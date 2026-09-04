extends "res://tests/test_base.gd"
## D0378. `view/visuals/surface_tone.gd` and the terrain painter's cap: the ground is ground. The claims
## are legacy's: humus darkens right under the cap and ramps back out; the subsoil below it warms toward
## ochre; the profile is gone past ten metres and absent in a hole column; moss tints exposed tops in the
## damp shallows and is dead at fourteen metres; a tuft hangs under a lip; the walked surface is read back
## to a row and band-gated; clay has a cap and hardrock does not; one column in five roots, one in three
## blades; the same seed paints the same cell and another seed does not; the painter's cell fill takes the
## cap on the surface cell and runs unchanged without a tone.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_surface_tone.gd
const CELL: int = Heightfield.TERRAIN_CELL_PX
const GRID_W: int = 40
const ROCK_TOP: int = MaterialLook.SURFACE_ROW + 4     ## a metre below the datum: inside the walked band
const GRID_H: int = ROCK_TOP + 80


func _initialize() -> void:
	_test_the_soil_profile()
	_test_moss_and_tufts()
	_test_the_walked_surface_and_the_cap()
	_test_determinism()
	_test_the_painters_cell_fill()
	_finish("surface_tone")


func _solid_all(_c: int, _r: int) -> bool:
	return true


func _mean_over_cols(tone: SurfaceTone, base: Color, depth: int, srow: int) -> Color:
	var sum := Vector3.ZERO
	for col: int in range(200):
		var c: Color = tone.soil(base, col, srow + 1 + depth, depth)
		sum += Vector3(c.r, c.g, c.b)
	sum /= 200.0
	return Color(sum.x, sum.y, sum.z)


func _test_the_soil_profile() -> void:
	var tone: SurfaceTone = SurfaceTone.new(7)
	var base := Color(0.50, 0.42, 0.30)
	var humus: Color = _mean_over_cols(tone, base, 2, ROCK_TOP)
	var deep: Color = _mean_over_cols(tone, base, 60, ROCK_TOP)
	_check(humus.get_luminance() < base.get_luminance() - 0.02, "two cells under the cap the humus is darker than the earth (%.3f vs %.3f)" % [humus.get_luminance(), base.get_luminance()])
	_check(deep == base or absf(deep.get_luminance() - base.get_luminance()) < 0.0005, "sixty cells down the profile is gone (%.4f)" % deep.get_luminance())
	var sub: Color = _mean_over_cols(tone, base, 8, ROCK_TOP)
	_check(sub.r - sub.b > base.r - base.b + 0.005, "the subsoil warms toward ochre: red over blue widens (%.3f vs %.3f)" % [sub.r - sub.b, base.r - base.b])
	_check(tone.soil(base, 3, 50, -1) == base, "a cell above its column's surface takes no profile")
	_check(tone.shade(base, 3, ROCK_TOP + 5, SurfaceTone.NONE, Callable()) == base, "a hole column (NONE) takes no profile and, with no probe, nothing else")
	# Means over columns, because the roots ride the same cells and a single column reads its root.
	var d0: float = _mean_over_cols(tone, base, 0, ROCK_TOP).get_luminance()
	var d2: float = _mean_over_cols(tone, base, 2, ROCK_TOP).get_luminance()
	var d4: float = _mean_over_cols(tone, base, 4, ROCK_TOP).get_luminance()
	_check(d2 < d0 and d4 > d2, "the humus is ramped in and out: darkest two cells down, lighter at the cap and at the band's foot (%.3f, %.3f, %.3f)" % [d0, d2, d4])
	var roots: int = 0
	for col: int in range(400):
		var c: Color = tone.soil(base, col, ROCK_TOP + 1, 0)
		if c.get_luminance() < base.get_luminance() - 0.10:
			roots += 1
	_check(roots > 60 and roots < 240, "roots reach down from the turf in a good share of columns, as legacy measured, not all (%d of 400)" % roots)


func _test_moss_and_tufts() -> void:
	var tone: SurfaceTone = SurfaceTone.new(7)
	var base := Color(0.40, 0.40, 0.44)
	_check(is_equal_approx(SurfaceTone.moss_life(MaterialLook.SURFACE_ROW + 4), 1.0), "moss is fully alive a metre down")
	_check(SurfaceTone.moss_life(MaterialLook.SURFACE_ROW + 14 * 4) == 0.0, "...and dead at fourteen metres")
	var mid: float = SurfaceTone.moss_life(MaterialLook.SURFACE_ROW + 8 * 4)
	_check(mid > 0.0 and mid < 1.0, "...thinning between (%.2f at 8 m)" % mid)
	# A ledge: solid from `top_row` down, open above. The cell on the ledge top has open air above it.
	var top_row: int = MaterialLook.SURFACE_ROW + 12
	var ledge: Callable = func(_c: int, r: int) -> bool: return r >= top_row
	var greener: int = 0
	for col: int in range(200):
		var c: Color = tone.shade(base, col, top_row, SurfaceTone.NONE, ledge)
		if c.g - c.r > base.g - base.r + 0.01:
			greener += 1
	_check(greener > 60, "exposed ledge tops in the shallows tint toward moss in organic patches (%d of 200)" % greener)
	var interior: int = 0
	for col: int in range(200):
		if tone.shade(base, col, top_row + 10, SurfaceTone.NONE, ledge) != base:
			interior += 1
	_check(interior == 0, "ten cells into the rock nothing grows (%d changed)" % interior)
	var deep_row: int = MaterialLook.SURFACE_ROW + 20 * 4
	var deep_ledge: Callable = func(_c: int, r: int) -> bool: return r >= deep_row
	var deep_green: int = 0
	for col: int in range(200):
		if tone.shade(base, col, deep_row, SurfaceTone.NONE, deep_ledge) != base:
			deep_green += 1
	_check(deep_green == 0, "a ledge at twenty metres grows no moss: the deep is bare rock (%d)" % deep_green)
	# An overhang: solid from row 0 down to `lip_row`, open below it. The lip cell has open air under it.
	var lip_row: int = MaterialLook.SURFACE_ROW + 12
	var overhang: Callable = func(_c: int, r: int) -> bool: return r <= lip_row
	var tufts: int = 0
	for col: int in range(200):
		var c: Color = tone.shade(base, col, lip_row, SurfaceTone.NONE, overhang)
		if c.g - c.r > base.g - base.r + 0.005:
			tufts += 1
	_check(tufts > 0 and tufts < 150, "a few lips hang a tuft, sparsely (%d of 200)" % tufts)
	_check(SurfaceTone.air_distance(ledge, 5, top_row, -1, 3) == 0 and SurfaceTone.air_distance(ledge, 5, top_row + 2, -1, 3) == 2 and SurfaceTone.air_distance(ledge, 5, top_row + 3, -1, 3) == SurfaceTone.NONE, "the air distance counts cells to the opening and stops at its reach")


