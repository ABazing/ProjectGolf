-- Project Golf - builds the courses into the world as their squares load:
--   * tee boxes: a circle of the hole's grass, tall grass and bushes cleared, regrowth stopped,
--     and two tee markers across the line to the cup;
--   * a cup on greens the map left without one (addCup).
-- Runs on the server (or in single player). Each square is done once per world (saved in the world's mod data),
-- so a tee marker someone picks up stays gone.

require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_World"
require "ProjectGolf/PG_Courses"

local PG = ProjectGolf
local W = PG.World
local C = PG.Courses
local try = W.try

PG.CourseBuilder = PG.CourseBuilder or {}
local B = PG.CourseBuilder

B.MARKER_ITEM = "ProjectGolf.TeeMarker"
B.DATA_KEY = "ProjectGolfing_Courses"   -- save key; keep as is (renaming it would rebuild tee boxes in existing saves)

-- ---- the work, by square ("x,y" -> { floor, markers = { {x, y} }, cup }) --------------------------------------
B.jobs = {}
local function job(x, y)
    local key = x .. "," .. y
    B.jobs[key] = B.jobs[key] or { markers = {} }
    return B.jobs[key]
end

for _, course in ipairs(C.list) do
    for _, hole in ipairs(course.holes) do
        if hole.addCup then job(hole.cup.x, hole.cup.y).cup = true end
        local tee = hole.tee
        if tee then
            local cx, cy = tee.x + 0.5, tee.y + 0.5
            local r = C.TEE_RADIUS
            for x = math.floor(cx - r), math.floor(cx + r) do
                for y = math.floor(cy - r), math.floor(cy + r) do
                    if (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2 <= r * r then job(x, y).floor = tee.floor end
                end
            end
            -- markers either side of the tee, across the line to the cup
            local ax, ay = hole.cup.x + 0.5 - cx, hole.cup.y + 0.5 - cy
            local len = math.sqrt(ax * ax + ay * ay)
            if len > 0 then
                local px, py = -ay / len * C.MARKER_GAP, ax / len * C.MARKER_GAP
                for _, side in ipairs({ -1, 1 }) do
                    local mx, my = cx + px * side, cy + py * side
                    table.insert(job(math.floor(mx), math.floor(my)).markers, { x = mx, y = my })
                end
            end
        end
    end
end

-- ---- square changes ----------------------------------------------------------------------------------------------
local function removeObject(sq, obj)
    if isServer() then try(sq, "transmitRemoveItemFromSquare", obj) end
    if try(obj, "getObjectIndex") ~= -1 then try(sq, "RemoveTileObject", obj) end
end

local function layTeeGrass(sq, floorName)
    local floor = try(sq, "getFloor")
    if floor and floorName then
        local spr = getSprite and getSprite(floorName)
        if spr then
            try(floor, "setSprite", spr)
            if isServer() then try(floor, "transmitUpdatedSpriteToClients") end
        end
    end
    -- mow it: tall grass, bushes and other removable plants go
    local objs = try(sq, "getObjects")
    if objs then
        for i = objs:size() - 1, 0, -1 do
            local o = objs:get(i)
            if o ~= floor then
                local props = try(o, "getProperties")
                if props and IsoFlagType and IsoFlagType.canBeRemoved and try(props, "has", IsoFlagType.canBeRemoved) then
                    removeObject(sq, o)
                end
            end
        end
    end
    -- and keep it mown
    try(sq, "disableErosion")
    if isServer() then
        pcall(sendServerCommand, "erosion", "disableForSquare", { x = sq:getX(), y = sq:getY(), z = sq:getZ() })
    end
end

local function addCup(sq)
    if W.mapHoleOn(sq) then return end
    local obj = IsoObject.new(sq:getCell(), sq, PG.HolePlacement.sprite)
    sq:AddTileObject(obj)
    if isServer() then try(obj, "transmitCompleteItemToClients") end
end

local function placeMarker(sq, m)
    local item = instanceItem and instanceItem(B.MARKER_ITEM)
    if not item then return end
    local ok = pcall(function() sq:AddWorldInventoryItem(item, m.x - sq:getX(), m.y - sq:getY(), 0, false) end)
    if not ok then pcall(function() sq:AddWorldInventoryItem(item, m.x - sq:getX(), m.y - sq:getY(), 0) end) end
    local wi = try(item, "getWorldItem")
    if wi then
        try(wi, "setIgnoreRemoveSandbox", true)     -- the world's item clean-up leaves tee markers alone
        if isServer() then try(wi, "transmitCompleteItemToClients") end
    end
end

-- ---- run once per square, as it loads ----------------------------------------------------------------------------
function B.build(sq)
    if not sq or sq:getZ() ~= 0 then return end
    local key = sq:getX() .. "," .. sq:getY()
    local work = B.jobs[key]
    if not work then return end
    local done = ModData.getOrCreate(B.DATA_KEY)
    if done[key] then return end
    if work.floor then layTeeGrass(sq, work.floor) end
    if work.cup then addCup(sq) end
    for _, m in ipairs(work.markers) do placeMarker(sq, m) end
    done[key] = true
end

local function onLoadGridsquare(sq)
    if isClient() then return end       -- the server builds; clients receive the changes
    pcall(B.build, sq)
end
Events.LoadGridsquare.Add(onLoadGridsquare)
