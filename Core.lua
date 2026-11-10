local ADDON, DOV = ...
DOV = DOV or {}
_G.DisenchantOrVendor = DOV

local AH_CUT = 0.05 -- auction house cut when selling the materials

local GetItemInfoFn = (C_Item and C_Item.GetItemInfo) or GetItemInfo

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, name)
  if name ~= ADDON then return end
  Arnat9DB = Arnat9DB or {}
  Arnat9DB.prices = Arnat9DB.prices or {}
  Arnat9DB.minGain = Arnat9DB.minGain or 0
end)

local function ItemLevel(link)
  if GetDetailedItemLevelInfo then
    local lvl = GetDetailedItemLevelInfo(link)
    if lvl and lvl > 0 then return lvl end
  end
  return select(4, GetItemInfoFn(link))
end

-- Pick the right DE row set. Returns list of {id, chance, avg}, or nil
local function Rows(classID, quality, ilvl)
  local function try(cid)
    local key = cid * 10 + quality
    local min, max = DOV.DE_MIN[key], DOV.DE_MAX[key]
    if not min then return nil end
    if ilvl >= min and ilvl <= max then return DOV.DE[key][ilvl] end
  end
  local rows = try(classID) or try(classID == 2 and 4 or 2)
  if rows then return rows end
  -- outside any logged range: clamp to nearest end of the class table (approximation)
  for _, cid in ipairs({ classID, classID == 2 and 4 or 2 }) do
    local key = cid * 10 + quality
    local min, max = DOV.DE_MIN[key], DOV.DE_MAX[key]
    if min then return DOV.DE[key][ilvl < min and min or max], true end
  end
end

-- Evaluate an item link. Returns a result table, or nil if it can't be disenchanted.
function DOV.Evaluate(link)
  if not link then return end
  local _, _, quality, _, _, _, _, _, equipLoc, _, sellPrice, classID = GetItemInfoFn(link)
  if not quality or quality < 2 or quality > 4 then return end
  if classID ~= 2 and classID ~= 4 then return end
  if equipLoc == "INVTYPE_BODY" or equipLoc == "INVTYPE_TABARD" then return end
  local ilvl = ItemLevel(link)
  if not ilvl then return end
  local rows, extrapolated = Rows(classID, quality, ilvl)
  if not rows then return end

  local ev, missing, stale = 0, false, false
  local parts = {}
  for _, r in ipairs(rows) do
    local id, chance, avg = r[1], r[2], r[3]
    local price, _, age = DOV.GetPrice(id)
    if price then
      ev = ev + chance * avg * price
      if DOV.IsStale(age) then stale = true end
      parts[#parts + 1] = { id = id, chance = chance, avg = avg, price = price }
    elseif chance >= 0.05 then
      missing = true -- a likely drop has no price
    end
  end
  ev = math.floor(ev * (1 - AH_CUT))
  return {
    de = ev, vendor = sellPrice or 0, missing = missing, stale = stale,
    extrapolated = extrapolated, parts = parts, ilvl = ilvl,
    better = (ev > (sellPrice or 0)) and "DE" or "VENDOR",
    gain = ev - (sellPrice or 0),
  }
end

local function Money(c) return GetCoinTextureString(math.floor(c)) end
DOV.Money = Money

function DOV.AddTooltip(tt, link)
  local r = DOV.Evaluate(link)
  if not r then return end
  local verdict
  if r.missing and r.de == 0 then
    verdict = "|cffaaaaaa? No AH data for materials (scan the AH)|r"
  elseif r.better == "DE" then
    verdict = "|cff00ff00DISENCHANT|r"
  else
    verdict = "|cffffd100VENDOR|r"
  end
  tt:AddLine(" ")
  tt:AddLine("Disenchant or Vendor: " .. verdict)
  tt:AddLine("  Disenchant (after 5% AH cut): " .. Money(r.de), 1, 1, 1)
  tt:AddLine("  Vendor: " .. Money(r.vendor), 1, 1, 1)
  if r.missing and r.de > 0 then tt:AddLine("  Some materials have no price: DE value may be higher", 0.7, 0.7, 0.7) end
  if r.stale then tt:AddLine("  Prices are old, rescan the AH", 0.7, 0.7, 0.7) end
  if r.extrapolated then tt:AddLine("  Item level outside logged data: estimate", 0.7, 0.7, 0.7) end
  tt:Show()
end

local function OnTooltip(tt)
  local _, link = tt:GetItem()
  if link then DOV.AddTooltip(tt, link) end
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
    if tt ~= GameTooltip and tt ~= ItemRefTooltip then return end
    local link = data and (data.hyperlink or (tt.GetItem and select(2, tt:GetItem())))
    if link then DOV.AddTooltip(tt, link) end
  end)
else
  GameTooltip:HookScript("OnTooltipSetItem", OnTooltip)
  ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltip)
end
