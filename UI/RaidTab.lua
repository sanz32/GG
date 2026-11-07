local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.RaidTab = {}

local Theme
local container
local state = { difficultyID = 15, raidInstanceID = nil }

local function DefaultRaidInstanceID()
  local best
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    if not best or (raid.numEncounters or 0) > (best.numEncounters or 0) then best = raid end
  end
  return best and best.instanceID
end

local PORTRAIT_W, PORTRAIT_H = 112, 56
local NAME_H = 26
local ROW_H = 22
local BOSS_DOT = 16
local COL_NAME, COL_STATUS, COL_DETAIL = 210, 90, 110
local NAV_BG = { 0.063, 0.071, 0.090, 1 }
local STAT_W, STAT_H = 112, 54
local GROUP_H = 22
local WHITE = "Interface\\Buttons\\WHITE8x8"

local function Amber() return Theme.warning or Theme.gold end

local function BossColor(isKilled)
  if isKilled then return Theme.danger end
  return { 0.302, 0.318, 0.376, 1 }
end

local function CreateText(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size, "")
  fs:SetTextColor(unpack(color))
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

local function TextWidth(fs)
  local width = fs:GetStringWidth()
  if width and width > 0 then return width end
  local _, size = fs:GetFont()
  return #(fs:GetText() or "") * (size or 11) * 0.6
end

local function CreateRule(parent, strong)
  local tex = parent:CreateTexture(nil, "ARTWORK")
  tex:SetHeight(1)
  tex:SetColorTexture(unpack(strong and Theme.borderSoft or { 1, 1, 1, 0.05 }))
  return tex
end

local function BuildSegment(parent, items, onPick)
  local seg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  seg:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  seg:SetBackdropColor(unpack(NAV_BG))
  seg:SetBackdropBorderColor(unpack(Theme.border))
  seg:SetHeight(24)
  seg.buttons = {}
  seg.order = {}
  for _, item in ipairs(items) do
    local btn = CreateFrame("Button", nil, seg)
    btn:SetHeight(20)
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.label = CreateText(btn, 11.5, Theme.textMuted, true)
    btn.label:SetPoint("CENTER")
    btn.label:SetJustifyH("CENTER")
    btn.label:SetText(item.label)
    seg.order[#seg.order + 1] = btn
    local key = item.key
    btn:SetScript("OnClick", function() onPick(key) end)
    btn:SetScript("OnEnter", function(self)
      if not self.active then self.bg:SetColorTexture(1, 1, 1, 0.06) end
    end)
    btn:SetScript("OnLeave", function(self)
      if not self.active then self.bg:SetColorTexture(0, 0, 0, 0) end
    end)
    seg.buttons[key] = btn
  end
  seg.Layout = function()
    local x = 2
    for _, btn in ipairs(seg.order) do
      local width = math.max(56, math.ceil(TextWidth(btn.label)) + 22)
      btn:SetWidth(width)
      btn:ClearAllPoints()
      btn:SetPoint("LEFT", seg, "LEFT", x, 0)
      x = x + width + 2
    end
    seg:SetWidth(math.max(x, 4))
  end
  seg.Layout()
  return seg
end

local function BuildDifficultyToggle(parent)
  local items = {}
  for _, difficultyID in ipairs(GG.Lockouts.SHARED_DIFFICULTIES) do
    local labelKey = ({ [14] = "DIFFICULTY_NORMAL", [15] = "DIFFICULTY_HEROIC", [16] = "DIFFICULTY_MYTHIC" })[difficultyID]
    table.insert(items, { key = difficultyID, label = L[labelKey] })
  end
  return BuildSegment(parent, items, function(difficultyID)
    state.difficultyID = difficultyID
    if container and container.list then container.list.offset = 0 end
    GG.RaidTab:Refresh()
  end)
end

local function BuildRaidToggle(parent)
  local items = {}
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    table.insert(items, { key = raid.instanceID, label = raid.name or "?" })
  end
  return BuildSegment(parent, items, function(instanceID)
    state.raidInstanceID = instanceID
    if container and container.list then container.list.offset = 0 end
    GG.RaidTab:Refresh()
  end)
end

local function PaintToggle(holder, activeKey)
  holder.Layout()
  for key, btn in pairs(holder.buttons) do
    local active = key == activeKey
    btn.active = active
    btn.bg:SetColorTexture(unpack(active and Theme.accent or { 0, 0, 0, 0 }))
    btn.label:SetTextColor(unpack(active and Theme.onAccent or Theme.textMuted))
  end
end

local function BuildStat(parent, labelKey, color, block)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:EnableMouse(true)
  box:SetScript("OnMouseUp", function() GG.RaidTab:ScrollToBlock(block) end)
  box:SetScript("OnEnter", function(self)
    if (tonumber(self.number:GetText()) or 0) > 0 then
      self:SetBackdropBorderColor(color[1], color[2], color[3], 0.8)
    end
  end)
  box:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(Theme.borderSoft)) end)
  box:SetSize(STAT_W, STAT_H)
  box:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  box:SetBackdropColor(1, 1, 1, 0.03)
  box:SetBackdropBorderColor(unpack(Theme.borderSoft))
  box.edge = box:CreateTexture(nil, "ARTWORK")
  box.edge:SetPoint("TOPLEFT", 0, 0)
  box.edge:SetPoint("BOTTOMLEFT", 0, 0)
  box.edge:SetWidth(3)
  box.edge:SetColorTexture(unpack(color))
  box.number = CreateText(box, 24, color, true)
  box.number:SetPoint("TOPLEFT", 14, -7)
  box.label = CreateText(box, 10, Theme.textFaint, true)
  box.label:SetPoint("BOTTOMLEFT", 14, 8)
  box.label:SetText(L[labelKey]:upper())
  return box
