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
const MGE_SPAWN_FILE = "mge/cfg/mgemod_spawns.nut"

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

foreach (sound in StockSounds)
    PrecacheSound(sound)

PrecacheModel(MODEL_POINT)
PrecacheModel(MODEL_BRIEFCASE)
PrecacheModel(MODEL_AMMOPACK)
PrecacheModel(MODEL_LARGE_AMMOPACK)

::All_Arenas <- {}

// ::MGE_Respawn <- SpawnEntityFromTable("trigger_player_respawn_override", {
//     spawnflags = 1,
//     targetname = "__mge_respawn",
//     RespawnTime = 0.0
// })
// MGE_Respawn.SetSolid(SOLID_BBOX)
// MGE_Respawn.SetSize(Vector(), Vector(1, 1, 1))

// //fix delayed starttouch crash
// function RespawnStartTouch() { return (activator && activator.IsValid()) ? true : false; }
// function RespawnEndTouch() { return (activator && activator.IsValid()) ? true : false; }

// MGE_Respawn.ValidateScriptScope()
// MGE_Respawn.GetScriptScope().InputStartTouch <- RespawnStartTouch
// MGE_Respawn.GetScriptScope().Inputstarttouch <- RespawnStartTouch
// MGE_Respawn.GetScriptScope().InputEndTouch <- RespawnEndTouch
// MGE_Respawn.GetScriptScope().Inputendtouch <- RespawnEndTouch