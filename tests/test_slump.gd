extends "res://tests/test_base.gd"

## `sim/mining/slump.gd` -- LOOSE MATERIAL FALLS (D0562). Posed by hand on a grid of known material, so
## every cell the automaton moves is one this file put there and every count below is exact.
##
## The four properties that matter, in the order they would break:
##   1. CONSERVATION. A step moves loose cells; it never makes or destroys one. Fuzzed.
##   2. DETERMINISM. Two grids posed identically and stepped identically finish identical. Fuzzed.
##   3. REST. A supported cell does not move, and a step that moves nothing leaves the world alone.
##   4. THE RULES THEMSELVES: it falls, it slumps to an angle, it will not squeeze a diagonal crack, it
##      will not enter water, and a non-loose material never moves at all.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_slump.gd

const W: int = 64
const H: int = 48
const LOOSE := &"clay"        ## data/materials/clay.yaml carries `loose: true`
const FIRM := &"hardrock"     ## and hardrock does not


func _initialize() -> void:
	_test_the_flag_is_the_one_the_data_carries()
	_test_an_unsupported_cell_falls_one_cell_a_step()
	_test_a_supported_cell_never_moves()
	_test_firm_material_never_moves()
	_test_a_column_slumps_to_a_heap()
	_test_a_diagonal_crack_does_not_leak()
	_test_water_is_a_floor()
	_test_a_step_conserves_every_loose_cell()
	_test_two_identical_worlds_settle_identically()
	_test_nothing_moves_until_a_blow_wakes_it()
	_test_the_view_is_told_what_moved_and_what_it_was()
	_finish("slump")


func _grid() -> TileGrid:
	return TileGrid.new(W, H, 7)


func _water() -> WaterPlane:
	return WaterPlane.new()


## Run `steps` settles, seeding the queue with `wake` as a blow at that cell would.
func _run(grid: TileGrid, water: WaterPlane, wake: Array[Vector2i], steps: int) -> Slump:
	var s: Slump = Slump.new()
	s.after_break(grid, wake)
	for _i: int in steps:
		s.settle(grid, water)
	return s


func _count(grid: TileGrid, material: StringName) -> int:
	var n: int = 0
	for y: int in H:
		for x: int in W:
			if grid.get_material(Vector2i(x, y)) == material:
				n += 1
	return n


## The suite's whole premise: `clay` is loose and `hardrock` is not, in the DATA, not in this file. If a
## record changes, this fails first and names the reason rather than letting six later assertions go
## quietly green on a world where nothing was ever loose.
func _test_the_flag_is_the_one_the_data_carries() -> void:
	_check(WorldMaterials.is_loose(LOOSE), "%s is loose in data/materials" % LOOSE)
	_check(not WorldMaterials.is_loose(FIRM), "%s is not loose in data/materials" % FIRM)
	_check(not WorldMaterials.is_loose(&"ore_iron"), "ore is never loose: it would have to carry its deposit")
	_check(not WorldMaterials.is_loose(&"no_such_material"), "an unknown material is not loose")


func _test_an_unsupported_cell_falls_one_cell_a_step() -> void:
	var grid: TileGrid = _grid()
	var water: WaterPlane = _water()
	for x: int in range(6, 15):
		grid.set_material(Vector2i(x, 30), FIRM)       # a floor, five cells down
	grid.set_material(Vector2i(10, 25), LOOSE)
	var s: Slump = Slump.new()
	s.after_break(grid, [Vector2i(10, 26)])
	s.settle(grid, water)
	_check(grid.get_material(Vector2i(10, 26)) == LOOSE, "one step moves the cell exactly one cell down")
	_check(_count(grid, LOOSE) == 1, "one cell, one step, one move: it did not fall the whole budget at once")
	_check(grid.get_material(Vector2i(10, 25)) == &"", "and leaves the cell it came from empty")
	for _i: int in 10:
		s.settle(grid, water)
	_check(grid.get_material(Vector2i(10, 29)) == LOOSE, "it comes to rest on the floor, not through it")
	_check(_count(grid, LOOSE) == 1, "and there is still exactly one loose cell")


func _test_a_supported_cell_never_moves() -> void:
	var grid: TileGrid = _grid()
	grid.set_material(Vector2i(10, 30), FIRM)
	grid.set_material(Vector2i(10, 29), LOOSE)
	_run(grid, _water(), [Vector2i(11, 29)], 20)
	_check(grid.get_material(Vector2i(10, 29)) == LOOSE, "a cell resting on rock stays where it is")


