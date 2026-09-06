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


## Ore-like: a block whose yield is a deposit (`kind: ore` or `kind: fuel` in `data/materials`). Legacy's
## `_is_ore_like` (`factory_sim.gd:1466`) was a four-name literal list; the record's kind is the same
## question with no list to keep in step.
static func is_ore_like(material_id: StringName) -> bool:
	var record: Dictionary = MaterialsRecords.RECORDS.get(material_id, {})
	var kind: String = String(record.get("kind", ""))
	return kind == "ore" or kind == "fuel"


## THE MATERIAL-TO-ITEM CONTRACT (D0409): the item a cell of `material_id` puts in the pack when mined or
## bored -- the record's `yields`, else the material itself. Legacy never needed this because its vein WAS
## `ore`; the port named the vein `ore_iron` and lifted legacy's recipes verbatim, so what the player mined
## satisfied no recipe and no objective (the new-player review's first finding). Every yield site reads
## this one function: `Items._yield_ore`, `World.bore_one`.
static func yield_of(material_id: StringName) -> StringName:
	var record: Dictionary = MaterialsRecords.RECORDS.get(material_id, {})
	var named: String = String(record.get("yields", ""))
	return StringName(named) if named != "" else material_id
