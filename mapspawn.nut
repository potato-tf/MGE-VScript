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

const MGE_VERSION = "0.5.0"

::ROOT  <- getroottable()
::CONST <- getconsttable()

// get clean map name from workshop map name
local mapname = GetMapName()
::MAPNAME_CONFIG_OVERRIDE <- 8 in mapname && mapname[8] == '/' ? mapname.slice(9, mapname.find(".") ) : mapname

local Include = @(file) IncludeScript("mge/"+file)

Include("cfg/mgemod_spawns")

// spawns not configured, bail and don't load anything
if (!(MAPNAME_CONFIG_OVERRIDE in SpawnConfigs)) {

	local failed_msg = "Map not configured for MGE, goodbye..."
	error(format("\n%s\n%s\n%s\n\n", failed_msg, failed_msg, failed_msg))
	ClientPrint(null, 3, "\x07FFD700[MGE VScript] \x07edf781"+failed_msg)
	ClientPrint(null, 4, "[MGE VScript] "+failed_msg)

	delete CONST.MGE_VERSION
	delete MAPNAME_CONFIG_OVERRIDE
	delete SpawnConfigs

	collectgarbage()

	return
}

Include("constants")

/*********************************************************************************************
 * Namespacing wrapper for creating self-contained extension/module scopes.			         *
 * All code is scoped to an entity to allow for easier cleanup.  Code is killed with the ent *
 * - name: Targetname of the entity.  "__mge" in the name is recommended for consistency	 *
 * - namespace: Root table reference to the scope.                                           *
 * - entity_ref: Root table reference to the entity.                                         *
 * - think_func: Create a think function for this entity/scope, depending on argument type.  *
 * 	  - String: Create a new think function that iterates over a 'ThinkTable' table.		 *
 * 	  - Function: Does NOT create 'ThinkTable', sets the think function directly.			 *
 * - classname: overrides the spawned entity classname to something else                     *
 *********************************************************************************************/

if ( !( "__mge_active_scopes" in ROOT ) )
	::__mge_active_scopes <- {}

function MGE_CREATE_SCOPE( name = "__mge_scope"+UniqueString(), namespace = null, entity_ref = null, think_func = null, classname = null, table_auto_delegate = true ) {

	local ent = FindByName( null, name )

	if ( !ent || !ent.IsValid() ) {

		ent = SpawnEntityFromTable( classname || "logic_autosave", { vscripts = " " } )
		SetPropString( ent, "m_iName", name )
	}

	SetPropBool( ent, "m_bForcePurgeFixedupStrings", true )
	__mge_active_scopes[ ent ] <- namespace

	// make preserved between round resets
	// don't spawn an actual move_rope to save an edict
	if ( !classname )
		SetPropString( ent, "m_iClassname", "move_rope" )

	local ent_scope = ent.GetScriptScope()

	local namespace    =  namespace  || format( "%s_Scope", name )
	local entity_ref   =  entity_ref || format( "%s_Entity", name )
	ROOT[ namespace ]  <- ent_scope
	ROOT[ entity_ref ] <- ent

	ent_scope.setdelegate({

		function _newslot( k, v ) {

			if ( k == "_OnDestroy" && _OnDestroy == null )
				_OnDestroy = v.bindenv( ent_scope )

			this.rawset( k, v )

            if ( typeof v == "function" ) {

                if ( k == "_OnCreate" )
                    _OnCreate.call( ent_scope )

                // fix anonymous function declarations in perf counter
                else if ( v.getinfos().name == null ) 
                    compilestring( format( @" local _%s = %s; function %s() { _%s() }", k, k, k, k ) ).call( ent_scope )
            }

            // delegate variables to ent_scope for less verbose writing
            // e.g. Scope.MyTable.MyFunc() can be written instead as Scope.MyFunc() in more places
            else if ( typeof v == "table" && table_auto_delegate )
                v.setdelegate( ent_scope )
		}

	}.setdelegate( {

			parent     = ent_scope.getdelegate()
			id         = ent.GetScriptId()
			index      = ent.entindex()
			_OnDestroy = null

			function _get( k ) { return parent[k] }

			function _delslot( k ) {

				if ( k == id ) {

					if ( _OnDestroy )
						_OnDestroy()

                    // delete root references to ourself
					if ( namespace in ROOT )
						delete ROOT[ namespace ]

					if ( entity_ref in ROOT )
						delete ROOT[ entity_ref ]

					__mge_active_scopes = __mge_active_scopes.filter( @(ent, _) ent && ent.IsValid() )
				}

				delete parent[k]
			}
		} )
	)

	if ( think_func ) {

		// function passed, Add the think function directly to the entity
		if ( endswith( typeof think_func, "function" ) ) {

			local think_name = think_func.getinfos().name || format( "%s_Think", name )

			ent_scope[ think_name ] <- think_func
			AddThinkToEnt( ent, think_name )
			return
		}

        // String passed, set up think table and assume we're defining the actual function later
		ent_scope.ThinkTable <- {}

        ent_scope[ think_func ] <- function() {

            foreach( func in ThinkTable )
                func()

            return -1
        }

		AddThinkToEnt( ent, think_func )
	}

	return { Entity = ent, Scope = ent_scope }
}

