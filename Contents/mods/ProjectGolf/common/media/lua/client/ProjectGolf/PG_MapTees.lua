-- Project Golf - every tracked course hole on the world map (M): its tee box, its cup, and a dotted line joining them.
-- The tee box is a blue square the size of the box with the hole number on a badge; the cup has a little flag.
-- Point at the badge or the flag: that hole lights up and shows its number, par and length. Drawn on top of the map
-- each frame, like the game's own flier and stash map icons, so nothing is added to your saved map symbols.
-- Mod Options: "Show the course's tee boxes and holes on the map".

require "ISUI/Maps/ISWorldMap"
require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Courses"
require "ProjectGolf/PG_Options"

local PG = ProjectGolf
PG.MapTees = PG.MapTees or {}
local MT = PG.MapTees

MT.minZoom = 11.5           -- zoomed further out than this: no tees (the whole course is a speck)
MT.labelZoom = 13.5         -- badges grow from here...
MT.fullZoom = 16            -- ...to full size here
MT.colour = { 0.12, 0.53, 0.90 }    -- the tee marker blue

local function fontHeight(font)
    local ok, h = pcall(function() return getTextManager():getFontHeight(font) end)
    return ok and h or 14
end

local function lerp(a, b, t) return a + (b - a) * math.max(0, math.min(1, t)) end

function MT.enabled()
    return PG.Options == nil or PG.Options.get("mapTees") ~= false
end

-- Hole length, tee centre to cup centre (squares).
local function lengthOf(hole)
    local dx, dy = (hole.cup.x - hole.tee.x), (hole.cup.y - hole.tee.y)
    return math.floor(math.sqrt(dx * dx + dy * dy) + 0.5)
end

-- One hole on the map: tee box (blue, its real size) with the hole number on a badge, a dotted line down the hole to
-- the cup, and a flag at the cup. Pointing at the badge or the flag highlights that hole and names it.
local function holeShapes(api, hole, half, badge)
    local cx, cy = hole.tee.x + 0.5, hole.tee.y + 0.5
    local h = {
        hole = hole,
        box = {
            api:worldToUIX(cx - half, cy - half), api:worldToUIY(cx - half, cy - half),
            api:worldToUIX(cx + half, cy - half), api:worldToUIY(cx + half, cy - half),
            api:worldToUIX(cx + half, cy + half), api:worldToUIY(cx + half, cy + half),
            api:worldToUIX(cx - half, cy + half), api:worldToUIY(cx - half, cy + half),
        },
        tx = api:worldToUIX(cx, cy), ty = api:worldToUIY(cx, cy),
        fx = api:worldToUIX(hole.cup.x + 0.5, hole.cup.y + 0.5), fy = api:worldToUIY(hole.cup.x + 0.5, hole.cup.y + 0.5),
    }
    local boxH = math.abs(h.box[6] - h.box[2])
    h.bx, h.by = math.floor(h.tx - badge / 2), math.floor(h.ty - badge - boxH / 2 - 2)
    return h
end

local function inside(mx, my, x, y, w, hgt) return mx >= x and mx < x + w and my >= y and my < y + hgt end

-- dotted line, dash and gap in pixels
local function dotted(jo, x1, y1, x2, y2, thick, r, g, b, a)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return end
    local dash, gap = 6, 5
    local ux, uy = dx / len, dy / len
    local t = 0
    while t < len do
        local e = math.min(len, t + dash)
        pcall(jo.DrawLine, jo, nil, x1 + ux * t, y1 + uy * t, x1 + ux * e, y1 + uy * e, thick, r, g, b, a)
        t = e + gap
    end
end

