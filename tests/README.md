Tests for the new codebase (`core/`, `sim/`, `interface/`, ...). Not to be confused with
`legacy/tests/`, the pre-pivot suite, which is frozen and excluded from every gate.

- `unit/` — narrow, fast, one behavior at a time. Mirrors `core/` and `sim/`'s module structure.
- `property/` — invariant-style tests over randomized input, e.g. `replay_determinism_test`
  (`docs/ARCHITECTURE.md` §4: 20,000 recorded ticks, hashed every 100, from one seed, identical) and
  the conservation-of-matter property test (`docs/QUALITY.md` gate 9).
- `scenario/` — tests that exercise a full scenario file from `scenarios/` through the harness driver,
  as opposed to `harness/scenario/`, which holds the format/loader/schema code itself.
- `golden/` — fixed-output regression tests: a known input against a recorded expected output
  (e.g. `traverse_time` on the standard movement-acceptance route, `docs/ARCHITECTURE.md` §9).

Counts toward the instrument side of the LOC ratio (`docs/QUALITY.md` gate 7).

Coverage target: ≥85% line coverage on `core/` and `sim/` (`docs/QUALITY.md` gate 14). `view/` and
`shell/` are exempt — chasing coverage in rendering code is theater.
