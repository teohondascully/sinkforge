extends "res://tests/test_base.gd"

## `sim/run/world_seeder.gd` (A' step 3h, D0353): legacy's tutorial opening as a data record stamped
## through the sim's verbs. Every fixture kind lands where the record says at the per-cell stocks the
## unit regime gives (D0349), machines in file order, the pack credited as produced; a bad record is
## refused before anything is stamped; twins sign the same; and the real generated site takes it.

const ROCK: StringName = &"hardrock"

var world: World
var items: Items
var machines: Machines


func _initialize() -> void:
	_test_tutorial_stamps_every_kind_at_the_record_cells()
	_test_dev_kit_stocks_the_pack_and_conserves()
	_test_refusals_leave_the_world_untouched()
	_test_twins_sign_the_same_and_the_real_site_takes_it()
	_test_a_room_fixture_opens_a_rectangle_and_floors_it()
	_finish("world_seeder")


## A flat 64 x 32 metre world with ground from the surface row down, like the generator's datum.
func _flat() -> void:
	items = _hub_items(64, 32)
	world = items.world
	machines = _hub_machines(items)
	for row_m: int in range(WorldSeeder.SURFACE_ROW_M, 32):
		for col_m: int in 64:
			world.set_solid(Vector2i(col_m, row_m), ROCK)


func _metre_yield(cell: Vector2i) -> int:
	var n: int = 0
	for tc: Vector2i in world.terrain_cells_of(cell):
		n += world.deposits.ore_deposit_at(world.grid, tc)
	return n


func _test_tutorial_stamps_every_kind_at_the_record_cells() -> void:
	_flat()
	_check(WorldSeeder.SURFACE_ROW_M == 20, "the surface row is the generator's datum: 20 m of sky")
	var start: Dictionary = StartsRecords.RECORDS["tutorial"]
	_check(WorldSeeder.stamp(world, items, machines, &"tutorial", &"shallow_clay"), "the tutorial start stamps on a flat world")
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(start)
	_check(spawn == Vector2i(32, 19) and world.logic_air(spawn) and world.logic_solid(spawn + Vector2i(0, 1)), "the spawn is the air metre above the surface at the spawn column, ground under it")
	_check(world.grid.get_material(Vector2i(120, 80)) == &"ore_iron" and world.grid.get_material(Vector2i(124, 80)) == &"ore_iron", "the starter vein: two metres of ore_iron left of spawn, in the surface row")
	_check(_metre_yield(Vector2i(30, 20)) == 208 and world.deposits.ore_deposit_at(world.grid, Vector2i(120, 80)) == 13, "legacy's 200 a metre is 13 a cell, 208 a metre")
	_check(world.grid.get_material(Vector2i(148, 80)) == &"coal" and _metre_yield(Vector2i(37, 20)) == 208, "the tutorial coal, five metres right")
	var opened: Array[Vector2i] = [Vector2i(35, 21), Vector2i(35, 22), Vector2i(36, 21), Vector2i(36, 22), Vector2i(36, 23), Vector2i(37, 22), Vector2i(37, 23), Vector2i(37, 24)]
	var all_air: bool = true
	for c: Vector2i in opened:
		all_air = all_air and world.logic_air(c)
	_check(all_air and world.logic_solid(Vector2i(35, 20)) and world.logic_solid(Vector2i(37, 21)), "the adit: eight metres opened, a stepped cut under an intact roof")
	_check(world.deposits.lode_at(Vector2i(144, 92)) == &"ore_iron" and world.deposits.lode_permille(Vector2i(144, 92)) == 1000 and world.deposits.ore_deposit_at(world.grid, Vector2i(144, 92)) == 3, "the face: a lode in an opened metre's wall, 3 a cell (legacy's 45 a metre), untouched so it draws full")
	_check(world.deposits.lode_workable(world.grid, Vector2i(148, 96)) and not world.deposits.lode_workable(world.grid, Vector2i(148, 100)), "the face is workable where opened; the deep vein behind rock is not, yet")
	_check(world.deposits.lode_at(Vector2i(148, 108)) == &"ore_iron" and world.deposits.ore_deposit_at(world.grid, Vector2i(148, 108)) == 8, "the deep vein: 8 a cell (legacy's 120 a metre), three metres of it")
	_check(world.logic_air(Vector2i(29, 20)) and world.logic_air(Vector2i(29, 21)) and WorldMaterials.is_soil(world.grid.get_material(Vector2i(116, 88))), "the forge pocket: two metres opened over a clay floor (legacy's earth)")
	var forge: MachineState = machines.machine_at(Vector2i(29, 20))
	_check(forge != null and forge.def.id == &"processor", "the bootstrap forge sits in the pocket")
	_check(world.logic_air(Vector2i(39, 20)) and world.logic_air(Vector2i(39, 21)) and _metre_yield(Vector2i(39, 22)) == 400, "the drill shaft: an open mouth and drill cell over a 400-unit vein (25 a cell)")
	_check(world.logic_air(Vector2i(39, 24)) and world.logic_solid(Vector2i(39, 25)) and machines.machine_at(Vector2i(39, 23)) != null, "the auto forge under the vein, a gap for ingots, a floor")
	_check(machines.count() == 2 and machines.machines[0] == forge, "two machines, in file order")
	_check(Invariants.check_placed_not_in_rock(world, 0) == null and Invariants.check_item_conservation(items, 0) == null, "nothing placed in rock; the ledger balances (no pack fixture in the tutorial)")
	_check(not WorldSeeder.stamp(world, items, machines, &"tutorial") and WorldSeeder.last_refusal.begins_with("machine processor at (29, 20)"), "stamping twice: the forge cell is taken, refused with the cell named")


