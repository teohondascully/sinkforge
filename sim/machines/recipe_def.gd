class_name RecipeDef
extends RefCounted

## One recipe, the flyweight every machine running it shares. Lifted in A' step 3 (D0346) from
## `legacy/src/data/recipe_def.gd` (a `Resource` with `@export`s) as the thin adapter `docs/adr/0004` asks
## for over `data/recipes/generated.gd`: the record is the truth, this is its typed, `StringName`-keyed
## reading, built once per id and cached. Legacy's `time: float` seconds is `time_ticks: int` here (plan
## §5.1 row 001); every legacy time was exact at 20 Hz, so no recipe changed length.

var id: StringName = &""
var inputs: Dictionary = {}    # item id: StringName -> count consumed per craft; empty = a source
var outputs: Dictionary = {}   # item id: StringName -> count produced per craft
var time_ticks: int = 1

static var _cache: Dictionary = {}  # id -> RecipeDef; memoises a pure reading of a const table


static func of(recipe_id: StringName) -> RecipeDef:
	return memoised(_cache, RecipesRecords.RECORDS, recipe_id, func(record: Dictionary) -> RecipeDef:
		var def: RecipeDef = RecipeDef.new()
		def._read(record)
		return def)


## The one memoised reading of a const record table, shared by every def adapter (`MachineDef` calls it
## too): null for an unknown id, the same object for every later call. Lives on the leaf so the adapters
## do not each carry a copy `tools/quality_check/duplication.py` would refuse. The factory Callable is
## built per call and never stored, so it holds no reference cycle (legacy's `_BEHAVIORS` note).
static func memoised(cache: Dictionary, records: Dictionary, id: StringName, factory: Callable) -> Variant:
	var hit: Variant = cache.get(id)
	if hit != null:
		return hit
	if not records.has(id):
		return null
	var def: Variant = factory.call(records[id])
	cache[id] = def
	return def


static func exists(recipe_id: StringName) -> bool:
	return RecipesRecords.RECORDS.has(recipe_id)


func _read(record: Dictionary) -> void:
	id = StringName(String(record["id"]))
	inputs = _item_counts(record.get("inputs", {}))
	outputs = _item_counts(record.get("outputs", {}))
	time_ticks = int(record["time_ticks"])


## Codegen keeps YAML keys as `String`; the hub compares item ids as `StringName`, so the keys are
## converted once here rather than at every lookup.
static func _item_counts(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in raw:
		out[StringName(String(k))] = int(raw[k])
	return out
