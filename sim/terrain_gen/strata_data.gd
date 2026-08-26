class_name StrataData
extends RefCounted

## Site generation parameters. Reads `data/strata/generated.gd` (`StrataRecords.RECORDS`), codegen'd
## from `data/strata/*.yaml` by `tools/data_codegen/generate.py` -- `docs/adr/0004-data-codegen.md`,
## resolving `docs/DECISIONS_LEDGER.md` D0021. `data/` is the actual source of truth now; this file no
## longer hand-mirrors it.
##
## `SHALLOW_CLAY` keeps its old name and shape (nested dicts for `cave`, `strata_shelf`, `ore`, `coal`,
## `iron`, `ruin`) so `ShaftGenerator` and a future per-shaft modifier file (`docs/DECISIONS_LEDGER.md`
## D0016 -- "floods fast", "hard rock starts early") read it exactly as before; this file is now a thin
## re-export, not a second copy. One real leaf-level change from the old hand-written version: string
## fields nested inside a record (`id`, `material`) are plain GDScript `String` now, not `StringName`,
## because codegen does no type conversion by design (`docs/adr/0004-data-codegen.md`). Grepped `sim/`
## and `tests/` before this landed: nothing reads those specific leaf fields today --
## `_scatter_vein_material`'s material argument is a `StringName` literal at its own call site in
## `shaft_generator.gd`, not read from this config -- so this is a real change, verified inert, not a
## silently dropped one.

const SHALLOW_CLAY: Dictionary = StrataRecords.RECORDS["shallow_clay"]

const _SITES: Dictionary = {
	&"shallow_clay": SHALLOW_CLAY,
}


static func get_site(id: StringName) -> Dictionary:
	return _SITES.get(id, {})


static func exists(id: StringName) -> bool:
	return _SITES.has(id)
