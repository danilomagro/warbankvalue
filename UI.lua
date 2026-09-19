local _, ns = ...

ns.UI = {}

local UI = ns.UI

local FRAME_WIDTH = 340
local DEFAULT_POSITION = { x = 50, y = -180 }

local function FormatMoney(copper)
    local amount = copper or 0
    if amount <= 0 then
        return "0c"
    end

    return GetMoneyString(amount, true)
end

-- Wrap an item name in its quality color, as the game does everywhere else.
local function ColorizeItemName(item)
    local name = tostring(item.name or "Unknown")
    local getItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local quality
    if C_Item and C_Item.GetItemQualityByID and item.itemID then
        quality = C_Item.GetItemQualityByID(item.itemID)
    end
    if not quality and getItemInfo and (item.itemLink or item.itemID) then
        quality = select(3, getItemInfo(item.itemLink or item.itemID))
    end

    local color = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if color and color.hex then
        return color.hex .. name .. "|r"
    end
    return name
end

local function FormatBagBreakdownLine(bagSummary)
    local label = bagSummary.tabIndex and ("Tab " .. tostring(bagSummary.tabIndex)) or ("Bag " .. tostring(bagSummary.bagID))
    return label .. ": AH " .. FormatMoney(bagSummary.ahValue or 0)
        .. " | Vendor " .. FormatMoney(bagSummary.vendorValue or 0)
end

