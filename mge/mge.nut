::OnMapStart <- function()
{
    printl("[VScript MGEMod] Loaded, moving all players to spectator")
    for (local i = 1; i <= MAX_CLIENTS; i++)
    {
        local player = PlayerInstanceFromIndex(i)

        if (!player || !player.IsValid()) continue

        player.ValidateScriptScope()
        local scope = player.GetScriptScope()
        scope.elo <- -INT_MAX
        // player.TakeDamage(99999, 0, null)
        player.ForceChangeTeam(TEAM_SPECTATOR, true)
    }
    LoadSpawnPoints()

    Convars.SetValue("mp_autoteambalance", "0");
    Convars.SetValue("mp_teams_unbalance_limit", "32");
    Convars.SetValue("mp_tournament", "0");

    EntFire("tf_gamerules", "SetRedTeamRespawnWaveTime", "99999")
    EntFire("tf_gamerules", "SetBlueTeamRespawnWaveTime", "99999")

    //hide respawn text

    local player_manager = Entities.FindByClassname(null, "tf_player_manager")
    player_manager.ValidateScriptScope()

    player_manager.GetScriptScope().HideRespawnText <- function() {

        for (local i = 1; i <= MAX_CLIENTS; i++)
        {
            local player = PlayerInstanceFromIndex(i)
            if (!player || !player.IsValid()) continue
            SetPropFloatArray(player_manager, "m_flNextRespawnTime", -1, player.entindex())
        }
        return -1
    }

    AddThinkToEnt(player_manager, "HideRespawnText")
}

OnMapStart()