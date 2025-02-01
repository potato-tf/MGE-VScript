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

	if (ELO_TRACKING_MODE > 1 || ENABLE_LEADERBOARD || UPDATE_SERVER_DATA || GAMEMODE_AUTOUPDATE_REPO)
		Include("vpi/vpi")

	Include("functions")
	Include("events")
	Include("mge")

}