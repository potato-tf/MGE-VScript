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

	ClientPrint(player, 3, format(MGE_Localization.ClassIsNotAllowed, newclass))
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

			datatable.BBallSetup <- bball_points
			BBall_SpawnBall(arena_name)

		}
		// Grab spawn points
		foreach(k, v in datatable)
		{
			if (ToStrictInt(k) != null)
			{
				try
				{

					if (datatable.IsBBall && ToStrictInt(k) > BBALL_MAX_SPAWNS) continue

					local split_spawns = split(v, " ", true).apply( @(str) str.tofloat() )

					local origin = Vector(split_spawns[0], split_spawns[1], split_spawns[2])

					local angles = QAngle()
					if (split_spawns.len() == 4)
						angles = QAngle(0, split_spawns[3], 0) // Yaw only
					else if (split_spawns.len() == 6)
						angles = QAngle(split_spawns[3], split_spawns[4], split_spawns[5])

					datatable.SpawnPoints.append([origin, angles])
				}
				catch(_)
					printl(format("[VSCRIPT MGEMod] Warning: Data parsing for arena '%s' failed -- key: %s, val: %s"), arena_name, k, v.tostring())
			}
		}
	}
}

::BBall_SpawnBall <- function(arena_name, origin_override = null)
{
	local arena = Arenas[arena_name]
	local bball_points = arena.BBallSetup
	local last_score_team = arena.BBallSetup.last_score_team

	local ball_ground = CreateByClassname("tf_halloween_pickup")

	ball_ground.KeyValueFromString("pickup_sound", BBALL_PICKUP_SOUND)
	ball_ground.KeyValueFromString("pickup_particle", BBALL_PICKUP_PARTICLE)
	ball_ground.KeyValueFromString("powerup_model", BBALL_BALL_MODEL)
	ball_ground.SetOrigin(origin_override ? origin_override : last_score_team == -1 ? bball_points.neutral_home : last_score_team == TF_TEAM_RED ? bball_points.red_score_home : bball_points.blue_score_home)
	AddOutput(ball_ground, "OnPlayerTouch", "!activator", "RunScriptCode", "BBall_Pickup(self);", 0.0, 1)
	AddOutput(ball_ground, "OnPlayerTouch", "!self", "Kill", "", 0.0, 1)
	if ("ball_ground" in arena.BBallSetup && arena.BBallSetup.ball_ground.IsValid())
		arena.BBallSetup.ball_ground.Kill()
	
	arena.BBallSetup.ball_ground <- ball_ground

	EntFireByHandle(ball_ground, "RunScriptCode", "DispatchSpawn(self)", 0.2, null, null)
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
	scope.ball_ent <- ball_ent

	EntFireByHandle(ball_ent, "SetParent", "!activator", -1, player, player)
	EntFireByHandle(ball_ent, "SetParentAttachment", "flag", -1, player, player)

	EntFireByHandle(ball_ent, "RunScriptCode", "DispatchSpawn(self)", 0.1, null, null)

}

function AddBot(arena_name)
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

function RemoveBot(arena_name, all=false)
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

function RemoveAllBots()
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

	MGE_ClientPrint(player, 3, format(MGE_Localization.ChoseArena, arena_name))

	// Enough room, add to arena
	if (current_players.len() < arena.MaxPlayers)
	{
		AddToArena(player, arena_name)
		local str = ELO_TRACKING_MODE ? format(MGE_Localization.JoinsArena, scope.Name, scope.stats.elo.tostring(), arena_name) : format(MGE_Localization.JoinsArenaNoStats, scope.Name, arena_name)
		MGE_ClientPrint(null, 3, str)
	}
	// Add to queue
	else
	{
		arena.Queue.append(player)
		scope.queue <- arena.Queue

		local idx = arena.Queue.len() - 1
		local str = (idx == 0) ? format(MGE_Localization.NextInLine, arena.Queue.len().tostring()) : format(MGE_Localization.InLine, arena.Queue.len().tostring())
		MGE_ClientPrint(player, 3, str)
	}
}

