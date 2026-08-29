Invariant-style tests over randomized or generated input, rather than one fixed case. The two
load-bearing examples named in `docs/ARCHITECTURE.md`:

- `replay_determinism_test` — run a 20,000-tick recorded input log twice from one seed, hash full
  state every 100 ticks, assert identical. Must exist from day one (`docs/ARCHITECTURE.md` §4).
- Conservation of matter — over 10,000 random ticks with fuzzed commands, total material is conserved
  modulo declared sinks (`docs/QUALITY.md` gate 9).

**Unused as of 2026-08-29 (queue #3 Part M2): no test file lives in this directory.** The real suite is flat under `tests/`; see `tests/README.md`.
