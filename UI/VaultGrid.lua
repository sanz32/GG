local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.VaultGrid = {}

local ICON_SIZE = 40
local SLOT_GAP = 6
local ROW_GAP = 10
local ROW_LABEL_WIDTH = 66
local ILVL_LABEL_HEIGHT = 14

GG.VaultGrid.CONTENT_WIDTH = ROW_LABEL_WIDTH + ICON_SIZE * 3 + SLOT_GAP * 2
GG.VaultGrid.CONTENT_HEIGHT = (ICON_SIZE + ILVL_LABEL_HEIGHT + ROW_GAP) * 3 - ROW_GAP

local function ApplyBackdrop(f, bg, border)
  f:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  f:SetBackdropColor(unpack(bg))
  f:SetBackdropBorderColor(unpack(border))
end

local function CreateLabel(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and GG.Theme.fontBold or GG.Theme.font, size or 12, "")
  fs:SetTextColor(unpack(color or GG.Theme.textPrimary))
  fs:SetWordWrap(false)
  return fs
end

local tierDefs
function GG.VaultGrid:GetTierDefs()
  tierDefs = tierDefs or {
    { type = Enum.WeeklyRewardChestThresholdType.Raid, label = L["VAULT_TIER_RAID"] },
    { type = Enum.WeeklyRewardChestThresholdType.Activities, label = L["VAULT_TIER_DUNGEONS"] },
    { type = Enum.WeeklyRewardChestThresholdType.World, label = L["VAULT_TIER_WORLD"] },
  }
  return tierDefs
end

function GG.VaultGrid:DescribeSlot(slot, fallbackLabel)
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

local function DrawSlotIcon(parent, x, y, slot, tierLabel)
  local hasItem = slot and slot.itemLink
  local card = CreateFrame(hasItem and "Button" or "Frame", nil, parent, "BackdropTemplate")
  card:SetSize(ICON_SIZE, ICON_SIZE)
  card:SetPoint("TOPLEFT", x, -y)
  ApplyBackdrop(card, GG.Theme.background, hasItem and GG.Theme.ready or GG.Theme.border)

  local iconFileID
  if hasItem then
    _, _, _, _, iconFileID = C_Item.GetItemInfoInstant(slot.itemLink)
  end
  local icon = card:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 2, -2)
  icon:SetPoint("BOTTOMRIGHT", -2, 2)
  GG.Widgets.SetItemIcon(icon, iconFileID)
  if not hasItem then
    icon:SetDesaturated(true)
    icon:SetAlpha(0.35)
  end

  local ilvlLabel = CreateLabel(parent, 10, hasItem and GG.Theme.textPrimary or GG.Theme.textMuted)
  ilvlLabel:SetPoint("TOP", card, "BOTTOM", 0, -2)
  ilvlLabel:SetWidth(ICON_SIZE)
  ilvlLabel:SetJustifyH("CENTER")
  ilvlLabel:SetText(hasItem and tostring(slot.itemLevel or "?") or "-")

  card:EnableMouse(true)
  card:SetScript("OnEnter", function(self)
    if not hasItem then
      GG.Tip:Open(self, { family = "vault" }, function(t)
        t:Title(tierLabel)
        t:Text(L["TIP_PROGRESS"]:format(slot and slot.progress or 0, slot and slot.threshold or 0))
      end)
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(slot.itemLink)
    GameTooltip:AddLine(GG.VaultGrid:DescribeSlot(slot, tierLabel), unpack(GG.Theme.textMuted))
    GameTooltip:Show()
  end)
  card:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function GG.VaultGrid:Draw(parent, allSlots, x, y)
  for rowIdx, tierDef in ipairs(self:GetTierDefs()) do
    local rowY = y + (rowIdx - 1) * (ICON_SIZE + ILVL_LABEL_HEIGHT + ROW_GAP)

    local label = CreateLabel(parent, 11, GG.Theme.accent, true)
    label:SetPoint("LEFT", parent, "TOPLEFT", x, -(rowY + ICON_SIZE / 2))
    label:SetWidth(ROW_LABEL_WIDTH)
    label:SetJustifyH("LEFT")
    label:SetText(tierDef.label)

    local slots = {}
    for _, slot in ipairs(allSlots) do
      if slot.type == tierDef.type then table.insert(slots, slot) end
    end
    table.sort(slots, function(a, b) return (a.index or 0) < (b.index or 0) end)

    for col, slot in ipairs(slots) do
      local slotX = x + ROW_LABEL_WIDTH + (col - 1) * (ICON_SIZE + SLOT_GAP)
      DrawSlotIcon(parent, slotX, rowY, slot, tierDef.label)
    end
  end

  return self.CONTENT_WIDTH, self.CONTENT_HEIGHT
