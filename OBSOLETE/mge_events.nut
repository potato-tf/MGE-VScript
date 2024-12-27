local mge_ent = CreateByClassname("move_rope")
mge_ent.KeyValueFromString("targetname", "__mge_ent")
mge_ent.DispatchSpawn()
mge_ent.ValidateScriptScope()

class MGE_Events {

    chatCommands = {
        "!add" : function(params) {

            local player = GetPlayerFromUserID(params.userid)

            local splitText = split(params.text, " ")

            if (splitText.len() < 2 || splitText[1].tointeger() > g_sArenaOriginalName.len()) {

                ClientPrint(player, 3, "Valid areas:")

                local originalname_len = g_sArenaOriginalName.len()
                for (local i = 1; i < originalname_len; i++) {
                    if (g_sArenaOriginalName[i] == "") break
                    ClientPrint(player, 3, format("\t%d: %s", i, g_sArenaOriginalName[i]))
                }

                return

            }
            RemoveFromQueue(player, true)
            AddInQueue(player, splitText[1].tointeger(), true, TEAM_RED);
        },
        "!remove" : function(params) {

            local player = GetPlayerFromUserID(params.userid)

            RemoveFromQueue(player, true)
        }
    }

    Entities = {
        function OnTouchPoint(entity, other)
        {
            local client = other;
            if (!IsValidClient(client))
                return Plugin_Continue;
        }
        function OnEndTouchPoint(entity, other)
        {
            local client = other;

            local arena_index = g_iPlayerArena[client];
            local client_slot = g_iPlayerSlot[client];

            g_bPlayerTouchPoint[arena_index][client_slot] = false;
        }
    }

