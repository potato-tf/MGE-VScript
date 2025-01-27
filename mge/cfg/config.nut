//CONFIG CONSTANTS
const DEFAULT_LANGUAGE                        = "english"

const MAP_RESTART_TIMER                       = 7200 //how long to wait before restarting the map/server in seconds

/***************************************************************************************************************
 *              setting this to true will send a retry command to every player and kill worldspawn             *
 *   this obviously assumes you use a watchdog script/systemd/etc to restart the server automatically on crash *
 *         we should find a better way to kill the server that doesn't trigger an accelerator crash dump       *
 *    this will not work if your server launch times are longer than 25 seconds (default retry attempt time)   *
 ***************************************************************************************************************/
const SERVER_FORCE_SHUTDOWN_ON_CHANGELEVEL    = false

/******************************************************************************************************
 *      if repo is (not false or "") and vpi is running, vpi will periodically git clone the repo     *
 *     if vpi detects a change it will trigger a callback function to shorten the map restart timer   *
 ******************************************************************************************************/
// const GAMEMODE_AUTOUPDATE_REPO            = "https://github.com/potato-tf/MGE-VScript.git" //the repo to clone
const GAMEMODE_AUTOUPDATE_REPO               = false //the repo to clone
const GAMEMODE_AUTOUPDATE_BRANCH             = "main" //the branch to clone
const GAMEMODE_AUTOUPDATE_TARGET_DIR         = "D:/dedicatedtf/tf/scripts/vscripts" //the directory to clone to, this should be your servers `tf/scripts/vscripts` directory
const GAMEMODE_AUTOUPDATE_RESTART_TIME       = 300.0 //the time to wait before restarting the map in seconds

 //how often to check for updates in seconds (30 minutes 30*60=1800).
 //GitHub will rate limit you if you try to abuse this
const GAMEMODE_AUTOUPDATE_INTERVAL           = 120

//general
const DEFAULT_FRAGLIMIT                      = 20
const DEFAULT_ELO                            = 1600

// 0 = none - No ELO or stat tracking at all
// 1 = file (tf/scriptdata/mge_playerdata) - Recommended for servers hosted on a single physical machine
// 2 = database (requires VPI) - Recommended for multi-region server networks, local data is still written to local storage
// 3 = database NO fallback - Database connection only, don't write player data to files
// if VPI is not running this will just do nothing and accumulate junk in your scriptdata folder xd
const ELO_TRACKING_MODE                      = 2
const ENABLE_LEADERBOARD                     = true //This only works if ELO_TRACKING_MODE is set to 2 or 3, file-based leaderboards don't exist yet
const REMOVE_DROPPED_WEAPONS                 = true
const IDLE_RESPAWN_TIME                      = 3.0 //respawn time while waiting for arena to start
const AIRSHOT_HEIGHT_THRESHOLD               = 100
const SPECTATOR_MESSAGE_COOLDOWN             = 25.0

//leaderboard
const LEADERBOARD_FORWARD_OFFSET             = 12
const LEADERBOARD_VERTICAL_OFFSET            = 6
const LEADERBOARD_TEXT_SIZE                  = 1.0
const LEADERBOARD_UPDATE_INTERVAL            = 10
const MAX_LEADERBOARD_ENTRIES                = 7 //anything greater than 7 gets cut off

/*******************************************************************************************************
 * spawn shuffle modes                                                                                 *
 * 0 = none, spawns are iterated over in consistent order based on provided config                     *
 * 1 = random shuffle, iterates over a randomly shuffled array of spawns (classic MGE plugin behavior) *
 * 2 = random except, picks a truly random spawn so long as it's not the last one we spawned at        *
 * 3 = random, no shuffling (can repeat spawns)                                                        *
 *******************************************************************************************************/
const SPAWN_SHUFFLE_MODE                     = 1
const SPAWN_SOUND                            = "items/spawn_item.wav" //a few other things besides spawning use this sound
const SPAWN_SOUND_VOLUME                     = 1.0
const MAX_CLEAR_SPAWN_RETRIES                = 10

