::HandleRoundStart <- function()
{
	local tf_gamerules = FindByClassname(null, "tf_gamerules")
	if (tf_gamerules)
	{
		SetPropBool(tf_gamerules, "m_bInWaitingForPlayers", false)
		tf_gamerules.AcceptInput("SetRedTeamRespawnWaveTime", "99999", null, null)
		tf_gamerules.AcceptInput("SetBlueTeamRespawnWaveTime", "99999", null, null)
	}

	// Hide respawn text
	local player_manager = FindByClassname(null, "tf_player_manager")
	if (player_manager)
	{
		player_manager.ValidateScriptScope()
		local prop_array_size = GetPropArraySize(player_manager, "m_flNextRespawnTime")
		player_manager.GetScriptScope().HideRespawnText <- function() {
			foreach (player, userid in ALL_PLAYERS)
			{
				if (!player || !player.IsValid() || player.IsFakeClient()) continue

				SetPropFloatArray(player_manager, "m_flNextRespawnTime", -1, player.entindex())
			}
			return -1
		}
		AddThinkToEnt(player_manager, "HideRespawnText")
	}
}

::PreserveEnts <- function(preserve = true)
{
	for (local ent; ent = FindByName(ent, "__mge*");)
		preserve ? ent.AddEFlags(EFL_KILLME) : ent.RemoveEFlags(EFL_KILLME)
}

::InitPlayerScope <- function(player)
{
	player.ValidateScriptScope()
	local scope = player.GetScriptScope()

	// Clear scope
	foreach (k, v in scope)
		if (!(k in default_scope))
			delete scope[k]

	local toscope = {
		ThinkTable = {
			//potentially useful for fake custom cvars in vscript
			//read some cvar like cl_class in a think and watch for changes
			//cl_class vscript_cvar_here 5 then split the string in GetClientConvarValue to get `vscript_cvar_here 5`
			// function ConCommandHijack()
			// {

			// }

		},
		cvarhijack =  Convars.GetClientConvarValue("cl_class", player.entindex())
		Name       = Convars.GetClientConvarValue("name", player.entindex()),
		Language   = Convars.GetClientConvarValue("cl_language", player.entindex()),
		arena_info = null,
		queue      = null,
		stats      = {
			elo = -INT_MAX
			wins = -INT_MAX,
			losses = -INT_MAX,
			kills = -INT_MAX,
			deaths = -INT_MAX,
			damage_taken = -INT_MAX,
			damage_dealt = -INT_MAX,
			airshots = -INT_MAX,
			market_gardens = -INT_MAX,
			hoops_scored = -INT_MAX,
			koth_points_capped = -INT_MAX,
			name = Convars.GetClientConvarValue("name", player.entindex())
		},
		enable_announcer = true,
		enable_countdown = true,
		won_last_match = false,
		ball_ent = null
	}

	foreach (k, v in toscope)
		scope[k] <- v

	scope.PlayerThink <- function() {
		foreach(name, func in scope.ThinkTable)
			func.call(scope)
		return PLAYER_THINK_INTERVAL
	}
	AddThinkToEnt(player, "PlayerThink")
}

::ForceChangeClass <- function(player, classIndex)
{
	player.SetPlayerClass(classIndex)
	SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", classIndex)
}

::ValidatePlayerClass <- function(player, newclass, pre=false)
{
	local scope = player.GetScriptScope()
	if (!("arena_info" in scope) || !scope.arena_info) return

	local arena = scope.arena_info.arena
	local classes = arena.classes
	if (!classes.len()) return

	newclass = ArenaClasses[newclass]   // Get string version of class
	if (classes.find(newclass) != null) // Class is in the whitelist
		return

	if (pre)
		ForceChangeClass(player, player.GetPlayerClass())
	else
		ForceChangeClass(player, ("scout" in classes) ? TF_CLASS_SCOUT : ArenaClasses.find(classes[0]))

	MGE_ClientPrint(player, 3, "ClassIsNotAllowed", newclass)
}
// tointeger() allows trailing garbage (e.g. "123abc")
// This will only allow strictly integers (also floats with only zeroes: e.g "1.00")
::ToStrictNum <-  function(str, float = false)
{
//	local rex = regexp(@"-?[0-9]+(\.0+)?")  // [-](digit)[.(>0 zeroes)]
	local rex = regexp(@"-?[0-9]+(\.[0-9]+)?")
	if (!rex.match(str)) return

	try
		return float ? str.tofloat() : str.tointeger()
	catch (_)
		return
}
 //calling this function with no arena argument passed will
 //load spawn points for all arenas
 //configure rulesets (bball koth etc)
 //load arena indexes for !add
 //this should only be called with no args once at script load

 //passing a specific arena will refresh the rulesets temporarily for use in !rulesets
 //it does NOT initialize anything, only modifies the existing data
 
 //passing an arena name and setting arena_reset to true will convert the existing arena to a standard MGE arena
