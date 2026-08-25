# data/materials

## Purpose

Material definitions — the deep-material spine referenced by `data/recipes`
(R2), `data/machines` (build cost), `data/strata` (deposit placement), and
`sim/economy` (haul accounting, stockpile value).

## Schema (informal, not yet fixed)

- `id` — stable identifier.
- `tier`/`depth` — where it's found and how it relates to progression.
- `hardness` — read by `sim/world`/`sim/terrain_gen` for dig cost.
- Display/flavor fields, if any, stay separate from anything that affects
  simulation — no balance-relevant number should live only in a display
  field.

## Consumers

`sim/economy`, `sim/machines` (build cost), `sim/terrain_gen` /
`sim/world` (hardness), `data/recipes`, `data/strata`.

## Public API

None yet. No schema has been finalized or validated yet.

## Gotchas

None yet.
