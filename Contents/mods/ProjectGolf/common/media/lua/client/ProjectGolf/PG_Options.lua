-- Project Golf - player options (B42 mod options menu), with safe defaults if the API is missing.

require "ProjectGolf/PG_Config"

local PG = ProjectGolf
PG.Options = PG.Options or {}
local O = PG.Options

local defaults = {
    showPreview = true,
    ball3D      = true,
    mapTees     = true,
}

local ok, err = pcall(function()
    if not PZAPI or not PZAPI.ModOptions then return end
    local opts = PZAPI.ModOptions:create(PG.MOD_ID, "Project Golf")
    opts:addTickBox("showPreview", "Show the trajectory preview", defaults.showPreview)
    opts:addTickBox("ball3D", "3D ball in Viewpoint (needs Project Golf - Viewpoint Ball)", defaults.ball3D)
    opts:addTickBox("mapTees", "Show the course's tee boxes and holes on the map", defaults.mapTees)
    O.api = opts
end)
if not ok then PG.log("mod options unavailable:", err) end

function O.get(name)
    if O.api then
        local okGet, value = pcall(function() return O.api:getOption(name):getValue() end)
        if okGet and value ~= nil then return value end
    end
    return defaults[name]
end
