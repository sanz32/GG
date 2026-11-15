local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

local popup
local Theme

local SIDE_W = 272
local CARD_H = 62
local CARD_GAP = 7
local CENTER_W = 660
local COL_GAP = 18
local ICON_SIZE = 36
local ICON_TOP = 6
local PADDING = 16
local TITLEBAR_HEIGHT = 44
local WIDTH = PADDING * 2 + SIDE_W * 2 + CENTER_W + COL_GAP * 2

local RED_MISSING = { 1, 0.42, 0.42, 1 }
local ENCHANT_GREEN = { 0.365, 0.780, 0.490, 1 }
local AMBER_FIX = { 1.00, 0.780, 0.300, 1 }
local KIND_COLORS = { replace = RED_MISSING, fix = AMBER_FIX }
local ILVL_GOLD = { 0.910, 0.722, 0.361, 1 }

local TRACK_COLORS = {
  myth = { 1.00, 0.60, 0.20, 1 }, hero = { 0.70, 0.45, 1.00, 1 }, champion = { 0.25, 0.60, 1.00, 1 },
  veteran = { 0.30, 0.85, 0.35, 1 }, adventurer = { 0.75, 0.75, 0.78, 1 }, explorer = { 0.60, 0.60, 0.64, 1 },
  crafted = { 0.208, 0.816, 0.729, 1 }, other = { 0.55, 0.57, 0.63, 1 },
}

local LEFT_SLOTS = {
  { id = INVSLOT_HEAD,     labelKey = "EQUIP_SLOT_HEAD",     canEnchant = true },
  { id = INVSLOT_NECK,     labelKey = "EQUIP_SLOT_NECK",     canEnchant = false },
  { id = INVSLOT_SHOULDER, labelKey = "EQUIP_SLOT_SHOULDER", canEnchant = true },
  { id = INVSLOT_BACK,     labelKey = "EQUIP_SLOT_BACK",     canEnchant = false },
  { id = INVSLOT_CHEST,    labelKey = "EQUIP_SLOT_CHEST",    canEnchant = true },
  { id = INVSLOT_WRIST,    labelKey = "EQUIP_SLOT_WRIST",    canEnchant = false },
}
local RIGHT_SLOTS = {
  { id = INVSLOT_HAND,     labelKey = "EQUIP_SLOT_HANDS",    canEnchant = false },
  { id = INVSLOT_WAIST,    labelKey = "EQUIP_SLOT_WAIST",    canEnchant = false },
  { id = INVSLOT_LEGS,     labelKey = "EQUIP_SLOT_LEGS",     canEnchant = true },
  { id = INVSLOT_FEET,     labelKey = "EQUIP_SLOT_FEET",     canEnchant = true },
  { id = INVSLOT_FINGER1,  labelKey = "EQUIP_SLOT_FINGER1",  canEnchant = true },
  { id = INVSLOT_FINGER2,  labelKey = "EQUIP_SLOT_FINGER2",  canEnchant = true },
}
local BOTTOM_SLOTS = {
  { id = INVSLOT_MAINHAND, labelKey = "EQUIP_SLOT_MAINHAND", canEnchant = true },
  { id = INVSLOT_OFFHAND,  labelKey = "EQUIP_SLOT_OFFHAND",  canEnchant = true, weaponOnly = true },
  { id = INVSLOT_TRINKET1, labelKey = "EQUIP_SLOT_TRINKET1", canEnchant = false },
  { id = INVSLOT_TRINKET2, labelKey = "EQUIP_SLOT_TRINKET2", canEnchant = false },
}

local NON_ENCHANTABLE_EQUIP_LOCS = {
  INVTYPE_SHIELD = true,
  INVTYPE_HOLDABLE = true,
}

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

local function Hex(c)
  return ("%02x%02x%02x"):format(math.floor(c[1] * 255), math.floor(c[2] * 255), math.floor(c[3] * 255))
end

local function ScanItemDetails(itemLink)
  local details = { enchantText = nil, gems = {} }
  local tooltipData = C_TooltipInfo and C_TooltipInfo.GetHyperlink(itemLink)
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

