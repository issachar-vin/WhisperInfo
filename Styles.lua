-- Who Are You People?: the four UI style kits (WoW Forever, EllesmereUI, Classic, Blizzard).
local ADDON, ns = ...

---------------------------------------------------------------- UI styles
-- Every window is drawn in one of four looks, matching EllesmereUI's styles.
-- The look is picked once, when the addon loads (changing it reloads the UI),
-- and every window builder asks UI, the active kit, for its pieces.
local STYLES = {
  { key = "forever",  name = "WoW Forever" },
  { key = "eui",      name = "EllesmereUI" },
  { key = "classic",  name = "Classic WoW UI" },
  { key = "blizzard", name = "Blizzard (Retail)" },
}
local KITS = {}
-- ns.UI is the active kit, set by UseStyle at ADDON_LOADED

local BACKDROP = BackdropTemplateMixin and "BackdropTemplate" or nil
local TOOLTIP_BACKDROP = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 14,
  insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local DIALOG_BACKDROP = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

local function Backdrop(frame, def, r, g, b, a)
  if not frame.SetBackdrop then Mixin(frame, BackdropTemplateMixin) end
  frame:SetBackdrop(def)
  frame:SetBackdropColor(r or 0, g or 0, b or 0, a or 1)
end

local function Fill(frame, layer, r, g, b, a, sublevel)
  local t = frame:CreateTexture(nil, layer, nil, sublevel)
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

-- Shared by every look: movable, kept on screen, Esc closes it.
local function Movable(f, name, w, h, strata)
  f:SetSize(w, h)
  f:SetFrameStrata(strata)
  f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  tinsert(UISpecialFrames, name)
end

-- Game-font text for the Blizzard-drawn looks; size picks the closest font object.
local function GameText(parent, size, alpha, template)
  if not template then
    if alpha and alpha < 1 then template = (size or 12) >= 13 and "GameFontDisable" or "GameFontDisableSmall"
    elseif (size or 12) >= 15 then template = "GameFontNormalLarge"
    elseif (size or 12) >= 13 then template = "GameFontNormal"
    elseif (size or 12) >= 12 then template = "GameFontHighlight"
    else template = "GameFontHighlightSmall" end
  end
  return parent:CreateFontString(nil, "OVERLAY", template)
end