end

local function BuildBossStrip(parent)
  local strip = CreateFrame("Frame", nil, parent)
  strip:SetHeight(PORTRAIT_H + 30)
  strip.slots = {}

  strip.groups = {}
  local slotIndex, x = 0, 0
  for raidIndex, raid in ipairs(GG.Season.RAIDS or {}) do
    if raidIndex > 1 then x = x + 22 end
    local groupStartX = x

    for i = 1, (raid.numEncounters or 0) do
      slotIndex = slotIndex + 1
      local slot = CreateFrame("Frame", nil, strip)
      slot:SetSize(PORTRAIT_W, PORTRAIT_H + 4 + NAME_H)
      slot:SetPoint("TOPLEFT", x, 0)

      slot.portrait = slot:CreateTexture(nil, "ARTWORK")
      slot.portrait:SetSize(PORTRAIT_W, PORTRAIT_H)
      slot.portrait:SetPoint("TOP")

      slot.border = CreateFrame("Frame", nil, slot, "BackdropTemplate")
      slot.border:SetPoint("TOPLEFT", slot.portrait, "TOPLEFT", -1, 1)
      slot.border:SetPoint("BOTTOMRIGHT", slot.portrait, "BOTTOMRIGHT", 1, -1)
      slot.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
      slot.border:SetBackdropBorderColor(unpack(Theme.borderSoft))

      slot.name = CreateText(slot, 10.5, Theme.textMuted)
      slot.name:SetPoint("TOP", slot.portrait, "BOTTOM", 0, -4)
      slot.name:SetWidth(PORTRAIT_W)
      slot.name:SetJustifyH("CENTER")
      slot.name:SetJustifyV("TOP")
      slot.name:SetWordWrap(true)
      slot.name:SetMaxLines(2)
      slot.name:SetHeight(NAME_H)

      slot.count = CreateFrame("Frame", nil, slot, "BackdropTemplate")
      slot.count:SetHeight(16)
      slot.count:SetPoint("BOTTOMRIGHT", slot.portrait, "BOTTOMRIGHT", -3, 3)
      slot.count:SetBackdrop({ bgFile = WHITE })
      slot.count.text = CreateText(slot.count, 10, { 1, 1, 1, 1 }, true)
      slot.count.text:SetPoint("CENTER")
      slot.count.text:SetJustifyH("CENTER")
      slot.count:Hide()

      slot.raidKey = raid.instanceID
      slot.journalInstanceID = raid.journalInstanceID
      slot.bossIndex = i
      strip.slots[slotIndex] = slot
      x = x + PORTRAIT_W + 4
    end

    local groupWidth = (x - 4) - groupStartX
    local group = CreateFrame("Frame", nil, strip)
    group:SetPoint("TOPLEFT", groupStartX, -(PORTRAIT_H + 26))
    group:SetSize(groupWidth, 16)

    group.rule = CreateRule(group, true)
    group.rule:SetPoint("TOPLEFT", 0, 0)
    group.rule:SetPoint("TOPRIGHT", 0, 0)

    group.label = CreateText(group, 10.5, Theme.textFaint)
    group.label:SetPoint("TOP", 0, -3)
    group.label:SetWidth(groupWidth)
    group.label:SetJustifyH("CENTER")
    group.label:SetText(raid.name or "?")

    table.insert(strip.groups, group)
  end

  strip:SetWidth(x)
  strip:SetHeight(PORTRAIT_H + 4 + NAME_H)
  return strip
