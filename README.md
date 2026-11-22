# Who Are You People?

A WoW Forever addon that tells you who is whispering you before you invite them. It is built for picking up players for dungeons without guessing.

The name comes from the SpongeBob *"Who are you people?"* meme, which is exactly how it feels when strangers start whispering you.

- **Whisper tag:** every whisper starts with the sender's level, class and guild, e.g. `[Lvl 24 Paladin <Night Watch> [who] [armory]]`.
- **Player card:** click `[who]` to open a window with everything the game can tell you about that player, plus Whisper, Invite and Armory buttons.
- **Class icons:** a class icon in front of messages, switchable per chat type (whispers, say, guild, party/raid, channels).
- **Role icons:** a tank, healer or DPS icon in party and raid chat.
- **Whispers window:** every whisper conversation in one window, Battle.net whispers included, with history and a reply box.
- **Spam flag:** greys out or hides likely gold-seller whispers from strangers.
- **Armory link:** one click gives you the player's Forever Armory page to copy into your browser.
- **Settings with live preview:** every feature has its own on/off switch, in collapsible sections. They open in their own window with `/wi config` or a shift-click on the minimap button.
- **UI styles:** four UI styles matching EllesmereUI's: **WoW Forever** (the game's own Forever windows, the default), **EllesmereUI** (flat and dark), **Classic WoW UI** (the original vanilla frames and buttons) and **Blizzard (Retail)**. On the Forever client, Blizzard (Retail) still draws Forever's frame art for now.
- **Memory:** everything it learns is saved, so people who whisper you again show their full tag straight away.

## Installing