-- One dropdown for every look, built from the kit's own button and panel.
local function MakeDropdown(kit, parent, w, items, getCurrent, onPick)
  local dd = kit.Button(parent, "", w, 24)
  local label = dd:GetFontString()
  label:ClearAllPoints()
  label:SetPoint("LEFT", 10, 0)
  label:SetPoint("RIGHT", -24, 0)
  label:SetJustifyH("LEFT")
  local arrow = dd:CreateTexture(nil, "OVERLAY")
  arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
  arrow:SetSize(12, 12)
  arrow:SetPoint("RIGHT", -8, -3)

  local list = CreateFrame("Frame", nil, dd, BACKDROP)
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
  list:SetSize(w, #items * 22 + 10)
  list:EnableMouse(true)
  kit.Panel(list)
  list:Hide()

  local rows = {}
  for i, item in ipairs(items) do
    local row = CreateFrame("Button", nil, list)
    row:SetSize(w - 10, 22)
    row:SetPoint("TOPLEFT", 5, -5 - (i - 1) * 22)
    kit.RowHighlight(row)
    row.mark = kit.SelectedMark(row)
    local text = kit.Text(row, 12)
    text:SetPoint("LEFT", 22, 0)
    text:SetText(item.name)
    row:SetScript("OnClick", function() list:Hide(); onPick(item) end)
    row.item = item
    rows[i] = row
  end

  function dd:Refresh()
    local cur = getCurrent()
    label:SetText(cur.name)
    for _, row in ipairs(rows) do row.mark:SetShown(row.item == cur) end
  end
  dd:SetScript("OnClick", function()
    if list:IsShown() then list:Hide() else dd:Refresh(); list:Show() end
  end)
  dd:HookScript("OnHide", function() list:Hide() end)
  return dd
end

---------------- WoW Forever: the game's own windows, buttons and checkboxes
-- (on the Forever client these templates draw Forever's bronze art)
local forever = { key = "forever", accent = { 0.25, 1, 0.25 } }
KITS.forever = forever

forever.Text = GameText

function forever.Window(name, w, h, titleText, strata)
  local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
  Movable(f, name, w, h, strata)
  local title = f.TitleText or f.title
  if not title then
    title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
  end
  title:SetText(titleText)
  f.title = title
  return f
end

function forever.Button(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w or 84, h or 22)
  b:SetText(text or "")
  return b
end

function forever.Input(parent)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetAutoFocus(false)
  eb:SetTextInsets(4, 4, 0, 0)
  return eb
end

local function TemplateCheck(parent, labelText, onClick)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  local text = cb.Text or cb.text
  if not text then
    text = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 4, 1)
  end
  text:SetText(labelText)
  cb.label = text
  cb:SetScript("OnClick", onClick)
  return cb
end
forever.Check = TemplateCheck

function forever.Panel(frame, alpha)
  Backdrop(frame, TOOLTIP_BACKDROP, 0, 0, 0, alpha or 0.9)
  frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
end

function forever.RowHighlight(row)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
end

function forever.SelectedMark(row)
  local t = row:CreateTexture(nil, "ARTWORK")
  t:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  t:SetSize(16, 16)
  t:SetPoint("LEFT", 2, 0)
  return t
end

function forever.Scroll(panel)
  local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(560, 10)
  scroll:SetScrollChild(content)
  return scroll, content
end

function forever.SectionHeader(hb)
  hb.icon = hb:CreateTexture(nil, "ARTWORK")
  hb.icon:SetSize(14, 14)
  hb.icon:SetPoint("LEFT", 2, 0)
  hb.title = hb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  hb.title:SetPoint("LEFT", hb.icon, "RIGHT", 6, 0)
  hb.count = hb:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  hb.count:SetPoint("LEFT", hb.title, "RIGHT", 8, 0)
  hb:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  function hb:SetOpen(open)
    self.icon:SetTexture(open and "Interface\\Buttons\\UI-MinusButton-Up" or "Interface\\Buttons\\UI-PlusButton-Up")
  end
end

-- the Whispers window's list: a divider, and a gold highlight on the open conversation
function forever.Sidebar(m)
  local divider = m:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(0.6, 0.5, 0.3, 0.5)
  divider:SetSize(1, 352)
  divider:SetPoint("TOPLEFT", 182, -32)
end

function forever.ListRow(b)
  b:SetSize(166, 22)
  b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  local sel = b:CreateTexture(nil, "BACKGROUND")
  sel:SetAllPoints()
  sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
  sel:SetVertexColor(1, 0.82, 0, 0.45)
  b.sel = { sel }
end

function forever.Decorate() end   -- extra lines and stripes: the flat look only

---------------- Blizzard (Retail): retail's window frame where the client has it
-- On the Forever client retail's art names draw Forever art, so this looks like
-- WoW Forever there until the retail art is mapped; buttons and checkboxes are
-- the stock ones.
local blizzard = setmetatable({ key = "blizzard" }, { __index = forever })
KITS.blizzard = blizzard

function blizzard.Window(name, w, h, titleText, strata)
  local ok, f = pcall(CreateFrame, "Frame", name, UIParent, "ButtonFrameTemplate")
  if not ok then return forever.Window(name, w, h, titleText, strata) end
  Movable(f, name, w, h, strata)
  if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
  if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(f) end
  local title = (f.TitleContainer and f.TitleContainer.TitleText) or f.TitleText
  if not title then
    title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -5)
  end
  title:SetText(titleText)
  f.title = title
  return f
end

---------------- Classic WoW UI: the original dialog frames, red buttons and checkboxes
local classic = setmetatable({ key = "classic" }, { __index = forever })
KITS.classic = classic

function classic.Window(name, w, h, titleText, strata)
  local f = CreateFrame("Frame", name, UIParent, BACKDROP)
  Movable(f, name, w, h, strata)
  Backdrop(f, DIALOG_BACKDROP, 1, 1, 1, 1)
  local header = f:CreateTexture(nil, "ARTWORK")
  header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
  header:SetSize(300, 64)
  header:SetPoint("TOP", 0, 12)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOP", header, "TOP", 0, -14)
  f.title:SetText(titleText)
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  return f
end

function classic.Button(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 84, h or 22)
  for state, file in pairs({ Normal = "Up", Pushed = "Down", Disabled = "Disabled" }) do
    local t = b:CreateTexture()
    t:SetTexture("Interface\\Buttons\\UI-Panel-Button-" .. file)
    t:SetTexCoord(0, 0.625, 0, 0.6875)
    t:SetAllPoints()
    b["Set" .. state .. "Texture"](b, t)
  end
  local hl = b:CreateTexture()
  hl:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  hl:SetTexCoord(0, 0.625, 0, 0.6875)
  hl:SetAllPoints()
  b:SetHighlightTexture(hl, "ADD")
  local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  label:SetPoint("CENTER", 0, 1)
  b:SetFontString(label)
  b:SetText(text or "")
  return b