end

local function BossPortrait(slot, boss)
  if not (boss and boss.journalEncounterID and slot.journalInstanceID) then return nil end
  local ok, icon = pcall(function()
    EJ_SelectInstance(slot.journalInstanceID)
    local _, _, _, _, iconImage = EJ_GetCreatureInfo(1, boss.journalEncounterID)
    return iconImage
  end)
  return ok and icon or nil
end

local function ActiveBossNames()
  local catalog = GG.Lockouts:GetRaidBossCatalog()
  local entry = catalog[state.raidInstanceID]
  local names = {}
  for i, boss in ipairs((entry and entry.bosses) or {}) do
    names[i] = boss.name or "?"
  end
  return names
end

local function PaintBossStrip(kills, known)
  local catalog = GG.Lockouts:GetRaidBossCatalog()
  local x = 0

  for _, slot in ipairs(container.bosses.slots) do
    local mine = slot.raidKey == state.raidInstanceID
    slot:SetShown(mine)
    if mine then
      local entry = catalog[slot.raidKey]
      local boss = entry and entry.bosses[slot.bossIndex]
      slot.name:SetText(boss and boss.name or "?")

      local killedBy = kills[slot.bossIndex] or 0
      slot.count:SetShown(killedBy > 0)
      if killedBy > 0 then
        slot.count.text:SetText(tostring(killedBy))
        slot.count:SetWidth(math.max(16, slot.count.text:GetStringWidth() + 10))
        if killedBy > 0 then
          slot.count:SetBackdropColor(Theme.danger[1], Theme.danger[2], Theme.danger[3], 0.92)
          slot.count.text:SetTextColor(1, 1, 1, 1)
        else
          slot.count:SetBackdropColor(0, 0, 0, 0.72)
          slot.count.text:SetTextColor(unpack(Theme.textMuted))
        end
      end
      slot.border:SetBackdropBorderColor(unpack(killedBy > 0 and Theme.danger or Theme.borderSoft))

      slot:ClearAllPoints()
      slot:SetPoint("TOPLEFT", x, 0)
      x = x + PORTRAIT_W + 4

      local iconImage = BossPortrait(slot, boss)
      if iconImage then
        slot.portrait:SetTexture(iconImage)
        slot.portrait:SetVertexColor(1, 1, 1, 1)
      else
        slot.portrait:SetTexture("Interface\\Buttons\\WHITE8x8")
        slot.portrait:SetVertexColor(0.12, 0.13, 0.16, 1)
      end
    end
  end

  for _, group in ipairs(container.bosses.groups) do group:Hide() end
  container.bosses:SetWidth(math.max(x, 1))
end

