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
local WEEK_SECONDS = 7 * 86400
RC.GONE_SECONDS = 90
RC.ARRIVE_SECONDS = 1.1
local PILL_HEIGHT = 46
local PILL_ACTION_W, PILL_ACTION_H = 158, 34
local PILL_GLOW_REACH = 12
RC.COMET_SECONDS = 3.6
local PILL_COMET_PIECES, PILL_COMET_STEP = 8, 0.011
local PillLight
local PILL_GAP = 24
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
local function OtherShort(name)
  local rr = GG.RaidRosters
  local lookup = rr and rr.MemberLookup and rr:MemberLookup()
  local data = lookup and name and lookup(name)
  return ClassText(ShortName(name), data and data.class)
end
local function MeText()
  local _, class = UnitClass("player")
  return ClassText(GG:GetCharacterKey() or "", class)
end
local function HintText(info)
  local path, inviter = "whisper", nil
  if GG.RaidInvites and info.group.leaderKey then path, inviter = GG.RaidInvites:PlanFor(info.group) end
  if path == "gg" then return L["RC_HINT_GG"]:format(OtherShort(inviter)) end
  return L["RC_HINT"]:format(LeaderShort(info))
end
local function ShowAskTip(owner)
  if not (cur and GameTooltip) or cur.test or cur.info.otherGroup then return end
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  GameTooltip:SetText(HintText(cur.info), 1, 1, 1, 1, true)
  GameTooltip:Show()
end
local function HideAskTip(owner)
  if GameTooltip and GameTooltip:GetOwner() == owner then GameTooltip:Hide() end
end

local function RosterKey(roster)
  return roster.label or ""
end

local function Marked(field, key)
  local list = GGDB[field]
  if type(list) ~= "table" then return false end
  local now = GetServerTime()
  for k, untilT in pairs(list) do
    if type(untilT) ~= "number" or untilT <= now then list[k] = nil end
  end
  return list[key] ~= nil
end

local function Mark(field, key, untilT)
  if type(GGDB[field]) ~= "table" then GGDB[field] = {} end
  GGDB[field][key] = untilT
end

local function Unmark(field, key)
  if type(GGDB[field]) == "table" then GGDB[field][key] = nil end
end

local live = {}
local goneAt = {}

local function ForgetGone(current)
  local now = GetTime()
  for key in pairs(live) do
    if key ~= current and not goneAt[key] then goneAt[key] = now end
  end
  for key, at in pairs(goneAt) do
    if now - at >= RC.GONE_SECONDS then
      live[key], goneAt[key] = nil, nil
      Unmark("rosterCallPill", key)
      Unmark("rosterCallDismissed", key)
    end
  end
  if current then live[current], goneAt[current] = true, nil end
end

local function PillEnabled()
  return GGDB.options.rosterCallPill ~= false
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

local MEDIA = "Interface\\AddOns\\GG\\Media\\"

local function Sliced(parent, layer, sublayer, file, margin)
  local t = GG.Widgets.NewRoundTexture(parent, layer, sublayer)
  t:SetTexture(MEDIA .. file)
  if t.SetTextureSliceMargins then
    t:SetTextureSliceMargins(margin, margin, margin, margin)
    local mode = Enum and Enum.UITextureSliceMode and Enum.UITextureSliceMode.Stretched
    if mode and t.SetTextureSliceMode then t:SetTextureSliceMode(mode) end
  end
  return t
end

local function Capsule(parent, sublayer, r, ring)
  local c = {}
  c.fill = Sliced(parent, "BACKGROUND", sublayer, "PillFill" .. r .. ".tga", r)
  c.fill:SetAllPoints(parent)
  if ring then
    c.ring = Sliced(parent, "BACKGROUND", sublayer + 1, "PillRing" .. r .. ".tga", r)
    c.ring:SetAllPoints(parent)
  end
  function c:SetColor(red, g, b, a) self.fill:SetVertexColor(red, g, b, a or 1) end
  function c:SetRingColor(red, g, b, a) if self.ring then self.ring:SetVertexColor(red, g, b, a or 1) end end
  return c
end

