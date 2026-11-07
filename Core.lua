local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

_G[ADDON_NAME] = GG

GG.frame = CreateFrame("Frame")

local GetAddOnMetadataCompat = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

GG.VERSION = GetAddOnMetadataCompat(ADDON_NAME, "Version") or "?"

GG.latestKnownVersion = GG.VERSION

function GG:GetCharacterKey()
  local name = UnitName("player")
  local realm = GetRealmName():gsub("%s+", "")
  return name .. "-" .. realm
end

function GG:CompareVersions(a, b)
  if type(a) ~= "string" or type(b) ~= "string" then return 0 end
  local ai, bi = a:gmatch("%d+"), b:gmatch("%d+")
  while true do
    local an, bn = ai(), bi()
    if not an and not bn then return 0 end
    an, bn = tonumber(an) or 0, tonumber(bn) or 0
    if an ~= bn then return (an > bn) and 1 or -1 end
  end
end

local warnedAboutNewVersion = false

local NOISY_CURRENCY_UPDATE_INTERVAL = 1.0
local lastNoisyCurrencyUpdate = 0
local noisyCurrencyUpdatePending = false

local function ThrottledCurrenciesUpdate()
  local now = GetTime()
  if now - lastNoisyCurrencyUpdate >= NOISY_CURRENCY_UPDATE_INTERVAL then
    lastNoisyCurrencyUpdate = now
    GG.Currencies:Update()
  elseif not noisyCurrencyUpdatePending then
    noisyCurrencyUpdatePending = true
    C_Timer.After(NOISY_CURRENCY_UPDATE_INTERVAL, function()
      noisyCurrencyUpdatePending = false
      lastNoisyCurrencyUpdate = GetTime()
      GG.Currencies:Update()
    end)
  end
end

function GG:RGBToHex(color)
  return string.format("%02x%02x%02x",
    math.floor((color[1] or 0) * 255 + 0.5),
    math.floor((color[2] or 0) * 255 + 0.5),
    math.floor((color[3] or 0) * 255 + 0.5))
end

function GG:ColorizeText(text, themeColor)
  return ("|cff%s%s|r"):format(GG:RGBToHex(themeColor), tostring(text))
end

function GG:NoteObservedVersion(remoteVersion)
  if type(remoteVersion) ~= "string" or remoteVersion == "" then return end
  if GG:CompareVersions(remoteVersion, GG.latestKnownVersion) <= 0 then return end

  GG.latestKnownVersion = remoteVersion
  if GGDB then GGDB.latestKnownVersion = remoteVersion end

  if not warnedAboutNewVersion and GG:CompareVersions(remoteVersion, GG.VERSION) > 0 then
    warnedAboutNewVersion = true

    local Theme = GG.Theme
    local icon = (Theme and Theme.media and Theme.media.logoIcon)
      and ("|T" .. Theme.media.logoIcon .. ":14:14:0:0|t ") or ""
    local ggLabel = Theme and GG:ColorizeText("GG", Theme.accent) or "GG"
    local newVerText = Theme and GG:ColorizeText(remoteVersion, Theme.success) or remoteVersion
    local ownVerText = Theme and GG:ColorizeText(GG.VERSION, Theme.danger) or GG.VERSION
    print(("%s%s: " .. L["VERSION_UPDATE_CHAT"]):format(icon, ggLabel, newVerText, ownVerText))
  end

  if GG.RosterUI and GG.RosterUI.RefreshVersionBadge then
    GG.RosterUI:RefreshVersionBadge()
  end
  if GG.RosterUI and GG.RosterUI.MaybeShowVersionBanner then
    GG.RosterUI:MaybeShowVersionBanner()
  end
end

function GG:MinCharacterLevel()
  return (GGDB and GGDB.options and GGDB.options.minLevel) or GG.MIN_CHARACTER_LEVEL or 80
end

function GG:IsCharacterEligible()
  return UnitLevel("player") >= GG:MinCharacterLevel()
end

function GG:GetWeekKey()
  return tostring(math.floor(time() + C_DateAndTime.GetSecondsUntilWeeklyReset()))
end

function GG:CurrentWeekStart()
  return (tonumber(GG:GetWeekKey()) or 0) - 7 * 24 * 60 * 60
