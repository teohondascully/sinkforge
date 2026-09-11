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
	_test_the_starfield_fills_the_sky_that_is_on_screen()
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
## `SURFACE_LINE(22) * CELL(32)`; asserting a bare literal would restate the constant rather than check
## it, so this checks the DATUM the constant is derived from -- which, since P017 (D0292), is
## `MaterialLook.SURFACE_ROW` rather than row 0.
func _test_the_horizon_sits_on_the_surface_datum() -> void:
	_check(MaterialLook.depth_m(MaterialLook.SURFACE_ROW) == 0,
		"the band ladder puts the surface row at depth 0 m (got %d)"
		% MaterialLook.depth_m(MaterialLook.SURFACE_ROW))
	_check(is_equal_approx(SkyPainter.HORIZON_Y,
			float(MaterialLook.SURFACE_ROW * Interface.TERRAIN_CELL_PX)),
		"so the horizon is the world-y of that row (%f vs %f)"
		% [SkyPainter.HORIZON_Y, float(MaterialLook.SURFACE_ROW * Interface.TERRAIN_CELL_PX)])
	# The whole point of P017: there is sky ABOVE the horizon now, and it is a negative depth. Before it,
	# this line could only have been written about a region the grid did not contain.
	_check(SkyPainter.HORIZON_Y > 0.0 and MaterialLook.depth_m(0) < 0,
		"and there is world ABOVE it -- row 0 is %d m, which is air the player can rise into rather than "
		% MaterialLook.depth_m(0) + "a backdrop drawn outside the world")


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
	_check_over(stars.size(), above == stars.size(),
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
	## NOT `_check_over`, deliberately: `> 3` already FAILS on an empty field, so the guard could never fire
	## here and adding it would only teach the idiom as decoration (D0245's direction rule).
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


## THE STARFIELD WAS NEVER VISIBLE, AND THE SKY WAS MOVED TO NIGHT PARTLY BECAUSE IT WOULD BE (D0598).
##
## Legacy placed stars over a band `380` of ITS pixels tall against ITS 32 px cell -- about 12 cells,
## which filled a third of a screen showing ~34 of them. This world shows ~135 cells of height at play
## zoom, so the same 12 cells became a 47 px ribbon sitting ON the horizon, behind the trees. Measured on
## a real 1920x1080 night capture: `visible_stars` returned 42 and the sky held ZERO pixels above 0.12
## luma across 111,600 samples. D0583's "at 0.15 the stars read" was false.
##
## So the band is the SKY THAT IS ON SCREEN, and this pins that rather than the old constant: stars must
## reach the top of the view and must stay clear of the horizon, at any view height.
func _test_the_starfield_fills_the_sky_that_is_on_screen() -> void:
	var tall := Rect2(0.0, -600.0, 1920.0, 1000.0)
	var stars: Array = SkyPainter.visible_stars(tall, 0.0, SkyPainter.HORIZON_Y - 420.0 * SkyPainter.SCALE)
	_check(stars.size() > 20, "a tall night view holds stars at all (%d)" % stars.size())
	var lo: float = 9e9
	var hi: float = -9e9
	for st: Dictionary in stars:
		var y: float = (st["pos"] as Vector2).y
		lo = minf(lo, y)
		hi = maxf(hi, y)
	var horizon: float = SkyPainter.HORIZON_Y - 90.0 * SkyPainter.SCALE
	_check(hi <= horizon + 0.001, "none falls below the horizon line (lowest %.1f against %.1f)" % [hi, horizon])
	_check(lo < tall.position.y + tall.size.y * 0.25,
		"and they reach the TOP of the view, not a ribbon at the bottom (highest %.1f, view top %.1f)" % [lo, tall.position.y])
	var span: float = hi - lo
	_check(span > (horizon - tall.position.y) * 0.5,
		"the field spans most of the visible sky: %.0f px of %.0f available" % [span, horizon - tall.position.y])
	# THE CONTROL, and it is the one the old constant would have failed: a SHORTER view must still be
	# filled, rather than the field keeping a fixed pixel height that happens to suit one zoom.
	var shortv := Rect2(0.0, 100.0, 1920.0, 200.0)
	var few: Array = SkyPainter.visible_stars(shortv, 0.0, SkyPainter.HORIZON_Y - 420.0 * SkyPainter.SCALE)
	var s_lo: float = 9e9
	for st2: Dictionary in few:
		s_lo = minf(s_lo, (st2["pos"] as Vector2).y)
	_check(few.size() > 20 and s_lo < 160.0,
		"and a short view is filled from ITS top too (%d stars, highest %.1f)" % [few.size(), s_lo])
