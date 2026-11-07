local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.RosterAlert = {}
local RA = GG.RosterAlert

local Theme
local frame
local queue = {}
local WAIT_SECONDS = 2
local WIDTH, PAD = 460, 20
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function CreateText(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size, "")
  fs:SetTextColor(unpack(color))
  fs:SetJustifyH("LEFT")
  return fs
end

local function ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return { c.r, c.g, c.b, 1 } end
  return Theme.textPrimary
end

local function ShortLabel(label)
  return (label or ""):match("^(.-)%s+%-%s") or label or ""
end

local function BuildRow(parent, icon)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(20)
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(15, 15)
  row.icon:SetPoint("LEFT", 0, 0)
  row.icon:SetTexture(icon)
  row.label = CreateText(row, 13, Theme.textMuted)
  row.label:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
  row.name = CreateText(row, 13.5, Theme.textPrimary, true)
  row.name:SetPoint("RIGHT", 0, 0)
  row.name:SetJustifyH("RIGHT")
  return row
end

local function EnsureFrame()
  if frame then return frame end
  Theme = GG.Theme
  frame = CreateFrame("Frame", "GGRosterAlert", UIParent, "BackdropTemplate")
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetToplevel(true)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  frame:SetWidth(WIDTH)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  GG.Widgets.ApplyPanel(frame, { bg = Theme.background, corners = "all" })

  frame.stripe = frame:CreateTexture(nil, "ARTWORK")
  frame.stripe:SetPoint("TOPLEFT")
  frame.stripe:SetPoint("TOPRIGHT")
  frame.stripe:SetHeight(4)
  frame.stripe:SetColorTexture(unpack(Theme.gold))

  frame.icon = frame:CreateTexture(nil, "ARTWORK")
  frame.icon:SetSize(28, 28)
  frame.icon:SetPoint("TOPLEFT", PAD - 2, -18)
  frame.icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")

  frame.title = CreateText(frame, 16, Theme.textPrimary, true)
  frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -1)
  frame.title:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
  frame.title:SetWordWrap(true)
  frame.subtitle = CreateText(frame, 12, Theme.textMuted)
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
  frame.subtitle:SetPoint("RIGHT", frame, "RIGHT", -PAD, 0)
  frame.subtitle:SetWordWrap(true)

  frame.box = CreateFrame("Frame", nil, frame, "BackdropTemplate")
  frame.box:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  frame.box:SetBackdropColor(1, 1, 1, 0.03)
  frame.box:SetBackdropBorderColor(unpack(Theme.border))
  frame.box:SetHeight(58)
  frame.mine = BuildRow(frame.box, "Interface\\RaidFrame\\ReadyCheck-Ready")
  frame.mine:SetPoint("TOPLEFT", 12, -9)
  frame.mine:SetPoint("TOPRIGHT", -12, -9)
  frame.current = BuildRow(frame.box, "Interface\\RaidFrame\\ReadyCheck-NotReady")
  frame.current:SetPoint("TOPLEFT", frame.mine, "BOTTOMLEFT", 0, -6)
  frame.current:SetPoint("TOPRIGHT", frame.mine, "BOTTOMRIGHT", 0, -6)

  frame.ok = GG.Widgets.CreateButton(frame, L["RA_OK"], function()
    if frame.waiting then return end
    frame:Hide()
  end)
  frame.ok:SetHeight(28)
  frame.footer = CreateText(frame, 11.5, Theme.textMuted)
  frame.footer:SetWordWrap(true)

  frame:SetScript("OnHide", function()
    if frame.ticker then frame.ticker:Cancel() frame.ticker = nil end
    local pending = queue
    queue = {}
    for _, fn in ipairs(pending) do fn() end
  end)
  frame:Hide()
  return frame
end

local function PaintButton()
  local ok = frame.ok
  if frame.waiting then
    ok.label:SetText(("%s (%d)"):format(L["RA_OK"], frame.wait))
    ok:SetDisabled(true)
    ok:SetBackdropBorderColor(unpack(Theme.border))
  else
    ok.label:SetText(L["RA_OK"])
    ok:SetDisabled(false)
    ok.label:SetTextColor(unpack(Theme.gold))
    ok:SetBackdropBorderColor(unpack(Theme.gold))
  end
  ok:SetWidth(ok.label:GetStringWidth() + 32)
