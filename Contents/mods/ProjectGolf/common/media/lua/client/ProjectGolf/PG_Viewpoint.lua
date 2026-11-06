-- Project Golf - soft integration with Viewpoint (first / third person).
-- Nothing here requires Viewpoint: every call is guarded, and without it the mod uses the isometric view.
--
-- Two ways in, picked automatically (both give the same numbers):
--   Viewpoint 0.1.7+: its Lua mirror (docs: api/lua-mirror) and our Java addon "projectgolf.ball".
--     Viewpoint.Addons.viewState() -> table, or nil on the first call / after a 2 s pause. Call it every frame.
--   Viewpoint 0.1.6 (no addon API): the global ProjectGolfVP16, a small ZombieBuddy bridge in this mod's jar
--     (vp16-src/) that reads the camera and relief, and draws the 3D ball at the same point of the frame when the
--     Viewpoint Ball mod is on too.
--   x east, y south (squares), z up in storeys; yaw 0 = east, 90 = south; pitch up is positive; fov is vertical.

require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Options"

local PG = ProjectGolf
PG.VP = PG.VP or {}
local VP = PG.VP

VP.ADDON_ID = "projectgolf.ball"

-- Viewpoint terrain relief: Viewpoint can raise and lower the ground it draws. Physics stays on the game's flat
-- floor (relief is a per-player visual setting); only the drawing of the ball and the preview is lifted onto it.
PG.Relief = PG.Relief or {
    enabled = true,
    units = "storeys",   -- what Viewpoint.Addons.terrainHeight returns: "storeys" or "squares" (check the log line)
    cacheStep = 0.25,    -- squares; heights are cached on this grid
}

-- Viewpoint 0.1.7+: its addon API's Lua mirror.
local function addons()
    if Viewpoint ~= nil and Viewpoint.Addons ~= nil and Viewpoint.Addons.viewState ~= nil then return Viewpoint.Addons end
    return nil
end

-- Viewpoint 0.1.6: our bridge (it answers active() = false on 0.1.7+, where the addon API is used instead).
local bridgeChecked, bridgeOn = false, false
local function bridge()
    local b = ProjectGolfVP16
    if b == nil or b.active == nil then return nil end
    if not bridgeChecked then
        bridgeChecked = true
        local ok, on = pcall(b.active)
        bridgeOn = ok and on == true
        if bridgeOn then
            PG.log("Viewpoint 0.1.6 bridge on (view, relief, 3D ball)")
        elseif b.why then
            local okWhy, why = pcall(b.why)
            PG.log("Viewpoint 0.1.6 bridge off: " .. tostring(okWhy and why or "?"))
        end
    end
    return bridgeOn and b or nil
end

function VP.present()
    return addons() ~= nil or bridge() ~= nil
end

