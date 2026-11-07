local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.BonusRollTab = {}

local Theme
local container
local detail
local state = { view = "log", content = nil, character = nil, difficulty = nil }

local ALL = "__all"
local TEXT_SCALE = 1.2
local ROW_H = 38
local ICON = 28
local CARD_W, CARD_GAP = 440, 14
local LANE_ICONS_X = 156
local LANE_H = 44
local LANE_ICONS_MAX = 3
local ART_H = 50
local CARD_HEADER = 10 + ART_H + 10
local ART_CROP = 0.06
local FALLBACK_ART = {
  delve = "Interface\\Icons\\INV_Misc_Key_03",
  world = "Interface\\Icons\\Ability_Hunter_SniperShot",
}
local MONEY_ICON = "Interface\\Icons\\INV_Misc_Coin_01"

local COL = {
  { key = "when",   x = 8,    w = 126 },
  { key = "who",    x = 140,  w = 150 },
  { key = "result", x = 298,  w = 306 },
  { key = "where",  x = 612,  w = 284 },
  { key = "diff",   x = 904,  w = 194 },
  { key = "spec",   x = 1104, w = 170 },
}
GG.BonusRollTab.CONTENT_WIDTH = COL[#COL].x + COL[#COL].w + 24
local COLX = {}
for _, c in ipairs(COL) do COLX[c.key] = c end

local KIND = {
  raid    = { labelKey = "BR_KIND_RAID",    color = { 0.694, 0.549, 1.000, 1 } },
  dungeon = { labelKey = "BR_KIND_DUNGEON", color = { 0.310, 0.820, 0.773, 1 } },
  delve   = { labelKey = "BR_KIND_DELVE",   color = { 0.910, 0.722, 0.361, 1 } },
  world   = { labelKey = "BR_KIND_WORLD",   color = { 1.000, 0.420, 0.420, 1 } },
}
local CONTENT_ORDER = { "raid", "dungeon", "delve", "world" }
local NAV_BG = { 0.063, 0.071, 0.090, 1 }

local function CreateText(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size * TEXT_SCALE, "")
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

local function CreateRule(parent)
  local tex = parent:CreateTexture(nil, "ARTWORK")
  tex:SetHeight(1)
  tex:SetColorTexture(unpack(Theme.borderSoft))
  return tex
end

local function SetBackdrop(f, bg, border)
  f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  f:SetBackdropColor(unpack(bg))
  f:SetBackdropBorderColor(unpack(border))
end

local function SpecInfo(specID)
  if not specID or not GetSpecializationInfoByID then return L["BR_UNKNOWN_SPEC"], nil end
  local _, name, _, icon = GetSpecializationInfoByID(specID)
  return name or L["BR_UNKNOWN_SPEC"], icon
end

local function FormatGold(copper)
  local gold = math.floor((copper or 0) / 10000)
  return BreakUpLargeNumbers and BreakUpLargeNumbers(gold) or tostring(gold)
end

local function DescribeResult(entry)
  if entry.kind == "item" and entry.itemLink then
    local name, _, quality = C_Item.GetItemInfo(entry.itemLink)
    name = name or entry.itemLink:match("%[(.-)%]") or "?"
    quality = quality or C_Item.GetItemQualityByID(entry.itemLink)
    local color = Theme.textPrimary
    if quality then
      local r, g, b = C_Item.GetItemQualityColor(quality)
      color = { r, g, b, 1 }
    end
    local sub = entry.itemLevel and ("ilvl %d"):format(entry.itemLevel) or ""
    if entry.secondary then sub = sub .. " · " .. L["BR_SECONDARY"] end
    return select(5, C_Item.GetItemInfoInstant(entry.itemLink)), name, color, sub
  elseif entry.kind == "money" then
    return MONEY_ICON, L["BR_GOLD"]:format(FormatGold(entry.quantity)), Theme.textFaint, L["BR_GOLD_SUB"]
  elseif entry.kind == "currency" and entry.currencyID then
    local info = C_CurrencyInfo.GetCurrencyInfo(entry.currencyID)
    local name = (info and info.name) or "?"
    if (entry.quantity or 0) > 1 then name = ("%s ×%d"):format(name, entry.quantity) end
    return info and info.iconFileID, name, Theme.textPrimary, ""
  end
  return nil, L["BR_UNKNOWN_RESULT"], Theme.textFaint, ""
end

local function ShowResultTooltip(owner, entry)
  local isItem = entry.kind == "item" and entry.itemLink
  local isCurrency = entry.kind == "currency" and entry.currencyID
  if not (isItem or isCurrency) then
    local _, name, _, sub = DescribeResult(entry)
    GG.Tip:Open(owner, { family = "money" }, function(t)
      t:Head({ kicker = sub, title = name })
      if entry.at then t:Kv(L["TIP_ROLLED"], date(L["BR_DATE"], entry.at)) end
      if entry.spentCurrencyID and entry.spentCost then
        local info = C_CurrencyInfo.GetCurrencyInfo(entry.spentCurrencyID)
        t:Kv(L["TIP_SPENT"], L["TIP_SPENT_FMT"]:format(entry.spentCost, (info and info.name) or "?"), true)
      end
    end)
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  if isItem then
    GameTooltip:SetHyperlink(entry.itemLink)
  else
    GameTooltip:SetCurrencyByID(entry.currencyID, entry.quantity)
  end
  if entry.at then GameTooltip:AddLine(date(L["BR_DATE"], entry.at), unpack(Theme.textFaint)) end
  if entry.spentCurrencyID and entry.spentCost then
    local info = C_CurrencyInfo.GetCurrencyInfo(entry.spentCurrencyID)
    GameTooltip:AddLine(L["BR_SPENT"]:format(entry.spentCost, (info and info.name) or "?"), unpack(Theme.textFaint))
  end
  GameTooltip:Show()
end

local function DescribeDifficulty(entry)
  if entry.keystoneLevel then
    return L["BR_KEYSTONE"]:format(entry.keystoneLevel), { 1.000, 0.502, 0.000, 1 }
  end
  local id = entry.difficultyID
  local name, isHeroic, isChallengeMode, displayHeroic, displayMythic, isLFR
  if id and GetDifficultyInfo then
    local _, _, heroic, challenge, dHeroic, dMythic, _, lfr = GetDifficultyInfo(id)
    name = GetDifficultyInfo(id)
    isHeroic, isChallengeMode, displayHeroic, displayMythic, isLFR = heroic, challenge, dHeroic, dMythic, lfr
  end
  if entry.content == "delve" or entry.content == "world" then name = entry.difficultyName or name end
  local function NameHas(baseID)
    local word = GetDifficultyInfo and GetDifficultyInfo(baseID)
    return name and word and word ~= "" and name:find(word, 1, true) ~= nil
  end
  local color = Theme.gold
  if displayMythic or isChallengeMode or NameHas(16) then color = { 1.000, 0.502, 0.000, 1 }
  elseif displayHeroic or isHeroic or NameHas(15) then color = { 0.639, 0.208, 0.933, 1 }
  elseif isLFR then color = { 0.000, 0.639, 0.910, 1 }
  elseif id and id > 0 and entry.content ~= "delve" and entry.content ~= "world" then color = Theme.success
  end
  return (name and name ~= "") and name or "-", color
end

local function DescribeWhere(entry)
  if entry.content == "dungeon" then return entry.place or "?", "" end
  if entry.boss then return entry.boss, entry.place or "" end
  return entry.place or "?", entry.subZone or ""
end

local function CharacterLabel(row, duplicated)
  if duplicated[row.name] then return ("%s-%s"):format(row.name, row.realm) end
  return row.name
end

local function ClassColor(row)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[row.class]
  if c then return { c.r, c.g, c.b, 1 } end
  return Theme.textPrimary
end

local function CreateFieldLabel(parent, text)
  local fs = CreateText(parent, 9, Theme.textFaint, true)
  fs:SetText(text:upper())
  return fs
end

local function BuildToggle(parent, labelText, options, onPick)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetHeight(26)
  holder.buttons = {}
  holder.order = {}
  if labelText then
    holder.label = CreateFieldLabel(holder, labelText)
    holder.label:SetPoint("LEFT", 0, 0)
  end
  local seg = CreateFrame("Frame", nil, holder, "BackdropTemplate")
  SetBackdrop(seg, NAV_BG, Theme.border)
  seg:SetHeight(26)
  for _, option in ipairs(options) do
    local btn = CreateFrame("Button", nil, seg)
    btn:SetHeight(22)
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.label = CreateText(btn, 10.5, Theme.textMuted, true)
    btn.label:SetPoint("CENTER")
    btn.label:SetJustifyH("CENTER")
    btn.label:SetText(option.label)
    holder.order[#holder.order + 1] = btn
    local key = option.key
    btn:SetScript("OnClick", function() onPick(key) end)
    btn:SetScript("OnEnter", function(self)
      if not self.active then self.bg:SetColorTexture(1, 1, 1, 0.06) end
    end)
    btn:SetScript("OnLeave", function(self)
      if not self.active then self.bg:SetColorTexture(0, 0, 0, 0) end
    end)
    holder.buttons[key] = btn
  end
  holder.Layout = function()
    local x = holder.label and (math.ceil(TextWidth(holder.label)) + 10) or 0
    seg:ClearAllPoints()
    seg:SetPoint("LEFT", x, 0)
    local bx = 2
    for _, btn in ipairs(holder.order) do
      local width = math.max(52, math.ceil(TextWidth(btn.label)) + 24)
      btn:SetWidth(width)
      btn:ClearAllPoints()
      btn:SetPoint("LEFT", seg, "LEFT", bx, 0)
      bx = bx + width + 2
    end
    seg:SetWidth(bx)
    holder:SetWidth(x + bx)
  end
  holder.Layout()
  return holder
end

local function PaintToggle(holder, activeKey)
  holder.Layout()
  for key, btn in pairs(holder.buttons) do
    local active = key == (activeKey or ALL)
    btn.active = active
    btn.bg:SetColorTexture(unpack(active and Theme.accent or { 0, 0, 0, 0 }))
    btn.label:SetTextColor(unpack(active and Theme.onAccent or Theme.textMuted))
  end
end

local function Pick(field)
  return function(key)
    if key == ALL then key = nil end
    state[field] = key
    if container then container.list.offset = 0 end
    GG.BonusRollTab:Refresh()
  end
end

local function UpdateCharacterOptions(rows)
  local options = { { key = ALL, label = L["BR_ALL_CHARS"] } }
  local present = {}
  for _, row in ipairs(rows) do
    table.insert(options, { key = row.key, label = ("%s-%s"):format(row.name, row.realm) })
    present[row.key] = true
  end
  container.charOptions = options
  if state.character and not present[state.character] then state.character = nil end
  container.charDropdown.Refresh()
end

local function BuildSnaps(starts, contentH, listH)
  local snaps = {}
  for _, top in ipairs(starts) do
    snaps[#snaps + 1] = top
    if contentH - top <= listH + 0.5 then break end
  end
  if #snaps == 0 then snaps[1] = 0 end
  return snaps
end

local function NearestSnap(snaps, target)
  local best = 1
  for i, value in ipairs(snaps) do
    if math.abs(value - target) < math.abs(snaps[best] - target) then best = i end
  end
  return best
end

local function ApplySnaps(starts, contentH)
  local list = container.list
  local snaps = BuildSnaps(starts, contentH, list:GetHeight())
  list.snaps = snaps
  list.offset = snaps[NearestSnap(snaps, list.offset or 0)]
  list.contentHeight = contentH
  return list.offset
end

local function Fits(top, height)
  return top >= -0.5 and top + height <= container.list:GetHeight() + 0.5
end

local function UpdateScrollbar()
  local list, track = container.list, container.track
  local contentH, listH = list.contentHeight or 0, list:GetHeight()
  track:SetShown(contentH > listH + 0.5)
  if not track:IsShown() then return end
  local trackH = track:GetHeight()
  local thumbH = math.max(24, trackH * listH / contentH)
  local ratio = (list.offset or 0) / math.max(1, contentH - listH)
  track.thumb:SetHeight(thumbH)
  track.thumb:ClearAllPoints()
  track.thumb:SetPoint("TOP", track, "TOP", 0, -(trackH - thumbH) * math.min(1, ratio))
end

function GG.BonusRollTab:ScrollTo(offset)
  if not container or not container.list then return end
  local snaps = container.list.snaps or { 0 }
  container.list.offset = snaps[NearestSnap(snaps, offset)]
  self:Refresh()
end

local function EnsureLogRow(index)
  local row = container.logRows[index]
  if row then return row end

  row = CreateFrame("Frame", nil, container.list)
  row:SetHeight(ROW_H)
  row.stripe = row:CreateTexture(nil, "BACKGROUND")
  row.stripe:SetAllPoints()
  row.stripe:SetColorTexture(1, 1, 1, 0.025)

  row.when = CreateText(row, 11, Theme.textFaint)
  row.when:SetPoint("LEFT", COLX.when.x, 0)
  row.when:SetWidth(COLX.when.w)

  row.who = CreateText(row, 12, Theme.textPrimary, true)
  row.who:SetPoint("TOPLEFT", COLX.who.x, -4)
  row.who:SetWidth(COLX.who.w)
  row.realm = CreateText(row, 10, Theme.textFaint)
  row.realm:SetPoint("TOPLEFT", row.who, "BOTTOMLEFT", 0, -1)
  row.realm:SetWidth(COLX.who.w)

  row.result = CreateFrame("Button", nil, row, "BackdropTemplate")
  row.result:SetPoint("LEFT", COLX.result.x, 0)
  row.result:SetSize(COLX.result.w, ROW_H - 4)
  row.icon = row.result:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(ICON, ICON)
  row.icon:SetPoint("LEFT", 0, 0)
  row.iconBorder = CreateFrame("Frame", nil, row.result, "BackdropTemplate")
  row.iconBorder:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -1, 1)
  row.iconBorder:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 1, -1)
  row.iconBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  row.name = CreateText(row.result, 12, Theme.textPrimary, true)
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 7, 1)
  row.name:SetWidth(COLX.result.w - ICON - 10)
  row.sub = CreateText(row.result, 10, Theme.textFaint)
  row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
  row.sub:SetWidth(COLX.result.w - ICON - 10)
  row.result:SetScript("OnEnter", function(self) if self.entry then ShowResultTooltip(self, self.entry) end end)
  row.result:SetScript("OnLeave", function() GameTooltip:Hide() end)

  row.tag = CreateFrame("Frame", nil, row, "BackdropTemplate")
  row.tag:SetHeight(17)
  row.tag:SetPoint("TOPLEFT", COLX.where.x, -4)
  row.tag:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  row.tag.text = CreateText(row.tag, 9, Theme.textPrimary, true)
  row.tag.text:SetPoint("CENTER")
  row.boss = CreateText(row, 12, Theme.textPrimary, true)
  row.boss:SetPoint("LEFT", row.tag, "RIGHT", 6, 0)
  row.boss:SetWidth(COLX.where.w - 70)
  row.place = CreateText(row, 10, Theme.textFaint)
  row.place:SetPoint("TOPLEFT", row.tag, "BOTTOMLEFT", 0, -2)
  row.place:SetWidth(COLX.where.w)

  row.diff = CreateText(row, 12, Theme.textPrimary, true)
  row.diff:SetPoint("LEFT", COLX.diff.x, 0)
  row.diff:SetWidth(COLX.diff.w)

  row.specIcon = row:CreateTexture(nil, "ARTWORK")
  row.specIcon:SetSize(19, 19)
  row.specIcon:SetPoint("LEFT", COLX.spec.x, 0)
  row.spec = CreateText(row, 12, Theme.textPrimary)
  row.spec:SetPoint("LEFT", row.specIcon, "RIGHT", 6, 0)
  row.spec:SetWidth(COLX.spec.w - 22)

  container.logRows[index] = row
  return row
