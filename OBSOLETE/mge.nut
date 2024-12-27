
IncludeScript("mge_util.nut")
IncludeScript("mge_events.nut")

//these replace cvars
::MGE_Config <- {
    fragLimit = 3,
    allowedClasses = TF_CLASS_SCOUT | TF_CLASS_SOLDIER | TF_CLASS_DEMOMAN,
    blockFallDamage = 0,
    dbConfig = "mgemod",
    stats = 1,
    airshotHeight = 80,
    RocketForceX = 1.1,
    RocketForceY = 1.1,
    RocketForceZ = 2.15,
    bballParticle_red = "player_intel_trail_red",
    bballParticle_blue = "player_intel_trail_blue",
    midairHP = 5,
    noDisplayRating = 0,
    reconnectInterval = 5,
    spawnFile = "mge_configs/mgemod_spawns",
    autoCvar = true,
    WfP = null,
}
// this will get overwritten by the config file
// defined here to avoid errors
::SpawnConfigs <- {}

local config_file = FileToString("mge_config.cfg")

if (!config_file)
    printl("\nmge_config.cfg not found in tf/scriptdata folder, loading defaults...\n")
else {
    compilestring(config_file)()
    MGE_Config <- config_file
}

//CONST.MAXPLAYERS <- MaxClients().tointeger()
::MAXPLAYERS <- MaxClients().tointeger()
const MAXARENAS = 63
const MAXSPAWNS = 15
const HUDFADEOUTTIME = 120.0
//config file included above

const SLOT_ONE = 1
const SLOT_TWO = 2
const SLOT_THREE = 3
const SLOT_FOUR = 4


// teams
const TEAM_NONE = 0
const TEAM_SPEC = 1
const TEAM_RED = 2
const TEAM_BLU = 3

//arena status
const AS_IDLE = 0
const AS_PRECOUNTDOWN = 1
const AS_COUNTDOWN = 2
const AS_FIGHT = 3
const AS_AFTERFIGHT = 4
const AS_REPORTED = 5

// for neutral cap points
const NEUTRAL = 1

//sounds
const STOCK_SOUND_COUNT = 24
const DEFAULT_CDTIME = 3
const MODEL_POINT = "models/props_gameplay/cap_point_base.mdl"
const MODEL_BRIEFCASE = "models/flag/briefcase.mdl"
const MODEL_AMMOPACK = "models/items/ammopack_small.mdl"
const MODEL_LARGE_AMMOPACK = "models/items/ammopack_large.mdl"

// ====[ VARIABLES ]===================================================
// Handle, String, Float, Bool, NUM, TFCT
::g_bNoStats <- false
::g_bNoDisplayRating <- false

// HUD Handles
::hm_HP <- null
::hm_Score <- null
::hm_TeammateHP <- null
::hm_KothTimerBLU <- null
::hm_KothTimerRED <- null
::hm_KothCap <- null

//misc globals
::g_sMapName <- GetMapName()

::g_bBlockFallDamage <- MGE_Config.blockFallDamage
::g_bUseSQLite <- false
::g_bAutoCvar <- MGE_Config.autoCvar

::g_iDefaultFragLimit <- 0
::g_iAirshotHeight <- MGE_Config.airshotHeight

//database
::db <- null
::g_hDBReconnectTimer <- null
::g_sDBConfig <- MGE_Config.dbConfig
::g_iReconnectInterval <- MGE_Config.reconnectInterval

//cvars
::g_WfP <- MGE_Config.WfP
::g_fragLimit <- MGE_Config.fragLimit
::g_allowedClasses <- MGE_Config.allowedClasses
::g_blockFallDamage <- MGE_Config.blockFallDamage
::g_dbConfig <- MGE_Config.dbConfig
::g_midairHP <- MGE_Config.midairHP
::g_airshotHeight <- MGE_Config.airshotHeight
::g_RocketForceX <- MGE_Config.RocketForceX
::g_RocketForceY <- MGE_Config.RocketForceY
::g_RocketForceZ <- MGE_Config.RocketForceZ
::g_autoCvar <- MGE_Config.autoCvar
::g_bballParticle_red <- MGE_Config.bballParticle_red
::g_bballParticle_blue <- MGE_Config.bballParticle_blue
::g_noDisplayRating <- MGE_Config.noDisplayRating
::g_stats <- MGE_Config.stats
::g_reconnectInterval <- MGE_Config.reconnectInterval
::g_spawnFile <- MGE_Config.spawnFile

// Classes
::g_tfctClassAllowed <- array(10, false)

foreach(i, _class in g_tfctClassAllowed)
    if (i & g_allowedClasses)
        g_tfctClassAllowed[i] = true

// Arena Vars
::g_tKothTimer <- array(MAXARENAS + 1)

::g_sArenaName <- array(MAXARENAS + 1, "")
::g_sArenaOriginalName <- array(MAXARENAS + 1, "")
::g_sArenaCapTrigger <- array(MAXARENAS + 1, "")
::g_sArenaCap <- array(MAXARENAS + 1, "")

::g_fArenaSpawnOrigin <- array(MAXARENAS + 1)
for (local i = 0; i <= MAXARENAS; i++) {
    g_fArenaSpawnOrigin[i] = array(MAXSPAWNS + 1)
    for (local j = 0; j <= MAXSPAWNS; j++) {
        g_fArenaSpawnOrigin[i][j] = [0.0, 0.0, 0.0]
    }
}

::g_fArenaSpawnAngles <- array(MAXARENAS + 1)
for (local i = 0; i <= MAXARENAS; i++) {
    g_fArenaSpawnAngles[i] = array(MAXSPAWNS + 1)
    for (local j = 0; j <= MAXSPAWNS; j++) {
        g_fArenaSpawnAngles[i][j] = [0.0, 0.0, 0.0]
    }
}

::g_fArenaHPRatio <- array(MAXARENAS + 1, 0.0)
::g_fArenaMinSpawnDist <- array(MAXARENAS + 1, 0.0)
::g_fArenaRespawnTime <- array(MAXARENAS + 1, 0.0)
::g_fKothCappedPercent <- array(MAXARENAS + 1, 0.0)
::g_fTotalTime <- array(MAXARENAS + 1, 0.0)
::g_fCappedTime <- array(MAXARENAS + 1, 0.0)

::g_bArenaAmmomod <- array(MAXARENAS + 1, false)
::g_bArenaMidair <- array(MAXARENAS + 1, false)
::g_bArenaMGE <- array(MAXARENAS + 1, false)
::g_bArenaEndif <- array(MAXARENAS + 1, false)
::g_bArenaBBall <- array(MAXARENAS + 1, false)
::g_bVisibleHoops <- array(MAXARENAS + 1, false)
::g_bArenaInfAmmo <- array(MAXARENAS + 1, false)
::g_bFourPersonArena <- array(MAXARENAS + 1, false)
::g_bArenaAllowChange <- array(MAXARENAS + 1, false)
::g_bArenaAllowKoth <- array(MAXARENAS + 1, false)
::g_bArenaKothTeamSpawn <- array(MAXARENAS + 1, false)
::g_bArenaShowHPToPlayers <- array(MAXARENAS + 1, false)
::g_bArenaUltiduo <- array(MAXARENAS + 1, false)
::g_bArenaKoth <- array(MAXARENAS + 1, false)
::g_bPlayerTouchPoint <- array(MAXARENAS + 1, false)
::g_bArenaTurris <- array(MAXARENAS + 1, false)
::g_bOvertimePlayed <- array(MAXARENAS + 1, false)
::g_bTimerRunning <- array(MAXARENAS + 1, false)
::g_bArenaHasCap <- array(MAXARENAS + 1, false)
::g_bArenaHasCapTrigger <- array(MAXARENAS + 1, false)
::g_bArenaBoostVectors <- array(MAXARENAS + 1, false)

::g_iArenaCount <- 0
::g_iArenaAirshotHeight <- array(MAXARENAS + 1, 0)
::g_iCappingTeam <- array(MAXARENAS + 1, 0)
::g_iCapturePoint <- array(MAXARENAS + 1, 0)
::g_iDefaultCapTime <- array(MAXARENAS + 1, 0)
::g_iKothTimer <- array(MAXARENAS + 1, array(4, 0))
::g_iPointState <- array(MAXARENAS + 1, 0)
::g_iArenaScore <- array(MAXARENAS + 1, array(3, 0))
::g_iArenaQueue <- array(MAXARENAS + 1, array(MAXPLAYERS + 1))
::g_iArenaStatus <- array(MAXARENAS + 1, 0)
::g_iArenaCd <- array(MAXARENAS + 1, 0)
::g_iArenaFraglimit <- array(MAXARENAS + 1, 0)
::g_iArenaMgelimit <- array(MAXARENAS + 1, 0)
::g_iArenaCaplimit <- array(MAXARENAS + 1, 0)
::g_iArenaMinRating <- array(MAXARENAS + 1, 0)
::g_iArenaMaxRating <- array(MAXARENAS + 1, 0)
::g_iArenaCdTime <- array(MAXARENAS + 1, 0)
::g_iArenaSpawns <- array(MAXARENAS + 1, 0)
::g_iBBallHoop <- array(MAXARENAS + 1, array(3, 0))
::g_iBBallIntel <- array(MAXARENAS + 1, 0)
::g_iArenaEarlyLeave <- array(MAXARENAS + 1, 0)
::g_iELOMenuPage <- array(MAXARENAS + 1, 0)

//bool g_tfctArenaAllowedClasses[MAXARENAS + 1][TFClassType+1];
::g_tfctArenaAllowedClasses <- array(MAXARENAS + 1, array(10, false))

// Player vars
::g_sPlayerSteamID <- array(MAXPLAYERS + 1, array(MAXPLAYERS, ""))

::g_bPlayerTakenDirectHit <- array(MAXPLAYERS + 1, false)
::g_bPlayerRestoringAmmo <- array(MAXPLAYERS + 1, false)
::g_bPlayerHasIntel <- array(MAXPLAYERS + 1, false)
::g_bHitBlip <- array(MAXPLAYERS + 1, false)
::g_bShowHud <- array(MAXPLAYERS + 1, false)
::g_iPlayerWaiting <- array(MAXPLAYERS + 1, 0)
::g_bCanPlayerSwap <- array(MAXPLAYERS + 1, false)
::g_bCanPlayerGetIntel <- array(MAXPLAYERS + 1, false)

