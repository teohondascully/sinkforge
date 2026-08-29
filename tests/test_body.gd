extends "res://tests/test_base.gd"

## Unit tests for sim/body/body.gd's individual mechanics, isolated from the full acceptance suite
## (tests/test_body_acceptance.gd), which exercises all of them together against the real chamber.

const CELL: int = Heightfield.TERRAIN_CELL_PX

## D0055: raised from 10. `body.gd::_enforce_grid_bounds()` (the bounds invariant's own fix) now
## refuses to let the body's box cross row 0; at floor_row=10 a resting body's own TOP edge sat at
## EXACTLY row 0 (10 - HEIGHT_PX/CELL/2 x2 = 0), so any jump at all -- even one cut short after a
## single tick -- immediately tripped the new guard and zeroed vel_y before
## `_test_variable_jump_cut_on_release` ever saw its own cut math take effect. 40 leaves 30 rows of
## real headroom above the resting top, comfortably past a full held jump's measured ~18-cell apex.
const TEST_FLOOR_ROW: int = 40

## D0055: replaces `Fx.from_int(0)` as this file's "start high, fall and settle" spawn row.
## `Body.HEIGHT_PX/CELL/2` (5) is the shallowest row whose body's own TOP edge is not already past
## row 0 before it ever takes a single tick -- spawning at row 0 put a fresh body's top at row -5,
## tripping `_enforce_grid_bounds` immediately on every affected test even though nothing was
## actually wrong; correct (rate-limited, non-fatal) but pure noise in an otherwise-clean run.
const TEST_SPAWN_ROW: int = Body.HEIGHT_PX / Heightfield.TERRAIN_CELL_PX / 2


func _initialize() -> void:
	_test_falls_and_rests_on_flat_floor()
	_test_jump_from_ground_within_2_ticks()
	_test_coyote_time_allows_a_late_jump()
	_test_jump_buffer_allows_an_early_jump()
	_test_auto_step_up_one_tile_ledge()
	_test_ceiling_is_not_treated_as_a_step_up_ledge()
	_test_ground_accel_reaches_top_speed_in_8_ticks()
	_test_variable_jump_cut_on_release()
	_test_dig_excavates_the_adjacent_cell_in_facing_direction()
	_test_dig_against_air_is_not_an_event()
	_test_dig_respects_facing_left()
	_test_dig_clears_the_whole_body_height_column()
	_test_dig_reports_glimmer_over_other_material_in_the_same_column()
	_test_dig_out_of_bounds_is_not_an_event()
	_test_dig_gap_between_two_touches_in_the_same_column_is_closed()
	_finish("body")


func _idle_input() -> InputFrame:
	return InputFrame.new()


func _test_falls_and_rests_on_flat_floor() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(200):
		body.tick(_idle_input(), grid)
	_check(body.on_floor, "a body given 200 ticks to fall settles on the floor")
	_check(body.vel_y == 0, "vel_y is exactly zero at rest (got %d)" % body.vel_y)
	var expected_bottom: int = Fx.from_int(TEST_FLOOR_ROW * CELL)
	_check(body._bottom_y() == expected_bottom,
		"resting body's feet are exactly at the floor surface (got %d, want %d)" %
		[body._bottom_y(), expected_bottom])


func _test_jump_from_ground_within_2_ticks() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)
	_check(body.on_floor, "settled before the jump test begins")
	var jump: InputFrame = InputFrame.new()
	jump.jump_pressed = true
	jump.jump_held = true
	var left_floor_at: int = -1
	for tick_i: int in range(2):
		body.tick(jump if tick_i == 0 else _idle_input(), grid)
		if not body.on_floor:
			left_floor_at = tick_i
			break
	_check(left_floor_at >= 0 and left_floor_at <= 1,
		"jump leaves the floor within 2 ticks of the press (left at tick %d)" % left_floor_at)
	_check(body.vel_y < 0, "vel_y is negative (rising) right after the jump (got %d)" % body.vel_y)


