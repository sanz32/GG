local ADDON_NAME, GG = ...

local Tip = {}
GG.Tip = Tip

local WHITE = "Interface\\Buttons\\WHITE8x8"
local TICK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"
local EDGE_COLOR = { 0.50, 0.52, 0.60, 1 }
local CAP_COLOR = { 1, 0.624, 0.247, 1 }
local PILL_COLORS = {
  done = "success",
  warn = nil,
  bad = "danger",
}
local FAMILY_COLORS = {
  vault = "gold", money = "gold", keys = "teal",
  quest = "purple", ui = "purple",
  roster = "accentStrong", raid = "accentStrong",
  danger = "danger",
}

local MIN_WIDTH, MAX_WIDTH = 250, 340
local COMPACT_MAX_WIDTH = 280
local PAD = 11
local COMPACT_PAD = 9
local ICON_SIZE = 30
local KV_HEIGHT = 17
local ACTION_HEIGHT = 18
local BOSS_W, BOSS_H = 46, 23
local CELL_GAP = 3
local VAULT_LABEL_W = 62

function Tip.Paint(text, color)
  return ("|cff%02x%02x%02x%s|r"):format(
    math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), tostring(text))
end

function Tip.Rich(text, color)
  return (tostring(text):gsub("%*([^*]+)%*", function(word) return Tip.Paint(word, color) end))
end

function Tip.Label(text)
  return (tostring(text):gsub("%s*:%s*$", ""))
end

function Tip.Blend(base, color, amount)
  return {
    base[1] + (color[1] - base[1]) * amount,
    base[2] + (color[2] - base[2]) * amount,
    base[3] + (color[3] - base[3]) * amount,
    1,
  }
end

function Tip.Fraction(value, max)
  if not max or max <= 0 then return 0 end
  return math.max(0, math.min(1, (value or 0) / max))
end

local Builder = {}
Builder.__index = Builder

function Builder:SetColor(color) self.color = color end