local function EnsureRow(index)
  local row = container.rows[index]
  if row then return row end

  row = CreateFrame("Frame", nil, container.list)
  row:SetHeight(ROW_H)
  row:SetPoint("LEFT", 0, 0)
  row:SetPoint("RIGHT", 0, 0)

  row.stripe = row:CreateTexture(nil, "BACKGROUND")
  row.stripe:SetAllPoints()
  row.stripe:SetColorTexture(1, 1, 1, 0.02)
  row.stripe:Hide()

  row.selfMark = row:CreateTexture(nil, "ARTWORK")
  row.selfMark:SetSize(2, ROW_H - 6)
  row.selfMark:SetPoint("LEFT", 0, 0)
  row.selfMark:SetColorTexture(unpack(Theme.accent))
  row.selfMark:Hide()

  row.name = CreateText(row, 12, Theme.textPrimary)
  row.name:SetPoint("LEFT", 8, 0)
  row.name:SetWidth(COL_NAME)

  row.status = CreateText(row, 11, Theme.textPrimary, true)
  row.status:SetPoint("LEFT", row.name, "RIGHT", 14, 0)
  row.status:SetWidth(COL_STATUS)

  row.detail = CreateText(row, 10.5, Theme.textFaint)
  row.detail:SetPoint("LEFT", row.status, "RIGHT", 10, 0)
  row.detail:SetWidth(COL_DETAIL)

  row.bossAnchor = row:CreateTexture(nil, "ARTWORK")
  row.bossAnchor:SetSize(1, 1)
  row.bossAnchor:SetPoint("LEFT", row.status, "RIGHT", 16 + COL_DETAIL, 0)

  row.statusChip = row:CreateTexture(nil, "BORDER")
  row.statusChip:SetHeight(17)
  row.statusChip:SetPoint("LEFT", row.status, "LEFT", -6, 0)
  row.detailChip = row:CreateTexture(nil, "BORDER")
  row.detailChip:SetHeight(17)
  row.detailChip:SetPoint("LEFT", row.detail, "LEFT", -6, 0)
  row.detailChip:SetColorTexture(1, 1, 1, 0.06)

  row.dots = {}
  local dotSize, dotStep = GG.BossIcons:SnapLine(BOSS_DOT, 2, GG.BossIcons:PixelsPerUnit(row))
  for i = 1, 16 do
    local dot = CreateFrame("Frame", nil, row)
    dot:SetSize(dotSize, dotSize)
    dot:SetPoint("LEFT", row.bossAnchor, "LEFT", (i - 1) * dotStep, 0)
    dot:EnableMouse(true)

    dot.icon = GG.BossIcons:Create(dot)
    dot.icon:SetSize(dotSize, dotSize)
    dot.icon:SetPoint("CENTER")

    dot:SetScript("OnEnter", function(self)
      if not self.bossName then return end
      local dotKilled = self.isKilled
      local bossName, ownerName = self.bossName, self.ownerName
      local icon = GG.Lockouts:BossIcon(self.instanceID, self.bossIndex)
      GG.Tip:Open(self, { family = "raid" }, function(t)
        t:BossHead({ icon = icon, title = bossName, sub = ownerName, dead = dotKilled })
        t:Text(L[dotKilled and "RAID_TOOLTIP_KILLED" or "RAID_TOOLTIP_NOT_KILLED"], dotKilled and Theme.danger or Theme.success)
      end)
    end)
    dot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    dot:Hide()
    row.dots[i] = dot
  end

  row.age = CreateText(row, 10.5, Theme.textFaint)
  row.age:SetPoint("LEFT", row.bossAnchor, "LEFT", 0, 0)

  container.rows[index] = row
  return row
end

local function FormatAge(receivedAt)
  if not receivedAt then return "" end
  local seconds = time() - receivedAt
  if seconds < 60 then return ("%ds"):format(math.max(seconds, 0)) end
  if seconds < 3600 then return ("%dm"):format(math.floor(seconds / 60)) end
  return ("%dh"):format(math.floor(seconds / 3600))
end

local function DescribeStatus(row)
  if row.status == "saved" then
    return L["RAID_STATUS_SAVED"]:format(row.killed, row.total), Theme.danger, ""
  elseif row.status == "unsaved" then
    return L["RAID_STATUS_UNSAVED"], Theme.success, ""
  elseif row.status == "noaddon" then
    return L["RAID_STATUS_NO_ADDON"], Amber(), L["RAID_STATUS_NO_ADDON_DETAIL"]
  elseif row.status == "outdated" then
    local detail = row.addonVersion
      and L["RAID_STATUS_OUTDATED_DETAIL"]:format(row.addonVersion)
      or L["RAID_STATUS_OUTDATED_DETAIL_UNKNOWN"]
    return L["RAID_STATUS_OUTDATED"], Amber(), detail
  end
  return L["RAID_STATUS_NO_DATA"], Amber(), L["RAID_STATUS_NO_DATA_DETAIL"]
end