::LoadSpawnPoints <-  function(custom_ruleset_arena_name = null, arena_reset = false)
{
	local config = SpawnConfigs[GetMapName()]

	//custom ruleset handling
	if (custom_ruleset_arena_name && !arena_reset)
	{
		local _arena = config[custom_ruleset_arena_name]
		printl("RulesetVote" in _arena)
		_arena.Score          <- array(2, 0)

		//0 breaks our countdown system, default to 1
		// _arena.cdtime         <- "cdtime" in _arena ? _arena.cdtime != "0" ? _arena.cdtime : 1 : DEFAULT_CDTIME
		_arena.MaxPlayers     <- "4player" in _arena && _arena["4player"] == "1" ? 4 : 2
		// _arena.classes        <- "classes" in _arena ? split(_arena.classes, " ", true) : []
		// _arena.fraglimit      <- "fraglimit" in _arena ? _arena.fraglimit.tointeger() : DEFAULT_FRAGLIMIT
		// _arena.SpawnIdx       <- 0

		//do this instead of checking both of these everywhere
		_arena.IsMGE          <- "mge" in _arena && _arena.mge == "1"
		_arena.IsUltiduo      <- "ultiduo" in _arena && _arena.ultiduo == "1"
		_arena.IsKoth         <- "koth" in _arena && _arena.koth == "1"
		_arena.IsBBall        <- "bball" in _arena && _arena.bball == "1"
		_arena.IsAmmomod      <- "ammomod" in _arena && _arena.ammomod == "1"
		_arena.IsTurris       <- "turris" in _arena && _arena.turris == "1"
		_arena.IsEndif        <- "endif" in _arena && _arena.endif == "1"
		_arena.IsMidair       <- "midair" in _arena && _arena.midair == "1"

		//new keyvalues
		_arena.countdown_sound 		  	<- "countdown_sound" in _arena ? _arena.countdown_sound : COUNTDOWN_SOUND
		_arena.countdown_sound_volume 	<- "countdown_sound_volume" in _arena ? _arena.countdown_sound_volume : COUNTDOWN_SOUND_VOLUME
		_arena.round_start_sound 		<- "round_start_sound" in _arena ? _arena.round_start_sound : ROUND_START_SOUND
		_arena.round_start_sound_volume <- "round_start_sound_volume" in _arena ? _arena.round_start_sound_volume : ROUND_START_SOUND_VOLUME
		_arena.airshot_height_threshold <- "airshot_height_threshold" in _arena ? _arena.airshot_height_threshold : AIRSHOT_HEIGHT_THRESHOLD

		if (_arena.IsUltiduo)
		{
			_arena.Ultiduo <- {
				CurrentMedics = array(2, null)
			}
		}
		if (_arena.IsBBall)
		{
			//alternative keyvalues for bball logic
			//if you intend on adding > 8 spawns, you will need to replace your current "9" - "13" entries with these
			local bball_points = {
				neutral_home = "bball_home" in _arena ? _arena.bball_home : _arena["9"],
				red_score_home = "bball_home_red" in _arena ? _arena.bball_home_red : _arena["10"],
				blue_score_home = "bball_home_blue" in _arena ? _arena.bball_home_blue : _arena["11"],
				red_hoop = "bball_hoop_red" in _arena ? _arena.bball_hoop_red : _arena["12"],
				blue_hoop = "bball_hoop_blue" in _arena ? _arena.bball_hoop_blue : _arena["13"],
				hoop_size = "bball_hoop_size" in _arena ? _arena.bball_hoop_size : BBALL_HOOP_SIZE,
				pickup_model = "bball_pickup_model" in _arena ? _arena.bball_pickup_model : BBALL_BALL_MODEL,
				particle_pickup_red = "bball_particle_pickup_red" in _arena ? _arena.bball_particle_pickup_red : BBALL_PARTICLE_PICKUP_RED,
				particle_pickup_blue = "bball_particle_pickup_blue" in _arena ? _arena.bball_particle_pickup_blue : BBALL_PARTICLE_PICKUP_BLUE,
				particle_pickup_generic = "bball_particle_pickup_generic" in _arena ? _arena.bball_particle_pickup_generic : BBALL_PARTICLE_PICKUP_GENERIC,
				particle_trail_red = "bball_particle_trail_red" in _arena ? _arena.bball_particle_trail_red : BBALL_PARTICLE_TRAIL_RED,
				particle_trail_blue = "bball_particle_trail_blue" in _arena ? _arena.bball_particle_trail_blue : BBALL_PARTICLE_TRAIL_BLUE,
				last_score_team = -1
			}

			foreach (k, v in bball_points)
			{
				if (typeof v != "string") continue
				local split_spawns = split(v, " ")
				split_spawns.apply( @(str) ToStrictNum(str, true) )
				local spawn_lens = {
					[3] = true,
					[4] = true,
					[6] = true,
				}
				if (split_spawns.len() in spawn_lens)
					bball_points[k] <- Vector(split_spawns[0], split_spawns[1], split_spawns[2])
			}
			printl("test5")
			printl("RulesetVote" in _arena)
			_arena.BBall <- bball_points
			BBall_SpawnBall(custom_ruleset_arena_name)
			printl("RulesetVote" in _arena)

		}
		if (_arena.IsKoth)
		{
			//alternative keyvalues for KOTH logic
			//koth_radius is a new kv that you can set per-arena
			_arena.Koth <- {
				//see BBall notes about adding more spawns, koth uses the final index for cap points
				cap_point = "koth_cap" in _arena ? _arena.koth_cap : ""
				cap_radius = "koth_radius" in _arena ? _arena.koth_radius : KOTH_DEFAULT_CAPTURE_POINT_RADIUS
				owner_team = 0

				blu_partial_cap_amount = 0.0
				red_partial_cap_amount = 0.0
				// timelimit = 0.0
				// timeleft = 0.0

				// is_overtime = false

				red_start_cap_time = "start_time_red" in _arena ? _arena.start_time_red : KOTH_START_TIME_RED
				blu_start_cap_time = "start_time_blu" in _arena ? _arena.start_time_blu : KOTH_START_TIME_BLUE


				decay_rate 		     = "koth_decay_rate" in _arena ? _arena.koth_decay_rate : KOTH_DECAY_RATE,
				decay_interval	     = "koth_decay_interval" in _arena ? _arena.koth_decay_interval : KOTH_DECAY_INTERVAL,
				additive_decay       = "koth_additive_decay" in _arena ? _arena.koth_additive_decay : KOTH_ADDITIVE_DECAY,
				countdown_rate     	 = "koth_countdown_rate" in _arena ? _arena.koth_countdown_rate : KOTH_COUNTDOWN_RATE,
				countdown_interval 	 = "koth_countdown_interval" in _arena ? _arena.koth_countdown_interval : KOTH_COUNTDOWN_INTERVAL,
				partial_cap_rate   	 = "koth_partial_cap_rate" in _arena ? _arena.koth_partial_cap_rate : KOTH_PARTIAL_CAP_RATE,
				partial_cap_interval = "koth_partial_cap_interval" in _arena ? _arena.koth_partial_cap_interval : KOTH_PARTIAL_CAP_INTERVAL,

				capture_point_radius     = "koth_capture_point_radius" in _arena ? _arena.koth_capture_point_radius : KOTH_CAPTURE_POINT_MAX_HEIGHT,
				capture_point_max_height = "koth_capture_point_max_height" in _arena ? _arena.koth_capture_point_max_height : KOTH_CAPTURE_POINT_MAX_HEIGHT,
			}
			_arena.Koth.red_cap_time <- _arena.Koth.red_start_cap_time
			_arena.Koth.blu_cap_time <- _arena.Koth.blu_start_cap_time
		}

		if (_arena.IsEndif)
		{
			_arena.Endif <- {
				height_threshold = "endif_height_threshold" in _arena ? _arena.endif_height_threshold : ENDIF_HEIGHT_THRESHOLD
			}
		}
		if (_arena.IsMidair)
		{
			_arena.Midair <- {
				height_threshold = "midair_height_threshold" in _arena ? _arena.midair_height_threshold : AIRSHOT_HEIGHT_THRESHOLD
			}
		}
		// Grab spawn points
		foreach(k, v in _arena)
		{
			local spawn_idx = ToStrictNum(k)
			if (spawn_idx != null)
			{
				try
				{
					if (
						(_arena.IsBBall && spawn_idx > BBALL_MAX_SPAWNS) ||
						(_arena.IsKoth && spawn_idx > KOTH_MAX_SPAWNS) 	||
						(_arena.IsUltiduo && spawn_idx > ULTIDUO_MAX_SPAWNS)
					) continue

					local split_spawns = split(v, " ", true).apply( @(str) str.tofloat() )

					local origin = Vector(split_spawns[0], split_spawns[1], split_spawns[2])

					local angles = QAngle()
					if (split_spawns.len() == 4)
						angles = QAngle(0, split_spawns[3], 0) // Yaw only
					else if (split_spawns.len() == 6)
						angles = QAngle(split_spawns[3], split_spawns[4], split_spawns[5])

					local spawn = [origin, angles, TEAM_UNASSIGNED]

					if (_arena.MaxPlayers > 2)
						spawn[2] = spawn_idx < 4 ? TF_TEAM_RED : TF_TEAM_BLUE

					_arena.SpawnPoints.append(spawn)
				}
				catch(e)
					printf("[VSCRIPT MGE] Warning: Data parsing for arena '%s' failed: %s\nkey: %s, val: %s\n", arena_name, e.tostring(), k, v.tostring())
			}
		}
		local idx = (_arena.SpawnPoints.len() + 1).tostring()
		if (_arena.IsKoth && idx in _arena)
		{
			// printl(arena_name)
			// printl(_arena.IsKoth && idx in _arena)
			// printl(_arena.SpawnPoints.len())
			local cap_point = split(_arena[idx], " ").apply( @(str) str.tofloat() )
			_arena.Koth.cap_point = Vector(cap_point[0], cap_point[1], cap_point[2])
		}

		//rulset updated, re-add everyone to the arena
		Arenas[custom_ruleset_arena_name] <- _arena
		foreach(p, _ in _arena.CurrentPlayers)
		{
			RemovePlayer(p, custom_ruleset_arena_name)
			AddPlayer(p, custom_ruleset_arena_name)
		}
		return
	}

	// if (ELO_TRACKING_MODE == 2 && ENABLE_LEADERBOARD)
	if (ENABLE_LEADERBOARD)
	{
		//MGE_LEADERBOARD_DATA
		compilestring(FileToString("leaderboard.nut"))()
		::DoLeaderboardCam <- function()
		{
			//spawn our camera
			::MGE_LeaderboardCam <- CreateByClassname("info_observer_point")
			SetPropBool(MGE_LeaderboardCam, "m_bForcePurgeFixedUpStrings", true)
			MGE_LeaderboardCam.KeyValueFromString("targetname", "__mge_leaderboard_cam")
			MGE_LeaderboardCam.KeyValueFromInt("fov",  120)
			DispatchSpawn(MGE_LeaderboardCam)

			local leaderboard_cam_pos = Vector()
			local leaderboard_cam_angles = QAngle()

			// this config has a leaderboard cam position set
			if ("leaderboard_cam" in config)
			{
				local origin = split(config.leaderboard_cam, " ").apply( @(str) str.tofloat() )
				local origin_len = origin.len()
				leaderboard_cam_pos = Vector(origin[0], origin[1], origin[2])

				if (origin_len == 4)
					leaderboard_cam_angles = QAngle(origin[3], 0.0, 0.0)
				else if (origin_len == 6)
					leaderboard_cam_angles = QAngle(origin[3], origin[4], origin[5])

				MGE_LeaderboardCam.SetOrigin(leaderboard_cam_pos)
				MGE_LeaderboardCam.SetAbsAngles(leaderboard_cam_angles - QAngle(0, 180, 0))
				return
			}

			//no config pos found, find a cam with a wall behind it
			local cams = []
			local welcome_cams = []
			for (local cam; cam = FindByClassname(cam, "info_observer_point");)
			{
				//check the welcome cam first
				GetPropBool(cam, "m_bDefaultWelcome") ? welcome_cams.append(cam) : cams.append(cam)
			}

			if (welcome_cams.len())
				cams = welcome_cams.extend(cams)

			local valid_cams = []
			foreach (_cam in cams)
			{
				//this shouldn't happen but whatever
				if (_cam.GetName() == "__mge_leaderboard_cam")
					continue

				local cam_angle_inverse = (_cam.GetAbsAngles() - QAngle(0, 180, 0))
				local endpos = _cam.GetOrigin() + cam_angle_inverse.Forward() * LEADERBOARD_FORWARD_OFFSET
				local trace = TraceLine(_cam.GetOrigin(), endpos, _cam)

				// DebugDrawLine(_cam.GetOrigin(), endpos, 255, 100, 255, true, 10)

				if (trace && trace == 1)
					valid_cams.append(_cam)
			}
			local random_cam = valid_cams.len() == 1 ? valid_cams[0] : valid_cams[RandomInt(0, valid_cams.len() - 1)]
			local random_cam_angle_inverse = (random_cam.GetAbsAngles() - QAngle(0, 180, 0))

			MGE_LeaderboardCam.SetOrigin(random_cam.GetOrigin())
			MGE_LeaderboardCam.SetAbsAngles(random_cam_angle_inverse)

			local leaderboard_pos = (random_cam.GetOrigin() + (random_cam_angle_inverse.Forward() * LEADERBOARD_FORWARD_OFFSET)) + Vector(0, 0, LEADERBOARD_VERTICAL_OFFSET)

			::MGE_Leaderboard <- CreateByClassname("point_worldtext")

			MGE_Leaderboard.KeyValueFromString("targetname", "__mge_leaderboard_text")
			MGE_Leaderboard.KeyValueFromString("message", "      Placeholder:\n       #9999 | aaaa\n")
			MGE_Leaderboard.KeyValueFromInt("textsize", LEADERBOARD_TEXT_SIZE)
			MGE_Leaderboard.KeyValueFromString("color", "255 255 255")
			MGE_Leaderboard.KeyValueFromInt("orientation", 1)
			MGE_Leaderboard.SetOrigin(leaderboard_pos)
			SetPropBool(MGE_Leaderboard, "m_bForcePurgeFixedUpStrings", true)
			DispatchSpawn(MGE_Leaderboard)
			MGE_Leaderboard.ValidateScriptScope()

			local think_override = LEADERBOARD_UPDATE_INTERVAL
			MGE_Leaderboard.GetScriptScope().UpdateLeaderboard <- function() {
				// Store the keys and current index to track progress across yields
				if (!("_current_stat_index" in this))
					this._current_stat_index <- 0

				local stat_keys = MGE_LEADERBOARD_DATA.keys()

				local stat_index = this._current_stat_index

				local stat = stat_keys[stat_index in stat_keys ? stat_index : 0]
				
				// printl("populating leaderboard")

				local column_name = ""
				split(stat, " ").apply( @(str) column_name += format("_%s", str.tolower()) )
				column_name = column_name.slice(1)

				VPI.AsyncCall({
					func="VPI_MGE_PopulateLeaderboard",
					kwargs= {
						order_filter = column_name,
						max_leaderboard_entries = MAX_LEADERBOARD_ENTRIES,
					},
					callback=function(response, error) {
						if (typeof(response) != "array" || !response.len())
						{
							// MGE_ClientPrint(player, 3, "VPI_ReadError", "Could not populate leaderboard")
							// MGE_ClientPrint(player, 2, "VPI_ReadError", "Could not populate leaderboard")
							printl(format(MGE_Localization[DEFAULT_LANGUAGE]["VPI_ReadError"], "Could not populate leaderboard"))
							return
						}
						foreach (i, r in response)
						{
							// foreach (j, _r in r)
								// printl(j + " : " + _r)
							local data = MGE_LEADERBOARD_DATA[stat]
							data[i] = r
						}
						// MGE_LEADERBOARD_DATA <- data
						// MGE_ClientPrint(player, 3, "VPI_ReadSuccess",  "Populated leaderboard")
						// MGE_ClientPrint(player, 2, "VPI_ReadSuccess",  "Populated leaderboard")
						// printf(MGE_Localization[DEFAULT_LANGUAGE]["VPI_ReadSuccess"], data[0].tostring())
					}
				})

				// Process one stat per yield
				if (this._current_stat_index < stat_keys.len()) {
					local steamid_list = MGE_LEADERBOARD_DATA[stat]

					local message = format("          %s:\n", stat)
					foreach(i, user_info in steamid_list)
					{
						if (!user_info)
						{
							think_override = 0.2
							user_info = ["NONE", -INT_MAX]
						} else {
							think_override = LEADERBOARD_UPDATE_INTERVAL
						}
						
						// foreach( u in user_info)
							// printl(u)
						local name = 2 in user_info && user_info[2] ? user_info[2] : user_info[0]
						message += format("\n          %d | %s | %d\n", i + 1, name.tostring(), user_info[1])
					}
					MGE_Leaderboard.KeyValueFromString("message", message)
					
					this._current_stat_index++
					yield
				}
				
				// Reset index and refresh data when done with all stats
				this._current_stat_index = 0
			}
			MGE_Leaderboard.GetScriptScope().LeaderboardThink <- function() {
				local gen = UpdateLeaderboard()
				resume gen
				return think_override
			}
			AddThinkToEnt(MGE_Leaderboard, "LeaderboardThink")
		}
		//delay this until ents are spawned
		EntFire("worldspawn", "CallScriptFunction", "DoLeaderboardCam", GENERIC_DELAY)
	}

	if (!arena_reset)
		Arenas_List <- array(config.len(), null)

	local idx_failed = false
	foreach(arena_name, _arena in config)
	{
		if (arena_reset && arena_name != custom_ruleset_arena_name) continue

		if (arena_reset)
		{
			_arena.mge <- "1"
			_arena.IsMGE <- true
			_arena.IsCustomRuleset <- false
			_arena.RulesetVote <- {}
			foreach(k, v in special_arenas)
			{
				if (k in _arena)
					_arena[k] = "0"

				_arena.RulesetVote[k] <- array(2, false)
			}
		}

		Arenas[arena_name] <- _arena

		_arena.CurrentPlayers <- {}
		_arena.Queue          <- []
		_arena.SpawnPoints    <- []
		_arena.Score          <- array(2, 0)
		_arena.State          <- AS_IDLE
		//0 breaks our countdown system, default to 1
		_arena.cdtime         <- "cdtime" in _arena ? _arena.cdtime != "0" ? _arena.cdtime : 1 : DEFAULT_CDTIME
		_arena.MaxPlayers     <- "4player" in _arena && _arena["4player"] == "1" ? 4 : 2
		// _arena.MaxPlayers     <- 1 //debug
		_arena.classes        <- "classes" in _arena && typeof _arena.classes != "array" ? split(_arena.classes, " ", true) : []
		_arena.fraglimit      <- "fraglimit" in _arena ? _arena.fraglimit.tointeger() : DEFAULT_FRAGLIMIT
		_arena.SpawnIdx       <- 0

		//do this instead of checking both of these everywhere
		_arena.IsMGE          <- "mge" in _arena && _arena.mge == "1"
		_arena.IsUltiduo      <- "ultiduo" in _arena && _arena.ultiduo == "1"
		_arena.IsKoth         <- "koth" in _arena && _arena.koth == "1"
		_arena.IsBBall        <- "bball" in _arena && _arena.bball == "1"
		_arena.IsAmmomod      <- "ammomod" in _arena && _arena.ammomod == "1"
		_arena.IsTurris       <- "turris" in _arena && _arena.turris == "1"
		_arena.IsEndif        <- "endif" in _arena && _arena.endif == "1"
		_arena.IsMidair       <- "midair" in _arena && _arena.midair == "1"

		//new keyvalues
		_arena.countdown_sound <- "countdown_sound" in _arena ? _arena.countdown_sound : COUNTDOWN_SOUND
		_arena.countdown_sound_volume <- "countdown_sound_volume" in _arena ? _arena.countdown_sound_volume : COUNTDOWN_SOUND_VOLUME
		_arena.round_start_sound <- "round_start_sound" in _arena ? _arena.round_start_sound : ROUND_START_SOUND
		_arena.round_start_sound_volume <- "round_start_sound_volume" in _arena ? _arena.round_start_sound_volume : ROUND_START_SOUND_VOLUME
		_arena.airshot_height_threshold <- "airshot_height_threshold" in _arena ? _arena.airshot_height_threshold : AIRSHOT_HEIGHT_THRESHOLD

		if (_arena.IsMGE && !("IsCustomRuleset" in _arena) && !("RulesetVote" in _arena))
		{
			_arena.IsCustomRuleset <- false
			_arena.RulesetVote <- {}
			foreach(k, _ in special_arenas)
				_arena.RulesetVote[k] <- array(2, false)
		}

		if (_arena.IsUltiduo)
		{
			_arena.Ultiduo <- {
				CurrentMedics = array(2, null)
			}
		}
		if (_arena.IsBBall)
		{
			//alternative keyvalues for bball logic
			//if you intend on adding > 8 spawns, you will need to replace your current "9" - "13" entries with these
			local bball_points = {
				neutral_home = "bball_home" in _arena ? _arena.bball_home : _arena["9"],
				red_score_home = "bball_home_red" in _arena ? _arena.bball_home_red : _arena["10"],
				blue_score_home = "bball_home_blue" in _arena ? _arena.bball_home_blue : _arena["11"],
				red_hoop = "bball_hoop_red" in _arena ? _arena.bball_hoop_red : _arena["12"],
				blue_hoop = "bball_hoop_blue" in _arena ? _arena.bball_hoop_blue : _arena["13"],
				hoop_size = "bball_hoop_size" in _arena ? _arena.bball_hoop_size : BBALL_HOOP_SIZE,
				pickup_model = "bball_pickup_model" in _arena ? _arena.bball_pickup_model : BBALL_BALL_MODEL,
				particle_pickup_red = "bball_particle_pickup_red" in _arena ? _arena.bball_particle_pickup_red : BBALL_PARTICLE_PICKUP_RED,
				particle_pickup_blue = "bball_particle_pickup_blue" in _arena ? _arena.bball_particle_pickup_blue : BBALL_PARTICLE_PICKUP_BLUE,
				particle_pickup_generic = "bball_particle_pickup_generic" in _arena ? _arena.bball_particle_pickup_generic : BBALL_PARTICLE_PICKUP_GENERIC,
				particle_trail_red = "bball_particle_trail_red" in _arena ? _arena.bball_particle_trail_red : BBALL_PARTICLE_TRAIL_RED,
				particle_trail_blue = "bball_particle_trail_blue" in _arena ? _arena.bball_particle_trail_blue : BBALL_PARTICLE_TRAIL_BLUE,
				last_score_team = -1
			}

			foreach (k, v in bball_points)
			{
				if (typeof v != "string") continue
				local split_spawns = split(v, " ")
				split_spawns.apply( @(str) ToStrictNum(str, true) )
				local spawn_lens = {
					[3] = true,
					[4] = true,
					[6] = true,
				}
				if (split_spawns.len() in spawn_lens)
					bball_points[k] <- Vector(split_spawns[0], split_spawns[1], split_spawns[2])
			}

			_arena.BBall <- bball_points
			BBall_SpawnBall(arena_name)

		}
		if (_arena.IsKoth)
		{
			//alternative keyvalues for KOTH logic
			//koth_radius is a new kv that you can set per-arena
			_arena.Koth <- {
				//see BBall notes about adding more spawns, koth uses the final index for cap points
				cap_point = "koth_cap" in _arena ? _arena.koth_cap : ""
				cap_radius = "koth_radius" in _arena ? _arena.koth_radius : KOTH_DEFAULT_CAPTURE_POINT_RADIUS
				owner_team = 0

				blu_partial_cap_amount = 0.0
				red_partial_cap_amount = 0.0
				// timelimit = 0.0
				// timeleft = 0.0

				// is_overtime = false

				red_start_cap_time = "start_time_red" in _arena ? _arena.start_time_red : KOTH_START_TIME_RED
				blu_start_cap_time = "start_time_blu" in _arena ? _arena.start_time_blu : KOTH_START_TIME_BLUE


				decay_rate 		     = "koth_decay_rate" in _arena ? _arena.koth_decay_rate : KOTH_DECAY_RATE,
				decay_interval	     = "koth_decay_interval" in _arena ? _arena.koth_decay_interval : KOTH_DECAY_INTERVAL,
				additive_decay       = "koth_additive_decay" in _arena ? _arena.koth_additive_decay : KOTH_ADDITIVE_DECAY,
				countdown_rate     	 = "koth_countdown_rate" in _arena ? _arena.koth_countdown_rate : KOTH_COUNTDOWN_RATE,
				countdown_interval 	 = "koth_countdown_interval" in _arena ? _arena.koth_countdown_interval : KOTH_COUNTDOWN_INTERVAL,
				partial_cap_rate   	 = "koth_partial_cap_rate" in _arena ? _arena.koth_partial_cap_rate : KOTH_PARTIAL_CAP_RATE,
				partial_cap_interval = "koth_partial_cap_interval" in _arena ? _arena.koth_partial_cap_interval : KOTH_PARTIAL_CAP_INTERVAL,

				capture_point_radius     = "koth_capture_point_radius" in _arena ? _arena.koth_capture_point_radius : KOTH_CAPTURE_POINT_MAX_HEIGHT,
				capture_point_max_height = "koth_capture_point_max_height" in _arena ? _arena.koth_capture_point_max_height : KOTH_CAPTURE_POINT_MAX_HEIGHT,
			}

			_arena.Koth.red_cap_time <- _arena.Koth.red_start_cap_time
			_arena.Koth.blu_cap_time <- _arena.Koth.blu_start_cap_time
		}

		if (_arena.IsEndif)
		{
			_arena.Endif <- {
				height_threshold = "endif_height_threshold" in _arena ? _arena.endif_height_threshold : ENDIF_HEIGHT_THRESHOLD
			}
		}
		if (_arena.IsMidair)
		{
			_arena.Midair <- {
				height_threshold = "midair_height_threshold" in _arena ? _arena.midair_height_threshold : AIRSHOT_HEIGHT_THRESHOLD
			}
		}
		local idx = ("idx" in _arena) ? _arena.idx.tointeger() : null
		if (idx == null && !idx_failed)
		{
			idx_failed = true

			local new_list = []
			foreach (arena in Arenas_List)
				if (arena != null)
					new_list.append(arena)
			Arenas_List = new_list
		}

		if (idx_failed)
			Arenas_List.append(arena_name)
		else
			Arenas_List[idx] = arena_name

		// Grab spawn points
		foreach(k, v in _arena)
		{
			local spawn_idx = ToStrictNum(k)
			if (spawn_idx != null)
			{
				try
				{

					if (
						(_arena.IsBBall && spawn_idx > BBALL_MAX_SPAWNS) ||
						(_arena.IsKoth && spawn_idx > KOTH_MAX_SPAWNS) 	||
						(_arena.IsUltiduo && spawn_idx > ULTIDUO_MAX_SPAWNS)
					) continue

					local split_spawns = split(v, " ", true).apply( @(str) str.tofloat() )

					local origin = Vector(split_spawns[0], split_spawns[1], split_spawns[2])

					local angles = QAngle()
					if (split_spawns.len() == 4)
						angles = QAngle(0, split_spawns[3], 0) // Yaw only
					else if (split_spawns.len() == 6)
						angles = QAngle(split_spawns[3], split_spawns[4], split_spawns[5])

					local spawn = [origin, angles, TEAM_UNASSIGNED]

					if (_arena.MaxPlayers > 2)
						spawn[2] = spawn_idx < 4 ? TF_TEAM_RED : TF_TEAM_BLUE

					_arena.SpawnPoints.append(spawn)
				}
				catch(e)
					printf("[VSCRIPT MGE] Warning: Data parsing for arena '%s' failed: %s\nkey: %s, val: %s\n", arena_name, e.tostring(), k, v.tostring())
			}
		}
		local idx = (_arena.SpawnPoints.len() + 1).tostring()
		if (_arena.IsKoth && idx in _arena)
		{
			// printl(arena_name)
			// printl(_arena.IsKoth && idx in _arena)
			// printl(_arena.SpawnPoints.len())
			local cap_point = split(_arena[idx], " ").apply( @(str) str.tofloat() )
			_arena.Koth.cap_point = Vector(cap_point[0], cap_point[1], cap_point[2])
		}
	}
}

