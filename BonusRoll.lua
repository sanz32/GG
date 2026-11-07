local ADDON_NAME, GG = ...

GG.BonusRoll = {}

local CONTEXT_MAX_AGE_SECONDS = 300
local MAX_ENTRIES = 300

GG.BonusRoll.CONTENT = { raid = "raid", dungeon = "dungeon", delve = "delve", world = "world" }

local lastEncounter
local lastPrompt
local lastChallenge

local function Plain(value)
  if issecretvalue and issecretvalue(value) then return nil end
  return value
end

local function IsFresh(context, now)
  return context ~= nil and context.at ~= nil and now - context.at <= CONTEXT_MAX_AGE_SECONDS
end

local function CurrentInstance()
  local name, instanceType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
  return {
    name = Plain(name),
    instanceType = Plain(instanceType),
    difficultyID = Plain(difficultyID),
    difficultyName = Plain(difficultyName),
    instanceID = Plain(instanceID),
  }
end

function GG.BonusRoll:ContentFor(instanceType)
  if instanceType == "raid" then return self.CONTENT.raid end
  if instanceType == "party" then return self.CONTENT.dungeon end
  if instanceType == "scenario" then return self.CONTENT.delve end
  return self.CONTENT.world
end

function GG.BonusRoll:OnEncounterEnd(encounterID, encounterName, difficultyID, _, success)
  if Plain(success) ~= 1 then return end
  lastEncounter = {
    id = Plain(encounterID),
    name = Plain(encounterName),
    difficultyID = Plain(difficultyID),
    instanceID = CurrentInstance().instanceID,
    at = GetServerTime(),
  }
end

function GG.BonusRoll:OnConfirmationPrompt(_, _, _, _, currencyID, cost, difficultyID)
  currencyID = Plain(currencyID)
  if not currencyID or currencyID == 0 then return end
  lastPrompt = { currencyID = currencyID, cost = Plain(cost), difficultyID = Plain(difficultyID), at = GetServerTime() }
end

function GG.BonusRoll:OnChallengeCompleted()
  if not (C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo) then return end
  local info = C_ChallengeMode.GetChallengeCompletionInfo()
  local level = info and Plain(info.level)
  if level and level > 0 then
    lastChallenge = { level = level, mapID = Plain(info.mapChallengeModeID), at = GetServerTime() }
  end
end

local function ResolveLootSpec(specID)
  specID = Plain(specID)
  if specID and specID > 0 then return specID end
  local lootSpec = GetLootSpecialization and GetLootSpecialization() or 0
  if lootSpec and lootSpec > 0 then return lootSpec end
  local index = GetSpecialization and GetSpecialization()
  return index and GetSpecializationInfo(index) or nil
end

