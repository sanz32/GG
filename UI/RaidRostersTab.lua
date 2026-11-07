local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

GG.RaidRostersTab = {}
local Tab = GG.RaidRostersTab

local Theme
local container
local WHITE = "Interface\\Buttons\\WHITE8x8"
local NAV_BG = { 0.063, 0.071, 0.090, 1 }
local LEFT_W = 300
local CREATE_LEFT_W = 330
local CARD_W, CARD_H, CARD_GAP = 232, 150, 10
local MEMBER_COLS, MEMBER_H = 3, 22
local MINE_ROW_H = 40
local SEARCH_SECONDS = 5
local ILVL_COLOR = { 0.64, 0.21, 0.93, 1 }

local function AgeText(at)
  local s = math.max(0, GetServerTime() - at)
  if s < 3600 then return ("%d min"):format(math.floor(s / 60)) end
  if s < 86400 then return ("%d h"):format(math.floor(s / 3600)) end
  return ("%d d"):format(math.floor(s / 86400))
end
Tab.CONTENT_WIDTH = CREATE_LEFT_W + 16 + 3 * CARD_W + 2 * CARD_GAP + 16

local state = {
  sub = "list", mode = "all", sel = 1, query = "",
  textAll = "", allGroups = {}, oneName = "", oneText = "", oneList = {},
  modal = nil, cardsOffset = 0, mineOffset = 0,
  autoSel = false, searchUntil = 0,
}

local function RR() return GG.RaidRosters end

local function CreateText(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and Theme.fontBold or Theme.font, size, "")
  fs:SetTextColor(unpack(color))
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

local function SetBackdrop(f, bg, border)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  f:SetBackdropColor(unpack(bg))
  f:SetBackdropBorderColor(unpack(border or Theme.borderSoft))
end

local function Fade(c, a) return { c[1], c[2], c[3], a } end

local measureFS
local function TextMax(big)
  measureFS = measureFS or UIParent:CreateFontString(nil, "OVERLAY")
  measureFS:SetFont(GG.Theme.fontBold, big and 13 or 11, "")
  measureFS:SetText("Mythic 88")
  return math.max(30, math.ceil(measureFS:GetStringWidth()) + 2)
end

function Tab.TagMaxWidth(big)
  return TextMax(big) + (big and 26 or 22)
end

local function ShowTagTooltip(self)
  local e = self.entry
  if not e then return end
  local rr = RR()
  local g = self.forming
  GG.Tip:Open(self, { family = "roster" }, function(t)
    t:Head({ kicker = rr:DifficultyName(e.diff) .. " · " .. rr:RaidName(e.raid), title = e.label })
    t:Status(L["TIP_THIS_CHAR"], e.saved and L["RR_TAG_SAVED"] or L["RR_TAG_FREE"], e.saved and "bad" or "done")
    if e.set then
      t:Text(L["RR_PUBLISHED_BY"]:format(RR().PublisherName(e.set), date("%a %H:%M", e.set.publishedAt or 0)), Theme.textFaint, true)
    end
    if g and not Tab.IsInsideFor(g, e.key) then
      t:Text(L["RR_TAG_CLICK_INVITE"]:format(g.leader), Theme.success)
    else
      if g then t:Text(L["RG_INSIDE"], Theme.success) end
      t:Action(L["TOOLTIP_CLICK"], L["TIP_VIEW_ROSTER"])
    end
  end)
end

function Tab.FormingGroup(roster)
  local RG = GG.RaidGroups
  if not (RG and roster and roster.members) then return nil end
  local groups = RG:Groups()
  if #groups == 0 then return nil end
  return RG.BestGroupFor(roster.members, groups)
end

function Tab.IsInsideFor(g, characterKey)
  if GG.RaidGroups:IsInside(g) then return true end
  local k = characterKey and RR().NameKey(characterKey)
  return k ~= nil and g.keys[k] == true
end

function Tab.AutoPick(count, bestOf, mineByRoster)
  local pick
  for i = 1, count do
    if bestOf[i] and (not pick or (mineByRoster[i] and not mineByRoster[pick])) then pick = i end
  end
  return pick
end

function Tab.OnTagClick(tag)
  local e = tag.entry
  local best = Tab.FormingGroup(e.roster)
  local RG = GG.RaidGroups
  if best and not Tab.IsInsideFor(best.group, e.key) then
    if RG.InRoster(e.roster.members, GG:GetCharacterKey()) then
      if Tab.SendInvite(best.group) then print("|cff8B5CF6GG|r " .. L["RR_TAG_SENT"]:format(best.group.leader)) end
      return
    end
    Tab:OpenRoster(e.roster, best.group)
    return
  end
  Tab:OpenRoster(e.roster)
end

local SWEEP_SECONDS, SWEEP_WIDTH = 1.8, 0.4
local function PulseTag(self)
  local s, t = Theme.success, GetTime()
  local p = 0.5 + 0.5 * math.sin(t * 5)
  self:SetBackdropBorderColor(s[1], s[2], s[3], 0.55 + 0.45 * p)
  self.halo:SetBackdropBorderColor(s[1], s[2], s[3], 0.45 * p)
  self.dot:SetAlpha(0.35 + 0.65 * p)
  local w = self:GetWidth()
  local phase = (t % SWEEP_SECONDS) / SWEEP_SECONDS
  self.sweep:SetWidth(w * SWEEP_WIDTH)
  self.sweep:SetPoint("LEFT", self.sweepClip, "LEFT", w * (-0.5 + 1.6 * phase), 0)
end

local function BuildPulse(tag)
  local s = Theme.success
  tag.halo = CreateFrame("Frame", nil, tag, "BackdropTemplate")
  tag.halo:SetPoint("TOPLEFT", -2, 2)
  tag.halo:SetPoint("BOTTOMRIGHT", 2, -2)
  tag.halo:SetBackdrop({ edgeFile = WHITE, edgeSize = 2 })
  tag.halo:EnableMouse(false)
  tag.sweepClip = CreateFrame("Frame", nil, tag)
  tag.sweepClip:SetPoint("TOPLEFT", 2, -2)
  tag.sweepClip:SetPoint("BOTTOMRIGHT", -2, 2)
  tag.sweepClip:SetClipsChildren(true)
  tag.sweepClip:EnableMouse(false)
  tag.sweep = CreateFrame("Frame", nil, tag.sweepClip)
  tag.sweep:SetPoint("TOP", tag.sweepClip, "TOP")
  tag.sweep:SetPoint("BOTTOM", tag.sweepClip, "BOTTOM")
  local fadeIn = tag.sweep:CreateTexture(nil, "ARTWORK")
  fadeIn:SetPoint("TOPLEFT")
  fadeIn:SetPoint("BOTTOMRIGHT", tag.sweep, "BOTTOM")
  local fadeOut = tag.sweep:CreateTexture(nil, "ARTWORK")
  fadeOut:SetPoint("TOPLEFT", tag.sweep, "TOP")
  fadeOut:SetPoint("BOTTOMRIGHT")
  for i, tex in ipairs({ fadeIn, fadeOut }) do
    tex:SetColorTexture(1, 1, 1, 1)
    if CreateColor then
      local clear, lit = CreateColor(s[1], s[2], s[3], 0), CreateColor(s[1], s[2], s[3], 0.35)
      tex:SetGradient("HORIZONTAL", i == 1 and clear or lit, i == 1 and lit or clear)
    end
  end
  tag.halo:Hide()
  tag.sweepClip:Hide()
end

local allTags = setmetatable({}, { __mode = "k" })

function Tab.CreateTag(parent, big)
  Theme = Theme or GG.Theme
  local tag = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  tag:SetHeight(big and 22 or 18)
  tag:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  tag.big = big
  tag.dot = tag:CreateTexture(nil, "ARTWORK")
  tag.dot:SetSize(5, 5)
  tag.dot:SetPoint("LEFT", big and 8 or 6, 0)
  tag.text = tag:CreateFontString(nil, "OVERLAY")
  tag.text:SetFont(Theme.fontBold, big and 13 or 11, "")
  tag.text:SetWordWrap(false)
  tag.text:SetJustifyH("LEFT")
  tag.text:SetPoint("LEFT", tag.dot, "RIGHT", 4, 0)
  BuildPulse(tag)
  tag:EnableMouse(true)
  tag:SetScript("OnEnter", ShowTagTooltip)
  tag:SetScript("OnLeave", function() GameTooltip:Hide() end)
  tag:SetScript("OnMouseUp", function(self, button)
    if not self:IsMouseOver() then return end
    if button == "LeftButton" and self.entry then
      GameTooltip:Hide()
      Tab.OnTagClick(self)
    elseif self.clickTarget then
      self.clickTarget:Click(button)
    end
  end)
  allTags[tag] = true
  return tag
