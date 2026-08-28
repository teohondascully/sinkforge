# Brief

Regenerated as the last action before reporting to the director, overwritten — not at an arbitrary
session boundary, since a brief written mid-session goes stale the moment another decision lands.
`CONTEXT.md`, "Review bandwidth." If this takes more than 90 seconds to read, it's too long.

**Last updated: 2026-08-28. This round: `tools/quality_check/` — four code-quality instruments the repo
had no coverage for, run as a dashboard against the real tree, with real findings.** Unrelated to
`data/economy/`, which still waits for the director. Function length, duplication (the headline finding
type, per instruction — "duplication is what actually happened"), complexity, and module coupling, all
reporting distributions and self-calibrating IQR outliers, no gate, no thresholds set yet. 17/17 mutation
cases OBSERVED. Real findings below, duplication first. No `.gd` code touched.

---

## The headline finding — duplication (4 clusters)

- **`core/entity_id_pool.gd:20:_ushr`** and **`core/split_rng.gd:38:_ushr`** — identical after
  identifier normalization, two separate files. Real, genuine cross-file duplication of a utility
  function — the exact shape of the legacy failure, at small scale.
- Two clusters already inside `tools/layer_lint/` itself: `find_gd_files` duplicated between
  `check_coordinate_naming.py`/`no_engine_imports.py`, and a second, syntactically distinct copy between
  `check_size_limits.py`/`layer_lint.py`. Pre-existing debt this instrument's own build surfaced in the
  gates it reused code from.
- One cluster inside `tools/quality_check/` itself: the four `main()` functions in `complexity.py` /
  `coupling.py` / `duplication.py` / `function_length.py` are identical after normalization. Real, but
  about as low-stakes as duplication gets — a useful calibration point for where the size floor should
  sit before any threshold is set.

## Function length, complexity, coupling — full detail in `docs/DECISIONS_LEDGER.md` D0096

- **Length**: 8 GDScript outliers (IQR fence >19.5 lines), 13 Python outliers (fence >42.5 lines).
  Longest: `sim/body/vertical_resolve.gd:111:resolve_floor` (50), `tools/economy_check/check_tier_rule.
  py:182:check_output_consequence` (67). Note: the existing `check_size_limits.py` 50-line hard cap sits
  ABOVE this run's own GDScript fence (19.5) — worth a look when a real threshold gets set.
- **Complexity**: 7 GDScript outliers (fence >6.0), 9 Python outliers (fence >13.5). Highest:
  `sim/body/body.gd:242:_resolve_horizontal` (24), `tools/anvil/schema.py:173:validate_event` (33).
- **Coupling**: `sim/` has real, plausible structure once GDScript's `class_name` global visibility is
  counted (this instrument found `sim/` had ZERO `res://`-based cross-references but 13 `class_name`
  declarations, and closed that blind spot rather than shipping blind to it) — `world` fan-in 3,
  `body`/`invariants` fan-out 3, `terrain_gen` fan-in 2 + fan-out 1, 10 of 14 modules at zero. `tools/`
  near-zero everywhere. Caveat: with most values at zero, the IQR fence itself sits near 0, so "outlier"
  here largely means "the only modules with any cross-reference yet," not "dramatically hub-like."

**Yield, this run — the first recorded data point for each instrument:** duplication 4 clusters, length
21 outliers, complexity 16 outliers, coupling 2 outliers.

---

## EXPENSIVE, awaiting you

- **`data/economy/`, D1 through D6** — unchanged, still the next substantial thing, authored with you
  present, checked against `tools/economy_check/` as it lands.
- **Thresholds for the four quality instruments** — not proposed by this report beyond what the IQR
  fences already show; your call once you've seen the numbers above (and the full lists in
  `docs/DECISIONS_LEDGER.md` D0096 / by running `python3 tools/quality_check/dashboard.py` yourself).
