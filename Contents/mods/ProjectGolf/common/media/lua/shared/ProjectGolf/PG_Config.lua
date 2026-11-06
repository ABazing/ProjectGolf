-- Project Golf (B42) - shared configuration
-- Everything tunable lives here. Units: 1 unit = 1 square (≈ 1 m). Heights are in squares above the ball's storey.

ProjectGolf = ProjectGolf or {}
local PG = ProjectGolf

PG.MOD_ID   = "ProjectGolf"
PG.VERSION  = "2.0.0"

-- Viewpoint docs: one storey is the side of a square multiplied by sqrt(6).
PG.STOREY = math.sqrt(6)

PG.Items = {
    Club = "Base.Golfclub",          -- vanilla golf club
    Ball = "Base.GolfBall",          -- vanilla golf ball
    Flag = "ProjectGolf.GolfFlag",   -- our placeable cup & flag
}

PG.Physics = {
    dt            = 1 / 60,   -- simulation step (s)
    maxTime       = 25,       -- hard cap on one shot (s)
    gravity       = 9.8,      -- squares / s^2
    restitution   = 0.38,     -- vertical bounce factor on landing
    bounceKeep    = 0.65,     -- horizontal speed kept on each bounce
    rollStartKeep = 0.5,      -- horizontal speed kept when an air shot settles into a roll (backspin)
    minBounceVz   = 1.2,      -- below this vertical speed the ball starts rolling
    stopSpeed     = 0.12,     -- rolling speed at which the ball stops
    wallKeep      = 0.45,     -- speed kept after hitting a wall
    wallHeight    = 2.3,      -- walls block the ball below this height
    fenceHeight   = 1.0,      -- low fences block below this height
    treeHeight    = 6.0,      -- tree canopies can catch the ball below this height
    treeCatch     = 0.55,     -- chance a tree deflects the ball when it passes through
    zombieHeight  = 1.8,      -- a zombie's body blocks the ball below this height
    zombieRadius  = 0.35,
    cupRadius     = 0.15,     -- distance from cup centre that counts as "in"
    cupMaxSpeed   = 2.5,      -- fastest a ball can be rolling and still drop in, dead centre
    cupEdgeFactor = 0.5,      -- a ball clipping the rim must be going this fraction of that
    pathSample    = 3,        -- keep every Nth step for the network path (60/3 = 20 Hz)
}

-- Rolling deceleration (squares / s^2) by surface.
PG.Surfaces = {
    grass    = 2.4,
    rough    = 5.5,   -- tall grass, bushes
    dirt     = 3.0,
    road     = 0.9,
    floor    = 1.4,
    default  = 2.0,
}

-- One entry per shot type. carry = max air distance at full power, roll = putt distance.
PG.Shots = {
    putt  = { label = "Putt",  launchDeg = 0,  maxDist = 14, accuracyDeg = 0.6, noiseRadius = 4  },
    chip  = { label = "Chip",  launchDeg = 52, maxDist = 16, accuracyDeg = 1.4, noiseRadius = 10 },
    drive = { label = "Drive", launchDeg = 20, maxDist = 42, accuracyDeg = 2.2, noiseRadius = 22 },
}
PG.ShotOrder = { "putt", "chip", "drive" }

-- Strength scales how far chips and drives carry.
-- Multiplier = (minMult at Strength 0, rising evenly to maxMult at Strength 10) x boost.
-- boost: everyone's chips and drives go this much further, at every Strength (1.3 = 30% further).
PG.Strength = {
    affects = { chip = true, drive = true },
    minMult = 0.75,
    maxMult = 1.75,
    boost   = 1.3,
}

-- The distance multiplier for a club at a Strength level (0-10). Used for you and for golf partners alike.
function PG.strengthMult(shotId, level)
    local cfg = PG.Strength
    if not cfg.affects[shotId] then return 1 end
    return (cfg.minMult + (cfg.maxMult - cfg.minMult) * PG.clamp(level or 5, 0, 10) / 10) * (cfg.boost or 1)
end

function PG.strengthLevel(player)
    if not player or not Perks or not Perks.Strength then return 5 end
    local ok, lvl = pcall(function() return player:getPerkLevel(Perks.Strength) end)
    lvl = ok and tonumber(lvl) or nil
    if not lvl then return 5 end
    return PG.clamp(lvl, 0, 10)
end

-- Distance multiplier for this player and shot (1 for shots strength does not affect).
function PG.distanceMult(player, shotId)
    return PG.strengthMult(shotId, PG.strengthLevel(player))
end

PG.Gameplay = {
    maxHitDistance  = 2.2,   -- player must be this close to the ball (squares)
    hitCooldownMs   = 1200,  -- server-side rate limit per player
    meterSpeed      = 0.85,  -- power meter cycles per second (0 -> 1 -> 0 is one cycle)
    overswingAt     = 0.92,  -- above this power you overswing (spread and mishits: PG.Overswing in PG_Server.lua)
    swingDelayMs    = 350,   -- swing animation time before the ball leaves
    previewDots     = 48,    -- max dots in the trajectory preview
}

-- Sounds defined in media/scripts/ProjectGolf_sounds.txt
PG.Sounds = {
    drive  = "ProjectGolf_Drive",
    putt   = "ProjectGolf_Putt",
    bounce = "ProjectGolf_Bounce",
    wall   = "ProjectGolf_Bounce",
    tree   = "ProjectGolf_Tree",
    cup    = "ProjectGolf_Cup",
    splash = "ProjectGolf_Splash",
}

-- Stance animation while aiming (the swing itself is PG.SwingAnims in PG_StanceAction.lua).
PG.Anims = {
    stance = nil,          -- nil = just hold the club and face the shot
}

PG.DEBUG = false

function PG.log(...)
    local parts = { "[ProjectGolf]" }
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    print(table.concat(parts, " "))
end

function PG.debug(...)
    if PG.DEBUG then PG.log(...) end
end

-- Kahlua has math.atan2; Lua 5.3 (test harness) uses math.atan(y, x).
PG.atan2 = math.atan2 or function(y, x) return math.atan(y, x) end

function PG.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
