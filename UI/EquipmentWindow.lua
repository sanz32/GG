local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

local popup
local Theme

local CARD_WIDTH = 320
local CARD_HEIGHT = 86
local CARD_GAP = 10
local COLUMN_GAP = 20
local ICON_SIZE = 40
local PADDING = 16
local TITLEBAR_HEIGHT = 34
local WIDTH = PADDING * 2 + CARD_WIDTH * 2 + COLUMN_GAP

local GREEN_ENCHANT = { 0.30, 0.90, 0.35, 1 }
local RED_MISSING = { 1, 0.42, 0.42, 1 }

local LEFT_SLOTS = {
  { id = INVSLOT_HEAD,     labelKey = "EQUIP_SLOT_HEAD",     canEnchant = true },
  { id = INVSLOT_NECK,     labelKey = "EQUIP_SLOT_NECK",     canEnchant = false },
  { id = INVSLOT_SHOULDER, labelKey = "EQUIP_SLOT_SHOULDER", canEnchant = true },
  { id = INVSLOT_BACK,     labelKey = "EQUIP_SLOT_BACK",     canEnchant = false },
  { id = INVSLOT_CHEST,    labelKey = "EQUIP_SLOT_CHEST",    canEnchant = true },
  { id = INVSLOT_WRIST,    labelKey = "EQUIP_SLOT_WRIST",    canEnchant = false },
  { id = INVSLOT_MAINHAND, labelKey = "EQUIP_SLOT_MAINHAND", canEnchant = true },
  { id = INVSLOT_OFFHAND,  labelKey = "EQUIP_SLOT_OFFHAND",  canEnchant = true, weaponOnly = true },
}

local NON_ENCHANTABLE_EQUIP_LOCS = {
  INVTYPE_SHIELD = true,
  INVTYPE_HOLDABLE = true,
}
local RIGHT_SLOTS = {
  { id = INVSLOT_HAND,     labelKey = "EQUIP_SLOT_HANDS",    canEnchant = false },
  { id = INVSLOT_WAIST,    labelKey = "EQUIP_SLOT_WAIST",    canEnchant = false },
  { id = INVSLOT_LEGS,     labelKey = "EQUIP_SLOT_LEGS",     canEnchant = true },
  { id = INVSLOT_FEET,     labelKey = "EQUIP_SLOT_FEET",     canEnchant = true },
  { id = INVSLOT_FINGER1,  labelKey = "EQUIP_SLOT_FINGER1",  canEnchant = true },
  { id = INVSLOT_FINGER2,  labelKey = "EQUIP_SLOT_FINGER2",  canEnchant = true },
  { id = INVSLOT_TRINKET1, labelKey = "EQUIP_SLOT_TRINKET1", canEnchant = false },
  { id = INVSLOT_TRINKET2, labelKey = "EQUIP_SLOT_TRINKET2", canEnchant = false },
}

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

local function ScanItemDetails(itemLink)
  local details = { enchantText = nil, gems = {} }
  local tooltipData = C_TooltipInfo.GetHyperlink(itemLink)
  if not tooltipData or not tooltipData.lines then return details end

  for _, line in ipairs(tooltipData.lines) do
    if line.type == Enum.TooltipDataLineType.ItemEnchantmentPermanent then
      local value = ENCHANTED_TOOLTIP_LINE and line.leftText
        and line.leftText:match(ENCHANTED_TOOLTIP_LINE:gsub("%%s", "(.*)"))
      details.enchantText = value or line.leftText
    elseif line.type == Enum.TooltipDataLineType.GemSocket then
      table.insert(details.gems, { icon = line.gemIcon, filled = line.gemIcon ~= nil })
    end
  end

  return details
end

local function GetUpgradeText(itemLink)
  local info = C_Item.GetItemUpgradeInfo(itemLink)
  if not info or not info.trackString or not info.maxLevel or info.maxLevel <= 0 then
    return nil
  end
  return ("%s %d/%d"):format(info.trackString, info.currentLevel or 0, info.maxLevel), (info.currentLevel or 0) >= info.maxLevel
end

