# sim/machines

## Purpose

Instances, placement validity, tick scheduling, and the state machine that
drives them. A machine definition is data (see `data/machines`), not a
class — this module provides the generic instance/scheduling/state-machine
framework that every machine type runs through, built from the primitives
in `sim/behaviors`.

## Must-not

- Hardcode a per-type NUMBER. Every constant a runner reads (fuel ticks, throughput, power demand,
  keep percentages) is a field of the machine's record in `data/machines/` and a typed property of
  `MachineDef`; a tuning pass is a diff of `data/`.
- Carry `craft_cost`/`craft_count`, in code or in data: the schema forbids both (D0346).

**Amended 2026-09-03 (D0346, A′ step 3).** This section used to forbid per-machine-type code and
promise a `sim/behaviors` primitive decomposition. That was an aspiration written before any machine
existed; the approved plan (`docs/A_PRIME_REFACTOR_PLAN.md` §1, D0341) lifts legacy's per-type
runners as they are — `_run_drill`, `_run_pump`, `_run_lift`, … dispatched by legacy's behaviour
table — because rewriting working logic into primitives is exactly the from-scratch work A′ exists to
stop. The runners are code, their numbers are data, and `sim/behaviors` stays empty until something
needs it.

## Dependencies

`core`, `data`, `world` (placement validity, the planes a runner reads and bores), `items` (the ledger,
the landing rule, the pack the verbs spend). `behaviors` dropped 2026-09-03 (D0349): the runners are
here, as code, and nothing is built from primitives.

## Consumers

`interface`, at minimum. Sim-internal: `economy` (refinery-type machine
state feeds conversion accounting), `invariants` (checks like "no machine
in an invalid cell" read machine state), `run` (extraction resolution may
reference machine state — "termination" dropped from this line 2026-08-27:
there is no more run-ending event to have a condition for).

Note: `transport` is a peer of `items`/`machines`, not a consumer or a
dependency of this module — it implements R1 (down free, up powered)
alongside them, not through them.

## Tick phase

`machines` (3rd phase — after `body`, before `transport`).

## Source

Lifted in A′ step 3 (D0346) from `legacy/src/core/machine_state.gd`, `legacy/src/data/machine_def.gd`,
`legacy/src/data/recipe_def.gd` and the 15 LIFT `.tres` records (`docs/A_PRIME_REFACTOR_PLAN.md` §3.2);
step 3d (D0349) lifted the hub's registry, `power_flow.gd`, the recipe/generator/hopper/pump/drill
runners, the status reads and the build/pickup/configure verbs from `legacy/src/core/factory_sim.gd`;
lift, splitter, winch, crusher and spur follow in step 3e or wait on a ruling (plan §8).

## Public API

- `MachineDef` (`machine_def.gd`) — one type's definition, a cached flyweight read from
  `data/machines/generated.gd` (`MachinesRecords`). `MachineDef.of(id)` (null if unknown), `.exists(id)`,
  `.ids()` (sorted). Fields: `id`, `display_name`, `behavior` (legacy's tag; empty = recipe-runner),
  `recipe: RecipeDef` (null = none), and the per-type ints `PARAMS` lists (`fuel_ticks`,
  `power_demand_milli`, …; 0 when the record has none).
- `RecipeDef` (`recipe_def.gd`) — `RecipeDef.of(id)`, `.exists(id)`; `id`, `inputs`/`outputs`
  (`StringName` → count), `time_ticks` (legacy seconds × 20, all exact).
- `MachineState` (`machine_state.gd`) — one placed machine: `def`, `logic_cell` (the 16 px cell, D0020),
  `input_buffer`/`output_buffer`, `progress_ticks`, `route_toggle`, `fuel`, `power_permille` (0..1000,
  default 1000), `fed`, `facing`, `mode`, `filter`.
- `Machines` (`machines.gd`, D0349) — THE REGISTRY: `machines` (placement order, state), `machine_at()`,
  `count()`, `machine_logic_cells()` (scan order), `place(world, def, cell, facing)` (refuses unless
  `World.logic_open`; registers `&"machine"` in `LogicGrid`), `remove(world, items, cell)` (destroys the
  buffers, credits them consumed), `first_machine_below()`, static `machine_eats()`, the derived `power`
  field with `power_at()` (milli) and `power_throttle(cell, demand_milli) → per-mille` (THE cost rule),
  `attach_to(items)` (hands `Items` its two buffer Callables), `state_signature()` (power excluded).
- `PowerFlow` (`power_flow.gd`) — `compute(world, machines) → field`, legacy's pass in milli-units with
  the generator's and the conduit's record fields; the field is derived, recomputed every hub tick.
- `Runners` (`runners.gd`) — `run(m, world, items, machines)` by behaviour tag (recipe default),
  `behavior_flag(def, flag)` over `BEHAVIORS`, `has_inputs()`, `buffer_load()`, and the drill reads
  `drill_target()`, `drill_blocked()`, `drill_lode_target()`, `head_coverage()`.
- `MachineStatus.of(m, world, machines)` (`machine_status.gd`) — `working`/`idle`/`no_input`/`no_fuel`/
  `blocked`/`spent`, each read mirroring its runner's gates in order.
- `MachineVerbs` (`machine_verbs.gd`) — static: `build_from_pack()`, `pickup_machine()` (salvage, then
  remove, then spill — the order fix), `configure_machine()`.

## Gotchas

- **`power` is derived.** Recomputed at the top of every hub tick, never saved, never in the signature.
  The tick a generator lights, the field was already computed dark; it powers from the next tick.
- **Placement order is state.** `machines` is walked in order every tick; a save must preserve it.
- **The drill on the metre grid (D0349).** Its target is a metre that is an ore BODY (every rock cell in
  it ore-like; one stone cell caps the column); it bores the metre's 4 px cells in scan order, 16 units a
  cell by default (256 a metre against legacy's 250), and ejects from the target metre.
- **`Machines` holds no `Items`.** Runners and verbs take it as a parameter; `attach_to` points one way.
  A Callable bound to a registry and stored on it would be the RefCounted cycle legacy warned about.
