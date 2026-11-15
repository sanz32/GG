local ADDON_NAME, GG = ...

local OT = {}
GG.OverflowTabs = OT

local MEDIA = "Interface\\AddOns\\GG\\Media\\"
local R = 13
local H = 2 * R
local SHADOW_REACH = 8
local CHEV = 12
local CHEV_STEP = 6
local FONT_SIZE = 15

OT.HEIGHT = H
OT.COLUMNS_Y = 80
OT.LINE_INSET = 4
OT.PERIOD = 1.2
OT.STEP = 0.2
OT.LOW = 0.25

local INK = { 0.063, 0.078, 0.106 }
local INK_HOVER = { 0.11, 0.13, 0.17 }
local BACK_RING = { 0.29, 0.33, 0.38 }
local BACK_CHEV = { 0.68, 0.71, 0.74 }
local BACK_TEXT = { 0.81, 0.83, 0.85 }

function OT.Counts(total, offset, visible)
  total = math.max(0, math.floor(tonumber(total) or 0))
  visible = math.max(0, math.floor(tonumber(visible) or 0))
  offset = math.floor(tonumber(offset) or 0)
  offset = math.max(0, math.min(offset, math.max(0, total - visible)))
  return offset, math.max(0, total - offset - visible)
end

function OT.RevealOffset(total, index, visible, offset)
  total = math.max(0, math.floor(tonumber(total) or 0))
  visible = math.max(1, math.floor(tonumber(visible) or 1))
  offset = math.floor(tonumber(offset) or 0)
  index = tonumber(index)
  if index and index >= 1 and index <= total then
    if index - 1 < offset then
      offset = index - 1
    elseif index > offset + visible then
      offset = index - visible
    end
  end
  return math.max(0, math.min(offset, math.max(0, total - visible)))
end

function OT.ChevronAlpha(t, i)
  local low = OT.LOW
  local p = ((t - i * OT.STEP) % OT.PERIOD) / OT.PERIOD
  if p < 0.4 then return low + (1 - low) * (p / 0.4) end
  return 1 - (1 - low) * ((p - 0.4) / 0.6)
end

local function Sliced(owner, layer, sublayer, file, margin)
  local t = GG.Widgets.NewRoundTexture(owner, layer, sublayer)
  t:SetTexture(MEDIA .. file)
  if t.SetTextureSliceMargins then
    t:SetTextureSliceMargins(margin, margin, margin, margin)
    local mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched
    if mode and t.SetTextureSliceMode then t:SetTextureSliceMode(mode) end
  end
  return t
end

local function Accent()
  local a = GG.Theme and GG.Theme.accent or { 1, 0.58, 0.1, 1 }
  return a[1], a[2], a[3]
end

local function Paint(b)
  local fill = b.hover and INK_HOVER or INK
  b.fill:SetVertexColor(fill[1], fill[2], fill[3], 0.97)
  if b.back then
    b.ring:SetVertexColor(BACK_RING[1], BACK_RING[2], BACK_RING[3], 1)
    b.text:SetTextColor(BACK_TEXT[1], BACK_TEXT[2], BACK_TEXT[3], 1)
    for _, c in ipairs(b.chev) do c:SetVertexColor(BACK_CHEV[1], BACK_CHEV[2], BACK_CHEV[3], 1) end
  else
    local r, g, bl = Accent()
    b.ring:SetVertexColor(r, g, bl, 1)
    b.text:SetTextColor(1, 1, 1, 1)
    for _, c in ipairs(b.chev) do c:SetVertexColor(r, g, bl, 1) end
  end
end

local function Animate(b)
  local now = GetTime and GetTime() or 0
  for i, c in ipairs(b.chev) do c:SetAlpha(OT.ChevronAlpha(now, i - 1)) end
end

local function NewTab(parent, back)
  local b = CreateFrame("Button", nil, parent)
  b.back = back
  b:SetSize(48, H)
  b:RegisterForClicks("LeftButtonUp")
  b.shadow = Sliced(b, "BACKGROUND", -2, "TabGlow13.tga", R + SHADOW_REACH)
  b.shadow:SetPoint("TOPLEFT", -SHADOW_REACH, SHADOW_REACH - 3)
  b.shadow:SetPoint("BOTTOMRIGHT", SHADOW_REACH, -SHADOW_REACH - 3)
  b.shadow:SetVertexColor(0, 0, 0, 0.6)
  b.fill = Sliced(b, "BACKGROUND", 0, "TabFill13.tga", R)
  b.fill:SetAllPoints(b)
  b.ring = Sliced(b, "BORDER", 0, "TabRing13.tga", R)
  b.ring:SetAllPoints(b)
  b.text = b:CreateFontString(nil, "OVERLAY")
  b.text:SetFont(GG.Theme.fontBold, FONT_SIZE, "")
  b.chev = {}
  for i = 1, 3 do
    local c = GG.Widgets.NewRoundTexture(b, "ARTWORK", 0)
    c:SetSize(CHEV, CHEV)
    b.chev[i] = c
  end
  b:SetScript("OnEnter", function(self) self.hover = true; Paint(self) end)
  b:SetScript("OnLeave", function(self) self.hover = false; Paint(self) end)
  b:Hide()
  return b
end

