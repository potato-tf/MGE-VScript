class MGE_Events
{
	chat_commands = {
		"add" : function(params) {

			local player = GetPlayerFromUserID(params.userid)

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

			if (!("name" in player.GetScriptScope().arena_info))
				return

			player.AddEFlags(EFL_REMOVE_FROM_ARENA)
			CycleQueue(player.GetScriptScope().arena_info.name)
			// RemovePlayer(player)
		}
		"handicap" : function(params) {

			local player = GetPlayerFromUserID(params.userid)
			local scope = player.GetScriptScope()

			local arena = "arena_info" in scope && "arena" in scope.arena_info ? scope.arena_info.arena : {State = -1}

			// if (arena.State != AS_IDLE) return

			local split_text = split(params.text, " ")
			local split_text_len = split_text.len()
			if (!("handicap_hp_penalty" in scope))
				scope.player_max_health_handicap <- player.GetMaxHealth()

			if (split_text_len > 1)
			{
				local handicap = abs(ToStrictNum(split_text[1]))
				if (handicap == 0 || handicap > scope.player_max_health_handicap)
				{
					MGE_ClientPrint(player, 3, handicap > scope.player_max_health_handicap ? "InvalidHandicap" : "HandicapDisabled")
					// player.RemoveCustomAttribute("max health additive penalty")
					if ("handicap_hp_penalty" in scope)
						delete scope.handicap_hp_penalty
					return
				}
				// player.AddCustomAttribute("max health additive penalty", handicap * -1.0, -1.0)
				scope.handicap_hp_penalty <- handicap
			}
			"handicap_hp_penalty" in scope ?
			MGE_ClientPrint(player, 3, "CurrentHandicap", -scope.handicap_hp_penalty) :
			MGE_ClientPrint(player, 3, "NoCurrentHandicap")
		}
		"announcer" : function(params) {
			local player = GetPlayerFromUserID(params.userid)
			local scope = player.GetScriptScope()
			scope.enable_announcer = !scope.enable_announcer
			MGE_ClientPrint(player, 3, scope.enable_announcer ? "AnnouncerEnabled" : "AnnouncerDisabled")
		}
		"hud" : function(params) {
			local player = GetPlayerFromUserID(params.userid)
			local scope = player.GetScriptScope()
			scope.enable_hud = !scope.enable_hud
			MGE_ClientPrint(player, 3, scope.enable_hud ? "HUDEnabled" : "HUDDisabled")
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

			if (ruleset_split.len() == 1 || !(ruleset_split[1] in special_arenas))
			{
				MGE_ClientPrint(player, HUD_PRINTTALK, "InvalidRuleset", ruleset_split.len() == 1 ? "" : ruleset_split[1])

				local valid_rulesets = ""
				foreach (ruleset, _ in special_arenas)
					valid_rulesets += format(", %s", ruleset)

				valid_rulesets = valid_rulesets.slice(1)
				ClientPrint(player, HUD_PRINTTALK, format("\x07%sValid Rulesets:\x07%s %s", MGE_COLOR_MAIN, MGE_COLOR_SUBJECT, valid_rulesets))
				return
			}
			local ruleset = ruleset_split[1]
			local fraglimit = 2 in ruleset_split ? ruleset_split[2].tointeger() : arena.fraglimit / 2

			if (!("RulesetVote" in arena))
				arena.RulesetVote <- {}

			if (!(ruleset in arena.RulesetVote))
				arena.RulesetVote[ruleset] <- array(arena.CurrentPlayers.len(), false)

			local votes = arena.RulesetVote[ruleset]
			votes.append(player)

			if (votes.len() / arena.CurrentPlayers.len() < 0.5)
			{
				MGE_ClientPrint(player, HUD_PRINTTALK, "RulesetVote", ruleset)

				foreach(p, _ in arena.CurrentPlayers)
				{
					if (p == player) continue

					MGE_ClientPrint(p, HUD_PRINTTALK, "RulesetVoteArena", scope.player_name, ruleset, ruleset)
				}
				return
			}

			SetCustomArenaRuleset(arena_name, ruleset, fraglimit)
		}
		"language" : function(params) {
			local lang = split(params.text, " ")
			local player = GetPlayerFromUserID(params.userid)
			if (lang.len() > 1 && lang[1] in MGE_Localization)
			{
				MGE_ClientPrint(player, 3, "LanguageSet", lang[1])
				player.GetScriptScope().language <- lang[1]
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
			MGE_ClientPrint(player, HUD_PRINTTALK, "Cmd_MGECmds")
			MGE_ClientPrint(player, HUD_PRINTTALK, "Cmd_SeeConsole")
			MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_MGEMod")
			MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_Add")
			MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_Remove")
			// MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_First")
			MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_Top5")
			MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_Rank")
			MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_Hud")
			MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_Handicap")
			MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_Ruleset")
			MGE_ClientPrint(player, HUD_PRINTCONSOLE, "Cmd_Language")
		}
		"mgehelp": @(params) this["help"](params)

		"top5": function(params) {
			local player = GetPlayerFromUserID(params.userid)
			local text = params.text

			if (!ENABLE_LEADERBOARD)
			{
				MGE_ClientPrint(player, HUD_PRINTTALK, "Top5Error")
				return
			}

			local stat = split(text, " ", true).len() > 1 ? split(text, " ", true)[1].tolower() : "elo"

			local data = ""
			if (stat == "elo")
			{
				for (local i = 0; i < 5; i++)
					data += format("%s: %s\n", MGE_LEADERBOARD_DATA.ELO[i][2], MGE_LEADERBOARD_DATA.ELO[i][1].tostring())

				MGE_ClientPrint(player, HUD_PRINTTALK, "Top5Title", format(" (ELO)\n%s", data))
				return

			}

			foreach(leaderboard_stat, user_data in MGE_LEADERBOARD_DATA)
			{
				if (leaderboard_stat == stat || startswith(leaderboard_stat, stat))
				{
					for (local i = 0; i < 5; i++)
						data += format("%s: %s\n", user_data[i][2], user_data[i][1].tostring())

					MGE_ClientPrint(player, HUD_PRINTTALK, "Top5Title", format(" (%s)\n%s", leaderboard_stat, data))
					break
				}
			}
		}
		"stats": function(params) {
			local player = GetPlayerFromUserID(params.userid)
			MGE_ClientPrint(player, HUD_PRINTTALK, "Cmd_SeeConsole")
			foreach(k, v in player.GetScriptScope().stats)
				ClientPrint(player, HUD_PRINTCONSOLE, k + " : " + v)
		}

		"adminscript": function(params) {
			local player = GetPlayerFromUserID(params.userid)
			local steam_id = GetPropString(player, "m_szNetworkIDString")
			local script = split(params.text, " ", true)[1]
			if (GetStr("sv_allow_point_servercommand") != "always")
			{
				MGE_ClientPrint(player, HUD_PRINTTALK, "ServerCommandDisabled")
				return
			}
			if (steam_id in ADMIN_LIST) {
				MGE_ClientPrint(player, HUD_PRINTTALK, "AdminScript", script)
				script = CharReplace(script, "'", "\"")
				printl(script)
				SendToServerConsole(format("script %s", script))
			}
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

			ALL_PLAYERS[player] <- params.userid

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

			if (player.IsFakeClient()) return

			delete ALL_PLAYERS[player]
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

			//allow spectators to talk
			//turns out this isn't necessary

			// local player = GetPlayerFromUserID(params.userid)
			// if (player.GetTeam() == TEAM_SPECTATOR)
			// {
			// 	local scope = player.GetScriptScope()
			// 	foreach(p, userid in ALL_PLAYERS)
			// 	{
			// 		if (p != player && p.GetTeam() != TEAM_SPECTATOR)
			// 		{
			// 			ClientPrint(p, HUD_PRINTTALK, format("\x07CCCCCC %s \x07FBECCB : %s", scope.player_name, params.text))
			// 		}
			// 	}
			// }
		}

		function OnGameEvent_player_spawn(params)
		{
			PreserveEnts()
			EntFire("bignet", "RunScriptCode", "PreserveEnts(false)", GENERIC_DELAY)

			local player = GetPlayerFromUserID(params.userid)

			local scope = player.GetScriptScope()
			if (!scope)
			{
				player.ValidateScriptScope()
				scope = player.GetScriptScope()
			}
			local spawnfix = FindByName(null, "__mge_spawnfix")
			printl(spawnfix)
			if (spawnfix)
			{
				spawnfix.AcceptInput("SetRespawnName", format("__mge_spawn_override_%d", player.GetTeam()), player, player)
				spawnfix.AcceptInput("StartTouch", "", player, player)
			}

			ValidatePlayerClass(player, player.GetPlayerClass())

			EntFireByHandle(player, "RunScriptCode",  @"
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
				local scope = self.GetScriptScope()
				local handicap_hp_penalty = `handicap_hp_penalty` in scope ? scope.handicap_hp_penalty : false
				local arena = `arena_info` in scope && `arena` in scope.arena_info ? scope.arena_info.arena : false

				if (!arena) return

				if (arena.State == AS_COUNTDOWN)
				{
					self.AddCustomAttribute(`no_attack`, 1.0, -1.0)
				}

				if (handicap_hp_penalty)
				{
					self.AddCustomAttribute(`max health additive penalty`, handicap_hp_penalty * - 1.0, -1.0)
					MGE_ClientPrint(self, 3, `CurrentHandicap`, -handicap_hp_penalty)
				}

			", GENERIC_DELAY, null, null)

			if ("arena_info" in scope && scope.arena_info)
			{

				local arena      = scope.arena_info.arena
				local arena_name = scope.arena_info.name
				local arena_players = arena.CurrentPlayers.keys()

				local _arena = Arenas[arena_name]


				//set arena state to countdown
				if (arena.State == AS_IDLE && arena_players.len() == arena.MaxPlayers)
					if (!arena.IsUltiduo && !((arena.IsBBall || arena.IsKoth) && arena.State == AS_IDLE && arena.IsCustomRuleset))
						EntFireByHandle(player, "RunScriptCode", "SetArenaState(self.GetScriptScope().arena_info.name, AS_COUNTDOWN)", COUNTDOWN_START_DELAY, null, null)
					//ultiduo
					else if (arena.IsUltiduo)
					{
						local current_medics = arena.Ultiduo.CurrentMedics
						foreach(p in arena_players)
							if (p.GetPlayerClass() == TF_CLASS_MEDIC)
								current_medics[p.GetTeam() - 2] = p

						if (current_medics[0] && current_medics[1])
							EntFireByHandle(player, "RunScriptCode", "SetArenaState(self.GetScriptScope().arena_info.name, AS_COUNTDOWN)", COUNTDOWN_START_DELAY, null, null)
						else
						{
							foreach(p in arena_players)
								MGE_ClientPrint(p, HUD_PRINTTALK, "UltiduoNotEnoughMedics")

							arena.Ultiduo.CurrentMedics <- array(2, null)
						}
					}


					// SetSpecialArena(player, arena_name)
				EntFireByHandle(player, "RunScriptCode", format("SetSpecialArena(self, `%s`)", arena_name), GENERIC_DELAY, null, null)

				//spawn player
				local idx = TryGetClearSpawnPoint(player, arena_name)
				player.SetAbsOrigin(arena.SpawnPoints[idx][0])
				player.SnapEyeAngles(arena.SpawnPoints[idx][1])

				//regenerate all players
				if (!arena.IsBBall)
				foreach (p in arena_players)
				{
					p.Regenerate(true)
					if (arena.IsMGE)
					{
						local hpratio = "hpratio" in arena ? arena.hpratio.tofloat() : 1.0
						EntFireByHandle(p, "RunScriptCode", format("self.SetHealth(self.GetMaxHealth() * %f)", hpratio), GENERIC_DELAY, null, null)
					}
				}

				//play spawn sound
				if (arena.State == AS_FIGHT)
					EmitSoundEx({
						sound_name = SPAWN_SOUND,
						entity = player,
						volume = SPAWN_SOUND_VOLUME,
						channel = CHAN_STREAM,
						sound_level = 65
					})

				if (scope.enable_hud)
				{
					//update hud
					local hudstr = format("%s\n", arena_name)
					foreach(p in arena_players)
					{
						local scope = p.GetScriptScope()
						local team = p.GetTeam()

						//joined spectator directly without using !remove
						if (team == TEAM_SPECTATOR) continue

						hudstr += format("%s: %d (%d)\n", scope.player_name, arena.Score[team - 2], scope.stats.elo.tointeger())
					}
					MGE_HUD.KeyValueFromString("message", hudstr)
					MGE_HUD.KeyValueFromString("color2",  player.GetTeam() == TF_TEAM_RED ? KOTH_RED_HUD_COLOR : KOTH_BLU_HUD_COLOR)
					// MGE_HUD.AcceptInput("Display", "", player, player)
					EntFireByHandle(MGE_HUD, "Display", "", GENERIC_DELAY, player, player)

				}

				// if (arena.IsBBall)
				EntFireByHandle(player, "DispatchEffect", "ParticleEffectStop", GENERIC_DELAY, null, null)
			}
			else
			{
				// tf_bot_quota spawned bots will always be forced to a team and cause error spew when they attack eachother in the void
				if (player.IsFakeClient())
					EntFireByHandle(player, "RunScriptCode", "self.AddBotAttribute(IGNORE_ENEMIES); self.TakeDamage(99999, DMG_GENERIC, self)", GENERIC_DELAY, null, null)
				else if (player.GetTeam() != TEAM_UNASSIGNED)
					MGE_ClientPrint(null, 3, "\x07FF0000[VScript MGE] WARNING: '%s' spawned outside of arena!", scope.player_name)
			}
		}

		function OnGameEvent_player_changeclass(params)
		{
			local player = GetPlayerFromUserID(params.userid)
			ValidatePlayerClass(player, params["class"], true)

			local scope = player.GetScriptScope()

			if (player.IsFakeClient()) return

			local arena = scope.arena_info.arena

			if (arena.State != AS_FIGHT || arena.IsBBall || arena.IsKoth) return

			foreach(p, _ in arena.CurrentPlayers)
				MGE_ClientPrint(p, 3, player == p ? "ClassChangePoint" : "ClassChangePointOpponent")
		}

		function OnGameEvent_player_changename(params){
			local player = GetPlayerFromUserID(params.userid)
			local scope = player.GetScriptScope()
			scope.player_name = params.newname
		}

		function OnGameEvent_player_death(params)
		{
			if (REMOVE_DROPPED_WEAPONS)
				EntFire("tf_dropped_weapon", "Kill")

			EntFire("tf_ammo_pack", "Kill")

			if (params.death_flags & TF_DEATH_FEIGN_DEATH)
				return

			local victim = GetPlayerFromUserID(params.userid)
			local attacker = GetPlayerFromUserID(params.attacker)
			local victim_origin = victim.GetOrigin()

			// disable freezecam
			// causes a bug where players will get stuck with muted freecam sound
			// likely spawning players after freeze cam starts but before it actually does the zoom-in/sfx
			SetPropEntity(victim, "m_hObserverTarget", null)

			local victim_scope = victim.GetScriptScope()
			local attacker_scope = attacker ? attacker.GetScriptScope() : victim_scope

			if (!victim_scope.arena_info) return

			local arena = victim_scope.arena_info.arena
			local arena_name = victim_scope.arena_info.name
			local arena_players = arena.CurrentPlayers.keys()

			if (arena.IsCustomRuleset && arena.State == AS_IDLE && "CustomRulesetThink" in victim_scope.ThinkTable && ("bball" in victim_scope.ThinkTable || "koth" in victim_scope.ThinkTable))
			{
				delete victim_scope.ThinkTable.CustomRulesetThink
				LoadSpawnPoints(arena_name, true)
				return
			}

			if (arena.State == AS_FIGHT)
			{
				attacker && attacker != victim && "kills" in attacker_scope.stats ? attacker_scope.stats.kills++ : attacker_scope.stats.kills <- 1
				victim && "deaths" in victim_scope.stats ? victim_scope.stats.deaths++ : victim_scope.stats.deaths <- 1
			}

			local respawntime = "respawntime" in arena && arena.respawntime != "0" ? arena.respawntime.tofloat() : 0.2
			local fraglimit = arena.fraglimit.tointeger()
			local trace_dist = arena.IsEndif ? arena.Endif.height_threshold : arena.IsMidair ? arena.Midair.height_threshold : AIRSHOT_HEIGHT_THRESHOLD
			local str = false, print_str = false
			// local rocket_jumping = (!(victim.GetFlags() & FL_ONGROUND) && victim.InCond(TF_COND_BLASTJUMPING)
			if (ENABLE_ANNOUNCER && arena.State == AS_FIGHT && attacker)
			{
				local killstreak_total = "kill_streak_total" in params ? params.kill_streak_total.tointeger() : 0
				//first blood
				if (!arena.Score[0] && !arena.Score[1] && !arena.IsBBall && !arena.IsKoth)
				{
					print_str = GetLocalizedString("FirstBlood", attacker)
					str = format("vo/announcer_am_firstblood0%d.mp3", RandomInt(1, 6))
				}
				//we've hit a killstreak threshold
				else if (killstreak_total && !(killstreak_total % KILLSTREAK_ANNOUNCER_INTERVAL))
				{
					str = format("vo/announcer_am_killstreak0%d.mp3", RandomInt(1, 9))
					print_str = format(GetLocalizedString("Killstreak", attacker), attacker_scope.player_name, killstreak_total.tostring())
				}
				//we've hit an airshot
				else if (
					params.rocket_jump &&
					params.damagebits & DMG_BLAST &&
					TraceLine(victim_origin, victim_origin - Vector(0, 0, trace_dist), victim) == 1
				) {
					print_str = GetLocalizedString("Airshot", attacker)
					str = format("vo/announcer_am_killstreak%d.mp3", RandomInt(10, 11))
					"airshots" in attacker_scope.stats ? attacker_scope.stats.airshots++ : attacker_scope.stats.airshots <- 1
				}
				//we've hit a market garden
				else if (
					attacker && attacker.GetActiveWeapon() &&
					attacker.GetActiveWeapon().GetAttribute("mod crit while airborne", 0) &&
					attacker.InCond(TF_COND_BLASTJUMPING) && params.damagebits & DMG_CRITICAL
				) {
					print_str = GetLocalizedString("MarketGarden", attacker)
					str = format("vo/announcer_am_killstreak0%d.mp3", RandomInt(1, 9))
					"market_gardens" in attacker_scope.stats ? attacker_scope.stats.market_gardens++ : attacker_scope.stats.market_gardens <- 1
				}
				foreach(p in arena_players)
				{
					if (p.GetScriptScope().enable_announcer)
					{
						if (str)
							PlayAnnouncer(p, str)
						if (print_str)
							MGE_ClientPrint(p, HUD_PRINTTALK, print_str)
					}
				}
			}

			local hudstr = format("%s\n", arena_name)
			if (attacker && attacker != victim)
			{
				MGE_ClientPrint(victim, HUD_PRINTTALK, "HPLeft", attacker.GetHealth())

				MGE_HUD.KeyValueFromString("color2",  attacker.GetTeam() == TF_TEAM_RED ? KOTH_RED_HUD_COLOR : KOTH_BLU_HUD_COLOR)
			}

			// Koth / bball mode doesn't count deaths
			if (!arena.IsKoth && !arena.IsBBall && arena.State == AS_FIGHT)
			{
				(victim.GetTeam() == TF_TEAM_RED) ? ++arena.Score[1] : ++arena.Score[0]

				CalcArenaScore(arena_name)
			}
			else if (arena.IsBBall)
			{
				local scope = victim.GetScriptScope()
				if (scope.ball_ent && scope.ball_ent.IsValid())
				{
					scope.ball_ent.Kill()
					victim.AcceptInput("DispatchEffect", "ParticleEffectStop", null, null)
					local ball_pos = victim.GetFlags() & FL_ONGROUND ? victim.EyePosition() : victim_origin + Vector(0, 0, 10)

					if (!("freeze_ball" in arena) || !arena.freeze_ball)
					{
						local ball_trace = {
							start  = victim_origin
							end    = victim_origin - Vector(0, 0, 8192)
							mask   = MASK_PLAYERSOLID
							ignore = victim
						}

						TraceLineEx(ball_trace)

						if (ball_trace.hit && ball_trace.enthit)
							ball_pos = ball_trace.endpos
					}

					BBall_SpawnBall(arena_name, ball_pos)
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
				if ("MGE_LeaderboardCam" in ROOT)
					SetPropEntity(player, "m_hObserverTarget", MGE_LeaderboardCam)

				local spec_cooldown_time = 0.0
				local arena = "arena_info" in scope && "arena" in scope.arena_info ? scope.arena_info.arena : {State = -1}
				// if (arena.State == AS_FIGHT || arena.State == AS_AFTERFIGHT)
				// {
					// MGE_ClientPrint(player, 3, "SpecRemove")
					RemovePlayer(player,  false)
				// }
				if (!player.IsFakeClient())
					scope.ThinkTable.SpecThink <- function()
					{
						if (spec_cooldown_time < Time())
						{
							MGE_ClientPrint(player, 3, "Adv")
							spec_cooldown_time = Time() + SPECTATOR_MESSAGE_COOLDOWN
						}
					}
			}
			else if (params.oldteam > TEAM_SPECTATOR && team > TEAM_SPECTATOR && !player.IsEFlagSet(EFL_ADDING_TO_ARENA))
			{
				if (!player.IsFakeClient())
				{
					printf("AUTOTEAM SWITCH BLOCKED! removing %s from arena\n", scope.player_name)
					RemovePlayer(player)
				}
			}
		}

		function OnScriptHook_OnTakeDamage(params)
		{
			local victim = params.const_entity
			local attacker = params.attacker
			local victim_scope = victim.GetScriptScope()

			if (!victim.IsPlayer()) return

			local arena = victim_scope && "arena_info" in victim_scope && victim_scope.arena_info ? Arenas[victim_scope.arena_info.name] : {}
			// if ("endif_killme" in victim_scope || ("endif" in arena && arena.endif == "1"))
			// {
			// 	if (!("midair" in arena) || arena.midair == "0")
			// 	{
			// 		print("old velocity: " + victim.GetAbsVelocity())
			// 		params.damage_force *= ENDIF_FORCE_MULT
			// 		victim.ApplyAbsVelocityImpulse(victim.GetAbsVelocity() * ENDIF_FORCE_MULT)
			// 		print("new velocity: " + victim.GetAbsVelocity())
			// 	}

			if (attacker != victim && arena.IsCustomRuleset && arena.State != AS_FIGHT)
			{
				params.early_out = true
				params.damage = 0
				return false
			}
			if ("IsAllMeat" in arena && arena.IsAllMeat)
			{
				local weapon = params.weapon
				if (!weapon) return

				local itemdef = GetPropInt(weapon, STRING_NETPROP_ITEMDEF)

				//does not account for any conditional damage bonuses/penalties
				//this technically means quickiebomb charged shots are cheating
				//I don't care, this is meant for shotguns
				local damage_mult_attribs = {
					"damage bonus" : null,
					"damage penalty" : null,
					"damage bonus HIDDEN" : null,
					"damage penalty HIDDEN" : null,
					"CARD: damage bonus" : null,
				}

				local damage_attrib_mult = 1.0
				foreach (attrib, _ in damage_mult_attribs)
				{
					local val = weapon.GetAttribute(attrib, 1.0)
					if (val)
					{
						damage_attrib_mult = val
						break
					}
				}

				local wep_ref = AllMeat_FindWeapon(weapon)

				if (!wep_ref || params.damage < ((ALLMEAT_MAX_DAMAGE[wep_ref] * arena.AllMeat.damage_threshold) * damage_attrib_mult))
					params.damage = 0.0
			}

			if (victim.IsFakeClient()) return

			if (
				victim_scope && victim.IsPlayer() &&
				attacker != victim &&
				(arena.IsEndif || arena.IsMidair) &&
				params.damage_type & DMG_BLAST &&
				!(victim.GetFlags() & FL_ONGROUND)
			) {
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

			if (!("State" in arena) && victim.IsFakeClient())
				return

			if (!victim.IsFakeClient() && arena.State == AS_FIGHT && !arena.IsEndif && !arena.IsMidair)
			{
				"damage_taken" in victim_scope.stats ? victim_scope.stats.damage_taken += params.damageamount : victim_scope.stats.damage_taken <- params.damageamount
				if (attacker && attacker != victim && !attacker.IsFakeClient())
					"damage_dealt" in attacker_scope.stats ? attacker_scope.stats.damage_dealt += params.damageamount : attacker_scope.stats.damage_dealt <- params.damageamount
			}

			//set this here instead of OnTakeDamage since damage_force isn't set until after damage is applied
			//TODO: test this again, it wasn't working before due to multiplying vectors correctly and might work fine in OnTakeDamage
			if (arena.IsEndif)
			{
				local old_vel = victim.GetAbsVelocity()
				local vel = Vector(old_vel.x * ENDIF_FORCE_MULT.x, old_vel.y * ENDIF_FORCE_MULT.y, old_vel.z * ENDIF_FORCE_MULT.z)
				victim.SetAbsVelocity(vel)
			}
		}
	}
}

__CollectGameEventCallbacks(MGE_Events.Events)