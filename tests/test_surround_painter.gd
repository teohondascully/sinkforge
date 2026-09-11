extends "res://tests/test_base.gd"

## `view/visuals/surround_painter.gd` -- THE EARTH PAST THE EDGE OF THE WORLD (T036, item 34, D0590).
##
## The sim has answered "rock" for every cell outside the grid since D0457 (`WorldSurroundings.blocks`).
## The view painted the sky's below-horizon colour there instead, so the body walked into a wall that was
## not pictured. These assertions pin the three things that decide whether the fix works: it is not the
## sky's colour, it is not a FLAT fill, and it recedes rather than ending in black.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_surround_painter.gd

const SURF: float = float(MaterialLook.SURFACE_ROW)


func _initialize() -> void:
	_test_the_beyond_is_not_the_sky_colour_it_used_to_be()
	_test_it_is_strata_and_not_a_flat_fill()
	_test_it_recedes_to_a_floor_that_is_not_black()
	_test_it_takes_the_same_night_and_depth_model_the_terrain_does()
	_test_it_survives_a_missing_look_and_a_column_with_no_floor()
	_finish("surround_painter")


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## THE DEFECT ITSELF. `SkyPainter` fills below the horizon across the WHOLE view, so what stood past the
## edge was `SkyLight.horizon_tone` -- ground-coloured sky, at luma 0.1968.
##
## THE FIRST VERSION OF THIS TEST ASSERTED THE WRONG QUANTITY and failed honestly: it required that no
## row of the beyond share the sky's LUMA. The beyond necessarily spans a range of brightness, so it must
## cross 0.1968 somewhere, and luma alone never distinguished the two -- `[[print-the-discriminating-
## quantity]]`. What actually matters is that the beyond is DARKER than the fill it replaced, at every
## depth, which is also what makes it read as mass rather than as sky.
func _test_the_beyond_is_not_the_sky_colour_it_used_to_be() -> void:
	var look: MaterialLook = MaterialLook.new()
	var sky: float = _luma(SkyLight.horizon_tone(SkyPainter.DAYLIGHT))
	var brightest: float = -1.0
	for m: int in range(0, 61):
		brightest = maxf(brightest, _luma(SurroundPainter.mass_color(look, 3, int(SURF) + m * MaterialLook.CELLS_PER_METRE, SURF)))
	_check(brightest < sky,
		"the beyond is darker than the sky fill it replaced at EVERY depth: brightest %.4f against the sky's %.4f" % [
			brightest, sky])
	# And darker than the rock it continues -- the reference's unlit deep rock, which D0585 measured this
	# build onto at 0.1926. Past the edge is unreachable and unlit; it must never out-glow the world.
	_check(brightest < 0.19,
		"and darker than the in-world rock it continues (%.4f against the reference's unlit deep rock 0.190)" % brightest)


## A single flat rectangle past the edge is the SAME defect in a different hue: what reads as broken is
## that it is featureless. So the beyond must vary down the column, and by more than rounding.
func _test_it_is_strata_and_not_a_flat_fill() -> void:
	var look: MaterialLook = MaterialLook.new()
	var lo: float = 9.0
	var hi: float = -9.0
	var distinct: Dictionary = {}
	for m: int in range(0, 60):
		var c: Color = SurroundPainter.mass_color(look, 3, int(SURF) + m * MaterialLook.CELLS_PER_METRE, SURF)
		lo = minf(lo, _luma(c))
		hi = maxf(hi, _luma(c))
		distinct["%.3f,%.3f,%.3f" % [c.r, c.g, c.b]] = true
	_check(hi - lo > 0.03, "the beyond varies down 60 m of depth: luma %.4f to %.4f (spread %.4f)" % [lo, hi, hi - lo])
	_check(distinct.size() >= 12,
		"and it is many colours rather than a fill: %d distinct over 60 samples" % distinct.size())