end

local function PaintLogRow(row, item, index, duplicated)
  local entry, owner = item.entry, item.row
  row.stripe:SetShown(index % 2 == 0)
  row.when:SetText(entry.at and date(L["BR_DATE"], entry.at) or "")

  row.who:SetText(CharacterLabel(owner, duplicated))
  row.who:SetTextColor(unpack(ClassColor(owner)))
  row.realm:SetText(owner.realm or "")

  local icon, name, color, sub = DescribeResult(entry)
  GG.Widgets.SetItemIcon(row.icon, icon)
  row.iconBorder:SetBackdropBorderColor(color[1], color[2], color[3], entry.kind == "item" and 0.9 or 0.35)
  row.name:SetText(name)
  row.name:SetTextColor(unpack(color))
  row.sub:SetText(sub)
  row.result.entry = entry
  row:SetAlpha(entry.kind == "money" and 0.6 or 1)

  local kind = KIND[entry.content] or KIND.world
  row.tag.text:SetText(L[kind.labelKey]:upper())
  row.tag.text:SetTextColor(unpack(kind.color))
  row.tag:SetBackdropBorderColor(kind.color[1], kind.color[2], kind.color[3], 0.6)
  row.tag:SetWidth(row.tag.text:GetStringWidth() + 10)
  local main, secondary = DescribeWhere(entry)
  row.boss:SetText(main)
  row.place:SetText(secondary)

  local diffText, diffColor = DescribeDifficulty(entry)
  row.diff:SetText(diffText)
  row.diff:SetTextColor(unpack(diffColor))

  local specName, specIcon = SpecInfo(entry.specID)
  GG.Widgets.SetItemIcon(row.specIcon, specIcon)
  row.spec:SetText(specName)
