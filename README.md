# MGE-VScript
A fully vanilla compatible rewrite of the MGEMod plugin.  No sourcemod plugins required.

The goal of this project is to create a drop-in replacement for the SM version for better long term support/stability, ease of use, and generally expanding on the gamemode in ways that were prohibitively complicated before.  PRs and Issues are more than welcome.

The biggest obstacle that obviously cannot be worked around is the lack of a proper database connector.  If stat tracking is set to database mode, this gamemode copes by using an external python script to move data from disk to database.  You should be EXTREMELY careful about using this alongside untrusted maps/scripts, see below to avoid malicious maps/scripts from tampering with player stats.

## Installation
- Drop the `mapspawn.nut` file and mge folder in your `tf/scripts/vscripts` directory.  That's it
  - If you know github/git, I recommend cloning the repository to this directory so you're always up to date.

## Don't pack this into your map
- I generally don't recommend you do this, this will receive live regular updates like a sourcemod plugin, and will conflict with server configs
- If you must pack this into your map, you should modify it so it loads in a way that it doesn't override any existing mge scripts on the server


## Configuration/Modifying game rules
- Most arena rules can be configured at the top of the `mge/cfg/config.nut` file
  
## Features & Progress

| Feature | Status |
|---------|--------|
| [Legacy map support](https://github.com/sapphonie/MGEMod/blob/master/addons/sourcemod/configs/mgemod_spawns.cfg) | ✅ |
| Endif | ✅ |
| Ammomod | ✅ |
| Infammo | ✅ |
| 4Player | ✅ |
| Turris | ✅ |
| BBall | ✅ |
| Allmeat | ✅ |
| Koth | ⚠️ |
| Midair? |⚠️|
| Ultiduo | ❌ |
| Plain text ELO/stat tracking | ✅ |
| Quake-style announcer lines (toggleable) | ✅ |
| Localization | ⚠️ |
| NavMesh Generation | ⚠️ |
| Database tracking (MySQL) | ✅ |
| Database tracking (SQLite) | ⚠️ |
| Custom rulesets | ⚠️ |
| Arbitrary team sizes | ❌ |
| Custom spawn ordering | ❌ |
| In-Game map configuration tool | ❌ |

⚠️KOTH works but the logic is super janky right now, is Turris even that popular?

⚠️I have never played midair and am only going off of what the plugin describes (same as endif but no height threshold?), it might not be faithful to the original thing

⚠️Theres a few AI translations in here. PRs fixing the AI translations listed in `mge/cfg/localization.nut`  would be appreciated

⚠️See below for navmesh warning, tl;dr it's very slow and will still generate bad navs on the more abstract arenas (oihguv, chillypunch, etc)

⚠️The SQLite stuff should work fine but is untested.

⚠️Ruleset voting exists but is very janky, doesn't clean itself up correctly, and is disabled by default.

## Converting your map configs
- Open a copy of `mgemod_spawns.cfg` in VSCode/NP++/any text editor that supports regex search/replace, enable regex
- If you're confused, Google/ask your favorite AI chat bot how to enable regex search/replace in your text editor

    - Find pattern: `(\s*)"([^"]+)"\s*\n\s*\{`
    - Replace pattern: `$1"$2": {`
    - Replace All
- Then:
    - Find pattern: `(\s*)"([^"]+)"\s+"([^"]+)"`
    - Replace pattern: `$1"$2": "$3"`
    - Replace All

- **CUSTOM MAPS NEED TO BE INDEXED MANUALLY!** See the `mge/cfg/mgemod_spawns.nut` file for an example of how to index your map
    - Failing to index your maps will result in !add being unordered, rendering everyone's !add binds useless

## Known bugs/limitations
- KOTH in general is a bit jank
- Custom ruleset spawns do not rotate correctly
- The BBall flag can sometimes not drop if you kill the player as soon as they pick it up, they will still have it on respawn.

## Adding new BBall/Koth/etc spawns:
- BBall, Koth, and other "specialty" modes still supports reading hoop/koth point/ball spawn points/etc using the old method for backwards compatibility
- The old system requires exactly 8 spawns on BBall and 6 on KOTH, with the other indexes being used for arena logic.
- This isn't strictly necessary anymore, these arenas can now support any arbitrary number of spawn points (just make sure the number of spawns is divisible by 2)
- If you'd like to modify spawn points for these arenas, see `constants.nut` and search for `BBALL_MAX_SPAWNS` to see how it works.

## New optional arena keyvalues:
If not specified, the default values can be found in `cfg/config.nut`

- `countdown_sound` - the sound played when the countdown starts
- `countdown_sound_volume` - the volume of the countdown sound
- `round_start_sound` - the sound played when the round starts
- `round_start_sound_volume` - the volume of the round start sound

- **BBall:**
- Index 9-13 in the plugin spawn config can be optionally replaced with the following keyvalues:
    - `bball_home` - the spawn point of the neutral home
    - `bball_home_red` - the spawn point of the red home
    - `bball_home_blue` - the spawn point of the blue home
    - `bball_hoop_red` - the spawn point of the red hoop
    - `bball_hoop_blue` - the spawn point of the blue hoop

- `bball_hoop_size` - the radius of the hoop in hammer units
- `bball_pickup_model` - the model of the ball pickup
- `bball_pickup_sound` - the sound of the ball pickup
- `bball_particle_pickup_red` - the particle effect of the ball pickup for the red team
- `bball_particle_pickup_blue` - the particle effect of the ball pickup for the blue team
- `bball_particle_pickup_generic` - the particle effect of the ball pickup for both teams
- `bball_particle_trail_red` - the particle effect applied to players on pickup for the red team
- `bball_particle_trail_blue` - the particle effect applied to players on pickup for the blue team

- **Koth:**

- `koth_cap` - the spawn point of the capture point
    - If this is not specified, the last index in the map spawn config will be used as the capture point
- `start_time_red` - the time at which the red team can start capturing the point in seconds, defaults to KOTH_START_TIME_RED in `cfg/config.nut`
- `start_time_blu` - the time at which the blue team can start capturing the point in seconds, defaults to KOTH_START_TIME_BLUE in `cfg/config.nut`
- `koth_capture_point_radius` - the radius of the capture point in hammer units, defaults to KOTH_CAPTURE_POINT_RADIUS in `cfg/config.nut`
- `koth_capture_point_max_height` - the maximum height of the capture point in hammer units, defaults to KOTH_CAPTURE_POINT_MAX_HEIGHT in `cfg/config.nut`
- `koth_decay_rate` - the rate at which the capture point decays when not being capped in seconds, defaults to KOTH_DECAY_RATE in `cfg/config.nut`
- `koth_decay_interval` - the interval at which the capture point decays in seconds, defaults to KOTH_DECAY_INTERVAL in `cfg/config.nut`
- `koth_additive_decay` - the additive decay rate of the capture point, defaults to KOTH_ADDITIVE_DECAY in `cfg/config.nut`
- `koth_countdown_rate` - the rate at which the capture point counts down in seconds, defaults to KOTH_COUNTDOWN_RATE in `cfg/config.nut`
- `koth_countdown_interval` - the interval at which the capture point counts down in seconds, defaults to KOTH_COUNTDOWN_INTERVAL in `cfg/config.nut`
- `koth_partial_cap_rate` - the rate at which the capture point is capped in seconds, defaults to KOTH_PARTIAL_CAP_RATE in `cfg/config.nut`
- `koth_partial_cap_interval` - the interval at which the capture point is capped in seconds, defaults to KOTH_PARTIAL_CAP_INTERVAL in `cfg/config.nut`


## New Arena Type: Allmeat
- Allmeat is a mode that only registers damage if your shot deals `allmeat_damage_threshold`%+ of the weapon's max damage, intended for scattergun/shotgun training.
- `allmeat_damage_threshold` - the minimum damage % compared to max theoretical damage, defaults to ALLMEAT_DAMAGE_THRESHOLD in `cfg/config.nut`
    - settings this to 1.0 will require 100% perfect shots, setting this to 0.0 will disable it, default is 0.85.
- the ALLMEAT_MAX_DAMAGE table in `cfg/config.nut` contains the hardcoded max damage values for each weapon.  This table also doubles as a whitelist for which weapons are affected by allmeat.
- Add `"allmeat" : "1"` to the arena config to enable, or turn any MGE arena into an allmeat arena by typing !ruleset allmeat.
- allmeat is fun to type.  allmeat allmeat allmeat


## Chat Commands

All chat commands can be prefixed with any of these characters: `/\.!?`

| Feature | What it do
|---------|--------|
| add | Add yourself to a given arena index
| remove | Remove yourself from the arena you are currently in 
| stats | view your stats breakdown
| ruleset | Vote to change the current arenas ruleset, for example enabling endif or ammomod
| addbots/removebots | add/remove training bots from arena

## ELO/Stat Tracking
### SECURITY WARNING
Support [This github issue](https://github.com/ValveSoftware/Source-1-Games/issues/6356).
- While most existing MGE maps are safe to use, **DO NOT ENABLE ANY STAT TRACKING ON UNTRUSTED MAPS!**
    - Any MGE maps created after the VScript update can pack a mapspawn.nut file that will override ours
    - Not only will this break the gamemode, but malicious maps can target either the database or filesystem and manipulate player stats
    - This cannot be fixed unless Valve implements another reserved file (i.e. init.nut) that runs before mapspawn.nut and can only run from the server filesystem
    - **How to check if a map is safe:**
        - Open the bsp using GCFScape, open the .zip file, and check the tf/scripts/vscripts directory in this zip file
        - If you see a mapspawn.nut file, the gamemode will either not load correctly or this map is unsafe
        - If you see any other packed script files, Ctrl+F and search for `StringToFile` or `FileToString` in every script file, if you see any of these, the map is potentially unsafe
        - Search for `__MGE__VPI`.  If this shows up anywhere, the map is attempting to tamper with the database 

### Plain Text
- perfect option for MGE servers running on a single physical server
- player stats are tracked in the `tf/scriptdata/mge_playerdata` directory indexed by steamid.
- No leaderboard support currently.

### Database
- Database tracking uses [VScript-Python Interface](https://github.com/potato-tf/VPI) to send data from vscript to python through the filesystem.
    - Install Python 3.10 or newer if you don't already have it
    - Install MySQL (recommended) or SQLite
    - Install the `aiomysql` module
        - SQLite uses `aiosqlite`
    - Add your database credentials to `tf/scripts/mge_python/vpi.py` and run this script constantly in the background, this is your database connection
        - You should create a systemd service for this on linux, or whatever the windows equivalent is
    - Check server console for any VPI related errors when you join/leave the server.
    - This will automatically create the `mge_playerdata` table in your database
 
## GitHub Auto Updates
- If configured in `cfg/constants.nut`, the python script that handles database connections will also periodically git clone this repo to a specified directory and shorten the map restart timer.  

## NavMesh generation

Included is a tool to generate a navmesh for every arena on a given map.  Load any map you want to generate a navmesh for in singleplayer, enable cheats, and paste this into console

`ent_fire bignet CallScriptFunction "MGE_CreateNav"`

Or for only one arena:

```ent_fire bignet RunScriptCode "MGE_CreateNav(`Badlands Middle`)"```

### **WARNING:
- This is very slow and will freeze your game for every arena
- More "abstract" arenas (such as the ones on oihguv or chillypunch) will generate nav squares where you may not want them, and will take forever to generate.  Both oihguv and triumph take 30+ mins for every arena.  You have been warned.

## Localization
- Localization files are automatically detected by `cl_language` for per-player language settings, if a string is not localized it will default back to the DEFAULT_LANGUAGE constant.
- **Some translations are machine translated**, please submit pull requests to fix any bad ones.

## Credits
*Localization credits can be found at the top of `mge/cfg/localization.nut`*
- Braindawg - Most of it.
- Mince - (VPI), misc cleanup, bot stuff.
- [MGEMod](https://github.com/sapphonie/MGEMod) - The most recent version of the original MGEMod plugin.
- CPrice, Lange - Original MGEMod/Ammomod developers.