local function PaintRow(row, datum, index)
  local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[datum.class]
  row.name:SetText(datum.realm and datum.realm ~= ""
    and ("%s-%s"):format(datum.name or "?", datum.realm)
    or (datum.name or "?"))
  if classColor then
    row.name:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
  else
    row.name:SetTextColor(unpack(Theme.textPrimary))
  end
  row.stripe:SetShown(index % 2 == 0)
  row.selfMark:SetShown(datum.isSelf == true)

  row.detail:SetWidth(math.max(container.detailW or COL_DETAIL, 1))
  row.bossAnchor:ClearAllPoints()
  row.bossAnchor:SetPoint("LEFT", row.status, "RIGHT", container.bossX or (16 + COL_DETAIL), 0)
  row.age:ClearAllPoints()
  row.age:SetPoint("LEFT", row.bossAnchor, "LEFT", container.ageX or 0, 0)

  local text, color, detail = DescribeStatus(datum)
  row.status:SetText(text)
  row.status:SetTextColor(unpack(color))
  row.statusChip:SetColorTexture(color[1], color[2], color[3], 0.16)
  row.statusChip:SetWidth(math.min(row.status:GetStringWidth(), COL_STATUS) + 12)
  row.detail:SetText(detail)
  row.detailChip:SetShown(detail ~= "")
  if detail ~= "" then
    row.detailChip:SetWidth(math.min(row.detail:GetStringWidth(), container.detailW or COL_DETAIL) + 12)
  end
  row.age:SetText(FormatAge(datum.receivedAt))

  local showDots = datum.status == "saved" or datum.status == "unsaved"
  local bossNames = ActiveBossNames()
  local range = GG.Lockouts:RaidSlotRange(state.raidInstanceID)
  local offset = range and range.offset or 0
  for i, dot in ipairs(row.dots) do
    if showDots and i <= (datum.total or 0) then
      local isKilled = datum.slots[i] == true
      GG.BossIcons:Paint(dot.icon, isKilled, BossColor(true), offset + i,
        GG.BossIcons:LetterForSlot(offset + i))
      dot.bossName = bossNames[i]
      dot.instanceID = state.raidInstanceID
      dot.bossIndex = i
      dot.ownerName = datum.name
      dot.isKilled = isKilled
      dot:Show()
    else
      dot:Hide()
    end
  end
end

local function BlockOf(status)
  if status == "saved" then return 1 end
  if status == "unsaved" then return 3 end
  return 2
end

local function BlockStyle(block)
  if block == 1 then return L["RAID_STAT_SAVED"], Theme.danger end
  if block == 3 then return L["RAID_STAT_UNSAVED"], Theme.success end
  return L["RAID_STAT_UNKNOWN"], Amber()
end

local function EnsureGroupHead(index)
  local head = container.groupHeads[index]
  if head then return head end
  head = CreateFrame("Frame", nil, container.list)
  head:SetHeight(GROUP_H)
  head.label = CreateText(head, 10.5, Theme.textMuted, true)
  head.label:SetPoint("LEFT", 8, 0)
  head.line = head:CreateTexture(nil, "ARTWORK")
  head.line:SetHeight(1)
  head.line:SetPoint("LEFT", head.label, "RIGHT", 10, 0)
  head.line:SetPoint("RIGHT", head, "RIGHT", 0, 0)
  container.groupHeads[index] = head
  return head
end

local function PaintGroupHead(head, block, count)
  local label, color = BlockStyle(block)
  head.label:SetText(("%s · %d"):format(label:upper(), count))
  head.label:SetTextColor(unpack(color))
  head.line:SetColorTexture(color[1], color[2], color[3], 0.28)
end

local function RaidListSignature()
  local ids = {}
  for _, raid in ipairs(GG.Season.RAIDS or {}) do table.insert(ids, tostring(raid.instanceID)) end
  return table.concat(ids, ",")
end

local function RebuildRaidSectionsIfNeeded()
  local signature = RaidListSignature()
  if container.raidSignature == signature then return end
  container.raidSignature = signature

  container.raid:Hide()
  container.raid = BuildRaidToggle(container)
  container.difficulty:ClearAllPoints()
  container.difficulty:SetPoint("TOPLEFT", container.raid, "BOTTOMLEFT", 0, -6)

  container.bosses:Hide()
  container.bosses = BuildBossStrip(container)
  container.bosses:SetPoint("TOPLEFT", container.difficulty, "BOTTOMLEFT", 0, -14)
  container.head:ClearAllPoints()
  container.head:SetPoint("TOPLEFT", container.bosses, "BOTTOMLEFT", 0, -12)
  container.head:SetPoint("RIGHT", container, "RIGHT", -10, 0)

  local stillThere = false
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    if raid.instanceID == state.raidInstanceID then stillThere = true end
  end
  if not stillThere then state.raidInstanceID = DefaultRaidInstanceID() end
end

