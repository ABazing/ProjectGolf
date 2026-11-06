-- Project Golf - client side: sending hits, playing back flights, sounds, stroke count and the ball camera.

require "ISUI/ISUIElement"
require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Net"
require "ProjectGolf/PG_World"
require "ProjectGolf/PG_Render"
require "ProjectGolf/PG_Viewpoint"
require "ProjectGolf/PG_Options"
require "ProjectGolf/PG_Courses"

local PG = ProjectGolf
local R = PG.Render
local W = PG.World
local try = W.try

PG.Sounds.overhit = PG.Sounds.overhit or "ProjectGolf_Overhit"   -- media/scripts/ProjectGolf_sounds.txt

PG.Client = PG.Client or {}
local C = PG.Client
C.flights = {}

-- ---- strokes ---------------------------------------------------------------------------------------------------
local function golfData(player)
    local md = player:getModData()
    md.ProjectGolf = md.ProjectGolf or { strokes = 0 }
    return md.ProjectGolf
end

function C.getStrokes(player) return golfData(player).strokes or 0 end
function C.resetStrokes(player) golfData(player).strokes = 0 end

-- ---- scorecards (West Maple, Wellington Heights) -----------------------------------------------------------------------
-- card = { holes = { [n] = { last = strokes, best = strokes } }, bestRound = strokes }
function C.getScorecard(player, courseId)
    local data = golfData(player)
    data.cards = data.cards or {}
    -- cards saved before the course was renamed (Louisville -> Wellington Heights) carry over
    if data.cards.Louisville and not data.cards.WellingtonHeights then
        data.cards.WellingtonHeights, data.cards.Louisville = data.cards.Louisville, nil
    end
    data.cards[courseId] = data.cards[courseId] or { holes = {} }
    data.cards[courseId].holes = data.cards[courseId].holes or {}
    return data.cards[courseId]
end

-- The course hole you're playing: set when you tee off (or tee up on a tee box), cleared when you hole out.
-- The aim screen sticks to it (PG.Courses.holeFor) so a dogleg doesn't switch you to a neighbouring hole.
function C.setCurrentHole(player, hole)
    local data = golfData(player)
    if hole and hole.course then
        data.hole = { course = hole.course.id, number = hole.number }
    else
        data.hole = nil
    end
end

function C.currentHole(player)
    local h = player and golfData(player).hole
    if type(h) ~= "table" then return nil end
    for _, course in ipairs(PG.Courses.list) do
        if course.id == h.course then return course.holes[h.number] end
    end
    return nil
end

-- A fresh card: clears this round's scores, keeps the bests.
function C.newScorecard(player, courseId)
    local card = C.getScorecard(player, courseId)
    for _, e in pairs(card.holes) do e.last = nil end
end

-- Hand corrections from the book's Edit mode. field = "last" (this round) or "best".
-- "+" on an empty box starts at par; "-" below 1 empties it again.
C.MAX_HOLE_SCORE = 20
function C.adjustScore(player, courseId, holeNumber, field, delta, par)
    local card = C.getScorecard(player, courseId)
    local e = card.holes[holeNumber] or {}
    card.holes[holeNumber] = e
    local v = e[field]
    if v == nil then
        if delta > 0 then v = par or 1 end
    else
        v = v + delta
        if v < 1 then v = nil elseif v > C.MAX_HOLE_SCORE then v = C.MAX_HOLE_SCORE end
    end
    e[field] = v
end

-- Best full round: "+" on none starts at the course's par; "-" below one stroke a hole clears it.
function C.adjustBestRound(player, courseId, delta, coursePar, holes)
    local card = C.getScorecard(player, courseId)
    local v = card.bestRound
    if v == nil then
        if delta > 0 then v = coursePar end
    else
        v = v + delta
        if v < (holes or 1) then v = nil end
    end
    card.bestRound = v
end