end

function GG:IsBeforeThisWeek(weekKey, ts)
  if weekKey then return weekKey ~= GG:GetWeekKey() end
  return ts ~= nil and ts < GG:CurrentWeekStart()
end

function GG:FindOwnedKeystoneItemLink()
  for bagID = 0, NUM_BAG_SLOTS do
    for slotID = 1, C_Container.GetContainerNumSlots(bagID) do
      local itemID = C_Container.GetContainerItemID(bagID, slotID)
      if itemID and C_Item.IsItemKeystoneByID(itemID) then
        return C_Container.GetContainerItemLink(bagID, slotID)
      end
    end
  end
  return nil
end

function GG:HashText(text)
  if type(text) ~= "string" or text == "" then return nil end
  local hash = 5381
  for i = 1, #text do
    hash = (hash * 33 + text:byte(i)) % 4294967296
  end
  return string.format("%08x", hash)
end

local cachedAccountHash

function GG:GetAccountHash()
  local _, battleTag = BNGetInfo()
  if type(battleTag) == "string" and battleTag ~= "" then
    cachedAccountHash = GG:HashText(battleTag)
    GGDB.account = GGDB.account or {}
    GGDB.account.battleTag = battleTag
    GGDB.account.hash = cachedAccountHash
  end
  return cachedAccountHash or (GGDB.account and GGDB.account.hash)
end

function GG:GetLinkedAccountHashMap()
  local map = {}
  for _, tag in ipairs((GGDB.options and GGDB.options.linkedAccountTags) or {}) do
    local hash = GG:HashText(tag)
    if hash then map[hash] = tag end
  end
  for hash in pairs((GGDB.options and GGDB.options.linkedAccountHashes) or {}) do
    if not map[hash] then map[hash] = "" end
  end
  return map
end

function GG:IsMyAccountHash(hash)
  if not hash then return false end
  local mine = GG:GetAccountHash()
  if mine and hash == mine then return true end
  return GG:GetLinkedAccountHashMap()[hash] ~= nil
end

function GG:GetAccountSlot()
  local options = GGDB.options
  if options and options.accountSlotManual then
    return options.accountSlot or 1
  end
  return (GGDB.account and GGDB.account.autoSlot) or 1
end

local GROUP_STATE_SETTLE_SECONDS = 10

local wasInRaid = false
local groupStateInitialized = false
local groupStateSilentUntil = 0

function GG:BeginGroupStateGrace()
  groupStateSilentUntil = GetTime() + GROUP_STATE_SETTLE_SECONDS
end

function GG:UpdateRaidGroupState()
  local isInRaid = IsInRaid() and true or false

  if GetTime() < groupStateSilentUntil then
    groupStateInitialized = true
    wasInRaid = isInRaid
    return
  end

  if not groupStateInitialized then
    groupStateInitialized = true
    wasInRaid = isInRaid
    return
  end

  if isInRaid == wasInRaid then return end
  wasInRaid = isInRaid

  if not isInRaid then
    if GG.GroupLockouts then GG.GroupLockouts:Reset() end
    return
  end

  if GG.GroupLockouts then
    GG.GroupLockouts:Reset()
    C_Timer.After(2, function()
      if IsInRaid() then GG.GroupLockouts:Request(true) end
    end)
  end

  if GG.LockoutAlert then GG.LockoutAlert:ShowGroupAlert() end
end

function GG:IsCharacterHidden(key)
  local hidden = GGDB.options and GGDB.options.hiddenCharacters
  return (hidden and hidden[key]) == true
end

function GG:SetCharacterHidden(key, hidden)
  if not key then return end
  GGDB.options = GGDB.options or {}
  GGDB.options.hiddenCharacters = GGDB.options.hiddenCharacters or {}
  GGDB.options.hiddenCharacters[key] = hidden and true or nil
end

function GG:CountHiddenCharacters()
  local count = 0
  for key in pairs((GGDB.options and GGDB.options.hiddenCharacters) or {}) do
    if GGDB.chars and GGDB.chars[key] then count = count + 1 end
  end
  return count
end

