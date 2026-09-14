local _, WI = ...

local Commands = {}
WI.Commands = Commands

local function splitFirst(message)
    local command, rest = string.match(message or "", "^%s*(%S*)%s*(.-)%s*$")
    return string.lower(command or ""), rest or ""
end

function Commands:Initialize()
    SLASH_WORTHIT1 = "/worthit"
    SLASH_WORTHIT2 = "/wit"
    SlashCmdList.WORTHIT = function(message) self:Handle(message) end
end

function Commands:Help()
    WI.Util:SafePrint("Commands:")
    print("  /worthit - open/close dashboard")
    print("  /worthit refresh - update Blizzard favorites and prices")
    print("  /worthit stats - show data and query statistics")
    print("  /worthit reset CONFIRM - erase local WorthIt data")
end

function Commands:Handle(message)
    local command, rest = splitFirst(message)

    if command == "" then
        WI.Dashboard:Toggle()
    elseif command == "help" then
        self:Help()
    elseif command == "refresh" or command == "favorites" then
        local ok, err = WI.AuctionHouse:SyncFavorites(true)
        if not ok then WI.Util:SafePrint(err) end
    elseif command == "stats" then
        local db = WI.Database.db
        local brief = WI.PriceEngine:GetBrief()
        WI.Util:SafePrint(string.format(
            "%d favorites • %d observations • %d high-confidence • %d learning • %d duplicates skipped • %d WorthIt AH queries total • %d this session • %d passive captures this session.",
            brief.total, db.stats.captured, brief.highConfidence, brief.learning, db.stats.skippedDuplicates,
            db.stats.activeQueries, WI.AuctionHouse.sessionQueries or 0, WI.AuctionHouse.sessionPassiveCaptures or 0
        ))
    elseif command == "reset" and string.upper(rest) == "CONFIRM" then
        WI.Database:Reset()
        WI.Dashboard.currentPage = 1
        WI.Dashboard.selectedKey = nil
        WI.Dashboard:ShowTab("overview")
        WI.Dashboard:Refresh()
        WI.Util:SafePrint("All local WorthIt data has been reset. Reopen the Auction House to restore favorites.")
    else
        self:Help()
    end
end
