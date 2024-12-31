// todo ??

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

::Arenas      <- {}
::Arenas_List <- [] // Need ordered arenas for selection with client commands like !add

::default_scope <- {
	"self"    : null,
	"__vname" : null,
	"__vrefs" : null,
}

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