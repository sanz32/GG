local ADDON_NAME, GG = ...

GG.Widgets = {}
local Widgets = GG.Widgets

local CLASS_ICON_SHEET = [[Interface\Glues\CharacterCreate\UI-CharacterCreate-Classes]]
local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"
function Widgets.SetItemIcon(texture, fileID, fallback)
  if not texture then return end
  texture:SetTexture((fileID and fileID ~= 0) and fileID or (fallback or QUESTION_MARK))
  texture:SetTexCoord(unpack(GG.Theme.iconCrop))
end

function Widgets.PreloadItems(links, onReady, timeout)
  local pending, finished = 0, false
  local scanning = true

  local function finish()
    if finished then return end
    finished = true
    onReady()
  end

  local function stepDone()
    pending = pending - 1
    if not scanning and pending <= 0 then finish() end
  end

  for _, link in ipairs(links or {}) do
    if type(link) == "string" and link ~= "" then
      local ok, item = pcall(function() return Item:CreateFromItemLink(link) end)
      if ok and item and not item:IsItemEmpty() and not item:IsItemDataCached() then
        pending = pending + 1
        item:ContinueOnItemLoad(stepDone)
      end
    end
  end

  scanning = false
  if pending <= 0 then
    finish()
  else
    C_Timer.After(timeout or 2, finish)
  end
end

function Widgets.SetClassIcon(texture, coords)
  if not texture then return end
  texture:SetTexture(CLASS_ICON_SHEET)
  if not coords then return end
  local inset = GG.Theme.iconCrop[1]
  local left, right, top, bottom = coords[1], coords[2], coords[3], coords[4]
  local w, h = right - left, bottom - top
  texture:SetTexCoord(left + w * inset, right - w * inset, top + h * inset, bottom - h * inset)
end

local CIRCLE_ATLAS = "CircleMaskScalable"

local function circleTexture(parent, layer)
  local tex = parent:CreateTexture(nil, layer or "ARTWORK")
  tex:SetAtlas(CIRCLE_ATLAS, false)
  return tex
end

local function unpackColor(c)
  return c[1], c[2], c[3], c[4] or 1
end

function Widgets.ApplyPanel(frame, opts)
  opts = opts or {}
  local Theme = GG.Theme
  local R = opts.radius or Theme.cornerRadius
  local corners = opts.corners or "all"
  local bg = opts.bg or Theme.background
  local topTint = opts.tint or Theme.gradientFrom
  local media = Theme.media

  local panel = { pieces = {}, frame = frame }

  local topR = (corners == "all" or corners == "top") and R or 0
  local bottomR = (corners == "all" or corners == "bottom") and R or 0

  if opts.glow then
    local glowInset = opts.glowInset or 80
    local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    glow:SetPoint("TOPLEFT", -glowInset, glowInset)
    glow:SetPoint("BOTTOMRIGHT", glowInset, -glowInset)
    glow:SetTexture(media.glowHalo)
    glow:SetBlendMode("ADD")
    panel.glow = glow
  end

  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 0,
    insets = { left = 0, right = 0, top = topR, bottom = bottomR },
  })
  frame:SetBackdropColor(unpackColor(bg))
  panel.bg = bg

  local function corner(point, flipH, flipV)
    local c = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    c:SetTexture(media.cornerMask)
    c:SetSize(R, R)
    c:SetPoint(point)
    c:SetTexCoord(flipH and 1 or 0, flipH and 0 or 1, flipV and 1 or 0, flipV and 0 or 1)
    c:SetVertexColor(unpackColor(bg))
    table.insert(panel.pieces, c)
    return c
  end

  local function midStrip(anchorL, anchorR, tint)
    local strip = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    strip:SetPoint("TOPLEFT", anchorL, "TOPRIGHT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", anchorR, "BOTTOMLEFT", 0, 0)
    strip:SetColorTexture(unpackColor(tint or bg))
    table.insert(panel.pieces, strip)
    return strip
  end

  if topR > 0 then
    local tl = corner("TOPLEFT", false, false)
    local tr = corner("TOPRIGHT", true, false)
    tl:SetVertexColor(unpackColor(topTint))
    tr:SetVertexColor(unpackColor(topTint))
    midStrip(tl, tr, topTint)
  end
  if bottomR > 0 then
    local bl = corner("BOTTOMLEFT", false, true)
    local br = corner("BOTTOMRIGHT", true, true)
    midStrip(bl, br, bg)
  end

  if opts.logo then
    local logo = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    logo:SetTexture(media.logo)
    local size = opts.logoSize or 240
    logo:SetSize(size, size)
    logo:SetPoint("BOTTOMRIGHT", -R, R)
    logo:SetAlpha(opts.logoAlpha or 0.05)
    panel.logo = logo
  end

  function panel.SetAlpha(alpha)
    alpha = alpha or 1.0
    frame:SetBackdropColor(bg[1], bg[2], bg[3], alpha)
    for _, piece in ipairs(panel.pieces) do
      piece:SetAlpha(alpha)
    end
  end

  return panel
