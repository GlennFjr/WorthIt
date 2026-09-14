local _, WI = ...

local Dashboard = {}
WI.Dashboard = Dashboard

local ROWS_PER_PAGE = 10
local FRAME_WIDTH = 980
local FRAME_HEIGHT = 700
local CHART_WIDTH = 890
local CHART_HEIGHT = 270
local CHART_LEFT = 58
local CHART_RIGHT = 16
local CHART_BOTTOM = 32
local CHART_TOP = 20

local function makeButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text)
    return button
end

local function makeText(parent, template, width)
    local text = parent:CreateFontString(nil, "OVERLAY", template)
    if width then text:SetWidth(width) end
    return text
end

local function makePanel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.035, 0.035, 0.04, 0.90)
    panel:SetBackdropBorderColor(0.30, 0.30, 0.34, 0.90)
    return panel
end

local function shortName(analysis)
    local favorite = analysis and analysis.favorite
    return favorite and WI.Util:GetItemName(favorite.itemID, favorite.name) or "Unknown"
end

local function briefLine(analysis, fallback)
    if not analysis then return fallback end
    return string.format("%s\n%s • %s", shortName(analysis), WI.Util:FormatPercent(analysis.deviation), analysis.confidence)
end

local function metricCard(parent, x, y, width, title)
    local card = makePanel(parent)
    card:SetSize(width, 58)
    card:SetPoint("TOPLEFT", x, y)
    card.title = makeText(card, "GameFontDisableSmall", width - 18)
    card.title:SetPoint("TOPLEFT", 9, -8)
    card.title:SetJustifyH("LEFT")
    card.title:SetText(title)
    card.value = makeText(card, "GameFontHighlight", width - 18)
    card.value:SetPoint("BOTTOMLEFT", 9, 9)
    card.value:SetJustifyH("LEFT")
    return card
end

