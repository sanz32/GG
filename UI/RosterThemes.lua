local ADDON_NAME, GG = ...

local RT = {}
GG.RosterThemes = RT

local function C(hex, a)
  return {
    tonumber(hex:sub(1, 2), 16) / 255,
    tonumber(hex:sub(3, 4), 16) / 255,
    tonumber(hex:sub(5, 6), 16) / 255,
    a or 1,
  }
end

RT.DEFAULT = "cards"
RT.ORDER = { "cards", "gauges", "heatmap", "rail", "halo", "banners" }
RT.PART_ORDER = { "nums", "bosses", "quests", "mark" }

RT.PART_VALUES = {
  nums = { "num", "gauge" },
  bosses = { "icons", "bar" },
  quests = { "icons", "checks" },
  mark = { "card", "tint", "outline", "frame", "halo", "fill" },
}

RT.PART_LABELS = {
  nums = { title = "THEME_PART_NUMS", num = "THEME_NUMS_NUM", gauge = "THEME_NUMS_GAUGE" },
  bosses = { title = "THEME_PART_BOSSES", icons = "THEME_BOSSES_ICONS", bar = "THEME_BOSSES_BAR" },
  quests = { title = "THEME_PART_QUESTS", icons = "THEME_QUESTS_ICONS", checks = "THEME_QUESTS_CHECKS" },
  mark = {
    title = "THEME_PART_MARK", card = "THEME_MARK_CARD", tint = "THEME_MARK_TINT",
    outline = "THEME_MARK_OUTLINE", frame = "THEME_MARK_FRAME", halo = "THEME_MARK_HALO", fill = "THEME_MARK_FILL",
  },
}

RT.COLORS = {
  track = C("2c303b"),
  checkIdle = C("3a3e4a"),
}

RT.MARK = {
  ring = 2,
  glowSize = 12,
  listGlowSize = 4,
  glowAlpha = 0.7,
  tintTop = 0.12, tintBottom = 0.04, tintStop = 0.40,
  listTintStart = 0.14, listTintEnd = 0.03, listTintStop = 0.45,
  tintBar = 2,
  frameFill = 0.06,
  haloAlpha = 0.6,
  haloWash = 0.035, haloWashStop = 0.30,
  listHaloWash = 0.06, listHaloWashStop = 0.50,
  fill = 0.11,
}

RT.BLOCK_COLORS = {
  overview = C("9aa3b5"), weekly = C("a78bfa"), quests = C("e8b85c"), currencies = C("35d0ba"),
}

RT.THEMES = {
  cards = {
    key = "cards", labelKey = "THEME_CARDS", descKey = "THEME_CARDS_DESC", implemented = true,
    colWidth = 140, colGap = 6, rowGap = 6, titleHeight = 28, radius = 8,
    cell = C("191b23"),
    headTint = 0.08, headFade = 0.60,
    listCharTint = 0.09, listCharFade = 0.90,
    separator = "inset", rule = C("2e313c"), ruleInset = 14, listRuleInset = 14,
    headerLines = false, listLines = "inset",
    parts = { nums = "num", bosses = "icons", quests = "icons", mark = "card" },
  },
  gauges = {
    key = "gauges", labelKey = "THEME_GAUGES", descKey = "THEME_GAUGES_DESC", implemented = true,
    colWidth = 140, colGap = 0, rowGap = 0, titleHeight = 28, radius = 0,
    separator = "full", rule = C("2a2d38"), ruleInset = 0, listRowLine = C("262934"),
    headerLines = true,
    parts = { nums = "gauge", bosses = "bar", quests = "checks", mark = "tint" },
  },
  heatmap = {
    key = "heatmap", labelKey = "THEME_HEATMAP", descKey = "THEME_HEATMAP_DESC", implemented = true,
    colWidth = 128, colGap = 2, rowGap = 2, titleHeight = 18, radius = 3,
    cell = { 1, 1, 1, 0.035 }, headCell = { 1, 1, 1, 0.05 }, titleCell = { 1, 1, 1, 0.018 },
    separator = "none", nameSize = 14,
    heat = { ilvl = { 0.04, 0.15 }, rating = { 0.05, 0.11 }, raid = 0.14 },
    headerLines = false,
    parts = { nums = "num", bosses = "icons", quests = "icons", mark = "outline" },
  },
  rail = {
    key = "rail", labelKey = "THEME_RAIL", descKey = "THEME_RAIL_DESC", implemented = true,
    colWidth = 140, colGap = 0, rowGap = 0, titleHeight = 28, radius = 0,
    separator = "block", ruleAlpha = 0.35, ruleInset = 0,
    compactHeader = true, headerHeight = 64, headerPad = 14, headerGap = 9,
    wash = 0.06, spineWidth = 3, spineX = 4,
    blocks = RT.BLOCK_COLORS,
    headerLines = true, listLines = "block", listLineAlpha = 0.30,
    parts = { nums = "num", bosses = "icons", quests = "icons", mark = "frame" },
  },
  halo = {
    key = "halo", labelKey = "THEME_HALO", descKey = "THEME_HALO_DESC", implemented = true,
    colWidth = 140, colGap = 0, rowGap = 0, titleHeight = 28, radius = 0,
    separator = "glow", glowAlpha = 0.55, glowWhite = 0.30, bloomAlpha = 0.30, bloomHeight = 7,
    numBump = 1,
    headerLines = false,
    parts = { nums = "gauge", bosses = "bar", quests = "checks", mark = "halo" },
  },
  banners = {
    key = "banners", labelKey = "THEME_BANNERS", descKey = "THEME_BANNERS_DESC", implemented = true,
    colWidth = 140, colGap = 10, rowGap = 8, titleHeight = 28, radius = 0,
    cell = C("1a1c25"), zebra = C("1e2029"),
    separator = "gold", rule = C("e8b85c", 0.22), ruleInset = 12, listRuleInset = 14,
    headerLines = false, listLines = "inset",
    banner = true, tailHeight = 20, listTailWidth = 16, stripe = 3,
    pole = C("5b4a35"), poleShadow = { 0, 0, 0, 0.5 },
    headTint = 0.08, headFade = 0.75, listCharTint = 0.08, listCharFade = 0.85,
    listCardLeft = 16,
    markFill = 0.10, markFillHead = 0.16,
    parts = { nums = "num", bosses = "icons", quests = "icons", mark = "fill" },
  },
}

