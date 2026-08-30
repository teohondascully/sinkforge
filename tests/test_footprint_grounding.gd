extends "res://tests/test_base.gd"

## D0206. Both of this module's grounding paths must place the body's feet using the SAME quantity --
## the highest solid top face across every column the box occupies -- and neither may commit a position
## the bounds/overlap invariants would reject.
##
## The two defects this pins, measured across the director's two recorded sessions (184 bad ticks total):
##
##   * `resolve_floor` sampled the ground plane at three interpolated points of a FOUR-column footprint
##     and rested the box on the blend. A blend between two columns of different heights is by
##     definition below the taller one's face, so the feet sank into it (13 ticks); and because
##     `Heightfield.surface_y_at_x` anchors its blend on column CENTRES, a foot sample near the box's
##     edge mixes in the neighbouring column OUTSIDE the footprint, which where that neighbour is taller
##     lifted the body ABOVE its real floor and pushed its head into the world ceiling (10 ticks).
##
##   * `grid_floor_backstop` then read that ceiling as "the topmost solid row in the box" and placed the
##     FEET on top of it. For the world's own ceiling row that face is y=0, so the whole body went above
##     the world: 153 ticks, one ejection at tick 598 of the 767-tick session and every tick after it.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_footprint_grounding.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
const HALF_H: int = (Body.HEIGHT_PX * Fx.SCALE) / 2


func _initialize() -> void:
	_test_a_tall_column_inside_the_footprint_is_rested_on_not_sunk_into()
	_test_footprint_surface_and_the_three_sample_blend_actually_disagree_here()
	_test_a_floorless_column_does_not_poison_the_footprint()
	_test_flat_ground_is_completely_unchanged()
	_test_the_backstop_never_places_the_body_outside_the_world()
	_test_the_backstop_still_depenetrates_a_body_inside_solid_ground()
	_finish("footprint_grounding")


## Floor at `floor_row` across the whole grid, plus one column raised by a single cell. The raised column
## is the SECOND of the body's four, which is the one the old three-sample rule could only ever see as a
## blend endpoint, never as a height in its own right.
func _stepped_grid(floor_row: int, tall_col: int) -> TileGrid:
	var grid: TileGrid = TileGrid.new(20, floor_row + 5, 1)
	for col: int in range(0, 20):
		for row: int in range(floor_row, floor_row + 3):
			grid.set_material(Vector2i(col, row), &"hardrock")
	grid.set_material(Vector2i(tall_col, floor_row - 1), &"hardrock")
	return grid


func _overlap(grid: TileGrid, body: Body) -> int:
	var n: int = 0
	for col: int in range(Body._px_to_cell(body._left_x()), Body._px_to_cell(body._right_x() - 1) + 1):
		for row: int in range(Body._px_to_cell(body._top_y()), Body._px_to_cell(body._bottom_y() - 1) + 1):
			if grid.in_bounds(Vector2i(col, row)) and grid.is_solid(Vector2i(col, row)):
				n += 1
	return n


## The behavioural case. A body dropped straight down (no horizontal input, so nothing but the ground
## plane decides where it stops) must come to rest ON the one raised cell under its footprint, not 2px
## inside it. Also asserts WHICH path grounded it: D0139 failed by fixing one path and letting the flaw
## reappear through the other, so "no overlap" alone would pass a fix that had merely relocated.
func _test_a_tall_column_inside_the_footprint_is_rested_on_not_sunk_into() -> void:
	var grid: TileGrid = _stepped_grid(13, 3)
	var body: Body = Body.new(Fx.from_int(16), Fx.from_int(24))
	var input: InputFrame = InputFrame.new()
	for _i: int in 120:
		body.tick(input, grid)
	var expected: int = Fx.from_int(12 * CELL) - HALF_H  ## feet on the raised cell's own top face
	print("  [OBSERVED] dropped onto a footprint with one raised column: pos_y=%.3f (expected %.3f) src=%s overlap=%d"
		% [float(body.pos_y) / float(Fx.SCALE), float(expected) / float(Fx.SCALE),
		body.floor_source_this_tick, _overlap(grid, body)])
	_check(body.on_floor, "the body settles rather than falling forever")
	_check(_overlap(grid, body) == 0,
		"and rests with NO part of its box inside rock (overlapping %d cells)" % _overlap(grid, body))
	_check(body.pos_y == expected,
		"resting exactly on the raised cell's top face, not on a blend below it (got %d, want %d)" %
		[body.pos_y, expected])
	_check(body.floor_source_this_tick == &"resolve_floor",
		"and the GROUND PLANE is what grounded it -- not the backstop picking up after it (got %s)" %
		body.floor_source_this_tick)


