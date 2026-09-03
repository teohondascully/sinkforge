# sim/mining

## Purpose

The mining verb: cursor-aim, a reach radius, hold-to-charge, and the per-cell
crack bank that makes a mis-aim cost travel time rather than progress. Plus the
hollow tell — the pure query that says whether there is a void behind the rock
you are about to break.

Re-derived from `legacy/scenes/main.gd::_update_mining` (lines 1522–1624) and
`::_hollow_at` (1638–1652), not lifted: that loop is float, `delta`-driven and
frame-rate dependent. Every accumulator here is an integer on a fixed 60 Hz tick.
`docs/DECISIONS_LEDGER.md` D0195, D0196.

## Public API

`mining.gd` is the primitive; nothing outside `sim/mining/` should reference `hollow_tell.gd`
directly (`Mining.hollow_at` delegates to it). The four verb-layer blocks lifted from legacy's main
scene (A′ step 3i, D0354) are their own interface files: `line_of_sight.gd`, `aim.gd`,
`dig_plan.gd`, `lode_work.gd`.

- `mine(grid, body_x, body_y, target, held) -> Vector2i` — one tick of the verb.
  Returns the cell broken this tick, or `Mining.NO_CELL`. **This is the seam:**
  it is `Command.Mine(target_cell)` in everything but its type. See "Tick phase".
- `banked(cell) -> int`, `break_cost(material) -> int` — for a progress overlay.
- `ticks_to_break(material) -> int`, `hardness_halves(material) -> int`.
- `in_reach(body_x, body_y, cell) -> bool`, `swing_dir(body_x, body_y, cell)`.
- `hollow_at(grid, cell, dir) -> int` — per mille, 0..1000.
- `state_signature() -> String` — the crack bank is real sim state.
- Per-tick telemetry, not auto-cleared: `charging_cell`, `broke_this_tick`,
  `broke_material`, `breach_this_tick`; `broke_cells` and `broke_materials` (parallel: what each
  cleared cell WAS, for `Items.yield_break`); `rhythm()`.
- `LineOfSight.clear(grid, a, b)` — the integer Amanatides-Woo walk between terrain cells; the target
  may be solid; ties step y first. Legacy's float walk, re-derived in exact rationals.
- `Aim.effective(grid, body_x, body_y, point_x, point_y, building) → cell` — exact while building; an
  open or visible solid cell in reach as aimed; else the nearest visible face within a reach of the
  cursor (`nearest_reachable_solid`); else raw. `Aim.cell_of(point)`, `cell_center_fx(cell)`.
- `DigPlan` — `marks` (STATE, signed), `paint(grid, from, to)` (a drag, sampled every half cell; cap
  `MAX_MARKS` 800), `nearest_workable(grid, body_x, body_y)` (prunes spent marks), `clear()`.
- `LodeWork` — the hand on a lode: `work(world, items, mining, body_x, body_y, face, held) → item`
  (one unit every `LODE_CYCLE_TICKS` 33, quickened by the miner's rhythm, not banked; a full pack stalls
  it), `progress_per_mille()`, `target`/`charge` STATE, signed.

## Invariants

- No float, no RNG, no clock. Two runs of the same inputs produce the same
  state signature (`tests/test_mining.gd`).
- `state_signature()` sorts by cell. `CONTEXT.md` forbids iterating a hash map
  in state-affecting code, and an insertion-ordered signature would report a
  false divergence.
- Reach is Euclidean and inclusive, compared squared — never `sqrt`.

## Dependencies

`core` (`Fx`), `sim/world` (`TileGrid`, `WorldMaterials`), and two published
constants from `sim/body` (`Heightfield.TERRAIN_CELL_PX`, `Body.LOGIC_TILE_PX`).
It takes no `Body` object.

## Consumers

`tests/body/reveal_scene.gd` today. At Slice 2 the caller becomes `interface`.

## Tick phase

`input`. It runs after the body has moved, so the reach test uses this tick's
own position, and before invariants.

## The three things that will bite you here

1. **The charge unit is a scaled tick, not a second.** `CHARGE_UNIT` is 1024 so
   the rhythm multiplier survives integer division. A threshold written in
   plain ticks will break cells 1024× too fast.
2. **Hardness scales do not match across the migration.** Legacy's hardness
   numbers *are* seconds (earth 0.28); this project's are unitless (clay 1.0),
   and no single factor maps one onto the other. `TICKS_PER_HARDNESS = 17` is
   derived from the shallow end and leaves the deep end faster than legacy.
   That is a tuning question, not a porting bug.
3. **The tell reads LOGIC TILES, never terrain cells.** Probing legacy's box at
   this world's 4px cell would be 1056 samples per blow instead of 20. And
   out-of-bounds reads **solid** here, the opposite of legacy — these reveal
   sites are 12 logic tiles wide against a 4-tile probe, so legacy's convention
   would make a third of the map a permanent false cavity.

## Not here, deliberately

- **Line of sight in the primitive.** `LineOfSight` exists now (D0354) and every player-facing path
  refuses through rock (`Interface._apply_mine`, `Aim`, `DigPlan`, `LodeWork`), but `Mining.mine`
  itself stays reach-only, as legacy's `FactorySim.mine` was: fixtures pose a body in rock.
- **The save.** The crack bank, the rhythm, the plan and the lode charge are state and are not in the
  v3 envelope yet; they join the body's keys when the interface owns them (ADR 0010 §1, D0354).
- **Tool tiers.** Legacy's `MiningRules.can_mine` gate is the terminal economy,
  which stays dead by the director's ruling.