-- Writes a sunk course hole onto the card. A card with every hole filled is a full round.
function C.recordScore(player, hole, strokes)
    if not hole or not hole.course or not strokes or strokes < 1 then return end
    local card = C.getScorecard(player, hole.course.id)
    local e = card.holes[hole.number] or {}
    card.holes[hole.number] = e
    e.last = strokes
    if not e.best or strokes < e.best then e.best = strokes end
    local total = 0
    for i = 1, #hole.course.holes do
        local s = card.holes[i] and card.holes[i].last
        if not s then return end
        total = total + s
    end
    if not card.bestRound or total < card.bestRound then card.bestRound = total end
end

local function halo(player, text, r, g, b)
    if HaloTextHelper and HaloTextHelper.addText then
        local ok = pcall(HaloTextHelper.addText, player, text)
        if ok then return end
    end
    pcall(function() player:setHaloNote(text, (r or 1) * 255, (g or 1) * 255, (b or 1) * 255, 300) end)
end
C.halo = halo

-- ---- sending a hit ---------------------------------------------------------------------------------------------
function C.sendHit(stance)
    local player = stance.character
    local data = golfData(player)
    data.strokes = (data.strokes or 0) + 1
    PG.sendToServer(player, "Hit", {
        x = stance.ballSqX, y = stance.ballSqY, z = stance.ballZ,
        id = stance.ballId,
        shot = stance.shot,
        power = stance.swingPower,
        yaw = stance.yaw,
    })
end

-- ---- sounds ----------------------------------------------------------------------------------------------------
local function playAt(name, x, y, z, radius)
    if not name then return end
    local sq = W.square(math.floor(x), math.floor(y), z)
    local sm = getSoundManager and getSoundManager()
    if sq and sm then
        local ok = pcall(function() sm:PlayWorldSound(name, sq, 0, radius or 20, 1.0, false) end)
        if ok then return end
    end
    local player = getPlayer()
    if player then pcall(function() player:getEmitter():playSound(name) end) end
end

local eventSound = {
    bounce = "bounce", wall = "wall", tree = "tree", zombie = "wall",
    cup = "cup", splash = "splash", lipout = "bounce",
}

-- ---- flight playback -------------------------------------------------------------------------------------------
local function samplePath(f, t)
    local p = f.path
    local n = #p / 3
    local fi = t / f.sampleDt
    local i = math.floor(fi)
    if i >= n - 1 then
        return p[(n - 1) * 3 + 1], p[(n - 1) * 3 + 2], p[(n - 1) * 3 + 3], 0, 0
    end
    local k = fi - i
    local a, b = i * 3, (i + 1) * 3
    local x = p[a + 1] + (p[b + 1] - p[a + 1]) * k
    local y = p[a + 2] + (p[b + 2] - p[a + 2]) * k
    local z = p[a + 3] + (p[b + 3] - p[a + 3]) * k
    return x, y, z, (p[b + 1] - p[a + 1]) / f.sampleDt, (p[b + 2] - p[a + 2]) / f.sampleDt
end

local function isMine(by)
    local player = getPlayer()
    if not player then return false end
    if PG.isSinglePlayer() then return true end
    return (try(player, "getOnlineID") or 0) == by
end

