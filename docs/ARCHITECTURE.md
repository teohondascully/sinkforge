# Sinkforge — Technical Architecture

> The technical source of truth. The load-bearing systems get a section each — responsibility, public API,
> relationships — and the **Module index** near the bottom lists every remaining script in `src/` and
> `scenes/` with one line on what it is for, so that nothing in the tree is absent from this file without
> being absent on purpose. Update this whenever a system is built or refactored.

## Core Principle: Data-Driven Everything

Machines, materials, recipes, and depth layers are **Godot custom Resources (data files)**, consumed by a generic engine. Adding new content = creating/editing a data file, NOT writing new classes. This is the load-bearing architectural decision.

## Core Principle: Discrete Items Are Source of Truth

Production is **discrete and integer**. A machine fills `output_buffer`; `_flow` hands those items to the
machine's destination list; nothing anywhere is a rate. `production_rate()` is **derived bookkeeping** — a
ring buffer of `total_produced` snapshots, read only by the HUD for legibility, never read back by
production logic.

The falling-item sprites (`FallingItems`) are a cosmetic layer spawned from `flow_events`. **Delete them
and every production count is identical.**

> *This principle used to be written the other way round — "production math runs entirely through the
> abstract rate-based flow layer, discrete falling items are cosmetic". That inverted the actual
> dependency: items are authoritative and the rate layer is the cosmetic one. It described an earlier
> architecture and would have led a new contributor to build against a layer that does not exist.
> Corrected 2026-08-17.*

---

## Systems

> The whiteboard view: simulation (node-free, authoritative) on one side, representation
> (Nodes, disposable, read-only) on the other. The boundary is the load-bearing invariant.

### FactorySim — the simulation (source of truth)
- **Location:** `src/core/factory_sim.gd` (`RefCounted`, node-free)
- **Responsibility:** Runs all production math on a fixed 20 Hz tick; owns the grid topology
  and the item flow. Deterministic; runs headless.
- **Public API:** `place_machine(def, cell) -> MachineState` · `remove_machine(cell)` ·
  `machine_at(cell)` · `in_bounds(cell)` · `advance(delta)` (game-loop time driver) ·
  `tick()` (one logical step). Terrain/pack/economy: `is_solid`/`material_at`/`set_solid`/`mine` ·
  `inventory_slots()` · `deposit(cell,item,n)` · `collect_ground(cell)` (walk-over pickup of a spat
  pile) · `craft(def)` (spend `craft_cost` ingots → a machine item, counted as consumed) ·
  `build_from_pack(def,cell)` / `pickup_machine(cell)` (place/return a carried machine, salvaging
  buffers). Reads: `machines`, `grid`, `inventory`, `ground`, `sink`, `total_produced/consumed`.
- **Topology:** machines occupy grid cells (`GRID_COLS`×`GRID_ROWS`, row increases downward).
  Each tick: every machine runs, then `_flow` hands each machine's output to its **destination
  list** (`_destinations` → `_column_landing`). An ordinary machine has ONE destination (straight
  down its column): the next machine below catches it (cascade), else it **lands on top of the
  first solid floor as a physical `ground` pile** the player walks over to collect; a column dug
  clear to the void uses `sink` (conservation-only). A **splitter** (`behavior == &"splitter"`)
  runs no recipe — it passes its incoming stream through and `_flow` divides it evenly between
  TWO destinations (down + the column to its right), dealt round-robin via the machine's
  `route_toggle` so odd counts split fairly over time. Right-wall splitters degrade to down-only
  (PROVISIONAL edge). A **lift** (`behavior == &"lift"`) routes UP (`_column_rise`)
  rate-limited by `LIFT_THROUGHPUT`; a **drill** (`behavior == &"drill"`) draws from the WORLD, not a
  buffer — `_run_drill` takes the cell `drill_target()` picks out of the column straight below it,
  drains that cell's finite `deposits` pool, and spits ore down its column like an ordinary machine.
  There is no reach constant on the vertical drill: `drill_target()` scans the whole column. The
  horizontal sibling does have one, `H_DRILL_RANGE`.
