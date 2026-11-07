local ADDON_NAME, GG = ...

GG.Vault = {}

GG.VAULT_ITEM_DATA_VERSION = 1

local function GetWeekKey()
  return GG:GetWeekKey()
end

local awaitingLoot
local lastHasAvailableRewards

local CLAIM_STALE_SECONDS = 10

local function ResolveBestItemReward(rewards, callback)
  local itemRewards = {}
  for _, r in ipairs(rewards or {}) do
    if r.type == Enum.CachedRewardType.Item and r.itemDBID and not C_Item.IsItemKeystoneByID(r.id) then
      table.insert(itemRewards, r)
    end
  end
  if #itemRewards == 0 then
    callback(nil)
    return
  end

  local container = ContinuableContainer:Create()
  for _, r in ipairs(itemRewards) do
    container:AddContinuable(Item:CreateFromItemID(r.id))
  end
  container:ContinueOnLoad(function()
    local best, bestQuality, bestLevel = nil, -1, -1
    for _, r in ipairs(itemRewards) do
      local _, _, quality, ilvl = C_Item.GetItemInfo(r.id)
      quality, ilvl = quality or 0, ilvl or 0
      if quality > bestQuality or (quality == bestQuality and ilvl > bestLevel) then
        best, bestQuality, bestLevel = r, quality, ilvl
      end
    end
    callback(best and C_WeeklyRewards.GetItemHyperlink(best.itemDBID) or nil)
  end)
end

function GG.Vault:Update()
  local record = GG:GetOrCreateCharacterRecord()

  local activities = C_WeeklyRewards.GetActivities()
  if not self:IsActivityDataLoaded(activities) then return end

  local weekKey = GetWeekKey()
  local carried = {}
  local previous = record.vault
  if previous and previous.weekKey == weekKey and previous.itemDataVersion == GG.VAULT_ITEM_DATA_VERSION then
    for _, old in ipairs(previous.slots or {}) do
      if old.itemLink or old.currencyID then carried[self:SlotKey(old)] = old end
    end
  end

  record.vault = record.vault or {}
  record.vault.slots = {}
  record.vault.itemDataVersion = GG.VAULT_ITEM_DATA_VERSION
  record.vault.weekKey = weekKey

  for _, activity in ipairs(activities) do
    local hasRewards = activity.rewards and #activity.rewards > 0
    local filled = activity.threshold and activity.threshold > 0
      and activity.progress and activity.progress >= activity.threshold

    local slot = {
      id = activity.id,
      type = activity.type,
      index = activity.index,
      threshold = activity.threshold,
      progress = activity.progress,
      level = activity.level,
      unlocked = filled,
      claimID = activity.claimID,
    }
    local currency = hasRewards and self:PickCurrencyReward(activity.rewards)
    if currency then
      slot.currencyID, slot.quantity = currency.id, currency.quantity
    end
    table.insert(record.vault.slots, slot)

    if hasRewards then
      local slotKey = self:SlotKey(slot)
      local ok, err = pcall(ResolveBestItemReward, activity.rewards, function(itemLink)
        if not itemLink then return end
        local itemLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
        slot.itemLink, slot.itemLevel = itemLink, itemLevel
        local current = GG:GetOrCreateCharacterRecord().vault
        if current and current.weekKey == weekKey and current.slots then
          for _, live in ipairs(current.slots) do
            if self:SlotKey(live) == slotKey then
              live.itemLink, live.itemLevel = itemLink, itemLevel
            end
          end
        end
        GG:RequestBroadcast("vault")
        if GG.UI and GG.UI.Refresh then GG.UI:Refresh() end
      end)
      if not ok then
        geterrorhandler()(("GG: ResolveBestItemReward failed: %s"):format(tostring(err)))
      end
    end
  end

  local hasAvailableRewards = C_WeeklyRewards.HasAvailableRewards() == true
  local interacting = C_WeeklyRewards.HasInteraction and C_WeeklyRewards.HasInteraction() == true
  local vault = record.vault
  if hasAvailableRewards and vault.claimedWeekKey == weekKey then
    local reopened = interacting
      and time() - (vault.claimedAt or 0) > CLAIM_STALE_SECONDS
    if reopened then
      vault.claimedWeekKey, vault.claimedAt, vault.claim = nil, nil, nil
    else
      hasAvailableRewards = false
    end
  end
  record.vault.hasAvailableRewards = hasAvailableRewards

  local claimedThisWeek = vault.claimedWeekKey == weekKey
  if hasAvailableRewards or (not claimedThisWeek and not interacting) then
    for _, slot in ipairs(record.vault.slots) do
      local old = carried[self:SlotKey(slot)]
      if old and not slot.itemLink and not slot.currencyID then
        slot.itemLink = old.itemLink
        slot.itemLevel = old.itemLevel
        slot.currencyID = old.currencyID
        slot.quantity = old.quantity
      end
    end
  end

  if awaitingLoot and lastHasAvailableRewards == true and hasAvailableRewards == false then
    awaitingLoot.expiresAt = time() + 15
  end
  lastHasAvailableRewards = hasAvailableRewards

  GG:RequestBroadcast("vault")
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
end