end

local CLAIM_ICON_SIZE = 64
local READY_CHECK_TEXTURE = "Interface\\RaidFrame\\ReadyCheck-Ready"

local function TierLabelFor(slotType)
  for _, def in ipairs(GG.VaultGrid:GetTierDefs()) do
    if def.type == slotType then return def.label end
  end
  return nil
end

local function DescribeClaim(claim)
  local tierLabel = claim.type and TierLabelFor(claim.type)
  local origin = tierLabel and GG.VaultGrid:DescribeSlot(claim, tierLabel)
  if claim.itemLink then
    local name, _, quality = C_Item.GetItemInfo(claim.itemLink)
    name = name or claim.itemLink:match("%[(.-)%]") or "?"
    quality = quality or C_Item.GetItemQualityByID(claim.itemLink)
    local r, g, b = 1, 1, 1
    if quality then r, g, b = C_Item.GetItemQualityColor(quality) end
    local iconFileID = select(5, C_Item.GetItemInfoInstant(claim.itemLink))
    local sub = origin or L["VAULT_TIER_RAID"]
    if claim.itemLevel then sub = ("%s · %s %d"):format(sub, L["VAULT_CLAIMED_ILVL"], claim.itemLevel) end
    return name, { r, g, b }, sub, iconFileID
  elseif claim.currencyID then
    local info = C_CurrencyInfo.GetCurrencyInfo(claim.currencyID)
    local name = (info and info.name) or "?"
    if (claim.quantity or 0) > 1 then name = ("%s ×%d"):format(name, claim.quantity) end
    return name, GG.Theme.textPrimary, origin or L["VAULT_CLAIMED_CURRENCY"], info and info.iconFileID
  end
  return L["VAULT_CLAIMED_UNKNOWN"], GG.Theme.textMuted, origin or "", nil
end

