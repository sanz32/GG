local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.SetupWizard = {}

local Theme = GG.Theme

local SETUP_VERSION = 1

local WIDTH, HEIGHT, PAD = 640, 520, 22
local NAV_BG = { 0.063, 0.071, 0.090, 1 }

local frame, content, kicker, title, lead, stepLabel, hint, backBtn, nextBtn
local progressBars = {}
local steps
local index = 1
local reviewMode = false
local Render

local function CreateLabel(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size, "")
  fs:SetTextColor(unpack(color))
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

local function Setup()
  GGDB.setup = GGDB.setup or {}
  return GGDB.setup
end

local function FieldsStep(category, ids, tweak)
  return function(container, width)
    local fields = GG.UI:GetSettingsFields(category, ids)
    for _, field in ipairs(fields) do
      if tweak then tweak(field) end
      if field.set then
        local original = field.set
        field.set = function(...)
          original(...)
          C_Timer.After(0, Render)
        end
      end
      field.rerender = Render
    end
    return GG.UI:RenderFieldList(container, fields, width)
  end
end

local function NoDesc(field) field.desc = nil end
local function Bare(field)
  field.desc = nil
  field.label = ""
end

local function FlatBorder(parent, color, thickness)
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local line = parent:CreateTexture(nil, "BORDER")
    line:SetColorTexture(unpack(color))
    if side == "TOP" or side == "BOTTOM" then
      line:SetPoint(side .. "LEFT"); line:SetPoint(side .. "RIGHT"); line:SetHeight(thickness)
    else
      line:SetPoint("TOP" .. side); line:SetPoint("BOTTOM" .. side); line:SetWidth(thickness)
    end
  end
end

local function BuildLayoutCards(container, width)
  local options = GGDB.options
  local gap, cardH = 14, 226
  local cardW = math.floor((width - gap) / 2)
  local a = Theme.accent
  for i, def in ipairs({
    { key = "horizontal", titleKey = "OPT_LAYOUT_ROWS", descKey = "WIZ_ROWS_DESC" },
    { key = "vertical", titleKey = "OPT_LAYOUT_COLUMNS", descKey = "WIZ_COLUMNS_DESC" },
  }) do
    local selected = (options.layoutMode == "vertical") == (def.key == "vertical")
    local card = CreateFrame("Button", nil, container)
    card:SetSize(cardW, cardH)
    card:SetPoint("TOPLEFT", (i - 1) * (cardW + gap), 0)
    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    if selected then
      bg:SetGradient("VERTICAL", CreateColor(a[1], a[2], a[3], 0.02), CreateColor(a[1], a[2], a[3], 0.16))
      FlatBorder(card, Theme.accent, 2)
    else
      bg:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0.03), CreateColor(1, 1, 1, 0.03))
      FlatBorder(card, Theme.border, 1)
    end

    local mini = CreateFrame("Frame", nil, card)
    mini:SetPoint("TOPLEFT", 10, -10)
    mini:SetSize(cardW - 20, 150)
    local miniBg = mini:CreateTexture(nil, "BACKGROUND")
    miniBg:SetAllPoints()
    miniBg:SetColorTexture(0.086, 0.098, 0.133, 1)
    local innerW, innerH = cardW - 32, 138
    local fractions = { 0.26, 0.12, 0.12, 0.22, 0.28 }
    local lines = def.key == "horizontal" and 4 or 5
    for line = 1, lines do
      local offset = 0
      for cell, fraction in ipairs(fractions) do
        local block = mini:CreateTexture(nil, "ARTWORK")
        if cell == 1 then block:SetColorTexture(a[1], a[2], a[3], 0.5) else block:SetColorTexture(0.18, 0.2, 0.26, 1) end
        if def.key == "horizontal" then
          local rowH = (innerH - (lines - 1) * 4) / lines
          local w = innerW * fraction - 4
          block:SetSize(w, rowH)
          block:SetPoint("TOPLEFT", 6 + offset, -(6 + (line - 1) * (rowH + 4)))
          offset = offset + w + 4
        else
          local colW = (innerW - (lines - 1) * 4) / lines
          local h = innerH * fraction - 4
          block:SetSize(colW, h)
          block:SetPoint("TOPLEFT", 6 + (line - 1) * (colW + 4), -(6 + offset))
          offset = offset + h + 4
        end
      end
    end

    local name = CreateLabel(card, 14, selected and { 1, 1, 1, 1 } or Theme.textPrimary, true)
    name:SetPoint("TOPLEFT", mini, "BOTTOMLEFT", 0, -10)
    name:SetText(L[def.titleKey])
    local desc = CreateLabel(card, 11, Theme.textFaint)
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    desc:SetWidth(cardW - 20)
    desc:SetWordWrap(true)
    desc:SetText(L[def.descKey])

    card:SetScript("OnClick", function()
      if selected then return end
      options.layoutMode = def.key
      GG.RosterUI:ApplyLayoutMode()
      C_Timer.After(0, Render)
    end)
  end
  return cardH
