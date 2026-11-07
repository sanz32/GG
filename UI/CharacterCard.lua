local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.CharacterCard = {}

local popup
local Theme

local PADDING = 16
local TITLEBAR_HEIGHT = 74
local BOX_PAD = 10
local BOX_HEADER_HEIGHT = 18
local BOX_GAP = 12
local COLUMN_GAP = 20

local GEAR_ICON_SIZE = 34
local GEAR_ILVL_LABEL_HEIGHT = 12
local GEAR_ROW_GAP = 6
local GEAR_COL_GAP = 18
local GEAR_CONTENT_WIDTH = GEAR_ICON_SIZE * 2 + GEAR_COL_GAP
local GEAR_CONTENT_HEIGHT = 8 * (GEAR_ICON_SIZE + GEAR_ILVL_LABEL_HEIGHT + GEAR_ROW_GAP) - GEAR_ROW_GAP

local RIGHT_COLUMN_WIDTH = 300

local BOSS_ICON_SIZE = 22
local BOSS_ICON_GAP = 4
local DIFF_LABEL_WIDTH = 50

local CURRENCY_CHIP_HEIGHT = 34
local CURRENCY_CHIP_GAP = 6

local WIDTH = PADDING * 2 + BOX_PAD * 2 + GEAR_CONTENT_WIDTH + COLUMN_GAP + RIGHT_COLUMN_WIDTH

local GEAR_SLOTS_LEFT = {
  INVSLOT_HEAD, INVSLOT_NECK, INVSLOT_SHOULDER, INVSLOT_BACK,
  INVSLOT_CHEST, INVSLOT_WRIST, INVSLOT_MAINHAND, INVSLOT_OFFHAND,
}
local GEAR_SLOTS_RIGHT = {
  INVSLOT_HAND, INVSLOT_WAIST, INVSLOT_LEGS, INVSLOT_FEET,
  INVSLOT_FINGER1, INVSLOT_FINGER2, INVSLOT_TRINKET1, INVSLOT_TRINKET2,
}
local GEAR_SLOT_LABEL_KEYS = {
  [INVSLOT_HEAD] = "EQUIP_SLOT_HEAD", [INVSLOT_NECK] = "EQUIP_SLOT_NECK",
  [INVSLOT_SHOULDER] = "EQUIP_SLOT_SHOULDER", [INVSLOT_BACK] = "EQUIP_SLOT_BACK",
  [INVSLOT_CHEST] = "EQUIP_SLOT_CHEST", [INVSLOT_WRIST] = "EQUIP_SLOT_WRIST",
  [INVSLOT_MAINHAND] = "EQUIP_SLOT_MAINHAND", [INVSLOT_OFFHAND] = "EQUIP_SLOT_OFFHAND",
  [INVSLOT_HAND] = "EQUIP_SLOT_HANDS", [INVSLOT_WAIST] = "EQUIP_SLOT_WAIST",
  [INVSLOT_LEGS] = "EQUIP_SLOT_LEGS", [INVSLOT_FEET] = "EQUIP_SLOT_FEET",
  [INVSLOT_FINGER1] = "EQUIP_SLOT_FINGER1", [INVSLOT_FINGER2] = "EQUIP_SLOT_FINGER2",
  [INVSLOT_TRINKET1] = "EQUIP_SLOT_TRINKET1", [INVSLOT_TRINKET2] = "EQUIP_SLOT_TRINKET2",
}

local RAID_DIFFICULTY_DEFS = {
  [17] = { color = { 0.12, 1.00, 0.00, 1 }, labelKey = "DIFFICULTY_LFR", shortKey = "DIFFICULTY_LFR_SHORT" },
  [14] = { color = { 0.00, 0.44, 0.87, 1 }, labelKey = "DIFFICULTY_NORMAL" },
  [15] = { color = { 0.64, 0.21, 0.93, 1 }, labelKey = "DIFFICULTY_HEROIC" },
  [16] = { color = { 1.00, 0.50, 0.00, 1 }, labelKey = "DIFFICULTY_MYTHIC" },
}
local DIFFICULTY_ORDER = { 17, 14, 15, 16 }

