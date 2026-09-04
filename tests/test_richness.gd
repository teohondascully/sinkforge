extends "res://tests/test_base.gd"

## `sim/terrain_gen/richness.gd` -- legacy's per-column richness field on the deterministic generator,
## A' step 8f (D0386), and its three consumers: the ore and coal scatters' acceptance and size, and the
## lodes' per-cell amount. The field's own shape is asserted first (bounded, symmetric about one, richer
## at the frontier than at spawn, smooth), then that each consumer moves with it -- by driving the same
## pass with a rich field and a poor one over the same seed, so only the field differs.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_richness.gd

const CPM: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
const W: int = 256
const SPAWN: int = 128
const DATUM: int = ShaftGenerator.SKY_ROWS


func _initialize() -> void:
	_test_no_record_reads_one_everywhere()
	_test_the_field_is_bounded_symmetric_about_one_and_richer_at_the_frontier()
	_test_the_field_is_smooth_column_to_column()
	_test_strength_zero_is_one_everywhere_and_the_seed_moves_the_band()
	_test_a_richer_field_seeds_bigger_and_more_veins()
	_test_a_richer_field_seeds_richer_lodes()
	_test_the_generator_reads_the_record()
	_finish("richness")


## Legacy's constants verbatim: HORIZONTAL_STRENGTH, HORIZONTAL_FREQ, FRONTIER_BIAS.
func _cfg() -> Dictionary:
	return {"strength": 0.55, "freq_per_m": 0.045, "frontier_bias": 0.5}


func _field(seed: int = 20260826, cfg: Dictionary = _cfg()) -> PackedInt32Array:
	return Richness.field({"richness": cfg}, W, SPAWN, seed, CPM)


func _mean(f: PackedInt32Array, from: int, to: int) -> int:
	var sum: int = 0
	for col: int in range(from, to):
		sum += f[col]
	return sum / maxi(1, to - from)


func _test_no_record_reads_one_everywhere() -> void:
	var f: PackedInt32Array = Richness.field({}, W, SPAWN, 1, CPM)
	var off: int = 0
	for v: int in f:
		if v != 1000:
			off += 1
	_check(f.size() == W and off == 0, "without the record every column is 1000 (%d off)" % off)
	_check(Richness.multiplier(f, 7) == 1.0, "and the float multiplier is exactly one")


func _test_the_field_is_bounded_symmetric_about_one_and_richer_at_the_frontier() -> void:
	var f: PackedInt32Array = _field()
	var out: int = 0
	var lo: int = 1 << 30
	var hi: int = 0
	for v: int in f:
		if v < 450 or v > 1550:
			out += 1
		lo = mini(lo, v)
		hi = maxi(hi, v)
	_check(out == 0, "every column within [1 - S, 1 + S] = [450, 1550] (%d out; range %d..%d)" % [out, lo, hi])
	var mean: int = _mean(f, 0, W)
	_check(absi(mean - 1000) < 200, "the mean is about one (%d)" % mean)
	var edges: int = (_mean(f, 0, 32) + _mean(f, W - 32, W)) / 2
	var home: int = _mean(f, SPAWN - 16, SPAWN + 16)
	_check(edges > home + 200, "the frontier is richer than spawn: edges %d over home %d" % [edges, home])
	_check(hi - lo > 300, "CONTROL: the field moves (%d..%d)" % [lo, hi])


func _test_the_field_is_smooth_column_to_column() -> void:
	var f: PackedInt32Array = _field()
	var worst: int = 0
	for col: int in range(1, W):
		worst = maxi(worst, absi(f[col] - f[col - 1]))
	_check(worst <= 12, "no two neighbouring columns differ by more than 12 thousandths (%d)" % worst)


func _test_strength_zero_is_one_everywhere_and_the_seed_moves_the_band() -> void:
	var flat_cfg: Dictionary = _cfg()
	flat_cfg["strength"] = 0.0
	var flat: PackedInt32Array = _field(1, flat_cfg)
	var off: int = 0
	for v: int in flat:
		if v != 1000:
			off += 1
	_check(off == 0, "strength 0 is exactly one everywhere (%d off)" % off)
	_check(_field(1) == _field(1), "same seed, same field")
	_check(_field(1) != _field(2), "CONTROL: another seed, another band")
	var ramp_only: Dictionary = _cfg()
	ramp_only["frontier_bias"] = 1.0
	_check(_field(1, ramp_only) == _field(2, ramp_only), "with the bias all ramp, the seed no longer matters")