- **THE BEHAVIOR REGISTRY (`_BEHAVIORS`):** the ONE sim-side table wiring a `behavior` tag into the
  tick — per-tag `run` / `status` / `dests` hook method-names (dispatched via `call()`; names, not
  bound Callables, so a RefCounted sim never self-references) plus semantic flags (`updraft`,
  `power_source`) read by `updraft_at` and the power sweep. No entry = the default named
  recipe-runner (`_run_recipe`). **Adding a machine behavior = its functions + one `_BEHAVIORS`
  entry + one `Visuals.MACHINE_STYLE` entry (its look) + a `.tres`** — never a scattered if-ladder.
  Behavior-SPECIFIC view reads (renderer `_machine_active`/`_draw_machine_io`, the hover `mode`
  text in `MainView`) keep sane defaults, so most new machines never touch them.
- **The DESCENT ENGINE (`behavior == &"descent"`, docs/PROGRESSION.md §2):** the L1→L2 gate-breacher.
  Standing over THE SEAL (an unbroken worldgen band of unmineable `sealrock`, `SEAL_ROWS` deep from
  `LayeredWorldGen.SEAL_TOP`, with a mineable deepslate SHELF above and IRON only below), `_run_descent`
  EATS gravity-fed `DESCENT_EATS` (ingots) toward `DESCENT_QUOTA` (`MachineState.fed`) — the throughput
  WALL — passing every other item through; at quota it BREACHES the contiguous seal below (`set_solid` +
  pile resettle). *Both numbers were spelled out here as "rows 56-57" and "40" and both had drifted from
  the real 84 and 64. They now name the constants, per DECISIONS: a comment that states a number is a test
  with no runner.*
  Misplaced = `blocked` and everything passes. Research-locked behind the `descent` tech.
- **Placed layers (conduit / rope / torch):** sparse world layers beside `solid`/`wall`, NOT machines —
  item-flow, collision, and the tick never see them. `conduit` carries power. `rope`
  (`is_climbable`/`place_rope`/`remove_rope`) is the placeable climb: `place_rope(anchor)` UNROLLS down
  the open column one carried segment per cell (a stranded digger aims above themself and the rope drops
  to them); `remove_rope` cuts that segment + the hanging tail. The avatar reads `is_climbable` to climb
  (representation-only, like the updraft). `torch` (`has_torch`/`place_torch`/`remove_torch`) is placeable LIGHT: mounts only on a BACKED open cell (wall behind or a solid neighbour); the
  warm pool it casts is pure representation (`_paint_lights`). ALL placed layers use symmetric ledger
  accounting (place = consumed, remove = produced) — **the ledger is total: every item id satisfies
  present == produced − consumed** (craft outputs count produced; placed machines count consumed;
  pickups produce back).
- **Water — the fluid layer (L3 Aquifer):** `water` (cell→integer level `1..WATER_MAX`)
  is authoritative world state beside `solid`/`wall`/`conduit`/`rope`/`torch`/`deposits`. Discrete-cell,
  integer-only (deliberately NOT per-pixel falling-sand — fits the discrete-cell hook). API
  `water_at`/`add_water`/`remove_water`/`total_water`. `WaterFlow.step()` (`src/core/water_flow.gd`, called
  from `FactorySim` each tick after `_flow`) is a
  deterministic snapshot-based two-rule step — DOWN (gravity, the hook) then LATERAL even-fill settle —
  that only MOVES water, so `total_water` is invariant (conserved). `add_water`/`remove_water` are the
  explicit accounted source/drain; `set_solid`/`place_block` DISPLACE (erase) a cell's water. The **Pump**
  (`behavior == &"pump"`, `_run_pump`/`_status_pump`) is the fluid sibling of the lift — while POWERED it
  DRAINS its column (rate ∝ `power_throttle`, `PUMP_RATE`/`PUMP_REACH`), on-hook: water fell in free,
  pumping out costs power. Research-locked behind the `drainage` tech. Seeded from `WorldData.water` in
  `load_world`; rides the save envelope + the determinism canary.
