# sim/invariants

## Purpose

Continuous assertions: conservation of matter across the tick modulo
declared sinks, non-negative buffers, no items inside solid rock, no
machine in an invalid cell, flood level monotonic within a run. This is a
checking module — it reads other submodules' state after they've acted
this tick and flags violations; it doesn't itself produce gameplay state.

## Must-not

- Be disabled in tests. These assertions are the deterministic-sim
  contract made checkable — turning them off to make a test pass hides the
  thing the test exists to catch.

## Dependencies

`core`, `world` ("no items inside solid rock"), `items` (buffer
non-negativity, matter conservation), `machines` ("no machine in an
invalid cell"), `fluid` (flood level monotonic — read directly from
`fluid`'s own state, not through `run`, to avoid needing a dependency on
`run`), `economy` (conservation "modulo declared sinks" needs to know what
economy has declared as a legitimate sink).

## Consumers

`interface`, at minimum — violations surface as part of the telemetry/
rejection surface `observe()`/`apply()` expose. No sim-internal consumer:
this is a terminal, checking-only module that emits into `telemetry` but
nothing in `sim/` reads its output back.

## Tick phase

`invariants` (8th phase — after `economy`, before `telemetry`). This is
one of the phases explicitly named in the fixed order, unlike `commands`
and `telemetry` (see their MODULE.md files).

## Public API

None yet.

## Gotchas

None yet.
