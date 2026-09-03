# data/machines

## Purpose

Machine definitions: id, tier, footprint, placement rule, behaviors list,
states, build cost. Read by `sim/machines` and built from the primitives
in `sim/behaviors` — a machine here is data, never code. Adding a machine
should mean adding a file here, not a new class under `sim/`.

## Schema

`SCHEMA.yaml`, validated by gate 13 and codegen'd to `generated.gd` (gate 22). Lifted in A′ step 3
(D0346) from legacy's `MachineDef` `.tres` records plus the per-type constants legacy kept in code:
`id`, `display_name`, `behavior` (legacy's routing/look tag; empty = the default recipe-runner),
`recipe` (a `data/recipes` id), and the per-type integer parameters each record carries only if its
runner reads them (`fuel_ticks`, `power_demand_milli`, `throughput`, …; power in milli-units,
fractions in percent). **`craft_cost` and `craft_count` are forbidden** and the validator refuses
them with the reason. The earlier informal schema here (tier, footprint, placement_rule, behaviors,
states, build_cost) described a machine system that was never built; placement rules live in the
runners and build cost belongs to the step 7 economy.

15 records: the LIFT list in `docs/A_PRIME_REFACTOR_PLAN.md` §3.2. Not converted, on purpose: the four
awaiting a ruling (`splitter`, `spur`, `ore_vent`, `crusher`) and the three dead (`descent_engine`,
`h_drill`, `drift_rig`). `tests/test_machine_defs.gd` pins the population.

## Consumers

`sim/machines` (instantiation, placement validity), `sim/behaviors`
(indirectly — a machine's `behaviors` list references primitives).

## Public API

`MachinesRecords.RECORDS` (generated) read through `MachineDef` (`sim/machines/machine_def.gd`).

## Gotchas

None yet.
