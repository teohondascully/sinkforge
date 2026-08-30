extends "res://tests/test_base.gd"

## `MovementCourse` is a play fixture, so the thing worth asserting is not that it "works" but that its
## shape still poses what it claims to pose. Every section's difficulty is stated relative to what the
## controller can actually do, and a feel constant moving silently would otherwise turn the committing
## gap into a walk and the precision pit into an ordinary jump, with nothing red.
##
## `test_hostile_chamber.gd::_test_cave_geometry_present` is the precedent: a fixture asserts its own
## geometry, because D0201's lesson is that a fixture nobody checks drifts out from under the thing it
## was built for.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_movement_course.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_it_builds_and_the_spawn_is_clear()
	_test_the_catch_floor_is_continuous_so_nothing_traps()
	_test_the_sky_is_open_above_every_section()
	_test_the_committing_gap_is_clearable_at_full_speed()
	_test_the_precision_pit_is_NOT_clearable_so_the_perch_is_mandatory()
	_test_the_perch_is_one_body_wide_with_air_all_round_it()
	_test_the_stairs_add_up_to_the_lift_the_sky_is_sized_from()
	_test_the_perch_can_be_escaped_from_a_standstill()
	_finish("movement_course")


## Runs right from `from_col` and jumps the tick the leading edge reaches `lip_col` — the latest legal
## jump, so the best case. Returns the column the body's trailing edge rests at, or -1 if it never lands.
##
## `from_col` must be SOLID GROUND at `surface_row`, and that is checked rather than assumed: the first
## version of this helper ran a blind 60-tick approach before looking for the lip, which for the
## committing gap started the body in mid-air over the PREVIOUS gap and reported a 26-cell jump as
## unclearable. A run-up that begins by falling measures the fall, and reads as a failure of the thing
## under test.
func _best_case_jump(grid: TileGrid, from_col: int, surface_row: int, lip_col: int) -> int:
	_check(grid.is_solid(Vector2i(from_col, surface_row)),
		"sanity: the run-up for the jump below starts on solid ground at column %d, row %d" % [from_col, surface_row])
	var feet: int = Fx.from_int(surface_row * CELL) - (Body.HEIGHT_PX * Fx.SCALE) / 2
	var body: Body = Body.new(Fx.from_int(from_col * CELL), feet)
	var input: InputFrame = InputFrame.new()
	input.move_dir = 1
	for _i: int in 600:
		input.jump_pressed = Body._px_to_cell(body._right_x() - 1) >= lip_col - 1
		input.jump_held = true
		body.tick(input, grid)
		if input.jump_pressed:
			break
	input.jump_pressed = false
	for _i: int in 300:
		body.tick(input, grid)
		if body.on_floor:
			break
	if not body.on_floor:
		return -1
	return Body._px_to_cell(body._left_x())


func _test_it_builds_and_the_spawn_is_clear() -> void:
	var grid: TileGrid = MovementCourse.build()
	var body: Body = Body.new(MovementCourse.spawn_x(), MovementCourse.spawn_y())
	_check(grid.width == MovementCourse.WIDTH and grid.height == MovementCourse.GRID_HEIGHT,
		"the course builds at its stated size (%dx%d)" % [grid.width, grid.height])
	_check(PropertyChecks.solid_overlap_count(body, grid) == 0,
		"the spawn is not inside rock (overlapping %d cells)" % PropertyChecks.solid_overlap_count(body, grid))
	for _i: int in 60:
		body.tick(InputFrame.new(), grid)
	_check(body.on_floor, "and the body settles on the runway rather than falling")
	_check(Body._px_to_cell(body._bottom_y()) == MovementCourse.SURFACE_ROW,
		"resting on the surface row %d (got %d)" % [MovementCourse.SURFACE_ROW, Body._px_to_cell(body._bottom_y())])


