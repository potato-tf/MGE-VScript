local function Include(file)
{
	local path = format("mge/%s", file)
	IncludeScript(path)
}

Include("cfg/mgemod_spawns")

local mapname = GetMapName()
if (!(mapname in SpawnConfigs))
	delete SpawnConfigs
else
{
	Include("constants")
	Include("itemdef_constants")
	Include("cfg/config")
	Include("cfg/localization")

	if (
		CONST.ELO_TRACKING_MODE > 1 	||
		CONST.ENABLE_LEADERBOARD 		||
		CONST.UPDATE_SERVER_DATA 		||
		CONST.GAMEMODE_AUTOUPDATE_REPO 	||
		CONST.PER_ARENA_LOGGING
	) {
		Include("vpi/vpi")
		// create a dummy file to make the directory
		StringToFile("_mge_mkdir_", "")
	}

	Include("functions")
	Include("events")
	Include("mge")

}