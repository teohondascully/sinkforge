extends "res://tests/test_base.gd"

## `sim/terrain_gen/studding_passes.gd` -- legacy's ledges, spires, rubble and the drought pass on the
## deterministic generator, A' step 8d (D0384). The studding passes are posed on a hand-carved chamber
## with clay above the mid-line and deepstone below it, so what grows from the ceiling and what grows
## from the floor can be told apart by material; the drought pass on solid rock, where every column
## starts as one long run of it.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_studding_passes.gd

const CPM: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
const W: int = 128
const H: int = 240              # 20 m of sky and 40 m of rock
const DATUM: int = 80
const BAND: int = 24
const MID: int = 160            # clay above, deepstone from here down
const BOX := Rect2i(30, 130, 60, 60)   # the chamber: cols 30..89, rows 130..189


func _initialize() -> void:
	_test_structural_rock_is_the_host_or_the_mid_rock()
	_test_open_cells_is_the_chamber_and_nothing_in_the_band()
	_test_ledges_grow_from_a_wall_a_metre_thick_and_need_headroom()
	_test_a_tooth_tapers_from_a_metre_to_a_cell()
	_test_spires_hang_in_the_ceilings_rock_and_rise_in_the_floors()
	_test_rubble_rests_on_the_floor_in_the_floors_rock()
	_test_no_column_runs_dry_after_the_drought_pass()
	_test_the_whole_pass_on_a_generated_world()
	_test_the_same_seed_studs_the_same_world()
	_finish("studding_passes")


func _ledge_cfg() -> Dictionary:
	return {"per_col": 0.22, "len_min_m": 2, "len_max_m": 4, "headroom_m": 2, "thickness_m": 1}


func _spire_cfg() -> Dictionary:
	return {"chance": 0.075, "floor_bias": 0.34, "hang_min_m": 2, "hang_max_m": 5, "rise_min_m": 1, "rise_max_m": 2}


func _rubble_cfg() -> Dictionary:
	return {"chance": 0.060, "size_m": 1}


func _drought_cfg() -> Dictionary:
	return {"limit_m": 18, "vug_chance": 0.28, "vein_size_m2": 5, "coal_bias": 0.38, "back_min_m": 3, "back_max_m": 14}


func _solid_world() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 7)
	for col: int in W:
		for row: int in range(DATUM, H):
			var cell := Vector2i(col, row)
			grid.set_material(cell, &"clay" if row < MID else &"deepstone")
			grid.set_wall(cell, &"hardrock")
	return grid


func _chamber_world(box: Rect2i = BOX) -> TileGrid:
	var grid: TileGrid = _solid_world()
	for col: int in range(box.position.x, box.end.x):
		for row: int in range(box.position.y, box.end.y):
			grid.excavate(Vector2i(col, row))
	return grid


func _flat() -> PackedInt32Array:
	return Relief.flat(W, DATUM)


func _rng(seed: int) -> SplitRng:
	return SplitRng.new(seed).split("studding")


func _sites(grid: TileGrid) -> Array[Vector2i]:
	return StuddingPasses.open_terrain_cells(grid, _flat(), BAND)


## Solid cells in `after` that were open in `before`.
func _grown(before: TileGrid, after: TileGrid) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col: int in W:
		for row: int in range(DATUM, H):
			var c := Vector2i(col, row)
			if after.is_solid(c) and not before.is_solid(c):
				out.append(c)
	return out


func _test_structural_rock_is_the_host_or_the_mid_rock() -> void:
	_check(StuddingPasses.structural_rock(&"clay") == &"clay" and StuddingPasses.structural_rock(&"deepstone") == &"deepstone",
		"host rock builds in itself")
	_check(StuddingPasses.structural_rock(&"ore_copper") == &"hardrock" and StuddingPasses.structural_rock(&"coal") == &"hardrock",
		"a reward builds in the mid rock")
	_check(StuddingPasses.structural_rock(&"") == &"hardrock", "and so does nothing at all")


