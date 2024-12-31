class MGE_Events
{
	chat_commands = {
		"!add" : function(params) {
			local player = GetPlayerFromUserID(params.userid)

			// todo remove
			local scope = player.GetScriptScope()
			foreach (k, v in scope)
				printl(k)

			local splitText = split(params.text, " ")

			local idx = null

			try
				idx = splitText[1].tointeger() - 1
			catch(_) {}

			if (splitText.len() < 2 || idx > Arenas_List.len() - 1 || idx < 0) {

				ClientPrint(player, 3, "Valid arenas:")

				local i = 1
				foreach (arena_name in Arenas_List) {
					ClientPrint(player, 3, format("\t%d: %s", i, arena_name))
					i++
				}
				return
			}

			if (idx != null)
			{
				AddPlayer(player, Arenas_List[idx])
			}
			else
			{
				foreach (arena_name, _ in Arenas)
				{
					if (startswith(arena_name, splitText[1]))
					{
						AddPlayer(player, arena_name)
						break
					}
				}
			}
		},
		"!remove" : function(params) {
			local player = GetPlayerFromUserID(params.userid)
			local scope = player.GetScriptScope()

			RemovePlayer(player)
		}
	}
	Events = {
		function OnGameEvent_teamplay_round_start(params)
		{
			HandleRoundStart()
		}

		function OnGameEvent_player_activate(params)
		{
			local player = GetPlayerFromUserID(params.userid)

			player.ValidateScriptScope()
			InitPlayerScope(player)

			if (player.IsFakeClient()) return

			GetStats(player)
		}

		function OnGameEvent_player_disconnect(params)
		{
			local player = GetPlayerFromUserID(params.userid)
			RemovePlayer(player, false)
		}

		function OnGameEvent_player_say(params)
		{
			local chatCommands = MGE_Events.chat_commands
			local text = params.text.tolower()

			local splitText = split(text, " ")

			if (splitText[0][0] != 33) //ASCII for !
				return

			if (splitText[0] in chatCommands)
				chatCommands[splitText[0]](params)
		}

		function OnGameEvent_player_spawn(params)
		{
			local player = GetPlayerFromUserID(params.userid)

			player.ValidateScriptScope()
			local scope = player.GetScriptScope()
			if (!("arena_info" in scope)) return // Wait for player_activate

			if (scope.arena_info)
			{
				local arena      = scope.arena_info.arena
				local arena_name = scope.arena_info.name

				//spawned into arena with waiting player, start countdown
				if (arena.State == AS_IDLE && arena.CurrentPlayers.len() == arena.MaxPlayers)
				{
					// SetArenaState(arena.name, AS_COUNTDOWN)
					EntFireByHandle(player, "RunScriptCode", "SetArenaState("+arena_name+", AS_COUNTDOWN)", COUNTDOWN_START_DELAY, null, null)
				}

				// todo need to have a system for checking if the spawn we pick is occupied in preround
				local idx = RandomInt(0, arena.SpawnPoints.len() - 1)

				printl(arena.SpawnPoints[idx][0])
				printl(arena.SpawnPoints[idx][1])

				player.SetAbsOrigin(arena.SpawnPoints[idx][0])
				player.SnapEyeAngles(arena.SpawnPoints[idx][1])

				if (arena.State == AS_FIGHT)
					player.EmitSound("items/spawn_item.wav")

				scope.ThinkTable.ScoreThink <- function() {
					MGE_ClientPrint(player, 4, "RED Score: "+arena.Score[0]+" BLU Score: "+arena.Score[1]+"\nRed ELO: "+player.GetScriptScope().stats.elo+" BLU ELO: "+player.GetScriptScope().stats.elo)
				}
			}
			else
			{
				local team = player.GetTeam()
				if (!player.IsFakeClient() && (team == TF_TEAM_BLUE || team == TF_TEAM_RED))
					MGE_ClientPrint(null, 3, "[VScript MGEMod] Warning: "+player+" spawned outside of arena!")
			}
		}

		function OnGameEvent_player_death(params)
		{
			local player = GetPlayerFromUserID(params.userid)

			local scope = player.GetScriptScope()
			if (!scope.arena_info) return

			local arena = scope.arena_info.arena

			local respawntime = "respawntime" in arena ? arena.respawntime.tointeger() : -1

			// Koth / bball mode doesn't count deaths
			// todo braindawg one obscure map has bball: 0 lol
			if (!("koth" in arena) && !("bball" in arena) && arena.State != AS_FIGHT)
			{
				(player.GetTeam() == TF_TEAM_RED) ? ++arena.Score[1] : ++arena.Score[0]

				CalcArenaScore(player, scope.arena_info.name)
			}

			local attacker = GetPlayerFromUserID(params.attacker)

			if (attacker && attacker != player)
				MGE_ClientPrint(player, 3, format(MGE_Localization.HPLeft, attacker.GetHealth()))

			EntFireByHandle(player, "RunScriptCode", "self.ForceRespawn()", arena.State == AS_IDLE ? IDLE_RESPAWN_TIME : respawntime, null, null)
		}
	}
}

__CollectGameEventCallbacks(MGE_Events.Events)