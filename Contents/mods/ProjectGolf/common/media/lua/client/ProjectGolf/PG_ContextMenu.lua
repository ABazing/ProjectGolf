-- Project Golf - right-click menus.
--   On a golf ball in the world:  Golf > Putt / Chip / Drive / Tips / Scorecard
--   On a golf ball in inventory:  Tee up golf ball (drops it just in front of you)

require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_World"
require "ProjectGolf/PG_StanceAction"
require "ProjectGolf/PG_Client"
require "ProjectGolf/PG_HoleAction"
require "ProjectGolf/PG_Viewpoint"
require "ProjectGolf/PG_Courses"
require "ProjectGolf/PG_Guide"

local PG = ProjectGolf
local W = PG.World
local try = W.try

-- How forgiving right-clicking a ball is.
PG.Menu = PG.Menu or {
    clickRadius    = 1.75,   -- squares around the click that are searched for a ball
    nearSelfRadius = 3,      -- clicking this close to yourself also finds a ball within reach
}

local function findClub(player)
    local hand = player:getPrimaryHandItem()
    if hand and hand:getFullType() == PG.Items.Club then return hand end
    return player:getInventory():getFirstTypeRecurse(PG.Items.Club)
end

local function addressShot(player, wo, shotId)
    if not wo or not try(wo, "getSquare") then return end
    if not PG.Shots[shotId] then
        PG.log("menu gave no valid shot:", tostring(shotId), "- using drive")
        shotId = "drive"
    end
    local club = findClub(player)
    if not club then return end
    local sq = wo:getSquare()

    -- walk next to the ball unless we are already there
    local bx, by = W.worldItemPos(wo)
    local dx, dy = player:getX() - bx, player:getY() - by
    if dx * dx + dy * dy > 1.2 * 1.2 or player:getZ() ~= sq:getZ() then
        if not luautils.walkAdj(player, sq, true) then return end
    end

    -- club in both hands
    if player:getPrimaryHandItem() ~= club then
        ISInventoryPaneContextMenu.equipWeapon(club, true, club:isTwoHandWeapon(), player:getPlayerNum())
    end

    ISTimedActionQueue.add(ISGolfStance:new(player, wo, shotId))
end

local function onGuide(player)
    PG.Guide.open(player)
end