local RAID_BOSS_ICON_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8"

local function ApplyBackdrop(f, bg, border, edgeSize)
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = edgeSize or 1,
  })
  f:SetBackdropColor(unpack(bg))
  if border then f:SetBackdropBorderColor(unpack(border)) end
end

local function CreateLabel(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size or 12, "")
  fs:SetTextColor(unpack(color or Theme.textPrimary))
  fs:SetWordWrap(false)
  fs:SetJustifyH("LEFT")
  return fs
end

local function SetTruncatedText(fontString, text, maxWidth)
  text = text or ""
  fontString:SetWidth(maxWidth)
  fontString:SetText(text)
  if fontString:GetStringWidth() <= maxWidth or #text <= 1 then return end
  local truncated = text
  while #truncated > 1 and fontString:GetStringWidth() > maxWidth do
    truncated = truncated:sub(1, -2)
    fontString:SetText(truncated .. "...")
  end
end

local function FormatIlvl(ilvl)
  ilvl = ilvl or 0
  local rounded = tonumber(("%.2f"):format(ilvl))
  if rounded == math.floor(rounded) then
    return tostring(math.floor(rounded))
  end
  return ("%.2f"):format(rounded)
end

local function DrawSectionBox(parent, x, y, width, titleText)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetPoint("TOPLEFT", x, -y)
  box:SetWidth(width)
  ApplyBackdrop(box, Theme.panel, Theme.borderSoft)

  local tick = box:CreateTexture(nil, "ARTWORK")
  tick:SetColorTexture(unpack(Theme.accent))
  tick:SetSize(3, 11)
  tick:SetPoint("TOPLEFT", BOX_PAD, -(BOX_PAD + 3))

  local label = CreateLabel(box, 11, Theme.textFaint, true)
  label:SetPoint("TOPLEFT", BOX_PAD + 8, -BOX_PAD)
  label:SetText(titleText)

  return box, BOX_PAD, BOX_PAD + BOX_HEADER_HEIGHT
end

local function DrawGearIcon(parent, x, y, slotId, itemLink)
  local frame = CreateFrame(itemLink and "Button" or "Frame", nil, parent, "BackdropTemplate")
  frame:SetSize(GEAR_ICON_SIZE, GEAR_ICON_SIZE)
  frame:SetPoint("TOPLEFT", x, -y)

  local iconFileID, borderColor
  if itemLink then
    local _, _, itemQuality = C_Item.GetItemInfo(itemLink)
    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemLink)
    iconFileID = icon
    local qc = ITEM_QUALITY_COLORS[itemQuality or 1]
    if qc then borderColor = { qc.r, qc.g, qc.b, 1 } end
  end
  ApplyBackdrop(frame, Theme.background, borderColor or Theme.borderSoft)

  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 2, -2)
  icon:SetPoint("BOTTOMRIGHT", -2, 2)
  GG.Widgets.SetItemIcon(icon, iconFileID)
  if not itemLink then
    icon:SetDesaturated(true)
    icon:SetAlpha(0.35)
  end

  local ilvlLabel = CreateLabel(parent, 10, Theme.textFaint)
  ilvlLabel:SetPoint("TOP", frame, "BOTTOM", 0, -2)
  ilvlLabel:SetWidth(GEAR_ICON_SIZE)
  ilvlLabel:SetJustifyH("CENTER")
  if itemLink then
    local ilvl = C_Item.GetDetailedItemLevelInfo(itemLink)
    ilvlLabel:SetText(ilvl and tostring(ilvl) or "?")
  else
    ilvlLabel:SetText("-")
  end

  if itemLink then
    frame:EnableMouse(true)
    frame:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetHyperlink(itemLink)
      local labelKey = GEAR_SLOT_LABEL_KEYS[slotId]
      if labelKey then
        GameTooltip:AddLine(L[labelKey], unpack(Theme.textMuted))
      end
      GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
