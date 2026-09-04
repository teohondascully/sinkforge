extends "res://tests/test_base.gd"

## `sim/terrain_gen/vertical_passes.gd` -- legacy's rifts, their wall ore and the sinkhole mouths on the
## deterministic generator, A' step 8c (D0383). Built the way `test_cave_passes.gd` is: a pass that ran
## and carved nothing is the silent failure, so every row counts cells or measures a property that is
## zero when nothing opened. The mouths are posed on hand-cut slots so each rule (the keepout, the drop
## floor, the spacing, the cap, the deepest-first ranking) is exercised by a slot built to trip it.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_vertical_passes.gd

const CPM: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
const W: int = 256
const H: int = 480              # 20 m of sky and 100 m of rock
const DATUM: int = 80
const BAND: int = 24            # the cave band: 6 m under the surface
const SPAWN: int = 128


func _initialize() -> void:
	_test_the_flare_table_is_pow_2_2_and_interpolates()
	_test_rifts_open_cells_and_report_every_one_of_them()
	_test_rifts_refuse_the_cave_band_under_every_column()
	_test_a_rift_pinches_and_opens()
	_test_with_no_wander_no_rift_starts_inside_the_spawn_keepout()
	_test_wall_ore_lands_only_beside_carved_cells_and_by_depth()
	_test_a_mouth_opens_over_the_deepest_drop_and_flares_toward_the_sky()
	_test_the_keepout_the_drop_floor_the_spacing_and_the_cap()
	_test_the_whole_pass_on_a_generated_world()
	_test_the_same_seed_carves_the_same_rifts()
	_finish("vertical_passes")


## Legacy's constants verbatim (`layered_world_gen.gd:91-100, 487-494`) in the record the generator reads.
func _rift_cfg() -> Dictionary:
	return {
		"per_col": 0.018, "min_len_m": 34, "max_len_m": 80, "half_w_min_m": 0.8, "half_w_max_m": 2.1,
		"wander": 0.34, "wander_nudge": 0.10, "spawn_keepout_m": 10, "top_min_m": 2, "top_max_m": 10,
		"pinch_min": 0.16, "pinch_max": 0.30, "wall_ore_chance": 0.11,
	}


func _sink_cfg() -> Dictionary:
	return {
		"count": 3, "mouth_half_m": 3.0, "throat_half_m": 1.1, "keepout_m": 20, "spacing_m": 15,
		"wander": 0.22, "wander_nudge": 0.08, "min_drop_m": 14,
	}


func _solid_world() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 7)
	for col: int in W:
		for row: int in range(DATUM, H):
			grid.set_material(Vector2i(col, row), &"hardrock")
			grid.set_wall(Vector2i(col, row), &"hardrock")
	return grid


func _flat() -> PackedInt32Array:
	return Relief.flat(W, DATUM)


func _rng(seed: int) -> SplitRng:
	return SplitRng.new(seed).split("vertical")


func _rifts(grid: TileGrid, seed: int, cfg: Dictionary = _rift_cfg()) -> Array[Vector2i]:
	return VerticalPasses.carve_rifts(grid, _rng(seed), cfg, _flat(), BAND, SPAWN, CPM)


func _test_the_flare_table_is_pow_2_2_and_interpolates() -> void:
	var t: PackedInt32Array = VerticalPasses.FLARE_MILLI
	_check(t.size() == 65 and t[0] == 0 and t[64] == 1000, "65 entries from 0 to 1000 (%d, %d, %d)" % [t.size(), t[0], t[64]])
	_check(t[32] == 218, "the midpoint is 0.5^2.2 = 0.2176 (%d)" % t[32])
	var falls: int = 0
	for i: int in range(1, 65):
		if t[i] < t[i - 1]:
			falls += 1
	_check(falls == 0, "monotone (%d falls)" % falls)
	_check(VerticalPasses.flare_milli(0) == 0 and VerticalPasses.flare_milli(1000) == 1000, "the ends")
	_check(VerticalPasses.flare_milli(500) == 218, "an entry point reads the entry (%d)" % VerticalPasses.flare_milli(500))
	var between: int = VerticalPasses.flare_milli(507)
	_check(between > 218 and between < 233, "between two entries interpolates (%d)" % between)
	_check(VerticalPasses.flare_milli(250) < 250, "the cone stays narrow low down: a quarter of the way up is %d of 1000" % VerticalPasses.flare_milli(250))


