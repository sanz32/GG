local ADDON_NAME, GG = ...

local Layout = {}
GG.Layout = Layout

Layout.SCREEN_MARGIN = 12
Layout.RESIZE_DURATION = 0.38
Layout.SLIDER_DURATION = 0.28
Layout.NAME_SIZES = { 17, 15, 13 }

Layout.CARD_WIDTH = 320
Layout.CARD_GAP = 6
Layout.CARD_BAND_TOP = 52
Layout.CARD_BAND_WEEK = 34
Layout.CARD_BAND_BOTTOM = 30
Layout.CARDS_PER_ROW_MAX = 5

local function Clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function Layout.FitToScreen(natW, natH, left, top, screenW, screenH, minW, minH)
  local margin = Layout.SCREEN_MARGIN
  minW, minH = minW or 0, minH or 0
  left = Clamp(left or 0, 0, screenW)
  top = Clamp(top or screenH, 0, screenH)
  local availW = screenW - margin - left
  local availH = top - margin
  local w = math.max(math.min(natW, availW), minW)
  local h = math.max(math.min(natH, availH), minH)
  return w, h, natW > w + 0.5, natH > h + 0.5
end

function Layout.MoveInside(left, top, w, h, screenW, screenH)
  local margin = Layout.SCREEN_MARGIN
  if left + w > screenW - margin then left = screenW - margin - w end
  if left < 0 then left = 0 end
  if top - h < margin then top = h + margin end
  if top > screenH then top = screenH end
  return left, top
end

Layout.TAB_SIZES = {
  raid = { w = 1100, h = 620 },
  bonusRoll = { w = 1330, h = 620 },
  rosters = { w = 1110, h = 620 },
  vaultPending = { minCards = 3, maxCards = 6, minW = 760, minH = 520, maxHFrac = 0.85 },
  settings = { w = 1300, h = 680 },
  settingsSide = { w = 1560, h = 680 },
}
Layout.TAB_MIN_WIDTH = 760
Layout.MIN_CHARACTER_SLOTS = 4

function Layout.WindowSize(spec)
  local sizes = Layout.TAB_SIZES
  local screenW, screenH = spec.screenW or 1536, spec.screenH or 864
  local tab = spec.tab or "all"
  local slots = Layout.MIN_CHARACTER_SLOTS
  local maxShown = math.max(1, spec.maxShown or 15)
  local count = math.max(1, spec.count or 1)
  local w, h
  local trimHeight = true

  if tab == "all" and spec.view == "columns" then
    local pitch, sidebar, edge = spec.colPitch or 1, spec.sidebar or 104, spec.colEdge or 4
    local maxCols = Clamp(math.floor((screenW * 0.9 - sidebar - edge) / pitch), 1, maxShown)
    w = sidebar + math.max(math.min(count, maxCols), slots) * pitch + edge
    h = spec.columnsHeight or 600
    trimHeight = false
  elseif tab == "all" and spec.view == "accounts" then
    w = math.max((spec.accountsW or 0) + (spec.accountsGutter or 0), Layout.TAB_MIN_WIDTH)
    h = Clamp((spec.accountsChrome or 0) + (spec.accountsH or 0), 312, screenH * 0.9)
  elseif tab == "all" then
    local chrome, pitch = spec.rowsChrome or 0, spec.rowPitch or 1
    local maxRows = Clamp(math.floor((screenH * 0.85 - chrome) / pitch), 1, maxShown)
    w = spec.rowsWidth or 1000
    h = chrome + math.max(math.min(count, maxRows), slots) * pitch
  elseif tab == "vaultPending" then
    local def = sizes.vaultPending
    local cardW, gap, margin = spec.vaultCardW or 300, spec.vaultGap or 12, spec.vaultMargin or 12
    local gutter = spec.vaultGutter or 32
    local pending, claimed = spec.vaultPending or 0, spec.vaultClaimed or 0
    local cards = Clamp(math.max(pending, claimed), def.minCards, def.maxCards)
    w = cards * (cardW + gap) - gap + margin * 2 + gutter
    w = math.max(math.min(w, screenW * 0.9), def.minW)
    local perRow = math.max(1, math.floor((w - gutter - margin * 2 + gap) / (cardW + gap)))
    local body = 0
    for _, n in ipairs({ pending, claimed }) do
      if n > 0 then body = body + 30 + math.ceil(n / perRow) * ((spec.vaultCardH or 200) + gap) + 8 end
    end
    h = Clamp((spec.vaultChrome or 0) + margin * 2 + body, def.minH, math.max(def.minH, screenH * def.maxHFrac))
  elseif tab == "settings" then
    local side = spec.settingsWidth and spec.settingsWidth >= sizes.settingsSide.w
    local def = side and sizes.settingsSide or sizes.settings
    w = spec.settingsWidth or math.max(def.w, spec.rowsWidth or def.w)
    h = def.h
  else
    local def = sizes[tab] or sizes.raid
    w = spec.contentWidth or def.w
    h = def.h
  end

  if tab ~= "all" then w = math.max(w, Layout.TAB_MIN_WIDTH) end
  local fitW, fitH = Layout.FitToScreen(w, h, spec.left, spec.top, screenW, screenH, 320, 200)
  return fitW, trimHeight and fitH or h