function MT.draw(map)
    if not MT.enabled() or not map or not map.mapAPI then return end
    local api = map.mapAPI
    local zoom = api:getZoomF()
    if zoom < MT.minZoom then return end
    local r, g, b = MT.colour[1], MT.colour[2], MT.colour[3]
    local font = UIFont.Small
    local fh = fontHeight(font)
    local grow = (zoom - MT.labelZoom) / (MT.fullZoom - MT.labelZoom)
    local badge = math.floor(lerp(fh + 2, fh + 8, grow))
    local flagH = math.floor(lerp(10, 18, grow))
    local mx, my = map:getMouseX(), map:getMouseY()
    local half = (PG.Courses.TEE_RADIUS or 2.5)
    local jo = map.javaObject

    local holes, over = {}, nil
    for _, course in ipairs(PG.Courses.list) do
        for _, hole in ipairs(course.holes) do
            if hole.tee then
                local h = holeShapes(api, hole, half, badge)
                holes[#holes + 1] = h
                if inside(mx, my, h.bx, h.by, badge, badge)
                        or inside(mx, my, h.fx - 3, h.fy - flagH - 2, flagH + 4, flagH + 4) then
                    over = h
                end
            end
        end
    end
    if over and not map:isMouseOver() then over = nil end

    -- the lines first, under everything (the pointed-at hole bright and solid)
    if jo then
        for _, h in ipairs(holes) do
            if h == over then
                pcall(jo.DrawLine, jo, nil, h.tx, h.ty, h.fx, h.fy, 2, 1, 1, 1, 0.95)
            else
                dotted(jo, h.tx, h.ty, h.fx, h.fy, 1, r, g, b, over and 0.35 or 0.75)
            end
        end
    end
    for _, h in ipairs(holes) do
        local hot = h == over
        local q = h.box
        -- tee box
        pcall(map.drawPolygon, map, nil, q[1], q[2], q[3], q[4], q[5], q[6], q[7], q[8], r, g, b, hot and 0.9 or 0.55)
        if jo then
            pcall(jo.DrawLine, jo, nil, q[1], q[2], q[3], q[4], 1, 1, 1, 1, 0.9)
            pcall(jo.DrawLine, jo, nil, q[3], q[4], q[5], q[6], 1, 1, 1, 1, 0.9)
            pcall(jo.DrawLine, jo, nil, q[5], q[6], q[7], q[8], 1, 1, 1, 1, 0.9)
            pcall(jo.DrawLine, jo, nil, q[7], q[8], q[1], q[2], 1, 1, 1, 1, 0.9)
        end
        -- flag at the cup: a pole and a red pennant
        local px, py = math.floor(h.fx), math.floor(h.fy)
        if jo then pcall(jo.DrawLine, jo, nil, px, py, px, py - flagH, hot and 2 or 1, 1, 1, 1, 1) end
        local fw = math.floor(flagH * 0.7)
        pcall(map.drawPolygon, map, nil, px, py - flagH, px + fw, py - flagH + fw / 2 - 1, px + fw, py - flagH + fw / 2,
            px, py - flagH + fw, 0.9, 0.15, 0.15, hot and 1 or 0.9)
        map:drawRect(px - 2, py - 2, 4, 4, 1, 1, 1, 1)
        -- the hole number badge on the tee
        local bx, by = h.bx, h.by
        map:drawRect(bx, by, badge, badge, 0.95, hot and 1 or r, hot and 1 or g, hot and 1 or b)
        map:drawRectBorder(bx, by, badge, badge, 1, hot and r or 1, hot and g or 1, hot and b or 1)
        local tr, tg, tb = 1, 1, 1
        if hot then tr, tg, tb = r, g, b end
        map:drawTextCentre(tostring(h.hole.number), bx + badge / 2, by + (badge - fh) / 2, tr, tg, tb, 1, font)
    end

    if over then
        local hole = over.hole
        local text = hole.course.short .. "  -  Hole " .. hole.number .. "  -  Par " .. hole.par .. "  -  " .. lengthOf(hole) .. " m"
        local tw = getTextManager():MeasureStringX(font, text)
        local tx, ty = math.floor(over.bx + badge / 2 - tw / 2 - 6), over.by - fh - 10
        map:drawRect(tx, ty, tw + 12, fh + 6, 0.9, 0.08, 0.1, 0.14)
        map:drawRectBorder(tx, ty, tw + 12, fh + 6, 1, r, g, b)
        map:drawText(text, tx + 6, ty + 3, 1, 1, 1, 1, font)
    end
end

-- after the game's own stash map icons, every frame the map is open
if ISWorldMap and ISWorldMap.renderStashMaps and not MT.wrapped then
    local original = ISWorldMap.renderStashMaps
    function ISWorldMap:renderStashMaps(...)
        local r = original(self, ...)
        local ok, err = pcall(MT.draw, self)
        if not ok and not MT.reported then MT.reported = true; PG.log("map tees:", err) end
        return r
    end
    MT.wrapped = true
end