func _test_rifts_open_cells_and_report_every_one_of_them() -> void:
	var grid: TileGrid = _solid_world()
	var carved: Array[Vector2i] = _rifts(grid, 3)
	_check(carved.size() > 2 * 34 * CPM, "at least two rifts of the minimum length worth of cells (%d)" % carved.size())
	var still_solid: int = 0
	var out: int = 0
	for c: Vector2i in carved:
		if not grid.in_bounds(c):
			out += 1
		elif grid.is_solid(c):
			still_solid += 1
	_check(still_solid == 0 and out == 0, "every reported cell is open and in bounds (%d solid, %d out)" % [still_solid, out])
	var open: int = 0
	for col: int in W:
		for row: int in range(DATUM, H):
			if not grid.is_solid(Vector2i(col, row)):
				open += 1
	var distinct: Dictionary = {}
	for c: Vector2i in carved:
		distinct[c] = true
	_check(open == distinct.size(), "and the open cells ARE the reported cells: %d open, %d distinct reported" % [open, distinct.size()])


func _test_rifts_refuse_the_cave_band_under_every_column() -> void:
	# A small pad and a one-metre ramp, so nearly every column off the pad is off the datum: the band
	# under a rift's neighbouring columns then differs from the band under its own.
	var rows: PackedInt32Array = Relief.surface_rows({"relief": {
		"pad_centre_m": 32, "pad_half_m": 2, "ramp_m": 1,
		"waves": [{"amp_m": 1.6, "freq_rad_per_m": 0.30, "phase_rad": 0.0, "ramp": "far"},
			{"amp_m": 0.9, "freq_rad_per_m": 0.11, "phase_rad": 1.7, "ramp": "far"}],
		"scarps": [{"at_m": 10, "step_m": 5}, {"at_m": 45, "step_m": 4}], "scarp_span_m": 2,
		"max_rise_m": 9, "max_fall_m": 11}}, W, DATUM, CPM)
	var grid: TileGrid = TileGrid.new(W, H, 7)
	for col: int in W:
		for row: int in range(rows[col], H):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var carved: Array[Vector2i] = VerticalPasses.carve_rifts(grid, _rng(5), _rift_cfg(), rows, BAND, SPAWN, CPM)
	var breached: int = 0
	for c: Vector2i in carved:
		if c.y < rows[c.x] + BAND:
			breached += 1
	_check(carved.size() > 0 and breached == 0, "no carved cell inside the band under its own column (%d of %d)" % [breached, carved.size()])
	# CONTROL: the rifts run under columns whose surface is off the datum, so the per-column band -- not
	# the datum's -- is what the row above tested.
	var off_datum: int = 0
	for c: Vector2i in carved:
		if rows[c.x] != DATUM:
			off_datum += 1
	_check(off_datum > carved.size() / 2, "CONTROL: %d of %d carved cells sit under columns whose surface is off the datum"
		% [off_datum, carved.size()])


## Per row, the carved columns form contiguous runs, one per rift; the narrowest run is a squeeze and the
## widest a hall, or the sine never moved the width.
func _test_a_rift_pinches_and_opens() -> void:
	var grid: TileGrid = _solid_world()
	var carved: Array[Vector2i] = _rifts(grid, 3)
	var by_row: Dictionary = {}
	for c: Vector2i in carved:
		if not by_row.has(c.y):
			by_row[c.y] = []
		(by_row[c.y] as Array).append(c.x)
	var narrowest: int = 1 << 30
	var widest: int = 0
	for row: Variant in by_row:
		# Two rifts crossing report their shared cells twice; a duplicate would read as a one-cell run.
		var seen: Dictionary = {}
		for x: Variant in by_row[row]:
			seen[int(x)] = true
		var cols: Array = seen.keys()
		cols.sort()
		var run: int = 1
		for i: int in range(1, cols.size()):
			if int(cols[i]) == int(cols[i - 1]) + 1:
				run += 1
			else:
				narrowest = mini(narrowest, run)
				widest = maxi(widest, run)
				run = 1
		narrowest = mini(narrowest, run)
		widest = maxi(widest, run)
	_check(narrowest <= 2 * 4 + 1, "a squeeze at most 2 x 0.8 m + 1 wide (%d cells)" % narrowest)
	_check(widest >= 15, "and a hall at least 2 x 2.1 m - 2 wide (%d cells)" % widest)


func _test_with_no_wander_no_rift_starts_inside_the_spawn_keepout() -> void:
	var cfg: Dictionary = _rift_cfg()
	cfg["wander"] = 0.0
	cfg["wander_nudge"] = 0.0
	var grid: TileGrid = _solid_world()
	var inside: int = 0
	var carved: Array[Vector2i] = _rifts(grid, 11, cfg)
	var keepout: int = 10 * CPM
	var half_max: int = int(ceil(2.1 * CPM))
	for c: Vector2i in carved:
		if absi(c.x - SPAWN) < keepout - half_max:
			inside += 1
	_check(carved.size() > 0 and inside == 0, "no rift cell within the keepout less a half-width of spawn (%d of %d)" % [inside, carved.size()])


