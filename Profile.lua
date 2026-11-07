local ADDON_NAME, GG = ...
local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

GG.Profile = {}
local P = GG.Profile

P.PREFIX = "GG1:"
local FORMAT_VERSION = 1
P.DEFAULT_NAME = "Default"
P.MAX_NAME = 32

P.SECTIONS = {
  { key = "columns", keys = { "sections", "currencyVisibility" } },
  { key = "theme", keys = { "theme", "themeParts" } },
  { key = "bosses", keys = { "bossIconStyle", "raidDifficulties" } },
  { key = "window", keys = { "layoutMode", "maxVisibleCharacters", "windowScale", "windowOpacity", "lockWindow",
    "closeWithEsc", "openOn", "minimap", "minLevel", "accentMode", "accentColor" } },
  { key = "account", keys = { "accountLabelStyle" } },
  { key = "announcements", keys = { "announceInstanceReset", "announceKeystoneParty", "announceKeystoneGuild", "announceTexts" } },
  { key = "popups", keys = { "popupRosterCall", "rosterCallStyle", "rosterCallSound", "popupRosterCharacter", "popupLockoutGroup", "popupLockoutInstance" } },
}

local BOOLS = { "lockWindow", "closeWithEsc", "announceInstanceReset", "announceKeystoneParty", "announceKeystoneGuild",
  "popupRosterCall", "rosterCallSound", "popupRosterCharacter", "popupLockoutGroup", "popupLockoutInstance" }

local ENUMS = {
  rosterCallStyle = { band = true, match = true, ring = true, card = true },
  layoutMode = { horizontal = true, vertical = true },
  openOn = { characters = true, last = true },
  accentMode = { default = true, class = true, custom = true },
  accountLabelStyle = { cuenta = true, wow = true, alt = true, number = true, battletag = true },
  maxVisibleCharacters = { [6] = true, [8] = true, [10] = true, [12] = true, [15] = true, all = true },
}

local RANGES = {
  windowScale = { 0.7, 1.5 },
  windowOpacity = { 0.7, 1.0 },
  minLevel = { 1, 200, int = true },
}

P.ANNOUNCE_TEXT_KEYS = { "instanceReset", "keystoneParty", "keystoneGuild" }
local MAX_TEXT = 255
local MAX_CURRENCIES = 300
P.DIFFICULTIES = { 17, 14, 15, 16 }

local function IsBossStyle(style)
  for _, s in ipairs((GG.BossIcons and GG.BossIcons.STYLES) or {}) do
    if s.key == style then return true end
  end
  return false
end

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end
P.Copy = Copy

local function Same(a, b)
  if type(a) == "table" and type(b) == "table" then
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
  end
  return a == b
end

function P.Sanitize(src, current)
  if type(src) ~= "table" then return nil, 0 end
  local out, n = {}, 0
  local function put(k, v) out[k] = v; n = n + 1 end

  for _, k in ipairs(BOOLS) do
    if type(src[k]) == "boolean" then put(k, src[k]) end
  end
  for k, allowed in pairs(ENUMS) do
    if src[k] ~= nil and allowed[src[k]] then put(k, src[k]) end
  end
  for k, r in pairs(RANGES) do
    local v = tonumber(src[k])
    if v and v == v then
      v = Clamp(v, r[1], r[2])
      if r.int then v = math.floor(v + 0.5) end
      put(k, v)
    end
  end
  if type(src.theme) == "string" and GG.RosterThemes and GG.RosterThemes:IsValidTheme(src.theme) then
    put("theme", src.theme)
  end
  if type(src.bossIconStyle) == "string" and IsBossStyle(src.bossIconStyle) then
    put("bossIconStyle", src.bossIconStyle)
  end

  local c = src.accentColor
  if type(c) == "table" and tonumber(c[1]) and tonumber(c[2]) and tonumber(c[3]) then
    put("accentColor", { Clamp(tonumber(c[1]), 0, 1), Clamp(tonumber(c[2]), 0, 1), Clamp(tonumber(c[3]), 0, 1) })
  end

  local known = current and current.sections or {}
  if type(src.sections) == "table" then
    local t = {}
    for k, v in pairs(src.sections) do
      if type(known[k]) == "boolean" and type(v) == "boolean" then t[k] = v end
    end
    put("sections", t)
  end
  if type(src.raidDifficulties) == "table" then
    local t = {}
    for _, id in ipairs(P.DIFFICULTIES) do
      if type(src.raidDifficulties[id]) == "boolean" then t[id] = src.raidDifficulties[id] end
    end
    put("raidDifficulties", t)
  end
  if type(src.currencyVisibility) == "table" then
    local t, count = {}, 0
    for k, v in pairs(src.currencyVisibility) do
      if (type(k) == "number" or type(k) == "string") and v == false and count < MAX_CURRENCIES then
        t[k], count = false, count + 1
      end
    end
    put("currencyVisibility", t)
  end
  if type(src.themeParts) == "table" then
    local t = {}
    for part, value in pairs(src.themeParts) do
      if GG.RosterThemes and GG.RosterThemes:IsValidPart(part, value) then t[part] = value end
    end
    put("themeParts", t)
  end
  if type(src.announceTexts) == "table" then
    local t = {}
    for _, k in ipairs(P.ANNOUNCE_TEXT_KEYS) do
      local s = src.announceTexts[k]
      if type(s) == "string" then t[k] = s:gsub("[\r\n]", " "):sub(1, MAX_TEXT) end
    end
    put("announceTexts", t)
  end
  if type(src.minimap) == "table" then
    local t = {}
    if type(src.minimap.hide) == "boolean" then t.hide = src.minimap.hide end
    if type(src.minimap.lock) == "boolean" then t.lock = src.minimap.lock end
    put("minimap", t)
  end
  return out, n