::BBall_SpawnBall <-  function(arena_name, origin_override = null, custom_ruleset_arena = false)
{
	local arena = Arenas[arena_name]
	local bball_points = custom_ruleset_arena ? {} : arena.BBall
	local last_score_team = custom_ruleset_arena ? -1 : arena.BBall.last_score_team

	local ground_ball = CreateByClassname("tf_halloween_pickup")

	ground_ball.KeyValueFromString("pickup_sound", BBALL_PICKUP_SOUND)
	ground_ball.KeyValueFromString("pickup_particle", BBALL_PARTICLE_PICKUP_GENERIC)
	ground_ball.KeyValueFromString("powerup_model", BBALL_BALL_MODEL)

	// printl(bball_points.neutral_home)

	//I did this specifically to annoy mince
	ground_ball.SetOrigin(origin_override ? origin_override : last_score_team == -1 ? bball_points.neutral_home : last_score_team == TF_TEAM_RED ? bball_points.red_score_home : bball_points.blue_score_home)

	AddOutput(ground_ball, "OnPlayerTouch", "!activator", "RunScriptCode", "BBall_Pickup(self);", 0.0, 1)
	AddOutput(ground_ball, "OnPlayerTouch", "!self", "Kill", "", SINGLE_TICK, 1)

	if (!custom_ruleset_arena)
	{
		if ("ground_ball" in arena.BBall && arena.BBall.ground_ball.IsValid())
			arena.BBall.ground_ball.Kill()

		arena.BBall.ground_ball <- ground_ball
	} else {
		if ("ground_ball" in arena.RulesetVote && arena.RulesetVote.ground_ball.IsValid())
			arena.RulesetVote.ground_ball.Kill()

		arena.RulesetVote.ground_ball <- ground_ball
	}

	EntFireByHandle(ground_ball, "RunScriptCode", "DispatchSpawn(self)", 0.2, null, null)
}