end

local shownFields = FieldsStep("window", { "shown" }, Bare)
local function BuildShown(container, width)
  local y = shownFields(container, width) + 16
  local count = #GG.Roster:BuildRows()
  local setting = GGDB.options.maxVisibleCharacters
  local visible = setting == "all" and count or math.min(count, tonumber(setting) or 10)
  local text = CreateLabel(container, 12.5, Theme.textPrimary)
  text:SetPoint("TOPLEFT", 0, -y)
  text:SetWidth(width)
  text:SetWordWrap(true)
  if count > visible then
    text:SetText(L["WIZ_SHOWN_PREVIEW"]:format(count, visible, count - visible))
  else
    text:SetText(L["WIZ_SHOWN_PREVIEW_ALL"]:format(count))
  end
  y = y + text:GetStringHeight() + 10
  local blocks = math.min(count, 24)
  if blocks > 0 then
    local gap = 4
    local blockW = math.min(40, (width - (blocks - 1) * gap) / blocks)
    local a = Theme.accent
    for i = 1, blocks do
      local block = container:CreateTexture(nil, "ARTWORK")
      block:SetSize(blockW, 46)
      block:SetPoint("TOPLEFT", (i - 1) * (blockW + gap), -y)
      if i <= visible then block:SetColorTexture(a[1], a[2], a[3], 0.55) else block:SetColorTexture(0.17, 0.19, 0.24, 1) end
    end
    y = y + 46
  end
  return y
end

local scaleFields = FieldsStep("window", { "scale" }, Bare)
local function BuildScale(container, width)
  local y = scaleFields(container, width) + 18
  local holder = CreateFrame("Frame", nil, container)
  holder:SetPoint("TOPLEFT", 0, -y)
  holder:SetSize(width, 110)
  local sample = CreateFrame("Frame", nil, holder)
  sample:SetSize(300, 64)
  sample:SetPoint("TOPLEFT", 0, 0)
  sample:SetScale(GGDB.options.windowScale or 1)
  local bg = sample:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(unpack(Theme.panel))
  local _, class = UnitClass("player")
  local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  local icon = sample:CreateTexture(nil, "ARTWORK")
  icon:SetSize(40, 40)
  icon:SetPoint("LEFT", 12, 0)
  icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
  local coords = class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]
  if coords then icon:SetTexCoord(unpack(coords)) end
  local name = CreateLabel(sample, 14, classColor and { classColor.r, classColor.g, classColor.b, 1 } or Theme.textPrimary, true)
  name:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
  name:SetText(UnitName("player") or "?")
  local realm = CreateLabel(sample, 11, Theme.textMuted)
  realm:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
  realm:SetText(GetRealmName() or "")
  local _, equipped = GetAverageItemLevel()
  local ilvl = CreateLabel(sample, 17, Theme.purple, true)
  ilvl:SetPoint("RIGHT", -14, 0)
  ilvl:SetText(("%.2f"):format(equipped or 0))
  return y + 110
end