end

function classic.Input(parent)
  local eb = CreateFrame("EditBox", nil, parent, BACKDROP)
  Backdrop(eb, TOOLTIP_BACKDROP, 0, 0, 0, 0.8)
  eb:SetFontObject(ChatFontNormal or GameFontHighlight)
  eb:SetTextInsets(8, 8, 0, 0)
  eb:SetAutoFocus(false)
  return eb
end

function classic.Check(parent, labelText, onClick)
  local cb = CreateFrame("CheckButton", nil, parent)
  cb:SetSize(24, 24)
  cb:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
  cb:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
  cb:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
  cb:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
  cb:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
  cb.label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
  cb.label:SetText(labelText)
  cb:SetScript("OnClick", onClick)
  return cb
end

function classic.Panel(frame, alpha)
  Backdrop(frame, DIALOG_BACKDROP, 1, 1, 1, alpha or 1)
end

---------------- EllesmereUI: flat dark panels and hairline borders
-- Drawn with plain colour textures, so none of EllesmereUI's art is used; its
-- font is used only when EllesmereUI itself is installed.
local LOOK = {
  bg    = { 0.069, 0.058, 0.047 },  -- window background
  shade = 0.3,                      -- black alpha over it for title bars, sidebars and inputs
  line  = 0.08,                     -- white alpha for borders and dividers
  edge  = 0.12,                     -- white alpha for button and input borders
  dim   = 0.53,                     -- white alpha for secondary text
}
local FONT = (EllesmereUI and EllesmereUI.EXPRESSWAY) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local eui = { key = "eui", flat = true, accent = { 12/255, 210/255, 157/255 } }
KITS.eui = eui

-- 1px border just inside the frame's edges; frame:SetOutline(r, g, b, a) recolours it
local function Outline(frame, a)
  local edges = {}
  for i = 1, 4 do edges[i] = Fill(frame, "OVERLAY", 1, 1, 1, a or LOOK.line, 7) end
  edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(1)
  edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(1)
  edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(1)
  edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(1)
  function frame:SetOutline(r, g, b, alpha)
    for _, e in ipairs(edges) do e:SetColorTexture(r, g, b, alpha) end
  end
end

function eui.Text(parent, size, alpha)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 12, "")
  fs:SetTextColor(1, 1, 1, alpha or 1)
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.6)
  return fs
end

