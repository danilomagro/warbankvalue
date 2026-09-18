local _, ns = ...

ns.Scanner = {}

local Scanner = ns.Scanner
local ACCOUNT_BANK_BAG_IDS = {
    Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 or 12,
    Enum.BagIndex and Enum.BagIndex.AccountBankTab_2 or 13,
    Enum.BagIndex and Enum.BagIndex.AccountBankTab_3 or 14,
    Enum.BagIndex and Enum.BagIndex.AccountBankTab_4 or 15,
    Enum.BagIndex and Enum.BagIndex.AccountBankTab_5 or 16,
}
-- Carried inventory: backpack, the four bags, and the reagent bag where it exists.
local INVENTORY_BAG_IDS = {}
do
    local function add(id)
        if id ~= nil then
            table.insert(INVENTORY_BAG_IDS, id)
        end
    end
    add(Enum.BagIndex and Enum.BagIndex.Backpack or 0)
    for i = 1, 4 do
        add((Enum.BagIndex and Enum.BagIndex["Bag_" .. i]) or i)
    end
    add(Enum.BagIndex and Enum.BagIndex.ReagentBag)
end

-- Bank containers, derived from Enum.BagIndex when available. The historical
-- raw IDs 5-11 are only a last resort: on modern clients bag 5 is the carried
-- reagent bag, and bank bags start at 6.
local NORMAL_BANK_BAG_CANDIDATES = {}
do
    local inventorySet = {}
    for _, id in ipairs(INVENTORY_BAG_IDS) do
        inventorySet[id] = true
    end

    local seen = {}
    local function add(id)
        if id ~= nil and not seen[id] and not inventorySet[id] then
            seen[id] = true
            table.insert(NORMAL_BANK_BAG_CANDIDATES, id)
        end
    end

    add(Enum.BagIndex and Enum.BagIndex.Bank or -1) -- Main bank container
    if Enum.BagIndex then
        for i = 1, 7 do
            add(Enum.BagIndex["BankBag_" .. i])
        end
        for i = 1, 6 do
            add(Enum.BagIndex["CharacterBankTab_" .. i])
        end
    end
    if #NORMAL_BANK_BAG_CANDIDATES <= 1 then
        for id = 5, 11 do
            add(id)
        end
    end
end

local pendingItemIDs = {}

local function IsAuctionatorAvailable()
    return Auctionator and Auctionator.API and Auctionator.API.v1 and (
        Auctionator.API.v1.GetAuctionPriceByItemLink or Auctionator.API.v1.GetAuctionPriceByItemID
    )
end

local function GetItemBindType(slotInfo)
    if not slotInfo or (not slotInfo.itemLink and not slotInfo.itemID) then
        return nil
    end

    if slotInfo.bindType ~= nil then
        return slotInfo.bindType
    end

    local _, _, _, _, _, _, _, _, _, _, _, _, _, bindType = GetItemInfo(slotInfo.itemLink or slotInfo.itemID)
    return bindType
end

local function GetWarboundUntilEquippedBindTypes()
    local bindTypes = {}

    if Enum and Enum.ItemBind then
        for name, value in pairs(Enum.ItemBind) do
            if type(name) == "string" and type(value) == "number" then
                local lowered = string.lower(name)
                if string.find(lowered, "warbound") and string.find(lowered, "equip") then
                    bindTypes[value] = true
                end
            end
        end
    end

    return bindTypes
end

local NON_AUCTIONABLE_BIND_REASONS = {
    warbound_until_equipped = {
        bindTypes = GetWarboundUntilEquippedBindTypes(),
        tooltipTexts = {
            _G.ITEM_BIND_TO_WARBOUND_UNTIL_EQUIP or "Warbound until equipped",
        },
    },
    warbound = {
        bindTypes = {},
        tooltipTexts = {
            _G.ITEM_BIND_TO_WARBOUND or "Warbound",
            _G.ITEM_BIND_TO_BNETACCOUNT or "Account Bound",
        },
    },
    soulbound = {
        bindTypes = {},
        tooltipTexts = {
            _G.ITEM_SOULBOUND or "Soulbound",
        },
    },
    bind_on_pickup = {
        bindTypes = {},
        tooltipTexts = {
            _G.ITEM_BIND_ON_PICKUP or "Binds when picked up",
            _G.ITEM_BIND_ON_ACQUIRE,
        },
    },
}

