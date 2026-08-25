# Brief

Regenerated at the end of every session, overwritten. `CONTEXT.md`, "Review bandwidth." If this takes
more than 90 seconds to read, it's too long.

**Last updated: 2026-08-26, after Stage 1 landed.**

---

## EXPENSIVE, awaiting you

1. **Clone-size Phase 1 conflict** — see the director's item 3 reply this session for the one-paragraph
   statement of the conflict. Not executed either way.
2. **Doc-triage follow-through on `docs/EXPERIENCE_EVALUATION.md`** — is the CLAIMS.md §5 cross-reference
   (already committed) the right resolution, or should the two documents merge further? Awaiting your
   read of the pasted section.
3. **`docs/handoff/` and `history/`** — tracked-status answered this session (`history/` tracked, 228MB;
   `docs/handoff/` untracked, 199MB). Neither moved. Still awaiting a decision on what to actually do
   about either.

Resolved since the last brief: fixed-point bit depth (director supplied the missing constants directly,
ADR-0003) and the LOC-ratio gate calibration (rewritten as a trend measure, own commit).

## What landed

- `check_loc_ratio.py` rewritten: trailing-10-commit-window trend, 2x floor, ADVISORY under 2,000 game
  LOC, absolute ratio always printed. `.github/workflows/harness.yml`'s `gates` job given
  `fetch-depth: 0` so the window actually has history to read in CI. Verified against four synthetic
  git repos (insufficient history, balanced growth, >2x violation, sub-floor game LOC) before trusting
  it. Commit `4fbfb71`.
- `docs/ARCHITECTURE.md` §9 gained "The world scale" (16px/m, 4px terrain grid, 4096px/256m max depth)
  and `docs/adr/0003-fixed-point-representation.md`.
- **`core/` Stage 1 landed** (commit `560ee78`): `Fx` (fixed-point, i32/16-fractional-bits, validated
  against the constants above — `length()`/`length_sq()` documented and test-demonstrated as
  local-neighborhood-only, safe to ~181px per axis), `SplitRng` (SplitMix64, 39 tests), `EntityIdPool`
  (packed-int generational ids, 29 tests). 96 tests across three suites, all green, all mutation-checked.
- Two real GDScript-runtime findings worth knowing before writing more `core/`/`sim/` code, both now in
  `core/MODULE.md`'s Gotchas: (1) an unguarded runtime error (division by zero, etc.) inside a bare
  `--headless --script` run doesn't crash, it hangs forever with no exit code; (2) `>>`/`<<` reject a
  syntactically-negative left operand at parse time but allow the identical value through a variable.

## Gates

All PASS or ADVISORY (informational, non-blocking): `check_claim_references`, `check_size_limits`,
`layer_lint`, `no_engine_imports`, `schema_validator` — PASS. `check_loc_ratio` — ADVISORY, game LOC
(257) under the 2,000-line floor; velocity check would currently FAIL on its own (instrument grew faster
than game over the last 10 commits, expected while `core/` is landing without `sim/` alongside it yet)
but this isn't gating.

## Claims

No status or value changes. `C001`, `C002` remain `BLOCKED`, never measured.

## Blocked, and what it's waiting on

- Stage 2 (`replay_determinism_test`) — not started. No blocker, paused to answer this session's other
  items first.
- `sim/body` / `sim/transport` — waiting on Stage 3+ (explicitly out of this session's scope).
- Freight Winch / haul work — waiting on `sim/commands`/`sim/run` real implementations.
- Clone-size Phase 1, `docs/handoff/`, `history/` — waiting on your decisions (see EXPENSIVE above).

## LOC ratio

Instrument 1,314 (tools 943, tests 371) / game 257 (core 257) = 5.11 absolute — informational only.
Trailing-10-commit window: instrument grew, game grew by less than half as much — would fail the 2x
velocity check on its own, but ADVISORY-only while game LOC is under 2,000, so not gating. Expected to
look exactly like this for a while: `core/` is small by design and `sim/` (most of "game") is stage 3+.

## Taste queue

0 fixtures. Unchanged — `harness/` and `scenarios/` are still skeletons.