end

function P.Snapshot(options)
  return (P.Sanitize(options, options))
end

function P.SectionsIn(clean)
  local present = {}
  for _, s in ipairs(P.SECTIONS) do
    for _, k in ipairs(s.keys) do
      if clean[k] ~= nil then present[s.key] = true end
    end
  end
  return present
end

function P.Apply(options, clean, sectionSet)
  for _, s in ipairs(P.SECTIONS) do
    if not sectionSet or sectionSet[s.key] then
      for _, k in ipairs(s.keys) do
        local v = clean[k]
        if k == "minimap" then
          options.minimap = options.minimap or {}
          options.minimap.hide = v and v.hide
          options.minimap.lock = v and v.lock
        elseif type(options[k]) == "table" and (v == nil or type(v) == "table") then
          local target = options[k]
          for key in pairs(target) do target[key] = nil end
          for key, value in pairs(v or {}) do target[key] = Copy(value) end
        else
          options[k] = Copy(v)
        end
      end
    end
  end
end

local function Store(db)
  db.profiles = db.profiles or {}
  db.profiles.list = db.profiles.list or {}
  return db.profiles
end

local function Lower(s) return (s or ""):lower() end

local function Find(store, name)
  for key in pairs(store.list) do
    if Lower(key) == Lower(name) then return key end
  end
  return nil
end

function P.Init(db, options, now)
  local store = Store(db)
  if not next(store.list) then
    store.list[P.DEFAULT_NAME] = { o = P.Snapshot(options), at = now }
    store.active = P.DEFAULT_NAME
  end
  if not store.active or not store.list[store.active] then
    store.active = next(store.list)
  end
end

function P.Active(db) return Store(db).active end

function P.SaveActive(db, options, now)
  local store = Store(db)
  local entry = store.active and store.list[store.active]
  if entry then
    local snap = P.Snapshot(options)
    if not Same(entry.o, snap) then
      entry.o = snap
      entry.at = now
    end
  end
end

