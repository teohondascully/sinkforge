The structural gates run in CI on every push and PR (`.github/workflows/harness.yml`, job `gates`).
Each script is self-contained Python 3, takes no arguments, and exits 0 (pass) or 1 (fail). Each was
mutation-tested against a deliberately broken fixture before being trusted — `docs/QUALITY.md` §2: "a
check that has never been observed failing is not a check."

- `layer_lint.py` — dependency direction between layers (`docs/ARCHITECTURE.md` §3) and sibling
  reach-in within `sim/`'s submodules. States its own blind spot: GDScript's `class_name` global
  visibility is invisible to a `res://`-path-based scan.
- `no_engine_imports.py` — `core/` and `sim/` may not reference the scene tree, file IO, wall-clock
  time, or unseeded randomness.
- `check_size_limits.py` — no file over 400 lines (warn at 300), no function over 50.
- `check_loc_ratio.py` — instrument LOC (`harness/` + `experiment/` + `tools/` + `tests/`) must not
  exceed game LOC (`core/` + `sim/` + `interface/` + `view/` + `shell/`). Reads WARN, not FAIL, while
  `core/` hasn't landed yet (Task 1) — a zero-game state is a different condition from "instrument
  exceeds game," not a degenerate case of it. That WARN should stop appearing once `core/` exists;
  if it's still printing after that, treat it as the FAIL it actually is.
- `check_claim_references.py` — every scenario in `scenarios/` and every harness layer with a
  registered `func run()` names a claim ID that exists in `claims/` AND has been observed FAILING at
  least once (`first_failed_at` populated — `docs/CLAIMS.md` §10a), or is explicitly marked
  `EXEMPT (ADR-0001)`. Also enforces the 40-active-claim cap (`docs/CLAIMS.md` §10c).
