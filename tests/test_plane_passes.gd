extends "res://tests/test_base.gd"

## `sim/terrain_gen/plane_passes.gd` -- legacy's aquifers (with their rim treasure) and lodes on the
## `World`'s water and deposit planes, A' step 8e (D0385), and `ShaftGenerator.enrich`, the door they run
## through after the grid. Posed on solid rock, where every flooded cell and every lode cell is one the
## pass put there.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_plane_passes.gd

const CPM: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
const W: int = 128
const H: int = 400              # 20 m of sky and 80 m of rock
const DATUM: int = 80
const BAND: int = 24
const DEEP: int = DATUM + 50 * CPM   # iron from 50 m down
const MIN_ROW: int = DATUM + 30 * CPM


func _initialize() -> void:
	_test_depth_permille_is_zero_at_the_datum_and_full_at_the_floor()
	_test_aquifers_carve_flood_and_seed_their_treasure()
	_test_an_aquifer_never_breaches_the_band_or_rises_above_its_floor()
	_test_lodes_sit_in_host_rock_below_their_depth_with_a_deposit_that_grows_with_depth()
	_test_a_lode_never_lies_in_water_or_over_another_lode()
	_test_enrich_writes_both_planes_only_when_the_site_asks()
	_test_load_world_enriches_and_the_planes_are_deterministic()
	_finish("plane_passes")


func _aquifer_cfg() -> Dictionary:
	return {"per_col": 0.045, "rx_min_m": 2, "rx_max_m": 4, "ry_min_m": 2, "ry_max_m": 3,
		"ore_size_min_m2": 5, "ore_size_max_m2": 9, "min_depth_m": 30}


func _lode_cfg() -> Dictionary:
	return {"per_col": 0.35, "size_min_m2": 6, "size_depth_bonus_m2": 12, "amount_base": 40,
		"amount_depth_bonus": 170, "min_depth_m": 14}


func _solid_world() -> World:
	var grid: TileGrid = TileGrid.new(W, H, 7)
	for col: int in W:
		for row: int in range(DATUM, H):
			grid.set_material(Vector2i(col, row), &"hardrock")
			grid.set_wall(Vector2i(col, row), &"hardrock")
	return World.new(grid)


func _flat() -> PackedInt32Array:
	return Relief.flat(W, DATUM)


func _rng(seed: int, label: String) -> SplitRng:
	return SplitRng.new(seed).split("planes").split(label)


func _test_depth_permille_is_zero_at_the_datum_and_full_at_the_floor() -> void:
	_check(PlanePasses.depth_permille(DATUM, DATUM, H) == 0, "the datum is 0")
	_check(PlanePasses.depth_permille(H - 1, DATUM, H) == 1000, "the last row is 1000")
	var half: int = PlanePasses.depth_permille(DATUM + (H - 1 - DATUM) / 2, DATUM, H)
	_check(half >= 498 and half <= 500, "halfway is 500 less the integer floor (%d)" % half)
	_check(PlanePasses.depth_permille(0, DATUM, H) == 0, "the sky clamps to 0")


func _test_aquifers_carve_flood_and_seed_their_treasure() -> void:
	var world: World = _solid_world()
	var cfg: Dictionary = _aquifer_cfg()
	cfg["per_col"] = 0.5                                    # enough pockets in a small world to count on
	var out: Dictionary = PlanePasses.seed_aquifers(world, _rng(1, "aquifers"), cfg, _flat(), BAND, MIN_ROW, DEEP, CPM)
	_check(int(out["pockets"]) >= 2 and int(out["flooded"]) > 0, "pockets carved and flooded (%s)" % str(out))
	var wet: Array[Vector2i] = world.water.wet_terrain_cells()
	_check(wet.size() == int(out["flooded"]), "the wet cells are the flooded cells (%d of %d)" % [wet.size(), int(out["flooded"])])
	var solid_wet: int = 0
	var short: int = 0
	for c: Vector2i in wet:
		if world.grid.is_solid(c):
			solid_wet += 1
		if world.water.water_at(c) != WaterPlane.WATER_MAX:
			short += 1
	_check(solid_wet == 0 and short == 0, "every flooded cell is open and full to the brim (%d solid, %d short)" % [solid_wet, short])
	_check(world.water.total_water() == wet.size() * WaterPlane.WATER_MAX, "the plane's total is cells x WATER_MAX (%d)" % world.water.total_water())
	# The treasure: ore beside the water.
	var touching: int = 0
	for c: Vector2i in wet:
		for d: Vector2i in PlanePasses.ORTHO:
			if WorldMaterials.is_ore_like(world.grid.get_material(c + d)):
				touching += 1
				break
	_check(int(out["treasure"]) > 0 and touching > 0, "each pocket's rim seeds a vein: %d ore cells, %d wet cells touch ore" % [int(out["treasure"]), touching])
	# CONTROL: a pocket seeded where nothing is solid floods nothing and seeds nothing.
	var air: World = World.new(TileGrid.new(W, H, 7))
	var none: Dictionary = PlanePasses.seed_aquifers(air, _rng(1, "aquifers"), cfg, _flat(), BAND, MIN_ROW, DEEP, CPM)
	_check(int(none["flooded"]) == 0 and int(none["treasure"]) == 0, "CONTROL: nothing to carve, nothing flooded (%s)" % str(none))