## It must fade AWAY from the world, and it must not reach black -- black past the edge reads as a hole
## cut in the canvas, which is the one thing this painter exists to stop looking like.
func _test_it_recedes_to_a_floor_that_is_not_black() -> void:
	_check(absf(SurroundPainter.recede(0.0) - 1.0) < 0.0001,
		"at the boundary the mass is at full strength (%.4f): the seam is continuous with the terrain" % SurroundPainter.recede(0.0))
	_check(absf(SurroundPainter.recede(SurroundPainter.RECEDE_M) - SurroundPainter.RECEDE_FLOOR) < 0.0001,
		"and it reaches its floor at RECEDE_M (%.1f m -> %.4f)" % [SurroundPainter.RECEDE_M, SurroundPainter.RECEDE_FLOOR])
	_check(SurroundPainter.RECEDE_FLOOR > 0.05,
		"the floor is not black (%.4f): a hole in the canvas is the defect, not the fix" % SurroundPainter.RECEDE_FLOOR)
	var fell: int = 0
	var last: float = 2.0
	for i: int in 21:
		var v: float = SurroundPainter.recede(float(i))
		if v <= last:
			fell += 1
		last = v
	_check(fell == 21, "and it never brightens with distance across 21 steps (%d)" % fell)
	_check(absf(SurroundPainter.recede(999.0) - SurroundPainter.RECEDE_FLOOR) < 0.0001,
		"and it clamps rather than going negative far out (%.4f)" % SurroundPainter.recede(999.0))


## COHERENCE, the same requirement Astra's D6 put on the godrays: the beyond asks the world's own light
## functions, so it cannot disagree with the terrain about the hour or the depth.
func _test_it_takes_the_same_night_and_depth_model_the_terrain_does() -> void:
	var look: MaterialLook = MaterialLook.new()
	var shallow: Color = SurroundPainter.mass_color(look, 3, int(SURF) + MaterialLook.CELLS_PER_METRE, SURF)
	var deep: Color = SurroundPainter.mass_color(look, 3, int(SURF) + 60 * MaterialLook.CELLS_PER_METRE, SURF)
	# The deep is LIFTED (D0577/D0583): ambient reaches it, the night level does not.
	_check(_luma(deep) > _luma(shallow),
		"the deep is lifted above the shallow beyond (%.4f against %.4f), as `DEEP_AMBIENT` says it must be" % [
			_luma(deep), _luma(shallow)])
	# And the shallow one is under the night level rather than lit for noon (the D0583 defect).
	var sky_at: float = VeilLight.sky_light(SURF + float(MaterialLook.CELLS_PER_METRE), SURF)
	var noon: Color = VeilLight.level_rgb(SurroundPainter.BEYOND_SHADE * sky_at, 1.0)
	var night: Color = VeilLight.level_rgb(SurroundPainter.BEYOND_SHADE * sky_at, 0.0)
	_check(_luma(night) < _luma(noon),
		"and near the surface the night level applies (%.4f against a noon %.4f)" % [_luma(night), _luma(noon)])
	# THE MASS SHADE IS RAMPED, NOT FLAT, and this is the guard for it. The beyond's top row sits directly
	# under the sky, so it is not mass-shaded; applied flat it measured 0.041 against the 0.155 of the
	# ground beside it, a four-fold step that draws a black bar along the top of the boundary. Nothing
	# else in this suite can see that -- the spread and the distinct-colour counts both survive it.
	var top: float = _luma(SurroundPainter.mass_color(look, 3, int(SURF), SURF))
	_check(top / maxf(_luma(deep), 0.0001) > 0.45,
		"the surface row is not a black bar: %.4f is %.0f%% of the deep's %.4f, not the 28%% a flat shade gives" % [
			top, 100.0 * top / _luma(deep), _luma(deep)])
	_check(absf(SurroundPainter.mass_shade(int(SURF), SURF) - 1.0) < 0.0001,
		"because at the surface the mass takes no shading at all (%.4f)" % SurroundPainter.mass_shade(int(SURF), SURF))


## Every early return and every degenerate input: a painter that throws takes the whole frame with it.
func _test_it_survives_a_missing_look_and_a_column_with_no_floor() -> void:
	var c: Color = SurroundPainter.mass_color(null, 3, int(SURF) + 40, SURF)
	_check(c.r >= 0.0 and c.r <= 1.0 and c.g >= 0.0 and c.g <= 1.0 and c.b >= 0.0 and c.b <= 1.0,
		"a null look still yields a drawable colour (%.3f, %.3f, %.3f)" % [c.r, c.g, c.b])
	SurroundPainter.paint(null, null)
	var f: Frame = Frame.new()
	SurroundPainter.paint(f, null)
	_check(true, "and `paint` refuses a null frame and a frame with no observation without drawing")