//announcer
const ENABLE_ANNOUNCER                       = true //enable announcer quips (first blood airshots etc)
const ANNOUNCER_VOLUME                       = 0.5 //volume of announcer quips
const KILLSTREAK_ANNOUNCER_INTERVAL          = 5 //airshot announcer will play every KILLSTREAK_ANNOUNCER_INTERVAL number of kills

//round misc
const DEFAULT_CDTIME                         = 3 //default countdown time

const COUNTDOWN_START_DELAY                  = 1.0 //delay before countdown starts, additive to queue cycle delay
const QUEUE_CYCLE_DELAY                      = 3.0 //delay before cycling to next player in queue after a fight, additive to countdown start delay

const COUNTDOWN_SOUND                        = "ui/chime_rd_2base_pos.wav" //a few other things besides countdown use this sound
const COUNTDOWN_SOUND_VOLUME                 = 0.5

const ROUND_START_SOUND                      = "ui/chime_rd_2base_neg.wav" //a few other things besides round start use this sound
const ROUND_START_SOUND_VOLUME               = 0.5

//hud
//see KOTH section for KOTH hud
const MGE_HUD_POS_X                         = 0.2
const MGE_HUD_POS_Y                         = 0.15

const AMMOMOD_RESPAWN_DELAY                 = 2.0
const AMMOMOD_DEFAULT_HP_MULT 				= 6.0

const TURRIS_REGEN_TIME                     = 5.0

const ENDIF_HEIGHT_THRESHOLD                = 250

const ALLMEAT_DAMAGE_THRESHOLD              = 0.85

::ALLMEAT_MAX_DAMAGE <- {
	tf_weapon_scattergun = 105,
	tf_weapon_handgun_scout_primary = 72,
	tf_weapon_shotgun = 90,
	tf_weapon_pipebomblauncher = 100,
	[ID_PANIC_ATTACK_SHOTGUN] = 108,
}
//this is absolutely not the value that the .sp plugin implies it uses, 2.15 is way too high
//on the majority of mge servers, endif force mult only barely pushes you over the threshold with a single non-DH shot to the toes
//2.15 here is pinball mode
//if someone wants to do a deep dive with side-by-side comparisons of the original plugin velocity vs this, I would love to see it
::ENDIF_FORCE_MULT                          <- Vector(1.1, 1.1, 1.31) //no vector constants :(

//NOTE:
//Editing this constant alone is not enough to add more spawns to arenas with fixed spawn rotations like BBall
//Ctrl + F for "bball_points" in functions.nut to see how you will need to update your map config to support this
const BBALL_MAX_SPAWNS                      = 8
// BBall uses index 9-13 for round logic
// based on the bball_points table, index "9" for example can be replaced with "bball_home",
// the "9" index can now be used for a 9th spawn point

//SourceMod MGE uses the same array for spawn points as it does for round logic
//VScript MGE uses a table for arena data with descriptive names, allowing you to add more spawns without issue
//For better legacy compatibility with existing map configs we still read the old indexes

const BBALL_HOOP_SIZE                       = 30
const BBALL_PICKUP_SOUND_VOLUME             = 1.0
const BBALL_PICKUP_SOUND                    = "ui/chime_rd_2base_neg.wav"
const BBALL_BALL_MODEL                      = "models/flag/ticket_case.mdl"
const BBALL_PARTICLE_PICKUP_RED             = "teleported_red"
const BBALL_PARTICLE_PICKUP_BLUE            = "teleported_blue"
const BBALL_PARTICLE_PICKUP_GENERIC         = ""
const BBALL_PARTICLE_TRAIL_RED              = "player_intel_trail_red"
const BBALL_PARTICLE_TRAIL_BLUE             = "player_intel_trail_blue"

//all BBall settings below are for custom ruleset bball only

const BBALL_HOOP_MODEL                      = "models/props_forest/basketball_hoop.mdl"
const BBALL_MAX_HOOP_DIST                   = 1000
const BBALL_HOOP_PLACEMENT_COOLDOWN         = 2.0