end

local function PaintLog(collected, duplicated)
  local starts = {}
  for i = 1, #collected do starts[i] = (i - 1) * ROW_H end
  local offset = ApplySnaps(starts, #collected * ROW_H)
  local y = -offset
  for i, item in ipairs(collected) do
    local row = EnsureLogRow(i)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", container.list, "TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", container.list, "RIGHT", 0, 0)
    PaintLogRow(row, item, i, duplicated)
    row:SetShown(Fits(y, ROW_H))
    y = y + ROW_H
  end
  for i = #collected + 1, #container.logRows do container.logRows[i]:Hide() end
end

local ITEM_ROW_H = 28
local ITEM_ICON = 24

local function EnsureItemRow(lane, index)
  local row = lane.items[index]
  if row then return row end
  row = CreateFrame("Button", nil, lane)
  row:SetHeight(ITEM_ROW_H)
  row.border = CreateFrame("Frame", nil, row, "BackdropTemplate")
  row.border:SetSize(ITEM_ICON, ITEM_ICON)
  row.border:SetPoint("LEFT", 0, 0)
  row.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  row.tex = row.border:CreateTexture(nil, "ARTWORK")
  row.tex:SetPoint("TOPLEFT", 1, -1)
  row.tex:SetPoint("BOTTOMRIGHT", -1, 1)
  row.ilvl = CreateText(row, 10, Theme.textFaint)
  row.ilvl:SetPoint("RIGHT", 0, 0)
  row.ilvl:SetJustifyH("RIGHT")
  row.ilvl:SetWidth(36)
  row.name = CreateText(row, 11, Theme.textPrimary, true)
  row.name:SetPoint("LEFT", row.border, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.ilvl, "LEFT", -4, 0)
  row:SetScript("OnEnter", function(self) if self.entry then ShowResultTooltip(self, self.entry) end end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  lane.items[index] = row
  return row
end

local function EnsureLane(card, index)
  local lane = card.lanes[index]
  if lane then return lane end
  lane = CreateFrame("Frame", nil, card)
  lane.rule = lane:CreateTexture(nil, "ARTWORK")
  lane.rule:SetHeight(1)
  lane.rule:SetPoint("TOPLEFT", 0, 0)
  lane.rule:SetPoint("TOPRIGHT", 0, 0)
  lane.rule:SetColorTexture(1, 1, 1, 0.05)
  lane.specIcon = lane:CreateTexture(nil, "ARTWORK")
  lane.specIcon:SetSize(19, 19)
  lane.specIcon:SetPoint("TOPLEFT", 0, -6)
  lane.spec = CreateText(lane, 11, Theme.textPrimary, true)
  lane.spec:SetPoint("TOPLEFT", lane.specIcon, "TOPRIGHT", 5, 0)
  lane.spec:SetWidth(LANE_ICONS_X - 26)
  lane.who = CreateText(lane, 9.5, Theme.textFaint)
  lane.who:SetPoint("TOPLEFT", lane.spec, "BOTTOMLEFT", 0, -1)
  lane.who:SetWidth(LANE_ICONS_X - 26)
  lane.rolls = CreateText(lane, 9.5, Theme.textFaint)
  lane.items = {}
  lane.more = CreateFrame("Button", nil, lane)
  lane.more:SetHeight(17)
  lane.more.text = CreateText(lane.more, 10.5, Theme.accent, true)
  lane.more.text:SetPoint("LEFT", 0, 0)
  lane.more:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1, 1) end)
  lane.more:SetScript("OnLeave", function(self) self.text:SetTextColor(unpack(Theme.accent)) end)
  lane.more:SetScript("OnClick", function(self)
    if self.group then GG.BonusRollTab:ShowDetail(self.group) end
  end)
  card.lanes[index] = lane
  return lane
