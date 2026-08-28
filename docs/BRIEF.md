# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: `tools/quality_check/` follow-ups — every finding from the last
round acted on, not left as a report.** Unrelated to `data/economy/`, which still waits for the director.
`core/_ushr` duplication fixed (extracted to `core/bit_ops.gd`). `tools/layer_lint/`'s own two
`find_gd_files` duplications fixed (`gd_scan.py`). The `main()` cluster calibrated as a named,
mutation-tested, risk-logged exclusion — plus a real shared CLI harness so the fix is in the code, not
just hidden from the report. LOC re-measured: **up, not down** (1,011 → 1,112), stated plainly, same
discipline as the overrun itself. 21/21 mutation cases OBSERVED. Full distributions read and reported to
you below, with a recommended guardrail line per metric — not set, your call.

---

## This round's four fixes, in order

1. **`core/_ushr` — fixed.** `entity_id_pool.gd`/`split_rng.gd`'s identical helper extracted to
   `core/bit_ops.gd` (`BitOps.ushr`). A test-file reference the original two-file grep missed
   (`tests/test_entity_id_pool.gd:97`) was caught by actually running the Godot suite, not anticipated —
   fixed, both real suites re-run, ALL PASS. `core/MODULE.md` had previously documented this exact
   duplication as a *deliberate* decision; that's surfaced and superseded, not silently overwritten.
   `duplication.py`: GDScript clusters 1 → 0.
2. **`tools/layer_lint/find_gd_files` — fixed, pre-existing debt not exempted.** Two genuinely different
   filter styles (allow-list vs deny-list), kept as two small named functions in the new
   `tools/layer_lint/gd_scan.py`, not forced behind one flag. All four gates re-verified PASS, file counts
   exactly +1 each (matching the one new file added to the tree — no scope drift).
3. **The `main()` cluster — calibrated, not suppressed.** `duplication.py` now excludes a Python `main()`
   at or under 8 lines (`MAIN_BOILERPLATE_MAX_LINES`), calibrated against every OTHER `main()` in the
   repo (all real branching logic, well over the bound). **Risk stated explicitly, logged as a real Anvil
   `DECISION` event** (`.anvil/log/2026-08-28T213152.609167Z-d61283eb.json`), matching D0074's own
   precedent: a future short-AND-duplicated `main()` would be hidden by this exclusion.
4. **Shared CLI harness — the actual fix.** `scan.run_cli` holds the one dispatch body all four
   instruments' `main()` now delegates to. Item 3 keeps the detector sharp everywhere, item 4 removes
   this specific instance from the source.

Full reasoning: `docs/DECISIONS_LEDGER.md` D0097.

## LOC — up, not down, stated the same way the original overrun was

**847 implementation / 265 test / 1,112 total** (was 794/217/1,011). The `main()` boilerplate that came
out was only 16 lines; the two things this round explicitly required — the exclusion + its risk statement
(+29) and the harness's new home (+18) — added more back, plus 4 new mutation cases (+48 test). Full
`git diff --stat` accounting in D0097 and `tools/quality_check/README.md`. Not trimmed to hide this — same
call as the Anvil cap adjustment (D0074): accept the honest number with the reason recorded.

## The four distributions, read for you — shape, named outliers, a recommended guardrail (not set)

- **Duplication: 0 clusters, both languages** (was 4). Clean. No guardrail question here — a clean run,
  not evidence there's nothing left to find; re-run whenever new code lands.