- **Production rate (legibility):** a tick-driven ring buffer of `total_produced` snapshots (1/s, ~60s
  window) behind `production_rate(item)` (per-minute) + `production_rates()` (sorted live list). Derived
  bookkeeping — deterministic, conservation-neutral, never read back by production logic. The HUD's
  hover "factory makes X/min" row + the pack header's "making …" pulse line read it.
- **Factory census (legibility):** `machine_census()` — a pure read over `grid` tallying machines by
  `def.id` with a live `machine_status`-derived working-count (`[{id, name, def, count, working}]`,
  most-numerous-first). Same role as `production_rates()` for the machine side; no state, never ticks.
  The PRODUCTION DASHBOARD ([G]) draws both together — throughput bars + this census.
- **Factory alerts (legibility):** `machine_problems()` — a pure read over `grid` for machines that
  STALLED (`blocked`/`no_fuel`, grouped by id+status, worst-first, each carrying a representative cell;
  starvation `no_input` excluded as "not hooked up yet"). Drives the calm-by-default alert stack; clicking a row pings the culprit (`set_ping`), since the camera is body-locked.
- **Save/load — `SaveGame` (`src/core/save_game.gd`):** the sim being plain data makes a
  save a straight `capture(sim) → Dictionary` of the authoritative state (terrain/wall/deposits, pack/
  ground/sink, both ledgers, the three placed layers, research, machines as def-id + runtime fields),
  in one VERSIONED envelope written with the binary Variant serializer (Vector2i keys round-trip; no
  JSON mangling, envelope **v2**). DERIVED state (grid, power, flow_events, terrain_dirty, the rate
  buffer, the tick accumulator) is not saved — it rebuilds next tick, and restore RESETS it explicitly so
  an in-process F9 and a fresh-process load resume identically. AUTHORITATIVE PHASE (`seep_tick`) *is*
  saved, because when the next weep lands is part of the world's future. `restore(sim, data)` mutates IN
  PLACE (live references survive) and is genuinely all-or-nothing: the whole envelope is validated and
  staged into a scratch dictionary first, so an unknown version, a malformed field, or a missing def
  refuses without having written a single byte into the sim.
  **The write is atomic and keeps a backup:** encode to `<path>.tmp` → close → read it back and prove it
  decodes → copy the current save aside to `<path>.bak` → rename the temp over the slot. A failure at any
  step leaves the previous save intact, and `read()` falls back to `.bak` when the slot is damaged,
  reporting which happened through `SaveGame.last_read` (NONE / OK / RECOVERED / CORRUPT) so the UI can
  tell "you have no save" apart from "your save was damaged". The controller owns the file (F5/F9 →
  `_save_game`/`_load_game`, `user://sinkforge.save` via the overridable `MainView.save_path`, +
  `player_pos` in the envelope) but NOT the seed — `sim.world_seed` is the single authority, and the
  controller keeping a second copy was a live bug that re-stamped loaded worlds with the wrong seed.
  It calls `WorldRenderer.repaint_world()` (requeue all retained chunks + veil, drop lazy caches) after a
  load. **Determinism is the verifier:** capture → restore → tick both 120× → identical signatures
  (`_test_save_load`), plus two live layers — `tools/check_saveload.gd` (boot the real scene: save, scar
  the world, load, exact heal + conservation) and `tools/check_save_durability.gd` (the unhappy paths:
  truncation, unopenable path, missing keys, v1 migration, phase equivalence, seed ownership).