## A world only forty rows deeper than the band, so every pocket's ellipse reaches above the floor and
## the guard is exercised by every one of them rather than by whichever happened to roll shallow.
func _test_an_aquifer_never_breaches_the_band_or_rises_above_its_floor() -> void:
	var short_h: int = DATUM + BAND + 40
	var grid: TileGrid = TileGrid.new(W, short_h, 7)
	for col: int in W:
		for row: int in range(DATUM, short_h):
			grid.set_material(Vector2i(col, row), &"hardrock")
	var world: World = World.new(grid)
	var cfg: Dictionary = _aquifer_cfg()
	cfg["per_col"] = 0.5
	var shallow_floor: int = DATUM + BAND
	PlanePasses.seed_aquifers(world, _rng(2, "aquifers"), cfg, _flat(), BAND, shallow_floor, DEEP, CPM)
	var in_band: int = 0
	var above_floor: int = 0
	var wet: Array[Vector2i] = world.water.wet_terrain_cells()
	for c: Vector2i in wet:
		if c.y < DATUM + BAND:
			in_band += 1
		if c.y < shallow_floor:
			above_floor += 1
	_check(wet.size() > 0 and in_band == 0 and above_floor == 0, "no flooded cell in the band or above the floor (%d, %d of %d)" % [in_band, above_floor, wet.size()])
	# CONTROL: a pocket did reach the boundary rows, so the guard was tested and not merely absent.
	var at_edge: int = 0
	for c: Vector2i in wet:
		if c.y < shallow_floor + 2 * CPM:
			at_edge += 1
	_check(at_edge > 0, "CONTROL: %d flooded cells lie within two metres of the floor" % at_edge)


func _test_lodes_sit_in_host_rock_below_their_depth_with_a_deposit_that_grows_with_depth() -> void:
	var world: World = _solid_world()
	var seeded: int = PlanePasses.seed_lodes(world, _rng(3, "lodes"), _lode_cfg(), _flat(), DATUM, DEEP, CPM)
	var cells: Array[Vector2i] = world.deposits.lode_terrain_cells()
	_check(seeded > 0 and cells.size() == seeded, "lodes seeded %d cells (%d in the plane)" % [seeded, cells.size()])
	var shallow: int = 0
	var not_rock: int = 0
	var wrong_metal: int = 0
	var bad_amount: int = 0
	var upper_sum: int = 0
	var upper_n: int = 0
	var lower_sum: int = 0
	var lower_n: int = 0
	for c: Vector2i in cells:
		if c.y < DATUM + 14 * CPM:
			shallow += 1
		if not ShaftGenerator.HOST_ROCK.has(world.grid.get_material(c)):
			not_rock += 1
		# The metal is the SEED's (legacy's rule), and a blob can straddle the deep row: judged clear of it.
		var metal: StringName = world.deposits.lode_at(c)
		if (c.y < DEEP - 40 and metal != &"ore_copper") or (c.y > DEEP + 40 and metal != &"ore_iron"):
			wrong_metal += 1
		var amount: int = int(world.deposits.deposits.get(c, 0))
		if amount < 1 or amount > 14:
			bad_amount += 1
		if c.y < DATUM + (H - DATUM) / 2:
			upper_sum += amount
			upper_n += 1
		else:
			lower_sum += amount
			lower_n += 1
	_check(shallow == 0, "no lode above 14 m under the surface (%d)" % shallow)
	_check(not_rock == 0, "every lode cell is behind solid host rock (%d not)" % not_rock)
	_check(wrong_metal == 0, "copper well above the deep row and iron well below it (%d wrong)" % wrong_metal)
	_check(bad_amount == 0, "every cell's deposit is 1..14 -- legacy's 40..210 a metre over 16 cells (%d out)" % bad_amount)
	_check(upper_n > 0 and lower_n > 0 and lower_sum * upper_n > upper_sum * lower_n,
		"the deposit grows with depth: lower half mean %d/%d over upper %d/%d" % [lower_sum, lower_n, upper_sum, upper_n])
	_check(world.deposits.lode_permille(cells[0]) == 1000, "a fresh lode is full (%d)" % world.deposits.lode_permille(cells[0]))