local colorFields = FieldsStep("window", { "color" }, function(field) field.noReloadNotice = true end)
local function BuildColor(container, width)
  local y = colorFields(container, width) + 12
  local r, g, b = GG:ResolveAccentRGB()
  if not r then r, g, b = unpack(GG.ACCENT_DEFAULT) end
  local accent, onAccent = GG:DeriveAccent(r, g, b)

  local caption = CreateLabel(container, 10.5, Theme.textFaint, true)
  caption:SetPoint("TOPLEFT", 0, -y)
  caption:SetText(L["WIZ_COLOR_PREVIEW"]:upper())
  y = y + 18

  local strip = CreateFrame("Frame", nil, container)
  strip:SetPoint("TOPLEFT", 0, -y)
  strip:SetSize(width, 44)
  local stripBg = strip:CreateTexture(nil, "BACKGROUND")
  stripBg:SetAllPoints()
  stripBg:SetColorTexture(0.063, 0.071, 0.090, 1)

  local tabBar = strip:CreateTexture(nil, "ARTWORK")
  tabBar:SetSize(96, 2)
  tabBar:SetPoint("TOPLEFT", 10, -8)
  tabBar:SetColorTexture(unpack(accent))
  local tab = CreateLabel(strip, 12.5, { 1, 1, 1, 1 }, true)
  tab:SetPoint("TOPLEFT", 18, -17)
  tab:SetText(L["ROSTER_TAB_ALL"])
  local btn = strip:CreateTexture(nil, "ARTWORK")
  btn:SetSize(104, 24)
  btn:SetPoint("LEFT", 126, 0)
  btn:SetColorTexture(unpack(accent))
  local btnText = CreateLabel(strip, 12, onAccent, true)
  btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
  btnText:SetText(L["WIZ_NEXT"])
  local track = strip:CreateTexture(nil, "ARTWORK")
  track:SetSize(44, 22)
  track:SetPoint("LEFT", btn, "RIGHT", 18, 0)
  track:SetTexture("Interface\\AddOns\\GG\\Media\\SwitchTrack128.tga")
  track:SetVertexColor(unpack(accent))
  local knob = strip:CreateTexture(nil, "OVERLAY")
  knob:SetSize(16, 16)
  knob:SetPoint("RIGHT", track, "RIGHT", -3, 0)
  knob:SetTexture("Interface\\AddOns\\GG\\Media\\SwitchKnob64.tga")
  local on = CreateLabel(strip, 8.5, onAccent, true)
  on:SetPoint("LEFT", track, "LEFT", 7, 0)
  on:SetText("ON")
  local chip = CreateFrame("Frame", nil, strip)
  chip:SetSize(150, 28)
  chip:SetPoint("LEFT", track, "RIGHT", 18, 0)
  local chipBg = chip:CreateTexture(nil, "BACKGROUND")
  chipBg:SetAllPoints()
  chipBg:SetColorTexture(1, 1, 1, 1)
  chipBg:SetGradient("HORIZONTAL", CreateColor(accent[1], accent[2], accent[3], 0.22), CreateColor(accent[1], accent[2], accent[3], 0.03))
  FlatBorder(chip, { accent[1], accent[2], accent[3], 0.6 }, 1)
  local chipText = CreateLabel(chip, 12, Theme.textPrimary, true)
  chipText:SetPoint("LEFT", 10, 0)
  chipText:SetText(L["SECTION_ILVL"])
  return y + 44
end

local announceFields = FieldsStep("announcements",
  { "announceInstanceReset", "announceKeystoneParty", "announceKeystoneGuild" }, NoDesc)
local function BuildAnnouncements(container, width)
  local y = announceFields(container, width) + 14
  local options = GGDB.options
  local playerName = UnitName("player") or "?"
  local PARTY, GUILD = { 0.667, 0.667, 1, 1 }, { 0.251, 1, 0.251, 1 }
  local example = L["OPTIONS_PREVIEW_KEYSTONE_EXAMPLE"]
  local keystoneText = GG.Announce and GG.Announce.FormatKeystoneText
    and GG.Announce:FormatKeystoneText(L["ANNOUNCE_NEW_KEYSTONE"], example) or example
  local function Prefix(template) return ((template or "[%s]: "):gsub("|H.-|h(.-)|h", "%1")):format(playerName) end
  local lines = {
    { options.announceInstanceReset, PARTY, Prefix(CHAT_PARTY_GET) .. ">GG< " .. L["ANNOUNCE_INSTANCES_RESET"] },
    { options.announceKeystoneParty, PARTY, Prefix(CHAT_PARTY_GET) .. ">GG< " .. keystoneText },
    { options.announceKeystoneGuild, GUILD, Prefix(CHAT_GUILD_GET) .. ">GG< " .. keystoneText },
  }
  local chat = CreateFrame("Frame", nil, container)
  chat:SetPoint("TOPLEFT", 0, -y)
  chat:SetSize(width, #lines * 18 + 14)
  local bg = chat:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0, 0, 0, 0.4)
  for i, line in ipairs(lines) do
    local text = CreateLabel(chat, 11.5, line[2])
    text:SetPoint("TOPLEFT", 10, -(7 + (i - 1) * 18))
    text:SetWidth(width - 20)
    text:SetText(line[3])
    text:SetAlpha(line[1] and 1 or 0.3)
  end
  return y + chat:GetHeight()
