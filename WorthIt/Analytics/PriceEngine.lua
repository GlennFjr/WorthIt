local _, WI = ...

local PriceEngine = {}
WI.PriceEngine = PriceEngine

local WINDOW_7D = 7 * 24 * 60 * 60
local WINDOW_24H = 24 * 60 * 60
local WINDOW_30D = 30 * 24 * 60 * 60

local function observationsInWindow(favorite, windowSeconds)
    local results = {}
    local cutoff = WI.Util:Now() - windowSeconds
    for _, observation in ipairs(favorite.observations or {}) do
        if observation.time and observation.time >= cutoff and observation.price and observation.price > 0 then
            results[#results + 1] = observation
        end
    end
    return results
end

local function pricesFromObservations(observations)
    local prices = {}
    for _, observation in ipairs(observations) do prices[#prices + 1] = observation.price end
    return prices
end

local function minMax(values)
    local low, high
    for _, value in ipairs(values or {}) do
        low = low and math.min(low, value) or value
        high = high and math.max(high, value) or value
    end
    return low, high
end

function PriceEngine:AnalyzeFavorite(favorite)
    if not favorite then return nil end

    local observations7d = observationsInWindow(favorite, WINDOW_7D)
    local observations24h = observationsInWindow(favorite, WINDOW_24H)
    local prices7d = pricesFromObservations(observations7d)
    local prices24h = pricesFromObservations(observations24h)
    local sampleCount = #prices7d
    local current = favorite.lastPrice

    if sampleCount == 0 then
        return {
            key = favorite.key,
            favorite = favorite,
            current = current,
            sampleCount = 0,
            confidence = "None",
            confidenceScore = 0,
            label = "LEARNING",
            opportunityScore = 0,
        }
    end

    local median7d = WI.Util:Median(prices7d)
    local mad = WI.Util:MedianAbsoluteDeviation(prices7d, median7d) or 0
    current = current or prices7d[sampleCount]
    local deviation = median7d > 0 and ((current - median7d) / median7d) or 0
    local relativeMAD = median7d > 0 and (mad / median7d) or 0

    local oldest = observations7d[1] and observations7d[1].time or nil
    local newest = observations7d[#observations7d] and observations7d[#observations7d].time or nil
    local spanSeconds = oldest and newest and math.max(0, newest - oldest) or 0

    local confidenceScore = math.min(sampleCount / 20, 1) * 0.70
    if oldest then confidenceScore = confidenceScore + math.min((WI.Util:Now() - oldest) / (3 * 86400), 1) * 0.30 end
    confidenceScore = WI.Util:Clamp(confidenceScore, 0, 1)

    local confidence = "Low"
    if confidenceScore >= 0.75 then confidence = "High"
    elseif confidenceScore >= 0.40 then confidence = "Medium" end

    local threshold = WI.Util:Clamp(0.10 + relativeMAD * 1.5, 0.10, 0.30)
    local label = "NORMAL"
    if sampleCount < 3 then label = "LEARNING"
    elseif deviation <= -threshold * 1.6 then label = "GREAT BUY"
    elseif deviation <= -threshold then label = "GOOD BUY"
    elseif deviation >= threshold * 1.6 then label = "VERY HIGH"
    elseif deviation >= threshold then label = "HIGH" end

    local median24h = #prices24h > 0 and WI.Util:Median(prices24h) or nil
    local trend = median24h and median7d > 0 and ((median24h - median7d) / median7d) or nil
    local opportunityScore = math.abs(deviation) * confidenceScore

    return {
        key = favorite.key,
        favorite = favorite,
        current = current,
        fairValue = median7d,
        deviation = deviation,
        median24h = median24h,
        trend = trend,
        mad = mad,
        relativeMAD = relativeMAD,
        threshold = threshold,
        sampleCount = sampleCount,
        confidence = confidence,
        confidenceScore = confidenceScore,
        label = label,
        opportunityScore = opportunityScore,
        lastSeen = favorite.lastSeen,
        lastQuantity = favorite.lastQuantity or 0,
        spanSeconds = spanSeconds,
    }
end

function PriceEngine:GetDetailStats(favorite)
    if not favorite then return nil end
    local observations7d = observationsInWindow(favorite, WINDOW_7D)
    local prices = pricesFromObservations(observations7d)
    if #prices == 0 then return nil end

    local median = WI.Util:Median(prices)
    local mean = WI.Util:Mean(prices)
    local q1 = WI.Util:Percentile(prices, 0.25)
    local q3 = WI.Util:Percentile(prices, 0.75)
    local mad = WI.Util:MedianAbsoluteDeviation(prices, median) or 0
    local stdev = WI.Util:StandardDeviation(prices, mean)
    local low, high = minMax(prices)
    local current = favorite.lastPrice or prices[#prices]
    local percentileCount = 0
    for _, price in ipairs(prices) do
        if price <= current then percentileCount = percentileCount + 1 end
    end
    local currentPercentile = #prices > 0 and (percentileCount / #prices) or nil
    local robustZ = mad > 0 and (0.6745 * (current - median) / mad) or nil
    local coefficientVariation = mean and mean > 0 and (stdev / mean) or 0
    local span = observations7d[#observations7d].time - observations7d[1].time

    return {
        sampleCount = #prices,
        median = median,
        mean = mean,
        low = low,
        high = high,
        q1 = q1,
        q3 = q3,
        iqr = q3 - q1,
        mad = mad,
        stdev = stdev,
        coefficientVariation = coefficientVariation,
        currentPercentile = currentPercentile,
        robustZ = robustZ,
        spanSeconds = span,
        latestQuantity = favorite.lastQuantity or 0,
    }
end

function PriceEngine:GetSeries(favorite, windowSeconds, maxPoints)
    if not favorite then return {} end
    windowSeconds = tonumber(windowSeconds) or WINDOW_7D
    maxPoints = tonumber(maxPoints) or 120
    local source = observationsInWindow(favorite, windowSeconds)
    if #source <= maxPoints then return source end

    local sampled = {}
    for index = 1, maxPoints do
        local sourceIndex = math.floor(((index - 1) * (#source - 1)) / (maxPoints - 1)) + 1
        sampled[#sampled + 1] = source[sourceIndex]
    end
    return sampled
end

function PriceEngine:GetColorForLabel(label)
    if label == "GREAT BUY" or label == "GOOD BUY" then return WI.colors.good end
    if label == "HIGH" or label == "VERY HIGH" then return WI.colors.high end
    if label == "LEARNING" then return WI.colors.muted end
    return WI.colors.normal
end

function PriceEngine:GetAnalyses()
    local results = {}
    for _, favorite in ipairs(WI.Database:GetFavorites()) do
        results[#results + 1] = self:AnalyzeFavorite(favorite)
    end
    table.sort(results, function(a, b)
        if a.opportunityScore == b.opportunityScore then
            return string.lower(a.favorite.name or "") < string.lower(b.favorite.name or "")
        end
        return a.opportunityScore > b.opportunityScore
    end)
    return results
end

function PriceEngine:GetBrief()
    local analyses = self:GetAnalyses()
    local bestBuy, bestSell
    local learning, fresh, highConfidence = 0, 0, 0
    local deviations = {}

    for _, analysis in ipairs(analyses) do
        if analysis.label == "LEARNING" then learning = learning + 1 end
        if analysis.lastSeen and (WI.Util:Now() - analysis.lastSeen) <= 3600 then fresh = fresh + 1 end
        if analysis.confidence == "High" then highConfidence = highConfidence + 1 end
        if analysis.deviation then deviations[#deviations + 1] = math.abs(analysis.deviation) end
        if (analysis.label == "GOOD BUY" or analysis.label == "GREAT BUY") and not bestBuy then bestBuy = analysis end
        if (analysis.label == "HIGH" or analysis.label == "VERY HIGH") and not bestSell then bestSell = analysis end
    end

    return {
        total = #analyses,
        bestBuy = bestBuy,
        bestSell = bestSell,
        learning = learning,
        fresh = fresh,
        highConfidence = highConfidence,
        medianAbsoluteMove = #deviations > 0 and WI.Util:Median(deviations) or nil,
    }
end

PriceEngine.WINDOW_24H = WINDOW_24H
PriceEngine.WINDOW_7D = WINDOW_7D
PriceEngine.WINDOW_30D = WINDOW_30D
