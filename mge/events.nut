class MGE_Events {

    chat_commands = {
        "!add" : function(params) {

            local player = GetPlayerFromUserID(params.userid)

            local splitText = split(params.text, " ")

            local idx = INT_MAX

            try
                idx = splitText[1].tointeger() - 1
            catch(_)

            if (splitText.len() < 2 || idx > All_Arenas.len()) {

                ClientPrint(player, 3, "Valid areas:")

                local i = 1
                foreach (arena_name, _ in All_Arenas) {
                    ClientPrint(player, 3, format("\t%d: %s", i, arena_name))
                    i++
                }
                return
            }
            if (idx != INT_MAX)
            {
                AddToQueue(player, All_Arenas.Indexes[idx])
            }
            else
            {
                foreach (arena_name, _ in All_Arenas)
                {
                    if (startswith(arena_name, splitText[1]))
                    {
                        AddToQueue(player, arena_name)
                        break
                    }
                }
            }
        },
        "!remove" : function(params) {

            local player = GetPlayerFromUserID(params.userid)

            RemoveFromQueue(player, player.GetScriptScope().Arena.name)
        }
    }
    Events = {

        function OnGameEvent_player_say(params) {

            local chatCommands = MGE_Events.chat_commands
            local text = params.text.tolower()

            local splitText = split(text, " ")

            if (splitText[0][0] != 33) //ASCII for !
                return

            if (splitText[0] in chatCommands)
                chatCommands[splitText[0]](params)
        }

        function OnGameEvent_player_spawn(params) {

            local player = GetPlayerFromUserID(params.userid)
            local scope = player.GetScriptScope()

            if ("Arena" in scope)
            {
                local idx = scope.Arena.spawnidx
                player.SetAbsOrigin(scope.Arena.spawns[idx][0])
                player.SetAbsAngles(scope.Arena.spawns[idx][1])
                player.EmitSound("items/spawn_item.wav")
                idx++
                if (idx >= scope.Arena.spawns.len()) idx = 0
                scope.Arena.spawnidx = idx

                local arena = All_Arenas[scope.Arena.name]
                scope.ScoreThink <- function() {
                    MGE_ClientPrint(player, 4, "RED Score: "+arena.Score[0]+" BLU Score: "+arena.Score[1])
                }
                AddThinkToEnt(player, "ScoreThink")
            } else {
                MGE_ClientPrint(null, 3, "[MGE ERROR] "+player+" spawned outside of arena!")
            }
        }

        function OnGameEvent_player_death(params) {

            local player = GetPlayerFromUserID(params.userid)

            local scope = player.GetScriptScope()

            //we aren't in an arena
            if (!("Arena" in scope)) return

            local arena = All_Arenas[scope.Arena.name]

            local respawntime = "respawntime" in arena ? arena.respawntime.tointeger() : -1
            //koth/bball mode doesn't count deaths
            if ("koth" in arena || "bball" in arena) return

            player.GetTeam() == TF_TEAM_RED ? arena.Score[1]++ : arena.Score[0]++

            CalcArenaScore(player, scope.Arena.name)

            local attacker = GetPlayerFromUserID(params.attacker)

            if (attacker && attacker != player)
                MGE_ClientPrint(player, 3, format(MGE_Localization.HPLeft, attacker.GetHealth()))

            EntFireByHandle(player, "RunScriptCode", "self.ForceRespawn()", respawntime, null, null)
        }
    }
}

__CollectGameEventCallbacks(MGE_Events.Events)