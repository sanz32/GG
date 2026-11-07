local ADDON_NAME, GG = ...

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")
LibStub("AceComm-3.0"):Embed(GG)

local COMM_PREFIX = "GGv1"

local CARD_COMM_PREFIX = "GGv1c"

local LOCKOUT_COMM_PREFIX = "GGv1L"

local SYNC_COMM_PREFIX = "GGv1s"

local ROSTER_COMM_PREFIX = "GGv1r"

local BROADCAST_MIN_INTERVAL_SECONDS = 15
local BROADCAST_DEBOUNCE_SECONDS = 1

local FAST_LANE_MIN_INTERVAL_SECONDS = 3

local lastBroadcastAt = {}
local broadcastPending = false
local firstDirtyAt

local SECTION_FIELDS = {
  vault = { "vault", "vaultHistory" },
  mythicplus = { "mythicplus", "itemLevel" },
  raids = { "raids" },
  currencies = { "currencies", "bounty", "items", "nemesis", "crackedKeystone" },
  kindojan = { "kindojan" },
  money = { "money" },
  bonusRolls = { "bonusRolls" },
  equipment = { "equipment" },
}

local IDENTITY_FIELDS = {
  "name", "realm", "class", "level", "guid", "guild", "seasonId", "ts",
  "isMain", "accountHash", "accountSlot", "addonVersion",
  "role",
  "specID", "raceID", "faction",
  "installId", "installCreatedAt", "slotManual",
}

local dirtySections = {}

local SECTION_OF_FIELD = {}
for section, fields in pairs(SECTION_FIELDS) do
  for _, field in ipairs(fields) do SECTION_OF_FIELD[field] = section end
end

local function SectionHasData(record, section)
  for _, field in ipairs(SECTION_FIELDS[section]) do
    if record[field] ~= nil then return true end
  end
  return false
end

local function SectionStamp(record, section)
  return type(record.sectionTs) == "table" and record.sectionTs[section] or nil
end

local function CopyIdentity(record, payload)
  for _, field in ipairs(IDENTITY_FIELDS) do
    payload[field] = record[field]
  end
end

local function CopySection(record, payload, section)
  for _, field in ipairs(SECTION_FIELDS[section]) do
    payload[field] = record[field]
  end
  local stamp = SectionStamp(record, section)
  if stamp then
    payload.sectionTs = payload.sectionTs or {}
    payload.sectionTs[section] = stamp
  end
end

local function BuildPartialPayload(record, dirty)
  local payload = {}
  CopyIdentity(record, payload)
  for section in pairs(dirty) do
    if SECTION_FIELDS[section] then CopySection(record, payload, section) end
  end
  return payload
end

function GG:BuildRecordDelta(record, knownTs, knownSections, newerRolls)
  if not knownTs then return record end
  if type(knownSections) ~= "table" then
    if (record.ts and record.ts > knownTs) or newerRolls then return record end
    return nil
  end
  local payload, anySection = {}, false
  for section in pairs(SECTION_FIELDS) do
    local include
    if section == "bonusRolls" then
      include = newerRolls
    else
      local mine = SectionStamp(record, section)
      if mine then
        include = mine > (knownSections[section] or 0)
      else
        include = record.ts and record.ts > knownTs
      end
    end
    if include and SectionHasData(record, section) then
      CopySection(record, payload, section)
      anySection = true
    end
  end
  if not anySection and not (record.ts and record.ts > knownTs) then return nil end
  CopyIdentity(record, payload)
  return payload
end

local function StampOwnRecord(record)
  local ts = math.max(GetServerTime(), record.ts or 0, (record.sentTs or 0) + 1)
  record.ts = ts
  record.sentTs = ts
end

local function SendRecord(key, record, fast)
  local serialized = LibSerialize:Serialize(record)
  local compressed = LibDeflate:CompressDeflate(serialized)
  local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)

  if fast then
    GG:SendCommMessage(SYNC_COMM_PREFIX, encoded, "GUILD", nil, "NORMAL")
  else
    GG:SendCommMessage(COMM_PREFIX, encoded, "GUILD", nil, "BULK")
  end
  lastBroadcastAt[key] = GetTime()
  return type(encoded) == "string" and #encoded or 0