local INK = { 0.024, 0.137, 0.059, 1 }

local function AskButton(parent, fontSize, pill)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  local s = Theme.success
  if pill then
    b.capsule = Capsule(b, -6, PILL_ACTION_H / 2)
    function b:SetFill(r, g, bl, a) self.capsule:SetColor(r, g, bl, a) end
  else
    GG.Widgets.Backdrop(b, s, nil, 8)
    function b:SetFill(r, g, bl, a) self:SetBackdropColor(r, g, bl, a) end
  end
  b:SetFill(s[1], s[2], s[3], 1)
  b.label = CreateText(b, fontSize, INK, true, "CENTER")
  b.label:SetPoint("CENTER")
  b.label:SetText(L["RC_ASK"])
  b:SetScript("OnEnter", function(self)
    if not self.blocked then self:SetFill(s[1] + 0.12, s[2] + 0.1, s[3] + 0.1, 1) end
    ShowAskTip(self)
  end)
  b:SetScript("OnLeave", function(self)
    if not self.blocked then self:SetFill(s[1], s[2], s[3], 1) end
    HideAskTip(self)
  end)
  b:SetScript("OnClick", function() RC:Ask() end)
  return b
end

local LATER_BG = { 0.227, 0.106, 0.125, 1 }
local LATER_BORDER = { 0.663, 0.267, 0.286, 1 }
local LATER_HOVER_BG = { 0.353, 0.145, 0.169, 1 }
local LATER_HOVER_TEXT = { 1, 0.816, 0.816, 1 }

local function LaterButton(parent, height, fontSize, minWidth, radius)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  GG.Widgets.Backdrop(b, LATER_BG, LATER_BORDER, radius or 8)
  b.label = CreateText(b, fontSize or 13, Theme.danger, true, "CENTER")
  b.label:SetPoint("CENTER")
  b.label:SetText(L["RC_LATER"])
  b.padW, b.minW = 28, minWidth or 0
  b:SetSize(math.max(b.minW, b.label:GetStringWidth() + b.padW), height)
  b:SetScript("OnEnter", function(self)
    self:SetBackdropColor(unpack(LATER_HOVER_BG))
    self:SetBackdropBorderColor(unpack(Theme.danger))
    self.label:SetTextColor(unpack(LATER_HOVER_TEXT))
  end)
  b:SetScript("OnLeave", function(self)
    self:SetBackdropColor(unpack(LATER_BG))
    self:SetBackdropBorderColor(unpack(LATER_BORDER))
    self.label:SetTextColor(unpack(Theme.danger))
  end)
  b:SetScript("OnClick", function() RC:Later() end)
  return b
end

local function FitLater(b)
  local w = b.label:GetStringWidth() or 0
  if w > 0 then b:SetWidth(math.max(b.minW or 0, w + b.padW)) end
end

local function RoundBar(parent, layer, r, color, alpha)
  local t = GG.Widgets.NewRoundTexture(parent, layer)
  GG.Widgets.ApplyRound(t, "RoundFill", r)
  t:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
  return t
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
  f.drainTrack = RoundBar(f, "ARTWORK", 2, { 1, 1, 1 }, 0.08)
  f.drainTrack:SetHeight(4)
  f.drain = RoundBar(f, "OVERLAY", 2, Theme.success, 1)
  f.drain:SetHeight(4)
  f.drain:SetPoint("LEFT", f.drainTrack, "LEFT", 0, 0)
end

