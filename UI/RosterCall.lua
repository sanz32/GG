local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.RosterCall = {}
local RC = GG.RosterCall

RC.STYLES = { "band", "match", "ring", "card" }
RC.BEAT_SECONDS = 1.8
RC.SOUND_SECONDS = 30
RC.RETRY_SECONDS = 10
RC.TEST_END_SECONDS = 2
local DISMISS_SECONDS = 6 * 3600
local PULSE_SECONDS = RC.BEAT_SECONDS / 2

local SOUND_FILE = "Interface\\AddOns\\GG\\Media\\Sounds\\roster-call.ogg"
local RING = "Interface\\AddOns\\GG\\Media\\RosterCallRing.png"
local DISC = "Interface\\AddOns\\GG\\Media\\RosterCallDisc.png"
local GLOW = "Interface\\AddOns\\GG\\Media\\RosterCallGlow.png"
local WHITE = "Interface\\Buttons\\WHITE8x8"
RC.RING_TEXTURE, RC.DISC_TEXTURE = RING, DISC

local Theme
local frames = {}
local driver
local cur
local spentSound = {}

local function ShortLabel(label)
  return (label or ""):match("^(.-)%s+%-%s") or label or ""
end

local function ShortName(name)
  return (name or ""):match("^[^-]+") or name or ""
end

local function Colored(color, text)
  local function byte(v) return math.floor(v * 255 + 0.5) end
  return ("|cff%02x%02x%02x%s|r"):format(byte(color[1]), byte(color[2]), byte(color[3]), text)
end

