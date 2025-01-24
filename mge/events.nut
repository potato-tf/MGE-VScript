class MGE_Events
{
	chat_commands = {
		"add" : function(params) {

			local player = GetPlayerFromUserID(params.userid)

			// todo remove
			// local scope = player.GetScriptScope()
			// foreach (k, v in scope)
				// printl(k)

			local split_text = split(params.text, " ")

			local idx = null

			try
				idx = split_text[1].tointeger() - 1
			catch(_) {}

			if (split_text.len() < 2 || idx > Arenas_List.len() - 1 || idx < 0) {

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
					if (startswith(arena_name, split_text[1]))
					{
						AddPlayer(player, arena_name)
						break
					}
				}
			}
		},
		"remove" : function(params) {

			local player = GetPlayerFromUserID(params.userid)
			// local scope = player.GetScriptScope()

			RemovePlayer(player)
		}
		"handicap" : function(params) {

			local player = GetPlayerFromUserID(params.userid)
			local scope = player.GetScriptScope()

			local split_text = split(params.text, " ")
			local split_text_len = split_text.len()
			local mult = ToStrictNum(split_text[1], true)
			if (split_text_len > 1 && mult)
			{
				if (mult > 0.9)
				{
					MGE_ClientPrint(player, 3, "HandicapDisabled")
					if ("handicap_hp_mult" in scope)
					{
						player.RemoveCustomAttribute("max health additive penalty")
						delete scope.handicap_hp_mult
					}
					return
				}
				scope.handicap_hp_mult <- mult
			}
			else if (!("handicap_hp_mult" in scope))
			{
				MGE_ClientPrint(player, 3, "NoCurrentHandicap")
				return

			} else if (!mult)
			{
				MGE_ClientPrint(player, 3, "InvalidHandicap")
				return
			}

			MGE_ClientPrint(player, 3, "CurrentHandicap", scope.handicap_hp_mult)
		}
		"ruleset" : function(params) {
			local player = GetPlayerFromUserID(params.userid)
			local scope = player.GetScriptScope()

			if (!("arena" in scope.arena_info))
			{
				MGE_ClientPrint(player, HUD_PRINTTALK, "MustJoinArena")
				return
			}
			local arena = scope.arena_info.arena

			if (arena.State == AS_AFTERFIGHT)
			{
				MGE_ClientPrint(player, HUD_PRINTTALK, "RulesetCannotSet")
				return
			}

			local arena_name = scope.arena_info.name
			local ruleset_split = split(params.text, " ")
			local ruleset = ruleset_split[1]

			local votes = arena.RulesetVote[ruleset]
			votes[player.GetTeam() - 2] = true

			if (!votes[0] || !votes[1])
			{
				MGE_ClientPrint(player, HUD_PRINTTALK, "RulesetVote", ruleset)

				foreach(p, _ in arena.CurrentPlayers)
				{
					if (p == player) continue

					MGE_ClientPrint(p, HUD_PRINTTALK, "RulesetVoteArena", scope.Name, ruleset, ruleset)
				}
				return
			}

			SetCustomArenaRuleset(arena_name, ruleset)
		}
		"language" : function(params) {
			local lang = split(params.text, " ")
			local player = GetPlayerFromUserID(params.userid)
			if (lang.len() > 1 && lang[1] in MGE_Localization)
			{
				MGE_ClientPrint(player, 3, "LanguageSet", lang[1])
				player.GetScriptScope().Language <- lang[1]
			}
		}
		"rank" : function(params) {
			local player = GetPlayerFromUserID(params.userid)
			local scope = player.GetScriptScope()
			local rank = scope.stats.elo
			if (ELO_TRACKING_MODE)
				MGE_ClientPrint(player, 3, "MyRank", rank.tostring(), scope.stats.wins.tostring(), scope.stats.losses.tostring())
			else
				MGE_ClientPrint(player, 3, "MyRankNoRating", scope.stats.wins.tostring(), scope.stats.losses.tostring())
		}

		"help" : function(params) {
			local player = GetPlayerFromUserID(params.userid)
			MGE_ClientPrint(player, 3, "Cmd_MGECmds")
			MGE_ClientPrint(player, 3, "Cmd_SeeConsole")
			MGE_ClientPrint(player, 2, "Cmd_MGEMod")
			MGE_ClientPrint(player, 2, "Cmd_Add")
			MGE_ClientPrint(player, 2, "Cmd_Remove")
			MGE_ClientPrint(player, 2, "Cmd_First")
			MGE_ClientPrint(player, 2, "Cmd_Top5")
			MGE_ClientPrint(player, 2, "Cmd_Rank")
			MGE_ClientPrint(player, 2, "Cmd_HitBlip")
			MGE_ClientPrint(player, 2, "Cmd_Hud")
			MGE_ClientPrint(player, 2, "Cmd_Handicap")
			MGE_ClientPrint(player, 2, "Cmd_Ruleset")
			MGE_ClientPrint(player, 2, "Cmd_Language")
		}
		"mgehelp": @(params) this["help"](params)
	}
	Events = {
		function OnGameEvent_teamplay_round_start(params)
		{
			HandleRoundStart()
		}

		//updates every 8 seconds
		//this event acts effectively like a heartbeat, so we can update the server data
		//interestingly, the `master` server IP actually returns a valid SDR address, no port unfortunately.
		//I'm assuming it reads the +ip arg if SDR is not enabled, since we set ours to 0.0.0.0
		function OnGameEvent_hltv_status(params)
		{
			if (!HLTV_TEST || !("VPI" in ROOT)) return

			//no port info, not useful for SDR since we get assigned a random one
			// local ip = params.master
			// if (ip != "0.0.0.0" && SERVER_DATA.address == 0)
				// SERVER_DATA.address = ip

			LocalTime(local_time)
			SERVER_DATA.update_time = local_time
			SERVER_DATA.max_wave = counter
			SERVER_DATA.wave = counter
			local players = array(2, 0)
			local spectators = 0
			for (local i = 1; i <= MAX_CLIENTS; i++)
			{
				local player = PlayerInstanceFromIndex(i)

				if (!player || !player.IsValid()) continue

				if (player.GetTeam() == TEAM_SPECTATOR)
					spectators++
				else
					players[player.GetTeam() == TF_TEAM_RED ? 0 : 1]++
			}
			SERVER_DATA.players_red = players[0]
			SERVER_DATA.players_blu = players[1]
			SERVER_DATA.players_connecting = spectators + players[0] + players[1]
			SERVER_DATA.server_name = Convars.GetStr("hostname")

			VPI.AsyncCall({
				func = "VPI_MGE_UpdateServerData",
				kwargs = SERVER_DATA,
				callback = function(response, error) {
					if (error)
					{
						// printl(error)
						return
					}
					printl(response)
					if (SERVER_DATA.address == 0)
						SERVER_DATA.address = response.address
				}
			})
		}

		function OnGameEvent_server_spawn(params){
			printl("<<Server IP: " + server.address + ">>")
		}
		function OnGameEvent_player_activate(params)
		{
			local player = GetPlayerFromUserID(params.userid)

			player.ValidateScriptScope()
			InitPlayerScope(player)

			if (player.IsFakeClient()) return

			GetStats(player)

			MGE_ClientPrint(player, 3, "Welcome1", MGE_VERSION)
			MGE_ClientPrint(player, 3, "Welcome2")
			MGE_ClientPrint(player, 3, "Welcome3")
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
			local chat_commands = MGE_Events.chat_commands

			local split_text = split(params.text.tolower(), " ")
			local command_only = split_text[0]
			command_only = command_only.slice(1)

			local valid_chars = {
				[33] = "!",
				[46] = ".",
				[47] = "/",
				[63] = "?",
				[92] = "\\",
			}

			if (split_text[0][0] in valid_chars && command_only in chat_commands)
				chat_commands[command_only](params)
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

			local handicap = 0
			if ("handicap_hp_mult" in scope)
				handicap = scope.handicap_hp

			EntFireByHandle(player, "RunScriptCode",  format(@"
				for (local child = self.FirstMoveChild(); child != null; child = child.NextMovePeer())
				{
					if (startswith(child.GetClassname(), `tf_weapon`) || startswith(child.GetClassname(), `tf_wearable`))
					{
						if (!child.GetAttribute(`killstreak tier`, 0))
						{
							child.AddAttribute(`killstreak tier`, 1, -1)
							child.ReapplyProvision()
						}
						SetPropInt(child, `m_clrRender`, INT_COLOR_WHITE)
						SetPropInt(child, `m_nRenderMode`, kRenderFxNone)
					}
				}
				if (`handicap_hp_mult` in self.GetScriptScope() && self.GetScriptScope().handicap_hp_mult)
					self.AddCustomAttribute(`max health additive penalty`, %d)

			", handicap), GENERIC_DELAY, null, null)

			if ("arena_info" in scope && scope.arena_info)
			{

				local arena      = scope.arena_info.arena
				local arena_name = scope.arena_info.name
				//spawned into arena with waiting player, start countdown
				// EntFireByHandle(player, "RunScriptCode", format(@"

				// 	local scope 	 = self.GetScriptScope()
				// 	local arena      = scope.arena_info.arena

				// 	if (arena.State == AS_IDLE && arena.CurrentPlayers.len() == arena.MaxPlayers)
				// 		EntFireByHandle(self, `RunScriptCode`, `SetArenaState(self.GetScriptScope().arena_info.name, AS_COUNTDOWN)`, COUNTDOWN_START_DELAY, null, null)

				// ", arena_name), -1, null, null)

				local _arena = Arenas[arena_name]
				if (arena.State == AS_IDLE && arena.CurrentPlayers.len() == arena.MaxPlayers)
					if (!arena.IsUltiduo && !(arena.IsBBall && arena.State == AS_IDLE && "IsCustomRuleset" in arena && arena.IsCustomRuleset))
						EntFireByHandle(player, "RunScriptCode", "SetArenaState(self.GetScriptScope().arena_info.name, AS_COUNTDOWN)", COUNTDOWN_START_DELAY, null, null)
					else if (arena.IsUltiduo)
					{
						local current_medics = arena.Ultiduo.CurrentMedics
						foreach(p, _ in arena.CurrentPlayers)
							if (p.GetPlayerClass() == TF_CLASS_MEDIC)
								current_medics[p.GetTeam() - 2] = p

						if (current_medics[0] && current_medics[1])
							EntFireByHandle(player, "RunScriptCode", "SetArenaState(self.GetScriptScope().arena_info.name, AS_COUNTDOWN)", COUNTDOWN_START_DELAY, null, null)
						else
						{
							foreach(p_, _ in arena.CurrentPlayers)
								MGE_ClientPrint(p, HUD_PRINTTALK, "UltiduoNotEnoughMedics")

							arena.Ultiduo.CurrentMedics <- array(2, null)
						}
					}

				// SetSpecialArena(player, arena_name)
				EntFireByHandle(player, "RunScriptCode", format("SetSpecialArena(self, `%s`)", arena_name), GENERIC_DELAY, null, null)

				local idx = TryGetClearSpawnPoint(player, arena_name)
				player.SetAbsOrigin(arena.SpawnPoints[idx][0])
				player.SnapEyeAngles(arena.SpawnPoints[idx][1])

				printl(idx)

				if (arena.State == AS_FIGHT)
					EmitSoundEx({
						sound_name = SPAWN_SOUND,
						entity = player,
						volume = SPAWN_SOUND_VOLUME,
						channel = CHAN_STREAM,
						sound_level = 65
					})

				local str = format("%s\n", arena_name)
				foreach(p, _ in arena.CurrentPlayers)
				{
					local scope = p.GetScriptScope()
					local team = p.GetTeam()

					//joined spectator directly without using !remove
					if (team == TEAM_SPECTATOR) continue

					str += format("%s: %d (%d)\n", scope.Name, arena.Score[team - 2], scope.stats.elo)
				}
				MGE_HUD.KeyValueFromString("message", str)
				MGE_HUD.KeyValueFromString("color2",  player.GetTeam() == TF_TEAM_RED ? KOTH_RED_HUD_COLOR : KOTH_BLU_HUD_COLOR)
				// MGE_HUD.AcceptInput("Display", "", player, player)
				EntFireByHandle(MGE_HUD, "Display", "", GENERIC_DELAY, player, player)

				if (arena.IsBBall)
					EntFireByHandle(player, "DispatchEffect", "ParticleEffectStop", GENERIC_DELAY, null, null)
			}
			else
			{
				local team = player.GetTeam()
				if (!player.IsFakeClient() && (team == TF_TEAM_BLUE || team == TF_TEAM_RED))
					MGE_ClientPrint(null, 3, "\x07FF0000[VScript MGE] WARNING: "+player+" spawned outside of arena!")
			}
		}

		// function OnGameEvent_projectile_removed(params)
		// {
		// 	printl(params.attacker)
		// 	printl(params.num_hit)
		// 	printl(params.num_direct_hit)
		// }

		function OnGameEvent_player_changeclass(params)
		{
			local player = GetPlayerFromUserID(params.userid)
			// printl(player)
			ValidatePlayerClass(player, params["class"], true)

			local scope = player.GetScriptScope()
			local arena = scope.arena_info.arena

			if (arena.State != AS_FIGHT || arena.IsBBall || arena.IsKoth) return

			foreach(p, _ in arena.CurrentPlayers)
				MGE_ClientPrint(p, 3, player == p ? "ClassChangePoint" : "ClassChangePointOpponent")
		}

		function OnGameEvent_player_death(params)
		{
			if (REMOVE_DROPPED_WEAPONS) EntFire("tf_dropped_weapon", "Kill")
			EntFire("tf_ammo_pack", "Kill")
			local victim = GetPlayerFromUserID(params.userid)
			local attacker = GetPlayerFromUserID(params.attacker)

			local victim_scope = victim.GetScriptScope()
			local attacker_scope = attacker ? attacker.GetScriptScope() : victim_scope

			if (!victim_scope.arena_info) return

			local arena = victim_scope.arena_info.arena
			local arena_name = victim_scope.arena_info.name

			if (arena.State == AS_FIGHT)
			{
				attacker && "kills" in attacker_scope.stats ? attacker_scope.stats.kills++ : attacker_scope.stats.kills <- 1
				victim && "deaths" in victim_scope.stats ? victim_scope.stats.deaths++ : victim_scope.stats.deaths <- 1
			}

			local respawntime = "respawntime" in arena && arena.respawntime != "0" ? arena.respawntime.tofloat() : 0.2
			local fraglimit = arena.fraglimit.tointeger()
			local trace_dist = arena.IsEndif ? arena.Endif.height_threshold : arena.IsMidair ? arena.Midair.height_threshold : AIRSHOT_HEIGHT_THRESHOLD
			local str = false, hud_str = false
			// local rocket_jumping = (!(victim.GetFlags() & FL_ONGROUND) && victim.InCond(TF_COND_BLASTJUMPING)
			if (ENABLE_ANNOUNCER && arena.State == AS_FIGHT && attacker && attacker.GetScriptScope().enable_announcer)
			{
				local killstreak_total = "kill_streak_total" in params ? params.kill_streak_total.tointeger() : 0
				//first blood
				if (!arena.Score[0] && !arena.Score[1] && !arena.IsBBall && !arena.IsKoth)
				{
					hud_str = GetLocalizedString("FirstBlood", attacker)
					str = format("vo/announcer_am_firstblood0%d.mp3", RandomInt(1, 6))
				}
				//we've hit a killstreak threshold
				else if (killstreak_total && !(killstreak_total % KILLSTREAK_ANNOUNCER_INTERVAL))
				{
					str = format("vo/announcer_am_killstreak0%d.mp3", RandomInt(1, 9))

					foreach (p, _ in arena.CurrentPlayers)
						MGE_ClientPrint(p, HUD_PRINTTALK, "Killstreak", attacker_scope.Name, killstreak_total.tostring())
				}
				//we've hit an airshot
				else if (params.rocket_jump && (params.damagebits & DMG_BLAST) && TraceLine(victim.GetOrigin(), victim.GetOrigin() - Vector(0, 0, trace_dist), victim) == 1)
				{
					hud_str = GetLocalizedString("Airshot", attacker)
					str = format("vo/announcer_am_killstreak%d.mp3", RandomInt(10, 11))
					"airshots" in attacker_scope.stats ? attacker_scope.stats.airshots++ : attacker_scope.stats.airshots <- 1
				}
				//we've hit a market garden
				else if (attacker && attacker.GetActiveWeapon() && attacker.GetActiveWeapon().GetAttribute("mod crit while airborne", 0) && attacker.InCond(TF_COND_BLASTJUMPING) && params.damagebits & DMG_CRITICAL)
				{
					hud_str = GetLocalizedString("MarketGarden", attacker)
					str = format("vo/announcer_am_killstreak0%d.mp3", RandomInt(1, 9))
					"market_gardens" in attacker_scope.stats ? attacker_scope.stats.market_gardens++ : attacker_scope.stats.market_gardens <- 1
				}
			}
			if (attacker && attacker != victim)
			{
				MGE_ClientPrint(victim, 3, "HPLeft", attacker.GetHealth())

				if (str) PlayAnnouncer(attacker, str)
				if (hud_str) MGE_ClientPrint(attacker, HUD_PRINTTALK, hud_str)

				local str = format("%s\n", arena_name)

				MGE_HUD.KeyValueFromString("color2",  attacker.GetTeam() == TF_TEAM_RED ? KOTH_RED_HUD_COLOR : KOTH_BLU_HUD_COLOR)
			}

			foreach(p, _ in arena.CurrentPlayers)
				str += format("%s: %d (%d)\n", p.GetScriptScope().Name, arena.Score[p.GetTeam() - 2], p.GetScriptScope().stats.elo)

			MGE_HUD.KeyValueFromString("message", str)

			foreach (p, _ in arena.CurrentPlayers)
				EntFireByHandle(MGE_HUD, "Display", "", GENERIC_DELAY, p, p)

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
					foreach(p, _ in arena.CurrentPlayers)
						str += format("%s: %d (%d)\n", p.GetScriptScope().Name, arena.Score[p.GetTeam() - 2], p.GetScriptScope().stats.elo)

					foreach (p, _ in arena.CurrentPlayers)
						EntFireByHandle(MGE_HUD, "Display", "", GENERIC_DELAY, p, p)

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
			if (!arena.IsAmmomod)
				EntFireByHandle(victim, "RunScriptCode", "self.ForceRespawn()", arena.State == AS_IDLE ? IDLE_RESPAWN_TIME : respawntime, null, null)
			else
				EntFire("bignet", "RunScriptCode", format("SetArenaState(`%s`, AS_COUNTDOWN)", arena_name), AMMOMOD_RESPAWN_DELAY)
		}

		function OnGameEvent_player_team(params)
		{
			local player = GetPlayerFromUserID(params.userid)

			//this can return a null player handle on rafmod/potato servers but I don't remember it happening on vanilla
			if (!player) return

			local scope = player.GetScriptScope()
			local team = params.team

			if ("ThinkTable" in scope && "SpecThink" in scope.ThinkTable)
				delete scope.ThinkTable.SpecThink

			if (team == TEAM_SPECTATOR)
			{
				SetPropEntity(player, "m_hObserverTarget", MGE_LeaderboardCam)

				local spec_cooldown_time = 0.0
				if ("arena_info" in scope && "arena" in scope.arena_info && scope.arena_info.arena.State == AS_FIGHT)
				{
					MGE_ClientPrint(player, 3, "SpecRemove")
					RemovePlayer(player)
				}
				scope.ThinkTable.SpecThink <-  function()
				{
					if (spec_cooldown_time < Time())
					{
						MGE_ClientPrint(player, 3, "Adv")
						spec_cooldown_time = Time() + SPECTATOR_MESSAGE_COOLDOWN
					}
				}
			}
		}

		function OnScriptHook_OnTakeDamage(params)
		{
			local victim = params.const_entity
			local attacker = params.attacker
			local victim_scope = victim.GetScriptScope()

			if (!victim.IsPlayer()) return

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

			if (attacker != victim && "IsCustomRuleset" in arena && arena.IsCustomRuleset && arena.State != AS_FIGHT)
			{
				params.damage = 0
				return false
			}

			if (victim_scope && victim.IsPlayer() && attacker != victim && (arena.IsEndif || arena.IsMidair) && params.damage_type & DMG_BLAST && !(victim.GetFlags() & FL_ONGROUND))
			{
				local trace_dist = arena.IsEndif ? arena.Endif.height_threshold : arena.IsMidair ? arena.Midair.height_threshold : AIRSHOT_HEIGHT_THRESHOLD

				if (TraceLine(victim.GetOrigin(), victim.GetOrigin() - Vector(0, 0, trace_dist), victim) == 1)
				{
					victim.SetHealth(1)
					params.damage_type = params.damage_type | DMG_CRITICAL
				}
			}
		}

		function OnGameEvent_player_hurt(params)
		{
			local victim = GetPlayerFromUserID(params.userid)
			local victim_scope = victim.GetScriptScope()
			local arena = victim_scope && "arena_info" in victim_scope && victim_scope.arena_info ? victim_scope.arena_info.arena : {}
			local attacker = GetPlayerFromUserID(params.attacker)
			local attacker_scope = attacker ? attacker.GetScriptScope() : {}

			if (arena.State == AS_FIGHT)
			{
				"damage_taken" in victim_scope.stats ? victim_scope.stats.damage_taken += params.damageamount : victim_scope.stats.damage_taken <- params.damageamount
				if (attacker)
					"damage_dealt" in attacker_scope.stats ? attacker_scope.stats.damage_dealt += params.damageamount : attacker_scope.stats.damage_dealt <- params.damageamount
			}

			//set this here instead of OnTakeDamage since damage_force isn't set until after damage is applied
			//TODO: test this again, it wasn't working before due to multiplying vectors correctly and might work fine in OnTakeDamage
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