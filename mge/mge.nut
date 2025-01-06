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

	"vo/announcer_am_roundstart01.mp3",
	"vo/announcer_am_roundstart02.mp3",
	"vo/announcer_am_roundstart03.mp3",
	"vo/announcer_am_roundstart04.mp3",

	"vo/announcer_am_lastmanforfeit01.mp3",

	"vo/announcer_am_killstreak01.mp3",
	"vo/announcer_am_killstreak02.mp3",
	"vo/announcer_am_killstreak03.mp3",
	"vo/announcer_am_killstreak04.mp3",
	"vo/announcer_am_killstreak05.mp3",
	"vo/announcer_am_killstreak06.mp3",
	"vo/announcer_am_killstreak07.mp3",
	"vo/announcer_am_killstreak08.mp3",
	"vo/announcer_am_killstreak09.mp3",
	"vo/announcer_am_killstreak10.mp3",
	"vo/announcer_am_killstreak11.mp3",

	"vo/announcer_am_firstblood01.mp3",
	"vo/announcer_am_firstblood02.mp3",
	"vo/announcer_am_firstblood03.mp3",
	"vo/announcer_am_firstblood04.mp3",
	"vo/announcer_am_firstblood05.mp3",
	"vo/announcer_am_firstblood06.mp3",

	"vo/announcer_am_flawlessvictory01.mp3",
	"vo/announcer_am_flawlessvictory02.mp3",
	"vo/announcer_am_flawlessvictory03.mp3",
	"vo/announcer_am_flawlessdefeat01.mp3",
	"vo/announcer_am_flawlessdefeat02.mp3",
	"vo/announcer_am_flawlessdefeat03.mp3",
	"vo/announcer_am_flawlessdefeat04.mp3",

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

::ArenaClasses <- ["", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer", "civilian"]

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
		player.ForceChangeTeam(TEAM_SPECTATOR, true)
		GetStats(player)
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

	Convars.SetValue("tf_weapon_criticals", 0);
	Convars.SetValue("tf_fall_damage_disablespread", 1);
}
//assumes spawn config exists

::nav_generation_state <- {
	generator = null,
	is_running = false
}

