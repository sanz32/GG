local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

local popup
local HEADER_ROW_HEIGHT = 16
local WIDTH = GG.VaultGrid.CONTENT_WIDTH + 28

local function CreateLabel(parent, size, color, bold)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(bold and GG.Theme.fontBold or GG.Theme.font, size or 12, "")
  fs:SetTextColor(unpack(color or GG.Theme.textPrimary))
  fs:SetWordWrap(false)
  return fs
end

local function BuildPopup()
  popup = CreateFrame("Frame", "GGVaultPreview", UIParent, "BackdropTemplate")
  popup:SetSize(WIDTH, 120)
  popup:SetPoint("CENTER")
  popup:SetFrameStrata("FULLSCREEN_DIALOG")
  popup:SetToplevel(true)
  popup:SetMovable(true)
  popup:EnableMouse(true)
  popup:RegisterForDrag("LeftButton")
  popup:SetScript("OnDragStart", popup.StartMoving)
  popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
  popup:SetClampedToScreen(true)
  GG.Widgets.ApplyPanel(popup, { bg = GG.Theme.background, corners = "all" })
  tinsert(UISpecialFrames, "GGVaultPreview")

  local accentBar = popup:CreateTexture(nil, "ARTWORK")
  accentBar:SetColorTexture(unpack(GG.Theme.accent))
  accentBar:SetPoint("TOPLEFT")
  accentBar:SetPoint("TOPRIGHT")
  accentBar:SetHeight(2)

  popup.title = CreateLabel(popup, 13, nil, true)
  popup.title:SetPoint("TOPLEFT", 14, -12)
  popup.title:SetWidth(WIDTH - 46)
  popup.title:SetJustifyH("LEFT")

  local close = CreateFrame("Button", nil, popup)
  close:SetSize(20, 20)
  close:SetPoint("TOPRIGHT", -8, -8)
  local closeLabel = CreateLabel(close, 16, GG.Theme.textMuted)
  closeLabel:SetPoint("CENTER")
  closeLabel:SetText("x")
  close:SetScript("OnEnter", function() closeLabel:SetTextColor(unpack(GG.Theme.textPrimary)) end)
  close:SetScript("OnLeave", function() closeLabel:SetTextColor(unpack(GG.Theme.textMuted)) end)
  close:SetScript("OnClick", function() popup:Hide() end)

  popup.body = CreateFrame("Frame", nil, popup)
  popup.body:SetPoint("TOPLEFT", 14, -40)
  popup.body:SetPoint("TOPRIGHT", -14, -40)
  popup.body:SetHeight(1)

  popup:Hide()
  return popup
end

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

function GG.UI:ShowVaultPreview(record)
  if not popup then BuildPopup() end
  ClearBody()

  popup.title:SetText(("%s — %s-%s"):format(L["SECTION_VAULT"], record.name, record.realm))

  local isCurrentWeek = GG.Vault:IsCurrentWeek(record)
  local allSlots = (isCurrentWeek and record.vault and record.vault.slots) or {}
  if not isCurrentWeek or not GG.Vault:HasFreshItemData(record) or #allSlots == 0 then
    local text = not isCurrentWeek and L["VAULT_PREVIEW_OLD_WEEK"] or (#allSlots == 0 and L["VAULT_PREVIEW_NONE"] or L["VAULT_PREVIEW_STALE"])
    local height = GG.VaultGrid:DrawEmptyMessage(popup.body, 0, 0, WIDTH - 28, text)
    popup.body:SetHeight(height)
    popup:SetHeight(height + 50)
    popup:Show()
    return
  end

  local y = HEADER_ROW_HEIGHT + 4
  local _, gridHeight = GG.VaultGrid:Draw(popup.body, allSlots, 0, y)

  local totalHeight = y + gridHeight
  popup.body:SetHeight(totalHeight)
  popup:SetHeight(totalHeight + 50)
  popup:Show()
end
