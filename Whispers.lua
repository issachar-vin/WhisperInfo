-- Who Are You People?: the Whispers window and saved conversations, Battle.net included.
local ADDON, ns = ...
local AccentHex = ns.AccentHex
local ClassColored = ns.ClassColored
local ClassIcon = ns.ClassIcon
local Describe = ns.Describe
local Display = ns.Display
local FullName = ns.FullName
local GRAY = ns.GRAY
local Invite = ns.Invite
local LOOK = ns.LOOK
local On = ns.On
local Print = ns.Print

---------------------------------------------------------------- whisper window
-- A Blizzard-style window just for whispers: people on the left, the
-- conversation and a reply box on the right. History is saved between sessions.
local messenger, selectedConvo
local MAX_LIST, MAX_HISTORY = 14, 150

-- Battle.net conversations are saved under "BN:" plus the BattleTag, which
-- stays the same between sessions (the account ID does not).
local BN_COLOR = "|cff82c5ff"
local BN_ICON = "|TInterface\\FriendsFrame\\Battlenet-Battleneticon:14:14:0:0:32:32:5:27:5:27|t"
local function IsBN(key) return key:sub(1, 3) == "BN:" end
local function BNKey(battleTag) return "BN:" .. battleTag end

-- the friend's live account info, or nil if they are no longer on the friends list
local function BNAccount(key)
  if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo and BNGetNumFriends) then return nil end
  local tag = key:sub(4)
  for i = 1, (BNGetNumFriends()) or 0 do
    local a = C_BattleNet.GetFriendAccountInfo(i)
    if a and a.battleTag == tag then return a end
  end
end

-- the WoW character a Battle.net friend is playing right now, if any
local function BNCharacter(acct)
  local g = acct and acct.gameAccountInfo
  if not g or not g.isOnline or g.clientProgram ~= BNET_CLIENT_WOW or not g.characterName or g.characterName == "" then
    return nil
  end
  local realm = g.realmName and g.realmName:gsub("%s", "") or ""
  return FullName(realm ~= "" and (g.characterName .. "-" .. realm) or g.characterName)
end

-- name shown for a conversation: a character, or a Battle.net friend's BattleTag name
local function ConvoName(key)
  if IsBN(key) then return BN_COLOR .. (key:match("^BN:([^#]+)") or key:sub(4)) .. "|r" end
  return ClassColored(ns.DB.players[key] or {}, Display(key))
end