function UI:Initialize()
    if self.frame then
        return
    end

    local f = CreateFrame("Frame", "WarbankValueSummaryFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, 100) -- Height is recomputed by Relayout.
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DEFAULT_POSITION.x, DEFAULT_POSITION.y)
    f:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        ns.db.settings.framePos = {
            x = f:GetLeft(),
            y = f:GetTop() - UIParent:GetHeight(),
        }
    end)
    f:Hide()

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    f.title:SetText("WarbankValue")

    -- Ordered list of layout entries; Relayout anchors the visible ones in
    -- sequence below the title and resizes the frame to fit.
    f.layout = {}

    local function AddEntry(anchor, gap, isSep, extraPart)
        local entry = {
            anchor = anchor,
            gap = gap,
            isSep = isSep or false,
            visible = true,
            parts = { anchor },
        }
        if extraPart then
            table.insert(entry.parts, extraPart)
        end
        table.insert(f.layout, entry)
        return entry
    end

    local function AddHeader(text, gap)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetText(text)
        return AddEntry(fs, gap)
    end

    -- Label on the left, value right-aligned on the same line.
    local function AddStatRow(labelText)
        local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetText(labelText)
        local value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        value:SetPoint("TOP", label, "TOP", 0, 0)
        value:SetPoint("RIGHT", f, "RIGHT", -12, 0)
        value:SetJustifyH("RIGHT")
        value:SetText("")
        local entry = AddEntry(label, 3, false, value)
        entry.valueFS = value
        return entry
    end

    local function AddSeparator()
        local sep = f:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(0.5, 0.5, 0.5, 0.4)
        sep:SetHeight(1)
        sep:SetWidth(FRAME_WIDTH - 16)
        return AddEntry(sep, 4, true)
    end

    local function AddTextLine(gap)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetText("")
        return AddEntry(fs, gap)
    end

    local notice = f:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    notice:SetWidth(FRAME_WIDTH - 24)
    notice:SetJustifyH("LEFT")
    notice:SetText("Auctionator not detected - AH prices unavailable")
    f.entryNotice = AddEntry(notice, 8)

    f.entryWarbandHeader = AddHeader("Warband", 8)
    f.entryWarbandAH = AddStatRow("AH Total")
    f.entryWarbandVendor = AddStatRow("Vendor Total")
    f.entryWarbandMissing = AddStatRow("Missing Prices")
    f.entryWarbandMissing.anchor:SetTextColor(1, 0.55, 0)
    f.entryWarbandMissing.valueFS:SetTextColor(1, 0.55, 0)

    f.bagEntries = {}
    for i = 1, 5 do
        f.bagEntries[i] = AddTextLine(i == 1 and 5 or 1)
    end

    f.entrySep1 = AddSeparator()

    f.entryBankHeader = AddHeader("Bank", 3)
    f.entryBankAH = AddStatRow("AH Total")
    f.entryBankVendor = AddStatRow("Vendor Total")
    f.entryBankMissing = AddStatRow("Missing Prices")
    f.entryBankMissing.anchor:SetTextColor(1, 0.55, 0)
    f.entryBankMissing.valueFS:SetTextColor(1, 0.55, 0)

    f.entrySepBags = AddSeparator()

    f.entryBagsHeader = AddHeader("Bags", 3)
    f.entryBagsAH = AddStatRow("AH Total")
    f.entryBagsVendor = AddStatRow("Vendor Total")
    f.entryBagsMissing = AddStatRow("Missing Prices")
    f.entryBagsMissing.anchor:SetTextColor(1, 0.55, 0)
    f.entryBagsMissing.valueFS:SetTextColor(1, 0.55, 0)

    f.entrySep2 = AddSeparator()

    f.entryTotalHeader = AddHeader("Total", 3)
    f.entryTotalAH = AddStatRow("AH Total")
    f.entryTotalVendor = AddStatRow("Vendor Total")

    f.entrySep3 = AddSeparator()

    f.entryTopHeader = AddHeader("Top AH Items", 3)
    f.topAHEntries = {}
    for i = 1, 3 do
        local entry = AddTextLine(i == 1 and 3 or 2)
        -- A fixed width lets the engine ellipsize long item names instead of
        -- letting them run past the panel.
        entry.anchor:SetWidth(FRAME_WIDTH - 24)
        entry.anchor:SetWordWrap(false)
        entry.anchor:SetJustifyH("LEFT")

        -- FontStrings take no mouse input, so an invisible frame on top of
        -- the line provides the hover area for the item tooltip.
        local hover = CreateFrame("Frame", nil, f)
        hover:SetAllPoints(entry.anchor)
        hover:EnableMouse(true)
        hover:SetScript("OnEnter", function(self)
            if not self.itemLink and not self.itemID then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.itemLink then
                GameTooltip:SetHyperlink(self.itemLink)
            else
                GameTooltip:SetItemByID(self.itemID)
            end
            GameTooltip:Show()
        end)
        hover:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        entry.hover = hover
        table.insert(entry.parts, hover)

        f.topAHEntries[i] = entry
    end

    -- Conditional entries start hidden until the first scan fills them in.
    f.entryNotice.visible = false
    f.entryWarbandMissing.visible = false
    f.entryBankMissing.visible = false
    f.entryBagsMissing.visible = false
    f.entrySep3.visible = false
    f.entryTopHeader.visible = false
    for i = 1, #f.bagEntries do
        f.bagEntries[i].visible = false
    end
    for i = 1, #f.topAHEntries do
        f.topAHEntries[i].visible = false
    end

    self.frame = f
    self:Relayout()
    self:InitializeMinimapButton()
    if ns.dprint then
        ns.dprint("summary frame created")
    end
end

function UI:Relayout()
    local f = self.frame
    if not f then
        return
    end

    local prev = f.title
    local prevIsSep = false
    local totalHeight = 10 + (f.title:GetStringHeight() or 12)

    for _, entry in ipairs(f.layout) do
        if entry.visible then
            for _, part in ipairs(entry.parts) do
                part:Show()
            end

            -- Separators extend 4px left of the text column; whatever follows
            -- one needs the matching +4 to return to the column.
            local dx = 0
            if entry.isSep then
                dx = prevIsSep and 0 or -4
            elseif prevIsSep then
                dx = 4
            end

            entry.anchor:ClearAllPoints()
            entry.anchor:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", dx, -entry.gap)
            prev = entry.anchor
            prevIsSep = entry.isSep

            local height
            if entry.anchor.GetStringHeight then
                height = entry.anchor:GetStringHeight()
            else
                height = entry.anchor:GetHeight()
            end
            totalHeight = totalHeight + entry.gap + (height or 12)
        else
            for _, part in ipairs(entry.parts) do
                part:Hide()
            end
        end
    end

    f:SetHeight(math.floor(totalHeight + 12 + 0.5))