function GG.Vault:IsActivityDataLoaded(activities)
  if type(activities) ~= "table" then return false end
  for _, activity in ipairs(activities) do
    if activity.threshold and activity.threshold > 0 then return true end
  end
  return false
end

function GG.Vault:SlotKey(slot)
  return tostring(slot.type) .. ":" .. tostring(slot.index)
end

function GG.Vault:HasFreshItemData(record)
  return record.vault ~= nil and record.vault.itemDataVersion == GG.VAULT_ITEM_DATA_VERSION
end

function GG.Vault:IsCurrentWeek(record)
  return record.vault ~= nil and record.vault.weekKey == GetWeekKey()
end

function GG.Vault:CurrentKeystone(record)
  local keystone = record and record.mythicplus and record.mythicplus.keystone
  if not keystone or GG:IsBeforeThisWeek(keystone.weekKey, record.ts) then return nil end
  return keystone
end

function GG.Vault:HasPendingRewards(record)
  local vault = record and record.vault
  if not vault then return false end
  if vault.hasAvailableRewards == true then return true end
  if self:IsCurrentWeek(record) then return false end
  for _, slot in ipairs(vault.slots or {}) do
    if slot.unlocked then return true end
  end
  return false
end

function GG.Vault:RecordClaimed(activityId, itemLink)
  local record = GG:GetOrCreateCharacterRecord()
  record.vaultHistory = record.vaultHistory or {}
  local weekKey = GetWeekKey()
  record.vaultHistory[weekKey] = record.vaultHistory[weekKey] or { claimed = {} }
  record.vaultHistory[weekKey].claimed[tostring(activityId)] = {
    itemLink = itemLink,
    ts = time(),
  }
  GG:RequestBroadcast("vault")
end

if type(C_WeeklyRewards) == "table" and type(C_WeeklyRewards.ClaimReward) == "function" then
  hooksecurefunc(C_WeeklyRewards, "ClaimReward", function(claimID)
    GG.Vault:OnClaimReward(claimID)
  end)
end

function GG.Vault:PickCurrencyReward(rewards)
  local best
  for _, r in ipairs(rewards or {}) do
    if r.type == Enum.CachedRewardType.Item and not C_Item.IsItemKeystoneByID(r.id) then
      return nil
    end
    if r.type == Enum.CachedRewardType.Currency and (not best or (r.quantity or 0) > (best.quantity or 0)) then
      best = r
    end
  end
  return best
end

function GG.Vault:BuildClaim(slots, claimID, weekKey)
  local claim = { weekKey = weekKey, at = GetServerTime() }
  local slot
  for _, s in ipairs(slots or {}) do
    if claimID ~= nil and s.claimID == claimID then slot = s break end
  end
  if slot then
    claim.type, claim.index, claim.level = slot.type, slot.index, slot.level
    claim.itemLink, claim.itemLevel = slot.itemLink, slot.itemLevel
    claim.currencyID, claim.quantity = slot.currencyID, slot.quantity
  end
  if claim.itemLink or claim.currencyID then return claim end

  for _, activity in ipairs(C_WeeklyRewards.GetActivities() or {}) do
    if claimID ~= nil and activity.claimID == claimID then
      claim.type, claim.index, claim.level = activity.type, activity.index, activity.level
      local currency = self:PickCurrencyReward(activity.rewards)
      if currency then
        claim.currencyID, claim.quantity = currency.id, currency.quantity
      else
        local best, bestQuality, bestLevel = nil, -1, -1
        for _, r in ipairs(activity.rewards or {}) do
          if r.type == Enum.CachedRewardType.Item and r.itemDBID and not C_Item.IsItemKeystoneByID(r.id) then
            local _, _, quality, ilvl = C_Item.GetItemInfo(r.id)
            quality, ilvl = quality or 0, ilvl or 0
            if quality > bestQuality or (quality == bestQuality and ilvl > bestLevel) then
              best, bestQuality, bestLevel = r, quality, ilvl
            end
          end
        end
        if best then
          claim.itemLink = C_WeeklyRewards.GetItemHyperlink(best.itemDBID)
          claim.itemLevel = claim.itemLink and C_Item.GetDetailedItemLevelInfo(claim.itemLink)
        end
      end
      break
    end
  end
  return claim