## The property that makes this a playground rather than a puzzle: every column has ground under it, and
## that ground is close enough to jump back out of. A missed jump must always cost time, never the run.
func _test_the_catch_floor_is_continuous_so_nothing_traps() -> void:
	var grid: TileGrid = MovementCourse.build()
	var holes: int = 0
	for col: int in range(0, MovementCourse.WIDTH):
		if not grid.is_solid(Vector2i(col, MovementCourse.CATCH_ROW)):
			holes += 1
	var drop_cells: int = MovementCourse.CATCH_ROW - MovementCourse.SURFACE_ROW
	print("  [OBSERVED] catch floor: %d columns without ground; drop from surface is %d cells"
		% [holes, drop_cells])
	_check(holes == 0, "every one of the %d columns has catch-floor ground under it (%d do not)"
		% [MovementCourse.WIDTH, holes])
	_check(drop_cells < 17,
		"and the drop back up is %d cells, inside the measured 17.9-cell standing jump -- a fall is recoverable without walking to a ramp"
		% drop_cells)


## "Surface" is the whole premise: no jump anywhere on this course may be cut short by a ceiling. Checks
## that no solid cell sits above the highest feature, across the entire width.
func _test_the_sky_is_open_above_every_section() -> void:
	var grid: TileGrid = MovementCourse.build()
	var highest: int = MovementCourse.GRID_HEIGHT
	for col: int in range(0, MovementCourse.WIDTH):
		for row: int in range(0, MovementCourse.GRID_HEIGHT):
			if grid.is_solid(Vector2i(col, row)):
				highest = mini(highest, row)
				break
	var headroom: int = highest * CELL
	# The requirement is the apex PLUS the body's own height: it is the HEAD that leaves the world, not
	# the feet. Derived from the same two constants the course sizes itself from, never re-typed here --
	# the first version of this check asserted `> 71` and passed a course the body jumped straight out of.
	var needed: int = MovementCourse.MEASURED_APEX_PX + Body.HEIGHT_PX
	print("  [OBSERVED] highest solid cell is row %d; clear sky above it is %d px, and a jump from it needs %d"
		% [highest, headroom, needed])
	_check(highest == MovementCourse.PLATEAU_ROW,
		"the plateau is the highest thing on the course (row %d, got %d)" % [MovementCourse.PLATEAU_ROW, highest])
	_check(headroom >= needed,
		"and the sky holds a full jump from it plus the body's own height (%dpx of air against %dpx needed) -- the head is what leaves the world"
		% [headroom, needed])


func _test_the_committing_gap_is_clearable_at_full_speed() -> void:
	var grid: TileGrid = MovementCourse.build()
	var landed: int = _best_case_jump(grid, MovementCourse.GAP_MED_END + 1, MovementCourse.SURFACE_ROW,
		MovementCourse.GAP_COMMIT_START)
	var width: int = MovementCourse.GAP_COMMIT_END - MovementCourse.GAP_COMMIT_START
	print("  [OBSERVED] committing gap is %d cells; a best-case running jump lands at column %d (far lip is %d)"
		% [width, landed, MovementCourse.GAP_COMMIT_END])
	_check(landed >= MovementCourse.GAP_COMMIT_END,
		"the %d-cell committing gap IS clearable at full speed with a late jump (landed at %d, needs %d) -- if this fails the course has a dead end, not a challenge"
		% [width, landed, MovementCourse.GAP_COMMIT_END])


## THE LOAD-BEARING CLAIM, simulated rather than asserted from the constant. The pit is built wider than
## the body can jump so that stopping on the perch is the only way across -- which is what makes it a
## test of arresting speed in the air instead of a test of jump distance. If a feel constant ever makes
## this jumpable, the section silently stops posing its own question.
func _test_the_precision_pit_is_NOT_clearable_so_the_perch_is_mandatory() -> void:
	var grid: TileGrid = MovementCourse.build()
	var landed: int = _best_case_jump(grid, MovementCourse.STAIRS_END + 1, MovementCourse.PLATEAU_ROW,
		MovementCourse.PIT_START)
	print("  [OBSERVED] precision pit is %d cells; a best-case running jump reaches column %d (far lip is %d)"
		% [MovementCourse.PIT_WIDTH, landed, MovementCourse.PIT_END])
	_check(landed < MovementCourse.PIT_END,
		"a best-case full-speed jump does NOT reach the far lip (landed %d, lip %d) -- the perch is mandatory"
		% [landed, MovementCourse.PIT_END])
	_check(landed >= MovementCourse.PERCH_START,
		"but it DOES carry far enough to reach the perch (landed %d, perch starts %d) -- otherwise the section is impassable, not demanding"
		% [landed, MovementCourse.PERCH_START])