- **Research — the PULL (docs/PROGRESSION.md §5):** `research` (tech id → true) is sim state mutated only
  by `research_tech(id)` — a discrete call that consumes an analyze-SAMPLE of the tech's signature
  material + its refined-goods cost (both ledgered). The tree is static data in **`ResearchRules`**
  (`src/data/research_rules.gd`, the MiningRules pattern): TECHS (requires/sample/cost/unlocks) + ORDER +
  `next_tech`. `craft` refuses defs whose `locking_tech` isn't researched (`craft_unlocked`); the
  controller's `try_research` adds the Bazaar-proximity gate (the bench), and `R` in the pack screen
  researches the next tech. Adding a tech = one TECHS entry.
- **Block placement + the Bazaar:** `place_block(cell, material)` is the Terraria build primitive
  (inverse of `mine`; consumes the material, counted like a craft so conservation holds). A **Bazaar**
  is a structure DETECTED in the world, not a machine: `is_bazaar_at`/`find_bazaars`/`near_bazaar` read
  a distinctive 4×3 wood frame with an open interior — "active" is derived from the world, no state. The
  decorated look + the block-by-block transform on completion live in the `Bazaars` view.
- **The LODE plane — what you EXTRACT, beside what you CARVE (docs/LODE.md):** `lode` (cell → material id)
  and `lode_max` (cell → units the vein held when opened) are sparse layers beside `solid`/`wall`/`water`.
  The old model made a vein *be* the rock, so a tunnel driven through an ore body destroyed everything it
  did not pocket. Now **terrain is what you carve and the lode is what you extract**: a blow OPENS a vein
  rather than ending it, and what the burst did not take stays in the cell to keep working. A lode is not
  collision (you walk through it) and not "items present" (latent, like `deposits`); it is cleared only by
  `load_world` and by being worked dry, and placing a block back over one **covers** it rather than
  destroying it. API: `lode_at` · `lode_workable` · `take_lode` (hand extraction) · `lode_fraction` (the
  denominator the renderer's fleck density thins against — measured against `lode_max`, not against a
  standard vein, or a full 45-unit starter adit draws as one fleck in six and reads as stripped on the
  first face a new player ever sees).
  Three machines work it: the **Head** (`behavior == &"h_drill"`) stands ON a lode and drains it in place;
  the **Spur** (`&"spur"`) is a passive coverage extender chained off a Head; the **Drift Rig** (`&"drift"`)
  cuts rock and sorts pay from spoil into two columns (which is why it owns a `flow` hook — the default
  round-robin deal is exactly wrong for a machine that already sorted at the face).
  **Status (2026-08-17): phase 3a shipped, phase 3b is NOT done** — see `docs/LODE_PLAN.md`. Generated
  worlds now carry a lode plane (`WorldData.lodes` → `FactorySim.lode`), proven across 12 seeds × 5 sizes;
  ore blocks still exist alongside it, and converting them is 3b. The Borer and Drift Rig expose lode, but
  **whether their pay chute draws on a generated world is UNTESTED, not exonerated** — the symptom that
  produced "draws nothing" had an upstream cause (no generated lode existed at all) which 3a removed, and
  no fixture has since driven either machine on a generated world and watched it pay.
- **Finite ore deposits:** `deposits` (cell→remaining yield) is a sparse pool over ore cells; an
  ore cell absent from it counts as 1 (so worlds that never set richness behave as before). Drained
  by hand-`mine` and the Drill; clearing the block only when empty. Latent world resource, NOT
  counted as "items present" — the ore it yields is `total_produced` (conservation-neutral). Seeded
  from `WorldData.amounts` in `load_world`.
- **Depends on:** `MachineState`, and the data Resources (`MachineDef`/`RecipeDef`).
- **Used by:** `MainView` (reads it to draw; drives it via `advance`/place/remove).

### MachineState — per-machine runtime data
- **Location:** `src/core/machine_state.gd` (`RefCounted`, plain data)
- **Responsibility:** Holds one placed machine's mutable state: `cell`, `input_buffer`,
  `output_buffer`, `progress`, and a reference to its shared `MachineDef` (flyweight).

