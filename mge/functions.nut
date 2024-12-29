function HandleRoundStart()
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

function ForceChangeClass(player, classIndex)
{
	player.SetPlayerClass(classIndex)
	SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", classIndex)
}

// tointeger() allows trailing garbage (e.g. "123abc")
// This will only allow strictly integers (also floats with only zeroes: e.g "1.00")
function ToStrictInt(str)
{
	local rex = regexp(@"-?[0-9]+(\.0+)?") // [-](digit)[.(>0 zeroes)]
	if (!rex.match(str)) return

	try
		return str.tointeger()
	catch (_)
		return
}

function LoadSpawnPoints()
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
					printl(format("[VSCRIPT MGEMod] Warning: Data parsing for arena '%s' failed -- key: %s, val: %s"), arena_name, k, v)
			}
		}
	}
}

function AddToQueue(player, arena_name)
{
	local arena = Arenas[arena_name]
	local current_players = arena.CurrentPlayers

	if (player in current_players || arena.Queue.find(player) != null)
	{
		ClientPrint(player, 3, "Already in arena");
		return
	}
	
	// Remove ourselves from our current arena if applicable
	local scope = player.GetScriptScope()
	local current_arena = ("arena_info" in scope) ? scope.arena_info.arena : null
	if (current_arena)
	{
		try
			current_arena.Queue.remove(current_arena.Queue.find(player))
		catch (_)
			if (player in current_arena.CurrentPlayers)
				delete current_arena.CurrentPlayers[player]
	}

	if (!current_players.len())
		AddToArena(player, arena_name)
	else
	{
		arena.Queue.append(player)
		MGE_ClientPrint(player, 3, format(MGE_Localization.ChoseArena, arena_name))
	}
}

function AddToArena(player, arena_name)
{
	local scope = player.GetScriptScope()
	local arena = Arenas[arena_name]
	local current_players = arena.CurrentPlayers

	scope.arena_info <- {
		arena = arena,
		name  = arena_name,
	}
	current_players[player] <- scope.elo

	// Choose the team with the lower amount of players
	local team = 1
	local red  = 0, blue = 0
	if (current_players.len())
	{
		foreach (p, _ in current_players)
		{
			local t = p.GetTeam()
			if (t != TF_TEAM_RED && t != TF_TEAM_BLUE) continue

			(t == TF_TEAM_RED) ? ++red : ++blue
		}
	}

	if (red == blue)
		team = RandomInt(TF_TEAM_RED, TF_TEAM_BLUE)
	else
		team = (red < blue) ? TF_TEAM_RED : TF_TEAM_BLUE

	// Make sure spectators have a class chosen to be able to spawn
	if (!GetPropInt(player, "m_Shared.m_iDesiredPlayerClass"))
		ForceChangeClass(player, TF_CLASS_SCOUT);

	// Spawn (goto player_spawn)
	player.ForceChangeTeam(team, true)
	player.ForceRespawn()
}

function RemoveFromQueue(player, arena_name)
{
	local arena = Arenas[arena_name]
	local index = arena.Queue.find(player)

	try
		arena.Queue.remove(index)
	catch(_)
	{
		if (player in arena.CurrentPlayers)
		{
			player.ForceChangeTeam(TEAM_SPECTATOR, true)
			delete arena.CurrentPlayers[player]
		}
	}
}

function CycleQueue(player, arena_name)
{
	local arena = Arenas[arena_name]
	local queue = arena.Queue
	local current_players = arena.CurrentPlayers
	local next_player = queue[0]

	RemoveFromQueue(player, arena_name)
	AddToArena(next_player, arena_name)

	queue.remove(0)

	foreach(i, p in queue)
		MGE_ClientPrint(p, 3, format(MGE_Localization.InLine, i + 1))
}


function CalcELO(winner, loser) {
	if ( winner.IsFakeClient() || loser.IsFakeClient())
		return;

	local winner_elo = winner.GetScriptScope().elo
	local loser_elo = loser.GetScriptScope().elo

	// ELO formula
	local El = 1.0 / (pow(10.0, (winner_elo - loser_elo).tofloat() / 400) + 1)

	local k = (winner_elo >= 2400) ? 10 : 15
	local winnerscore = floor(k * El + 0.5)
	winner.elo += winnerscore

	k = (loser_elo >= 2400) ? 10 : 15
	local loserscore = floor(k * El + 0.5)
	loser.elo -= loserscore

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

function CalcELO2(winner, winner2, loser, loser2) {

	if (winner.IsFakeClient() || loser.IsFakeClient() || g_bNoStats || loser2.IsFakeClient() || winner2.IsFakeClient())
		return;

	local Losers_ELO = (loser.elo + loser2.elo).tofloat() / 2;
	local Winners_ELO = (winner.elo + winner2.elo).tofloat() / 2;

	// ELO formula
	local El = 1 / (pow(10.0, (Winners_ELO - Losers_ELO) / 400) + 1);
	local k = (Winners_ELO >= 2400) ? 10 : 15;
	local winnerscore = floor(k * El + 0.5);
	winner.elo += winnerscore;
	winner2.elo += winnerscore;
	k = (Losers_ELO >= 2400) ? 10 : 15;
	local loserscore = floor(k * El + 0.5);
	loser.elo -= loserscore;
	loser2.elo -= loserscore;

	// local winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
	// local loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];

	// local arena_index = winner.arena;
	// local time = Time();

	// if (winner && winner.IsValid() && !g_bNoDisplayRating)
	//     ClientPrint(winner, 3, format("You gained %d points!", winnerscore));

	// if (winner2 && winner2.IsValid() && !g_bNoDisplayRating)
	//     ClientPrint(winner2, 3, format("You gained %d points!", winnerscore));

	// if (loser && loser.IsValid() && !g_bNoDisplayRating)
	//     ClientPrint(loser, 3, format("You lost %d points!", loserscore));

	// if (loser2 && loser2.IsValid() && !g_bNoDisplayRating)
	//     ClientPrint(loser2, 3, format("You lost %d points!", loserscore));
}

function CalcArenaScore(player, arena_name) {

	local arena = Arenas[arena_name]

	if (arena.State == AS_IDLE) return

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

	MGE_ClientPrint(winner, 3, format(MGE_Localization.XdefeatsY, Convars.GetClientConvarValue("name", winner.entindex()), winner.GetScriptScope().elo, Convars.GetClientConvarValue("name", loser.entindex()), loser.GetScriptScope().elo, fraglimit, scope.arena_info.name))
	CalcELO(winner, loser)
}

function SetArenaState(arena_name, state) {
	local arena = Arenas[arena_name]
	arena.State = state

	switch (state) {
		case AS_COUNTDOWN:
			break
		case AS_FIGHT:
			break
	}
}

function MGE_ClientPrint(player, target, localized_string) {
	local str = localized_string in MGE_Localization ? MGE_Localization[localized_string] : localized_string
	ClientPrint(player, target, str)
}

