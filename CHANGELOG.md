# WarbankValue changelog

## Unreleased
- The minimap button now starts right below Fireside's, so the two sit together; drag it anywhere as before

## 0.2.0
- WoW: Forever support: its own TOC (interface 16001), and the Warband section hides itself where the game has no Warband Bank
- Published on CurseForge for WoW: Forever; Retail follows once this version has been tested there
- New Bags section: AH and vendor value of the carried inventory, included in the Total
- `/wbv show` now rescans on open: Bags are always live; Bank/Warband keep the last scan when the bank is out of reach
- Bank and Warband sections appear only once a scan has actually seen them, and keep their values after you leave the bank
- Bank bag IDs now derived from Enum.BagIndex (fixes the carried reagent bag being counted as a bank bag)
- Items without an AH valuation now count at vendor price — totals always cover the whole bank
- Top AH Items aggregated per item instead of per stack, shown in quality colors with the item tooltip on hover
- Panel auto-resizes to fit its content; values right-aligned in a second column
- Missing Prices rows shown only when relevant, highlighted in orange
- Notice shown when Auctionator is not installed
- New `/wbv show` and `/wbv resetpos` commands
- Minimap button: click toggles the panel, hover shows live totals, drag sets its angle and distance so it clears any minimap border art (`/wbv minimap on|off`)
- Colored chat output: gold `[WBV]` prefix, accented commands, orange warnings; load message shows the version
- Interface bumped to 12.1.0

## 0.1.0
- Initial release
- Warband Bank and regular Bank scanning
- AH value (via Auctionator) and vendor value display
- Per-tab breakdown, top 3 AH items, missing prices list
- Draggable panel with saved position
- `/wbv` slash commands
