extends "res://tests/test_base.gd"

## THE FLAT INDEX PLANES AND WHAT STANDS ON THEM (D0390). `TileGrid.block_index`/`wall_index` mirror the
## dictionaries byte for byte through the three mutators and the clone; `WindowPlanes.of_plane` cuts a
## window out of one as row slices and must equal `of`, the Callable-per-cell reference, including where
## the window hangs past the world; `VeilLayer.openness_metres` is legacy's blur at legacy's resolution,
## open where the map is open and buried where it is rock, and `VeilLayer` packs the lamp and the cuts the
## way the shader reads them; `SeatFlags` parses the seat's flags and finds a floor to stand on.

const CELL: int = 4


func _initialize() -> void:
	_test_index_planes_mirror_the_dictionaries_through_every_mutator()
	_test_of_plane_equals_the_per_cell_reference_including_past_the_edge()
	_test_openness_metres_is_open_in_air_buried_in_rock_and_graded_between()
	_test_the_layer_packs_the_lamp_and_the_cuts_as_the_shader_reads_them()
	_test_seat_flags_parse_and_a_warp_finds_a_floor()
	_test_the_sky_floor_follows_every_mutator_and_the_light_terms_pin()
	_finish("flat_planes")


func _fuzzed(seed: int) -> TileGrid:
	var rng: SplitRng = SplitRng.new(seed)
	var g: TileGrid = TileGrid.new(24, 20, seed)
	var ids: Array[StringName] = [&"clay", &"hardrock", &"ore_iron", &"coal", &"wood"]
	for _i: int in 400:
		var c := Vector2i(rng.next_range(0, 23), rng.next_range(0, 19))
		var roll: int = rng.next_range(0, 9)
		if roll < 6:
			g.set_material(c, ids[rng.next_range(0, ids.size() - 1)])
		elif roll < 8:
			g.set_wall(c, ids[rng.next_range(0, ids.size() - 1)])
		else:
			g.excavate(c)
	return g


## Every cell's index byte names the material the dictionary holds there, for both planes.
func _mirrors(g: TileGrid) -> int:
	var bad: int = 0
	for row: int in g.height:
		for col: int in g.width:
			var c := Vector2i(col, row)
			var i: int = row * g.width + col
			if String(g.get_material(c)) != g.legend[g.block_index[i]]:
				bad += 1
			if String(g.get_wall(c)) != g.legend[g.wall_index[i]]:
				bad += 1
	return bad


func _test_index_planes_mirror_the_dictionaries_through_every_mutator() -> void:
	var g: TileGrid = _fuzzed(77)
	_check(g.legend.size() >= 4 and g.legend[0] == "", "the legend grew from the empty id as ids were first written (%d entries)" % g.legend.size())
	_check(_mirrors(g) == 0, "after 400 fuzzed set_material/set_wall/excavate writes both index planes mirror the dictionaries cell for cell")
	var c: TileGrid = g.clone()
	c.set_material(Vector2i(1, 1), &"rich_ore")
	_check(_mirrors(c) == 0 and c.legend.size() == g.legend.size() + 1, "a clone carries its own copies: a new id on the clone lands in the clone's legend only")
	_check(g.legend.size() + 1 == c.legend.size() and _mirrors(g) == 0, "and the original is untouched")
	_check(g.ordinal_of(&"clay") == g.ordinal_of(&"clay") and g.ordinal_of(&"") == 0, "an ordinal is stable and the empty id is always 0")


func _test_of_plane_equals_the_per_cell_reference_including_past_the_edge() -> void:
	var g: TileGrid = _fuzzed(91)
	var world := Vector2i(g.width, g.height)
	var windows: Array[Rect2i] = [Rect2i(3, 2, 10, 9), Rect2i(-5, -4, 14, 12), Rect2i(15, 12, 20, 20), Rect2i(-3, 5, 40, 6), Rect2i(30, 30, 4, 4)]
	var agreed: int = 0
	for w: Rect2i in windows:
		var sliced: PackedByteArray = WindowPlanes.of_plane(w, g.block_index, world)
		var reference: Array = WindowPlanes.of(w, g.get_material)
		var ref_bytes: PackedByteArray = reference[0]
		var ref_legend: PackedStringArray = reference[1]
		var same: bool = sliced.size() == ref_bytes.size()
		if same:
			for i: int in sliced.size():
				if g.legend[sliced[i]] != ref_legend[ref_bytes[i]]:
					same = false
					break
		if same:
			agreed += 1
	_check_over(windows.size(), agreed == windows.size(), "the slice form names the same material as the per-cell reference at every cell of %d windows, inside, straddling and wholly past the world" % windows.size())
	var walls: PackedByteArray = WindowPlanes.of_plane(Rect2i(0, 0, g.width, g.height), g.wall_index, world)
	_check(walls == g.wall_index, "the whole world as a window is the plane itself")


