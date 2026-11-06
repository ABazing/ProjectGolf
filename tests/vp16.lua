-- Viewpoint 0.1.6: no addon API, only our ZombieBuddy bridge (global ProjectGolfVP16). Same results as 0.1.7.
package.path = arg[1] .. "/lua/shared/?.lua;" .. arg[1] .. "/lua/client/?.lua;" .. package.path
function getCore() return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end } end
Keyboard = {}
Viewpoint = { View = {}, ReliefMap = {} }        -- what 0.1.6 exposes: no Viewpoint.Addons
local CALLS, VIEW, DRAWING, ACTIVE = {}, "1,10,10,0.7,0,-10,70", true, true
ProjectGolfVP16 = {
  active = function() return ACTIVE end,
  why = function() return nil end,
  view = function() return VIEW end,
  terrainHeight = function(x, y) return 0.5 end,
  drawing = function() return DRAWING end,
  flight = function(id, path, dt) CALLS[#CALLS + 1] = "flight"; LAST_PATH = path; return true end,
  stop = function(id) CALLS[#CALLS + 1] = "stop" end,
  preview = function(path, r, g, b) CALLS[#CALLS + 1] = "preview" end,
  clearPreview = function() CALLS[#CALLS + 1] = "clear" end,
}
require "ProjectGolf/PG_Config"; require "ProjectGolf/PG_Viewpoint"
local VP = ProjectGolf.VP
local LOGS = {}; ProjectGolf.log = function(...) LOGS[#LOGS + 1] = table.concat({ ... }, " ") end
local function p(n, c) print((c and "PASS  " or "FAIL  ") .. n) end

p("present through the bridge", VP.present())
local v = VP.state()
p("view state parsed", v and v.on and v.eye.x == 10 and v.eye.y == 10 and math.abs(v.eye.z - 0.7) < 1e-9
  and v.eye.yaw == 0 and v.eye.pitch == -10 and v.fov == 70 and v.mode == "first_person")
-- the same projection as with 0.1.7's view state: a point on the view ray lands at the screen centre
local pitch, d = math.rad(-10), 8
local sx, sy = VP.project(v, 10 + d * math.cos(pitch), 10, 0.7 + d * math.sin(pitch) / math.sqrt(6))
p(("ray point -> centre (%.1f, %.1f)"):format(sx, sy), math.abs(sx - 960) < 0.01 and math.abs(sy - 540) < 0.01)
p("aim yaw follows the view", VP.aimYaw(v) == 0)
p("relief from the bridge (0.5 storeys)", math.abs(VP.groundLift(18, 10) - 0.5) < 1e-9)
p("no Viewpoint Ball mod: aim works, 3D ball stays off", VP.ball3D(v) == false and VP.aimYaw(v) == 0)
ProjectGolfViewpointBall = true
p("3D ball through the bridge", VP.ball3D(v) == true)
p("flight sent", VP.ballFlight(1, { 10, 10, 0, 11, 10, 0.5 }, 0.05, 0) == true)
local nums = {}; for n in tostring(LAST_PATH):gmatch("[^,;]+") do nums[#nums + 1] = tonumber(n) end
p("path lifted onto relief: " .. tostring(LAST_PATH), #nums == 8 and nums[3] == 0.5 and nums[4] == 0.5 and nums[7] == 1 and nums[8] == 0.5)
VP.ballPreview({ 10, 10, 0, 11, 10, 0 }, 0, 1, 1, 1); VP.ballClearPreview(); VP.ballStop(1)
p("calls reach the bridge", table.concat(CALLS, ",") == "flight,preview,clear,stop")
-- third person, isometric, broken drawing, bad text
VIEW = "2,10,10,1.5,45,-20,80"; p("third person", VP.state().mode == "third_person" and VP.state().eye.yaw == 45)
VIEW = nil; p("isometric: no view state", VP.state() == nil)
VIEW = "1,10,nan"; p("malformed view text ignored", VP.state() == nil)
VIEW = "1,10,10,0.7,0,-10,70"; DRAWING = false
p("drawing failed -> 2D overlay instead", VP.ball3D(VP.state()) == false)
local onLines = 0; for _, l in ipairs(LOGS) do if l:find("bridge on") then onLines = onLines + 1 end end
p("bridge on is logged once (" .. onLines .. ")", onLines == 1)
-- with the 0.1.7 addon API present, it wins and the bridge is not asked
Viewpoint.Addons = { viewState = function() return { on = true, eye = { x = 1, y = 2, z = 0, yaw = 0, pitch = 0 }, fov = 60 } end }
p("0.1.7 addon API wins over the bridge", VP.state().eye.x == 1)
