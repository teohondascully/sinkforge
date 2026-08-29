Tests for the new codebase (`core/`, `sim/`, `interface/`, ...). Not to be confused with
`legacy/tests/`, the pre-pivot suite, which is frozen and excluded from every gate.

**Actual current structure, corrected 2026-08-29 (queue #3 Part M2): flat, not subdivided.** Every real
`test_*.gd` file lives directly under `tests/` or `tests/body/`; the `unit/`, `property/`, `scenario/`,
and `golden/` subdirectories below are an intended future organization that was never adopted — each
holds only its own `README.md`, no test files. Real examples of what those categories describe: the
determinism property (`tests/test_shaft_replay_determinism.gd`, `docs/QUALITY.md` gate 8) and the
`traverse_time` golden regression (`tests/test_body_acceptance.gd`, `docs/ARCHITECTURE.md` §9). There is
no committed conservation-of-matter test — gate 9 is one of the gates `tools/gate_status.py` reports as
NO-CODE; a prior version of this file described one as if it existed. For which gate has which test
right now, read `docs/QUALITY.md`'s own gate list or run `tools/gate_status.py`, rather than trusting a
hand-maintained mapping here — that mapping is exactly what went stale.

Counts toward the instrument side of the LOC ratio (`docs/QUALITY.md` gate 7).

Coverage target: ≥85% line coverage on `core/` and `sim/` (`docs/QUALITY.md` gate 14). `view/` and
`shell/` are exempt — chasing coverage in rendering code is theater.
