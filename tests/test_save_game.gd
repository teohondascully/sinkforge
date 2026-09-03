extends "res://tests/test_base.gd"

## `shell/save_game.gd` (A' step 3g, ADR 0010, D0352): a lived-in world captured, restored into fresh
## services and proven identical by every signature, then ticked on both sides (determinism is the
## verifier); the same through disk; every refusal path with its reason; the dangling-winch
## reconciliation legacy's `_test_freight_winch_lifecycle` second half tested through a save; and the
## tmp/readback/bak/rename protocol with `read()`'s four verdicts. All disk IO is a scratch path.

const ROCK: StringName = &"hardrock"
const SCRATCH: String = "user://test_save_game_scratch.save"

var world: World
var items: Items
var machines: Machines


func _initialize() -> void:
	_test_round_trip_is_signature_identical_and_stays_so_under_ticks()
	_test_round_trip_through_disk_and_the_fixture_guard()
	_test_refusals_name_their_reason_and_touch_nothing()
	_test_dangling_winch_routes_reconcile_without_losing_cargo()
	_test_write_is_durable_and_read_recovers()
	_cleanup()
	_finish("save_game")


func _feed(cell: Vector2i, item: StringName, n: int) -> void:
	_feed_machine(items, cell, item, n)


## A world with every plane and every kind of state populated, then lived in for a few ticks.
func _lived_in() -> void:
	items = _hub_items()
	world = items.world
	machines = _hub_machines(items)
	for y: int in range(9, 12):
		for x: int in range(2, 12):
			world.set_solid(Vector2i(x, y), ROCK)
	world.set_solid(Vector2i(6, 8), &"ore_iron")
	world.deposits.set_deposit(Vector2i(24, 32), 3)
	world.set_wall(Vector2i(4, 7), ROCK)
	world.grid.set_material(Vector2i(13, 30), ROCK)          # a half-dug metre (3, 7)
	world.grid.extend_terrain_dig_extent(5, 3, 9)
	PlacedVerbs.place_conduit(world, Vector2i(9, 4))
	PlacedVerbs.place_conduit(world, Vector2i(9, 5))
	PlacedVerbs.place_rope(world, Vector2i(2, 2), 3)
	world.logic.plant(Vector2i(4, 8))
	world.logic.set_sapling_age(Vector2i(4, 8), 7)
	for tc: Vector2i in world.terrain_cells_of(Vector2i(7, 8)):
		world.water.set_level(tc, 5)
	world.deposits.seed_lode(Vector2i(40, 20), &"coal", 4)
	world.deposits.take_one(world.grid, Vector2i(40, 20))
	items.pack.add(&"ore", 5)
	items.pack.add(&"ingot", 2)
	items.produced(&"ore", 5)
	items.produced(&"ingot", 2)
	items.drop_item(Vector2i(3, 2), &"ingot", 1)               # a pile on the floor at (3, 8)
	items.pack.add(&"gear", 1)
	items.produced(&"gear", 1)
	items.drop_item(Vector2i(14, 1), &"gear", 1)               # no floor in column 14: the sink
	machines.place(world, MachineDef.of(&"hopper"), Vector2i(5, 3))
	machines.place(world, MachineDef.of(&"processor"), Vector2i(5, 6))
	machines.place(world, MachineDef.of(&"generator"), Vector2i(10, 8))
	machines.place(world, MachineDef.of(&"winch_head"), Vector2i(10, 7), -1)
	machines.place(world, MachineDef.of(&"winch_station"), Vector2i(11, 7))
	machines.link_winch(Vector2i(10, 7), Vector2i(11, 7))
	_feed(Vector2i(5, 3), &"coal", 1)
	_feed(Vector2i(5, 3), &"ore", 4)
	_feed(Vector2i(10, 8), &"coal", 3)
	_feed(Vector2i(10, 7), &"ore", 3)
	for _i: int in 3:
		HubTick.step(world, items, machines)


func _sig(w: World, i: Items, m: Machines) -> String:
	return w.state_signature() + "/" + i.state_signature() + "/" + m.state_signature()


