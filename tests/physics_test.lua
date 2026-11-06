local shared = arg[1]
package.path = shared .. "/?.lua;" .. package.path
require "ProjectGolf/PG_Config"
require "ProjectGolf/PG_Physics"
local PG = ProjectGolf

-- mock world: grass field 0..79 x 0..79 at z=0, plus features per test
local function makeWorld(opts)
  opts = opts or {}
  local w = {}
  function w.info(ix, iy, iz)
    if ix < 0 or iy < 0 or ix > 79 or iy > 79 then return nil end
    if iz > 0 then return { floor = opts.roof and opts.roof(ix, iy) or false, surface = "floor" } end
    return { floor = true, surface = opts.surface or "grass",
             water = opts.water and opts.water(ix, iy) or false,
             tree = opts.tree and opts.tree(ix, iy) or false }
  end
  function w.blocked(ax, ay, bx, by, z)
    if opts.wallX and z == 0 and math.max(ax, bx) == opts.wallX and ax ~= bx then return opts.wallKind or "wall" end
    return nil
  end
  function w.zombies() return opts.zombies or {} end
  function w.cups(ix, iy, iz)
    if opts.cup and math.floor(opts.cup.x) == ix and math.floor(opts.cup.y) == iy then return { opts.cup } end
    return {}
  end
  return w
end

local pass, fail = 0, 0
local function check(name, cond, detail)
  if cond then pass = pass + 1; print("PASS  " .. name .. "  " .. (detail or ""))
  else fail = fail + 1; print("FAIL  " .. name .. "  " .. (detail or "")) end
end
local function run(input, opts)
  input.seed = input.seed or 42
  return PG.simulate(input, makeWorld(opts))
end
local function carryOf(sim, x0)
  for i, e in ipairs(sim.events) do if e.kind == "bounce" then return e.x - x0 end end
  return sim.final.x - x0