end

function UI:GetWarbandBankParent()
    if _G.BankPanel then
        return _G.BankPanel, "BankPanel"
    end
    if _G.AccountBankPanel then
        return _G.AccountBankPanel, "AccountBankPanel"
    end
    if _G.BankFrame then
        return _G.BankFrame, "BankFrame"
    end

    return nil, nil
end

function UI:AttachToWarbandBank()
    if not self.frame then
        return false
    end

    local parent, parentType = self:GetWarbandBankParent()
    if not parent then
        if ns.dprint then
            ns.dprint("No bank parent found")
        end
        return false
    end

    self.frame:ClearAllPoints()
    self.frame:SetParent(parent)
    -- To the right of bank UI, inset moderately so the panel stays readable and less intrusive.
    local anchorParent = _G.BankFrame or parent
    local point, relativePoint, xOfs, yOfs = "TOPLEFT", "TOPRIGHT", 140, -84
    self.frame:SetPoint(point, anchorParent, relativePoint, xOfs, yOfs)
    self.parentFrame = parent
    self.parentFrameType = parentType

    if ns.dprint then
        local anchorParentName = anchorParent.GetName and anchorParent:GetName() or parentType
        ns.dprint("Attached to " .. tostring(parentType) .. " anchorParent=" .. tostring(anchorParentName) .. " anchor=" .. point .. "->" .. relativePoint .. " (" .. xOfs .. "," .. yOfs .. ")")
    end
    return true
end

function UI:Show()
    if self.frame then
        local attached = self:AttachToWarbandBank()
        if attached then
            local pos = ns.db.settings and ns.db.settings.framePos
            if pos then
                self.frame:ClearAllPoints()
                self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x, pos.y)
            end
            self.frame:Show()
            if ns.dprint then
                ns.dprint("summary frame shown")
            end
        else
            self.frame:Hide()
        end
    end
end

-- Show the panel outside the bank (e.g. via /wbv show), using the last scan data.
function UI:ShowStandalone()
    if not self.frame then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetParent(UIParent)
    local pos = ns.db and ns.db.settings and ns.db.settings.framePos
    if pos then
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x, pos.y)
    else
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DEFAULT_POSITION.x, DEFAULT_POSITION.y)
    end
    self.frame:Show()

    -- Rescan so the Bags section is live anywhere; bank sections fall back
    -- to the last scan when the bank is not accessible.
    if ns.Scanner and ns.Scanner.ScanSummary then
        ns.Scanner:ScanSummary()
    end
end

function UI:ResetPosition()
    if ns.db and ns.db.settings then
        ns.db.settings.framePos = nil
        if ns.db.settings.minimap then
            ns.db.settings.minimap.angle = nil
            ns.db.settings.minimap.radius = nil
        end
    end
    if self.frame and self.frame:IsShown() then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", DEFAULT_POSITION.x, DEFAULT_POSITION.y)
    end
    if self.UpdateMinimapButtonPosition then
        self:UpdateMinimapButtonPosition()
    end
end

-- Distance from the minimap centre to the button. The frame's own size only
-- gives a starting point: Classic-style minimap art (WoW: Forever) draws a
-- decorative border beyond the frame, so the default can still land on it.
-- Dragging the button adjusts the distance as well as the angle.
local function GetMinimapFrameRadius()
    local width = (Minimap and Minimap:GetWidth()) or 140
    if width <= 0 then
        width = 140
    end
    return width / 2
end

local function GetDefaultMinimapRadius()
    return GetMinimapFrameRadius() + 10
end