end

function Widgets.CreateSeparator(parent)
  local tex = parent:CreateTexture(nil, "ARTWORK")
  tex:SetTexture(GG.Theme.media.glowSeparator)
  tex:SetHeight(6)
  return tex
end

function Widgets.SkinScrollbar(slider)
  local Theme = GG.Theme
  local name = slider:GetName()

  for _, suffix in ipairs({ "ScrollUpButton", "ScrollDownButton" }) do
    local btn = name and _G[name .. suffix]
    if btn then
      btn:Hide()
      btn:SetAlpha(0)
    end
  end
  if slider.Background then slider.Background:Hide() end
  if slider.Track then slider.Track:Hide() end

  local horizontal = slider.GetOrientation and slider:GetOrientation() == "HORIZONTAL"

  local track = slider:CreateTexture(nil, "BACKGROUND")
  if horizontal then
    track:SetPoint("LEFT", 2, 0)
    track:SetPoint("RIGHT", -2, 0)
    track:SetHeight(2)
  else
    track:SetPoint("TOP", 0, -2)
    track:SetPoint("BOTTOM", 0, 2)
    track:SetWidth(2)
  end
  track:SetColorTexture(1, 1, 1, 0.06)

  local thumb = circleTexture(slider)
  thumb:SetSize(horizontal and 26 or 6, horizontal and 6 or 26)
  thumb:SetVertexColor(unpackColor(Theme.accent))
  slider:SetThumbTexture(thumb)
end

function Widgets.CreateSwitch(parent, checked, onChange)
  local Theme = GG.Theme
  local W, H, KNOB = 44, 22, 16

  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(W, H)

  local track = btn:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetTexture("Interface\\AddOns\\GG\\Media\\SwitchTrack128.tga")

  local knob = btn:CreateTexture(nil, "ARTWORK")
  knob:SetSize(KNOB, KNOB)
  knob:SetTexture("Interface\\AddOns\\GG\\Media\\SwitchKnob64.tga")

  local text = btn:CreateFontString(nil, "OVERLAY")
  text:SetFont(Theme.fontBold, 8.5, "")

  local state = { checked = not not checked }

  local function paint()
    knob:ClearAllPoints()
    text:ClearAllPoints()
    if state.checked then
      track:SetVertexColor(unpackColor(Theme.accent))
      knob:SetVertexColor(1, 1, 1, 1)
      knob:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
      text:SetPoint("LEFT", btn, "LEFT", 7, 0)
      text:SetTextColor(unpackColor(Theme.onAccent))
      text:SetText("ON")
    else
      track:SetVertexColor(0.208, 0.231, 0.294, 1)
      knob:SetVertexColor(0.604, 0.627, 0.682, 1)
      knob:SetPoint("LEFT", btn, "LEFT", 3, 0)
      text:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
      text:SetTextColor(0.545, 0.565, 0.627, 1)
      text:SetText("OFF")
    end
  end

  btn:SetScript("OnClick", function()
    state.checked = not state.checked
    paint()
    if onChange then onChange(state.checked) end
  end)

  paint()

  btn.SetChecked = function(_, value)
    state.checked = not not value
    paint()
  end
  btn.GetChecked = function() return state.checked end

  return btn
end

function Widgets.CreateToggle(parent, checked, onChange)
  local Theme = GG.Theme
  local SIZE = 16

  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(SIZE, SIZE)

  local border = btn:CreateTexture(nil, "BACKGROUND")
  border:SetAllPoints()

  local fill = btn:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 2, -2)
  fill:SetPoint("BOTTOMRIGHT", -2, 2)

  local state = { checked = not not checked }

  local function paint()
    local borderColor = state.checked and Theme.accent or Theme.borderSoft
    border:SetColorTexture(unpackColor(borderColor))
    local fillColor = state.checked and Theme.accent or Theme.background
    fill:SetColorTexture(unpackColor(fillColor))
  end

  btn:SetScript("OnClick", function()
    state.checked = not state.checked
    paint()
    if onChange then onChange(state.checked) end
  end)

  paint()

  btn.SetChecked = function(_, value)
    state.checked = not not value
    paint()
  end
  btn.GetChecked = function() return state.checked end

  return btn