func _test_firm_material_never_moves() -> void:
	var grid: TileGrid = _grid()
	grid.set_material(Vector2i(10, 20), FIRM)          # nothing at all beneath it
	_run(grid, _water(), [Vector2i(10, 21)], 30)
	_check(grid.get_material(Vector2i(10, 20)) == FIRM, "hardrock hangs: only loose material falls")


## THE ANGLE OF REPOSE, posed the way the game poses it: a bank of earth on bedrock, trenched on both
## sides by hand until a two-metre column is left standing. That column must not stand.
func _test_a_column_slumps_to_a_heap() -> void:
	var grid: TileGrid = _grid()
	var water: WaterPlane = _water()
	for x: int in range(4, 24):
		grid.set_material(Vector2i(x, 30), FIRM)
	for x: int in range(13, 16):
		for i: int in 8:
			grid.set_material(Vector2i(x, 29 - i), LOOSE)
	var s: Slump = Slump.new()
	for x: int in [13, 15]:                # the two trenches, cut cell by cell as a hold cuts them
		for i: int in 8:
			var c := Vector2i(x, 29 - i)
			grid.excavate(c)
			s.after_break(grid, [c])
	_check(_count(grid, LOOSE) == 8, "the trenches leave an eight-cell column standing")
	for _t: int in 200:
		s.settle(grid, water)
	var height: int = 0
	for y: int in range(0, 30):
		if grid.get_material(Vector2i(14, y)) == LOOSE:
			height = 30 - y
			break
	var width: int = 0
	for x: int in range(4, 24):
		if grid.get_material(Vector2i(x, 29)) == LOOSE:
			width += 1
	_check(_count(grid, LOOSE) == 8, "the heap still holds all eight cells")
	_check(height < 8, "the column came down: %d cells tall, was 8" % height)
	_check(width >= 3, "and spread sideways: %d cells wide at the floor" % width)


## A one-cell diagonal gap between two firm blocks is not a hole. Material that poured through it would
## read as leaking, and a pile could drain through a wall it should be resting against.
func _test_a_diagonal_crack_does_not_leak() -> void:
	var grid: TileGrid = _grid()
	grid.set_material(Vector2i(10, 31), FIRM)          # bedrock
	grid.set_material(Vector2i(10, 30), LOOSE)         # a grain resting on it: so the one above MAY slide
	grid.set_material(Vector2i(10, 29), LOOSE)         # the grain under test
	grid.set_material(Vector2i(9, 29), FIRM)           # both orthogonal neighbours walled...
	grid.set_material(Vector2i(11, 29), FIRM)
	# ...while both diagonals below them are wide open. Only the orthogonal clause holds this grain.
	_check(not grid.is_solid(Vector2i(9, 30)) and not grid.is_solid(Vector2i(11, 30)), "the cracks are open")
	# The blow is one cell down and to the right, so `after_break` wakes (10,29) itself. A wake that does
	# not reach the cell under test makes this whole suite pass on an automaton with no rules at all: the
	# first version of this test woke (10,27) and survived deleting the clause it was written to pin.
	var s: Slump = Slump.new()
	s.after_break(grid, [Vector2i(11, 30)])
	_check(s.pending() > 0, "the blow woke something")
	for _t: int in 40:
		s.settle(grid, _water())
	_check(grid.get_material(Vector2i(10, 29)) == LOOSE, "it stays put: the orthogonal cells are closed")
	_check(_count(grid, LOOSE) == 2, "and nothing was duplicated squeezing through")


## Wet is closed, deliberately (see the header): the water plane's conservation is worth more than silt.
func _test_water_is_a_floor() -> void:
	var grid: TileGrid = _grid()
	var water: WaterPlane = _water()
	grid.set_material(Vector2i(10, 30), FIRM)
	water.set_level(Vector2i(10, 29), WaterPlane.WATER_MAX)
	grid.set_material(Vector2i(10, 27), LOOSE)
	var before: int = water.total_water()
	_run(grid, water, [Vector2i(10, 28)], 30)
	_check(grid.get_material(Vector2i(10, 28)) == LOOSE, "the cell rests on the water's surface")
	_check(water.total_water() == before, "and no water was displaced away: %d" % water.total_water())


