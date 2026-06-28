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
  `tick()` (one logical step) · reads: `machines`, `grid`, `sink`, `total_produced/consumed`.
- **Topology:** machines occupy grid cells (`GRID_COLS`×`GRID_ROWS`, row increases downward).
  Each tick: every machine runs, then `_flow` hands each machine's output to its **destination
  list** (`_destinations` → `_column_landing`). An ordinary machine has ONE destination (straight
  down its column to the next machine, else `sink`). A **splitter** (`behavior == &"splitter"`)
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
- **Responsibility:** OWNS a `FactorySim`, advances it (pausable), draws the grid + machines +
  buffers + OUTPUT total, and translates mouse/keys into sim placement ops. Reads sim
  production state only — never writes it. Delete it and the numbers are unchanged.
- **Input:** click palette to select; left-click places, right-click removes; space pauses.

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
