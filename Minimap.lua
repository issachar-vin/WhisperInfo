-- Who Are You People?: the minimap button.
local ADDON, ns = ...
local OpenSettings = ns.OpenSettings
local Print = ns.Print

---------------------------------------------------------------- minimap button
-- Left-click: Whispers window. Shift- or middle-click: settings.
-- Right-click: card for whoever whispered you last.
-- Drag it around the edge of the minimap.
local mmButton

local function PlaceMinimapButton()
  local angle = math.rad(ns.DB.minimapAngle or 210)
  local radius = (Minimap:GetWidth() / 2) + 10
  mmButton:ClearAllPoints()
  mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function BuildMinimapButton()
  if mmButton or not Minimap then return end
  local b = CreateFrame("Button", "WhoAreYouPeopleMinimapButton", Minimap)
  mmButton = b
  b:SetSize(31, 31)
  b:SetFrameStrata("MEDIUM")
  b:SetFrameLevel(8)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
  b:RegisterForDrag("LeftButton")
  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(18, 18)
  icon:SetTexture("Interface\\AddOns\\WhoAreYouPeople\\icon")
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  icon:SetPoint("CENTER", bg, "CENTER", 0, 0)

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  border:SetPoint("TOPLEFT")

  b:SetScript("OnClick", function(_, button)
    if button == "MiddleButton" or (button == "LeftButton" and IsShiftKeyDown()) then
      if ns.settingsWindow:IsShown() then ns.settingsWindow:Hide() else OpenSettings() end
    elseif button == "RightButton" then
      if ns.lastWhisperer then ns.ShowCard(ns.lastWhisperer) else Print("Nobody has whispered you yet this session.") end
    else
      ns.ToggleMessenger()
    end
  end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      local atan2 = math.atan2 or math.atan
      ns.DB.minimapAngle = math.deg(atan2(py / scale - my, px / scale - mx))
      PlaceMinimapButton()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Who Are You People?")
    GameTooltip:AddLine("Left-click: Whispers window", 1, 1, 1)
    GameTooltip:AddLine("Shift-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: card for your last whisper", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  PlaceMinimapButton()
end

ns.UpdateMinimapButton = function()
  if ns.OPT.minimap then
    BuildMinimapButton()
    if mmButton then mmButton:Show() end
  elseif mmButton then
    mmButton:Hide()
  end
end
