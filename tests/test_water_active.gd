extends "res://tests/test_base.gd"

## THE ACTIVE SET (D0405): `WaterFlow.step` visits the cells written last tick, the cells above them, the
## neighbourhood of every dig and the runs those sit in -- never the world. This suite pins it equal to
## `WaterFlow.step_full`, the algorithm as lifted, on the subject that made it necessary: THE FRESH BOOT
## WORLD'S OWN POUR, stepped tick for tick against a control forced to step in full. The fuzzed grid with
## digs, pours and rock is `tests/test_water_rest.gd`'s. Also here: the plane's row index reads a window
## equal to filtering the world; the grid's solidity log names a dig, gives up past its cap, and says
## `all` for a fresh, bulk-loaded or cloned grid; and the mechanism the exactness argument leans on -- a
## cell whose floor drains falls on the very next tick -- is pinned directly, with a positive control that
## shows the comparison can register a plane that stops visiting.

const ROCK: StringName = &"hardrock"
const POUR_TICKS: int = 300   # 15 s at the hub's 20 Hz: the whole of the stutter D0404 named


func _initialize() -> void:
	_test_the_fresh_world_pours_the_same_under_the_active_step()
	_test_wet_in_equals_filtering_the_world()
	_test_the_solidity_log_names_a_dig_and_gives_up_past_its_cap()
	_test_a_cell_whose_floor_drains_falls_next_tick()
	_test_a_plane_that_stops_visiting_is_registered()
	_finish("water_active")


func _rock(grid: TileGrid, terrain_cell: Vector2i) -> void:
	grid.set_material(terrain_cell, ROCK)


## The real subject: the boot site and seed, its aquifers seeded full against carved caves, so the first
## ticks pour. The plane under test steps actively; a clone steps in full on a clone of the grid (the two
## must not share a solidity log). Levels and lanes agree on every tick, the pour is real (the plane
## moved), and after the first full pass the seed of the next tick is a fraction of the wet count.
func _test_the_fresh_world_pours_the_same_under_the_active_step() -> void:
	# The world BEFORE `load_world` settles it: generated and enriched, the aquifers full against the caves.
	var world: World = World.new(ShaftGenerator.generate(StrataData.SHALLOW_CLAY, 20260826))
	ShaftGenerator.enrich(world, StrataData.SHALLOW_CLAY, 20260826)
	var grid: TileGrid = world.grid
	var water: WaterPlane = world.water
	var control_grid: TileGrid = grid.clone()
	var control: WaterPlane = water.clone()
	var wet_at_start: int = water.levels.size()
	var agreed: int = 0
	var moving_ticks: int = 0
	var first_bad: String = ""
	var seed_after_first: int = -1
	var seed_peak: int = 0
	var seed_sum: int = 0                    # every cell the active passes will visit, summed over the pour
	var trajectory: PackedInt32Array = []    # the seed at 1 s intervals, for the report
	for t: int in POUR_TICKS:
		var before: int = water.version
		WaterFlow.step(water, grid)
		control.rest_version = -1
		WaterFlow.step_full(control, control_grid)
		if water.version != before:
			moving_ticks += 1
		if t == 0:
			seed_after_first = water.touched.size()
		seed_peak = maxi(seed_peak, water.touched.size())
		seed_sum += water.touched.size()
		if t % 20 == 19:
			trajectory.append(water.touched.size())
		if water.levels == control.levels and water.state_signature() == control.state_signature():
			agreed += 1
		elif first_bad.is_empty():
			first_bad = " first disagreement at tick %d: %d vs %d wet cells, totals %d vs %d" % [t, water.levels.size(), control.levels.size(), water.total_water(), control.total_water()]
	_check_over(POUR_TICKS, agreed == POUR_TICKS, "the active step matched the full step on every one of %d ticks of the boot world's pour%s" % [POUR_TICKS, first_bad])
	_check(wet_at_start > 1000 and moving_ticks > 5, "the subject was posed: %d wet cells at boot, the plane moved on %d of %d ticks" % [wet_at_start, moving_ticks, POUR_TICKS])
	var full_visits: int = wet_at_start * moving_ticks   # what `step_full` walks on the ticks water moved
	_check(seed_sum < full_visits,
		"the active passes visit fewer cells than the full passes walk over the pour: %d against %d (%.0f%%) -- a mass pour moves most of its water, so the set is worth about half here and everything at rest" % [seed_sum, full_visits, 100.0 * seed_sum / maxi(1, full_visits)])
	_check(water.at_rest(grid) and water.touched.is_empty(), "the pour ends at rest with an empty seed (moved on %d of %d ticks)" % [moving_ticks, POUR_TICKS])
	_check(water.state_signature() == water.recomputed_signature(), "the running signature matches the rebuild after the pour")
	print("water_active: boot pour wet=%d moving_ticks=%d seed_after_first=%d seed_peak=%d seed_sum=%d full_visits=%d seed_per_second=%s" % [wet_at_start, moving_ticks, seed_after_first, seed_peak, seed_sum, full_visits, trajectory])
	_the_door_world_arrives_at_rest(world, moving_ticks)


