# Sinkforge — Technical Architecture

> The technical source of truth. Every system, its responsibility, its public API, and its relationships. Update this whenever a new system is built or refactored.

## Core Principle: Data-Driven Everything

Machines, materials, recipes, and depth layers are **Godot custom Resources (data files)**, consumed by a generic engine. Adding new content = creating/editing a data file, NOT writing new classes. This is the load-bearing architectural decision.

## Core Principle: Abstract Flow Is Source of Truth

Production math runs entirely through the abstract rate-based flow layer. Discrete falling-item sprites are a COSMETIC layer driven by the same numbers. They never feed back into production calculations. If all item sprites were removed, production counts would be identical.

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
  (PROVISIONAL edge, see docs/RISKS.md). A **lift** (`behavior == &"lift"`) routes UP (`_column_rise`)
  rate-limited by `LIFT_THROUGHPUT`; a **drill** (`behavior == &"drill"`) draws from the WORLD, not a
  buffer — `_run_drill` bores the first ore cell within `DRILL_REACH` straight below, drains its
  finite `deposits` pool (`_drain_deposit`, shared with hand-`mine`), and spits ore down its column
  like an ordinary machine (docs/MINING.md).
- **THE BEHAVIOR REGISTRY (`_BEHAVIORS`):** the ONE sim-side table wiring a `behavior` tag into the
  tick — per-tag `run` / `status` / `dests` hook method-names (dispatched via `call()`; names, not
  bound Callables, so a RefCounted sim never self-references) plus semantic flags (`updraft`,
  `power_source`) read by `updraft_at` and the power sweep. No entry = the default named
  recipe-runner (`_run_recipe`). **Adding a machine behavior = its functions + one `_BEHAVIORS`
  entry + one `Visuals.MACHINE_STYLE` entry (its look) + a `.tres`** — never a scattered if-ladder.
  Behavior-SPECIFIC view reads (renderer `_machine_active`/`_draw_machine_io`, the hover `mode`
  text in `MainView`) keep sane defaults, so most new machines never touch them.
- **The DESCENT ENGINE (`behavior == &"descent"`, docs/PROGRESSION.md §2):** the L1→L2 gate-breacher.
  Standing over THE SEAL (an unbroken worldgen band of unmineable `sealrock`, `LayeredWorldGen.SEAL_TOP`
  rows 56-57, with a mineable deepslate SHELF above and IRON only below), `_run_descent` EATS gravity-fed
  `DESCENT_EATS` (ingots) toward `DESCENT_QUOTA` (40, `MachineState.fed`) — the throughput WALL — passing
  every other item through; at quota it BREACHES the contiguous seal below (`set_solid` + pile resettle).
  Misplaced = `blocked` and everything passes. Research-locked behind the `descent` tech.
