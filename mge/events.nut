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
			local scope = player.GetScriptScope()

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
				if (!mult || mult > 0.9)
				{
					MGE_ClientPrint(player, 3, !mult ? "HandicapDisabled" : "InvalidHandicap")
					if ("handicap_hp_mult" in scope)
						delete scope.handicap_hp_mult
					return
				}
				scope.handicap_hp_mult <- mult
			}
			else if (!("handicap_hp_mult" in scope))
			{
				MGE_ClientPrint(player, 3, "NoCurrentHandicap")
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
			local ruleset = split(params.text, " ")

			ruleset[1] in arena.RulesetVote ? arena.RulesetVote[ruleset[1]]++ : arena.RulesetVote[ruleset[1]] <- 1

			if (arena.RulesetVote[ruleset[1]] != arena.MaxPlayers)
			{
				MGE_ClientPrint(player, HUD_PRINTTALK, "RulesetVote", ruleset[1])

				foreach(p, _ in arena.CurrentPlayers)
				{
					if (p == player) continue

					MGE_ClientPrint(p, HUD_PRINTTALK, "RulesetVoteArena", scope.Name, ruleset[1], ruleset[1])
				}
				return
			}

			if (arena.IsMGE && ruleset.len() > 1 && ruleset[1] in special_arenas)
			{
				arena.RulesetVote.clear()

				arena[ruleset[1]] <- "1"
				delete arena.mge

				local ruleset_inits = {
					function bball() {
						arena.IsBBall <- true
						if (!("validatedhoops" in arena.RulesetVote))
						{
							arena.RulesetVote.ballvote_pos <- array(2, null)
							arena.RulesetVote.validatedhoops <- 0
						}

						local scope = self.GetScriptScope()

						BBall_SpawnBall(arena_name, Vector(), true)

						if ("hoop" in scope)
							EntFireByHandle(scope.hoop, "Kill", "", -1, null, null)

						local hoop = CreateByClassname("prop_dynamic")
						hoop.SetModel(BBALL_HOOP_MODEL)
						hoop.SetSolid(SOLID_VPHYSICS)
						hoop.SetCollisionGroup(COLLISION_GROUP_DEBRIS)
						hoop.SetTeam(self.GetTeam())

						//save basket pos in prop scope
						hoop.ValidateScriptScope()

						hoop.SetAbsOrigin(self.EyePosition())

						hoop.AcceptInput("Color", self.GetTeam() == TF_TEAM_RED ? KOTH_RED_HUD_COLOR : KOTH_BLU_HUD_COLOR, null, null)

						DispatchSpawn(hoop)

						scope.hoop <- hoop
						scope.hoop_placed <- false
						scope.hoop_validated <- false
						scope.hoop_cooldown <- 0.0

						EntFireByHandle(self, "RunScriptCode", @"
							local visbit = 1 << self.entindex()
							SendGlobalGameEvent(`show_annotation`, {
								visibilityBitfield = visbit,
								id = self.entindex() + BBALL_HOOP_SIZE,
								text = format(`MOUSE1: Place Hoop`),
								lifetime = 5.0,
								play_sound = BBALL_PICKUP_SOUND,
								follow_entindex = self.GetScriptScope().hoop.entindex(),
								show_distance = true,
								show_effect = true
							})
						", GENERIC_DELAY, null, null)
					}
				}
				local ruleset_thinks = {
					function bball() {

						local scope = self.GetScriptScope()
						if (hoop_cooldown > Time()) return

						local hoop_trace = {

							start = self.EyePosition(),
							end = (self.EyeAngles().Forward() * INT_MAX),
							mask = hoop_placed ? -1 : MASK_PLAYERSOLID,
							ignore = self
						}

						TraceLineEx(hoop_trace)

						if (hoop_placed && !hoop_validated)
						{
							//move hoop somewhere else
							if (
								GetPropInt(self, "m_nButtons") & IN_ATTACK2 &&
								hoop_trace.hit &&
								(hoop_trace.endpos - hoop.GetOrigin()).Length() < 100.0
							) {

								scope.hoop_placed = false
								arena.RulesetVote[self.entindex()] <- scope.hoop_placed
								hoop.AcceptInput("Color", self.GetTeam() == TF_TEAM_RED ? KOTH_RED_HUD_COLOR : KOTH_BLU_HUD_COLOR, null, null)
								hoop.SetCollisionGroup(COLLISION_GROUP_DEBRIS)

								for (local glows; glows = FindByClassnameWithin(glows, "obj_teleporter", hoop.GetOrigin(), 32.0);)
									EntFireByHandle(glows, "Kill", "", -1, null, null)
							}
							if ((self.GetOrigin() - hoop.GetScriptScope().basket).Length() < BBALL_HOOP_SIZE)
							{
								hoop_validated = true,
								printl(self.GetTeam())
								arena[self.GetTeam() == TF_TEAM_RED ? "bball_hoop_red" : "bball_hoop_blue"] <- hoop.GetScriptScope().basket.ToKVString()
								// printl(arena.bball_hoop_red)
								// printl(arena.bball_hoop_blue)
								//add some constant to this value o singify it's a bball annotation
								SendGlobalGameEvent("hide_annotation", { id = self.entindex() + BBALL_HOOP_SIZE })

								arena.RulesetVote.validatedhoops++
							}
							if (arena.RulesetVote.validatedhoops == arena.MaxPlayers)
							{
								scope.temp_ball <- ShowModelToPlayer(self, [BBALL_BALL_MODEL, 0, 0], hoop_trace.endpos, QAngle(), 9999.0)
								EntFireByHandle(self, "RunScriptCode", format(@"
									SendGlobalGameEvent(`show_annotation`, {
										visibilityBitfield = 1 << self.entindex(),
										id = self.entindex() + BBALL_HOOP_SIZE,
										text = `MOUSE1: Set ball respawn point`,
										lifetime = 5.0,
										play_sound = BBALL_PICKUP_SOUND,
										follow_entindex = %d,
										show_distance = true,
										show_effect = true
									})
								", scope.temp_ball.entindex()), GENERIC_DELAY, null, null)
							}
							return
						} else if (hoop_validated && arena.RulesetVote.validatedhoops == arena.MaxPlayers && "temp_ball" in scope) {

							local ball = scope.temp_ball
							ball.KeyValueFromVector("origin", hoop_trace.pos + Vector(0, 0, 10))
							local normal_angles = VectorAngles(hoop_trace.plane_normal)
							ball.SetAbsAngles(QAngle(normal_angles.x, normal_angles.y, normal_angles.z) + QAngle(90, 0, 0))

							if (CanPlaceHoop(ball))
							{
								// arena.RulesetVote.ballvote_pos[self.GetTeam() - 2] = ball.GetOrigin()
								arena.RulesetVote.ballvote_pos[0] = ball.GetOrigin()
								arena.RulesetVote.ballvote_pos[1] = ball.GetOrigin()

								//we both picked an area close enough to eachother, start the game
								local votepos = arena.RulesetVote.ballvote_pos
								if (votepos[0] && votepos[1] && (votepos[0] - votepos[1]).Length() < 50.0)
								{

									arena.RulesetVote.ground_ball.SetOrigin(ball.GetOrigin())
									arena.RulesetVote.ground_ball.SetAbsAngles(ball.GetAbsAngles())

									arena.bball_home <- ball.GetOrigin().ToKVString()
									arena.bball_home_red <- ball.GetOrigin().ToKVString()
									arena.bball_home_blue <- ball.GetOrigin().ToKVString()

									// arena.bball_hoop_red <- scope.hoop.GetScriptScope().basket.ToKVString()
									// arena.bball_hoop_blue <- scope.hoop.GetScriptScope().basket.ToKVString()
									arena[self.GetTeam() == TF_TEAM_RED ? "bball_hoop_red" : "bball_hoop_blue"] <- scope.hoop.GetScriptScope().basket.ToKVString()

									LoadSpawnPoints(arena_name)

									printl("\n\n" + arena.IsBBall + "\n\n")

									arena.BBall.ground_ball <- arena.RulesetVote.ground_ball

									arena.IsCustomRuleset <- true
									arena.RulesetVote.clear()
									SetArenaState(arena_name, AS_COUNTDOWN)

									ball.Kill()
									delete scope.temp_ball
									if ("CustomRulesetThink" in scope.ThinkTable)
										delete scope.ThinkTable.CustomRulesetThink
									return
								}

								foreach (p, _ in arena.CurrentPlayers)
								{
									SendGlobalGameEvent("show_annotation", {
										visibilityBitfield = 1 << self.entindex(),
										id = self.entindex() + BBALL_HOOP_SIZE,
										text = format("%s wants to spawn the ball here", p.GetScriptScope().Name),
										lifetime = 3.0,
										play_sound = BBALL_PICKUP_SOUND,
										follow_entindex = ball.entindex(),
										show_distance = true,
										show_effect = true
									})
								}
								hoop_cooldown = Time() + BBALL_HOOP_PLACEMENT_COOLDOWN
							}
							return
						}

						if (!hoop_trace.hit || hoop_validated ) return

						hoop.KeyValueFromVector("origin", hoop_trace.pos)

						// Convert the plane normal to angles that face away from the wall
						local normal_angles = VectorAngles(hoop_trace.plane_normal)

						// Set the hoop angles perpendicular to the wall
						hoop.SetAbsAngles(QAngle(normal_angles.x, normal_angles.y, normal_angles.z))

						//TODO should this be inlined here?
						//where else would it be used?
						//also used for ball
						function CanPlaceHoop(ball = null) {

							if (!(GetPropInt(self, "m_nButtons") & IN_ATTACK))
								return false

							if ((self.EyePosition() - hoop_trace.pos).Length() > BBALL_MAX_HOOP_DIST)
								return false

							if (ball && ball.GetAbsAngles().x != BBALL_BALL_ANGLE_X)
								return false

							if (!ball && abs(hoop.GetAbsAngles().x) > BBALL_HOOP_MAX_ANGLE_X)
								return false

							return true
						}

						//place hoop
						if (!hoop_placed && CanPlaceHoop())
						{
							hoop_placed = true
							arena.RulesetVote[self.entindex()] <- hoop_placed
							hoop.SetCollisionGroup(COLLISION_GROUP_PLAYER)
							hoop.AcceptInput("Color", "255 255 255 255", null, null)
							hoop.GetScriptScope().basket <- (hoop.GetOrigin() + hoop.GetAbsAngles().Forward() * BBALL_HOOP_POS_OFFSET)
							hoop.GetScriptScope().hoop_validated <- false
							local readytovalidate = 0
							foreach(p, _ in arena.CurrentPlayers)
							{
								local _scope = p.GetScriptScope()
								local _hoop = _scope.hoop
								SendGlobalGameEvent("show_annotation", {
									visibilityBitfield = 1 << p.entindex(),
									id = p.entindex() + BBALL_HOOP_SIZE, //add some constant to this value to singify it's a bball annotation
									text = format("Hoop placed by %s", self.GetScriptScope().Name),
									lifetime = 5.0,
									play_sound = COUNTDOWN_SOUND,
									follow_entindex = _hoop.entindex(),
									show_distance = true,
									show_effect = true
								})

								if (p.entindex() in arena.RulesetVote && arena.RulesetVote[p.entindex()])
									readytovalidate++


								local glow_dummy = ShowModelToPlayer(p, [BBALL_HOOP_MODEL, 0, p.GetTeam() == TF_TEAM_RED ? 3 : 2], _hoop.GetOrigin(), _hoop.GetAbsAngles(), 9999.0)
								printl(glow_dummy)
								glow_dummy.AcceptInput("SetParent", "!activator", _hoop, _hoop)
								SetPropBool(glow_dummy, "m_bGlowEnabled", true)
								hoop_cooldown = Time() + BBALL_HOOP_PLACEMENT_COOLDOWN
								// p.SetOrigin(hoop.GetOrigin() + hoop.GetAbsAngles().Forward() * BBALL_HOOP_POS_OFFSET)
							}

							if (readytovalidate == arena.MaxPlayers)
							{
								foreach(p, _ in arena.CurrentPlayers)
								{
									EntFireByHandle(p, "RunScriptCode", format(@"
										self.ForceRespawn();
										SwitchWeaponSlot(self, 3);
										SwitchWeaponSlot(self, 1)
									", hoop.entindex()), GENERIC_DELAY, null, null)

									EntFireByHandle(p, "RunScriptCode", format(@"

										SendGlobalGameEvent(`show_annotation`, {
											id = self.entindex() + BBALL_HOOP_SIZE, //add some constant to this value to singify it's a bball annotation
											visibilityBitfield = 1 << self.entindex(),
											text = `Hoops placed! jump to your hoop`,
											lifetime = -1,
											play_sound = ROUND_START_SOUND,
											follow_entindex = %d,
											show_distance = true,
											show_effect = true
										})
									", hoop.entindex()), GENERIC_DELAY + 0.1, null, null)
								}
							}
						}
					}
				}

				foreach (p, _ in arena.CurrentPlayers)
				{
					ruleset_inits[ruleset[1]].call(p.GetScriptScope())
					p.GetScriptScope().ThinkTable["CustomRulesetThink"] <- ruleset_thinks[ruleset[1]]
					for(local child = p.FirstMoveChild(); child != null; child = child.NextMovePeer())
						if (startswith(child.GetClassname(), "tf_weapon"))
						{
							SetPropInt(child, "m_nRenderMode", kRenderTransColor)
							SetPropInt(child, "m_clrRender", 0)
						}
					p.AddCustomAttribute("no_attack", 1, -1)
					p.AddCustomAttribute("disable weapon switch", 1, -1)
				}
				return
			} else if (!arena.IsMGE) {
				MGE_ClientPrint(player, HUD_PRINTTALK, "InvalidRuleset", ruleset[1])
			}
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
			", GENERIC_DELAY, null, null)

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

				if (arena.State == AS_IDLE && arena.CurrentPlayers.len() == arena.MaxPlayers)
					if (!arena.IsUltiduo)
						EntFireByHandle(player, "RunScriptCode", "SetArenaState(self.GetScriptScope().arena_info.name, AS_COUNTDOWN)", COUNTDOWN_START_DELAY, null, null)
					else
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
				else if (attacker.GetActiveWeapon().GetAttribute("mod crit while airborne", 0) && attacker.InCond(TF_COND_BLASTJUMPING) && params.damagebits & DMG_CRITICAL)
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

				foreach(p, _ in arena.CurrentPlayers)
					str += format("%s: %d (%d)\n", p.GetScriptScope().Name, arena.Score[p.GetTeam() - 2], p.GetScriptScope().stats.elo)

				MGE_HUD.KeyValueFromString("message", str)

				foreach (p, _ in arena.CurrentPlayers)
					EntFireByHandle(MGE_HUD, "Display", "", GENERIC_DELAY, p, p)
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
			if (!arena.IsAmmomod)
				EntFireByHandle(victim, "RunScriptCode", "self.ForceRespawn()", arena.State == AS_IDLE ? IDLE_RESPAWN_TIME : respawntime, null, null)
			else
				EntFire("bignet", "RunScriptCode", format("SetArenaState(`%s`, AS_COUNTDOWN)", arena_name), AMMOMOD_RESPAWN_DELAY)
		}

		function OnGameEvent_player_team(params)
		{
			local player = GetPlayerFromUserID(params.userid)
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