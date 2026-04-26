local addonName, ns = ...

-- Debug flag (set true for lightweight prints while testing).
ns.DEBUG = false
ns.dprint = function(msg)
    if ns.DEBUG then
        print("[WBV] " .. tostring(msg))
    end
end

ns.addonName = addonName

local frame = CreateFrame("Frame")
ns.eventFrame = frame

local function RefreshSummary()
    if ns.dprint then
        ns.dprint("refresh starts")
    end
    if ns.DEBUG and ns.Scanner and ns.Scanner.DebugAccountBankBags then
        ns.Scanner:DebugAccountBankBags()
    end
    if ns.Scanner and ns.Scanner.ScanSummary then
        ns.Scanner:ScanSummary()
    end
end

local function OnAddonLoaded(loadedAddonName)
    if loadedAddonName ~= addonName then
        return
    end

    WarbankValueDB = WarbankValueDB or {}
    ns.db = WarbankValueDB
    ns.db.settings = ns.db.settings or {}
    if ns.db.settings.debug == nil then
        ns.db.settings.debug = false
    end
    ns.DEBUG = ns.db.settings.debug

    -- Minimal startup wiring.
    if ns.UI and ns.UI.Initialize then
        ns.UI:Initialize()
    end

    if not ns._didAnnounceLoaded then
        ns._didAnnounceLoaded = true
        -- One-time chat message on addon load (as requested).
        print("[WBV] WarbankValue loaded")
    end

    local function PrintWbvHelp()
        print("[WBV] /wbv debug on|off")
        print("[WBV] /wbv missing")
        print("[WBV] /wbv status")
    end

    SLASH_WARBANKVALUE1 = "/wbv"
    SlashCmdList.WARBANKVALUE = function(msg)
        local trimmed = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local lowered = string.lower(trimmed)
        if lowered == "" or lowered == "?" or lowered == "help" then
            PrintWbvHelp()
            return
        end

        local cmd, arg = lowered:match("^(%S+)%s*(.*)$")

        if cmd == "debug" then
            arg = arg:gsub("^%s+", ""):gsub("%s+$", "")
            if arg == "on" then
                ns.db.settings.debug = true
                ns.DEBUG = true
                print("[WBV] Debug enabled")
                return
            elseif arg == "off" then
                ns.db.settings.debug = false
                ns.DEBUG = false
                print("[WBV] Debug disabled")
                return
            end
            print("[WBV] Usage: /wbv debug on|off")
            return
        elseif cmd == "status" then
            print("[WBV] debug = " .. tostring(ns.db.settings.debug))
            return
        elseif cmd == "missing" then
            local scan = ns.Scanner and ns.Scanner.lastScanSummary
            if not scan or not scan.missingMerged then
                print("[WBV] No scan data yet. Open the bank to refresh.")
                return
            end
            local list = {}
            for _, entry in pairs(scan.missingMerged) do
                table.insert(list, entry)
            end
            if #list == 0 then
                print("[WBV] No missing-price items in the last scan.")
                return
            end
            table.sort(list, function(a, b)
                local sa, sb = tostring(a.source or ""), tostring(b.source or "")
                if sa ~= sb then
                    return sa < sb
                end
                return tostring(a.name or "") < tostring(b.name or "")
            end)
            for _, entry in ipairs(list) do
                print("[WBV] [" .. tostring(entry.source or "?") .. "] " .. tostring(entry.name or "?") .. " x" .. tostring(entry.count or 0))
            end
            return
        end

        PrintWbvHelp()
    end
end

local function OnBankFrameOpened()
    if ns.dprint then
        ns.dprint("BANKFRAME_OPENED")
    end
    if ns.UI and ns.UI.Show then
        ns.UI:Show()
    end
    if ns.DEBUG and ns.Scanner and ns.Scanner.DebugAccountBankBags then
        ns.Scanner:DebugAccountBankBags()
    end
    -- Force one refresh attempt when the bank opens.
    RefreshSummary()
end

local function OnBankFrameClosed()
    if ns.dprint then
        ns.dprint("BANKFRAME_CLOSED")
    end
    if ns.UI and ns.UI.Hide then
        ns.UI:Hide()
    end
end

local function OnBagUpdateDelayed()
    if ns.UI and ns.UI.frame and ns.UI.frame:IsShown() then
        if ns.DEBUG and ns.Scanner and ns.Scanner.DebugAccountBankBags then
            ns.Scanner:DebugAccountBankBags()
        end
        RefreshSummary()
    end
end

local function OnItemDataEvent(...)
    -- GET_ITEM_INFO_RECEIVED and ITEM_DATA_LOAD_RESULT can have slightly different argument shapes
    -- across client versions. Normalize to (itemID, success).
    local a1, a2, a3 = ...
    local itemID = (type(a1) == "number" and a1) or (type(a2) == "number" and a2)

    local success
    if type(a2) == "boolean" then
        success = a2
    elseif type(a3) == "boolean" then
        success = a3
    elseif type(a2) == "number" then
        success = a2 > 0
    elseif type(a3) == "number" then
        success = a3 > 0
    else
        success = true -- If we can't tell, assume success to avoid getting stuck.
    end

    if not itemID or not success then
        return
    end

    if ns.Scanner and ns.Scanner.HasPendingItemData and ns.Scanner:HasPendingItemData(itemID) then
        ns.Scanner:ClearPendingItemData(itemID)
        RefreshSummary()
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        OnAddonLoaded(...)
    elseif event == "BANKFRAME_OPENED" then
        OnBankFrameOpened()
    elseif event == "BANKFRAME_CLOSED" then
        OnBankFrameClosed()
    elseif event == "BAG_UPDATE_DELAYED" then
        OnBagUpdateDelayed()
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        OnItemDataEvent(...)
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        OnItemDataEvent(...)
    end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
frame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