if Enum and Enum.ItemBind then
    for name, value in pairs(Enum.ItemBind) do
        if type(name) == "string" and type(value) == "number" then
            local lowered = string.lower(name)
            if string.find(lowered, "soul") then
                NON_AUCTIONABLE_BIND_REASONS.soulbound.bindTypes[value] = true
            end
            if string.find(lowered, "pickup") or string.find(lowered, "acquire") then
                NON_AUCTIONABLE_BIND_REASONS.bind_on_pickup.bindTypes[value] = true
            end
            if (string.find(lowered, "warbound") and not string.find(lowered, "equip"))
                or string.find(lowered, "account")
                or string.find(lowered, "bnet") then
                NON_AUCTIONABLE_BIND_REASONS.warbound.bindTypes[value] = true
            end
        end
    end
end

local function BuildExpectedTooltipLookup(expectedTexts)
    local expectedLookup = {}
    for _, text in ipairs(expectedTexts or {}) do
        if text and text ~= "" then
            expectedLookup[string.lower(tostring(text))] = true
        end
    end
    return expectedLookup
end

local function TooltipDataHasText(tooltipData, expectedLookup)
    local lines = tooltipData and tooltipData.lines
    if not lines then
        return false
    end

    for _, line in ipairs(lines) do
        local leftText = line and line.leftText
        if leftText and expectedLookup[string.lower(leftText)] then
            return true
        end
    end

    return false
end

local BANK_CONTAINER = Enum.BagIndex and Enum.BagIndex.Bank or -1

local function BagTooltipHasText(slotInfo, expectedLookup)
    if not slotInfo or not slotInfo.bagID or not slotInfo.slotIndex or not C_TooltipInfo then
        return false
    end

    local tooltipData
    if slotInfo.bagID == BANK_CONTAINER and C_TooltipInfo.GetBankItem then
        tooltipData = C_TooltipInfo.GetBankItem(slotInfo.slotIndex)
    elseif C_TooltipInfo.GetBagItem then
        tooltipData = C_TooltipInfo.GetBagItem(slotInfo.bagID, slotInfo.slotIndex)
    end
    return TooltipDataHasText(tooltipData, expectedLookup)
end

local function HyperlinkTooltipHasText(slotInfo, expectedLookup)
    if not slotInfo or not slotInfo.itemLink or not C_TooltipInfo or not C_TooltipInfo.GetHyperlink then
        return false
    end

    local tooltipData = C_TooltipInfo.GetHyperlink(slotInfo.itemLink)
    return TooltipDataHasText(tooltipData, expectedLookup)
end

local function GetNonAuctionableBindState(slotInfo)
    local bindType = GetItemBindType(slotInfo)
    for reason, data in pairs(NON_AUCTIONABLE_BIND_REASONS) do
        if bindType and data.bindTypes and data.bindTypes[bindType] then
            return reason, "bindType"
        end
    end

    for reason, data in pairs(NON_AUCTIONABLE_BIND_REASONS) do
        local expectedLookup = BuildExpectedTooltipLookup(data.tooltipTexts)
        if BagTooltipHasText(slotInfo, expectedLookup) then
            return reason, "bag tooltip"
        end
        if HyperlinkTooltipHasText(slotInfo, expectedLookup) then
            return reason, "link tooltip"
        end
    end

    return nil, nil
end

