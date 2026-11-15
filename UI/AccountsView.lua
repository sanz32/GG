local ADDON_NAME, GG = ...

local L = LibStub("AceLocale-3.0"):GetLocale("GG")

local AV = { cards = {}, bands = {} }
GG.AccountsView = AV

AV.PAD = 10
AV.BAND_HEAD = 32
AV.BAND_PAD = 8
AV.BAND_GAP = 18
AV.RIGHT_COL = 104

local Theme, Shared

local function Label(parent, size, color, bold, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size, "")
  fs:SetTextColor(color[1], color[2], color[3], color[4] or 1)
  fs:SetWordWrap(false)
  fs:SetJustifyH("LEFT")
  return fs
end

local function SetColor(tex, c, a)
  tex:SetColorTexture(c[1], c[2], c[3], a or c[4] or 1)
end

local function AccountColor(slot)
  local colors = Shared.CONST.ACCOUNT_COLORS
  return colors[((slot or 1) - 1) % #colors + 1]
end

local function ActiveDifficulties()
  local out = {}
  for _, id in ipairs(Shared.CONST.RAID_BAR_ORDER) do
    if Shared.IsRaidDifficultyVisible(id) then out[#out + 1] = id end
  end
  return out
end

function AV.Group(rows)
  local bySlot, list = {}, {}
  for _, datum in ipairs(rows or {}) do
    local slot = datum.accountSlot or 1
    local g = bySlot[slot]
    if not g then
      g = { slot = slot, label = datum.accountLabel or ("WoW " .. slot), rows = {} }
      bySlot[slot] = g
      list[#list + 1] = g
    end
    g.rows[#g.rows + 1] = datum
  end
  table.sort(list, function(a, b) return a.slot < b.slot end)
  return list
end

function AV.Measure(rows, availWidth)
  local LY = GG.Layout
  local groups = AV.Group(rows)
  local longest = 0
  for _, g in ipairs(groups) do longest = math.max(longest, #g.rows) end
  local cardH = LY.CardHeight(#ActiveDifficulties())
  local inner = (availWidth or 2000) - 2 * AV.PAD - 2 * AV.BAND_PAD
  local perRow = LY.CardsPerRow(math.max(1, longest), inner)
  local width = 2 * AV.PAD + 2 * AV.BAND_PAD + LY.CardGridWidth(perRow)
  local height = AV.PAD
  for i, g in ipairs(groups) do
    local lines = LY.CardRows(#g.rows, perRow)
    height = height + AV.BAND_HEAD + lines * (cardH + LY.CARD_GAP) - LY.CARD_GAP + AV.BAND_PAD
    if i < #groups then height = height + AV.BAND_GAP end
  end
  height = height + AV.PAD
  return width, height, perRow, cardH
end

function AV:Attach(clip)
  if self.scroll then return end
  Theme = GG.Theme
  Shared = GG.RosterUI.Shared
  local scroll = CreateFrame("ScrollFrame", nil, clip)
  scroll:SetAllPoints(clip)
  local canvas = CreateFrame("Frame", nil, scroll)
  canvas:SetSize(1, 1)
  scroll:SetScrollChild(canvas)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(s, delta)
    local max = math.max(0, canvas:GetHeight() - s:GetHeight())
    s:SetVerticalScroll(math.max(0, math.min(max, s:GetVerticalScroll() - delta * 60)))
  end)
  scroll:Hide()
  self.scroll, self.canvas = scroll, canvas
end

function AV:SetShown(shown)
  if self.scroll then self.scroll:SetShown(shown) end
end

local function NewBand(parent)
  local b = CreateFrame("Frame", nil, parent)
  GG.Widgets.Backdrop(b, { 0.047, 0.051, 0.067, 1 }, { 1, 1, 1, 0.2 }, 10)
  b.head = GG.Widgets.TopBand(b, 1, 10, AV.BAND_HEAD - 1, "BACKGROUND", 1)
  b.edge = b:CreateTexture(nil, "BORDER")
  b.edge:SetPoint("TOPLEFT", 0, -10)
  b.edge:SetPoint("BOTTOMLEFT", 0, 10)
  b.edge:SetWidth(3)
  b.chip = CreateFrame("Frame", nil, b)
  b.chip:SetHeight(18)
  b.chip:SetPoint("LEFT", b, "TOPLEFT", 12, -AV.BAND_HEAD / 2)
  b.chip.bg = GG.Widgets.RoundedFill(b.chip, b.chip, 9, "BACKGROUND")
  b.chip.text = Label(b.chip, 12, Theme.textPrimary, true)
  b.chip.text:SetPoint("CENTER")
  b.freshDot = b:CreateTexture(nil, "ARTWORK")
  b.freshDot:SetSize(10, 10)
  b.freshDot:SetPoint("LEFT", b.chip, "RIGHT", 10, 0)
  b.fresh = Label(b, 12, Theme.textFaint, true)
  b.fresh:SetPoint("LEFT", b.freshDot, "RIGHT", 5, 0)
  b.summary = Label(b, 12, Theme.textFaint)
  b.summary:SetPoint("RIGHT", b, "TOPRIGHT", -12, -AV.BAND_HEAD / 2)
  b.summary:SetJustifyH("RIGHT")
  return b
end

local function PaintBand(b, g, bestIlvl)
  local c = AccountColor(g.slot)
  SetColor(b.edge, c, 1)
  b:SetBackdropBorderColor(c[1], c[2], c[3], 0.38)
  b.head:SetGradientV(c[1], c[2], c[3], 0.13, 0.05)
  b.chip.bg:SetColor(c[1], c[2], c[3], 0.18)
  b.chip.text:SetText(g.label)
  b.chip.text:SetTextColor(c[1], c[2], c[3], 1)
  local tw = b.chip.text:GetStringWidth()
  if not tw or tw <= 0 then tw = GG.Layout.EstimateWidth(g.label, 12) end
  b.chip:SetWidth(tw + 20)

  local live, age = false, nil
  for _, d in ipairs(g.rows) do
    local f = d.freshness
    if not f or f.live then
      live = true
    elseif f.age then
      age = age and math.min(age, f.age) or f.age
    end
  end
  if live then
    b.freshDot:SetTexture(Theme.media.dot)
    b.freshDot:SetSize(7, 7)
    b.freshDot:SetVertexColor(Theme.success[1], Theme.success[2], Theme.success[3], 1)
    b.fresh:SetText(L["FRESH_LIVE"])
    b.fresh:SetTextColor(unpack(Theme.success))
  else
    local f = { age = age or 0, stale = (age or 0) > GG.Roster.STALE_AFTER_SECONDS }
    local words, color, icon = Shared.FreshnessText(f)
    b.freshDot:SetTexture(icon)
    b.freshDot:SetSize(11, 11)
    b.freshDot:SetVertexColor(color[1], color[2], color[3], 1)
    b.fresh:SetText(words)
    b.fresh:SetTextColor(color[1], color[2], color[3], 1)
  end

  local rewards = 0
  for _, d in ipairs(g.rows) do if d.vault and d.vault.hasAvailableRewards then rewards = rewards + 1 end end
  local white = "|cffe8e8ee%s|r"
  local parts = { L["AV_SUMMARY_CHARS"]:format(white:format(#g.rows)) }
  if rewards > 0 then parts[#parts + 1] = L["AV_SUMMARY_REWARDS"]:format(("|cff35d0ba%d|r"):format(rewards)) end
  parts[#parts + 1] = L["AV_SUMMARY_BEST"]:format(white:format(Shared.FormatIlvl(bestIlvl or 0)))
  b.summary:SetText(table.concat(parts, "     "))
end

local function Hitbox(parent, onEnter, onClick)
  local h = CreateFrame("Button", nil, parent)
  h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  if onEnter then h:SetScript("OnEnter", onEnter) end
  h:SetScript("OnLeave", function()
    GameTooltip:Hide()
    if GG.CharacterTooltip then GG.CharacterTooltip:Hide() end
  end)
  if onClick then h:SetScript("OnClick", onClick) end
  return h
end

local function IdentityClick(card, button)
  local d = card.datum
  if not d then return end
  if button == "LeftButton" and IsShiftKeyDown() then
    if GG.Links then GG.Links:InsertCharacterLink(d) end
  elseif button == "RightButton" then
    GG.RosterUI:ConfirmHideCharacter(d.key, d.name, d.realm)
  elseif d.rawRecord and GG.UI and GG.UI.ShowEquipmentWindow then
    GG.UI:ShowEquipmentWindow(d.rawRecord)
  end
end

function AV.RaidColumns(byDifficulty, order, isVisible, count)
  byDifficulty = byDifficulty or {}
  count = count or 2
  local out = {}
  for i = #(order or {}), 1, -1 do
    local id = order[i]
    if #out < count and (not isVisible or isVisible(id)) then
      local p = byDifficulty[id] or {}
      local killed = p.killed or 0
      table.insert(out, 1, { id = id, killed = killed, total = math.max(p.total or 0, #(p.slots or {}), killed) })
    end
  end
  return out
end

function AV.PickMoney(record, defs, itemExists, forDisplay)
  local out = {}
  record = record or {}
  for _, def in ipairs(defs or {}) do
    local key = tostring(def.id)
    if def.kind == "item" then
      if not itemExists or itemExists(def.id) then
        out[#out + 1] = { kind = "item", id = def.id, data = record.items and record.items[key] or nil }
      end
    else
      local raw = record.currencies and record.currencies[key]
      local data = raw and (forDisplay and forDisplay(raw) or raw) or nil
      out[#out + 1] = { kind = "currency", id = def.id, data = data }
    end
  end
  return out
end

function AV.MoneyAnchors(n, width, pad)
  local out = {}
  for i = 1, n do
    if i == 1 then
      out[i] = { point = "LEFT", x = pad }
    elseif i == n then
      out[i] = { point = "RIGHT", x = -pad }
    else
      out[i] = { point = "CENTER", x = pad + (width - 2 * pad) * (i - 1) / (n - 1) }
    end
  end
  return out
end

local MONEY_SLOTS = 4
local EDGE = 10
local RAID_COLUMNS, RAID_COL_W = 2, 52
local PIP, PIP_GAP, PIP_GROUP = 9, 3, 6
local REWARD_INK = { 0.06, 0.16, 0.11, 1 }
local KEY_HEX = "35d0ba"

local function NewCard(parent)
  local LY = GG.Layout
  local c = CreateFrame("Frame", nil, parent)
  c:SetFrameLevel(parent:GetFrameLevel() + 3)
  c:SetSize(LY.CARD_WIDTH, LY.CardHeight())

  c.curBox = CreateFrame("Frame", nil, c)
  c.curBox:SetPoint("TOPLEFT", -1.5, 1.5)
  c.curBox:SetPoint("BOTTOMRIGHT", 1.5, -1.5)
  c.cur = GG.Widgets.RoundedFill(c, c.curBox, 10, "BACKGROUND", -3)
  c.bg = GG.Widgets.RoundedFill(c, c, 9, "BACKGROUND", -1)
  c.bg:SetColor(Theme.panel)
  c.tint = GG.Widgets.RoundedFill(c, c, 9, "BACKGROUND", 0)

  c.portrait = CreateFrame("Frame", nil, c)
  c.portrait:SetSize(38, 38)
  c.portrait:SetPoint("LEFT", c, "TOPLEFT", 8, -LY.CARD_BAND_TOP / 2)
  c.mainBox = CreateFrame("Frame", nil, c.portrait)
  c.mainBox:SetPoint("TOPLEFT", -2, 2)
  c.mainBox:SetPoint("BOTTOMRIGHT", 2, -2)
  c.mainFill = GG.Widgets.RoundedFill(c.portrait, c.mainBox, 10, "BACKGROUND")
  c.mainFill:SetColor(Theme.gold)
  c.mainGlow = c.portrait:CreateTexture(nil, "BACKGROUND", nil, -1)
  c.mainGlow:SetTexture(Theme.media.glowHalo)
  c.mainGlow:SetDesaturated(true)
  c.mainGlow:SetBlendMode("ADD")
  c.mainGlow:SetVertexColor(Theme.gold[1], Theme.gold[2], Theme.gold[3], 0.45)
  c.mainGlow:SetPoint("TOPLEFT", -10, 10)
  c.mainGlow:SetPoint("BOTTOMRIGHT", 10, -10)
  c.ring = GG.Widgets.RoundedFill(c.portrait, c.portrait, 9, "BORDER")
  c.icon = c.portrait:CreateTexture(nil, "ARTWORK")
  c.icon:SetPoint("TOPLEFT", 1, -1)
  c.icon:SetPoint("BOTTOMRIGHT", -1, 1)
  c.iconMask = c.portrait:CreateMaskTexture()
  c.iconMask:SetTexture(Theme.media.roundMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  c.iconMask:SetAllPoints(c.icon)
  c.icon:AddMaskTexture(c.iconMask)
  c.star = c.portrait:CreateTexture(nil, "OVERLAY", nil, 2)
  c.star:SetTexture(Theme.media.star)
  c.star:SetSize(11, 11)
  c.star:SetVertexColor(unpack(Theme.gold))
  c.starDisc = c.portrait:CreateTexture(nil, "OVERLAY", nil, 1)
  c.starDisc:SetTexture(Theme.media.dot)
  c.starDisc:SetSize(17, 17)
  c.starDisc:SetVertexColor(0.165, 0.129, 0.071, 1)
  c.starRim = c.portrait:CreateTexture(nil, "OVERLAY")
  c.starRim:SetTexture(Theme.media.dot)
  c.starRim:SetSize(20, 20)
  c.starRim:SetVertexColor(unpack(Theme.gold))
  c.lvl = CreateFrame("Frame", nil, c.portrait)
  c.lvl:SetHeight(12)
  c.lvl:SetPoint("CENTER", c.portrait, "BOTTOM", 0, -1)
  c.lvl:SetFrameLevel(c.portrait:GetFrameLevel() + 2)
  c.lvl.bg = GG.Widgets.RoundedFill(c.lvl, c.lvl, 6, "BACKGROUND")
  c.lvl.bg:SetColor(0.055, 0.059, 0.075, 1)
  c.lvl.text = Label(c.lvl, 10, Theme.textMuted, true)
  c.lvl.text:SetPoint("CENTER")

  c.name = Label(c, 17, Theme.textPrimary, true)
  c.line = Label(c, 12, Theme.textFaint)
  c.lineFade = Label(c, 12, Theme.textFaint)
  c.lineFade:Hide()
  c.nameStar = c:CreateTexture(nil, "OVERLAY")
  c.nameStar:SetTexture(Theme.media.star)
  c.nameStar:SetSize(12, 12)
  c.nameStar:SetVertexColor(unpack(Theme.gold))
  c.tag = GG.RaidRostersTab and GG.RaidRostersTab.CreateTag(c, false) or nil
  if c.tag then
    Shared.RoundRosterTag(c.tag)
    c.tag:Hide()
  end

  local ilvlColor = Shared.CONST.ILVL_COLOR
  c.ilvlDec = Label(c, 13, { ilvlColor[1], ilvlColor[2], ilvlColor[3], 0.6 }, true)
  c.ilvlDec:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", -10, -27)
  c.ilvl = Label(c, 22, ilvlColor, true)
  c.ilvl:SetJustifyH("RIGHT")
  c.ilvl:SetPoint("BOTTOMRIGHT", c.ilvlDec, "BOTTOMLEFT", 0, -GG.Layout.DecimalLift(22, 13))
  c.rating = Label(c, 13, Theme.textPrimary, true)
  c.rating:SetJustifyH("RIGHT")
  c.rating:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -31)

  c.idHit = Hitbox(c, function(self)
    if c.datum and not Shared.IsDragEditMode() then
      GG.CharacterTooltip:Show(self, function() return c.datum end, self)
    end
  end, function(_, button) IdentityClick(c, button) end)
  c.idHit:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
  c.idHit:SetPoint("BOTTOMRIGHT", c, "TOPRIGHT", -AV.RIGHT_COL - 8, -LY.CARD_BAND_TOP)
  c.ilvlHit = Hitbox(c, nil, function(_, button) IdentityClick(c, button) end)
  c.ilvlHit:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
  c.ilvlHit:SetSize(AV.RIGHT_COL + 8, 29)
  c.ratingHit = Hitbox(c, function(self)
    local d = c.datum
    if not d then return end
    if d.keystone then Shared.ShowKeystoneTooltip(self, d.rawRecord) else Shared.ShowRatingTooltip(self, d.rawRecord) end
  end)
  c.ratingHit:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -29)
  c.ratingHit:SetSize(AV.RIGHT_COL + 8, LY.CARD_BAND_TOP - 29)

  for i, y in ipairs({ LY.CARD_BAND_TOP, LY.CARD_BAND_TOP + LY.CARD_BAND_WEEK }) do
    local r = c:CreateTexture(nil, "ARTWORK")
    r:SetColorTexture(1, 1, 1, 0.06)
    r:SetHeight(1)
    r:SetPoint("TOPLEFT", c, "TOPLEFT", 10, -y)
    r:SetPoint("TOPRIGHT", c, "TOPRIGHT", -10, -y)
    c["rule" .. i] = r
  end

  local y2 = -(LY.CARD_BAND_TOP + LY.CARD_BAND_WEEK / 2)
  c.vaultLabel = Label(c, 10, Theme.textFaint, true)
  c.vaultLabel:SetPoint("LEFT", c, "TOPLEFT", 10, y2)
  c.vaultLabel:SetText(L["AV_VAULT"])
  c.vault = Hitbox(c, function(self)
    if c.datum then Shared.ShowVaultTooltip(self, c.datum.rawRecord) end
  end, function()
    if c.datum and c.datum.rawRecord and GG.UI and GG.UI.ShowVaultPreview then GG.UI:ShowVaultPreview(c.datum.rawRecord) end
  end)
  c.vault:SetSize(3 * (3 * PIP + 2 * PIP_GAP) + 2 * PIP_GROUP, 20)
  c.vault:SetPoint("LEFT", c, "TOPLEFT", 46, y2)
  c.vaultCells = {}
  for tier = 1, 3 do
    c.vaultCells[tier] = {}
    for slot = 1, 3 do
      local t = GG.Widgets.NewRoundTexture(c.vault, "ARTWORK")
      GG.Widgets.ApplyRound(t, "RoundFill", 2)
      t:SetSize(PIP, PIP)
      t:SetPoint("LEFT", c.vault, "LEFT", (tier - 1) * (3 * PIP + 2 * PIP_GAP + PIP_GROUP) + (slot - 1) * (PIP + PIP_GAP), 0)
      c.vaultCells[tier][slot] = t
    end
  end
  c.reward = CreateFrame("Frame", nil, c.vault)
  c.reward:SetHeight(18)
  c.reward:SetPoint("LEFT", c.vault, "LEFT", 0, 0)
  c.reward.bg = GG.Widgets.RoundedFill(c.reward, c.reward, 9, "BACKGROUND")
  c.reward.text = Label(c.reward, 11, REWARD_INK, true)
  c.reward.text:SetPoint("CENTER")
  c.reward.text:SetText(L["AV_REWARD_READY"])
  c.reward:Hide()

  c.raids = {}
  for i = 1, RAID_COLUMNS do
    local r = Hitbox(c, function(self)
      if c.datum and self.diffID then Shared.ShowRaidTooltip(self, c.datum.rawRecord, self.diffID) end
    end)
    r:SetSize(RAID_COL_W - 4, 20)
    r:SetPoint("RIGHT", c, "TOPRIGHT", -(EDGE + (RAID_COLUMNS - i) * RAID_COL_W), y2)
    r.text = Label(r, 12, Theme.textFaint, true)
    r.text:SetJustifyH("RIGHT")
    r.text:SetPoint("RIGHT")
    c.raids[i] = r
  end

  local y3 = -(LY.CARD_BAND_TOP + LY.CARD_BAND_WEEK + LY.CARD_BAND_BOTTOM / 2)
  c.money = {}
  c.moneyY = y3
  for i = 1, MONEY_SLOTS do
    local m = CreateFrame("Frame", nil, c)
    m:EnableMouse(true)
    m:SetSize(60, 18)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetSize(16, 16)
    m.icon:SetPoint("LEFT")
    m.text = Label(m, 13, Theme.textPrimary, true)
    m.text:SetPoint("LEFT", m.icon, "RIGHT", 5, 0)
    m:SetScript("OnEnter", function(self)
      local entry = self.entry
      if not entry then return end
      GG.Tip:Open(self, { family = "money", anchor = "TOP" }, function(t)
        if entry.kind == "currency" and entry.data then
          GG.Tip.DrawCurrency(t, entry.data, L)
        else
          t:Head({ title = self.name or "?", right = entry.data and entry.data.quantity or 0 })
        end
      end)
    end)
    m:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m:Hide()
    c.money[i] = m
  end
  return c
end

local function PaintIdentity(c, d, showPortrait)
  local LY = GG.Layout
  local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[d.class]
  local class = cc and { cc.r, cc.g, cc.b } or Theme.textPrimary
  local isMain = d.isMain == true

  c.portrait:SetShown(showPortrait)
  local x = 8
  if showPortrait then
    x = 8 + 38 + 8
    GG.Widgets.SetClassIcon(c.icon, CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[d.class])
    c.ring:SetColor(class[1], class[2], class[3], 0.6)
    c.mainFill:SetShown(isMain)
    c.mainGlow:SetShown(isMain)
    for _, t in ipairs({ c.star, c.starDisc, c.starRim }) do
      t:ClearAllPoints()
      t:SetPoint("CENTER", c.portrait, "TOPRIGHT", 0, 0)
      t:SetShown(isMain)
    end
    c.starRim:SetSize(19, 19)
    c.starDisc:SetSize(16, 16)
    c.lvl:SetShown((d.level or 0) > 0)
    c.lvl.text:SetText(d.level or "")
    local lw = c.lvl.text:GetStringWidth()
    if not lw or lw <= 0 then lw = 12 end
    c.lvl:SetWidth(lw + 8)
  end

  local tagW = 0
  local tags = (c.tag and GG.RaidRostersTab:TagsVisible()) and GG.RaidRosters:TagsFor(d.key, d.rawRecord) or {}
  if c.tag and tags[1] then
    GG.RaidRostersTab.PaintTag(c.tag, tags[1])
    c.tag:Show()
    tagW = (c.tag:GetWidth() or 0) + 6
  elseif c.tag then
    c.tag:Hide()
  end
  local starW = (isMain and not showPortrait) and 16 or 0
  local avail = LY.CARD_WIDTH - x - AV.RIGHT_COL - 8 - 8
  local size = LY.NameFontSize(d.name or "", avail - tagW - starW, AV.MeasureName)
  c.name:SetFont(Theme.fontBold, size, "")
  c.name:SetText(d.name or "")
  c.name:SetTextColor(class[1], class[2], class[3], 1)
  c.name:ClearAllPoints()
  c.name:SetPoint("BOTTOMLEFT", c, "TOPLEFT", x + starW, -26)
  c.nameStar:ClearAllPoints()
  c.nameStar:SetPoint("RIGHT", c.name, "LEFT", -3, 0)
  c.nameStar:SetShown(isMain and not showPortrait)
  if c.tag and c.tag:IsShown() then
    local nw = c.name:GetStringWidth()
    if not nw or nw <= 0 then nw = LY.EstimateWidth(d.name or "", size) end
    c.tag:ClearAllPoints()
    c.tag:SetPoint("LEFT", c.name, "LEFT", nw + 6, 0)
  end

  local plain = d.realm or ""
  local colored = plain
  if not showPortrait and (d.level or 0) > 0 then
    plain = plain .. " · " .. d.level
    colored = plain
  end
  if d.guild and d.guild ~= "" and Shared.IsSectionVisible("guild") then
    plain = plain .. " · " .. d.guild
    colored = colored .. " · |cff62d39a" .. d.guild .. "|r"
  end
  local lineAvail = LY.CARD_WIDTH - x - AV.RIGHT_COL - 8 - 8
  local chars, over = LY.FitChars(plain, lineAvail, AV.MeasureLine, 12)
  for _, fs in ipairs({ c.line, c.lineFade }) do
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", c, "TOPLEFT", x, -29)
  end
  if over and c.lineFade.SetAlphaGradient then
    c.line:SetText(" ")
    c.lineFade:SetText(colored)
    c.lineFade:SetAlphaGradient(math.max(0, chars - 3), 4)
    c.lineFade:Show()
  else
    c.line:SetText(colored)
    c.lineFade:Hide()
  end

  c.tint:SetColor(class[1], class[2], class[3], 0.06)
  local a = Theme.accent
  c.cur:SetColor(a[1], a[2], a[3], 0.75)
  c.cur:SetShown(d.isCurrent == true)
end

local function PaintNumbers(c, d)
  local LY = GG.Layout
  local whole, decimals = LY.SplitIlvl(d.ilvl or 0)
  c.ilvl:SetText(whole)
  c.ilvlDec:SetText(decimals)
  local rating = d.rating or 0
  local text = rating > 0 and tostring(rating) or "—"
  if d.keystone and d.keystone.level then
    text = ("%s  |cff%s+%d %s|r"):format(text, KEY_HEX, d.keystone.level,
      Shared.AbbreviateDungeonName(d.keystone.challengeModeID, d.keystone.dungeon) or "")
  end
  c.rating:SetText(text)
  local col = rating <= 0 and Theme.textFaint or (rating >= 2000 and Theme.gold or Theme.textPrimary)
  c.rating:SetTextColor(col[1], col[2], col[3], 1)
end

local function PaintWeek(c, d)
  local record = d.rawRecord
  local rewards = d.vault and d.vault.hasAvailableRewards == true
  c.reward:SetShown(rewards)
  if rewards then
    local s = Theme.success
    c.reward.bg:SetColor(s[1], s[2], s[3], 1)
    local tw = c.reward.text:GetStringWidth()
    if not tw or tw <= 0 then tw = GG.Layout.EstimateWidth(L["AV_REWARD_READY"], 11) end
    c.reward:SetWidth(tw + 18)
  end
  local current = GG.Vault and GG.Vault.IsCurrentWeek and GG.Vault:IsCurrentWeek(record)
  local tierColors = { nil, Theme.teal, Theme.gold }
  for tier, def in ipairs(Shared.CONST.VAULT_TIER_TYPES) do
    local slots = Shared.CollectVaultTierSlots(record, def.type)
    for slot = 1, 3 do
      local t = c.vaultCells[tier] and c.vaultCells[tier][slot]
      if t then
        local sd = slots[slot]
        if current and sd and sd.unlocked then
          local _, color = Shared.VaultSlotDisplay(sd)
          local col = tierColors[tier] or color
          t:SetVertexColor(col[1], col[2], col[3], 0.95)
        else
          t:SetVertexColor(1, 1, 1, 0.09)
        end
        t:SetShown(not rewards)
      end
    end
  end

  local progress = d.raidProgress and d.raidProgress.byDifficulty or {}
  local cols = AV.RaidColumns(progress, Shared.CONST.RAID_BAR_ORDER, Shared.IsRaidDifficultyVisible, RAID_COLUMNS)
  for i, r in ipairs(c.raids) do
    local col = cols[i]
    r.diffID = col and col.id or nil
    if col then
      local def = Shared.CONST.RAID_DIFFICULTY_DEFS[col.id]
      local color = (col.killed > 0 and def and def.color) or Theme.textFaint
      r.text:SetText(("%s %d/%s"):format(def and def.abbr or "?", col.killed, col.total > 0 and col.total or "-"))
      r.text:SetTextColor(color[1], color[2], color[3], 1)
      r:Show()
    else
      r:Hide()
    end
  end
end

local function MoneyIcon(entry)
  local icon = entry.data and entry.data.iconFileID
  if icon and icon ~= 0 then return icon end
  if entry.kind == "item" then
    return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(entry.id)
  end
  local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(entry.id)
  return info and info.iconFileID
end

local function MoneyName(entry)
  if entry.data and entry.data.name then return entry.data.name end
  if entry.kind == "item" then
    return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(entry.id)
  end
  local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(entry.id)
  return info and info.name
end

local function PaintMoney(c, d)
  local CG = Shared.CurrencyGrid
  local zero = Shared.CONST.ZERO_COLOR
  local list = AV.PickMoney(d.rawRecord, GG.Season and GG.Season.ACCOUNT_CARD_MONEY,
    function(id) return GG.Currencies:ItemExists(id) end,
    function(raw) return GG.Currencies:ForDisplay(raw, d.rawRecord) end)
  local anchors = AV.MoneyAnchors(math.min(#list, #c.money), GG.Layout.CARD_WIDTH, EDGE)
  for i, m in ipairs(c.money) do
    local entry = list[i]
    m.entry = entry
    if entry then
      GG.Widgets.SetItemIcon(m.icon, MoneyIcon(entry))
      m.name = MoneyName(entry)
      local quantity = entry.data and entry.data.quantity or 0
      local amount = GG.Currencies:FormatAmount(quantity, L["NUMBER_DECIMAL_SEPARATOR"])
      m.text:SetText(amount)
      local atCap = entry.kind == "currency" and entry.data and GG.Currencies:IsAtCap(entry.data)
      local color = (quantity == 0 and zero) or (atCap and CG.CAP_COLOR) or Theme.textPrimary
      m.text:SetTextColor(color[1], color[2], color[3], 1)
      m.icon:SetAlpha(quantity == 0 and 0.4 or 1)
      local tw = m.text:GetStringWidth()
      if not tw or tw <= 0 then tw = GG.Layout.EstimateWidth(amount, 13) end
      m:SetWidth(16 + 5 + tw)
      local a = anchors[i]
      m:ClearAllPoints()
      if a.point == "RIGHT" then
        m:SetPoint("RIGHT", c, "TOPRIGHT", a.x, c.moneyY)
      else
        m:SetPoint(a.point, c, "TOPLEFT", a.x, c.moneyY)
      end
      m:Show()
    else
      m:Hide()
    end
  end
end

function AV.MeasureRaw(text, size, font)
  local fs = AV.measureFS
  fs:SetFont(font, size, "")
  fs:SetText(text)
  return fs:GetStringWidth()
end
function AV.MeasureName(text, size) return GG.Layout.CachedWidth(AV.MeasureRaw, text, size, Theme.fontBold) end
function AV.MeasureLine(text) return GG.Layout.CachedWidth(AV.MeasureRaw, text, 12, Theme.font) end

local function PaintCard(c, d)
  c.datum = d
  c:SetHeight(GG.Layout.CardHeight())
  PaintIdentity(c, d, Shared.IsSectionVisible("avatar"))
  PaintNumbers(c, d)
  PaintWeek(c, d)
  PaintMoney(c, d)
  c:SetAlpha(d.excluded and 0.42 or 1)
end

function AV:Render(rows, availWidth)
  if not self.canvas then return end
  Theme = GG.Theme
  if not self.measureFS then
    self.measureFS = UIParent:CreateFontString(nil, "OVERLAY")
    self.measureFS:Hide()
    AV.measureFS = self.measureFS
  end
  local LY = GG.Layout
  local width, height, perRow, cardH = AV.Measure(rows, availWidth)
  local diffs = ActiveDifficulties()
  local showPortrait = Shared.IsSectionVisible("avatar")
  self.canvas:SetSize(width, height)
  self.width, self.height = width, height
  local a = Theme.accent
  local paintCommon = table.concat({ table.concat(diffs, ","), tostring(showPortrait), a[1], a[2], a[3],
    tostring(Theme.font), tostring(GG.RaidRostersTab and GG.RaidRostersTab:TagsVisible()),
    tostring(Shared.IsSectionVisible("guild")), tostring(GG.BossIcons and GG.BossIcons:GetStyle()),
    tostring(Shared.QuestChecks()), AV.paintGen or 0 }, "|")

  local y = AV.PAD
  local cardIndex = 0
  local groups = AV.Group(rows)
  for gi, g in ipairs(groups) do
    local band = self.bands[gi]
    if not band then
      band = NewBand(self.canvas)
      self.bands[gi] = band
    end
    local lines = LY.CardRows(#g.rows, perRow)
    local bandH = AV.BAND_HEAD + lines * (cardH + LY.CARD_GAP) - LY.CARD_GAP + AV.BAND_PAD
    band:ClearAllPoints()
    band:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", AV.PAD, -y)
    band:SetSize(width - 2 * AV.PAD, bandH)
    local best = 0
    for _, d in ipairs(g.rows) do best = math.max(best, d.ilvl or 0) end
    PaintBand(band, g, best)
    band:Show()
    for i, d in ipairs(g.rows) do
      cardIndex = cardIndex + 1
      local card = self.cards[cardIndex]
      if not card then
        card = NewCard(self.canvas)
        self.cards[cardIndex] = card
      end
      local cx, cy = LY.CardPosition(i, perRow, cardH)
      card:ClearAllPoints()
      card:SetPoint("TOPLEFT", band, "TOPLEFT", AV.BAND_PAD + cx, -(AV.BAND_HEAD + cy))
      local paintKey = tostring(d) .. "|" .. paintCommon
      if card.paintKey ~= paintKey then
        PaintCard(card, d)
        card.paintKey = paintKey
      end
      card:Show()
    end
    y = y + bandH + AV.BAND_GAP
  end
  for i = #groups + 1, #self.bands do self.bands[i]:Hide() end
  for i = cardIndex + 1, #self.cards do
    self.cards[i].datum = nil
    self.cards[i].paintKey = nil
    self.cards[i]:Hide()
  end
  if self.scroll then
    local max = math.max(0, height - (self.scroll:GetHeight() or 0))
    if self.scroll:GetVerticalScroll() > max then self.scroll:SetVerticalScroll(max) end
  end
end
