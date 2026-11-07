local ADDON_NAME, GG = ...

GG.Currencies = {}

GG.Currencies.BOUNTY_KEY = "bounty"
GG.Currencies.NEMESIS_KEY = "nemesis"
GG.Currencies.KEYSTONE_KEY = "keystone"
GG.Currencies.KINDOJAN_KEY = "kindojan"

function GG.Currencies:CurrencyKey(currencyID) return tostring(currencyID) end
function GG.Currencies:ItemKey(itemID) return "item:" .. tostring(itemID) end

function GG.Currencies:ItemExists(itemID)
  if not (C_Item and C_Item.DoesItemExistByID) then return true end
  return C_Item.DoesItemExistByID(itemID) == true
end

function GG.Currencies:IsVisible(key)
  if not key then return true end
  local prefs = GGDB and GGDB.options and GGDB.options.currencyVisibility
  return not (prefs and prefs[key] == false)
end

function GG.Currencies:SetVisible(key, visible)
  if not key then return end
  GGDB.options = GGDB.options or {}
  GGDB.options.currencyVisibility = GGDB.options.currencyVisibility or {}
  if visible then
    GGDB.options.currencyVisibility[key] = nil
  else
    GGDB.options.currencyVisibility[key] = false
  end
end

function GG.Currencies:GetTrackables()
  local out = {}

  for _, currencyID in ipairs(GG.Season.SEASON_CURRENCY_IDS or {}) do
    local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(currencyID)
    out[#out + 1] = {
      kind = "currency",
      key = self:CurrencyKey(currencyID),
      id = currencyID,
      name = (info and info.name) or ("#" .. currencyID),
      icon = info and info.iconFileID,
    }
  end

  for _, itemID in ipairs(GG.Season.SEASON_ITEM_IDS or {}) do
    if self:ItemExists(itemID) then
      out[#out + 1] = {
        kind = "item",
        key = self:ItemKey(itemID),
        id = itemID,
        name = C_Item.GetItemNameByID(itemID) or ("#" .. itemID),
        icon = C_Item.GetItemIconByID(itemID),
      }
    end
  end

  local bounty = GG.Season.BOUNTY
  if bounty and bounty.itemID then
    out[#out + 1] = {
      kind = "bounty",
      key = self.BOUNTY_KEY,
      id = bounty.itemID,
      name = C_Item.GetItemNameByID(bounty.itemID) or ("#" .. bounty.itemID),
      icon = C_Item.GetItemIconByID(bounty.itemID) or bounty.iconTexture,
    }
  end

  return out
end

function GG.Currencies:GetQuestTrackables()
  local out = {}

  local nemesis = GG.Season.NEMESIS
  if nemesis and nemesis.itemID then
    out[#out + 1] = {
      kind = "nemesis",
      key = self.NEMESIS_KEY,
      id = nemesis.itemID,
      name = C_Item.GetItemNameByID(nemesis.itemID) or ("#" .. nemesis.itemID),
      icon = nemesis.iconFileID or C_Item.GetItemIconByID(nemesis.itemID),
    }
  end

  local keystone = GG.Season.CRACKED_KEYSTONE
  if keystone and keystone.itemID then
    out[#out + 1] = {
      kind = "keystone",
      key = self.KEYSTONE_KEY,
      id = keystone.itemID,
      name = C_Item.GetItemNameByID(keystone.itemID) or ("#" .. keystone.itemID),
      icon = C_Item.GetItemIconByID(keystone.itemID) or keystone.iconTexture,
    }
  end

  local kindojan = GG.Season.KINDOJAN
  if kindojan then
    out[#out + 1] = {
      kind = "kindojan",
      key = self.KINDOJAN_KEY,
      id = kindojan.itemID,
      labelKey = "KINDOJAN_TITLE",
      name = C_Item.GetItemNameByID(kindojan.itemID) or ("#" .. kindojan.itemID),
      icon = kindojan.iconTexture,
    }
  end

  return out
end

