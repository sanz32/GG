local ADDON_NAME, GG = ...

GG.GroupLockouts = {}

GG.GroupLockouts.STALE_AFTER_SECONDS = 120

GG.GroupLockouts.COLLECT_SECONDS = 6

GG.GroupLockouts.MIN_SECONDS_BETWEEN_REQUESTS = 5

local responses = {}
local lastRequestAt = 0

GG.GroupLockouts.trace = false

function GG.GroupLockouts:Text(key)
  local AceLocale = LibStub and LibStub("AceLocale-3.0", true)
  local L = AceLocale and AceLocale:GetLocale("GG", true)
  return (L and L[key]) or key
end

function GG.GroupLockouts:Trace(msg)
  if not self.trace then return end
  print("|cff8B5CF6GG|r |cffffd100" .. self:Text("DIAG_NET_TAG") .. "|r " .. msg)
end

function GG.GroupLockouts:UnitKey(unit)
  local name, realm = UnitName(unit)
  if not name or name == "" then return nil end
  if not realm or realm == "" then realm = GetRealmName() end
  if not realm then return nil end
  return name .. "-" .. (realm:gsub("%s+", ""))
end

function GG.GroupLockouts:GetGroupMembers()
  if not IsInRaid() then return nil end

  local members = {}
  for i = 1, GetNumGroupMembers() do
    local unit = "raid" .. i
    local key = self:UnitKey(unit)
    if key then
      local _, class = UnitClass(unit)
      local name, realm = UnitName(unit)
      if not realm or realm == "" then realm = GetRealmName() end
      table.insert(members, {
        key = key,
        unit = unit,
        name = name,
        realm = realm,
        class = class,
        isSelf = UnitIsUnit(unit, "player"),
      })
    end
  end
  return members
end

function GG.GroupLockouts:StoreResponse(characterKey, state, addonVersion)
  if not characterKey then return end
  local parsed = GG.Lockouts:ParseSharedState(state)
  responses[characterKey] = {
    state = parsed,
    incompatible = parsed == nil,
    receivedAt = time(),
    addonVersion = addonVersion,
  }

  self:Trace(self:Text("DIAG_NET_ANSWER"):format(
    characterKey, tostring(addonVersion),
    parsed and self:Text("DIAG_NET_READABLE") or self:Text("DIAG_NET_DISCARDED")))
end

function GG.GroupLockouts:GetMemberStatus(characterKey, difficultyID, range)
  local entry = responses[characterKey]

  if characterKey == GG:GetCharacterKey() then
    entry = {
      state = GG.Lockouts:ParseSharedState(GG.Lockouts:BuildSharedState()),
      receivedAt = time(),
      addonVersion = GG.VERSION,
      unconfirmed = GG.Lockouts.HasServerData ~= nil and not GG.Lockouts:HasServerData(),
    }
  end

  if entry and entry.state then
    local perDifficulty = entry.state[difficultyID]
    local allSlots = (perDifficulty and perDifficulty.slots) or {}

    local slots, killed = {}, 0
    local from = range and (range.offset + 1) or 1
    local to = range and (range.offset + range.count) or #allSlots
    for i = from, to do
      local isKilled = allSlots[i] == true
      table.insert(slots, isKilled)
      if isKilled then killed = killed + 1 end
    end

    local status = killed > 0 and "saved" or "unsaved"
    if status == "unsaved" and entry.unconfirmed then status = "nodata" end
    return {
      status = status,
      slots = slots,
      killed = killed,
      total = #slots,
      receivedAt = entry.receivedAt,
      addonVersion = entry.addonVersion,
    }
  end

  local cached = GGDB and GGDB.chars and GGDB.chars[characterKey]
  local cachedVersion = cached and cached.addonVersion

  local status
  if entry and entry.incompatible then
    status = "outdated"
  elseif not cachedVersion then
    status = "noaddon"
  elseif GG:CompareVersions(GG.VERSION, cachedVersion) > 0 then
    status = "outdated"
  else
    status = "nodata"
  end

  return {
    status = status,
    slots = {},
    killed = 0,
    total = 0,
    receivedAt = nil,
    addonVersion = cachedVersion,
  }
end

local demoRows

local DEMO_NAMES = {
  { "Thalryn", "Sargeras", "MAGE" }, { "Brakkor", "Area52", "PRIEST" },
  { "Velisande", "Ragnaros", "DEATHKNIGHT" }, { "Morwick", "Ragnaros", "WARLOCK" },
  { "Ishkára", "QuelThalas", "PALADIN" }, { "Tovren", "Stormrage", "MONK" },
  { "Grimbel", "Proudmoore", "WARLOCK" }, { "Ashlocke", "Stormrage", "ROGUE" },
  { "Fennwyn", "Proudmoore", "DRUID" }, { "Korvash", "Illidan", "HUNTER" },
  { "Zhaelin", "Tichondrius", "SHAMAN" }, { "Durnhal", "Area52", "WARRIOR" },
  { "Elowenwhisperleaf", "Quel'Thalas", "EVOKER" }, { "Nyxarë", "Sargeras", "DEMONHUNTER" },
  { "Orrin", "Ragnaros", "PRIEST" }, { "Lysandre", "Sargeras", "MAGE" },
  { "Corvane", "Area52", "PALADIN" }, { "Mirelle", "Stormrage", "DRUID" },
  { "Vexmora", "Illidan", "WARLOCK" }, { "Tamsin", "Proudmoore", "MONK" },
  { "Rhovan", "Tichondrius", "HUNTER" }, { "Sylvaine", "Sargeras", "ROGUE" },
  { "Kaelith", "Area52", "SHAMAN" }, { "Bramwell", "Ragnaros", "WARRIOR" },
  { "Quillon", "Stormrage", "DEATHKNIGHT" },
}

