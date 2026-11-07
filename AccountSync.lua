local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.AccountSync = {}
local Sync = GG.AccountSync

local SIBLING_MAX_AGE_SECONDS = 30 * 24 * 60 * 60
local MANUAL_SYNC_COOLDOWN_SECONDS = 10
local RESPONSE_COOLDOWN_SECONDS = 10
local HELLO_BACK_COOLDOWN_SECONDS = 30
local KEEPER_DELAY_MIN_SECONDS = 3
local KEEPER_DELAY_SPREAD_SECONDS = 9
local KEEPER_DELAY_PER_KEEPER_SECONDS = 1.5
local KEEPER_COOLDOWN_SECONDS = 60
local KEEPER_MAX_RECORDS = 8
local FIRST_HELLO_MIN_SECONDS = 4
local FIRST_HELLO_SPREAD_SECONDS = 5
local REASK_DELAYS_SECONDS = { 180, 600 }
local LINK_REQUEST_TTL_SECONDS = 120
local LINK_POPUP_COOLDOWN_SECONDS = 60

local function Say(msg) print("|cff8B5CF6GG|r " .. msg) end

function Sync:IsTraceOn()
  return GGDB and GGDB.options and GGDB.options.syncTrace == true
end

local SYNC_LOG_MAX_LINES = 600

local TRACE_WINDOW_NAME = "GG Sync"

local function TraceChatFrame()
  if not GetChatWindowInfo then return nil end
  for i = 1, NUM_CHAT_WINDOWS or 10 do
    local name = GetChatWindowInfo(i)
    if type(name) == "string" and name:lower() == TRACE_WINDOW_NAME:lower() then
      return _G["ChatFrame" .. i]
    end
  end
  return nil
end

local TRACE_SCREEN_ONLY = { DIAG_SYNC_QUEUED = true, DIAG_SYNC_SKIPPED = true }