func _test_openness_metres_is_open_in_air_buried_in_rock_and_graded_between() -> void:
	var o := Interface.Observation.new()
	o.map_cells = Vector2i(20, 12)
	o.map = PackedByteArray()
	o.map.resize(20 * 12)
	for y: int in 12:
		for x: int in 20:
			o.map[y * 20 + x] = Interface.Observation.MAP_ROCK if y >= 6 else Interface.Observation.MAP_VOID
	var field: PackedByteArray = VeilLayer.openness_metres(o, Rect2i(0, 0, 20, 12))
	_check(field.size() == 240 and field[0] == 255 and field[20 * 11 + 10] == 0, "deep in the air the field is fully open (255) and deep in the rock fully buried (0)")
	var above: int = field[20 * 5 + 10]
	var at: int = field[20 * 6 + 10]
	var below: int = field[20 * 7 + 10]
	_check(above > at and at > below and below > 0, "across the surface the field grades down over the reach (%d > %d > %d > 0)" % [above, at, below])
	var w: PackedByteArray = VeilLayer.openness_metres(o, Rect2i(-3, -3, 8, 8))
	_check(w.size() == 64 and w[0] == 255, "a rect hanging past the map clamps into it, as the cell field does")
	_check(VeilLayer.metre_rect_of(Rect2i(-9, 5, 146, 30)) == Rect2i(-3, 1, 38, 8), "the metre rect covers a cell window with floor and ceil (-9..137 -> -3..35, 5..35 -> 1..9)")


func _test_the_layer_packs_the_lamp_and_the_cuts_as_the_shader_reads_them() -> void:
	var o := Interface.Observation.new()
	o.cell = Vector2i(40, 200)
	o.facing = 1
	var lamp: PackedVector4Array = VeilLayer.lamp_cuts(o)
	var m: float = float(MaterialLook.CELLS_PER_METRE)
	_check(lamp.size() == 3 and is_equal_approx(lamp[0].z, VeilPainter.LAMP_BEAM_M * m) and is_equal_approx(lamp[2].z, VeilPainter.LAMP_BODY_M * m), "three lamp cuts with legacy's radii in cells")
	_check(is_equal_approx(lamp[2].x, 40.5) and lamp[0].x > lamp[2].x, "the body cut sits on the miner and the beam leads the way the miner faces")
	_check(is_equal_approx(lamp[2].w, VeilPainter.LAMP_BODY_STRENGTH * VeilPainter.lamp_scale(200)), "strengths carry the depth scale (and at t = 0 the flicker is exactly 1)")
	# D0403: the lamp breathes on the frame's clock, within LAMP_FLICKER of itself, never above it.
	var lo: float = 2.0
	var hi: float = 0.0
	for i: int in 200:
		var f: float = VeilLayer.lamp_flicker(float(i) * 0.05)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	_check(is_equal_approx(hi, 1.0) and lo >= 1.0 - VeilLayer.LAMP_FLICKER - 1e-6 and lo < 1.0 - VeilLayer.LAMP_FLICKER * 0.5, "the flicker stays within its band and reaches most of it over ten seconds (%.4f..%.4f)" % [lo, hi])
	_check(VeilLayer.lamp_cuts(o, 1.7)[2].w < lamp[2].w, "...and a later frame's pool is fainter than the unflickered one")
	var cuts: Array[Dictionary] = []
	for i: int in 70:
		cuts.append({"centre": Vector2(float(i), 2.0), "radius": 8.0, "strength": 0.5, "tint": Color(1.0, 0.5, 0.25)})
	var packed: Array = VeilLayer.pack_cuts(cuts)
	var geo: PackedVector4Array = packed[0]
	var tints: PackedVector4Array = packed[1]
	_check(geo.size() == VeilLayer.MAX_CUTS and tints.size() == VeilLayer.MAX_CUTS and int(packed[2]) == VeilLayer.MAX_CUTS, "the arrays are always MAX_CUTS long and the count is capped there (%d)" % int(packed[2]))
	_check(is_equal_approx(geo[7].x, 7.0) and is_equal_approx(geo[7].z, 8.0) and is_equal_approx(tints[7].y, 0.5), "a cut lands at its index with centre, radius, strength and tint")
	var layer: VeilLayer = VeilLayer.new()
	_check(layer.material != null and layer.material.shader != null, "the layer loads its shader and owns a material")