end
local function fmt(s) return ("result=%s final=(%.1f, %.1f, z%d) t=%.2fs events=%d"):format(s.result, s.final.x, s.final.y, s.final.z, s.duration, #s.events) end

-- 1 drive, full power, east
local s = run{ x = 5.5, y = 40.5, z = 0, shot = "drive", power = 1, yaw = 0 }
local carry = carryOf(s, 5.5)
check("drive carry ~42", math.abs(carry - 42) < 1.5, ("carry=%.1f  %s"):format(carry, fmt(s)))
check("drive rolls on after landing", s.final.x - 5.5 > carry + 2, fmt(s))
check("drive straight", math.abs(s.final.y - 40.5) < 0.01)

-- 2 putt half power on grass ~7
s = run{ x = 10.5, y = 10.5, z = 0, shot = "putt", power = 0.5, yaw = 90 }
check("putt 50% ~7 squares south", math.abs((s.final.y - 10.5) - 7) < 0.6, fmt(s))

-- 3 putt is faster on road
local s2 = run({ x = 10.5, y = 10.5, z = 0, shot = "putt", power = 0.5, yaw = 90 }, { surface = "road" })
check("putt rolls further on road", s2.final.y > s.final.y + 5, fmt(s2))

-- 4 chip into a wall bounces back
s = run({ x = 10.5, y = 30.5, z = 0, shot = "putt", power = 0.8, yaw = 0 }, { wallX = 15 })
check("putt hits wall and comes back", s.final.x < 15 and #s.events > 0 and s.events[1].kind == "wall", fmt(s))

-- 5 drive clears a wall when high enough
s = run({ x = 5.5, y = 30.5, z = 0, shot = "drive", power = 1, yaw = 0 }, { wallX = 25 })
check("drive flies over a wall", s.final.x > 25, fmt(s))

-- 6 low fence vs chip: chip goes high -> clears
s = run({ x = 5.5, y = 30.5, z = 0, shot = "chip", power = 0.6, yaw = 0 }, { wallX = 9, wallKind = "fence" })
check("chip clears a low fence", s.final.x > 9, fmt(s))

-- 7 water hazard
s = run({ x = 5.5, y = 50.5, z = 0, shot = "putt", power = 1, yaw = 0 }, { water = function(ix) return ix >= 12 and ix <= 14 end })
check("putt into water is lost", s.result == "water", fmt(s))

-- 8 cup: slow putt that ends just past the cup drops in
s = run({ x = 10.5, y = 60.5, z = 0, shot = "putt", power = 5.4 / 14, yaw = 0 }, { cup = { x = 15.5, y = 60.5 } })
check("putt drops in the cup", s.result == "cup" and s.cup and math.abs(s.final.x - 15.5) < 1e-9, fmt(s))

-- 9 cup: a blasted putt lips out
s = run({ x = 10.5, y = 60.5, z = 0, shot = "putt", power = 1, yaw = 0 }, { cup = { x = 12.5, y = 60.5 } })
local lip = false; for _, e in ipairs(s.events) do if e.kind == "lipout" then lip = true end end
check("fast putt lips out", s.result ~= "cup" and lip, fmt(s))

-- 10 edge of loaded world acts as a wall
s = run{ x = 70.5, y = 20.5, z = 0, shot = "putt", power = 1, yaw = 0 }
check("unloaded squares stop the ball", s.final.x < 80, fmt(s))

-- 11 trees deflect sometimes (over many seeds)
local deflected = 0
for seed = 1, 40 do
  local t = run({ x = 5.5, y = 20.5, z = 0, shot = "putt", power = 1, yaw = 0, seed = seed }, { tree = function(ix, iy) return ix == 10 and iy == 20 end })
  for _, e in ipairs(t.events) do if e.kind == "tree" then deflected = deflected + 1; break end end
end
check("trees catch ~55% of balls", deflected > 12 and deflected < 32, deflected .. "/40")

-- 12 preview stops at a tree
s = run({ x = 5.5, y = 20.5, z = 0, shot = "putt", power = 1, yaw = 0, preview = true, maxTime = 8 }, { tree = function(ix, iy) return ix == 10 and iy == 20 end })
check("preview stops at the tree", s.final.x < 11.1, fmt(s))

-- 13 ball rolls off a roof and falls a storey
s = run({ x = 5.5, y = 70.5, z = 1, shot = "putt", power = 0.6, yaw = 0 }, { roof = function(ix) return ix <= 8 end })
check("rolls off a roof onto the ground", s.final.z == 0 and s.final.x > 8, fmt(s))

-- 14 zombie in the way
s = run({ x = 5.5, y = 5.5, z = 0, shot = "putt", power = 1, yaw = 0 }, { zombies = { { x = 9.5, y = 5.5, id = 7 } } })
local hit = false; for _, e in ipairs(s.events) do if e.kind == "zombie" then hit = true end end
check("zombie blocks the ball", hit and s.final.x < 9.5, fmt(s))

-- 15 determinism + network path size
local a = run({ x = 5.5, y = 20.5, z = 0, shot = "drive", power = 0.9, yaw = 33, seed = 99 }, { tree = function(ix, iy) return (ix * 7 + iy * 3) % 11 == 0 end })
local b = run({ x = 5.5, y = 20.5, z = 0, shot = "drive", power = 0.9, yaw = 33, seed = 99 }, { tree = function(ix, iy) return (ix * 7 + iy * 3) % 11 == 0 end })
check("deterministic for a seed", a.final.x == b.final.x and a.final.y == b.final.y)
check("path payload small", #a.path / 3 < 600, (#a.path / 3) .. " points, " .. ("%.1f"):format(a.duration) .. "s")

-- 16 preview cost
local t0 = os.clock()
for i = 1, 200 do run({ x = 5.5, y = 40.5, z = 0, shot = "drive", power = 1, yaw = i, maxTime = 8, preview = true }) end
local ms = (os.clock() - t0) / 200 * 1000
check("preview sim is cheap", ms < 8, ("%.2f ms per preview (mock world)"):format(ms))

-- 17 strength scales chip and drive carry, never putts
Perks = { Strength = "Strength" }
local function golfer(lvl) return { getPerkLevel = function() return lvl end } end
local SC = PG.Strength
-- (power 0.55, so even Strength 10 with the 30% boost lands inside the 80-square test world)
for _, lvl in ipairs{ 0, 5, 10 } do
  local want = (SC.minMult + (SC.maxMult - SC.minMult) * lvl / 10) * (SC.boost or 1)
  local m = PG.distanceMult(golfer(lvl), "drive")
  local sd = run{ x = 5.5, y = 40.5, z = 0, shot = "drive", power = 0.55, yaw = 0, distanceMult = m }
  local c = carryOf(sd, 5.5)
  check(("strength %d drive carry ~%.1f"):format(lvl, 42 * 0.55 * want), math.abs(m - want) < 1e-9 and math.abs(c - 42 * 0.55 * want) < 2, ("carry=%.1f"):format(c))
end
check("the boost: everyone's drives go 30% further", math.abs(PG.distanceMult(golfer(5), "drive") - 1.25 * 1.3) < 1e-9)
check("...and chips", math.abs(PG.distanceMult(golfer(5), "chip") - 1.25 * 1.3) < 1e-9)
check("strength 10 chip goes further than strength 0",
  carryOf(run{ x = 5.5, y = 40.5, z = 0, shot = "chip", power = 1, yaw = 0, distanceMult = PG.distanceMult(golfer(10), "chip") }, 5.5)
  > carryOf(run{ x = 5.5, y = 40.5, z = 0, shot = "chip", power = 1, yaw = 0, distanceMult = PG.distanceMult(golfer(0), "chip") }, 5.5) + 6)
check("putts ignore strength", PG.distanceMult(golfer(10), "putt") == 1 and PG.distanceMult(golfer(0), "putt") == 1)
check("no perk API -> Strength 5", math.abs(PG.distanceMult({}, "drive") - (SC.minMult + SC.maxMult) / 2 * (SC.boost or 1)) < 1e-9)
Perks = nil

print(("\n%d passed, %d failed"):format(pass, fail))
