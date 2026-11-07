local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.CharacterTooltip = {}
local CT = GG.CharacterTooltip

local FACTION_COLORS = {
  Alliance = { 0.29, 0.62, 1.00, 1 },
  Horde = { 1.00, 0.36, 0.36, 1 },
}
local FACTION_NAMES = { Alliance = "FACTION_ALLIANCE", Horde = "FACTION_HORDE" }
local ROLE_KEYS = { TANK = "ARRANGE_ROLE_TANK", HEALER = "ARRANGE_ROLE_HEALER", DAMAGER = "ARRANGE_ROLE_DAMAGER" }

function CT.FormatAge(age)
  if age < 3600 then return L["ROSTER_LAST_UPDATE_MINUTES"]:format(math.max(1, math.floor(age / 60))) end
  if age < 86400 then return L["ROSTER_LAST_UPDATE_HOURS"]:format(math.floor(age / 3600)) end
  return L["ROSTER_LAST_UPDATE_DAYS"]:format(math.floor(age / 86400))
end

local function Split(list)
  local out = {}
  for word in list:gmatch("[^,]+") do out[#out + 1] = word end
  return out
end

function CT.FormatWhen(ts)
  local d = date("*t", ts)
  local values = {
    w = Split(L["TOOLTIP_WEEKDAYS"])[d.wday],
    m = Split(L["TOOLTIP_MONTHS"])[d.month],
    d = tostring(d.day),
    t = ("%02d:%02d"):format(d.hour, d.min),
  }
  return (L["TOOLTIP_WHEN"]:gsub("{(%a)}", values))
end

function CT.Status(datum, now)
  if datum.isCurrent then return { kind = "current", head = L["TOOLTIP_PLAYING"] } end
  local account = datum.accountLabel or "?"
  local f = datum.freshness
  if f and f.live then
    return { kind = "live", head = L["TOOLTIP_LIVE"], sub = L["TOOLTIP_ACCOUNT_ON"]:format(account) }
  end
  if f and f.age then
    return {
      kind = f.stale and "old" or "recent",
      head = L["FRESH_TIP_TITLE"]:format(CT.FormatAge(f.age)),
      sub = CT.FormatWhen(now - f.age) .. " · " .. L["TOOLTIP_ACCOUNT_OFF"]:format(account),
      hint = f.stale and L["FRESH_TIP_HINT"]:format(account) or nil,
    }
  end
  if datum.lastSeen then
    local age = math.max(0, now - datum.lastSeen)
    return { kind = "own", head = L["FRESH_TIP_TITLE"]:format(CT.FormatAge(age)), sub = CT.FormatWhen(datum.lastSeen) }
  end
  return nil
end

local function ClassName(token)
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[token]) or token or "?"
end

local function SpecName(specID)
  if not specID or not GetSpecializationInfoByID then return nil end
  local _, name = GetSpecializationInfoByID(specID)
  return name
end

local function RaceName(raceID)
  if not raceID or not (C_CreatureInfo and C_CreatureInfo.GetRaceInfo) then return nil end
  local info = C_CreatureInfo.GetRaceInfo(raceID)
  return info and info.raceName or nil
end

function CT.Build(datum, now)
  local rows = {}
  local className, spec = ClassName(datum.class), SpecName(datum.specID)
  if spec then
    rows[#rows + 1] = { label = L["TOOLTIP_SPEC"], value = spec .. " " .. className }
  else
    local role = ROLE_KEYS[datum.role] and L[ROLE_KEYS[datum.role]]
    rows[#rows + 1] = { label = L["TOOLTIP_CLASS"], value = role and (className .. " · " .. role) or className }
  end
  local race = RaceName(datum.raceID)
  if race then rows[#rows + 1] = { label = L["TOOLTIP_RACE"], value = race } end
  local factionName = FACTION_NAMES[datum.faction] and _G[FACTION_NAMES[datum.faction]]
  if factionName then
    rows[#rows + 1] = { label = L["TOOLTIP_FACTION"], value = factionName, color = FACTION_COLORS[datum.faction] }
  end

  return {
    name = datum.name, realm = datum.realm, guild = datum.guild, level = datum.level,
    class = datum.class, isMain = datum.isMain == true,
    rows = rows,
    money = datum.money,
    moneyTotal = (datum.moneyCount or 0) >= 2 and datum.moneyTotal or nil,
    status = CT.Status(datum, now),
    actions = {
      { key = L["TOOLTIP_CLICK"], text = L["TOOLTIP_CLICK_EQUIP"] },
      { key = L["TOOLTIP_SHIFT"], text = L["TOOLTIP_SHIFT_LINK"] },
      { key = L["TOOLTIP_RIGHT"], text = L["TOOLTIP_RIGHT_HIDE"] },
    },
  }
end

local function StatusLook(kind)
  local Theme = GG.Theme
  if kind == "current" or kind == "live" then return Theme.success, Theme.media.dot end
  if kind == "old" then return Theme.gold, Theme.media.clock end
  return Theme.textMuted, Theme.media.clock
end

local function WholeGold(copper) return GetMoneyString(copper - copper % 10000, true) end

function CT.Draw(t, datum, now)
  local Theme = GG.Theme
  local model = CT.Build(datum, now)
  local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[model.class]
  if classColor then t:SetColor({ classColor.r, classColor.g, classColor.b, 1 }) end

  local place = model.realm or ""
  if model.guild then place = place .. " · " .. GG.Tip.Paint(model.guild, Theme.success) end
  t:Identity({
    coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[model.class],
    isMain = model.isMain,
    badge = model.isMain and L["ROSTER_TAG_MAIN"] or nil,
    name = model.name, place = place,
    level = model.level, levelLabel = L["TOOLTIP_LEVEL"],
  })

  for _, row in ipairs(model.rows) do t:Kv(row.label, row.value, row.color) end
  if model.money then
    if #model.rows > 0 then t:Sep() end
    t:Kv(L["TOOLTIP_GOLD"], GetMoneyString(model.money, true))
    if model.moneyTotal then t:Kv(L["TOOLTIP_GOLD_ALL"], WholeGold(model.moneyTotal)) end
  end

  local status = model.status
  if status then
    t:Sep()
    local color, icon = StatusLook(status.kind)
    t:Line(icon, color, status.head)
    if status.sub then t:Text(status.sub, Theme.textFaint, true) end
    if status.hint then t:Text(status.hint, Theme.gold, true) end
  end

  for _, action in ipairs(model.actions) do t:Action(action.key, action.text) end
end

function CT:Show(owner, getDatum, alsoOver)
  GG.Tip:Open(owner, { watch = getDatum, alsoOver = alsoOver }, function(t, datum)
    CT.Draw(t, datum, GetServerTime())
  end)
end

function CT:Hide() GG.Tip:Hide() end
