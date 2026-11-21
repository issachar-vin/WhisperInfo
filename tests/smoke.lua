-- Smoke test: load the addon against a fake WoW API, build every window,
-- and fire every script handler to catch Lua runtime errors in our code.
-- It can't check how things look or that the real game API behaves as faked.
-- Usage: lua tests/smoke.lua WhoAreYouPeople.lua [style]   (VERBOSE=1 for chat output)
-- style is a saved UI style (forever, eui, classic, blizzard), as if picked before a reload.
local addonFile, style = arg[1], arg[2]
local VERBOSE = os.getenv("VERBOSE")

local objects = {}
local NUMERIC = {
  GetWidth = 200, GetHeight = 300, GetVerticalScroll = 0, GetVerticalScrollRange = 100,
  GetEffectiveScale = 1, GetNumPoints = 1, GetFrameLevel = 1,
}
local function NewObject(kind, name)
  local o = { _kind = kind, _name = name, _scripts = {}, _shown = true, _enabled = true, _text = "" }
  local methods = {
    SetScript = function(self, ev, fn) self._scripts[ev] = fn and { fn } or nil end,
    HookScript = function(self, ev, fn)
      self._scripts[ev] = self._scripts[ev] or {}
      table.insert(self._scripts[ev], fn)
    end,
    GetScript = function(self, ev) return self._scripts[ev] and self._scripts[ev][1] end,
    Show = function(self) self._shown = true end,
    Hide = function(self) self._shown = false end,
    SetShown = function(self, v) self._shown = v and true or false end,
    IsShown = function(self) return self._shown end,
    IsVisible = function(self) return self._shown end,
    Enable = function(self) self._enabled = true end,
    Disable = function(self) self._enabled = false end,
    IsEnabled = function(self) return self._enabled end,
    SetText = function(self, t) self._text = t end,
    GetText = function(self) return self._text end,
    SetFontString = function(self, fs) self._fs = fs end,
    GetFontString = function(self) return self._fs end,
    GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
    GetCenter = function() return 100, 100 end,
    GetName = function(self) return rawget(self, "_name") end,
    CreateTexture = function() return NewObject("Texture") end,
    CreateFontString = function() return NewObject("FontString") end,
    GetChecked = function(self) return self._checked end,
    SetChecked = function(self, v) self._checked = v end,
    AddMessage = function(self, msg) if VERBOSE and rawget(self, "_name") == "ChatFrame1" then print("  [chat] " .. tostring(msg)) end end,
    HasFocus = function() return false end,
    GetID = function() return 1 end,
  }
  return setmetatable(o, { __index = function(_, k)
    if methods[k] then return methods[k] end
    if NUMERIC[k] then return function() return NUMERIC[k] end end
    -- other widget methods are no-ops; capitalised fields such as TitleText stay nil
    if type(k) == "string" and (k:match("^[SG]et%u") or k:match("^Is%u") or k:match("^Has%u")
      or k:match("^(Enable)") or k:match("^(Disable)") or k:match("^Register") or k:match("^Unregister")
      or k:match("^Clear") or k:match("^Add") or k:match("^Create") or k:match("^Start") or k:match("^Stop")
      or k:match("^Scroll") or k:match("^Highlight") or k:match("^Raise") or k:match("^Lower")) then
      return function() end
    end
    return nil
  end })
end

