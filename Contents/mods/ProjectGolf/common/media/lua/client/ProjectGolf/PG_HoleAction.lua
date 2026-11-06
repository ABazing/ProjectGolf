-- Project Golf - placing a crafted golf hole as a map tile, and digging one back up.
-- The timed action is only the animation and the wait; the server makes the change (PlaceHole / RemoveHole).

require "TimedActions/ISBaseTimedAction"
require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_World"
require "ProjectGolf/PG_Net"

local PG = ProjectGolf
local W = PG.World

ISGolfHoleAction = ISBaseTimedAction:derive("ISGolfHoleAction")

-- mode: "place" or "remove"
function ISGolfHoleAction:new(character, sq, mode)
    local o = ISBaseTimedAction.new(self, character)
    o.sq = sq
    o.mode = mode
    o.maxTime = PG.HolePlacement.actionTicks
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function ISGolfHoleAction:getDuration()
    return PG.HolePlacement.actionTicks
end

function ISGolfHoleAction:isValid()
    if self.mode == "place" then
        return self.character:getInventory():getFirstTypeRecurse(PG.Items.Flag) ~= nil and W.canPlaceHole(self.sq)
    end
    return W.removableHoleOn(self.sq) ~= nil
end

function ISGolfHoleAction:waitToStart()
    self.character:faceLocation(self.sq:getX(), self.sq:getY())
    return self.character:shouldBeTurning()
end

function ISGolfHoleAction:start()
    self:setActionAnim("Loot")
end

function ISGolfHoleAction:perform()
    PG.sendToServer(self.character, self.mode == "place" and "PlaceHole" or "RemoveHole", {
        x = self.sq:getX(), y = self.sq:getY(), z = self.sq:getZ(),
    })
    ISBaseTimedAction.perform(self)
end

-- Walk next to the square, then place or remove.
function ISGolfHoleAction.queue(player, sq, mode)
    if mode == "place" then
        local flag = player:getInventory():getFirstTypeRecurse(PG.Items.Flag)
        if not flag then return end
        ISInventoryPaneContextMenu.transferIfNeeded(player, flag)
    end
    if luautils.walkAdj(player, sq, true) then
        ISTimedActionQueue.add(ISGolfHoleAction:new(player, sq, mode))
    end
end
