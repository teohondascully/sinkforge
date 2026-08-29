# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: the director's ruling on `_handle_dig` executed — per-column
high/low-water mark, full sweep re-run, first nightly-escape regression fixture.**
`docs/DECISIONS_LEDGER.md` D0125–D0126. **Headline: D0122's regression is fixed and verified —
`discontinuity` back to 0, `embedded`/`grounded_no_floor` both moved — but one residual is left open,
not smoothed over: read "Anything that felt wrong" below.**

---

## The one that matters most: D0122 closed — `discontinuity` 3→0, `embedded` 187→0

Per the director's ruling (whole-column dig, refuse-if-would-strand, and fragment cleanup all rejected —
per-column high/low-water mark chosen: a column's dig history is tracked as `[min_row, max_row]` ever
dug, and every touch re-excavates the FULL span, making a within-column gap structurally impossible).
`TileGrid.extend_terrain_dig_extent` (D0125) is the new state, folded into `state_signature()` so
determinism replay still covers it; `Body._handle_dig` excavates its merged range. `_resolve_horizontal`
untouched, per the explicit instruction. Full 1000×1500 sweep, everything else held identical to the
prior D0124 re-run:

| kind | pre-dig | after dig + oracle fix | after this fix |
|---|---|---|---|
| `discontinuity` | 0 | 3 | **0** |
| `embedded` | 1 | 187 | **0** |
| `grounded_no_floor` | 32 | 95 | **59** |
| `bounds` (reported) | 18,218 | 722,655 | **805,397** |

Both `embedded` and `grounded_no_floor` moved substantially — not just `discontinuity` — confirming the
same staircase geometry was the (largest) shared root cause, per the explicit instruction not to declare
victory on `discontinuity` alone.

## What landed

1. **D0125 — the fix, verified before trusted.** New unit tests (`test_tile_grid.gd`: first-touch
   identity, gap-closing merge both directions, overlap, per-column isolation, signature sensitivity)
   and one integration test (`test_body.gd`, two direct `_handle_dig` calls at different `pos_y` in the
   same column). Mutation-tested twice — inverting the merge's `mini`/`maxi` (caught, exactly the
   merge-behavior checks failed) and reverting `_handle_dig` to touch-only excavation (caught by both the
   integration test and, independently, the regression fixture below at the exact D0124 count). Re-ran
   `test_shaft_generator.gd`/`test_replay_determinism.gd` after the `state_signature()` change — clean,
   200/200 checkpoint hashes identical.
2. **D0126 — the first nightly-escape-to-per-commit regression fixture.** `discontinuity`'s reproducing
   case needs the shared grid's dig history accumulated across seeds 0-497 (a fresh-grid replay of
   seed=497 alone reproduces nothing — the load-bearing detail from D0123's own diagnosis), so
   `tests/test_body_fuzz_regression_d0122.gd` replays exactly that prefix (~53s) rather than a
   hand-built minimal case. Now QUALITY gate 29, wired into the per-commit CI job. Passes clean against
   the fix; mutation-tested against the pre-fix behavior, catches it exactly (`discontinuity=3`).
3. **Mid-cycle correction, same-day:** the first push's `extend_dig_extent` tripped
   `check_coordinate_naming.py` (D0020) — a CI-only gate not run locally before that push (public
   function returning `Vector2i` must name its grid in the function name). Renamed to
   `extend_terrain_dig_extent`, pure mechanical fix (`No-Ledger-Entry:` trailer, not a judgment call),
   re-verified locally and via CI before moving on.

## Anything that felt wrong even though it passed

- **`grounded_no_floor` (59) is still above the pre-dig D0061 `DESIGN_TRADEOFF` bound (32)** — real,
  roughly double the old baseline, and NOT root-caused this cycle. The bound in `test_body_fuzz.gd` was
  deliberately left unedited rather than bumped to fit — bumping it without understanding the residual
  would be exactly the resolver-patch instinct the director's own ruling rejected for `_handle_dig`
  itself. This is an open question for you: raise the bound with a real explanation, or trace the
  residual further. Does not block anything currently gated (`test_body_fuzz.gd` is nightly-only).
- **`bounds` rose 722,655 → 805,397 (+11%)**, unrelated to anything this cycle's fix should plausibly
  touch (it tracks the body's box leaving the grid entirely, not column dig extent). Reported because
  it's real, not traced — no working hypothesis yet.
- **CI caught a gate the local run hadn't** (the coordinate-naming check) — worth naming: the standard
  pre-commit gate list I ran locally this cycle didn't include `check_coordinate_naming.py`; it should
  be added to that checklist so this doesn't cost a second push next time.

## Gates

All layer_lint gates (including `check_coordinate_naming.py`, now confirmed both locally and in CI),
`schema_validator.py`, `data_codegen --check`, `anvil/check_integrity.py`, `duplication.py` (0 clusters,
237 GDScript / 164 Python functions), `check_untracked_files.py`, `check_working_freshness.py`,
`check_base_namespace.sh`, `check_trailers.sh` — all PASS. All 18 CI-scoped per-commit Godot suites PASS
(one more than last brief — the new D0126 regression fixture). The full nightly fuzzer
(`test_body_fuzz.gd`, not CI-scoped, not run by CI this cycle) is expected RED against its own stale
`grounded_no_floor<=32` bound — see "Anything that felt wrong" above; not itself re-run this cycle since
the direct probe invocation already produced the real counts.

Instrument/game LOC ratio: **5.735 absolute** (instrument 9,290 / game 1,620), still ADVISORY (game LOC
under the 2,000-line floor). Trailing 10 commits: instrument +1,227, game +135 — mostly this cycle's own
test/fixture additions (`test_tile_grid.gd`, `test_body.gd`, `test_body_fuzz_regression_d0122.gd`), not
economy content; stated plainly, not read as progress toward the eventual target.

**Commits this round: 2 (`d08f6e0`, `8e04c97`), well within the 12-commit budget. ~1hr budget: on
schedule, one hard stop away from crossed (the coordinate-naming gate failure was clearable in one
attempt — a rename — not a design escalation).**

## Claims

`C004-reveal-raises-dig-persistence.md`: `BLOCKED`, unchanged — replay driver still needed.
`C001`/`C002`/`C003`: unchanged.

## Blocked, and what it's waiting on

- **`grounded_no_floor`'s residual (59 vs. the old 32 bound)** — new this round: waits on you, whether
  to re-baseline the bound or trace it further.
- **The replay driver** — correctly sequenced after `sim/body` being defect-free at the fuzzer's own
  full-sweep scale, which is now materially closer (`discontinuity`/`embedded` both closed) but not
  fully there (`grounded_no_floor`'s residual, `bounds`'s unexplained rise).
- **`history/`'s 165-image pre-pivot cull** — waits on you, unchanged.
- **The hands-on-keyboard `--play` test** — stays open and owed, unchanged.
- **`data/economy/`, D1-D6** — unchanged.

## Taste queue

0 fixtures. Unchanged.
