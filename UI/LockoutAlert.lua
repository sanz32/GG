local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.LockoutAlert = {}

local Theme
local frame

local everDrawn = false
local visible = false
local repaint

local DATA_SETTLE_SECONDS = 3

local INSTANCE_ALERT_DIFFICULTIES = {
  [14] = true,
  [15] = true,
}

local DIFFICULTY_LABEL_KEYS = {
  [14] = "DIFFICULTY_NORMAL",
  [15] = "DIFFICULTY_HEROIC",
  [16] = "DIFFICULTY_MYTHIC",
}

local GROUP_TITLE_SIZE = 17
local GROUP_SUBTITLE_SIZE = 12.5
local GROUP_RAID_SIZE = 14
local GROUP_ROW_SIZE = 14
local INSTANCE_TITLE_SIZE = 15
local INSTANCE_SUBTITLE_SIZE = 11.5

local PAD_X = 22
local BODY_TOP = 62
local GAP_BODY_FOOTER = 18
local GAP_FOOTER_BUTTON = 14
local PAD_BOTTOM = 18
local FOOTER_H = 14
local MIN_WIDTH = 320

local function EnsureTheme()
  Theme = Theme or GG.Theme
  return Theme
end

local function CreateText(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size, "")
  fs:SetTextColor(unpack(color))
  fs:SetJustifyH("LEFT")
  return fs
end

local function EnsureFrame()
  if frame then return frame end
  EnsureTheme()

  frame = CreateFrame("Frame", "GGLockoutAlert", UIParent, "BackdropTemplate")
  frame:SetFrameStrata("FULLSCREEN_DIALOG")
  frame:SetToplevel(true)
  frame:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
  frame:SetSize(420, 200)
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  GG.Widgets.ApplyPanel(frame, { bg = Theme.background, corners = "all" })

  frame.accent = frame:CreateTexture(nil, "ARTWORK")
  frame.accent:SetPoint("TOPLEFT")
  frame.accent:SetPoint("TOPRIGHT")
  frame.accent:SetHeight(3)

  frame.title = CreateText(frame, 15, Theme.textPrimary, true)
  frame.title:SetPoint("TOP", 0, -16)
  frame.title:SetJustifyH("CENTER")

  frame.subtitle = CreateText(frame, 11.5, Theme.textMuted)
  frame.subtitle:SetPoint("TOP", frame.title, "BOTTOM", 0, -4)
  frame.subtitle:SetJustifyH("CENTER")

  frame.body = CreateFrame("Frame", nil, frame)
  frame.body:SetPoint("TOPLEFT", PAD_X, -BODY_TOP)
  frame.body:SetPoint("TOPRIGHT", -PAD_X, -BODY_TOP)
  frame.body:SetHeight(1)
  frame.lines = {}

  frame.footer = CreateText(frame, 11, Theme.textMuted)
  frame.footer:SetJustifyH("CENTER")

  frame.accept = GG.Widgets.CreateButton(frame, L["LOCKOUT_ALERT_ACCEPT"], function()
    frame:Hide()
  end)

  frame:SetScript("OnHide", function() visible = false end)
  tinsert(UISpecialFrames, "GGLockoutAlert")
  frame:Hide()
  return frame
end

local function TextWidth(fs)
  local width = fs:GetStringWidth()
  if width and width > 0 then return width end
  local text = fs:GetText() or ""
  local _, size = fs:GetFont()
  return #text * (size or 12) * 0.55
end

local function PrepareLine(index, text, color, bold, size)
  local line = frame.lines[index]
  if not line then
    line = CreateText(frame.body, 12, Theme.textPrimary)
    line.icon = GG.BossIcons:Create(frame.body)
    line.icon:SetSize(14, 14)
    frame.lines[index] = line
  end
  line:SetFont(bold and Theme.fontBold or Theme.font, size or 12, "")
  line:SetText(text)
  line:SetTextColor(unpack(color))
  line:Show()
  line.icon:Hide()
  return line
end

local function PlaceLine(line, x, y, killedIcon, slot)
  line:ClearAllPoints()
  if killedIcon == nil then
    line:SetPoint("TOPLEFT", frame.body, "TOPLEFT", x, -y)
  else
    line.icon:ClearAllPoints()
    line.icon:SetPoint("TOPLEFT", frame.body, "TOPLEFT", x, -y + 1)
    GG.BossIcons:Paint(line.icon, killedIcon, Theme.danger, slot, slot and GG.BossIcons:LetterForSlot(slot))
    line.icon:Show()
    line:SetPoint("TOPLEFT", frame.body, "TOPLEFT", x + 20, -y)
  end