func _test_coyote_time_allows_a_late_jump() -> void:
	# Body starts exactly at the floor, already resting, then walks off the edge of a one-column shelf
	# (no floor beyond column 10) and jumps a few ticks after leaving it -- inside COYOTE_TICKS. Floor
	# row matches TEST_FLOOR_ROW's own D0055 reasoning above (this test builds its own grid rather
	# than using `_flat_grid`, since it also needs the shelf to end at a specific column).
	var grid: TileGrid = TileGrid.new(30, TEST_FLOOR_ROW + 5, 1)
	for col: int in range(0, 11):
		for row: int in range(TEST_FLOOR_ROW, TEST_FLOOR_ROW + 3):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(9 * CELL * Fx.SCALE + CELL * Fx.SCALE / 2, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)
	_check(body.on_floor, "settled on the shelf before walking off it")
	var walk: InputFrame = InputFrame.new()
	walk.move_dir = 1
	var left_shelf: bool = false
	for i: int in range(120):
		body.tick(walk, grid)
		if not body.on_floor:
			left_shelf = true
			break  # jump on the very next tick, well inside COYOTE_TICKS
	_check(left_shelf, "body left the shelf (airborne) after walking past its edge")
	var jump: InputFrame = InputFrame.new()
	jump.jump_pressed = true
	jump.jump_held = true
	body.tick(jump, grid)
	_check(body.vel_y < 0, "a jump pressed just after leaving the edge still fires (coyote time)")


func _test_jump_buffer_allows_an_early_jump() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	# A few px above the resting height -- close enough that landing happens well inside the 6-tick
	# jump-buffer window, which is the case this mechanic actually exists for ("pressed just before
	# landing"), not an arbitrarily distant fall.
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(TEST_FLOOR_ROW * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE - 3 * Fx.SCALE)
	var jump: InputFrame = InputFrame.new()
	jump.jump_pressed = true
	jump.jump_held = true
	body.tick(jump, grid)  # press while still airborne, just short of the floor
	var jumped_again: bool = false
	for i: int in range(10):
		body.tick(_idle_input(), grid)
		if body.vel_y < 0:
			jumped_again = true  # landing and the buffered jump fire in the same tick -- on_floor flips
			break                # true then immediately false again, so vel_y is the real signal here
	_check(jumped_again, "a buffered jump fires the tick the body lands (got vel_y=%d)" % body.vel_y)


func _test_auto_step_up_one_tile_ledge() -> void:
	# A one-tile-high step at column 10, with three clear tiles of headroom above it -- exactly the
	# "1 tile, no input, when blocked and the cell above is clear" case from docs/ARCHITECTURE.md §9.
	# Width 100, not 30 (D0055): 120 ticks of held rightward walking can cover ~75 cells at top
	# speed, and `body.gd::_enforce_grid_bounds()` now stops the body dead at the grid's own right
	# edge -- a real, generally-correct behavior that turned this test's own narrow floor into a
	# spurious "left the world" report on a walk this fixture never expected to run that far.
	var grid: TileGrid = TileGrid.new(100, 30, 1)
	for col: int in range(0, 10):
		for row: int in range(11, 14):
			grid.set_material(Vector2i(col, row), &"hardrock")
	for col: int in range(10, 100):
		for row: int in range(10, 14):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(5 * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)
	_check(body.on_floor, "settled on the lower shelf")
	var walk: InputFrame = InputFrame.new()
	walk.move_dir = 1
	var stepped: bool = false
	for i: int in range(120):
		body.tick(walk, grid)
		if body.stepped_up_this_tick:
			stepped = true
		if not stepped and body.edge_caught_this_tick:
			_check(false, "edge_caught fired instead of stepping up a walkable 1-tile ledge")
			return
	_check(stepped, "auto step-up fired while walking into a 1-tile ledge with clear headroom")
	_check(Body._px_to_cell(body.pos_x) > 10, "body actually crossed onto the upper shelf")


