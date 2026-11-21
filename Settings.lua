-- Who Are You People?: the settings window, its live preview, and the button in the game's options.
local ADDON, ns = ...
local AccentHex = ns.AccentHex
local BACKDROP = ns.BACKDROP
local ClassIcon = ns.ClassIcon
local DEFAULTS = ns.DEFAULTS
local Describe = ns.Describe
local GRAY = ns.GRAY
local LOOK = ns.LOOK
local On = ns.On
local PARENT = ns.PARENT
local Print = ns.Print
local RoleIcon = ns.RoleIcon
local STYLES = ns.STYLES
local SpamLink = ns.SpamLink
local StyleByKey = ns.StyleByKey
local TagFor = ns.TagFor
local guidToName = ns.guidToName

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
  if ns.OPT.printLookups then
    lines[#lines + 1] = AccentHex() .. "Who Are You People?|r Addled Ark is " .. Describe(sample) .. GRAY .. " in Westfall|r" ..
      GRAY .. (ns.OPT.autoWho and "   (after your next click)|r" or "   (after you click [who])|r")
  else
    lines[#lines + 1] = GRAY .. "(lookup results fill in the tag and card, no chat line)|r"
  end

  -- 3) a spam whisper
  local spamMsg = "cheap gold, www.example.com"
  local why = ns.OPT.spamFlag and ((On("spamLevel") and "Lvl 1") or (On("spamWords") and "link or sales words"))
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
  lines[#lines + 1] = GRAY .. "Minimap button: |r" .. (ns.OPT.minimap and "|cff40ff40shown|r" or "|cffff6060hidden|r") ..
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
local settingsCategory

StaticPopupDialogs["WHOAREYOUPEOPLE_RELOAD"] = {
  text = "Who Are You People? switches to the %s style after a UI reload. Reload now?",
  button1 = RELOADUI or "Reload",
  button2 = LATER or "Later",
  OnAccept = function() ReloadUI() end,
  timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- The game's AddOns options page only holds a button that opens our own window.
local function BuildOptionsStub(open)
  local stub = CreateFrame("Frame")
  stub.name = "Who Are You People?"
  local title = stub:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("Who Are You People?")
  local text = stub:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  text:SetPoint("RIGHT", -16, 0)
  text:SetJustifyH("LEFT")
  text:SetText("The settings have their own window. You can also open it with /wi config or by shift-clicking the minimap button.")
  local b = CreateFrame("Button", nil, stub, "UIPanelButtonTemplate")
  b:SetSize(160, 24)
  b:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -12)
  b:SetText("Open settings")
  b:SetScript("OnClick", open)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    settingsCategory = Settings.RegisterCanvasLayoutCategory(stub, "Who Are You People?")
    Settings.RegisterAddOnCategory(settingsCategory)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(stub)
  end
end

local function BuildSettings()
  local w = ns.UI.Window("WhoAreYouPeopleSettings", 640, 600, "Who Are You People? Settings", "DIALOG")
  w:SetPoint("CENTER")
  w:Hide()
  ns.settingsWindow = w
  local panel = CreateFrame("Frame", nil, w)
  panel:SetPoint("TOPLEFT", 8, -28)
  panel:SetPoint("BOTTOMRIGHT", -8, 8)
  ns.settingsPanel = panel

  local sub = ns.UI.Text(panel, 11, LOOK.dim)
  sub:SetPoint("TOPLEFT", 12, -14)
  sub:SetText("Every feature has its own switch. Changes apply straight away.")

  -- UI style: takes effect after a reload, like EllesmereUI's style picker
  local styleDD = ns.UI.Dropdown(panel, 190, STYLES, function() return StyleByKey(ns.OPT.uiStyle) end, function(style)
    if style.key == ns.OPT.uiStyle then return end
    ns.OPT.uiStyle = style.key
    panel.UpdatePreview()
    StaticPopup_Show("WHOAREYOUPEOPLE_RELOAD", style.name)
  end)
  styleDD:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -8)
  local styleLabel = ns.UI.Text(panel, 12, LOOK.dim)
  styleLabel:SetPoint("RIGHT", styleDD, "LEFT", -8, 0)
  styleLabel:SetText("UI style")
  local styleNote = ns.UI.Text(panel, 11, LOOK.dim)
  styleNote:SetPoint("TOPRIGHT", styleDD, "BOTTOMRIGHT", 0, -4)

  -- preview, fixed at the top so it stays in view while you scroll the switches
  local head = ns.UI.Text(panel, 13)
  head:SetPoint("TOPLEFT", 14, -52)
  head:SetText("Preview")
  local headSub = ns.UI.Text(panel, 11, LOOK.dim)
  headSub:SetPoint("LEFT", head, "RIGHT", 8, 0)
  headSub:SetText("updates as you click")

  local box = CreateFrame("Frame", nil, panel, BACKDROP)
  box:SetPoint("TOPLEFT", 10, -70)
  box:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
  box:SetHeight(6 * 20 + 16)
  ns.UI.Panel(box, 0.75)
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
  local scroll, content = ns.UI.Scroll(panel)
  scroll:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -8)
  scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)

  panel.boxes = {}
  local function Refresh()
    for key, cb in pairs(panel.boxes) do
      cb:SetChecked(ns.OPT[key])
      local parent = PARENT[key]
      local enabled = parent == nil or On(parent)
      if enabled then cb:Enable() else cb:Disable() end
      cb.label:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
    end
    styleDD:Refresh()
    styleNote:SetText(ns.OPT.uiStyle ~= ns.UI.key and ("Now: " .. StyleByKey(ns.UI.key).name .. ". Reload to switch.") or "")
    local lines = PreviewLines()
    for i, fs in ipairs(box.lines) do fs:SetText(lines[i] or "") end
    if panel.Layout then panel.Layout() end
  end
  panel.UpdatePreview = Refresh

  -- collapsible sections: click a header to open or close it
  ns.DB.openSections = ns.DB.openSections or { ["Whisper tag"] = true }
  local headers, Layout = {}, nil

  for _, section in ipairs(SECTIONS) do
    local hb = CreateFrame("Button", nil, content)
    hb:SetSize(540, 22)
    ns.UI.SectionHeader(hb)
    hb.title:SetText(section.title)
    hb.section, hb.boxes = section, {}
    hb:SetScript("OnClick", function(self)
      ns.DB.openSections[section.title] = not ns.DB.openSections[section.title] or nil
      Layout()
    end)
    headers[#headers + 1] = hb

    for _, item in ipairs(section.items) do
      local indent = item.indent or (PARENT[item.key] and 1 or 0)
      local cb = ns.UI.Check(content, item.label, function(self)
        ns.OPT[item.key] = self:GetChecked() and true or false
        if item.key == "minimap" and ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
        Refresh()
      end)
      cb.indent = indent
      panel.boxes[item.key] = cb
      hb.boxes[#hb.boxes + 1] = { key = item.key, cb = cb }
    end
  end

  local defaults = ns.UI.Button(content, "Restore defaults", 150, 24)
  defaults:SetScript("OnClick", function()
    for k, v in pairs(DEFAULTS) do
      if k ~= "uiStyle" then ns.OPT[k] = v end   -- the style has its own picker and needs a reload
    end
    if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    Refresh()
  end)

  local reset = ns.UI.Button(content, "", 180, 24)
  reset:SetPoint("LEFT", defaults, "RIGHT", 8, 0)
  reset:SetText("Forget all saved players")
  reset:SetScript("OnClick", function()
    wipe(ns.DB.players); wipe(guidToName); Print("Saved players cleared.")
  end)

  Layout = function()
    local y = -4
    for _, hb in ipairs(headers) do
      local open = ns.DB.openSections[hb.section.title]
      hb:ClearAllPoints()
      hb:SetPoint("TOPLEFT", 4, y)
      hb:SetOpen(open)
      local on = 0
      for _, b in ipairs(hb.boxes) do if ns.OPT[b.key] then on = on + 1 end end
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
end

-- Our own window: opening it leaves the Whispers window alone, and it closes
-- the game's options window if the "Open settings" button was used.
local function OpenSettings()
  if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel)
  elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then HideUIPanel(InterfaceOptionsFrame) end
  ns.settingsWindow:Show()
  ns.settingsWindow:Raise()
end

-- shared with the other files
ns.BuildOptionsStub = BuildOptionsStub
ns.BuildSettings = BuildSettings
ns.OpenSettings = OpenSettings
