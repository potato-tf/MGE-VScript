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
		player_manager.GetScriptScope().HideRespawnText <- function() {
			for (local i = 1; i <= MAX_CLIENTS; i++)
			{
				local player = PlayerInstanceFromIndex(i)
				if (!player || !player.IsValid() || player.IsFakeClient()) continue

				SetPropFloatArray(player_manager, "m_flNextRespawnTime", -1, player.entindex())
			}
			return -1
		}
		AddThinkToEnt(player_manager, "HideRespawnText")
	}
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
		ThinkTable = {},
		Name       = Convars.GetClientConvarValue("name", player.entindex()),
		Language   = Convars.GetClientConvarValue("cl_language", player.entindex()),
		arena_info = null,
		queue      = null,
		stats      = { elo = -INT_MAX },
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

	ClientPrint(player, 3, format(GetLocalizedString("ClassIsNotAllowed", player), newclass))
}

// tointeger() allows trailing garbage (e.g. "123abc")
// This will only allow strictly integers (also floats with only zeroes: e.g "1.00")
::ToStrictInt <- function(str)
{
	local rex = regexp(@"-?[0-9]+(\.0+)?") // [-](digit)[.(>0 zeroes)]
	if (!rex.match(str)) return

	try
		return str.tointeger()
	catch (_)
		return
}

::LoadSpawnPoints <- function()
{
	local config = SpawnConfigs[GetMapName()]
	Arenas_List <- array(config.len(), null)

	local idx_failed = false
	foreach(arena_name, datatable in config)
	{
		Arenas[arena_name] <- datatable

		datatable.CurrentPlayers <- {}
		datatable.Queue          <- []
		datatable.SpawnPoints    <- []
		datatable.Score          <- array(2, 0)
		datatable.State          <- AS_IDLE
		//0 breaks our countdown system, default to 1
		datatable.cdtime         <- "cdtime" in datatable ? datatable.cdtime != "0" ? datatable.cdtime : 1 : DEFAULT_CDTIME
		datatable.MaxPlayers     <- "4player" in datatable && datatable["4player"] == "1" ? 4 : 2
		datatable.classes        <- ("classes" in datatable) ? split(datatable.classes, " ", true) : []
		datatable.fraglimit      <- "fraglimit" in datatable ? datatable.fraglimit.tointeger() : DEFAULT_FRAGLIMIT
		datatable.SpawnIdx       <- 0

		//do this instead of checking both of these everywhere
		datatable.IsMGE          <- "mge" in datatable && datatable.mge == "1"
		datatable.IsKoth         <- "koth" in datatable && datatable.koth == "1"
		datatable.IsBBall        <- "bball" in datatable && datatable.bball == "1"
		datatable.IsAmmomod      <- "ammomod" in datatable && datatable.ammomod == "1"
		datatable.IsTurris       <- "turris" in datatable && datatable.turris == "1"
		datatable.IsEndif        <- "endif" in datatable && datatable.endif == "1"
		datatable.IsMidair       <- "midair" in datatable && datatable.midair == "1"

		local idx = ("idx" in datatable) ? datatable.idx.tointeger() : null
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

		if (datatable.IsBBall)
		{
			//alternative keyvalues for bball logic
			//if you intend on adding > 8 spawns, you will need to replace your current "9" - "13" entries with these
			local bball_points = {
				neutral_home = "bball_home" in datatable ? datatable.bball_home : datatable["9"],
				red_score_home = "bball_home_red" in datatable ? datatable.bball_home_red : datatable["10"],
				blue_score_home = "bball_home_blue" in datatable ? datatable.bball_home_blue : datatable["11"],
				red_hoop = "bball_hoop_red" in datatable ? datatable.bball_hoop_red : datatable["12"],
				blue_hoop = "bball_hoop_blue" in datatable ? datatable.bball_hoop_blue : datatable["13"],
				last_score_team = -1
			}

			foreach (k, v in bball_points)
			{
				if (k == "last_score_team") continue
				local split_spawns = split(v, " ").apply( @(str) str.tofloat() )
				bball_points[k] <- Vector(split_spawns[0], split_spawns[1], split_spawns[2])
			}

			datatable.BBall <- bball_points
			BBall_SpawnBall(arena_name)

		}
		if (datatable.IsKoth)
		{
			//alternative keyvalues for KOTH logic
			//koth_radius is a new kv that you can set per-arena
			local koth_points = {
				//see BBall notes about adding more spawns, koth uses the final index for cap points
				cap_point = "koth_cap" in datatable ? datatable.koth_cap : ""
				cap_radius = "koth_radius" in datatable ? datatable.koth_radius : KOTH_DEFAULT_CAPTURE_POINT_RADIUS

				red_cap_time = KOTH_START_TIME_RED
				blu_cap_time = KOTH_START_TIME_BLUE
				owner_team = 0

				blu_partial_cap_amount = 0.0
				red_partial_cap_amount = 0.0
				timelimit = 0.0
				timeleft = 0.0

				is_overtime = false
			}
			datatable.Koth <- koth_points
		}
		// Grab spawn points
		foreach(k, v in datatable)
		{
			local spawn_idx = ToStrictInt(k)
			if (spawn_idx != null)
			{
				try
				{

					if ((datatable.IsBBall && spawn_idx > BBALL_MAX_SPAWNS) || (datatable.IsKoth && spawn_idx > KOTH_MAX_SPAWNS)) continue

					local split_spawns = split(v, " ", true).apply( @(str) str.tofloat() )

					local origin = Vector(split_spawns[0], split_spawns[1], split_spawns[2])

					local angles = QAngle()
					if (split_spawns.len() == 4)
						angles = QAngle(0, split_spawns[3], 0) // Yaw only
					else if (split_spawns.len() == 6)
						angles = QAngle(split_spawns[3], split_spawns[4], split_spawns[5])

					local spawn = [origin, angles, TEAM_UNASSIGNED]

					if (datatable.MaxPlayers > 2)
						spawn[2] = spawn_idx < 4 ? TF_TEAM_RED : TF_TEAM_BLUE

					datatable.SpawnPoints.append(spawn)
				}
				catch(e)
					printf("[VSCRIPT MGEMod] Warning: Data parsing for arena '%s' failed: %s\nkey: %s, val: %s\n", arena_name, e.tostring(), k, v.tostring())
			}
		}
		local idx = (datatable.SpawnPoints.len() + 1).tostring()
		if (datatable.IsKoth && idx in datatable)
		{
			// printl(arena_name)
			printl(datatable.IsKoth && idx in datatable)
			// printl(datatable.SpawnPoints.len())
			local cap_point = split(datatable[idx], " ").apply( @(str) str.tofloat() )
			datatable.Koth.cap_point = Vector(cap_point[0], cap_point[1], cap_point[2])
		}
	}
}

