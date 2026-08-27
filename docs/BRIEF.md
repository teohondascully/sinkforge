# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-27. This round: independent (Codex) audit of ANVIL's own steps 1-2, and the
response to it.** Two real findings changed the design; the ledger now holds the project's first two
`FINDING` events, logged by an external audit against its own architecture document. **Anvil crossed its
own 800-line steps-1-2 cap (922 lines) doing the fixes the audit asked for — flagged, not buried; see
below.** Step 3 (economy authoring) still waits for the director.

---

## EXPENSIVE, awaiting you

- **Anvil-proper is 922 lines against the queue's own 800-line steps-1-2 cap.** `test_check_integrity.py`
  alone is 420 lines covering 17 branches / 37 cases — real, necessary coverage for real, necessary
  fixes (typed references, self-reference, UUID shape, empty-array semantics), not padding. "Cheap now"
  undersold the actual cost. Not proceeding past the audit's items 1-6 without your read on this.
- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged, still
  deliberately unresolved pending step 6's manifest gate.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged, still undetermined.

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

All 27 structural gates PASS, run and confirmed just now. `test_check_integrity.py`: 37/37 (up from
17/17). `test_check_untracked_files.py`: 5/5 (new). `check_integrity.py` against the real
`.anvil/log/` (2 events): PASS, referentially sound.

**Anvil line count: 922 / 800 cap for steps 1-2 (115% — over) / 2,000 total budget (46%).**
**LOC ratio: unchanged this round** (no `core/`/`sim/`/`tests/` GDScript touched) — still the figure from
the prior round, 3.599, not re-measured since nothing that feeds it changed.

**Commits this round: 1** (`fb9ce00`). **Unpushed: 0.**

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured.

## Blocked, and what it's waiting on

- **Step 3 (economy authoring) and beyond** — still waits for the director.
- **The 922-line overage** — awaiting director direction: proceed, cut, or reconsider the cap.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.

## Taste queue

0 fixtures. Unchanged.