func _test_dev_kit_stocks_the_pack_and_conserves() -> void:
	_flat()
	_check(WorldSeeder.stamp(world, items, machines, &"dev_kit"), "the dev kit stamps (no site: fits any)")
	_check(items.pack.count(&"ore") == 20 and items.pack.count(&"processor") == 2 and items.pack.count(&"conduit") == 10, "the pack is stocked from the record")
	_check(items.pack.count(&"splitter") == 0 and items.pack.count(&"wood") == 0, "no splitter (a ruling) and no wood (no material yet)")
	_check(int(items.total_produced[&"ore"]) == 20 and Invariants.check_item_conservation(items, 0) == null, "spawned items are counted as produced: conservation holds")
	_check(machines.count() == 0, "a pack-only record stamps nothing into the world")


func _test_refusals_leave_the_world_untouched() -> void:
	_flat()
	var before: String = world.state_signature() + items.state_signature() + machines.state_signature()
	_check(not WorldSeeder.stamp(world, items, machines, &"no_such_start") and WorldSeeder.last_refusal == "unknown start: no_such_start", "an unknown start id")
	_check(not WorldSeeder.stamp(world, items, machines, &"tutorial", &"deep_basalt") and WorldSeeder.last_refusal.begins_with("start tutorial is authored for site shallow_clay"), "a start authored for another site")
	var bad_material: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "solid", "dx": 0, "dy": 0, "material": "ore", "deposit": 1}]}
	_check(not WorldSeeder.stamp_record(world, items, machines, bad_material) and WorldSeeder.last_refusal == "unknown material: ore", "legacy's `ore` is not a material here: refused by name")
	var bad_machine: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "open", "cells": [[0, 0]]}, {"kind": "machine", "id": "ore_vent", "dx": 0, "dy": 0}]}
	_check(not WorldSeeder.stamp_record(world, items, machines, bad_machine) and WorldSeeder.last_refusal == "unknown machine: ore_vent", "an unknown machine, caught before the open fixture ahead of it stamped")
	var far: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "lode", "dx": 40, "dy": 0, "material": "coal", "amount": 1}]}
	_check(not WorldSeeder.stamp_record(world, items, machines, far) and WorldSeeder.last_refusal.begins_with("cell out of bounds"), "a cell off the world")
	var odd: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "tree", "dx": 0, "dy": 0}]}
	_check(not WorldSeeder.stamp_record(world, items, machines, odd) and WorldSeeder.last_refusal == "unknown fixture kind: tree", "an unknown kind")
	var empty_pack: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "pack", "item": "ore", "count": 0}]}
	_check(not WorldSeeder.stamp_record(world, items, machines, empty_pack), "a pack fixture with no count")
	_check(world.state_signature() + items.state_signature() + machines.state_signature() == before, "after every refusal nothing was stamped")
	var closed: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "machine", "id": "hopper", "dx": 0, "dy": 0}]}
	_check(not WorldSeeder.stamp_record(world, items, machines, closed) and WorldSeeder.last_refusal.begins_with("machine hopper at (32, 20): the cell is not open"), "a machine on a metre nothing opened: refused with the cell named (the one refusal that comes after stamping began)")