::g_iPlayerArena <- array(MAXPLAYERS + 1, 0)
::g_iPlayerSlot <- array(MAXPLAYERS + 1, 0)
::g_iPlayerHP <- array(MAXPLAYERS + 1, 0) //true HP of players
::g_iPlayerSpecTarget <- array(MAXPLAYERS + 1, 0)
::g_iPlayerMaxHP <- array(MAXPLAYERS + 1, 0)
::g_iClientParticle <- array(MAXPLAYERS + 1, 0)
::g_iPlayerClip <- array(MAXPLAYERS + 1, 3)
::g_iPlayerWins <- array(MAXPLAYERS + 1, 0)
::g_iPlayerLosses <- array(MAXPLAYERS + 1, 0)
::g_iPlayerRating <- array(MAXPLAYERS + 1, 0)
::g_iPlayerHandicap <- array(MAXPLAYERS + 1, 0)

::g_tfctPlayerClass <- array(MAXPLAYERS + 1, 0)

// Bot things
::g_bPlayerAskedForBot <- array(MAXPLAYERS + 1, false)

// Midair
::g_iMidairHP <- 0

// Debug log
::g_sLogFile <- ""

// Endif
::g_fRocketForceX <- 0
::g_fRocketForceY <- 0
::g_fRocketForceZ <- 0

// Bball
::g_sBBallParticleRed <- ""
::g_sBBallParticleBlue <- ""

local stockSounds = [
    "vo/intel_teamcaptured.wav",
    "vo/intel_teamdropped.wav",
    "vo/intel_teamstolen.wav",
    "vo/intel_enemycaptured.wav",
    "vo/intel_enemydropped.wav",
    "vo/intel_enemystolen.wav",
    "vo/announcer_ends_5sec.wav",
    "vo/announcer_ends_4sec.wav",
    "vo/announcer_ends_3sec.wav",
    "vo/announcer_ends_2sec.wav",
    "vo/announcer_ends_1sec.wav",
    "vo/announcer_ends_10sec.wav",
    "vo/announcer_control_point_warning.wav",
    "vo/announcer_control_point_warning2.wav",
    "vo/announcer_control_point_warning3.wav",
    "vo/announcer_overtime.wav",
    "vo/announcer_overtime2.wav",
    "vo/announcer_overtime3.wav",
    "vo/announcer_overtime4.wav",
    "vo/announcer_we_captured_control.wav",
    "vo/announcer_we_lost_control.wav",
    "items/spawn_item.wav",
    "vo/announcer_victory.wav",
    "vo/announcer_you_failed.wav"
]

foreach (sound in stockSounds)
    PrecacheSound(sound)

PrecacheModel(MODEL_POINT)
PrecacheModel(MODEL_BRIEFCASE)
PrecacheModel(MODEL_AMMOPACK)
PrecacheModel(MODEL_LARGE_AMMOPACK)

::LogMessage <- function(message, logfile = "mge.log") {
    local log_string = FileToString(logfile)
    if (!log_string) {
        StringToFile(logfile, message)
        return
    }
    log_string += message
    StringToFile(logfile, log_string)
}

::LoadSpawnPoints <- function() {

    IncludeScript(g_spawnFile)
    local spawn = ""

    local kvmap = SpawnConfigs[g_sMapName]
    local i = 0
    g_iArenaCount = 0

    for (local j = 0; j <= MAXARENAS; j++)
    {
        g_iArenaSpawns[j] = 0
    }

    foreach(k, v in kvmap) {

        g_iArenaCount++
        g_sArenaOriginalName[g_iArenaCount] = k
        local id = 0

        // if ("1" in v)
        // {
        //     local intstr = ""
        //     local intstr2 = ""

        //     g_iArenaSpawns[g_iArenaCount]++;

        //     intstr = g_iArenaSpawns[g_iArenaCount].tostring()
        //     intstr2 = (g_iArenaSpawns[g_iArenaCount] + 1).tostring()

        //     spawn = v[intstr]
        //     local spawnCo = split(spawn, " ")
        //     local count = spawnCo.len()
        //     if (count == 6)  {

        //         // for (local i = 0; i < 6; i++)
        //             // printl(g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i])

        //         for (local i = 0; i < 3; i++)
        //             g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i] = spawnCo[i].tofloat();

        //         for (local i = 3; i < 6; i++)
        //             g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i-3] = spawnCo[i].tofloat();

        //     } else if(count == 4) {

        //         for (local i = 0; i < 3; i++)
        //             g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i] = spawnCo[i].tofloat();

        //         g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][0] = 0.0;
        //         g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][1] = spawnCo[3].tofloat();
        //         g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][2] = 0.0;
        //     } else {
        //         throw format("Error in cfg file. Wrong number of parametrs (%d) on spawn <%i> in arena <%s>",count,g_iArenaSpawns[g_iArenaCount],g_sArenaOriginalName[g_iArenaCount]);
        //     }
        //     if (!(intstr2 in v)) break;
        //     LogMessage(format("Loaded %d spawns on arena %s.", g_iArenaSpawns[g_iArenaCount], g_sArenaOriginalName[g_iArenaCount]));
        // } else {
        //     LogError(format("Could not load spawns on arena %s.", g_sArenaOriginalName[g_iArenaCount]));
        // }

        for (local i = 1; i <= MAXSPAWNS; i++) {
            local str = i.tostring()
            if (!(str in v)) break
            g_iArenaSpawns[g_iArenaCount]++

            local spawn = v[str]
            local spawnCo = split(spawn, " ")
            local count = spawnCo.len()

            if (count == 6) {

                for (local i = 0; i < 3; i++)
                    g_fArenaSpawnOrigin[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i] = spawnCo[i].tofloat()

                for (local i = 3; i < 6; i++)
                    g_fArenaSpawnAngles[g_iArenaCount][g_iArenaSpawns[g_iArenaCount]][i-3] = spawnCo[i].tofloat()

            }
        }

        if ("cap" in v) {
            g_sArenaCap[g_iArenaCount] = v["cap"]
            g_bArenaHasCap[g_iArenaCount] = true

            LogMessage(format("Found cap point on arena %s.", g_sArenaOriginalName[g_iArenaCount]))
        } else {
            g_bArenaHasCap[g_iArenaCount] = false
        }

        if ("cap_trigger" in v) {
            g_sArenaCapTrigger[g_iArenaCount] = v["cap_trigger"]
            g_bArenaHasCapTrigger[g_iArenaCount] = true
        }

        //optional parametrs
        g_iArenaMgelimit[g_iArenaCount] = g_iDefaultFragLimit
        g_iArenaCaplimit[g_iArenaCount] = g_iDefaultFragLimit
        g_iArenaMinRating[g_iArenaCount] = -1
        g_iArenaMaxRating[g_iArenaCount] = -1
        g_bArenaMidair[g_iArenaCount] = false
        g_iArenaCdTime[g_iArenaCount] = DEFAULT_CDTIME
        g_bArenaMGE[g_iArenaCount] = false
        g_fArenaHPRatio[g_iArenaCount] = 1.5
        g_bArenaEndif[g_iArenaCount] = false
        g_iArenaAirshotHeight[g_iArenaCount] = 250
        g_bArenaBoostVectors[g_iArenaCount] = false
        g_bArenaBBall[g_iArenaCount] = false
        g_bVisibleHoops[g_iArenaCount] = false
        g_iArenaEarlyLeave[g_iArenaCount] = 0
        g_bArenaInfAmmo[g_iArenaCount] = true
        g_bArenaShowHPToPlayers[g_iArenaCount] = true
        g_fArenaMinSpawnDist[g_iArenaCount] = 100.0
        g_bFourPersonArena[g_iArenaCount] = false
        g_bArenaAllowChange[g_iArenaCount] = false
        g_bArenaAllowKoth[g_iArenaCount] = false
        g_bArenaKothTeamSpawn[g_iArenaCount] = false
        g_fArenaRespawnTime[g_iArenaCount] = 0.1
        g_bArenaAmmomod[g_iArenaCount] = false
        g_bArenaUltiduo[g_iArenaCount] = false
        g_bArenaKoth[g_iArenaCount] = false
        g_bArenaTurris[g_iArenaCount] = false
        g_iDefaultCapTime[g_iArenaCount] = 180

        //parsing allowed classes for current arena
        local sAllowedClasses = ""
        if ("classes" in v)
            sAllowedClasses = v["classes"]

        LogMessage(format("%s classes: <%s>", g_sArenaOriginalName[g_iArenaCount], sAllowedClasses))
        ParseAllowedClasses(sAllowedClasses,g_tfctArenaAllowedClasses[g_iArenaCount])
        g_iArenaFraglimit[g_iArenaCount] = g_iArenaMgelimit[g_iArenaCount]
        UpdateArenaName(g_iArenaCount)
    }

    PrintSpawnLocations()
}

