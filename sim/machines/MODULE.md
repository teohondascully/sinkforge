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

`core`, `world` (placement validity queries tile state), `items` (machine
instances consume/produce item instances), `behaviors` (machines are built
from behaviors — this is the direct reason `machines` exists above
`behaviors` in the dependency order).

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
the hub's runners follow, sub-step by sub-step, from `legacy/src/core/factory_sim.gd`.

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

## Gotchas

None yet.