// many mge maps only have a single respawn point
// this spams console with "no valid spawns for class x on team x" errors for every player spawn
// this will stop the spam after the first player spawn
// some maps (chillypunch) also use cap logic to override the global respawn times
// we force "infinite" respawn times to avoid problems
function ROOT::MGE_RESPAWN_FIX()
{
	// delay until ents are spawned
	EntFire("worldspawn", "RunScriptCode", @"

		local base_spawn = Entities.FindByClassname(null, `info_player_teamspawn`)

		// will be null for > 1 spawn point
		if (!base_spawn) return

		local function make_spawn( team, offset ) {

			SpawnEntityFromTable(`info_player_teamspawn`, {

				targetname 	= `__mge_spawn_override_`+team
				TeamNum 	= team
				origin 		= base_spawn.GetOrigin() + offset
				spawnflags 	= 511
			})
		}

		local blu_spawn = make_spawn(2, Vector(0, 0, 10))
		local red_spawn = make_spawn(3, Vector(0, 0, 20))

		MGE.MGE_RESPAWN_OVERRIDE <- SpawnEntityFromTable(`trigger_player_respawn_override`, {

			targetname  = `__mge_respawn_override`
			RespawnTime = IDLE_RESPAWN_TIME
			spawnflags  = 1
		})
		MGE.MGE_RESPAWN_OVERRIDE.SetSolid(2)
		MGE.MGE_RESPAWN_OVERRIDE.SetSize(Vector(), Vector(1, 1, 1))

	", 1)
}

Include("itemdef_constants")
Include("cfg/config")
Include("cfg/localization")

// the VPI system for passing vscript data to python
// If you are just hosting a single server and just want basic MGE functionality
// with local, file-based ELO tracking, you can ignore all of this.

// VPI is used for:
// - external mysql/sqlite database connection
// - pulling leaderboard stats from the database
// - gamemode auto-updates via github
// - per-arena JSON logging
if (
	CONST.ELO_TRACKING_MODE > 1 	||
	CONST.ENABLE_LEADERBOARD 		||
	CONST.UPDATE_SERVER_DATA 		||
	CONST.GAMEMODE_AUTOUPDATE_REPO 	||
	CONST.PER_ARENA_LOGGING
) {
	Include("vpi/vpi")

	// create scriptdata directories
	FileToString("mge_playerdata/ ")
	FileToString("mge_arenalogs/ ")
}

Include("functions")
Include("events")
Include("mge")

EntFire("__mge_main", "CallScriptFunction", "collectgarbage")