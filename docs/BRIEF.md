# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: diagnosing (not fixing) D0125's own two residuals via a
controlled dig-off A/B.** `docs/DECISIONS_LEDGER.md` D0127. **Headline: neither residual is a new bug —
`grounded_no_floor`'s excess is the same already-accepted pit-lip trade-off, now reachable at more
locations because dig can carve new lips; `bounds`'s rise is confirmed dig-attributable, with the
water-mark fix itself adding a further, plausible-but-unproven 11.4% on top.**

---

## The one that matters most: both residuals isolated by geometry, not guessed at

Built a standing `--no-dig` flag on the fuzz probe (D0127) — draws the same random dig-roll every tick,
only overrides the result, so the A/B varies exactly one thing. Full 1000×1500 sweep, dig forced off:

| kind | pre-dig baseline | dig-off (this round) | dig-on (D0125) |
|---|---|---|---|
| `grounded_no_floor` | 32 | **32 (exact match)** | 59 |
| `bounds` (reported) | 18,218 | **18,157 (~match)** | 805,397 |

**`grounded_no_floor`'s 27-violation excess is not a new dig-created defect.** All 91 violations across
both conditions rest at the exact same height (`HostileChamber.FLOOR_ROW`) — the signature of the
already-documented, already-accepted D0059f/D0061 pit-lip trade-off (partial-footprint support), not a
varying-height staircase fragment the water-mark fix would have needed to close. Dig just adds more
reachable lips at that one height by carving holes into previously-flat floor. Confirmed unrelated to the
untraced dy=0 discontinuity (seed=497 appears in neither seed list).

**`bounds`'s rise is confirmed dig-attributable, not an artifact of something else this session
touched** — disabling only dig's behavior returns the count to baseline. The water-mark fix's own further
+82,742 (722,655→805,397) on top of dig's baseline increase is plausible (excavating more per dig removes
more supporting ground near map edges) but not independently proven this cycle.

## What landed

1. **D0127 — the `--no-dig` diagnostic flag**, verified non-disruptive first (`test_body_fuzz_fast.gd`
   and `test_body_fuzz_regression_d0122.gd` both re-run, byte-identical counts to before the change).
2. **Both residuals from the D0125 report traced to a specific, evidenced population, neither fixed** —
   per explicit instruction: both are rulings (re-baseline a bound? accept a cost?), not fixes
   (`grounded_implies_solid_beneath` and `_resolve_horizontal` both untouched).
3. **Not started this round:** the replay driver. The two traces above were the round's whole point per
   your own explicit ordering ("outranks new work, same principle as last round") — both are now
   diagnosed, so it's next, not started here.

## Anything that felt wrong even though it passed

Nothing new this round — both open items from the D0125 report are now precisely attributed (see above),
neither hiding a surprise.

## Gates

All layer_lint gates (including `check_coordinate_naming.py`, now on the standard local checklist),
`schema_validator.py`, `data_codegen --check`, `anvil/check_integrity.py`, `duplication.py`,
`check_untracked_files.py`, `check_working_freshness.py`, `check_base_namespace.sh`, `check_trailers.sh`
— all PASS. `test_body_fuzz_fast.gd` and `test_body_fuzz_regression_d0122.gd` re-confirmed green against
the `--no-dig` addition. The two full-sweep diagnostic runs (dig-on already reported last round, dig-off
this round) were direct probe invocations, not routed through `test_body_fuzz.gd`'s own gate — that
gate's stale `grounded_no_floor<=32` bound is still red pending your ruling from last round, unchanged.

Instrument/game LOC ratio: not re-measured this round (no `core/`/`sim/` change — the only code change is
`tests/fixture_body_fuzz_probe.gd`'s new flag); last measured 5.735 absolute, still ADVISORY.

**Commits this round: 1 so far (the `--no-dig` flag + D0127), well within budget.**

## Claims

`C004-reveal-raises-dig-persistence.md`: `BLOCKED`, unchanged — replay driver still needed.
`C001`/`C002`/`C003`: unchanged.

## Blocked, and what it's waiting on

- **`grounded_no_floor`'s D0061 bound** — waits on you: re-baseline now that the growth is understood
  (same mechanism, more reachable locations), or leave as a live signal.
- **`bounds`'s water-mark-fix-specific +11.4%** — waits on you: accept as a known cost of excavating a
  column's full extent, or worth a closer look.
- **The replay driver** — now correctly sequenced: both `sim/body` residuals from last round are
  diagnosed, neither is a live unknown-shape defect. Next, time permitting.
- **`history/`'s 165-image pre-pivot cull** — waits on you, unchanged.
- **The hands-on-keyboard `--play` test** — stays open and owed, unchanged.
- **`data/economy/`, D1-D6** — unchanged.

## Taste queue

0 fixtures. Unchanged.