function CreateFrame(kind, name, parent, template)
  local o = NewObject(kind, name)
  objects[#objects + 1] = o
  if name then _G[name] = o end
  if template and template:find("BasicFrameTemplate") then
    o.TitleText = NewObject("FontString")
  elseif template == "ButtonFrameTemplate" then
    o.TitleContainer = { TitleText = NewObject("FontString") }
  elseif template == "UICheckButtonTemplate" then
    o.Text = NewObject("FontString")
  elseif template == "UIPanelButtonTemplate" then
    o._fs = NewObject("FontString")   -- the template's own button label
  end
  return o
end

-- game globals the addon touches
UIParent = NewObject("Frame", "UIParent")
Minimap = NewObject("Frame", "Minimap")
DEFAULT_CHAT_FRAME = NewObject("Frame", "ChatFrame1")
GameTooltip = NewObject("Frame", "GameTooltip")
ChatFontNormal, GameFontHighlight = NewObject("Font"), NewObject("Font")
UISpecialFrames = {}
SlashCmdList = {}
StaticPopupDialogs = {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return { r = 0.96, g = 0.55, b = 0.73, colorStr = "fff58cba" } end })
LOCALIZED_CLASS_NAMES_MALE = setmetatable({}, { __index = function(_, k) return k end })
CLASS_ICON_TCOORDS = setmetatable({}, { __index = function() return { 0, 0.25, 0, 0.25 } end })
INVITE, WHISPER, CLOSE = "Invite", "Whisper", "Close"
Settings = {
  RegisterCanvasLayoutCategory = function() return { GetID = function() return 1 end, ID = 1 } end,
  RegisterAddOnCategory = function() end,
  OpenToCategory = function() end,
}
C_FriendList = setmetatable({ GetNumWhoResults = function() return 0 end }, { __index = function() return function() end end })
C_ChatInfo, C_GuildInfo = {}, {}
C_Timer = { After = function(_, fn) end, NewTimer = function() return { Cancel = function() end } end }
ChatFrame_AddMessageEventFilter = function() end
ChatFrame_RemoveMessageEventFilter = function() end
hooksecurefunc = function() end
function strtrim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert, tremove = table.insert, table.remove
format, strlower, strupper, strsplit = string.format, string.lower, string.upper, function(d, s) return s end
function GetTime() return 1000 end
function GetCursorPosition() return 10, 10 end
function IsShiftKeyDown() return false end
function IsInGuild() return false end
function IsInGroup() return false end
function IsInRaid() return false end
function UnitClass() return "Paladin", "PALADIN" end
function UnitFactionGroup() return "Horde" end
function UnitName() return "Tester" end
function UnitExists() return false end
function UnitIsPlayer() return false end
function UnitGUID() return nil end
function UnitLevel() return 20 end
function GetNormalizedRealmName() return "" end
function GetRealmName() return "" end
function GetCurrentRegion() return 1 end
function Ambiguate(n) return n end
function SendChatMessage() end
function InviteUnit() end
function SetItemRef() end
function ChatFrame_SendTell() end
function GetNumGroupMembers() return 0 end
function UnitGroupRolesAssigned() return "NONE" end
function GetPlayerInfoByGUID() return nil end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
math.atan2 = math.atan2 or math.atan
unpack = unpack or table.unpack
getn = function(t) return #t end
function issecretvalue() return false end
BackdropTemplateMixin = {}
function Mixin(o, m) for k, v in pairs(m) do o[k] = v end return o end
function StaticPopup_Show() end
function ReloadUI() end
function ButtonFrameTemplate_HidePortrait() end
function ButtonFrameTemplate_HideButtonBar() end
time, date = os.time, os.date
WorldFrame = NewObject("Frame", "WorldFrame")
function GetQuestDifficultyColor() return { r = 1, g = 1, b = 0 } end

-- report any global the addon reads that we haven't stubbed
local seen = {}
setmetatable(_G, { __index = function(_, k)
  if VERBOSE and not seen[k] then seen[k] = true; io.stderr:write("  (not stubbed, treated as missing: " .. tostring(k) .. ")\n") end
  return nil
end })

local failures = 0
local function try(label, fn, ...)
  local args, n = { ... }, select("#", ...)
  local ok, err = xpcall(function() return fn((unpack or table.unpack)(args, 1, n)) end, debug.traceback)
  if not ok then
    failures = failures + 1
    print("FAIL " .. label .. "\n" .. err)
  end
  return ok
end

-- the game only sends mouse and key events to frames that are shown
local ALWAYS = { OnEvent = true, OnShow = true, OnHide = true, OnEnable = true, OnDisable = true }
local function Fire(o, ev, ...)
  local list = o._scripts[ev]
  if not list then return end
  if not ALWAYS[ev] and not o._shown then return end
  for _, fn in ipairs(list) do
    try((rawget(o, "_name") or o._kind) .. ":" .. ev, fn, o, ...)
  end
end
local function FireAll(ev, ...)
  local snapshot = { (unpack or table.unpack)(objects) }
  for _, o in ipairs(snapshot) do Fire(o, ev, ...) end
end

print("== load" .. (style and (" (UI style: " .. style .. ")") or ""))
if style then rawset(_G, "WhisperInfoDB", { options = { uiStyle = style } }) end
local chunk = assert(loadfile(addonFile))
try("load", chunk, "WhoAreYouPeople")

print("== events")
FireAll("OnEvent", "ADDON_LOADED", "WhoAreYouPeople")
FireAll("OnEvent", "PLAYER_LOGIN")

print("== slash commands")
local slash
for k, fn in pairs(SlashCmdList) do slash = fn end
for _, cmd in ipairs({ "", "config", "whispers", "addled ark", "armory addled ark", "list", "icons", "icons", "minimap", "minimap" }) do
  try("/wi " .. cmd, slash, cmd)
end

print("== record a whisper conversation")
FireAll("OnEvent", "CHAT_MSG_WHISPER_INFORM", "hello there", "Addled Ark")

print("== every window shown, every handler fired (" .. #objects .. " frames)")
for _, theme in ipairs({ "Who Are You People?", "Horde", "Faction (Auto)", "Class Colored", "Midnight" }) do
  WhisperInfoDB.options.theme = theme
  for _, ev in ipairs({ "OnShow", "OnEnter", "OnLeave", "OnEditFocusGained", "OnEditFocusLost", "OnEnable", "OnDisable" }) do
    FireAll(ev)
  end
  FireAll("OnClick", "LeftButton")
  FireAll("OnClick", "RightButton")
  FireAll("OnMouseWheel", -1)
  FireAll("OnVerticalScroll", 10)
  FireAll("OnTextChanged", true)
  FireAll("OnEnterPressed")
  FireAll("OnEscapePressed")
end

print(failures == 0 and "== PASS: no Lua errors" or ("== " .. failures .. " FAILURES"))
os.exit(failures == 0 and 0 or 1)
