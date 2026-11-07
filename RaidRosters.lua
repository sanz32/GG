local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG", true)

GG.RaidRosters = {}
local RR = GG.RaidRosters

local MAX_ROSTERS = 40
local MAX_MEMBERS = 40
RR.MAX_LABEL = 24
local MAX_LIFETIME_SECONDS = 8 * 86400
local HELLO_DELAY_SECONDS = 8
local SHARE_SPREAD_SECONDS = 4

RR.DIFFICULTIES = { 14, 15, 16 }

local function Trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

function RR.SplitCells(line)
  line = line:gsub("\r", "")
  local cells = {}
  if line:find("\t", 1, true) then
    for cell in (line .. "\t"):gmatch("([^\t]*)\t") do cells[#cells + 1] = Trim(cell) end
    return cells
  end
  local cur, pos = "", 1
  while true do
    local s, e = line:find(" +", pos)
    if not s then break end
    local run = e - s + 1
    if run >= 4 then
      cells[#cells + 1] = Trim(cur .. line:sub(pos, s - 1))
      for _ = 2, math.floor(run / 4) do cells[#cells + 1] = "" end
      cur = ""
    else
      cur = cur .. line:sub(pos, e)
    end
    pos = e + 1
  end
  cells[#cells + 1] = Trim(cur .. line:sub(pos))
  return cells
end

function RR.IsCharacterName(cell)
  return cell ~= nil and cell:find("^[^%s%-]+%-[^%s]+$") ~= nil
end

function RR.NameKey(full)
  local name, realm = (full or ""):match("^([^%-]+)%-(.+)$")
  if not name then return nil end
  return name:lower() .. "-" .. realm:gsub("[%s%-']", ""):lower()
end

local function AutoName(n)
  return ((L and L["RAID_ROSTER_AUTO_NAME"]) or "Roster %d"):format(n)
end

local function RowInfo(row)
  local hasName, hasText = false, false
  for _, cell in ipairs(row) do
    if cell ~= "" then
      if RR.IsCharacterName(cell) then hasName = true else hasText = true end
    end
  end
  return hasName, hasText
end

function RR.ParseAll(text)
  local grid = {}
  for line in ((text or "") .. "\n"):gmatch("([^\n]*)\n") do grid[#grid + 1] = RR.SplitCells(line) end

  local groups, blocks, blankRun = {}, nil, 0
  local function NewGroup(label, auto)
    local g = { label = label, orig = label, auto = auto, members = {} }
    groups[#groups + 1] = g
    return g
  end
  local function AutoBlocks(from)
    local used, blank = {}, 0
    for r = from, #grid do
      local row = grid[r]
      local hasName, hasText = RowInfo(row)
      if not hasName and hasText then break end
      blank = (hasName or hasText) and 0 or blank + 1
      if blank >= 2 then break end
      for i, cell in ipairs(row) do
        if RR.IsCharacterName(cell) then used[i] = true end
      end
    end
    local cols = {}
    for i in pairs(used) do cols[#cols + 1] = i end
    table.sort(cols)
    local out = {}
    for _, c in ipairs(cols) do
      local last = out[#out]
      if last and c == last.last + 1 then last.last = c else out[#out + 1] = { first = c, last = c } end
    end
    for _, b in ipairs(out) do b.group = NewGroup(AutoName(#groups + 1), true) end
    return out
  end

  for r, row in ipairs(grid) do
    local hasName, hasText = RowInfo(row)
    if not hasName and hasText then
      blankRun = 0
      local titles = {}
      for i, cell in ipairs(row) do
        if cell ~= "" then titles[#titles + 1] = { col = i, text = cell } end
      end
      blocks = {}
      for k, t in ipairs(titles) do
        blocks[k] = { first = t.col, last = titles[k + 1] and (titles[k + 1].col - 1) or math.huge, group = NewGroup(t.text, false) }
      end
    elseif not hasName then
      blankRun = blankRun + 1
    else
      if not blocks or (blocks[1] and blocks[1].group.auto and blankRun >= 2) then blocks = AutoBlocks(r) end
      blankRun = 0
      for _, b in ipairs(blocks) do
        for i = b.first, math.min(b.last, #row) do
          if RR.IsCharacterName(row[i]) then table.insert(b.group.members, row[i]) end
        end
      end
    end
  end
  return groups
end

function RR.ParseOne(text)
  local names = {}
  for token in (text or ""):gmatch("[^%s,;/|]+") do
    token = token:gsub("^[%d%.%)%*]+(%D)", "%1"):gsub("[%.,;:!%?%)%]]+$", "")
    if RR.IsCharacterName(token) then names[#names + 1] = token end
  end
  return names
end

function RR.Summarize(groups)
  local kept, skipped, dups, seenIn = {}, {}, {}, {}
  for _, g in ipairs(groups) do
    local unique, seen = {}, {}
    for _, name in ipairs(g.members) do
      local k = RR.NameKey(name)
      if k and not seen[k] then
        seen[k] = true
        unique[#unique + 1] = name
        if seenIn[k] and seenIn[k] ~= g then dups[#dups + 1] = name end
        seenIn[k] = g
      end
    end
    g.members = unique
    if #unique > 0 then kept[#kept + 1] = g else skipped[#skipped + 1] = g.label end
  end
  return { rosters = kept, skipped = skipped, dups = dups }
end

local function Now() return GetServerTime() end

function RR:GuildKey()
  if not IsInGuild() then return nil end
  local name, _, _, realm = GetGuildInfo("player")
  if not name or name == "" then return nil end
  realm = realm or (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or ""
  return name .. "-" .. realm:gsub("%s+", "")
end

local function Store()
  GGDB.raidRosters = GGDB.raidRosters or {}
  return GGDB.raidRosters
end

local function IsLive(set)
  return set ~= nil and (set.expiresAt or 0) > Now()
end

local function IsActive(set)
  return IsLive(set) and not set.deleted
end

local function IsNewer(a, b)
  if not b then return true end
  if (a.publishedAt or 0) ~= (b.publishedAt or 0) then return (a.publishedAt or 0) > (b.publishedAt or 0) end
  return (a.publisher or "") > (b.publisher or "")
end

function RR:GetCurrentSet()
  local key = self:GuildKey()
  local set = key and Store()[key]
  return IsActive(set) and set or nil
end

function RR:HasActive()
  for _, set in pairs((GGDB and GGDB.raidRosters) or {}) do
    if IsActive(set) then return true end
  end
  return false
end

local index, indexStamp = {}, nil

local function Signature()
  local parts = {}
  for gk, set in pairs((GGDB and GGDB.raidRosters) or {}) do
    if IsActive(set) then parts[#parts + 1] = gk .. "@" .. tostring(set.publishedAt) .. tostring(set.publisher) end
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function EnsureIndex()
  local sig = Signature()
  if sig == indexStamp then return end
  index, indexStamp = {}, sig
  for _, set in pairs((GGDB and GGDB.raidRosters) or {}) do
    if IsActive(set) then
      for _, roster in ipairs(set.rosters or {}) do
        for _, name in ipairs(roster.members or {}) do
          local k = RR.NameKey(name)
          if k then
            index[k] = index[k] or {}
            table.insert(index[k], { roster = roster, set = set })
          end
        end
      end
    end
  end
end

function RR:IsSaved(record, raidInstanceID, difficultyID)
  if not (record and raidInstanceID and difficultyID and GG.Lockouts) then return false end
  local prefix = raidInstanceID .. ":" .. difficultyID .. ":"
  for k in pairs(GG.Lockouts:BuildKilledLookup(record)) do
    if k:sub(1, #prefix) == prefix then return true end
  end
  return false
end

function RR:TagsFor(characterKey, record)
  if not characterKey then return {} end
  EnsureIndex()
  local out = {}
  for _, hit in ipairs(index[RR.NameKey(characterKey)] or {}) do
    out[#out + 1] = {
      label = hit.roster.label,
      raid = hit.roster.raid,
      diff = hit.roster.diff,
      saved = self:IsSaved(record, hit.roster.raid, hit.roster.diff),
      roster = hit.roster,
      set = hit.set,
      key = characterKey,
    }
  end
  return out
end

function RR:RaidName(instanceID)
  for _, list in ipairs({ GG.Season.RAIDS or {}, GG.Season.PENDING_RAIDS or {} }) do
    for _, raid in ipairs(list) do
      if raid.instanceID == instanceID then return ((raid.name or ""):gsub("^The ", "")) end
    end
  end
  return "?"
end

RR.STALE_SECONDS = 3 * 86400

function RR.BuildMemberLookup(chars, classes, now, summaries)
  local byKey = {}
  for _, record in pairs(chars or {}) do
    if type(record) == "table" and record.name and record.realm then
      local k = RR.NameKey(record.name .. "-" .. record.realm)
      if k then byKey[k] = record end
    end
  end
  return function(name)
    local k = RR.NameKey(name)
    local record = k and byKey[k]
    local ilvl = record and tonumber(record.itemLevel)
    if ilvl and ilvl <= 0 then ilvl = nil end
    local updatedAt = ilvl and tonumber(record.ts) or nil
    local summary = k and summaries and summaries[k]
    if summary and (not updatedAt or summary.t > updatedAt) then
      ilvl, updatedAt = summary.i, summary.t
    end
    return {
      class = (record and record.class) or (k and classes and classes[k]) or (summary and summary.c) or nil,
      ilvl = ilvl,
      updatedAt = updatedAt,
      stale = updatedAt ~= nil and now - updatedAt > RR.STALE_SECONDS,
    }
  end
end

function RR.AverageIlvl(infos)
  local sum, n = 0, 0
  for _, info in ipairs(infos) do
    if info.ilvl then sum, n = sum + info.ilvl, n + 1 end
  end
  return n > 0 and sum / n or nil, n
end

local guildClasses, guildDirty = {}, true

local function GuildClasses()
  if guildDirty and GetNumGuildMembers and GetGuildRosterInfo then
    guildDirty = false
    guildClasses = {}
    for i = 1, GetNumGuildMembers() do
      local name, _, _, _, _, _, _, _, _, _, classFile = GetGuildRosterInfo(i)
      local k = RR.NameKey(name)
      if k and classFile then guildClasses[k] = classFile end
    end
  end
  return guildClasses
end

function RR:MemberLookup()
  return RR.BuildMemberLookup(GGDB and GGDB.chars, GuildClasses(), Now(), GGDB and GGDB.memberIlvl)
end

function RR:RequestGuildRoster()
  if C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
end

local MAX_SUMMARY = 60
RR.SUMMARY_MAX_AGE = 60 * 86400

function RR.OwnSummary(chars, own, guildName, onlyKeys)
  local out = {}
  for key in pairs(own or {}) do
    local r = chars and chars[key]
    local ilvl = r and tonumber(r.itemLevel)
    if r and r.name and r.realm and r.guild == guildName and ilvl and ilvl > 0 and tonumber(r.ts) then
      local full = r.name .. "-" .. r.realm
      if not onlyKeys or onlyKeys[RR.NameKey(full)] then
        out[#out + 1] = { n = full, c = r.class, i = ilvl, t = tonumber(r.ts) }
        if #out >= MAX_SUMMARY then break end
      end
    end
  end
  return out
end

function RR.MergeSummary(store, list, now)
  if type(list) ~= "table" then return 0 end
  local changed, keys = 0, {}
  for i = 1, math.min(#list, MAX_SUMMARY) do
    local e = list[i]
    if type(e) == "table" and type(e.n) == "string" and RR.IsCharacterName(e.n) then
      local ilvl, ts = tonumber(e.i), tonumber(e.t)
      if ilvl and ilvl > 0 and ilvl < 2000 and ts and ts <= now + 300 then
        local k = RR.NameKey(e.n)
        local cur = store[k]
        if not cur or (cur.t or 0) < ts then
          local class = type(e.c) == "string" and e.c:match("^[A-Z]+$") or nil
          store[k] = { i = ilvl, t = ts, c = class, o = cur and cur.o }
          changed = changed + 1
        end
        keys[#keys + 1] = k
      end
    end
  end
  RR.LinkOwner(store, keys)
  return changed
end

function RR.LinkOwner(store, keys)
  local id
  for _, k in ipairs(keys) do
    if store[k] and store[k].o then id = store[k].o break end
  end
  id = id or keys[1]
  if not id then return end
  local old = {}
  for _, k in ipairs(keys) do
    local e = store[k]
    if e then
      if e.o and e.o ~= id then old[e.o] = true end
      e.o = id
    end
  end
  if next(old) then
    for _, e in pairs(store) do
      if e.o and old[e.o] then e.o = id end
    end
  end
end

function RR:SameOwner(a, b)
  local ka, kb = RR.NameKey(a), RR.NameKey(b)
  if not ka or not kb then return false end
  if ka == kb then return true end
  local mine = {}
  for key in pairs((GGDB and GGDB.ownCharacters) or {}) do
    local r = GGDB.chars and GGDB.chars[key]
    if r and r.name and r.realm then mine[RR.NameKey(r.name .. "-" .. r.realm) or ""] = true end
  end
  if mine[ka] and mine[kb] then return true end
  local s = GGDB and GGDB.memberIlvl
  local ea, eb = s and s[ka], s and s[kb]
  return ea ~= nil and eb ~= nil and ea.o ~= nil and ea.o == eb.o
end

function RR:DifficultyName(difficultyID)
  local key = ({ [14] = "DIFFICULTY_NORMAL", [15] = "DIFFICULTY_HEROIC", [16] = "DIFFICULTY_MYTHIC" })[difficultyID]
  return (key and L and L[key]) or tostring(difficultyID)
end

function RR.Sanitize(set, now)
  if type(set) ~= "table" or type(set.rosters) ~= "table" then return nil end
  local expiresAt, publishedAt = tonumber(set.expiresAt), tonumber(set.publishedAt)
  if not expiresAt or not publishedAt or expiresAt <= now or expiresAt > now + MAX_LIFETIME_SECONDS then return nil end
  if type(set.publisher) ~= "string" or not RR.NameKey(set.publisher) then return nil end
  local deleted = set.deleted == true
  if deleted then
    return { publishedAt = publishedAt, expiresAt = expiresAt, publisher = set.publisher, deleted = true, rosters = {} }
  end
  if #set.rosters == 0 or #set.rosters > MAX_ROSTERS then return nil end
  local clean = { publishedAt = publishedAt, expiresAt = expiresAt, publisher = set.publisher, auto = set.auto == true or nil, rosters = {} }
  for _, r in ipairs(set.rosters) do
    if type(r) ~= "table" or type(r.label) ~= "string" or type(r.members) ~= "table" then return nil end
    local diff, raid = tonumber(r.diff), tonumber(r.raid)
    if not raid or (diff ~= 14 and diff ~= 15 and diff ~= 16) then return nil end
    local members = {}
    for i = 1, math.min(#r.members, MAX_MEMBERS) do
      local name = r.members[i]
      if type(name) == "string" and RR.IsCharacterName(name) then members[#members + 1] = name end
    end
    local label = Trim(r.label):sub(1, RR.MAX_LABEL)
    if label == "" or #members == 0 then return nil end
    clean.rosters[#clean.rosters + 1] = { label = label, raid = raid, diff = diff, members = members }
  end
  return clean
end

local pendingShare
local expiryTimer

local function Changed()
  if expiryTimer then expiryTimer:Cancel() expiryTimer = nil end
  local set = RR:GetCurrentSet()
  if set and C_Timer.NewTimer then
    expiryTimer = C_Timer.NewTimer(math.max(1, set.expiresAt - Now() + 1), Changed)
  end
  if GG.RosterUI and GG.RosterUI.OnRaidRostersChanged then GG.RosterUI:OnRaidRostersChanged() end
  if set and GG.RaidGroups then
    GG.RaidGroups:OnGroupEvent()
    GG.RaidGroups:RequestIfNeeded()
  end
end
RR.Changed = Changed

local function IsMe(sender)
  return RR.NameKey(sender) == RR.NameKey(GG:GetCharacterKey())
end

function RR.PublisherName(set)
  if set.auto then return L["RR_AUTO_NAME"] end
  return set.publisher or "?"
end

function RR:Publish(rosters, auto)
  local guildKey = self:GuildKey()
  if not guildKey then return false end
  local now = Now()
  local untilReset = (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()) or (7 * 86400)
  local set = RR.Sanitize({
    publishedAt = now,
    expiresAt = now + math.max(60, untilReset),
    publisher = GG:GetCharacterKey(),
    auto = auto == true,
    rosters = rosters,
  }, now)
  if not set then return false end
  Store()[guildKey] = set
  if pendingShare then pendingShare.cancelled = true pendingShare = nil end
  GG:SendRosterPayload({ kind = "roster_publish", set = set })
  Changed()
  return true
end

function RR:CanDelete()
  local set = self:GetCurrentSet()
  return set ~= nil and RR.NameKey(set.publisher) == RR.NameKey(GG:GetCharacterKey())
end

function RR:WhoCanDeleteText()
  local set = self:GetCurrentSet()
  if not set then return L["RR_DELETE_WHO_NONE"] end
  return (self:CanDelete() and L["RR_DELETE_WHO_ME"] or L["RR_DELETE_WHO"]):format(set.publisher)
end

function RR:Delete()
  local guildKey = self:GuildKey()
  local current = self:GetCurrentSet()
  if not guildKey or not self:CanDelete() then return false end
  local tomb = {
    publishedAt = math.max(Now(), current.publishedAt + 1),
    expiresAt = current.expiresAt,
    publisher = current.publisher,
    deleted = true,
    rosters = {},
  }
  Store()[guildKey] = tomb
  if pendingShare then pendingShare.cancelled = true pendingShare = nil end
  GG:SendRosterPayload({ kind = "roster_publish", set = tomb })
  Changed()
  return true
end

function RR:Hello()
  local guildKey = self:GuildKey()
  if not guildKey then return end
  for key, set in pairs(Store()) do
    if not IsLive(set) then Store()[key] = nil end
  end
  local mine = Store()[guildKey]
  GG:SendRosterPayload({ kind = "roster_hello", have = mine and mine.publishedAt or 0, haveBy = mine and mine.publisher or "" })
  local summaries, now = GGDB.memberIlvl or {}, Now()
  for k, s in pairs(summaries) do
    if now - (s.t or 0) > RR.SUMMARY_MAX_AGE then summaries[k] = nil end
  end
  self:PushOwnIlvl(nil)
  Changed()
end

local ILVL_REQUEST_COOLDOWN = 60
local ILVL_REPLY_SPREAD_SECONDS = 2
local lastIlvlRequestAt = -math.huge
local pendingIlvlReply

function RR:PushOwnIlvl(onlyKeys)
  local list = RR.OwnSummary(GGDB and GGDB.chars, GGDB and GGDB.ownCharacters, (GetGuildInfo("player")), onlyKeys)
  if #list == 0 then return false end
  GG:SendRosterPayload({ kind = "ilvl_push", list = list })
  return true
end

function RR:RequestIlvl()
  local set = self:GetCurrentSet()
  if not set or Now() - lastIlvlRequestAt < ILVL_REQUEST_COOLDOWN then return false end
  local keys, seen = {}, {}
  for _, roster in ipairs(set.rosters) do
    for _, name in ipairs(roster.members) do
      local k = RR.NameKey(name)
      if k and not seen[k] then seen[k] = true; keys[#keys + 1] = k end
    end
  end
  if #keys == 0 then return false end
  lastIlvlRequestAt = Now()
  GG:SendRosterPayload({ kind = "ilvl_req", keys = keys })
  return true
end

function RR:OnMessage(payload, distribution, sender)
  if distribution ~= "GUILD" or type(payload) ~= "table" or IsMe(sender) then return end
  local guildKey = self:GuildKey()
  if not guildKey then return end
  local now = Now()

  if payload.kind == "grp_state" or payload.kind == "grp_end" or payload.kind == "grp_req" then
    if GG.RaidGroups then GG.RaidGroups:OnMessage(payload, sender) end
    return
  end

  if payload.kind == "ilvl_req" then
    if type(payload.keys) ~= "table" then return end
    local job = pendingIlvlReply
    if not job then
      job = { keys = {} }
      pendingIlvlReply = job
      C_Timer.After(math.random() * ILVL_REPLY_SPREAD_SECONDS, function()
        if pendingIlvlReply == job then pendingIlvlReply = nil end
        RR:PushOwnIlvl(job.keys)
      end)
    end
    for i = 1, math.min(#payload.keys, 2 * MAX_ROSTERS * MAX_MEMBERS) do
      local k = payload.keys[i]
      if type(k) == "string" then job.keys[k] = true end
    end
    return
  end

  if payload.kind == "ilvl_push" then
    GGDB.memberIlvl = GGDB.memberIlvl or {}
    if RR.MergeSummary(GGDB.memberIlvl, payload.list, now) > 0
      and GG.RaidRostersTab and GG.RaidRostersTab.RefreshIfShown then
      GG.RaidRostersTab:RefreshIfShown()
    end
    return
  end

  if payload.kind == "roster_hello" then
    local mine = Store()[guildKey]
    if not IsLive(mine) then return end
    local theirs = { publishedAt = tonumber(payload.have) or 0, publisher = tostring(payload.haveBy or "") }
    if not IsNewer(mine, theirs) then return end
    if pendingShare then return end
    local job = {}
    pendingShare = job
    C_Timer.After(math.random() * SHARE_SPREAD_SECONDS, function()
      if job.cancelled or pendingShare ~= job then return end
      pendingShare = nil
      local current = Store()[guildKey]
      if IsLive(current) then GG:SendRosterPayload({ kind = "roster_share", set = current }) end
    end)
    return
  end

  if payload.kind ~= "roster_publish" and payload.kind ~= "roster_share" then return end
  local set = RR.Sanitize(payload.set, now)
  if not set then return end
  if payload.kind == "roster_publish" then
    if RR.NameKey(set.publisher) ~= RR.NameKey(sender) then return end
  else
    set.relayedBy = sender
  end

  local current = Store()[guildKey]
  if pendingShare and current and not IsNewer(current, set) then
    pendingShare.cancelled = true
    pendingShare = nil
  end
  if IsLive(current) and not IsNewer(set, current) then return end
  if set.deleted and IsActive(current) and RR.NameKey(current.publisher) ~= RR.NameKey(set.publisher) then return end
  Store()[guildKey] = set
  if payload.kind == "roster_publish" and L then
    local who = Ambiguate and Ambiguate(sender, "short") or sender
    local text = set.deleted and L["RAID_ROSTER_DELETED"]:format(who)
      or set.auto and L["RAID_ROSTER_UPDATED"]
      or L["RAID_ROSTER_RECEIVED"]:format(who)
    print("|cff8B5CF6GG|r " .. text)
  end
  Changed()
end

local AUTO_CHECK_DELAY = HELLO_DELAY_SECONDS + SHARE_SPREAD_SECONDS + 4
local AUTO_RETRY_SECONDS, AUTO_MAX_TRIES = 5, 6

function RR:DefaultRaid()
  local best
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    if not best or (raid.numEncounters or 0) > (best.numEncounters or 0) then best = raid end
  end
  return best and best.instanceID
end

function RR.AutoRosterDecision(data, current, isMember, now)
  if type(data) ~= "table" or type(data.text) ~= "string" or type(data.hash) ~= "string" then return "no-data" end
  local changedAt = tonumber(data.changedAt) or 0
  if current and (current.expiresAt or 0) > now and (current.publishedAt or 0) >= changedAt then return "up-to-date" end
  local rosters = RR.Summarize(RR.ParseAll(data.text)).rosters
  if #rosters == 0 then return "empty" end
  local inGuild, total = 0, 0
  for _, g in ipairs(rosters) do
    for _, name in ipairs(g.members) do
      local m = isMember(RR.NameKey(name))
      if m == nil then return "wait" end
      total = total + 1
      if m then inGuild = inGuild + 1 end
    end
  end
  if inGuild * 2 < total then return "other-guild", nil, inGuild, total end
  return "publish", rosters, inGuild, total
end

local function GuildMemberKeys()
  if not GetNumGuildMembers or not GetGuildRosterInfo then return nil end
  local n = GetNumGuildMembers()
  if not n or n == 0 then return nil end
  local keys = {}
  for i = 1, n do
    local k = RR.NameKey((GetGuildRosterInfo(i)))
    if k then keys[k] = true end
  end
  return keys
end

local function Notify(msg) print("|cff8B5CF6GG|r " .. msg) end

function RR:CheckAutoRoster(try, force)
  local data = _G.GG_AutoRoster_Data
  if type(data) ~= "table" then
    if force and L then Notify(L["RR_AUTO_NO_DATA"]) end
    return
  end
  local guildKey = self:GuildKey()
  if not guildKey then return end
  local members = GuildMemberKeys()
  local isMember = function(k) if not members then return nil end return members[k] == true end
  local result, rosters, inGuild, total = RR.AutoRosterDecision(data, not force and Store()[guildKey] or nil, isMember, Now())
  if result == "wait" then
    try = (try or 0) + 1
    if try < AUTO_MAX_TRIES then
      self:RequestGuildRoster()
      C_Timer.After(AUTO_RETRY_SECONDS, function() RR:CheckAutoRoster(try, force) end)
      return
    end
  end
  if force and result == "empty" and L then Notify(L["RR_AUTO_EMPTY"]) end

  local raid = tonumber(data.raid)
  if not raid or RR:RaidName(raid) == "?" then raid = self:DefaultRaid() end
  local diff = tonumber(data.diff)
  if diff ~= 14 and diff ~= 15 and diff ~= 16 then diff = 16 end

  local prev = GGDB.autoRoster
  GGDB.autoRoster = { hash = data.hash, result = result, at = Now(), guild = guildKey, inGuild = inGuild, total = total }
  if result == "publish" and not raid then
    GGDB.autoRoster.result = "failed"
  elseif result == "publish" then
    local list = {}
    for _, g in ipairs(rosters) do
      list[#list + 1] = { label = g.label, raid = raid, diff = diff, members = g.members }
    end
    if self:Publish(list, true) then
      GGDB.autoRoster.publishedAt = Now()
      if L then Notify(L["RR_AUTO_PUBLISHED"]:format(#list, self:RaidName(raid), self:DifficultyName(diff))) end
    else
      GGDB.autoRoster.result = "failed"
    end
  elseif result == "other-guild" and L and (force or not (prev and prev.hash == data.hash and prev.result == "other-guild")) then
    Notify(L["RR_AUTO_OTHER_GUILD"]:format(inGuild, total))
  end
end

local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
loginFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
loginFrame:SetScript("OnEvent", function(self, event)
  if event == "GUILD_ROSTER_UPDATE" then
    guildDirty = true
    if GG.RaidRostersTab and GG.RaidRostersTab.RefreshIfShown then GG.RaidRostersTab:RefreshIfShown() end
    return
  end
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  C_Timer.After(HELLO_DELAY_SECONDS, function() RR:Hello() end)
  if _G.GG_AutoRoster_Data then
    RR:RequestGuildRoster()
    C_Timer.After(AUTO_CHECK_DELAY, function() RR:CheckAutoRoster() end)
  end
end)
