extends "res://tests/test_base.gd"

## `view/visuals/bake_data.gd`: THE SHADER'S INPUT PLANE (D0528, T040's evidence). One RGBA8 texel a cell
## over the paint rect grown by `BakeData.MARGIN` -- R the material's palette index, G the grammar plus
## the speck and facet bits, B the Manhattan distance to air clamped to `FORM_REACH + 1`, A the soil-depth
## code plus a root bit -- and the flag that decides whether `BakeChunk` builds one at all.
##
## **THIS SUITE CANNOT SEE THE PIXELS AND SAYS SO UP FRONT**, as `test_bake_budget.gd` does: `rock_tone.
## gdshader` runs on a GPU and `TerrainBake.setup` declines under `--headless`, so nothing here asserts a
## COLOUR. What it asserts is that the bytes the shader reads say what the CPU tone would have looked up
## -- the material, the grammar, the speck, the distance, the surface row -- against controls computed a
## different way: the distance by an exhaustive ring scan off `Observation.material_at` rather than off
## this file's chamfer, the material by `material_at` rather than by the legend table.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_bake_data.gd

const CELL: int = 4
const GRID_W: int = 80
const GRID_H: int = 140
## The soil surface. `SurfaceTone.is_walked` needs `depth_m_exact(row) <= CAP_BAND_M` -- row <= 112 -- or
## the column is a hole floor and the cap and the profile do not apply at all.
const SOIL_TOP: int = 84
const ROCK_TOP: int = 100
const ORE_CELL := Vector2i(30, 112)
const ORE_R: int = 3
## The dug pocket, so the distance-to-air field has an interior source and not only the sky.
const CAVITY := Rect2i(24, 106, 7, 5)
## Three chunks by three at `BakeWindow.CHUNK_PX` 64 over 4 px cells: 48 cells a side, from cell (16, 80).
const REGION := Rect2i(16, 80, 48, 48)


func _initialize() -> void:
	_test_the_b_channel_is_the_distance_to_air_at_every_cell_of_a_three_by_three_chunk_world()
	_test_the_r_channel_indexes_the_material_the_observation_holds()
	_test_the_g_channel_carries_the_grammar_the_speck_and_the_facet()
	_test_the_a_channel_marks_the_walked_surface_row_and_the_root_column()
	_test_the_palette_row_is_the_records_own_colour_and_depth_darken()
	_test_the_seed_truncates_to_thirty_two_bits_signed()
	_test_with_the_flag_off_bake_chunk_keeps_the_cpu_painter_and_builds_nothing()
	_finish("bake_data")


## A world with a walked soil surface, rock under it, an ore blob and a dug pocket, observed over the
## 3x3-chunk region plus room to spare. Returns [observation, look, image, data].
func _fixture() -> Array:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 11)
	for col: int in GRID_W:
		for row: int in range(SOIL_TOP, GRID_H):
			var m: StringName = &"clay" if row < ROCK_TOP else &"hardrock"
			grid.set_material(Vector2i(col, row), m)
			grid.set_wall(Vector2i(col, row), m)
	for dy: int in range(-ORE_R, ORE_R + 1):
		for dx: int in range(-ORE_R, ORE_R + 1):
			grid.set_material(ORE_CELL + Vector2i(dx, dy), &"ore_iron")
	for row: int in range(CAVITY.position.y, CAVITY.end.y):
		for col: int in range(CAVITY.position.x, CAVITY.end.x):
			grid.excavate(Vector2i(col, row))
	var body: Body = Body.new(Fx.from_int(GRID_W * CELL / 2), Fx.from_int(4 * CELL))
	var iface: Interface = Interface.new(grid, body, Mining.new())
	var view := Rect2(0.0, 0.0, float(GRID_W * CELL), float(GRID_H * CELL))
	var obs: Interface.Observation = iface.observe(
		Interface.Envelope.covering(view, WorldView.WINDOW_MARGIN_CELLS))
	var look: MaterialLook = MaterialLook.new()
	var data: BakeData = BakeData.new()
	data.setup()
	return [obs, look, data.build(obs, REGION, look), data]


## THE CONTROL FOR B, computed a different way from the thing it checks: an exhaustive scan of every cell
## at Manhattan distance 1, 2, ... off `Observation.material_at` (which answers air outside its window,
## exactly as `solid_bytes` writes 0 there), stopping at `DIST_MAX`. A cell outside the IMAGE is unseen
## and is not a source, which is the one rule the chamfer's boundary encodes.
func _ring_distance(obs: Interface.Observation, span: Rect2i, cell: Vector2i) -> int:
	if obs.material_at(cell) == &"":
		return 0
	for d: int in range(1, BakeData.DIST_MAX + 1):
		for dx: int in range(-d, d + 1):
			var dy: int = d - absi(dx)
			for sy: int in ([0] if dy == 0 else [dy, -dy]):
				var c: Vector2i = cell + Vector2i(dx, sy)
				if span.has_point(c) and obs.material_at(c) == &"":
					return d
	return BakeData.DIST_MAX


