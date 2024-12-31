::StockSounds <- [
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
	"vo/announcer_victory.wav",
	"vo/announcer_you_failed.wav"

	"vo/intel_teamcaptured.wav",
	"vo/intel_teamdropped.wav",
	"vo/intel_teamstolen.wav",
	"vo/intel_enemycaptured.wav",
	"vo/intel_enemydropped.wav",
	"vo/intel_enemystolen.wav",
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

::MGE_Init <- function()
{
	printl("[VScript MGEMod] Loaded, moving all active players to spectator")

	for (local i = 1; i <= MAX_CLIENTS; i++)
	{
		local player = PlayerInstanceFromIndex(i)
		if (!player || !player.IsValid()) continue

		player.ValidateScriptScope()
		InitPlayerScope(player)
		local scope = player.GetScriptScope()
		foreach (k, v in scope)
			printl(k + " " + v)
		printl(player)

		player.ForceChangeTeam(TEAM_SPECTATOR, true)
		// todo bots dont like to stay dead with this, need to come up with something else
		/*
			SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", 0)
		*/
	}

	HandleRoundStart()
	LoadSpawnPoints()

	Convars.SetValue("mp_humans_must_join_team", "spectator")
	Convars.SetValue("mp_autoteambalance", 0);
	Convars.SetValue("mp_teams_unbalance_limit", 0);
	Convars.SetValue("mp_scrambleteams_auto", 0);
	Convars.SetValue("mp_tournament", 0);
}

MGE_Init()