# data

## Purpose

All content as declarative text, never binary resources. Human-diffable,
schema-validated at build time. Balance numbers belong here, never in
code — a tuning pass should be a diff of `data/`, not a code change.

Per-shaft modifiers (constraints like "floods fast", "no fuel above 50m")
are data too, not code branches. If a design constraint can be expressed
as a value in one of these files, it must be — a new `if site.is_flooding:`
branch somewhere in `sim/` is the failure mode this directory exists to
prevent.

## Subdirectories

- `machines/` — machine definitions (id, tier, footprint, placement rule,
  behaviors list, states, build cost).
- `materials/` — material definitions.
- `recipes/` — recipe definitions (implements R2's quantity-based economy).
- `strata/` — terrain-gen tuning constants and per-site parameters.
- `progression/` — meta-progression / unlock data.

Each has its own README.md.

## Consumers

Read by whichever `sim/` submodule needs the content at load time —
chiefly `sim/machines`, `sim/behaviors`, `sim/economy`, `sim/terrain_gen`,
`sim/meta`. `data/` is content, not a code layer in the L0-L4 tower; it has
no dependencies of its own.

## Gotchas

None yet.