function UI:InitializeMinimapButton()
    if self.minimapButton or not Minimap then
        return
    end

    local settings = ns.db.settings
    settings.minimap = settings.minimap or {}
    if settings.minimap.show == nil then
        settings.minimap.show = true
    end
    settings.minimap.angle = settings.minimap.angle or 215

    local btn = CreateFrame("Button", "WarbankValueMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:RegisterForClicks("LeftButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetHighlightTexture("Interface/Minimap/UI-Minimap-ZoomButton-Highlight")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface/Minimap/MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface/Icons/INV_Misc_Coin_02")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("CENTER", 0, 1)

    local function UpdatePosition()
        local angle = math.rad(settings.minimap.angle or 215)
        local radius = settings.minimap.radius or GetDefaultMinimapRadius()
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER",
            math.cos(angle) * radius, math.sin(angle) * radius)
    end
    self.UpdateMinimapButtonPosition = UpdatePosition

    -- An addon may resize the minimap after us (Leatrix Plus and friends do).
    if Minimap.HookScript then
        Minimap:HookScript("OnSizeChanged", UpdatePosition)
    end

    local Atan2 = math.atan2 or math.atan
    local function OnDragUpdate()
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local dx, dy = cx - mx, cy - my

        settings.minimap.angle = math.deg(Atan2(dy, dx))

        -- Follow the cursor outwards too, so the button clears whatever
        -- border art this client draws; keep it near the minimap though.
        local frameRadius = GetMinimapFrameRadius()
        local radius = math.sqrt(dx * dx + dy * dy)
        settings.minimap.radius = math.max(frameRadius * 0.6, math.min(radius, frameRadius + 60))

        UpdatePosition()
    end

    btn:SetScript("OnDragStart", function(button)
        button:SetScript("OnUpdate", OnDragUpdate)
    end)
    btn:SetScript("OnDragStop", function(button)
        button:SetScript("OnUpdate", nil)
    end)

    btn:SetScript("OnClick", function()
        if UI.frame and UI.frame:IsShown() then
            UI:Hide()
        else
            UI:ShowStandalone()
        end
    end)

    btn:SetScript("OnEnter", function(button)
        -- Refresh so the tooltip totals are current, but rescan at most every
        -- few seconds: with a full bank a scan is not free, and repeated
        -- hovers would otherwise trigger it every time.
        if ns.Scanner and ns.Scanner.ScanSummary then
            local lastScanAt = ns.Scanner.lastScanAt or 0
            if GetTime() - lastScanAt > 5 then
                ns.Scanner:ScanSummary()
            end
        end

        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine("WarbankValue", 1, 0.82, 0)
        local scan = ns.Scanner and ns.Scanner.lastScanSummary
        if scan then
            local warband = scan.warband or {}
            local bank = scan.bank or {}
            local bags = scan.bags or {}
            local ah = (warband.ahValue or 0) + (bank.ahValue or 0) + (bags.ahValue or 0)
            local vendor = (warband.vendorValue or 0) + (bank.vendorValue or 0) + (bags.vendorValue or 0)
            GameTooltip:AddDoubleLine("AH Total", FormatMoney(ah), 1, 1, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("Vendor Total", FormatMoney(vendor), 1, 1, 1, 1, 1, 1)
        else
            GameTooltip:AddLine("No scan data yet", 0.6, 0.6, 0.6)
        end
        GameTooltip:AddLine("Click to toggle the summary panel", 0, 1, 0)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = btn
    UpdatePosition()
    if settings.minimap.show then
        btn:Show()
    else
        btn:Hide()
    end
end

function UI:SetMinimapButtonShown(show)
    if ns.db and ns.db.settings then
        ns.db.settings.minimap = ns.db.settings.minimap or {}
        ns.db.settings.minimap.show = show and true or false
    end
    if self.minimapButton then
        if show then
            self.minimapButton:Show()
        else
            self.minimapButton:Hide()
        end
    end
end

function UI:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function UI:UpdateSummary(summary)
    if not self.frame then
        return
    end

    summary = summary or {}
    local warband = summary.warband or summary
    local bank = summary.bank or {}
    local bags = summary.bags or {}
    local f = self.frame

    f.entryNotice.visible = summary.auctionatorAvailable == false

    -- Stored sections appear only once a scan with the bank open has seen
    -- them. Before that (and on clients with no account bank, e.g. WoW:
    -- Forever) showing zeros would claim the storage is empty. Each section
    -- carries the separator that follows it, so no stray lines are left.
    local hasWarband = summary.warbandBankAvailable == true
    local hasBank = summary.bankAccessible == true
    local hasTotal = hasWarband or hasBank

    f.entryWarbandHeader.visible = hasWarband
    f.entryWarbandAH.visible = hasWarband
    f.entryWarbandVendor.visible = hasWarband
    f.entrySep1.visible = hasWarband

    f.entryBankHeader.visible = hasBank
    f.entryBankAH.visible = hasBank
    f.entryBankVendor.visible = hasBank
    f.entrySepBags.visible = hasBank

    f.entrySep2.visible = hasTotal
    f.entryTotalHeader.visible = hasTotal
    f.entryTotalAH.visible = hasTotal
    f.entryTotalVendor.visible = hasTotal

    f.entryWarbandAH.valueFS:SetText(FormatMoney(warband.ahValue or 0))
    f.entryWarbandVendor.valueFS:SetText(FormatMoney(warband.vendorValue or 0))
    local warbandMissing = warband.missingPrices or 0
    f.entryWarbandMissing.visible = hasWarband and warbandMissing > 0
    f.entryWarbandMissing.valueFS:SetText(tostring(warbandMissing))

    f.entryBankAH.valueFS:SetText(FormatMoney(bank.ahValue or 0))
    f.entryBankVendor.valueFS:SetText(FormatMoney(bank.vendorValue or 0))
    local bankMissing = bank.missingPrices or 0
    f.entryBankMissing.visible = hasBank and bankMissing > 0
    f.entryBankMissing.valueFS:SetText(tostring(bankMissing))

    f.entryBagsAH.valueFS:SetText(FormatMoney(bags.ahValue or 0))
    f.entryBagsVendor.valueFS:SetText(FormatMoney(bags.vendorValue or 0))
    local bagsMissing = bags.missingPrices or 0
    f.entryBagsMissing.visible = bagsMissing > 0
    f.entryBagsMissing.valueFS:SetText(tostring(bagsMissing))

    f.entryTotalAH.valueFS:SetText(FormatMoney((warband.ahValue or 0) + (bank.ahValue or 0) + (bags.ahValue or 0)))
    f.entryTotalVendor.valueFS:SetText(FormatMoney((warband.vendorValue or 0) + (bank.vendorValue or 0) + (bags.vendorValue or 0)))

    local breakdown = warband.bagBreakdown or summary.bagBreakdown or {}
    for i = 1, #f.bagEntries do
        local entry = f.bagEntries[i]
        local bagSummary = hasWarband and breakdown[i] or nil
        if bagSummary then
            entry.anchor:SetText(FormatBagBreakdownLine(bagSummary))
            entry.visible = true
        else
            entry.anchor:SetText("")
            entry.visible = false
        end
    end

    local topAHItems = summary.topAHItems or {}
    for i = 1, #f.topAHEntries do
        local entry = f.topAHEntries[i]
        local item = topAHItems[i]
        if item then
            entry.anchor:SetText(tostring(i) .. ". [" .. tostring(item.source or "?") .. "] "
                .. ColorizeItemName(item) .. " - " .. FormatMoney(item.value or 0))
            entry.hover.itemLink = item.itemLink
            entry.hover.itemID = item.itemID
            entry.visible = true
        else
            entry.anchor:SetText("")
            entry.hover.itemLink = nil
            entry.hover.itemID = nil
            entry.visible = false
        end
    end
    local hasTopItems = topAHItems[1] ~= nil
    f.entrySep3.visible = hasTopItems
    f.entryTopHeader.visible = hasTopItems

    self:Relayout()
end
