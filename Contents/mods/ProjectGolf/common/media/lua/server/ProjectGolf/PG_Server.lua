-- Project Golf - server authority.
-- The server validates each hit, removes the ball, runs the physics once, tells every client the flight path,
-- and puts the ball back in the world when the flight ends. In single player this same code runs locally.

require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Physics"
require "ProjectGolf/PG_World"
require "ProjectGolf/PG_Net"
require "ProjectGolf/PG_Sandbox"
require "ProjectGolf/PG_Skill"

local PG = ProjectGolf
local W = PG.World
local try = W.try

PG.Server = PG.Server or {}
local S = PG.Server

S.AIMING_XP = 1    -- Aiming XP per chip or drive (half for a putt, +2x this for sinking it)
S.lastHit = {}     -- player key -> timestamp
S.pending = {}     -- balls in flight: { due, item, x, y, z, result }

local function playerKey(player)
    return tostring(try(player, "getUsername") or try(player, "getOnlineID") or "local")
end

-- -------------------------------------------------------------------------------------------------------------
-- World item helpers
-- -------------------------------------------------------------------------------------------------------------
function S.removeWorldItem(wo)
    local item = try(wo, "getItem")
    local sq = try(wo, "getSquare")
    if sq then try(sq, "transmitRemoveItemFromSquare", wo) end
    try(wo, "removeFromWorld")
    try(wo, "removeFromSquare")
    try(wo, "setSquare", nil)
    if item then try(item, "setWorldItem", nil) end
    return item
end

function S.placeWorldItem(item, x, y, z)
    local ix, iy = math.floor(x), math.floor(y)
    local sq = W.square(ix, iy, z)
    if not sq then
        local cell = getCell()
        sq = cell and try(cell, "getOrCreateGridSquare", ix, iy, z)
    end
    if not sq then
        PG.log("no square to place the ball at", ix, iy, z)
        return false
    end
    local xo, yo = PG.clamp(x - ix, 0.02, 0.98), PG.clamp(y - iy, 0.02, 0.98)
    -- B42 has an overload with a "transmit" flag; older builds transmit separately.
    local ok = pcall(function() sq:AddWorldInventoryItem(item, xo, yo, 0, true) end)
    if not ok then
        ok = pcall(function() sq:AddWorldInventoryItem(item, xo, yo, 0) end)
        if ok and isServer() then
            local wi = try(item, "getWorldItem")
            if wi then try(wi, "transmitCompleteItemToClients") end
        end
    end
    if not ok then PG.log("AddWorldInventoryItem failed at", ix, iy, z) end
    return ok
end

-- -------------------------------------------------------------------------------------------------------------
-- Ball names: the ball you hit becomes "<your first name>'s golf ball", so when two people play it's clear whose
-- ball is lying where (hover it, right-click it, or pick it up). Whoever hits it next makes it theirs.
-- -------------------------------------------------------------------------------------------------------------
-- The golfer's first name: the character's forename, else the first word of the account name.
function S.ownerName(player)
    local desc = try(player, "getDescriptor")
    local name = desc and try(desc, "getForename")
    if type(name) ~= "string" or name == "" then name = try(player, "getUsername") end
    if type(name) ~= "string" or name == "" then return nil end
    return name:match("^%s*(%S+)") or name
end

function S.ballName(name) return tostring(name) .. "'s golf ball" end

-- Names a golf ball item after its owner (a first name). Also used by golf partner mods.
function S.nameBall(item, name)
    if not item or type(name) ~= "string" or name == "" then return false end
    try(item, "setName", S.ballName(name))
    try(item, "setCustomName", true)          -- keeps the name through saves
    return true
end

-- -------------------------------------------------------------------------------------------------------------
-- Accuracy: how far off the aim the ball goes (degrees, 1 sd)
-- -------------------------------------------------------------------------------------------------------------
local function statValue(stats, legacyGetter, enumName)
    local v = try(stats, legacyGetter)
    if v == nil and CharacterStat and CharacterStat[enumName] then
        v = try(stats, "get", CharacterStat[enumName])
    end
    return tonumber(v) or 0
