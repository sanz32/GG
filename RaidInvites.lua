local ADDON_NAME, GG = ...

GG.RaidInvites = {}
local RI = GG.RaidInvites

RI.REPLY_TIMEOUT = 5
RI.EXCLUDE_SECONDS = 120
RI.WAIT_RETRY_SECONDS = 30
RI.INVITED_RESET_SECONDS = 60
RI.WHISPER_WATCH_SECONDS = 6

RI.REINVITE_SECONDS = 5
RI.PENDING_SECONDS = 60
RI.ENTRY_TTL = 90
RI.REPLY_BATCH_SECONDS = 0.4
RI.FULL_WINDOW_SECONDS = 3
RI.CONVERT_RETRY_SECONDS = 5

RI.PARTY_SIZE = 5
RI.RAID_SIZE = 40
RI.LOG_MAX = 200
RI.ANSWERS = { ok = true, wait = true, full = true, gone = true }
local MAX_NAME = 64

local function NameKey(name) return GG.RaidRosters.NameKey(name) end
local function Clock() return GetTime() end
local function MyKey() return NameKey(GG:GetCharacterKey()) end

local function Secret(v)
  return issecretvalue ~= nil and issecretvalue(v) == true
end

local function Flag(v)
  if Secret(v) then return false end
  return v == true
end

local function Home() return LE_PARTY_CATEGORY_HOME end