func _test_open_cells_is_the_chamber_and_nothing_in_the_band() -> void:
	var grid: TileGrid = _chamber_world()
	var sites: Array[Vector2i] = _sites(grid)
	_check(sites.size() == 60 * 60, "the snapshot is the chamber's %d cells (%d)" % [60 * 60, sites.size()])
	var slit: TileGrid = _solid_world()
	for col: int in range(20, 40):
		slit.excavate(Vector2i(col, DATUM + 5))            # open, but inside the protected band
	_check(_sites(slit).is_empty(), "an opening inside the band is not a site (%d)" % _sites(slit).size())


## Posed in a corridor eight cells wide, where a quarter of the open cells touch a wall, with the rate
## raised so the pass draws often enough to find them; the real rate on the real world is 8h's to judge.
func _test_ledges_grow_from_a_wall_a_metre_thick_and_need_headroom() -> void:
	var corridor := Rect2i(30, 130, 8, 60)
	var grid: TileGrid = _chamber_world(corridor)
	var before: TileGrid = grid.clone()
	var cfg: Dictionary = _ledge_cfg()
	cfg["per_col"] = 8.0
	var placed: int = StuddingPasses.stud_ledges(grid, _rng(1), cfg, _sites(grid), CPM)
	var grown: Array[Vector2i] = _grown(before, grid)
	_check(placed > 0 and grown.size() == placed, "ledges grew %d cells (%d counted)" % [placed, grown.size()])
	var loose: int = 0
	var outside: int = 0
	var wrong_rock: int = 0
	var thin: int = 0
	for c: Vector2i in grown:
		if not corridor.has_point(c):
			outside += 1
		if not grid.is_solid(c + Vector2i(-1, 0)) and not grid.is_solid(c + Vector2i(1, 0)):
			loose += 1                                        # every ledge cell holds a wall or the next cell
		var top: bool = not grown.has(c + Vector2i(0, -1))
		if top and grid.get_material(c) != (&"clay" if c.y < MID else &"deepstone"):
			wrong_rock += 1                                   # the seeded row is the wall's own rock
		var room: bool = not before.is_solid(c + Vector2i(0, 1)) and not before.is_solid(c + Vector2i(0, 3))
		if top and room and not (grown.has(c + Vector2i(0, 1)) and grown.has(c + Vector2i(0, 2)) and grown.has(c + Vector2i(0, 3))):
			thin += 1
	_check(outside == 0 and loose == 0, "every ledge cell is inside the corridor and touches rock sideways (%d out, %d loose)" % [outside, loose])
	_check(wrong_rock == 0, "and a ledge is the rock of the wall it sprang from (%d wrong)" % wrong_rock)
	_check(thin == 0, "a ledge with room under it is %d cells thick (%d thinner)" % [CPM, thin])
	# CONTROL: a chamber lower than the headroom grows no shelf you could not stand on.
	var low: TileGrid = _chamber_world(Rect2i(30, 150, 8, 6))
	var none: int = StuddingPasses.stud_ledges(low, _rng(1), cfg, _sites(low), CPM)
	_check(none == 0, "CONTROL: a 6-row corridor under an 8-row headroom grows no ledge (%d)" % none)


func _test_a_tooth_tapers_from_a_metre_to_a_cell() -> void:
	var grid: TileGrid = _chamber_world()
	var placed: int = StuddingPasses._taper(grid, Vector2i(60, 130), 1, 12, CPM, &"clay")
	var widths: Array[int] = []
	for row: int in [130, 133, 136, 139]:
		var w: int = 0
		for col: int in range(50, 70):
			if grid.is_solid(Vector2i(col, row)):
				w += 1
		widths.append(w)
	_check(widths == ([4, 3, 2, 1] as Array[int]), "four cells at the root down to one at the tip (%s)" % str(widths))
	_check(placed == 4 * 3 + 3 * 3 + 2 * 3 + 1 * 3, "thirty cells in all (%d)" % placed)
	_check(not grid.is_solid(Vector2i(60, 142)), "and nothing past the run")