-- the dark background plus a faint accent glow fading down from the top
local function FlatBackground(frame)
  local bg = Fill(frame, "BACKGROUND", LOOK.bg[1], LOOK.bg[2], LOOK.bg[3], 0.97, -8)
  bg:SetAllPoints()
  local r, g, b = unpack(eui.accent)
  local glow = Fill(frame, "BACKGROUND", 1, 1, 1, 1, -7)
  glow:SetPoint("TOPLEFT"); glow:SetPoint("TOPRIGHT"); glow:SetHeight(140)
  if CreateColor then
    glow:SetGradient("VERTICAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, 0.10))
  else
    glow:SetColorTexture(r, g, b, 0.04)
  end
end
eui.Background = FlatBackground

-- the border lights up in the accent colour while hovered or focused
local function AccentOutlineOn(frame) local r, g, b = unpack(eui.accent); frame:SetOutline(r, g, b, 0.8) end
local function AccentOutlineOff(frame) frame:SetOutline(1, 1, 1, LOOK.edge) end

function eui.Button(parent, text, w, h)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(w or 84, h or 22)
  Fill(b, "BACKGROUND", 1, 1, 1, 0.06):SetAllPoints()
  Fill(b, "HIGHLIGHT", 1, 1, 1, 0.05):SetAllPoints()
  Outline(b, LOOK.edge)
  local label = eui.Text(b, 12)
  label:SetPoint("CENTER")
  b:SetFontString(label)
  b:SetText(text or "")
  b:HookScript("OnEnter", AccentOutlineOn)
  b:HookScript("OnLeave", AccentOutlineOff)
  b:HookScript("OnDisable", function() label:SetAlpha(0.4) end)
  b:HookScript("OnEnable", function() label:SetAlpha(1) end)
  return b
end

function eui.Input(parent)
  local eb = CreateFrame("EditBox", nil, parent)
  Fill(eb, "BACKGROUND", 0, 0, 0, 0.35):SetAllPoints()
  Outline(eb, LOOK.edge)
  eb:SetFontObject(ChatFontNormal or GameFontHighlight)
  eb:SetTextInsets(8, 8, 0, 0)
  eb:SetAutoFocus(false)
  eb:HookScript("OnEditFocusGained", AccentOutlineOn)
  eb:HookScript("OnEditFocusLost", AccentOutlineOff)
  return eb
end

-- dark title bar with an accent rule under it and a close X
function eui.Window(name, w, h, titleText, strata)
  local f = CreateFrame("Frame", name, UIParent)
  Movable(f, name, w, h, strata)
  FlatBackground(f)
  Outline(f, LOOK.edge)
  local bar = Fill(f, "BORDER", 0, 0, 0, LOOK.shade)
  bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT"); bar:SetHeight(28)
  local rule = Fill(f, "ARTWORK", eui.accent[1], eui.accent[2], eui.accent[3], 0.7)
  rule:SetPoint("TOPLEFT", bar, "BOTTOMLEFT"); rule:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT"); rule:SetHeight(1)

  f.title = eui.Text(f, 13)
  f.title:SetPoint("LEFT", bar, "LEFT", 12, 0)
  f.title:SetText(titleText)

  local close = CreateFrame("Button", nil, f)
  close:SetSize(28, 28)
  close:SetPoint("TOPRIGHT")
  local x = eui.Text(close, 16, LOOK.dim)
  x:SetPoint("CENTER", 0, 1)
  x:SetText("×")
  close:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1, 1) end)
  close:SetScript("OnLeave", function() x:SetTextColor(1, 1, 1, LOOK.dim) end)
  close:SetScript("OnClick", function() f:Hide() end)
  return f
end

-- On/off switch in place of a checkbox; keeps the CheckButton calls
-- (SetChecked, GetChecked, Enable, Disable, .label) the settings code relies on.
function eui.Check(parent, labelText, onClick)
  local t = CreateFrame("Button", nil, parent)
  t:SetSize(470, 22)
  local track = Fill(t, "ARTWORK", 0.267, 0.267, 0.267, 1)
  track:SetSize(28, 14)
  track:SetPoint("LEFT", 2, 0)
  local knob = Fill(t, "OVERLAY", 1, 1, 1, 1)
  knob:SetSize(10, 10)
  t.label = eui.Text(t, 12)
  t.label:SetPoint("LEFT", track, "RIGHT", 10, 0)
  t.label:SetText(labelText)
  Fill(t, "HIGHLIGHT", 1, 1, 1, 0.04):SetAllPoints()

  local function Paint()
    local a = t:IsEnabled() and 1 or 0.35
    knob:ClearAllPoints()
    if t.checked then
      track:SetColorTexture(eui.accent[1], eui.accent[2], eui.accent[3], a)
      knob:SetPoint("RIGHT", track, "RIGHT", -2, 0)
    else
      track:SetColorTexture(0.267, 0.267, 0.267, a)
      knob:SetPoint("LEFT", track, "LEFT", 2, 0)
    end
    knob:SetAlpha(a)
  end
  function t:SetChecked(on) self.checked = on and true or false; Paint() end
  function t:GetChecked() return self.checked end
  t:HookScript("OnEnable", Paint)
  t:HookScript("OnDisable", Paint)
  t:SetScript("OnClick", function(self) self:SetChecked(not self.checked); onClick(self) end)
  Paint()
  return t
end

function eui.Panel(frame, alpha)
  Fill(frame, "BACKGROUND", LOOK.bg[1] * 0.8, LOOK.bg[2] * 0.8, LOOK.bg[3] * 0.8, alpha or 0.98):SetAllPoints()
  Outline(frame, LOOK.edge)
end

function eui.RowHighlight(row) Fill(row, "HIGHLIGHT", 1, 1, 1, 0.06):SetAllPoints() end

function eui.SelectedMark(row)
  local bar = Fill(row, "ARTWORK", eui.accent[1], eui.accent[2], eui.accent[3], 1)
  bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(2)
  return bar
end