local function PaintPips(f, count, total, width, height, gap)
  f.pips = f.pips or {}
  local n = math.max(total, count)
  height, gap = height or 9, gap or 3
  local w = math.max(1, (width - gap * (n - 1)) / n)
  for i = 1, math.max(n, #f.pips) do
    local p = f.pips[i]
    if i <= n then
      if not p then
        p = RoundBar(f, "ARTWORK", height >= 8 and 3 or 2, Theme.border)
        f.pips[i] = p
      end
      p:ClearAllPoints()
      p:SetPoint("TOPLEFT", f.pipsAnchor, "TOPLEFT", (i - 1) * (w + gap), 0)
      p:SetSize(w, height)
      p:SetVertexColor(unpack(i <= count and Theme.success or Theme.border))
      p:Show()
    elseif p then
      p:Hide()
    end
  end
end

local GLOW_REACH = 14
local function GlowAround(f)
  local s = Theme.success
  local halo = CreateFrame("Frame", nil, f)
  halo:SetAllPoints()
  halo:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  halo:EnableMouse(false)
  local t = Sliced(halo, "BACKGROUND", 0, "CallGlow10.tga", 10 + GLOW_REACH)
  t:SetPoint("TOPLEFT", halo, "TOPLEFT", -GLOW_REACH, GLOW_REACH)
  t:SetPoint("BOTTOMRIGHT", halo, "BOTTOMRIGHT", GLOW_REACH, -GLOW_REACH)
  t:SetVertexColor(s[1], s[2], s[3], 1)
  return halo
end

local function Bubble(parent)
  local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  GG.Widgets.ApplyPanel(b, { bg = Theme.background, corners = "all" })
  b:EnableMouse(false)
  return b
end

local function WindowShadow(f, shadowOnly)
  if not (GG.Widgets.ApplyWindowChrome and Theme.media) then return end
  local chrome = GG.Widgets.ApplyWindowChrome(f)
  f.chrome = chrome
  if shadowOnly then
    for _, t in ipairs(chrome.ring) do t:Hide() end
    for _, t in pairs(chrome.glow) do t:Hide() end
    chrome.lightL:Hide()
    chrome.lightR:Hide()
  end
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
  f.later = LaterButton(f.content, 44, 15, 112)
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
  FitLater(f.later)
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
  f:SetSize(560, 252)
  local bg = Theme.background
  GG.Widgets.Backdrop(f, { bg[1], bg[2], bg[3], 1 }, Theme.success, 10, 2)
  WindowShadow(f, true)
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
  f.hint:SetPoint("BOTTOMLEFT", 26, 19)
  f.later = LaterButton(f, 30, 13, 96)
  f.later:SetPoint("BOTTOMRIGHT", -22, 10)
  return f
end

function PAINT.match(f, info)
  FitLater(f.later)
  f.kicker:SetText(L["RC_KICKER"]:format(RosterText(info.roster.label or "")))
  f.title:SetText(L["RC_TITLE"]:format(CountText(info), RosterText(ShortLabel(info.roster.label))))
  f.sub:SetText(L["RC_LEADER_ON"]:format(LeaderFull(info), MeText()))
  f.hint:SetText(HintText(info))
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
  f.disc:SetScript("OnEnter", function(self)
    if not (cur and cur.info.otherGroup) then f.discBg:SetVertexColor(0.11, 0.165, 0.141, 1) end
    if cur and cur.status == "alert" then ShowAskTip(self) end
  end)
  f.disc:SetScript("OnLeave", function(self)
    f.discBg:SetVertexColor(Theme.background[1], Theme.background[2], Theme.background[3], 1)
    HideAskTip(self)
  end)
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
  f.later = LaterButton(f, 32, 13, 108, 10)
  return f
end

function PAINT.ring(f, info)
  FitLater(f.later)
  f.big:SetText(RosterText(ShortLabel(info.roster.label)))
  f.count:SetText(L["RC_COUNT"]:format(CountText(info), #(info.roster.members or {})))
  f.sub:SetText(L["RC_LEADER"]:format(LeaderFull(info)))
  LayoutRing(f)
end

function BUILD.card()
  local f = BaseFrame("GGRosterCallCard")
  f:SetSize(348, 178)
  MakeDraggable(f, "card", f)
  local bg = Theme.background
  GG.Widgets.Backdrop(f, { bg[1], bg[2], bg[3], 1 }, Theme.border, 10, 1)
  WindowShadow(f, false)
  f.stripe = RoundBar(f, "ARTWORK", 2, Theme.success, 1)
  f.stripe:SetPoint("TOPLEFT", 1, -10)
  f.stripe:SetPoint("BOTTOMLEFT", 1, 10)
  f.stripe:SetWidth(4)
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
  f.later = LaterButton(f, 40, 13, 92)
  f.later:SetPoint("LEFT", f.ask, "RIGHT", 8, 0)
  StatusPieces(f, 210)
  f.status:SetPoint("LEFT", f.ask, "LEFT", 0, 0)
  f.retry:SetPoint("RIGHT", f.ask, "RIGHT", 0, 0)
  DrainBar(f)
  f.drainTrack:SetPoint("TOPLEFT", f.ask, "BOTTOMLEFT", 0, -4)
  f.drainTrack:SetWidth(316)
  return f
end

function PAINT.card(f, info)
  FitLater(f.later)
  f.ask:SetWidth(316 - 8 - (f.later:GetWidth() or 92))
  f.kicker:SetText(L["RC_KICKER"]:format(RosterText(ShortLabel(info.roster.label))))
  f.title:SetText(L["RC_TITLE_CARD"]:format(CountText(info), #(info.roster.members or {})))
  f.sub:SetText(L["RC_LEADER"]:format(LeaderFull(info)))
  PaintPips(f, info.count, #(info.roster.members or {}), 316)
end

local function PlacePill(f)
  f:ClearAllPoints()
  local p = SavedPos("pill")
  if p then
    f:SetPoint("CENTER", UIParent, "CENTER", p.x, p.y)
    return
  end
  local mm = Minimap
  if mm and mm.IsVisible and mm:IsVisible() and mm.GetRect then
    local l, b, w, h = mm:GetRect()
    local ui = UIParent:GetEffectiveScale() or 1
    if l and b and w and h and w > 0 and ui > 0 then
      local k = (mm:GetEffectiveScale() or ui) / ui
      local cx, bottom, top = (l + w / 2) * k, b * k, (b + h) * k
      local sw, sh = UIParent:GetWidth() or 0, UIParent:GetHeight() or 0
      if cx > 0 and cx < sw and top > 0 and bottom < sh then
        local half = (f:GetWidth() or 0) / 2
        if half > 0 then cx = math.max(half + 8, math.min(sw - half - 8, cx)) end
        if (top + bottom) / 2 >= sh / 2 then
          f:SetPoint("TOP", UIParent, "BOTTOMLEFT", cx, bottom - PILL_GAP)
        else
          f:SetPoint("BOTTOM", UIParent, "BOTTOMLEFT", cx, top + PILL_GAP)
        end
        return
      end
    end
  end
  f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -250)
end

local function ShowPillTip(f)
  if not (cur and GameTooltip) then return end
  GameTooltip:SetOwner(f, "ANCHOR_BOTTOM")
  GameTooltip:SetText(L["RC_KICKER"]:format(RosterText(cur.info.roster.label or "")), 1, 1, 1, 1, true)
  if not cur.info.otherGroup and not cur.test then GameTooltip:AddLine(HintText(cur.info), 1, 1, 1, true) end
  if cur.status ~= "alert" and cur.textLong then GameTooltip:AddLine(cur.textLong, 0.78, 0.78, 0.8, true) end
  GameTooltip:AddLine(L["RC_PILL_TIP_MOVE"], 0.65, 0.66, 0.69, true)
  GameTooltip:Show()
end

function BUILD.pill()
  local f = BaseFrame("GGRosterCallPill")
  f:SetFrameStrata("HIGH")
  f:SetHeight(PILL_HEIGHT)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function()
    f.dragging = true
    f:StartMoving()
  end)
  f:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    f:SetUserPlaced(false)
    f.dragging = false
    local cx, cy = f:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and ux then SavePos("pill", cx - ux, cy - uy) end
    PlacePill(f)
  end)
  f:SetScript("OnMouseUp", function(_, button)
    if button ~= "RightButton" then return end
    if type(GGDB.options.rosterCallPos) == "table" then GGDB.options.rosterCallPos.pill = nil end
    PlacePill(f)
  end)
  f:SetScript("OnEnter", ShowPillTip)
  f:SetScript("OnLeave", function(self) if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
  local reach = PILL_GLOW_REACH
  f.shadow = Sliced(f, "BACKGROUND", -8, "PillGlow23.tga", 23 + reach)
  f.shadow:SetPoint("TOPLEFT", -reach, reach - 3)
  f.shadow:SetPoint("BOTTOMRIGHT", reach, -reach - 3)
  f.shadow:SetVertexColor(0, 0, 0, 0.55)
  f.aura = Sliced(f, "BACKGROUND", -7, "PillGlow23.tga", 23 + reach)
  f.aura:SetPoint("TOPLEFT", -reach, reach)
  f.aura:SetPoint("BOTTOMRIGHT", reach, -reach)
  f.aura:SetBlendMode("ADD")
  f.body = Capsule(f, -6, PILL_HEIGHT / 2, true)
  f.body:SetColor(Theme.background[1], Theme.background[2], Theme.background[3], 1)
  f.comet = {}
  for i = 1, PILL_COMET_PIECES do
    local t = f:CreateTexture(nil, "OVERLAY")
    t:SetTexture(MEDIA .. "PillSpark.tga")
    t:SetBlendMode("ADD")
    local k = (i - 1) / PILL_COMET_PIECES
    t:SetSize(18 - 8 * k, 18 - 8 * k)
    t.alpha = 0.95 * (1 - k) ^ 1.6
    f.comet[i] = t
  end

  for col = 0, 1 do
    for row = -1, 1 do
      local d = Solid(f, "ARTWORK", Theme.textFaint, 0.45)
      d:SetSize(2, 2)
      d:SetPoint("CENTER", f, "LEFT", 13 + col * 3, row * 4)
    end
  end
  f.dot = RoundBar(f, "ARTWORK", 4, Theme.success)
  f.dot:SetSize(8, 8)
  f.dot:SetPoint("CENTER", f, "LEFT", 28, 0)
  f.name = CreateText(f, 13, Theme.teal, true)
  f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -11)
  f.count = CreateText(f, 13, Theme.textMuted)
  f.count:SetPoint("LEFT", f.name, "RIGHT", 6, 0)
  f.pipsAnchor = CreateFrame("Frame", nil, f)
  f.pipsAnchor:SetSize(78, 4)
  f.pipsAnchor:SetPoint("TOPLEFT", f, "TOPLEFT", 40, -31)

  f.act = CreateFrame("Frame", nil, f)
  f.act:SetSize(PILL_ACTION_W, PILL_ACTION_H)
  f.ask = AskButton(f.act, 12, true)
  f.ask:SetAllPoints()
  f.statusBox = CreateFrame("Frame", nil, f.act)
  f.statusBox:SetAllPoints()
  f.statusCapsule = Capsule(f.statusBox, -6, PILL_ACTION_H / 2, true)
  f.statusCapsule:SetColor(0.106, 0.125, 0.157, 1)
  f.statusCapsule:SetRingColor(0.184, 0.212, 0.263, 1)
  f.status = CreateText(f.statusBox, 12, Theme.textMuted, false, "CENTER")
  f.status:SetWordWrap(false)
  f.retry = GG.Widgets.CreateButton(f.statusBox, L["RC_RETRY"], function() RC:Ask() end)
  f.retry:SetHeight(22)
  f.retry:SetPoint("RIGHT", f.statusBox, "RIGHT", -6, 0)
  f.statusBox:Hide()
  function f:paintStatus(alert)
    self.statusBox:SetShown(not alert)
    self.status:ClearAllPoints()
    if self.retry:IsShown() then
      self.retry:SetWidth(self.retry.label:GetStringWidth() + 18)
      self.status:SetPoint("LEFT", self.statusBox, "LEFT", 12, 0)
      self.status:SetPoint("RIGHT", self.retry, "LEFT", -6, 0)
      self.status:SetJustifyH("LEFT")
    else
      self.status:SetPoint("LEFT", self.statusBox, "LEFT", 12, 0)
      self.status:SetPoint("RIGHT", self.statusBox, "RIGHT", -12, 0)
      self.status:SetJustifyH("CENTER")
    end
  end

  f.later = CreateFrame("Button", nil, f)
  f.later:SetSize(26, 26)
  f.later.hover = Sliced(f.later, "BACKGROUND", 0, "PillFill13.tga", 13)
  f.later.hover:SetAllPoints()
  f.later.hover:SetVertexColor(Theme.danger[1], Theme.danger[2], Theme.danger[3], 0.16)
  f.later.hover:Hide()
  f.later.label = CreateText(f.later, 14, Theme.textFaint, true, "CENTER")
  f.later.label:SetPoint("CENTER", 0, 1)
  f.later.label:SetText("x")
  f.later:SetScript("OnEnter", function(self)
    self.hover:Show()
    self.label:SetTextColor(unpack(Theme.danger))
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(L["RC_PILL_CLOSE"], 1, 1, 1, 1, true)
      GameTooltip:Show()
    end
  end)
  f.later:SetScript("OnLeave", function(self)
    self.hover:Hide()
    self.label:SetTextColor(unpack(Theme.textFaint))
    if GameTooltip and GameTooltip:GetOwner() == self then GameTooltip:Hide() end
  end)
  f.later:SetScript("OnClick", function() RC:Later() end)
  return f
end

function PAINT.pill(f, info)
  local edge, dot = { 0.184, 0.353, 0.239, 1 }, Theme.success
  if cur and cur.mode == "regroup" then
    edge, dot = Theme.teal, Theme.teal
  end
  if info.otherGroup then
    edge, dot = { 0.208, 0.239, 0.290, 1 }, { 0.42, 0.44, 0.5, 1 }
  elseif cur and cur.status ~= "alert" then
    edge, dot = { 0.235, 0.271, 0.329, 1 }, { 0.91, 0.72, 0.29, 1 }
  end
  f.body:SetRingColor(edge[1], edge[2], edge[3], 1)
  f.dot:SetVertexColor(dot[1], dot[2], dot[3], 1)
  f.light = dot
  f.aura:SetVertexColor(dot[1], dot[2], dot[3], 1)
  for _, t in ipairs(f.comet) do t:SetVertexColor(dot[1], dot[2], dot[3], 1) end

  local total = #(info.roster.members or {})
  f.name:SetText(ShortLabel(info.roster.label))
  f.count:SetText(CountText(info) .. "/" .. total)
  PaintPips(f, info.count, total, 78, 4, 1.5)
  f.ask.label:SetFont(Theme.fontBold, 12, "")
  if (f.ask.label:GetStringWidth() or 0) > PILL_ACTION_W - 14 then f.ask.label:SetFont(Theme.fontBold, 11, "") end

  local infoW = math.max(78, (f.name:GetStringWidth() or 0) + 6 + (f.count:GetStringWidth() or 0))
  local actX = 40 + infoW + 12
  f.act:ClearAllPoints()
  f.act:SetPoint("LEFT", f, "LEFT", actX, 0)
  f.later:ClearAllPoints()
  f.later:SetPoint("LEFT", f.act, "RIGHT", 6, 0)
  f:SetWidth(actX + PILL_ACTION_W + 6 + 26 + 8)
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
    b:SetFill(unpack(Theme.border))
    b.label:SetTextColor(unpack(Theme.textMuted))
  else
    b:SetFill(unpack(Theme.success))
    b.label:SetTextColor(unpack(INK))
  end
end

local SHORT = {
  RC_SENT = "RC_P_WAITING", RC_SENT_GG = "RC_P_WAITING", RC_INVITING = "RC_P_INVITING",
  RC_QUEUED = "RC_P_QUEUED", RC_INVITED = "RC_P_INVITED", RC_NO_INVITE = "RC_P_NO_INVITE",
  RC_NO_ANSWER = "RC_P_NO_ANSWER", RC_FULL = "RC_P_FULL", RC_GONE = "RC_P_GONE",
}

local function PaintStatus()
  local f = cur.frame
  local alert = cur.status == "alert"
  PaintAsk(f, cur.info.otherGroup == true)
  f.ask:SetShown(alert)
  if f.cta then f.cta:SetShown(alert) end
  if f.sub then f.sub:SetShown(alert or f.cooldown == nil) end
  f.status:SetShown(not alert)
  f.retry:SetShown(cur.status == "retry")
  if not alert then
    local key = cur.textKey or (cur.status == "retry" and "RC_NO_INVITE" or "RC_SENT")
    local who = cur.textWho == "inviter" and cur.req and OtherShort(cur.req.inviter) or LeaderShort(cur.info)
    cur.textLong = L[key]:format(who)
    f.status:SetText(f.paintStatus and L[SHORT[key] or key]:format(who) or cur.textLong)
  end
  if f.paintStatus then f:paintStatus(alert) end
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

local function Open(info, key, test, mode, carry)
  mode = mode or "full"
  local style = mode == "full" and (GGDB.options.rosterCallStyle or "band") or "pill"
  if mode == "full" and style == "pill" then style = "band" end
  local f
  f, style = FrameFor(style)
  if not driver then
    driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function() RC.Tick() end)
  end
  if cur then Close() end
  cur = { info = info, key = key, test = test, frame = f, style = style, mode = mode, status = "alert", t0 = GetTime(), layoutFrames = 3 }
  if carry and carry.status ~= "alert" then
    cur.status, cur.sentAt, cur.req, cur.path = carry.status, carry.sentAt, carry.req, carry.path
    cur.textKey, cur.textWho = carry.textKey, carry.textWho
  end
  if style == "pill" then
    info.sounds = false
  elseif style ~= "band" then
    ApplyPos(f, style)
  end
  Paint()
  if style == "pill" then PlacePill(f) end
  f:SetAlpha(0)
  f:Show()
  driver:Show()
  if mode ~= "full" then return end
  if info.sounds then StartLoop(key) end
  if FlashClientIcon then FlashClientIcon() end
end

local function Shrink()
  local old = cur
  StopLoop()
  old.frame:Hide()
  cur = nil
  Open(old.info, old.key, old.test, "pill", old)
end

function RC.PillPoint(w, h, u)
  local r = h / 2
  local straight = math.max(0, w - 2 * r)
  local arc = math.pi * r
  local s = (u % 1) * (2 * straight + 2 * arc)
  if s < straight then return r + s, h end
  s = s - straight
  if s < arc then
    local a = math.pi / 2 - s / r
    return w - r + r * math.cos(a), r + r * math.sin(a)
  end
  s = s - arc
  if s < straight then return w - r - s, 0 end
  s = s - straight
  local a = -math.pi / 2 - s / r
  return r + r * math.cos(a), r + r * math.sin(a)
end

function PillLight(f, now, elapsed)
  local on = not cur.info.otherGroup
  local w = f:GetWidth() or 0
  local lap = (now - cur.t0) / RC.COMET_SECONDS
  for i, t in ipairs(f.comet) do
    if on and w > 0 then
      local x, y = RC.PillPoint(w, PILL_HEIGHT, lap - (i - 1) * PILL_COMET_STEP)
      t:ClearAllPoints()
      t:SetPoint("CENTER", f, "BOTTOMLEFT", x, y)
      t:SetAlpha(t.alpha)
      t:Show()
    else
      t:Hide()
    end
  end
  local alpha = 0
  if on then
    alpha = 0.22 + 0.1 * math.sin(elapsed * 2 * math.pi / 3)
    local reps = cur.mode == "regroup" and 3 or 1
    local t = elapsed - 0.2
    if t >= 0 and t < reps * RC.ARRIVE_SECONDS then
      local p = (t % RC.ARRIVE_SECONDS) / RC.ARRIVE_SECONDS
      alpha = alpha + 0.7 * (1 - p) ^ 2
    end
  end
  f.aura:SetAlpha(math.min(1, alpha))
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
  if f.comet then PillLight(f, now, elapsed) end
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

  if cur.status == "sent" and cur.test then
    if now - cur.sentAt >= RC.TEST_END_SECONDS then EndTest() end
    return
  end

  if cur.status ~= "alert" and cur.sentAt then
    local RI = GG.RaidInvites
    local req = cur.req
    if req and RI then RI:State() end
    local status, key, who = "sent", nil, nil
    if RI then
      status, key, who = RI.CallView(cur.path, req and req.phase, now - cur.sentAt,
        now - ((req and req.phaseAt) or cur.sentAt), RC.RETRY_SECONDS)
    elseif now - cur.sentAt >= RC.RETRY_SECONDS then
      status = "retry"
    end
    if status ~= cur.status or key ~= cur.textKey then
      cur.status, cur.textKey, cur.textWho = status, key, who
      if status == "alert" then cur.sentAt, cur.req = nil, nil end
      PaintStatus()
    end
  end
end

function RC:Ask()
  if not cur or cur.info.otherGroup then return end
  local path = "test"
  if not cur.test then
    path = GG.RaidGroups:RequestInvite(cur.info.group)
    if not path then
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
  cur.path = path
  cur.req = GG.RaidInvites and GG.RaidInvites:State() or nil
  cur.textKey, cur.textWho = path == "gg" and "RC_SENT_GG" or nil, path == "gg" and "inviter" or nil
  PaintStatus()
end

function RC:Later()
  if not cur then return end
  if cur.mode ~= "full" then
    if IsTest() then return EndTest() end
    Mark("rosterCallDismissed", cur.key, GetServerTime() + DISMISS_SECONDS)
    return Close()
  end
  if not PillEnabled() then
    if IsTest() then return EndTest() end
    Mark("rosterCallDismissed", cur.key, GetServerTime() + DISMISS_SECONDS)
    return Close()
  end
  if not IsTest() then Mark("rosterCallPill", cur.key, GetServerTime() + DISMISS_SECONDS) end
  Shrink()
end

function RC:Evaluate()
  if not (GGDB and GGDB.options) then return end
  if cur and cur.test then return end
  if GGDB.options.popupRosterCall == false then return Close() end
  local set = GG.RaidRosters and GG.RaidRosters:GetCurrentSet()
  local me = GG:GetCharacterKey()
  local groups = set and GG.RaidGroups:Groups()
  if set and GG.RaidGroups.JoinedRosters then
    for _, roster in ipairs(GG.RaidGroups.JoinedRosters(set.rosters, groups, me)) do
      Mark("rosterCallJoined", RosterKey(roster), tonumber(set.expiresAt) or GetServerTime() + WEEK_SECONDS)
    end
  end
  local info = set and GG.RaidGroups.InviteCallFor(set.rosters, groups, me)
  ForgetGone(info and not info.group.simulated and RosterKey(info.roster) or nil)
  if not info then
    spentSound = {}
    return Close()
  end
  if IsBusy() then return Close() end
  local key = RosterKey(info.roster)
  local mode = "full"
  if info.group.simulated then
    if cur and cur.key == key then mode = cur.mode end
  else
    if Marked("rosterCallDismissed", key) then return Close() end
    if PillEnabled() then
      if Marked("rosterCallJoined", key) then
        mode = "regroup"
      elseif Marked("rosterCallPill", key) then
        mode = "pill"
      end
    elseif Marked("rosterCallPill", key) then
      return Close()
    end
  end
  if mode ~= "full" then info.sounds = false end
  if IsInGroup and IsInGroup(LE_PARTY_CATEGORY_HOME) then
    info.sounds = false
    info.otherGroup = true
  end
  if cur and cur.key == key and cur.mode == mode then
    if info.otherGroup and info.group.simulated and cur.sentAt then return EndTest() end
    cur.info = info
    if info.otherGroup then cur.status = "alert" end
    Paint()
    if info.sounds and cur.status == "alert" then StartLoop(key) end
    return
  end
  Open(info, key, nil, mode, cur and cur.key == key and cur or nil)
end

local function TestInfo()
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
  return info, "__test"
end

function RC:Test()
  local info, key = TestInfo()
  spentSound[key] = nil
  if cur then Close() end
  Open(info, key, true)
end

function RC:TestPill()
  local info, key = TestInfo()
  if cur then Close() end
  Open(info, key, true, "pill")
end

RC._PlacePill = PlacePill
function RC:_State() return cur end
function RC:_Reset()
  Close()
  frames, spentSound, live, goneAt = {}, {}, {}, {}
  driver = nil
end

if CreateFrame then
  local events = CreateFrame("Frame")
  events:RegisterEvent("PLAYER_REGEN_DISABLED")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  events:SetScript("OnEvent", function() RC:Evaluate() end)
end
