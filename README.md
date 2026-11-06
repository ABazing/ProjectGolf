# Project Golf (Build 42 + Viewpoint)

A rewrite of Project Golf (workshop 2766645289). The old mod was a throwable "golf club grenade"; this one is real golf:
place a ball, right-click it, take a stance, aim, fill the power meter, swing.

## Layout

```
ProjectGolf/                      <- copy this folder to  ~/Zomboid/Workshop/ProjectGolf
  workshop.txt, preview.png       <- Steam upload metadata
  Contents/mods/
    ProjectGolf/                  <- the gameplay mod (no Viewpoint needed)
      42/mod.info, poster.png
      common/media/
        lua/shared/ProjectGolf/   PG_Config (tuning), PG_Physics (ball sim), PG_World (game adapter), PG_Net,
                                  PG_Courses + PG_CoursePar (courses, par), PG_Skill (Aiming), PG_Sandbox
        lua/server/ProjectGolf/   PG_Server (validates hits, runs the sim, places the ball), PG_CourseBuilder (tee boxes, cups)
        lua/client/ProjectGolf/   context menu, stance action, aim UI, flight playback, Tips / Scorecard window,
                                  ball finder, Viewpoint bridge, options
        scripts/                  Golf Hole + Tee Marker items, recipe, tee marker 3D model, sounds
        textures/, sound/         ball/shadow/dot sprites, icons, tee marker texture, sounds
  tests/                          <- offline Lua tests (physics, end-to-end smoke test with mocks, Viewpoint maths)
```

## Working in VS Code

Open `ProjectGolf.code-workspace` (File > Open Workspace from File). This folder is the one the game loads from
(`Zomboid\Workshop\ProjectGolf`), so every save is live: restart the game, or reload Lua from the debug menu.

- Install the recommended **Lua** extension (sumneko.lua). `.luarc.json` sets it up for Kahlua (Lua 5.1) and the
  game's globals.
- Viewpoint's mod folder is added read-only, for looking up its Lua.
- Terminal > Run Task:
  - **Golf: watch game log (live)** - only Project Golf lines from `console.txt`, with stack traces.
  - **Golf: errors from the last session**
  - **Golf: run offline tests** - needs `lua` on PATH (`winget install DEVCOM.Lua`).

## How it plays

1. **Tee up golf ball** (inventory right-click): the ball goes down and you step up to it - with the putter, or on a
   course tee box with the club for that par (Driver, Chip on par 3s). Or drop a ball and right-click it:
   **Golf > Putt / Chip / Drive** (needs `Base.Golfclub` in your inventory).
2. On West Maple, right-click a tee box: **Golf > Tee off: Hole N** (starts the stroke count;
   hole 1 starts a new scorecard).
3. Aim: mouse in isometric view, where you look in Viewpoint first/third person.
4. Hold **LMB**: the meter runs 0 → 100 → 0. Release to swing. Above 92% you overswing (overhit sound, wider spread,
   mishit chance). Panic, drunkenness and low endurance also spray the ball. Aiming skill tightens everything.
5. Wheel or 1/2/3 switches club; RMB/Esc steps away.
6. **Golf > Tips / Scorecard** (right-click anywhere with a golf club): tips, and scorecards that fill in as you sink
   course holes. **Edit scores** fixes a wrong one; **New card** starts a fresh round.

Your own cup: craft a **Golf Hole** (tin can + plank + ripped sheets), right-click the ground: **Golf > Place golf
hole here**, and roll the ball in slowly. The stroke counter resets on a sink and on Tee off.

Sandbox options (page "Project Golf"): Golf lifts mood, Golf trains Aiming, Aiming affects golf.

## Multiplayer model

The client sends `Hit {ball square, item id, shot, power, yaw}`. The server checks club in hand, distance, rate
limit, adds spread, removes the ball, runs `PG.simulate` once, broadcasts the sampled path, and re-places the
ball when the flight time is up. Every client animates the same path. Single player runs the same handlers
directly (`PG_Net.lua`).

## Viewpoint

Works with Viewpoint **0.1.7+** (addon API) and **0.1.6** (no addon API), picked automatically in `PG_Viewpoint.lua`:

- **0.1.7+:** `Viewpoint.Addons.viewState()` / `terrainHeight()` give the camera and relief; the optional mod
  `ProjectGolfViewpoint` ships the Java addon `projectgolf.ball` (`addon-src/`), which draws the ball, its shadow and the
  aim line as real 3D spheres at `AFTER_OPAQUE` (depth-tested, so terrain and walls hide them).
  Build: VS Code task **Golf: build 3D ball addon** (`addon-src\gradlew.bat build`, JDK 17+).
- **0.1.6:** `Contents/mods/ProjectGolf/42/media/java/client/ProjectGolfVP16.jar` (`vp16-src/`), loaded by ZombieBuddy
  (`javaJarFile` in `mod.info`; 0.1.6 needs ZombieBuddy anyway). It exposes the Lua global `ProjectGolfVP16` with the
  same view state and relief, read by reflection exactly as 0.1.7 publishes them, and patches
  `viewpoint.render.TranslucentPass.draw` to draw the same spheres at the same point of the frame (where 0.1.7 calls
  `AFTER_OPAQUE`). The 3D ball only draws when `ProjectGolfViewpoint` is enabled (it sets `ProjectGolfViewpointBall`).
  It switches itself off on 0.1.7+ and on unknown Viewpoint builds (see `[ProjectGolf VP16]` lines in console.txt).
  Build: `vp16-src\build.ps1 "<Viewpoint 0.1.6>\42\media\java\client\Viewpoint.jar"` (JDK 17+; compiles against
  stubs, uses only GL calls Viewpoint 0.1.6 itself makes).
- Without Viewpoint, in isometric view, or without the 3D ball, a 2D overlay draws the ball and the aim line.

## Tests

Windows: `./tests/run.ps1`. Linux/macOS: `LUA=lua ./tests/run.sh`.

## Check in game (could not be verified offline)

These are B42 APIs the code uses but that need confirming against your build. Each is guarded, so a mismatch
degrades instead of erroring; watch `console.txt` for `[ProjectGolf]` lines.

- [ ] Item script `ItemType = base:normal` (older 42.x used `Type = Normal`) and the `craftRecipe` block.
- [ ] `sq:AddWorldInventoryItem(item, x, y, z, true)` + `transmitRemoveItemFromSquare` sync in MP.
- [ ] `isoToScreenX/Y` and `screenToIsoX/Y` line up with the ball at all zoom levels.
- [ ] `ISDropWorldItemAction:new(...)` signature for Tee up.
- [ ] `PZAPI.ModOptions` tick boxes appear under Mod Options.
- [ ] In MP, the client-only `ISGolfStance` timed action is accepted (B42 networks some timed actions).
- [ ] Multiplayer: two players on a dedicated server (hits, flights, tee boxes, scorecards).
- [ ] Viewpoint 0.1.6: console.txt says `[ProjectGolf VP16] bridge on`, aiming follows the view, 3D ball draws.