//the actual "hoop" spot used for scoring is offset this far forward from the model.
//This may be very misleading depending on the custom models Forward() vector
const BBALL_HOOP_POS_OFFSET                 = 60
 //setting this to 360 will allow placing hoops on the floor/ceiling.
 //Some angle forgiveness (<15) means the wall doesn't need to be perfectly flat
const BBALL_HOOP_MAX_ANGLE_X                = 20.0

const BBALL_BALL_ANGLE_X                    = 360.0

//NOTE:
//See BBall notes about adding more spawns
// KOTH uses index 7 for the cap point, replace "7" with "koth_cap" to use a 7th spawn point
const KOTH_MAX_SPAWNS                       = 6

//both of these can be overridden in mgemod_spawns.nut
const KOTH_DEFAULT_CAPTURE_POINT_RADIUS     = 256
const KOTH_CAPTURE_POINT_MAX_HEIGHT         = 128

const KOTH_PARTIAL_CAP_RATE                 = 0.05 //how much progress we gain per KOTH_PARTIAL_CAP_INTERVAL
const KOTH_PARTIAL_CAP_INTERVAL             = 0.1 //partial cap increment in seconds

const KOTH_DECAY_RATE                       = 0.01 //how much the cap decays per KOTH_DECAY_INTERVAL
const KOTH_DECAY_INTERVAL                   = 0.1 //decay decrement in seconds

//if true, reverting enemy cap progress will stack with passive decay
const KOTH_ADDITIVE_DECAY                   = true

const KOTH_COUNTDOWN_RATE                   = 1.0
const KOTH_COUNTDOWN_INTERVAL               = 1.0

const KOTH_START_TIME_RED                   = 60
const KOTH_START_TIME_BLUE                  = 60

const KOTH_RED_HUD_COLOR                    = "255 80 80"
const KOTH_BLU_HUD_COLOR                    = "80 80 255"

const KOTH_HUD_RED_POS_X                    = 0.6
const KOTH_HUD_RED_POS_Y                    = 0.4

const KOTH_HUD_BLU_POS_X                    = 0.6
const KOTH_HUD_BLU_POS_Y                    = 0.3

//all koth settings below are for custom ruleset koth only

const KOTH_POINT_MODEL                      = "models/props_2fort/groundlight003.mdl"
const KOTH_POINT_MAX_ANGLE_X                  = 20.0
const KOTH_POINT_ANGLE_X                    = 360.0
const KOTH_POINT_PLACEMENT_COOLDOWN                   = 2.0

//NOTE:
//See BBall notes about adding more spawns
const ULTIDUO_MAX_SPAWNS                    = 4

//VPI related stuff
// CONST.HLTV_TEST <- Convars.GetInt("tv_enable")
const HLTV_TEST                             = false
//this gets overwritten by HLTV_TEST (fixed 8 second interval)
const VPI_SERVERINFO_UPDATE_INTERVAL        = 3

const LEADERBOARD_DEBUG                     = true

PrecacheModel(BBALL_BALL_MODEL)
PrecacheModel(BBALL_HOOP_MODEL)

PrecacheModel(KOTH_POINT_MODEL)

PrecacheSound(COUNTDOWN_SOUND)
PrecacheSound(ROUND_START_SOUND)
PrecacheSound(SPAWN_SOUND)
PrecacheSound(BBALL_PICKUP_SOUND)

function PrecacheParticle(particle)
{
	PrecacheEntityFromTable({ classname = "info_particle_system" effect_name = particle })
}

PrecacheParticle(BBALL_PARTICLE_PICKUP_RED)
PrecacheParticle(BBALL_PARTICLE_PICKUP_BLUE)
PrecacheParticle(BBALL_PARTICLE_PICKUP_GENERIC)
PrecacheParticle(BBALL_PARTICLE_TRAIL_RED)
PrecacheParticle(BBALL_PARTICLE_TRAIL_BLUE)