class MGE_Events {

    chat_commands = {
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
    Events = {

        function OnGameEvent_player_say(params)
        {
            local chatCommands = MGE_Events.chat_commands
            local text = params.text.tolower()

            local splitText = split(text, " ")

            if (splitText[0][0] != 33) //ASCII for !
                return

            if (splitText[0] in chatCommands)
                chat_commands[splitText[0]](params)
        }
        function OnGameEvent_player_spawn(params)
        {
            local player = GetPlayerFromUserID(params.userid)

            EntFireByHandle(player, "RunScriptCode", "self.EmitSound(`items/spawn_item.wav`)", 0.1, null, null)
        }
    }
}

__CollectGameEventCallbacks(MGE_Events.Events)