## Posed at chance 1.0, so both kinds certainly grow; at that chance a tooth's tip seeds the next tooth
## (legacy's passes read the world they write), so the rock is checked at the ROOTS, where it is decided.
func _test_spires_hang_in_the_ceilings_rock_and_rise_in_the_floors() -> void:
	var grid: TileGrid = _chamber_world()
	var before: TileGrid = grid.clone()
	var cfg: Dictionary = _spire_cfg()
	cfg["chance"] = 1.0
	cfg["floor_bias"] = 1.0
	var placed: int = StuddingPasses.stud_spires(grid, _rng(2), cfg, _sites(grid), CPM)
	var grown: Array[Vector2i] = _grown(before, grid)
	_check(placed > 0 and grown.size() == placed, "spires grew %d cells" % placed)
	var roof: int = 0
	var floor_row: int = 0
	var wrong: int = 0
	for c: Vector2i in grown:
		if c.y == BOX.position.y:
			roof += 1
			wrong += 1 if grid.get_material(c) != &"clay" else 0
		if c.y == BOX.end.y - 1:
			floor_row += 1
			wrong += 1 if grid.get_material(c) != &"deepstone" else 0
	_check(roof > 0 and floor_row > 0, "teeth root in the ceiling row (%d cells) and in the floor row (%d)" % [roof, floor_row])
	_check(wrong == 0, "hanging roots are the ceiling's clay and rising roots the floor's deepstone (%d wrong)" % wrong)
	# The floor bias: at 0 no tooth rises, while the roof still grows them.
	var biased: TileGrid = _chamber_world()
	cfg["floor_bias"] = 0.0
	var b_before: TileGrid = biased.clone()
	StuddingPasses.stud_spires(biased, _rng(2), cfg, _sites(biased), CPM)
	var rising: int = 0
	var hanging: int = 0
	for c: Vector2i in _grown(b_before, biased):
		if c.y == BOX.end.y - 1:
			rising += 1
		if c.y == BOX.position.y:
			hanging += 1
	_check(rising == 0 and hanging > 0, "floor bias 0 grows no rising tooth and %d hanging roots (%d rising)" % [hanging, rising])
	# CONTROL: a one-cell gap between two solids grows nothing.
	var slit: TileGrid = _solid_world()
	for col: int in range(20, 100):
		slit.excavate(Vector2i(col, 150))
	cfg["floor_bias"] = 1.0
	_check(StuddingPasses.stud_spires(slit, _rng(2), cfg, _sites(slit), CPM) == 0, "CONTROL: a slit grows no tooth")
	var zero: TileGrid = _chamber_world()
	cfg["chance"] = 0.0
	_check(StuddingPasses.stud_spires(zero, _rng(2), cfg, _sites(zero), CPM) == 0, "CONTROL: chance 0 grows none")


## At chance 1.0 a block's top is the next block's floor, so the columns stack; what holds at any chance is
## that every stack stands on the chamber floor and is the floor's rock.
func _test_rubble_rests_on_the_floor_in_the_floors_rock() -> void:
	var grid: TileGrid = _chamber_world()
	var before: TileGrid = grid.clone()
	var cfg: Dictionary = _rubble_cfg()
	cfg["chance"] = 1.0
	var placed: int = StuddingPasses.scatter_rubble(grid, _rng(3), cfg, _sites(grid), CPM)
	var grown: Array[Vector2i] = _grown(before, grid)
	_check(placed > 0 and grown.size() == placed, "rubble set %d cells" % placed)
	var lowest: Dictionary = {}
	var wrong: int = 0
	var unsupported: int = 0
	for c: Vector2i in grown:
		lowest[c.x] = maxi(int(lowest.get(c.x, 0)), c.y)
		if grid.get_material(c) != &"deepstone":
			wrong += 1
		if not grid.is_solid(c + Vector2i(0, 1)):
			unsupported += 1
	var floating: int = 0
	for col: Variant in lowest:
		if int(lowest[col]) != BOX.end.y - 1:
			floating += 1
	_check(floating == 0 and unsupported == 0, "every column of rubble stands on the chamber floor (%d floating, %d unsupported)" % [floating, unsupported])
	_check(wrong == 0, "and is the floor's rock (%d wrong)" % wrong)
	var zero: TileGrid = _chamber_world()
	cfg["chance"] = 0.0
	_check(StuddingPasses.scatter_rubble(zero, _rng(3), cfg, _sites(zero), CPM) == 0, "CONTROL: chance 0 sets none")