function GG.RaidTab:Attach(parent)
  if container then return container end
  Theme = GG.Theme

  container = CreateFrame("Frame", nil, parent)
  container:SetAllPoints(parent)
  container.rows = {}

  state.raidInstanceID = state.raidInstanceID or DefaultRaidInstanceID()

  container.raid = BuildRaidToggle(container)
  container.raid:SetPoint("TOPLEFT", 10, -10)
  container.raidSignature = RaidListSignature()

  container.difficulty = BuildDifficultyToggle(container)
  container.difficulty:SetPoint("TOPLEFT", container.raid, "BOTTOMLEFT", 0, -6)

  container.bosses = BuildBossStrip(container)
  container.bosses:SetPoint("TOPLEFT", container.difficulty, "BOTTOMLEFT", 0, -14)

  container.demoBanner = CreateFrame("Frame", nil, container, "BackdropTemplate")
  container.demoBanner:SetHeight(20)
  container.demoBanner:SetPoint("TOPLEFT", 10, -10)
  container.demoBanner:SetPoint("TOPRIGHT", -10, -10)
  container.demoBanner:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  container.demoBanner:SetBackdropColor(Theme.danger[1], Theme.danger[2], Theme.danger[3], 0.25)
  container.demoBanner.text = CreateText(container.demoBanner, 11.5, Theme.danger, true)
  container.demoBanner.text:SetPoint("CENTER")
  container.demoBanner.text:SetJustifyH("CENTER")
  container.demoBanner.text:SetText(L["RAID_TAB_DEMO_BANNER"])
  container.demoBanner:Hide()

  container.head = CreateFrame("Frame", nil, container)
  container.head:SetHeight(18)
  container.head:SetPoint("TOPLEFT", container.bosses, "BOTTOMLEFT", 0, -12)
  container.head:SetPoint("RIGHT", container, "RIGHT", -10, 0)
  container.head.name = CreateText(container.head, 10.5, Theme.textFaint)
  container.head.name:SetPoint("LEFT", 8, 0)
  container.head.name:SetWidth(COL_NAME)
  container.head.name:SetText(L["RAID_TAB_COL_CHARACTER"])
  container.head.status = CreateText(container.head, 10.5, Theme.textFaint)
  container.head.status:SetPoint("LEFT", container.head.name, "RIGHT", 14, 0)
  container.head.status:SetWidth(COL_STATUS)
  container.head.status:SetText(L["RAID_TAB_COL_STATUS"])
  container.head.bosses = CreateText(container.head, 10.5, Theme.textFaint)
  container.head.bosses:SetPoint("LEFT", container.head.status, "RIGHT", 10 + COL_DETAIL + 6, 0)
  container.head.bosses:SetText(L["RAID_TAB_COL_BOSSES"])

  container.ruleHead = CreateRule(container, false)
  container.ruleHead:SetPoint("TOPLEFT", container.head, "BOTTOMLEFT", 0, 0)
  container.ruleHead:SetPoint("RIGHT", container, "RIGHT", -10, 0)

  container.refresh = GG.Widgets.CreateButton(container, L["RAID_TAB_REFRESH"], function()
    GG.GroupLockouts:Request(true)
    GG.RaidTab:Refresh()
  end)
  container.refresh:SetPoint("TOPRIGHT", -10, -10)

  container.updated = CreateText(container, 10.5, Theme.textFaint)
  container.updated:SetPoint("TOPRIGHT", container.refresh, "BOTTOMRIGHT", 0, -8)
  container.updated:SetJustifyH("RIGHT")

  container.measure = CreateText(container, 10.5, Theme.textFaint)
  container.measure:SetAlpha(0)

  container.stats = {
    saved = BuildStat(container, "RAID_STAT_SAVED", Theme.danger, 1),
    unknown = BuildStat(container, "RAID_STAT_UNKNOWN", Amber(), 2),
    unsaved = BuildStat(container, "RAID_STAT_UNSAVED", Theme.success, 3),
  }
  container.stats.unsaved:SetPoint("TOPRIGHT", container.refresh, "TOPLEFT", -12, 0)
  container.stats.unknown:SetPoint("TOPRIGHT", container.stats.unsaved, "TOPLEFT", -8, 0)
  container.stats.saved:SetPoint("TOPRIGHT", container.stats.unknown, "TOPLEFT", -8, 0)

  container.list = CreateFrame("Frame", nil, container)
  container.list:SetPoint("TOPLEFT", container.ruleHead, "BOTTOMLEFT", 0, -4)
  container.list:SetPoint("RIGHT", container, "RIGHT", -22, 0)
  container.list:SetPoint("BOTTOM", container, "BOTTOM", 0, 10)
  container.list:SetClipsChildren(true)
  container.list:EnableMouseWheel(true)
  container.list:SetScript("OnMouseWheel", function(self, delta)
    GG.RaidTab:ScrollTo((self.offset or 0) - delta * ROW_H * 3)
  end)

  container.track = CreateFrame("Frame", nil, container)
  container.track:SetWidth(4)
  container.track:SetPoint("TOPLEFT", container.list, "TOPRIGHT", 8, 0)
  container.track:SetPoint("BOTTOMLEFT", container.list, "BOTTOMRIGHT", 8, 0)
  container.track.bg = container.track:CreateTexture(nil, "BACKGROUND")
  container.track.bg:SetAllPoints()
  container.track.bg:SetColorTexture(1, 1, 1, 0.05)

  local thumb = CreateFrame("Frame", nil, container.track)
  thumb:SetWidth(12)
  thumb.tex = thumb:CreateTexture(nil, "ARTWORK")
  thumb.tex:SetWidth(4)
  thumb.tex:SetPoint("TOP")
  thumb.tex:SetPoint("BOTTOM")
  thumb.tex:SetColorTexture(Theme.textFaint[1], Theme.textFaint[2], Theme.textFaint[3], 0.55)
  thumb:EnableMouse(true)
  thumb:SetScript("OnEnter", function(self) self.tex:SetColorTexture(unpack(Theme.accent)) end)
  thumb:SetScript("OnLeave", function(self)
    if not self.dragStart then
      self.tex:SetColorTexture(Theme.textFaint[1], Theme.textFaint[2], Theme.textFaint[3], 0.55)
    end
  end)
  thumb:SetScript("OnMouseDown", function(self)
    local _, cursorY = GetCursorPosition()
    self.dragStart, self.dragOffset = cursorY / self:GetEffectiveScale(), container.list.offset or 0
  end)
  thumb:SetScript("OnMouseUp", function(self)
    self.dragStart = nil
    if not self:IsMouseOver() then
      self.tex:SetColorTexture(Theme.textFaint[1], Theme.textFaint[2], Theme.textFaint[3], 0.55)
    end
  end)
  thumb:SetScript("OnUpdate", function(self)
    if not self.dragStart then return end
    local _, cursorY = GetCursorPosition()
    local moved = self.dragStart - cursorY / self:GetEffectiveScale()
    local trackH = container.track:GetHeight()
    local contentH = container.list.contentHeight or 0
    if trackH <= 0 then return end
    GG.RaidTab:ScrollTo(self.dragOffset + moved * contentH / trackH)
  end)
  container.track.thumb = thumb
  container.track:Hide()

  container.groupHeads = {}

  container.empty = CreateText(container, 13, Theme.textFaint)
  container.empty:SetPoint("CENTER", container, "CENTER", 0, 0)
  container.empty:SetJustifyH("CENTER")
  container.empty:SetText(L["RAID_TAB_NO_GROUP"])

  container:Hide()
  return container
