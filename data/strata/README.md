# data/strata

## Purpose

Terrain-gen tuning constants and per-site parameters. This is where the
~118 hardcoded tuning constants from the legacy (pre-pivot) terrain
generator get extracted to, when that module is ported — none of them
should end up as literals in `sim/terrain_gen`'s code.

## Schema (informal, not yet fixed)

- Per-site parameters: seed inputs, strata bands, deposit/ruin placement
  rules, and any per-shaft modifier ("floods fast", "no fuel above 50m" —
  see `data/README.md`).

## Consumers

`sim/terrain_gen` exclusively, as far as is known now.

## Public API

None yet. No schema has been finalized or validated yet, and the port from
the legacy generator's constants hasn't started.

## Gotchas

The legacy terrain generator this will absorb constants from still exists
in the pre-pivot codebase (being relocated elsewhere as a separate, current
in-progress move — not touched by this scaffolding pass). Porting its ~118
constants here is future work, not done as part of creating this
directory.