function P.List(db)
  local store, out = Store(db), {}
  for name, entry in pairs(store.list) do
    out[#out + 1] = { name = name, o = entry.o or {}, at = entry.at, active = name == store.active }
  end
  table.sort(out, function(a, b)
    if a.active ~= b.active then return a.active end
    return Lower(a.name) < Lower(b.name)
  end)
  return out
end

function P.ValidateName(db, name, except)
  name = (name or ""):gsub("[%c]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then return nil, "PROFILE_NAME_EMPTY" end
  if #name > P.MAX_NAME then return nil, "PROFILE_NAME_LONG" end
  local taken = Find(Store(db), name)
  if taken and Lower(taken) ~= Lower(except) then return nil, "PROFILE_NAME_TAKEN" end
  return name
end

function P.UniqueName(db, base)
  local store, i = Store(db), 2
  base = (base or P.DEFAULT_NAME):gsub("%s+%d+$", ""):sub(1, P.MAX_NAME - 3)
  while Find(store, base .. " " .. i) do i = i + 1 end
  return base .. " " .. i
end

function P.Use(db, options, name, now)
  local store = Store(db)
  local target = store.list[name]
  if not target or name == store.active then return false end
  P.SaveActive(db, options, now)
  P.Apply(options, target.o or {})
  store.active = name
  return true
end

function P.CreateCopy(db, options, fromName, now)
  local store = Store(db)
  fromName = fromName or store.active
  if not store.list[fromName] then return nil end
  P.SaveActive(db, options, now)
  local name = P.UniqueName(db, fromName)
  store.list[name] = { o = Copy(store.list[fromName].o or {}), at = now }
  local reload = fromName ~= store.active
  store.active = name
  if reload then P.Apply(options, store.list[name].o) end
  return name, reload
end

function P.Rename(db, old, new)
  local store = Store(db)
  if not store.list[old] then return nil, "PROFILE_NAME_EMPTY" end
  local name, err = P.ValidateName(db, new, old)
  if not name then return nil, err end
  if name ~= old then
    store.list[name], store.list[old] = store.list[old], nil
    if store.active == old then store.active = name end
  end
  return name
end

function P.Delete(db, name)
  local store = Store(db)
  if name == store.active or not store.list[name] then return false end
  store.list[name] = nil
  return true
end

function P.Export(options, sectionSet)
  local all = P.Snapshot(options)
  local clean = {}
  for _, s in ipairs(P.SECTIONS) do
    if sectionSet[s.key] then
      for _, k in ipairs(s.keys) do clean[k] = all[k] end
    end
  end
  local payload = { v = FORMAT_VERSION, gg = GG.VERSION, o = clean }
  return P.PREFIX .. LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(LibSerialize:Serialize(payload)))
end

function P.Decode(text, current)
  text = (text or ""):gsub("%s", "")
  if text == "" then return nil, "PROFILE_ERR_EMPTY_TEXT" end
  if text:sub(1, #P.PREFIX) ~= P.PREFIX then return nil, "PROFILE_ERR_NOT_GG" end
  local ok, payload = pcall(function()
    local decoded = LibDeflate:DecodeForPrint(text:sub(#P.PREFIX + 1))
    local raw = decoded and LibDeflate:DecompressDeflate(decoded)
    if not raw then return nil end
    local success, value = LibSerialize:Deserialize(raw)
    return success and value or nil
  end)
  if not ok or type(payload) ~= "table" then return nil, "PROFILE_ERR_BROKEN" end
  if payload.v ~= FORMAT_VERSION then return nil, "PROFILE_ERR_FORMAT" end
  local clean, n = P.Sanitize(payload.o, current)
  if not clean or n == 0 then return nil, "PROFILE_ERR_NOTHING" end
  return clean, n, type(payload.gg) == "string" and payload.gg or "?", P.SectionsIn(clean)
end

local SUB_DEFAULT = { sections = true, raidDifficulties = true }

local function CountHidden(t)
  local n = 0
  for _, v in pairs(t or {}) do if v == false then n = n + 1 end end
  return n
end

function P.Diff(options, clean)
  local cur, out = P.Snapshot(options), {}
  for _, s in ipairs(P.SECTIONS) do
    local present = false
    for _, k in ipairs(s.keys) do if clean[k] ~= nil then present = true end end
    if present then
      local list = {}
      for _, k in ipairs(s.keys) do
        local new, old = clean[k], cur[k]
        if new == nil then
        elseif k == "currencyVisibility" then
          if not Same(old or {}, new) then list[#list + 1] = { key = k, old = CountHidden(old), new = CountHidden(new) } end
        elseif type(new) == "table" and k ~= "accentColor" then
          local keys = {}
          for sub in pairs(new) do keys[sub] = true end
          for sub in pairs(old or {}) do keys[sub] = true end
          local subs = {}
          for sub in pairs(keys) do subs[#subs + 1] = sub end
          table.sort(subs, function(a, b) return tostring(a) < tostring(b) end)
          for _, sub in ipairs(subs) do
            local a, b = (old or {})[sub], new[sub]
            if SUB_DEFAULT[k] then
              if a == nil then a = true end
              if b == nil then b = true end
            end
            if k == "minimap" then a, b = a == true, b == true end
            if a ~= b then list[#list + 1] = { key = k, sub = sub, old = a, new = b } end
          end
        elseif not Same(old, new) then
          list[#list + 1] = { key = k, old = old, new = new }
        end
      end
      out[s.key] = list
    end
  end
  return out
end

function P.ImportAsNew(db, options, clean, sectionSet, name, now)
  local valid, err = P.ValidateName(db, name)
  if not valid then return nil, err end
  P.SaveActive(db, options, now)
  local base = P.Snapshot(options)
  for _, s in ipairs(P.SECTIONS) do
    if sectionSet[s.key] then
      for _, k in ipairs(s.keys) do
        if clean[k] ~= nil then base[k] = Copy(clean[k]) end
      end
    end
  end
  local store = Store(db)
  store.list[valid] = { o = base, at = now }
  store.active = valid
  P.Apply(options, base)
  return valid
end

local logout = CreateFrame("Frame")
logout:RegisterEvent("PLAYER_LOGOUT")
logout:SetScript("OnEvent", function()
  if GGDB and GGDB.options and GGDB.profiles then P.SaveActive(GGDB, GGDB.options, GetServerTime()) end
end)
