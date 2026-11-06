-- Project Golf - world adapter: turns the game's squares into the plain tables that PG_Physics reads.
-- Every game call is guarded, so a renamed method in a future build degrades the physics instead of erroring.

require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Sandbox"

local PG = ProjectGolf
PG.World = PG.World or {}
local W = PG.World

local function try(obj, method, ...)
    if not obj then return nil end
    local f = obj[method]
    if not f then return nil end
    local ok, res = pcall(f, obj, ...)
    if ok then return res end
    return nil
end
W.try = try

local function square(ix, iy, iz)
    local cell = getCell and getCell()
    if not cell then return nil end
    return cell:getGridSquare(ix, iy, iz)
end
W.square = square

-- Tile flags. B42 reads them with getProperties():has(flag) (as vanilla fishing does); older builds used Is().
local function hasFlag(sq, flagName)
    if not sq or not IsoFlagType or not IsoFlagType[flagName] then return false end
    local flag = IsoFlagType[flagName]
    local props = try(sq, "getProperties")
    if props then
        local v = try(props, "has", flag)
        if v ~= nil then return v == true end
        v = try(props, "Is", flag)
        if v ~= nil then return v == true end
    end
    return try(sq, "Is", flag) == true
end
W.hasFlag = hasFlag

local function spriteName(obj)
    local spr = try(obj, "getSprite")
    return spr and try(spr, "getName") or nil
end

-- Lakes and rivers: the water flag, or a natural water floor (vanilla treats blends_natural_02 as lake/river).
local function isWater(sq)
    if hasFlag(sq, "water") then return true end
    local name = spriteName(try(sq, "getFloor"))
    return name ~= nil and name:sub(1, 17) == "blends_natural_02"
end
W.isWater = isWater

local function surfaceOf(sq)
    local name = spriteName(try(sq, "getFloor")) or ""
    local surface = "default"
    if name:find("street") or name:find("blends_street") then
        surface = "road"
    elseif name:find("floors_interior") or name:find("carpentry") or name:find("floors_burnt") then
        surface = "floor"
    elseif name:find("blends_natural") then
        surface = "grass"
    elseif name:find("floors_exterior") then
        surface = "road"
    end
    -- tall grass / bushes on top of the floor make it rough
    local objs = try(sq, "getObjects")
    if objs then
        for i = 0, objs:size() - 1 do
            local n = spriteName(objs:get(i))
            if n and (n:find("e_newgrass") or n:find("vegetation_foliage") or n:find("f_bushes")) then
                return "rough"
            end
        end
    end
    return surface
end

-- ---------------------------------------------------------------------------------------------------------------
-- Golf holes that are part of the map (golf course flag / hole tiles).
-- Exact sprite names can go in `sprites`; anything whose sprite name or tile properties contain one of the
-- `patterns` also counts. Use "Golf > Inspect this tile" in game to see a tile's names.
-- ---------------------------------------------------------------------------------------------------------------
PG.MapHoles = PG.MapHoles or {
    sprites  = {                   -- exact map tile names (found with "Golf > Inspect this tile")
        ["recreational_sports_01_48"] = true,   -- golf course hole (Riverside course, 6135,6149)
    },
    patterns = { "golf" },         -- lower-case substrings of sprite name, CustomName or GroupName
    ignore   = {},                 -- sprite names that match a pattern but are not holes
    offsetX  = 0.5,                -- cup position inside the square
    offsetY  = 0.5,
}

local holeCache = {}   -- sprite name -> true / false

-- Crafted holes: the "Golf Hole" item is placed as the course hole tile. Only tiles the mod placed (marked in
-- their mod data) can be picked up again, so the map's own course holes stay where they are.
PG.HolePlacement = PG.HolePlacement or {
    sprite              = "recreational_sports_01_48",
    allowPickupMapHoles = false,   -- true: players can also pick up the map's course holes
    actionTicks         = 120,     -- how long placing / removing takes
}