func _test_the_perch_is_one_body_wide_with_air_all_round_it() -> void:
	var grid: TileGrid = MovementCourse.build()
	var w: int = MovementCourse.PERCH_END - MovementCourse.PERCH_START
	_check(w == Body.WIDTH_PX / CELL,
		"the perch is exactly the body's own width (%d cells against %d)" % [w, Body.WIDTH_PX / CELL])
	var clear: bool = true
	for row: int in range(0, MovementCourse.PERCH_ROW):
		for col: int in range(MovementCourse.PERCH_START - 2, MovementCourse.PERCH_END + 2):
			if grid.is_solid(Vector2i(col, row)):
				clear = false
	_check(clear, "with open air above and to both sides -- it is a floating target, not a step in a wall")
	_check(not grid.is_solid(Vector2i(MovementCourse.PERCH_START, MovementCourse.PERCH_ROW + 6)),
		"and nothing directly under it, so overshooting it is a fall to the catch floor")


## The stairs must add up to the plateau lift the sky is sized from. Two constants that have to agree,
## derived in one place and checked here rather than trusted to stay in step.
func _test_the_stairs_add_up_to_the_lift_the_sky_is_sized_from() -> void:
	_check(MovementCourse.STAIR_COUNT * MovementCourse.STAIR_RISE == MovementCourse.PLATEAU_LIFT,
		"%d steps of %d cells == the %d-cell plateau lift" %
		[MovementCourse.STAIR_COUNT, MovementCourse.STAIR_RISE, MovementCourse.PLATEAU_LIFT])
	_check(MovementCourse.STAIR_RISE * Heightfield.TERRAIN_CELL_PX == Body.STEP_UP_PX,
		"and each step is exactly one auto step-up (%dpx against STEP_UP_PX %d) -- so the flight is walkable at speed"
		% [MovementCourse.STAIR_RISE * Heightfield.TERRAIN_CELL_PX, Body.STEP_UP_PX])
	_check(MovementCourse.PIT_WIDTH > MovementCourse.MEASURED_MAX_GAP_CELLS,
		"and the precision pit (%d cells) is stated wider than the measured maximum jump (%d)" %
		[MovementCourse.PIT_WIDTH, MovementCourse.MEASURED_MAX_GAP_CELLS])


## The escape. Reaching the perch is only half a section: from a standstill on a 4-cell block there is no
## run-up, so the jump to the far lip is made at whatever speed air control alone can build. If this
## cannot be done the pit is a dead end rather than a demand, which is the same failure
## `_test_the_committing_gap_is_clearable_at_full_speed` guards against at the other end of the course.
func _test_the_perch_can_be_escaped_from_a_standstill() -> void:
	var grid: TileGrid = MovementCourse.build()
	var feet: int = Fx.from_int(MovementCourse.PERCH_ROW * CELL) - (Body.HEIGHT_PX * Fx.SCALE) / 2
	var body: Body = Body.new(Fx.from_int(MovementCourse.PERCH_START * CELL + Body.WIDTH_PX / 2), feet)
	var input: InputFrame = InputFrame.new()
	for _i: int in 30:
		body.tick(input, grid)
	_check(body.on_floor and Body._px_to_cell(body._bottom_y()) == MovementCourse.PERCH_ROW,
		"sanity: the body can stand on the perch at all (on_floor=%s, row %d)" %
		[str(body.on_floor), Body._px_to_cell(body._bottom_y())])
	input.move_dir = 1
	input.jump_pressed = true
	input.jump_held = true
	body.tick(input, grid)
	input.jump_pressed = false
	var landed_row: int = -1
	for _i: int in 300:
		body.tick(input, grid)
		if body.on_floor:
			landed_row = Body._px_to_cell(body._bottom_y())
			break
	var col: int = Body._px_to_cell(body._left_x())
	print("  [OBSERVED] standing jump off the perch: lands at column %d, row %d (far lip is column %d, row %d)"
		% [col, landed_row, MovementCourse.PIT_END, MovementCourse.PLATEAU_ROW])
	_check(col >= MovementCourse.PIT_END and landed_row == MovementCourse.PLATEAU_ROW,
		"a standing jump off the perch reaches the far lip -- the section is demanding, not a dead end (landed column %d row %d)"
		% [col, landed_row])
