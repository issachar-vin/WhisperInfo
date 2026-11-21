-- Who Are You People?: event handling, loading saved data, and the /wi commands. Loads last.
local ADDON, ns = ...
local BuildOptionsStub = ns.BuildOptionsStub
local BuildSettings = ns.BuildSettings
local DEFAULTS = ns.DEFAULTS
local Describe = ns.Describe
local Display = ns.Display
local Entry = ns.Entry
local FullName = ns.FullName
local HideWhoLine = ns.HideWhoLine
local IsSecret = ns.IsSecret
local Locked = ns.Locked
local NeedsWho = ns.NeedsWho
local OnAnyChat = ns.OnAnyChat
local OnBNWhisper = ns.OnBNWhisper
local OnGroupChat = ns.OnGroupChat
local OnLink = ns.OnLink
local OnSystem = ns.OnSystem
local OnWhisper = ns.OnWhisper
local OnWhisperInform = ns.OnWhisperInform
local OpenSettings = ns.OpenSettings
local Print = ns.Print
local ROLE_ALIAS = ns.ROLE_ALIAS
local ROLE_NAME = ns.ROLE_NAME
local RoleIcon = ns.RoleIcon
local RunQueuedWho = ns.RunQueuedWho
local SendWhoFor = ns.SendWhoFor
local ShowArmory = ns.ShowArmory
local TitleCase = ns.TitleCase
local UpdateFromUnit = ns.UpdateFromUnit
local UseStyle = ns.UseStyle
local WhoFound = ns.WhoFound
local WhoLink = ns.WhoLink
local f = ns.f
local guidToName = ns.guidToName

---------------------------------------------------------------- events
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("WHO_LIST_UPDATE")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
f:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("GROUP_ROSTER_UPDATE")

f:SetScript("OnEvent", function(_, event, arg1, arg2, ...)
  if event == "ADDON_LOADED" and arg1 == ADDON then
    WhisperInfoDB = WhisperInfoDB or {}
    ns.DB = WhisperInfoDB
    ns.DB.players = ns.DB.players or {}
    ns.DB.roles = ns.DB.roles or {}
    ns.DB.convos = ns.DB.convos or {}
    ns.DB.options = ns.DB.options or {}
    ns.OPT = ns.DB.options
    if ns.DB.classIcons ~= nil then ns.OPT.classIcons = ns.DB.classIcons; ns.DB.classIcons = nil end  -- old setting
    for k, v in pairs(DEFAULTS) do
      if ns.OPT[k] == nil then ns.OPT[k] = v end
    end
    ns.OPT.theme = nil   -- colour themes were replaced by UI styles in 3.0
    UseStyle(ns.OPT.uiStyle)
    local renamed = {}
    for full in pairs(ns.DB.players) do
      if full:find("%-$") then renamed[#renamed + 1] = full end
    end
    for _, bad in ipairs(renamed) do
      local good = FullName(bad)
      if good then
        ns.DB.players[good] = ns.DB.players[good] or ns.DB.players[bad]
        if ns.DB.roles[bad] then ns.DB.roles[good] = ns.DB.roles[good] or ns.DB.roles[bad] end
      end
      ns.DB.players[bad], ns.DB.roles[bad] = nil, nil
    end
    for full, e in pairs(ns.DB.players) do
      if e.guid then guidToName[e.guid] = full end
    end
    local add = ChatFrame_AddMessageEventFilter
             or (ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter)
    add("CHAT_MSG_WHISPER", OnWhisper)
    add("CHAT_MSG_BN_WHISPER", OnBNWhisper)
    add("CHAT_MSG_SYSTEM", HideWhoLine)
    add("CHAT_MSG_WHISPER_INFORM", OnWhisperInform)
    add("CHAT_MSG_BN_WHISPER_INFORM", OnWhisperInform)
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
    BuildOptionsStub(OpenSettings)
    ns.UpdateMinimapButton()

  elseif event == "PLAYER_LOGIN" then
    if IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end

  elseif event == "WHO_LIST_UPDATE" then
    for i = 1, C_FriendList.GetNumWhoResults() do
      local info = C_FriendList.GetWhoInfo(i)
      local full = info and FullName(info.fullName)
      if full and ns.DB.players[full] then
        local e = ns.DB.players[full]
        e.class, e.classFile = info.classStr or e.class, info.filename or e.classFile
        e.race = e.race or info.raceStr
        WhoFound(full, info.level, info.fullGuildName, info.area)
      end
    end

  elseif event == "CHAT_MSG_WHISPER_INFORM" then
    if not IsSecret(arg1) and not IsSecret(arg2) and not Locked() then
      ns.RecordWhisper(FullName(arg2), "me", arg1)
    end

  elseif event == "CHAT_MSG_BN_WHISPER_INFORM" then
    local bnID = select(11, ...)   -- arg13: the friend's account ID
    if not IsSecret(arg1) and bnID and not IsSecret(bnID) and not Locked() and C_BattleNet then
      local acct = C_BattleNet.GetAccountInfoByID(bnID)
      if acct and acct.battleTag then ns.RecordWhisper("BN:" .. acct.battleTag, "me", arg1) end
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
    Print("/wi config - open the settings window")
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
    ns.ToggleMessenger()
  elseif lower == "minimap" then
    ns.OPT.minimap = not ns.OPT.minimap
    ns.UpdateMinimapButton()
    Print("Minimap button " .. (ns.OPT.minimap and "shown" or "hidden") .. ".")
    if ns.settingsPanel and ns.settingsPanel.UpdatePreview then ns.settingsPanel.UpdatePreview() end
  elseif lower:find("^notspam%s+") then
    local full = FullName(TitleCase(strtrim(msg:sub(9))))
    if full then
      local e = Entry(full)
      e.notSpam, e.spam = true, nil
      Print(Display(full) .. " won't be flagged as spam again.")
    end
  elseif lower == "icons" then
    ns.OPT.classIcons = not ns.OPT.classIcons
    Print("Class icons in chat " .. (ns.OPT.classIcons and "on" or "off") .. ".")
  elseif lower == "reset" then
    wipe(ns.DB.players); wipe(guidToName); Print("Cleared.")
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
    ns.DB.roles[full] = role
    Print(Display(full) .. ": " .. (role and ((RoleIcon(role) or "") .. " " .. ROLE_NAME[role]) or "role cleared"))
    if ns.RefreshCard then ns.RefreshCard(full) end
  elseif lower == "list" then
    local t = {}
    for full, e in pairs(ns.DB.players) do t[#t + 1] = { full, e } end
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
    ns.ShowCard(full)
    if NeedsWho(ns.DB.players[full]) and GetTime() - ns.lastWho >= 5 then
      SendWhoFor(full, ns.OPT.hideWhoLines)
      ns.RefreshCard(full)
    end
  end
end
