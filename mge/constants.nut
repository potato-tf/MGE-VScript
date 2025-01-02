::CONST <- getconsttable()
::ROOT <- getroottable()

CONST.setdelegate({ _newslot = @(k, v) compilestring("const " + k + "=" + (typeof(v) == "string" ? ("\"" + v + "\"") : v))() })
CONST.MAX_CLIENTS <- MaxClients().tointeger()

//CONFIG CONSTANTS
const DEFAULT_FRAGLIMIT = 20
const DEFAULT_ELO = 1500

const MAX_CLEAR_SPAWN_RETRIES = 10

const ELO_TRACKING_MODE = 1 //0 = none, 1 = file (tf/scriptdata/mge_playerdata), 2 = database (requires VPI)
const IDLE_RESPAWN_TIME = 3.0 //respawn time while waiting for arena to start

const ENABLE_ANNOUNCER = true //enable announcer quips (first blood airshots etc)
const ANNOUNCER_VOLUME = 0.5 //volume of announcer quips

const KILLSTREAK_ANNOUNCER_INTERVAL = 5 //how many kills before we play a killstreak sound

const COUNTDOWN_START_DELAY = 1.0 //delay before countdown starts, additive to queue cycle delay
const QUEUE_CYCLE_DELAY = 4.0 //delay before cycling to next player in queue after a fight, additive to countdown start delay

const COUNTDOWN_SOUND = "ui/chime_rd_2base_pos.wav"
const COUNTDOWN_SOUND_VOLUME = 0.5

const ROUND_START_SOUND = "ui/chime_rd_2base_neg.wav"
const ROUND_START_SOUND_VOLUME = 0.5

const TURRIS_REGEN_TIME = 5.0

const ENDIF_HEIGHT_THRESHOLD = 250
ROOT. ENDIF_FORCE_MULT <- Vector(1.1, 1.1, 2.15)

const BBALL_MAX_SPAWNS = 8
const BBALL_HOOP_SIZE = 30
const BBALL_PICKUP_SOUND = "items/pickup_powerup.wav"
const BBALL_PICKUP_PARTICLE = "powerup_glow_red"
const BBALL_BALL_MODEL = "models/flag/ticket_case.mdl"

//spawn shuffle modes
//0 = none, spawns are iterated over in consistent order based on provided config
//1 = random shuffle, iterates over a randomly shuffled array of spawns (classic MGE plugin behavior)
//2 = random except, picks a truly random spawn so long as it's not the last one we spawned at
//3 = random, no shuffling (can repeat spawns)
const SPAWN_SHUFFLE_MODE = 1
const SPAWN_SOUND = "items/spawn_item.wav"
const SPAWN_SOUND_VOLUME = 1.0

const DEFAULT_CDTIME    = 3 //default countdown time

const PLAYER_THINK_INTERVAL = -1

//END CONFIG CONSTANTS

// Arena status
const AS_IDLE         = 0
const AS_PRECOUNTDOWN = 1
const AS_COUNTDOWN    = 2
const AS_FIGHT        = 3
const AS_AFTERFIGHT   = 4
const AS_REPORTED     = 5

//"reminder that constants are resolved at preprocessor level and not runtime"
//"if you add them dynamically to the table they wont show up until you execute a new script as the preprocessor isnt aware yet"

//fold into both const and root table to work around this.

if (!("ConstantNamingConvention" in ROOT))
{
	foreach(a, b in Constants)
	{
		foreach(k, v in b)
		{
			CONST[k] <- v != null ? v : 0
			ROOT[k] <- v != null ? v : 0
		}
	}
}

foreach (i in [NetProps, Entities, EntityOutputs, NavMesh])
	foreach (k, v in i.getclass())
		if (k != "IsValid" && !(k in ROOT))
			ROOT[k] <- i[k].bindenv(i)

const STRING_NETPROP_ITEMDEF = "m_AttributeManager.m_Item.m_iItemDefinitionIndex"
const SINGLE_TICK = 0.015

// Clientprint chat colors
const COLOR_LIME       = "22FF22"
const COLOR_YELLOW     = "FFFF66"
const TF_COLOR_RED     = "FF3F3F"
const TF_COLOR_BLUE    = "99CCFF"
const TF_COLOR_SPEC    = "CCCCCC"
const TF_COLOR_DEFAULT = "FBECCB"

