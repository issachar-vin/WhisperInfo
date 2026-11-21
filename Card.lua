-- Who Are You People?: the player card and the Armory link copy box.
local ADDON, ns = ...
local ClassColored = ns.ClassColored
local Display = ns.Display
local GRAY = ns.GRAY
local Gather = ns.Gather
local LOOK = ns.LOOK
local ROLE_NAME = ns.ROLE_NAME
local RoleIcon = ns.RoleIcon
local SendWhoFor = ns.SendWhoFor
local ShortName = ns.ShortName
local waitingWho = ns.waitingWho

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
    local w = ns.UI.Window("WhoAreYouPeopleArmory", 460, 118, "Armory link", "DIALOG")
    w:SetPoint("CENTER", 0, 120)
    w.text = ns.UI.Text(w, 12, LOOK.dim)
    w.text:SetPoint("TOPLEFT", 18, -42)
    w.text:SetPoint("RIGHT", -18, 0)
    w.text:SetJustifyH("LEFT")
    local eb = ns.UI.Input(w)
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
  return ns.UI.Button(parent, text, w or 92, 22)
end

local function BuildCard()
  card = ns.UI.Window("WhoAreYouPeopleCard", 320, 392, "Who Are You People?", "DIALOG")
  card:SetPoint("CENTER", UIParent, "CENTER", 260, 40)

  card.icon = card:CreateTexture(nil, "ARTWORK")
  card.icon:SetSize(44, 44)
  card.icon:SetPoint("TOPLEFT", 16, -42)

  card.name = ns.UI.Text(card, 16)
  card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -2)
  card.name:SetPoint("RIGHT", -14, 0)
  card.name:SetJustifyH("LEFT")

  card.sub = ns.UI.Text(card, 12)
  card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
  card.sub:SetPoint("RIGHT", -14, 0)
  card.sub:SetJustifyH("LEFT")

  ns.UI.Decorate(card, "rule", { 14, -96 }, { -14, -96 })

  card.rows = {}
  local y = -104
  for i, label in ipairs(CARD_ROWS) do
    ns.UI.Decorate(card, "stripe", { 12, y + 3 }, { -12, y + 3 }, i)
    local l = ns.UI.flat and ns.UI.Text(card, 11, LOOK.dim) or ns.UI.Text(card, 11, nil, "GameFontNormalSmall")
    l:SetPoint("TOPLEFT", 18, y)
    l:SetWidth(84); l:SetJustifyH("LEFT")
    l:SetText(label)
    local v = ns.UI.Text(card, 11)
    v:SetPoint("TOPLEFT", 104, y)
    v:SetPoint("RIGHT", -16, 0)
    v:SetJustifyH("LEFT"); v:SetWordWrap(false)
    card.rows[label] = v
    y = y - 20
  end

  card.status = ns.UI.Text(card, 11, LOOK.dim)
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
    if GetTime() - ns.lastWho < 5 then
      card.status:SetText("/who needs a few seconds between lookups.")
    else
      SendWhoFor(card.full, ns.OPT.hideWhoLines)
      ns.RefreshCard(card.full)
    end
  end)

  local roleBtn = CardButton(card, "Set role", 143)
  roleBtn:SetPoint("LEFT", refresh, "RIGHT", 6, 0)
  roleBtn:SetScript("OnClick", function()
    local cur = ns.DB.roles[card.full]
    local nextRole = "TANK"
    if cur == "TANK" then nextRole = "HEALER" elseif cur == "HEALER" then nextRole = "DAMAGER"
    elseif cur == "DAMAGER" then nextRole = nil end
    ns.DB.roles[card.full] = nextRole
    ns.RefreshCard(card.full)
  end)
  card:Hide()
end

ns.RefreshCard = function(full)
  if not card or not card:IsShown() or card.full ~= full then return end
  local e = ns.DB.players[full] or {}
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
  local role = ns.DB.roles[full]
  R["Party role"]:SetText(role and ((RoleIcon(role) or "") .. " " .. ROLE_NAME[role]) or GRAY .. "not set|r")
  R["Whispers"]:SetText(tostring(e.whispers or 0) .. (e.seen and (GRAY .. "  (last " .. Ago(e.seen) .. ")|r") or ""))
  R["First whisper"]:SetText(e.firstSeen and date("%b %d, %Y", e.firstSeen) or GRAY .. "-|r")

  card.status:SetText(waitingWho[full] and "Asking the server with /who..." or "")
end

ns.ShowCard = function(full)
  if not card then BuildCard() end
  Gather(full, ns.DB.players[full] and ns.DB.players[full].guid)
  card.full = full
  card:Show()
  ns.RefreshCard(full)
end

-- shared with the other files
ns.Invite = Invite
ns.ShowArmory = ShowArmory
