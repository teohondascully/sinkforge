# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-27. This round: independent (Codex) audit of ANVIL's own steps 1-2, the response
to it, and the director's ruling on the resulting budget question.** The ledger now holds Anvil's first
four real events — two `FINDING`s from the audit, a `DECISION` raising the steps-1-2 cap and splitting
how it's measured, and a third `FINDING` recorded against the fix's own history. Step 3 (economy
authoring) still waits for the director.

---

## EXPENSIVE, awaiting you

- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged, still
  deliberately unresolved pending step 6's manifest gate.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged, still undetermined.
- Step 3 (economy authoring) — waits for the director, as it has all session.

## What was learned

- **The system's first real test of recording a correction against itself, and it worked.** The director
  wrote "contradictions unrepresentable"; an external audit found it false; the correction is now six
  rewritten passages in the architecture doc AND a `FINDING` event, `source_class: external-audit`,
  independently checked referentially sound before either was written down as done. `docs/DECISIONS_LEDGER.md`
  D0070.
- **Untyped references were exactly the failure class this project keeps finding, reappearing inside the
  tool built to prevent it.** `MEASUREMENT.claim_id` could point at a real event of the wrong type and
  pass; `CONTENT_LINK.serves_claims` was declared and never traversed. Both fixed (D0069) with a typed
  table, not a patch per symptom — `supersedes`' legal targets are keyed by the SOURCE event's own type
  specifically because the architecture doc already has one documented cross-type case (`DECISION` →
  `ASSUMPTION`) that a same-type-only rule would have wrongly rejected.
- **A fix's own test fixtures can carry the exact bug the fix is closing, and only run-and-observe catches
  it.** Adding claim-id type-checking broke two existing "fixed" test cases whose default fixtures
  happened to self-reference (an id used as both the event's own id and its `claim_id`) — invisible until
  the suite was actually re-run, not from reading the new code.
- **"Almost certainly right" was checked, not trusted, again.** The director's own caution about
  `check_integrity()`'s independent per-check scanning got a dedicated multi-violation fixture last round;
  this round the same discipline applied to the untracked-files gate, which had a claimed 3/3 with no
  checked-in way to re-run it. Now it does (`tools/layer_lint/test_check_untracked_files.py`, 5/5,
  disposable scratch git repos).
- **A cap can be stale rather than wrong, and the two calls for it.** The steps-1-2 cap crossing was
  reported as a HARD STOP; the director's ruling wasn't "cut to fit" but "the cap itself predates the
  scope that crossed it" — raised, not defended against. Reported as two numbers (implementation/test)
  from now on for the same reason the instrument/game ratio measures instrument and game separately: a
  number only means something if it bounds the thing actually meant to be bounded (D0074).
- **A defect class can be proven real by breaking your own "correct" code, not just by breaking bad
  code.** Two of this session's own passing test fixtures turned out to be exactly the semantically-
  nonsensical-but-structurally-valid case reference typing exists to catch — found by running the suite
  after the fix landed, not by review. Logged as a `FINDING` against the schema's own history (D0075),
  the second self-referential finding in three days after D0004's duplicate header — a pattern, not an
  incident.

## What landed this round

Full detail: `docs/DECISIONS_LEDGER.md` D0069-D0073. One commit, pushed, CI confirmed green
(`fb9ce00`, run `33109356157`).

1. **Typed references** (D0069): `schema.REFERENCE_FIELDS` / `SUPERSEDES_LEGAL_TARGETS`; every reference
   now checks existence AND legal target type; `CONTENT_LINK.serves_claims` traversed for the first time.
2. **Language correction** (D0070): "contradictions unrepresentable" → "contradictions become explicit
   event history; resolution becomes deterministic projection behavior" (the audit's own framing, adopted
   verbatim), six occurrences in `incoming/ANVIL_ARCHITECTURE.md`. First `FINDING` event.
3. **Untracked-gate mutation harness** (D0071): checked in, 5/5 cases, real disposable git repos.
4. **Semantic hardening** (D0072): malformed UUID rejected, self-reference rejected (generalized beyond
   `supersedes`), `FINDING.evidence` rejects empty (`independent_of`'s deliberate empty-is-valid case
   preserved, regression-guarded). Deferred with a stated reason in code: supersedes-cycle detection,
   commit-SHA existence, timestamp ordering. Empty-log vacuous PASS fixed — reports "0 events", never PASS.
5. **Seven-types sufficiency** (D0073): second `FINDING` event, three named gaps, NOT resolved, no
   eighth type added.

## Gates

All 27 structural gates PASS, run and confirmed just now. `test_check_integrity.py`: 37/37.
`test_check_untracked_files.py`: 5/5. `check_integrity.py` against the real `.anvil/log/` (4 events, up
from 2): PASS, referentially sound.

**Anvil, reported as two numbers from now on (D0074): implementation 504 / test 420 / total 924.**
Cap is now 1,000 for steps 1-2, applies to implementation only (test LOC uncapped — mutation coverage is
code this project wants more of, not less). Implementation is comfortably under. 2,000-line total budget
unchanged, 1,076 lines of headroom for steps 3-9 (measured against the current 924 total).
**LOC ratio: unchanged this round** (no `core/`/`sim/`/`tests/` GDScript touched) — still 3.599 from the
prior round, not re-measured since nothing that feeds it changed.

**Commits this round: 2** (`fb9ce00`, plus this round's DECISION/FINDING events + ledger). **Unpushed: to
be pushed with this round's commit.**

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured.

## Blocked, and what it's waiting on

- **Step 3 (economy authoring) and beyond** — still waits for the director.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.
- **Cohesion note for step 4** (director's instruction, preserved in `docs/WORKING.md`): projections
  should mirror `sim/invariants`/`replay_determinism_test` deliberately when built, so "one architecture,
  two scales" is visible in the code, not just asserted. Not started — step 4 hasn't either.

## Taste queue

0 fixtures. Unchanged.
