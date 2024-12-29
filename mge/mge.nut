::MGE_Init <- function()
{
	printl("[VScript MGEMod] Loaded, moving all active players to spectator")

	local default_scope = {
		"self"    : null,
		"__vname" : null,
		"__vrefs" : null,
	}

	for (local i = 1; i <= MAX_CLIENTS; i++)
	{
		local player = PlayerInstanceFromIndex(i)
		if (!player || !player.IsValid() || player.IsFakeClient()) continue

		player.ValidateScriptScope()
		local scope = player.GetScriptScope()

		// Clear scope
		foreach (k, v in scope)
			if (!(k in default_scope))
				delete scope[k]

		scope.elo <- -INT_MAX
		player.ForceChangeTeam(TEAM_SPECTATOR, true)
	}

	HandleRoundStart()
	LoadSpawnPoints()

	Convars.SetValue("mp_humans_must_join_team", "spectator")
	Convars.SetValue("mp_autoteambalance", 0);
	Convars.SetValue("mp_teams_unbalance_limit", 0);
	Convars.SetValue("mp_scrambleteams_auto", 0);
	Convars.SetValue("mp_tournament", 0);
}

MGE_Init()