local function IsAHEligible(slotInfo)
    if not slotInfo then
        return false, "no_item"
    end

    if slotInfo.isBound then
        return false, "bound"
    end

    local nonAuctionableReason, matchSource = GetNonAuctionableBindState(slotInfo)
    if nonAuctionableReason then
        if ns.DEBUG then
            ns.dprint("excluded from AH: " .. tostring(nonAuctionableReason) .. " (" .. tostring(matchSource or "unknown") .. ") itemID=" .. tostring(slotInfo.itemID) .. " bindType=" .. tostring(slotInfo.bindType))
        end
        return false, nonAuctionableReason
    end

    return true, "auction_eligible"
end

local function GetAuctionatorPrice(slotInfo)
    if not slotInfo then
        return nil
    end

    if not IsAuctionatorAvailable() then
        return nil
    end

    -- Auctionator public API typically requires a caller name as the first argument.
    if slotInfo.itemLink and Auctionator.API.v1.GetAuctionPriceByItemLink then
        return Auctionator.API.v1.GetAuctionPriceByItemLink(ns.addonName or "WarbankValue", slotInfo.itemLink)
    end

    if slotInfo.itemID and Auctionator.API.v1.GetAuctionPriceByItemID then
        return Auctionator.API.v1.GetAuctionPriceByItemID(ns.addonName or "WarbankValue", slotInfo.itemID)
    end

    return nil
end

local function GetBlizzardVendorSellPrice(itemLink, itemID)
    if not itemLink and not itemID then
        return 0
    end

    -- Use Blizzard item info API for vendor value (not Auctionator vendor APIs).
    local _, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemLink or itemID)
    return sellPrice or 0
end

local function GetItemDisplayName(itemLink, itemID)
    if itemLink then
        local name = GetItemInfo(itemLink)
        if name and name ~= "" then
            return name
        end
    end
    if itemID then
        local byID = C_Item.GetItemNameByID(itemID)
        if byID and byID ~= "" then
            return byID
        end
        return tostring(itemID)
    end
    return "Unknown Item"
end

local function BagIDToTabIndex(bagID)
    for i, id in ipairs(ACCOUNT_BANK_BAG_IDS) do
        if id == bagID then
            return i
        end
    end
    return nil
end

function Scanner:GetAccountBankBagIDs()
    return ACCOUNT_BANK_BAG_IDS
end

function Scanner:GetNormalBankBagIDs()
    local bagIDs = {}
    for _, bagID in ipairs(NORMAL_BANK_BAG_CANDIDATES) do
        local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
        if slotCount > 0 then
            table.insert(bagIDs, bagID)
        end
    end
    return bagIDs
end

function Scanner:DebugAccountBankBags(forcePrint)
    local printer = (forcePrint and ns.Print) or ns.dprint
    if not printer then
        return
    end

    for _, bagID in ipairs(ACCOUNT_BANK_BAG_IDS) do
        local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
        local occupied = 0
        local firstItem = "none"

        for slotIndex = 1, slotCount do
            local itemInfo = C_Container.GetContainerItemInfo(bagID, slotIndex)
            if itemInfo and itemInfo.stackCount and itemInfo.stackCount > 0 then
                occupied = occupied + 1
                if firstItem == "none" then
                    local itemName = nil
                    if itemInfo.itemName and itemInfo.itemName ~= "" then
                        itemName = itemInfo.itemName
                    elseif itemInfo.itemID then
                        itemName = C_Item.GetItemNameByID(itemInfo.itemID)
                    end
                    firstItem = itemName or (itemInfo.itemID and tostring(itemInfo.itemID)) or "none"
                end
            end
        end

        printer("bag " .. tostring(bagID) .. ": slots=" .. tostring(slotCount) .. " occupied=" .. tostring(occupied) .. " firstItem=" .. tostring(firstItem))
    end
end