end

local function BuildSummary(container, width)
  local o = GGDB.options
  local check = container:CreateTexture(nil, "ARTWORK")
  check:SetSize(40, 40)
  check:SetPoint("TOPLEFT", 0, 0)
  check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  local text = CreateLabel(container, 12.5, Theme.textMuted)
  text:SetPoint("LEFT", check, "RIGHT", 12, 0)
  text:SetWidth(width - 60)
  text:SetWordWrap(true)
  text:SetText(L["WIZ_DONE_TEXT"])

  local shown = o.maxVisibleCharacters == "all" and L["OPT_SHOWN_ALL"] or tostring(o.maxVisibleCharacters or 10)
  local colorText = (o.accentMode == "class" and L["WIZ_SUM_COLOR_CLASS"])
    or (o.accentMode == "custom" and L["WIZ_SUM_COLOR_CUSTOM"]) or L["WIZ_SUM_COLOR_DEFAULT"]
  local announces = {}
  if o.announceInstanceReset then table.insert(announces, L["WIZ_ANN_S_RESET"]) end
  if o.announceKeystoneParty then table.insert(announces, L["WIZ_ANN_S_PARTY"]) end
  if o.announceKeystoneGuild then table.insert(announces, L["WIZ_ANN_S_GUILD"]) end
  local styleText = "?"
  for _, style in ipairs(GG.BossIcons.STYLES) do
    if style.key == GG.BossIcons:GetStyle() then styleText = L[style.labelKey] end
  end
  local difficulties = {}
  for _, def in ipairs({ { 17, "DIFFICULTY_LFR" }, { 14, "DIFFICULTY_NORMAL" }, { 15, "DIFFICULTY_HEROIC" }, { 16, "DIFFICULTY_MYTHIC" } }) do
    if o.raidDifficulties[def[1]] then table.insert(difficulties, L[def[2]]) end
  end
  local columnKeys = { "avatar", "ilvl", "rating", "guild", "account", "keystone", "vault", "dungeons", "raids", "currencies" }
  local columnsOn = 0
  for _, key in ipairs(columnKeys) do
    if o.sections[key] then columnsOn = columnsOn + 1 end
  end
  local columnsTotal = #columnKeys
  local labelStyle = L["ACCOUNT_LABEL_STYLE_" .. string.upper(o.accountLabelStyle or "cuenta")] or ""

  local rows = {
    { "WIZ_SUM_LAYOUT", L["WIZ_SUM_LAYOUT_FMT"]:format(
      o.layoutMode == "vertical" and L["OPT_LAYOUT_COLUMNS"] or L["OPT_LAYOUT_ROWS"], shown,
      math.floor((o.windowScale or 1) * 100 + 0.5)) },
    { "WIZ_SUM_COLOR", colorText },
    { "WIZ_SUM_ACCOUNTS", L["WIZ_SUM_ACCOUNT_FMT"]:format(
      o.accountSlotManual and tostring(o.accountSlot or 1) or L["WIZ_SUM_AUTO"], labelStyle) },
    { "WIZ_SUM_ANN", #announces > 0 and table.concat(announces, ", ") or L["WIZ_SUM_NONE"] },
    { "WIZ_SUM_BOSSES", styleText .. " · " .. (#difficulties > 0 and table.concat(difficulties, ", ") or L["WIZ_SUM_NONE"]) },
    { "WIZ_SUM_COLUMNS", L["WIZ_SUM_COLUMNS_FMT"]:format(columnsOn, columnsTotal) },
  }
  local y = 62
  for _, row in ipairs(rows) do
    local key = CreateLabel(container, 12, Theme.textFaint)
    key:SetPoint("TOPLEFT", 0, -y)
    key:SetText(L[row[1]])
    local value = CreateLabel(container, 12, Theme.textPrimary, true)
    local valueX = 130
    if row[1] == "WIZ_SUM_COLOR" then
      local r, g, b = GG:ResolveAccentRGB()
      if not r then r, g, b = unpack(GG.ACCENT_DEFAULT) end
      local dot = container:CreateTexture(nil, "ARTWORK")
      dot:SetSize(12, 12)
      dot:SetPoint("TOPLEFT", valueX, -y + 1)
      dot:SetTexture("Interface\\AddOns\\GG\\Media\\SwitchKnob64.tga")
      dot:SetVertexColor(r, g, b, 1)
      valueX = valueX + 18
    end
    value:SetPoint("TOPLEFT", valueX, -y)
    value:SetWidth(width - valueX)
    value:SetText(row[2])
    y = y + 22
  end
  return y
end

local ALL_STEPS = {
  { since = 1, kicker = "SETTINGS_CAT_WINDOW", title = "WIZ_LAYOUT_TITLE", lead = "WIZ_LAYOUT_LEAD", build = BuildLayoutCards },
  { since = 1, kicker = "SETTINGS_CAT_WINDOW", title = "WIZ_SHOWN_TITLE", lead = "OPT_SHOWN_DESC", build = BuildShown },
  { since = 1, kicker = "SETTINGS_CAT_WINDOW", title = "WIZ_SCALE_TITLE", lead = "WIZ_SCALE_LEAD", build = BuildScale },
  { since = 1, kicker = "SETTINGS_BOX_COLOR", title = "WIZ_COLOR_TITLE", lead = "WIZ_COLOR_LEAD", build = BuildColor },
  { since = 1, kicker = "SETTINGS_CAT_ACCOUNT", title = "WIZ_ACCOUNT_TITLE", lead = "WIZ_ACCOUNT_LEAD",
    build = FieldsStep("account", { "accountSlot", "labelStyle", "link" }) },
  { since = 1, kicker = "SETTINGS_CAT_ANNOUNCEMENTS", title = "WIZ_ANN_TITLE", lead = "WIZ_ANN_LEAD", build = BuildAnnouncements },
  { since = 1, kicker = "SETTINGS_CAT_BOSSES", title = "WIZ_BOSSES_TITLE", lead = "WIZ_BOSSES_LEAD",
    build = FieldsStep("bosses", { "bossStyle", "diffHeader", "diff:17", "diff:14", "diff:15", "diff:16" }) },
  { since = 1, kicker = "SETTINGS_CAT_COLUMNS", title = "WIZ_COLUMNS_TITLE", lead = "WIZ_COLUMNS_LEAD",
    build = FieldsStep("columns", {
      "colgroup:SETTINGS_GROUP_CHARACTER", "col:avatar", "col:ilvl", "col:rating", "col:guild", "col:account",
      "colgroup:SETTINGS_GROUP_WEEKLY", "col:keystone", "col:vault", "col:dungeons", "col:raids", "col:currencies",
    }) },
}
local DONE_STEP = { kicker = "WIZ_DONE_LABEL", title = "WIZ_DONE_TITLE", build = BuildSummary, isDone = true }

local function PendingSteps(all)
  local completed = all and 0 or (Setup().completed or 0)
  local list = {}
  for _, step in ipairs(ALL_STEPS) do
    if step.since > completed then table.insert(list, step) end
  end
  table.insert(list, DONE_STEP)
  return list
end

local function Complete()
  local setup = Setup()
  setup.completed = SETUP_VERSION
  setup.resume = nil
end

local function IsLastStep() return steps and index == #steps end

local function AccentNeedsReload()
  return GG.AccentSignature and GG:AccentSignature() ~= GG.appliedAccentSignature
end

local function CreatePrimaryButton(parent, onClick)
  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetHeight(26)
  btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  btn:SetBackdropColor(unpack(Theme.accent))
  btn:SetBackdropBorderColor(unpack(Theme.accent))
  btn.label = CreateLabel(btn, 12, Theme.onAccent, true)
  btn.label:SetPoint("CENTER")
  btn:SetScript("OnEnter", function(self) self:SetBackdropColor(unpack(Theme.accentHi)) end)
  btn:SetScript("OnLeave", function(self) self:SetBackdropColor(unpack(Theme.accent)) end)
  btn:SetScript("OnClick", onClick)
  function btn:SetLabel(text)
    self.label:SetText(text)
    self:SetWidth(math.max(90, self.label:GetStringWidth() + 32))
  end
  return btn
end

local function Build()
  frame = CreateFrame("Frame", "GGSetupWizard", UIParent, "BackdropTemplate")
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  GG.Widgets.ApplyPanel(frame, { bg = Theme.background, corners = "all", glow = true })
  local solid = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
  solid:SetPoint("TOPLEFT", 3, -3)
  solid:SetPoint("BOTTOMRIGHT", -3, 3)
  solid:SetColorTexture(Theme.background[1], Theme.background[2], Theme.background[3], 1)
  tinsert(UISpecialFrames, "GGSetupWizard")

  local top = frame:CreateTexture(nil, "ARTWORK")
  top:SetPoint("TOPLEFT", 1, -1)
  top:SetPoint("TOPRIGHT", -1, -1)
  top:SetHeight(34)
  top:SetColorTexture(unpack(NAV_BG))
  local logo = frame:CreateTexture(nil, "OVERLAY")
  logo:SetSize(18, 18)
  logo:SetPoint("TOPLEFT", 14, -9)
  logo:SetTexture(Theme.media.logoIcon)
  logo:SetVertexColor(unpack(Theme.accent))
  local heading = CreateLabel(frame, 13.5, Theme.textPrimary, true)
  heading:SetPoint("LEFT", logo, "RIGHT", 8, 0)
  heading:SetText(L["WIZ_TITLE"])
  local close = CreateFrame("Button", nil, frame)
  close:SetSize(22, 22)
  close:SetPoint("TOPRIGHT", -8, -6)
  local closeLabel = CreateLabel(close, 15, Theme.textMuted, true)
  closeLabel:SetPoint("CENTER")
  closeLabel:SetText("x")
  close:SetScript("OnEnter", function() closeLabel:SetTextColor(unpack(Theme.textPrimary)) end)
  close:SetScript("OnLeave", function() closeLabel:SetTextColor(unpack(Theme.textMuted)) end)
  close:SetScript("OnClick", function() frame:Hide() end)
  stepLabel = CreateLabel(frame, 11.5, Theme.textFaint, true)
  stepLabel:SetPoint("RIGHT", close, "LEFT", -10, 0)

  kicker = CreateLabel(frame, 10.5, Theme.accentHi, true)
  kicker:SetPoint("TOPLEFT", PAD, -58)
  title = CreateLabel(frame, 20, Theme.textPrimary, true)
  title:SetPoint("TOPLEFT", kicker, "BOTTOMLEFT", 0, -6)
  title:SetWidth(WIDTH - PAD * 2)
  lead = CreateLabel(frame, 12, Theme.textFaint)
  lead:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  lead:SetWidth(WIDTH - PAD * 2)
  lead:SetWordWrap(true)

  local footLine = frame:CreateTexture(nil, "ARTWORK")
  footLine:SetPoint("BOTTOMLEFT", 1, 48)
  footLine:SetPoint("BOTTOMRIGHT", -1, 48)
  footLine:SetHeight(1)
  footLine:SetColorTexture(unpack(Theme.borderSoft))
  nextBtn = CreatePrimaryButton(frame, function()
    if IsLastStep() then
      local reload = AccentNeedsReload()
      Complete()
      frame:Hide()
      if reload then ReloadUI() end
      return
    end
    index = index + 1
    if not reviewMode then Setup().resume = index end
    Render()
  end)
  nextBtn:SetPoint("BOTTOMRIGHT", -14, 11)
  backBtn = GG.Widgets.CreateButton(frame, L["WIZ_BACK"], function()
    if index > 1 then
      index = index - 1
      if not reviewMode then Setup().resume = index end
      Render()
    end
  end)
  backBtn:SetHeight(26)
  backBtn:SetPoint("RIGHT", nextBtn, "LEFT", -8, 0)
  hint = CreateLabel(frame, 11, Theme.textFaint)
  hint:SetPoint("BOTTOMLEFT", 16, 18)
  hint:SetPoint("RIGHT", backBtn, "LEFT", -12, 0)

  frame:SetScript("OnHide", function()
    if IsLastStep() then Complete() end
  end)
end

Render = function()
  if not frame or not steps then return end
  local step = steps[index]
  local total = #steps

  local segW = (WIDTH - PAD * 2 - (total - 1) * 3) / total
  for i = 1, math.max(total, #progressBars) do
    local bar = progressBars[i]
    if not bar then
      bar = frame:CreateTexture(nil, "ARTWORK")
      bar:SetHeight(3)
      progressBars[i] = bar
    end
    bar:SetShown(i <= total)
    if i <= total then
      bar:ClearAllPoints()
      bar:SetWidth(segW)
      bar:SetPoint("TOPLEFT", PAD + (i - 1) * (segW + 3), -42)
      local a = Theme.accent
      if i < index then bar:SetColorTexture(a[1], a[2], a[3], 0.55)
      elseif i == index then bar:SetColorTexture(unpack(a))
      else bar:SetColorTexture(0.17, 0.19, 0.24, 1) end
    end
  end

  stepLabel:SetText(step.isDone and L["WIZ_DONE_LABEL"] or L["WIZ_STEP"]:format(index, total - 1))
  kicker:SetText(L[step.kicker]:upper())
  title:SetText(L[step.title])
  lead:SetText(step.lead and L[step.lead] or "")

  if content then
    content:Hide()
    content:SetParent(nil)
  end
  content = CreateFrame("Frame", nil, frame)
  local topOffset = step.lead and (lead:GetStringHeight() + 14) or 8
  content:SetPoint("TOPLEFT", lead, "BOTTOMLEFT", 0, -topOffset)
  content:SetWidth(WIDTH - PAD * 2)
  content:SetHeight(step.build(content, WIDTH - PAD * 2) or 1)

  backBtn:SetShown(index > 1)
  if step.isDone then
    nextBtn:SetLabel(AccentNeedsReload() and L["WIZ_FINISH_RELOAD"] or L["WIZ_FINISH"])
    hint:SetText(L["WIZ_HINT_LAST"])
  else
    nextBtn:SetLabel(L["WIZ_NEXT"])
    hint:SetText(L["WIZ_HINT"])
  end
end

function GG.SetupWizard:IsPending()
  return GGDB ~= nil and (Setup().completed or 0) < SETUP_VERSION
end

function GG.SetupWizard:Open(fromStart)
  if not GGDB or not GG.UI or not GG.UI.GetSettingsFields then return end
  if not frame then Build() end
  reviewMode = fromStart == true
  steps = PendingSteps(reviewMode)
  local resume = (not reviewMode) and Setup().resume or 1
  index = math.max(1, math.min(#steps, resume))
  frame:ClearAllPoints()
  frame:SetPoint("CENTER")
  frame:Show()
  Render()
end

local events = CreateFrame("Frame")
local triedThisSession = false

local function TryShow()
  if not GG.SetupWizard:IsPending() then return end
  if InCombatLockdown() then
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    return
  end
  GG.SetupWizard:Open(false)
end

events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function(self, event)
  if event == "PLAYER_ENTERING_WORLD" then
    if triedThisSession then return end
    triedThisSession = true
    C_Timer.After(3, TryShow)
  elseif event == "PLAYER_REGEN_ENABLED" then
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    C_Timer.After(1, TryShow)
  end
end)

SLASH_GGSETUP1 = "/ggsetup"
SlashCmdList["GGSETUP"] = function()
  if InCombatLockdown() then
    print("|cff8B5CF6GG|r " .. L["WIZ_IN_COMBAT"])
    return
  end
  GG.SetupWizard:Open(true)
end
