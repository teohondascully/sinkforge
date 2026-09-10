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
	_test_a_grain_does_not_fall_through_an_already_queued_cell()
	_test_a_grain_the_body_blocks_is_not_forgotten()
	_test_an_overflowing_wake_is_deferred_not_dropped()
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


## REST, AND THE CONTROL THAT MAKES IT A MEASUREMENT (A6). This test used to wake (11,29), whose
## neighbourhood is row 28 -- three rows of cells that are not the subject. The subject at (10,29) was
## never queued, so "it did not move" was true of a cell the automaton never looked at, and deleting the
## rest clause outright left the assertion green. That is this repo's house failure class and it is the
## second time this file has produced it.
##
## Two things fix it. The wake now goes through (10,30), whose neighbourhood contains the subject. And
## the control travels inside the measurement: the SAME pose and the SAME wake with a LOOSE floor
## instead of a firm one must move. If the wake ever stops reaching the subject, the control goes red
## and says so, which is the thing a bare "it stayed put" can never do.
func _test_a_supported_cell_never_moves() -> void:
	var grid: TileGrid = _grid()
	grid.set_material(Vector2i(10, 30), FIRM)
	grid.set_material(Vector2i(10, 29), LOOSE)
	_run(grid, _water(), [Vector2i(10, 30)], 20)
	_check(grid.get_material(Vector2i(10, 29)) == LOOSE, "a cell resting on rock stays where it is")

	var control: TileGrid = _grid()
	control.set_material(Vector2i(10, 30), LOOSE)      # the only difference: the floor is loose too
	control.set_material(Vector2i(10, 29), LOOSE)
	_run(control, _water(), [Vector2i(10, 30)], 20)
	_check(control.get_material(Vector2i(10, 29)) != LOOSE,
			"CONTROL: the identical wake DOES reach (10,29) -- with a loose floor beneath it the cell "
			+ "leaves. The rest above is a refusal the automaton made, not a cell it never examined.")


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
## A1 -- A GRAIN MOVES ONE CELL A STEP EVEN WHEN ITS DESTINATION WAS ALREADY QUEUED.
##
## Reproduced by Astra on `c52d6baf`. `_next` defers the destinations of moves made this step, which is
## why the simple version of this test passes: pose one grain, wake it, and nothing else is in the queue
## to collide with. The hole is a destination queued BEFORE the step began, which overlapping wake
## neighbourhoods produce constantly -- `after_break` wakes three cells per break and `_move` three more
## per move, so in any real collapse the cell below a grain is usually already waiting.
##
## The pose is exact about queue ORDER, because the bug needs the destination to be popped AFTER its
## occupant. `after_break` wakes `c+UP`, `c+UP+LEFT`, `c+UP+RIGHT` in that order per cell, so breaking
## (10,26) then (10,27) queues [(10,25),(9,25),(11,25),(10,26),(9,26),(11,26)] -- the grain first, its
## destination fourth. Reverse those two breaks and the bug does not fire, which is exactly why one
## grain and one wake never caught it.
func _test_a_grain_does_not_fall_through_an_already_queued_cell() -> void:
	var grid: TileGrid = _grid()
	grid.set_material(Vector2i(10, 30), FIRM)
	grid.set_material(Vector2i(10, 25), LOOSE)
	var s: Slump = Slump.new()
	s.after_break(grid, [Vector2i(10, 26), Vector2i(10, 27)])
	_check(s.pending() == 6,
			"CONTROL: the two breaks queued six cells (%d) -- the grain at (10,25) AND its destination "
			% s.pending() + "(10,26). With the destination unqueued this test cannot fail.")

	s.settle(grid, _water())
	_check(grid.get_material(Vector2i(10, 26)) == LOOSE,
			"one step, one cell: the grain is at (10,26)")
	_check(grid.get_material(Vector2i(10, 27)) == "",
			"and NOT at (10,27). It was popped as an occupant, then again as a destination, and fell "
			+ "twice on one step's budget.")
	_check(s.moved_this_tick.size() == 1,
			"the step's own account agrees: %d cell(s) moved, not two" % s.moved_this_tick.size())
	_check(_count(grid, LOOSE) == 1, "and there is still exactly one grain")