::BBall_SpawnBall <- function(arena_name, origin_override = null)
{
	local arena = Arenas[arena_name]
	local bball_points = arena.BBall
	local last_score_team = arena.BBall.last_score_team

	local ground_ball = CreateByClassname("tf_halloween_pickup")

	ground_ball.KeyValueFromString("pickup_sound", BBALL_PICKUP_SOUND)
	ground_ball.KeyValueFromString("pickup_particle", BBALL_PARTICLE_PICKUP_GENERIC)
	ground_ball.KeyValueFromString("powerup_model", BBALL_BALL_MODEL)

	//I did this specifically to annoy mince
	ground_ball.SetOrigin(origin_override ? origin_override : last_score_team == -1 ? bball_points.neutral_home : last_score_team == TF_TEAM_RED ? bball_points.red_score_home : bball_points.blue_score_home)

	AddOutput(ground_ball, "OnPlayerTouch", "!activator", "RunScriptCode", "BBall_Pickup(self);", 0.0, 1)
	AddOutput(ground_ball, "OnPlayerTouch", "!self", "Kill", "", SINGLE_TICK, 1)

	if ("ground_ball" in arena.BBall && arena.BBall.ground_ball.IsValid())
		arena.BBall.ground_ball.Kill()

	arena.BBall.ground_ball <- ground_ball

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
	local visbit = 0
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

	EntFireByHandle(ball_ent, "SetParent", "!activator", -1, player, player)
	EntFireByHandle(ball_ent, "SetParentAttachment", "flag", -1, player, player)
	EntFireByHandle(ball_ent, "RunScriptCode", "DispatchSpawn(self)", 0.1, null, null)

	DispatchParticleEffect(player.GetTeam() == TF_TEAM_RED ? BBALL_PARTICLE_PICKUP_RED : BBALL_PARTICLE_PICKUP_BLUE, player.GetOrigin(), Vector(0, 90, 0))
	EntFire(format("__mge_bball_trail_%d", player.GetTeam()), "StartTouch", "!activator", -1, player)

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
	for (local i = 1; i <= MAX_CLIENTS; ++i)
	{
		local player = PlayerInstanceFromIndex(i)
		if (!player || !player.IsBotOfType(1337)) continue

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

	MGE_ClientPrint(player, 3, GetLocalizedString("ChoseArena", player))

	// Enough room, add to arena
	if (current_players.len() < arena.MaxPlayers)
	{
		AddToArena(player, arena_name)
		local name = scope.Name
		local elo = scope.stats.elo
		printl(arena_name)
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
	player.ForceRespawn()

	current_players[player] <- scope.stats.elo
	// EntFireByHandle(KOTH_HUD_BLU, "RunScriptCode", "DispatchSpawn(self); self.RemoveEFlags(EFL_KILLME)", 1.0, null, null)
}

::RemovePlayer <- function(player, changeteam=true)
{
	local scope = player.GetScriptScope()

	scope.ThinkTable.clear()

	if (changeteam)
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

		if (arena.Queue.find(player) != null)
			arena.Queue.remove(player)

		if (player in arena.CurrentPlayers)
		{
			delete arena.CurrentPlayers[player]
			SetArenaState(scope.arena_info.name, AS_IDLE)
		}
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
			EntFireByHandle(p, "RunScriptCode", format("AddPlayer(self, `%s`)", arena_name), i * 0.1, null, null)
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
		MGE_ClientPrint(p, 3, format(GetLocalizedString("InLine", p), (i + 1).tostring()))
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

	// Print results to players
	if (winner.IsValid())
		ClientPrint(winner, 3, format("You gained %d points!", winner_gain))
	if (loser.IsValid())
		ClientPrint(loser, 3, format("You lost %d points!", loser_loss))

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

	MGE_ClientPrint(null, 3, format(GetLocalizedString("XdefeatsY", null),
		winner_scope.Name,
		winner_scope.stats.elo.tostring(),
		loser_scope.Name,
		loser_scope.stats.elo.tostring(),
		fraglimit.tostring(),
	arena_name))
	CalcELO(winner, loser)
	SetArenaState(arena_name, AS_AFTERFIGHT)
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
	if (!arena.IsMGE)
	{
		local end = -1
		local idx = arena.SpawnIdx

		if (arena.IsKoth)
			end = KOTH_MAX_SPAWNS
		else if (arena.IsBBall)
			end = BBALL_MAX_SPAWNS

		local team = player.GetTeam()
		if (team == TF_TEAM_RED)
			end /= 2

		idx = (idx + 1) % end
		if (team == TF_TEAM_BLUE)
			idx += arena.SpawnPoints.len() / 2
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

				if (p.GetScriptScope().ball_ent && p.GetScriptScope().ball_ent.IsValid())
					p.GetScriptScope().ball_ent.Kill()


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

			local _players = array(arena.MaxPlayers, 0.0)
			foreach(p, _ in arena.CurrentPlayers)
			{

				local round_start_sound = !ENABLE_ANNOUNCER || !p.GetScriptScope().enable_announcer ? ROUND_START_SOUND : format("vo/announcer_am_roundstart0%d.mp3", RandomInt(1, 4))

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
						", arena_name, COUNTDOWN_SOUND, COUNTDOWN_SOUND_VOLUME), i, null, null)
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
				", arena_name, round_start_sound, ROUND_START_SOUND_VOLUME), countdown_time, null, null)
			}

			local str = ""
			foreach(_p in _players)
				str += format("%s: %d (%d)\n", _p.GetScriptScope().Name, arena.Score[_p.GetTeam() - 2], _p.GetScriptScope().stats.elo)

			MGE_HUD.KeyValueFromString("message", str)

			foreach(_p in _players)
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
	local special_arenas = {
		koth = function()
		{
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

			scope.ThinkTable.KothThink <- function()
			{
				local owner_team = arena.Koth.owner_team

				if (!player.IsAlive()) return

				if (owner_team != team && partial_cap_cooldowntime < Time() && (self.GetOrigin() - point).Length() < radius)
				{
					if (arena.Koth[enemy_partial_cap_amount] > 0.0)
					{
						arena.Koth[enemy_partial_cap_amount] -= KOTH_PARTIAL_CAP_RATE
						partial_cap_cooldowntime = Time() + KOTH_PARTIAL_CAP_INTERVAL
						return
					}

					arena.Koth[partial_cap_amount] += KOTH_PARTIAL_CAP_RATE

					if (arena.Koth[partial_cap_amount] >= 1.0)
					{
						arena.Koth.owner_team = team
						// arena.Koth[partial_cap_amount] = owner_team == self.GetTeam() ? 0.0 : 0.99
						arena.Koth[partial_cap_amount] = 0.0
					}
					foreach(p, _ in arena.CurrentPlayers)
					{
						local _team = p.GetTeam()
						local ent = _team == TF_TEAM_RED ? KOTH_HUD_RED : KOTH_HUD_BLU
						local str = ""

						local _cap_time = arena.Koth[enemy_cap_amount] ? arena.Koth[enemy_cap_amount] : arena.Koth[enemy_partial_cap_amount]
						if (owner_team == _team)
						{
							ent.KeyValueFromString("message", format("Cap Time: %.2f", arena.Koth[enemy_cap_amount]))
							ent.AcceptInput("Display", "", p, p)
							continue
						}

						ent.KeyValueFromString("message", format("Partial Cap: %.2f", arena.Koth[partial_cap_amount]))
						ent.AcceptInput("Display", "", p, p)

					}
					partial_cap_cooldowntime = Time() + KOTH_PARTIAL_CAP_INTERVAL
					return
				}
				else if (cap_countdown_interval < Time() && owner_team == team)
				{
					printl(owner_team + " : " + team + " : " + player.GetScriptScope().Name)
					arena.Koth[cap_amount] -= KOTH_COUNTDOWN_RATE
					if (arena.Koth[cap_amount] == 0)
					{
						arena.Score[team == TF_TEAM_RED ? 0 : 1]++
						CalcArenaScore(arena_name)
					}
					foreach(p, _ in arena.CurrentPlayers)
					{
						KOTH_HUD_RED.KeyValueFromString("message", format("Cap Time: %d", arena.Koth.red_cap_time.tointeger()))
						KOTH_HUD_RED.AcceptInput("Display", "", p, p)
						KOTH_HUD_BLU.KeyValueFromString("message", format("Cap Time: %d", arena.Koth.blu_cap_time.tointeger()))
						KOTH_HUD_BLU.AcceptInput("Display", "", p, p)
					}
					cap_countdown_interval = Time() + KOTH_COUNTDOWN_INTERVAL
					return
				}
				else if (cap_decay_interval < Time() && arena.Koth[partial_cap_amount] && (self.GetOrigin() - point).Length() > radius)
				{
					arena.Koth[partial_cap_amount] -= KOTH_DECAY_RATE
					cap_decay_interval = Time() + KOTH_DECAY_INTERVAL
				}
			}
		}
		bball = function()
		{
			local team = player.GetTeam()
			local goal = team == TF_TEAM_RED ? arena.BBall.blue_hoop : arena.BBall.red_hoop
			scope.ThinkTable.BBallThink <- function() {
				if (scope.ball_ent && scope.ball_ent.IsValid())
				{
					//bball score think
					if ((self.GetOrigin() - goal).Length() < BBALL_HOOP_SIZE)
					{
						if (scope.ball_ent && scope.ball_ent.IsValid())
						{
							scope.ball_ent.Kill()
							scope.ball_ent = null
						}
						team == TF_TEAM_RED ? ++arena.Score[0] : ++arena.Score[1]
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
		//I have no idea what midair config is
		//the sourcemod plugin provided CFG only has one midair-specific map and I don't have this map
		//so I'm just using the endif config for now
		midair = function()
		{
			special_arenas.endif()
		}
		turris = function()
		{
			scope.turris_cooldown <- 0.0
			scope.ThinkTable.TurrisThink <- function() {
				//redefine here to avoid reaching out of scope
				local player = self
				if (turris_cooldown < Time())
				{
					player.Regenerate(true)
					turris_cooldown = Time() + TURRIS_REGEN_TIME
				}
			}
		}
		ammomod = function()
		{
			// printl("attr : " + player.GetCustomAttribute("hidden maxhealth non buffed", 0))

			EntFireByHandle(player, "RunScriptCode", format(@"

				local hp_ratio = Arenas[`%s`].hpratio.tofloat()
				self.AddCustomAttribute(`max health additive bonus`,(self.GetMaxHealth() * hp_ratio) - self.GetMaxHealth(), -1)
				self.AddCustomAttribute(`dmg taken increased`, 1 / hp_ratio, -1)
				self.AddCustomAttribute(`dmg from ranged reduced`, hp_ratio, -1)
				self.Regenerate(true)

			", arena_name), 0.1, null, null)
		}
		endif = function()
		{
			scope.endif_base_origin <- Vector()
			scope.endif_killme <- false

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
		infammo = function()
		{

			scope.ThinkTable.InfAmmoThink <- function() {
				//redefine here to avoid reaching out of scope
				local player = self
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

	foreach(k, func in special_arenas)
		if (k in arena && arena[k] == "1")
			func()
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
	local language_cvar = Convars.GetClientConvarValue("cl_language", player.entindex())

	if (player && player.IsValid() && !player.IsFakeClient())
	{
		local scope = player.GetScriptScope()
		language =  "Language" in scope ? scope.Language : language_cvar

		str = MGE_Localization[language][string]
	}
	if (!str) str = MGE_Localization[DEFAULT_LANGUAGE][string]

	return str
}

::MGE_ClientPrint <- function(player, target, localized_string) {
	local str = localized_string in MGE_Localization ? MGE_Localization[localized_string] : localized_string
	ClientPrint(player, target, str)
}

::GetStats <- function(player) {

	if (!ELO_TRACKING_MODE) return

	local scope = player.GetScriptScope()
	local steam_id = GetPropString(player, "m_szNetworkIDString")
	local steam_id_slice = steam_id == "BOT" ? "BOT" : steam_id.slice(5, steam_id.find("]"))
	local filename = format("mge_playerdata/%s.nut", steam_id_slice)

	if (ELO_TRACKING_MODE == 1)
	{
		if (FileToString(filename))
		{
			compilestring(FileToString(filename))()
			scope.stats <- ROOT[steam_id_slice]
			delete ROOT[steam_id_slice]
		}
		else
		{
			if (scope.stats.elo == -INT_MAX)
				scope.stats.elo <- DEFAULT_ELO
			local str = format("ROOT[\"%s\"]<-{\n", steam_id_slice)

			foreach(k, v in scope.stats)
				str += format("%s=%s\n", k.tostring(), v.tostring())

			str += "}\n"
			StringToFile(filename, str)
		}
		return
	}
	else if (ELO_TRACKING_MODE == 2 && "VPI" in getroottable())
	{
		VPI.AsyncCall({
			func="VPI_DB_MGE_ReadWritePlayerStats",
			kwargs= {
				query_mode="read",
				network_id=steam_id_slice
			},
			callback=function(response, error) {
				if (typeof(response) != "array" || !response.len())
				{
					printf(GetLocalizedString("VPI_ReadError", player), GetPropString(player, "m_szNetworkIDString"))
					return
				}
				scope.stats <- response[0]
				printf(GetLocalizedString("VPI_ReadSuccess", player), GetPropString(player, "m_szNetworkIDString"))
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
		printf(GetLocalizedString("Error_StatsNotFound", player), steam_id)
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
			VPI.AsyncCall({
				func="VPI_DB_MGE_ReadWritePlayerStats",
				kwargs= {
					query_mode="write",
					network_id=steam_id_slice,
					stats=_stats,
					additive=additive
				},
				callback=function(response, error) {
					printf(GetLocalizedString("VPI_WriteSuccess", player), GetPropString(player, "m_szNetworkIDString"))
				}
			})
		break
	}
}
