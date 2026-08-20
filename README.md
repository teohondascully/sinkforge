# Sinkforge

A 2D side-view game about digging a factory down into solid earth.

[![godot 4.6.2](https://img.shields.io/badge/godot-4.6.2-478cbf)](https://godotengine.org)
[![license: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](LICENSE)

Gravity carries a machine's output downward for free. Moving anything back up, including the miner,
costs power. Production lines therefore grow vertically, while the tunnels around them sprawl in any
direction.

![The first automated line running at the surface](_moment_line.png)

## What it is

The world is 128 by 128 cells of solid, minable ground at 32 pixels to a cell. A metre is one cell.
The surface datum sits at row 20, so the deepest ground reads 107 metres down. A new game starts up
there with a wood pickaxe and nothing else.

Mining is done by hand at first. Ore goes into a pack, the pack goes to a forge, the forge turns it
into ingots. Automation then takes that work over. A drill bores the vein on its own, its output
falls down the column into the forge below, a hopper or a splitter routes what comes out, and a
power conduit feeds whatever needs feeding. Once a column runs unattended the miner climbs back out
and digs further down.

Moving material back up costs power. A Lift carries 2 items per tick hand-cranked and 6 at full
power. A Pump reaches 4 cells straight down and drains 3 units of water per tick at full power, and
none at all unpowered.

The descent is banded and named: Topsoil at the datum, then the Clayband, Shale Reach, the Long
Dark, and the Deepslate, whose rock the starter wood pickaxe cannot break. At 64 metres come two
rows of unminable sealrock. No pickaxe touches the seal. It opens when a Descent Engine standing on
it has been fed 64 ingots down its column, and the breach bores a shaft through into Stonereach,
where the iron is. Sealed water pockets are seeded in the deep rock below the Deepslate and need a
pump before they are worth entering.

There is no reset and no prestige mechanic. The world is permanent and grows downward.

![A drill and five spurs working a seam, 27 metres down](_moment_chain.png)

## Running from source

The project needs Godot 4.6.2. `project.godot` targets the 4.6 feature set, and CI installs
`4.6.2-stable`.

```sh
git clone https://github.com/teohondascully/sinkforge
cd sinkforge
godot --path .
```

Opening `project.godot` in the editor and pressing play does the same thing.

Two things are worth knowing before cloning. The tracked tree is 324 MB, of which 319 MB is
screenshots, so it is a large clone. And `export_presets.cfg` is gitignored, so a fresh clone runs
the game from source but cannot yet produce a packaged build.

Development happens on macOS and CI runs the project on Linux. There is no Windows job and no
Windows testing.

## Controls

| Input | Action |
| --- | --- |
| `A` `D` or arrows | walk |
| `Space` | jump |
| `W` `S` | grip and climb a placed rope |
| left mouse | mine the aimed cell; drag to paint a dig plan the miner works through |
| right mouse | place the selected item, or pick one of the placed machines back up |
| `F` or middle mouse | fire or release the grapple |
| mouse wheel | cycle the hotbar |
| `1`-`9`, `0` | select a hotbar slot directly |
| `Q` | drop the selected stack, or feed the faced cell |
| `E` | open the counter: pack, works and bench |
| `R` | configure the machine under the cursor |
| `X` | clear the painted dig plan |
| `M` | map |
| `T` | tech tree |
| `G` | production dashboard |
| `Z` | cycle zoom |
| `.` | cycle the game clock, 1x through 8x |
| `N` | mute |
| `P` | pause |
| `F5` / `F9` | save / load |
| `H` or `/` | key help |
| `Esc` | close the open screen, or open settings |

Mining, building and feeding are gated on reach, at 3.2 cells from the body's centre, and on a clear
line of sight to the target cell.

A gamepad layout ships alongside the keyboard defaults and both are live at once. The defaults live
in one file, `scenes/controls.gd`, and the settings screen rebinds them by overriding Godot's
`InputMap`. The number row is the exception: it is a fixed convention handled at its call site.

## How it is built

### The simulation and representation seam

`src/core/factory_sim.gd` holds all production state and all production math. It extends
`RefCounted`, runs on a fixed 20 Hz tick, and does not know a scene tree exists. Nothing under
`src/` extends `Node`, and the directory contains zero `get_tree()` calls. The suites in `tests/`
build a sim, tick it, and assert on it with no scene instantiated at all.

Everything visible lives in `scenes/`: the renderer, the HUD, the falling-item sprites, the lighting
passes, the player body. They read the sim and draw it. Player input reaches the sim's discrete verbs
through a single controller, `scenes/main.gd`, so the input boundary has one crossing point.

Determinism falls out of that. The same seed and the same call sequence produce the same state,
headless or windowed, which is what makes both the save format and the test suite workable.
`tests/test_sim.gd` asserts it directly: capture the sim, restore it, tick both copies, compare
signatures.

### Content is data

Machines, recipes and materials are Godot Resources under `src/data/`. There are currently 20
machine definitions, 6 recipes and 16 materials. A machine is a named recipe-runner by default.
Anything that is not one carries a `behavior` StringName which maps into a single table in the sim,
`_BEHAVIORS`, naming that tag's per-tick hooks. Adding a machine means a `.tres`, one row in that
table, and one row in the renderer's style registry.

### Worldgen and rendering meet through a contract

`WorldGen.generate(cols, rows, seed)` returns a `WorldData`, which is plain data with no engine
dependencies: two grids of material ids for foreground blocks and background walls, plus deposit
richness, a background lode plane, and water levels. `FactorySim.load_world()` ingests it. The
renderer resolves material ids against `MaterialDef` resources for colour and grain. The generators
reference nothing under `scenes/`, and `scenes/world_renderer.gd` references no generator, so a new
generator and a new palette are independent changes.

The live generator is `LayeredWorldGen`, which extends the heightmap generator and adds depth-banded
ore veins, caves, rifts and sinkholes on top of a heightmap surface.

### Drawing

Everything is drawn from code in `_draw`. The only authored images in the project are 16 miner frames
in `assets/sprites/`; every other texture the renderer hands to `draw_texture` is one it generated
itself. Lighting is a lightmap texture at one texel per cell, stretched over the world with linear
filtering: daylight floods down open columns until it meets rock, then lamps, torches, working
machines and powered conduits cut radial holes in the darkness each frame. A `WorldEnvironment` glow
pass grades the scene, and `scenes/post_fx.gdshader` adds a vignette, film grain and a little
chromatic aberration on a full-screen rect one canvas layer below the HUD, so the world gets the lens
and the UI stays crisp.

### Saving

`src/core/save_game.gd` captures the authoritative sim state into one versioned envelope, written
with Godot's binary Variant serializer so `Vector2i` keys and StringNames survive the round trip.
Derived state is not saved; it rebuilds on the next tick. The write encodes to a temp file, reads it
back to prove it decodes, copies the current save to `.bak`, and only then renames over the slot, so
the slot holds a complete readable game at every point. `restore()` stages the whole envelope into a
scratch dictionary before touching the sim, so a malformed file is refused without a partial write,
and a damaged slot falls back to the backup. The envelope is at version 2 and still reads version 1.

## Tests

```sh
bash tools/run_harness.sh
```

The runner registers 92 layers across 89 scripts and launches each as its own Godot process, up to
the CPU count in parallel. A file lock keeps two sweeps from sharing the machine. The layers fall
into roughly six kinds:

| Kind | What runs | What it can establish |
| --- | --- | --- |
| Simulation | the four headless suites in `tests/`, 64 test functions between them | deterministic state transitions, conservation, save round-trips |
| World and content | worldgen across seeds, the material and craft registries | that generated worlds and the content graph hold their invariants |
| Runtime integration | mining, climbing, lifts, settings, save and load through the real scene | that the real code path works under a controlled fixture |
| Pixels | frames captured from a real window and measured | what a frame actually renders |
| Timing | frame budget and dig-hitch probes | measured cost on one machine, with nothing else running on it |
| Play | `tools/play_tests.gd` | that a scripted pilot can reach a goal through the same reach-gated verbs a player uses |

`tools/play_tests.gd` is the closest thing here to an end-to-end test. It boots the real scene with
an empty pack and walks the real body with real physics through 16 goals, from finding and digging
the first ore, through the first self-feeding drill and forge line, breaching the seal into
Stonereach, the iron chain below it, and pumping out a generated aquifer. Four of the goals measure
friction on journeys a player has to make anyway, including the climb back out of a deep pit. Each
goal gets up to three tries, because real-time physics and heuristic navigation can miss once. Some
goals inject resources to arrange the situation; the verb under test is always the real one.

What that run does and does not establish:

- A layer reports pass, fail or skip, and skip has its own exit code rather than a quiet zero. 17
  layers are registered as needing a real window or exclusive use of the machine, and the layers that
  judge pixels detect the absence of a display and skip themselves. The runner prints the three
  counts separately and will not print the word "ALL" over a list containing a skip.
- On a machine that has a display, strict mode is on by default, so any skip fails the whole run
  with exit code 4. There are five exit codes in all, and a caller that reads "not zero" as "a test
  failed" will misdiagnose four of them.
- 92 is a count of registered layers. It is not a coverage figure, and none is claimed here.
- The suite does not measure whether the game is enjoyable. A play goal establishes that a scripted
  pilot reached it, which is a far narrower claim.

The suite protects the real save while it runs. Every layer executes against an isolated `HOME`, and
a sentinel hashes the production save slot before and after the sweep, so a layer that writes to it
fails the run loudly with its own exit code instead of quietly eating a game.

`docs/HARNESS_LAYERS.md` covers the shape of a layer, the three-state exit protocol, and the failure
modes that have actually bitten this suite.

### CI

`.github/workflows/harness.yml` runs three jobs on every push to `main` and every pull request: an
authorship and capture-manifest check, the whole registration headless, and the window-dependent
layers under xvfb with Mesa's software Vulkan. No single job runs every layer. `check_frametime` is
deliberately excluded from CI, because a software rasterizer draws at 6 to 9 fps and its hitch ratios
then describe the rasterizer.

CI is currently red. On the most recent run against `main`, dated 2026-08-20, the headless job came
back 77 pass, 0 fail and 15 skipped of 92, and the display job selected the 16 layers that need a
surface and came back 13 pass, 3 fail: `check_grapple_reads`, `check_hud_layout` and
`check_snap_frame`. This README carries no build badge while that is the case.

## Repository layout

```
scenes/     the Godot scene, the player body, the renderer, the HUD, the shaders
src/core/   the simulation, world data, worldgen, save/load
src/data/   machine, recipe and material definitions as Godot Resources
tests/      headless sim, worldgen, power/water and stress suites
tools/      the harness runner, its layer scripts, and the capture tooling
assets/     the miner frames
docs/       design and technical notes
history/    a dated screenshot archive, 226 MB
```

The `_moment_*.png` files in the repository root are canonical captures written by
`tools/capture_moments.gd`. Several of the pixel layers read them as evidence, which is why they are
tracked rather than generated on demand. `docs/CAPTURE_MANIFEST.md` is generated from git and records
the date and drawing-source signature behind each one.

For design intent, `docs/GDD.md` is the game design document and `docs/PROGRESSION.md` is the
intended layer ladder. `docs/ARCHITECTURE.md` is the longer version of the section above.
`docs/DECISIONS.md` is the running log of what was decided and why.

## Status

Early, and in active development.

Playable today: hand-mining, hauling and hand-feeding; crafting and placing machines from the pack;
a self-feeding drill and forge line; coal-fired power and conduit routing; ropes, a grapple and
lifts; research at a bazaar bench; the seal breach into Stonereach; the iron chain below it; water as
an integer-level fluid, with pumps to clear it. Save and load, a map, a tech tree, a production
dashboard and a settings screen with remappable keys.

Not there yet. The generated world runs from Topsoil down to Stonereach, the second layer of the
ladder in `docs/PROGRESSION.md`. The third layer's fluid mechanic already exists as water and pumps,
and its tooling is on the research tree, but the layer itself and everything past it are design
rather than code. There is no combat and no packaged build. Most of the art is placeholder.
Underground legibility is an open problem, since outside a lamp pool rock and empty space are hard to
tell apart.

Expect things to change.

## License

MIT. See [LICENSE](LICENSE).