end

function GG.RaidTab:SetShown(shown)
  if not container then return end
  container:SetShown(shown)
  if shown then
    if GG.GroupLockouts then GG.GroupLockouts:Request(false) end
    self:Refresh()
    C_Timer.After(0, function() GG.RaidTab:Refresh() end)
  end
end

function GG.RaidTab:Refresh()
  if not container or not container:IsShown() then return end
  RebuildRaidSectionsIfNeeded()
  PaintToggle(container.raid, state.raidInstanceID)
  PaintToggle(container.difficulty, state.difficultyID)

  local rows = GG.GroupLockouts:BuildRows(state.difficultyID, state.raidInstanceID)

  local inRaid = rows ~= nil
  local demo = GG.GroupLockouts:IsDemo()
  container.empty:SetShown(not inRaid)
  container.bosses:SetShown(inRaid)
  container.difficulty:SetShown(inRaid)
  container.raid:SetShown(inRaid)
  for _, box in pairs(container.stats) do box:SetShown(inRaid) end
  container.updated:SetShown(inRaid)
  container.refresh:SetShown(inRaid)
  container.head:SetShown(inRaid)
  container.ruleHead:SetShown(inRaid)
  container.demoBanner:SetShown(inRaid and demo)
  local top = demo and -36 or -10
  container.raid:ClearAllPoints()
  container.raid:SetPoint("TOPLEFT", 10, top)
  container.refresh:ClearAllPoints()
  container.refresh:SetPoint("TOPRIGHT", -10, top)
  if not inRaid then
    for _, row in ipairs(container.rows) do row:Hide() end
    for _, head in ipairs(container.groupHeads) do head:Hide() end
    container.track:Hide()
    return
  end

  local summary = GG.GroupLockouts:Summarize(rows)
  container.stats.saved.number:SetText(summary.saved)
  container.stats.unknown.number:SetText(summary.unknown)
  container.stats.unsaved.number:SetText(summary.unsaved)

  local kills, known = {}, 0
  for _, datum in ipairs(rows) do
    if datum.status == "saved" or datum.status == "unsaved" then
      known = known + 1
      for i = 1, datum.total or 0 do
        if datum.slots and datum.slots[i] == true then kills[i] = (kills[i] or 0) + 1 end
      end
    end
  end
  PaintBossStrip(kills, known)

  local lastUpdate = GG.GroupLockouts:LastUpdateAt()
  container.updated:SetText(lastUpdate
    and L["RAID_TAB_UPDATED"]:format(FormatAge(lastUpdate))
    or L["RAID_TAB_NEVER_UPDATED"])
  local rightColumn = math.max(container.refresh:GetWidth(), container.updated:GetStringWidth())
  container.stats.unsaved:ClearAllPoints()
  container.stats.unsaved:SetPoint("TOPRIGHT", container, "TOPRIGHT", -(10 + rightColumn + 14), top)

  local detailW, bossCount = 0, #ActiveBossNames()
  for _, datum in ipairs(rows) do
    local _, _, detail = DescribeStatus(datum)
    if detail ~= "" then
      container.measure:SetText(detail)
      detailW = math.max(detailW, container.measure:GetStringWidth())
    end
    bossCount = math.max(bossCount, datum.total or 0)
  end
  detailW = math.min(math.ceil(detailW), COL_DETAIL)
  container.detailW = detailW
  container.bossX = detailW > 0 and (detailW + 24) or 14
  container.ageX = bossCount * (BOSS_DOT + 2) + 12
  container.head.bosses:ClearAllPoints()
  container.head.bosses:SetPoint("LEFT", container.head.status, "RIGHT", container.bossX, 0)

  local blockCounts = { 0, 0, 0 }
  for _, datum in ipairs(rows) do
    local block = BlockOf(datum.status)
    blockCounts[block] = blockCounts[block] + 1
  end

  local blocks = 0
  for _, count in ipairs(blockCounts) do if count > 0 then blocks = blocks + 1 end end
  local contentH = #rows * ROW_H + blocks * GROUP_H + math.max(0, blocks - 1) * 8
  local listH = container.list:GetHeight()
  local offset = math.min(container.list.offset or 0, math.max(0, contentH - listH))
  offset = math.max(0, offset)
  container.list.offset = offset
  container.list.contentHeight = contentH

  local function Fits(top, height) return top >= -0.5 and top + height <= listH + 0.5 end

  container.blockY = {}
  local y, headIndex, lastBlock = -offset, 0, nil

  for i, datum in ipairs(rows) do
    local block = BlockOf(datum.status)
    if block ~= lastBlock then
      headIndex = headIndex + 1
      local head = EnsureGroupHead(headIndex)
      PaintGroupHead(head, block, blockCounts[block])
      local gap = lastBlock and 8 or 0
      head:ClearAllPoints()
      head:SetPoint("TOPLEFT", container.list, "TOPLEFT", 0, -(y + gap))
      head:SetPoint("RIGHT", container.list, "RIGHT", 0, 0)
      head:SetShown(Fits(y + gap, GROUP_H))
      container.blockY[block] = y + gap + offset
      y = y + gap + GROUP_H
    end
    lastBlock = block

    local row = EnsureRow(i)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", container.list, "TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", container.list, "RIGHT", 0, 0)
    PaintRow(row, datum, i)
    row:SetShown(Fits(y, ROW_H))
    y = y + ROW_H
  end

  for i = #rows + 1, #container.rows do container.rows[i]:Hide() end
  for i = headIndex + 1, #container.groupHeads do container.groupHeads[i]:Hide() end

  local track = container.track
  track:SetShown(contentH > listH + 0.5)
  if track:IsShown() then
    local trackH = track:GetHeight()
    local thumbH = math.max(24, trackH * listH / contentH)
    local travel = trackH - thumbH
    local ratio = offset / math.max(1, contentH - listH)
    track.thumb:SetHeight(thumbH)
    track.thumb:ClearAllPoints()
    track.thumb:SetPoint("TOP", track, "TOP", 0, -travel * ratio)
  end
end

function GG.RaidTab:ScrollTo(offset)
  if not container or not container.list then return end
  local max = math.max(0, (container.list.contentHeight or 0) - container.list:GetHeight())
  container.list.offset = math.min(max, math.max(0, offset))
  self:Refresh()
end

function GG.RaidTab:ScrollToBlock(block)
  local y = container and container.blockY and container.blockY[block]
  if y then self:ScrollTo(y) end
end
