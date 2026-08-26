The structural gates run in CI on every push and PR (`.github/workflows/harness.yml`, job `gates`).
Each script is self-contained Python 3, takes no arguments, and exits 0 (pass) or 1 (fail). Each was
mutation-tested against a deliberately broken fixture before being trusted — `docs/QUALITY.md` §2: "a
check that has never been observed failing is not a check."

- `layer_lint.py` — dependency direction between layers (`docs/ARCHITECTURE.md` §3) and sibling
  reach-in within `sim/`'s submodules. States its own blind spot: GDScript's `class_name` global
  visibility is invisible to a `res://`-path-based scan.
- `no_engine_imports.py` — `core/` and `sim/` may not reference the scene tree, file IO, wall-clock
  time, or unseeded randomness. Rewritten 2026-08-26 from a one-time audit of Godot's actual `ClassDB`
  (282 Node-derived classes, 37 singletons) rather than a pattern list accumulated by tripping over
  gaps one at a time — `docs/DECISIONS_LEDGER.md` D0026.
- `check_coordinate_naming.py` — every public function in `sim/world/` or `sim/terrain_gen/` that takes
  or returns a `Vector2i` (or a typed array/dictionary of one) must name which grid it's on —
  `terrain_` or `logic_` in the identifier. Converts D0020's naming-discipline mitigation (nothing at
  the type level distinguishes the 4px terrain grid from the 16px logic grid) from something a reviewer
  has to remember to sample for into a checked property — `docs/DECISIONS_LEDGER.md` D0027, D0028.
- `check_size_limits.py` — no file over 400 lines (warn at 300), no function over 50.
- `check_loc_ratio.py` — instrument LOC growth (`harness/` + `experiment/` + `tools/` + `tests/`) may
  not exceed game LOC growth (`core/` + `sim/` + `interface/` + `view/` + `shell/`) by more than 2x
  over a trailing 10-commit window, with a floor so small numbers don't trip it. Rewritten 2026-08-26 —
  the original absolute-totals form correctly went red the moment `core/` landed with `sim/` still
  empty, but that was the wrong thing to gate on: any nonzero instrument exceeds zero game on day one.
  ADVISORY (never blocking) until current game LOC passes 2,000; always prints the absolute ratio as
  information regardless. Needs `.github/workflows/harness.yml`'s `gates` job to check out full history
  (`fetch-depth: 0`) — see the script's own header for why.
- `check_claim_references.py` — every scenario in `scenarios/` and every harness layer with a
  registered `func run()` names a claim ID that exists in `claims/` AND has been observed FAILING at
  least once (`first_failed_at` populated — `docs/CLAIMS.md` §10a), or is explicitly marked
  `EXEMPT (ADR-0001)`. Also enforces the 40-active-claim cap (`docs/CLAIMS.md` §10c).
