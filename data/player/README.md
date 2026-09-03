# data/player

## Purpose

The player's own balance numbers: the pack. `pack.yaml` carries `inventory_slots` (distinct stacks the
hotbar shows) and `bulk_cap` (units of bulk freight the pack holds at once — the number that makes
hauling a repeated job instead of one trip). Lifted in A′ step 3c (D0348) from constants legacy kept in
code. `SCHEMA.yaml`, gate 13; codegen'd to `generated.gd` (`PlayerRecords`), gate 22.

## Consumers

`sim/items` (`Pack`, through the generated record). Nothing else reads it directly.
