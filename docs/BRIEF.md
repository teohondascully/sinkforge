# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: four follow-ups on the quality-instrument distributions, plus one
incidental fix.** Unrelated to `data/economy/`, which still waits for the director. The two size gates
reconciled (documented, not merged). A FINDING filed for the `_resolve_horizontal`/JUMP_CORNER complexity
correlation — checked against the real source, found narrower than first framed, filed with the corrected
scope. Python advisory guardrails set and proven decoupled from the self-calibrating fence, with the
decoupling showing up for real within this same round. Stub modules excluded from coupling's corpus,
confirmed as the actual cause of `sim/`'s false "4 outliers." Incidental: the `.import` staleness closed
at its root cause, not just untracked.

---

## This round's five items, in order

1. **`FUNC_LIMIT=50` reconciled, kept as a ceiling — not lowered.** Both gates now cross-reference each
   other, stating explicitly that they answer different questions (unmaintainable vs. unusual-today).
   Lowering it would have forced an immediate split of `_resolve_horizontal`/`_carve_caves`/`tick`/
   `_enforce_grid_bounds`/`move_and_resolve`/`grid_floor_backstop`/`generate` — all working, tested, no
   defect driving it, and would have contradicted this same instruction's own item 2. A new WARN tier
   (mirroring the existing file-level one) was considered and left for you to ask for, not built
   unilaterally — the two choices you gave didn't ask for a third mechanism.
2. **FINDING filed, narrower than first framed.** Checked `sim/body/body.gd:267-274` directly before
   filing: `_resolve_horizontal` contains exactly 1 of D0059's 4 defects, not all 4 — the other 3 live in
   the sibling `vertical_resolve.gd` (2 in `resolve_ceiling`, 1 test-harness-only). Filed with the
   verified scope: complexity flags 3 of 4 defect-adjacent functions once the sibling module is counted,
   but misses `resolve_ceiling` itself — the site with the MOST defects (2 of 4) — whose complexity sits
   below this run's own fence. `.anvil/log/2026-08-28T215456.495534Z-4b27d7cb.json`, severity low,
   confidence high. Not refactored — named as the first candidate for whenever it's next touched.
3. **Python advisory guardrails set: `PY_LENGTH_GUARDRAIL=42.5`, `PY_COMPLEXITY_GUARDRAIL=13.5`** —
   frozen at this run's own fence, advisory only (never gates), proven genuinely decoupled from the
   self-calibrating fence by 8 new mutation cases. The decoupling wasn't just synthetic: later edits in
   this same round grew the real corpus enough that the LIVE length fence moved to 47.5 by the end,
   already diverging from the frozen 42.5 before this report was even written.
4. **Stub modules excluded from coupling's corpus, named in the report.** Confirmed, not just suspected,
   as the cause of `sim/`'s false "4 outliers" — re-running with the exclusion drops it to 0. `sim/`'s 4
   real modules (`body`/`invariants`/`terrain_gen`/`world`) show no outlier once the 10 zero-file stubs
   stop diluting the fence. `tools/` loses one stub (`report/`, a README only) with no change to its
   existing 2 outliers.
5. **INCIDENTAL, closed at the root cause.** `docs/archive/session-exhaust/` never had a `.gdignore`
   (unlike `history/`, which does) — Godot kept reimporting 88 review screenshots every run, drifting
   their tracked sidecars stale. Fixed the same way as `history/`: a new `.gdignore` stops it recurring,
   `.gitignore` stops tracking the sidecars, `git rm --cached` untracks the 88 (files confirmed still on
   disk).

Full reasoning: `docs/DECISIONS_LEDGER.md` D0098.

## LOC — up again, all real content

**929 implementation / 353 test / 1,282 total** (was 847/265/1,112 after D0097). All of the growth is the
two guardrail mechanisms, the stub-exclusion logic, and 8 new mutation cases proving it all fires
correctly — no padding kept to protect a number, same standard as every prior round.

---

## EXPENSIVE, awaiting you

- **`data/economy/`, D1 through D6** — unchanged, still the next substantial thing, authored with you
  present, checked against `tools/economy_check/` as it lands.