function GG:RebroadcastAllOwnCharacters()
  local slot = GG:GetAccountSlot()
  local manual = GGDB.options.accountSlotManual == true
  for key in pairs(GGDB.ownCharacters or {}) do
    local record = GGDB.chars[key]
    if record then
      record.accountSlot = slot
      record.slotManual = manual
      GG:BroadcastRecordNow(key)
    end
  end
end

local ownRebroadcastPending = false
function GG:ScheduleOwnRebroadcast()
  if ownRebroadcastPending then return end
  ownRebroadcastPending = true
  C_Timer.After(2, function()
    ownRebroadcastPending = false
    GG:RebroadcastAllOwnCharacters()
    if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
  end)
end

local ACCOUNT_LABEL_FORMATTERS = {
  wow = function(slot, tag) return L["ACCOUNT_LABEL_FMT_WOW"]:format(slot) end,
  cuenta = function(slot, tag) return L["ACCOUNT_LABEL_FMT_CUENTA"]:format(slot) end,
  alt = function(slot, tag) return L["ACCOUNT_LABEL_FMT_ALT"]:format(slot) end,
  number = function(slot, tag) return tostring(slot) end,
  battletag = function(slot, tag) return (tag and tag:match("^[^#]+")) or L["ACCOUNT_LABEL_FMT_CUENTA"]:format(slot) end,
}

function GG:FormatAccountLabel(slot, tag)
  slot = slot or 1
  local style = (GGDB.options and GGDB.options.accountLabelStyle) or "cuenta"
  local formatter = ACCOUNT_LABEL_FORMATTERS[style] or ACCOUNT_LABEL_FORMATTERS.cuenta
  return formatter(slot, tag)
end

function GG:GetCurrentRole()
  local index = GetSpecialization and GetSpecialization()
  if not index or not GetSpecializationInfo then return nil end
  local role = select(5, GetSpecializationInfo(index))
  if role == "TANK" or role == "HEALER" or role == "DAMAGER" then return role end
  return nil
end

function GG:GetCurrentSpecID()
  local index = GetSpecialization and GetSpecialization()
  if not index or not GetSpecializationInfo then return nil end
  local specID = GetSpecializationInfo(index)
  if type(specID) == "number" and specID > 0 then return specID end
  return nil
end

function GG:GetOrCreateCharacterRecord()
  local key = self:GetCharacterKey()
  GGDB.chars[key] = GGDB.chars[key] or {}
  local record = GGDB.chars[key]

  GGDB.ownCharacters = GGDB.ownCharacters or {}
  GGDB.ownCharacters[key] = true

  record.name = UnitName("player")
  record.realm = GetRealmName():gsub("%s+", "")
  record.class = select(2, UnitClass("player"))
  record.level = UnitLevel("player")
  record.role = GG:GetCurrentRole() or record.role
  record.specID = GG:GetCurrentSpecID() or record.specID
  record.raceID = select(3, UnitRace("player")) or record.raceID
  local faction = UnitFactionGroup("player")
  if faction == "Alliance" or faction == "Horde" then record.faction = faction end
  record.guid = UnitGUID("player")
  record.guild = (GetGuildInfo("player"))
  record.seasonId = GG.Season.SEASON_ID
  record.ts = math.max(GetServerTime(), record.ts or 0)
  record.isMain = (GGDB.options and GGDB.options.mainCharacterKey == key) or false

  local accountHash = GG:GetAccountHash()
  if accountHash then record.accountHash = accountHash end

  record.accountSlot = GG:GetAccountSlot()
  if GG.AccountSync then
    local account = GG.AccountSync:EnsureIdentity()
    record.installId = account.installId
    record.installCreatedAt = account.createdAt
  end
  record.slotManual = (GGDB.options and GGDB.options.accountSlotManual) == true

  record.addonVersion = GG.VERSION

  return record
end

local function OnAddonLoaded(name)
  if name ~= ADDON_NAME then return end

  GGDB = GGDB or {}
  GGDB.chars = GGDB.chars or {}
  GGDB.options = GGDB.options or {}

  if not GGDB.negativeZerosCleaned and GG.CleanNegativeZeros then
    GG:CleanNegativeZeros(GGDB.chars)
    GGDB.negativeZerosCleaned = true
  end

  GGDB.latestKnownVersion = GGDB.latestKnownVersion or GG.VERSION
  if GG:CompareVersions(GG.VERSION, GGDB.latestKnownVersion) > 0 then
    GGDB.latestKnownVersion = GG.VERSION
  end
  GG.latestKnownVersion = GGDB.latestKnownVersion

  GG:InitOptions()
  GG:InitMinimapIcon()
