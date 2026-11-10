local _, DOV = ...
DOV = DOV or {}

-- Builds our own price DB from the auction house.
-- 1) Passive: whenever an AH result list arrives, record the lowest buyout of any component in it.
-- 2) Active: /9ar scan at the AH queries every component by name, one at a time.
-- Uses the classic-style AH API (QueryAuctionItems / GetAuctionItemInfo). If the client lacks it,
-- prices come from Auctionator instead.

local hasLegacyAH = QueryAuctionItems and GetNumAuctionItems and GetAuctionItemInfo
local ahOpen = false
local scanning, queue, current

local function Record()
  if not hasLegacyAH then return 0 end
  local n = GetNumAuctionItems("list") or 0
  local best = {}
  for i = 1, n do
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
    if itemID and DOV.NAMES[itemID] and buyout and buyout > 0 and count and count > 0 then
      local unit = math.floor(buyout / count)
      if not best[itemID] or unit < best[itemID] then best[itemID] = unit end
    end
  end
  local c = 0
  for id, p in pairs(best) do DOV.StorePrice(id, p); c = c + 1 end
  return c, best
end

local function Next()
  if not scanning then return end
  if #queue == 0 then
    scanning = false
    print("|cff66ccff9arnat:|r scan finished.")
    if DOV.OnScanUpdate then DOV.OnScanUpdate() end
    return
  end
  if not CanSendAuctionQuery or CanSendAuctionQuery() then
    current = table.remove(queue, 1)
    QueryAuctionItems(DOV.NAMES[current], nil, nil, 0, false, 0, false, false)
  else
    C_Timer.After(0.5, Next)
  end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
ev:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
ev:SetScript("OnEvent", function(_, event)
  if event == "AUCTION_HOUSE_SHOW" then ahOpen = true
  elseif event == "AUCTION_HOUSE_CLOSED" then ahOpen = false; scanning = false
  elseif event == "AUCTION_ITEM_LIST_UPDATE" then
    local _, best = Record()
    if DOV.OnScanUpdate then DOV.OnScanUpdate() end
    if scanning and current then
      if best and not best[current] then
        -- nothing found for this component: remember that it isn't listed
      end
      current = nil
      C_Timer.After(0.6, Next)
    end
  end
end)

function DOV.IsScanning() return scanning end
function DOV.CanScan() return ahOpen and hasLegacyAH end
function DOV.StartScan()
  if not hasLegacyAH then
    print("|cff66ccff9arnat:|r this client has no classic AH query API. Scan with Auctionator instead (its prices are used automatically).")
    return
  end
  if not ahOpen then print("|cff66ccff9arnat:|r open the auction house first.") return end
  queue = DOV.ComponentIDs()
  scanning = true
  print(("|cff66ccff9arnat:|r scanning %d materials..."):format(#queue))
  Next()
end
