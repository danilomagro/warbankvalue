local _, ns = ...

ns.UI = {}

local UI = ns.UI

local function FormatMoney(copper)
    local amount = copper or 0
    if amount <= 0 then
        return "0c"
    end

    return GetMoneyString(amount, true)
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
    f:SetSize(340, 337)
    f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -180)
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

    local function AddSeparator(anchorFrame)
        local sep = f:CreateTexture(nil, "ARTWORK")
        sep:SetColorTexture(0.5, 0.5, 0.5, 0.4)
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", -4, -4)
        sep:SetWidth(f:GetWidth() - 16)
        return sep
    end

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
    f.title:SetText("WarbankValue")

    f.warbandHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.warbandHeader:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
    f.warbandHeader:SetText("Warband")

    f.ahText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.ahText:SetPoint("TOPLEFT", f.warbandHeader, "BOTTOMLEFT", 0, -3)
    f.ahText:SetText("AH Total: 0c")

    f.vendorText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.vendorText:SetPoint("TOPLEFT", f.ahText, "BOTTOMLEFT", 0, -3)
    f.vendorText:SetText("Vendor Total: 0c")

    f.missingText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.missingText:SetPoint("TOPLEFT", f.vendorText, "BOTTOMLEFT", 0, -3)
    f.missingText:SetText("Missing Prices: 0")

    f.bagLines = {}
    for i = 1, 5 do
        local line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if i == 1 then
            line:SetPoint("TOPLEFT", f.missingText, "BOTTOMLEFT", 0, -5)
        else
            line:SetPoint("TOPLEFT", f.bagLines[i - 1], "BOTTOMLEFT", 0, -1)
        end
        line:SetText("")
        f.bagLines[i] = line
    end

    f.sep1 = AddSeparator(f.missingText)

    f.bankHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.bankHeader:SetPoint("TOPLEFT", f.sep1, "BOTTOMLEFT", 4, -3)
    f.bankHeader:SetText("Bank")

    f.bankAHText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.bankAHText:SetPoint("TOPLEFT", f.bankHeader, "BOTTOMLEFT", 0, -3)
    f.bankAHText:SetText("AH Total: 0c")

    f.bankVendorText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.bankVendorText:SetPoint("TOPLEFT", f.bankAHText, "BOTTOMLEFT", 0, -3)
    f.bankVendorText:SetText("Vendor Total: 0c")

    f.bankMissingText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.bankMissingText:SetPoint("TOPLEFT", f.bankVendorText, "BOTTOMLEFT", 0, -3)
    f.bankMissingText:SetText("Missing Prices: 0")

    local sep2 = AddSeparator(f.bankMissingText)

    f.totalHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.totalHeader:SetPoint("TOPLEFT", sep2, "BOTTOMLEFT", 4, -3)
    f.totalHeader:SetText("Total (Warband + Bank)")

    f.totalAHText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.totalAHText:SetPoint("TOPLEFT", f.totalHeader, "BOTTOMLEFT", 0, -3)
    f.totalAHText:SetText("AH Total: 0c")

    f.totalVendorText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.totalVendorText:SetPoint("TOPLEFT", f.totalAHText, "BOTTOMLEFT", 0, -3)
    f.totalVendorText:SetText("Vendor Total: 0c")

    local sep3 = AddSeparator(f.totalVendorText)

    f.topAHHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.topAHHeader:SetPoint("TOPLEFT", sep3, "BOTTOMLEFT", 4, -3)
    f.topAHHeader:SetText("Top AH Items")

    f.topAHLines = {}
    for i = 1, 3 do
        local line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if i == 1 then
            line:SetPoint("TOPLEFT", f.topAHHeader, "BOTTOMLEFT", 0, -3)
        else
            line:SetPoint("TOPLEFT", f.topAHLines[i - 1], "BOTTOMLEFT", 0, -2)
        end
        line:SetText("")
        f.topAHLines[i] = line
    end

    self.frame = f
    if ns.dprint then
        ns.dprint("summary frame created")
    end
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

    self.frame.ahText:SetText("AH Total: " .. FormatMoney(warband.ahValue or 0))
    self.frame.vendorText:SetText("Vendor Total: " .. FormatMoney(warband.vendorValue or 0))
    self.frame.missingText:SetText("Missing Prices: " .. tostring(warband.missingPrices or 0))

    self.frame.bankAHText:SetText("AH Total: " .. FormatMoney(bank.ahValue or 0))
    self.frame.bankVendorText:SetText("Vendor Total: " .. FormatMoney(bank.vendorValue or 0))
    self.frame.bankMissingText:SetText("Missing Prices: " .. tostring(bank.missingPrices or 0))

    self.frame.totalAHText:SetText("AH Total: " .. FormatMoney((warband.ahValue or 0) + (bank.ahValue or 0)))
    self.frame.totalVendorText:SetText("Vendor Total: " .. FormatMoney((warband.vendorValue or 0) + (bank.vendorValue or 0)))

    local breakdown = warband.bagBreakdown or summary.bagBreakdown or {}
    local lastFilledLine = nil
    for i = 1, #self.frame.bagLines do
        local line = self.frame.bagLines[i]
        local bagSummary = breakdown[i]
        if bagSummary then
            line:SetText(FormatBagBreakdownLine(bagSummary))
            lastFilledLine = line
        else
            line:SetText("")
        end
    end

    self.frame.sep1:ClearAllPoints()
    self.frame.sep1:SetPoint("TOPLEFT", lastFilledLine or self.frame.missingText, "BOTTOMLEFT", -4, -4)
    self.frame.sep1:SetWidth(self.frame:GetWidth() - 16)

    local topAHItems = summary.topAHItems or {}
    for i = 1, #self.frame.topAHLines do
        local line = self.frame.topAHLines[i]
        local item = topAHItems[i]
        if item then
            line:SetText(tostring(i) .. ". [" .. tostring(item.source or "?") .. "] " .. tostring(item.name or "Unknown") .. " - " .. FormatMoney(item.value or 0))
        else
            line:SetText("")
        end
    end
end
