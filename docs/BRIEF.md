# Brief

Regenerated at the end of every session, overwritten. `CONTEXT.md`, "Review bandwidth." If this takes
more than 90 seconds to read, it's too long.

**Last updated: 2026-08-26. Stages 1 and 2 both landed. Stopped deliberately before stage 3.**

---

## EXPENSIVE, awaiting you

None carried over as blocking. Everything flagged earlier this session is resolved or explicitly closed:
fixed-point (you supplied the constants, ADR-0003), the LOC-ratio gate (rewritten), clone-size (Phase 1
withdrawn), `docs/handoff/` (reviewed, deliberately deferred), `docs/EXPERIENCE_EVALUATION.md`'s
relationship to `CLAIMS.md` (confirmed, cross-referenced).

The next real decision point is stage 3 (`sim/world`, `sim/terrain_gen`) itself — not attempted, on
purpose, per explicit instruction to stop here regardless of remaining budget.

## What landed

- Clone-size Phase 1 withdrawn; `README.md`'s "On clone size" now states the size, the 165-screenshot
  count, and the loss-prevention reasoning directly. `docs/EXPERIENCE_EVALUATION.md`'s relationship to
  `CLAIMS.md` made explicit in `docs/README.md`'s normative table; its "no layer may certify all six
  questions" thesis marked for `README.md`'s eventual real rewrite. `docs/handoff/` reviewed and closed
  as deliberately deferred.
- **Stage 2 landed** (`f51d722`): `tests/test_replay_determinism.gd` — a throwaway stub (never to become
  `sim/`) exercising `Fx`, `SplitRng`, and `EntityIdPool` together, replayed twice from one seed across
  the full 20,000 ticks `docs/ARCHITECTURE.md` §4 specifies, hashed every 100. Mutation-checked (seed
  drift correctly caught at checkpoint 0) and checked for a frozen-no-op false pass (200 distinct hashes
  of 200 checkpoints).
- Four more ledger entries (D0012-D0015) for stage 2's judgment calls: where the stub lives, why the
  input log is independent of the stub's own RNG, why `String.hash()` is fine here specifically, why the
  tick count wasn't trivialized along with the stub.

## Gates

All PASS or ADVISORY, same as last brief. `check_loc_ratio`: ADVISORY, game LOC (257) still under the
2,000-line floor.

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured — stage 3+ territory.

## Blocked, and what it's waiting on

- Stage 3 (`sim/world`, `sim/terrain_gen`) — waiting on the director's presence for its judgment calls,
  per explicit instruction. Not started.
- `sim/body` / `sim/transport` / Freight Winch — downstream of stage 3+, unchanged.

## LOC ratio

Instrument 1,455 (tools 943, tests 512 across four suites) / game 257 (core only — stage 2's stub lives
in `tests/` on purpose, see D0012). Absolute ratio 5.66, informational only, ADVISORY under the
2,000-line game-LOC floor. Expected to look like this until stage 3 lands real `sim/` code.

## Taste queue

0 fixtures. Unchanged.
