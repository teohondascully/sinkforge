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
  (PROVISIONAL edge, see docs/RISKS.md).
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

### MainView — representation + input (disposable, read-only)
- **Location:** `scenes/main.gd` (`class_name MainView`, `Node2D`) + `scenes/main.tscn`
- **Responsibility:** OWNS a `FactorySim`, advances it (pausable), draws the WORLD in world-space
  under a follow `Camera2D`, hosts the embodied `Player` + a screen-fixed `Hud`, and translates
  mouse/keys into the body's **world-verbs**. Reads sim production state only — never writes it;
  every world edit goes through the sim's discrete API (`mine`/`deposit`/`place_machine`/
  `remove_machine`). Delete it and the numbers are unchanged.
- **Input (embodied, Factorio-style):** ←→/AD move, Space jump (handled by `Player`); **LMB mine**
  the aimed solid cell (reach-limited); **mouse-wheel** picks the active hotbar slot; **1/2 craft**
  a machine item (Processor/Splitter) from carried ingots; **RMB** places the selected hotbar
  machine item on an in-reach open cell (consumes it) or picks one of your machines back up
  (returns it + salvages its buffers); **E** deposits the selected resource into an in-reach
  machine; **P** pause. You also **auto-collect** product piles by walking over them. The cursor is
  context-sensitive (`_draw_aim`): a solid cell shows a MINE box; an open in-reach cell shows a
  BUILD ghost of the selected machine item (green = placeable) — only when a machine is selected.
  The Ore Vent is excluded from crafting so you stay the ore source by hand. **The economy added no
  determinism/boundary change** — placement/removal/craft are discrete sim calls;
  reach + "where allowed" are representation concerns (like deposit), so the sim API stays
  position-agnostic and the determinism boundary holds.

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
