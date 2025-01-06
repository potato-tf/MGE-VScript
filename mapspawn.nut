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
	Include("functions")
	Include("events")
	Include("mge")
}