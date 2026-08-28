# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: the director's four-item follow-up on the execution-dense queue
(a known-outlier record, a consolidated sweep-blindness FINDING with a coverage audit, a correcting
FINDING, and the test-code scope rule) — closed, no hard stop.** Unrelated to `data/economy/`, untouched.
`docs/DECISIONS_LEDGER.md` D0103–D0106.

---

## What landed

1. **`move_and_resolve` recorded as a known, accepted complexity outlier (D0103).** Complexity 9 against
   a 6.0 fence — left alone, per instruction: the remainder is the substep `while` loop's own
   `break`-based control flow, not reducible by pure mechanical extraction without a design decision
   (converting loop control into a return-value contract). Recorded directly in the function's own
   docstring with an explicit acceptance condition — complexity comes down when the function is next
   touched for other reasons, not chased now.
2. **The sweep-blindness law, consolidated into one Anvil FINDING (D0105).** Named as one thing, not five
   scattered notes: a sweep bounded by its own author's model of the corpus cannot see outside that
   model, and a green result from it is evidence only about the covered subset. Four cited instances:
   D0026 (`no_engine_imports.py`'s hand-picked class list missed 276/282 real classes), D0091 (two
   run-language sweeps missed CLAUDE.md/docs/CLAIMS.md/eight MODULE.md files), D0075 (self-referencing
   test fixtures), D0102 (`scan.find_gd_files()` itself, inside the exact instrument suite this failure
   class motivated building). Concrete follow-through: every `quality_check` instrument's scan scope
   audited and tabulated (`tools/quality_check/README.md`) — `duplication.py`/`function_length.py`/
   `complexity.py` all share `scan.all_functions()`, so D0102's fix already closed the gap for all three;
   `coupling.py`'s narrower `sim/`+`tools/` scope is a stated design decision, not a hidden gap, with one
   latent non-recursive-glob gap named for the record.
3. **D0098's FINDING corrected via a real superseding Anvil event (D0104).** The original attributed BOTH
   D0059 defects #2 and #3 to `resolve_ceiling`; #2's actual "back out the failed nudge" fix lives in
   `move_and_resolve` (the caller), which owns the substep loop the backout happens inside. Filed as a
   `FINDING` with `--supersedes=` the original — original event untouched, append-only, per the project's
   own standing discipline. Does not change the original's core claim (1 of D0059's 4 defects lives
   directly in `_resolve_horizontal`, not all 4).