## The mechanism, isolated from the tick loop: at the exact resting position above, the shared criterion
## and the rule it replaced return DIFFERENT numbers, and the old one is the one inside the rock. Without
## this the behavioural test could pass for reasons unrelated to the change.
func _test_footprint_surface_and_the_three_sample_blend_actually_disagree_here() -> void:
	var grid: TileGrid = _stepped_grid(13, 3)
	var body: Body = Body.new(Fx.from_int(16), Fx.from_int(28))
	var scan_from: int = maxi(0, Body._px_to_cell(body._bottom_y()) - 2)
	var footprint: int = VerticalResolve.footprint_surface_y(body, grid, scan_from)
	var blend: int = mini(mini(
		Heightfield.surface_y_at_x(grid, body._left_x() + Fx.SCALE, scan_from, Body.FLOOR_SCAN_ROWS),
		Heightfield.surface_y_at_x(grid, body._right_x() - Fx.SCALE, scan_from, Body.FLOOR_SCAN_ROWS)),
		Heightfield.surface_y_at_x(grid, body.pos_x, scan_from, Body.FLOOR_SCAN_ROWS))
	print("  [OBSERVED] at the resting position: footprint=%.3f three-sample blend=%.3f"
		% [float(footprint) / float(Fx.SCALE), float(blend) / float(Fx.SCALE)])
	_check(blend > footprint,
		"the rule this replaced really does report a DEEPER surface on this geometry (blend %d vs footprint %d) -- if these were equal the suite would be measuring nothing"
		% [blend, footprint])
	_check(footprint == Fx.from_int(12 * CELL),
		"and the shared criterion returns the raised cell's own face (got %d)" % footprint)


## D0059f's original complaint -- the reason `grid_floor_backstop` was written at all -- answered by the
## new criterion directly: `surface_y_at_x` returns NO_FLOOR whenever EITHER column it straddles lacks
## one, so a wide body over a pit's lip could read "no ground anywhere" while most of its footprint stood
## on real ground. A per-column minimum cannot do that.
func _test_a_floorless_column_does_not_poison_the_footprint() -> void:
	var grid: TileGrid = TileGrid.new(20, 20, 1)
	for col: int in range(0, 20):
		if col == 3:
			continue  ## one column open all the way down
		for row: int in range(13, 16):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(Fx.from_int(16), Fx.from_int(28))
	var scan_from: int = maxi(0, Body._px_to_cell(body._bottom_y()) - 2)
	var got: int = VerticalResolve.footprint_surface_y(body, grid, scan_from)
	print("  [OBSERVED] footprint spanning one floorless column: surface=%.3f (NO_FLOOR would be %d)"
		% [float(got) / float(Fx.SCALE), Heightfield.NO_FLOOR])
	_check(got == Fx.from_int(13 * CELL),
		"the columns that DO have ground decide the surface (got %d, want %d)" % [got, Fx.from_int(13 * CELL)])