end

Layout.MEASURE_CACHE_MAX = 4000
Layout.measureCache = {}
Layout.measureCacheSize = 0

function Layout.CachedWidth(measure, text, size, font)
  text = text or ""
  local key = tostring(font) .. "\31" .. tostring(size) .. "\31" .. text
  local cache = Layout.measureCache
  local w = cache[key]
  if w then return w end
  w = measure(text, size, font) or 0
  if w > 0 then
    if Layout.measureCacheSize >= Layout.MEASURE_CACHE_MAX then Layout.ClearMeasureCache() end
    Layout.measureCache[key] = w
    Layout.measureCacheSize = Layout.measureCacheSize + 1
  end
  return w
end

function Layout.ClearMeasureCache()
  Layout.measureCache = {}
  Layout.measureCacheSize = 0
end

function Layout.EaseOutQuint(t)
  t = Clamp(t, 0, 1)
  local u = 1 - t
  return 1 - u * u * u * u * u
end

function Layout.EaseOutCubic(t)
  t = Clamp(t, 0, 1)
  local u = 1 - t
  return 1 - u * u * u
end

function Layout.Tween(from, to, elapsed, duration, ease)
  if not duration or duration <= 0 or elapsed >= duration then return to, true end
  if elapsed <= 0 then return from, false end
  local k = (ease or Layout.EaseOutQuint)(elapsed / duration)
  return from + (to - from) * k, false
end

function Layout.SizeAt(fromW, fromH, toW, toH, elapsed, duration)
  local w, done = Layout.Tween(fromW, toW, elapsed, duration)
  local h = Layout.Tween(fromH, toH, elapsed, duration)
  return w, h, done
end

function Layout.Utf8Len(text)
  if not text or text == "" then return 0 end
  local _, continuation = text:gsub("[\128-\191]", "")
  return #text - continuation
end

function Layout.EstimateWidth(text, size)
  return Layout.Utf8Len(text) * size * 0.55
end

function Layout.DecimalLift(intSize, decSize)
  return math.floor(((intSize or 0) - (decSize or 0)) * 0.35 + 0.5)
end

function Layout.SplitIlvl(ilvl)
  local rounded = tonumber(("%.2f"):format(tonumber(ilvl) or 0))
  if rounded == math.floor(rounded) then return tostring(math.floor(rounded)), "" end
  local whole, decimals = ("%.2f"):format(rounded):match("^(%-?%d+)(%.%d+)$")
  return whole or tostring(rounded), decimals or ""
end