func _test_twins_sign_the_same_and_the_real_site_takes_it() -> void:
	_flat()
	WorldSeeder.stamp(world, items, machines, &"tutorial")
	var a: String = world.state_signature() + machines.state_signature()
	_flat()
	WorldSeeder.stamp(world, items, machines, &"tutorial")
	_check(world.state_signature() + machines.state_signature() == a, "twin worlds stamped the same sign the same")
	_check(world.deposits.recomputed_signature() == world.deposits.state_signature() and world.logic.recomputed_signature() == world.logic.state_signature(), "the deposit and placed planes' running signatures agree with a rebuild after stamping")
	var real: World = WorldSeeder.load_world(StrataData.SHALLOW_CLAY, 20260903)
	var real_items: Items = Items.new(real)
	var real_machines: Machines = _hub_machines(real_items)
	_check(real.grid.width == 256 and real.logic_in_bounds(Vector2i(39, 27)), "the real site is 64 metres wide and deep enough for every fixture")
	_check(WorldSeeder.stamp(real, real_items, real_machines, &"tutorial", &"shallow_clay"), "the generated shallow_clay world takes the tutorial start")
	var spawn: Vector2i = WorldSeeder.spawn_logic_cell(StartsRecords.RECORDS["tutorial"])
	_check(real.logic_air(spawn) and real.logic_solid(spawn + Vector2i(0, 1)) and real_machines.count() == 2, "on the real world too: the body spawns on solid ground, both forges placed")


## D0407: a `room` is a w x h rectangle of open metres from (dx, dy); with `floor` the row under it is
## solid in that material -- the fixture a scenario record needs where the tutorial listed cells one by one.
func _test_a_room_fixture_opens_a_rectangle_and_floors_it() -> void:
	_flat()
	var anchor := Vector2i(32, WorldSeeder.SURFACE_ROW_M)
	var floored: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "room", "dx": 2, "dy": 4, "w": 5, "h": 3, "floor": "clay"}]}
	_check(WorldSeeder.stamp_record(world, items, machines, floored), "a floored room stamps (%s)" % WorldSeeder.last_refusal)
	var open_cells: int = 0
	var floor_cells: int = 0
	for dx: int in 5:
		for dy: int in 3:
			if world.logic_open(anchor + Vector2i(2 + dx, 4 + dy)):
				open_cells += 1
		if world.grid.get_material(world.terrain_cells_of(anchor + Vector2i(2 + dx, 7))[0]) == &"clay":
			floor_cells += 1
	_check(open_cells == 15 and floor_cells == 5, "5 x 3 metres open (%d) over a clay floor row (%d)" % [open_cells, floor_cells])
	_check(not world.logic_open(anchor + Vector2i(1, 4)) and not world.logic_open(anchor + Vector2i(7, 4)) and not world.logic_open(anchor + Vector2i(2, 3)),
		"and nothing beside or above it moved")
	var bare: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "room", "dx": 10, "dy": 4, "w": 2, "h": 2}]}
	_check(WorldSeeder.stamp_record(world, items, machines, bare) and world.logic_open(anchor + Vector2i(10, 5)) and world.grid.get_material(world.terrain_cells_of(anchor + Vector2i(10, 6))[0]) == ROCK,
		"a room without a floor opens its rows and leaves the rock under it as it was")
	var bad: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "room", "dx": 0, "dy": 4, "w": 0, "h": 2}]}
	_check(not WorldSeeder.stamp_record(world, items, machines, bad) and WorldSeeder.last_refusal.begins_with("room fixture needs"), "a room with no width is refused by name")
	var bad_floor: Dictionary = {"spawn_col_m": 32, "fixtures": [{"kind": "room", "dx": 0, "dy": 4, "w": 2, "h": 2, "floor": "ore"}]}
	_check(not WorldSeeder.stamp_record(world, items, machines, bad_floor), "and an unknown floor material")