### Data Resources — the content schema (flyweight)
- **Location:** `src/data/` — `MachineDef`, `RecipeDef` and `MaterialDef`, with the `.tres` instances in
  `src/data/machines/`, `src/data/recipes/` and `src/data/materials/`. The static rule tables
  (`bit_rules.gd`, `mining_rules.gd`, `research_rules.gd`, `seams.gd`) sit beside them.
- **Responsibility:** Shared definitions consumed by the generic sim. A machine = a named
  recipe-runner; a source = a recipe with no inputs; a thin `behavior: StringName` tag
  (default empty) lets non-recipe machines branch in the sim without a type-enum. PROVISIONAL machine
  model (see `docs/DECISIONS.md`, 2026-06-27). Every def carries a stable `id: StringName` (save/reference
  safety). **The authoritative list of behaviour tags is `FactorySim._BEHAVIORS`** — this doc used to say
  "the few non-recipe machines (currently the splitter)", which was true when the splitter was the only
  one and had been wrong for a long time by 2026-08-17, when there were eleven. Read the table; don't
  restate it here.

### World engine — the gen↔viz handshake
- **Location:** `src/core/world_data.gd`, `src/core/world_gen.gd`, `src/core/heightmap_world_gen.gd`,
  `src/core/layered_world_gen.gd` (the generator the live world actually uses);
  `src/data/material_def.gd` + `src/data/materials/*.tres`.
- **Responsibility:** Decouple HOW the world is generated from HOW it is visualised, so either
  improves without the other. Three contract pieces:
  - **`MaterialDef`** (Resource, flyweight) — the shared vocabulary. A cell holds a material
    **id**; appearance (`base_color`, `grain`, `cap_color`, `nugget_color`, `depth_darken`) +
    `layer` (`&"block"`/`&"wall"`) live here. The generator emits ids; the visualiser maps
    `id → MaterialDef` through `WorldRenderer`'s `_materials` registry.
  - **`WorldData`** (`RefCounted`, plain data, no engine deps) — the handshake artifact a generator
    PRODUCES and the sim INGESTS: `cols`, `rows`, `seed`, the two grids `blocks` + `walls`
    (cell → material id), `amounts` (deposit richness), and `water` (cell → level, the L3 aquifer
    grid `LayeredWorldGen._seed_aquifers` fills; ingested into `sim.water`).
    The bounded, two-layer world.
  - **`WorldGen`** (`RefCounted`) — `generate(cols, rows, seed) -> WorldData`, contractually
    **deterministic** (seeded RNG). Concrete: `HeightmapWorldGen` (heightmap surface, seeded ore,
    a stone layer below a depth, stone/dirt walls behind sub-surface cells); `LayeredWorldGen`
    (extends it — adds noise CAVES that keep their wall + open up with depth, and DEPTH-BANDED ore
    veins: deeper = richer. Generation-only — zero renderer change. This is what the live world uses).
- **Relationships / dependency rule:** WorldGen depends only on material ids + WorldData (not the
  sim, not rendering). `FactorySim.load_world(WorldData)` ingests both grids; the sim gained a
  background **wall layer** (`wall`, `wall_at`/`set_wall`) and `mine` now clears the block but keeps
  the wall (Terraria-style). The renderer reads the live grids + the registry. **Improve generation
  = a new WorldGen; improve the look = edit MaterialDefs; neither touches the other.** Conforms to
  the node-free-sim / data-driven-Resources / viz-as-driven-layer principles.

### Representation layer — controller / view / cosmetics (disposable, read-only)
The representation is split into focused modules (the node-free sim is the model; none of these write
production state — delete them and the numbers are unchanged):

- **`MainView`** (`scenes/main.gd`, `Node2D`) — the **CONTROLLER + session root**. OWNS a `FactorySim`,
  advances it (pausable), hosts the embodied `Player` + follow `Camera2D` + a screen-fixed `Hud` +
  the `WorldRenderer`, and translates mouse/keys into the body's reach-gated **world-verbs**
  (`try_mine`/`try_deposit`/`try_build`/`try_craft`). Does NOT draw — it pushes the aim cursor + its
  computed reach/placeable/ghost state to the renderer via `set_aim()` each frame. Every world edit
  goes through the sim's discrete API.