- **Placed layers (conduit / rope / torch):** sparse world layers beside `solid`/`wall`, NOT machines —
  item-flow, collision, and the tick never see them. `conduit` carries power (docs/POWER.md). `rope`
  (`is_climbable`/`place_rope`/`remove_rope`) is the placeable climb: `place_rope(anchor)` UNROLLS down
  the open column one carried segment per cell (a stranded digger aims above themself and the rope drops
  to them); `remove_rope` cuts that segment + the hanging tail. The avatar reads `is_climbable` to climb
  (representation-only, like the updraft). `torch` (`has_torch`/`place_torch`/`remove_torch`, FABLE_50
  #26) is placeable LIGHT: mounts only on a BACKED open cell (wall behind or a solid neighbour); the
  warm pool it casts is pure representation (`_paint_lights`). ALL placed layers use symmetric ledger
  accounting (place = consumed, remove = produced) — **the ledger is total: every item id satisfies
  present == produced − consumed** (craft outputs count produced; placed machines count consumed;
  pickups produce back).
- **Production rate (legibility):** a tick-driven ring buffer of `total_produced` snapshots (1/s, ~60s
  window) behind `production_rate(item)` (per-minute) + `production_rates()` (sorted live list). Derived
  bookkeeping — deterministic, conservation-neutral, never read back by production logic. The HUD's
  hover "factory makes X/min" row + the pack header's "making …" pulse line read it.
- **Factory census (legibility):** `machine_census()` — a pure read over `grid` tallying machines by
  `def.id` with a live `machine_status`-derived working-count (`[{id, name, def, count, working}]`,
  most-numerous-first). Same role as `production_rates()` for the machine side; no state, never ticks.
  The PRODUCTION DASHBOARD ([G], FABLE_NEXT_50 #28) draws both together — throughput bars + this census.
- **Save/load — `SaveGame` (`src/core/save_game.gd`, FABLE_50 #1):** the sim being plain data makes a
  save a straight `capture(sim) → Dictionary` of the authoritative state (terrain/wall/deposits, pack/
  ground/sink, both ledgers, the three placed layers, research, machines as def-id + runtime fields),
  in one VERSIONED envelope written with the binary Variant serializer (Vector2i keys round-trip; no
  JSON mangling). DERIVED state (grid, power, flow_events, terrain_dirty, the rate buffer) is not saved
  — it rebuilds next tick. `restore(sim, data)` mutates IN PLACE (live references survive) and is
  all-or-nothing: an unknown version or missing def refuses without touching the sim. The controller
  owns the file (F5/F9 → `_save_game`/`_load_game`, `user://sinkforge.save`, + `player_pos` in the
  envelope) and calls `WorldRenderer.repaint_world()` (requeue all retained chunks + veil, drop lazy
  caches) after a load. **Determinism is the verifier:** capture → restore → tick both 120× →
  identical signatures (`_test_save_load`), plus the live-scene layer `tools/check_saveload.gd`
  (harness layer 12: save, scar the world, load, exact heal + conservation).
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
  decorated look + the block-by-block transform on completion live in the `Bazaars` view (docs/CRAFTING.md).
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
- **Location:** `src/data/` (`MachineDef`, `RecipeDef`; `.tres` instances in `machines/`, `recipes/`)
- **Responsibility:** Shared definitions consumed by the generic sim. A machine = a named
  recipe-runner; a source = a recipe with no inputs; a thin `behavior: StringName` tag
  (default empty) lets the few non-recipe machines (currently the splitter) branch in the sim
  without a type-enum. PROVISIONAL machine model (see DECISIONS 2026-06-27 splitter entry).
  Every def carries a stable `id: StringName` (save/reference safety, docs/RISKS.md).

### World engine — the gen↔viz handshake (see docs/WORLDGEN.md)
- **Location:** `src/core/world_data.gd`, `src/core/world_gen.gd`,
  `src/core/heightmap_world_gen.gd`; `src/data/material_def.gd` + `src/data/materials/*.tres`.
- **Responsibility:** Decouple HOW the world is generated from HOW it is visualised, so either
  improves without the other. Three contract pieces:
  - **`MaterialDef`** (Resource, flyweight) — the shared vocabulary. A cell holds a material
    **id**; appearance (`base_color`, `grain`, `cap_color`, `nugget_color`, `depth_darken`) +
    `layer` (`&"block"`/`&"wall"`) live here. The generator emits ids; the visualiser maps
    `id → MaterialDef` through `WorldRenderer`'s `_materials` registry.
  - **`WorldData`** (`RefCounted`, plain data, no engine deps) — the handshake artifact a generator
    PRODUCES and the sim INGESTS: `cols`, `rows`, `seed`, and two grids `blocks` + `walls`
    (cell → material id). The bounded, two-layer world.
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
  - **Post-FX (modern-rendering, docs/MODERN_FEEL.md).** `MainView._setup_post_fx()` adds a
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
- **`Settings`** (`scenes/settings.gd`, static) — machine-local **player preferences** (FABLE_50
  #36): audio levels (master → the Master bus; sound/ambience → dB offsets `Sfx` adds lazily),
  screen-shake toggle, zoom index, and key-binding OVERRIDES rebound into `InputMap` over the
  `Controls` defaults. Persists to `user://settings.cfg` (ConfigFile) — deliberately SEPARATE from
  `SaveGame`: a save is a world, settings are this machine. HARNESS RULE: `persist` is false by
  default and only a real (unscripted) boot loads/saves the file, so every fixture runs on pure
  defaults (`tools/check_settings.gd` = harness layer 13, on its own temp path). The UI is a drawn
  HUD page (ESC on a calm screen): sliders/chips/remap rows return payloads through
  `Hud.settings_click()`; `MainView` turns them into `Settings` calls — the knob pattern.
- **`Visuals`** (`scenes/visuals.gd`, static) — the shared **visual vocabulary**: the
  `MACHINE_STYLE` registry (behavior tag → glyph kind + casing colour, the representation twin of
  the sim's `_BEHAVIORS`), the scalable animated machine glyph (drawn by both the world + the HUD,
  so they never drift), item glyphs/colour. **`FallingItems`** (`scenes/falling_items.gd`, RefCounted) — the cosmetic falling-product
  layer (state + spawn-from-`flow_events` + advance + draw + light-motes). **`LightLayer`**
  (`scenes/light_layer.gd`) — a thin canvas giving each lighting pass its own blend mode.
- **Input (embodied, Factorio-style):** ←→/AD move, **Space jump**, **W/↑ + S/↓ climb** a rope (grab +
  ride; release hangs; Space jumps off — handled by `Player`); **LMB mine**
  the aimed solid cell (reach-limited); **mouse-wheel** picks the active hotbar slot; **1/2 craft**
  a machine item (Processor/Splitter) from carried ingots; **RMB** places the selected hotbar
  machine item on an in-reach open cell (consumes it) or picks one of your machines back up
  (returns it + salvages its buffers); **E** deposits the selected resource into an in-reach
  machine; **P** pause. You also **auto-collect** product piles by walking over them. The cursor is
  context-sensitive (`WorldRenderer._draw_aim`): a solid cell shows a MINE box; an open in-reach cell
  shows a BUILD ghost of the selected machine item (green = placeable) — only when a machine is
  selected. The Ore Vent is excluded from crafting so you stay the ore source by hand. **The economy
  added no determinism/boundary change** — placement/removal/craft are discrete sim calls; reach +
  "where allowed" are representation concerns, so the sim API stays position-agnostic and the
  determinism boundary holds.

### Dev harness (Track B)
- **Location:** `tests/run_tests.gd` (headless sim tests), `tools/capture.gd` (visual capture).
  See docs/HARNESS.md for the full validation harness and slice-gate procedure.

---

## Data Schema Reference
- **`RecipeDef`** — `id: StringName`, `inputs: Dictionary` (item id→count), `outputs: Dictionary`, `time: float`.
- **`MachineDef`** — `id: StringName`, `display_name: String`, `recipe: RecipeDef`, `behavior: StringName` (empty = recipe-runner, `&"splitter"` = router).
- Items are referenced by `StringName` id (e.g. `&"ore"`, `&"ingot"`); no `ItemDef` yet (added when needed).

## Scene Tree Overview
- `Main` (`MainView`, Node2D) — the entire Prototype-1 scene. Owns the sim in script; no child
  nodes yet (everything is `_draw`n). Set as `run/main_scene`.
