extends "res://tests/test_base.gd"

## D0132: unit tests for `Body.floor_source_this_tick`, the grounding-path telemetry added so a fuzz
## violation's own printed line can name which call ("resolve_floor", "grid_floor_backstop", "try_step")
## last set `on_floor = true` that tick, rather than only its position -- an external audit correctly
## found that same-height alone is correlation, not proof of one mechanism. Purely additive, read-only
## telemetry; changes no grounding behavior (docs/DECISIONS_LEDGER.md D0132).

const CELL: int = Heightfield.TERRAIN_CELL_PX
const TEST_FLOOR_ROW: int = 40
const TEST_SPAWN_ROW: int = Body.HEIGHT_PX / Heightfield.TERRAIN_CELL_PX / 2


func _initialize() -> void:
	_test_falling_body_has_no_floor_source_before_it_lands()
	_test_normal_landing_names_resolve_floor()
	_test_auto_step_up_names_try_step()
	_test_direct_call_to_grid_floor_backstop_names_itself()
	_finish("floor_source_telemetry")


func _idle_input() -> InputFrame:
	return InputFrame.new()


func _test_falling_body_has_no_floor_source_before_it_lands() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	body.tick(_idle_input(), grid)
	_check(not body.on_floor, "sanity: one tick of freefall from spawn is not yet on the floor")
	_check(body.floor_source_this_tick == &"",
		"floor_source_this_tick is empty while airborne -- neither resolver found a floor to set (got %s)" %
		body.floor_source_this_tick)


func _test_normal_landing_names_resolve_floor() -> void:
	var grid: TileGrid = _flat_grid(TEST_FLOOR_ROW, 20)
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(TEST_SPAWN_ROW * CELL))
	for i: int in range(200):
		body.tick(_idle_input(), grid)
	_check(body.on_floor, "sanity: settled on the flat floor after 200 ticks")
	_check(body.floor_source_this_tick == &"resolve_floor",
		"a normal flat-floor landing/rest is named resolve_floor, not silently attributed elsewhere (got %s)" %
		body.floor_source_this_tick)


func _test_auto_step_up_names_try_step() -> void:
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
	_check(body.on_floor, "sanity: settled on the lower shelf before stepping")
	var walk: InputFrame = InputFrame.new()
	walk.move_dir = 1
	var saw_step: bool = false
	for i: int in range(60):
		body.tick(walk, grid)
		if body.stepped_up_this_tick:
			saw_step = true
			_check(body.floor_source_this_tick == &"try_step",
				"the exact tick step-up fires is named try_step (got %s)" % body.floor_source_this_tick)
			break
	_check(saw_step, "sanity: walking into the one-tile ledge actually triggered an auto step-up")


func _test_direct_call_to_grid_floor_backstop_names_itself() -> void:
	# grid_floor_backstop only fires when the body's own box is already blocked (D0059f's pit-lip
	# case) -- reproduced directly, the same way test_body.gd calls `_handle_dig` directly, rather
	# than fighting the ground-plane resolver into producing this specific edge for us.
	var grid: TileGrid = TileGrid.new(20, 30, 1)
	for col: int in range(0, 20):
		for row: int in range(15, 20):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(10 * CELL * Fx.SCALE, Fx.from_int(16 * CELL))
	_check(body._box_blocked(grid, body._left_x(), body._top_y(), body._right_x(), body._bottom_y()),
		"sanity: this body's own box is embedded in solid ground")
	var result: bool = VerticalResolve.grid_floor_backstop(body, grid)
	_check(result, "sanity: grid_floor_backstop actually fired for an embedded box")
	_check(body.floor_source_this_tick == &"grid_floor_backstop",
		"a direct grid_floor_backstop call names itself, not resolve_floor or try_step (got %s)" %
		body.floor_source_this_tick)