func _test_the_b_channel_is_the_distance_to_air_at_every_cell_of_a_three_by_three_chunk_world() -> void:
	var f: Array = _fixture()
	var obs: Interface.Observation = f[0]
	var img: Image = f[2]
	var span: Rect2i = (f[3] as BakeData).span
	_check(img != null and img.get_size() == span.size,
		"the image is the region grown by MARGIN: %s cells for a %s region" % [span.size, REGION.size])
	_check(obs.window.encloses(span),
		"the observation encloses the span: window %s encloses %s" % [obs.window, span])
	var checked: int = 0
	var wrong: int = 0
	var first: String = ""
	for y: int in span.size.y:
		for x: int in span.size.x:
			var cell: Vector2i = span.position + Vector2i(x, y)
			if obs.material_at(cell) == &"":
				continue
			checked += 1
			var got: int = int(round(img.get_pixel(x, y).b * 255.0))
			var want: int = _ring_distance(obs, span, cell)
			if got == want:
				continue
			wrong += 1
			if first == "":
				first = "cell %s: B=%d, ring scan says %d" % [cell, got, want]
	_check_over(checked, wrong == 0,
		"every solid cell's B is its ring-scanned distance to air; %d disagreed%s"
			% [wrong, "" if first == "" else " (first: %s)" % first])
	var deep: int = 0
	var edge: int = 0
	for y: int in span.size.y:
		for x: int in span.size.x:
			var b: int = int(round(img.get_pixel(x, y).b * 255.0))
			if b == BakeData.DIST_MAX:
				deep += 1
			elif b > 0:
				edge += 1
	# The population the pin ranges over is not degenerate: without BOTH a saturated interior and a band
	# under DIST_MAX, "every cell agrees" would be an agreement about one value.
	_check(deep > 0 and edge > 0,
		"the field spans its range: %d cells at DIST_MAX (%d) and %d strictly between"
			% [deep, BakeData.DIST_MAX, edge])


func _test_the_r_channel_indexes_the_material_the_observation_holds() -> void:
	var f: Array = _fixture()
	var obs: Interface.Observation = f[0]
	var img: Image = f[2]
	var data: BakeData = f[3]
	var span: Rect2i = data.span
	var checked: int = 0
	var wrong: int = 0
	var first: String = ""
	var seen: Dictionary = {}
	for y: int in span.size.y:
		for x: int in span.size.x:
			var cell: Vector2i = span.position + Vector2i(x, y)
			var material: StringName = obs.material_at(cell)
			checked += 1
			seen[material] = true
			var got: int = int(round(img.get_pixel(x, y).r * 255.0))
			var want: int = data.index_of(material)
			if got == want:
				continue
			wrong += 1
			if first == "":
				first = "cell %s holds %s: R=%d, index_of says %d" % [cell, material, got, want]
	_check_over(checked, wrong == 0,
		"every texel's R is its material's palette index; %d disagreed%s"
			% [wrong, "" if first == "" else " (first: %s)" % first])
	_check(seen.size() >= 4,
		"the fixture poses more than one material: %d distinct, %s" % [seen.size(), seen.keys()])
	_check(data.index_of(&"") == 0 and data.index_of(&"clay") > 0
			and data.index_of(&"no_such_material") == data.unknown_index(),
		"air is 0, a record is 1..N, an unknown id is the unknown slot %d" % data.unknown_index())


func _test_the_g_channel_carries_the_grammar_the_speck_and_the_facet() -> void:
	var f: Array = _fixture()
	var obs: Interface.Observation = f[0]
	var look: MaterialLook = f[1]
	var img: Image = f[2]
	var span: Rect2i = (f[3] as BakeData).span
	var checked: int = 0
	var wrong: int = 0
	var specks: int = 0
	var facets: int = 0
	var first: String = ""
	for y: int in span.size.y:
		for x: int in span.size.x:
			var cell: Vector2i = span.position + Vector2i(x, y)
			var material: StringName = obs.material_at(cell)
			if material == &"":
				continue
			checked += 1
			var g: int = int(round(img.get_pixel(x, y).g * 255.0))
			var speck: bool = look.is_speck(material, cell.x, cell.y)
			var lit: bool = MaterialLook._hash01(cell.x, cell.y, BakeData.FACET_SALT) < BakeData.FACET_SHARE
			specks += 1 if speck else 0
			facets += 1 if speck and lit else 0
			var want: int = look.grammar_of(material)
			want |= BakeData.G_SPECK_BIT if speck else 0
			want |= BakeData.G_FACET_BIT if speck and lit else 0
			if g == want:
				continue
			wrong += 1
			if first == "":
				first = "cell %s (%s): G=%d, want %d" % [cell, material, g, want]
	_check_over(checked, wrong == 0,
		"every solid texel's G is grammar | speck | facet; %d disagreed%s"
			% [wrong, "" if first == "" else " (first: %s)" % first])
	_check(specks > 0 and facets > 0 and facets < specks,
		"the speck and facet bits both fire and neither is everything: %d specks, %d of them lit"
			% [specks, facets])