1. Download this repo (**Code → Download ZIP**).
2. In Battle.net, select WoW Forever, click the gear icon next to Play, and choose **Show in Explorer**.
3. Open `Interface\AddOns\`. If either folder is missing, create it with that exact spelling.
4. Extract the zip there and rename the folder to `WhoAreYouPeople`. You should have `Interface\AddOns\WhoAreYouPeople\` holding `WhoAreYouPeople.toc` and `WhoAreYouPeople.lua`, not a folder nested inside another.
5. Start the game. On the character screen, click **AddOns** and tick **Who Are You People?**. If it says out of date, tick **Load out of date AddOns**.
6. In game, type `/wi`. You should see the list of commands.

To update, delete the old `WhoAreYouPeople` folder first, extract the new one, then type `/reload`. Your saved players are kept.

**Coming from WhisperInfo?** Delete the old `WhisperInfo` folder and install `WhoAreYouPeople` as above. To keep your saved players, settings and whisper history, close the game, go to `WTF\Account\<your account>\SavedVariables\` in the Forever folder, and copy `WhisperInfo.lua` to a new file named `WhoAreYouPeople.lua` in the same place.

## Reading the whisper tag

The tag in front of a whisper shows what the addon knows about the sender: `[Lvl 24 Paladin <Night Watch> [armory]]`.

| Part | What it means |
|---|---|
| `Lvl 24` | Their level, coloured like quest difficulty: grey and green are below you, yellow is close, orange and red are above. `Lvl ?` means not known yet. |
| `Paladin` | Their class, in class colour. This shows up straight away for everyone. |
| `<Night Watch>` | Their guild, in green. Nothing shown means they are not in a guild. |
| `[who]` | Click it to open the player card and look them up again. |
| `[armory]` | Click to open a box with their Armory link. Press Ctrl+C and paste it into your browser. |

Each part of the tag (level, level colour, class, guild, `[who]`, `[armory]`) has its own switch in settings. Turn on **Show [who] and [armory] as icons** to swap the words for a small spyglass and chest-armor icon. Both stay clickable.

**Where the level and guild come from:**

- **Straight away:** friends, Battle.net friends on that character, guildmates, group members, and anyone you target or mouse over.
- **Everyone else:** the addon looks them up on your next click in the game world (moving, turning the camera, clicking a mob) and prints a line like *Addled Ark is Lvl 24 Paladin \<Night Watch\>*. Clicks on menus or action bars don't count.
- **Saved:** once known, the level and guild show on every later whisper from that person.

## Player card

Click `[who]` on any whisper, or type `/wi Name`, to open a window with everything the game can tell you about that player. It also runs a fresh lookup. Drag it to move it; Esc closes it.

| Row | What it shows |
|---|---|
| Name and title line | Name in class colour, then level, race and class, with the class icon. |
| Guild | Their guild in green, or None. |
| Guild rank | Only for your own guildmates or someone near you. The game doesn't share it otherwise. |
| Zone | Where they are right now. |
| Status | Online, Looking up..., Not found (offline or other faction), or when they were last seen. |
| Faction | Alliance or Horde. Handy on the PvP ruleset. |
| Known as | Guildmate, Friend, Battle.net friend, Ignored, or Stranger. |
| Note | Your friend note or their guild note. |
| Party role | The role you set for them. |
| Whispers | How many times they've whispered you, and when last. |
| First whisper | The date they first whispered you. |

**Buttons:**

- **Whisper** starts a reply to them.
- **Invite** invites them to your group.
- **Armory** opens the copy box with their Armory link.
- **Look up again** refreshes the card. The game needs about 5 seconds between lookups.
- **Set role** steps through Tank, Healer, DPS and none. The role then shows in party chat.

## Whispers window

The Whispers window keeps every whisper conversation in one window, saved between sessions, including Battle.net whispers. Open it by left-clicking the minimap button, or with `/wi whispers` (short: `/wi w`). Opening the settings leaves it open. Drag the title bar to move it, or the bottom-right corner to resize it; it remembers both. Esc leaves it open: close it with its X, the minimap button or `/wi w`.

- **Conversation list (left):** everyone you've whispered with, newest first, with class icon (or a Battle.net icon), class-coloured name and an unread count. Click a name to open the conversation. Right-click it to remove that conversation.
- **Conversation (right):** time-stamped messages from both sides. Item links stay clickable, and the mouse wheel scrolls back through up to 150 messages per person.
- **Header:** their level, class, guild and zone, with **Card** (opens the player card) and **Invite** buttons. For a Battle.net friend it shows what they're playing; Card and Invite appear while they're on a WoW Forever character.
- **Reply box:** type at the bottom and press Enter to whisper back. Replies to Battle.net friends go out as Battle.net whispers.
- **Spam:** whispers flagged as spam are left out of the window.

The *Whisper window* settings section controls it:

| Setting | Default | What it does |
|---|---|---|
| Keep whispers in the Whispers window | On | Main switch. Off = no window and no saved history. |
| When someone whispers you | Do nothing | **Do nothing**, **Open the Whispers window**, or **Show a toast**: a small notice with their name and message. Click the toast to open the Whispers window on that conversation, right-click to dismiss it. A newer whisper replaces it and shows *+1 more*. Nothing pops up while the Whispers window is already open. |
| Toast stays for | 8 seconds | 4, 8 or 15 seconds, or until clicked. Hovering keeps it up. |
| Move the toast | | Shows a blue box you drag to where toasts appear. It also shows in the game's Edit Mode, and `/wi toast` does the same. |
| Take whispers out of the normal chat window | Off | Whispers, yours and theirs, only appear in the Whispers window. |

Battle.net conversations are saved by BattleTag, so they stay together between sessions.

## Settings

Every feature has its own on/off switch. The settings have their own window, drawn in your UI style. Open it with `/wi config`, a shift-click (or middle-click) on the minimap button, or the **Open settings** button under Game Menu → Options → AddOns → Who Are You People?. Opening it doesn't close the Whispers window. Changes apply straight away.

- **Preview:** sample chat lines at the top redraw every time you change a setting, so you see the result before closing the window.
- **Sections:** click a section header's **+** / **−** to open or close it. Closed headers show a count such as *5 of 9 on*. The page remembers which sections you leave open.
- **Main switches:** the first switch in a section turns that whole feature off. The indented switches under it grey out but keep their state, so turning the main switch back on restores your setup.
- **Buttons:** **Restore defaults** puts every switch back, and **Forget all saved players** clears the addon's memory.
- **UI style:** the dropdown at the top right sets the look of every Who Are You People? window: the player card, the Whispers window, the Armory copy box and the settings window. Pick a style and the addon asks to reload the UI, which is when the new look takes effect. The styles match EllesmereUI's: WoW Forever (the default), EllesmereUI, Classic WoW UI and Blizzard (Retail). **Restore defaults** leaves the style alone.

| Section | Switches |
|---|---|
| Whisper tag | Tag on/off · Level · Colour level by difficulty · Class · Guild · `[who]` link · `[armory]` link · Show links as icons · Tag Battle.net whispers |
| Lookups | Automatic lookup on your next click · `[who]` opens the player card · Print a line when a lookup finishes · Hide raw /who lines · Open the player card when someone whispers you |
| Class icons | Icons on/off · Whispers · Say and yell · Guild and officer · Party, raid and instance · General, Trade and other channels |
| Role icons | Icons on/off · Party chat · Raid chat |
| Spam | Flag on/off · Strangers at level 1–5 · Links, prices and gold-selling words · Hide instead of grey out |
| Other | Minimap button |
| Whisper window | Window on/off · When someone whispers you (nothing, open the window, toast) · Toast stays for · Move the toast · Take whispers out of normal chat |

## Chat icons

**Class icons** show in say, yell, guild, officer, party, raid, raid warnings, General/Trade/LFG channels and whispers. Type `/wi icons` to turn them on or off. Each chat type has its own switch in settings.

**Role icons** (tank, healer or DPS) show in party and raid chat. The addon decides each person's role in this order:

1. **The role picked in the game**, through a role check or the group frame's role menu.
2. **A role you set** with `/wi role`, for example `/wi role tank` for your target or `/wi role heal Addled Ark`. It is saved between sessions.
3. **Their class**, if it can only deal damage: mages, rogues, warlocks and hunters always show as DPS.

Warriors, druids, paladins, priests and shamans show no role icon until one of the first two applies, so the addon never labels a healer as a tank by mistake.

## Spam flag

Whispers that look like gold sellers are greyed out with a `[likely spam: …]` label. The addon only checks strangers: never friends, Battle.net friends, guildmates or group members.

A whisper is flagged when either rule matches, and each rule has its own switch:

- **Level 1–5:** the sender is a low-level stranger. A bot's first whisper often shows `Lvl ?`; once the lookup finds its level, you get a *likely spam* note, and later whispers from it are greyed out.
- **Links and sales words:** the whisper contains a website, a $ price, or words like *cheap gold* or *discount*. These are flagged straight away.

If a real player gets flagged, click **[not spam]** on their whisper or type `/wi notspam Name`. They won't be flagged again. In settings you can also **hide** spam completely instead of greying it out.

## Minimap button

The Who Are You People? button on the edge of your minimap gives quick access to the addon.

- **Left-click:** open or close the Whispers window.
- **Shift-click or middle-click:** open or close the settings.
- **Right-click:** open the player card for whoever whispered you last.
- **Drag:** move it around the minimap. It remembers where you put it.

Hide it with the *Minimap button* switch in settings or `/wi minimap`.

## Commands

All commands start with `/wi` (or `/wayp`, `/whoareyoupeople`). Names can be typed in lowercase.

| Command | What it does |
|---|---|
| `/wi` | Shows the list of commands. |
| `/wi config` | Opens the settings window (same as shift-clicking the minimap button). |
| `/wi Name` | Opens the player card for anyone, e.g. `/wi addled ark`, and looks them up. |
| `/wi list` | The last 10 people who whispered you, each with a `[who]` link. |
| `/wi armory Name` | Opens the copy box with that player's Armory link. |
| `/wi role tank` | Sets your target's party role. Use `heal`, `dps` or `clear` the same way. |
| `/wi role heal Name` | Sets a named player's role. Use `me` for yourself. |
| `/wi notspam Name` | Never flags that player as spam again. |
| `/wi icons` | Turns all class icons in chat on or off. |
| `/wi minimap` | Shows or hides the minimap button. |
| `/wi reset` | Forgets every saved player. |
| `/wi whispers` | Opens or closes the Whispers window (short: `/wi w`). |
| `/wi toast` | Shows or hides the box that places whisper toasts. |

## Limits

These limits come from the game, not the addon, and no addon can get around them.

- **Other faction:** `/who` only finds players on your own faction, so level and guild stay unknown for players on the other faction.
- **One lookup at a time:** the game allows a `/who` about every 5 seconds. If several people whisper at once, they are looked up over your next few clicks.
- **Boss fights:** during some instance encounters, the game hides whisper contents from addons. Those whispers show without a tag.
- **No remote inspect:** an addon can't see the gear or talents of someone who isn't near you. Use the `[armory]` link for that.
- **Armory:** characters only appear on the Armory from level 10.

Forever runs mega-servers with rulesets (PvP, RP PvP, PvE, RP) and no realm names. The addon uses character names as they are, with no realm added.

## Troubleshooting

| Problem | Fix |
|---|---|
| Addon shows as out of date | Tick **Load out of date AddOns**. For a lasting fix, type `/dump (select(4, GetBuildInfo()))` in game, then put that number in the `## Interface:` line of `WhoAreYouPeople.toc` and `/reload`. |
| Picked a new UI style but nothing changed | The style switches after a UI reload. Accept the reload prompt, or type `/reload`. |
| No tag on whispers at all | Check Who Are You People? is ticked in the AddOns list and type `/reload`. |
| `Lvl ?` never fills in | Click once in the game world (not a menu), or click `[who]`. If it still stays, they are probably on the other faction. |
| Icons show as `[T]`, `[H]`, `[D]` or blank squares | The game is missing that icon image. The letters are the backup and still work. |
| A Lua error pops up | Turn on errors with `/console scriptErrors 1` (or install BugSack), copy the error, and open an issue with it. |