local function ReadItem(slotDef, itemLink)
  local item = { slot = L[slotDef.labelKey] or slotDef.labelKey, slotDef = slotDef, link = itemLink }
  if not itemLink then return item end
  local name, _, quality = C_Item.GetItemInfo(itemLink)
  local _, _, _, equipLoc, iconFileID = C_Item.GetItemInfoInstant(itemLink)
  item.name, item.quality, item.icon = name, quality, iconFileID
  item.ilvl = C_Item.GetDetailedItemLevelInfo(itemLink) or 0
  local info = C_Item.GetItemUpgradeInfo and C_Item.GetItemUpgradeInfo(itemLink)
  if info and info.trackString and info.maxLevel and info.maxLevel > 0 then
    item.trackString, item.cur, item.max = info.trackString, info.currentLevel or 0, info.maxLevel
    item.trackKey = GG.GearDiagnosis.TrackKey(info.trackString)
  end
  if C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
    local ok, craftedQuality = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, itemLink)
    item.crafted = ok and craftedQuality ~= nil and craftedQuality > 0 and not item.max
  end
  local details = ScanItemDetails(itemLink)
  item.canEnchant = slotDef.canEnchant and not (slotDef.weaponOnly and NON_ENCHANTABLE_EQUIP_LOCS[equipLoc]) or false
  item.enchanted = details.enchantText ~= nil
  item.enchantText = details.enchantText
  item.gems, item.gemsFilled, item.gemList = #details.gems, 0, details.gems
  for _, g in ipairs(details.gems) do if g.filled then item.gemsFilled = item.gemsFilled + 1 end end
  return item
end

local CRAFT_WORDS = { "craft", "fabric", "artesan", "forj" }
local function CraftedCap()
  local cap, cap2
  local ids = GG.Season and GG.Season.SEASON_CURRENCY_IDS or {}
  for i = 1, 5 do
    local info = ids[i] and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
      and C_CurrencyInfo.GetCurrencyInfo(ids[i])
    local desc = info and type(info.description) == "string" and info.description or ""
    desc = desc:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local ranges = 0
    for _, hi in (desc:gsub("–", "-")):gmatch("%f[%d](%d%d%d)%s*%-%s*(%d%d%d)%f[%D]") do
      ranges = ranges + 1
      hi = tonumber(hi)
      if ranges == 2 and hi and (not cap2 or hi > cap2) then cap2 = hi end
    end
    for sentence in desc:gmatch("[^%.\n]+") do
      local lower = sentence:lower()
      local at
      for _, w in ipairs(CRAFT_WORDS) do
        local p = lower:find(w, 1, true)
        if p and (not at or p < at) then at = p end
      end
      if at then
        for n in (" " .. sentence:sub(at)):gmatch("%f[%d]%d%d%d%f[%D]") do
          n = tonumber(n)
          if n and n >= 100 and (not cap or n > cap) then cap = n end
        end
      end
    end
  end
  return cap or cap2 or (GG.Season and GG.Season.CRAFTED_MAX_ILVL)
end