func _test_ceiling_is_not_treated_as_a_step_up_ledge() -> void:
	# The exact bug legacy/scenes/player.gd's own history names: a SHALLOW vertical overlap is
	# direction-blind unless the classifier also compares the blocking cell to the body's centre. Ceiling
	# block at row 10 (y = 40..44px); body's top placed at 43px, one pixel into it -- shallow in Y (1px)
	# but wide in X (up to the full 16px body width), exactly the ambiguous shape a ledge exemption and a
	# ceiling clip share. Driving `_resolve_horizontal` directly (not walking in over many ticks) makes
	# the 1px overlap exact and deterministic rather than dependent on where a multi-tick walk happens to
	# land -- the same "sub-cell start phase" dependency that made the original bug invisible to a
	# fixture drawing the same phase every run.
	var grid: TileGrid = TileGrid.new(30, 20, 1)
	grid.set_material(Vector2i(12, 10), &"hardrock")
	var body: Body = Body.new(Fx.from_int(12 * CELL) - Fx.SCALE, Fx.from_int(43) + Body.HEIGHT_PX / 2 * Fx.SCALE)
	body.vel_x = Body.RUN_SPEED
	var walk: InputFrame = InputFrame.new()
	walk.move_dir = 1
	var before_right: int = body._right_x()
	body._resolve_horizontal(grid, walk)
	var ceiling_left: int = Fx.from_int(12 * CELL)
	_check(body._right_x() <= ceiling_left,
		"a 1px-shallow overlap with a block ABOVE the body's centre still blocks horizontal movement " +
		"(right edge %d, ceiling starts at %d) -- got through means the classifier is direction-blind" %
		[body._right_x(), ceiling_left])
	_check(before_right != body._right_x() or before_right <= ceiling_left,
		"sanity: the body was actually approaching the obstruction, not already clear of it")


func _test_ground_accel_reaches_top_speed_in_8_ticks() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)  # settle first
	var walk: InputFrame = InputFrame.new()
	walk.move_dir = 1
	for i: int in range(Body.GROUND_ACCEL_TICKS):
		body.tick(walk, grid)
	_check(body.vel_x == Body.RUN_SPEED,
		"ground accel reaches exactly top speed in %d ticks (got %d, want %d)" %
		[Body.GROUND_ACCEL_TICKS, body.vel_x, Body.RUN_SPEED])


func _test_variable_jump_cut_on_release() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)
	var jump: InputFrame = InputFrame.new()
	jump.jump_pressed = true
	jump.jump_held = true
	body.tick(jump, grid)
	var v_before_release: int = body.vel_y
	var release: InputFrame = InputFrame.new()
	release.jump_held = false
	body.tick(release, grid)
	# Gravity integrates BEFORE the jump-handling that applies the cut (tick() runs vertical integrate,
	# then resolve, then _handle_jump last, so a buffered jump can see this tick's own landing) -- so the
	# cut multiplies a vel_y that already includes this tick's own gravity, not the reverse.
	var v_with_gravity: int = mini(v_before_release + Body.GRAVITY_PER_TICK, Body.MAX_FALL)
	var want: int = (v_with_gravity * Body.JUMP_CUT_MULT_NUM) / Body.JUMP_CUT_MULT_DEN
	_check(absi(body.vel_y - want) <= 2,
		"releasing jump while rising cuts vel_y toward 40%% (got %d, want ~%d)" % [body.vel_y, want])


## `target`/`left_target`/`right_target` below are computed WITHOUT calling `body._dig_target_cell()` --
## the function under test -- deliberately: an earlier version of this test derived the expected cell
## by calling that same function, which cannot catch a bug IN the function (it would just excavate
## whatever wrong cell the buggy formula named, and every assertion below would still read as passing).
## That's exactly what happened: `_dig_target_cell()` shipped with a real off-by-one (right-facing only,
## `docs/DECISIONS_LEDGER.md` D0112), found only by actually running `tests/body/reveal_scene.gd` and
## watching the body get permanently stuck one cell short of the wall it had just dug past. Independent
## derivation: a body spawned at `spawn_col * CELL` and never given horizontal input occupies exactly
## `[spawn_col - w/2, spawn_col + w/2)` in cell space, `w = Body.WIDTH_PX / CELL` -- plain arithmetic on
## construction parameters this test already knows, not a call into `body.gd` at all.
func _test_dig_excavates_the_adjacent_cell_in_facing_direction() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var spawn_col: int = 10
	var body: Body = Body.new(spawn_col * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)
	_check(body.on_floor, "settled before the dig test begins")
	_check(body.pos_x == spawn_col * CELL * Fx.SCALE,
		"sanity: idle ticks don't drift horizontal position, so the spawn column's geometry stays exact")
	var half_width_cells: int = Body.WIDTH_PX / CELL / 2
	var cy: int = Body._px_to_cell(body.pos_y)
	var target: Vector2i = Vector2i(spawn_col + half_width_cells, cy)
	grid.set_material(target, &"hardrock")
	var dig: InputFrame = InputFrame.new()
	dig.dig_pressed = true
	body.tick(dig, grid)
	_check(body.dig_event_this_tick, "a dig press against a real solid cell fires a dig event")
	_check(body.dug_material_this_tick == &"hardrock",
		"the reported dug material matches what was actually there (got %s)" % body.dug_material_this_tick)
	_check(not grid.is_solid(target), "the target cell is actually excavated after the dig")


