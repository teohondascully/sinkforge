# sim/machines

## Purpose

Instances, placement validity, tick scheduling, and the state machine that
drives them. A machine definition is data (see `data/machines`), not a
class — this module provides the generic instance/scheduling/state-machine
framework that every machine type runs through, built from the primitives
in `sim/behaviors`.

## Must-not

- Contain per-machine-type code. There is no "furnace.gd" or "drill.gd"
  here. Machine-specific behavior is expressed as data (which behaviors, in
  what states) plus the shared primitives in `sim/behaviors`.

## Dependencies

`core`, `world` (placement validity queries tile state), `items` (machine
instances consume/produce item instances), `behaviors` (machines are built
from behaviors — this is the direct reason `machines` exists above
`behaviors` in the dependency order).

## Consumers

`interface`, at minimum. Sim-internal: `economy` (refinery-type machine
state feeds conversion accounting), `invariants` (checks like "no machine
in an invalid cell" read machine state), `run` (extraction resolution and
termination conditions may reference machine state).

Note: `transport` is a peer of `items`/`machines`, not a consumer or a
dependency of this module — it implements R1 (down free, up powered)
alongside them, not through them.

## Tick phase

`machines` (3rd phase — after `body`, before `transport`).

## Public API

None yet.

## Gotchas

None yet.
