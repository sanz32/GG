local ADDON_NAME, GG = ...

GG.Lockouts = {}

local FLEX_DIFFICULTY_BASE = { [233] = 16 }

function GG.Lockouts:BaseDifficultyID(difficultyID)
  if not difficultyID then return difficultyID end
  local base = difficultyID
  if GetBaseDifficultyID then base = GetBaseDifficultyID(difficultyID) or difficultyID end
  return FLEX_DIFFICULTY_BASE[base] or base
end

local serverConfirmed = false

function GG.Lockouts:HasServerData() return serverConfirmed end
function GG.Lockouts:MarkServerData() serverConfirmed = true end

local function InstanceKey(instance)
  return tostring(instance.instanceID) .. ":" .. tostring(GG.Lockouts:BaseDifficultyID(instance.difficultyID))
end

function GG.Lockouts:MergeSavedInstances(fresh, stored, now)
  local byKey, kept = {}, 0
  for _, instance in ipairs(fresh) do byKey[InstanceKey(instance)] = instance end
  for _, old in ipairs(stored or {}) do
    if old.expires and old.expires > now then
      local current = byKey[InstanceKey(old)]
      if not current then
        table.insert(fresh, old)
        for _, enc in ipairs(old.encounters or {}) do
          if enc.isKilled then kept = kept + 1 end
        end
      else
        local byIndex = {}
        for _, enc in ipairs(current.encounters or {}) do byIndex[enc.index] = enc end
        for _, enc in ipairs(old.encounters or {}) do
          if enc.isKilled then
            local match = byIndex[enc.index]
            if not match then
              current.encounters = current.encounters or {}
              table.insert(current.encounters, enc)
              kept = kept + 1
            elseif not match.isKilled then
              match.isKilled = true
              kept = kept + 1
            end
          end
        end
      end
    end
  end
  return fresh, kept
end

function GG.Lockouts:UpdateRaidInstances(fromServer)
  local record = GG:GetOrCreateCharacterRecord()
  record.raids = record.raids or {}
  local stored = record.raids.savedInstances
  local fresh = {}

  local numSavedInstances = GetNumSavedInstances() or 0

  for savedInstanceIndex = 1, numSavedInstances do
    local name, lockoutId, reset, difficultyID, locked, extended, _, isRaid,
      maxPlayers, difficultyName, numEncounters, encounterProgress, _, instanceID =
      GetSavedInstanceInfo(savedInstanceIndex)

    if isRaid and locked then
      local encounters = {}
      for encounterIndex = 1, (numEncounters or 0) do
        local bossName, fileDataID, isKilled = GetSavedInstanceEncounterInfo(savedInstanceIndex, encounterIndex)
        table.insert(encounters, {
          index = encounterIndex,
          bossName = bossName,
          fileDataID = fileDataID,
          isKilled = isKilled == true,
        })
      end

      local baseDifficultyID = self:BaseDifficultyID(difficultyID)

      table.insert(fresh, {
        instanceID = instanceID,
        difficultyID = baseDifficultyID,
        name = name,
        difficultyName = (baseDifficultyID ~= difficultyID and GetDifficultyInfo
          and GetDifficultyInfo(baseDifficultyID)) or difficultyName,
        maxPlayers = maxPlayers,
        numEncounters = numEncounters,
        encounterProgress = encounterProgress,
        reset = reset,
        expires = reset and reset > 0 and (reset + time()) or nil,
        encounters = encounters,
      })
    end
  end

  local kept
  record.raids.savedInstances, kept = self:MergeSavedInstances(fresh, stored, time())
  if kept > 0 and GG.AccountSync and GG.AccountSync.Trace then
    GG.AccountSync:Trace("DIAG_LOCKOUT_KEPT", kept, fromServer and "server" or "client")
  end

  local firstConfirmation = fromServer and not serverConfirmed
  if fromServer then self:MarkServerData() end

  GG:RequestBroadcast("raids")
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
  if firstConfirmation and GG.FlushDeferredLockoutState then GG:FlushDeferredLockoutState() end