local function spriteProps(obj)
    local spr = try(obj, "getSprite")
    local props = spr and try(spr, "getProperties")
    local custom = props and try(props, "Val", "CustomName") or nil
    local group = props and try(props, "Val", "GroupName") or nil
    return spr and try(spr, "getName") or nil, custom, group
end
W.spriteProps = spriteProps

function W.isMapHole(obj)
    -- dropped items (the ball itself, a club) are never map tiles
    if instanceof and instanceof(obj, "IsoWorldInventoryObject") then return false end
    local name, custom, group = spriteProps(obj)
    if not name then return false end
    local cached = holeCache[name]
    if cached ~= nil then return cached end
    local cfg = PG.MapHoles
    local hit = cfg.sprites[name] == true
    if not hit and not cfg.ignore[name] then
        local hay = (name .. " " .. tostring(custom or "") .. " " .. tostring(group or "")):lower()
        for _, p in ipairs(cfg.patterns) do
            if hay:find(p, 1, true) then hit = true; break end
        end
    end
    holeCache[name] = hit
    return hit
end

function W.mapHoleOn(sq)
    local objs = try(sq, "getObjects")
    if not objs then return false end
    for i = 0, objs:size() - 1 do
        if W.isMapHole(objs:get(i)) then return true end
    end
    return false
end

local function hasTree(sq)
    if try(sq, "getTree") then return true end
    local objs = try(sq, "getObjects")
    if objs and instanceof then
        for i = 0, objs:size() - 1 do
            if instanceof(objs:get(i), "IsoTree") then return true end
        end
    end
    return false
end

-- info(ix, iy, iz) -> nil when the square is not loaded
function W.info(ix, iy, iz)
    local sq = square(ix, iy, iz)
    if not sq then
        -- Outdoors at ground level a missing square is still open ground the game just has not created; above
        -- ground it means "no floor".
        if iz > 0 and square(ix, iy, 0) then
            return { floor = false, surface = "default" }
        end
        return nil
    end
    local floorOk = iz == 0 or try(sq, "TreatAsSolidFloor") == true or try(sq, "getFloor") ~= nil
    return {
        floor   = floorOk,
        water   = isWater(sq),
        tree    = hasTree(sq),
        solid   = (hasFlag(sq, "solid") or hasFlag(sq, "solidtrans")) and not W.mapHoleOn(sq),
        surface = surfaceOf(sq),
    }
end

-- blocked(ax, ay, bx, by, z) -> nil | "wall" | "fence"  (a and b are adjacent along one axis)
function W.blocked(ax, ay, bx, by, z)
    local a, b = square(ax, ay, z), square(bx, by, z)
    if not a or not b then
        if z == 0 and a and not b then return nil end
        return "wall"
    end
    local isBlocked = try(a, "isBlockedTo", b)
    if isBlocked == nil then
        isBlocked = try(a, "testCollideAdjacent", nil, bx - ax, by - ay, 0)
    end
    if not isBlocked then return nil end
    -- which square carries the edge between a and b?
    local low
    if bx > ax then low = hasFlag(b, "HoppableW")
    elseif bx < ax then low = hasFlag(a, "HoppableW")
    elseif by > ay then low = hasFlag(b, "HoppableN")
    else low = hasFlag(a, "HoppableN") end
    return low and "fence" or "wall"
end

