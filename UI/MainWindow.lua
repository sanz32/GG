local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.UI = {}

local LABEL_WIDTH = 150
local COLUMN_WIDTH = 130
local ROW_HEIGHT = 22
local RAIDS_ROW_HEIGHT = 48
local RAID_ICON_GAP = 6
local HEADER_ROW_HEIGHT = 26
local TITLE_ROW_HEIGHT = 22
local SECTION_GAP = 10

local function ApplyBackdrop(f, opts)
  opts = opts or {}
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = opts.edgeSize or 1,
  })
  f:SetBackdropColor(unpack(opts.bg or GG.Theme.panel))
  f:SetBackdropBorderColor(unpack(opts.border or GG.Theme.border))
end

local function CreateLabel(parent, size, color)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(GG.Theme.font, size or 12, "")
  fs:SetTextColor(unpack(color or GG.Theme.textPrimary))
  fs:SetWordWrap(false)
  return fs
end

local frame

local function BuildFrame()
  frame = CreateFrame("Frame", "GGMainWindow", UIParent, "BackdropTemplate")
  frame:SetPoint("CENTER")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetClampedToScreen(true)

  frame:SetFrameStrata("DIALOG")
  frame:SetToplevel(true)

  tinsert(UISpecialFrames, "GGMainWindow")

  ApplyBackdrop(frame, { bg = GG.Theme.background, edgeSize = 1 })

  local accentBar = frame:CreateTexture(nil, "ARTWORK")
  accentBar:SetColorTexture(unpack(GG.Theme.accent))
  accentBar:SetPoint("TOPLEFT")
  accentBar:SetPoint("TOPRIGHT")
  accentBar:SetHeight(2)

  local title = CreateLabel(frame, 16)
  title:SetPoint("TOPLEFT", 16, -14)
  title:SetText(L["ADDON_TITLE"] or "GG")

  local rosterBtn = CreateFrame("Button", nil, frame)
  rosterBtn:SetSize(18, 18)
  rosterBtn:SetPoint("TOPRIGHT", -64, -13)
  local rosterIcon = rosterBtn:CreateTexture(nil, "ARTWORK")
  rosterIcon:SetAllPoints()
  rosterIcon:SetTexture("Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend")
  rosterBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["ROSTER_BUTTON_TOOLTIP"])
    GameTooltip:Show()
  end)
  rosterBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  rosterBtn:SetScript("OnClick", function()
    if GG.RosterUI and GG.RosterUI.Toggle then GG.RosterUI:Toggle() end
  end)

  local settings = CreateFrame("Button", nil, frame)
  settings:SetSize(18, 18)
  settings:SetPoint("TOPRIGHT", -38, -13)
  local gearIcon = settings:CreateTexture(nil, "ARTWORK")
  gearIcon:SetAllPoints()
  gearIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
  settings:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L["SETTINGS_TOOLTIP"])
    GameTooltip:Show()
  end)
  settings:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local close = CreateFrame("Button", nil, frame)
  close:SetSize(20, 20)
  close:SetPoint("TOPRIGHT", -12, -12)
  local closeLabel = CreateLabel(close, 16, GG.Theme.textMuted)
  closeLabel:SetPoint("CENTER")
  closeLabel:SetText("x")
  close:SetScript("OnEnter", function() closeLabel:SetTextColor(unpack(GG.Theme.textPrimary)) end)
  close:SetScript("OnLeave", function() closeLabel:SetTextColor(unpack(GG.Theme.textMuted)) end)
  close:SetScript("OnClick", function() frame:Hide() end)
  frame.body = CreateFrame("Frame", nil, frame)
  frame.body:SetPoint("TOPLEFT", 16, -50)
  frame.body:SetSize(1, 1)

  frame:Hide()

  return frame
end