function RT:IsValidTheme(key)
  return type(key) == "string" and RT.THEMES[key] ~= nil
end

function RT:IsValidPart(part, value)
  local values = RT.PART_VALUES[part]
  if not values or type(value) ~= "string" then return false end
  for _, v in ipairs(values) do
    if v == value then return true end
  end
  return false
end

function RT:ThemeDefault(themeKey, part)
  local theme = RT.THEMES[themeKey] or RT.THEMES[RT.DEFAULT]
  return theme.parts[part]
end

function RT:Resolve(options)
  if options == nil then options = (GGDB and GGDB.options) or {} end
  local key = options.theme
  if not RT:IsValidTheme(key) then key = RT.DEFAULT end
  local theme = RT.THEMES[key]
  local painter = theme.implemented and key or RT.DEFAULT
  local overrides = type(options.themeParts) == "table" and options.themeParts or {}

  local parts, source = {}, {}
  for _, part in ipairs(RT.PART_ORDER) do
    local value = overrides[part]
    if RT:IsValidPart(part, value) then
      parts[part], source[part] = value, "override"
    else
      parts[part], source[part] = theme.parts[part], "theme"
    end
  end

  return {
    key = key,
    painter = painter,
    theme = theme,
    tokens = RT.THEMES[painter],
    parts = parts,
    source = source,
    signature = table.concat({ key, painter, parts.nums, parts.bosses, parts.quests, parts.mark }, "/"),
  }
end

function RT:SetTheme(options, key)
  if not RT:IsValidTheme(key) then return false end
  options.theme = key
  return true
end

function RT:SetPart(options, part, value)
  if not RT.PART_VALUES[part] then return false end
  if type(options.themeParts) ~= "table" then options.themeParts = {} end
  if value == nil or value == "theme" then
    options.themeParts[part] = nil
    return true
  end
  if not RT:IsValidPart(part, value) then return false end
  options.themeParts[part] = value
  return true
end