::RemoveFromQueue <- function(client, calcstats = false, specfix = false)
{
    local iClient = client instanceof CBaseEntity ? client.entindex() : client
    local hClient = typeof client == "integer" ? EntIndexToHScript(client) : client
    local arena_index = g_iPlayerArena[iClient]

    if (arena_index == 0) return

    local player_slot = g_iPlayerSlot[iClient]
    g_iPlayerArena[iClient] = 0
    g_iPlayerSlot[iClient] = 0
    g_iArenaQueue[arena_index][player_slot] = 0
    g_iPlayerHandicap[iClient] = 0

    if (hClient.GetTeam() != TEAM_SPEC)
    {
        hClient.TakeDamage(hClient.GetHealth(), 0, null)
        hClient.ForceChangeTeam(TEAM_SPEC, true)

        // if (specfix)
            // CreateTimer(0.1, Timer_SpecFix, GetClientUserId(client));
    }

    local after_leaver_slot = player_slot + 1

    //I beleive I don't need to do this anymore BUT
    //If the player was in the arena, and the timer was running, kill it
    if (((player_slot <= SLOT_TWO) || (g_bFourPersonArena[arena_index] && player_slot <= SLOT_FOUR)) && g_bTimerRunning[arena_index])
    {
        delete g_tKothTimer[arena_index]
        g_bTimerRunning[arena_index] = false
    }

    if (g_bFourPersonArena[arena_index])
    {
        local foe_team_slot
        local player_team_slot

        if (player_slot <= SLOT_FOUR && player_slot > 0)
        {
            local foe_slot = (player_slot == SLOT_ONE || player_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE
            local foe = g_iArenaQueue[arena_index][foe_slot]
            local player_teammate
            local foe2

            foe_team_slot = (foe_slot > 2) ? (foe_slot - 2) : foe_slot
            player_team_slot = (player_slot > 2) ? (player_slot - 2) : player_slot

            if (g_bFourPersonArena[arena_index])
            {
                player_teammate = getTeammate(player_slot, arena_index)
                foe2 = getTeammate(foe_slot, arena_index)

            }

            if (g_bArenaBBall[arena_index])
            {
                local hBallIntel = EntIndexToHScript(g_iBBallIntel[arena_index])
                if (hBallIntel && hBallIntel.IsValid())
                {
                    //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
                    // RemoveEdict(g_iBBallIntel[arena_index]);
                    hBallIntel.Kill()
                    g_iBBallIntel[arena_index] = -1
                }

                // client.RemoveParticle(g_iClientParticle[iClient]);
                client.AcceptInput("DispatchEffect", "ParticleEffectStop", null, null)
                g_bPlayerHasIntel[iClient] = false

                if (foe)
                {
                    // RemoveClientParticle(foe);
                    foe.AcceptInput("DispatchEffect", "ParticleEffectStop", null, null)
                    g_bPlayerHasIntel[foe] = false
                }

                if (foe2)
                {
                    // RemoveClientParticle(foe2);
                    foe2.AcceptInput("DispatchEffect", "ParticleEffectStop", null, null)
                    g_bPlayerHasIntel[foe2] = false
                }

                if (player_teammate)
                {
                    // RemoveClientParticle(player_teammate);
                    player_teammate.AcceptInput("DispatchEffect", "ParticleEffectStop", null, null)
                    g_bPlayerHasIntel[player_teammate] = false
                }
            }

            if (g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED && calcstats && !g_bNoStats && foe)
            {
                local foe_name = ""
                local player_name = ""
                local foe2_name = ""
                local player_teammate_name = ""

                Convars.GetClientConvarValue("name", foe, foe_name, sizeof(foe_name))
                Convars.GetClientConvarValue("name", client, player_name, sizeof(player_name))
                Convars.GetClientConvarValue("name", foe2, foe2_name, sizeof(foe2_name))
                Convars.GetClientConvarValue("name", player_teammate, player_teammate_name, sizeof(player_teammate_name))

                g_iArenaStatus[arena_index] = AS_REPORTED

                if (g_iArenaScore[arena_index][foe_team_slot] > g_iArenaScore[arena_index][player_team_slot])
                {
                    if (g_iArenaScore[arena_index][foe_team_slot] >= g_iArenaEarlyLeave[arena_index])
                    {
                        CalcELO(foe, client)
                        CalcELO(foe2, client)
                        // MC_PrintToChatAll("%t", "XdefeatsYearly", foe_name, g_iArenaScore[arena_index][foe_team_slot], player_name, g_iArenaScore[arena_index][player_team_slot], g_sArenaName[arena_index]);
                        ClientPrint(client, 3, format("XdefeatsYearly %s %d %s %d %s", foe_name, g_iArenaScore[arena_index][foe_team_slot], player_name, g_iArenaScore[arena_index][player_team_slot], g_sArenaName[arena_index]))
                    }
                }
            }

            if (g_iArenaQueue[arena_index][SLOT_FOUR + 1])
            {
                local next_client = g_iArenaQueue[arena_index][SLOT_FOUR + 1]
                g_iArenaQueue[arena_index][SLOT_FOUR + 1] = 0
                g_iArenaQueue[arena_index][player_slot] = next_client
                g_iPlayerSlot[next_client] = player_slot
                after_leaver_slot = SLOT_FOUR + 2
                local playername = ""
                local next_client = g_iArenaQueue[arena_index][SLOT_FOUR + 1];
                g_iArenaQueue[arena_index][SLOT_FOUR + 1] = 0;
                g_iArenaQueue[arena_index][player_slot] = next_client;
                g_iPlayerSlot[next_client] = player_slot;
                after_leaver_slot = SLOT_FOUR + 2;
                local playername = "";
                // CreateTimer(2.0, Timer_StartDuel, arena_index);
                EntFire("worldspawn", "RunScriptCode", "StartDuel(" + arena_index + ")", 2.0, null);
                Convars.GetClientConvarValue("name", next_client, playername, sizeof(playername));

                if (!g_bNoStats && !g_bNoDisplayRating)
                    ClientPrint(client, 3, format("JoinsArena %s %d %s", playername, g_iPlayerRating[next_client], g_sArenaName[arena_index]));
                else
                    ClientPrint(client, 3, format("JoinsArenaNoStats %s %s", playername, g_sArenaName[arena_index]));


            } else {
                if (foe && foe.IsFakeClient())
                {
                    local quota = Convars.GetInt("tf_bot_quota");
                    Convars.SetValue("tf_bot_quota", quota - 1);
                }

                g_iArenaStatus[arena_index] = AS_IDLE;
                return;
            }
        }
    }

    else
    {
        if (player_slot == SLOT_ONE || player_slot == SLOT_TWO)
        {
            local foe_slot = player_slot == SLOT_ONE ? SLOT_TWO : SLOT_ONE;
            local foe = g_iArenaQueue[arena_index][foe_slot];

            if (g_bArenaBBall[arena_index])
            {
                local hBallIntel = EntIndexToHScript(g_iBBallIntel[arena_index]);
                if (hBallIntel && hBallIntel.IsValid())
                {
                    //SDKUnhook(g_iBBallIntel[arena_index], SDKHook_StartTouch, OnTouchIntel);
                    hBallIntel.Kill();
                    g_iBBallIntel[arena_index] = -1;
                }

                RemoveClientParticle(client);
                g_bPlayerHasIntel[client] = false;

                if (foe)
                {
                    RemoveClientParticle(foe);
                    g_bPlayerHasIntel[foe] = false;
                }
            }

            if (g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED && calcstats && !g_bNoStats && foe)
            {
                local foe_name = "";
                local player_name = "";
                Convars.GetClientConvarValue("name", foe, foe_name, sizeof(foe_name));
                Convars.GetClientConvarValue("name", client, player_name, sizeof(player_name));

                g_iArenaStatus[arena_index] = AS_REPORTED;

                if (g_iArenaScore[arena_index][foe_slot] > g_iArenaScore[arena_index][player_slot])
                {
                    if (g_iArenaScore[arena_index][foe_slot] >= g_iArenaEarlyLeave[arena_index])
                    {
                        CalcELO(foe, client);
                        ClientPrint(client, 3, format("XdefeatsYearly %s %d %s %d %s", foe_name, g_iArenaScore[arena_index][foe_slot], player_name, g_iArenaScore[arena_index][player_slot], g_sArenaName[arena_index]));
                    }
                }
            }

            if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
            {
                local next_client = g_iArenaQueue[arena_index][SLOT_TWO + 1];
                g_iArenaQueue[arena_index][SLOT_TWO + 1] = 0;
                g_iArenaQueue[arena_index][player_slot] = next_client;
                g_iPlayerSlot[next_client] = player_slot;
                after_leaver_slot = SLOT_TWO + 2;
                local playername = "";
                // CreateTimer(2.0, Timer_StartDuel, arena_index);
                EntFire("worldspawn", "RunScriptCode", "StartDuel(" + arena_index + ")", 2.0, null);
                Convars.GetClientConvarValue("name", next_client, playername, sizeof(playername));

                if (!g_bNoStats && !g_bNoDisplayRating)
                    ClientPrint(client, 3, format("JoinsArena %s %d %s", playername, g_iPlayerRating[next_client], g_sArenaName[arena_index]));
                else
                    ClientPrint(client, 3, format("JoinsArenaNoStats %s %s", playername, g_sArenaName[arena_index]));


            } else {
                if (foe && PlayerInstanceFromIndex(foe).IsFakeClient())
                {
                    local quota = Convars.GetInt("tf_bot_quota");
                    Convars.SetValue("tf_bot_quota", quota - 1);
                }

                g_iArenaStatus[arena_index] = AS_IDLE;
                return;
            }
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

::AddInQueue <- function(client, arena_index, showmsg = true, playerPrefTeam = 0)
{
    local iClient = client instanceof CBaseEntity ? client.entindex() : client;
    local hClient = typeof client == "integer" ? EntIndexToHScript(client) : client;

    printl(g_iPlayerArena[iClient])
    if (g_iPlayerArena[iClient])
    {
        ClientPrint(client, 3, format("client "+client+" is already on arena %d", arena_index));
    }

    //Set the player to the preffered team if there is room, otherwise just add him in wherever there is a slot
    local player_slot = SLOT_ONE
    if (playerPrefTeam == TEAM_RED)
    {
        if (!g_iArenaQueue[arena_index][SLOT_ONE])
            player_slot = SLOT_ONE
        else if (g_bFourPersonArena[arena_index] && !g_iArenaQueue[arena_index][SLOT_THREE])
            player_slot = SLOT_THREE;
        else
        {
            while (g_iArenaQueue[arena_index][player_slot])
                player_slot++;
        }
    }
    else if (playerPrefTeam == TEAM_BLU)
    {
        if (!g_iArenaQueue[arena_index][SLOT_TWO])
            player_slot = SLOT_TWO;
        else if (g_bFourPersonArena[arena_index] && !g_iArenaQueue[arena_index][SLOT_FOUR])
            player_slot = SLOT_FOUR;
        else
        {
            while (g_iArenaQueue[arena_index][player_slot])
                player_slot++;
        }
    }
    else
    {
        while (g_iArenaQueue[arena_index][player_slot])
            player_slot++;
    }

    g_iPlayerArena[iClient] = arena_index;
    g_iPlayerSlot[iClient] = player_slot;
    g_iArenaQueue[arena_index][player_slot] = iClient;

    SetPlayerToAllowedClass(client, arena_index);

    if (showmsg)
    {
        ClientPrint(client, 3, "ChoseArena "+g_sArenaName[arena_index]);
    }
    if (g_bFourPersonArena[arena_index])
    {
        if (player_slot <= SLOT_FOUR)
        {
            local name = Convars.GetClientConvarValue("name", client)

            if (!g_bNoStats && !g_bNoDisplayRating)
                ClientPrint(client, 3, "JoinsArena "+name+" "+g_iPlayerRating[iClient]+" "+g_sArenaName[arena_index])
            else
                ClientPrint(client, 3, "JoinsArenaNoStats "+name+" "+g_sArenaName[arena_index])

            if (g_iArenaQueue[arena_index][SLOT_ONE] && g_iArenaQueue[arena_index][SLOT_TWO] && g_iArenaQueue[arena_index][SLOT_THREE] && g_iArenaQueue[arena_index][SLOT_FOUR])
            {
                EntFire("worldspawn", "RunScriptCode", "StartDuel("+arena_index+")", 1.5, null)
            }
            else
                EntFireByHandle(client, "RunScriptCode", "ResetPlayer(self.entindex())", 2, null, null)
        } else {
            if (client.GetTeam() != TEAM_SPEC)
                client.ForceChangeTeam(TEAM_SPEC, true)
            if (player_slot == SLOT_FOUR + 1)
                ClientPrint(client, 3, "NextInLine")
            else
                ClientPrint(client, 3, "InLine "+player_slot+" "+SLOT_FOUR)
        }
    }
    else
    {
        if (player_slot <= SLOT_TWO)
        {
            local name = Convars.GetClientConvarValue("name", iClient)

            if (!g_bNoStats && !g_bNoDisplayRating)
                ClientPrint(hClient, 3, "JoinsArena "+name+" "+g_iPlayerRating[iClient]+" "+g_sArenaName[arena_index])
            else
                ClientPrint(hClient, 3, "JoinsArenaNoStats "+name+" "+g_sArenaName[arena_index])

            if (g_iArenaQueue[arena_index][SLOT_ONE] && g_iArenaQueue[arena_index][SLOT_TWO])
            {
                EntFire("worldspawn", "RunScriptCode", "StartDuel("+arena_index+")", 1.5, null)
            }

        } else {
            if (hClient.GetTeam() != TEAM_SPEC)
                hClient.ForceChangeTeam(TEAM_SPEC, true)
            if (player_slot == SLOT_TWO + 1)
                ClientPrint(hClient, 3, "NextInLine")
            else
                ClientPrint(hClient, 3, "InLine "+player_slot+" "+SLOT_TWO)
        }
    }
    EntFire("worldspawn", "RunScriptCode", "ResetPlayer("+iClient+")", 0.1, null)
    return;
}

::CalcELO <- function(winner, loser) {
    if ( winner.IsFakeClient() || loser.IsFakeClient() || g_bNoStats)
        return;

    // ELO formula
    local El = 1.0 / (pow(10.0, (g_iPlayerRating[winner] - g_iPlayerRating[loser]).tofloat() / 400) + 1)
    local k = (g_iPlayerRating[winner] >= 2400) ? 10 : 15
    local winnerscore = floor(k * El + 0.5)
    g_iPlayerRating[winner] += winnerscore
    k = (g_iPlayerRating[loser] >= 2400) ? 10 : 15
    local loserscore = floor(k * El + 0.5)
    g_iPlayerRating[loser] -= loserscore

    local arena_index = g_iPlayerArena[winner]
    local time = Time()

    if (winner && winner.IsValid() && !g_bNoDisplayRating)
        ClientPrint(winner, 3, format("You gained %d points!", winnerscore))

    if (loser && loser.IsValid() && !g_bNoDisplayRating)
        ClientPrint(loser, 3, format("You lost %d points!", loserscore))

    //This is necessary for when a player leaves a 2v2 arena that is almost done.
    //I don't want to penalize the player that doesn't leave, so only the winners/leavers ELO will be effected.
    local winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner]
    local loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser]

}

::CalcELO2 <- function(winner, winner2, loser, loser2) {

    if (winner.IsFakeClient() || loser.IsFakeClient() || g_bNoStats || loser2.IsFakeClient() || winner2.IsFakeClient())
        return;

    local Losers_ELO = (g_iPlayerRating[loser] + g_iPlayerRating[loser2]).tofloat() / 2;
    local Winners_ELO = (g_iPlayerRating[winner] + g_iPlayerRating[winner2]).tofloat() / 2;

    // ELO formula
    local El = 1 / (pow(10.0, (Winners_ELO - Losers_ELO) / 400) + 1);
    local k = (Winners_ELO >= 2400) ? 10 : 15;
    local winnerscore = floor(k * El + 0.5);
    g_iPlayerRating[winner] += winnerscore;
    g_iPlayerRating[winner2] += winnerscore;
    k = (Losers_ELO >= 2400) ? 10 : 15;
    local loserscore = floor(k * El + 0.5);
    g_iPlayerRating[loser] -= loserscore;
    g_iPlayerRating[loser2] -= loserscore;

    local winner_team_slot = (g_iPlayerSlot[winner] > 2) ? (g_iPlayerSlot[winner] - 2) : g_iPlayerSlot[winner];
    local loser_team_slot = (g_iPlayerSlot[loser] > 2) ? (g_iPlayerSlot[loser] - 2) : g_iPlayerSlot[loser];

    local arena_index = g_iPlayerArena[winner];
    local time = Time();

    if (winner && winner.IsValid() && !g_bNoDisplayRating)
        ClientPrint(winner, 3, format("You gained %d points!", winnerscore));

    if (winner2 && winner2.IsValid() && !g_bNoDisplayRating)
        ClientPrint(winner2, 3, format("You gained %d points!", winnerscore));

    if (loser && loser.IsValid() && !g_bNoDisplayRating)
        ClientPrint(loser, 3, format("You lost %d points!", loserscore));

    if (loser2 && loser2.IsValid() && !g_bNoDisplayRating)
        ClientPrint(loser2, 3, format("You lost %d points!", loserscore));
}

::PrintSpawnLocations <- function(maxArenas = MAXARENAS, maxSpawns = MAXSPAWNS) {
    function PrintArena(arenaIndex, spawnIndex = 0) {
        // Base case - if we've gone through all spawns for this arena
        if (spawnIndex > maxSpawns) {
            // Move to next arena
            if (arenaIndex < maxArenas) {
                PrintArena(arenaIndex + 1, 0)
            }
            return
        }

        // Skip if spawn location is all zeros (likely unused)
        local origin = g_fArenaSpawnOrigin[arenaIndex][spawnIndex]
        local angles = g_fArenaSpawnAngles[arenaIndex][spawnIndex]

        if (origin[0] != 0 || origin[1] != 0 || origin[2] != 0) {
            printl(format("Arena %d, Spawn %d:", arenaIndex, spawnIndex))
            printl(format("  Origin: (%.2f, %.2f, %.2f)", origin[0], origin[1], origin[2]))
            printl(format("  Angles: (%.2f, %.2f, %.2f)", angles[0], angles[1], angles[2]))
        }

        // Recurse to next spawn in this arena
        PrintArena(arenaIndex, spawnIndex + 1)
    }

    // Start recursion from first arena
    PrintArena(0)
}

// Call the function to print all spawn locations
PrintSpawnLocations()
::ResetPlayer <- function(client)
{
    local hClient = PlayerInstanceFromIndex(client)
    local arena_index = g_iPlayerArena[client];
    local player_slot = g_iPlayerSlot[client];

    if (!arena_index || !player_slot)
        return

    g_iPlayerSpecTarget[client] = 0;

    if (player_slot == SLOT_ONE || player_slot == SLOT_THREE)
        hClient.ForceChangeTeam(TEAM_RED, false);
    else
        hClient.ForceChangeTeam(TEAM_BLU, false);

    //This logic doesn't work with 2v2's
    //new team = GetClientTeam(client);
    //if (player_slot - team != SLOT_ONE - TEAM_RED)
    //  ChangeClientTeam(client, player_slot + TEAM_RED - SLOT_ONE);

    local _class = g_tfctPlayerClass[client] ? g_tfctPlayerClass[client] : "soldier";
//
//  if (GetPropInt(client, "m_lifeState") || g_bArenaBBall[arena_index])
    // {
        // local desired_class = class_string_names.find(_class)
        // if (desired_class != hClient.GetPlayerClass())
        // {
        //     hClient.SetPlayerClass(desired_class)
        //     SetPropInt(hClient, "m_Shared.m_iDesiredPlayerClass", desired_class)
        // }
        // hClient.ForceRegenerateAndRespawn()
    // } else {
        hClient.ForceRespawn()
        // hClient.ExtinguishPlayerBurning()
    // }

    g_iPlayerMaxHP[client] = hClient.GetMaxHealth()

    if (g_bArenaMidair[arena_index])
        g_iPlayerHP[client] = g_iMidairHP;
    else
        g_iPlayerHP[client] = g_iPlayerHandicap[client] ? g_iPlayerHandicap[client] : g_iPlayerMaxHP[client] * g_fArenaHPRatio[arena_index];

    if (g_bArenaMGE[arena_index] || g_bArenaBBall[arena_index])
        hClient.SetHealth(g_iPlayerHandicap[client] ? g_iPlayerHandicap[client] : g_iPlayerMaxHP[client] * g_fArenaHPRatio[arena_index])

    ShowPlayerHud(hClient);
    // ResetClientAmmoCounts(client);
    // CreateTimer(0.1, Timer_Tele, GetClientUserId(client));
    EntFireByHandle(hClient, "RunScriptCode", "Timer_Tele(self)", 0.1, null, null)

    return 1;
}

::ResetKiller <- function(killer, arena_index)
{
    local hKiller = PlayerInstanceFromIndex(killer);
    local reset_hp = g_iPlayerHandicap[killer] ? g_iPlayerHandicap[killer] : g_iPlayerMaxHP[killer] * g_fArenaHPRatio[arena_index];
    g_iPlayerHP[killer] = reset_hp;
    hKiller.Regenerate(true);
}


::SetPlayerToAllowedClass <- function(client, arena_index)
{  // If a player's class isn't allowed, set it to one that is.
    local iClient = client.entindex();
    if (g_tfctPlayerClass[iClient] == 0 || !g_tfctArenaAllowedClasses[arena_index][g_tfctPlayerClass[iClient]])
    {
        for (local i = 1; i <= 9; i++)
        {
            if (g_tfctArenaAllowedClasses[arena_index][i])
            {
                if (g_bArenaUltiduo[arena_index] && g_bFourPersonArena[arena_index] && g_iPlayerSlot[iClient] > SLOT_TWO)
                {
                    local client_teammate = getTeammate(g_iPlayerSlot[iClient], arena_index);
                    if (g_tfctPlayerClass[client_teammate] == i)
                    {
                        //Tell the player what he did wrong
                        ClientPrint(client, 3, "Your team already has that class!");

                        if (g_tfctPlayerClass[client_teammate] == TF_CLASS_SOLDIER)
                            g_tfctPlayerClass[iClient] = TF_CLASS_MEDIC;
                        else
                            g_tfctPlayerClass[iClient] = TF_CLASS_SOLDIER;

                    }
                }
                else
                    g_tfctPlayerClass[iClient] = i;

                break;
            }
        }
    }
}

::TraceEntityFilterPlayer <- function(entity, contentsMask)
{
    return entity > MaxClients || !entity;
}

/* TraceEntityPlayersOnly()
 *
 * Returns only players.
 * -------------------------------------------------------------------------- */
/*
bool TraceEntityPlayersOnly(int entity, int mask, int client)
{
    if (IsValidClient(entity) && entity != client)
    {
        PrintToChatAll("returning true for %d<%N>", entity, entity);
        return true;
    } else {
        PrintToChatAll("returning false for %d<%N>", entity, entity);
        return false;
    }
}
*/

/* ShootsRocketsOrPipes()
 *
 * Does this player's gun shoot rockets or pipes?
 * -------------------------------------------------------------------------- */
::ShootsRocketsOrPipes <- function(client)
{
    local hClient = PlayerInstanceFromIndex(client)
    if (!hClient || !hClient.IsValid())
        return false

    for (local child = hClient.FirstMoveChild(); child != null; child = child.NextMovePeer())

        if (child.GetClassname() == "tf_weapon_rocketlauncher" || child.GetClassname() == "tf_weapon_grenadelauncher")
        {
            return true
            break
        }

    return false
}

/* DistanceAboveGround()
 *
 * How high off the ground is the player?
 * -------------------------------------------------------------------------- */
::DistanceAboveGround <- function(victim)
{
    local vStart = victim.GetAbsOrigin()
    local vEnd = Vector()
    local vAngles = QAngle(90.0, 0.0, 0.0)
    local trace = TraceLineEx({
        start = vStart,
        end = vEnd,
        mask = MASK_PLAYERSOLID,
        type = RayType_Infinite,
        filter = TraceEntityFilterPlayer
    })

    local distance = -1.0;
    if (trace.hit)
    {
        distance = (vStart - trace.endpos).Length()
    } else {
        LogError("trace error. victim %N(%d)", victim, victim);
    }

    return distance;
}

/* DistanceAboveGroundAroundUser()
 *
 * How high off the ground is the player?
 *This is used for dropping
 * -------------------------------------------------------------------------- */

 // i highly suspect this also needs a switch case rewrite lol

::DistanceAboveGroundAroundPlayer <- function(victim)
{
    local vStart = victim.GetAbsOrigin()
    local vEnd = Vector()
    local vAngles = QAngle(90.0, 0.0, 0.0)
    local minDist

    for (local i = 0; i < 5; ++i)
    {
        local tvStart = vStart
        local tempDist = -1.0
        if (i == 0)
        {
            local trace = TraceLineEx({
                start = vStart,
                end = vEnd,
                mask = MASK_PLAYERSOLID,
                type = RayType_Infinite,
                filter = TraceEntityFilterPlayer
            })

            if (TR_DidHit(trace))
            {
                vEnd = trace.endpos
                minDist = (vStart - vEnd).Length()
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
        }
        else if (i == 1)
        {
            tvStart[0] = tvStart[0] + 10;
            local trace = TraceLineEx({
                start = tvStart,
                end = vEnd,
                mask = MASK_PLAYERSOLID,
                type = RayType_Infinite,
                filter = TraceEntityFilterPlayer
            })

            if (TR_DidHit(trace))
            {
                TR_GetEndPosition(vEnd, trace);
                tempDist = GetVectorDistance(tvStart, vEnd, false);
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
        }
        else if (i == 2)
        {
            tvStart[0] = tvStart[0] - 10;
            local trace = TraceLineEx({
                start = tvStart,
                end = vEnd,
                mask = MASK_PLAYERSOLID,
                type = RayType_Infinite,
                filter = TraceEntityFilterPlayer
            })

            if (TR_DidHit(trace))
            {
                TR_GetEndPosition(vEnd, trace);
                tempDist = GetVectorDistance(tvStart, vEnd, false);
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
        }
        else if (i == 3)
        {
            tvStart[1] = vStart[1] + 10;
            local trace = TraceLineEx({
                start = tvStart,
                end = vEnd,
                mask = MASK_PLAYERSOLID,
                type = RayType_Infinite,
                filter = TraceEntityFilterPlayer
            })

            if (TR_DidHit(trace))
            {
                TR_GetEndPosition(vEnd, trace);
                tempDist = GetVectorDistance(tvStart, vEnd, false);
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
        }
        else if (i == 4)
        {
            tvStart[1] = vStart[1] - 10;
            local trace = TraceLineEx({
                start = tvStart,
                end = vEnd,
                mask = MASK_PLAYERSOLID,
                type = RayType_Infinite,
                filter = TraceEntityFilterPlayer
            })

            if (TR_DidHit(trace))
            {
                TR_GetEndPosition(vEnd, trace);
                tempDist = GetVectorDistance(tvStart, vEnd, false);
            } else {
                LogError("trace error. victim %N(%d)", victim, victim);
            }
        }

        if ((tempDist > -1 && tempDist < minDist) || minDist == -1)
        {
            minDist = tempDist;
        }
    }

    return minDist;
}

/* FindEntityByClassname2()
 *
 * Finds entites, and won't error out when searching invalid entities.
 * -------------------------------------------------------------------------- */
// stock int FindEntityByClassname2(int startEnt, const char[] classname)
// {
//     /* If startEnt isn't valid shifting it back to the nearest valid one */
//     while (startEnt > -1 && !IsValidEntity(startEnt))startEnt--;

//     return FindEntityByClassname(startEnt, classname);
// }

/* getTeammate()
 *
 * Gets a clients teammate if he's in a 4 player arena
 * This can actually be replaced by g_iArenaQueue[SLOT_X] but I didn't realize that array existed, so YOLO
 *---------------------------------------------------------------------*/
::getTeammate <- function(myClientSlot, arena_index)
{

    local client_teammate_slot;

    if (myClientSlot == SLOT_ONE)
    {
        client_teammate_slot = SLOT_THREE;
    }
    else if (myClientSlot == SLOT_TWO)
    {
        client_teammate_slot = SLOT_FOUR;
    }
    else if (myClientSlot == SLOT_THREE)
    {
        client_teammate_slot = SLOT_ONE;
    }
    else
    {
        client_teammate_slot = SLOT_TWO;
    }

    local myClientTeammate = g_iArenaQueue[arena_index][client_teammate_slot];
    return myClientTeammate;

}


::ChangeSpecTarget <- function(client)
{
    local iClient = client instanceof CBaseEntity ? client.entindex() : client;
    local hClient = typeof client == "integer" ? EntIndexToHScript(client) : client;

    if (!hClient || !hClient.IsValid())
        return;

    local target = GetPropEntity(hClient, "m_hObserverTarget");
    local iTarget = target ? target.entindex() : 0;

    if (target && target.IsValid() && iTarget in g_iPlayerArena)
    {
        g_iPlayerSpecTarget[iClient] = iTarget;
        // ShowSpecHudToClient(iClient);
    }
    else
    {
        // HideHud(client);
        g_iPlayerSpecTarget[iClient] = 0;
    }
}
::isPlayerWaiting <- function(myClient)
{
    return g_iPlayerWaiting[myClient];
}

/*  EndUlitduo(any arena_index, any winner_team)
*
* Called when someone wins an ultiduo round
* --------------------------------------------------------------------------- */
::EndKoth <- function(arena_index, winner_team)
{

    PlayEndgameSoundsToArena(arena_index, winner_team);
    g_iArenaScore[arena_index][winner_team] += 1;
    local fraglimit = g_iArenaFraglimit[arena_index];
    local client = g_iArenaQueue[arena_index][winner_team];
    local client_slot = winner_team;
    local foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
    local foe = g_iArenaQueue[arena_index][foe_slot];
    local client_teammate;
    local foe_teammate;

    //End the Timer if its still running
    //You shouldn't need to do this, but just incase
    if (g_bTimerRunning[arena_index])
    {
        delete g_tKothTimer[arena_index];
        g_bTimerRunning[arena_index] = false;
    }

    if (g_bFourPersonArena[arena_index])
    {
        client_teammate = getTeammate(client_slot, arena_index);
        foe_teammate = getTeammate(foe_slot, arena_index);
    }

    if (fraglimit > 0 && g_iArenaScore[arena_index][winner_team] >= fraglimit && g_iArenaStatus[arena_index] >= AS_FIGHT && g_iArenaStatus[arena_index] < AS_REPORTED)
    {
        g_iArenaStatus[arena_index] = AS_REPORTED;
        local foe_name = "";
        foe_name = Convars.GetClientConvarValue("name", foe);
        local client_name = "";
        client_name = Convars.GetClientConvarValue("name", client);

        if (g_bFourPersonArena[arena_index])
        {
            local client_teammate_name = "";
            local foe_teammate_name = "";

            client_teammate_name = Convars.GetClientConvarValue("name", client_teammate);
            foe_teammate_name = Convars.GetClientConvarValue("name", foe_teammate);

            client_name = format("%s and %s", client_name, client_teammate_name);
            foe_name = format("%s and %s", foe_name, foe_teammate_name);
        }

        // MC_PrintToChatAll("%t", "XdefeatsY", client_name, g_iArenaScore[arena_index][winner_team], foe_name, g_iArenaScore[arena_index][foe_slot], fraglimit, g_sArenaName[arena_index]);

        if (!g_bNoStats && !g_bFourPersonArena[arena_index])
            CalcELO(client, foe);

        else if (!g_bNoStats)
            CalcELO2(client, client_teammate, foe, foe_teammate);

        if (g_bFourPersonArena[arena_index] && g_iArenaQueue[arena_index][SLOT_FOUR + 1])
        {
            RemoveFromQueue(foe, false);
            RemoveFromQueue(foe_teammate, false);
            AddInQueue(foe, arena_index, false);
            AddInQueue(foe_teammate, arena_index, false);
        }
        else if (g_iArenaQueue[arena_index][SLOT_TWO + 1])
        {
            RemoveFromQueue(foe, false);
            AddInQueue(foe, arena_index, false);
        } else {
            CreateTimer(3.0, Timer_StartDuel, arena_index);
        }
    } else {
        ResetArena(arena_index);

        ResetPlayer(client);
        ResetPlayer(foe);

        if (g_bFourPersonArena[arena_index])
        {
            ResetPlayer(client_teammate);
            ResetPlayer(foe_teammate);
        }

        g_bPlayerTouchPoint[arena_index][SLOT_ONE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_TWO] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_THREE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_FOUR] = false;
        g_iKothTimer[arena_index][TEAM_RED] = g_iDefaultCapTime[arena_index];
        g_iKothTimer[arena_index][TEAM_BLU] = g_iDefaultCapTime[arena_index];
        g_fKothCappedPercent[arena_index] = 0.0;
        g_iCappingTeam[arena_index] = NEUTRAL;
        g_iPointState[arena_index] = NEUTRAL;
        g_fCappedTime[arena_index] = 0.0;
        g_bOvertimePlayed[arena_index][TEAM_RED] = false;
        g_bOvertimePlayed[arena_index][TEAM_BLU] = false;
        g_tKothTimer[arena_index] = CreateTimer(1.0, Timer_CountDownKoth, arena_index, TIMER_REPEAT);
        g_bTimerRunning[arena_index] = true;
    }

    ShowPlayerHud(client);
    ShowPlayerHud(foe);

    if (g_bFourPersonArena[arena_index])
    {
        ShowPlayerHud(client_teammate);
        ShowPlayerHud(foe_teammate);
    }
}

::ShowPlayerHud <- function(client)
{
    return;
}

::ResetArena <- function(arena_index)
{
    //Tell the game this was a forced suicide and it shouldn't do anything about it

    local maxSlots;
    if (g_bFourPersonArena[arena_index])
    {
        maxSlots = SLOT_FOUR;
    }
    else
    {
        maxSlots = SLOT_TWO;
    }

    for (local i = SLOT_ONE; i <= maxSlots; ++i)
    {
        local thisClient = PlayerInstanceFromIndex(g_iArenaQueue[arena_index][i]);
        if (thisClient && thisClient.IsValid() && thisClient.IsAlive() && thisClient.GetPlayerClass() == TF_CLASS_MEDIC)
        {
            // medigun
            for (local child = thisClient.FirstMoveChild(); child != null; child = child.NextMovePeer())
                if (child.GetClassname() == "tf_weapon_medigun")
                {
                    SetPropFloat(child, "m_flChargeLevel", 0.0)
                    break
                }
        }
    }
}
::swapClasses <- function(client, client_teammate)
{

    local client_class = g_tfctPlayerClass[client];
    local client_teammate_class = g_tfctPlayerClass[client_teammate];

    client.SetPlayerClass(client_teammate_class);
    SetPropInt(client, "m_Shared.m_iDesiredPlayerClass", client_teammate_class);
    client.TakeDamage(1000000, DMG_GENERIC, client);

    client_teammate.SetPlayerClass(client_class);
    SetPropInt(client_teammate, "m_Shared.m_iDesiredPlayerClass", client_class);
    client_teammate.TakeDamage(1000000, DMG_GENERIC, client_teammate);

    g_tfctPlayerClass[client] = client_teammate_class;
    g_tfctPlayerClass[client_teammate] = client_class;

}

::EnemyTeamTouching <- function(team, arena_index)
{
    if (team == TEAM_RED)
    {
        if (g_bPlayerTouchPoint[arena_index][SLOT_TWO])
            return true;
        else if (g_bFourPersonArena[arena_index] && g_bPlayerTouchPoint[arena_index][SLOT_FOUR])
            return true;
        else
            return false;
    }
    else
    {
        if (g_bPlayerTouchPoint[arena_index][SLOT_ONE])
            return true;
        else if (g_bFourPersonArena[arena_index] && g_bPlayerTouchPoint[arena_index][SLOT_THREE])
            return true;
        else
            return false;
    }
}

::PlayEndgameSoundsToArena <- function(arena_index, winner_team)
{
    local red_1 = g_iArenaQueue[arena_index][SLOT_ONE];
    local blu_1 = g_iArenaQueue[arena_index][SLOT_TWO];
    local SoundFileBlu = "";
    local SoundFileRed = "";

    //If the red team won
    if (winner_team == 1)
    {
        SoundFileRed = "vo/announcer_victory.wav";
        SoundFileBlu = "vo/announcer_you_failed.wav";
    }
    //Else the blu team won
    else
    {
        SoundFileBlu = "vo/announcer_victory.wav";
        SoundFileRed = "vo/announcer_you_failed.wav";
    }
    if (red_1 && red_1.IsValid())
        red_1.EmitSound(SoundFileRed);

    if (blu_1 && blu_1.IsValid())
        blu_1.EmitSound(SoundFileBlu);

    if (g_bFourPersonArena[arena_index])
    {
        local red_2 = g_iArenaQueue[arena_index][SLOT_THREE];
        local blu_2 = g_iArenaQueue[arena_index][SLOT_FOUR];
        if (g_iCappingTeam[arena_index] == TEAM_BLU)
        {
            if (red_2 && red_2.IsValid())
                red_2.EmitSound(SoundFileRed);
        }
        else
        {
            if (blu_2 && blu_2.IsValid())
                blu_2.EmitSound(SoundFileBlu);
        }
    }
}

::StartDuel <- function(arena_index)
{
    ResetArena(arena_index);

    if (g_bArenaTurris[arena_index])
    {
        CreateTimer(5.0, Timer_RegenArena, arena_index, TIMER_REPEAT);
    }
    if (g_bArenaKoth[arena_index])
    {

        g_bPlayerTouchPoint[arena_index][SLOT_ONE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_TWO] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_THREE] = false;
        g_bPlayerTouchPoint[arena_index][SLOT_FOUR] = false;
        g_iKothTimer[arena_index][0] = 0;
        g_iKothTimer[arena_index][1] = 0;
        g_iKothTimer[arena_index][TEAM_RED] = g_iDefaultCapTime[arena_index];
        g_iKothTimer[arena_index][TEAM_BLU] = g_iDefaultCapTime[arena_index];
        g_iCappingTeam[arena_index] = NEUTRAL;
        g_iPointState[arena_index] = NEUTRAL;
        g_fTotalTime[arena_index] = 0.0;
        g_fCappedTime[arena_index] = 0.0;
        g_fKothCappedPercent[arena_index] = 0.0;
        g_bOvertimePlayed[arena_index][TEAM_RED] = false;
        g_bOvertimePlayed[arena_index][TEAM_BLU] = false;
        g_tKothTimer[arena_index] = CreateTimer(1.0, Timer_CountDownKoth, arena_index, TIMER_REPEAT);
        g_bTimerRunning[arena_index] = true;
    }

    g_iArenaScore[arena_index][SLOT_ONE] = 0;
    g_iArenaScore[arena_index][SLOT_TWO] = 0;
    ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_ONE]);
    ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_TWO]);

    if (g_bFourPersonArena[arena_index])
    {
        ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_THREE]);
        ShowPlayerHud(g_iArenaQueue[arena_index][SLOT_FOUR]);
    }

    // ShowSpecHudToArena(arena_index);

    // StartCountDown(arena_index);
}