-- mouse wheel scrolling with a slim bar on the right
function eui.Scroll(panel)
  local scroll = CreateFrame("ScrollFrame", nil, panel)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(560, 10)
  scroll:SetScrollChild(content)
  local thumb = Fill(panel, "ARTWORK", 1, 1, 1, 0.2)
  thumb:SetWidth(3)
  local function UpdateThumb()
    local range, h = scroll:GetVerticalScrollRange(), scroll:GetHeight()
    if range <= 0 or h <= 0 then thumb:Hide() return end
    local th = math.max(24, h * h / (h + range))
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 12, -(h - th) * scroll:GetVerticalScroll() / range)
    thumb:SetHeight(th)
    thumb:Show()
  end
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange()
    self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * 40)))
  end)
  scroll:SetScript("OnVerticalScroll", UpdateThumb)
  scroll:SetScript("OnScrollRangeChanged", UpdateThumb)
  return scroll, content
end

function eui.SectionHeader(hb)
  Fill(hb, "BACKGROUND", 0, 0, 0, 0.2):SetAllPoints()
  Fill(hb, "HIGHLIGHT", 1, 1, 1, 0.05):SetAllPoints()
  hb.icon = eui.Text(hb, 14, LOOK.dim)
  hb.icon:SetPoint("LEFT", 8, 0)
  hb.icon:SetWidth(12)
  hb.title = eui.Text(hb, 13)
  hb.title:SetTextColor(unpack(eui.accent))
  hb.title:SetPoint("LEFT", hb.icon, "RIGHT", 6, 0)
  hb.count = eui.Text(hb, 11, LOOK.dim)
  hb.count:SetPoint("LEFT", hb.title, "RIGHT", 8, 0)
  function hb:SetOpen(open) self.icon:SetText(open and "-" or "+") end
end

-- the Whispers window's list: a darker sidebar with striped rows
function eui.Sidebar(m)
  local sidebar = Fill(m, "BORDER", 0, 0, 0, LOOK.shade)
  sidebar:SetPoint("TOPLEFT", 1, -29)
  sidebar:SetPoint("BOTTOMLEFT", 1, 1)
  sidebar:SetWidth(181)
  local divider = Fill(m, "ARTWORK", 1, 1, 1, LOOK.line)
  divider:SetPoint("TOPLEFT", sidebar, "TOPRIGHT")
  divider:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT")
  divider:SetWidth(1)
end

function eui.ListRow(b, i)
  b:SetSize(181, 24)
  Fill(b, "BACKGROUND", 0, 0, 0, i % 2 == 1 and 0.1 or 0.2):SetAllPoints()
  Fill(b, "HIGHLIGHT", 1, 1, 1, 0.05):SetAllPoints()
  local tint = Fill(b, "BORDER", eui.accent[1], eui.accent[2], eui.accent[3], 0.14)
  tint:SetAllPoints()
  local bar = Fill(b, "ARTWORK", eui.accent[1], eui.accent[2], eui.accent[3], 1)
  bar:SetPoint("TOPLEFT"); bar:SetPoint("BOTTOMLEFT"); bar:SetWidth(2)
  b.sel = { tint, bar }
end

-- a thin line or a striped row; only the flat look draws these
function eui.Decorate(frame, kind, a, b2, i)
  if kind == "rule" then
    local rule = Fill(frame, "ARTWORK", 1, 1, 1, LOOK.line)
    rule:SetPoint("TOPLEFT", a[1], a[2]); rule:SetPoint("TOPRIGHT", b2[1], b2[2]); rule:SetHeight(1)
  elseif kind == "stripe" then
    local stripe = Fill(frame, "BORDER", 0, 0, 0, i % 2 == 1 and 0.1 or 0.2)
    stripe:SetPoint("TOPLEFT", a[1], a[2]); stripe:SetPoint("TOPRIGHT", b2[1], b2[2]); stripe:SetHeight(20)
  end
end

for _, kit in pairs(KITS) do
  kit.Dropdown = function(...) return MakeDropdown(kit, ...) end
  kit.Background = kit.Background or function() end
end

local function StyleByKey(key)
  for _, s in ipairs(STYLES) do if s.key == key then return s end end
  return STYLES[1]
end
local function UseStyle(key) ns.UI = KITS[StyleByKey(key).key] end
UseStyle("forever")   -- until the saved choice loads

local function AccentHex()
  local r, g, b = unpack(ns.UI.accent)
  return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- shared with the other files
ns.AccentHex = AccentHex
ns.BACKDROP = BACKDROP
ns.LOOK = LOOK
ns.STYLES = STYLES
ns.StyleByKey = StyleByKey
ns.UseStyle = UseStyle
