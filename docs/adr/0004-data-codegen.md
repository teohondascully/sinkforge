# ADR 0004: Data-driven records are codegen'd from YAML, not hand-mirrored

**Status:** accepted, 2026-08-26.

## Context

D0021 (`docs/DECISIONS_LEDGER.md`) found `data/` has no runtime loader — Godot ships no YAML parser —
so `sim/world/materials.gd` and `sim/terrain_gen/strata_data.gd` are GDScript dictionaries hand-mirroring
`data/materials/*.yaml` and `data/strata/shallow_clay.yaml` respectively, kept in sync by hand. That is
two sources of truth for the numbers that define the game. `docs/ARCHITECTURE.md` §8's whole
content-as-data premise assumes `data/` is authoritative; hand-syncing means it silently isn't. D0021
named three options and deferred the choice, because it touches every future data-driven module
(`sim/machines`, `sim/economy`, `sim/meta`, ...), not just the two kinds that exist today. This ADR
makes that choice.

## Decision

Build-time codegen. `tools/data_codegen/generate.py` reads every `data/<kind>/*.yaml` file (excluding
`SCHEMA.yaml` itself) in a directory that has a schema, and emits one generated file,
`data/<kind>/generated.gd`, checked into the repo:

- Class name `<KindPascalCase>Records` (e.g. `MaterialsRecords`, `StrataRecords`), `extends RefCounted`.
- One `const RECORDS: Dictionary`, keyed by each record's `id` field. New constraint this adds: a kind's
  `SCHEMA.yaml` must declare `id` as a required `str` field to be codegen-eligible — both existing
  schemas (`data/materials/SCHEMA.yaml`, `data/strata/SCHEMA.yaml`) already do, so neither needs a
  change. Each value is the record's full YAML content translated 1:1 into GDScript literal types
  (str → String, int → int, float → float, bool → bool, list/dict → recursively, matching structure).
- No StringName conversion, no field renaming, no derived or computed fields, no defaults for optional
  fields missing from a record. Codegen stays a literal, mechanical translation of what the YAML says.
  Anything a consumer needs beyond the raw record — a `StringName` key, a `.hardness()`-style accessor,
  a default for a missing optional field — stays a thin, hand-written adapter reading from `RECORDS`,
  the same shape `sim/world/materials.gd` and `sim/terrain_gen/strata_data.gd` already have and keep.
- A header comment marking the file generated and naming the regeneration command, so a reader who opens
  it without this ADR in hand still knows not to hand-edit it.
- `generate.py --check` regenerates every expected file in memory and diffs it against what is actually
  on disk; any difference, including a missing file, fails and names the specific stale or missing file.
  This is the new gate: `tools/data_codegen/generate.py --check`, registered in
  `.github/workflows/harness.yml` and `docs/QUALITY.md` as gate 22 — appended at the end of that
  document's numbered list rather than inserted near gate 13 ("Schema"), because several existing gate
  scripts cite their own gate number in their own docstrings (`schema_validator.py` cites "gate 13"), and
  renumbering would make every one of those citations wrong. Gate numbers are addresses, the same reason
  `docs/DECISIONS_LEDGER.md` entries are.

`sim/world/materials.gd` and `sim/terrain_gen/strata_data.gd` are refactored to read from
`MaterialsRecords.RECORDS` / `StrataRecords.RECORDS` instead of hand-copied literals. GDScript
const-folds a dictionary subscript of another class's `const` at parse time (`const FOO: Dictionary =
OtherClass.RECORDS["key"]` resolves at compile time, not runtime) — verified directly against the pinned
engine (4.6.2-stable) with a throwaway two-file scratch test before this was relied on, not assumed.
Their existing public APIs (`hardness()`, `exists()`, `get_site()`, the `SHALLOW_CLAY` constant) are
unchanged, so nothing outside these two files needs to change.

Rejected alternatives:

- **A hand-written YAML-subset parser**, run at sim startup, reading `data/*.yaml` directly. Already
  rejected once in D0021 as scope creep (infrastructure for all of `data/`, not `sim/world`'s job to
  own), and rejected again here: it adds a runtime cost and a new failure mode a build-time approach
  doesn't have — a malformed YAML file would become a runtime error mid-run instead of a build-time gate
  failure, for no benefit codegen doesn't already give.
- **Switch `data/`'s on-disk format to JSON**, read by Godot's native `JSON` singleton at runtime.
  Rejected because it gives up YAML's comments entirely, and every `data/*.yaml` file in this repo uses
  comments load-bearingly — provenance notes, cross-references to `legacy/`'s original constant names,
  the `pending_sim_economy` structural marker D0025 added specifically so "unconsumed" would be visible
  in the file itself. It also doesn't actually solve the sync problem, only moves it: a human-reviewable
  YAML authoring format would still need to exist alongside `data/*.json`, which is YAML with extra
  steps.

## Consequences

- Runtime cost is exactly zero: `RECORDS` is a plain `const Dictionary`, identical in shape and cost to
  what `materials.gd`/`strata_data.gd` already hand-wrote. Drift becomes a build failure
  (`generate.py --check`) instead of a review question, which was the entire point.
- `data/` gains its first GDScript files. `data` is already `UNPOLICED` by `tools/layer_lint/layer_lint.py`
  (grouped with `docs`, `tools`, `tests`) and is counted in neither bucket of
  `check_loc_ratio.py`'s `INSTRUMENT_DIRS`/`GAME_DIRS` — deliberately left uncounted on both sides, since
  a generated record table is neither hand-written game logic nor test/harness/tooling, and counting it
  as `game/` would let a wide schema inflate the LOC-ratio numerator without a person deciding anything.
  This is a real trade, stated plainly rather than smoothed over: if `data/`'s generated files are ever
  used to shadow real logic specifically to dodge the ratio, that would be a defect in how `data/` gets
  used, not in this decision. `check_size_limits.py`'s 400-line file / 50-line function caps DO still
  apply to generated files — its only exclusion is `legacy/` — so a kind with enough records to breach
  that cap is a real finding the gate will surface, not one generation hides.
- `generate.py` requires PyYAML, already a dependency of `tools/schema_validator/schema_validator.py`.
- Every future `data/<kind>/` that wants codegen needs a required `id: str` field in its `SCHEMA.yaml`.
  A kind without one is simply not codegen-eligible yet, reported by `generate.py`, not silently skipped.
- Resolves D0021: `data/` becomes actually authoritative, not just nominally so. Logged as its own
  ledger entry pointing back to D0021, not an edit to it — the ledger is append-only.
