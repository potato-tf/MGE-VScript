//::DEFAULT_LANGUAGE <- "english"

local function Include(file) {
    local path = format("mge/%s", file)
        IncludeScript(path)
}

//include order is important

local language = "DEFAULT_LANGUAGE" in getroottable() ? DEFAULT_LANGUAGE : Convars.GetStr("cl_language")

try
    Include(format("cfg/localization/%s", language))
catch (_)
    Include(format("cfg/localization/english"))


Include("constants")
Include("globals")
Include("functions")
Include("events")
Include("mge")