end

local function SectionsIn(payload)
  local names = {}
  for section, fields in pairs(SECTION_FIELDS) do
    for _, field in ipairs(fields) do
      if payload[field] ~= nil then
        table.insert(names, section)
        break
      end
    end
  end
  table.sort(names)
  return #names > 0 and table.concat(names, ", ") or "-"
end

local function Trace(key, ...)
  if GG.AccountSync and GG.AccountSync.Trace then GG.AccountSync:Trace(key, ...) end
end

local function ComparableKey(text)
  if type(text) ~= "string" then return nil end
  local name, realm = text:match("^([^%-]+)%-(.+)$")
  if not name then name, realm = text, GetRealmName() end
  return (name .. "-" .. realm:gsub("[%s%-']", "")):lower()
end
GG.ComparableCharacterKey = ComparableKey

local lastSentSections = {}
local lastSentAt = {}
local identityDirty = false

local function DeepCopy(value)
  if type(value) ~= "table" then return value end
  local copy = {}
  for k, v in pairs(value) do copy[k] = DeepCopy(v) end
  return copy
end

local function DeepEqual(a, b)
  if type(a) ~= "table" or type(b) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not DeepEqual(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function SectionSnapshot(record, section)
  local snapshot = {}
  for _, field in ipairs(SECTION_FIELDS[section]) do snapshot[field] = record[field] end
  return snapshot
end

local function DropUnchangedSections(record)
  local snapshots = {}
  for section in pairs(dirtySections) do
    if SECTION_FIELDS[section] then
      local snapshot = SectionSnapshot(record, section)
      if lastSentSections[section] and DeepEqual(snapshot, lastSentSections[section]) then
        dirtySections[section] = nil
      else
        snapshots[section] = DeepCopy(snapshot)
      end
    end
  end
  return snapshots
end

local ScheduleBroadcast

local function PerformBroadcast()
  broadcastPending = false

  local key = GG:GetCharacterKey()
  local fast = GG.AccountSync and GG.AccountSync.HasLiveSibling and GG.AccountSync:HasLiveSibling() or false
  local interval = fast and FAST_LANE_MIN_INTERVAL_SECONDS or BROADCAST_MIN_INTERVAL_SECONDS
  local now = GetTime()
  local last = lastBroadcastAt[key]
  if last and (now - last) < interval then
    local wait = interval - (now - last)
    Trace("DIAG_SYNC_WAIT", math.ceil(wait))
    ScheduleBroadcast(wait + 0.1)
    return
  end

  local record = GGDB.chars[key]
  if not record then return end

  local snapshots = DropUnchangedSections(record)
  if next(dirtySections) == nil and not identityDirty then
    Trace("DIAG_SYNC_SKIPPED")
    firstDirtyAt = nil
    return
  end

  StampOwnRecord(record)
  record.sectionTs = type(record.sectionTs) == "table" and record.sectionTs or {}
  for section in pairs(dirtySections) do
    if SECTION_FIELDS[section] then record.sectionTs[section] = record.ts end
  end
  local payload = BuildPartialPayload(record, dirtySections)
  if GG.AccountSync and GG.AccountSync.IsTraceOn and GG.AccountSync:IsTraceOn() then
    payload.queuedAt = firstDirtyAt
  end
  for section, snapshot in pairs(snapshots) do
    lastSentSections[section] = snapshot
    lastSentAt[section] = GetServerTime()
  end
  dirtySections = {}
  identityDirty = false
  firstDirtyAt = nil
  local size = SendRecord(key, payload, fast)
  Trace(fast and "DIAG_SYNC_SENT_FAST" or "DIAG_SYNC_SENT_SLOW", SectionsIn(payload), size)
end

function GG:RequestBroadcast(section)
  if section and not dirtySections[section] then
    dirtySections[section] = true
    Trace("DIAG_SYNC_QUEUED", section)
  elseif not section then
    identityDirty = true
  end
  firstDirtyAt = firstDirtyAt or GetServerTime()
  if broadcastPending then return end
  ScheduleBroadcast(BROADCAST_DEBOUNCE_SECONDS)
end

local scheduleToken = 0
ScheduleBroadcast = function(delay)
  scheduleToken = scheduleToken + 1
  local token = scheduleToken
  broadcastPending = true
  C_Timer.After(delay, function()
    if token == scheduleToken then PerformBroadcast() end
  end)
end

function GG:NoteRecordSent(record, payload)
  for section in pairs(SECTION_FIELDS) do
    if SectionHasData(payload, section) then
      lastSentSections[section] = DeepCopy(SectionSnapshot(record, section))
      lastSentAt[section] = GetServerTime()
    end
  end
  Trace("DIAG_SYNC_COVERED")
end

function GG:CurrentRecordSentSince(since)
  local record = GGDB.chars[GG:GetCharacterKey()]
  if not record then return false end
  for section, fields in pairs(SECTION_FIELDS) do
    if section ~= "bonusRolls" then
      local hasData = false
      for _, field in ipairs(fields) do
        if record[field] ~= nil then hasData = true break end
      end
      if hasData and not (lastSentAt[section] and lastSentAt[section] > since) then return false end
    end
  end
  return true
end

function GG:OnSiblingOnline()
  if broadcastPending then ScheduleBroadcast(0.1) end
end

function GG:BroadcastRecordNow(key)
  local record = GGDB.chars[key]
  if not record then return end
  StampOwnRecord(record)
  SendRecord(key, record)
end

local REQUEST_TIMEOUT_AFTER_SECONDS = 10

local pendingCardRequests = {}

local function SendPayload(prefix, payload, distribution, target, priority)
  local serialized = LibSerialize:Serialize(payload)
  local compressed = LibDeflate:CompressDeflate(serialized)
  local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
  GG:SendCommMessage(prefix, encoded, distribution, target, priority)
end

function GG:SendRosterPayload(payload, priority)
  if not IsInGuild() then return false end
  SendPayload(ROSTER_COMM_PREFIX, payload, "GUILD", nil, priority or "NORMAL")
  return true
end

function GG:SendSyncPayload(payload)
  if not IsInGuild() then return false end
  SendPayload(SYNC_COMM_PREFIX, payload, "GUILD", nil, "NORMAL")
  return true
end

local CARD_RESPONSE_FIELDS = {
  "name", "realm", "class", "level", "itemLevel",
  "equipment", "vault", "raids", "currencies", "bounty", "nemesis", "crackedKeystone", "money",
}

local function TrimRecordForCard(record)
  local trimmed = {}
  for _, field in ipairs(CARD_RESPONSE_FIELDS) do
    trimmed[field] = record[field]
  end
  return trimmed
end

function GG:RequestCharacterCard(characterKey, senderKey, channelHint, onResult)
  local requestId = time() .. "-" .. math.random(100000, 999999)
  pendingCardRequests[requestId] = { onResult = onResult }

  SendPayload(CARD_COMM_PREFIX, { kind = "char_request", characterKey = characterKey, requestId = requestId, channelHint = channelHint }, "WHISPER", senderKey, "ALERT")

  C_Timer.After(REQUEST_TIMEOUT_AFTER_SECONDS, function()
    local pending = pendingCardRequests[requestId]
    if not pending then return end
    pendingCardRequests[requestId] = nil
    pending.onResult(nil)
  end)
end

local refreshPending = false
local function RequestRosterRefresh()
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(1, function()
    refreshPending = false
    if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
  end)
end

local LOCKOUT_RESPONSE_SPREAD = 4
local LOCKOUT_RESPONSE_MIN_GAP = 3
local lockoutResponsePending = false
local lockoutStateSentAt = 0

local function GroupDistribution()
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
  return nil
end

function GG:SendLockoutRequest()
  local distribution = GroupDistribution()
  if not distribution then return end
  if GG.GroupLockouts then
    GG.GroupLockouts:Trace(GG.GroupLockouts:Text("DIAG_NET_SEND_REQUEST"):format(distribution))
  end
  SendPayload(LOCKOUT_COMM_PREFIX, { kind = "lock_request" }, distribution, nil, "ALERT")
end

local lockoutStateDeferred = false

function GG:SendLockoutState()
  local distribution = GroupDistribution()
  if not distribution then return end
  if GG.Lockouts.HasServerData and not GG.Lockouts:HasServerData() then
    lockoutStateDeferred = true
    return
  end
  lockoutStateSentAt = GetTime()
  if GG.GroupLockouts then
    GG.GroupLockouts:Trace(GG.GroupLockouts:Text("DIAG_NET_SEND_STATE"):format(distribution, GG:GetCharacterKey()))
  end
  SendPayload(LOCKOUT_COMM_PREFIX, {
    kind = "lock_response",
    characterKey = GG:GetCharacterKey(),
    state = GG.Lockouts:BuildSharedState(),
    addonVersion = GG.VERSION,
  }, distribution, nil, "ALERT")
end

function GG:FlushDeferredLockoutState()
  if not lockoutStateDeferred then return end
  lockoutStateDeferred = false
  if IsInGroup() then GG:SendLockoutState() end
end

local MergeIncomingRecord

function GG:CleanNegativeZeros(tbl, seen)
  seen = seen or {}
  if seen[tbl] then return end
  seen[tbl] = true
  for key, value in pairs(tbl) do
    if value == 0 then
      tbl[key] = 0
    elseif type(value) == "table" then
      self:CleanNegativeZeros(value, seen)
    end
  end
end

function GG:OnCommReceived(prefix, message, distribution, sender)
  if prefix ~= COMM_PREFIX and prefix ~= CARD_COMM_PREFIX and prefix ~= LOCKOUT_COMM_PREFIX
    and prefix ~= SYNC_COMM_PREFIX and prefix ~= ROSTER_COMM_PREFIX then return end

  local decoded = LibDeflate:DecodeForWoWAddonChannel(message)
  if not decoded then return end
  local decompressed = LibDeflate:DecompressDeflate(decoded)
  if not decompressed then return end
  local ok, payload = LibSerialize:Deserialize(decompressed)
  if not ok or type(payload) ~= "table" then return end
  self:CleanNegativeZeros(payload)

  if prefix == ROSTER_COMM_PREFIX then
    if GG.RaidRosters then GG.RaidRosters:OnMessage(payload, distribution, sender) end
    return
  end

  if payload.kind == "lock_request" then
    if lockoutResponsePending then
      if GG.GroupLockouts then
        GG.GroupLockouts:Trace(GG.GroupLockouts:Text("DIAG_NET_ALREADY_ANSWERING"):format(tostring(sender)))
      end
      return
    end
    lockoutResponsePending = true

    local delay = math.random() * LOCKOUT_RESPONSE_SPREAD
    local sinceLast = GetTime() - lockoutStateSentAt
    if sinceLast < LOCKOUT_RESPONSE_MIN_GAP then
      delay = math.max(delay, LOCKOUT_RESPONSE_MIN_GAP - sinceLast)
    end

    if GG.GroupLockouts then
      GG.GroupLockouts:Trace(GG.GroupLockouts:Text("DIAG_NET_ANSWER_IN"):format(tostring(sender), delay))
    end

    C_Timer.After(delay, function()
      lockoutResponsePending = false
      if IsInGroup() then GG:SendLockoutState() end
    end)
    return
  end

  if payload.kind == "lock_response" then
    if GG.GroupLockouts then
      GG.GroupLockouts:StoreResponse(payload.characterKey, payload.state, payload.addonVersion)
      if GG.RosterUI and GG.RosterUI.RefreshGroupLockouts then
        GG.RosterUI:RefreshGroupLockouts()
      end
    end
    return
  end

  if payload.kind == "char_request" then
    local myRecord = GGDB.chars[payload.characterKey]
    if not myRecord then return end
    local isOwn = GGDB.ownCharacters and GGDB.ownCharacters[payload.characterKey]
    local sameBattletag = false
    if not isOwn and myRecord.accountHash then
      local myAccountHash = GG:GetAccountHash()
      sameBattletag = myAccountHash ~= nil and myRecord.accountHash == myAccountHash
    end
    local linkedTag = nil
    if not isOwn and not sameBattletag and myRecord.accountHash then
      linkedTag = GG:GetLinkedAccountHashMap()[myRecord.accountHash]
    end
    if not (isOwn or sameBattletag or linkedTag) then return end
    local responsePayload = { kind = "char_response", requestId = payload.requestId, record = TrimRecordForCard(myRecord) }
    if not isOwn and GG.Roster and GG.Roster.Freshness then
      local Sync = GG.AccountSync
      local f = GG.Roster:Freshness(myRecord, false, GetServerTime(),
        Sync ~= nil and Sync:IsInstallLive(myRecord.installId),
        Sync ~= nil and Sync:LastLiveAt(myRecord.installId) or nil)
      if f and f.age then responsePayload.record.dataAge = f.age end
    end

    if payload.channelHint == "GUILD" then
      if IsInGuild() then
        SendPayload(CARD_COMM_PREFIX, responsePayload, "GUILD", nil, "ALERT")
      end
    elseif payload.channelHint == "GROUP" then
      if IsInRaid() then
        SendPayload(CARD_COMM_PREFIX, responsePayload, "RAID", nil, "ALERT")
      elseif IsInGroup() then
        SendPayload(CARD_COMM_PREFIX, responsePayload, "PARTY", nil, "ALERT")
      end
    else
      SendPayload(CARD_COMM_PREFIX, responsePayload, "WHISPER", sender, "ALERT")
    end
    return
  end

  if payload.kind == "sync_hello" or payload.kind == "link_request" or payload.kind == "link_accept" then
    if GG.AccountSync then GG.AccountSync:OnMessage(payload, sender) end
    return
  end

  if payload.kind == "char_response" then
    local pending = pendingCardRequests[payload.requestId]
    if not pending then return end
    pendingCardRequests[payload.requestId] = nil
    pending.onResult(payload.record)
    return
  end

  if payload.kind == "sync_batch" then
    if type(payload.records) == "table" then
      if GG.AccountSync and GG.AccountSync.NoteBatchSeen then GG.AccountSync:NoteBatchSeen(payload.records) end
      local mine = 0
      for _, record in ipairs(payload.records) do
        if type(record) == "table" and GG:IsMyAccountHash(record.accountHash) then mine = mine + 1 end
      end
      if mine > 0 and ComparableKey(sender) ~= ComparableKey(GG:GetCharacterKey()) then
        Trace("DIAG_SYNC_BATCH_IN", mine)
      end
      for _, record in ipairs(payload.records) do
        if type(record) == "table" then MergeIncomingRecord(record, sender, "batch", payload.owner) end
      end
    end
    return
  end

  MergeIncomingRecord(payload, sender, prefix == SYNC_COMM_PREFIX and "fast" or "slow")
end

MergeIncomingRecord = function(record, sender, via, batchOwner)
  if not record.name or not record.realm then return end

  local fromSibling = via and GG:IsMyAccountHash(record.accountHash)
    and not (GGDB.ownCharacters and GGDB.ownCharacters[record.name .. "-" .. record.realm])
  if fromSibling and GG.AccountSync and GG.AccountSync.NoteLive and record.installId
    and ComparableKey(sender) == ComparableKey(record.name .. "-" .. record.realm) then
    GG.AccountSync:NoteLive(record.installId, record.name .. "-" .. record.realm)
  end

  GG:NoteObservedVersion(record.addonVersion)

  local key = record.name .. "-" .. record.realm
  local existing = GGDB.chars[key]

  if GG.AccountSync then GG.AccountSync:NoteSibling(record) end

  local rollsUpdated = false
  if existing and type(record.bonusRolls) == "table" and GG.BonusRoll
    and GG.BonusRoll:LastAt(record) > GG.BonusRoll:LastAt(existing) then
    existing.bonusRolls = record.bonusRolls
    rollsUpdated = true
  end

  local queuedAt = record.queuedAt
  record.queuedAt = nil
  local source = via
  if fromSibling and via ~= "batch" and ComparableKey(sender) ~= ComparableKey(key) then source = "relay" end
  if fromSibling and via == "batch" then
    local senderRecord = type(sender) == "string"
      and GGDB.chars[(sender:find("-", 1, true) and sender or (sender .. "-" .. GetRealmName())):gsub("%s+", "")]
    if not (senderRecord and GG:IsMyAccountHash(senderRecord.accountHash)) then source = "keeper" end
  end

  local identityNewer = not existing or not existing.ts or (record.ts and record.ts > existing.ts)
  local accepted = {}
  if existing then
    local incoming = type(record.sectionTs) == "table" and record.sectionTs or nil
    local fromOwner = (batchOwner ~= nil and (record.installId == nil or record.installId == batchOwner))
      or (via ~= "batch" and ComparableKey(sender) == ComparableKey(key))
    for section, fields in pairs(SECTION_FIELDS) do
      if section ~= "bonusRolls" and SectionHasData(record, section) then
        local stamp = incoming and incoming[section]
        local have = SectionStamp(existing, section)
        local take
        if stamp and not SectionHasData(existing, section) then
          take = true
        elseif stamp and fromOwner and not have then
          take = true
        elseif stamp then
          take = stamp > (have or existing.ts or 0)
        elseif have then
          take = false
        else
          take = identityNewer
        end
        if take then
          for _, field in ipairs(fields) do
            if record[field] ~= nil then existing[field] = record[field] end
          end
          if stamp then
            existing.sectionTs = type(existing.sectionTs) == "table" and existing.sectionTs or {}
            existing.sectionTs[section] = stamp
          elseif type(existing.sectionTs) == "table" then
            existing.sectionTs[section] = nil
          end
          table.insert(accepted, section)
        end
      end
    end
    if identityNewer then
      for field, value in pairs(record) do
        if not SECTION_OF_FIELD[field] and field ~= "sectionTs" then existing[field] = value end
      end
    end
  else
    GGDB.chars[key] = record
  end

  if identityNewer or #accepted > 0 then
    if fromSibling then
      local since = GetServerTime() - (queuedAt or record.ts or GetServerTime())
      table.sort(accepted)
      local what = existing and (#accepted > 0 and table.concat(accepted, ", ") or "-") or SectionsIn(record)
      Trace("DIAG_SYNC_GOT_" .. source:upper(), key, what, since)
    end
    RequestRosterRefresh()
  elseif rollsUpdated then
    RequestRosterRefresh()
  elseif fromSibling and source ~= "relay" then
    Trace("DIAG_SYNC_GOT_OLD", key)
  end
end

local RELAY_INTERVAL_SECONDS = 15
local RELAY_MAX_AGE_SECONDS = 14 * 24 * 60 * 60
local RELAY_MIN_INTERVAL_PER_CHARACTER = 60 * 60

local lastRelayedAt = {}

local function PerformRelay()
  if InCombatLockdown() then return end
  if not GGDB or not GGDB.chars or not GG:IsCharacterEligible() then return end

  local myKey = GG:GetCharacterKey()
  local now = time()
  local serverNow = GetServerTime()
  local candidateKey, candidateRecord, oldestRelayedAt

  for key, record in pairs(GGDB.chars) do
    if key ~= myKey and record.ts and (serverNow - record.ts) <= RELAY_MAX_AGE_SECONDS then
      local relayedAt = lastRelayedAt[key] or 0
      if now - relayedAt >= RELAY_MIN_INTERVAL_PER_CHARACTER then
        if not oldestRelayedAt or relayedAt < oldestRelayedAt then
          candidateKey, candidateRecord, oldestRelayedAt = key, record, relayedAt
        end
      end
    end
  end

  if candidateKey and candidateRecord then
    SendRecord(candidateKey, candidateRecord)
    lastRelayedAt[candidateKey] = now
  end
end

C_Timer.NewTicker(RELAY_INTERVAL_SECONDS, PerformRelay)

GG:RegisterComm(COMM_PREFIX)
GG:RegisterComm(CARD_COMM_PREFIX)
GG:RegisterComm(LOCKOUT_COMM_PREFIX)
GG:RegisterComm(SYNC_COMM_PREFIX)
GG:RegisterComm(ROSTER_COMM_PREFIX)
