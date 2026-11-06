-- Project Golf - ball physics.
-- Pure Lua: talks to the world only through a "world" adapter (see PG_World.lua), so the same code runs on the
-- server (authoritative), in single player, in the client's trajectory preview, and in the offline test harness.
--
-- Coordinates: x east, y south (squares), z = storey (integer), h = height above that storey's floor (squares).

require "ProjectGolf/PG_Config"

local PG = ProjectGolf
PG.Physics = PG.Physics or {}
local P = PG.Physics

-- ---------------------------------------------------------------------------------------------------------------
-- Small deterministic RNG (Park-Miller). Exact in doubles, so identical everywhere.
-- ---------------------------------------------------------------------------------------------------------------
local Rng = {}
Rng.__index = Rng

function PG.newRng(seed)
    seed = math.floor(math.abs(seed or 1)) % 2147483646 + 1
    local r = setmetatable({ s = seed }, Rng)
    for _ = 1, 4 do r:next() end   -- small seeds give tiny first outputs; warm up
    return r
end

function Rng:next()            -- [0, 1)
    self.s = (self.s * 16807) % 2147483647
    return (self.s - 1) / 2147483646
end

function Rng:range(a, b) return a + (b - a) * self:next() end

-- Roughly normal, mean 0, sd ~1 (sum of uniforms).
function Rng:gauss()
    return (self:next() + self:next() + self:next() + self:next() - 2) * 1.732
end

-- ---------------------------------------------------------------------------------------------------------------
-- Launch velocity for a shot.
-- ---------------------------------------------------------------------------------------------------------------
function PG.launchVelocity(shotId, power, yawDeg, distMult)
    local shot = PG.Shots[shotId]
    local cfg = PG.Physics
    power = PG.clamp(power or 0, 0, 1)
    local yaw = math.rad(yawDeg)
    local dirX, dirY = math.cos(yaw), math.sin(yaw)

    if shot.launchDeg <= 0 then
        -- Putt: pick the speed that rolls maxDist*power on grass.
        local dist = math.max(0.05, shot.maxDist * power * (distMult or 1))
        local v = math.sqrt(2 * PG.Surfaces.grass * dist)
        return dirX * v, dirY * v, 0, true
    end

    local theta = math.rad(shot.launchDeg)
    local carry = math.max(0.1, shot.maxDist * power * (distMult or 1))
    local v = math.sqrt(carry * cfg.gravity / math.sin(2 * theta))
    local vh = v * math.cos(theta)
    return dirX * vh, dirY * vh, v * math.sin(theta), false
end

