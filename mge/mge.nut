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
::ALL_PLAYERS <- {}

local local_time = {}
LocalTime(local_time)
::SERVER_DATA <- {
	endpoint_url = "https://archive.potato.tf/api/serverstatus"
	server_key = ""
	address = 0
	map = GetMapName()
	max_wave = -1
	// mission = GetMapName()
	mission = ""
	players_blu = 0
	players_connecting = 0
	players_max = MaxClients().tointeger()
	players_red = 0
	region = ""
	server_name = ""
	classes = ""
	is_fake_ip = false
	steam_ids = []
	in_protected_match = false
	matchmaking_disable_time = 0
	server_name = ""

	status = "Waiting for players"
	update_time = {
		year = local_time.year
		month = local_time.month
		day = local_time.day
		hour = local_time.hour
		minute = local_time.minute
		second = local_time.second
	}
	domain = "potato.tf"
	password = ""
	wave = 0
	campaign_name = "MGE"
}

EntFire("worldspawn", "RunScriptCode", @"

	local hostname = GetStr(`hostname`)
	local _split = split(hostname, `#`)
	local _split_region = _split.len() == 1 ? [``, `]`] : split(_split[1], `[`)
	SERVER_DATA.server_name = GetStr(`hostname`)
	SERVER_DATA.server_key = _split.len() == 1 ? `` : _split[1].slice(0, _split[1].find(`[`))
	SERVER_DATA.region = _split_region.len() == 1 ? `` : _split_region[1].slice(0, _split_region[1].find(`]`))
	SERVER_DATA.domain = SERVER_DATA.region == `USA` ? `us.potato.tf` : format(`%s.%s`, SERVER_DATA.region.tolower(), SERVER_DATA.domain)

	if ( SERVER_DATA.domain == `ustx.potato.tf` )
		SERVER_DATA.domain += `:22443`
", 5)


if (ENABLE_LEADERBOARD && (ELO_TRACKING_MODE > 1 || LEADERBOARD_DEBUG))
	::MGE_LEADERBOARD_DATA <- {
		"ELO"				 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Airshots"			 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Koth Points Capped" : array(MAX_LEADERBOARD_ENTRIES, null),
		"Hoops Scored" 		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Market Gardens" 	 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Wins"				 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Losses"			 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Kills"				 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Deaths"			 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Damage Dealt"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		"Damage Taken"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		// "Ammomod Kills"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		// "Endif Wins"		 	 : array(MAX_LEADERBOARD_ENTRIES, null),
		// "Scout Kills"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		// "Soldier Kills"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		// "Demoman Kills"		 : array(MAX_LEADERBOARD_ENTRIES, null),
		// "Arenas Played"		 : array(MAX_LEADERBOARD_ENTRIES, null),
	}

::ArenaClasses <- ["", "scout", "sniper", "soldier", "demoman", "medic", "heavy", "pyro", "spy", "engineer", "civilian"]

::default_scope <- {
	"self"    : null,
	"__vname" : null,
	"__vrefs" : null,
}

//player think functions applied to special arenas
//all scoring logic for koth and bball are handled here

//this table is also used as a reference for all valid special arenas elsewhere in the code
//if a new custom arena is created, you must add a function to this table
// (it doesn't need to do anything, see allmeat, 4player, and midair)
::special_arenas <- {

	function koth()
	{
		local player = self
		scope <- player.GetScriptScope()
		local arena = scope.arena_info.arena
		local arena_name = scope.arena_info.name
		local arena_players = arena.CurrentPlayers.keys()

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
		local current_cappers = arena.Koth.current_cappers
		local cap_contested = false

		if (typeof point == "string")
		{
			local point_vector = split(point, " ").apply(@(v) ToStrictNum(v, true))
			point_vector = Vector(point_vector[0], point_vector[1], point_vector[2])

			point = point_vector
		}
		//cap logic think
		function scope::ThinkTable::KothThink()
		{
			local owner_team = arena.Koth.owner_team
			local arena_players = arena.CurrentPlayers.keys()

			if (!player.IsAlive()) return
			if ((player.GetOrigin() - point).Length() < radius)
			{
				if (!(player in current_cappers) || !current_cappers[player])
					current_cappers[player] <- true

				foreach(p, is_capping in current_cappers)
				{
					if (p.GetTeam() != player.GetTeam() && is_capping)
					{
						cap_contested = true
						break
					}
					cap_contested = false
				}
				if (owner_team != team && partial_cap_cooldowntime < Time() && !cap_contested)
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
					if (!cap_contested)
						arena.Koth[partial_cap_amount] += arena.Koth.partial_cap_rate

					//finished capping, we own it now, reset our partial cap progress for next time
					if (arena.Koth[partial_cap_amount] >= 1.0)
					{
						arena.Koth.owner_team = team
						arena.Koth[partial_cap_amount] = 0.0

						if ("RulesetVote" in arena && "cap_point" in arena.RulesetVote && arena.RulesetVote.cap_point && arena.RulesetVote.cap_point.IsValid())
						{
							local cap_model = arena.RulesetVote.cap_point
							cap_model.SetTeam(owner_team)
							cap_model.FirstMoveChild().SetTeam(owner_team) //glow teleporter
						}
					}

					//hud stuff
					local _team = player.GetTeam()
					local str = ["", ""]
					if (arena.Koth[partial_cap_amount] != 0.0)
						str[_team == TF_TEAM_RED ? 0 : 1] = format("Partial Cap: %.2f", arena.Koth[partial_cap_amount])
					if (arena.Koth[enemy_partial_cap_amount] != 0.0)
						str[_team == TF_TEAM_RED ? 1 : 0] = format("Partial Cap: %.2f", arena.Koth[enemy_partial_cap_amount])

					foreach(p in arena_players)
					{
						if (p.GetScriptScope().enable_hud)
						{
							KOTH_HUD_RED.KeyValueFromString("message", format("Cap Time: %d\n%s", arena.Koth.red_cap_time.tointeger(), str[0]))
							KOTH_HUD_BLU.KeyValueFromString("message", format("Cap Time: %d\n%s", arena.Koth.blu_cap_time.tointeger(), str[1]))

							KOTH_HUD_RED.AcceptInput("Display", "", p, p)
							KOTH_HUD_BLU.AcceptInput("Display", "", p, p)
						}
					}
					KOTH_HUD_RED.KeyValueFromString("message", "")
					KOTH_HUD_BLU.KeyValueFromString("message", "")

					partial_cap_cooldowntime = Time() + arena.Koth.partial_cap_interval
					return
				}
			}
			//we stopped capping
			else
			{
				current_cappers[player] <- false

				//start decaying partial cap
				if (cap_decay_interval < Time() && arena.Koth[partial_cap_amount] > 0.0)
				{
					arena.Koth[partial_cap_amount] -= arena.Koth.decay_rate
					cap_decay_interval = Time() + arena.Koth.decay_interval
				}
			}
			//we own it, switch to standard countdown timer
			if (cap_countdown_interval < Time() && owner_team == team)
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
					foreach(p in arena_players)
						EmitSoundEx({
							sound_name = format("vo/announcer_ends_%s.mp3", _announcer_sound[_cap_amount]),
							entity = p,
							volume = 1.0,
							channel = CHAN_STREAM,
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER,
						})

				else if (_cap_amount < 6)
					foreach(p in arena_players)
						EmitSoundEx({
							sound_name = format("vo/announcer_ends_%dsec.mp3", _cap_amount),
							entity = p,
							volume = 1.0,
							channel = CHAN_STREAM,
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER,
						})

				//hud stuff
				foreach(p in arena_players)
				{
					if (!p.GetScriptScope().enable_hud) continue

					KOTH_HUD_RED.KeyValueFromString("message", format("Cap Time: %d", arena.Koth.red_cap_time.tointeger()))
					KOTH_HUD_RED.AcceptInput("Display", "", p, p)
					KOTH_HUD_BLU.KeyValueFromString("message", format("Cap Time: %d", arena.Koth.blu_cap_time.tointeger()))
					KOTH_HUD_BLU.AcceptInput("Display", "", p, p)
				}

				cap_countdown_interval = Time() + arena.Koth.countdown_interval
				return
			}
		}
	}
	function bball()
	{
		local player = self
		scope <- player.GetScriptScope()
		local arena = scope.arena_info.arena
		local arena_name = scope.arena_info.name
		local arena_players = arena.CurrentPlayers.keys()
		local team = player.GetTeam()
		local goal = team == TF_TEAM_RED ? arena.BBall.blue_hoop : arena.BBall.red_hoop

		function scope::ThinkTable::BBallThink() {

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
					if (arena.State == AS_AFTERFIGHT)
					{
						arena.BBall.last_score_team = -1
						return
					}
					arena.BBall.last_score_team = team
					BBall_SpawnBall(arena_name)

					foreach(p in arena_players)
						p.ForceRespawn()
					return
				}
			}
		}
	}
	function midair()
	{
		return
	}
	function turris()
	{
		local player = self
		scope <- player.GetScriptScope()
		scope.turris_cooldown <- 0.0
		function scope::ThinkTable::TurrisThink() {
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

		EntFireByHandle(player, "RunScriptCode", format(@"

			if (self.GetCustomAttribute(`max health additive bonus`, 0)) return
			local hp_ratio = Arenas[`%s`].hpratio.tofloat()
			self.AddCustomAttribute(`max health additive bonus`,(self.GetMaxHealth() * hp_ratio) - self.GetMaxHealth(), -1)
			self.AddCustomAttribute(`mod see enemy health`, 1, -1)

			//this is for reducing falldmg
			self.AddCustomAttribute(`dmg taken increased`, 1 / hp_ratio, -1)
			self.AddCustomAttribute(`dmg from ranged reduced`, hp_ratio, -1)
			self.AddCustomAttribute(`dmg from melee increased`, hp_ratio, -1)

			self.Regenerate(true)

		", arena_name), GENERIC_DELAY, null, null)
	}
	function endif()
	{
		local player = self

		for (local child = player.FirstMoveChild(); child; child = child.NextMovePeer())
		{
			if (child instanceof CEconEntity && GetPropInt(child, STRING_NETPROP_ITEMDEF) == ID_MANTREADS)
			{
				ENDIF_DELETE_MANTREADS ? EntFireByHandle(child, "Kill", "", -1, null, null) : RemovePlayer(player)
				MGE_ClientPrint(player, HUD_PRINTTALK, "EndifMantreads")
				break
			}
		}

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
		scope <- player.GetScriptScope()

		function scope::ThinkTable::InfAmmoThink() {

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
	function allmeat()
	{
		return
	}
	"4player" : function() { //function names that start with a number need this special syntax
		return
	}
}

function ROOT::MGE_Init() {

	printl("[VScript MGE] Loaded, moving all active players to spectator")

	for (local i = 1; i <= MAX_CLIENTS; i++)
	{
		local player = PlayerInstanceFromIndex(i)
		if (!player || !player.IsValid()) continue

		player.ValidateScriptScope()
		InitPlayerScope(player)

		ALL_PLAYERS[player] <- GetPropIntArray(FindByClassname(null, "tf_player_manager"), "m_iUserID", player.entindex())

		local scope = player.GetScriptScope()
		player.ForceChangeTeam(TEAM_SPECTATOR, true)
		GetStats(player)
		// todo bots dont like to stay dead with this, need to come up with something else
		/*
			SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", 0)
		*/
	}

	if (ELO_TRACKING_MODE > 1)
	{
		printl(MGE_Localization[DEFAULT_LANGUAGE]["VPI_InitDB"])
		VPI.AsyncCall({
			func = "VPI_MGE_DBInit",
			function callback (response, error) {
				printl(MGE_Localization[DEFAULT_LANGUAGE][error ? "VPI_DBInitError" : "VPI_DBInitSuccess"])
			}
		})
	}

	HandleRoundStart()
	LoadSpawnPoints()

	SetValue("mp_humans_must_join_team", "spectator")
	SetValue("mp_autoteambalance", 0)
	SetValue("mp_teams_unbalance_limit", 0)
	SetValue("mp_scrambleteams_auto", 0)
	SetValue("mp_tournament", 0)
	SetValue("mp_chattime", 1.0)

	SetValue("tf_weapon_criticals", 0)
	SetValue("tf_fall_damage_disablespread", 1)

	//requires a custom plugin to feed m_iszMvMPopfileName to SteamWorks_SetGameDescription
	//might be able to do this through VPI?
	local gamedesc = format("Potato MGE (%s)", MGE_MAPINFO[GetMapName()].nice_name)
	SetPropString(FindByClassname(null, "tf_objective_resource"), "m_iszMvMPopfileName",  gamedesc)
}

for (local cleanup; cleanup = FindByName(cleanup, "__mge*");)
	EntFireByHandle(cleanup, "Kill", "", -1, null, null)

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

EntFire("bignet", "RunScriptCode", "DispatchSpawn(MGE_HUD); DispatchSpawn(KOTH_HUD_RED); DispatchSpawn(KOTH_HUD_BLU)", GENERIC_DELAY)

::MGE_CHANGELEVEL <- CreateByClassname("point_intermission")
MGE_CHANGELEVEL.KeyValueFromString("targetname", "__mge_changelevel")

if (GAMEMODE_AUTOUPDATE_REPO && GAMEMODE_AUTOUPDATE_REPO != "")
{
	MGE_CHANGELEVEL.ValidateScriptScope()
	ChangelevelScope <- MGE_CHANGELEVEL.GetScriptScope()

	function ChangelevelScope::AutoUpdate() {
		VPI.AsyncCall({
			func = "VPI_MGE_AutoUpdate",
			kwargs = {
				repo = GAMEMODE_AUTOUPDATE_REPO,
				branch = GAMEMODE_AUTOUPDATE_BRANCH,
				clone_dir = GAMEMODE_AUTOUPDATE_TARGET_DIR
			},
			function callback(response, error) {

				//gamemode has been updated
				if (!error && response.len()) {

					local time_left = MGE_TIMER.GetScriptScope().base_timestamp - Time()

					MGE_ClientPrint(null, HUD_PRINTTALK, "GamemodeUpdate", time_left > GAMEMODE_AUTOUPDATE_RESTART_TIME ? GAMEMODE_AUTOUPDATE_RESTART_TIME : time_left)
					MGE_ClientPrint(null, HUD_PRINTTALK, "GamemodeUpdate", time_left > GAMEMODE_AUTOUPDATE_RESTART_TIME ? GAMEMODE_AUTOUPDATE_RESTART_TIME : time_left)
					MGE_ClientPrint(null, HUD_PRINTTALK, "GamemodeUpdate", time_left > GAMEMODE_AUTOUPDATE_RESTART_TIME ? GAMEMODE_AUTOUPDATE_RESTART_TIME : time_left)

					printl("Files changed:")

					foreach(file in response)
						printl(file)

					printl("[MGE VScript] Got new gamemode version via git")

					if (time_left > GAMEMODE_AUTOUPDATE_RESTART_TIME)
					{
						printl("[MGE VScript] updating map restart time...")
						EntFire("__mge_timer", "SetTime", format("%d", GAMEMODE_AUTOUPDATE_RESTART_TIME))
					}

				} else if (!response.len()) {
					printl("[MGE VScript] No gamemode updates found")
				}
			}
		})
		return GAMEMODE_AUTOUPDATE_INTERVAL
	}
	AddThinkToEnt(MGE_CHANGELEVEL, "AutoUpdate")
}

::MGE_CLIENTCOMMAND <- CreateByClassname("point_clientcommand")
MGE_CLIENTCOMMAND.KeyValueFromString("targetname", "__mge_clientcommand")
DispatchSpawn(MGE_CLIENTCOMMAND)

::MGE_TIMER <- CreateByClassname("team_round_timer")
MGE_TIMER.KeyValueFromString("targetname", "__mge_timer")

SetPropInt(MGE_TIMER, "m_nTimerMaxLength", MAP_RESTART_TIMER)
SetPropInt(MGE_TIMER, "m_nTimerInitialLength", MAP_RESTART_TIMER)
SetPropInt(MGE_TIMER, "m_nTimerLength", MAP_RESTART_TIMER)
SetPropBool(MGE_TIMER, "m_bShowInHUD", true)
SetPropBool(MGE_TIMER, "m_bShowTimeRemaining", true)
SetPropBool(MGE_TIMER, "m_bAutoCountdown", true)
SetPropBool(MGE_TIMER, "m_bStartPaused", false)

//doesn't fire with with EFL_KILLME
AddOutput(MGE_TIMER, "OnFinished", "!self", "CallScriptFunction", "MGE_DoChangelevel", 1.0, -1)

DispatchSpawn(MGE_TIMER)
MGE_TIMER.AcceptInput("Resume", "", null, null)

//this crashes windows servers
//mysteriously isolating this entire team_round_timer spawn sequence to another file doesn't crash
//maybe EFL_KILLME being added briefly in teamplay_round_start?
// MGE_TIMER.AcceptInput("ShowInHUD", "1", null, null)

EntFireByHandle(MGE_TIMER, "ShowInHUD", "1", -1, null, null)

MGE_TIMER.ValidateScriptScope()

TimerScope <- MGE_TIMER.GetScriptScope()
TimerScope.time_left <- GetPropFloat(MGE_TIMER, "m_flTimeRemaining")
TimerScope.base_timestamp <- GetPropFloat(MGE_TIMER, "m_flTimeRemaining")

function TimerScope::InputSetTime() {

	base_timestamp = GetPropFloat(MGE_TIMER, "m_flTimeRemaining")
	return true

}
TimerScope.Inputsettime <- TimerScope.InputSetTime
TimerScope.hinted <- false

function TimerScope::TimerThink()
{
	local time_left = base_timestamp - Time()

	if (time_left > 0)
	{
		if (!(time_left % VPI_SERVERINFO_UPDATE_INTERVAL))
		{
			LocalTime(local_time)
			SERVER_DATA.update_time = local_time
			SERVER_DATA.max_wave = time_left
			SERVER_DATA.wave = time_left
			local players = array(2, 0)
			local spectators = 0
			foreach (player, userid in ALL_PLAYERS)

			{
				if (!player || !player.IsValid() || player.IsFakeClient()) continue

				if (player.GetTeam() == TEAM_SPECTATOR)
					spectators++
				else
					players[player.GetTeam() == TF_TEAM_RED ? 0 : 1]++
			}
			SERVER_DATA.players_red = players[0]
			SERVER_DATA.players_blu = players[1]
			SERVER_DATA.players_connecting = spectators
			SERVER_DATA.server_name = GetStr("hostname")

			if (UPDATE_SERVER_DATA) {

				VPI.AsyncCall({
					func = "VPI_MGE_UpdateServerData",
					kwargs = SERVER_DATA,

					function callback(response, error) {

						if (error) 
							return 3

						if (SERVER_DATA.address == 0 && "address" in response)
							SERVER_DATA.address = response.address

					}
				})
			}
		}

		// Show countdown message in last minute
		if (time_left < 60 && !(time_left.tointeger() % 10))
		{
			if (!hinted)
			{
				SendGlobalGameEvent("player_hintmessage", {hintmessage = format("MAP RESTART IN %d SECONDS", time_left.tointeger())})
				hinted = true
				EntFireByHandle(self, "RunScriptCode", "self.GetScriptScope().hinted = false", 1.1, null, null)
			}
		}


		return -1
	}

	delete TimerScope.TimerThink
}
AddThinkToEnt(MGE_TIMER, "TimerThink")
MGE_Init()