end

-- Overswing (power past PG.Gameplay.overswingAt): the further over, the wider the spread and the bigger the chance
-- of a mishit, where the ball comes off weak and sliced or hooked.
PG.Overswing = PG.Overswing or {
    spreadMin  = 3,     -- extra degrees of spread just past the line
    spreadMax  = 12,    -- ... at 100% power
    mishitMin  = 0.15,  -- mishit chance just past the line
    mishitMax  = 0.60,  -- ... at 100% power
    mishitPowerMin = 0.45, mishitPowerMax = 0.75,   -- power kept on a mishit
    mishitAngleMin = 8,    mishitAngleMax = 25,     -- degrees it veers off
}

-- 0 below the overswing line, rising to 1 at full power.
function S.overswingAmount(power)
    local at = PG.Gameplay.overswingAt
    if power <= at then return 0 end
    return PG.clamp((power - at) / math.max(1 - at, 0.001), 0, 1)
end

function S.spreadFor(player, shot, power)
    local spread = shot.accuracyDeg
    local o = S.overswingAmount(power)
    if o > 0 then
        local ov = PG.Overswing
        spread = spread + ov.spreadMin + (ov.spreadMax - ov.spreadMin) * o
    end
    -- Aiming skill: about 1.5x at level 0, 1x at 5, 0.5x at 10 (panic, drink and tiredness still add on top)
    spread = spread * PG.Skill.spreadMult(PG.Skill.level(player))
    local stats = try(player, "getStats")
    if stats then
        local panic = statValue(stats, "getPanic", "PANIC")                 -- 0..100
        local drunk = statValue(stats, "getDrunkenness", "INTOXICATION")    -- 0..100
        local endurance = statValue(stats, "getEndurance", "ENDURANCE")     -- 0..1
        if panic > 1 then panic = panic / 100 end
        if drunk > 1 then drunk = drunk / 100 end
        spread = spread + panic * 3 + drunk * 6 + math.max(0, 0.6 - endurance) * 4
    end
    return spread
end

