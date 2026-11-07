local ADDON_NAME, GG = ...

GG.Equipment = {}

GG.Equipment.SLOT_ORDER = {
  INVSLOT_HEAD, INVSLOT_NECK, INVSLOT_SHOULDER, INVSLOT_BACK,
  INVSLOT_CHEST, INVSLOT_WRIST, INVSLOT_HAND, INVSLOT_WAIST,
  INVSLOT_LEGS, INVSLOT_FEET, INVSLOT_FINGER1, INVSLOT_FINGER2,
  INVSLOT_TRINKET1, INVSLOT_TRINKET2, INVSLOT_MAINHAND, INVSLOT_OFFHAND,
}

local MAX_UPDATE_ATTEMPTS = 5
local RETRY_DELAY_SECONDS = 2

function GG.Equipment:Update(attempt, reason)
  attempt = attempt or 1
  local record = GG:GetOrCreateCharacterRecord()
  local equipment = {}
  local anyItem = false
  local changed = 0
  local previous = record.equipment or {}
  for _, slotID in ipairs(GG.Equipment.SLOT_ORDER) do
    local link = GetInventoryItemLink("player", slotID)
    equipment[slotID] = link
    if link then anyItem = true end
    if link ~= previous[slotID] then changed = changed + 1 end
  end

  if not anyItem and attempt < MAX_UPDATE_ATTEMPTS then
    C_Timer.After(RETRY_DELAY_SECONDS, function() GG.Equipment:Update(attempt + 1, reason) end)
    return
  end

  if GG.AccountSync and GG.AccountSync.Trace and (changed > 0 or not reason) then
    GG.AccountSync:Trace("DIAG_SYNC_GEAR", reason or "PLAYER_EQUIPMENT_CHANGED", changed)
  end

  record.equipment = equipment
  GG.Equipment:UpdateItemLevel()

  if reason and changed == 0 then return end
  GG:RequestBroadcast("equipment")
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
end

local REFRESH_DEBOUNCE_SECONDS = 1
local refreshPending = false

function GG.Equipment:ScheduleRefresh(reason)
  if refreshPending then return end
  refreshPending = true
  C_Timer.After(REFRESH_DEBOUNCE_SECONDS, function()
    refreshPending = false
    GG.Equipment:Update(nil, reason)
  end)
end

local ILVL_CONFIRM_DELAY_SECONDS = 2
local ILVL_SUSPICIOUS_DROP_RATIO = 0.5

function GG.Equipment:UpdateItemLevel(confirming)
  local equipped = select(2, GetAverageItemLevel())
  if not equipped or equipped <= 0 then return end

  local record = GG:GetOrCreateCharacterRecord()
  local previous = record.itemLevel

  if not confirming and previous and previous > 0
    and equipped < previous * ILVL_SUSPICIOUS_DROP_RATIO then
    C_Timer.After(ILVL_CONFIRM_DELAY_SECONDS, function()
      GG.Equipment:UpdateItemLevel(true)
    end)
    return
  end

  if previous == equipped then return end
  record.itemLevel = equipped

  GG:RequestBroadcast("mythicplus")
  if GG.RosterUI and GG.RosterUI.Refresh then GG.RosterUI:Refresh() end
end
