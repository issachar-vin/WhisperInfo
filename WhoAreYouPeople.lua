-- Who Are You People?: level, class and guild on whispers, a player card, class and
-- role icons in chat, and a settings panel to turn each feature on or off.
local ADDON = ...
local f = CreateFrame("Frame")
local DB, OPT
local guidToName = {}    -- guid -> "Name-Realm"
local handledLine = {}   -- lineID -> true (filters run once per chat frame)
local waitingWho = {}    -- "Name-Realm" -> GetTime() the lookup was sent
local autoQueue, autoQueued = {}, {}   -- people to /who on your next click
local hideWhoUntil = {}                -- hide the raw /who chat line for these
local lastWho, lastHidden = 0, 0
local ShowCard, RefreshCard            -- defined with the card below
local SpamReason                       -- defined with the spam flag below
local RecordWhisper, ToggleMessenger   -- defined with the whisper window below

local GRAY = "|cff888888"

local DEFAULTS = {
  -- whisper tag
  whisperTag    = true,  -- master switch for the tag
  tagLevel      = true,
  tagLevelColor = true,  -- colour levels by difficulty (everywhere)
  tagClass      = true,
  tagGuild      = true,
  whoLink       = true,  -- [who] in the tag
  armoryLink    = true,  -- [armory] in the tag
  linkIcons     = false, -- show [who] / [armory] as small icons instead of words
  tagBN         = true,  -- also tag Battle.net whispers
  -- lookups
  autoWho       = true,  -- look strangers up on your next world click
  whoCard       = true,  -- [who] opens the player card
  hideWhoLines  = true,  -- hide raw /who lines for lookups the addon makes
  printLookups  = true,  -- print "Name is Lvl 24 ..." when a lookup finishes
  -- class icons
  classIcons    = true,  -- master switch
  iconsWhispers = true,
  iconsSay      = true,  -- say and yell
  iconsGuild    = true,  -- guild and officer
  iconsGroup    = true,  -- party, raid, instance
  iconsChannels = true,  -- General, Trade, LookingForGroup...
  -- role icons
  roleIcons     = true,  -- master switch
  roleIconsParty = true, -- party and instance chat
  roleIconsRaid = true,
  -- spam
  spamFlag      = true,  -- master switch
  spamLevel     = true,  -- strangers at level 1-5
  spamWords     = true,  -- links, prices, "cheap gold"...
  spamHide      = false, -- hide instead of greying out
  -- other
  minimap       = true,
  -- whisper window
  whisperWindow   = true,  -- keep whispers in the WhoAreYouPeople window
  whisperAutoOpen = false, -- open the window when someone whispers you
  whisperHideChat = false, -- take whispers out of the normal chat window
  -- look (needs a UI reload to change)
  uiStyle         = "forever",
}
local PARENT = {
  tagLevel = "whisperTag", tagLevelColor = "tagLevel", tagClass = "whisperTag", tagGuild = "whisperTag",
  whoLink = "whisperTag", armoryLink = "whisperTag", tagBN = "whisperTag", linkIcons = "whisperTag",
  iconsWhispers = "classIcons", iconsSay = "classIcons", iconsGuild = "classIcons",
  iconsGroup = "classIcons", iconsChannels = "classIcons",
  roleIconsParty = "roleIcons", roleIconsRaid = "roleIcons",
  spamLevel = "spamFlag", spamWords = "spamFlag", spamHide = "spamFlag",
  whisperAutoOpen = "whisperWindow", whisperHideChat = "whisperWindow",
}
-- a setting counts only if it and everything above it is on
local function On(key)
  if not OPT[key] then return false end
  local parent = PARENT[key]
  return parent == nil or On(parent)
end
local SPAM_MAX_LEVEL = 5
local lastWhisperer       -- for the minimap button's right-click

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
local UI   -- the active kit, set by UseStyle at ADDON_LOADED

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
local function UseStyle(key) UI = KITS[StyleByKey(key).key] end
UseStyle("forever")   -- until the saved choice loads

local function AccentHex()
  local r, g, b = unpack(UI.accent)
  return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(AccentHex() .. "Who Are You People?|r " .. msg)
end

-- Whispers during some instance encounters arrive as secret values.
local function IsSecret(v) return issecretvalue and issecretvalue(v) end
local function Locked()
  return C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()
end

local function FullName(name)
  if not name or name == "" then return nil end
  name = strtrim(name):gsub("%-+$", ""):gsub("^%-+", "")
  if name == "" then return nil end
  if not name:find("-", 1, true) then
    -- Forever has no realm names: the realm comes back blank, so only add a real one
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if realm and realm ~= "" then name = name .. "-" .. realm end
  end
  return name
end

local function ShortName(full) return (full:match("^([^-]+)") or full) end

-- name to show, whisper or invite: drop the realm if it is ours, never a stray dash
local function Display(full)
  return ((Ambiguate(full, "none") or full):gsub("%-+$", ""))
end

local function TitleCase(name)
  return (name:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b:lower() end))
end

local function Entry(full)
  local e = DB.players[full]
  if not e then e = {}; DB.players[full] = e end
  return e
end

local function LevelText(lvl)
  if not lvl then return "Lvl ?" end
  local t = "Lvl " .. lvl
  local col = OPT.tagLevelColor and GetQuestDifficultyColor and GetQuestDifficultyColor(lvl)
  if col and col.r then
    t = string.format("|cff%02x%02x%02x%s|r", col.r * 255, col.g * 255, col.b * 255, t)
  end
  return t
end

local function ClassColored(e, text)
  local c = e.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.classFile]
  if c and c.colorStr then return "|c" .. c.colorStr .. text .. "|r" end
  return text
end

-- e.guild: string = guild name, false = not in a guild, nil = unknown yet
local function Describe(e)
  local text = LevelText(e.level) .. " " .. ClassColored(e, e.class or "?")
  if e.guild then text = text .. " |cff40ff40<" .. e.guild .. ">|r" end
  return text
end

local function NeedsWho(e) return not e.level or e.guild == nil end

-- small inline icons (cropped like action-bar icons) used when "linkIcons" is on
local WHO_ICON    = "|TInterface\\Icons\\INV_Misc_Spyglass_03:14:14:0:0:64:64:5:59:5:59|t"
local ARMORY_ICON = "|TInterface\\Icons\\INV_Chest_Chain:14:14:0:0:64:64:5:59:5:59|t"

local function WhoLink(full)
  local label = On("linkIcons") and WHO_ICON or "[who]"
  return " |cff00ccff|Haddon:WhoAreYouPeople:who:" .. full .. "|h" .. label .. "|h|r"
end

local function ArmoryLink(full)
  local label = On("linkIcons") and ARMORY_ICON or "[armory]"
  return " |cffffd100|Haddon:WhoAreYouPeople:armory:" .. full .. "|h" .. label .. "|h|r"
end

-- e.g. https://worldofwarcraft.blizzard.com/en-us/forever/us/armory/character/addled-ark
local function ArmoryURL(full)
  local region = (GetCurrentRegionName and GetCurrentRegionName() or "us"):lower()
  local slug = strtrim(ShortName(full)):lower():gsub("'", ""):gsub("%s+", "-")
  return "https://worldofwarcraft.blizzard.com/en-us/forever/" .. region .. "/armory/character/" .. slug
end

-- Copy box for an Armory link: the link is selected, so Ctrl+C copies it.
local armoryBox
local function ShowArmory(full)
  if not armoryBox then
    local w = UI.Window("WhoAreYouPeopleArmory", 460, 118, "Armory link", "DIALOG")
    w:SetPoint("CENTER", 0, 120)
    w.text = UI.Text(w, 12, LOOK.dim)
    w.text:SetPoint("TOPLEFT", 18, -42)
    w.text:SetPoint("RIGHT", -18, 0)
    w.text:SetJustifyH("LEFT")
    local eb = UI.Input(w)
    eb:SetHeight(24)
    eb:SetPoint("TOPLEFT", 18, -70)
    eb:SetPoint("RIGHT", -18, 0)
    eb:SetMaxLetters(0)
    -- typing can't change the link: put it back and select it again
    eb:SetScript("OnTextChanged", function(self, userInput)
      if userInput then self:SetText(w.url); self:HighlightText() end
    end)
    eb:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnEnterPressed", function() w:Hide() end)
    eb:SetScript("OnEscapePressed", function() w:Hide() end)
    w.eb = eb
    armoryBox = w
  end
  armoryBox.url = ArmoryURL(full)
  armoryBox.text:SetText("Armory link for " .. Display(full) .. " - press Ctrl+C, then paste it in your browser.")
  armoryBox.eb:SetText(armoryBox.url)
  armoryBox:Show()
  armoryBox.eb:SetFocus()
  armoryBox.eb:HighlightText()