function GG.GroupLockouts:IsDemo() return demoRows ~= nil end

function GG.GroupLockouts:ToggleDemo()
  if demoRows then
    demoRows = nil
    return false
  end

  local rand = 12345
  local function nextRandom(max)
    rand = (rand * 1103515245 + 12345) % 2147483648
    return (rand % max) + 1
  end

  local totalBosses = 0
  for _, raid in ipairs(GG.Season.RAIDS or {}) do totalBosses = totalBosses + (raid.numEncounters or 0) end

  demoRows = {}
  for i, person in ipairs(DEMO_NAMES) do
    local name, realm, class = person[1], person[2], person[3]
    local bucket = nextRandom(10)
    local status, killed, slots = "unsaved", 0, {}

    if bucket <= 3 then
      status = "saved"
      killed = nextRandom(totalBosses)
    elseif bucket <= 6 then
      status = ({ "noaddon", "outdated", "nodata" })[nextRandom(3)]
    end

    if status == "saved" or status == "unsaved" then
      for slot = 1, totalBosses do slots[slot] = false end
      local placed = 0
      while placed < killed do
        local slot = nextRandom(totalBosses)
        if not slots[slot] then
          slots[slot] = true
          placed = placed + 1
        end
      end
    end

    table.insert(demoRows, {
      key = name .. "-" .. realm,
      name = name, realm = realm, class = class,
      isSelf = i == 1,
      status = status,
      slots = slots,
      killed = killed,
      total = (status == "saved" or status == "unsaved") and totalBosses or 0,
      receivedAt = (status == "saved" or status == "unsaved") and (time() - nextRandom(90)) or nil,
      addonVersion = status == "outdated" and "0.1.6" or (status == "noaddon" and nil or GG.VERSION),
    })
  end
  return true
end

local STATUS_ORDER = { saved = 1, outdated = 2, noaddon = 3, nodata = 4, unsaved = 5 }

function GG.GroupLockouts:BuildRows(difficultyID, raidInstanceID)
  local range = GG.Lockouts:RaidSlotRange(raidInstanceID)
  local rows

  if demoRows then
    rows = {}
    for _, row in ipairs(demoRows) do
      local copy = {}
      for k, v in pairs(row) do copy[k] = v end
      if range and (row.status == "saved" or row.status == "unsaved") then
        local slots, killed = {}, 0
        for i = range.offset + 1, range.offset + range.count do
          local isKilled = row.slots[i] == true
          table.insert(slots, isKilled)
          if isKilled then killed = killed + 1 end
        end
        copy.slots, copy.killed, copy.total = slots, killed, #slots
        copy.status = killed > 0 and "saved" or "unsaved"
      end
      table.insert(rows, copy)
    end
  else
    local members = self:GetGroupMembers()
    if not members then return nil end
    rows = {}
    for _, member in ipairs(members) do
      local status = self:GetMemberStatus(member.key, difficultyID, range)
      status.key = member.key
      status.name = member.name
      status.realm = member.realm
      status.class = member.class
      status.isSelf = member.isSelf
      table.insert(rows, status)
    end
  end

  table.sort(rows, function(a, b)
    local ao, bo = STATUS_ORDER[a.status] or 9, STATUS_ORDER[b.status] or 9
    if ao ~= bo then return ao < bo end
    if a.killed ~= b.killed then return a.killed > b.killed end
    return (a.name or ""):lower() < (b.name or ""):lower()
  end)
  return rows
end

function GG.GroupLockouts:Summarize(rows)
  local summary = { saved = 0, unsaved = 0, unknown = 0, total = 0 }
  for _, row in ipairs(rows or {}) do
    summary.total = summary.total + 1
    if row.status == "saved" then
      summary.saved = summary.saved + 1
    elseif row.status == "unsaved" then
      summary.unsaved = summary.unsaved + 1
    else
      summary.unknown = summary.unknown + 1
    end
  end
  return summary
end

function GG.GroupLockouts:LastUpdateAt()
  local newest
  for _, entry in pairs(responses) do
    if entry.receivedAt and (not newest or entry.receivedAt > newest) then
      newest = entry.receivedAt
    end
  end
  return newest
end

function GG.GroupLockouts:DebugLines()
  local members = self:GetGroupMembers()
  if not members then return nil end

  local lines = {}
  for _, member in ipairs(members) do
    local entry = responses[member.key]
    local what
    if member.isSelf then
      what = self:Text("DIAG_NET_SELF")
    elseif not entry then
      what = self:Text("DIAG_NET_NO_ANSWER")
    elseif entry.incompatible then
      what = self:Text("DIAG_NET_OTHER_SEASON")
    else
      what = self:Text("DIAG_NET_ANSWERED"):format(time() - (entry.receivedAt or time()),
        tostring(entry.addonVersion))
    end
    table.insert(lines, ("  %s -> %s"):format(member.key, what))
  end
  return lines
end

function GG.GroupLockouts:Request(force)
  if not IsInGroup() then return false end
  local now = time()
  if not force and (now - lastRequestAt) < self.MIN_SECONDS_BETWEEN_REQUESTS then
    return false
  end
  lastRequestAt = now
  GG:SendLockoutRequest()
  return true
end

function GG.GroupLockouts:Reset()
  responses = {}
  lastRequestAt = 0
end