function RI:Log(fmt, ...)
  if type(GGDB) ~= "table" then return end
  GGDB.inviteLog = type(GGDB.inviteLog) == "table" and GGDB.inviteLog or {}
  local log = GGDB.inviteLog
  local n, args = select("#", ...), { ... }
  for i = 1, n do args[i] = tostring(args[i]) end
  local ok, text = pcall(string.format, fmt, (table.unpack or unpack)(args, 1, n))
  log[#log + 1] = date("%m-%d %H:%M:%S") .. " " .. (ok and text or fmt)
  while #log > RI.LOG_MAX do table.remove(log, 1) end
end

function RI.PickInviter(names, atByKey, excluded, now)
  for _, name in ipairs(names or {}) do
    local k = NameKey(name)
    local x = k and excluded and excluded[k]
    if k and (not x or now - x.t >= RI.EXCLUDE_SECONDS or ((atByKey and atByKey[k]) or -math.huge) > x.at) then
      return name
    end
  end
  return nil
end

function RI.ChoosePath(inviter, lockdown)
  if inviter and not lockdown then return "gg" end
  return "whisper"
end

function RI.Decide(f)
  if f.recent then return "again" end
  if f.raid then return f.members >= RI.RAID_SIZE and "full" or "invite" end
  if RI.PARTY_SIZE - f.members - f.pending > 0 then return "invite" end
  return "wait"
end

function RI.GoneReason(own, requestLeaderKey, capable, why)
  if not own then return "sin grupo propio" end
  if own.leaderKey ~= requestLeaderKey then return "otro líder" end
  if not capable then return why or "sin permiso para invitar" end
  return nil
end

function RI.TestRefusal(f)
  if not f.sibling then return "prueba de alguien que no es mi otra cuenta" end
  if f.enabled == false then return "opción apagada" end
  if not f.grouped then return nil end
  if f.leader or (f.raid and (f.assistant or f.everyoneAssistant)) then return nil end
  return "sin permiso para invitar"
end

function RI.CallView(path, phase, sinceSent, sincePhase, retryAfter)
  if phase == "invited" then
    local who = path == "gg" and "inviter" or "leader"
    if sincePhase >= RI.INVITED_RESET_SECONDS then return "alert" end
    if sincePhase >= retryAfter then return "retry", "RC_INVITED", who end
    return "sent", "RC_INVITED", who
  end
  if path ~= "gg" then
    if sinceSent >= retryAfter then return "retry", "RC_NO_INVITE", "leader" end
    return "sent", "RC_SENT", "leader"
  end
  if phase == "noanswer" then return "retry", "RC_NO_ANSWER", "inviter" end
  if phase == "gone" then return "retry", "RC_GONE", "inviter" end
  if phase == "full" then return "retry", "RC_FULL", "inviter" end
  if phase == "wait" then
    if sincePhase >= RI.WAIT_RETRY_SECONDS then return "retry", "RC_NO_INVITE", "inviter" end
    return "sent", "RC_QUEUED", "inviter"
  end
  if sinceSent >= retryAfter then return "retry", "RC_NO_INVITE", "inviter" end
  if phase == "ok" then return "sent", "RC_INVITING", "inviter" end
  return "sent", "RC_SENT_GG", "inviter"
end

local req
local excluded = {}
local whisperWatch
local whisperFrame

local function Exclude(r)
  if not r.inviterKey then return end
  excluded[r.leaderKey] = excluded[r.leaderKey] or {}
  excluded[r.leaderKey][r.inviterKey] = { t = Clock(), at = r.inviterAt or -math.huge }
end

local function SetPhase(r, phase)
  r.phase, r.phaseAt = phase, Clock()
end

local function NoAnswer(r, why)
  if r.phase ~= "sent" then return end
  SetPhase(r, "noanswer")
  Exclude(r)
  RI:Log("sin respuesta de %s (%s)", r.inviter, why)
end

function RI:State()
  if req and req.path == "gg" and req.phase == "sent" and Clock() - req.sentAt >= RI.REPLY_TIMEOUT then
    NoAnswer(req, "venció la espera")
  end
  return req
end

function RI:InviterFor(group)
  if not group or not group.leaderKey then return nil end
  local names, atByKey = GG.RaidGroups:InvitersFor(group)
  return RI.PickInviter(names, atByKey, excluded[group.leaderKey], Clock()), atByKey
end

function RI:PlanFor(group)
  local inviter = self:InviterFor(group)
  local lockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
  local path = RI.ChoosePath(inviter, Flag(lockdown))
  return path, path == "gg" and inviter or nil
end

function RI:SendRequest(group, inviter)
  local _, atByKey = self:InviterFor(group)
  local r = {
    path = "gg", inviter = inviter, inviterKey = NameKey(inviter), inviterAt = atByKey and atByKey[NameKey(inviter)],
    leader = group.leader, leaderKey = group.leaderKey, sentAt = Clock(),
    grouped = IsInGroup(Home()) == true,
  }
  SetPhase(r, "sent")
  req = r
  self:Log("pedido por GG a %s (líder %s)", inviter, group.leader)
  local queued = GG:SendInvitePayload({ kind = "inv_req", to = inviter, leader = group.leader,
    test = group.simulated and true or nil }, function(ok)
    if req ~= r then return end
    if ok then
      RI:Log("el juego aceptó el pedido")
    else
      RI:Log("el juego rechazó el pedido")
      NoAnswer(r, "envío fallido")
    end
  end)
  if not queued then NoAnswer(r, "sin hermandad") end
  C_Timer.After(RI.REPLY_TIMEOUT, function()
    if req == r then RI:State() end
  end)
end

local function StopWhisperWatch()
  local w = whisperWatch
  if not w then return end
  whisperWatch = nil
  if whisperFrame then
    whisperFrame:UnregisterEvent("CHAT_MSG_WHISPER_INFORM")
    whisperFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
  end
  if w.notFound then
    RI:Log("susurro a %s: jugador no encontrado", w.target)
  elseif w.confirmed then
    RI:Log("susurro a %s confirmado", w.target)
  else
    RI:Log("susurro a %s sin confirmación", w.target)
  end
end

local function NotFoundTexts(target)
  local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S
  if type(fmt) ~= "string" or type(target) ~= "string" then return {} end
  local out = {}
  local ok, full = pcall(string.format, fmt, target)
  if ok then out[full] = true end
  local short = target:match("^[^%-]+")
  if short and short ~= target then
    local ok2, s = pcall(string.format, fmt, short)
    if ok2 then out[s] = true end
  end
  return out
end

function RI:WatchWhisper(group)
  StopWhisperWatch()
  local r = { path = "whisper", leader = group.leader, leaderKey = group.leaderKey, sentAt = Clock(),
    grouped = IsInGroup(Home()) == true }
  SetPhase(r, "sent")
  req = r
  self:Log("pedido por susurro a %s", group.leader)
  local w = { target = group.leader, notFoundTexts = NotFoundTexts(group.leader) }
  whisperWatch = w
  if CreateFrame and not whisperFrame then
    whisperFrame = CreateFrame("Frame")
    whisperFrame:SetScript("OnEvent", function(_, event, ...) RI:OnEvent(event, ...) end)
  end
  if whisperFrame then
    whisperFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
    whisperFrame:RegisterEvent("CHAT_MSG_SYSTEM")
  end
  C_Timer.After(RI.WHISPER_WATCH_SECONDS, function()
    if whisperWatch == w then StopWhisperWatch() end
  end)
end

local function OnWhisperEvent(event, text)
  local w = whisperWatch
  if not w or Secret(text) or type(text) ~= "string" then return end
  if event == "CHAT_MSG_WHISPER_INFORM" then
    if text == GG.RaidGroups.INVITE_WORD then w.confirmed = true end
  elseif event == "CHAT_MSG_SYSTEM" then
    if w.notFoundTexts[text] then
      w.notFound = true
      StopWhisperWatch()
    end
  end
end

local function OnReply(answers, sender, senderKey)
  local r = req
  if not r or r.path ~= "gg" or r.inviterKey ~= senderKey then return end
  local answer = answers[MyKey()]
  if not RI.ANSWERS[answer] then return end
  if r.phase == "invited" and answer == "ok" then return end
  RI:Log("respuesta de %s: %s", sender, answer)
  SetPhase(r, answer)
  if answer == "gone" then
    Exclude(r)
  elseif excluded[r.leaderKey] then
    excluded[r.leaderKey][senderKey] = nil
  end
end

RI.AUTO_ACCEPT_SECONDS = 120

function RI.AcceptRefusal(f)
  if f.enabled == false then return "opción apagada" end
  if not f.requested then return "sin pedido" end
  if (f.sinceSent or math.huge) > RI.AUTO_ACCEPT_SECONDS then return "pedido vencido" end
  if not f.inviterKey then return "nombre ilegible" end
  if f.grouped then return "ya en un grupo" end
  if f.queued then return "en cola" end
  local k = f.inviterKey
  if k == f.leaderKey or k == f.askedKey or (f.groupKeys and f.groupKeys[k]) then return nil end
  return "no es del grupo"
end

local function InviterKey(name)
  if Secret(name) or type(name) ~= "string" or name == "" then return nil end
  if not name:find("-", 1, true) then
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if Secret(realm) or type(realm) ~= "string" or realm == "" then return nil end
    name = name .. "-" .. realm
  end
  return NameKey(name)
end

local function GroupKeys(leaderKey)
  local RG = GG.RaidGroups
  if not RG or not leaderKey then return nil end
  for _, g in ipairs(RG:Groups()) do
    if g.leaderKey == leaderKey then return g.keys end
  end
  return nil
end

local function InQueue()
  local b = QueueStatusButton
  return type(b) == "table" and b.IsShown ~= nil and b:IsShown() == true
end

local hidePopup = false
local popupFrame

local function TryAutoAccept(r, inviter)
  local options = GGDB and GGDB.options
  local reason = RI.AcceptRefusal({
    enabled = not (options and options.rosterAutoAccept == false),
    requested = r ~= nil,
    sinceSent = r and Clock() - r.sentAt,
    inviterKey = InviterKey(inviter),
    leaderKey = r and r.leaderKey,
    askedKey = r and r.inviterKey,
    groupKeys = r and GroupKeys(r.leaderKey),
    grouped = IsInGroup(Home()) == true,
    queued = InQueue(),
  })
  if reason then
    if r then RI:Log("no la acepto sola: %s", reason) end
    return false
  end
  if not AcceptGroup then return false end
  AcceptGroup()
  RI:Log("aceptada sola")
  local L = LibStub and LibStub("AceLocale-3.0"):GetLocale("GG", true)
  print("|cff8B5CF6GG|r " .. ((L and L["RI_AUTO_ACCEPTED"]) or "Invite from %s accepted."):format(inviter))
  if CreateFrame and StaticPopup_Hide then
    hidePopup = true
    if not popupFrame then
      popupFrame = CreateFrame("Frame")
      popupFrame:SetScript("OnEvent", function(self)
        self:UnregisterEvent("GROUP_ROSTER_UPDATE")
        if not hidePopup then return end
        hidePopup = false
        StaticPopup_Hide("PARTY_INVITE")
      end)
    end
    popupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
  end
  return true
end

local function OnInviteRequest(inviter)
  local r = req
  if r and r.phase ~= "invited" then
    SetPhase(r, "invited")
    RI:Log("invitación recibida de %s", (Secret(inviter) or type(inviter) ~= "string") and "?" or inviter)
  end
  TryAutoAccept(r, inviter)
end

local queue = {}
local replies, replyScheduled = nil, false
local convertWanted, convertAt = false, -math.huge
local inviterFrame, watchingFull = nil, false

local function Reply(key, answer)
  replies = replies or {}
  replies[key] = answer
  if replyScheduled then return end
  replyScheduled = true
  C_Timer.After(RI.REPLY_BATCH_SECONDS, function()
    replyScheduled = false
    local batch = replies
    replies = nil
    if not batch or not next(batch) then return end
    local n = 0
    for _ in pairs(batch) do n = n + 1 end
    GG:SendInvitePayload({ kind = "inv_re", r = batch })
    RI:Log("respuestas mandadas: %d", n)
  end)
end

local function PendingInvites(now, exceptKey)
  local n = 0
  for k, e in pairs(queue) do
    if k ~= exceptKey and e.invitedAt and now - e.invitedAt < RI.PENDING_SECONDS then n = n + 1 end
  end
  return n
end

local function InviteEntry(e)
  local invite = (C_PartyInfo and C_PartyInfo.InviteUnit) or InviteUnit
  if invite then invite(e.name) end
  e.invitedAt, e.waiting = Clock(), false
  RI:Log("invitado %s", e.name)
end

local function RequestConvert()
  local home = Home()
  if IsInRaid(home) or not IsInGroup(home) or not Flag(UnitIsGroupLeader and UnitIsGroupLeader("player")) then return end
  if InCombatLockdown and InCombatLockdown() then
    if not convertWanted then RI:Log("en combate: paso a banda al salir") end
    convertWanted = true
    return
  end
  if Clock() - convertAt < RI.CONVERT_RETRY_SECONDS then return end
  convertWanted, convertAt = false, Clock()
  local convert = (C_PartyInfo and C_PartyInfo.ConvertToRaid) or ConvertToRaid
  if convert then convert() end
  RI:Log("paso el grupo a banda")
end

local function UpdateFullWatch()
  local want = next(queue) ~= nil
  if want == watchingFull then return end
  if want and CreateFrame and not inviterFrame then
    inviterFrame = CreateFrame("Frame")
    inviterFrame:SetScript("OnEvent", function(_, event, ...) RI:OnEvent(event, ...) end)
  end
  if not inviterFrame then return end
  watchingFull = want
  if want then
    inviterFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    inviterFrame:RegisterEvent("UI_ERROR_MESSAGE")
  else
    inviterFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
    inviterFrame:UnregisterEvent("UI_ERROR_MESSAGE")
  end
end

local function IsSibling(key)
  local sync = GG.AccountSync
  if not (key and sync and sync.LiveSiblingNames) then return false end
  for _, name in ipairs(sync:LiveSiblingNames()) do
    if NameKey(name) == key then return true end
  end
  return false
end

local function TestRefusalFor(senderKey)
  local RG = GG.RaidGroups
  local f = RG:InviterFacts(RG:OwnGroup(), true)
  f.sibling = IsSibling(senderKey)
  f.grouped = IsInGroup(Home()) == true
  return RI.TestRefusal(f)
end

local probedBy = {}
RI.PROBE_KEEP_SECONDS = 1800

local function SendCap(p, key)
  local refusal = TestRefusalFor(key)
  p.ok = refusal == nil
  GG:SendInvitePayload({ kind = "inv_cap", to = p.name, ok = p.ok })
  RI:Log("prueba: le aviso a %s que %s", p.name, refusal and ("no puedo invitar (" .. refusal .. ")") or "puedo invitar")
end

local function OnProbe(payload, sender, senderKey)
  if NameKey(payload.to) ~= MyKey() or not IsSibling(senderKey) then return end
  local p = { name = sender, at = Clock() }
  probedBy[senderKey] = p
  SendCap(p, senderKey)
end

local function RefreshTestCaps()
  local now = Clock()
  for key, p in pairs(probedBy) do
    if now - p.at > RI.PROBE_KEEP_SECONDS then
      probedBy[key] = nil
    elseif (TestRefusalFor(key) == nil) ~= p.ok then
      SendCap(p, key)
    end
  end
end

function RI:ProbeTest(leader)
  if not GG.SendInvitePayload then return end
  GG:SendInvitePayload({ kind = "inv_probe", to = leader, test = true })
  self:Log("prueba: le pregunto al GG de %s si puede invitar", leader)
end

local function OnRequest(payload, sender, senderKey)
  if NameKey(payload.to) ~= MyKey() then return end
  local test = payload.test == true
  RI:Log("pedido %sde %s (líder %s)", test and "DE PRUEBA " or "", sender, payload.leader)
  local RG = GG.RaidGroups
  local own = RG:OwnGroup()
  local reason
  if test then
    reason = TestRefusalFor(senderKey)
  else
    local capable, why = RG:CanInvite(own)
    reason = RI.GoneReason(own, NameKey(payload.leader), capable, why)
  end
  if reason then
    queue[senderKey] = nil
    Reply(senderKey, "gone")
    RI:Log("no puedo invitar a %s: %s", sender, reason)
    UpdateFullWatch()
    return
  end
  if own and own.keys[senderKey] then
    RI:Log("%s ya está en el grupo", sender)
    return
  end
  local now = Clock()
  local e = queue[senderKey] or { key = senderKey }
  e.name, e.leaderKey, e.askedAt = sender, own and own.leaderKey or MyKey(), now
  queue[senderKey] = e
  local home = Home()
  local action = RI.Decide({
    recent = e.invitedAt ~= nil and now - e.invitedAt < RI.REINVITE_SECONDS,
    raid = IsInRaid(home) == true,
    members = GetNumGroupMembers(home),
    pending = PendingInvites(now, senderKey),
  })
  if action == "again" then
    RI:Log("%s ya invitado hace menos de %d s", sender, RI.REINVITE_SECONDS)
    Reply(senderKey, "ok")
  elseif action == "invite" then
    InviteEntry(e)
    Reply(senderKey, "ok")
  elseif action == "full" then
    queue[senderKey] = nil
    RI:Log("banda llena: %s", sender)
    Reply(senderKey, "full")
  else
    e.invitedAt, e.waiting = nil, true
    RI:Log("%s en cola: grupo de 5 lleno", sender)
    Reply(senderKey, "wait")
    RequestConvert()
  end
  UpdateFullWatch()
end

local function LostReason(own)
  local RG = GG.RaidGroups
  if not IsInGroup(Home()) then return "salí del grupo" end
  local capable, why = RG:CanInvite(own, own == nil)
  if not capable then return why end
  if own then
    for _, e in pairs(queue) do
      if e.leaderKey ~= own.leaderKey then return "cambió el líder" end
    end
  end
  return nil
end

function RI:OnGroupChanged(event)
  if next(probedBy) then RefreshTestCaps() end
  if req and not req.grouped and IsInGroup(Home()) then
    self:Log("entré al grupo (pedido a %s)", req.inviter or req.leader)
    req = nil
  end
  if not next(queue) then
    convertWanted = false
    return
  end
  local own = GG.RaidGroups:OwnGroup()
  local lost = LostReason(own)
  if lost then
    for k, e in pairs(queue) do
      if e.waiting then Reply(k, "gone") end
    end
    self:Log("dejo de invitar (%s): se vacía la cola", lost)
    queue = {}
    convertWanted = false
    UpdateFullWatch()
    return
  end
  if not own then return end
  local now = Clock()
  for k, e in pairs(queue) do
    if own.keys[k] then
      self:Log("%s entró al grupo", e.name)
      queue[k] = nil
    elseif now - e.askedAt > RI.ENTRY_TTL then
      self:Log("pedido de %s vencido", e.name)
      queue[k] = nil
    end
  end
  if convertWanted and not (InCombatLockdown and InCombatLockdown()) then RequestConvert() end
  local waiting = {}
  for _, e in pairs(queue) do
    if e.waiting then waiting[#waiting + 1] = e end
  end
  table.sort(waiting, function(a, b)
    if a.askedAt ~= b.askedAt then return a.askedAt < b.askedAt end
    return a.key < b.key
  end)
  local home = Home()
  if IsInRaid(home) then
    for _, e in ipairs(waiting) do
      if GetNumGroupMembers(home) >= RI.RAID_SIZE then
        queue[e.key] = nil
        Reply(e.key, "full")
      else
        InviteEntry(e)
        Reply(e.key, "ok")
      end
    end
  elseif #waiting > 0 then
    local free = RI.PARTY_SIZE - GetNumGroupMembers(home) - PendingInvites(now)
    local left = 0
    for _, e in ipairs(waiting) do
      if free > 0 then
        InviteEntry(e)
        Reply(e.key, "ok")
        free = free - 1
      else
        left = left + 1
      end
    end
    if left > 0 then RequestConvert() end
  end
  UpdateFullWatch()
end

local function OnGroupFull(text)
  if type(ERR_GROUP_FULL) ~= "string" or Secret(text) or text ~= ERR_GROUP_FULL then return end
  if IsInRaid(Home()) then return end
  local now, n = Clock(), 0
  for k, e in pairs(queue) do
    if e.invitedAt and now - e.invitedAt <= RI.FULL_WINDOW_SECONDS then
      e.invitedAt, e.waiting = nil, true
      Reply(k, "wait")
      n = n + 1
    end
  end
  if n > 0 then
    RI:Log("grupo lleno: %d vuelven a la cola", n)
    RequestConvert()
  end
end

function RI:OnMessage(payload, distribution, sender)
  if distribution ~= "GUILD" or type(payload) ~= "table" then return end
  if Secret(sender) or type(sender) ~= "string" or #sender == 0 or #sender > MAX_NAME then return end
  local senderKey = NameKey(sender)
  if not senderKey or senderKey == MyKey() then return end
  if payload.kind == "inv_req" then
    if type(payload.to) ~= "string" or #payload.to > MAX_NAME then return end
    if type(payload.leader) ~= "string" or #payload.leader > MAX_NAME then return end
    OnRequest(payload, sender, senderKey)
  elseif payload.kind == "inv_re" then
    if type(payload.r) ~= "table" then return end
    OnReply(payload.r, sender, senderKey)
  elseif payload.kind == "inv_probe" then
    if type(payload.to) ~= "string" or #payload.to > MAX_NAME then return end
    OnProbe(payload, sender, senderKey)
  elseif payload.kind == "inv_cap" then
    if type(payload.to) ~= "string" or #payload.to > MAX_NAME or NameKey(payload.to) ~= MyKey() then return end
    if GG.RaidGroups:SetSimulatedInvite(senderKey, payload.ok == true) then
      self:Log("prueba: el GG de %s %s", sender, payload.ok == true and "puede invitar" or "no puede invitar")
    end
  end
end

function RI:OnEvent(event, ...)
  if event == "PARTY_INVITE_REQUEST" then
    OnInviteRequest((...))
  elseif event == "CHAT_MSG_WHISPER_INFORM" then
    OnWhisperEvent(event, (...))
  elseif event == "CHAT_MSG_SYSTEM" then
    OnWhisperEvent(event, (...))
    OnGroupFull((...))
  elseif event == "UI_ERROR_MESSAGE" then
    local _, text = ...
    OnGroupFull(text)
  end
end

function RI:_Queue() return queue end
function RI:_Reset()
  req, excluded, queue = nil, {}, {}
  replies, replyScheduled = nil, false
  convertWanted, convertAt = false, -math.huge
  whisperWatch = nil
  watchingFull = false
  probedBy = {}
end

if CreateFrame then
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("PARTY_INVITE_REQUEST")
  frame:SetScript("OnEvent", function(_, event, ...) RI:OnEvent(event, ...) end)
end