function GG.BonusRoll:BuildEntry(typeIdentifier, itemLink, quantity, specID, currencyID, isSecondaryResult, now)
  typeIdentifier, itemLink, quantity = Plain(typeIdentifier), Plain(itemLink), Plain(quantity)
  currencyID, isSecondaryResult = Plain(currencyID), Plain(isSecondaryResult)
  local instance = CurrentInstance()

  local entry = {
    at = now,
    seasonId = GG.Season and GG.Season.SEASON_ID,
    specID = ResolveLootSpec(specID),
    content = self:ContentFor(instance.instanceType),
    place = instance.name,
    instanceID = instance.instanceID,
    secondary = isSecondaryResult == true or nil,
  }

  if typeIdentifier == "item" and itemLink then
    entry.kind = "item"
    entry.itemLink = itemLink
    entry.itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
  elseif typeIdentifier == "money" then
    entry.kind = "money"
    entry.quantity = quantity
  elseif currencyID and currencyID > 0 then
    entry.kind = "currency"
    entry.currencyID = currencyID
    entry.quantity = quantity
  else
    entry.kind = "other"
  end

  if IsFresh(lastEncounter, now) and lastEncounter.instanceID == instance.instanceID
    and entry.content ~= self.CONTENT.dungeon then
    entry.encounterID = lastEncounter.id
    entry.boss = lastEncounter.name
    local ok, journalInstanceID, journalEncounterID = pcall(self.ResolveJournal, self, entry.encounterID, nil, true)
    if ok then entry.journalInstanceID, entry.journalEncounterID = journalInstanceID, journalEncounterID end
  end

  local prompt = IsFresh(lastPrompt, now) and lastPrompt or nil
  entry.difficultyID = (entry.boss and lastEncounter.difficultyID)
    or (prompt and prompt.difficultyID ~= 0 and prompt.difficultyID)
    or instance.difficultyID
  entry.difficultyName = instance.difficultyName

  if entry.content == self.CONTENT.dungeon then
    local level = C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo and Plain(C_ChallengeMode.GetActiveKeystoneInfo())
    if (not level or level == 0) and IsFresh(lastChallenge, now) then level = lastChallenge.level end
    if level and level > 0 then entry.keystoneLevel = level end
    local mapID = IsFresh(lastChallenge, now) and lastChallenge.mapID or nil
    if not mapID and C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID then
      mapID = Plain(C_ChallengeMode.GetActiveChallengeMapID())
    end
    if mapID and mapID > 0 then entry.challengeMapID = mapID end
  elseif entry.content == self.CONTENT.world then
    entry.place = Plain(GetRealZoneText and GetRealZoneText()) or entry.place
    local sub = Plain(GetSubZoneText and GetSubZoneText())
    if sub and sub ~= "" then entry.subZone = sub end
  end

  if prompt then
    entry.spentCurrencyID, entry.spentCost = prompt.currencyID, prompt.cost
  end

  entry.raw = {
    typeIdentifier = typeIdentifier,
    quantity = quantity,
    specID = Plain(specID),
    currencyID = currencyID,
    instanceType = instance.instanceType,
    instanceDifficultyID = instance.difficultyID,
    encounter = lastEncounter and lastEncounter.name,
    encounterAge = lastEncounter and lastEncounter.at and (now - lastEncounter.at),
    promptDifficultyID = lastPrompt and lastPrompt.difficultyID,
    promptAge = lastPrompt and lastPrompt.at and (now - lastPrompt.at),
  }
  return entry
end

