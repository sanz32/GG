local ADDON_NAME, GG = ...

function GG:IsChatRestricted()
  if C_ChatInfo.InChatMessagingLockdown() then return true end
  if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
    if C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Chat) == true then
      return true
    end
  end
  if C_PlayerInteractionManager and C_PlayerInteractionManager.IsInteractingWithNpcOfType
    and C_PlayerInteractionManager.IsInteractingWithNpcOfType(Enum.PlayerInteractionType.WeeklyRewards) then
    return true
  end
  return false
end

local RESTRICTED_CONTENT_TYPES = { "ChallengeMode", "Encounter", "PvPMatch" }

function GG:IsAddonChatTextRestricted()
  if self:IsChatRestricted() then return true end
  if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
    for _, name in ipairs(RESTRICTED_CONTENT_TYPES) do
      local restrictionType = Enum.AddOnRestrictionType[name]
      if restrictionType and C_RestrictedActions.IsAddOnRestrictionActive(restrictionType) == true then
        return true
      end
    end
  end
  return false
end
