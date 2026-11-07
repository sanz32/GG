local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

local Theme = GG.Theme
local Widgets = GG.Widgets

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

local SIDEBAR_WIDTH = 150
local CONTENT_PADDING = 16
local SCROLLBAR_GUTTER = 20
local ROW_GAP = 14
local PREVIEW_HEIGHT = 160
local SIDE_PREVIEW_WIDTH = 290
local BOX_PADDING = 14
local BOX_TITLE_HEIGHT = 36
local BOX_GAP = 14
local NAV_BG = { 0.063, 0.071, 0.090, 1 }
local SETTINGS_WIDTH = 1300
local SETTINGS_WIDTH_SIDE_PREVIEW = 1560
local TOOLBAR_HEIGHT = 30
local SLIDER_MAX_WIDTH = 420
local TEXTBOX_MAX_WIDTH = 600

local panelFrame, contentClip, contentInner, contentScrollbar, toolbar
local previewFrame, previewInner
local previewBottomFrame, previewBottomInner, previewSideFrame, previewSideInner
local sidebarButtons = {}
local activeCategory
local scrollOffset = 0
local activePreviewRefresh

local UpdateScrollBounds
local ClearContent
local ClearPreview
local RenderFields
local RenderFieldList
local RenderField
local RerenderActiveFields
local SelectCategory
local BuildSidebar
local BuildPanel

local CATEGORIES

local function AddToggleRow(container, y, width, field, xOffset)
  xOffset = xOffset or 0
  local label = CreateLabel(container, 12, Theme.textPrimary, true)
  label:SetPoint("TOPLEFT", xOffset, -y)
  label:SetText(field.label)

  local toggle = Widgets.CreateSwitch(container, field.get(), field.set)
  toggle:SetPoint("TOPLEFT", container, "TOPLEFT", xOffset + label:GetStringWidth() + 16, -y + 3)

  local button
  if field.buttonText then
    button = Widgets.CreateButton(container, field.buttonText, field.onClick)
  end

  local height = 22
  if field.desc and field.desc ~= "" then
    local desc = CreateLabel(container, 11, Theme.textFaint)
    desc:SetWordWrap(true)
    desc:SetWidth(width - 50)
    desc:SetPoint("TOPLEFT", xOffset, -y - 22)
    desc:SetText(field.desc)
    height = 22 + desc:GetStringHeight() + 4
  end
  if field.note and field.note ~= "" then
    local note = CreateLabel(container, 11, Theme.danger)
    note:SetWordWrap(true)
    note:SetWidth(width - 50)
    note:SetPoint("TOPLEFT", xOffset, -y - height)
    note:SetText(field.note)
    height = height + note:GetStringHeight() + 4
  end
  if button then button:SetPoint("RIGHT", container, "TOPRIGHT", 0, -(y + (height - 4) / 2)) end
  return height
end

local CHIP_HEIGHT = 34
local CHIP_PADDING = 10

local function AddToggleChip(container, x, y, width, field)
  local chip = CreateFrame("Frame", nil, container)
  chip:SetSize(width, CHIP_HEIGHT)
  chip:SetPoint("TOPLEFT", x, -y)

  local bg = chip:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, 1)
  local edges = {}
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local line = chip:CreateTexture(nil, "BORDER")
    if side == "TOP" or side == "BOTTOM" then
      line:SetPoint(side .. "LEFT"); line:SetPoint(side .. "RIGHT"); line:SetHeight(1)
    else
      line:SetPoint("TOP" .. side); line:SetPoint("BOTTOM" .. side); line:SetWidth(1)
    end
    edges[#edges + 1] = line
  end
  local function PaintChip(on)
    local a = Theme.accent
    if on then
      bg:SetGradient("HORIZONTAL", CreateColor(a[1], a[2], a[3], 0.20), CreateColor(a[1], a[2], a[3], 0.03))
    else
      bg:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0.03), CreateColor(1, 1, 1, 0.03))
    end
    for _, line in ipairs(edges) do
      if on then line:SetColorTexture(a[1], a[2], a[3], 0.6) else line:SetColorTexture(unpack(Theme.border)) end
    end
  end
  PaintChip(field.get())

  local iconSize, iconGap = 14, 5
  local labelX = CHIP_PADDING
  if field.icon then
    local icon = chip:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    icon:SetPoint("LEFT", CHIP_PADDING, 0)
    GG.Widgets.SetItemIcon(icon, field.icon)
    labelX = labelX + iconSize + iconGap
  end

  local label = CreateLabel(chip, 12, Theme.textPrimary, true)
  label:SetPoint("LEFT", labelX, 0)
  label:SetWidth(width - labelX - CHIP_PADDING - 46)
  label:SetWordWrap(false)
  label:SetText(field.label)

  local toggle = Widgets.CreateSwitch(chip, field.get(), function(v)
    PaintChip(v)
    field.set(v)
  end)
  toggle:SetPoint("RIGHT", -CHIP_PADDING + 2, 0)

  return CHIP_HEIGHT
end

local EXPANDER_HEIGHT = 26

local function AddExpanderRow(container, y, width, field)
  local btn = CreateFrame("Button", nil, container)
  btn:SetSize(width, EXPANDER_HEIGHT)
  btn:SetPoint("TOPLEFT", 0, -y)

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(1, 1, 1, 0.05)

  local arrow = CreateLabel(btn, 10, Theme.textFaint, true)
  arrow:SetPoint("LEFT", CHIP_PADDING, 0)
  arrow:SetText(field.expanded and "v" or ">")

  local label = CreateLabel(btn, 12, Theme.textPrimary, true)
  label:SetPoint("LEFT", arrow, "RIGHT", 7, 0)
  label:SetText(field.label)

  local count = CreateLabel(btn, 11, Theme.textFaint)
  count:SetPoint("RIGHT", -CHIP_PADDING, 0)
  count:SetText(field.countText or "")

  btn:SetScript("OnEnter", function() bg:SetColorTexture(1, 1, 1, 0.09) end)
  btn:SetScript("OnLeave", function() bg:SetColorTexture(1, 1, 1, 0.05) end)
  btn:SetScript("OnClick", function()
    if field.onToggle then field.onToggle() end
  end)

  return EXPANDER_HEIGHT
end

local SECTION_HEADER_HEIGHT = 24

local ANNOUNCE_CAPTION_HEIGHT = 14
local ANNOUNCE_CAPTION_GAP = 4

local function AddSectionHeader(container, y, width, field)
  local label = CreateLabel(container, 11, Theme.textMuted, true)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(field.label)

  local divider = container:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", 0, -y - 16)
  divider:SetPoint("TOPRIGHT", 0, -y - 16)
  divider:SetHeight(1)
  divider:SetColorTexture(unpack(Theme.borderSoft))

  return SECTION_HEADER_HEIGHT
end

local function AddSliderRow(container, y, width, field)
  local label = CreateLabel(container, 12, Theme.textPrimary, true)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(field.label)

  local sliderWidth = math.min(width, SLIDER_MAX_WIDTH)
  local valueLabel = CreateLabel(container, 11, Theme.textFaint)
  valueLabel:SetPoint("TOPRIGHT", container, "TOPLEFT", sliderWidth, -y)

  local function Format(value)
    return field.format and field.format(value) or tostring(value)
  end

  local slider = Widgets.CreateSlider(container, {
    min = field.min,
    max = field.max,
    step = field.step,
    value = field.get(),
    width = sliderWidth - 8,
    onChange = function(value)
      valueLabel:SetText(Format(value))
      field.set(value)
    end,
  })
  slider:SetPoint("TOPLEFT", 4, -y - 22)
  valueLabel:SetText(Format(field.get()))

  local height = 22 + 16
  if field.desc and field.desc ~= "" then
    local desc = CreateLabel(container, 11, Theme.textFaint)
    desc:SetWordWrap(true)
    desc:SetWidth(width)
    desc:SetPoint("TOPLEFT", 0, -y - 42)
    desc:SetText(field.desc)
    height = 42 + desc:GetStringHeight() + 4
  end
  return height
end

local function AddDropdownRow(container, y, width, field)
  local label = CreateLabel(container, 12, Theme.textPrimary, true)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(field.label)

  local dropdown = Widgets.CreateDropdown(container, {
    values = field.values,
    get = field.get,
    set = field.set,
    width = math.min(260, width),
  })
  dropdown:SetPoint("TOPLEFT", 0, -y - 20)

  local height = 20 + 24
  if field.desc and field.desc ~= "" then
    local desc = CreateLabel(container, 11, Theme.textFaint)
    desc:SetWordWrap(true)
    desc:SetWidth(width)
    desc:SetPoint("TOPLEFT", 0, -y - 48)
    desc:SetText(field.desc)
    height = 48 + desc:GetStringHeight() + 4
  end
  return height
end

local function AddInfoButtonRow(container, y, width, field)
  local label = CreateLabel(container, 12, Theme.textPrimary)
  label:SetWordWrap(true)
  label:SetWidth(width)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(field.label())
  local labelHeight = label:GetStringHeight()

  local button = Widgets.CreateButton(container, field.buttonText, field.onClick)
  button:SetPoint("TOPLEFT", 0, -y - labelHeight - 6)
  if field.disabled then button:SetDisabled(field.disabled()) end

  local height = labelHeight + 6 + 24
  if field.desc and field.desc ~= "" then
    local desc = CreateLabel(container, 11, Theme.textFaint)
    desc:SetWordWrap(true)
    desc:SetWidth(width)
    desc:SetPoint("TOPLEFT", 0, -y - labelHeight - 6 - 28)
    desc:SetText(field.desc)
    height = height + 4 + desc:GetStringHeight()
  end
  return height
end

local function AddTextboxRow(container, y, width, field)
  local label = CreateLabel(container, 12, Theme.textPrimary, true)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(field.label)

  local descHeight = 0
  if field.desc and field.desc ~= "" then
    local desc = CreateLabel(container, 11, Theme.textFaint)
    desc:SetWordWrap(true)
    desc:SetWidth(width)
    desc:SetPoint("TOPLEFT", 0, -y - 18)
    desc:SetText(field.desc)
    descHeight = desc:GetStringHeight() + 6
  end

  local boxHeight = field.boxHeight or 54
  local boxTop = y + 18 + descHeight
  local box = CreateFrame("EditBox", nil, container, "BackdropTemplate")
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetFontObject("ChatFontNormal")
  box:SetFont(Theme.font, 11, "")
  box:SetTextColor(unpack(Theme.textPrimary))
  ApplyBackdrop(box, NAV_BG, Theme.border)
  box:SetTextInsets(7, 7, 6, 6)
  box:SetPoint("TOPLEFT", 0, -boxTop)
  box:SetWidth(math.min(width, TEXTBOX_MAX_WIDTH))
  box:SetHeight(boxHeight)
  box:SetText(field.get())
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEditFocusLost", function(self) field.set(self:GetText()) end)

  return 18 + descHeight + boxHeight
end