end

function RA:Show(info)
  EnsureFrame()
  local label = info.roster.label or ""
  local short = ShortLabel(label)
  local _, myClass = UnitClass("player")

  frame.title:SetText(L["RA_TITLE"]:format(short))
  frame.subtitle:SetText(L["RA_SUB"]:format(info.count, info.total, label))
  frame.mine.label:SetText(L["RA_MINE"]:format(short))
  frame.mine.name:SetText(info.mine.key)
  frame.mine.name:SetTextColor(unpack(ClassColor(info.mine.class)))
  frame.current.label:SetText(L["RA_CURRENT"])
  frame.current.name:SetText(GG:GetCharacterKey())
  frame.current.name:SetTextColor(unpack(ClassColor(myClass)))
  frame.footer:SetText(L["RA_FOOTER"]:format(short))

  local top = 18 + math.max(28, frame.title:GetStringHeight() + 4 + frame.subtitle:GetStringHeight())
  frame.box:ClearAllPoints()
  frame.box:SetPoint("TOPLEFT", PAD, -(top + 12))
  frame.box:SetPoint("TOPRIGHT", -PAD, -(top + 12))
  frame.wait, frame.waiting = WAIT_SECONDS, true
  PaintButton()
  frame.ok:ClearAllPoints()
  frame.ok:SetPoint("TOPRIGHT", frame.box, "BOTTOMRIGHT", 0, -12)
  frame.footer:ClearAllPoints()
  frame.footer:SetPoint("TOPLEFT", frame.box, "BOTTOMLEFT", 0, -14)
  frame.footer:SetPoint("RIGHT", frame.ok, "LEFT", -12, 0)
  frame:SetHeight(top + 12 + 58 + 12 + math.max(28, frame.footer:GetStringHeight()) + 16)

  local lockout = _G.GGLockoutAlert
  if lockout and lockout:IsShown() and GG.LockoutAlert then
    lockout:Hide()
    queue[#queue + 1] = function() GG.LockoutAlert:RenderGroupAlert() end
  end

  if frame.ticker then frame.ticker:Cancel() end
  frame.ticker = C_Timer.NewTicker(1, function()
    frame.wait = frame.wait - 1
    frame.waiting = frame.wait > 0
    PaintButton()
  end, WAIT_SECONDS)
  frame:Show()
  if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING) end
end

function RA:CheckJoin(group)
  if GGDB.options.popupRosterCharacter == false then return true end
  local set = GG.RaidRosters and GG.RaidRosters:GetCurrentSet()
  if not set then return false end
  local mine = {}
  for _, row in ipairs(GG.Roster and GG.Roster:BuildRows() or {}) do
    mine[#mine + 1] = { key = row.key, class = row.class }
  end
  local info = GG.RaidGroups.WrongCharacter(group, set.rosters, mine, GG:GetCharacterKey())
  if not info then return false end
  self:Show(info)
  return true
end

function RA:QueueAfter(fn)
  if not (frame and frame:IsShown()) then return false end
  queue[#queue + 1] = fn
  return true
end

function RA:Test()
  local set = GG.RaidRosters and GG.RaidRosters:GetCurrentSet()
  local current = GG:GetCharacterKey()
  for _, row in ipairs(GG.Roster and GG.Roster:BuildRows() or {}) do
    for _, roster in ipairs(set and set.rosters or {}) do
      if row.key ~= current and GG.RaidGroups.InRoster(roster.members, row.key) then
        local n = #roster.members
        return self:Show({ roster = roster, count = math.ceil(n * 0.6), total = n, mine = { key = row.key, class = row.class } })
      end
    end
  end
  local _, class = UnitClass("player")
  self:Show({ roster = { label = "M1 - Thursday 10.00 PM" }, count = 12, total = 20, mine = { key = current, class = class } })
end