func _test_a_lode_never_lies_in_water_or_over_another_lode() -> void:
	var world: World = _solid_world()
	var a_cfg: Dictionary = _aquifer_cfg()
	a_cfg["per_col"] = 0.5
	PlanePasses.seed_aquifers(world, _rng(4, "aquifers"), a_cfg, _flat(), BAND, MIN_ROW, DEEP, CPM)
	var l_cfg: Dictionary = _lode_cfg()
	l_cfg["per_col"] = 3.0                                   # dense, so the two would collide if allowed
	PlanePasses.seed_lodes(world, _rng(4, "lodes"), l_cfg, _flat(), DATUM, DEEP, CPM)
	var wet_lode: int = 0
	for c: Vector2i in world.deposits.lode_terrain_cells():
		if world.water.water_at(c) > 0 or not world.grid.is_solid(c):
			wet_lode += 1
	_check(world.deposits.lode_terrain_cells().size() > 100 and wet_lode == 0, "no lode in water or air (%d of %d)" % [wet_lode, world.deposits.lode_terrain_cells().size()])
	# One vein per cell: grow a second lode over the first's seed and count what it adds.
	var first: Array[Vector2i] = world.deposits.lode_terrain_cells()
	var before: int = first.size()
	var added: int = PlanePasses.grow_lode(world, _rng(5, "lodes"), first[0], 16, 2, &"ore_copper", _flat(), 14 * CPM)
	_check(world.deposits.lode_terrain_cells().size() == before + added, "a lode grown over another adds only new cells (%d)" % added)
	var overwritten: int = 0
	for c: Vector2i in first:
		if int(world.deposits.deposits.get(c, 0)) == 2 and world.deposits.lode_at(c) == &"ore_copper" and c.y >= DEEP:
			overwritten += 1
	_check(overwritten == 0, "and rewrites none of the first's cells (%d)" % overwritten)


func _plane_site() -> Dictionary:
	var site: Dictionary = StrataData.SHALLOW_CLAY.duplicate(true)
	site["max_depth_m"] = 96
	site["layer_thresholds_m"] = {"topsoil_shale_end": 30, "stonereach_end": 60}
	site["aquifer"] = _aquifer_cfg()
	site["lode"] = _lode_cfg()
	return site


func _test_enrich_writes_both_planes_only_when_the_site_asks() -> void:
	var site: Dictionary = _plane_site()
	var world: World = World.new(ShaftGenerator.generate(site, 20260826))
	ShaftGenerator.enrich(world, site, 20260826)
	_check(world.water.total_water() > 0, "the site's aquifers put water in the world (%d)" % world.water.total_water())
	_check(world.deposits.lode_terrain_cells().size() > 0, "and its lodes ore behind the wall (%d cells)" % world.deposits.lode_terrain_cells().size())
	var deep_water: int = 0
	for c: Vector2i in world.water.wet_terrain_cells():
		if c.y >= ShaftGenerator.SKY_ROWS + 30 * CPM:
			deep_water += 1
	_check(deep_water == world.water.wet_terrain_cells().size(), "every wet cell is at or below the record's 30 m (%d of %d)" % [deep_water, world.water.wet_terrain_cells().size()])
	var plain: Dictionary = _plane_site()
	plain.erase("aquifer")
	plain.erase("lode")
	var dry: World = World.new(ShaftGenerator.generate(plain, 20260826))
	ShaftGenerator.enrich(dry, plain, 20260826)
	_check(dry.water.total_water() == 0 and dry.deposits.lode_terrain_cells().is_empty(), "CONTROL: without the records, no water and no lode")
	_check(dry.grid.state_signature() == ShaftGenerator.generate(plain, 20260826).state_signature(), "and the grid is untouched by an enrich with nothing to do")


func _test_load_world_enriches_and_the_planes_are_deterministic() -> void:
	var site: Dictionary = _plane_site()
	var a: World = WorldSeeder.load_world(site, 20260826)
	var b: World = WorldSeeder.load_world(site, 20260826)
	_check(a.water.total_water() > 0, "the one door a new world comes through enriches it (%d water)" % a.water.total_water())
	_check(a.state_signature() == b.state_signature(), "same site and seed, same planes")
	_check(a.state_signature() == a.recomputed_signature(), "the running signature agrees with the recomputed one after the passes")
	var c: World = WorldSeeder.load_world(site, 20260827)
	_check(c.state_signature() != a.state_signature(), "CONTROL: another seed, other planes")