local function ClassText(name, class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if not c then return name end
  return Colored({ c.r, c.g, c.b }, name)
end

local function LeaderClass(info)
  local leader = info.group.leader
  if info.leaderClassOf ~= leader then
    local rr = GG.RaidRosters
    local lookup = rr and rr.MemberLookup and rr:MemberLookup()
    local data = lookup and leader and lookup(leader)
    info.leaderClassOf, info.leaderClass = leader, data and data.class
  end
  return info.leaderClass
end

local function CountText(info) return Colored(Theme.success, info.count) end
local function RosterText(text) return Colored(Theme.teal, text) end
local function LeaderFull(info) return ClassText(info.group.leader or "", LeaderClass(info)) end
local function LeaderShort(info) return ClassText(ShortName(info.group.leader), LeaderClass(info)) end
local function MeText()
  local _, class = UnitClass("player")
  return ClassText(GG:GetCharacterKey() or "", class)
end

local function RosterKey(roster)
  return roster.label or ""
end

local function IsDismissed(key)
  local list = GGDB.rosterCallDismissed
  if not list then return false end
  local now = GetServerTime()
  for k, untilT in pairs(list) do
    if untilT <= now then list[k] = nil end
  end
  return list[key] ~= nil
end

local function Dismiss(key)
  GGDB.rosterCallDismissed = GGDB.rosterCallDismissed or {}
  GGDB.rosterCallDismissed[key] = GetServerTime() + DISMISS_SECONDS
end

local function IsBusy()
  if InCombatLockdown and InCombatLockdown() then return true end
  if IsEncounterInProgress and IsEncounterInProgress() then return true end
  if IsInInstance and IsInInstance() then return true end
  return false
end

local function SoundEnabled()
  return GGDB.options.rosterCallSound ~= false
end

local handles = {}

local function StopLoop()
  if not cur then return end
  cur.sounding = false
  for i = #handles, 1, -1 do
    if StopSound then StopSound(handles[i], 150) end
    handles[i] = nil
  end
end

local function PlayBeat()
  if not PlaySoundFile then return end
  local _, handle = PlaySoundFile(SOUND_FILE, "Master")
  if handle then
    handles[#handles + 1] = handle
    if #handles > 2 then table.remove(handles, 1) end
  end
end

local function StartLoop(key)
  if cur.sounding or spentSound[key] or not SoundEnabled() then return end
  local now = GetTime()
  cur.sounding = true
  cur.soundStart = now
  cur.nextBeat = cur.t0 + math.ceil((now - cur.t0) / RC.BEAT_SECONDS - 0.001) * RC.BEAT_SECONDS
  if cur.frame.cooldown then cur.frame.cooldown:SetCooldown(now, RC.SOUND_SECONDS) end
end

local function CreateText(parent, size, color, bold, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size, "")
  fs:SetTextColor(unpack(color))
  fs:SetJustifyH(justify or "LEFT")
  return fs
end

local function Solid(parent, layer, color, alpha)
  local t = parent:CreateTexture(nil, layer or "ARTWORK")
  t:SetColorTexture(color[1], color[2], color[3], alpha or color[4] or 1)
  return t
end

local function Fade(tex, color, alpha, leftLit)
  tex:SetColorTexture(1, 1, 1, 1)
  if CreateColor then
    local clear, lit = CreateColor(color[1], color[2], color[3], 0), CreateColor(color[1], color[2], color[3], alpha)
    tex:SetGradient("HORIZONTAL", leftLit and lit or clear, leftLit and clear or lit)
  end
end

local function AskButton(parent, fontSize)
  local b = CreateFrame("Button", nil, parent)
  local s = Theme.success
  b.bg = Solid(b, "BACKGROUND", s, 1)
  b.bg:SetAllPoints()
  b.label = CreateText(b, fontSize, { 0.024, 0.137, 0.059, 1 }, true, "CENTER")
  b.label:SetPoint("CENTER")
  b.label:SetText(L["RC_ASK"])
  b:SetScript("OnEnter", function(self)
    if not self.blocked then self.bg:SetColorTexture(s[1] + 0.12, s[2] + 0.1, s[3] + 0.1, 1) end
  end)
  b:SetScript("OnLeave", function(self)
    if not self.blocked then self.bg:SetColorTexture(s[1], s[2], s[3], 1) end
  end)
  b:SetScript("OnClick", function() RC:Ask() end)
  return b
end

local function LaterButton(parent, text)
  local b = CreateFrame("Button", nil, parent)
  b.label = CreateText(b, 12, Theme.textFaint, false, "CENTER")
  b.label:SetPoint("CENTER")
  b.label:SetText(text or L["RC_LATER"])
  b:SetSize(math.max(24, b.label:GetStringWidth() + 12), 22)
  b:SetScript("OnEnter", function(self) self.label:SetTextColor(unpack(Theme.textPrimary)) end)
  b:SetScript("OnLeave", function(self) self.label:SetTextColor(unpack(Theme.textFaint)) end)
  b:SetScript("OnClick", function() RC:Later() end)
  return b
end

local function StatusPieces(f, width)
  f.status = CreateText(f, 13, Theme.textMuted)
  f.status:SetWidth(width)
  f.status:SetWordWrap(true)
  f.retry = GG.Widgets.CreateButton(f, L["RC_RETRY"], function() RC:Ask() end)
  f.retry:SetHeight(26)
  f.retry:SetWidth(f.retry.label:GetStringWidth() + 26)
  f.status:Hide()
  f.retry:Hide()
end

local function DrainBar(f)
  f.drainTrack = Solid(f, "ARTWORK", { 1, 1, 1 }, 0.08)
  f.drainTrack:SetHeight(4)
  f.drain = Solid(f, "OVERLAY", Theme.success, 1)
  f.drain:SetHeight(4)
  f.drain:SetPoint("LEFT", f.drainTrack, "LEFT", 0, 0)
end

local function PaintPips(f, count, total, width)
  f.pips = f.pips or {}
  local n = math.max(total, count)
  local gap = 3
  local w = math.max(2, (width - gap * (n - 1)) / n)
  for i = 1, math.max(n, #f.pips) do
    local p = f.pips[i]
    if i <= n then
      if not p then
        p = f:CreateTexture(nil, "ARTWORK")
        f.pips[i] = p
      end
      p:ClearAllPoints()
      p:SetPoint("TOPLEFT", f.pipsAnchor, "TOPLEFT", (i - 1) * (w + gap), 0)
      p:SetSize(w, 9)
      if i <= count then p:SetColorTexture(unpack(Theme.success)) else p:SetColorTexture(unpack(Theme.border)) end
      p:Show()
    elseif p then
      p:Hide()
    end
  end
end

local function GlowAround(f)
  local s = Theme.success
  local LAYERS, STEP = 7, 2
  local halo = CreateFrame("Frame", nil, f)
  halo:SetAllPoints()
  halo:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  halo:EnableMouse(false)
  for i = 1, LAYERS do
    local layer = CreateFrame("Frame", nil, halo, "BackdropTemplate")
    layer:SetPoint("TOPLEFT", halo, "TOPLEFT", -i * STEP, i * STEP)
    layer:SetPoint("BOTTOMRIGHT", halo, "BOTTOMRIGHT", i * STEP, -i * STEP)
    layer:SetBackdrop({ edgeFile = WHITE, edgeSize = STEP })
    layer:SetBackdropBorderColor(s[1], s[2], s[3], 0.55 * (1 - (i - 1) / LAYERS) ^ 2)
    layer:EnableMouse(false)
  end
  return halo
end

local function Bubble(parent)
  local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  GG.Widgets.ApplyPanel(b, { bg = Theme.background, corners = "all" })
  b:EnableMouse(false)
  return b
end

local function BaseFrame(name)
  local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:Hide()
  return f
end

local function SavedPos(style)
  local all = GGDB.options.rosterCallPos
  local p = type(all) == "table" and all[style]
  if type(p) == "table" and type(p.x) == "number" and type(p.y) == "number" then return p end
  return nil
end

local function SavePos(style, x, y)
  if type(GGDB.options.rosterCallPos) ~= "table" then GGDB.options.rosterCallPos = {} end
  GGDB.options.rosterCallPos[style] = { x = x, y = y }
end

local function ApplyPos(f, style, shake)
  local p = SavedPos(style)
  local x, y = p and p.x, p and p.y
  if not p then
    x = style == "card" and (UIParent:GetWidth() or 1536) / 2 - 200 or 0
    y = 120
  end
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", x + (shake or 0), y)
end

local function MakeDraggable(f, style, handle)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  handle:RegisterForDrag("LeftButton")
  handle:SetScript("OnDragStart", function()
    f.dragging = true
    f:StartMoving()
  end)
  handle:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    f:SetUserPlaced(false)
    f.dragging = false
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and ux then SavePos(style, cx - ux, cy - uy) end
    ApplyPos(f, style)
  end)
end

local function PlaceBand(f, top)
  f:ClearAllPoints()
  f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, top)
  f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0, top)