::BBall_Pickup <- function(player)
{
	local scope = player.GetScriptScope()
	if (scope.ball_ent && scope.ball_ent.IsValid())
		return

	local ball_ent = CreateByClassname("funCBaseFlex")

	ball_ent.SetOrigin(player.GetOrigin())
	ball_ent.SetModel(BBALL_BALL_MODEL)
	ball_ent.SetCollisionGroup(COLLISION_GROUP_DEBRIS)
	ball_ent.SetSolid(SOLID_NONE)
	ball_ent.SetOwner(player)
	ball_ent.KeyValueFromString("targetname", format("__ball_%d", player.entindex()))
	ball_ent.DisableDraw()
	scope.ball_ent <- ball_ent

	local arena = scope.arena_info.arena
	// local visbit = 0
	foreach (p, _ in arena.CurrentPlayers)
	{
		// visbit = 1 << p.entindex() | visbit
		// SendGlobalGameEvent("show_annotation", {
		// 	visibilityBitfield = visbit
		// 	text = format("%s has the flag!", player.GetScriptScope().Name)
		// 	lifetime = 3.0
		// 	play_sound = BBALL_PICKUP_SOUND
		// 	follow_entindex = player.entindex()
		// 	show_distance = true
		// 	show_effect = true
		// })
		EmitSoundEx({
			sound_name = BBALL_PICKUP_SOUND,
			entity = p,
			volume = BBALL_PICKUP_SOUND_VOLUME,
			channel = CHAN_STREAM,
			sound_level = 65
		})
		ClientPrint(p, 3, p == player ? "You have the ball!" : format("%s has the ball!", player.GetScriptScope().Name))
	}

	printl(ball_ent)

	EntFireByHandle(ball_ent, "SetParent", "!activator", -1, player, player)
	EntFireByHandle(ball_ent, "SetParentAttachment", "flag", -1, player, player)
	EntFireByHandle(ball_ent, "RunScriptCode", "DispatchSpawn(self)", GENERIC_DELAY, null, null)

	printl(ball_ent)

	DispatchParticleEffect(player.GetTeam() == TF_TEAM_RED ? BBALL_PARTICLE_PICKUP_RED : BBALL_PARTICLE_PICKUP_BLUE, player.GetOrigin(), Vector(0, 90, 0))
	EntFire(format("__mge_bball_trail_%d", player.GetTeam()), "StartTouch", "!activator", -1, player)

	printl(ball_ent)
}

::AddBot <- function(arena_name)
{
	if (typeof(arena_name) == "string" && !(arena_name in Arenas)) return
	if (typeof(arena_name) == "integer")
	{
		--arena_name
		if (arena_name > Arenas_List.len() - 1 || arena_name < 0) return
		arena_name = Arenas_List[arena_name]
	}

	// Ideally find a bot that isn't currently in an arena, but we aren't picky at the end of the day
	local abot = null
	local bot  = null
	foreach (player, userid in ALL_PLAYERS)
	{
		if (!player || !player.IsValid() || !player.IsFakeClient()) continue

		player.ValidateScriptScope()
		local scope = player.GetScriptScope()

		if(!("stats" in scope))
			GetStats(player)

		if (!bot && !scope.arena_info)
		{
			bot = player
			break
		}
		if (!abot && scope.arena_info)
			abot = player
	}
	if (!bot && !abot) return

	AddPlayer((bot) ? bot : abot, arena_name)
}

::RemoveBot <- function(arena_name, all=false)
{
	if (typeof(arena_name) == "string" && !(arena_name in Arenas)) return
	if (typeof(arena_name) == "integer")
	{
		--arena_name
		if (arena_name > Arenas_List.len() - 1 || arena_name < 0) return
		arena_name = Arenas_List[arena_name]
	}

	local arena = Arenas[arena_name]

	// Remove active bot(s)
	foreach (player, _ in arena.CurrentPlayers)
	{
		if (player.IsFakeClient())
		{
			player.ForceChangeTeam(TEAM_UNASSIGNED, true)
			SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", 0)

			RemovePlayer(player, false)

			if (!all) return
		}
	}

	// No active bot(s) found, remove from queue
	local rem = []
	foreach (idx, player in arena.Queue)
	{
		if (player.IsFakeClient())
			rem.append(player)

		if (!all) break
	}
	foreach (player in rem)
	{
		player.ForceChangeTeam(TEAM_UNASSIGNED, true)
		SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", 0)
		RemovePlayer(player, false)
	}
}

::RemoveAllBots <- function()
{
	foreach (arena_name, _ in Arenas)
		RemoveBot(arena_name, true)
}

::AddPlayer <- function(player, arena_name)
{
	local arena = Arenas[arena_name]
	local current_players = arena.CurrentPlayers

	if (player in current_players || arena.Queue.find(player) != null)
	{
		ClientPrint(player, 3, "Already in arena")
		return
	}

	local scope = player.GetScriptScope()

	RemovePlayer(player, false)

	MGE_ClientPrint(player, 3, "ChoseArena", arena_name)

	// Enough room, add to arena
	if (current_players.len() < arena.MaxPlayers)
	{
		AddToArena(player, arena_name)
		local name = scope.Name
		local elo = scope.stats.elo
		// printl(arena_name)
		local str = ELO_TRACKING_MODE ?
			format(GetLocalizedString("JoinsArena", player), name, elo.tostring(), arena_name) :
			format(GetLocalizedString("JoinsArenaNoStats", player), scope.Name, arena_name)
		MGE_ClientPrint(null, 3, str)
	}
	// Add to queue
	else
	{
		arena.Queue.append(player)
		scope.queue <- arena.Queue

		local idx = arena.Queue.len() - 1
		local str = (idx == 0) ? format(GetLocalizedString("NextInLine", player), arena.Queue.len().tostring()) : format(GetLocalizedString("InLine", player), arena.Queue.len().tostring())
		MGE_ClientPrint(player, 3, str)
	}
}

::AddToArena <- function(player, arena_name)
{
	local scope = player.GetScriptScope()
	local arena = Arenas[arena_name]
	local current_players = arena.CurrentPlayers

	scope.endif_killme <- false
	scope.endif_firstspawn <- true
	scope.queue <- null
	scope.arena_info <- {
		arena = arena,
		name  = arena_name,
		team = player.GetTeam()
	}

	// Choose the team with the lower amount of players
	local red  = 0, blue = 0
	foreach(p, _ in current_players)
	{
		if (p.GetTeam() == TF_TEAM_RED)
			++red
		else if (p.GetTeam() == TF_TEAM_BLUE)
			++blue
	}

	local team = null
	if (red == blue)
		team = RandomInt(TF_TEAM_RED, TF_TEAM_BLUE)
	else
		team = (red < blue) ? TF_TEAM_RED : TF_TEAM_BLUE

	// Make sure spectators have a class chosen to be able to spawn
	if (!GetPropInt(player, "m_Shared.m_iDesiredPlayerClass"))
	{
			ForceChangeClass(player, TF_CLASS_SCOUT)
			player.ForceRespawn()
	}

	// Spawn (goto player_spawn)
	player.ForceChangeTeam(team, true)
	scope.arena_info.team = team
	player.ForceRespawn()
	current_players[player] <- scope.stats.elo

	//shitfix, fixes CurrentPlayers not updating
	EntFireByHandle(player, "RunScriptCode", format("self.ForceRespawn()", arena_name), GENERIC_DELAY, null, null)

	// EntFireByHandle(KOTH_HUD_BLU, "RunScriptCode", "DispatchSpawn(self); self.RemoveEFlags(EFL_KILLME)", 1.0, null, null)
}

::RemovePlayer <- function(player, changeteam=true)
{
	local scope = player.GetScriptScope()

	if ("ThinkTable" in scope)
		scope.ThinkTable.clear()

	if (changeteam && player.GetTeam() != TEAM_SPECTATOR)
		player.ForceChangeTeam(TEAM_SPECTATOR, true)

	if (scope.queue)
	{
		for (local i = scope.queue.len() - 1; i >= 0; --i)
			if (scope.queue[i] == player)
			{
				scope.queue.remove(i)
				break
			}

		scope.queue <- null
	}

	if (scope.arena_info)
	{
		local arena = scope.arena_info.arena
		local arena_name = scope.arena_info.name

		if (arena.Queue.find(player) != null)
			arena.Queue.remove(player)

		if (player in arena.CurrentPlayers)
		{
			delete arena.CurrentPlayers[player]
			SetArenaState(arena_name, AS_IDLE)
		}
		// if ("IsCustomRuleset" in arena && arena.IsCustomRuleset)
		// {
		// 	LoadSpawnPoints(arena_name, true)
		// }
	}
}

::CycleQueue <- function(arena_name)
{
	local arena = Arenas[arena_name]

	local queue = arena.Queue

	if (!queue.len())
	{
		local i = 0
		foreach (p, _ in arena.CurrentPlayers)
		{
			i++
			RemovePlayer(p)
			// AddPlayer(p, arena_name)
			EntFireByHandle(p, "RunScriptCode", format("AddPlayer(self, `%s`)", arena_name), i * GENERIC_DELAY, null, null)
			break
		}
		return
	}

	local next_player = queue[0]

	foreach (p, _ in arena.CurrentPlayers)
		if (!p.GetScriptScope().won_last_match)
			RemovePlayer(p)

	AddToArena(next_player, arena_name)

	queue.remove(0)

	SetArenaState(arena_name, AS_IDLE)

	foreach(i, p in queue)
		MGE_ClientPrint(p, 3, "InLine", (i + 1))
}