## `WorldSeeder.load_world` hands the player the same world after `WaterFlow.settle`: at rest, the water
## conserved, the levels equal to the pour's own end state, the ticks it spent equal to the pour's length.
func _the_door_world_arrives_at_rest(poured: World, moving_ticks: int) -> void:
	var settled: World = WorldSeeder.load_world(StrataData.SHALLOW_CLAY, 20260826)
	_check(settled.water.at_rest(settled.grid) and settled.water.touched.is_empty(), "the door's fresh world is at rest before the first hub tick (%d ticks settled)" % WorldSeeder.settled_ticks)
	_check(settled.water.total_water() == poured.water.total_water() and settled.water.total_water() > 0, "settling conserved the water: %d units" % settled.water.total_water())
	_check(settled.water.levels == poured.water.levels and settled.water.state_signature() == poured.water.state_signature(), "the settled plane IS the pour's end state, cell for cell")
	_check(WorldSeeder.settled_ticks == moving_ticks + 1 and WorldSeeder.settled_ticks < WorldSeeder.SETTLE_TICKS / 2,
		"the settle spent the pour's ticks plus the one that found rest, %d, well under the cap of %d" % [WorldSeeder.settled_ticks, WorldSeeder.SETTLE_TICKS])
	_check(settled.grid.state_signature() == poured.grid.state_signature(), "settling wrote nothing to the terrain")
	# The win the pour cannot show: at rest, a dig far from any water wakes its own neighbourhood, not the
	# world's %d wet cells, and the plane is back at rest after one step that wrote nothing.
	var far := Vector2i(2, ShaftGenerator.SKY_ROWS + 4)
	if not settled.grid.is_solid(far):
		settled.grid.set_material(far, ROCK)
		settled.grid.take_solidity_changes()
	settled.grid.excavate(far)
	var woken: Dictionary = WaterFlow._wake(settled.water, settled.grid.take_solidity_changes())
	_check(woken.size() == 5 and woken.has(far), "a dig far from the water wakes five cells, not %d: %d" % [settled.water.levels.size(), woken.size()])
	settled.grid.excavate(far + Vector2i(1, 0))
	var v: int = settled.water.version
	WaterFlow.step(settled.water, settled.grid)
	_check(settled.water.version == v and settled.water.at_rest(settled.grid), "the step after a far dig writes nothing and rests again")


func _test_wet_in_equals_filtering_the_world() -> void:
	var rng: SplitRng = SplitRng.new(77)
	var grid: TileGrid = TileGrid.new(64, 64, 1)
	var water: WaterPlane = WaterPlane.new()
	for _i: int in 400:
		water.add_water(grid, Vector2i(rng.next_range(0, 63), rng.next_range(0, 63)), rng.next_range(1, 8))
	for _j: int in 100:
		water.remove_water(Vector2i(rng.next_range(0, 63), rng.next_range(0, 63)), 8)   # erasures leave the index
	var rect := Rect2i(10, 20, 30, 25)
	var filtered: Dictionary = {}
	for c: Vector2i in water.levels:
		if rect.has_point(c):
			filtered[c] = true
	var expect: Array[Vector2i] = Ordering.cells_native(filtered)
	var got: Array[Vector2i] = water.wet_terrain_cells_in(rect)
	_check(got == expect and got.size() > 20, "wet_terrain_cells_in reads the window off the row index equal to filtering the world: %d cells" % got.size())
	_check(got.size() < water.levels.size(), "positive control: the window excludes cells, so equality is not the whole plane (%d of %d)" % [got.size(), water.levels.size()])
	var copy: WaterPlane = water.clone()
	_check(copy.wet_terrain_cells_in(rect) == expect, "a clone rebuilds the index and reads the same window")
	_check(water.wet_terrain_cells_in(Rect2i(0, 0, 0, 0)).is_empty() and water.wet_terrain_cells_in(Rect2i(200, 200, 10, 10)).is_empty(), "an empty or off-plane window reads nothing")


