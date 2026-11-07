local ADDON_NAME, GG = ...
local L = LibStub("AceLocale-3.0"):GetLocale("GG")

local dataObject = LibStub("LibDataBroker-1.1"):NewDataObject(ADDON_NAME, {
  type = "launcher",
  text = "GG",
  icon = GG.Theme.media.logoMinimap,
  OnClick = function()
    if GG.RosterUI and GG.RosterUI.Toggle then GG.RosterUI:Toggle() end
  end,
  OnEnter = function(frame)
    GG.Tip:Open(frame, { family = "ui" }, function(t)
      t:Title("GG")
      t:Text(L["MINIMAP_TOOLTIP"])
    end)
  end,
  OnLeave = function() GG.Tip:Hide() end,
})

function GG:InitMinimapIcon()
  GGDB.options.minimap = GGDB.options.minimap or { hide = false }
  LibStub("LibDBIcon-1.0"):Register(ADDON_NAME, dataObject, GGDB.options.minimap)
end
