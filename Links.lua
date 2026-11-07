local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

local InsertLink = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
local OpenChat = (ChatFrameUtil and ChatFrameUtil.OpenChat) or ChatFrame_OpenChat
local AddMessageEventFilter = (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
  or ChatFrame_AddMessageEventFilter

GG.Links = {}

local LINK_PREFIX = "addon:GG:char:"
local MARKER_PATTERN = "%[GG:([^%s%]:]+):([^%s%]]+)%]"

local EVENT_TO_CHANNEL_HINT = {
  CHAT_MSG_PARTY = "GROUP", CHAT_MSG_PARTY_LEADER = "GROUP",
  CHAT_MSG_RAID = "GROUP", CHAT_MSG_RAID_LEADER = "GROUP", CHAT_MSG_RAID_WARNING = "GROUP",
  CHAT_MSG_INSTANCE_CHAT = "GROUP", CHAT_MSG_INSTANCE_CHAT_LEADER = "GROUP",
  CHAT_MSG_WHISPER = "WHISPER", CHAT_MSG_WHISPER_INFORM = "WHISPER",
  CHAT_MSG_SAY = "WHISPER", CHAT_MSG_YELL = "WHISPER",
  CHAT_MSG_GUILD = "GUILD", CHAT_MSG_OFFICER = "GUILD",
}

function GG.Links:InsertCharacterLink(datum)
  if not datum or not datum.key then return end

  if GG:IsAddonChatTextRestricted() then
    print("|cff8B5CF6GG|r " .. L["LINKS_CHAT_LOCKED"])
    return
  end

  local senderKey = GG:GetCharacterKey()
  local marker = "[GG:" .. datum.key .. ":" .. senderKey .. "]"

  if not InsertLink(marker) then
    OpenChat()
    InsertLink(marker)
  end
end

local FILTERED_EVENTS = {
  "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
  "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
  "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
  "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
  "CHAT_MSG_SAY", "CHAT_MSG_YELL",
}

local function RewriteMarkers(_, event, msg, ...)
  if not msg or not msg:find("[GG:", 1, true) then return false end

  local channelHint = EVENT_TO_CHANNEL_HINT[event] or "WHISPER"
  local newMsg = msg:gsub(MARKER_PATTERN, function(characterKey, senderKey)
    local displayName = characterKey:match("^([^%-]+)") or characterKey
    return "|cff8b5cf6|H" .. LINK_PREFIX .. characterKey .. ":" .. senderKey .. ":" .. channelHint .. "|h[" .. L["LINKS_CHAT_LABEL"]:format(displayName) .. "]|h|r"
  end)

  return false, newMsg, ...
end

for _, event in ipairs(FILTERED_EVENTS) do
  AddMessageEventFilter(event, RewriteMarkers)
end

hooksecurefunc("SetItemRef", function(link)
  if type(link) ~= "string" or link:sub(1, #LINK_PREFIX) ~= LINK_PREFIX then return end

  local rest = link:sub(#LINK_PREFIX + 1)
  local characterKey, senderKey, channelHint = rest:match("^([^:]+):([^:]+):(.+)$")
  if not characterKey or not senderKey then return end

  if GG.CharacterCard and GG.CharacterCard.RequestAndShow then
    GG.CharacterCard:RequestAndShow(characterKey, senderKey, channelHint)
  end
end)
