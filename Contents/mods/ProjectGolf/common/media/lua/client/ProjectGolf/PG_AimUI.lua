-- Project Golf - the aiming screen shown while the player stands over the ball.
--
--   Mouse (isometric) or where you look (Viewpoint)  -> aim
--   Hold left mouse                                  -> power meter runs 0 -> 100 -> 0
--   Release                                          -> swing at that power
--   Mouse wheel or 1 / 2 / 3                         -> putt / chip / drive
--   Right mouse or Esc                               -> step away

require "ISUI/ISUIElement"
require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Physics"
require "ProjectGolf/PG_World"
require "ProjectGolf/PG_Render"
require "ProjectGolf/PG_Options"
require "ProjectGolf/PG_Courses"
require "ProjectGolf/PG_Skill"

local PG = ProjectGolf
local R = PG.Render

PG_AimUI = ISUIElement:derive("PG_AimUI")

-- Power meter speed per club, relative to PG.Gameplay.meterSpeed (putts 25% slower, for finer control).
PG.MeterSpeedScale = PG.MeterSpeedScale or {
    putt  = 0.50,
    chip  = 0.75,
    drive = 1.0,
}

-- How far the aim screen looks for a hole to show the flag and "Hole: N m".
PG.HoleFinder = PG.HoleFinder or {
    radius       = 40,   -- squares around the ball (a circle)
    rowsPerFrame = 12,   -- search rows per frame: 80 -> about 14 frames
}

function PG_AimUI:new(action)
    local core = getCore()
    local o = ISUIElement.new(self, 0, 0, core:getScreenWidth(), core:getScreenHeight())
    o.action = action
    o.playerNum = action.character:getPlayerNum()
    o.charging = false
    o.power = 0
    o.chargeStart = 0
    o.yaw = action.yaw or 0
    o.initialShot = PG.Shots[action.shot] and action.shot or "drive"
    -- on a course: the hole being played (the one you teed off on, else from the course layout); elsewhere: the
    -- nearest hole, searched over frames
    local courseHole = PG.Courses.holeFor(action.ballX, action.ballY, action.ballZ,
        PG.Client.currentHole and PG.Client.currentHole(action.character) or nil)
    if courseHole then
        o.courseHole = courseHole
        o.hole = { x = courseHole.cup.x + 0.5, y = courseHole.cup.y + 0.5 }
        o.holeDist = math.sqrt((o.hole.x - action.ballX) ^ 2 + (o.hole.y - action.ballY) ^ 2)
    else
        o.holeScan = PG.World.holeScanner(action.ballX, action.ballY, action.ballZ, PG.HoleFinder.radius)
    end
    o.preview = nil
    o.previewKey = nil
    return o
end

function PG_AimUI:initialise()
    ISUIElement.initialise(self)
    self:setAlwaysOnTop(true)
    self:setWantKeyEvents(true)
end

-- ---- input -----------------------------------------------------------------------------------------------------
function PG_AimUI:isKeyConsumed(key)
    return key == Keyboard.KEY_ESCAPE
        or key == Keyboard.KEY_1 or key == Keyboard.KEY_2 or key == Keyboard.KEY_3
end

function PG_AimUI:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self.action:cancelStance()
    elseif key == Keyboard.KEY_1 then self:setShot("putt")
    elseif key == Keyboard.KEY_2 then self:setShot("chip")
    elseif key == Keyboard.KEY_3 then self:setShot("drive") end
end

function PG_AimUI:onMouseDown(x, y) self:startCharge(); return true end
function PG_AimUI:onMouseUp(x, y) self:release(); return true end
function PG_AimUI:onMouseUpOutside(x, y) self:release(); return true end
function PG_AimUI:onRightMouseDown(x, y) self.action:cancelStance(); return true end

