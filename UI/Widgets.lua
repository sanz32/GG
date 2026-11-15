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

  local bucket = Widgets.RoundBucket(R)
  local cornerFile = bucket > 0 and ("Interface\\AddOns\\GG\\Media\\RoundFill" .. bucket .. ".tga") or nil
  local k = bucket > 0 and bucket / (2 * bucket + 2) or 1
  local function corner(point, flipH, flipV)
    local c = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    c:SetSize(R, R)
    c:SetPoint(point)
    if cornerFile then
      c:SetTexture(cornerFile)
      c:SetTexCoord(flipH and 1 - k or 0, flipH and 1 or k, flipV and 1 - k or 0, flipV and 1 or k)
    else
      c:SetTexture(media.cornerMask)
      c:SetTexCoord(flipH and 1 or 0, flipH and 0 or 1, flipV and 1 or 0, flipV and 0 or 1)
    end
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

local ROUND_DIR = "Interface\\AddOns\\GG\\Media\\"

local function RoundBucket(r)
  local LY = GG.Layout
  if LY and LY.RoundBucket then return LY.RoundBucket(r) end
  r = tonumber(r) or 0
  if r <= 0 then return 0 end
  return math.max(2, math.min(10, math.floor(r + 0.5)))
end
Widgets.RoundBucket = RoundBucket

local function CanSlice(t)
  return type(t.SetTextureSliceMargins) == "function"
end

local function NewRoundTexture(owner, layer, sublayer)
  local t = owner:CreateTexture(nil, layer or "BACKGROUND", nil, sublayer or 0)
  if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
  if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
  return t
end
Widgets.NewRoundTexture = NewRoundTexture

local function ApplyRound(t, kind, r)
  local b = RoundBucket(r)
  if not CanSlice(t) then
    if kind == "RoundFill" then t:SetColorTexture(1, 1, 1, 1) end
    return false
  end
  if b == 0 and kind == "RoundFill" then
    t:SetTextureSliceMargins(0, 0, 0, 0)
    t:SetColorTexture(1, 1, 1, 1)
    return true
  end
  local m = b == 0 and 1 or b
  t:SetTexture(ROUND_DIR .. kind .. b .. ".tga")
  t:SetTextureSliceMargins(m, m, m, m)
  local mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched
  if mode and t.SetTextureSliceMode then t:SetTextureSliceMode(mode) end
  return true
end
Widgets.ApplyRound = ApplyRound

local ROUND_COORDS = {
  TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 },
  BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
}

local LegacyRoundedFill

function Widgets.RoundedFill(owner, anchor, radius, layer, sublayer)
  anchor = anchor or owner
  local tex = NewRoundTexture(owner, layer, sublayer)
  if not CanSlice(tex) then return LegacyRoundedFill(owner, anchor, radius, layer, sublayer, tex) end
  tex:SetAllPoints(anchor)
  local fill = { tex = tex, pieces = { tex } }

  function fill:SetRadius(r)
    r = math.max(0, r or 0)
    self.radius = r
    ApplyRound(self.tex, "RoundFill", r)
  end
  function fill:SetColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    self.tex:SetVertexColor(r, g, b, a or 1)
  end
  function fill:SetAlpha(a) self.tex:SetAlpha(a or 1) end
  function fill:SetShown(shown)
    self.hidden = not shown
    self.tex:SetShown(shown)
  end
  function fill:IsShown() return not self.hidden end
  function fill:Show() self:SetShown(true) end
  function fill:Hide() self:SetShown(false) end

  fill:SetRadius(radius)
  return fill
end