func _test_the_a_channel_marks_the_walked_surface_row_and_the_root_column() -> void:
	var f: Array = _fixture()
	var obs: Interface.Observation = f[0]
	var img: Image = f[2]
	var span: Rect2i = (f[3] as BakeData).span
	var columns: int = 0
	var wrong: int = 0
	var roots: int = 0
	var first: String = ""
	for x: int in span.size.x:
		var col: int = span.position.x + x
		var srow: int = SurfaceTone.column_surface_row(obs, col)
		if srow == SurfaceTone.NONE or not span.has_point(Vector2i(col, srow)):
			continue
		columns += 1
		roots += 1 if SurfaceTone.root_here(col) else 0
		var a_surface: int = int(round(img.get_pixel(x, srow - span.position.y).a * 255.0))
		var code: int = a_surface & 0x7f
		var root: bool = (a_surface & BakeData.A_ROOT_BIT) != 0
		var above: int = int(round(img.get_pixel(x, srow - 1 - span.position.y).a * 255.0)) & 0x7f
		var deep_row: int = mini(srow + BakeData.A_BEYOND, span.end.y - 1)
		var deep: int = int(round(img.get_pixel(x, deep_row - span.position.y).a * 255.0)) & 0x7f
		if (code == BakeData.A_SURFACE and root == SurfaceTone.root_here(col) and above == BakeData.A_NONE
				and deep == BakeData.A_BEYOND):
			continue
		wrong += 1
		if first == "":
			first = ("col %d (surface row %d): code %d (want %d), above %d (want %d), row +%d %d (want %d)"
				% [col, srow, code, BakeData.A_SURFACE, above, BakeData.A_NONE,
					deep_row - srow, deep, BakeData.A_BEYOND])
	_check_over(columns, wrong == 0,
		"every walked column codes its surface row 1, the air above 0 and the deep row BEYOND; %d wrong%s"
			% [wrong, "" if first == "" else " (first: %s)" % first])
	_check(roots > 0 and roots < columns,
		"the root bit is a per-column hash, not a constant: %d of %d columns root" % [roots, columns])
	_check(BakeData.depth_of_a(BakeData.A_SURFACE) == -1 and BakeData.depth_of_a(BakeData.A_SURFACE + 1) == 0
			and BakeData.depth_of_a(BakeData.A_BEYOND) == SurfaceTone.SOIL_ROWS
			and BakeData.depth_of_a(BakeData.A_ROOT_BIT | BakeData.A_SURFACE) == -1,
		"the shader's `code - 2` is the CPU's `row - (srow + 1)`: surface -1, next 0, BEYOND %d, root bit"
			% SurfaceTone.SOIL_ROWS + " ignored")


func _test_the_palette_row_is_the_records_own_colour_and_depth_darken() -> void:
	var data: BakeData = BakeData.new()
	data.setup()
	var img: Image = data.palette().get_image()
	var checked: int = 0
	var wrong: int = 0
	var caps: int = 0
	var nuggets: int = 0
	for id: String in MaterialsRecords.RECORDS:
		var rec: Dictionary = MaterialsRecords.RECORDS[id]
		var i: int = data.index_of(StringName(id))
		checked += 1
		var base: Color = img.get_pixel(i, 0)
		var nug: Color = img.get_pixel(i, 1)
		var cap: Color = img.get_pixel(i, 2)
		nuggets += 1 if rec.has("nugget_color") else 0
		caps += 1 if rec.has("cap_color") else 0
		var want_base: Color = OrePainter.record_color(rec["base_color"])
		var ok: bool = (is_equal_approx(base.r, want_base.r) and is_equal_approx(base.g, want_base.g)
			and is_equal_approx(base.b, want_base.b)
			and is_equal_approx(base.a, float(rec.get("depth_darken", 0.0)))
			and is_equal_approx(nug.a, 1.0 if rec.has("nugget_color") else 0.0)
			and cap.is_equal_approx(SurfaceTone.cap_color(StringName(id))))
		if not ok:
			wrong += 1
			printerr("    palette %s (index %d): base %s want %s a=%f, nug.a %f, cap %s"
				% [id, i, base, want_base, float(rec.get("depth_darken", 0.0)), nug.a, cap])
	_check_over(checked, wrong == 0,
		"every record's palette column is its own base colour, depth_darken in alpha, nugget flag and cap;"
			+ " %d wrong of %d" % [wrong, checked])
	_check(nuggets > 0 and caps > 0 and nuggets < checked and caps < checked,
		"the two flags separate records rather than marking all of them: %d of %d carry a nugget, %d a cap"
			% [nuggets, checked, caps])


