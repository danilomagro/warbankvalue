local addonName, ns = ...

-- Chat output colors (AARRGGBB).
local COLOR_PREFIX = "|cffffd100" -- gold, to match the subject matter
local COLOR_ACCENT = "|cff69ccf0" -- light blue for commands and keywords
local COLOR_WARN = "|cffff8000"   -- orange for warnings
local COLOR_DEBUG = "|cff9d9d9d"  -- gray for debug output
local COLOR_RESET = "|r"

ns.CHAT_PREFIX = COLOR_PREFIX .. "[WBV]" .. COLOR_RESET .. " "

function ns.Print(msg)
    print(ns.CHAT_PREFIX .. tostring(msg))
end

function ns.PrintWarn(msg)
    print(ns.CHAT_PREFIX .. COLOR_WARN .. tostring(msg) .. COLOR_RESET)
end

function ns.Accent(text)
    return COLOR_ACCENT .. tostring(text) .. COLOR_RESET
end

-- Debug flag (set true for lightweight prints while testing).
ns.DEBUG = false
ns.dprint = function(msg)
    if ns.DEBUG then
        print(ns.CHAT_PREFIX .. COLOR_DEBUG .. tostring(msg) .. COLOR_RESET)
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
        local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
        local version = getMeta and getMeta(addonName, "Version")
        ns.Print("WarbankValue " .. (version and (ns.Accent("v" .. version) .. " ") or "") .. "loaded")
    end

    local function PrintWbvHelp()
        ns.Print(ns.Accent("/wbv show") .. " - show the panel with the last scan data")
        ns.Print(ns.Accent("/wbv missing") .. " - list items with no price data")
        ns.Print(ns.Accent("/wbv resetpos") .. " - reset the panel position")
        ns.Print(ns.Accent("/wbv minimap on|off") .. " - show or hide the minimap button")
        ns.Print(ns.Accent("/wbv status"))
        ns.Print(ns.Accent("/wbv debug on|off"))
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
                ns.Print("Debug " .. ns.Accent("enabled"))
                return
            elseif arg == "off" then
                ns.db.settings.debug = false
                ns.DEBUG = false
                ns.Print("Debug " .. ns.Accent("disabled"))
                return
            end
            ns.Print("Usage: " .. ns.Accent("/wbv debug on|off"))
            return
        elseif cmd == "show" then
            if ns.UI and ns.UI.ShowStandalone then
                ns.UI:ShowStandalone()
            end
            local scan = ns.Scanner and ns.Scanner.lastScanSummary
            if not (scan and scan.bankAccessible) then
                ns.Print("Bank values will refresh when you visit your bank.")
            end
            return
        elseif cmd == "minimap" then
            arg = arg:gsub("^%s+", ""):gsub("%s+$", "")
            if arg == "on" then
                if ns.UI and ns.UI.SetMinimapButtonShown then
                    ns.UI:SetMinimapButtonShown(true)
                end
                ns.Print("Minimap button " .. ns.Accent("shown"))
                return
            elseif arg == "off" then
                if ns.UI and ns.UI.SetMinimapButtonShown then
                    ns.UI:SetMinimapButtonShown(false)
                end
                ns.Print("Minimap button " .. ns.Accent("hidden"))
                return
            end
            ns.Print("Usage: " .. ns.Accent("/wbv minimap on|off"))
            return
        elseif cmd == "resetpos" then
            if ns.UI and ns.UI.ResetPosition then
                ns.UI:ResetPosition()
            end
            ns.Print("Panel position reset to default.")
            return
        elseif cmd == "status" then
            ns.Print("debug = " .. ns.Accent(tostring(ns.db.settings.debug)))
            return
        elseif cmd == "missing" then
            local scan = ns.Scanner and ns.Scanner.lastScanSummary
            if not scan or not scan.missingMerged then
                ns.PrintWarn("No scan data yet. Open the bank to refresh.")
                return
            end
            local list = {}
            for _, entry in pairs(scan.missingMerged) do
                table.insert(list, entry)
            end
            if #list == 0 then
                ns.Print("No missing-price items in the last scan.")
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
                ns.Print(ns.Accent("[" .. tostring(entry.source or "?") .. "]") .. " " .. tostring(entry.name or "?") .. " x" .. tostring(entry.count or 0))
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

-- On some clients (e.g. WoW: Forever) registering an unknown event throws and
-- aborts the file, so guard each registration.
local EVENTS = {
    "ADDON_LOADED",
    "BANKFRAME_OPENED",
    "BANKFRAME_CLOSED",
    "BAG_UPDATE_DELAYED",
    "GET_ITEM_INFO_RECEIVED",
    "ITEM_DATA_LOAD_RESULT",
}
for _, event in ipairs(EVENTS) do
    local ok = pcall(frame.RegisterEvent, frame, event)
    if not ok and ns.dprint then
        ns.dprint("event not available on this client: " .. event)
    end
end