function Scanner:BuildSlotInfo(bagID, slotIndex)
    local itemInfo = C_Container.GetContainerItemInfo(bagID, slotIndex)
    if not itemInfo or not itemInfo.stackCount or itemInfo.stackCount <= 0 then
        return nil
    end

    local itemLink = C_Container.GetContainerItemLink(bagID, slotIndex)
    local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
    local isBound = (itemInfo.isBound == true)
        or (itemLocation and itemLocation:IsValid() and C_Item.IsBound(itemLocation))
        or false
    local itemID = itemInfo.itemID

    if itemID and not itemLink then
        if not pendingItemIDs[itemID] then
            C_Item.RequestLoadItemDataByID(itemID)
            pendingItemIDs[itemID] = true
        end
    end

    local bindType = GetItemBindType({
        itemLink = itemLink,
        itemID = itemID,
    })
    if itemID and bindType == nil and not pendingItemIDs[itemID] then
        C_Item.RequestLoadItemDataByID(itemID)
        pendingItemIDs[itemID] = true
    end

    return {
        bagID = bagID,
        isBound = isBound,
        slotIndex = slotIndex,
        stackCount = itemInfo.stackCount,
        itemLink = itemLink,
        itemID = itemID,
        bindType = bindType,
    }
end

function Scanner:IterateBagSlots(bagID)
    local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
    local slotIndex = 0

    return function()
        while slotIndex < slotCount do
            slotIndex = slotIndex + 1
            local slotInfo = self:BuildSlotInfo(bagID, slotIndex)
            if slotInfo then
                return slotInfo
            end
        end

        return nil
    end
end

function Scanner:AccumulateBagSummary(rootSummary, sectionSummary, bagSummary, slotInfo, sourceLabel, topItems, missingMerged)
    if not slotInfo or not slotInfo.stackCount or slotInfo.stackCount <= 0 then
        return
    end

    bagSummary.occupiedSlots = bagSummary.occupiedSlots + 1

    local function AddVendorValue()
        local vendorPricePerItem = GetBlizzardVendorSellPrice(slotInfo.itemLink, slotInfo.itemID)
        local stackVendor = vendorPricePerItem * slotInfo.stackCount
        bagSummary.vendorValue = bagSummary.vendorValue + stackVendor
        sectionSummary.vendorValue = sectionSummary.vendorValue + stackVendor
    end

    if slotInfo.isBound then
        AddVendorValue()
        return
    end

    local isAuctionEligible = IsAHEligible(slotInfo)
    if isAuctionEligible and slotInfo.itemLink and rootSummary.auctionatorAvailable then
        local ahPricePerItem = GetAuctionatorPrice(slotInfo)
        if ahPricePerItem and ahPricePerItem > 0 then
            local stackAH = ahPricePerItem * slotInfo.stackCount
            bagSummary.ahValue = bagSummary.ahValue + stackAH
            sectionSummary.ahValue = sectionSummary.ahValue + stackAH
            if topItems then
                -- Aggregate by item so multiple stacks of the same item rank once.
                local key = slotInfo.itemID or slotInfo.itemLink or "unknown"
                local entry = topItems[key]
                if not entry then
                    entry = {
                        name = GetItemDisplayName(slotInfo.itemLink, slotInfo.itemID),
                        value = 0,
                        sources = {},
                    }
                    topItems[key] = entry
                end
                entry.value = entry.value + stackAH
                local simpleSource = (sourceLabel:find("^Warband") and "Warband") or sourceLabel
                entry.sources[simpleSource] = true
            end
            return
        end

        bagSummary.missingPrices = bagSummary.missingPrices + 1
        sectionSummary.missingPrices = sectionSummary.missingPrices + 1
        if missingMerged then
            local idKey = slotInfo.itemID or slotInfo.itemLink or "unknown"
            local key = sourceLabel .. "|" .. tostring(idKey)
            if not missingMerged[key] then
                missingMerged[key] = {
                    source = sourceLabel,
                    name = GetItemDisplayName(slotInfo.itemLink, slotInfo.itemID),
                    count = 0,
                }
            end
            missingMerged[key].count = missingMerged[key].count + slotInfo.stackCount
        end
    end

    -- No AH valuation possible (Auctionator unavailable, AH-ineligible, or price
    -- missing): fall back to vendor price so the item still counts in the totals.
    AddVendorValue()