function PG_AimUI:onMouseWheel(del)
    local order = PG.ShotOrder
    local idx = 1
    for i, id in ipairs(order) do if id == self.action.shot then idx = i end end
    idx = ((idx - 1 + (del > 0 and 1 or -1)) % #order) + 1
    self:setShot(order[idx])
    return true
end

function PG_AimUI:setShot(id)
    if self.charging then return end
    self.action.shot = id
    self.previewKey = nil
end

function PG_AimUI:startCharge()
    if self.charging or self.action.swinging then return end
    self.charging = true
    self.chargeStart = PG.now()
    self.power = 0
end

function PG_AimUI:release()
    if not self.charging then return end
    self.charging = false
    if self.power < 0.03 then return end          -- a tap does nothing
    self.action:swing(self.power, self.yaw)
end

-- The shot type must always be valid. If something cleared it, log what we saw once and fall back.
function PG_AimUI:ensureShot()
    local a = self.action
    if PG.Shots[a.shot] then
        self.lastShot = a.shot
        return
    end
    if not self.reportedBadShot then
        self.reportedBadShot = true
        PG.log("stance had no valid shot:", tostring(a.shot), "type", type(a.shot),
            "action type", tostring(a.Type), "last good", tostring(self.lastShot))
    end
    a.shot = self.lastShot or self.initialShot or "drive"
end

-- ---- per frame -------------------------------------------------------------------------------------------------
function PG_AimUI:updateAim(vp)
    local a = self.action
    if vp then
        self.yaw = PG.VP.aimYaw(vp) or self.yaw
    else
        local wx, wy = R.mouseToWorld(self.playerNum, a.ballZ)
        if wx and wy then
            local dx, dy = wx - a.ballX, wy - a.ballY
            if dx * dx + dy * dy > 0.04 then
                self.yaw = math.deg(PG.atan2(dy, dx))
            end
        end
    end
    a.yaw = self.yaw

    if self.charging then
        local phase = (PG.now() - self.chargeStart) / 1000 * PG.Gameplay.meterSpeed * (PG.MeterSpeedScale[a.shot] or 1)
        local saw = (phase * 2) % 2                     -- 0..2
        self.power = 1 - math.abs(saw - 1)              -- 0 -> 1 -> 0 triangle wave, starting at 0
    end
end

function PG_AimUI:updatePreview()
    if not PG.Options.get("showPreview") then self.preview = nil; return end
    local a = self.action
    local power = self.charging and self.power or 1
    local fraction = PG.Skill.previewFraction(PG.Skill.level(a.character), a.shot)
    local key = tostring(a.shot) .. ":" .. math.floor((self.yaw or 0) * 10) .. ":" .. math.floor(power * 100)
        .. ":" .. math.floor(fraction * 100)
    if key == self.previewKey then return end
    self.previewKey = key
    local sim = PG.simulate({
        x = a.ballX, y = a.ballY, z = a.ballZ, shot = a.shot, power = power, yaw = self.yaw,
        distanceMult = PG.distanceMult(a.character, a.shot),
        seed = 7, maxTime = 8, preview = true,
    }, PG.GameWorld)
    -- Aiming skill: you only "read" part of the shot at low levels
    self.previewFraction = fraction
    self.preview = PG.Skill.trimPath(sim.path, fraction)
end

function PG_AimUI:prerender()
    local a = self.action
    if not a or a.closed then return end
    local vp = PG.VP.state()
    self:ensureShot()
    if not a.swinging then
        self:updateAim(vp)
        self:updatePreview()
    end

    if self.preview then
        local r, g, b = 1, 1, 1
        if self.charging then r, g, b = 0.4, 1, 0.4 end
        if PG.VP.ball3D(vp) then
            -- send to the 3D addon only when the path changed
            if self.sentPreview ~= self.previewKey then
                self.sentPreview = self.previewKey
                PG.VP.ballPreview(self.preview, a.ballZ, r, g, b)
            end
        else
            if self.sentPreview then PG.VP.ballClearPreview(); self.sentPreview = nil end
            R.drawPath(self, self.playerNum, self.preview, vp, r, g, b, PG.Gameplay.previewDots, a.ballZ)
        end
    elseif self.sentPreview then
        PG.VP.ballClearPreview(); self.sentPreview = nil
    end

    -- hole search (spread over frames) and the power that reaches it (one test shot per frame)
    if self.holeScan and not self.holeScan.done then
        local ok, done = pcall(self.holeScan.step, self.holeScan, PG.HoleFinder.rowsPerFrame)
        if not ok then self.holeScan.done = true
        elseif done and self.holeScan.best then self.hole, self.holeDist = self.holeScan.best, self.holeScan.dist end
    end
    if not a.swinging then pcall(self.updateTarget, self) end

    -- flag over the hole
    if self.hole then
        local hx, hy, hs = R.toScreen(self.playerNum, self.hole.x, self.hole.y, a.ballZ, vp, a.ballZ)
        if hx then
            local d = math.max(6, math.min(14, (hs or 32) * 0.15))
            self:drawRect(hx - d / 2, hy - d * 2.5, 2, d * 2.5, 0.9, 1, 1, 1)            -- pole
            self:drawRect(hx - d / 2 + 2, hy - d * 2.5, d, d * 0.8, 0.9, 0.9, 0.15, 0.15) -- flag
        end
    end

    -- meter: under the player in isometric, bottom centre in first / third person
    local cx, cy
    if vp then
        cx, cy = self.width / 2, self.height * 0.78
    else
        local pl = a.character
        cx, cy = R.toScreen(self.playerNum, pl:getX(), pl:getY(), pl:getZ(), nil)
        cy = (cy or self.height / 2) + 30
        cx = cx or self.width / 2
    end
    local shot = PG.Shots[a.shot]
    local label = shot.label
    local mult = PG.distanceMult(a.character, a.shot)
    if mult ~= 1 then
        label = label .. "  (Strength " .. PG.strengthLevel(a.character) .. ": " .. math.floor(mult * 100 + 0.5) .. "% distance)"
    end
    if self.charging or a.swinging then
        label = label .. "  -  " .. math.floor((a.swingPower or self.power) * 100 + 0.5) .. "%"
    end
    local tgt = self.target
    -- Aiming skill: a band ("somewhere in here") instead of an exact line at low levels
    local bandLo, bandHi
    if tgt and tgt.power and not tgt.max then
        local half = PG.Skill.markerBand(PG.Skill.level(a.character))
        if half > 0 then bandLo, bandHi = PG.Skill.bandAround(tgt.power, half, tgt.key) end
    end
    R.drawMeter(self, cx, cy, a.swingPower or self.power, label, tgt and tgt.power or nil, tgt and tgt.max or false,
        bandLo, bandHi)

    -- lines under the bar, spaced by the real font height so they never overlap at any UI scale
    local small = R.fontHeight(UIFont.Small)
    local lineY = cy + R.METER_H + 8
    if self.hole then
        local text = "Hole: " .. math.floor(self.holeDist + 0.5) .. " m"
        if self.courseHole then
            text = PG.Courses.label(self.courseHole) .. "  -  " .. math.floor(self.holeDist + 0.5) .. " m"
        end
        if tgt and tgt.max then text = text .. "  (out of reach)" end
        self:drawTextCentre(text, cx, lineY, 0.6, 1, 0.6, 1, UIFont.Small)
        lineY = lineY + small + 4
    end

    -- what the Aiming skill is costing you (only while it still limits something)
    if PG.Skill.enabled() then
        local lvl = PG.Skill.level(a.character)
        local frac = self.previewFraction or 1
        if frac < 1 or PG.Skill.markerBand(lvl) > 0 then
            local text = "Aiming " .. lvl .. ":  reading " .. math.floor(frac * 100 + 0.5) .. "% of the line"
            if self.target and PG.Skill.markerBand(lvl) > 0 then text = text .. "  |  rough power marker" end
            self:drawTextCentre(text, cx, lineY, 0.75, 0.8, 1, 0.9, UIFont.Small)
            lineY = lineY + small + 4
        end
    end

    local hint = "Hold LMB to swing  |  Wheel / 1-2-3: club  |  RMB / Esc: step away"
    self:drawTextCentre(hint, cx, lineY, 0.85, 0.85, 0.85, 0.9, UIFont.Small)
end

-- Which clubs show the power-to-the-hole marker away from the courses (on West Maple / Wellington Heights: all clubs).
PG.TargetShots = PG.TargetShots or { putt = true }

-- ---- power to the hole -----------------------------------------------------------------------------------------
-- Binary search on power with the same physics as the preview (one test shot per frame): the power at which the
-- ball comes to rest at the hole's distance, along the current aim. Redone when the club, the hole or the aim
-- (by more than ~2 degrees) changes.
function PG_AimUI:updateTarget()
    local a = self.action
    -- On a tracked course the hole is known, so every club gets the marker. Elsewhere the hole is only the
    -- nearest one, which is often wrong for long shots, so only putts (PG.TargetShots) get it.
    local allowed = self.courseHole ~= nil or PG.TargetShots[a.shot]
    if not self.hole or not allowed then self.target = nil; return end
    local key = a.shot .. ":" .. math.floor((self.yaw or 0) / 2 + 0.5)
    local t = self.target
    if not t or t.key ~= key then
        t = { key = key, lo = 0, hi = 1, step = 0, done = false, power = t and t.power or nil, max = false }
        self.target = t
    end
    if t.done then return end
    local function restDistance(power)
        local sim = PG.simulate({
            x = a.ballX, y = a.ballY, z = a.ballZ, shot = a.shot, power = power, yaw = self.yaw,
            distanceMult = PG.distanceMult(a.character, a.shot),
            seed = 7, maxTime = 12, preview = true,
        }, PG.GameWorld)
        local dx, dy = sim.final.x - a.ballX, sim.final.y - a.ballY
        return math.sqrt(dx * dx + dy * dy)
    end
    if t.step == 0 then
        -- can full power reach it at all?
        if restDistance(1) < self.holeDist then
            t.power, t.max, t.done = 1, true, true
            return
        end
    else
        local mid = (t.lo + t.hi) / 2
        if restDistance(mid) < self.holeDist then t.lo = mid else t.hi = mid end
        t.power = (t.lo + t.hi) / 2
    end
    t.step = t.step + 1
    if t.step > 9 then t.done = true end
end

-- ---- open / close ----------------------------------------------------------------------------------------------
function PG_AimUI.open(action)
    local ui = PG_AimUI:new(action)
    ui:initialise()
    ui:addToUIManager()
    return ui
end

function PG_AimUI:close()
    if self.sentPreview then PG.VP.ballClearPreview(); self.sentPreview = nil end
    self:setVisible(false)
    self:removeFromUIManager()
end
