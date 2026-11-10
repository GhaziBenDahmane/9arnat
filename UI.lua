local _, DOV = ...
DOV = DOV or {}

local GetNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
local GetLink = (C_Container and C_Container.GetContainerItemLink) or GetContainerItemLink
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

local ROW_H, ROWS = 22, 14
local frame, view = nil, "bags"
local rows = {}
local data = {}

local function BagItems()
  local out = {}
  for bag = 0, (NUM_BAG_SLOTS or 4) do
    for slot = 1, (GetNumSlots(bag) or 0) do
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

local function MaterialItems()
  local out = {}
  for _, id in ipairs(DOV.ComponentIDs()) do
    local p, src, age = DOV.GetPrice(id)
    out[#out + 1] = { id = id, price = p, src = src, age = age }
  end
  table.sort(out, function(a, b) return (a.price or -1) > (b.price or -1) end)
  return out
end

local function Age(age)
  if not age then return "" end
  if age < 3600 then return math.floor(age / 60) .. "m" end
  if age < 86400 then return math.floor(age / 3600) .. "h" end
  return math.floor(age / 86400) .. "d"
end

local function Refresh()
  if not frame or not frame:IsShown() then return end
  frame.bagsBtn:SetEnabled(view ~= "bags"); frame.matsBtn:SetEnabled(view ~= "mats")
  frame.onlyDE:SetShown(view == "bags")
  data = (view == "bags") and BagItems() or MaterialItems()
  if view == "bags" and Arnat9DB.onlyDE then
    local f = {}
    for _, r in ipairs(data) do if r.better == "DE" then f[#f + 1] = r end end
    data = f
  end
  FauxScrollFrame_Update(frame.scroll, #data, ROWS, ROW_H)
  local offset = FauxScrollFrame_GetOffset(frame.scroll)
  for i = 1, ROWS do
    local row, r = rows[i], data[i + offset]
    if r then
      row.r = r
      if view == "bags" then
        row.icon:SetTexture(GetItemIcon and GetItemIcon(r.link) or nil)
        row.name:SetText(r.link)
        row.a:SetText(DOV.Money(r.de)); row.b:SetText(DOV.Money(r.vendor))
        local tag = (r.missing and r.de == 0) and "|cffaaaaaa?|r" or (r.better == "DE" and "|cff00ff00DISENCHANT|r" or "|cffffd100VENDOR|r")
        row.c:SetText(tag)
      else
        row.icon:SetTexture(GetItemIcon and GetItemIcon(r.id) or nil)
        row.name:SetText(DOV.NAMES[r.id])
        row.a:SetText(r.price and DOV.Money(r.price) or "|cffaaaaaano data|r")
        row.b:SetText(r.src or ""); row.c:SetText(Age(r.age))
      end
      row:Show()
    else
      row.r = nil; row:Hide()
    end
  end
  if view == "bags" then
    local gain = 0
    for _, r in ipairs(data) do if r.better == "DE" then gain = gain + r.gain end end
    frame.hdrA:SetText("Disenchant"); frame.hdrB:SetText("Vendor"); frame.hdrC:SetText("Verdict")
    frame.total:SetText("Extra from disenchanting instead of vendoring: " .. DOV.Money(gain))
    if #data == 0 then frame.total:SetText("Nothing to show. Bags have no disenchantable items (or none pass the filter).") end
  else
    frame.hdrA:SetText("Price"); frame.hdrB:SetText("Source"); frame.hdrC:SetText("Age")
    frame.total:SetText("Prices come from Auctionator and/or 9arnat scans.")
  end
  frame.scanBtn:SetText(DOV.IsScanning and DOV.IsScanning() and "Scanning..." or "Scan AH")
  frame.scanBtn:SetEnabled(not (DOV.IsScanning and DOV.IsScanning()))
end
DOV.RefreshUI = Refresh

local function MakeText(parent, template, justify, w)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  fs:SetJustifyH(justify or "LEFT"); if w then fs:SetWidth(w) end
  return fs
end

local function Build()
  frame = CreateFrame("Frame", "Arnat9Frame", UIParent, "BackdropTemplate")
  frame:SetSize(580, 100 + ROWS * ROW_H + 40)
  frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
  frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  frame:SetBackdropColor(0.05, 0.05, 0.07, 0.95); frame:SetBackdropBorderColor(0.4, 0.4, 0.45)
  frame:EnableMouse(true); frame:SetMovable(true); frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  tinsert(UISpecialFrames, "Arnat9Frame")

  local title = MakeText(frame, "GameFontNormalLarge"); title:SetPoint("TOPLEFT", 12, -10); title:SetText("9arnat")
  local sub = MakeText(frame, "GameFontDisableSmall"); sub:SetPoint("LEFT", title, "RIGHT", 8, -1); sub:SetText("disenchant or vendor")
  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)

  local function Btn(text, w, onclick)
    local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetText(text); b:SetScript("OnClick", onclick); return b
  end
  frame.bagsBtn = Btn("Bags", 70, function() view = "bags"; Refresh() end); frame.bagsBtn:SetPoint("TOPLEFT", 12, -36)
  frame.matsBtn = Btn("Materials", 80, function() view = "mats"; Refresh() end); frame.matsBtn:SetPoint("LEFT", frame.bagsBtn, "RIGHT", 4, 0)
  frame.scanBtn = Btn("Scan AH", 90, function()
    DOV.StartScan(); Refresh()
  end)
  frame.scanBtn:SetPoint("TOPRIGHT", -12, -36)
  frame.scanBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText(DOV.CanScan and DOV.CanScan() and "Scan every material at the auction house" or "Open the auction house to scan (needs the classic AH API; otherwise use Auctionator)")
    GameTooltip:Show()
  end)
  frame.scanBtn:SetScript("OnLeave", GameTooltip_Hide)
  frame.refreshBtn = Btn("Refresh", 70, Refresh); frame.refreshBtn:SetPoint("RIGHT", frame.scanBtn, "LEFT", -4, 0)

  frame.onlyDE = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
  frame.onlyDE:SetPoint("LEFT", frame.matsBtn, "RIGHT", 10, 0); frame.onlyDE:SetSize(24, 24)
  local cl = MakeText(frame, "GameFontHighlightSmall"); cl:SetPoint("LEFT", frame.onlyDE, "RIGHT", 0, 1); cl:SetText("Only disenchant")
  frame.onlyDE:SetScript("OnClick", function(self) Arnat9DB.onlyDE = self:GetChecked() and true or false; Refresh() end)

  -- column headers
  frame.hdrA = MakeText(frame, "GameFontNormalSmall", "RIGHT", 120); frame.hdrA:SetPoint("TOPLEFT", 290, -66)
  frame.hdrB = MakeText(frame, "GameFontNormalSmall", "RIGHT", 100); frame.hdrB:SetPoint("LEFT", frame.hdrA, "RIGHT", 6, 0)
  frame.hdrC = MakeText(frame, "GameFontNormalSmall", "LEFT", 80); frame.hdrC:SetPoint("LEFT", frame.hdrB, "RIGHT", 10, 0)

  local scroll = CreateFrame("ScrollFrame", "Arnat9Scroll", frame, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -82); scroll:SetSize(540, ROWS * ROW_H)
  scroll:SetScript("OnVerticalScroll", function(self, offset) FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, Refresh) end)
  frame.scroll = scroll

  for i = 1, ROWS do
    local row = CreateFrame("Button", nil, frame)
    row:SetSize(540, ROW_H); row:SetPoint("TOPLEFT", 8, -82 - (i - 1) * ROW_H)
    local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.08)
    if i % 2 == 0 then local bg = row:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(1, 1, 1, 0.03) end
    row.icon = row:CreateTexture(nil, "ARTWORK"); row.icon:SetSize(18, 18); row.icon:SetPoint("LEFT", 2, 0)
    row.name = MakeText(row, "GameFontHighlight", "LEFT", 250); row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0); row.name:SetWordWrap(false)
    row.a = MakeText(row, "GameFontHighlightSmall", "RIGHT", 120); row.a:SetPoint("LEFT", 282, 0)
    row.b = MakeText(row, "GameFontHighlightSmall", "RIGHT", 100); row.b:SetPoint("LEFT", row.a, "RIGHT", 6, 0)
    row.c = MakeText(row, "GameFontHighlightSmall", "LEFT", 80); row.c:SetPoint("LEFT", row.b, "RIGHT", 10, 0)
    row:SetScript("OnEnter", function(self)
      if not self.r then return end
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if self.r.link then GameTooltip:SetHyperlink(self.r.link) else GameTooltip:SetText(DOV.NAMES[self.r.id]) end
      GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    row:SetScript("OnClick", function(self)
      if self.r and self.r.link and IsModifiedClick("CHATLINK") then ChatEdit_InsertLink(self.r.link) end
    end)
    rows[i] = row
  end

  frame.total = MakeText(frame, "GameFontNormal"); frame.total:SetPoint("BOTTOMLEFT", 12, 34)
  local mgl = MakeText(frame, "GameFontHighlightSmall"); mgl:SetPoint("BOTTOMLEFT", 12, 12); mgl:SetText("Only recommend disenchant if it earns at least (gold) more:")
  local eb = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  eb:SetSize(50, 18); eb:SetPoint("LEFT", mgl, "RIGHT", 10, 0); eb:SetAutoFocus(false); eb:SetNumeric(true); eb:SetMaxLetters(5)
  eb:SetScript("OnEnterPressed", function(self) Arnat9DB.minGain = tonumber(self:GetText()) or 0; self:ClearFocus(); Refresh() end)
  eb:SetScript("OnEscapePressed", function(self) self:SetText(Arnat9DB.minGain or 0); self:ClearFocus() end)
  frame.minGain = eb

  frame:SetScript("OnShow", function()
    frame.onlyDE:SetChecked(Arnat9DB.onlyDE); frame.minGain:SetText(Arnat9DB.minGain or 0); Refresh()
  end)
  frame:RegisterEvent("BAG_UPDATE_DELAYED")
  frame:SetScript("OnEvent", function() Refresh() end)
  DOV.OnScanUpdate = Refresh
end

function DOV.ToggleUI(which)
  if not frame then Build() end
  if which then view = which end
  if frame:IsShown() and not which then frame:Hide() else frame:Show() end
end
function DOV.ShowBags() DOV.ToggleUI("bags") end

-- Minimap button (draggable around the minimap)
local function BuildMinimap()
  local b = CreateFrame("Button", "Arnat9MinimapButton", Minimap)
  b:SetSize(31, 31); b:SetFrameStrata("MEDIUM"); b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
  local icon = b:CreateTexture(nil, "BACKGROUND"); icon:SetSize(20, 20); icon:SetPoint("CENTER")
  icon:SetTexture("Interface\\Icons\\Spell_Holy_RemoveCurse")
  local ring = b:CreateTexture(nil, "OVERLAY"); ring:SetSize(53, 53); ring:SetPoint("TOPLEFT")
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local function Place()
    local a = math.rad(Arnat9DB.minimapAngle or 215)
    b:ClearAllPoints(); b:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
  end
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter(); local s = Minimap:GetEffectiveScale()
      local cx, cy = GetCursorPosition()
      Arnat9DB.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx)); Place()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnClick", function(_, btn) if btn == "RightButton" then DOV.ToggleUI("mats") else DOV.ToggleUI() end end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT"); GameTooltip:SetText("9arnat")
    GameTooltip:AddLine("Left-click: bag report", 1, 1, 1); GameTooltip:AddLine("Right-click: material prices", 1, 1, 1)
    GameTooltip:AddLine("Drag: move button", 0.7, 0.7, 0.7); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  Place()
end

local init = CreateFrame("Frame")
init:RegisterEvent("PLAYER_LOGIN")
init:SetScript("OnEvent", BuildMinimap)

local function PrintPrices()
  for _, r in ipairs(MaterialItems()) do
    print(("  %s: %s%s"):format(DOV.NAMES[r.id], r.price and DOV.Money(r.price) or "no data", r.src and (" (" .. r.src .. ")") or ""))
  end
end

SLASH_ARNAT91 = "/9ar"
SLASH_ARNAT92 = "/arnat"
SlashCmdList["ARNAT9"] = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "scan" then DOV.StartScan()
  elseif msg == "prices" then PrintPrices()
  elseif msg == "mats" or msg == "materials" then DOV.ToggleUI("mats")
  elseif msg == "bags" then DOV.ToggleUI("bags")
  else DOV.ToggleUI() end
end
