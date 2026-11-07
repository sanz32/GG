local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.ProfilePanel = {}
local Panel = GG.ProfilePanel
local Theme = GG.Theme
local P

local WHITE = "Interface\\Buttons\\WHITE8x8"
local NAV_BG = { 0.063, 0.071, 0.090, 1 }
local CARD_COLS, CARD_H, CARD_GAP = 4, 128, 10
local MAX_DIFF_LINES = 6

local state = {
  tab = "export",
  exportSel = nil,
  exportText = nil,
  step = "paste",
  pasted = "",
  decoded = nil,
  importSel = {},
  name = "",
}
Panel.state = state

local function Fade(c, a) return { c[1], c[2], c[3], a } end

local function Backdrop(f, bg, border)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(unpack(bg))
  f:SetBackdropBorderColor(unpack(border or Theme.border))
end

local function Text(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size, "")
  fs:SetTextColor(unpack(color or Theme.textPrimary))
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

local function TextWidth(fs)
  local w = fs:GetStringWidth()
  if w and w > 0 then return w end
  local _, size = fs:GetFont()
  return #(fs:GetText() or "") * (size or 11) * 0.6
end

local function Hex(c) return ("%02x%02x%02x"):format(c[1] * 255, c[2] * 255, c[3] * 255) end
local function Paint(text, c) return "|cff" .. Hex(c) .. text .. "|r" end

local function LinkButton(parent, label, color, onClick)
  local b = CreateFrame("Button", nil, parent)
  b.label = Text(b, 11.5, color or Theme.textFaint, true)
  b.label:SetPoint("LEFT")
  b.label:SetText(label)
  b:SetSize(TextWidth(b.label) + 2, 18)
  b:SetScript("OnEnter", function() b.label:SetTextColor(unpack(Theme.textPrimary)) end)
  b:SetScript("OnLeave", function() b.label:SetTextColor(unpack(color or Theme.textFaint)) end)
  b:SetScript("OnClick", onClick)
  return b
end

local function PrimaryButton(parent, label, onClick)
  local b = GG.Widgets.CreateButton(parent, label, onClick)
  b:SetHeight(26)
  b:SetWidth(TextWidth(b.label) + 28)
  b:SetBackdropColor(unpack(Theme.accent))
  b:SetBackdropBorderColor(unpack(Theme.accent))
  b.label:SetTextColor(unpack(Theme.onAccent))
  b:SetScript("OnEnter", nil)
  b:SetScript("OnLeave", nil)
  local setDisabled = b.SetDisabled
  b.SetDisabled = function(self, disabled)
    setDisabled(self, disabled)
    self:SetAlpha(disabled and 0.5 or 1)
  end
  return b
end

local function Button(parent, label, onClick)
  local b = GG.Widgets.CreateButton(parent, label, onClick)
  b:SetHeight(26)
  b:SetWidth(TextWidth(b.label) + 24)
  return b
end

local function TextBox(parent, width, height)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  Backdrop(holder, NAV_BG)
  holder:SetSize(width, height)
  holder:SetClipsChildren(true)
  local box = CreateFrame("EditBox", nil, holder)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetMaxLetters(0)
  box:SetFontObject("ChatFontNormal")
  box:SetFont(Theme.font, 10, "")
  box:SetTextColor(unpack(Theme.textMuted))
  box:SetTextInsets(8, 8, 6, 6)
  box:SetPoint("TOPLEFT")
  box:SetSize(width, height)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  holder:EnableMouse(true)
  holder:SetScript("OnMouseDown", function() box:SetFocus() end)
  return box, holder
end

local function SectionIcon(parent, ctx, key, size, color)
  local tex = parent:CreateTexture(nil, "ARTWORK")
  tex:SetSize(size, size)
  local info = ctx.icons[key]
  if info then
    tex:SetTexture(info.icon)
    if info.tint then tex:SetVertexColor(unpack(color or Theme.textMuted)) end
  end
  return tex
end

local function SectionName(key)
  return L["SETTINGS_CAT_" .. key:upper()] or key
end

local function OnOff(v) return v and L["PROFILE_ON"] or L["PROFILE_OFF"] end
local function ShownHidden(v) return v and L["PROFILE_SHOWN"] or L["PROFILE_HIDDEN"] end

local function ThemeName(key)
  local t = GG.RosterThemes.THEMES[key or GG.RosterThemes.DEFAULT]
  return t and L[t.labelKey] or tostring(key)
end

