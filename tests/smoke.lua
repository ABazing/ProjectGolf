local media = arg[1]
package.path = media .. "/lua/shared/?.lua;" .. media .. "/lua/client/?.lua;" .. media .. "/lua/server/?.lua;" .. package.path
-- ---------- mocks ----------
local clock = 1000000
function getTimestampMs() return clock end
local function List(t) return { size = function() return #t end, get = function(_, i) return t[i + 1] end, _t = t } end
local function derive(base) return function(self, name) local c = {}; setmetatable(c, { __index = self }); c.__index = c; c.Type = name; return c end end
ISUIElement = {}; ISUIElement.__index = ISUIElement; ISUIElement.derive = derive(ISUIElement)
function ISUIElement:new(x, y, w, h) local o = setmetatable({ x = x, y = y, width = w, height = h }, self); return o end
for _, m in ipairs{ "initialise", "setAlwaysOnTop", "setWantKeyEvents", "addToUIManager", "removeFromUIManager", "setVisible" } do ISUIElement[m] = function() end end
DRAWN = 0
function ISUIElement:drawTextureScaled() DRAWN = DRAWN + 1 end
function ISUIElement:drawRect() end; function ISUIElement:drawRectBorder() end
function ISUIElement:drawTextCentre() end
function ISUIElement:drawText() end
ISBaseTimedAction = {}; ISBaseTimedAction.__index = ISBaseTimedAction; ISBaseTimedAction.derive = derive(ISBaseTimedAction)
function ISBaseTimedAction.new(cls, char) return setmetatable({ character = char }, cls) end
function ISBaseTimedAction:setActionAnim(a) self.anim = a end
function ISBaseTimedAction:forceComplete() self.completed = true; self:perform() end
function ISBaseTimedAction:forceStop() self.stopped = true; self:stop() end
function ISBaseTimedAction:stop() end; function ISBaseTimedAction:perform() end
local handlers = {}
Events = setmetatable({}, { __index = function(t, k) local e = { Add = function(f) handlers[k] = handlers[k] or {}; table.insert(handlers[k], f) end }; rawset(t, k, e); return e end })
Keyboard = { KEY_SPACE = 57, KEY_ESCAPE = 1, KEY_1 = 2, KEY_2 = 3, KEY_3 = 4 }
UIFont = { Small = 1, Medium = 2 }
IsoFlagType = { water = "water", solid = "solid", solidtrans = "solidtrans", HoppableN = "HN", HoppableW = "HW" }
function isClient() return false end; function isServer() return false end
function instanceof(o, c) return type(o) == "table" and o._class == c end
function ZombRand(a, b) return 12345 end
function isoToScreenX(p, x, y, z) return (x - y) * 32 end
function isoToScreenY(p, x, y, z) return (x + y) * 16 - z * 96 end
function screenToIsoX() return 30 end; function screenToIsoY() return 10.5 end
function getMouseX() return 0 end; function getMouseY() return 0 end
function getCore() return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end } end
function getTexture() return {} end
function getSoundManager() return { PlayWorldSound = function(_, name) SOUNDS = (SOUNDS or "") .. name .. " " end } end
function addSound() NOISE = true end
-- world: 60x60 grass squares
local squares = {}
local function newItem(full, id) return { _class = "InventoryItem", getFullType = function() return full end, getID = function() return id end,
  setWorldItem = function(self, w) self.wi = w end, getWorldItem = function(self) return self.wi end } end
local function sqAt(x, y, z)
  if x < 0 or y < 0 or x >= 60 or y >= 60 or z ~= 0 then return nil end
  local k = x .. "," .. y; if squares[k] then return squares[k] end
  local wobjs = {}
  local sq; sq = { _class = "IsoGridSquare", wobjs = wobjs,
    getX = function() return x end, getY = function() return y end, getZ = function() return z end,
    getWorldObjects = function() return List(wobjs) end, objs = {}, getObjects = function(self) return List(self.objs) end,
    getMovingObjects = function() return List({}) end,
    Is = function() return false end, isBlockedTo = function() return false end, TreatAsSolidFloor = function() return true end,
    getFloor = function() return { getSprite = function() return { getName = function() return "blends_natural_01_16" end } end } end,
    transmitRemoveItemFromSquare = function(_, wo) for i, v in ipairs(wobjs) do if v == wo then table.remove(wobjs, i) end end end,
    AddWorldInventoryItem = function(_, item, xo, yo, zo, transmit)
      local wo; wo = { _class = "IsoWorldInventoryObject", getItem = function() return item end, getSquare = function() return wo.sq end,
        sq = sq, getWorldPosX = function() return x + xo end, getWorldPosY = function() return y + yo end,
        removeFromWorld = function() end, removeFromSquare = function() wo.sq = nil end, setSquare = function(_, s) wo.sq = s end }
      table.insert(wobjs, wo); item.wi = wo; PLACED = { x = x + xo, y = y + yo }; return item end }
  squares[k] = sq; return sq
end
function getCell() return { getGridSquare = function(_, x, y, z) return sqAt(x, y, z) end } end
local club = newItem("Base.Golfclub", 1)
local md = {}
PLAYER = { getX = function() return 10.0 end, getY = function() return 10.5 end, getZ = function() return 0 end,
  getPrimaryHandItem = function() return club end, getModData = function() return md end, getOnlineID = function() return 0 end,
  getPlayerNum = function() return 0 end, faceLocationF = function() end, shouldBeTurning = function() return false end,
  getUsername = function() return "tester" end, getStats = function() return nil end, getVehicle = function() return nil end,
  setHaloNote = function(_, t) HALO = t end, getEmitter = function() return { playSound = function() end } end }