end

local function BandTop()
  local p = SavedPos("band")
  if p then return p.y end
  return -math.floor((UIParent:GetHeight() or 864) * 0.25)
end

local function CursorY()
  local _, y = GetCursorPosition()
  return (y or 0) / (UIParent:GetEffectiveScale() or 1)
end

local BUILD, PAINT = {}, {}

local BAND_HEIGHT = 124
function BUILD.band()
  local f = BaseFrame("GGRosterCallBand")
  local d = Theme.background
  f:SetHeight(BAND_HEIGHT)
  f:SetClipsChildren(true)
  f.left = f:CreateTexture(nil, "BACKGROUND")
  f.left:SetPoint("TOPLEFT")
  f.left:SetPoint("BOTTOMLEFT")
  Fade(f.left, d, 0.97, false)
  f.right = f:CreateTexture(nil, "BACKGROUND")
  f.right:SetPoint("TOPRIGHT")
  f.right:SetPoint("BOTTOMRIGHT")
  Fade(f.right, d, 0.97, true)
  f.mid = Solid(f, "BACKGROUND", d, 0.97)
  f.mid:SetPoint("TOPLEFT", f.left, "TOPRIGHT")
  f.mid:SetPoint("BOTTOMRIGHT", f.right, "BOTTOMLEFT")
  f.lines = {}
  for i, spec in ipairs({ { "TOP", false }, { "TOP", true }, { "BOTTOM", false }, { "BOTTOM", true } }) do
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetHeight(2)
    t:SetPoint(spec[1] .. (spec[2] and "RIGHT" or "LEFT"), f, spec[1] .. (spec[2] and "RIGHT" or "LEFT"), 0, 0)
    t:SetPoint(spec[1] .. (spec[2] and "LEFT" or "RIGHT"), f, spec[1], 0, 0)
    Fade(t, Theme.success, 1, spec[2])
    f.lines[i] = t
  end
  f.sweep = CreateFrame("Frame", nil, f)
  f.sweep:SetSize(240, BAND_HEIGHT)
  f.sweep:SetFrameLevel(f:GetFrameLevel() + 1)
  f.sweep:EnableMouse(false)
  f.sweepIn = f.sweep:CreateTexture(nil, "ARTWORK")
  f.sweepIn:SetPoint("TOPLEFT")
  f.sweepIn:SetPoint("BOTTOMRIGHT", f.sweep, "BOTTOM")
  Fade(f.sweepIn, Theme.success, 0.22, false)
  f.sweepOut = f.sweep:CreateTexture(nil, "ARTWORK")
  f.sweepOut:SetPoint("TOPLEFT", f.sweep, "TOP")
  f.sweepOut:SetPoint("BOTTOMRIGHT")
  Fade(f.sweepOut, Theme.success, 0.22, true)

  f.content = CreateFrame("Frame", nil, f)
  f.content:SetAllPoints()
  f.content:SetFrameLevel(f:GetFrameLevel() + 2)
  f.title = CreateText(f.content, 30, Theme.textPrimary, true)
  f.kicker = CreateText(f.content, 14, Theme.textFaint, true)
  f.kicker:SetPoint("BOTTOMLEFT", f.title, "TOPLEFT", 0, 5)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function()
    f.dragGrab = (UIParent:GetHeight() or 864) + BandTop() - CursorY()
  end)
  f:SetScript("OnDragStop", function()
    f.dragGrab = nil
    if f.dragTop then SavePos("band", 0, f.dragTop) end
    f.dragTop = nil
  end)
  f.ask = AskButton(f.content, 20)
  f.ask:SetSize(250, 58)
  StatusPieces(f.content, 250)
  f.status = f.content.status
  f.retry = f.content.retry
  f.retry:SetPoint("TOPLEFT", f.status, "BOTTOMLEFT", 0, -6)
  f.later = LaterButton(f.content)
  DrainBar(f.content)
  f.drain, f.drainTrack = f.content.drain, f.content.drainTrack
  f.drainTrack:SetPoint("BOTTOM", f, "BOTTOM", 0, 9)
  return f