LegacyRoundedFill = function(owner, anchor, radius, layer, sublayer, first)
  local fill = { pieces = {}, corners = {} }
  local function Tex()
    local t = first or owner:CreateTexture(nil, layer or "BACKGROUND", nil, sublayer or 0)
    first = nil
    fill.pieces[#fill.pieces + 1] = t
    return t
  end
  fill.center = Tex()
  for point, coords in pairs(ROUND_COORDS) do
    local c = Tex()
    c:SetTexture(GG.Theme.media.cornerMask)
    c:SetTexCoord(unpack(coords))
    fill.corners[point] = c
  end
  fill.left, fill.right = Tex(), Tex()
  for _, t in ipairs({ fill.center, fill.left, fill.right }) do t:SetColorTexture(1, 1, 1, 1) end

  function fill:SetRadius(r)
    r = math.max(0, r or 0)
    self.radius = r
    for point, c in pairs(self.corners) do
      c:ClearAllPoints()
      c:SetPoint(point, anchor, point, 0, 0)
      c:SetSize(math.max(r, 0.001), math.max(r, 0.001))
      c:SetShown(r > 0 and not self.hidden)
    end
    local center, left, right = self.center, self.left, self.right
    center:ClearAllPoints()
    center:SetPoint("TOPLEFT", anchor, "TOPLEFT", r, 0)
    center:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -r, 0)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, -r)
    left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", r, r)
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", anchor, "TOPRIGHT", -r, -r)
    right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, r)
    left:SetShown(r > 0 and not self.hidden)
    right:SetShown(r > 0 and not self.hidden)
  end

  function fill:SetColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    for _, t in ipairs(self.pieces) do t:SetVertexColor(r, g, b, a or 1) end
  end

  function fill:SetShown(shown)
    self.hidden = not shown
    for _, t in ipairs(self.pieces) do t:SetShown(shown) end
    if shown then self:SetRadius(self.radius) end
  end
  function fill:SetAlpha(a) for _, t in ipairs(self.pieces) do t:SetAlpha(a or 1) end end
  function fill:IsShown() return not self.hidden end
  function fill:Show() self:SetShown(true) end
  function fill:Hide() self:SetShown(false) end

  fill:SetRadius(radius)
  return fill
end

local function AutoRadius(h)
  h = h or 0
  if h <= 0 then return 8 end
  if h < 20 then return 4 elseif h < 34 then return 6 elseif h < 100 then return 8 end
  return 9
end
Widgets.AutoRadius = AutoRadius

local function PlaceRings(state)
  local r = state.radius or 0
  local key = r * 8 + #state.rings
  local place = state.placed ~= key
  state.placed = key
  for i, ring in ipairs(state.rings) do
    if place then
      local inset = i - 1
      ring:ClearAllPoints()
      ring:SetPoint("TOPLEFT", state.frame, "TOPLEFT", inset, -inset)
      ring:SetPoint("BOTTOMRIGHT", state.frame, "BOTTOMRIGHT", -inset, inset)
      ApplyRound(ring, "RoundRing", r > 0 and math.max(2, r - inset) or 0)
    end
    ring:SetShown(state.ringShown and i <= state.edge)
  end
end

local function SetEdge(state, n)
  n = math.max(1, math.min(3, math.floor((n or 1) + 0.5)))
  state.edge = n
  local c = state.border
  while #state.rings < n do
    local ring = NewRoundTexture(state.frame, "BORDER", -7)
    ring:SetVertexColor(c[1], c[2], c[3], c[4])
    state.rings[#state.rings + 1] = ring
  end
  PlaceRings(state)
end

local function SetRadiusOf(state, radius)
  if state.radius == radius then return end
  state.radius = radius
  ApplyRound(state.fill, "RoundFill", radius)
  PlaceRings(state)
end

function Widgets.Backdrop(frame, bg, border, radius, edgeSize)
  local state = frame.ggBackdrop
  if not state then
    local fill = NewRoundTexture(frame, "BACKGROUND", -7)
    if not CanSlice(fill) then
      fill:Hide()
      if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = edgeSize or 1 })
        if bg then frame:SetBackdropColor(unpackColor(bg)) end
        if border then frame:SetBackdropBorderColor(unpackColor(border)) end
      end
      return
    end
    if frame.SetBackdrop and frame.backdropInfo then frame:SetBackdrop(nil) end
    state = {
      frame = frame, fill = fill, rings = { NewRoundTexture(frame, "BORDER", -7) },
      bg = { 1, 1, 1, 1 }, border = { 1, 1, 1, 1 }, edge = 1, ringShown = true,
    }
    state.ring = state.rings[1]
    state.fill:SetAllPoints(frame)
    frame.ggBackdrop = state

    function frame:SetBackdrop(info)
      state.fill:SetShown(info ~= nil and info.bgFile ~= nil)
      state.ringShown = info ~= nil and info.edgeFile ~= nil and (info.edgeSize or 1) > 0
      if state.ringShown then SetEdge(state, info.edgeSize or 1) else PlaceRings(state) end
    end
    function frame:SetBackdropColor(r, g, b, a)
      state.bg = { r or 1, g or 1, b or 1, a or 1 }
      state.fill:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
    end
    function frame:SetBackdropBorderColor(r, g, b, a)
      state.border = { r or 1, g or 1, b or 1, a or 1 }
      for _, ring in ipairs(state.rings) do ring:SetVertexColor(r or 1, g or 1, b or 1, a or 1) end
    end
    function frame:GetBackdropColor() return unpack(state.bg) end
    function frame:GetBackdropBorderColor() return unpack(state.border) end
    if frame.HookScript then
      frame:HookScript("OnSizeChanged", function(_, _, h)
        if state.auto then SetRadiusOf(state, AutoRadius(h)) end
      end)
    end
  end
  state.auto = radius == nil
  SetRadiusOf(state, radius or AutoRadius(frame:GetHeight()))
  state.ringShown = border ~= nil
  state.fill:SetShown(bg ~= nil)
  SetEdge(state, edgeSize or state.edge)
  if bg then frame:SetBackdropColor(unpackColor(bg)) end
  if border then frame:SetBackdropBorderColor(unpackColor(border)) end
  return state
