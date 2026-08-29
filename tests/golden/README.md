Fixed-output regression tests: a known input against a recorded expected output, committed alongside
the test. Example: `traverse_time` on the standard hostile-geometry route must stay within 5% of its
golden recording (`docs/ARCHITECTURE.md` §9) — a movement change that drifts past that fails CI.

**Unused as of 2026-08-29 (queue #3 Part M2): no test file lives in this directory.** The real suite is flat under `tests/`; see `tests/README.md`.
