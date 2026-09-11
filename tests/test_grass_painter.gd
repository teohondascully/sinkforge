extends "res://tests/test_base.gd"

## `view/visuals/grass_painter.gd` -- THE GROUND STOPS BEING A LINE (item 28, D0595).
##
## `SurfaceTone`'s moss, roots, blades and hanging tufts are all drawn WITHIN the cap cell: a texture on
## the top face, not a silhouette against the sky. These assertions pin the things that make blades read
## as grass rather than as a comb -- that heights VARY, that the variation is deterministic and not a
## lattice, that only soil carries them, and that the green is the trees' own.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_grass_painter.gd


func _initialize() -> void:
	_test_heights_vary_and_stay_inside_their_bounds()
	_test_the_field_is_deterministic_and_not_a_lattice()
	_test_only_soil_carries_grass()
	_test_the_green_is_the_trees_own_and_varies_between_columns()
	_test_paint_refuses_a_frame_it_cannot_read()
	_finish("grass_painter")


func _test_heights_vary_and_stay_inside_their_bounds() -> void:
	var lo: float = 99.0
	var hi: float = -99.0
	var out_of_range: int = 0
	for col: int in range(0, 400):
		for blade: int in GrassPainter.PER_COLUMN:
			var h: float = GrassPainter.blade_height(col, blade)
			lo = minf(lo, h)
			hi = maxf(hi, h)
			if h < GrassPainter.MIN_CELLS - 0.001 or h > GrassPainter.MAX_CELLS + 0.001:
				out_of_range += 1
	_check(out_of_range == 0, "every blade stands between %.2f and %.2f cells (%d outside)" % [
		GrassPainter.MIN_CELLS, GrassPainter.MAX_CELLS, out_of_range])
	# THE ITEM IS "height VARIATION", so a field of equal blades passes every other check here and fails
	# the one thing asked for. It must use most of its range, not a sliver in the middle.
	var span: float = hi - lo
	var range_cells: float = GrassPainter.MAX_CELLS - GrassPainter.MIN_CELLS
	_check(span > range_cells * 0.8,
		"and they use %.0f%% of the range available (%.2f to %.2f of %.2f-%.2f)" % [
			100.0 * span / range_cells, lo, hi, GrassPainter.MIN_CELLS, GrassPainter.MAX_CELLS])
	# NEIGHBOURS MUST DIFFER, which is a different claim from "the set is wide": a field that ramped
	# smoothly across the world would satisfy the span and still read as a comb at any one place.
	var flat: int = 0
	for col: int in range(0, 400):
		if absf(GrassPainter.blade_height(col, 0) - GrassPainter.blade_height(col + 1, 0)) < 0.02:
			flat += 1
	_check(flat < 80, "and adjacent columns differ: only %d of 400 neighbour pairs are within 0.02 cells" % flat)


## Deterministic, and NOT `i * BIG_CONST` (`[[linear-sequence-as-hash]]`): a lattice would give a small
## number of distinct gaps and draw a visible repeat down a hillside.
func _test_the_field_is_deterministic_and_not_a_lattice() -> void:
	_check(GrassPainter.blade_height(77, 1) == GrassPainter.blade_height(77, 1)
			and GrassPainter.blade_lean(77, 1) == GrassPainter.blade_lean(77, 1),
		"the same column and blade give the same answer twice")
	var seen: Dictionary = {}
	for col: int in range(0, 400):
		seen["%.3f" % GrassPainter.blade_height(col, 0)] = true
	_check(seen.size() > 300, "400 columns give %d distinct heights, not a short repeating cycle" % seen.size())
	var leans: Dictionary = {}
	for col: int in range(0, 400):
		leans["%.3f" % GrassPainter.blade_lean(col, 0)] = true
	_check(leans.size() > 300, "and %d distinct leans, so the tips are not a comb" % leans.size())
	var worst: float = 0.0
	for col: int in range(0, 400):
		worst = maxf(worst, absf(GrassPainter.blade_lean(col, 0)))
	_check(worst <= GrassPainter.LEAN_CELLS + 0.001,
		"no tip leans past LEAN_CELLS (%.3f against %.2f)" % [worst, GrassPainter.LEAN_CELLS])


## The record's own `soil` flag, which is the same rule `sim/world/materials.gd:25 is_soil` applies --
## the view may not reach that function, so this reads the record instead of restating a list.
func _test_only_soil_carries_grass() -> void:
	_check(GrassPainter.grassy(&"clay"), "clay carries grass -- it is the one material with `soil: true`")
	for barren: StringName in [&"hardrock", &"deepstone", &"coal", &"ore_iron", &"leaves", &"wood", &"glimmer"]:
		_check(not GrassPainter.grassy(barren), "%s does not" % barren)
	_check(not GrassPainter.grassy(&"no_such_material"),
		"and an unknown material does not, rather than defaulting to grassy")


## ONE GREEN FOR EVERY PLANT IN THIS WORLD. The blade takes `leaves`' own `base_color` and
## `BeddingTone.foliage_tone`, the function that gives two trees side by side different greens (D0584),
## so grass and canopy drift together rather than apart.
func _test_the_green_is_the_trees_own_and_varies_between_columns() -> void:
	var c: Color = GrassPainter.blade_color(40, 80)
	_check(c.g > c.r and c.g > c.b, "a blade is green-dominant (%.3f, %.3f, %.3f)" % [c.r, c.g, c.b])
	var leaf: Array = MaterialsRecords.RECORDS[&"leaves"]["base_color"]
	_check(c.g < float(leaf[1]) + 0.12,
		"and no brighter than the canopy it belongs to (%.3f against leaves' %.3f)" % [c.g, float(leaf[1])])
	var tints: Dictionary = {}
	for col: int in range(0, 200):
		var t: Color = GrassPainter.blade_color(col, 80)
		tints["%.3f,%.3f,%.3f" % [t.r, t.g, t.b]] = true
	_check(tints.size() > 120,
		"and the green varies along the surface: %d distinct over 200 columns" % tints.size())


## Every early return: a painter that throws takes the whole frame with it.
func _test_paint_refuses_a_frame_it_cannot_read() -> void:
	GrassPainter.paint(null, null)
	var f: Frame = Frame.new()
	GrassPainter.paint(f, null)
	f.obs = Interface.Observation.new()
	f.view_world_rect = Rect2()
	GrassPainter.paint(f, null)
	_check(true, "a null frame, a frame with no observation and a zero-width view all draw nothing")