end

local function TagFor(e, full)
  if not On("whisperTag") then return "" end
  local parts = {}
  if On("tagLevel") then parts[#parts + 1] = LevelText(e.level) end
  if On("tagClass") then parts[#parts + 1] = ClassColored(e, e.class or "?") end
  if On("tagGuild") and e.guild then parts[#parts + 1] = "|cff40ff40<" .. e.guild .. ">|r" end
  local links = (On("whoLink") and WhoLink(full) or "") .. (On("armoryLink") and ArmoryLink(full) or "")
  if #parts == 0 then
    if links == "" then return "" end
    links = links:gsub("^ ", "")
  end
  return GRAY .. "[|r" .. table.concat(parts, " ") .. links .. GRAY .. "]|r "
end

local function Tag(full)
  local e = DB.players[full]
  if not e then return "" end
  return TagFor(e, full)
end

---------------------------------------------------------------- unit lookup
local SCAN = { "player", "target", "mouseover", "focus", "party1", "party2", "party3", "party4" }
for i = 1, 40 do SCAN[#SCAN + 1] = "raid" .. i end
local function UnitFromGUID(guid)
  if not guid then return nil end
  if UnitTokenFromGUID then
    local u = UnitTokenFromGUID(guid)
    if u then return u end
  end
  for _, u in ipairs(SCAN) do
    if UnitExists(u) and UnitGUID(u) == guid then return u end
  end
end

---------------------------------------------------------------- read a visible unit
local function ReadUnit(e, unit)
  local lvl = UnitLevel(unit)
  if lvl and lvl > 0 then e.level = lvl end
  local g, rank = GetGuildInfo(unit)
  e.guild = (g and g ~= "") and g or false
  e.guildRank = e.guild and rank or nil
  e.faction = UnitFactionGroup(unit) or e.faction
end

local function UpdateFromUnit(unit)
  local guid = UnitGUID(unit)
  if not guid or IsSecret(guid) then return end
  local full = guidToName[guid]
  if full and DB.players[full] then
    ReadUnit(DB.players[full], unit)
    if RefreshCard then RefreshCard(full) end
  end
end

---------------------------------------------------------------- gather info
local RACE_FACTION = {
  Human = "Alliance", Dwarf = "Alliance", NightElf = "Alliance", Gnome = "Alliance",
  Orc = "Horde", Scourge = "Horde", Tauren = "Horde", Troll = "Horde",
}

local function Gather(full, guid)
  local e = Entry(full)
  if guid and not IsSecret(guid) then
    e.guid = guid
    guidToName[guid] = full
    local className, classFile, race, raceFile, sex = GetPlayerInfoByGUID(guid)
    if className then e.class, e.classFile = className, classFile end
    if race then e.race, e.raceFile, e.sex = race, raceFile, sex end
    e.faction = e.faction or (raceFile and RACE_FACTION[raceFile])
    local unit = UnitFromGUID(guid)
    if unit then ReadUnit(e, unit) end
  end
  local charName = ShortName(full):lower()
  local function same(n)
    return type(n) == "string" and ShortName(n):lower() == charName
  end
  e.isFriend, e.isBNFriend, e.isGuildmate, e.friendNote = nil, nil, nil, nil
  -- character friends list
  if C_FriendList and C_FriendList.GetNumFriends then
    for i = 1, C_FriendList.GetNumFriends() or 0 do
      local fi = C_FriendList.GetFriendInfoByIndex(i)
      if fi and same(fi.name) then
        e.isFriend = true
        e.friendNote = (fi.notes and fi.notes ~= "") and fi.notes or nil
        if fi.connected and fi.level and fi.level > 0 then e.level = fi.level end
        if fi.connected and fi.area then e.zone = fi.area end
        e.class = e.class or fi.className
        break
      end
    end
  end
  -- Battle.net friends who are on that character right now
  if C_BattleNet and C_BattleNet.GetFriendNumGameAccounts and BNGetNumFriends then
    for i = 1, (BNGetNumFriends()) or 0 do
      for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
        local g = C_BattleNet.GetFriendGameAccountInfo(i, j)
        if g and same(g.characterName) then
          e.isBNFriend = true
          if g.characterLevel and g.characterLevel > 0 then e.level = g.characterLevel end
          if g.areaName and g.areaName ~= "" then e.zone = g.areaName end
          e.class = e.class or g.className
          e.faction = g.factionName or e.faction
        end
      end
    end
  end
  -- guild roster
  if IsInGuild() then
    for i = 1, GetNumGuildMembers() do
      local n, rank, _, lvl, cls, zone, note, _, _, _, classFile = GetGuildRosterInfo(i)
      if same(n) then
        e.isGuildmate = true
        if lvl and lvl > 0 then e.level = lvl end
        e.class, e.classFile = e.class or cls, e.classFile or classFile
        e.guild = GetGuildInfo("player") or e.guild
        e.guildRank = rank or e.guildRank
        e.zone = zone or e.zone
        e.guildNote = (note and note ~= "") and note or nil
        break
      end
    end
  end
  return e
end

---------------------------------------------------------------- party roles
local DPS_ONLY = { MAGE = true, ROGUE = true, WARLOCK = true, HUNTER = true }
local ROLE_ALIAS = {
  tank = "TANK", t = "TANK",
  heal = "HEALER", healer = "HEALER", h = "HEALER",
  dps = "DAMAGER", damage = "DAMAGER", d = "DAMAGER",
}
local ROLE_ATLAS = { TANK = "roleicon-tiny-tank", HEALER = "roleicon-tiny-healer", DAMAGER = "roleicon-tiny-dps" }
local ROLE_TEXT = { TANK = "|cff4da6ff[T]|r", HEALER = "|cff40ff40[H]|r", DAMAGER = "|cffff4040[D]|r" }
local ROLE_NAME = { TANK = "Tank", HEALER = "Healer", DAMAGER = "DPS" }

local function RoleIcon(role)
  if not role then return nil end
  local inline = (role == "TANK" and INLINE_TANK_ICON) or (role == "HEALER" and INLINE_HEALER_ICON)
              or (role == "DAMAGER" and INLINE_DAMAGER_ICON)
  if type(inline) == "string" and inline ~= "" then return inline end
  local atlas = ROLE_ATLAS[role]
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
    return "|A:" .. atlas .. ":14:14|a"
  end
  return ROLE_TEXT[role]
end

local function ResolveRole(unit, full, guid)
  if unit and UnitGroupRolesAssigned then
    local r = UnitGroupRolesAssigned(unit)
    if r and r ~= "NONE" then return r end
  end
  if full and DB.roles[full] then return DB.roles[full] end
  local classFile
  if unit then classFile = select(2, UnitClass(unit))
  elseif guid then classFile = select(2, GetPlayerInfoByGUID(guid)) end
  if classFile and DPS_ONLY[classFile] then return "DAMAGER" end
end

local function OnGroupChat(_, event, msg, sender, ...)
  local key = event:find("RAID") and "roleIconsRaid" or "roleIconsParty"
  if not On(key) or Locked() or IsSecret(msg) or IsSecret(sender) then return false end
  local guid = select(10, ...)
  if guid and IsSecret(guid) then guid = nil end
  local full = FullName(sender)
  local unit = guid and UnitFromGUID(guid)
  local icon = RoleIcon(ResolveRole(unit, full, guid))
  if not icon then return false end
  return false, icon .. " " .. msg, sender, ...
end

---------------------------------------------------------------- /who
local function SendWhoFor(full, hide)
  lastWho = GetTime()
  waitingWho[full] = GetTime()
  if hide then hideWhoUntil[full] = GetTime() + 10 end
  C_FriendList.SendWho('n-"' .. ShortName(full) .. '"')
  -- no answer after a few seconds = offline, other faction, or a typo
  if C_Timer then
    C_Timer.After(4, function()
      if waitingWho[full] then
        waitingWho[full] = nil
        local e = DB.players[full]
        if e then e.whoMissed = true end
        if RefreshCard then RefreshCard(full) end
      end
    end)
  end
end

-- Blizzard only allows /who from a click, so automatic lookups wait for your
-- next click in the game world (moving, turning the camera, selecting something).
local function QueueWho(full)
  if autoQueued[full] then return end   -- once per person per session
  autoQueued[full] = true
  autoQueue[#autoQueue + 1] = full
end

local function RunQueuedWho()
  if not OPT.autoWho or #autoQueue == 0 or GetTime() - lastWho < 5 then return end
  SendWhoFor(table.remove(autoQueue, 1), OPT.hideWhoLines)
end

---------------------------------------------------------------- class icons
local function ClassIcon(classFile, size)
  if not classFile then return nil end
  size = size or 14
  local atlas = "classicon-" .. classFile:lower()
  if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
    return "|A:" .. atlas .. ":" .. size .. ":" .. size .. "|a"
  end
  local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
  if c then
    return string.format("|TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:%d:%d:0:0:256:256:%d:%d:%d:%d|t",
      size, size, c[1] * 256, c[2] * 256, c[3] * 256, c[4] * 256)
  end
end

local ICON_SETTING = {
  CHAT_MSG_WHISPER = "iconsWhispers",
  CHAT_MSG_SAY = "iconsSay", CHAT_MSG_YELL = "iconsSay",
  CHAT_MSG_GUILD = "iconsGuild", CHAT_MSG_OFFICER = "iconsGuild",
  CHAT_MSG_PARTY = "iconsGroup", CHAT_MSG_PARTY_LEADER = "iconsGroup",
  CHAT_MSG_RAID = "iconsGroup", CHAT_MSG_RAID_LEADER = "iconsGroup", CHAT_MSG_RAID_WARNING = "iconsGroup",
  CHAT_MSG_INSTANCE_CHAT = "iconsGroup", CHAT_MSG_INSTANCE_CHAT_LEADER = "iconsGroup",
  CHAT_MSG_CHANNEL = "iconsChannels",
}

local function OnAnyChat(_, event, msg, sender, ...)
  local key = ICON_SETTING[event]
  if not key or not On(key) or Locked() or IsSecret(msg) then return false end
  local guid = select(10, ...)
  if not guid or guid == "" or IsSecret(guid) then return false end
  local _, classFile = GetPlayerInfoByGUID(guid)
  local icon = ClassIcon(classFile)
  if not icon then return false end
  return false, icon .. " " .. msg, sender, ...
end

---------------------------------------------------------------- whisper filters
local function NoteWhisper(e)
  e.seen = time()
  e.firstSeen = e.firstSeen or e.seen
  e.whispers = (e.whispers or 0) + 1
end

---------------------------------------------------------------- spam flag
-- Gold sellers and spam bots are almost always strangers on a level 1-5
-- character, or paste a website / price into the whisper.
local SPAM_WORDS = { "www%.", "%.com", "%.net", "%.org", "%.gg", "https?:", "%$%s*%d", "%d%s*usd",
                     "%d+%s*gold%s*for", "cheap gold", "buy gold", "sell gold", "powerlevel",
                     "discount", "coupon", "promo code", "delivery", "/w me for" }

local function InMyGroup(full)
  local name = ShortName(full)
  return (UnitInParty and UnitInParty(name)) or (UnitInRaid and UnitInRaid(name)) or false
end

local function IsStranger(e, full)
  return not (e.isFriend or e.isBNFriend or e.isGuildmate or InMyGroup(full))
end

-- returns the reason it looks like spam, or nil
SpamReason = function(e, full, msg)
  if e.notSpam or not IsStranger(e, full) then return nil end
  if On("spamLevel") and e.level and e.level <= SPAM_MAX_LEVEL then return "Lvl " .. e.level end
  if not On("spamWords") then return nil end
  local low = (msg or ""):lower()
  for _, w in ipairs(SPAM_WORDS) do
    if low:find(w) then return "link or sales words" end
  end
end

local function SpamLink(full)
  return " |cff9d9d9d|Haddon:WhoAreYouPeople:notspam:" .. full .. "|h[not spam]|h|r"
end

local function OnWhisper(_, event, msg, sender, ...)
  if Locked() or IsSecret(msg) or IsSecret(sender) then return false end
  local lineID, guid = select(9, ...), select(10, ...)
  local full = FullName(sender)
  if not full then return false end
  local e
  if lineID and not handledLine[lineID] then
    handledLine[lineID] = true
    e = Gather(full, guid)
    NoteWhisper(e)
    lastWhisperer = full
    if OPT.autoWho and NeedsWho(e) then QueueWho(full) end
    local spam = OPT.spamFlag and SpamReason(e, full, msg)
    if not spam and RecordWhisper then RecordWhisper(full, "them", msg) end
  end
  e = e or DB.players[full]
  if On("whisperHideChat") and not (OPT.spamFlag and SpamReason(e, full, msg)) then return true end
  if OPT.spamFlag and e then
    local why = SpamReason(e, full, msg)
    e.spam = why and true or nil
    if why then
      if On("spamHide") then return true end
      local plain = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      return false, "|cff777777[likely spam: " .. why .. "]|r" .. SpamLink(full) ..
                    " |cff777777" .. plain .. "|r", sender, ...
    end
  end
  local tag = Tag(full)
  if tag == "" then return false end
  return false, tag .. msg, sender, ...
end

local function OnBNWhisper(_, event, msg, sender, ...)
  if Locked() or IsSecret(msg) then return false end
  local lineID, bnID = select(9, ...), select(11, ...)
  if not bnID or IsSecret(bnID) or not C_BattleNet then return false end
  local acct = C_BattleNet.GetAccountInfoByID(bnID)
  local g = acct and acct.gameAccountInfo
  if not g or g.clientProgram ~= BNET_CLIENT_WOW or not g.characterName or g.characterName == "" then
    return false
  end
  local realm = g.realmName and g.realmName:gsub("%s", "") or ""
  local full = FullName(realm ~= "" and (g.characterName .. "-" .. realm) or g.characterName)
  if lineID and not handledLine[lineID] then
    handledLine[lineID] = true
    local e = Gather(full, g.playerGuid)
    if g.characterLevel and g.characterLevel > 0 then e.level = g.characterLevel end
    e.class = e.class or g.className
    NoteWhisper(e)
    if OPT.autoWho and NeedsWho(e) then QueueWho(full) end
  end
  if not On("tagBN") then return false end
  local tag = Tag(full)
  if tag == "" then return false end
  return false, tag .. msg, sender, ...
end

local function OnWhoAreYouPeoplerm(_, event, msg, target, ...)
  if On("whisperHideChat") and not IsSecret(msg) then return true end
  return false
end

---------------------------------------------------------------- links
local function OnLink(link)
  if type(link) ~= "string" then return end
  local cmd, full = link:match("^addon:WhoAreYouPeople:(%a+):(.+)$")
  if not full then return end
  if cmd == "armory" then
    ShowArmory(full)
  elseif cmd == "notspam" then
    local e = Entry(full)
    e.notSpam, e.spam = true, nil
    Print(Display(full) .. " won't be flagged as spam again.")
    if RefreshCard then RefreshCard(full) end
  elseif cmd == "who" then
    autoQueued[full] = true
    if OPT.whoCard then ShowCard(full) end
    if GetTime() - lastWho >= 5 then
      SendWhoFor(full, OPT.whoCard and OPT.hideWhoLines)
    elseif not OPT.whoCard then
      Print("/who needs a few seconds between lookups - click again shortly.")
    end
    if RefreshCard then RefreshCard(full) end
  end
end

---------------------------------------------------------------- /who results
-- Small /who results are printed to chat ("[Name]: Level 24 Human Paladin <Guild> - Zone")
-- instead of filling the Who window, so read both.
local function FormatToPattern(fmt)
  if type(fmt) ~= "string" then return nil end
  local pat = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
  pat = pat:gsub("%%s", "(.-)"):gsub("%%d", "(%%d+)")
  return "^" .. pat .. "$"
end
local WHO_GUILD = FormatToPattern(WHO_LIST_GUILD_FORMAT)
local WHO_PLAIN = FormatToPattern(WHO_LIST_FORMAT)

local function HideWhoLine(_, _, msg)
  if not OPT.hideWhoLines or type(msg) ~= "string" or IsSecret(msg) then return false end
  local name
  if WHO_GUILD then name = msg:match(WHO_GUILD) end
  if not name and WHO_PLAIN then name = msg:match(WHO_PLAIN) end
  if name then
    local full = FullName(name)
    if full and hideWhoUntil[full] and GetTime() < hideWhoUntil[full] then
      lastHidden = GetTime()
      return true
    end
  elseif GetTime() - lastHidden < 2 and msg:match("^%d+ [Pp]layers? [Tt]otal") then
    return true
  end
  return false
end

local function WhoFound(full, lvl, guild, zone)
  local e = DB.players[full]
  if not e then return end
  e.level = tonumber(lvl) or e.level
  e.guild = (guild and guild ~= "") and guild or false
  if zone and zone ~= "" then e.zone = zone end
  e.lastOnline = time()
  e.whoMissed = nil
  if waitingWho[full] then
    waitingWho[full] = nil
    local card = _G.WhoAreYouPeopleCard
    local spam = OPT.spamFlag and SpamReason and SpamReason(e, full, "")
    if spam then e.spam = true end
    if OPT.printLookups and not (card and card:IsShown() and card.full == full) then
      Print(Display(full) .. " is " .. Describe(e) ..
            (e.zone and (GRAY .. " in " .. e.zone .. "|r") or "") ..
            (spam and " |cffff6060- likely spam|r" or ""))
    end
  end
  if RefreshCard then RefreshCard(full) end
end

local function OnSystem(msg)
  if type(msg) ~= "string" or IsSecret(msg) then return end
  local name, lvl, guild, zone, _
  if WHO_GUILD then name, _, lvl, _, _, guild, zone = msg:match(WHO_GUILD) end
  if not name and WHO_PLAIN then name, _, lvl, _, _, zone = msg:match(WHO_PLAIN); guild = false end
  if not name then return end
  WhoFound(FullName(name), lvl, guild, zone)
end

---------------------------------------------------------------- player card
local card
local CARD_ROWS = { "Guild", "Guild rank", "Zone", "Status", "Faction", "Known as", "Note", "Party role", "Whispers", "First whisper" }

local function Ago(t)
  if not t then return nil end
  local d = time() - t
  if d < 120 then return "just now" end
  if d < 7200 then return math.floor(d / 60) .. " min ago" end
  if d < 172800 then return math.floor(d / 3600) .. " h ago" end
  return math.floor(d / 86400) .. " days ago"
end

local function SendTell(name)
  if ChatFrame_SendTell then ChatFrame_SendTell(name)
  elseif ChatFrameUtil and ChatFrameUtil.SendTell then ChatFrameUtil.SendTell(name) end
end

local function Invite(name)
  if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(name)
  elseif InviteUnit then InviteUnit(name) end
end

local function CardButton(parent, text, w)
  return UI.Button(parent, text, w or 92, 22)
end

local function BuildCard()
  card = UI.Window("WhoAreYouPeopleCard", 320, 392, "Who Are You People?", "DIALOG")
  card:SetPoint("CENTER", UIParent, "CENTER", 260, 40)

  card.icon = card:CreateTexture(nil, "ARTWORK")
  card.icon:SetSize(44, 44)
  card.icon:SetPoint("TOPLEFT", 16, -42)

  card.name = UI.Text(card, 16)
  card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -2)
  card.name:SetPoint("RIGHT", -14, 0)
  card.name:SetJustifyH("LEFT")

  card.sub = UI.Text(card, 12)
  card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
  card.sub:SetPoint("RIGHT", -14, 0)
  card.sub:SetJustifyH("LEFT")

  UI.Decorate(card, "rule", { 14, -96 }, { -14, -96 })

  card.rows = {}
  local y = -104
  for i, label in ipairs(CARD_ROWS) do
    UI.Decorate(card, "stripe", { 12, y + 3 }, { -12, y + 3 }, i)
    local l = UI.flat and UI.Text(card, 11, LOOK.dim) or UI.Text(card, 11, nil, "GameFontNormalSmall")
    l:SetPoint("TOPLEFT", 18, y)
    l:SetWidth(84); l:SetJustifyH("LEFT")
    l:SetText(label)
    local v = UI.Text(card, 11)
    v:SetPoint("TOPLEFT", 104, y)
    v:SetPoint("RIGHT", -16, 0)
    v:SetJustifyH("LEFT"); v:SetWordWrap(false)
    card.rows[label] = v
    y = y - 20
  end

  card.status = UI.Text(card, 11, LOOK.dim)
  card.status:SetPoint("BOTTOMLEFT", 18, 66)
  card.status:SetPoint("RIGHT", -16, 0)
  card.status:SetJustifyH("LEFT")

  local whisper = CardButton(card, WHISPER or "Whisper")
  whisper:SetPoint("BOTTOMLEFT", 14, 40)
  whisper:SetScript("OnClick", function() SendTell(Display(card.full)) end)

  local invite = CardButton(card, INVITE or "Invite")
  invite:SetPoint("LEFT", whisper, "RIGHT", 6, 0)
  invite:SetScript("OnClick", function() Invite(Display(card.full)) end)

  local armory = CardButton(card, "Armory")
  armory:SetPoint("LEFT", invite, "RIGHT", 6, 0)
  armory:SetScript("OnClick", function() ShowArmory(card.full) end)

  local refresh = CardButton(card, "Look up again", 143)
  refresh:SetPoint("BOTTOMLEFT", 14, 12)
  refresh:SetScript("OnClick", function()
    if GetTime() - lastWho < 5 then
      card.status:SetText("/who needs a few seconds between lookups.")
    else
      SendWhoFor(card.full, OPT.hideWhoLines)
      RefreshCard(card.full)
    end
  end)

  local roleBtn = CardButton(card, "Set role", 143)
  roleBtn:SetPoint("LEFT", refresh, "RIGHT", 6, 0)
  roleBtn:SetScript("OnClick", function()
    local cur = DB.roles[card.full]
    local nextRole = "TANK"
    if cur == "TANK" then nextRole = "HEALER" elseif cur == "HEALER" then nextRole = "DAMAGER"
    elseif cur == "DAMAGER" then nextRole = nil end
    DB.roles[card.full] = nextRole
    RefreshCard(card.full)
  end)
  card:Hide()
end

RefreshCard = function(full)
  if not card or not card:IsShown() or card.full ~= full then return end
  local e = DB.players[full] or {}
  local display = Display(full)
  card.name:SetText(ClassColored(e, display))

  local c = e.classFile and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.classFile]
  local atlas = e.classFile and ("classicon-" .. e.classFile:lower())
  if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
    card.icon:SetAtlas(atlas); card.icon:Show()
  elseif c then
    card.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    card.icon:SetTexCoord(c[1], c[2], c[3], c[4]); card.icon:Show()
  else
    card.icon:Hide()
  end

  local lvl = e.level and ("Level " .. e.level) or "Level ?"
  card.sub:SetText(lvl .. " " .. (e.race and (e.race .. " ") or "") .. ClassColored(e, e.class or "?"))

  local R = card.rows
  local unknown = GRAY .. "unknown|r"
  R["Guild"]:SetText(e.guild and ("|cff40ff40<" .. e.guild .. ">|r") or (e.guild == false and "None" or unknown))
  R["Guild rank"]:SetText(e.guildRank or (e.guild == false and "-" or (GRAY .. "only shown for guildmates or nearby|r")))
  R["Zone"]:SetText(e.zone or unknown)
  local status
  if waitingWho[full] then status = "|cffffd100Looking up...|r"
  elseif e.lastOnline and time() - e.lastOnline < 300 then status = "|cff40ff40Online|r"
  elseif e.whoMissed then status = "|cffff6060Not found|r " .. GRAY .. "(offline or other faction)|r"
  elseif e.lastOnline then status = "Last seen online " .. Ago(e.lastOnline)
  else status = unknown end
  R["Status"]:SetText(status)
  R["Faction"]:SetText(e.faction or unknown)
  local known = {}
  if e.spam and not e.notSpam then known[#known + 1] = "|cffff6060Likely spam|r" end
  if e.isGuildmate then known[#known + 1] = "Guildmate" end
  if e.isFriend then known[#known + 1] = "Friend" end
  if e.isBNFriend then known[#known + 1] = "Battle.net friend" end
  if C_FriendList and C_FriendList.IsIgnored and C_FriendList.IsIgnored(ShortName(full)) then
    known[#known + 1] = "|cffff6060Ignored|r"
  end
  R["Known as"]:SetText(#known > 0 and table.concat(known, ", ") or "Stranger")
  R["Note"]:SetText(e.friendNote or e.guildNote or GRAY .. "-|r")
  local role = DB.roles[full]
  R["Party role"]:SetText(role and ((RoleIcon(role) or "") .. " " .. ROLE_NAME[role]) or GRAY .. "not set|r")
  R["Whispers"]:SetText(tostring(e.whispers or 0) .. (e.seen and (GRAY .. "  (last " .. Ago(e.seen) .. ")|r") or ""))
  R["First whisper"]:SetText(e.firstSeen and date("%b %d, %Y", e.firstSeen) or GRAY .. "-|r")

  card.status:SetText(waitingWho[full] and "Asking the server with /who..." or "")
end

ShowCard = function(full)
  if not card then BuildCard() end
  Gather(full, DB.players[full] and DB.players[full].guid)
  card.full = full
  card:Show()
  RefreshCard(full)
end

---------------------------------------------------------------- settings preview
-- Sample chat lines drawn with the same code as real chat, so they show
-- exactly what each setting changes.
local WHISPER_COL, PARTY_COL, TRADE_COL = "|cffff80ff", "|cffaaaaff", "|cffffc0c0"

local function ClassName(classFile, fallback)
  return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]) or fallback
end

local function IconIf(key, classFile)
  return On(key) and ((ClassIcon(classFile) or "") .. " ") or ""
end

local function PreviewLines()
  local sample = { level = 24, class = ClassName("PALADIN", "Paladin"), classFile = "PALADIN", guild = "Night Watch" }
  local bot = { level = 1, class = ClassName("ROGUE", "Rogue"), classFile = "ROGUE", guild = false }
  local lines = {}

  -- 1) a normal whisper
  lines[#lines + 1] = WHISPER_COL .. "[Addled Ark] whispers:|r " .. IconIf("iconsWhispers", "PALADIN") ..
                      TagFor(sample, "Addled Ark") .. WHISPER_COL .. "lf healer for Deadmines?|r"

  -- 2) the lookup result
  if OPT.printLookups then
    lines[#lines + 1] = AccentHex() .. "Who Are You People?|r Addled Ark is " .. Describe(sample) .. GRAY .. " in Westfall|r" ..
      GRAY .. (OPT.autoWho and "   (after your next click)|r" or "   (after you click [who])|r")
  else
    lines[#lines + 1] = GRAY .. "(lookup results fill in the tag and card, no chat line)|r"
  end

  -- 3) a spam whisper
  local spamMsg = "cheap gold, www.example.com"
  local why = OPT.spamFlag and ((On("spamLevel") and "Lvl 1") or (On("spamWords") and "link or sales words"))
  if why and On("spamHide") then
    lines[#lines + 1] = GRAY .. "(a spam whisper would be hidden here)|r"
  elseif why then
    lines[#lines + 1] = WHISPER_COL .. "[Bot Guy] whispers:|r " .. IconIf("iconsWhispers", "ROGUE") ..
      "|cff777777[likely spam: " .. why .. "]|r" .. SpamLink("Bot Guy") .. " |cff777777" .. spamMsg .. "|r"
  else
    lines[#lines + 1] = WHISPER_COL .. "[Bot Guy] whispers:|r " .. IconIf("iconsWhispers", "ROGUE") ..
      TagFor(bot, "Bot Guy") .. WHISPER_COL .. spamMsg .. "|r"
  end

  -- 4) party chat
  local role = On("roleIconsParty") and ((RoleIcon("TANK") or "") .. " ") or ""
  lines[#lines + 1] = PARTY_COL .. "[Party] [Thrall]:|r " .. role .. IconIf("iconsGroup", "WARRIOR") ..
                      PARTY_COL .. "pulling the next pack|r"

  -- 5) trade / LFG channel
  lines[#lines + 1] = TRADE_COL .. "[2. Trade] [Bigdeeps Obgyn]:|r " .. IconIf("iconsChannels", "SHAMAN") ..
                      TRADE_COL .. "LFM Deadmines, need heals|r"

  -- 6) minimap button
  lines[#lines + 1] = GRAY .. "Minimap button: |r" .. (OPT.minimap and "|cff40ff40shown|r" or "|cffff6060hidden|r") ..
    GRAY .. "   Whisper window: |r" .. (On("whisperWindow") and "|cff40ff40on|r" or "|cffff6060off|r") ..
    (On("whisperHideChat") and (GRAY .. " (whispers only appear there)|r") or "")
  return lines
end

---------------------------------------------------------------- settings panel
-- Every feature has its own switch. Indented switches belong to the one above
-- them and are greyed out while that one is off.
local SECTIONS = {
  { title = "Whisper tag", items = {
    { key = "whisperTag",    label = "Show a tag in front of whispers" },
    { key = "tagLevel",      label = "Level" },
    { key = "tagLevelColor", label = "Colour the level by difficulty (green, yellow, red)", indent = 2 },
    { key = "tagClass",      label = "Class" },
    { key = "tagGuild",      label = "Guild" },
    { key = "whoLink",       label = "[who] link" },
    { key = "armoryLink",    label = "[armory] link" },
    { key = "linkIcons",     label = "Show [who] and [armory] as icons instead of words" },
    { key = "tagBN",         label = "Tag Battle.net whispers too" },
  }},
  { title = "Lookups", items = {
    { key = "autoWho",       label = "Look strangers up automatically on your next click in the world" },
    { key = "whoCard",       label = "Clicking [who] opens the player card" },
    { key = "printLookups",  label = "Print a chat line when a lookup finishes" },
    { key = "hideWhoLines",  label = "Hide the raw /who lines for lookups the addon makes" },
  }},
  { title = "Class icons", items = {
    { key = "classIcons",    label = "Show class icons in chat" },
    { key = "iconsWhispers", label = "Whispers" },
    { key = "iconsSay",      label = "Say and yell" },
    { key = "iconsGuild",    label = "Guild and officer" },
    { key = "iconsGroup",    label = "Party, raid and instance" },
    { key = "iconsChannels", label = "General, Trade and other channels" },
  }},
  { title = "Role icons", items = {
    { key = "roleIcons",      label = "Show tank / healer / DPS icons" },
    { key = "roleIconsParty", label = "Party chat" },
    { key = "roleIconsRaid",  label = "Raid chat" },
  }},
  { title = "Spam", items = {
    { key = "spamFlag",      label = "Flag likely spam whispers from strangers" },
    { key = "spamLevel",     label = "Strangers at level 1-5" },
    { key = "spamWords",     label = "Links, prices and gold-selling words" },
    { key = "spamHide",      label = "Hide them completely instead of greying them out" },
  }},
  { title = "Whisper window", items = {
    { key = "whisperWindow",   label = "Keep whispers in the Whispers window" },
    { key = "whisperAutoOpen", label = "Open the window when someone whispers you" },
    { key = "whisperHideChat", label = "Take whispers out of the normal chat window" },
  }},
  { title = "Other", items = {
    { key = "minimap",       label = "Show the minimap button" },
  }},
}
local settingsCategory, settingsPanel
local UpdateMinimapButton

StaticPopupDialogs["WHOAREYOUPEOPLE_RELOAD"] = {
  text = "Who Are You People? switches to the %s style after a UI reload. Reload now?",
  button1 = RELOADUI or "Reload",
  button2 = LATER or "Later",
  OnAccept = function() ReloadUI() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

local function BuildSettings()
  local panel = CreateFrame("Frame")
  panel.name = "Who Are You People?"
  settingsPanel = panel

  UI.Background(panel)

  local title = UI.Text(panel, 18)
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Who Are You People?")
  if UI.flat then title:SetTextColor(unpack(UI.accent)) end
  local sub = UI.Text(panel, 11, LOOK.dim)
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetText("Every feature has its own switch. Changes apply straight away.")

  -- UI style: takes effect after a reload, like EllesmereUI's style picker
  local styleDD = UI.Dropdown(panel, 190, STYLES, function() return StyleByKey(OPT.uiStyle) end, function(style)
    if style.key == OPT.uiStyle then return end
    OPT.uiStyle = style.key
    panel.UpdatePreview()
    StaticPopup_Show("WHOAREYOUPEOPLE_RELOAD", style.name)
  end)
  styleDD:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -24, -16)
  local styleLabel = UI.Text(panel, 12, LOOK.dim)
  styleLabel:SetPoint("RIGHT", styleDD, "LEFT", -8, 0)
  styleLabel:SetText("UI style")
  local styleNote = UI.Text(panel, 11, LOOK.dim)
  styleNote:SetPoint("TOPRIGHT", styleDD, "BOTTOMRIGHT", 0, -4)

  -- preview, fixed at the top so it stays in view while you scroll the switches
  local head = UI.Text(panel, 13)
  head:SetPoint("TOPLEFT", 18, -58)
  head:SetText("Preview")
  local headSub = UI.Text(panel, 11, LOOK.dim)
  headSub:SetPoint("LEFT", head, "RIGHT", 8, 0)
  headSub:SetText("updates as you click")

  local box = CreateFrame("Frame", nil, panel, BACKDROP)
  box:SetPoint("TOPLEFT", 14, -76)
  box:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
  box:SetHeight(6 * 20 + 16)
  UI.Panel(box, 0.75)
  box.lines = {}
  for i = 1, 6 do
    local fs = box:CreateFontString(nil, "ARTWORK", ChatFontNormal and "ChatFontNormal" or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 10, -9 - (i - 1) * 20)
    fs:SetPoint("RIGHT", box, "RIGHT", -10, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    box.lines[i] = fs
  end

  -- switches, in a scrolling list under the preview
  local scroll, content = UI.Scroll(panel)
  scroll:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)

  panel.boxes = {}
  local function Refresh()
    for key, cb in pairs(panel.boxes) do
      cb:SetChecked(OPT[key])
      local parent = PARENT[key]
      local enabled = parent == nil or On(parent)
      if enabled then cb:Enable() else cb:Disable() end
      cb.label:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
    end
    styleDD:Refresh()
    styleNote:SetText(OPT.uiStyle ~= UI.key and ("Now: " .. StyleByKey(UI.key).name .. ". Reload to switch.") or "")
    local lines = PreviewLines()
    for i, fs in ipairs(box.lines) do fs:SetText(lines[i] or "") end
    if panel.Layout then panel.Layout() end
  end
  panel.UpdatePreview = Refresh

  -- collapsible sections: click a header to open or close it
  DB.openSections = DB.openSections or { ["Whisper tag"] = true }
  local headers, Layout = {}, nil

  for _, section in ipairs(SECTIONS) do
    local hb = CreateFrame("Button", nil, content)
    hb:SetSize(540, 22)
    UI.SectionHeader(hb)
    hb.title:SetText(section.title)
    hb.section, hb.boxes = section, {}
    hb:SetScript("OnClick", function(self)
      DB.openSections[section.title] = not DB.openSections[section.title] or nil
      Layout()
    end)
    headers[#headers + 1] = hb

    for _, item in ipairs(section.items) do
      local indent = item.indent or (PARENT[item.key] and 1 or 0)
      local cb = UI.Check(content, item.label, function(self)
        OPT[item.key] = self:GetChecked() and true or false
        if item.key == "minimap" and UpdateMinimapButton then UpdateMinimapButton() end
        Refresh()
      end)
      cb.indent = indent
      panel.boxes[item.key] = cb
      hb.boxes[#hb.boxes + 1] = { key = item.key, cb = cb }
    end
  end

  local defaults = UI.Button(content, "Restore defaults", 150, 24)
  defaults:SetScript("OnClick", function()
    for k, v in pairs(DEFAULTS) do
      if k ~= "uiStyle" then OPT[k] = v end   -- the style has its own picker and needs a reload
    end
    if UpdateMinimapButton then UpdateMinimapButton() end
    Refresh()
  end)

  local reset = UI.Button(content, "", 180, 24)
  reset:SetPoint("LEFT", defaults, "RIGHT", 8, 0)
  reset:SetText("Forget all saved players")
  reset:SetScript("OnClick", function()
    wipe(DB.players); wipe(guidToName); Print("Saved players cleared.")
  end)

  Layout = function()
    local y = -4
    for _, hb in ipairs(headers) do
      local open = DB.openSections[hb.section.title]
      hb:ClearAllPoints()
      hb:SetPoint("TOPLEFT", 4, y)
      hb:SetOpen(open)
      local on = 0
      for _, b in ipairs(hb.boxes) do if OPT[b.key] then on = on + 1 end end
      hb.count:SetText(on .. " of " .. #hb.boxes .. " on")
      y = y - 22
      for _, b in ipairs(hb.boxes) do
        if open then
          b.cb:ClearAllPoints()
          b.cb:SetPoint("TOPLEFT", 24 + b.cb.indent * 20, y)
          b.cb:Show()
          y = y - 24
        else
          b.cb:Hide()
        end
      end
      y = y - 4
    end
    defaults:ClearAllPoints()
    defaults:SetPoint("TOPLEFT", 8, y - 8)
    content:SetHeight(-y + 44)
  end
  panel.Layout = Layout

  panel:SetScript("OnShow", Refresh)

  if Settings and Settings.RegisterCanvasLayoutCategory then
    settingsCategory = Settings.RegisterCanvasLayoutCategory(panel, "Who Are You People?")
    Settings.RegisterAddOnCategory(settingsCategory)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end
end

local function OpenSettings()
  if settingsCategory and Settings and Settings.OpenToCategory then
    Settings.OpenToCategory(settingsCategory.GetID and settingsCategory:GetID() or settingsCategory.ID)
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(settingsPanel)
    InterfaceOptionsFrame_OpenToCategory(settingsPanel)
  end
end

---------------------------------------------------------------- minimap button
-- Left-click: settings. Right-click: card for whoever whispered you last.
-- Drag it around the edge of the minimap.
local mmButton

local function PlaceMinimapButton()
  local angle = math.rad(DB.minimapAngle or 210)
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
      ToggleMessenger()
    elseif button == "RightButton" then
      if lastWhisperer then ShowCard(lastWhisperer) else Print("Nobody has whispered you yet this session.") end
    else
      OpenSettings()
    end
  end)
  b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      local atan2 = math.atan2 or math.atan
      DB.minimapAngle = math.deg(atan2(py / scale - my, px / scale - mx))
      PlaceMinimapButton()
    end)
  end)
  b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Who Are You People?")
    GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: card for your last whisper", 1, 1, 1)
    GameTooltip:AddLine("Shift-click: whisper window", 1, 1, 1)
    GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  PlaceMinimapButton()
end

UpdateMinimapButton = function()
  if OPT.minimap then
    BuildMinimapButton()
    if mmButton then mmButton:Show() end
  elseif mmButton then
    mmButton:Hide()
  end
end

---------------------------------------------------------------- whisper window
-- A Blizzard-style window just for whispers: people on the left, the
-- conversation and a reply box on the right. History is saved between sessions.
local messenger, selectedConvo
local MAX_LIST, MAX_HISTORY = 14, 150

local function ConvoList()
  local t = {}
  for full, c in pairs(DB.convos) do t[#t + 1] = { full = full, c = c } end
  table.sort(t, function(a, b) return (a.c.last or 0) > (b.c.last or 0) end)
  return t
end

local function FormatLine(full, m)
  local stamp = GRAY .. "[" .. date("%H:%M", m.t) .. "]|r "
  if m.from == "me" then
    return stamp .. "|cffffd100You|r: " .. m.msg, 0.85, 0.6, 0.85
  end
  local e = DB.players[full] or {}
  return stamp .. ClassColored(e, Display(full)) .. ": " .. m.msg, 1, 0.5, 1
end

local function RefreshMessenger()
  if not messenger or not messenger:IsShown() then return end
  local list = ConvoList()
  if not selectedConvo or not DB.convos[selectedConvo] then
    selectedConvo = list[1] and list[1].full or nil
  end
  for i, btn in ipairs(messenger.buttons) do
    local item = list[i]
    if item then
      local e = DB.players[item.full] or {}
      local icon = e.classFile and (ClassIcon(e.classFile, 14) or "") or ""
      btn.full = item.full
      btn.name:SetText(icon .. " " .. ClassColored(e, Display(item.full)))
      local unread = item.c.unread or 0
      btn.unread:SetText(unread > 0 and (AccentHex() .. unread .. "|r") or "")
      for _, t in ipairs(btn.sel) do t:SetShown(item.full == selectedConvo) end
      btn:Show()
    else
      btn:Hide()
    end
  end
  local mf = messenger.messages
  mf:Clear()
  if selectedConvo then
    local c = DB.convos[selectedConvo]
    c.unread = 0
    for _, m in ipairs(c.msgs) do mf:AddMessage(FormatLine(selectedConvo, m)) end
    local e = DB.players[selectedConvo] or {}
    messenger.who:SetText(ClassColored(e, Display(selectedConvo)))
    messenger.sub:SetText(Describe(e) .. (e.zone and (GRAY .. "  -  " .. e.zone .. "|r") or ""))
    messenger.reply:Show(); messenger.cardBtn:Show(); messenger.inviteBtn:Show()
    messenger.empty:Hide()
  else
    messenger.who:SetText(""); messenger.sub:SetText("")
    messenger.reply:Hide(); messenger.cardBtn:Hide(); messenger.inviteBtn:Hide()
    messenger.empty:Show()
  end
  -- the list buttons were refreshed before unread was cleared; redraw that count
  for _, btn in ipairs(messenger.buttons) do
    if btn.full == selectedConvo then btn.unread:SetText("") end
  end
end

local function BuildMessenger()
  local m = UI.Window("WhoAreYouPeopleMessenger", 600, 400, "Whispers", "HIGH")
  messenger = m
  if DB.messengerPos then
    local p = DB.messengerPos
    m:SetPoint(p[1], UIParent, p[3], p[4], p[5])
  else
    m:SetPoint("CENTER", UIParent, "CENTER", -120, 60)
  end
  m:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    DB.messengerPos = { self:GetPoint(1) }
    DB.messengerPos[2] = nil
  end)

  -- left: conversations, on a darker sidebar
  UI.Sidebar(m)

  m.buttons = {}
  for i = 1, MAX_LIST do
    local b = CreateFrame("Button", nil, m)
    UI.ListRow(b, i)
    b:SetPoint("TOPLEFT", UI.flat and 1 or 12, -30 - (i - 1) * 24)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    for _, t in ipairs(b.sel) do t:Hide() end
    b.name = UI.Text(b, 12)
    b.name:SetPoint("LEFT", 10, 0)
    b.name:SetPoint("RIGHT", -28, 0)
    b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.unread = UI.Text(b, 11)
    b.unread:SetPoint("RIGHT", -8, 0)
    b:SetScript("OnClick", function(self, button)
      if not self.full then return end
      if button == "RightButton" then
        DB.convos[self.full] = nil       -- right-click: remove the conversation
        if selectedConvo == self.full then selectedConvo = nil end
      else
        selectedConvo = self.full
      end
      RefreshMessenger()
    end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(Display(self.full))
      GameTooltip:AddLine(Describe(DB.players[self.full] or {}), 1, 1, 1)
      GameTooltip:AddLine("Right-click to remove this conversation", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m.buttons[i] = b
  end

  -- right: header, messages, reply box
  m.who = UI.Text(m, 15)
  m.who:SetPoint("TOPLEFT", 196, -40)
  m.sub = UI.Text(m, 11, UI.flat and LOOK.dim or nil)
  m.sub:SetPoint("TOPLEFT", m.who, "BOTTOMLEFT", 0, -4)
  m.sub:SetPoint("RIGHT", -150, 0)
  m.sub:SetJustifyH("LEFT"); m.sub:SetWordWrap(false)

  m.inviteBtn = UI.Button(m, INVITE or "Invite", 64, 22)
  m.inviteBtn:SetPoint("TOPRIGHT", -14, -40)
  m.inviteBtn:SetScript("OnClick", function() if selectedConvo then Invite(Display(selectedConvo)) end end)
  m.cardBtn = UI.Button(m, "Card", 64, 22)
  m.cardBtn:SetPoint("RIGHT", m.inviteBtn, "LEFT", -6, 0)

  UI.Decorate(m, "rule", { 183, -78 }, { -1, -78 })
  m.cardBtn:SetScript("OnClick", function() if selectedConvo then ShowCard(selectedConvo) end end)

  local mf = CreateFrame("ScrollingMessageFrame", nil, m)
  m.messages = mf
  mf:SetPoint("TOPLEFT", 196, -86)
  mf:SetPoint("BOTTOMRIGHT", -16, 48)
  mf:SetFontObject(ChatFontNormal or GameFontHighlight)
  mf:SetJustifyH("LEFT")
  mf:SetFading(false)
  mf:SetMaxLines(MAX_HISTORY + 10)
  mf:SetHyperlinksEnabled(true)
  mf:SetScript("OnHyperlinkClick", function(_, link, text, button) SetItemRef(link, text, button) end)
  mf:EnableMouseWheel(true)
  mf:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
  end)

  m.empty = UI.Text(m, 13, LOOK.dim)
  m.empty:SetPoint("CENTER", 90, 0)
  m.empty:SetText("No whispers yet.")

  local eb = UI.Input(m)
  m.reply = eb
  eb:SetHeight(UI.flat and 26 or 20)
  eb:SetPoint("BOTTOMLEFT", UI.flat and 194 or 200, 14)
  eb:SetPoint("BOTTOMRIGHT", UI.flat and -14 or -18, 14)
  eb:SetMaxLetters(255)
  eb:SetScript("OnEnterPressed", function(self)
    local text = strtrim(self:GetText() or "")
    if text ~= "" and selectedConvo then
      SendChatMessage(text, "WHISPER", nil, Display(selectedConvo))
    end
    self:SetText("")
    self:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local hint = UI.Text(eb, 11, LOOK.dim)
  hint:SetPoint("LEFT", 9, 0)
  hint:SetText("Type a reply and press Enter")
  eb:HookScript("OnEditFocusGained", function() hint:Hide() end)
  eb:HookScript("OnEditFocusLost", function(self) if (self:GetText() or "") == "" then hint:Show() end end)

  m:SetScript("OnShow", RefreshMessenger)
  m:Hide()
end

local function OpenMessenger(full)
  if not On("whisperWindow") then
    Print("The whisper window is turned off in settings (/wi config).")
    return
  end
  if not messenger then BuildMessenger() end
  if full then selectedConvo = full end
  messenger:Show()
  RefreshMessenger()
end

ToggleMessenger = function()
  if messenger and messenger:IsShown() then messenger:Hide() else OpenMessenger() end
end

-- add one message to a conversation; from = "them" or "me"
RecordWhisper = function(full, from, msg)
  if not On("whisperWindow") or not full or not msg then return end
  local c = DB.convos[full]
  if not c then c = { msgs = {}, unread = 0 }; DB.convos[full] = c end
  c.last = time()
  c.msgs[#c.msgs + 1] = { t = c.last, from = from, msg = msg }
  while #c.msgs > MAX_HISTORY do table.remove(c.msgs, 1) end
  local open = messenger and messenger:IsShown()
  if from == "them" and not (open and selectedConvo == full) then
    c.unread = (c.unread or 0) + 1
  end
  if open then
    RefreshMessenger()
  elseif from == "them" and On("whisperAutoOpen") then
    OpenMessenger(full)
  end
end

---------------------------------------------------------------- events
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("WHO_LIST_UPDATE")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("GROUP_ROSTER_UPDATE")

f:SetScript("OnEvent", function(_, event, arg1, arg2)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    WhisperInfoDB = WhisperInfoDB or {}
    DB = WhisperInfoDB
    DB.players = DB.players or {}
    DB.roles = DB.roles or {}
    DB.convos = DB.convos or {}
    DB.options = DB.options or {}
    OPT = DB.options
    if DB.classIcons ~= nil then OPT.classIcons = DB.classIcons; DB.classIcons = nil end  -- old setting
    for k, v in pairs(DEFAULTS) do
      if OPT[k] == nil then OPT[k] = v end
    end
    OPT.theme = nil   -- colour themes were replaced by UI styles in 3.0
    UseStyle(OPT.uiStyle)
    local renamed = {}
    for full in pairs(DB.players) do
      if full:find("%-$") then renamed[#renamed + 1] = full end
    end
    for _, bad in ipairs(renamed) do
      local good = FullName(bad)
      if good then
        DB.players[good] = DB.players[good] or DB.players[bad]
        if DB.roles[bad] then DB.roles[good] = DB.roles[good] or DB.roles[bad] end
      end
      DB.players[bad], DB.roles[bad] = nil, nil
    end
    for full, e in pairs(DB.players) do
      if e.guid then guidToName[e.guid] = full end
    end
    local add = ChatFrame_AddMessageEventFilter
             or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    add("CHAT_MSG_WHISPER", OnWhisper)
    add("CHAT_MSG_BN_WHISPER", OnBNWhisper)
    add("CHAT_MSG_SYSTEM", HideWhoLine)
    add("CHAT_MSG_WHISPER_INFORM", OnWhoAreYouPeoplerm)
    -- class icons are registered after the whisper filter so they end up first on the line
    for _, ev in ipairs({ "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
                          "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
                          "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
                          "CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_CHANNEL", "CHAT_MSG_WHISPER" }) do
      add(ev, OnAnyChat)
    end
    for _, ev in ipairs({ "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
                          "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
                          "CHAT_MSG_INSTANCE_CHAT_LEADER" }) do
      add(ev, OnGroupChat)
    end
    if WorldFrame then WorldFrame:HookScript("OnMouseDown", RunQueuedWho) end
    if EventRegistry and EventRegistry.RegisterCallback then
      EventRegistry:RegisterCallback("SetItemRef", function(_, link) OnLink(link) end, f)
    elseif SetItemRef then
      hooksecurefunc("SetItemRef", function(link) OnLink(link) end)
    end
    BuildSettings()
    UpdateMinimapButton()

  elseif event == "PLAYER_LOGIN" then
    if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end

  elseif event == "WHO_LIST_UPDATE" then
    for i = 1, C_FriendList.GetNumWhoResults() do
      local info = C_FriendList.GetWhoInfo(i)
      local full = info and FullName(info.fullName)
      if full and DB.players[full] then
        local e = DB.players[full]
        e.class, e.classFile = info.classStr or e.class, info.filename or e.classFile
        e.race = e.race or info.raceStr
        WhoFound(full, info.level, info.fullGuildName, info.area)
      end
    end

  elseif event == "CHAT_MSG_WHISPER_INFORM" then
    if not IsSecret(arg1) and not IsSecret(arg2) and not Locked() then
      RecordWhisper(FullName(arg2), "me", arg1)
    end

  elseif event == "CHAT_MSG_SYSTEM" then
    OnSystem(arg1)

  elseif event == "PLAYER_TARGET_CHANGED" then
    UpdateFromUnit("target")
  elseif event == "UPDATE_MOUSEOVER_UNIT" then
    UpdateFromUnit("mouseover")
  elseif event == "GROUP_ROSTER_UPDATE" then
    local prefix = IsInRaid() and "raid" or "party"
    for i = 1, GetNumGroupMembers() do UpdateFromUnit(prefix .. i) end
  end
end)

---------------------------------------------------------------- /wi
SLASH_WHISPERINFO1 = "/wi"
SLASH_WHISPERINFO2 = "/wayp"
SLASH_WHISPERINFO3 = "/whoareyoupeople"
SlashCmdList.WHISPERINFO = function(msg)
  msg = strtrim(msg or "")
  local lower = msg:lower()
  if msg == "" or lower == "help" then
    Print("/wi config - open the settings panel")
    Print("/wi Name  - open the player card for Name")
    Print("/wi list  - last 10 people who whispered you")
    Print("/wi armory Name - copy box with Name's Armory link")
    Print("/wi role tank|heal|dps|clear [Name] - set someone's party role (no name = your target, 'me' = you)")
    Print("/wi icons - turn class icons in chat on/off")
    Print("/wi minimap - show/hide the minimap button")
    Print("/wi whispers - open or close the whisper window")
    Print("/wi notspam Name - never flag Name as spam")
    Print("/wi reset - forget everyone")
  elseif lower == "config" or lower == "settings" or lower == "options" then
    OpenSettings()
  elseif lower == "whispers" or lower == "w" then
    ToggleMessenger()
  elseif lower == "minimap" then
    OPT.minimap = not OPT.minimap
    UpdateMinimapButton()
    Print("Minimap button " .. (OPT.minimap and "shown" or "hidden") .. ".")
    if settingsPanel and settingsPanel.UpdatePreview then settingsPanel.UpdatePreview() end
  elseif lower:find("^notspam%s+") then
    local full = FullName(TitleCase(strtrim(msg:sub(9))))
    if full then
      local e = Entry(full)
      e.notSpam, e.spam = true, nil
      Print(Display(full) .. " won't be flagged as spam again.")
    end
  elseif lower == "icons" then
    OPT.classIcons = not OPT.classIcons
    Print("Class icons in chat " .. (OPT.classIcons and "on" or "off") .. ".")
  elseif lower == "reset" then
    wipe(DB.players); wipe(guidToName); Print("Cleared.")
  elseif lower:find("^armory%s+") then
    local name = strtrim(msg:sub(8))
    if name ~= "" then ShowArmory(FullName(TitleCase(name))) end
  elseif lower:find("^role%s+") then
    local roleWord, who = msg:sub(6):match("^%s*(%S+)%s*(.-)%s*$")
    roleWord = roleWord and roleWord:lower()
    local role = ROLE_ALIAS[roleWord or ""]
    if not role and roleWord ~= "clear" then
      Print("Usage: /wi role tank|heal|dps|clear [Name]"); return
    end
    local full
    if who == "" then
      if UnitIsPlayer("target") then full = FullName(GetUnitName("target", true)) end
    elseif who:lower() == "me" then
      full = FullName(UnitName("player"))
    else
      full = FullName(TitleCase(who))
    end
    if not full then Print("Target a player or give a name."); return end
    DB.roles[full] = role
    Print(Display(full) .. ": " .. (role and ((RoleIcon(role) or "") .. " " .. ROLE_NAME[role]) or "role cleared"))
    if RefreshCard then RefreshCard(full) end
  elseif lower == "list" then
    local t = {}
    for full, e in pairs(DB.players) do t[#t + 1] = { full, e } end
    table.sort(t, function(a, b) return (a[2].seen or 0) > (b[2].seen or 0) end)
    for i = 1, math.min(10, #t) do
      Print(Display(t[i][1]) .. ": " .. Describe(t[i][2]) .. WhoLink(t[i][1]))
    end
    if #t == 0 then Print("Nobody yet.") end
  else
    -- typing the command counts as a key press, so a /who is allowed here
    local full = FullName(TitleCase(msg))
    if not full then return end
    Entry(full)
    ShowCard(full)
    if NeedsWho(DB.players[full]) and GetTime() - lastWho >= 5 then
      SendWhoFor(full, OPT.hideWhoLines)
      RefreshCard(full)
    end
  end
end