func _rock_grid() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, 400, 7)
	for col: int in W:
		for row: int in range(DATUM, 400):
			grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


func _ore_count(grid: TileGrid) -> int:
	var n: int = 0
	for col: int in W:
		for row: int in range(DATUM, grid.height):
			if grid.get_material(Vector2i(col, row)) == &"ore_copper":
				n += 1
	return n


func _uniform(v: int) -> PackedInt32Array:
	var f := PackedInt32Array()
	f.resize(W)
	f.fill(v)
	return f


func _test_a_richer_field_seeds_bigger_and_more_veins() -> void:
	var cfg: Dictionary = StrataData.SHALLOW_CLAY["ore"]
	var rich: TileGrid = _rock_grid()
	var poor: TileGrid = _rock_grid()
	var surface: PackedInt32Array = Relief.flat(W, DATUM)
	ShaftGenerator._scatter_vein_material(rich, SplitRng.new(3).split("terrain_gen"), cfg, &"ore_copper", surface, _uniform(1550))
	ShaftGenerator._scatter_vein_material(poor, SplitRng.new(3).split("terrain_gen"), cfg, &"ore_copper", surface, _uniform(450))
	var rich_n: int = _ore_count(rich)
	var poor_n: int = _ore_count(poor)
	_check(poor_n > 0 and rich_n > poor_n * 2, "the same seed under 1.55 seeds more than twice the ore of 0.45 (%d over %d)" % [rich_n, poor_n])
	var same: TileGrid = _rock_grid()
	ShaftGenerator._scatter_vein_material(same, SplitRng.new(3).split("terrain_gen"), cfg, &"ore_copper", surface, _uniform(1000))
	var plain: TileGrid = _rock_grid()
	ShaftGenerator._scatter_vein_material(plain, SplitRng.new(3).split("terrain_gen"), cfg, &"ore_copper", surface, Richness.field({}, W, SPAWN, 3, CPM))
	_check(same.state_signature() == plain.state_signature(), "CONTROL: a field of exactly one is the pass without a field")


func _test_a_richer_field_seeds_richer_lodes() -> void:
	var cfg: Dictionary = {"per_col": 0.35, "size_min_m2": 6, "size_depth_bonus_m2": 12, "amount_base": 40,
		"amount_depth_bonus": 170, "min_depth_m": 14}
	var surface: PackedInt32Array = Relief.flat(W, DATUM)
	var rich: World = World.new(_rock_grid())
	var poor: World = World.new(_rock_grid())
	PlanePasses.seed_lodes(rich, SplitRng.new(5).split("lodes"), cfg, surface, DATUM, 300, CPM, _uniform(1550))
	PlanePasses.seed_lodes(poor, SplitRng.new(5).split("lodes"), cfg, surface, DATUM, 300, CPM, _uniform(450))
	_check(rich.deposits.lode_terrain_cells() == poor.deposits.lode_terrain_cells(), "the field moves no lode cell: same seed, same cells (%d)" % rich.deposits.lode_terrain_cells().size())
	var rich_sum: int = 0
	var poor_sum: int = 0
	for c: Vector2i in rich.deposits.lode_terrain_cells():
		rich_sum += int(rich.deposits.deposits.get(c, 0))
		poor_sum += int(poor.deposits.deposits.get(c, 0))
	_check(poor_sum > 0 and rich_sum > poor_sum, "but every cell holds more under the richer field (%d over %d)" % [rich_sum, poor_sum])


func _test_the_generator_reads_the_record() -> void:
	var site: Dictionary = StrataData.SHALLOW_CLAY.duplicate(true)
	site["max_depth_m"] = 96
	site["layer_thresholds_m"] = {"topsoil_shale_end": 30, "stonereach_end": 60}
	var plain: TileGrid = ShaftGenerator.generate(site, 20260826)
	site["richness"] = _cfg()
	var with: TileGrid = ShaftGenerator.generate(site, 20260826)
	_check(with.state_signature() != plain.state_signature(), "the record changes the world")
	# Ore per column at the frontier against ore per column about spawn, in the world with the field.
	var edge: int = 0
	var home: int = 0
	for col: int in W:
		for row: int in range(DATUM, with.height):
			if with.get_material(Vector2i(col, row)) == &"ore_copper":
				if col < 48 or col >= W - 48:
					edge += 1
				elif absi(col - SPAWN) < 48:
					home += 1
	_check(edge > home, "the frontier's 96 columns carry more copper than spawn's 96 (%d over %d)" % [edge, home])