end

local function DrawGearSection(parent, x, y, equipment)
  equipment = equipment or {}
  local rowHeight = GEAR_ICON_SIZE + GEAR_ILVL_LABEL_HEIGHT + GEAR_ROW_GAP
  for i, slotId in ipairs(GEAR_SLOTS_LEFT) do
    DrawGearIcon(parent, x, y + (i - 1) * rowHeight, slotId, equipment[slotId])
  end
  for i, slotId in ipairs(GEAR_SLOTS_RIGHT) do
    DrawGearIcon(parent, x + GEAR_ICON_SIZE + GEAR_COL_GAP, y + (i - 1) * rowHeight, slotId, equipment[slotId])
  end
  return GEAR_CONTENT_HEIGHT
end

local function IsRaidDifficultyVisible(difficultyID)
  local prefs = GGDB and GGDB.options and GGDB.options.raidDifficulties
  return not (prefs and prefs[difficultyID] == false)
end

local function BuildRaidLookup(record)
  return GG.Lockouts:BuildKilledLookup(record)
end

local function DrawBossIcon(parent, x, y, killed, color, bossName, difficultyLabel, slot, letter, instanceID, bossIndex)
  local frame = CreateFrame("Frame", nil, parent)
  frame:SetSize(BOSS_ICON_SIZE, BOSS_ICON_SIZE)
  frame:SetPoint("TOPLEFT", x, -y)

  local icon = GG.BossIcons:Create(frame)
  icon:SetSize(BOSS_ICON_SIZE, BOSS_ICON_SIZE)
  icon:SetPoint("CENTER")
  GG.BossIcons:Paint(icon, killed, color, slot, letter)

  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function(self)
    GG.Tip:Open(self, { family = "raid", color = color }, function(t)
      t:BossHead({ icon = GG.Lockouts:BossIcon(instanceID, bossIndex), title = bossName or "?",
        sub = difficultyLabel or "", dead = killed })
      t:Text(L[killed and "CARD_BOSS_KILLED" or "CARD_BOSS_NOT_KILLED"], killed and Theme.success or Theme.textMuted)
    end)
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function DrawBossesSection(parent, x, y, width, record)
  local lookup = BuildRaidLookup(record)
  local catalog = GG.Lockouts:GetRaidBossCatalog()
  local cursorY = y
  local drewAny = false

  local visibleDifficulties = {}
  for _, difficultyID in ipairs(DIFFICULTY_ORDER) do
    if IsRaidDifficultyVisible(difficultyID) then
      table.insert(visibleDifficulties, difficultyID)
    end
  end

  for _, raidDef in ipairs(GG.Season.RAIDS or {}) do
    local catalogEntry = catalog[raidDef.instanceID]
    local slotRange = GG.Lockouts:RaidSlotRange(raidDef.instanceID)
    if catalogEntry and #visibleDifficulties > 0 then
      drewAny = true
      local groupStartY = cursorY

      local nameLabel = CreateLabel(parent, 10.5, Theme.textMuted)
      nameLabel:SetPoint("TOPLEFT", x + 9, -cursorY)
      nameLabel:SetText(catalogEntry.name)
      cursorY = cursorY + 15

      for _, difficultyID in ipairs(visibleDifficulties) do
        local def = RAID_DIFFICULTY_DEFS[difficultyID]
        local difficultyLabel = def and (L[def.labelKey] or def.labelKey) or "?"
        local diffLabel = CreateLabel(parent, 10, def and def.color or Theme.textFaint, true)
        diffLabel:SetPoint("TOPLEFT", x + 9, -cursorY)
        diffLabel:SetWidth(DIFF_LABEL_WIDTH)
        diffLabel:SetText(def and def.shortKey and L[def.shortKey] or difficultyLabel)

        for i, boss in ipairs(catalogEntry.bosses) do
          local bx = x + 9 + DIFF_LABEL_WIDTH + (i - 1) * (BOSS_ICON_SIZE + BOSS_ICON_GAP)
          local killed = lookup[raidDef.instanceID .. ":" .. difficultyID .. ":" .. boss.index] == true
          DrawBossIcon(parent, bx, cursorY, killed, def and def.color or Theme.border, boss.name, difficultyLabel,
            (slotRange and slotRange.offset or 0) + i, GG.BossIcons:LetterFor(raidDef, i), raidDef.instanceID, boss.index)
        end

        cursorY = cursorY + BOSS_ICON_SIZE + 6
      end

      local rail = parent:CreateTexture(nil, "ARTWORK", nil, -1)
      rail:SetColorTexture(unpack(Theme.borderSoft))
      rail:SetPoint("TOPLEFT", x, -groupStartY)
      rail:SetSize(2, cursorY - 4 - groupStartY)

      cursorY = cursorY + 8
    end
  end

  if not drewAny then
    return GG.VaultGrid:DrawEmptyMessage(parent, x, y, width, L["RAID_PROGRESS_EMPTY"])
  end

  return cursorY - y
