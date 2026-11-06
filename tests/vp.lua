package.path = arg[1] .. "/lua/shared/?.lua;" .. arg[1] .. "/lua/client/?.lua;" .. package.path
function getCore() return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end } end
local CALLS = {}
Viewpoint = { Addons = {
  viewState = function() return { on = true, eye = { x = 10, y = 10, z = 0.7, yaw = 0, pitch = -10 }, fov = 70 } end,
  ["projectgolf.ball"] = { Ball = {
     flight = function(id, path, dt) CALLS[#CALLS+1] = "flight"; LAST_PATH = path; return true end,
     preview = function(path, r, g, b) CALLS[#CALLS+1] = "preview"; LAST_PREVIEW = path end,
     clearPreview = function() CALLS[#CALLS+1] = "clear" end,
     stop = function() error("boom") end } } } }
Keyboard = {}
require "ProjectGolf/PG_Config"; require "ProjectGolf/PG_Viewpoint"
local VP = ProjectGolf.VP
local v = VP.state()
local function p(n, c) print((c and "PASS  " or "FAIL  ") .. n) end
-- a point straight along the view ray lands at the screen centre
local yaw, pitch = 0, math.rad(-10); local d = 8
local x, y, zf = 10 + d * math.cos(pitch), 10, 0.7 + d * math.sin(pitch) / math.sqrt(6)
local sx, sy = VP.project(v, x, y, zf)
p(("ray point -> centre (%.1f, %.1f)"):format(sx, sy), math.abs(sx - 960) < 0.01 and math.abs(sy - 540) < 0.01)
local sx2 = VP.project(v, 18, 12, 0)    -- south of the view line = right of centre (yaw 0 looks east, south is right)
p("south of the view line is right of centre", sx2 > 960)
local _, sy3 = VP.project(v, 18, 10, 0) -- ground below the view = lower on screen
p("ground point is lower on screen", sy3 > 540)
p("behind the camera is culled", VP.project(v, 2, 10, 0.7) == nil)
p("aim yaw follows the view", VP.aimYaw(v) == 0)
-- 3D ball addon bridge
p("3D ball active in first person", VP.ball3D(v) == true)
p("3D ball off in isometric (no view state)", VP.ball3D(nil) == false)
p("flight sent", VP.ballFlight(1, { 10, 10, 0, 11, 10, 0.5, 12, 10, 0 }, 0.05, 0) == true)
p("path encoded as text: " .. tostring(LAST_PATH), LAST_PATH == "10,10,0,0;11,10,0.5,0;12,10,0,0")
VP.ballStop(1)     -- a throwing export must not break our Lua
local pts = {}
for i = 0, 199 do pts[#pts + 1] = i * 0.1; pts[#pts + 1] = 0; pts[#pts + 1] = 0 end
VP.ballPreview(pts, 0, 1, 1, 1)
local count = select(2, LAST_PREVIEW:gsub(";", ";")) + 1
p("preview thinned to <= ~48 points, last point kept (" .. count .. ")", count <= 52 and LAST_PREVIEW:sub(-10) == "19.9,0,0,0")
VP.ballClearPreview()
p("calls in order + error contained", table.concat(CALLS, ",") == "flight,preview,clear")

-- terrain relief lifts drawing on the ground storey only
require "ProjectGolf/PG_Render"
local R = ProjectGolf.Render
local function log() end
ProjectGolf.log = function(...) RELIEF_LOG = table.concat({ ... }, " ") end
Viewpoint.Addons.terrainHeight = function(x, y) CALLS_T = (CALLS_T or 0) + 1; return 0.5 end
local fx, fy = VP.project(v, 18, 10, 0.5)
local rx, ry = R.toScreen(0, 18, 10, 0, v, 0)
p("ground point lifted by relief (0.5 storeys)", math.abs(fx - rx) < 1e-9 and math.abs(fy - ry) < 1e-9)
local ux, uy = VP.project(v, 18, 10, 1.2)
local qx, qy = R.toScreen(0, 18, 10, 1.2, v, 1)
p("roof (storey 1) is not lifted", math.abs(ux - qx) < 1e-9 and math.abs(uy - qy) < 1e-9)
local before = CALLS_T
for i = 1, 50 do R.toScreen(0, 18.01, 10.02, 0, v, 0) end
p("heights are cached", CALLS_T == before)
p("first height is logged: " .. tostring(RELIEF_LOG), RELIEF_LOG and RELIEF_LOG:find("terrainHeight") ~= nil)
ProjectGolf.Relief.units = "squares"; VP.clearReliefCache()
local sx2, sy2 = VP.project(v, 18, 10, 0.5 / math.sqrt(6))
local tx, ty = R.toScreen(0, 18, 10, 0, v, 0)
p("units = squares converts to storeys", math.abs(sx2 - tx) < 1e-9 and math.abs(sy2 - ty) < 1e-9)
ProjectGolf.Relief.units = "storeys"; VP.clearReliefCache()
-- a slope: height = x / 10 storeys; blended lookups follow it between grid samples
Viewpoint.Addons.terrainHeight = function(x, y) return x / 10 end
local worst = 0
for i = 0, 40 do local x = 18 + i * 0.037; worst = math.max(worst, math.abs(VP.groundLift(x, 10.13) - x / 10)) end
p(("relief follows a slope smoothly (worst error %.4f storeys)"):format(worst), worst < 1e-9)
VP.clearReliefCache()
Viewpoint.Addons.terrainHeight = function() return nil end
local nx, ny = R.toScreen(0, 18, 10, 0, v, 0)
local ox, oy = VP.project(v, 18, 10, 0)
p("relief off (nil) leaves points flat", math.abs(nx - ox) < 1e-9 and math.abs(ny - oy) < 1e-9)
