# 9arnat

Tooltip + bag report telling you whether to disenchant or vendor an item, from AH prices.

Install: copy this folder into `World of Warcraft/<client folder>/Interface/AddOns/9arnat`
(folder name must match the .toc: `9arnat`).

Commands: `/9ar` bag report, `/9ar scan` scan the AH for material prices (at the AH), `/9ar prices` list prices.

Prices: Auctionator's database (if installed) and/or this addon's own DB, filled by `/9ar scan` and
passively whenever AH results show materials.

Disenchant odds: community Enchantrix logs (alex-berliner/wow_classic_de_table), per item level, weapon vs armor.
Gaps are filled from the nearest logged item level. Regenerate with scratch/gen.py.
