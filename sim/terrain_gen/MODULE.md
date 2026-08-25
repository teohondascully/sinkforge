# sim/terrain_gen

## Purpose

Seeded strata generation, deposit and ruin placement, per-site parameters.
Writes into `world`'s tile grid. Generation is called per-run and scoped to
a bounded shaft region now, not a single persistent grid — this changed
from the pre-pivot design, where terrain generation produced one world that
persisted across the whole game.

## Must-not

- Depend on run state. Generation takes a seed and site parameters as
  inputs; it must not reach into `sim/run` for phase, flood clock, or any
  other in-run state. This keeps generation callable in isolation (by
  `harness/scenario` fixtures, by tooling, by tests) without spinning up a
  run.

## Dependencies

`core`, `world` (for tile and material types — generation writes tiles, it
doesn't invent its own representation of them).

## Consumers

`interface`, indirectly (generated terrain is what `observe()` surfaces
once a shaft exists). Sim-internal: `run` (invokes generation at
site-selection/run-start, scoped to that run's shaft).

## Tick phase

None. Generation runs once at run/site setup, not as part of the fixed
per-tick phase order.

## Public API

None yet.

## Gotchas

None yet.