end

function GG:RequestGameData()
  C_MythicPlus.RequestCurrentAffixes()
  C_MythicPlus.RequestMapInfo()
  C_MythicPlus.RequestRewards()
  RequestRaidInfo()
end

local function OnPlayerLogin()
  GG.Lockouts:ActivatePendingRaids()
  if not GG:IsCharacterEligible() then return end

  GG:GetOrCreateCharacterRecord()
  GG:RequestGameData()
  GG.Vault:Update()
  GG.Lockouts:UpdateRaidInstances()
  GG.Currencies:ResetBountySessionTracking()
  GG.Currencies:Update()
  GG.Currencies:UpdateGold()
  GG.Equipment:Update()
  if GG.AccountSync then GG.AccountSync:ScheduleLoginHello() end
end

GG.frame:RegisterEvent("ADDON_LOADED")
GG.frame:RegisterEvent("PLAYER_LOGIN")
GG.frame:RegisterEvent("PLAYER_LEVEL_UP")
GG.frame:RegisterEvent("WEEKLY_REWARDS_UPDATE")
GG.frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")
GG.frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
GG.frame:RegisterEvent("BAG_UPDATE_DELAYED")
GG.frame:RegisterEvent("CHALLENGE_MODE_RESET")
GG.frame:RegisterEvent("MYTHIC_PLUS_NEW_WEEKLY_RECORD")
GG.frame:RegisterEvent("ITEM_CHANGED")
GG.frame:RegisterEvent("QUEST_LOG_UPDATE")
GG.frame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
GG.frame:RegisterEvent("BONUS_ROLL_RESULT")
GG.frame:RegisterEvent("CHAT_MSG_CURRENCY")
GG.frame:RegisterEvent("PLAYER_TRADE_CURRENCY")
GG.frame:RegisterEvent("POST_MATCH_CURRENCY_REWARD_UPDATE")
GG.frame:RegisterEvent("QUEST_CURRENCY_LOOT_RECEIVED")
GG.frame:RegisterEvent("SPELL_CONFIRMATION_PROMPT")
GG.frame:RegisterEvent("TRADE_CURRENCY_CHANGED")
GG.frame:RegisterEvent("TRADE_SKILL_CURRENCY_REWARD_RESULT")
GG.frame:RegisterEvent("PLAYER_MONEY")
GG.frame:RegisterEvent("BOSS_KILL")
GG.frame:RegisterEvent("ENCOUNTER_END")
GG.frame:RegisterEvent("UPDATE_INSTANCE_INFO")
GG.frame:RegisterEvent("LFG_UPDATE_RANDOM_INFO")
GG.frame:RegisterEvent("RAID_INSTANCE_WELCOME")
GG.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
GG.frame:RegisterEvent("GROUP_ROSTER_UPDATE")
GG.frame:RegisterEvent("LFG_LOCK_INFO_RECEIVED")
GG.frame:RegisterEvent("CHAT_MSG_LOOT")
GG.frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
GG.frame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
GG.frame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
GG.frame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
GG.frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
GG.frame:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
GG.frame:RegisterUnitEvent("UNIT_AURA", "player")
GG.frame:RegisterEvent("PLAYER_REGEN_ENABLED")