func _test_round_trip_is_signature_identical_and_stays_so_under_ticks() -> void:
	_lived_in()
	var hop: MachineState = machines.machine_at(Vector2i(5, 3))
	_check(hop.filter == &"coal" and machines.winch_transit.has(Vector2i(10, 7)) and world.water.total_water() > 0, "the fixture is lived in: a latched hopper, a trip in flight, water")
	var env: Dictionary = SaveGame.capture(world, items, machines)
	_check(env["version"] == 3 and env["machines"].size() == 5 and not (env["placed"] as Dictionary).values().has(LogicGrid.KIND_MACHINE), "v3, five machines, and no machine cell in the placed plane (the registry re-registers them)")
	for key: String in SaveGame.REQUIRED_KEYS:
		if not env.has(key):
			_check(false, "capture wrote required key %s" % key)
	var before: String = _sig(world, items, machines)
	var i2: Items = _hub_items()
	var m2: Machines = _hub_machines(i2)
	_check(SaveGame.restore(i2.world, i2, m2, env), "restore accepted the capture")
	_check(_sig(i2.world, i2, m2) == before, "world, items and machines sign identically after the round trip")
	_check(i2.world.grid.recomputed_signature() == i2.world.grid.state_signature() and i2.world.logic.recomputed_signature() == i2.world.logic.state_signature(), "the terrain's and the placed plane's running signatures agree with a rebuild")
	_check(i2.world.water.recomputed_signature() == i2.world.water.state_signature() and i2.world.deposits.recomputed_signature() == i2.world.deposits.state_signature() and i2.pack.recomputed_signature() == i2.pack.state_signature(), "so do water, deposits and the pack")
	_check(i2.world.grid.dig_extents() == world.grid.dig_extents() and i2.world.grid.get_wall(Vector2i(16, 28)) == ROCK, "the dug extent and the wall came back")
	var ids: Array[StringName] = []
	for m: MachineState in m2.machines:
		ids.append(m.def.id)
	var expected: Array[StringName] = [&"hopper", &"processor", &"generator", &"winch_head", &"winch_station"]
	_check(ids == expected and m2.machine_at(Vector2i(10, 7)).facing == -1, "placement order and facing survive")
	_check(m2.machine_at(Vector2i(5, 3)).filter == &"coal" and i2.pack.slots()[0]["item"] == &"ore" and i2.pack.slots()[1]["item"] == &"ingot", "the hopper's latch and the pack's hotbar order survive")
	_check(int(m2.winch_transit[Vector2i(10, 7)]["ticks_remaining"]) == int(machines.winch_transit[Vector2i(10, 7)]["ticks_remaining"]), "the trip's countdown survives")
	_check(m2.power.is_empty() and i2.flow_events.is_empty() and i2.last_drop_landing == Vector2i(-1, -1), "derived state starts clean")
	_check(Invariants.check_item_conservation(i2, 0) == null, "conserved in the restored world")
	for _i: int in 100:
		HubTick.step(world, items, machines)
		HubTick.step(i2.world, i2, m2)
	_check(_sig(i2.world, i2, m2) == _sig(world, items, machines) and _sig(world, items, machines) != before, "100 ticks each: still identical, and the world moved")
	_check(i2.machine_buffer.call(Vector2i(5, 6)) == m2.machine_at(Vector2i(5, 6)).input_buffer, "Items is re-attached to the restored registry")


func _test_round_trip_through_disk_and_the_fixture_guard() -> void:
	_lived_in()
	_cleanup()
	var env: Dictionary = SaveGame.capture(world, items, machines)
	_check(SaveGame.write(SCRATCH, env) and FileAccess.file_exists(SCRATCH) and not FileAccess.file_exists(SCRATCH + SaveGame.TMP_SUFFIX), "written to the scratch slot; no temp left behind")
	var back: Dictionary = SaveGame.read(SCRATCH)
	_check(SaveGame.last_read == SaveGame.Read.OK and back["version"] == 3, "read back OK")
	var i2: Items = _hub_items()
	var m2: Machines = _hub_machines(i2)
	_check(SaveGame.restore(i2.world, i2, m2, back) and _sig(i2.world, i2, m2) == _sig(world, items, machines), "Vector2i keys and StringNames survive the binary serializer: identical after disk")
	_check(SaveGame._fixture_may_not_write(SaveGame.SLOT) and not SaveGame._fixture_may_not_write(SCRATCH), "a --script fixture may write scratch, never the real slot")
	_check(not SaveGame.write(SaveGame.SLOT, env) and not FileAccess.file_exists(SaveGame.SLOT + SaveGame.TMP_SUFFIX), "writing the real slot from a fixture is refused before any file is touched")


