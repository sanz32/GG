local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

StaticPopupDialogs["GG_COPY_BATTLETAG"] = {
  text = L["OPTIONS_COPY_BATTLETAG_POPUP"],
  button1 = OKAY,
  hasEditBox = true,
  editBoxWidth = 240,
  OnShow = function(dialog)
    local editBox = dialog:GetEditBox()
    editBox:SetText((GGDB.account and GGDB.account.battleTag) or "")
    editBox:HighlightText()
    editBox:SetFocus()
  end,
  EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local DEFAULTS = {
  sections = {
    avatar = true,
    ilvl = true,
    rating = true,
    guild = true,
    account = true,
    keystone = true,
    vault = true,
    dungeons = true,
    raids = true,
    currencies = true,
    roster = true,
  },
  raidDifficulties = {
    [14] = true,
    [15] = true,
    [16] = true,
    [17] = true,
  },
  currencyVisibility = {},
  minLevel = GG.MIN_CHARACTER_LEVEL or 80,
  linkedAccountTags = {},
  linkedAccountHashes = {},
  accountLabelStyle = "cuenta",
  accountSlot = 1,
  windowScale = 1.0,
  windowOpacity = 1.0,
  maxVisibleCharacters = 10,
  lockWindow = false,
  closeWithEsc = true,
  openOn = "characters",
  accentMode = "default",
  accentColor = { 0.545, 0.361, 0.965 },
  layoutMode = "horizontal",
  theme = "cards",
  themeParts = {},
  announceInstanceReset = true,
  announceKeystoneParty = true,
  announceKeystoneGuild = false,
  announceTexts = {
    instanceReset = "",
    keystoneParty = "",
    keystoneGuild = "",
  },
  popupRosterCall = true,
  rosterCallStyle = "band",
  rosterCallSound = true,
  popupRosterCharacter = true,
  popupLockoutGroup = true,
  popupLockoutInstance = true,
}

local function ApplyDefaults(target, defaults)
  for key, value in pairs(defaults) do
    if type(value) == "table" then
      target[key] = target[key] or {}
      ApplyDefaults(target[key], value)
    elseif target[key] == nil then
      target[key] = value
    end
  end
end

local function ResetInPlace(target, defaults)
  for key in pairs(target) do target[key] = nil end
  for key, value in pairs(defaults) do target[key] = value end
end

function GG:ResetOptionsSection(category)
  local o = GGDB.options
  if category == "columns" then
    ResetInPlace(o.sections, DEFAULTS.sections)
    ResetInPlace(o.currencyVisibility, {})
  elseif category == "theme" then
    o.theme = DEFAULTS.theme
    o.themeParts = o.themeParts or {}
    ResetInPlace(o.themeParts, {})
  elseif category == "bosses" then
    ResetInPlace(o.raidDifficulties, DEFAULTS.raidDifficulties)
    o.bossIconStyle = nil
  elseif category == "window" then
    o.minimap = o.minimap or {}
    o.minimap.hide = false
    o.minimap.lock = false
    o.windowScale = DEFAULTS.windowScale
    o.windowOpacity = DEFAULTS.windowOpacity
    o.minLevel = DEFAULTS.minLevel
    o.layoutMode = DEFAULTS.layoutMode
    o.maxVisibleCharacters = DEFAULTS.maxVisibleCharacters
    o.lockWindow = DEFAULTS.lockWindow
    o.closeWithEsc = DEFAULTS.closeWithEsc
    o.openOn = DEFAULTS.openOn
    o.accentMode = DEFAULTS.accentMode
  elseif category == "announcements" then
    o.announceInstanceReset = DEFAULTS.announceInstanceReset
    o.announceKeystoneParty = DEFAULTS.announceKeystoneParty
    o.announceKeystoneGuild = DEFAULTS.announceKeystoneGuild
    ResetInPlace(o.announceTexts, DEFAULTS.announceTexts)
  elseif category == "popups" then
    o.popupRosterCall = DEFAULTS.popupRosterCall
    o.rosterCallStyle = DEFAULTS.rosterCallStyle
    o.rosterCallSound = DEFAULTS.rosterCallSound
    o.rosterCallPos = nil
    o.popupRosterCharacter = DEFAULTS.popupRosterCharacter
    o.popupLockoutGroup = DEFAULTS.popupLockoutGroup
    o.popupLockoutInstance = DEFAULTS.popupLockoutInstance
  end
end

function GG:InitOptions()
  GGDB.options = GGDB.options or {}
  ApplyDefaults(GGDB.options, DEFAULTS)

  if not GGDB.options.announceOptionsMigrated then
    GGDB.options.announceInstanceReset = true
    GGDB.options.announceKeystoneParty = true
    GGDB.options.announceOptionsMigrated = true
  end

  if GGDB.options.accountSlotManual == nil then
    GGDB.options.accountSlotManual = (GGDB.options.accountSlot or 1) ~= 1
  end

  if GG.Profile then GG.Profile.Init(GGDB, GGDB.options, GetServerTime()) end

  GG:ApplyStoredAccent()
end

function GG:GetMaxShownCharacters()
  local v = GGDB and GGDB.options and GGDB.options.maxVisibleCharacters
  if v == "all" then return 99 end
  return tonumber(v) or 10
end