end

function Widgets.CreateSlider(parent, opts)
  local Theme = GG.Theme
  opts = opts or {}
  local width = opts.width or 160

  local slider = CreateFrame("Slider", nil, parent)
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(width, 16)
  slider:EnableMouse(true)
  slider:SetMinMaxValues(opts.min or 0, opts.max or 1)
  slider:SetValueStep(opts.step or 0.01)
  slider:SetObeyStepOnDrag(true)

  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT", 0, 0)
  track:SetPoint("RIGHT", 0, 0)
  track:SetHeight(2)
  track:SetColorTexture(1, 1, 1, 0.10)

  local fill = slider:CreateTexture(nil, "BACKGROUND", nil, 1)
  fill:SetPoint("LEFT", track, "LEFT", 0, 0)
  fill:SetHeight(2)
  fill:SetColorTexture(unpackColor(Theme.accent))

  local thumb = circleTexture(slider, "OVERLAY")
  thumb:SetSize(14, 14)
  thumb:SetVertexColor(unpackColor(Theme.accent))
  slider:SetThumbTexture(thumb)

  local function updateFill()
    local lo, hi = slider:GetMinMaxValues()
    local value = slider:GetValue()
    local pct = (hi > lo) and ((value - lo) / (hi - lo)) or 0
    fill:SetWidth(math.max(0.001, width * pct))
  end

  slider:SetScript("OnValueChanged", function(_, value)
    updateFill()
    if opts.onChange then opts.onChange(value) end
  end)

  slider:SetValue(opts.value or opts.min or 0)

  return slider
end

Widgets.MENU_BG = { 0.169, 0.188, 0.231, 1 }
Widgets.MENU_BORDER = { 0.271, 0.294, 0.349, 1 }

function Widgets.StyleMenu(frame)
  if frame.ggMenuStyled then return end
  frame.ggMenuStyled = true
  for _, layer in ipairs({ { 2, 0.40 }, { 5, 0.24 }, { 9, 0.13 }, { 14, 0.06 } }) do
    local shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetColorTexture(0, 0, 0, layer[2])
    shadow:SetPoint("TOPLEFT", -layer[1], layer[1] - 4)
    shadow:SetPoint("BOTTOMRIGHT", layer[1], -layer[1] - 4)
  end
  local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  bg:SetAllPoints()
  bg:SetColorTexture(unpackColor(Widgets.MENU_BG))
  local function Edge(p1, p2, horizontal)
    local edge = frame:CreateTexture(nil, "BORDER")
    edge:SetColorTexture(unpackColor(Widgets.MENU_BORDER))
    edge:SetPoint(p1)
    edge:SetPoint(p2)
    if horizontal then edge:SetHeight(1) else edge:SetWidth(1) end
  end
  Edge("TOPLEFT", "TOPRIGHT", true)
  Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  Edge("TOPLEFT", "BOTTOMLEFT", false)
  Edge("TOPRIGHT", "BOTTOMRIGHT", false)
end

local menuVeil

function Widgets.ShowMenuVeil(trigger, menu)
  if not (trigger and menu) then return end
  local window = trigger
  while window:GetParent() and window:GetParent() ~= UIParent do window = window:GetParent() end
  if not menuVeil then
    menuVeil = CreateFrame("Frame", nil, UIParent)
    menuVeil:SetFrameStrata("FULLSCREEN_DIALOG")
    menuVeil.parts = {}
    for i = 1, 4 do
      local part = menuVeil:CreateTexture(nil, "BACKGROUND")
      part:SetColorTexture(0, 0, 0, 0.55)
      menuVeil.parts[i] = part
    end
  end
  menuVeil:SetFrameLevel(1)
  if menu:GetFrameLevel() < 5 then menu:SetFrameLevel(5) end
  menuVeil:ClearAllPoints()
  menuVeil:SetAllPoints(window)
  local top, bottom, left, right = unpack(menuVeil.parts)
  for _, part in ipairs(menuVeil.parts) do part:ClearAllPoints() end
  top:SetPoint("TOPLEFT", window, "TOPLEFT")
  top:SetPoint("TOPRIGHT", window, "TOPRIGHT")
  top:SetPoint("BOTTOM", trigger, "TOP")
  bottom:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT")
  bottom:SetPoint("TOP", trigger, "BOTTOM")
  local veilScale = menuVeil:GetEffectiveScale()
  local function X(frame, edge)
    local value = edge == "left" and frame:GetLeft() or frame:GetRight()
    return (value or 0) * frame:GetEffectiveScale() / veilScale
  end
  left:SetPoint("TOPRIGHT", trigger, "TOPLEFT")
  left:SetPoint("BOTTOMRIGHT", trigger, "BOTTOMLEFT")
  left:SetWidth(math.max(0.01, X(trigger, "left") - X(window, "left")))
  right:SetPoint("TOPLEFT", trigger, "TOPRIGHT")
  right:SetPoint("BOTTOMLEFT", trigger, "BOTTOMRIGHT")
  right:SetWidth(math.max(0.01, X(window, "right") - X(trigger, "right")))
  menuVeil.owner = menu
  menuVeil:Show()