func _test_refusals_name_their_reason_and_touch_nothing() -> void:
	_lived_in()
	var env: Dictionary = SaveGame.capture(world, items, machines)
	var i2: Items = _hub_items()
	var m2: Machines = _hub_machines(i2)
	var untouched: String = _sig(i2.world, i2, m2)
	_check(not SaveGame.restore(i2.world, i2, m2, {}) and SaveGame.last_invalid == "empty", "empty: refused")
	var v2: Dictionary = env.duplicate(true)
	v2["version"] = 2
	_check(not SaveGame.restore(i2.world, i2, m2, v2) and SaveGame.last_invalid.begins_with("pre-pivot save (v2)"), "a pre-pivot v2 envelope is refused by name (ADR 0010)")
	var v4: Dictionary = env.duplicate(true)
	v4["version"] = 4
	_check(not SaveGame.restore(i2.world, i2, m2, v4) and SaveGame.last_invalid.begins_with("version 4 outside"), "a future version is refused")
	var holed: Dictionary = env.duplicate(true)
	holed.erase("pack")
	_check(not SaveGame.restore(i2.world, i2, m2, holed) and SaveGame.last_invalid == "missing key: pack", "a missing required key is named")
	var typed: Dictionary = env.duplicate(true)
	typed["blocks"] = [1, 2]
	_check(not SaveGame.restore(i2.world, i2, m2, typed) and SaveGame.last_invalid == "wrong type: blocks", "a wrong type is named")
	var seedless: Dictionary = env.duplicate(true)
	seedless.erase("world_seed")
	_check(not SaveGame.restore(i2.world, i2, m2, seedless) and SaveGame.last_invalid == "missing key: world_seed", "the seed may not be defaulted")
	var alien: Dictionary = env.duplicate(true)
	(alien["machines"] as Array)[0]["def"] = "ore_vent"
	_check(not SaveGame.restore(i2.world, i2, m2, alien) and SaveGame.last_invalid.begins_with("machines: unknown def ore_vent"), "a machine whose def does not exist refuses the whole save")
	var buried: Dictionary = env.duplicate(true)
	(buried["machines"] as Array)[0]["cell"] = Vector2i(3, 10)
	_check(not SaveGame.restore(i2.world, i2, m2, buried) and SaveGame.last_invalid.begins_with("machines: hopper at (3, 10) cannot be placed"), "a machine inside rock refuses the whole save")
	var junk: Dictionary = env.duplicate(true)
	(junk["machines"] as Array)[1] = 7
	_check(not SaveGame.restore(i2.world, i2, m2, junk) and SaveGame.last_invalid == "machines: a malformed entry", "a malformed machine entry")
	_check(_sig(i2.world, i2, m2) == untouched and m2.count() == 0, "after every refusal the live services are untouched")
	var additive: Dictionary = env.duplicate(true)
	for key: String in ["dig_extent", "conduit_tiers", "sapling", "lode", "lode_max", "winch_routes", "winch_transit"]:
		additive.erase(key)
	_check(SaveGame.restore(i2.world, i2, m2, additive) and m2.winch_routes.is_empty() and not i2.world.logic.has_sapling(Vector2i(4, 8)), "the additive keys default to empty and the save still opens")