function W.zombies(ix, iy, iz)
    local list = {}
    local sq = square(ix, iy, iz)
    local movers = try(sq, "getMovingObjects")
    if not movers then return list end
    for i = 0, movers:size() - 1 do
        local o = movers:get(i)
        if instanceof(o, "IsoZombie") and not try(o, "isDead") then
            list[#list + 1] = { x = o:getX(), y = o:getY(), id = try(o, "getOnlineID") or i }
        end
    end
    return list
end

-- Position of a world item, inside its square.
function W.worldItemPos(wo)
    local px, py = try(wo, "getWorldPosX"), try(wo, "getWorldPosY")
    if px and py then return px, py end
    local sq = try(wo, "getSquare")
    local xo, yo = try(wo, "getXoff") or 0.5, try(wo, "getYoff") or 0.5
    return sq:getX() + xo, sq:getY() + yo
end

function W.cups(ix, iy, iz)
    local list = {}
    local sq = square(ix, iy, iz)
    local wobjs = try(sq, "getWorldObjects")
    if not wobjs then return list end
    for i = 0, wobjs:size() - 1 do
        local wo = wobjs:get(i)
        local item = try(wo, "getItem")
        if item and item:getFullType() == PG.Items.Flag then
            local x, y = W.worldItemPos(wo)
            list[#list + 1] = { x = x, y = y }
        end
    end
    if #list == 0 and W.mapHoleOn(sq) then
        list[1] = { x = ix + PG.MapHoles.offsetX, y = iy + PG.MapHoles.offsetY, map = true }
    end
    return list
end

-- Finds the nearest hole within a circle of `radius` squares, a few rows at a time, so a large radius does not
-- stall a frame:  local scan = W.holeScanner(x, y, z, r);  each frame: if scan:step(rows) then use scan.best, scan.dist
function W.holeScanner(x, y, z, radius)
    local s = { x = x, y = y, z = z, r = radius, row = -radius, done = false, best = nil, dist = nil }
    local cx, cy = math.floor(x), math.floor(y)
    local r2 = (radius + 1) * (radius + 1)
    local bestD2
    function s:step(rows)
        if self.done then return true end
        local last = math.min(self.row + rows - 1, self.r)
        for dy = self.row, last do
            local span = math.floor(math.sqrt(math.max(0, r2 - dy * dy)))
            local iy = cy + dy
            for ix = cx - span, cx + span do
                if square(ix, iy, self.z) then
                    for _, c in ipairs(W.cups(ix, iy, self.z)) do
                        local ddx, ddy = c.x - self.x, c.y - self.y
                        local d2 = ddx * ddx + ddy * ddy
                        if d2 > 0.01 and d2 <= self.r * self.r and (not bestD2 or d2 < bestD2) then
                            self.best, bestD2 = c, d2
                        end
                    end
                end
            end
        end
        self.row = last + 1
        if self.row > self.r then
            self.done = true
            self.dist = bestD2 and math.sqrt(bestD2) or nil
        end
        return self.done
    end
    return s
end


-- Was this tile placed by Project Golf?
function W.isPlacedHole(o)
    if instanceof and instanceof(o, "IsoWorldInventoryObject") then return false end
    if try(o, "hasModData") == false then return false end
    local md = try(o, "getModData")
    return md ~= nil and md.ProjectGolfHole == true
end

-- The hole tile on a square that may be picked up, if any.
function W.removableHoleOn(sq)
    local objs = try(sq, "getObjects")
    if not objs then return nil end
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if W.isPlacedHole(o) or (PG.HolePlacement.allowPickupMapHoles and W.isMapHole(o)) then return o end
    end
    return nil
end

-- Can a hole be placed here? Returns ok, reason.
function W.canPlaceHole(sq)
    if not sq then return false, "nothing here" end
    if W.mapHoleOn(sq) then return false, "there is already a hole here" end
    if isWater(sq) then return false, "it would fill with water" end
    if hasFlag(sq, "solid") or hasFlag(sq, "solidtrans") then return false, "something is in the way" end
    if sq:getZ() > 0 and not (try(sq, "TreatAsSolidFloor") or try(sq, "getFloor")) then return false, "no floor" end
    if not try(sq, "getFloor") then return false, "no ground" end
    return true
end

-- Find a golf ball world item on a square (by item id if given).
function W.findBall(sq, itemId)
    local wobjs = try(sq, "getWorldObjects")
    if not wobjs then return nil end
    local fallback
    for i = 0, wobjs:size() - 1 do
        local wo = wobjs:get(i)
        local item = try(wo, "getItem")
        if item and item:getFullType() == PG.Items.Ball then
            if not itemId or item:getID() == itemId then return wo end
            fallback = fallback or wo
        end
    end
    return fallback
end

-- The adapter table that PG.simulate expects.
PG.GameWorld = {
    info    = W.info,
    blocked = W.blocked,
    zombies = W.zombies,
    cups    = W.cups,
}