end

local function EnsureCard(index)
  local card = container.cards[index]
  if card then return card end
  card = CreateFrame("Frame", nil, container.list, "BackdropTemplate")
  card:SetWidth(CARD_W)
  SetBackdrop(card, Theme.panel, Theme.border)
  card.band = card:CreateTexture(nil, "BACKGROUND", nil, 2)
  card.band:SetPoint("TOPLEFT", 1, -1)
  card.band:SetPoint("TOPRIGHT", -1, -1)
  card.band:SetHeight(CARD_HEADER - 1)
  card.band:SetColorTexture(1, 1, 1, 1)
  card.bandLine = card:CreateTexture(nil, "ARTWORK")
  card.bandLine:SetHeight(1)
  card.bandLine:SetPoint("TOPLEFT", 1, -CARD_HEADER)
  card.bandLine:SetPoint("TOPRIGHT", -1, -CARD_HEADER)
  card.bandLine:SetColorTexture(unpack(Theme.borderSoft))
  card.art = card:CreateTexture(nil, "ARTWORK")
  card.art:SetPoint("TOPLEFT", 12, -10)
  card.artBorder = CreateFrame("Frame", nil, card, "BackdropTemplate")
  card.artBorder:SetPoint("TOPLEFT", card.art, "TOPLEFT", -1, 1)
  card.artBorder:SetPoint("BOTTOMRIGHT", card.art, "BOTTOMRIGHT", 1, -1)
  card.artBorder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  card.artBorder:SetBackdropBorderColor(unpack(Theme.borderSoft))
  card.title = CreateText(card, 13, Theme.textPrimary, true)
  card.title:SetPoint("TOPLEFT", card.art, "TOPRIGHT", 10, 0)
  card.diff = CreateText(card, 11, Theme.textPrimary, true)
  card.diff:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -2)
  card.place = CreateText(card, 10, Theme.textFaint)
  card.place:SetPoint("TOPLEFT", card.diff, "BOTTOMLEFT", 0, -2)
  card.lanes = {}
  container.cards[index] = card
  return card
end