local function BossStyleName(key)
  for _, s in ipairs(GG.BossIcons.STYLES) do
    if s.key == key then return L[s.labelKey] end
  end
  return L[GG.BossIcons.STYLES[1].labelKey]
end

local function ColumnLabel(sub)
  for _, group in ipairs(GG.SettingsColumnGroups or {}) do
    for _, entry in ipairs(group.sections) do
      if entry.key == sub then return L[entry.labelKey] end
    end
  end
  return sub
end

local DIFFICULTY_KEYS = { [17] = "DIFFICULTY_LFR", [14] = "DIFFICULTY_NORMAL", [15] = "DIFFICULTY_HEROIC", [16] = "DIFFICULTY_MYTHIC" }
local LABEL_STYLE_KEYS = { cuenta = "ACCOUNT_LABEL_STYLE_CUENTA", wow = "ACCOUNT_LABEL_STYLE_WOW", alt = "ACCOUNT_LABEL_STYLE_ALT",
  number = "ACCOUNT_LABEL_STYLE_NUMBER", battletag = "ACCOUNT_LABEL_STYLE_BATTLETAG" }
local ANNOUNCE_TEXT_LABELS = { instanceReset = "OPTIONS_ANNOUNCE_INSTANCE_RESET_TEXT",
  keystoneParty = "OPTIONS_ANNOUNCE_KEYSTONE_PARTY_TEXT", keystoneGuild = "OPTIONS_ANNOUNCE_KEYSTONE_GUILD_TEXT" }

local function Percent(v) return v and ("%d%%"):format(math.floor(v * 100 + 0.5)) or "100%" end

local function Quote(s)
  if not s or s == "" then return L["PROFILE_DEFAULT_TEXT"] end
  if #s > 28 then s = s:sub(1, 26) .. "..." end
  return "\"" .. s .. "\""
end

local function ColorWord(rgb)
  if type(rgb) ~= "table" then return L["PROFILE_CUSTOM"] end
  return Paint(L["PROFILE_CUSTOM"], { rgb[1], rgb[2], rgb[3] })
end