::StartCountDown <- function(arena_index)
{
    local red_f1 = g_iArenaQueue[arena_index][SLOT_ONE]; /* Red (slot one) player. */
    local blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO]; /* Blu (slot two) player. */

    if (g_bFourPersonArena[arena_index])
    {
        local red_f2 = g_iArenaQueue[arena_index][SLOT_THREE]; /* 2nd Red (slot three) player. */
        local blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR]; /* 2nd Blu (slot four) player. */

        if (red_f1)
            ResetPlayer(red_f1);
        if (blu_f1)
            ResetPlayer(blu_f1);
        if (red_f2)
            ResetPlayer(red_f2);
        if (blu_f2)
            ResetPlayer(blu_f2);


        if (red_f1 && blu_f1 && red_f2 && blu_f2)
        {
            local _players = [red_f1, blu_f1, red_f2, blu_f2];
            local enginetime = Time();

            foreach (p in _players)
                for (local child = p.FirstMoveChild(); child != null; child = child.NextMovePeer())
                    if (child.GetClassname() == "tf_weapon_medigun")
                        SetPropFloat(child, "m_flNextPrimaryAttack", enginetime + 1.1)


            g_iArenaCd[arena_index] = g_iArenaCdTime[arena_index] + 1;
            g_iArenaStatus[arena_index] = AS_PRECOUNTDOWN;
            CreateTimer(0.1, Timer_CountDown, arena_index, TIMER_FLAG_NO_MAPCHANGE);
            return 1;
        } else {
            g_iArenaStatus[arena_index] = AS_IDLE;
            return 0;
        }
    }
    else {
        if (red_f1)
            ResetPlayer(red_f1);
        if (blu_f1)
            ResetPlayer(blu_f1);

        if (red_f1 && blu_f1)
        {
            local enginetime = Time();

            for (local i = 0; i <= 2; i++)
            {
                local ent = GetPlayerWeaponSlot(red_f1, i);

                if (IsValidEntity(ent))
                    SetPropFloat(ent, "m_flNextPrimaryAttack", enginetime + 1.1);

                ent = GetPlayerWeaponSlot(blu_f1, i);

                if (IsValidEntity(ent))
                    SetPropFloat(ent, "m_flNextPrimaryAttack", enginetime + 1.1);
            }

            g_iArenaCd[arena_index] = g_iArenaCdTime[arena_index] + 1;
            g_iArenaStatus[arena_index] = AS_PRECOUNTDOWN;
            EntFire("worldspawn", "RunScriptCode", "Timer_CountDown(" + arena_index + ")", 0.1, null);
            return 1;
        }
        else
        {
            g_iArenaStatus[arena_index] = AS_IDLE;
            return 0;
        }
    }
}