func _test_seat_flags_parse_and_a_warp_finds_a_floor() -> void:
	var f: Dictionary = SeatFlags.parse(PackedStringArray(["--warp=12,34", "--zoom=2.5", "--screenshot-tick=40", "--screenshot-out=/tmp/x.png", "--perf-drive"]))
	_check(f["warp"] == Vector2i(12, 34) and is_equal_approx(float(f["zoom"]), 2.5) and int(f["screenshot_tick"]) == 40 and String(f["screenshot_out"]) == "/tmp/x.png" and bool(f["perf"]) and bool(f["drive"]) and int(f["quit_after"]) == -1, "every flag parses and the absent smoke flag reads -1")
	var none: Dictionary = SeatFlags.parse(PackedStringArray([]))
	_check(none["warp"] == SeatFlags.NO_WARP and not bool(none["perf"]) and float(none["zoom"]) == 0.0, "no flags: no warp, no meter, the saved zoom")
	var g: TileGrid = TileGrid.new(30, 30, 1)
	for row: int in range(20, 30):
		for col: int in 30:
			g.set_material(Vector2i(col, row), &"clay")
	for col: int in range(10, 14):   # a pocket in the rock, 4 wide, rows 24-27 open, floor at 28
		for row: int in range(24, 28):
			g.excavate(Vector2i(col, row))
	_check(SeatFlags.stand_near(g, Vector2i(5, 10), 3) == Vector2i(5, 19), "in the open above the ground the nearest floor is the surface directly below")
	var pocket: Vector2i = SeatFlags.stand_near(g, Vector2i(11, 25), 3)
	_check(pocket.y == 27 and pocket.x >= 10 and pocket.x <= 13, "pointed into a pocket, the warp lands on the pocket's floor, not on the surface (%s)" % pocket)
	_check(SeatFlags.stand_near(g, Vector2i(20, 29), 3, 1) == SeatFlags.NO_WARP, "buried with no floor in reach: no warp")


## `TileGrid.sky_floor` is the first solid row per column under the open sky, maintained at the mutators
## and equal to a from-scratch scan after fuzzing; `WindowPlanes.columns_of` pads past the world; and
## `VeilLight`'s terms pin legacy's numbers: the deep is `AMBIENT_LIGHT`, the scatter under a column's
## surface reaches the ambient over `SKY_FADE_M`, open air above the surface is lit by depth alone.
func _test_the_sky_floor_follows_every_mutator_and_the_light_terms_pin() -> void:
	var g: TileGrid = _fuzzed(123)
	var bad: int = 0
	for col: int in g.width:
		var first: int = g.height
		for row: int in g.height:
			if g.is_solid(Vector2i(col, row)):
				first = row
				break
		if g.sky_floor[col] != first:
			bad += 1
	_check(bad == 0, "after fuzzed writes every column's sky floor equals a from-scratch scan (%d wrong)" % bad)
	var g2: TileGrid = TileGrid.new(4, 10, 1)
	_check(g2.sky_floor[1] == 10, "an all-air column's floor is the height")
	g2.set_material(Vector2i(1, 6), &"clay")
	g2.set_material(Vector2i(1, 8), &"clay")
	_check(g2.sky_floor[1] == 6, "the first solid from the sky is the floor (6)")
	g2.excavate(Vector2i(1, 6))
	_check(g2.sky_floor[1] == 8, "digging the floor hands it to the next solid below (8)")
	g2.set_material(Vector2i(1, 8), &"")
	_check(g2.sky_floor[1] == 10, "clearing the last solid returns the column to all-air")
	var cols: PackedInt32Array = WindowPlanes.columns_of(Rect2i(-2, 0, 8, 1), g2.sky_floor, 99)
	_check(cols.size() == 8 and cols[0] == 99 and cols[1] == 99 and cols[3] == 10 and cols[7] == 99, "a column window pads past the world with the sentinel on both sides")
	var deep: Color = VeilLight.level_rgb(1.0 - VeilPainter.AMBIENT_DARK)
	_check(deep.is_equal_approx(VeilLight.AMBIENT_LIGHT), "at the ambient the light level is legacy's AMBIENT_LIGHT, a colour")
	_check(VeilLight.level_rgb(1.0).is_equal_approx(Color.WHITE) and VeilLight.level_rgb(0.17).b > VeilLight.level_rgb(0.17).r, "full light is white; below the ambient the hue stays cool")
	var datum: float = float(MaterialLook.SURFACE_ROW)
	_check(is_equal_approx(VeilLight.sky_light(datum - 20.0, datum), 1.0), "open air above the datum is fully lit")
	var open_deep: float = VeilLight.sky_light(datum + 40.0, datum + 200.0)   # 10 m down an open shaft
	var under_rock: float = VeilLight.sky_light(datum + 40.0, datum)          # 10 m under the surface rock
	_check(open_deep > under_rock and under_rock < 0.5, "the same depth is brighter down an open shaft than under rock (%.2f vs %.2f)" % [open_deep, under_rock])
	_check(is_equal_approx(VeilLight.sky_light(datum + 400.0, datum), 1.0 - VeilPainter.AMBIENT_DARK), "deep under rock the light is the ambient")
