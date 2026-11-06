-- Project Golf - the golf courses of the vanilla map that track par and score (West Maple; Wellington Heights is parked, see enabled = false).
-- The mini golf's cups still work as ordinary holes; it is not tracked.
--
-- Cup positions were checked against the map files (media/maps/Muldraugh, KY): every cup listed without addCup
-- exists in the map.
--
--   cup  = { x, y, z }                 the hole (a map tile, or added by the course builder when addCup = true)
--   tee  = { x, y, floor }             centre of the tee box and the grass sprite it is laid with
--   par                                strokes for the hole
--   bounds = { x1, y1, x2, y2 }        area of the course, for knowing which course a ball is on

require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_CoursePar"

local PG = ProjectGolf

PG.Courses = PG.Courses or {}
local C = PG.Courses

C.TEE_RADIUS = 2.5     -- tee box radius (squares)
C.MARKER_GAP = 2.0     -- each tee marker this far from the centre, across the line to the cup

C.list = {
    {
        id = "WestMaple",
        name = "West Maple Country Club",
        short = "West Maple",
        bounds = { 5799, 6024, 6366, 6696 },
        holes = {
            { cup = { x = 5944, y = 6598, z = 0 }, par = 5, tee = { x = 5839, y = 6427, floor = "blends_natural_01_16" } },
            { cup = { x = 6148, y = 6588, z = 0 }, par = 5, tee = { x = 5987, y = 6607, floor = "blends_natural_01_16" } },
            { cup = { x = 6301, y = 6656, z = 0 }, par = 4, addCup = true, tee = { x = 6158, y = 6605, floor = "blends_natural_01_16" } },
            { cup = { x = 6186, y = 6514, z = 0 }, par = 5, tee = { x = 6325, y = 6582, floor = "blends_natural_01_22" } },
            { cup = { x = 6088, y = 6393, z = 0 }, par = 4, tee = { x = 6145, y = 6495, floor = "blends_natural_01_16" } },
            { cup = { x = 6285, y = 6454, z = 0 }, par = 5, tee = { x = 6105, y = 6387, floor = "blends_natural_01_22" } },
            { cup = { x = 6314, y = 6323, z = 0 }, par = 4, addCup = true, tee = { x = 6326, y = 6466, floor = "blends_natural_01_21" } },
            { cup = { x = 6133, y = 6288, z = 0 }, par = 4, addCup = true, tee = { x = 6279, y = 6330, floor = "blends_natural_01_23" } },
            { cup = { x = 6058, y = 6192, z = 0 }, par = 4, tee = { x = 6166, y = 6274, floor = "blends_natural_01_16" } },
            { cup = { x = 6182, y = 6201, z = 0 }, par = 3, tee = { x = 6080, y = 6172, floor = "blends_natural_01_23" } },
            { cup = { x = 6277, y = 6265, z = 0 }, par = 3, tee = { x = 6199, y = 6238, floor = "blends_natural_01_21" } },
            { cup = { x = 6278, y = 6148, z = 0 }, par = 4, tee = { x = 6302, y = 6271, floor = "blends_natural_01_21" } },
            { cup = { x = 6135, y = 6149, z = 0 }, par = 4, tee = { x = 6247, y = 6155, floor = "blends_natural_01_16" } },
            { cup = { x = 5997, y = 6203, z = 0 }, par = 4, tee = { x = 6127, y = 6125, floor = "blends_natural_01_21" } },
            { cup = { x = 5969, y = 6064, z = 0 }, par = 4, tee = { x = 5968, y = 6217, floor = "blends_natural_01_22" } },
            { cup = { x = 5876, y = 6206, z = 0 }, par = 4, tee = { x = 5938, y = 6071, floor = "blends_natural_01_23" } },
            { cup = { x = 6009, y = 6366, z = 0 }, par = 4, addCup = true, tee = { x = 5911, y = 6272, floor = "blends_natural_01_23" } },
            { cup = { x = 5862, y = 6366, z = 0 }, par = 4, tee = { x = 6001, y = 6404, floor = "blends_natural_01_21" } },
        },
    },
    {
        id = "WellingtonHeights",
        enabled = false,   -- parked for now: not tracked, no scorecard, no tee boxes. Set true to bring it back.
        name = "Wellington Heights Golf Club",
        short = "Wellington Heights",
        bounds = { 12989, 2224, 13324, 2424 },
        holes = {
            { cup = { x = 13029, y = 2301, z = 0 }, par = 3, tee = { x = 13016, y = 2275, floor = "blends_natural_01_32" } },
            { cup = { x = 13092, y = 2264, z = 0 }, par = 3, tee = { x = 13043, y = 2304, floor = "blends_natural_01_22" } },
            { cup = { x = 13119, y = 2265, z = 0 }, par = 3, tee = { x = 13102, y = 2266, floor = "blends_natural_01_38" } },
            { cup = { x = 13147, y = 2323, z = 0 }, par = 3, tee = { x = 13132, y = 2270, floor = "blends_natural_01_22" } },
            { cup = { x = 13099, y = 2384, z = 0 }, par = 3, tee = { x = 13141, y = 2331, floor = "blends_natural_01_23" } },
            { cup = { x = 13149, y = 2347, z = 0 }, par = 3, tee = { x = 13110, y = 2376, floor = "blends_natural_01_22" } },
            { cup = { x = 13249, y = 2340, z = 0 }, par = 3, tee = { x = 13156, y = 2343, floor = "blends_natural_01_16" } },
            { cup = { x = 13284, y = 2325, z = 0 }, par = 3, tee = { x = 13261, y = 2332, floor = "blends_natural_01_16" } },
            { cup = { x = 13256, y = 2289, z = 0 }, par = 3, tee = { x = 13270, y = 2322, floor = "blends_natural_01_16" } },
        },
    },
}

