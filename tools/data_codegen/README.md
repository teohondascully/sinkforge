`generate.py` reads every `data/<kind>/*.yaml` file in a directory whose `SCHEMA.yaml` declares a
required `id: str` field, and emits `data/<kind>/generated.gd`: one `<Kind>Records` class holding a
`const RECORDS: Dictionary` keyed by each record's `id`, valued by the record's full YAML content
translated 1:1 into GDScript literal types. `--check` mode writes nothing and fails if any generated
file would differ from what is on disk — that is the CI gate (`docs/QUALITY.md` gate 22).

Deliberately mechanical: no field renaming, no `StringName` conversion, no computed defaults. Anything a
consumer needs beyond the raw record is a thin, hand-written adapter reading from `RECORDS` — see
`sim/world/materials.gd` and `sim/terrain_gen/strata_data.gd`. `docs/adr/0004-data-codegen.md` has the
full contract and the alternatives it was chosen over.

Requires `pyyaml` (`pip install pyyaml`; CI installs it as a workflow step), same as
`tools/schema_validator/`.