func _test_dangling_winch_routes_reconcile_without_losing_cargo() -> void:
	_lived_in()
	var env: Dictionary = SaveGame.capture(world, items, machines)
	var head_cell := Vector2i(10, 7)
	var cargo: int = int(machines.winch_transit[head_cell]["items"][&"ore"])
	_check(cargo == 3, "3 ore are in flight in the capture")
	var without_station: Dictionary = env.duplicate(true)
	for i: int in range((without_station["machines"] as Array).size() - 1, -1, -1):
		if (without_station["machines"] as Array)[i]["cell"] == Vector2i(11, 7):
			(without_station["machines"] as Array).remove_at(i)
	var i2: Items = _hub_items()
	var m2: Machines = _hub_machines(i2)
	_check(SaveGame.restore(i2.world, i2, m2, without_station), "a save with a dangling route still restores (fails closed, not refused whole)")
	_check(not m2.winch_routes.has(head_cell) and not m2.winch_transit.has(head_cell), "the dangling route and its transit are dropped")
	_check(int(m2.machine_at(head_cell).input_buffer.get(&"ore", 0)) == cargo, "the in-flight cargo returns to the surviving Head's own buffer")
	_check(Invariants.check_item_conservation(i2, 0) == null, "conservation holds after the reconciliation (head survives)")
	var without_either: Dictionary = env.duplicate(true)
	for i: int in range((without_either["machines"] as Array).size() - 1, -1, -1):
		var c: Vector2i = (without_either["machines"] as Array)[i]["cell"]
		if c == Vector2i(11, 7) or c == head_cell:
			(without_either["machines"] as Array).remove_at(i)
	var i3: Items = _hub_items()
	var m3: Machines = _hub_machines(i3)
	_check(SaveGame.restore(i3.world, i3, m3, without_either) and m3.machine_at(head_cell) == null, "both endpoints missing: still restores, neither survives")
	_check(int(m3.machine_at(Vector2i(10, 8)).input_buffer.get(&"ore", 0)) == cargo, "the cargo spilled down the Head's last column by the landing rule: the generator below caught it")
	_check(i3.present(&"ore") == items.present(&"ore") and Invariants.check_item_conservation(i3, 0) == null, "the cargo is not destroyed even with no machine left to hold it (present and conserved)")


func _test_write_is_durable_and_read_recovers() -> void:
	_lived_in()
	_cleanup()
	var first: Dictionary = SaveGame.capture(world, items, machines)
	_check(SaveGame.write(SCRATCH, first) and not FileAccess.file_exists(SCRATCH + SaveGame.BAK_SUFFIX), "first write: a primary, no backup yet")
	HubTick.step(world, items, machines)
	var second: Dictionary = SaveGame.capture(world, items, machines)
	_check(SaveGame.write(SCRATCH, second) and FileAccess.file_exists(SCRATCH + SaveGame.BAK_SUFFIX), "second write: the first became the backup")
	_check(SaveGame.read(SCRATCH)["produced"] == second["produced"] and SaveGame._read_file(SCRATCH + SaveGame.BAK_SUFFIX)["machines"][1]["progress_ticks"] == first["machines"][1]["progress_ticks"], "the primary is the second save and the backup the first")
	var f: FileAccess = FileAccess.open(SCRATCH, FileAccess.WRITE)
	f.store_var({"junk": true})   # decodes, but is no envelope (a truncated file also reads as {}, via an engine error the runner would count)
	f.close()
	var recovered: Dictionary = SaveGame.read(SCRATCH)
	_check(SaveGame.last_read == SaveGame.Read.RECOVERED and recovered["machines"][1]["progress_ticks"] == first["machines"][1]["progress_ticks"], "a damaged primary falls back to the backup and says so")
	_check(not SaveGame.write(SCRATCH, {"version": 3}) and SaveGame.read(SCRATCH + "") == recovered, "an envelope that does not read back valid is not promoted; a damaged primary is not copied over the good backup")
	DirAccess.remove_absolute(SCRATCH + SaveGame.BAK_SUFFIX)
	_check(SaveGame.read(SCRATCH).is_empty() and SaveGame.last_read == SaveGame.Read.CORRUPT, "damaged primary, no backup: CORRUPT, not a new player")
	DirAccess.remove_absolute(SCRATCH)
	_check(SaveGame.read(SCRATCH).is_empty() and SaveGame.last_read == SaveGame.Read.NONE, "nothing on disk: NONE")


func _cleanup() -> void:
	for suffix: String in ["", SaveGame.TMP_SUFFIX, SaveGame.BAK_SUFFIX]:
		if FileAccess.file_exists(SCRATCH + suffix):
			DirAccess.remove_absolute(SCRATCH + suffix)
