class_name MachineDef
extends RefCounted

## One machine type's definition, the flyweight every placed machine of that type shares. Lifted in A'
## step 3 (D0346) from `legacy/src/data/machine_def.gd` as the thin adapter `docs/adr/0004` asks for over
## `data/machines/generated.gd`. What legacy kept as `const` on `FactorySim` (`LIFT_POWER_DEMAND`,
## `PUMP_RATE`, `GENERATOR_FUEL_TICKS`, ...) is a field of the record now and a typed property here, so a
## runner reads `m.def.fuel_ticks` where legacy read `DRILL_FUEL_TICKS`: the number moved to `data/`, the
## logic did not (plan §5.1 row 009). Power is milli-units, fractions are percentages; every one is an int.
##
## `craft_cost` and `craft_count` are gone and the schema REFUSES them (`data/machines/SCHEMA.yaml`).
## The behaviour registry (tag -> runner) stays code in `sim/machines`; a tag this def carries that the
## registry does not know is a plain recipe-runner with a look of its own, exactly as in legacy.

## The per-type parameters, in the order `data/machines/SCHEMA.yaml` declares them. A record carries
## only the ones its runner reads; the rest read 0 here, which no runner treats as a valid value.
const PARAMS: Array[StringName] = [&"throughput", &"powered_throughput", &"power_demand_milli", &"reach",
	&"rate", &"power_milli", &"fuel_ticks", &"aura", &"release", &"feed_cap", &"capacity_milli",
	&"v_keep_pct", &"h_keep_pct", &"bleed_pct", &"trip_capacity", &"transit_ticks", &"station_cap"]

var id: StringName = &""
var display_name: String = ""
var behavior: StringName = &""   # legacy's routing/look tag; empty = the default recipe-runner
var recipe: RecipeDef = null     # null = runs no recipe

var throughput: int = 0
var powered_throughput: int = 0
var power_demand_milli: int = 0
var reach: int = 0
var rate: int = 0
var power_milli: int = 0
var fuel_ticks: int = 0
var aura: int = 0
var release: int = 0
var feed_cap: int = 0
var capacity_milli: int = 0
var v_keep_pct: int = 0
var h_keep_pct: int = 0
var bleed_pct: int = 0
var trip_capacity: int = 0
var transit_ticks: int = 0
var station_cap: int = 0

static var _cache: Dictionary = {}  # id -> MachineDef; memoises a pure reading of a const table


static func of(machine_id: StringName) -> MachineDef:
	return RecipeDef.memoised(_cache, MachinesRecords.RECORDS, machine_id, func(record: Dictionary) -> MachineDef:
		var def: MachineDef = MachineDef.new()
		def._read(record)
		return def)


## Is this id a placeable machine at all? Legacy answered this with `ResourceLoader.exists(...tres)`
## inside the sim (plan §5.1 row 023, an engine-IO call on the state path); the records table is the
## same question with no IO.
static func exists(machine_id: StringName) -> bool:
	return MachinesRecords.RECORDS.has(machine_id)


## Every machine id, lexically sorted (`Ordering`, never a bare `.sort()` -- D0346) -- the iteration order
## for anything state-affecting that walks the types.
static func ids() -> Array[StringName]:
	return Ordering.ids(MachinesRecords.RECORDS)


func _read(record: Dictionary) -> void:
	id = StringName(String(record["id"]))
	display_name = String(record["display_name"])
	behavior = StringName(String(record.get("behavior", "")))
	var recipe_id: String = String(record.get("recipe", ""))
	recipe = RecipeDef.of(StringName(recipe_id)) if not recipe_id.is_empty() else null
	for p: StringName in PARAMS:
		set(p, int(record.get(String(p), 0)))