local function AddProfileRow(container, y, width, field)
  if not GG.Profile or not GG.ProfilePanel then
    if field.type ~= "profile-list" then return 0 end
    local note = CreateLabel(container, 12, Theme.textMuted)
    note:SetWordWrap(true)
    note:SetWidth(width)
    note:SetPoint("TOPLEFT", 0, -y)
    note:SetText(L["PROFILE_NEEDS_RESTART"])
    return note:GetStringHeight() + 4
  end
  local icons = {}
  for _, c in ipairs(CATEGORIES) do icons[c.key] = { icon = c.icon, tint = c.tint } end
  local ctx = { icons = icons, rerender = RerenderActiveFields }
  if field.type == "profile-list" then return GG.ProfilePanel:BuildList(container, y, width, ctx) end
  return GG.ProfilePanel:BuildShare(container, y, width, ctx)
end

local STYLE_CARD_W, STYLE_CARD_H, STYLE_CARD_GAP = 168, 86, 10
local STYLE_CARD_MIN_W = 140
local STYLE_SAMPLE_KILLS = { true, true, true, true, true, true, false, false, true, true }

local function AddBossStyleRow(container, y, width, field)
  local current = field.get()
  local count = #GG.BossIcons.STYLES
  local cardW = STYLE_CARD_W
  local cols = math.max(1, math.floor((width + STYLE_CARD_GAP) / (STYLE_CARD_W + STYLE_CARD_GAP)))
  if cols < count then
    local fitW = math.floor((width - (count - 1) * STYLE_CARD_GAP) / count)
    if fitW >= STYLE_CARD_MIN_W then
      cols, cardW = count, fitW
    else
      cols = math.ceil(count / math.ceil(count / cols))
    end
  end
  local total = 0
  for _, raid in ipairs(GG.Season.RAIDS or {}) do total = total + (raid.numEncounters or 0) end
  total = math.max(total, 1)
  local heroic = { 0.64, 0.21, 0.93, 1 }

  for index, style in ipairs(GG.BossIcons.STYLES) do
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    local selected = style.key == current

    local card = CreateFrame("Button", nil, container)
    card:SetSize(cardW, STYLE_CARD_H)
    card:SetPoint("TOPLEFT", col * (cardW + STYLE_CARD_GAP), -(y + row * (STYLE_CARD_H + STYLE_CARD_GAP)))

    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, selected and 0.07 or 0.035)
    local border = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local line = card:CreateTexture(nil, "BORDER")
      line:SetColorTexture(unpack(selected and Theme.accent or Theme.borderSoft))
      if side == "TOP" or side == "BOTTOM" then
        line:SetPoint(side .. "LEFT"); line:SetPoint(side .. "RIGHT"); line:SetHeight(selected and 2 or 1)
      else
        line:SetPoint("TOP" .. side); line:SetPoint("BOTTOM" .. side); line:SetWidth(selected and 2 or 1)
      end
      table.insert(border, line)
    end

    local label = CreateLabel(card, 12, selected and Theme.textPrimary or Theme.textMuted, true)
    label:SetPoint("TOPLEFT", 10, -8)
    label:SetText(L[style.labelKey])

    local previewW, previewH = cardW - 20, 40
    local size, positions
    if GG.BossIcons:IsInterlocking(style.key) then
      size, positions = GG.BossIcons:Interlock(total, previewW, previewH, 18, GG.BossIcons:PixelsPerUnit(card))
    else
      size, positions = GG.BossIcons:Honeycomb(total, previewW, previewH, 15, 2)
    end
    for i, pos in ipairs(positions) do
      local icon = GG.BossIcons:Create(card)
      icon:SetSize(size, size)
      icon:SetPoint("TOPLEFT", card, "TOPLEFT", 10 + pos.x, -(34 + pos.y))
      GG.BossIcons:Paint(icon, STYLE_SAMPLE_KILLS[(i - 1) % #STYLE_SAMPLE_KILLS + 1], heroic,
        i, GG.BossIcons:LetterForSlot(i), style.key)
    end

    card:SetScript("OnEnter", function() if not selected then bg:SetColorTexture(1, 1, 1, 0.06) end end)
    card:SetScript("OnLeave", function() if not selected then bg:SetColorTexture(1, 1, 1, 0.035) end end)
    card:SetScript("OnClick", function()
      if selected then return end
      field.set(style.key)
      C_Timer.After(0, field.rerender or RerenderActiveFields)
    end)
  end

  local rows = math.ceil(#GG.BossIcons.STYLES / cols)
  return rows * STYLE_CARD_H + (rows - 1) * STYLE_CARD_GAP
end

local CALL_CARD = { MIN_W = 150, H = 96, GAP = 10, PREVIEW_H = 62 }

local function PaintRosterCallPreview(card, style, x0, y0, W, H)
  local green, teal, dark, grey, white = Theme.success, Theme.teal, Theme.background, Theme.textFaint, Theme.textPrimary
  local function Rect(x, y, w, h, c, a, sub)
    local t = card:CreateTexture(nil, "ARTWORK", nil, sub or 2)
    t:SetColorTexture(c[1], c[2], c[3], a or 1)
    t:SetPoint("TOPLEFT", card, "TOPLEFT", x0 + x, -(y0 + y))
    t:SetSize(w, h)
    return t
  end
  local function Title(x, y, rest)
    Rect(x, y, 5, 4, green)
    Rect(x + 7, y, 8, 4, teal)
    Rect(x + 17, y, rest, 4, white, 0.85)
  end
  local function Frame(x, y, w, h, border)
    Rect(x, y, w, h, dark, 1, 0)
    Rect(x, y, w, 1, border, 1, 1)
    Rect(x, y + h - 1, w, 1, border, 1, 1)
    Rect(x, y, 1, h, border, 1, 1)
    Rect(x + w - 1, y, 1, h, border, 1, 1)
  end

  Rect(0, 0, W, H, { 1, 1, 1 }, 0.04, 0)
  if style == "band" then
    local y, h = math.floor(H * 0.2), 22
    Rect(0, y, W, h, dark, 0.97, 0)
    Rect(0, y, W, 1, green, 1, 1)
    Rect(0, y + h - 1, W, 1, green, 1, 1)
    local x = math.floor(W / 2) - 52
    Rect(x, y + 6, 22, 2, grey)
    Title(x, y + 11, 22)
    Rect(x + 45, y + 5, 36, 12, green)
    Rect(x + 86, y + 10, 12, 2, grey)
  elseif style == "match" then
    local w, h = math.min(84, W - 12), 50
    local x, y = math.floor((W - w) / 2), 5
    Frame(x, y, w, h, green)
    Rect(x + 6, y + 5, 22, 2, grey)
    Title(x + 6, y + 10, 34)
    Rect(x + 6, y + 18, 40, 3, green)
    Rect(x + 47, y + 18, w - 53, 3, Theme.border)
    Rect(x + 6, y + 25, w - 12, 14, green)
    Rect(x + 6, y + 44, 22, 2, grey)
    Rect(x + w - 18, y + 44, 12, 2, grey)
  elseif style == "ring" then
    local size = 42
    local x, y = math.floor((W - size) / 2), 3
    local disc = card:CreateTexture(nil, "ARTWORK", nil, 0)
    disc:SetTexture(GG.RosterCall.DISC_TEXTURE)
    disc:SetVertexColor(dark[1], dark[2], dark[3], 1)
    disc:SetPoint("TOPLEFT", card, "TOPLEFT", x0 + x, -(y0 + y))
    disc:SetSize(size, size)
    local ring = card:CreateTexture(nil, "ARTWORK", nil, 1)
    ring:SetTexture(GG.RosterCall.RING_TEXTURE)
    ring:SetVertexColor(green[1], green[2], green[3], 1)
    ring:SetAllPoints(disc)
    Rect(x + 13, y + 12, 16, 7, teal)
    Rect(x + 12, y + 22, 18, 2, white, 0.7)
    Rect(x + 11, y + 27, 20, 3, green)
    Rect(x + 3, y + size + 3, size - 6, 6, dark, 1, 1)
    Rect(x + 8, y + size + 5, size - 16, 2, grey)
    Rect(x + 13, y + size + 11, size - 26, 3, dark, 1, 1)
  else
    local w, h = 62, 36
    local x, y = W - w - 5, math.floor(H * 0.24)
    Rect(x, y, w, h, dark, 1, 0)
    Rect(x, y, 2, h, green, 1, 1)
    Rect(x + 6, y + 4, 16, 2, grey)
    Rect(x + w - 13, y + 4, 9, 2, grey)
    Title(x + 6, y + 9, 26)
    Rect(x + 6, y + 16, 30, 2, green)
    Rect(x + 37, y + 16, w - 42, 2, Theme.border)
    Rect(x + 6, y + 21, w - 11, 11, green)
  end
end

local function AddRosterCallStyleRow(container, y, width, field)
  local label = CreateLabel(container, 12, Theme.textPrimary, true)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(field.label)
  local desc = CreateLabel(container, 11, Theme.textFaint)
  desc:SetWordWrap(true)
  desc:SetWidth(width)
  desc:SetPoint("TOPLEFT", 0, -y - 18)
  desc:SetText(field.desc or "")
  local top = y + 18 + desc:GetStringHeight() + 8

  local current = field.get()
  local styles = field.values()
  local gap = CALL_CARD.GAP
  local cols = math.max(1, math.min(#styles, math.floor((width + gap) / (CALL_CARD.MIN_W + gap))))
  if cols < #styles then cols = math.ceil(#styles / math.ceil(#styles / cols)) end
  local cardW = math.floor((width - (cols - 1) * gap) / cols)

  for index, style in ipairs(styles) do
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    local selected = style.key == current

    local card = CreateFrame("Button", nil, container)
    card:SetSize(cardW, CALL_CARD.H)
    card:SetPoint("TOPLEFT", col * (cardW + gap), -(top + row * (CALL_CARD.H + gap)))

    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, selected and 0.07 or 0.035)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local line = card:CreateTexture(nil, "BORDER")
      line:SetColorTexture(unpack(selected and Theme.accent or Theme.borderSoft))
      if side == "TOP" or side == "BOTTOM" then
        line:SetPoint(side .. "LEFT"); line:SetPoint(side .. "RIGHT"); line:SetHeight(selected and 2 or 1)
      else
        line:SetPoint("TOP" .. side); line:SetPoint("BOTTOM" .. side); line:SetWidth(selected and 2 or 1)
      end
    end

    local name = CreateLabel(card, 12, selected and Theme.textPrimary or Theme.textMuted, true)
    name:SetPoint("TOPLEFT", 8, -7)
    name:SetText(style.label)

    PaintRosterCallPreview(card, style.key, 8, 26, cardW - 16, CALL_CARD.PREVIEW_H)

    card:SetScript("OnEnter", function() if not selected then bg:SetColorTexture(1, 1, 1, 0.06) end end)
    card:SetScript("OnLeave", function() if not selected then bg:SetColorTexture(1, 1, 1, 0.035) end end)
    card:SetScript("OnClick", function()
      if selected then return end
      field.set(style.key)
      C_Timer.After(0, field.rerender or RerenderActiveFields)
    end)
  end

  local rows = math.ceil(#styles / cols)
  return (top - y) + rows * CALL_CARD.H + (rows - 1) * gap
end

local THEME_CARD = { MIN_W = 200, H = 66, GAP = 10 }

local function AddThemePickerRow(container, y, width, field)
  local RT = GG.RosterThemes
  local current = field.get()
  local count = #RT.ORDER
  local gap = THEME_CARD.GAP
  local cols = math.max(1, math.min(count, math.floor((width + gap) / (THEME_CARD.MIN_W + gap))))
  if cols < count then cols = math.ceil(count / math.ceil(count / cols)) end
  local cardW = math.floor((width - (cols - 1) * gap) / cols)
  local a = Theme.accent

  for index, key in ipairs(RT.ORDER) do
    local theme = RT.THEMES[key]
    local col = (index - 1) % cols
    local row = math.floor((index - 1) / cols)
    local selected = key == current
    local available = theme.implemented == true

    local card = CreateFrame("Button", nil, container)
    card:SetSize(cardW, THEME_CARD.H)
    card:SetPoint("TOPLEFT", col * (cardW + gap), -(y + row * (THEME_CARD.H + gap)))

    local bg = card:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    local function PaintBg(hover)
      if selected then
        bg:SetColorTexture(a[1], a[2], a[3], 0.10)
      else
        bg:SetColorTexture(1, 1, 1, hover and 0.06 or 0.035)
      end
    end
    PaintBg(false)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local line = card:CreateTexture(nil, "BORDER")
      line:SetColorTexture(unpack(selected and Theme.accent or Theme.borderSoft))
      if side == "TOP" or side == "BOTTOM" then
        line:SetPoint(side .. "LEFT"); line:SetPoint(side .. "RIGHT"); line:SetHeight(selected and 2 or 1)
      else
        line:SetPoint("TOP" .. side); line:SetPoint("BOTTOM" .. side); line:SetWidth(selected and 2 or 1)
      end
    end

    local name = CreateLabel(card, 13, selected and Theme.textPrimary or Theme.textMuted, true)
    name:SetPoint("TOPLEFT", 12, -10)
    name:SetText(("%d · %s"):format(index, L[theme.labelKey]))

    local blurb = CreateLabel(card, 11, Theme.textFaint)
    blurb:SetWordWrap(true)
    if blurb.SetMaxLines then blurb:SetMaxLines(2) end
    blurb:SetJustifyV("TOP")
    blurb:SetWidth(cardW - 24)
    blurb:SetPoint("TOPLEFT", 12, -30)
    blurb:SetText(L[theme.descKey])

    if not available then
      card:SetAlpha(0.55)
      local soon = CreateLabel(card, 10, Theme.gold, true)
      soon:SetPoint("TOPRIGHT", -10, -12)
      soon:SetText(L["THEME_SOON"])
    end

    card:SetScript("OnEnter", function() if not selected and available then PaintBg(true) end end)
    card:SetScript("OnLeave", function() PaintBg(false) end)
    card:SetScript("OnClick", function()
      if selected or not available then return end
      field.set(key)
      C_Timer.After(0, field.rerender or RerenderActiveFields)
    end)
  end

  local rows = math.ceil(count / cols)
  return rows * THEME_CARD.H + (rows - 1) * gap
end

local function FlatBox(frame, bg, border)
  local fill = frame:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(unpack(bg))
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetColorTexture(unpack(border))
    if side == "TOP" or side == "BOTTOM" then
      line:SetPoint(side .. "LEFT"); line:SetPoint(side .. "RIGHT"); line:SetHeight(1)
    else
      line:SetPoint("TOP" .. side); line:SetPoint("BOTTOM" .. side); line:SetWidth(1)
    end
  end
end

local function AddRowDesc(container, y, width, field, top)
  if not (field.desc and field.desc ~= "") then return top end
  local desc = CreateLabel(container, 11, Theme.textFaint)
  desc:SetWordWrap(true)
  desc:SetWidth(width - 50)
  desc:SetPoint("TOPLEFT", 0, -y - top)
  desc:SetText(field.desc)
  return top + desc:GetStringHeight() + 4
end

local function AddSegmentedRow(container, y, width, field)
  local label = CreateLabel(container, 12, Theme.textPrimary, true)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(field.label)

  local seg = CreateFrame("Frame", nil, container)
  FlatBox(seg, NAV_BG, Theme.border)
  seg:SetHeight(26)
  local labelSpace = (field.label and field.label ~= "") and (label:GetStringWidth() + 16) or 0
  seg:SetPoint("TOPLEFT", container, "TOPLEFT", labelSpace, -y + 6)
  local buttons = {}
  local function Paint(key)
    for _, b in ipairs(buttons) do
      local active = b.key == key
      b.active = active
      b.bg:SetColorTexture(unpack(active and Theme.accent or { 0, 0, 0, 0 }))
      b.label:SetTextColor(unpack(active and Theme.onAccent or Theme.textMuted))
    end
  end
  local x = 2
  for _, option in ipairs(field.values) do
    local b = CreateFrame("Button", nil, seg)
    b:SetHeight(22)
    b.bg = b:CreateTexture(nil, "ARTWORK")
    b.bg:SetAllPoints()
    b.label = CreateLabel(b, 11.5, Theme.textMuted, true)
    b.label:SetPoint("CENTER")
    b.label:SetText(option.label)
    local w = math.max(40, b.label:GetStringWidth() + 22)
    b:SetWidth(w)
    b:SetPoint("LEFT", seg, "LEFT", x, 0)
    x = x + w + 2
    b.key = option.key
    b:SetScript("OnClick", function()
      Paint(option.key)
      field.set(option.key)
    end)
    b:SetScript("OnEnter", function(self) if not self.active then self.bg:SetColorTexture(1, 1, 1, 0.06) end end)
    b:SetScript("OnLeave", function(self) if not self.active then self.bg:SetColorTexture(0, 0, 0, 0) end end)
    table.insert(buttons, b)
  end
  seg:SetWidth(x)
  Paint(field.get())
  return AddRowDesc(container, y, width, field, 28)
end

local function AddStepperRow(container, y, width, field)
  local label = CreateLabel(container, 12, Theme.textPrimary, true)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(field.label)

  local box = CreateFrame("Frame", nil, container)
  FlatBox(box, NAV_BG, Theme.border)
  box:SetSize(124, 26)
  local labelSpace = (field.label and field.label ~= "") and (label:GetStringWidth() + 16) or 0
  box:SetPoint("TOPLEFT", container, "TOPLEFT", labelSpace, -y + 6)
  local value = CreateLabel(box, 12, Theme.textPrimary, true)
  value:SetPoint("CENTER")
  local function Paint() value:SetText(field.format(field.get())) end
  local function Step(dir)
    local v = math.floor((field.get() + dir * field.step) * 100 + 0.5) / 100
    v = math.max(field.min, math.min(field.max, v))
    field.set(v)
    Paint()
  end
  for i, def in ipairs({ { "-", -1, "LEFT" }, { "+", 1, "RIGHT" } }) do
    local b = CreateFrame("Button", nil, box)
    b:SetSize(32, 24)
    b:SetPoint(def[3], box, def[3], def[3] == "LEFT" and 1 or -1, 0)
    local bg = b:CreateTexture(nil, "ARTWORK")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0)
    local glyph = CreateLabel(b, 15, Theme.textPrimary, true)
    glyph:SetPoint("CENTER")
    glyph:SetText(def[1])
    local divider = box:CreateTexture(nil, "BORDER")
    divider:SetWidth(1)
    divider:SetPoint("TOP", b, def[3] == "LEFT" and "TOPRIGHT" or "TOPLEFT", 0, 0)
    divider:SetPoint("BOTTOM", b, def[3] == "LEFT" and "BOTTOMRIGHT" or "BOTTOMLEFT", 0, 0)
    divider:SetColorTexture(unpack(Theme.border))
    local a = Theme.accent
    b:SetScript("OnEnter", function() bg:SetColorTexture(a[1], a[2], a[3], 0.2) end)
    b:SetScript("OnLeave", function() bg:SetColorTexture(0, 0, 0, 0) end)
    b:SetScript("OnClick", function() Step(def[2]) end)
  end
  Paint()
  return AddRowDesc(container, y, width, field, 28)
end

local function AddActionRow(container, y, width, field)
  local label = CreateLabel(container, 12, Theme.textPrimary, true)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(field.label)
  local button = Widgets.CreateButton(container, field.buttonText, field.onClick)
  button:SetPoint("TOPLEFT", container, "TOPLEFT", label:GetStringWidth() + 16, -y + 5)
  return AddRowDesc(container, y, width, field, 26)
end

local ACCENT_SWATCHES = {
  { labelKey = "COLOR_VIOLET", rgb = { 0.545, 0.361, 0.965 }, isDefault = true },
  { labelKey = "COLOR_BLUE", rgb = { 0.231, 0.510, 0.965 } },
  { labelKey = "COLOR_INDIGO", rgb = { 0.388, 0.400, 0.945 } },
  { labelKey = "COLOR_ROSE", rgb = { 0.925, 0.282, 0.600 } },
  { labelKey = "COLOR_SILVER", rgb = { 0.580, 0.639, 0.722 } },
  { labelKey = "COLOR_GREEN", rgb = { 0.133, 0.773, 0.369 }, warnKey = "VAULT_STATE_CLAIMED" },
  { labelKey = "COLOR_RED", rgb = { 0.937, 0.267, 0.267 }, warnKey = "RAID_STAT_SAVED" },
  { labelKey = "COLOR_GOLD", rgb = { 0.918, 0.702, 0.031 }, warnKey = "ROSTER_LEGEND_WORLD" },
  { labelKey = "COLOR_TEAL", rgb = { 0.078, 0.722, 0.651 }, warnKey = "ROSTER_LEGEND_MPLUS" },
  { labelKey = "COLOR_ORANGE", rgb = { 0.976, 0.451, 0.086 }, warnKey = "DIFFICULTY_MYTHIC" },
}
local SWATCH_SIZE = 28
local SWATCH_TEXTURE = "Interface\\AddOns\\GG\\Media\\SwitchKnob64.tga"

local function SameColor(a, b)
  return type(a) == "table" and math.abs(a[1] - b[1]) < 0.01
    and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01
end

local function CreateSwatch(parent, rgb, selected)
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(SWATCH_SIZE, SWATCH_SIZE)
  local ring = btn:CreateTexture(nil, "BACKGROUND")
  ring:SetAllPoints()
  ring:SetTexture(SWATCH_TEXTURE)
  ring:SetVertexColor(1, 1, 1, selected and 1 or 0)
  local gap = btn:CreateTexture(nil, "BORDER")
  gap:SetSize(SWATCH_SIZE - 4, SWATCH_SIZE - 4)
  gap:SetPoint("CENTER")
  gap:SetTexture(SWATCH_TEXTURE)
  gap:SetVertexColor(0.11, 0.12, 0.15, 1)
  local dot = btn:CreateTexture(nil, "ARTWORK")
  dot:SetSize(SWATCH_SIZE - 8, SWATCH_SIZE - 8)
  dot:SetPoint("CENTER")
  dot:SetTexture(SWATCH_TEXTURE)
  dot:SetVertexColor(rgb[1], rgb[2], rgb[3], 1)
  return btn
end

local function AddColorRow(container, y, width, field)
  local options = GGDB.options
  local rerender = field.rerender or RerenderActiveFields
  local label = CreateLabel(container, 12, Theme.textPrimary, true)
  label:SetPoint("TOPLEFT", 0, -y)
  label:SetText(L["OPT_COLOR"])

  local function Choose(mode, rgb)
    options.accentMode = mode
    if rgb then options.accentColor = { rgb[1], rgb[2], rgb[3] } end
    if activePreviewRefresh then activePreviewRefresh() end
    C_Timer.After(0, rerender)
  end

  local mode = options.accentMode or "default"
  local rowY = y + 24
  local x = 0
  local matchedPreset = false
  for _, swatch in ipairs(ACCENT_SWATCHES) do
    local selected = (swatch.isDefault and mode == "default")
      or (not swatch.isDefault and mode == "custom" and SameColor(options.accentColor, swatch.rgb))
    matchedPreset = matchedPreset or selected
    local btn = CreateSwatch(container, swatch.rgb, selected)
    btn:SetPoint("TOPLEFT", x, -rowY)
    if swatch.warnKey then
      local warn = CreateLabel(btn, 10, Theme.gold, true)
      warn:SetPoint("TOPRIGHT", 3, 3)
      warn:SetText("!")
    end
    btn:SetScript("OnEnter", function(self)
      GG.Tip:Open(self, { family = "ui", anchor = "TOP" }, function(t)
        t:Title(L[swatch.labelKey])
        if swatch.warnKey then t:Text(L["OPT_COLOR_WARN"]:format(L[swatch.warnKey]), Theme.gold) end
      end)
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function()
      if swatch.isDefault then Choose("default") else Choose("custom", swatch.rgb) end
    end)
    x = x + SWATCH_SIZE + 8
  end

  local classBtn = Widgets.CreateButton(container, L["OPT_COLOR_CLASS"], function() Choose("class") end)
  local customBtn = Widgets.CreateButton(container, L["OPT_COLOR_CUSTOM"], function()
    local r, g, b = GG:ResolveAccentRGB()
    if not r then r, g, b = unpack(GG.ACCENT_DEFAULT) end
    local prevMode, prevColor = options.accentMode, options.accentColor
    local pending
    local function Pick()
      local nr, ng, nb = ColorPickerFrame:GetColorRGB()
      options.accentMode = "custom"
      options.accentColor = { nr, ng, nb }
      if activePreviewRefresh then activePreviewRefresh() end
      if not pending then
        pending = true
        C_Timer.After(0.15, function() pending = false; rerender() end)
      end
    end
    ColorPickerFrame:SetupColorPickerAndShow({
      r = r, g = g, b = b, hasOpacity = false,
      swatchFunc = Pick,
      cancelFunc = function()
        options.accentMode, options.accentColor = prevMode, prevColor
        if activePreviewRefresh then activePreviewRefresh() end
        rerender()
      end,
    })
  end)
  customBtn:SetPoint("LEFT", classBtn, "RIGHT", 8, 0)

  local indicatorW = 0
  if not matchedPreset and mode ~= "default" then
    local r, g, b = GG:ResolveAccentRGB()
    if r then
      local current = CreateSwatch(container, { r, g, b }, true)
      current:SetPoint("LEFT", customBtn, "RIGHT", 12, 0)
      local using = CreateLabel(container, 11, Theme.textMuted)
      using:SetPoint("LEFT", current, "RIGHT", 6, 0)
      using:SetText(mode == "class" and L["OPT_COLOR_USING_CLASS"] or L["OPT_COLOR_USING_CUSTOM"])
      indicatorW = 12 + SWATCH_SIZE + 6 + using:GetStringWidth()
    end
  end

  local extraH = 0
  local buttonsW = classBtn:GetWidth() + 8 + customBtn:GetWidth() + indicatorW
  if x + 10 + buttonsW <= width then
    classBtn:SetPoint("TOPLEFT", x + 10, -(rowY + 2))
  else
    extraH = SWATCH_SIZE + 10
    classBtn:SetPoint("TOPLEFT", 0, -(rowY + SWATCH_SIZE + 10))
  end

  local height = AddRowDesc(container, y, width, { desc = L["OPT_COLOR_DESC"] }, 24 + SWATCH_SIZE + 8 + extraH)

  if not field.noReloadNotice and GG:AccentSignature() ~= GG.appliedAccentSignature then
    local note = CreateLabel(container, 11, Theme.gold, true)
    note:SetPoint("TOPLEFT", 0, -(y + height + 8))
    note:SetText(L["OPT_COLOR_PENDING"])
    local apply = Widgets.CreateButton(container, L["OPT_COLOR_APPLY"], function() ReloadUI() end)
    apply:SetPoint("LEFT", note, "RIGHT", 12, 0)
    height = height + 8 + 26
  end
  return height
end

RenderField = function(container, field, y, width)
  if field.type == "segmented" then return AddSegmentedRow(container, y, width, field) end
  if field.type == "stepper" then return AddStepperRow(container, y, width, field) end
  if field.type == "action" then return AddActionRow(container, y, width, field) end
  if field.type == "color" then return AddColorRow(container, y, width, field) end
  if field.type == "boss-style" then return AddBossStyleRow(container, y, width, field) end
  if field.type == "roster-call-style" then return AddRosterCallStyleRow(container, y, width, field) end
  if field.type == "theme-picker" then return AddThemePickerRow(container, y, width, field) end
  if field.type == "toggle" then return AddToggleRow(container, y, width, field) end
  if field.type == "slider" then return AddSliderRow(container, y, width, field) end
  if field.type == "dropdown" then return AddDropdownRow(container, y, width, field) end
  if field.type == "info-button" then return AddInfoButtonRow(container, y, width, field) end
  if field.type == "textbox" then return AddTextboxRow(container, y, width, field) end
  if field.type == "profile-list" or field.type == "profile-share" then return AddProfileRow(container, y, width, field) end
  if field.type == "expander" then return AddExpanderRow(container, y, width, field) end
  return 0
end

ClearContent = function()
  for _, region in ipairs({ contentInner:GetRegions() }) do
    region:Hide()
    region:SetParent(nil)
  end
  for _, child in ipairs({ contentInner:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end
end

ClearPreview = function()
  for _, inner in ipairs({ previewBottomInner, previewSideInner }) do
    for _, region in ipairs({ inner:GetRegions() }) do
      region:Hide()
      region:SetParent(nil)
    end
    for _, child in ipairs({ inner:GetChildren() }) do
      child:Hide()
      child:SetParent(nil)
    end
  end
end

local function ApplyPreviewPlacement(category)
  local side = category and category.buildPreviewVertical ~= nil
    and GG.RosterUI and GG.RosterUI.IsVertical and GG.RosterUI:IsVertical()
  local none = category and not category.buildPreview and not category.buildPreviewVertical
  previewBottomFrame:SetShown(not side and not none)
  previewSideFrame:SetShown(side and true or false)
  previewFrame = side and previewSideFrame or previewBottomFrame
  previewInner = side and previewSideInner or previewBottomInner

  contentClip:ClearAllPoints()
  contentClip:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", SIDEBAR_WIDTH + CONTENT_PADDING, -(CONTENT_PADDING + TOOLBAR_HEIGHT))
  if none then
    contentClip:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", -CONTENT_PADDING - SCROLLBAR_GUTTER, CONTENT_PADDING)
  elseif side then
    contentClip:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT",
      -SIDE_PREVIEW_WIDTH - CONTENT_PADDING - SCROLLBAR_GUTTER, CONTENT_PADDING)
  else
    contentClip:SetPoint("BOTTOMRIGHT", previewBottomFrame, "TOPRIGHT", -CONTENT_PADDING - SCROLLBAR_GUTTER, CONTENT_PADDING)
  end
  return side
end

UpdateScrollBounds = function()
  local totalHeight = contentInner:GetHeight()
  local visibleHeight = contentClip:GetHeight()
  local maxScroll = math.max(0, totalHeight - visibleHeight)
  contentScrollbar:SetMinMaxValues(0, maxScroll)
  if scrollOffset > maxScroll then scrollOffset = maxScroll end
  contentScrollbar:SetValue(scrollOffset)
  contentScrollbar:SetShown(maxScroll > 0)
  contentInner:ClearAllPoints()
  contentInner:SetPoint("TOPLEFT", contentClip, "TOPLEFT", 0, scrollOffset)
  contentInner:SetPoint("RIGHT", contentClip, "RIGHT", 0, 0)
end

RenderFields = function(fields)
  ClearContent()
  for _, field in ipairs(fields) do
    if field.set then
      local originalSet = field.set
      field.set = function(...)
        originalSet(...)
        if activePreviewRefresh then activePreviewRefresh() end
      end
    end
  end
  local width = contentInner:GetWidth()
  if not width or width < 100 then width = 300 end

  local groups, current = {}, nil
  for _, field in ipairs(fields) do
    if field.type == "header" then
      current = { title = field.label, fields = {} }
      table.insert(groups, current)
    else
      if not current then
        current = { fields = {} }
        table.insert(groups, current)
      end
      table.insert(current.fields, field)
    end
  end

  local y = 0
  for _, group in ipairs(groups) do
    local box = CreateFrame("Frame", nil, contentInner)
    box:SetPoint("TOPLEFT", 0, -y)
    box:SetWidth(width)
    local boxBg = box:CreateTexture(nil, "BACKGROUND")
    boxBg:SetAllPoints()
    boxBg:SetColorTexture(1, 1, 1, 0.025)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
      local line = box:CreateTexture(nil, "BORDER")
      line:SetColorTexture(unpack(Theme.border))
      if side == "TOP" or side == "BOTTOM" then
        line:SetPoint(side .. "LEFT"); line:SetPoint(side .. "RIGHT"); line:SetHeight(1)
      else
        line:SetPoint("TOP" .. side); line:SetPoint("BOTTOM" .. side); line:SetWidth(1)
      end
    end

    local titleH = 0
    if group.title then
      titleH = BOX_TITLE_HEIGHT
      local title = CreateLabel(box, 10.5, Theme.accentHi, true)
      title:SetPoint("TOPLEFT", BOX_PADDING, -12)
      title:SetText(group.title:upper())
      local divider = box:CreateTexture(nil, "ARTWORK")
      divider:SetPoint("TOPLEFT", 1, -titleH)
      divider:SetPoint("TOPRIGHT", -1, -titleH)
      divider:SetHeight(1)
      divider:SetColorTexture(unpack(Theme.borderSoft))
    end

    local inner = CreateFrame("Frame", nil, box)
    inner:SetPoint("TOPLEFT", BOX_PADDING, -(titleH + BOX_PADDING))
    inner:SetWidth(width - BOX_PADDING * 2)
    local innerH = RenderFieldList(inner, group.fields, width - BOX_PADDING * 2)
    inner:SetHeight(math.max(innerH, 1))
    local boxH = titleH + BOX_PADDING + innerH + BOX_PADDING
    box:SetHeight(boxH)
    y = y + boxH + BOX_GAP
  end

  contentInner:SetHeight(math.max(y - BOX_GAP, 1))
  UpdateScrollBounds()
end

RenderFieldList = function(container, fields, width)
  local TOGGLE_COL_WIDTH = 240
  local measure = CreateLabel(container, 12, Theme.textPrimary, true)
  measure:SetAlpha(0)
  local function ChipStep(startIndex)
    local need, count = 0, 0
    for i = startIndex, #fields do
      local f = fields[i]
      if f.type ~= "toggle" or (f.desc and f.desc ~= "") then break end
      measure:SetText(f.label or "")
      need = math.max(need, measure:GetStringWidth() + (f.icon and 19 or 0))
      count = count + 1
    end
    local minStep = math.max(160, need + 76) + 16
    local columns = math.max(1, math.floor((width + 16) / minStep))
    if count > columns then
      columns = math.ceil(count / math.ceil(count / columns))
    end
    return (width + 16) / columns
  end
  local colStep = TOGGLE_COL_WIDTH
  local y = 0
  local fullRows = 0
  local colX = 0
  local rowHeight = 0
  local inGrid = false

  local function FlushGrid()
    if inGrid then
      y = y + rowHeight + ROW_GAP
      colX = 0
      rowHeight = 0
      inGrid = false
    end
  end

  for index, field in ipairs(fields) do
    if field.type == "header" then
      FlushGrid()
      local height = AddSectionHeader(container, y, width, field)
      y = y + height
    elseif field.type == "expander" then
      FlushGrid()
      local height = AddExpanderRow(container, y, width, field)
      y = y + height + ROW_GAP
    elseif field.type == "toggle" and not (field.desc and field.desc ~= "") then
      if not inGrid then colStep = ChipStep(index) end
      if colX + colStep > width + 16.5 and inGrid then
        FlushGrid()
      end
      local height = AddToggleChip(container, colX, y, colStep - 16, field)
      rowHeight = math.max(rowHeight, height)
      colX = colX + colStep
      inGrid = true
    else
      FlushGrid()
      fullRows = fullRows + 1
      if fullRows > 1 then
        local sep = container:CreateTexture(nil, "ARTWORK")
        sep:SetPoint("TOPLEFT", 0, -(y - ROW_GAP / 2))
        sep:SetPoint("TOPRIGHT", 0, -(y - ROW_GAP / 2))
        sep:SetHeight(1)
        sep:SetColorTexture(1, 1, 1, 0.05)
      end
      local height = RenderField(container, field, y, width)
      y = y + height + ROW_GAP
    end
  end
  FlushGrid()

  return math.max(0, y - ROW_GAP)
end

RerenderActiveFields = function()
  for _, c in ipairs(CATEGORIES) do
    if c.key == activeCategory then
      RenderFields(c.build())
      return
    end
  end
end

SelectCategory = function(key)
  activeCategory = key
  if GG.RosterUI and GG.RosterUI.FitSettingsWidth and GG.RosterUI:FitSettingsWidth() then
    C_Timer.After(0, function()
      if activeCategory == key and panelFrame and panelFrame:IsShown() then SelectCategory(key) end
    end)
  end
  for catKey, btn in pairs(sidebarButtons) do
    local active = catKey == key
    btn.accent:SetShown(active)
    btn.bg:SetShown(active)
    local a = Theme.accent
    btn.bg:SetColorTexture(a[1], a[2], a[3], 0.18)
    btn.label:SetFont(active and Theme.fontBold or Theme.font, 12.5, "")
    btn.label:SetTextColor(unpack(active and { 1, 1, 1, 1 } or Theme.textMuted))
    if btn.tint then
      btn.icon:SetVertexColor(unpack(active and { 1, 1, 1, 1 } or { 0.55, 0.52, 0.63, 1 }))
    else
      btn.icon:SetVertexColor(1, 1, 1, 1)
      btn.icon:SetAlpha(active and 1 or 0.6)
    end
  end

  scrollOffset = 0
  local category
  for _, c in ipairs(CATEGORIES) do
    if c.key == key then category = c end
  end
  if category and toolbar then
    toolbar.title:SetText(L[category.labelKey])
    toolbar.reset:SetShown(category.resettable == true)
    toolbar.reset.categoryKey = key
  end
  if category then
    local side = ApplyPreviewPlacement(category)
    RenderFields(category.build())

    ClearPreview()
    activePreviewRefresh = nil
    local buildPreview = side and category.buildPreviewVertical or category.buildPreview
    if buildPreview then
      activePreviewRefresh = buildPreview(previewInner)
      if activePreviewRefresh then activePreviewRefresh() end
    end
  end
end

local COLUMN_GROUPS = {
  {
    labelKey = "SETTINGS_GROUP_CHARACTER",
    sections = {
      { key = "avatar", labelKey = "SECTION_AVATAR" },
      { key = "ilvl", labelKey = "SECTION_ILVL" },
      { key = "rating", labelKey = "SECTION_RATING" },
      { key = "guild", labelKey = "SECTION_GUILD" },
      { key = "roster", labelKey = "SECTION_ROSTER" },
      { key = "account", labelKey = "SECTION_ACCOUNT" },
    },
  },
  {
    labelKey = "SETTINGS_GROUP_WEEKLY",
    sections = {
      { key = "keystone", labelKey = "SECTION_KEYSTONE" },
      { key = "vault", labelKey = "SECTION_VAULT" },
      { key = "dungeons", labelKey = "SECTION_DUNGEONS" },
      { key = "raids", labelKey = "SECTION_RAIDS" },
      { key = "currencies", labelKey = "SECTION_CURRENCIES" },
    },
  },
}
GG.SettingsColumnGroups = COLUMN_GROUPS

local expandedPickers = { currencies = false, quests = false }

local function AppendPickerFields(fields, pickerKey, trackables, labelKey)
  local visibleCount = 0
  for _, entry in ipairs(trackables) do
    if GG.Currencies:IsVisible(entry.key) then visibleCount = visibleCount + 1 end
  end

  table.insert(fields, {
    type = "expander",
    label = L[labelKey],
    countText = L["SETTINGS_CURRENCIES_PICKER_COUNT"]:format(visibleCount, #trackables),
    expanded = expandedPickers[pickerKey],
    onToggle = function()
      expandedPickers[pickerKey] = not expandedPickers[pickerKey]
      RerenderActiveFields()
    end,
  })

  if not expandedPickers[pickerKey] then return end

  for _, entry in ipairs(trackables) do
    table.insert(fields, {
      type = "toggle",
      label = entry.labelKey and L[entry.labelKey] or entry.name,
      icon = entry.icon,
      get = function() return GG.Currencies:IsVisible(entry.key) end,
      set = function(v)
        GG.Currencies:SetVisible(entry.key, v)
        if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
        if GG.RosterUI and GG.RosterUI.Relayout then GG.RosterUI:Relayout() end
        C_Timer.After(0, RerenderActiveFields)
      end,
    })
  end
end

local function BuildColumnsFields()
  local sections = GGDB.options.sections
  local fields = {}
  for _, group in ipairs(COLUMN_GROUPS) do
    table.insert(fields, { id = "colgroup:" .. group.labelKey, type = "header", label = L[group.labelKey] })
    for _, entry in ipairs(group.sections) do
      table.insert(fields, {
        id = "col:" .. entry.key,
        type = "toggle",
        label = L[entry.labelKey],
        get = function() return sections[entry.key] end,
        set = function(v)
          sections[entry.key] = v
          GG.RosterUI:Relayout()
        end,
      })
      if entry.key == "currencies" then
        AppendPickerFields(fields, "quests",
          GG.Currencies:GetQuestTrackables(), "SETTINGS_QUESTS_PICKER")
        AppendPickerFields(fields, "currencies",
          GG.Currencies:GetTrackables(), "SETTINGS_CURRENCIES_PICKER")
      end
    end
  end
  return fields
end

local function BuildColumnsPreview(container)
  return GG.RosterUI:BuildSettingsColumnsPreview(container)
end

local RAID_DIFFICULTIES = {
  { id = 17, labelKey = "DIFFICULTY_LFR" },
  { id = 14, labelKey = "DIFFICULTY_NORMAL" },
  { id = 15, labelKey = "DIFFICULTY_HEROIC" },
  { id = 16, labelKey = "DIFFICULTY_MYTHIC" },
}

local function BuildBossesFields()
  local difficulties = GGDB.options.raidDifficulties
  local fields = {
    { id = "bossStyleHeader", type = "header", label = L["BOSS_STYLE_HEADER"] },
    {
      id = "bossStyle",
      type = "boss-style",
      get = function() return GG.BossIcons:GetStyle() end,
      set = function(v)
        GG.BossIcons:SetStyle(v)
        if GG.RosterUI and GG.RosterUI.Relayout then GG.RosterUI:Relayout() end
        if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
        if GG.RaidTab and GG.RaidTab.Refresh then GG.RaidTab:Refresh() end
      end,
    },
    { id = "diffHeader", type = "header", label = L["OPTIONS_SHOW_DIFFICULTY"] },
  }
  for _, entry in ipairs(RAID_DIFFICULTIES) do
    table.insert(fields, {
      id = "diff:" .. entry.id,
      type = "toggle",
      label = L[entry.labelKey],
      get = function() return difficulties[entry.id] end,
      set = function(v)
        difficulties[entry.id] = v
        GG.RosterUI:Relayout()
      end,
    })
  end
  return fields
end

local function BuildBossesPreview(container)
  return GG.RosterUI:BuildSettingsBossesPreview(container)
end

local function BuildColumnsPreviewVertical(container)
  return GG.RosterUI:BuildSettingsColumnsPreviewVertical(container)
end

local function BuildBossesPreviewVertical(container)
  return GG.RosterUI:BuildSettingsBossesPreviewVertical(container)
end

local function BuildThemeFields()
  local options = GGDB.options
  local RT = GG.RosterThemes
  local function Relayout()
    if GG.RosterUI and GG.RosterUI.Relayout then GG.RosterUI:Relayout() end
  end
  local resolved = RT:Resolve(options)
  local fields = {
    { id = "themeHeader", type = "header", label = L["THEME_HEADER"] },
    {
      id = "theme",
      type = "theme-picker",
      get = function() return RT:Resolve(options).key end,
      set = function(v)
        if RT:SetTheme(options, v) then Relayout() end
      end,
    },
    { id = "themePartsHeader", type = "header", label = L["THEME_PARTS_HEADER"] },
  }
  for _, part in ipairs(RT.PART_ORDER) do
    local labels = RT.PART_LABELS[part]
    local themeValue = RT:ThemeDefault(resolved.key, part)
    local values = { { key = "theme", label = L["THEME_PART_DEFAULT"]:format(L[labels[themeValue]]) } }
    for _, value in ipairs(RT.PART_VALUES[part]) do
      values[#values + 1] = { key = value, label = L[labels[value]] }
    end
    fields[#fields + 1] = {
      id = "themePart:" .. part,
      type = "segmented",
      label = L[labels.title],
      desc = L[labels.title .. "_DESC"],
      values = values,
      get = function()
        local saved = type(options.themeParts) == "table" and options.themeParts[part] or nil
        return RT:IsValidPart(part, saved) and saved or "theme"
      end,
      set = function(v)
        if RT:SetPart(options, part, v) then Relayout() end
      end,
    }
  end
  return fields
end

local function BuildWindowFields()
  local options = GGDB.options
  local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or 90
  local function Relayout()
    if GG.RosterUI and GG.RosterUI.Relayout then GG.RosterUI:Relayout() end
  end
  return {
    { type = "header", label = L["SETTINGS_CAT_WINDOW"] },
    {
      id = "layout",
      type = "segmented",
      label = L["OPT_LAYOUT"],
      desc = L["OPT_LAYOUT_DESC"],
      values = {
        { key = "horizontal", label = L["OPT_LAYOUT_ROWS"] },
        { key = "vertical", label = L["OPT_LAYOUT_COLUMNS"] },
      },
      get = function() return options.layoutMode == "vertical" and "vertical" or "horizontal" end,
      set = function(v)
        if (options.layoutMode == "vertical") == (v == "vertical") then return end
        options.layoutMode = v
        GG.RosterUI:ApplyLayoutMode()
      end,
    },
    {
      id = "shown",
      type = "segmented",
      label = L["OPT_SHOWN"],
      desc = L["OPT_SHOWN_DESC"],
      values = {
        { key = 6, label = "6" }, { key = 8, label = "8" }, { key = 10, label = "10" },
        { key = 12, label = "12" }, { key = 15, label = "15" }, { key = "all", label = L["OPT_SHOWN_ALL"] },
      },
      get = function() return options.maxVisibleCharacters or 10 end,
      set = function(v)
        options.maxVisibleCharacters = v
        Relayout()
      end,
    },
    {
      id = "scale",
      type = "stepper",
      label = L["OPTIONS_WINDOW_SCALE"],
      min = 0.7, max = 1.5, step = 0.05,
      format = function(v) return ("%d%%"):format(math.floor(v * 100 + 0.5)) end,
      get = function() return options.windowScale or 1.0 end,
      set = function(v)
        options.windowScale = v
        if GG.RosterUI.ApplyScale then GG.RosterUI:ApplyScale(v) end
      end,
    },
    {
      type = "segmented",
      label = L["OPTIONS_WINDOW_OPACITY"],
      values = {
        { key = 100, label = "100%" }, { key = 90, label = "90%" },
        { key = 80, label = "80%" }, { key = 70, label = "70%" },
      },
      get = function() return math.floor((options.windowOpacity or 1) * 100 + 0.5) end,
      set = function(v)
        options.windowOpacity = v / 100
        if GG.RosterUI.ApplyOpacity then GG.RosterUI:ApplyOpacity(v / 100) end
      end,
    },
    {
      type = "toggle",
      label = L["OPT_LOCK_WINDOW"],
      get = function() return options.lockWindow == true end,
      set = function(v) options.lockWindow = v end,
    },
    {
      type = "toggle",
      label = L["OPT_CLOSE_ESC"],
      get = function() return options.closeWithEsc ~= false end,
      set = function(v)
        options.closeWithEsc = v
        GG.RosterUI:ApplyEscBehavior()
      end,
    },
    {
      type = "action",
      label = L["OPT_WINDOW_POSITION"],
      desc = L["OPT_CENTER_DESC"],
      buttonText = L["OPT_CENTER"],
      onClick = function() GG.RosterUI:CenterWindow() end,
    },
    { type = "header", label = L["SETTINGS_BOX_COLOR"] },
    { id = "color", type = "color" },
    { type = "header", label = L["SETTINGS_BOX_OPENING"] },
    {
      type = "segmented",
      label = L["OPT_OPEN_ON"],
      values = {
        { key = "characters", label = L["OPT_OPEN_CHARS"] },
        { key = "last", label = L["OPT_OPEN_LAST"] },
      },
      get = function() return options.openOn or "characters" end,
      set = function(v) options.openOn = v end,
    },
    {
      type = "toggle",
      label = L["OPTIONS_MINIMAP_SHOW"],
      get = function() return not options.minimap.hide end,
      set = function(v)
        options.minimap.hide = not v
        if v then LibStub("LibDBIcon-1.0"):Show(ADDON_NAME) else LibStub("LibDBIcon-1.0"):Hide(ADDON_NAME) end
      end,
    },
    {
      type = "toggle",
      label = L["OPTIONS_MINIMAP_LOCK"],
      get = function() return options.minimap.lock end,
      set = function(v)
        options.minimap.lock = v
        local icon = LibStub("LibDBIcon-1.0")
        if v then icon:Lock(ADDON_NAME) else icon:Unlock(ADDON_NAME) end
      end,
    },
    { type = "header", label = L["SETTINGS_BOX_CHARACTERS"] },
    {
      type = "segmented",
      label = L["OPTIONS_MIN_LEVEL"],
      desc = L["OPT_LEVEL_DESC"],
      values = {
        { key = maxLevel, label = L["OPT_LEVEL_MAX"]:format(maxLevel) },
        { key = maxLevel - 10, label = ("%d+"):format(maxLevel - 10) },
        { key = 1, label = L["OPT_LEVEL_ANY"] },
      },
      get = function() return options.minLevel end,
      set = function(v) options.minLevel = v end,
    },
  }
end

local function BuildWindowPreview(container)
  local options = GGDB.options

  local mock = CreateFrame("Frame", nil, container)
  mock:SetSize(64, 40)
  mock:SetPoint("LEFT", 4, 6)
  local mockBg = mock:CreateTexture(nil, "BACKGROUND")
  mockBg:SetAllPoints()
  mockBg:SetColorTexture(unpack(Theme.panel))
  local mockLogo = mock:CreateTexture(nil, "ARTWORK")
  mockLogo:SetSize(16, 16)
  mockLogo:SetPoint("CENTER")
  mockLogo:SetTexture(Theme.media.logoIcon)

  local statusLabel = CreateLabel(container, 11, Theme.textFaint)
  statusLabel:SetPoint("LEFT", 110, 0)
  statusLabel:SetWordWrap(true)
  statusLabel:SetWidth(520)

  return function()
    mock:SetScale(options.windowScale or 1.0)
    mock:SetAlpha(options.windowOpacity or 1.0)
    local r, g, b = GG:ResolveAccentRGB()
    if r then mockLogo:SetVertexColor(r, g, b, 1) else mockLogo:SetVertexColor(unpack(GG.ACCENT_DEFAULT)) end
    local minimapStatus = options.minimap.hide and L["OPTIONS_PREVIEW_MINIMAP_HIDDEN"]
      or (options.minimap.lock and L["OPTIONS_PREVIEW_MINIMAP_LOCKED"] or L["OPTIONS_PREVIEW_MINIMAP_SHOWN"])
    statusLabel:SetText(L["OPTIONS_PREVIEW_WINDOW_STATUS"]:format(
      math.floor((options.windowOpacity or 1) * 100 + 0.5),
      minimapStatus,
      options.minLevel or 1
    ))
  end
end

local function BuildAccountFields()
  local options = GGDB.options
  local fields = {
    { type = "header", label = L["SETTINGS_BOX_IDENTITY"] },
    {
      type = "dropdown",
      label = L["OPTIONS_MAIN_CHARACTER"],
      desc = L["OPTIONS_MAIN_CHARACTER_DESC"],
      values = function()
        local values = { { key = "", label = L["OPTIONS_MAIN_CHARACTER_NONE"] } }
        for key in pairs(GGDB.ownCharacters or {}) do
          table.insert(values, { key = key, label = key })
        end
        return values
      end,
      get = function() return options.mainCharacterKey or "" end,
      set = function(v)
        local newKey = (v ~= "" and v) or nil
        local oldKey = options.mainCharacterKey
        options.mainCharacterKey = newKey

        if oldKey and GGDB.chars[oldKey] then GGDB.chars[oldKey].isMain = false end
        if newKey and GGDB.chars[newKey] then GGDB.chars[newKey].isMain = true end

        GG:RequestBroadcast()
        if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
      end,
    },
    {
      type = "info-button",
      label = function()
        return L["OPTIONS_YOUR_BATTLETAG"]:format(
          (GGDB.account and GGDB.account.battleTag) or L["OPTIONS_MAIN_CHARACTER_NONE"]
        )
      end,
      desc = L["OPTIONS_COPY_BATTLETAG_DESC"],
      buttonText = L["OPTIONS_COPY_BATTLETAG"],
      disabled = function() return not (GGDB.account and GGDB.account.battleTag) end,
      onClick = function() StaticPopup_Show("GG_COPY_BATTLETAG") end,
    },
    { type = "header", label = L["SETTINGS_BOX_ACCOUNT_LABEL"] },
    {
      id = "accountSlot",
      type = "dropdown",
      label = L["OPTIONS_ACCOUNT_SLOT"],
      desc = L["OPTIONS_ACCOUNT_SLOT_DESC"],
      values = function()
        local auto = (GGDB.account and GGDB.account.autoSlot) or 1
        local values = { { key = "auto", label = L["OPTIONS_ACCOUNT_SLOT_AUTO"]:format(auto) } }
        for n = 1, 9 do table.insert(values, { key = tostring(n), label = tostring(n) }) end
        return values
      end,
      get = function()
        return options.accountSlotManual and tostring(options.accountSlot or 1) or "auto"
      end,
      set = function(v)
        local beforeSlot, beforeManual = GG:GetAccountSlot(), options.accountSlotManual == true
        if v == "auto" then
          options.accountSlotManual = false
          if GG.AccountSync then GG.AccountSync:RecomputeAutoSlot() end
        else
          options.accountSlotManual = true
          options.accountSlot = tonumber(v) or 1
        end
        if GG:GetAccountSlot() ~= beforeSlot or (options.accountSlotManual == true) ~= beforeManual then
          GG:ScheduleOwnRebroadcast()
        end
        if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
      end,
    },
    {
      id = "labelStyle",
      type = "dropdown",
      label = L["OPTIONS_ACCOUNT_LABEL_STYLE"],
      desc = L["OPTIONS_ACCOUNT_LABEL_STYLE_DESC"],
      values = {
        { key = "cuenta", label = L["ACCOUNT_LABEL_STYLE_CUENTA"] },
        { key = "wow", label = L["ACCOUNT_LABEL_STYLE_WOW"] },
        { key = "alt", label = L["ACCOUNT_LABEL_STYLE_ALT"] },
        { key = "number", label = L["ACCOUNT_LABEL_STYLE_NUMBER"] },
        { key = "battletag", label = L["ACCOUNT_LABEL_STYLE_BATTLETAG"] },
      },
      get = function() return options.accountLabelStyle end,
      set = function(v)
        options.accountLabelStyle = v
        if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
        if GG.RosterUI and GG.RosterUI.Relayout then GG.RosterUI:Relayout() end
      end,
    },
    { type = "header", label = L["SETTINGS_BOX_LINKED"] },
    {
      id = "link",
      type = "info-button",
      label = function() return L["OPTIONS_LINK_BUTTON_LABEL"] end,
      desc = L["OPTIONS_LINK_BUTTON_DESC"],
      buttonText = L["OPTIONS_LINK_BUTTON"],
      onClick = function() StaticPopup_Show("GG_LINK_ASK_TARGET") end,
    },
    "__LINKED_ROWS__",
    {
      type = "textbox",
      label = L["OPTIONS_LINKED_ACCOUNTS"],
      desc = L["OPTIONS_LINKED_ACCOUNTS_DESC"],
      get = function() return table.concat(options.linkedAccountTags or {}, "\n") end,
      set = function(v)
        local tags, seen = {}, {}
        for line in (v or ""):gmatch("[^\n,]+") do
          local trimmed = line:match("^%s*(.-)%s*$")
          if trimmed ~= "" and not seen[trimmed] then
            seen[trimmed] = true
            table.insert(tags, trimmed)
          end
        end
        options.linkedAccountTags = tags
        if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
      end,
    },
  }

  local linked = {}
  for hash, label in pairs(options.linkedAccountHashes or {}) do
    table.insert(linked, { hash = hash, label = label })
  end
  table.sort(linked, function(a, b) return tostring(a.label) < tostring(b.label) end)
  for i, field in ipairs(fields) do
    if field == "__LINKED_ROWS__" then
      table.remove(fields, i)
      for j, entry in ipairs(linked) do
        table.insert(fields, i + j - 1, {
          type = "info-button",
          label = function() return L["OPTIONS_LINKED_ENTRY"]:format(tostring(entry.label)) end,
          buttonText = L["OPTIONS_UNLINK"],
          onClick = function()
            GG:UnlinkAccountHash(entry.hash)
            RerenderActiveFields()
          end,
        })
      end
      break
    end
  end
  return fields
end

local function BuildAccountPreview(container)
  local options = GGDB.options

  local pill = CreateFrame("Frame", nil, container)
  pill:SetHeight(24)
  pill:SetPoint("LEFT", 4, 0)
  local pillBg = pill:CreateTexture(nil, "BACKGROUND")
  pillBg:SetAllPoints()
  pillBg:SetColorTexture(Theme.accent[1], Theme.accent[2], Theme.accent[3], 0.22)
  local pillLabel = CreateLabel(pill, 12, Theme.accent, true)
  pillLabel:SetPoint("CENTER")

  local mainLabel = CreateLabel(container, 11, Theme.textFaint)
  mainLabel:SetPoint("LEFT", pill, "RIGHT", 90, 0)
  mainLabel:SetWordWrap(true)
  mainLabel:SetWidth(220)

  return function()
    local text = GG:FormatAccountLabel(GG:GetAccountSlot(), GGDB.account and GGDB.account.battleTag)
    pillLabel:SetText(text)
    pill:SetWidth(pillLabel:GetStringWidth() + 24)
    mainLabel:SetText(options.mainCharacterKey
      and L["OPTIONS_PREVIEW_MAIN_SET"]:format(options.mainCharacterKey)
      or L["OPTIONS_PREVIEW_MAIN_NONE"])
  end
end

local function BuildAnnouncementsFields()
  local options = GGDB.options
  local function toggle(key, labelKey, descKey)
    return {
      id = key,
      type = "toggle",
      label = L[labelKey],
      desc = L[descKey],
      get = function() return options[key] end,
      set = function(v) options[key] = v end,
    }
  end
  local function customText(textKey, labelKey, descKey)
    return {
      type = "textbox",
      label = L[labelKey],
      desc = L[descKey],
      boxHeight = 36,
      get = function() return options.announceTexts[textKey] end,
      set = function(v) options.announceTexts[textKey] = v end,
    }
  end
  return {
    { type = "header", label = L["SETTINGS_BOX_INSTANCES"] },
    toggle("announceInstanceReset", "OPTIONS_ANNOUNCE_INSTANCE_RESET", "OPTIONS_ANNOUNCE_INSTANCE_RESET_DESC"),
    customText("instanceReset", "OPTIONS_ANNOUNCE_INSTANCE_RESET_TEXT", "OPTIONS_ANNOUNCE_INSTANCE_RESET_TEXT_DESC"),
    { type = "header", label = L["SECTION_KEYSTONE"] },
    toggle("announceKeystoneParty", "OPTIONS_ANNOUNCE_KEYSTONE_PARTY", "OPTIONS_ANNOUNCE_KEYSTONE_PARTY_DESC"),
    customText("keystoneParty", "OPTIONS_ANNOUNCE_KEYSTONE_PARTY_TEXT", "OPTIONS_ANNOUNCE_KEYSTONE_TEXT_DESC"),
    toggle("announceKeystoneGuild", "OPTIONS_ANNOUNCE_KEYSTONE_GUILD", "OPTIONS_ANNOUNCE_KEYSTONE_GUILD_DESC"),
    customText("keystoneGuild", "OPTIONS_ANNOUNCE_KEYSTONE_GUILD_TEXT", "OPTIONS_ANNOUNCE_KEYSTONE_TEXT_DESC"),
  }
end

local function BuildPopupsFields()
  local options = GGDB.options
  local function popup(key, labelKey, test, noteKey)
    return {
      id = key,
      type = "toggle",
      label = L[labelKey],
      desc = L[labelKey .. "_DESC"],
      note = noteKey and L[noteKey] or nil,
      buttonText = L["POPUP_TEST"],
      onClick = test,
      get = function() return options[key] ~= false end,
      set = function(v) options[key] = v end,
    }
  end
  return {
    { type = "header", label = L["POPUPS_LEAD"] },
    popup("popupRosterCall", "POPUP_ROSTER_CALL", function() GG.RosterCall:Test() end),
    {
      id = "rosterCallStyle",
      type = "roster-call-style",
      label = L["POPUP_ROSTER_CALL_STYLE"],
      desc = L["POPUP_ROSTER_CALL_STYLE_DESC"],
      values = function()
        local values = {}
        for _, style in ipairs(GG.RosterCall.STYLES) do
          values[#values + 1] = { key = style, label = L["RC_STYLE_" .. string.upper(style)] }
        end
        return values
      end,
      get = function() return options.rosterCallStyle or "band" end,
      set = function(v) options.rosterCallStyle = v end,
    },
    {
      id = "rosterCallSound",
      type = "toggle",
      label = L["POPUP_ROSTER_CALL_SOUND"],
      desc = L["POPUP_ROSTER_CALL_SOUND_DESC"],
      get = function() return options.rosterCallSound ~= false end,
      set = function(v) options.rosterCallSound = v end,
    },
    popup("popupRosterCharacter", "POPUP_ROSTER_CHARACTER", function() GG.RosterAlert:Test() end, "POPUP_ROSTER_CHARACTER_NOTE"),
    popup("popupLockoutGroup", "POPUP_LOCKOUT_GROUP", function() GG.LockoutAlert:RenderGroupAlert() end),
    popup("popupLockoutInstance", "POPUP_LOCKOUT_INSTANCE", function() GG.LockoutAlert:TestInstanceAlert() end),
  }
end

local function BuildAnnouncementsPreview(container)
  local options = GGDB.options
  local exampleKeystone = GG:FindOwnedKeystoneItemLink() or L["OPTIONS_PREVIEW_KEYSTONE_EXAMPLE"]

  local order = {
    { key = "instance", captionKey = "OPTIONS_ANNOUNCE_INSTANCE_RESET", optionKey = "announceInstanceReset" },
    { key = "party", captionKey = "OPTIONS_ANNOUNCE_KEYSTONE_PARTY", optionKey = "announceKeystoneParty" },
    { key = "guild", captionKey = "OPTIONS_ANNOUNCE_KEYSTONE_GUILD", optionKey = "announceKeystoneGuild" },
  }

  local function ComputeText(key)
    local texts = options.announceTexts or {}
    if key == "instance" then
      local resetText = (texts.instanceReset ~= "" and texts.instanceReset) or L["ANNOUNCE_INSTANCES_RESET"]
      return ">GG< " .. resetText
    end
    local customKey = (key == "party") and "keystoneParty" or "keystoneGuild"
    local template = (texts[customKey] ~= "" and texts[customKey]) or L["ANNOUNCE_NEW_KEYSTONE"]
    return ">GG< " .. GG.Announce:FormatKeystoneText(template, exampleKeystone)
  end

  local playerName = UnitName and UnitName("player") or "?"
  local PARTY = { 0.667, 0.667, 1.000, 1 }
  local GUILD = { 0.251, 1.000, 0.251, 1 }
  local function Prefix(key)
    local template = (key == "guild" and CHAT_GUILD_GET or CHAT_PARTY_GET) or "[%s]: "
    return (template:gsub("|H.-|h(.-)|h", "%1")):format(playerName)
  end
  local chatBg = container:CreateTexture(nil, "BACKGROUND")
  chatBg:SetPoint("TOPLEFT", -8, 6)
  chatBg:SetWidth(516)
  chatBg:SetColorTexture(0, 0, 0, 0.35)

  local captions, lines = {}, {}
  local y = 0
  for _, entry in ipairs(order) do
    local caption = CreateLabel(container, 10, Theme.textMuted, true)
    caption:SetPoint("TOPLEFT", 0, -y)
    caption:SetText(L[entry.captionKey])
    y = y + ANNOUNCE_CAPTION_HEIGHT + ANNOUNCE_CAPTION_GAP

    local line = CreateLabel(container, 11, entry.key == "guild" and GUILD or PARTY)
    line:SetWordWrap(true)
    line:SetWidth(500)
    line:SetPoint("TOPLEFT", 0, -y)
    line:SetText(Prefix(entry.key) .. ComputeText(entry.key))
    y = y + line:GetStringHeight() + 6

    captions[entry.key] = caption
    lines[entry.key] = line
  end
  chatBg:SetHeight(y + 6)

  return function()
    for _, entry in ipairs(order) do
      lines[entry.key]:SetText(Prefix(entry.key) .. ComputeText(entry.key))
      local visible = options[entry.optionKey]
      captions[entry.key]:SetShown(visible)
      lines[entry.key]:SetShown(visible)
    end
  end
end

local function BuildProfileFields()
  return {
    { type = "header", label = L["PROFILE_LIST_HEADER"] },
    { type = "profile-list" },
    { type = "header", label = L["PROFILE_SHARE_HEADER"] },
    { type = "profile-share" },
  }
end

CATEGORIES = {
  { key = "columns", labelKey = "SETTINGS_CAT_COLUMNS", build = BuildColumnsFields, buildPreview = BuildColumnsPreview,
    buildPreviewVertical = BuildColumnsPreviewVertical, resettable = true,
    icon = "Interface\\AddOns\\GG\\Media\\ViewHorizontal64.tga", tint = true },
  { key = "theme", labelKey = "SETTINGS_CAT_THEME", build = BuildThemeFields, buildPreview = BuildColumnsPreview,
    buildPreviewVertical = BuildColumnsPreviewVertical, resettable = true,
    icon = "Interface\\AddOns\\GG\\Media\\Palette64.tga", tint = true },
  { key = "bosses", labelKey = "SETTINGS_CAT_BOSSES", build = BuildBossesFields, buildPreview = BuildBossesPreview,
    buildPreviewVertical = BuildBossesPreviewVertical, resettable = true,
    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
  { key = "window", labelKey = "SETTINGS_CAT_WINDOW", build = BuildWindowFields, buildPreview = BuildWindowPreview,
    resettable = true, icon = Theme.media.logoIcon, tint = true },
  { key = "account", labelKey = "SETTINGS_CAT_ACCOUNT", build = BuildAccountFields, buildPreview = BuildAccountPreview,
    icon = "Interface\\AddOns\\GG\\Media\\Characters64.tga", tint = true },
  { key = "announcements", labelKey = "SETTINGS_CAT_ANNOUNCEMENTS", build = BuildAnnouncementsFields, buildPreview = BuildAnnouncementsPreview,
    resettable = true, icon = "Interface\\GossipFrame\\GossipGossipIcon" },
  { key = "popups", labelKey = "SETTINGS_CAT_POPUPS", build = BuildPopupsFields,
    resettable = true, icon = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew" },
  { key = "profile", labelKey = "SETTINGS_CAT_PROFILE", build = BuildProfileFields,
    icon = "Interface\\AddOns\\GG\\Media\\Profile64.tga", tint = true },
}

BuildSidebar = function()
  local sidebar = CreateFrame("Frame", nil, panelFrame)
  sidebar:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", 0, 0)
  sidebar:SetPoint("BOTTOMLEFT", panelFrame, "BOTTOMLEFT", 0, 0)
  sidebar:SetWidth(SIDEBAR_WIDTH)
  local sidebarBg = sidebar:CreateTexture(nil, "BACKGROUND")
  sidebarBg:SetAllPoints()
  sidebarBg:SetColorTexture(unpack(NAV_BG))

  local divider = sidebar:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPRIGHT", 0, 0)
  divider:SetPoint("BOTTOMRIGHT", 0, 0)
  divider:SetWidth(1)
  divider:SetColorTexture(unpack(Theme.borderSoft))

  local y = 10
  for _, category in ipairs(CATEGORIES) do
    local btn = CreateFrame("Button", nil, sidebar)
    btn:SetHeight(32)
    btn:SetPoint("TOPLEFT", 0, -y)
    btn:SetPoint("RIGHT", 0, 0)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:Hide()

    btn.accent = btn:CreateTexture(nil, "ARTWORK")
    btn.accent:SetPoint("TOPLEFT")
    btn.accent:SetPoint("BOTTOMLEFT")
    btn.accent:SetWidth(3)
    btn.accent:SetColorTexture(unpack(Theme.accent))
    btn.accent:Hide()

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(15, 15)
    btn.icon:SetPoint("LEFT", 14, 0)
    if category.icon then btn.icon:SetTexture(category.icon) end
    btn.tint = category.tint

    btn.label = CreateLabel(btn, 12, Theme.textMuted)
    btn.label:SetPoint("LEFT", btn.icon, "RIGHT", 9, 0)
    btn.label:SetText(L[category.labelKey])

    local key = category.key
    btn:SetScript("OnClick", function() SelectCategory(key) end)
    btn:SetScript("OnEnter", function()
      if activeCategory ~= key then
        btn.bg:SetColorTexture(1, 1, 1, 0.04)
        btn.bg:Show()
      end
    end)
    btn:SetScript("OnLeave", function() if activeCategory ~= key then btn.bg:Hide() end end)

    sidebarButtons[key] = btn
    y = y + 32
  end
end

BuildPanel = function(parent, anchorBelow)
  panelFrame = CreateFrame("Frame", nil, parent)
  panelFrame:SetPoint("TOPLEFT", anchorBelow, "BOTTOMLEFT", 0, 0)
  panelFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

  BuildSidebar()

  previewFrame = CreateFrame("Frame", nil, panelFrame)
  previewBottomFrame = previewFrame
  previewFrame:SetPoint("BOTTOMLEFT", panelFrame, "BOTTOMLEFT", SIDEBAR_WIDTH, 0)
  previewFrame:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", 0, 0)
  previewFrame:SetHeight(PREVIEW_HEIGHT)
  local previewBg = previewFrame:CreateTexture(nil, "BACKGROUND")
  previewBg:SetAllPoints()
  previewBg:SetColorTexture(unpack(Theme.panel))
  local previewDivider = previewFrame:CreateTexture(nil, "ARTWORK")
  previewDivider:SetPoint("TOPLEFT", 0, 0)
  previewDivider:SetPoint("TOPRIGHT", 0, 0)
  previewDivider:SetHeight(1)
  previewDivider:SetColorTexture(unpack(Theme.borderSoft))
  local previewLabel = CreateLabel(previewFrame, 10, Theme.textFaint, true)
  previewLabel:SetPoint("TOPLEFT", CONTENT_PADDING, -8)
  previewLabel:SetText(L["SETTINGS_PREVIEW_LABEL"])
  previewInner = CreateFrame("Frame", nil, previewFrame)
  previewInner:SetPoint("TOPLEFT", CONTENT_PADDING, -26)
  previewInner:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING, 10)
  previewBottomInner = previewInner

  previewSideFrame = CreateFrame("Frame", nil, panelFrame)
  previewSideFrame:SetPoint("TOPRIGHT", panelFrame, "TOPRIGHT", 0, 0)
  previewSideFrame:SetPoint("BOTTOMRIGHT", panelFrame, "BOTTOMRIGHT", 0, 0)
  previewSideFrame:SetWidth(SIDE_PREVIEW_WIDTH)
  local sideBg = previewSideFrame:CreateTexture(nil, "BACKGROUND")
  sideBg:SetAllPoints()
  sideBg:SetColorTexture(unpack(Theme.panel))
  local sideDivider = previewSideFrame:CreateTexture(nil, "ARTWORK")
  sideDivider:SetPoint("TOPLEFT", 0, 0)
  sideDivider:SetPoint("BOTTOMLEFT", 0, 0)
  sideDivider:SetWidth(1)
  sideDivider:SetColorTexture(unpack(Theme.borderSoft))
  local sideLabel = CreateLabel(previewSideFrame, 10, Theme.textFaint, true)
  sideLabel:SetPoint("TOPLEFT", CONTENT_PADDING, -8)
  sideLabel:SetText(L["SETTINGS_PREVIEW_LABEL"])
  previewSideInner = CreateFrame("Frame", nil, previewSideFrame)
  previewSideInner:SetPoint("TOPLEFT", CONTENT_PADDING, -26)
  previewSideInner:SetPoint("BOTTOMRIGHT", -CONTENT_PADDING, 10)
  previewSideFrame:Hide()

  contentClip = CreateFrame("Frame", nil, panelFrame)
  contentClip:SetPoint("TOPLEFT", panelFrame, "TOPLEFT", SIDEBAR_WIDTH + CONTENT_PADDING, -CONTENT_PADDING)
  contentClip:SetPoint("BOTTOMRIGHT", previewFrame, "TOPRIGHT", -CONTENT_PADDING - SCROLLBAR_GUTTER, CONTENT_PADDING)
  contentClip:SetClipsChildren(true)
  contentClip:EnableMouseWheel(true)
  contentClip:SetScript("OnMouseWheel", function(_, delta)
    contentScrollbar:SetValue(scrollOffset - delta * 30)
  end)

  contentInner = CreateFrame("Frame", nil, contentClip)
  contentInner:SetPoint("TOPLEFT", contentClip, "TOPLEFT", 0, 0)
  contentInner:SetPoint("RIGHT", contentClip, "RIGHT", 0, 0)
  contentInner:SetHeight(1)

  contentScrollbar = CreateFrame("Slider", "GGSettingsScrollBar", panelFrame, "UIPanelScrollBarTemplate")
  contentScrollbar:SetPoint("TOPLEFT", contentClip, "TOPRIGHT", 6, 0)
  contentScrollbar:SetPoint("BOTTOMLEFT", contentClip, "BOTTOMRIGHT", 6, 0)
  contentScrollbar:SetScript("OnValueChanged", function(_, value)
    local newOffset = math.floor(value + 0.5)
    if newOffset == scrollOffset then return end
    scrollOffset = newOffset
    contentInner:ClearAllPoints()
    contentInner:SetPoint("TOPLEFT", contentClip, "TOPLEFT", 0, scrollOffset)
    contentInner:SetPoint("RIGHT", contentClip, "RIGHT", 0, 0)
  end)
  contentScrollbar:SetMinMaxValues(0, 0)
  contentScrollbar:SetValueStep(1)
  contentScrollbar:SetValue(0)
  Widgets.SkinScrollbar(contentScrollbar)

  toolbar = CreateFrame("Frame", nil, panelFrame)
  toolbar:SetHeight(TOOLBAR_HEIGHT - 6)
  toolbar:SetPoint("BOTTOMLEFT", contentClip, "TOPLEFT", 0, 8)
  toolbar:SetPoint("BOTTOMRIGHT", contentClip, "TOPRIGHT", 0, 8)
  toolbar.title = CreateLabel(toolbar, 14, Theme.textPrimary, true)
  toolbar.title:SetPoint("LEFT", 0, 0)
  toolbar.note = CreateLabel(toolbar, 11, Theme.textFaint)
  toolbar.note:SetPoint("LEFT", toolbar.title, "RIGHT", 12, -1)
  toolbar.note:SetText(L["SETTINGS_TOOLBAR_NOTE"])
  toolbar.reset = Widgets.CreateButton(toolbar, L["SETTINGS_RESET_SECTION"], function(self)
    local key = toolbar.reset.categoryKey
    if not key then return end
    for _, c in ipairs(CATEGORIES) do
      if c.key == key then StaticPopup_Show("GG_RESET_SETTINGS_SECTION", L[c.labelKey], nil, key) end
    end
  end)
  toolbar.reset:SetPoint("RIGHT", 0, 0)
end

local function ResetSection(key)
  GG:ResetOptionsSection(key)
  local options = GGDB.options
  if key == "window" then
    local icon = LibStub("LibDBIcon-1.0", true)
    if icon then
      icon:Show(ADDON_NAME)
      icon:Unlock(ADDON_NAME)
    end
    if GG.RosterUI.ApplyScale then GG.RosterUI:ApplyScale(options.windowScale) end
    if GG.RosterUI.ApplyOpacity then GG.RosterUI:ApplyOpacity(options.windowOpacity) end
    if GG.RosterUI.ApplyEscBehavior then GG.RosterUI:ApplyEscBehavior() end
    if GG.RosterUI.ApplyLayoutMode then GG.RosterUI:ApplyLayoutMode() end
  end
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
  if GG.RosterUI and GG.RosterUI.Relayout then GG.RosterUI:Relayout() end
  if GG.RaidTab and GG.RaidTab.Refresh then GG.RaidTab:Refresh() end
  SelectCategory(key)
end

StaticPopupDialogs["GG_RESET_SETTINGS_SECTION"] = {
  text = L["SETTINGS_RESET_CONFIRM"],
  button1 = YES,
  button2 = NO,
  OnAccept = function(_, data) if data then ResetSection(data) end end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function GG.UI:OnRosterLayoutChanged()
  if panelFrame and panelFrame:IsShown() and activeCategory then
    SelectCategory(activeCategory)
  end
end

function GG.UI:SettingsWindowWidth()
  local key = activeCategory or CATEGORIES[1].key
  local category
  for _, c in ipairs(CATEGORIES) do
    if c.key == key then category = c end
  end
  local vertical = GG.RosterUI and GG.RosterUI.IsVertical and GG.RosterUI:IsVertical()
  if category and category.buildPreviewVertical then
    return vertical and SETTINGS_WIDTH_SIDE_PREVIEW or nil
  end
  return SETTINGS_WIDTH
end

function GG.UI:GetSettingsFields(categoryKey, ids)
  for _, category in ipairs(CATEGORIES) do
    if category.key == categoryKey then
      local byId = {}
      for _, field in ipairs(category.build()) do
        if type(field) == "table" and field.id then byId[field.id] = field end
      end
      local out = {}
      for _, id in ipairs(ids) do
        if byId[id] then table.insert(out, byId[id]) end
      end
      return out
    end
  end
  return {}
end

function GG.UI:RenderFieldList(container, fields, width)
  return RenderFieldList(container, fields, width)
end

function GG.UI:ShowSettingsPanel(parent, anchorBelow)
  if not panelFrame then BuildPanel(parent, anchorBelow) end
  panelFrame:Show()
  SelectCategory(activeCategory or CATEGORIES[1].key)
end

function GG.UI:HideSettingsPanel()
  if panelFrame then panelFrame:Hide() end
end

function GG.UI:IsSettingsPanelShown()
  return panelFrame ~= nil and panelFrame:IsShown()
end

function GG.UI:RefreshSettingsIfShown()
  if self:IsSettingsPanelShown() then RerenderActiveFields() end
end