GG.frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    OnAddonLoaded(...)
    return
  end

  if not GGDB then return end

  if event == "PLAYER_LEVEL_UP" then
    local newLevel = tonumber((...))
    local minLevel = GG:MinCharacterLevel()
    if newLevel and newLevel >= minLevel and newLevel - 1 < minLevel then
      C_Timer.After(1, function()
        if GG:IsCharacterEligible() then OnPlayerLogin() end
      end)
    elseif newLevel and newLevel > minLevel then
      C_Timer.After(1, function()
        GG:GetOrCreateCharacterRecord()
        GG:RequestBroadcast()
      end)
    end
    return
  end

  if not GG:IsCharacterEligible() then return end

  if event == "PLAYER_LOGIN" then
    OnPlayerLogin()
  elseif event == "WEEKLY_REWARDS_UPDATE" then
    GG.Vault:Update()
  elseif event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "BAG_UPDATE_DELAYED"
    or event == "CHALLENGE_MODE_RESET" or event == "MYTHIC_PLUS_NEW_WEEKLY_RECORD"
    or event == "ITEM_CHANGED" then
    if event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "ITEM_CHANGED" then
      GG.Vault:Update()
    end
    if event == "BAG_UPDATE_DELAYED" or event == "ITEM_CHANGED" then
      GG.Currencies:Update()
    end
    GG.Vault:UpdateMythicPlus()

    for _, delay in ipairs({ 1, 3 }) do
      C_Timer.After(delay, function()
        if event == "CHALLENGE_MODE_MAPS_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "ITEM_CHANGED" then
          GG.Vault:Update()
        end
        GG.Vault:UpdateMythicPlus()
      end)
    end
  elseif event == "GROUP_ROSTER_UPDATE" then
    GG:UpdateRaidGroupState()
  elseif event == "PLAYER_ENTERING_WORLD" then
    GG:BeginGroupStateGrace()
    GG:UpdateRaidGroupState()
    if GG.LockoutAlert then
      GG.LockoutAlert:OnEnteringWorld()
      C_Timer.After(5, function()
        if GG.LockoutAlert then GG.LockoutAlert:OnEnteringWorld() end
      end)
    end
  elseif event == "CHALLENGE_MODE_COMPLETED" or event == "ENCOUNTER_END" or event == "RAID_INSTANCE_WELCOME"
    or event == "LFG_LOCK_INFO_RECEIVED" then
    if event == "ENCOUNTER_END" then
      pcall(GG.BonusRoll.OnEncounterEnd, GG.BonusRoll, ...)
    elseif event == "CHALLENGE_MODE_COMPLETED" then
      pcall(GG.BonusRoll.OnChallengeCompleted, GG.BonusRoll)
    end
    GG:RequestGameData()
    if GG.LockoutAlert then GG.LockoutAlert:OnEnteringWorld() end
    GG.Vault:UpdateMythicPlus()
  elseif event == "CURRENCY_DISPLAY_UPDATE" or event == "BONUS_ROLL_RESULT" or event == "CHAT_MSG_CURRENCY"
    or event == "PLAYER_TRADE_CURRENCY" or event == "POST_MATCH_CURRENCY_REWARD_UPDATE"
    or event == "QUEST_CURRENCY_LOOT_RECEIVED" or event == "SPELL_CONFIRMATION_PROMPT"
    or event == "TRADE_CURRENCY_CHANGED" or event == "TRADE_SKILL_CURRENCY_REWARD_RESULT" then
    if event == "SPELL_CONFIRMATION_PROMPT" then
      pcall(GG.BonusRoll.OnConfirmationPrompt, GG.BonusRoll, ...)
    elseif event == "BONUS_ROLL_RESULT" then
      local ok, err = pcall(GG.BonusRoll.OnResult, GG.BonusRoll, ...)
      if not ok then geterrorhandler()(("GG: BonusRoll failed: %s"):format(tostring(err))) end
    end
    GG.Currencies:Update()
  elseif event == "QUEST_LOG_UPDATE" then
    ThrottledCurrenciesUpdate()
  elseif event == "UNIT_AURA" then
    local _, updateInfo = ...
    GG.Currencies:OnBountyAuraUpdate(updateInfo)
    ThrottledCurrenciesUpdate()
  elseif event == "PLAYER_REGEN_ENABLED" then
    ThrottledCurrenciesUpdate()
  elseif event == "PLAYER_MONEY" then
    GG.Currencies:UpdateGold()
  elseif event == "BOSS_KILL" or event == "UPDATE_INSTANCE_INFO" or event == "LFG_UPDATE_RANDOM_INFO" then
    GG.Lockouts:UpdateRaidInstances(event == "UPDATE_INSTANCE_INFO")
    if event == "BOSS_KILL" and IsInGroup() then
      GG:RequestGameData()
      C_Timer.After(3, function()
        if IsInGroup() then GG:SendLockoutState() end
      end)
    end
  elseif event == "CHAT_MSG_LOOT" then
    GG.Vault:OnLootMessage((...))
  elseif event == "PLAYER_EQUIPMENT_CHANGED" then
    GG.Equipment:Update()
  elseif event == "PLAYER_AVG_ITEM_LEVEL_UPDATE" then
    GG.Equipment:UpdateItemLevel()
    GG.Equipment:ScheduleRefresh(event)
  elseif event == "UNIT_INVENTORY_CHANGED" then
    GG.Equipment:ScheduleRefresh(event)
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    local record = GG:GetOrCreateCharacterRecord()
    if record.role then
      GG:RequestBroadcast()
      if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
    end
  elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
    if GG.Announce and GG.Announce.FlushPendingKeystoneAnnounce then
      GG.Announce:FlushPendingKeystoneAnnounce()
    end
    GG.Vault:UpdateMythicPlus()
    GG.Vault:Update()
  elseif event == "ADDON_RESTRICTION_STATE_CHANGED" then
    local state = select(2, ...)
    if state == Enum.AddOnRestrictionState.Inactive and GG.Announce and GG.Announce.FlushPendingKeystoneAnnounce then
      GG.Announce:FlushPendingKeystoneAnnounce()
    end
  end
