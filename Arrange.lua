local ADDON_NAME, GG = ...

GG.Arrange = {}
local A = GG.Arrange

A.MODES = { "free", "roster", "class", "account", "role", "ilvl", "rating", "level", "name" }
A.GROUPS = { class = true, account = true, role = true }
A.VALUES = { ilvl = true, rating = true, level = true, name = true }
A.ROLES = { "TANK", "HEALER", "DAMAGER" }
A.CLASSES = {
  "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
  "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER",
}
A.DEFAULT_DESC = { ilvl = true, rating = true, level = true, name = false, roster = false }

local VALID_MODE = {}
for _, m in ipairs(A.MODES) do VALID_MODE[m] = true end

function A.IsGroup(k) return A.GROUPS[k] == true end
function A.IsValue(k) return A.VALUES[k] == true end

function A.NaturalLess(rawA, rawB)
  rawA, rawB = tostring(rawA):lower(), tostring(rawB):lower()
  local a, b = rawA:gsub("%s+", ""), rawB:gsub("%s+", "")
  if a == b then return rawA < rawB end
  local ia, ib = 1, 1
  while ia <= #a and ib <= #b do
    local na, nb = a:match("^%d+", ia), b:match("^%d+", ib)
    if na and nb then
      local va, vb = tonumber(na), tonumber(nb)
      if va ~= vb then return va < vb end
      ia, ib = ia + #na, ib + #nb
    else
      local ca, cb = a:sub(ia, ia), b:sub(ib, ib)
      if ca ~= cb then return ca < cb end
      ia, ib = ia + 1, ib + 1
    end
  end
  return #a - ia < #b - ib
end

