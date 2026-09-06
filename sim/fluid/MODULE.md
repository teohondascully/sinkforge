# sim/fluid

## Purpose

Water automaton: active-cell set, flood level, aquifer breach.

## Must-not

- Tick every cell every frame. Must use an active-cell set (only cells
  where water state can still change get processed) — this is a hard
  performance constraint, not a style preference.

The base fluid automaton's design contract guarantees total water is
conserved across a tick. Continuous seepage into excavated sections (R3,
`docs/GDD.md` §4 — rewritten 2026-08-27 from a run-ending clock to local,
continuous upkeep) is a controlled, deliberate violation of that contract,
and it must stay contained to one clearly-named function gated by
section/pump state — not threaded through the conservation-preserving
passes. Anyone reading the conservation-checking code should be able to
find the one place water is deliberately injected without having to audit
the whole module.

**What owns the seepage/pump-upkeep logic is an open question, same as
`sim/run`'s own shape (see `sim/run/MODULE.md`).** The description below
still names `run` because nothing has replaced it yet — read it as "whatever
ends up owning local flood/pump state," not a confirmed dependency.

## Dependencies

`core`, `world` (the automaton operates over `World`'s planes: `WaterFlow` reads `TileGrid.is_solid` and
`in_bounds` for every move and writes the `WaterPlane`, which lives in `sim/world` beside the other planes
— ADR 0009, D0347; it was here for one day after D0344).

## Source

Lifted in A′ step 2 (`docs/A_PRIME_REFACTOR_PLAN.md` §4, D0344) from `legacy/src/core/water_flow.gd`
(the algorithm, verbatim) and `legacy/src/core/factory_sim.gd:1100-1135` (the `water` dictionary and
its accessors, now `WaterPlane`). Legacy's cell was one metre; this plane's is the 4 px terrain cell
(`docs/ARCHITECTURE.md` §9: "what water flows through"), so a metre of water is sixteen cells of
`WATER_MAX` and legacy's per-cell rates convert ×16 where they meet it (pump, seep — step 3).

## Consumers

`interface`, at minimum. Sim-internal: `invariants` (flood level in a given
section, monotonic while rising, reads this module's flood level state
directly, not through `run`), `run` (drives the seepage/pump-upkeep
mechanic via the one gated override function described above — provisional
naming, see the open question noted under Purpose above).

## Tick phase

`fluid` (6th phase — after `items`, before `economy`).

## Public API

- `WaterPlane` (`sim/world/water_plane.gd`, moved there in D0347) — the plane. `levels: Dictionary` (terrain_cell → int, absent = dry,
  never a stored 0), `WATER_MAX` (8 per cell). `.water_at()`, `.add_water(grid, terrain_cell, amount)
  → added` (refuses rock and out-of-bounds, clamps to room), `.remove_water(terrain_cell, amount) →
  removed`, `.displace(terrain_cell) → removed` (rock arrived: the world verb calls this),
  `.total_water()` (the conservation probe), `.wet_terrain_cells()` (sorted in the flow's scan order),
  `.set_level()` (THE one write; levels above `WATER_MAX` are legal transiently, see `WaterFlow`),
  `.state_signature()` / `.recomputed_signature()` (running two-lane XOR, `TileGrid`'s pattern, D0261),
  `.clone()`, `.wet_terrain_cells_in(rect)` (the wet cells of a window off the plane's row index, D0405). Derived and
  outside the signature: `touched` (the cells written since the last step, the active set's seed),
  `wake_all`, the row index.
- `WaterFlow` (`water_flow.gd`) — the algorithm, stateless. `WaterFlow.step(water, grid)` once per
  `fluid` phase, over THE ACTIVE SET (D0405): the cells written last tick, the cell above each, the four
  neighbours of every cell the grid's solidity log names (`TileGrid.take_solidity_changes`), then the runs
  the gravity pass touched -- gravity in scan order, then lateral even-fill of each such maximal open run
  with the remainder biased left. `WaterFlow.step_full` is the algorithm as lifted, every wet cell every
  tick, the oracle `step` is pinned equal to (`tests/test_water_active.gd`, `tests/test_water_rest.gd`);
  nothing else calls it. `WaterFlow.settle(water, grid, max_ticks)` runs a plane to rest: `WorldSeeder.load_world`
  hands the player a world whose aquifers have already poured (the boot pour was generation's artifact, V65).

## Invariants

`Invariants.check_water_conservation(water, expected_total, tick)` and
`Invariants.check_water_not_in_rock(water, grid, tick)` (`sim/invariants`), with `report_*` twins that
`push_error`. `tests/test_water_flow.gd` holds both over 10,000 fuzzed ticks.

## Gotchas

The conservation-violating flood-clock function is the one deliberately
special-cased piece of this module — see Must-not above. Everything else
in `fluid` should conserve water exactly.