-- Only enabled courses are tracked (score, scorecard, tee boxes, hole on the aim screen); the rest wait in C.parked.
do
    local active, parked = {}, {}
    for _, course in ipairs(C.list) do
        if course.enabled == false then parked[#parked + 1] = course else active[#active + 1] = course end
    end
    C.list, C.parked = active, parked
end

-- number each hole, point back at its course, and take its par from PG_CoursePar.lua
for _, course in ipairs(C.list) do
    local pars = PG.CoursePar and PG.CoursePar[course.id] or {}
    for i, hole in ipairs(course.holes) do
        hole.number = i
        hole.course = course
        if tonumber(pars[i]) then hole.par = tonumber(pars[i]) end
    end
end

-- The course hole whose cup is on square x, y, z (or nil).
function C.holeAtCup(x, y, z)
    local ix, iy, iz = math.floor(x), math.floor(y), math.floor(z or 0)
    for _, course in ipairs(C.list) do
        for _, hole in ipairs(course.holes) do
            if hole.cup.x == ix and hole.cup.y == iy and (hole.cup.z or 0) == iz then return hole end
        end
    end
    return nil
end

-- Golf's name for a score against par.
function C.scoreName(strokes, par)
    local d = strokes - par
    if d <= -4 then return "Condor" end
    if d == -3 then return "Albatross" end
    if d == -2 then return "Eagle" end
    if d == -1 then return "Birdie" end
    if d == 0 then return "Par" end
    if d == 1 then return "Bogey" end
    if d == 2 then return "Double bogey" end
    if d == 3 then return "Triple bogey" end
    return "+" .. d
end

-- The course whose bounds contain x, y (or nil).
function C.courseAt(x, y)
    for _, course in ipairs(C.list) do
        local b = course.bounds
        if x >= b[1] and x <= b[3] and y >= b[2] and y <= b[4] then return course end
    end
    return nil
end

local function centre(p) return p.x + 0.5, p.y + 0.5 end

-- Distance from point (px, py) to the segment a-b.
local function segmentDistance(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local len2 = dx * dx + dy * dy
    local t = len2 > 0 and PG.clamp(((px - ax) * dx + (py - ay) * dy) / len2, 0, 1) or 0
    local qx, qy = ax + dx * t, ay + dy * t
    return math.sqrt((px - qx) ^ 2 + (py - qy) ^ 2)
end

-- The hole you teed off on stays your hole while the ball is within this reach of its cup: the hole's own length
-- times KEEP_FACTOR, and never less than KEEP_MIN squares. (Doglegs and wild shots leave the straight tee-to-cup
-- line, where another hole's line can run closer: hole 11's ball south of the line used to read as hole 8.)
C.KEEP_FACTOR = 1.5
C.KEEP_MIN = 40

-- The hole a ball at (x, y, z) is being played on. `current` (optional) is the hole you teed off on: it wins while
-- the ball is on its course and within reach of its cup. Otherwise: the course's hole whose tee-to-cup line passes
-- closest. Returns hole (with .number, .par, .course, .cup) or nil when not on a course.
function C.holeFor(x, y, z, current)
    local course = C.courseAt(x, y)
    if not course then return nil end
    if current and current.course == course and (current.cup.z or 0) == (z or 0) then
        local cx, cy = centre(current.cup)
        local len = 0
        if current.tee then
            local tx, ty = centre(current.tee)
            len = math.sqrt((cx - tx) ^ 2 + (cy - ty) ^ 2)
        end
        local reach = math.max(C.KEEP_MIN, len * C.KEEP_FACTOR)
        if (x - cx) ^ 2 + (y - cy) ^ 2 <= reach * reach then return current end
    end
    local best, bestD
    for _, hole in ipairs(course.holes) do
        if (hole.cup.z or 0) == (z or 0) then
            local cx, cy = centre(hole.cup)
            local d
            if hole.tee then
                local tx, ty = centre(hole.tee)
                d = segmentDistance(x, y, tx, ty, cx, cy)
            else
                d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
            end
            if not bestD or d < bestD then best, bestD = hole, d end
        end
    end
    return best
end

-- The tee box (hole) whose box contains x, y, if any.
function C.teeAt(x, y)
    local course = C.courseAt(x, y)
    if not course then return nil end
    local r = C.TEE_RADIUS + 0.5
    for _, hole in ipairs(course.holes) do
        if hole.tee then
            local tx, ty = centre(hole.tee)
            if (x - tx) ^ 2 + (y - ty) ^ 2 <= r * r then return hole end
        end
    end
    return nil
end

-- "West Maple Country Club - Hole 4 - Par 4"
function C.label(hole)
    return hole.course.name .. "  -  Hole " .. hole.number .. "  -  Par " .. hole.par
end
