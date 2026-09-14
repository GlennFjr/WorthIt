local _, WI = ...

local AuctionHouse = {}
WI.AuctionHouse = AuctionHouse

AuctionHouse.isOpen = false
AuctionHouse.syncPending = false
AuctionHouse.syncedThisSession = false
AuctionHouse.lastSyncRequest = 0
AuctionHouse.syncGeneration = 0
AuctionHouse.sessionQueries = 0
AuctionHouse.sessionPassiveCaptures = 0

local function commoditySummary(itemID)
    local lowest, total = nil, 0
    local count = C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0
    for index = 1, count do
        local result = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, index)
        if result then
            total = total + (tonumber(result.quantity) or 0)
            local price = tonumber(result.unitPrice)
            if price and price > 0 and (not lowest or price < lowest) then lowest = price end
        end
    end
    return lowest, total
end

local function itemSummary(itemKey)
    local lowest, total = nil, 0
    local count = C_AuctionHouse.GetNumItemSearchResults(itemKey) or 0
    for index = 1, count do
        local result = C_AuctionHouse.GetItemSearchResultInfo(itemKey, index)
        if result then
            total = total + (tonumber(result.quantity) or 1)
            local price = tonumber(result.buyoutAmount)
            if price and price > 0 and (not lowest or price < lowest) then lowest = price end
        end
    end
    return lowest, total
end

