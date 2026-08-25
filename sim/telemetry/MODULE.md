# sim/telemetry

## Purpose

Structured event emission from inside the sim — the record of what
happened this tick (state changes, rejected commands and their reasons,
whatever a scenario's claim needs to measure).

## Must-not

- Do IO. This module emits structured events into an in-memory stream;
  something above `sim/` (in practice, `harness/driver`) is what writes
  them out to `telemetry.jsonl` or wherever they end up.

## Dependencies

`core` only. Event payloads reference `core` primitives (fixed-point
values, entity IDs) the same way `sim/commands` does.

## Consumers

`interface`, at minimum — rejection reasons from `apply()` are part of
telemetry, per L2's contract. `harness/aggregate` (outside `sim/`, listed
here because it's telemetry's whole reason for existing) turns emitted
events into metrics and reports. Sim-internal: effectively every gameplay
submodule (`world`, `body`, `items`, `machines`, `behaviors`, `transport`,
`fluid`, `economy`, `run`, `meta`, `invariants`) emits into this module —
it's a dependency *of* almost everything else in `sim/`, not the reverse.

## Tick phase

Named as the last slot in the fixed tick order (`... -> invariants ->
telemetry`), but that's a flush point, not gameplay logic living in this
module. `telemetry`'s own code is a passive emission API called from
inside every other phase; the named "telemetry" phase is where the
tick's accumulated event queue gets finalized/drained.

## Public API

None yet.

## Gotchas

None yet.
