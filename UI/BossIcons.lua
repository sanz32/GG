local ADDON_NAME, GG = ...

GG.BossIcons = {}

local MEDIA = [[Interface\AddOns\GG\Media\BossIcons\]]

GG.BossIcons.STYLES = {
  { key = "skull", labelKey = "BOSS_STYLE_SKULL" },
  { key = "hex", labelKey = "BOSS_STYLE_HEX" },
  { key = "gems", labelKey = "BOSS_STYLE_GEMS" },
  { key = "runes", labelKey = "BOSS_STYLE_RUNES" },
  { key = "futhark_latin", labelKey = "BOSS_STYLE_FUTHARK_LATIN" },
  { key = "futhark", labelKey = "BOSS_STYLE_FUTHARK" },
}
GG.BossIcons.DEFAULT_STYLE = "skull"

local VALID = {}
for _, style in ipairs(GG.BossIcons.STYLES) do VALID[style.key] = true end

local LETTERS = { N = true, S = true, E = true, V = true, T = true, C = true, U = true, K = true }
local NUM_RUNES = 10

local DIM = { 0.302, 0.318, 0.376, 1 }
local SKULL_DIM = { 0.235, 0.251, 0.298, 1 }
local HEX_EMPTY = { 0.149, 0.165, 0.204, 1 }
local HEX_EMPTY_RING = { 0.227, 0.247, 0.298, 1 }

function GG.BossIcons:GetStyle()
  local style = GGDB and GGDB.options and GGDB.options.bossIconStyle
  if style and VALID[style] then return style end
  return self.DEFAULT_STYLE
end

function GG.BossIcons:SetStyle(style)
  if not VALID[style] then return end
  GGDB.options.bossIconStyle = style
end

function GG.BossIcons:LetterFor(raid, index)
  return raid and raid.bossLetters and raid.bossLetters[index] or nil
end

function GG.BossIcons:LetterForSlot(slot)
  local offset = 0
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    local count = raid.numEncounters or 0
    if slot <= offset + count then return self:LetterFor(raid, slot - offset) end
    offset = offset + count
  end
  return nil
end

function GG.BossIcons:Honeycomb(count, width, height, maxIconSize, gap)
  if count <= 0 then return maxIconSize, {} end
  local top = math.ceil(count / 2)
  local bottom = count - top
  local halfExtra = bottom >= top and 0.5 or 0
  local lineHeight = height / 2
  local size = math.floor((width - (top - 1 + halfExtra) * gap) / (top + halfExtra))
  size = math.max(4, math.min(maxIconSize, lineHeight, size))
  local step = size + gap
  local totalWidth = (top - 1 + halfExtra) * step + size
  local x0 = math.max(0, (width - totalWidth) / 2)

  local positions = {}
  for i = 1, count do
    local row = i <= top and 0 or 1
    local col = row == 0 and (i - 1) or (i - top - 1)
    positions[i] = {
      x = x0 + col * step + row * step / 2,
      y = row * lineHeight + (lineHeight - size) / 2,
    }
  end
  return size, positions
end

GG.BossIcons.INTERLOCK_DX = 38.56 / 64
GG.BossIcons.INTERLOCK_DY = 36.95 / 64

function GG.BossIcons:IsInterlocking(style)
  return (style or self:GetStyle()) == "skull"
end

function GG.BossIcons:PixelsPerUnit(frame)
  if not (GetPhysicalScreenSize and frame and frame.GetEffectiveScale) then return 1 end
  local _, physicalHeight = GetPhysicalScreenSize()
  if not physicalHeight or physicalHeight <= 0 then return 1 end
  return frame:GetEffectiveScale() * physicalHeight / 768
end

function GG.BossIcons:SnapLine(iconSize, gap, pixelsPerUnit)
  local ppu = pixelsPerUnit or 1
  local sizePixels = math.max(1, math.floor(iconSize * ppu))
  local stepPixels = math.max(sizePixels, math.floor((iconSize + gap) * ppu + 0.5))
  return sizePixels / ppu, stepPixels / ppu
end