::ArenaNavGenerator <- function(only_this_arena = null) {
	local player = GetListenServerHost()

	local progress = 0
	if (!only_this_arena) {
		local arenas_len = Arenas.len()
		foreach(arena_name, arena in Arenas) {
			local generate_delay = 0.0
			progress++
			// Process spawn points for current arena
			foreach(spawn_point in arena.SpawnPoints) {
				generate_delay += 0.01
				EntFireByHandle(player, "RunScriptCode", format(@"
					local origin = Vector(%f, %f, %f)
					self.SetOrigin(origin)
					self.SnapEyeAngles(QAngle(90, 0, 0))
						SendToConsole(`nav_mark_walkable`)
						printl(`Marking Spawn Point: ` + origin)
				", spawn_point[0].x, spawn_point[0].y, spawn_point[0].z), generate_delay, null, null)
			}

			// Schedule nav generation for current arena
			EntFire("bignet", "RunScriptCode", format(@"
				ClientPrint(null, 3, `Areas marked!`)
				ClientPrint(null, 3, `Generating nav...`)
				SendToConsole(`host_thread_mode -1`)
				SendToConsole(`nav_generate_incremental`)
				ClientPrint(null, 3, `Progress: ` + %d +`/`+ %d)
			", progress,arenas_len), generate_delay + 0.1)

			yield
		}
	} else {
		local arena = Arenas[only_this_arena]
		local generate_delay = 0.0
		foreach(spawn_point in arena.SpawnPoints) {
			generate_delay += 0.01
			EntFireByHandle(player, "RunScriptCode", format(@"
				local origin = Vector(%f, %f, %f)
				self.SetOrigin(origin)
				self.SnapEyeAngles(QAngle(90, 0, 0))
					SendToConsole(`nav_mark_walkable`)
					printl(`Marking Spawn Point: ` + origin)
			", spawn_point[0].x, spawn_point[0].y, spawn_point[0].z), generate_delay, null, null)
		}

		// Schedule nav generation for current arena
		EntFire("bignet", "RunScriptCode", @"
			ClientPrint(null, 3, `Areas marked!`)
			ClientPrint(null, 3, `Generating nav...`)
			SendToConsole(`host_thread_mode -1`)
			SendToConsole(`nav_generate_incremental`)
		", generate_delay + 0.1)
	}
}

::ResumeNavGeneration <- function() {
	if (!nav_generation_state.is_running || !nav_generation_state.generator) return

	if (nav_generation_state.generator.getstatus() == "dead") {
		nav_generation_state.is_running = false
		return
	}

	resume nav_generation_state.generator
}

::MGE_CreateNav <- function(only_this_arena = null) {
	local player = GetListenServerHost()
	player.SetMoveType(MOVETYPE_NOCLIP, MOVECOLLIDE_DEFAULT)

	if (!Arenas.len())
		LoadSpawnPoints()

	AddPlayer(player, Arenas_List[0])

	player.ValidateScriptScope()
	player.GetScriptScope().NavThink <- function() {
		if (!Convars.GetInt("host_thread_mode")) {
			ResumeNavGeneration()
		}
		return 1
	}
	AddThinkToEnt(player, "NavThink")

	// Start generating
	nav_generation_state.generator = ArenaNavGenerator(only_this_arena)
	nav_generation_state.is_running = true
}

//EFL_KILLME effectively acts as a way to make any entity act like a preserved entity
::MGE_HUD <- CreateByClassname("game_text")

MGE_HUD.KeyValueFromString("targetname", "__mge_hud")
MGE_HUD.KeyValueFromInt("effect", 2)
MGE_HUD.KeyValueFromString("color", "255 254 255")
MGE_HUD.KeyValueFromString("color2", "255 254 255")
MGE_HUD.KeyValueFromFloat("fxtime", 1.0)
MGE_HUD.KeyValueFromFloat("holdtime", MGE_HUD_HOLDTIME)
MGE_HUD.KeyValueFromFloat("fadeout", 0.01)
MGE_HUD.KeyValueFromFloat("fadein", 0.01)
MGE_HUD.KeyValueFromInt("channel", 4)
MGE_HUD.KeyValueFromFloat("x", MGE_HUD_POS_X)
MGE_HUD.KeyValueFromFloat("y", MGE_HUD_POS_Y)
SetPropBool(MGE_HUD, "m_bForcePurgeFixedupStrings", true)
MGE_HUD.AddEFlags(EFL_KILLME)

::KOTH_HUD_RED <- CreateByClassname("game_text")

KOTH_HUD_RED.KeyValueFromString("targetname", "__mge_hud_koth_red")
KOTH_HUD_RED.KeyValueFromInt("effect", 2)
KOTH_HUD_RED.KeyValueFromString("color", KOTH_RED_HUD_COLOR)
KOTH_HUD_RED.KeyValueFromString("color2", "255 254 255")
KOTH_HUD_RED.KeyValueFromFloat("fxtime", 0.02)
KOTH_HUD_RED.KeyValueFromFloat("holdtime", 1.0)
KOTH_HUD_RED.KeyValueFromFloat("fadeout", 0.01)
KOTH_HUD_RED.KeyValueFromFloat("fadein", 0.01)
KOTH_HUD_RED.KeyValueFromInt("channel", 5)
KOTH_HUD_RED.KeyValueFromFloat("x", KOTH_HUD_RED_POS_X)
KOTH_HUD_RED.KeyValueFromFloat("y", KOTH_HUD_RED_POS_Y)
SetPropBool(KOTH_HUD_RED, "m_bForcePurgeFixedupStrings", true)
KOTH_HUD_RED.AddEFlags(EFL_KILLME)
::KOTH_HUD_BLU <- CreateByClassname("game_text")

KOTH_HUD_BLU.KeyValueFromString("targetname", "__mge_hud_koth_blu")
KOTH_HUD_BLU.KeyValueFromInt("effect", 2)
KOTH_HUD_BLU.KeyValueFromString("color", KOTH_BLU_HUD_COLOR)
KOTH_HUD_BLU.KeyValueFromString("color2", "255 254 255")
KOTH_HUD_BLU.KeyValueFromFloat("fxtime", 0.02)
KOTH_HUD_BLU.KeyValueFromFloat("holdtime", 1.0)
KOTH_HUD_BLU.KeyValueFromFloat("fadeout", 0.01)
KOTH_HUD_BLU.KeyValueFromFloat("fadein", 0.01)
KOTH_HUD_BLU.KeyValueFromInt("channel", 6)
KOTH_HUD_BLU.KeyValueFromFloat("x", KOTH_HUD_BLU_POS_X)
KOTH_HUD_BLU.KeyValueFromFloat("y", KOTH_HUD_BLU_POS_Y)
SetPropBool(KOTH_HUD_BLU, "m_bForcePurgeFixedupStrings", true)
KOTH_HUD_BLU.AddEFlags(EFL_KILLME)

MGE_Init()