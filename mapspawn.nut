local function Include(file) {
    local path = format("mge/%s", file)
        IncludeScript(path)
}

//include these 2 first
Include("globals")
Include("functions")

Include("events")
Include("mge")