-- ---------------------------------------------------------------------------------------------------------------
-- Simulation.
-- input = { x, y, z, h?, shot, power, yaw (deg, 0 east, 90 south), seed, distanceMult?, maxTime?, preview? }
-- world = adapter with info(ix,iy,iz), blocked(ax,ay,bx,by,z), zombies(ix,iy,iz), cups(ix,iy,iz)
-- returns result table (see bottom)
-- ---------------------------------------------------------------------------------------------------------------
function PG.simulate(input, world)
    local cfg = PG.Physics
    local rng = PG.newRng(input.seed or 1)
    local dt = cfg.dt
    local maxTime = input.maxTime or cfg.maxTime
    local floor = math.floor

    local x, y, z, h = input.x, input.y, input.z or 0, input.h or 0
    local vx, vy, vz, rolling = PG.launchVelocity(input.shot, input.power, input.yaw, input.distanceMult)

    local path = { x, y, z + h / PG.STOREY }
    local events = {}
    local result = "rest"
    local cupAt = nil
    local t, step = 0, 0
    local lastCell = floor(x) .. "," .. floor(y) .. "," .. z
    local hitZombies = {}
    local lippedCups = {}

    -- per-simulation caches
    local infoCache, zedCache, cupCache = {}, {}, {}
    local function info(ix, iy, iz)
        local k = ix .. "," .. iy .. "," .. iz
        local v = infoCache[k]
        if v == nil then v = world.info(ix, iy, iz) or false; infoCache[k] = v end
        return v or nil
    end
    local function zombies(ix, iy, iz)
        local k = ix .. "," .. iy .. "," .. iz
        local v = zedCache[k]
        if v == nil then v = world.zombies(ix, iy, iz) or {}; zedCache[k] = v end
        return v
    end
    local function cups(ix, iy, iz)
        local k = ix .. "," .. iy .. "," .. iz
        local v = cupCache[k]
        if v == nil then v = world.cups(ix, iy, iz) or {}; cupCache[k] = v end
        return v
    end

    local function event(kind, extra)
        local e = { t = t, kind = kind, x = x, y = y, z = z }
        if extra then for k2, v2 in pairs(extra) do e[k2] = v2 end end
        events[#events + 1] = e
    end

    -- Height under which a crossing between two cells is blocked (0 = open).
    local function blockHeight(ax, ay, bx, by)
        local b = world.blocked(ax, ay, bx, by, z)
        if b == "wall" then return cfg.wallHeight end
        if b == "fence" then return cfg.fenceHeight end
        local inf = info(bx, by, z)
        if not inf then return 1e9 end                 -- unloaded square: hard wall
        if inf.solid then return cfg.fenceHeight * 1.2 end
        return 0
    end

    if not info(floor(x), floor(y), z) then
        return { path = path, events = events, result = "lost", final = { x = x, y = y, z = z }, duration = 0 }
    end

    while t < maxTime do
        t = t + dt
        step = step + 1

        -- vertical motion
        if not rolling then
            vz = vz - cfg.gravity * dt
            h = h + vz * dt
        end

        -- horizontal motion with wall checks, one axis at a time
        local nx, ny = x + vx * dt, y + vy * dt
        local cx, cy = floor(x), floor(y)
        local tx, ty = floor(nx), floor(ny)

        if tx ~= cx then
            local bh = blockHeight(cx, cy, tx, cy)
            if bh > 0 and h < bh then
                vx = -vx * cfg.wallKeep
                vy = vy * cfg.wallKeep
                nx = x
                tx = cx
                event("wall")
            end
        end
        if ty ~= cy then
            local bh = blockHeight(tx, cy, tx, ty)
            if bh > 0 and h < bh then
                vy = -vy * cfg.wallKeep
                vx = vx * cfg.wallKeep
                ny = y
                ty = cy
                event("wall")
            end
        end
        x, y = nx, ny

        local cell = tx .. "," .. ty .. "," .. z
        local here = info(tx, ty, z)
        local entered = cell ~= lastCell
        lastCell = cell

        -- trees: only checked when the ball enters a new square
        if entered and here and here.tree and h < cfg.treeHeight then
            if input.preview then
                -- preview: stop drawing at the tree so the player sees it is in the way
                event("tree")
                break
            elseif rng:next() < cfg.treeCatch then
                local speed = math.sqrt(vx * vx + vy * vy) * rng:range(0.15, 0.35)
                local ang = PG.atan2(vy, vx) + math.rad(rng:range(100, 260))
                vx, vy = math.cos(ang) * speed, math.sin(ang) * speed
                if vz > 0 then vz = vz * 0.2 end
                if rolling then rolling = false; vz = 0.5 end
                event("tree")
            end
        end

        -- zombies
        if h < cfg.zombieHeight then
            for _, zed in ipairs(zombies(tx, ty, z)) do
                local key = zed.id or (zed.x .. "," .. zed.y)
                if not hitZombies[key] then
                    local dx, dy = x - zed.x, y - zed.y
                    local d = math.sqrt(dx * dx + dy * dy)
                    if d < cfg.zombieRadius then
                        hitZombies[key] = true
                        local speed = math.sqrt(vx * vx + vy * vy)
                        local nxn, nyn = dx / math.max(d, 0.01), dy / math.max(d, 0.01)
                        local dot = vx * nxn + vy * nyn
                        vx, vy = (vx - 2 * dot * nxn) * 0.3, (vy - 2 * dot * nyn) * 0.3
                        event("zombie", { id = zed.id, speed = speed })
                    end
                end
            end
        end

        -- landing / bouncing
        if not rolling and h <= 0 and vz < 0 then
            if here and here.water then
                h = 0
                result = "water"
                event("splash")
                break
            end
            if z > 0 and here and not here.floor then
                z = z - 1
                h = h + PG.STOREY
            elseif -vz > cfg.minBounceVz then
                h = 0
                vz = -vz * cfg.restitution
                vx, vy = vx * cfg.bounceKeep, vy * cfg.bounceKeep
                event("bounce")
            else
                h, vz = 0, 0
                rolling = true
                vx, vy = vx * cfg.rollStartKeep, vy * cfg.rollStartKeep   -- backspin bites on landing
            end
        end

        if rolling then
            -- roll off a ledge
            if z > 0 and here and not here.floor then
                rolling = false
                z = z - 1
                h = PG.STOREY
                vz = 0
            elseif here and here.water then
                result = "water"
                event("splash")
                break
            else
                local speed = math.sqrt(vx * vx + vy * vy)
                local decel = PG.Surfaces[(here and here.surface) or "default"] or PG.Surfaces.default
                local newSpeed = speed - decel * dt
                if newSpeed <= cfg.stopSpeed then
                    vx, vy = 0, 0
                    result = "rest"
                    break
                end
                local k = newSpeed / speed
                vx, vy = vx * k, vy * k
            end
        end

        -- the cup
        if h < 0.2 then
            for i, cup in ipairs(cups(tx, ty, z)) do
                local dx, dy = x - cup.x, y - cup.y
                local d2 = dx * dx + dy * dy
                if d2 < cfg.cupRadius * cfg.cupRadius then
                    local speed = math.sqrt(vx * vx + vy * vy + vz * vz)
                    local key = cell .. ":" .. i
                    -- a ball that has just lipped out of this cup cannot drop back in on the same pass
                    if lippedCups[key] then speed = math.huge end
                    -- a ball rolling straight at the centre may be a little faster than one clipping the rim:
                    -- judged by how far off-centre its line of travel passes (not where it first touches)
                    local hs = math.sqrt(vx * vx + vy * vy)
                    local offLine = hs > 1e-6 and math.abs(vx * dy - vy * dx) / hs or math.sqrt(d2)
                    local edge = math.min(1, (offLine / cfg.cupRadius) ^ 2)        -- 0 centre line .. 1 rim
                    local limit = cfg.cupMaxSpeed * (1 - (1 - (cfg.cupEdgeFactor or 0.5)) * edge)
                    if speed <= limit then
                        x, y, h = cup.x, cup.y, 0
                        result = "cup"
                        cupAt = { x = cup.x, y = cup.y, z = z }
                        event("cup")
                        break
                    elseif speed ~= math.huge then
                        lippedCups[key] = true
                        local ang = PG.atan2(vy, vx) + math.rad(rng:range(-45, 45))
                        local s = math.sqrt(vx * vx + vy * vy) * 0.6
                        vx, vy = math.cos(ang) * s, math.sin(ang) * s
                        event("lipout")
                    end
                end
            end
            if result == "cup" then break end
        end

        if step % cfg.pathSample == 0 then
            path[#path + 1] = x
            path[#path + 1] = y
            path[#path + 1] = z + math.max(h, 0) / PG.STOREY
        end
    end

    if h < 0 then h = 0 end
    path[#path + 1] = x
    path[#path + 1] = y
    path[#path + 1] = z + h / PG.STOREY

    return {
        path     = path,          -- flat list x,y,zf,x,y,zf,... sampled every pathSample steps
        events   = events,        -- { t, kind, x, y, z, ... }
        result   = result,        -- "rest" | "cup" | "water" | "lost"
        final    = { x = x, y = y, z = z },
        cup      = cupAt,
        duration = t,
        sampleDt = cfg.dt * cfg.pathSample,
    }
end