func _test_wall_ore_lands_only_beside_carved_cells_and_by_depth() -> void:
	var grid: TileGrid = _solid_world()
	var slot: Array[Vector2i] = []
	for row: int in range(200, 300):
		var c := Vector2i(60, row)
		grid.excavate(c)
		slot.append(c)
	var cfg: Dictionary = _rift_cfg()
	cfg["wall_ore_chance"] = 1.0
	var deep_row: int = 250
	var placed: int = VerticalPasses.ore_rift_walls(grid, _rng(1), cfg, slot, deep_row)
	# 100 rows x two side walls, plus the cell above the slot and the one below it.
	_check(placed == 202, "every host-rock neighbour turned at chance 1.0 (%d of 202)" % placed)
	_check(grid.get_material(Vector2i(59, 210)) == &"ore_copper" and grid.get_material(Vector2i(61, 210)) == &"ore_copper",
		"copper above deep_row")
	_check(grid.get_material(Vector2i(59, 290)) == &"ore_iron" and grid.get_material(Vector2i(61, 290)) == &"ore_iron",
		"iron from deep_row down")
	_check(grid.get_material(Vector2i(58, 250)) == &"hardrock" and grid.get_material(Vector2i(62, 250)) == &"hardrock",
		"two cells out is untouched")
	var none: TileGrid = _solid_world()
	cfg["wall_ore_chance"] = 0.0
	_check(VerticalPasses.ore_rift_walls(none, _rng(1), cfg, slot, deep_row) == 0, "CONTROL: chance 0 turns nothing")


## A hand-cut slot, 3 wide, 45 m tall, its ceiling 10 m under the surface.
func _slot(grid: TileGrid, col: int, top: int, bottom: int, carved: Array[Vector2i]) -> void:
	for row: int in range(top, bottom):
		for dx: int in [-1, 0, 1]:
			var c := Vector2i(col + dx, row)
			grid.excavate(c)
			carved.append(c)


func _open_run_at(grid: TileGrid, row: int, around: int) -> int:
	var lo: int = around
	while lo > 0 and not grid.is_solid(Vector2i(lo - 1, row)):
		lo -= 1
	var hi: int = around
	while hi < W - 1 and not grid.is_solid(Vector2i(hi + 1, row)):
		hi += 1
	return hi - lo + 1 if not grid.is_solid(Vector2i(around, row)) else 0


func _test_a_mouth_opens_over_the_deepest_drop_and_flares_toward_the_sky() -> void:
	var grid: TileGrid = _solid_world()
	var carved: Array[Vector2i] = []
	_slot(grid, 40, DATUM + 40, DATUM + 220, carved)
	var opened: Array[int] = VerticalPasses.open_sinkholes(grid, _rng(2), _sink_cfg(), carved, _flat(), SPAWN, CPM)
	# The slot's three columns tie on the drop, and ties go leftmost: the plumb is its left column.
	_check(opened.size() == 1 and opened[0] == 39, "one mouth, over the slot's leftmost column (%s)" % str(opened))
	var plumb: int = opened[0] if opened.size() > 0 else 39
	_check(VerticalPasses.drop_below(grid, plumb, DATUM) >= 220, "and it is open from the surface to the slot's floor (%d rows)"
		% VerticalPasses.drop_below(grid, plumb, DATUM))
	var at_sky: int = _open_run_at(grid, DATUM, plumb)
	var at_throat: int = _open_run_at(grid, DATUM + 36, plumb)
	_check(at_sky >= 20, "the mouth at the sky is at least 2 x 3 m - 4 wide (%d cells)" % at_sky)
	_check(at_throat <= 12, "the throat where it meets the rift is at most 2 x 1.1 m + 3 wide (%d cells)" % at_throat)
	_check(at_sky > at_throat, "so it flares (%d over %d)" % [at_sky, at_throat])
	# The drop floor, isolated: a lone slot with a 10 m fall under its ceiling is a pit, not a route.
	var shallow: TileGrid = _solid_world()
	var pit: Array[Vector2i] = []
	_slot(shallow, 40, DATUM + 40, DATUM + 80, pit)
	var none: Array[int] = VerticalPasses.open_sinkholes(shallow, _rng(2), _sink_cfg(), pit, _flat(), SPAWN, CPM)
	_check(none.is_empty() and shallow.is_solid(Vector2i(39, DATUM)), "a 10 m drop opens no mouth (%s)" % str(none))


