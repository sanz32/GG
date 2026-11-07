local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.Announce = {}

local CHAT_PREFIX = ">GG< "

local function GetGroupChannel()
  if IsInRaid() then return "RAID" end
  if IsInGroup() then return "PARTY" end
  return nil
end

local function IsChatRestricted()
  return GG:IsChatRestricted()
end

local function CanAnnounceReset()
  if not (GGDB and GGDB.options and GGDB.options.announceInstanceReset) then return nil end
  if IsInInstance() then return nil end
  if not UnitIsGroupLeader("player") then return nil end
  local channel = GetGroupChannel()
  if not channel then return nil end
  if IsChatRestricted() then return nil end
  return channel
end

hooksecurefunc("ResetInstances", function()
  local channel = CanAnnounceReset()
  if not channel then return end
  local customText = GGDB.options.announceTexts and GGDB.options.announceTexts.instanceReset
  local text = (customText and customText ~= "") and customText or L["ANNOUNCE_INSTANCES_RESET"]
  SendChatMessage(CHAT_PREFIX .. text, channel)
end)

function GG.Announce:FormatKeystoneText(template, keystoneLink)
  local ok, result = pcall(string.format, template, keystoneLink)
  if ok then return result end
  return template
end

local pendingKeystoneAnnounce

local function SendOrQueueAnnouncement(partyText, guildText, wantParty, wantGuild)
  if IsChatRestricted() then
    pendingKeystoneAnnounce = { partyText = partyText, guildText = guildText, wantParty = wantParty, wantGuild = wantGuild }
    return
  end
  pendingKeystoneAnnounce = nil
  if wantParty and IsInGroup() then
    SendChatMessage(partyText, "PARTY")
  end
  if wantGuild and IsInGuild() then
    SendChatMessage(guildText, "GUILD")
  end
end

function GG.Announce:FlushPendingKeystoneAnnounce()
  if not pendingKeystoneAnnounce then return end
  local pending = pendingKeystoneAnnounce
  SendOrQueueAnnouncement(pending.partyText, pending.guildText, pending.wantParty, pending.wantGuild)
end

local function KeystoneMemory()
  GGDB.keystoneAnnounce = GGDB.keystoneAnnounce or {}
  return GGDB.keystoneAnnounce
end

local function LastSeenKeystone()
  return KeystoneMemory()[GG:GetCharacterKey()]
end

local function RememberKeystone(keystone)
  if not keystone or not keystone.mapId or not keystone.level then return end
  KeystoneMemory()[GG:GetCharacterKey()] = {
    mapId = keystone.mapId,
    level = keystone.level,
    weekKey = GG:GetWeekKey(),
  }
end

local function RecordDecision(seen, current, announced, reason)
  GGDB.keystoneAnnounce = GGDB.keystoneAnnounce or {}
  GGDB.keystoneAnnounce.lastDecision = {
    at = time(),
    character = GG:GetCharacterKey(),
    seen = seen and ("%s +%d"):format(tostring(seen.mapId), seen.level or 0) or nil,
    current = current and ("%s +%d"):format(tostring(current.mapId), current.level or 0) or "?",
    announced = announced,
    reason = reason,
  }
end

function GG.Announce:GetKeystoneDiagnostics()
  return LastSeenKeystone(), (GGDB.keystoneAnnounce or {}).lastDecision
end

function GG.Announce:CheckNewKeystone(previous, current, dungeonName)
  if not current then return end
  if not (GGDB and GGDB.options) then return end

  local seen = LastSeenKeystone() or previous
  RememberKeystone(current)

  local wantParty = GGDB.options.announceKeystoneParty
  local wantGuild = GGDB.options.announceKeystoneGuild
  if not wantParty and not wantGuild then
    RecordDecision(seen, current, false, "off")
    return
  end

  local isNew
  if seen and seen.mapId and seen.level then
    isNew = seen.mapId ~= current.mapId or seen.level < current.level
    if not isNew and seen.weekKey and seen.weekKey ~= GG:GetWeekKey() then
      isNew = seen.level ~= current.level
    end
  else
    isNew = true
  end
  if not isNew then
    RecordDecision(seen, current, false, "same")
    return
  end

  local keystoneLink = GG:FindOwnedKeystoneItemLink()
    or ("%s +%d"):format(dungeonName or "?", current.level or 0)

  local texts = GGDB.options.announceTexts or {}
  local partyTemplate = (texts.keystoneParty and texts.keystoneParty ~= "") and texts.keystoneParty or L["ANNOUNCE_NEW_KEYSTONE"]
  local guildTemplate = (texts.keystoneGuild and texts.keystoneGuild ~= "") and texts.keystoneGuild or L["ANNOUNCE_NEW_KEYSTONE"]
  local partyText = CHAT_PREFIX .. GG.Announce:FormatKeystoneText(partyTemplate, keystoneLink)
  local guildText = CHAT_PREFIX .. GG.Announce:FormatKeystoneText(guildTemplate, keystoneLink)
  RecordDecision(seen, current, true,
    seen and "changed" or "first")
  SendOrQueueAnnouncement(partyText, guildText, wantParty, wantGuild)
end
