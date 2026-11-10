local _, DOV = ...
DOV = DOV or {}

local MAX_AGE = 3 * 24 * 3600 -- stored prices older than this are flagged stale

-- Own price DB (filled by passive AH capture + /9ar scan)
function DOV.StorePrice(itemID, copper)
  Arnat9DB.prices[itemID] = { p = copper, t = time() }
end

-- Returns copper price, source ("auctionator"|"own"), ageSeconds|nil
function DOV.GetPrice(itemID)
  local own = Arnat9DB and Arnat9DB.prices[itemID]
  local ownAge = own and (time() - own.t)

  if Auctionator and Auctionator.API and Auctionator.API.v1 and Auctionator.API.v1.GetAuctionPriceByItemID then
    local ok, p = pcall(Auctionator.API.v1.GetAuctionPriceByItemID, "9arnat", itemID)
    if ok and p and p > 0 then
      -- prefer a fresher own scan if we have one from the last hour
      if own and ownAge < 3600 then return own.p, "own", ownAge end
      return p, "auctionator", nil
    end
  end
  if own then return own.p, "own", ownAge end
  return nil
end

function DOV.IsStale(age) return age and age > MAX_AGE end

-- All component item IDs
function DOV.ComponentIDs()
  local ids = {}
  for id in pairs(DOV.NAMES) do ids[#ids + 1] = id end
  table.sort(ids)
  return ids
end