end

function Scanner:BuildSummary()
    local summary = {
        auctionatorAvailable = IsAuctionatorAvailable() and true or false,
        warband = {
            ahValue = 0,
            vendorValue = 0,
            missingPrices = 0,
            bagBreakdown = {},
        },
        bank = {
            ahValue = 0,
            vendorValue = 0,
            missingPrices = 0,
        },
        bags = {
            ahValue = 0,
            vendorValue = 0,
            missingPrices = 0,
        },
        topAHItems = {},
        missingMerged = {},
    }
    local topAHByItem = {}


    for _, bagID in ipairs(ACCOUNT_BANK_BAG_IDS) do
        local bagSummary = {
            bagID = bagID,
            tabIndex = BagIDToTabIndex(bagID),
            ahValue = 0,
            vendorValue = 0,
            missingPrices = 0,
            occupiedSlots = 0,
        }

        for slotInfo in self:IterateBagSlots(bagID) do
            local sourceLabel = bagSummary.tabIndex and ("Warband Tab " .. tostring(bagSummary.tabIndex)) or "Warband"
            self:AccumulateBagSummary(summary, summary.warband, bagSummary, slotInfo, sourceLabel, topAHByItem, summary.missingMerged)
        end

        if bagSummary.occupiedSlots > 0 then
            table.insert(summary.warband.bagBreakdown, bagSummary)
        end
    end

    local normalBankBagIDs = self:GetNormalBankBagIDs()
    self.lastNormalBankBagIDs = normalBankBagIDs
    for _, bagID in ipairs(normalBankBagIDs) do
        local bagSummary = {
            bagID = bagID,
            ahValue = 0,
            vendorValue = 0,
            missingPrices = 0,
            occupiedSlots = 0,
        }
        for slotInfo in self:IterateBagSlots(bagID) do
            self:AccumulateBagSummary(summary, summary.bank, bagSummary, slotInfo, "Bank", topAHByItem, summary.missingMerged)
        end
    end

    for _, bagID in ipairs(INVENTORY_BAG_IDS) do
        local bagSummary = {
            bagID = bagID,
            ahValue = 0,
            vendorValue = 0,
            missingPrices = 0,
            occupiedSlots = 0,
        }
        for slotInfo in self:IterateBagSlots(bagID) do
            self:AccumulateBagSummary(summary, summary.bags, bagSummary, slotInfo, "Bags", topAHByItem, summary.missingMerged)
        end
    end

    for _, entry in pairs(topAHByItem) do
        local firstSource, sourceCount = nil, 0
        for source in pairs(entry.sources) do
            sourceCount = sourceCount + 1
            firstSource = firstSource or source
        end
        entry.source = (sourceCount > 1) and "Multi" or (firstSource or "?")
        table.insert(summary.topAHItems, entry)
    end
    table.sort(summary.topAHItems, function(a, b)
        return (a.value or 0) > (b.value or 0)
    end)
    while #summary.topAHItems > 3 do
        table.remove(summary.topAHItems)
    end

    -- Backward-compatible top-level fields.
    summary.ahValue = summary.warband.ahValue
    summary.vendorValue = summary.warband.vendorValue
    summary.missingPrices = summary.warband.missingPrices
    summary.bagBreakdown = summary.warband.bagBreakdown

    return summary
end

function Scanner:ScanSummary()
    local summary = self:BuildSummary()
    self.lastScanSummary = summary

    if ns.UI and ns.UI.UpdateSummary then
        ns.UI:UpdateSummary(summary)
    end
end

function Scanner:HasPendingItemData(itemID)
    if not itemID then
        return next(pendingItemIDs) ~= nil
    end

    return pendingItemIDs[itemID] == true
end

function Scanner:ClearPendingItemData(itemID)
    if itemID then
        pendingItemIDs[itemID] = nil
        return
    end

    for id in pairs(pendingItemIDs) do
        pendingItemIDs[id] = nil
    end
end