function GG.BonusRoll:LastAt(record)
  local list = record and record.bonusRolls
  local last = type(list) == "table" and list[#list]
  return (type(last) == "table" and last.at) or 0
end

function GG.BonusRoll:Record(entry)
  local record = GG:GetOrCreateCharacterRecord()
  record.bonusRolls = record.bonusRolls or {}
  table.insert(record.bonusRolls, entry)
  while #record.bonusRolls > MAX_ENTRIES do table.remove(record.bonusRolls, 1) end
  GG:RequestBroadcast("bonusRolls")
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
end

function GG.BonusRoll:OnResult(typeIdentifier, itemLink, quantity, specID, _, _, currencyID, isSecondaryResult)
  local entry = self:BuildEntry(typeIdentifier, itemLink, quantity, specID, currencyID, isSecondaryResult, GetServerTime())
  self:Record(entry)
end

local journalCache, portraitCache = {}, {}

function GG.BonusRoll:ResolveJournal(encounterID, journalInstanceID, useCurrentMap)
  if not encounterID or not EJ_GetEncounterInfoByIndex then return nil end
  local cached = journalCache[encounterID]
  if cached then return cached[1], cached[2] end
  local candidates = {}
  if journalInstanceID then table.insert(candidates, journalInstanceID) end
  if useCurrentMap and EJ_GetInstanceForMap and C_Map and C_Map.GetBestMapForUnit then
    local mapID = C_Map.GetBestMapForUnit("player")
    local jid = mapID and EJ_GetInstanceForMap(mapID)
    if jid and jid > 0 then table.insert(candidates, jid) end
  end
  for _, raid in ipairs((GG.Season and GG.Season.RAIDS) or {}) do
    if raid.journalInstanceID then table.insert(candidates, raid.journalInstanceID) end
  end
  for _, jid in ipairs(candidates) do
    if EJ_SelectInstance then EJ_SelectInstance(jid) end
    for i = 1, 30 do
      local name, _, journalEncounterID, _, _, _, dungeonEncounterID = EJ_GetEncounterInfoByIndex(i, jid)
      if not name then break end
      if dungeonEncounterID == encounterID then
        journalCache[encounterID] = { jid, journalEncounterID }
        return jid, journalEncounterID
      end
    end
  end
  return nil
end

local journeyKits
function GG.BonusRoll:JourneyKits()
  if journeyKits then return journeyKits end
  local kits, list = {}, {}
  if C_MajorFactions and C_MajorFactions.GetMajorFactionIDs and C_MajorFactions.ShouldDisplayMajorFactionAsJourney then
    for _, id in ipairs(C_MajorFactions.GetMajorFactionIDs(LE_EXPANSION_LEVEL_CURRENT) or {}) do
      if C_MajorFactions.ShouldDisplayMajorFactionAsJourney(id) then
        local data = C_MajorFactions.GetMajorFactionData(id)
        local kit = data and data.textureKit
        if kit then
          table.insert(list, { id = id, name = data.name, kit = kit })
          local low = kit:lower()
          if low:find("delve") then kits.delve = kits.delve or kit
          elseif low:find("prey") or low:find("hunt") then kits.prey = kits.prey or kit end
        end
      end
    end
  end
  kits.list = list
  if #list > 0 then journeyKits = kits end
  return kits
end

function GG.BonusRoll:Portrait(entry)
  if entry.content == self.CONTENT.dungeon then
    if entry.challengeMapID and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
      local _, _, _, texture = C_ChallengeMode.GetMapUIInfo(entry.challengeMapID)
      if texture and texture ~= 0 then return texture, "square" end
    end
    return nil
  end
  if entry.content == self.CONTENT.delve or (entry.content == self.CONTENT.world and not entry.encounterID) then
    local ok, kits = pcall(self.JourneyKits, self)
    local kit = ok and kits and (entry.content == self.CONTENT.delve and kits.delve or kits.prey)
    if kit then return ("ui-journeys-%s-button"):format(kit), "atlas" end
    return nil
  end
  local jid, jeid = entry.journalInstanceID, entry.journalEncounterID
  if not jeid and entry.encounterID then
    local ok, a, b = pcall(self.ResolveJournal, self, entry.encounterID)
    if ok then jid, jeid = a, b end
  end
  if not jeid and entry.instanceID and entry.boss and GG.Lockouts and GG.Lockouts.GetRaidBossCatalog then
    local ok, catalog = pcall(GG.Lockouts.GetRaidBossCatalog, GG.Lockouts)
    local raidEntry = ok and catalog and catalog[entry.instanceID]
    for _, boss in ipairs((raidEntry and raidEntry.bosses) or {}) do
      if boss.name == entry.boss and boss.journalEncounterID then jeid = boss.journalEncounterID end
    end
    for _, raid in ipairs((GG.Season and GG.Season.RAIDS) or {}) do
      if raid.instanceID == entry.instanceID then jid = raid.journalInstanceID end
    end
  end
  if not (jid and jeid and EJ_SelectInstance and EJ_GetCreatureInfo) then return nil end
  if not portraitCache[jeid] then
    local ok, icon = pcall(function()
      EJ_SelectInstance(jid)
      return (select(5, EJ_GetCreatureInfo(1, jeid)))
    end)
    if ok and icon then portraitCache[jeid] = icon end
  end
  if not portraitCache[jeid] then return nil end
  return portraitCache[jeid], "wide"
end

local demo

local DEMO_ITEMS = {
  "|cnIQ4:|Hitem:270175::::::::90:105::95:2:13334:12849::::::|h[Voracious Heart of Ula'tek]|h|r",
  "|cnIQ4:|Hitem:270162::::::::90:105::96:3:6652:13335:12854::::::|h[Soulcoiler Ritual Vessel]|h|r",
  "|cnIQ4:|Hitem:273774::::::::90:105::35:4:12849:13440:13662:12699::::::|h[Snakeskin Spaulders]|h|r",
}

local function SpecsForClass(classFile)
  local specs = {}
  if not (GetNumClasses and GetClassInfo and GetSpecializationInfoForClassID) then return specs end
  for classID = 1, GetNumClasses() do
    local _, file = GetClassInfo(classID)
    if file == classFile then
      for i = 1, (GetNumSpecializationsForClassID and GetNumSpecializationsForClassID(classID) or 4) do
        local specID = GetSpecializationInfoForClassID(classID, i)
        if specID then table.insert(specs, specID) end
      end
    end
  end
  return specs
end

function GG.BonusRoll:IsDemo() return demo ~= nil end

function GG.BonusRoll:ToggleDemo()
  if demo then
    demo = nil
    return false
  end
  local now, season = GetServerTime(), GG.Season and GG.Season.SEASON_ID
  local function E(rowIndex, specIndex, minutesAgo, fields)
    fields.at, fields.seasonId = now - minutesAgo * 60, season
    fields.rowIndex, fields.specIndex = rowIndex, specIndex
    fields.kind = fields.kind or "item"
    return fields
  end
  local raidName, journalInstanceID, bosses = "Venomous Abyss", nil, {}
  local catalog = GG.Lockouts and GG.Lockouts.GetRaidBossCatalog and GG.Lockouts:GetRaidBossCatalog() or {}
  for _, raid in ipairs((GG.Season and GG.Season.RAIDS) or {}) do
    local entry = catalog[raid.instanceID]
    if entry and #(entry.bosses or {}) >= 2 then
      raidName, journalInstanceID, bosses = raid.name or raidName, raid.journalInstanceID, entry.bosses
      break
    end
  end
  local function Boss(i)
    local b = bosses[i]
    return (b and b.name) or ({ "Ula'tek", "Nek'zali the Soulcoiler" })[i], b and b.journalEncounterID
  end
  local function R(bossIndex, id, diff, extra)
    local name, journalEncounterID = Boss(bossIndex)
    local t = { content = "raid", place = raidName, boss = name, encounterID = id, difficultyID = diff,
      journalInstanceID = journalEncounterID and journalInstanceID, journalEncounterID = journalEncounterID }
    for k, v in pairs(extra or {}) do t[k] = v end
    return t
  end
  local dungeonID = C_ChallengeMode and C_ChallengeMode.GetMapTable and (C_ChallengeMode.GetMapTable() or {})[1]
  local dungeonName = dungeonID and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(dungeonID)
  demo = {
    E(1, 1, 20,   R(1, 1, 16, { itemLink = DEMO_ITEMS[1], itemLevel = 337 })),
    E(1, 2, 60,   R(2, 2, 16, { itemLink = DEMO_ITEMS[2], itemLevel = 337 })),
    E(1, 2, 3200, R(2, 2, 16, { itemLink = DEMO_ITEMS[1], itemLevel = 337 })),
    E(1, 2, 3300, R(2, 2, 16, { itemLink = DEMO_ITEMS[3], itemLevel = 334 })),
    E(1, 2, 4400, R(2, 2, 16, { itemLink = DEMO_ITEMS[2], itemLevel = 334 })),
    E(1, 2, 4500, R(2, 2, 16, { itemLink = DEMO_ITEMS[1], itemLevel = 331 })),
    E(1, 2, 5600, R(2, 2, 16, { itemLink = DEMO_ITEMS[3], itemLevel = 331 })),
    E(1, 2, 95,   R(1, 1, 16, { kind = "money", quantity = 4120000 })),
    E(1, 1, 1500, R(1, 1, 16, { itemLink = DEMO_ITEMS[3], itemLevel = 337 })),
    E(1, 1, 1520, R(1, 1, 16, { itemLink = DEMO_ITEMS[2], itemLevel = 337 })),
    E(2, 1, 1700, R(1, 1, 15, { itemLink = DEMO_ITEMS[3], itemLevel = 334 })),
    E(1, 1, 2900, { content = "dungeon", place = dungeonName or "Mazmorra de prueba", challengeMapID = dungeonID,
      difficultyID = 8, keystoneLevel = 12, itemLink = DEMO_ITEMS[3], itemLevel = 330 }),
    E(1, 2, 3100, { content = "dungeon", place = dungeonName or "Mazmorra de prueba", challengeMapID = dungeonID,
      difficultyID = 8, keystoneLevel = 10, itemLink = DEMO_ITEMS[1], itemLevel = 327 }),
    E(2, 2, 4300, { content = "delve", place = "Delve de prueba", difficultyName = "Tier 11", difficultyID = 208,
      itemLink = DEMO_ITEMS[1], itemLevel = 320 }),
    E(1, 3, 5800, { content = "world", place = "Zul'Aman", subZone = "Prey", itemLink = DEMO_ITEMS[2], itemLevel = 327 }),
  }
  return true
end

local function DemoItems(rows)
  local out = {}
  if not demo then return out end
  for _, entry in ipairs(demo) do
    local row = rows[entry.rowIndex] or rows[1]
    if row then
      local specs = SpecsForClass(row.class)
      entry.specID = specs[entry.specIndex] or specs[1]
      table.insert(out, { entry = entry, row = row })
    end
  end
  return out
end

function GG.BonusRoll:LastEntry()
  local record = GG:GetOrCreateCharacterRecord()
  local list = record.bonusRolls
  return list and list[#list]
end

GG.BonusRoll.DIFFICULTY_ORDER = { "lfr", "normal", "heroic", "mythic" }
GG.BonusRoll.DIFFICULTY_BASE_ID = { lfr = 17, normal = 14, heroic = 15, mythic = 16 }

function GG.BonusRoll:DifficultyBucket(entry)
  local id = entry.difficultyID
  if id == 17 or id == 7 then return "lfr" end
  if id == 14 then return "normal" end
  if id == 15 then return "heroic" end
  if id == 16 then return "mythic" end
  if id and GetDifficultyInfo then
    local name, _, isHeroic, _, displayHeroic, displayMythic, _, isLFR = GetDifficultyInfo(id)
    if displayMythic then return "mythic" end
    if isLFR then return "lfr" end
    if displayHeroic or isHeroic then return "heroic" end
    local function has(baseID)
      local word = GetDifficultyInfo(baseID)
      return name and word and word ~= "" and name:find(word, 1, true) ~= nil
    end
    if has(16) then return "mythic" end
    if has(15) then return "heroic" end
    if has(17) then return "lfr" end
  end
  return "normal"
end

local function MatchesDifficulty(self, entry, difficulty)
  return not difficulty or entry.content ~= self.CONTENT.raid or self:DifficultyBucket(entry) == difficulty
end

function GG.BonusRoll:Collect(rows, filter)
  filter = filter or {}
  local seasonId = GG.Season and GG.Season.SEASON_ID
  local list = {}
  for _, row in ipairs(rows or {}) do
    local record = row.rawRecord
    if (not filter.character or filter.character == row.key) and record and record.bonusRolls then
      for _, entry in ipairs(record.bonusRolls) do
        if (not seasonId or entry.seasonId == seasonId)
          and (not filter.content or filter.content == entry.content)
          and MatchesDifficulty(self, entry, filter.difficulty) then
          table.insert(list, { entry = entry, row = row })
        end
      end
    end
  end
  for _, item in ipairs(DemoItems(rows or {})) do
    if (not filter.character or filter.character == item.row.key)
      and (not filter.content or filter.content == item.entry.content)
      and MatchesDifficulty(self, item.entry, filter.difficulty) then
      table.insert(list, item)
    end
  end
  table.sort(list, function(a, b) return (a.entry.at or 0) > (b.entry.at or 0) end)
  return list
end

function GG.BonusRoll:CharactersWithRolls(rows)
  local seasonId = GG.Season and GG.Season.SEASON_ID
  local out, inDemo = {}, {}
  for _, item in ipairs(DemoItems(rows or {})) do inDemo[item.row] = true end
  for _, row in ipairs(rows or {}) do
    local has = inDemo[row]
    for _, entry in ipairs((row.rawRecord and row.rawRecord.bonusRolls) or {}) do
      if has then break end
      if not seasonId or entry.seasonId == seasonId then has = true end
    end
    if has then table.insert(out, row) end
  end
  return out
end

local function GroupKey(entry)
  if entry.content == "dungeon" then
    return "d" .. tostring(entry.challengeMapID or entry.place)
  end
  local who = entry.encounterID and ("e" .. entry.encounterID) or ("p" .. tostring(entry.place) .. "/" .. tostring(entry.subZone))
  return who .. "|" .. tostring(entry.difficultyID)
end

function GG.BonusRoll:GroupByBoss(collected)
  local groups, byKey = {}, {}
  for _, item in ipairs(collected) do
    local entry = item.entry
    local key = GroupKey(entry)
    local group = byKey[key]
    if not group then
      group = { key = key, sample = entry, lanes = {}, laneByKey = {}, lastAt = entry.at or 0 }
      byKey[key] = group
      table.insert(groups, group)
    end
    local laneKey = tostring(item.row.key) .. "#" .. tostring(entry.specID)
    local lane = group.laneByKey[laneKey]
    if not lane then
      lane = { row = item.row, specID = entry.specID, entries = {}, rolls = 0, lastAt = entry.at or 0 }
      group.laneByKey[laneKey] = lane
      table.insert(group.lanes, lane)
    end
    table.insert(lane.entries, entry)
    if not entry.secondary then lane.rolls = lane.rolls + 1 end
  end
  return groups
end