end

local function HideLinesFrom(index)
  for i = index, #frame.lines do
    frame.lines[i]:Hide()
    if frame.lines[i].icon then frame.lines[i].icon:Hide() end
  end
end

local function FinishFrame(contentWidth, bodyHeight)
  local footerText = frame.footer:GetText()
  local hasFooter = footerText and footerText ~= ""

  local width = math.max(
    MIN_WIDTH,
    contentWidth + PAD_X * 2,
    TextWidth(frame.title) + PAD_X * 2,
    hasFooter and (TextWidth(frame.footer) + PAD_X * 2) or 0
  )
  frame:SetWidth(width)
  frame.body:SetHeight(math.max(bodyHeight, 1))

  frame.footer:ClearAllPoints()
  frame.footer:SetPoint("TOP", frame.body, "BOTTOM", 0, -GAP_BODY_FOOTER)

  frame.accept:ClearAllPoints()
  if hasFooter then
    frame.accept:SetPoint("TOP", frame.footer, "BOTTOM", 0, -GAP_FOOTER_BUTTON)
  else
    frame.accept:SetPoint("TOP", frame.body, "BOTTOM", 0, -GAP_BODY_FOOTER)
  end
  frame.accept:SetWidth(math.max(96, TextWidth(frame.accept.label) + 32))

  local height = BODY_TOP + bodyHeight + GAP_BODY_FOOTER
    + (hasFooter and (FOOTER_H + GAP_FOOTER_BUTTON) or 0)
    + frame.accept:GetHeight() + PAD_BOTTOM
  frame:SetHeight(height)
  frame:Show()
  visible = true

  if not everDrawn then
    everDrawn = true
    C_Timer.After(0, function()
      if visible and repaint then repaint() end
    end)
  end
end

local function StatusText(killed, total, unconfirmed)
  if killed > 0 then
    return ("%s  %d/%d"):format(L["LOCKOUT_ALERT_SAVED"], killed, total), Theme.danger
  end
  if unconfirmed then return L["LOCKOUT_ALERT_UNCONFIRMED"], Theme.gold end
  return L["LOCKOUT_ALERT_UNSAVED"], Theme.success
end

local CONFIRM_RETRIES = 5
local CONFIRM_RETRY_SECONDS = 2

local function AfterLockoutData(fn, tries)
  tries = tries or CONFIRM_RETRIES
  if GG.Lockouts:HasServerData() or tries <= 0 then return fn() end
  GG:RequestGameData()
  C_Timer.After(CONFIRM_RETRY_SECONDS, function() AfterLockoutData(fn, tries - 1) end)
end

function GG.LockoutAlert:ShowGroupAlert(force)
  if not force and GGDB.options.popupLockoutGroup == false then return end
  GG:RequestGameData()
  C_Timer.After(DATA_SETTLE_SECONDS, function() AfterLockoutData(function()
    if not force and not IsInRaid() then return end
    if not force and GG.RosterAlert and GG.RosterAlert:QueueAfter(function() self:RenderGroupAlert() end) then return end
    if not force and self:ResolveCurrentRaid() then return end
    self:RenderGroupAlert()
  end) end)
end

