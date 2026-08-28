# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: the execution-dense queue (CI wiring, two behavior-preserving
refactors, a full-tree duplication sweep) — closed, 4 commits, all CI-green, budget not hit.** Unrelated
to `data/economy/`, untouched. `docs/DECISIONS_LEDGER.md` D0099–D0102.

---

## What landed

1. **CI wiring (D0099).** `duplication.py` is now a real BLOCKING gate (0 clusters is the clean state; a
   regression fails the build) via a new `run_cli(exit_fn=)` parameter on `scan.py`'s shared harness. The
   other three instruments report as `continue-on-error` steps — GDScript length against the still-
   enforced hard cap, Python length/complexity against the frozen advisory guardrails, coupling with
   stubs excluded. 6 new mutation cases.
2. **`_resolve_horizontal` refactor (D0100).** Complexity 24 → 13 worst-case, two Extract Methods
   (`_resolve_horizontal_cell`, `_try_climb`), no logic changed. Behavior verified byte-identical: 7
   suites ALL PASS before/after, and the full 1000×1500-tick fuzzer's `FUZZ_SUMMARY` byte-identical
   across 1.5M ticks.
3. **`vertical_resolve.gd`'s D0059 functions, checked and treated selectively (D0101).** `resolve_ceiling`
   (6, exactly at the fence) and `resolve_floor` (7, holds no D0059 defect) left alone, stated why.
   `grid_floor_backstop` 10 → 3 (fully resolved, two clean extractions). `move_and_resolve` 11 → 9
   (partial — remaining complexity is the substep loop's own `break`-based control flow, not safely
   extractable by pure mechanical means). A small correction to D0098's own FINDING recorded in the same
   entry: the "back out a failed nudge" fix code actually lives in `move_and_resolve`, not
   `resolve_ceiling` as that FINDING stated. Byte-identical again, same rigor.
4. **Full-tree duplication sweep (D0102).** Found and fixed a real scope gap first: `scan.find_gd_files()`
   was silently `GAME_DIRS`-only, missing `tests/` entirely, despite its own docstring claiming parity
   with `check_size_limits.py` — false, fixed, now proven identical by a set-equality mutation test. The
   sweep itself found one real cluster: `_flat_grid`, byte-identical between `test_body.gd` and
   `test_heightfield.gd` — moved into the shared `test_base.gd` both already extend. 0 clusters, both
   languages, across the genuinely whole tree now.

## Complexity, before → after (this round's targets only)

| function | before | after |
|---|---|---|
| `body.gd::_resolve_horizontal` | 24 | ~3 (dropped out of the outlier list) |
| `body.gd::_resolve_horizontal_cell` (new) | — | 11 |
| `body.gd::_try_climb` (new) | — | 13 |
| `vertical_resolve.gd::resolve_ceiling` | 6 | 6 (left alone, not an outlier) |
| `vertical_resolve.gd::grid_floor_backstop` | 10 | 3 |
| `vertical_resolve.gd::move_and_resolve` | 11 | 9 |
| `vertical_resolve.gd::resolve_floor` | 7 | 7 (left alone, no D0059 defect) |

Worst-case GDScript complexity among this round's actual targets: 24 → 13. Every reduction verified
behavior-preserving by full-fuzzer byte-identical comparison, not just "still green."

## Full-tree duplication result

**0 clusters, both languages**, across the corpus after the scope fix (196 GDScript / 162 Python
functions considered — up from 87/162 once `tests/` was actually reachable). One real cluster found and
fixed this round (`_flat_grid`); everything else clean.

## Instrument/game ratio

**Instrument 8,021 / game 1,477, ratio 5.431.** Game LOC moved this round — 1,424 → 1,477 (+53) — but
**that movement is this session's own refactor work (new extracted-function signatures and docstrings in
`body.gd`/`vertical_resolve.gd`), not `data/economy/` content landing.** Worth distinguishing before
reading the ratio as evidence the economy has started: it hasn't. The floor to watch once it does:
1,477.

## Anvil and instrument LOC against caps

- **Anvil: 513 / 1,000 implementation cap, unchanged** — no Anvil file touched this round, no cap
  crossed (the named hard-stop condition never came close).
