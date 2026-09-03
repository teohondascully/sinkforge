# data/recipes

## Purpose

Recipe definitions: what goes in, what comes out, in what quantity.
Implements R2's quantity-based economy — deep material is required in
large quantity rather than simply worth more, and this directory is where
that "large quantity" is a number someone can read and tune, not logic
buried in `sim/economy`.

## Schema

`SCHEMA.yaml` (gate 13), codegen'd to `generated.gd` (gate 22). Lifted in A′ step 3 (D0346) from
legacy's six `RecipeDef` `.tres` records: `id`, `inputs` and `outputs` (item id → count), and
`time_ticks` — legacy's `time` seconds × 20 at the hub's cadence, every one exact. Which machine runs
a recipe is the machine record's `recipe` field, not a list here. `press_plate` and `mill_gear` are
converted because their machines are LIFT; whether their outputs keep a consumer is a plan §8 ruling.

## Consumers

`sim/economy` (conversion math reads recipes from here — never hardcodes a
ratio), `sim/behaviors` (if a conversion primitive reads recipe data
directly rather than through `sim/economy` — see `sim/economy`'s Gotchas
for the unresolved question of exactly where conversion is triggered).

## Public API

`RecipesRecords.RECORDS` (generated) read through `RecipeDef` (`sim/machines/recipe_def.gd`).

## Gotchas

None yet.