::AddToArena <- function(player, arena_name)
{
	local scope = player.GetScriptScope()
	local arena = Arenas[arena_name]
	local current_players = arena.CurrentPlayers

	scope.endif_killme <- false
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
		ForceChangeClass(player, TF_CLASS_SCOUT)

	// Spawn (goto player_spawn)
	player.ForceChangeTeam(team, true)
	player.ForceRespawn()

	current_players[player] <- scope.stats.elo
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
		MGE_ClientPrint(p, 3, format(MGE_Localization.InLine, (i + 1).tostring()))
}


::CalcELO <- function(winner, loser) {

	if ( !ELO_TRACKING_MODE || 
		!winner ||
		!loser  ||
		!winner.IsValid() ||
		!loser.IsValid()  ||
		loser.IsFakeClient() ||
		winner.IsFakeClient()
	) return
	local winner_elo = winner.GetScriptScope().stats.elo
	local loser_elo = loser.GetScriptScope().stats.elo

	local winner_stats = winner.GetScriptScope().stats
	local loser_stats = loser.GetScriptScope().stats

	// ELO formula
	local El = 1.0 / (pow(10.0, (winner_elo - loser_elo).tofloat() / 400) + 1)

	local k = (winner_elo >= 2400) ? 10 : 15
	local winnerscore = floor(k * El + 0.5)
	winner_elo += winnerscore

	k = (loser_elo >= 2400) ? 10 : 15
	local loserscore = floor(k * El + 0.5)
	loser_elo -= loserscore

	// local arena_index = winner.arena
	// local time = Time()

	if (winner && winner.IsValid())
		ClientPrint(winner, 3, format("You gained %d points!", winnerscore))

	 if (loser && loser.IsValid())
		ClientPrint(loser, 3, format("You lost %d points!", loserscore))
	winner_stats.elo <- winner_elo
	loser_stats.elo <- loser_elo
	UpdateStats(winner, winner_stats, false)
	UpdateStats(loser, loser_stats, false)
	//This is necessary for when a player leaves a 2v2 arena that is almost done.
	//I don't want to penalize the player that doesn't leave, so only the winners/leavers ELO will be effected.
	// local winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner]
	// local loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser]

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

::CalcArenaScore <- function(arena_name) {

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

	MGE_ClientPrint(null, 3, format(MGE_Localization.XdefeatsY, winner_scope.Name, winner_scope.stats.elo.tostring(), loser_scope.Name, loser_scope.stats.elo.tostring(), fraglimit.tostring(), arena_name))
	CalcELO(winner, loser)
}

::TryGetClearSpawnPoint <- function(player, arena_name)
{
	local arena   = Arenas[arena_name]
	local spawns  = arena.SpawnPoints
	local mindist = ("mindist" in arena) ? arena.mindist.tofloat() : 0.0;
	local idx     = arena.SpawnIdx
	for (local i = 0; i < MAX_CLEAR_SPAWN_RETRIES; ++i)
	{
		idx = GetNextSpawnPoint(player, arena_name)
		if (!mindist) return idx

		local origin = spawns[idx][0]

		local clear = true
		for (local p; p = FindByClassnameWithin(p, "player", origin, mindist);)
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

			//reset score
			arena.Score <- array(2, 0)
			return
		},
		[AS_COUNTDOWN] = function() {

			local countdown_time = arena.cdtime.tointeger()
			foreach(p, _ in arena.CurrentPlayers)
			{

				local round_start_sound = !ENABLE_ANNOUNCER || !p.GetScriptScope().enable_announcer ? ROUND_START_SOUND : format("vo/announcer_am_roundstart0%d.mp3", RandomInt(1, 4))

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
								filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
								entity = self
							})
						", arena_name, COUNTDOWN_SOUND, COUNTDOWN_SOUND_VOLUME), i, null, null)
					}
				}

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
						filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
						entity = self
					})
				", arena_name, round_start_sound, ROUND_START_SOUND_VOLUME), countdown_time, null, null)
			}

			if (arena.IsBBall)
				BBall_SpawnBall(arena_name)
			
		},
		[AS_FIGHT] = function() {
			foreach(p, _ in arena.CurrentPlayers)
			{
				local round_start_sound = !ENABLE_ANNOUNCER || !p.GetScriptScope().enable_announcer ? ROUND_START_SOUND : format("vo/announcer_am_roundstart0%d.mp3", RandomInt(1, 4))
				PlayAnnouncer(p, round_start_sound)

				// function UnfreezePlayer(player)
				// {
				// 	player.RemoveCustomAttribute("no_attack")
				// 	player.RemoveCustomAttribute("no_jump")
				// 	player.RemoveCustomAttribute("no_duck")
				// 	player.RemoveFlags(FL_FROZEN|FL_ATCONTROLS)
				// }
				// UnfreezePlayer(p)
			}
		},
		[AS_AFTERFIGHT] = function() {
			foreach(p, _ in arena.CurrentPlayers)
			{
				//20-0
				if (arena.Score.find(arena.fraglimit.tointeger()) && arena.Score.find(0))
				{
					local sound = p.GetScriptScope().won_last_match ? format("vo/announcer_am_flawlessvictory%d.mp3", RandomInt(1, 3)) : format("vo/announcer_am_flawlessdefeat%d.mp3", RandomInt(1, 4))
					PlayAnnouncer(p, sound)
				}
				//left early
				else if (arena.Score[0] != arena.fraglimit.tointeger() && arena.Score[1] != arena.fraglimit.tointeger())
				{
					PlayAnnouncer(p, "vo/announcer_am_lastmanforfeit01.mp3")
				}
			}
			EntFire("worldspawn", "RunScriptCode", format("CycleQueue(`%s`)", arena_name), QUEUE_CYCLE_DELAY)
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

		}
		bball = function()
		{
			local team = player.GetTeam()
			local goal = team == TF_TEAM_RED ? arena.BBallSetup.red_hoop : arena.BBallSetup.blue_hoop
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
						arena.BBallSetup.last_score_team = team
						BBall_SpawnBall(arena_name)
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

			if (player.GetCustomAttribute("hidden maxhealth non buffed", 0)) return

			EntFireByHandle(player, "RunScriptCode", format(@"

				local maxhp = %d
				local hp_ratio = Arenas[`%s`].hpratio.tofloat()
				self.AddCustomAttribute(`hidden maxhealth non buffed`, maxhp - self.GetMaxHealth(), -1)
				self.AddCustomAttribute(`dmg taken increased`, (1 / hp_ratio), -1)
				self.AddCustomAttribute(`dmg from ranged reduced`, hp_ratio, -1)
				self.SetHealth(maxhp)
				self.Regenerate(true)

			", maxhp, arena_name), -1, null, null)
		}
		endif = function()
		{
			scope.endif_base_origin <- Vector()
			scope.endif_killme <- false

			if (player.GetCustomAttribute("hidden maxhealth non buffed", 0)) return
			EntFireByHandle(player, "RunScriptCode", format(@"

				self.AddCustomAttribute(`cancel falling damage`, 1, -1)
				self.AddCustomAttribute(`hidden maxhealth non buffed`, %d - self.GetMaxHealth(), -1)
				self.AddCustomAttribute(`health regen`, %d, -1)
				self.Regenerate(true)

			", 9999, 9999), -1, null, null)

			scope.ThinkTable.EndifThink <- function() {
				//redefine here to avoid reaching out of scope
				local player = self
				local origin = player.GetOrigin()

				if (player.GetFlags() & FL_ONGROUND)
					endif_base_origin = origin

				endif_killme = abs(endif_base_origin.z - origin.z) > ENDIF_HEIGHT_THRESHOLD ? true : false
			}
		}
		infammo = function()
		{
			scope.ThinkTable.InfAmmoThink <- function() {
				//redefine here to avoid reaching out of scope
				local player = self
				local weapon = player.GetActiveWeapon()
				if (weapon && weapon.Clip1() < weapon.GetMaxClip1())
					weapon.SetClip1(weapon.GetMaxClip1())
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
			filter_type = RECIPIENT_FILTER_SINGLE_PLAYER,
			entity = player
	})
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
					printf(MGE_Localization.VPI_ReadError, GetPropString(player, "m_szNetworkIDString"))
					return
				}
				scope.stats <- response[0]
				printf(MGE_Localization.VPI_ReadSuccess, GetPropString(player, "m_szNetworkIDString"))
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
		printf(MGE_Localization.Error_StatsNotFound, steam_id)
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
					printf(MGE_Localization.VPI_WriteSuccess, GetPropString(player, "m_szNetworkIDString"))
				}
			})
		break
	}
}