func _test_the_walked_surface_and_the_cap() -> void:
	var w: Array = _rock_world(&"clay", [] as Array[Vector2i], ROCK_TOP, GRID_W, GRID_H)
	var o: Interface.Observation = w[0]
	_check(SurfaceTone.column_surface_row(o, 5) == ROCK_TOP, "the column's surface reads back to its row (%d)" % SurfaceTone.column_surface_row(o, 5))
	_check(SurfaceTone.is_walked(MaterialLook.SURFACE_ROW - 20) and SurfaceTone.is_walked(MaterialLook.SURFACE_ROW + 8 * 4), "a hill above the datum and ground eight metres down are both walked")
	_check(not SurfaceTone.is_walked(MaterialLook.SURFACE_ROW + 9 * 4), "...nine metres down is a hole floor")
	var deep: Array = _rock_world(&"clay", [] as Array[Vector2i], MaterialLook.SURFACE_ROW + 12 * 4, GRID_W, MaterialLook.SURFACE_ROW + 12 * 4 + 20)
	_check(SurfaceTone.column_surface_row(deep[0], 5) == SurfaceTone.NONE, "a column whose first solid is twelve metres down has no walked line")
	_check(SurfaceTone.cap_color(&"clay").a > 0.0 and SurfaceTone.cap_color(&"hardrock").a == 0.0, "clay wears a cap; hardrock grows nothing")
	var roots: int = 0
	var tufts: int = 0
	for col: int in range(1000):
		if SurfaceTone.root_here(col):
			roots += 1
		if SurfaceTone.tuft_here(col):
			tufts += 1
	_check(roots > 140 and roots < 260, "about one column in five roots (%d of 1000)" % roots)
	_check(tufts > 250 and tufts < 420, "about one in three blades (%d of 1000)" % tufts)


func _test_determinism() -> void:
	var a: SurfaceTone = SurfaceTone.new(99)
	var b: SurfaceTone = SurfaceTone.new(99)
	var other: SurfaceTone = SurfaceTone.new(100)
	var base := Color(0.5, 0.42, 0.3)
	var same: bool = true
	var differs: int = 0
	for col: int in range(60):
		for depth: int in range(12):
			var ca: Color = a.soil(base, col, ROCK_TOP + 1 + depth, depth)
			if ca != b.soil(base, col, ROCK_TOP + 1 + depth, depth):
				same = false
			if ca != other.soil(base, col, ROCK_TOP + 1 + depth, depth):
				differs += 1
	_check(same, "the same seed paints the same cell")
	_check(differs > 0, "...and another seed paints another picture (%d cells differ)" % differs)
	_check(RockTone.new(99).surface != null, "the rock tone owns a surface tone seeded with it")


func _test_the_painters_cell_fill() -> void:
	var w: Array = _rock_world(&"clay", [] as Array[Vector2i], ROCK_TOP, GRID_W, GRID_H)
	var f: Frame = Frame.new()
	f.obs = w[0]
	f.look = w[1]
	f.tone = RockTone.new(f.obs.world_seed)
	var solid: Callable = func(c: int, r: int) -> bool: return f.obs.material_at(Vector2i(c, r)) != &""
	var cap: Color = SurfaceTone.cap_color(&"clay")
	_check(TerrainPainter.cell_fill(f, &"clay", 5, ROCK_TOP, ROCK_TOP, solid) == cap, "the walked surface cell of clay IS the cap")
	var under: Color = TerrainPainter.cell_fill(f, &"clay", 5, ROCK_TOP + 3, ROCK_TOP, solid)
	_check(under != cap, "...and the cell under it is earth, not cap")
	var col_root: int = -1
	for col: int in range(200):
		if SurfaceTone.root_here(col):
			col_root = col
			break
	var rooted: Color = TerrainPainter.cell_fill(f, &"clay", col_root, ROCK_TOP + 1, ROCK_TOP, solid)
	var plain: Color = TerrainPainter.cell_fill(f, &"clay", col_root, ROCK_TOP + 1, SurfaceTone.NONE, solid)
	_check(col_root >= 0 and rooted != plain, "a rooting column's cell under the cap is pulled toward the cap's dark (col %d)" % col_root)
	f.tone = null
	_check(TerrainPainter.cell_fill(f, &"clay", 5, ROCK_TOP, ROCK_TOP, solid) == f.look.cell_color(&"clay", 5, ROCK_TOP), "with no tone the fill is the flat pre-port picture, cap and all left out")
