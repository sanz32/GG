local ADDON_NAME, GG = ...

GG.Roster = {}

local RAID_DIFFICULTY_IDS = { 17, 14, 15, 16 }

local function CountUnlockedByType(record, wantedType)
  if not GG.Vault:IsCurrentWeek(record) then return 0 end

  local count = 0
  for _, slot in ipairs((record.vault and record.vault.slots) or {}) do
    if slot.type == wantedType and slot.unlocked then
      count = count + 1
    end
  end
  return math.min(count, 3)
end

local function BuildVaultCounts(record)
  return {
    raid = CountUnlockedByType(record, Enum.WeeklyRewardChestThresholdType.Raid),
    mplus = CountUnlockedByType(record, Enum.WeeklyRewardChestThresholdType.Activities),
    world = CountUnlockedByType(record, Enum.WeeklyRewardChestThresholdType.World),
    hasAvailableRewards = GG.Vault:HasPendingRewards(record),
    claim = GG.Vault:GetClaimThisWeek(record),
  }
end

local function BuildRaidProgress(record)
  local byDifficulty = {}
  local lookup = GG.Lockouts:BuildKilledLookup(record)
  for _, difficultyID in ipairs(RAID_DIFFICULTY_IDS) do
    local slots, killed = GG.Lockouts:BuildDifficultySlots(record, difficultyID, lookup)
    byDifficulty[difficultyID] = { slots = slots, killed = killed, total = #slots }
  end
  return { byDifficulty = byDifficulty }
end

local function BuildNemesisStatus(record)
  return record.nemesis
end

local function BuildKeystone(record)
  local keystone = GG.Vault:CurrentKeystone(record)
  if not keystone then return nil end
  return {
    dungeon = keystone.dungeonName,
    challengeModeID = keystone.challengeModeID,
    level = keystone.level,
  }
end

local function BuildBountyStatus(record)
  if not record.bounty or record.bounty.weekKey ~= GG:GetWeekKey() then return nil end
  return record.bounty
end

local function BuildAllCurrencies(record)
  local out = {}
  local slot = 0
  for _, cells in ipairs(GG.Currencies:GridGroups()) do
    for _, cell in ipairs(cells) do
      slot = slot + 1
      local key = tostring(cell.id)
      if cell.kind == "bounty" then
        local status = BuildBountyStatus(record)
        out[#out + 1] = { kind = "bounty", slot = slot, bounty = status,
          data = { iconFileID = status and status.iconFileID } }
      elseif cell.kind == "currency" then
        local currency = record.currencies and record.currencies[key]
        if currency then
          out[#out + 1] = { kind = "currency", slot = slot, data = GG.Currencies:ForDisplay(currency, record) }
        end
      else
        local item = record.items and record.items[key]
        if item then out[#out + 1] = { kind = "item", slot = slot, data = item } end
      end
    end
  end
  return out
end

GG.Roster.STALE_AFTER_SECONDS = 12 * 60 * 60

function GG.Roster:Freshness(record, isOwn, now, isLive, accountLiveAt)
  if isOwn then return nil end
  if isLive then return { live = true } end
  local since = math.max(record.ts or 0, accountLiveAt or 0)
  if since <= 0 then return nil end
  local age = math.max(0, now - since)
  return { age = age, stale = age > self.STALE_AFTER_SECONDS }
end

function GG.Roster:ClockState(freshness)
  if not freshness or freshness.live or not freshness.age then return nil end
  return freshness.stale and "old" or "recent"
end

function GG.Roster:AccountStatus(rows)
  local byAccount, list = {}, {}
  for _, row in ipairs(rows) do
    local f = row.freshness
    local id = f and row.rawRecord and (row.rawRecord.installId or row.accountLabel)
    if id then
      local entry = byAccount[id]
      if not entry then
        entry = { slot = row.accountSlot or 99, label = row.accountLabel, live = false }
        byAccount[id] = entry
        table.insert(list, entry)
      end
      if f.live then entry.live = true end
      if f.age and (not entry.age or f.age < entry.age) then entry.age = f.age end
    end
  end
  table.sort(list, function(a, b) return a.slot < b.slot end)
  return list
end

function GG.Roster:BuildRows(includeHidden)
  local rows = {}
  local myAccountHash = GG:GetAccountHash()
  local linkedHashes = GG:GetLinkedAccountHashMap()
  local now = GetServerTime()
  local Sync = GG.AccountSync
  local moneyTotal, moneyCount = 0, 0

  for key, record in pairs(GGDB.chars or {}) do
    local isOwn = GGDB.ownCharacters and GGDB.ownCharacters[key]
    local sameBattletag = false
    if not isOwn and record.accountHash and myAccountHash then
      sameBattletag = record.accountHash == myAccountHash
    end

    local linkedTag = nil
    if not isOwn and not sameBattletag and record.accountHash then
      linkedTag = linkedHashes[record.accountHash]
    end

    local isHidden = GG:IsCharacterHidden(key)

    if (isOwn or sameBattletag or linkedTag) and type(record.money) == "number" then
      moneyTotal = moneyTotal + record.money
      moneyCount = moneyCount + 1
    end

    if (isOwn or sameBattletag or linkedTag) and record.name and record.realm and record.class
      and (includeHidden or not isHidden) then
      local realTag = linkedTag
      if not realTag and (isOwn or sameBattletag) then
        realTag = GGDB.account and GGDB.account.battleTag
      end
      local accountLabel = GG:FormatAccountLabel(record.accountSlot, realTag)

      table.insert(rows, {
        key = key,
        hidden = isHidden,
        isOwn = isOwn == true,
        rawRecord = record,
        name = record.name,
        realm = record.realm,
        class = record.class,
        level = record.level or 0,
        role = record.role,
        specID = record.specID,
        raceID = record.raceID,
        faction = record.faction,
        money = record.money,
        guild = record.guild,
        accountLabel = accountLabel,
        accountSlot = record.accountSlot,
        isMain = record.isMain == true,
        isCurrent = key == GG:GetCharacterKey(),
        ilvl = record.itemLevel or 0,
        rating = (record.mythicplus and record.mythicplus.rating) or 0,
        keystone = BuildKeystone(record),
        vault = BuildVaultCounts(record),
        raidProgress = BuildRaidProgress(record),
        currencies = BuildAllCurrencies(record),
        bounty = BuildBountyStatus(record),
        nemesis = BuildNemesisStatus(record),
        crackedKeystone = record.crackedKeystone,
        kindojan = record.kindojan,
        excluded = false,
        lastSeen = record.ts,
        freshness = self:Freshness(record, isOwn == true, now,
          Sync ~= nil and Sync.IsInstallLive ~= nil and Sync:IsInstallLive(record.installId),
          Sync ~= nil and Sync.LastLiveAt ~= nil and Sync:LastLiveAt(record.installId) or nil),
      })
    end
  end

  local totalSegments = 0
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    totalSegments = totalSegments + (raid.numEncounters or 0)
  end
  totalSegments = math.max(totalSegments, 1)
  for _, row in ipairs(rows) do
    row.raidProgress.totalSegments = totalSegments
    row.moneyTotal = moneyTotal
    row.moneyCount = moneyCount
  end

  return rows
end

function GG.Roster:GetMostRecentTimestamp(rows)
  local newest
  for _, row in ipairs(rows) do
    if row.lastSeen and (not newest or row.lastSeen > newest) then
      newest = row.lastSeen
    end
  end
  return newest
end