end

function Widgets.TopBand(owner, inset, radius, height, layer, sublayer)
  inset = inset or 1
  local r = math.max(2, math.min(10, math.floor((radius or 8) - inset + 0.5)))
  local band = { owner = owner, r = r, height = height }
  local file = ROUND_DIR .. "RoundFill" .. r .. ".tga"
  local k = r / (2 * r + 2)
  local function Tex()
    local t = owner:CreateTexture(nil, layer or "BACKGROUND", nil, sublayer or 0)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    return t
  end
  band.tl, band.tr, band.top, band.body = Tex(), Tex(), Tex(), Tex()
  band.tl:SetTexture(file)
  band.tl:SetTexCoord(0, k, 0, k)
  band.tr:SetTexture(file)
  band.tr:SetTexCoord(1 - k, 1, 0, k)
  band.top:SetColorTexture(1, 1, 1, 1)
  band.body:SetColorTexture(1, 1, 1, 1)
  band.tl:SetSize(r, r)
  band.tr:SetSize(r, r)
  band.tl:SetPoint("TOPLEFT", owner, "TOPLEFT", inset, -inset)
  band.tr:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -inset, -inset)
  band.top:SetPoint("TOPLEFT", band.tl, "TOPRIGHT", 0, 0)
  band.top:SetPoint("BOTTOMRIGHT", band.tr, "BOTTOMLEFT", 0, 0)
  band.body:SetPoint("TOPLEFT", band.tl, "BOTTOMLEFT", 0, 0)
  band.body:SetPoint("TOPRIGHT", band.tr, "BOTTOMRIGHT", 0, 0)
  band.body:SetHeight(math.max(0.001, (height or r) - r))
  band.pieces = { band.tl, band.tr, band.top, band.body }

  function band:SetHeight(h)
    self.height = h
    self.body:SetHeight(math.max(0.001, (h or self.r) - self.r))
  end
  function band:SetGradientV(cr, cg, cb, aTop, aBottom)
    local h = math.max(self.height or self.r, self.r)
    local aMid = aTop + (aBottom - aTop) * (self.r / h)
    if CreateColor then
      local top, mid, bottom = CreateColor(cr, cg, cb, aTop), CreateColor(cr, cg, cb, aMid), CreateColor(cr, cg, cb, aBottom)
      for _, t in ipairs({ self.tl, self.tr, self.top }) do t:SetGradient("VERTICAL", mid, top) end
      self.body:SetGradient("VERTICAL", bottom, mid)
    else
      self:SetColor(cr, cg, cb, aTop)
    end
  end
  function band:SetColor(cr, cg, cb, a)
    for _, t in ipairs(self.pieces) do
      if t.SetGradient and CreateColor then
        local c = CreateColor(cr, cg, cb, a or 1)
        t:SetGradient("VERTICAL", c, c)
      else
        t:SetVertexColor(cr, cg, cb, a or 1)
      end
    end
  end
  function band:SetShown(shown) for _, t in ipairs(self.pieces) do t:SetShown(shown) end end
  function band:Show() self:SetShown(true) end
  function band:Hide() self:SetShown(false) end
  return band
end

function Widgets.ApplyPopup(frame, opts)
  opts = opts or {}
  local b = GG.Theme.background
  local solid = { b[1], b[2], b[3], 1 }
  local panel = Widgets.ApplyPanel(frame, { bg = solid, tint = solid, corners = "all", glow = opts.glow })
  if not frame.chrome then frame.chrome = Widgets.ApplyWindowChrome(frame) end
  return panel
end