end)

SLASH_GG1 = "/gg"
SlashCmdList["GG"] = function()
  if GG.RosterUI and GG.RosterUI.Toggle then
    GG.RosterUI:Toggle()
  end
end

SLASH_GGROSTER1 = "/ggroster"
SlashCmdList["GGROSTER"] = function(arg)
  if arg and arg:lower():match("^%s*auto%s*$") then
    if GG.RaidRosters then GG.RaidRosters:CheckAutoRoster(nil, true) end
    return
  end
  if arg and arg:lower():match("^%s*delete%s*$") then
    if GG.RaidRosters then print("|cff8B5CF6GG|r " .. GG.RaidRosters:WhoCanDeleteText()) end
    return
  end
  local test = arg and arg:lower():match("^%s*test%s*(%a*)%s*$")
  if test then
    local L = LibStub("AceLocale-3.0"):GetLocale("GG")
    if test == "off" then
      GG.RaidGroups:SimulateForming(nil)
      print("|cff8B5CF6GG|r " .. L["RG_TEST_OFF"])
      return
    end
    local roster
    for _, t in ipairs(GG.RaidRosters:TagsFor(GG:GetCharacterKey(), GG:GetOrCreateCharacterRecord())) do
      if t.set == GG.RaidRosters:GetCurrentSet() then roster = t.roster break end
    end
    local leader = GG.AccountSync and GG.AccountSync:LiveSiblingNames()[1]
    if not roster then print("|cff8B5CF6GG|r " .. L["RG_TEST_NO_ROSTER"]) return end
    if not leader then print("|cff8B5CF6GG|r " .. L["RG_TEST_NO_SIBLING"]) return end
    if GG.RaidGroups:SimulateForming(roster, leader) then
      print("|cff8B5CF6GG|r " .. L["RG_TEST_ON"]:format(roster.label, leader))
    else
      print("|cff8B5CF6GG|r " .. L["RG_TEST_NO_ROSTER"])
    end
    return
  end
  if GG.RosterUI and GG.RosterUI.OpenRosters then GG.RosterUI:OpenRosters() end
end

SLASH_GGBONUS1 = "/ggbonus"
SlashCmdList["GGBONUS"] = function(arg)
  local function say(msg) print("|cff8B5CF6GG|r " .. msg) end
  if arg == "demo" then
    local on = GG.BonusRoll:ToggleDemo()
    say(on and L["DIAG_BONUS_DEMO_ON"] or L["DIAG_BONUS_DEMO_OFF"])
    if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
    return
  end
  if arg == "art" then
    local kits = GG.BonusRoll:JourneyKits()
    for _, j in ipairs(kits.list or {}) do say(("journey %d · %s · kit=%s"):format(j.id, tostring(j.name), j.kit)) end
    say(("delve -> %s · prey -> %s"):format(tostring(kits.delve), tostring(kits.prey)))
    return
  end
  local entry = GG.BonusRoll:LastEntry()
  if not entry then
    say(L["DIAG_BONUS_NONE"])
    return
  end
  say(L["DIAG_BONUS_LAST"]:format(entry.itemLink or entry.kind or "?", entry.at and date("%d/%m %H:%M", entry.at) or "?"))
  local keys = {}
  for k in pairs(entry) do if k ~= "raw" then table.insert(keys, k) end end
  table.sort(keys)
  for _, k in ipairs(keys) do say(("  %s = %s"):format(k, tostring(entry[k]))) end
  for k, v in pairs(entry.raw or {}) do say(("  raw.%s = %s"):format(k, tostring(v))) end
