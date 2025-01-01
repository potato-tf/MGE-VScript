# MGE-VScript
A fully vanilla compatible rewrite of the MGEMod plugin.  No sourcemod plugins required.

## Features & Progress

| Feature | Status |
|---------|--------|
| [Legacy map support](https://github.com/sapphonie/MGEMod/blob/master/addons/sourcemod/configs/mgemod_spawns.cfg) | ✅ |
| Quake-style announcer lines (toggleable) | ✅ |
| Plain text ELO/stat tracking | ❌ |
| Database stat tracking support | ❌ |
| BBall | ❌ |
| 4Player | ❌ |
| Koth | ❌ |
| Arena leader system for custom rulesets | ❌ |
| Arbitrary team sizes | ❌ |
| Player-configurable spawn ordering | ❌ |
| In-Game map configuration tool | ❌ |

## Installation
- Drop the mapspawn.nut file and mge folder in your tf/scripts/vscripts directory.
- If you know github/git, I recommend cloning the repository to this directory so you're always up to date.

## Map Disclaimer
- We are accepting PRs for this, if your favorite map isn't indexed, please make a pull request!
- Arena indexing may not be correct on older/more obscure maps
    - What this means is your old !add binds will be wrong on some maps
    - Server owners need to manually configure map indexing to fix this in the `mge/cfg/mgemod_spawns.nut` file
    - See `mge_training_v8_beta4b` in the map config file for an example of how to properly index your arenas
- The following maps have been manually indexed:
    - `mge_training_v8_beta4b`
    - `mge_chillypunch_final4_fix2`
    - `mge_oihguy_sucks_b5`
    - `mge_oihguy_sucks_a12`

## ELO/Stat Tracking
### SECURITY WARNING
Support [This github issue](https://github.com/ValveSoftware/Source-1-Games/issues/6356) if you want this to be fixed.
- While most existing MGE maps are safe to use, **DO NOT ENABLE ANY STAT TRACKING ON UNTRUSTED MAPS!**
    - Any MGE maps created after the VScript update can pack a mapspawn.nut file that executes before ours
    - Not only will this break the gamemode, but malicious maps can target either the database or filesystem and manipulate player stats
    - This cannot be fixed unless Valve implements a way for server owners to execute their own scripts before map-packed scripts.
    - **How to check if a map is safe:**
        - Open the bsp using GCFScape, open the .zip file, and check the tf/scripts/vscripts directory in this zip file
        - If you see a mapspawn.nut file, the gamemode will either not load correctly or this map is unsafe
        - Ctrl+F and search for `StringToFile` or `FileToString` in every script file, if you see any of these, the map is probably unsafe
        - Search for `__MGE__VPI`.  If this shows up anywhere, the map is attempting to tamper with the database 

### Plain Text
- perfect option for MGE servers running on a single physical server
- player stats are tracked in the `tf/scriptdata/mge_playerdata` directory indexed by steamid.

### Database
- Database tracking uses [VScript-Python Interface](https://github.com/potato-tf/VPI) to send data from vscript to python through the filesystem.
    - Install VPI and the `aiomysql` module.