- **`WorldRenderer`** (`scenes/world_renderer.gd`, `Node2D`) — the **VIEW**. Draws all world-space sim
  state (terrain texture/AO/surface, background walls, ground piles, machines, the falling stream,
  drop guides, updrafts, the aim cursor) **and** the lighting passes (owns the `MaterialDef` registry,
  the cosmetic clock, the two `LightLayer` canvases + glow textures). One-way data flow: it derives
  what it can from the sim and reads the pushed aim state; it never reaches back into the controller.
  - **Lighting model — SKYLIGHT + ambient (not a depth gradient), as a LIGHTMAP TEXTURE (#17).**
    The darkness is a small texture — ONE TEXEL PER CELL (RGB = SHADOW_COLOR, A = darkness) —
    stretched over the whole world by the `_dark` LightLayer with LINEAR filtering, so light grades
    smoothly in every direction (the old pass drew a rect per cell: hard edges on every lit shaft).
    The skylight/ambient BASE (`_bake_veil_base`, ~0.5 ms) rebakes only when terrain or the
    quantized daylight changes: daylight floods DOWN each column's open air (attenuating via
    `SKY_REACH`), blocked by the first solid rock (`sim.surface_row`), with a night floor above
    ground. Each frame `_update_veil` (~0.04–0.4 ms) copies the base and the live sources CUT
    radial holes in the alpha — lamp, torches, working machines, powered conduits, falling drops —
    so where light falls the veil OPENS and the world shows its true colours; the `_lights`
    LightLayer (additive) then lays the warm pools on top (flicker/pulse stays additive-only; the
    cuts are steady). Warm artificial light vs cold dark = the deliberate vibe, now with light that
    REVEALS rather than just tints.
  - **Post-FX (modern-rendering).** `MainView._setup_post_fx()` adds a
    `WorldEnvironment` (selective softlight GLOW on the bright cores + a gentle colour grade) and a
    full-screen LENS pass — `scenes/post_fx.gdshader` (vignette + film grain + edge chromatic
    aberration) on a ColorRect on a CanvasLayer at layer 5, BELOW the HUD (bumped to layer 10), so the
    world gets the lens and the UI stays crisp. `_setup_ambient_motes()` adds a `GPUParticles2D` dust
    haze (z 45, under the lighting veil — motes glow in the lamp, fade in the dark) that follows the
    camera. All representation-layer; the sim never knows.
- **`Objectives`** (`scenes/objectives.gd`, RefCounted) — the **tutorial chain / legibility guide**
  ("how do I play?"). A sim-READING ordered chain (dig→feed→forge→craft→build→automate); each step's
  predicate is a SESSION DELTA off a baseline snapshot taken at construction (so it guides correctly
  even when the dev-start kit pre-stocks the pack), and completions LATCH. `MainView` owns one + refreshes
  it each frame; the `Hud` renders it top-left. Reads only — deleting it changes no production number.