INV_ITEMS = {}
local INV; INV = { getFirstTypeRecurse = function(_, t) for _, it in ipairs(INV_ITEMS) do if it:getFullType() == t then return it end end end,
  Remove = function(_, it) for i, v in ipairs(INV_ITEMS) do if v == it then table.remove(INV_ITEMS, i) end end end,
  AddItem = function(_, t) local it = newItem(t, 900 + #INV_ITEMS); it.getContainer = function() return INV end; table.insert(INV_ITEMS, it); return it end }
PLAYER.getInventory = function() return INV end
PLAYER.faceLocation = function() end
IsoObject = { new = function(cell, sq, sprite) local md = {}; return { _class = "IsoObject", getModData = function() return md end,
  getSprite = function() return { getName = function() return sprite end, getProperties = function() return { Val = function() end } end } end } end }
function getPlayer() return PLAYER end; function getSpecificPlayer() return PLAYER end
HaloTextHelper = { addText = function(_, t) HALO = t end }
luautils = {}; ISTimedActionQueue = { add = function(a) QUEUED = a end }
ISInventoryPaneContextMenu = {}; ISContextMenu = {}; ISWorldObjectContextMenu = {}
package.preload["ISUI/ISUIElement"] = function() return ISUIElement end
-- window / button mocks for the yardage book
ISCollapsableWindow = setmetatable({}, { __index = ISUIElement }); ISCollapsableWindow.__index = ISCollapsableWindow
ISCollapsableWindow.derive = derive(ISCollapsableWindow)
function ISCollapsableWindow:new(x, y, w, h) return ISUIElement.new(self, x, y, w, h) end
function ISCollapsableWindow:createChildren() end
function ISCollapsableWindow:render() end
function ISCollapsableWindow:close() end
function ISCollapsableWindow:setResizable() end
function ISCollapsableWindow:titleBarHeight() return 16 end
function ISUIElement:addChild() end
function ISUIElement:setStencilRect() end; function ISUIElement:clearStencilRect() end
function ISUIElement:drawTextRight() end
ISButton = setmetatable({}, { __index = ISUIElement }); ISButton.__index = ISButton
function ISButton:new(x, y, w, h, title, target, onclick) return ISUIElement.new(self, x, y, w, h) end
function ISButton:setBackgroundRGBA() end
function ISButton:setTitle(t) self.title = t end
function ISCollapsableWindow:onMouseDown() return "window" end
function ISUIElement:isMouseOver() return false end
function ISUIElement:getMouseX() return 0 end; function ISUIElement:getMouseY() return 0 end
package.preload["ISUI/ISCollapsableWindow"] = function() return ISCollapsableWindow end
package.preload["ISUI/ISButton"] = function() return ISButton end
package.preload["TimedActions/ISBaseTimedAction"] = function() return ISBaseTimedAction end
-- ---------- load the mod like the game does ----------
for _, f in ipairs{ "ProjectGolf/PG_Config", "ProjectGolf/PG_Physics", "ProjectGolf/PG_World", "ProjectGolf/PG_Net",
  "ProjectGolf/PG_Viewpoint", "ProjectGolf/PG_Options", "ProjectGolf/PG_Render", "ProjectGolf/PG_AimUI", "ProjectGolf/PG_StanceAction",
  "ProjectGolf/PG_Client", "ProjectGolf/PG_ContextMenu", "ProjectGolf/PG_BallFinder", "ProjectGolf/PG_Server", "ProjectGolf/PG_CourseBuilder", "ProjectGolf/PG_Guide" } do require(f) end
local PG = ProjectGolf
local ok = 0; local function check(n, c) print((c and "PASS  " or "FAIL  ") .. n); if c then ok = ok + 1 end end
-- place a ball at 10.5,10.5
local ball = newItem("Base.GolfBall", 77)
sqAt(10, 10, 0):AddWorldInventoryItem(ball, 0.5, 0.5, 0)
local wo = PG.World.findBall(sqAt(10, 10, 0))
check("findBall finds the ball", wo ~= nil)
-- context menu offers Golf
local opts = {}
local ctx = { addOption = function(_, name) table.insert(opts, name); return {} end, addSubMenu = function() end }
ISContextMenu.getNew = function() return ctx end
for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, ctx, { wo }, false) end
check("context menu: Golf > Putt/Chip/Drive", table.concat(opts, ",") == "Golf,Putt,Chip,Drive,Tips / Scorecard")
-- stance -> aim -> swing
local st = ISGolfStance:new(PLAYER, wo, "drive")
check("stance valid", st:isValid())
st:start()
check("aim UI opened", st.ui ~= nil)
st.ui:prerender()                       -- aims at mouse world (30, 10.5) => yaw 0
check("aim yaw from mouse = east", math.abs(st.yaw) < 0.01)
st.ui:onMouseDown(0, 0); clock = clock + 590; st.ui:prerender()   -- hold ~0.59s at 0.85 Hz => ~100%
st.ui:onMouseUp(0, 0)
check("swing started with power ~1", st.swinging and st.swingPower > 0.95)
clock = clock + 300; st:update()
check("no launch before the club strikes", not st.sent)
st:animEvent("ProjectGolfHit")
check("ball launches on the swing's hit event, UI closes", st.sent and st.ui == nil and not st.completed)
check("stance stays valid during the follow-through", st:isValid())
clock = clock + 600; st:update()
check("stance completes after the follow-through", st.completed)
check("ball removed from the start square", PG.World.findBall(sqAt(10, 10, 0)) == nil)
check("zombies hear the hit", NOISE == true)
check("flight playing", #PG.Client.flights == 1)
check("stroke counted", md.ProjectGolf.strokes == 1)
-- play the flight
for i = 1, 400 do clock = clock + 16; PG.Client.overlay:prerender(); for _, f in ipairs(handlers.OnTick) do f() end end
check("ball drawn during flight", DRAWN > 50)
check("sounds played: " .. tostring(SOUNDS), SOUNDS and SOUNDS:find("ProjectGolf_Drive") and SOUNDS:find("ProjectGolf_Overhit") and SOUNDS:find("ProjectGolf_Bounce"))
check("flight finished", #PG.Client.flights == 0)
-- (a full drive now carries past the 60-square mock world's east edge and comes back off it)
check("ball placed back down far east: " .. (PLACED and ("%.1f,%.1f"):format(PLACED.x, PLACED.y) or "nil"), PLACED and PLACED.x > 35)
check("result halo: " .. tostring(HALO), HALO and HALO:find("stroke 1"))
-- server rate limit + validation
local before = #PG.Client.flights
PG.ServerCommands.Hit(PLAYER, { x = 10, y = 10, z = 0, shot = "drive", power = 1, yaw = 0 })
check("hit on a missing ball is ignored", #PG.Client.flights == before)
PG.ServerCommands.Hit(PLAYER, { x = "a", shot = "nope" })
check("garbage command ignored", #PG.Client.flights == before)
-- strength: a Strength 10 golfer's drive goes further than the default one
Perks = { Strength = "Strength" }
PLAYER.getPerkLevel = function() return 10 end
local ball2 = newItem("Base.GolfBall", 78)
sqAt(5, 30, 0):AddWorldInventoryItem(ball2, 0.5, 0.5, 0)
PLAYER.getX = function() return 5.0 end; PLAYER.getY = function() return 30.5 end
clock = clock + 5000; PLACED = nil
ZombRand = function() return 1 end   -- tiny spread
local realSim, seenMult = PG.simulate, nil
PG.simulate = function(input, world) seenMult = input.distanceMult; return realSim(input, world) end
PG.ServerCommands.Hit(PLAYER, { x = 5, y = 30, z = 0, id = 78, shot = "drive", power = 1, yaw = 0 })
PG.simulate = realSim
check("server applies the hitter's Strength (mult " .. tostring(seenMult) .. ")", math.abs(seenMult - PG.Strength.maxMult * (PG.Strength.boost or 1)) < 1e-9)
-- map golf holes (course flag tiles)
local function tile(name, custom, group)
  return { _class = "IsoObject", getSprite = function() return { getName = function() return name end,
    getProperties = function() return { Val = function(_, k) if k == "CustomName" then return custom elseif k == "GroupName" then return group end end } end } end }
end
local W = PG.World
local hsq = sqAt(30, 40, 0)
table.insert(hsq.objs, tile("recreational_golf_01_3", "Flag", "Golf Course"))
hsq.Is = function(_, f) return f == "solid" end           -- worst case: the flag tile is solid
table.insert(sqAt(31, 40, 0).objs, tile("location_community_church_01_0", "Bench", nil))
check("map golf tile detected as a hole", #W.cups(30, 40, 0) == 1 and W.cups(30, 40, 0)[1].map == true)
check("unrelated tile is not a hole", #W.cups(31, 40, 0) == 0)
check("hole square is not solid for the ball", W.info(30, 40, 0).solid == false)
local fakeBall = { _class = "IsoWorldInventoryObject", getSprite = function() return { getName = function() return "Item_GolfBall" end } end }
check("a dropped golf ball is never a hole", W.isMapHole(fakeBall) == false)
local scan = W.holeScanner(25.5, 40.5, 0, 10)
for _ = 1, 50 do if scan:step(12) then break end end
check("hole scanner finds the nearest hole (" .. tostring(scan.dist) .. " m)", scan.best and math.abs(scan.dist - 5) < 1e-9)
-- putt into the map hole: 5 squares away, slow
local sim = PG.simulate({ x = 25.5, y = 40.5, z = 0, shot = "putt", power = 5.4 / 14, yaw = 0, seed = 3 }, PG.GameWorld)
check("putt drops into the map hole (" .. sim.result .. ")", sim.result == "cup")
-- exact sprite list works too, and the inspect tool reports it
PG.MapHoles.patterns = {}; PG.MapHoles.sprites["my_custom_hole_7"] = true
check("the real course hole sprite is listed", W.isMapHole(tile("recreational_sports_01_48", nil, nil)))
table.insert(sqAt(35, 40, 0).objs, tile("my_custom_hole_7", nil, nil))
check("hole listed by exact sprite name", #W.cups(35, 40, 0) == 1)
isDebugEnabled = function() return true end
check("inspect tool (debug mode) says golf hole", (function() HALO = nil
  local opts2 = {}; local c2 = { addOption = function(_, n, t, fn, a1) opts2[n] = { fn, t, a1 }; return {} end, addSubMenu = function() end }
  ISContextMenu.getNew = function() return c2 end
  for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, c2, { { getSquare = function() return sqAt(35, 40, 0) end } }, false) end
  local o = opts2["Inspect this tile"]; if not o then return false end
  o[1](o[2], o[3]); return HALO == "Golf hole here!" end)())
-- crafted holes: place -> putt in -> pick up
PG.MapHoles.patterns = { "golf" }
local hs = sqAt(40, 20, 0)
hs.getCell = function() return {} end
hs.AddTileObject = function(self, o) table.insert(self.objs, o) end
hs.RemoveTileObject = function(self, o) for i, v in ipairs(self.objs) do if v == o then table.remove(self.objs, i) end end end
PLAYER.getX = function() return 39.5 end; PLAYER.getY = function() return 20.5 end
INV:AddItem("ProjectGolf.GolfFlag")
luautils.walkAdj = function() return true end
ISInventoryPaneContextMenu.transferIfNeeded = function() end
local menu = {}
local c3 = { addOption = function(_, n, t, fn, a1) menu[n] = { fn, t, a1, opt = {} }; return menu[n].opt end, addSubMenu = function() end }
ISContextMenu.getNew = function() return c3 end
for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, c3, { { getSquare = function() return hs end } }, false) end
check("menu offers Place golf hole here", menu["Place golf hole here"] ~= nil and not menu["Place golf hole here"].opt.notAvailable)
local m = menu["Place golf hole here"]; m[1](m[2], m[3])
local act = QUEUED
check("place action queued and valid", act and act.mode == "place" and act:isValid())
act:perform()
check("tile placed with the hole sprite", #hs.objs == 1 and W.mapHoleOn(hs) and W.removableHoleOn(hs) ~= nil)
check("item used up: " .. tostring(HALO), #INV_ITEMS == 0 and HALO == "Golf hole placed")
check("placed hole works as a cup", #W.cups(40, 20, 0) == 1)
local sim2 = PG.simulate({ x = 35.5, y = 20.5, z = 0, shot = "putt", power = 5.4 / 14, yaw = 0, seed = 3 }, PG.GameWorld)
check("putt drops into the placed hole (" .. sim2.result .. ")", sim2.result == "cup")
PG.ServerCommands.PlaceHole(PLAYER, { x = 40, y = 20, z = 0 })
check("can't place twice without an item / on a hole", #hs.objs == 1)
menu = {}
for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, c3, { { getSquare = function() return hs end } }, false) end
check("menu offers Pick up golf hole", menu["Pick up golf hole"] ~= nil and menu["Place golf hole here"] == nil)
m = menu["Pick up golf hole"]; m[1](m[2], m[3]); QUEUED:perform()
check("tile removed and item returned", #hs.objs == 0 and #INV_ITEMS == 1 and INV_ITEMS[1]:getFullType() == "ProjectGolf.GolfFlag")
-- map course holes (_48) can't be picked up
local ms = sqAt(42, 20, 0); table.insert(ms.objs, tile("recreational_sports_01_48", nil, nil))
check("map course hole is not removable", W.removableHoleOn(ms) == nil)
PLAYER.getX = function() return 41.5 end
PG.ServerCommands.RemoveHole(PLAYER, { x = 42, y = 20, z = 0 })
check("server refuses to remove a map hole", #ms.objs == 1 and #INV_ITEMS == 1)
-- too far away
PLAYER.getX = function() return 10 end
PG.ServerCommands.PlaceHole(PLAYER, { x = 44, y = 20, z = 0 })
check("server refuses placing from far away", #INV_ITEMS == 1)
-- tennis nets (_49) are not golf holes; a net the old version placed can still be picked up
check("tennis net is not a golf hole", not W.isMapHole(tile("recreational_sports_01_49", nil, nil)))
local ts = sqAt(46, 20, 0); local net = tile("recreational_sports_01_49", nil, nil)
local netMd = { ProjectGolfHole = true }; net.getModData = function() return netMd end
table.insert(ts.objs, net)
local plainNet = sqAt(47, 20, 0); table.insert(plainNet.objs, tile("recreational_sports_01_49", nil, nil))
check("net placed by the mod can be picked up", W.removableHoleOn(ts) == net)
check("map tennis net can't be picked up", W.removableHoleOn(plainNet) == nil)
check("placed tile uses the course hole sprite", PG.HolePlacement.sprite == "recreational_sports_01_48")
-- forgiving right-click: balls near the click, nearest wins
local function golfMenuFor(sqClicked)
  local names = {}
  local cm = { addOption = function(_, n, t, fn, a1) names[#names + 1] = n; return {} end, addSubMenu = function() end }
  ISContextMenu.getNew = function() return cm end
  QUEUED = nil
  for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, cm, { { getSquare = function() return sqClicked end } }, false) end
  return table.concat(names, ",")
end
INV_ITEMS = {}
local fb = newItem("Base.GolfBall", 501); sqAt(50, 50, 0):AddWorldInventoryItem(fb, 0.5, 0.5, 0)
PLAYER.getX = function() return 20.5 end; PLAYER.getY = function() return 20.5 end
check("click on the ball's square", golfMenuFor(sqAt(50, 50, 0)):find("Drive") ~= nil)
check("click one square off", golfMenuFor(sqAt(51, 50, 0)):find("Drive") ~= nil)
check("click diagonally next to it", golfMenuFor(sqAt(49, 49, 0)):find("Drive") ~= nil)
check("click 3 squares away finds nothing", golfMenuFor(sqAt(53, 50, 0)):find("Drive") == nil)
-- near yourself: ball within reach is found even when clicking a bit further off
PLAYER.getX = function() return 50.5 end; PLAYER.getY = function() return 52.0 end
check("click near yourself finds the ball in reach", golfMenuFor(sqAt(52, 53, 0)):find("Drive") ~= nil)
-- two balls: nearest to the click is used
local fb2 = newItem("Base.GolfBall", 502); sqAt(52, 50, 0):AddWorldInventoryItem(fb2, 0.5, 0.5, 0)
PLAYER.getX = function() return 52.5 end; PLAYER.getY = function() return 51.2 end
local pick
local cm2 = { addOption = function(_, n, t, fn, a1) if n == "Drive" then pick = a1 end; return {} end, addSubMenu = function() end }
ISContextMenu.getNew = function() return cm2 end
for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, cm2, { { getSquare = function() return sqAt(52, 51, 0) end } }, false) end
check("nearest of two balls is chosen", pick and pick:getItem():getID() == 502)
-- ball finder in search mode
local F = PG.Finder
PLAYER.getX = function() return 51.0 end; PLAYER.getY = function() return 50.5 end; PLAYER.getZ = function() return 0 end
PLAYER.getPlayerNum = function() return 0 end
ISSearchManager = { players = {} }
check("finder off outside search mode", not F.active(PLAYER))
ISSearchManager.players[PLAYER] = { isSearchMode = true }
check("finder on in search mode with a club", F.active(PLAYER))
local farBall = newItem("Base.GolfBall", 601); sqAt(51, 15, 0):AddWorldInventoryItem(farBall, 0.5, 0.5, 0)  -- 35.5 away
local found = F.scan(PLAYER)
check("finder lists balls nearest first (" .. #found .. ")", #found >= 3 and found[1].d <= found[#found].d)
check("finder sees a ball 35 squares away", found[#found].d > 35 and found[#found].d <= 40)
local tooFar = newItem("Base.GolfBall", 602); sqAt(51, 5, 0):AddWorldInventoryItem(tooFar, 0.5, 0.5, 0)       -- 45 away
check("finder ignores balls beyond its radius", #F.scan(PLAYER) == #found)
for _, f in ipairs(handlers.OnGameStart) do f() end
DRAWN = 0; F.lastScan = 0; F.overlay:prerender()
check("finder draws markers", DRAWN >= #found)
local savedHand = PLAYER.getPrimaryHandItem; PLAYER.getPrimaryHandItem = function() return nil end
INV_ITEMS = {}
check("finder needs a club", not F.active(PLAYER))
PLAYER.getPrimaryHandItem = savedHand
-- hole scanner: 80-square circle, a few rows per frame
local hsq2 = sqAt(30, 40, 0)   -- the map hole tile added earlier
local scan = W.holeScanner(5.5, 40.5, 0, 80)
local frames = 0
while not scan:step(12) do frames = frames + 1 end
check("scanner finds the hole 25 squares away in ~14 frames (" .. frames .. ")", scan.best and math.abs(scan.dist - 25) < 1e-9 and frames >= 12 and frames <= 14)
local s2 = W.holeScanner(5.5, 40.5, 0, 20); while not s2:step(12) do end
check("scanner respects its radius", s2.best == nil)
-- swing anims: drive uses the two-handed floor swing, putt the rake push; fallback timer launches without events
check("drive uses the two-handed swing", PG.SwingAnims.drive.anim == "ProjectGolf_Swing" and st.anim == "ProjectGolf_Swing")
local st2 = ISGolfStance:new(PLAYER, { getSquare = function() return sqAt(1, 1, 0) end,
  getItem = function() return newItem("Base.GolfBall", 999) end, getWorldPosX = function() return 1.5 end, getWorldPosY = function() return 1.5 end }, "putt")
st2.ui = { close = function() end }
st2:swing(0.5, 0)
check("putt uses the rake push", st2.anim == "Rake")
local sentBefore = PG.Client.sendHit; local fired = false
PG.Client.sendHit = function() fired = true end
clock = clock + 460; st2:update()
check("putt launches on its timer", fired and st2.sent)
PG.Client.sendHit = sentBefore
-- power to the hole: the solved power puts the ball at the hole's distance
local function solve(shot, bx, by, hole)
  local fake = setmetatable({ action = { shot = shot, ballX = bx, ballY = by, ballZ = 0, character = PLAYER },
    yaw = 0, hole = hole, holeDist = math.sqrt((hole.x - bx) ^ 2 + (hole.y - by) ^ 2) }, { __index = PG_AimUI })
  for i = 1, 12 do fake:updateTarget() end
  return fake.target, fake.holeDist
end
PLAYER.getPerkLevel = function() return 5 end
PG.TargetShots = { putt = true, chip = true, drive = true }   -- the solver itself works for every club
for _, case in ipairs{ { "putt", 6 }, { "chip", 12 }, { "drive", 30 } } do
  local shot, d = case[1], case[2]
  local t, hd = solve(shot, 5.5, 30.5, { x = 5.5 + d, y = 30.5 })
  local sim = PG.simulate({ x = 5.5, y = 30.5, z = 0, shot = shot, power = t.power, yaw = 0, seed = 7, preview = true,
    distanceMult = PG.distanceMult(PLAYER, shot) }, PG.GameWorld)
  local err = math.abs((sim.final.x - 5.5) - hd)
  check(("%s target %.0f%% stops the ball %.2f squares from a %d-square hole"):format(shot, t.power * 100, err, d), t.done and not t.max and err < 0.4)
end
PG.TargetShots = { putt = true }
check("no marker for drives", solve("drive", 5.5, 30.5, { x = 35.5, y = 30.5 }) == nil)
local tfar = solve("putt", 5.5, 30.5, { x = 45.5, y = 30.5 })
check("hole out of putting range is flagged", tfar.max and tfar.power == 1)
-- gauge draws without errors at a few powers
local g = setmetatable({}, { __index = ISUIElement })
for _, pw in ipairs{ 0, 0.5, 0.97 } do PG.Render.drawMeter(g, 400, 300, pw, "Drive", 0.6, false); PG.Render.drawMeter(g, 400, 300, pw, "Putt", nil, true) end
check("meter draws with the hole marker", true)
-- overswing: scaled spread and mishits
local S = PG.Server
check("no overswing below the line", S.overswingAmount(0.9) == 0)
check("overswing grows to 1 at full power", math.abs(S.overswingAmount(1) - 1) < 1e-9 and S.overswingAmount(0.96) > 0.4)
local shotD = PG.Shots.drive
local sNormal, sFull = S.spreadFor(PLAYER, shotD, 0.9), S.spreadFor(PLAYER, shotD, 1.0)
check(("spread at 100%% (%.1f) far wider than at 90%% (%.1f)"):format(sFull, sNormal), sFull >= sNormal + 11.9)
-- count mishits at full power over many seeded hits (server path), via the broadcast flag
local mishits, total = 0, 0
local realBroadcast = PG.broadcast
PG.broadcast = function(cmd, args) if cmd == "Flight" then total = total + 1; if args.mishit then mishits = mishits + 1 end end end
local seedN = 0; ZombRand = function() seedN = seedN + 7919; return seedN end
PLAYER.getX = function() return 20.0 end; PLAYER.getY = function() return 50.5 end
for i = 1, 60 do
  local b = newItem("Base.GolfBall", 7000 + i); sqAt(20, 50, 0):AddWorldInventoryItem(b, 0.5, 0.5, 0)
  clock = clock + 5000
  PG.ServerCommands.Hit(PLAYER, { x = 20, y = 50, z = 0, id = 7000 + i, shot = "drive", power = 1, yaw = 0 })
end
PG.broadcast = realBroadcast
check(("full-power drives mishit about 60%% of the time (%d/%d)"):format(mishits, total), total == 60 and mishits >= 25 and mishits <= 47)
-- cup: rim hits must be slower than centre hits
local cfgP = PG.Physics
local function cupSim(offsetY, power)
  return PG.simulate({ x = 10.5, y = 60.5 + offsetY, z = 0, shot = "putt", power = power, yaw = 0, seed = 3 },
    { info = function() return { floor = true, surface = "grass" } end, blocked = function() end, zombies = function() return {} end,
      cups = function(ix, iy) if ix == 15 and iy == 60 then return { { x = 15.5, y = 60.5 } } end return {} end })
end
local function fastestSink(offsetY)
  local best = 0
  for p = 0.35, 0.8, 0.005 do if cupSim(offsetY, p).result == "cup" then best = p end end
  return best
end
local centre, rim = fastestSink(0), fastestSink(cfgP.cupRadius * 0.85)
check(("rim needs a softer putt than dead centre (centre %.3f, rim %.3f)"):format(centre, rim), centre > rim and rim > 0)
-- water: B42 flag API (getProperties():has) and lake/river floors
local wsq = sqAt(44, 44, 0)
wsq.getProperties = function() return { has = function(_, f) return f == "water" end } end
check("water flag read through getProperties():has", W.info(44, 44, 0).water == true)
local rsq = sqAt(45, 44, 0)
rsq.getFloor = function() return { getSprite = function() return { getName = function() return "blends_natural_02_5" end } end } end
check("lake/river floor (blends_natural_02) counts as water", W.info(45, 44, 0).water == true)
check("grass is not water", W.info(43, 44, 0).water == false)
local splash = PG.simulate({ x = 40.5, y = 44.5, z = 0, shot = "putt", power = 1, yaw = 0, seed = 1 }, PG.GameWorld)
check("a putt into the pond splashes (" .. splash.result .. ")", splash.result == "water")
check("no hole on water", W.canPlaceHole(wsq) == false)
-- solid and fence flags now work through the same path
local fsq = sqAt(46, 46, 0)
fsq.getProperties = function() return { has = function(_, f) return f == "solid" end } end
check("solid flag read through getProperties():has", W.info(46, 46, 0).solid == true)
-- golf lifts mood
CharacterStat = { BOREDOM = { getMaximumValue = function() return 100 end, getMinimumValue = function() return 0 end },
                  UNHAPPINESS = { getMaximumValue = function() return 100 end, getMinimumValue = function() return 0 end } }
local mood = { [CharacterStat.BOREDOM] = 50, [CharacterStat.UNHAPPINESS] = 40 }
local savedStats = PLAYER.getStats
PLAYER.getStats = function() return { get = function(_, st) return mood[st] end, set = function(_, st, v) mood[st] = v end } end
PG.Server.adjustMood(PLAYER, PG.Mood.shot)
check("a swing lowers boredom 3 and unhappiness 1", mood[CharacterStat.BOREDOM] == 47 and mood[CharacterStat.UNHAPPINESS] == 39)
PG.Server.adjustMood(PLAYER, PG.Mood.sunk)
check("sinking it lowers them more", mood[CharacterStat.BOREDOM] == 39 and mood[CharacterStat.UNHAPPINESS] == 33)
mood[CharacterStat.BOREDOM] = 1
PG.Server.adjustMood(PLAYER, PG.Mood.sunk)
check("never below zero", mood[CharacterStat.BOREDOM] == 0)
-- through a real hit
mood[CharacterStat.BOREDOM] = 50; mood[CharacterStat.UNHAPPINESS] = 40
PLAYER.getX = function() return 20.0 end; PLAYER.getY = function() return 50.5 end
local mb = newItem("Base.GolfBall", 8800); sqAt(20, 50, 0):AddWorldInventoryItem(mb, 0.5, 0.5, 0)
clock = clock + 5000
PG.ServerCommands.Hit(PLAYER, { x = 20, y = 50, z = 0, id = 8800, shot = "putt", power = 0.3, yaw = 0 })
check("hitting the ball lifts mood", mood[CharacterStat.BOREDOM] == 47)
PLAYER.getStats = savedStats; CharacterStat = nil
-- sandbox toggles and Aiming XP
check("no SandboxVars: everything on by default", PG.sandbox("MoodBoost", true) == true and PG.sandbox("AimingSkill", true) == true)
Perks = Perks or {}; Perks.Aiming = "Aiming"; Perks.Strength = "Strength"
local xpLog = {}
addXp = function(pl, perk, amount) xpLog[#xpLog + 1] = { perk, amount } end
local function hitOnce(shot, id, power)
  local b = newItem("Base.GolfBall", id); sqAt(20, 50, 0):AddWorldInventoryItem(b, 0.5, 0.5, 0)
  clock = clock + 5000
  PG.ServerCommands.Hit(PLAYER, { x = 20, y = 50, z = 0, id = id, shot = shot, power = power or 0.5, yaw = 0 })
end
PLAYER.getX = function() return 20.0 end; PLAYER.getY = function() return 50.5 end
hitOnce("drive", 9001); hitOnce("putt", 9002)
check("Aiming XP: 1 per drive, 0.5 per putt", #xpLog == 2 and xpLog[1][1] == "Aiming" and xpLog[1][2] == 1 and xpLog[2][2] == 0.5)
SandboxVars = { ProjectGolf = { AimingXP = false } }
xpLog = {}; hitOnce("drive", 9004)
check("Aiming XP can be switched off", #xpLog == 0)
-- zombies always hear a swing; Strength always adds distance
NOISE = false; hitOnce("drive", 9005)
check("zombies hear every swing", NOISE == true)
PLAYER.getPerkLevel = function() return 10 end
check("Strength 10 adds distance", PG.distanceMult(PLAYER, "drive") > 1)
-- mood toggle
CharacterStat = { BOREDOM = {}, UNHAPPINESS = {} }
local mood2 = { [CharacterStat.BOREDOM] = 50, [CharacterStat.UNHAPPINESS] = 40 }
local savedStats2 = PLAYER.getStats
PLAYER.getStats = function() return { get = function(_, st) return mood2[st] end, set = function(_, st, v) mood2[st] = v end } end
SandboxVars.ProjectGolf.MoodBoost = false
PG.Server.adjustMood(PLAYER, PG.Mood.shot)
check("mood boost can be switched off", mood2[CharacterStat.BOREDOM] == 50)
PLAYER.getStats = savedStats2; CharacterStat = nil
-- the map's own course holes can never be picked up
local cs = sqAt(48, 20, 0); table.insert(cs.objs, tile("recreational_sports_01_48", nil, nil))
check("course holes are not removable", W.removableHoleOn(cs) == nil)
SandboxVars = nil
-- players never see Inspect
isDebugEnabled = function() return false end
local seen = {}
local cm4 = { addOption = function(_, n) seen[n] = true; return {} end, addSubMenu = function() end }
ISContextMenu.getNew = function() return cm4 end
INV_ITEMS = {}
for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, cm4, { { getSquare = function() return sqAt(35, 40, 0) end } }, false) end
check("club in hand: Golf > Tips / Scorecard anywhere, never Inspect", seen["Golf"] and seen["Tips / Scorecard"] and not seen["Inspect this tile"])
do
  local savedHand2 = PLAYER.getPrimaryHandItem; PLAYER.getPrimaryHandItem = function() return nil end
  seen = {}
  for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, cm4, { { getSquare = function() return sqAt(35, 40, 0) end } }, false) end
  check("no club: no empty Golf menu", not seen["Golf"])
  PLAYER.getPrimaryHandItem = savedHand2
end
-- courses
local C = PG.Courses
check("tracked courses: West Maple 18 only (Wellington Heights parked), no mini golf", #C.list == 1 and #C.list[1].holes == 18
  and #C.parked == 1 and C.parked[1].id == "WellingtonHeights" and #C.parked[1].holes == 9)
check("parked course is not tracked", C.holeFor(13100, 2300, 0) == nil and C.teeAt(13016.5, 2275.5) == nil and C.holeAtCup(13029, 2301, 0) == nil)
local h13 = C.holeFor(6200, 6152, 0)       -- on the fairway between hole 13's tee (6247,6155) and cup (6135,6149)
check("ball on hole 13's fairway -> hole 13 (" .. tostring(h13 and h13.number) .. ")", h13 and h13.number == 13 and h13.par == 4)
check("label", C.label(h13) == "West Maple Country Club  -  Hole 13  -  Par 4")
check("off course -> nil", C.holeFor(100, 100, 0) == nil)
check("tee box lookup", C.teeAt(6247.5, 6156.5) == h13 and C.teeAt(6247.5, 6160.5) == nil)
check("mini golf is not tracked", C.holeFor(12356.4, 1304.6, 0) == nil and C.holeAtCup(12356, 1304, 0) == nil)
-- course builder: tee box square + missing cup + runs once
local B = PG.CourseBuilder
ModDataStore = {}
ModData = { getOrCreate = function(k) ModDataStore[k] = ModDataStore[k] or {}; return ModDataStore[k] end }
getSprite = function(n) return { name = n } end
IsoFlagType.canBeRemoved = "canBeRemoved"
instanceItem = function(t) return newItem(t, 5000) end
local function bigSq(x, y)
  local floorSprite = "blends_natural_01_64"
  local floor = { getSprite = function(self) return { getName = function() return self.spr and self.spr.name or floorSprite end } end,
                  setSprite = function(self, sp) self.spr = sp end, getObjectIndex = function() return 0 end }
  local grass = { getProperties = function() return { has = function(_, f) return f == "canBeRemoved" end } end, getObjectIndex = function() return 1 end }
  local sq = { objs = { floor, grass }, items = {}, x = x, y = y }
  sq.getX = function() return x end; sq.getY = function() return y end; sq.getZ = function() return 0 end
  sq.getFloor = function() return floor end; sq.getCell = function() return {} end
  sq.getObjects = function(self) return List(self.objs) end
  sq.getWorldObjects = function(self) return List({}) end
  sq.RemoveTileObject = function(self, o) for i, v in ipairs(self.objs) do if v == o then table.remove(self.objs, i) end end end
  sq.AddTileObject = function(self, o) table.insert(self.objs, o) end
  sq.disableErosion = function(self) self.noErosion = true end
  sq.AddWorldInventoryItem = function(self, item) table.insert(self.items, item); return item end
  sq.floor = floor
  return sq
end
local teeSq = bigSq(6247, 6155)
for _, f in ipairs(handlers.LoadGridsquare) do f(teeSq) end
check("tee box: grass laid with the hole's floor", teeSq.floor.spr and teeSq.floor.spr.name == "blends_natural_01_16")
check("tee box: tall grass mown and kept mown", #teeSq.objs == 1 and teeSq.noErosion)
local markerCount = 0
for key, j in pairs(B.jobs) do if j.floor and #j.markers > 0 then local hx, hy = key:match("(%d+),(%d+)"); hx, hy = tonumber(hx), tonumber(hy)
  if math.abs(hx - 6247) <= 3 and math.abs(hy - 6155) <= 3 then markerCount = markerCount + #j.markers end end end
check("two tee markers per tee box", markerCount == 2)
local cupSq = bigSq(6301, 6656)     -- West Maple hole 3: addCup
for _, f in ipairs(handlers.LoadGridsquare) do f(cupSq) end
check("missing cup added", W.mapHoleOn(cupSq))
local before = #cupSq.objs
for _, f in ipairs(handlers.LoadGridsquare) do f(cupSq) end
check("each square is built only once", #cupSq.objs == before)
-- tee off menu
local seen5 = {}
local cm5 = { addOption = function(_, n) seen5[#seen5 + 1] = n; return {} end, addSubMenu = function() end }
ISContextMenu.getNew = function() return cm5 end
INV_ITEMS = {}; INV:AddItem("Base.GolfBall")
local teeSq2 = sqAt(40, 40, 0)   -- off course: no tee off
for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, cm5, { { getSquare = function() return teeSq2 end } }, false) end
check("no Tee off away from a course", not table.concat(seen5, "|"):find("Tee off"))
local onTee = { getX = function() return 6247 end, getY = function() return 6155 end, getZ = function() return 0 end }
PLAYER.getX = function() return 6250 end; PLAYER.getY = function() return 6155 end
for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, cm5, { { getSquare = function() return onTee end } }, false) end
check("Tee off offered on a tee box: " .. table.concat(seen5, " | "), table.concat(seen5, "|"):find("Tee off: Hole 13 %(Par 4%)") ~= nil)
-- par file and score names
check("par comes from PG_CoursePar.lua", C.list[1].holes[1].par == PG.CoursePar.WestMaple[1])
local names = {}
for _, st in ipairs{ 1, 2, 3, 4, 5, 6, 7, 9 } do names[#names + 1] = C.scoreName(st, 4) end
check("score names: " .. table.concat(names, ", "), table.concat(names, ",") == "Albatross,Eagle,Birdie,Par,Bogey,Double bogey,Triple bogey,+5")
check("cup lookup", C.holeAtCup(6135.5, 6149.5, 0).number == 13 and C.holeAtCup(10, 10, 0) == nil)
-- sinking hole 13 in 3 after teeing off
local function sinkWith(strokes, cupX, cupY)
  md.ProjectGolf = { strokes = strokes }; HALO = nil; PG.Client.flights = {}
  PG.ClientCommands.Flight({ by = 0, shot = "putt", path = { cupX, cupY, 0, cupX, cupY, 0 }, sampleDt = 0.05, duration = 0,
    result = "cup", evT = {}, evK = {}, x0 = cupX, y0 = cupY, z0 = 0, x1 = cupX, y1 = cupY, z1 = 0, cupX = cupX, cupY = cupY, cupZ = 0 })
  clock = clock + 200; PG.Client.overlay:prerender()
  return HALO
end
check("birdie callout: " .. tostring(sinkWith(3, 6135.5, 6149.5)), HALO == "Birdie!  Hole 13 in 3 (par 4)")
check("strokes reset after the hole", md.ProjectGolf.strokes == 0)
check("double bogey: " .. tostring(sinkWith(6, 6135.5, 6149.5)), HALO == "Double bogey!  Hole 13 in 6 (par 4)")
check("hole in one on a par 3: " .. tostring(sinkWith(1, 6182.5, 6201.5)), HALO == "HOLE IN ONE! Eagle!  Hole 10 in 1 (par 3)")
check("backyard hole keeps the old message: " .. tostring(sinkWith(2, 40.5, 20.5)), HALO == "In the cup! 2 strokes")
-- marker for drives: only on a course hole
local function targetFor(shot, courseHole)
  local fake = setmetatable({ action = { shot = shot, ballX = 6240.5, ballY = 6155.5, ballZ = 0, character = PLAYER },
    yaw = 180, courseHole = courseHole, hole = { x = 6200.5, y = 6155.5 }, holeDist = 40 }, { __index = PG_AimUI })
  for i = 1, 12 do fake:updateTarget() end
  return fake.target
end
check("drive marker on a course hole", targetFor("drive", C.holeFor(6240.5, 6155.5, 0)) ~= nil)
check("no drive marker off the courses", targetFor("drive", nil) == nil)
check("putt marker off the courses", targetFor("putt", nil) ~= nil)
-- Aiming affects golf
do
  local K = PG.Skill
  Perks = Perks or {}; Perks.Aiming = "Aiming"
  local savedLvl = PLAYER.getPerkLevel
  local lvl = 0
  PLAYER.getPerkLevel = function(_, perk) if perk == "Aiming" then return lvl end return 5 end
  SandboxVars = nil
  check("spread x1.5 / x1 / x0.5 at Aiming 0 / 5 / 10", math.abs(K.spreadMult(0) - 1.5) < 1e-9 and math.abs(K.spreadMult(5) - 1) < 1e-9 and math.abs(K.spreadMult(10) - 0.5) < 1e-9)
  check("mishit chance halves by Aiming 10", K.mishitMult(0) == 1 and math.abs(K.mishitMult(10) - 0.5) < 1e-9)
  check("preview 40% at 0, whole from 6, putts start at 60%", math.abs(K.previewFraction(0, "drive") - 0.4) < 1e-9 and K.previewFraction(6, "drive") == 1 and math.abs(K.previewFraction(0, "putt") - 0.6) < 1e-9)
  check("marker band at 0, exact from 7", K.markerBand(0) > 0 and K.markerBand(7) == 0 and K.markerBand(10) == 0)
  local lo, hi = K.bandAround(0.5, 0.1, "drive:90")
  local lo2, hi2 = K.bandAround(0.5, 0.1, "drive:90")
  check(("band contains the target and is steady (%.3f-%.3f)"):format(lo, hi), lo < 0.5 and hi > 0.5 and lo == lo2 and hi == hi2 and math.abs((hi - lo) - 0.2) < 1e-9)
  -- trimming keeps the start and cuts by distance
  local path = { 0, 0, 0,  10, 0, 1,  20, 0, 0 }
  local half = K.trimPath(path, 0.5)
  check("trimPath cuts at half the distance", #half == 6 and half[4] == 10 and half[1] == 0)
  local q = K.trimPath(path, 0.25)
  check("trimPath interpolates", #q == 6 and math.abs(q[4] - 5) < 1e-9 and math.abs(q[6] - 0.5) < 1e-9)
  check("trimPath full = same path", K.trimPath(path, 1) == path)
  -- server spread follows skill
  local shot = PG.Shots.drive
  lvl = 0; local s0 = PG.Server.spreadFor(PLAYER, shot, 0.5)
  lvl = 10; local s10 = PG.Server.spreadFor(PLAYER, shot, 0.5)
  check(("server spread: Aiming 0 %.2f deg > Aiming 10 %.2f deg"):format(s0, s10), s0 > s10 * 2.5)
  -- mishits: full-power drives at Aiming 0 vs 10
  local function mishits(level)
    lvl = level
    local n = 0
    local rb2 = PG.broadcast
    PG.broadcast = function(cmd, args) if cmd == "Flight" and args.mishit then n = n + 1 end end
    for i = 1, 200 do
      local b = newItem("Base.GolfBall", 20000 + level * 1000 + i); sqAt(20, 50, 0):AddWorldInventoryItem(b, 0.5, 0.5, 0)
      clock = clock + 5000
      PG.ServerCommands.Hit(PLAYER, { x = 20, y = 50, z = 0, id = 20000 + level * 1000 + i, shot = "drive", power = 1, yaw = 0 })
    end
    PG.broadcast = rb2
    return n
  end
  PLAYER.getX = function() return 20.0 end; PLAYER.getY = function() return 50.5 end
  local m0, m10 = mishits(0), mishits(10)
  check(("full-power mishits: Aiming 0 %d / 200, Aiming 10 %d / 200"):format(m0, m10), m0 > m10 * 1.4 and m10 > 20)
  PG.Server.pending = {}
  -- sandbox off: neutral
  SandboxVars = { ProjectGolf = { AimingSkill = false } }
  check("switched off: everything neutral", K.spreadMult(0) == 1 and K.mishitMult(0) == 1 and K.previewFraction(0, "drive") == 1 and K.markerBand(0) == 0)
  SandboxVars = nil
  PLAYER.getPerkLevel = savedLvl
end
-- yardage book: scorecards
do
  local C = PG.Courses
  local wm = C.list[1]
  local md = PLAYER:getModData(); md.ProjectGolf = { strokes = 0 }
  PG.Client.recordScore(PLAYER, wm.holes[1], 6)
  PG.Client.recordScore(PLAYER, wm.holes[1], 4)
  local card = PG.Client.getScorecard(PLAYER, "WestMaple")
  check("card keeps last and best", card.holes[1].last == 4 and card.holes[1].best == 4)
  PG.Client.recordScore(PLAYER, wm.holes[1], 7)
  check("worse score: last 7, best stays 4", card.holes[1].last == 7 and card.holes[1].best == 4)
  check("no full round yet", card.bestRound == nil)
  for i = 2, 18 do PG.Client.recordScore(PLAYER, wm.holes[i], wm.holes[i].par) end
  check("18 holes filled -> best round " .. tostring(card.bestRound), card.bestRound == (function() local t = 7; for i = 2, 18 do t = t + wm.holes[i].par end return t end)())
  PG.Client.newScorecard(PLAYER, "WestMaple")
  check("new card clears this round, keeps bests", card.holes[1].last == nil and card.holes[1].best == 4 and card.bestRound ~= nil)
  check("a second course's card is separate", next(PG.Client.getScorecard(PLAYER, "OtherCourse").holes) == nil)
  -- sinking a course hole writes the card
  local other = { id = "OtherCourse", holes = { {}, {}, {} } }
  PG.Client.recordScore(PLAYER, { course = other, number = 3, par = 3 }, 2)
  check("other course hole 3 in 2", PG.Client.getScorecard(PLAYER, "OtherCourse").holes[3].best == 2)
  -- the window draws every page without errors
  local w = PG.Guide.open(PLAYER)
  w:createChildren()
  local okAll = true
  for _, page in ipairs({ "tips", "WestMaple" }) do
    w.page = page
    local ok, err = pcall(w.render, w)
    if not ok then print(err); okAll = false end
  end
  check("book renders tips and both scorecards", okAll)
  -- edit mode: - / + boxes fix a score
  local wmc = PG.Client.getScorecard(PLAYER, "WestMaple")
  wmc.holes[5] = { last = 7, best = 7 }
  w.page = "WestMaple"; w:onEdit(); w:render()
  check("edit mode draws boxes (" .. #w.hits .. ")", w.editing and #w.hits == 18 * 4 + 2)
  local function click(i) local h = w.hits[i]; return w:onMouseDown(h.x + 1, h.y + 1) end
  -- hole 5 boxes: (5-1)*4 + 1 = score -, +2 = score +, +3 = best -, +4 = best +
  click(17); click(17); click(19)
  check("hole 5 fixed: score 5, best 6", wmc.holes[5].last == 5 and wmc.holes[5].best == 6)
  click(1)   -- hole 1 score - on an empty box: stays empty
  check("minus on an empty score keeps it empty", wmc.holes[1] == nil or wmc.holes[1].last == nil)
  click(2)   -- hole 1 score + on an empty box: starts at par
  check("plus on an empty score starts at par", wmc.holes[1].last == C.list[1].holes[1].par)
  for _ = 1, 30 do click(2) end
  check("score capped at 20", wmc.holes[1].last == 20)
  wmc.bestRound = nil; w:render(); click(#w.hits)
  local parWM = 0; for _, hh in ipairs(C.list[1].holes) do parWM = parWM + hh.par end
  check("best round + from none starts at par (" .. tostring(wmc.bestRound) .. ")", wmc.bestRound == parWM)
  click(#w.hits - 1)
  check("best round -", wmc.bestRound == parWM - 1)
  check("clicks elsewhere go to the window", w:onMouseDown(1, 1) == "window")
  w:onEdit()
  check("Done editing turns the boxes off", not w.editing and w:onMouseDown(w.hits[1].x + 1, w.hits[1].y + 1) == "window")
  w:close()
  check("closing forgets the window", PG.Guide.window == nil)
end
-- overhit sound: past the red line, the flight plays it instead of the hit
do
  local last
  local rb3 = PG.broadcast
  PG.broadcast = function(cmd, args) if cmd == "Flight" then last = args end end
  PLAYER.getX = function() return 20.0 end; PLAYER.getY = function() return 50.5 end
  local function hit(id, power)
    local b = newItem("Base.GolfBall", id); sqAt(20, 50, 0):AddWorldInventoryItem(b, 0.5, 0.5, 0)
    clock = clock + 5000; last = nil
    PG.ServerCommands.Hit(PLAYER, { x = 20, y = 50, z = 0, id = id, shot = "drive", power = power, yaw = 0 })
    return last
  end
  local f1 = hit(31001, 1)
  local f2 = hit(31002, 0.5)
  PG.broadcast = rb3
  PG.Server.pending = {}
  check("full power is an overhit, half power is not", f1 and f1.overhit == true and f2 and f2.overhit == false)
  check("overhit sound is defined", PG.Sounds.overhit == "ProjectGolf_Overhit")
end
-- teeing off steps up to the ball with the right club (drive on par 4/5, chip on par 3)
do
  local C = PG.Courses
  check("tee club: drive on par 4 and 5, chip on par 3",
    PG.teeClubFor({ par = 4 }) == "drive" and PG.teeClubFor({ par = 5 }) == "drive" and PG.teeClubFor({ par = 3 }) == "chip")
  local savedDrop = ISDropWorldItemAction
  ISDropWorldItemAction = { new = function(_, pl, item, sq, xo, yo) return { isDrop = true, item = item, sq = sq } end }
  local calls = {}
  local cm6 = { addOption = function(_, n, target, fn, a1) calls[n] = function() fn(target, a1) end; return {} end, addSubMenu = function() end }
  ISContextMenu.getNew = function() return cm6 end
  -- a little test course inside the mock world (real tees are outside it)
  local test = { id = "TestCourse", name = "Test Course", bounds = { 0, 0, 59, 59 }, holes = {} }
  test.holes[1] = { cup = { x = 50, y = 20, z = 0 }, tee = { x = 20, y = 20 }, par = 4, number = 1, course = test }
  test.holes[2] = { cup = { x = 50, y = 40, z = 0 }, tee = { x = 20, y = 40 }, par = 3, number = 2, course = test }
  table.insert(C.list, 1, test)
  local function teeOff(hole)
    INV_ITEMS = {}; local ball = INV:AddItem("Base.GolfBall")
    calls = {}
    local tsq = sqAt(hole.tee.x, hole.tee.y, 0)
    PLAYER.getX = function() return hole.tee.x + 3 end; PLAYER.getY = function() return hole.tee.y end
    for _, f in ipairs(handlers.OnFillWorldObjectContextMenu) do f(0, cm6, { { getSquare = function() return tsq end } }, false) end
    local opt = calls["Tee off: Hole " .. hole.number .. " (Par " .. hole.par .. ")"]
    if not opt then return nil, "no option" end
    QUEUED = nil; opt()
    local drop = QUEUED
    if not (drop and drop.isDrop) then return nil, "no drop" end
    QUEUED = nil; for _, f in ipairs(handlers.OnTick) do f() end
    if QUEUED then return nil, "addressed too early" end
    tsq:AddWorldInventoryItem(ball, 0.5, 0.5, 0)     -- the drop finishes
    for _, f in ipairs(handlers.OnTick) do f() end
    return QUEUED
  end
  local st4, why4 = teeOff(test.holes[1])
  check("tee off on a par 4 -> stance with the driver " .. tostring(why4 or ""), st4 and st4.shot == "drive")
  local st3, why3 = teeOff(test.holes[2])
  check("tee off on a par 3 -> stance with the chip " .. tostring(why3 or ""), st3 and st3.shot == "chip")
  check("nothing left waiting", PG.Menu.pendingTee == nil)
  table.remove(C.list, 1)
  ISDropWorldItemAction = savedDrop
end
-- tee up at home (no tee box): step up with the putter
do
  local savedDrop = ISDropWorldItemAction
  ISDropWorldItemAction = { new = function(_, pl, item, sq, xo, yo) return { isDrop = true, item = item, sq = sq } end }
  local savedFwd, savedCur = PLAYER.getForwardDirection, PLAYER.getCurrentSquare
  PLAYER.getForwardDirection = function() return { getX = function() return 1 end, getY = function() return 0 end } end
  PLAYER.getCurrentSquare = function() return sqAt(30, 30, 0) end
  PLAYER.getX = function() return 30.5 end; PLAYER.getY = function() return 30.5 end
  INV_ITEMS = {}; local ball = INV:AddItem("Base.GolfBall")
  local cbs = {}
  local cm7 = { addOption = function(_, n, target, fn, a1) cbs[n] = function() fn(target, a1) end; return {} end }
  for _, f in ipairs(handlers.OnFillInventoryObjectContextMenu) do f(0, cm7, { ball }) end
  QUEUED = nil; cbs["Tee up golf ball"]()
  local dropSq = QUEUED and QUEUED.sq
  QUEUED = nil
  if dropSq then dropSq:AddWorldInventoryItem(ball, 0.1, 0.5, 0) end
  for _, f in ipairs(handlers.OnTick) do f() end
  check("tee up at home -> stance with the putter", QUEUED and QUEUED.shot == "putt")
  PLAYER.getForwardDirection, PLAYER.getCurrentSquare = savedFwd, savedCur
  ISDropWorldItemAction = savedDrop
end
-- rename: Louisville -> Wellington Heights (names and saved cards)
do
  local C = PG.Courses
  check("parked course keeps its name and par data", C.parked[1].name == "Wellington Heights Golf Club" and PG.CoursePar.WellingtonHeights[1] == 3)
  local md2 = PLAYER:getModData(); md2.ProjectGolf = { strokes = 0, cards = { Louisville = { holes = { [4] = { last = 3, best = 2 } } } } }
  local card = PG.Client.getScorecard(PLAYER, "WellingtonHeights")
  check("old Louisville card carries over", card.holes[4] and card.holes[4].best == 2 and md2.ProjectGolf.cards.Louisville == nil)
end
-- the hole you teed off on sticks (hole 11 doglegs; south of its straight line hole 8's line runs closer)
do
  local C = PG.Courses
  local h11 = C.list[1].holes[11]
  check("hole 11 is a par 4", h11.par == 4)
  local x, y = 6198, 6279.5   -- south of the tee: where hole 8's line runs closer
  check("off hole 11's line, guessing alone picks hole 8 (the bug)", C.holeFor(x, y, 0).number == 8)
  PG.Client.setCurrentHole(PLAYER, h11)
  check("teed off on 11: the aim screen stays on hole 11", C.holeFor(x, y, 0, PG.Client.currentHole(PLAYER)) == h11)
  local h1 = C.list[1].holes[1]
  check("far off on another hole: back to the layout", C.holeFor(h1.cup.x, h1.cup.y - 3, 0, h11) == h1)
  PG.Client.setCurrentHole(PLAYER, nil)
  check("holed out: no current hole", PG.Client.currentHole(PLAYER) == nil)
end
-- ball names: the ball you hit becomes "<first name>'s golf ball"
do
  local named = newItem("Base.GolfBall", 501)
  named.setName = function(self, n) self.name = n end
  named.setCustomName = function(self, b) self.custom = b end
  sqAt(10, 25, 0):AddWorldInventoryItem(named, 0.5, 0.5, 0)
  PLAYER.getX = function() return 10.0 end; PLAYER.getY = function() return 25.5 end
  PLAYER.getDescriptor = function() return { getForename = function() return "Garry" end } end
  clock = clock + 5000
  PG.ServerCommands.Hit(PLAYER, { x = 10, y = 25, z = 0, id = 501, shot = "putt", power = 0.2, yaw = 0 })
  check("the ball you hit is named after you: " .. tostring(named.name), named.name == "Garry's golf ball" and named.custom == true)
  PLAYER.getDescriptor = nil
  check("no character name: your account name", PG.Server.ownerName(PLAYER) == "tester")
end
print(ok .. " checks passed")
