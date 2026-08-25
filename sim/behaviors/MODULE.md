# sim/behaviors

## Purpose

The composable primitives machines are built from. Under a dozen, ever. A
machine is data (id, tier, footprint, behaviors list, states — see
`data/machines`) plus a small set of shared primitives from here; it is
never its own class.

The exact primitive count and shape is an open design question, not
settled. Do not hardcode an assumption anywhere about how many primitives
there are or exactly what they're named — this module's shape is expected
to move as `sim/machines` gets built out against it.

## Must-not

- Grow one class per machine. If a new machine needs a behavior that
  doesn't decompose into the existing primitive set, that's a design
  problem to solve by extending the primitive set (carefully — "under a
  dozen, ever"), not by adding machine-specific code here or in
  `sim/machines`.

## Dependencies

`core`, `world` (primitives that mutate terrain, e.g. an extraction
primitive), `items` (primitives that consume/produce/store item
instances).

## Consumers

`interface`, indirectly (machine state built from these primitives surfaces
via `observe()`). Sim-internal: `machines` — the only direct sim-internal
consumer. Machine behavior lives here specifically so `sim/machines` stays
free of per-machine-type code.

## Tick phase

None by itself. Behavior primitives execute inline as part of whichever
phase invokes them — chiefly the `machines` phase (3rd).

## Public API

None yet.

## Gotchas

None yet, beyond the open question about the primitive set's final shape.