Keep a copy of a working `WhoAreYouPeople` folder outside the game folder, so you can go back to it if an update causes trouble.

**Found a bug or have an idea?** Open an issue or contact quake_x1. Include the error text, your `WhoAreYouPeople.lua` file, and what you were doing when it happened.

## Development

The addon is split into one Lua file per feature. The `.toc` lists them in load order, and they share one namespace table (`local ADDON, ns = ...`):

| File | What's in it |
|---|---|
| `Core.lua` | shared state, saved-settings defaults, name and text helpers |
| `Styles.lua` | the four UI style kits |
| `Lookup.lua` | finding out who a player is, `/who`, party roles |
| `Chat.lua` | chat filters: whisper tag, class and role icons, spam flag, links |
| `Card.lua` | the player card and the Armory copy box |
| `Settings.lua` | the settings window, its preview, and the button in the game's options |
| `Minimap.lua` | the minimap button |
| `Whispers.lua` | the Whispers window and saved conversations |
| `Toast.lua` | the whisper toast and its anchor (Edit Mode or `/wi toast`) |
| `Events.lua` | events, loading saved data, `/wi` commands (loads last) |

- `make test` checks the syntax of every file, then loads the addon in a fake WoW environment (`tests/smoke.lua`) and fires every handler, once per UI style.
- `make release` runs the tests, then builds `release/WhoAreYouPeople-<version>.zip`. Pushing to `main` does the same on GitHub and publishes the zip as a release.

