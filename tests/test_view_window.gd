extends "res://tests/test_base.gd"

## D0211. The performance gate, as a COUNT rather than a clock: the work a draw loop does per frame must
## be bounded by the viewport, and must not grow with the body's position or the size of the world.
##
## Why this shape and not a duration assertion, stated once here because it is the reusable part: the
## defect that prompted it was RENDER cost, CI runs headless, and the headless renderer is a dummy that
## does not rasterise (D0190 caught it saving blank PNGs while reporting success) -- so a wall-clock gate
## would have been GREEN through the whole regression. A duration assertion in this repo has separately
## already inverted its own 12% margin under `JOBS=4`. Cells-visited is deterministic, display-free,
## cannot flake, and is the quantity that actually regressed.
##
## The control that makes this a real gate: `_test_the_rule_it_replaced_would_fail_this` re-implements
## the OLD window inline and asserts it blows the bound. Without it this suite would pass just as happily
## against a bound so loose nothing could ever exceed it.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_view_window.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
const VIEWPORT: Vector2 = Vector2(1280, 720)  ## project.godot's own 2D render size
const ZOOM: float = 3.0


func _initialize() -> void:
	_test_the_window_never_exceeds_its_own_stated_bound()
	_test_the_window_does_not_grow_with_body_position()
	_test_the_window_does_not_grow_with_world_size()
	_test_the_rule_it_replaced_would_fail_this()
	_test_the_window_actually_covers_what_is_on_screen()
	_finish("view_window")


func _cells(centre_col: int, grid_w: int, grid_h: int) -> Rect2i:
	return ViewWindow.visible_cells(Vector2(centre_col * CELL, MovementCourse.SURFACE_ROW * CELL),
		VIEWPORT, ZOOM, CELL, grid_w, grid_h)


## The bound itself, swept across the whole course rather than sampled at one flattering position.
func _test_the_window_never_exceeds_its_own_stated_bound() -> void:
	var bound: int = ViewWindow.max_cells(VIEWPORT, ZOOM, CELL)
	var worst: int = 0
	var worst_col: int = -1
	for col: int in range(0, MovementCourse.WIDTH):
		var r: Rect2i = _cells(col, MovementCourse.WIDTH, MovementCourse.GRID_HEIGHT)
		var n: int = r.size.x * r.size.y
		if n > worst:
			worst = n
			worst_col = col
	print("  [OBSERVED] bound %d cells; worst over %d body positions is %d at column %d"
		% [bound, MovementCourse.WIDTH, worst, worst_col])
	_check(worst <= bound, "no camera position visits more than the stated bound (%d against %d)" % [worst, bound])
	_check(worst > 0, "and the window is not empty everywhere, which would satisfy the above vacuously")


## The exact property the old rule broke. `maxi(0, col - 200)` meant the window widened as the body left
## the left edge behind, so the cost at column 8 and at column 400 were different by a factor of two.
func _test_the_window_does_not_grow_with_body_position() -> void:
	var sizes: Array[int] = []
	for col: int in [8, 60, 200, 300, MovementCourse.WIDTH - 8]:
		var r: Rect2i = _cells(col, MovementCourse.WIDTH, MovementCourse.GRID_HEIGHT)
		sizes.append(r.size.x * r.size.y)
	var lo: int = sizes[0]
	var hi: int = sizes[0]
	for n: int in sizes:
		lo = mini(lo, n)
		hi = maxi(hi, n)
	print("  [OBSERVED] cells visited across the course, near both edges and the middle: %s" % str(sizes))
	# Not equality: clamping at the world's own edges legitimately makes the window SMALLER there. What
	# must never happen is the middle costing more than the bound, or the far end costing more than the
	# near end -- which is precisely the shape of the rule this replaced.
	_check(hi <= ViewWindow.max_cells(VIEWPORT, ZOOM, CELL),
		"the largest (%d) is still inside the bound" % hi)
	_check(sizes[sizes.size() - 1] <= sizes[2],
		"and the far end of the world costs no more than the middle (%d against %d) -- the old rule doubled here"
		% [sizes[sizes.size() - 1], sizes[2]])
	_check(lo > 0, "with no position visiting nothing at all")


## A world ten times taller and wider must cost the same, because a camera does not see more of it.
func _test_the_window_does_not_grow_with_world_size() -> void:
	var small: Rect2i = _cells(300, MovementCourse.WIDTH, MovementCourse.GRID_HEIGHT)
	var huge: Rect2i = ViewWindow.visible_cells(
		Vector2(300 * CELL, 400 * CELL), VIEWPORT, ZOOM, CELL, 8000, 4000)
	print("  [OBSERVED] %d x %d world visits %d cells; 8000 x 4000 world visits %d"
		% [MovementCourse.WIDTH, MovementCourse.GRID_HEIGHT, small.size.x * small.size.y,
		huge.size.x * huge.size.y])
	_check(huge.size.x * huge.size.y <= ViewWindow.max_cells(VIEWPORT, ZOOM, CELL),
		"a 32-million-cell world still visits no more than the bound (%d)" % (huge.size.x * huge.size.y))
	_check(huge.size.y <= 4000 / 10, "and does not scan the world's full height (%d rows of 4000)" % huge.size.y)


## THE POSITIVE CONTROL. Re-implements the rule this replaced -- `body_col +/- 200` by the full grid
## height -- and asserts it exceeds the bound. If the bound were set loosely enough for anything to pass,
## this test is what fails.
func _test_the_rule_it_replaced_would_fail_this() -> void:
	var bound: int = ViewWindow.max_cells(VIEWPORT, ZOOM, CELL)
	var old_worst: int = 0
	for col: int in range(0, MovementCourse.WIDTH):
		var lo: int = maxi(0, col - 200)
		var hi: int = mini(MovementCourse.WIDTH, col + 200)
		old_worst = maxi(old_worst, (hi - lo) * MovementCourse.GRID_HEIGHT)
	print("  [OBSERVED] the rule this replaced visits up to %d cells against a bound of %d -- %.1fx over"
		% [old_worst, bound, float(old_worst) / float(bound)])
	_check(old_worst > bound,
		"the OLD +/-200-by-full-height rule really does exceed this bound (%d against %d) -- if it did not, this suite would be gating nothing"
		% [old_worst, bound])


## The bound is only worth having if the window still covers the screen: a rule that drew nothing would
## satisfy every assertion above. Checks the four corners of the visible area are inside the returned rect.
func _test_the_window_actually_covers_what_is_on_screen() -> void:
	var centre: Vector2 = Vector2(300 * CELL, MovementCourse.SURFACE_ROW * CELL)
	var r: Rect2i = ViewWindow.visible_cells(centre, VIEWPORT, ZOOM, CELL,
		MovementCourse.WIDTH, MovementCourse.GRID_HEIGHT)
	var half: Vector2 = (VIEWPORT / ZOOM) * 0.5
	var covered: int = 0
	for dx: float in [-half.x, half.x - 1.0]:
		for dy: float in [-half.y, half.y - 1.0]:
			var cell: Vector2i = Vector2i(int(floor((centre.x + dx) / CELL)), int(floor((centre.y + dy) / CELL)))
			cell.x = clampi(cell.x, 0, MovementCourse.WIDTH - 1)
			cell.y = clampi(cell.y, 0, MovementCourse.GRID_HEIGHT - 1)
			if r.has_point(cell):
				covered += 1
	print("  [OBSERVED] %d of 4 screen corners fall inside the returned window %s" % [covered, str(r)])
	_check(covered == 4, "every corner of the visible area is inside the window (%d of 4)" % covered)
