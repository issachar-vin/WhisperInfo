# Who Are You People?

**Know who's whispering you before you invite them.**

Who Are You People? puts the sender's level, class and guild in front of every whisper, so you can fill dungeon groups without guessing. Click a name for a full player card, keep every conversation in one window, and let the addon grey out gold-seller spam. All of it is set up in a settings page with a live preview.

---

## Features

### Whisper tag
Every whisper starts with a tag like **[Lvl 24 Paladin <Night Watch> [who] [armory]]**.

- **Level**, coloured like quest difficulty: grey and green are below you, yellow is close, orange and red are above.
- **Class** in class colour, shown straight away for everyone.
- **Guild** in green, or nothing if they're not in one.
- **[who]** opens the player card. **[armory]** gives you their Armory link to copy.
- Optionally show [who] and [armory] as small icons instead of words.
- Works on Battle.net whispers too.

Friends, guildmates, group members and anyone you target or mouse over are known instantly. Strangers are looked up automatically on your next click in the game world. Everything the addon learns is saved, so repeat whisperers show their full tag at once.

### Player card
Click [who] or type `/wi Name` to see everything the game can tell you about a player:

- Level, race, class, guild, and guild rank (for guildmates or players near you)
- Current zone, online status and faction
- Whether they're a guildmate, friend, Battle.net friend, ignored or a stranger
- Your friend note or their guild note
- How many times they've whispered you, when they last did, and when they first did

The card has buttons to **Whisper**, **Invite**, **Armory**, **Look up again** and **Set role**.

### Whispers window
Every whisper conversation in one window, saved between sessions.

- A conversation list with class icons, class-coloured names and unread counts
- Time-stamped messages with clickable item links, and up to 150 messages of history per person
- A header showing their level, class, guild and zone, with Card and Invite buttons
- A reply box: type and press Enter to whisper back
- Optional: pop the window open on new whispers, or take whispers out of normal chat entirely

### Class and role icons
- **Class icons** in front of messages in whispers, say/yell, guild/officer, party/raid/instance and General/Trade/LFG channels. Each chat type has its own switch.
- **Role icons** (tank, healer, DPS) in party and raid chat. Roles come from the game's role check, from a role you set yourself, or from the class when it can only deal damage. Hybrid classes never get a wrong guess.

### Spam flag
Whispers from strangers that look like gold sellers are greyed out with a **[likely spam]** label, or hidden completely if you prefer.

- Flags low-level strangers (level 1–5) and whispers containing websites, $ prices or gold-selling words
- Never flags friends, Battle.net friends, guildmates or group members
- Click **[not spam]** to clear a real player for good

### UI styles
Pick the look that matches the rest of your UI. There are four UI styles matching EllesmereUI's: **WoW Forever** (the game's own Forever windows, the default), **EllesmereUI** (flat and dark), **Classic WoW UI** (the original vanilla frames and buttons) and **Blizzard (Retail)**. On the Forever client, Blizzard (Retail) still draws Forever's frame art for now. Changing the style reloads the UI, just like EllesmereUI. EllesmereUI doesn't need to be installed, but the flat style uses its font when it is.

### Settings with live preview
Every feature has its own on/off switch, grouped into collapsible sections. Sample chat lines at the top redraw as you change settings, so you see exactly what changes. Main switches turn a whole feature off while keeping your sub-settings, and a **Restore defaults** button puts everything back.

### Minimap button
- **Left-click:** settings
- **Right-click:** player card for whoever whispered you last
- **Shift-click or middle-click:** Whispers window
- **Drag:** move it around the minimap

---

## Commands

All commands start with `/wi` (or `/wayp`). Names can be typed in lowercase.

| Command | What it does |
|---|---|
| `/wi` | Shows the list of commands |
| `/wi config` | Opens the settings |
| `/wi Name` | Opens the player card and looks them up |
| `/wi whispers` (`/wi w`) | Opens or closes the Whispers window |
| `/wi list` | The last 10 people who whispered you |
| `/wi armory Name` | Shows that player's Armory link |
| `/wi role tank` / `heal` / `dps` / `clear` | Sets your target's party role (add a name, or `me`) |
| `/wi notspam Name` | Never flags that player as spam again |
| `/wi icons` | Turns class icons in chat on or off |
| `/wi minimap` | Shows or hides the minimap button |
| `/wi reset` | Forgets every saved player |

---

## Limits

These come from the game, and no addon can get around them:

- `/who` only finds players on your own faction, so the other faction's level and guild stay unknown.
- The game allows about one `/who` every 5 seconds, so a burst of whispers is looked up over your next few clicks.
- During some boss encounters the game hides whisper contents from addons, so those whispers show without a tag.
- Addons can't inspect the gear or talents of players who aren't near you. Use the [armory] link for that.
- Characters only appear on the Armory from level 10.

---

## Feedback

Found a bug or have an idea? Open an issue on [GitHub](https://github.com/issachar-vin/WhoAreYouPeople/issues) with the error text and what you were doing when it happened. Use `/console scriptErrors 1` or BugSack to capture Lua errors.
