local _, WI = ...

local Database = {}
WI.Database = Database

local function newDatabase()
    return {
        schemaVersion = WI.schemaVersion,
        createdAt = WI.Util:Now(),
        favorites = {},
        settings = {
            captureEnabled = true,
        },
        stats = {
            captured = 0,
            skippedDuplicates = 0,
            favoriteSyncs = 0,
            activeQueries = 0,
            passiveCaptures = 0,
        },
    }
end

function Database:Initialize()
    if type(WorthItDB) ~= "table" then WorthItDB = newDatabase() end

    WorthItDB.favorites = WorthItDB.favorites or {}
    WorthItDB.settings = WorthItDB.settings or {}
    WorthItDB.stats = WorthItDB.stats or {}
    if WorthItDB.settings.captureEnabled == nil then WorthItDB.settings.captureEnabled = true end

    local statNames = { "captured", "skippedDuplicates", "favoriteSyncs", "activeQueries", "passiveCaptures" }
    for _, name in ipairs(statNames) do WorthItDB.stats[name] = tonumber(WorthItDB.stats[name]) or 0 end

    if (tonumber(WorthItDB.schemaVersion) or 1) < 3 then
        local oldItems = WorthItDB.items or {}
        local oldSources = WorthItDB.watchSources or {}
        for itemID, sources in pairs(oldSources) do
            if type(sources) == "table" and sources.favorite == true then
                itemID = tonumber(itemID)
                if itemID then
                    local itemKey = { itemID = itemID, itemLevel = 0, itemSuffix = 0, battlePetSpeciesID = 0 }
                    local key = WI.Util:FavoriteKey(itemKey)
                    local old = oldItems[itemID] or {}
                    WorthItDB.favorites[key] = {
                        key = key,
                        itemKey = itemKey,
                        itemID = itemID,
                        name = old.name,
                        observations = old.observations or {},
                        lastSeen = old.lastSeen,
                        lastPrice = old.lastPrice,
                        lastQuantity = old.lastQuantity,
                    }
                end
            end
        end
        WorthItDB.watchlist = nil
        WorthItDB.watchSources = nil
        WorthItDB.items = nil
    end

    WorthItDB.schemaVersion = WI.schemaVersion
    self.db = WorthItDB
    self:PruneAll()
end

function Database:GetFavorite(key, create, itemKey)
    if not self.db or not key then return nil end
    local favorite = self.db.favorites[key]
    if not favorite and create and itemKey then
        favorite = {
            key = key,
            itemKey = WI.Util:CopyItemKey(itemKey),
            itemID = tonumber(itemKey.itemID),
            observations = {},
        }
        self.db.favorites[key] = favorite
    end
    if favorite then favorite.observations = favorite.observations or {} end
    return favorite
end

function Database:IsFavoriteItemID(itemID)
    itemID = tonumber(itemID)
    if not itemID then return false end
    for _, favorite in pairs(self.db.favorites) do
        if favorite.itemID == itemID then return true end
    end
    return false
end