## The longest run of plain rock under the band in any column.
func _longest_plain_run(grid: TileGrid, surface: PackedInt32Array) -> int:
	var longest: int = 0
	for col: int in grid.width:
		var run: int = 0
		for row: int in range(surface[col] + BAND, grid.height):
			if StuddingPasses.is_plain(grid, Vector2i(col, row)):
				run += 1
				longest = maxi(longest, run)
			else:
				run = 0
	return longest


func _test_no_column_runs_dry_after_the_drought_pass() -> void:
	var grid: TileGrid = _solid_world()
	var limit: int = 18 * CPM
	_check(_longest_plain_run(grid, _flat()) > limit, "CONTROL: before the pass every column is one %d-cell run" % _longest_plain_run(grid, _flat()))
	var counts: Dictionary = StuddingPasses.seed_droughts(grid, _rng(4), _drought_cfg(), _flat(), BAND, MID, CPM)
	_check(_longest_plain_run(grid, _flat()) < limit, "after it no column runs %d cells of plain rock (longest %d)" % [limit, _longest_plain_run(grid, _flat())])
	_check(int(counts["vugs"]) > 0 and int(counts["veins"]) > 0, "it planted both vugs and veins (%s)" % str(counts))
	var coal: int = 0
	var copper: int = 0
	var iron: int = 0
	var band_open: int = 0
	for col: int in W:
		for row: int in range(DATUM, H):
			var m: StringName = grid.get_material(Vector2i(col, row))
			coal += 1 if m == &"coal" else 0
			copper += 1 if m == &"ore_copper" else 0
			iron += 1 if m == &"ore_iron" else 0
			if row < DATUM + BAND and not grid.is_solid(Vector2i(col, row)):
				band_open += 1
	_check(coal > 0 and copper > 0 and iron > 0, "coal, copper above the deep row and iron below it (%d, %d, %d)" % [coal, copper, iron])
	_check(band_open == 0, "no vug opened inside the cave band (%d cells)" % band_open)


func _studding_site() -> Dictionary:
	var site: Dictionary = _site_without_content(StrataData.SHALLOW_CLAY)
	site["max_depth_m"] = 96
	site["layer_thresholds_m"] = {"topsoil_shale_end": 30, "stonereach_end": 60}
	site["studding"] = {"ledge": _ledge_cfg(), "spire": _spire_cfg(), "rubble": _rubble_cfg(), "drought": _drought_cfg()}
	return site


func _test_the_whole_pass_on_a_generated_world() -> void:
	var with: TileGrid = ShaftGenerator.generate(_studding_site(), 20260826)
	var plain_site: Dictionary = _studding_site()
	plain_site.erase("studding")
	var without: TileGrid = ShaftGenerator.generate(plain_site, 20260826)
	_check(with.state_signature() != without.state_signature(), "the record changes the world")
	var flat: PackedInt32Array = Relief.flat(with.width, ShaftGenerator.SKY_ROWS)
	_check(_longest_plain_run(without, flat) >= 18 * CPM, "CONTROL: the plain world has a column running %d cells dry" % _longest_plain_run(without, flat))
	_check(_longest_plain_run(with, flat) < 18 * CPM, "the studded world has none (longest %d)" % _longest_plain_run(with, flat))


func _test_the_same_seed_studs_the_same_world() -> void:
	var a: TileGrid = _chamber_world()
	var b: TileGrid = _chamber_world()
	for g: TileGrid in [a, b]:
		var rng: SplitRng = _rng(9)
		StuddingPasses.stud_ledges(g, rng, _ledge_cfg(), _sites(g), CPM)
		StuddingPasses.stud_spires(g, rng, _spire_cfg(), _sites(g), CPM)
		StuddingPasses.scatter_rubble(g, rng, _rubble_cfg(), _sites(g), CPM)
	_check(a.state_signature() == b.state_signature(), "same seed, same world")
	var c: TileGrid = _chamber_world()
	var other: SplitRng = _rng(10)
	StuddingPasses.stud_ledges(c, other, _ledge_cfg(), _sites(c), CPM)
	StuddingPasses.stud_spires(c, other, _spire_cfg(), _sites(c), CPM)
	StuddingPasses.scatter_rubble(c, other, _rubble_cfg(), _sites(c), CPM)
	_check(c.state_signature() != a.state_signature(), "CONTROL: another seed, another world")
