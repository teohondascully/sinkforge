# Brief

Regenerated at the end of every session, overwritten. `CONTEXT.md`, "Review bandwidth." If this takes
more than 90 seconds to read, it's too long.

**Last updated: 2026-08-26. Stage 3 (`sim/world`, `sim/terrain_gen`) landed. Stopped deliberately before
stage 4 (`sim/body`).**

---

## EXPENSIVE, awaiting you

None carried over as blocking. Two EXPENSIVE items named at the top of this stage's grant stay
deliberately open, not resolved unilaterally:

- **Chunk size** (D0019) — `TileGrid` is a sparse `Dictionary`, correct regardless of what fixed size (if
  any) a later pass picks. Revisit once `sim/fluid` and `view/` exist enough to measure the three real
  costs it trades against.
- **Coordinate type scheme** (D0020) — working choice is naming-only (`terrain_cell` vs. `logic_cell`,
  both plain `Vector2i`), two stronger typed alternatives proposed and NOT adopted. Accepts a real risk
  (a cross-grid mismatch is a naming-discipline lapse, not a compile error) until this is revisited.

Two smaller EXPENSIVE-adjacent things decided rather than escalated, because both were closer to "an
obvious defect" than "a judgment call the review-bandwidth test would flag" — logged in full either way:
`no_engine_imports.py`'s FastNoiseLite/RandomNumberGenerator gap (D0023), and per-cell richness/deposit
amounts staying unbuilt until `sim/economy`/`sim/items` exist to consume them (declared in data,
unconsumed — see D0025's 7-of-29 breakdown).

## What landed

- **`sim/world`** (`c3fb970`): `TileGrid` (4px terrain grid, sparse, `terrain_cell`-named coordinates,
  block/wall two-layer model matching legacy) and `WorldMaterials` (hardness registry, hand-mirrors
  `data/materials/*.yaml`). Mutation-checked.
- **`core/split_rng.gd`** (`b30eeab`): `next_float()`/`next_range()`, needed the moment vein placement
  needed acceptance rolls and range picks — general RNG functionality, not terrain_gen-specific. Golden
  vectors from a from-scratch Python reference, mutation-checked.
- **`tools/layer_lint/no_engine_imports.py`** (`d68ba29`, D0023): closed a real gap — `FastNoiseLite` and
  `RandomNumberGenerator` are both Godot engine classes the gate never checked for, and legacy's cave
  carving uses both. Found by reading the gate before writing code that would have needed either one, not
  by a red.
- **`sim/terrain_gen`** (`8b8097a`, `1a585a7`): `ValueNoise` (from-scratch engine-free 2D noise,
  hash+bilinear+smoothstep, calibrated to legacy's [-1, 1] `FastNoiseLite` output range so the ported
  threshold constants keep their meaning), `StrataData` (hand-mirrors `data/strata/shallow_clay.yaml`),
  `ShaftGenerator` (depth-banded base rock, cave carving, ore/coal/iron vein scattering, one empty ruin
  chamber). Scope is D0017's real subset of legacy, not all of it. `_band_hash`/`_is_shelf_band` ported
  verbatim and verified to reproduce legacy's own shipping example exactly (shelf bands at rows 0-3,
  16-19, 28-31, 36-39, 52-55, 64-67). Determinism check (D0022: `tests/`, not `scenarios/`, per `CLAIMS.md`
  §10d) lives in `tests/test_shaft_generator.gd`.
- **Constant-count report** (`250063f`, D0025): 29 of the cited 118 legacy tuning constants carried over
  by value (22 consumed by the generator today, 7 declared-but-unconsumed pending economy/items), 0 of
  heightmap's 19 (a single vertical shaft has no lateral surface to walk across). Full breakdown in D0025.
- **A mutation-testing finding, D0024**: two real safety guards (iron's depth floor, the
  never-fill-a-carved-cave rule) survived being deliberately broken under a full-scale integration test,
  because an accretion blob is compact enough that a real generation run rarely probes either guard.
  Targeted unit tests built specifically to force each guard now catch both; the ledger entry states the
  general lesson.

## Gates

All PASS or ADVISORY. `check_loc_ratio`: ADVISORY, game LOC (724) still under the 2,000-line floor;
the trailing-10-commit velocity check would PASS if it were gating (instrument +525, game +467).
`check_claim_references`: PASS, 0 of 2 claims proven — unchanged, stage 4+ territory.

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured.

## Blocked, and what it's waiting on

- Stage 4 (`sim/body`) — not started, per explicit instruction to stop at this stage's boundary
  regardless of remaining budget (5 of 12 commits unused).
- `sim/transport` / Freight Winch — downstream of stage 4+, unchanged.
- Chunk size and the coordinate type scheme (above) — waiting on measurement, not a missing decision.

## LOC ratio

Instrument 1,839 (tools 947, tests 892) / game 724 (core 273, sim 451). Absolute ratio 2.540,
informational only, ADVISORY under the 2,000-line game-LOC floor. Trailing 10 commits: instrument
1,314 → 1,839 (+525), game 257 → 724 (+467) — velocity check would PASS.

## Taste queue

0 fixtures. Unchanged — the first ones are still wanted at stage 4 (hostile chamber fresh-dig slopes,
rope traversal segment), per `ONBOARDING.md`.