local function Describe(e)
  local k, sub = e.key, e.sub
  if k == "theme" then return L["THEME_HEADER"], ThemeName(e.old), ThemeName(e.new) end
  if k == "themeParts" then
    local labels = GG.RosterThemes.PART_LABELS[sub] or {}
    local function v(x) return x and L[labels[x]] or L["PROFILE_THEME_DEFAULT"] end
    return labels.title and L[labels.title] or sub, v(e.old), v(e.new)
  end
  if k == "sections" then return ColumnLabel(sub), ShownHidden(e.old), ShownHidden(e.new) end
  if k == "currencyVisibility" then return L["PROFILE_HIDDEN_CURRENCIES"], tostring(e.old), tostring(e.new) end
  if k == "bossIconStyle" then return L["BOSS_STYLE_HEADER"], BossStyleName(e.old), BossStyleName(e.new) end
  if k == "raidDifficulties" then return L[DIFFICULTY_KEYS[sub]] or tostring(sub), ShownHidden(e.old), ShownHidden(e.new) end
  if k == "layoutMode" then
    local function v(x) return x == "vertical" and L["OPT_LAYOUT_COLUMNS"] or L["OPT_LAYOUT_ROWS"] end
    return L["OPT_LAYOUT"], v(e.old), v(e.new)
  end
  if k == "maxVisibleCharacters" then
    local function v(x) return x == "all" and L["OPT_SHOWN_ALL"] or tostring(x or 10) end
    return L["OPT_SHOWN"], v(e.old), v(e.new)
  end
  if k == "windowScale" then return L["OPTIONS_WINDOW_SCALE"], Percent(e.old), Percent(e.new) end
  if k == "windowOpacity" then return L["OPTIONS_WINDOW_OPACITY"], Percent(e.old), Percent(e.new) end
  if k == "lockWindow" then return L["OPT_LOCK_WINDOW"], OnOff(e.old), OnOff(e.new) end
  if k == "closeWithEsc" then return L["OPT_CLOSE_ESC"], OnOff(e.old), OnOff(e.new) end
  if k == "openOn" then
    local function v(x) return x == "last" and L["OPT_OPEN_LAST"] or L["OPT_OPEN_CHARS"] end
    return L["OPT_OPEN_ON"], v(e.old), v(e.new)
  end
  if k == "minimap" then
    if sub == "hide" then return L["OPTIONS_MINIMAP_SHOW"], OnOff(not e.old), OnOff(not e.new) end
    return L["OPTIONS_MINIMAP_LOCK"], OnOff(e.old), OnOff(e.new)
  end
  if k == "minLevel" then return L["OPTIONS_MIN_LEVEL"], tostring(e.old or "-"), tostring(e.new) end
  if k == "accentMode" then
    local function v(x)
      if x == "class" then return L["OPT_COLOR_CLASS"] end
      if x == "custom" then return L["PROFILE_CUSTOM"] end
      return L["COLOR_VIOLET"]
    end
    return L["SETTINGS_BOX_COLOR"], v(e.old), v(e.new)
  end
  if k == "accentColor" then return L["SETTINGS_BOX_COLOR"], ColorWord(e.old), ColorWord(e.new) end
  if k == "accountLabelStyle" then
    local function v(x) return L[LABEL_STYLE_KEYS[x or "cuenta"]] end
    return L["OPTIONS_ACCOUNT_LABEL_STYLE"], v(e.old), v(e.new)
  end
  if k == "announceInstanceReset" then return L["OPTIONS_ANNOUNCE_INSTANCE_RESET"], OnOff(e.old), OnOff(e.new) end
  if k == "announceKeystoneParty" then return L["OPTIONS_ANNOUNCE_KEYSTONE_PARTY"], OnOff(e.old), OnOff(e.new) end
  if k == "announceKeystoneGuild" then return L["OPTIONS_ANNOUNCE_KEYSTONE_GUILD"], OnOff(e.old), OnOff(e.new) end
  if k == "announceTexts" then return L[ANNOUNCE_TEXT_LABELS[sub]] or sub, Quote(e.old), Quote(e.new) end
  if k == "popupRosterCall" then return L["POPUP_ROSTER_CALL"], OnOff(e.old), OnOff(e.new) end
  if k == "rosterCallSound" then return L["POPUP_ROSTER_CALL_SOUND"], OnOff(e.old), OnOff(e.new) end
  if k == "rosterCallStyle" then
    local function v(x) return L["RC_STYLE_" .. string.upper(x or "band")] end
    return L["POPUP_ROSTER_CALL_STYLE"], v(e.old), v(e.new)
  end
  if k == "popupRosterCharacter" then return L["POPUP_ROSTER_CHARACTER"], OnOff(e.old), OnOff(e.new) end
  if k == "popupLockoutGroup" then return L["POPUP_LOCKOUT_GROUP"], OnOff(e.old), OnOff(e.new) end
  if k == "popupLockoutInstance" then return L["POPUP_LOCKOUT_INSTANCE"], OnOff(e.old), OnOff(e.new) end
  return k, tostring(e.old), tostring(e.new)
end

local function Tags(o)
  return {
    ThemeName(o.theme),
    BossStyleName(o.bossIconStyle),
    Percent(o.windowScale),
    o.layoutMode == "vertical" and L["OPT_LAYOUT_COLUMNS"] or L["OPT_LAYOUT_ROWS"],
  }
end

local function Ago(at)
  local s = math.max(0, GetServerTime() - (at or 0))
  if s < 60 then return L["PROFILE_UPDATED_NOW"] end
  local span
  if s < 3600 then span = ("%d min"):format(math.floor(s / 60))
  elseif s < 86400 then span = ("%d h"):format(math.floor(s / 3600))
  else span = ("%d d"):format(math.floor(s / 86400)) end
  return L["PROFILE_UPDATED"]:format(span)
end

local function Now() return GetServerTime() end

local function Complain(err)
  print("|cff8B5CF6GG|r " .. (L[err] or err))
end

local rerender