- **Whether `tools/quality_check/` gets wired into CI** — not decided, dashboard only right now.
- **`sim/run`/`sim/meta`'s actual shape** — still open, unchanged.
- **Whether lateral variety survives losing re-rolled geology** — unchanged, `docs/GDD.md` §8.
- Eleven tracked `docs/*.md` files outside `docs/README.md`'s normative table — unchanged.
- `incoming/ANVIL_ARCHITECTURE.md`'s disposition — unchanged.
- **The two-hop decorative gap** (`tools/economy_check`) — still logged, not fixed, unchanged.
- **`tools/quality_check/`'s own LOC overage** — 1,011 total against the director's "a few hundred
  lines" bar, stated plainly in both the ledger and the tool's own README. Not silently absorbed.

## What was learned

- **Building an instrument for a documented blind spot is a chance to close it, not just inherit and
  disclose it again.** `layer_lint.py` already states it can't see GDScript `class_name` coupling. The
  new coupling instrument could have repeated that disclaimer and shipped a near-vacuous "sim/ has no
  coupling" result — instead it measured what's actually driving `sim/`'s real architecture (13
  `class_name` declarations, zero `res://` references) and closed the gap. A disclosed limitation is not
  automatically an acceptable one just because it's disclosed.
- **A duplication detector run against a codebase for the first time will find itself.** The four
  `main()` functions across this round's own instrument files clustered as duplicates. Not a bug — the
  tool working exactly as built, on the corpus it happens to be sitting inside, which is a useful
  reminder that "run the new instrument against the tree" always includes the instrument's own directory
  unless deliberately excluded, and excluding it would have been the wrong call here (self-blindness is
  its own kind of vacuous result).
- **Testability gaps get caught earlier when you've already been burned by one.** `coupling.analyze`
  hardcoded the real filesystem on first draft; refactored to an injectable `root` before any test was
  written, specifically because `tools/anvil/check_integrity.py`'s own `check_integrity(log_dir)`
  parameter is a known, load-bearing precedent in this exact codebase for exactly this problem.
- **Reporting a real LOC overage against your own explicit sizing instruction is itself information the
  director asked for, not a failure to hide.** The instinct to quietly trim documentation or cut a real
  correctness fix (the `class_name` closure) just to land under "a few hundred lines" would have traded
  honesty for a number — reporting 1,011 plainly, with the reasons, respects the instruction more than
  gaming it would have.

## What landed this round

Full detail: `docs/DECISIONS_LEDGER.md` D0096.

`tools/quality_check/` — `scan.py` (237, shared infra), `function_length.py` (61), `duplication.py`
(89), `complexity.py` (107), `coupling.py` (208), `dashboard.py` (92), `README.md`,
`test_quality_check.py` (217, 17 mutation cases, all OBSERVED). `tools/README.md` gained one entry.
Committed and pushed alongside this report.

## Gates

All 9 structural gates + `schema_validator.py` + `data_codegen/generate.py --check` + `tools/anvil/
check_integrity.py` re-run and PASS.

**LOC ratio: instrument total 7,636 / game total 1,424, absolute ratio 5.362.** Trailing-10-commit
window: instrument +2,077, game +0. Still ADVISORY, game LOC under the 2,000-line floor.

**`tools/quality_check/` split: 794 implementation / 217 test / 1,011 total** — over the director's "a
few hundred lines" instruction, reported honestly (see "EXPENSIVE" and D0096 for the reasoning).

**Anvil: unchanged this round** — implementation 513 / 1,000 cap. No Anvil work; not touched.

**Commits this round: 1. Unpushed: 0**, pushed with this report.

## Claims

`C001-two-minute-run.md`: `RETIRED`, unchanged. `C003-cold-start-reaches-d1.md`: `BLOCKED`, unchanged.
`C002-traversal-over-rubble.md`: unchanged, `BLOCKED`.

## Blocked, and what it's waiting on

- **`data/economy/`, D1-D6** — waits for you, explicitly, with you present.
- **Quality-instrument thresholds** — waits for your read of this round's real numbers.
- **`sim/run`/`sim/meta`'s shape** — waits for a real decision, unchanged.
- Gate 10, item 2 (human-biased fuzzer), rope, chunk size (D0019), coordinate type scheme (D0020) —
  unchanged.
- Cohesion note for Anvil step 4 (unchanged, unrelated to this round).

## Taste queue

0 fixtures. Unchanged.