function Layout.NameFontSize(text, available, measure, sizes)
  sizes = sizes or Layout.NAME_SIZES
  for _, size in ipairs(sizes) do
    local w = measure and measure(text, size) or 0
    if not w or w <= 0 then w = Layout.EstimateWidth(text, size) end
    if w <= available then return size, true end
  end
  return sizes[#sizes], false
end

function Layout.Utf8Sub(text, n)
  if not text or n <= 0 then return "" end
  local count, i = 0, 1
  local len = #text
  while i <= len do
    local b = text:byte(i)
    local size = (b >= 240 and 4) or (b >= 224 and 3) or (b >= 192 and 2) or 1
    count = count + 1
    if count > n then return text:sub(1, i - 1) end
    i = i + size
  end
  return text
end

function Layout.FitChars(text, available, measure, size)
  local total = Layout.Utf8Len(text)
  local function Width(s)
    local w = measure and measure(s) or 0
    if not w or w <= 0 then w = Layout.EstimateWidth(s, size or 12) end
    return w
  end
  if total == 0 or Width(text) <= available then return total, false end
  local lo, hi = 0, total
  while lo < hi do
    local mid = math.floor((lo + hi + 1) / 2)
    if Width(Layout.Utf8Sub(text, mid)) <= available then lo = mid else hi = mid - 1 end
  end
  return lo, true
end

function Layout.WeekBandHeight(_)
  return Layout.CARD_BAND_WEEK
end

function Layout.CardHeight(_)
  return Layout.CARD_BAND_TOP + Layout.CARD_BAND_WEEK + Layout.CARD_BAND_BOTTOM
end

function Layout.CardsPerRow(maxCardsInAccount, availWidth)
  local want = Clamp(maxCardsInAccount or 1, 1, Layout.CARDS_PER_ROW_MAX)
  local fit = math.floor(((availWidth or 0) + Layout.CARD_GAP) / (Layout.CARD_WIDTH + Layout.CARD_GAP))
  return math.max(1, math.min(want, fit))
end

function Layout.CardGridWidth(perRow)
  return perRow * Layout.CARD_WIDTH + (perRow - 1) * Layout.CARD_GAP
end

function Layout.CardPosition(index, perRow, cardHeight)
  local i = index - 1
  local row, col = math.floor(i / perRow), i % perRow
  return col * (Layout.CARD_WIDTH + Layout.CARD_GAP), row * (cardHeight + Layout.CARD_GAP), row + 1, col + 1
end

function Layout.CardRows(count, perRow)
  if not count or count <= 0 then return 0 end
  return math.ceil(count / perRow)
end

Layout.ROUND_MIN = 2
Layout.ROUND_MAX = 10

function Layout.RoundBucket(r, w, h)
  r = tonumber(r) or 0
  if r <= 0 then return 0 end
  if w and h and w > 0 and h > 0 then r = math.min(r, math.min(w, h) / 2) end
  return Clamp(math.floor(r + 0.5), Layout.ROUND_MIN, Layout.ROUND_MAX)
end

function Layout.RowVisible(top, height, listH)
  if height > listH + 0.5 then return top < listH - 0.5 and top + height > 0.5 end
  return top >= -0.5 and top + height <= listH + 0.5
end

function Layout.ScrollSnaps(tops, heights, contentH, listH, overlap)
  local snaps = {}
  local function Add(value)
    if #snaps == 0 or value > snaps[#snaps] + 0.5 then snaps[#snaps + 1] = value end
    return contentH - value <= listH + 0.5
  end
  local step = math.max(1, listH - (overlap or 0))
  for r, top in ipairs(tops) do
    if Add(top) then break end
    local height = heights and heights[r] or 0
    if height > listH + 0.5 then
      local last = top + height - listH
      local at, done = top + step, false
      while at < last - 0.5 do
        if Add(at) then done = true break end
        at = at + step
      end
      if done or Add(last) then break end
    end
  end
  if #snaps == 0 then snaps[1] = 0 end
  return snaps
end
