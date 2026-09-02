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
	await _test_a_stateful_painter_outlives_the_expression_that_created_it()
	await _test_the_frame_asks_for_walls_exactly_when_a_per_frame_painter_reads_them()
	_finish("world_view")


## D0289, WRITTEN AFTER IT BIT AND ONLY BECAUSE A CAPTURE CAUGHT IT.
##
## `add_painter(CrumblePainter.new().paint)` reads as obviously correct and is not: a `Callable` built
## from a method on a `RefCounted` stores an OBJECT ID and does not keep the object alive, so the painter
## was freed at the end of that expression — before `add_painter` was entered. `PaintLayer._draw` then
## found `not _paint.is_valid()` and returned. **Nothing drew for four commits, and every suite passed**,
## because a suite builds its painter and holds it in a local.
##
## Two assertions, because the fix has two halves: the retaining form must keep the object, and the
## bound-Callable form must FAIL LOUDLY rather than silently binding a corpse.
func _test_a_stateful_painter_outlives_the_expression_that_created_it() -> void:
	var view: WorldView = await _mount()
	var layer: PaintLayer = view.add_stateful_painter(Counter.new(), &"paint")
	_check(layer.painter_is_live(),
		"a stateful painter handed over as an object is still alive after the call that added it")
	# CONTROL, and it is the whole finding: the same painter passed as a bound Callable is ALREADY DEAD.
	# Without this row the one above passes on a Callable that happened to keep anything alive at all.
	var corpse: Callable = Counter.new().paint
	_check(not corpse.is_valid(),
		"CONTROL: the same painter as a bound Callable is already freed -- a Callable does not keep a "
		+ "RefCounted alive, which is the bug this API exists to make impossible")
	# And the bind refuses it rather than drawing nothing in silence.
	var dead: PaintLayer = view.add_painter(corpse)
	_check(not dead.painter_is_live(),
		"binding a dead callable leaves the layer unbound rather than silently painting nothing forever")
	# The painter must actually RUN, not merely be alive: a retained object bound to the wrong method
	# name would satisfy every row above.
	var counter: Counter = Counter.new()
	view.add_stateful_painter(counter, &"paint")
	view.refresh()
	await process_frame
	await process_frame
	_check(counter.calls > 0,
		"and it is actually called by the coordinator (%d draws) -- being alive is not being wired"
		% counter.calls)
	view.queue_free()


## A stateful painter that records being called. Deliberately trivial: this suite is about the LIFETIME,
## and a painter that drew anything would need a mounted canvas to prove it.
class Counter extends RefCounted:
	var calls: int = 0

	func paint(_frame: Frame, _ci: CanvasItem) -> void:
		calls += 1


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
	# D0277 RE-PINS THIS RATCHET RATHER THAN LOOSENING IT. It asserted `anim_time == 0.0` forever, which
	# was Q5's ruling and was correct while nothing animated. The director re-opened it, so the property
	# under test changed -- from "the clock never moves" to "the clock moves, deterministically, and only
	# because a tick was rendered". Deleting the assertion would have been the loosening; this is the same
	# subject at its new value.
	_check(f.anim_time > 0.0,
		"the cosmetic clock advances once a tick has been rendered (anim_time=%f)" % f.anim_time)
	var before: float = f.anim_time
	view.refresh()
	var after: float = view.current_frame().anim_time
	_check(after > before,
		"and a second refresh advances it further (%f -> %f)" % [before, after])
	_check(is_equal_approx(after - before, WorldView.SECONDS_PER_TICK),
		"by exactly one tick's worth -- a wall clock would give an arbitrary delta here, and that is the "
		+ "difference the ruling turned on (%f vs %f)" % [after - before, WorldView.SECONDS_PER_TICK])
	# THE DETERMINISM HALF, which is the reason this is a counter and not `Time.get_ticks_msec()`: the
	# same number of rendered ticks must give the same clock, or two captures of one tick stop being
	# comparable and every screenshot in `docs/QUALITY.md`'s discipline becomes a fresh sample.
	view.reset_anim_clock()
	view.refresh()
	_check(is_equal_approx(view.current_frame().anim_time, before),
		"and resetting then re-rendering reproduces the earlier value exactly (%f vs %f)"
		% [view.current_frame().anim_time, before])
	_check(WorldView.PINNED_ANIM_TIME == 0.0,
		"the pinned value a test poses for a still frame is still available, and is still zero")
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


## THE WALL PLANE IS ASKED FOR ONLY WHEN SOMETHING PER-FRAME STILL READS IT (D0338) — and this asserts it
## THROUGH `WorldView`, not by building an `Envelope` here. That distinction is the whole point: a test
## that poses its own envelope cannot register a wiring error at the call site it bypassed, which is the
## same trap D0326's bake test fell into when it passed its own margin and stayed green while the real
## call site passed zero.
##
## **THE COUPLING THIS PROTECTS IS EASY TO GET WRONG IN THE DANGEROUS DIRECTION.** `WallPainter` normally
## draws from the BAKE's own observation, so the per-frame one need not carry walls — ~18,900 dictionary
## lookups a frame saved. But `bake_static` DECLINES with no render target, which is every headless CI
## run, and then `WallPainter` mounts as an ordinary per-frame layer reading THIS observation. Declining
## unconditionally would make it `push_error` every frame and drop the background plane in exactly the
## configuration the suites run under — a regression that this suite, running headless, is the one thing
## positioned to catch.
func _test_the_frame_asks_for_walls_exactly_when_a_per_frame_painter_reads_them() -> void:
	var view: WorldView = await _mount()
	# No `bake_static` call at all, so `_bake` is null exactly as it is on the declined path.
	view.refresh()
	var obs: Interface.Observation = view.current_frame().obs
	_check(obs.has_walls,
		"with no bake, the per-frame observation carries the wall plane -- WallPainter reads it here")
	_check(not obs.walls.is_empty(),
		"and the plane is really built, not just flagged (%d bytes)" % obs.walls.size())
	# The saving itself: an envelope that declines walls must produce an EMPTY plane, or the flag is
	# cosmetic and the 4.24 ms this change measured would not exist.
	var declined: Interface.Observation = view.observe_declining_walls()
	_check(not declined.has_walls, "an envelope that declines walls says so on the observation")
	_check(declined.walls.is_empty(),
		"and builds nothing -- the saving is real, not a flag over a plane still being filled (%d bytes)"
		% declined.walls.size())
	_check(not declined.materials.is_empty(),
		"CONTROL: the MATERIALS plane is still built, so declining walls dropped one plane and not the "
		+ "observation itself")