local function DrawSlotCard(parent, x, y, slotDef, itemLink)
  local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
  card:SetSize(CARD_WIDTH, CARD_HEIGHT)
  card:SetPoint("TOPLEFT", x, -y)
  ApplyBackdrop(card, Theme.panel, Theme.borderSoft)

  local iconFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
  iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
  iconFrame:SetPoint("LEFT", 8, 0)

  local icon = iconFrame:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 2, -2)
  icon:SetPoint("BOTTOMRIGHT", -2, 2)

  local textLeft = 8 + ICON_SIZE + 10
  local textWidth = CARD_WIDTH - textLeft - 10

  local nameText = CreateLabel(card, 12, Theme.textPrimary)
  nameText:SetPoint("TOPLEFT", textLeft, -8)

  local slotText = CreateLabel(card, 11, Theme.textFaint)
  slotText:SetPoint("TOPLEFT", textLeft, -28)
  slotText:SetText(L[slotDef.labelKey] or slotDef.labelKey)

  local ilvlText = CreateLabel(card, 10.5, { 0.64, 0.21, 0.93, 1 })
  ilvlText:SetPoint("TOPRIGHT", -8, -28)

  local upgradeText = CreateLabel(card, 11.5, Theme.textMuted)
  upgradeText:SetPoint("TOPLEFT", textLeft, -47)
  upgradeText:SetWidth(textWidth)

  local enchantText = CreateLabel(card, 11.5, GREEN_ENCHANT)
  enchantText:SetPoint("TOPLEFT", textLeft, -65)
  enchantText:SetWidth(textWidth)

  local gemRow = CreateFrame("Frame", nil, card)
  gemRow:SetPoint("TOPRIGHT", -8, -47)
  gemRow:SetSize(90, 14)

  if not itemLink then
    GG.Widgets.SetItemIcon(icon, nil)
    icon:SetDesaturated(true)
    icon:SetAlpha(0.4)
    SetTruncatedText(nameText, L["EQUIP_SLOT_EMPTY"], textWidth)
    nameText:SetTextColor(unpack(Theme.textFaint))
    return card
  end

  local itemName, _, itemQuality = C_Item.GetItemInfo(itemLink)
  local _, _, _, itemEquipLoc, iconFileID = C_Item.GetItemInfoInstant(itemLink)
  GG.Widgets.SetItemIcon(icon, iconFileID)

  local qualityColor = ITEM_QUALITY_COLORS[itemQuality or 1]
  SetTruncatedText(nameText, itemName or itemLink, textWidth)
  if qualityColor then
    nameText:SetTextColor(qualityColor.r, qualityColor.g, qualityColor.b)
  end
  ApplyBackdrop(iconFrame, Theme.background, qualityColor and { qualityColor.r, qualityColor.g, qualityColor.b, 1 } or Theme.borderSoft)

  local actualItemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
  ilvlText:SetText(tostring(actualItemLevel or "?"))

  local upgrade, upgradeMaxed = GetUpgradeText(itemLink)
  upgradeText:SetText(upgrade or "")
  upgradeText:SetTextColor(unpack(upgradeMaxed and Theme.success or Theme.textMuted))

  local details = ScanItemDetails(itemLink)

  local canEnchant = slotDef.canEnchant
    and not (slotDef.weaponOnly and NON_ENCHANTABLE_EQUIP_LOCS[itemEquipLoc])
  if canEnchant then
    if details.enchantText then
      enchantText:SetTextColor(unpack(GREEN_ENCHANT))
      SetTruncatedText(enchantText, details.enchantText, textWidth)
    else
      enchantText:SetTextColor(unpack(RED_MISSING))
      enchantText:SetText(L["EQUIP_MISSING"])
    end
  end

  if #details.gems > 0 then
    local gx = 0
    for _, gem in ipairs(details.gems) do
      if gem.filled then
        local gemIcon = gemRow:CreateTexture(nil, "ARTWORK")
        gemIcon:SetSize(14, 14)
        gemIcon:SetPoint("LEFT", gx, 0)
        GG.Widgets.SetItemIcon(gemIcon, gem.icon)
        gx = gx + 16
      else
        local missing = CreateLabel(gemRow, 9.5, RED_MISSING)
        missing:SetPoint("LEFT", gx, 0)
        missing:SetText(L["EQUIP_MISSING"])
        gx = gx + missing:GetStringWidth() + 8
      end
    end
  end

  card:EnableMouse(true)
  card:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(itemLink)
    GameTooltip:Show()
  end)
  card:SetScript("OnLeave", function() GameTooltip:Hide() end)

  return card
end