local function ConvoList()
  local t = {}
  for full, c in pairs(ns.DB.convos) do t[#t + 1] = { full = full, c = c } end
  table.sort(t, function(a, b) return (a.c.last or 0) > (b.c.last or 0) end)
  return t
end

local function FormatLine(full, m)
  local stamp = GRAY .. "[" .. date("%H:%M", m.t) .. "]|r "
  if m.from == "me" then
    return stamp .. "|cffffd100You|r: " .. m.msg, IsBN(full) and 0.6 or 0.85, IsBN(full) and 0.75 or 0.6, IsBN(full) and 0.9 or 0.85
  end
  if IsBN(full) then return stamp .. ConvoName(full) .. ": " .. m.msg, 0.5, 0.8, 1 end
  return stamp .. ConvoName(full) .. ": " .. m.msg, 1, 0.5, 1
end

local function RefreshMessenger()
  if not messenger or not messenger:IsShown() then return end
  local list = ConvoList()
  if not selectedConvo or not ns.DB.convos[selectedConvo] then
    selectedConvo = list[1] and list[1].full or nil
  end
  for i, btn in ipairs(messenger.buttons) do
    local item = list[i]
    if item then
      local e = ns.DB.players[item.full] or {}
      local icon = IsBN(item.full) and BN_ICON or (e.classFile and (ClassIcon(e.classFile, 14) or "") or "")
      btn.full = item.full
      btn.name:SetText(icon .. " " .. ConvoName(item.full))
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
    local c = ns.DB.convos[selectedConvo]
    c.unread = 0
    for _, m in ipairs(c.msgs) do mf:AddMessage(FormatLine(selectedConvo, m)) end
    messenger.who:SetText(ConvoName(selectedConvo))
    -- a Battle.net friend's card and invite go to the character they are playing, if any
    local char = selectedConvo
    if IsBN(selectedConvo) then
      local acct = BNAccount(selectedConvo)
      char = BNCharacter(acct)
      local where = not acct and "no longer on your friends list"
        or char and (Describe(ns.DB.players[char] or {}) .. "  " .. GRAY .. Display(char) .. "|r")
        or (acct.gameAccountInfo and acct.gameAccountInfo.isOnline and "online, not in WoW Forever")
        or "offline"
      messenger.sub:SetText(BN_COLOR .. "Battle.net|r  " .. where)
    else
      local e = ns.DB.players[selectedConvo] or {}
      messenger.sub:SetText(Describe(e) .. (e.zone and (GRAY .. "  -  " .. e.zone .. "|r") or ""))
    end
    messenger.char = char
    messenger.reply:Show(); messenger.cardBtn:SetShown(char ~= nil); messenger.inviteBtn:SetShown(char ~= nil)
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
  local m = ns.UI.Window("WhoAreYouPeopleMessenger", 600, 400, "Whispers", "HIGH")
  messenger = m
  if ns.DB.messengerPos then
    local p = ns.DB.messengerPos
    m:SetPoint(p[1], UIParent, p[3], p[4], p[5])
  else
    m:SetPoint("CENTER", UIParent, "CENTER", -120, 60)
  end
  m:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    ns.DB.messengerPos = { self:GetPoint(1) }
    ns.DB.messengerPos[2] = nil
  end)

  -- left: conversations, on a darker sidebar
  ns.UI.Sidebar(m)

  m.buttons = {}
  for i = 1, MAX_LIST do
    local b = CreateFrame("Button", nil, m)
    ns.UI.ListRow(b, i)
    b:SetPoint("TOPLEFT", ns.UI.flat and 1 or 12, -30 - (i - 1) * 24)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    for _, t in ipairs(b.sel) do t:Hide() end
    b.name = ns.UI.Text(b, 12)
    b.name:SetPoint("LEFT", 10, 0)
    b.name:SetPoint("RIGHT", -28, 0)
    b.name:SetJustifyH("LEFT"); b.name:SetWordWrap(false)
    b.unread = ns.UI.Text(b, 11)
    b.unread:SetPoint("RIGHT", -8, 0)
    b:SetScript("OnClick", function(self, button)
      if not self.full then return end
      if button == "RightButton" then
        ns.DB.convos[self.full] = nil       -- right-click: remove the conversation
        if selectedConvo == self.full then selectedConvo = nil end
      else
        selectedConvo = self.full
      end
      RefreshMessenger()
    end)
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(ConvoName(self.full))
      GameTooltip:AddLine(IsBN(self.full) and "Battle.net friend" or Describe(ns.DB.players[self.full] or {}), 1, 1, 1)
      GameTooltip:AddLine("Right-click to remove this conversation", 0.6, 0.6, 0.6)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    m.buttons[i] = b
  end

  -- right: header, messages, reply box
  m.who = ns.UI.Text(m, 15)
  m.who:SetPoint("TOPLEFT", 196, -40)
  m.sub = ns.UI.Text(m, 11, ns.UI.flat and LOOK.dim or nil)
  m.sub:SetPoint("TOPLEFT", m.who, "BOTTOMLEFT", 0, -4)
  m.sub:SetPoint("RIGHT", -150, 0)
  m.sub:SetJustifyH("LEFT"); m.sub:SetWordWrap(false)

  m.inviteBtn = ns.UI.Button(m, INVITE or "Invite", 64, 22)
  m.inviteBtn:SetPoint("TOPRIGHT", -14, -40)
  m.inviteBtn:SetScript("OnClick", function() if m.char then Invite(Display(m.char)) end end)
  m.cardBtn = ns.UI.Button(m, "Card", 64, 22)
  m.cardBtn:SetPoint("RIGHT", m.inviteBtn, "LEFT", -6, 0)

  ns.UI.Decorate(m, "rule", { 183, -78 }, { -1, -78 })
  m.cardBtn:SetScript("OnClick", function() if m.char then ns.ShowCard(m.char) end end)

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

  m.empty = ns.UI.Text(m, 13, LOOK.dim)
  m.empty:SetPoint("CENTER", 90, 0)
  m.empty:SetText("No whispers yet.")

  local eb = ns.UI.Input(m)
  m.reply = eb
  eb:SetHeight(ns.UI.flat and 26 or 20)
  eb:SetPoint("BOTTOMLEFT", ns.UI.flat and 194 or 200, 14)
  eb:SetPoint("BOTTOMRIGHT", ns.UI.flat and -14 or -18, 14)
  eb:SetMaxLetters(255)
  eb:SetScript("OnEnterPressed", function(self)
    local text = strtrim(self:GetText() or "")
    if text ~= "" and selectedConvo then
      if IsBN(selectedConvo) then
        local acct = BNAccount(selectedConvo)
        if acct then BNSendWhisper(acct.bnetAccountID, text) else Print("That Battle.net friend is no longer on your friends list.") end
      else
        SendChatMessage(text, "WHISPER", nil, Display(selectedConvo))
      end
    end
    self:SetText("")
    self:ClearFocus()
  end)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  local hint = ns.UI.Text(eb, 11, LOOK.dim)
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

ns.ToggleMessenger = function()
  if messenger and messenger:IsShown() then messenger:Hide() else OpenMessenger() end
end

-- add one message to a conversation; from = "them" or "me"
ns.RecordWhisper = function(full, from, msg)
  if not On("whisperWindow") or not full or not msg then return end
  local c = ns.DB.convos[full]
  if not c then c = { msgs = {}, unread = 0 }; ns.DB.convos[full] = c end
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
