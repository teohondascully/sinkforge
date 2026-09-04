extends "res://tests/test_base.gd"

## THE REST MARKER (2026-09-04): `WaterFlow.step` skips a plane that a previous step left unchanged, as long
## as neither the plane nor the grid's solidity has moved since. The skip is exact by construction -- the
## step is a pure function of (levels, solidity) -- and this suite is the mechanism check that construction
## needs: a settled plane IS skipped, a dig or a pour DOES wake it, a same-value write moves nothing, and a
## fuzzed run with digs and pours matches, tick for tick, a control plane forced to step in full. The
## positive control forges a rest marker on a moving plane and asserts the comparison registers the wrong
## skip -- without it a comparison that could never differ would pass on a no-op.

const ROCK: StringName = &"hardrock"
const FUZZ_TICKS: int = 3000


func _initialize() -> void:
	_test_a_settled_plane_is_skipped_and_a_dig_wakes_it()
	_test_a_pour_wakes_a_resting_plane_and_a_same_value_write_does_not()
	_test_a_second_grid_built_alike_is_not_the_same_grid()
	_test_skipping_plane_matches_a_control_stepped_in_full()
	_test_forged_rest_marker_is_registered_by_the_comparison()
	_finish("water_rest")


func _rock(grid: TileGrid, terrain_cell: Vector2i) -> void:
	grid.set_material(terrain_cell, ROCK)


## A walled shaft with a floor at row 8, 6 units poured at the top and run to rest.
func _settled_shaft() -> Array:
	var grid: TileGrid = TileGrid.new(16, 16, 1)
	for row: int in range(0, 9):
		_rock(grid, Vector2i(4, row))
		_rock(grid, Vector2i(6, row))
	for col: int in 16:
		_rock(grid, Vector2i(col, 9))
	var water: WaterPlane = WaterPlane.new()
	water.add_water(grid, Vector2i(5, 1), 6)
	for _t: int in 30:
		WaterFlow.step(water, grid)
	return [grid, water]


func _test_a_settled_plane_is_skipped_and_a_dig_wakes_it() -> void:
	var pair: Array = _settled_shaft()
	var grid: TileGrid = pair[0]
	var water: WaterPlane = pair[1]
	_check(water.water_at(Vector2i(5, 8)) == 6, "fixture: the 6 units settled on the floor")
	_check(water.at_rest(grid), "after 30 ticks the plane reads at rest")
	var version: int = water.version
	WaterFlow.step(water, grid)
	_check(water.version == version and water.water_at(Vector2i(5, 8)) == 6, "a resting step writes nothing")
	grid.excavate(Vector2i(5, 9))   # open the floor under the pool
	_check(not water.at_rest(grid), "a dig in the grid wakes the plane before any step runs")
	WaterFlow.step(water, grid)
	_check(water.water_at(Vector2i(5, 9)) == 6 and water.water_at(Vector2i(5, 8)) == 0, "the woken step let the pool fall a cell")
	_check(not water.at_rest(grid), "a step that moved water does not mark rest")
	for _t: int in 20:
		WaterFlow.step(water, grid)
	_check(water.at_rest(grid) and water.total_water() == 6, "the pool rests again on the new floor, total kept")


func _test_a_pour_wakes_a_resting_plane_and_a_same_value_write_does_not() -> void:
	var pair: Array = _settled_shaft()
	var grid: TileGrid = pair[0]
	var water: WaterPlane = pair[1]
	var version: int = water.version
	var sig: String = water.state_signature()
	water.set_level(Vector2i(5, 8), 6)   # the value already there
	water.set_level(Vector2i(2, 2), 0)   # a dry cell written dry
	_check(water.version == version and water.state_signature() == sig, "a same-value write moves neither the version nor the lanes")
	_check(water.state_signature() == water.recomputed_signature(), "and the running signature still agrees with the rebuild")
	_check(water.at_rest(grid), "so the plane still reads at rest")
	water.add_water(grid, Vector2i(5, 2), 3)
	_check(not water.at_rest(grid), "a pour wakes the plane")
	for _t: int in 20:
		WaterFlow.step(water, grid)
	_check(water.at_rest(grid) and water.water_at(Vector2i(5, 8)) == 8 and water.water_at(Vector2i(5, 7)) == 1, "9 units rest as a full cell and one above it")


