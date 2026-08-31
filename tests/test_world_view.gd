extends "res://tests/test_base.gd"

## Phase 1 of the coordinator rebuild, D0240. `view/world_view.gd` calls `observe()`, builds one `Frame`,
## and hands it to painters. This suite pins the three properties that make it a coordinator rather than
## a renderer, each chosen because it would be silent to get wrong:
##
##   1. **A painter receives its OWN canvas, not the coordinator.** That is contract §2a and it is the
##      whole reason parallax is possible later. Passing `self` would satisfy every other assertion here.
##   2. **The observation window covers the camera rect, partial cells included.** The tempting `int()`
##      truncation drops the half-visible row at the top and left of the screen -- one undrawn strip,
##      visible only at some camera positions, which reads as flicker rather than as a missing feature.
##   3. **The clock does not advance.** Q5 was ruled "pin it"; a coordinator that quietly grew a time
##      source would be an authored feature nobody asked for.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_world_view.gd

const FLOOR_ROW: int = 20
const GRID_W: int = 60
const GRID_H: int = 40


func _initialize() -> void:
	await _test_a_painter_gets_the_frame_and_its_own_canvas()
	_test_the_window_covers_partial_cells_rather_than_truncating()
	await _test_the_frame_carries_the_ruled_contract()
	_finish("world_view")


func _build_iface() -> Interface:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 1)
	for col: int in range(0, GRID_W):
		for row: int in range(FLOOR_ROW, GRID_H):
			grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(
		Fx.from_int(GRID_W * Heightfield.TERRAIN_CELL_PX / 2),
		Fx.from_int(FLOOR_ROW * Heightfield.TERRAIN_CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2)
	return Interface.new(grid, body, Mining.new())


## Mounted under `root` AND given a process frame, because a node is not really in the tree until one
## has passed: `get_viewport()` returns null before that, `view_world_rect()` returns `Rect2()`, and the
## observation window collapses to nothing but its own margin.
##
## That is not a hypothetical. The first version of this suite did not await, and
## `_test_the_frame_carries_the_ruled_contract` asserted the window was "non-empty" -- which PASSED, over
## a 4x4 window that was **entirely `WINDOW_MARGIN_CELLS`**, with the real rect at zero. An assertion
## about seeing a viewport, passing on having seen no viewport. The width check below is what makes the
## difference legible now.
func _mount() -> WorldView:
	var view: WorldView = WorldView.new()
	var camera: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(camera)
	view.setup(_build_iface(), MaterialLook.new(), camera)
	await process_frame
	return view


func _test_a_painter_gets_the_frame_and_its_own_canvas() -> void:
	var view: WorldView = await _mount()
	var seen: Array = []
	var layer: PaintLayer = view.add_painter(
		func(f: Frame, ci: CanvasItem) -> void: seen.append([f, ci]))
	view.refresh()
	# A REAL redraw pass, not a direct `layer._draw()` call. This suite's painter is a stub that draws
	# nothing, so the direct call worked -- but Godot refuses `draw_*` outside the draw notification, and
	# it refuses as an engine-level ERROR that neither stops execution nor changes the exit code. The
	# first `test_sky_painter` reproduced exactly that with a painter that DOES draw: eight errors, and
	# still "ALL PASS". Fixed here too so the idiom is not copied out of this file (D0244).
	for _i: int in 3:
		await process_frame
	_check(seen.size() == 1, "the painter slot dispatched exactly once (got %d)" % seen.size())
	_check(seen[0][0] == view.current_frame(),
		"the painter is handed the coordinator's current frame, not a copy of it")
	_check(seen[0][1] == layer and seen[0][1] != view,
		"DISCRIMINATOR: the painter draws onto its OWN PaintLayer, not onto the coordinator -- "
		+ "passing `self` here would satisfy every other check in this suite")
	_check(layer.get_parent() == view, "and that layer is a child of the coordinator, so it is in the tree")
	view.queue_free()


## The boundary case, posed against the wrong implementation rather than only the right one.
##
## Cell size is 4px. A rect from x=2 to x=10 touches cells 0, 1 and 2 -- cell 0 partially (px 0-4) and
## cell 2 partially (px 8-12). `floor`/`ceil` returns all three. `int()` truncation returns 0 and 1, and
## the assertion below states the wrong answer explicitly so a reader can see what is being excluded.
func _test_the_window_covers_partial_cells_rather_than_truncating() -> void:
	var cell: int = Heightfield.TERRAIN_CELL_PX
	var rect := Rect2(Vector2(2.0, 2.0), Vector2(8.0, 8.0))  ## x,y from 2 to 10
	var env: Interface.Envelope = Interface.Envelope.covering(rect, 0)
	_check(env.window.position == Vector2i(0, 0),
		"the near edge floors to the cell containing it (got %s)" % env.window.position)
	_check(env.window.end == Vector2i(3, 3),
		"the far edge ceils to include the partially covered cell: got end=%s, want (3,3) -- "
		% env.window.end + "int() truncation would give (2,2) and drop a visible strip")
	_check(env.window.has_point(Vector2i(2, 2)),
		"so the partially visible cell at (2,2) IS in the window")
	var margined: Interface.Envelope = Interface.Envelope.covering(rect, 2)
	_check(margined.window.position == Vector2i(-2, -2)
			and margined.window.size == env.window.size + Vector2i(4, 4),
		"and the margin grows it on every side (got pos=%s size=%s)"
		% [margined.window.position, margined.window.size])
	_check(cell == 4, "control: this test's arithmetic assumes a 4px terrain cell, and it is %d" % cell)


func _test_the_frame_carries_the_ruled_contract() -> void:
	var view: WorldView = await _mount()
	view.refresh()
	var f: Frame = view.current_frame()
	_check(f != null and f.obs != null, "refresh() builds a frame carrying a real observation")
	_check(f.look != null, "the palette is on the frame, so a painter never constructs one")
	_check(f.marks.is_empty(),
		"marks is empty in this build -- no objectives and no build ghost exist to clear stars for")
	_check(f.anim_time == WorldView.ANIM_TIME and WorldView.ANIM_TIME == 0.0,
		"the cosmetic clock is pinned (Q5 ruled): anim_time=%f" % f.anim_time)
	var before: float = f.anim_time
	view.refresh()
	_check(view.current_frame().anim_time == before,
		"and a second refresh does not advance it -- there is no time source to advance")
	## Wider than the margin ALONE, which is the assertion the first draft of this suite failed to make:
	## `size > 0` is true of a window that is nothing but margin over a zero-sized viewport.
	##
	## Deliberately NOT `_check_over` (D0245), though this suite is one of the four that motivated it. The
	## thing that was empty here is a RECT, not a population -- there is no count to range over, and the
	## guard says so itself. The remedy for a scalar is a floor derived from what the scalar would read
	## with the subject removed, which is exactly what `margin_only` is.
	var margin_only: int = 2 * WorldView.WINDOW_MARGIN_CELLS
	_check(f.obs.window.size.x > margin_only and f.obs.window.size.y > margin_only,
		"the window is wider than its own margin (%s vs %d), so a real viewport rect reached it"
		% [f.obs.window.size, margin_only])
	_check(view.view_world_rect().size.x > 0.0,
		"control: the camera rect itself is non-zero (%s)" % view.view_world_rect().size)
	view.queue_free()