function GG.VaultGrid:DrawClaim(parent, claim, width, height, hideKicker)
  local success = GG.Theme.success
  local name, nameColor, sub, iconFileID = DescribeClaim(claim)

  local kicker = CreateLabel(parent, 10, success, true)
  kicker:SetPoint("TOP", parent, "TOP", 0, 0)
  kicker:SetText(hideKicker and "" or L["VAULT_CLAIMED_TITLE"]:upper())

  local glow = parent:CreateTexture(nil, "BACKGROUND")
  glow:SetSize(CLAIM_ICON_SIZE + 10, CLAIM_ICON_SIZE + 10)
  glow:SetPoint("TOP", kicker, "BOTTOM", 0, -3)
  glow:SetColorTexture(success[1], success[2], success[3], 0.14)

  local iconFrame = CreateFrame("Button", nil, parent, "BackdropTemplate")
  iconFrame:SetSize(CLAIM_ICON_SIZE, CLAIM_ICON_SIZE)
  iconFrame:SetPoint("CENTER", glow, "CENTER", 0, 0)
  iconFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
  iconFrame:SetBackdropColor(unpack(GG.Theme.background))
  iconFrame:SetBackdropBorderColor(unpack(success))

  local icon = iconFrame:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 3, -3)
  icon:SetPoint("BOTTOMRIGHT", -3, 3)
  GG.Widgets.SetItemIcon(icon, iconFileID)

  if claim.currencyID and (claim.quantity or 0) > 1 then
    local qty = iconFrame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    qty:SetPoint("BOTTOMRIGHT", -4, 4)
    qty:SetText(claim.quantity)
  end

  local check = iconFrame:CreateTexture(nil, "OVERLAY")
  check:SetSize(18, 18)
  check:SetPoint("CENTER", iconFrame, "TOPRIGHT", -1, -1)
  check:SetTexture(READY_CHECK_TEXTURE)

  iconFrame:SetScript("OnEnter", function(self)
    if not (claim.itemLink or claim.currencyID) then
      GG.Tip:Open(self, { family = "vault" }, function(t) t:Title(name) end)
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if claim.itemLink then
      GameTooltip:SetHyperlink(claim.itemLink)
    else
      GameTooltip:SetCurrencyByID(claim.currencyID, claim.quantity)
    end
    GameTooltip:Show()
  end)
  iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

  local nameText = CreateLabel(parent, 12, nameColor, true)
  nameText:SetPoint("TOP", glow, "BOTTOM", 0, -5)
  nameText:SetWidth(width)
  nameText:SetJustifyH("CENTER")
  nameText:SetWordWrap(true)
  nameText:SetMaxLines(2)
  nameText:SetText(name)

  local subText = CreateLabel(parent, 10, GG.Theme.textFaint)
  subText:SetPoint("TOP", nameText, "BOTTOM", 0, -2)
  subText:SetWidth(width)
  subText:SetJustifyH("CENTER")
  subText:SetText(sub)

  local pill = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  ApplyBackdrop(pill, { success[1], success[2], success[3], 0.14 }, success)
  local pillText = CreateLabel(pill, 10.5, success, true)
  pillText:SetPoint("CENTER")
  pillText:SetText(L["VAULT_CLAIMED_TAG"])
  pill:SetSize(pillText:GetStringWidth() + 20, 17)
  pill:SetPoint("TOP", subText, "BOTTOM", 0, -6)
  pill:SetShown(not hideKicker)

  local when = CreateLabel(parent, 10, GG.Theme.textFaint)
  if hideKicker then
    when:SetPoint("TOP", subText, "BOTTOM", 0, -6)
  else
    when:SetPoint("TOP", pill, "BOTTOM", 0, -3)
  end
  when:SetText(claim.at and date(L["VAULT_CLAIMED_AT"], claim.at) or "")

  if height then
    local total = kicker:GetStringHeight() + 3 + (CLAIM_ICON_SIZE + 10)
      + 5 + nameText:GetStringHeight() + 2 + subText:GetStringHeight()
      + (hideKicker and 6 or (6 + pill:GetHeight() + 3)) + when:GetStringHeight()
    kicker:ClearAllPoints()
    kicker:SetPoint("TOP", parent, "TOP", 0, -math.max(0, math.floor((height - total) / 2)))
  end
end

function GG.VaultGrid:DrawHint(parent, width, height, text)
  local icon = parent:CreateTexture(nil, "ARTWORK")
  icon:SetSize(46, 46)
  icon:SetAtlas("gficon-chest-evergreen-greatvault-collect")
  local msg = CreateLabel(parent, 11.5, GG.Theme.textMuted)
  msg:SetWidth(width - 10)
  msg:SetJustifyH("CENTER")
  msg:SetWordWrap(true)
  msg:SetText(text)
  icon:SetPoint("TOP", parent, "TOP", 0, -math.floor(height * 0.22))
  msg:SetPoint("TOP", icon, "BOTTOM", 0, -10)
end

function GG.VaultGrid:DrawEmptyMessage(parent, x, y, width, text)
  local msg = CreateLabel(parent, 12, GG.Theme.textMuted)
  msg:SetPoint("TOPLEFT", x, -y)
  msg:SetWidth(width or self.CONTENT_WIDTH)
  msg:SetJustifyH("LEFT")
  msg:SetWordWrap(true)
  msg:SetText(text)
  return msg:GetStringHeight()
end