end

function Tab.PaintTag(tag, entry)
  tag.entry = entry
  local c = entry.saved and Theme.danger or Theme.teal
  local best = Tab.FormingGroup(entry.roster)
  tag.forming = best and best.group or nil
  local forming = tag.forming ~= nil and not Tab.IsInsideFor(tag.forming, entry.key)
  tag:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = forming and 2 or 1 })
  tag:SetBackdropColor(c[1], c[2], c[3], 0.14)
  tag.halo:SetShown(forming)
  tag.sweepClip:SetShown(forming)
  if forming then
    tag.dot:SetColorTexture(unpack(Theme.success))
    tag:SetScript("OnUpdate", PulseTag)
    PulseTag(tag)
  else
    tag:SetScript("OnUpdate", nil)
    tag:SetBackdropBorderColor(c[1], c[2], c[3], 0.55)
    tag.dot:SetColorTexture(c[1], c[2], c[3], 1)
    tag.dot:SetAlpha(1)
  end
  tag.text:SetTextColor(c[1], c[2], c[3], 1)
  tag.text:SetWidth(0)
  tag.text:SetText(entry.label)
  local textW = math.min(math.ceil(tag.text:GetStringWidth()), TextMax(tag.big))
  tag.text:SetWidth(textW + 1)
  tag:SetWidth(textW + (tag.big and 26 or 22))
end

function Tab:RepaintTags()
  for tag in pairs(allTags) do
    if tag.entry and tag:IsShown() then Tab.PaintTag(tag, tag.entry) end
  end
end

function Tab:TagsVisible()
  local sections = GGDB and GGDB.options and GGDB.options.sections
  return RR() ~= nil and RR():HasActive() and not (sections and sections.roster == false)
end

local function TextWidth(fs)
  local width = fs:GetStringWidth()
  if width and width > 0 then return width end
  local _, size = fs:GetFont()
  return #(fs:GetText() or "") * (size or 11) * 0.6
end