function GG.LockoutAlert:RenderGroupAlert()
  EnsureFrame()
  repaint = function() self:RenderGroupAlert() end
  local record = GG:GetOrCreateCharacterRecord()
  local lookup = GG.Lockouts:BuildKilledLookup(record)
  local unconfirmed = not GG.Lockouts:HasServerData()

  local anySaved = false
  local index, y = 1, 0
  local catalog = GG.Lockouts:GetRaidBossCatalog()

  local rows, labelWidth, statusWidth, titleWidth = {}, 0, 0, 0

  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    local range = GG.Lockouts:RaidSlotRange(raid.instanceID)
    local slotOffset = (range and range.offset) or 0
    local entry = catalog[raid.instanceID]

    local titleLine = PrepareLine(index, (entry and entry.name) or raid.name or "?",
      Theme.accent, true, GROUP_RAID_SIZE)
    titleWidth = math.max(titleWidth, TextWidth(titleLine))
    table.insert(rows, { line = titleLine, kind = "raid" })
    index = index + 1

    for _, difficultyID in ipairs(GG.Lockouts.SHARED_DIFFICULTIES) do
      local slots = GG.Lockouts:BuildDifficultySlots(record, difficultyID, lookup)
      local killed = 0
      for i = 1, (raid.numEncounters or 0) do
        if slots[slotOffset + i] then killed = killed + 1 end
      end
      if killed > 0 then anySaved = true end

      local text, color = StatusText(killed, raid.numEncounters or 0, unconfirmed)
      local label = PrepareLine(index, L[DIFFICULTY_LABEL_KEYS[difficultyID]],
        Theme.textMuted, false, GROUP_ROW_SIZE)
      local status = PrepareLine(index + 1, text, color, false, GROUP_ROW_SIZE)
      status:SetJustifyH("LEFT")
      labelWidth = math.max(labelWidth, TextWidth(label))
      statusWidth = math.max(statusWidth, TextWidth(status))
      table.insert(rows, { line = label, status = status, kind = "difficulty" })
      index = index + 2
    end
    table.insert(rows, { kind = "gap" })
  end

  HideLinesFrom(index)

  local INDENT, COL_GAP = 16, 26
  local statusX = INDENT + labelWidth + COL_GAP
  local contentWidth = math.max(titleWidth, statusX + statusWidth)

  local bodyWidth = math.max(MIN_WIDTH - PAD_X * 2, contentWidth)
  local x0 = math.max(0, (bodyWidth - contentWidth) / 2)

  y = 0
  for _, row in ipairs(rows) do
    if row.kind == "gap" then
      y = y + 12
    elseif row.kind == "raid" then
      PlaceLine(row.line, x0, y)
      y = y + 24
    else
      PlaceLine(row.line, x0 + INDENT, y)
      PlaceLine(row.status, x0 + statusX, y)
      y = y + 21
    end
  end
  y = y - 12

  frame.title:SetFont(Theme.fontBold, GROUP_TITLE_SIZE, "")
  local title, tone = L["LOCKOUT_ALERT_GROUP_TITLE_CLEAN"], Theme.success
  if anySaved then
    title, tone = L["LOCKOUT_ALERT_GROUP_TITLE_SAVED"], Theme.danger
  elseif unconfirmed then
    title, tone = L["LOCKOUT_ALERT_TITLE_UNCONFIRMED"], Theme.gold
  end
  frame.title:SetText(title)
  frame.title:SetTextColor(unpack(tone))
  frame.subtitle:SetFont(Theme.font, GROUP_SUBTITLE_SIZE, "")
  frame.subtitle:SetText(GG:GetCharacterKey() or "")
  frame.accent:SetColorTexture(unpack(tone))
  frame.footer:SetText("")

  FinishFrame(contentWidth, y)
end

function GG.LockoutAlert:AppliesToDifficulty(difficultyID)
  return INSTANCE_ALERT_DIFFICULTIES[difficultyID] == true
end

function GG.LockoutAlert:ResolveCurrentRaid()
  local inInstance, instanceType = IsInInstance()
  if not inInstance then return nil, L["DIAG_REASON_NOT_IN_INSTANCE"] end
  if instanceType ~= "raid" then return nil, L["DIAG_REASON_NOT_RAID"]:format(tostring(instanceType)) end

  local name, _, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
  if not instanceID then return nil, L["DIAG_REASON_NO_ID"] end

  local raidDef
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    if raid.instanceID == instanceID then raidDef = raid end
  end
  if not raidDef then
    return nil, L["DIAG_REASON_NOT_SEASON"]:format(tostring(name), tostring(instanceID))
  end

  local baseDifficulty = GG.Lockouts:BaseDifficultyID(difficultyID)
  if not DIFFICULTY_LABEL_KEYS[baseDifficulty] then
    return nil, L["DIAG_REASON_DIFFICULTY"]:format(tostring(difficultyName), tostring(difficultyID))
  end
  return raidDef, nil, baseDifficulty, instanceID, difficultyID
end

local lastInstanceKey

function GG.LockoutAlert:OnEnteringWorld()
  if GGDB.options.popupLockoutInstance == false then return end
  local raidDef, _, baseDifficulty, instanceID = self:ResolveCurrentRaid()
  if not raidDef then
    lastInstanceKey = nil
    return
  end

  if not self:AppliesToDifficulty(baseDifficulty) then
    lastInstanceKey = nil
    return
  end

  local key = tostring(instanceID) .. ":" .. tostring(baseDifficulty)
  if lastInstanceKey == key then return end
  lastInstanceKey = key

  GG:RequestGameData()
  C_Timer.After(DATA_SETTLE_SECONDS, function() AfterLockoutData(function()
    local stillInside, stillRaid = IsInInstance()
    if not stillInside or stillRaid ~= "raid" then return end
    self:RenderInstanceAlert(raidDef, baseDifficulty)
  end) end)
