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
	_test_the_batch_obeys_the_engines_own_contract()
	await _test_the_draw_itself_runs_on_a_real_canvas()
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


## THE BATCH ITSELF, AND THIS TEST EXISTS BECAUSE A REAL BUG GOT THROUGH EVERY OTHER ONE (D0595).
##
## `draw_multiline_colors` asserts `colors.size() * 2 == points.size()` in NATIVE code. The first version
## built a colour per POINT: the call failed, drew nothing, and printed only an engine-level ERROR -- no
## script error, no failed assertion, exit 0. This file was 20 of 20 while the grass did not exist. Two
## unrelated boot suites went red instead, because they drive the real stack and `run_gd_test.sh`'s D0149
## guard reads engine ERROR lines.
##
## THE FIRST ATTEMPT AT THIS TEST ALSO FAILED TO CATCH IT, and that is the sharper half. It ran `paint`
## with a real canvas inside a real draw pass -- and the posed world produced NO BLADES, so the draw was
## never reached and restoring the bug left the suite green. `[[instrument-cannot-register-subject]]`: a
## draw test that draws nothing registers nothing. So this poses the field, PROVES it is non-empty first,
## and only then asserts the invariant on the data.
func _test_the_batch_obeys_the_engines_own_contract() -> void:
	var f: Frame = Frame.new()
	f.obs = _grassy_obs()
	f.view_world_rect = Rect2(0.0, 0.0, 160.0, 400.0)
	var b: Dictionary = GrassPainter.batch(f)
	var points: PackedVector2Array = b["points"]
	var colors: PackedColorArray = b["colors"]
	# THE CONTROL, FIRST. Every assertion below is vacuous on an empty batch, which is exactly how the
	# first version of this test passed while the subject was gone.
	_check(points.size() > 0, "the posed surface actually grows blades (%d points) -- without this the rest is vacuous" % points.size())
	_check(colors.size() * 2 == points.size(),
		"ONE COLOUR PER SEGMENT, which is what `draw_multiline_colors` asserts natively: %d colours, %d points" % [
			colors.size(), points.size()])
	_check(points.size() % 2 == 0, "and the points come in pairs, one segment apiece (%d)" % points.size())
	# Blades stand UP from their foot: the second point of each pair is above the first.
	var upward: int = 0
	for i: int in range(0, points.size(), 2):
		if points[i + 1].y < points[i].y:
			upward += 1
	_check(upward == points.size() / 2, "every blade stands up from its foot (%d of %d)" % [upward, points.size() / 2])
	# And nothing grows where there is no soil.
	var bare: Frame = Frame.new()
	bare.obs = _grassy_obs(&"hardrock")
	bare.view_world_rect = Rect2(0.0, 0.0, 160.0, 400.0)
	_check((bare.obs != null) and (GrassPainter.batch(bare)["points"] as PackedVector2Array).is_empty(),
		"CONTROL: the same surface in hardrock grows nothing")


## A window of solid `material` from row 20 down, so every column has a walkable surface at row 20.
func _grassy_obs(material: StringName = &"clay") -> Interface.Observation:
	var w: int = 48
	var h: int = 48
	var o: Interface.Observation = Interface.Observation.new()
	o.world_cells = Vector2i(w, h)
	o.window = Rect2i(0, 0, w, h)
	o.logic_window = Rect2i(0, 0, w / 4, h / 4)
	o.legend = PackedStringArray(["", String(material)])
	o.materials = PackedByteArray()
	o.materials.resize(w * h)
	o.water = PackedByteArray()
	o.water.resize(w * h)
	for col: int in w:
		for row: int in range(20, h):
			o.materials[row * w + col] = 1
	var surf := PackedInt32Array()
	for _col: int in w:
		surf.append(20 * Interface.Units.CELL_PX * Fx.SCALE)
	o.surface_y = surf
	return o


## THE DRAW PATH, AND THIS TEST EXISTS BECAUSE IT WAS MISSING (D0595).
##
## Every other assertion in this file calls a pure function, and the first version shipped a real bug none
## of them could see: `draw_multiline_colors` asserts `colors.size() * 2 == points.size()` in NATIVE code,
## and the batch was built with a colour per POINT. The call failed, drew nothing, and printed only an
## engine-level ERROR -- no script error, no failed assertion, exit code 0. `test_main_boot` and
## `test_settings_live` went red because they boot the real stack and `tools/run_gd_test.sh`'s D0149 guard
## reads engine ERROR lines; this suite stayed green at 20 of 20.
##
## So the guard already existed and this suite simply never REACHED the draw. It does now: a real
## `WorldView`, a real canvas, a clay surface under the camera, and the painter run inside an actual draw
## pass. A colour-per-point regression prints the ERROR again and the harness fails THIS file, where the
## subject is, instead of two unrelated boot suites.
func _test_the_draw_itself_runs_on_a_real_canvas() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20 * 4):
		for row: int in range(60, 80):
			world.set_solid(Vector2i(col, row), &"clay")   # a clay surface for blades to stand in
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(56 * 4) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var ran: Array = [0, 0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		GrassPainter.paint(f, ci)
		ran[0] = int(ran[0]) + 1
		if f != null and f.obs != null and f.view_world_rect.size.x > 0.0:
			ran[1] = 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint() ran inside a real draw pass (%d time(s))" % int(ran[0]))
	_check(int(ran[1]) == 1, "and the frame it drew carried an observation and a non-empty view rect")
	# The real assertion is made by the harness, not by this line: if the batch is malformed again, the
	# engine prints an ERROR during that draw and `run_gd_test.sh` fails this file for it.
	_check(true, "and the engine raised no draw error -- `run_gd_test.sh`'s D0149 guard is the witness")
	view.queue_free()