end

function PAINT.band(f, info)
  local w = UIParent:GetWidth() or 1536
  if not f.dragTop then PlaceBand(f, BandTop()) end
  f.left:SetWidth(w * 0.16)
  f.right:SetWidth(w * 0.16)
  f.drainTrack:SetWidth(w * 0.5)
  f.kicker:SetText(L["RC_KICKER"]:format(RosterText(info.roster.label or "")))
  f.title:SetText(L["RC_TITLE_BAND"]:format(CountText(info), RosterText(ShortLabel(info.roster.label)), LeaderShort(info)))
  local laterWidth = f.later:GetWidth() or 60
  local fixed = 32 + 250 + 12 + laterWidth
  f.title:SetFont(Theme.fontBold, 30, "")
  if f.title:GetStringWidth() + fixed > w * 0.92 then f.title:SetFont(Theme.fontBold, 22, "") end
  local titleWidth = f.title:GetStringWidth()
  local left = -(titleWidth + fixed) / 2
  f.title:ClearAllPoints()
  f.title:SetPoint("LEFT", f, "CENTER", left, -8)
  local right = left + titleWidth + 32
  f.ask:ClearAllPoints()
  f.ask:SetPoint("LEFT", f, "CENTER", right, 0)
  f.status:ClearAllPoints()
  f.status:SetPoint("LEFT", f, "CENTER", right, f.retry:IsShown() and 16 or 0)
  f.later:ClearAllPoints()
  f.later:SetPoint("LEFT", f, "CENTER", right + 250 + 12, 0)
end