    Events = {

        function OnGameEvent_player_say(params)
        {
            local chatCommands = MGE_Events.chatCommands
            local text = params.text.tolower()

            local splitText = split(text, " ")

            if (splitText[0][0] != 33) //ASCII for !
                return

            if (splitText[0] in chatCommands)
                chatCommands[splitText[0]](params)


        }
        function OnGameEvent_player_spawn(params)
        {
            local hClient = GetPlayerFromUserID(params.userid);
            local iClient = hClient.entindex();
            local arena_index = g_iPlayerArena[iClient];
            EntFireByHandle(hClient, "RunScriptCode", @"

                local _length =  (self.GetOrigin() - Vector(-3774.000000, 7768.000000, -1452.118774)).Length()
                if (_length < 100)
                {
                    self.TakeDamage(1000000, 0, self)
                    return
                }
            ", 0.2, null, null)

            g_tfctPlayerClass[iClient] = hClient.GetPlayerClass();

            if (!g_bFourPersonArena[arena_index] && g_iPlayerSlot[iClient] != SLOT_ONE && g_iPlayerSlot[iClient] != SLOT_TWO)
                hClient.ForceChangeTeam(TEAM_SPEC, true);

            else if (g_bFourPersonArena[arena_index] && g_iPlayerSlot[iClient] != SLOT_ONE && g_iPlayerSlot[iClient] != SLOT_TWO && (g_iPlayerSlot[iClient] != SLOT_THREE && g_iPlayerSlot[iClient] != SLOT_FOUR))
                hClient.ForceChangeTeam(TEAM_SPEC, true);

            if (g_bArenaMGE[arena_index])
            {
                g_iPlayerHP[iClient] = g_iPlayerMaxHP[iClient] * g_fArenaHPRatio[arena_index];
                ShowSpecHudToArena(arena_index);
            }

            if (g_bArenaBBall[arena_index])
            {
                g_bPlayerHasIntel[iClient] = false;
            }
        }

        function OnGameEvent_teamplay_win_panel(params)
        {
            // Disable stats so people leaving at the end of the map don't lose points.
            g_bNoStats = true;
        }

        function OnGameEvent_player_hurt(params)
        {
            local hVictim = GetPlayerFromUserID(params.userid);
            local iVictim = hVictim.entindex();

            local hAttacker = GetPlayerFromUserID(params.attacker);
            local iAttacker = hAttacker ? hAttacker.entindex() : 0;

            local arena_index = g_iPlayerArena[iVictim];
            local iDamage = params.damageamount;

            if (!hAttacker || iVictim != hAttacker) // If the attacker wasn't the person being hurt, or the world (fall damage).
            {
                local shootsRocketsOrPipes = ShootsRocketsOrPipes(iAttacker);
                if (g_bArenaEndif[arena_index])
                {
                    if (shootsRocketsOrPipes)
                        EntFireByHandle(hVictim, "RunScriptCode", "BoostVectors("+iVictim+")", 0.1, null, null);
                }

                if (g_bPlayerTakenDirectHit[iVictim])
                {
                    local isVictimInAir = !hVictim.IsEFlagSet(FL_ONGROUND);

                    if (isVictimInAir)
                    {
                        //airshot
                        local dist = DistanceAboveGround(iVictim);
                        if (dist >= g_iAirshotHeight)
                        {
                            if (g_bArenaMidair[arena_index])
                                g_iPlayerHP[iVictim] -= 1;

                            if (g_bArenaEndif[arena_index] && dist >= 250)
                            {
                                g_iPlayerHP[iVictim] = -1;
                            }
                        }
                    }
                }
            }

            g_bPlayerTakenDirectHit[iVictim] = false;

            if (g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index])
                g_iPlayerHP[iVictim] = hVictim.GetHealth()
            else if (g_bArenaAmmomod[arena_index])
                g_iPlayerHP[iVictim] -= iDamage

            //TODO: Look into getting rid of the crutch. Possible memory leak/performance issue?
            g_bPlayerRestoringAmmo[iAttacker] = false; //inf ammo crutch

            if (g_bArenaAmmomod[arena_index] || g_bArenaMidair[arena_index] || g_bArenaEndif[arena_index])
            {
                if (g_iPlayerHP[iVictim] <= 0)
                    hVictim.SetHealth(0)
                else
                    hVictim.SetHealth(g_iPlayerMaxHP[iVictim])
            }

            ShowPlayerHud(iVictim)
            ShowPlayerHud(iAttacker)
            // ShowSpecHudToArena(g_iPlayerArena[iVictim])
        }

        function OnGameEvent_teamplay_round_start(params)
        {
            // gcvar_WfP.SetInt(1); //cancel waiting for players
        
            //Be totally certain that the models are chached so they can be hooked
            PrecacheModel(MODEL_BRIEFCASE);
            PrecacheModel(MODEL_AMMOPACK);
        
            for (local i = 0; i <= g_iArenaCount; i++)
            {
                if (g_bArenaBBall[i])
                {
                    local hoop_2_loc = array(3, 0.0);
                    hoop_2_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][0];
                    hoop_2_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][1];
                    hoop_2_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][2];
        
                    local hoop_1_loc = array(3, 0.0);
                    hoop_1_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][0];
                    hoop_1_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][1];
                    hoop_2_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][2];

                    hoop_2_loc = Vector(hoop_2_loc[0], hoop_2_loc[1], hoop_2_loc[2]);

                    local hoop_1_loc = array(3, 0.0);
                    hoop_1_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][0];
                    hoop_1_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][1];
                    hoop_1_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][2];

                    hoop_1_loc = Vector(hoop_1_loc[0], hoop_1_loc[1], hoop_1_loc[2]);

                    if (g_iBBallHoop[i][SLOT_ONE].IsValid() && g_iBBallHoop[i][SLOT_ONE] > 0)
                    {
                        g_iBBallHoop[i][SLOT_ONE].Kill();
                        g_iBBallHoop[i][SLOT_ONE] = -1;
                    } else if (g_iBBallHoop[i][SLOT_ONE] != -1) {  // g_iBBallHoop[i][SLOT_ONE] equaling -1 is not a bad thing, so don't print an error for it.
                        //LogError("[%s] Event_RoundStart fired, but could not remove old hoop [%d]!.", g_sArenaName[i], g_iBBallHoop[i][SLOT_ONE]);
                        //LogError("[%s] Resetting SLOT_ONE hoop array index %i.", g_sArenaName[i], i);
                        g_iBBallHoop[i][SLOT_ONE] = -1;
                    }
        
                    if (g_iBBallHoop[i][SLOT_TWO].IsValid() && g_iBBallHoop[i][SLOT_TWO] > 0)
                    {
                        g_iBBallHoop[i][SLOT_TWO].Kill();
                        g_iBBallHoop[i][SLOT_TWO] = -1;
                    } else if (g_iBBallHoop[i][SLOT_TWO] != -1) {  // g_iBBallHoop[i][SLOT_TWO] equaling -1 is not a bad thing, so don't print an error for it.
                        //LogError("[%s] Event_RoundStart fired, but could not remove old hoop [%d]!.", g_sArenaName[i], g_iBBallHoop[i][SLOT_TWO]);
                        //LogError("[%s] Resetting SLOT_TWO hoop array index %i.", g_sArenaName[i], i);
                        g_iBBallHoop[i][SLOT_TWO] = -1;
                    }
        
                    if (g_iBBallHoop[i][SLOT_ONE] == -1)
                    {
                        g_iBBallHoop[i][SLOT_ONE] = CreateEntityByName("item_ammopack_small");
                        g_iBBallHoop[i][SLOT_ONE].SetOrigin(hoop_1_loc);
                        DispatchSpawn(g_iBBallHoop[i][SLOT_ONE]);
                        // SetEntProp(g_iBBallHoop[i][SLOT_ONE], Prop_Send, "m_iTeamNum", 1, 4);
                        SetPropInt(g_iBBallHoop[i][SLOT_ONE], "m_iTeamNum", 1, 4);
        
                        //SDKUnhook(g_iBBallHoop[i][SLOT_ONE], SDKHook_StartTouch, OnTouchHoop);
                        // SDKHook(g_iBBallHoop[i][SLOT_ONE], SDKHook_StartTouch, OnTouchHoop);

                        // g_iBBallHoop[i][SLOT_ONE]
                        AddOutput(g_iBBallHoop[i][SLOT_ONE], "OnPlayerTouch", "RunScriptCode", "OnTouchIntel(self);", 0.0, -1, null);

                    }
        
                    if (g_iBBallHoop[i][SLOT_TWO] == -1)
                    {
                        g_iBBallHoop[i][SLOT_TWO] = CreateEntityByName("item_ammopack_small");
                        g_iBBallHoop[i][SLOT_TWO].SetOrigin(hoop_2_loc);
                        DispatchSpawn(g_iBBallHoop[i][SLOT_TWO]);
                        // SetEntProp(g_iBBallHoop[i][SLOT_TWO], Prop_Send, "m_iTeamNum", 1, 4);
                        SetPropInt(g_iBBallHoop[i][SLOT_TWO], "m_iTeamNum", 1, 4);
        
                        //SDKUnhook(g_iBBallHoop[i][SLOT_TWO], SDKHook_StartTouch, OnTouchHoop);
                        // SDKHook(g_iBBallHoop[i][SLOT_TWO], SDKHook_StartTouch, OnTouchHoop);
                    }
        
                    if (g_bVisibleHoops[i] == false)
                    {
                        // Could have used SetRenderMode here, but it had the unfortunate side-effect of also making the intel invisible.
                        // Luckily, inputting "Disable" to most entities makes them invisible, so it was a valid workaround.
                        AcceptEntityInput(g_iBBallHoop[i][SLOT_ONE], "Disable");
                        AcceptEntityInput(g_iBBallHoop[i][SLOT_TWO], "Disable");
                    }
                }
        
                if (g_bArenaKoth[i])
                {
                    local point_loc = array(3, 0.0);
                    point_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][0];
                    point_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][1];
                    point_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][2];
                    point_loc = Vector(point_loc[0], point_loc[1], point_loc[2]);
        
                    if (g_iCapturePoint[i].IsValid() && g_iCapturePoint[i] > 0)
                    {
                        g_iCapturePoint[i].Kill();
                        g_iCapturePoint[i] = -1;
                    }
                    // g_iCapturePoint[i] equaling -1 is not a bad thing, so don't print an error for it.
                    else if (g_iCapturePoint[i] != -1)
                    {
                        g_iCapturePoint[i] = -1;
                    }
        
                    if (g_iCapturePoint[i] == -1)
                    {
                        g_iCapturePoint[i] = CreateEntityByName("item_ammopack_small");
                        g_iCapturePoint[i].SetOrigin(point_loc);
                        DispatchSpawn(g_iCapturePoint[i]);
                        // SetEntProp(g_iCapturePoint[i], Prop_Send, "m_iTeamNum", 1, 4);
                        SetPropInt(g_iCapturePoint[i], "m_iTeamNum", 1, 4);
                        SetEntityModel(g_iCapturePoint[i], MODEL_POINT);
                        // DispatchKeyValue(g_iCapturePoint[i], "powerup_model", MODEL_BRIEFCASE);
        
                        //SDKUnhook(g_iCapturePoint[i], SDKHook_StartTouch, OnTouchPoint);
                        // SDKHook(g_iCapturePoint[i], SDKHook_StartTouch, OnTouchPoint);
                        //SDKUnhook(g_iCapturePoint[i], SDKHook_EndTouch, OnEndTouchPoint);
                        // SDKHook(g_iCapturePoint[i], SDKHook_EndTouch, OnEndTouchPoint);

                        AddOutput(g_iCapturePoint[i], "OnPlayerTouch", "RunScriptCode", "OnTouchIntel(self);", 0.0, -1, null);
                    }
        
                    // Could have used SetRenderMode here, but it had the unfortunate side-effect of also making the intel invisible.
                    // Luckily, inputting "Disable" to most entities makes them invisible, so it was a valid workaround.
                    // AcceptEntityInput(g_iCapturePoint[i], "Disable");
                    g_iCapturePoint[i].AcceptInput("Disable");
        
                }
            }
        }

        function OnScriptHook_OnTakeDamage(params)
        {
            // Fall damage negation.
            if ((params.damage_type & DMG_FALL) && g_bBlockFallDamage)
            {
                params.damage = 0.0;
                return false;
            }
        }

        function OnGameEvent_player_disconnect(params)
        {
            local hClient = GetPlayerFromUserID(params.userid);
            local iClient = hClient.entindex();

            // We ignore the kick queue check for this function only so that clients that get kicked still get their elo calculated
            if (g_iPlayerArena[iClient])
            {
                RemoveFromQueue(iClient, true);
            }
            else
            {
                local arena_index = g_iPlayerArena[iClient];
                local player_slot = g_iPlayerSlot[iClient];
                local after_leaver_slot = player_slot + 1;
                local foe_slot = (player_slot == SLOT_ONE || player_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
                local foe = g_iArenaQueue[arena_index][foe_slot];

                //Turn all this logic into a helper meathod
                local player_teammate, foe2;

                if (g_bFourPersonArena[arena_index])
                {
                    player_teammate = getTeammate(player_slot, arena_index);
                    foe2 = getTeammate(foe_slot, arena_index);
                }

                g_iPlayerArena[iClient] = 0;
                g_iPlayerSlot[iClient] = 0;
                g_iArenaQueue[arena_index][player_slot] = 0;
                g_iPlayerHandicap[iClient] = 0;

                if (g_bFourPersonArena[arena_index])
                {
                    if (g_iArenaQueue[arena_index][SLOT_FOUR + 1])
                    {
                        local next_client = g_iArenaQueue[arena_index][SLOT_FOUR + 1];
                        g_iArenaQueue[arena_index][SLOT_FOUR + 1] = 0;
                        g_iArenaQueue[arena_index][player_slot] = next_client;
                        g_iPlayerSlot[next_client] = player_slot;
                        after_leaver_slot = SLOT_FOUR + 2;
                        local playername = "";
                        // CreateTimer(2.0, Timer_StartDuel, arena_index);
                        EntFire("worldspawn", "RunScriptCode", "StartDuel("+arena_index+");", 2.0, null, null);
                        playername = Convars.GetClientConvarValue("name", next_client);

                        if (!g_bNoStats && !g_bNoDisplayRating)
                            MC_PrintToChatAll("%t", "JoinsArena", playername, g_iPlayerRating[next_client], g_sArenaName[arena_index]);
                        else
                            MC_PrintToChatAll("%t", "JoinsArenaNoStats", playername, g_sArenaName[arena_index]);


                    } else {

                        if (foe && IsFakeClient(foe))
                        {
                            local cvar = Convars.GetInt("tf_bot_quota");
                            Convars.SetValue("tf_bot_quota", cvar - 1);
                        }

                        if (foe2 && IsFakeClient(foe2))
                        {
                            local cvar = Convars.GetInt("tf_bot_quota");
                            Convars.SetValue("tf_bot_quota", cvar - 1);
                        }

                        if (player_teammate && IsFakeClient(player_teammate))
                        {
                            local cvar = Convars.GetInt("tf_bot_quota");
                            Convars.SetValue("tf_bot_quota", cvar - 1);
                        }

                        g_iArenaStatus[arena_index] = AS_IDLE;
                        return;
                    }
                }
                else
                {
                    if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
                    {
                        local next_client = g_iArenaQueue[arena_index][SLOT_TWO + 1];
                        g_iArenaQueue[arena_index][SLOT_TWO + 1] = 0;
                        g_iArenaQueue[arena_index][player_slot] = next_client;
                        g_iPlayerSlot[next_client] = player_slot;
                        after_leaver_slot = SLOT_TWO + 2;
                        local playername =  "";
                        // CreateTimer(2.0, Timer_StartDuel, arena_index);
                        EntFire("worldspawn", "RunScriptCode", "StartDuel("+arena_index+");", 2.0, null, null);
                        playername = Convars.GetClientConvarValue("name", next_client);

                        if (!g_bNoStats && !g_bNoDisplayRating)
                            ClientPrint(3, null, format("%t", "JoinsArena", playername, g_iPlayerRating[next_client], g_sArenaName[arena_index]));
                        else
                            ClientPrint(3, null, format("%t", "JoinsArenaNoStats", playername, g_sArenaName[arena_index]));


                    } else {
                        if (foe && IsFakeClient(foe))
                        {
                            local cvar = Convars.GetInt("tf_bot_quota");
                            Convars.SetValue("tf_bot_quota", cvar - 1);
                        }

                        g_iArenaStatus[arena_index] = AS_IDLE;
                        return;
                    }
                }

                if (g_iArenaQueue[arena_index][after_leaver_slot])
                {
                    while (g_iArenaQueue[arena_index][after_leaver_slot])
                    {
                        g_iArenaQueue[arena_index][after_leaver_slot - 1] = g_iArenaQueue[arena_index][after_leaver_slot];
                        g_iPlayerSlot[g_iArenaQueue[arena_index][after_leaver_slot]] -= 1;
                        after_leaver_slot++;
                    }
                    g_iArenaQueue[arena_index][after_leaver_slot - 1] = 0;
                }
            }
        }
        function OnGameEvent_player_death(params)
        {
            local hVictim = GetPlayerFromUserID(params.userid);
            local iVictim = hVictim.entindex();
            local arena_index = g_iPlayerArena[iVictim];
            local victim_slot = g_iPlayerSlot[iVictim];


            local killer_slot = (victim_slot == SLOT_ONE || victim_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
            local killer = g_iArenaQueue[arena_index][killer_slot];
            local killer_teammate;
            local victim_teammate;

            //gets the killer and victims team slot (red 1, blu 2)
            local killer_team_slot = (killer_slot > 2) ? (killer_slot - 2) : killer_slot;
            local victim_team_slot = (victim_slot > 2) ? (victim_slot - 2) : victim_slot;

            // don't detect dead ringer deaths
            local victim_deathflags = params.death_flags;
            if (victim_deathflags & 32)
            {
                return Plugin_Continue;
            }

            if (g_bFourPersonArena[arena_index])
            {
                victim_teammate = getTeammate(victim_slot, arena_index);
                killer_teammate = getTeammate(killer_slot, arena_index);
            }

            // RemoveClientParticle(victim);

            if (!arena_index)
                hVictim.ForceChangeTeam(TEAM_SPEC, true);

            local hAttacker = GetPlayerFromUserID(params.attacker);
            local iAttacker = hAttacker.entindex();

            if (g_iArenaStatus[arena_index] < AS_FIGHT && hAttacker && hAttacker.IsAlive())
            {
                hAttacker.Regenerate(true);
                local raised_hp = g_iPlayerMaxHP[iAttacker] * g_fArenaHPRatio[arena_index];
                g_iPlayerHP[iAttacker] = raised_hp;
                hAttacker.SetHealth(raised_hp);
            }

            if (g_iArenaStatus[arena_index] < AS_FIGHT || g_iArenaStatus[arena_index] > AS_FIGHT)
            {
                // CreateTimer(0.1, Timer_ResetPlayer, GetClientUserId(victim));
                EntFireByHandle(hVictim, "RunScriptCode", "ResetPlayer("+iVictim+")", 0.1, null, null)
                return
            }

            if ((g_bFourPersonArena[arena_index] && !hKiller.IsAlive()) || (g_bFourPersonArena[arena_index] && !hKillerTeammate.IsAlive() && !hKiller.IsAlive()))
            {
                if (g_bArenaAmmomod[arena_index] || g_bArenaMidair[arena_index])
                    return
            }

            if (!g_bArenaBBall[arena_index] && !g_bArenaKoth[arena_index] && (!g_bFourPersonArena[arena_index] || (g_bFourPersonArena[arena_index] && !hVictimTeammate.IsAlive()))) // Kills shouldn't give points in bball. Or if only 1 player in a two person arena dies
                g_iArenaScore[arena_index][killer_team_slot] += 1;

            if (!g_bArenaEndif[arena_index]) // Endif does not need to display health, since it is one-shot kills.
            {
                //We must get the player that shot you last in 4 player arenas
                //The valid client check shouldn't be necessary but I'm getting invalid clients here for some reason
                //This may be caused by players killing themselves in 1v1 arenas without being attacked, or dieing after
                //A player disconnects but before the arena status transitions out of fight mode?
                //TODO: check properly
                if (g_bFourPersonArena[arena_index] && hAttacker && hAttacker.IsAlive())
                {
                    if ((g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index] || g_bArenaKoth[arena_index]) && (iVictim != iAttacker))
                        // MC_PrintToChat(iVictim, "%t", "HPLeft", hAttacker.GetHealth());
                        ClientPrint(hVictim, 3, format("HPLeft: %d", hAttacker.GetHealth()));
                    else if (iVictim != iAttacker)
                        // MC_PrintToChat(iVictim, "%t", "HPLeft", g_iPlayerHP[iAttacker]);
                        ClientPrint(hVictim, 3, format("HPLeft: %d", g_iPlayerHP[iAttacker]));
                }
                //in 1v1 arenas we can assume the person who killed you is the other person in the arena
                else if (hKiller && hKiller.IsAlive())
                {
                    if (g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index] || g_bArenaKoth[arena_index])
                        // MC_PrintToChat(iVictim, "%t", "HPLeft", GetClientHealth(killer));
                        ClientPrint(hVictim, 3, format("HPLeft: %d", hKiller.GetHealth()));
                    else
                        // MC_PrintToChat(iVictim, "%t", "HPLeft", g_iPlayerHP[killer]);
                        ClientPrint(hVictim, 3, format("HPLeft: %d", g_iPlayerHP[killer]));
                }
            }

            //Currently set up so that if its a 2v2 duel the round will reset after both players on one team die and a point will be added for that round to the other team
            //Another possibility is to make it like dm where its instant respawn for every player, killer gets hp, and a point is awarded for every kill


            local fraglimit = g_iArenaFraglimit[arena_index];


            if ((!g_bFourPersonArena[arena_index] && (g_bArenaAmmomod[arena_index] || g_bArenaMidair[arena_index])) ||
                (g_bFourPersonArena[arena_index] && !IsPlayerAlive(victim_teammate) && !g_bArenaBBall[arena_index] && !g_bArenaKoth[arena_index]))
            g_iArenaStatus[arena_index] = AS_AFTERFIGHT;

            if (g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED && fraglimit > 0 && g_iArenaScore[arena_index][killer_team_slot] >= fraglimit)
            {
                g_iArenaStatus[arena_index] = AS_REPORTED;
                local killer_name = Convars.GetClientConvarValue("name",  killer);
                local victim_name = Convars.GetClientConvarValue("name",  victim);
                // GetClientName(killer, killer_name, sizeof(killer_name));
                // GetClientName(victim, victim_name, sizeof(victim_name));


                if (g_bFourPersonArena[arena_index])
                {
                    local killer_teammate_name = Convars.GetClientConvarValue("name",  killer_teammate);
                    local victim_teammate_name = Convars.GetClientConvarValue("name",  victim_teammate);

                    // GetClientName(killer_teammate, killer_teammate_name, sizeof(killer_teammate_name));
                    // GetClientName(victim_teammate, victim_teammate_name, sizeof(victim_teammate_name));

                    // Format(killer_name, sizeof(killer_name), "%s and %s", killer_name, killer_teammate_name);
                    // Format(victim_name, sizeof(victim_name), "%s and %s", victim_name, victim_teammate_name);
                }

                // ClientPrintAll(3, "%t", "XdefeatsY", killer_name, g_iArenaScore[arena_index][killer_team_slot], victim_name, g_iArenaScore[arena_index][victim_team_slot], fraglimit, g_sArenaName[arena_index]);

                ClientPrint(3, null, format("%s defeats %s", killer_name, victim_name));

                if (!g_bNoStats && !g_bFourPersonArena[arena_index])
                    CalcELO(killer, victim);

                else if (!g_bNoStats)
                    CalcELO2(killer, killer_teammate, victim, victim_teammate);

                if (!g_bFourPersonArena[arena_index])
                {
                    if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
                    {
                        RemoveFromQueue(victim, false, true);
                        AddInQueue(victim, arena_index, false);
                    } else {
                        EntFire("worldspawn", "RunScriptCode", "StartDuel("+arena_index+");", 0.1, null, null);
                    }
                }
                else
                {
                    if (g_iArenaQueue[arena_index][SLOT_FOUR + 1] && g_iArenaQueue[arena_index][SLOT_FOUR + 2])
                    {
                        RemoveFromQueue(victim_teammate, false, true);
                        RemoveFromQueue(victim, false, true);
                        AddInQueue(victim_teammate, arena_index, false);
                        AddInQueue(victim, arena_index, false);
                    }
                    else if (g_iArenaQueue[arena_index][SLOT_FOUR + 1])
                    {
                        RemoveFromQueue(victim, false, true);
                        AddInQueue(victim, arena_index, false);
                    }
                    else {
                        EntFire("worldspawn", "RunScriptCode", "StartDuel("+arena_index+");", 0.1, null, null);
                    }
                }
            }
            else if (g_bArenaAmmomod[arena_index] || g_bArenaMidair[arena_index])
            {
                if (!g_bFourPersonArena[arena_index])
                    EntFire("worldspawn", "RunScriptCode", "NewRound("+arena_index+");", 0.1, null, null);

                else if (g_bFourPersonArena[arena_index] && victim_teammate && !victim_teammate.IsAlive())
                    EntFire("worldspawn", "RunScriptCode", "NewRound("+arena_index+");", 0.1, null, null);

            }
            else
            {
                if (g_bArenaBBall[arena_index])
                {
                    if (g_bPlayerHasIntel[iVictim])
                    {
                        g_bPlayerHasIntel[iVictim] = false;
                        local pos = hVictim.GetAbsOrigin();
                        local dist = DistanceAboveGround(iVictim);
                        if (dist > -1)
                            pos[2] = pos[2] - dist + 5;
                        else
                            pos[2] = g_fArenaSpawnOrigin[arena_index][g_iArenaSpawns[arena_index] - 3][2];

                        if (g_iBBallIntel[arena_index] == -1)
                            g_iBBallIntel[arena_index] = CreateByClassname("item_ammopack_small");
                        else
                            LogError("[%s] Player died with intel, but intel [%i] already exists.", g_sArenaName[arena_index], g_iBBallIntel[arena_index]);


                        //This should fix the ammopack not being turned into a briefcase
                        g_iBBallIntel[arena_index].KeyValueFromString("powerup_model", MODEL_BRIEFCASE);
                        g_iBBallIntel[arena_index].Teleport(pos, NULL_VECTOR, NULL_VECTOR);
                        g_iBBallIntel[arena_index].DispatchSpawn();
                        g_iBBallIntel[arena_index].SetTeam(1);
                        g_iBBallIntel[arena_index].SetModelScale(1.15);
                        //Doesn't work anymore
                        //SetEntityModel(g_iBBallIntel[arena_index], MODEL_BRIEFCASE);
                        AddOutput(g_iBBallIntel[arena_index], "OnPlayerTouch", "RunScriptCode", "OnTouchIntel(self);", 0.0, -1, null);
                        g_iBBallIntel[arena_index].AcceptInput("Enable", "", null, null);

                        hVictim.EmitSound("vo/intel_teamdropped.wav");
                        if (hAttacker && hAttacker.IsValid())
                            hAttacker.EmitSound("vo/intel_enemydropped.wav");

                    }
                } else {
                    if (!g_bFourPersonArena[arena_index] && !g_bArenaKoth[arena_index])
                    {
                        ResetKiller(killer, arena_index);
                    }
                    if (g_bFourPersonArena[arena_index] && (GetClientTeam(victim_teammate) == TEAM_SPEC || !IsPlayerAlive(victim_teammate)))
                    {
                        //Reset the teams
                        ResetArena(arena_index);
                        if (killer_team_slot == SLOT_ONE)
                        {
                            hVictim.ChangeTeam(TEAM_BLU);
                            hVictimTeammate.ChangeTeam(TEAM_BLU);

                            hKillerTeammate.ChangeTeam(TEAM_RED);
                        }
                        else
                        {
                            hVictim.ChangeTeam(TEAM_RED);
                            hVictimTeammate.ChangeTeam(TEAM_RED);

                            hKillerTeammate.ChangeTeam(TEAM_BLU);
                        }

                        //Should there be a 3 second count down in between rounds in 2v2 or just spawn and go?
                        //Timer_NewRound would create a 3 second count down where as just reseting all the players would make it just go
                        /*
                        if (killer)
                            ResetPlayer(killer);
                        if (victim_teammate)
                            ResetPlayer(victim_teammate);
                        if (victim)
                            ResetPlayer(victim);
                        if (killer_teammate)
                            ResetPlayer(killer_teammate);

                        g_iArenaStatus[arena_index] = AS_FIGHT;
                        */
                        EntFire("worldspawn", "RunScriptCode", "NewRound("+arena_index+");", 0.1, null, null);
                    }


                }


                //TODO: Check to see if its koth and apply a spawn penalty if needed depending on who's capping
                if (g_bArenaBBall[arena_index] || g_bArenaKoth[arena_index])
                {
                    EntFire("worldspawn", "RunScriptCode", "ResetPlayer("+victim+");", g_fArenaRespawnTime[arena_index], null, null);
                }
                else if (g_bFourPersonArena[arena_index] && victim_teammate && IsPlayerAlive(victim_teammate))
                {
                    //Set the player as waiting
                    g_iPlayerWaiting[victim] = true;
                    //change the player to spec to keep him from respawning
                    // CreateTimer(5.0, Timer_ChangePlayerSpec, victim);
                    EntFireByHandle(hVictim, "RunScriptCode", "ChangePlayerSpec(self);", 5, null, null);
                    //instead of respawning him
                    //CreateTimer(g_fArenaRespawnTime[arena_index],Timer_ResetPlayer,GetClientUserId(victim));
                }
                else
                    EntFireByHandle(hVictim, "RunScriptCode", "ResetPlayer(self);", -1, null, null);

            }

            ShowPlayerHud(victim);
            ShowPlayerHud(killer);

            if (g_bFourPersonArena[arena_index])
            {
                ShowPlayerHud(victim_teammate);
                ShowPlayerHud(killer_teammate);
            }

            // ShowSpecHudToArena(arena_index);
        }

        function OnGameEvent_player_team(params){
            local hClient = GetPlayerFromUserID(params.userid);
            local iClient = hClient.entindex();

            local team = params.team;

            if (team == TEAM_SPEC)
            {
                // HideHud(client);
                // CreateTimer(1.0, Timer_ChangeSpecTarget, GetClientUserId(client));
                EntFireByHandle(hClient, "RunScriptCode", "ChangeSpecTarget(self);", 1, null, null);
                local arena_index = g_iPlayerArena[iClient];

                if (arena_index && ((!g_bFourPersonArena[arena_index] && g_iPlayerSlot[iClient] <= SLOT_TWO) || (g_bFourPersonArena[arena_index] && g_iPlayerSlot[iClient] <= SLOT_FOUR && !isPlayerWaiting(iClient))))
                {
                    // MC_PrintToChat(client, "%t", "SpecRemove");
                    ClientPrint(hClient, HUD_PRINTTALK, "SpecRemove");
                    RemoveFromQueue(hClient, true);
                }
            } else if (hClient.IsValid()) {  // this code fixing spawn exploit
                local arena_index = g_iPlayerArena[iClient];

                if (arena_index == 0)
                {
                    // TF2_SetPlayerClass(client, view_as<TFClassType>(0));
                    hClient.SetPlayerClass(TF_CLASS_SCOUT);
                    SetPropInt(hClient, "m_Shared.m_iDesiredPlayerClass", TF_CLASS_SCOUT);

                }
            }

            // event.SetInt("silent", true);
            // return Plugin_Changed;
        }

        function OnGameEvent_round_start(params){
            gcvar_WfP <- 1; //cancel waiting for players

            //Be totally certain that the models are chached so they can be hooked
            PrecacheModel(MODEL_BRIEFCASE);
            PrecacheModel(MODEL_AMMOPACK);

            for (local i = 0; i <= g_iArenaCount; i++)
            {
                if (g_bArenaBBall[i])
                {
                    local hoop_2_loc = array(3, 0.0);
                    hoop_2_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][0];
                    hoop_2_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][1];
                    hoop_2_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][2];

                    hoop_2_loc = Vector(hoop_2_loc[0], hoop_2_loc[1], hoop_2_loc[2]);

                    local hoop_1_loc = array(3, 0.0);
                    hoop_1_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][0];
                    hoop_1_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][1];
                    hoop_1_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i] - 1][2];

                    hoop_1_loc = Vector(hoop_1_loc[0], hoop_1_loc[1], hoop_1_loc[2]);

                    if (g_iBBallHoop[i][SLOT_ONE] && g_iBBallHoop[i][SLOT_ONE].IsValid() && g_iBBallHoop[i][SLOT_ONE] > 0)
                    {
                        g_iBBallHoop[i][SLOT_ONE].Kill();
                        g_iBBallHoop[i][SLOT_ONE] = -1;
                    } else if (g_iBBallHoop[i][SLOT_ONE] != -1) {  // g_iBBallHoop[i][SLOT_ONE] equaling -1 is not a bad thing, so don't print an error for it.
                        //LogError("[%s] Event_RoundStart fired, but could not remove old hoop [%d]!.", g_sArenaName[i], g_iBBallHoop[i][SLOT_ONE]);
                        //LogError("[%s] Resetting SLOT_ONE hoop array index %i.", g_sArenaName[i], i);
                        g_iBBallHoop[i][SLOT_ONE] = -1;
                    }

                    if (g_iBBallHoop[i][SLOT_TWO] && g_iBBallHoop[i][SLOT_TWO].IsValid() && g_iBBallHoop[i][SLOT_TWO] > 0)
                    {
                        g_iBBallHoop[i][SLOT_TWO].Kill();
                        g_iBBallHoop[i][SLOT_TWO] = -1;
                    } else if (g_iBBallHoop[i][SLOT_TWO] != -1) {  // g_iBBallHoop[i][SLOT_TWO] equaling -1 is not a bad thing, so don't print an error for it.
                        //LogError("[%s] Event_RoundStart fired, but could not remove old hoop [%d]!.", g_sArenaName[i], g_iBBallHoop[i][SLOT_TWO]);
                        //LogError("[%s] Resetting SLOT_TWO hoop array index %i.", g_sArenaName[i], i);
                        g_iBBallHoop[i][SLOT_TWO] = -1;
                    }

                    if (g_iBBallHoop[i][SLOT_ONE] == -1)
                    {
                        g_iBBallHoop[i][SLOT_ONE] = CreateByClassname("item_ammopack_small");
                        g_iBBallHoop[i][SLOT_ONE].SetOrigin(hoop_1_loc);
                        g_iBBallHoop[i][SLOT_ONE].DispatchSpawn();
                        g_iBBallHoop[i][SLOT_ONE].SetTeam(1);

                        AddOutput(g_iBBallHoop[i][SLOT_ONE], "OnPlayerTouch", "RunScriptCode", "OnTouchHoop(self);", 0.0, -1, null);
                    }

                    if (g_iBBallHoop[i][SLOT_TWO] == -1)
                    {
                        g_iBBallHoop[i][SLOT_TWO] = CreateByClassname("item_ammopack_small");
                        g_iBBallHoop[i][SLOT_TWO].SetOrigin(hoop_2_loc);
                        g_iBBallHoop[i][SLOT_TWO].DispatchSpawn();
                        g_iBBallHoop[i][SLOT_TWO].SetTeam(1);

                        AddOutput(g_iBBallHoop[i][SLOT_TWO], "OnPlayerTouch", "RunScriptCode", "OnTouchHoop(self);", 0.0, -1, null);
                    }

                    if (g_bVisibleHoops[i] == false)
                    {
                        // Could have used SetRenderMode here, but it had the unfortunate side-effect of also making the intel invisible.
                        // Luckily, inputting "Disable" to most entities makes them invisible, so it was a valid workaround.
                        EntFireByHandle(g_iBBallHoop[i][SLOT_ONE], "Disable", "", 0.0, null, null);
                        EntFireByHandle(g_iBBallHoop[i][SLOT_TWO], "Disable", "", 0.0, null, null);
                    }
                }

                if (g_bArenaKoth[i])
                {
                    local point_loc = array(3, 0.0);
                    point_loc[0] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][0];
                    point_loc[1] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][1];
                    point_loc[2] = g_fArenaSpawnOrigin[i][g_iArenaSpawns[i]][2];

                    point_loc = Vector(point_loc[0], point_loc[1], point_loc[2]);

                    if (g_iCapturePoint[i] && g_iCapturePoint[i].IsValid() && g_iCapturePoint[i] > 0)
                    {
                        g_iCapturePoint[i].Kill();
                        g_iCapturePoint[i] = -1;
                    }
                    // g_iCapturePoint[i] equaling -1 is not a bad thing, so don't print an error for it.
                    else if (g_iCapturePoint[i] != -1)
                    {
                        g_iCapturePoint[i] = -1;
                    }

                    if (g_iCapturePoint[i] == -1)
                    {
                        g_iCapturePoint[i] = CreateByClassname("item_ammopack_small");
                        g_iCapturePoint[i].SetOrigin(point_loc);
                        g_iCapturePoint[i].KeyValueFromString("powerup_model", MODEL_BRIEFCASE);
                        g_iCapturePoint[i].DispatchSpawn();
                        g_iCapturePoint[i].SetTeam(1);
                        g_iCapturePoint[i].SetModel(MODEL_POINT);

                        AddOutput(g_iCapturePoint[i], "OnPlayerTouch", "RunScriptCode", "OnTouchPoint(self);", 0.0, -1, null);
                    }

                    // Could have used SetRenderMode here, but it had the unfortunate side-effect of also making the intel invisible.
                    // Luckily, inputting "Disable" to most entities makes them invisible, so it was a valid workaround.
                    // AcceptEntityInput(g_iCapturePoint[i], "Disable");
                    g_iCapturePoint[i].AcceptInput("Disable", "", null, null);

                }
            }
        }
    }
    function OnGameFrame()
    {
        local arena_index;

        for (local client = 1; client <= MAXPLAYERS; client++)
        {
            local player = PlayerInstanceFromIndex(client);
            if (player && player.IsAlive())
            {
                arena_index = g_iPlayerArena[client];
                if (!g_bArenaBBall[arena_index] && !g_bArenaMGE[arena_index] && !g_bArenaKoth[arena_index])
                {
                    /*  This is a hack that prevents people from getting one-shot by things
                    like the direct hit in the Ammomod arenas. */
                    local replacement_hp = (g_iPlayerMaxHP[client] + 512);
                    player.SetHealth(replacement_hp);
                }
            }
        }
        for (local arena_index2 = 1; arena_index2 <= g_iArenaCount; ++arena_index2)
        {
            if (g_bArenaKoth[arena_index2] && g_iArenaStatus[arena_index2] == AS_FIGHT)
            {
                g_fTotalTime[arena_index2] += 7;
                if (g_iPointState[arena_index2] == NEUTRAL || g_iPointState[arena_index2] == TEAM_BLU)
                {
                    //If RED Team is capping and BLU Team isn't and BLU Team has the point increase the cap time
                    if (!(g_bPlayerTouchPoint[arena_index2][SLOT_TWO] || g_bPlayerTouchPoint[arena_index2][SLOT_FOUR]) && (g_iCappingTeam[arena_index2] == TEAM_RED || g_iCappingTeam[arena_index2] == NEUTRAL))
                    {
                        local cap = 0;

                        if (g_bPlayerTouchPoint[arena_index2][SLOT_ONE])
                        {
                            cap++;
                            //If the player is a Scout add one to the cap speed
                            if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_ONE]] == TF_CLASS_SCOUT)
                                cap++;

                            local ent = MGE_Util.GetEntityIndexInSlot(g_iArenaQueue[arena_index2][SLOT_ONE], 2);
                            local iItemDefinitionIndex = GetPropInt(EntIndexToHScript(ent), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");

                            //If the player has the Pain Train equipped add one to the cap speed
                            if (iItemDefinitionIndex == 154)
                                cap++;
                        }
                        if (g_bPlayerTouchPoint[arena_index2][SLOT_THREE])
                        {
                            cap++;
                            //If the player is a Scout add one to the cap speed
                            if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_THREE]] == TF_CLASS_SCOUT)
                                cap++;

                            local ent = MGE_Util.GetEntityIndexInSlot(g_iArenaQueue[arena_index2][SLOT_THREE], 2);
                            local iItemDefinitionIndex = GetPropInt(EntIndexToHScript(ent), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");

                            //If the player has the Pain Train equipped add one to the cap speed
                            if (iItemDefinitionIndex == 154)
                                cap++;
                        }
                        //Add cap time if needed
                        if (cap)
                        {
                            //True harmonic cap time, yes!
                            for (local i = 0; i < cap; i++)
                            {
                                g_fCappedTime[arena_index2] += 7.0 / cap.tofloat();
                            }
                            g_iCappingTeam[arena_index2] = TEAM_RED;
                            continue;
                        }
                    }


                }

                if (g_iPointState[arena_index2] == NEUTRAL || g_iPointState[arena_index2] == TEAM_RED)
                {
                    //If BLU Team is capping and Team RED isn't and Team RED has the point increase the cap time
                    if (!(g_bPlayerTouchPoint[arena_index2][SLOT_ONE] || g_bPlayerTouchPoint[arena_index2][SLOT_THREE]) && (g_iCappingTeam[arena_index2] == TEAM_BLU || g_iCappingTeam[arena_index2] == NEUTRAL))
                    {
                        local cap = 0;

                        if (g_bPlayerTouchPoint[arena_index2][SLOT_TWO])
                        {
                            cap++;
                            //If the player is a Scout add one to the cap speed
                            if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_TWO]] == TF_CLASS_SCOUT)
                                cap++;

                            local ent = MGE_Util.GetEntityIndexInSlot(g_iArenaQueue[arena_index2][SLOT_TWO], 2);
                            local iItemDefinitionIndex =GetPropInt(EntIndexToHScript(ent), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");

                            //If the player has the Pain Train equipped add one to the cap speed
                            if (iItemDefinitionIndex == 154)
                                cap++;
                        }
                        if (g_bPlayerTouchPoint[arena_index2][SLOT_FOUR])
                        {
                            cap++;
                            //If the player is a Scout add one to the cap speed
                            if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_FOUR]] == TF_CLASS_SCOUT)
                                cap++;

                            local ent = MGE_Util.GetEntityIndexInSlot(g_iArenaQueue[arena_index2][SLOT_FOUR], 2);
                            local iItemDefinitionIndex =GetPropInt(EntIndexToHScript(ent), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");

                            //If the player has the Pain Train equipped add one to the cap speed
                            if (iItemDefinitionIndex == 154)
                                cap++;
                        }
                        //Add cap time if needed
                        if (cap)
                        {
                            //True harmonic cap time, yes!
                            for (; cap > 0; cap--)
                            {
                                // g_fCappedTime[arena_index2] += 7.0, cap.tofloat();
                                g_fCappedTime[arena_index2] += 7.0 / cap.tofloat();
                            }
                            g_iCappingTeam[arena_index2] = TEAM_BLU;
                            continue;
                        }
                    }


                }

                //If BLU Team is blocking and RED Team isn't capping and BLU Team has the point increase the cap diminish rate
                if ((g_bPlayerTouchPoint[arena_index2][SLOT_TWO] || g_bPlayerTouchPoint[arena_index2][SLOT_FOUR]) &&
                    (g_iPointState[arena_index2] == NEUTRAL) && g_iCappingTeam[arena_index2] == TEAM_RED &&
                    !(g_bPlayerTouchPoint[arena_index2][SLOT_ONE] || g_bPlayerTouchPoint[arena_index2][SLOT_THREE]))
                {
                    local cap = 0;

                    if (g_bPlayerTouchPoint[arena_index2][SLOT_TWO])
                    {
                        cap++;
                        //If the player is a Scout add one to the cap speed
                        if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_TWO]] == TF_CLASS_SCOUT)
                            cap++;

                        local ent = MGE_Util.GetEntityIndexInSlot(g_iArenaQueue[arena_index2][SLOT_TWO], 2);
                        local iItemDefinitionIndex =GetPropInt(EntIndexToHScript(ent), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");

                        //If the player has the Pain Train equipped add one to the cap speed
                        if (iItemDefinitionIndex == 154)
                            cap++;
                    }
                    if (g_bPlayerTouchPoint[arena_index2][SLOT_FOUR])
                    {
                        cap++;
                        //If the player is a Scout add one to the cap speed
                        if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_FOUR]] == TF_CLASS_SCOUT)
                            cap++;

                        local ent = MGE_Util.GetEntityIndexInSlot(g_iArenaQueue[arena_index2][SLOT_FOUR], 2);
                        local iItemDefinitionIndex =GetPropInt(EntIndexToHScript(ent), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");

                        //If the player has the Pain Train equipped add one to the cap speed
                        if (iItemDefinitionIndex == 154)
                            cap++;
                    }
                    //Add cap time if needed
                    if (cap)
                    {
                        //True harmonic cap time, yes!
                        for (; cap > 0; cap--)
                        {
                            g_fCappedTime[arena_index2] -= 7.0, cap.tofloat();
                        }
                        g_iCappingTeam[arena_index2] = TEAM_BLU;
                        continue;
                    }
                }

                //If RED Team is blocking and BLU Team isn't capping and RED Team has the point increase the cap diminish rate
                if ((g_bPlayerTouchPoint[arena_index2][SLOT_ONE] || g_bPlayerTouchPoint[arena_index2][SLOT_THREE]) &&
                    (g_iPointState[arena_index2] == NEUTRAL) && g_iCappingTeam[arena_index2] == TEAM_BLU &&
                    !(g_bPlayerTouchPoint[arena_index2][SLOT_TWO] || g_bPlayerTouchPoint[arena_index2][SLOT_FOUR]))
                {
                    local cap = 0;

                    if (g_bPlayerTouchPoint[arena_index2][SLOT_ONE])
                    {
                        cap++;
                        //If the player is a Scout add one to the cap speed
                        if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_ONE]] == TF_CLASS_SCOUT)
                            cap++;

                        local ent = MGE_Util.GetEntityIndexInSlot(g_iArenaQueue[arena_index2][SLOT_ONE], 2);
                        local iItemDefinitionIndex =GetPropInt(EntIndexToHScript(ent), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");

                        //If the player has the Pain Train equipped add one to the cap speed
                        if (iItemDefinitionIndex == 154)
                            cap++;
                    }
                    if (g_bPlayerTouchPoint[arena_index2][SLOT_THREE])
                    {
                        cap++;
                        //If the player is a Scout add one to the cap speed
                        if (g_tfctPlayerClass[g_iArenaQueue[arena_index2][SLOT_THREE]] == TF_CLASS_SCOUT)
                            cap++;

                        local ent = MGE_Util.GetEntityIndexInSlot(g_iArenaQueue[arena_index2][SLOT_THREE], 2);
                        local iItemDefinitionIndex =GetPropInt(EntIndexToHScript(ent), "m_AttributeManager.m_Item.m_iItemDefinitionIndex");

                        //If the player has the Pain Train equipped add one to the cap speed
                        if (iItemDefinitionIndex == 154)
                            cap++;
                    }
                    //Add cap time if needed
                    if (cap)
                    {
                        //True harmonic cap time, yes!
                        for (; cap > 0; cap--)
                        {
                            g_fCappedTime[arena_index2] -= 7.0, cap.tofloat();
                        }
                        g_iCappingTeam[arena_index2] = TEAM_RED;
                        continue;
                    }
                }

                //If both teams are touching the point, do nothing
                if ((g_bPlayerTouchPoint[arena_index2][SLOT_TWO] || g_bPlayerTouchPoint[arena_index2][SLOT_FOUR]) && (g_bPlayerTouchPoint[arena_index2][SLOT_ONE] || g_bPlayerTouchPoint[arena_index2][SLOT_THREE]))
                    continue;

                // If in overtime, revert cap at 6x speed, if not, revert cap slowly
                if (g_bOvertimePlayed[arena_index][TEAM_RED] || g_bOvertimePlayed[arena_index][TEAM_BLU])
                    g_fCappedTime[arena_index2] -= 6.0;
                else
                    g_fCappedTime[arena_index2]--;
            }
        }
        return -1
    }
}

mge_ent.GetScriptScope().OnGameFrame <- MGE_Events.OnGameFrame
AddThinkToEnt(mge_ent, "OnGameFrame")

__CollectGameEventCallbacks(MGE_Events.Events)
