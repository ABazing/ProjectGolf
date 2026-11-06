-- Project Golf - Aiming makes you a better golfer (sandbox option "Aiming affects golf").
--
--   1. Accuracy   the random spread on every shot shrinks with skill            (server)
--   2. Overswing  past the red line, the mishit chance shrinks with skill        (server)
--   3. Reading    the preview line shows only as much of the shot as you can read (client)
--   4. Marker     the power-to-the-hole marker is a band at low skill, exact later (client)
--
-- Everything is a straight line between the level 0 and level 10 values below (clamped). With the sandbox option
-- off, every effect is neutral: spread and mishits as before, the whole preview line and an exact marker.

require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Sandbox"

local PG = ProjectGolf

PG.Skill = PG.Skill or {}
local K = PG.Skill

K.Tuning = K.Tuning or {
    spreadAt0  = 1.5,  spreadAt10 = 0.5,     -- x shot spread (1.0 at level 5)
    mishitAt0  = 1.0,  mishitAt10 = 0.5,     -- x overswing mishit chance (60% -> 30% at full power)
    previewAt0 = 0.40, previewFullAt = 6,    -- share of the shot's distance the preview shows; whole line from level 6
    previewMin = { putt = 0.60 },            -- putts are easier to read
    bandAt0    = 0.10, bandExactAt = 7,      -- marker band half-width (share of the meter); exact from level 7
}

function K.enabled()
    return PG.sandbox("AimingSkill", true) == true
end

function K.level(player)
    if not player or not Perks or not Perks.Aiming then return 0 end
    local ok, lvl = pcall(function() return player:getPerkLevel(Perks.Aiming) end)
    return ok and tonumber(lvl) or 0
end

local function lerp(a, b, t) return a + (b - a) * PG.clamp(t, 0, 1) end

-- 1. multiplier on the shot's spread
function K.spreadMult(level)
    if not K.enabled() then return 1 end
    local t = K.Tuning
    return lerp(t.spreadAt0, t.spreadAt10, (level or 0) / 10)
end

-- 2. multiplier on the overswing mishit chance
function K.mishitMult(level)
    if not K.enabled() then return 1 end
    local t = K.Tuning
    return lerp(t.mishitAt0, t.mishitAt10, (level or 0) / 10)
end

-- 3. share (0..1) of the shot's distance the preview line shows
function K.previewFraction(level, shotId)
    if not K.enabled() then return 1 end
    local t = K.Tuning
    local start = math.max(t.previewAt0, (t.previewMin and t.previewMin[shotId]) or 0)
    return lerp(start, 1, (level or 0) / t.previewFullAt)
end

-- 4. half-width of the marker band, as a share of the meter (0 = an exact line)
function K.markerBand(level)
    if not K.enabled() then return 0 end
    local t = K.Tuning
    return lerp(t.bandAt0, 0, (level or 0) / t.bandExactAt)
end

-- Cuts a flat x,y,z path so it covers `fraction` of its horizontal length. Returns a new array.
function K.trimPath(path, fraction)
    local n = #path / 3
    if fraction >= 1 or n < 2 then return path end
    local total = 0
    for i = 1, n - 1 do
        local a, b = (i - 1) * 3, i * 3
        total = total + math.sqrt((path[b + 1] - path[a + 1]) ^ 2 + (path[b + 2] - path[a + 2]) ^ 2)
    end
    local want = total * math.max(fraction, 0)
    local out = { path[1], path[2], path[3] }
    local run = 0
    for i = 1, n - 1 do
        local a, b = (i - 1) * 3, i * 3
        local seg = math.sqrt((path[b + 1] - path[a + 1]) ^ 2 + (path[b + 2] - path[a + 2]) ^ 2)
        if run + seg >= want then
            local k = seg > 0 and (want - run) / seg or 0
            out[#out + 1] = path[a + 1] + (path[b + 1] - path[a + 1]) * k
            out[#out + 1] = path[a + 2] + (path[b + 2] - path[a + 2]) * k
            out[#out + 1] = path[a + 3] + (path[b + 3] - path[a + 3]) * k
            return out
        end
        run = run + seg
        out[#out + 1] = path[b + 1]; out[#out + 1] = path[b + 2]; out[#out + 1] = path[b + 3]
    end
    return out
end

-- A band around the true target power that contains it, but is not centred on it (so its middle is not the
-- answer). `salt` keeps the band still while the aim stays the same. Returns lo, hi (0..1).
function K.bandAround(target, half, salt)
    if half <= 0 then return target, target end
    local h = 0
    local s = tostring(salt)
    for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
    local shift = ((h % 1000) / 1000 * 2 - 1) * half * 0.8     -- true value lies within the inner 80%
    local mid = target + shift
    return PG.clamp(mid - half, 0, 1), PG.clamp(mid + half, 0, 1)
end