local function BuildPopup()
  Theme = GG.Theme

  popup = CreateFrame("Frame", "GGEquipmentWindow", UIParent, "BackdropTemplate")
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
  tinsert(UISpecialFrames, "GGEquipmentWindow")

  local accentBar = popup:CreateTexture(nil, "ARTWORK")
  accentBar:SetColorTexture(unpack(Theme.accent))
  accentBar:SetPoint("TOPLEFT")
  accentBar:SetPoint("TOPRIGHT")
  accentBar:SetHeight(2)

  popup.title = CreateLabel(popup, 14, Theme.textPrimary, true)
  popup.title:SetPoint("TOPLEFT", PADDING, -12)
  popup.title:SetWidth(WIDTH - 100)

  popup.ilvlBadge = CreateLabel(popup, 13, { 0.64, 0.21, 0.93, 1 })
  popup.ilvlBadge:SetPoint("TOPRIGHT", -36, -13)

  local close = CreateFrame("Button", nil, popup)
  close:SetSize(20, 20)
  close:SetPoint("TOPRIGHT", -8, -8)
  local closeLabel = CreateLabel(close, 16, Theme.textMuted)
  closeLabel:SetPoint("CENTER")
  closeLabel:SetText("x")
  close:SetScript("OnEnter", function() closeLabel:SetTextColor(unpack(Theme.textPrimary)) end)
  close:SetScript("OnLeave", function() closeLabel:SetTextColor(unpack(Theme.textMuted)) end)
  close:SetScript("OnClick", function() popup:Hide() end)
  popup.body = CreateFrame("Frame", nil, popup)
  popup.body:SetPoint("TOPLEFT", PADDING, -TITLEBAR_HEIGHT)
  popup.body:SetPoint("TOPRIGHT", -PADDING, -TITLEBAR_HEIGHT)
  popup.body:SetHeight(1)

  popup:Hide()
  return popup
end

local equipGeneration = 0

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

function GG.UI:ShowEquipmentWindow(record)
  if not popup then BuildPopup() end
  ClearBody()

  local classColor = record.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[record.class]
  if classColor then
    popup.title:SetTextColor(classColor.r, classColor.g, classColor.b)
  else
    popup.title:SetTextColor(unpack(Theme.textPrimary))
  end
  popup.title:SetText(("%s  (%s)"):format(record.name or "?", record.realm or "?"))
  popup.ilvlBadge:SetText(record.itemLevel and FormatIlvl(record.itemLevel) or "")

  if type(record.equipment) ~= "table" then
    local msg = CreateLabel(popup.body, 12, Theme.textMuted)
    msg:SetPoint("TOPLEFT", 0, 0)
    msg:SetWidth(WIDTH - PADDING * 2)
    msg:SetWordWrap(true)
    msg:SetText(L["EQUIP_NO_DATA"])
    popup.body:SetHeight(40)
    popup:SetSize(WIDTH, TITLEBAR_HEIGHT + 40 + PADDING)
    popup:Show()
    return
  end

  local links = {}
  for _, slotDef in ipairs(LEFT_SLOTS) do links[#links + 1] = record.equipment[slotDef.id] end
  for _, slotDef in ipairs(RIGHT_SLOTS) do links[#links + 1] = record.equipment[slotDef.id] end

  equipGeneration = equipGeneration + 1
  local myGeneration = equipGeneration
  local drawnNow = false

  local function DrawAll()
    if myGeneration ~= equipGeneration or not popup then return end
    ClearBody()
    for i, slotDef in ipairs(LEFT_SLOTS) do
      DrawSlotCard(popup.body, 0, (i - 1) * (CARD_HEIGHT + CARD_GAP), slotDef, record.equipment[slotDef.id])
    end
    for i, slotDef in ipairs(RIGHT_SLOTS) do
      DrawSlotCard(popup.body, CARD_WIDTH + COLUMN_GAP, (i - 1) * (CARD_HEIGHT + CARD_GAP), slotDef, record.equipment[slotDef.id])
    end

    local bodyHeight = math.max(#LEFT_SLOTS, #RIGHT_SLOTS) * (CARD_HEIGHT + CARD_GAP) - CARD_GAP
    popup.body:SetHeight(bodyHeight)
    popup:SetSize(WIDTH, TITLEBAR_HEIGHT + bodyHeight + PADDING)
    popup:Show()
    drawnNow = true
  end

  GG.Widgets.PreloadItems(links, DrawAll)

  if not drawnNow then
    local msg = CreateLabel(popup.body, 12, Theme.textMuted)
    msg:SetPoint("TOPLEFT", 0, 0)
    msg:SetWidth(WIDTH - PADDING * 2)
    msg:SetText(L["EQUIP_LOADING"])
    popup.body:SetHeight(40)
    popup:SetSize(WIDTH, TITLEBAR_HEIGHT + 40 + PADDING)
    popup:Show()
  end
end
