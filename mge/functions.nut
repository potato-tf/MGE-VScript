function ForceChangeClass(player, classIndex)
{
	player.SetPlayerClass(classIndex)
	SetPropInt(player, "m_Shared.m_iDesiredPlayerClass", classIndex)
}

function LoadSpawnPoints()
{
    local spawn = ""

    local config = SpawnConfigs[GetMapName()]

    ::All_Arenas <- {
        Indexes = array(config.len(), null)
    }

    //this is used for the !add command so we have the same ordering as the OG plugin
    //plugin version uses nested arrays
    All_Arenas.Indexes <- array(config.len(), null)

    // printl(config.len())
    foreach(k, v in config) {

        All_Arenas[k] <- v

        local idx = "idx" in v ? v.idx.tointeger() : -1
        local arena = All_Arenas[k]
        arena.CurrentPlayers <- {}
        arena.Queue <- []
        arena.SpawnPoints <- []
        arena.Score <- array(2, 0)
        arena.State <- AS_IDLE

        All_Arenas.Indexes[idx] = k

        foreach(a, b in v) {

            try
                if (a !=  "4player" && a.tointeger())
                {
                    local split_spawns = split(b, " ").apply(function(v) { return v.tofloat() })

                    local spawn_org = Vector(split_spawns[0], split_spawns[1], split_spawns[2])
                    local spawn_ang = split_spawns.len() > 3 ? QAngle(split_spawns[3], split_spawns[4], split_spawns[5]) : QAngle()

                    All_Arenas[k].SpawnPoints.append([spawn_org, spawn_ang])
                }
            catch(_) continue

        }
    }
}

function AddToQueue(player, arena_name)
{
    local arena = All_Arenas[arena_name]
    local current_players = arena.CurrentPlayers

    if (player in current_players || arena.Queue.find(player) != null)
        return

    //nobody is in this arena
    if (!current_players.len())
    {
        AddToArena(player, arena_name)
        return
    }

    arena.Queue.append(player)

    MGE_ClientPrint(player, 3, format(MGE_Localization.ChoseArena, arena_name))
}

function RemoveFromQueue(player, arena_name)
{
    local arena = All_Arenas[arena_name]
    local index = arena.Queue.find(player)

    try
        arena.Queue.remove(index)
    catch(_)
        if (player in arena.CurrentPlayers)
        {
            player.ForceChangeTeam(TEAM_SPECTATOR, true)
            delete arena.CurrentPlayers[player]
        }
}

function CycleQueue(player, arena_name)
{
    local arena = All_Arenas[arena_name]
    local queue = arena.Queue
    local current_players = arena.CurrentPlayers
    local next_player = queue[0]

    RemoveFromQueue(player, arena_name)
    AddToArena(next_player, arena_name)

    queue.remove(0)

    foreach(i, p in queue)
        MGE_ClientPrint(p, 3, format(MGE_Localization.InLine, i + 1))
}

function AddToArena(player, arena_name)
{

    local scope = player.GetScriptScope()
    local arena = All_Arenas[arena_name]
    local current_players = arena.CurrentPlayers

    scope.Arena <- {
        name = arena_name,
        spawns = arena.SpawnPoints,
        spawnidx = 0
    }
    current_players[player] <- scope.elo

    local team = 1
    local red = 0, blue = 0
    if (current_players.len())
        foreach(p, _ in current_players)
            p.GetTeam() == TF_TEAM_RED ? red++ : blue++

    if (red == blue)
        team = RandomInt(TF_TEAM_RED, TF_TEAM_BLUE)
    else
        team = red > blue ? TF_TEAM_RED : TF_TEAM_BLUE

    if (!GetPropInt(player, "m_Shared.m_iDesiredPlayerClass"))
        ForceChangeClass(player, TF_CLASS_SCOUT);

    player.ForceChangeTeam(team, true)
    player.ForceRespawn()
    player.SetAbsOrigin(arena.SpawnPoints[RandomInt(0, arena.SpawnPoints.len() - 1)][0])
    player.SetAbsAngles(arena.SpawnPoints[RandomInt(0, arena.SpawnPoints.len() - 1)][1])
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

    local arena = All_Arenas[arena_name]

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

            MGE_ClientPrint(winner, 3, format(MGE_Localization.XdefeatsY, Convars.GetClientConvarValue("name", winner.entindex()), winner.GetScriptScope().elo, Convars.GetClientConvarValue("name", loser.entindex()), loser.GetScriptScope().elo, fraglimit, scope.Arena.name))
            CalcELO(winner, loser)
}

function SetArenaState(arena_name, state) {
    local arena = All_Arenas[arena_name]
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