-- Golf balls lying on a square.
local function ballsOn(sq, out)
    local wobjs = try(sq, "getWorldObjects")
    if not wobjs then return end
    for i = 0, wobjs:size() - 1 do
        local wo = wobjs:get(i)
        local item = try(wo, "getItem")
        if item and item:getFullType() == PG.Items.Ball then out[#out + 1] = wo end
    end
end

-- Balls near a point (x, y on storey z) within `radius` squares, nearest first.
local function ballsNear(x, y, z, radius)
    local found, near = {}, {}
    local r = math.ceil(radius)
    for iy = math.floor(y) - r, math.floor(y) + r do
        for ix = math.floor(x) - r, math.floor(x) + r do
            local sq = W.square(ix, iy, z)
            if sq then ballsOn(sq, found) end
        end
    end
    for _, wo in ipairs(found) do
        local bx, by = W.worldItemPos(wo)
        local d = math.sqrt((bx - x) ^ 2 + (by - y) ^ 2)
        if d <= radius then near[#near + 1] = { wo = wo, d = d } end
    end
    table.sort(near, function(a, b) return a.d < b.d end)
    local list = {}
    for i, n in ipairs(near) do list[i] = n.wo end
    return list
end

-- Where the player clicked: the mouse position on the ground in the isometric view, else the clicked square.
local function clickPoint(playerNum, worldobjects)
    local sq
    for _, obj in ipairs(worldobjects) do
        sq = try(obj, "getSquare")
        if sq then break end
    end
    if not sq then return nil end
    local x, y, z = sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ()
    if not PG.VP.state() and screenToIsoX then
        local ok, mx, my = pcall(function()
            return screenToIsoX(playerNum, getMouseX(), getMouseY(), z), screenToIsoY(playerNum, getMouseX(), getMouseY(), z)
        end)
        if ok and mx and my and math.abs(mx - x) < 3 and math.abs(my - y) < 3 then x, y = mx, my end
    end
    return x, y, z
end

-- Forgiving ball lookup: any ball within a couple of squares of the click, or, when clicking near yourself,
-- any ball within reach. The nearest one to the click wins.
local function ballsForClick(player, playerNum, worldobjects)
    local x, y, z = clickPoint(playerNum, worldobjects)
    if not x then return {} end
    local balls = ballsNear(x, y, z, PG.Menu.clickRadius)
    if #balls == 0 and math.floor(player:getZ()) == z then
        local px, py = player:getX(), player:getY()
        if (px - x) ^ 2 + (py - y) ^ 2 <= PG.Menu.nearSelfRadius ^ 2 then
            balls = ballsNear(px, py, z, PG.Gameplay.maxHitDistance)
        end
    end
    return balls
end

-- Logs and shows the names of everything on a square, so map golf tiles can be added to PG.MapHoles.
local function onInspectTile(player, sq)
    local lines = {}
    local holes = 0
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        local name, custom, group = W.spriteProps(o)
        local isHole = W.isMapHole(o)
        if isHole then holes = holes + 1 end
        lines[#lines + 1] = tostring(name) .. "  CustomName=" .. tostring(custom) .. "  GroupName=" .. tostring(group)
            .. (isHole and "  <- golf hole" or "")
    end
    PG.log("inspect " .. sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() .. ": " .. #lines .. " objects")
    for _, l in ipairs(lines) do PG.log("  " .. l) end
    PG.Client.halo(player, holes > 0 and "Golf hole here!" or ("No golf hole (" .. #lines .. " tiles, see console.txt)"))
end

local function onPlaceHole(player, sq) ISGolfHoleAction.queue(player, sq, "place") end
local function onRemoveHole(player, sq) ISGolfHoleAction.queue(player, sq, "remove") end

-- No ball on the square: place / pick up a golf hole, tee off, Tips / Scorecard (with a club), or inspect the tile.
-- "Inspect this tile" is a modder's tool: only when the game runs with -debug.
local function debugTools()
    return isDebugEnabled ~= nil and isDebugEnabled() == true
end

-- ---- teeing up on a course tee box: the ball goes down, then you step up to it with the right club ---------------
-- Club off the tee by par (anything not listed: drive). Change freely, e.g. [4] = "chip" for short par 4s.
PG.TeeClub = PG.TeeClub or { [3] = "chip" }

function PG.teeClubFor(hole)
    local club = hole and PG.TeeClub[hole.par] or "drive"
    return PG.Shots[club] and club or "drive"
end

-- After the drop action finishes, the ball turns up in the world: then address it. Gives up after 15 s.
PG.Menu.pendingTee = nil

local function addressWhenDown(player, item, sq, shot)
    PG.Menu.pendingTee = {
        player = player, id = item:getID(), x = sq:getX(), y = sq:getY(), z = sq:getZ(),
        shot = PG.Shots[shot] and shot or "drive", deadline = PG.now() + 15000,
    }
end

local function findBallById(x, y, z, id)
    for dy = -1, 1 do
        for dx = -1, 1 do
            local sq = W.square(x + dx, y + dy, z)
            local wobjs = sq and try(sq, "getWorldObjects")
            if wobjs then
                for i = 0, wobjs:size() - 1 do
                    local wo = wobjs:get(i)
                    local item = try(wo, "getItem")
                    if item and item:getID() == id then return wo end
                end
            end
        end
    end
    return nil
end

local function onTeeTick()
    local p = PG.Menu.pendingTee
    if not p then return end
    if PG.now() > p.deadline then PG.Menu.pendingTee = nil; return end
    local wo = findBallById(p.x, p.y, p.z, p.id)
    if wo then
        PG.Menu.pendingTee = nil
        addressShot(p.player, wo, p.shot)
    end
end
Events.OnTick.Add(onTeeTick)

-- Tee off: walk to the tee box of a course hole and put a ball down in the middle of it.
local function onTeeOff(player, hole)
    local ball = player:getInventory():getFirstTypeRecurse(PG.Items.Ball)
    if not ball or not hole.tee then return end
    local sq = W.square(hole.tee.x, hole.tee.y, 0)
    if not sq then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, ball)
    if not luautils.walkAdj(player, sq, true) then return end
    if ISDropWorldItemAction then
        ISTimedActionQueue.add(ISDropWorldItemAction:new(player, ball, sq, 0.5, 0.5, 0, 0, false))
    else
        ISInventoryPaneContextMenu.dropItem(ball, player:getPlayerNum())
    end
    if findClub(player) then addressWhenDown(player, ball, sq, PG.teeClubFor(hole)) end   -- then step up with the right club
    PG.Client.resetStrokes(player)      -- a new hole starts here
    PG.Client.setCurrentHole(player, hole)
    if hole.number == 1 then PG.Client.newScorecard(player, hole.course.id) end   -- and hole 1 starts a new round
    PG.Client.halo(player, PG.Courses.label(hole))
end

local function addSquareOptions(context, player, worldobjects)
    local sq = worldobjects[1] and try(worldobjects[1], "getSquare")
    if not sq then return end
    local inspect = debugTools() and findClub(player) ~= nil
    local flag = player:getInventory():getFirstTypeRecurse(PG.Items.Flag)
    local placed = W.removableHoleOn(sq)
    local teeHole = PG.Courses.teeAt(sq:getX() + 0.5, sq:getY() + 0.5)
    local hasBall = player:getInventory():getFirstTypeRecurse(PG.Items.Ball) ~= nil
    local teeOff = teeHole and hasBall
    local hasClub = findClub(player) ~= nil      -- a golfer can always open Tips / Scorecard
    if not inspect and not flag and not placed and not teeOff and not hasClub then return end

    local root = context:addOption("Golf", worldobjects, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)
    if placed then
        sub:addOption("Pick up golf hole", player, onRemoveHole, sq)
    elseif flag then
        local opt = sub:addOption("Place golf hole here", player, onPlaceHole, sq)
        local ok, why = W.canPlaceHole(sq)
        if not ok then
            opt.notAvailable = true
            local tip = ISWorldObjectContextMenu.addToolTip()
            tip.description = "Can't place a hole: " .. tostring(why) .. "."
            opt.toolTip = tip
        end
    end
    if teeOff then
        sub:addOption("Tee off: Hole " .. teeHole.number .. " (Par " .. teeHole.par .. ")", player, onTeeOff, teeHole)
    end
    if hasClub then sub:addOption("Tips / Scorecard", player, onGuide) end
    if inspect then sub:addOption("Inspect this tile", player, onInspectTile, sq) end
    return sub
end

local function onFillWorldObjectContextMenu(playerNum, context, worldobjects, test)
    local player = getSpecificPlayer(playerNum)
    if not player or player:getVehicle() then return end
    local balls = ballsForClick(player, playerNum, worldobjects)
    if #balls == 0 then
        -- no ball here: place / pick up a hole, or inspect the tile
        if not test then addSquareOptions(context, player, worldobjects) end
        return
    end
    if test then return true end

    local ball = balls[1]
    local root = context:addOption("Golf", worldobjects, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)

    local club = findClub(player)
    for _, id in ipairs(PG.ShotOrder) do
        local opt = sub:addOption(PG.Shots[id].label, player, addressShot, ball, id)
        if not club then
            opt.notAvailable = true
            local tip = ISWorldObjectContextMenu.addToolTip()
            tip.description = "You need a golf club."
            opt.toolTip = tip
        end
    end
    sub:addOption("Tips / Scorecard", player, onGuide)
    if debugTools() then sub:addOption("Inspect this tile", player, onInspectTile, ball:getSquare()) end
end
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)

-- ---- tee up from the inventory --------------------------------------------------------------------------------
local function onTeeUp(player, item)
    ISInventoryPaneContextMenu.transferIfNeeded(player, item)
    local dir = try(player, "getForwardDirection")
    local fx, fy = 0, 0
    if dir then fx, fy = dir:getX(), dir:getY() end
    local x, y, z = player:getX() + fx * 0.6, player:getY() + fy * 0.6, player:getZ()
    local sq = W.square(math.floor(x), math.floor(y), math.floor(z))
    local here = player:getCurrentSquare()
    if not sq or (here and try(here, "isBlockedTo", sq)) then
        sq, x, y = here, player:getX(), player:getY()
    end
    if not sq then return end
    local xo, yo = x - sq:getX(), y - sq:getY()
    if ISDropWorldItemAction then
        ISTimedActionQueue.add(ISDropWorldItemAction:new(player, item, sq, xo, yo, 0, 0, false))
    else
        ISInventoryPaneContextMenu.dropItem(item, player:getPlayerNum())
    end
    -- step up to it: on a course tee box with the club for that par, anywhere else with the putter (practice putting)
    if findClub(player) then
        local hole = PG.Courses.teeAt(x, y)
        if hole then PG.Client.setCurrentHole(player, hole) end
        addressWhenDown(player, item, sq, hole and PG.teeClubFor(hole) or "putt")
    end
end

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    for _, v in ipairs(items) do
        local item = v
        if type(v) == "table" and v.items then item = v.items[1] end
        if item and instanceof(item, "InventoryItem") and item:getFullType() == PG.Items.Ball then
            context:addOption("Tee up golf ball", player, onTeeUp, item)
            return
        end
    end
end
Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