func _test_the_seed_truncates_to_thirty_two_bits_signed() -> void:
	# The rival explanation is "the seed is passed whole": these three are the values a 64-bit seed and its
	# low 32 bits DIFFER on. `BedSequence._unit` masks at every step, so only the low 32 bits can matter.
	_check(BakeData.seed32(7) == 7, "a small seed is itself: %d" % BakeData.seed32(7))
	_check(BakeData.seed32(0x1_0000_0000 + 7) == 7,
		"a seed one above 2^32 truncates to the same 7: %d" % BakeData.seed32(0x1_0000_0000 + 7))
	_check(BakeData.seed32(0xFFFF_FFFF) == -1,
		"the top bit set comes back signed, so `uint()` in GLSL recovers the pattern: %d"
			% BakeData.seed32(0xFFFF_FFFF))
	_check(BakeData.seed32(0x8000_0000) == -2147483648,
		"and at the boundary: %d" % BakeData.seed32(0x8000_0000))


func _test_with_the_flag_off_bake_chunk_keeps_the_cpu_painter_and_builds_nothing() -> void:
	_check(not BakeChunk.shader_tone(),
		"the shipped flag is OFF: BakeChunk.SHADER_TONE %s and no --shader-tone on this command line"
			% BakeChunk.SHADER_TONE)
	var f: Array = _fixture()
	var obs: Interface.Observation = f[0]
	var look: MaterialLook = f[1]
	var w: BakeWindow = BakeWindow.new()
	w.plan(Vector2i(GRID_W, GRID_H), CELL)
	w.set_margin(WorldView.WINDOW_MARGIN_CELLS)
	var chunk: BakeChunk = BakeChunk.new()
	var baked: Array[Callable] = [WallPainter.paint, TerrainPainter.paint]
	chunk.setup(w, func(_r: Rect2) -> Interface.Observation: return obs, look, null, baked, null)
	_check(chunk.cpu_tone and chunk.data == null and chunk.painters.has(TerrainPainter.paint),
		"the flag off leaves the CPU terrain painter in the baked list (%d painters) and `data` null"
			% chunk.painters.size())
	# Driven with an EMPTY painter list, because a baked painter's `draw_rect` is only legal inside a
	# `_draw` pass and this suite has no viewport: what is under test is the branch, not the drawing.
	var counted: BakeChunk = BakeChunk.new()
	counted.setup(w, func(_r: Rect2) -> Interface.Observation: return obs, look, null,
		[] as Array[Callable], null)
	var canvas: Node2D = Node2D.new()
	counted.paint(canvas, 0, w.chunk_rect(0))
	canvas.free()
	_check(counted.cpu_paints == 1 and counted.data_builds == 0,
		"a chunk painted with the flag off took the CPU path once and built no data texture: %d CPU, %d built"
			% [counted.cpu_paints, counted.data_builds])
	# The split itself, both ways, as the pure decision it is -- the ON side cannot be reached through
	# `shader_tone()` from a suite, so it is asserted here where a mutation can move it.
	var on: Array = BakeChunk.tone_painters(baked, true)
	var off: Array = BakeChunk.tone_painters(baked, false)
	_check((on[0] as Array).size() == 2 and not (on[0] as Array).has(TerrainPainter.paint)
			and (on[0] as Array).has(TerrainPainter.paint_tufts)
			and (on[0] as Array).has(WallPainter.paint) and not bool(on[1]),
		"the flag ON replaces solid shading but retains surface tufts and WallPainter.paint: %s left"
			% [(on[0] as Array).size()])
	_check((off[0] as Array).size() == 2 and bool(off[1]),
		"the flag OFF changes nothing: %d painters, cpu_tone %s" % [(off[0] as Array).size(), off[1]])
	var none: Array = BakeChunk.tone_painters([WallPainter.paint] as Array[Callable], true)
	_check((none[0] as Array).size() == 1 and bool(none[1]),
		"a list with no terrain painter keeps the CPU path rather than losing a pass: cpu_tone %s" % none[1])