local function Lerp(a, b, t)
  return {
    a[1] + (b[1] - a[1]) * t,
    a[2] + (b[2] - a[2]) * t,
    a[3] + (b[3] - a[3]) * t,
    (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t,
  }
end

function RT.Mix(base, over, amount)
  return {
    base[1] + (over[1] - base[1]) * amount,
    base[2] + (over[2] - base[2]) * amount,
    base[3] + (over[3] - base[3]) * amount,
    base[4] or 1,
  }
end

local function Lighten(c, amount)
  return { c[1] + (1 - c[1]) * amount, c[2] + (1 - c[2]) * amount, c[3] + (1 - c[3]) * amount, c[4] or 1 }
end

local function Color(c, mul)
  return CreateColor(c[1], c[2], c[3], (c[4] or 1) * (mul or 1))
end

function RT.Inset(g, left, top, right, bottom)
  return {
    x = g.x + left, y = g.y + top, h = g.h - top - bottom,
    w = g.w and (g.w - left - right) or nil,
    right = g.right and (g.right + right) or nil,
    span = g.span and (g.span - left - right) or nil,
  }
end

local function SpanH(owner, g, t, a, b, bInset, top, height)
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", owner, "TOPLEFT", g.x + a, -(g.y + top))
  if b then
    t:SetPoint("BOTTOMRIGHT", owner, "TOPLEFT", g.x + b, -(g.y + top + height))
  elseif g.w then
    t:SetPoint("BOTTOMRIGHT", owner, "TOPLEFT", g.x + g.w - bInset, -(g.y + top + height))
  else
    t:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", -(g.right + bInset), -(g.y + top + height))
  end
end

local function SpanR(owner, g, t, a, b, top, height)
  if g.w then return SpanH(owner, g, t, g.w - a, g.w - b, 0, top, height) end
  t:ClearAllPoints()
  t:SetPoint("TOPLEFT", owner, "TOPRIGHT", -(g.right + a), -(g.y + top))
  t:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", -(g.right + b), -(g.y + top + height))
end

local Panel = {}
Panel.__index = Panel

function RT.NewPanel(owner, sublayer, layer)
  return setmetatable({
    owner = owner, layer = layer or "BACKGROUND", sublayer = sublayer or 0,
    corners = {}, fills = {}, used = 0,
  }, Panel)
end

local CORNER_COORDS = {
  tl = { 0, 1, 0, 1 }, tr = { 1, 0, 0, 1 }, bl = { 0, 1, 1, 0 }, br = { 1, 0, 1, 0 },
}

function Panel:Corner(which)
  local t = self.corners[which]
  if not t then
    t = self.owner:CreateTexture(nil, self.layer, nil, self.sublayer)
    t:SetTexture(GG.Theme.media.cornerMask)
    t:SetTexCoord(unpack(CORNER_COORDS[which]))
    self.corners[which] = t
  end
  t:Show()
  return t
end

function Panel:Fill()
  self.used = self.used + 1
  local t = self.fills[self.used]
  if not t then
    t = self.owner:CreateTexture(nil, self.layer, nil, self.sublayer)
    t:SetColorTexture(1, 1, 1, 1)
    self.fills[self.used] = t
  end
  t:Show()
  return t
end

function Panel:Hide()
  for _, t in pairs(self.corners) do t:Hide() end
  for _, t in ipairs(self.fills) do t:Hide() end
end

function Panel:Paint(g, radius, orient, stops, alphaMul)
  self.used = 0
  local owner = self.owner
  local h = g.h
  if h <= 0 or (g.w and g.w <= 0) then self:Hide() return end
  local R = math.max(0, math.min(radius or 0, math.floor(h / 2), g.w and math.floor(g.w / 2) or 9999))
  local first, last = stops[1][2], stops[#stops][2]
  local vertical = orient == "VERTICAL"

  if R > 0 then
    local startColor, endColor = first, last
    local tl, tr, bl, br = self:Corner("tl"), self:Corner("tr"), self:Corner("bl"), self:Corner("br")
    SpanH(owner, g, tl, 0, R, nil, 0, R)
    SpanR(owner, g, tr, R, 0, 0, R)
    SpanH(owner, g, bl, 0, R, nil, h - R, R)
    SpanR(owner, g, br, R, 0, h - R, R)
    local c1, c2 = startColor, endColor
    tl:SetVertexColor(c1[1], c1[2], c1[3], (c1[4] or 1) * (alphaMul or 1))
    if vertical then
      tr:SetVertexColor(c1[1], c1[2], c1[3], (c1[4] or 1) * (alphaMul or 1))
      bl:SetVertexColor(c2[1], c2[2], c2[3], (c2[4] or 1) * (alphaMul or 1))
    else
      tr:SetVertexColor(c2[1], c2[2], c2[3], (c2[4] or 1) * (alphaMul or 1))
      bl:SetVertexColor(c1[1], c1[2], c1[3], (c1[4] or 1) * (alphaMul or 1))
    end
    br:SetVertexColor(c2[1], c2[2], c2[3], (c2[4] or 1) * (alphaMul or 1))

    local s1, s2 = self:Fill(), self:Fill()
    if vertical then
      SpanH(owner, g, s1, R, nil, R, 0, R)
      SpanH(owner, g, s2, R, nil, R, h - R, R)
    else
      SpanH(owner, g, s1, 0, R, nil, R, h - 2 * R)
      SpanR(owner, g, s2, R, 0, R, h - 2 * R)
    end
    s1:SetGradient("HORIZONTAL", Color(c1, alphaMul), Color(c1, alphaMul))
    s2:SetGradient("HORIZONTAL", Color(c2, alphaMul), Color(c2, alphaMul))
  else
    for _, t in pairs(self.corners) do t:Hide() end
  end

  local limit = vertical and (h - R) or (g.w and (g.w - R) or math.huge)
  for i = 1, #stops - 1 do
    local p1, p2 = stops[i], stops[i + 1]
    local a = math.max(p1[1], R)
    local b = math.min(p2[1], limit)
    local span = p2[1] - p1[1]
    if b > a then
      local function At(pos)
        if span <= 0 or span == math.huge then return p1[2] end
        return Lerp(p1[2], p2[2], (pos - p1[1]) / span)
      end
      local t = self:Fill()
      local ca, cb = At(a), (b == math.huge) and p2[2] or At(b)
      if vertical then
        SpanH(owner, g, t, 0, nil, 0, a, b - a)
        t:SetGradient("VERTICAL", Color(cb, alphaMul), Color(ca, alphaMul))
      else
        if b == math.huge then
          SpanH(owner, g, t, a, nil, R, 0, h)
        else
          SpanH(owner, g, t, a, b, nil, 0, h)
        end
        t:SetGradient("HORIZONTAL", Color(ca, alphaMul), Color(cb, alphaMul))
      end
    end
  end
  for i = self.used + 1, #self.fills do self.fills[i]:Hide() end
end

function Panel:Solid(g, radius, color, alphaMul)
  self:Paint(g, radius, "VERTICAL", { { 0, color }, { g.h, color } }, alphaMul)
end

local Glow = {}
Glow.__index = Glow

local GLOW_PIECES = {
  { "tl", { 0, 0.5, 0, 0.5 } }, { "tr", { 0.5, 1, 0, 0.5 } },
  { "bl", { 0, 0.5, 0.5, 1 } }, { "br", { 0.5, 1, 0.5, 1 } },
  { "t", { 0.49, 0.51, 0, 0.5 } }, { "b", { 0.49, 0.51, 0.5, 1 } },
  { "l", { 0, 0.5, 0.49, 0.51 } }, { "r", { 0.5, 1, 0.49, 0.51 } },
}

function RT.NewGlow(owner, sublayer)
  return setmetatable({ owner = owner, sublayer = sublayer or -8, pieces = {} }, Glow)
end

function Glow:Hide()
  for _, t in pairs(self.pieces) do t:Hide() end
end

function Glow:Paint(g, inset, size, color, alpha)
  local src = RT.Inset(g, inset, inset, inset, inset)
  local S = size
  for _, def in ipairs(GLOW_PIECES) do
    local key = def[1]
    local t = self.pieces[key]
    if not t then
      t = self.owner:CreateTexture(nil, "BACKGROUND", nil, self.sublayer)
      t:SetTexture(GG.Theme.media.glowHalo)
      t:SetTexCoord(unpack(def[2]))
      t:SetDesaturated(true)
      t:SetBlendMode("ADD")
      self.pieces[key] = t
    end
    t:SetVertexColor(color[1], color[2], color[3], alpha)
    t:Show()
  end
  local p = self.pieces
  SpanH(self.owner, src, p.tl, -S, 0, nil, -S, S)
  SpanR(self.owner, src, p.tr, 0, -S, -S, S)
  SpanH(self.owner, src, p.bl, -S, 0, nil, src.h, S)
  SpanR(self.owner, src, p.br, 0, -S, src.h, S)
  SpanH(self.owner, src, p.t, 0, nil, 0, -S, S)
  SpanH(self.owner, src, p.b, 0, nil, 0, src.h, S)
  SpanH(self.owner, src, p.l, -S, 0, nil, 0, src.h)
  SpanR(self.owner, src, p.r, 0, -S, 0, src.h)
end

local function ListCellKind(key)
  if key == "character" then return "head", nil end
  if key == "ilvl" or key == "rating" then return "cell", key end
  return "cell", nil
end

function RT.ColumnLayout(sections)
  local out = { cells = {}, zebra = {}, blocks = {}, rules = {} }
  local dataIndex = 0
  local open, lastBottom
  for _, s in ipairs(sections or {}) do
    if s.visible and s.y and s.key ~= "tail" then
      local top, bottom = s.y, s.y + s.height
      if s.band then
        if open then open.b = lastBottom or top end
        open = nil
        out.cells[#out.cells + 1] = { top = top, height = s.height, kind = "title" }
        out.rules[#out.rules + 1] = { y = math.floor(top + s.height / 2), block = s.block }
        if s.block then
          open = { a = top, b = bottom, block = s.block }
          out.blocks[#out.blocks + 1] = open
        end
      elseif s.difficulties and s.zebraRows then
        local h = s.zebraRows.height
        for i, difficultyID in ipairs(s.difficulties) do
          out.cells[#out.cells + 1] = { top = top + (i - 1) * h, height = h, kind = "cell", raid = difficultyID }
        end
        if #s.difficulties == 0 then
          out.cells[#out.cells + 1] = { top = top, height = s.height, kind = "cell" }
        end
      else
        local heat = (s.key == "ilvl" or s.key == "rating") and s.key or nil
        out.cells[#out.cells + 1] = { top = top, height = s.height, kind = s.key == "character" and "head" or "cell", heat = heat }
      end
      if s.dataRow then
        dataIndex = dataIndex + 1
        if dataIndex % 2 == 0 then out.zebra[#out.zebra + 1] = { top = top, bottom = bottom } end
      end
      lastBottom = bottom
    end
  end
  if open then open.b = lastBottom end
  return out
end

function RT.ListSpans(starts, endX)
  local spans = {}
  for i, st in ipairs(starts or {}) do
    local nextX = starts[i + 1] and starts[i + 1].x or endX
    if nextX and nextX > st.x then spans[#spans + 1] = { a = st.x, b = nextX, block = st.block } end
  end
  return spans
end

function RT.FadeStops(spans, origin, alpha, palette)
  if not spans or #spans == 0 then return nil end
  local function Col(sp) return (palette and palette[sp.block]) or sp.color or { 1, 1, 1 } end
  local c1 = Col(spans[1])
  local stops = { { 0, { c1[1], c1[2], c1[3], 0 } } }
  local last = 0
  local function Add(pos, c)
    if pos < last then pos = last end
    last = pos
    stops[#stops + 1] = { pos, c }
  end
  for _, sp in ipairs(spans) do
    local base = Col(sp)
    local c = { base[1], base[2], base[3], alpha }
    local q = (sp.b - sp.a) / 4
    Add(sp.a + q - (origin or 0), c)
    Add(sp.b - q - (origin or 0), c)
  end
  stops[#stops + 1] = { math.huge, stops[#stops][2] }
  return stops
end

function RT.HeatColor(tok, cell, heat)
  local kind, key = cell.kind, cell.heat
  if not kind and cell.key then kind, key = ListCellKind(cell.key) end
  local base = (kind == "head" and tok.headCell) or (kind == "title" and tok.titleCell) or tok.cell
  local h = tok.heat
  heat = heat or {}
  if h and key and heat[key] and h[key] then
    local c, t = heat[key].color, math.max(0, math.min(1, heat[key].t or 0))
    return { c[1], c[2], c[3], h[key][1] + h[key][2] * t }
  end
  if h and cell.raid and heat.raid and heat.raid[cell.raid] then
    local c = heat.raid[cell.raid]
    return { c[1], c[2], c[3], h.raid }
  end
  return base
end

local function Begin(s) s.used = {} end

local function UseTex(s, owner, key, sublayer, init)
  local t = s.tex[key]
  if not t then
    t = owner:CreateTexture(nil, "BACKGROUND", nil, sublayer)
    if init then init(t) end
    s.tex[key] = t
  end
  s.used[key] = true
  t:Show()
  return t
end

local function UsePanel(s, owner, key, sublayer)
  local p = s.panels[key]
  if not p then
    p = RT.NewPanel(owner, sublayer)
    s.panels[key] = p
  end
  s.used[key] = true
  return p
end

local function UseGlow(s, owner, key, sublayer)
  local g = s.glows[key]
  if not g then
    g = RT.NewGlow(owner, sublayer)
    s.glows[key] = g
  end
  s.used[key] = true
  return g
end

local function Finish(s)
  for key, t in pairs(s.tex) do if not s.used[key] then t:Hide() end end
  for key, p in pairs(s.panels) do if not s.used[key] then p:Hide() end end
  for key, g in pairs(s.glows) do if not s.used[key] then g:Hide() end end
end

local function InitHalo(t)
  t:SetTexture(GG.Theme.media.glowHalo)
  t:SetDesaturated(true)
  t:SetBlendMode("ADD")
end

local function InitGlowLine(t)
  t:SetTexture(GG.Theme.media.glowSeparator)
  t:SetDesaturated(true)
end

local function Edge(owner, t, g, side, thick)
  if side == "left" then
    SpanH(owner, g, t, 0, thick, nil, 0, g.h)
  elseif side == "right" then
    SpanR(owner, g, t, thick, 0, 0, g.h)
  elseif side == "top" then
    SpanH(owner, g, t, 0, nil, 0, 0, thick)
  else
    SpanH(owner, g, t, 0, nil, 0, g.h - thick, thick)
  end
end

function RT.PlaceGlowLine(owner, line, bloom, g, y, tok)
  local accent = GG.Theme.accent
  local c = Lighten(accent, tok.glowWhite or 0.3)
  line:SetVertexColor(c[1], c[2], c[3], tok.glowAlpha or 0.55)
  SpanH(owner, g, line, 0, nil, 0, y, 1)
  local w = g.w or g.span or 600
  local bh = tok.bloomHeight or 7
  bloom:SetVertexColor(accent[1], accent[2], accent[3], tok.bloomAlpha or 0.3)
  bloom:ClearAllPoints()
  bloom:SetSize(math.max(8, math.floor(w * 0.4)), bh)
  if g.w then
    bloom:SetPoint("CENTER", owner, "TOPLEFT", g.x + g.w / 2, -(g.y + y) - 0.5)
  else
    bloom:SetPoint("CENTER", owner, "TOP", (g.x - (g.right or 0)) / 2, -(g.y + y) - 0.5)
  end
end

function RT.PaintSurface(row, geom, ctx)
  local s = row.themeSurface
  if not s then
    s = { tex = {}, panels = {}, glows = {}, used = {} }
    row.themeSurface = s
  end
  if not geom then return RT.HideSurface(row) end
  Begin(s)

  local T, tok = ctx.T, ctx.T.tokens
  local vertical = ctx.vertical
  local mark = ctx.isCurrent and T.parts.mark or nil
  local accent = GG.Theme.accent
  local M = RT.MARK
  local R = tok.radius or 0
  local o = M.ring
  local alphaMul = ctx.alphaMul or 1
  local hasCard = tok.cell ~= nil and not tok.heat
  local function A(alpha) return { accent[1], accent[2], accent[3], alpha } end

  local body = geom
  if tok.banner then
    if vertical then
      body = RT.Inset(geom, 0, 0, 0, tok.tailHeight)
    else
      body = RT.Inset(geom, 0, 0, tok.listTailWidth, 0)
    end
  end
  local bannerFill = tok.banner and mark == "fill"

  local inner, innerR = body, R
  if hasCard and mark == "outline" then
    inner, innerR = RT.Inset(body, o, o, o, o), math.max(0, R - o)
  elseif hasCard and mark == "frame" then
    inner = vertical and RT.Inset(body, o, 0, o, 0) or RT.Inset(body, 0, o, 0, o)
  end
  local cardColor = tok.cell
  if bannerFill then cardColor = RT.Mix(tok.cell, accent, tok.markFill) end
  s.inner, s.innerR, s.alphaMul, s.tokens, s.hasCard, s.cardColor = inner, innerR, alphaMul, tok, hasCard, cardColor

  if hasCard then
    UsePanel(s, row, "card", -6):Solid(inner, innerR, s.hover and Lighten(cardColor, 0.03) or cardColor, alphaMul)
  end

  local cc, headTint, headFade = ctx.classColor, tok.headTint, tok.headFade
  local listTint, listFade = tok.listCharTint, tok.listCharFade
  if bannerFill then
    cc, headTint, headFade, listTint, listFade = accent, tok.markFillHead, 1, tok.markFillHead, 1
  end
  if hasCard and cc and headTint then
    if vertical and geom.headBottom then
      local on, off = { cc[1], cc[2], cc[3], headTint }, { cc[1], cc[2], cc[3], 0 }
      local headStart = (geom.headSplit or geom.y) - inner.y
      local fadeEnd = headStart + (geom.headBottom - (geom.headSplit or geom.y)) * headFade
      local stops = { { 0, on } }
      if geom.headSplit then stops[#stops + 1] = { headStart, on } end
      stops[#stops + 1] = { fadeEnd, off }
      stops[#stops + 1] = { inner.h, off }
      UsePanel(s, row, "head", -5):Paint(inner, innerR, "VERTICAL", stops, alphaMul)
    elseif not vertical and geom.charX then
      local on, off = { cc[1], cc[2], cc[3], listTint }, { cc[1], cc[2], cc[3], 0 }
      local cx = geom.charX - inner.x
      local fadeEnd = cx + (geom.charW or 0) * listFade
      local stops = { { 0, on }, { fadeEnd, off }, { math.huge, off } }
      UsePanel(s, row, "head", -5):Paint(inner, innerR, "HORIZONTAL", stops, alphaMul)
    end
  end

  if tok.heat then
    local n = 0
    local function Cell(g, color)
      n = n + 1
      UsePanel(s, row, "cell" .. n, -6):Solid(g, R, color, alphaMul)
    end
    if vertical and geom.layout then
      for _, c in ipairs(geom.layout.cells) do
        Cell({ x = geom.x, y = c.top + 1, w = geom.w, h = c.height - 2 }, RT.HeatColor(tok, c, ctx.heat))
      end
    elseif not vertical and geom.cols then
      local last = #geom.cols
      for i, col in ipairs(geom.cols) do
        local left = (i == 1) and geom.x or (col.x + 1)
        local g
        if i == last then
          g = { x = left, y = geom.y, h = geom.h, right = geom.right }
        else
          g = { x = left, y = geom.y, h = geom.h, w = col.x + col.w - 1 - left }
        end
        Cell(g, RT.HeatColor(tok, col, ctx.heat))
      end
    end
  end

  if tok.zebra and vertical and geom.layout then
    local zc = bannerFill and RT.Mix(tok.zebra, accent, tok.markFill) or tok.zebra
    for i, z in ipairs(geom.layout.zebra) do
      local t = UseTex(s, row, "zebra" .. i, -5)
      t:SetColorTexture(zc[1], zc[2], zc[3], (zc[4] or 1) * alphaMul)
      SpanH(row, { x = inner.x, y = z.top, h = z.bottom - z.top, w = inner.w }, t, 0, nil, 0, 0, z.bottom - z.top)
    end
  end
  if tok.banner then
    local tc = s.hover and Lighten(cardColor, 0.03) or cardColor
    local tail = UseTex(s, row, "tail", -6)
    tail:SetTexture(vertical and GG.Theme.media.bannerTip or GG.Theme.media.bannerTail)
    tail:SetVertexColor(tc[1], tc[2], tc[3], alphaMul)
    if vertical then
      SpanH(row, geom, tail, 0, nil, 0, body.h, tok.tailHeight)
    else
      SpanR(row, geom, tail, tok.listTailWidth, 0, 0, geom.h)
    end
    local sc = ctx.classColor or GG.Theme.textMuted
    local stripe = UseTex(s, row, "stripe", -2)
    stripe:SetColorTexture(sc[1], sc[2], sc[3], alphaMul)
    if vertical then
      SpanH(row, inner, stripe, 0, nil, 0, 0, tok.stripe)
    else
      SpanH(row, inner, stripe, 0, tok.stripe, nil, 0, inner.h)
    end
    local pc, sh = tok.pole, tok.poleShadow
    local pole = UseTex(s, row, "pole", -6)
    pole:SetColorTexture(pc[1], pc[2], pc[3], alphaMul)
    if vertical then
      SpanH(row, geom, pole, -4, nil, -4, -6, 4)
      local shadow = UseTex(s, row, "poleShadow", -6)
      shadow:SetColorTexture(sh[1], sh[2], sh[3], (sh[4] or 1) * alphaMul)
      SpanH(row, geom, shadow, -4, nil, -4, -2, 1)
    else
      local half = math.floor((geom.rowGap or 8) / 2)
      SpanH(row, geom, pole, -9, -5, nil, -half, geom.h + half * 2)
    end
  end

  if tok.blocks then
    local g, stops, orient
    if vertical and geom.layout and #geom.layout.blocks > 0 then
      local blocks = geom.layout.blocks
      local top, bottom = blocks[1].a, blocks[#blocks].b
      g = { x = geom.x, y = top, w = geom.w, h = bottom - top }
      stops, orient = RT.FadeStops(blocks, top, tok.wash, tok.blocks), "VERTICAL"
    elseif not vertical and geom.spans and #geom.spans > 0 then
      g = geom
      stops, orient = RT.FadeStops(geom.spans, geom.x, tok.wash, tok.blocks), "HORIZONTAL"
    end
    if stops then UsePanel(s, row, "railWash", -5):Paint(g, 0, orient, stops, alphaMul) end
  end

  if not vertical and (ctx.index or 1) > 1 then
    if tok.listRowLine then
      local lc = tok.listRowLine
      local t = UseTex(s, row, "rowLine", -2)
      t:SetColorTexture(lc[1], lc[2], lc[3], (lc[4] or 1) * alphaMul)
      SpanH(row, geom, t, 0, nil, 0, 0, 1)
    elseif tok.separator == "glow" then
      RT.PlaceGlowLine(row, UseTex(s, row, "rowGlow", -2, InitGlowLine),
        UseTex(s, row, "rowBloom", -2, InitHalo), geom, 0, tok)
    end
  end

  local edges = {}
  if mark == "card" then
    if hasCard then
      UsePanel(s, row, "rim", -7):Solid(RT.Inset(body, -o, -o, -o, -o), R + o, accent, alphaMul)
    else
      local ring = RT.Inset(body, -o, -o, -o, -o)
      edges = { { ring, "left" }, { ring, "right" }, { ring, "top" }, { ring, "bottom" } }
    end
    UseGlow(s, row, "glow", -8):Paint(body, R, (vertical and M.glowSize or M.listGlowSize) + R, accent, M.glowAlpha)
  elseif (mark == "outline" or mark == "frame") and hasCard then
    UsePanel(s, row, "rim", -7):Solid(body, R, accent, alphaMul)
  elseif mark == "outline" then
    edges = { { body, "left" }, { body, "right" }, { body, "top" }, { body, "bottom" } }
  elseif mark == "frame" then
    if vertical then
      edges = { { body, "left" }, { body, "right" } }
    else
      edges = { { body, "top" }, { body, "bottom" } }
    end
  end
  for i, e in ipairs(edges) do
    local t = UseTex(s, row, "edge" .. i, -2)
    t:SetColorTexture(accent[1], accent[2], accent[3], 1)
    Edge(row, t, e[1], e[2], o)
  end

  local span = inner.w or inner.span or 600
  if mark == "tint" then
    if vertical then
      UsePanel(s, row, "wash", -4):Paint(inner, innerR, "VERTICAL", {
        { 0, A(M.tintTop) }, { inner.h * M.tintStop, A(M.tintBottom) }, { inner.h, A(M.tintBottom) },
      })
    else
      UsePanel(s, row, "wash", -4):Paint(inner, innerR, "HORIZONTAL", {
        { 0, A(M.listTintStart) }, { span * M.listTintStop, A(M.listTintEnd) }, { math.huge, A(M.listTintEnd) },
      })
    end
  elseif mark == "fill" and not bannerFill then
    UsePanel(s, row, "wash", -4):Solid(inner, innerR, A(M.fill))
  elseif mark == "frame" then
    UsePanel(s, row, "wash", -4):Solid(inner, innerR, A(M.frameFill))
  elseif mark == "halo" then
    if vertical then
      UsePanel(s, row, "wash", -4):Paint(inner, innerR, "VERTICAL", {
        { 0, A(M.haloWash) }, { inner.h * M.haloWashStop, A(0) }, { inner.h, A(0) },
      })
    else
      UsePanel(s, row, "wash", -4):Paint(inner, innerR, "HORIZONTAL", {
        { 0, A(M.listHaloWash) }, { span * M.listHaloWashStop, A(0) }, { math.huge, A(0) },
      })
    end
  end

  if mark == "halo" then
    local halo = UseTex(s, row, "halo", -3, InitHalo)
    halo:ClearAllPoints()
    local avatar = geom.avatar
    local avatarShown = avatar and avatar:IsShown()
    if vertical then
      halo:SetSize(math.floor((body.w or 140) * 0.95), 170)
      if avatarShown then
        halo:SetPoint("CENTER", avatar, "CENTER", 0, 0)
      else
        halo:SetPoint("CENTER", row, "TOPLEFT", body.x + (body.w or 140) / 2, -(body.y + 40))
      end
    else
      halo:SetSize(300, math.min(120, body.h * 1.6))
      if avatarShown then
        halo:SetPoint("CENTER", avatar, "CENTER", 0, 0)
      else
        halo:SetPoint("CENTER", row, "TOPLEFT", (geom.charX or body.x) + 40, -(body.y + body.h / 2))
      end
    end
    halo:SetVertexColor(accent[1], accent[2], accent[3], M.haloAlpha)
    if avatarShown then
      local half = ((geom.avatarSize or 28) + 11) / 2
      local th = 2
      local ring = {
        { -half, half, half, half - th },
        { -half, -half + th, half, -half },
        { -half, half, -half + th, -half },
        { half - th, half, half, -half },
      }
      for i, e in ipairs(ring) do
        local key = "ring" .. i
        local tex = s.tex[key]
        if not tex then
          tex = row:CreateTexture(nil, "BORDER", nil, -1)
          s.tex[key] = tex
        end
        s.used[key] = true
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", avatar, "CENTER", e[1], e[2])
        tex:SetPoint("BOTTOMRIGHT", avatar, "CENTER", e[3], e[4])
        tex:SetColorTexture(accent[1], accent[2], accent[3], 1)
        tex:Show()
      end
    end
  end

  if mark == "tint" then
    local bar = UseTex(s, row, "bar", -2)
    bar:SetColorTexture(accent[1], accent[2], accent[3], 1)
    if vertical then
      local w = inner.w or 140
      SpanH(row, inner, bar, math.floor(w * 0.3), math.floor(w * 0.7), nil, 0, M.tintBar)
    else
      SpanH(row, inner, bar, 0, M.tintBar, nil, math.floor(inner.h * 0.25), math.floor(inner.h * 0.5))
    end
  end

  Finish(s)
end

function RT.HideSurface(row)
  local s = row.themeSurface
  if not s then return end
  s.used = {}
  Finish(s)
end

function RT.SetHover(row, on)
  local s = row.themeSurface
  if not (s and s.hasCard and s.inner and s.panels and s.panels.card and s.used.card) then return false end
  s.hover = on and true or false
  local c = s.cardColor or s.tokens.cell
  local shown = s.hover and Lighten(c, 0.03) or c
  s.panels.card:Solid(s.inner, s.innerR, shown, s.alphaMul)
  if s.used.tail and s.tex.tail then s.tex.tail:SetVertexColor(shown[1], shown[2], shown[3], s.alphaMul) end
  return true
end

function RT.SurfaceColor(T, isCurrent, vertical)
  local tok = T.tokens
  local base = { 0.09, 0.098, 0.122, 1 }
  if tok.cell and not tok.heat then
    base = { tok.cell[1], tok.cell[2], tok.cell[3], 1 }
  elseif tok.heat and tok.cell then
    base = RT.Mix(base, tok.cell, tok.cell[4] or 0)
  end
  if not isCurrent then return base end
  local mark, M, accent = T.parts.mark, RT.MARK, GG.Theme.accent
  if mark == "fill" then return RT.Mix(base, accent, tok.banner and tok.markFill or M.fill) end
  if mark == "frame" then return RT.Mix(base, accent, M.frameFill) end
  if mark == "tint" then return RT.Mix(base, accent, vertical and M.tintBottom or M.listTintEnd) end
  return base
end

function RT.PaintGlowSeparators(owner, store, x, w, ys, tok)
  store.lines = store.lines or {}
  store.blooms = store.blooms or {}
  local g = { x = x, y = 0, w = w, h = 1 }
  for i, y in ipairs(ys) do
    local line, bloom = store.lines[i], store.blooms[i]
    if not line then
      line = owner:CreateTexture(nil, "BACKGROUND")
      InitGlowLine(line)
      bloom = owner:CreateTexture(nil, "BACKGROUND", nil, 1)
      InitHalo(bloom)
      store.lines[i], store.blooms[i] = line, bloom
    end
    RT.PlaceGlowLine(owner, line, bloom, g, y, tok)
    line:Show()
    bloom:Show()
  end
  for i = #ys + 1, #store.lines do
    store.lines[i]:Hide()
    store.blooms[i]:Hide()
  end
end

function RT.HideGlowSeparators(store)
  for _, t in ipairs(store and store.lines or {}) do t:Hide() end
  for _, t in ipairs(store and store.blooms or {}) do t:Hide() end
end

function RT.PaintSpine(owner, store, g, orient, spans, origin, palette)
  local stops = RT.FadeStops(spans, origin, 1, palette)
  if not stops then return RT.HideSpine(store) end
  store.spine = store.spine or RT.NewPanel(owner, 1, "ARTWORK")
  store.spine:Paint(g, 0, orient, stops)
end

function RT.HideSpine(store)
  if store and store.spine then store.spine:Hide() end
end

function RT.PaintGauge(owner, store, key, x, y, w, pct, color)
  local g = store[key]
  if not g then
    g = { bg = owner:CreateTexture(nil, "ARTWORK"), fill = owner:CreateTexture(nil, "ARTWORK", nil, 1) }
    store[key] = g
  end
  local track = RT.COLORS.track
  w = math.max(4, math.floor(w))
  g.bg:SetColorTexture(track[1], track[2], track[3], 1)
  g.bg:ClearAllPoints()
  g.bg:SetPoint("TOPLEFT", owner, "TOPLEFT", x, -y)
  g.bg:SetSize(w, 3)
  g.bg:Show()
  if pct and pct > 0 then
    g.fill:SetColorTexture(color[1], color[2], color[3], 1)
    g.fill:ClearAllPoints()
    g.fill:SetPoint("TOPLEFT", g.bg, "TOPLEFT", 0, 0)
    g.fill:SetSize(math.max(1, math.floor(w * math.min(1, pct) + 0.5)), 3)
    g.fill:Show()
  else
    g.fill:Hide()
  end
end

function RT.HideGauge(store, key)
  local g = store and store[key]
  if g then g.bg:Hide(); g.fill:Hide() end
end

function RT.GaugePct(value, lo, hi)
  if not value or value <= 0 then return 0 end
  if not hi or not lo or hi <= lo then return 1 end
  return math.max(0.06, math.min(1, (value - lo) / (hi - lo)))
end

function RT.PaintSegmentBar(cell, bar, slots, total, x0, yTop, width, height, color)
  local sb = bar.segBar
  if not sb then
    sb = { segs = {} }
    sb.count = cell:CreateFontString(nil, "OVERLAY")
    sb.count:SetJustifyH("RIGHT")
    sb.count:SetWordWrap(false)
    bar.segBar = sb
  end
  total = math.max(1, total or 1)
  local COUNT_W, COUNT_GAP, SEG_GAP, SEG_H = 24, 8, 2, 8
  local area = width - x0 - COUNT_W - COUNT_GAP
  local segW = math.max(2, math.floor((area - (total - 1) * SEG_GAP) / total))
  local cy = yTop - height / 2
  local killed = 0
  local track = RT.COLORS.track
  for i = 1, math.max(total, #sb.segs) do
    local seg = sb.segs[i]
    if i <= total then
      if not seg then
        seg = cell:CreateTexture(nil, "ARTWORK")
        sb.segs[i] = seg
      end
      local dead = slots and slots[i] == true
      if dead then killed = killed + 1 end
      if dead then
        seg:SetColorTexture(color[1], color[2], color[3], 1)
      else
        seg:SetColorTexture(track[1], track[2], track[3], 1)
      end
      seg:ClearAllPoints()
      seg:SetPoint("TOPLEFT", cell, "TOPLEFT", x0 + (i - 1) * (segW + SEG_GAP), cy + SEG_H / 2)
      seg:SetSize(segW, SEG_H)
      seg:Show()
    elseif seg then
      seg:Hide()
    end
  end
  local used = total * segW + (total - 1) * SEG_GAP
  local Theme = GG.Theme
  sb.count:SetFont(Theme.fontBold, 12, "")
  sb.count:SetTextColor(unpack(killed >= total and Theme.textPrimary or Theme.textMuted))
  sb.count:SetText(("%d/%d"):format(killed, total))
  sb.count:SetWidth(COUNT_W + 8)
  sb.count:ClearAllPoints()
  sb.count:SetPoint("RIGHT", cell, "TOPLEFT", x0 + used + COUNT_GAP + COUNT_W, cy)
  sb.count:Show()
  sb.shown = true
end

function RT.HideSegmentBar(bar)
  local sb = bar and bar.segBar
  if not sb or not sb.shown then return end
  for _, seg in ipairs(sb.segs) do seg:Hide() end
  sb.count:Hide()
  sb.shown = false
end

RT.CHECK_SIZE = 16
RT.CHECK_GAP = 8
local DISC = "Interface\\AddOns\\GG\\Media\\SwitchKnob64.tga"

function RT.PaintCheck(owner, store, anchor, ringColor, done, holeColor)
  local c = store.themeCheck
  if not c then
    c = {
      ring = owner:CreateTexture(nil, "ARTWORK"),
      hole = owner:CreateTexture(nil, "ARTWORK", nil, 1),
      dot = owner:CreateTexture(nil, "ARTWORK", nil, 2),
    }
    for _, t in pairs(c) do t:SetTexture(DISC) end
    store.themeCheck = c
  end
  local size = RT.CHECK_SIZE
  c.ring:SetSize(size, size)
  c.hole:SetSize(size - 4, size - 4)
  c.dot:SetSize(6, 6)
  for _, t in pairs(c) do
    t:ClearAllPoints()
    t:SetPoint("CENTER", anchor, "CENTER", 0, 0)
  end
  c.ring:SetVertexColor(ringColor[1], ringColor[2], ringColor[3], 1)
  c.hole:SetVertexColor(holeColor[1], holeColor[2], holeColor[3], 1)
  local green = GG.Theme.success
  c.dot:SetVertexColor(green[1], green[2], green[3], 1)
  c.ring:Show()
  c.hole:Show()
  c.dot:SetShown(done == true)
end

function RT.HideCheck(store)
  local c = store and store.themeCheck
  if c then c.ring:Hide(); c.hole:Hide(); c.dot:Hide() end
end