function AuctionHouse:Initialize()
    self.frame = CreateFrame("Frame")
    local events = {
        "AUCTION_HOUSE_SHOW",
        "AUCTION_HOUSE_CLOSED",
        "AUCTION_HOUSE_FAVORITES_UPDATED",
        "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED",
        "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
        "AUCTION_HOUSE_BROWSE_FAILURE",
        "COMMODITY_SEARCH_RESULTS_UPDATED",
        "ITEM_SEARCH_RESULTS_UPDATED",
        "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    }
    for _, event in ipairs(events) do self.frame:RegisterEvent(event) end
    self.frame:SetScript("OnEvent", function(_, event, ...)
        local handler = self[event]
        if handler then handler(self, ...) end
    end)
end

function AuctionHouse:AUCTION_HOUSE_SHOW()
    self.isOpen = true
    self.syncedThisSession = false
    self.syncGeneration = self.syncGeneration + 1
    if WI.Dashboard then WI.Dashboard:SetAHStatus(true) end

    local generation = self.syncGeneration
    C_Timer.After(0.4, function()
        if self.isOpen and generation == self.syncGeneration and not self.syncedThisSession then self:SyncFavorites(false) end
    end)
end

function AuctionHouse:AUCTION_HOUSE_CLOSED()
    self.isOpen = false
    self.syncPending = false
    self.syncedThisSession = false
    self.syncGeneration = self.syncGeneration + 1
    if WI.Dashboard then
        WI.Dashboard:SetAHStatus(false)
        WI.Dashboard:SetStatus("Open the Auction House to update favorites.")
    end
end

function AuctionHouse:AUCTION_HOUSE_FAVORITES_UPDATED()
    if not self.isOpen then return end
    local generation = self.syncGeneration
    C_Timer.After(WI.constants.FAVORITES_EVENT_DEBOUNCE_SECONDS, function()
        if self.isOpen and generation == self.syncGeneration then self:SyncFavorites(false) end
    end)
end

function AuctionHouse:CanSync()
    if not self.isOpen then return false, "Open the Auction House first." end
    if self.syncPending then return false, "Favorites are already refreshing." end
    if not C_AuctionHouse.SearchForFavorites or not C_AuctionHouse.GetBrowseResults then
        return false, "Auction House favorites are unavailable on this client."
    end
    if C_AuctionHouse.FavoritesAreAvailable and not C_AuctionHouse.FavoritesAreAvailable() then
        return false, "Auction House favorites are not ready yet."
    end
    if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
        return false, "Auction House is throttled; try again shortly."
    end

    local now = GetTime and GetTime() or 0
    local remaining = WI.constants.FAVORITES_SYNC_COOLDOWN_SECONDS - (now - self.lastSyncRequest)
    if remaining > 0 then return false, string.format("Refresh available in %d seconds.", math.ceil(remaining)) end
    return true
end

function AuctionHouse:SyncFavorites(userRequested)
    local ok, reason = self:CanSync()
    if not ok then
        if userRequested and WI.Dashboard then WI.Dashboard:SetStatus(reason) end
        return false, reason
    end

    self.syncPending = true
    self.lastSyncRequest = GetTime and GetTime() or 0
    local generation = self.syncGeneration
    if WI.Dashboard then WI.Dashboard:SetStatus("Refreshing Blizzard favorites…") end

    local sent, err = pcall(C_AuctionHouse.SearchForFavorites, {})
    if not sent then
        self.syncPending = false
        if WI.Dashboard then WI.Dashboard:SetStatus("Favorites refresh failed.") end
        return false, "Favorites query failed: " .. tostring(err)
    end

    self.sessionQueries = self.sessionQueries + 1
    WI.Database.db.stats.activeQueries = WI.Database.db.stats.activeQueries + 1

    C_Timer.After(WI.constants.FAVORITES_SYNC_TIMEOUT_SECONDS, function()
        if generation == self.syncGeneration and self.syncPending then
            self.syncPending = false
            if WI.Dashboard then WI.Dashboard:SetStatus("Favorites refresh timed out; no data changed.") end
        end
    end)
    return true
end

function AuctionHouse:ProcessFavoriteResults()
    if not self.syncPending then return end

    local raw = C_AuctionHouse.GetBrowseResults() or {}
    local favorites = {}
    for _, result in ipairs(raw) do
        local itemKey = result and result.itemKey
        if itemKey and itemKey.itemID then
            local isFavorite = true
            if C_AuctionHouse.IsFavoriteItem then
                local ok, value = pcall(C_AuctionHouse.IsFavoriteItem, itemKey)
                isFavorite = ok and value == true
            end
            if isFavorite then favorites[#favorites + 1] = result end
        end
    end

    self.syncPending = false
    self.syncedThisSession = true
    local total, removed = WI.Database:SyncFavorites(favorites)
    if WI.Dashboard then
        WI.Dashboard:SetStatus(string.format("Updated %d favorite%s%s", total, total == 1 and "" or "s", removed > 0 and (" • removed " .. removed) or ""))
        WI.Dashboard:Refresh()
    end
end

function AuctionHouse:COMMODITY_SEARCH_RESULTS_UPDATED(itemID)
    if not WI.Database:IsFavoriteItemID(itemID) then return end
    local price, quantity = commoditySummary(itemID)
    if not price then return end
    local matches = WI.Database:FindFavoritesByItemID(itemID)
    if #matches == 1 then
        local recorded = WI.Database:RecordObservationByKey(matches[1], price, quantity, "passive")
        if recorded then
            self.sessionPassiveCaptures = self.sessionPassiveCaptures + 1
            if WI.Dashboard then WI.Dashboard:Refresh() end
        end
    end
end

function AuctionHouse:ITEM_SEARCH_RESULTS_UPDATED(itemKey)
    local key = WI.Util:FavoriteKey(itemKey)
    if not key or not WI.Database.db.favorites[key] then return end
    local price, quantity = itemSummary(itemKey)
    if not price then return end
    local recorded = WI.Database:RecordObservationByKey(key, price, quantity, "passive")
    if recorded then
        self.sessionPassiveCaptures = self.sessionPassiveCaptures + 1
        if WI.Dashboard then WI.Dashboard:Refresh() end
    end
end

function AuctionHouse:AUCTION_HOUSE_THROTTLED_SYSTEM_READY()
    if WI.Dashboard and self.isOpen and not self.syncPending then WI.Dashboard:SetAHStatus(true) end
end

function AuctionHouse:AUCTION_HOUSE_BROWSE_RESULTS_UPDATED()
    self:ProcessFavoriteResults()
end

function AuctionHouse:AUCTION_HOUSE_BROWSE_RESULTS_ADDED()
    if not self.syncPending then return end
    local generation = self.syncGeneration
    C_Timer.After(0.15, function()
        if generation == self.syncGeneration and self.syncPending then self:ProcessFavoriteResults() end
    end)
end

function AuctionHouse:AUCTION_HOUSE_BROWSE_FAILURE()
    if not self.syncPending then return end
    self.syncPending = false
    if WI.Dashboard then WI.Dashboard:SetStatus("Favorites refresh failed.") end
end