## CONSERVATION, fuzzed. A random field of loose and firm cells, stepped hard, never gains or loses one.
func _test_a_step_conserves_every_loose_cell() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	var worst: String = ""
	for trial: int in 40:
		var grid: TileGrid = _grid()
		var wake: Array[Vector2i] = []
		for _i: int in 120:
			var c := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, H - 3))
			grid.set_material(c, LOOSE if rng.randi_range(0, 2) > 0 else FIRM)
			wake.append(c)
		var before: int = _count(grid, LOOSE)
		var s: Slump = Slump.new()
		s.after_break(grid, wake)
		for _t: int in 250:
			s.settle(grid, _water())
			if _count(grid, LOOSE) != before:
				worst = "trial %d: %d loose cells, was %d" % [trial, _count(grid, LOOSE), before]
				break
		if worst != "":
			break
	_check(worst == "", "10,000 steps over 40 random fields never changed the loose count (%s)" % worst)


## DETERMINISM. Same posing, same steps, same world -- read off `TileGrid`'s own signature, so this
## compares the whole grid and not the handful of cells this file thought to look at.
func _test_two_identical_worlds_settle_identically() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var cells: Array[Vector2i] = []
	var mats: Array[StringName] = []
	for _i: int in 200:
		cells.append(Vector2i(rng.randi_range(2, W - 3), rng.randi_range(2, H - 3)))
		mats.append(LOOSE if rng.randi_range(0, 3) > 0 else FIRM)
	var signatures: Array[String] = []
	for run: int in 2:
		var grid: TileGrid = _grid()
		for i: int in cells.size():
			grid.set_material(cells[i], mats[i])
		var s: Slump = Slump.new()
		s.after_break(grid, cells)
		for _t: int in 300:
			s.settle(grid, _water())
		signatures.append(grid.state_signature())
	_check(signatures[0] == signatures[1], "two identical runs end on the same grid signature")


## THE MUTATION GUARD. The automaton is queue-driven: a cell nobody woke does not move, however
## unsupported it is. Without this, every assertion above could pass on an automaton that swept the whole
## world every step -- which is the performance failure `sim/fluid/MODULE.md` calls a hard constraint.
func _test_nothing_moves_until_a_blow_wakes_it() -> void:
	var grid: TileGrid = _grid()
	grid.set_material(Vector2i(40, 20), LOOSE)         # unsupported, and nobody has cut anything
	var s: Slump = Slump.new()
	for _t: int in 50:
		s.settle(grid, _water())
	_check(grid.get_material(Vector2i(40, 20)) == LOOSE, "an unwoken cell hangs: the queue is the active set")
	_check(s.pending() == 0, "and the queue is empty, not merely slow")
	s.after_break(grid, [Vector2i(40, 21)])
	_check(s.pending() > 0, "a blow beneath it wakes it")
	s.settle(grid, _water())
	_check(grid.get_material(Vector2i(40, 21)) == LOOSE, "and then it falls")


## WHAT THE VIEW IS HANDED (D0564): `moved_this_tick` is the cells that EMPTIED, and `moved_material` is
## what left them, so `SeatEffects._slump` can puff dust of the right colour at the right place. Pinned
## because a dust cloud at the wrong cell, or in the wrong colour, is a defect nobody would ever see in a
## failing assertion -- it would just look slightly wrong forever.
func _test_the_view_is_told_what_moved_and_what_it_was() -> void:
	var grid: TileGrid = _grid()
	var water: WaterPlane = _water()
	for x: int in range(6, 15):
		grid.set_material(Vector2i(x, 30), FIRM)
	grid.set_material(Vector2i(10, 25), LOOSE)
	var s: Slump = Slump.new()
	_check(s.moved_material == &"", "nothing has moved yet, so no material is claimed")
	s.after_break(grid, [Vector2i(10, 26)])
	s.settle(grid, water)
	_check(s.moved_this_tick.size() == 1 and s.moved_this_tick[0] == Vector2i(10, 25),
		"the reported cell is the one that EMPTIED, not the one that filled: %s" % [s.moved_this_tick])
	_check(s.moved_material == LOOSE, "and the material is what left it: %s" % s.moved_material)
	_check(not grid.is_solid(Vector2i(10, 25)), "the reported cell really is empty now")
	s.settle(grid, water)
	_check(s.moved_this_tick.size() == 1 and s.moved_this_tick[0] == Vector2i(10, 26),
		"the list is THIS step's, not cumulative: %s" % [s.moved_this_tick])
	for _t: int in 20:
		s.settle(grid, water)
	_check(s.moved_this_tick.is_empty(), "and it empties when the collapse is over, so the dust stops")