StaticPopupDialogs["GG_PROFILE_USE"] = {
  text = L["PROFILE_CONFIRM_USE"],
  button1 = ACCEPT, button2 = CANCEL,
  OnAccept = function(_, name)
    if GG.Profile.Use(GGDB, GGDB.options, name, Now()) then ReloadUI() end
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["GG_PROFILE_COPY_OTHER"] = {
  text = L["PROFILE_CONFIRM_COPY"],
  button1 = ACCEPT, button2 = CANCEL,
  OnAccept = function(_, name)
    local _, reload = GG.Profile.CreateCopy(GGDB, GGDB.options, name, Now())
    if reload then ReloadUI() elseif rerender then rerender() end
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

StaticPopupDialogs["GG_PROFILE_DELETE"] = {
  text = L["PROFILE_CONFIRM_DELETE"],
  button1 = DELETE, button2 = CANCEL,
  OnAccept = function(_, name)
    GG.Profile.Delete(GGDB, name)
    if rerender then rerender() end
  end,
  timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true, preferredIndex = 3,
}

StaticPopupDialogs["GG_PROFILE_RENAME"] = {
  text = L["PROFILE_RENAME_POPUP"],
  button1 = ACCEPT, button2 = CANCEL,
  hasEditBox = true,
  editBoxWidth = 220,
  OnShow = function(dialog, name)
    local box = dialog:GetEditBox()
    box:SetMaxLetters(GG.Profile.MAX_NAME)
    box:SetText(name or "")
    box:HighlightText()
    box:SetFocus()
  end,
  OnAccept = function(dialog, name)
    local ok, err = GG.Profile.Rename(GGDB, name, dialog:GetEditBox():GetText())
    if not ok then Complain(err) end
    if rerender then rerender() end
  end,
  EditBoxOnEnterPressed = function(box)
    local dialog = box:GetParent()
    StaticPopupDialogs["GG_PROFILE_RENAME"].OnAccept(dialog, dialog.data)
    dialog:Hide()
  end,
  EditBoxOnEscapePressed = function(box) box:GetParent():Hide() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function BuildCard(container, ctx, p, x, y, w)
  local card = CreateFrame("Frame", nil, container, "BackdropTemplate")
  card:SetPoint("TOPLEFT", x, -y)
  card:SetSize(w, CARD_H)
  if p.active then
    Backdrop(card, Fade(Theme.accent, 0.10), Theme.accent)
  else
    Backdrop(card, Fade(Theme.panel, 1), Theme.border)
  end

  local right = 10
  if p.active then
    local badge = CreateFrame("Frame", nil, card, "BackdropTemplate")
    Backdrop(badge, Theme.accent, Theme.accent)
    local bt = Text(badge, 9.5, Theme.onAccent, true)
    bt:SetPoint("CENTER")
    bt:SetText(L["PROFILE_ACTIVE"])
    badge:SetSize(TextWidth(bt) + 10, 16)
    badge:SetPoint("TOPRIGHT", -10, -10)
    right = right + badge:GetWidth() + 6
  end
  local name = Text(card, 14, Theme.textPrimary, true)
  name:SetPoint("TOPLEFT", 10, -10)
  name:SetWidth(w - 10 - right)
  name:SetText(p.name)
  local when = Text(card, 10.5, Theme.textFaint)
  when:SetPoint("TOPLEFT", 10, -30)
  when:SetText(Ago(p.at))

  local tx, ty = 10, 50
  for _, tag in ipairs(Tags(p.o)) do
    local chip = CreateFrame("Frame", nil, card, "BackdropTemplate")
    Backdrop(chip, { 1, 1, 1, 0.05 }, Theme.borderSoft)
    local t = Text(chip, 10.5, Theme.textMuted, true)
    t:SetPoint("CENTER")
    t:SetText(tag)
    local cw = math.ceil(TextWidth(t)) + 12
    if tx + cw > w - 10 and tx > 10 then tx, ty = 10, ty + 22 end
    chip:SetSize(cw, 18)
    chip:SetPoint("TOPLEFT", tx, -ty)
    tx = tx + cw + 4
  end

  local line = card:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(unpack(Theme.borderSoft))
  line:SetHeight(1)
  line:SetPoint("BOTTOMLEFT", 10, 28)
  line:SetPoint("BOTTOMRIGHT", -10, 28)
  local ax = 10
  local function Act(label, color, onClick)
    local b = LinkButton(card, label, color, onClick)
    b:SetPoint("BOTTOMLEFT", ax, 6)
    ax = ax + b:GetWidth() + 12
  end
  if not p.active then
    Act(L["PROFILE_USE"], Theme.accent, function() StaticPopup_Show("GG_PROFILE_USE", p.name, nil, p.name) end)
  end
  Act(L["PROFILE_COPY"], nil, function()
    if p.active then
      P.CreateCopy(GGDB, GGDB.options, p.name, Now())
      ctx.rerender()
    else
      StaticPopup_Show("GG_PROFILE_COPY_OTHER", p.name, nil, p.name)
    end
  end)
  Act(L["PROFILE_RENAME"], nil, function() StaticPopup_Show("GG_PROFILE_RENAME", p.name, nil, p.name) end)
  if not p.active then
    Act(L["PROFILE_DELETE"], { 0.94, 0.42, 0.42, 1 }, function() StaticPopup_Show("GG_PROFILE_DELETE", p.name, nil, p.name) end)
  end
end

function Panel:BuildList(container, y, width, ctx)
  P = GG.Profile
  rerender = ctx.rerender
  P.SaveActive(GGDB, GGDB.options, Now())

  local hint = Text(container, 11, Theme.textFaint)
  hint:SetPoint("TOPLEFT", 0, -y)
  hint:SetText(L["PROFILE_LIST_HINT"])
  local top = y + 22

  local w = math.floor((width - (CARD_COLS - 1) * CARD_GAP) / CARD_COLS)
  local list = P.List(GGDB)
  local slots = #list + 1
  for i = 1, slots do
    local col, row = (i - 1) % CARD_COLS, math.floor((i - 1) / CARD_COLS)
    local x, cy = col * (w + CARD_GAP), top + row * (CARD_H + CARD_GAP)
    if list[i] then
      BuildCard(container, ctx, list[i], x, cy, w)
    else
      local new = CreateFrame("Button", nil, container, "BackdropTemplate")
      Backdrop(new, { 0, 0, 0, 0 }, Theme.borderSoft)
      new:SetPoint("TOPLEFT", x, -cy)
      new:SetSize(w, CARD_H)
      local plus = Text(new, 24, Theme.textFaint, true)
      plus:SetPoint("CENTER", 0, 10)
      plus:SetText("+")
      local label = Text(new, 13, Theme.textFaint, true)
      label:SetPoint("CENTER", 0, -14)
      label:SetText(L["PROFILE_NEW"])
      new:SetScript("OnEnter", function() new:SetBackdropBorderColor(unpack(Theme.accent)); label:SetTextColor(unpack(Theme.textPrimary)) end)
      new:SetScript("OnLeave", function() new:SetBackdropBorderColor(unpack(Theme.borderSoft)); label:SetTextColor(unpack(Theme.textFaint)) end)
      new:SetScript("OnClick", function()
        P.CreateCopy(GGDB, GGDB.options, nil, Now())
        ctx.rerender()
      end)
    end
  end
  local rows = math.ceil(slots / CARD_COLS)
  return top + rows * CARD_H + (rows - 1) * CARD_GAP - y + 4
end

local function Chip(parent, ctx, key, on, enabled, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetHeight(30)
  local active = on and enabled
  Backdrop(b, active and Fade(Theme.accent, 0.12) or Fade(Theme.panel, 1), active and Theme.accent or Theme.border)
  local icon = SectionIcon(b, ctx, key, 14, active and Theme.accent or Theme.textFaint)
  icon:SetPoint("LEFT", 10, 0)
  local t = Text(b, 12, active and Theme.textPrimary or Theme.textFaint, true)
  t:SetPoint("LEFT", icon, "RIGHT", 7, 0)
  t:SetText(SectionName(key))
  b:SetWidth(10 + 14 + 7 + math.ceil(TextWidth(t)) + 12)
  if not enabled then b:SetAlpha(0.35) end
  b:SetScript("OnClick", function() if enabled then onClick() end end)
  return b
end

local function ChipRow(container, ctx, y, width, sel, enabledSet, onToggle)
  local x, rowY = 0, y
  for _, s in ipairs(P.SECTIONS) do
    local enabled = not enabledSet or enabledSet[s.key] == true
    local chip = Chip(container, ctx, s.key, sel[s.key] ~= false, enabled, function() onToggle(s.key) end)
    if x + chip:GetWidth() > width and x > 0 then x, rowY = 0, rowY + 38 end
    chip:SetPoint("TOPLEFT", x, -rowY)
    x = x + chip:GetWidth() + 8
  end
  return rowY + 30 - y
end

local function Segmented(container, y, ctx)
  local seg = CreateFrame("Frame", nil, container, "BackdropTemplate")
  Backdrop(seg, NAV_BG, Theme.border)
  seg:SetPoint("TOPLEFT", 0, -y)
  seg:SetHeight(28)
  local x = 2
  for _, tab in ipairs({ "export", "import" }) do
    local on = state.tab == tab
    local b = CreateFrame("Button", nil, seg)
    b:SetHeight(24)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(unpack(on and Theme.accent or { 0, 0, 0, 0 }))
    local t = Text(b, 12, on and Theme.onAccent or Theme.textMuted, true)
    t:SetPoint("CENTER")
    t:SetText(L[tab == "export" and "PROFILE_TAB_EXPORT" or "PROFILE_TAB_IMPORT"])
    local bw = math.max(80, math.ceil(TextWidth(t)) + 28)
    b:SetWidth(bw)
    b:SetPoint("LEFT", x, 0)
    x = x + bw + 2
    b:SetScript("OnClick", function() state.tab = tab; ctx.rerender() end)
  end
  seg:SetWidth(x)
  return 28
end

local function Count(set)
  local n = 0
  for _, s in ipairs(P.SECTIONS) do if set[s.key] ~= false then n = n + 1 end end
  return n
end

local function ExportPane(container, y, width, ctx)
  state.exportSel = state.exportSel or {}
  local top = y
  local hint = Text(container, 11, Theme.textFaint)
  hint:SetPoint("TOPLEFT", 0, -top)
  hint:SetText(L["PROFILE_EXPORT_HINT"]:format(P.Active(GGDB)))
  top = top + 22
  top = top + ChipRow(container, ctx, top, width, state.exportSel, nil, function(key)
    state.exportSel[key] = state.exportSel[key] == false
    state.exportText = nil
    ctx.rerender()
  end) + 12

  local n = Count(state.exportSel)
  local count = Text(container, 11, Theme.textFaint)
  count:SetPoint("TOPLEFT", 0, -top - 6)
  count:SetText(L["PROFILE_SECTIONS_COUNT"]:format(n, #P.SECTIONS))
  local make = PrimaryButton(container, L["PROFILE_CREATE_TEXT"], function()
    local set = {}
    for _, s in ipairs(P.SECTIONS) do set[s.key] = state.exportSel[s.key] ~= false end
    state.exportText = P.Export(GGDB.options, set)
    ctx.rerender()
  end)
  make:SetPoint("TOPRIGHT", container, "TOPLEFT", width, -top)
  make:SetDisabled(n == 0)
  top = top + 26 + 12

  if state.exportText then
    local box, holder = TextBox(container, width, 84)
    holder:SetPoint("TOPLEFT", 0, -top)
    local edge = holder:CreateTexture(nil, "OVERLAY")
    edge:SetColorTexture(unpack(Theme.accent))
    edge:SetPoint("TOPLEFT")
    edge:SetPoint("BOTTOMLEFT")
    edge:SetWidth(3)
    local text = state.exportText
    box:SetText(text)
    box:SetScript("OnTextChanged", function(self, userInput)
      if userInput then self:SetText(text); self:HighlightText() end
    end)
    box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    C_Timer.After(0, function() if box:IsVisible() then box:SetFocus(); box:HighlightText() end end)
    top = top + 84 + 8
    local note = Text(container, 11, Theme.textFaint)
    note:SetPoint("TOPLEFT", 0, -top - 6)
    note:SetText(L["PROFILE_TEXT_READY"])
    local all = Button(container, L["PROFILE_SELECT_ALL"], function() box:SetFocus(); box:HighlightText() end)
    all:SetPoint("TOPRIGHT", container, "TOPLEFT", width, -top)
    top = top + 26
  end
  return top - y
end

local function Track(container, y)
  local order = { "paste", "review", "save" }
  local labels = { L["PROFILE_STEP_PASTE"], L["PROFILE_STEP_REVIEW"], L["PROFILE_STEP_SAVE"] }
  local at = 1
  for i, s in ipairs(order) do if s == state.step then at = i end end
  local x = 0
  for i, label in ipairs(labels) do
    local done, now = i < at, i == at
    local box = CreateFrame("Frame", nil, container, "BackdropTemplate")
    Backdrop(box, now and Theme.accent or { 0, 0, 0, 0 }, (done or now) and Theme.accent or Theme.border)
    box:SetSize(18, 18)
    box:SetPoint("TOPLEFT", x, -y)
    local n = Text(box, 10.5, now and Theme.onAccent or (done and Theme.accent or Theme.textFaint), true)
    n:SetPoint("CENTER")
    n:SetText(tostring(i))
    local t = Text(container, 12, (now or done) and Theme.textPrimary or Theme.textFaint, true)
    t:SetPoint("LEFT", box, "RIGHT", 6, 0)
    t:SetText(label)
    x = x + 18 + 6 + math.ceil(TextWidth(t)) + 10
    if i < #labels then
      local line = container:CreateTexture(nil, "ARTWORK")
      line:SetColorTexture(unpack(Theme.border))
      line:SetSize(18, 1)
      line:SetPoint("TOPLEFT", x, -y - 9)
      x = x + 28
    end
  end
  return 18
end

local function PastePane(container, y, width, ctx)
  local top = y
  local box, holder = TextBox(container, width, 120)
  holder:SetPoint("TOPLEFT", 0, -top)
  box:SetText(state.pasted)
  top = top + 120 + 8
  local status = Text(container, 11.5, Theme.textFaint)
  status:SetPoint("TOPLEFT", 0, -top)
  status:SetWidth(width)
  top = top + 22
  local nextBtn = PrimaryButton(container, L["PROFILE_NEXT_REVIEW"], function()
    if not state.decoded then return end
    state.step = "review"
    ctx.rerender()
  end)
  nextBtn:SetPoint("TOPRIGHT", container, "TOPLEFT", width, -top)

  local function Check(text)
    state.pasted = text
    local clean, n, version, present = P.Decode(text, GGDB.options)
    state.decoded = clean and { clean = clean, n = n, version = version, present = present } or nil
    nextBtn:SetDisabled(state.decoded == nil)
    if clean then
      local sections = 0
      for _ in pairs(present) do sections = sections + 1 end
      status:SetTextColor(unpack(Theme.success))
      status:SetText(L["PROFILE_READY"]:format(version, sections))
      state.importSel = {}
      for key in pairs(present) do state.importSel[key] = true end
    elseif text:gsub("%s", "") == "" then
      status:SetText("")
    else
      status:SetTextColor(unpack(Theme.danger))
      status:SetText(L[n] or L["PROFILE_ERR_BROKEN"])
    end
  end
  Check(state.pasted)
  box:SetScript("OnTextChanged", function(self) Check(self:GetText()) end)
  return top + 26 - y
end

local function ReviewPane(container, y, width, ctx)
  local d = state.decoded
  local active = P.Active(GGDB)
  local diff = P.Diff(GGDB.options, d.clean)
  local top = y
  local hint = Text(container, 11, Theme.textFaint)
  hint:SetPoint("TOPLEFT", 0, -top)
  hint:SetText(L["PROFILE_REVIEW_HINT"]:format(active))
  top = top + 24

  local left = 190
  for i, s in ipairs(P.SECTIONS) do
    local has = d.present[s.key] == true
    local on = has and state.importSel[s.key] == true
    local entries = diff[s.key] or {}
    local lines = {}
    if not has then
      lines[1] = Paint(L["PROFILE_NOT_IN_TEXT"]:format(active), Theme.textFaint)
    elseif #entries == 0 then
      lines[1] = Paint(L["PROFILE_NO_CHANGES"], Theme.textFaint)
    else
      for j, e in ipairs(entries) do
        if j > MAX_DIFF_LINES then
          lines[#lines + 1] = Paint(L["PROFILE_MORE"]:format(#entries - MAX_DIFF_LINES), Theme.textFaint)
          break
        end
        local label, old, new = Describe(e)
        lines[#lines + 1] = Paint(label .. ":", Theme.textFaint) .. "  " .. Paint(old, { 0.45, 0.47, 0.53 }) ..
          Paint("  >  ", Theme.textFaint) .. Paint(new, Theme.textPrimary)
      end
    end
    local rowH = math.max(30, #lines * 16 + 14)
    local row = CreateFrame("Button", nil, container, "BackdropTemplate")
    row:SetPoint("TOPLEFT", 0, -top)
    row:SetSize(width, rowH)
    Backdrop(row, i % 2 == 0 and { 1, 1, 1, 0.025 } or { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    local check = CreateFrame("Frame", nil, row, "BackdropTemplate")
    Backdrop(check, NAV_BG, on and Theme.accent or Theme.border)
    check:SetSize(16, 16)
    check:SetPoint("TOPLEFT", 10, -7)
    if on then
      local fill = check:CreateTexture(nil, "ARTWORK")
      fill:SetColorTexture(unpack(Theme.accent))
      fill:SetPoint("TOPLEFT", 3, -3)
      fill:SetPoint("BOTTOMRIGHT", -3, 3)
    end
    local icon = SectionIcon(row, ctx, s.key, 14, on and Theme.textPrimary or Theme.textFaint)
    icon:SetPoint("LEFT", check, "RIGHT", 10, 0)
    local name = Text(row, 13, on and Theme.textPrimary or Theme.textFaint, true)
    name:SetPoint("LEFT", icon, "RIGHT", 7, 0)
    name:SetText(SectionName(s.key))
    local body = Text(row, 11.5, Theme.textMuted)
    body:SetWordWrap(true)
    body:SetSpacing(4)
    body:SetPoint("TOPLEFT", left, -8)
    body:SetWidth(width - left - 10)
    body:SetText(table.concat(lines, "\n"))
    if not has then row:SetAlpha(0.5) end
    row:SetScript("OnClick", function()
      if not has then return end
      state.importSel[s.key] = not state.importSel[s.key]
      ctx.rerender()
    end)
    top = top + rowH
  end

  top = top + 12
  local back = Button(container, L["PROFILE_BACK"], function() state.step = "paste"; ctx.rerender() end)
  back:SetPoint("TOPLEFT", 0, -top)
  local any = false
  for key in pairs(d.present) do if state.importSel[key] then any = true end end
  local nextBtn = PrimaryButton(container, L["PROFILE_NEXT_NAME"], function() state.step = "save"; ctx.rerender() end)
  nextBtn:SetPoint("TOPRIGHT", container, "TOPLEFT", width, -top)
  nextBtn:SetDisabled(not any)
  return top + 26 - y
end

local function SavePane(container, y, width, ctx)
  local d = state.decoded
  local active = P.Active(GGDB)
  local top = y
  local label = Text(container, 12, Theme.textMuted, true)
  label:SetPoint("TOPLEFT", 0, -top)
  label:SetText(L["PROFILE_NAME_LABEL"])
  top = top + 20
  local holder = CreateFrame("Frame", nil, container, "BackdropTemplate")
  Backdrop(holder, NAV_BG)
  holder:SetPoint("TOPLEFT", 0, -top)
  holder:SetSize(math.min(360, width), 30)
  local box = CreateFrame("EditBox", nil, holder)
  box:SetAutoFocus(false)
  box:SetMaxLetters(P.MAX_NAME)
  box:SetFontObject("ChatFontNormal")
  box:SetFont(Theme.fontBold, 13, "")
  box:SetTextColor(unpack(Theme.textPrimary))
  box:SetTextInsets(8, 8, 0, 0)
  box:SetAllPoints()
  box:SetText(state.name)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  top = top + 30 + 6
  local err = Text(container, 11, Theme.danger)
  err:SetPoint("TOPLEFT", 0, -top)
  top = top + 20

  local picked = {}
  for _, s in ipairs(P.SECTIONS) do
    if d.present[s.key] and state.importSel[s.key] then picked[#picked + 1] = SectionName(s.key) end
  end
  local recapBox = CreateFrame("Frame", nil, container, "BackdropTemplate")
  Backdrop(recapBox, NAV_BG, Theme.borderSoft)
  recapBox:SetPoint("TOPLEFT", 0, -top)
  local recap = Text(recapBox, 12, Theme.textMuted)
  recap:SetWordWrap(true)
  recap:SetPoint("TOPLEFT", 12, -10)
  recap:SetWidth(width - 24)
  top = top + 4

  local save
  local function Update()
    local name, e = P.ValidateName(GGDB, state.name)
    err:SetText(e and L[e] or "")
    save:SetDisabled(name == nil)
    local white = function(t) return Paint(t, Theme.textPrimary) end
    recap:SetText(L["PROFILE_RECAP"]:format(white(name or "..."), white(table.concat(picked, ", ")), white(active)))
    recapBox:SetSize(width, recap:GetStringHeight() + 20)
  end
  save = PrimaryButton(container, L["PROFILE_SAVE_RELOAD"], function()
    local name, e = P.ImportAsNew(GGDB, GGDB.options, d.clean, state.importSel, state.name, Now())
    if not name then Complain(e); return end
    ReloadUI()
  end)
  box:SetScript("OnTextChanged", function(self) state.name = self:GetText(); Update() end)
  box:SetScript("OnEnterPressed", function() if P.ValidateName(GGDB, state.name) then save:Click() end end)
  Update()
  top = top + recapBox:GetHeight() + 14

  local back = Button(container, L["PROFILE_BACK"], function() state.step = "review"; ctx.rerender() end)
  back:SetPoint("TOPLEFT", 0, -top)
  save:SetPoint("TOPRIGHT", container, "TOPLEFT", width, -top)
  C_Timer.After(0, function() if box:IsVisible() and state.name == "" then box:SetFocus() end end)
  return top + 26 - y
end

function Panel:BuildShare(container, y, width, ctx)
  P = GG.Profile
  rerender = ctx.rerender
  local top = y + Segmented(container, y, ctx) + 16
  if state.tab == "export" then
    top = top + ExportPane(container, top, width, ctx)
  else
    if not state.decoded then state.step = "paste" end
    top = top + Track(container, top) + 16
    if state.step == "paste" then
      top = top + PastePane(container, top, width, ctx)
    elseif state.step == "review" then
      top = top + ReviewPane(container, top, width, ctx)
    else
      top = top + SavePane(container, top, width, ctx)
    end
  end
  return top - y + 4
end
