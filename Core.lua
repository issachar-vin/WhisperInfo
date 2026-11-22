-- Who Are You People?: shared state, saved-settings defaults and helpers used by every file.
-- The addon tells you who is whispering you: level, class and guild on whispers, a player
-- card, a Whispers window, class and role icons in chat, and a settings window.
local ADDON, ns = ...
local f = CreateFrame("Frame")
local guidToName = {}    -- guid -> "Name-Realm"
local handledLine = {}   -- lineID -> true (filters run once per chat frame)
local waitingWho = {}    -- "Name-Realm" -> GetTime() the lookup was sent
local autoQueue, autoQueued = {}, {}   -- people to /who on your next click
local hideWhoUntil = {}                -- hide the raw /who chat line for these
ns.lastWho, ns.lastHidden = 0, 0
-- Values that change after load live on ns, so every file sees the current one:
-- ns.DB and ns.OPT (saved data, set at ADDON_LOADED), ns.UI (the UI style kit),
-- ns.lastWho / ns.lastHidden / ns.lastWhisperer, and functions a later file fills in:
-- ns.ShowCard and ns.RefreshCard (Card.lua), ns.SpamReason (Chat.lua),
-- ns.RecordWhisper and ns.ToggleMessenger (Whispers.lua), ns.UpdateMinimapButton (Minimap.lua).

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
  cardOnWhisper = false, -- open the player card when someone whispers you
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
  whisperNotify   = "none", -- on a new whisper: "none", "window" (open it) or "toast"
  toastDuration   = 8,      -- seconds a toast stays; 0 = until clicked
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
  whisperNotify = "whisperWindow", toastDuration = "whisperWindow", moveToast = "whisperWindow",
  whisperHideChat = "whisperWindow",
}
-- a setting counts only if it and everything above it is on
local function On(key)
  if not ns.OPT[key] then return false end
  local parent = PARENT[key]
  return parent == nil or On(parent)
end
local SPAM_MAX_LEVEL = 5

local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(ns.AccentHex() .. "Who Are You People?|r " .. msg)
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
  local e = ns.DB.players[full]
  if not e then e = {}; ns.DB.players[full] = e end
  return e
end

local function LevelText(lvl)
  if not lvl then return "Lvl ?" end
  local t = "Lvl " .. lvl
  local col = ns.OPT.tagLevelColor and GetQuestDifficultyColor and GetQuestDifficultyColor(lvl)
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

-- shared with the other files
ns.ClassColored = ClassColored
ns.DEFAULTS = DEFAULTS
ns.Describe = Describe
ns.Display = Display
ns.Entry = Entry
ns.FullName = FullName
ns.GRAY = GRAY
ns.IsSecret = IsSecret
ns.LevelText = LevelText
ns.Locked = Locked
ns.NeedsWho = NeedsWho
ns.On = On
ns.PARENT = PARENT
ns.Print = Print
ns.SPAM_MAX_LEVEL = SPAM_MAX_LEVEL
ns.ShortName = ShortName
ns.TitleCase = TitleCase
ns.autoQueue = autoQueue
ns.autoQueued = autoQueued
ns.f = f
ns.guidToName = guidToName
ns.handledLine = handledLine
ns.hideWhoUntil = hideWhoUntil
ns.waitingWho = waitingWho
