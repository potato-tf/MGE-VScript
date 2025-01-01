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
			UpdateStats(player, player.GetScriptScope().stats, true)
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

			local scope = player.GetScriptScope()
			if (!scope)
			{
				player.ValidateScriptScope()
				scope = player.GetScriptScope()
			}

			ValidatePlayerClass(player, player.GetPlayerClass())

			EntFireByHandle(player, "RunScriptCode",  @"
				for (local child = self.FirstMoveChild(); child != null; child = child.NextMovePeer())
				{
					if (child instanceof CBaseCombatWeapon && !child.GetAttribute(`killstreak tier`, 0))
					{
						child.AddAttribute(`killstreak tier`, 1, -1)
						child.ReapplyProvision()
					}
				}
			", 0.1, null, null)

			if (!("arena_info" in scope)) return // Wait for player_activate

			if (scope.arena_info)
			{
				local arena      = scope.arena_info.arena
				local arena_name = scope.arena_info.name

				//spawned into arena with waiting player, start countdown
				if (arena.State == AS_IDLE && arena.CurrentPlayers.len() == arena.MaxPlayers)
				{
					// SetArenaState(arena.name, AS_COUNTDOWN)
					EntFireByHandle(player, "RunScriptCode", format("SetArenaState(`%s`, AS_COUNTDOWN)", arena_name), COUNTDOWN_START_DELAY, null, null)
				}

				// todo need to have a system for checking if the spawn we pick is occupied in preround
				local idx = RandomInt(0, arena.SpawnPoints.len() - 1)

				printl(arena.SpawnPoints[idx][0])
				printl(arena.SpawnPoints[idx][1])

				player.SetAbsOrigin(arena.SpawnPoints[idx][0])
				player.SnapEyeAngles(arena.SpawnPoints[idx][1])

				if (arena.State == AS_FIGHT)
					EmitSoundEx({ sound_name = SPAWN_SOUND, entity = player, volume = SPAWN_SOUND_VOLUME })

				scope.ThinkTable.ScoreThink <- function() {
					// MGE_ClientPrint(player, 4, "RED Score: "+arena.Score[0]+" BLU Score: "+arena.Score[1]+"\nRed ELO: "+player.GetScriptScope().stats.elo+" BLU ELO: "+player.GetScriptScope().stats.elo)
					local str = format("RED: %d (%d)\nBLU: %d (%d)", arena.Score[0], player.GetScriptScope().stats.elo, arena.Score[1], player.GetScriptScope().stats.elo)
					MGE_ClientPrint(player, 4, str)
				}
			}
			else
			{
				local team = player.GetTeam()
				if (!player.IsFakeClient() && (team == TF_TEAM_BLUE || team == TF_TEAM_RED))
					MGE_ClientPrint(null, 3, "[VScript MGEMod] Warning: "+player+" spawned outside of arena!")
			}
		}

		function OnGameEvent_player_changeclass(params)
		{
			local player = GetPlayerFromUserID(params.userid)
			ValidatePlayerClass(player, params["class"], true)
		}

		function OnGameEvent_player_death(params)
		{
			local victim = GetPlayerFromUserID(params.userid)
			local attacker = GetPlayerFromUserID(params.attacker)

			local victim_scope = victim.GetScriptScope()
			local attacker_scope = attacker.GetScriptScope()

			if (!victim_scope.arena_info) return

			local arena = victim_scope.arena_info.arena

			local respawntime = "respawntime" in arena ? arena.respawntime.tointeger() : 0.2
			local fraglimit = "fraglimit" in arena ? arena.fraglimit.tointeger() : 20

			if (ENABLE_ANNOUNCER)
			{
				local killstreak_total = "kill_streak_total" in params ? params.kill_streak_total.tointeger() : 0
				local str = false, hud_str = false

				printl("death flags: " + params.death_flags)
				//first blood
				if (!arena.Score[0] && !arena.Score[1])
				{
					hud_str = MGE_Localization.FirstBlood
					str = format("vo/announcer_am_firstblood0%d.mp3", RandomInt(1, 6))
				}
				//we've hit a killstreak threshold
				else if (killstreak_total && !(killstreak_total % KILLSTREAK_ANNOUNCER_INTERVAL))
				{
					str = format("vo/announcer_am_killstreak0%d.mp3", RandomInt(1, 9))

					foreach (p, _ in arena.CurrentPlayers)
						MGE_ClientPrint(p, HUD_PRINTTALK, format(MGE_Localization.Killstreak, attacker_scope.Name, killstreak_total.tostring()))
				}
				//we've hit an airshot
				else if (params.rocket_jump || (!(victim.GetFlags() & FL_ONGROUND) && victim.InCond(TF_COND_BLASTJUMPING) && (params.damagebits & DMG_BLAST)))
				{
					hud_str = MGE_Localization.Airshot
					str = format("vo/announcer_am_killstreak0%d.mp3", RandomInt(10, 11))
				}

				if (str) PlayAnnouncer(attacker, str)
				if (hud_str) MGE_ClientPrint(attacker, HUD_PRINTCENTER, hud_str)

			}

			if (attacker && attacker != victim)
				MGE_ClientPrint(victim, 3, format(MGE_Localization.HPLeft, attacker.GetHealth()))

			// Koth / bball mode doesn't count deaths
			// todo braindawg one obscure map has bball: 0 lol
			if (!("koth" in arena) && (!("bball" in arena) || arena.bball == "0") && arena.State == AS_FIGHT)
				(victim.GetTeam() == TF_TEAM_RED) ? ++arena.Score[1] : ++arena.Score[0]

			if (arena.Score[0] >= fraglimit || arena.Score[1] >= fraglimit)
			{
				local arena_name = victim_scope.arena_info.name
				CalcArenaScore(arena_name)
				SetArenaState(arena_name, AS_AFTERFIGHT)
				return
			}

			EntFireByHandle(victim, "RunScriptCode", "self.ForceRespawn()", arena.State == AS_IDLE ? IDLE_RESPAWN_TIME : respawntime, null, null)
		}

		function OnGameEvent_player_team(params)
		{
			local player = GetPlayerFromUserID(params.userid)
			local team = params.team

			if (team == TEAM_SPECTATOR)
				RemovePlayer(player)
		}
	}
}

__CollectGameEventCallbacks(MGE_Events.Events)