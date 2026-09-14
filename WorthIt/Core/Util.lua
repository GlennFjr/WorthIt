local _, WI = ...

local Util = {}
WI.Util = Util

function Util:Now()
    return time()
end

function Util:Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

function Util:CopyArray(source)
    local copy = {}
    for i = 1, #source do copy[i] = source[i] end
    return copy
end

function Util:Median(values)
    if not values or #values == 0 then return nil end
    local sorted = self:CopyArray(values)
    table.sort(sorted)
    local count = #sorted
    if count % 2 == 1 then return sorted[(count + 1) / 2] end
    return (sorted[count / 2] + sorted[count / 2 + 1]) / 2
end

function Util:Mean(values)
    if not values or #values == 0 then return nil end
    local sum = 0
    for _, value in ipairs(values) do sum = sum + value end
    return sum / #values
end

function Util:Percentile(values, percentile)
    if not values or #values == 0 then return nil end
    local sorted = self:CopyArray(values)
    table.sort(sorted)
    percentile = self:Clamp(tonumber(percentile) or 0.5, 0, 1)
    if #sorted == 1 then return sorted[1] end
    local position = 1 + ((#sorted - 1) * percentile)
    local lower = math.floor(position)
    local upper = math.ceil(position)
    if lower == upper then return sorted[lower] end
    local weight = position - lower
    return sorted[lower] + ((sorted[upper] - sorted[lower]) * weight)
end

function Util:MedianAbsoluteDeviation(values, median)
    if not values or #values == 0 then return nil end
    median = median or self:Median(values)
    local deviations = {}
    for i = 1, #values do deviations[i] = math.abs(values[i] - median) end
    return self:Median(deviations)
end

function Util:StandardDeviation(values, mean)
    if not values or #values < 2 then return 0 end
    mean = mean or self:Mean(values)
    local sum = 0
    for _, value in ipairs(values) do
        local delta = value - mean
        sum = sum + (delta * delta)
    end
    return math.sqrt(sum / (#values - 1))
end

function Util:FormatMoney(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    if GetMoneyString then return GetMoneyString(copper, true) end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local c = copper % 100
    return string.format("%dg %ds %dc", gold, silver, c)
end

function Util:FormatCompactMoney(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = copper / 10000
    if gold >= 1000000 then return string.format("%.1fm", gold / 1000000) end
    if gold >= 1000 then return string.format("%.1fk", gold / 1000) end
    if gold >= 1 then return string.format("%.1fg", gold) end
    return string.format("%.0fs", copper / 100)
end

function Util:FormatPercent(value)
    if value == nil then return "—" end
    return string.format("%+.1f%%", value * 100)
end

function Util:FormatNumber(value, decimals)
    if value == nil then return "—" end
    return string.format("%." .. tostring(decimals or 1) .. "f", value)
end

function Util:FormatAge(timestamp)
    if not timestamp then return "Never" end
    local seconds = math.max(0, self:Now() - timestamp)
    if seconds < 60 then return "Now" end
    if seconds < 3600 then return math.floor(seconds / 60) .. "m" end
    if seconds < 86400 then return math.floor(seconds / 3600) .. "h" end
    return math.floor(seconds / 86400) .. "d"
end

function Util:FormatSpan(seconds)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds < 3600 then return math.max(1, math.floor(seconds / 60)) .. "m" end
    if seconds < 86400 then return string.format("%.1fh", seconds / 3600) end
    return string.format("%.1fd", seconds / 86400)
end

function Util:GetItemName(itemID, fallback)
    if C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(itemID)
        if name then return name end
    end
    if GetItemInfo then
        local name = GetItemInfo(itemID)
        if name then return name end
    end
    return fallback or ("Item " .. tostring(itemID))
end

function Util:FavoriteKey(itemKey)
    if type(itemKey) ~= "table" or not tonumber(itemKey.itemID) then return nil end
    return table.concat({
        tonumber(itemKey.itemID) or 0,
        tonumber(itemKey.itemLevel) or 0,
        tonumber(itemKey.itemSuffix) or 0,
        tonumber(itemKey.battlePetSpeciesID) or 0,
    }, ":")
end

function Util:CopyItemKey(itemKey)
    if type(itemKey) ~= "table" then return nil end
    return {
        itemID = tonumber(itemKey.itemID) or 0,
        itemLevel = tonumber(itemKey.itemLevel) or 0,
        itemSuffix = tonumber(itemKey.itemSuffix) or 0,
        battlePetSpeciesID = tonumber(itemKey.battlePetSpeciesID) or 0,
    }
end

function Util:SafePrint(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffd9b44aWorthIt:|r " .. tostring(message))
end

function Util:TableCount(tbl)
    local count = 0
    for _ in pairs(tbl or {}) do count = count + 1 end
    return count
end