end

function Widgets.HideMenuVeil(menu)
  if menuVeil and (menu == nil or menuVeil.owner == menu) then
    menuVeil.owner = nil
    menuVeil:Hide()
  end
end

local activeDropdownClose

local dropdownInstanceCount = 0

function Widgets.CreateDropdown(parent, opts)
  local Theme = GG.Theme
  opts = opts or {}
  local width = opts.width or 160
  local ROW_HEIGHT = 22

  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(width, 24)
  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  btn:SetBackdropColor(1, 1, 1, 0.04)
  btn:SetBackdropBorderColor(unpackColor(Theme.borderSoft))

  local label = btn:CreateFontString(nil, "OVERLAY")
  label:SetFont(Theme.font, 11, "")
  label:SetTextColor(unpackColor(Theme.textPrimary))
  label:SetPoint("LEFT", 8, 0)
  label:SetPoint("RIGHT", -18, 0)
  label:SetJustifyH("LEFT")
  label:SetWordWrap(false)

  local arrow = btn:CreateFontString(nil, "OVERLAY")
  arrow:SetFont(Theme.font, 10, "")
  arrow:SetTextColor(unpackColor(Theme.textFaint))
  arrow:SetPoint("RIGHT", -8, 0)
  arrow:SetText("v")

  local list

  local function resolveValues()
    if type(opts.values) == "function" then return opts.values() end
    return opts.values or {}
  end

  local function labelForKey(key)
    for _, entry in ipairs(resolveValues()) do
      if entry.key == key then return entry.label end
    end
    return ""
  end

  local function RefreshLabel()
    label:SetText(labelForKey(opts.get and opts.get() or nil))
  end

  local function CloseList()
    if list then list:Hide() end
    if activeDropdownClose == CloseList then activeDropdownClose = nil end
  end

  local function OpenList()
    if activeDropdownClose then activeDropdownClose() end
    activeDropdownClose = CloseList

    local values = resolveValues()
    if not list then
      dropdownInstanceCount = dropdownInstanceCount + 1
      local listName = "GGDropdownList" .. dropdownInstanceCount

      list = CreateFrame("Frame", listName, UIParent, "BackdropTemplate")
      list:SetFrameStrata("FULLSCREEN_DIALOG")
      list:SetToplevel(true)
      GG.Widgets.StyleMenu(list)

      tinsert(UISpecialFrames, listName)

      list:SetScript("OnEvent", function(self, event)
        if event ~= "GLOBAL_MOUSE_DOWN" then return end
        if self:IsMouseOver() then return end
        if btn:IsMouseOver() then return end
        CloseList()
      end)
      list:SetScript("OnShow", function(self) self:RegisterEvent("GLOBAL_MOUSE_DOWN") end)
      list:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        if activeDropdownClose == CloseList then activeDropdownClose = nil end
        GG.Widgets.HideMenuVeil(self)
        if btn.ggClosedBorder then
          btn:SetBackdropBorderColor(unpack(btn.ggClosedBorder))
          btn.ggClosedBorder = nil
        end
      end)

      list.rows = {}
    end

    local currentKey = opts.get and opts.get() or nil

    for _, row in ipairs(list.rows) do row:Hide() end
    list:SetWidth(opts.listWidth or width)
    local y = 2
    for i, entry in ipairs(values) do
      local row = list.rows[i]
      if not row then
        row = CreateFrame("Button", nil, list)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, 0.08)
        row.bg:Hide()
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetFont(Theme.font, 11, "")
        row.text:SetJustifyH("LEFT")
        row.desc = row:CreateFontString(nil, "OVERLAY")
        row.desc:SetFont(Theme.font, 10, "")
        row.desc:SetJustifyH("LEFT")
        row.desc:SetTextColor(unpackColor(Theme.textFaint))
        row:SetScript("OnEnter", function(self) if not self.isHeader then self.bg:Show() end end)
        row:SetScript("OnLeave", function(self) self.bg:Hide() end)
        list.rows[i] = row
      end
      if not row.rule then
        row.rule = row:CreateTexture(nil, "ARTWORK")
        row.rule:SetColorTexture(unpackColor(Widgets.MENU_BORDER))
        row.rule:SetHeight(1)
        row.rule:SetPoint("TOPLEFT", 6, -3)
        row.rule:SetPoint("TOPRIGHT", -6, -3)
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetColorTexture(unpackColor(Theme.accent))
        row.mark:SetWidth(2)
        row.mark:SetPoint("TOPLEFT", 0, -3)
        row.mark:SetPoint("BOTTOMLEFT", 0, 3)
        row.selBg = row:CreateTexture(nil, "BACKGROUND")
        row.selBg:SetAllPoints()
        row.selBg:SetColorTexture(1, 1, 1, 0.05)
      end
      row.isHeader = entry.header ~= nil
      local height = ROW_HEIGHT
      if row.isHeader then
        height = i == 1 and 22 or 30
      elseif entry.desc then
        height = 32
      end
      row:SetHeight(height)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", 2, -y)
      row:SetPoint("RIGHT", -2, 0)
      y = y + height
      row.text:ClearAllPoints()
      row.desc:SetShown(entry.desc ~= nil and not row.isHeader)
      row.rule:SetShown(row.isHeader and i > 1)
      local selected = not row.isHeader and entry.key == currentKey
      row.mark:SetShown(selected)
      row.selBg:SetShown(selected)
      if row.isHeader then
        row.text:SetPoint("BOTTOMLEFT", 8, 4)
        row.text:SetText(entry.header)
        row.text:SetFont(Theme.fontBold, 12, "")
        row.text:SetTextColor(unpackColor(Theme.accent))
        row:SetScript("OnClick", nil)
      else
        if entry.desc then
          row.text:SetPoint("TOPLEFT", 8, -4)
          row.desc:ClearAllPoints()
          row.desc:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", 0, -2)
          row.desc:SetText(entry.desc)
        else
          row.text:SetPoint("LEFT", 8, 0)
        end
        row.text:SetText(entry.label)
        if selected then
          row.text:SetFont(Theme.fontBold, 11, "")
          row.text:SetTextColor(unpackColor(Theme.textPrimary))
        else
          row.text:SetFont(Theme.font, 11, "")
          row.text:SetTextColor(unpackColor(Theme.textPrimary))
        end
        row:SetScript("OnClick", function()
          if opts.set then opts.set(entry.key) end
          RefreshLabel()
          CloseList()
        end)
      end
      row:Show()
    end
    list:SetHeight(y + 2)
    list:ClearAllPoints()
    if opts.listAlign == "LEFT" then
      list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -6)
    else
      list:SetPoint("TOP", btn, "BOTTOM", 0, -6)
    end
    list:Show()
    if btn.GetBackdropBorderColor and not btn.ggClosedBorder then
      btn.ggClosedBorder = { btn:GetBackdropBorderColor() }
      btn:SetBackdropBorderColor(unpackColor(Theme.accent))
    end
    GG.Widgets.ShowMenuVeil(btn, list)
  end

  btn:SetScript("OnClick", function()
    if list and list:IsShown() then CloseList() else OpenList() end
  end)
  btn:SetScript("OnHide", CloseList)

  RefreshLabel()
  btn.Refresh = RefreshLabel
  btn.label = label
  btn.arrow = arrow
  return btn
end

function Widgets.CreateButton(parent, text, onClick)
  local Theme = GG.Theme

  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetHeight(24)
  btn:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  btn:SetBackdropColor(1, 1, 1, 0.04)
  btn:SetBackdropBorderColor(unpackColor(Theme.borderSoft))

  local label = btn:CreateFontString(nil, "OVERLAY")
  label:SetFont(Theme.font, 11, "")
  label:SetTextColor(unpackColor(Theme.textPrimary))
  label:SetPoint("CENTER")
  label:SetText(text)
  btn:SetWidth(label:GetStringWidth() + 24)

  local isDisabled = false
  btn:SetScript("OnEnter", function() if not isDisabled then btn:SetBackdropColor(1, 1, 1, 0.09) end end)
  btn:SetScript("OnLeave", function() btn:SetBackdropColor(1, 1, 1, 0.04) end)
  btn:SetScript("OnClick", function()
    if isDisabled then return end
    if onClick then onClick() end
  end)

  btn.label = label
  btn.SetDisabled = function(_, disabled)
    isDisabled = not not disabled
    label:SetAlpha(isDisabled and 0.4 or 1)
  end

  return btn
end