- **Function length.** GDScript: 85 functions, IQR fence 19.5 lines, 8 above it, longest 50
  (`vertical_resolve.gd:resolve_floor` — exactly AT `check_size_limits.py`'s own hard cap). The existing
  enforced gate (50) sits well above this run's own statistical fence (19.5) — if a guardrail gets drawn
  from this data, it would land far stricter than the current hard cap, which is worth a direct look: is
  50 too generous, or is GDScript's natural function size in this domain just longer than the IQR fence
  assumes? Python: 187 functions, fence 42.5, 14 above it, longest 67 (`check_output_consequence`) — no
  existing hard cap for Python at all; a guardrail near 45-50 would catch the current tail without
  touching the bulk of the distribution.
- **Complexity.** GDScript: 85 functions, fence 6.0, 7 above it, top `body.gd:_resolve_horizontal` at 24
  — the same function D0059's four-defect JUMP_CORNER investigation centered on. A real, notable
  correlation between this metric and actual prior-incident history, not asserted further than that.
  Python: 187 functions, fence 13.5, 9 above it, top `anvil/schema.py:validate_event` at 33 (a large
  `match`/dispatch-shaped validator — worth checking whether it's genuinely branchy logic or a shape this
  metric over-counts before treating it as debt).
- **Coupling — same caveat as D0096, re-confirmed not newly found.** `sim/`'s 4 "outliers" and `tools/`'s
  2 are still an artifact of 10 of 14 `sim/` modules sitting at literal zero .gd files (real stub
  directories, verified — `behaviors`/`commands`/`economy`/`fluid`/`items`/`machines`/`meta`/`run`/
  `telemetry`/`transport` all have 0 files), which drags the IQR fence to ~0 and flags any nonzero
  fan-in/out. Not a coupling problem yet — a sample-size artifact. A real guardrail here should probably
  wait until more `sim/` modules have real code, or the instrument should exclude empty modules from the
  corpus — a design question for you, not decided this round.

**Yield, this run:** duplication 0, function length 22, complexity 16, coupling 6 (repo-wide, both
scopes/languages — up slightly from D0096's numbers only because the corpus itself grew this round, not
because thresholds changed).

---

## EXPENSIVE, awaiting you

- **`data/economy/`, D1 through D6** — unchanged, still the next substantial thing, authored with you
  present, checked against `tools/economy_check/` as it lands.
- **Thresholds for the four quality instruments** — the distributions are above; your call, not proposed
  further here.
- **Coupling's zero-padded-module question** — new this round: should empty `sim/` stub directories count
  in the fan-in/fan-out corpus at all, or dilute the IQR fence the way they currently do?
- **Whether `tools/quality_check/` gets wired into CI** — not decided, dashboard only right now.
- **`sim/run`/`sim/meta`'s actual shape** — still open, unchanged.
- **Whether lateral variety survives losing re-rolled geology** — unchanged, `docs/GDD.md` §8.
- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged.
- **The two-hop decorative gap** (`tools/economy_check`) — still logged, not fixed, unchanged.
- **`tools/quality_check/`'s own LOC** — now 1,112 total, up from 1,011, reasons recorded in D0097 and
  the tool's own README. Not silently absorbed.

## What was learned

- **"The line count comes down" doesn't always survive contact with the rest of the same instruction.**
  The boilerplate that actually existed (16 lines) was smaller than what the OTHER explicit requirements
  in the same instruction (a documented, mutation-tested exclusion; a real shared harness) cost to build
  correctly. Both directions are honest; only one matched the stated expectation, and saying so plainly —
  with the exact accounting — serves the instruction's actual intent (no trimming to hit a number) better
  than quietly hoping the total looked smaller.
- **A prior round's own documented "deliberate decision" can be wrong and still deserve acknowledgment,
  not silent replacement.** `core/MODULE.md` had stated the `_ushr` duplication was intentional. Fixing
  it anyway (per explicit instruction) without noting that reversal would have made the file's history
  read as if nothing had ever justified the old shape — surfacing it costs one paragraph and keeps the
  document honest about its own past.
- **A named exclusion is only as trustworthy as the negative space around it.** Excluding `main()`-shaped
  functions could have been implemented as "skip anything short," which would have silently exempted any
  trivial function, not just entry points. The mutation tests that prove the SAME shape under a different
  name is still caught, and a real over-threshold `main()` is still caught, are what make the exclusion
  narrow instead of just convenient.
- **Logging a calibration decision to Anvil, not just the ledger, is a real second discipline, not
  redundant.** The ledger is prose for a human; the Anvil event is a typed, referentially-checked record
  that a script (`check_integrity.py`) can verify didn't corrupt the log and that a future `OVERRIDE` or
  `DECISION` can formally supersede. D0074 established this pattern for Anvil's own cap; applying it here
  to a quality_check calibration choice keeps both self-referential instruments to their own standard.

## What landed this round

Full detail: `docs/DECISIONS_LEDGER.md` D0097.

`core/bit_ops.gd` (new), `core/entity_id_pool.gd`/`core/split_rng.gd` (`_ushr` removed),
`core/MODULE.md` (updated), `tests/test_entity_id_pool.gd` (fixed reference). `tools/layer_lint/
gd_scan.py` (new), four `layer_lint/` gates updated to delegate to it. `tools/quality_check/scan.py`
(+`run_cli`), `duplication.py` (+`_is_trivial_main_dispatch`), `function_length.py`/`complexity.py`/
`coupling.py` (yield-counter headers + `run_cli` delegation), `test_quality_check.py` (+4 mutation
cases), `README.md` (LOC/testing/gotchas sections updated). One new Anvil `DECISION` event. Committed and
pushed alongside this report.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` + `tools/anvil/
check_integrity.py` (6 events, referentially sound) re-run and PASS. Both real Godot suites
(`test_entity_id_pool.gd`, `test_split_rng.gd`) re-run, ALL PASS. `test_quality_check.py` 21/21,
`test_check_tier_rule.py` 44/44 (unaffected, re-confirmed).

**LOC ratio: instrument total 7,768 / game total 1,428, absolute ratio 5.440.** Trailing-10-commit
window: instrument +2,209, game +4. Still ADVISORY, game LOC under the 2,000-line floor.

**`tools/quality_check/` split: 847 implementation / 265 test / 1,112 total** — up from D0096's
1,011, reasons recorded in D0097.

**Anvil: 513 / 1,000 cap, unchanged this round** (no implementation file touched) — 6 events in
`.anvil/log/`, +1 this round (the `main()`-exclusion `DECISION`).

**Commits this round: 1. Unpushed: 0**, pushed with this report.

## Claims

`C001-two-minute-run.md`: `RETIRED`, unchanged. `C003-cold-start-reaches-d1.md`: `BLOCKED`, unchanged.
`C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`, D1-D6** — waits for you, explicitly, with you present.
- **Quality-instrument thresholds, and the coupling zero-padding question** — waits for your read of
  this round's distributions.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, unchanged.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.
- Cohesion note for Anvil step 4 (unchanged, unrelated to this round).

## Taste queue

0 fixtures. Unchanged.