end

local function DrawCurrencyChip(parent, x, y, width, iconFileID, amountText, nameText, tooltipFn)
  local chip = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  chip:SetSize(width, CURRENCY_CHIP_HEIGHT)
  chip:SetPoint("TOPLEFT", x, -y)
  ApplyBackdrop(chip, Theme.background, Theme.borderSoft)

  local icon = chip:CreateTexture(nil, "ARTWORK")
  icon:SetSize(20, 20)
  icon:SetPoint("LEFT", 6, 0)
  GG.Widgets.SetItemIcon(icon, iconFileID)

  local amount = CreateLabel(chip, 11, Theme.textPrimary)
  amount:SetPoint("TOPLEFT", 30, -6)
  SetTruncatedText(amount, amountText, width - 34)

  local name = CreateLabel(chip, 9.5, Theme.textFaint)
  name:SetPoint("TOPLEFT", 30, -19)
  SetTruncatedText(name, nameText, width - 34)

  if tooltipFn then
    chip:EnableMouse(true)
    chip:SetScript("OnEnter", function(self)
      GG.Tip:Open(self, { family = "money" }, tooltipFn)
    end)
    chip:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  return chip
end

local function DrawCurrenciesSection(parent, x, y, width, record)
  local chips = {}

  if record.money then
    table.insert(chips, { icon = [[Interface\Icons\INV_Misc_Coin_01]], amount = GetMoneyString(record.money, true), name = "" })
  end

  for _, currencyID in ipairs(GG.Season.SEASON_CURRENCY_IDS or {}) do
    local c = GG.Currencies:ForDisplay(record.currencies and record.currencies[tostring(currencyID)], record)
    if c and GG.Currencies:IsVisible(GG.Currencies:CurrencyKey(currencyID)) then
      table.insert(chips, {
        icon = c.iconFileID, amount = tostring(c.quantity or 0), name = c.name or "",
        tooltip = function(t) GG.Tip.DrawCurrency(t, c, L) end,
      })
    end
  end

  if record.bounty and record.bounty.itemID and record.bounty.weekKey == GG:GetWeekKey()
    and GG.Currencies:IsVisible(GG.Currencies.BOUNTY_KEY) then
    local statusText = record.bounty.weeklyQuestClaimed and L["BOUNTY_STATUS_COMPLETED"]
      or (record.bounty.bagCount and record.bounty.bagCount > 0 and L["BOUNTY_STATUS_MAP_IN_BAG"])
      or (record.bounty.fluteBagCount and record.bounty.fluteBagCount > 0 and L["BOUNTY_STATUS_FLUTE_IN_BAG"])
      or L["BOUNTY_STATUS_NO_DATA"]
    table.insert(chips, {
      icon = record.bounty.iconFileID, amount = statusText, name = L["BOUNTY_FALLBACK_TITLE"],
      tooltip = function(t)
        t:Head({ kicker = L["TIP_BOUNTY_KICKER"], title = L["BOUNTY_FALLBACK_TITLE"] })
        t:Kv(L["BOUNTY_STATUS_LABEL"], statusText, true)
      end,
    })
  end

  if #chips == 0 then
    return GG.VaultGrid:DrawEmptyMessage(parent, x, y, width, L["CURRENCIES_EMPTY"])
  end

  local chipWidth = math.floor((width - CURRENCY_CHIP_GAP) / 2)
  for i, chip in ipairs(chips) do
    local col = (i - 1) % 2
    local row = math.floor((i - 1) / 2)
    DrawCurrencyChip(parent, x + col * (chipWidth + CURRENCY_CHIP_GAP), y + row * (CURRENCY_CHIP_HEIGHT + CURRENCY_CHIP_GAP), chipWidth, chip.icon, chip.amount, chip.name, chip.tooltip)
  end

  local rows = math.ceil(#chips / 2)
  return rows * (CURRENCY_CHIP_HEIGHT + CURRENCY_CHIP_GAP) - CURRENCY_CHIP_GAP
end

local function BuildPopup()
  Theme = GG.Theme

  popup = CreateFrame("Frame", "GGCharacterCard", UIParent, "BackdropTemplate")
  popup:SetPoint("CENTER")
  popup:SetFrameStrata("FULLSCREEN_DIALOG")
  popup:SetToplevel(true)
  popup:SetMovable(true)
  popup:EnableMouse(true)
  popup:RegisterForDrag("LeftButton")
  popup:SetScript("OnDragStart", popup.StartMoving)
  popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
  popup:SetClampedToScreen(true)
  GG.Widgets.ApplyPanel(popup, { bg = Theme.background, corners = "all" })
  tinsert(UISpecialFrames, "GGCharacterCard")

  local accentBar = popup:CreateTexture(nil, "ARTWORK")
  accentBar:SetColorTexture(unpack(Theme.accent))
  accentBar:SetPoint("TOPLEFT")
  accentBar:SetPoint("TOPRIGHT")
  accentBar:SetHeight(2)

  popup.nameText = CreateLabel(popup, 16, Theme.textPrimary, true)
  popup.nameText:SetPoint("TOPLEFT", PADDING, -14)

  popup.realmText = CreateLabel(popup, 12, Theme.textFaint)
  popup.realmText:SetPoint("LEFT", popup.nameText, "RIGHT", 6, -1)

  popup.levelText = CreateLabel(popup, 11, Theme.textMuted)
  popup.levelText:SetPoint("TOPLEFT", PADDING, -36)

  popup.liveDot = popup:CreateTexture(nil, "ARTWORK")
  popup.liveDot:SetTexture(RAID_BOSS_ICON_TEXTURE)
  popup.liveDot:SetSize(8, 8)
  popup.liveDot:SetVertexColor(unpack(Theme.success))
  popup.liveDot:SetPoint("TOPLEFT", PADDING, -54)

  popup.liveText = CreateLabel(popup, 10.5, Theme.textFaint)
  popup.liveText:SetPoint("LEFT", popup.liveDot, "RIGHT", 5, 0)
  popup.liveText:SetText(L["CARD_LIVE_LABEL"])

  popup.ilvlValue = CreateLabel(popup, 20, Theme.gold, true)
  popup.ilvlValue:SetPoint("TOPRIGHT", -40, -12)
  popup.ilvlLabel = CreateLabel(popup, 10, Theme.textFaint)
  popup.ilvlLabel:SetPoint("TOP", popup.ilvlValue, "BOTTOM", 0, -2)
  popup.ilvlLabel:SetText(L["SECTION_ILVL"])

  local close = CreateFrame("Button", nil, popup)
  close:SetSize(20, 20)
  close:SetPoint("TOPRIGHT", -8, -8)
  local closeLabel = CreateLabel(close, 16, Theme.textMuted)
  closeLabel:SetPoint("CENTER")
  closeLabel:SetText("x")
  close:SetScript("OnEnter", function() closeLabel:SetTextColor(unpack(Theme.textPrimary)) end)
  close:SetScript("OnLeave", function() closeLabel:SetTextColor(unpack(Theme.textMuted)) end)
  close:SetScript("OnClick", function() GG.CharacterCard:Close() end)

  popup.footer = CreateLabel(popup, 10, Theme.textFaint)
  popup.footer:SetJustifyH("CENTER")
  popup.footer:SetWordWrap(true)
  popup.footer:SetText(L["CARD_FOOTER_HINT"])

  popup.body = CreateFrame("Frame", nil, popup)
  popup.body:SetPoint("TOPLEFT", PADDING, -TITLEBAR_HEIGHT)
  popup.body:SetPoint("TOPRIGHT", -PADDING, -TITLEBAR_HEIGHT)
  popup.body:SetHeight(1)

  popup:Hide()
  return popup
end

local function ClearBody()
  for _, region in ipairs({ popup.body:GetRegions() }) do
    region:Hide()
    region:SetParent(nil)
  end
  for _, child in ipairs({ popup.body:GetChildren() }) do
    child:Hide()
    child:SetParent(nil)
  end
end

local activeToken = 0

local function SetHeaderIdentity(record)
  local classColor = record.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[record.class]
  popup.nameText:SetText(record.name or "?")
  popup.nameText:SetTextColor(classColor and classColor.r or Theme.textPrimary[1], classColor and classColor.g or Theme.textPrimary[2], classColor and classColor.b or Theme.textPrimary[3])
  popup.realmText:SetText(record.realm and ("- " .. record.realm) or "")
  popup.levelText:SetText(record.level and L["ROSTER_LEVEL_FORMAT"]:format(record.level) or "")
  popup.ilvlValue:SetText(record.itemLevel and FormatIlvl(record.itemLevel) or "-")
  local age = tonumber(record.dataAge)
  if age then
    local color = age > GG.Roster.STALE_AFTER_SECONDS and Theme.gold or Theme.textMuted
    local ageText = age < 3600 and L["ROSTER_LAST_UPDATE_MINUTES"]:format(math.max(1, math.floor(age / 60)))
      or age < 86400 and L["ROSTER_LAST_UPDATE_HOURS"]:format(math.floor(age / 3600))
      or L["ROSTER_LAST_UPDATE_DAYS"]:format(math.floor(age / 86400))
    popup.liveDot:SetTexture(Theme.media.clock)
    popup.liveDot:SetSize(11, 11)
    popup.liveDot:SetVertexColor(unpack(color))
    popup.liveText:SetText(L["FRESH_AGO"]:format(ageText))
    popup.liveText:SetTextColor(unpack(color))
  else
    popup.liveDot:SetTexture(RAID_BOSS_ICON_TEXTURE)
    popup.liveDot:SetSize(8, 8)
    popup.liveDot:SetVertexColor(unpack(Theme.success))
    popup.liveText:SetText(L["CARD_LIVE_LABEL"])
    popup.liveText:SetTextColor(unpack(Theme.textFaint))
  end
  popup.liveDot:Show()
  popup.liveText:Show()
end

local function ShowMessageState(text)
  ClearBody()
  popup.nameText:SetText("")
  popup.realmText:SetText("")
  popup.levelText:SetText("")
  popup.ilvlValue:SetText("")
  popup.liveDot:Hide()
  popup.liveText:Hide()
  popup.footer:Hide()

  local msg = CreateLabel(popup.body, 13, Theme.textMuted)
  msg:SetPoint("TOP", 0, 0)
  msg:SetWidth(WIDTH - PADDING * 2)
  msg:SetJustifyH("CENTER")
  msg:SetText(text)

  local bodyHeight = 60
  popup.body:SetHeight(bodyHeight)
  popup:SetSize(WIDTH, TITLEBAR_HEIGHT + bodyHeight + PADDING)
  popup:Show()
end

local function DrawRecordBody(record)
  ClearBody()
  SetHeaderIdentity(record)
  popup.footer:Show()

  local gearBox, gcx, gcy = DrawSectionBox(popup.body, 0, 0, BOX_PAD * 2 + GEAR_CONTENT_WIDTH, L["CARD_SECTION_EQUIPMENT"])
  local gearContentHeight = DrawGearSection(gearBox, gcx, gcy, record.equipment)
  gearBox:SetHeight(gcy + gearContentHeight + BOX_PAD)

  local rightX = BOX_PAD * 2 + GEAR_CONTENT_WIDTH + COLUMN_GAP
  local cursorY = 0

  local vaultBox, vcx, vcy = DrawSectionBox(popup.body, rightX, cursorY, RIGHT_COLUMN_WIDTH, L["SECTION_VAULT"])
  local vaultSlots = (GG.Vault:IsCurrentWeek(record) and record.vault.slots) or {}
  local vaultContentHeight = select(2, GG.VaultGrid:Draw(vaultBox, vaultSlots, vcx, vcy))
  vaultBox:SetHeight(vcy + vaultContentHeight + BOX_PAD)
  cursorY = cursorY + vaultBox:GetHeight() + BOX_GAP

  local bossBox, bcx, bcy = DrawSectionBox(popup.body, rightX, cursorY, RIGHT_COLUMN_WIDTH, L["SECTION_RAIDS"])
  local bossContentHeight = DrawBossesSection(bossBox, bcx, bcy, RIGHT_COLUMN_WIDTH - BOX_PAD * 2, record)
  bossBox:SetHeight(bcy + bossContentHeight + BOX_PAD)
  cursorY = cursorY + bossBox:GetHeight() + BOX_GAP

  local currencyBox, ccx, ccy = DrawSectionBox(popup.body, rightX, cursorY, RIGHT_COLUMN_WIDTH, L["SECTION_CURRENCIES"])
  local currencyContentHeight = DrawCurrenciesSection(currencyBox, ccx, ccy, RIGHT_COLUMN_WIDTH - BOX_PAD * 2, record)
  currencyBox:SetHeight(ccy + currencyContentHeight + BOX_PAD)
  cursorY = cursorY + currencyBox:GetHeight()

  local bodyHeight = math.max(gearBox:GetHeight(), cursorY)
  popup.body:SetHeight(bodyHeight)
  popup.footer:ClearAllPoints()
  popup.footer:SetPoint("TOP", popup.body, "BOTTOM", 0, -8)
  popup.footer:SetWidth(WIDTH - PADDING * 2)

  popup:SetSize(WIDTH, TITLEBAR_HEIGHT + bodyHeight + 8 + 26 + PADDING)
  popup:Show()
end

local function ShowRecordState(record)
  local myToken = activeToken
  local links = {}
  for _, link in pairs((record and record.equipment) or {}) do
    links[#links + 1] = link
  end
  for _, slot in ipairs((record and record.vault and record.vault.slots) or {}) do
    if slot and slot.itemLink then links[#links + 1] = slot.itemLink end
  end

  local drawnNow = false
  GG.Widgets.PreloadItems(links, function()
    if myToken ~= activeToken then return end
    DrawRecordBody(record)
    drawnNow = true
  end)

  if not drawnNow then
    ShowMessageState(L["CARD_LOADING"])
  end
end

function GG.CharacterCard:Close()
  activeToken = activeToken + 1
  if popup then popup:Hide() end
end

function GG.CharacterCard:RequestAndShow(characterKey, senderKey, channelHint)
  if not popup then BuildPopup() end
  activeToken = activeToken + 1
  local myToken = activeToken

  ShowMessageState(L["CARD_LOADING"])

  GG:RequestCharacterCard(characterKey, senderKey, channelHint, function(record)
    if myToken ~= activeToken then return end
    if record then
      ShowRecordState(record)
    else
      ShowMessageState(L["CARD_UNAVAILABLE"] .. "\n\n" .. L["CARD_UNAVAILABLE_DETAIL"])
    end
  end)
end
