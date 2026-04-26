# WarbankValue

![WarbankValue](assets/logo_big.png)

> Displays the Auction House and vendor value of items stored in your Warband Bank and regular Bank — at a glance, every time you open the bank.

**Requires [Auctionator](https://www.curseforge.com/wow/addons/auctionator) for AH prices.**

---

## What it does

WarbankValue adds a small, movable summary panel that appears whenever you open your bank. It scans all Warband Bank tabs and your regular Bank slots and shows:

- **AH value** — estimated market value via Auctionator prices
- **Vendor value** — Blizzard sell price for bound items
- **Per-tab breakdown** — AH and vendor value for each Warband Bank tab
- **Top 3 AH items** — the most valuable auctionable items across all storage
- **Missing prices** — count of items Auctionator has no price data for yet

Soulbound and Warbound items are correctly excluded from AH valuation and counted at vendor price instead.

## Installation

1. Download and extract the `WarbankValue` folder into your `World of Warcraft/_retail_/Interface/AddOns/` directory
2. Make sure [Auctionator](https://www.curseforge.com/wow/addons/auctionator) is installed — WarbankValue uses its pricing API
3. Reload your UI or log in
4. Open your bank — the summary panel appears automatically

## Slash commands

| Command | Description |
|---|---|
| `/wbv` | Show help |
| `/wbv missing` | List items with no Auctionator price data |
| `/wbv status` | Show current settings |
| `/wbv debug on\|off` | Toggle debug output |

## Notes

- The panel is **draggable** — position is saved between sessions
- AH prices reflect Auctionator's local scan data; run an Auctionator scan for best accuracy
- Items with no price data are counted as "missing" and listed via `/wbv missing`
- Async item data loading is handled gracefully — the panel refreshes automatically when data arrives

## Compatibility

- **Interface:** 11.0.x (The War Within)
- **Dependency:** Auctionator (optional but required for AH prices)

## Changelog

### 0.1.0
- Initial release
- Warband Bank and regular Bank scanning
- AH value (via Auctionator) and vendor value display
- Per-tab breakdown, top 3 AH items, missing prices list
- Draggable panel with saved position
- `/wbv` slash commands

---

*Fourth public repo in a series exploring the boundary between human intent and AI execution.*  
*Author: Azareus — [github.com/danilomagro](https://github.com/danilomagro)*
