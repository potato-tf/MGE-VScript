class MGE_Events
{
	chat_commands = {
		"!add" : function(params) {
			local player = GetPlayerFromUserID(params.userid)

			// todo remove
			// local scope = player.GetScriptScope()
			// foreach (k, v in scope)
				// printl(k)

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
			if (!player) return
			RemovePlayer(player, false)
			// UpdateStats(player, player.GetScriptScope().stats, true)
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

			if ("arena_info" in scope && scope.arena_info)
			{

				local arena      = scope.arena_info.arena
				local arena_name = scope.arena_info.name
				//spawned into arena with waiting player, start countdown
				EntFireByHandle(player, "RunScriptCode", format(@"

					local scope 	 = self.GetScriptScope()
					local arena      = scope.arena_info.arena

					if (arena.State == AS_IDLE && arena.CurrentPlayers.len() == arena.MaxPlayers)	
						EntFireByHandle(self, `RunScriptCode`, `SetArenaState(self.GetScriptScope().arena_info.name, AS_COUNTDOWN)`, COUNTDOWN_START_DELAY, null, null)
					
				", arena_name), -1, null, null)

				SetSpecialArena(player, arena_name)

				local idx = TryGetClearSpawnPoint(player, arena_name)
				player.SetAbsOrigin(arena.SpawnPoints[idx][0])
				player.SnapEyeAngles(arena.SpawnPoints[idx][1])

				if (arena.State == AS_FIGHT)
					EmitSoundEx({ 
						sound_name = SPAWN_SOUND,
						entity = player,
						volume = SPAWN_SOUND_VOLUME,
						channel = CHAN_STREAM,
						sound_level = 65
					})

				scope.ThinkTable.ScoreThink <- function() {
					// MGE_ClientPrint(player, 4, "RED Score: "+arena.Score[0]+" BLU Score: "+arena.Score[1]+"\nRed ELO: "+player.GetScriptScope().stats.elo+" BLU ELO: "+player.GetScriptScope().stats.elo)
					
					local _players = array(2)
					foreach (p, _ in arena.CurrentPlayers) _players[p.GetTeam() - 2] = p
					local str = _players[0] && _players[1] ? format("RED: %d (%d)\nBLU: %d (%d)", arena.Score[0], _players[0].GetScriptScope().stats.elo, arena.Score[1], _players[1].GetScriptScope().stats.elo) : ""
					MGE_ClientPrint(player, 4, str)
				}
				if (arena.IsBBall)
					EntFireByHandle(player, "DispatchEffect", "ParticleEffectStop", 0.1, null, null)
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
			// printl(player)
			ValidatePlayerClass(player, params["class"], true)
		}

		function OnGameEvent_player_death(params)
		{
			local victim = GetPlayerFromUserID(params.userid)
			local attacker = GetPlayerFromUserID(params.attacker)

			local victim_scope = victim.GetScriptScope()
			local attacker_scope = attacker ? attacker.GetScriptScope() : victim_scope

			if (!victim_scope.arena_info) return

			local arena = victim_scope.arena_info.arena
			local arena_name = victim_scope.arena_info.name

			local respawntime = "respawntime" in arena && arena.respawntime != "0" ? arena.respawntime.tointeger() : 0.2
			local fraglimit = arena.fraglimit.tointeger()

			local str = false, hud_str = false
			// local rocket_jumping = (!(victim.GetFlags() & FL_ONGROUND) && victim.InCond(TF_COND_BLASTJUMPING)
			if (ENABLE_ANNOUNCER && arena.State == AS_FIGHT && attacker && attacker.GetScriptScope().enable_announcer)
			{
				local killstreak_total = "kill_streak_total" in params ? params.kill_streak_total.tointeger() : 0
				//first blood
				if (!arena.Score[0] && !arena.Score[1] && !arena.IsBBall && !arena.IsKoth)
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
				else if (params.rocket_jump && (params.damagebits & DMG_BLAST))
				{
					hud_str = MGE_Localization.Airshot
					str = format("vo/announcer_am_killstreak%d.mp3", RandomInt(10, 11))
				}
			}
			if (attacker && attacker != victim)
			{
				MGE_ClientPrint(victim, 3, format(MGE_Localization.HPLeft, attacker.GetHealth()))

				if (str) PlayAnnouncer(attacker, str)
				if (hud_str) MGE_ClientPrint(attacker, HUD_PRINTTALK, hud_str)
			}
			
			
			if (!arena.IsBBall)
				foreach (p, _ in arena.CurrentPlayers)
				{
					p.Regenerate(true)
					//this attrib is set by ammomod
					if (!p.GetCustomAttribute("hidden maxhealth non buffed", 0) && arena.IsMGE)
						p.SetHealth(p.GetMaxHealth() * arena.hpratio.tofloat())
				}

			// Koth / bball mode doesn't count deaths
			if (!arena.IsKoth && !arena.IsBBall && arena.State == AS_FIGHT)
			{
				(victim.GetTeam() == TF_TEAM_RED) ? ++arena.Score[1] : ++arena.Score[0]

				if (arena.Score[0] >= fraglimit || arena.Score[1] >= fraglimit)
				{
					CalcArenaScore(arena_name)
					return
				}
			}

			if (arena.IsBBall)
			{
				local scope = victim.GetScriptScope()
				if (scope.ball_ent && scope.ball_ent.IsValid())
				{
					scope.ball_ent.Kill()
					victim.AcceptInput("DispatchEffect", "ParticleEffectStop", null, null)
					BBall_SpawnBall(arena_name, victim.GetFlags() & FL_ONGROUND ? victim.EyePosition() : victim.GetOrigin())
				}
			}

			printl("Respawn Time: " + (arena.State == AS_IDLE ? IDLE_RESPAWN_TIME : respawntime))
			EntFireByHandle(victim, "RunScriptCode", "self.ForceRespawn()", arena.State == AS_IDLE ? IDLE_RESPAWN_TIME : respawntime, null, null)
		}

		function OnGameEvent_player_team(params)
		{
			local player = GetPlayerFromUserID(params.userid)
			local team = params.team

			if (team == TEAM_SPECTATOR)
				RemovePlayer(player)
		}

		function OnScriptHook_OnTakeDamage(params)
		{
			local victim = params.const_entity
			local attacker = params.attacker
			local victim_scope = victim.GetScriptScope()

			local arena = victim_scope && "arena_info" in victim_scope && victim_scope.arena_info ? victim_scope.arena_info.arena : {}
			// if ("endif_killme" in victim_scope || ("endif" in arena && arena.endif == "1"))
			// {
			// 	if (!("midair" in arena) || arena.midair == "0")
			// 	{
			// 		print("old velocity: " + victim.GetAbsVelocity())
			// 		params.damage_force *= ENDIF_FORCE_MULT
			// 		victim.ApplyAbsVelocityImpulse(victim.GetAbsVelocity() * ENDIF_FORCE_MULT)
			// 		print("new velocity: " + victim.GetAbsVelocity())
			// 	}

				if (victim != attacker &&"endif_killme" in victim_scope && victim_scope.endif_killme && params.damage_type & DMG_BLAST)
				{
					victim.SetHealth(1)
					params.damage_type = params.damage_type | DMG_CRITICAL
				}
		}

		function OnGameEvent_player_hurt(params)
		{
			local victim = GetPlayerFromUserID(params.userid)
			local attacker = GetPlayerFromUserID(params.attacker)
			local victim_scope = victim.GetScriptScope()
			local attacker_scope = attacker ? attacker.GetScriptScope() : victim_scope
			local arena = victim_scope && "arena_info" in victim_scope && victim_scope.arena_info ? victim_scope.arena_info.arena : {}

			if ("endif" in arena && arena.endif == "1")
			{
				if (!("midair" in arena) || arena.midair == "0")
				{
					local old_vel = victim.GetAbsVelocity()
					local vel = Vector(old_vel.x * ENDIF_FORCE_MULT.x, old_vel.y * ENDIF_FORCE_MULT.y, old_vel.z * ENDIF_FORCE_MULT.z)
					victim.SetAbsVelocity(vel)
				}
			}
		}
	}
}

__CollectGameEventCallbacks(MGE_Events.Events)