- **`tools/quality_check/`: 948 implementation / 404 test / 1,352 total** (was 929/353/1,282 before this
  queue) — the CI-wiring gate logic and the scope-fix mutation tests, all real, requested content.

## Anything that felt wrong even though it passed

- **A FINDING I filed two rounds ago (D0098) had a small, real inaccuracy**, found only because THIS
  round needed more precision than that one did: it attributed the "back-out-a-failed-nudge" fix to
  `resolve_ceiling`; the actual fix code lives in `move_and_resolve`. Nothing broke and the FINDING's
  core claim stands, but it's a reminder that "verified against the real source" is only as precise as
  the question being asked at the time — worth naming rather than letting a two-rounds-old citation stand
  uncorrected.
- **The full-tree scope fix surfaced a genuinely higher complexity outlier than anything this round
  touched**: `tests/fixture_body_fuzz_probe.gd:_check_tick` at complexity 21 — above both refactor
  targets' pre-fix values combined would suggest. Explicitly out of this round's named scope (not
  `_resolve_horizontal` or a D0059-holding function), so left untouched per instruction — but it's real,
  it's in test infrastructure that gets run on every fuzz sweep, and it's now visible for the first time.
  Named, not fixed.
- **`move_and_resolve`'s partial-only resolution (11 → 9) was a judgment call I made autonomously**,
  reading "STOP if it won't come down without behavior risk" as permitting a partial safe reduction
  rather than requiring a full stop. I believe that's the right reading, but it's the one place this
  round where I didn't reach a clean, fully-resolved number, and it's worth a second look rather than
  treated as settled by this report alone.

---

## EXPENSIVE, awaiting you

- **`data/economy/`, D1 through D6** — unchanged, still the next substantial thing, authored with you
  present, checked against `tools/economy_check/` as it lands.
- **`tests/fixture_body_fuzz_probe.gd:_check_tick`'s complexity (21)** — newly visible, not a named
  target this round, your call whether it becomes one.
- **`move_and_resolve`'s remaining complexity (9)** — a design decision (converting `break`-based loop
  control into a return-value contract) would be needed to bring it further down; not made unilaterally.
- **`sim/run`/`sim/meta`'s actual shape** — still open, unchanged.
- The Python function-length/complexity guardrails and GDScript's documented-ceiling framing (D0098) are
  now visible in CI on every push — worth a glance once real data/economy/ content starts moving `sim/`.

## What was learned

- **A scanner's own docstring claim is a testable assertion, not documentation** — `scan.find_gd_files()`
  said "same scope as check_size_limits.py" for four rounds without that ever being checked against the
  other scanner's actual behavior. Checking a claim like that costs one comparison; not checking it costs
  a whole corpus's worth of blind spot.
- **A behavior-preserving refactor's confidence should scale with the function's incident history, not
  just its current test coverage.** Running the full 1000×1500-tick fuzzer twice (not just the fast
  per-commit subset) for `_resolve_horizontal` specifically — because it's the exact function class that
  already cost real time once — is proportionate caution, not excess: the fast subset alone would have
  been "probably fine," the full sweep made it "verified, 1.5M ticks, byte-identical."
- **Partial, honestly-reported complexity reductions are more useful than a clean number reached by going
  further than the safety margin allows.** `grid_floor_backstop` resolved fully because its structure
  allowed it; `move_and_resolve` didn't, and reporting 9 (not 6, not a forced lower number) is what keeps
  this whole instrument's numbers trustworthy.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` + `tools/anvil/
check_integrity.py` re-run and PASS at every commit. `test_quality_check.py` 41/41. Full Godot suite
green in CI at every push (4/4 commits), including the full-fuzz-equivalent confidence this round added
locally beyond CI's own fast-per-commit path.

**Commits this round: 4. Unpushed: 0.** Budget: 4 of 12 commits used, well under the 1-hour allowance.

## Claims

`C001-two-minute-run.md`: `RETIRED`, unchanged. `C003-cold-start-reaches-d1.md`: `BLOCKED`, unchanged.
`C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`, D1-D6** — waits for you, explicitly, with you present.
- **`_check_tick`'s complexity, `move_and_resolve`'s remaining 9** — waits for your read of this report.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, unchanged.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.

## Taste queue

0 fixtures. Unchanged.
