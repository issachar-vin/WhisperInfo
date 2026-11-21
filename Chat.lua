-- Who Are You People?: chat filters: the whisper tag, class and role icons, spam flag and links.
local ADDON, ns = ...
local ClassColored = ns.ClassColored
local Display = ns.Display
local Entry = ns.Entry
local FullName = ns.FullName
local GRAY = ns.GRAY
local Gather = ns.Gather
local IsSecret = ns.IsSecret
local LevelText = ns.LevelText
local Locked = ns.Locked
local NeedsWho = ns.NeedsWho
local On = ns.On
local Print = ns.Print
local QueueWho = ns.QueueWho
local SPAM_MAX_LEVEL = ns.SPAM_MAX_LEVEL
local SendWhoFor = ns.SendWhoFor
local ShortName = ns.ShortName
local autoQueued = ns.autoQueued
local handledLine = ns.handledLine

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
  local e = ns.DB.players[full]
  if not e then return "" end
  return TagFor(e, full)
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
ns.SpamReason = function(e, full, msg)
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
    ns.lastWhisperer = full
    if ns.OPT.autoWho and NeedsWho(e) then QueueWho(full) end
    local spam = ns.OPT.spamFlag and ns.SpamReason(e, full, msg)
    if not spam and ns.RecordWhisper then ns.RecordWhisper(full, "them", msg) end
  end
  e = e or ns.DB.players[full]
  if On("whisperHideChat") and not (ns.OPT.spamFlag and ns.SpamReason(e, full, msg)) then return true end
  if ns.OPT.spamFlag and e then
    local why = ns.SpamReason(e, full, msg)
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
  local first = lineID and not handledLine[lineID]
  if first then
    handledLine[lineID] = true
    if acct and acct.battleTag and ns.RecordWhisper then ns.RecordWhisper("BN:" .. acct.battleTag, "them", msg) end
  end
  local hide = On("whisperHideChat")
  local g = acct and acct.gameAccountInfo
  if not g or g.clientProgram ~= BNET_CLIENT_WOW or not g.characterName or g.characterName == "" then
    return hide
  end
  local realm = g.realmName and g.realmName:gsub("%s", "") or ""
  local full = FullName(realm ~= "" and (g.characterName .. "-" .. realm) or g.characterName)
  if first then
    local e = Gather(full, g.playerGuid)
    if g.characterLevel and g.characterLevel > 0 then e.level = g.characterLevel end
    e.class = e.class or g.className
    NoteWhisper(e)
    if ns.OPT.autoWho and NeedsWho(e) then QueueWho(full) end
  end
  if hide then return true end
  if not On("tagBN") then return false end
  local tag = Tag(full)
  if tag == "" then return false end
  return false, tag .. msg, sender, ...
end

local function OnWhisperInform(_, event, msg, target, ...)
  if On("whisperHideChat") and not IsSecret(msg) then return true end
  return false
end

---------------------------------------------------------------- links
local function OnLink(link)
  if type(link) ~= "string" then return end
  local cmd, full = link:match("^addon:WhoAreYouPeople:(%a+):(.+)$")
  if not full then return end
  if cmd == "armory" then
    ns.ShowArmory(full)
  elseif cmd == "notspam" then
    local e = Entry(full)
    e.notSpam, e.spam = true, nil
    Print(Display(full) .. " won't be flagged as spam again.")
    if ns.RefreshCard then ns.RefreshCard(full) end
  elseif cmd == "who" then
    autoQueued[full] = true
    if ns.OPT.whoCard then ns.ShowCard(full) end
    if GetTime() - ns.lastWho >= 5 then
      SendWhoFor(full, ns.OPT.whoCard and ns.OPT.hideWhoLines)
    elseif not ns.OPT.whoCard then
      Print("/who needs a few seconds between lookups - click again shortly.")
    end
    if ns.RefreshCard then ns.RefreshCard(full) end
  end
end

-- shared with the other files
ns.ClassIcon = ClassIcon
ns.OnAnyChat = OnAnyChat
ns.OnBNWhisper = OnBNWhisper
ns.OnLink = OnLink
ns.OnWhisper = OnWhisper
ns.OnWhisperInform = OnWhisperInform
ns.SpamLink = SpamLink
ns.TagFor = TagFor
ns.WhoLink = WhoLink