function GG.BossIcons:Interlock(count, width, height, maxIconSize, pixelsPerUnit)
  if count <= 0 then return maxIconSize, {} end
  local ppu = pixelsPerUnit or 1
  local function Snap(value) return math.floor(value * ppu + 0.5) / ppu end
  local dx, dy = self.INTERLOCK_DX, self.INTERLOCK_DY
  local minPixels = math.ceil(4 * ppu)
  local sizePixels = math.floor(ppu * math.min(maxIconSize, width / (1 + (count - 1) * dx), height / (1 + dy)))
  sizePixels = math.max(minPixels, sizePixels)
  local size, stepX, stepY
  while true do
    size = sizePixels / ppu
    stepX, stepY = Snap(dx * size), Snap(dy * size)
    local fits = size + (count - 1) * stepX <= width + 0.001 and size + stepY <= height + 0.001
    if fits or sizePixels <= minPixels then break end
    sizePixels = sizePixels - 1
  end
  local x0 = Snap(math.max(0, (width - (size + (count - 1) * stepX)) / 2))
  local y0 = Snap(math.max(0, (height - (size + stepY)) / 2))
  local positions = {}
  for i = 1, count do
    positions[i] = {
      x = x0 + (i - 1) * stepX,
      y = y0 + ((i % 2 == 0) and stepY or 0),
    }
  end
  return size, positions
end

function GG.BossIcons:Create(parent)
  local icon = CreateFrame("Frame", nil, parent)
  icon:EnableMouse(false)
  icon.glow = icon:CreateTexture(nil, "BACKGROUND")
  icon.base = icon:CreateTexture(nil, "ARTWORK", nil, 0)
  icon.top = icon:CreateTexture(nil, "ARTWORK", nil, 1)
  icon.shine = icon:CreateTexture(nil, "OVERLAY")
  icon.base:SetAllPoints()
  return icon
end

local function Layer(tex, file, color, alpha)
  tex:SetTexture(file)
  tex:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
  tex:Show()
end

local function Centered(tex, icon, scale)
  local w = icon:GetWidth()
  if not w or w <= 0 then w = 16 end
  w = w * scale
  tex:ClearAllPoints()
  tex:SetSize(w, w)
  tex:SetPoint("CENTER", icon, "CENTER", 0, 0)
end

function GG.BossIcons:Paint(icon, killed, color, slot, letter, style)
  style = style or self:GetStyle()
  icon.glow:Hide(); icon.top:Hide(); icon.shine:Hide()
  local tint = killed and color or DIM

  if style == "hex" then
    if killed then
      Layer(icon.base, MEDIA .. "hex", color)
    else
      Layer(icon.base, MEDIA .. "hex", HEX_EMPTY)
      Layer(icon.top, MEDIA .. "hex-ring", HEX_EMPTY_RING)
      icon.top:ClearAllPoints(); icon.top:SetAllPoints(icon)
    end
  elseif style == "gems" then
    Layer(icon.base, MEDIA .. "gem-socket", { 1, 1, 1, 1 })
    if killed then
      Layer(icon.top, MEDIA .. "gem", color)
      icon.top:ClearAllPoints(); icon.top:SetAllPoints(icon)
      Layer(icon.shine, MEDIA .. "gem-shine", { 1, 1, 1, 0.9 })
      icon.shine:ClearAllPoints(); icon.shine:SetAllPoints(icon)
    end
  elseif style == "runes" or style == "futhark_latin" or style == "futhark" then
    local file
    if style ~= "runes" and letter and LETTERS[letter] then
      file = MEDIA .. (style == "futhark" and "futhark-" or "latin-") .. letter
    else
      file = MEDIA .. "rune-" .. (((slot or 1) - 1) % NUM_RUNES + 1)
    end
    Layer(icon.base, file, tint)
    if killed then
      Layer(icon.glow, MEDIA .. "glow", color, 0.55)
      Centered(icon.glow, icon, 1.7)
    end
  else
    Layer(icon.base, MEDIA .. "skull-lock", killed and color or SKULL_DIM)
  end
end