func _test_a_second_grid_built_alike_is_not_the_same_grid() -> void:
	var pair: Array = _settled_shaft()
	var grid: TileGrid = pair[0]
	var water: WaterPlane = pair[1]
	var twin: TileGrid = TileGrid.new(16, 16, 1)
	for row: int in range(0, 9):
		_rock(twin, Vector2i(4, row))
		_rock(twin, Vector2i(6, row))
	for col: int in 16:
		_rock(twin, Vector2i(col, 9))
	_check(twin.terrain_version == grid.terrain_version, "fixture: the twin grid carries the same version number")
	_check(water.at_rest(grid) and not water.at_rest(twin), "the rest marker names its grid, not only its version")


## The plane under test (skips allowed) against a control that is forced to step in full every tick, on
## one shared grid that is dug and poured into at random. Levels and lanes must agree on every tick, and
## both populations -- ticks skipped and ticks stepped -- must be non-empty for the agreement to mean anything.
func _test_skipping_plane_matches_a_control_stepped_in_full() -> void:
	var rng: SplitRng = SplitRng.new(4242)
	var grid: TileGrid = TileGrid.new(24, 24, 1)
	for row: int in 24:
		for col: int in 24:
			if rng.next_range(0, 99) < 40:
				_rock(grid, Vector2i(col, row))
	var water: WaterPlane = WaterPlane.new()
	for _i: int in 40:
		water.add_water(grid, Vector2i(rng.next_range(0, 23), rng.next_range(0, 23)), rng.next_range(1, 8))
	var control: WaterPlane = water.clone()
	var skipped: int = 0
	var stepped: int = 0
	var agreed: int = 0
	var first_bad: String = ""
	for t: int in FUZZ_TICKS:
		var roll: int = rng.next_range(0, 99)
		if roll < 3:
			var c := Vector2i(rng.next_range(0, 23), rng.next_range(0, 23))
			if grid.is_solid(c):
				grid.excavate(c)
		elif roll < 5:
			var c2 := Vector2i(rng.next_range(0, 23), rng.next_range(0, 23))
			var amount: int = rng.next_range(1, 8)
			water.add_water(grid, c2, amount)
			control.add_water(grid, c2, amount)
		if water.at_rest(grid):
			skipped += 1
		else:
			stepped += 1
		WaterFlow.step(water, grid)
		control.rest_version = -1   # the control never skips
		WaterFlow.step(control, grid)
		if water.levels == control.levels and water.state_signature() == control.state_signature():
			agreed += 1
		elif first_bad.is_empty():
			first_bad = " first disagreement at tick %d: %d vs %d cells" % [t, water.levels.size(), control.levels.size()]
	_check_over(FUZZ_TICKS, agreed == FUZZ_TICKS, "the skipping plane matched the full-step control on every one of %d ticks%s" % [FUZZ_TICKS, first_bad])
	_check(skipped > 0 and stepped > 0, "both populations were exercised: skipped=%d stepped=%d" % [skipped, stepped])
	_check(skipped > FUZZ_TICKS / 4, "the skip is worth having: %d of %d ticks skipped on a mostly-resting plane" % [skipped, FUZZ_TICKS])
	_check(water.state_signature() == water.recomputed_signature(), "the running signature still matches the rebuild at the end")


## Forge a rest marker on a plane that is still moving: the step skips, the control does not, and the
## comparison the test above relies on must be able to register the difference.
func _test_forged_rest_marker_is_registered_by_the_comparison() -> void:
	var grid: TileGrid = TileGrid.new(16, 16, 1)
	for col: int in 16:
		_rock(grid, Vector2i(col, 12))
	var water: WaterPlane = WaterPlane.new()
	water.add_water(grid, Vector2i(5, 1), 6)
	var control: WaterPlane = water.clone()
	water.rest_version = water.version
	water.rest_terrain = grid.terrain_version
	water.rest_grid = grid.get_instance_id()
	_check(water.at_rest(grid), "fixture: the marker is forged on a plane with water in the air")
	WaterFlow.step(water, grid)
	WaterFlow.step(control, grid)
	_check(water.levels != control.levels, "positive control: a wrong skip is visible as a levels disagreement (%d vs %d)" % [water.water_at(Vector2i(5, 1)), control.water_at(Vector2i(5, 1))])
