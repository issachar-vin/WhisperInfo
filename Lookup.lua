-- Who Are You People?: finding out who a player is (units, guild, friends, /who) and party roles.
local ADDON, ns = ...
local Describe = ns.Describe
local Display = ns.Display
local Entry = ns.Entry
local FullName = ns.FullName
local GRAY = ns.GRAY
local IsSecret = ns.IsSecret
local Locked = ns.Locked
local On = ns.On
local Print = ns.Print
local ShortName = ns.ShortName
local autoQueue = ns.autoQueue
local autoQueued = ns.autoQueued
local guidToName = ns.guidToName
local hideWhoUntil = ns.hideWhoUntil
local waitingWho = ns.waitingWho

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
  if full and ns.DB.players[full] then
    ReadUnit(ns.DB.players[full], unit)
    if ns.RefreshCard then ns.RefreshCard(full) end
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
  if full and ns.DB.roles[full] then return ns.DB.roles[full] end
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
  ns.lastWho = GetTime()
  waitingWho[full] = GetTime()
  if hide then hideWhoUntil[full] = GetTime() + 10 end
  C_FriendList.SendWho('n-"' .. ShortName(full) .. '"')
  -- no answer after a few seconds = offline, other faction, or a typo
  if C_Timer then
    C_Timer.After(4, function()
      if waitingWho[full] then
        waitingWho[full] = nil
        local e = ns.DB.players[full]
        if e then e.whoMissed = true end
        if ns.RefreshCard then ns.RefreshCard(full) end
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
  if not ns.OPT.autoWho or #autoQueue == 0 or GetTime() - ns.lastWho < 5 then return end
  SendWhoFor(table.remove(autoQueue, 1), ns.OPT.hideWhoLines)
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
  if not ns.OPT.hideWhoLines or type(msg) ~= "string" or IsSecret(msg) then return false end
  local name
  if WHO_GUILD then name = msg:match(WHO_GUILD) end
  if not name and WHO_PLAIN then name = msg:match(WHO_PLAIN) end
  if name then
    local full = FullName(name)
    if full and hideWhoUntil[full] and GetTime() < hideWhoUntil[full] then
      ns.lastHidden = GetTime()
      return true
    end
  elseif GetTime() - ns.lastHidden < 2 and msg:match("^%d+ [Pp]layers? [Tt]otal") then
    return true
  end
  return false
end

local function WhoFound(full, lvl, guild, zone)
  local e = ns.DB.players[full]
  if not e then return end
  e.level = tonumber(lvl) or e.level
  e.guild = (guild and guild ~= "") and guild or false
  if zone and zone ~= "" then e.zone = zone end
  e.lastOnline = time()
  e.whoMissed = nil
  if waitingWho[full] then
    waitingWho[full] = nil
    local card = _G.WhoAreYouPeopleCard
    local spam = ns.OPT.spamFlag and ns.SpamReason and ns.SpamReason(e, full, "")
    if spam then e.spam = true end
    if ns.OPT.printLookups and not (card and card:IsShown() and card.full == full) then
      Print(Display(full) .. " is " .. Describe(e) ..
            (e.zone and (GRAY .. " in " .. e.zone .. "|r") or "") ..
            (spam and " |cffff6060- likely spam|r" or ""))
    end
  end
  if ns.RefreshCard then ns.RefreshCard(full) end
end

local function OnSystem(msg)
  if type(msg) ~= "string" or IsSecret(msg) then return end
  local name, lvl, guild, zone, _
  if WHO_GUILD then name, _, lvl, _, _, guild, zone = msg:match(WHO_GUILD) end
  if not name and WHO_PLAIN then name, _, lvl, _, _, zone = msg:match(WHO_PLAIN); guild = false end
  if not name then return end
  WhoFound(FullName(name), lvl, guild, zone)
end

-- shared with the other files
ns.Gather = Gather
ns.HideWhoLine = HideWhoLine
ns.OnGroupChat = OnGroupChat
ns.OnSystem = OnSystem
ns.QueueWho = QueueWho
ns.ROLE_ALIAS = ROLE_ALIAS
ns.ROLE_NAME = ROLE_NAME
ns.RoleIcon = RoleIcon
ns.RunQueuedWho = RunQueuedWho
ns.SendWhoFor = SendWhoFor
ns.UpdateFromUnit = UpdateFromUnit
ns.WhoFound = WhoFound