end

SLASH_GGRAID1 = "/ggraid"
SlashCmdList["GGRAID"] = function(arg)
  local function say(msg) print("|cff8B5CF6GG|r " .. msg) end

  if arg == "test" then
    if GG.LockoutAlert then GG.LockoutAlert:ShowGroupAlert(true) end
    say(L["DIAG_RAID_TEST"])
    return
  end

  if arg == "net" then
    local GL = GG.GroupLockouts
    GL.trace = not GL.trace
    say(GL.trace and L["DIAG_NET_TRACE_ON"] or L["DIAG_NET_TRACE_OFF"])

    local lines = GL:DebugLines()
    if not lines then
      say(L["DIAG_NET_NOT_IN_RAID"])
      return
    end
    say(L["DIAG_NET_MEMBERS"]:format(#lines))
    for _, line in ipairs(lines) do print(line) end
    if GL.trace then
      say(L["DIAG_NET_ASKING"])
      GL:Request(true)
    end
    return
  end

  if arg == "kithix" then
    local added = GG.Lockouts:ForcePendingRaidsPreview()
    if added == 0 then
      say(L["DIAG_PENDING_NONE"])
      return
    end
    say(L["DIAG_PENDING_PREVIEW"])
    if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
    if GG.RaidTab then GG.RaidTab:Refresh() end
    return
  end

  if arg == "demo" then
    local on = GG.GroupLockouts:ToggleDemo()
    say(on and L["DIAG_RAID_DEMO_ON"] or L["DIAG_RAID_DEMO_OFF"])
    if GG.RosterUI and GG.RosterUI.RefreshGroupLockouts then
      GG.RosterUI:RefreshGroupLockouts()
    end
    if GG.RaidTab then GG.RaidTab:Refresh() end
    return
  end

  local name, instanceType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
  say(L["DIAG_RAID_ZONE"]:format(
    tostring(name), tostring(instanceType), tostring(instanceID),
    tostring(difficultyName), tostring(difficultyID)))

  local ids = {}
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    table.insert(ids, ("%s=%s"):format(raid.name, tostring(raid.instanceID)))
  end
  say(L["DIAG_RAID_SEASON"] .. table.concat(ids, ", "))
  local pending = {}
  for _, raid in ipairs(GG.Season.PENDING_RAIDS or {}) do
    table.insert(pending, ("%s=%s"):format(raid.name, tostring(raid.instanceID)))
  end
  if #pending > 0 then
    say("|cffFFD100" .. L["DIAG_RAID_PENDING"] .. "|r " .. table.concat(pending, ", "))
  end

  if GG.LockoutAlert then
    local raidDef, reason, baseDifficulty = GG.LockoutAlert:ResolveCurrentRaid()
    if raidDef and not GG.LockoutAlert:AppliesToDifficulty(baseDifficulty) then
      say(L["DIAG_RAID_MATCH_NO_BANNER"]:format(raidDef.name))
    elseif raidDef then
      say(L["DIAG_RAID_MATCH"]:format(raidDef.name))
    else
      say(L["DIAG_RAID_NO_BANNER"]:format(tostring(reason)))
    end
  end

  say(L["DIAG_RAID_GROUP"]:format(tostring(IsInRaid()), GetNumGroupMembers() or 0))
  say(L["DIAG_RAID_HINT"])
end

SLASH_GGKEY1 = "/ggkey"
SlashCmdList["GGKEY"] = function()
  local function say(msg) print("|cff8B5CF6GG|r " .. msg) end

  local mapId = C_MythicPlus.GetOwnedKeystoneMapID()
  local level = C_MythicPlus.GetOwnedKeystoneLevel()
  say(L["DIAG_KEY_CLIENT"]:format(tostring(mapId), tostring(level)))
  say(L["DIAG_KEY_BAG_LINK"]:format(GG:FindOwnedKeystoneItemLink() or ("|cffFF6B6B" .. L["DIAG_NOT_FOUND"] .. "|r")))

  local record = GG:GetOrCreateCharacterRecord()
  local saved = record.mythicplus and record.mythicplus.keystone
  say(L["DIAG_KEY_SAVED"]:format(
    saved and ("%s +%d"):format(tostring(saved.mapId), saved.level or 0) or ("|cffFF6B6B" .. L["DIAG_NONE"] .. "|r")))

  local seen, decision = GG.Announce:GetKeystoneDiagnostics()
  say(L["DIAG_KEY_MEMORY"]:format(
    seen and ("%s +%d"):format(tostring(seen.mapId), seen.level or 0) or ("|cffFFD100" .. L["DIAG_EMPTY"] .. "|r")))

  if decision then
    local reasons = {
      off = L["DIAG_KEY_REASON_OFF"], same = L["DIAG_KEY_REASON_SAME"],
      changed = L["DIAG_KEY_REASON_CHANGED"], first = L["DIAG_KEY_REASON_FIRST"],
    }
    say(L["DIAG_KEY_DECISION"]:format(
      date("%d/%m %H:%M", decision.at), decision.character or "?",
      decision.announced and "FF6B6B" or "4ADE80",
      decision.announced and L["DIAG_KEY_ANNOUNCED"] or L["DIAG_KEY_NOT_ANNOUNCED"],
      reasons[decision.reason] or tostring(decision.reason or "?")))
    say(L["DIAG_KEY_COMPARED"]:format(decision.current or "?", decision.seen or L["DIAG_KEY_NO_MEMORY"]))
  else
    say(L["DIAG_KEY_NEVER"])
  end
end

SLASH_GGCONFIG1 = "/ggconfig"
SlashCmdList["GGCONFIG"] = function()
  if GG.RosterUI and GG.RosterUI.OpenSettings then
    GG.RosterUI:OpenSettings()
  end
end

SLASH_GGCHAT1 = "/ggchat"
SlashCmdList["GGCHAT"] = function()
  local function say(msg) print("|cff8B5CF6GG|r " .. msg) end
  local function flag(active)
    if active == nil then return "|cff808080" .. L["DIAG_MISSING"] .. "|r" end
    return active and ("|cffFF6B6B" .. L["DIAG_YES"] .. "|r") or ("|cff4ADE80" .. L["DIAG_NO"] .. "|r")
  end

  local inInstance, instanceType = IsInInstance()
  local difficultyId = select(3, GetInstanceInfo())
  say(L["DIAG_CHAT_CONTEXT"]:format(
    inInstance and L["DIAG_CHAT_IN_INSTANCE"] or L["DIAG_CHAT_OUTSIDE"],
    tostring(instanceType), tostring(difficultyId)))

  say(("InChatMessagingLockdown: %s"):format(flag(C_ChatInfo.InChatMessagingLockdown())))

  if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
    local types = {}
    for name, value in pairs(Enum.AddOnRestrictionType) do
      table.insert(types, { name = name, value = value })
    end
    table.sort(types, function(a, b) return a.value < b.value end)
    for _, entry in ipairs(types) do
      say(L["DIAG_CHAT_RESTRICTION"]:format(
        entry.name, tostring(entry.value),
        flag(C_RestrictedActions.IsAddOnRestrictionActive(entry.value) == true)))
    end
  else
    say(L["DIAG_CHAT_NO_API"])
  end

  local atVault = C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType
    and C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.WeeklyRewards)
  say(L["DIAG_CHAT_VAULT_OPEN"]:format(flag(atVault == true)))

  local function can(blocked)
    return blocked and ("|cffFF6B6B" .. L["DIAG_NO"] .. "|r") or ("|cff4ADE80" .. L["DIAG_YES"] .. "|r")
  end
  say(L["DIAG_CHAT_CAN_SEND"]:format(can(GG:IsChatRestricted())))
  say(L["DIAG_CHAT_CAN_TYPE"]:format(can(GG:IsAddonChatTextRestricted())))
end