function Dashboard:Initialize()
    local frame = CreateFrame("Frame", "WorthItDashboard", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    UISpecialFrames = UISpecialFrames or {}
    local registered = false
    for _, name in ipairs(UISpecialFrames) do
        if name == "WorthItDashboard" then registered = true break end
    end
    if not registered then table.insert(UISpecialFrames, "WorthItDashboard") end

    local title = makeText(frame, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -20)
    title:SetText("WorthIt")

    local subtitle = makeText(frame, "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Auction House intelligence for your Blizzard favorites")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    self.ahStatus = makeText(frame, "GameFontHighlightSmall")
    self.ahStatus:SetPoint("TOPRIGHT", -44, -24)

    local refresh = makeButton(frame, "Refresh Favorites", 135, 24)
    refresh:SetPoint("TOPRIGHT", -24, -54)
    refresh:SetScript("OnClick", function()
        local ok, err = WI.AuctionHouse:SyncFavorites(true)
        if not ok then self:SetStatus(err) end
    end)
    self.refreshButton = refresh

    self.status = makeText(frame, "GameFontDisableSmall", 690)
    self.status:SetPoint("TOPLEFT", 24, -62)
    self.status:SetJustifyH("LEFT")
    self.status:SetText("Open the Auction House to update favorites.")

    self.overviewTab = makeButton(frame, "Market", 92, 24)
    self.overviewTab:SetPoint("TOPLEFT", 24, -88)
    self.overviewTab:SetScript("OnClick", function() self:ShowTab("overview") end)

    self.analyticsTab = makeButton(frame, "Analytics", 92, 24)
    self.analyticsTab:SetPoint("LEFT", self.overviewTab, "RIGHT", 6, 0)
    self.analyticsTab:SetScript("OnClick", function() self:ShowTab("analytics") end)

    self.overviewFrame = CreateFrame("Frame", nil, frame)
    self.overviewFrame:SetPoint("TOPLEFT", 18, -119)
    self.overviewFrame:SetPoint("BOTTOMRIGHT", -18, 40)

    self.analyticsFrame = CreateFrame("Frame", nil, frame)
    self.analyticsFrame:SetPoint("TOPLEFT", 18, -119)
    self.analyticsFrame:SetPoint("BOTTOMRIGHT", -18, 40)
    self.analyticsFrame:Hide()

    self:BuildOverview()
    self:BuildAnalytics()

    local footer = makeText(frame, "GameFontDisableSmall", FRAME_WIDTH - 48)
    footer:SetPoint("BOTTOMLEFT", 24, 20)
    footer:SetJustifyH("LEFT")
    footer:SetText("Favorites only  •  Local 30-day history  •  No background polling  •  Click a favorite for analytics  •  Esc closes WorthIt")

    self.frame = frame
    self.currentPage = 1
    self.currentTab = "overview"
    self.chartRange = WI.PriceEngine.WINDOW_7D
    self:SetAHStatus(WI.AuctionHouse.isOpen)
    self:Refresh()
end

function Dashboard:BuildOverview()
    local parent = self.overviewFrame
    local briefBox = makePanel(parent)
    briefBox:SetPoint("TOPLEFT", 6, -4)
    briefBox:SetPoint("TOPRIGHT", -6, -4)
    briefBox:SetHeight(102)

    local briefTitle = makeText(briefBox, "GameFontNormal")
    briefTitle:SetPoint("TOPLEFT", 12, -10)
    briefTitle:SetText("Market Brief")

    self.summary = makeText(briefBox, "GameFontHighlightSmall", 260)
    self.summary:SetPoint("TOPLEFT", 12, -34)
    self.summary:SetJustifyH("LEFT")

    self.buyBrief = makeText(briefBox, "GameFontHighlightSmall", 290)
    self.buyBrief:SetPoint("TOPLEFT", 305, -34)
    self.buyBrief:SetJustifyH("LEFT")

    self.sellBrief = makeText(briefBox, "GameFontHighlightSmall", 290)
    self.sellBrief:SetPoint("TOPLEFT", 610, -34)
    self.sellBrief:SetJustifyH("LEFT")

    self.diagnostics = makeText(briefBox, "GameFontDisableSmall", 900)
    self.diagnostics:SetPoint("BOTTOMLEFT", 12, 9)
    self.diagnostics:SetJustifyH("LEFT")

    local headers = {
        { "Favorite", 12, 245 },
        { "Current", 272, 98 },
        { "7d Median", 375, 98 },
        { "vs Fair", 478, 70 },
        { "24h vs 7d", 553, 70 },
        { "Signal", 628, 96 },
        { "Confidence", 729, 112 },
        { "Seen", 846, 54 },
    }
    for _, header in ipairs(headers) do
        local text = makeText(parent, "GameFontNormalSmall", header[3])
        text:SetPoint("TOPLEFT", header[2], -119)
        text:SetJustifyH("LEFT")
        text:SetText(header[1])
    end

    self.rows = {}
    for index = 1, ROWS_PER_PAGE do
        local rowIndex = index
        local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        row:SetSize(912, 31)
        row:SetPoint("TOPLEFT", 12, -136 - ((index - 1) * 32))
        row:EnableMouse(true)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        if rowIndex % 2 == 0 then row:SetBackdropColor(1, 1, 1, 0.025) else row:SetBackdropColor(0, 0, 0, 0) end

        row.name = makeText(row, "GameFontHighlight", 245)
        row.name:SetPoint("LEFT", 0, 0)
        row.name:SetJustifyH("LEFT")

        row.current = makeText(row, "GameFontHighlightSmall", 98)
        row.current:SetPoint("LEFT", 260, 0)
        row.current:SetJustifyH("LEFT")

        row.fair = makeText(row, "GameFontHighlightSmall", 98)
        row.fair:SetPoint("LEFT", 363, 0)
        row.fair:SetJustifyH("LEFT")

        row.delta = makeText(row, "GameFontHighlightSmall", 70)
        row.delta:SetPoint("LEFT", 466, 0)
        row.delta:SetJustifyH("LEFT")

        row.trend = makeText(row, "GameFontHighlightSmall", 70)
        row.trend:SetPoint("LEFT", 541, 0)
        row.trend:SetJustifyH("LEFT")

        row.signal = makeText(row, "GameFontNormalSmall", 96)
        row.signal:SetPoint("LEFT", 616, 0)
        row.signal:SetJustifyH("LEFT")

        row.confidence = makeText(row, "GameFontHighlightSmall", 112)
        row.confidence:SetPoint("LEFT", 717, 0)
        row.confidence:SetJustifyH("LEFT")

        row.seen = makeText(row, "GameFontHighlightSmall", 54)
        row.seen:SetPoint("LEFT", 834, 0)
        row.seen:SetJustifyH("LEFT")

        row:SetScript("OnEnter", function(r)
            r:SetBackdropColor(0.85, 0.72, 0.30, 0.10)
            self:ShowTooltip(r)
        end)
        row:SetScript("OnLeave", function(r)
            if rowIndex % 2 == 0 then r:SetBackdropColor(1, 1, 1, 0.025) else r:SetBackdropColor(0, 0, 0, 0) end
            GameTooltip:Hide()
        end)
        row:SetScript("OnMouseUp", function(r, button)
            if button == "LeftButton" and r.analysis then
                self.selectedKey = r.analysis.key
                self:ShowTab("analytics")
            end
        end)
        self.rows[index] = row
    end

    local empty = makeText(parent, "GameFontHighlight", 850)
    empty:SetPoint("TOP", 0, -260)
    empty:SetJustifyH("CENTER")
    empty:SetText("No Auction House favorites found yet.\n\nFavorite items in Blizzard's Auction House, then press Refresh Favorites.")
    self.empty = empty

    local previous = makeButton(parent, "<", 36, 22)
    previous:SetPoint("BOTTOMLEFT", 12, 8)
    previous:SetScript("OnClick", function()
        self.currentPage = math.max(1, (self.currentPage or 1) - 1)
        self:RefreshOverview()
    end)
    self.prevButton = previous

    self.pageText = makeText(parent, "GameFontHighlightSmall", 100)
    self.pageText:SetPoint("LEFT", previous, "RIGHT", 10, 0)
    self.pageText:SetJustifyH("CENTER")

    local nextButton = makeButton(parent, ">", 36, 22)
    nextButton:SetPoint("LEFT", self.pageText, "RIGHT", 10, 0)
    nextButton:SetScript("OnClick", function()
        self.currentPage = (self.currentPage or 1) + 1
        self:RefreshOverview()
    end)
    self.nextButton = nextButton

    local hint = makeText(parent, "GameFontDisableSmall", 500)
    hint:SetPoint("BOTTOMRIGHT", -12, 10)
    hint:SetJustifyH("RIGHT")
    hint:SetText("Rows are ranked by unusual price movement × confidence")
end

function Dashboard:BuildAnalytics()
    local parent = self.analyticsFrame

    self.analyticsTitle = makeText(parent, "GameFontNormalLarge", 600)
    self.analyticsTitle:SetPoint("TOPLEFT", 10, -8)
    self.analyticsTitle:SetJustifyH("LEFT")
    self.analyticsTitle:SetText("Select a favorite from Market")

    self.analyticsSubtitle = makeText(parent, "GameFontDisableSmall", 880)
    self.analyticsSubtitle:SetPoint("TOPLEFT", 10, -34)
    self.analyticsSubtitle:SetJustifyH("LEFT")

    self.metricCards = {
        current = metricCard(parent, 10, -62, 176, "Current price"),
        median = metricCard(parent, 194, -62, 176, "7d median / mean"),
        range = metricCard(parent, 378, -62, 176, "7d low / high"),
        trend = metricCard(parent, 562, -62, 176, "24h vs 7d"),
        percentile = metricCard(parent, 746, -62, 176, "Current percentile"),
        samples = metricCard(parent, 10, -128, 176, "Samples / span"),
        iqr = metricCard(parent, 194, -128, 176, "IQR"),
        mad = metricCard(parent, 378, -128, 176, "MAD"),
        cv = metricCard(parent, 562, -128, 176, "Coefficient of variation"),
        robustZ = metricCard(parent, 746, -128, 176, "Robust z-score"),
    }

    local chartBox = makePanel(parent)
    chartBox:SetSize(CHART_WIDTH, CHART_HEIGHT + 48)
    chartBox:SetPoint("TOPLEFT", 10, -200)
    self.chartBox = chartBox

    self.chartTitle = makeText(chartBox, "GameFontNormal", 520)
    self.chartTitle:SetPoint("TOPLEFT", 12, -10)
    self.chartTitle:SetJustifyH("LEFT")
    self.chartTitle:SetText("Price history")

    self.range24h = makeButton(chartBox, "24H", 48, 20)
    self.range24h:SetPoint("TOPRIGHT", -120, -8)
    self.range24h:SetScript("OnClick", function()
        self.chartRange = WI.PriceEngine.WINDOW_24H
        self:RefreshAnalytics()
    end)

    self.range7d = makeButton(chartBox, "7D", 48, 20)
    self.range7d:SetPoint("LEFT", self.range24h, "RIGHT", 4, 0)
    self.range7d:SetScript("OnClick", function()
        self.chartRange = WI.PriceEngine.WINDOW_7D
        self:RefreshAnalytics()
    end)

    self.range30d = makeButton(chartBox, "30D", 48, 20)
    self.range30d:SetPoint("LEFT", self.range7d, "RIGHT", 4, 0)
    self.range30d:SetScript("OnClick", function()
        self.chartRange = WI.PriceEngine.WINDOW_30D
        self:RefreshAnalytics()
    end)

    self.chartFrame = CreateFrame("Frame", nil, chartBox, "BackdropTemplate")
    self.chartFrame:SetSize(CHART_WIDTH - 24, CHART_HEIGHT)
    self.chartFrame:SetPoint("BOTTOMLEFT", 12, 12)
    self.chartFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    self.chartFrame:SetBackdropColor(0.015, 0.015, 0.018, 0.82)

    self.chartLines = {}
    self.gridLines = {}
    self.yLabels = {}
    for index = 1, 4 do
        local label = makeText(self.chartFrame, "GameFontDisableSmall", 54)
        label:SetJustifyH("RIGHT")
        self.yLabels[index] = label
    end

    self.xStart = makeText(self.chartFrame, "GameFontDisableSmall", 120)
    self.xStart:SetPoint("BOTTOMLEFT", CHART_LEFT, 4)
    self.xStart:SetJustifyH("LEFT")

    self.xEnd = makeText(self.chartFrame, "GameFontDisableSmall", 120)
    self.xEnd:SetPoint("BOTTOMRIGHT", -CHART_RIGHT, 4)
    self.xEnd:SetJustifyH("RIGHT")

    self.chartEmpty = makeText(self.chartFrame, "GameFontHighlight", 500)
    self.chartEmpty:SetPoint("CENTER", 15, 0)
    self.chartEmpty:SetJustifyH("CENTER")
    self.chartEmpty:SetText("Collect at least two observations to draw a price history.")

    self.analyticsFoot = makeText(parent, "GameFontDisableSmall", 900)
    self.analyticsFoot:SetPoint("TOPLEFT", 10, -535)
    self.analyticsFoot:SetJustifyH("LEFT")
    self.analyticsFoot:SetText("Median and MAD are robust to price outliers. Percentile shows where the current price sits within your observed 7-day distribution.")
end

function Dashboard:GetAnalysisByKey(key)
    if not key then return nil end
    for _, analysis in ipairs(WI.PriceEngine:GetAnalyses()) do
        if analysis.key == key then return analysis end
    end
    return nil
end

function Dashboard:ShowTooltip(row)
    local analysis = row and row.analysis
    if not analysis then return end
    local favorite = analysis.favorite
    local details = WI.PriceEngine:GetDetailStats(favorite)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(shortName(analysis), 1, 1, 1)
    GameTooltip:AddLine("Price checker", 0.85, 0.72, 0.30)
    GameTooltip:AddDoubleLine("Current", analysis.current and WI.Util:FormatMoney(analysis.current) or "—", 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("7d median", analysis.fairValue and WI.Util:FormatMoney(analysis.fairValue) or "—", 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Deviation", WI.Util:FormatPercent(analysis.deviation), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("24h vs 7d", WI.Util:FormatPercent(analysis.trend), 0.8, 0.8, 0.8, 1, 1, 1)
    if details then
        GameTooltip:AddDoubleLine("7d percentile", string.format("%.0f%%", details.currentPercentile * 100), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine("Volatility CV", string.format("%.1f%%", details.coefficientVariation * 100), 0.8, 0.8, 0.8, 1, 1, 1)
    end
    GameTooltip:AddDoubleLine("Samples", tostring(analysis.sampleCount or 0), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Quantity", tostring(analysis.lastQuantity or 0), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddDoubleLine("Last seen", WI.Util:FormatAge(favorite.lastSeen), 0.8, 0.8, 0.8, 1, 1, 1)
    GameTooltip:AddLine("Click for analytics", 0.65, 0.65, 0.65)
    GameTooltip:Show()
end

function Dashboard:SetAHStatus(open)
    if not self.ahStatus then return end
    if open then
        self.ahStatus:SetText("Auction House: |cff55dd66OPEN|r")
        if self.refreshButton then self.refreshButton:Enable() end
    else
        self.ahStatus:SetText("Auction House: |cff999999CLOSED|r")
        if self.refreshButton then self.refreshButton:Disable() end
    end
end

function Dashboard:SetStatus(text)
    if self.status then self.status:SetText(text or "") end
end

function Dashboard:ShowTab(name)
    self.currentTab = name == "analytics" and "analytics" or "overview"
    self.overviewFrame:SetShown(self.currentTab == "overview")
    self.analyticsFrame:SetShown(self.currentTab == "analytics")
    if self.currentTab == "overview" then
        self.overviewTab:Disable()
        self.analyticsTab:Enable()
        self:RefreshOverview()
    else
        self.overviewTab:Enable()
        self.analyticsTab:Disable()
        if not self.selectedKey then
            local analyses = WI.PriceEngine:GetAnalyses()
            if analyses[1] then self.selectedKey = analyses[1].key end
        end
        self:RefreshAnalytics()
    end
end

function Dashboard:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then self.frame:Hide() else self.frame:Show(); self:Refresh() end
end

function Dashboard:Show()
    if self.frame then self.frame:Show(); self:Refresh() end
end

function Dashboard:Refresh()
    if not self.frame then return end
    self:RefreshOverview()
    if self.currentTab == "analytics" then self:RefreshAnalytics() end
end

function Dashboard:RefreshOverview()
    if not self.frame then return end

    local analyses = WI.PriceEngine:GetAnalyses()
    local brief = WI.PriceEngine:GetBrief()
    local totalPages = math.max(1, math.ceil(#analyses / ROWS_PER_PAGE))
    self.currentPage = WI.Util:Clamp(self.currentPage or 1, 1, totalPages)
    local first = ((self.currentPage - 1) * ROWS_PER_PAGE) + 1

    self.summary:SetText(string.format(
        "%d favorites\n%d fresh • %d high confidence\n%d still learning",
        brief.total, brief.fresh, brief.highConfidence, brief.learning
    ))
    self.buyBrief:SetText("|cff55dd66Best buy|r\n" .. briefLine(brief.bestBuy, "No strong buy signal yet"))
    self.sellBrief:SetText("|cffff7a40High price|r\n" .. briefLine(brief.bestSell, "No strong high-price signal yet"))
    self.diagnostics:SetText(string.format(
        "Session: %d WorthIt AH quer%s • %d passive capture%s • %d stored observations • median absolute move %s",
        WI.AuctionHouse.sessionQueries or 0, (WI.AuctionHouse.sessionQueries or 0) == 1 and "y" or "ies",
        WI.AuctionHouse.sessionPassiveCaptures or 0, (WI.AuctionHouse.sessionPassiveCaptures or 0) == 1 and "" or "s",
        WI.Database.db.stats.captured or 0,
        WI.Util:FormatPercent(brief.medianAbsoluteMove)
    ))

    self.empty:SetShown(#analyses == 0)

    for rowIndex = 1, ROWS_PER_PAGE do
        local row = self.rows[rowIndex]
        local analysis = analyses[first + rowIndex - 1]
        if analysis then
            row.analysis = analysis
            row.name:SetText("|cffffd100★|r " .. shortName(analysis))
            row.current:SetText(analysis.current and WI.Util:FormatMoney(analysis.current) or "—")
            row.fair:SetText(analysis.fairValue and WI.Util:FormatMoney(analysis.fairValue) or "—")
            row.delta:SetText(WI.Util:FormatPercent(analysis.deviation))
            row.trend:SetText(WI.Util:FormatPercent(analysis.trend))
            row.signal:SetText(analysis.label or "LEARNING")
            local color = WI.PriceEngine:GetColorForLabel(analysis.label)
            row.signal:SetTextColor(color[1], color[2], color[3])
            row.confidence:SetText((analysis.confidence or "None") .. " (" .. tostring(analysis.sampleCount or 0) .. ")")
            row.seen:SetText(WI.Util:FormatAge(analysis.lastSeen))
            row:Show()
        else
            row.analysis = nil
            row:Hide()
        end
    end

    self.pageText:SetText(string.format("%d / %d", self.currentPage, totalPages))
    if self.currentPage <= 1 then self.prevButton:Disable() else self.prevButton:Enable() end
    if self.currentPage >= totalPages then self.nextButton:Disable() else self.nextButton:Enable() end
end

function Dashboard:ClearChart()
    for _, line in ipairs(self.chartLines or {}) do line:Hide() end
    for _, line in ipairs(self.gridLines or {}) do line:Hide() end
    for _, label in ipairs(self.yLabels or {}) do label:Hide() end
    if self.xStart then self.xStart:SetText("") end
    if self.xEnd then self.xEnd:SetText("") end
end

function Dashboard:GetLine(pool, index, layer)
    if not pool[index] then
        local line = self.chartFrame:CreateLine(nil, layer or "ARTWORK")
        line:SetThickness(2)
        pool[index] = line
    end
    pool[index]:Show()
    return pool[index]
end

function Dashboard:DrawChart(analysis)
    self:ClearChart()
    if not analysis or not analysis.favorite then
        self.chartEmpty:Show()
        return
    end

    local series = WI.PriceEngine:GetSeries(analysis.favorite, self.chartRange, 120)
    if #series < 2 then
        self.chartEmpty:Show()
        return
    end
    self.chartEmpty:Hide()

    local minPrice, maxPrice
    for _, point in ipairs(series) do
        minPrice = minPrice and math.min(minPrice, point.price) or point.price
        maxPrice = maxPrice and math.max(maxPrice, point.price) or point.price
    end
    if analysis.fairValue then
        minPrice = math.min(minPrice, analysis.fairValue)
        maxPrice = math.max(maxPrice, analysis.fairValue)
    end

    local spread = math.max(1, maxPrice - minPrice)
    local padding = spread * 0.10
    minPrice = math.max(0, minPrice - padding)
    maxPrice = maxPrice + padding
    spread = math.max(1, maxPrice - minPrice)

    local plotWidth = (CHART_WIDTH - 24) - CHART_LEFT - CHART_RIGHT
    local plotHeight = CHART_HEIGHT - CHART_BOTTOM - CHART_TOP
    local firstTime = series[1].time
    local lastTime = series[#series].time
    local rawTimeSpan = lastTime - firstTime
    local timeSpan = math.max(1, rawTimeSpan)

    for index = 1, 4 do
        local fraction = (index - 1) / 3
        local y = CHART_BOTTOM + (fraction * plotHeight)
        local grid = self:GetLine(self.gridLines, index, "BACKGROUND")
        grid:SetThickness(1)
        grid:SetColorTexture(1, 1, 1, 0.10)
        grid:SetStartPoint("BOTTOMLEFT", self.chartFrame, CHART_LEFT, y)
        grid:SetEndPoint("BOTTOMLEFT", self.chartFrame, CHART_LEFT + plotWidth, y)
        local label = self.yLabels[index]
        label:ClearAllPoints()
        label:SetPoint("RIGHT", self.chartFrame, "BOTTOMLEFT", CHART_LEFT - 6, y)
        label:SetText(WI.Util:FormatCompactMoney(minPrice + (fraction * spread)))
        label:Show()
    end

    local function pointXY(point)
        local x
        if rawTimeSpan <= 0 then
            x = CHART_LEFT
        else
            x = CHART_LEFT + (((point.time - firstTime) / timeSpan) * plotWidth)
        end
        local y = CHART_BOTTOM + (((point.price - minPrice) / spread) * plotHeight)
        return x, y
    end

    for index = 2, #series do
        local x1, y1 = pointXY(series[index - 1])
        local x2, y2 = pointXY(series[index])
        local line = self:GetLine(self.chartLines, index - 1, "ARTWORK")
        line:SetThickness(2)
        line:SetColorTexture(0.85, 0.72, 0.30, 1)
        line:SetStartPoint("BOTTOMLEFT", self.chartFrame, x1, y1)
        line:SetEndPoint("BOTTOMLEFT", self.chartFrame, x2, y2)
    end

    if analysis.fairValue then
        local y = CHART_BOTTOM + (((analysis.fairValue - minPrice) / spread) * plotHeight)
        local fairLine = self:GetLine(self.chartLines, #series, "ARTWORK")
        fairLine:SetThickness(1.5)
        fairLine:SetColorTexture(0.70, 0.70, 0.72, 0.75)
        fairLine:SetStartPoint("BOTTOMLEFT", self.chartFrame, CHART_LEFT, y)
        fairLine:SetEndPoint("BOTTOMLEFT", self.chartFrame, CHART_LEFT + plotWidth, y)
    end

    self.xStart:SetText(date("%b %d", firstTime))
    self.xEnd:SetText(date("%b %d", lastTime))
end

function Dashboard:RefreshAnalytics()
    if not self.frame then return end
    local analysis = self:GetAnalysisByKey(self.selectedKey)
    if not analysis then
        local analyses = WI.PriceEngine:GetAnalyses()
        analysis = analyses[1]
        self.selectedKey = analysis and analysis.key or nil
    end

    if not analysis then
        self.analyticsTitle:SetText("No favorite selected")
        self.analyticsSubtitle:SetText("Favorite items in Blizzard's Auction House to build an analytics history.")
        for _, card in pairs(self.metricCards) do card.value:SetText("—") end
        self:DrawChart(nil)
        return
    end

    local details = WI.PriceEngine:GetDetailStats(analysis.favorite)
    self.analyticsTitle:SetText("|cffffd100★|r " .. shortName(analysis))
    self.analyticsSubtitle:SetText(string.format(
        "%s • %s confidence • last seen %s • latest quantity %d",
        analysis.label, analysis.confidence, WI.Util:FormatAge(analysis.lastSeen), analysis.lastQuantity or 0
    ))

    self.metricCards.current.value:SetText(analysis.current and WI.Util:FormatMoney(analysis.current) or "—")
    self.metricCards.median.value:SetText(details and (WI.Util:FormatCompactMoney(details.median) .. " / " .. WI.Util:FormatCompactMoney(details.mean)) or (analysis.fairValue and WI.Util:FormatMoney(analysis.fairValue) or "—"))
    self.metricCards.trend.value:SetText(WI.Util:FormatPercent(analysis.trend))

    if details then
        self.metricCards.range.value:SetText(WI.Util:FormatCompactMoney(details.low) .. " / " .. WI.Util:FormatCompactMoney(details.high))
        self.metricCards.percentile.value:SetText(string.format("%.0f%%", details.currentPercentile * 100))
        self.metricCards.samples.value:SetText(string.format("%d / %s", details.sampleCount, WI.Util:FormatSpan(details.spanSeconds)))
        self.metricCards.iqr.value:SetText(WI.Util:FormatCompactMoney(details.iqr))
        self.metricCards.mad.value:SetText(WI.Util:FormatCompactMoney(details.mad))
        self.metricCards.cv.value:SetText(string.format("%.1f%%", details.coefficientVariation * 100))
        self.metricCards.robustZ.value:SetText(WI.Util:FormatNumber(details.robustZ, 2))
    else
        self.metricCards.range.value:SetText("—")
        self.metricCards.percentile.value:SetText("—")
        self.metricCards.samples.value:SetText("0 / —")
        self.metricCards.iqr.value:SetText("—")
        self.metricCards.mad.value:SetText("—")
        self.metricCards.cv.value:SetText("—")
        self.metricCards.robustZ.value:SetText("—")
    end

    local rangeLabel = "7 days"
    if self.chartRange == WI.PriceEngine.WINDOW_24H then rangeLabel = "24 hours"
    elseif self.chartRange == WI.PriceEngine.WINDOW_30D then rangeLabel = "30 days" end
    self.range24h:Enable()
    self.range7d:Enable()
    self.range30d:Enable()
    if self.chartRange == WI.PriceEngine.WINDOW_24H then self.range24h:Disable()
    elseif self.chartRange == WI.PriceEngine.WINDOW_30D then self.range30d:Disable()
    else self.range7d:Disable() end
    self.chartTitle:SetText("Price history • " .. rangeLabel .. " • gold = observed price • gray = 7d median")
    self:DrawChart(analysis)
end