function GG.Currencies:CountVisibleSlots()
  local n = 0
  for _, currencyID in ipairs(GG.Season.SEASON_CURRENCY_IDS or {}) do
    if self:IsVisible(self:CurrencyKey(currencyID)) then n = n + 1 end
  end
  for _, itemID in ipairs(GG.Season.SEASON_ITEM_IDS or {}) do
    if self:IsVisible(self:ItemKey(itemID)) and self:ItemExists(itemID) then n = n + 1 end
  end
  if GG.Season.BOUNTY and self:IsVisible(self.BOUNTY_KEY) then n = n + 1 end
  return n
end

function GG.Currencies:MaxSlots()
  return #(GG.Season.SEASON_CURRENCY_IDS or {}) + #(GG.Season.SEASON_ITEM_IDS or {})
    + (GG.Season.BOUNTY and 1 or 0)
end

function GG.Currencies:GridGroups()
  local kinds = {}
  for _, id in ipairs(GG.Season.SEASON_CURRENCY_IDS or {}) do kinds[id] = "currency" end
  for _, id in ipairs(GG.Season.SEASON_ITEM_IDS or {}) do kinds[id] = "item" end
  if GG.Season.BOUNTY then kinds.bounty = "bounty" end

  local groups = {}
  local function AddGroup(ids)
    local cells = { labelKey = ids.labelKey }
    for _, id in ipairs(ids) do
      local kind = kinds[id]
      if kind then
        kinds[id] = nil
        local visible
        if kind == "currency" then
          visible = self:IsVisible(self:CurrencyKey(id))
        elseif kind == "bounty" then
          visible = self:IsVisible(self.BOUNTY_KEY)
        else
          visible = self:IsVisible(self:ItemKey(id)) and self:ItemExists(id)
        end
        if visible then cells[#cells + 1] = { kind = kind, id = id } end
      end
    end
    if #cells > 0 then groups[#groups + 1] = cells end
  end

  for _, ids in ipairs(GG.Season.CURRENCY_GROUPS or {}) do AddGroup(ids) end
  local rest = {}
  for _, id in ipairs(GG.Season.SEASON_CURRENCY_IDS or {}) do
    if kinds[id] then rest[#rest + 1] = id end
  end
  for _, id in ipairs(GG.Season.SEASON_ITEM_IDS or {}) do
    if kinds[id] then rest[#rest + 1] = id end
  end
  if kinds.bounty then rest[#rest + 1] = "bounty" end
  AddGroup(rest)
  return groups
end

function GG.Currencies:BountyState(bounty)
  if not bounty then return "none" end
  if (bounty.delveCompletionsThisWeek or 0) > 0 then return "done" end
  if bounty.hasBuff then return "buff" end
  if (bounty.bagCount or 0) > 0 then return "bag" end
  if (bounty.fluteBagCount or 0) > 0 then return "flute" end
  return "none"
end

function GG.Currencies:StackedLayout(perRow)
  local layout = { cells = {}, rows = 0, ruleRows = {}, labels = {} }
  for groupIndex, cells in ipairs(self:GridGroups()) do
    if groupIndex > 1 then layout.ruleRows[#layout.ruleRows + 1] = layout.rows end
    layout.labels[groupIndex] = { labelKey = cells.labelKey, row = layout.rows, rows = math.ceil(#cells / perRow) }
    for i = 1, #cells do
      layout.cells[#layout.cells + 1] = {
        row = layout.rows + math.floor((i - 1) / perRow),
        col = (i - 1) % perRow,
      }
    end
    layout.rows = layout.rows + math.ceil(#cells / perRow)
  end
  return layout
end

function GG.Currencies:SideBySideLayout(rowsPerBlock)
  local layout = { cells = {}, blockColumns = {}, blockLabels = {} }
  for blockIndex, cells in ipairs(self:GridGroups()) do
    local columns = math.ceil(#cells / rowsPerBlock)
    layout.blockColumns[blockIndex] = columns
    layout.blockLabels[blockIndex] = cells.labelKey
    for i = 1, #cells do
      layout.cells[#layout.cells + 1] = {
        block = blockIndex,
        col = (i - 1) % columns,
        row = math.floor((i - 1) / columns),
      }
    end
  end
  return layout
end

function GG.Currencies:FormatAmount(amount, decimalSeparator)
  local n = math.floor(amount or 0)
  if n < 1000 then return ("%d"):format(n) end
  if n >= 10000 then return ("%dk"):format(math.floor(n / 1000)) end
  local tenths = math.floor(n / 100)
  local decimal = tenths % 10
  if decimal == 0 then return ("%dk"):format(math.floor(tenths / 10)) end
  return ("%d%s%dk"):format(math.floor(tenths / 10), decimalSeparator or ",", decimal)
end

function GG.Currencies:IsAtCap(currency)
  if not currency then return false end
  local cap = currency.maxQuantity
  local quantity = currency.quantity or 0
  if not cap or cap <= 0 or quantity <= 0 then return false end
  if currency.useTotalEarnedForMaxQty then return (currency.totalEarned or 0) >= cap end
  return quantity >= cap
end

function GG.Currencies:VisibilitySignature()
  local parts = {
    self:IsVisible(self.BOUNTY_KEY) and "1" or "0",
    self:IsVisible(self.NEMESIS_KEY) and "1" or "0",
    self:IsVisible(self.KEYSTONE_KEY) and "1" or "0",
    self:IsVisible(self.KINDOJAN_KEY) and "1" or "0",
  }
  for _, currencyID in ipairs(GG.Season.SEASON_CURRENCY_IDS or {}) do
    parts[#parts + 1] = self:IsVisible(self:CurrencyKey(currencyID)) and "1" or "0"
  end
  for _, itemID in ipairs(GG.Season.SEASON_ITEM_IDS or {}) do
    parts[#parts + 1] = self:IsVisible(self:ItemKey(itemID)) and "1" or "0"
  end
  return table.concat(parts)
end

local bountyIconRequestPending = false

local function AurasRestricted()
  if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
  local restricted = C_Secrets.ShouldAurasBeSecret()
  if issecretvalue(restricted) then return true end
  return restricted == true
end

local hasDoneColdStartCompare = false
local trackedBountyAuraInstanceID = nil
local pendingDelveCompletion = false
local bountyRemovalUnverified = false

function GG.Currencies:ResetBountySessionTracking()
  hasDoneColdStartCompare = false
  trackedBountyAuraInstanceID = nil
  pendingDelveCompletion = false
  bountyRemovalUnverified = false
end

function GG.Currencies:OnBountyAuraUpdate(updateInfo)
  if not trackedBountyAuraInstanceID or not updateInfo then return end
  local removed = updateInfo.removedAuraInstanceIDs
  if issecretvalue(removed) or issecretvalue(updateInfo.isFullUpdate) or updateInfo.isFullUpdate then
    bountyRemovalUnverified = true
    return
  end
  if not removed then return end
  for _, instanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
    if instanceID == trackedBountyAuraInstanceID then
      trackedBountyAuraInstanceID = nil
      pendingDelveCompletion = true
      break
    end
  end
end

local function BuildBountyStatus(previous)
  local bounty = GG.Season.BOUNTY
  if not bounty then return nil end

  local iconFileID = C_Item.GetItemIconByID(bounty.itemID)
  if (not iconFileID or iconFileID == 0) and not bountyIconRequestPending then
    bountyIconRequestPending = true
    Item:CreateFromItemID(bounty.itemID):ContinueOnItemLoad(function()
      bountyIconRequestPending = false
      GG.Currencies:Update()
    end)
  end

  local hasBuff = false
  local aurasRestricted = bounty.spellID ~= nil and AurasRestricted()
  if aurasRestricted then
    hasBuff = previous ~= nil and previous.hasBuff == true
  elseif bounty.spellID then
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(bounty.spellID)
    local auraIsSecret = issecretvalue(aura)
    hasBuff = aura ~= nil and not auraIsSecret
    if auraIsSecret and previous then
      hasBuff = previous.hasBuff == true
    end
    if bountyRemovalUnverified and trackedBountyAuraInstanceID and not InCombatLockdown() then
      local ok, byInstance = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", trackedBountyAuraInstanceID)
      if ok and not issecretvalue(byInstance) and not auraIsSecret then
        bountyRemovalUnverified = false
        if byInstance == nil and aura == nil then
          trackedBountyAuraInstanceID = nil
          pendingDelveCompletion = true
        end
      end
    end
    if hasBuff and not auraIsSecret and aura.auraInstanceID then
      trackedBountyAuraInstanceID = aura.auraInstanceID
    end
  end

  local weekKey = GG:GetWeekKey()
  local sameWeek = previous ~= nil and previous.weekKey == weekKey
  local delveCompletionsThisWeek = (sameWeek and previous.delveCompletionsThisWeek) or 0

  if not hasDoneColdStartCompare and not aurasRestricted then
    hasDoneColdStartCompare = true
    local previousHasBuff = (sameWeek and previous.hasBuff) or false
    if previousHasBuff and not hasBuff then
      delveCompletionsThisWeek = delveCompletionsThisWeek + 1
    end
  elseif pendingDelveCompletion then
    pendingDelveCompletion = false
    if sameWeek then
      delveCompletionsThisWeek = delveCompletionsThisWeek + 1
    end
  end

  return {
    itemID = bounty.itemID,
    iconFileID = iconFileID or 0,
    bagCount = C_Item.GetItemCount(bounty.itemID) or 0,
    fluteBagCount = bounty.fluteItemID and C_Item.GetItemCount(bounty.fluteItemID) or 0,
    hasBuff = hasBuff,
    weeklyQuestClaimed = bounty.questID ~= nil and C_QuestLog.IsQuestFlaggedCompleted(bounty.questID) == true,
    delveCompletionsThisWeek = delveCompletionsThisWeek,
    weekKey = weekKey,
  }
end

local nemesisIconRequestPending = false

local function BuildNemesisStatus()
  local nemesis = GG.Season.NEMESIS
  if not nemesis or not nemesis.questIDs then return nil end

  local iconFileID = nemesis.iconFileID or C_Item.GetItemIconByID(nemesis.itemID)
  if (not iconFileID or iconFileID == 0) and not nemesisIconRequestPending then
    nemesisIconRequestPending = true
    Item:CreateFromItemID(nemesis.itemID):ContinueOnItemLoad(function()
      nemesisIconRequestPending = false
      GG.Currencies:Update()
    end)
  end

  local completedCount = 0
  for _, questID in ipairs(nemesis.questIDs) do
    if C_QuestLog.IsQuestFlaggedCompleted(questID) == true then
      completedCount = completedCount + 1
    end
  end

  return {
    itemID = nemesis.itemID,
    iconFileID = iconFileID or 0,
    completedCount = completedCount,
    total = #nemesis.questIDs,
    weekKey = GG:GetWeekKey(),
  }
end

local function BuildKeystoneStatus()
  local keystone = GG.Season.CRACKED_KEYSTONE
  if not keystone or not keystone.questID then return nil end
  return {
    itemID = keystone.itemID,
    completed = C_QuestLog.IsQuestFlaggedCompleted(keystone.questID) == true,
    inProgress = C_QuestLog.IsOnQuest(keystone.questID) == true,
    bagCount = keystone.itemID and C_Item.GetItemCount(keystone.itemID) or 0,
    weekKey = GG:GetWeekKey(),
  }
end

local function BuildKindojanStatus()
  local kindojan = GG.Season.KINDOJAN
  if not kindojan then return nil end
  local completedIDs = {}
  for _, quest in ipairs(kindojan.quests) do
    if C_QuestLog.IsQuestFlaggedCompleted(quest.id) == true then
      completedIDs[#completedIDs + 1] = quest.id
    end
  end
  return {
    completedIDs = completedIDs,
    fragments = C_Item.GetItemCount(kindojan.itemID, true) or 0,
  }
end

function GG.Currencies:KindojanState(status)
  local kindojan = GG.Season.KINDOJAN
  local total = kindojan and #kindojan.quests or 0
  local perItem = kindojan and kindojan.fragmentsPerItem or 3
  local maxItems = math.floor(total / perItem)
  if type(status) ~= "table" then
    return { noData = true, done = 0, total = total, fragments = 0, bought = 0, maxItems = maxItems }
  end
  local completed = {}
  if type(status.completedIDs) == "table" then
    for _, questID in ipairs(status.completedIDs) do completed[questID] = true end
  end
  local done = 0
  for _, quest in ipairs(kindojan and kindojan.quests or {}) do
    if completed[quest.id] then done = done + 1 end
  end
  local fragments = type(status.fragments) == "number" and status.fragments or 0
  local bought = math.floor(math.max(done - fragments, 0) / perItem)
  bought = math.min(bought, maxItems)
  return {
    done = done,
    total = total,
    fragments = fragments,
    bought = bought,
    maxItems = maxItems,
    canBuy = fragments >= perItem,
    complete = maxItems > 0 and bought >= maxItems,
  }
end

function GG.Currencies:Update()
  local record = GG:GetOrCreateCharacterRecord()
  record.currencies = {}
  record.bounty = BuildBountyStatus(record.bounty)
  record.nemesis = BuildNemesisStatus()
  record.crackedKeystone = BuildKeystoneStatus()
  record.kindojan = BuildKindojanStatus()

  for _, currencyID in ipairs(GG.Season.SEASON_CURRENCY_IDS) do
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if info then
      record.currencies[tostring(currencyID)] = {
        currencyID = currencyID,
        name = info.name,
        iconFileID = info.iconFileID,
        quantity = info.quantity or 0,
        maxQuantity = info.maxQuantity,
        totalEarned = info.totalEarned,
        useTotalEarnedForMaxQty = info.useTotalEarnedForMaxQty,
        maxWeeklyQuantity = info.maxWeeklyQuantity,
        quantityEarnedThisWeek = info.quantityEarnedThisWeek,
        weekKey = GG:GetWeekKey(),
      }
    end
  end

  record.items = record.items or {}
  local pendingItemIDs = {}
  for _, itemID in ipairs(GG.Season.SEASON_ITEM_IDS or {}) do
    local exists = self:ItemExists(itemID)
    local name = exists and C_Item.GetItemNameByID(itemID)
    if not exists then
    elseif name then
      record.items[tostring(itemID)] = {
        itemID = itemID,
        name = name,
        quantity = C_Item.GetItemCount(itemID) or 0,
        iconFileID = C_Item.GetItemIconByID(itemID),
      }
    else
      table.insert(pendingItemIDs, itemID)
    end
  end

  if #pendingItemIDs > 0 then
    local container = ContinuableContainer:Create()
    for _, itemID in ipairs(pendingItemIDs) do
      container:AddContinuable(Item:CreateFromItemID(itemID))
    end
    container:ContinueOnLoad(function()
      for _, itemID in ipairs(pendingItemIDs) do
        local name = C_Item.GetItemNameByID(itemID)
        if name then
          record.items[tostring(itemID)] = {
            itemID = itemID,
            name = name,
            quantity = C_Item.GetItemCount(itemID) or 0,
            iconFileID = C_Item.GetItemIconByID(itemID),
          }
          GG:RequestBroadcast("currencies")
          if GG.UI and GG.UI.Refresh then GG.UI:Refresh() end
          if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
        end
      end
    end)
  end

  GG:RequestBroadcast("currencies")
  GG:RequestBroadcast("kindojan")
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
end

function GG.Currencies:ForDisplay(currency, record)
  if not currency or not GG:IsBeforeThisWeek(currency.weekKey, record and record.ts) then return currency end
  local copy = {}
  for k, v in pairs(currency) do copy[k] = v end
  copy.quantityEarnedThisWeek = 0
  if currency.useTotalEarnedForMaxQty then
    local live = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and currency.currencyID
      and C_CurrencyInfo.GetCurrencyInfo(currency.currencyID)
    if live and live.maxQuantity and live.maxQuantity > 0 then
      copy.maxQuantity = live.maxQuantity
    else
      copy.staleCap = true
    end
  end
  return copy
end

function GG.Currencies:UpdateGold()
  local record = GG:GetOrCreateCharacterRecord()
  record.money = GetMoney()
  GG:RequestBroadcast("money")
end