func _test_dig_against_air_is_not_an_event() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)
	var target: Vector2i = body._dig_target_cell()
	_check(not grid.is_solid(target), "sanity: the target cell starts as air for this test")
	var dig: InputFrame = InputFrame.new()
	dig.dig_pressed = true
	body.tick(dig, grid)
	_check(not body.dig_event_this_tick, "a dig press against air is not an event")


## Same independent-derivation discipline as the test above -- see its own comment.
func _test_dig_respects_facing_left() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var spawn_col: int = 10
	var body: Body = Body.new(spawn_col * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)
	var half_width_cells: int = Body.WIDTH_PX / CELL / 2
	var cy: int = Body._px_to_cell(body.pos_y)
	var right_target: Vector2i = Vector2i(spawn_col + half_width_cells, cy)
	var left_target: Vector2i = Vector2i(spawn_col - half_width_cells - 1, cy)
	body.facing = -1
	grid.set_material(left_target, &"hardrock")
	grid.set_material(right_target, &"hardrock")
	var dig: InputFrame = InputFrame.new()
	dig.dig_pressed = true
	body.tick(dig, grid)
	_check(not grid.is_solid(left_target), "facing left digs the LEFT-adjacent cell")
	_check(grid.is_solid(right_target), "facing left leaves the right-adjacent cell (the wrong side) untouched")


## Calls `_handle_dig` directly rather than through `tick()`, so the out-of-bounds check under test is
## isolated from `_enforce_grid_bounds`'s own world-edge clamping (which runs earlier in the tick and
## would otherwise fight over what "the body's position" even means near an edge).
func _test_dig_out_of_bounds_is_not_an_event() -> void:
	var grid: TileGrid = TileGrid.new(5, 20, 1)
	var body: Body = Body.new(0, Fx.from_int(TEST_SPAWN_ROW * CELL))
	body.facing = -1
	var target: Vector2i = body._dig_target_cell()
	_check(not grid.in_bounds(target), "sanity: the dig target is off-grid for this fixture (got %s)" % target)
	body._handle_dig(grid)
	_check(not body.dig_event_this_tick, "a dig press off the grid edge is not an event")


## D0113: a dig that only clears the body's own centre row can't be walked through by a body several
## cells tall -- the original mechanic shipped with exactly that bug, undetected because no test checked
## anything past the target cell's own identity. Fills the target column solid across a range WIDER than
## the body's own height, then checks the cleared range matches the body's own span exactly -- not more
## (would eat into terrain the mechanic has no business touching), not less (the original bug).
func _test_dig_clears_the_whole_body_height_column() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var spawn_col: int = 10
	var body: Body = Body.new(spawn_col * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)
	var half_width_cells: int = Body.WIDTH_PX / CELL / 2
	var target_col: int = spawn_col + half_width_cells
	# A rough pre-dig estimate, used only to know how wide a range to seed solid -- generous margin
	# (+/-8) rather than exact, because the dig tick's own vertical resolve can shift the body's position
	# by a row or so (a newly solid adjacent column changing what the sub-pixel heightfield samples),
	# found by actually running this test and seeing a false failure from a stale pre-tick estimate.
	var rough_top: int = Body._px_to_cell(body._top_y())
	var rough_bottom: int = Body._px_to_cell(body._bottom_y() - 1)
	for row: int in range(rough_top - 8, rough_bottom + 9):
		grid.set_material(Vector2i(target_col, row), &"hardrock")
	var dig: InputFrame = InputFrame.new()
	dig.dig_pressed = true
	body.tick(dig, grid)
	# The actual expected range, read AFTER the dig tick -- the same `_top_y()`/`_bottom_y()`/
	# `_px_to_cell()` primitives `_handle_dig` itself uses, but not the dig logic under test, so this
	# isn't tautological about the actual defect class (how many rows, which column) this test exists to
	# catch.
	var top_row: int = Body._px_to_cell(body._top_y())
	var bottom_row: int = Body._px_to_cell(body._bottom_y() - 1)
	var cleared_violations: int = 0
	for row: int in range(top_row, bottom_row + 1):
		if grid.is_solid(Vector2i(target_col, row)):
			cleared_violations += 1
	var untouched_violations: int = 0
	for row: int in [top_row - 3, top_row - 4, top_row - 5, bottom_row + 3, bottom_row + 4, bottom_row + 5]:
		if not grid.is_solid(Vector2i(target_col, row)):
			untouched_violations += 1
	_check(cleared_violations == 0,
		"every row of the body's own height range is cleared (%d still solid)" % cleared_violations)
	_check(untouched_violations == 0,
		"rows well past the body's own height range are left alone (%d dug that shouldn't have been)" % untouched_violations)


