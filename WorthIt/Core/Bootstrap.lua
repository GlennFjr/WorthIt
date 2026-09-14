local _, WI = ...

local Bootstrap = CreateFrame("Frame")
Bootstrap:RegisterEvent("ADDON_LOADED")
Bootstrap:RegisterEvent("PLAYER_LOGIN")

Bootstrap:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == WI.name then
        WI.Database:Initialize()
        WI.AuctionHouse:Initialize()
        WI.Dashboard:Initialize()
        WI.Commands:Initialize()
    elseif event == "PLAYER_LOGIN" then
        local _, _, _, interfaceVersion = GetBuildInfo()
        if interfaceVersion and interfaceVersion < 120100 then
            WI.Util:SafePrint("Warning: WorthIt targets Retail interface 120100+; your client reports " .. tostring(interfaceVersion) .. ".")
        end
        WI.Util:SafePrint("v" .. WI.version .. " loaded. Favorite items in Blizzard's Auction House, then type /worthit.")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