::CalcELO <- function(winner, loser) {
	// Early validation
	if (!ELO_TRACKING_MODE || !winner || !loser ||
		!winner.IsValid() || !loser.IsValid() ||
		winner.IsFakeClient() || loser.IsFakeClient()) {
		return
	}

	local winner_stats = winner.GetScriptScope().stats
	local loser_stats = loser.GetScriptScope().stats
	local winner_elo = winner_stats.elo
	local loser_elo = loser_stats.elo

	// Calculate expected probability
	local expected_prob = 1.0 / (pow(10.0, (winner_elo - loser_elo).tofloat() / 400) + 1)

	// Calculate K-factor based on ELO
	local k_winner = (winner_elo >= 2400) ? 10 : 15
	local k_loser = (loser_elo >= 2400) ? 10 : 15

	// Calculate score changes
	local winner_gain = floor(k_winner * expected_prob + 0.5)
	local loser_loss = floor(k_loser * expected_prob + 0.5)

	// Update ELOs
	winner_stats.elo = winner_elo + winner_gain
	loser_stats.elo = loser_elo - loser_loss

	//update W/L
	"wins" in winner_stats ? winner_stats.wins++ : winner_stats.wins <- 1
	"losses" in loser_stats ? loser_stats.losses++ : loser_stats.losses <- 1

	// Print results to players
	if (winner.IsValid())
		MGE_ClientPrint(winner, 3, "GainedPoints", winner_gain.tostring())
	if (loser.IsValid())
		MGE_ClientPrint(loser, 3, "LostPoints", loser_loss.tostring())

	// Update stats in database/file
	UpdateStats(winner, winner_stats, false)
	UpdateStats(loser, loser_stats, false)
}

::CalcELO2 <- function(winner, winner2, loser, loser2) {

	if (winner.IsFakeClient() || loser.IsFakeClient() || !ELO_TRACKING_MODE || loser2.IsFakeClient() || winner2.IsFakeClient())
		return

	local Losers_ELO = (loser.stats.elo + loser2.stats.elo).tofloat() / 2
	local Winners_ELO = (winner.stats.elo + winner2.stats.elo).tofloat() / 2

	// ELO formula
	local El = 1 / (pow(10.0, (Winners_ELO - Losers_ELO) / 400) + 1)
	local k = (Winners_ELO >= 2400) ? 10 : 15
	local winnerscore = floor(k * El + 0.5)
	winner.stats.elo += winnerscore
	winner2.stats.elo += winnerscore
	k = (Losers_ELO >= 2400) ? 10 : 15
	local loserscore = floor(k * El + 0.5)
	loser.stats.elo -= loserscore
	loser2.stats.elo -= loserscore

	// local winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner]
	// local loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser]

	// local arena_index = winner.arena
	// local time = Time()

	// if (winner && winner.IsValid() && !g_bNoDisplayRating)
	//     ClientPrint(winner, 3, format("You gained %d points!", winnerscore))

	// if (winner2 && winner2.IsValid() && !g_bNoDisplayRating)
	//     ClientPrint(winner2, 3, format("You gained %d points!", winnerscore))

	// if (loser && loser.IsValid() && !g_bNoDisplayRating)
	//     ClientPrint(loser, 3, format("You lost %d points!", loserscore))

	// if (loser2 && loser2.IsValid() && !g_bNoDisplayRating)
	//     ClientPrint(loser2, 3, format("You lost %d points!", loserscore))
}

::CalcArenaScore <- function(arena_name)
{
	local arena = Arenas[arena_name]

	local fraglimit = arena.fraglimit.tointeger()

	//round over
	if (arena.Score[0] >= fraglimit || arena.Score[1] >= fraglimit)
	{
		local winner, loser

		foreach(p, _ in arena.CurrentPlayers)
		{
			if (arena.Score[0] >= fraglimit && p.GetTeam() == TF_TEAM_RED)
				winner = p
			else if (arena.Score[1] >= fraglimit && p.GetTeam() == TF_TEAM_BLUE)
				winner = p
			else
				loser = p
		}

		local loser_scope = loser ? loser.GetScriptScope() : false
		local winner_scope = winner ? winner.GetScriptScope() : false

		if (!winner || !loser) return

		loser_scope.won_last_match = false
		winner_scope.won_last_match = true

		MGE_ClientPrint(null, 3, "XdefeatsY",
			winner_scope.Name,
			winner_scope.stats.elo.tostring(),
			loser_scope.Name,
			loser_scope.stats.elo.tostring(),
			fraglimit.tostring(),
		arena_name)
		CalcELO(winner, loser)
		SetArenaState(arena_name, AS_AFTERFIGHT)
	}
}

::TryGetClearSpawnPoint <- function(player, arena_name)
{
	local arena   = Arenas[arena_name]
	local spawns  = arena.SpawnPoints
	local mindist = ("mindist" in arena) ? arena.mindist.tofloat() : 0.0;
	local idx = arena.SpawnIdx

	for (local i = 0; i < MAX_CLEAR_SPAWN_RETRIES; ++i)
	{
		idx = GetNextSpawnPoint(player, arena_name)
		local spawn = spawns[idx]
		if (!mindist) return idx

		local clear = true

		for (local p; p = FindByClassnameWithin(p, "player", spawn[0], mindist);)
		{
			if (p.IsValid() && p.IsAlive())
			{
				clear = false
				break
			}
		}
		if (clear) return idx
	}

	return idx
}

::GetNextSpawnPoint <- function(player, arena_name)
{
	local arena = Arenas[arena_name]

	//most non-MGE configs have fixed spawn rotations per team
	if (!arena.IsMGE && !arena.IsEndif)
	{
		local end = -1
		local idx = arena.SpawnIdx
		if (arena.IsKoth)
			end = KOTH_MAX_SPAWNS
		else if (arena.IsBBall)
			end = BBALL_MAX_SPAWNS
		else if (arena.IsUltiduo)
			end = ULTIDUO_MAX_SPAWNS

		end--

		local team = player.GetTeam()
		if (team == TF_TEAM_RED)
			end /= 2

		idx = (idx + 1) % end
		if (team == TF_TEAM_BLUE)
			idx += (arena.SpawnPoints.len() / 2) - 1

		printl(idx + " : " + end + " : " + arena.SpawnPoints.len())
		// if ("IsCustomRuleset" in arena && arena.IsCustomRuleset)
		arena.SpawnIdx = idx

		return idx
	}

	local shuffleModes = {
		[0] = function() {
			arena.SpawnIdx = (arena.SpawnIdx + 1) % arena.SpawnPoints.len()
		},
		[1] = function() {

			if (!("SpawnPointsOriginal" in arena))
			{
				arena.SpawnPointsOriginal <- clone arena.SpawnPoints
				local len = arena.SpawnPointsOriginal.len()
				for (local i = len - 1; i > 0; i--)
				{
					local j = RandomInt(0, i)
					local temp = arena.SpawnPoints[i]
					arena.SpawnPoints[i] = arena.SpawnPoints[j]
					arena.SpawnPoints[j] = temp
				}
			}
			arena.SpawnIdx = (arena.SpawnIdx + 1) % arena.SpawnPoints.len()
		},
		[2] = function() {
			while (player.GetScriptScope().last_spawn_point == arena.SpawnIdx)
				arena.SpawnIdx = RandomInt(0, arena.SpawnPoints.len() - 1)
		},
		// [3] = function() {
		// 	return
		// },
	}

	if (SPAWN_SHUFFLE_MODE in shuffleModes)
		shuffleModes[SPAWN_SHUFFLE_MODE]()
	else
		arena.SpawnIdx = RandomInt(0, arena.SpawnPoints.len() - 1)

	return arena.SpawnIdx
}