end

local raidBossCatalogCache

local function ScanSeasonJournalTier()
  if not (EJ_GetNumTiers and EJ_SelectTier and EJ_GetInstanceByIndex and EJ_GetInstanceInfo) then return nil end
  local known = {}
  for _, raid in ipairs(GG.Season.RAIDS or {}) do known[raid.instanceID] = true end

  local previousTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
  local found
  local numTiers = EJ_GetNumTiers() or 0
  for tier = numTiers, math.max(1, numTiers - 2), -1 do
    EJ_SelectTier(tier)
    local raids, hasSeasonRaid = {}, false
    local index = 1
    while true do
      local journalID = EJ_GetInstanceByIndex(index, true)
      if not journalID then break end
      local _, _, _, _, _, _, _, _, shouldDisplayDifficulty, mapID = EJ_GetInstanceInfo(journalID)
      if mapID and shouldDisplayDifficulty ~= false then
        raids[mapID] = journalID
        if known[mapID] then hasSeasonRaid = true end
      end
      index = index + 1
    end
    if hasSeasonRaid then found = raids break end
  end
  if previousTier then EJ_SelectTier(previousTier) end
  return found
end

function GG.Lockouts:ActivatePendingRaids()
  local pending = GG.Season.PENDING_RAIDS
  if not pending or #pending == 0 then return end
  local ok, tierRaids = pcall(ScanSeasonJournalTier)
  if not ok or not tierRaids then return end

  local claimed = {}
  for _, raid in ipairs(GG.Season.RAIDS) do claimed[raid.instanceID] = true end
  for _, id in ipairs(GG.Season.PREVIOUS_RAID_INSTANCE_IDS or {}) do claimed[id] = true end

  local unknown = {}
  for mapID in pairs(tierRaids) do
    if not claimed[mapID] then table.insert(unknown, mapID) end
  end
  local stillPending = {}
  for _, raid in ipairs(pending) do
    local instanceID = raid.instanceID
    if not tierRaids[instanceID] then
      instanceID = (#pending == 1 and #unknown == 1) and unknown[1] or nil
    end
    if instanceID and not claimed[instanceID] then
      claimed[instanceID] = true
      table.insert(GG.Season.RAIDS, {
        instanceID = instanceID,
        journalInstanceID = tierRaids[instanceID],
        numEncounters = raid.numEncounters,
        name = raid.name,
        bossNames = raid.bossNames,
      bossLetters = raid.bossLetters,
      })
    else
      table.insert(stillPending, raid)
    end
  end
  if #stillPending ~= #pending then
    GG.Season.PENDING_RAIDS = stillPending
    raidBossCatalogCache = nil
  end
end

function GG.Lockouts:ForcePendingRaidsPreview()
  local added = 0
  for _, raid in ipairs(GG.Season.PENDING_RAIDS or {}) do
    table.insert(GG.Season.RAIDS, {
      instanceID = raid.instanceID,
      numEncounters = raid.numEncounters,
      name = raid.name,
      bossNames = raid.bossNames,
      bossLetters = raid.bossLetters,
    })
    added = added + 1
  end
  GG.Season.PENDING_RAIDS = {}
  raidBossCatalogCache = nil
  return added
end

function GG.Lockouts:GetRaidBossCatalog()
  if raidBossCatalogCache then return raidBossCatalogCache end
  self:ActivatePendingRaids()

  raidBossCatalogCache = {}
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    if raid.journalInstanceID then EJ_SelectInstance(raid.journalInstanceID) end
    local bosses = {}
    for encounterIndex = 1, raid.numEncounters do
      local name, journalEncounterID
      if raid.journalInstanceID then
        name, _, journalEncounterID = EJ_GetEncounterInfoByIndex(encounterIndex, raid.journalInstanceID)
      end
      table.insert(bosses, {
        index = encounterIndex,
        name = name or (raid.bossNames and raid.bossNames[encounterIndex]) or "?",
        journalEncounterID = journalEncounterID,
      })
    end
    raidBossCatalogCache[raid.instanceID] = {
      instanceID = raid.instanceID,
      journalInstanceID = raid.journalInstanceID,
      name = raid.name,
      bosses = bosses,
    }
  end

  return raidBossCatalogCache
end

function GG.Lockouts:BossIcon(instanceID, bossIndex)
  local entry = self:GetRaidBossCatalog()[instanceID]
  local boss = entry and entry.bosses[bossIndex]
  if not boss then return nil end
  if boss.icon then return boss.icon end
  if not (boss.journalEncounterID and entry.journalInstanceID) then return nil end
  local ok, icon = pcall(function()
    EJ_SelectInstance(entry.journalInstanceID)
    local _, _, _, _, iconImage = EJ_GetCreatureInfo(1, boss.journalEncounterID)
    return iconImage
  end)
  if ok and icon then boss.icon = icon end
  return ok and icon or nil
end

function GG.Lockouts:BuildKilledLookup(record)
  local lookup = {}
  local now = time()
  for _, instance in ipairs((record and record.raids and record.raids.savedInstances) or {}) do
    local expired = instance.expires and instance.expires <= now
    if not expired then
      local difficultyID = self:BaseDifficultyID(instance.difficultyID)
      for _, enc in ipairs(instance.encounters or {}) do
        if enc.isKilled then
          lookup[instance.instanceID .. ":" .. difficultyID .. ":" .. enc.index] = true
        end
      end
    end
  end
  return lookup
end

function GG.Lockouts:BuildDifficultySlots(record, difficultyID, lookup)
  lookup = lookup or self:BuildKilledLookup(record)
  local slots, killed = {}, 0
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    for encounterIndex = 1, (raid.numEncounters or 0) do
      local isKilled = lookup[raid.instanceID .. ":" .. difficultyID .. ":" .. encounterIndex] == true
      table.insert(slots, isKilled)
      if isKilled then killed = killed + 1 end
    end
  end
  return slots, killed
end

function GG.Lockouts:RaidSlotRange(raidInstanceID)
  if not raidInstanceID then return nil end
  local offset = 0
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    local count = raid.numEncounters or 0
    if raid.instanceID == raidInstanceID then
      return { offset = offset, count = count }
    end
    offset = offset + count
  end
  return nil
end

GG.Lockouts.SHARED_DIFFICULTIES = { 14, 15, 16 }

function GG.Lockouts:BuildSharedState()
  local lookup = self:BuildKilledLookup(GG:GetOrCreateCharacterRecord())
  local masks, total = {}, 0
  for _, difficultyID in ipairs(self.SHARED_DIFFICULTIES) do
    local slots = self:BuildDifficultySlots(nil, difficultyID, lookup)
    total = #slots
    local mask = 0
    for i, killed in ipairs(slots) do
      if killed then mask = mask + 2 ^ (i - 1) end
    end
    masks[difficultyID] = mask
  end
  return { s = GG.Season.SEASON_ID, n = total, d = masks }
end

function GG.Lockouts:ParseSharedState(state)
  if type(state) ~= "table" or type(state.d) ~= "table" then return nil end
  if state.s ~= GG.Season.SEASON_ID then return nil end

  local expected = 0
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    expected = expected + (raid.numEncounters or 0)
  end
  if state.n ~= expected then return nil end

  local out = {}
  for _, difficultyID in ipairs(self.SHARED_DIFFICULTIES) do
    local mask = state.d[difficultyID] or 0
    local slots, killed = {}, 0
    for i = 1, expected do
      local isKilled = math.floor(mask / (2 ^ (i - 1))) % 2 == 1
      slots[i] = isKilled
      if isKilled then killed = killed + 1 end
    end
    out[difficultyID] = { slots = slots, killed = killed, total = expected }
  end
  return out
end