function BUILD.match()
  local f = BaseFrame("GGRosterCallMatch")
  f:SetSize(560, 242)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
  f:SetBackdropColor(unpack(Theme.background))
  f:SetBackdropBorderColor(unpack(Theme.success))
  MakeDraggable(f, "match", f)
  f.halo = GlowAround(f)
  f.kicker = CreateText(f, 14, Theme.textFaint, true)
  f.kicker:SetPoint("TOPLEFT", 26, -22)
  f.title = CreateText(f, 30, Theme.textPrimary, true)
  f.title:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -7)
  f.title:SetPoint("RIGHT", f, "RIGHT", -26, 0)
  f.sub = CreateText(f, 14, Theme.textMuted)
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -5)
  f.pipsAnchor = CreateFrame("Frame", nil, f)
  f.pipsAnchor:SetSize(508, 9)
  f.pipsAnchor:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -13)
  f.ask = AskButton(f, 24)
  f.ask:SetSize(508, 60)
  f.ask:SetPoint("TOPLEFT", f.pipsAnchor, "BOTTOMLEFT", 0, -16)
  StatusPieces(f, 390)
  f.status:SetPoint("LEFT", f.ask, "LEFT", 0, 0)
  f.retry:SetPoint("RIGHT", f.ask, "RIGHT", 0, 0)
  DrainBar(f)
  f.drainTrack:SetPoint("TOPLEFT", f.ask, "BOTTOMLEFT", 0, -4)
  f.drainTrack:SetWidth(508)
  f.hint = CreateText(f, 12, Theme.textFaint)
  f.hint:SetPoint("BOTTOMLEFT", 26, 12)
  f.later = LaterButton(f)
  f.later:SetPoint("BOTTOMRIGHT", -22, 8)
  return f
end

