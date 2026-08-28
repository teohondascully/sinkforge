# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: `tools/economy_check/` approved, then three follow-ups landed —
reference integrity, the two-hop residual named in the checker's own output, and an Anvil FINDING
recording it.** Director's verdict on the checker itself: "the instrument whose absence killed the last
game, proven against synthetic failure first." The three follow-ups mirror Anvil's typed-reference
discipline exactly (a director-stated requirement, not a nice-to-have — "one architecture at two scales"
only holds if the reference discipline is identical), surface a known, deliberately-unfixed gap in the
report a reader actually sees, and put that gap in the permanent record rather than only this document.
`test_check_tier_rule.py`: 34/34 OBSERVED. No `core/`/`sim/` code touched. Stopped, as instructed — the
director authors D1-D6 against this checker next, present.

---

## EXPENSIVE, awaiting you

- **`data/economy/`, D1 through D6** — the real demand/material/recipe/unlock rows, authored with you
  present, checked against `tools/economy_check/` as they land. The step this tool was built to make
  safe.
- **`sim/run`/`sim/meta`'s actual shape** — still open, unchanged this round.
- **Whether lateral variety survives losing re-rolled geology** — unchanged, `docs/GDD.md` §8.
- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged.
- **Whether `tools/economy_check/` gets wired into CI** — not decided, still waiting on real data to
  check.
- **The two-hop decorative gap itself** — logged, not fixed, on purpose. When D1-D6 land, this is the
  finding to check the chain against by hand (`.anvil/log/2026-08-28T165338.936688Z-a677726d.json`).

## What was learned

- **Output-consequence clause (b) had the same vacuity clause (a) did, for a structurally different
  reason, surfaced while building the fixture meant to catch a different thing.** If a demand's numeric
  capability grant is what causally satisfies the *next* demand's input-provenance requirement — the
  normal shape of a hardness-escalator chain — that same grant "opens access" to that material too, so
  clause (b) as first specified would pass trivially at every step of the single most common real
  pattern. Fixed by requiring the newly-opened material to also be consumed by a recipe or the breach,
  mirroring clause (a)'s own fix. Verified necessary by hand, then confirmed by the fixture itself
  (`docs/DECISIONS_LEDGER.md` D0092).
- **A mutation test can catch a bug in its own fixture, and that's the check working, not failing.**
  Building the reference-integrity tests, the "FIXED" chain for fixture 7 referenced `ingot_iron` from a
  recipe output and the breach but never added it to the materials registry — caught immediately by the
  very check under test. Fixed once observed, not guessed at in advance (`docs/DECISIONS_LEDGER.md`
  D0093).
- **A residual a checker can't close is still worth building the checker around, as long as the gap
  travels with it.** The two-hop decorative-verb case isn't fixed — closing it means recursively
  verifying everything downstream is non-decorative, a materially larger problem than this rule's scope.
  What changed this round is where the gap lives: from a docstring paragraph to the report's own printed
  output (`RESIDUAL_NOTE`) plus a permanent, referentially-checked Anvil event — a green result can no
  longer be misread as "everything downstream verified."
- **Consistency between two schemas is a testable claim, not a description.** "One architecture at two
  scales" (Anvil's event log, this chain) was true in spirit before this round and now true by direct
  mirroring — the same typed-reference-table shape, the same "resolve first, skip everything else on
  failure" behavior, checked by the same class of mutation test in both.

## What landed this round

Full detail: `docs/DECISIONS_LEDGER.md` D0092 (the build), D0093 (this round's three follow-ups).

`tools/economy_check/` — `schema.py` (128 lines), `check_tier_rule.py` (356 lines), `README.md`,
`test_check_tier_rule.py` (375 lines, 34 mutation cases, all OBSERVED). New this round: reference
integrity (`check_reference_integrity`, `schema.REFERENCE_FIELDS`/`iter_material_references`, mirroring
`tools/anvil/schema.py` exactly), `RESIDUAL_NOTE` printed in every report alongside `SCOPE_NOTE`, and an
Anvil `FINDING` event recording the two-hop gap (`source_class: artifact-instrument`). CLI re-verified
directly against a clean chain and a broken-reference chain. Committed and pushed alongside this report.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` re-run and PASS.
`tools/anvil/check_integrity.py` re-run after appending the FINDING: `PASS -- 5 event(s) checked,
referentially sound.`

**LOC ratio: instrument total 6,418 / game total 1,424, absolute ratio 4.507.** Trailing-10-commit
window (`58fc97f`..HEAD): instrument +859, game +0. Still ADVISORY, game LOC under the 2,000-line floor.
Reported per instruction, not reacted to.

**Anvil: log grew by one FINDING event this round (5 total), the log-content cap does not apply to code**
— implementation 513 / test 420 / total 933, cap 1,000/2,000, unchanged. `tools/economy_check/` is a
separate instrument and does not count against this cap.

**`tools/economy_check/` own split: 484 implementation / 375 test / 859 total** (up from 376/255/631 at
D0092 — this round added 108 implementation / 120 test lines).

**Commits this round: 2** (D0092's build, D0093's follow-ups). **Unpushed: 0**, pushed with this report.

## Claims

`C001-two-minute-run.md`: `RETIRED`, unchanged. `C003-cold-start-reaches-d1.md`: `BLOCKED`, unchanged.
`C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`, D1-D6** — waits for you, explicitly, with you present — the checker is built,
  mutation-tested, and its own known gap is on record, ready to validate the first real chain.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, unchanged.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.
- Cohesion note for Anvil step 4 (unchanged, unrelated to this round).

## Taste queue

0 fixtures. Unchanged.