local function CopyList(t)
  local out = {}
  if type(t) == "table" then
    for _, v in ipairs(t) do
      if type(v) == "string" then out[#out + 1] = v end
    end
  end
  return out
end

local function CompleteFixed(saved, reference)
  local known, seen, out = {}, {}, {}
  for _, v in ipairs(reference) do known[v] = true end
  for _, v in ipairs(saved) do
    if known[v] and not seen[v] then out[#out + 1] = v; seen[v] = true end
  end
  for _, v in ipairs(reference) do
    if not seen[v] then out[#out + 1] = v end
  end
  return out
end

function A:Resolve(saved)
  saved = type(saved) == "table" and saved or {}
  local cfg = {}
  cfg.by = VALID_MODE[saved.by] and saved.by or "free"
  local inside = saved.inside
  if inside ~= "manual" and not (A.IsGroup(inside) or A.IsValue(inside)) then inside = "manual" end
  if not A.IsGroup(cfg.by) or inside == cfg.by then inside = "manual" end
  cfg.inside = inside
  cfg.desc = {}
  local desc = type(saved.desc) == "table" and saved.desc or {}
  for k, default in pairs(A.DEFAULT_DESC) do
    if type(desc[k]) == "boolean" then cfg.desc[k] = desc[k] else cfg.desc[k] = default end
  end
  local strips = type(saved.strips) == "table" and saved.strips or {}
  cfg.strips = {
    class = CompleteFixed(CopyList(strips.class), A.CLASSES),
    role = CompleteFixed(CopyList(strips.role), A.ROLES),
    account = CopyList(strips.account),
  }
  return cfg
end

function A.SyncStrip(saved, live)
  local present = {}
  for _, v in ipairs(live) do present[v] = true end
  local out, seen = {}, {}
  for _, v in ipairs(saved or {}) do
    if present[v] and not seen[v] then out[#out + 1] = v; seen[v] = true end
  end
  local fresh = {}
  for _, v in ipairs(live) do
    if not seen[v] then fresh[#fresh + 1] = v; seen[v] = true end
  end
  table.sort(fresh, A.NaturalLess)
  for _, v in ipairs(fresh) do
    local at
    for i, existing in ipairs(out) do
      if A.NaturalLess(v, existing) then at = i; break end
    end
    table.insert(out, at or (#out + 1), v)
  end
  local changed = #out ~= #(saved or {})
  if not changed then
    for i, v in ipairs(out) do
      if saved[i] ~= v then changed = true; break end
    end
  end
  return out, changed
end

function A:Effective(cfg, hasRosters)
  if cfg.by == "roster" and not hasRosters then return "free" end
  return cfg.by
end

local function GroupValue(row, k)
  if k == "class" then return row.class end
  if k == "account" then return row.accountLabel end
  if k == "role" then return row.role end
end

local function StripIndex(list, value)
  if value == nil then return math.huge end
  for i, v in ipairs(list) do
    if v == value then return i end
  end
  return math.huge
end

local function ValueOf(row, k)
  if k == "ilvl" then return row.ilvl or 0 end
  if k == "rating" then return row.rating or 0 end
  if k == "level" then return row.level or 0 end
end

local function CompareBy(cfg, k, a, b, ctx)
  if k == "roster" then
    local ra, rb = ctx.rosterOf(a), ctx.rosterOf(b)
    if ra == rb then return 0 end
    if not ra then return 1 end
    if not rb then return -1 end
    local less = A.NaturalLess(ra, rb)
    if not less and not A.NaturalLess(rb, ra) then return 0 end
    if cfg.desc.roster then less = not less end
    return less and -1 or 1
  end
  if A.IsGroup(k) then
    local ia = StripIndex(cfg.strips[k], GroupValue(a, k))
    local ib = StripIndex(cfg.strips[k], GroupValue(b, k))
    if ia == ib then return 0 end
    return ia < ib and -1 or 1
  end
  if k == "name" then
    local na, nb = (a.name or ""):lower(), (b.name or ""):lower()
    if na == nb then return 0 end
    local less = na < nb
    if cfg.desc.name then less = not less end
    return less and -1 or 1
  end
  local va, vb = ValueOf(a, k), ValueOf(b, k)
  if va == vb then return 0 end
  local less = va < vb
  if cfg.desc[k] then less = not less end
  return less and -1 or 1
end

function A:Comparator(cfg, ctx)
  local by = self:Effective(cfg, ctx.hasRosters)
  local keys = {}
  if by ~= "free" then keys[1] = by end
  if A.IsGroup(by) and cfg.inside ~= "manual" then keys[2] = cfg.inside end
  local pos = ctx.manualPos or {}
  return function(a, b)
    for _, k in ipairs(keys) do
      local d = CompareBy(cfg, k, a, b, ctx)
      if d ~= 0 then return d < 0 end
    end
    local pa, pb = pos[a.key] or math.huge, pos[b.key] or math.huge
    if pa ~= pb then return pa < pb end
    local na, nb = (a.name or ""):lower(), (b.name or ""):lower()
    if na ~= nb then return na < nb end
    return (a.key or "") < (b.key or "")
  end
end

function A:DragSection(cfg, ctx, row)
  local by = self:Effective(cfg, ctx.hasRosters)
  if by == "free" then return "all" end
  if by == "roster" then
    if ctx.rosterOf(row) then return nil end
    return "others"
  end
  if A.IsGroup(by) and cfg.inside == "manual" then
    return "g:" .. tostring(GroupValue(row, by))
  end
  return nil
end

function A:CanDrag(cfg, hasRosters)
  local by = self:Effective(cfg, hasRosters)
  return by == "free" or by == "roster" or (A.IsGroup(by) and cfg.inside == "manual")
end

function A.MoveWithinSection(manual, visible, dragKey, dropIndex, sectionOf)
  local newVisible = {}
  for _, k in ipairs(visible) do
    if k ~= dragKey then newVisible[#newVisible + 1] = k end
  end
  local at = math.max(1, math.min(dropIndex or 1, #newVisible + 1))
  table.insert(newVisible, at, dragKey)

  local section = sectionOf(dragKey)
  local block, inBlock = {}, {}
  for _, k in ipairs(newVisible) do
    if sectionOf(k) == section then
      block[#block + 1] = k
      inBlock[k] = true
    end
  end

  local out = {}
  for i, k in ipairs(manual) do out[i] = k end
  local present = {}
  for _, k in ipairs(out) do present[k] = true end
  for _, k in ipairs(block) do
    if not present[k] then out[#out + 1] = k; present[k] = true end
  end
  local slot = 0
  for i, k in ipairs(out) do
    if inBlock[k] then
      slot = slot + 1
      out[i] = block[slot]
    end
  end
  return out
end