local function Add(self, item)
  self.items[#self.items + 1] = item
  return item
end

function Builder:Head(head)
  head.kind = "plain"
  if head.kicker == "" then head.kicker = nil end
  self.head = head
end

function Builder:Identity(head)
  head.kind = "identity"
  self.head = head
end

function Builder:BossHead(head)
  head.kind = "boss"
  self.head = head
end

function Builder:Title(text, color) Add(self, { kind = "title", text = text, color = color }) end

function Builder:Text(text, color, small)
  Add(self, { kind = "text", text = Tip.Rich(text, self.color), color = color, small = small })
end

function Builder:Kv(label, value, color)
  Add(self, { kind = "kv", label = Tip.Label(label), value = tostring(value),
    color = color == true and self.color or color })
end

function Builder:Sep() Add(self, { kind = "sep" }) end
function Builder:Gap(height) Add(self, { kind = "gap", height = height or 4 }) end

function Builder:Status(label, pill, state)
  Add(self, { kind = "status", label = Tip.Label(label), pill = pill, state = state })
end

function Builder:Bar(value, max, color)
  Add(self, { kind = "bar", fraction = Tip.Fraction(value, max), color = color })
end

function Builder:Segs(list) Add(self, { kind = "segs", list = list }) end
function Builder:Group(name, right, color) Add(self, { kind = "group", name = name, rightText = right, color = color }) end
function Builder:Boss(icon, name, dead) Add(self, { kind = "bossrow", icon = icon, name = name, dead = dead == true }) end

function Builder:Vault(rows) Add(self, { kind = "vault", rows = rows }) end

function Builder:Line(icon, color, text) Add(self, { kind = "line", icon = icon, color = color, text = text }) end

function Builder:Action(key, text)
  self.actions[#self.actions + 1] = { key = key, text = text }
end

function Tip.ColorFor(opts)
  if opts.color then return opts.color end
  local Theme = GG.Theme
  return Theme[FAMILY_COLORS[opts.family] or "purple"]
end

function Tip.Build(opts, draw, state)
  local builder = setmetatable({ items = {}, actions = {}, color = Tip.ColorFor(opts) }, Builder)
  draw(builder, state)
  return builder
end

local card
local openCount = 0
local pools ={ fs = { used = 0 }, tex = { used = 0 }, box = { used = 0 } }

local function Acquire(pool, create)
  pool.used = pool.used + 1
  local widget = pool[pool.used]
  if not widget then
    widget = create()
    pool[pool.used] = widget
  end
  widget:ClearAllPoints()
  widget:Show()
  return widget
end

local function FS(size, color, bold, parent)
  local Theme = GG.Theme
  local fs
  if parent then
    fs = parent.text
    fs:Show()
    fs:ClearAllPoints()
  else
    fs = Acquire(pools.fs, function() return card.body:CreateFontString(nil, "OVERLAY") end)
  end
  fs:SetFont(bold and Theme.fontBold or Theme.font, size, "")
  fs:SetTextColor(color[1], color[2], color[3], 1)
  fs:SetWordWrap(false)
  fs:SetJustifyH("LEFT")
  fs:SetWidth(0)
  return fs
end

local function Tex(subLevel)
  local tex = Acquire(pools.tex, function() return card.body:CreateTexture(nil, "ARTWORK") end)
  tex:SetDrawLayer("ARTWORK", subLevel or 2)
  tex:SetTexture(nil)
  tex:SetTexCoord(0, 1, 0, 1)
  tex:SetDesaturated(false)
  tex:SetVertexColor(1, 1, 1, 1)
  return tex
end

local function Box(fill, border)
  local box = Acquire(pools.box, function()
    local b = CreateFrame("Frame", nil, card.body, "BackdropTemplate")
    b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    b.text = b:CreateFontString(nil, "OVERLAY")
    return b
  end)
  box:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
  local line = border or fill
  box:SetBackdropBorderColor(line[1], line[2], line[3], line[4] or 1)
  return box
end

local function BoxText(box, text, size, color)
  local fs = FS(size, color, true, box)
  fs:SetText(text)
  fs:SetPoint("CENTER", box, "CENTER", 0, 0)
  return fs
end

local function ReleaseUnused()
  for _, pool in pairs(pools) do
    for i = pool.used + 1, #pool do pool[i]:Hide() end
  end
end

local function CreateCard()
  local Theme = GG.Theme
  local f = CreateFrame("Frame", "GGTipCard", UIParent, "BackdropTemplate")
  f:SetFrameStrata("TOOLTIP")
  f:SetClampedToScreen(true)
  f:Hide()
  GG.Widgets.ApplyPanel(f, { bg = EDGE_COLOR, tint = EDGE_COLOR })
  local body = CreateFrame("Frame", nil, f, "BackdropTemplate")
  body:SetPoint("TOPLEFT", 1, -1)
  body:SetPoint("BOTTOMRIGHT", -1, 1)
  local bg = Theme.background
  f.bodyColor = { bg[1], bg[2], bg[3], 1 }
  f.panel = GG.Widgets.ApplyPanel(body, { bg = f.bodyColor, tint = Theme.panel, radius = Theme.cornerRadius - 1 })
  f.body = body

  f.headFill = body:CreateTexture(nil, "ARTWORK")
  f.headFill:SetPoint("TOPLEFT", 0, -(Theme.cornerRadius - 1))
  f.headFill:SetPoint("TOPRIGHT", 0, -(Theme.cornerRadius - 1))
  f.headLine = body:CreateTexture(nil, "ARTWORK", nil, 1)
  f.headLine:SetHeight(1)
  f.footLine = body:CreateTexture(nil, "ARTWORK", nil, 1)
  f.footLine:SetHeight(1)
  f.footLine:SetColorTexture(unpack(Theme.borderSoft))

  f:SetScript("OnUpdate", function(self)
    local owner = self.owner
    local over = owner and owner:IsVisible()
      and (owner:IsMouseOver() or (self.alsoOver and self.alsoOver:IsVisible() and self.alsoOver:IsMouseOver()))
    if not over then
      self.misses = (self.misses or 0) + 1
      if self.misses >= 2 then Tip:Hide() end
      return
    end
    self.misses = 0
    if self.watch then
      local state = self.watch()
      if not state then
        Tip:Hide()
      elseif state ~= self.state then
        self.state = state
        Tip.Render(Tip.Build(self.opts, self.draw, state))
      end
    end
  end)
  return f
end

local function PaintTopBand(color)
  local pieces = card.panel.pieces
  pieces[1]:SetVertexColor(color[1], color[2], color[3], 1)
  pieces[2]:SetVertexColor(color[1], color[2], color[3], 1)
  pieces[3]:SetColorTexture(color[1], color[2], color[3], 1)
end

local Items = {}

Items.title = {
  measure = function(item, color)
    item.fs = FS(13, item.color or color, true)
    item.fs:SetText(item.text)
    return item.fs:GetStringWidth()
  end,
  place = function(item, x, y)
    item.fs:SetPoint("TOPLEFT", x, y)
    return 17
  end,
}

Items.text = {
  measure = function(item, _, compact)
    local Theme = GG.Theme
    item.fs = FS(item.small and 12 or 13, item.color or (compact and Theme.textPrimary or Theme.textMuted))
    item.fs:SetText(item.text)
    return compact and math.min(item.fs:GetStringWidth(), COMPACT_MAX_WIDTH) or 0
  end,
  place = function(item, x, y, inner)
    item.fs:SetWordWrap(true)
    item.fs:SetWidth(inner)
    item.fs:SetPoint("TOPLEFT", x, y)
    return item.fs:GetStringHeight() + 3
  end,
}

Items.kv = {
  measure = function(item)
    local Theme = GG.Theme
    item.left = FS(13, Theme.textFaint)
    item.left:SetText(item.label)
    item.right = FS(13, item.color or Theme.textPrimary, item.color ~= nil)
    item.right:SetText(item.value)
    return item.left:GetStringWidth() + item.right:GetStringWidth() + 14
  end,
  place = function(item, x, y, inner)
    item.left:SetPoint("TOPLEFT", x, y)
    item.right:SetPoint("TOPRIGHT", item.left, "TOPLEFT", inner, 0)
    return KV_HEIGHT
  end,
}

Items.sep = {
  measure = function(item)
    item.tex = Tex()
    item.tex:SetColorTexture(unpack(GG.Theme.borderSoft))
    return 0
  end,
  place = function(item, x, y, inner)
    item.tex:SetSize(inner, 1)
    item.tex:SetPoint("TOPLEFT", x, y - 3)
    return 8
  end,
}

Items.gap = {
  measure = function() return 0 end,
  place = function(item) return item.height end,
}

Items.status = {
  measure = function(item, color)
    local Theme = GG.Theme
    local tone = (item.state == "warn" and CAP_COLOR)
      or (item.state and Theme[PILL_COLORS[item.state]])
      or Theme.textFaint
    item.left = FS(13, Theme.textPrimary, true)
    item.left:SetText(item.label)
    local fill = item.state and { tone[1], tone[2], tone[3], 0.17 } or { 0.137, 0.153, 0.192, 1 }
    item.box = Box(fill)
    local fs = BoxText(item.box, item.pill, 11, tone)
    local w = fs:GetStringWidth() + 12
    item.box:SetSize(w, 15)
    return item.left:GetStringWidth() + w + 12
  end,
  place = function(item, x, y, inner)
    item.left:SetPoint("TOPLEFT", x, y)
    item.box:SetPoint("TOPLEFT", x + inner - item.box:GetWidth(), y + 1)
    return KV_HEIGHT + 1
  end,
}

Items.bar = {
  measure = function(item, color)
    item.track = Tex()
    item.track:SetColorTexture(0.137, 0.153, 0.192, 1)
    item.fill = Tex(3)
    local c = item.color or color
    item.fill:SetColorTexture(c[1], c[2], c[3], 1)
    return 0
  end,
  place = function(item, x, y, inner)
    item.track:SetSize(inner, 5)
    item.track:SetPoint("TOPLEFT", x, y - 1)
    item.fill:SetSize(math.max(1, inner * item.fraction), 5)
    item.fill:SetPoint("TOPLEFT", x, y - 1)
    item.fill:SetShown(item.fraction > 0)
    return 10
  end,
}

Items.segs = {
  measure = function(item, color)
    item.cells = {}
    for i, on in ipairs(item.list) do
      local tex = Tex()
      local c = on and color or { 0.204, 0.220, 0.263, 1 }
      tex:SetColorTexture(c[1], c[2], c[3], 1)
      item.cells[i] = tex
    end
    return 0
  end,
  place = function(item, x, y, inner)
    local n = #item.cells
    local w = (inner - (n - 1) * 2) / math.max(n, 1)
    for i, tex in ipairs(item.cells) do
      tex:SetSize(w, 5)
      tex:SetPoint("TOPLEFT", x + (i - 1) * (w + 2), y)
    end
    return 11
  end,
}

Items.group = {
  measure = function(item)
    local Theme = GG.Theme
    item.left = FS(12, item.color or Theme.textFaint, true)
    item.left:SetText(item.name)
    item.right = FS(12, Theme.textFaint, true)
    item.right:SetText(item.rightText or "")
    return item.left:GetStringWidth() + item.right:GetStringWidth() + 14
  end,
  place = function(item, x, y, inner)
    item.left:SetPoint("TOPLEFT", x, y)
    item.right:SetPoint("TOPRIGHT", item.left, "TOPLEFT", inner, 0)
    return 16
  end,
}

Items.bossrow = {
  measure = function(item)
    local Theme = GG.Theme
    item.name_fs = FS(13, item.dead and Theme.success or Theme.textFaint)
    item.name_fs:SetText(item.name)
    if item.icon then
      item.portrait = Tex()
      item.portrait:SetTexture(item.icon)
      item.portrait:SetDesaturated(not item.dead)
      if not item.dead then item.portrait:SetVertexColor(0.62, 0.62, 0.62, 1) end
    end
    if item.dead then
      item.tick = Tex()
      item.tick:SetTexture(TICK_TEXTURE)
    end
    return (item.icon and BOSS_W + 6 or 0) + item.name_fs:GetStringWidth() + 20
  end,
  place = function(item, x, y, inner)
    local height = item.icon and BOSS_H or 18
    local textX = x
    if item.portrait then
      item.portrait:SetSize(BOSS_W, BOSS_H)
      item.portrait:SetPoint("TOPLEFT", x, y)
      textX = x + BOSS_W + 6
    end
    item.name_fs:SetPoint("LEFT", card.body, "TOPLEFT", textX, y - height / 2)
    if item.tick then
      item.tick:SetSize(13, 13)
      item.tick:SetPoint("RIGHT", card.body, "TOPLEFT", x + inner, y - height / 2)
    end
    return height
  end,
}

Items.vault = {
  measure = function(item)
    local Theme = GG.Theme
    for _, row in ipairs(item.rows) do
      row.fs = FS(12, Theme.textFaint)
      row.fs:SetText(row.label)
      for _, cell in ipairs(row.cells) do
        local success = Theme.success
        cell.box = cell.on
          and Box({ success[1], success[2], success[3], 0.17 }, { success[1], success[2], success[3], 0.55 })
          or Box({ 0.137, 0.153, 0.192, 1 })
        cell.fs = BoxText(cell.box, cell.text, 12, cell.on and success or Theme.textFaint)
      end
    end
    return 0
  end,
  place = function(item, x, y, inner)
    local cellY = y
    for _, row in ipairs(item.rows) do
      local n = math.max(#row.cells, 1)
      local w = (inner - VAULT_LABEL_W - n * CELL_GAP) / n
      row.fs:SetPoint("TOPLEFT", x, cellY - 3)
      for i, cell in ipairs(row.cells) do
        cell.box:SetSize(w, 19)
        cell.box:SetPoint("TOPLEFT", x + VAULT_LABEL_W + (i - 1) * (w + CELL_GAP) + CELL_GAP, cellY)
        cell.fs:SetWidth(w - 2)
        cell.fs:SetJustifyH("CENTER")
      end
      cellY = cellY - 19 - CELL_GAP
    end
    return y - cellY + 2
  end,
}

Items.line = {
  measure = function(item)
    item.tex = Tex()
    item.tex:SetTexture(item.icon)
    item.tex:SetVertexColor(item.color[1], item.color[2], item.color[3], 1)
    item.fs = FS(13, item.color)
    item.fs:SetText(item.text)
    return item.fs:GetStringWidth() + 15
  end,
  place = function(item, x, y)
    item.tex:SetSize(11, 11)
    item.tex:SetPoint("TOPLEFT", x, y - 1)
    item.fs:SetPoint("TOPLEFT", x + 15, y)
    return KV_HEIGHT
  end,
}

local Heads = {}

Heads.plain = {
  measure = function(head, color)
    local Theme = GG.Theme
    head.height = head.kicker and 44 or 34
    local width = 0
    if head.kicker then
      head.kickerFs = FS(9, Tip.Blend(Theme.textFaint, color, 0.7), true)
      head.kickerFs:SetText(head.kicker:upper())
      width = head.kickerFs:GetStringWidth()
    end
    head.titleFs = FS(16, head.titleColor or color, true)
    head.titleFs:SetText(head.title or "?")
    width = math.max(width, head.titleFs:GetStringWidth())
    if head.right ~= nil then
      head.rightFs = FS(18, color, true)
      local text = tostring(head.right)
      if head.rightOf then text = text .. Tip.Paint("/" .. head.rightOf, Theme.textFaint) end
      head.rightFs:SetText(text)
      width = width + head.rightFs:GetStringWidth() + 14
    end
    return width
  end,
  place = function(head)
    local top = -8
    if head.kickerFs then
      head.kickerFs:SetPoint("TOPLEFT", PAD, top)
      top = top - 13
    end
    head.titleFs:SetPoint("TOPLEFT", PAD, top)
    if head.rightFs then
      head.rightFs:SetPoint("RIGHT", card.body, "TOPRIGHT", -PAD, -head.height / 2)
    end
  end,
}

Heads.identity = {
  measure = function(head, color)
    local Theme = GG.Theme
    head.height = 50
    if head.isMain then
      head.mainRing = Tex(2)
      head.mainRing:SetColorTexture(unpack(Theme.gold))
    end
    head.ring = Tex(3)
    local ring = head.ringColor or color
    head.ring:SetColorTexture(ring[1], ring[2], ring[3], 1)
    head.icon = Tex(4)
    GG.Widgets.SetClassIcon(head.icon, head.coords)
    head.nameFs = FS(16, color, true)
    head.nameFs:SetText(head.name or "?")
    head.placeFs = FS(12, Theme.textFaint)
    head.placeFs:SetText(head.place or "")
    head.levelTitle = FS(9, Tip.Blend(Theme.textFaint, color, 0.7), true)
    head.levelTitle:SetText(head.levelLabel:upper())
    head.levelValue = FS(18, Theme.textPrimary, true)
    head.levelValue:SetText(tostring(head.level or "?"))
    if head.badge then
      head.badgeBox = Box(Theme.gold)
      local fs = BoxText(head.badgeBox, head.badge, 10, { 0.05, 0.055, 0.07, 1 })
      head.badgeBox:SetSize(fs:GetStringWidth() + 8, 13)
    end
    local nameWidth = head.nameFs:GetStringWidth() + (head.badgeBox and head.badgeBox:GetWidth() + 5 or 0)
    return ICON_SIZE + 9 + math.max(nameWidth, head.placeFs:GetStringWidth()) + 44
  end,
  place = function(head, width)
    local body = card.body
    head.ring:SetSize(ICON_SIZE, ICON_SIZE)
    head.ring:SetPoint("LEFT", body, "TOPLEFT", PAD + 1, -head.height / 2)
    if head.mainRing then
      head.mainRing:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
      head.mainRing:SetPoint("CENTER", head.ring, "CENTER")
    end
    head.icon:SetSize(ICON_SIZE - 4, ICON_SIZE - 4)
    head.icon:SetPoint("CENTER", head.ring, "CENTER")
    head.levelTitle:SetPoint("TOPRIGHT", body, "TOPRIGHT", -PAD, -10)
    head.levelValue:SetPoint("TOPRIGHT", head.levelTitle, "BOTTOMRIGHT", 0, -2)
    local avail = width - PAD * 2 - ICON_SIZE - 9 - 44
    head.nameFs:SetPoint("TOPLEFT", head.ring, "TOPRIGHT", 9, 0)
    local badgeWidth = head.badgeBox and head.badgeBox:GetWidth() + 5 or 0
    head.nameFs:SetWidth(math.min(head.nameFs:GetStringWidth() + 1, avail - badgeWidth))
    head.placeFs:SetPoint("BOTTOMLEFT", head.ring, "BOTTOMRIGHT", 9, 0)
    head.placeFs:SetWidth(avail)
    if head.badgeBox then head.badgeBox:SetPoint("LEFT", head.nameFs, "RIGHT", 5, 0) end
  end,
}

Heads.boss = {
  measure = function(head, color)
    local Theme = GG.Theme
    head.height = 48
    if head.icon then
      head.portrait = Tex(3)
      head.portrait:SetTexture(head.icon)
      head.portrait:SetDesaturated(not head.dead)
      if not head.dead then head.portrait:SetVertexColor(0.62, 0.62, 0.62, 1) end
    end
    head.titleFs = FS(15, head.titleColor or color, true)
    head.titleFs:SetText(head.title or "?")
    head.subFs = FS(12, Theme.textFaint)
    head.subFs:SetText(head.sub or "")
    local textWidth = math.max(head.titleFs:GetStringWidth(), head.subFs:GetStringWidth())
    return (head.icon and 78 or 0) + textWidth
  end,
  place = function(head)
    local x = PAD
    if head.portrait then
      head.portrait:SetSize(72, 36)
      head.portrait:SetPoint("LEFT", card.body, "TOPLEFT", PAD - 2, -head.height / 2)
      x = PAD + 74
    end
    head.titleFs:SetPoint("TOPLEFT", x, -8)
    head.subFs:SetPoint("TOPLEFT", x, -26)
  end,
}

local function MeasureAction(action)
  local Theme = GG.Theme
  action.box = Box(Theme.panel, Theme.border)
  local fs = BoxText(action.box, action.key, 11, Theme.textPrimary)
  action.box:SetSize(fs:GetStringWidth() + 8, 15)
  action.fs = FS(12, Theme.textMuted)
  action.fs:SetText(action.text)
  return action.box:GetWidth() + 6 + action.fs:GetStringWidth()
end

function Tip.Render(built)
  local Theme = GG.Theme
  local color = built.color
  pools.fs.used, pools.tex.used, pools.box.used = 0, 0, 0
  local compact = built.head == nil
  local pad = compact and COMPACT_PAD or PAD

  local width = compact and 0 or MIN_WIDTH
  local head = built.head
  if head then width = math.max(width, Heads[head.kind].measure(head, color) + PAD * 2) end
  for _, item in ipairs(built.items) do
    width = math.max(width, Items[item.kind].measure(item, color, compact) + pad * 2)
  end
  for _, action in ipairs(built.actions) do
    width = math.max(width, MeasureAction(action) + pad * 2)
  end
  width = math.ceil(math.min(width, compact and COMPACT_MAX_WIDTH + pad * 2 or MAX_WIDTH))

  local inner = width - pad * 2
  local y
  if head then
    Heads[head.kind].place(head, width)
    local fill = Tip.Blend(Theme.panel, color, 0.09)
    local line = Tip.Blend(Theme.border, color, 0.27)
    PaintTopBand(fill)
    card.headFill:SetColorTexture(fill[1], fill[2], fill[3], 1)
    card.headFill:SetHeight(head.height - Theme.cornerRadius + 1)
    card.headFill:Show()
    card.headLine:SetColorTexture(line[1], line[2], line[3], 1)
    card.headLine:ClearAllPoints()
    card.headLine:SetPoint("TOPLEFT", 0, -head.height)
    card.headLine:SetPoint("TOPRIGHT", 0, -head.height)
    card.headLine:Show()
    y = -head.height - (#built.items > 0 and 8 or 0)
  else
    PaintTopBand(card.bodyColor)
    card.headFill:Hide()
    card.headLine:Hide()
    y = -7
  end
  for _, item in ipairs(built.items) do
    y = y - Items[item.kind].place(item, pad, y, inner)
  end

  if #built.actions > 0 then
    y = y - (#built.items > 0 and 4 or 0)
    card.footLine:ClearAllPoints()
    card.footLine:SetPoint("TOPLEFT", 0, y)
    card.footLine:SetPoint("TOPRIGHT", 0, y)
    card.footLine:Show()
    y = y - 6
    for _, action in ipairs(built.actions) do
      action.box:SetPoint("TOPLEFT", pad, y)
      action.fs:SetPoint("LEFT", action.box, "RIGHT", 6, 0)
      y = y - ACTION_HEIGHT
    end
    y = y + 2
  else
    card.footLine:Hide()
  end

  ReleaseUnused()
  card:SetSize(width + 2, -y + (compact and 6 or 7))
end

local function Anchor(owner, anchor)
  card:ClearAllPoints()
  if anchor == "TOP" then
    card:SetPoint("BOTTOM", owner, "TOP", 0, 6)
  elseif anchor == "BOTTOM" then
    card:SetPoint("TOP", owner, "BOTTOM", 0, -6)
  elseif anchor == "BOTTOMRIGHT" then
    card:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -6)
  else
    local right = (owner:GetRight() or 0) * owner:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if right + card:GetWidth() + 8 > UIParent:GetWidth() then
      card:SetPoint("TOPRIGHT", owner, "TOPLEFT", -8, 0)
    else
      card:SetPoint("TOPLEFT", owner, "TOPRIGHT", 8, 0)
    end
  end
end

function Tip:Open(owner, opts, draw)
  if GG.Widgets.MenuCovers(owner) then return self:Hide() end
  local state
  if opts.watch then
    state = opts.watch()
    if not state then return self:Hide() end
  end
  card = card or CreateCard()
  card.owner, card.opts, card.draw = owner, opts, draw
  card.alsoOver, card.watch, card.state = opts.alsoOver, opts.watch, state
  card.misses = 0
  self.Render(self.Build(opts, draw, state))
  Anchor(owner, opts.anchor)
  card:Show()
  openCount = openCount + 1
  local session = openCount
  local function Remeasure()
    if not card:IsShown() or openCount ~= session or card.owner ~= owner then return end
    Tip.Render(Tip.Build(card.opts, card.draw, card.state))
    Anchor(owner, card.opts.anchor)
  end
  C_Timer.After(0, Remeasure)
  C_Timer.After(0.5, Remeasure)
end

function Tip:Owner()
  return card and card:IsShown() and card.owner or nil
end

function Tip:Hide()
  if not card then return end
  card:Hide()
  card.owner, card.opts, card.draw, card.alsoOver, card.watch, card.state = nil, nil, nil, nil, nil, nil
end

function Tip.DrawCurrency(t, currency, L)
  t:Head({ title = currency.name or "?", right = currency.quantity or 0 })
  local function Limit(label, value, max, atCap)
    t:Kv(label, ("%d / %d"):format(value, max), atCap and CAP_COLOR or true)
    t:Bar(value, max, atCap and CAP_COLOR or nil)
  end
  if currency.maxWeeklyQuantity and currency.maxWeeklyQuantity > 0 then
    local earned = currency.quantityEarnedThisWeek or 0
    Limit(L["CURRENCY_WEEKLY"], earned, currency.maxWeeklyQuantity, earned >= currency.maxWeeklyQuantity)
  end
  if currency.maxQuantity and currency.maxQuantity > 0 then
    local atCap = GG.Currencies:IsAtCap(currency)
    if currency.useTotalEarnedForMaxQty then
      Limit(L["CURRENCY_TOTAL"], currency.totalEarned or 0, currency.maxQuantity, atCap)
      if currency.staleCap then t:Text(L["CURRENCY_STALE_CAP"], GG.Theme.gold, true) end
    else
      Limit(L["CURRENCY_CAP"], currency.quantity or 0, currency.maxQuantity, atCap)
    end
  end
end
