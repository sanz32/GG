local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

local CONST = {}

GG.RosterUI = {}

local Theme

CONST.ROW_HEIGHT = 72
CONST.ROW_HEIGHT_BASE = 72
CONST.ROW_HEIGHT_TAGGED = 88
CONST.ROW_GAP = 6
CONST.LIST_CARD_LEFT = 8
CONST.LIST_CARD_RIGHT = 8
CONST.LIST_ACCOUNT_INSET = CONST.LIST_CARD_LEFT + 4
CONST.CHARACTER_COL_MIN = 60
CONST.CHARACTER_COL_MAX = 260
CONST.TITLEBAR_HEIGHT = 28
CONST.RAIL_HEIGHT = 36
CONST.NAV_TAB_HEIGHT = 30
CONST.CTX_HEIGHT = 34
CONST.NAV_BG = { 0.063, 0.071, 0.090, 1 }
CONST.MIN_WINDOW_WIDTH = 1000
CONST.RAID_WINDOW_WIDTH = 1100
CONST.ROSTERS_WINDOW_HEIGHT = 600
CONST.MIN_TAB_WINDOW_WIDTH = 760
CONST.MIN_WINDOW_HEIGHT = 520
CONST.MIN_CHARACTER_SLOTS = 4
CONST.COMPACT_BAR_WIDTH = 900
CONST.HEADER_HEIGHT = 40
CONST.FOOTER_HEIGHT = 24
CONST.SCROLLBAR_WIDTH = 16
CONST.AVATAR_SIZE = 28
CONST.AVATAR_GAP = 9
CONST.AVATAR_Y_OFFSET = 9
CONST.CLASS_ICON_ATLAS_TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

CONST.DEFAULT_WIDTH = 1090
CONST.DEFAULT_HEIGHT = 620
CONST.WINDOW_CONTENT_GUTTER = 32
CONST.MIN_HEIGHT = 320
CONST.MAX_RAID_SEGMENTS = 16
CONST.MAX_CURRENCY_SLOTS = GG.Currencies:MaxSlots()
CONST.CURRENCY_COLUMNS = math.ceil(CONST.MAX_CURRENCY_SLOTS / 2)
CONST.CURRENCY_SLOT_WIDTH = 46
CONST.CURRENCY_SLOT_HEIGHT = 17

CONST.DELVES_ICON_SIZE = 22
CONST.BOUNTY_ICON_SIZE = CONST.DELVES_ICON_SIZE
CONST.BOUNTY_ICON_GAP = 12
CONST.QUESTS_CURRENCY_GAP = 22

CONST.NEMESIS_ICON_SIZE = CONST.DELVES_ICON_SIZE
CONST.NEMESIS_ICON_GAP = 8

CONST.QUEST_DOT_COUNT = 2
CONST.QUEST_DOT_SIZE = 6
CONST.QUEST_DOT_BORDER_SIZE = 9
CONST.QUEST_DOT_STEP = 9
CONST.QUEST_DOT_CENTER_Y = 5
CONST.QUEST_DOT_ON = { 0.25, 1, 0.4, 1 }
CONST.DELVES_CHECK_SIZE = 7
CONST.DELVES_CHECK_OFFSET = -3

CONST.VAULT_CARD_HEADER_HEIGHT = 66
CONST.VAULT_CARD_PADDING = 12
CONST.VAULT_CARD_WIDTH = GG.VaultGrid.CONTENT_WIDTH + CONST.VAULT_CARD_PADDING * 2
CONST.VAULT_CARD_HEIGHT = CONST.VAULT_CARD_HEADER_HEIGHT + GG.VaultGrid.CONTENT_HEIGHT + CONST.VAULT_CARD_PADDING * 2
CONST.VAULT_CARD_GAP = 12
CONST.VAULT_GRID_MARGIN = CONST.VAULT_CARD_GAP
CONST.VAULT_CARD_POOL_SIZE = 30

CONST.COLUMNS = {
  { key = "account",    labelKey = "ROSTER_COL_ACCOUNT",    optionKey = "account" },
  { key = "character",  labelKey = "ROSTER_COL_CHARACTER",  width = 170, sortable = true },
  { key = "ilvl",       labelKey = "ROSTER_COL_ILVL",       width = 78,  sortable = true, optionKey = "ilvl" },
  { key = "rating",     labelKey = "ROSTER_COL_RATING",     width = 70,  sortable = true, optionKey = "rating" },
  { key = "keystone",   labelKey = "ROSTER_COL_KEYSTONE",   width = 112, optionKey = "keystone" },
  { key = "vault",      labelKey = "ROSTER_COL_VAULT",      width = 130, optionKey = "vault" },
  { key = "raid",       labelKey = "ROSTER_COL_RAID",       width = 196, optionKey = "raids" },
  { key = "currencies", labelKey = "ROSTER_COL_CURRENCIES", width = nil, minWidth = CONST.BOUNTY_ICON_SIZE + CONST.BOUNTY_ICON_GAP + 3 * (CONST.NEMESIS_ICON_SIZE + CONST.NEMESIS_ICON_GAP) + CONST.QUESTS_CURRENCY_GAP + CONST.CURRENCY_COLUMNS * CONST.CURRENCY_SLOT_WIDTH, optionKey = "currencies" },
}
CONST.FLEX_COLUMN_KEY = "currencies"

CONST.COLUMN_GROUPS = {
  { labelKey = "ROSTER_GROUP_CHARACTER", first = "account", last = "keystone" },
  { labelKey = "ROSTER_GROUP_WEEKLY", first = "vault", last = "raid" },
  { labelKey = "ROSTER_GROUP_QUESTS_CURRENCIES", first = "currencies", last = "currencies" },
}

CONST.ACCOUNT_COLORS = {
  { 0.655, 0.545, 0.980 },
  { 0.208, 0.816, 0.729 },
  { 0.910, 0.722, 0.361 },
  { 0.310, 0.702, 1.000 },
  { 1.000, 0.420, 0.420 },
}

CONST.ZERO_COLOR = { 0.36, 0.38, 0.45, 1 }
CONST.CELL_PADDING = 10

CONST.FLEX_COLUMN_MIN_WIDTH = 160
for _, col in ipairs(CONST.COLUMNS) do
  if col.key == CONST.FLEX_COLUMN_KEY then CONST.FLEX_COLUMN_MIN_WIDTH = col.minWidth or 160 end
end

local CurrencyGrid = {
  ROWS = 2,
  CELL_WIDTH = 24,
  BLOCK_GAP = 21,
  PER_ROW = 5,
  CELL_HEIGHT = 31,
  ICON_SIZE = 16,
  ICON_TOP = 1,
  TEXT_GAP = 3,
  RULE_POOL = 5,
  CAP_COLOR = { 1, 0.624, 0.247, 1 },
}

function CurrencyGrid.Layouts()
  local signature = GG.Currencies:VisibilitySignature()
  if CurrencyGrid.signature ~= signature then
    CurrencyGrid.signature = signature
    CurrencyGrid.stacked = GG.Currencies:StackedLayout(CurrencyGrid.PER_ROW)
    CurrencyGrid.sideBySide = GG.Currencies:SideBySideLayout(CurrencyGrid.ROWS)
  end
  return CurrencyGrid.stacked, CurrencyGrid.sideBySide
end

local QUEST_ICON_ORDER = { "nemesis", "keystone", "kindojan" }
local QUEST_ICON_VISIBLE = {
  nemesis = function() return GG.Currencies:IsVisible(GG.Currencies.NEMESIS_KEY) end,
  keystone = function() return GG.Currencies:IsVisible(GG.Currencies.KEYSTONE_KEY) end,
  kindojan = function() return GG.Currencies:IsVisible(GG.Currencies.KINDOJAN_KEY) end,
}

function CurrencyGrid.NemesisVisible()
  return QUEST_ICON_VISIBLE.nemesis()
end

function CurrencyGrid.KeystoneVisible()
  return QUEST_ICON_VISIBLE.keystone()
end

function CurrencyGrid.QuestIconCount()
  local n = 0
  for _, key in ipairs(QUEST_ICON_ORDER) do
    if QUEST_ICON_VISIBLE[key]() then n = n + 1 end
  end
  return n
end

function CurrencyGrid.QuestsVisible()
  return CurrencyGrid.QuestIconCount() > 0
end

function CurrencyGrid.Width()
  local _, layout = CurrencyGrid.Layouts()
  local blocks = #layout.blockColumns
  if blocks == 0 then return CurrencyGrid.CELL_WIDTH end
  local columns = 0
  for _, count in ipairs(layout.blockColumns) do columns = columns + count end
  return columns * CurrencyGrid.CELL_WIDTH + (blocks - 1) * CurrencyGrid.BLOCK_GAP
end

function CurrencyGrid.BlockOffsets()
  local _, layout = CurrencyGrid.Layouts()
  local offsets, x = {}, 0
  for block, columns in ipairs(layout.blockColumns) do
    offsets[block] = x
    x = x + columns * CurrencyGrid.CELL_WIDTH + CurrencyGrid.BLOCK_GAP
  end
  return offsets
end

function CurrencyGrid.NemesisLead()
  return CurrencyGrid.QuestIconCount() * (CONST.NEMESIS_ICON_SIZE + CONST.NEMESIS_ICON_GAP)
end

function CurrencyGrid.DelvesLead()
  local lead = CurrencyGrid.NemesisLead()
  if lead > 0 then lead = lead + CONST.QUESTS_CURRENCY_GAP end
  return lead
end

function CurrencyGrid.FlexMinWidth()
  return math.min(CONST.FLEX_COLUMN_MIN_WIDTH, CurrencyGrid.DelvesLead() + CurrencyGrid.Width())
end

local function IsSectionVisible(optionKey)
  if not optionKey then return true end
  local sections = GGDB and GGDB.options and GGDB.options.sections
  return not (sections and sections[optionKey] == false)
end

local function IsRaidDifficultyVisible(difficultyID)
  local prefs = GGDB and GGDB.options and GGDB.options.raidDifficulties
  return not (prefs and prefs[difficultyID] == false)
end

local function ApplyBackdrop(f, bg, border, edgeSize)
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = edgeSize or 1,
  })
  f:SetBackdropColor(unpack(bg))
  if border then f:SetBackdropBorderColor(unpack(border)) end
end

local function CreateLabel(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size or 12, "")
  fs:SetTextColor(unpack(color or Theme.textPrimary))
  fs:SetWordWrap(false)
  fs:SetJustifyH("LEFT")
  return fs
end

local function CreateMonoLabel(parent, size, color, bold)
  return CreateLabel(parent, size, color, bold)
end

local dimOverlays = {}

local function CreateDimOverlay(parent)
  local overlay = CreateFrame("Frame", nil, parent)
  overlay:SetAllPoints(parent)
  overlay:EnableMouse(true)
  overlay:SetFrameLevel(parent:GetFrameLevel() + 50)
  local tex = overlay:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints()
  tex:SetColorTexture(0, 0, 0, 0.72)
  overlay:Hide()
  table.insert(dimOverlays, overlay)
  return overlay
end

CONST.DUNGEON_ABBR_STOPWORDS = {
  ["the"] = true, ["of"] = true, ["and"] = true, ["in"] = true, ["at"] = true, ["to"] = true,
  ["de"] = true, ["del"] = true, ["la"] = true, ["el"] = true, ["los"] = true, ["las"] = true,
  ["y"] = true, ["en"] = true,
}

local function AbbreviateDungeonName(challengeModeID, name)
  local curated = challengeModeID and GG.Season.DUNGEON_ABBR and GG.Season.DUNGEON_ABBR[challengeModeID]
  if curated then return curated end

  if not name or name == "" then return "?" end
  local letters = {}
  for word in name:gmatch("%a+") do
    if not CONST.DUNGEON_ABBR_STOPWORDS[word:lower()] then
      table.insert(letters, word:sub(1, 1):upper())
    end
  end
  if #letters == 0 then
    return name:sub(1, 3):upper()
  end
  return table.concat(letters)
end

local function FormatIlvl(ilvl)
  ilvl = ilvl or 0
  local rounded = tonumber(("%.2f"):format(ilvl))
  if rounded == math.floor(rounded) then
    return tostring(math.floor(rounded))
  end
  return ("%.2f"):format(rounded)
end

local measureFS

local function AccountTextFontSize(style)
  return (style == "number") and 20 or 12
end

local function GetAccountColumnWidth()
  if not (GGDB and GGDB.options and Theme) then return 60 end

  if not measureFS then
    measureFS = UIParent:CreateFontString(nil, "OVERLAY")
  end

  measureFS:SetFont(Theme.font, 9.5, "")
  measureFS:SetText(L["ROSTER_COL_ACCOUNT"])
  local widest = measureFS:GetStringWidth()

  local style = GGDB.options.accountLabelStyle or "cuenta"
  measureFS:SetFont(Theme.font, AccountTextFontSize(style), "")
  if style == "battletag" then
    for _, row in ipairs(GG.Roster:BuildRows()) do
      measureFS:SetText(row.accountLabel or "")
      widest = math.max(widest, measureFS:GetStringWidth())
    end
  else
    for slot = 1, 9 do
      measureFS:SetText(GG:FormatAccountLabel(slot, nil))
      widest = math.max(widest, measureFS:GetStringWidth())
    end
  end

  return widest + CONST.CELL_PADDING * 2 + CONST.LIST_ACCOUNT_INSET
end

local function GetCharacterColumnWidth()
  if not (GGDB and GGDB.options and Theme) then return 170 end
  if not measureFS then measureFS = UIParent:CreateFontString(nil, "OVERLAY") end
  local function Measure(text, size)
    measureFS:SetFont(Theme.font, size, "")
    measureFS:SetText(text or "")
    return measureFS:GetStringWidth()
  end
  local badge = Measure(L["ROSTER_TAG_MAIN"], 10) + 12 + 6
  local nameClock = IsSectionVisible("avatar") and 0 or 14
  local showGuild = IsSectionVisible("guild")
  local widest = math.max(Measure(L["ROSTER_COL_CHARACTER"], 10), Measure(L["ROSTER_LEVEL_FORMAT"]:format(90), 10))
  for _, row in ipairs(GG.Roster:BuildRows()) do
    widest = math.max(widest,
      Measure(row.name, 15) + (row.isMain and badge or 0) + (GG.Roster:ClockState(row.freshness) and nameClock or 0),
      Measure(row.realm, 10))
    if showGuild and row.guild then widest = math.max(widest, Measure(row.guild, 10)) end
  end
  if GG.RaidRostersTab and GG.RaidRostersTab:TagsVisible() then
    widest = math.max(widest, GG.RaidRostersTab.TagMaxWidth(false))
  end
  local lead = CONST.CELL_PADDING + (IsSectionVisible("avatar") and (CONST.AVATAR_SIZE + CONST.AVATAR_GAP) or 0)
  local width = lead + math.ceil(widest) + CONST.CELL_PADDING
  return math.max(CONST.CHARACTER_COL_MIN, math.min(CONST.CHARACTER_COL_MAX, width))
end

CONST.RAID_INTERLOCK_ICON_SIZE = 18
CONST.RAID_INTERLOCK_LINE_HEIGHT = 30
CONST.RAID_INTERLOCK_LABEL_SPACE = 19
CONST.RAID_INTERLOCK_COLUMN_AIR = 8
CONST.RAID_INTERLOCK_MIN_LINE_HEIGHT = 24
CONST.RAID_INTERLOCK_MAX_ZIGZAG_DIFFICULTIES = 2
CONST.RAID_SKULL_LINE_GAP = 1

function CurrencyGrid.RaidZigzagInRows()
  if not GG.BossIcons:IsInterlocking() then return false end
  if CurrencyGrid.BossesAsBar and CurrencyGrid.BossesAsBar() then return false end
  local visible = 0
  for _, difficultyID in ipairs(CONST.RAID_BAR_ORDER or {}) do
    if IsRaidDifficultyVisible(difficultyID) then visible = visible + 1 end
  end
  return visible <= CONST.RAID_INTERLOCK_MAX_ZIGZAG_DIFFICULTIES
end

function CurrencyGrid.RaidColumnWidth(baseWidth)
  if not CurrencyGrid.RaidZigzagInRows() then return baseWidth end
  local count = 0
  for _, raid in ipairs(GG.Season.RAIDS or {}) do count = count + (raid.numEncounters or 0) end
  local size = CONST.RAID_INTERLOCK_ICON_SIZE
  local bosses = size + (math.max(count, 1) - 1) * math.ceil(GG.BossIcons.INTERLOCK_DX * size)
  return math.min(baseWidth,
    bosses + CONST.RAID_INTERLOCK_LABEL_SPACE + CONST.CELL_PADDING * 2 + CONST.RAID_INTERLOCK_COLUMN_AIR)
end

local function ColumnLayout(totalContentWidth)
  local accountWidth = GetAccountColumnWidth()
  local characterWidth = GetCharacterColumnWidth()
  local function ColWidth(col)
    if col.key == "account" then return accountWidth end
    if col.key == "character" then return characterWidth end
    if col.key == "raid" then return CurrencyGrid.RaidColumnWidth(col.width) end
    return col.width
  end

  local fixedWidth = 0
  for _, col in ipairs(CONST.COLUMNS) do
    if col.key ~= CONST.FLEX_COLUMN_KEY and IsSectionVisible(col.optionKey) then
      fixedWidth = fixedWidth + ColWidth(col)
    end
  end

  local flexWidth = math.max(CurrencyGrid.FlexMinWidth(), totalContentWidth - fixedWidth)
  local layout, x = {}, 0
  for _, col in ipairs(CONST.COLUMNS) do
    if IsSectionVisible(col.optionKey) then
      local w = (col.key == CONST.FLEX_COLUMN_KEY) and flexWidth or ColWidth(col)
      layout[col.key] = { x = x, width = w, visible = true }
      x = x + w
    else
      layout[col.key] = { x = x, width = 0, visible = false }
    end
  end
  return layout, x
end

local function TrueMinContentWidth()
  local accountWidth = GetAccountColumnWidth()
  local total = 0
  for _, col in ipairs(CONST.COLUMNS) do
    if IsSectionVisible(col.optionKey) then
      if col.key == CONST.FLEX_COLUMN_KEY then
        total = total + CurrencyGrid.FlexMinWidth()
      elseif col.key == "account" then
        total = total + accountWidth
      elseif col.key == "character" then
        total = total + GetCharacterColumnWidth()
      elseif col.key == "raid" then
        total = total + CurrencyGrid.RaidColumnWidth(col.width)
      else
        total = total + col.width
      end
    end
  end
  return total
end

local function FormatRelativeTime(ts)
  if not ts then return "—" end
  local diff = time() - ts
  if diff < 60 then return L["ROSTER_LAST_UPDATE_NOW"], true
  elseif diff < 3600 then return L["ROSTER_LAST_UPDATE_MINUTES"]:format(math.floor(diff / 60))
  elseif diff < 86400 then return L["ROSTER_LAST_UPDATE_HOURS"]:format(math.floor(diff / 3600))
  else return L["ROSTER_LAST_UPDATE_DAYS"]:format(math.floor(diff / 86400))
  end
end

local frame
local header = { cells = {}, hitboxes = {} }
local scrollClip, scrollbar
local hscrollbar
local sidebar
local rail
local layoutBtn
local RefreshLayoutButton
local resizeRelayoutPending = false
local UpdateSidebar
local customOrderBtn
local settingsBtn
local versionText
local versionBanner
local editBanner
local editModeBorder
local opacityPanels = {}
local rowPool = {}
local dataRows = {}
local scrollOffset = 0
local settingsOpen = false
local columnLayout = ColumnLayout(CONST.DEFAULT_WIDTH - CONST.WINDOW_CONTENT_GUTTER)

local vaultCardPool = {}
local vaultCardContainer
local vaultScrollOffsetPx = 0

local state = {
  filterTab = "all",
  accountFilter = nil,
  search = "",
  sortKey = "character",
  sortAsc = true,
  dragEditMode = false,
  arrangeCfg = nil,
  arrangeCtx = nil,
  arrangeEntry = nil,
  arrangeExtra = 0,
}

local function RailHeight()
  if not state.dragEditMode then return CONST.RAIL_HEIGHT end
  return CONST.RAIL_HEIGHT + (state.arrangeExtra or 0)
end

local RefreshArrangePanel
local UpdateSortHalo

local searchBox, countLabel, syncLabel, tabButtons = nil, nil, nil, {}
local charactersBtn

local tabDefs = {
  { key = "all", labelKey = "ROSTER_TAB_ALL" },
  { key = "vaultPending", labelKey = "ROSTER_TAB_VAULT_PENDING" },
  { key = "raid", labelKey = "ROSTER_TAB_RAID" },
  { key = "bonusRoll", labelKey = "ROSTER_TAB_BONUS_ROLL" },
  { key = "rosters", labelKey = "ROSTER_TAB_ROSTERS", dynamic = true },
}

local function CreateNavTab(parent, text, icon)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetHeight(CONST.NAV_TAB_HEIGHT)
  btn.bg = btn:CreateTexture(nil, "BACKGROUND")
  btn.bg:SetAllPoints()
  btn.bg:SetColorTexture(unpack(Theme.panel))
  btn.hoverBg = btn:CreateTexture(nil, "BACKGROUND")
  btn.hoverBg:SetAllPoints()
  btn.hoverBg:SetColorTexture(1, 1, 1, 0.04)
  btn.topBar = btn:CreateTexture(nil, "ARTWORK")
  btn.topBar:SetPoint("TOPLEFT")
  btn.topBar:SetPoint("TOPRIGHT")
  btn.topBar:SetHeight(3)
  btn.topBar:SetColorTexture(unpack(Theme.accent))
  btn.leftLine = btn:CreateTexture(nil, "ARTWORK")
  btn.leftLine:SetPoint("TOPLEFT")
  btn.leftLine:SetPoint("BOTTOMLEFT")
  btn.leftLine:SetWidth(1)
  btn.leftLine:SetColorTexture(unpack(Theme.border))
  btn.rightLine = btn:CreateTexture(nil, "ARTWORK")
  btn.rightLine:SetPoint("TOPRIGHT")
  btn.rightLine:SetPoint("BOTTOMRIGHT")
  btn.rightLine:SetWidth(1)
  btn.rightLine:SetColorTexture(unpack(Theme.border))

  icon = icon or {}
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetSize(icon and icon.size or 15, icon and icon.size or 15)
  btn.icon:SetPoint("LEFT", 12, 0)
  if icon.atlas then
    btn.icon:SetAtlas(icon.atlas)
  else
    local file = icon.file
    if icon.currency and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
      local info = C_CurrencyInfo.GetCurrencyInfo(icon.currency)
      file = (info and info.iconFileID) or icon.fallback
    end
    btn.icon:SetTexture(file or "Interface\\Icons\\INV_Misc_QuestionMark")
    if icon.crop then btn.icon:SetTexCoord(unpack(Theme.iconCrop)) end
  end
  btn.tint = icon.tint

  btn.label = CreateLabel(btn, 12.5, Theme.textMuted, true)
  btn.label:SetPoint("LEFT", btn.icon, "RIGHT", 7, 0)
  btn.label:SetText(text)

  btn.badge = CreateFrame("Frame", nil, btn)
  btn.badge:SetHeight(16)
  btn.badge:SetPoint("LEFT", btn.label, "RIGHT", 7, 0)
  btn.badge.bg = btn.badge:CreateTexture(nil, "BACKGROUND")
  btn.badge.bg:SetAllPoints()
  btn.badge.text = CreateLabel(btn.badge, 10, Theme.textPrimary, true)
  btn.badge.text:SetPoint("CENTER", 0, 0)
  btn.badge:Hide()

  function btn:Layout()
    local width = 12 + self.icon:GetWidth() + 7 + self.label:GetStringWidth() + 14
    if self.badge:IsShown() then
      local badgeWidth = math.max(18, self.badge.text:GetStringWidth() + 10)
      self.badge:SetWidth(badgeWidth)
      width = width + 7 + badgeWidth
    end
    self:SetWidth(width)
  end

  function btn:SetBadge(value, style)
    if not value then
      self.badge:Hide()
      self:Layout()
      return
    end
    local fg, bg = Theme.textMuted, { 1, 1, 1, 0.09 }
    if style == "accent" then
      fg, bg = { 0.106, 0.082, 0.188, 1 }, Theme.ready
    elseif style == "green" then
      fg, bg = Theme.success, { Theme.success[1], Theme.success[2], Theme.success[3], 0.18 }
    end
    self.badge.bg:SetColorTexture(unpack(bg))
    self.badge.text:SetTextColor(unpack(fg))
    self.badge.text:SetText(value)
    self.badge:Show()
    self:Layout()
  end

  function btn:Paint(active)
    self.active = active
    self.bg:SetShown(active)
    self.topBar:SetShown(active)
    self.leftLine:SetShown(active)
    self.rightLine:SetShown(active)
    self.hoverBg:SetShown(not active and self:IsMouseOver())
    self.label:SetTextColor(unpack(active and { 1, 1, 1, 1 } or Theme.textMuted))
    self.icon:SetAlpha(active and 1 or 0.6)
    if self.tint then
      self.icon:SetVertexColor(unpack(active and Theme.accent or { 0.55, 0.52, 0.63, 1 }))
    else
      self.icon:SetDesaturated(not active)
    end
  end

  btn:SetScript("OnEnter", function(self)
    if self.active then return end
    self.hoverBg:Show()
    self.label:SetTextColor(unpack(Theme.textPrimary))
  end)
  btn:SetScript("OnLeave", function(self) self:Paint(self.active) end)
  btn:Paint(false)
  return btn
end

local function CreateSegment(parent, onPick)
  local seg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  ApplyBackdrop(seg, CONST.NAV_BG, Theme.border, 1)
  seg:SetHeight(24)
  seg.buttons = {}
  seg.options = {}

  function seg:SetOptions(options)
    self.options = options
    self.hasOptions = #options > 0
    for i, opt in ipairs(options) do
      local b = self.buttons[i]
      if not b then
        b = CreateFrame("Button", nil, self)
        b:SetHeight(20)
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(12, 12)
        b.label = CreateLabel(b, 11.5, Theme.textMuted, true)
        b:SetScript("OnClick", function(clicked) if onPick then onPick(clicked.key) end end)
        b:SetScript("OnEnter", function(hovered)
          if not hovered.active then hovered.bg:SetColorTexture(1, 1, 1, 0.06) end
        end)
        b:SetScript("OnLeave", function(hovered)
          if not hovered.active then hovered.bg:SetColorTexture(0, 0, 0, 0) end
        end)
        self.buttons[i] = b
      end
      b.key = opt.key
      b.label:SetText(opt.label)
      b.hasIcon = opt.icon ~= nil
      if opt.icon then b.icon:SetTexture(opt.icon) end
      b.icon:SetShown(b.hasIcon)
      b:Show()
    end
    for i = #options + 1, #self.buttons do self.buttons[i]:Hide() end
    self:Layout()
  end

  function seg:Layout()
    local x = 2
    for i = 1, #self.options do
      local b = self.buttons[i]
      local iconWidth = b.hasIcon and 16 or 0
      local hasText = (b.label:GetText() or "") ~= ""
      local width = hasText and (b.label:GetStringWidth() + 20 + iconWidth) or 30
      b:ClearAllPoints()
      b:SetPoint("LEFT", self, "LEFT", x, 0)
      b:SetWidth(width)
      b.icon:ClearAllPoints()
      b.icon:SetPoint("LEFT", b, "LEFT", 9, 0)
      b.label:ClearAllPoints()
      b.label:SetPoint("LEFT", b, "LEFT", 10 + iconWidth, 0)
      x = x + width + 2
    end
    self:SetWidth(math.max(x, 4))
  end

  function seg:Paint(activeKey)
    for i = 1, #self.options do
      local b = self.buttons[i]
      local active = b.key == activeKey
      b.active = active
      b.bg:SetColorTexture(unpack(active and Theme.accent or { 0, 0, 0, 0 }))
      b.label:SetTextColor(unpack(active and Theme.onAccent or Theme.textMuted))
      b.icon:SetVertexColor(unpack(active and Theme.onAccent or { 0.55, 0.52, 0.63, 1 }))
    end
  end
  return seg
end

local function UpdateFooter()
  local legend = state.footerLegend
  if not legend or not state.footerHint then return end
  local items, hint
  if state.filterTab == "all" then
    items = {
      { Theme.purple, L["ROSTER_LEGEND_RAID"] },
      { Theme.teal, L["ROSTER_LEGEND_MPLUS"] },
      { Theme.gold, L["ROSTER_LEGEND_WORLD"] },
    }
    hint = L["ROSTER_FOOTER_HINT"]
  elseif state.filterTab == "vaultPending" then
    items = {
      { Theme.ready, L["VAULT_STATE_READY"] },
      { Theme.gold, L["FOOTER_VAULT_LOGIN"] },
      { Theme.success, L["VAULT_STATE_CLAIMED"] },
    }
    hint = L["FOOTER_VAULT_HINT"]
  elseif state.filterTab == "raid" then
    items = {
      { Theme.danger, L["RAID_LEGEND_KILLED"] },
      { { 0.302, 0.318, 0.376, 1 }, L["RAID_LEGEND_ALIVE"] },
      { Theme.warning or Theme.gold, L["RAID_STAT_UNKNOWN"] },
    }
    hint = L["FOOTER_RAID_HINT"]
  elseif state.filterTab == "bonusRoll" then
    items, hint = {}, L["FOOTER_BONUS_HINT"]
  elseif state.filterTab == "rosters" then
    items, hint = {}, L["RR_EXPIRES"]
  else
    items, hint = {}, ""
  end
  for i, slot in ipairs(legend) do
    local item = items[i]
    slot.dot:SetShown(item ~= nil)
    slot.text:SetShown(item ~= nil)
    if item then
      slot.dot:SetColorTexture(unpack(item[1]))
      slot.text:SetText(item[2])
    end
  end
  state.footerHint:SetText(hint)
end

local function PaintNavTabs()
  local activeKey = settingsOpen and "__settings" or state.filterTab
  for key, btn in pairs(tabButtons) do btn:Paint(key == activeKey) end
  if state.settingsTab then state.settingsTab:Paint(settingsOpen == true) end
end

