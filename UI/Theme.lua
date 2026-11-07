local ADDON_NAME, GG = ...
local LSM = LibStub("LibSharedMedia-3.0")

LSM:Register("font", "GG Sans", [[Interface\AddOns\GG\Fonts\Expressway.ttf]])
LSM:Register("font", "GG Sans Bold", [[Interface\AddOns\GG\Fonts\ExpresswayBold.ttf]])

local warmup = CreateFrame("Frame", nil, UIParent)
warmup:SetAlpha(0)
for _, fontName in ipairs({ "GG Sans", "GG Sans Bold" }) do
  local fs = warmup:CreateFontString(nil, "OVERLAY")
  fs:SetFont(LSM:Fetch("font", fontName), 12, "")
  fs:SetText("Warmup 0123456789 áéíóúñ")
end

GG.Theme = {
  iconCrop = { 0.08, 0.92, 0.08, 0.92 },

  background = { 0.078, 0.086, 0.109, 0.97 },
  panel      = { 0.110, 0.122, 0.153, 1 },
  border     = { 0.165, 0.180, 0.220, 1 },
  accent     = { 0.545, 0.361, 0.965, 1 },
  accentDeep = { 0.349, 0.153, 0.702, 1 },
  success    = { 0.365, 0.780, 0.490, 1 },
  danger     = { 1.000, 0.420, 0.420, 1 },
  textPrimary = { 0.910, 0.910, 0.933, 1 },
  textMuted   = { 0.780, 0.784, 0.800, 1 },
  font = LSM:Fetch("font", "GG Sans"),

  textFaint  = { 0.650, 0.658, 0.690, 1 },
  borderSoft = { 0.122, 0.149, 0.196, 1 },
  gold          = { 0.910, 0.722, 0.361, 1 },
  teal          = { 0.208, 0.816, 0.729, 1 },
  purple        = { 0.655, 0.545, 0.980, 1 },
  accentStrong  = { 1.000, 0.604, 0.361, 1 },
  rowAlt        = { 1, 1, 1, 0.014 },
  rowHover      = { 1, 1, 1, 0.035 },

  fontBold = LSM:Fetch("font", "GG Sans Bold"),

  gradientFrom = { 0.114, 0.098, 0.161, 0.97 },
  gradientTo   = { 0.078, 0.086, 0.109, 0.97 },

  cornerRadius = 6,

  media = {
    cornerMask    = [[Interface\AddOns\GG\Media\corner-mask.png]],
    glowSeparator = [[Interface\AddOns\GG\Media\glow-separator.png]],
    bannerTip     = [[Interface\AddOns\GG\Media\BannerTip128.tga]],
    bannerTail    = [[Interface\AddOns\GG\Media\BannerTail32.tga]],
    glowHalo      = [[Interface\AddOns\GG\Media\glow-halo.png]],
    logo          = [[Interface\AddOns\GG\Media\logo-watermark.png]],
    logoIcon      = [[Interface\AddOns\GG\Media\logo-icon.png]],
    logoMinimap   = [[Interface\AddOns\GG\Media\logo-minimap.png]],
    clock         = [[Interface\AddOns\GG\Media\Clock32.tga]],
    dot           = [[Interface\AddOns\GG\Media\Dot32.tga]],
  },
}

local Theme = GG.Theme

Theme.ready = { 0.655, 0.545, 0.980, 1 }
Theme.accentHi = { 0.655, 0.545, 0.980, 1 }
Theme.onAccent = { 1, 1, 1, 1 }

GG.ACCENT_DEFAULT = { 0.545, 0.361, 0.965 }

local function RgbToHsl(r, g, b)
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local h, s, l = 0, 0, (mx + mn) / 2
  if mx ~= mn then
    local d = mx - mn
    s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
    if mx == r then h = (g - b) / d + (g < b and 6 or 0)
    elseif mx == g then h = (b - r) / d + 2
    else h = (r - g) / d + 4 end
    h = h / 6
  end
  return h, s, l
end

local function HslToRgb(h, s, l)
  if s == 0 then return l, l, l end
  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q
  local function f(t)
    t = t % 1
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
  end
  return f(h + 1 / 3), f(h), f(h - 1 / 3)
end

local function Luminance(r, g, b)
  local function c(v) return v <= 0.03928 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4 end
  return 0.2126 * c(r) + 0.7152 * c(g) + 0.0722 * c(b)
end

local function SetRGB(t, r, g, b) t[1], t[2], t[3] = r, g, b end

local function ApplyAccent(r, g, b)
  local h, s, l = RgbToHsl(r, g, b)
  if l < 0.45 then l = 0.45 end
  if l > 0.9 then l = 0.9 end
  r, g, b = HslToRgb(h, s, l)
  SetRGB(Theme.accent, r, g, b)
  SetRGB(Theme.accentDeep, HslToRgb(h, s, math.max(0.2, l - 0.22)))
  SetRGB(Theme.accentHi, HslToRgb(h, s * 0.9, math.min(0.85, l + 0.1)))
  if Luminance(r, g, b) > 0.42 then
    SetRGB(Theme.onAccent, 0.08, 0.09, 0.11)
  else
    SetRGB(Theme.onAccent, 1, 1, 1)
  end
  local bg = Theme.gradientTo
  SetRGB(Theme.gradientFrom, bg[1] + (r - bg[1]) * 0.07, bg[2] + (g - bg[2]) * 0.07, bg[3] + (b - bg[3]) * 0.07)
end

function GG:DeriveAccent(r, g, b)
  local h, s, l = RgbToHsl(r, g, b)
  if l < 0.45 then l = 0.45 end
  if l > 0.9 then l = 0.9 end
  r, g, b = HslToRgb(h, s, l)
  local onAccent = Luminance(r, g, b) > 0.42 and { 0.08, 0.09, 0.11, 1 } or { 1, 1, 1, 1 }
  return { r, g, b, 1 }, onAccent
end

function GG:ResolveAccentRGB()
  local o = GGDB and GGDB.options
  if not o then return nil end
  if o.accentMode == "class" then
    local _, class = UnitClass("player")
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
  elseif o.accentMode == "custom" and type(o.accentColor) == "table" then
    return o.accentColor[1], o.accentColor[2], o.accentColor[3]
  end
  return nil
end

function GG:AccentSignature()
  local r, g, b = self:ResolveAccentRGB()
  if not r then return "default" end
  return ("%.3f,%.3f,%.3f"):format(r, g, b)
end

function GG:ApplyStoredAccent()
  local r, g, b = self:ResolveAccentRGB()
  if r then ApplyAccent(r, g, b) end
  self.appliedAccentSignature = self:AccentSignature()
end
