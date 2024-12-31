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
		won_last_match = false
	}
	foreach (k, v in toscope)
		scope[k] <- v

	scope.PlayerThink <- function() {
		foreach(name, func in scope.ThinkTable)
			func.call(scope)
	}
	AddThinkToEnt(player, "PlayerThink")
}

::ForceChangeClass <- function(player, classIndex)
{
	player.SetPlayerClass(classIndex)
	SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", classIndex)
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
		datatable.cdtime         <- "cdtime" in datatable ? datatable.cdtime : DEFAULT_CDTIME
		datatable.MaxPlayers     <- "4player" in datatable && datatable["4player"] == "1" ? 4 : 2

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

		// Grab spawn points
		foreach(k, v in datatable)
		{
			if (ToStrictInt(k) != null)
			{
				try
				{
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

	scope.queue <- null
	scope.arena_info <- {
		arena = arena,
		name  = arena_name,
	}
	current_players[player] <- scope.stats.elo

	// Choose the team with the lower amount of players
	local team = RandomInt(TF_TEAM_RED, TF_TEAM_BLUE)
	local red  = 0, blue = 0

	foreach(p, _ in current_players)
	{
		if (p.GetTeam() == TF_TEAM_RED)
			++red
		else if (p.GetTeam() == TF_TEAM_BLUE)
			++blue
	}

	team = !red && !blue ? team : red < blue ? TF_TEAM_RED : TF_TEAM_BLUE

	printl("team: " + team)

	// Make sure spectators have a class chosen to be able to spawn
	if (!GetPropInt(player, "m_Shared.m_iDesiredPlayerClass"))
		ForceChangeClass(player, TF_CLASS_SCOUT)

	// printl(player.GetTeam())
	// Spawn (goto player_spawn)
	player.ForceChangeTeam(team, true)
	player.ForceRespawn()
	// printl(player.GetTeam())
}

::RemovePlayer <- function(player, changeteam=true)
{
	local scope = player.GetScriptScope()

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
	local next_player = queue[0]

	foreach (p, _ in arena.CurrentPlayers)
		if (!p.GetScriptScope().won_last_match)
			RemovePlayer(p)

	AddToArena(next_player, arena_name)

	queue.remove(0)

	SetArenaState(arena_name, AS_IDLE)

	foreach(i, p in queue)
		MGE_ClientPrint(p, 3, format(MGE_Localization.InLine, i + 1))
}


::CalcELO <- function(winner, loser) {

	if ( winner.IsFakeClient() || loser.IsFakeClient() || !ELO_TRACKING_MODE)
		return

	local winner_elo = winner.GetScriptScope().stats.elo
	local loser_elo = loser.GetScriptScope().stats.elo

	// ELO formula
	local El = 1.0 / (pow(10.0, (winner_elo - loser_elo).tofloat() / 400) + 1)

	local k = (winner_elo >= 2400) ? 10 : 15
	local winnerscore = floor(k * El + 0.5)
	winner.stats.elo += winnerscore

	k = (loser_elo >= 2400) ? 10 : 15
	local loserscore = floor(k * El + 0.5)
	loser.stats.elo -= loserscore

	// local arena_index = winner.arena
	// local time = Time()

	if (winner && winner.IsValid())
		ClientPrint(winner, 3, format("You gained %d points!", winnerscore))

	 if (loser && loser.IsValid())
		ClientPrint(loser, 3, format("You lost %d points!", loserscore))

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

	local fraglimit = "fraglimit" in arena ? arena.fraglimit.tointeger() : 20

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
			foreach(p, _ in arena.CurrentPlayers)
			{
				p.ForceRespawn()
				p.AddCustomAttribute("no_attack", 1.0, arena.cdtime.tofloat())

				for (local i = 0; i < arena.cdtime.tointeger(); ++i)
				{
					EntFireByHandle(p, "RunScriptCode", format(@"
						EmitSoundEx({
							sound_name = `%s`
							volume = %.2f
							filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
							entity = self
						})
					", COUNTDOWN_SOUND, COUNTDOWN_SOUND_VOLUME), i, null, null)
				}

				EntFireByHandle(p, "RunScriptCode", format(@"
					SetArenaState(`%s`, AS_FIGHT)
					EmitSoundEx({
						sound_name = `%s`,
						volume = %.2f,
						filter_type = RECIPIENT_FILTER_SINGLE_PLAYER
						entity = self
					})
				", arena_name, ROUND_START_SOUND, ROUND_START_SOUND_VOLUME), arena.cdtime.tofloat(), null, null)
			}
		},
		[AS_FIGHT] = function() {
			foreach(p, _ in arena.CurrentPlayers)
				PlayAnnouncer(p, ROUND_START_SOUND)
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
				else if (!arena.Score.find(arena.fraglimit.tointeger()))
				{
					PlayAnnouncer(p, "vo/announcer_am_lastmanforfeit01.mp3")
				}
			}
			if (arena.Queue.len())
				// CycleQueue(arena.Queue[0], arena_name)
				EntFireByHandle(arena.Queue[0], "RunScriptCode", format("CycleQueue(`%s`)", arena_name), QUEUE_CYCLE_DELAY, null, null)
		},
	}
	arenaStates[state]()
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

	local scope = player.GetScriptScope()
	local steam_id = GetPropString(player, "m_szNetworkIDString")
	local steam_id_slice = steam_id == "BOT" ? "BOT" : steam_id.slice(5, steam_id.find("]"))
	local player_file = FileToString(format("mge_playerdata/%s.nut", steam_id_slice))

	if (player_file)
	{
		scope.stats <- compilestring(player_file)()
		return
	}
	else if ("VPI" in getroottable())
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
					printl("Error getting player stats")
					return
				}
				scope.stats <- response[0]
			}
		})
	}
}

::UpdateStats <-  function(player, stats = {}, additive = false) {
	local scope = player.GetScriptScope()

	if (!("stats" in scope) || scope.stats.len() == 1)
	{
		printf("Error: stats not found for %s! fetching again and skipping update...\n", GetPropString(player, "m_szNetworkIDString"))
		GetStats(player)
		return
	}
	foreach (k, v in stats)
		additive ? scope.stats[k] += v : scope.stats[k] = v

	switch(ELO_TRACKING_MODE)
	{
		case 0:
			return
		break
		case 1:
			local file_data = format("getroottable()[\"%s\"] <- {\n", steam_id_slice)
			foreach(k, v in scope.stats)
				file_data += format("\t%s = %s\n", k.tostring(), v.tostring())
			file_data += "}\n"
			StringToFile(format("mge_playerdata/%s.nut", steam_id_slice), file_data)

		break
		case 2:
			VPI.AsyncCall({
				func="VPI_DB_MGE_ReadWritePlayerStats",
				kwargs= {
					query_mode="write",
					network_id=steam_id_slice,
					stats=stats,
					additive=additive
				},
				callback=function(response, error) {
					printf("Stats updated for %s\n", GetPropString(player, "m_szNetworkIDString"))
				}
			})
		break
	}
}