function Widgets.TopAccent(frame, radius)
  local R = radius or GG.Theme.cornerRadius
  local bar = frame:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", R, 0)
  bar:SetPoint("TOPRIGHT", -R, 0)
  bar:SetHeight(2)
  function bar:Paint() self:SetColorTexture(unpackColor(GG.Theme.accent)) end
  bar:Paint()
  return bar
end

function Widgets.SetBackdropShown(frame, shown)
  local state = frame.ggBackdrop
  if not state then return end
  state.fill:SetShown(shown)
  state.ringShown = shown and true or false
  PlaceRings(state)
end

function Widgets.CreateChevron(parent, width)
  width = width or 9
  local chev = CreateFrame("Frame", nil, parent)
  chev:SetSize(width, math.floor(width * 0.6 + 0.5))
  local arm = width * 0.62
  chev.left = chev:CreateTexture(nil, "ARTWORK")
  chev.right = chev:CreateTexture(nil, "ARTWORK")
  for i, t in ipairs({ chev.left, chev.right }) do
    t:SetColorTexture(1, 1, 1, 1)
    t:SetSize(arm, 1.6)
    t:SetPoint("CENTER", chev, "CENTER", (i == 1 and -1 or 1) * width * 0.22, 0)
    if t.SetRotation then t:SetRotation((i == 1 and -1 or 1) * math.pi / 4) end
  end
  function chev:SetVertexColor(r, g, b, a)
    self.left:SetVertexColor(r, g, b, a)
    self.right:SetVertexColor(r, g, b, a)
  end
  return chev
end

function Widgets.CreateIconButton(parent, size, opts)
  opts = opts or {}
  local Theme = GG.Theme
  local btn = CreateFrame("Button", nil, parent)
  btn:SetSize(size or 30, size or 30)
  btn:EnableMouse(true)
  btn.hover = Widgets.RoundedFill(btn, btn, 7, "BACKGROUND")
  btn.hover:SetColor(1, 1, 1, 0.06)
  btn.hover:Hide()
  btn.icon = btn:CreateTexture(nil, "ARTWORK")
  btn.icon:SetSize(opts.iconSize or 16, opts.iconSize or 16)
  btn.icon:SetPoint("CENTER")
  if opts.atlas then btn.icon:SetAtlas(opts.atlas) else btn.icon:SetTexture(opts.texture) end
  if opts.desaturate then btn.icon:SetDesaturated(true) end

  function btn:Paint()
    local over = self:IsMouseOver()
    self.hover:SetShown(over or self.active == true)
    if self.active then
      self.icon:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    elseif over then
      self.icon:SetVertexColor(1, 1, 1, 1)
    else
      self.icon:SetVertexColor(Theme.textMuted[1], Theme.textMuted[2], Theme.textMuted[3], 0.85)
    end
  end
  function btn:SetActive(active)
    self.active = active
    self:Paint()
  end
  btn:HookScript("OnEnter", function(self) self:Paint() end)
  btn:HookScript("OnLeave", function(self) self:Paint() end)
  btn:Paint()
  return btn
end

local SHADOW_REACH, SHADOW_DROP, GLOW_REACH = 36, 8, 30
local NINE = {
  { "tl", { 0, 0.5, 0, 0.5 } }, { "tr", { 0.5, 1, 0, 0.5 } },
  { "bl", { 0, 0.5, 0.5, 1 } }, { "br", { 0.5, 1, 0.5, 1 } },
  { "t", { 0.49, 0.51, 0, 0.5 } }, { "b", { 0.49, 0.51, 0.5, 1 } },
  { "l", { 0, 0.5, 0.49, 0.51 } }, { "r", { 0.5, 1, 0.49, 0.51 } },
}