local function WrapNames(fs, prefixFmt, names, maxW)
  measureFS = measureFS or UIParent:CreateFontString(nil, "OVERLAY")
  measureFS:SetFont(fs:GetFont())
  local lines, cur = {}, prefixFmt:format(names[1])
  for i = 2, #names do
    local try = cur .. ", " .. names[i]
    measureFS:SetText(try)
    if TextWidth(measureFS) > maxW then
      lines[#lines + 1] = cur .. ","
      cur = names[i]
    else
      cur = try
    end
  end
  lines[#lines + 1] = cur
  return table.concat(lines, "\n")
end

local function BuildSegment(parent, items, onPick)
  local seg = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  SetBackdrop(seg, NAV_BG, Theme.border)
  seg:SetHeight(26)
  seg.buttons = {}
  seg.order = {}
  for _, item in ipairs(items) do
    local btn = CreateFrame("Button", nil, seg)
    btn:SetHeight(22)
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.label = CreateText(btn, 11, Theme.textMuted, true)
    btn.label:SetPoint("CENTER")
    btn.label:SetText(item.label)
    local key = item.key
    btn:SetScript("OnClick", function() onPick(key) end)
    seg.buttons[key] = btn
    seg.order[#seg.order + 1] = btn
  end
  seg.Layout = function()
    local x = 2
    for _, btn in ipairs(seg.order) do
      local w = math.max(60, math.ceil(TextWidth(btn.label)) + 24)
      btn:SetWidth(w)
      btn:ClearAllPoints()
      btn:SetPoint("LEFT", seg, "LEFT", x, 0)
      x = x + w + 2
    end
    seg:SetWidth(x)
  end
  seg.Layout()
  seg.Paint = function(_, active)
    seg.Layout()
    for key, btn in pairs(seg.buttons) do
      local on = key == active
      btn.bg:SetColorTexture(unpack(on and Theme.accent or { 0, 0, 0, 0 }))
      btn.label:SetTextColor(unpack(on and Theme.onAccent or Theme.textMuted))
    end
  end
  return seg
end

local function CreateEditBox(parent, width, placeholder, maxLetters)
  local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  box:SetSize(width, 26)
  box:SetAutoFocus(false)
  box:SetFontObject("ChatFontNormal")
  box:SetFont(Theme.font, 12, "")
  box:SetTextColor(unpack(Theme.textPrimary))
  box:SetTextInsets(8, 8, 0, 0)
  if maxLetters then box:SetMaxLetters(maxLetters) end
  SetBackdrop(box, { 0, 0, 0, 0.35 }, Theme.border)
  box.placeholder = CreateText(box, 11.5, Theme.textFaint)
  box.placeholder:SetPoint("LEFT", 8, 0)
  box.placeholder:SetText(placeholder or "")
  box:HookScript("OnTextChanged", function(self) self.placeholder:SetShown(self:GetText() == "") end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  return box
end

local pasteBoxCount = 0
local function CreatePasteBox(parent, placeholder)
  pasteBoxCount = pasteBoxCount + 1
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  SetBackdrop(holder, { 0, 0, 0, 0.45 }, Theme.border)
  local scroll = CreateFrame("ScrollFrame", "GGRosterPasteScroll" .. pasteBoxCount, holder, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 6, -6)
  scroll:SetPoint("BOTTOMRIGHT", -24, 6)
  if scroll.ScrollBar and GG.Widgets.SkinScrollbar then GG.Widgets.SkinScrollbar(scroll.ScrollBar) end
  local box = CreateFrame("EditBox", nil, scroll)
  box:SetMultiLine(true)
  box:SetAutoFocus(false)
  box:SetMaxLetters(0)
  box:SetFontObject("ChatFontNormal")
  box:SetFont(Theme.font, 11, "")
  box:SetTextColor(unpack(Theme.textMuted))
  box:SetWidth(200)
  scroll:SetScrollChild(box)
  scroll:SetScript("OnSizeChanged", function(self, w) box:SetWidth(math.max(50, w)) end)
  box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  if ScrollingEdit_OnCursorChanged then
    box:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
    box:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, scroll) end)
  end
  holder:EnableMouse(true)
  holder:SetScript("OnMouseDown", function() box:SetFocus() end)
  holder.placeholder = CreateText(holder, 11.5, Theme.textFaint)
  holder.placeholder:SetPoint("TOPLEFT", 10, -10)
  holder.placeholder:SetText(placeholder)
  box:HookScript("OnTextChanged", function(self) holder.placeholder:SetShown(self:GetText() == "") end)
  holder.box = box
  return holder
end

local function AccentButton(parent, text, onClick)
  local btn = GG.Widgets.CreateButton(parent, text, onClick)
  local function Paint(alpha) btn:SetBackdropColor(Theme.accent[1], Theme.accent[2], Theme.accent[3], alpha) end
  btn:SetScript("OnEnter", function() Paint(1) end)
  btn:SetScript("OnLeave", function() Paint(0.85) end)
  btn.label:SetTextColor(unpack(Theme.onAccent))
  Paint(0.85)
  return btn
end

local function DefaultRaid()
  return RR():DefaultRaid()
end

local function RaidOptions()
  local out = {}
  for _, raid in ipairs(GG.Season.RAIDS or {}) do
    out[#out + 1] = { key = raid.instanceID, label = RR():RaidName(raid.instanceID) }
  end
  return out
end

local function DifficultyOptions()
  local out = {}
  for _, diff in ipairs(RR().DIFFICULTIES) do out[#out + 1] = { key = diff, label = RR():DifficultyName(diff) } end
  return out
end

local function NewDraftGroup(label, members, auto)
  return { label = label:sub(1, RR().MAX_LABEL), orig = label, auto = auto, members = members, custom = false, raid = DefaultRaid(), diff = 16 }
end

local function ParseAllDraft(text)
  local groups = {}
  for _, g in ipairs(RR().ParseAll(text)) do groups[#groups + 1] = NewDraftGroup(g.label, g.members, g.auto) end
  return groups
end

local function Draft()
  return RR().Summarize(state.mode == "all" and state.allGroups or state.oneList)
end

local function MyRows()
  local rows = GG.Roster and GG.Roster:BuildRows() or {}
  table.sort(rows, function(a, b) return (a.name .. a.realm) < (b.name .. b.realm) end)
  return rows
end

local function ClassColor(class)
  local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return { c.r, c.g, c.b, 1 } end
  return Theme.textPrimary
end

local function EnsureMineRow(i)
  local list = container.listView
  list.mineRows = list.mineRows or {}
  local row = list.mineRows[i]
  if row then return row end
  row = CreateFrame("Button", nil, list.mineInner, "BackdropTemplate")
  row:SetSize(LEFT_W - 24, MINE_ROW_H - 4)
  SetBackdrop(row, Fade(Theme.panel, 1), Theme.borderSoft)
  row.tag = Tab.CreateTag(row, true)
  row.tag:SetPoint("LEFT", 8, 0)
  row.tag.clickTarget = row
  row.name = CreateText(row, 13, Theme.textPrimary, true)
  row.realm = CreateText(row, 10.5, Theme.textFaint)
  row.realm:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
  row.acct = CreateText(row, 10.5, Theme.textMuted, true)
  row.acct:SetPoint("RIGHT", -8, 0)
  row.inGroup = CreateText(row, 9.5, Theme.success, true)
  row.inGroup:SetPoint("RIGHT", row.acct, "LEFT", -8, 0)
  row.inGroup:SetText(L["RG_IN_GROUP"])
  row:SetScript("OnClick", function(self)
    if self.rosterIndex then state.sel, state.autoSel = self.rosterIndex, false; Tab:Refresh() end
  end)
  list.mineRows[i] = row
  return row
end

local function EnsureChip(i)
  local list = container.listView
  list.chips = list.chips or {}
  local chip = list.chips[i]
  if chip then return chip end
  chip = CreateFrame("Button", nil, list.right, "BackdropTemplate")
  chip:SetHeight(26)
  SetBackdrop(chip, Fade(Theme.panel, 1), Theme.border)
  chip.dot = chip:CreateTexture(nil, "ARTWORK")
  chip.dot:SetSize(6, 6)
  chip.dot:SetPoint("LEFT", 9, 0)
  chip.label = CreateText(chip, 12, Theme.textMuted, true)
  chip.count = CreateText(chip, 10, { 0.72, 0.64, 0.97, 1 })
  chip.live = chip:CreateTexture(nil, "OVERLAY")
  chip.live:SetHeight(2)
  chip.live:SetPoint("BOTTOMLEFT", 1, 1)
  chip.live:SetPoint("BOTTOMRIGHT", -1, 1)
  chip.live:SetColorTexture(unpack(Theme.success))
  chip:SetScript("OnClick", function(self) state.sel, state.autoSel = self.rosterIndex, false; Tab:Refresh() end)
  list.chips[i] = chip
  return chip
end

local function EnsureMember(i)
  local list = container.listView
  list.members = list.members or {}
  local m = list.members[i]
  if m then return m end
  m = CreateFrame("Frame", nil, list.right, "BackdropTemplate")
  m:SetHeight(MEMBER_H - 2)
  m.num = CreateText(m, 10, Theme.textFaint)
  m.num:SetPoint("RIGHT", m, "LEFT", 26, 0)
  m.num:SetJustifyH("RIGHT")
  m.check = m:CreateTexture(nil, "OVERLAY")
  m.check:SetSize(14, 14)
  m.check:SetPoint("RIGHT", m, "LEFT", 27, 0)
  m.check:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  m.warn = m:CreateTexture(nil, "OVERLAY")
  m.warn:SetSize(15, 15)
  m.warn:SetPoint("RIGHT", m, "LEFT", 27, 0)
  m.warn:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
  m.name = CreateText(m, 12.5, Theme.textMuted, true)
  m.name:SetPoint("LEFT", 32, 0)
  m.ilvl = CreateText(m, 11, ILVL_COLOR, true)
  m.ilvl:SetPoint("RIGHT", -8, 0)
  m.ilvl:SetJustifyH("RIGHT")
  m.you = CreateText(m, 9.5, Theme.accentHi or Theme.accent, true)
  m.you:SetPoint("RIGHT", m.ilvl, "LEFT", -8, 0)
  m:EnableMouse(true)
  m:SetScript("OnEnter", function(self)
    local info = self.info
    if not info then return end
    local fullName, inGroup, altName = self.fullName, self.inGroup, self.altName
    GG.Tip:Open(self, { family = "roster" }, function(t)
      t:Title(fullName or "")
      if inGroup then t:Text(L["RG_MEMBER_IN_GROUP"], Theme.success) end
      if altName then t:Text(L["RG_MEMBER_ALT"]:format(altName), Theme.gold) end
      if info.ilvl then
        t:Text(L["RR_MEMBER_ILVL"]:format(info.ilvl))
        if info.updatedAt then t:Text(L["RR_MEMBER_UPDATED"]:format(AgeText(info.updatedAt)), Theme.textFaint, true) end
      else
        t:Text(L["RR_MEMBER_NO_ILVL"], Theme.textFaint)
      end
    end)
  end)
  m:SetScript("OnLeave", function() GameTooltip:Hide() end)
  list.members[i] = m
  return m
end

local BANNER_H = 40

local function PaintInvite(inv, mode)
  inv.mode = mode
  inv.icon:SetShown(mode == "sent")
  inv.name:ClearAllPoints()
  inv.text:ClearAllPoints()
  if mode == "invite" then
    inv:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    inv:SetBackdropColor(unpack(inv.hover and Fade(Theme.accent, 0.18) or Fade(Theme.panel, 1)))
    inv:SetBackdropBorderColor(unpack(inv.hover and Theme.accent or Theme.border))
    inv.name:SetPoint("LEFT", 10, 0)
    inv.text:SetPoint("LEFT", inv.name, "RIGHT", 6, 0)
    inv.text:SetText(L["RG_REQUEST"])
    inv.text:SetTextColor(unpack(Theme.textPrimary))
    inv:SetWidth(10 + inv.name:GetStringWidth() + 6 + inv.text:GetStringWidth() + 10)
  else
    inv:SetBackdrop(nil)
    inv.name:SetPoint("LEFT", 0, 0)
    if mode == "sent" then
      inv.icon:SetPoint("LEFT", inv.name, "RIGHT", 6, 0)
      inv.text:SetPoint("LEFT", inv.icon, "RIGHT", 4, 0)
      inv.text:SetText(L["RG_SENT"])
    else
      inv.text:SetPoint("LEFT", inv.name, "RIGHT", 8, 0)
      inv.text:SetText(L["RG_INSIDE"])
    end
    inv.text:SetTextColor(unpack(Theme.success))
    inv:SetWidth(inv.name:GetStringWidth() + (mode == "sent" and 24 or 8) + inv.text:GetStringWidth())
  end
  inv:EnableMouse(mode == "invite")
end

local function BuildBanner(parent)
  local b = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  b:SetHeight(BANNER_H)
  SetBackdrop(b, Fade(Theme.success, 0.08), Fade(Theme.success, 0.45))
  b.dot = b:CreateTexture(nil, "ARTWORK")
  b.dot:SetSize(7, 7)
  b.dot:SetPoint("LEFT", 12, 0)
  b.dot:SetColorTexture(unpack(Theme.success))
  b.live = CreateText(b, 12, Theme.success, true)
  b.live:SetPoint("LEFT", b.dot, "RIGHT", 8, 0)
  b.live:SetText(L["RG_LIVE"])
  b.count = CreateText(b, 13, Theme.textPrimary)
  b.count:SetPoint("LEFT", b.live, "RIGHT", 14, 0)
  b.sep = b:CreateTexture(nil, "ARTWORK")
  b.sep:SetSize(1, 18)
  b.sep:SetPoint("LEFT", b.count, "RIGHT", 14, 0)
  b.sep:SetColorTexture(unpack(Fade(Theme.success, 0.3)))
  b.leaderLabel = CreateText(b, 12, Theme.textFaint)
  b.leaderLabel:SetPoint("LEFT", b.sep, "RIGHT", 14, 0)
  b.leaderLabel:SetText(L["RG_LEADER"])

  local inv = CreateFrame("Button", nil, b, "BackdropTemplate")
  inv:SetHeight(28)
  inv:SetPoint("LEFT", b.leaderLabel, "RIGHT", 8, 0)
  inv.name = CreateText(inv, 13, Theme.textPrimary, true)
  inv.text = CreateText(inv, 12, Theme.textPrimary, true)
  inv.icon = inv:CreateTexture(nil, "ARTWORK")
  inv.icon:SetSize(14, 14)
  inv.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  inv:SetScript("OnClick", function(self)
    if not self.group then return end
    self.hover = false
    GameTooltip:Hide()
    Tab.AskInvite(self.group, self.rosterLabel, self.inRoster)
  end)
  inv:SetScript("OnEnter", function(self)
    self.hover = true
    PaintInvite(self, self.mode)
    local leader = self.group and self.group.leader or ""
    GG.Tip:Open(self, { family = "roster", anchor = "BOTTOM" }, function(t)
      t:Title(L["RG_TIP_INVITE_TITLE"])
      t:Text(L["RG_TIP_INVITE"]:format(leader))
    end)
  end)
  inv:SetScript("OnLeave", function(self)
    self.hover = false
    PaintInvite(self, self.mode)
    GameTooltip:Hide()
  end)
  b.invite = inv

  local out = CreateFrame("Frame", nil, b)
  out:SetHeight(BANNER_H)
  out:SetPoint("RIGHT", -12, 0)
  out:EnableMouse(true)
  out.text = CreateText(out, 12, Theme.textMuted)
  out.text:SetPoint("RIGHT", 0, 0)
  out:SetScript("OnEnter", function(self)
    local owner = self
    GG.Tip:Open(self, { family = "roster", anchor = "BOTTOMRIGHT" }, function(t)
      t:Title(L["RG_TIP_OUTSIDE"])
      for _, name in ipairs(owner.names or {}) do
        local c = ClassColor(owner.lookup and owner.lookup(name).class)
        local instead = owner.altFor and owner.altFor[RR().NameKey(name) or ""]
        local suffix = instead and ("  " .. GG.Tip.Paint(L["RG_ALT_OF"]:format(instead), Theme.gold)) or ""
        t:Text(name .. suffix, c)
      end
    end)
  end)
  out:SetScript("OnLeave", function() GameTooltip:Hide() end)
  b.outside = out
  b:Hide()
  return b
end

function Tab.AskInvite(g, rosterLabel, inRoster)
  if inRoster then return Tab.SendInvite(g) end
  local c = container.inviteConfirm
  c.group = g
  local _, class = UnitClass("player")
  local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  local who = cc and ("|c%s%s|r"):format(cc.colorStr, GG:GetCharacterKey()) or GG:GetCharacterKey()
  local p = Theme.teal
  local where = ("|cff%02x%02x%02x%s|r"):format(p[1] * 255, p[2] * 255, p[3] * 255, rosterLabel or "")
  c.text:SetText(L["RG_CONFIRM_NOT_IN"]:format(who, where))
  c.panel:SetHeight(18 + c.text:GetStringHeight() + 8 + c.ask:GetStringHeight() + 18 + 26 + 16)
  c:Show()
end

function Tab.SendInvite(g)
  if GG.RaidGroups:RequestInvite(g) then
    state.sent = { key = g.leaderKey, untilT = GetTime() + 4 }
    C_Timer.After(4.1, function() Tab:RefreshIfShown() end)
    Tab:Refresh()
    return true
  elseif GG.IsChatRestricted and GG:IsChatRestricted() then
    print("|cff8B5CF6GG|r " .. L["RG_CHAT_BLOCKED"])
  end
  return false
end

local function PaintBanner(best, roster, width, y, lookup, alts)
  local total = #roster.members
  local list = container.listView
  local b = list.banner
  b:SetShown(best ~= nil)
  if not best then return end
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", list.right, "TOPLEFT", 0, y)
  b:SetWidth(width)
  b.count:SetText(L["RG_OF_ROSTER"]:format(best.count, total))

  local g = best.group
  local inv = b.invite
  inv.group = g
  inv.rosterLabel = roster.label
  inv.inRoster = GG.RaidGroups.InRoster(roster.members, GG:GetCharacterKey())
  inv.name:SetText(g.leader)
  inv.name:SetTextColor(unpack(ClassColor(lookup(g.leader).class)))
  local sent = state.sent and state.sent.key == g.leaderKey and GetTime() < state.sent.untilT
  PaintInvite(inv, GG.RaidGroups:IsInside(g) and "inside" or sent and "sent" or "invite")

  local out = b.outside
  local n = #best.outsiders
  out:SetShown(n > 0)
  out.names, out.lookup, out.altFor = best.outsiders, lookup, alts and alts.byAlt
  out.text:SetText(L["RG_OUTSIDE"]:format(n))
  local used = 12 + 7 + 8 + b.live:GetStringWidth() + 14 + b.count:GetStringWidth() + 29
    + b.leaderLabel:GetStringWidth() + 8 + inv:GetWidth() + 16 + 12
  if out.text:GetStringWidth() > width - used then out.text:SetText("+" .. n) end
  out:SetWidth(out.text:GetStringWidth() + 2)
end

local function PaintList()
  local list = container.listView
  local rr = RR()
  local set = rr:GetCurrentSet()
  list.empty:SetShown(set == nil)
  list.left:SetShown(set ~= nil)
  list.right:SetShown(set ~= nil)
  if not set then
    list.empty.title:SetText(rr:GuildKey() and L["RR_EMPTY_TITLE"] or L["RR_NO_GUILD"])
    list.empty.go:SetShown(rr:GuildKey() ~= nil)
    container.info:SetText("")
    return
  end
  state.sel = math.min(math.max(1, state.sel), #set.rosters)

  local info = L["RR_PUBLISHED_BY"]:format(RR().PublisherName(set), date("%a %H:%M", set.publishedAt))
  local relayedByAuthor = set.relayedBy == set.publisher
    or (RR().NameKey(set.relayedBy) ~= nil and RR().NameKey(set.relayedBy) == RR().NameKey(set.publisher))
  if set.relayedBy and not relayedByAuthor then info = info .. "  " .. L["RR_RELAYED_BY"]:format(set.relayedBy) end
  container.info:SetText(info)

  local mine, without, myKeys, mineByRoster = {}, {}, {}, {}
  local rosterIndex = {}
  for i, roster in ipairs(set.rosters) do rosterIndex[roster] = i end
  for _, row in ipairs(MyRows()) do
    myKeys[rr.NameKey(row.key) or ""] = true
    local any = false
    for _, t in ipairs(rr:TagsFor(row.key, row.rawRecord)) do
      if t.set == set and rosterIndex[t.roster] then
        mine[#mine + 1] = { row = row, tag = t, index = rosterIndex[t.roster] }
        mineByRoster[rosterIndex[t.roster]] = true
        any = true
      end
    end
    if not any then without[#without + 1] = row.name .. "-" .. row.realm end
  end
  table.sort(mine, function(a, b) return a.index < b.index end)
  local RG = GG.RaidGroups
  local groups = RG and RG:Groups() or {}
  local bestOf = {}
  if #groups > 0 then
    for i, roster in ipairs(set.rosters) do bestOf[i] = RG.BestGroupFor(roster.members, groups) end
  end
  if state.autoSel then state.sel = Tab.AutoPick(#set.rosters, bestOf, mineByRoster) or state.sel end

  local visibleH = list.mineClip:GetHeight()
  local contentH = #mine * MINE_ROW_H
  state.mineOffset = math.max(0, math.min(state.mineOffset, math.max(0, contentH - visibleH)))
  for i, item in ipairs(mine) do
    local r = EnsureMineRow(i)
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", list.mineInner, "TOPLEFT", 0, -(i - 1) * MINE_ROW_H + state.mineOffset)
    Tab.PaintTag(r.tag, item.tag)
    r.name:SetText(item.row.name)
    r.name:SetTextColor(unpack(ClassColor(item.row.class)))
    r.realm:SetText(item.row.realm)
    local blockH = r.name:GetStringHeight() + 1 + r.realm:GetStringHeight()
    r.name:ClearAllPoints()
    r.name:SetPoint("TOPLEFT", r, "LEFT", 8 + Tab.TagMaxWidth(true) + 8, blockH / 2)
    r.acct:SetText(item.row.accountLabel or "")
    local best = bestOf[item.index]
    r.inGroup:SetShown(best ~= nil and best.present[rr.NameKey(item.row.key) or ""] == true)
    r.rosterIndex = item.index
    local on = item.index == state.sel
    r:SetBackdropBorderColor(unpack(on and Fade(Theme.teal, 0.7) or Theme.borderSoft))
    r:SetBackdropColor(unpack(on and Fade(Theme.teal, 0.10) or Fade(Theme.panel, 1)))
    r:Show()
  end
  for i = #mine + 1, #(list.mineRows or {}) do list.mineRows[i]:Hide() end
  list.none:SetShown(#mine == 0)
  list.outText:ClearAllPoints()
  list.outText:SetPoint("TOPLEFT", list.mineClip, "BOTTOMLEFT", 0, -8)
  list.outText:SetText(#without > 0 and WrapNames(list.outText, L["RR_NOT_IN_ANY"], without, list.outText:GetWidth() - 2) or "")
  list.mineClip:SetHeight(math.max(MINE_ROW_H, math.min(contentH, list.left:GetHeight() - 110)))

  local q = state.query:lower()
  local rightW = list.right:GetWidth()
  local x, y, shown = 0, -36, 0
  for i, roster in ipairs(set.rosters) do
    local match = q == "" or roster.label:lower():find(q, 1, true)
    if not match then
      for _, name in ipairs(roster.members) do
        if name:lower():find(q, 1, true) then match = true break end
      end
    end
    local chip = EnsureChip(i)
    if match then
      shown = shown + 1
      chip.rosterIndex = i
      chip.label:SetText(roster.label)
      local best = bestOf[i]
      chip.count:SetText(best and ("%d/%d"):format(best.count, #roster.members) or tostring(#roster.members))
      chip.count:SetTextColor(unpack(best and Theme.success or { 0.72, 0.64, 0.97, 1 }))
      chip.live:SetShown(best ~= nil)
      local hasMine = mineByRoster[i] == true
      chip.dot:SetShown(hasMine)
      chip.dot:SetColorTexture(unpack(Theme.teal))
      chip.label:ClearAllPoints()
      chip.label:SetPoint("LEFT", hasMine and 20 or 10, 0)
      chip.count:SetPoint("LEFT", chip.label, "RIGHT", 6, 0)
      local w = (hasMine and 20 or 10) + chip.label:GetStringWidth() + 6 + chip.count:GetStringWidth() + 10
      chip:SetWidth(w)
      if x + w > rightW and x > 0 then x, y = 0, y - 32 end
      chip:ClearAllPoints()
      chip:SetPoint("TOPLEFT", list.right, "TOPLEFT", x, y)
      x = x + w + 6
      local on = i == state.sel
      chip:SetBackdropColor(unpack(on and Fade(Theme.teal, 0.18) or Fade(Theme.panel, 1)))
      chip:SetBackdropBorderColor(unpack(on and Fade(Theme.teal, 0.7) or Theme.border))
      chip.label:SetTextColor(unpack(on and Theme.textPrimary or Theme.textMuted))
      chip:Show()
    else
      chip:Hide()
    end
  end
  for i = #set.rosters + 1, #(list.chips or {}) do list.chips[i]:Hide() end
  list.noMatch:SetShown(shown == 0)
  list.noMatch:ClearAllPoints()
  list.noMatch:SetPoint("TOPLEFT", list.right, "TOPLEFT", 0, -40)

  local roster = set.rosters[state.sel]
  y = y - 44
  list.title:ClearAllPoints()
  list.title:SetPoint("TOPLEFT", list.right, "TOPLEFT", 0, y)
  list.title:SetText(roster.label)
  list.subtitle:ClearAllPoints()
  list.subtitle:SetPoint("LEFT", list.title, "RIGHT", 12, -1)
  local lookup = rr:MemberLookup()
  local infos = {}
  for i, name in ipairs(roster.members) do infos[i] = lookup(name) end
  local avg, withIlvl = rr.AverageIlvl(infos)
  local subtitle = rr:DifficultyName(roster.diff) .. " · " .. rr:RaidName(roster.raid) .. " · " .. L["RR_CHARACTERS_COUNT"]:format(#roster.members)
  if avg then
    local avgText = ("%.1f"):format(avg)
    subtitle = subtitle .. " · " .. (withIlvl < #roster.members
      and L["RR_AVG_ILVL_PARTIAL"]:format(avgText, withIlvl, #roster.members)
      or L["RR_AVG_ILVL"]:format(avgText))
  end
  list.subtitle:SetText(subtitle)
  y = y - 34
  local best = bestOf[state.sel]
  local alts = best and RG.AltsFor(best, roster.members, function(a, b) return rr:SameOwner(a, b) end)
  PaintBanner(best, roster, rightW, y, lookup, alts)
  if best then y = y - (BANNER_H + 10) end
  list.searching = list.searching or CreateText(list.right, 11.5, Theme.textFaint)
  local searching = not best and GetTime() < state.searchUntil
  list.searching:SetShown(searching)
  if searching then
    list.searching:ClearAllPoints()
    list.searching:SetPoint("TOPLEFT", list.right, "TOPLEFT", 0, y)
    list.searching:SetText(L["RG_SEARCHING"])
    y = y - 22
  end
  local colW = math.floor(rightW / MEMBER_COLS)
  local perCol = math.ceil(#roster.members / MEMBER_COLS)
  for i, name in ipairs(roster.members) do
    local m = EnsureMember(i)
    local info = infos[i]
    local col, line = math.floor((i - 1) / perCol), (i - 1) % perCol
    m:ClearAllPoints()
    m:SetPoint("TOPLEFT", list.right, "TOPLEFT", col * colW, y - line * MEMBER_H)
    m:SetWidth(colW - 10)
    m.num:SetText(tostring(i))
    m.name:SetText(name)
    m.name:SetWidth(colW - 140)
    m.info, m.fullName = info, name
    local key = rr.NameKey(name) or ""
    local isMine = myKeys[key] == true
    local hit = q ~= "" and name:lower():find(q, 1, true) ~= nil
    local inGroup = best ~= nil and best.present[key] == true
    local altName = alts and alts.byRoster[key]
    m.inGroup, m.altName = inGroup, altName
    m.check:SetShown(inGroup)
    m.warn:SetShown(altName ~= nil)
    m.num:SetShown(not inGroup and not altName)
    m:SetAlpha((best and not inGroup and not altName) and 0.45 or 1)
    m:SetBackdrop((isMine or hit or inGroup or altName) and { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 } or nil)
    if isMine or hit then
      m:SetBackdropColor(unpack(Fade(Theme.accent, 0.16)))
      m:SetBackdropBorderColor(unpack(Fade(Theme.accent, 0.5)))
    elseif inGroup then
      m:SetBackdropColor(unpack(Fade(Theme.success, 0.10)))
      m:SetBackdropBorderColor(unpack(Fade(Theme.success, 0.34)))
    elseif altName then
      m:SetBackdropColor(unpack(Fade(Theme.gold, 0.13)))
      m:SetBackdropBorderColor(unpack(Fade(Theme.gold, 0.5)))
    end
    local cc = info.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[info.class]
    if cc then
      m.name:SetTextColor(cc.r, cc.g, cc.b, 1)
    else
      m.name:SetTextColor(unpack((isMine or hit) and Theme.textPrimary or Theme.textMuted))
    end
    if info.ilvl then
      m.ilvl:SetText(tostring(math.floor(info.ilvl)))
      m.ilvl:SetTextColor(ILVL_COLOR[1], ILVL_COLOR[2], ILVL_COLOR[3], info.stale and 0.45 or 1)
    else
      m.ilvl:SetText("—")
      m.ilvl:SetTextColor(unpack(Fade(Theme.textFaint, 0.5)))
    end
    m.you:SetText(isMine and L["RR_YOU"]:upper() or "")
    m:Show()
  end
  for i = #roster.members + 1, #(list.members or {}) do list.members[i]:Hide() end
end

local function BuildList()
  local list = CreateFrame("Frame", nil, container)
  list:SetPoint("TOPLEFT", 0, -46)
  list:SetPoint("BOTTOMRIGHT", 0, 0)
  container.listView = list

  list.left = CreateFrame("Frame", nil, list, "BackdropTemplate")
  SetBackdrop(list.left, NAV_BG, Theme.borderSoft)
  list.left:SetPoint("TOPLEFT", 0, 0)
  list.left:SetPoint("BOTTOMLEFT", 0, 0)
  list.left:SetWidth(LEFT_W)
  local title = CreateText(list.left, 11, Theme.textMuted, true)
  title:SetPoint("TOPLEFT", 12, -12)
  title:SetText(L["RR_YOUR_CHARACTERS"]:upper())
  list.mineClip = CreateFrame("Frame", nil, list.left)
  list.mineClip:SetPoint("TOPLEFT", 12, -34)
  list.mineClip:SetWidth(LEFT_W - 24)
  list.mineClip:SetHeight(200)
  list.mineClip:SetClipsChildren(true)
  list.mineClip:EnableMouseWheel(true)
  list.mineClip:SetScript("OnMouseWheel", function(_, delta)
    state.mineOffset = state.mineOffset - delta * MINE_ROW_H
    PaintList()
  end)
  list.mineInner = CreateFrame("Frame", nil, list.mineClip)
  list.mineInner:SetAllPoints()
  list.none = CreateText(list.left, 11.5, Theme.textFaint)
  list.none:SetPoint("TOPLEFT", 12, -38)
  list.none:SetWidth(LEFT_W - 24)
  list.none:SetWordWrap(true)
  list.none:SetText(L["RR_NONE_OF_YOURS"])
  list.outText = CreateText(list.left, 11, Theme.textFaint)
  list.outText:SetWidth(LEFT_W - 24)
  list.outText:SetWordWrap(true)

  list.right = CreateFrame("Frame", nil, list)
  list.right:SetPoint("TOPLEFT", list.left, "TOPRIGHT", 16, -12)
  list.right:SetPoint("BOTTOMRIGHT", -16, 12)
  list.search = CreateEditBox(list.right, 280, L["RR_FIND"], 40)
  list.search:SetPoint("TOPLEFT", 0, 0)
  list.search:SetScript("OnTextChanged", function(self, user)
    self.placeholder:SetShown(self:GetText() == "")
    if user then state.query = self:GetText(); PaintList() end
  end)
  list.noMatch = CreateText(list.right, 11.5, Theme.textFaint)
  list.noMatch:SetText(L["RR_NO_MATCH"])
  list.title = CreateText(list.right, 20, Theme.textPrimary, true)
  list.subtitle = CreateText(list.right, 12, Theme.textFaint)
  list.banner = BuildBanner(list.right)

  list.empty = CreateFrame("Frame", nil, list)
  list.empty:SetAllPoints()
  list.empty.title = CreateText(list.empty, 15, Theme.textPrimary, true)
  list.empty.title:SetPoint("CENTER", 0, 30)
  list.empty.title:SetJustifyH("CENTER")
  list.empty.go = GG.Widgets.CreateButton(list.empty, L["RR_SUB_CREATE"], function()
    state.sub = "create"
    Tab:Refresh()
  end)
  list.empty.go:SetPoint("TOP", list.empty.title, "BOTTOM", 0, -14)
end

local function EnsureCard(i)
  local view = container.createView
  view.cards = view.cards or {}
  local card = view.cards[i]
  if card then return card end
  card = CreateFrame("Frame", nil, view.cardsInner, "BackdropTemplate")
  card:SetSize(CARD_W, CARD_H)
  SetBackdrop(card, Fade(Theme.panel, 1), Theme.border)
  card.name = CreateEditBox(card, CARD_W - 60, nil, RR().MAX_LABEL)
  card.name:SetHeight(24)
  card.name:SetFont(Theme.fontBold, 12.5, "")
  card.name:SetPoint("TOPLEFT", 8, -8)
  card.name:SetScript("OnTextChanged", function(self, user)
    self.placeholder:SetShown(self:GetText() == "")
    if user and card.group then
      local text = self:GetText():gsub("^%s+", ""):gsub("%s+$", "")
      card.group.label = text ~= "" and text or card.group.orig
      Tab.PaintTag(card.tag, { label = card.group.label, saved = false })
    end
  end)
  card.count = CreateText(card, 12, Theme.teal, true)
  card.count:SetPoint("TOPRIGHT", -10, -13)
  card.count:SetJustifyH("RIGHT")
  card.preview = CreateText(card, 10.5, Theme.textFaint)
  card.preview:SetPoint("TOPLEFT", 9, -40)
  card.preview:SetWidth(CARD_W - 18)
  card.preview:SetWordWrap(true)
  card.preview:SetMaxLines(2)
  card.lookLabel = CreateText(card, 10, Theme.textFaint)
  card.lookLabel:SetPoint("TOPLEFT", 9, -78)
  card.lookLabel:SetText(L["RR_IN_THE_LIST"])
  card.tag = Tab.CreateTag(card, false)
  card.tag:SetPoint("LEFT", card.lookLabel, "RIGHT", 6, 0)
  card.switch = GG.Widgets.CreateSwitch(card, false, function(on)
    if card.group then card.group.custom = on; Tab:Refresh() end
  end)
  card.switch:SetPoint("TOPLEFT", 8, -98)
  card.switchLabel = CreateText(card, 10.5, Theme.textMuted)
  card.switchLabel:SetPoint("LEFT", card.switch, "RIGHT", 8, 0)
  card.switchLabel:SetText(L["RR_OWN_RAID"])
  card.raid = GG.Widgets.CreateDropdown(card, {
    values = RaidOptions,
    get = function() return card.group and card.group.raid end,
    set = function(key) if card.group then card.group.raid = key end end,
    width = 128,
  })
  card.raid:SetPoint("BOTTOMLEFT", 8, 8)
  card.diff = GG.Widgets.CreateDropdown(card, {
    values = DifficultyOptions,
    get = function() return card.group and card.group.diff end,
    set = function(key) if card.group then card.group.diff = key end end,
    width = 84,
  })
  card.diff:SetPoint("BOTTOMRIGHT", -8, 8)
  card.remove = GG.Widgets.CreateButton(card, "x", function()
    if not card.group then return end
    for k, g in ipairs(state.oneList) do
      if g == card.group then table.remove(state.oneList, k) break end
    end
    Tab:Refresh()
  end)
  card.remove:SetSize(22, 22)
  card.remove:SetPoint("TOPRIGHT", -6, -9)
  view.cards[i] = card
  return card
end

local function PaintCards(draft)
  local view = container.createView
  local width = view.cardsClip:GetWidth()
  local cols = math.max(1, math.floor((width + CARD_GAP) / (CARD_W + CARD_GAP)))
  local rows = math.ceil(#draft.rosters / cols)
  local contentH = rows * (CARD_H + CARD_GAP)
  local maxOffset = math.max(0, contentH - view.cardsClip:GetHeight())
  state.cardsOffset = math.max(0, math.min(state.cardsOffset, maxOffset))
  for i, g in ipairs(draft.rosters) do
    local card = EnsureCard(i)
    card.group = g
    local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", view.cardsInner, "TOPLEFT", col * (CARD_W + CARD_GAP), -line * (CARD_H + CARD_GAP) + state.cardsOffset)
    if not card.name:HasFocus() then card.name:SetText(g.label) end
    card.name.placeholder:Hide()
    card.count:SetText(tostring(#g.members))
    local shown = {}
    for k = 1, math.min(6, #g.members) do shown[k] = g.members[k] end
    local text = table.concat(shown, ", ")
    if #g.members > 6 then text = text .. " " .. L["RR_MORE"]:format(#g.members - 6) end
    card.preview:SetText(text)
    Tab.PaintTag(card.tag, { label = g.label, saved = false })
    card.switch:SetChecked(g.custom)
    card.raid:SetShown(g.custom)
    card.diff:SetShown(g.custom)
    if card.raid.Refresh then card.raid:Refresh() end
    if card.diff.Refresh then card.diff:Refresh() end
    card.remove:SetShown(state.mode == "one")
    card.count:ClearAllPoints()
    card.count:SetPoint("TOPRIGHT", state.mode == "one" and -32 or -10, -13)
    card:Show()
  end
  for i = #draft.rosters + 1, #(view.cards or {}) do
    view.cards[i]:Hide()
    view.cards[i].group = nil
  end
end

local function PaintModal()
  local modal = container.modal
  local m = state.modal
  modal:SetShown(m ~= nil)
  if not m then return end
  modal.title:SetText(m.count == m.total and L["RR_MODAL_ALL"] or L["RR_MODAL_REST"]:format(m.count))
  modal.raid:Paint(m.raid)
  modal.diff:Paint(m.diff)
end

local function PaintCreate()
  local view = container.createView
  local rr = RR()
  local draft = Draft()
  container.info:SetText("")
  view.modeAll:SetBackdropBorderColor(unpack(state.mode == "all" and Theme.accent or Theme.border))
  view.modeOne:SetBackdropBorderColor(unpack(state.mode == "one" and Theme.accent or Theme.border))
  view.modeAll:SetBackdropColor(unpack(state.mode == "all" and Fade(Theme.accent, 0.14) or Fade(Theme.panel, 1)))
  view.modeOne:SetBackdropColor(unpack(state.mode == "one" and Fade(Theme.accent, 0.14) or Fade(Theme.panel, 1)))
  local one = state.mode == "one"
  view.oneName:SetShown(one)
  view.add:SetShown(one)
  view.paste:ClearAllPoints()
  view.paste:SetPoint("TOPLEFT", view.left, "TOPLEFT", 12, one and -112 or -78)
  view.paste:SetPoint("BOTTOMRIGHT", view.left, "BOTTOMRIGHT", -12, 44)
  local wanted = one and state.oneText or state.textAll
  if not view.paste.box:HasFocus() and view.paste.box:GetText() ~= wanted then view.paste.box:SetText(wanted) end
  view.paste.placeholder:SetText(one and L["RR_PASTE_ONE_HINT"] or L["RR_PASTE_ALL_HINT"])
  view.paste.placeholder:SetShown(wanted == "")
  if one then
    view.add.label:SetText(L["RR_ADD"]:format(#rr.ParseOne(state.oneText)))
    view.add:SetWidth(view.add.label:GetStringWidth() + 24)
  end

  local total = 0
  for _, g in ipairs(draft.rosters) do total = total + #g.members end
  view.statRosters.value:SetText(tostring(#draft.rosters))
  view.statChars.value:SetText(tostring(total))
  local warn = {}
  if #draft.skipped > 0 then warn[#warn + 1] = L["RR_SKIPPED"]:format(table.concat(draft.skipped, ", ")) end
  if #draft.dups > 0 then warn[#warn + 1] = L["RR_DUPS"]:format(table.concat(draft.dups, ", ")) end
  view.warn:SetText(table.concat(warn, "\n"))
  view.warn:SetShown(#warn > 0)
  view.cardsClip:ClearAllPoints()
  view.cardsClip:SetPoint("TOPLEFT", view.right, "TOPLEFT", 0, #warn > 0 and -(60 + 8 + view.warn:GetStringHeight() + 8) or -60)
  view.cardsClip:SetPoint("BOTTOMRIGHT", view.right, "BOTTOMRIGHT", 0, 40)
  view.noRosters:SetShown(#draft.rosters == 0)
  PaintCards(draft)

  local guild = rr:GuildKey() ~= nil
  view.publish.label:SetText(guild and L["RR_PUBLISH_AS"]:format(GG:GetCharacterKey()) or L["RR_NO_GUILD"])
  view.publish:SetWidth(view.publish.label:GetStringWidth() + 28)
  view.publish:SetDisabled(not guild or #draft.rosters == 0)
  PaintModal()
end

local function DoPublish(rosters)
  local list = {}
  for _, g in ipairs(rosters) do
    list[#list + 1] = { label = g.label, raid = g.raid, diff = g.diff, members = g.members }
  end
  if RR():Publish(list) then
    print("|cff8B5CF6GG|r " .. L["RR_PUBLISHED_TOAST"])
    state.sub = "list"
    state.sel = 1
  else
    print("|cff8B5CF6GG|r " .. L["RR_NO_GUILD_PUBLISH"])
  end
  state.modal = nil
  Tab:Refresh()
end

local function OnPublishClicked()
  local draft = Draft()
  if #draft.rosters == 0 then return end
  local pending = 0
  for _, g in ipairs(draft.rosters) do if not g.custom then pending = pending + 1 end end
  if pending > 0 then
    state.modal = { raid = DefaultRaid(), diff = 16, count = pending, total = #draft.rosters }
    PaintModal()
    C_Timer.After(0, PaintModal)
    return
  end
  DoPublish(draft.rosters)
end

local function BuildModeCard(parent, titleKey, descKey, mode)
  local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
  card:SetSize((CREATE_LEFT_W - 30) / 2, 56)
  SetBackdrop(card, Fade(Theme.panel, 1), Theme.border)
  local t = CreateText(card, 12.5, Theme.textPrimary, true)
  t:SetPoint("TOPLEFT", 9, -8)
  t:SetText(L[titleKey])
  local d = CreateText(card, 10, Theme.textFaint)
  d:SetPoint("TOPLEFT", 9, -25)
  d:SetWidth(card:GetWidth() - 16)
  d:SetWordWrap(true)
  d:SetMaxLines(2)
  d:SetText(L[descKey])
  card:SetScript("OnClick", function()
    state.mode = mode
    state.cardsOffset = 0
    Tab:Refresh()
  end)
  return card
end

local function BuildStat(parent, labelKey, color)
  local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  box:SetSize(118, 48)
  SetBackdrop(box, Fade(Theme.panel, 1), Theme.border)
  local bar = box:CreateTexture(nil, "ARTWORK")
  bar:SetColorTexture(unpack(color))
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("BOTTOMLEFT")
  bar:SetWidth(3)
  box.value = CreateText(box, 20, color, true)
  box.value:SetPoint("TOPLEFT", 12, -6)
  local label = CreateText(box, 9.5, Theme.textFaint, true)
  label:SetPoint("BOTTOMLEFT", 12, 7)
  label:SetText(L[labelKey]:upper())
  return box
end

local function BuildModal()
  local modal = CreateFrame("Frame", nil, container)
  modal:SetAllPoints()
  modal:SetFrameLevel(container:GetFrameLevel() + 40)
  modal:EnableMouse(true)
  local dim = modal:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints()
  dim:SetColorTexture(0.02, 0.02, 0.04, 0.72)
  local panel = CreateFrame("Frame", nil, modal, "BackdropTemplate")
  panel:SetSize(470, 232)
  panel:SetPoint("CENTER")
  SetBackdrop(panel, Fade(Theme.background, 1), Theme.border)
  modal.title = CreateText(panel, 16, Theme.textPrimary, true)
  modal.title:SetPoint("TOPLEFT", 16, -16)
  local raidLabel = CreateText(panel, 10, Theme.textFaint, true)
  raidLabel:SetPoint("TOPLEFT", 16, -50)
  raidLabel:SetText(L["RR_MODAL_RAID"]:upper())
  modal.raid = BuildSegment(panel, RaidOptions(), function(key) state.modal.raid = key; PaintModal() end)
  modal.raid:SetPoint("TOPLEFT", 16, -66)
  local diffLabel = CreateText(panel, 10, Theme.textFaint, true)
  diffLabel:SetPoint("TOPLEFT", 16, -106)
  diffLabel:SetText(L["RR_MODAL_DIFFICULTY"]:upper())
  modal.diff = BuildSegment(panel, DifficultyOptions(), function(key) state.modal.diff = key; PaintModal() end)
  modal.diff:SetPoint("TOPLEFT", 16, -122)
  local ok = AccentButton(panel, L["RR_PUBLISH"], function()
    local m = state.modal
    if not m then return end
    local draft = Draft()
    for _, g in ipairs(draft.rosters) do
      if not g.custom then g.raid, g.diff = m.raid, m.diff end
    end
    DoPublish(draft.rosters)
  end)
  ok:SetPoint("BOTTOMRIGHT", -16, 16)
  local cancel = GG.Widgets.CreateButton(panel, L["RR_CANCEL"], function()
    state.modal = nil
    PaintModal()
  end)
  cancel:SetPoint("RIGHT", ok, "LEFT", -8, 0)
  modal:Hide()
  container.modal = modal
end

local function BuildCreate()
  local view = CreateFrame("Frame", nil, container)
  view:SetPoint("TOPLEFT", 0, -46)
  view:SetPoint("BOTTOMRIGHT", 0, 0)
  container.createView = view

  view.left = CreateFrame("Frame", nil, view, "BackdropTemplate")
  SetBackdrop(view.left, NAV_BG, Theme.borderSoft)
  view.left:SetPoint("TOPLEFT")
  view.left:SetPoint("BOTTOMLEFT")
  view.left:SetWidth(CREATE_LEFT_W)
  view.modeAll = BuildModeCard(view.left, "RR_MODE_ALL", "RR_MODE_ALL_DESC", "all")
  view.modeAll:SetPoint("TOPLEFT", 12, -12)
  view.modeOne = BuildModeCard(view.left, "RR_MODE_ONE", "RR_MODE_ONE_DESC", "one")
  view.modeOne:SetPoint("TOPRIGHT", -12, -12)

  view.oneName = CreateEditBox(view.left, CREATE_LEFT_W - 24, L["RR_NAME_HINT"], RR().MAX_LABEL)
  view.oneName:SetPoint("TOPLEFT", 12, -78)
  view.oneName:SetScript("OnTextChanged", function(self, user)
    self.placeholder:SetShown(self:GetText() == "")
    if user then state.oneName = self:GetText() end
  end)

  view.paste = CreatePasteBox(view.left, L["RR_PASTE_ALL_HINT"])
  view.paste.box:SetScript("OnTextChanged", function(self, user)
    view.paste.placeholder:SetShown(self:GetText() == "")
    if not user then return end
    if state.mode == "one" then
      state.oneText = self:GetText()
      view.add.label:SetText(L["RR_ADD"]:format(#RR().ParseOne(state.oneText)))
      view.add:SetWidth(view.add.label:GetStringWidth() + 24)
      return
    end
    state.textAll = self:GetText()
    local token = {}
    state.parseToken = token
    C_Timer.After(0.3, function()
      if state.parseToken ~= token then return end
      state.allGroups = ParseAllDraft(state.textAll)
      state.cardsOffset = 0
      PaintCreate()
    end)
  end)

  view.clear = GG.Widgets.CreateButton(view.left, L["RR_CLEAR"], function()
    if state.mode == "one" then
      state.oneText = ""
    else
      state.textAll = ""
      state.allGroups = {}
    end
    view.paste.box:SetText("")
    PaintCreate()
  end)
  view.clear:SetPoint("BOTTOMLEFT", 12, 12)
  view.add = AccentButton(view.left, L["RR_ADD"]:format(0), function()
    local members = RR().ParseOne(state.oneText)
    local name = (state.oneName or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #members == 0 then print("|cff8B5CF6GG|r " .. L["RR_ADD_NO_CHARS"]) return end
    if name == "" then print("|cff8B5CF6GG|r " .. L["RR_ADD_NO_NAME"]) view.oneName:SetFocus() return end
    local replaced = false
    for _, g in ipairs(state.oneList) do
      if g.label:lower() == name:lower() then g.members = members; replaced = true end
    end
    if not replaced then table.insert(state.oneList, NewDraftGroup(name, members, false)) end
    state.oneName, state.oneText = "", ""
    view.oneName:SetText("")
    view.paste.box:SetText("")
    PaintCreate()
    view.oneName:SetFocus()
  end)
  view.add:SetPoint("BOTTOMRIGHT", -12, 12)

  view.right = CreateFrame("Frame", nil, view)
  view.right:SetPoint("TOPLEFT", view.left, "TOPRIGHT", 16, -12)
  view.right:SetPoint("BOTTOMRIGHT", -16, 12)
  view.statRosters = BuildStat(view.right, "RR_STAT_ROSTERS", Theme.teal)
  view.statRosters:SetPoint("TOPLEFT")
  view.statChars = BuildStat(view.right, "RR_STAT_CHARACTERS", Theme.accent)
  view.statChars:SetPoint("LEFT", view.statRosters, "RIGHT", 10, 0)
  view.warn = CreateText(view.right, 11, Theme.gold)
  view.warn:SetPoint("TOPLEFT", 0, -60)
  view.warn:SetPoint("RIGHT", view.right, "RIGHT", 0, 0)
  view.warn:SetWordWrap(true)

  view.cardsClip = CreateFrame("Frame", nil, view.right)
  view.cardsClip:SetClipsChildren(true)
  view.cardsClip:EnableMouseWheel(true)
  view.cardsClip:SetScript("OnMouseWheel", function(_, delta)
    state.cardsOffset = state.cardsOffset - delta * 60
    PaintCards(Draft())
  end)
  view.cardsInner = CreateFrame("Frame", nil, view.cardsClip)
  view.cardsInner:SetAllPoints()
  view.noRosters = CreateText(view.right, 13, Theme.textFaint, true)
  view.noRosters:SetPoint("CENTER", view.right, "CENTER", 0, 0)
  view.noRosters:SetText(L["RR_NO_ROSTERS_YET"])

  view.publish = AccentButton(view.right, L["RR_PUBLISH"], OnPublishClicked)
  view.publish:SetHeight(28)
  view.publish:SetPoint("BOTTOMRIGHT", 0, 0)
end

local function BuildConfirmDelete()
  local confirm = CreateFrame("Frame", nil, container)
  confirm:SetAllPoints()
  confirm:SetFrameLevel(container:GetFrameLevel() + 40)
  confirm:EnableMouse(true)
  local dim = confirm:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints()
  dim:SetColorTexture(0.02, 0.02, 0.04, 0.72)
  local panel = CreateFrame("Frame", nil, confirm, "BackdropTemplate")
  panel:SetSize(420, 120)
  panel:SetPoint("CENTER")
  SetBackdrop(panel, Fade(Theme.background, 1), Theme.border)
  local text = CreateText(panel, 13, Theme.textPrimary, true)
  text:SetPoint("TOPLEFT", 16, -16)
  text:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  text:SetWordWrap(true)
  text:SetText(L["RR_DELETE_CONFIRM"])
  local yes = GG.Widgets.CreateButton(panel, L["RR_DELETE"], function()
    confirm:Hide()
    if RR():Delete() then print("|cff8B5CF6GG|r " .. L["RR_DELETED_TOAST"]) end
    Tab:Refresh()
  end)
  yes:SetPoint("BOTTOMRIGHT", -16, 16)
  yes.label:SetTextColor(unpack(Theme.danger))
  yes:SetBackdropBorderColor(unpack(Fade(Theme.danger, 0.6)))
  local no = GG.Widgets.CreateButton(panel, L["RR_CANCEL"], function() confirm:Hide() end)
  no:SetPoint("RIGHT", yes, "LEFT", -8, 0)
  confirm:Hide()
  container.confirm = confirm
end

local function BuildConfirmInvite()
  local confirm = CreateFrame("Frame", nil, container)
  confirm:SetAllPoints()
  confirm:SetFrameLevel(container:GetFrameLevel() + 40)
  confirm:EnableMouse(true)
  local dim = confirm:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints()
  dim:SetColorTexture(0.02, 0.02, 0.04, 0.72)
  local panel = CreateFrame("Frame", nil, confirm, "BackdropTemplate")
  panel:SetWidth(440)
  panel:SetPoint("CENTER")
  SetBackdrop(panel, Fade(Theme.background, 1), Theme.border)
  confirm.panel = panel
  confirm.text = CreateText(panel, 13.5, Theme.textMuted, true)
  confirm.text:SetPoint("TOPLEFT", 16, -18)
  confirm.text:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  confirm.text:SetWordWrap(true)
  confirm.ask = CreateText(panel, 12.5, Theme.textMuted)
  confirm.ask:SetPoint("TOPLEFT", confirm.text, "BOTTOMLEFT", 0, -8)
  confirm.ask:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  confirm.ask:SetWordWrap(true)
  confirm.ask:SetText(L["RG_CONFIRM_ASK"])
  local yes = GG.Widgets.CreateButton(panel, L["RG_TIP_INVITE_TITLE"], function()
    confirm:Hide()
    if confirm.group then Tab.SendInvite(confirm.group) end
  end)
  yes:SetPoint("BOTTOMRIGHT", -16, 16)
  yes.label:SetTextColor(unpack(Theme.accent))
  yes:SetBackdropBorderColor(unpack(Fade(Theme.accent, 0.6)))
  local no = GG.Widgets.CreateButton(panel, L["RR_CANCEL"], function() confirm:Hide() end)
  no:SetPoint("RIGHT", yes, "LEFT", -8, 0)
  confirm:Hide()
  container.inviteConfirm = confirm
end

function Tab:Attach(parent)
  if container then return container end
  Theme = GG.Theme
  container = CreateFrame("Frame", nil, parent)
  container:SetAllPoints(parent)

  container.sub = BuildSegment(container, {
    { key = "list", label = L["RR_SUB_LIST"] },
    { key = "create", label = L["RR_SUB_CREATE"] },
  }, function(key)
    state.sub = key
    state.modal = nil
    Tab:Refresh()
  end)
  container.sub:SetPoint("TOPLEFT", 12, -10)
  container.info = CreateText(container, 11, Theme.textFaint)
  container.info:SetJustifyH("RIGHT")
  container.delete = GG.Widgets.CreateButton(container, L["RR_DELETE"], function()
    container.confirm:Show()
  end)
  container.delete:SetPoint("TOPRIGHT", -14, -10)
  container.delete.label:SetTextColor(unpack(Theme.danger))
  container.delete:SetBackdropBorderColor(unpack(Fade(Theme.danger, 0.6)))

  BuildList()
  BuildCreate()
  BuildModal()
  BuildConfirmDelete()
  BuildConfirmInvite()
  container:Hide()
  return container
end

function Tab:SetShown(shown)
  if not container then return end
  container:SetShown(shown)
  if shown then
    if not RR():GetCurrentSet() and RR():GuildKey() then state.sub = "create" end
    RR():RequestGuildRoster()
    RR():RequestIlvl()
    if GG.RaidGroups and GG.RaidGroups:RequestIfNeeded() then
      state.searchUntil = GetTime() + SEARCH_SECONDS
      C_Timer.After(SEARCH_SECONDS + 0.1, function() Tab:RefreshIfShown() end)
    end
    state.autoSel = not state.keepSel
    state.keepSel = nil
    self:Refresh()
    C_Timer.After(0, function() Tab:Refresh() end)
  end
end

function Tab:OpenRoster(roster, confirmGroup)
  local set = RR():GetCurrentSet()
  if not (set and roster) then return end
  for i, r in ipairs(set.rosters) do
    if r == roster or r.label == roster.label then state.sel = i break end
  end
  state.sub = "list"
  state.autoSel = false
  if container and container:IsShown() then
    self:Refresh()
  else
    state.keepSel = true
    GG.RosterUI:SelectTab("rosters")
  end
  if confirmGroup and container then Tab.AskInvite(confirmGroup, roster.label, false) end
end

function Tab:RefreshIfShown()
  if container and container:IsShown() and state.sub == "list" then self:Refresh() end
end

function Tab:Refresh()
  if not container or not container:IsShown() then return end
  container.sub:Paint(state.sub)
  local list = state.sub == "list"
  local canDelete = list and RR():CanDelete()
  container.delete:SetShown(canDelete)
  container.info:ClearAllPoints()
  if canDelete then
    container.info:SetPoint("RIGHT", container.delete, "LEFT", -12, 0)
  else
    container.info:SetPoint("TOPRIGHT", -14, -16)
  end
  if not list then
    container.confirm:Hide()
    container.inviteConfirm:Hide()
  end
  container.listView:SetShown(list)
  container.createView:SetShown(not list)
  if list then
    state.modal = nil
    container.modal:Hide()
    PaintList()
  else
    PaintCreate()
  end
end
