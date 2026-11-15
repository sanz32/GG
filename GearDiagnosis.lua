local ADDON_NAME, GG = ...

local GD = {}
GG.GearDiagnosis = GD

GD.TRACK_ORDER = { "myth", "hero", "champion", "veteran", "adventurer", "explorer", "crafted", "other" }

local TRACK_WORDS = {
  myth = { "myth", "mitico", "mito", "mythos", "mythique", "mitica" },
  hero = { "hero", "heroe", "held", "heros", "eroe" },
  champion = { "champion", "campeon", "champ", "campione", "champion" },
  veteran = { "veteran", "veterano", "veteran", "veterana" },
  adventurer = { "adventurer", "aventurero", "abenteurer", "aventurier", "avventuriero" },
  explorer = { "explorer", "explorador", "entdecker", "explorateur", "esploratore" },
}

local function Plain(s)
  s = (s or ""):lower()
  local map = { ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ü"] = "u",
    ["è"] = "e", ["ê"] = "e", ["à"] = "a", ["ö"] = "o", ["ä"] = "a", ["Á"] = "a", ["É"] = "e", ["Í"] = "i", ["Ó"] = "o", ["Ú"] = "u" }
  return (s:gsub("[\195][\128-\191]", function(c) return map[c] or c end))
end

function GD.TrackKey(trackString)
  local s = Plain(trackString)
  if s == "" then return nil end
  for _, key in ipairs(GD.TRACK_ORDER) do
    for _, word in ipairs(TRACK_WORDS[key] or {}) do
      if s:find(word, 1, true) then return key end
    end
  end
  return nil
end

GD.MAXED_LOW_GAP = 5

function GD.Diagnose(items, craftedCap)
  local out = { tracks = {}, missingEnchant = {}, emptyGems = {}, maxedLow = {}, craftedLow = {}, low = {}, socketed = 0 }
  local counts, total, n = {}, 0, 0
  for _, it in ipairs(items or {}) do
    local key = it.crafted and "crafted" or it.trackKey or "other"
    counts[key] = (counts[key] or 0) + 1
    total = total + (it.ilvl or 0)
    n = n + 1
  end
  for _, key in ipairs(GD.TRACK_ORDER) do
    if counts[key] then out.tracks[#out.tracks + 1] = { key = key, count = counts[key] } end
  end
  local avg = n > 0 and total / n or 0
  out.average = avg

  for _, it in ipairs(items or {}) do
    local ilvl = it.ilvl or 0
    if it.canEnchant and not it.enchanted then out.missingEnchant[#out.missingEnchant + 1] = it.slot end
    if (it.gems or 0) > 0 then
      out.socketed = out.socketed + 1
      if (it.gemsFilled or 0) < it.gems then out.emptyGems[#out.emptyGems + 1] = it.slot end
    end
    local maxed = it.max and it.max > 0 and (it.cur or 0) >= it.max
    local upgradable = it.max and it.max > 0 and (it.cur or 0) < it.max and not it.crafted
    if upgradable and (not out.upgradeFirst or ilvl < (out.upgradeFirst.ilvl or 0)) then out.upgradeFirst = it end
    local craftedBelowCap = it.crafted and craftedCap and ilvl < craftedCap - 0.5
    if it.crafted and craftedCap and not craftedBelowCap then maxed = true end
    if it.crafted and not craftedCap then maxed = false end
    if maxed and ilvl <= avg - GD.MAXED_LOW_GAP then out.maxedLow[#out.maxedLow + 1] = it end
    if craftedBelowCap then out.craftedLow[#out.craftedLow + 1] = it end
    if ilvl <= avg - 8 then out.low[it.slot] = true end
  end
  local function ByIlvl(a, b)
    if (a.ilvl or 0) ~= (b.ilvl or 0) then return (a.ilvl or 0) < (b.ilvl or 0) end
    return tostring(a.slot) < tostring(b.slot)
  end
  table.sort(out.maxedLow, ByIlvl)
  table.sort(out.craftedLow, ByIlvl)
  return out
end
