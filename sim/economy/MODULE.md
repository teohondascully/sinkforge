# sim/economy

## Purpose

Recipes, tiers, refinery conversion, haul accounting. Implements the design
rule that deep material is required in large quantity rather than simply
worth more (R2) — this module is where "large quantity" gets enforced, not
just priced.

**What is here now (A′ step 3f, D0351):** `production_rate.gd`, `ProductionRate` — legacy's
production-rate ring buffer, the one live piece of its economy. Recipes are `data/recipes` read by
`sim/machines`; the produced/consumed ledger is `Items`; the demand side (rig-as-consumer) is plan
step 7 and is not here. Legacy's bazaars, research and crafting are DEAD (D0341).

## Must-not

- Hardcode quantities. All balance numbers (recipe ratios, tier thresholds,
  haul costs) belong in `data/`, never as literals in this module's code. A
  tuning pass should be a diff of `data/`, not a code change here.

## Dependencies

`core`, `items` (conversion consumes/produces item instances; haul
accounting tallies item quantities), `machines` (refinery-type machine
state is what economy's conversion phase acts on), `transport` (haul
accounting reads transport's cost/movement to reconcile value moved against
cost incurred).

Flagged as a judgment call: whether conversion math is triggered by a
behavior primitive calling into `economy` during the `machines` phase, or
by `economy`'s own phase (7th, after `items`) reading machine state that
was merely marked as "processing" during the earlier `machines` phase, is
not settled. Declared here as `economy -> machines` (the second reading)
because it matches the fixed tick order more directly, but the first
reading (`behaviors -> economy`) is equally plausible and would flip this.

## Consumers

`interface`, at minimum. Sim-internal: `run` (extraction resolution
converts hauled items to value via economy), `meta` (stockpile and offline
processing reuse economy's conversion math), `invariants` (conservation of
matter "modulo declared sinks" needs economy's declared sinks to compute
correctly).

## Tick phase

`economy` (7th phase — after `fluid`, before `invariants`).

## Public API

- `ProductionRate` (`production_rate.gd`) — `sample(items)` (a `total_produced` snapshot every
  `SAMPLE_TICKS` = 20 hub ticks, `WINDOW_SAMPLES` = 61 kept), `rate_centi(items, item)` (centi-items a
  minute over the window; 0 until a second of history), `rates(items)` (live items fastest first, ties
  in text order), `sample_count()`. `HubTick.step` samples it when handed one.

## Gotchas

- **Derived, not saved, not signed.** The ring buffer is HUD history; a loaded game starts with an
  empty window, as legacy's did. Integer centi-items a minute: the view formats.
- **`HUB_HZ = 20` is written, not read** (`Body.TICK_HZ / HubTick.HUB_TICK_DIVISOR`), so this module
  does not depend on `sim/run`; `tests/test_economy.gd` pins the identity.
- See the dependency note above re: `machines`/`behaviors`.