local function Layout(b, n, columns)
  b.text:SetText(b.back and tostring(n) or ("+" .. n))
  local tw = math.ceil(b.text:GetStringWidth() or 0)
  local dir = columns and (b.back and "L" or "R") or (b.back and "U" or "D")
  b.text:ClearAllPoints()
  for _, c in ipairs(b.chev) do
    c:SetTexture(MEDIA .. "TabChev" .. dir .. ".tga")
    c:ClearAllPoints()
  end
  local w
  if columns then
    if b.back then
      for i, c in ipairs(b.chev) do c:SetPoint("LEFT", b, "LEFT", 5 + (3 - i) * CHEV_STEP, 0) end
      b.text:SetPoint("LEFT", b, "LEFT", 28, 0)
      w = 28 + tw + 11
    else
      b.text:SetPoint("LEFT", b, "LEFT", 11, 0)
      for i, c in ipairs(b.chev) do c:SetPoint("LEFT", b, "LEFT", 11 + tw - 1 + (i - 1) * CHEV_STEP, 0) end
      w = 11 + tw + 28
    end
  else
    local top = (H - (CHEV + 10)) / 2
    if b.back then
      for i, c in ipairs(b.chev) do c:SetPoint("TOPLEFT", b, "TOPLEFT", 8, -(top + (3 - i) * 5)) end
      b.text:SetPoint("LEFT", b, "LEFT", 21, 0)
      w = 21 + tw + 11
    else
      b.text:SetPoint("LEFT", b, "LEFT", 11, 0)
      for i, c in ipairs(b.chev) do c:SetPoint("TOPLEFT", b, "TOPLEFT", 11 + tw + 1, -(top + (i - 1) * 5)) end
      w = 11 + tw + 1 + CHEV + 6
    end
  end
  b:SetWidth(w)
  return w
end

function OT:Create(window, clip, onPage)
  local o = { window = window, clip = clip }
  local level = (clip:GetFrameLevel() or 1) + 70
  o.lines = CreateFrame("Frame", nil, window)
  o.lines:SetAllPoints(clip)
  o.lines:SetFrameLevel(level - 5)
  o.endLine = o.lines:CreateTexture(nil, "OVERLAY")
  o.startLine = o.lines:CreateTexture(nil, "OVERLAY")
  o.endTab = NewTab(window, false)
  o.startTab = NewTab(window, true)
  o.endTab:SetFrameLevel(level)
  o.startTab:SetFrameLevel(level)
  o.endTab:SetScript("OnClick", function() onPage(1) end)
  o.startTab:SetScript("OnClick", function() onPage(-1) end)
  OT:Update(o, nil)
  return o
end

local function SetAnimated(b, on)
  if on then
    b:SetScript("OnUpdate", Animate)
  else
    b:SetScript("OnUpdate", nil)
    for _, c in ipairs(b.chev) do c:SetAlpha(1) end
  end
end

function OT:Update(o, info)
  if not o then return 0, 0 end
  if not info then
    o.endTab:Hide(); o.startTab:Hide(); o.endLine:Hide(); o.startLine:Hide()
    SetAnimated(o.endTab, false); SetAnimated(o.startTab, false)
    return 0, 0
  end
  local before, after = OT.Counts(info.total, info.offset, info.visible)
  local columns = info.columns and true or false
  local clip = o.clip
  local gap = tonumber(info.endGap) or 0

  o.endLine:ClearAllPoints()
  o.startLine:ClearAllPoints()
  if columns then
    o.endLine:SetPoint("TOPRIGHT", clip, "TOPRIGHT", 0, 0)
    o.endLine:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
    o.endLine:SetWidth(2)
    o.startLine:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
    o.startLine:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", 0, 0)
    o.startLine:SetWidth(2)
  else
    local inset, right = OT.LINE_INSET, gap - OT.LINE_INSET
    o.endLine:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", inset, 0)
    o.endLine:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", right, 0)
    o.endLine:SetHeight(2)
    o.startLine:SetPoint("TOPLEFT", clip, "TOPLEFT", inset, 0)
    o.startLine:SetPoint("TOPRIGHT", clip, "TOPRIGHT", right, 0)
    o.startLine:SetHeight(2)
  end
  local r, g, bl = Accent()
  o.endLine:SetColorTexture(r, g, bl, 0.9)
  o.startLine:SetColorTexture(1, 1, 1, 0.3)
  o.endLine:SetShown(after > 0)
  o.startLine:SetShown(before > 0)

  for _, pair in ipairs({ { o.endTab, after, o.endLine }, { o.startTab, before, o.startLine } }) do
    local b, n, line = pair[1], pair[2], pair[3]
    if n > 0 then
      Layout(b, n, columns)
      Paint(b)
      b:ClearAllPoints()
      if columns then
        if b.back then
          b:SetPoint("CENTER", clip, "TOPLEFT", 0, -OT.COLUMNS_Y)
        else
          b:SetPoint("CENTER", clip, "TOPRIGHT", gap - 0.5, -OT.COLUMNS_Y)
        end
      else
        b:SetPoint("CENTER", line, "CENTER", 0, 0)
      end
      SetAnimated(b, info.animate ~= false)
      b:Show()
    else
      SetAnimated(b, false)
      b:Hide()
    end
  end
  return before, after
end
