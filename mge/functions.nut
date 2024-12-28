class MGE_Functions {

    function LoadSpawnPoints()
    {
        IncludeScript(MGE_SPAWN_FILE)
        local spawn = ""

        local config = SpawnConfigs[MAP_NAME]

        ::All_Arenas <- {}

        foreach(k, v in config) {
            All_Arenas[k] <- v
            printl(k + " : " + v)
        }
    }
}