local function DrawSlotCard(parent, x, y, item, mirror, low, kind)
  local card = CreateFrame("Button", nil, parent)
  card:SetSize(SIDE_W, CARD_H)
  card:SetPoint("TOPLEFT", x, -y)
  card.item = item
  local markColor = KIND_COLORS[kind]
  if markColor then
    local edgeBox = CreateFrame("Frame", nil, card)
    edgeBox:SetPoint("TOPLEFT", -1, 1)
    edgeBox:SetPoint("BOTTOMRIGHT", 1, -1)
    local edge = GG.Widgets.RoundedFill(card, edgeBox, 8, "BACKGROUND", -2)
    edge:SetColor(markColor[1], markColor[2], markColor[3], 0.55)
  end
  local hlBox = CreateFrame("Frame", nil, card)
  hlBox:SetPoint("TOPLEFT", -2, 2)
  hlBox:SetPoint("BOTTOMRIGHT", 2, -2)
  card.hl = GG.Widgets.RoundedFill(card, hlBox, 9, "BACKGROUND", -1)
  card.hl:Hide()
  local dimBox = CreateFrame("Frame", nil, card)
  dimBox:SetPoint("TOPLEFT", -1, 1)
  dimBox:SetPoint("BOTTOMRIGHT", 1, -1)
  dimBox:SetFrameLevel(card:GetFrameLevel() + 10)
  card.dim = GG.Widgets.RoundedFill(dimBox, dimBox, 8, "OVERLAY")
  local bgc = Theme.background
  card.dim:SetColor(bgc[1], bgc[2], bgc[3], 0.72)
  card.dim:Hide()
  local bg = GG.Widgets.RoundedFill(card, card, 7, "BACKGROUND")
  bg:SetColor(Theme.level1)

  local iconBox = CreateFrame("Frame", nil, card)
  iconBox:SetSize(ICON_SIZE, ICON_SIZE)
  iconBox:SetPoint(mirror and "TOPRIGHT" or "TOPLEFT", mirror and -8 or 8, -ICON_TOP)
  local ring = GG.Widgets.RoundedFill(iconBox, iconBox, 6, "BACKGROUND")
  local icon = iconBox:CreateTexture(nil, "ARTWORK")
  icon:SetPoint("TOPLEFT", 2, -2)
  icon:SetPoint("BOTTOMRIGHT", -2, 2)
  local mask = iconBox:CreateMaskTexture()
  mask:SetTexture(Theme.media.roundMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(icon)
  icon:AddMaskTexture(mask)

  local ilvlText = CreateLabel(card, 13, low and RED_MISSING or Theme.textPrimary, true)
  ilvlText:SetJustifyH("CENTER")
  ilvlText:SetPoint("TOP", iconBox, "BOTTOM", 0, -2)
  local textX = 8 + ICON_SIZE + 10
  local textW = SIDE_W - textX - 10
  local name = CreateLabel(card, 12, Theme.textPrimary, true)
  local sub = CreateLabel(card, 11, Theme.textFaint)
  local gemsLine = CreateLabel(card, 11, Theme.textFaint)
  local enchLine = CreateLabel(card, 11, ENCHANT_GREEN)
  local side = mirror and "RIGHT" or "LEFT"
  local dir = mirror and -1 or 1
  for _, fs in ipairs({ name, sub, enchLine }) do fs:SetJustifyH(side) end
  local hasThird = item.link and (item.canEnchant or (item.gems or 0) > 0)
  local edgeY = hasThird and 9 or 16
  name:SetPoint("TOP" .. side, dir * textX, -edgeY)
  if hasThird then
    sub:SetPoint(side, card, side, dir * textX, 0)
    gemsLine:SetPoint("BOTTOM" .. side, dir * textX, edgeY)
  else
    sub:SetPoint("BOTTOM" .. side, dir * textX, edgeY)
  end

  if not item.link then
    GG.Widgets.SetItemIcon(icon, nil)
    icon:SetDesaturated(true)
    icon:SetAlpha(0.4)
    ring:SetColor(Theme.borderSoft)
    SetTruncatedText(name, L["EQUIP_SLOT_EMPTY"], textW)
    name:SetTextColor(unpack(Theme.textFaint))
    sub:SetText(item.slot)
    return card
  end

  GG.Widgets.SetItemIcon(icon, item.icon)
  local qc = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.quality or 1]
  ring:SetColor(qc and qc.r or 0.5, qc and qc.g or 0.5, qc and qc.b or 0.5, 1)
  SetTruncatedText(name, item.name or item.link, textW)
  if qc then name:SetTextColor(qc.r, qc.g, qc.b) end
  ilvlText:SetText(tostring(item.ilvl or "?"))
  if kind == "upgrade" then
    local arrow = card:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\Buttons\\Arrow-Up-Up")
    arrow:SetSize(12, 12)
    arrow:SetVertexColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], 1)
    arrow:SetPoint("LEFT", ilvlText, "RIGHT", 0, 1)
    ilvlText:SetTextColor(unpack(Theme.accent))
  end

  local parts = { item.slot }
  local key = item.crafted and "crafted" or item.trackKey or "other"
  local trackLabel = item.crafted and L["EQUIP_TRACK_CRAFTED"]
    or (item.trackString and ("%s %d/%d"):format(item.trackString, item.cur or 0, item.max or 0))
  if trackLabel then parts[#parts + 1] = "|cff" .. Hex(TRACK_COLORS[key] or TRACK_COLORS.other) .. trackLabel .. "|r" end
  sub:SetText(table.concat(parts, " · "))

  local gems = {}
  for _, g in ipairs(item.gemList or {}) do
    gems[#gems + 1] = g.filled and ("|T" .. g.icon .. ":14:14:0:0:64:64:5:59:5:59|t")
      or "|TInterface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic:14:14|t"
  end
  gemsLine:SetText(table.concat(gems, " "))
  local fullW = SIDE_W - textX - 10
  local gemsW = 0
  if #gems > 0 then
    gemsW = gemsLine:GetStringWidth()
    if not gemsW or gemsW <= 0 then gemsW = #gems * 18 end
    enchLine:SetPoint(side, gemsLine, mirror and "LEFT" or "RIGHT", dir * 6, 0)
    gemsW = gemsW + 6
  else
    enchLine:SetPoint("BOTTOM" .. side, dir * textX, edgeY)
  end
  if item.canEnchant then
    if item.enchanted then
      local raw = tostring(item.enchantText or "")
      local atlas = raw:match("|A.-|a")
      local plain = (raw:gsub("|A.-|a", "")):match("^%s*(.-)%s*$")
      SetTruncatedText(enchLine, plain, math.max(20, fullW - gemsW - (atlas and 18 or 0)))
      if atlas then enchLine:SetText(enchLine:GetText() .. " " .. atlas) end
      enchLine:SetWidth(0)
    else
      enchLine:SetText(L["EQUIP_ENCHANT_MISSING"])
      enchLine:SetTextColor(unpack(RED_MISSING))
    end
  end

  card:EnableMouse(true)
  card:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, mirror and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink(item.link)
    GameTooltip:Show()
  end)
  card:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return card
end

local function Panel(parent, y, h)
  local f = CreateFrame("Frame", nil, parent)
  f:SetPoint("TOPLEFT", SIDE_W + COL_GAP, -y)
  f:SetSize(CENTER_W, h)
  local bg = GG.Widgets.RoundedFill(f, f, 8, "BACKGROUND")
  bg:SetColor(Theme.level0)
  return f
end

local function PanelTitle(panel, text)
  local t = CreateLabel(panel, 11, { 0.655, 0.545, 0.980, 1 }, true)
  t:SetPoint("TOPLEFT", 14, -12)
  t:SetText(text:upper())
  return t
end

local function Slots(list, field)
  local out = {}
  for _, v in ipairs(list) do out[#out + 1] = field and v[field] or v end
  return table.concat(out, ", ")
end

local function SlotsWithIlvl(list)
  local out = {}
  for _, v in ipairs(list) do out[#out + 1] = ("%s %s"):format(v.slot, FormatIlvl(v.ilvl)) end
  return table.concat(out, ", ")
end

local function SlotSet(list)
  local set = {}
  for _, v in ipairs(list) do set[type(v) == "table" and v.slot or v] = true end
  return set
end

local function CheckLines(d)
  local lines = {}
  if #d.missingEnchant == 0 then
    lines[#lines + 1] = { ok = true, text = L["EQUIP_CHECK_ENCHANTS_OK"] }
  else
    lines[#lines + 1] = { ok = false, color = KIND_COLORS.fix, slots = SlotSet(d.missingEnchant),
      text = L["EQUIP_CHECK_ENCHANTS_MISSING"]:format(Slots(d.missingEnchant)) }
  end
  if d.socketed > 0 then
    if #d.emptyGems == 0 then
      lines[#lines + 1] = { ok = true, text = L["EQUIP_CHECK_GEMS_OK"] }
    else
      lines[#lines + 1] = { ok = false, color = KIND_COLORS.fix, slots = SlotSet(d.emptyGems),
        text = L["EQUIP_CHECK_GEMS_EMPTY"]:format(Slots(d.emptyGems)) }
    end
  end
  local up = d.upgradeFirst
  if up then
    lines[#lines + 1] = { ok = nil, color = KIND_COLORS.upgrade, slots = SlotSet({ up }),
      text = L["EQUIP_CHECK_UPGRADE_FIRST"]:format(up.slot, FormatIlvl(up.ilvl),
      ("%s %d/%d"):format(up.trackString or "?", up.cur or 0, up.max or 0)) }
  end
  if #d.maxedLow > 0 then
    lines[#lines + 1] = { ok = false, color = KIND_COLORS.replace, slots = SlotSet(d.maxedLow),
      text = L["EQUIP_CHECK_MAXED"]:format(SlotsWithIlvl(d.maxedLow)) }
  end
  if #d.craftedLow > 0 then
    lines[#lines + 1] = { ok = false, color = KIND_COLORS.fix, slots = SlotSet(d.craftedLow),
      text = L["EQUIP_CHECK_CRAFTED"]:format(SlotsWithIlvl(d.craftedLow)) }
  end
  return lines
end

local function HighlightCards(match, color)
  for _, card in ipairs(popup and popup.cards or {}) do
    local on = match and match(card.item)
    card.dimmed = match ~= nil and not on
    card.dim:SetShown(card.dimmed)
    if on then
      card.hl:SetColor(color[1], color[2], color[3], 0.95)
      card.hl:Show()
    else
      card.hl:Hide()
    end
  end
end

local function HoverZone(parent, match, color)
  local zone = CreateFrame("Frame", nil, parent)
  zone:EnableMouse(true)
  zone:SetScript("OnEnter", function() HighlightCards(match, color) end)
  zone:SetScript("OnLeave", function() HighlightCards(nil) end)
  return zone
end

local function TrackOf(item)
  return item.crafted and "crafted" or item.trackKey or "other"
end

local function DrawCenter(body, record, items, d)
  local x = SIDE_W + COL_GAP
  local cc = record.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[record.class]
  local name = CreateLabel(body, 22, cc and { cc.r, cc.g, cc.b, 1 } or Theme.textPrimary, true)
  name:SetPoint("TOPLEFT", x + 4, -2)
  name:SetText(record.name or "?")
  local spec
  if record.specID and GetSpecializationInfoByID then
    local _, specName = GetSpecializationInfoByID(record.specID)
    if type(specName) == "string" then spec = specName end
  end
  local className = record.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[record.class]
  if type(className) ~= "string" then className = nil end
  local who = CreateLabel(body, 11, Theme.textFaint)
  who:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
  local specClass = table.concat({ spec or "", className or "" }, " "):match("^%s*(.-)%s*$")
  who:SetText(specClass ~= "" and ((record.realm or "?") .. " · " .. specClass) or (record.realm or "?"))

  local ilvl = CreateLabel(body, 34, ILVL_GOLD, true)
  ilvl:SetJustifyH("RIGHT")
  ilvl:SetPoint("TOPRIGHT", body, "TOPLEFT", x + CENTER_W - 4, 2)
  ilvl:SetText(FormatIlvl(record.itemLevel or d.average))
  local ilvlLabel = CreateLabel(body, 10, Theme.textFaint, true)
  ilvlLabel:SetJustifyH("RIGHT")
  ilvlLabel:SetPoint("TOPRIGHT", ilvl, "BOTTOMRIGHT", 0, -2)
  ilvlLabel:SetText(L["EQUIP_EQUIPPED_ILVL"]:upper())

  local rule = body:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(1, 1, 1, 0.06)
  rule:SetPoint("TOPLEFT", x, -56)
  rule:SetSize(CENTER_W, 1)

  local y = 66
  local tracks = Panel(body, y, 88)
  PanelTitle(tracks, L["EQUIP_TRACKS"])
  local total = 0
  for _, t in ipairs(d.tracks) do total = total + t.count end
  local barW = CENTER_W - 28
  local bx = 14
  local names = {}
  for _, it in ipairs(items) do
    if it.trackKey and it.trackString and not names[it.trackKey] then names[it.trackKey] = it.trackString end
  end
  local lx = 14
  for i, t in ipairs(d.tracks) do
    local color = TRACK_COLORS[t.key] or TRACK_COLORS.other
    local w = total > 0 and math.max(4, math.floor(barW * t.count / total + 0.5)) or 0
    if i == #d.tracks then w = math.max(4, barW + 14 - bx) end
    local segBox = CreateFrame("Frame", nil, tracks)
    segBox:SetPoint("TOPLEFT", bx, -34)
    segBox:SetSize(math.max(1, w - 2), 12)
    local seg = GG.Widgets.RoundedFill(segBox, segBox, 4, "ARTWORK")
    seg:SetColor(color)
    bx = bx + w
    local dot = tracks:CreateTexture(nil, "ARTWORK")
    dot:SetColorTexture(color[1], color[2], color[3], 1)
    dot:SetSize(8, 8)
    dot:SetPoint("TOPLEFT", lx, -62)
    local legend = CreateLabel(tracks, 12, Theme.textMuted)
    legend:SetPoint("LEFT", dot, "RIGHT", 6, 0)
    local label = (t.key == "crafted" and L["EQUIP_TRACK_CRAFTED"]) or names[t.key] or L["EQUIP_TRACK_OTHER"]
    legend:SetText(("%s · %d"):format(label, t.count))
    local lw = legend:GetStringWidth()
    if not lw or lw <= 0 then lw = GG.Layout.EstimateWidth(label .. " · 00", 12) end
    local key = t.key
    local function IsTrack(it) return it.link ~= nil and TrackOf(it) == key end
    local segZone = HoverZone(tracks, IsTrack, color)
    segZone:SetPoint("TOPLEFT", segBox, "TOPLEFT", 0, 4)
    segZone:SetPoint("BOTTOMRIGHT", segBox, "BOTTOMRIGHT", 0, -4)
    local legendZone = HoverZone(tracks, IsTrack, color)
    legendZone:SetPoint("TOPLEFT", dot, "TOPLEFT", -4, 5)
    legendZone:SetSize(8 + 6 + lw + 8, 18)
    lx = lx + 8 + 6 + lw + 20
  end

  y = y + 88 + 10
  local lines = CheckLines(d)
  local checksH = 40 + #lines * 28
  local checks = Panel(body, y, checksH)
  PanelTitle(checks, L["EQUIP_CHECKS"])
  for i, line in ipairs(lines) do
    local ly = -(36 + (i - 1) * 28)
    local disc = checks:CreateTexture(nil, "ARTWORK")
    disc:SetTexture(Theme.media.dot)
    disc:SetSize(18, 18)
    disc:SetPoint("TOPLEFT", 14, ly)
    local mark = CreateLabel(checks, 11, Theme.textPrimary, true)
    mark:SetPoint("CENTER", disc, "CENTER", 0, 0)
    if line.ok == true then
      disc:SetVertexColor(Theme.success[1], Theme.success[2], Theme.success[3], 0.25)
      mark:SetText("|A:common-icon-checkmark:12:12|a")
    else
      local c = line.color or (line.ok == false and RED_MISSING) or Theme.accent
      disc:SetVertexColor(c[1], c[2], c[3], 0.25)
      mark:SetText(line.ok == false and "!" or ">")
      mark:SetTextColor(c[1], c[2], c[3], 1)
    end
    local text = CreateLabel(checks, 12, Theme.textMuted)
    text:SetPoint("LEFT", disc, "RIGHT", 10, 0)
    SetTruncatedText(text, line.text, CENTER_W - 14 - 18 - 10 - 14)
    if line.slots then
      local slots, color = line.slots, line.color or RED_MISSING
      local zone = HoverZone(checks, function(it) return slots[it.slot] end, color)
      zone:SetPoint("TOPLEFT", 6, ly + 4)
      zone:SetSize(CENTER_W - 12, 26)
      local glow = GG.Widgets.RoundedFill(zone, zone, 6, "BACKGROUND", 1)
      glow:SetColor(color[1], color[2], color[3], 0.08)
      glow:Hide()
      zone:HookScript("OnEnter", function() glow:Show() end)
      zone:HookScript("OnLeave", function() glow:Hide() end)
    end
  end
  return y + checksH
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
  GG.Widgets.ApplyPopup(popup)
  tinsert(UISpecialFrames, "GGEquipmentWindow")

  local mark = popup:CreateTexture(nil, "ARTWORK")
  mark:SetSize(20, 20)
  mark:SetPoint("TOPLEFT", 14, -12)
  mark:SetTexture(Theme.media.logoIcon)
  mark:SetVertexColor(unpack(Theme.accent))
  popup.mark = mark

  popup.title = CreateLabel(popup, 14, Theme.textPrimary, true)
  popup.title:SetPoint("LEFT", mark, "RIGHT", 10, 0)
  popup.title:SetText(L["EQUIP_WINDOW_TITLE"])

  local close = GG.Widgets.CreateIconButton(popup, 30, { texture = Theme.media.close, iconSize = 14 })
  close:SetPoint("TOPRIGHT", -8, -7)
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

local function ShowMessage(text)
  local msg = CreateLabel(popup.body, 12, Theme.textMuted)
  msg:SetPoint("TOPLEFT", 0, 0)
  msg:SetWidth(WIDTH - PADDING * 2)
  msg:SetWordWrap(true)
  msg:SetText(text)
  popup.body:SetHeight(40)
  popup:SetSize(WIDTH, TITLEBAR_HEIGHT + 40 + PADDING)
  popup:Show()
end

function GG.UI:ShowEquipmentWindow(record)
  if not popup then BuildPopup() end
  ClearBody()
  popup.mark:SetVertexColor(unpack(Theme.accent))
  KIND_COLORS.upgrade = Theme.accent
  if popup.chrome then popup.chrome:Paint() end

  if type(record.equipment) ~= "table" then
    ShowMessage(L["EQUIP_NO_DATA"])
    return
  end

  local links = {}
  for _, list in ipairs({ LEFT_SLOTS, RIGHT_SLOTS, BOTTOM_SLOTS }) do
    for _, slotDef in ipairs(list) do links[#links + 1] = record.equipment[slotDef.id] end
  end

  equipGeneration = equipGeneration + 1
  local myGeneration = equipGeneration
  local drawnNow = false

  local function DrawAll()
    if myGeneration ~= equipGeneration or not popup then return end
    ClearBody()
    local items, byList = {}, { {}, {}, {} }
    for li, list in ipairs({ LEFT_SLOTS, RIGHT_SLOTS, BOTTOM_SLOTS }) do
      for i, slotDef in ipairs(list) do
        local item = ReadItem(slotDef, record.equipment[slotDef.id])
        byList[li][i] = item
        if item.link then items[#items + 1] = item end
      end
    end
    local d = GG.GearDiagnosis.Diagnose(items, CraftedCap())
    local replace, fix = SlotSet(d.maxedLow), SlotSet(d.missingEnchant)
    for slot in pairs(SlotSet(d.emptyGems)) do fix[slot] = true end
    for slot in pairs(SlotSet(d.craftedLow)) do fix[slot] = true end
    local function KindOf(item)
      if not item.link then return nil end
      local upgradable = item.max and (item.cur or 0) < item.max and not item.crafted
      if replace[item.slot] or (d.low[item.slot] and not upgradable) then return "replace" end
      if fix[item.slot] then return "fix" end
      if d.upgradeFirst == item then return "upgrade" end
    end
    popup.cards = {}
    local function Card(px, py, item, mirror)
      local card = DrawSlotCard(popup.body, px, py, item, mirror, d.low[item.slot], KindOf(item))
      popup.cards[#popup.cards + 1] = card
    end

    local pitch = CARD_H + CARD_GAP
    for i, item in ipairs(byList[1]) do
      Card(0, (i - 1) * pitch, item, false)
    end
    local rightX = SIDE_W + COL_GAP + CENTER_W + COL_GAP
    for i, item in ipairs(byList[2]) do
      Card(rightX, (i - 1) * pitch, item, true)
    end
    local centerBottom = DrawCenter(popup.body, record, items, d)
    local pairW = SIDE_W * 2 + 10
    local bx = SIDE_W + COL_GAP + (CENTER_W - pairW) / 2
    local by = centerBottom + 12
    for i, item in ipairs(byList[3]) do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      Card(bx + col * (SIDE_W + 10), by + row * pitch, item, false)
    end

    local sidesH = #LEFT_SLOTS * pitch - CARD_GAP
    local bodyHeight = math.max(sidesH, by + 2 * pitch - CARD_GAP)
    popup.body:SetHeight(bodyHeight)
    popup:SetSize(WIDTH, TITLEBAR_HEIGHT + bodyHeight + PADDING)
    popup:Show()
    drawnNow = true
  end

  GG.Widgets.PreloadItems(links, DrawAll)

  if not drawnNow then ShowMessage(L["EQUIP_LOADING"]) end
end