::SetArenaState <- function(arena_name, state) {
	local arena = Arenas[arena_name]
	arena.State = state

	local arenaStates = {
		[AS_IDLE] = function() {
			arena.Score <- array(2, 0)
		},
		[AS_COUNTDOWN] = function() {

			local countdown_time = arena.cdtime.tointeger()

			if (arena.IsBBall)
			{
				if (arena.BBall.ground_ball.IsValid())
					arena.BBall.ground_ball.SetOrigin(arena.BBall.neutral_home)


				arena.BBall.bball_pickup_r <- CreateByClassname("trigger_particle")
				arena.BBall.bball_pickup_r.KeyValueFromString("targetname", "__mge_bball_trail_2")
				arena.BBall.bball_pickup_r.KeyValueFromString("particle_name", BBALL_PARTICLE_TRAIL_RED)
				arena.BBall.bball_pickup_r.KeyValueFromString("attachment_name", "flag")
				arena.BBall.bball_pickup_r.KeyValueFromInt("attachment_type", 4)
				arena.BBall.bball_pickup_r.KeyValueFromInt("spawnflags", 1)
				DispatchSpawn(arena.BBall.bball_pickup_r)

				arena.BBall.bball_pickup_b <- CreateByClassname("trigger_particle")
				arena.BBall.bball_pickup_b.KeyValueFromString("targetname", "__mge_bball_trail_3")
				arena.BBall.bball_pickup_b.KeyValueFromString("particle_name", BBALL_PARTICLE_TRAIL_BLUE)
				arena.BBall.bball_pickup_b.KeyValueFromString("attachment_name", "flag")
				arena.BBall.bball_pickup_b.KeyValueFromInt("attachment_type", 4)
				arena.BBall.bball_pickup_b.KeyValueFromInt("spawnflags", 1)
				DispatchSpawn(arena.BBall.bball_pickup_b)
			}

			if (arena.IsKoth)
			{
				local t = arena.Koth
				t.owner_team = 0

				t.red_cap_time = arena.Koth.red_start_cap_time
				t.blu_cap_time = arena.Koth.blu_start_cap_time

				t.red_partial_cap_amount = 0.0
				t.blu_partial_cap_amount = 0.0

				// t.is_overtime = false
			}

			local _players = array(arena.MaxPlayers, null)
			foreach(p, _ in arena.CurrentPlayers)
			{

				if (p.GetTeam() == TEAM_SPECTATOR) continue

				local round_start_sound = !ENABLE_ANNOUNCER || !p.GetScriptScope().enable_announcer ? arena.round_start_sound : format("vo/announcer_am_roundstart0%d.mp3", RandomInt(1, 4))

				if (arena.IsBBall)
					if (p.GetScriptScope().ball_ent && p.GetScriptScope().ball_ent.IsValid())
						p.GetScriptScope().ball_ent.Kill()


				p.ForceRespawn()

				//it might be better to remove this in AS_FIGHT instead of using the timer
				//there's probably a good reason to remove no_attack separate from the countdown but I'm not sure what
				p.AddCustomAttribute("no_attack", 1.0, countdown_time)

				if (p.GetScriptScope().enable_countdown)
				{
					for (local i = 0; i < countdown_time; ++i)
					{
						EntFireByHandle(p, "RunScriptCode", format(@"

							local arena = Arenas[`%s`]
							//left before countdown ended
							if (!(self in arena.CurrentPlayers)) return

							EmitSoundEx({
								sound_name = `%s`
								volume = %.2f
								channel = CHAN_STREAM
								filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
								entity = self
							})
						", arena_name, arena.countdown_sound, arena.countdown_sound_volume), i, null, null)
					}
				}
				_players[p.GetTeam() - 2] = p
				EntFireByHandle(p, "RunScriptCode", format(@"

					local arena_name = `%s`
					local arena = Arenas[arena_name]

					//left before countdown ended
					if (!(self in arena.CurrentPlayers))
					{
						SetArenaState(arena_name, AS_IDLE)
						return
					}
					SetArenaState(arena_name, AS_FIGHT)
					EmitSoundEx({
						sound_name = `%s`,
						volume = %.2f,
						channel = CHAN_STREAM,
						filter_type = RECIPIENT_FILTER_SINGLE_PLAYER,
						entity = self
					})
				", arena_name, arena.round_start_sound, arena.round_start_sound_volume), countdown_time, null, null)
			}

			local hudstr = format("%s\n", arena_name)
			foreach(_p in _players)
				if (_p && _p.IsValid())
					hudstr += format("%s: %d (%d)\n", _p.GetScriptScope().Name, arena.Score[_p.GetTeam() - 2], _p.GetScriptScope().stats.elo)

			MGE_HUD.KeyValueFromString("message", hudstr)

			foreach(_p in _players)
				if (_p && _p.IsValid())
					MGE_HUD.AcceptInput("Display", "", _p, _p)

			if (arena.IsBBall)
				BBall_SpawnBall(arena_name)

		},
		[AS_FIGHT] = function() {
			foreach(p, _ in arena.CurrentPlayers)
			{
				local scope = p.GetScriptScope()
				local round_start_sound = !ENABLE_ANNOUNCER || !scope.enable_announcer ? ROUND_START_SOUND : format("vo/announcer_am_roundstart0%d.mp3", RandomInt(1, 4))
				PlayAnnouncer(p, round_start_sound)

				if (arena.IsBBall)
				{
					if (scope.ball_ent && scope.ball_ent.IsValid())
						scope.ball_ent.Kill()
				}
			}
		},
		[AS_AFTERFIGHT] = function() {
			foreach(p, _ in arena.CurrentPlayers)
			{
				//20-0
				if (arena.Score.find(arena.fraglimit.tointeger()) && arena.Score.find(0))
				{
					local sound = p.GetScriptScope().won_last_match ? format("vo/announcer_am_flawlessvictory0%d.mp3", RandomInt(1, 3)) : format("vo/announcer_am_flawlessdefeat0%d.mp3", RandomInt(1, 4))
					PlayAnnouncer(p, sound)
				}
				//left early
				else if (arena.Score[0] != arena.fraglimit.tointeger() && arena.Score[1] != arena.fraglimit.tointeger())
				{
					PlayAnnouncer(p, "vo/announcer_am_lastmanforfeit01.mp3")
				}
			}
			if (arena.IsBBall)
			{
				EntFireByHandle(arena.BBall.bball_pickup_r, "Kill", "", -1, null, null)
				EntFireByHandle(arena.BBall.bball_pickup_b, "Kill", "", -1, null, null)
				EntFireByHandle(arena.BBall.ground_ball, "Kill", "", -1, null, null)
			}

			if ("IsCustomRuleset" in arena && arena.IsCustomRuleset)
			{
				foreach(p, _ in arena.CurrentPlayers)
				{
					AddPlayer(p, arena_name)
					LoadSpawnPoints(arena_name, true)
				}
			}

			EntFire("bignet", "RunScriptCode", format("CycleQueue(`%s`)", arena_name), QUEUE_CYCLE_DELAY)
		},
	}
	arenaStates[state]()
}

::SetSpecialArena <- function(player, arena_name) {

	local arena = Arenas[arena_name]

	if ("mge" in arena && arena.mge == "1") return

	local scope = player.GetScriptScope()
	local hpratio = "hpratio" in arena ? arena.hpratio.tofloat() : 1.0
	local maxhp = player.GetMaxHealth() * hpratio

	foreach(k, func in special_arenas)
	{
		if (k in arena && arena[k] == "1")
			func.call(scope)
	}
}

::PlayAnnouncer <- function(player, sound_name) {

	if (!ENABLE_ANNOUNCER || !player.GetScriptScope().enable_announcer) return

	EmitSoundEx({
			sound_name = sound_name,
			volume =  ANNOUNCER_VOLUME,
			channel = CHAN_STREAM,
			filter_type = RECIPIENT_FILTER_SINGLE_PLAYER,
			entity = player
	})
}

::GetLocalizedString <-  function(string, player = null) {

	local str = false

	local language = DEFAULT_LANGUAGE

	if (player && player.IsValid() && !player.IsFakeClient())
	{
		local scope = player.GetScriptScope()
		language =  "Language" in scope ? scope.Language : Convars.GetClientConvarValue("cl_language", player.entindex())

		if (!(language in MGE_Localization))
			language = DEFAULT_LANGUAGE

		if (string in MGE_Localization[language])
			str = MGE_Localization[language][string]
		else
			printf("[MGE VScript] Cannot localize string %s, reverting to default language...\n", string)
	}
	if (!str) str = MGE_Localization[DEFAULT_LANGUAGE][string]

	return str
}

::MGE_ClientPrint <-  function(...) {

	local args = vargv
	local player = args[0]
	local target = args[1]
	local localized_string = args[2]
	local format_args = args.slice(3).apply(@(a) a.tostring())


	foreach (p, userid in ALL_PLAYERS)
	{
		if (!p || !p.IsValid() || p.IsFakeClient()) continue

		local temp = UniqueString()
		local str = ""
		local scope = p.GetScriptScope()
		local language = "Language" in scope ? scope.Language : Convars.GetClientConvarValue("cl_language", p.entindex())

		if (!(language in MGE_Localization))
			language = DEFAULT_LANGUAGE

		str = localized_string in MGE_Localization[language] ? MGE_Localization[language][localized_string] : localized_string

		// if (args.len() > 3)
		// {
		// 	str = format("format(\"%s\"",  str)
		// 	foreach (a in format_args)
		// 		str += format(",\"%s\"", a)
		// 	str += ")"
		// 	compilestring(format("ROOT[\"%s\"] <- %s", temp, str))()
		// 	str = ROOT[temp]
		// }

		// local args = [this, str].extend(format_args)

		// foreach(a in args)
			// printl(typeof a)
		if (args.len() > 3)
			str = format.acall([this, str].extend(format_args))

		ClientPrint(p, target, str)
		if (temp in ROOT) delete ROOT[temp]
	}

}

::GetStats <- function(player) {

	if (!ELO_TRACKING_MODE) return

	local scope = player.GetScriptScope()
	local steam_id = GetPropString(player, "m_szNetworkIDString")
	local steam_id_slice = steam_id == "BOT" ? "BOT" : steam_id.slice(5, steam_id.find("]"))
	local filename = format("mge_playerdata/%s.nut", steam_id_slice)

	if (ELO_TRACKING_MODE == 1)
	{
		//load stats from file
		if (FileToString(filename))
		{
			compilestring(FileToString(filename))()
			scope.stats <- ROOT[steam_id_slice]
			delete ROOT[steam_id_slice]
		}
		else
		{
			//first time player
			if (scope.stats.elo == -INT_MAX)
			{
				scope.stats.elo <- DEFAULT_ELO
				foreach(k, v in scope.stats)
					if (k != "elo")
						scope.stats[k] = 0
			}
			//save default stats to file
			local str = format("ROOT[\"%s\"]<-{\n", steam_id_slice)

			foreach(k, v in scope.stats)
				str += format("%s=%s\n", k.tostring(), v.tostring())

			str += "}\n"
			StringToFile(filename, str)
		}
		return
	}
	else if (ELO_TRACKING_MODE > 1 && "VPI" in ROOT)
	{
		VPI.AsyncCall({
			func="VPI_MGE_ReadWritePlayerStats",
			kwargs= {
				query_mode="read",
				network_id=steam_id_slice,
				default_elo=DEFAULT_ELO,
				name = scope.Name
			},
			callback=function(response, error) {

				if (typeof(response) != "array" || !response.len())
				{
					printl(response)
					printf(MGE_Localization[DEFAULT_LANGUAGE]["VPI_ReadError"], GetPropString(player, "m_szNetworkIDString"))
					return
				}

				local r = response[0]
				scope.stats <- {
					elo = r[1],
					wins = r[2],
					losses = r[3],
					kills = r[4],
					deaths = r[5],
					damage_taken = r[6],
					damage_dealt = r[7],
					airshots = r[8],
					market_gardens = r[9],
					hoops_scored = r[10],
					koth_points_capped = r[11],
					name = r[12]
				}
				printf(MGE_Localization[DEFAULT_LANGUAGE]["VPI_ReadSuccess"], GetPropString(player, "m_szNetworkIDString"))
			}
		})
	}
}

::UpdateStats <-  function(player, _stats = {}, additive = false) {
	local scope = player.GetScriptScope()
	local steam_id = GetPropString(player, "m_szNetworkIDString")
	local steam_id_slice = steam_id == "BOT" ? "BOT" : steam_id.slice(5, steam_id.find("]"))
	local filename = format("mge_playerdata/%s.nut", steam_id_slice)

	if (!("stats" in scope))
	{
		printf(MGE_Localization[DEFAULT_LANGUAGE]["Error_StatsNotFound"], steam_id)
		GetStats(player)
		return
	}
	foreach (k, v in _stats)
		additive ? scope.stats[k] += v : scope.stats[k] = v

	switch(ELO_TRACKING_MODE)
	{
		case 0:
			return
		break
		case 1:
			local file_data = format("ROOT[\"%s\"]<-{\n", steam_id_slice)
			foreach(k, v in scope.stats)
				file_data += format("%s=%s\n", k.tostring(), v.tostring())
			file_data += "}\n"
			StringToFile(filename, file_data)
		break
		case 2:

			local file_data = format("ROOT[\"%s\"]<-{\n", steam_id_slice)
			foreach(k, v in scope.stats)
				file_data += format("%s=%s\n", k.tostring(), v.tostring())
			file_data += "}\n"
			StringToFile(filename, file_data)

			VPI.AsyncCall({
				func="VPI_MGE_ReadWritePlayerStats",
				kwargs= {
					query_mode="write",
					network_id=steam_id_slice,
					name = scope.Name,
					stats=_stats,
					additive=additive
				},
				callback=function(response, error) {
					printf(MGE_Localization[DEFAULT_LANGUAGE][error ? "VPI_WriteError" : "VPI_WriteSuccess"], GetPropString(player, "m_szNetworkIDString"))
				}
			})
		break
		case 3:
			VPI.AsyncCall({
				func="VPI_MGE_ReadWritePlayerStats",
				kwargs= {
					query_mode="write",
					network_id=steam_id_slice,
					name = scope.Name,
					stats=_stats,
					additive=additive
				},
				callback=function(response, error) {
					printf(MGE_Localization[DEFAULT_LANGUAGE][error ? "VPI_WriteError" : "VPI_WriteSuccess"], GetPropString(player, "m_szNetworkIDString"))
				}
			})
		break
	}
}

::SendUsermessage <-  function(usermessage, input, player = null)
{
	local dummy = CreateByClassname("prop_dynamic")

	dummy.KeyValueFromString("model", "models/player/heavy.mdl")
	dummy.KeyValueFromString("BreakModelMessage", usermessage)
	dummy.KeyValueFromInt("disablebonefollowers", 1)
	dummy.KeyValueFromInt("modelindex", input[0])
	if (input.len() > 1) dummy.KeyValueFromString("origin", input[1].tostring())
	if (input.len() > 2) dummy.KeyValueFromString("angles", input[2].tostring())

	if (player && player.IsValid())
		player.SetOrigin(dummy.GetOrigin())

	DispatchSpawn(dummy)
	dummy.AcceptInput("Break", "", player, player)
}

::ShowModelToPlayer <-  function(_player, model = ["models/player/heavy.mdl", 0, 0], pos = Vector(), ang = QAngle(), duration = 9999.0)
{
    PrecacheModel(model[0])
    local proxy_entity = CreateByClassname("obj_teleporter") // not using SpawnEntityFromTable as that creates spawning noises
    proxy_entity.SetAbsOrigin(pos)
    proxy_entity.SetAbsAngles(ang)
    DispatchSpawn(proxy_entity)

    proxy_entity.SetModel(model[0])
    proxy_entity.SetSkin(model[1])
    proxy_entity.AddEFlags(EFL_NO_THINK_FUNCTION); // EFL_NO_THINK_FUNCTION prevents the entity from disappearing
    proxy_entity.SetSolid(SOLID_NONE)
	proxy_entity.SetTeam(model[2]) // for glows

    SetPropBool(proxy_entity, "m_bPlacing", true)
    SetPropInt(proxy_entity, "m_fObjectFlags", 2) // sets "attachment" flag, prevents entity being snapped to player feet

    // m_hBuilder is the player who the entity will be networked to only
    SetPropEntity(proxy_entity, "m_hBuilder", _player)
    EntFireByHandle(proxy_entity, "Kill", "", duration, _player, _player)
	_player.GetScriptScope()[format("__showmodel_%d", _player.entindex(), proxy_entity.entindex())] <- proxy_entity
    return proxy_entity;
}
//taken from popext (originally made by fellen)
::VectorAngles <- function(forward)
{
	local yaw, pitch
	if ( forward.y == 0.0 && forward.x == 0.0 ) {
		yaw = 0.0
		if (forward.z > 0.0)
			pitch = 270.0
		else
			pitch = 90.0
	}
	else {
		yaw = (atan2(forward.y, forward.x) * 180.0 / Pi)
		if (yaw < 0.0)
			yaw += 360.0
		pitch = (atan2(-forward.z, forward.Length2D()) * 180.0 / Pi)
		if (pitch < 0.0)
			pitch += 360.0
	}

	return QAngle(pitch, yaw, 0.0)
}

::SwitchWeaponSlot <-  function(player, slot, delay = -2)
{

	if (delay == -2)
		MGE_CLIENTCOMMAND.AcceptInput("Command", format("slot%d", slot), player, player)
	else
		EntFireByHandle(MGE_CLIENTCOMMAND, "Command", format("slot%d", slot), delay, player, player)
}
::SetCustomArenaRuleset <- function(arena_name, ruleset)
{
	local arena = Arenas[arena_name]
	if (!arena.IsMGE || !(ruleset in special_arenas))
	{
		MGE_ClientPrint(player, HUD_PRINTTALK, "InvalidRuleset", ruleset)
		return
	}

	arena.RulesetVote.clear()

	arena[ruleset] <- "1"
	arena.IsCustomRuleset <- true
	SetArenaState(arena_name, AS_IDLE)
	if ("mge" in arena)
	{
		delete arena.mge
		arena.IsMGE <- false
	}

	local ruleset_inits = {
		function bball() {
			printl("RulesetTest")
			//set some temporary bball variables
			if (!("validatedhoops" in arena.RulesetVote))
			{
				arena.RulesetVote.ballvote_pos <- array(2, null)
				arena.RulesetVote.readytovalidate <- array(2, false)
				arena.RulesetVote.validatedhoops <- 0
			}

			local scope = self.GetScriptScope()

			//spawn ball in the void
			BBall_SpawnBall(arena_name, Vector(), true)

			//spawn hoop prop
			if ("hoop" in scope)
				EntFireByHandle(scope.hoop, "Kill", "", -1, null, null)

			local hoop = CreateByClassname("prop_dynamic")
			hoop.SetModel(BBALL_HOOP_MODEL)
			hoop.SetSolid(SOLID_VPHYSICS)
			hoop.SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			hoop.SetTeam(self.GetTeam())

			hoop.ValidateScriptScope()
			hoop.SetAbsOrigin(self.EyePosition())
			hoop.AcceptInput("Color", self.GetTeam() == TF_TEAM_RED ? KOTH_RED_HUD_COLOR : KOTH_BLU_HUD_COLOR, null, null)

			DispatchSpawn(hoop)

			scope.hoop <- hoop
			scope.hoop_placed <- false
			scope.hoop_validated <- false
			scope.hoop_cooldown <- 0.0

			EntFireByHandle(self, "RunScriptCode", @"
				local visbit = 1 << self.entindex()
				SendGlobalGameEvent(`show_annotation`, {
					visibilityBitfield = visbit,
					id = self.entindex() + BBALL_HOOP_SIZE,
					text = format(`MOUSE1: Place Hoop`),
					lifetime = 5.0,
					play_sound = BBALL_PICKUP_SOUND,
					follow_entindex = self.GetScriptScope().hoop.entindex(),
					show_distance = true,
					show_effect = true
				})
			", GENERIC_DELAY, null, null)
		}
		function koth() {
			local cap_point = CreateByClassname("prop_dynamic")
			cap_point.SetModel(KOTH_POINT_MODEL)
			cap_point.SetSolid(SOLID_VPHYSICS)
			cap_point.SetCollisionGroup(COLLISION_GROUP_DEBRIS)
			DispatchSpawn(cap_point)

			arena.RulesetVote.pointvote_pos <- array(2, null)

			scope.cap_point <- cap_point
		}
		function ultiduo() {
			return
		}
		function ammomod() {
			return
		}
		function endif() {
			return
		}
		function midair() {
			return
		}
	}
	local ruleset_thinks = {
		function bball() {
			// printl(arena.RulesetVote.validatedhoops)
			// printl("temp_ball" in self.GetScriptScope())
			local scope = self.GetScriptScope()
			if (hoop_cooldown > Time()) return

			local hoop_trace = {

				start = self.EyePosition(),
				end = (self.EyeAngles().Forward() * INT_MAX),
				mask = hoop_placed ? -1 : MASK_PLAYERSOLID,
				ignore = self
			}

			TraceLineEx(hoop_trace)

			if (hoop_placed && !hoop_validated)
			{
				//move hoop somewhere else
				if (
					GetPropInt(self, "m_nButtons") & IN_ATTACK2 &&
					hoop_trace.hit &&
					(hoop_trace.endpos - hoop.GetOrigin()).Length() < 100.0
				) {

					scope.hoop_placed = false
					arena.RulesetVote[self.entindex()] <- scope.hoop_placed
					hoop.AcceptInput("Color", self.GetTeam() == TF_TEAM_RED ? KOTH_RED_HUD_COLOR : KOTH_BLU_HUD_COLOR, null, null)
					hoop.SetCollisionGroup(COLLISION_GROUP_DEBRIS)

					for (local glows; glows = FindByClassnameWithin(glows, "obj_teleporter", hoop.GetOrigin(), 32.0);)
						EntFireByHandle(glows, "Kill", "", -1, null, null)
				}

				//we are in the basket, validate this hoop pos
				if (arena.RulesetVote.readytovalidate[0] && arena.RulesetVote.readytovalidate[1] && (self.GetOrigin() - hoop.GetScriptScope().basket).Length() < BBALL_HOOP_SIZE)
				{
					hoop_validated = true,
					printl(self.GetTeam())
					arena[self.GetTeam() == TF_TEAM_RED ? "bball_hoop_red" : "bball_hoop_blue"] <- hoop.GetScriptScope().basket.ToKVString()
					// printl(arena.bball_hoop_red)
					// printl(arena.bball_hoop_blue)
					//add some constant to this value o singify it's a bball annotation
					SendGlobalGameEvent("hide_annotation", { id = self.entindex() + BBALL_HOOP_SIZE })

					arena.RulesetVote.validatedhoops++
				}

				//spawn ball
				if (arena.RulesetVote.validatedhoops == arena.MaxPlayers)
				{
					foreach(p, _ in arena.CurrentPlayers)
					{
						local _scope = p.GetScriptScope()

						_scope.temp_ball <- ShowModelToPlayer(p, [BBALL_BALL_MODEL, 0, 0], hoop_trace.endpos, QAngle(), 9999.0)
						SetPropInt(_scope.temp_ball, "m_nRenderFX", kRenderFxDistort)

						EntFireByHandle(p, "RunScriptCode", format(@"
							SendGlobalGameEvent(`show_annotation`, {
								visibilityBitfield = 1 << self.entindex(),
								id = self.entindex() + BBALL_HOOP_SIZE,
								text = `MOUSE1: Set ball respawn point`,
								lifetime = 5.0,
								play_sound = BBALL_PICKUP_SOUND,
								follow_entindex = %d,
								show_distance = true,
								show_effect = true
							})
						", _scope.temp_ball.entindex()), GENERIC_DELAY, null, null)
					}
				}
				return
			}

			//spawn ball
			else if (hoop_validated && arena.RulesetVote.validatedhoops == arena.MaxPlayers && "temp_ball" in scope)
			{

				local ball = scope.temp_ball
				ball.KeyValueFromVector("origin", hoop_trace.pos + Vector(0, 0, 10))
				local normal_angles = VectorAngles(hoop_trace.plane_normal)
				ball.SetAbsAngles(QAngle(normal_angles.x, normal_angles.y, normal_angles.z) + QAngle(90, 0, 0))

				if (CanPlaceHoop(ball))
				{
					arena.RulesetVote.ballvote_pos[self.GetTeam() - 2] = ball.GetOrigin()
					// arena.RulesetVote.ballvote_pos[0] = ball.GetOrigin()
					// arena.RulesetVote.ballvote_pos[1] = ball.GetOrigin()

					//we both picked an area close enough to eachother, start the game
					local votepos = arena.RulesetVote.ballvote_pos
					if (votepos[0] && votepos[1] && (votepos[0] - votepos[1]).Length() < 200.0)
					{
						local groundball = arena.RulesetVote.ground_ball
						groundball.SetOrigin(ball.GetOrigin())
						groundball.SetAbsAngles(ball.GetAbsAngles())

						// arena.bball_hoop_red <- scope.hoop.GetScriptScope().basket.ToKVString()
						// arena.bball_hoop_blue <- scope.hoop.GetScriptScope().basket.ToKVString()

						arena.fraglimit /= 2

						arena.bball_home 		<- ball.GetOrigin().ToKVString()
						arena.bball_home_red 	<- ball.GetOrigin().ToKVString()
						arena.bball_home_blue 	<- ball.GetOrigin().ToKVString()
						arena[self.GetTeam() == TF_TEAM_RED ? "bball_hoop_red" : "bball_hoop_blue"] <- scope.hoop.GetScriptScope().basket.ToKVString()


						//HACK
						//the temp_ball kill below doesn't work for the first person who placed the flag, only the last
						//just manually kill all obj_teleporters in radius
						for (local hack; hack = FindByClassnameWithin(hack, "obj_teleporter", ball.GetOrigin(), 200.0);)
							EntFireByHandle(hack, "Kill", "", -1, null, null)

						foreach(p, _ in arena.CurrentPlayers)
						{
							if (scope.temp_ball)
								EntFireByHandle(scope.temp_ball, "Kill", "", -1, null, null)
						}
						LoadSpawnPoints(arena_name)

						//why does this need to be set here
						// if ("mge" in arena)
						// {
						// 	delete arena.mge
						// 	arena.IsMGE <- false
						// }
						// arena.IsBBall <- true
						arena.BBall.ground_ball <- groundball

						// arena.bball_home 		<- ball.GetOrigin().ToKVString()
						// arena.bball_home_red 	<- ball.GetOrigin().ToKVString()
						// arena.bball_home_blue 	<- ball.GetOrigin().ToKVString()
						// arena[self.GetTeam() == TF_TEAM_RED ? "bball_hoop_red" : "bball_hoop_blue"] <- scope.hoop.GetScriptScope().basket.ToKVString()

						arena.RulesetVote.clear()
						SetArenaState(arena_name, AS_COUNTDOWN)

						foreach(p, _ in arena.CurrentPlayers)
						{
							if (scope.temp_ball)
								EntFireByHandle(scope.temp_ball, "Kill", "", -1, null, null)
							if ("CustomRulesetThink" in scope.ThinkTable)
								delete scope.ThinkTable.CustomRulesetThink
							p.RemoveCustomAttribute("no_attack")
							p.RemoveCustomAttribute("disable weapon switch")
						}
						return
					}

					foreach (p, _ in arena.CurrentPlayers)
					{
						SendGlobalGameEvent("show_annotation", {
							visibilityBitfield = 1 << p.entindex(),
							id = self.entindex() + BBALL_HOOP_SIZE,
							text = format("%s wants to spawn the ball here", scope.Name),
							lifetime = 3.0,
							play_sound = BBALL_PICKUP_SOUND,
							follow_entindex = scope.temp_ball.entindex(),
							show_distance = true,
							show_effect = true
						})
					}
					hoop_cooldown = Time() + BBALL_HOOP_PLACEMENT_COOLDOWN
				}
				return
			}

			if (!hoop_trace.hit || hoop_validated) return

			hoop.KeyValueFromVector("origin", hoop_trace.pos)

			// Convert the plane normal to angles that face away from the wall
			local normal_angles = VectorAngles(hoop_trace.plane_normal)

			// Set the hoop angles perpendicular to the wall
			hoop.SetAbsAngles(QAngle(normal_angles.x, normal_angles.y, normal_angles.z))

			//TODO should this be inlined here?
			//where else would it be used?
			//also used for ball
			function CanPlaceHoop(ball = null) {

				if (!(GetPropInt(self, "m_nButtons") & IN_ATTACK))
					return false

				// if ((self.EyePosition() - hoop_trace.pos).Length() > BBALL_MAX_HOOP_DIST)
					// return false

				if (ball && ball.GetAbsAngles().x != BBALL_BALL_ANGLE_X)
					return false

				if (!ball && abs(hoop.GetAbsAngles().x) > BBALL_HOOP_MAX_ANGLE_X)
					return false

				return true
			}

			//place hoop
			if (!hoop_placed && CanPlaceHoop())
			{
				hoop_placed = true
				arena.RulesetVote[self.entindex()] <- hoop_placed
				hoop.SetCollisionGroup(COLLISION_GROUP_PLAYER)
				hoop.AcceptInput("Color", "255 255 255 255", null, null)

				//save basket pos in prop scope
				hoop.GetScriptScope().basket <- (hoop.GetOrigin() + hoop.GetAbsAngles().Forward() * BBALL_HOOP_POS_OFFSET)
				hoop.GetScriptScope().hoop_validated <- false
				local hoops = []

				//TODO: clean up this awful annotation/glow code
				//it barely works, the glow in particular pretty much never works correctly

				foreach(p, _ in arena.CurrentPlayers)
				{
					local _scope = p.GetScriptScope()
					hoops.append(_scope.hoop)

					SendGlobalGameEvent("show_annotation", {
						visibilityBitfield = 1 << p.entindex(),
						id = p.entindex() + BBALL_HOOP_SIZE, //add some constant to this value to singify it's a bball annotation
						text = format("Hoop placed by %s", scope.Name),
						lifetime = 5.0,
						play_sound = COUNTDOWN_SOUND,
						follow_entindex = scope.hoop.entindex(),
						show_distance = true,
						show_effect = true
					})

					if (p.entindex() in arena.RulesetVote && arena.RulesetVote[p.entindex()])
						arena.RulesetVote.readytovalidate[p.GetTeam() - 2] = true

					hoop_cooldown = Time() + BBALL_HOOP_PLACEMENT_COOLDOWN
					// p.SetOrigin(hoop.GetOrigin() + hoop.GetAbsAngles().Forward() * BBALL_HOOP_POS_OFFSET)
				}

				//make hoops glow only to the arena players
				//this sucks and doesn't work right
				foreach(__hoop in hoops)
				{
					foreach(p, _ in arena.CurrentPlayers)
					{
						local glow_dummy = ShowModelToPlayer(p, [BBALL_HOOP_MODEL, 0, __hoop.GetTeam()], __hoop.GetOrigin(), __hoop.GetAbsAngles(), 9999.0)
						printl(glow_dummy)
						glow_dummy.AcceptInput("SetParent", "!activator", __hoop, __hoop)
						SetPropBool(glow_dummy, "m_bGlowEnabled", true)
					}
				}

				//all players have placed their hoops, give them their weapons back
				//once both hoops are validated, we can vote on the ball spawn point

				//should we force players to soldier for this?
				//custom rulesets are a gimmick in general so I don't see the harm in letting people play whatever class they want
				if (arena.RulesetVote.readytovalidate[0] && arena.RulesetVote.readytovalidate[1])
				{
					foreach(p, _ in arena.CurrentPlayers)
					{
						EntFireByHandle(p, "RunScriptCode", format(@"
							SwitchWeaponSlot(self, 3);
							SwitchWeaponSlot(self, 1)
							for (local child = self.FirstMoveChild(); child != null; child = child.NextMovePeer())
							{
								SetPropInt(child, `m_clrRender`, INT_COLOR_WHITE)
								SetPropInt(child, `m_nRenderMode`, kRenderFxNone)
							}
							self.RemoveCustomAttribute(`disable weapon switch`)
							self.RemoveCustomAttribute(`no_attack`)
						", hoop.entindex()), GENERIC_DELAY, null, null)

						EntFireByHandle(p, "RunScriptCode", format(@"

							SendGlobalGameEvent(`show_annotation`, {
								id = self.entindex() + BBALL_HOOP_SIZE, //add some constant to this value to singify it's a bball annotation
								visibilityBitfield = 1 << self.entindex(),
								text = `Hoops placed! jump to your hoop`,
								lifetime = -1,
								play_sound = ROUND_START_SOUND,
								follow_entindex = %d,
								show_distance = true,
								show_effect = true
							})
						", hoop.entindex()), GENERIC_DELAY + 0.1, null, null)
					}
				}
			}
		}
		function koth() {

			if (point_cooldown > Time()) return

			local point_trace = {

				start = self.EyePosition(),
				end = (self.EyeAngles().Forward() * INT_MAX),
				mask = hoop_placed ? -1 : MASK_PLAYERSOLID,
				ignore = self
			}

			TraceLineEx(point_trace)

			local point = scope.temp_point
			point.KeyValueFromVector("origin", point_trace.pos + Vector(0, 0, 10))
			local normal_angles = VectorAngles(point_trace.plane_normal)
			point.SetAbsAngles(QAngle(normal_angles.x, normal_angles.y, normal_angles.z) + QAngle(90, 0, 0))
			
			scope.point_cooldown <- 0.0

			function CanPlacePoint() {

				if (!(GetPropInt(self, "m_nButtons") & IN_ATTACK))
					return false

				// if ((self.EyePosition() - hoop_trace.pos).Length() > BBALL_MAX_HOOP_DIST)
					// return false

				if (point && point.GetAbsAngles().x != KOTH_POINT_ANGLE_X)
					return false

				if (!point && abs(point.GetAbsAngles().x) > KOTH_POINT_MAX_ANGLE_X)
					return false

				return true
			}
			
			//place point
			if (CanPlacePoint())
			{
				arena.RulesetVote.pointvote_pos[self.GetTeam() - 2] = point.GetOrigin()

				local votepos = arena.RulesetVote.pointvote_pos

				//we both picked an area close enough to eachother, start the game
				if (votepos[0] && votepos[1] && (votepos[0] - votepos[1]).Length() < 200.0)
				{
					arena.fraglimit = 2
					arena.koth_cap <- point.GetOrigin().ToKVString()

					//HACK
					//see above for bball
					for (local hack; hack = FindByClassnameWithin(hack, "obj_teleporter", point.GetOrigin(), 200.0);)
						EntFireByHandle(hack, "Kill", "", -1, null, null)

					foreach(p, _ in arena.CurrentPlayers)
						if (scope.temp_point)
							EntFireByHandle(scope.temp_point, "Kill", "", -1, null, null)
					
					LoadSpawnPoints(arena_name)

					arena.RulesetVote.clear()

					foreach(p, _ in arena.CurrentPlayers)
					{
						if (scope.temp_ball)
							EntFireByHandle(scope.temp_ball, "Kill", "", -1, null, null)

						if ("CustomRulesetThink" in scope.ThinkTable)
							delete scope.ThinkTable.CustomRulesetThink
							
						p.RemoveCustomAttribute("no_attack")
						p.RemoveCustomAttribute("disable weapon switch")
					}
					return
				}

				foreach (p, _ in arena.CurrentPlayers)
				{
					SendGlobalGameEvent("show_annotation", {
						visibilityBitfield = 1 << p.entindex(),
						id = self.entindex() + KOTH_MAX_SPAWNS,
						text = format("%s wants to spawn the point here", scope.Name),
						lifetime = 3.0,
						play_sound = COUNTDOWN_SOUND,
						follow_entindex = scope.temp_point.entindex(),
						show_distance = true,
						show_effect = true
					})
				}
				point_cooldown = Time() + KOTH_POINT_PLACEMENT_COOLDOWN
			}
		}
	}

	foreach (p, _ in arena.CurrentPlayers)
	{
		ruleset_inits[ruleset].call(p.GetScriptScope())
		p.GetScriptScope().ThinkTable["CustomRulesetThink"] <- ruleset_thinks[ruleset]
		for(local child = p.FirstMoveChild(); child != null; child = child.NextMovePeer())
			if (startswith(child.GetClassname(), "tf_weapon"))
			{
				SetPropInt(child, "m_nRenderMode", kRenderTransColor)
				SetPropInt(child, "m_clrRender", 0)
			}
		p.AddCustomAttribute("no_attack", 1, -1)
		p.AddCustomAttribute("disable weapon switch", 1, -1)
	}
	
	SetArenaState(arena_name, AS_COUNTDOWN)
	return
}