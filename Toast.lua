-- Who Are You People?: the whisper toast, and the anchor that places it (Edit Mode or /wi toast).
local ADDON, ns = ...
local Print = ns.Print

local TOAST_W, TOAST_H = 300, 58
local toast, anchor, hideTimer
local inEditMode = false

local function SavedPoint()
  local p = ns.DB.toastPos
  if p then return p[1], UIParent, p[2], p[3], p[4] end
  return "TOP", UIParent, "TOP", 0, -140
end

local function Place(frame)
  frame:ClearAllPoints()
  frame:SetPoint(SavedPoint())
end

local function StopTimer()
  if hideTimer then hideTimer:Cancel(); hideTimer = nil end
end

-- hide after the chosen number of seconds; 0 keeps it until clicked
local function StartTimer()
  StopTimer()
  local secs = ns.OPT.toastDuration or 8
  if secs > 0 then
    hideTimer = C_Timer.NewTimer(secs, function() hideTimer = nil; toast:Hide() end)
  end
end

local function BuildToast()
  toast = CreateFrame("Button", "WhoAreYouPeopleToast", UIParent, ns.BACKDROP)
  toast:SetSize(TOAST_W, TOAST_H)
  toast:SetFrameStrata("DIALOG")
  toast:SetClampedToScreen(true)
  toast:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  ns.UI.Panel(toast, 0.92)

  toast.more = ns.UI.Text(toast, 11, ns.LOOK.dim)
  toast.more:SetPoint("TOPRIGHT", -12, -11)
  toast.name = ns.UI.Text(toast, 13)
  toast.name:SetPoint("TOPLEFT", 12, -10)
  toast.name:SetPoint("RIGHT", toast.more, "LEFT", -6, 0)
  toast.name:SetJustifyH("LEFT")
  toast.name:SetWordWrap(false)
  toast.msg = ns.UI.Text(toast, 12)
  toast.msg:SetPoint("TOPLEFT", toast.name, "BOTTOMLEFT", 0, -4)
  toast.msg:SetPoint("RIGHT", -12, 0)
  toast.msg:SetHeight(28)
  toast.msg:SetJustifyH("LEFT")
  toast.msg:SetJustifyV("TOP")

  toast:SetScript("OnClick", function(self, button)
    self:Hide()
    if button == "LeftButton" then ns.OpenMessenger(self.full) end
  end)
  -- hovering keeps it up while you read
  toast:SetScript("OnEnter", function(self)
    StopTimer()
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Click: open the Whispers window", 1, 1, 1)
    GameTooltip:AddLine("Right-click: dismiss", 1, 1, 1)
    GameTooltip:Show()
  end)
  toast:SetScript("OnLeave", function()
    GameTooltip:Hide()
    StartTimer()
  end)
  toast:SetScript("OnHide", function(self)
    StopTimer()
    self.count = 0
  end)
  toast:Hide()
end

-- One toast at a time: a new whisper replaces it and counts the ones it covers.
ns.ShowToast = function(full, msg)
  if not toast then BuildToast() end
  toast.count = toast:IsShown() and (toast.count or 0) + 1 or 0
  toast.full = full
  toast.name:SetText(ns.ConvoIcon(full) .. " " .. ns.ConvoName(full))
  toast.more:SetText(toast.count > 0 and ("+" .. toast.count .. " more") or "")
  toast.msg:SetText(msg)
  Place(toast)
  toast:Show()
  if not toast:IsMouseOver() then StartTimer() end
end

---------------------------------------------------------------- anchor
-- A box the size of the toast: drag it to where toasts should appear.
local function BuildAnchor()
  anchor = CreateFrame("Frame", "WhoAreYouPeopleToastAnchor", UIParent)
  anchor:SetSize(TOAST_W, TOAST_H)
  anchor:SetFrameStrata("FULLSCREEN_DIALOG")
  anchor:SetClampedToScreen(true)
  anchor:SetMovable(true)
  anchor:EnableMouse(true)
  anchor:RegisterForDrag("LeftButton")
  local fill = anchor:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints()
  fill:SetColorTexture(0.1, 0.45, 0.9, 0.35)
  local title = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  title:SetPoint("TOP", 0, -12)
  title:SetText("Who Are You People? whisper toast")
  local hint = anchor:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
  anchor.hint = hint

  anchor:SetScript("OnDragStart", anchor.StartMoving)
  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    ns.DB.toastPos = { point, relPoint, x, y }
    if toast then Place(toast) end
  end)
  anchor:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" and not inEditMode then self:Hide() end
  end)
  anchor:Hide()
end

local function ShowAnchor()
  if not anchor then BuildAnchor() end
  anchor.hint:SetText(inEditMode and "Drag to move" or "Drag to move. Right-click or /wi toast when done.")
  Place(anchor)
  anchor:Show()
end

ns.ToggleToastAnchor = function()
  if anchor and anchor:IsShown() then
    anchor:Hide()
  else
    ShowAnchor()
    Print("Drag the blue box to where whisper toasts should appear.")
  end
end

-- In the game's Edit Mode the anchor shows with everything else; clients
-- without Edit Mode use the Move the toast button or /wi toast.
if EventRegistry and EventRegistry.RegisterCallback and EditModeManagerFrame then
  local owner = {}
  EventRegistry:RegisterCallback("EditMode.Enter", function()
    inEditMode = true
    ShowAnchor()
  end, owner)
  EventRegistry:RegisterCallback("EditMode.Exit", function()
    inEditMode = false
    if anchor then anchor:Hide() end
  end, owner)
end
