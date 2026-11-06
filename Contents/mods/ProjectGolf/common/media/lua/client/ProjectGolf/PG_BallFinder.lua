-- Project Golf - golf ball finder.
-- In search (foraging) mode, with a golf club on you, every golf ball within range gets a marker and its distance.
-- Vanilla search mode already gives nearby balls its own icon (8 squares); this finds the ones you drove further.

require "ISUI/ISUIElement"
require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_World"
require "ProjectGolf/PG_Render"
require "ProjectGolf/PG_Viewpoint"
require "ProjectGolf/PG_Sandbox"

local PG = ProjectGolf
local R = PG.Render
local W = PG.World
local try = W.try

PG.Finder = PG.Finder or {
    radius   = 40,     -- squares
    rescanMs = 1000,   -- how often to look for balls (the markers redraw every frame)
    needClub = true,
}
local F = PG.Finder
F.balls = {}
F.lastScan = 0

local function isSearching(player)
    if not ISSearchManager or not ISSearchManager.players then return false end
    local manager = ISSearchManager.players[player]   -- do not create a manager just to ask
    return manager ~= nil and manager.isSearchMode == true and not player:getVehicle()
end

local function hasClub(player)
    local hand = player:getPrimaryHandItem()
    if hand and hand:getFullType() == PG.Items.Club then return true end
    return player:getInventory():getFirstTypeRecurse(PG.Items.Club) ~= nil
end

function F.active(player)
    if not player or not isSearching(player) then return false end
    return not F.needClub or hasClub(player)
end

-- Every golf ball within the radius on the player's storey: { x, y, z, d }, nearest first.
function F.scan(player)
    local list = {}
    local px, py, pz = player:getX(), player:getY(), math.floor(player:getZ())
    local r = F.radius
    for iy = math.floor(py) - r, math.floor(py) + r do
        for ix = math.floor(px) - r, math.floor(px) + r do
            local sq = W.square(ix, iy, pz)
            local wobjs = sq and try(sq, "getWorldObjects")
            if wobjs and wobjs:size() > 0 then
                for i = 0, wobjs:size() - 1 do
                    local wo = wobjs:get(i)
                    local item = try(wo, "getItem")
                    if item and item:getFullType() == PG.Items.Ball then
                        local bx, by = W.worldItemPos(wo)
                        local d = math.sqrt((bx - px) ^ 2 + (by - py) ^ 2)
                        if d <= r then list[#list + 1] = { x = bx, y = by, z = pz, d = d } end
                    end
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    return list
end

-- ---- drawing ---------------------------------------------------------------------------------------------------
PG_FinderOverlay = ISUIElement:derive("PG_FinderOverlay")

function PG_FinderOverlay:prerender()
    local player = getPlayer()
    if not F.active(player) then
        F.balls = {}
        return
    end
    local now = PG.now()
    if now - F.lastScan >= F.rescanMs then
        F.lastScan = now
        F.balls = F.scan(player)
    end
    if #F.balls == 0 then return end

    local vp = PG.VP.state()
    local pn = player:getPlayerNum()
    local px, py = player:getX(), player:getY()
    local pulse = 0.65 + 0.35 * math.sin(now / 180)
    local pin = R.texture("ball")
    for _, b in ipairs(F.balls) do
        -- marker floats a little above the ball
        local sx, sy, s = R.toScreen(pn, b.x, b.y, b.z + 0.25, vp, b.z)
        local gx, gy = R.toScreen(pn, b.x, b.y, b.z, vp, b.z)
        if sx and gx then
            local size = math.max(10, math.min(22, (s or 32) * 0.3)) * (0.9 + 0.1 * pulse)
            self:drawRect(sx - 1, sy, 2, gy - sy, 0.6 * pulse, 1, 1, 0.4)               -- stem down to the ball
            if pin then
                self:drawTextureScaled(pin, sx - size / 2, sy - size, size, size, pulse, 1, 1, 0.4)
            else
                self:drawRect(sx - size / 2, sy - size, size, size, pulse, 1, 1, 0.4)
            end
            local d = math.floor(math.sqrt((b.x - px) ^ 2 + (b.y - py) ^ 2) + 0.5)
            self:drawTextCentre(d .. " m", sx, sy - size - 16, 1, 1, 0.6, pulse, UIFont.Small)
        end
    end
end

local function ensureOverlay()
    if F.overlay then return end
    local o = PG_FinderOverlay:new(0, 0, 1, 1)   -- 1x1: draws anywhere, eats no clicks
    o:initialise()
    o:addToUIManager()
    F.overlay = o
end

Events.OnGameStart.Add(ensureOverlay)