end

function GG.LockoutAlert:TestInstanceAlert()
  local raidDef = GG.Season.RAIDS and GG.Season.RAIDS[1]
  if raidDef then self:RenderInstanceAlert(raidDef, 15) end
end

function GG.LockoutAlert:RenderInstanceAlert(raidDef, difficultyID)
  EnsureFrame()
  repaint = function() self:RenderInstanceAlert(raidDef, difficultyID) end
  local record = GG:GetOrCreateCharacterRecord()
  local lookup = GG.Lockouts:BuildKilledLookup(record)
  local catalog = GG.Lockouts:GetRaidBossCatalog()
  local entry = catalog[raidDef.instanceID]

  local range = GG.Lockouts:RaidSlotRange(raidDef.instanceID)
  local slotOffset = (range and range.offset) or 0

  local slots = GG.Lockouts:BuildDifficultySlots(record, difficultyID, lookup)
  local killed, index, y = 0, 1, 0

  local bosses = (entry and entry.bosses) or {}
  local columns = (#bosses > 4) and 2 or 1
  local perColumn = math.ceil(#bosses / columns)

  local prepared, nameWidth = {}, 0
  for i, boss in ipairs(bosses) do
    local isKilled = slots[slotOffset + i] == true
    if isKilled then killed = killed + 1 end
    local line = PrepareLine(index, boss.name or "?", isKilled and Theme.danger or Theme.textPrimary)
    nameWidth = math.max(nameWidth, TextWidth(line))
    table.insert(prepared, { line = line, isKilled = isKilled, slot = slotOffset + i })
    index = index + 1
  end
  HideLinesFrom(index)

  local COL_GAP = 24
  local columnWidth = nameWidth + 20
  local contentWidth = columnWidth * columns + COL_GAP * (columns - 1)
  local bodyWidth = math.max(MIN_WIDTH - PAD_X * 2, contentWidth)
  local x0 = math.max(0, (bodyWidth - contentWidth) / 2)

  for i, item in ipairs(prepared) do
    local column = math.floor((i - 1) / perColumn)
    local row = (i - 1) % perColumn
    PlaceLine(item.line, x0 + column * (columnWidth + COL_GAP), row * 19, item.isKilled, item.slot)
    y = math.max(y, (row + 1) * 19)
  end

  local isSaved = killed > 0
  local unconfirmed = not isSaved and not GG.Lockouts:HasServerData()
  local title, tone = L["LOCKOUT_ALERT_INSTANCE_TITLE_CLEAN"], Theme.success
  if isSaved then
    title, tone = L["LOCKOUT_ALERT_INSTANCE_TITLE_SAVED"], Theme.danger
  elseif unconfirmed then
    title, tone = L["LOCKOUT_ALERT_TITLE_UNCONFIRMED"], Theme.gold
  end
  frame.title:SetFont(Theme.fontBold, INSTANCE_TITLE_SIZE, "")
  frame.subtitle:SetFont(Theme.font, INSTANCE_SUBTITLE_SIZE, "")
  frame.title:SetText(title)
  frame.title:SetTextColor(unpack(tone))
  frame.accent:SetColorTexture(unpack(tone))
  frame.subtitle:SetText(("%s  ·  %s"):format(
    (entry and entry.name) or raidDef.name or "?",
    L[DIFFICULTY_LABEL_KEYS[difficultyID]] or "?"))
  local footer
  if isSaved then
    footer = killed == 1 and L["LOCKOUT_ALERT_INSTANCE_FOOTER_SAVED_ONE"]
      or L["LOCKOUT_ALERT_INSTANCE_FOOTER_SAVED"]:format(killed)
  elseif unconfirmed then
    footer = L["LOCKOUT_ALERT_FOOTER_UNCONFIRMED"]
  else
    footer = #bosses == 1 and L["LOCKOUT_ALERT_INSTANCE_FOOTER_CLEAN_ONE"]
      or L["LOCKOUT_ALERT_INSTANCE_FOOTER_CLEAN"]:format(#bosses)
  end
  frame.footer:SetText(footer)

  FinishFrame(contentWidth, y)
end
