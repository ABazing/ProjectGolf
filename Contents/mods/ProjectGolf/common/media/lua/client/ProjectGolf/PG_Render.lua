-- Project Golf - drawing helpers shared by the aim UI and the flight overlay.
-- Projects world points to the screen in the isometric view, or with Viewpoint's camera in first / third person.

require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Viewpoint"

local PG = ProjectGolf
PG.Render = PG.Render or {}
local R = PG.Render

R.tex = {}
local function tex(name)
    if R.tex[name] == nil then
        R.tex[name] = getTexture("media/textures/ProjectGolf/" .. name .. ".png") or false
    end
    return R.tex[name] or nil
end
R.texture = tex

-- world (x, y, z in storeys) -> screen x, y, pixels per square
-- baseZ: the storey whose floor the point is above. Terrain relief only lifts points above the ground (storey 0).
function R.toScreen(playerNum, x, y, zf, vpState, baseZ)
    if vpState then
        if (baseZ or math.floor(zf + 0.0001)) == 0 then
            zf = zf + PG.VP.groundLift(x, y)
        end
        return PG.VP.project(vpState, x, y, zf)
    end
    local sx, sy = isoToScreenX(playerNum, x, y, zf), isoToScreenY(playerNum, x, y, zf)
    local sx2, sy2 = isoToScreenX(playerNum, x + 1, y, zf), isoToScreenY(playerNum, x + 1, y, zf)
    local dx, dy = sx2 - sx, sy2 - sy
    return sx, sy, math.sqrt(dx * dx + dy * dy)
end

-- screen -> world on a storey (isometric only)
function R.mouseToWorld(playerNum, zLevel)
    local mx, my = getMouseX(), getMouseY()
    return screenToIsoX(playerNum, mx, my, zLevel), screenToIsoY(playerNum, mx, my, zLevel)
end

-- Draws a ball (and its shadow on the floor below it) on a UI element placed at the screen origin.
function R.drawBall(ui, playerNum, x, y, zf, vpState, alpha, baseZ)
    alpha = alpha or 1
    local ground = baseZ or math.floor(zf + 0.0001)
    if ground > zf then ground = math.floor(zf + 0.0001) end   -- the ball fell off a ledge
    local gx, gy, gs = R.toScreen(playerNum, x, y, ground, vpState, ground)
    local sx, sy, s = R.toScreen(playerNum, x, y, zf, vpState, ground)
    if not sx then return end

    local shadow, ball = tex("shadow"), tex("ball")
    if gx then
        local sw = math.max(4, gs * 0.22)
        if shadow then
            ui:drawTextureScaled(shadow, gx - sw / 2, gy - sw / 4, sw, sw / 2, 0.45 * alpha, 1, 1, 1)
        end
    end
    local d = math.max(4, s * 0.14)
    if ball then
        ui:drawTextureScaled(ball, sx - d / 2, sy - d / 2, d, d, alpha, 1, 1, 1)
    else
        ui:drawRect(sx - d / 2, sy - d / 2, d, d, alpha, 1, 1, 1)
    end
end

-- Dotted path: points is a flat x,y,zf list.
function R.drawPath(ui, playerNum, points, vpState, r, g, b, maxDots, baseZ)
    local dot = tex("dot")
    local n = #points / 3
    if n < 2 then return end
    local stride = math.max(1, math.floor(n / (maxDots or 48)))
    for i = 0, n - 1, stride do
        local x, y, zf = points[i * 3 + 1], points[i * 3 + 2], points[i * 3 + 3]
        local base = baseZ
        if base and base > zf then base = math.floor(zf + 0.0001) end
        local sx, sy, s = R.toScreen(playerNum, x, y, zf, vpState, base)
        if sx then
            local a = 0.85 - 0.5 * (i / n)
            local d = math.max(3, math.min(10, s * 0.08))
            if dot then
                ui:drawTextureScaled(dot, sx - d / 2, sy - d / 2, d, d, a, r, g, b)
            else
                ui:drawRect(sx - d / 2, sy - d / 2, d, d, a, r, g, b)
            end
        end
    end
end

-- Height of a font in pixels at the player's UI scale (falls back to sensible sizes).
function R.fontHeight(font)
    local ok, h = pcall(function() return getTextManager():getFontHeight(font) end)
    if ok and h and h > 0 then return h end
    return font == UIFont.Medium and 20 or 15
end

R.METER_H = 16

-- Power meter: a bar with a sweet-spot band near the top, and an optional marker at the power that reaches the hole
-- (target 0..1; targetMax = the hole is out of reach, marker pinned at the end).
function R.drawMeter(ui, cx, cy, power, label, target, targetMax, bandLo, bandHi)
    local w, h = 180, R.METER_H
    local x, y = cx - w / 2, cy
    ui:drawRect(x - 2, y - 2, w + 4, h + 4, 0.75, 0, 0, 0)
    local over = PG.Gameplay.overswingAt
    ui:drawRect(x + w * over, y, w * (1 - over), h, 0.35, 0.9, 0.2, 0.2)
    local r = power > over and 1 or 0.3 + power * 0.6
    local g = power > over and 0.35 or 0.9
    ui:drawRect(x, y, w * power, h, 0.9, r, g, 0.25)
    ui:drawRectBorder(x - 2, y - 2, w + 4, h + 4, 1, 1, 1, 1)
    if bandLo and bandHi and bandHi > bandLo and not targetMax then
        -- low Aiming: a soft band somewhere around the right power, with brackets at its ends
        local now = getTimestampMs and getTimestampMs() or 0
        local pulse = 0.75 + 0.25 * math.sin(now / 200)
        local bx1, bx2 = x + w * bandLo, x + w * bandHi
        ui:drawRect(bx1, y - 4, bx2 - bx1, h + 8, 0.30 * pulse, 1, 0.82, 0.1)
        ui:drawRect(bx1, y - 4, 2, h + 8, pulse, 1, 0.82, 0.1)
        ui:drawRect(bx2 - 2, y - 4, 2, h + 8, pulse, 1, 0.82, 0.1)
    elseif target or targetMax then
        local tx = x + w * (targetMax and 1 or PG.clamp(target, 0, 1))
        local now = getTimestampMs and getTimestampMs() or 0
        local pulse = 0.75 + 0.25 * math.sin(now / 200)
        ui:drawRect(tx - 1, y - 4, 3, h + 8, pulse, 1, 0.82, 0.1)                 -- marker line
        for i = 0, 5 do                                                            -- little arrow above it
            ui:drawRect(tx - (5 - i), y - 11 + i, (5 - i) * 2 + 1, 1, pulse, 1, 0.82, 0.1)
        end
    end
    if label then
        ui:drawTextCentre(label, cx, y - R.fontHeight(UIFont.Medium) - 14, 1, 1, 1, 1, UIFont.Medium)
    end
end

