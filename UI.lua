local _, DOV = ...
DOV = DOV or {}

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
local function BagItems()
  local out = {}
  for bag = 0, 4 do
    for slot = 1, GetNumSlots(bag) or 0 do
      local link = GetLink(bag, slot)
      if link then
        local r = DOV.Evaluate(link)
        if r then r.link = link; out[#out + 1] = r end
      end
    end
  end
  table.sort(out, function(a, b) return a.gain > b.gain end)
  return out
end

local frame
local lines = {}
local MAXLINES = 24

local function Build()
  frame = CreateFrame("Frame", "DisenchantOrVendorFrame", UIParent, "BackdropTemplate")
  frame:SetSize(520, 36 + MAXLINES * 16 + 30)
  frame:SetPoint("CENTER")
  frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  frame:SetBackdropColor(0, 0, 0, 0.9)
  frame:SetBackdropBorderColor(0.4, 0.4, 0.4)
  frame:EnableMouse(true); frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetFrameStrata("DIALOG")
  tinsert(UISpecialFrames, "DisenchantOrVendorFrame")
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 12, -10); title:SetText("Disenchant or Vendor: bags")
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 2, 2)
  for i = 1, MAXLINES do
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", 12, -30 - (i - 1) * 16)
    fs:SetWidth(496); fs:SetJustifyH("LEFT")
    lines[i] = fs
  end
  frame.total = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  frame.total:SetPoint("BOTTOMLEFT", 12, 10)
end

function DOV.ShowBags()
  if not frame then Build() end
  local items = BagItems()
  local gain, shown = 0, 0
  for i = 1, MAXLINES do lines[i]:SetText("") end
  for _, r in ipairs(items) do
    if r.better == "DE" then gain = gain + r.gain end
    if shown < MAXLINES then
      shown = shown + 1
      local tag = r.better == "DE" and "|cff00ff00DE|r    " or "|cffffd100VENDOR|r"
      lines[shown]:SetText(("%s  %s   DE %s  /  Vendor %s"):format(tag, r.link, DOV.Money(r.de), DOV.Money(r.vendor)))
    end
  end
  if #items == 0 then lines[1]:SetText("No disenchantable items in your bags.") end
  frame.total:SetText("Extra gold from disenchanting instead of vendoring: " .. DOV.Money(gain))
  frame:Show()
end

local function PrintPrices()
  print("|cff66ccff9arnat:|r material prices")
  for _, id in ipairs(DOV.ComponentIDs()) do
    local p, src, age = DOV.GetPrice(id)
    print(("  %s: %s%s"):format(DOV.NAMES[id], p and DOV.Money(p) or "no data",
      p and (" (" .. src .. (age and (", " .. math.floor(age / 3600) .. "h old") or "") .. ")") or ""))
  end
end

SLASH_ARNAT91 = "/9ar"
SLASH_ARNAT92 = "/arnat"
SlashCmdList["ARNAT9"] = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "scan" then DOV.StartScan()
  elseif msg == "prices" then PrintPrices()
  elseif msg == "" or msg == "bags" then DOV.ShowBags()
  else print("/9ar [bags]  bag report | /9ar scan  scan AH materials (at the AH) | /9ar prices  list material prices") end
end
