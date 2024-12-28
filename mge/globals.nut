::ROOT <- getroottable()
::CONST <- getconsttable()
if (!("ConstantNamingConvention" in ROOT)) // make sure folding is only done once
{
	foreach (a,b in Constants)
		foreach (k,v in b)
        {
			ROOT[k] <- v != null ? v : 0
            CONST[k] <- v != null ? v : 0
        }
}

CONST.MAXPLAYERS <- MaxClients().tointeger()
CONST.MAP_NAME <- GetMapName()

const MAXARENAS = 63
const MAXSPAWNS = 15
const HUDFADEOUTTIME = 120.0
//config file included above

const SLOT_ONE = 1
const SLOT_TWO = 2
const SLOT_THREE = 3
const SLOT_FOUR = 4

//arena status
const AS_IDLE = 0
const AS_PRECOUNTDOWN = 1
const AS_COUNTDOWN = 2
const AS_FIGHT = 3
const AS_AFTERFIGHT = 4
const AS_REPORTED = 5

// for neutral cap points
const NEUTRAL = 1

//sounds
const STOCK_SOUND_COUNT = 24
const DEFAULT_CDTIME = 3
const MODEL_POINT = "models/props_gameplay/cap_point_base.mdl"
const MODEL_BRIEFCASE = "models/flag/briefcase.mdl"
const MODEL_AMMOPACK = "models/items/ammopack_small.mdl"
const MODEL_LARGE_AMMOPACK = "models/items/ammopack_large.mdl"
const MGE_SPAWN_FILE = "mge_configs/mgemod_spawns.nut"

// this will get overwritten by the config file
// defined here to avoid errors
::SpawnConfigs <- {}

::StockSounds <- [
    "vo/intel_teamcaptured.wav",
    "vo/intel_teamdropped.wav",
    "vo/intel_teamstolen.wav",
    "vo/intel_enemycaptured.wav",
    "vo/intel_enemydropped.wav",
    "vo/intel_enemystolen.wav",
    "vo/announcer_ends_5sec.wav",
    "vo/announcer_ends_4sec.wav",
    "vo/announcer_ends_3sec.wav",
    "vo/announcer_ends_2sec.wav",
    "vo/announcer_ends_1sec.wav",
    "vo/announcer_ends_10sec.wav",
    "vo/announcer_control_point_warning.wav",
    "vo/announcer_control_point_warning2.wav",
    "vo/announcer_control_point_warning3.wav",
    "vo/announcer_overtime.wav",
    "vo/announcer_overtime2.wav",
    "vo/announcer_overtime3.wav",
    "vo/announcer_overtime4.wav",
    "vo/announcer_we_captured_control.wav",
    "vo/announcer_we_lost_control.wav",
    "items/spawn_item.wav",
    "vo/announcer_victory.wav",
    "vo/announcer_you_failed.wav"
]

foreach (sound in stockSounds)
    PrecacheSound(sound)

PrecacheModel(MODEL_POINT)
PrecacheModel(MODEL_BRIEFCASE)
PrecacheModel(MODEL_AMMOPACK)
PrecacheModel(MODEL_LARGE_AMMOPACK)