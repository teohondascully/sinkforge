# data/machines

## Purpose

Machine definitions: id, tier, footprint, placement rule, behaviors list,
states, build cost. Read by `sim/machines` and built from the primitives
in `sim/behaviors` — a machine here is data, never code. Adding a machine
should mean adding a file here, not a new class under `sim/`.

## Schema (informal, not yet fixed)

- `id` — stable identifier.
- `tier` — where it sits in progression (see `data/progression`).
- `footprint` — placement shape/size.
- `placement_rule` — what makes a cell valid for this machine.
- `behaviors` — which `sim/behaviors` primitives it's built from.
- `states` — its state machine, in terms of those behaviors.
- `build_cost` — in terms of `data/materials`/`data/recipes`.

## Consumers

`sim/machines` (instantiation, placement validity), `sim/behaviors`
(indirectly — a machine's `behaviors` list references primitives).

## Public API

None yet. No schema has been finalized or validated yet.

## Gotchas

None yet.