const INT_COLOR_WHITE = 16777215

//redefine EFlags
const EFL_USER = 1048576 // EFL_IS_BEING_LIFTED_BY_BARNACLE
const EFL_USER2 = 1073741824 //EFL_NO_PHYSCANNON_INTERACTION

// Weapon slots
const SLOT_PRIMARY   = 0
const SLOT_SECONDARY = 1
const SLOT_MELEE     = 2
const SLOT_UTILITY   = 3
const SLOT_BUILDING  = 4
const SLOT_PDA       = 5
const SLOT_PDA2      = 6
const SLOT_COUNT     = 7

// Cosmetic slots (UNTESTED)
const LOADOUT_POSITION_HEAD   = 8
const LOADOUT_POSITION_MISC   = 9
const LOADOUT_POSITION_ACTION = 10
const LOADOUT_POSITION_MISC2  = 11

// Taunt slots (UNTESTED)
const LOADOUT_POSITION_TAUNT  = 12
const LOADOUT_POSITION_TAUNT2 = 13
const LOADOUT_POSITION_TAUNT3 = 14
const LOADOUT_POSITION_TAUNT4 = 15
const LOADOUT_POSITION_TAUNT5 = 16
const LOADOUT_POSITION_TAUNT6 = 17
const LOADOUT_POSITION_TAUNT7 = 18
const LOADOUT_POSITION_TAUNT8 = 19

// DMG type bits, less confusing than shit like DMG_AIRBOAT or DMG_SLOWBURN
const DMG_USE_HITLOCATIONS   = 33554432  // DMG_AIRBOAT
const DMG_HALF_FALLOFF       = 262144    // DMG_RADIATION
const DMG_CRITICAL           = 1048576   // DMG_ACID
const DMG_RADIUS_MAX         = 1024      // DMG_ENERGYBEAM
const DMG_IGNITE             = 16777216  // DMG_PLASMA
const DMG_FROM_OTHER_SAPPER  = 16777216  // same as DMG_IGNITE
const DMG_USEDISTANCEMOD     = 2097152   // DMG_SLOWBURN
const DMG_NOCLOSEDISTANCEMOD = 131072    // DMG_POISON
const DMG_MELEE              = 134217728 // DMG_BLAST_SURFACE
const DMG_DONT_COUNT_DAMAGE_TOWARDS_CRIT_RATE = 67108864 //DMG_DISSOLVE

const TF_DEATH_DOMINATION = 		 1
const TF_DEATH_ASSISTER_DOMINATION = 2
const TF_DEATH_REVENGE =			 4
const TF_DEATH_ASSISTER_REVENGE = 	 8
const TF_DEATH_FIRST_BLOOD = 		 16
const TF_DEATH_FEIGN_DEATH = 		 32
const TF_DEATH_INTERRUPTED = 		 64
const TF_DEATH_GIBBED = 			 128
const TF_DEATH_PURGATORY =			 256
const TF_DEATH_MINIBOSS =			 512
const TF_DEATH_AUSTRALIUM =			 1024


// Numbers
const FLT_SMALL = 0.0000001
const FLT_MIN   = 1.175494e-38
const FLT_MAX   = 3.402823466e+38
const INT_MIN   = -2147483648
const INT_MAX   = 2147483647


///////////////////////////////////////////////////////////////////////////////////////////////////

// todo ??

// Models
const MODEL_POINT          = "models/props_gameplay/cap_point_base.mdl"
const MODEL_BRIEFCASE      = "models/flag/briefcase.mdl"
const MODEL_AMMOPACK       = "models/items/ammopack_small.mdl"
const MODEL_LARGE_AMMOPACK = "models/items/ammopack_large.mdl"

PrecacheModel(MODEL_POINT)
PrecacheModel(MODEL_BRIEFCASE)
PrecacheModel(MODEL_AMMOPACK)
PrecacheModel(MODEL_LARGE_AMMOPACK)
PrecacheModel(BBALL_BALL_MODEL)

PrecacheSound(COUNTDOWN_SOUND)
PrecacheSound(ROUND_START_SOUND)
PrecacheSound(SPAWN_SOUND)
PrecacheSound(BBALL_PICKUP_SOUND)

PrecacheEntityFromTable({ classname = "info_particle_system" effect_name = BBALL_PICKUP_PARTICLE })
