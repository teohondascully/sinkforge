# data/recipes

## Purpose

Recipe definitions: what goes in, what comes out, in what quantity.
Implements R2's quantity-based economy — deep material is required in
large quantity rather than simply worth more, and this directory is where
that "large quantity" is a number someone can read and tune, not logic
buried in `sim/economy`.

## Schema (informal, not yet fixed)

- `id` — stable identifier.
- `inputs` — material id + quantity pairs.
- `outputs` — material id + quantity pairs.
- Which `data/machines` entries can run this recipe.

## Consumers

`sim/economy` (conversion math reads recipes from here — never hardcodes a
ratio), `sim/behaviors` (if a conversion primitive reads recipe data
directly rather than through `sim/economy` — see `sim/economy`'s Gotchas
for the unresolved question of exactly where conversion is triggered).

## Public API

None yet. No schema has been finalized or validated yet.

## Gotchas

None yet.