local function UpdateNavBadges(rows)
  if not tabButtons.all then return end
  tabButtons.all:SetBadge(tostring(#rows))
  local pending = 0
  for _, row in ipairs(rows) do
    if row.vault and row.vault.hasAvailableRewards then pending = pending + 1 end
  end
  tabButtons.vaultPending:SetBadge(pending > 0 and tostring(pending) or nil, "accent")
  if tabButtons.raid then
    tabButtons.raid:SetBadge(IsInRaid() and tostring(GetNumGroupMembers()) or nil, "green")
  end
  if tabButtons.bonusRoll and GG.BonusRoll then
    local rolls = 0
    for _, item in ipairs(GG.BonusRoll:Collect(rows)) do
      if not item.entry.secondary then rolls = rolls + 1 end
    end
    tabButtons.bonusRoll:SetBadge(rolls > 0 and tostring(rolls) or nil)
  end
end

local function UpdateContextBar()
  local ctx = state.ctxBar
  if not ctx then return end
  local tab = state.filterTab
  local show = not settingsOpen and (tab == "all" or tab == "vaultPending")
  ctx:SetHeight(show and CONST.CTX_HEIGHT or 0.001)
  ctx:SetShown(show)
  if UpdateSortHalo then UpdateSortHalo() end
  if not show then return end
  local isCharacters = tab == "all"
  if customOrderBtn then customOrderBtn:SetShown(isCharacters) end
  if charactersBtn then charactersBtn:SetShown(isCharacters) end
  if state.layoutSeg then state.layoutSeg:SetShown(isCharacters) end
  ctx.resetText:SetShown(not isCharacters)
  if not isCharacters then
    local seconds = (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()) or 0
    local days, hours, minutes = math.floor(seconds / 86400), math.floor(seconds % 86400 / 3600), math.floor(seconds % 3600 / 60)
    ctx.resetText:SetText(L["VAULT_RESETS_IN"]:format(days > 0 and ("%dd %dh"):format(days, hours) or ("%dh %dm"):format(hours, minutes)))
  end
end

local function LayoutActionRail()
  local prev
  local navWidth = 10
  for _, def in ipairs(tabDefs) do
    local btn = tabButtons[def.key]
    if not btn then return end
    local visible = not def.dynamic or state.filterTab == def.key
      or (GG.RaidRosters ~= nil and GG.RaidRosters:HasActive())
    btn:SetShown(visible)
    btn:ClearAllPoints()
    if prev then
      btn:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 2, 0)
    else
      btn:SetPoint("BOTTOMLEFT", rail, "BOTTOMLEFT", 10, -1)
    end
    btn:Layout()
    if visible then
      navWidth = navWidth + btn:GetWidth() + 2
      prev = btn
    end
  end
  local settingsTab = state.settingsTab
  if settingsTab then
    settingsTab:ClearAllPoints()
    settingsTab:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -10, -1)
    settingsTab:Layout()
    if syncLabel then
      syncLabel:ClearAllPoints()
      syncLabel:SetPoint("RIGHT", settingsTab, "LEFT", -14, 0)
      local room = rail:GetWidth() - navWidth - settingsTab:GetWidth() - 10 - 28
      syncLabel:SetShown(room >= 130 and not settingsOpen
        and state.filterTab ~= "raid" and state.filterTab ~= "bonusRoll" and state.filterTab ~= "rosters")
      for _, icon in ipairs(state.syncIcons or {}) do icon:SetShown(syncLabel:IsShown() and icon.used == true) end
    end
  end

  local ctx = state.ctxBar
  if not ctx then return end
  local compact = ctx:GetWidth() > 0 and ctx:GetWidth() < CONST.COMPACT_BAR_WIDTH
  if compact ~= state.compactBar then
    state.compactBar = compact
    if state.layoutSeg then
      state.layoutSeg:SetOptions({
        { key = "rows", label = compact and "" or L["LAYOUT_ROWS"], icon = "Interface\\AddOns\\GG\\Media\\ViewHorizontal64.tga" },
        { key = "cols", label = compact and "" or L["LAYOUT_COLUMNS"], icon = "Interface\\AddOns\\GG\\Media\\ViewVertical64.tga" },
      })
      local vertical = (GGDB and GGDB.options and GGDB.options.layoutMode) == "vertical"
      state.layoutSeg:Paint(vertical and "cols" or "rows")
    end
    if countLabel then
      countLabel:SetText(compact and tostring(#dataRows) or L["ROSTER_COUNT"]:format(#dataRows))
    end
  end
  local seg = state.accountSeg
  local hasAccounts = seg ~= nil and seg.hasOptions == true
  ctx.accountLabel:SetShown(hasAccounts)
  local left
  if seg then
    seg:SetShown(hasAccounts)
    if hasAccounts then
      seg:Layout()
      seg:ClearAllPoints()
      seg:SetPoint("LEFT", ctx.accountLabel, "RIGHT", 8, 0)
      left = seg
    end
  end
  if searchBox then
    searchBox:ClearAllPoints()
    if left then
      searchBox:SetPoint("LEFT", left, "RIGHT", 14, 0)
    else
      searchBox:SetPoint("LEFT", ctx, "LEFT", 12, 0)
    end
  end
  if charactersBtn then
    charactersBtn:ClearAllPoints()
    charactersBtn:SetPoint("RIGHT", ctx, "RIGHT", -10, 0)
    if charactersBtn.Sync then charactersBtn:Sync() end
  end
  local isCharacters = state.filterTab == "all"
  local leftEdge = 12
  if left then leftEdge = leftEdge + ctx.accountLabel:GetStringWidth() + 8 + left:GetWidth() + 14 end
  if state.layoutSeg then state.layoutSeg:Layout() end
  local centered = false
  if customOrderBtn then
    customOrderBtn:SetWidth(customOrderBtn.label:GetStringWidth() + 10 + 14 + 6 + 12)
    local half = ctx:GetWidth() / 2 - customOrderBtn:GetWidth() / 2
    local rightNeeded = 10 + (charactersBtn and charactersBtn:GetWidth() + 10 or 0)
      + (state.layoutSeg and state.layoutSeg:GetWidth() + 14 or 0)
    centered = ctx:GetWidth() > 0 and half >= leftEdge + 80 + 14 and half >= rightNeeded
    customOrderBtn:ClearAllPoints()
    if centered then
      customOrderBtn:SetPoint("CENTER", ctx, "CENTER", 0, 0)
    elseif charactersBtn then
      customOrderBtn:SetPoint("RIGHT", charactersBtn, "LEFT", -10, 0)
    else
      customOrderBtn:SetPoint("RIGHT", ctx, "RIGHT", -10, 0)
    end
  end
  state.sortCentered = centered
  if searchBox and ctx:GetWidth() > 0 then
    local available
    if isCharacters and centered then
      available = ctx:GetWidth() / 2 - customOrderBtn:GetWidth() / 2 - 14 - leftEdge
    else
      local rightUsed = 10
      if isCharacters then
        if charactersBtn then rightUsed = rightUsed + charactersBtn:GetWidth() + 10 end
        if customOrderBtn then rightUsed = rightUsed + customOrderBtn:GetWidth() + 10 end
        if state.layoutSeg then rightUsed = rightUsed + state.layoutSeg:GetWidth() + 10 end
      else
        rightUsed = rightUsed + ctx.resetText:GetStringWidth() + 14
      end
      available = ctx:GetWidth() - leftEdge - rightUsed - 12
    end
    searchBox:SetWidth(math.max(80, math.min(190, available)))
  end
  if state.layoutSeg then
    state.layoutSeg:ClearAllPoints()
    if customOrderBtn and not centered then
      state.layoutSeg:SetPoint("RIGHT", customOrderBtn, "LEFT", -10, 0)
    elseif charactersBtn then
      state.layoutSeg:SetPoint("RIGHT", charactersBtn, "LEFT", -10, 0)
    else
      state.layoutSeg:SetPoint("RIGHT", ctx, "RIGHT", -10, 0)
    end
  end
  if UpdateSortHalo then UpdateSortHalo() end
end

local function RowMatchesFilterTab(row)
  if state.accountFilter and (state.filterTab == "all" or state.filterTab == "vaultPending")
    and row.accountLabel ~= state.accountFilter then
    return false
  end
  if state.filterTab == "vaultPending" then
    return row.vault.hasAvailableRewards or row.vault.claim ~= nil
  end
  return true
end

local function RowMatchesSearch(row)
  if state.search == "" then return true end
  local needle = state.search:lower()
  return row.name:lower():find(needle, 1, true) ~= nil
    or row.realm:lower():find(needle, 1, true) ~= nil
end

local function RowSortValue(row, key)
  if key == "character" then return row.name:lower() end
  if key == "ilvl" then return row.ilvl end
  if key == "rating" then return row.rating end
  if key == "custom" then
    local order = GGDB.options and GGDB.options.customOrder
    if order then
      for i, key2 in ipairs(order) do
        if key2 == row.key then return i end
      end
    end
    return math.huge
  end
  return 0
end

local function ArrangeConfig()
  return GG.Arrange:Resolve(GGDB.options and GGDB.options.arrange)
end

local ARRANGE_LABEL_KEYS = {
  free = "ARRANGE_FREE", roster = "ARRANGE_ROSTER", class = "ARRANGE_CLASS", account = "ARRANGE_ACCOUNT",
  role = "ARRANGE_ROLE", ilvl = "ARRANGE_ILVL", rating = "ARRANGE_RATING", level = "ARRANGE_LEVEL",
  name = "ARRANGE_NAME", manual = "ARRANGE_MY_ORDER",
}
local HEADER_SORT_LABEL_KEYS = { character = "ARRANGE_NAME", ilvl = "ARRANGE_ILVL", rating = "ARRANGE_RATING" }

local function SortedByText()
  local shown
  if state.sortKey ~= "custom" then
    shown = L[HEADER_SORT_LABEL_KEYS[state.sortKey] or "ARRANGE_MY_ORDER"]
  else
    local cfg = state.arrangeCfg or ArrangeConfig()
    local by = GG.Arrange:Effective(cfg, state.arrangeCtx and state.arrangeCtx.hasRosters)
    shown = L[by == "free" and "ARRANGE_MY_ORDER" or ARRANGE_LABEL_KEYS[by]]
  end
  return L["ROSTER_CUSTOM_ORDER"]:format(shown)
end

local function SyncSortedByLabel()
  if not customOrderBtn then return end
  local text = SortedByText()
  if customOrderBtn.label:GetText() ~= text then
    customOrderBtn.label:SetText(text)
    LayoutActionRail()
  end
end

local function RosterLabelOf(row)
  local rr = GG.RaidRosters
  if not (rr and rr:HasActive()) then return nil end
  local best
  for _, tag in ipairs(rr:TagsFor(row.key, row.rawRecord)) do
    if tag.label and (not best or GG.Arrange.NaturalLess(tag.label, best)) then best = tag.label end
  end
  return best
end

local function PrepareArrange(rows)
  local cfg = ArrangeConfig()
  local rosters, accounts, seenR, seenA = {}, {}, {}, {}
  local tagOf = {}
  for _, row in ipairs(rows) do
    local label = RosterLabelOf(row)
    tagOf[row.key] = label
    if label and not seenR[label] then seenR[label] = true; rosters[#rosters + 1] = label end
    local account = row.accountLabel
    if account and not seenA[account] then seenA[account] = true; accounts[#accounts + 1] = account end
  end
  table.sort(rosters, GG.Arrange.NaturalLess)
  cfg.strips.account = GG.Arrange.SyncStrip(cfg.strips.account, accounts)
  GGDB.options.arrange = cfg

  local manualPos = {}
  for i, key in ipairs(GGDB.options.customOrder or {}) do
    if not manualPos[key] then manualPos[key] = i end
  end
  state.arrangeCfg = cfg
  state.arrangeCtx = {
    manualPos = manualPos,
    rosterOf = function(row) return tagOf[row.key] end,
    hasRosters = #rosters > 0,
    rosters = rosters,
  }
end

local function BuildComparator()
  local key, asc = state.sortKey, state.sortAsc
  if key == "custom" and state.arrangeCfg and state.arrangeCtx then
    return GG.Arrange:Comparator(state.arrangeCfg, state.arrangeCtx)
  end
  return function(a, b)
    local av, bv = RowSortValue(a, key), RowSortValue(b, key)
    if av == bv then return a.name:lower() < b.name:lower() end
    if asc then return av < bv else return av > bv end
  end
end

local function EnsureCustomOrderComplete()
  GGDB.options.customOrder = GGDB.options.customOrder or {}
  local order = GGDB.options.customOrder

  local present = {}
  for _, key in ipairs(order) do present[key] = true end

  local rows = GG.Roster:BuildRows()
  table.sort(rows, function(a, b) return a.name:lower() < b.name:lower() end)
  for _, row in ipairs(rows) do
    if not present[row.key] then
      table.insert(order, row.key)
      present[row.key] = true
    end
  end
end

CONST.RAID_DIFFICULTY_DEFS = {
  [17] = { color = { 0.12, 1.00, 0.00, 1 }, abbr = "L", labelKey = "DIFFICULTY_LFR" },
  [14] = { color = { 0.00, 0.44, 0.87, 1 }, abbr = "N", labelKey = "DIFFICULTY_NORMAL" },
  [15] = { color = { 0.64, 0.21, 0.93, 1 }, abbr = "H", labelKey = "DIFFICULTY_HEROIC" },
  [16] = { color = { 1.00, 0.50, 0.00, 1 }, abbr = "M", labelKey = "DIFFICULTY_MYTHIC" },
}

CONST.RAID_BAR_ORDER = { 17, 14, 15, 16 }
CONST.RAID_BAR_ROW_HEIGHT = 16
CONST.RAID_BOSS_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"
CONST.RAID_BOSS_DIM_COLOR = { 0.302, 0.318, 0.376, 1 }
CONST.RAID_BAR_ICON_GAP = 2

local function VaultSlotDisplay(slot)
  if slot.type == Enum.WeeklyRewardChestThresholdType.Raid then
    local difficultyID = GetBaseDifficultyID(slot.level)
    local def = difficultyID and CONST.RAID_DIFFICULTY_DEFS[difficultyID]
    return def and def.abbr or "?", def and def.color or Theme.textPrimary
  end
  return tostring(slot.level or 0), Theme.accentStrong
end

local function DescribeVaultSlot(slot, fallbackLabel)
  if slot.type == Enum.WeeklyRewardChestThresholdType.Raid then
    local difficultyID = GetBaseDifficultyID(slot.level)
    local difficultyName = difficultyID and GetDifficultyInfo(difficultyID)
    return difficultyName or fallbackLabel
  elseif slot.type == Enum.WeeklyRewardChestThresholdType.Activities then
    return (WEEKLY_REWARDS_MYTHIC and WEEKLY_REWARDS_MYTHIC:format(slot.level or 0)) or fallbackLabel
  elseif slot.type == Enum.WeeklyRewardChestThresholdType.World then
    return (GREAT_VAULT_WORLD_TIER and GREAT_VAULT_WORLD_TIER:format(slot.level or 0)) or fallbackLabel
  end
  return fallbackLabel
end

CONST.VAULT_TIER_TYPES = {
  { type = Enum.WeeklyRewardChestThresholdType.Raid, labelKey = "VAULT_TIER_RAID" },
  { type = Enum.WeeklyRewardChestThresholdType.Activities, labelKey = "VAULT_TIER_DUNGEONS" },
  { type = Enum.WeeklyRewardChestThresholdType.World, labelKey = "VAULT_TIER_WORLD" },
}

local function CollectVaultTierSlots(record, tierType)
  local slots = {}
  for _, slot in ipairs((record.vault and record.vault.slots) or {}) do
    if slot.type == tierType then table.insert(slots, slot) end
  end
  table.sort(slots, function(a, b) return (a.index or 0) < (b.index or 0) end)
  return slots
end

local function VaultCellText(slot, fallbackLabel)
  if slot.type == Enum.WeeklyRewardChestThresholdType.Activities then
    return ("M+%d"):format(slot.level or 0)
  end
  if slot.type == Enum.WeeklyRewardChestThresholdType.Raid then
    local difficultyID = GetBaseDifficultyID(slot.level)
    local def = difficultyID == 17 and CONST.RAID_DIFFICULTY_DEFS[17]
    if def and def.abbr then return def.abbr end
  end
  return DescribeVaultSlot(slot, fallbackLabel)
end

local function ShowVaultTooltip(anchor, record)
  local isCurrentWeek = GG.Vault:IsCurrentWeek(record)
  GG.Tip:Open(anchor, { family = "vault" }, function(t)
    local rows, open, total = {}, 0, 0
    for _, tierDef in ipairs(CONST.VAULT_TIER_TYPES) do
      local cells = {}
      for _, slot in ipairs(CollectVaultTierSlots(record, tierDef.type)) do
        local unlocked = isCurrentWeek and slot.unlocked
        total = total + 1
        if unlocked then open = open + 1 end
        cells[#cells + 1] = {
          text = unlocked and VaultCellText(slot, L[tierDef.labelKey]) or ("%d/%d"):format(slot.progress or 0, slot.threshold or 0),
          on = unlocked and true or false,
        }
      end
      if #cells > 0 then rows[#rows + 1] = { label = L[tierDef.labelKey], cells = cells } end
    end
    t:Head({ kicker = L["TIP_THIS_WEEK"], title = L["SECTION_VAULT"], right = open, rightOf = total })
    local pending = GG.Vault:HasPendingRewards(record)
    if pending then t:Text(L["VAULT_UNCLAIMED"], Theme.success) end
    t:Vault(rows)
    if pending then t:Action(L["TOOLTIP_CLICK"], L["TIP_VIEW_VAULT"]:format(L["VAULT_REWARDS_LABEL"])) end
  end)
end

local function ShowRaidTooltip(anchor, record, filterDifficultyID)
  local killedLookup = GG.Lockouts:BuildKilledLookup(record)

  local catalog = GG.Lockouts:GetRaidBossCatalog()
  local catalogRaids = {}
  for _, raidDef in ipairs(GG.Season.RAIDS or {}) do
    local entry = catalog[raidDef.instanceID]
    if entry then table.insert(catalogRaids, entry) end
  end
  local multipleRaids = #catalogRaids > 1

  local visibleDifficulties = {}
  for _, difficultyID in ipairs(CONST.RAID_BAR_ORDER) do
    if IsRaidDifficultyVisible(difficultyID) and (not filterDifficultyID or difficultyID == filterDifficultyID) then
      table.insert(visibleDifficulties, difficultyID)
    end
  end

  local firstDef = visibleDifficulties[1] and CONST.RAID_DIFFICULTY_DEFS[visibleDifficulties[1]]
  GG.Tip:Open(anchor, { family = "raid", color = firstDef and firstDef.color }, function(t)
    if #visibleDifficulties == 0 or #catalogRaids == 0 then
      t:Head({ title = L["RAID_PROGRESS_TITLE"] })
      t:Text(L["RAID_PROGRESS_EMPTY"])
      return
    end
    for position, difficultyID in ipairs(visibleDifficulties) do
      local def = CONST.RAID_DIFFICULTY_DEFS[difficultyID]
      local difficultyName = GetDifficultyInfo(difficultyID) or (def and def.abbr) or "?"
      local function IsKilled(raid, boss)
        return killedLookup[raid.instanceID .. ":" .. difficultyID .. ":" .. boss.index] == true
      end

      local killed, total, segments = 0, 0, {}
      for _, raid in ipairs(catalogRaids) do
        for _, boss in ipairs(raid.bosses) do
          total = total + 1
          local isKilled = IsKilled(raid, boss)
          if isKilled then killed = killed + 1 end
          segments[total] = isKilled
        end
      end

      if position == 1 then
        t:Head({ kicker = L["RAID_PROGRESS_TITLE"], title = difficultyName, right = killed, rightOf = total })
      else
        t:Sep()
        t:Group(difficultyName, killed .. "/" .. total, def and def.color)
      end
      t:Segs(segments)
      for raidPosition, raid in ipairs(catalogRaids) do
        if raidPosition > 1 then t:Gap(5) end
        if multipleRaids then
          local raidKilled = 0
          for _, boss in ipairs(raid.bosses) do
            if IsKilled(raid, boss) then raidKilled = raidKilled + 1 end
          end
          t:Group(raid.name or "?", raidKilled .. "/" .. #raid.bosses)
        end
        for _, boss in ipairs(raid.bosses) do
          t:Boss(GG.Lockouts:BossIcon(raid.instanceID, boss.index), boss.name, IsKilled(raid, boss))
        end
      end
    end
  end)
end

local function ShowKeystoneTooltip(anchor, record)
  local keystone = GG.Vault:CurrentKeystone(record)
  GG.Tip:Open(anchor, { family = "keys" }, function(t)
    if keystone then
      t:Title(keystone.dungeonName or "?")
      t:Text(L["TIP_KEYSTONE"]:format(keystone.level or 0))
    else
      t:Text(L["ROSTER_NO_KEYSTONE"], Theme.textFaint)
    end
  end)
end

local function ShowRatingTooltip(anchor, record)
  local rating = record.mythicplus and record.mythicplus.rating
  GG.Tip:Open(anchor, { family = "keys" }, function(t)
    t:Head({ kicker = L["TIP_MPLUS"], title = L["ROSTER_COL_RATING"],
      right = (rating and rating > 0) and tostring(rating) or "—" })
    if IsSectionVisible("dungeons") then
      for _, dungeon in ipairs((record.mythicplus and record.mythicplus.dungeons) or {}) do
        local hasLevel = dungeon.level and dungeon.level > 0
        t:Kv(dungeon.dungeonName or "?", hasLevel and ("+%d"):format(dungeon.level) or "-", hasLevel and true or Theme.textFaint)
      end
    end
  end)
end

local function ClassifyBountyStatus(bounty)
  if not bounty then
    return {
      ringColor = Theme.borderSoft, iconAlpha = 0.25,
      showQuestMark = false, completions = 0,
      pendingKey = "BOUNTY_STATUS_NO_DATA", pendingColor = Theme.textMuted,
    }
  end

  local pendingKey, pendingColor
  if bounty.hasBuff then
    pendingKey, pendingColor = "BOUNTY_STATUS_ACTIVE", Theme.ready
  elseif (bounty.bagCount or 0) > 0 then
    pendingKey, pendingColor = "BOUNTY_STATUS_MAP_IN_BAG", Theme.ready
  elseif (bounty.fluteBagCount or 0) > 0 then
    pendingKey, pendingColor = "BOUNTY_STATUS_FLUTE_IN_BAG", Theme.ready
  else
    pendingKey, pendingColor = "BOUNTY_NOTHING_PENDING", Theme.textMuted
  end

  local hasExtra = bounty.hasBuff or (bounty.bagCount or 0) > 0 or (bounty.fluteBagCount or 0) > 0
  local completions = bounty.delveCompletionsThisWeek or 0

  local ringColor, iconAlpha
  if completions > 0 then
    ringColor, iconAlpha = Theme.success, 1
  elseif hasExtra then
    ringColor, iconAlpha = Theme.ready, 1
  else
    ringColor, iconAlpha = Theme.borderSoft, 0.5
  end

  return {
    ringColor = ringColor,
    iconAlpha = iconAlpha,
    showQuestMark = bounty.weeklyQuestClaimed == true,
    showPendingDot = completions > 0 and hasExtra,
    completions = completions,
    pendingKey = pendingKey, pendingColor = pendingColor,
  }
end

local function ClassifyNemesisStatus(nemesis)
  local total = (nemesis and nemesis.total) or 2
  local done = (nemesis and nemesis.completedCount) or 0
  return {
    pending = done < total,
    completedCount = done,
    total = total,
    noData = nemesis == nil,
    hasFirst = done >= 1,
  }
end

local function ShowNemesisTooltip(anchor, datum)
  local status = datum.nemesis
  local classification = ClassifyNemesisStatus(status)
  GG.Tip:Open(anchor, { family = "quest" }, function(t)
    t:Head({ kicker = L["TIP_ONCE_SEASON"], title = L["NEMESIS_TITLE"],
      right = status and classification.completedCount or nil, rightOf = status and classification.total or nil })
    t:Text(L["NEMESIS_TOOLTIP_DESC"])
    if not status then
      t:Text(L["NEMESIS_NO_DATA"], Theme.textFaint)
      return
    end
    t:Gap(4)
    t:Status(L["NEMESIS_DIFF_1_LABEL"], classification.hasFirst and L["NEMESIS_DONE"] or L["NEMESIS_PENDING"],
      classification.hasFirst and "done" or nil)
    t:Text(L["NEMESIS_DIFF_1_REWARD"], Theme.textFaint, true)
    t:Gap(4)
    local secondDone = classification.completedCount >= classification.total
    t:Status(L["NEMESIS_DIFF_2_LABEL"], secondDone and L["NEMESIS_DONE"] or L["NEMESIS_PENDING"],
      secondDone and "done" or nil)
    t:Text(L["NEMESIS_DIFF_2_REWARD"], Theme.textFaint, true)
  end)
end

function CurrencyGrid.ShowCrackedKeystoneTooltip(anchor, datum)
  local status = datum.crackedKeystone
  GG.Tip:Open(anchor, { family = "quest" }, function(t)
    t:Head({ kicker = L["TIP_ONCE_SEASON"], title = L["CRACKED_KEYSTONE_TITLE"] })
    if not status then
      t:Text(L["CRACKED_KEYSTONE_TOOLTIP_DESC"])
      t:Text(L["CRACKED_KEYSTONE_NO_DATA"], Theme.textFaint)
      return
    end
    local done = status.completed == true
    local started = not done and (status.inProgress == true or (status.bagCount or 0) > 0)
    if done then
      t:Status(L["TIP_STATUS"], L["CRACKED_KEYSTONE_DONE"], "done")
    elseif started then
      t:Status(L["TIP_STATUS"], L["CRACKED_KEYSTONE_IN_PROGRESS"], "warn")
    else
      t:Status(L["TIP_STATUS"], L["CRACKED_KEYSTONE_PENDING"])
    end
    if not done and (status.bagCount or 0) > 0 then
      t:Text(L["CRACKED_KEYSTONE_IN_BAG"], Theme.textFaint, true)
    end
    t:Text(L["CRACKED_KEYSTONE_TOOLTIP_DESC"], Theme.textFaint, true)
  end)
end

function CurrencyGrid.ShowKindojanTooltip(anchor, datum)
  local status = datum.kindojan
  GG.Tip:Open(anchor, { family = "quest" }, function(t)
    if type(status) ~= "table" then
      t:Head({ kicker = L["TIP_KINDOJAN_KICKER"], title = L["KINDOJAN_TITLE"] })
      t:Text(L["KINDOJAN_TOOLTIP_DESC"])
      t:Text(L["KINDOJAN_NO_DATA"], Theme.textFaint)
      return
    end
    local completed, doneCount = {}, 0
    if type(status.completedIDs) == "table" then
      for _, questID in ipairs(status.completedIDs) do completed[questID] = true end
    end
    local quests = GG.Season.KINDOJAN.quests
    for _, quest in ipairs(quests) do
      if completed[quest.id] then doneCount = doneCount + 1 end
    end
    t:Head({ kicker = L["TIP_KINDOJAN_KICKER"], title = L["KINDOJAN_TITLE"], right = doneCount, rightOf = #quests })
    for _, quest in ipairs(quests) do
      local name = C_QuestLog.GetTitleForQuestID(quest.id) or quest.name
      local isDone = completed[quest.id] == true
      t:Kv(name, L[isDone and "KINDOJAN_DONE" or "KINDOJAN_PENDING"], isDone and Theme.success or Theme.textFaint)
    end
    local st = GG.Currencies:KindojanState(status)
    t:Sep()
    t:Kv(L["KINDOJAN_FRAGMENTS"], tostring(st.fragments), true)
    t:Kv(L["KINDOJAN_ITEMS"], L["KINDOJAN_ITEMS_COUNT"]:format(st.bought, st.maxItems), true)
    if st.canBuy then t:Text(L["KINDOJAN_CAN_BUY"], CurrencyGrid.CAP_COLOR) end
  end)
end

local function ShowBountyTooltip(anchor, datum)
  local status = datum.bounty
  local classification = ClassifyBountyStatus(status)
  GG.Tip:Open(anchor, { family = "money" }, function(t)
    t:Head({ kicker = L["TIP_BOUNTY_KICKER"], title = L["BOUNTY_FALLBACK_TITLE"] })
    if not status then
      t:Text(L["BOUNTY_NO_DATA_HINT"], Theme.textFaint)
      return
    end
    t:Status(L["BOUNTY_WEEKLY_QUEST_LABEL"],
      classification.showQuestMark and L["BOUNTY_QUEST_CLAIMED"] or L["BOUNTY_QUEST_AVAILABLE"],
      classification.showQuestMark and "done" or nil)
    t:Kv(L["BOUNTY_COMPLETIONS_LABEL"],
      classification.completions > 0 and tostring(classification.completions) or L["BOUNTY_COMPLETIONS_NONE"],
      classification.completions > 0 and Theme.success or Theme.textFaint)
    t:Sep()
    t:Kv(L["BOUNTY_PENDING_LABEL"], L[classification.pendingKey], classification.pendingColor)
    t:Kv(L["BOUNTY_MAP_IN_BAG_LABEL"], tostring(status.bagCount or 0), (status.bagCount or 0) > 0 and true or nil)
    t:Kv(L["BOUNTY_FLUTE_IN_BAG_LABEL"], tostring(status.fluteBagCount or 0), (status.fluteBagCount or 0) > 0 and true or nil)
    t:Kv(L["BOUNTY_BUFF_LABEL"], status.hasBuff and L["BOUNTY_YES"] or L["BOUNTY_NO"], status.hasBuff and true or nil)
  end)
end

local function OpenVaultPreview(row)
  if row.datum and row.datum.rawRecord and GG.UI and GG.UI.ShowVaultPreview then
    GG.UI:ShowVaultPreview(row.datum.rawRecord)
  end
end

CONST.VAULT_SLOT_FONT_SIZE = 11
CONST.VAULT_SLOT_WIDTH = 26
CONST.VAULT_ROW_HEIGHT = 15
CONST.VAULT_DOT_SIZE = 5
CONST.VAULT_DOT_GAP = 6
CONST.VAULT_TIER_DOT_COLOR_KEYS = { "purple", "teal", "gold" }

local V = {}
V.COL_WIDTH = 140
V.COL_GAP = 6
V.COL_PADDING = 9
V.COL_CONTENT = V.COL_WIDTH - V.COL_PADDING * 2
V.SIDEBAR_WIDTH = 104
V.CURRENCY_ROW_HEIGHT = 35
V.CURRENCY_ROW_TOP = 3

V.DATA_ROW_HEIGHT = 28
V.HEAD_HEIGHT = 96
V.HEAD_HEIGHT_NO_AVATAR = 60
V.VAULT_HEIGHT = 64
V.ILVL_GAUGE_WINDOW = 20
V.QUESTS_HEIGHT = 42
V.TITLE_SIZE = 14
V.LABEL_SIZE = 12
V.SMALL_SIZE = 10
V.SIDE_X = 14

function V.Theme()
  if not V.T then V.ApplyTheme() end
  return V.T
end

function V.ApplyTheme()
  V.T = GG.RosterThemes:Resolve()
  local tok = V.T.tokens
  V.COL_WIDTH = tok.colWidth
  V.COL_GAP = tok.colGap or 0
  V.COL_CONTENT = V.COL_WIDTH - V.COL_PADDING * 2
  CONST.ROW_GAP = tok.rowGap or 0
  CONST.LIST_CARD_LEFT = tok.listCardLeft or 8
  CONST.LIST_ACCOUNT_INSET = CONST.LIST_CARD_LEFT + 4 + (tok.banner and tok.stripe or 0)
  return V.T
end

function V.ColPitch()
  return V.COL_WIDTH + V.COL_GAP
end

function CurrencyGrid.VerticalRows()
  local stacked = CurrencyGrid.Layouts()
  return math.max(1, stacked.rows)
end

local function PlaceCurrencyRule(rule, cell, x, y, width, height)
  if not x then
    rule:Hide()
    return
  end
  rule:ClearAllPoints()
  rule:SetSize(width, height)
  rule:SetPoint("TOPLEFT", cell, "TOPLEFT", x, y)
  rule:Show()
end

CurrencyGrid.BOUNTY_WORDS = { buff = "BOUNTY_WORD_BUFF", bag = "BOUNTY_WORD_BAG", flute = "BOUNTY_WORD_FLUTE" }

function CurrencyGrid.PaintBountySlot(slot, entry)
  local status = entry.bounty
  local classification = ClassifyBountyStatus(status)
  local bountyState = GG.Currencies:BountyState(status)
  GG.Widgets.SetItemIcon(slot.icon, status and status.iconFileID,
    GG.Season.BOUNTY and GG.Season.BOUNTY.iconTexture)
  slot.icon:SetAlpha(classification.iconAlpha)
  slot.icon:Show()
  local ring = classification.ringColor
  slot.capFrame:SetColorTexture(ring[1], ring[2], ring[3], ring[4] or 1)
  slot.capFrame:Show()

  if not slot.bountyTick then
    slot.bountyBacking = slot:CreateTexture(nil, "BORDER", nil, 1)
    slot.bountyBacking:SetColorTexture(unpack(Theme.background))
    slot.bountyBacking:SetSize(CurrencyGrid.ICON_SIZE, CurrencyGrid.ICON_SIZE)
    slot.bountyBacking:SetPoint("CENTER", slot.icon, "CENTER", 0, 0)
    slot.bountyTick = slot:CreateTexture(nil, "OVERLAY")
    slot.bountyTick:SetAtlas("common-icon-checkmark")
    slot.bountyTick:SetSize(12, 12)
    slot.bountyTick:SetPoint("TOP", slot.icon, "BOTTOM", 0, -1)
    slot.bountyDotBg = slot:CreateTexture(nil, "OVERLAY")
    slot.bountyDotBg:SetColorTexture(unpack(Theme.background))
    slot.bountyDotBg:SetSize(7, 7)
    slot.bountyDotBg:SetPoint("TOPRIGHT", slot.icon, "TOPRIGHT", 3, 3)
    slot.bountyDot = slot:CreateTexture(nil, "OVERLAY", nil, 1)
    slot.bountyDot:SetColorTexture(unpack(Theme.ready))
    slot.bountyDot:SetSize(5, 5)
    slot.bountyDot:SetPoint("CENTER", slot.bountyDotBg, "CENTER", 0, 0)
  end
  slot.bountyBacking:Show()
  slot.bountyTick:SetShown(bountyState == "done")
  slot.bountyDotBg:SetShown(classification.showPendingDot)
  slot.bountyDot:SetShown(classification.showPendingDot)

  slot.text:SetShown(bountyState ~= "done")
  slot.text:ClearAllPoints()
  slot.text:SetPoint("TOP", slot.icon, "BOTTOM", 1, -CurrencyGrid.TEXT_GAP)
  local wordKey = CurrencyGrid.BOUNTY_WORDS[bountyState]
  slot.text:SetText(wordKey and L[wordKey] or "-")
  slot.text:SetTextColor(unpack(wordKey and Theme.ready or CONST.ZERO_COLOR))
end

function CurrencyGrid.PositionStacked(row)
  local layout = CurrencyGrid.Layouts()
  local width = V.COL_CONTENT / CurrencyGrid.PER_ROW
  row.currencyCell:SetSize(V.COL_CONTENT, CurrencyGrid.VerticalRows() * V.CURRENCY_ROW_HEIGHT)
  for i, slot in ipairs(row.currencySlots) do
    local cell = layout.cells[i]
    if cell then
      slot:SetSize(width, CurrencyGrid.CELL_HEIGHT)
      slot:ClearAllPoints()
      slot:SetPoint("TOPLEFT", row.currencyCell, "TOPLEFT", cell.col * width,
        -(cell.row * V.CURRENCY_ROW_HEIGHT + V.CURRENCY_ROW_TOP))
    end
  end
  for i, rule in ipairs(row.currencyRules) do
    local ruleRow = layout.ruleRows[i]
    PlaceCurrencyRule(rule, row.currencyCell, ruleRow and 0, ruleRow and -ruleRow * V.CURRENCY_ROW_HEIGHT, V.COL_CONTENT, 1)
  end
end

function CurrencyGrid.PositionSideBySide(row)
  local _, layout = CurrencyGrid.Layouts()
  local width, height = CurrencyGrid.CELL_WIDTH, CurrencyGrid.CELL_HEIGHT
  local blockX = CurrencyGrid.BlockOffsets()
  row.currencyCell:SetSize(CurrencyGrid.Width(), height * CurrencyGrid.ROWS)
  for i, slot in ipairs(row.currencySlots) do
    local cell = layout.cells[i]
    if cell then
      slot:SetSize(width, height)
      slot:ClearAllPoints()
      slot:SetPoint("TOPLEFT", row.currencyCell, "TOPLEFT", blockX[cell.block] + cell.col * width, -cell.row * height)
    end
  end
  local half = math.floor(CurrencyGrid.BLOCK_GAP / 2)
  for i, rule in ipairs(row.currencyRules) do
    local nextBlock = blockX[i + 1]
    PlaceCurrencyRule(rule, row.currencyCell, nextBlock and nextBlock - half - 1, 0, 1, height * CurrencyGrid.ROWS)
  end
end

V.VAULT_TOP_PAD = 3
V.VAULT_DOT_GAP = 8
V.VAULT_SLOT_WIDTH = 28
V.VAULT_ROW_HEIGHT = 15
V.VAULT_FONT_SIZE = 10

V.RAID_WRAP_ROWS = 2
V.RAID_ICON_SIZE = 14
V.RAID_LINE_HEIGHT = V.RAID_ICON_SIZE + 2
V.RAID_DIFFICULTY_HEIGHT = V.RAID_WRAP_ROWS * V.RAID_LINE_HEIGHT
V.RAID_BAR_HEIGHT = 28
V.RAID_LEGEND_HEIGHT = 12
V.RAID_LEGEND_GAP = 4

function V.RaidBandHeight()
  local content = V.Theme().parts.bosses == "bar" and V.RAID_BAR_HEIGHT or V.RAID_DIFFICULTY_HEIGHT
  return content + V.RAID_LEGEND_HEIGHT
end

function CurrencyGrid.BossesAsBar()
  return V.Theme().parts.bosses == "bar"
end

function V.HideRaidLegend(bar)
  if not bar.legend then return end
  bar.legend:Hide()
  bar.legendLeft:Hide()
  bar.legendRight:Hide()
end

function V.PaintRaidLegend(raidCell, bar, text, color, yTop)
  if not bar.legend then
    bar.legend = CreateMonoLabel(raidCell, 10, color, true)
    bar.legendLeft = raidCell:CreateTexture(nil, "ARTWORK")
    bar.legendRight = raidCell:CreateTexture(nil, "ARTWORK")
    bar.legendLeft:SetHeight(1)
    bar.legendRight:SetHeight(1)
  end
  local centerY = yTop - V.RAID_LEGEND_HEIGHT / 2
  bar.legend:SetText(text)
  bar.legend:SetTextColor(unpack(color))
  bar.legend:ClearAllPoints()
  bar.legend:SetPoint("CENTER", raidCell, "TOP", 0, centerY)
  bar.legendLeft:SetColorTexture(color[1], color[2], color[3], 0.55)
  bar.legendRight:SetColorTexture(color[1], color[2], color[3], 0.55)
  bar.legendLeft:ClearAllPoints()
  bar.legendLeft:SetPoint("LEFT", raidCell, "TOPLEFT", 0, centerY)
  bar.legendLeft:SetPoint("RIGHT", bar.legend, "LEFT", -V.RAID_LEGEND_GAP, 0)
  bar.legendRight:ClearAllPoints()
  bar.legendRight:SetPoint("RIGHT", raidCell, "TOPRIGHT", 0, centerY)
  bar.legendRight:SetPoint("LEFT", bar.legend, "RIGHT", V.RAID_LEGEND_GAP, 0)
  bar.legend:Show()
  bar.legendLeft:Show()
  bar.legendRight:Show()
end

V.ROSTER_ROW_HEIGHT = 24

local VFONT = {}
VFONT.account = 12
VFONT.ilvl = 15
VFONT.rating = 15
VFONT.keyLevel = 12
VFONT.keyDungeon = 12
VFONT.noKey = 12
VFONT.name = 15
V.KEY_BADGE_HEIGHT = 20

local HFONT = {}
HFONT.account = 12
HFONT.ilvl = 15
HFONT.rating = 15
HFONT.keyLevel = 12
HFONT.keyDungeon = 12
HFONT.noKey = 12
HFONT.name = 15
HFONT.keyBadgeHeight = 20

V.TOP_PADDING = 12
V.BOTTOM_PADDING = 14

local function VisibleRaidDifficulties()
  local list = {}
  for _, difficultyID in ipairs(CONST.RAID_BAR_ORDER) do
    if IsRaidDifficultyVisible(difficultyID) then list[#list + 1] = difficultyID end
  end
  return list
end

local function BuildVerticalSections()
  local tok = V.Theme().tokens
  local titleHeight = tok.titleHeight or 28
  local headHeight = IsSectionVisible("avatar") and V.HEAD_HEIGHT or V.HEAD_HEIGHT_NO_AVATAR
  if tok.compactHeader then
    headHeight = math.min(headHeight, tok.headerHeight or headHeight)
  end
  local sections = {
    { key = "roster", height = V.ROSTER_ROW_HEIGHT, label = L["ROSTER_ROW_LABEL"], optionKey = "roster",
      extraVisible = function() return GG.RaidRosters ~= nil and GG.RaidRosters:HasActive() end },
    { key = "character", height = headHeight,
      label = L["LAYOUT_VERTICAL_SIDEBAR_TITLE"], sortKey = "character" },
    { key = "band_overview", band = "ROSTER_GROUP_OVERVIEW", group = { "account", "ilvl", "rating", "keystone" },
      height = titleHeight, block = "overview" },
    { key = "account",   height = V.DATA_ROW_HEIGHT, label = L["ROSTER_COL_ACCOUNT"],  optionKey = "account",  zebra = true, dataRow = true },
    { key = "ilvl",      height = V.DATA_ROW_HEIGHT, label = L["ROSTER_COL_ILVL"],     optionKey = "ilvl",     sortKey = "ilvl", zebra = true, dataRow = true },
    { key = "rating",    height = V.DATA_ROW_HEIGHT, label = L["ROSTER_COL_RATING"],   optionKey = "rating",   sortKey = "rating", zebra = true, dataRow = true },
    { key = "keystone",  height = V.DATA_ROW_HEIGHT, label = L["ROSTER_COL_KEYSTONE"], optionKey = "keystone", zebra = true, dataRow = true },
  }

  sections[#sections + 1] = { key = "band_weekly", band = "ROSTER_GROUP_WEEKLY", group = { "vault", "raid" },
    height = titleHeight, block = "weekly" }
  sections[#sections + 1] = {
    key = "vault",
    height = V.VAULT_HEIGHT,
    optionKey = "vault",
    vaultTiers = true,
  }

  local difficulties = VisibleRaidDifficulties()
  local bandHeight = V.RaidBandHeight()
  sections[#sections + 1] = {
    key = "raid",
    height = math.max(#difficulties, 1) * bandHeight,
    optionKey = "raids",
    zebraRows = { count = #difficulties, height = bandHeight, offset = 0 },
    difficulties = difficulties,
    bandHeight = bandHeight,
  }

  sections[#sections + 1] = { key = "band_quests", band = "ROSTER_GROUP_QUESTS", group = { "bounty" },
    height = titleHeight, block = "quests" }
  sections[#sections + 1] = {
    key = "bounty",
    height = V.QUESTS_HEIGHT,
    optionKey = "currencies",
    extraVisible = CurrencyGrid.QuestsVisible,
    zebra = true,
  }
  local currencyRows = CurrencyGrid.VerticalRows()
  sections[#sections + 1] = { key = "band_currencies", band = "ROSTER_GROUP_CURRENCIES", group = { "currencies" },
    height = titleHeight, block = "currencies" }
  sections[#sections + 1] = {
    key = "currencies",
    height = currencyRows * V.CURRENCY_ROW_HEIGHT,
    optionKey = "currencies",
    zebraRows = { count = currencyRows, height = V.CURRENCY_ROW_HEIGHT, offset = 0 },
    sidebarSolid = true,
    currencyLabels = true,
  }

  if tok.banner then
    sections[#sections + 1] = { key = "tail", height = tok.tailHeight or 20 }
  end

  return sections
end

local verticalSections = {}
local verticalTotalHeight = 0
local RebuildVerticalDecor

local function RebuildVerticalSections()
  verticalSections = BuildVerticalSections()
  local y = V.TOP_PADDING
  local map = {}
  for _, section in ipairs(verticalSections) do
    section.visible = IsSectionVisible(section.optionKey)
      and (section.extraVisible == nil or section.extraVisible())
  end
  local byKey = {}
  for _, section in ipairs(verticalSections) do byKey[section.key] = section end
  for _, section in ipairs(verticalSections) do
    if section.group then
      local any = false
      for _, key in ipairs(section.group) do
        if byKey[key] and byKey[key].visible then any = true end
      end
      section.visible = any
    end
  end
  for _, section in ipairs(verticalSections) do
    if section.visible then
      section.y = y
      y = y + section.height + (section.gapAfter or 0)
    else
      section.y = nil
    end
    map[section.key] = section
  end
  verticalTotalHeight = y + V.BOTTOM_PADDING
  RebuildVerticalDecor()
  return map
end

local verticalMap = {}

local verticalDecor = { bands = {}, sidebarBands = {}, rules = {}, glows = {}, layout = nil }

function RebuildVerticalDecor()
  local tok = V.Theme().tokens
  local layout = GG.RosterThemes.ColumnLayout(verticalSections)
  local drawsRule = tok.separator == "inset" or tok.separator == "full"
    or tok.separator == "block" or tok.separator == "gold"
  local glows = {}
  if tok.separator == "glow" then
    for _, rule in ipairs(layout.rules) do glows[#glows + 1] = rule.y end
  end
  verticalDecor = {
    bands = {}, sidebarBands = {},
    rules = drawsRule and layout.rules or {},
    glows = glows,
    layout = layout,
  }
end

local function PaintVerticalDecor(parent, store, forSidebar)
  local tok = V.Theme().tokens
  store.bands = store.bands or {}
  store.rules = store.rules or {}

  local bandList = (forSidebar and verticalDecor.sidebarBands) or verticalDecor.bands
  for i, band in ipairs(bandList) do
    local tex = store.bands[i]
    if not tex then
      tex = parent:CreateTexture(nil, "BACKGROUND", nil, -1)
      store.bands[i] = tex
    end
    local c = band.color
    tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -band.top)
    tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -band.top)
    tex:SetHeight(math.max(1, band.bottom - band.top))
    tex:Show()
  end
  for i = #bandList + 1, #store.bands do store.bands[i]:Hide() end

  local rules = forSidebar and {} or verticalDecor.rules
  local inset = tok.ruleInset or 0
  for i, rule in ipairs(rules) do
    local y = rule.y
    local c = (tok.blocks and rule.block and tok.blocks[rule.block]) or tok.rule or Theme.border
    local tex = store.rules[i]
    if not tex then
      tex = parent:CreateTexture(nil, "BORDER")
      tex:SetHeight(1)
      store.rules[i] = tex
    end
    tex:SetColorTexture(c[1], c[2], c[3], (c[4] or 1) * (tok.ruleAlpha or 1))
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -y)
    tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -y)
    tex:Show()
  end
  for i = #rules + 1, #store.rules do store.rules[i]:Hide() end
end

local function HideVerticalDecor(store)
  for _, tex in ipairs(store.bands or {}) do tex:Hide() end
  for _, tex in ipairs(store.rules or {}) do tex:Hide() end
end

local function IsVertical()
  return (GGDB and GGDB.options and GGDB.options.layoutMode) == "vertical"
end

local function CreateVaultGrid(row)
  local dots, cells = {}, {}
  for tierIndex = 1, #CONST.VAULT_TIER_TYPES do
    local dot = row.vaultCell:CreateTexture(nil, "ARTWORK")
    dot:SetSize(CONST.VAULT_DOT_SIZE, CONST.VAULT_DOT_SIZE)
    dot:SetPoint("LEFT", row.vaultCell, "TOPLEFT", 0, -(tierIndex - 1) * CONST.VAULT_ROW_HEIGHT - CONST.VAULT_ROW_HEIGHT / 2)
    dot:SetColorTexture(unpack(Theme[CONST.VAULT_TIER_DOT_COLOR_KEYS[tierIndex]]))
    dots[tierIndex] = dot

    cells[tierIndex] = {}
    for slotIndex = 1, 3 do
      local cell = CreateLabel(row.vaultCell, CONST.VAULT_SLOT_FONT_SIZE, Theme.textFaint, true)
      cell:SetJustifyH("CENTER")
      cell:SetWidth(CONST.VAULT_SLOT_WIDTH)
      cell.bg = row.vaultCell:CreateTexture(nil, "BORDER")
      cell:SetPoint("TOPLEFT", row.vaultCell, "TOPLEFT", CONST.VAULT_DOT_GAP + (slotIndex - 1) * CONST.VAULT_SLOT_WIDTH, -(tierIndex - 1) * CONST.VAULT_ROW_HEIGHT)
      cells[tierIndex][slotIndex] = cell
    end
  end
  row.vaultDots = dots
  return cells
end

local function CreateRaidBar(row, difficultyID)
  local bar = { segments = {}, difficultyID = difficultyID }
  bar.label = CreateMonoLabel(row.raidCell, 10, Theme.textFaint)
  bar.label:SetText(CONST.RAID_DIFFICULTY_DEFS[difficultyID].abbr)
  for i = 1, CONST.MAX_RAID_SEGMENTS do
    bar.segments[i] = GG.BossIcons:Create(row.raidCell)
  end

  bar.hitbox = CreateFrame("Frame", nil, row.raidCell)
  bar.hitbox:EnableMouse(true)
  bar.hitbox:SetScript("OnEnter", function(self)
    if row.datum and row.datum.rawRecord then
      ShowRaidTooltip(self, row.datum.rawRecord, difficultyID)
    end
  end)
  bar.hitbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
  bar.hitbox:Hide()

  return bar
end

local function HideRaidBar(bar)
  GG.RosterThemes.HideSegmentBar(bar)
  bar.label:Hide()
  V.HideRaidLegend(bar)
  for _, seg in ipairs(bar.segments) do seg:Hide() end
  bar.hitbox:Hide()
end

local function CreateQuestIcon(row, onEnter)
  local slot = {}

  slot.ring = row:CreateTexture(nil, "BORDER")
  slot.ring:SetSize(CONST.NEMESIS_ICON_SIZE + 4, CONST.NEMESIS_ICON_SIZE + 4)
  slot.ring:SetColorTexture(unpack(Theme.borderSoft))

  slot.backing = row:CreateTexture(nil, "BORDER", nil, 1)
  slot.backing:SetSize(CONST.NEMESIS_ICON_SIZE, CONST.NEMESIS_ICON_SIZE)
  slot.backing:SetPoint("CENTER", slot.ring, "CENTER", 0, 0)
  slot.backing:SetColorTexture(unpack(Theme.background))

  slot.icon = row:CreateTexture(nil, "ARTWORK")
  slot.icon:SetSize(CONST.NEMESIS_ICON_SIZE, CONST.NEMESIS_ICON_SIZE)
  slot.icon:SetPoint("CENTER", slot.ring, "CENTER", 0, 0)

  slot.badge = row:CreateFontString(nil, "OVERLAY")
  slot.badge:SetFont(Theme.fontBold, 9, "OUTLINE")
  slot.badge:SetPoint("BOTTOM", slot.ring, "BOTTOM", 1, 1)

  slot.check = row:CreateTexture(nil, "OVERLAY")
  slot.check:SetSize(CONST.DELVES_CHECK_SIZE, CONST.DELVES_CHECK_SIZE)
  slot.check:SetPoint("BOTTOMLEFT", slot.ring, "BOTTOMLEFT",
    CONST.DELVES_CHECK_OFFSET, CONST.DELVES_CHECK_OFFSET)
  slot.check:SetAtlas("common-icon-checkmark", true)
  slot.check:Hide()

  slot.dots = {}
  slot.dotBorders = {}
  for i = 1, CONST.QUEST_DOT_COUNT do
    local x = (i - (CONST.QUEST_DOT_COUNT + 1) / 2) * CONST.QUEST_DOT_STEP

    local border = row:CreateTexture(nil, "OVERLAY")
    border:SetTexture(Theme.media.dot)
    border:SetVertexColor(0, 0, 0, 1)
    border:SetSize(CONST.QUEST_DOT_BORDER_SIZE, CONST.QUEST_DOT_BORDER_SIZE)
    border:SetPoint("CENTER", slot.ring, "BOTTOM", x, -CONST.QUEST_DOT_CENTER_Y)
    border:Hide()
    slot.dotBorders[i] = border

    local dot = row:CreateTexture(nil, "OVERLAY", nil, 1)
    dot:SetTexture(Theme.media.dot)
    dot:SetSize(CONST.QUEST_DOT_SIZE, CONST.QUEST_DOT_SIZE)
    dot:SetPoint("CENTER", border, "CENTER", 0, 0)
    dot:Hide()
    slot.dots[i] = dot
  end

  slot.hitbox = CreateFrame("Button", nil, row)
  slot.hitbox:SetAllPoints(slot.ring)
  slot.hitbox:SetScript("OnEnter", function(self)
    if row.datum then onEnter(self, row.datum) end
  end)
  slot.hitbox:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return slot
end

local QUEST_ICONS = {
  nemesis = {
    tooltip = ShowNemesisTooltip,
    paint = function(datum)
      local st = ClassifyNemesisStatus(datum.nemesis)
      local complete = not st.pending
      local ring = Theme.borderSoft
      if complete then
        ring = Theme.success
      elseif st.hasFirst then
        ring = Theme.ready
      end
      return {
        icon = (datum.nemesis and datum.nemesis.iconFileID)
          or (GG.Season.NEMESIS and GG.Season.NEMESIS.iconFileID),
        ring = ring,
        check = complete,
        badge = (not complete)
          and (st.noData and "?" or (st.completedCount .. "/" .. st.total))
          or nil,
        badgeColor = st.hasFirst and Theme.ready or Theme.textMuted,
      }
    end,
  },
  keystone = {
    tooltip = CurrencyGrid.ShowCrackedKeystoneTooltip,
    paint = function(datum)
      local st = datum.crackedKeystone
      local complete = st ~= nil and st.completed == true
      local started = st ~= nil and not complete
        and (st.inProgress == true or (st.bagCount or 0) > 0)
      local ring = Theme.borderSoft
      if complete then
        ring = Theme.success
      elseif started then
        ring = Theme.ready
      end
      return {
        icon = GG.Season.CRACKED_KEYSTONE and GG.Season.CRACKED_KEYSTONE.iconTexture,
        ring = ring,
        check = complete,
        badge = (not complete) and (st == nil and "?" or nil) or nil,
        badgeColor = Theme.textMuted,
      }
    end,
  },
  kindojan = {
    tooltip = CurrencyGrid.ShowKindojanTooltip,
    paint = function(datum)
      local st = GG.Currencies:KindojanState(datum.kindojan)
      local ring, badgeColor = Theme.borderSoft, Theme.textMuted
      if st.complete then
        ring = Theme.success
      elseif st.canBuy then
        ring, badgeColor = CurrencyGrid.CAP_COLOR, CurrencyGrid.CAP_COLOR
      elseif st.done > 0 then
        ring, badgeColor = Theme.ready, Theme.ready
      end
      return {
        icon = GG.Season.KINDOJAN and GG.Season.KINDOJAN.iconTexture,
        ring = ring,
        check = st.complete == true,
        badge = st.noData and "?" or (st.done .. "/" .. st.total),
        badgeColor = badgeColor,
        dotsOn = (not st.noData) and st.bought or nil,
      }
    end,
  },
}

local function CreateRow(parent)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(CONST.ROW_HEIGHT)
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()

  row.accountCellBg = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  row.accountCellBg:Hide()

  row.accountText = CreateLabel(row, 12, Theme.textPrimary)

  row.dragSourceFill = row:CreateTexture(nil, "BACKGROUND", nil, 1)
  row.dragSourceFill:SetAllPoints()
  row.dragSourceFill:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.22)
  row.dragSourceFill:Hide()

  row.dragSourceBorderTop = row:CreateTexture(nil, "OVERLAY")
  row.dragSourceBorderTop:SetHeight(2)
  row.dragSourceBorderTop:SetPoint("TOPLEFT")
  row.dragSourceBorderTop:SetPoint("TOPRIGHT")
  row.dragSourceBorderTop:SetColorTexture(unpack(Theme.accent))
  row.dragSourceBorderTop:Hide()

  row.dragSourceBorderBottom = row:CreateTexture(nil, "OVERLAY")
  row.dragSourceBorderBottom:SetHeight(2)
  row.dragSourceBorderBottom:SetPoint("BOTTOMLEFT")
  row.dragSourceBorderBottom:SetPoint("BOTTOMRIGHT")
  row.dragSourceBorderBottom:SetColorTexture(unpack(Theme.accent))
  row.dragSourceBorderBottom:Hide()

  row.dragSourceBorderLeft = row:CreateTexture(nil, "OVERLAY")
  row.dragSourceBorderLeft:SetWidth(2)
  row.dragSourceBorderLeft:SetPoint("TOPLEFT")
  row.dragSourceBorderLeft:SetPoint("BOTTOMLEFT")
  row.dragSourceBorderLeft:SetColorTexture(unpack(Theme.accent))
  row.dragSourceBorderLeft:Hide()

  row.dragSourceBorderRight = row:CreateTexture(nil, "OVERLAY")
  row.dragSourceBorderRight:SetWidth(2)
  row.dragSourceBorderRight:SetPoint("TOPRIGHT")
  row.dragSourceBorderRight:SetPoint("BOTTOMRIGHT")
  row.dragSourceBorderRight:SetColorTexture(unpack(Theme.accent))
  row.dragSourceBorderRight:Hide()

  local function OnEquipmentClick(_, button)
    if button == "LeftButton" and IsShiftKeyDown() then
      if row.datum then GG.Links:InsertCharacterLink(row.datum) end
      return
    end
    if button == "RightButton" then
      if row.datum then GG.RosterUI:ConfirmHideCharacter(row.datum.key, row.datum.name, row.datum.realm) end
      return
    end
    if state.dragEditMode then return end
    if row.datum and row.datum.rawRecord and GG.UI and GG.UI.ShowEquipmentWindow then
      GG.UI:ShowEquipmentWindow(row.datum.rawRecord)
    end
  end
  row.equipmentHitbox = CreateFrame("Button", nil, row)
  row.equipmentHitbox:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.equipmentHitbox:SetScript("OnClick", OnEquipmentClick)

  row.ilvlHitbox = CreateFrame("Button", nil, row)
  row.ilvlHitbox:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.ilvlHitbox:SetScript("OnClick", OnEquipmentClick)
  row.ilvlHitbox:Hide()

  row.equipmentHitbox:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" and state.dragEditMode and row.datum then
      GG.RosterUI:StartRowDrag(row)
    end
  end)
  row.equipmentHitbox:SetScript("OnMouseUp", function(_, button)
    if button == "LeftButton" then GG.RosterUI:StopRowDrag() end
  end)
  function row.TooltipDatum()
    if state.dragEditMode then return nil end
    return row.datum
  end
  row.equipmentHitbox:SetScript("OnEnter", function(self)
    GG.CharacterTooltip:Show(self, row.TooltipDatum, row.ageFrame)
  end)
  row.equipmentHitbox:SetScript("OnLeave", function() GG.CharacterTooltip:Hide() end)
  row.mainRing = row:CreateTexture(nil, "BORDER")
  row.mainRing:SetSize(CONST.AVATAR_SIZE + 7, CONST.AVATAR_SIZE + 7)
  row.mainRing:SetColorTexture(unpack(Theme.gold))
  row.mainRing:Hide()

  row.avatarRing = row:CreateTexture(nil, "BORDER", nil, 1)
  row.avatarRing:SetSize(CONST.AVATAR_SIZE + 3, CONST.AVATAR_SIZE + 3)
  row.avatarRing:SetColorTexture(unpack(Theme.borderSoft))

  row.avatar = row:CreateTexture(nil, "ARTWORK")
  row.avatar:SetSize(CONST.AVATAR_SIZE, CONST.AVATAR_SIZE)
  row.avatar:SetPoint("CENTER", row.avatarRing, "CENTER", 0, 0)

  row.avatarModel = CreateFrame("PlayerModel", nil, row)
  row.avatarModel:SetSize(CONST.AVATAR_SIZE, CONST.AVATAR_SIZE)
  row.avatarModel:SetPoint("CENTER", row.avatarRing, "CENTER", 0, 0)
  row.avatarModel:SetPortraitZoom(1)
  row.avatarModel:Hide()

  row.levelText = CreateLabel(row, 10, Theme.textFaint)
  row.levelText:SetPoint("TOP", row.avatarRing, "BOTTOM", 0, -3)

  row.nameText = CreateLabel(row, 15, Theme.textPrimary)
  row.nameText:SetPoint("BOTTOMLEFT", row.avatar, "RIGHT", CONST.AVATAR_GAP, 2)

  row.realmText = CreateLabel(row, 10, Theme.textFaint)
  row.realmText:SetPoint("TOPLEFT", row.avatar, "RIGHT", CONST.AVATAR_GAP, -2)

  row.guildText = CreateLabel(row, 10, Theme.success)
  row.guildText:SetPoint("TOPLEFT", row.realmText, "BOTTOMLEFT", 0, -2)

  row.ageFrame = CreateFrame("Frame", nil, parent)
  row.ageFrame:SetSize(15, 15)
  row.ageBack = row.ageFrame:CreateTexture(nil, "ARTWORK")
  row.ageBack:SetTexture(Theme.media.dot)
  row.ageBack:SetVertexColor(0.04, 0.05, 0.07, 0.92)
  row.ageBack:SetAllPoints()
  row.ageIcon = row.ageFrame:CreateTexture(nil, "OVERLAY")
  row.ageIcon:SetSize(11, 11)
  row.ageIcon:SetPoint("CENTER", row.ageFrame, "CENTER", 0, 0)
  row.ageFrame:EnableMouse(true)
  row.ageFrame:SetScript("OnEnter", function(self)
    if not state.dragEditMode then
      GG.CharacterTooltip:Show(row.equipmentHitbox, row.TooltipDatum, self)
    elseif row.datum and row.datum.freshness then
      V.ShowFreshnessTooltip(self, row.datum)
    end
  end)
  row.ageFrame:SetScript("OnLeave", function()
    GameTooltip:Hide()
    GG.CharacterTooltip:Hide()
  end)
  row:HookScript("OnHide", function(self) self.ageFrame:Hide() end)
  row:HookScript("OnShow", function(self) self.ageFrame:SetShown(self.ageShown == true) end)
  row.mainBadge = CreateFrame("Frame", nil, row, "BackdropTemplate")
  row.mainBadge:SetHeight(16)
  ApplyBackdrop(row.mainBadge, { 0.910, 0.722, 0.361, 0.18 }, Theme.gold)
  local mainBadgeText = CreateLabel(row.mainBadge, 10, Theme.gold)
  mainBadgeText:SetPoint("CENTER", row.mainBadge, "CENTER", 0, 0)
  mainBadgeText:SetText(L["ROSTER_TAG_MAIN"])
  row.mainBadge:SetWidth(mainBadgeText:GetStringWidth() + 12)
  row.mainBadge.text = mainBadgeText

  row.rosterTags = {}
  for i = 1, 2 do
    local tag = GG.RaidRostersTab.CreateTag(row, false)
    tag.clickTarget = row.equipmentHitbox
    tag:SetFrameLevel(row.equipmentHitbox:GetFrameLevel() + 2)
    tag:Hide()
    row.rosterTags[i] = tag
  end

  row.ilvlText = CreateMonoLabel(row, 15, { 0.64, 0.21, 0.93, 1 })
  row.ratingText = CreateMonoLabel(row, 15, Theme.textMuted)
  row.ratingHitbox = CreateFrame("Frame", nil, row)

  row.keyBadge = CreateFrame("Frame", nil, row, "BackdropTemplate")
  row.keyBadge:SetHeight(20)
  ApplyBackdrop(row.keyBadge, { 1, 1, 1, 0.03 }, Theme.borderSoft)
  row.keyLevelText = CreateMonoLabel(row.keyBadge, 12, Theme.accentStrong)
  row.keyLevelText:SetPoint("LEFT", row.keyBadge, "LEFT", 6, 0)
  row.keyDungeonText = CreateLabel(row.keyBadge, 12, Theme.textMuted)
  row.keyDungeonText:SetPoint("LEFT", row.keyLevelText, "RIGHT", 4, 0)
  row.noKeyText = CreateLabel(row, 12, Theme.textFaint)
  row.noKeyText:SetText(L["ROSTER_NO_KEYSTONE"])
  row.keyHitbox = CreateFrame("Frame", nil, row)

  row.vaultCell = CreateFrame("Frame", nil, row)
  row.vaultCell:SetSize(CONST.VAULT_DOT_GAP + CONST.VAULT_SLOT_WIDTH * 3, CONST.VAULT_ROW_HEIGHT * #CONST.VAULT_TIER_TYPES)
  row.vaultGrid = CreateVaultGrid(row)

  row.vaultAlert = CreateLabel(row, 10, Theme.success, true)
  row.vaultAlert:SetText(L["VAULT_REWARDS_LABEL"])
  row.vaultAlert:Hide()
  row.vaultAlertBg = row:CreateTexture(nil, "BORDER")
  row.vaultAlertBg:SetColorTexture(Theme.success[1], Theme.success[2], Theme.success[3], 0.16)
  row.vaultAlertBg:SetPoint("TOPLEFT", row.vaultAlert, "TOPLEFT", -5, 1)
  row.vaultAlertBg:SetPoint("BOTTOMRIGHT", row.vaultAlert, "BOTTOMRIGHT", 5, -1)
  row.vaultAlertBg:Hide()
  row.vaultAlertHitbox = CreateFrame("Button", nil, row)
  row.vaultAlertHitbox:SetAllPoints(row.vaultAlert)
  row.vaultAlertHitbox:SetScript("OnClick", function() OpenVaultPreview(row) end)
  row.vaultAlertHitbox:Hide()

  row.raidCell = CreateFrame("Frame", nil, row)
  row.raidCell:SetSize(170, CONST.RAID_BAR_ROW_HEIGHT * #CONST.RAID_BAR_ORDER)
  row.raidBars = {}
  for _, difficultyID in ipairs(CONST.RAID_BAR_ORDER) do
    row.raidBars[difficultyID] = CreateRaidBar(row, difficultyID)
  end

  row.questAnchor = row:CreateTexture(nil, "BORDER")
  row.questAnchor:SetSize(CONST.NEMESIS_ICON_SIZE + 4, CONST.NEMESIS_ICON_SIZE + 4)
  row.questAnchor:Hide()

  row.questIcons = {}
  for _, key in ipairs(QUEST_ICON_ORDER) do
    row.questIcons[key] = CreateQuestIcon(row, QUEST_ICONS[key].tooltip)
  end

  row.currencyCell = CreateFrame("Frame", nil, row)
  row.currencyCell:SetSize(CurrencyGrid.Width(), CurrencyGrid.CELL_HEIGHT * CurrencyGrid.ROWS)
  row.currencyRules = {}
  for i = 1, CurrencyGrid.RULE_POOL do
    local rule = row.currencyCell:CreateTexture(nil, "BORDER")
    rule:SetColorTexture(1, 1, 1, 0.08)
    rule:Hide()
    row.currencyRules[i] = rule
  end
  row.currencySlots = {}
  for i = 1, CONST.MAX_CURRENCY_SLOTS do
    local slot = CreateFrame("Frame", nil, row.currencyCell)
    slot:SetSize(CurrencyGrid.CELL_WIDTH, CurrencyGrid.CELL_HEIGHT)
    slot:EnableMouse(true)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetSize(CurrencyGrid.ICON_SIZE, CurrencyGrid.ICON_SIZE)
    slot.icon:SetPoint("TOP", slot, "TOP", 0, -CurrencyGrid.ICON_TOP)
    slot.capFrame = slot:CreateTexture(nil, "BORDER")
    slot.capFrame:SetColorTexture(unpack(CurrencyGrid.CAP_COLOR))
    slot.capFrame:SetSize(CurrencyGrid.ICON_SIZE + 2, CurrencyGrid.ICON_SIZE + 2)
    slot.capFrame:SetPoint("CENTER", slot.icon, "CENTER", 0, 0)
    slot.capFrame:Hide()
    slot.text = CreateMonoLabel(slot, 10, Theme.textMuted)
    slot.text:SetPoint("TOP", slot.icon, "BOTTOM", 0, -CurrencyGrid.TEXT_GAP)
    slot.text:SetWidth(CurrencyGrid.CELL_WIDTH + 8)
    slot.text:SetJustifyH("CENTER")
    slot:SetScript("OnEnter", function(self)
      if not self.entry then return end
      if self.entry.kind == "bounty" then
        if row.datum then ShowBountyTooltip(self, row.datum) end
        return
      end
      local entry = self.entry
      GG.Tip:Open(self, { family = "money", anchor = "TOP" }, function(t)
        if entry.kind == "currency" then
          GG.Tip.DrawCurrency(t, entry.data, L)
        else
          t:Head({ title = entry.data.name or "?", right = entry.data.quantity or 0 })
        end
      end)
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    row.currencySlots[i] = slot
  end

  row:SetScript("OnEnter", function(self)
    if not self.datum then return end
    if not GG.RosterThemes.SetHover(self, true) then self.bg:SetColorTexture(unpack(Theme.rowHover)) end
  end)
  row:SetScript("OnLeave", function(self)
    if not self.datum then return end
    GG.RosterThemes.SetHover(self, false)
    self.bg:SetColorTexture(unpack(self.baseRowColor or { 0, 0, 0, 0 }))
  end)
  row:SetScript("OnClick", function(self, button)
    if button == "RightButton" and self.datum then
      GG.RosterUI:ConfirmHideCharacter(self.datum.key, self.datum.name, self.datum.realm)
    end
  end)

  local function WireTooltipCell(cell, showTooltip)
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", function(self)
      if row.datum and row.datum.rawRecord then showTooltip(self, row.datum.rawRecord) end
    end)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  WireTooltipCell(row.ratingHitbox, ShowRatingTooltip)
  WireTooltipCell(row.keyHitbox, ShowKeystoneTooltip)
  WireTooltipCell(row.vaultCell, ShowVaultTooltip)

  return row
end

local function PaintVaultGrid(row, record)
  local isCurrentWeek = GG.Vault:IsCurrentWeek(record)
  local blockW, blockH = 22, 12
  local rowHeight = CONST.VAULT_ROW_HEIGHT
  if IsVertical() then blockW, blockH, rowHeight = 22, 12, V.VAULT_ROW_HEIGHT end
  local tierColors = { nil, Theme.teal, Theme.gold }
  for tierIndex, tierDef in ipairs(CONST.VAULT_TIER_TYPES) do
    local slots = CollectVaultTierSlots(record, tierDef.type)
    for slotIndex = 1, 3 do
      local cell = row.vaultGrid[tierIndex][slotIndex]
      local slot = slots[slotIndex]
      cell.bg:ClearAllPoints()
      cell.bg:SetSize(blockW, blockH)
      cell.bg:SetPoint("TOPLEFT", cell, "TOPLEFT", (cell:GetWidth() - blockW) / 2, -(rowHeight - blockH) / 2 + 1)
      if not slot then
        cell:SetText("")
        cell.bg:Hide()
      elseif isCurrentWeek and slot.unlocked then
        local text, color = VaultSlotDisplay(slot)
        local blockColor = tierColors[tierIndex] or color
        cell:SetText(text)
        cell:SetTextColor(0.07, 0.07, 0.09, 1)
        cell.bg:SetColorTexture(blockColor[1], blockColor[2], blockColor[3], 0.95)
        cell.bg:Show()
      else
        cell:SetText("")
        cell.bg:SetColorTexture(0.17, 0.19, 0.24, 1)
        cell.bg:Show()
      end
    end
  end
end

local function PaintRaidBar(raidCell, bar, slots, totalSegments, width, color, yOffset, rowHeight, opts)
  opts = opts or {}
  local wrapRows = opts.wrapRows or 1
  local showLabel = opts.showLabel ~= false

  bar.label:ClearAllPoints()
  bar.label:SetPoint("TOPLEFT", raidCell, "TOPLEFT", 0, yOffset)
  bar.label:SetShown(showLabel)

  bar.hitbox:ClearAllPoints()
  bar.hitbox:SetPoint("TOPLEFT", raidCell, "TOPLEFT", 0, yOffset)
  bar.hitbox:SetSize(raidCell:GetWidth(), rowHeight)
  bar.hitbox:Show()

  if opts.legend then
    V.PaintRaidLegend(raidCell, bar, opts.legend, color, yOffset)
    yOffset = yOffset - V.RAID_LEGEND_HEIGHT
    rowHeight = rowHeight - V.RAID_LEGEND_HEIGHT
  else
    V.HideRaidLegend(bar)
  end

  if opts.style == "bar" then
    for _, seg in ipairs(bar.segments) do seg:Hide() end
    local labelSpace = showLabel and 14 or 0
    GG.RosterThemes.PaintSegmentBar(raidCell, bar, slots, totalSegments, labelSpace, yOffset,
      width + labelSpace, rowHeight, color)
    return
  end
  GG.RosterThemes.HideSegmentBar(bar)

  local gap = CONST.RAID_BAR_ICON_GAP

  local style = GG.BossIcons:GetStyle()
  local function PaintSegmentColor(seg, index)
    GG.BossIcons:Paint(seg, slots and slots[index] == true, color, index,
      GG.BossIcons:LetterForSlot(index), style)
  end

  local skulls = GG.BossIcons:IsInterlocking(style)
  if skulls and (wrapRows >= 2 or rowHeight >= CONST.RAID_INTERLOCK_MIN_LINE_HEIGHT) then
    local labelSpace = showLabel and CONST.RAID_INTERLOCK_LABEL_SPACE or 0
    local size, positions = GG.BossIcons:Interlock(totalSegments, width - (showLabel and 5 or 0),
      rowHeight, CONST.RAID_INTERLOCK_ICON_SIZE, GG.BossIcons:PixelsPerUnit(raidCell))
    local leftEdge = showLabel and positions[1] and positions[1].x or 0
    if showLabel then
      bar.label:ClearAllPoints()
      bar.label:SetPoint("LEFT", raidCell, "TOPLEFT", 0, yOffset - rowHeight / 2)
    end
    for i = 1, CONST.MAX_RAID_SEGMENTS do
      local seg = bar.segments[i]
      local pos = positions[i]
      if pos then
        seg:ClearAllPoints()
        seg:SetSize(size, size)
        seg:SetPoint("TOPLEFT", raidCell, "TOPLEFT", labelSpace + pos.x - leftEdge, yOffset - pos.y)
        PaintSegmentColor(seg, i)
        seg:Show()
      else
        seg:Hide()
      end
    end
    return
  end

  if wrapRows <= 1 then
    if skulls then gap = CONST.RAID_SKULL_LINE_GAP end
    local iconSize = math.max(4, math.min(
      math.floor((width - (totalSegments - 1) * gap) / math.max(totalSegments, 1)),
      rowHeight
    ))
    local lineStep = iconSize + gap
    if skulls then
      iconSize, lineStep = GG.BossIcons:SnapLine(iconSize, gap, GG.BossIcons:PixelsPerUnit(raidCell))
    end
    local x = 0
    for i = 1, CONST.MAX_RAID_SEGMENTS do
      local seg = bar.segments[i]
      if i <= totalSegments then
        seg:ClearAllPoints()
        seg:SetSize(iconSize, iconSize)
        seg:SetPoint("LEFT", bar.label, "RIGHT", 5 + x, 0)
        PaintSegmentColor(seg, i)
        seg:Show()
        x = x + lineStep
      else
        seg:Hide()
      end
    end
    return
  end

  if wrapRows == 2 then
    local size, positions = GG.BossIcons:Honeycomb(totalSegments, width, rowHeight,
      opts.iconSize or rowHeight / 2, gap)
    for i = 1, CONST.MAX_RAID_SEGMENTS do
      local seg = bar.segments[i]
      local pos = positions[i]
      if pos then
        seg:ClearAllPoints()
        seg:SetSize(size, size)
        seg:SetPoint("TOPLEFT", raidCell, "TOPLEFT", pos.x, yOffset - pos.y)
        PaintSegmentColor(seg, i)
        seg:Show()
      else
        seg:Hide()
      end
    end
    return
  end

  local perRow = math.ceil(totalSegments / wrapRows)
  local lineHeight = rowHeight / wrapRows
  local iconSize = math.max(4, math.min(
    opts.iconSize or lineHeight,
    math.floor((width - (perRow - 1) * gap) / math.max(perRow, 1)),
    lineHeight
  ))

  local function RowStartX(count)
    local rowWidth = count * iconSize + math.max(0, count - 1) * gap
    return math.max(0, (width - rowWidth) / 2)
  end

  for i = 1, CONST.MAX_RAID_SEGMENTS do
    local seg = bar.segments[i]
    if i <= totalSegments then
      local col = (i - 1) % perRow
      local line = math.floor((i - 1) / perRow)
      local countInLine = math.min(perRow, totalSegments - line * perRow)
      seg:ClearAllPoints()
      seg:SetSize(iconSize, iconSize)
      seg:SetPoint("TOPLEFT", raidCell, "TOPLEFT",
        RowStartX(countInLine) + col * (iconSize + gap),
        yOffset - line * lineHeight - (lineHeight - iconSize) / 2)
      PaintSegmentColor(seg, i)
      seg:Show()
    else
      seg:Hide()
    end
  end
end

local function ApplyDelvesAlignment(row)
  local checks = V.Theme().parts.quests == "checks"
  local gap = checks and GG.RosterThemes.CHECK_GAP or (CONST.NEMESIS_ICON_GAP - 2)
  local previous = nil
  local shownCount = 0
  for _, key in ipairs(QUEST_ICON_ORDER) do
    local slot = row.questIcons[key]
    if slot.shown ~= false then
      shownCount = shownCount + 1
      slot.ring:ClearAllPoints()
      if previous then
        slot.ring:SetPoint("LEFT", previous, "RIGHT", gap, 0)
      else
        slot.ring:SetPoint("LEFT", row.questAnchor, "LEFT", 0, 0)
      end
      previous = slot.ring
    end
  end

  if not IsVertical() or not row.questsVerticalY then return end
  local extra = math.max(shownCount - 1, 0)
  local step = checks and (GG.RosterThemes.CHECK_SIZE + GG.RosterThemes.CHECK_GAP)
    or (CONST.NEMESIS_ICON_SIZE + CONST.NEMESIS_ICON_GAP)
  local shift = extra * step / 2
  row.questAnchor:ClearAllPoints()
  row.questAnchor:SetPoint("TOP", row, "TOP", -shift, -row.questsVerticalY)
end

local function LayoutIdentity(row)
  local count = row.rosterTagCount or 0
  if IsVertical() then
    local top = row.rosterTagTop
    local totalW = 0
    for i = 1, count do totalW = totalW + row.rosterTags[i]:GetWidth() + (i > 1 and 4 or 0) end
    local x = -totalW / 2
    for i, tag in ipairs(row.rosterTags) do
      if top and i <= count then
        tag:ClearAllPoints()
        tag:SetPoint("TOPLEFT", row, "TOP", x, top)
        x = x + tag:GetWidth() + 4
      else
        tag:Hide()
      end
    end
    if not (row.compactIdentity and row.identityAnchor) then return end
    count = 0
  end
  local anchor = row.identityAnchor
  if not anchor then return end
  local TAG_GAP, LINE_GAP = 3, 1
  local lines = { row.nameText, row.realmText }
  if row.guildText:IsShown() then lines[#lines + 1] = row.guildText end
  if row.levelText:IsShown() then lines[#lines + 1] = row.levelText end
  local heights, total = {}, 0
  for i, fs in ipairs(lines) do
    local h = fs:GetStringHeight()
    if not h or h <= 0 then
      local _, size = fs:GetFont()
      h = (size or 12) + 1
    end
    heights[i] = math.ceil(h)
    total = total + heights[i] + (i > 1 and LINE_GAP or 0)
  end
  local tagH = count > 0 and (row.rosterTags[1]:GetHeight() + TAG_GAP) or 0
  local y = (anchor.y or 0) + (total + tagH) / 2
  local x = anchor.x
  for i = 1, count do
    local tag = row.rosterTags[i]
    tag:ClearAllPoints()
    tag:SetPoint("TOPLEFT", anchor.frame, anchor.point, x, y)
    x = x + tag:GetWidth() + 4
  end
  y = y - tagH
  for i, fs in ipairs(lines) do
    if i > 1 then y = y - LINE_GAP end
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", anchor.frame, anchor.point, anchor.x, y)
    y = y - heights[i]
  end
end

function V.PaintGauges(row, datum)
  local store = row.gauges or {}
  row.gauges = store
  local geom = row.gaugeGeom
  local RT = GG.RosterThemes
  if V.Theme().parts.nums ~= "gauge" or not geom then
    RT.HideGauge(store, "ilvl")
    RT.HideGauge(store, "rating")
    return
  end
  local range = state.ilvlRange or {}
  if geom.ilvl and row.ilvlText:IsShown() then
    local lo = (range.min or datum.ilvl or 0) - 2
    RT.PaintGauge(row, store, "ilvl", geom.ilvl.x, geom.ilvl.y, geom.ilvl.w,
      RT.GaugePct(datum.ilvl, lo, range.max or datum.ilvl), { 0.64, 0.21, 0.93, 1 })
  else
    RT.HideGauge(store, "ilvl")
  end
  if geom.rating and row.ratingText:IsShown() then
    RT.PaintGauge(row, store, "rating", geom.rating.x, geom.rating.y, geom.rating.w,
      RT.GaugePct(datum.rating, 800, 3000), datum.rating >= 2000 and Theme.gold or Theme.textMuted)
  else
    RT.HideGauge(store, "rating")
  end
end

function V.FreshnessAge(age)
  return GG.CharacterTooltip.FormatAge(age)
end

function V.FreshnessText(f)
  if f.live then return L["FRESH_LIVE"], Theme.success, Theme.media.dot end
  local text = L["FRESH_AGO"]:format(V.FreshnessAge(f.age))
  if f.stale then return text, Theme.gold, Theme.media.clock end
  return text, Theme.textMuted, Theme.media.clock
end

V.SYNC_ICON_GAP = "    "

function V.PaintSyncStatus(label, accounts)
  state.syncIcons = state.syncIcons or {}
  if not state.syncMeasure then
    state.syncMeasure = label:GetParent():CreateFontString(nil, "OVERLAY")
    state.syncMeasure:Hide()
  end
  local measure = state.syncMeasure
  measure:SetFont(label:GetFont())
  local function width(s)
    measure:SetText(s)
    return measure:GetStringWidth() or 0
  end

  local text, placed = "", {}
  for i, account in ipairs(accounts) do
    local f = { live = account.live, age = account.age or 0,
      stale = (account.age or 0) > GG.Roster.STALE_AFTER_SECONDS }
    local words, color, iconPath = V.FreshnessText(f)
    if i > 1 then text = text .. "     " end
    text = text .. (account.label or "?") .. " "
    placed[i] = { x = width(text), color = color, path = iconPath }
    text = text .. V.SYNC_ICON_GAP .. ("|cff%02x%02x%02x%s|r"):format(
      math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), words)
  end
  label:SetText(text)

  local gap = width(V.SYNC_ICON_GAP)
  for i = 1, math.max(#placed, #state.syncIcons) do
    local icon = state.syncIcons[i]
    if not icon and placed[i] then
      icon = label:GetParent():CreateTexture(nil, "OVERLAY")
      icon:SetSize(11, 11)
      state.syncIcons[i] = icon
    end
    if icon then
      local p = placed[i]
      icon.used = p ~= nil
      if p then
        icon:SetTexture(p.path)
        icon:SetVertexColor(p.color[1], p.color[2], p.color[3], 1)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", label, "LEFT", p.x + (gap - 11) / 2, 0)
      end
      icon:SetShown(icon.used and label:IsShown())
    end
  end
end

function V.NameWithClock(datum, showAvatar)
  local clock = not showAvatar and GG.Roster:ClockState(datum.freshness)
  if not clock then return datum.name end
  local _, color, icon = V.FreshnessText(datum.freshness)
  return ("|T%s:10:10:0:0:32:32:0:32:0:32:%d:%d:%d|t %s"):format(icon,
    math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), datum.name)
end

function V.PaintFreshness(row, datum)
  local f = datum.freshness
  local clock = GG.Roster:ClockState(f)
  row.ageShown = clock ~= nil
  if not clock then
    row.ageFrame:Hide()
    return
  end
  row.ageFrame:SetFrameLevel(row:GetFrameLevel() + 8)
  row.ageFrame:ClearAllPoints()
  local onAvatar = IsSectionVisible("avatar")
  row.ageBack:SetShown(onAvatar)
  row.ageIcon:SetShown(onAvatar)
  if onAvatar then
    local _, color, icon = V.FreshnessText(f)
    row.ageIcon:SetTexture(icon)
    row.ageIcon:SetVertexColor(color[1], color[2], color[3], 1)
    row.ageFrame:SetPoint("CENTER", row.avatar, "BOTTOMRIGHT", -1, 1)
  elseif not IsVertical() or row.compactIdentity == true then
    row.ageFrame:SetPoint("LEFT", row.nameText, "LEFT", 0, 0)
  else
    row.ageFrame:SetPoint("LEFT", row.nameText, "CENTER", -row.nameText:GetStringWidth() / 2, 0)
  end
  row.ageFrame:SetShown(row:IsShown())
end

function V.ShowFreshnessTooltip(owner, datum)
  local f = datum.freshness
  local account = datum.accountLabel or "?"
  local accountRich = "*" .. account .. "*"
  GG.Tip:Open(owner, { family = "ui" }, function(t)
    if f.live then
      t:Title(L["FRESH_TIP_LIVE_TITLE"], Theme.success)
      t:Text(L["FRESH_TIP_LIVE"]:format(accountRich))
    else
      t:Title(L["FRESH_TIP_TITLE"]:format(V.FreshnessAge(f.age)), f.stale and Theme.gold or Theme.textPrimary)
      t:Text(L["FRESH_TIP_OFFLINE"]:format(accountRich))
      t:Text(L["FRESH_TIP_HINT"]:format(account), Theme.gold, true)
    end
  end)
end

local function PaintRow(row, datum, dataIndex)
  row.datum = datum

  local showAvatar = IsSectionVisible("avatar")
  row.avatarRing:SetShown(showAvatar)
  if not showAvatar then
    row.avatar:Hide()
    row.avatarModel:Hide()
  elseif datum.isCurrent then
    row.avatar:Hide()
    row.avatarModel:Show()
    row.avatarModel:SetUnit("player")
  else
    row.avatarModel:Hide()
    row.avatar:Show()
    GG.Widgets.SetClassIcon(row.avatar, CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[datum.class])
  end

  if datum.level and datum.level > 0 then
    row.levelText:SetText(L["ROSTER_LEVEL_FORMAT"]:format(datum.level))
    row.levelText:Show()
  else
    row.levelText:Hide()
  end

  row.nameText:SetText(V.NameWithClock(datum, showAvatar))
  local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[datum.class]
  if classColor then
    row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
    row.avatarRing:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.6)
  else
    row.nameText:SetTextColor(unpack(Theme.textPrimary))
    row.avatarRing:SetColorTexture(unpack(Theme.borderSoft))
  end
  row.mainRing:SetShown(datum.isMain and showAvatar)
  row.realmText:SetText(datum.realm)

  if datum.guild and datum.guild ~= "" and IsSectionVisible("guild") then
    row.guildText:SetText(datum.guild)
    row.guildText:Show()
  else
    row.guildText:Hide()
  end

  local rrTags = (GG.RaidRostersTab and GG.RaidRostersTab:TagsVisible())
    and GG.RaidRosters:TagsFor(datum.key, datum.rawRecord) or {}
  row.rosterTagCount = math.min(#rrTags, #row.rosterTags)
  for i, tag in ipairs(row.rosterTags) do
    if rrTags[i] then
      GG.RaidRostersTab.PaintTag(tag, rrTags[i])
      tag:Show()
    else
      tag:Hide()
    end
  end
  local leftStack = not IsVertical() or row.compactIdentity == true
  if leftStack and row.identityAvail then
    row.nameText:SetWidth(math.max(20, row.identityAvail - (datum.isMain and (row.mainBadge:GetWidth() + 6) or 0)))
  end

  row.mainBadge:SetShown(datum.isMain)
  if datum.isMain then
    local badgeW = row.mainBadge.text and row.mainBadge.text:GetStringWidth() or 0
    if not badgeW or badgeW <= 0 then badgeW = #(L["ROSTER_TAG_MAIN"] or "Main") * 6 end
    row.mainBadge:SetWidth(math.ceil(badgeW) + 12)
    row.mainBadge:ClearAllPoints()
    if IsVertical() and not leftStack then
      local textEnd = (row.nameText:GetWidth() + row.nameText:GetStringWidth()) / 2
      row.mainBadge:SetPoint("LEFT", row.nameText, "LEFT", textEnd + 4, 0)
    else
      row.mainBadge:SetPoint("LEFT", row.nameText, "LEFT", row.nameText:GetStringWidth() + 6, 0)
    end
  end

  LayoutIdentity(row)

  local accountColVisible = columnLayout.account.visible
  row.accountText:SetShown(accountColVisible)
  if accountColVisible then
    local accountStyle = (GGDB.options and GGDB.options.accountLabelStyle) or "cuenta"
    row.accountText:SetFont(Theme.font, AccountTextFontSize(accountStyle), "")
    row.accountText:SetText(datum.accountLabel or "")
    local pillWidth = row.accountText:GetStringWidth() + 20
    if not IsVertical() then pillWidth = math.min(pillWidth, columnLayout.account.width - CONST.LIST_ACCOUNT_INSET - 6) end
    row.accountCellBg:SetWidth(math.max(40, pillWidth))
    do
      local colors = CONST.ACCOUNT_COLORS
      local c = colors[((datum.accountSlot or 1) - 1) % #colors + 1]
      row.accountCellBg:Show()
      row.accountCellBg:SetColorTexture(c[1], c[2], c[3], 0.18)
      row.accountText:SetTextColor(c[1], c[2], c[3], 1)
    end
  else
    row.accountCellBg:Hide()
  end

  row.ilvlText:SetText(FormatIlvl(datum.ilvl))

  row.ratingText:SetText(datum.rating > 0 and tostring(datum.rating) or "—")
  row.ratingText:SetTextColor(unpack(datum.rating >= 2000 and Theme.gold or Theme.textMuted))
  V.PaintGauges(row, datum)

  local keystoneColVisible = columnLayout.keystone.visible
  if keystoneColVisible and datum.keystone then
    local level = datum.keystone.level or 0
    local tierColor = level >= 10 and Theme.gold or (level >= 9 and Theme.teal or Theme.accentStrong)
    row.keyLevelText:SetText("+" .. level)
    row.keyLevelText:SetTextColor(unpack(tierColor))
    row.keyDungeonText:SetText(AbbreviateDungeonName(datum.keystone.challengeModeID, datum.keystone.dungeon))
    row.keyBadge:SetWidth(row.keyLevelText:GetStringWidth() + row.keyDungeonText:GetStringWidth() + 16)
    row.keyBadge:Show()
    row.noKeyText:Hide()
  elseif keystoneColVisible then
    row.keyBadge:Hide()
    row.noKeyText:Show()
  else
    row.keyBadge:Hide()
    row.noKeyText:Hide()
  end

  PaintVaultGrid(row, datum.rawRecord)
  local showVaultAlert = columnLayout.vault.visible and datum.vault.hasAvailableRewards
  row.vaultAlert:SetShown(showVaultAlert)
  row.vaultAlertBg:SetShown(showVaultAlert)
  if not IsVertical() and columnLayout.vault.visible then
    row.vaultCell:ClearAllPoints()
    row.vaultCell:SetPoint("LEFT", row, "LEFT", columnLayout.vault.x + CONST.CELL_PADDING, showVaultAlert and 8 or 0)
  end
  row.vaultAlertHitbox:SetShown(showVaultAlert)

  local totalSegments = datum.raidProgress.totalSegments
  local visibleDifficulties = {}
  for _, difficultyID in ipairs(CONST.RAID_BAR_ORDER) do
    if IsRaidDifficultyVisible(difficultyID) then
      table.insert(visibleDifficulties, difficultyID)
    else
      HideRaidBar(row.raidBars[difficultyID])
    end
  end

  local vertical = IsVertical()
  local bossBar = V.Theme().parts.bosses == "bar"
  local lineHeight = vertical and V.RaidBandHeight() or CONST.RAID_BAR_ROW_HEIGHT
  local startY = 0
  if not vertical then
    local cellHeight = CONST.RAID_BAR_ROW_HEIGHT * #CONST.RAID_BAR_ORDER
    if CurrencyGrid.RaidZigzagInRows() then lineHeight = CONST.RAID_INTERLOCK_LINE_HEIGHT end
    local usedHeight = lineHeight * #visibleDifficulties
    startY = -(cellHeight - usedHeight) / 2
  end
  local raidOpts = vertical
    and { wrapRows = V.RAID_WRAP_ROWS, showLabel = false, iconSize = V.RAID_ICON_SIZE }
    or {}
  if bossBar then raidOpts.style = "bar" end
  local barWidth = row.raidCell:GetWidth() - (vertical and 0 or 14)

  for i, difficultyID in ipairs(visibleDifficulties) do
    local bar = row.raidBars[difficultyID]
    local progress = datum.raidProgress.byDifficulty[difficultyID]
    raidOpts.legend = vertical and L[CONST.RAID_DIFFICULTY_DEFS[difficultyID].labelKey] or nil
    PaintRaidBar(
      row.raidCell, bar, progress.slots, totalSegments, barWidth,
      CONST.RAID_DIFFICULTY_DEFS[difficultyID].color,
      startY - (i - 1) * lineHeight,
      lineHeight,
      raidOpts
    )
  end

  local RT = GG.RosterThemes
  local checks = V.Theme().parts.quests == "checks"
  local checkHole = checks and RT.SurfaceColor(V.Theme(), datum.isCurrent, IsVertical()) or nil
  local function CheckRing(color)
    return (color == Theme.borderSoft or not color) and RT.COLORS.checkIdle or color
  end
  local anchorSize = checks and RT.CHECK_SIZE or (CONST.NEMESIS_ICON_SIZE + 4)
  row.questAnchor:SetSize(anchorSize, anchorSize)

  for _, key in ipairs(QUEST_ICON_ORDER) do
    local slot = row.questIcons[key]
    local shown = columnLayout.currencies.visible and QUEST_ICON_VISIBLE[key]()
    slot.shown = shown
    local slotSize = checks and RT.CHECK_SIZE or (CONST.NEMESIS_ICON_SIZE + 4)
    slot.ring:SetSize(slotSize, slotSize)
    slot.ring:SetShown(shown and not checks)
    slot.backing:SetShown(shown and not checks)
    slot.icon:SetShown(shown and not checks)
    slot.hitbox:SetShown(shown)
    slot.badge:SetShown(false)
    slot.check:SetShown(false)
    local dotsOn = shown and QUEST_ICONS[key].paint(datum).dotsOn or nil
    for i, dot in ipairs(slot.dots) do
      dot:SetShown(dotsOn ~= nil)
      slot.dotBorders[i]:SetShown(dotsOn ~= nil)
      if dotsOn then
        dot:SetVertexColor(unpack(i <= dotsOn and CONST.QUEST_DOT_ON or CONST.ZERO_COLOR))
      end
    end

    if shown and checks then
      local paint = QUEST_ICONS[key].paint(datum)
      RT.PaintCheck(row, slot, slot.ring, CheckRing(paint.ring), paint.check == true, checkHole)
    else
      RT.HideCheck(slot)
    end
    if shown and not checks then
      local paint = QUEST_ICONS[key].paint(datum)
      GG.Widgets.SetItemIcon(slot.icon, paint.icon)
      local ring = paint.ring or Theme.borderSoft
      slot.ring:SetColorTexture(ring[1], ring[2], ring[3], ring[4] or 1)
      slot.check:SetShown(paint.check == true)
      if paint.badge and not paint.check then
        slot.badge:SetText(paint.badge)
        slot.badge:SetTextColor(unpack(paint.badgeColor or Theme.textMuted))
        slot.badge:Show()
      end
    end
  end
  ApplyDelvesAlignment(row)

  for _, slot in ipairs(row.currencySlots) do
    slot.entry = nil
    slot:Hide()
    slot.capFrame:Hide()
    slot.text:Show()
    if slot.bountyTick then
      slot.text:ClearAllPoints()
      slot.text:SetPoint("TOP", slot.icon, "BOTTOM", 0, -CurrencyGrid.TEXT_GAP)
      slot.bountyBacking:Hide()
      slot.bountyTick:Hide()
      slot.bountyDotBg:Hide()
      slot.bountyDot:Hide()
    end
  end
  for _, entry in ipairs(datum.currencies) do
    local slot = row.currencySlots[entry.slot]
    if slot and entry.kind == "bounty" then
      slot.entry = entry
      CurrencyGrid.PaintBountySlot(slot, entry)
      slot:Show()
    elseif slot then
      slot.entry = entry
      local iconFileID = entry.data.iconFileID
      if iconFileID and iconFileID ~= 0 then
        GG.Widgets.SetItemIcon(slot.icon, iconFileID)
        slot.icon:Show()
      else
        slot.icon:Hide()
      end
      local quantity = entry.data.quantity or 0
      slot.text:SetText(GG.Currencies:FormatAmount(quantity, L["NUMBER_DECIMAL_SEPARATOR"]))
      local atCap = entry.kind == "currency" and GG.Currencies:IsAtCap(entry.data)
      local color = Theme.textPrimary
      if quantity == 0 then
        color = CONST.ZERO_COLOR
      elseif atCap then
        color = CurrencyGrid.CAP_COLOR
      end
      slot.text:SetTextColor(unpack(color))
      slot.capFrame:SetColorTexture(unpack(CurrencyGrid.CAP_COLOR))
      slot.capFrame:SetShown(atCap and slot.icon:IsShown())
      slot.icon:SetAlpha(quantity == 0 and 0.4 or 1)
      slot:Show()
    end
  end

  local tokens = V.Theme().tokens
  row.baseRowColor = (tokens.listZebra and not IsVertical() and dataIndex % 2 == 0) and Theme.rowAlt or { 0, 0, 0, 0 }
  row.bg:SetColorTexture(unpack(row.baseRowColor))
  row:SetAlpha(datum.excluded and 0.42 or 1)
  V.PaintFreshness(row, datum)

  GG.RosterThemes.PaintSurface(row, row.themeGeom, {
    T = V.Theme(),
    vertical = IsVertical(),
    classColor = classColor and { classColor.r, classColor.g, classColor.b } or nil,
    isCurrent = datum.isCurrent == true,
    alphaMul = (GGDB.options and GGDB.options.windowOpacity) or 1,
    index = dataIndex,
    heat = tokens.heat and V.HeatOf(datum, state.ilvlRange) or nil,
  })
end

function V.HeatOf(datum, range)
  range = range or {}
  local heat = { raid = {} }
  if datum.ilvl and datum.ilvl > 0 then
    local lo, hi = range.min or datum.ilvl, range.max or datum.ilvl
    heat.ilvl = { color = { 0.64, 0.21, 0.93 }, t = hi > lo and math.max(0, math.min(1, (datum.ilvl - lo) / (hi - lo))) or 1 }
  end
  if datum.rating and datum.rating > 0 then
    heat.rating = { color = datum.rating >= 2000 and Theme.gold or Theme.textMuted, t = datum.rating / 3000 }
  end
  local progress = datum.raidProgress
  local total = progress and progress.totalSegments or 0
  if total > 0 and progress.byDifficulty then
    for difficultyID, p in pairs(progress.byDifficulty) do
      local killed = 0
      for i = 1, total do
        if p.slots and p.slots[i] == true then killed = killed + 1 end
      end
      local def = CONST.RAID_DIFFICULTY_DEFS[difficultyID]
      if killed >= total and def then heat.raid[difficultyID] = def.color end
    end
  end
  return heat
end

local function PositionRowHorizontal(row)
  row:SetHeight(CONST.ROW_HEIGHT)
  local tokens = V.Theme().tokens

  row.groupLines = row.groupLines or {}
  local starts = (tokens.listLines and state.groupStarts) or {}
  local startBlocks = state.groupStartBlocks or {}
  local lineInset = tokens.listLines == "inset" and (tokens.listRuleInset or 0) or 0
  for i, x in ipairs(starts) do
    local line = row.groupLines[i]
    if not line then
      line = row:CreateTexture(nil, "BORDER")
      line:SetWidth(1)
      row.groupLines[i] = line
    end
    local lineColor, alpha = tokens.rule or Theme.border, 1
    if tokens.listLines == "block" then
      lineColor = (tokens.blocks and tokens.blocks[startBlocks[i]]) or Theme.border
      alpha = tokens.listLineAlpha or 0.3
    end
    line:SetColorTexture(lineColor[1], lineColor[2], lineColor[3], (lineColor[4] or 1) * alpha)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", row, "TOPLEFT", x, -lineInset)
    line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, lineInset)
    line:Show()
  end
  for i = #starts + 1, #row.groupLines do row.groupLines[i]:Hide() end
  if row.sepLine then row.sepLine:Hide() end
  row.compactIdentity = false

  if row.vDecor then HideVerticalDecor(row.vDecor) end
  if row.vColSeparator then row.vColSeparator:Hide() end

  row.nameText:SetFont(Theme.font, HFONT.name, "")
  row.accountText:SetFont(Theme.font, HFONT.account, "")
  local bump = tokens.numBump or 0
  row.ilvlText:SetFont(Theme.font, HFONT.ilvl + bump, "")
  row.ratingText:SetFont(Theme.font, HFONT.rating + bump, "")
  row.keyLevelText:SetFont(Theme.font, HFONT.keyLevel, "")
  row.keyDungeonText:SetFont(Theme.font, HFONT.keyDungeon, "")
  row.noKeyText:SetFont(Theme.font, HFONT.noKey, "")
  row.keyBadge:SetHeight(HFONT.keyBadgeHeight)

  row.vaultCell:SetSize(CONST.VAULT_DOT_GAP + CONST.VAULT_SLOT_WIDTH * 3, CONST.VAULT_ROW_HEIGHT * #CONST.VAULT_TIER_TYPES)
  for tierIndex = 1, #CONST.VAULT_TIER_TYPES do
    local dot = row.vaultDots[tierIndex]
    dot:Show()
    dot:ClearAllPoints()
    dot:SetPoint("LEFT", row.vaultCell, "TOPLEFT", 0,
      -(tierIndex - 1) * CONST.VAULT_ROW_HEIGHT - CONST.VAULT_ROW_HEIGHT / 2)
    for slotIndex = 1, 3 do
      local cell = row.vaultGrid[tierIndex][slotIndex]
      cell:SetFont(Theme.font, CONST.VAULT_SLOT_FONT_SIZE, "")
      cell:SetWidth(CONST.VAULT_SLOT_WIDTH)
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", row.vaultCell, "TOPLEFT",
        CONST.VAULT_DOT_GAP + (slotIndex - 1) * CONST.VAULT_SLOT_WIDTH,
        -(tierIndex - 1) * CONST.VAULT_ROW_HEIGHT)
    end
  end

  local avatarShown = IsSectionVisible("avatar")
  local textAnchor, textPoint, textX
  if avatarShown then
    textAnchor, textPoint, textX = row.avatar, "RIGHT", CONST.AVATAR_GAP
  else
    textAnchor, textPoint, textX = row, "LEFT", columnLayout.character.x + CONST.CELL_PADDING
  end

  row.nameText:ClearAllPoints()
  row.nameText:SetPoint("BOTTOMLEFT", textAnchor, textPoint, textX, 2)
  row.nameText:SetJustifyH("LEFT")
  row.realmText:ClearAllPoints()
  row.realmText:SetPoint("TOPLEFT", textAnchor, textPoint, textX, -2)
  row.realmText:SetJustifyH("LEFT")
  row.guildText:ClearAllPoints()
  row.guildText:SetPoint("TOPLEFT", row.realmText, "BOTTOMLEFT", 0, -2)
  row.guildText:SetJustifyH("LEFT")
  row.levelText:SetJustifyH("LEFT")
  row.identityAnchor = { frame = textAnchor, point = textPoint, x = textX }

  local accountLayout = columnLayout.account
  local nameLayout = columnLayout.character
  local ilvlLayout = columnLayout.ilvl
  local ratingLayout = columnLayout.rating
  local keyLayout = columnLayout.keystone
  local vaultLayout = columnLayout.vault
  local raidLayout = columnLayout.raid
  local currLayout = columnLayout.currencies

  row.accountCellBg:ClearAllPoints()
  local accountInner = accountLayout.width - CONST.LIST_ACCOUNT_INSET
  row.accountCellBg:SetPoint("CENTER", row, "TOPLEFT", accountLayout.x + CONST.LIST_ACCOUNT_INSET + accountInner / 2, -CONST.ROW_HEIGHT / 2)
  row.accountCellBg:SetSize(accountInner - 10, 20)
  row.accountText:ClearAllPoints()
  row.accountText:SetPoint("CENTER", row.accountCellBg, "CENTER", 0, 0)

  local bodyWidth = state.listBodyWidth or (scrollClip and scrollClip:GetWidth()) or 0
  local cols = {}
  for _, col in ipairs(CONST.COLUMNS) do
    local layout = columnLayout[col.key]
    if layout and layout.visible and (layout.width or 0) > 0 then
      cols[#cols + 1] = { key = col.key, x = layout.x, w = layout.width }
    end
  end
  row.themeGeom = {
    x = CONST.LIST_CARD_LEFT, y = 0, h = CONST.ROW_HEIGHT, right = CONST.LIST_CARD_RIGHT,
    span = math.max(200, bodyWidth - CONST.LIST_CARD_LEFT - CONST.LIST_CARD_RIGHT),
    charX = nameLayout.x, charW = nameLayout.width,
    avatar = row.avatarRing, avatarSize = CONST.AVATAR_SIZE,
    cols = cols,
    spans = GG.RosterThemes.ListSpans(state.groupSpanStarts, bodyWidth - CONST.LIST_CARD_RIGHT),
    rowGap = CONST.ROW_GAP,
  }

  row.mainRing:ClearAllPoints()
  row.mainRing:SetPoint("LEFT", row, "LEFT", nameLayout.x + CONST.CELL_PADDING - 2, 0)
  row.avatarRing:ClearAllPoints()
  row.avatarRing:SetPoint("LEFT", row, "LEFT", nameLayout.x + CONST.CELL_PADDING, 0)

  local textStart = CONST.CELL_PADDING + (avatarShown and (CONST.AVATAR_SIZE + CONST.AVATAR_GAP) or 0)
  local textAvail = math.max(20, nameLayout.width - textStart - CONST.CELL_PADDING)
  row.identityAvail = textAvail
  row.nameText:SetWidth(textAvail)
  row.realmText:SetWidth(textAvail)
  row.guildText:SetWidth(textAvail)
  row.levelText:SetWidth(textAvail)

  row.equipmentHitbox:ClearAllPoints()
  row.equipmentHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", nameLayout.x, 0)
  row.equipmentHitbox:SetSize(nameLayout.width + ilvlLayout.width, CONST.ROW_HEIGHT)
  row.ilvlHitbox:Hide()

  local gauge = V.Theme().parts.nums == "gauge"
  local numberLift = gauge and 4 or 0
  row.gaugeGeom = gauge and {
    ilvl = ilvlLayout.visible and { x = ilvlLayout.x + CONST.CELL_PADDING, y = CONST.ROW_HEIGHT / 2 + 8,
      w = ilvlLayout.width - CONST.CELL_PADDING * 2 } or nil,
    rating = ratingLayout.visible and { x = ratingLayout.x + CONST.CELL_PADDING, y = CONST.ROW_HEIGHT / 2 + 8,
      w = ratingLayout.width - CONST.CELL_PADDING * 2 } or nil,
  } or nil

  row.ilvlText:SetShown(ilvlLayout.visible)
  row.ilvlText:ClearAllPoints()
  row.ilvlText:SetPoint("LEFT", row, "LEFT", ilvlLayout.x + CONST.CELL_PADDING, numberLift)

  row.ratingText:SetShown(ratingLayout.visible)
  row.ratingText:ClearAllPoints()
  row.ratingText:SetPoint("LEFT", row, "LEFT", ratingLayout.x + CONST.CELL_PADDING, numberLift)
  row.ratingHitbox:SetShown(ratingLayout.visible)
  row.ratingHitbox:ClearAllPoints()
  row.ratingHitbox:SetPoint("LEFT", row, "LEFT", ratingLayout.x + CONST.CELL_PADDING, 0)
  row.ratingHitbox:SetSize(math.max(0, ratingLayout.width - CONST.CELL_PADDING * 2), CONST.ROW_HEIGHT)

  row.keyBadge:ClearAllPoints()
  row.keyBadge:SetPoint("LEFT", row, "LEFT", keyLayout.x + CONST.CELL_PADDING, 0)
  row.noKeyText:ClearAllPoints()
  row.noKeyText:SetPoint("LEFT", row, "LEFT", keyLayout.x + CONST.CELL_PADDING, 0)
  row.keyHitbox:SetShown(keyLayout.visible)
  row.keyHitbox:ClearAllPoints()
  row.keyHitbox:SetPoint("LEFT", row, "LEFT", keyLayout.x + CONST.CELL_PADDING, 0)
  row.keyHitbox:SetSize(math.max(0, keyLayout.width - CONST.CELL_PADDING * 2), CONST.ROW_HEIGHT)

  row.vaultCell:SetShown(vaultLayout.visible)
  row.vaultCell:ClearAllPoints()
  row.vaultCell:SetPoint("LEFT", row, "LEFT", vaultLayout.x + CONST.CELL_PADDING, 0)
  row.vaultAlert:ClearAllPoints()
  row.vaultAlert:SetPoint("TOP", row.vaultCell, "BOTTOMLEFT", CONST.VAULT_DOT_GAP + CONST.VAULT_SLOT_WIDTH * 1.5, -3)

  row.raidCell:SetShown(raidLayout.visible)
  row.raidCell:ClearAllPoints()
  row.raidCell:SetPoint("LEFT", row, "LEFT", raidLayout.x + CONST.CELL_PADDING, 0)
  row.raidCell:SetSize(raidLayout.width - CONST.CELL_PADDING * 2, CONST.RAID_BAR_ROW_HEIGHT * #CONST.RAID_BAR_ORDER)

  row.questAnchor:ClearAllPoints()
  row.questAnchor:SetPoint("LEFT", row, "LEFT", currLayout.x + CONST.CELL_PADDING, 0)

  row.currencyCell:SetShown(currLayout.visible)
  row.currencyCell:ClearAllPoints()
  row.currencyCell:SetPoint("LEFT", row, "LEFT", currLayout.x + CONST.CELL_PADDING + CurrencyGrid.DelvesLead(), 0)
  CurrencyGrid.PositionSideBySide(row)
end

local function PositionRowVertical(row)
  local tokens = V.Theme().tokens
  for _, line in ipairs(row.groupLines or {}) do line:Hide() end
  if row.sepLine then row.sepLine:Hide() end

  if not verticalMap["character"] then
    verticalMap = RebuildVerticalSections()
  end

  row:SetHeight(verticalTotalHeight)

  row.vDecor = row.vDecor or {}
  PaintVerticalDecor(row, row.vDecor)

  if row.vColSeparator then row.vColSeparator:Hide() end

  local function MidY(section)
    return -((section.y or 0) + section.height / 2)
  end

  local charSection = verticalMap["character"]
  local rosterSection = verticalMap["roster"]
  row.rosterTagTop = (rosterSection and rosterSection.visible) and -(rosterSection.y + 3) or nil
  local charY = charSection.y

  local rosterShown = rosterSection and rosterSection.visible
  row.themeGeom = {
    x = 0, y = V.TOP_PADDING, w = V.COL_WIDTH,
    h = math.max(1, verticalTotalHeight - V.TOP_PADDING - V.BOTTOM_PADDING),
    headSplit = rosterShown and (rosterSection.y + rosterSection.height) or nil,
    headBottom = charY + charSection.height,
    avatar = row.avatarRing, avatarSize = CONST.AVATAR_SIZE,
    layout = verticalDecor.layout,
  }

  local compact = tokens.compactHeader == true
  row.compactIdentity = compact
  local avatarOn = IsSectionVisible("avatar")
  row.avatarRing:ClearAllPoints()
  if compact then
    row.avatarRing:SetPoint("LEFT", row, "TOPLEFT", tokens.headerPad or 14, -(charY + charSection.height / 2))
  else
    row.avatarRing:SetPoint("TOP", row, "TOP", 0, -(charY + 5))
  end
  row.mainRing:ClearAllPoints()
  row.mainRing:SetPoint("CENTER", row.avatarRing, "CENTER", 0, 0)

  local textWidth = V.COL_CONTENT
  row.nameText:SetFont(Theme.font, tokens.nameSize or VFONT.name, "")
  if compact then
    local pad = tokens.headerPad or 14
    local textX = avatarOn and (tokens.headerGap or 9) or 0
    local ringW = avatarOn and row.avatarRing:GetWidth() or 0
    if not ringW or ringW <= 0 then ringW = CONST.AVATAR_SIZE + 3 end
    textWidth = math.max(20, V.COL_WIDTH - pad - ringW - textX - 6)
    if avatarOn then
      row.identityAnchor = { frame = row.avatarRing, point = "RIGHT", x = textX }
    else
      row.identityAnchor = { frame = row, point = "TOPLEFT", x = pad, y = -(charY + charSection.height / 2) }
    end
    row.identityAvail = textWidth
    for _, fs in ipairs({ row.nameText, row.realmText, row.guildText, row.levelText }) do
      fs:SetWidth(textWidth)
      fs:SetJustifyH("LEFT")
    end
  else
    row.identityAnchor = nil
    row.nameText:ClearAllPoints()
    if avatarOn then
      row.nameText:SetPoint("TOP", row.avatarRing, "BOTTOM", 0, -5)
    else
      row.nameText:SetPoint("TOP", row, "TOP", 0, -(charY + 5))
    end
    row.nameText:SetWidth(textWidth)
    row.nameText:SetJustifyH("CENTER")

    row.realmText:ClearAllPoints()
    row.realmText:SetPoint("TOP", row.nameText, "BOTTOM", 0, -1)
    row.realmText:SetWidth(textWidth)
    row.realmText:SetJustifyH("CENTER")

    row.guildText:ClearAllPoints()
    row.guildText:SetPoint("TOP", row.realmText, "BOTTOM", 0, -1)
    row.guildText:SetWidth(textWidth)
    row.guildText:SetJustifyH("CENTER")

    row.levelText:ClearAllPoints()
    row.levelText:SetPoint("TOP", row.guildText, "BOTTOM", 0, -1)
    row.levelText:SetWidth(textWidth)
    row.levelText:SetJustifyH("CENTER")
  end

  row.equipmentHitbox:ClearAllPoints()
  row.equipmentHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -charY)
  row.equipmentHitbox:SetSize(V.COL_WIDTH, charSection.height)

  local accountSection = verticalMap["account"]
  row.accountCellBg:ClearAllPoints()
  row.accountCellBg:SetPoint("CENTER", row, "TOPLEFT", V.COL_WIDTH / 2, -((accountSection.y or 0) + accountSection.height / 2))
  row.accountCellBg:SetSize(64, accountSection.height - 8)
  row.accountText:ClearAllPoints()
  row.accountText:SetPoint("CENTER", row.accountCellBg, "CENTER", 0, 0)
  row.accountText:SetFont(Theme.font, VFONT.account, "")

  local gauge = V.Theme().parts.nums == "gauge"
  local numberLift = gauge and 4 or 0
  local gaugeW = V.COL_WIDTH - 36

  local ilvlSection = verticalMap["ilvl"]
  local ratingSection = verticalMap["rating"]
  row.gaugeGeom = gauge and {
    ilvl = ilvlSection.visible and { x = 18, y = (ilvlSection.y or 0) + ilvlSection.height / 2 + 8, w = gaugeW } or nil,
    rating = ratingSection.visible and { x = 18, y = (ratingSection.y or 0) + ratingSection.height / 2 + 8, w = gaugeW } or nil,
  } or nil

  row.ilvlText:SetShown(ilvlSection.visible)
  row.ilvlText:ClearAllPoints()
  row.ilvlText:SetPoint("CENTER", row, "TOP", 0, MidY(ilvlSection) + numberLift)
  row.ilvlText:SetFont(Theme.font, VFONT.ilvl + (tokens.numBump or 0), "")
  row.ilvlHitbox:SetShown(ilvlSection.visible)
  row.ilvlHitbox:ClearAllPoints()
  row.ilvlHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", V.COL_PADDING, -(ilvlSection.y or 0))
  row.ilvlHitbox:SetSize(V.COL_CONTENT, ilvlSection.height)

  row.ratingText:SetShown(ratingSection.visible)
  row.ratingText:ClearAllPoints()
  row.ratingText:SetPoint("CENTER", row, "TOP", 0, MidY(ratingSection) + numberLift)
  row.ratingText:SetFont(Theme.font, VFONT.rating + (tokens.numBump or 0), "")
  row.ratingHitbox:SetShown(ratingSection.visible)
  row.ratingHitbox:ClearAllPoints()
  row.ratingHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", V.COL_PADDING, -(ratingSection.y or 0))
  row.ratingHitbox:SetSize(V.COL_CONTENT, ratingSection.height)

  local keySection = verticalMap["keystone"]
  row.keyBadge:ClearAllPoints()
  row.keyBadge:SetPoint("CENTER", row, "TOP", 0, MidY(keySection))
  row.keyBadge:SetHeight(V.KEY_BADGE_HEIGHT)
  row.keyLevelText:SetFont(Theme.font, VFONT.keyLevel, "")
  row.keyDungeonText:SetFont(Theme.font, VFONT.keyDungeon, "")
  row.noKeyText:ClearAllPoints()
  row.noKeyText:SetPoint("CENTER", row, "TOP", 0, MidY(keySection))
  row.noKeyText:SetFont(Theme.font, VFONT.noKey, "")
  row.keyHitbox:SetShown(keySection.visible)
  row.keyHitbox:ClearAllPoints()
  row.keyHitbox:SetPoint("TOPLEFT", row, "TOPLEFT", V.COL_PADDING, -(keySection.y or 0))
  row.keyHitbox:SetSize(V.COL_CONTENT, keySection.height)

  local vaultSection = verticalMap["vault"]
  row.vaultCell:SetShown(vaultSection.visible)
  row.vaultCell:SetSize(V.VAULT_SLOT_WIDTH * 3, V.VAULT_ROW_HEIGHT * #CONST.VAULT_TIER_TYPES)
  row.vaultCell:ClearAllPoints()
  row.vaultCell:SetPoint("TOP", row, "TOP", 0, -((vaultSection.y or 0) + V.VAULT_TOP_PAD))

  for tierIndex = 1, #CONST.VAULT_TIER_TYPES do
    row.vaultDots[tierIndex]:Hide()
    for slotIndex = 1, 3 do
      local cell = row.vaultGrid[tierIndex][slotIndex]
      cell:SetFont(Theme.font, V.VAULT_FONT_SIZE, "")
      cell:SetWidth(V.VAULT_SLOT_WIDTH)
      cell:ClearAllPoints()
      cell:SetPoint("TOPLEFT", row.vaultCell, "TOPLEFT",
        (slotIndex - 1) * V.VAULT_SLOT_WIDTH,
        -(tierIndex - 1) * V.VAULT_ROW_HEIGHT)
    end
  end
  row.vaultAlert:ClearAllPoints()
  row.vaultAlert:SetPoint("TOP", row.vaultCell, "BOTTOM", 0, -3)

  local raidSection = verticalMap["raid"]
  row.raidCell:SetShown(raidSection.visible)
  row.raidCell:ClearAllPoints()
  row.raidCell:SetPoint("TOP", row, "TOP", 0, -(raidSection.y or 0))
  row.raidCell:SetSize(V.COL_CONTENT,
    math.max(#(raidSection.difficulties or {}), 1) * (raidSection.bandHeight or V.RaidBandHeight()))

  local bountySection = verticalMap["bounty"]
  local questSlot = V.Theme().parts.quests == "checks" and GG.RosterThemes.CHECK_SIZE
    or (CONST.BOUNTY_ICON_SIZE + 4)
  row.questsVerticalY = (bountySection.y or 0) + math.floor((bountySection.height - questSlot) / 2)
  ApplyDelvesAlignment(row)

  local currSection = verticalMap["currencies"]
  row.currencyCell:SetShown(currSection.visible)
  row.currencyCell:ClearAllPoints()
  row.currencyCell:SetPoint("TOP", row, "TOP", 0, -(currSection.y or 0))
  CurrencyGrid.PositionStacked(row)
end

local function PositionRowColumns(row)
  if IsVertical() then
    PositionRowVertical(row)
  else
    PositionRowHorizontal(row)
  end
  if row.datum then LayoutIdentity(row) end
end

local function PreviewPickDatum()
  local rows = GG.Roster:BuildRows()
  if #rows == 0 then return nil end
  local current, main
  for _, row in ipairs(rows) do
    if row.isCurrent and not current then current = row end
    if row.isMain and not main then main = row end
  end
  return current or main or rows[1]
end

CONST.PREVIEW_AVATAR_SIZE = 28
CONST.PREVIEW_GAP = 16
CONST.PREVIEW_CAPTION_HEIGHT = 14
CONST.PREVIEW_CAPTION_GAP = 4

local function PreviewWrapCell(container, captionText, width)
  local cell = CreateFrame("Frame", nil, container)
  cell:SetSize(width, CONST.PREVIEW_CAPTION_HEIGHT + CONST.PREVIEW_CAPTION_GAP + CONST.ROW_HEIGHT)

  local caption = CreateLabel(cell, 10, Theme.textMuted, true)
  caption:SetPoint("TOPLEFT", 0, 0)
  caption:SetText(captionText)

  local content = CreateFrame("Frame", nil, cell)
  content:SetSize(width, CONST.ROW_HEIGHT)
  content:SetPoint("TOPLEFT", 0, -(CONST.PREVIEW_CAPTION_HEIGHT + CONST.PREVIEW_CAPTION_GAP))

  local divider = cell:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOP", cell, "TOPRIGHT", CONST.PREVIEW_GAP / 2, 0)
  divider:SetPoint("BOTTOM", cell, "BOTTOMRIGHT", CONST.PREVIEW_GAP / 2, 0)
  divider:SetWidth(1)
  divider:SetColorTexture(unpack(Theme.borderSoft))

  return cell, content
end

local function PreviewBuildRaidCell(container, width, datum, barHeight)
  barHeight = barHeight or CONST.RAID_BAR_ROW_HEIGHT
  local raidRow = { raidCell = CreateFrame("Frame", nil, container), raidBars = {}, datum = datum, barHeight = barHeight }
  raidRow.raidCell:SetSize(width, barHeight * #CONST.RAID_BAR_ORDER)
  for _, difficultyID in ipairs(CONST.RAID_BAR_ORDER) do
    local bar = CreateRaidBar(raidRow, difficultyID)
    if barHeight > CONST.RAID_BAR_ROW_HEIGHT then
      bar.label:SetFont(Theme.font, math.floor(barHeight * 0.6), "")
    end
    raidRow.raidBars[difficultyID] = bar
  end
  return raidRow
end

local function PreviewRefreshRaidCell(raidRow, datum, style)
  local barHeight = raidRow.barHeight or CONST.RAID_BAR_ROW_HEIGHT
  local visibleDifficulties = {}
  for _, difficultyID in ipairs(CONST.RAID_BAR_ORDER) do
    if IsRaidDifficultyVisible(difficultyID) then
      table.insert(visibleDifficulties, difficultyID)
    else
      HideRaidBar(raidRow.raidBars[difficultyID])
    end
  end

  local cellHeight = barHeight * #CONST.RAID_BAR_ORDER
  local usedHeight = barHeight * #visibleDifficulties
  local startY = -(cellHeight - usedHeight) / 2

  for i, difficultyID in ipairs(visibleDifficulties) do
    local progress = datum.raidProgress.byDifficulty[difficultyID]
    PaintRaidBar(
      raidRow.raidCell, raidRow.raidBars[difficultyID],
      progress.slots, datum.raidProgress.totalSegments, raidRow.raidCell:GetWidth(),
      CONST.RAID_DIFFICULTY_DEFS[difficultyID].color,
      startY - (i - 1) * barHeight, barHeight,
      style and { style = style } or nil
    )
  end
end

local function BuildSettingsColumnsPreview(container)
  local datum = PreviewPickDatum()
  if not datum then
    local empty = CreateLabel(container, 11, Theme.textFaint)
    empty:SetPoint("LEFT", 0, 0)
    empty:SetText(L["OPTIONS_PREVIEW_NO_CHARACTER"])
    return function() end
  end

  local accountCell, accountContent = PreviewWrapCell(container, L["SECTION_ACCOUNT"], 74)
  local accountText = CreateLabel(accountContent, 11, Theme.textPrimary)
  accountText:SetPoint("LEFT", accountContent, "LEFT", 0, 0)
  accountText:SetText(datum.accountLabel or "")

  local characterCell, characterContent = PreviewWrapCell(container, L["ROSTER_COL_CHARACTER"], 132)

  local avatarRing = characterContent:CreateTexture(nil, "BORDER")
  avatarRing:SetSize(CONST.PREVIEW_AVATAR_SIZE + 3, CONST.PREVIEW_AVATAR_SIZE + 3)
  avatarRing:SetPoint("LEFT", characterContent, "LEFT", 0, 0)

  local avatar = characterContent:CreateTexture(nil, "ARTWORK")
  avatar:SetSize(CONST.PREVIEW_AVATAR_SIZE, CONST.PREVIEW_AVATAR_SIZE)
  avatar:SetPoint("CENTER", avatarRing, "CENTER", 0, 0)
  GG.Widgets.SetClassIcon(avatar, CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[datum.class])

  local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[datum.class]
  if classColor then
    avatarRing:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.6)
  else
    avatarRing:SetColorTexture(unpack(Theme.borderSoft))
  end

  local name = CreateLabel(characterContent, 13, Theme.textPrimary)
  name:SetPoint("BOTTOMLEFT", avatar, "RIGHT", CONST.AVATAR_GAP, 2)
  name:SetText(datum.name)
  if classColor then name:SetTextColor(classColor.r, classColor.g, classColor.b) end

  local realm = CreateLabel(characterContent, 10, Theme.textFaint)
  realm:SetPoint("TOPLEFT", avatar, "RIGHT", CONST.AVATAR_GAP, -2)
  realm:SetText(datum.realm)

  local guild = CreateLabel(characterContent, 9, Theme.success)
  guild:SetPoint("TOPLEFT", realm, "BOTTOMLEFT", 0, -1)
  guild:SetText(datum.guild or "")

  local ilvlCell, ilvlContent = PreviewWrapCell(container, L["SECTION_ILVL"], 52)
  local ilvl = CreateMonoLabel(ilvlContent, HFONT.ilvl, { 0.64, 0.21, 0.93, 1 })
  ilvl:SetPoint("LEFT", ilvlContent, "LEFT", 0, 0)
  ilvl:SetText(FormatIlvl(datum.ilvl))

  local ratingCell, ratingContent = PreviewWrapCell(container, L["SECTION_RATING"], 46)
  local rating = CreateMonoLabel(ratingContent, HFONT.rating, datum.rating >= 2000 and Theme.gold or Theme.textMuted)
  rating:SetPoint("LEFT", ratingContent, "LEFT", 0, 0)
  rating:SetText(datum.rating > 0 and tostring(datum.rating) or "—")
  local gaugeStore = {}

  local keystoneCell, keystoneContent = PreviewWrapCell(container, L["SECTION_KEYSTONE"], 86)
  local keyFrame = CreateFrame("Frame", nil, keystoneContent)
  keyFrame:SetSize(86, 18)
  keyFrame:SetPoint("LEFT", keystoneContent, "LEFT", 0, 0)
  local keyBg = keyFrame:CreateTexture(nil, "BACKGROUND")
  keyBg:SetAllPoints()
  local keyText = CreateLabel(keyFrame, 11, Theme.textPrimary, true)
  keyText:SetPoint("CENTER")
  if datum.keystone then
    local level = datum.keystone.level or 0
    local tierColor = level >= 10 and Theme.gold or (level >= 9 and Theme.teal or Theme.accentStrong)
    keyBg:SetColorTexture(tierColor[1], tierColor[2], tierColor[3], 0.18)
    keyText:SetText(("+%d %s"):format(level, AbbreviateDungeonName(datum.keystone.challengeModeID, datum.keystone.dungeon)))
    keyText:SetTextColor(unpack(tierColor))
  else
    keyBg:SetColorTexture(0, 0, 0, 0)
    keyText:SetText(L["ROSTER_NO_KEYSTONE"])
    keyText:SetTextColor(unpack(Theme.textFaint))
  end

  local vaultCellWrap, vaultContent = PreviewWrapCell(container, L["SECTION_VAULT"],
    CONST.VAULT_DOT_GAP + CONST.VAULT_SLOT_WIDTH * 3 + 4)
  local vaultRow = { vaultCell = CreateFrame("Frame", nil, vaultContent) }
  vaultRow.vaultCell:SetSize(CONST.VAULT_DOT_GAP + CONST.VAULT_SLOT_WIDTH * 3, CONST.VAULT_ROW_HEIGHT * #CONST.VAULT_TIER_TYPES)
  vaultRow.vaultCell:SetPoint("LEFT", vaultContent, "LEFT", 0, 0)
  vaultRow.vaultGrid = CreateVaultGrid(vaultRow)
  PaintVaultGrid(vaultRow, datum.rawRecord)

  local raidCellWrap, raidContent = PreviewWrapCell(container, L["SECTION_RAIDS"], 132)
  local raidRow = PreviewBuildRaidCell(raidContent, 132, datum)
  raidRow.raidCell:SetPoint("LEFT", raidContent, "LEFT", 0, 0)

  local CURRENCY_PREVIEW_COUNT = 4
  local currenciesCell, currenciesContent = PreviewWrapCell(container, L["SECTION_CURRENCIES"], CONST.CURRENCY_SLOT_WIDTH * CURRENCY_PREVIEW_COUNT)
  local currencyFrame = CreateFrame("Frame", nil, currenciesContent)
  currencyFrame:SetSize(CONST.CURRENCY_SLOT_WIDTH * CURRENCY_PREVIEW_COUNT, CONST.CURRENCY_SLOT_HEIGHT)
  currencyFrame:SetPoint("LEFT", currenciesContent, "LEFT", 0, 0)
  local currencySlots = {}
  for i = 1, CURRENCY_PREVIEW_COUNT do
    local slot = CreateFrame("Frame", nil, currencyFrame)
    slot:SetSize(CONST.CURRENCY_SLOT_WIDTH, CONST.CURRENCY_SLOT_HEIGHT)
    slot:SetPoint("LEFT", currencyFrame, "LEFT", (i - 1) * CONST.CURRENCY_SLOT_WIDTH, 0)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetSize(14, 14)
    slot.icon:SetPoint("LEFT", slot, "LEFT", 0, 0)
    slot.text = CreateMonoLabel(slot, 10, Theme.textFaint)
    slot.text:SetPoint("LEFT", slot.icon, "RIGHT", 4, 0)
    currencySlots[i] = slot
  end
  local function PaintPreviewCurrencies()
    local fresh = PreviewPickDatum() or datum
    for i, slot in ipairs(currencySlots) do
      local entry = fresh.currencies and fresh.currencies[i]
      if entry and entry.kind ~= "bounty" and entry.data.iconFileID and entry.data.iconFileID ~= 0 then
        GG.Widgets.SetItemIcon(slot.icon, entry.data.iconFileID)
        slot.text:SetText(GG.Currencies:FormatAmount(entry.data.quantity, L["NUMBER_DECIMAL_SEPARATOR"]))
        slot:Show()
      else
        slot:Hide()
      end
    end
  end
  PaintPreviewCurrencies()

  local pieces = {
    { key = "account", frame = accountCell, width = 74 },
    { key = nil, frame = characterCell, width = 132, character = true },
    { key = "ilvl", frame = ilvlCell, width = 52 },
    { key = "rating", frame = ratingCell, width = 46 },
    { key = "keystone", frame = keystoneCell, width = 86 },
    { key = "vault", frame = vaultCellWrap, width = CONST.VAULT_DOT_GAP + CONST.VAULT_SLOT_WIDTH * 3 + 4 },
    { key = "raids", frame = raidCellWrap, width = 132 },
    { key = "currencies", frame = currenciesCell, width = CONST.CURRENCY_SLOT_WIDTH * CURRENCY_PREVIEW_COUNT },
  }

  local surface = CreateFrame("Frame", nil, container)
  surface:SetFrameLevel(container:GetFrameLevel())

  return function()
    V.ApplyTheme()
    PaintPreviewCurrencies()

    local gauge = V.Theme().parts.nums == "gauge"
    local lift = gauge and 4 or 0
    local bump = V.Theme().tokens.numBump or 0
    ilvl:SetFont(Theme.font, HFONT.ilvl + bump, "")
    rating:SetFont(Theme.font, HFONT.rating + bump, "")
    ilvl:ClearAllPoints()
    ilvl:SetPoint("LEFT", ilvlContent, "LEFT", 0, lift)
    rating:ClearAllPoints()
    rating:SetPoint("LEFT", ratingContent, "LEFT", 0, lift)
    if gauge then
      local lo, hi
      for _, r in ipairs(GG.Roster:BuildRows()) do
        if r.ilvl and r.ilvl > 0 then
          lo = math.min(lo or r.ilvl, r.ilvl)
          hi = math.max(hi or r.ilvl, r.ilvl)
        end
      end
      local RT = GG.RosterThemes
      RT.PaintGauge(ilvlContent, gaugeStore, "ilvl", 0, CONST.ROW_HEIGHT / 2 + 8, 46,
        RT.GaugePct(datum.ilvl, (lo or 0) - 2, hi), { 0.64, 0.21, 0.93, 1 })
      RT.PaintGauge(ratingContent, gaugeStore, "rating", 0, CONST.ROW_HEIGHT / 2 + 8, 40,
        RT.GaugePct(datum.rating, 800, 3000), datum.rating >= 2000 and Theme.gold or Theme.textMuted)
    else
      GG.RosterThemes.HideGauge(gaugeStore, "ilvl")
      GG.RosterThemes.HideGauge(gaugeStore, "rating")
    end
    guild:SetShown(datum.guild ~= nil and datum.guild ~= "" and IsSectionVisible("guild"))

    local showAvatar = IsSectionVisible("avatar")
    avatar:SetShown(showAvatar)
    avatarRing:SetShown(showAvatar)
    local textAnchor, textPoint, textX
    if showAvatar then
      textAnchor, textPoint, textX = avatar, "RIGHT", CONST.AVATAR_GAP
    else
      textAnchor, textPoint, textX = characterContent, "LEFT", 0
    end
    name:ClearAllPoints()
    name:SetPoint("BOTTOMLEFT", textAnchor, textPoint, textX, 2)
    realm:ClearAllPoints()
    realm:SetPoint("TOPLEFT", textAnchor, textPoint, textX, -2)

    if IsSectionVisible("raids") then
      PreviewRefreshRaidCell(raidRow, datum, V.Theme().parts.bosses == "bar" and "bar" or nil)
    else
      for _, difficultyID in ipairs(CONST.RAID_BAR_ORDER) do
        HideRaidBar(raidRow.raidBars[difficultyID])
      end
    end

    local tok = V.Theme().tokens
    local lead = math.max(0, (tok.listCardLeft or 8) - 8)
    local CARD_PAD = 8 + lead
    local previous, first, x, charX, charW
    local cols, spanStarts = {}, {}
    local PIECE_COLS = { raids = "raid" }
    local PIECE_BLOCKS = { vault = "weekly", currencies = "currencies" }
    for _, piece in ipairs(pieces) do
      local visible = (piece.key == nil) or IsSectionVisible(piece.key)
      piece.frame:SetShown(visible)
      if visible then
        piece.frame:ClearAllPoints()
        if previous then
          piece.frame:SetPoint("LEFT", previous, "RIGHT", CONST.PREVIEW_GAP, 0)
          x = x + CONST.PREVIEW_GAP
        else
          piece.frame:SetPoint("LEFT", container, "LEFT", CARD_PAD, 0)
          first, x = piece.frame, CARD_PAD
          spanStarts[1] = { x = lead, block = "overview" }
        end
        if piece.character then charX, charW = x, piece.width end
        local block = PIECE_BLOCKS[piece.key]
        if block and #spanStarts > 0 and spanStarts[#spanStarts].block ~= block then
          spanStarts[#spanStarts + 1] = { x = x - CONST.PREVIEW_GAP / 2, block = block }
        end
        cols[#cols + 1] = {
          key = piece.character and "character" or (PIECE_COLS[piece.key] or piece.key),
          x = x - CONST.PREVIEW_GAP / 2, w = piece.width + CONST.PREVIEW_GAP,
        }
        x = x + piece.width
        previous = piece.frame
      end
    end
    surface:ClearAllPoints()
    if first then
      surface:SetPoint("TOPLEFT", first, "TOPLEFT", -CARD_PAD, -(CONST.PREVIEW_CAPTION_HEIGHT + CONST.PREVIEW_CAPTION_GAP))
      surface:SetPoint("BOTTOMRIGHT", previous, "BOTTOMRIGHT", CARD_PAD, 0)
      local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[datum.class]
      local range = {}
      for _, r in ipairs(GG.Roster:BuildRows()) do
        if r.ilvl and r.ilvl > 0 then
          range.min = math.min(range.min or r.ilvl, r.ilvl)
          range.max = math.max(range.max or r.ilvl, r.ilvl)
        end
      end
      GG.RosterThemes.PaintSurface(surface, {
        x = lead, y = 0, h = CONST.ROW_HEIGHT, right = 0, span = x + CARD_PAD - lead,
        charX = charX, charW = charW,
        avatar = avatarRing, avatarSize = CONST.PREVIEW_AVATAR_SIZE,
        cols = cols, spans = GG.RosterThemes.ListSpans(spanStarts, x + CARD_PAD), rowGap = 0,
      }, {
        T = V.Theme(), vertical = false,
        classColor = classColor and { classColor.r, classColor.g, classColor.b } or nil,
        isCurrent = datum.isCurrent == true, alphaMul = 1, index = 1,
        heat = tok.heat and V.HeatOf(datum, range) or nil,
      })
    end
  end
end

CONST.BOSSES_PREVIEW_BAR_HEIGHT = 23
CONST.BOSSES_PREVIEW_WIDTH = 700

local function BuildSettingsBossesPreview(container)
  local datum = PreviewPickDatum()
  if not datum then
    local empty = CreateLabel(container, 11, Theme.textFaint)
    empty:SetPoint("LEFT", 0, 0)
    empty:SetText(L["OPTIONS_PREVIEW_NO_CHARACTER"])
    return function() end
  end

  local raidRow = PreviewBuildRaidCell(container, CONST.BOSSES_PREVIEW_WIDTH, datum, CONST.BOSSES_PREVIEW_BAR_HEIGHT)
  raidRow.raidCell:SetPoint("LEFT", container, "LEFT", 0, 0)

  return function()
    PreviewRefreshRaidCell(raidRow, datum)
  end
end

local PV = {}
PV.LABEL_W = 100
PV.COL_X = PV.LABEL_W + 10
PV.CURRENCY_ROWS = 2
PV.DIFFICULTY_LABEL_KEYS = { [17] = "DIFFICULTY_LFR", [14] = "DIFFICULTY_NORMAL", [15] = "DIFFICULTY_HEROIC", [16] = "DIFFICULTY_MYTHIC" }

function PV.Clear(canvas)
  for _, region in ipairs({ canvas:GetRegions() }) do region:Hide(); region:SetParent(nil) end
  for _, child in ipairs({ canvas:GetChildren() }) do child:Hide(); child:SetParent(nil) end
end

function PV.Label(canvas, text, top, height, color)
  local fs = CreateLabel(canvas, 10.5, color or Theme.textMuted, true)
  fs:SetJustifyH("RIGHT")
  fs:SetWidth(PV.LABEL_W - 6)
  fs:SetPoint("RIGHT", canvas, "TOPLEFT", PV.LABEL_W - 6, -(top + height / 2))
  fs:SetText(text)
  return fs
end

function PV.Title(canvas, text, top, height, block)
  local tok = V.Theme().tokens
  local fs = CreateLabel(canvas, V.LABEL_SIZE, Theme.accent, true)
  fs:SetWidth(PV.COL_X + 10)
  fs:SetPoint("LEFT", canvas, "TOPLEFT", tok.blocks and 8 or 0, -(top + height / 2))
  fs:SetText(text)
  local s = tok.separator
  if s == "glow" then
    GG.RosterThemes.PaintGlowSeparators(canvas, {}, PV.COL_X, V.COL_WIDTH, { math.floor(top + height / 2) }, tok)
  elseif s == "inset" or s == "full" or s == "block" or s == "gold" then
    local c = (tok.blocks and block and tok.blocks[block]) or tok.rule or Theme.border
    local inset = tok.ruleInset or 0
    local line = canvas:CreateTexture(nil, "BORDER")
    line:SetColorTexture(c[1], c[2], c[3], (c[4] or 1) * (tok.ruleAlpha or 1))
    line:SetHeight(1)
    local y = math.floor(top + height / 2)
    line:SetPoint("TOPLEFT", canvas, "TOPLEFT", PV.COL_X + inset, -y)
    line:SetPoint("TOPRIGHT", canvas, "TOPLEFT", PV.COL_X + V.COL_WIDTH - inset, -y)
  end
end

function PV.CenteredText(canvas, fs, top, height, lift)
  fs:SetPoint("CENTER", canvas, "TOPLEFT", PV.COL_X + V.COL_WIDTH / 2, -(top + height / 2) + (lift or 0))
end

function PV.DrawSection(canvas, section, top, datum)
  local cx = PV.COL_X + V.COL_WIDTH / 2
  local key = section.key

  if section.band then
    PV.Title(canvas, L[section.band], top, section.height, section.block)

  elseif key == "character" then
    PV.Label(canvas, section.label, top, section.height)
    local tok = V.Theme().tokens
    local compact = tok.compactHeader == true
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[datum.class]
    local textTop = top + 5
    local ring
    if IsSectionVisible("avatar") then
      ring = canvas:CreateTexture(nil, "BORDER")
      ring:SetSize(CONST.PREVIEW_AVATAR_SIZE + 3, CONST.PREVIEW_AVATAR_SIZE + 3)
      if compact then
        ring:SetPoint("LEFT", canvas, "TOPLEFT", PV.COL_X + (tok.headerPad or 14), -(top + section.height / 2))
      else
        ring:SetPoint("TOP", canvas, "TOPLEFT", cx, -(top + 5))
      end
      canvas.previewAvatar = ring
      if classColor then ring:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.6)
      else ring:SetColorTexture(unpack(Theme.borderSoft)) end
      local avatar = canvas:CreateTexture(nil, "ARTWORK")
      avatar:SetSize(CONST.PREVIEW_AVATAR_SIZE, CONST.PREVIEW_AVATAR_SIZE)
      avatar:SetPoint("CENTER", ring, "CENTER", 0, 0)
      GG.Widgets.SetClassIcon(avatar, CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[datum.class])
      textTop = top + 5 + CONST.PREVIEW_AVATAR_SIZE + 3 + 5
    end
    local lines = {}
    local name = CreateLabel(canvas, tok.nameSize or VFONT.name, Theme.textPrimary)
    name:SetText(datum.name)
    if classColor then name:SetTextColor(classColor.r, classColor.g, classColor.b) end
    lines[#lines + 1] = name
    local realm = CreateLabel(canvas, 10, Theme.textFaint)
    realm:SetText(datum.realm)
    lines[#lines + 1] = realm
    if datum.guild and datum.guild ~= "" and IsSectionVisible("guild") then
      local guild = CreateLabel(canvas, 10, Theme.success)
      guild:SetText(datum.guild)
      lines[#lines + 1] = guild
    end
    if compact then
      if datum.level and datum.level > 0 then
        local level = CreateLabel(canvas, 10, Theme.textFaint)
        level:SetText(L["ROSTER_LEVEL_FORMAT"]:format(datum.level))
        lines[#lines + 1] = level
      end
      local x = PV.COL_X + (tok.headerPad or 14) + (ring and (CONST.PREVIEW_AVATAR_SIZE + 3 + (tok.headerGap or 9)) or 0)
      local width = math.max(20, PV.COL_X + V.COL_WIDTH - x - 6)
      local total = 0
      for i, fs in ipairs(lines) do
        local _, size = fs:GetFont()
        total = total + (size or 12) + 1 + (i > 1 and 1 or 0)
      end
      local y = top + (section.height - total) / 2
      for _, fs in ipairs(lines) do
        local _, size = fs:GetFont()
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, -y)
        y = y + (size or 12) + 2
      end
    else
      for i, fs in ipairs(lines) do
        fs:SetWidth(V.COL_CONTENT)
        fs:SetJustifyH("CENTER")
        if i == 1 then
          fs:SetPoint("TOP", canvas, "TOPLEFT", cx, -textTop)
        else
          fs:SetPoint("TOP", lines[i - 1], "BOTTOM", 0, -1)
        end
      end
    end

  elseif key == "account" then
    PV.Label(canvas, section.label, top, section.height)
    local text = CreateLabel(canvas, VFONT.account, Theme.textPrimary)
    PV.CenteredText(canvas, text, top, section.height)
    text:SetText(datum.accountLabel or "")

  elseif key == "ilvl" or key == "rating" then
    PV.Label(canvas, section.label, top, section.height)
    local gauge = V.Theme().parts.nums == "gauge"
    local isIlvl = key == "ilvl"
    local color = isIlvl and { 0.64, 0.21, 0.93, 1 } or (datum.rating >= 2000 and Theme.gold or Theme.textMuted)
    local text = CreateMonoLabel(canvas, (isIlvl and VFONT.ilvl or VFONT.rating) + (V.Theme().tokens.numBump or 0), color)
    PV.CenteredText(canvas, text, top, section.height, gauge and 4 or 0)
    if isIlvl then
      text:SetText(FormatIlvl(datum.ilvl))
    else
      text:SetText(datum.rating > 0 and tostring(datum.rating) or "—")
    end
    if gauge then
      local RT = GG.RosterThemes
      local pct
      if isIlvl then
        local lo, hi
        for _, r in ipairs(GG.Roster:BuildRows()) do
          if r.ilvl and r.ilvl > 0 then
            lo = math.min(lo or r.ilvl, r.ilvl)
            hi = math.max(hi or r.ilvl, r.ilvl)
          end
        end
        pct = RT.GaugePct(datum.ilvl, (lo or 0) - 2, hi)
      else
        pct = RT.GaugePct(datum.rating, 800, 3000)
      end
      RT.PaintGauge(canvas, {}, key, PV.COL_X + 18, top + section.height / 2 + 8, V.COL_WIDTH - 36, pct, color)
    end

  elseif key == "keystone" then
    PV.Label(canvas, section.label, top, section.height)
    local text = CreateLabel(canvas, VFONT.keyLevel, Theme.textPrimary, true)
    PV.CenteredText(canvas, text, top, section.height)
    if datum.keystone then
      local level = datum.keystone.level or 0
      local tierColor = level >= 10 and Theme.gold or (level >= 9 and Theme.teal or Theme.accentStrong)
      text:SetText(("+%d %s"):format(level, AbbreviateDungeonName(datum.keystone.challengeModeID, datum.keystone.dungeon)))
      text:SetTextColor(unpack(tierColor))
      local badge = canvas:CreateTexture(nil, "BACKGROUND")
      badge:SetColorTexture(tierColor[1], tierColor[2], tierColor[3], 0.18)
      badge:SetSize(math.max(60, text:GetStringWidth() + 16), V.KEY_BADGE_HEIGHT)
      badge:SetPoint("CENTER", text, "CENTER", 0, 0)
    else
      text:SetFont(Theme.font, VFONT.noKey, "")
      text:SetText(L["ROSTER_NO_KEYSTONE"])
      text:SetTextColor(unpack(Theme.textFaint))
    end

  elseif key == "vault" then
    for tierIndex, tierDef in ipairs(CONST.VAULT_TIER_TYPES) do
      PV.Label(canvas, L[tierDef.labelKey], top + V.VAULT_TOP_PAD + (tierIndex - 1) * V.VAULT_ROW_HEIGHT,
        V.VAULT_ROW_HEIGHT, Theme[CONST.VAULT_TIER_DOT_COLOR_KEYS[tierIndex]])
    end
    local vaultRow = { vaultCell = CreateFrame("Frame", nil, canvas) }
    vaultRow.vaultCell:SetSize(V.VAULT_SLOT_WIDTH * 3, V.VAULT_ROW_HEIGHT * #CONST.VAULT_TIER_TYPES)
    vaultRow.vaultCell:SetPoint("TOP", canvas, "TOPLEFT", cx, -(top + V.VAULT_TOP_PAD))
    vaultRow.vaultGrid = CreateVaultGrid(vaultRow)
    for tierIndex = 1, #CONST.VAULT_TIER_TYPES do
      vaultRow.vaultDots[tierIndex]:Hide()
      for slotIndex = 1, 3 do
        local cell = vaultRow.vaultGrid[tierIndex][slotIndex]
        cell:SetFont(Theme.font, V.VAULT_FONT_SIZE, "")
        cell:SetWidth(V.VAULT_SLOT_WIDTH)
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", vaultRow.vaultCell, "TOPLEFT",
          (slotIndex - 1) * V.VAULT_SLOT_WIDTH, -(tierIndex - 1) * V.VAULT_ROW_HEIGHT)
      end
    end
    PaintVaultGrid(vaultRow, datum.rawRecord)

  elseif key == "raid" then
    local difficulties = section.difficulties or {}
    local bar = V.Theme().parts.bosses == "bar"
    local band = section.bandHeight or V.RaidBandHeight()
    for i, difficultyID in ipairs(difficulties) do
      PV.Label(canvas, L[PV.DIFFICULTY_LABEL_KEYS[difficultyID]], top + (i - 1) * band,
        band, CONST.RAID_DIFFICULTY_DEFS[difficultyID].color)
    end
    PV.DrawRaidColumn(canvas, datum, difficulties, top, 1, bar and "bar" or nil, true)

  elseif key == "currencies" then
    local layout = CurrencyGrid.Layouts()
    for _, group in ipairs(layout.labels) do
      if group.labelKey and group.row < PV.CURRENCY_ROWS then
        PV.Label(canvas, L[group.labelKey], top + group.row * V.CURRENCY_ROW_HEIGHT, group.rows * V.CURRENCY_ROW_HEIGHT)
      end
    end
    local slotWidth = V.COL_CONTENT / CurrencyGrid.PER_ROW
    for _, entry in ipairs(datum.currencies or {}) do
      local cell = layout.cells[entry.slot]
      if cell and cell.row < PV.CURRENCY_ROWS and entry.kind ~= "bounty" and entry.data and entry.data.iconFileID and entry.data.iconFileID ~= 0 then
        local centerX = PV.COL_X + V.COL_PADDING + (cell.col + 0.5) * slotWidth
        local iconTop = top + cell.row * V.CURRENCY_ROW_HEIGHT + V.CURRENCY_ROW_TOP + CurrencyGrid.ICON_TOP
        local icon = canvas:CreateTexture(nil, "ARTWORK")
        icon:SetSize(CurrencyGrid.ICON_SIZE, CurrencyGrid.ICON_SIZE)
        icon:SetPoint("TOP", canvas, "TOPLEFT", centerX, -iconTop)
        GG.Widgets.SetItemIcon(icon, entry.data.iconFileID)
        local qty = CreateMonoLabel(canvas, 10, Theme.textFaint)
        qty:SetPoint("TOP", icon, "BOTTOM", 0, -CurrencyGrid.TEXT_GAP)
        qty:SetText(GG.Currencies:FormatAmount(entry.data.quantity, L["NUMBER_DECIMAL_SEPARATOR"]))
      end
    end
  end
end

function PV.DrawRaidColumn(canvas, datum, difficulties, top, scale, style, withLegend)
  local band = style == "bar" and V.RAID_BAR_HEIGHT or V.RAID_DIFFICULTY_HEIGHT
  if withLegend then band = band + V.RAID_LEGEND_HEIGHT end
  local holder = CreateFrame("Frame", nil, canvas)
  holder:SetScale(scale or 1)
  holder:SetSize(V.COL_CONTENT, math.max(#difficulties, 1) * band)
  holder:SetPoint("TOPLEFT", canvas, "TOPLEFT",
    (PV.COL_X + V.COL_PADDING) / (scale or 1), -top / (scale or 1))
  local raidRow = PreviewBuildRaidCell(holder, V.COL_CONTENT, datum, band)
  raidRow.raidCell:SetSize(V.COL_CONTENT, math.max(#difficulties, 1) * band)
  raidRow.raidCell:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
  local visible = {}
  for i, difficultyID in ipairs(difficulties) do
    visible[difficultyID] = true
    local progress = datum.raidProgress.byDifficulty[difficultyID]
    PaintRaidBar(raidRow.raidCell, raidRow.raidBars[difficultyID], progress.slots,
      datum.raidProgress.totalSegments, V.COL_CONTENT, CONST.RAID_DIFFICULTY_DEFS[difficultyID].color,
      -(i - 1) * band, band,
      { wrapRows = V.RAID_WRAP_ROWS, showLabel = false, iconSize = V.RAID_ICON_SIZE, style = style,
        legend = withLegend and L[CONST.RAID_DIFFICULTY_DEFS[difficultyID].labelKey] or nil })
  end
  for _, difficultyID in ipairs(CONST.RAID_BAR_ORDER) do
    if not visible[difficultyID] then HideRaidBar(raidRow.raidBars[difficultyID]) end
  end
end

function PV.FitHeight(container, canvas, height)
  local available = container:GetHeight()
  local scale = 1
  if available and available > 0 and height > available then scale = available / height end
  canvas:SetScale(scale)
end

local function BuildSettingsColumnsPreviewVertical(container)
  local datum = PreviewPickDatum()
  if not datum then
    local empty = CreateLabel(container, 11, Theme.textFaint)
    empty:SetPoint("TOPLEFT", 0, 0)
    empty:SetWidth(container:GetWidth())
    empty:SetWordWrap(true)
    empty:SetText(L["OPTIONS_PREVIEW_NO_CHARACTER"])
    return function() end
  end

  local canvas = CreateFrame("Frame", nil, container)
  canvas:SetPoint("TOPLEFT", 0, 0)

  return function()
    V.ApplyTheme()
    PV.Clear(canvas)
    canvas.themeSurface = nil
    canvas.previewAvatar = nil
    local fresh = PreviewPickDatum() or datum
    local y = V.TOP_PADDING
    local headSplit, headBottom
    local sections = BuildVerticalSections()
    local byKey = {}
    for _, section in ipairs(sections) do
      section.visible = IsSectionVisible(section.optionKey)
        and (section.extraVisible == nil or section.extraVisible())
      if section.key == "bounty" then section.visible = false end
      byKey[section.key] = section
    end
    for _, section in ipairs(sections) do
      if section.group then
        local any = false
        for _, key in ipairs(section.group) do
          if byKey[key] and byKey[key].visible then any = true end
        end
        section.visible = any
      end
    end
    for _, section in ipairs(sections) do
      if section.visible then
        if section.key == "currencies" then
          section.height = PV.CURRENCY_ROWS * V.CURRENCY_ROW_HEIGHT
        end
        section.y = y
        PV.DrawSection(canvas, section, y, fresh)
        if section.key == "roster" then headSplit = y + section.height end
        if section.key == "character" then headBottom = y + section.height end
        y = y + section.height + (section.gapAfter or 0)
      end
    end
    local height = y + V.BOTTOM_PADDING

    local tok = V.Theme().tokens
    local layout = GG.RosterThemes.ColumnLayout(sections)
    local range = {}
    for _, r in ipairs(GG.Roster:BuildRows()) do
      if r.ilvl and r.ilvl > 0 then
        range.min = math.min(range.min or r.ilvl, r.ilvl)
        range.max = math.max(range.max or r.ilvl, r.ilvl)
      end
    end
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[fresh.class]
    GG.RosterThemes.PaintSurface(canvas, {
      x = PV.COL_X, y = V.TOP_PADDING, w = V.COL_WIDTH, h = math.max(1, y - V.TOP_PADDING),
      headSplit = headSplit, headBottom = headBottom,
      avatar = canvas.previewAvatar, avatarSize = CONST.PREVIEW_AVATAR_SIZE,
      layout = layout,
    }, {
      T = V.Theme(), vertical = true,
      classColor = classColor and { classColor.r, classColor.g, classColor.b } or nil,
      isCurrent = fresh.isCurrent == true, alphaMul = 1,
      heat = tok.heat and V.HeatOf(fresh, range) or nil,
    })

    if tok.blocks and #layout.blocks > 0 then
      local top, bottom = layout.blocks[1].a, layout.blocks[#layout.blocks].b
      GG.RosterThemes.PaintSpine(canvas, {}, { x = 0, y = top, w = tok.spineWidth or 3, h = bottom - top },
        "VERTICAL", layout.blocks, top, tok.blocks)
    end

    canvas:SetSize(PV.COL_X + V.COL_WIDTH, height)
    PV.FitHeight(container, canvas, height)
  end
end

local function BuildSettingsBossesPreviewVertical(container)
  local datum = PreviewPickDatum()
  if not datum then
    local empty = CreateLabel(container, 11, Theme.textFaint)
    empty:SetPoint("TOPLEFT", 0, 0)
    empty:SetWidth(container:GetWidth())
    empty:SetWordWrap(true)
    empty:SetText(L["OPTIONS_PREVIEW_NO_CHARACTER"])
    return function() end
  end

  local canvas = CreateFrame("Frame", nil, container)
  canvas:SetPoint("TOPLEFT", 0, 0)
  local SCALE = 1.15

  return function()
    PV.Clear(canvas)
    local difficulties = VisibleRaidDifficulties()
    local bandHeight = V.RAID_DIFFICULTY_HEIGHT * SCALE
    for i, difficultyID in ipairs(difficulties) do
      PV.Label(canvas, L[PV.DIFFICULTY_LABEL_KEYS[difficultyID]], 4 + (i - 1) * bandHeight,
        bandHeight, CONST.RAID_DIFFICULTY_DEFS[difficultyID].color)
    end
    PV.DrawRaidColumn(canvas, datum, difficulties, 4, SCALE)
    local height = 8 + math.max(#difficulties, 1) * bandHeight
    canvas:SetSize(PV.COL_X + V.COL_PADDING + V.COL_CONTENT * SCALE, height)
  end
end

local function PositionHeaderCells()
  for _, col in ipairs(CONST.COLUMNS) do
    local cell = header.cells[col.key]
    local layout = columnLayout[col.key]
    cell:SetShown(layout.visible)
    cell:ClearAllPoints()
    cell:SetPoint("BOTTOMLEFT", header.row, "BOTTOMLEFT", layout.x + CONST.CELL_PADDING, 7)
    if header.hitboxes[col.key] then
      header.hitboxes[col.key]:SetShown(layout.visible)
    end
  end

  header.groupLabels = header.groupLabels or {}
  header.groupLines = header.groupLines or {}
  local starts = {}
  local startBlocks, spanStarts = {}, {}
  local GROUP_BLOCKS = { "overview", "weekly", "currencies" }
  local split = columnLayout.currencies.visible and CurrencyGrid.QuestsVisible()
  for groupIndex, group in ipairs(CONST.COLUMN_GROUPS) do
    local firstX, inGroup = nil, false
    for _, col in ipairs(CONST.COLUMNS) do
      if col.key == group.first then inGroup = true end
      if inGroup and not firstX and columnLayout[col.key].visible then firstX = columnLayout[col.key].x end
      if col.key == group.last then inGroup = false end
    end
    local label = header.groupLabels[groupIndex]
    if not label then
      label = CreateLabel(header.row, V.LABEL_SIZE, Theme.accent, true)
      header.groupLabels[groupIndex] = label
    end
    label:SetShown(firstX ~= nil)
    if firstX then
      label:ClearAllPoints()
      label:SetPoint("TOPLEFT", header.row, "TOPLEFT", firstX + CONST.CELL_PADDING, -6)
      label:SetText(L[group.labelKey])
      local block = GROUP_BLOCKS[groupIndex] or "overview"
      if groupIndex == #CONST.COLUMN_GROUPS and split then block = "quests" end
      if firstX > 0 then
        table.insert(starts, firstX)
        table.insert(startBlocks, block)
      end
      spanStarts[#spanStarts + 1] = { x = firstX, block = block }
    end
  end
  local currLayout = columnLayout.currencies
  header.cells.currencies:SetText("")
  if header.groupLabels[#CONST.COLUMN_GROUPS] then
    header.groupLabels[#CONST.COLUMN_GROUPS]:SetText(L[split and "ROSTER_GROUP_QUESTS" or "ROSTER_GROUP_CURRENCIES"])
  end
  header.splitGroup = header.splitGroup or CreateLabel(header.row, V.LABEL_SIZE, Theme.accent, true)
  header.splitGroup:SetShown(split)
  if split then
    local x = currLayout.x + CONST.CELL_PADDING + CurrencyGrid.DelvesLead() - CONST.QUESTS_CURRENCY_GAP / 2
    table.insert(starts, x)
    table.insert(startBlocks, "currencies")
    spanStarts[#spanStarts + 1] = { x = x, block = "currencies" }
    header.splitGroup:ClearAllPoints()
    header.splitGroup:SetPoint("TOPLEFT", header.row, "TOPLEFT", x + CONST.CELL_PADDING, -6)
    header.splitGroup:SetText(L["ROSTER_GROUP_CURRENCIES"])
  end
  header.blockLabels = header.blockLabels or {}
  local _, sideBySide = CurrencyGrid.Layouts()
  local blockX = CurrencyGrid.BlockOffsets()
  local gridX = currLayout.x + CONST.CELL_PADDING + CurrencyGrid.DelvesLead()
  for i = 1, math.max(#sideBySide.blockColumns, #header.blockLabels) do
    local label = header.blockLabels[i]
    if not label then
      label = CreateLabel(header.row, V.SMALL_SIZE, Theme.textFaint, true)
      header.blockLabels[i] = label
    end
    local labelKey = sideBySide.blockLabels[i]
    label:SetShown(currLayout.visible and labelKey ~= nil)
    if labelKey then
      label:SetText(L[labelKey])
      label:ClearAllPoints()
      label:SetPoint("BOTTOMLEFT", header.row, "BOTTOMLEFT", gridX + blockX[i], 7)
    end
  end

  local tok = V.Theme().tokens
  local headerLines = tok.headerLines ~= false
  for i, x in ipairs(starts) do
    local line = header.groupLines[i]
    if not line then
      line = header.row:CreateTexture(nil, "ARTWORK")
      line:SetWidth(1)
      header.groupLines[i] = line
    end
    local c, alpha = Theme.border, 1
    if tok.listLines == "block" and tok.blocks and tok.blocks[startBlocks[i]] then
      c, alpha = tok.blocks[startBlocks[i]], tok.listLineAlpha or 0.3
    end
    line:SetColorTexture(c[1], c[2], c[3], (c[4] or 1) * alpha)
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", header.row, "TOPLEFT", x, 0)
    line:SetPoint("BOTTOMLEFT", header.row, "BOTTOMLEFT", x, 0)
    line:SetShown(headerLines)
  end
  for i = #starts + 1, #header.groupLines do header.groupLines[i]:Hide() end
  state.groupStarts = starts
  state.groupStartBlocks = startBlocks
  state.groupSpanStarts = spanStarts

  header.railSpine = header.railSpine or {}
  if tok.blocks then
    local rightInset = CONST.LIST_CARD_RIGHT + CONST.SCROLLBAR_WIDTH + 4
    local endX = (state.listBodyWidth or header.row:GetWidth() or 0) - CONST.LIST_CARD_RIGHT
    local sw = tok.spineWidth or 3
    GG.RosterThemes.PaintSpine(header.row, header.railSpine,
      { x = CONST.LIST_CARD_LEFT, y = CONST.HEADER_HEIGHT - sw, h = sw, right = rightInset },
      "HORIZONTAL", GG.RosterThemes.ListSpans(spanStarts, endX), CONST.LIST_CARD_LEFT, tok.blocks)
  else
    GG.RosterThemes.HideSpine(header.railSpine)
  end
end

local function AnchorRow(row, index)
  row:ClearAllPoints()
  row.gapCatcher = row.gapCatcher or CreateFrame("Frame", nil, row)
  row.gapCatcher:ClearAllPoints()
  if IsVertical() then
    row:SetPoint("TOPLEFT", scrollClip, "TOPLEFT", V.COL_GAP + (index - 1) * V.ColPitch(), 0)
    row:SetWidth(V.COL_WIDTH)
    row.gapCatcher:SetPoint("TOPLEFT", row, "TOPRIGHT", 0, 0)
    row.gapCatcher:SetPoint("BOTTOMLEFT", row, "BOTTOMRIGHT", 0, 0)
    row.gapCatcher:SetWidth(math.max(1, V.COL_GAP))
    row.gapCatcher:SetShown(V.COL_GAP > 0)
  else
    row:SetPoint("TOPLEFT", scrollClip, "TOPLEFT", 0, -(index - 1) * (CONST.ROW_HEIGHT + CONST.ROW_GAP))
    row:SetPoint("RIGHT", scrollClip, "RIGHT", 0, 0)
    row.gapCatcher:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, 0)
    row.gapCatcher:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.gapCatcher:SetHeight(math.max(1, CONST.ROW_GAP))
    row.gapCatcher:SetShown(CONST.ROW_GAP > 0)
  end
end

local function EnsureRowPoolSize(count)
  for i = #rowPool + 1, count do
    local row = CreateRow(scrollClip)
    AnchorRow(row, i)
    PositionRowColumns(row)
    rowPool[i] = row
  end
end

local function VisibleRowCount()
  if IsVertical() then
    local visibleWidth = scrollClip:GetWidth()
    if visibleWidth <= 0 then return 8 end
    return math.floor(visibleWidth / V.ColPitch()) + 2
  end
  local visibleHeight = scrollClip:GetHeight()
  if visibleHeight <= 0 then return 12 end
  return math.floor(visibleHeight / (CONST.ROW_HEIGHT + CONST.ROW_GAP)) + 2
end

local function FullyVisibleRowCount()
  if IsVertical() then
    local visibleWidth = scrollClip:GetWidth()
    if visibleWidth <= 0 then return 1 end
    return math.max(1, math.floor(visibleWidth / V.ColPitch()))
  end
  local visibleHeight = scrollClip:GetHeight()
  if visibleHeight <= 0 then return 1 end
  return math.max(1, math.floor((visibleHeight + CONST.ROW_GAP) / (CONST.ROW_HEIGHT + CONST.ROW_GAP)))
end

local function UpdateEmptyState()
  if not frame.emptyText then
    frame.emptyText = CreateLabel(scrollClip, 12, Theme.textFaint)
    frame.emptyText:SetPoint("TOP", scrollClip, "TOP", 0, -40)
  end
  if state.filterTab == "raid" or state.filterTab == "bonusRoll" or state.filterTab == "rosters" then
    frame.emptyText:Hide()
    return
  end
  if #dataRows > 0 then
    frame.emptyText:Hide()
    return
  end
  local total = #GG.Roster:BuildRows()
  local text
  if total > 0 then
    text = L["ROSTER_NO_RESULTS"]
  elseif GG:CountHiddenCharacters() > 0 then
    text = L["ROSTER_ALL_HIDDEN"]
  else
    text = L["ROSTER_EMPTY"]
  end
  frame.emptyText:SetText(text)
  frame.emptyText:Show()
end

function V.PaintTableDecor(shownCount)
  if not scrollClip then return end
  local tok = V.Theme().tokens
  local store = V.tableDecor
  local active = IsVertical() and tok.separator == "glow" and (shownCount or 0) > 0
  local ys = active and verticalDecor.glows or {}
  if #ys == 0 then
    if store then GG.RosterThemes.HideGlowSeparators(store) end
    return
  end
  if not store then
    local f = CreateFrame("Frame", nil, scrollClip)
    f:SetAllPoints(scrollClip)
    f:SetFrameLevel(scrollClip:GetFrameLevel())
    store = { frame = f }
    V.tableDecor = store
  end
  local width = shownCount * V.ColPitch() - V.COL_GAP
  local clipW = scrollClip:GetWidth()
  if clipW and clipW > 0 then width = math.min(width, clipW - V.COL_GAP) end
  GG.RosterThemes.PaintGlowSeparators(store.frame, store, V.COL_GAP, math.max(1, width), ys, tok)
end

local function UpdateVisibleRows()
  if state.filterTab ~= "all" then
    for _, row in ipairs(rowPool) do row:Hide() end
    V.PaintTableDecor(0)
    if state.filterTab == "raid" or state.filterTab == "bonusRoll" or state.filterTab == "rosters" then
      if scrollbar then scrollbar:Hide() end
      if hscrollbar then hscrollbar:Hide() end
    end
    return
  end

  local total = #dataRows
  local maxOffset = math.max(0, total - FullyVisibleRowCount())
  scrollOffset = math.max(0, math.min(scrollOffset, maxOffset))

  local shownCount = 0
  for i, row in ipairs(rowPool) do
    local dataIndex = scrollOffset + i
    local datum = dataRows[dataIndex]
    if datum then
      PaintRow(row, datum, dataIndex)
      row:Show()
      shownCount = i
    else
      row.datum = nil
      row:Hide()
    end
  end
  V.PaintTableDecor(shownCount)

  local activeBar = IsVertical() and hscrollbar or scrollbar
  local idleBar = IsVertical() and scrollbar or hscrollbar
  if idleBar then idleBar:Hide() end
  if activeBar then
    if maxOffset > 0 and not settingsOpen then
      activeBar:SetMinMaxValues(0, maxOffset)
      activeBar:SetValue(scrollOffset)
      activeBar:Show()
    else
      activeBar:Hide()
    end
  end

  UpdateEmptyState()
end

local function CreateVaultCard(parent)
  local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  card:SetSize(CONST.VAULT_CARD_WIDTH, CONST.VAULT_CARD_HEIGHT)
  ApplyBackdrop(card, Theme.panel, Theme.border, 2)

  card.hoverGlow = card:CreateTexture(nil, "OVERLAY")
  card.hoverGlow:SetAllPoints()
  card.hoverGlow:SetColorTexture(1, 1, 1, 0.035)
  card.hoverGlow:Hide()
  card:EnableMouse(true)
  card:SetScript("OnEnter", function(self) self.hoverGlow:Show() end)
  card:SetScript("OnLeave", function(self) self.hoverGlow:Hide() end)
  card.mainRing = card:CreateTexture(nil, "BORDER")
  card.mainRing:SetSize(24 + 4, 24 + 4)
  card.mainRing:SetColorTexture(unpack(Theme.gold))
  card.mainRing:SetPoint("TOPLEFT", CONST.VAULT_CARD_PADDING - 4, -(CONST.VAULT_CARD_PADDING - 4))
  card.mainRing:Hide()

  card.classIconRing = card:CreateTexture(nil, "BORDER")
  card.classIconRing:SetSize(24, 24)
  card.classIconRing:SetPoint("TOPLEFT", CONST.VAULT_CARD_PADDING - 2, -(CONST.VAULT_CARD_PADDING - 2))

  card.classIcon = card:CreateTexture(nil, "ARTWORK")
  card.classIcon:SetSize(20, 20)
  card.classIcon:SetPoint("CENTER", card.classIconRing, "CENTER", 0, 0)

  local textWidth = CONST.VAULT_CARD_WIDTH - CONST.VAULT_CARD_PADDING * 2 - 20 - 6
  card.nameText = CreateLabel(card, 12, Theme.textPrimary, true)
  card.nameText:SetPoint("TOPLEFT", card.classIcon, "TOPRIGHT", 6, -1)
  card.nameText:SetWidth(textWidth)

  card.realmText = CreateLabel(card, 9.5, Theme.textFaint)
  card.realmText:SetPoint("TOPLEFT", card.nameText, "BOTTOMLEFT", 0, -1)
  card.realmText:SetWidth(textWidth)

  card.mainBadge = CreateFrame("Frame", nil, card, "BackdropTemplate")
  card.mainBadge:SetHeight(14)
  ApplyBackdrop(card.mainBadge, { 0.910, 0.722, 0.361, 0.18 }, Theme.gold)
  local vaultMainBadgeText = CreateLabel(card.mainBadge, 9, Theme.gold)
  vaultMainBadgeText:SetPoint("CENTER", card.mainBadge, "CENTER", 0, 0)
  vaultMainBadgeText:SetText(L["ROSTER_TAG_MAIN"])
  card.mainBadge:SetWidth(vaultMainBadgeText:GetStringWidth() + 10)
  card.mainBadge:Hide()

  card.body = CreateFrame("Frame", nil, card)
  card.body:SetPoint("TOPLEFT", CONST.VAULT_CARD_PADDING, -CONST.VAULT_CARD_HEADER_HEIGHT)
  card.body:SetPoint("TOPRIGHT", -CONST.VAULT_CARD_PADDING, -CONST.VAULT_CARD_HEADER_HEIGHT)
  card.body:SetHeight(1)

  card.topBand = card:CreateTexture(nil, "ARTWORK")
  card.topBand:SetPoint("TOPLEFT", 2, -2)
  card.topBand:SetPoint("TOPRIGHT", -2, -2)
  card.topBand:SetHeight(3)
  card.headGlow = card:CreateTexture(nil, "BACKGROUND", nil, 1)
  card.headGlow:SetPoint("TOPLEFT", 2, -2)
  card.headGlow:SetPoint("TOPRIGHT", -2, -2)
  card.headGlow:SetHeight(40)
  card.headGlow:SetColorTexture(1, 1, 1, 1)

  card.acctChip = CreateFrame("Frame", nil, card)
  card.acctChip:SetHeight(16)
  card.acctChip:SetPoint("TOPRIGHT", -CONST.VAULT_CARD_PADDING, -CONST.VAULT_CARD_PADDING)
  card.acctChip.bg = card.acctChip:CreateTexture(nil, "BACKGROUND")
  card.acctChip.bg:SetAllPoints()
  card.acctChip.text = CreateLabel(card.acctChip, 10, Theme.textPrimary, true)
  card.acctChip.text:SetPoint("CENTER", 0, 0)

  card.stateChip = CreateFrame("Frame", nil, card)
  card.stateChip:SetHeight(18)
  card.stateChip:SetPoint("TOPLEFT", CONST.VAULT_CARD_PADDING, -42)
  card.stateChip.bg = card.stateChip:CreateTexture(nil, "BACKGROUND")
  card.stateChip.bg:SetAllPoints()
  card.stateChip.dot = card.stateChip:CreateTexture(nil, "ARTWORK")
  card.stateChip.dot:SetSize(6, 6)
  card.stateChip.dot:SetPoint("LEFT", 7, 0)
  card.stateChip.text = CreateLabel(card.stateChip, 10, Theme.textPrimary, true)
  card.stateChip.text:SetPoint("LEFT", card.stateChip.dot, "RIGHT", 5, 0)

  card:Hide()
  return card
end

local function SetVaultCardState(card, kind)
  local defs = {
    ready = { color = Theme.ready, key = "VAULT_STATE_READY" },
    open = { color = Theme.gold, key = "VAULT_STATE_OPEN" },
    reset = { color = Theme.gold, key = "VAULT_STATE_RESET" },
    claimed = { color = Theme.success, key = "VAULT_STATE_CLAIMED" },
  }
  local def = defs[kind] or defs.open
  local c = def.color
  card.stateChip.bg:SetColorTexture(c[1], c[2], c[3], 0.16)
  card.stateChip.dot:SetColorTexture(c[1], c[2], c[3], 1)
  card.stateChip.text:SetTextColor(c[1], c[2], c[3], 1)
  card.stateChip.text:SetText(L[def.key]:upper())
  card.stateChip:SetWidth(card.stateChip.text:GetStringWidth() + 26)
end

local function ClearVaultCardBody(card)
  for _, region in ipairs({ card.body:GetRegions() }) do
    region:Hide()
    region:SetParent(nil)
  end
  for _, child in ipairs({ card.body:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end
end

local function PaintVaultCard(card, row)
  ClearVaultCardBody(card)

  card.mainRing:SetShown(row.isMain)
  card.mainBadge:SetShown(row.isMain)

  local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.class]
  card.nameText:SetText(row.name)
  if classColor then
    card.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)
    card.classIconRing:SetColorTexture(classColor.r, classColor.g, classColor.b, 0.7)
    card.topBand:SetColorTexture(classColor.r, classColor.g, classColor.b, 1)
    card.headGlow:SetGradient("VERTICAL", CreateColor(classColor.r, classColor.g, classColor.b, 0),
      CreateColor(classColor.r, classColor.g, classColor.b, 0.14))
  else
    card.nameText:SetTextColor(unpack(Theme.textPrimary))
    card.classIconRing:SetColorTexture(unpack(Theme.borderSoft))
    card.topBand:SetColorTexture(unpack(Theme.border))
    card.headGlow:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.04))
  end
  card:SetBackdropBorderColor(unpack(Theme.border))

  local accountColors = CONST.ACCOUNT_COLORS
  local ac = accountColors[((row.accountSlot or 1) - 1) % #accountColors + 1]
  card.acctChip:SetShown((row.accountLabel or "") ~= "")
  card.acctChip.text:SetText(row.accountLabel or "")
  card.acctChip.text:SetTextColor(ac[1], ac[2], ac[3], 1)
  card.acctChip.bg:SetColorTexture(ac[1], ac[2], ac[3], 0.18)
  card.acctChip:SetWidth(card.acctChip.text:GetStringWidth() + 12)
  card.realmText:SetText(row.realm)
  if row.isMain then
    card.mainBadge:ClearAllPoints()
    card.mainBadge:SetPoint("LEFT", card.nameText, "LEFT", card.nameText:GetStringWidth() + 6, 0)
  end
  GG.Widgets.SetClassIcon(card.classIcon, CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[row.class])

  local record = row.rawRecord

  if not row.vault.hasAvailableRewards and row.vault.claim then
    card:SetBackdropBorderColor(Theme.success[1], Theme.success[2], Theme.success[3], 0.6)
    SetVaultCardState(card, "claimed")
    GG.VaultGrid:DrawClaim(card.body, row.vault.claim, CONST.VAULT_CARD_WIDTH - CONST.VAULT_CARD_PADDING * 2,
      CONST.VAULT_CARD_HEIGHT - CONST.VAULT_CARD_HEADER_HEIGHT - CONST.VAULT_CARD_PADDING, true)
    return
  end

  local isCurrentWeek = GG.Vault:IsCurrentWeek(record)
  local allSlots = (isCurrentWeek and record.vault and record.vault.slots) or {}

  if not isCurrentWeek or not GG.Vault:HasFreshItemData(record) or #allSlots == 0 then
    local text = not isCurrentWeek and L["VAULT_PENDING_AFTER_RESET"] or (#allSlots == 0 and L["VAULT_PREVIEW_NONE"] or L["VAULT_PREVIEW_STALE"])
    SetVaultCardState(card, isCurrentWeek and "open" or "reset")
    GG.VaultGrid:DrawHint(card.body, CONST.VAULT_CARD_WIDTH - CONST.VAULT_CARD_PADDING * 2,
      CONST.VAULT_CARD_HEIGHT - CONST.VAULT_CARD_HEADER_HEIGHT - CONST.VAULT_CARD_PADDING, text)
    return
  end

  local resolved = false
  for _, slot in ipairs(allSlots) do
    if slot.itemLink then
      resolved = true
      break
    end
  end

  if not resolved then
    SetVaultCardState(card, "open")
    GG.VaultGrid:DrawHint(card.body, CONST.VAULT_CARD_WIDTH - CONST.VAULT_CARD_PADDING * 2,
      CONST.VAULT_CARD_HEIGHT - CONST.VAULT_CARD_HEADER_HEIGHT - CONST.VAULT_CARD_PADDING, L["VAULT_PENDING_NOT_OPENED"])
    return
  end

  SetVaultCardState(card, "ready")
  GG.VaultGrid:Draw(card.body, allSlots, 0, 0)
end

local function EnsureVaultCardPoolSize(count)
  for i = #vaultCardPool + 1, count do
    vaultCardPool[i] = CreateVaultCard(vaultCardContainer)
  end
end

local function CreateVaultSectionHeader(parent)
  local header = CreateFrame("Frame", nil, parent)
  header:SetHeight(20)
  header.label = CreateLabel(header, 11.5, Theme.textMuted, true)
  header.label:SetPoint("LEFT", 0, 0)
  header.badge = CreateFrame("Frame", nil, header)
  header.badge:SetHeight(16)
  header.badge:SetPoint("LEFT", header.label, "RIGHT", 8, 0)
  header.badge.bg = header.badge:CreateTexture(nil, "BACKGROUND")
  header.badge.bg:SetAllPoints()
  header.badge.text = CreateLabel(header.badge, 10, Theme.textPrimary, true)
  header.badge.text:SetPoint("CENTER", 0, 0)
  header.line = header:CreateTexture(nil, "ARTWORK")
  header.line:SetHeight(1)
  header.line:SetColorTexture(unpack(Theme.border))
  header.line:SetPoint("LEFT", header.badge, "RIGHT", 10, 0)
  header.line:SetPoint("RIGHT", header, "RIGHT", 0, 0)
  function header:Paint(text, count, color, solid)
    self.label:SetText(text:upper())
    self.badge.text:SetText(tostring(count))
    self.badge.text:SetTextColor(unpack(solid and { 1, 1, 1, 1 } or color))
    self.badge.bg:SetColorTexture(color[1], color[2], color[3], solid and 1 or 0.18)
    self.badge:SetWidth(math.max(18, self.badge.text:GetStringWidth() + 10))
  end
  return header
end

local function UpdateVaultCards(repaint)
  if state.filterTab ~= "vaultPending" then
    for _, card in ipairs(vaultCardPool) do card:Hide() end
    for _, header in ipairs(vaultCardContainer.headers or {}) do header:Hide() end
    if vaultCardContainer.emptyText then vaultCardContainer.emptyText:Hide() end
    return
  end

  local total = math.min(#dataRows, CONST.VAULT_CARD_POOL_SIZE)
  EnsureVaultCardPoolSize(total)

  local availableWidth = scrollClip:GetWidth() - CONST.VAULT_GRID_MARGIN * 2
  local columnsCount = math.max(1, math.floor((availableWidth + CONST.VAULT_CARD_GAP) / (CONST.VAULT_CARD_WIDTH + CONST.VAULT_CARD_GAP)))

  local pendingCount = 0
  for i = 1, total do
    if dataRows[i].vault.hasAvailableRewards then pendingCount = pendingCount + 1 end
  end
  local sections = {
    { first = 1, last = pendingCount, labelKey = "VAULT_SECTION_PENDING", color = Theme.ready, solid = true },
    { first = pendingCount + 1, last = total, labelKey = "VAULT_SECTION_CLAIMED", color = Theme.success },
  }
  vaultCardContainer.headers = vaultCardContainer.headers or {}
  local cardY = {}
  local y = 0
  for sectionIndex, section in ipairs(sections) do
    local header = vaultCardContainer.headers[sectionIndex]
    if not header then
      header = CreateVaultSectionHeader(vaultCardContainer)
      vaultCardContainer.headers[sectionIndex] = header
    end
    local count = section.last - section.first + 1
    if count > 0 then
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", vaultCardContainer, "TOPLEFT", 0, -y)
      header:SetWidth(math.max(availableWidth, CONST.VAULT_CARD_WIDTH))
      header:Paint(L[section.labelKey], count, section.color, section.solid)
      header:Show()
      y = y + 30
      for i = section.first, section.last do
        local k = i - section.first
        cardY[i] = { col = k % columnsCount, y = y + math.floor(k / columnsCount) * (CONST.VAULT_CARD_HEIGHT + CONST.VAULT_CARD_GAP) }
      end
      y = y + math.ceil(count / columnsCount) * (CONST.VAULT_CARD_HEIGHT + CONST.VAULT_CARD_GAP) + 8
    else
      header:Hide()
    end
  end
  vaultCardContainer.sectionsHeight = y

  for i, card in ipairs(vaultCardPool) do
    local row = dataRows[i]
    if row and i <= CONST.VAULT_CARD_POOL_SIZE then
      local place = cardY[i]
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", vaultCardContainer, "TOPLEFT", place.col * (CONST.VAULT_CARD_WIDTH + CONST.VAULT_CARD_GAP), -place.y)
      if repaint then
        local ok, err = pcall(PaintVaultCard, card, row)
        if not ok then
          print(L["DIAG_CARD_ERROR"]:format(tostring(row.name), tostring(err)))
        end
      end
      card:Show()
    else
      card:Hide()
    end
  end

  local numCardRows = (total > 0) and math.ceil(total / columnsCount) or 0
  local contentHeight = math.max(scrollClip:GetHeight(), CONST.VAULT_GRID_MARGIN * 2 + (vaultCardContainer.sectionsHeight or 0))
  vaultCardContainer:SetSize(math.max(availableWidth, columnsCount * (CONST.VAULT_CARD_WIDTH + CONST.VAULT_CARD_GAP)), contentHeight)

  local maxOffsetPx = math.max(0, contentHeight - scrollClip:GetHeight())
  vaultScrollOffsetPx = math.max(0, math.min(vaultScrollOffsetPx, maxOffsetPx))
  vaultCardContainer:ClearAllPoints()
  vaultCardContainer:SetPoint("TOPLEFT", scrollClip, "TOPLEFT", CONST.VAULT_GRID_MARGIN, -CONST.VAULT_GRID_MARGIN + vaultScrollOffsetPx)

  if hscrollbar then hscrollbar:Hide() end
  if scrollbar then
    if maxOffsetPx > 0 and not settingsOpen then
      scrollbar:SetMinMaxValues(0, maxOffsetPx)
      scrollbar:SetValue(vaultScrollOffsetPx)
      scrollbar:Show()
    else
      scrollbar:Hide()
    end
  end

  if not vaultCardContainer.emptyText then
    vaultCardContainer.emptyText = CreateLabel(scrollClip, 12, Theme.textFaint)
    vaultCardContainer.emptyText:SetPoint("TOP", scrollClip, "TOP", 0, -40)
  end
  vaultCardContainer.emptyText:SetShown(total == 0)
  if total == 0 then
    vaultCardContainer.emptyText:SetText(state.search ~= "" and L["ROSTER_NO_RESULTS"] or L["VAULT_PENDING_GRID_EMPTY"])
  end
end

local AutoSizeWindow

local function SyncAccountTabs(rows)
  local seg = state.accountSeg
  if not seg then return end
  local seen, accounts = {}, {}
  for _, row in ipairs(rows) do
    local label = row.accountLabel
    if label and label ~= "" and not seen[label] then
      seen[label] = true
      table.insert(accounts, { label = label, slot = row.accountSlot or 99 })
    end
  end
  table.sort(accounts, function(a, b)
    if a.slot ~= b.slot then return a.slot < b.slot end
    return a.label < b.label
  end)
  if #accounts < 2 then accounts = {} end

  if state.accountFilter and (#accounts == 0 or not seen[state.accountFilter]) then
    state.accountFilter = nil
  end

  local keys = {}
  for _, account in ipairs(accounts) do table.insert(keys, account.label) end
  local signature = table.concat(keys, "|")
  if signature ~= state.accountTabSignature then
    state.accountTabSignature = signature
    local options = {}
    if #accounts > 0 then
      options[1] = { key = "__all", label = L["CTX_ALL"] }
      for _, account in ipairs(accounts) do table.insert(options, { key = account.label, label = account.label }) end
    end
    seg:SetOptions(options)
    LayoutActionRail()
  end
  seg:Paint(state.accountFilter or "__all")
end

local function RebuildDataRows()
  local rows = GG.Roster:BuildRows()
  SyncAccountTabs(rows)
  UpdateNavBadges(rows)
  if #rows ~= state.charCount then
    state.charCount = #rows
    if AutoSizeWindow then AutoSizeWindow() end
  end

  local filtered = {}
  for _, row in ipairs(rows) do
    if RowMatchesFilterTab(row) and RowMatchesSearch(row) then
      table.insert(filtered, row)
    end
  end
  if state.sortKey == "custom" then PrepareArrange(rows) end
  local comparator = BuildComparator()
  if state.filterTab == "vaultPending" then
    local base = comparator
    comparator = function(a, b)
      local pa, pb = a.vault.hasAvailableRewards == true, b.vault.hasAvailableRewards == true
      if pa ~= pb then return pa end
      return base(a, b)
    end
  end
  table.sort(filtered, comparator)
  SyncSortedByLabel()

  dataRows = filtered
  V.ApplyTheme()
  local ilvlMin, ilvlMax
  for _, r in ipairs(filtered) do
    if r.ilvl and r.ilvl > 0 then
      ilvlMin = math.min(ilvlMin or r.ilvl, r.ilvl)
      ilvlMax = math.max(ilvlMax or r.ilvl, r.ilvl)
    end
  end
  if ilvlMax then ilvlMin = math.max(ilvlMin, ilvlMax - V.ILVL_GAUGE_WINDOW) end
  state.ilvlRange = { min = ilvlMin, max = ilvlMax }
  UpdateVisibleRows()
  UpdateVaultCards(true)

  if countLabel then
    countLabel:SetText(state.compactBar and tostring(#dataRows) or L["ROSTER_COUNT"]:format(#dataRows))
  end
  if charactersBtn and charactersBtn.Sync then charactersBtn:Sync() end
  if syncLabel then
    V.PaintSyncStatus(syncLabel, GG.Roster:AccountStatus(rows))
  end
end

local function UpdateHeaderArrows()
  for _, col in ipairs(CONST.COLUMNS) do
    local cell = header.cells[col.key]
    if col.sortable then
      local label = L[col.labelKey]
      if state.sortKey == col.key then
        label = label .. " " .. (state.sortAsc and "^" or "v")
        cell:SetTextColor(unpack(Theme.textPrimary))
      else
        cell:SetTextColor(unpack(Theme.textFaint))
      end
      cell:SetText(label)
    end
  end

  if customOrderBtn then
    SyncSortedByLabel()
    local active = state.dragEditMode
    if active then
      ApplyBackdrop(customOrderBtn, Theme.accent, Theme.accent, 1)
      customOrderBtn.label:SetTextColor(unpack(Theme.onAccent))
      if customOrderBtn.icon then customOrderBtn.icon:SetVertexColor(unpack(Theme.onAccent)) end
    else
      ApplyBackdrop(customOrderBtn, { Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.16 }, Theme.accent, 1)
      customOrderBtn.label:SetTextColor(unpack(Theme.textPrimary))
      if customOrderBtn.icon then customOrderBtn.icon:SetVertexColor(unpack(Theme.accentHi)) end
    end
  end

  for _, overlay in ipairs(dimOverlays) do
    overlay:SetShown(state.dragEditMode)
  end
  if editBanner then editBanner:SetShown(state.dragEditMode) end
  if editModeBorder then editModeBorder:SetShown(state.dragEditMode) end
  if state.dragEditMode and RefreshArrangePanel then RefreshArrangePanel() end
  if state.rail and math.abs(state.rail:GetHeight() - RailHeight()) > 0.5 then
    state.rail:SetHeight(RailHeight())
    if AutoSizeWindow then AutoSizeWindow() end
  end
  if UpdateSortHalo then UpdateSortHalo() end
end

local function SetSort(key)
  if state.sortKey == key then
    state.sortAsc = not state.sortAsc
  else
    state.sortKey = key
    state.sortAsc = (key == "character" or key == "custom")
  end
  if key ~= "custom" then state.dragEditMode = false end
  UpdateHeaderArrows()
  UpdateSidebar()
  scrollOffset = 0
  vaultScrollOffsetPx = 0
  RebuildDataRows()
end

local function SetFilterTab(tab)
  state.filterTab = tab
  PaintNavTabs()
  UpdateFooter()

  GG.RosterUI:Relayout()

  if GG.RaidTab then GG.RaidTab:SetShown(tab == "raid") end
  if GG.BonusRollTab then GG.BonusRollTab:SetShown(tab == "bonusRoll") end
  if GG.RaidRostersTab then GG.RaidRostersTab:SetShown(tab == "rosters") end

  scrollOffset = 0
  vaultScrollOffsetPx = 0
  RebuildDataRows()
end

function GG.RosterUI:SelectTab(tab)
  if settingsOpen and settingsBtn then settingsBtn:Click() end
  SetFilterTab(tab)
end

function GG.RosterUI:SelectAccount(key)
  state.accountFilter = (key and key ~= "__all") and key or nil
  scrollOffset = 0
  vaultScrollOffsetPx = 0
  RebuildDataRows()
end

function UpdateSidebar()
  if not sidebar then return end

  if not IsVertical() or state.filterTab ~= "all" then
    sidebar:Hide()
    return
  end
  sidebar:Show()

  sidebar.labels = sidebar.labels or {}
  sidebar.hitboxes = sidebar.hitboxes or {}

  sidebar.vDecor = sidebar.vDecor or {}
  PaintVerticalDecor(sidebar, sidebar.vDecor, true)

  sidebar.railSpine = sidebar.railSpine or {}
  local tok = V.Theme().tokens
  local blocks = verticalDecor.layout and verticalDecor.layout.blocks or {}
  if tok.blocks and #blocks > 0 then
    local top, bottom = blocks[1].a, blocks[#blocks].b
    GG.RosterThemes.PaintSpine(sidebar, sidebar.railSpine,
      { x = tok.spineX or 4, y = top, w = tok.spineWidth or 3, h = bottom - top },
      "VERTICAL", blocks, top, tok.blocks)
  else
    GG.RosterThemes.HideSpine(sidebar.railSpine)
  end

  local labelIndex, hitboxIndex = 0, 0

  local function NextLabel(size, color, bold)
    labelIndex = labelIndex + 1
    local label = sidebar.labels[labelIndex]
    if not label then
      label = CreateLabel(sidebar, size, color, bold)
      sidebar.labels[labelIndex] = label
    end
    label:SetFont(bold and Theme.fontBold or Theme.font, size, "")
    label:SetTextColor(unpack(color))
    label:Show()
    return label
  end

  local function NextSortHitbox(label, sortKey)
    hitboxIndex = hitboxIndex + 1
    local hitbox = sidebar.hitboxes[hitboxIndex]
    if not hitbox then
      hitbox = CreateFrame("Button", nil, sidebar)
      sidebar.hitboxes[hitboxIndex] = hitbox
    end
    hitbox:SetAllPoints(label)
    hitbox:SetHitRectInsets(-4, -20, -4, -4)
    hitbox:SetScript("OnClick", function() SetSort(sortKey) end)
    hitbox:Show()
    return hitbox
  end

  for _, section in ipairs(verticalSections) do
    if section.visible then
      if section.band then
        local label = NextLabel(V.TITLE_SIZE, Theme.accent, true)
        label:SetText(L[section.band])
        label:ClearAllPoints()
        label:SetPoint("LEFT", sidebar, "TOPLEFT", V.SIDE_X, -(section.y + section.height / 2))
      elseif section.currencyLabels then
        local stacked = CurrencyGrid.Layouts()
        for _, group in ipairs(stacked.labels) do
          if group.labelKey then
            local label = NextLabel(V.LABEL_SIZE, Theme.textMuted)
            label:SetText(L[group.labelKey])
            label:ClearAllPoints()
            label:SetPoint("LEFT", sidebar, "TOPLEFT", V.SIDE_X,
              -(section.y + (group.row + group.rows / 2) * V.CURRENCY_ROW_HEIGHT))
          end
        end
      elseif section.vaultTiers then
        for tierIndex, tier in ipairs(CONST.VAULT_TIER_TYPES) do
          local label = NextLabel(V.LABEL_SIZE, Theme[CONST.VAULT_TIER_DOT_COLOR_KEYS[tierIndex]] or Theme.textMuted)
          label:SetText(L[tier.labelKey])
          label:ClearAllPoints()
          label:SetPoint("LEFT", sidebar, "TOPLEFT", V.SIDE_X,
            -(section.y + V.VAULT_TOP_PAD) - (tierIndex - 1) * V.VAULT_ROW_HEIGHT - V.VAULT_ROW_HEIGHT / 2)
        end
      elseif section.key == "raid" then
        local difficulties = section.difficulties or VisibleRaidDifficulties()
        local band = section.bandHeight or V.RaidBandHeight()
        for i, difficultyID in ipairs(difficulties) do
          local def = CONST.RAID_DIFFICULTY_DEFS[difficultyID]
          local label = NextLabel(V.LABEL_SIZE, def and def.color or Theme.textMuted)
          label:SetText(GetDifficultyInfo(difficultyID) or (def and def.abbr) or "?")
          label:ClearAllPoints()
          label:SetPoint("LEFT", sidebar, "TOPLEFT", V.SIDE_X,
            -section.y - (i - 1) * band - band / 2)
        end
      elseif section.label then
        local isSortKey = section.sortKey and state.sortKey == section.sortKey
        local label = NextLabel(V.LABEL_SIZE, isSortKey and Theme.textPrimary or Theme.textMuted)
        label:SetText(section.label .. (isSortKey and (" " .. (state.sortAsc and "^" or "v")) or ""))
        label:ClearAllPoints()
        label:SetPoint("LEFT", sidebar, "TOPLEFT", V.SIDE_X, -(section.y + section.height / 2))
        if section.sortKey then NextSortHitbox(label, section.sortKey) end
      end
    end
  end

  for i = labelIndex + 1, #sidebar.labels do sidebar.labels[i]:Hide() end
  for i = hitboxIndex + 1, #sidebar.hitboxes do sidebar.hitboxes[i]:Hide() end
end

local function SaveWindowState()
  if not frame then return end
  local point, _, relativePoint, x, y = frame:GetPoint()
  GGDB.options.rosterWindow = {
    point = point,
    relativePoint = relativePoint,
    x = x,
    y = y,
    width = frame:GetWidth(),
    height = frame:GetHeight(),
  }
end

V.HSCROLL_HEIGHT = 14

local function TabUsesOwnCanvas()
  return state.filterTab == "vaultPending" or state.filterTab == "raid" or state.filterTab == "bonusRoll"
    or state.filterTab == "rosters"
end

local function ApplyLayoutAnchors()
  if not scrollClip then return end
  UpdateContextBar()
  local top = state.ctxBar or rail
  local vertical = IsVertical()

  header.row:SetShown(not settingsOpen and not vertical and not TabUsesOwnCanvas())
  if sidebar then
    sidebar:ClearAllPoints()
    sidebar:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, CONST.FOOTER_HEIGHT + V.HSCROLL_HEIGHT)
    sidebar:SetWidth(V.SIDEBAR_WIDTH)
    sidebar:SetShown(not settingsOpen and vertical and not TabUsesOwnCanvas())
  end

  scrollClip:ClearAllPoints()
  if vertical and not TabUsesOwnCanvas() then
    scrollClip:SetPoint("TOPLEFT", top, "BOTTOMLEFT", V.SIDEBAR_WIDTH, 0)
    scrollClip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, CONST.FOOTER_HEIGHT + V.HSCROLL_HEIGHT)
  elseif vertical then
    scrollClip:SetPoint("TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    scrollClip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONST.SCROLLBAR_WIDTH - 4, CONST.FOOTER_HEIGHT)
  else
    scrollClip:SetPoint("TOPLEFT", header.row, "BOTTOMLEFT", 0, 0)
    scrollClip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONST.SCROLLBAR_WIDTH - 4, CONST.FOOTER_HEIGHT)
  end
end

local EnsureVerticalWindowHeight
local EnsureHorizontalWindowWidth

local lastRowLayoutKey
local function RowLayoutKey()
  local avatar = IsSectionVisible("avatar") and "a" or "-"
  local currencies = GG.Currencies:VisibilitySignature()
  currencies = currencies .. "|" .. V.Theme().signature
  if IsVertical() then
    local shown = {}
    for _, section in ipairs(verticalSections or {}) do
      if section.visible then shown[#shown + 1] = section.key end
    end
    return "v:" .. verticalTotalHeight .. ":" .. avatar .. ":" .. currencies
      .. ":" .. table.concat(shown, ",") .. ":" .. tostring(state.filterTab == "all")
  end
  local parts = { "h", avatar, currencies }
  for _, col in ipairs(CONST.COLUMNS) do
    local layout = columnLayout[col.key]
    parts[#parts + 1] = ("%d,%d,%s"):format(layout.x or 0, layout.width or 0, tostring(layout.visible))
  end
  return table.concat(parts, ":")
end

local function VerticalWindowHeight()
  return verticalTotalHeight + CONST.TITLEBAR_HEIGHT + RailHeight() + CONST.CTX_HEIGHT
    + CONST.FOOTER_HEIGHT + V.HSCROLL_HEIGHT + 12
end

AutoSizeWindow = function()
  if not frame then return end
  local count = state.charCount or #GG.Roster:BuildRows()
  count = math.max(1, count)
  local charactersView = state.filterTab == "all" and not settingsOpen
  local scale = frame:GetScale()
  if not scale or scale <= 0 then scale = 1 end
  local screenW, screenH = UIParent:GetWidth() / scale, UIParent:GetHeight() / scale
  local width, height
  if IsVertical() then
    local edge = 4
    local pitch = V.ColPitch()
    local maxCols = math.floor((screenW * 0.9 - V.SIDEBAR_WIDTH - edge) / pitch)
    maxCols = math.max(1, math.min(GG:GetMaxShownCharacters(), maxCols))
    local cols = math.max(math.min(count, maxCols), CONST.MIN_CHARACTER_SLOTS)
    if not charactersView then
      cols = math.max(cols, math.ceil((CONST.MIN_WINDOW_WIDTH - V.SIDEBAR_WIDTH - edge) / pitch))
    end
    width = V.SIDEBAR_WIDTH + cols * pitch + edge
    height = VerticalWindowHeight()
  else
    local chrome = 2 + CONST.TITLEBAR_HEIGHT + RailHeight() + CONST.CTX_HEIGHT
      + CONST.HEADER_HEIGHT + CONST.FOOTER_HEIGHT
    local rowPitch = CONST.ROW_HEIGHT + CONST.ROW_GAP
    local maxRows = math.floor((screenH * 0.85 - chrome) / rowPitch)
    maxRows = math.max(1, math.min(GG:GetMaxShownCharacters(), maxRows))
    width = TrueMinContentWidth() + CONST.WINDOW_CONTENT_GUTTER
    height = chrome + math.max(math.min(count, maxRows), CONST.MIN_CHARACTER_SLOTS) * rowPitch
  end
  if not charactersView then
    width = math.max(width, CONST.MIN_WINDOW_WIDTH)
    height = math.max(height, CONST.MIN_WINDOW_HEIGHT)
  end
  if not settingsOpen then
    local tab, tabWidth = state.filterTab, nil
    if tab == "raid" then
      tabWidth = CONST.RAID_WINDOW_WIDTH
    elseif tab == "rosters" and GG.RaidRostersTab then
      tabWidth = GG.RaidRostersTab.CONTENT_WIDTH + CONST.WINDOW_CONTENT_GUTTER
      height = math.max(height, CONST.ROSTERS_WINDOW_HEIGHT)
    elseif tab == "bonusRoll" and GG.BonusRollTab then
      tabWidth = GG.BonusRollTab:PreferredWidth() + CONST.WINDOW_CONTENT_GUTTER
    elseif tab == "vaultPending" then
      local pending, claimed = 0, 0
      for _, r in ipairs(GG.Roster:BuildRows()) do
        if RowMatchesFilterTab(r) then
          if r.vault and r.vault.hasAvailableRewards then pending = pending + 1 else claimed = claimed + 1 end
        end
      end
      local cards = math.max(3, math.min(6, math.max(pending, claimed)))
      tabWidth = cards * (CONST.VAULT_CARD_WIDTH + CONST.VAULT_CARD_GAP) - CONST.VAULT_CARD_GAP
        + CONST.VAULT_GRID_MARGIN * 2 + CONST.WINDOW_CONTENT_GUTTER
    end
    if tabWidth then width = math.max(tabWidth, CONST.MIN_TAB_WINDOW_WIDTH) end
  end
  if settingsOpen and GG.UI and GG.UI.SettingsWindowWidth then
    width = GG.UI:SettingsWindowWidth() or width
  end
  if math.abs(frame:GetWidth() - width) > 0.5 or math.abs(frame:GetHeight() - height) > 0.5 then
    frame:SetSize(width, height)
    return true
  end
  return false
end

function V.MeasureSidebarWidth()
  if not (Theme and L) then return 104 end
  if not measureFS then measureFS = UIParent:CreateFontString(nil, "OVERLAY") end
  local widest = 0
  local function Measure(text, size, bold, extra)
    text = text or ""
    measureFS:SetFont(bold and Theme.fontBold or Theme.font, size, "")
    measureFS:SetText(text)
    local w = measureFS:GetStringWidth()
    if not w or w <= 0 then w = #text * size * 0.55 end
    widest = math.max(widest, w + (extra or 0))
  end
  for _, section in ipairs(verticalSections or {}) do
    if section.visible then
      if section.band then
        Measure(L[section.band], V.TITLE_SIZE, true)
      elseif section.currencyLabels then
        local stacked = CurrencyGrid.Layouts()
        for _, group in ipairs(stacked.labels) do
          if group.labelKey then Measure(L[group.labelKey], V.LABEL_SIZE) end
        end
      elseif section.label then
        Measure(section.label .. " v", V.LABEL_SIZE)
      end
      for _, difficultyID in ipairs(section.difficulties or {}) do
        Measure(GetDifficultyInfo(difficultyID), V.LABEL_SIZE)
      end
    end
  end
  for _, tier in ipairs(CONST.VAULT_TIER_TYPES) do Measure(L[tier.labelKey], V.LABEL_SIZE) end
  return math.max(104, math.ceil(V.SIDE_X + widest + 12))
end

local function Relayout()
  V.ApplyTheme()
  CONST.ROW_HEIGHT = (GG.RaidRostersTab and GG.RaidRostersTab:TagsVisible())
    and CONST.ROW_HEIGHT_TAGGED or CONST.ROW_HEIGHT_BASE
  LayoutActionRail()

  verticalMap = RebuildVerticalSections()
  V.SIDEBAR_WIDTH = V.MeasureSidebarWidth()
  ApplyLayoutAnchors()

  local bodyWidth = scrollClip:GetWidth()
  columnLayout = ColumnLayout(bodyWidth)
  state.listBodyWidth = bodyWidth

  AutoSizeWindow()

  PositionHeaderCells()

  local layoutKey = RowLayoutKey()
  if layoutKey ~= lastRowLayoutKey then
    lastRowLayoutKey = layoutKey

    EnsureVerticalWindowHeight()
    EnsureHorizontalWindowWidth()

    UpdateSidebar()
    EnsureRowPoolSize(VisibleRowCount())
    for i, row in ipairs(rowPool) do
      AnchorRow(row, i)
      PositionRowColumns(row)
    end
  else
    EnsureRowPoolSize(VisibleRowCount())
  end

  UpdateVisibleRows()

  UpdateVaultCards(false)

  if state.footerHint then
    state.footerHint:SetShown(frame:GetWidth() >= state.footerHint:GetStringWidth() + 330)
  end
end

local function BuildNavTabs()
  local icons = {
    all = { file = "Interface\\AddOns\\GG\\Media\\Characters64.tga", tint = true },
    vaultPending = { atlas = "gficon-chest-evergreen-greatvault-complete", size = 19 },
    raid = { file = CONST.RAID_BOSS_ICON_TEXTURE },
    bonusRoll = { currency = 3418, fallback = "Interface\\Icons\\INV_Misc_Coin_01", crop = true },
    rosters = { file = "Interface\\Icons\\INV_Misc_Note_01", crop = true },
  }
  for _, def in ipairs(tabDefs) do
    local key = def.key
    local btn = CreateNavTab(rail, L[def.labelKey], icons[key])
    btn:SetScript("OnClick", function() GG.RosterUI:SelectTab(key) end)
    tabButtons[key] = btn
  end
  state.settingsTab = CreateNavTab(rail, L["OPTIONS_TITLE"], { file = "Interface\\Buttons\\UI-OptionsButton" })
  state.settingsTab:SetScript("OnClick", function()
    if not settingsOpen and settingsBtn then settingsBtn:Click() end
  end)
  PaintNavTabs()
end

local function BuildContextBar()
  local ctx = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  ctx:SetPoint("TOPLEFT", rail, "BOTTOMLEFT", 0, 0)
  ctx:SetPoint("TOPRIGHT", rail, "BOTTOMRIGHT", 0, 0)
  ctx:SetHeight(CONST.CTX_HEIGHT)
  ApplyBackdrop(ctx, Theme.panel, Theme.borderSoft, 1)
  table.insert(opacityPanels, { f = ctx, color = Theme.panel })
  ctx.accountLabel = CreateLabel(ctx, 10, Theme.textFaint, true)
  ctx.accountLabel:SetPoint("LEFT", 12, 0)
  ctx.accountLabel:SetText(L["CTX_ACCOUNT"]:upper())
  ctx.resetText = CreateLabel(ctx, 11, Theme.textFaint)
  ctx.resetText:SetPoint("RIGHT", -14, 0)
  state.ctxBar = ctx

  state.accountSeg = CreateSegment(ctx, function(key) GG.RosterUI:SelectAccount(key) end)
  state.layoutSeg = CreateSegment(ctx, function(key)
    if (key == "cols") ~= IsVertical() then GG.RosterUI:ToggleLayoutMode() end
  end)
  state.layoutSeg:SetOptions({
    { key = "rows", label = L["LAYOUT_ROWS"], icon = "Interface\\AddOns\\GG\\Media\\ViewHorizontal64.tga" },
    { key = "cols", label = L["LAYOUT_COLUMNS"], icon = "Interface\\AddOns\\GG\\Media\\ViewVertical64.tga" },
  })
  state.layoutSeg:Paint(IsVertical() and "cols" or "rows")
end

CONST.ARRANGE_TOP = 32
CONST.ARRANGE_ROW = 28
CONST.ARRANGE_GAP = 6
CONST.ARRANGE_CHIP = 22
CONST.ARRANGE_CHIP_TEXT_MAX = 72
CONST.ARRANGE_CLASS_ICON = 22

local function ShortRosterName(label)
  if not label then return "" end
  return label:match("^%s*(.-)%s+[-|:]%s") or label:match("^%s*(%S+)") or label
end

local ARRANGE_NOUN_KEYS = { class = "ARRANGE_NOUN_CLASS", account = "ARRANGE_NOUN_ACCOUNT", role = "ARRANGE_NOUN_ROLE" }
local ROLE_LABEL_KEYS = { TANK = "ARRANGE_ROLE_TANK", HEALER = "ARRANGE_ROLE_HEALER", DAMAGER = "ARRANGE_ROLE_DAMAGER" }
local ARRANGE_MENU = {
  { header = "ARRANGE_FAMILY_HAND" }, "free",
  { header = "ARRANGE_FAMILY_GROUP" }, "roster", "class", "account", "role",
  { header = "ARRANGE_FAMILY_SORT" }, "ilvl", "rating", "level", "name",
}

local function DeepEqual(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do
    if not DeepEqual(v, b[k]) then return false end
  end
  for k in pairs(b) do
    if a[k] == nil then return false end
  end
  return true
end

local function CreateGrip(parent)
  local grip = CreateFrame("Frame", nil, parent)
  grip:SetSize(8, 12)
  for row = 0, 2 do
    for col = 0, 1 do
      local dot = grip:CreateTexture(nil, "ARTWORK")
      dot:SetSize(2, 2)
      dot:SetPoint("TOPLEFT", col * 4 + 1, -(row * 4 + 1))
      dot:SetColorTexture(unpack(Theme.textFaint))
    end
  end
  return grip
end

local function BuildArrangePanel(parent)
  local A = GG.Arrange
  local panel = CreateFrame("Frame", nil, parent)
  panel:SetAllPoints(parent)

  local function Cfg() return state.arrangeCfg or ArrangeConfig() end
  local function HasRosters() return state.arrangeCtx and state.arrangeCtx.hasRosters end
  local function ShownBy(cfg) return A:Effective(cfg, HasRosters()) end

  local function Apply(cfg)
    GGDB.options.arrange = A:Resolve(cfg)
    state.sortKey = "custom"
    scrollOffset = 0
    vaultScrollOffsetPx = 0
    RebuildDataRows()
    UpdateHeaderArrows()
  end

  local function Tooltip(owner, text)
    GG.Tip:Open(owner, { family = "ui", anchor = "TOP" }, function(t) t:Text(text) end)
  end

  local function Token(opts, strong)
    opts.width = opts.width or 100
    opts.listAlign = "LEFT"
    local token = GG.Widgets.CreateDropdown(panel, opts)
    token:SetHeight(CONST.ARRANGE_ROW)
    token.label:SetFont(Theme.fontBold, 13, "")
    token.strong = strong
    return token
  end
  local function PaintToken(token)
    token:Refresh()
    local accent = Theme.accent
    if token.strong then
      ApplyBackdrop(token, { accent[1], accent[2], accent[3], 0.14 }, accent, 1)
      token.label:SetTextColor(unpack(accent))
      token.arrow:SetTextColor(unpack(accent))
    else
      ApplyBackdrop(token, CONST.NAV_BG, Theme.border, 1)
      token.label:SetTextColor(unpack(Theme.textPrimary))
      token.arrow:SetTextColor(unpack(Theme.textFaint))
    end
    token:SetWidth(token.label:GetStringWidth() + 34)
  end

  local function DirKey(cfg)
    if A.IsValue(cfg.by) then return cfg.by end
    if cfg.by == "roster" and HasRosters() then return "roster" end
    if A.IsGroup(cfg.by) and A.IsValue(cfg.inside) then return cfg.inside end
    return nil
  end
  local function DirEntries(key)
    if key == "roster" then
      local rosters = state.arrangeCtx.rosters
      local first, last = ShortRosterName(rosters[1]), ShortRosterName(rosters[#rosters])
      return {
        { key = "asc", label = L["ARRANGE_ROSTER_RANGE"]:format(first, last) },
        { key = "desc", label = L["ARRANGE_ROSTER_RANGE"]:format(last, first) },
      }
    end
    if key == "name" then
      return { { key = "asc", label = L["ARRANGE_A_Z"] }, { key = "desc", label = L["ARRANGE_Z_A"] } }
    end
    return { { key = "desc", label = L["ARRANGE_HIGH_FIRST"] }, { key = "asc", label = L["ARRANGE_LOW_FIRST"] } }
  end

  local lead = CreateLabel(panel, 14, Theme.textMuted, true)
  lead:SetText(L["ARRANGE_SENTENCE_BY"])

  local byToken = Token({
    listWidth = 230,
    values = function()
      local out = {}
      for _, item in ipairs(ARRANGE_MENU) do
        if type(item) == "table" then
          out[#out + 1] = { header = L[item.header] }
        elseif item ~= "roster" or HasRosters() then
          out[#out + 1] = { key = item, label = L[ARRANGE_LABEL_KEYS[item]], desc = L["ARRANGE_DESC_" .. item:upper()] }
        end
      end
      return out
    end,
    get = function() return ShownBy(Cfg()) end,
    set = function(key)
      local cfg = Cfg()
      if ShownBy(cfg) == key then return end
      cfg.by = key
      if cfg.inside == key then cfg.inside = "manual" end
      Apply(cfg)
    end,
  }, true)

  local mid = CreateLabel(panel, 14, Theme.textMuted, true)
  local insideToken = Token({
    listWidth = 140,
    values = function()
      local cfg = Cfg()
      local out = { { key = "manual", label = L["ARRANGE_MY_ORDER"] } }
      for _, k in ipairs({ "class", "account", "role", "ilvl", "rating", "level", "name" }) do
        if k ~= cfg.by then out[#out + 1] = { key = k, label = L[ARRANGE_LABEL_KEYS[k]] } end
      end
      return out
    end,
    get = function() return Cfg().inside end,
    set = function(key)
      local cfg = Cfg()
      cfg.inside = key
      Apply(cfg)
    end,
  }, false)

  local dirToken = Token({
    listWidth = 140,
    values = function()
      local key = DirKey(Cfg())
      return key and DirEntries(key) or {}
    end,
    get = function()
      local cfg = Cfg()
      local key = DirKey(cfg)
      return key and (cfg.desc[key] and "desc" or "asc") or nil
    end,
    set = function(value)
      local cfg = Cfg()
      local key = DirKey(cfg)
      if not key then return end
      cfg.desc[key] = value == "desc"
      Apply(cfg)
    end,
  }, false)

  local restore = GG.Widgets.CreateButton(panel, L["ARRANGE_RESTORE"], function()
    local entry = state.arrangeEntry
    if not entry then return end
    GGDB.options.customOrder = CopyTable(entry.order)
    Apply(CopyTable(entry.arrange))
  end)
  restore:SetHeight(CONST.ARRANGE_ROW - 2)
  restore:HookScript("OnEnter", function(self) Tooltip(self, L["ARRANGE_RESTORE_TIP"]) end)
  restore:HookScript("OnLeave", function() GameTooltip:Hide() end)
  local done = CreateFrame("Button", nil, panel, "BackdropTemplate")
  done:SetHeight(CONST.ARRANGE_ROW - 2)
  done.label = CreateLabel(done, 12, Theme.onAccent, true)
  done.label:SetPoint("CENTER")
  done.label:SetText(L["ARRANGE_DONE"])
  done:SetWidth(math.max(90, done.label:GetStringWidth() + 36))
  local function PaintDone(hover)
    local a = Theme.accent
    local k = hover and 1.12 or 1
    ApplyBackdrop(done, { math.min(1, a[1] * k), math.min(1, a[2] * k), math.min(1, a[3] * k), 1 }, a, 1)
  end
  PaintDone(false)
  done:SetScript("OnEnter", function(self)
    PaintDone(true)
    Tooltip(self, L["ARRANGE_DONE_TIP"])
  end)
  done:SetScript("OnLeave", function()
    PaintDone(false)
    GameTooltip:Hide()
  end)
  done:SetScript("OnClick", function()
    if state.dragEditMode and customOrderBtn then customOrderBtn:Click() end
  end)

  local grip = CreateGrip(panel)
  local note = CreateLabel(panel, 11.5, Theme.textMuted)

  local strips = {}
  for i = 1, 2 do strips[i] = { chips = {} } end
  local chipDrag

  local function EndChipDrag()
    if not chipDrag then return end
    chipDrag = nil
    panel:SetScript("OnUpdate", nil)
    RefreshArrangePanel()
  end

  local function ChipDragUpdate()
    if not chipDrag then return end
    if not IsMouseButtonDown("LeftButton") then EndChipDrag(); return end
    local strip = strips[chipDrag.strip]
    if not (strip.key and Cfg().strips[strip.key]) then EndChipDrag(); return end
    for i, chip in ipairs(strip.chips) do
      if chip:IsShown() and i ~= chipDrag.index and chip:IsMouseOver() then
        local cfg = Cfg()
        local list = cfg.strips[strip.key]
        local value = table.remove(list, chipDrag.index)
        table.insert(list, i, value)
        chipDrag.index = i
        Apply(cfg)
        return
      end
    end
  end

  local function Chip(strip, stripIndex, i)
    local chip = strip.chips[i]
    if chip then return chip end
    chip = CreateFrame("Button", nil, panel, "BackdropTemplate")
    chip:SetHeight(CONST.ARRANGE_CHIP)
    chip.icon = chip:CreateTexture(nil, "ARTWORK")
    chip.icon:SetPoint("CENTER")
    chip.text = CreateLabel(chip, 11, Theme.textPrimary, true)
    chip.text:SetPoint("CENTER")
    chip:SetScript("OnMouseDown", function(_, button)
      if button ~= "LeftButton" then return end
      chipDrag = { strip = stripIndex, index = i }
      panel:SetScript("OnUpdate", ChipDragUpdate)
      RefreshArrangePanel()
    end)
    chip:SetScript("OnMouseUp", EndChipDrag)
    chip:SetScript("OnEnter", function(self)
      if self.tip then Tooltip(self, self.tip) end
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    strip.chips[i] = chip
    return chip
  end

  local function PaintStrip(stripIndex, key, list)
    local strip = strips[stripIndex]
    strip.key = key
    for i, value in ipairs(list) do
      local chip = Chip(strip, stripIndex, i)
      chip.tip = nil
      local isClass = key == "class"
      chip.icon:SetShown(isClass)
      chip.text:SetShown(not isClass)
      if isClass then
        chip.icon:SetSize(CONST.ARRANGE_CLASS_ICON, CONST.ARRANGE_CLASS_ICON)
        GG.Widgets.SetClassIcon(chip.icon, CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[value])
        chip.tip = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[value]) or value
      elseif key == "role" then
        chip.text:SetText(L[ROLE_LABEL_KEYS[value]] or value)
      else
        chip.text:SetText(value)
      end
      local lifted = chipDrag and chipDrag.strip == stripIndex and chipDrag.index == i
      ApplyBackdrop(chip, lifted and Theme.rowHover or CONST.NAV_BG, lifted and Theme.accent or Theme.border, 1)
      chip.text:SetTextColor(unpack(Theme.textPrimary))
      chip.text:SetWidth(0)
      local fullWidth = chip.text:GetStringWidth()
      local textWidth = math.min(fullWidth, CONST.ARRANGE_CHIP_TEXT_MAX)
      chip.text:SetWidth(textWidth + 1)
      if textWidth < fullWidth then chip.tip = value end
      if isClass then
        chip:SetSize(CONST.ARRANGE_CLASS_ICON + 6, CONST.ARRANGE_CLASS_ICON + 6)
      else
        chip:SetSize(math.max(24, textWidth + 16), CONST.ARRANGE_CHIP)
      end
      chip:Show()
    end
    for i = #list + 1, #strip.chips do strip.chips[i]:Hide() end
    strip.count = #list
  end

  local function HideStrip(stripIndex)
    local strip = strips[stripIndex]
    strip.key = nil
    strip.count = 0
    for _, chip in ipairs(strip.chips) do chip:Hide() end
  end

  local function RowY(row)
    return -(CONST.ARRANGE_TOP + (row - 1) * (CONST.ARRANGE_ROW + CONST.ARRANGE_GAP) + CONST.ARRANGE_ROW / 2)
  end
  local function Flow(items, firstRow, panelWidth)
    local maxWidth = panelWidth - 24
    local lines, line, lineWidth = {}, {}, 0
    for _, item in ipairs(items) do
      local add = (#line > 0 and item.gap or 0) + item.w
      if #line > 0 and lineWidth + add > maxWidth then
        lines[#lines + 1] = line
        line, lineWidth, add = {}, 0, item.w
      end
      line[#line + 1] = item
      lineWidth = lineWidth + add
    end
    if #line > 0 then lines[#lines + 1] = line end
    for n, l in ipairs(lines) do
      local total = 0
      for i, item in ipairs(l) do total = total + item.w + (i > 1 and item.gap or 0) end
      local x = math.max(12, (panelWidth - total) / 2)
      for i, item in ipairs(l) do
        if i > 1 then x = x + item.gap end
        item.f:ClearAllPoints()
        item.f:SetPoint("LEFT", panel, "TOPLEFT", x, RowY(firstRow + n - 1))
        x = x + item.w
      end
    end
    return #lines
  end

  RefreshArrangePanel = function()
    local cfg = Cfg()
    local by = ShownBy(cfg)
    local grouped = A.IsGroup(by)
    local panelWidth = panel:GetWidth()
    if not panelWidth or panelWidth <= 0 then panelWidth = CONST.MIN_WINDOW_WIDTH end

    PaintToken(byToken)
    mid:SetShown(grouped)
    insideToken:SetShown(grouped)
    if grouped then
      mid:SetText(L["ARRANGE_SENTENCE_INSIDE"]:format(L[ARRANGE_NOUN_KEYS[by]]))
      PaintToken(insideToken)
    end
    local dirKey = DirKey(cfg)
    dirToken:SetShown(dirKey ~= nil)
    if dirKey then PaintToken(dirToken) end
    local entry = state.arrangeEntry
    restore:SetDisabled(not entry
      or (DeepEqual(entry.arrange, cfg) and DeepEqual(entry.order, GGDB.options.customOrder or {})))

    local sentence = {
      { f = lead, w = lead:GetStringWidth(), gap = 0 },
      { f = byToken, w = byToken:GetWidth(), gap = 8 },
    }
    if grouped then
      sentence[#sentence + 1] = { f = mid, w = mid:GetStringWidth(), gap = 8 }
      sentence[#sentence + 1] = { f = insideToken, w = insideToken:GetWidth(), gap = 8 }
    end
    if dirKey then sentence[#sentence + 1] = { f = dirToken, w = dirToken:GetWidth(), gap = 6 } end
    local rows = Flow(sentence, 1, panelWidth)

    local noteText, showGrip
    if by == "free" then
      noteText, showGrip = L["ARRANGE_HINT_FREE"], true
    elseif by == "roster" then
      noteText, showGrip = L["ARRANGE_HINT_ROSTER"], true
    elseif A.IsValue(by) then
      noteText = L["ARRANGE_HINT_AUTO"]
    else
      noteText, showGrip = L["ARRANGE_DRAG_HINT"], true
    end
    note:SetText(noteText)
    grip:SetShown(showGrip == true)

    local stripKeys = {}
    if grouped then stripKeys[#stripKeys + 1] = by end
    if grouped and A.IsGroup(cfg.inside) then stripKeys[#stripKeys + 1] = cfg.inside end
    for i = 1, 2 do
      if stripKeys[i] then PaintStrip(i, stripKeys[i], cfg.strips[stripKeys[i]]) else HideStrip(i) end
    end
    local below = {}
    for n = 1, #stripKeys do
      local strip = strips[n]
      for i = 1, strip.count do
        below[#below + 1] = { f = strip.chips[i], w = strip.chips[i]:GetWidth(), gap = (i == 1 and n > 1) and 18 or 4 }
      end
    end
    if showGrip then below[#below + 1] = { f = grip, w = 8, gap = #below > 0 and 14 or 0 } end
    below[#below + 1] = { f = note, w = note:GetStringWidth(), gap = showGrip and 6 or (#below > 0 and 14 or 0) }
    rows = rows + Flow(below, rows + 1, panelWidth)

    PaintDone(done:IsMouseOver())
    rows = rows + Flow({
      { f = restore, w = restore:GetWidth(), gap = 0 },
      { f = done, w = done:GetWidth(), gap = 10 },
    }, rows + 1, panelWidth)

    local height = CONST.ARRANGE_TOP + rows * (CONST.ARRANGE_ROW + CONST.ARRANGE_GAP) + 4
    state.arrangeExtra = math.max(0, height - CONST.RAIL_HEIGHT)
  end

  return panel
end

local function BuildFrame()
  Theme = GG.Theme

  if (GGDB.options.customOrder and #GGDB.options.customOrder > 0) or ArrangeConfig().by ~= "free" then
    state.sortKey = "custom"
  end

  frame = CreateFrame("Frame", "GGRosterWindow", UIParent, "BackdropTemplate")
  frame:SetMovable(true)
  frame:SetResizable(false)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  GG.RosterUI:ApplyEscBehavior()

  local saved = GGDB.options and GGDB.options.rosterWindow
  if saved and saved.point then
    frame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
  else
    frame:SetPoint("CENTER")
  end
  frame:SetSize((saved and saved.width) or CONST.DEFAULT_WIDTH, (saved and saved.height) or CONST.DEFAULT_HEIGHT)

  local framePanel = GG.Widgets.ApplyPanel(frame, {
    bg = Theme.background,
    corners = "all",
    logo = true,
  })
  opacityPanels = { { panel = framePanel } }

  local accentBar = frame:CreateTexture(nil, "ARTWORK")
  accentBar:SetColorTexture(unpack(Theme.accent))
  accentBar:SetPoint("TOPLEFT")
  accentBar:SetPoint("TOPRIGHT")
  accentBar:SetHeight(2)

  frame:SetScript("OnDragStart", function()
    if GGDB.options and GGDB.options.lockWindow then return end
    frame:StartMoving()
  end)
  frame:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SaveWindowState()
  end)

  frame:SetScript("OnHide", function()
    if state.dragEditMode then
      state.dragEditMode = false
      UpdateHeaderArrows()
    end
    if GGDB.options then GGDB.options.lastTab = state.filterTab end
    if state.filterTab ~= "all" or state.accountFilter then
      state.accountFilter = nil
      SetFilterTab("all")
    end
    if GG.RosterUI.CloseCharactersFlyout then GG.RosterUI:CloseCharactersFlyout() end
  end)

  local titlebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  titlebar:SetPoint("TOPLEFT", 0, -2)
  titlebar:SetPoint("TOPRIGHT", 0, -2)
  titlebar:SetHeight(CONST.TITLEBAR_HEIGHT)
  local titlebarPanel = GG.Widgets.ApplyPanel(titlebar, { bg = Theme.panel, corners = "top" })
  table.insert(opacityPanels, { panel = titlebarPanel })

  local mark = titlebar:CreateTexture(nil, "ARTWORK")
  mark:SetSize(20, 20)
  mark:SetPoint("LEFT", 10, 0)
  mark:SetTexture(Theme.media.logoIcon)
  mark:SetVertexColor(unpack(Theme.accent))

  local subtitleText = CreateLabel(titlebar, 11, Theme.textPrimary, true)
  subtitleText:SetText(L["ROSTER_SUBTITLE"])
  subtitleText:SetPoint("LEFT", mark, "RIGHT", 8, 0)

  local closeBtn = CreateFrame("Button", nil, titlebar)
  closeBtn:SetSize(20, 20)
  closeBtn:SetPoint("RIGHT", -10, 0)
  local closeLabel = CreateLabel(closeBtn, 15, Theme.textMuted)
  closeLabel:SetPoint("CENTER")
  closeLabel:SetText("x")
  closeBtn:SetScript("OnEnter", function() closeLabel:SetTextColor(unpack(Theme.textPrimary)) end)
  closeBtn:SetScript("OnLeave", function() closeLabel:SetTextColor(unpack(Theme.textMuted)) end)
  closeBtn:SetScript("OnClick", function() frame:Hide() end)

  settingsBtn = CreateFrame("Button", nil, titlebar)
  settingsBtn:SetSize(18, 18)
  settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
  local gearIcon = settingsBtn:CreateTexture(nil, "ARTWORK")
  gearIcon:SetAllPoints()
  gearIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
  settingsBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["SETTINGS_TOOLTIP"])
    GameTooltip:Show()
  end)
  settingsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  settingsBtn:SetAlpha(0)
  settingsBtn:EnableMouse(false)
  settingsBtn:SetWidth(1)

  layoutBtn = CreateFrame("Button", nil, titlebar, "BackdropTemplate")
  layoutBtn:SetSize(22, 22)
  layoutBtn:EnableMouse(true)
  layoutBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -6, 0)
  ApplyBackdrop(layoutBtn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, 1)
  local layoutIcon = layoutBtn:CreateTexture(nil, "ARTWORK")
  layoutIcon:SetSize(16, 16)
  layoutIcon:SetPoint("CENTER", layoutBtn, "CENTER", 0, 0)

  local LAYOUT_COLOR_NORMAL = { 0.55, 0.52, 0.63 }
  local LAYOUT_COLOR_HOVER = { 0.76, 0.61, 0.94 }
  local LAYOUT_COLOR_PUSHED = { 0.88, 0.80, 0.97 }
  local LAYOUT_BG_HOVER = { 0.165, 0.125, 0.251, 1 }
  local LAYOUT_BORDER_HOVER = { 0.427, 0.294, 0.690, 1 }
  local LAYOUT_BG_PUSHED = { 0.227, 0.165, 0.345, 1 }
  local LAYOUT_BORDER_PUSHED = { 0.541, 0.388, 0.824, 1 }
  local LAYOUT_TRANSPARENT = { 0, 0, 0, 0 }

  local function PaintLayoutButton(state)
    if state == "hover" then
      layoutIcon:SetVertexColor(unpack(LAYOUT_COLOR_HOVER))
      layoutBtn:SetBackdropColor(unpack(LAYOUT_BG_HOVER))
      layoutBtn:SetBackdropBorderColor(unpack(LAYOUT_BORDER_HOVER))
    elseif state == "pushed" then
      layoutIcon:SetVertexColor(unpack(LAYOUT_COLOR_PUSHED))
      layoutBtn:SetBackdropColor(unpack(LAYOUT_BG_PUSHED))
      layoutBtn:SetBackdropBorderColor(unpack(LAYOUT_BORDER_PUSHED))
    else
      layoutIcon:SetVertexColor(unpack(LAYOUT_COLOR_NORMAL))
      layoutBtn:SetBackdropColor(unpack(LAYOUT_TRANSPARENT))
      layoutBtn:SetBackdropBorderColor(unpack(LAYOUT_TRANSPARENT))
    end
  end

  function RefreshLayoutButton()
    if state.layoutSeg then state.layoutSeg:Paint(IsVertical() and "cols" or "rows") end
    if not layoutBtn then return end
    local goingToVertical = not IsVertical()
    layoutIcon:SetTexture(goingToVertical
      and "Interface\\AddOns\\GG\\Media\\ViewVertical64.tga"
      or "Interface\\AddOns\\GG\\Media\\ViewHorizontal64.tga")
    layoutBtn.tooltipTitle = goingToVertical and L["LAYOUT_TO_VERTICAL"] or L["LAYOUT_TO_HORIZONTAL"]
    PaintLayoutButton(layoutBtn:IsMouseOver() and "hover" or "normal")
    if GameTooltip:IsOwned(layoutBtn) then
      GameTooltip:SetOwner(layoutBtn, "ANCHOR_BOTTOMLEFT")
      GameTooltip:AddLine(layoutBtn.tooltipTitle)
      GameTooltip:AddLine(L["LAYOUT_TOGGLE_HINT"], unpack(Theme.textMuted))
      GameTooltip:Show()
    end
  end

  layoutBtn:SetScript("OnEnter", function(self)
    PaintLayoutButton("hover")
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    GameTooltip:AddLine(self.tooltipTitle or "")
    GameTooltip:AddLine(L["LAYOUT_TOGGLE_HINT"], unpack(Theme.textMuted))
    GameTooltip:Show()
  end)
  layoutBtn:SetScript("OnLeave", function()
    PaintLayoutButton("normal")
    GameTooltip:Hide()
  end)
  layoutBtn:SetScript("OnMouseDown", function() PaintLayoutButton("pushed") end)
  layoutBtn:SetScript("OnMouseUp", function(self)
    PaintLayoutButton(self:IsMouseOver() and "hover" or "normal")
  end)
  layoutBtn:SetScript("OnClick", function() GG.RosterUI:ToggleLayoutMode() end)
  RefreshLayoutButton()

  versionText = CreateLabel(titlebar, 10, Theme.textFaint)
  layoutBtn:Hide()
  versionText:SetPoint("RIGHT", GG.AccountSync:CreateSyncButton(titlebar, settingsBtn), "LEFT", -8, 0)
  local versionHitbox = CreateFrame("Frame", nil, titlebar)
  versionHitbox:SetAllPoints(versionText)
  versionHitbox:SetScript("OnEnter", function(self)
    GG.Tip:Open(self, { family = "ui", anchor = "TOP" }, function(t)
      if GG:CompareVersions(GG.latestKnownVersion, GG.VERSION) > 0 then
        t:Title(L["TIP_NEW_VERSION"], Theme.success)
        t:Text(L["VERSION_TOOLTIP_UPDATE_AVAILABLE"]:format(GG.VERSION, GG.Tip.Paint(GG.latestKnownVersion, Theme.success)))
      else
        t:Text(L["VERSION_TOOLTIP_CURRENT"]:format(GG.VERSION))
      end
    end)
  end)
  versionHitbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
  GG.RosterUI:RefreshVersionBadge()

  versionBanner = CreateFrame("Frame", nil, frame)
  versionBanner:SetAllPoints(frame)
  versionBanner:EnableMouse(true)
  versionBanner:SetFrameLevel(frame:GetFrameLevel() + 90)
  local versionBannerTex = versionBanner:CreateTexture(nil, "OVERLAY")
  versionBannerTex:SetAllPoints()
  versionBannerTex:SetColorTexture(0, 0, 0, 0.82)

  local versionCard = CreateFrame("Frame", nil, versionBanner, "BackdropTemplate")
  versionCard:SetSize(320, 220)
  versionCard:SetPoint("CENTER")
  GG.Widgets.ApplyPanel(versionCard, { bg = Theme.background, corners = "all", glow = true })

  local versionCardIcon = versionCard:CreateTexture(nil, "ARTWORK")
  versionCardIcon:SetSize(36, 36)
  versionCardIcon:SetPoint("TOP", 0, -22)
  versionCardIcon:SetTexture(Theme.media.logoIcon)
  versionCardIcon:SetVertexColor(unpack(Theme.accent))

  local versionCardTitle = CreateLabel(versionCard, 15, Theme.textPrimary, true)
  versionCardTitle:SetPoint("TOP", versionCardIcon, "BOTTOM", 0, -12)
  versionCardTitle:SetText(L["VERSION_BANNER_TITLE"])

  local versionCardBody = CreateLabel(versionCard, 12, Theme.textMuted)
  versionCardBody:SetJustifyH("CENTER")
  versionCardBody:SetWidth(268)
  versionCardBody:SetWordWrap(true)
  versionCardBody:SetPoint("TOP", versionCardTitle, "BOTTOM", 0, -10)

  local versionCardDismiss = GG.Widgets.CreateButton(versionCard, L["VERSION_BANNER_DISMISS"], function()
    versionBanner:Hide()
  end)
  versionCardDismiss:SetPoint("BOTTOM", 0, 18)

  versionBanner.body = versionCardBody
  versionBanner:Hide()

  CreateDimOverlay(titlebar)

  rail = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  rail:SetPoint("TOPLEFT", titlebar, "BOTTOMLEFT", 0, 0)
  rail:SetPoint("TOPRIGHT", titlebar, "BOTTOMRIGHT", 0, 0)
  rail:SetHeight(CONST.RAIL_HEIGHT)
  ApplyBackdrop(rail, CONST.NAV_BG, Theme.border, 1)
  table.insert(opacityPanels, { f = rail, color = CONST.NAV_BG })
  BuildContextBar()

  BuildNavTabs()
  state.rail = rail

  customOrderBtn = CreateFrame("Button", nil, state.ctxBar, "BackdropTemplate")
  customOrderBtn:SetHeight(24)
  customOrderBtn.icon = customOrderBtn:CreateTexture(nil, "ARTWORK")
  customOrderBtn.icon:SetSize(14, 14)
  customOrderBtn.icon:SetPoint("LEFT", 10, 0)
  customOrderBtn.icon:SetTexture("Interface\\AddOns\\GG\\Media\\Reorder64.tga")
  customOrderBtn.label = CreateLabel(customOrderBtn, 11.5, Theme.textPrimary, true)
  customOrderBtn.label:SetPoint("LEFT", customOrderBtn.icon, "RIGHT", 6, 0)
  customOrderBtn.label:SetText(SortedByText())
  ApplyBackdrop(customOrderBtn, { Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.16 }, Theme.accent, 1)
  customOrderBtn:SetScript("OnEnter", function(self)
    if not state.dragEditMode then
      self:SetBackdropColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.32)
    end
    GG.Tip:Open(self, { family = "ui", anchor = "TOP" }, function(t) t:Text(L["ROSTER_CUSTOM_ORDER_TOOLTIP"]) end)
  end)
  customOrderBtn:SetScript("OnLeave", function(self)
    if not state.dragEditMode then
      self:SetBackdropColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.16)
    end
    GameTooltip:Hide()
  end)
  customOrderBtn:SetScript("OnClick", function()
    if state.dragEditMode then
      state.dragEditMode = false
    else
      EnsureCustomOrderComplete()
      state.accountFilter = nil
      SetFilterTab("all")
      state.search = ""
      if searchBox then
        searchBox:SetText("")
        searchBox.placeholder:SetShown(true)
      end
      state.sortKey = "custom"
      state.sortAsc = true
      state.dragEditMode = true
    end
    scrollOffset = 0
    vaultScrollOffsetPx = 0
    RebuildDataRows()
    if state.dragEditMode then
      state.arrangeEntry = {
        arrange = CopyTable(state.arrangeCfg or ArrangeConfig()),
        order = CopyTable(GGDB.options.customOrder or {}),
      }
    end
    UpdateHeaderArrows()
    C_Timer.After(0, function()
      if state.dragEditMode then UpdateHeaderArrows() end
    end)
  end)

  searchBox = CreateFrame("EditBox", nil, state.ctxBar, "BackdropTemplate")
  searchBox:SetSize(190, 24)
  searchBox:SetAutoFocus(false)
  searchBox:SetFontObject("ChatFontNormal")
  searchBox:SetFont(Theme.font, 11, "")
  searchBox:SetTextColor(unpack(Theme.textPrimary))
  ApplyBackdrop(searchBox, { 1, 1, 1, 0.03 }, Theme.borderSoft)
  searchBox:SetTextInsets(7, 7, 0, 0)
  searchBox.placeholder = CreateLabel(searchBox, 11, Theme.textFaint)
  searchBox.placeholder:SetPoint("LEFT", 7, 0)
  searchBox.placeholder:SetText(L["ROSTER_SEARCH_PLACEHOLDER"])
  searchBox:SetScript("OnTextChanged", function(self)
    local text = self:GetText()
    self.placeholder:SetShown(text == "")
    state.search = text
    scrollOffset = 0
    vaultScrollOffsetPx = 0
    RebuildDataRows()
  end)
  searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  LayoutActionRail()

  C_Timer.After(0, LayoutActionRail)
  C_Timer.After(0.5, LayoutActionRail)

  charactersBtn = CreateFrame("Button", nil, state.ctxBar, "BackdropTemplate")
  charactersBtn:SetPoint("RIGHT", -10, 0)
  charactersBtn:SetHeight(24)
  ApplyBackdrop(charactersBtn, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, 1)

  charactersBtn.icon = charactersBtn:CreateTexture(nil, "ARTWORK")
  charactersBtn.icon:SetSize(13, 13)
  charactersBtn.icon:SetTexture("Interface\\AddOns\\GG\\Media\\Characters64.tga")
  charactersBtn.icon:SetPoint("LEFT", 6, 0)

  countLabel = CreateMonoLabel(charactersBtn, 10.5, Theme.textDim or Theme.textMuted)
  countLabel:SetPoint("LEFT", charactersBtn.icon, "RIGHT", 5, 0)

  function charactersBtn:Sync(hovering)
    self.hiddenCount = GG:CountHiddenCharacters()
    self:SetWidth(countLabel:GetStringWidth() + 30)
    if hovering == nil then hovering = self:IsMouseOver() end
    if hovering then
      self.icon:SetVertexColor(unpack(Theme.accent))
      self:SetBackdropColor(0.165, 0.125, 0.251, 1)
      self:SetBackdropBorderColor(0.427, 0.294, 0.690, 1)
    else
      if self.hiddenCount > 0 then
        self.icon:SetVertexColor(unpack(Theme.accent))
      else
        self.icon:SetVertexColor(0.55, 0.52, 0.63)
      end
      self:SetBackdropColor(0, 0, 0, 0)
      self:SetBackdropBorderColor(0, 0, 0, 0)
    end
  end

  charactersBtn:SetScript("OnEnter", function(self)
    self:Sync(true)
    local hiddenCount = self.hiddenCount or 0
    GG.Tip:Open(self, { family = "ui", anchor = "TOP" }, function(t)
      t:Title(L["ROSTER_CHARACTERS_TITLE"])
      t:Text(L["ROSTER_CHARACTERS_TOOLTIP"])
      if syncLabel and syncLabel:GetText() then t:Text(syncLabel:GetText(), Theme.textFaint, true) end
      if hiddenCount > 0 then t:Text("*" .. L["ROSTER_HIDDEN_COUNT"]:format(hiddenCount) .. "*", nil, true) end
    end)
  end)
  charactersBtn:SetScript("OnLeave", function(self)
    self:Sync(false)
    GameTooltip:Hide()
  end)
  charactersBtn:SetScript("OnClick", function(self)
    GG.RosterUI:ToggleCharactersFlyout(self)
  end)

  syncLabel = CreateMonoLabel(rail, 10.5, Theme.textFaint)
  syncLabel:SetPoint("RIGHT", charactersBtn, "LEFT", -10, 0)
  local syncHitbox = CreateFrame("Frame", nil, rail)
  syncHitbox:SetAllPoints(syncLabel)
  syncHitbox:EnableMouse(true)
  syncHitbox:SetScript("OnEnter", function(self)
    GG.Tip:Open(self, { family = "ui", anchor = "TOP" }, function(t) t:Text(L["ROSTER_SYNC_TOOLTIP"]) end)
  end)
  syncHitbox:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local railOverlay = CreateDimOverlay(rail)
  local railCover = railOverlay:CreateTexture(nil, "BACKGROUND")
  railCover:SetAllPoints()
  railCover:SetColorTexture(CONST.NAV_BG[1], CONST.NAV_BG[2], CONST.NAV_BG[3], 1)
  local bannerLock = railOverlay:CreateTexture(nil, "OVERLAY")
  bannerLock:SetAtlas("groupfinder-icon-lock", true)
  local ICON_GAP = 8
  local bannerText = CreateLabel(railOverlay, 16, Theme.accent)
  bannerText:SetText(L["ROSTER_EDIT_POSITION_BANNER"])
  local pairWidth = bannerLock:GetWidth() + ICON_GAP + bannerText:GetStringWidth()
  bannerLock:SetPoint("LEFT", railOverlay, "TOP", -pairWidth / 2, -17)
  bannerText:SetPoint("LEFT", bannerLock, "RIGHT", ICON_GAP, 0)
  editBanner = railOverlay
  BuildArrangePanel(railOverlay)

  state.ctxOverlay = CreateDimOverlay(state.ctxBar)
  customOrderBtn:SetFrameLevel(state.ctxOverlay:GetFrameLevel() + 1)

  header.row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  header.row:SetPoint("TOPLEFT", state.ctxBar, "BOTTOMLEFT", 0, 0)
  header.row:SetPoint("TOPRIGHT", state.ctxBar, "BOTTOMRIGHT", 0, 0)
  header.row:SetHeight(CONST.HEADER_HEIGHT)
  ApplyBackdrop(header.row, Theme.panel, Theme.border, 1)
  table.insert(opacityPanels, { f = header.row, color = Theme.panel })

  for _, col in ipairs(CONST.COLUMNS) do
    local cell = header.row:CreateFontString(nil, "OVERLAY")
    cell:SetFont(Theme.fontBold, V.SMALL_SIZE, "")
    cell:SetTextColor(unpack(Theme.textFaint))
    cell:SetText(L[col.labelKey])
    cell:SetPoint("LEFT", header.row, "LEFT", CONST.CELL_PADDING, 0)
    if col.sortable then
      local hitbox = CreateFrame("Button", nil, header.row)
      hitbox:SetAllPoints(cell)
      hitbox:SetHitRectInsets(-4, -20, -4, -4)
      hitbox:SetScript("OnClick", function() SetSort(col.key) end)
      header.hitboxes[col.key] = hitbox
    end
    header.cells[col.key] = cell
  end

  CreateDimOverlay(header.row)

  sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  ApplyBackdrop(sidebar, CONST.NAV_BG, Theme.border, 1)
  table.insert(opacityPanels, { f = sidebar, color = CONST.NAV_BG })
  sidebar:Hide()
  CreateDimOverlay(sidebar)

  scrollClip = CreateFrame("Frame", nil, frame)
  scrollClip:SetPoint("TOPLEFT", header.row, "BOTTOMLEFT", 0, 0)
  scrollClip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONST.SCROLLBAR_WIDTH - 4, CONST.FOOTER_HEIGHT)
  scrollClip:SetClipsChildren(true)
  scrollClip:EnableMouseWheel(true)
  if GG.RaidTab then GG.RaidTab:Attach(scrollClip) end
  if GG.BonusRollTab then GG.BonusRollTab:Attach(scrollClip) end
  if GG.RaidRostersTab then GG.RaidRostersTab:Attach(scrollClip) end
  scrollClip:SetScript("OnMouseWheel", function(_, delta)
    if state.filterTab == "vaultPending" then
      vaultScrollOffsetPx = vaultScrollOffsetPx - delta * 40
      UpdateVaultCards(false)
    else
      scrollOffset = scrollOffset - delta * (IsVertical() and 1 or 3)
      UpdateVisibleRows()
    end
  end)

  editModeBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  editModeBorder:SetAllPoints(scrollClip)
  ApplyBackdrop(editModeBorder, { 0, 0, 0, 0 }, Theme.accent, 3)
  editModeBorder:Hide()

  local halo = CreateFrame("Frame", nil, frame)
  halo:SetFrameLevel(scrollClip:GetFrameLevel() + 30)
  local haloTop = halo:CreateTexture(nil, "OVERLAY")
  haloTop:SetHeight(1)
  haloTop:SetPoint("TOPLEFT")
  haloTop:SetPoint("TOPRIGHT")
  local haloLeft = halo:CreateTexture(nil, "OVERLAY")
  haloLeft:SetWidth(1)
  haloLeft:SetPoint("TOPLEFT")
  local haloRight = halo:CreateTexture(nil, "OVERLAY")
  haloRight:SetWidth(1)
  haloRight:SetPoint("TOPRIGHT")
  local haloGlow = halo:CreateTexture(nil, "BACKGROUND")
  haloGlow:SetHeight(70)
  haloGlow:SetPoint("TOPLEFT")
  haloGlow:SetPoint("TOPRIGHT")
  halo:SetScript("OnSizeChanged", function(self, _, height)
    haloLeft:SetHeight(math.max(1, height * 0.7))
    haloRight:SetHeight(math.max(1, height * 0.7))
  end)
  local stems = CreateFrame("Frame", nil, frame)
  stems:SetAllPoints(frame)
  stems:SetFrameLevel(customOrderBtn:GetFrameLevel() + 60)
  local restStem = stems:CreateTexture(nil, "OVERLAY")
  local editStem = stems:CreateTexture(nil, "OVERLAY")
  local function Thin(region, horizontal, size)
    if PixelUtil then
      if horizontal then PixelUtil.SetHeight(region, size, size) else PixelUtil.SetWidth(region, size, size) end
    elseif horizontal then
      region:SetHeight(size)
    else
      region:SetWidth(size)
    end
  end
  Thin(haloTop, true, 1)
  Thin(haloLeft, false, 1)
  Thin(haloRight, false, 1)
  Thin(restStem, false, 1)
  Thin(editStem, false, 2)

  UpdateSortHalo = function()
    local onCharacters = state.filterTab == "all" and not settingsOpen
      and customOrderBtn and customOrderBtn:IsShown()
    local centered = state.sortCentered
    local editing = state.dragEditMode
    local a = Theme.accent
    local r, g, b = a[1], a[2], a[3]

    halo:ClearAllPoints()
    halo:SetPoint("TOPLEFT", state.ctxBar, "BOTTOMLEFT", 4, -2)
    halo:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4,
      CONST.FOOTER_HEIGHT + (IsVertical() and V.HSCROLL_HEIGHT or 0))
    halo:SetShown(onCharacters and centered and not editing)
    haloTop:SetColorTexture(r, g, b, 0.75)
    for _, side in ipairs({ haloLeft, haloRight }) do
      side:SetColorTexture(1, 1, 1, 1)
      side:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.75))
    end
    haloGlow:SetColorTexture(1, 1, 1, 1)
    haloGlow:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.10))

    local toCtxBottom = (CONST.CTX_HEIGHT - customOrderBtn:GetHeight()) / 2
    restStem:ClearAllPoints()
    restStem:SetPoint("TOP", customOrderBtn, "BOTTOM", 0, 0)
    restStem:SetHeight(toCtxBottom + 2)
    restStem:SetColorTexture(r, g, b, 0.75)
    restStem:SetShown(onCharacters and centered and not editing)

    editStem:ClearAllPoints()
    editStem:SetPoint("TOP", customOrderBtn, "BOTTOM", 0, 0)
    editStem:SetHeight(toCtxBottom + (IsVertical() and 0 or CONST.HEADER_HEIGHT))
    editStem:SetColorTexture(r, g, b, 1)
    editStem:SetShown(onCharacters and centered and editing == true)
  end

  scrollbar = CreateFrame("Slider", "GGRosterScrollBar", frame, "UIPanelScrollBarTemplate")
  scrollbar:SetPoint("TOPLEFT", scrollClip, "TOPRIGHT", 4, -16)
  scrollbar:SetPoint("BOTTOMLEFT", scrollClip, "BOTTOMRIGHT", 4, 16)
  scrollbar:SetScript("OnValueChanged", function(_, value)
    local newOffset = math.floor(value + 0.5)
    if state.filterTab == "vaultPending" then
      if newOffset == vaultScrollOffsetPx then return end
      vaultScrollOffsetPx = newOffset
      UpdateVaultCards(false)
    else
      if newOffset == scrollOffset then return end
      scrollOffset = newOffset
      UpdateVisibleRows()
    end
  end)
  scrollbar:SetMinMaxValues(0, 0)
  scrollbar:SetValueStep(1)
  scrollbar:SetValue(0)
  GG.Widgets.SkinScrollbar(scrollbar)

  hscrollbar = CreateFrame("Slider", "GGRosterHScrollBar", frame)
  hscrollbar:SetOrientation("HORIZONTAL")
  hscrollbar:SetHeight(V.HSCROLL_HEIGHT)
  hscrollbar:SetPoint("BOTTOMLEFT", scrollClip, "BOTTOMLEFT", 0, -V.HSCROLL_HEIGHT)
  hscrollbar:SetPoint("BOTTOMRIGHT", scrollClip, "BOTTOMRIGHT", 0, -V.HSCROLL_HEIGHT)
  hscrollbar:SetMinMaxValues(0, 0)
  hscrollbar:SetValueStep(1)
  hscrollbar:SetObeyStepOnDrag(true)
  hscrollbar:SetValue(0)
  hscrollbar:SetScript("OnValueChanged", function(_, value)
    local newOffset = math.floor(value + 0.5)
    if newOffset == scrollOffset then return end
    scrollOffset = newOffset
    UpdateVisibleRows()
  end)
  hscrollbar:Hide()
  GG.Widgets.SkinScrollbar(hscrollbar)

  vaultCardContainer = CreateFrame("Frame", nil, scrollClip)
  vaultCardContainer:SetPoint("TOPLEFT", scrollClip, "TOPLEFT", 0, 0)

  local footer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  footer:SetPoint("BOTTOMLEFT", 0, 2)
  footer:SetPoint("BOTTOMRIGHT", 0, 2)
  footer:SetHeight(CONST.FOOTER_HEIGHT)
  local footerPanel = GG.Widgets.ApplyPanel(footer, { bg = Theme.panel, corners = "bottom" })
  table.insert(opacityPanels, { panel = footerPanel })

  local legendDefs = {
    { colorKey = "purple", labelKey = "ROSTER_LEGEND_RAID" },
    { colorKey = "teal", labelKey = "ROSTER_LEGEND_MPLUS" },
    { colorKey = "gold", labelKey = "ROSTER_LEGEND_WORLD" },
  }
  local prevLegend
  state.footerLegend = {}
  for _, def in ipairs(legendDefs) do
    local dot = footer:CreateTexture(nil, "ARTWORK")
    dot:SetSize(6, 6)
    if prevLegend then
      dot:SetPoint("LEFT", prevLegend, "RIGHT", 12, 0)
    else
      dot:SetPoint("LEFT", 12, 0)
    end
    dot:SetColorTexture(unpack(Theme[def.colorKey]))
    local text = CreateMonoLabel(footer, 9.5, Theme.textFaint)
    text:SetPoint("LEFT", dot, "RIGHT", 4, 0)
    text:SetText(L[def.labelKey])
    prevLegend = text
    table.insert(state.footerLegend, { dot = dot, text = text })
  end

  local hintText = CreateMonoLabel(footer, 9.5, Theme.textFaint)
  state.footerHint = hintText
  hintText:SetText(L["ROSTER_FOOTER_HINT"])
  hintText:SetPoint("RIGHT", -12, 0)

  CreateDimOverlay(footer)

  frame:SetScript("OnSizeChanged", function()
    if resizeRelayoutPending then return end
    resizeRelayoutPending = true
    C_Timer.After(0.05, function()
      resizeRelayoutPending = false
      if frame and frame:IsShown() then Relayout() end
    end)
  end)

  local function CloseSettingsView()
    if not settingsOpen then return end
    settingsOpen = false
    PaintNavTabs()
    GG.UI:HideSettingsPanel()
    gearIcon:SetVertexColor(1, 1, 1)
    subtitleText:SetText(L["ROSTER_SUBTITLE"])
    rail:Show()
    scrollClip:Show()
    footer:Show()
    Relayout()
    SetFilterTab("all")
  end

  local function OpenSettingsView()
    if settingsOpen then return end
    settingsOpen = true
    PaintNavTabs()
    AutoSizeWindow()
    if state.ctxBar then state.ctxBar:Hide() end
    if syncLabel then syncLabel:Hide() end
    for _, icon in ipairs(state.syncIcons or {}) do icon:Hide() end
    header.row:Hide()
    scrollClip:Hide()
    scrollbar:Hide()
    if hscrollbar then hscrollbar:Hide() end
    if sidebar then sidebar:Hide() end
    footer:Hide()
    gearIcon:SetVertexColor(unpack(Theme.accent))
    subtitleText:SetText(L["OPTIONS_TITLE"])
    GG.UI:ShowSettingsPanel(frame, rail)
  end

  settingsBtn:SetScript("OnClick", function()
    if settingsOpen then CloseSettingsView() else OpenSettingsView() end
  end)

  frame:HookScript("OnHide", CloseSettingsView)

  UpdateHeaderArrows()
  frame:Hide()
  return frame
end

function GG.RosterUI:Toggle()
  if not frame then
    BuildFrame()
  end

  if frame:IsShown() then
    frame:Hide()
  else
    frame:SetScale((GGDB.options and GGDB.options.windowScale) or 1.0)
    GG.RosterUI:ApplyOpacity((GGDB.options and GGDB.options.windowOpacity) or 1.0)
    GG.RosterUI:ApplyLayoutMode()
    scrollOffset = 0
    vaultScrollOffsetPx = 0
    RebuildDataRows()
    frame:Show()
    local o = GGDB.options
    if o and o.openOn == "last" and o.lastTab and o.lastTab ~= "all" then
      GG.RosterUI:SelectTab(o.lastTab)
    end
    GG.RosterUI:MaybeShowVersionBanner()
  end
end

function GG.RosterUI:OpenSettings()
  if not frame then BuildFrame() end
  if not frame:IsShown() then GG.RosterUI:Toggle() end
  if settingsBtn and not (GG.UI and GG.UI:IsSettingsPanelShown()) then
    settingsBtn:Click()
  end
end

function GG.RosterUI:Refresh()
  if frame and frame:IsShown() then
    RebuildDataRows()
    if state.filterTab == "bonusRoll" and GG.BonusRollTab then GG.BonusRollTab:Refresh() end
    if state.filterTab == "rosters" and GG.RaidRostersTab then GG.RaidRostersTab:Refresh() end
  end
end

function GG.RosterUI:RefreshGroupLockouts()
  if not (frame and frame:IsShown()) then return end
  if state.filterTab ~= "raid" then return end
  if GG.RaidTab then GG.RaidTab:Refresh() end
end

function GG.RosterUI:RefreshVersionBadge()
  if not versionText then return end
  versionText:SetText(L["VERSION_LABEL"]:format(GG.VERSION))
  if GG:CompareVersions(GG.latestKnownVersion, GG.VERSION) > 0 then
    versionText:SetTextColor(unpack(Theme.accent))
  else
    versionText:SetTextColor(unpack(Theme.textFaint))
  end
end

CONST.VERSION_BANNER_THROTTLE_SECONDS = 24 * 60 * 60

function GG.RosterUI:MaybeShowVersionBanner()
  if not versionBanner or not frame or not frame:IsShown() then return end
  if GG:CompareVersions(GG.latestKnownVersion, GG.VERSION) <= 0 then return end

  local now = time()
  local lastShownAt = GGDB.versionBannerLastShownAt
  local lastShownFor = GGDB.versionBannerLastShownFor
  local isNewerThanLastShown = not lastShownFor or GG:CompareVersions(GG.latestKnownVersion, lastShownFor) > 0
  local dayPassed = not lastShownAt or (now - lastShownAt) >= CONST.VERSION_BANNER_THROTTLE_SECONDS
  if not (isNewerThanLastShown or dayPassed) then return end

  GGDB.versionBannerLastShownAt = now
  GGDB.versionBannerLastShownFor = GG.latestKnownVersion

  versionBanner.body:SetText(L["VERSION_BANNER_BODY"]:format(
    GG:ColorizeText(GG.VERSION, GG.Theme.danger),
    GG:ColorizeText(GG.latestKnownVersion, GG.Theme.success)
  ))
  versionBanner:Show()
end

local charactersFlyout

function GG.RosterUI:CloseCharactersFlyout()
  if charactersFlyout then charactersFlyout:Hide() end
end

function GG.RosterUI:ToggleCharactersFlyout(anchor)
  local ROW_H, HEADER_H, PAD, WIDTH = 24, 20, 12, 300

  if charactersFlyout and charactersFlyout:IsShown() then
    charactersFlyout:Hide()
    return
  end

  if not charactersFlyout then
    charactersFlyout = CreateFrame("Frame", "GGCharactersFlyout", UIParent, "BackdropTemplate")
    charactersFlyout:SetFrameStrata("FULLSCREEN_DIALOG")
    charactersFlyout:SetToplevel(true)
    GG.Widgets.StyleMenu(charactersFlyout)

    charactersFlyout.title = CreateLabel(charactersFlyout, 12, Theme.textPrimary, true)
    charactersFlyout.title:SetPoint("TOPLEFT", PAD, -10)
    charactersFlyout.title:SetText(L["ROSTER_CHARACTERS_TITLE"])

    charactersFlyout.hint = CreateLabel(charactersFlyout, 10.5, Theme.textFaint)
    charactersFlyout.hint:SetPoint("TOPLEFT", PAD, -26)
    charactersFlyout.hint:SetWidth(WIDTH - PAD * 2)
    charactersFlyout.hint:SetWordWrap(true)
    charactersFlyout.hint:SetJustifyH("LEFT")
    charactersFlyout.hint:SetText(L["ROSTER_CHARACTERS_HINT"])

    charactersFlyout.viewport = CreateFrame("Frame", nil, charactersFlyout)
    charactersFlyout.viewport:SetClipsChildren(true)
    charactersFlyout.viewport:EnableMouseWheel(true)

    charactersFlyout.content = CreateFrame("Frame", nil, charactersFlyout.viewport)
    charactersFlyout.content:SetPoint("TOPLEFT")
    charactersFlyout.content:SetSize(WIDTH, 1)

    charactersFlyout.viewport:SetScript("OnMouseWheel", function(self, delta)
      local max = math.max(0, (self.contentHeight or 0) - self:GetHeight())
      self.offset = math.min(max, math.max(0, (self.offset or 0) - delta * ROW_H * 2))
      charactersFlyout.content:SetPoint("TOPLEFT", 0, self.offset)
    end)

    charactersFlyout.rows = {}
    charactersFlyout.headers = {}

    tinsert(UISpecialFrames, "GGCharactersFlyout")

    charactersFlyout:SetScript("OnEvent", function(self, event)
      if event ~= "GLOBAL_MOUSE_DOWN" then return end
      if self:IsMouseOver() then return end
      if self.anchor and self.anchor:IsMouseOver() then return end
      self:Hide()
    end)
    charactersFlyout:SetScript("OnShow", function(self)
      self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    charactersFlyout:SetScript("OnHide", function(self)
      self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
      GG.Widgets.HideMenuVeil(self)
    end)
  end

  for _, row in ipairs(charactersFlyout.rows) do row:Hide() end
  for _, header in ipairs(charactersFlyout.headers) do header:Hide() end

  local rows = GG.Roster:BuildRows(true)
  table.sort(rows, function(a, b)
    if a.accountLabel ~= b.accountLabel then
      return (a.accountLabel or "") < (b.accountLabel or "")
    end
    return a.name:lower() < b.name:lower()
  end)

  local accountCount, seenAccounts = 0, {}
  for _, row in ipairs(rows) do
    if not seenAccounts[row.accountLabel or ""] then
      seenAccounts[row.accountLabel or ""] = true
      accountCount = accountCount + 1
    end
  end

  local cursorY, rowIndex, headerIndex, lastAccount = 0, 0, 0, nil
  for _, datum in ipairs(rows) do
    if accountCount > 1 and datum.accountLabel ~= lastAccount then
      lastAccount = datum.accountLabel
      headerIndex = headerIndex + 1
      local header = charactersFlyout.headers[headerIndex]
      if not header then
        header = CreateLabel(charactersFlyout.content, 10.5, Theme.accent, true)
        charactersFlyout.headers[headerIndex] = header
      end
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", PAD, -cursorY - 6)
      header:SetText(datum.accountLabel or "")
      header:Show()
      cursorY = cursorY + HEADER_H
    end

    rowIndex = rowIndex + 1
    local row = charactersFlyout.rows[rowIndex]
    if not row then
      row = CreateFrame("Frame", nil, charactersFlyout.content)
      row:SetSize(WIDTH - PAD * 2, ROW_H)

      row.toggle = GG.Widgets.CreateToggle(row, true, function(checked)
        if not row.datum then return end
        GG:SetCharacterHidden(row.datum.key, not checked)
        row.datum.hidden = not checked
        row:Paint()
        GG.RosterUI:Refresh()
      end)
      row.toggle:SetPoint("LEFT", 0, 0)

      row.name = CreateLabel(row, 11.5, Theme.textPrimary)
      row.name:SetPoint("LEFT", row.toggle, "RIGHT", 8, 0)

      row.realm = CreateLabel(row, 10, Theme.textFaint)
      row.realm:SetPoint("LEFT", row.name, "RIGHT", 5, 0)

      row.delete = CreateFrame("Button", nil, row)
      row.delete:SetSize(16, 16)
      row.delete:SetPoint("RIGHT", 0, 0)
      row.delete.icon = row.delete:CreateFontString(nil, "OVERLAY")
      row.delete.icon:SetFont(Theme.font, 12, "")
      row.delete.icon:SetPoint("CENTER")
      row.delete.icon:SetText("x")
      row.delete.icon:SetTextColor(unpack(Theme.textFaint))
      row.delete:SetScript("OnEnter", function(self)
        self.icon:SetTextColor(unpack(Theme.danger))
        GG.Tip:Open(self, { family = "danger" }, function(t) t:Text(L["ROSTER_CHARACTERS_DELETE_TOOLTIP"]) end)
      end)
      row.delete:SetScript("OnLeave", function(self)
        self.icon:SetTextColor(unpack(Theme.textFaint))
        GameTooltip:Hide()
      end)
      row.delete:SetScript("OnClick", function()
        if not row.datum then return end
        charactersFlyout:Hide()
        GG.RosterUI:ConfirmRemoveCharacter(row.datum.key, row.datum.name, row.datum.realm)
      end)

      function row:Paint()
        local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[self.datum.class]
        local dim = self.datum.hidden and 0.45 or 1
        if classColor then
          self.name:SetTextColor(classColor.r * dim, classColor.g * dim, classColor.b * dim, 1)
        else
          local c = Theme.textPrimary
          self.name:SetTextColor(c[1] * dim, c[2] * dim, c[3] * dim, 1)
        end
        local rc = Theme.textFaint
        self.realm:SetTextColor(rc[1] * dim, rc[2] * dim, rc[3] * dim, 1)
        self.toggle:SetChecked(not self.datum.hidden)
      end

      charactersFlyout.rows[rowIndex] = row
    end

    row.datum = datum
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", PAD, -cursorY)
    row.name:SetText(datum.name or "?")
    row.realm:SetText(datum.realm or "")
    row.delete:SetShown(datum.isOwn == true)
    row:Paint()
    row:Show()
    cursorY = cursorY + ROW_H
  end

  local headerHeight = 26 + math.max(charactersFlyout.hint:GetStringHeight(), 26) + 10
  local maxListHeight = math.max(ROW_H * 3, UIParent:GetHeight() * 0.6)
  local listHeight = math.min(cursorY, maxListHeight)

  charactersFlyout.content:SetHeight(math.max(cursorY, 1))
  charactersFlyout.viewport.contentHeight = cursorY
  charactersFlyout.viewport.offset = 0
  charactersFlyout.content:SetPoint("TOPLEFT", 0, 0)
  charactersFlyout.viewport:ClearAllPoints()
  charactersFlyout.viewport:SetPoint("TOPLEFT", 0, -headerHeight)
  charactersFlyout.viewport:SetSize(WIDTH, listHeight)

  charactersFlyout:SetSize(WIDTH, headerHeight + listHeight + PAD)
  charactersFlyout:ClearAllPoints()
  charactersFlyout:SetPoint("TOPRIGHT", anchor or UIParent, "BOTTOMRIGHT", 0, -4)
  charactersFlyout.anchor = anchor
  charactersFlyout:Show()
  if anchor then GG.Widgets.ShowMenuVeil(anchor, charactersFlyout) end
end

StaticPopupDialogs["GG_ROSTER_HIDE_CHARACTER"] = {
  text = L["ROSTER_HIDE_CONFIRM"],
  button1 = YES,
  button2 = CANCEL,
  OnAccept = function(_, data)
    if not data or not data.key then return end
    GG:SetCharacterHidden(data.key, true)
    GG.RosterUI:Refresh()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function GG.RosterUI:ConfirmHideCharacter(key, name, realm)
  if not key then return end
  local label = ("%s-%s"):format(name or "?", realm or "?")
  StaticPopup_Show("GG_ROSTER_HIDE_CHARACTER", label, nil, { key = key })
end

StaticPopupDialogs["GG_ROSTER_REMOVE_CHARACTER"] = {
  text = L["ROSTER_REMOVE_CONFIRM"],
  button1 = YES,
  button2 = CANCEL,
  OnAccept = function(_, data)
    if not data or not data.key then return end
    GGDB.chars[data.key] = nil
    if GGDB.ownCharacters then GGDB.ownCharacters[data.key] = nil end
    if GGDB.options then
      if GGDB.options.mainCharacterKey == data.key then
        GGDB.options.mainCharacterKey = nil
      end
      if GGDB.options.hiddenCharacters then
        GGDB.options.hiddenCharacters[data.key] = nil
      end
      if GGDB.options.customOrder then
        for i = #GGDB.options.customOrder, 1, -1 do
          if GGDB.options.customOrder[i] == data.key then
            table.remove(GGDB.options.customOrder, i)
          end
        end
      end
    end
    GG.RosterUI:Refresh()
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function GG.RosterUI:ConfirmRemoveCharacter(key, name, realm)
  if not (GGDB.ownCharacters and GGDB.ownCharacters[key]) then return end

  local label = ("%s-%s"):format(name or "?", realm or "?")
  StaticPopup_Show("GG_ROSTER_REMOVE_CHARACTER", label, nil, { key = key })
end

local dragIndicator, dragIndicatorGlow, dragIndicatorCapLeft, dragIndicatorCapRight
local dragState = { active = false, key = nil, row = nil }

local function SetRowDragSourceShown(row, shown)
  row.dragSourceFill:SetShown(shown)
  row.dragSourceBorderTop:SetShown(shown)
  row.dragSourceBorderBottom:SetShown(shown)
  row.dragSourceBorderLeft:SetShown(shown)
  row.dragSourceBorderRight:SetShown(shown)
end

local function EnsureDragIndicator()
  if dragIndicator then return dragIndicator end

  dragIndicatorGlow = scrollClip:CreateTexture(nil, "OVERLAY")
  dragIndicatorGlow:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.35)
  dragIndicatorGlow:Hide()

  dragIndicator = scrollClip:CreateTexture(nil, "OVERLAY", nil, 1)
  dragIndicator:SetColorTexture(unpack(Theme.accent))
  dragIndicator:Hide()

  dragIndicatorCapLeft = scrollClip:CreateTexture(nil, "OVERLAY", nil, 2)
  dragIndicatorCapLeft:SetSize(8, 8)
  dragIndicatorCapLeft:SetColorTexture(unpack(Theme.accent))
  dragIndicatorCapLeft:Hide()

  dragIndicatorCapRight = scrollClip:CreateTexture(nil, "OVERLAY", nil, 2)
  dragIndicatorCapRight:SetSize(8, 8)
  dragIndicatorCapRight:SetColorTexture(unpack(Theme.accent))
  dragIndicatorCapRight:Hide()

  return dragIndicator
end

local function ComputeDropIndex()
  local shown = 0
  for i, row in ipairs(rowPool) do
    if row:IsShown() then
      shown = i
      if row:IsMouseOver() then
        return scrollOffset + i
      end
      if row.gapCatcher and row.gapCatcher:IsShown() and row.gapCatcher:IsMouseOver() then
        return scrollOffset + i + 1
      end
    end
  end
  if shown > 0 then
    local beyondStart
    if IsVertical() then
      beyondStart = rowPool[1]:IsMouseOver(0, 0, -100000, 0)
    else
      beyondStart = rowPool[1]:IsMouseOver(-100000, 0, 0, 0)
    end
    if beyondStart then
      return scrollOffset + 1
    end
  end
  return math.max(1, math.min(scrollOffset + shown + 1, #dataRows + 1))
end

local function DragOnUpdate()
  if not dragState.active then return end
  local dropIndex = ComputeDropIndex()
  local poolIndex = dropIndex - scrollOffset
  local indicator = EnsureDragIndicator()

  indicator:ClearAllPoints()
  dragIndicatorGlow:ClearAllPoints()
  dragIndicatorCapLeft:ClearAllPoints()
  dragIndicatorCapRight:ClearAllPoints()

  if IsVertical() then
    local x = (poolIndex - 1) * V.ColPitch() + V.COL_GAP / 2
    indicator:SetWidth(3)
    indicator:SetPoint("TOPLEFT", scrollClip, "TOPLEFT", x - 1, 0)
    indicator:SetPoint("BOTTOMLEFT", scrollClip, "BOTTOMLEFT", x - 1, 0)
    dragIndicatorGlow:SetWidth(10)
    dragIndicatorGlow:SetPoint("TOPLEFT", scrollClip, "TOPLEFT", x - 5, 0)
    dragIndicatorGlow:SetPoint("BOTTOMLEFT", scrollClip, "BOTTOMLEFT", x - 5, 0)
    dragIndicatorCapLeft:SetPoint("CENTER", indicator, "TOP", 0, 0)
    dragIndicatorCapRight:SetPoint("CENTER", indicator, "BOTTOM", 0, 0)
  else
    local y = -(poolIndex - 1) * (CONST.ROW_HEIGHT + CONST.ROW_GAP) + CONST.ROW_GAP / 2
    indicator:SetHeight(3)
    indicator:SetPoint("LEFT", scrollClip, "LEFT", 0, 0)
    indicator:SetPoint("RIGHT", scrollClip, "RIGHT", 0, 0)
    indicator:SetPoint("TOP", scrollClip, "TOP", 0, y)
    dragIndicatorGlow:SetHeight(10)
    dragIndicatorGlow:SetPoint("LEFT", scrollClip, "LEFT", 0, 0)
    dragIndicatorGlow:SetPoint("RIGHT", scrollClip, "RIGHT", 0, 0)
    dragIndicatorGlow:SetPoint("TOP", scrollClip, "TOP", 0, y)
    dragIndicatorCapLeft:SetPoint("CENTER", indicator, "LEFT", 0, 0)
    dragIndicatorCapRight:SetPoint("CENTER", indicator, "RIGHT", 0, 0)
  end

  indicator:Show()
  dragIndicatorGlow:Show()
  dragIndicatorCapLeft:Show()
  dragIndicatorCapRight:Show()
end

function GG.RosterUI:StartRowDrag(row)
  if state.filterTab ~= "all" or state.accountFilter or state.search ~= "" then return end
  if not row.datum then return end
  if state.arrangeCfg and state.arrangeCtx
    and not GG.Arrange:DragSection(state.arrangeCfg, state.arrangeCtx, row.datum) then
    return
  end
  dragState.active = true
  dragState.key = row.datum.key
  dragState.row = row
  SetRowDragSourceShown(row, true)
  scrollClip:SetScript("OnUpdate", DragOnUpdate)
  DragOnUpdate()
end

function GG.RosterUI:StopRowDrag()
  if not dragState.active then return end
  dragState.active = false
  scrollClip:SetScript("OnUpdate", nil)
  EnsureDragIndicator()
  dragIndicator:Hide()
  dragIndicatorGlow:Hide()
  dragIndicatorCapLeft:Hide()
  dragIndicatorCapRight:Hide()
  if dragState.row then SetRowDragSourceShown(dragState.row, false) end
  dragState.row = nil

  local key = dragState.key
  dragState.key = nil
  if not key then return end

  EnsureCustomOrderComplete()
  local dropIndex = ComputeDropIndex()
  local visible, byKey = {}, {}
  for i, r in ipairs(dataRows) do
    visible[i] = r.key
    byKey[r.key] = r
  end
  local cfg, ctx = state.arrangeCfg, state.arrangeCtx
  local function SectionOf(k)
    if not (cfg and ctx and byKey[k]) then return "all" end
    return GG.Arrange:DragSection(cfg, ctx, byKey[k]) or ("fixed:" .. k)
  end
  GGDB.options.customOrder = GG.Arrange.MoveWithinSection(GGDB.options.customOrder, visible, key, dropIndex, SectionOf)

  self:Refresh()
end

function GG.RosterUI:Relayout()
  if frame and frame:IsShown() then
    Relayout()
  end
end

function GG.RosterUI:OnRaidRostersChanged()
  if not frame or not frame:IsShown() then return end
  Relayout()
  RebuildDataRows()
  if GG.RaidRostersTab then GG.RaidRostersTab:Refresh() end
end

function GG.RosterUI:OpenRosters()
  if not frame or not frame:IsShown() then self:Toggle() end
  self:SelectTab("rosters")
end

function EnsureVerticalWindowHeight()
  AutoSizeWindow()
end

function EnsureHorizontalWindowWidth()
  AutoSizeWindow()
end

function GG.RosterUI:ToggleLayoutMode()
  GGDB.options = GGDB.options or {}
  GGDB.options.layoutMode = IsVertical() and "horizontal" or "vertical"
  self:ApplyLayoutMode()
end

function GG.RosterUI:ApplyLayoutMode()
  if RefreshLayoutButton then RefreshLayoutButton() end
  if not frame then return end

  scrollOffset = 0

  verticalMap = RebuildVerticalSections()
  EnsureVerticalWindowHeight()
  EnsureHorizontalWindowWidth()
  Relayout()
  SaveWindowState()
  if GG.UI and GG.UI.OnRosterLayoutChanged then GG.UI:OnRosterLayoutChanged() end
end

function GG.RosterUI:ApplyScale(scale)
  if frame then
    frame:SetScale(scale or 1.0)
  end
end

function GG.RosterUI:ApplyEscBehavior()
  for i = #UISpecialFrames, 1, -1 do
    if UISpecialFrames[i] == "GGRosterWindow" then table.remove(UISpecialFrames, i) end
  end
  if not (GGDB.options and GGDB.options.closeWithEsc == false) then
    tinsert(UISpecialFrames, "GGRosterWindow")
  end
end

function GG.RosterUI:CenterWindow()
  if not frame then return end
  frame:ClearAllPoints()
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  SaveWindowState()
end

function GG.RosterUI:BuildSettingsColumnsPreview(container)
  return BuildSettingsColumnsPreview(container)
end

function GG.RosterUI:BuildSettingsBossesPreview(container)
  return BuildSettingsBossesPreview(container)
end

function GG.RosterUI:BuildSettingsColumnsPreviewVertical(container)
  return BuildSettingsColumnsPreviewVertical(container)
end

function GG.RosterUI:BuildSettingsBossesPreviewVertical(container)
  return BuildSettingsBossesPreviewVertical(container)
end

function GG.RosterUI:FitSettingsWidth()
  if not settingsOpen or not AutoSizeWindow then return false end
  return AutoSizeWindow() == true
end

function GG.RosterUI:IsVertical()
  return IsVertical()
end

function GG.RosterUI:ApplyOpacity(opacity)
  for _, entry in ipairs(opacityPanels) do
    if entry.panel then
      entry.panel.SetAlpha(opacity)
    else
      entry.f:SetBackdropColor(entry.color[1], entry.color[2], entry.color[3], opacity or 1.0)
    end
  end
  if frame and frame:IsShown() then UpdateVisibleRows() end
end

function GGToggleLayoutMode()
  GG.RosterUI:ToggleLayoutMode()
end

BINDING_HEADER_GG = L["ADDON_TITLE"]
BINDING_NAME_GG_TOGGLE_LAYOUT = L["LAYOUT_BINDING_NAME"]