## The control that the change is scoped to uneven ground: where every column under the body is the same
## height there is nothing to disagree about, and the two rules must return the identical number.
func _test_flat_ground_is_completely_unchanged() -> void:
	var grid: TileGrid = _flat_grid(13, 20)
	var body: Body = Body.new(Fx.from_int(16), Fx.from_int(24))
	var input: InputFrame = InputFrame.new()
	for _i: int in 120:
		body.tick(input, grid)
	var scan_from: int = maxi(0, Body._px_to_cell(body._bottom_y()) - 2)
	var footprint: int = VerticalResolve.footprint_surface_y(body, grid, scan_from)
	var blend: int = Heightfield.surface_y_at_x(grid, body.pos_x, scan_from, Body.FLOOR_SCAN_ROWS)
	print("  [OBSERVED] flat ground: pos_y=%.3f footprint=%.3f blend=%.3f"
		% [float(body.pos_y) / float(Fx.SCALE), float(footprint) / float(Fx.SCALE),
		float(blend) / float(Fx.SCALE)])
	_check(footprint == blend, "on flat ground the two rules agree exactly (%d vs %d)" % [footprint, blend])
	_check(body.pos_y == Fx.from_int(13 * CELL) - HALF_H,
		"and the body rests on the floor's own face, as it always did (got %d)" % body.pos_y)


## The 153-tick cascade, posed directly. The body's head is inside the world's ceiling row, so the
## topmost solid row anywhere in its box is row 0 -- and placing the FEET on row 0's top face puts the
## entire body above y=0. `is_solid` reads every out-of-bounds cell as OPEN, so the destination is not
## "blocked"; it is simply outside the world, which is why the check has to test bounds and not only
## overlap.
func _test_the_backstop_never_places_the_body_outside_the_world() -> void:
	var grid: TileGrid = TileGrid.new(20, 20, 1)
	for col: int in range(0, 20):
		grid.set_material(Vector2i(col, 0), &"hardrock")  ## the world ceiling (D0199's CEILING_ROWS)
		for row: int in range(15, 20):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(22))
	var before: int = body.pos_y
	_check(body._top_y() < Fx.from_int(CELL),
		"sanity: this body's head really is inside the ceiling row (top_y=%d)" % body._top_y())
	var fired: bool = VerticalResolve.grid_floor_backstop(body, grid)
	print("  [OBSERVED] backstop against a body whose head is in the ceiling: fired=%s pos_y %.3f -> %.3f, top_y=%.3f"
		% [str(fired), float(before) / float(Fx.SCALE), float(body.pos_y) / float(Fx.SCALE),
		float(body._top_y()) / float(Fx.SCALE)])
	_check(body._top_y() >= 0, "the body is not thrown above the world (top_y=%d)" % body._top_y())
	_check(not fired and body.pos_y == before,
		"the backstop declines outright rather than committing a destination it cannot make legal")
	_check(body.floor_source_this_tick == &"",
		"and claims no grounding it did not perform (got %s)" % body.floor_source_this_tick)


## The control for the check above, and the reason it is a DESTINATION test and not a refusal to snap
## upward at all: a body genuinely buried in a solid mass must still be pushed up onto its surface. A
## guard that simply never fired would pass the ceiling test and fail this one.
func _test_the_backstop_still_depenetrates_a_body_inside_solid_ground() -> void:
	var grid: TileGrid = TileGrid.new(20, 30, 1)
	for col: int in range(0, 20):
		for row: int in range(15, 20):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(16 * CELL))
	_check(body._box_blocked(grid, body._left_x(), body._top_y(), body._right_x(), body._bottom_y()),
		"sanity: this body's own box is embedded in solid ground")
	var fired: bool = VerticalResolve.grid_floor_backstop(body, grid)
	print("  [OBSERVED] backstop against a buried body: fired=%s pos_y=%.3f overlap=%d"
		% [str(fired), float(body.pos_y) / float(Fx.SCALE), _overlap(grid, body)])
	_check(fired, "the backstop still fires for the de-penetration case it exists for")
	_check(body.pos_y == Fx.from_int(15 * CELL) - HALF_H,
		"lifting the body onto the mass's own top face (got %d, want %d)" %
		[body.pos_y, Fx.from_int(15 * CELL) - HALF_H])
	_check(_overlap(grid, body) == 0, "with the box now clear of rock (overlapping %d)" % _overlap(grid, body))
	_check(body.floor_source_this_tick == &"grid_floor_backstop",
		"named as its own path (got %s)" % body.floor_source_this_tick)