## Spawn at 2 m so the 20 m keepout leaves columns 88 on eligible, and the spacing tightened to 10 m so
## four clear candidates fit and the cap of three is the rule that refuses the fourth.
func _test_the_keepout_the_drop_floor_the_spacing_and_the_cap() -> void:
	var grid: TileGrid = _solid_world()
	var carved: Array[Vector2i] = []
	var cfg: Dictionary = _sink_cfg()
	cfg["spacing_m"] = 10
	_slot(grid, 40, DATUM + 40, DATUM + 300, carved)     # deep but inside the keepout: never opened
	_slot(grid, 170, DATUM + 40, DATUM + 300, carved)    # the deepest: cut first
	_slot(grid, 200, DATUM + 40, DATUM + 200, carved)    # 7.5 m from it: refused by the spacing
	_slot(grid, 250, DATUM + 40, DATUM + 190, carved)    # clear: the second
	_slot(grid, 100, DATUM + 40, DATUM + 180, carved)    # clear: the third
	_slot(grid, 210, DATUM + 40, DATUM + 170, carved)    # clear of all three, refused by the cap alone
	var opened: Array[int] = VerticalPasses.open_sinkholes(grid, _rng(2), cfg, carved, _flat(), 2 * CPM, CPM)
	_check(opened.size() == 3, "the cap: three mouths (%s)" % str(opened))
	_check(opened.size() > 0 and absi(opened[0] - 170) <= 1, "the deepest drop is cut first (%s)" % str(opened))
	_check(_none_near(opened, 40), "the slot inside the spawn keepout stays sealed (%s)" % str(opened))
	_check(_none_near(opened, 200), "the slot 7.5 m from the first is refused by the spacing (%s)" % str(opened))
	_check(_none_near(opened, 210), "the fourth clear slot is refused by the cap (%s)" % str(opened))
	_check(not _none_near(opened, 250) and not _none_near(opened, 100), "CONTROL: the two clear slots are the other two (%s)" % str(opened))
	_check(grid.is_solid(Vector2i(39, DATUM)) and grid.is_solid(Vector2i(209, DATUM)), "the refused slots' surfaces are solid")


func _none_near(opened: Array[int], col: int) -> bool:
	for c: int in opened:
		if absi(c - col) <= 1:
			return false
	return true


## The generator with the record: rifts and mouths exist in a real world. Spawn is put at the left edge
## so the keepouts leave most of the width eligible.
func _vertical_site() -> Dictionary:
	var site: Dictionary = StrataData.SHALLOW_CLAY.duplicate(true)
	site["max_depth_m"] = 128
	site["layer_thresholds_m"] = {"topsoil_shale_end": 30, "stonereach_end": 80}
	site["spawn_col_m"] = 4
	site["vertical"] = {"rift": _rift_cfg(), "sinkhole": _sink_cfg()}
	return site


func _open_count(grid: TileGrid) -> int:
	var n: int = 0
	for col: int in grid.width:
		for row: int in range(ShaftGenerator.SKY_ROWS, grid.height):
			if not grid.is_solid(Vector2i(col, row)):
				n += 1
	return n


func _test_the_whole_pass_on_a_generated_world() -> void:
	var with: TileGrid = ShaftGenerator.generate(_vertical_site(), 20260826)
	var plain_site: Dictionary = _vertical_site()
	plain_site.erase("vertical")
	var without: TileGrid = ShaftGenerator.generate(plain_site, 20260826)
	_check(_open_count(with) > _open_count(without) + 500,
		"the record opens at least 500 more cells than the same site without it (%d over %d)" % [_open_count(with), _open_count(without)])
	var mouths: int = 0
	for col: int in with.width:
		if not with.is_solid(Vector2i(col, ShaftGenerator.SKY_ROWS)) and VerticalPasses.drop_below(with, col, ShaftGenerator.SKY_ROWS) >= 14 * CPM:
			mouths += 1
	_check(mouths > 0, "at least one column is open from the surface for 14 m or more: a mouth (%d columns)" % mouths)
	_check(mouths <= 3 * 30, "and not more than three mouths' worth of columns (%d)" % mouths)
	# The wall ore: copper or iron cells that the plain world does not have where the rifts are.
	var ore_gained: int = 0
	for col: int in with.width:
		for row: int in range(ShaftGenerator.SKY_ROWS, with.height):
			var c := Vector2i(col, row)
			if WorldMaterials.is_ore_like(with.get_material(c)) and not WorldMaterials.is_ore_like(without.get_material(c)):
				ore_gained += 1
	_check(ore_gained > 0, "the rift walls carry ore the plain world lacks (%d cells)" % ore_gained)


func _test_the_same_seed_carves_the_same_rifts() -> void:
	var a: TileGrid = _solid_world()
	var b: TileGrid = _solid_world()
	var ra: Array[Vector2i] = _rifts(a, 9)
	var rb: Array[Vector2i] = _rifts(b, 9)
	_check(ra == rb and a.state_signature() == b.state_signature(), "same seed, same cells, same world")
	var c: TileGrid = _solid_world()
	_check(_rifts(c, 10) != ra, "CONTROL: another seed carves elsewhere")