-- -------------------------------------------------------------------------------------------------------------
-- Golf lifts your mood. Points out of 100 (scaled to each stat's real maximum); negative = less boredom / sadness.
-- Applied here, on the server, like vanilla's leisure actions; single player runs the same code.
-- -------------------------------------------------------------------------------------------------------------
PG.Mood = PG.Mood or {
    enabled = true,
    shot   = { boredom = -3, unhappiness = -1 },   -- every swing
    sunk   = { boredom = -8, unhappiness = -6 },   -- extra when the ball drops in
    splash = { boredom = 0,  unhappiness = 2 },    -- lost in the water: annoying
}

local function adjustStat(stats, statName, points)
    if points == 0 or not CharacterStat or not CharacterStat[statName] then return end
    local stat = CharacterStat[statName]
    local max = tonumber(try(stat, "getMaximumValue")) or 100
    local min = tonumber(try(stat, "getMinimumValue")) or 0
    local cur = tonumber(try(stats, "get", stat))
    if not cur then return end
    local value = PG.clamp(cur + points / 100 * (max - min), min, max)
    try(stats, "set", stat, value)
end

function S.adjustMood(player, change)
    if not PG.Mood.enabled or not change or not PG.sandbox("MoodBoost", true) then return end
    local stats = try(player, "getStats")
    if not stats then return end
    adjustStat(stats, "BOREDOM", change.boredom or 0)
    adjustStat(stats, "UNHAPPINESS", change.unhappiness or 0)
end

-- -------------------------------------------------------------------------------------------------------------
-- Commands
-- -------------------------------------------------------------------------------------------------------------
function PG.ServerCommands.Hit(player, args)
    if type(args) ~= "table" then return end
    local shotId = args.shot
    local shot = PG.Shots[shotId]
    local power, yaw = tonumber(args.power), tonumber(args.yaw)
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not shot or not power or not yaw or not x or not y or not z then return end
    if power ~= power or yaw ~= yaw then return end   -- NaN
    power = PG.clamp(power, 0, 1)

    -- rate limit
    local key = playerKey(player)
    local now = PG.now()
    if S.lastHit[key] and now - S.lastHit[key] < PG.Gameplay.hitCooldownMs then return end

    -- the club must be in the player's hands
    local hand = try(player, "getPrimaryHandItem")
    if not hand or hand:getFullType() ~= PG.Items.Club then return end

    local sq = W.square(x, y, z)
    local wo = sq and W.findBall(sq, args.id)
    if not wo then return end

    local bx, by = W.worldItemPos(wo)
    local dx, dy = player:getX() - bx, player:getY() - by
    if dx * dx + dy * dy > PG.Gameplay.maxHitDistance * PG.Gameplay.maxHitDistance then return end
    S.lastHit[key] = now

    local seed = ZombRand and ZombRand(1, 2000000000) or now
    local rng = PG.newRng(seed)
    local deviation = rng:gauss() * S.spreadFor(player, shot, power)

    -- overswing can mishit: weak, and well off line
    local mishit = false
    local o = S.overswingAmount(power)
    local overswung = o > 0          -- past the red line: the client plays the overhit sound
    if o > 0 and shotId ~= "putt" then
        local ov = PG.Overswing
        local chance = (ov.mishitMin + (ov.mishitMax - ov.mishitMin) * o) * PG.Skill.mishitMult(PG.Skill.level(player))
        if rng:next() < chance then
            mishit = true
            power = power * rng:range(ov.mishitPowerMin, ov.mishitPowerMax)
            local veer = rng:range(ov.mishitAngleMin, ov.mishitAngleMax)
            deviation = deviation + (rng:next() < 0.5 and -veer or veer)
        end
    end

    local item = S.removeWorldItem(wo)
    if not item then return end
    S.nameBall(item, S.ownerName(player))      -- your ball now: it lands as "<name>'s golf ball"

    local sim = PG.simulate({
        x = bx, y = by, z = z,
        shot = shotId, power = power, yaw = yaw + deviation, seed = seed,
        distanceMult = PG.distanceMult(player, shotId),
    }, PG.GameWorld)

    -- golf trains Aiming a little: full amount for chips and drives, half for putts, double bonus for sinking it
    if PG.sandbox("AimingXP", true) then
        local amount = S.AIMING_XP
        local xp = (shotId == "putt" and amount * 0.5 or amount) + (sim.result == "cup" and amount * 2 or 0)
        if xp > 0 and Perks and Perks.Aiming then
            if addXp then
                pcall(addXp, player, Perks.Aiming, xp)
            else
                pcall(function() player:getXp():AddXP(Perks.Aiming, xp) end)
            end
        end
    end

    -- golf is relaxing (and water is not)
    S.adjustMood(player, PG.Mood.shot)
    if sim.result == "cup" then S.adjustMood(player, PG.Mood.sunk) end
    if sim.result == "water" then S.adjustMood(player, PG.Mood.splash) end

    -- the whack is loud: zombies near the golfer hear it
    if addSound then
        pcall(addSound, player, math.floor(bx), math.floor(by), z, shot.noiseRadius, shot.noiseRadius)
    end

    if sim.result == "water" then
        item = nil   -- the ball is gone
    end
    if sim.result == "lost" then
        sim.final = { x = bx, y = by, z = z }
    end

    if item then
        S.pending[#S.pending + 1] = {
            due = now + math.floor(sim.duration * 1000) + 50,
            item = item, x = sim.final.x, y = sim.final.y, z = sim.final.z,
        }
    end

    -- events go over the network as parallel arrays (small and flat)
    local evT, evK = {}, {}
    for i, e in ipairs(sim.events) do
        evT[i] = e.t
        evK[i] = e.kind
    end

    PG.broadcast("Flight", {
        by       = try(player, "getOnlineID") or 0,
        mishit   = mishit,
        overhit  = overswung,
        cupX = sim.cup and sim.cup.x, cupY = sim.cup and sim.cup.y, cupZ = sim.cup and sim.cup.z,
        shot     = shotId,
        path     = sim.path,
        sampleDt = sim.sampleDt,
        duration = sim.duration,
        result   = sim.result,
        evT      = evT,
        evK      = evK,
        x0 = bx, y0 = by, z0 = z,
        x1 = sim.final.x, y1 = sim.final.y, z1 = sim.final.z,
    })
end

-- -------------------------------------------------------------------------------------------------------------
-- Crafted golf holes: the item becomes a map tile, and digging the tile up gives the item back.
-- -------------------------------------------------------------------------------------------------------------
local function closeEnough(player, sq)
    local dx, dy = player:getX() - (sq:getX() + 0.5), player:getY() - (sq:getY() + 0.5)
    return dx * dx + dy * dy <= 2.5 * 2.5 and math.floor(player:getZ()) == sq:getZ()
end

local function notice(player, text)
    PG.sendToPlayer(player, "Notice", { text = text })
end

function S.takeItem(player, fullType)
    local item = player:getInventory():getFirstTypeRecurse(fullType)
    if not item then return false end
    local container = item:getContainer()
    container:Remove(item)
    if isServer() and sendRemoveItemFromContainer then pcall(sendRemoveItemFromContainer, container, item) end
    return true
end

function S.giveItem(player, fullType)
    local inv = player:getInventory()
    local item = inv:AddItem(fullType)
    if item and isServer() and sendAddItemToContainer then pcall(sendAddItemToContainer, inv, item) end
    return item ~= nil
end

function PG.ServerCommands.PlaceHole(player, args)
    if type(args) ~= "table" then return end
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not x or not y or not z then return end
    local sq = W.square(x, y, z)
    if not sq or not closeEnough(player, sq) then return end
    local ok, why = W.canPlaceHole(sq)
    if not ok then notice(player, "Can't place a hole: " .. why); return end
    if not S.takeItem(player, PG.Items.Flag) then return end

    local obj = IsoObject.new(sq:getCell(), sq, PG.HolePlacement.sprite)
    obj:getModData().ProjectGolfHole = true
    sq:AddTileObject(obj)
    if isServer() then try(obj, "transmitCompleteItemToClients") end
    notice(player, "Golf hole placed")
end

function PG.ServerCommands.RemoveHole(player, args)
    if type(args) ~= "table" then return end
    local x, y, z = tonumber(args.x), tonumber(args.y), tonumber(args.z)
    if not x or not y or not z then return end
    local sq = W.square(x, y, z)
    if not sq or not closeEnough(player, sq) then return end
    local obj = W.removableHoleOn(sq)
    if not obj then return end
    if isServer() then
        sq:transmitRemoveItemFromSquare(obj)
    else
        sq:RemoveTileObject(obj)
    end
    S.giveItem(player, PG.Items.Flag)
    notice(player, "Golf hole picked up")
end

-- -------------------------------------------------------------------------------------------------------------
-- Put balls back down when their flight ends.
-- -------------------------------------------------------------------------------------------------------------
local function onTick()
    if #S.pending == 0 then return end
    local now = PG.now()
    for i = #S.pending, 1, -1 do
        local p = S.pending[i]
        if now >= p.due then
            table.remove(S.pending, i)
            S.placeWorldItem(p.item, p.x, p.y, p.z)
        end
    end
end
Events.OnTick.Add(onTick)

local function onClientCommand(module, command, player, args)
    if module ~= PG.MOD_ID then return end
    local handler = PG.ServerCommands[command]
    if handler then handler(player, args) end
end
Events.OnClientCommand.Add(onClientCommand)