function PG.ClientCommands.Flight(args)
    if type(args) ~= "table" or type(args.path) ~= "table" then return end
    -- the network turns arrays into tables with number keys; copy to plain arrays
    local path, evT, evK = {}, {}, {}
    for i = 1, #args.path do path[i] = args.path[i] end
    for i = 1, #(args.evT or {}) do evT[i] = args.evT[i]; evK[i] = args.evK[i] end

    local f = {
        path = path, sampleDt = args.sampleDt or (1 / 20), duration = args.duration or 0,
        evT = evT, evK = evK, nextEvent = 1,
        start = PG.now(), result = args.result, shot = args.shot, mine = isMine(args.by),
        x0 = args.x0, y0 = args.y0, z0 = args.z0, x1 = args.x1, y1 = args.y1, z1 = args.z1,
        cupX = args.cupX, cupY = args.cupY, cupZ = args.cupZ,
    }
    -- the hit (one of the random hits; the putt sound for putts), plus the overhit on top when swung past the red line
    playAt(PG.Sounds[args.shot == "putt" and "putt" or "drive"], args.x0, args.y0, args.z0, 25)
    if args.overhit then playAt(PG.Sounds.overhit, args.x0, args.y0, args.z0, 25) end

    PG.VP.clearReliefCache()
    C.nextFlightId = (C.nextFlightId or 0) + 1
    f.id = C.nextFlightId
    f.sent3D = PG.VP.ballFlight(f.id, path, f.sampleDt, args.z0) == true
    if f.mine and args.mishit then
        local player = getPlayer()
        if player then halo(player, args.shot == "drive" and "Shanked it!" or "Mishit!", 1, 0.4, 0.3) end
    end
    C.flights[#C.flights + 1] = f
    C.ensureOverlay()
end

-- short messages from the server (hole placed, can't place, ...)
function PG.ClientCommands.Notice(args)
    local player = getPlayer()
    if player and type(args) == "table" and args.text then halo(player, tostring(args.text)) end
end

local function finishFlight(f)
    if f.sent3D then PG.VP.ballStop(f.id) end
    if not f.mine then return end
    local player = getPlayer()
    if not player then return end
    local strokes = C.getStrokes(player)
    if f.result == "cup" then
        local hole = f.cupX and PG.Courses.holeAtCup(f.cupX, f.cupY, f.cupZ)
        local word
        if hole then
            -- a course hole: name the score against par (strokes count from Tee off)
            local name = PG.Courses.scoreName(strokes, hole.par)
            if strokes == 1 then name = "HOLE IN ONE! " .. name end
            C.recordScore(player, hole, strokes)
            C.setCurrentHole(player, nil)      -- holed out: the next tee decides the next hole
            word = name .. "!  Hole " .. hole.number .. " in " .. strokes .. " (par " .. hole.par .. ")"
        else
            word = strokes == 1 and "HOLE IN ONE!" or ("In the cup! " .. strokes .. " strokes")
        end
        halo(player, word, 0.3, 1, 0.3)
        C.resetStrokes(player)
    elseif f.result == "water" then
        golfData(player).strokes = strokes + 1
        halo(player, "Splash! Ball lost (+1 stroke)", 0.4, 0.6, 1)
    else
        local dx, dy = (f.x1 or 0) - (f.x0 or 0), (f.y1 or 0) - (f.y0 or 0)
        local dist = math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
        halo(player, dist .. " m  -  stroke " .. strokes, 1, 1, 1)
    end
end

-- ---- overlay: a 1x1 element at the screen origin that draws anywhere without eating clicks ------------------------
PG_FlightOverlay = ISUIElement:derive("PG_FlightOverlay")

function PG_FlightOverlay:prerender()
    if #C.flights == 0 then return end
    local now = PG.now()
    local vp = PG.VP.state()
    local playerNum = 0
    for i = #C.flights, 1, -1 do
        local f = C.flights[i]
        local t = (now - f.start) / 1000
        -- sounds for events we have reached
        while f.nextEvent <= #f.evT and f.evT[f.nextEvent] <= t do
            local kind = f.evK[f.nextEvent]
            local x, y, z = samplePath(f, f.evT[f.nextEvent])
            playAt(PG.Sounds[eventSound[kind] or "bounce"], x, y, math.floor(z), 15)
            f.nextEvent = f.nextEvent + 1
        end
        if t >= f.duration + 0.05 then
            table.remove(C.flights, i)
            finishFlight(f)
        else
            -- the 3D addon draws the ball itself in first / third person; 2D otherwise
            if not (f.sent3D and PG.VP.ball3D(vp)) then
                local x, y, z = samplePath(f, t)
                R.drawBall(self, playerNum, x, y, z, vp, 1, f.z0)
            end
        end
    end
end

function C.ensureOverlay()
    if C.overlay then return end
    local o = PG_FlightOverlay:new(0, 0, 1, 1)
    o:initialise()
    o:setAlwaysOnTop(true)
    o:addToUIManager()
    C.overlay = o
end

local function onServerCommand(module, command, args)
    if module ~= PG.MOD_ID then return end
    local handler = PG.ClientCommands[command]
    if handler then handler(args) end
end
Events.OnServerCommand.Add(onServerCommand)