local function ClearBody()
  for _, region in ipairs({ frame.body:GetRegions() }) do
    region:Hide()
    region:SetParent(nil)
  end
  for _, child in ipairs({ frame.body:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end
end

local function ColumnX(index)
  return LABEL_WIDTH + (index - 1) * COLUMN_WIDTH
end

local function DrawRowLabel(y, text, color)
  local label = CreateLabel(frame.body, 11, color or GG.Theme.textMuted)
  label:SetPoint("TOPLEFT", 4, -y)
  label:SetWidth(LABEL_WIDTH - 10)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  return label
end

local function DrawSectionTitle(y, text)
  local label = CreateLabel(frame.body, 12, GG.Theme.accent)
  label:SetPoint("TOPLEFT", 4, -y)
  label:SetText(text)
  return label
end

local function DrawDivider(y, width)
  local line = frame.body:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(unpack(GG.Theme.border))
  line:SetPoint("TOPLEFT", 0, -y)
  line:SetSize(math.max(width, 1), 1)
  return line
end

local function GetOwnRecords()
  local keys = {}
  for key in pairs(GGDB.ownCharacters or {}) do
    local record = GGDB.chars[key]
    if record and (record.level or 0) >= (GG.MIN_CHARACTER_LEVEL or 80) then
      table.insert(keys, key)
    end
  end

  local currentKey = GG:GetCharacterKey()
  table.sort(keys, function(a, b)
    if a == currentKey then return b ~= currentKey end
    if b == currentKey then return false end
    return a < b
  end)

  local records = {}
  for _, key in ipairs(keys) do
    local record = GGDB.chars[key]
    record.isCurrent = (key == currentKey)
    table.insert(records, record)
  end
  return records
end

local VAULT_TIER_DEFS = {
  { type = Enum.WeeklyRewardChestThresholdType.Raid, label = L["VAULT_TIER_RAID"] },
  { type = Enum.WeeklyRewardChestThresholdType.Activities, label = L["VAULT_TIER_DUNGEONS"] },
  { type = Enum.WeeklyRewardChestThresholdType.World, label = L["VAULT_TIER_WORLD"] },
}

local function DescribeSlot(slot, fallbackLabel)
  if slot.type == Enum.WeeklyRewardChestThresholdType.Raid then
    local difficultyID = GetBaseDifficultyID(slot.level)
    local difficultyName = difficultyID and GetDifficultyInfo(difficultyID)
    return difficultyName or fallbackLabel
  elseif slot.type == Enum.WeeklyRewardChestThresholdType.Activities then
    return (WEEKLY_REWARDS_MYTHIC and WEEKLY_REWARDS_MYTHIC:format(slot.level or 0)) or fallbackLabel
  elseif slot.type == Enum.WeeklyRewardChestThresholdType.World then
    return (GREAT_VAULT_WORLD_TIER and GREAT_VAULT_WORLD_TIER:format(slot.level or 0)) or fallbackLabel
  end
  return fallbackLabel
end

local RAID_DIFFICULTY_DEFS = {
  [17] = { color = { 0.12, 1.00, 0.00, 1 }, abbr = "L" },
  [14] = { color = { 0.00, 0.44, 0.87, 1 }, abbr = "N" },
  [15] = { color = { 0.64, 0.21, 0.93, 1 }, abbr = "H" },
  [16] = { color = { 1.00, 0.50, 0.00, 1 }, abbr = "M" },
}

local function ColorizeText(text, color)
  return ("|cff%02x%02x%02x%s|r"):format(
    math.floor((color[1] or 1) * 255 + 0.5),
    math.floor((color[2] or 1) * 255 + 0.5),
    math.floor((color[3] or 1) * 255 + 0.5),
    text
  )
end

local function ProgressAbbr(slot)
  if slot.type == Enum.WeeklyRewardChestThresholdType.Raid then
    local difficultyID = GetBaseDifficultyID(slot.level)
    local def = difficultyID and RAID_DIFFICULTY_DEFS[difficultyID]
    return def and ColorizeText(def.abbr, def.color) or "?"
  end
  return tostring(slot.level or 0)
end

local function IsRaidDifficultyVisible(difficultyID)
  local prefs = GGDB.options and GGDB.options.raidDifficulties
  return not (prefs and prefs[difficultyID] == false)
end

local ABBREVIATION_STOPWORDS = { ["of"] = true, ["the"] = true, ["and"] = true, ["in"] = true, ["at"] = true }

local function AbbreviateDungeonName(name)
  if not name or name == "" then return nil end
  local letters = {}
  local first = true
  for word in name:gmatch("%a[%a'-]*") do
    local isStopword = (not first) and ABBREVIATION_STOPWORDS[word:lower()]
    table.insert(letters, isStopword and word:sub(1, 1):lower() or word:sub(1, 1):upper())
    first = false
  end
  if #letters == 0 then return nil end
  return table.concat(letters)
end

local function DrawTextCell(columnIndex, y, text, color, onEnter)
  local cell = CreateFrame("Frame", nil, frame.body)
  cell:SetSize(COLUMN_WIDTH - 6, ROW_HEIGHT)
  cell:SetPoint("TOPLEFT", ColumnX(columnIndex), -y)

  local label = CreateLabel(cell, 11, color)
  label:SetPoint("LEFT", 2, 0)
  label:SetText(text)

  if onEnter then
    cell:EnableMouse(true)
    cell:SetScript("OnEnter", onEnter)
    cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  return cell
end

local function DrawCurrencyCell(columnIndex, y, entry, fallbackIconFileID, onEnter)
  if not entry then return end
  local quantity = entry.quantity or 0
  local iconFileID = (entry.iconFileID and entry.iconFileID ~= 0) and entry.iconFileID
    or fallbackIconFileID or [[Interface\Icons\INV_Misc_QuestionMark]]
  local icon = CreateSimpleTextureMarkup(iconFileID, 14, 14)
  local color = quantity == 0 and GG.Theme.textMuted or GG.Theme.textPrimary
  DrawTextCell(columnIndex, y, ("%s %d"):format(icon, quantity), color, onEnter)
end

local function DrawRaidGrid(columnIndex, y, encounters, difficultyColor, onEnter)
  local count = #encounters
  if count == 0 then return end

  local perRow = math.ceil(count / 2)
  local gap = RAID_ICON_GAP
  local available = COLUMN_WIDTH - 6
  local iconSize = math.min(
    (available - (perRow + 1) * gap) / perRow,
    (RAIDS_ROW_HEIGHT - gap * 3) / 2
  )
  iconSize = math.max(iconSize, 8)

  for idx, enc in ipairs(encounters) do
    local rowIdx = (idx <= perRow) and 0 or 1
    local colIdx = (idx <= perRow) and (idx - 1) or (idx - perRow - 1)
    local box = CreateFrame("Frame", nil, frame.body, "BackdropTemplate")
    box:SetSize(iconSize, iconSize)
    box:SetPoint("TOPLEFT",
      ColumnX(columnIndex) + gap + colIdx * (iconSize + gap),
      -(y + gap + rowIdx * (iconSize + gap)))
    ApplyBackdrop(box, {
      bg = enc.isKilled and GG.Theme.success or GG.Theme.background,
      border = difficultyColor or GG.Theme.border,
      edgeSize = 1.5,
    })
    box:EnableMouse(true)
    box:SetScript("OnEnter", onEnter)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
end

local function ShowRaidRowTooltip(anchor, difficultyName, raidGroups)
  GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
  GameTooltip:AddLine(L["RAID_PROGRESS_TITLE"])
  GameTooltip:AddLine(("%s: %s"):format(L["RAID_PROGRESS_DIFFICULTY"], difficultyName or "?"), unpack(GG.Theme.textMuted))
  for _, group in ipairs(raidGroups) do
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(group.raidName or "?", unpack(GG.Theme.accent))
    for _, enc in ipairs(group.encounters) do
      GameTooltip:AddLine(enc.bossName or "?", unpack(enc.isKilled and GG.Theme.success or GG.Theme.textMuted))
    end
  end
  GameTooltip:Show()
end

local function ShowCurrencyTooltip(anchor, currency)
  GameTooltip:SetOwner(anchor, "ANCHOR_TOP")
  GameTooltip:AddLine(currency.name or "?")
  GameTooltip:AddLine(("%s: %d"):format(L["CURRENCY_AVAILABLE"], currency.quantity or 0), unpack(GG.Theme.textPrimary))
  if currency.maxWeeklyQuantity and currency.maxWeeklyQuantity > 0 then
    GameTooltip:AddLine(("%s: %d / %d"):format(L["CURRENCY_WEEKLY"], currency.quantityEarnedThisWeek or 0, currency.maxWeeklyQuantity), unpack(GG.Theme.textMuted))
  end
  if currency.useTotalEarnedForMaxQty then
    if currency.maxQuantity and currency.maxQuantity > 0 then
      GameTooltip:AddLine(("%s: %d / %d"):format(L["CURRENCY_TOTAL"], currency.totalEarned or 0, currency.maxQuantity), unpack(GG.Theme.textMuted))
    end
  elseif currency.maxQuantity and currency.maxQuantity > 0 then
    GameTooltip:AddLine(("%s: %d / %d"):format(L["CURRENCY_CAP"], currency.quantity or 0, currency.maxQuantity), unpack(GG.Theme.textMuted))
  end
  GameTooltip:Show()
end

local function RenderTable()
  ClearBody()

  local sections = (GGDB.options and GGDB.options.sections) or {}
  local records = GetOwnRecords()
  local numColumns = #records

  if numColumns == 0 then
    local msg = CreateLabel(frame.body, 12, GG.Theme.textMuted)
    msg:SetPoint("TOPLEFT", 0, 0)
    msg:SetWidth(400)
    msg:SetJustifyH("LEFT")
    msg:SetText(L["NO_OWN_CHARACTERS"])
    frame.body:SetSize(420, 40)
    frame:SetSize(420, 140)
    return
  end

  local tableWidth = LABEL_WIDTH + numColumns * COLUMN_WIDTH
  local y = 0

  local currentColumnIndex
  for i, record in ipairs(records) do
    local header = CreateLabel(frame.body, 12, record.isCurrent and GG.Theme.accent or nil)
    header:SetPoint("TOPLEFT", ColumnX(i), -y)
    header:SetWidth(COLUMN_WIDTH - 6)
    header:SetJustifyH("LEFT")
    local nameText = ("%s-%s"):format(record.name, record.realm)
    if record.isCurrent then
      nameText = nameText .. " " .. (L["CURRENT_CHARACTER_TAG"] or "(actual)")
      currentColumnIndex = i
    end
    header:SetText(nameText)
  end
  y = y + HEADER_ROW_HEIGHT
  DrawDivider(y, tableWidth)
  y = y + SECTION_GAP

  if sections.character ~= false then
    DrawRowLabel(y, L["COL_ITEM_LEVEL"])
    for i, record in ipairs(records) do
      DrawTextCell(i, y, record.itemLevel and tostring(math.floor(record.itemLevel)) or "-")
    end
    y = y + ROW_HEIGHT

    DrawRowLabel(y, L["COL_RATING"])
    for i, record in ipairs(records) do
      local rating = record.mythicplus and record.mythicplus.rating
      DrawTextCell(i, y, rating and tostring(math.floor(rating)) or "-")
    end
    y = y + ROW_HEIGHT

    DrawRowLabel(y, L["COL_KEYSTONE"])
    for i, record in ipairs(records) do
      local keystone = record.mythicplus and record.mythicplus.keystone
      local text = "-"
      local onEnter
      if keystone then
        local abbr = AbbreviateDungeonName(keystone.dungeonName) or "?"
        text = ("%s +%d"):format(abbr, keystone.level)
        onEnter = function(self)
          GameTooltip:SetOwner(self, "ANCHOR_TOP")
          GameTooltip:AddLine(keystone.dungeonName or "?")
          GameTooltip:AddLine(("+%d"):format(keystone.level), unpack(GG.Theme.textMuted))
          GameTooltip:Show()
        end
      end
      DrawTextCell(i, y, text, nil, onEnter)
    end
    y = y + ROW_HEIGHT + SECTION_GAP / 2
    DrawDivider(y, tableWidth)
    y = y + SECTION_GAP
  end

  if sections.vault ~= false then
    DrawSectionTitle(y, L["SECTION_VAULT"])

    for i, record in ipairs(records) do
      if record.vault and record.vault.hasAvailableRewards and GG.Vault:IsCurrentWeek(record) then
        local cell = CreateFrame("Button", nil, frame.body)
        cell:SetSize(COLUMN_WIDTH - 6, TITLE_ROW_HEIGHT)
        cell:SetPoint("TOPLEFT", ColumnX(i), -y)
        local label = CreateLabel(cell, 12, GG.Theme.success)
        label:SetPoint("TOPLEFT", 2, 0)
        label:SetText(L["VAULT_REWARDS_LABEL"])
        cell:SetScript("OnClick", function() GG.UI:ShowVaultPreview(record) end)
        cell:SetScript("OnEnter", function(self)
          GameTooltip:SetOwner(self, "ANCHOR_TOP")
          GameTooltip:AddLine(L["VAULT_UNCLAIMED"])
          GameTooltip:AddLine(L["VAULT_PREVIEW_HINT"], unpack(GG.Theme.textMuted))
          GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function() GameTooltip:Hide() end)
      end
    end
    y = y + TITLE_ROW_HEIGHT

    for _, tierDef in ipairs(VAULT_TIER_DEFS) do
      DrawRowLabel(y, tierDef.label)
      for i, record in ipairs(records) do
        local slots = {}
        for _, slot in ipairs((record.vault and record.vault.slots) or {}) do
          if slot.type == tierDef.type then table.insert(slots, slot) end
        end
        table.sort(slots, function(a, b) return (a.index or 0) < (b.index or 0) end)
        local isCurrentWeek = GG.Vault:IsCurrentWeek(record)

        local parts = {}
        for _, slot in ipairs(slots) do
          local unlocked = isCurrentWeek and slot.unlocked
          table.insert(parts, unlocked and ProgressAbbr(slot) or "-")
        end

        DrawTextCell(i, y, table.concat(parts, "  "), GG.Theme.textPrimary, function(self)
          GameTooltip:SetOwner(self, "ANCHOR_TOP")
          GameTooltip:AddLine(tierDef.label)
          for _, slot in ipairs(slots) do
            local unlocked = isCurrentWeek and slot.unlocked
            GameTooltip:AddDoubleLine(
              unlocked and DescribeSlot(slot, tierDef.label) or ("%d/%d"):format(slot.progress or 0, slot.threshold or 0),
              unlocked and L["VAULT_AVAILABLE"] or L["VAULT_NO_REWARD"],
              nil, nil, nil,
              unpack(unlocked and GG.Theme.textPrimary or GG.Theme.textMuted)
            )
          end
          GameTooltip:Show()
        end)
      end
      y = y + ROW_HEIGHT
    end
    y = y + SECTION_GAP / 2
    DrawDivider(y, tableWidth)
    y = y + SECTION_GAP
  end

  if sections.dungeons ~= false then
    DrawSectionTitle(y, L["SECTION_DUNGEONS"])
    y = y + TITLE_ROW_HEIGHT
    local dungeonList = (records[1] and records[1].mythicplus and records[1].mythicplus.dungeons) or {}
    for _, dungeon in ipairs(dungeonList) do
      DrawRowLabel(y, dungeon.dungeonName or "?")
      for i, record in ipairs(records) do
        local match
        for _, d in ipairs((record.mythicplus and record.mythicplus.dungeons) or {}) do
          if d.challengeModeID == dungeon.challengeModeID then
            match = d
            break
          end
        end
        DrawTextCell(i, y, (match and match.level and match.level > 0) and ("+%d"):format(match.level) or "-")
      end
      y = y + ROW_HEIGHT
    end
    y = y + SECTION_GAP / 2
    DrawDivider(y, tableWidth)
    y = y + SECTION_GAP
  end

  if sections.raids ~= false then
    DrawSectionTitle(y, L["SECTION_RAIDS"])
    y = y + TITLE_ROW_HEIGHT

    local difficulties, seen = {}, {}
    for _, record in ipairs(records) do
      for _, instance in ipairs((record.raids and record.raids.savedInstances) or {}) do
        local difficultyID = GG.Lockouts:BaseDifficultyID(instance.difficultyID)
        if not seen[difficultyID] and IsRaidDifficultyVisible(difficultyID) then
          seen[difficultyID] = true
          local difficultyName = instance.difficultyName
          if difficultyID ~= instance.difficultyID then
            difficultyName = (GetDifficultyInfo and GetDifficultyInfo(difficultyID)) or difficultyName
          end
          table.insert(difficulties, { id = difficultyID, name = difficultyName })
        end
      end
    end
    table.sort(difficulties, function(a, b) return (a.id or 0) < (b.id or 0) end)

    for _, diff in ipairs(difficulties) do
      local difficultyColor = RAID_DIFFICULTY_DEFS[diff.id] and RAID_DIFFICULTY_DEFS[diff.id].color
      DrawRowLabel(y, diff.name or "?", difficultyColor)
      for i, record in ipairs(records) do
        local raidGroups, groupByInstance = {}, {}
        for _, instance in ipairs((record.raids and record.raids.savedInstances) or {}) do
          if GG.Lockouts:BaseDifficultyID(instance.difficultyID) == diff.id then
            local group = groupByInstance[instance.instanceID]
            if not group then
              group = { raidName = instance.name, encounters = {} }
              groupByInstance[instance.instanceID] = group
              table.insert(raidGroups, group)
            end
            for _, enc in ipairs(instance.encounters or {}) do
              table.insert(group.encounters, enc)
            end
          end
        end

        local encounters = {}
        for _, group in ipairs(raidGroups) do
          for _, enc in ipairs(group.encounters) do
            table.insert(encounters, enc)
          end
        end

        DrawRaidGrid(i, y, encounters, difficultyColor, function(self)
          ShowRaidRowTooltip(self, diff.name, raidGroups)
        end)
      end
      y = y + RAIDS_ROW_HEIGHT
    end
    y = y + SECTION_GAP / 2
    DrawDivider(y, tableWidth)
    y = y + SECTION_GAP
  end

  if sections.currencies ~= false then
    DrawSectionTitle(y, L["SECTION_CURRENCIES"])
    y = y + TITLE_ROW_HEIGHT

    for _, currencyID in ipairs(GG.Season.SEASON_CURRENCY_IDS) do
      local anyName, anyIconFileID
      local visible = GG.Currencies:IsVisible(GG.Currencies:CurrencyKey(currencyID))
      for _, record in ipairs(records) do
        local c = visible and record.currencies and record.currencies[tostring(currencyID)]
        if c then
          anyName = anyName or c.name
          if c.iconFileID and c.iconFileID ~= 0 then anyIconFileID = anyIconFileID or c.iconFileID end
        end
      end
      if anyName then
        DrawRowLabel(y, anyName)
        for i, record in ipairs(records) do
          local currency = record.currencies and record.currencies[tostring(currencyID)]
          DrawCurrencyCell(i, y, currency, anyIconFileID, function(self) ShowCurrencyTooltip(self, currency) end)
        end
        y = y + ROW_HEIGHT
      end
    end

    for _, itemID in ipairs(GG.Season.SEASON_ITEM_IDS or {}) do
      local anyName, anyIconFileID
      local visible = GG.Currencies:IsVisible(GG.Currencies:ItemKey(itemID))
      for _, record in ipairs(records) do
        local it = visible and record.items and record.items[tostring(itemID)]
        if it then
          anyName = anyName or it.name
          if it.iconFileID and it.iconFileID ~= 0 then anyIconFileID = anyIconFileID or it.iconFileID end
        end
      end
      if anyName then
        DrawRowLabel(y, anyName)
        for i, record in ipairs(records) do
          local item = record.items and record.items[tostring(itemID)]
          DrawCurrencyCell(i, y, item, anyIconFileID, function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(item.name or "?")
            GameTooltip:AddLine(("%s: %d"):format(L["CURRENCY_AVAILABLE"], item.quantity or 0), unpack(GG.Theme.textPrimary))
            GameTooltip:Show()
          end)
        end
        y = y + ROW_HEIGHT
      end
    end
  end

  if currentColumnIndex then
    local highlight = frame.body:CreateTexture(nil, "BACKGROUND")
    highlight:SetColorTexture(GG.Theme.accent[1], GG.Theme.accent[2], GG.Theme.accent[3], 0.08)
    highlight:SetPoint("TOPLEFT", ColumnX(currentColumnIndex) - 4, 0)
    highlight:SetSize(COLUMN_WIDTH, y)
  end

  for i = 2, numColumns do
    local vline = frame.body:CreateTexture(nil, "ARTWORK")
    vline:SetColorTexture(unpack(GG.Theme.border))
    vline:SetPoint("TOPLEFT", ColumnX(i) - 8, 0)
    vline:SetSize(1, y)
  end

  frame.body:SetSize(tableWidth, y + 10)
  frame:SetWidth(math.min(tableWidth + 32, UIParent:GetWidth() - 100))
  frame:SetHeight(math.min(y + 90, UIParent:GetHeight() - 100))
end

function GG.UI:Toggle()
  if not frame then
    BuildFrame()
    frame:SetScale((GGDB.options and GGDB.options.windowScale) or 1.0)
  end

  if frame:IsShown() then
    frame:Hide()
  else
    RenderTable()
    frame:Show()
  end
end

function GG.UI:Refresh()
  if frame and frame:IsShown() then
    RenderTable()
  end
end

function GG.UI:ApplyScale(scale)
  if frame then
    frame:SetScale(scale or 1.0)
  end
end
