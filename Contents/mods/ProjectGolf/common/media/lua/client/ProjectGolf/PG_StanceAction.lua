-- Project Golf - the stance: the player stands over the ball with the club, aims, and swings.
-- An open-ended timed action, so walking away or any other action ends it the vanilla way.

require "TimedActions/ISBaseTimedAction"
require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_World"
require "ProjectGolf/PG_AimUI"

local PG = ProjectGolf
local W = PG.World
local try = W.try

ISGolfStance = ISBaseTimedAction:derive("ISGolfStance")

function ISGolfStance:new(character, worldObj, shot)
    local o = ISBaseTimedAction.new(self, character)
    o.worldObj = worldObj
    o.shot = shot or "drive"
    o.maxTime = -1
    o.stopOnWalk = true
    o.stopOnRun = true
    o.stopOnAim = false
    o.swinging = false

    local sq = worldObj:getSquare()
    o.ballX, o.ballY = W.worldItemPos(worldObj)
    o.ballZ = sq:getZ()
    o.ballSqX, o.ballSqY = sq:getX(), sq:getY()
    o.ballId = worldObj:getItem():getID()
    o.yaw = math.deg(PG.atan2(o.ballY - character:getY(), o.ballX - character:getX()))
    return o
end

function ISGolfStance:getDuration()
    return -1
end

local function holdsClub(character)
    local hand = character:getPrimaryHandItem()
    return hand ~= nil and hand:getFullType() == PG.Items.Club
end

function ISGolfStance:isValid()
    if not holdsClub(self.character) then return false end
    if self.sent then return true end   -- the ball has left: let the follow-through finish
    if not try(self.worldObj, "getSquare") then return false end
    local dx, dy = self.character:getX() - self.ballX, self.character:getY() - self.ballY
    local maxD = PG.Gameplay.maxHitDistance
    return dx * dx + dy * dy <= maxD * maxD
end

function ISGolfStance:waitToStart()
    self.character:faceLocationF(self.ballX, self.ballY)
    return self.character:shouldBeTurning()
end

function ISGolfStance:start()
    if PG.Anims.stance then self:setActionAnim(PG.Anims.stance) end
    self.ui = PG_AimUI.open(self)
end

-- Swing animations: the regular two-handed weapon swing (vanilla clip Bob_AttackBat01_Hit, as in melee 2HDefault),
-- played through the mod's own action nodes in media/AnimSets/player/actions:
--   ProjectGolf_Swing     - full speed, chips and drives
-- Putts use vanilla "Rake" (Bob_IdleRake), a gentle push along the ground, launched on a timer.
-- Both fire "PlaySwingSound" at the start and "ProjectGolfHit" at 25% (where the real attack checks for a hit),
-- so the ball leaves as the club meets it.
-- hitMs: launch time if the hit event never arrives. followMs: how long the follow-through plays after the hit.
PG.SwingAnims = PG.SwingAnims or {
    putt  = { anim = "Rake",              hitMs = 450, followMs = 350 },   -- vanilla rake push; no event, timed
    chip  = { anim = "ProjectGolf_Swing",     event = "ProjectGolfHit", hitMs = 700,  followMs = 450 },
    drive = { anim = "ProjectGolf_Swing",     event = "ProjectGolfHit", hitMs = 700,  followMs = 450 },
}

function ISGolfStance:update()
    local yaw = math.rad(self.yaw or 0)
    self.character:faceLocationF(self.ballX + math.cos(yaw) * 3, self.ballY + math.sin(yaw) * 3)

    if not self.swinging then return end
    local now = PG.now()
    if not self.sent and now >= self.hitDeadline then
        self:launch()                       -- fallback: the animation event did not arrive
    end
    if self.sent and now >= self.endAt then
        self:forceComplete()
    end
end

-- Animation events from the swing (same mechanism as vanilla's sledgehammer action).
function ISGolfStance:animEvent(event, parameter)
    if not self.swinging then return end
    if event == "PlaySwingSound" then
        local club = self.character:getPrimaryHandItem()
        local sound = club and W.try(club, "getSwingSound")
        if sound and sound ~= "" then self.character:playSound(sound) end
    elseif self.swingSpec and event == self.swingSpec.event then
        self:launch()
    end
end

-- The club meets the ball.
function ISGolfStance:launch()
    if self.sent then return end
    self.sent = true
    PG.Client.sendHit(self)
    self:closeUI()
    self.endAt = PG.now() + (self.swingSpec and self.swingSpec.followMs or 300)
end

-- called by the aim UI on release
function ISGolfStance:swing(power, yaw)
    if self.swinging then return end
    self.swinging = true
    self.swingPower = power
    self.yaw = yaw
    local spec = PG.SwingAnims[self.shot] or PG.SwingAnims.drive
    self.swingSpec = spec
    self.hitDeadline = PG.now() + (spec.hitMs or PG.Gameplay.swingDelayMs)
    if spec.anim then self:setActionAnim(spec.anim) end
end

function ISGolfStance:cancelStance()
    if self.swinging then return end
    self:forceStop()
end

function ISGolfStance:closeUI()
    self.closed = true
    if self.ui then
        self.ui:close()
        self.ui = nil
    end
end

function ISGolfStance:stop()
    self:closeUI()
    ISBaseTimedAction.stop(self)
end

function ISGolfStance:perform()
    self:closeUI()
    ISBaseTimedAction.perform(self)
end