- **`Hud`** (`scenes/hud.gd`, `Node2D` under a `CanvasLayer`) — the **screen-space UI**, one cohesive
  skin (palette + beveled accent `_panel()`): the OBJECTIVES panel, the machine INSPECTOR (recipe
  in→out chips / mode / holding, pushed by `MainView._hover_info()`), a cached MINIMAP (terrain by
  material + you-here + viewport rect; rebuilt only when `sim.solid` changes; terrain colour via the
  renderer's `material_color` Callable), the FORGED chip, and the unified craft+hotbar "pack". Reads
  the sim + a few pushed values; never mutates.
- **`Settings`** (`scenes/settings.gd`, static) — machine-local **player preferences**: audio levels (master → the Master bus; sound/ambience → dB offsets `Sfx` adds lazily),
  screen-shake toggle, zoom index, and key-binding OVERRIDES rebound into `InputMap` over the
  `Controls` defaults. Persists to `user://settings.cfg` (ConfigFile) — deliberately SEPARATE from
  `SaveGame`: a save is a world, settings are this machine. HARNESS RULE: `persist` is false by
  default and only a real (unscripted) boot loads/saves the file, so every fixture runs on pure
  defaults (`tools/check_settings.gd`, on its own temp path — this used to name its position in the runner,
  "harness layer 13", which drifted the moment anyone added a layer above it). The UI is a drawn
  HUD page (ESC on a calm screen): sliders/chips/remap rows return payloads through
  `Hud.settings_click()`; `MainView` turns them into `Settings` calls — the knob pattern.
- **`Visuals`** (`scenes/visuals.gd`, static) — the shared **visual vocabulary**: the
  `MACHINE_STYLE` registry (behavior tag → glyph kind + casing colour, the representation twin of
  the sim's `_BEHAVIORS`), the scalable animated machine glyph (drawn by both the world + the HUD,
  so they never drift), item glyphs/colour. **`FallingItems`** (`scenes/falling_items.gd`, RefCounted) — the cosmetic falling-product
  layer (state + spawn-from-`flow_events` + advance + draw + light-motes). **`LightLayer`**
  (`scenes/light_layer.gd`) — a thin canvas giving each lighting pass its own blend mode.
- **Input (embodied, Factorio-style):** the bindings themselves are not listed here, because they moved
  and this list did not. `scenes/controls.gd` is the source of truth — it holds every default, keyboard
  and gamepad, and registers them into Godot's `InputMap` at runtime, which is why `project.godot` has no
  `[input]` section at all. `README.md` carries the reader-facing table. Architecturally what matters is
  the shape: `Player` owns movement and rope-riding; every verb that changes the world goes through a
  reach-gated method on `MainView` and nowhere else; and you **auto-collect** product piles by walking
  over them. The cursor is
  context-sensitive (`WorldRenderer._draw_aim`): a solid cell shows a MINE box; an open in-reach cell
  shows a BUILD ghost of the selected machine item (green = placeable) — only when a machine is
  selected. The Ore Vent is excluded from crafting so you stay the ore source by hand. **The economy
  added no determinism/boundary change** — placement/removal/craft are discrete sim calls; reach +
  "where allowed" are representation concerns, so the sim API stays position-agnostic and the
  determinism boundary holds.

### Dev harness (Track B)
- **Location:** `tests/test_*.gd` (headless sim/worldgen/power/stress suites sharing `test_base.gd`),
  `tools/check_*.gd` + `tools/play_tests.gd` (embodied movement + scripted-pilot play-tests).
  Run everything with `bash tools/run_harness.sh`.

---

## Module index

The systems above are the ones whose design needs explaining. These are the rest of the tree: every other
script under `src/` and `scenes/`, so that this file can be checked against `ls` rather than trusted.

### `src/` — no engine dependency beyond `RefCounted`

| Module | What it is |
| --- | --- |
| `src/core/power_flow.gd` | the per-tick power propagation: clears and refills the sim's `power` field from the fuelled generators outward |
| `src/core/water_flow.gd` | the per-tick fluid algorithm, stateless over the sim's `water` and `solid` grids. `WaterFlow.step()` is the water section above |
| `src/core/fine_terrain.gd` | the deterministic fine-grid build of the dual-grid terrain, filling the sim's `_fine_solid` byte grid |
| `src/core/flora.gd` | the per-tick flora pass: planted saplings age into trees |
| `src/data/mining_rules.gd` | how hard each material is to break by hand, and which tool can break it |
| `src/data/bit_rules.gd` | picks that differ in shape rather than in speed. Design: `docs/BITS.md` |
| `src/data/seams.gd` | the grain of the rock: a seam direction per cell, and what striking along it calves off |

### `scenes/` — representation only; reads the sim, never writes to it

| Module | What it is |
| --- | --- |
| `scenes/player.gd` | the embodied avatar. A representation entity that reads the sim's world and owns movement |
| `scenes/grapple.gd` | the piton and winch line: the traversal verb for getting back up |
| `scenes/controls.gd` | the single source of truth for keybindings, keyboard and gamepad, registered into `InputMap` at runtime |
| `scenes/terrain_painter.gd` | the coarse-terrain draw pipeline: per-cell fill, grain, ore crystals, the autotile silhouette |
| `scenes/fine_terrain.gd` | the fine terrain bake, rendering the sim's terrain as molded rock at an 8px sub-cell resolution |
| `scenes/sky_painter.gd` | the parallax celestial backdrop: gradient, stars, sun and moon, clouds |
| `scenes/strata.gd` | the descent named: rows grouped into coloured depth bands, and the accessors over that table |
| `scenes/world_seeder.gd` | builds the tutorial world state onto a freshly generated sim, including the hand-placed spawn fixtures |
| `scenes/hover_info.gd` | assembles the dictionary the HUD's info panel renders for the cell under the cursor |
| `scenes/hints.gd` | just-in-time teaching: a bubble the first time an item with a non-obvious use reaches the pack |
| `scenes/payouts.gd` | the "+3 ore" tick that rises off a broken block, so the reward reads at the point of impact |
| `scenes/particles.gd` | the cosmetic particle layer, driven by bursts `MainView` emits on world verbs |
| `scenes/bazaars.gd` | a representation-only view of the Bazaar structures the sim detects |
| `scenes/art.gd` | a drop-in sprite loader: a texture for a logical key when its PNG exists, and nothing otherwise |
| `scenes/sfx.gd` | procedural audio. Every sound is synthesised at boot rather than loaded |
| `scenes/score.gd` | the music, as a pure function of depth. No track list and no cue system |

Shaders live beside them: `post_fx.gdshader` (described under Drawing in `README.md`), plus
`erase.gdshader`, `heat_haze.gdshader`, `rock_grit.gdshader` and `rock_tooth.gdshader`.

---

## Data Schema Reference
The three schema classes are `src/data/recipe_def.gd`, `src/data/machine_def.gd` and
`src/data/material_def.gd`; the `.tres` files under `src/data/recipes/`, `src/data/machines/` and
`src/data/materials/` are instances of them.

- **`RecipeDef`** — `id: StringName`, `inputs: Dictionary` (item id→count), `outputs: Dictionary`, `time: float`.
- **`MachineDef`** — `id: StringName`, `display_name: String`, `recipe: RecipeDef`, `behavior: StringName`
  (empty = plain recipe-runner; otherwise a tag, of which `FactorySim._BEHAVIORS` is the authoritative
  list), `craft_cost: Dictionary` (item id→count, what the bench charges) and `craft_count: int` (how many
  the craft yields).
- Items are referenced by `StringName` id (e.g. `&"ore"`, `&"ingot"`); no `ItemDef` yet (added when needed).

## Scene Tree Overview
- `Main` (`MainView`, Node2D) — the session root, set as `run/main_scene`. Owns the `FactorySim` in
  script and **hosts real children**: the embodied `Player`, a follow `Camera2D`, the `WorldRenderer`,
  a screen-fixed `Hud` on its own `CanvasLayer` (layer 10), the post-FX `ColorRect` on a `CanvasLayer`
  at layer 5, and a `GPUParticles2D` mote haze. Drawing is still immediate-mode `_draw` inside those
  nodes rather than sprites — that part was never the same claim.

  > *This section read "the entire Prototype-1 scene. Owns the sim in script; no child nodes yet
  > (everything is `_draw`n)" while the Representation section of this same file described MainView
  > hosting a Player, a Camera2D, a Hud and the WorldRenderer. One file, two answers. Corrected
  > 2026-08-17; "no child nodes yet" had been false since the body was embodied.*