local function NinePieces(host, file, sublayer, size, inner, dy, blend)
  local p = {}
  for _, def in ipairs(NINE) do
    local t = host:CreateTexture(nil, "BACKGROUND", nil, sublayer)
    t:SetTexture(file)
    t:SetTexCoord(unpack(def[2]))
    if blend then t:SetBlendMode(blend) end
    p[def[1]] = t
  end
  local out = size - inner
  for _, key in ipairs({ "tl", "tr", "bl", "br" }) do p[key]:SetSize(size, size) end
  p.tl:SetPoint("TOPLEFT", host, "TOPLEFT", -out, out - dy)
  p.tr:SetPoint("TOPRIGHT", host, "TOPRIGHT", out, out - dy)
  p.bl:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", -out, -out - dy)
  p.br:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", out, -out - dy)
  p.t:SetPoint("TOPLEFT", p.tl, "TOPRIGHT")
  p.t:SetPoint("BOTTOMRIGHT", p.tr, "BOTTOMLEFT")
  p.b:SetPoint("TOPLEFT", p.bl, "TOPRIGHT")
  p.b:SetPoint("BOTTOMRIGHT", p.br, "BOTTOMLEFT")
  p.l:SetPoint("TOPLEFT", p.tl, "BOTTOMLEFT")
  p.l:SetPoint("BOTTOMRIGHT", p.bl, "TOPRIGHT")
  p.r:SetPoint("TOPLEFT", p.tr, "BOTTOMLEFT")
  p.r:SetPoint("BOTTOMRIGHT", p.br, "TOPRIGHT")
  return p
end

Widgets.STRATA_BELOW = {
  TOOLTIP = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "FULLSCREEN", FULLSCREEN = "DIALOG",
  DIALOG = "HIGH", HIGH = "MEDIUM", MEDIUM = "LOW", LOW = "BACKGROUND",
}

