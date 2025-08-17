/*********************************************************************************************************************************************************************
 * Core code is separated into these sections:																													     *
 * 	   - Gamemode/map initialization (mapspawn.nut)                                                                                                                  *
 *     - Function definitions (functions.nut)                                                                                                                        *
 *     - Game event hooks (events.nut)                                                                                                                               *
 *     - Miscellaneous core logic/custom gamemode entities (mge.nut)                                                                                                 *
 * - All functions are globally defined, meaning any "plug-in" external scripts will need to be careful about their function names to avoid collisions/overwriting.  *
 * - All custom files are included in the Include() function below.                                                                                              	 *
 * 																                                                                                                     *
 * - cfg/config.nut                                                                                                                                                  *
 *     - editable configuration file for the gamemode.                                                                                                               *
 *     - Check for configurable values in this file before editing code directly.                                                                                    *
 *																																									 *
 * - cfg/localization.nut                                                                                                                                            *
 *     - localized text strings for the gamemode.                                                                                                                    *
 *     - If you run into sketchy translations it's because they were AI generated																					 *
 *     - I would greatly appreciate pull requests if you fix them (you'll be credited too)                                                                           *
 *																																									 *
 * - cfg/mgemod_spawns.nut                                                                                                                                           *
 *     - this is a 1:1 copy of the sourcemod mgemod_spawns.cfg file with one very important difference:                                                              *
 *     - all arena are now indexed using the "idx" kv.  This controls the ordering of the arena list in the !add menu.                                               *
 *     - The github repo has instructions for how to port sourcemod spawns to this format, however YOU WILL NEED TO INDEX THEM MANUALLY.                             *
 *																																									 *
 *                                                                                                                                                                   *
 * - mapspawn.nut (this file)                                                                                                                                        *
 *     - This includes all other files required for the gamemode, as well as the map specific config overrides.                                		                 *
 *     - If you're adding a new custom file or a new map, you'll need to edit this file.                                                                           	 *
 *																														                                             *
 * - mge/constants.nut					                                                                                                                             *
 *     - all NON-CONFIGURABLE constant values used by the gamemode                                                                                                   *
 *     - If you're adding a new constant that should not be modified by server admins, add it here.                                                                  *
 *																																									 *
 * - mge/functions.nut                                                                                                                                               *
 *     - all functions called by event hooks, think functions, etc are defined in here.                                                                              *
 *     - for custom forks of the gamemode, add all of your functions here.                                                                                           *
 *																																									 *
 * - mge/events.nut                                                                                                                                                  *
 *     - all event hooks (player_spawn, player_death, etc) are defined in here.                                                                                  	 *
 *     - if you're adding a new event hook, add it to this file.                                                                                                  	 *
 *																																									 *
 * - mge/mge.nut                                                                                                                                                     *
 *     - this is the main file for the gamemode, it handles the initialization of the gamemode and the loading of custom maps.                                       *
 *     - if you're adding a new custom map, you will need to add it to this file.                                                                                    *
 * 																																									 *
 * - mge/vpi/...																																					 *
 * 	   - These scripts handle interfacing from vscript to python for various things like database integration and github auto-updates 								 *
 *********************************************************************************************************************************************************************/


// many mge maps only have a single respawn point
// this spams console with "no valid spawns for class" errors for every player spawn
// this will stop the spam after the first player spawn
// some maps (chillypunch) also use cap logic to override the global respawn times
::MGE_RespawnFix <- function()
{
	// delay until ents are spawned
	EntFire("worldspawn", "RunScriptCode", @"

		local base_spawn = Entities.FindByClassname(null, `info_player_teamspawn`)

		// will be null for > 1 spawn point
		if (!base_spawn) return

		local red_spawn = SpawnEntityFromTable(`info_player_teamspawn`, {
			targetname = `__mge_spawn_override_2`
			TeamNum = 2
			origin = base_spawn.GetOrigin() + Vector(0, 0, 10)
			spawnflags = 511
		})

		local blu_spawn = SpawnEntityFromTable(`info_player_teamspawn`, {
			targetname = `__mge_spawn_override_3`
			TeamNum = 3
			origin = base_spawn.GetOrigin() + Vector(0, 0, 20)
			spawnflags = 511
		})

		::MGE_RESPAWN_OVERRIDE <- SpawnEntityFromTable(`trigger_player_respawn_override`, {
			targetname = `__mge_player_respawn_override`
			RespawnTime = 99999
			spawnflags = 1
		})
		MGE_RESPAWN_OVERRIDE.SetSolid(2)
		MGE_RESPAWN_OVERRIDE.SetSize(Vector(), Vector(1, 1, 1))

	", 1)
}

::MAPNAME_CONFIG_OVERRIDE <- GetMapName()

::MGE_MAPINFO <- {

	"workshop/mge_training_v8_beta4b.ugc1996603816" : {
		nice_name = "Classic Training"
		init_func = function() {
			MAPNAME_CONFIG_OVERRIDE = "mge_training_v8_beta4b"
			MGE_RespawnFix()
		}
	},
	"workshop/mge_chillypunch_final4_fix2.ugc3490315512" : {
		nice_name = "Chillypunch"
		init_func = function() {
			MAPNAME_CONFIG_OVERRIDE = "mge_chillypunch_final4_fix2"
			MGE_RespawnFix()
		}
	},
	mge_training_v8_beta4b 		= {
		nice_name = "Classic Training"
		init_func = MGE_RespawnFix
	},

	mge_chillypunch_final4_fix2 = {
		nice_name = "Chillypunch"
		init_func = MGE_RespawnFix
	},

	mge_triumph_beta7_rc1 		= {
		nice_name = "Triumph"
	},
	
	mge_oihguv_sucks_b5 		= {
		nice_name = "Oihguv"
	},
	
	mge_oihguv_sucks_a12 		= {
		nice_name = "Oihguv"
	},
}
if (!(MAPNAME_CONFIG_OVERRIDE in MGE_MAPINFO))
	return

if ("init_func" in MGE_MAPINFO[MAPNAME_CONFIG_OVERRIDE])
	MGE_MAPINFO[MAPNAME_CONFIG_OVERRIDE].init_func()

local function Include(file)
{
	local path = format("mge/%s", file)
	IncludeScript(path)
}

Include("cfg/mgemod_spawns")

if (!(MAPNAME_CONFIG_OVERRIDE in SpawnConfigs))
	delete SpawnConfigs
else
{
	// these 4 must be included first
	Include("constants") 
	Include("itemdef_constants")
	Include("cfg/config")
	Include("cfg/localization")
	
	// the VPI system for passing vscript data to python
	// if you're just hosting a single server and don't enable the leaderboard in config.nut, none of this will be used
	if (
		CONST.ELO_TRACKING_MODE > 1 	||
		CONST.ENABLE_LEADERBOARD 		||
		CONST.UPDATE_SERVER_DATA 		||
		CONST.GAMEMODE_AUTOUPDATE_REPO 	||
		CONST.PER_ARENA_LOGGING
	) {
		Include("vpi/vpi")

		// create scriptdata directories
		FileToString("mge_playerdata/")
		FileToString("mge_arenalogs/")
	}

	Include("functions")
	Include("events")
	Include("mge")

}