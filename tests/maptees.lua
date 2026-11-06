-- Tee boxes on the world map: draws every West Maple tee with its number, a tooltip on hover, hides when zoomed out.
local media = arg[1]
package.path = media .. "/lua/shared/?.lua;" .. media .. "/lua/client/?.lua;" .. package.path
UIFont = { Small = 1, Medium = 2 }
function getTextManager() return { getFontHeight = function() return 14 end, MeasureStringX = function(_, _, s) return #s * 7 end } end
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function() end }; rawset(t, k, e); return e end })
ISWorldMap = { renderStashMaps = function(self) self.stash = true end }
package.preload["ISUI/Maps/ISWorldMap"] = function() return ISWorldMap end
require "ProjectGolf/PG_Config"; require "ProjectGolf/PG_Courses"; require "ProjectGolf/PG_Options"
require "ProjectGolf/PG_MapTees"
local PG = ProjectGolf
local ok, bad = 0, 0
local function check(n, c) print((c and "PASS  " or "FAIL  ") .. n); if c then ok = ok + 1 else bad = bad + 1 end end
local function newMap(zoom, mouseAtHole, atFlag)
  local m = { texts = {}, rects = 0, polys = 0, lines = 0 }
  m.mapAPI = { getZoomF = function() return zoom end,
    worldToUIX = function(_, x, y) return (x - 5800) * 2 end, worldToUIY = function(_, x, y) return (y - 6000) * 2 end }
  m.javaObject = { DrawLine = function() m.lines = m.lines + 1 end }
  function m:drawPolygon() self.polys = self.polys + 1 end
  function m:drawRect() self.rects = self.rects + 1 end
  function m:drawRectBorder() end
  function m:drawTextCentre(t) self.texts[#self.texts + 1] = t end
  function m:drawText(t) self.texts[#self.texts + 1] = t end
  function m:isMouseOver() return true end
  local h = mouseAtHole and PG.Courses.list[1].holes[mouseAtHole]
  local mx = h and (h.tee.x + 0.5 - 5800) * 2 or -999
  local my = h and ((h.tee.y + 0.5 - 6000) * 2 - 10 - 5 - 2) or -999   -- inside the badge above the box
  if h and atFlag then mx, my = (h.cup.x + 0.5 - 5800) * 2 + 3, (h.cup.y + 0.5 - 6000) * 2 - 6 end   -- on its flag
  function m:getMouseX() return mx end
  function m:getMouseY() return my end
  return m
end
local m = newMap(15, nil)
ISWorldMap.renderStashMaps(m)
check("the game's own stash icons still draw", m.stash == true)
check("18 tee boxes and 18 flags drawn", m.polys == 36)
check("each tee joined to its cup by a dotted line (plus box outlines and flag poles)", m.lines > 18 * 5)
check("each has its hole number", table.concat(m.texts, ","):find("^1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18") ~= nil)
local far = newMap(10, nil)
ISWorldMap.renderStashMaps(far)
check("zoomed far out: no tees", far.polys == 0 and #far.texts == 0)
local hover = newMap(15, 11)
ISWorldMap.renderStashMaps(hover)
local tip = hover.texts[#hover.texts]
print("  tooltip: " .. tostring(tip))
check("pointing at a tee shows the hole, par and length", tip and tip:find("Hole 11", 1, true) and tip:find("Par 4", 1, true) and tip:find(" m", 1, true))
local flagHover = newMap(15, 7, true)
ISWorldMap.renderStashMaps(flagHover)
local tip2 = flagHover.texts[#flagHover.texts]
check("pointing at a flag names the same hole", tip2 and tip2:find("Hole 7", 1, true) ~= nil)
print(ok .. " passed, " .. bad .. " failed")
if bad > 0 then os.exit(1) end
