//::DEFAULT_LANGUAGE <- "english"

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
	local language = "DEFAULT_LANGUAGE" in getroottable() ? DEFAULT_LANGUAGE : Convars.GetStr("cl_language")

	try
		Include(format("cfg/localization/%s", language))
	catch (_)
		Include(format("cfg/localization/english"))

	Include("constants")
	Include("itemdef_constants")
	Include("functions")
	Include("events")
	Include("mge")
}