func _test_the_solidity_log_names_a_dig_and_gives_up_past_its_cap() -> void:
	var grid: TileGrid = TileGrid.new(80, 80, 1)
	var first: Dictionary = grid.take_solidity_changes()
	_check(bool(first["all"]) and (first["cells"] as Array).is_empty(), "a fresh grid says `all`: nothing has read it yet")
	_rock(grid, Vector2i(3, 4))
	grid.excavate(Vector2i(3, 4))
	grid.set_wall(Vector2i(5, 5), ROCK)
	var second: Dictionary = grid.take_solidity_changes()
	var named: Array[Vector2i] = [Vector2i(3, 4), Vector2i(3, 4)]
	_check(not bool(second["all"]) and second["cells"] == named,
		"a block write and a dig are named, in order; a wall write is not solidity: %s" % [second["cells"]])
	_check((grid.take_solidity_changes()["cells"] as Array).is_empty(), "taking the log empties it")
	for i: int in TileGrid.SOLIDITY_LOG_CAP + 1:
		_rock(grid, Vector2i(i % 80, i / 80))
	var third: Dictionary = grid.take_solidity_changes()
	_check(bool(third["all"]) and (third["cells"] as Array).is_empty(), "past the cap the log says `all` and names nothing")
	_check(bool(grid.clone().take_solidity_changes()["all"]), "a clone starts with `all`")
	var loaded: TileGrid = TileGrid.new(8, 8, 1)
	loaded.take_solidity_changes()
	loaded.load_cells({Vector2i(1, 1): ROCK}, {})
	_check(bool(loaded.take_solidity_changes()["all"]), "a bulk load says `all`")


## The rule the exactness argument leans on: the cell ABOVE a written cell is woken. A column of water on a
## floor; the floor is dug out; the bottom cell falls; the cell above it -- itself unwritten that tick --
## must fall on the next tick, as it does under `step_full`.
func _test_a_cell_whose_floor_drains_falls_next_tick() -> void:
	var grid: TileGrid = TileGrid.new(8, 12, 1)
	for row: int in 12:
		_rock(grid, Vector2i(2, row))
		_rock(grid, Vector2i(4, row))
	_rock(grid, Vector2i(3, 6))
	_rock(grid, Vector2i(3, 10))
	var water: WaterPlane = WaterPlane.new()
	water.add_water(grid, Vector2i(3, 4), 8)
	water.add_water(grid, Vector2i(3, 5), 8)
	for _t: int in 4:
		WaterFlow.step(water, grid)
	_check(water.at_rest(grid) and water.water_at(Vector2i(3, 5)) == 8, "two full cells rest on the floor at row 6")
	var control: WaterPlane = water.clone()
	var control_grid: TileGrid = grid.clone()
	grid.excavate(Vector2i(3, 6))
	control_grid.excavate(Vector2i(3, 6))
	WaterFlow.step(water, grid)
	WaterFlow.step_full(control, control_grid)
	_check(water.water_at(Vector2i(3, 4)) == 8 and water.water_at(Vector2i(3, 5)) == 0 and water.water_at(Vector2i(3, 6)) == 8,
		"tick 1: the bottom cell fell into the dug floor; the top cell, reached first, still had no room (%d/%d/%d at rows 4/5/6)" % [water.water_at(Vector2i(3, 4)), water.water_at(Vector2i(3, 5)), water.water_at(Vector2i(3, 6))])
	WaterFlow.step(water, grid)
	WaterFlow.step_full(control, control_grid)
	_check(water.water_at(Vector2i(3, 4)) == 0 and water.water_at(Vector2i(3, 5)) == 8 and water.levels == control.levels,
		"tick 2: the top cell -- unwritten on tick 1, woken as the cell ABOVE a written one -- fell (%d/%d at rows 4/5)" % [water.water_at(Vector2i(3, 4)), water.water_at(Vector2i(3, 5))])
	for _t2: int in 6:
		WaterFlow.step(water, grid)
		WaterFlow.step_full(control, control_grid)
	_check(water.levels == control.levels and water.water_at(Vector2i(3, 9)) == 8 and water.water_at(Vector2i(3, 8)) == 8,
		"the column falls to the new floor at row 10 under both steps alike")
	_check(water.at_rest(grid), "and rests there")


## Positive control for every comparison above: a plane whose seed is emptied before its step -- the
## failure an active set can have -- stops moving, and the comparison against `step_full` registers it.
func _test_a_plane_that_stops_visiting_is_registered() -> void:
	var grid: TileGrid = TileGrid.new(8, 12, 1)
	for col: int in 8:
		_rock(grid, Vector2i(col, 11))
	var water: WaterPlane = WaterPlane.new()
	water.add_water(grid, Vector2i(3, 2), 8)
	var control: WaterPlane = water.clone()
	WaterFlow.step(water, grid)
	WaterFlow.step_full(control, grid)
	_check(water.levels == control.levels, "one honest tick agrees")
	water.touched.clear()                   # the sabotage: nothing is woken next tick
	WaterFlow.step(water, grid)
	WaterFlow.step_full(control, grid)
	_check(water.levels != control.levels, "positive control: a plane that forgets its seed stops falling, and the comparison sees it (%d vs %d at row 4)" % [water.water_at(Vector2i(3, 4)), control.water_at(Vector2i(3, 4))])
