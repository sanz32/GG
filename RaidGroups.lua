local ADDON_NAME, GG = ...

GG.RaidGroups = {}
local RG = GG.RaidGroups

RG.REPORT_TTL = 150
RG.MIN_FROM_ROSTER = 2
RG.MAX_OUTSIDERS_PARTY = 1
RG.MAX_OUTSIDERS_RAID = 2
RG.LARGE_RAID_SIZE = 10
RG.MAX_OUTSIDERS_LARGE_RAID = 3
RG.CALL_SOUND_MIN_PARTY = 3
RG.MIN_KEPT_NUM, RG.MIN_KEPT_DEN = 2, 3
RG.INVITE_WORD = "inv"

local HEARTBEAT_SECONDS = 60
local HEARTBEAT_SPREAD = 15
local CHANGE_DELAY, CHANGE_SPREAD = 1, 2
local REQUEST_COOLDOWN = 60
local REPLY_SPREAD = 1.5
local WHISPER_COOLDOWN = 5
local MAX_MEMBERS = 40

local function Now() return GetServerTime() end
local function NameKey(name) return GG.RaidRosters.NameKey(name) end

function RG.Sanitize(payload)
  if type(payload) ~= "table" or type(payload.leader) ~= "string" or type(payload.members) ~= "table" then return nil end
  local leaderKey = NameKey(payload.leader)
  if not leaderKey then return nil end
  local members, keys, list = {}, {}, {}
  for i = 1, math.min(#payload.members, MAX_MEMBERS) do
    local name = payload.members[i]
    local k = type(name) == "string" and NameKey(name)
    if k and not keys[k] then
      keys[k] = true
      members[#members + 1] = name
      list[#list + 1] = k
    end
  end
  if #members < 2 or not keys[leaderKey] then return nil end
  table.sort(list)
  local raid = payload.raid == true or #members > 5
  local offline, offList, offKeys = {}, {}, {}
  if type(payload.off) == "table" then
    for i = 1, math.min(#payload.off, MAX_MEMBERS) do
      local name = payload.off[i]
      local k = type(name) == "string" and NameKey(name)
      if k and keys[k] and not offline[k] then
        offline[k] = true
        offList[#offList + 1] = name
        offKeys[#offKeys + 1] = k
      end
    end
  end
  table.sort(offKeys)
  local peak = math.min(tonumber(payload.peak) or 0, MAX_MEMBERS)
  return { leader = payload.leader, leaderKey = leaderKey, members = members, keys = keys, raid = raid,
    offline = offline, off = offList, onlineCount = #members - #offList, peak = math.max(peak, #members),
    hash = (raid and "R|" or "P|") .. leaderKey .. "|" .. table.concat(list, ",") .. "|" .. table.concat(offKeys, ",") }
end

function RG.CollectGroups(reports, now)
  local byLeader = {}
  for _, r in pairs(reports) do
    if now - r.at <= RG.REPORT_TTL then
      local cur = byLeader[r.leaderKey]
      if not cur or r.at > cur.at then byLeader[r.leaderKey] = r end
    end
  end
  local out = {}
  for _, r in pairs(byLeader) do out[#out + 1] = r end
  table.sort(out, function(a, b) return a.leaderKey < b.leaderKey end)
  return out
end

function RG.IsRosterGroup(count, size, isRaid)
  if count < RG.MIN_FROM_ROSTER then return false end
  local allowed = RG.MAX_OUTSIDERS_PARTY
  if isRaid then
    allowed = size >= RG.LARGE_RAID_SIZE and RG.MAX_OUTSIDERS_LARGE_RAID or RG.MAX_OUTSIDERS_RAID
  end
  return size - count <= allowed
end

function RG.IsStillFormed(g)
  if g.offline and g.offline[g.leaderKey] then return false end
  return g.onlineCount * RG.MIN_KEPT_DEN >= g.peak * RG.MIN_KEPT_NUM
end

function RG.BestGroupFor(rosterMembers, groups)
  local rosterKeys = {}
  for _, name in ipairs(rosterMembers or {}) do
    local k = NameKey(name)
    if k then rosterKeys[k] = true end
  end
  local best, bestCount
  for _, g in ipairs(groups or {}) do
    local count = 0
    for k in pairs(rosterKeys) do
      if g.keys[k] and not g.offline[k] then count = count + 1 end
    end
    if RG.IsRosterGroup(count, g.onlineCount, g.raid) and RG.IsStillFormed(g) then
      local better = not best or count > bestCount
        or (count == bestCount and (#g.members > #best.members
          or (#g.members == #best.members and (g.at or 0) > (best.at or 0))))
      if better then best, bestCount = g, count end
    end
  end
  if not best then return nil end
  local present, outsiders = {}, {}
  for k in pairs(rosterKeys) do
    if best.keys[k] and not best.offline[k] then present[k] = true end
  end
  for _, name in ipairs(best.members) do
    local k = NameKey(name)
    if not rosterKeys[k] and not best.offline[k] then outsiders[#outsiders + 1] = name end
  end
  return { group = best, present = present, count = bestCount, outsiders = outsiders }
end

function RG.AltsFor(best, rosterMembers, sameOwner)
  local out = { byRoster = {}, byAlt = {} }
  if not best then return out end
  for _, name in ipairs(rosterMembers or {}) do
    local k = NameKey(name)
    if k and not best.present[k] then
      for _, alt in ipairs(best.outsiders) do
        local ak = NameKey(alt)
        if ak and not out.byAlt[ak] and sameOwner(name, alt) then
          out.byRoster[k], out.byAlt[ak] = alt, name
          break
        end
      end
    end
  end
  return out
end

function RG.CallSounds(group, count)
  return group.raid == true or count >= RG.CALL_SOUND_MIN_PARTY
end

function RG.InviteCallFor(rosters, groups, characterKey)
  local me = NameKey(characterKey)
  if not me then return nil end
  local pick
  for _, roster in ipairs(rosters or {}) do
    if RG.InRoster(roster.members, characterKey) then
      local best = RG.BestGroupFor(roster.members, groups)
      if best then
        if best.group.keys[me] then return nil end
        if not pick or best.count > pick.count then
          pick = { roster = roster, group = best.group, count = best.count, sounds = RG.CallSounds(best.group, best.count) }
        end
      end
    end
  end
  return pick
end

function RG.JoinedRosters(rosters, groups, characterKey)
  local me = NameKey(characterKey)
  local out = {}
  if not me then return out end
  for _, roster in ipairs(rosters or {}) do
    if RG.InRoster(roster.members, characterKey) then
      local best = RG.BestGroupFor(roster.members, groups)
      if best and best.group.keys[me] and not best.group.simulated then out[#out + 1] = roster end
    end
  end
  return out
end

function RG.WrongCharacter(group, rosters, myChars, currentKey)
  if not group then return nil end
  local best, bestCount
  for _, roster in ipairs(rosters or {}) do
    local count = 0
    for _, name in ipairs(roster.members or {}) do
      local k = NameKey(name)
      if k and group.keys[k] and not group.offline[k] then count = count + 1 end
    end
    if RG.IsRosterGroup(count, group.onlineCount, group.raid) and RG.IsStillFormed(group) and (not best or count > bestCount) then
      best, bestCount = roster, count
    end
  end
  if not best or RG.InRoster(best.members, currentKey) then return nil end
  for _, char in ipairs(myChars or {}) do
    if RG.InRoster(best.members, char.key) then
      if group.keys[NameKey(char.key)] then return nil end
      return { roster = best, count = bestCount, total = group.onlineCount, mine = char }
    end
  end
  return nil
end

local function FullName(name)
  if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return nil end
  if name:find("-", 1, true) then return name end
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName() or ""):gsub("%s+", "")
  if not realm or realm == "" then return nil end
  return name .. "-" .. realm
end

function RG.MatchesAnyRoster(group, set)
  for _, roster in ipairs((set and set.rosters) or {}) do
    if RG.BestGroupFor(roster.members, { group }) then return true end
  end
  return false
end

function RG.IsInviter(f)
  if f.enabled == false then return false, "opción apagada" end
  if not f.home then return false, "sin grupo propio" end
  if not f.matches then return false, "no es el grupo de un roster" end
  if f.leader then return true end
  if f.raid and (f.assistant or f.everyoneAssistant) then return true end
  return false, "sin permiso para invitar"
end

function RG.InvitersFrom(reports, group, now)
  local list, atByKey = {}, {}
  if not group or not group.leaderKey or not group.keys then return {}, atByKey end
  for key, r in pairs(reports) do
    if r.inv and type(r.sender) == "string" and r.leaderKey == group.leaderKey and now - r.at <= RG.REPORT_TTL
      and group.keys[key] and not (group.offline and group.offline[key]) then
      list[#list + 1] = { name = r.sender, key = key, at = r.at }
    end
  end
  table.sort(list, function(a, b)
    local al, bl = a.key == group.leaderKey, b.key == group.leaderKey
    if al ~= bl then return al end
    if a.at ~= b.at then return a.at > b.at end
    return a.key < b.key
  end)
  local names = {}
  for i, e in ipairs(list) do
    names[i] = e.name
    atByKey[e.key] = e.at
  end
  return names, atByKey
end

local function IsOffline(unit)
  if not UnitIsConnected then return false end
  local connected = UnitIsConnected(unit)
  if issecretvalue and issecretvalue(connected) then return false end
  return connected == false
end

local ownPeak = 0

local function WithPeak(g)
  if not g then return nil end
  ownPeak = math.max(ownPeak, g.peak)
  g.peak = ownPeak
  return g
end

local function ReadParty(home)
  local members, leader, off = {}, nil, {}
  for i = 0, GetNumGroupMembers(home) - 1 do
    local unit = i == 0 and "player" or ("party" .. i)
    local name = GetUnitName(unit, true)
    if issecretvalue and issecretvalue(name) then return nil end
    local full = FullName(name)
    if not full then return nil end
    members[#members + 1] = full
    if IsOffline(unit) then off[#off + 1] = full end
    if UnitIsGroupLeader(unit) then leader = full end
  end
  return members, leader, off
end

function RG:ReadOwnGroup()
  local home = LE_PARTY_CATEGORY_HOME
  if not IsInGroup(home) then
    ownPeak = 0
    return nil
  end
  if not IsInRaid(home) then
    local members, leader, off = ReadParty(home)
    if not leader then return nil end
    local g = WithPeak(RG.Sanitize({ leader = leader, members = members, off = off }))
    if not g or not RG.MatchesAnyRoster(g, GG.RaidRosters:GetCurrentSet()) then return nil end
    g.at = Now()
    return g
  end
  local members, leader, off = {}, nil, {}
  for i = 1, GetNumGroupMembers(home) do
    local name, rank = GetRaidRosterInfo(i)
    if issecretvalue and issecretvalue(name) then return nil end
    local full = FullName(name)
    if not full then return nil end
    members[#members + 1] = full
    if IsOffline("raid" .. i) then off[#off + 1] = full end
    if rank == 2 then leader = full end
  end
  if not leader then return nil end
  local g = WithPeak(RG.Sanitize({ leader = leader, members = members, raid = true, off = off }))
  if g then g.at = Now() end
  return g
end

local reports = {}
local own
local lastSentHash, lastSentAt = nil, -math.huge
local lastSentInv = false
local pendingChange, pendingReply
local lastRequestAt = -math.huge
local lastWhisperAt = -math.huge

local function Busy()
  return (InCombatLockdown and InCombatLockdown()) or (IsEncounterInProgress and IsEncounterInProgress()) or false
end

local function MayReport()
  return IsInGuild() and GG.RaidRosters:GetCurrentSet() ~= nil
end

local function Flag(v)
  if issecretvalue and issecretvalue(v) then return false end
  return v == true
end

function RG:InviterFacts(group, assumeMatch)
  local home = LE_PARTY_CATEGORY_HOME
  local options = GGDB and GGDB.options
  return {
    enabled = not (options and options.rosterAutoInvite == false),
    home = (group ~= nil or assumeMatch == true) and IsInGroup(home) == true,
    leader = Flag(UnitIsGroupLeader and UnitIsGroupLeader("player")),
    assistant = Flag(UnitIsGroupAssistant and UnitIsGroupAssistant("player")),
    everyoneAssistant = Flag(IsEveryoneAssistant and IsEveryoneAssistant()),
    raid = IsInRaid(home) == true,
    matches = group == nil and assumeMatch == true
      or (group ~= nil and RG.MatchesAnyRoster(group, GG.RaidRosters:GetCurrentSet())),
  }
end

function RG:CanInvite(group, assumeMatch)
  return RG.IsInviter(self:InviterFacts(group, assumeMatch))
end

function RG:OwnGroup() return own end

local function Changed()
  if GG.RaidRostersTab and GG.RaidRostersTab.RefreshIfShown then GG.RaidRostersTab:RefreshIfShown() end
  if GG.RaidRostersTab and GG.RaidRostersTab.RepaintTags then GG.RaidRostersTab:RepaintTags() end
  if GG.RosterCall then GG.RosterCall:Evaluate() end
end

function RG.AlreadyReported(reportList, group, since, inv, iAmLeader)
  if inv and iAmLeader then return false end
  for _, r in pairs(reportList) do
    if r.at >= since and r.hash == group.hash and (not inv or r.inv) then return true end
  end
  return false
end

local function SendState(group, inv)
  if GG:SendRosterPayload({ kind = "grp_state", leader = group.leader, members = group.members, raid = group.raid,
    off = group.off, peak = group.peak, inv = inv or nil }, "ALERT") then
    lastSentHash, lastSentAt, lastSentInv = group.hash, Now(), inv
  end
end

local function Report(since, force)
  if Busy() then return end
  own = RG:ReadOwnGroup()
  Changed()
  if not own then
    if lastSentHash then
      lastSentHash, lastSentInv = nil, false
      GG:SendRosterPayload({ kind = "grp_end" }, "ALERT")
    end
    return
  end
  if not MayReport() then return end
  local inv = RG:CanInvite(own) == true
  if not force and own.hash == lastSentHash and inv == lastSentInv then return end
  local iAmLeader = own.leaderKey == NameKey(GG:GetCharacterKey())
  if RG.AlreadyReported(reports, own, since, inv, iAmLeader) then
    lastSentHash, lastSentAt, lastSentInv = own.hash, Now(), inv
    return
  end
  SendState(own, inv)
end

local READ_RETRIES, READ_RETRY_SECONDS = 5, 1
local readRetries, readRetryPending = 0, false

local JOIN_WINDOW = 30
local joinedAt, joinChecked = nil, false

local function TrackJoin(event)
  if not IsInGroup(LE_PARTY_CATEGORY_HOME) then
    joinedAt, joinChecked = nil, false
  elseif not joinedAt and not joinChecked then
    if event == "PLAYER_ENTERING_WORLD" then joinChecked = true else joinedAt = GetTime() end
  end
end

local function CheckJoin()
  if joinChecked or not joinedAt or not own then return end
  if GetTime() - joinedAt > JOIN_WINDOW then joinChecked = true return end
  if GG.RosterAlert and GG.RosterAlert:CheckJoin(own) then joinChecked = true end
end

function RG:OnGroupEvent(event)
  TrackJoin(event)
  if not Busy() then
    own = RG:ReadOwnGroup()
    Changed()
    CheckJoin()
    if own or not IsInGroup(LE_PARTY_CATEGORY_HOME) then
      readRetries = 0
    elseif not readRetryPending and readRetries < READ_RETRIES then
      readRetries = readRetries + 1
      readRetryPending = true
      C_Timer.After(READ_RETRY_SECONDS, function()
        readRetryPending = false
        RG:OnGroupEvent()
      end)
    end
  end
  if GG.RaidInvites then GG.RaidInvites:OnGroupChanged(event) end
  if pendingChange then return end
  local since = Now()
  pendingChange = true
  C_Timer.After(CHANGE_DELAY + math.random() * CHANGE_SPREAD, function()
    pendingChange = nil
    Report(since, false)
  end)
end

function RG:OnInviteOptionChanged()
  if GG.RaidInvites then GG.RaidInvites:OnGroupChanged("OPTION") end
  if pendingChange then return end
  local since = Now()
  pendingChange = true
  C_Timer.After(CHANGE_DELAY + math.random() * CHANGE_SPREAD, function()
    pendingChange = nil
    Report(since, false)
  end)
end

function RG:Heartbeat()
  local now, pruned = Now(), false
  for k, r in pairs(reports) do
    if now - r.at > self.REPORT_TTL then reports[k] = nil; pruned = true end
  end
  if pruned then Changed() end
  if not own and not lastSentHash then return end
  C_Timer.After(math.random() * HEARTBEAT_SPREAD, function()
    if Now() - lastSentAt < HEARTBEAT_SECONDS - 10 and own and own.hash == lastSentHash
      and (RG:CanInvite(own) == true) == lastSentInv then return end
    Report(Now() - (HEARTBEAT_SECONDS - 10), true)
  end)
end

function RG:RequestIfNeeded()
  if not MayReport() or Now() - lastRequestAt < REQUEST_COOLDOWN then return false end
  lastRequestAt = Now()
  GG:SendRosterPayload({ kind = "grp_req" }, "ALERT")
  return true
end

function RG:OnMessage(payload, sender)
  local senderKey = NameKey(sender)
  if not senderKey then return end
  if payload.kind == "grp_end" then
    if reports[senderKey] then reports[senderKey] = nil; Changed() end
  elseif payload.kind == "grp_state" then
    local g = self.Sanitize(payload)
    if not g or not g.keys[senderKey] then return end
    g.at = Now()
    g.sender, g.inv = sender, payload.inv == true
    for _, r in pairs(reports) do
      if r.leaderKey == g.leaderKey and r.peak > g.peak then g.peak = r.peak end
    end
    if own and own.leaderKey == g.leaderKey then
      ownPeak = math.max(ownPeak, g.peak)
      own.peak = ownPeak
    end
    reports[senderKey] = g
    Changed()
  elseif payload.kind == "grp_req" then
    if pendingReply or not own then return end
    local since = Now()
    pendingReply = true
    C_Timer.After(math.random() * REPLY_SPREAD, function()
      pendingReply = nil
      Report(since, true)
    end)
  end
end

function RG:Groups()
  local list = self.CollectGroups(reports, Now())
  if own then
    for i, g in ipairs(list) do
      if g.leaderKey == own.leaderKey then table.remove(list, i) break end
    end
    list[#list + 1] = own
  end
  return list
end

function RG.InRoster(rosterMembers, characterKey)
  local key = NameKey(characterKey)
  if not key then return false end
  for _, name in ipairs(rosterMembers or {}) do
    if NameKey(name) == key then return true end
  end
  return false
end

function RG:IsInside(group)
  local me = NameKey(GG:GetCharacterKey())
  return me ~= nil and group.keys[me] == true
end

function RG:InvitersFor(group)
  if not group or not group.leaderKey then return {}, {} end
  if group.simulated then
    if not group.simInv then return {}, {} end
    return { group.leader }, { [group.leaderKey] = group.simAt or -math.huge }
  end
  local current = group
  for _, g in ipairs(self:Groups()) do
    if g.leaderKey == group.leaderKey then current = g break end
  end
  return RG.InvitersFrom(reports, current, Now())
end

function RG:RequestInvite(group)
  if GetTime() - lastWhisperAt < WHISPER_COOLDOWN then return false end
  local RI = GG.RaidInvites
  local path, inviter = "whisper", nil
  if RI then path, inviter = RI:PlanFor(group) end
  if path == "gg" then
    lastWhisperAt = GetTime()
    RI:SendRequest(group, inviter)
    return "gg"
  end
  if GG.IsChatRestricted and GG:IsChatRestricted() then return false end
  lastWhisperAt = GetTime()
  if RI then RI:WatchWhisper(group) end
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  send(self.INVITE_WORD, "WHISPER", nil, group.leader)
  return "whisper"
end

function RG:SimulateForming(roster, leader)
  reports.__test = nil
  if roster then
    local me, lk = NameKey(GG:GetCharacterKey()), NameKey(leader)
    local members = { leader }
    for _, name in ipairs(roster.members or {}) do
      local k = NameKey(name)
      if #members < 3 and k and k ~= me and k ~= lk then members[#members + 1] = name end
    end
    local g = #members == 3 and RG.Sanitize({ leader = leader, members = members, raid = true })
    if not g then return false end
    g.at = math.huge
    g.simulated = true
    g.simInv = false
    g.simAt = Now()
    reports.__test = g
    if GG.RaidInvites then GG.RaidInvites:ProbeTest(leader) end
  end
  Changed()
  return true
end

function RG:SetSimulatedInvite(senderKey, ok)
  local g = reports.__test
  if not g or g.leaderKey ~= senderKey then return false end
  g.simInv, g.simAt = ok, Now()
  Changed()
  return true
end

function RG:_Reset()
  reports, own, lastSentHash, lastSentAt, lastSentInv = {}, nil, nil, -math.huge, false
  ownPeak = 0
  pendingChange, pendingReply, lastRequestAt, lastWhisperAt = nil, nil, -math.huge, -math.huge
  readRetries, readRetryPending = 0, false
  joinedAt, joinChecked = nil, false
end

if CreateFrame then
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("GROUP_ROSTER_UPDATE")
  frame:RegisterEvent("PARTY_LEADER_CHANGED")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
  frame:RegisterEvent("PLAYER_REGEN_ENABLED")
  frame:RegisterEvent("UNIT_CONNECTION")
  frame:SetScript("OnEvent", function(_, event) RG:OnGroupEvent(event) end)
  if C_Timer.NewTicker then C_Timer.NewTicker(HEARTBEAT_SECONDS, function() RG:Heartbeat() end) end
end
