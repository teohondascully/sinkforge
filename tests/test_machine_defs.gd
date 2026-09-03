extends "res://tests/test_base.gd"

## The data leaves of A' step 3 (D0346): `data/machines` and `data/recipes` as records, `MachineDef` /
## `RecipeDef` as their typed readings, `MachineState` as the per-placement state. Every number here is
## legacy's, cited to the `.tres` or the `factory_sim.gd` constant it came from, so a record that drifts
## from legacy fails by name. The POPULATION is pinned too: exactly the 15 LIFT machines and the 6
## recipes, so converting one of the four ruling machines (splitter, spur, ore_vent, crusher) or the
## three dead ones cannot happen silently.

const LIFTED_MACHINES: Array[StringName] = [&"blast_furnace", &"conduit", &"drill", &"gear_mill",
	&"generator", &"hopper", &"iron_forge", &"lift", &"plate_press", &"processor", &"pump", &"rope",
	&"torch", &"winch_head", &"winch_station"]
const NOT_CONVERTED: Array[StringName] = [&"splitter", &"spur", &"ore_vent", &"crusher",
	&"descent_engine", &"h_drill", &"drift_rig"]


func _initialize() -> void:
	_test_the_machine_population_is_exactly_the_lift_list()
	_test_every_recipe_time_is_legacy_seconds_times_twenty()
	_test_recipe_links_resolve_and_inputs_outputs_are_legacy_verbatim()
	_test_per_type_parameters_are_legacy_constants()
	_test_no_record_carries_a_craft_field()
	_test_def_readings_are_cached_flyweights()
	_test_machine_state_defaults_and_the_two_integer_rows()
	_finish("machine_defs")


func _test_the_machine_population_is_exactly_the_lift_list() -> void:
	var ids: Array[StringName] = MachineDef.ids()
	_check(ids == LIFTED_MACHINES, "MachineDef.ids() is exactly the 15 LIFT machines, sorted (got %s)" % str(ids))
	var resolved: int = 0
	for id: StringName in LIFTED_MACHINES:
		if MachineDef.of(id) != null and MachineDef.of(id).id == id and MachineDef.exists(id):
			resolved += 1
	_check_over(LIFTED_MACHINES.size(), resolved == LIFTED_MACHINES.size(), "every LIFT machine resolves to a def carrying its own id (%d of %d)" % [resolved, LIFTED_MACHINES.size()])
	var absent: int = 0
	for id: StringName in NOT_CONVERTED:
		if MachineDef.of(id) == null and not MachineDef.exists(id):
			absent += 1
	_check_over(NOT_CONVERTED.size(), absent == NOT_CONVERTED.size(), "the 4 ruling and 3 dead machines are NOT records (%d of %d absent)" % [absent, NOT_CONVERTED.size()])
	_check(MachineDef.of(&"no_such_machine") == null, "an unknown id reads as null, not a crash")


## legacy/src/data/recipes/*.tres: mine_ore 1.0 s, smelt_ingot 2.0, smelt_rich 2.2, smelt_iron 2.5,
## mill_gear 2.5, press_plate 3.0 -- x20 at the hub's 20 Hz.
func _test_every_recipe_time_is_legacy_seconds_times_twenty() -> void:
	var pins: Dictionary = {&"mine_ore": 20, &"smelt_ingot": 40, &"smelt_rich": 44, &"smelt_iron": 50,
		&"mill_gear": 50, &"press_plate": 60}
	var ok: int = 0
	for rid: StringName in pins:
		var r: RecipeDef = RecipeDef.of(rid)
		if r != null and r.time_ticks == int(pins[rid]) and r.id == rid:
			ok += 1
		else:
			_check(false, "recipe %s: expected %d ticks, got %s" % [rid, pins[rid], "null" if r == null else str(r.time_ticks)])
	_check_over(pins.size(), ok == pins.size(), "all %d recipe times are legacy's seconds x20, exact (%d ok)" % [pins.size(), ok])
	_check(RecipesRecords.RECORDS.size() == 6, "exactly 6 recipe records exist (got %d)" % RecipesRecords.RECORDS.size())
	_check(RecipeDef.of(&"no_such_recipe") == null and not RecipeDef.exists(&"no_such_recipe"), "an unknown recipe reads as null")


func _test_recipe_links_resolve_and_inputs_outputs_are_legacy_verbatim() -> void:
	var links: Dictionary = {&"drill": &"mine_ore", &"iron_forge": &"smelt_iron", &"blast_furnace": &"smelt_rich",
		&"processor": &"smelt_ingot", &"plate_press": &"press_plate", &"gear_mill": &"mill_gear"}
	var ok: int = 0
	for mid: StringName in links:
		var d: MachineDef = MachineDef.of(mid)
		if d != null and d.recipe != null and d.recipe.id == links[mid]:
			ok += 1
	_check_over(links.size(), ok == links.size(), "the 6 recipe-running machines link to their legacy recipe (%d ok)" % ok)
	var no_recipe: int = 0
	for mid: StringName in [&"lift", &"pump", &"hopper", &"generator", &"conduit", &"torch", &"rope", &"winch_head", &"winch_station"]:
		if MachineDef.of(mid).recipe == null:
			no_recipe += 1
	_check_over(9, no_recipe == 9, "the 9 non-recipe machines carry no recipe (%d)" % no_recipe)
	var smelt_iron: RecipeDef = RecipeDef.of(&"smelt_iron")
	_check(smelt_iron.inputs == {&"iron": 2} and smelt_iron.outputs == {&"iron_ingot": 1}, "smelt_iron: 2 iron -> 1 iron_ingot, keys as StringName")
	var mill: RecipeDef = RecipeDef.of(&"mill_gear")
	_check(mill.inputs == {&"iron_ingot": 1, &"ingot": 1} and mill.outputs == {&"gear": 2}, "mill_gear: 1 iron_ingot + 1 ingot -> 2 gear")
	var mine: RecipeDef = RecipeDef.of(&"mine_ore")
	_check(mine.inputs.is_empty() and mine.outputs == {&"ore": 1}, "mine_ore has no inputs: a source")
	_check(mine.inputs.has(&"ore") == false and smelt_iron.inputs.has(&"iron") and smelt_iron.inputs.get(&"iron") == 2,
		"lookups by StringName hit the converted keys")


