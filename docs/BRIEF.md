# Brief

Regenerated at the end of every session, overwritten. `CONTEXT.md`, "Review bandwidth." If this takes
more than 90 seconds to read, it's too long.

**Last session: 2026-08-26, autonomous, stopped early at a hard stop (not the stage boundary).**

---

## EXPENSIVE, awaiting you

1. **Fixed-point bit depth (`core/` — blocks `sim/body`, `sim/transport`).** `i32, 16 fractional bits`
   is the existing spec (`ARCHITECTURE.md` §4, `core/MODULE.md`), but I can't validate the ±32,767-unit
   range against anything: no pixels-per-meter (or equivalent) constant and no maximum playable depth
   are written down anywhere. Picked nothing. Need either both constants stated somewhere normative, or
   a decision that position uses a chunked/relative scheme instead, which changes what "range" even
   means. `docs/DECISIONS_LEDGER.md` D0004.
2. **Clone-size Phase 1 target is the LOCKED curated archive, not "non-curated."** `history/` +
   `docs/media/moments` (≈303 of ≈332 MB tracked) are explicitly named "the curated archive" and
   protected by `docs/DECISIONS.md`'s "Never destroy a curated file" rule, committed 2026-08-17 on
   purpose as the strongest available protection. Not executed. Full detail: `docs/WORKING.md`.
3. **`check_loc_ratio.py` will very likely FAIL again the next time Stage 1 is attempted, for
   structural reasons, not code quality.** `tools/` (863 lines) already exceeds any plausible `core/`
   size on its own — see "Gates" and D0008 below. Worth deciding how Stage 1 should proceed given this
   before more time goes into it: accept the red as expected and land it anyway, extend the gate's
   bootstrap exception, or pull some `sim/` work forward alongside `core/` so the ratio has something to
   balance against. Not something to resolve without you present — it's a QUALITY-gate calibration
   question, same class as the fixed-point one.

## What landed

- `SplitRng` (`core/split_rng.gd`) — SplitMix64, deterministic split(), get/set_state. 39 tests,
  golden vectors from an independent Python reference, mutation-checked. **Not committed** (see above).
- `EntityIdPool` (`core/entity_id_pool.gd`) — packed-int generational ids, `allocate`/`release`/
  `is_valid`/`live_count`. 29 tests including a 2000-step reproducible randomized-churn check.
  **Not committed.**
- `tests/test_base.gd` — new minimal suite-runner, adapted from `legacy/tests/test_base.gd`'s
  convention. **Not committed.**
- Earlier in the session (all committed and pushed, see `docs/WORKING.md` for the fuller list): the
  Sinkforge-as-stratum design decisions and R1 ADR, the Freight Winch build gate, the review-bandwidth
  and playable-fixtures protocols (this file and `docs/DECISIONS_LEDGER.md` are part of that), and the
  document triage (`docs/EXPERIENCE_EVALUATION.md` promoted, two archive extractions).

## Gates

- **RED: `check_loc_ratio.py`** — instrument 1112 (tools 863, tests 249) vs game 152 (core 152). This is
  the state on disk right now, uncommitted. Was PASS (WARN/bootstrap) before this session's `core/` work
  existed. See D0008.
- All other 5 gates: PASS (`check_claim_references`, `check_size_limits`, `layer_lint`,
  `no_engine_imports`, `schema_validator`).

## Claims

No status or value changes. `C001` and `C002` remain `BLOCKED`, never measured — unaffected by this
session's work (`sim/run`, `sim/body`, `sim/world` still don't exist).

## Blocked, and what it's waiting on

- Fixed-point / `sim/body` / `sim/transport` — waiting on the two missing constants above (EXPENSIVE #1).
- Clone-size Phase 1 — waiting on your go/no-go given the LOCKED-rule conflict (EXPENSIVE #2).
- Stage 1 landing cleanly — waiting on a decision about the LOC-ratio interaction (EXPENSIVE #3).
- Stage 2 (`replay_determinism_test`) — not attempted. Would only add more `tests/` LOC against the same
  small `core/`, worsening the same red rather than sidestepping it.
- Freight Winch / haul work — waiting on `sim/commands` and `sim/run` having real implementations
  (gated earlier this session, unchanged).

## LOC ratio

Instrument 1112 / game 152 = 7.32, on disk (uncommitted). Instrument 863 / game 0 (WARN, not a real
ratio) is what's actually committed at `origin/main`. Delta if the uncommitted work lands as-is: ratio
goes from "unenforceable" to a real, failing 7.32 — this is what EXPENSIVE #3 is about.

## Taste queue

0 fixtures. Unchanged — `harness/` and `scenarios/` are still skeletons.