function Widgets.ApplyWindowChrome(frame)
  local Theme = GG.Theme
  local media = Theme.media
  local R = Theme.cornerRadius
  local chrome = { alpha = 1 }

  local host = CreateFrame("Frame", nil, frame:GetParent() or UIParent)
  host:SetAllPoints(frame)
  host:EnableMouse(false)
  hooksecurefunc(frame, "SetScale", function(_, scale) host:SetScale(scale or 1) end)
  chrome.host = host

  local edge = CreateFrame("Frame", nil, frame)
  edge:SetAllPoints(frame)
  edge:SetFrameLevel(frame:GetFrameLevel() + 30)
  edge:EnableMouse(false)
  chrome.edgeFrame = edge

  local function Sync()
    local strata = frame:GetFrameStrata()
    host:SetFrameStrata(Widgets.STRATA_BELOW[strata] or strata)
    host:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    host:SetScale(frame:GetScale() or 1)
    host:SetShown(frame:IsVisible())
  end
  edge:SetScript("OnShow", Sync)
  edge:SetScript("OnHide", function() host:Hide() end)
  Sync()
  function chrome:Sync() Sync() end
  function chrome:Hide() host:Hide() end

  chrome.shadow = NinePieces(host, media.windowShadow, -8, SHADOW_REACH + R, R, SHADOW_DROP)
  chrome.glow = NinePieces(host, media.glowHalo, -7, GLOW_REACH, R, 0, "ADD")
  for _, t in pairs(chrome.glow) do t:SetDesaturated(true) end
  chrome.ring = {}
  local ringTex = NewRoundTexture(edge, "OVERLAY")
  if ApplyRound(ringTex, "RoundRing", R) then
    ringTex:SetAllPoints(edge)
    chrome.ring[1] = ringTex
  else
    ringTex:Hide()
    for point, coords in pairs(ROUND_COORDS) do
      local c = edge:CreateTexture(nil, "OVERLAY")
      c:SetTexture(media.edgeRing)
      c:SetTexCoord(unpack(coords))
      c:SetSize(R, R)
      c:SetPoint(point, edge, point)
      chrome.ring[#chrome.ring + 1] = c
    end
    local function Line(p1, x1, y1, p2, x2, y2)
      local t = edge:CreateTexture(nil, "OVERLAY")
      t:SetColorTexture(1, 1, 1, 1)
      t:SetPoint("TOPLEFT", edge, p1, x1, y1)
      t:SetPoint("BOTTOMRIGHT", edge, p2, x2, y2)
      chrome.ring[#chrome.ring + 1] = t
    end
    Line("TOPLEFT", R, 0, "TOPRIGHT", -R, -1)
    Line("BOTTOMLEFT", R, 1, "BOTTOMRIGHT", -R, 0)
    Line("TOPLEFT", 0, -R, "BOTTOMLEFT", 1, R)
    Line("TOPRIGHT", -1, -R, "BOTTOMRIGHT", 0, R)
  end

  chrome.lightL = edge:CreateTexture(nil, "OVERLAY", nil, 1)
  chrome.lightR = edge:CreateTexture(nil, "OVERLAY", nil, 1)
  chrome.lightL:SetColorTexture(1, 1, 1, 1)
  chrome.lightR:SetColorTexture(1, 1, 1, 1)
  chrome.lightL:SetPoint("TOPLEFT", edge, "TOPLEFT", 18, 0)
  chrome.lightL:SetPoint("BOTTOMRIGHT", edge, "TOP", 0, -1)
  chrome.lightR:SetPoint("TOPLEFT", edge, "TOP", 0, 0)
  chrome.lightR:SetPoint("BOTTOMRIGHT", edge, "TOPRIGHT", -18, -1)

  function chrome:Paint()
    local a = Theme.accent
    local alpha = self.alpha or 1
    for _, t in pairs(self.shadow) do t:SetVertexColor(0, 0, 0, 0.62 * alpha) end
    for _, t in pairs(self.glow) do t:SetVertexColor(a[1], a[2], a[3], 0.30 * alpha) end
    for _, t in ipairs(self.ring) do t:SetVertexColor(a[1] * 0.38, a[2] * 0.38, a[3] * 0.38, alpha) end
    if CreateColor then
      local clear, full = CreateColor(a[1], a[2], a[3], 0), CreateColor(a[1], a[2], a[3], 0.6 * alpha)
      self.lightL:SetGradient("HORIZONTAL", clear, full)
      self.lightR:SetGradient("HORIZONTAL", full, clear)
    end
  end

  function chrome:SetAlpha(alpha)
    self.alpha = alpha or 1
    self:Paint()
  end

  chrome:Paint()
  return chrome
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

  local border = NewRoundTexture(btn, "BACKGROUND")
  border:SetAllPoints()
  ApplyRound(border, "RoundFill", 4)

  local fill = NewRoundTexture(btn, "ARTWORK")
  fill:SetPoint("TOPLEFT", 2, -2)
  fill:SetPoint("BOTTOMRIGHT", -2, 2)
  ApplyRound(fill, "RoundFill", 2)

  local state = { checked = not not checked }

  local function paint()
    local borderColor = state.checked and Theme.accent or Theme.borderSoft
    border:SetVertexColor(unpackColor(borderColor))
    local fillColor = state.checked and Theme.accent or Theme.background
    fill:SetVertexColor(unpackColor(fillColor))
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
  local R = 6
  for _, layer in ipairs({ { 2, 0.40 }, { 5, 0.24 }, { 9, 0.13 }, { 14, 0.06 } }) do
    local shadow = NewRoundTexture(frame, "BACKGROUND", -8)
    ApplyRound(shadow, "RoundFill", math.min(10, R + layer[1]))
    shadow:SetVertexColor(0, 0, 0, layer[2])
    shadow:SetPoint("TOPLEFT", -layer[1], layer[1] - 4)
    shadow:SetPoint("BOTTOMRIGHT", layer[1], -layer[1] - 4)
  end
  Widgets.Backdrop(frame, Widgets.MENU_BG, Widgets.MENU_BORDER, R)
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
  menuVeil.window = window
  menuVeil:Show()
  if GG.Tip and Widgets.MenuCovers(GG.Tip:Owner()) then GG.Tip:Hide() end
  if GameTooltip:IsShown() and Widgets.MenuCovers(GameTooltip:GetOwner()) then GameTooltip:Hide() end
end

function Widgets.HideMenuVeil(menu)
  if menuVeil and (menu == nil or menuVeil.owner == menu) then
    menuVeil.owner = nil
    menuVeil.window = nil
    menuVeil:Hide()
  end
end

local function IsInside(frame, ancestor)
  while frame do
    if frame == ancestor then return true end
    frame = frame:GetParent()
  end
  return false
end

function Widgets.MenuCovers(owner)
  if not (owner and menuVeil and menuVeil:IsShown() and menuVeil.owner) then return false end
  return IsInside(owner, menuVeil.window) and not IsInside(owner, menuVeil.owner)
end

GameTooltip:HookScript("OnShow", function(tooltip)
  if menuVeil and menuVeil:IsShown() and Widgets.MenuCovers(tooltip:GetOwner()) then tooltip:Hide() end
end)

local activeDropdownClose

local dropdownInstanceCount = 0

function Widgets.CreateDropdown(parent, opts)
  local Theme = GG.Theme
  opts = opts or {}
  local width = opts.width or 160
  local ROW_HEIGHT = 22

  local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
  btn:SetSize(width, 24)
  Widgets.Backdrop(btn, { 1, 1, 1, 0.04 }, Theme.borderSoft, 6)

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
      list:Hide()
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
  Widgets.Backdrop(btn, { 1, 1, 1, 0.04 }, Theme.borderSoft, 6)

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