function PAINT.match(f, info)
  f.kicker:SetText(L["RC_KICKER"]:format(RosterText(info.roster.label or "")))
  f.title:SetText(L["RC_TITLE"]:format(CountText(info), RosterText(ShortLabel(info.roster.label))))
  f.sub:SetText(L["RC_LEADER_ON"]:format(LeaderFull(info), MeText()))
  f.hint:SetText(L["RC_HINT"]:format(LeaderShort(info)))
  PaintPips(f, info.count, #(info.roster.members or {}), 508)
end

local DISC_SIZE = 228
local GLOW_EXTRA = 70

local function LayoutRing(f)
  local fs = f.status:IsShown() and f.status or f.sub
  f.box:SetSize(math.min(fs:GetStringWidth(), 360) + 28, math.max(28, fs:GetStringHeight() + 14))
  f.later:ClearAllPoints()
  if f.retry:IsShown() then
    f.later:SetPoint("TOP", f.retry, "BOTTOM", 0, -6)
  else
    f.later:SetPoint("TOP", f.box, "BOTTOM", 0, -6)
  end
end

function BUILD.ring()
  local f = BaseFrame("GGRosterCallRing")
  f:SetSize(420, 320)
  f:EnableMouse(false)
  f.halo = f:CreateTexture(nil, "BACKGROUND")
  f.halo:SetTexture(GLOW)
  f.halo:SetVertexColor(Theme.success[1], Theme.success[2], Theme.success[3], 1)
  f.halo:SetSize(DISC_SIZE + GLOW_EXTRA, DISC_SIZE + GLOW_EXTRA)
  f.halo:SetPoint("TOP", f, "TOP", 0, GLOW_EXTRA / 2)
  f.disc = CreateFrame("Button", nil, f)
  f.disc:SetSize(DISC_SIZE, DISC_SIZE)
  f.disc:SetPoint("TOP")
  MakeDraggable(f, "ring", f.disc)
  f.discBg = f.disc:CreateTexture(nil, "BACKGROUND")
  f.discBg:SetTexture(DISC)
  f.discBg:SetAllPoints()
  f.discBg:SetVertexColor(Theme.background[1], Theme.background[2], Theme.background[3], 1)
  f.track = f.disc:CreateTexture(nil, "BORDER")
  f.track:SetTexture(RING)
  f.track:SetAllPoints()
  f.track:SetVertexColor(unpack(Theme.border))
  f.disc:SetScript("OnClick", function() if cur and cur.status == "alert" then RC:Ask() end end)
  f.disc:SetScript("OnEnter", function()
    if not (cur and cur.info.otherGroup) then f.discBg:SetVertexColor(0.11, 0.165, 0.141, 1) end
  end)
  f.disc:SetScript("OnLeave", function() f.discBg:SetVertexColor(Theme.background[1], Theme.background[2], Theme.background[3], 1) end)
  f.cooldown = CreateFrame("Cooldown", nil, f.disc, "CooldownFrameTemplate")
  f.cooldown:SetAllPoints()
  f.cooldown:SetSwipeTexture(RING)
  f.cooldown:SetSwipeColor(Theme.success[1], Theme.success[2], Theme.success[3], 1)
  f.cooldown:SetDrawEdge(false)
  f.cooldown:SetDrawBling(false)
  f.cooldown:SetHideCountdownNumbers(true)
  f.cooldown:EnableMouse(false)
  f.big = CreateText(f.disc, 54, Theme.textPrimary, true, "CENTER")
  f.big:SetPoint("CENTER", 0, 24)
  f.count = CreateText(f.disc, 13, Theme.textMuted, false, "CENTER")
  f.count:SetPoint("TOP", f.big, "BOTTOM", 0, -2)
  f.cta = CreateText(f.disc, 15, Theme.success, true, "CENTER")
  f.cta:SetPoint("TOP", f.count, "BOTTOM", 0, -7)
  f.cta:SetText(L["RC_ASK"])
  f.ask = f.cta
  f.box = Bubble(f)
  f.box:SetPoint("TOP", f.disc, "BOTTOM", 0, -12)
  f.sub = CreateText(f.box, 14, Theme.textMuted, false, "CENTER")
  f.sub:SetPoint("CENTER")
  StatusPieces(f.box, 360)
  f.status, f.retry = f.box.status, f.box.retry
  f.status:SetJustifyH("CENTER")
  f.status:SetPoint("CENTER")
  f.retry:SetPoint("TOP", f.box, "BOTTOM", 0, -6)
  f.laterBox = Bubble(f)
  f.later = LaterButton(f)
  f.later:SetSize(f.later.label:GetStringWidth() + 26, 26)
  f.later:SetFrameLevel(f.laterBox:GetFrameLevel() + 1)
  f.laterBox:SetAllPoints(f.later)
  return f
end

function PAINT.ring(f, info)
  f.big:SetText(RosterText(ShortLabel(info.roster.label)))
  f.count:SetText(L["RC_COUNT"]:format(CountText(info), #(info.roster.members or {})))
  f.sub:SetText(L["RC_LEADER"]:format(LeaderFull(info)))
  LayoutRing(f)
end

function BUILD.card()
  local f = BaseFrame("GGRosterCallCard")
  f:SetSize(348, 178)
  MakeDraggable(f, "card", f)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(unpack(Theme.background))
  f:SetBackdropBorderColor(unpack(Theme.border))
  f.stripe = Solid(f, "ARTWORK", Theme.success, 1)
  f.stripe:SetPoint("TOPLEFT")
  f.stripe:SetPoint("BOTTOMLEFT")
  f.stripe:SetWidth(4)
  f.later = LaterButton(f)
  f.later:SetPoint("TOPRIGHT", -8, -8)
  f.kicker = CreateText(f, 14, Theme.textFaint, true)
  f.kicker:SetPoint("TOPLEFT", 17, -14)
  f.title = CreateText(f, 20, Theme.textPrimary, true)
  f.title:SetPoint("TOPLEFT", f.kicker, "BOTTOMLEFT", 0, -5)
  f.title:SetPoint("RIGHT", f, "RIGHT", -14, 0)
  f.sub = CreateText(f, 13, Theme.textMuted)
  f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
  f.pipsAnchor = CreateFrame("Frame", nil, f)
  f.pipsAnchor:SetSize(316, 9)
  f.pipsAnchor:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -10)
  f.ask = AskButton(f, 15)
  f.ask:SetSize(316, 40)
  f.ask:SetPoint("TOPLEFT", f.pipsAnchor, "BOTTOMLEFT", 0, -11)
  StatusPieces(f, 210)
  f.status:SetPoint("LEFT", f.ask, "LEFT", 0, 0)
  f.retry:SetPoint("RIGHT", f.ask, "RIGHT", 0, 0)
  DrainBar(f)
  f.drainTrack:SetPoint("TOPLEFT", f.ask, "BOTTOMLEFT", 0, -4)
  f.drainTrack:SetWidth(316)
  return f
end

function PAINT.card(f, info)
  f.kicker:SetText(L["RC_KICKER"]:format(RosterText(ShortLabel(info.roster.label))))
  f.title:SetText(L["RC_TITLE_CARD"]:format(CountText(info), #(info.roster.members or {})))
  f.sub:SetText(L["RC_LEADER"]:format(LeaderFull(info)))
  PaintPips(f, info.count, #(info.roster.members or {}), 316)
end

local function FrameFor(style)
  if not BUILD[style] then style = "band" end
  if not frames[style] then
    Theme = GG.Theme
    frames[style] = BUILD[style]()
  end
  return frames[style], style
end

local function PaintAsk(f, blocked)
  local text = blocked and L["RC_OTHER_GROUP"] or L["RC_ASK"]
  if f.cooldown then
    f.cta:SetText(text)
    f.cta:SetTextColor(unpack(blocked and Theme.textMuted or Theme.success))
    f.disc:SetEnabled(not blocked)
    return
  end
  local b = f.ask
  b.blocked = blocked
  b:SetEnabled(not blocked)
  b.label:SetText(text)
  if blocked then
    b.bg:SetColorTexture(unpack(Theme.border))
    b.label:SetTextColor(unpack(Theme.textMuted))
  else
    b.bg:SetColorTexture(unpack(Theme.success))
    b.label:SetTextColor(0.024, 0.137, 0.059, 1)
  end
end

local function PaintStatus()
  local f = cur.frame
  local alert = cur.status == "alert"
  PaintAsk(f, cur.info.otherGroup == true)
  f.ask:SetShown(alert)
  if f.cta then f.cta:SetShown(alert) end
  if f.sub then f.sub:SetShown(alert or f.cooldown == nil) end
  f.status:SetShown(not alert)
  f.retry:SetShown(cur.status == "retry")
  if cur.status == "sent" then
    f.status:SetText(L["RC_SENT"]:format(LeaderShort(cur.info)))
  elseif cur.status == "retry" then
    f.status:SetText(L["RC_NO_INVITE"])
  end
  cur.layoutFrames = 3
end

local function Paint()
  PAINT[cur.style](cur.frame, cur.info)
  PaintStatus()
end

local function Close()
  if not cur then return end
  StopLoop()
  cur.frame:Hide()
  cur = nil
  if driver then driver:Hide() end
end

local function IsTest()
  return cur.test or cur.info.group.simulated == true
end

local function EndTest()
  local simulated = cur.info.group.simulated
  Close()
  if simulated then
    GG.RaidGroups:SimulateForming(nil)
    print("|cff8B5CF6GG|r " .. L["RG_TEST_OFF"])
  end
end

local function Open(info, key, test)
  local f, style = FrameFor(GGDB.options.rosterCallStyle or "band")
  if not driver then
    driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function() RC.Tick() end)
  end
  if cur then Close() end
  cur = { info = info, key = key, test = test, frame = f, style = style, status = "alert", t0 = GetTime(), layoutFrames = 3 }
  if style ~= "band" then ApplyPos(f, style) end
  Paint()
  f:SetAlpha(0)
  f:Show()
  driver:Show()
  if info.sounds then StartLoop(key) end
  if FlashClientIcon then FlashClientIcon() end
end

function RC.Tick()
  if not cur then return end
  local now = GetTime()
  local f = cur.frame
  local elapsed = now - cur.t0
  f:SetAlpha(math.min(1, elapsed / 0.2))

  if cur.layoutFrames > 0 then
    cur.layoutFrames = cur.layoutFrames - 1
    PAINT[cur.style](f, cur.info)
  end

  if cur.sounding then
    if now - cur.soundStart >= RC.SOUND_SECONDS then
      spentSound[cur.key] = true
      StopLoop()
    elseif now >= cur.nextBeat then
      PlayBeat()
      cur.nextBeat = cur.nextBeat + RC.BEAT_SECONDS
      if cur.nextBeat < now then
        cur.nextBeat = cur.t0 + math.ceil((now - cur.t0) / RC.BEAT_SECONDS) * RC.BEAT_SECONDS
      end
    end
  end

  if f.drain then
    local left = cur.sounding and 1 - (now - cur.soundStart) / RC.SOUND_SECONDS or 0
    local full = f.drainTrack:GetWidth() or 0
    f.drain:SetWidth(math.max(0.01, full * left))
    f.drain:SetShown(cur.sounding == true)
    f.drainTrack:SetShown(cur.sounding == true)
  end

  local pulse = math.exp(-(elapsed % PULSE_SECONDS) * 5)
  if f.sweep then
    local width = f:GetWidth() or 0
    f.sweep:ClearAllPoints()
    f.sweep:SetPoint("LEFT", f, "LEFT", -240 + (width + 240) * ((elapsed % RC.BEAT_SECONDS) / RC.BEAT_SECONDS), 0)
    for _, line in ipairs(f.lines) do line:SetAlpha(0.55 + 0.45 * pulse) end
  end
  if f.halo then f.halo:SetAlpha(0.45 + 0.55 * pulse) end
  if f.dragGrab then
    local height = UIParent:GetHeight() or 864
    f.dragTop = math.max(BAND_HEIGHT - height, math.min(0, CursorY() + f.dragGrab - height))
    PlaceBand(f, f.dragTop)
  end
  if f.stripe and not f.dragging then
    local shake = 0
    local since = elapsed % PULSE_SECONDS
    if cur.sounding and since < 0.25 then shake = math.sin(since * 50) * (1 - since / 0.25) * 6 end
    ApplyPos(f, cur.style, shake)
  end

  if cur.status == "sent" and IsTest() then
    if now - cur.sentAt >= RC.TEST_END_SECONDS then EndTest() end
    return
  end

  if cur.status == "sent" and now - cur.sentAt >= RC.RETRY_SECONDS then
    cur.status = "retry"
    PaintStatus()
  end
end

function RC:Ask()
  if not cur or cur.info.otherGroup then return end
  if not cur.test then
    if not GG.RaidGroups:RequestInvite(cur.info.group) then
      if GG.IsChatRestricted and GG:IsChatRestricted() then
        print("|cff8B5CF6GG|r " .. L["RG_CHAT_BLOCKED"])
      end
      return
    end
  end
  spentSound[cur.key] = true
  StopLoop()
  if cur.frame.cooldown then cur.frame.cooldown:Clear() end
  cur.status = "sent"
  cur.sentAt = GetTime()
  PaintStatus()
end

function RC:Later()
  if not cur then return end
  if IsTest() then return EndTest() end
  Dismiss(cur.key)
  Close()
end

function RC:Evaluate()
  if not (GGDB and GGDB.options) then return end
  if cur and cur.test then return end
  if GGDB.options.popupRosterCall == false then return Close() end
  local set = GG.RaidRosters and GG.RaidRosters:GetCurrentSet()
  local info = set and GG.RaidGroups.InviteCallFor(set.rosters, GG.RaidGroups:Groups(), GG:GetCharacterKey())
  if not info then
    spentSound = {}
    return Close()
  end
  if IsBusy() then return Close() end
  local key = RosterKey(info.roster)
  if not info.group.simulated and IsDismissed(key) then return Close() end
  if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME) then
    info.sounds = false
    info.otherGroup = true
  end
  if cur and cur.key == key then
    cur.info = info
    if info.otherGroup then cur.status = "alert" end
    Paint()
    if info.sounds and cur.status == "alert" then StartLoop(key) end
    return
  end
  Open(info, key)
end

function RC:Test()
  local set = GG.RaidRosters and GG.RaidRosters:GetCurrentSet()
  local roster = set and set.rosters and set.rosters[1]
  local members = roster and roster.members or {}
  local label = roster and roster.label or "M1 - Thursday 10.00 PM"
  local total = math.max(#members, 20)
  local info = {
    roster = { label = label, members = #members > 0 and members or nil },
    group = { leader = members[1] or "Leader-Ragnaros" },
    count = math.ceil(total * 0.6),
    sounds = true,
  }
  if not info.roster.members then
    info.roster.members = {}
    for i = 1, total do info.roster.members[i] = "x" end
  end
  local key = "__test"
  spentSound[key] = nil
  if cur then Close() end
  Open(info, key, true)
end

function RC:_State() return cur end
function RC:_Reset()
  Close()
  frames, spentSound = {}, {}
  driver = nil
end

if CreateFrame then
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  events:SetScript("OnEvent", function() RC:Evaluate() end)
end
