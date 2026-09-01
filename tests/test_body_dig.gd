extends "res://tests/test_base.gd"

## The DIG half of `sim/body/body.gd`'s unit tests -- which cell a press targets, which rows it clears,
## what it reports, and what it leaves alone. Split out of `tests/test_body.gd` at D0269, which had
## reached 398 of QUALITY gate 4's 400-line cap with no room for P022's headroom assertion. The seam is
## real and not merely convenient: every test here poses a `dig_pressed` input and reads the GRID
## afterwards, while the movement half poses motion and reads the BODY. They share only the fixture.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_body_dig.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX

## Both carried over from `tests/test_body.gd` unchanged, with their D0055 reasoning: at floor_row 10 a
## resting body's top edge sat exactly on row 0 and `_enforce_grid_bounds` zeroed vel_y on any jump; and
## `HEIGHT_PX/CELL/2` is the shallowest spawn row whose fresh body's top is not already past row 0.
const TEST_FLOOR_ROW: int = 40
const TEST_SPAWN_ROW: int = Body.HEIGHT_PX / Heightfield.TERRAIN_CELL_PX / 2


func _initialize() -> void:
	_test_dig_excavates_the_adjacent_cell_in_facing_direction()
	_test_dig_against_air_is_not_an_event()
	_test_dig_respects_facing_left()
	_test_dig_clears_the_whole_body_height_column()
	_test_dig_reports_glimmer_over_other_material_in_the_same_column()
	_test_dig_out_of_bounds_is_not_an_event()
	_test_dig_gap_between_two_touches_in_the_same_column_is_closed()
	_finish("body_dig")


func _idle_input() -> InputFrame:
	return InputFrame.new()


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
## the contract, then checks the cleared range matches that contract exactly -- not more (would eat into
## terrain the mechanic has no business touching), not less (the original bug).
##
## D0269 (P022) widened the contract UPWARD by `Heightfield.DIG_HEADROOM_CELLS`, and both boundaries here
## are DERIVED from that constant rather than written as literals.
##
## BE PRECISE ABOUT WHAT THAT BUYS, because the first draft of this comment claimed more and the mutation
## run refuted it. Deriving the boundary means this test moves WITH the constant, so it cannot see the
## constant being wrong: at a headroom of 0, of 1, of 2 or of 4 it is green every time, since it recomputes
## its own expectation from whatever the constant says. What it catches is `body.gd` disagreeing with the
## constant -- dropping the term, applying one cell too few, applying one too many -- all three measured
## red. Whether the constant is BIG ENOUGH is a different property with a different subject, and it is
## asserted in `tests/test_miner_look.gd`, the only place that can see the sprite's overhang too.
##
## The literals this replaced (`top-3/-4/-5`) were worse than either: a headroom of 0, 1 and 2 all satisfy
## them, and so does a `body.gd` that ignores the constant entirely.
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
	var headroom: int = Heightfield.DIG_HEADROOM_CELLS
	var top_row: int = Body._px_to_cell(body._top_y()) - headroom
	var bottom_row: int = Body._px_to_cell(body._bottom_y() - 1)
	var cleared_violations: int = 0
	for row: int in range(top_row, bottom_row + 1):
		if grid.is_solid(Vector2i(target_col, row)):
			cleared_violations += 1
	# `top_row - 1` is the tight boundary: the first row the contract says must survive. The lower probes
	# stay loose because nothing has ever proposed digging DOWNWARD past the feet, so there is no constant
	# to track there.
	var untouched_violations: int = 0
	for row: int in [top_row - 1, top_row - 2, bottom_row + 3, bottom_row + 4, bottom_row + 5]:
		if not grid.is_solid(Vector2i(target_col, row)):
			untouched_violations += 1
	_check(cleared_violations == 0,
		"the body's span plus its %d cells of headroom is cleared (%d row(s) still solid)"
		% [headroom, cleared_violations])
	_check(untouched_violations == 0,
		"the row immediately above that headroom is left alone (%d dug that shouldn't have been)"
		% untouched_violations)


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
