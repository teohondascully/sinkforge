extends "res://tests/test_base.gd"

## Unit tests for sim/body/body.gd's individual mechanics, isolated from the full acceptance suite
## (tests/test_body_acceptance.gd), which exercises all of them together against the real chamber.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_falls_and_rests_on_flat_floor()
	_test_jump_from_ground_within_2_ticks()
	_test_coyote_time_allows_a_late_jump()
	_test_jump_buffer_allows_an_early_jump()
	_test_auto_step_up_one_tile_ledge()
	_test_ceiling_is_not_treated_as_a_step_up_ledge()
	_test_ground_accel_reaches_top_speed_in_8_ticks()
	_test_variable_jump_cut_on_release()
	_finish("body")


func _flat_grid(floor_row: int, width: int) -> TileGrid:
	var grid: TileGrid = TileGrid.new(width, floor_row + 5, 1)
	for col: int in range(-2, width + 2):
		for row: int in range(floor_row, floor_row + 3):
			grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


func _idle_input() -> InputFrame:
	return InputFrame.new()


func _test_falls_and_rests_on_flat_floor() -> void:
	var grid: TileGrid = _flat_grid(10, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(0))
	for i: int in range(200):
		body.tick(_idle_input(), grid)
	_check(body.on_floor, "a body given 200 ticks to fall settles on the floor")
	_check(body.vel_y == 0, "vel_y is exactly zero at rest (got %d)" % body.vel_y)
	var expected_bottom: int = Fx.from_int(10 * CELL)
	_check(body._bottom_y() == expected_bottom,
		"resting body's feet are exactly at the floor surface (got %d, want %d)" %
		[body._bottom_y(), expected_bottom])


func _test_jump_from_ground_within_2_ticks() -> void:
	var grid: TileGrid = _flat_grid(10, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(0))
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
	# (no floor beyond column 10) and jumps a few ticks after leaving it -- inside COYOTE_TICKS.
	var grid: TileGrid = TileGrid.new(30, 30, 1)
	for col: int in range(0, 11):
		for row: int in range(10, 13):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(9 * CELL * Fx.SCALE + CELL * Fx.SCALE / 2, Fx.from_int(0))
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
	var grid: TileGrid = _flat_grid(10, 20)
	# A few px above the resting height -- close enough that landing happens well inside the 6-tick
	# jump-buffer window, which is the case this mechanic actually exists for ("pressed just before
	# landing"), not an arbitrarily distant fall.
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(10 * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE - 3 * Fx.SCALE)
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
	var grid: TileGrid = TileGrid.new(30, 30, 1)
	for col: int in range(0, 10):
		for row: int in range(11, 14):
			grid.set_material(Vector2i(col, row), &"hardrock")
	for col: int in range(10, 30):
		for row: int in range(10, 14):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(5 * CELL * Fx.SCALE, Fx.from_int(0))
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
	var grid: TileGrid = _flat_grid(10, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(0))
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
	var grid: TileGrid = _flat_grid(10, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(0))
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