## factory_sim.gd:41-43, 49-51, 56-58, 110-112, 119-122, 133-136. Power 4.0 -> 4000 milli; 0.92 -> 92 pct.
func _test_per_type_parameters_are_legacy_constants() -> void:
	var lift: MachineDef = MachineDef.of(&"lift")
	_check(lift.throughput == 2 and lift.powered_throughput == 6 and lift.power_demand_milli == 4000, "lift: 2 unpowered, 6 powered, demand 4000 milli")
	var pump: MachineDef = MachineDef.of(&"pump")
	_check(pump.reach == 4 and pump.rate == 3 and pump.power_demand_milli == 4000, "pump: reach 4, rate 3, demand 4000 milli")
	var gen: MachineDef = MachineDef.of(&"generator")
	_check(gen.power_milli == 6000 and gen.fuel_ticks == 100 and gen.aura == 2, "generator: 6000 milli, 100 fuel ticks, aura 2")
	_check(MachineDef.of(&"drill").fuel_ticks == 60, "drill: 60 fuel ticks (3 s at 20 Hz)")
	var hop: MachineDef = MachineDef.of(&"hopper")
	_check(hop.release == 1 and hop.feed_cap == 3, "hopper: release 1, feed cap 3")
	var con: MachineDef = MachineDef.of(&"conduit")
	_check(con.capacity_milli == 12000 and con.v_keep_pct == 92 and con.h_keep_pct == 80 and con.bleed_pct == 60, "conduit: 12000 milli cap, keep 92/80 pct, bleed 60 pct")
	var head: MachineDef = MachineDef.of(&"winch_head")
	_check(head.trip_capacity == 8 and head.transit_ticks == 40 and head.power_demand_milli == 4000, "winch head: 8 per trip, 40 ticks in flight, demand 4000 milli")
	_check(MachineDef.of(&"winch_station").station_cap == 60, "winch station: cap 60")
	_check(MachineDef.of(&"torch").fuel_ticks == 0 and MachineDef.of(&"rope").behavior == &"rope", "a record without a parameter reads 0 for it; the tag is preserved")
	_check(MachineDef.of(&"processor").behavior == &"" and MachineDef.of(&"processor").display_name == "Forge", "the processor is the default recipe-runner (no tag), displayed as Forge, as in legacy")
	_check(MachineDef.of(&"iron_forge").behavior == &"iron_forge", "iron_forge keeps its look tag even though no runner is registered for it")


func _test_no_record_carries_a_craft_field() -> void:
	var clean: int = 0
	var records: int = 0
	for k: Variant in MachinesRecords.RECORDS:
		records += 1
		var rec: Dictionary = MachinesRecords.RECORDS[k]
		if not rec.has("craft_cost") and not rec.has("craft_count"):
			clean += 1
	_check_over(records, clean == records, "no machine record carries craft_cost or craft_count (%d of %d clean); the schema forbids both and tools/schema_validator/test_schema_validator.py proves the refusal fires" % [clean, records])
	var known: int = 0
	var fields: int = 0
	var schema_fields: Array = ["id", "display_name", "behavior", "recipe"]
	for p: StringName in MachineDef.PARAMS:
		schema_fields.append(String(p))
	for k: Variant in MachinesRecords.RECORDS:
		for f: Variant in MachinesRecords.RECORDS[k]:
			fields += 1
			if schema_fields.has(String(f)):
				known += 1
	_check_over(fields, known == fields, "every field on every record is one MachineDef reads (%d of %d) -- a number nothing reads is not data, it is fog" % [known, fields])


func _test_def_readings_are_cached_flyweights() -> void:
	_check(MachineDef.of(&"drill") == MachineDef.of(&"drill"), "two readings of one machine id are the same object")
	_check(RecipeDef.of(&"mine_ore") == RecipeDef.of(&"mine_ore"), "two readings of one recipe id are the same object")
	_check(MachineDef.of(&"drill").recipe == RecipeDef.of(&"mine_ore"), "a machine's recipe is the shared flyweight, not a copy")


func _test_machine_state_defaults_and_the_two_integer_rows() -> void:
	var m: MachineState = MachineState.new(MachineDef.of(&"drill"), Vector2i(7, 12))
	_check(m.def.id == &"drill" and m.logic_cell == Vector2i(7, 12), "state holds its def and its logic cell")
	_check(m.progress_ticks == 0 and typeof(m.progress_ticks) == TYPE_INT, "progress is an int tick count, starting at 0 (legacy: float seconds)")
	_check(m.power_permille == 1000 and typeof(m.power_permille) == TYPE_INT, "power boost is per mille, default 1000 = not gated (legacy: float 1.0)")
	_check(m.input_buffer.is_empty() and m.output_buffer.is_empty(), "both buffers start empty")
	_check(m.route_toggle == 0 and m.fuel == 0 and m.fed == 0 and m.facing == 1 and m.mode == 0 and m.filter == &"",
		"route_toggle 0, fuel 0, fed 0, facing 1, mode 0, filter empty -- legacy's defaults")
	_check(not ("spoil_buffer" in m), "spoil_buffer (Drift Rig only, dead) did not come over")