4. **Test code's place in the quality instruments, decided once (D0106).** Same self-calibrating IQR
   methodology as production code, computed against test code's OWN population, reported as its own
   labeled section — never pooled (distorts the fence for both, the same problem `coupling.py`'s stub
   exclusion solved), never a looser a priori number (a guess wearing a decision's clothes), never
   exempted (recreates a blind spot right after D0102/D0105 closed one). `scan.is_test_func` classifies
   by this repo's own existing `tests/`/`test_*.py` conventions — not a new one invented for this.
   `function_length.py`/`complexity.py` restructured into four buckets each. Frozen advisory guardrails
   stay whole-Python-population, unsplit, since they're an absolute drift tripwire, not a distributional
   read.

## Test population split, verified against the live tree

| population | length fence | complexity fence | n |
|---|---|---|---|
| GDScript production | 19.5 | 6.0 | 90 |
| GDScript `tests/` | 25.0 | 6.0 | 175 |
| Python production | 50.0 | 14.5 | 119 |
| Python `test_*.py` | 42.5 | 8.5 | 78 |

Test code's own fences sit measurably above production code's on both instruments — confirms the pooling
concern (item 4) was real, not hypothetical: pooling would have suppressed real production outliers
behind a fence inflated by test code's legitimately larger natural size, and flagged legitimate test-code
shape as a false outlier against a fence calibrated on smaller production functions.

## Full-tree duplication result

**0 clusters, both languages, unchanged.** 196 GDScript / 164 Python functions considered (re-run this
round, no code-scope change since D0102).

## Instrument/game ratio

**Instrument 8,063 / game 1,485, ratio 5.430.** Game LOC moved +61 over the trailing 10 commits — but
that movement is refactor-signature extraction from the prior queue (`_resolve_horizontal_cell`/
`_try_climb`/etc.), not `data/economy/` content, and is named honestly as such rather than read as
progress toward the ratio target. The number does not come down until the economy produces machines —
the director's own next work, not this session's. Then hold.

## Anvil and instrument LOC against caps

- **Anvil: 513 / 1,000 implementation cap, unchanged** — no Anvil implementation file touched this round
  (two new `.anvil/log/*.json` event files were written — FINDING events, not code, and don't count
  toward the code cap).
- **`tools/quality_check/`: 990 implementation / 404 test / 1,394 total** (was 948/404/1,352 before this
  round) — the four-bucket restructure and its docstrings, all real, requested content; test LOC
  unchanged since item 4 needed six lines of reference repair, not new mutation cases.

## Anything that felt wrong even though it passed

- **My own D0106 ledger entry, first draft, claimed the mutation suite "grew from 21 to 41 cases" this
  round.** Checked against actual tool output (stashing this round's changes and re-running against HEAD)
  before committing to it: the suite was already at 41 before this round started — the growth to 41
  happened in the two prior commits (`c56ff1f`, `42e517f`), not this one. This round's actual mutation-
  suite work was six lines of reference repair, not new cases. Caught and corrected before the entry was
  ever committed, not after — worth naming because it's exactly the kind of unverified-count claim this
  project's own standing rule ("verify a numeric claim against actual tool output") exists to catch, and
  it would have shipped a small, false claim into a permanent ledger entry if not checked.
- **`tools/quality_check/README.md` had two flatly false sentences** ("None exits nonzero on a finding;
  none is wired into CI" / "Consumers: None yet. Not wired into CI.") left over from before D0099's CI
  wiring landed two commits ago — stale documentation sitting untouched next to otherwise-accurate prose
  in the same file. Not part of this round's assigned scope, but fixed in the same pass since I was
  already editing this exact file for the scope-audit table and test-population sections; leaving a known
  false claim in place while editing its neighbor would be the same "instrument cannot register its
  subject" class this project treats as its dominant failure mode, applied to documentation instead of
  code.

---

## EXPENSIVE, awaiting you

- **`data/economy/`, D1 through D6** — unchanged, still the next substantial thing, authored with you
  present, checked against `tools/economy_check/` as it lands.
- **`move_and_resolve`'s remaining complexity (9)** — accepted per your instruction, condition recorded
  in the function's own docstring; no action needed unless you want to revisit the acceptance condition
  itself.
- **`tests/fixture_body_fuzz_probe.gd:_check_tick` / `tests/test_body_acceptance.gd:_run_traverse`'s
  complexity (21 each)** — named at D0105's coverage audit, not touched, your call whether either becomes
  a target.
- **`coupling.py`'s non-recursive `.glob` on `tools/<module>/*.py`** — a latent, currently-inert scope gap
  named at D0105's audit table; would silently diverge the day a `tools/` module grows a nested `.py`
  file. No action needed now, worth knowing about.
- **`sim/run`/`sim/meta`'s actual shape** — still open, unchanged.

## What was learned

- **A ledger entry's own numeric claim needs the same verification discipline as any other claim, even
  when the number "obviously" moved.** The 21→41 mutation-count claim felt true (the file visibly grew
  across this whole segment) but was wrong about WHEN — checked against actual `git stash` + rerun output
  before it shipped, not assumed from narrative momentum.
- **A restructure that changes a result dict's SHAPE (not its coverage) can leave a mutation suite's case
  COUNT unchanged while still breaking every reference into it.** `function_length.py`/`complexity.py`'s
  guardrail moving from `result["py"]["guardrail_hits"]` to a new top-level `result["python_guardrail"]`
  key broke two existing assertions with zero new scenarios needed — worth distinguishing "the suite grew"
  from "the suite's existing assertions needed updating" as two different, non-conflatable events.
- **Fixing a stale doc sentence found by accident, while already in the file for an unrelated reason, is
  worth the two extra minutes.** The false CI-status sentences in `tools/quality_check/README.md` would
  have sat there indefinitely otherwise — nothing was scanning prose claims against actual CI config.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` + `tools/anvil/
check_integrity.py` (9 events, referentially sound) + `duplication.py` (CI's blocking gate, 0 clusters)
re-run and PASS. `test_quality_check.py` 41/41. `tests/test_body.gd` re-run ALL PASS after the
`vertical_resolve.gd` docstring addition (comment-only, parse-checked clean, no logic touched).

**Commits this round: pending (about to commit). Unpushed before this round's commit: 0.**

## Claims

`C001-two-minute-run.md`: `RETIRED`, unchanged. `C003-cold-start-reaches-d1.md`: `BLOCKED`, unchanged.
`C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`, D1-D6** — waits for you, explicitly, with you present.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, unchanged.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.

## Taste queue

0 fixtures. Unchanged.