func _test_dig_reports_glimmer_over_other_material_in_the_same_column() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var spawn_col: int = 10
	var body: Body = Body.new(spawn_col * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(60):
		body.tick(_idle_input(), grid)
	var half_width_cells: int = Body.WIDTH_PX / CELL / 2
	var target_col: int = spawn_col + half_width_cells
	# Rough pre-dig estimate, generously widened -- see the comment on the test above this one for why
	# not an exact range.
	var rough_top: int = Body._px_to_cell(body._top_y())
	var rough_bottom: int = Body._px_to_cell(body._bottom_y() - 1)
	for row: int in range(rough_top - 8, rough_bottom + 9):
		grid.set_material(Vector2i(target_col, row), &"hardrock")
	# The MIDDLE of the rough range, not an edge -- safely inside the actual post-tick range even if the
	# dig tick's own vertical resolve shifts the body's position by a row or so.
	var glimmer_row: int = (rough_top + rough_bottom) / 2
	grid.set_material(Vector2i(target_col, glimmer_row), &"glimmer")
	var dig: InputFrame = InputFrame.new()
	dig.dig_pressed = true
	body.tick(dig, grid)
	_check(body.dug_material_this_tick == &"glimmer",
		"a column with glimmer anywhere in it reports glimmer, not whichever row happened to be checked first (got %s)" %
		body.dug_material_this_tick)


## D0122/D0123/D0125 end-to-end: two digs to the SAME column at different vertical body positions, never
## occupying the rows between during a dig -- D0123's own reproducing mechanism for the staircase.
func _test_dig_gap_between_two_touches_in_the_same_column_is_closed() -> void:
	var grid: TileGrid = TileGrid.new(20, 100, 1)
	var spawn_col: int = 10
	var body: Body = Body.new(spawn_col * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	var half_width_cells: int = Body.WIDTH_PX / CELL / 2
	var target_col: int = spawn_col + half_width_cells
	for row: int in range(0, 100):
		grid.set_material(Vector2i(target_col, row), &"hardrock")
	body.pos_y = Fx.from_int(10 * CELL)
	body._handle_dig(grid)
	_check(body.dig_event_this_tick, "sanity: first touch fires a dig event")
	var first_top: int = Body._px_to_cell(body._top_y())
	var first_bottom: int = Body._px_to_cell(body._bottom_y() - 1)
	body.pos_y = Fx.from_int(60 * CELL)
	body._handle_dig(grid)
	_check(body.dig_event_this_tick, "sanity: second touch fires a dig event")
	var second_top: int = Body._px_to_cell(body._top_y())
	var second_bottom: int = Body._px_to_cell(body._bottom_y() - 1)
	_check(first_bottom < second_top - 1,
		"sanity: touches leave a real gap before the merge is checked (%d, %d)" % [first_bottom, second_top])
	var gap_violations: int = 0
	for row: int in range(first_top, second_bottom + 1):
		if grid.is_solid(Vector2i(target_col, row)):
			gap_violations += 1
	_check(gap_violations == 0,
		"the full span from first touch's top to second touch's bottom is cleared, no fragment left (%d still solid)" % gap_violations)