local function PaintLane(lane, data, showCharacter, group)
  local specName, specIcon = SpecInfo(data.specID)
  GG.Widgets.SetItemIcon(lane.specIcon, specIcon)
  lane.spec:SetText(specName)
  lane.who:SetText(showCharacter and ("%s-%s"):format(data.row.name, data.row.realm) or "")
  lane.who:SetTextColor(unpack(ClassColor(data.row)))
  lane.rolls:ClearAllPoints()
  lane.rolls:SetPoint("TOPLEFT", showCharacter and lane.who or lane.spec, "BOTTOMLEFT", 0, -1)
  lane.rolls:SetText(data.rolls == 1 and L["BR_ROLL_ONE"] or L["BR_ROLLS"]:format(data.rolls))

  local shown = math.min(#data.entries, LANE_ICONS_MAX)
  local y = 4
  for i = 1, shown do
    local entry = data.entries[i]
    local row = EnsureItemRow(lane, i)
    local icon, name, color = DescribeResult(entry)
    GG.Widgets.SetItemIcon(row.tex, icon)
    row.border:SetBackdropBorderColor(color[1], color[2], color[3], entry.kind == "item" and 0.9 or 0.35)
    row.name:SetText(name)
    row.name:SetTextColor(unpack(color))
    row.ilvl:SetText(entry.itemLevel and tostring(entry.itemLevel) or "")
    row:SetAlpha(entry.kind == "money" and 0.6 or 1)
    row.entry = entry
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", lane, "TOPLEFT", LANE_ICONS_X, -y)
    row:SetPoint("RIGHT", lane, "RIGHT", 0, 0)
    row:Show()
    y = y + ITEM_ROW_H
  end
  for i = shown + 1, #lane.items do lane.items[i]:Hide() end

  local extra = #data.entries - shown
  lane.more:SetShown(extra > 0)
  if extra > 0 then
    lane.more:ClearAllPoints()
    lane.more:SetPoint("TOPLEFT", lane, "TOPLEFT", LANE_ICONS_X + ITEM_ICON + 6, -y)
    lane.more.text:SetText(L["BR_MORE"]:format(extra))
    lane.more:SetWidth(lane.more.text:GetStringWidth() + 4)
    lane.more.group = group
    y = y + 20
  end
  return math.max(LANE_H + 6, y + 4)
end

local atlasCoords = {}
local probe
local function AtlasBaseCoords(atlas)
  local cached = atlasCoords[atlas]
  if cached then return cached[1], cached[2], cached[3], cached[4] end
  probe = probe or container:CreateTexture(nil, "BACKGROUND")
  probe:Hide()
  probe:SetAtlas(atlas)
  local left, top, _, bottom, right = probe:GetTexCoord()
  if not (left and right and top and bottom) then return nil end
  atlasCoords[atlas] = { left, right, top, bottom }
  return left, right, top, bottom
end

local function PaintArt(tex, sample)
  local texture, kind = GG.BonusRoll:Portrait(sample)
  local artW = ART_H
  if kind == "wide" then
    artW = ART_H * 2
    tex:SetTexture(texture)
    tex:SetTexCoord(0, 1, 0, 1)
  elseif kind == "atlas" then
    tex:SetAtlas(texture)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(texture)
    if info and info.width and info.height and info.height > 0 then
      artW = math.min(ART_H * 3, math.floor(ART_H * info.width / info.height))
    else
      artW = ART_H * 2
    end
    local left, right, top, bottom = AtlasBaseCoords(texture)
    if left then
      local dx, dy = (right - left) * ART_CROP, (bottom - top) * ART_CROP
      tex:SetTexCoord(left + dx, right - dx, top + dy, bottom - dy)
    end
  elseif kind == "square" then
    tex:SetTexture(texture)
    tex:SetTexCoord(0, 1, 0, 1)
  else
    GG.Widgets.SetItemIcon(tex, FALLBACK_ART[sample.content])
  end
  tex:SetSize(artW, ART_H)
  return artW
end

local function CardDifficulty(group)
  local sample = group.sample
  if sample.content ~= "dungeon" then return DescribeDifficulty(sample) end
  local low, high
  for _, lane in ipairs(group.lanes) do
    for _, entry in ipairs(lane.entries) do
      local level = entry.keystoneLevel
      if level then
        low = math.min(low or level, level)
        high = math.max(high or level, level)
      end
    end
  end
  local color = { 1.000, 0.502, 0.000, 1 }
  if not low then return L["BR_MYTHIC_PLUS"], color end
  if low == high then return L["BR_KEYSTONE"]:format(low), color end
  return L["BR_KEYSTONE_RANGE"]:format(low, high), color
end

local function PaintCard(card, group, showCharacter, duplicated, cardW)
  local sample = group.sample
  local main, secondary = DescribeWhere(sample)

  local artW = PaintArt(card.art, sample)
  local textW = cardW - 24 - artW - 10
  card.title:SetWidth(textW)
  card.diff:SetWidth(textW)
  card.place:SetWidth(textW)

  card.title:SetText(main)
  local diffText, diffColor = CardDifficulty(group)
  card.diff:SetText(diffText ~= "-" and diffText or "")
  card.diff:SetTextColor(unpack(diffColor))
  card.place:SetText(secondary)
  local tint = (KIND[sample.content] or KIND.raid).color
  card.band:SetGradient("VERTICAL", CreateColor(tint[1], tint[2], tint[3], 0),
    CreateColor(tint[1], tint[2], tint[3], 0.13))

  local y = CARD_HEADER
  for i, data in ipairs(group.lanes) do
    local lane = EnsureLane(card, i)
    lane:ClearAllPoints()
    lane:SetPoint("TOPLEFT", card, "TOPLEFT", 12, -y)
    lane:SetPoint("RIGHT", card, "RIGHT", -12, 0)
    local laneH = PaintLane(lane, data, showCharacter, group)
    lane.rule:SetShown(i > 1)
    lane:SetHeight(laneH)
    lane:Show()
    y = y + laneH
  end
  for i = #group.lanes + 1, #card.lanes do card.lanes[i]:Hide() end
  return y + 6
end

local function PaintBosses(collected, duplicated)
  local groups = GG.BonusRoll:GroupByBoss(collected)
  state.groupCount = #groups
  local width = container.list:GetWidth()
  if not width or width < CARD_W then width = CARD_W end
  local columns = math.max(1, math.floor((width + CARD_GAP) / (CARD_W + CARD_GAP)))
  local cardW = math.floor((width - (columns - 1) * CARD_GAP) / columns)
  local showCharacter = state.character == nil

  local heights = {}
  for i, group in ipairs(groups) do
    local card = EnsureCard(i)
    card:SetWidth(cardW)
    local cardRow = math.floor((i - 1) / columns) + 1
    heights[cardRow] = math.max(heights[cardRow] or 0, PaintCard(card, group, showCharacter, duplicated, cardW))
  end
  local tops, contentH = {}, 0
  for r, h in ipairs(heights) do
    tops[r] = contentH
    contentH = contentH + h + CARD_GAP
  end
  contentH = math.max(0, contentH - CARD_GAP)
  local offset = ApplySnaps(tops, contentH)
  local hiddenBelow, shownBottom = 0, 0
  for i = 1, #groups do
    local col = (i - 1) % columns
    local cardRow = math.floor((i - 1) / columns) + 1
    local card = container.cards[i]
    local y = tops[cardRow] - offset
    card:SetHeight(heights[cardRow])
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", container.list, "TOPLEFT", col * (cardW + CARD_GAP), -y)
    local fits = Fits(y, heights[cardRow])
    card:SetShown(fits)
    if fits then
      shownBottom = math.max(shownBottom, y + heights[cardRow])
    elseif y > 0 then
      hiddenBelow = hiddenBelow + 1
    end
  end
  for i = #groups + 1, #container.cards do container.cards[i]:Hide() end
  local more = container.moreBelow
  local room = container.list:GetHeight() - shownBottom
  more:SetShown(hiddenBelow > 0 and room >= 36)
  if more:IsShown() then
    more.label:SetText(hiddenBelow == 1 and L["BR_MORE_BELOW_ONE"] or L["BR_MORE_BELOW"]:format(hiddenBelow))
    more:SetWidth(TextWidth(more.label) + 24)
    more:ClearAllPoints()
    more:SetPoint("TOP", container.list, "TOP", 0, -(shownBottom + 14))
  end
  if detail and detail:IsShown() and detail.groupKey then
    for _, group in ipairs(groups) do
      if group.key == detail.groupKey then GG.BonusRollTab:ShowDetail(group) end
    end
  end
end

local DETAIL_W = 620
local DETAIL_MAX_H = 680
local DETAIL_ROW_H = 28
local DETAIL_TOP = 14 + ART_H + 14

local function BuildDetail()
  detail = CreateFrame("Frame", "GGBonusRollDetail", UIParent, "BackdropTemplate")
  detail:SetSize(DETAIL_W, 200)
  detail:SetPoint("CENTER")
  detail:SetFrameStrata("FULLSCREEN_DIALOG")
  detail:SetToplevel(true)
  detail:SetMovable(true)
  detail:EnableMouse(true)
  detail:RegisterForDrag("LeftButton")
  detail:SetScript("OnDragStart", detail.StartMoving)
  detail:SetScript("OnDragStop", detail.StopMovingOrSizing)
  detail:SetClampedToScreen(true)
  GG.Widgets.ApplyPanel(detail, { bg = Theme.background, corners = "all" })
  local solid = detail:CreateTexture(nil, "BACKGROUND", nil, -7)
  solid:SetPoint("TOPLEFT", 3, -3)
  solid:SetPoint("BOTTOMRIGHT", -3, 3)
  solid:SetColorTexture(Theme.background[1], Theme.background[2], Theme.background[3], 1)
  tinsert(UISpecialFrames, "GGBonusRollDetail")

  local bar = detail:CreateTexture(nil, "ARTWORK")
  bar:SetColorTexture(unpack(Theme.accent))
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("TOPRIGHT")
  bar:SetHeight(2)

  detail.art = detail:CreateTexture(nil, "ARTWORK")
  detail.art:SetPoint("TOPLEFT", 14, -14)
  detail.title = CreateText(detail, 13, Theme.textPrimary, true)
  detail.title:SetPoint("TOPLEFT", detail.art, "TOPRIGHT", 10, 0)
  detail.diff = CreateText(detail, 11, Theme.textPrimary, true)
  detail.diff:SetPoint("TOPLEFT", detail.title, "BOTTOMLEFT", 0, -2)
  detail.place = CreateText(detail, 10, Theme.textFaint)
  detail.place:SetPoint("TOPLEFT", detail.diff, "BOTTOMLEFT", 0, -2)

  local close = CreateFrame("Button", nil, detail)
  close:SetSize(20, 20)
  close:SetPoint("TOPRIGHT", -8, -8)
  local closeLabel = CreateText(close, 16, Theme.textMuted)
  closeLabel:SetPoint("CENTER")
  closeLabel:SetJustifyH("CENTER")
  closeLabel:SetText("x")
  close:SetScript("OnEnter", function() closeLabel:SetTextColor(unpack(Theme.textPrimary)) end)
  close:SetScript("OnLeave", function() closeLabel:SetTextColor(unpack(Theme.textMuted)) end)
  close:SetScript("OnClick", function() detail:Hide() end)

  detail.clip = CreateFrame("Frame", nil, detail)
  detail.clip:SetPoint("TOPLEFT", 14, -DETAIL_TOP)
  detail.clip:SetPoint("BOTTOMRIGHT", -14, 12)
  detail.clip:SetClipsChildren(true)
  detail.clip:EnableMouseWheel(true)
  detail.content = CreateFrame("Frame", nil, detail.clip)
  detail.content:SetWidth(DETAIL_W - 28)
  detail.clip:SetScript("OnMouseWheel", function(self, delta)
    local max = math.max(0, detail.content:GetHeight() - self:GetHeight())
    detail.offset = math.min(max, math.max(0, (detail.offset or 0) - delta * DETAIL_ROW_H * 3))
    detail.content:ClearAllPoints()
    detail.content:SetPoint("TOPLEFT", self, "TOPLEFT", 0, detail.offset)
  end)
  detail.headers, detail.rows = {}, {}
  detail:Hide()
end

local function EnsureDetailHeader(index)
  local h = detail.headers[index]
  if h then return h end
  h = CreateFrame("Frame", nil, detail.content)
  h:SetHeight(DETAIL_ROW_H)
  h:SetPoint("RIGHT", detail.content, "RIGHT", 0, 0)
  h.rule = h:CreateTexture(nil, "ARTWORK")
  h.rule:SetHeight(1)
  h.rule:SetPoint("BOTTOMLEFT")
  h.rule:SetPoint("BOTTOMRIGHT")
  h.rule:SetColorTexture(unpack(Theme.borderSoft))
  h.icon = h:CreateTexture(nil, "ARTWORK")
  h.icon:SetSize(19, 19)
  h.icon:SetPoint("LEFT", 0, 0)
  h.spec = CreateText(h, 11.5, Theme.textPrimary, true)
  h.spec:SetPoint("LEFT", h.icon, "RIGHT", 6, 0)
  h.who = CreateText(h, 10.5, Theme.textPrimary)
  h.who:SetPoint("LEFT", h.spec, "RIGHT", 8, 0)
  h.count = CreateText(h, 10, Theme.textFaint)
  h.count:SetPoint("RIGHT", 0, 0)
  h.count:SetJustifyH("RIGHT")
  detail.headers[index] = h
  return h
end

local function EnsureDetailRow(index)
  local row = detail.rows[index]
  if row then return row end
  row = CreateFrame("Button", nil, detail.content)
  row:SetHeight(DETAIL_ROW_H)
  row:SetPoint("RIGHT", detail.content, "RIGHT", 0, 0)
  row.border = CreateFrame("Frame", nil, row, "BackdropTemplate")
  row.border:SetSize(ITEM_ICON, ITEM_ICON)
  row.border:SetPoint("LEFT", 4, 0)
  row.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  row.tex = row.border:CreateTexture(nil, "ARTWORK")
  row.tex:SetPoint("TOPLEFT", 1, -1)
  row.tex:SetPoint("BOTTOMRIGHT", -1, 1)
  row.when = CreateText(row, 9.5, Theme.textFaint)
  row.when:SetPoint("RIGHT", 0, 0)
  row.when:SetJustifyH("RIGHT")
  row.when:SetWidth(118)
  row.ilvl = CreateText(row, 10, Theme.textFaint)
  row.ilvl:SetPoint("RIGHT", row.when, "LEFT", -6, 0)
  row.ilvl:SetJustifyH("RIGHT")
  row.ilvl:SetWidth(36)
  row.name = CreateText(row, 11, Theme.textPrimary, true)
  row.name:SetPoint("LEFT", row.border, "RIGHT", 6, 0)
  row.name:SetPoint("RIGHT", row.ilvl, "LEFT", -6, 0)
  row:SetScript("OnEnter", function(self) if self.entry then ShowResultTooltip(self, self.entry) end end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  detail.rows[index] = row
  return row
end

function GG.BonusRollTab:ShowDetail(group)
  if not detail then BuildDetail() end
  local reopening = detail.groupKey ~= group.key
  detail.groupKey = group.key
  if reopening then detail.offset = 0 end

  local sample = group.sample
  local artW = PaintArt(detail.art, sample)
  local textW = DETAIL_W - 28 - artW - 10 - 24
  detail.title:SetWidth(textW)
  detail.diff:SetWidth(textW)
  detail.place:SetWidth(textW)
  local main, secondary = DescribeWhere(sample)
  detail.title:SetText(main)
  local diffText, diffColor = CardDifficulty(group)
  detail.diff:SetText(diffText ~= "-" and diffText or "")
  detail.diff:SetTextColor(unpack(diffColor))
  local rolls = 0
  for _, lane in ipairs(group.lanes) do rolls = rolls + lane.rolls end
  local rollsText = rolls == 1 and L["BR_ROLL_ONE"] or L["BR_ROLLS"]:format(rolls)
  detail.place:SetText(secondary ~= "" and (secondary .. " · " .. rollsText) or rollsText)

  local y, hi, ri = 0, 0, 0
  for _, lane in ipairs(group.lanes) do
    hi = hi + 1
    local h = EnsureDetailHeader(hi)
    h:ClearAllPoints()
    h:SetPoint("TOPLEFT", detail.content, "TOPLEFT", 0, -y)
    h:SetPoint("RIGHT", detail.content, "RIGHT", 0, 0)
    local specName, specIcon = SpecInfo(lane.specID)
    GG.Widgets.SetItemIcon(h.icon, specIcon)
    h.spec:SetText(specName)
    h.who:SetText(("%s-%s"):format(lane.row.name, lane.row.realm))
    h.who:SetTextColor(unpack(ClassColor(lane.row)))
    h.count:SetText(lane.rolls == 1 and L["BR_ROLL_ONE"] or L["BR_ROLLS"]:format(lane.rolls))
    h:Show()
    y = y + DETAIL_ROW_H + 2

    for _, entry in ipairs(lane.entries) do
      ri = ri + 1
      local row = EnsureDetailRow(ri)
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", detail.content, "TOPLEFT", 0, -y)
      row:SetPoint("RIGHT", detail.content, "RIGHT", 0, 0)
      local icon, name, color = DescribeResult(entry)
      GG.Widgets.SetItemIcon(row.tex, icon)
      row.border:SetBackdropBorderColor(color[1], color[2], color[3], entry.kind == "item" and 0.9 or 0.35)
      row.name:SetText(name)
      row.name:SetTextColor(unpack(color))
      row.ilvl:SetText(entry.itemLevel and tostring(entry.itemLevel) or "")
      row.when:SetText(entry.at and date(L["BR_DATE"], entry.at) or "")
      row:SetAlpha(entry.kind == "money" and 0.6 or 1)
      row.entry = entry
      row:Show()
      y = y + DETAIL_ROW_H
    end
    y = y + 10
  end
  for i = hi + 1, #detail.headers do detail.headers[i]:Hide() end
  for i = ri + 1, #detail.rows do detail.rows[i]:Hide() end

  detail.content:SetHeight(math.max(y, 1))
  detail:SetHeight(math.min(DETAIL_MAX_H, DETAIL_TOP + y + 12))
  local max = math.max(0, y - (detail:GetHeight() - DETAIL_TOP - 12))
  detail.offset = math.min(detail.offset or 0, max)
  detail.content:ClearAllPoints()
  detail.content:SetPoint("TOPLEFT", detail.clip, "TOPLEFT", 0, detail.offset)
  detail:Show()
end

local function BuildLogHeader(parent)
  local head = CreateFrame("Frame", nil, parent)
  head:SetHeight(22)
  local keys = { when = "BR_COL_DATE", who = "BR_COL_CHARACTER", result = "BR_COL_RESULT",
    where = "BR_COL_WHERE", diff = "BR_COL_DIFFICULTY", spec = "BR_COL_SPEC" }
  for _, c in ipairs(COL) do
    local fs = CreateText(head, 10.5, Theme.textFaint)
    fs:SetPoint("LEFT", c.x, 0)
    fs:SetWidth(c.w)
    fs:SetText(L[keys[c.key]])
  end
  return head
end

function GG.BonusRollTab:Attach(parent)
  if container then return container end
  Theme = GG.Theme

  container = CreateFrame("Frame", nil, parent)
  container:SetAllPoints(parent)
  container.logRows, container.cards = {}, {}

  container.view = BuildToggle(container, nil, {
    { key = "log", label = L["BR_VIEW_LOG"] },
    { key = "boss", label = L["BR_VIEW_BOSS"] },
  }, function(key)
    state.view = key
    container.list.offset = 0
    if GG.RosterUI and GG.RosterUI.Relayout then GG.RosterUI:Relayout() end
    GG.BonusRollTab:Refresh()
  end)
  container.view:SetPoint("TOPLEFT", 10, -10)

  container.count = CreateText(container, 11, Theme.textFaint)
  container.count:SetPoint("TOPRIGHT", -12, -50)
  container.count:SetJustifyH("RIGHT")

  container.demoBanner = CreateFrame("Frame", nil, container, "BackdropTemplate")
  container.demoBanner:SetHeight(24)
  container.demoBanner:SetPoint("TOPLEFT", 10, -10)
  container.demoBanner:SetPoint("TOPRIGHT", -10, -10)
  container.demoBanner:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
  container.demoBanner:SetBackdropColor(Theme.danger[1], Theme.danger[2], Theme.danger[3], 0.25)
  container.demoBanner.text = CreateText(container.demoBanner, 11.5, Theme.danger, true)
  container.demoBanner.text:SetPoint("CENTER")
  container.demoBanner.text:SetText(L["BR_DEMO_BANNER"])
  container.demoBanner:Hide()

  local contentOptions = { { key = ALL, label = L["BR_ALL"] } }
  for _, key in ipairs(CONTENT_ORDER) do
    table.insert(contentOptions, { key = key, label = L[KIND[key].labelKey] })
  end
  container.content = BuildToggle(container, L["BR_CONTENT"], contentOptions, Pick("content"))
  container.content:SetPoint("LEFT", container.view, "RIGHT", 20, 0)

  local difficultyOptions = {}
  for _, key in ipairs(GG.BonusRoll.DIFFICULTY_ORDER) do
    local name = GetDifficultyInfo and GetDifficultyInfo(GG.BonusRoll.DIFFICULTY_BASE_ID[key])
    table.insert(difficultyOptions, { key = key, label = (name and name ~= "") and name or key })
  end
  container.difficulty = BuildToggle(container, L["BR_DIFFICULTY"], difficultyOptions, Pick("difficulty"))
  container.difficulty:SetPoint("LEFT", container.content, "RIGHT", 20, 0)

  container.characters = CreateFrame("Frame", nil, container)
  container.characters:SetSize(10, 24)
  container.characters:SetPoint("TOPLEFT", container.view, "BOTTOMLEFT", 0, -10)
  local charLabel = CreateFieldLabel(container.characters, L["BR_CHARACTER"])
  charLabel:SetPoint("LEFT", 0, 0)
  container.charOptions = { { key = ALL, label = L["BR_ALL_CHARS"] } }
  container.charDropdown = GG.Widgets.CreateDropdown(container.characters, {
    width = 260,
    values = function() return container.charOptions end,
    get = function() return state.character or ALL end,
    set = Pick("character"),
  })
  container.charDropdown:SetPoint("LEFT", charLabel, "RIGHT", 10, 0)
  container.charDropdown:SetHeight(26)
  container.charDropdown:SetBackdropColor(unpack(NAV_BG))
  container.charDropdown:SetBackdropBorderColor(unpack(Theme.border))

  container.rule = CreateRule(container)
  container.rule:SetPoint("TOPLEFT", container.characters, "BOTTOMLEFT", 0, -10)
  container.rule:SetPoint("RIGHT", container, "RIGHT", -10, 0)

  container.head = BuildLogHeader(container)
  container.head:SetPoint("TOPLEFT", container.rule, "BOTTOMLEFT", 0, -4)
  container.head:SetPoint("RIGHT", container, "RIGHT", -10, 0)

  container.list = CreateFrame("Frame", nil, container)
  container.list:SetPoint("RIGHT", container, "RIGHT", -22, 0)
  container.list:SetPoint("BOTTOM", container, "BOTTOM", 0, 10)
  container.list:SetClipsChildren(true)
  container.list:EnableMouseWheel(true)
  container.list:SetScript("OnMouseWheel", function(self, delta)
    local snaps = self.snaps or { 0 }
    local index = NearestSnap(snaps, self.offset or 0) - delta * (state.view == "log" and 3 or 1)
    self.offset = snaps[math.max(1, math.min(#snaps, index))]
    GG.BonusRollTab:Refresh()
  end)

  local more = CreateFrame("Button", nil, container)
  more:SetHeight(22)
  more:SetFrameLevel(container.list:GetFrameLevel() + 5)
  more.label = CreateText(more, 11, Theme.textMuted, true)
  more.label:SetPoint("CENTER")
  more.label:SetJustifyH("CENTER")
  more:SetScript("OnEnter", function(self) self.label:SetTextColor(unpack(Theme.textPrimary)) end)
  more:SetScript("OnLeave", function(self) self.label:SetTextColor(unpack(Theme.textMuted)) end)
  more:SetScript("OnClick", function()
    local onWheel = container.list:GetScript("OnMouseWheel")
    onWheel(container.list, -1)
  end)
  more:Hide()
  container.moreBelow = more

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
  local idle = { Theme.textFaint[1], Theme.textFaint[2], Theme.textFaint[3], 0.55 }
  thumb.tex:SetColorTexture(unpack(idle))
  thumb:EnableMouse(true)
  thumb:SetScript("OnEnter", function(self) self.tex:SetColorTexture(unpack(Theme.accent)) end)
  thumb:SetScript("OnLeave", function(self)
    if not self.dragStart then self.tex:SetColorTexture(unpack(idle)) end
  end)
  thumb:SetScript("OnMouseDown", function(self)
    local _, cursorY = GetCursorPosition()
    self.dragStart, self.dragOffset = cursorY / self:GetEffectiveScale(), container.list.offset or 0
  end)
  thumb:SetScript("OnMouseUp", function(self)
    self.dragStart = nil
    if not self:IsMouseOver() then self.tex:SetColorTexture(unpack(idle)) end
  end)
  thumb:SetScript("OnUpdate", function(self)
    if not self.dragStart then return end
    local _, cursorY = GetCursorPosition()
    local moved = self.dragStart - cursorY / self:GetEffectiveScale()
    local trackH = container.track:GetHeight()
    if trackH <= 0 then return end
    local target = self.dragOffset + moved * (container.list.contentHeight or 0) / trackH
    if NearestSnap(container.list.snaps or { 0 }, target) ~= NearestSnap(container.list.snaps or { 0 }, container.list.offset or 0) then
      GG.BonusRollTab:ScrollTo(target)
    end
  end)
  container.track.thumb = thumb
  container.track:Hide()

  container.empty = CreateText(container, 13, Theme.textFaint)
  container.empty:SetPoint("TOP", container.list, "TOP", 0, -40)
  container.empty:SetJustifyH("CENTER")
  container.empty:SetWordWrap(true)
  container.empty:SetWidth(560)

  container:Hide()
  return container
end

function GG.BonusRollTab:SetShown(shown)
  if not container then return end
  container:SetShown(shown)
  if shown then
    self:Refresh()
    C_Timer.After(0, function() GG.BonusRollTab:Refresh() end)
  end
end

function GG.BonusRollTab:Refresh()
  if not container or not container:IsShown() then return end

  local rows = GG.Roster:BuildRows()
  local withRolls = GG.BonusRoll:CharactersWithRolls(rows)
  UpdateCharacterOptions(withRolls)
  local duplicated, seen = {}, {}
  for _, row in ipairs(withRolls) do
    if seen[row.name] then duplicated[row.name] = true end
    seen[row.name] = true
  end

  local demo = GG.BonusRoll:IsDemo()
  container.demoBanner:SetShown(demo)
  container.view:ClearAllPoints()
  container.view:SetPoint("TOPLEFT", 10, demo and -42 or -10)
  container.count:ClearAllPoints()
  container.count:SetPoint("TOPRIGHT", -12, (demo and -42 or -10) - 36 - 6)

  PaintToggle(container.view, state.view)
  PaintToggle(container.content, state.content)

  local isRaid = state.content == "raid"
  container.difficulty:SetShown(isRaid)
  if isRaid and not state.difficulty then
    local latest = GG.BonusRoll:Collect(rows, { character = state.character, content = "raid" })[1]
    state.difficulty = latest and GG.BonusRoll:DifficultyBucket(latest.entry) or "mythic"
  end
  PaintToggle(container.difficulty, state.difficulty)

  local isLog = state.view == "log"
  container.head:SetShown(isLog)
  container.list:ClearAllPoints()
  container.list:SetPoint("TOPLEFT", isLog and container.head or container.rule, "BOTTOMLEFT", 0, isLog and -2 or -10)
  container.list:SetPoint("RIGHT", container, "RIGHT", -22, 0)
  container.list:SetPoint("BOTTOM", container, "BOTTOM", 0, 10)

  local collected = GG.BonusRoll:Collect(rows, { character = state.character, content = state.content,
    difficulty = isRaid and state.difficulty or nil })
  local rolls, items = 0, 0
  for _, item in ipairs(collected) do
    if not item.entry.secondary then rolls = rolls + 1 end
    if item.entry.kind == "item" then items = items + 1 end
  end
  local white = { 1, 1, 1, 1 }
  local function Bold(text, n)
    return (text:gsub(tostring(n), GG:ColorizeText(n, white), 1))
  end
  container.count:SetText(L["BR_COUNT"]:format(
    Bold(rolls == 1 and L["BR_ROLL_ONE"] or L["BR_ROLLS"]:format(rolls), rolls),
    Bold(items == 1 and L["BR_ITEM_ONE"] or L["BR_ITEMS"]:format(items), items)))

  local empty = #collected == 0
  container.empty:SetShown(empty)
  container.empty:SetText(#withRolls == 0 and L["BR_EMPTY"] or L["BR_EMPTY_FILTER"])
  container.head:SetShown(isLog and not empty)

  if isLog then
    for _, card in ipairs(container.cards) do card:Hide() end
    container.moreBelow:Hide()
    PaintLog(collected, duplicated)
  else
    for _, row in ipairs(container.logRows) do row:Hide() end
    local before = state.groupCount
    PaintBosses(collected, duplicated)
    if before ~= state.groupCount and GG.RosterUI and GG.RosterUI.Relayout then
      C_Timer.After(0, function() GG.RosterUI:Relayout() end)
    end
  end
  UpdateScrollbar()
end

function GG.BonusRollTab:PreferredWidth()
  if state.view ~= "boss" then return GG.BonusRollTab.CONTENT_WIDTH end
  local cols = math.max(2, math.min(3, state.groupCount or 3))
  return cols * CARD_W + (cols - 1) * CARD_GAP + 32
end
