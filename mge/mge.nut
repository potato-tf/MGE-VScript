::StockSounds <- [
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

	"vo/announcer_ends_5min.mp3",
	"vo/announcer_ends_2min.mp3",
	"vo/announcer_ends_60sec.mp3"
	"vo/announcer_ends_30sec.mp3"
	"vo/announcer_ends_20sec.mp3"
	"vo/announcer_ends_10sec.mp3",
	"vo/announcer_ends_5sec.mp3",
	"vo/announcer_ends_4sec.mp3",
	"vo/announcer_ends_3sec.mp3",
	"vo/announcer_ends_2sec.mp3",
	"vo/announcer_ends_1sec.mp3",

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

if (ENABLE_LEADERBOARD && ELO_TRACKING_MODE == 2)
	::MGE_LEADERBOARD_DATA <- {
		"Airshots"			 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Koth Points Capped" : array(MAX_LEADERBOARD_ENTRIES, null),
		"Hoops Scored" 		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Ammomod Kills"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Endif Wins"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Market Gardens" 	 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Scout Kills"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Soldier Kills"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Demoman Kills"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Arenas Played"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Deaths"			 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Damage Dealt"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Damage Taken"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Healing Done"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Healing Taken"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Revives"			 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Backstabs"			 : array(MAX_LEADERBOARD_ENTRIES, null),
	}

::ArenaClasses <- ["", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer", "civilian"]

::default_scope <- {
	"self"    : null,
	"__vname" : null,
	"__vrefs" : null,
}

//player think functions applied to special arenas
::special_arenas <- {
	function koth()
	{

		local player = self
		local scope = player.GetScriptScope()
		local arena = scope.arena_info.arena
		local arena_name = scope.arena_info.name

		if (arena.State == AS_IDLE)
		{
			if ("KothThink" in scope.ThinkTable)
				delete scope.ThinkTable.KothThink

			return
		}

		local partial_cap_cooldowntime = 0.0
		local cap_countdown_interval = 0.0
		local cap_decay_interval = 0.0

		local radius = arena.Koth.cap_radius
		local point = arena.Koth.cap_point
		local team = player.GetTeam()
		local partial_cap_amount = team == TF_TEAM_RED ? "red_partial_cap_amount" : "blu_partial_cap_amount"
		local enemy_partial_cap_amount = team == TF_TEAM_RED ? "blu_partial_cap_amount" : "red_partial_cap_amount"
		local cap_amount = team == TF_TEAM_RED ? "red_cap_time" : "blu_cap_time"
		local enemy_cap_amount = team == TF_TEAM_RED ? "blu_cap_time" : "red_cap_time"
		local additive_decay = arena.Koth.additive_decay

		//cap logic think
		scope.ThinkTable.KothThink <- function()
		{
			local owner_team = arena.Koth.owner_team

			if (!player.IsAlive()) return

			//we don't own it, start capping point
			if (owner_team != team && partial_cap_cooldowntime < Time() && (self.GetOrigin() - point).Length() < radius)
			{
				//revert enemy partial cap progress first
				if (arena.Koth[enemy_partial_cap_amount] > 0.0)
				{
					if (arena.Koth.additive_decay)
						arena.Koth[enemy_partial_cap_amount] -= arena.Koth.partial_cap_rate

					partial_cap_cooldowntime = Time() + (additive_decay ? arena.Koth.partial_cap_interval : arena.Koth.cap_decay_interval)
					return
				}
				//add partial cap progress
				arena.Koth[partial_cap_amount] += arena.Koth.partial_cap_rate

				//finished capping, we own it now, reset our partial cap progress for next time
				if (arena.Koth[partial_cap_amount] >= 1.0)
				{
					arena.Koth.owner_team = team
					arena.Koth[partial_cap_amount] = 0.0
					// arena.Koth[partial_cap_amount] = owner_team == self.GetTeam() ? 0.0 : 0.99
				}

				//hud stuff
				foreach(p, _ in arena.CurrentPlayers)
				{
					local _team = p.GetTeam()
					local ent = _team == TF_TEAM_RED ? KOTH_HUD_RED : KOTH_HUD_BLU
					local str = ""

					//we own it, show cap time
					if (owner_team == _team)
					{
						ent.KeyValueFromString("message", format("Cap Time: %.2f", arena.Koth[enemy_cap_amount]))
						ent.AcceptInput("Display", "", p, p)
						continue
					}
					//we don't own it, show partial cap progress
					ent.KeyValueFromString("message", format("Partial Cap: %.2f", arena.Koth[partial_cap_amount]))
					ent.AcceptInput("Display", "", p, p)

				}
				partial_cap_cooldowntime = Time() + arena.Koth.partial_cap_interval
				return
			}
			//we own it, switch to standard countdown timer
			else if (cap_countdown_interval < Time() && owner_team == team)
			{
				//decrease cap time
				arena.Koth[cap_amount] -= arena.Koth.countdown_rate

				//timer hit 0, we won this round
				if (!arena.Koth[cap_amount])
				{
					arena.Score[team == TF_TEAM_RED ? 0 : 1]++
					"koth_points_capped" in scope.stats ? scope.stats.koth_points_capped++ : scope.stats.koth_points_capped <- 1
					CalcArenaScore(arena_name)
					SetArenaState(arena_name, AS_COUNTDOWN)
					return
				}

				local _cap_amount = arena.Koth[cap_amount].tointeger()

				if (!_cap_amount) return

				//play countdown sound
				local _announcer_sound =  {
					[300] = "5min",
					[120] = "2min",
					[60] = "60sec",
					[30] = "30sec",
					[20] = "20sec",
					[10] = "10sec"
				}
				if (_cap_amount in _announcer_sound)
					foreach(p, _ in arena.CurrentPlayers)
						EmitSoundEx({
							sound_name = format("vo/announcer_ends_%s.mp3", _announcer_sound[_cap_amount]),
							entity = p,
							volume = 1.0,
							channel = CHAN_STREAM,
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER,
						})

				else if (_cap_amount < 6)
					foreach(p, _ in arena.CurrentPlayers)
						EmitSoundEx({
							sound_name = format("vo/announcer_ends_%dsec.mp3", _cap_amount),
							entity = p,
							volume = 1.0,
							channel = CHAN_STREAM,
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER,
						})
				//hud stuff
				foreach(p, _ in arena.CurrentPlayers)
				{
					KOTH_HUD_RED.KeyValueFromString("message", format("Cap Time: %d", arena.Koth.red_cap_time.tointeger()))
					KOTH_HUD_RED.AcceptInput("Display", "", p, p)
					KOTH_HUD_BLU.KeyValueFromString("message", format("Cap Time: %d", arena.Koth.blu_cap_time.tointeger()))
					KOTH_HUD_BLU.AcceptInput("Display", "", p, p)
				}

				cap_countdown_interval = Time() + arena.Koth.countdown_interval
				return
			}

			//we stopped capping, start decaying partial cap
			else if (cap_decay_interval < Time() && arena.Koth[partial_cap_amount] && (self.GetOrigin() - point).Length() > radius)
			{
				arena.Koth[partial_cap_amount] -= arena.Koth.decay_rate
				cap_decay_interval = Time() + arena.Koth.decay_interval
			}
		}
	}
	function bball()
	{
		local player = self
		local scope = player.GetScriptScope()
		local arena = scope.arena_info.arena
		local arena_name = scope.arena_info.name
		local team = player.GetTeam()
		local goal = team == TF_TEAM_RED ? arena.BBall.blue_hoop : arena.BBall.red_hoop
		scope.ThinkTable.BBallThink <- function() {
			if (scope.ball_ent && scope.ball_ent.IsValid())
			{
				//bball score think
				if ((self.GetOrigin() - goal).Length() < arena.BBall.hoop_size)
				{
					if (scope.ball_ent && scope.ball_ent.IsValid())
					{
						scope.ball_ent.Kill()
						scope.ball_ent = null
					}
					team == TF_TEAM_RED ? ++arena.Score[0] : ++arena.Score[1]
					"hoops_scored" in scope.stats ? scope.stats.hoops_scored++ : scope.stats.hoops_scored <- 1
					CalcArenaScore(arena_name)

					arena.BBall.last_score_team = team
					BBall_SpawnBall(arena_name)

					foreach(p, _ in arena.CurrentPlayers)
						p.ForceRespawn()
					return
				}
			}
		}
	}
	function midair()
	{
		local player = self
	}
	function turris()
	{
		local player = self
		local scope = player.GetScriptScope()
		scope.turris_cooldown <- 0.0
		scope.ThinkTable.TurrisThink <- function() {
			//redefine here to avoid reaching out of scope
			if (turris_cooldown < Time())
			{
				player.Regenerate(true)
				turris_cooldown = Time() + TURRIS_REGEN_TIME
			}
		}
	}
	function ammomod()
	{
		local player = self
		local scope = player.GetScriptScope()
		local arena = scope.arena_info.arena
		local arena_name = scope.arena_info.name
		// printl("attr : " + player.GetCustomAttribute("hidden maxhealth non buffed", 0))

		EntFireByHandle(player, "RunScriptCode", format(@"

			local hp_ratio = Arenas[`%s`].hpratio.tofloat()
			self.AddCustomAttribute(`max health additive bonus`,(self.GetMaxHealth() * hp_ratio) - self.GetMaxHealth(), -1)
			self.AddCustomAttribute(`mod see enemy health`, 1, -1)
			//this quirk is for reducing falldmg
			self.AddCustomAttribute(`dmg taken increased`, 1 / hp_ratio, -1)
			self.AddCustomAttribute(`dmg from ranged reduced`, hp_ratio, -1)
			self.Regenerate(true)

		", arena_name), GENERIC_DELAY, null, null)
	}
	function endif()
	{
		local player = self

		for (local child = player.FirstMoveChild(); child; child = child.NextMovePeer())
			if (child instanceof CEconEntity && GetPropInt(child, STRING_NETPROP_ITEMDEF) == ID_MANTREADS)
				EntFireByHandle(child, "Kill", "", -1, null, null)


		// if (player.GetCustomAttribute("hidden maxhealth non buffed", 0)) return
		EntFireByHandle(player, "RunScriptCode", format(@"

			self.AddCustomAttribute(`cancel falling damage`, 1, -1)
			self.AddCustomAttribute(`hidden maxhealth non buffed`, %d - self.GetMaxHealth(), -1)
			self.AddCustomAttribute(`health regen`, %d, -1)
			self.Regenerate(true)

		", 9999, 9999), -1, null, null)
	}
	function infammo()
	{
		local player = self
		local scope = player.GetScriptScope()
		scope.ThinkTable.InfAmmoThink <- function() {
			local weapon = player.GetActiveWeapon()
			local itemid = GetPropInt(weapon, STRING_NETPROP_ITEMDEF)
			if (weapon && weapon.Clip1() < weapon.GetMaxClip1() && itemid != ID_BEGGARS_BAZOOKA)
				weapon.SetClip1(weapon.GetMaxClip1())

			if (weapon && GetPropFloat(weapon, "m_flEnergy") != weapon.GetMaxClip1() && (itemid == ID_COW_MANGLER_5000 || itemid == ID_RIGHTEOUS_BISON || itemid == ID_POMSON_6000))
				SetPropFloat(weapon, "m_flEnergy", 20)

			SetPropIntArray(self, "m_iAmmo", 9999, 1)
			SetPropIntArray(self, "m_iAmmo", 9999, 2)
		}
	}
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
			", progress,arenas_len), generate_delay + GENERIC_DELAY)

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
		", generate_delay + GENERIC_DELAY)
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
MGE_HUD.KeyValueFromFloat("holdtime", INT_MAX)
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