::Timer_CountDown <- function(arena_index)
{
    local red_f1 = g_iArenaQueue[arena_index][SLOT_ONE];
    local blu_f1 = g_iArenaQueue[arena_index][SLOT_TWO];
    local red_f2;
    local blu_f2;
    if (g_bFourPersonArena[arena_index])
    {
        red_f2 = g_iArenaQueue[arena_index][SLOT_THREE];
        blu_f2 = g_iArenaQueue[arena_index][SLOT_FOUR];
    }
    if (g_bFourPersonArena[arena_index])
    {
        if (red_f1 && blu_f1 && red_f2 && blu_f2)
        {
            local _players = [red_f1, blu_f1, red_f2, blu_f2];
            g_iArenaCd[arena_index]--;

            if (g_iArenaCd[arena_index] > 0)
            {  // blocking +attack
                local enginetime = Time();

                foreach (p in _players)
                    for (local child = p.FirstMoveChild(); child != null; child = child.NextMovePeer())
                        if (child instanceof CBaseCombatWeapon)
                            SetPropFloat(child, "m_flNextPrimaryAttack", enginetime + 1.1)
            }

            if (g_iArenaCd[arena_index] <= 3 && g_iArenaCd[arena_index] >= 1)
            {
                local msg = "";

                switch (g_iArenaCd[arena_index])
                {
                    case 1:msg = "ONE";
                    case 2:msg = "TWO";
                    case 3:msg = "THREE";
                }

                ClientPrint(red_f1, HUD_PRINTCENTER, msg);
                ClientPrint(blu_f1, HUD_PRINTCENTER, msg);
                if (g_bFourPersonArena[arena_index]) {
                    ClientPrint(red_f2, HUD_PRINTCENTER, msg);
                    ClientPrint(blu_f2, HUD_PRINTCENTER, msg);
                }
                ShowCountdownToSpec(arena_index, msg);
                g_iArenaStatus[arena_index] = AS_COUNTDOWN;

            } else if (g_iArenaCd[arena_index] <= 0) {

                g_iArenaStatus[arena_index] = AS_FIGHT;
                local msg = "FIGHT";
                ClientPrint(red_f1, HUD_PRINTCENTER, msg);
                ClientPrint(blu_f1, HUD_PRINTCENTER, msg);
                if (g_bFourPersonArena[arena_index]) {
                    ClientPrint(red_f2, HUD_PRINTCENTER, msg);
                    ClientPrint(blu_f2, HUD_PRINTCENTER, msg);
                }
                ShowCountdownToSpec(arena_index, msg);

                //For bball.
                if (g_bArenaBBall[arena_index])
                {
                    ResetIntel(arena_index);
                }

                return
            }


            CreateTimer(1.0, Timer_CountDown, arena_index, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            return
        } else {
            g_iArenaStatus[arena_index] = AS_IDLE;
            g_iArenaCd[arena_index] = 0;
            return
        }
    }
    else
    {
        if (red_f1 && blu_f1)
        {
            g_iArenaCd[arena_index]--;

            local _players = [red_f1, blu_f1];

            if (g_iArenaCd[arena_index] > 0)
            {  // blocking +attack
                local enginetime = Time();

                foreach (p in _players)
                    for (local child = p.FirstMoveChild(); child != null; child = child.NextMovePeer())
                        if (child instanceof CBaseCombatWeapon)
                            SetPropFloat(child, "m_flNextPrimaryAttack", enginetime + 1.1)
            }

            if (g_iArenaCd[arena_index] <= 3 && g_iArenaCd[arena_index] >= 1)
            {
                local msg = "";

                switch (g_iArenaCd[arena_index])
                {
                    case 1:msg = "ONE";
                    case 2:msg = "TWO";
                    case 3:msg = "THREE";
                }

                ClientPrint(red_f1, HUD_PRINTCENTER, msg);
                ClientPrint(blu_f1, HUD_PRINTCENTER, msg);
                ShowCountdownToSpec(arena_index, msg);
                g_iArenaStatus[arena_index] = AS_COUNTDOWN;
            } else if (g_iArenaCd[arena_index] <= 0) {
                g_iArenaStatus[arena_index] = AS_FIGHT;
                local msg = "FIGHT";
                ClientPrint(red_f1, HUD_PRINTCENTER, msg);
                ClientPrint(blu_f1, HUD_PRINTCENTER, msg);
                ShowCountdownToSpec(arena_index, msg);

                //For bball.
                if (g_bArenaBBall[arena_index])
                {
                    ResetIntel(arena_index);
                }
                return
            }

            CreateTimer(1.0, Timer_CountDown, arena_index, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
            return
        } else {
            g_iArenaStatus[arena_index] = AS_IDLE;
            g_iArenaCd[arena_index] = 0;
            return
        }
    }
    // unreachable
    // return Plugin_Continue;
}
::Timer_Tele <- function(client)
{
    local iClient = client instanceof CBaseEntity ? client.entindex() : client;
    local hClient = typeof client == "integer" ? PlayerInstanceFromIndex(client) : client;

    local arena_index = g_iPlayerArena[iClient];

    if (!arena_index)
        return

    local arena_spawns = g_fArenaSpawnOrigin[arena_index];

    // Find a valid non-zero spawn to use as replacement
    local replacement_spawn = null;
    for (local i = arena_spawns.len(); i > 0; i--) {
        if (!(i in arena_spawns)) continue;

        local spawn = arena_spawns[i];
        if (spawn[0] != 0 || spawn[1] != 0 || spawn[2] != 0) {
            replacement_spawn = spawn;
            break;
        }
    }

    // Replace any zero spawns with the valid replacement
    if (replacement_spawn != null) {
        for (local i = arena_spawns.len(); i > 0; i--) {
            if (!(i in arena_spawns)) continue;

            local spawn = arena_spawns[i];
            if (spawn[0] == 0 && spawn[1] == 0 && spawn[2] == 0) {
                arena_spawns[i] = replacement_spawn;
            }
        }
    }

    local player_slot = g_iPlayerSlot[iClient];
    if ((!g_bFourPersonArena[arena_index] && player_slot > SLOT_TWO) || (g_bFourPersonArena[arena_index] && player_slot > SLOT_FOUR))
    {
        return;
    }

    local vel = [0.0, 0.0, 0.0]


    // CHECK FOR MANNTREADS IN ENDIF
    if (g_bArenaEndif[arena_index])
    {
        for (local child = client.FirstMoveChild(); child != null; child = child.NextMovePeer())
        {
            local itemdef = GetPropInt(child, "m_AttributeManager.m_Item.m_iItemDefinitionIndex");
            // manntreads itemdef
            if (itemdef == 444)
            {
                // just in case.
                EntFireByHandle(child, "Kill", "", -1, null, null);
                ClientPrint(client, HUD_PRINTTALK, "[MGE] Arena = EndIf and you have the Manntreads. Automatically removing you from the queue.");
                // run elo calc so clients can't be cheeky if they're losing
                RemoveFromQueue(client, true);
            }
        }
    }


    // BBall and 2v2 arenas handle spawns differently, each team, has their own spawns.
    if (g_bArenaBBall[arena_index])
    {
        local random_int;
        local offset_high, offset_low;
        if (g_iPlayerSlot[iClient] == SLOT_ONE || g_iPlayerSlot[iClient] == SLOT_THREE)
        {
            offset_high = ((g_iArenaSpawns[arena_index] - 5) / 2);
            random_int = RandomInt(1, offset_high); //The first half of the player spawns are for slot one and three.
        } else {
            offset_high = (g_iArenaSpawns[arena_index] - 5);
            offset_low = (((g_iArenaSpawns[arena_index] - 5) / 2) + 1);
            random_int = RandomInt(offset_low, offset_high); //The last 5 spawns are for the intel and trigger spawns, not players.
        }

        hClient.SetAbsOrigin(g_fArenaSpawnOrigin[arena_index][random_int]);
        hClient.SnapEyeAngles(g_fArenaSpawnAngles[arena_index][random_int]);
        hClient.SetAbsVelocity(vel);

        hClient.EmitSound("items/spawn_item.wav");
        ShowPlayerHud(hClient);
        return;
    }
    else if (g_bArenaKoth[arena_index])
    {
        local random_int;
        local offset_high, offset_low;
        if (g_iPlayerSlot[iClient] == SLOT_ONE || g_iPlayerSlot[iClient] == SLOT_THREE)
        {
            offset_high = ((g_iArenaSpawns[arena_index] - 1) / 2);
            random_int = RandomInt(1, offset_high); //The first half of the player spawns are for slot one and three.
        } else {
            offset_high = (g_iArenaSpawns[arena_index] - 1);
            offset_low = (((g_iArenaSpawns[arena_index] + 1) / 2));
            random_int = RandomInt(offset_low, offset_high); //The last spawn is for the point
        }

        hClient.SetAbsOrigin(g_fArenaSpawnOrigin[arena_index][random_int]);
        hClient.SnapEyeAngles(g_fArenaSpawnAngles[arena_index][random_int]);
        hClient.SetAbsVelocity(vel);
        hClient.EmitSound("items/spawn_item.wav");
        ShowPlayerHud(hClient);
        return;
    }
    else if (g_bFourPersonArena[arena_index])
    {
        local random_int;
        local offset_high, offset_low;
        if (g_iPlayerSlot[iClient] == SLOT_ONE || g_iPlayerSlot[iClient] == SLOT_THREE)
        {
            offset_high = ((g_iArenaSpawns[arena_index]) / 2);
            random_int = RandomInt(1, offset_high); //The first half of the player spawns are for slot one and three.
        } else {
            offset_high = (g_iArenaSpawns[arena_index]);
            offset_low = (((g_iArenaSpawns[arena_index]) / 2) + 1);
            random_int = RandomInt(offset_low, offset_high);
        }

        local spawn_kvstrings = g_fArenaSpawnOrigin[arena_index][random_int]
        local angles_kvstrings = g_fArenaSpawnAngles[arena_index][random_int]

        spawn_kvstrings = spawn_kvstrings.apply(@(val) val.tofloat());
        angles_kvstrings = angles_kvstrings.apply(@(val) val.tofloat());

        local spawn = Vector(spawn_kvstrings[0], spawn_kvstrings[1], spawn_kvstrings[2]);
        local angles = QAngle(angles_kvstrings[0], angles_kvstrings[1], angles_kvstrings[2]);

        printl("4");
        printl(spawn);
        printl(angles);
        printl(vel);

        hClient.SetAbsOrigin(spawn);
        hClient.SnapEyeAngles(angles);
        hClient.SetAbsVelocity(vel);
        hClient.EmitSound("items/spawn_item.wav");
        ShowPlayerHud(hClient);
        return;
    }

    // Create an array that can hold all the arena's spawns.
    local RandomSpawn = array(g_iArenaSpawns[arena_index], 0);

    // Fill the array with the spawns.
    for (local i = 0; i < g_iArenaSpawns[arena_index]; i++)
        RandomSpawn[i] = i + 1;

    // Shuffle them into a random order.
    // Fisher-Yates shuffle algorithm
    for (local i = g_iArenaSpawns[arena_index] - 1; i > 0; i--) {
        local j = RandomInt(0, i);
        local temp = RandomSpawn[i];
        RandomSpawn[i] = RandomSpawn[j];
        RandomSpawn[j] = temp;
    }

    // Now when the array is gone through sequentially, it will still provide a random spawn.
    local besteffort_dist;
    local besteffort_spawn;
    local vel = Vector();

    for (local i = 0; i < g_iArenaSpawns[arena_index]; i++)
    {
        local client_slot = g_iPlayerSlot[iClient];
        local foe_slot = (client_slot == SLOT_ONE || client_slot == SLOT_THREE) ? SLOT_TWO : SLOT_ONE;
        if (foe_slot)
        {
            local distance;
            local foe = g_iArenaQueue[arena_index][foe_slot];
            local hFoe = foe ? PlayerInstanceFromIndex(foe) : null;
            if (hFoe && hFoe.IsValid())
            {
                local foe_pos = hFoe.GetOrigin();
                local spawn_kvstrings = g_fArenaSpawnOrigin[arena_index][RandomSpawn[i]]
                local angles_kvstrings = g_fArenaSpawnAngles[arena_index][RandomSpawn[i]]

                spawn_kvstrings = spawn_kvstrings.apply(@(val) val.tofloat());
                angles_kvstrings = angles_kvstrings.apply(@(val) val.tofloat());

                local spawn = Vector(spawn_kvstrings[0], spawn_kvstrings[1], spawn_kvstrings[2]);
                local angles = QAngle(angles_kvstrings[0], angles_kvstrings[1], angles_kvstrings[2]);

                printl("1");
                printl(spawn);
                printl(angles);
                printl(vel);

                distance = (foe_pos - spawn).Length();
                if (distance > g_fArenaMinSpawnDist[arena_index])
                {
                    hClient.SetAbsOrigin(spawn);
                    hClient.SnapEyeAngles(angles);
                    hClient.SetAbsVelocity(vel);
                    hClient.EmitSound("items/spawn_item.wav");
                    ShowPlayerHud(client);
                    return;
                } else if (distance > besteffort_dist) {
                    besteffort_dist = distance;
                    besteffort_spawn = i;
                }
            }
        }
    }

    if (besteffort_spawn)
    {

        // No foe, so just pick a random spawn.
        local besteffort_int = RandomInt(1, g_iArenaSpawns[besteffort_spawn]);
        local origin_kvstrings = g_fArenaSpawnOrigin[besteffort_spawn][besteffort_int]
        local angles_kvstrings = g_fArenaSpawnAngles[besteffort_spawn][besteffort_int]
        // local vel_kvstrings = g_fArenaSpawnVel[besteffort_spawn][besteffort_int]

        origin_kvstrings = origin_kvstrings.apply(@(val) val.tofloat());
        angles_kvstrings = angles_kvstrings.apply(@(val) val.tofloat());
        // vel_kvstrings = vel_kvstrings.apply(@(val) val.tofloat());

        local spawn = Vector(origin_kvstrings[0], origin_kvstrings[1], origin_kvstrings[2]);
        local angles = QAngle(angles_kvstrings[0], angles_kvstrings[1], angles_kvstrings[2]);
        // local vel = Vector(vel_kvstrings[0], vel_kvstrings[1], vel_kvstrings[2]);

        printl("2");
        printl(spawn);
        printl(angles);
        printl(vel);
        // Couldn't find a spawn that was far enough away, so use the one that was the farthest.
        client.Teleport(false, spawn, false, angles, false, vel);
        hClient.EmitSound("items/spawn_item.wav");
        ShowPlayerHud(client);
        return;
    } else {
        // No foe, so just pick a random spawn.
        local random_int = RandomInt(1, g_iArenaSpawns[arena_index]);
        local origin_kvstrings = g_fArenaSpawnOrigin[arena_index][random_int]
        local angles_kvstrings = g_fArenaSpawnAngles[arena_index][random_int]
        // local vel_kvstrings = g_fArenaSpawnVel[arena_index][random_int]

        origin_kvstrings = origin_kvstrings.apply(@(val) val.tofloat());
        angles_kvstrings = angles_kvstrings.apply(@(val) val.tofloat());
        // vel_kvstrings = vel_kvstrings.apply(@(val) val.tofloat());

        local spawn = Vector(origin_kvstrings[0], origin_kvstrings[1], origin_kvstrings[2]);
        local angles = QAngle(angles_kvstrings[0], angles_kvstrings[1], angles_kvstrings[2]);
        // local vel = Vector(vel_kvstrings[0], vel_kvstrings[1], vel_kvstrings[2]);

        printl("3");
        printl(spawn);
        printl(angles);
        printl(vel);


        hClient.EmitSound("items/spawn_item.wav");
        ShowPlayerHud(client);
        hClient.SetAbsOrigin(spawn);
        hClient.SnapEyeAngles(angles);
        hClient.SetAbsVelocity(vel);
        return;
    }
    // unreachable
    // return;

}

::ParseAllowedClasses <- function(sList, output)
{
    local classes = []

    if (sList.len()) {
        classes = split(sList, " ")
    } else {
        classes = split(MGE_Config.allowedClasses, " ")
    }

    foreach (_class in classes) {
        foreach (idx, name in class_string_names) {
            if (_class == name) {
                output[idx + 1] = true
                break
            }
        }
    }
}

::AttachParticle <- function(ent, particleType) {
    local particle = CreateByClassname("info_particle_system")
    particle.SetOrigin(ent.GetOrigin())

    particle.KeyValueFromString("targetname", "tf2particle")
    particle.KeyValueFromString("effect_name", particleType)

    particle.DispatchSpawn()
    particle.AcceptInput("SetParent", "!activator", ent, ent, 0)
    particle.AcceptInput("Start", "", null, null)
}

::UpdateArenaName <- function(arena)
{
    local mode = g_bFourPersonArena[arena] ? "2v2" : "1v1";
    local type = g_bArenaMGE[arena] ? "MGE" :
        g_bArenaUltiduo[arena] ? "ULTI" :
        g_bArenaKoth[arena] ? "KOTH" :
        g_bArenaAmmomod[arena] ? "AMOD" :
        g_bArenaBBall[arena] ? "BBALL" :
        g_bArenaMidair[arena] ? "MIDA" :
        g_bArenaEndif[arena] ? "ENDIF" : ""
    g_sArenaName[arena] = format("%s [%s %s]", g_sArenaOriginalName[arena], mode, type);
    LogMessage(format("Arena %s updated to %s", g_sArenaOriginalName[arena], g_sArenaName[arena]));
}


//same naming convention as mge.sp
::OnMapStart <- function() {
    printl("[VScript MGEMod] Loaded, slaying alive players")
    for (local i = 1; i <= MAXPLAYERS; i++)
    {
        local player = PlayerInstanceFromIndex(i)

        if (!player || !player.IsValid()) continue
        g_bCanPlayerSwap[i] = true
        g_bCanPlayerGetIntel[i] = true

        player.TakeDamage(99999, 0, null)
    }
    g_spawnFile = MGE_Config.spawnFile
    g_bNoStats = MGE_Config.stats ? false : true
    local isMapAm = LoadSpawnPoints()
    if (isMapAm)
    {
        printl("[VScript MGEMod] Loaded spawnpoints")
        for (local i = 0; i <= g_iArenaCount; i++)
        {
            if (g_bArenaBBall[i])
            {
                g_iBBallHoop[i][SLOT_ONE] = -1;
                g_iBBallHoop[i][SLOT_TWO] = -1;
                g_iBBallIntel[i] = -1;
            }
            if (g_bArenaKoth[i])
            {
                g_iCapturePoint[i] = -1;
            }
        }

        // CreateTimer(1.0, Timer_SpecHudToAllArenas, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

        if (g_bAutoCvar)
        {
            /*  MGEMod often creates situtations where the number of players on RED and BLU will be uneven.
            If the server tries to force a player to a different team due to autobalance being on, it will interfere with MGEMod's queue system.
            These cvar settings are considered mandatory for MGEMod. */
            Convars.SetValue("mp_autoteambalance", "0");
            Convars.SetValue("mp_teams_unbalance_limit", "32");
            Convars.SetValue("mp_tournament", "0");
            LogMessage("AutoCvar: Setting mp_autoteambalance 0, mp_teams_unbalance_limit 32, & mp_tournament 0");
        }

        // HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
        // HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
        // HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
        // HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
        // HookEvent("teamplay_round_start", Event_RoundStart, EventHookMode_Post);
        // HookEvent("teamplay_win_panel", Event_WinPanel, EventHookMode_Post);

        // AddNormalSoundHook(sound_hook);
    // } else {
    }
        // SetFailState("Map not supported. MGEMod disabled.");
    // }

    for (local i = 0; i < MAXPLAYERS; i++)
    {
        g_iPlayerWaiting[i] = false;
        g_bCanPlayerSwap[i] = true;
        g_bCanPlayerGetIntel[i] = true;

    }

    for (local i = 0; i < MAXARENAS; i++)
    {
        g_bTimerRunning[i] = false;
        g_fCappedTime[i] = 0.0;
        g_fTotalTime[i] = 0.0;
    }
}

//call immediately
OnMapStart()