- **The WARN-tier option for GDScript function length** — noted, not built: mirroring `check_size_limits.
  py`'s existing file-level WARN/FAIL split at the function level, sourced from the same 19.5 fence. Your
  call whether it's worth a fourth tier of enforcement or the documentation-only reconciliation is enough.
- **Whether `tools/quality_check/` gets wired into CI** — your stated condition (thresholds decided, stub
  question settled) is now met by this round's items 1/3/4; wiring itself is still a separate ask.
- **`_resolve_horizontal`'s complexity** — first refactor candidate, logged, not touched. Comes down as an
  acceptance condition whenever it's next touched for any other reason.
- **`sim/run`/`sim/meta`'s actual shape** — still open, unchanged.
- **Whether lateral variety survives losing re-rolled geology** — unchanged, `docs/GDD.md` §8.
- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged.
- **The two-hop decorative gap** (`tools/economy_check`) — still logged, not fixed, unchanged.

## What was learned

- **A director's own framing can overstate a real finding, and the instrument's job includes catching
  that too, not just catching bugs.** "The four bugs lived in the most complex function" was close but
  not exact — checking the real source before filing found 1 of 4, not 4 of 4. Filing the narrower,
  verified claim instead of the stronger one is what makes the FINDING worth trusting later.
- **A frozen guardrail's value is proven by watching it disagree with the thing it was frozen from, not
  by keeping them in sync.** Building the guardrail feature itself grew the Python corpus enough to move
  the live fence away from the number just frozen — an unplanned, real demonstration of exactly the
  property being built, in the same round, not a discrepancy to chase down and fix.
- **A "4 outliers" finding from two rounds ago dissolved into 0 once its actual cause (zero-padded stub
  modules) was addressed instead of documented as a caveat.** D0096/D0097 both stated the caveat
  correctly; D0098 is what happens when you act on a correctly-stated caveat instead of carrying it
  forward indefinitely.
- **A stale cache artifact's root cause is a missing file, not a missing correction.** Committing 88
  corrected `.import` sidecars would have fixed this ONE staleness; the actual fix was the one file that
  stops it from recurring (`.gdignore`), found by asking why `history/` doesn't have this problem instead
  of just mirroring its `.gitignore` line.

## What landed this round

Full detail: `docs/DECISIONS_LEDGER.md` D0098.

`tools/layer_lint/check_size_limits.py` (docstring only). `tools/quality_check/function_length.py`
(+`PY_LENGTH_GUARDRAIL`), `complexity.py` (+`PY_COMPLEXITY_GUARDRAIL`), `coupling.py`
(+`_split_stubs`), `test_quality_check.py` (+8 mutation cases). One new Anvil `FINDING` event.
`docs/archive/session-exhaust/.gdignore` (new), `.gitignore` (+1 pattern), 88 `.import` sidecars
untracked. Committed and pushed alongside this report.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` + `tools/anvil/
check_integrity.py` (7 events, referentially sound) re-run and PASS. `test_quality_check.py` 32/32.
`duplication.py`: 0 clusters, both languages, unchanged from D0097.

**LOC ratio: instrument total 7,953 / game total 1,428, absolute ratio 5.569.** Trailing-10-commit
window: instrument +2,394, game +4. Still ADVISORY, game LOC under the 2,000-line floor.

**`tools/quality_check/` split: 929 implementation / 353 test / 1,282 total** — up from D0097's 1,112,
reasons recorded in D0098.

**Anvil: 513 / 1,000 cap, unchanged** (no implementation file touched) — 7 events in `.anvil/log/`, +1
this round (the `_resolve_horizontal` complexity `FINDING`).

**Commits this round: 1. Unpushed: 0**, pushed with this report.

## Claims

`C001-two-minute-run.md`: `RETIRED`, unchanged. `C003-cold-start-reaches-d1.md`: `BLOCKED`, unchanged.
`C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`, D1-D6** — waits for you, explicitly, with you present.
- **Whether to build the GDScript function-length WARN tier** — noted as an option this round, not built.
- **Whether `tools/quality_check/` gets wired into CI** — your call now that the stated conditions are met.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, unchanged.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.
- Cohesion note for Anvil step 4 (unchanged, unrelated to this round).

## Taste queue

0 fixtures. Unchanged.