## Changelog

Newest changes first.

| Version | Date | Changes |
|---|---|---|
| 3.3.0 | Nov 22, 2026 | New whispers can show a toast instead: click it to open the Whispers window, with an adjustable duration and a position you set in Edit Mode or with `/wi toast`. The "Open the window when someone whispers you" switch is now the *When someone whispers you* choice (your setting is kept). New switch: open the player card when someone whispers you. |
| 3.2.1 | Nov 21, 2026 | Esc no longer closes the Whispers window; it still closes the settings, the player card and the Armory box. |
| 3.2.0 | Nov 21, 2026 | The Whispers window can be resized from its bottom-right corner and remembers its size. The conversation list shows as many people as fit. |
| 3.1.0 | Nov 21, 2026 | Settings open in their own window, drawn in your UI style, and no longer close the Whispers window; the game's AddOns options page has an **Open settings** button. Battle.net whispers are kept in the Whispers window, and replies there go out as Battle.net whispers. Minimap button: left-click now opens the Whispers window, shift-click the settings. The code is split into one file per feature. |
| 3.0.0 | Nov 21, 2026 | UI styles replace the colour themes: WoW Forever (default, the look from before 2.2.0), EllesmereUI (flat), Classic WoW UI and Blizzard (Retail). Changing the style reloads the UI. |
| 2.2.0 | Nov 21, 2026 | New EllesmereUI-style look for every window: flat dark panels, thin borders, on/off switches in settings, and a new Armory copy box. Each theme has its own background tint. The theme picker is now a dropdown. Uses EllesmereUI's font when it is installed. |
| 2.1.0 | Nov 21, 2026 | Themes: pick an accent colour matching EllesmereUI's themes from the top of the settings page. |
| 2.0.1 | Nov 21, 2026 | Minimap button shows the addon icon instead of the green question mark. |
| 2.0.0 | Nov 21, 2026 | Renamed from WhisperInfo to Who Are You People?. New folder name `WhoAreYouPeople` and new slash command `/wayp` (`/wi` still works). Addon icon in the AddOns list. |
| 1.7.1 | Nov 21, 2026 | Minimap button is now a green question mark, centred in the ring. |
| 1.7.0 | Nov 21, 2026 | New **Whispers window**: conversation list, saved history, reply box, Card and Invite buttons. New *Whisper window* settings section. |
| 1.6.0 | Nov 21, 2026 | `[who]` and `[armory]` can show as icons. Minimap button became a question mark. Settings sections now open and close (+ / −). |
| 1.5.0 | Nov 21, 2026 | Every feature got its own on/off switch, grouped into sections with main switches. Restore defaults button. |
| 1.4.1 | Nov 21, 2026 | Live preview of chat in the settings page. |
| 1.4.0 | Nov 21, 2026 | Spam flag for gold-seller whispers, with **[not spam]**. Minimap button for settings. |
| 1.3.2 | Nov 20, 2026 | Fixed a stray dash after every name (Forever has no realm names). |
| 1.3.1 | Nov 20, 2026 | Battle.net friends' names fixed; clearer guild-rank text on the card. |
| 1.3.0 | Nov 20, 2026 | Settings panel and the player card behind `[who]`. |
| 1.0–1.2 | Nov 14–20, 2026 | First versions: whisper tag with level, class and guild; `[armory]` link; automatic lookups; class icons in chat; role icons in party chat. |
