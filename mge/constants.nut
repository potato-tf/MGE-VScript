const MGE_VERSION = "0.3.0"
::ROOT <- getroottable()
::CONST <- getconsttable()

//"reminder that constants are resolved at preprocessor level and not runtime"
//"if you add them dynamically to the table they wont show up until you execute a new script as the preprocessor isnt aware yet"

//fold into both const and root table to work around this.

CONST.setdelegate({ _newslot = @(k, v) compilestring("const " + k + "=" + (typeof(v) == "string" ? ("\"" + v + "\"") : v))() })
CONST.MAX_CLIENTS <- MaxClients().tointeger()
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

//TODO: see if reducing the think interval makes any impact on 100 player?
//we need maps that can support this many players in the first place
//look into "infinite" maps with propper arenas
const PLAYER_THINK_INTERVAL = -1

const GENERIC_DELAY = 0.1 //many things are delayed by this amount on player spawn and other important EntFires

// Maximum number of spawn points allowed in an arena
// this can safely be expanded to whatever, but I don't think any arenas will need more than 32
// if you're making a custom map/arena with >32 spawns, increase this value

// LoadSpawnPoints iterates over this value twice on map load/custom ruleset load
// don't just set it to some crazy high number to make it go away
const SPAWN_POINTS_ABSOLUTE_MAX = 32

// Arena status
const AS_IDLE         = 0
const AS_COUNTDOWN    = 1
const AS_FIGHT        = 2
const AS_AFTERFIGHT   = 3
const AS_REPORTED     = 4

const STRING_NETPROP_ITEMDEF = "m_AttributeManager.m_Item.m_iItemDefinitionIndex"
const SINGLE_TICK = 0.015

const INT_COLOR_WHITE = 16777215

//redefine EFlags
const EFL_USER = 1048576 // EFL_IS_BEING_LIFTED_BY_BARNACLE
const EFL_REMOVE_FROM_ARENA = 1073741824 //EFL_NO_PHYSCANNON_INTERACTION

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

//player_death flags
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

// EmitSoundEx flags
const SND_NOFLAGS         = 0
const SND_CHANGE_VOL      = 1
const SND_CHANGE_PITCH    = 2
const SND_STOP            = 4
const SND_SPAWNING        = 8
const SND_DELAY           = 16
const SND_STOP_LOOPING    = 32
const SND_SPEAKER         = 64
const SND_SHOULDPAUSE     = 128
const SND_IGNORE_PHONEMES = 256
const SND_IGNORE_NAME     = 512
const SND_DO_NOT_OVERWRITE_EXISTING_ON_CHANNEL = 1024

// EmitSoundEx channels
const CHAN_REPLACE    = -1
const CHAN_AUTO       =  0
const CHAN_WEAPON     =  1
const CHAN_VOICE      =  2
const CHAN_ITEM       =  3
const CHAN_BODY       =  4
const CHAN_STREAM     =  5
const CHAN_STATIC     =  6
const CHAN_VOICE2     =  7
const CHAN_VOICE_BASE =  8
const CHAN_USER_BASE  =  136

//masks
CONST.MASK_OPAQUE      <- (CONTENTS_SOLID|CONTENTS_MOVEABLE|CONTENTS_OPAQUE)
CONST.MASK_PLAYERSOLID <- (CONTENTS_SOLID|CONTENTS_MOVEABLE|CONTENTS_PLAYERCLIP|CONTENTS_WINDOW|CONTENTS_MONSTER|CONTENTS_GRATE)
CONST.MASK_SOLID_BRUSHONLY <- (CONTENTS_SOLID|CONTENTS_MOVEABLE|CONTENTS_WINDOW|CONTENTS_GRATE)

// Numbers
const FLT_SMALL = 0.0000001
const FLT_MIN   = 1.175494e-38
const FLT_MAX   = 3.402823466e+38
const INT_MIN   = -2147483648
const INT_MAX   = 2147483647

const BASE_SHOTGUN_DAMAGE = 60
