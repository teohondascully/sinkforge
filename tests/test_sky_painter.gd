extends "res://tests/test_base.gd"

## The first painter lifted onto the `Frame` contract, D0244. `view/visuals/sky_painter.gd`.
##
## WHAT THIS SUITE CANNOT DO, said first so no one reads more into a green than is there: it cannot
## judge whether the sky LOOKS RIGHT. That is the director's eye at the ◆, against the milestone capture.
## Everything below is structural.
##
## WHAT IT DOES DO is guard the failure this painter would otherwise fail SILENTLY. Legacy authored the
## sky for a 32px cell; this world has 4px cells, so every world-space length was rescaled. **If that
## rescale were wrong in the wrong direction, the entire starfield would land below the horizon and be
## culled** -- `paint()` would run, draw nothing, crash nothing, and a smoke test would pass over an
## empty sky. That is this project's recurring shape (a test passing because the state is empty), and it
## is why `visible_stars()` is public: the field is asserted NON-EMPTY before anything is asserted about
## it, and its scatter is checked against the lattice legacy's own first version produced.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_sky_painter.gd

## A realistic camera rect: 1280x720 at the reveal scene's default zoom 6.5 is ~197x111 world px, framed
## just above the surface datum so the sky is actually in view.
const VIEW := Rect2(Vector2(0.0, -60.0), Vector2(197.0, 111.0))


func _initialize() -> void:
	_test_the_scale_is_derived_and_self_consistent()
	_test_the_horizon_sits_on_the_surface_datum()
	_test_the_starfield_is_not_empty_and_does_not_lattice()
	await _test_paint_runs_against_a_real_frame_and_canvas()
	_finish("sky_painter")


func _test_the_scale_is_derived_and_self_consistent() -> void:
	_check(is_equal_approx(SkyPainter.SCALE * SkyPainter.INV_SCALE, 1.0),
		"SCALE and INV_SCALE are reciprocal (%f * %f = %f) -- lengths shrink and frequencies grow"
		% [SkyPainter.SCALE, SkyPainter.INV_SCALE, SkyPainter.SCALE * SkyPainter.INV_SCALE])
	## The discriminator: SCALE must be DERIVED from the world's cell size, not a typed-in 0.125. If
	## someone changes the terrain grid, this constant has to move with it or every sky length is wrong.
	_check(is_equal_approx(SkyPainter.SCALE,
			float(Interface.TERRAIN_CELL_PX) / SkyPainter.LEGACY_CELL_PX),
		"SCALE is TERRAIN_CELL_PX / LEGACY_CELL_PX (%d / %f), not a literal"
		% [Interface.TERRAIN_CELL_PX, SkyPainter.LEGACY_CELL_PX])
	_check(SkyPainter.SCALE < 1.0,
		"and it SHRINKS legacy lengths (%f < 1) -- this world's cell is the smaller one"
		% SkyPainter.SCALE)


## The horizon is where the world's surface is, and the world says where that is. Legacy's was
## `SURFACE_LINE(22) * CELL(32)`; asserting 0.0 as a bare literal would restate the constant rather than
## check it, so this checks the DATUM the constant was derived from.
func _test_the_horizon_sits_on_the_surface_datum() -> void:
	_check(MaterialLook.depth_m(0) == 0,
		"the band ladder puts row 0 at depth 0 m (got %d)" % MaterialLook.depth_m(0))
	_check(SkyPainter.HORIZON_Y == float(0 * Interface.TERRAIN_CELL_PX),
		"so the horizon is the world-y of row 0 (%f)" % SkyPainter.HORIZON_Y)
	_check(MaterialLook.depth_m(-4) < 0,
		"control: rows above the datum read as NEGATIVE depth, so 'above the horizon' is a real region")


## The two properties that separate a starfield from nothing, and from a comb.
func _test_the_starfield_is_not_empty_and_does_not_lattice() -> void:
	var grad_top: float = SkyPainter.HORIZON_Y - 420.0 * SkyPainter.SCALE
	var stars: Array = SkyPainter.visible_stars(VIEW, 0.0, grad_top)
	## THE EMPTY-STATE GUARD. Every star is culled if it lands below the horizon; a wrong rescale does
	## exactly that, and nothing else in this file would notice.
	_check(stars.size() > 20,
		"the field is populated: %d of 42 stars survive the horizon cull" % stars.size())
	var above: int = 0
	for s: Dictionary in stars:
		if (s["pos"] as Vector2).y < SkyPainter.HORIZON_Y:
			above += 1
	_check(above == stars.size(),
		"and every one of them is ABOVE the horizon (%d of %d) -- a star under the ground is not a star"
		% [above, stars.size()])
	## THE ANTI-LATTICE CHECK. Legacy's first version used `i * 2654435761`, whose sorted x values had
	## exactly THREE distinct gaps -- the three-distance theorem, reading as a comb of evenly spaced dots
	## rather than a sky. Through `Seams.grain` the same axis went to 38. Rounded to the nearest world
	## pixel so floating noise cannot manufacture distinctness.
	var xs: Array = []
	for s: Dictionary in stars:
		xs.append((s["pos"] as Vector2).x)
	xs.sort()
	var gaps: Dictionary = {}
	for i: int in range(1, xs.size()):
		gaps[roundi(float(xs[i]) - float(xs[i - 1]))] = true
	_check(gaps.size() > 3,
		"the field scatters: %d distinct x-gaps over %d stars (a linear i*K sequence gives 3)"
		% [gaps.size(), stars.size()])


## The smoke test, and it is LAST because it is the weakest. It proves `paint()` runs to completion
## against a real `Frame` and a real in-tree `CanvasItem` -- no missing member, no bad signature, no
## degenerate polygon. It proves nothing about what was drawn, which is what everything above is for.
##
## IT MUST GO THROUGH A REAL REDRAW, not a direct `layer._draw()` call. Godot refuses `draw_*` outside
## the actual draw notification -- "Drawing is only allowed inside this node's `_draw()`" -- and the
## refusal is an engine-level ERROR that does NOT stop execution or change the exit code. The first
## version of this test called `_draw()` directly, printed eight of those, and still reported ALL PASS;
## `tools/run_gd_test.sh` failed it anyway, which is the D0149 masked-crash guard doing its job.
## `tests/test_world_view.gd` calls `_draw()` the same way and gets away with it only because its
## painter is a stub that draws nothing -- a landmine, fixed there too.
func _test_paint_runs_against_a_real_frame_and_canvas() -> void:
	var grid: TileGrid = TileGrid.new(48, 60, 1)
	for col: int in range(0, 48):
		for row: int in range(20, 60):
			grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(96), Fx.from_int(60))
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(Interface.new(grid, body, Mining.new()), MaterialLook.new(), cam)
	var ran: Array = [0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		SkyPainter.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	var f: Frame = view.current_frame()
	_check(f != null and f.marks.is_empty(),
		"the coordinator built a frame with an empty marks array, as this build has no sky markers")
	_check(view.view_world_rect().size.x > 0.0,
		"control: the canvas has a real rect (%s), so paint() is not drawing into nothing"
		% view.view_world_rect().size)
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0,
		"paint() ran to completion inside a real draw pass (%d time(s)) -- the counter increments on the "
		% int(ran[0]) + "line AFTER the call, so a mid-paint failure would leave it at zero")
	view.queue_free()