end

function GG.Vault:GetClaimThisWeek(record)
  local claim = record and record.vault and record.vault.claim
  if claim and claim.weekKey == GetWeekKey() then return claim end
  return nil
end

function GG.Vault:OnClaimReward(claimID)
  awaitingLoot = { activityId = claimID, expiresAt = nil }
  local record = GG:GetOrCreateCharacterRecord()
  if not record.vault then return end
  local weekKey = GetWeekKey()
  local ok, claim = pcall(self.BuildClaim, self, record.vault.slots, claimID, weekKey)
  record.vault.claim = ok and claim or { weekKey = weekKey, at = GetServerTime() }
  record.vault.claimedWeekKey = weekKey
  record.vault.claimedAt = time()
  record.vault.hasAvailableRewards = false
  GG:RequestBroadcast("vault")
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
end

function GG.Vault:OnLootMessage(message)
  if not awaitingLoot or not awaitingLoot.expiresAt then return end
  if time() > awaitingLoot.expiresAt then
    awaitingLoot = nil
    return
  end

  local itemLink = message:match("(|c%x+|Hitem:.-|h%[.-%]|h|r)")
  if itemLink then
    self:RecordClaimed(awaitingLoot.activityId, itemLink)
    awaitingLoot = nil
  end
end

function GG.Vault:UpdateMythicPlus()
  local record = GG:GetOrCreateCharacterRecord()
  record.mythicplus = record.mythicplus or {}

  local ratingSummary = C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")
  if ratingSummary and ratingSummary.currentSeasonScore then
    record.mythicplus.rating = ratingSummary.currentSeasonScore
  end

  local bestSeasonScore = C_MythicPlus.GetSeasonBestMythicRatingFromThisExpansion()
  if bestSeasonScore then
    record.mythicplus.bestSeasonScore = bestSeasonScore
  end

  local mapTable = C_ChallengeMode.GetMapTable() or {}
  local canRebuild = ratingSummary ~= nil and #mapTable > 0
  if canRebuild then record.mythicplus.dungeons = {} end
  local runsByMap = {}
  if ratingSummary and ratingSummary.runs then
    for _, run in ipairs(ratingSummary.runs) do
      runsByMap[run.challengeModeID] = run
    end
  end
  for _, mapId in ipairs(canRebuild and mapTable or {}) do
    local name = C_ChallengeMode.GetMapUIInfo(mapId)
    local run = runsByMap[mapId]
    table.insert(record.mythicplus.dungeons, {
      challengeModeID = mapId,
      dungeonName = name,
      level = run and run.bestRunLevel or 0,
      score = run and run.mapScore or 0,
      finishedSuccess = run and run.finishedSuccess or false,
    })
  end

  local keystoneMapID = C_MythicPlus.GetOwnedKeystoneMapID()
  local keystoneLevel = C_MythicPlus.GetOwnedKeystoneLevel()
  local keystoneChallengeModeID = C_MythicPlus.GetOwnedKeystoneChallengeMapID()

  local keystoneItemLink = GG:FindOwnedKeystoneItemLink()
  if keystoneItemLink and LinkUtil.IsLinkType(keystoneItemLink, "keystone") then
    local _, linkOptions = LinkUtil.ExtractLink(keystoneItemLink)
    if linkOptions then
      local _, linkChallengeModeID, linkLevel = LinkUtil.SplitLinkOptions(linkOptions)
      linkChallengeModeID = tonumber(linkChallengeModeID)
      linkLevel = tonumber(linkLevel)
      if linkChallengeModeID and linkLevel then
        keystoneChallengeModeID = linkChallengeModeID
        keystoneLevel = linkLevel
      end
    end
  end

  local stored = record.mythicplus.keystone

  if keystoneMapID and keystoneLevel then
    local dungeonName
    if keystoneChallengeModeID then
      local name = C_ChallengeMode.GetMapUIInfo(keystoneChallengeModeID)
      dungeonName = name
    end
    record.mythicplus.keystone = {
      mapId = keystoneMapID,
      level = keystoneLevel,
      challengeModeID = keystoneChallengeModeID,
      dungeonName = dungeonName,
      weekKey = GG:GetWeekKey(),
    }
    if GG.Announce and GG.Announce.CheckNewKeystone then
      GG.Announce:CheckNewKeystone(stored, record.mythicplus.keystone, dungeonName)
    end
  elseif stored and stored.weekKey and stored.weekKey ~= GG:GetWeekKey() then
    record.mythicplus.keystone = nil
  end

  GG.Equipment:UpdateItemLevel()
  GG:RequestBroadcast("mythicplus")
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
end