function Database:FindFavoritesByItemID(itemID)
    itemID = tonumber(itemID)
    local matches = {}
    if not itemID then return matches end
    for key, favorite in pairs(self.db.favorites) do
        if favorite.itemID == itemID then matches[#matches + 1] = key end
    end
    return matches
end

function Database:SyncFavorites(results)
    local desired = {}
    local count = 0

    for _, result in ipairs(results or {}) do
        local itemKey = result and result.itemKey
        local key = WI.Util:FavoriteKey(itemKey)
        if key and not desired[key] then
            desired[key] = true
            count = count + 1
            local favorite = self:GetFavorite(key, true, itemKey)
            favorite.itemKey = WI.Util:CopyItemKey(itemKey)
            favorite.itemID = tonumber(itemKey.itemID)
            favorite.name = WI.Util:GetItemName(favorite.itemID, favorite.name)
            favorite.missingSyncs = nil
            local price = tonumber(result.minPrice)
            if price and price > 0 then
                self:RecordObservationByKey(key, price, tonumber(result.totalQuantity) or 0, "favorite")
            end
        end
    end

    local remove = {}
    for key, favorite in pairs(self.db.favorites) do
        if not desired[key] then
            favorite.missingSyncs = (tonumber(favorite.missingSyncs) or 0) + 1
            if favorite.missingSyncs >= 2 then remove[#remove + 1] = key end
        end
    end
    for _, key in ipairs(remove) do self.db.favorites[key] = nil end

    self.db.stats.favoriteSyncs = self.db.stats.favoriteSyncs + 1
    return count, #remove
end

function Database:RecordObservationByKey(key, unitPrice, quantity, source)
    if not self.db or not self.db.settings.captureEnabled then return false, "capture-disabled" end

    local favorite = self:GetFavorite(key, false)
    unitPrice = tonumber(unitPrice)
    quantity = tonumber(quantity) or 0
    if not favorite or not unitPrice or unitPrice <= 0 then return false, "invalid-observation" end

    local now = WI.Util:Now()
    local observations = favorite.observations
    local last = observations[#observations]

    if last and last.price == unitPrice and (now - last.time) < WI.constants.MIN_SAMPLE_INTERVAL then
        self.db.stats.skippedDuplicates = self.db.stats.skippedDuplicates + 1
        favorite.lastSeen = now
        favorite.lastPrice = math.floor(unitPrice)
        favorite.lastQuantity = math.max(0, math.floor(quantity))
        return false, "duplicate"
    end

    observations[#observations + 1] = {
        time = now,
        price = math.floor(unitPrice),
        quantity = math.max(0, math.floor(quantity)),
        source = source or "unknown",
    }
    favorite.lastSeen = now
    favorite.lastPrice = math.floor(unitPrice)
    favorite.lastQuantity = math.max(0, math.floor(quantity))
    favorite.name = WI.Util:GetItemName(favorite.itemID, favorite.name)
    self.db.stats.captured = self.db.stats.captured + 1
    if source == "passive" then self.db.stats.passiveCaptures = self.db.stats.passiveCaptures + 1 end
    self:PruneFavorite(favorite)
    return true
end

function Database:RecordPassiveItem(itemKey, unitPrice, quantity)
    local key = WI.Util:FavoriteKey(itemKey)
    if key and self.db.favorites[key] then
        return self:RecordObservationByKey(key, unitPrice, quantity, "passive")
    end

    local itemID = itemKey and tonumber(itemKey.itemID)
    local matches = self:FindFavoritesByItemID(itemID)
    if #matches == 1 then return self:RecordObservationByKey(matches[1], unitPrice, quantity, "passive") end
    return false, "not-favorite"
end

function Database:GetFavorites()
    local results = {}
    for _, favorite in pairs(self.db.favorites) do results[#results + 1] = favorite end
    table.sort(results, function(a, b)
        local aName = string.lower(a.name or "")
        local bName = string.lower(b.name or "")
        if aName == bName then return (a.key or "") < (b.key or "") end
        return aName < bName
    end)
    return results
end

function Database:PruneFavorite(favorite)
    if not favorite or not favorite.observations then return end
    local cutoff = WI.Util:Now() - WI.constants.RETENTION_SECONDS
    local kept = {}
    for _, observation in ipairs(favorite.observations) do
        if observation.time and observation.time >= cutoff then kept[#kept + 1] = observation end
    end
    local excess = #kept - WI.constants.MAX_OBSERVATIONS_PER_FAVORITE
    if excess > 0 then
        local trimmed = {}
        for index = excess + 1, #kept do trimmed[#trimmed + 1] = kept[index] end
        kept = trimmed
    end
    favorite.observations = kept
end

function Database:PruneAll()
    if not self.db then return end
    for _, favorite in pairs(self.db.favorites) do self:PruneFavorite(favorite) end
end

function Database:Reset()
    WorthItDB = newDatabase()
    self.db = WorthItDB
end