-- "mode,x,y,z,yaw,pitch,fov" from the bridge -> the same table shape as Viewpoint.Addons.viewState().
local function parseView(text)
    local f = {}
    for n in string.gmatch(text, "[^,]+") do f[#f + 1] = tonumber(n) end
    if #f < 7 then return nil end
    for i = 1, 7 do if f[i] == nil or f[i] ~= f[i] then return nil end end
    return {
        on = true,
        mode = f[1] == 2 and "third_person" or "first_person",
        eye = { x = f[2], y = f[3], z = f[4], yaw = f[5], pitch = f[6] },
        fov = f[7],
    }
end
VP.parseView = parseView

-- The view state when Viewpoint draws first or third person, else nil.
function VP.state()
    local a = addons()
    if a then
        local ok, v = pcall(a.viewState)
        if ok and v and v.on and v.eye then return v end
        return nil
    end
    local b = bridge()
    if b then
        local ok, text = pcall(b.view)
        if ok and type(text) == "string" then return parseView(text) end
    end
    return nil
end

-- Viewpoint's terrain height function, from whichever source is present (nil when there is none).
local function terrainFn()
    local a = addons()
    if a then return a.terrainHeight end
    return bridge() and ProjectGolfVP16.terrainHeight or nil
end

-- Height of Viewpoint's drawn ground at x, y (nil when unknown).
local function terrainHeightAt(x, y)
    local f = terrainFn()
    if not f then return nil end
    local ok, v = pcall(f, x, y)
    return ok and tonumber(v) or nil
end

-- Project a world point (x, y, z in storeys) to screen pixels with the Viewpoint camera.
-- Returns sx, sy, pixelsPerSquare (or nil when the point is behind the camera).
function VP.project(v, x, y, zf)
    local S = PG.STOREY
    local yaw, pitch = math.rad(v.eye.yaw), math.rad(v.eye.pitch)
    local cp, sp = math.cos(pitch), math.sin(pitch)
    local cy, sy = math.cos(yaw), math.sin(yaw)
    -- basis (x east, y south, z up - a left-handed frame, so up = forward x right)
    local fx, fy, fz = cp * cy, cp * sy, sp
    local rx, ry = -sy, cy                    -- right, rz = 0
    local ux, uy, uz = -sp * cy, -sp * sy, cp -- up

    local dx, dy, dz = x - v.eye.x, y - v.eye.y, (zf - v.eye.z) * S
    local depth = dx * fx + dy * fy + dz * fz
    if depth < 0.05 then return nil end
    local right = dx * rx + dy * ry
    local up = dx * ux + dy * uy + dz * uz

    local core = getCore()
    local w, h = core:getScreenWidth(), core:getScreenHeight()
    local focal = (h / 2) / math.tan(math.rad((v.fov or 70) / 2))
    return w / 2 + right / depth * focal, h / 2 - up / depth * focal, focal / depth
end

-- Height of Viewpoint's drawn ground (terrain relief) at x, y, in storeys. 0 when relief is off or unknown.
local reliefCache, reliefCount, reliefLogged = {}, 0, false

local function gridHeight(qx, qy, step)
    local key = qx .. "," .. qy
    local h = reliefCache[key]
    if h == nil then
        local v = terrainHeightAt(qx * step, qy * step)
        if v and v == v then
            h = PG.Relief.units == "squares" and v / PG.STOREY or v
            if not reliefLogged then
                reliefLogged = true
                local st = VP.state()
                PG.log("relief: terrainHeight(" .. qx * step .. ", " .. qy * step .. ") = " .. tostring(v)
                    .. " (read as " .. PG.Relief.units .. "), eye z = " .. tostring(st and st.eye and st.eye.z))
            end
        else
            h = 0
        end
        if reliefCount > 8000 then reliefCache, reliefCount = {}, 0 end
        reliefCache[key] = h
        reliefCount = reliefCount + 1
    end
    return h
end

-- Height of the drawn ground at x, y in storeys: blended from the four nearest cached samples, so it follows
-- slopes smoothly (Viewpoint returns storeys; checked against its relief code).
function VP.groundLift(x, y)
    local cfg = PG.Relief
    if not cfg.enabled or terrainFn() == nil then return 0 end
    local step = cfg.cacheStep
    local fx, fy = x / step, y / step
    local qx, qy = math.floor(fx), math.floor(fy)
    local tx, ty = fx - qx, fy - qy
    local h00, h10 = gridHeight(qx, qy, step), gridHeight(qx + 1, qy, step)
    local h01, h11 = gridHeight(qx, qy + 1, step), gridHeight(qx + 1, qy + 1, step)
    local top = h00 + (h10 - h00) * tx
    local bottom = h01 + (h11 - h01) * tx
    return top + (bottom - top) * ty
end

-- Relief can change (settings, new chunks): drop the cache, e.g. when a new shot starts.
function VP.clearReliefCache()
    reliefCache, reliefCount = {}, 0
end

-- Aim direction while in first / third person: where the player looks.
function VP.aimYaw(v)
    return v and v.eye and v.eye.yaw or nil
end

-- --------------------------------------------------------------------------------------------------------------
-- 3D ball (the ProjectGolfViewpoint mod: Java addon "projectgolf.ball" on 0.1.7+, the bridge on 0.1.6).
-- Lua sends each flight and the aim preview once, as text "x,y,z,g;..." (world x, y in squares; z = ball and
-- g = ground under it, in storeys, both already lifted onto terrain relief); the addon draws real 3D spheres with depth, so terrain and walls hide them.
-- Without the addon, or in the isometric view, the 2D overlay draws instead.
-- --------------------------------------------------------------------------------------------------------------
local function ballApi()
    local a = addons()
    if a then
        local addon = a[VP.ADDON_ID]
        return addon and addon.Ball or nil
    end
    -- 0.1.6: the bridge has the same calls (flight, stop, preview, clearPreview). Like on 0.1.7, the 3D ball is
    -- part of the "Project Golf - Viewpoint Ball" mod (it sets ProjectGolfViewpointBall). If the bridge's drawing
    -- ever failed, answer nil so the 2D overlay draws instead.
    if ProjectGolfViewpointBall ~= true then return nil end
    local b = bridge()
    if b and b.drawing then
        local ok, on = pcall(b.drawing)
        if not (ok and on) then return nil end
    end
    return b
end

-- True when the 3D ball draws this frame: addon on, option on, Viewpoint in first / third person.
function VP.ball3D(vpState)
    return vpState ~= nil and PG.Options.get("ball3D") ~= false and ballApi() ~= nil
end

local function encode(points, baseZ, maxPoints)
    local n = math.floor(#points / 3)
    local stride = maxPoints and math.max(1, math.floor(n / maxPoints)) or 1
    local parts = {}
    local i = 0
    while i < n do
        local x, y, z = points[i * 3 + 1], points[i * 3 + 2], points[i * 3 + 3]
        local base = baseZ
        if base and base > z then base = math.floor(z + 0.0001) end
        base = base or math.floor(z + 0.0001)
        local ground = base
        if base == 0 then
            local lift = VP.groundLift(x, y)
            z, ground = z + lift, ground + lift
        end
        parts[#parts + 1] = x .. "," .. y .. "," .. z .. "," .. ground
        if i < n - 1 and i + stride > n - 1 then i = n - 1 else i = i + stride end
    end
    return table.concat(parts, ";")
end
VP.encodePath = encode

local function call(fname, ...)
    local api = ballApi()
    local f = api and api[fname]
    if not f then return nil end
    local ok, res = pcall(f, ...)
    if not ok then PG.debug("ball addon " .. fname .. " failed: " .. tostring(res)) end
    return ok and res or nil
end

function VP.ballFlight(id, path, sampleDt, baseZ)
    return call("flight", id, encode(path, baseZ), sampleDt)
end

function VP.ballStop(id)
    call("stop", id)
end

function VP.ballPreview(points, baseZ, r, g, b)
    call("preview", encode(points, baseZ, PG.Gameplay.previewDots), r, g, b)
end

function VP.ballClearPreview()
    call("clearPreview")
end
