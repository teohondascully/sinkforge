Lints, validators, and report generators — the tooling that enforces `docs/QUALITY.md`'s gates and
turns run artifacts into readable output. Not game code, not the harness that runs scenarios
(`harness/`) — this is static analysis over the repository and post-hoc reporting over what the
harness already produced.

- `layer_lint/` — the structural gates: layer dependency direction, no-engine-imports, file/function
  size limits, the instrument-to-game LOC ratio, claim-reference checking. See `docs/QUALITY.md`
  gates 1-7, 15-16.
- `schema_validator/` — validates `data/` against per-kind schemas. `docs/QUALITY.md` gate 13.
- `data_codegen/` — generates `data/<kind>/generated.gd` from `data/<kind>/*.yaml`; `--check` mode is
  the staleness gate. `docs/QUALITY.md` gate 22, `docs/adr/0004-data-codegen.md`.
- `quality_check/` — four code-quality instruments correctness gates never covered: function-length
  distribution, cross-language duplication (the headline one — the actual legacy failure), cyclomatic
  complexity, and module fan-in/fan-out. All four run in CI (`.github/workflows/harness.yml`); only
  `duplication.py` blocks (D0099 — 0 clusters is this project's verified-clean state, a regression is a
  fact a build should refuse), the other three are `continue-on-error: true` by the director's own
  explicit instruction — real dashboards, not gates. Corrected here 2026-08-29 (queue #3 Part M2) — this
  file previously said "gates nothing yet. Not wired into CI," which stopped being true once duplication
  became a blocking step.
- `report/` — turns run artifacts (`telemetry.jsonl`, `result.json`) into human-readable output.
  Empty until `harness/driver` produces something to report on.
- `formatter/` — `.editorconfig` made executable. Six rules (charset, trailing-whitespace, file-edges,
  blank-run, indent, comment-space), two rulesets (string-aware for `.gd`/`.py`, byte-level for
  `.sh`/`.yml`/`.yaml`). Mutation-tested (76/76), self-including, idempotent. Wired into CI as
  QUALITY gate 32 (D0318/D0319).
- `coverage_check.py` — function-name coverage for `core/` and `sim/`. A function is "covered" if its
  name appears as an identifier in at least one `tests/test_*.gd` suite (comments and string literals
  blanked first). Ratchet at 61.8% (89/144 names), reported-only — not BLOCKING, because it measures
  reference not execution and can be gamed to 100% with dead lines. Mutation-tested (10/10). Wired
  into CI as QUALITY gate 33 (D0322/D0323).
- `test_naming_check.py` — enforces the `test_*.gd` / `_test_*()` naming convention. Mutation-tested
  (6/6). Wired into CI as QUALITY gate 34 (D0324).
- `test_isolation_check.py` — verifies every `godot` suite invocation in CI goes through
  `run_gd_test.sh` or `run_suites.sh`, not a bare `godot --script`. Mutation-tested (4/4). Wired into
  CI as QUALITY gate 35 (D0324).
- `flaky_test_detector.py` — wraps `run_suites.sh`, runs it N times, and flags suites with
  inconsistent verdicts. Local tool, not run in CI (too slow for per-commit). D0324.
- `scratch/` — gitignored. Scratch work lives here and only here. If a script here turns out to be
  worth keeping, it becomes a real tool with a claim ID and moves out.

`tools/check_trailers.sh` (commit-authorship enforcement) also lives at this top level rather than
under a subdirectory — it's general git hygiene with no sim/game coupling, ported forward unchanged
from the pre-pivot `tools/` rather than archived with the rest of it.

Counts toward the instrument side of the LOC ratio (`docs/QUALITY.md` gate 7), except `scratch/`.