## A2 -- EARTH HELD UP BY THE BODY IS WAITING, NOT RESTING.
##
## Also reproduced by Astra. `target` answers "stay" for two unlike reasons and `settle` treated them the
## same: rock beneath you is permanent and the cell should leave the queue, but the body's cell box moves
## on its own and wakes nothing when it does. Block a grain with the rect, walk the body away, and the
## grain hung forever over open air with an empty queue. Water is the same shape -- it drains.
##
## The bounded-queue assertion is not decoration. The fix requeues the refused cell every step, so the
## obvious way to get it wrong is a queue that grows by one a tick for as long as a player stands still.
func _test_a_grain_the_body_blocks_is_not_forgotten() -> void:
	var grid: TileGrid = _grid()
	grid.set_material(Vector2i(10, 30), FIRM)
	grid.set_material(Vector2i(10, 25), LOOSE)
	var water: WaterPlane = _water()
	var standing := Rect2i(10, 26, 1, 1)              # the body, exactly under the grain
	var s: Slump = Slump.new()
	s.after_break(grid, [Vector2i(10, 26)])
	for _i: int in 20:
		s.settle(grid, water, standing)
	_check(grid.get_material(Vector2i(10, 25)) == LOOSE,
			"twenty steps and the earth has not fallen on the player (D0566 still holds)")
	_check(s.pending() > 0,
			"...and the grain is STILL OWED A LOOK. This is the assertion Astra's repro needed: at rest "
			+ "it would be dropped, and nothing would ever wake it again.")
	_check(s.pending() <= 3,
			"the requeue is bounded, not a leak: %d cell(s) pending after twenty blocked steps"
			% s.pending())

	s.settle(grid, water)                            # the body walks away
	_check(grid.get_material(Vector2i(10, 26)) == LOOSE,
			"the step after the body leaves, the earth comes down -- with no new blow to wake it")
	_check(_count(grid, LOOSE) == 1, "and nothing was duplicated waiting")


## A3 -- A WAKE PAST THE QUEUE'S BOUND IS LATE, NOT LOST, AND THE ONE REMAINING LOSS IS COUNTED.
##
## `QUEUE_CAP` used to make `_wake` a plain no-op, so a collapse wider than the cap silently shed cells
## and the world stopped part-way with nothing anywhere recording why. Two halves, because the contract
## has two halves: a burst between the cap and twice the cap is fully deferred, and a burst past twice
## the cap is refused with a witness. Both are asserted so that neither can quietly become the other.
##
## ITS OWN, LARGER WORLD, and the control is why: the shared 64x48 grid holds 3072 cells, so a burst
## over every one of them tops out at 3008 unique wakes and CANNOT reach a 4096 cap. The first version
## of this test posed nothing and its control said so before the assertion could lie.
func _test_an_overflowing_wake_is_deferred_not_dropped() -> void:
	var big_w: int = 160
	var big_h: int = 120
	var deferred: Slump = Slump.new()
	var grid: TileGrid = TileGrid.new(big_w, big_h, 7)
	deferred.after_break(grid, _rows(big_w, 1, 39))          # ~6080 cells: over one bound, under two
	_check(deferred.pending() > Slump.QUEUE_CAP,
			"CONTROL: the burst really did overflow the LIVE queue -- %d pending against a cap of %d"
			% [deferred.pending(), Slump.QUEUE_CAP])
	_check(deferred.refused_wakes == 0,
			"and not one wake was refused (%d): the overflow went to the spill, which is a defer"
			% deferred.refused_wakes)

	var flooded: Slump = Slump.new()
	flooded.after_break(grid, _rows(big_w, 1, big_h))         # ~19040 cells: past both bounds
	_check(flooded.refused_wakes > 0,
			"past BOTH bounds a wake is refused -- and it is counted (%d), which is the whole "
			% flooded.refused_wakes + "difference from the silent version. A stated limit, not a "
			+ "solved problem; see the constant's header for what would actually fix it.")
	_check(flooded.pending() >= Slump.QUEUE_CAP,
			"the cells it did keep are still owed a look: %d pending" % flooded.pending())


## Every cell in rows [from, to) of a `w`-wide world, as a break list.
func _rows(w: int, from: int, to: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y: int in range(from, to):
		for x: int in w:
			cells.append(Vector2i(x, y))
	return cells

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