function Sync:Trace(key, ...)
  if not self:IsTraceOn() then return end
  local stamp, text = date("%H:%M:%S"), L[key]:format(...)
  local line = ("|cff8B5CF6GG sync|r |cff8a8a8a%s|r %s"):format(stamp, text)
  local frame = TraceChatFrame()
  if frame and frame.AddMessage then frame:AddMessage(line) else print(line) end
  if TRACE_SCREEN_ONLY[key] then return end
  GGDB.syncLog = type(GGDB.syncLog) == "table" and GGDB.syncLog or {}
  local log = GGDB.syncLog
  table.insert(log, stamp .. " " .. text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  while #log > SYNC_LOG_MAX_LINES do table.remove(log, 1) end
end

local liveSiblings = {}
local LIVE_FRESH_SECONDS = 120
local LIVE_UNVERIFIED_SECONDS = 30 * 60
local ROSTER_CACHE_SECONDS = 30

local function RefreshWindowSoon()
  C_Timer.After(0, function()
    if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
  end)
end

local function StampLiveAt(installId)
  local account = Sync:EnsureIdentity()
  account.liveAt = type(account.liveAt) == "table" and account.liveAt or {}
  account.liveAt[installId] = GetServerTime()
end

function Sync:NoteLive(installId, characterKey)
  local account = self:EnsureIdentity()
  if not installId or installId == account.installId or not characterKey then return end
  local wasLive = liveSiblings[installId] ~= nil
  liveSiblings[installId] = { key = characterKey, seenAt = GetTime() }
  StampLiveAt(installId)
  if not wasLive then
    self:Trace("DIAG_SYNC_LIVE", characterKey)
    if GG.OnSiblingOnline then GG:OnSiblingOnline() end
    RefreshWindowSoon()
  end
end

function Sync:NoteOffline(name)
  local key = GG.ComparableCharacterKey and GG.ComparableCharacterKey(name)
  if not key then return end
  for id, entry in pairs(liveSiblings) do
    if GG.ComparableCharacterKey(entry.key) == key then
      StampLiveAt(id)
      liveSiblings[id] = nil
      self:Trace("DIAG_SYNC_GONE", entry.key)
      RefreshWindowSoon()
    end
  end
end

local offlinePattern
function Sync:OfflineNameFromSystemMessage(message)
  if issecretvalue and issecretvalue(message) then return nil end
  if type(message) ~= "string" or type(ERR_FRIEND_OFFLINE_S) ~= "string" then return nil end
  if not offlinePattern then
    local escaped = ERR_FRIEND_OFFLINE_S:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
    offlinePattern = "^" .. escaped:gsub("%%s", "(.+)") .. "$"
  end
  local who = message:match(offlinePattern)
  if not who then return nil end
  local linked = who:match("|Hplayer:([^:|]+)")
  if linked then return linked end
  return (who:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[%[%]]", ""))
end

local rosterOnline, rosterReadAt

local function GuildOnlineMap()
  if rosterOnline and GetTime() - rosterReadAt < ROSTER_CACHE_SECONDS then return rosterOnline end
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
  rosterOnline, rosterReadAt = {}, GetTime()
  if not (GetNumGuildMembers and GetGuildRosterInfo and GG.ComparableCharacterKey) then return rosterOnline end
  for i = 1, GetNumGuildMembers() or 0 do
    local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
    local key = GG.ComparableCharacterKey(name)
    if key then rosterOnline[key] = online and true or false end
  end
  return rosterOnline
end

function Sync:HasLiveSibling()
  local now = GetTime()
  local found = false
  for id, entry in pairs(liveSiblings) do
    local age = now - entry.seenAt
    if age < LIVE_FRESH_SECONDS then
      found = true
    else
      local online = GuildOnlineMap()[GG.ComparableCharacterKey(entry.key)]
      if online == true then
        found = true
        StampLiveAt(id)
      elseif online == false or age >= LIVE_UNVERIFIED_SECONDS then
        liveSiblings[id] = nil
        self:Trace("DIAG_SYNC_GONE", entry.key)
        RefreshWindowSoon()
      else
        found = true
      end
    end
  end
  return found
end

local LIVE_CHECK_SECONDS = 20
C_Timer.NewTicker(LIVE_CHECK_SECONDS, function()
  if GGDB and next(liveSiblings) then Sync:HasLiveSibling() end
end)

local offlineFrame = CreateFrame("Frame")
offlineFrame:RegisterEvent("CHAT_MSG_SYSTEM")
offlineFrame:SetScript("OnEvent", function(_, _, message)
  if not next(liveSiblings) then return end
  local name = Sync:OfflineNameFromSystemMessage(message)
  if name then Sync:NoteOffline(name) end
end)

function Sync:IsInstallLive(installId)
  if not installId then return false end
  self:HasLiveSibling()
  return liveSiblings[installId] ~= nil
end

function Sync:LastLiveAt(installId)
  if not installId then return nil end
  if self:IsInstallLive(installId) then return GetServerTime() end
  local liveAt = self:EnsureIdentity().liveAt
  return type(liveAt) == "table" and liveAt[installId] or nil
end

function Sync:LiveSiblingNames()
  local names = {}
  self:HasLiveSibling()
  for _, entry in pairs(liveSiblings) do table.insert(names, entry.key) end
  table.sort(names)
  return names
end

function Sync:EnsureIdentity()
  GGDB.account = GGDB.account or {}
  local account = GGDB.account
  if not account.installId then
    account.installId = ("%08x%08x"):format(math.random(0, 0x7fffffff), math.random(0, 0x7fffffff))
    account.createdAt = GetServerTime()
  end
  account.siblings = account.siblings or {}
  return account
end

local function ComesBefore(aCreated, aId, bCreated, bId)
  aCreated, bCreated = aCreated or math.huge, bCreated or math.huge
  if aCreated ~= bCreated then return aCreated < bCreated end
  return tostring(aId) < tostring(bId)
end

function Sync:ComputeAutoSlot()
  local account = self:EnsureIdentity()
  local now = GetServerTime()
  local used = {}
  for id, sibling in pairs(account.siblings) do
    local fresh = sibling.seenAt and (now - sibling.seenAt) <= SIBLING_MAX_AGE_SECONDS
    if fresh and sibling.slot then
      if sibling.manual or ComesBefore(sibling.createdAt, id, account.createdAt, account.installId) then
        used[sibling.slot] = true
      end
    end
  end
  local slot = 1
  while used[slot] do slot = slot + 1 end
  return slot
end

function Sync:RecomputeAutoSlot()
  local account = self:EnsureIdentity()
  local slot = self:ComputeAutoSlot()
  if account.autoSlot == slot then return end
  account.autoSlot = slot
  if not GGDB.options.accountSlotManual then GG:ScheduleOwnRebroadcast() end
end

function Sync:NoteSibling(info)
  local account = self:EnsureIdentity()
  local id = info.installId
  if not id or id == account.installId then return end
  if not GG:IsMyAccountHash(info.accountHash) then return end

  local sibling = account.siblings[id] or {}
  local manual = info.slotManual == true
  local changed = sibling.slot ~= info.accountSlot or sibling.manual ~= manual
    or sibling.createdAt ~= info.installCreatedAt
  sibling.slot = info.accountSlot
  sibling.manual = manual
  sibling.createdAt = info.installCreatedAt
  sibling.seenAt = GetServerTime()
  account.siblings[id] = sibling
  if changed then self:RecomputeAutoSlot() end
end

local function BuildManifest()
  local manifest, sections = {}, {}
  local own = GGDB.ownCharacters or {}
  for key, record in pairs(GGDB.chars or {}) do
    if not own[key] and record.ts and GG:IsMyAccountHash(record.accountHash) then
      manifest[key] = record.ts
      sections[key] = type(record.sectionTs) == "table" and record.sectionTs or {}
    end
  end
  return manifest, sections
end

local function BuildRollsManifest()
  local rolls = {}
  if not GG.BonusRoll then return rolls end
  local own = GGDB.ownCharacters or {}
  for key, record in pairs(GGDB.chars or {}) do
    if not own[key] and GG:IsMyAccountHash(record.accountHash) then
      rolls[key] = GG.BonusRoll:LastAt(record)
    end
  end
  return rolls
end

local sessionStartedAt

function Sync:SendHello(isReply)
  local account = self:EnsureIdentity()
  local manifest, sections = BuildManifest()
  local linked = {}
  for hash in pairs(GG:GetLinkedAccountHashMap()) do table.insert(linked, hash) end
  return GG:SendSyncPayload({
    kind = "sync_hello",
    installId = account.installId,
    installCreatedAt = account.createdAt,
    accountHash = GG:GetAccountHash(),
    accountSlot = GG:GetAccountSlot(),
    slotManual = GGDB.options.accountSlotManual == true,
    manifest = manifest,
    sections = sections,
    linked = #linked > 0 and linked or nil,
    rolls = BuildRollsManifest(),
    sessionAt = sessionStartedAt,
    reply = isReply or nil,
  })
end

local helloExchanged = false

function Sync:ScheduleLoginHello()
  self:Trace("DIAG_SYNC_SESSION", GG:GetCharacterKey())
  helloExchanged = false
  sessionStartedAt = GetServerTime()
  self:RecomputeAutoSlot()
  C_Timer.After(FIRST_HELLO_MIN_SECONDS + math.random() * FIRST_HELLO_SPREAD_SECONDS, function()
    if helloExchanged then
      Sync:Trace("DIAG_SYNC_FIRST_HELLO_SKIPPED")
      return
    end
    Sync:SendHello(false)
  end)
  C_Timer.After(30, function()
    if helloExchanged then
      Sync:Trace("DIAG_SYNC_SECOND_HELLO_SKIPPED")
      return
    end
    Sync:SendHello(false)
  end)
  for _, delay in ipairs(REASK_DELAYS_SECONDS) do
    C_Timer.After(delay, function()
      if Sync:HasLiveSibling() then return end
      Sync:Trace("DIAG_SYNC_ASK_AGAIN")
      Sync:SendHello(false)
    end)
  end
end

local function GreeterHashes(payload)
  local hashes = {}
  if type(payload.accountHash) == "string" then hashes[payload.accountHash] = true end
  if type(payload.linked) == "table" then
    for _, hash in ipairs(payload.linked) do
      if type(hash) == "string" then hashes[hash] = true end
    end
  end
  return hashes
end

local keeperPending = {}
local keeperAnsweredAt = {}

local function KeeperKeys(payload, hashes)
  local account = Sync:EnsureIdentity()
  local online = GuildOnlineMap()
  local onlineInstalls = {}
  for key, record in pairs(GGDB.chars or {}) do
    if record.installId and hashes[record.accountHash] and online[GG.ComparableCharacterKey(key)] then
      onlineInstalls[record.installId] = true
    end
  end
  local keys = {}
  local own = GGDB.ownCharacters or {}
  for key, record in pairs(GGDB.chars or {}) do
    if record.installId and hashes[record.accountHash] and not own[key]
      and record.installId ~= payload.installId and record.installId ~= account.installId
      and not onlineInstalls[record.installId] then
      table.insert(keys, key)
    end
  end
  return keys
end

local function OnlineAddonUsers()
  local online = GuildOnlineMap()
  local count = 0
  for key, record in pairs(GGDB.chars or {}) do
    if record.addonVersion and online[GG.ComparableCharacterKey(key)] then count = count + 1 end
  end
  return count
end

local function KnownFor(pending, key)
  local payload = pending.payload
  local knownTs = type(payload.manifest) == "table" and payload.manifest[key] or nil
  local seenTs = pending.seenTs[key]
  if seenTs and (not knownTs or seenTs > knownTs) then knownTs = seenTs end
  if type(payload.sections) ~= "table" then return knownTs, nil end
  local known = {}
  for section, stamp in pairs(payload.sections[key] or {}) do known[section] = stamp end
  for section, stamp in pairs(pending.seenSections[key] or {}) do
    if not known[section] or stamp > known[section] then known[section] = stamp end
  end
  return knownTs, known
end

local function KeeperDeltas(pending)
  local deltas = {}
  local rolls = type(pending.payload.rolls) == "table" and pending.payload.rolls or nil
  for _, key in ipairs(KeeperKeys(pending.payload, pending.hashes)) do
    local record = GGDB.chars[key]
    local knownTs, known = KnownFor(pending, key)
    local newerRolls = rolls and GG.BonusRoll and GG.BonusRoll:LastAt(record) > math.max(rolls[key] or 0, pending.seenRolls[key] or 0)
    local delta = record.ts and GG:BuildRecordDelta(record, knownTs, known, newerRolls)
    if delta then
      table.insert(deltas, delta)
      if #deltas >= KEEPER_MAX_RECORDS then break end
    end
  end
  return deltas
end

function Sync:NoteBatchSeen(records)
  if not next(keeperPending) then return end
  for _, pending in pairs(keeperPending) do
    for _, record in ipairs(records) do
      if type(record) == "table" and record.name and record.realm then
        local key = record.name .. "-" .. record.realm
        if record.ts and (not pending.seenTs[key] or record.ts > pending.seenTs[key]) then
          pending.seenTs[key] = record.ts
        end
        if type(record.sectionTs) == "table" then
          pending.seenSections[key] = pending.seenSections[key] or {}
          local seen = pending.seenSections[key]
          for section, stamp in pairs(record.sectionTs) do
            if not seen[section] or stamp > seen[section] then seen[section] = stamp end
          end
        end
        if GG.BonusRoll and type(record.bonusRolls) == "table" then
          pending.seenRolls[key] = math.max(pending.seenRolls[key] or 0, GG.BonusRoll:LastAt(record))
        end
      end
    end
  end
end

function Sync:ConsiderKeeperAnswer(payload, sender)
  local id = payload.installId
  if InCombatLockdown and InCombatLockdown() then return end
  if keeperPending[id] then return end
  if keeperAnsweredAt[id] and GetTime() - keeperAnsweredAt[id] < KEEPER_COOLDOWN_SECONDS then return end
  local hashes = GreeterHashes(payload)
  local pending = { payload = payload, hashes = hashes, seenTs = {}, seenSections = {}, seenRolls = {} }
  local count = #KeeperDeltas(pending)
  if count == 0 then return end

  keeperPending[id] = pending
  local spread = math.max(KEEPER_DELAY_SPREAD_SECONDS, OnlineAddonUsers() * KEEPER_DELAY_PER_KEEPER_SECONDS)
  local delay = KEEPER_DELAY_MIN_SECONDS + math.random() * spread
  self:Trace("DIAG_SYNC_KEEPER_WAIT", tostring(sender), count, delay)
  C_Timer.After(delay, function()
    keeperPending[id] = nil
    if InCombatLockdown and InCombatLockdown() then return end
    keeperAnsweredAt[id] = GetTime()
    local deltas = KeeperDeltas(pending)
    if #deltas == 0 then
      Sync:Trace("DIAG_SYNC_KEEPER_COVERED", tostring(sender))
      return
    end
    GG:SendSyncPayload({ kind = "sync_batch", records = deltas })
    Sync:Trace("DIAG_SYNC_KEEPER_SENT", tostring(sender), #deltas)
  end)
end

local lastAnsweredAt = {}
local lastHelloBackAt = {}

local function OnHello(payload, sender)
  local account = Sync:EnsureIdentity()
  local id = payload.installId
  if not id or id == account.installId then return end
  Sync:ConsiderKeeperAnswer(payload, sender)
  if not GG:IsMyAccountHash(payload.accountHash) then return end
  Sync:NoteSibling(payload)
  Sync:NoteLive(id, sender)
  helloExchanged = true

  local now = GetTime()
  if not lastAnsweredAt[id] or now - lastAnsweredAt[id] >= RESPONSE_COOLDOWN_SECONDS then
    lastAnsweredAt[id] = now
    local manifest = type(payload.manifest) == "table" and payload.manifest or {}
    local rolls = type(payload.rolls) == "table" and payload.rolls or nil
    local records = {}
    local currentKey = GG:GetCharacterKey()
    local alreadyBroadcast = type(payload.sessionAt) == "number" and GG.CurrentRecordSentSince
      and GG:CurrentRecordSentSince(payload.sessionAt + 5)
    local sections = type(payload.sections) == "table" and payload.sections or nil
    local currentPayload
    for key in pairs(GGDB.ownCharacters or {}) do
      local record = GGDB.chars[key]
      local newerRolls = record and rolls and GG.BonusRoll and GG.BonusRoll:LastAt(record) > (rolls[key] or 0)
      local delta = record and record.ts
        and GG:BuildRecordDelta(record, manifest[key], sections and sections[key], newerRolls)
      if delta then
        if key == currentKey and alreadyBroadcast and not newerRolls then
          Sync:Trace("DIAG_SYNC_ALREADY_BROADCAST")
        else
          table.insert(records, delta)
          if key == currentKey then currentPayload = delta end
        end
      end
    end
    if #records > 0 and GG:SendSyncPayload({ kind = "sync_batch", records = records, owner = account.installId }) then
      if currentPayload and GG.NoteRecordSent then
        GG:NoteRecordSent(GGDB.chars[currentKey], currentPayload)
      end
    end
    Sync:Trace("DIAG_SYNC_HELLO_ANSWERED", tostring(sender), #records)
  end

  if not payload.reply and (not lastHelloBackAt[id] or now - lastHelloBackAt[id] >= HELLO_BACK_COOLDOWN_SECONDS) then
    lastHelloBackAt[id] = now
    Sync:SendHello(true)
  end
end

local lastManualSyncAt

function GG:ManualSync()
  local now = GetTime()
  if lastManualSyncAt and now - lastManualSyncAt < MANUAL_SYNC_COOLDOWN_SECONDS then
    Say(L["SYNC_COOLDOWN"]:format(math.ceil(MANUAL_SYNC_COOLDOWN_SECONDS - (now - lastManualSyncAt))))
    return false
  end
  if not IsInGuild() then
    Say(L["SYNC_NO_GUILD"])
    return false
  end
  lastManualSyncAt = now

  if GG:IsCharacterEligible() then
    GG:RequestGameData()
    GG.Vault:Update()
    GG.Lockouts:UpdateRaidInstances()
    GG.Currencies:Update()
    GG.Equipment:Update()
    GG:BroadcastRecordNow(GG:GetCharacterKey())
  end
  Sync:SendHello(false)
  Say(L["SYNC_SENT"])
  return true
end

function GG.AccountSync:CreateSyncButton(parent, anchor)
  local COLOR_NORMAL = { 0.55, 0.52, 0.63 }
  local COLOR_HOVER = { 0.76, 0.61, 0.94 }
  local BG_HOVER = { 0.165, 0.125, 0.251, 1 }
  local BORDER_HOVER = { 0.427, 0.294, 0.690, 1 }
  local TRANSPARENT = { 0, 0, 0, 0 }

  local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
  button:SetSize(22, 22)
  button:EnableMouse(true)
  button:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
  button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(14, 14)
  icon:SetPoint("CENTER")
  icon:SetTexture("Interface\\Buttons\\UI-RefreshButton")
  icon:SetDesaturated(true)

  local spin = icon:CreateAnimationGroup()
  local rotation = spin:CreateAnimation("Rotation")
  rotation:SetDegrees(-360)
  rotation:SetDuration(0.8)

  local function Paint(hover)
    icon:SetVertexColor(unpack(hover and COLOR_HOVER or COLOR_NORMAL))
    button:SetBackdropColor(unpack(hover and BG_HOVER or TRANSPARENT))
    button:SetBackdropBorderColor(unpack(hover and BORDER_HOVER or TRANSPARENT))
  end
  Paint(false)

  button:SetScript("OnEnter", function(self)
    Paint(true)
    GG.Tip:Open(self, { family = "ui", anchor = "BOTTOMRIGHT" }, function(t)
      t:Title(L["SYNC_BUTTON_TOOLTIP"])
      t:Text(L["SYNC_BUTTON_HINT"])
    end)
  end)
  button:SetScript("OnLeave", function()
    Paint(false)
    GameTooltip:Hide()
  end)
  button:SetScript("OnClick", function()
    if GG:ManualSync() then spin:Play() end
  end)
  return button
end

local pendingOutgoing = {}
local lastPopupFrom = {}

local function NormalizeKey(text)
  if type(text) ~= "string" then return nil end
  text = text:gsub("%s+", "")
  if text == "" then return nil end
  if not text:find("-", 1, true) then
    text = text .. "-" .. GetRealmName():gsub("%s+", "")
  end
  return text
end

local function SameKey(a, b)
  return type(a) == "string" and type(b) == "string" and a:lower() == b:lower()
end

local function StoreLink(hash, label)
  GGDB.options.linkedAccountHashes = GGDB.options.linkedAccountHashes or {}
  GGDB.options.linkedAccountHashes[hash] = label
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
  if GG.UI and GG.UI.RefreshSettingsIfShown then GG.UI:RefreshSettingsIfShown() end
end

function GG:UnlinkAccountHash(hash)
  if GGDB.options.linkedAccountHashes then GGDB.options.linkedAccountHashes[hash] = nil end
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
  if GG.UI and GG.UI.RefreshSettingsIfShown then GG.UI:RefreshSettingsIfShown() end
end

function GG:RequestAccountLink(targetText)
  local target = NormalizeKey(targetText)
  if not target or SameKey(target, GG:GetCharacterKey()) then
    Say(L["LINK_INVALID_TARGET"])
    return false
  end
  local account = Sync:EnsureIdentity()
  local sent = GG:SendSyncPayload({
    kind = "link_request",
    target = target,
    fromKey = GG:GetCharacterKey(),
    accountHash = GG:GetAccountHash(),
    installId = account.installId,
  })
  if not sent then
    Say(L["SYNC_NO_GUILD"])
    return false
  end
  pendingOutgoing[target:lower()] = GetTime() + LINK_REQUEST_TTL_SECONDS
  Say(L["LINK_REQUEST_SENT"]:format(target))
  return true
end

local function SendLinkAccept(request)
  GG:SendSyncPayload({
    kind = "link_accept",
    target = request.fromKey,
    fromKey = GG:GetCharacterKey(),
    accountHash = GG:GetAccountHash(),
  })
end

function Sync:AcceptLink(request)
  StoreLink(request.accountHash, request.fromKey)
  SendLinkAccept(request)
  Say(L["LINK_DONE"]:format(request.fromKey))
  self:SendHello(false)
end

local function OnLinkRequest(payload)
  if not SameKey(payload.target, GG:GetCharacterKey()) then return end
  local hash = payload.accountHash
  if type(hash) ~= "string" or type(payload.fromKey) ~= "string" then return end
  if hash == GG:GetAccountHash() then return end
  if GG:IsMyAccountHash(hash) then
    SendLinkAccept(payload)
    return
  end
  local now = GetTime()
  if lastPopupFrom[payload.fromKey] and now - lastPopupFrom[payload.fromKey] < LINK_POPUP_COOLDOWN_SECONDS then return end
  lastPopupFrom[payload.fromKey] = now
  StaticPopup_Show("GG_LINK_REQUEST", payload.fromKey, nil, payload)
end

local function OnLinkAccept(payload)
  if not SameKey(payload.target, GG:GetCharacterKey()) then return end
  if type(payload.fromKey) ~= "string" or type(payload.accountHash) ~= "string" then return end
  local key = payload.fromKey:lower()
  local expiresAt = pendingOutgoing[key]
  if not expiresAt or GetTime() > expiresAt then return end
  pendingOutgoing[key] = nil
  StoreLink(payload.accountHash, payload.fromKey)
  Say(L["LINK_DONE"]:format(payload.fromKey))
  Sync:SendHello(false)
end

function Sync:OnMessage(payload, sender)
  if payload.kind == "sync_hello" then
    OnHello(payload, sender)
  elseif payload.kind == "link_request" then
    OnLinkRequest(payload)
  elseif payload.kind == "link_accept" then
    OnLinkAccept(payload)
  end
end

local function TargetKey()
  if UnitIsPlayer and UnitIsPlayer("target") then
    local name, realm = UnitName("target")
    if name then
      return name .. "-" .. ((realm and realm ~= "") and realm or GetRealmName()):gsub("%s+", "")
    end
  end
  return ""
end

if StaticPopupDialogs then
  StaticPopupDialogs["GG_LINK_REQUEST"] = {
    text = L["LINK_REQUEST_POPUP"],
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function(_, data) if data then Sync:AcceptLink(data) end end,
    timeout = 60,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }

  StaticPopupDialogs["GG_LINK_ASK_TARGET"] = {
    text = L["LINK_ASK_TARGET_POPUP"],
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = 220,
    OnShow = function(dialog)
      local editBox = dialog:GetEditBox()
      editBox:SetText(TargetKey())
      editBox:HighlightText()
      editBox:SetFocus()
    end,
    OnAccept = function(dialog) GG:RequestAccountLink(dialog:GetEditBox():GetText()) end,
    EditBoxOnEnterPressed = function(editBox)
      GG:RequestAccountLink(editBox:GetText())
      editBox:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
end

function Sync:CreateTraceWindow()
  if TraceChatFrame() then
    Say(L["DIAG_SYNC_WINDOW_EXISTS"]:format(TRACE_WINDOW_NAME))
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    Say(L["DIAG_SYNC_WINDOW_COMBAT"])
    return
  end
  if not FCF_OpenNewWindow then
    Say(L["DIAG_SYNC_WINDOW_MANUAL"]:format(TRACE_WINDOW_NAME))
    return
  end
  local ok = pcall(FCF_OpenNewWindow, TRACE_WINDOW_NAME, true)
  local frame = ok and TraceChatFrame()
  if not frame then
    Say(L["DIAG_SYNC_WINDOW_MANUAL"]:format(TRACE_WINDOW_NAME))
    return
  end
  if ChatFrame_RemoveAllMessageGroups then pcall(ChatFrame_RemoveAllMessageGroups, frame) end
  if ChatFrame_RemoveAllChannels then pcall(ChatFrame_RemoveAllChannels, frame) end
  Say(L["DIAG_SYNC_WINDOW_CREATED"]:format(TRACE_WINDOW_NAME))
end

SLASH_GGSYNC1 = "/ggsync"
SlashCmdList["GGSYNC"] = function(arg)
  if arg and arg:lower():match("^%s*clear%s*$") then
    GGDB.syncLog = nil
    Say(L["DIAG_SYNC_LOG_CLEARED"])
    return
  end
  if arg and arg:lower():match("^%s*window%s*$") then
    Sync:CreateTraceWindow()
    return
  end
  GGDB.options.syncTrace = not Sync:IsTraceOn() or nil
  if not Sync:IsTraceOn() then
    Say(L["DIAG_SYNC_OFF"])
    return
  end
  Say(L["DIAG_SYNC_ON"])
  local names = Sync:LiveSiblingNames()
  Say(L["DIAG_SYNC_STATUS"]:format(#names > 0 and table.concat(names, ", ") or L["DIAG_NONE"]))
end
