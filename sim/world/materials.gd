class_name WorldMaterials
extends RefCounted

## Material registry: hardness by material id. `sim/world/MODULE.md`'s stated job ("material IDs,
## hardness") lives here, separate from `TileGrid`'s spatial storage -- one concept per file.
##
## Reads `data/materials/generated.gd` (`MaterialsRecords.RECORDS`), codegen'd from
## `data/materials/*.yaml` by `tools/data_codegen/generate.py` -- `docs/adr/0004-data-codegen.md`,
## resolving `docs/DECISIONS_LEDGER.md` D0021. `data/` is the actual source of truth now; this file no
## longer hand-mirrors it. GDScript's `Dictionary` lookups compare `String`/`StringName` keys by value,
## not by static type, so `RECORDS.get(material_id, ...)` works directly with a `StringName` argument
## even though `RECORDS` is keyed by plain `String` -- verified empirically before relying on it.

static func hardness(material_id: StringName) -> float:
	var record: Dictionary = MaterialsRecords.RECORDS.get(material_id, {})
	return float(record.get("hardness", 0.0))


static func exists(material_id: StringName) -> bool:
	return MaterialsRecords.RECORDS.has(material_id)


## A sapling can root in this material: the record's optional `soil` flag (ADR 0009 §3). Absent or
## unknown reads false, so a new material is not soil until someone says so.
static func is_soil(material_id: StringName) -> bool:
	var record: Dictionary = MaterialsRecords.RECORDS.get(material_id, {})
	return bool(record.get("soil", false))
