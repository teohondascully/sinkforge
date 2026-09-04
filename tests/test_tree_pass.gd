extends "res://tests/test_base.gd"

## `sim/terrain_gen/tree_pass.gd` -- legacy's surface trees on the deterministic generator, A' step 8g
## (D0387), and the two materials they are made of. Posed on flat solid ground so every wood and leaf cell
## is one the pass put there, then on a generated world through the site record.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_tree_pass.gd

const CPM: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
const W: int = 256
const H: int = 160
const DATUM: int = 80
const SPAWN: int = 128
const KEEPOUT := Vector2i(SPAWN - 12 * CPM, SPAWN + 12 * CPM)


func _initialize() -> void:
	_test_the_two_materials_exist_with_legacys_look()
	_test_trees_root_on_the_ground_with_legacys_heights_and_a_canopy()
	_test_the_gap_and_the_keepout_hold()
	_test_no_tree_over_a_cave_mouth_and_none_without_sky()
	_test_the_ground_and_the_wall_plane_are_untouched()
	_test_the_generator_reads_the_record()
	_test_the_same_seed_plants_the_same_trees()
	_finish("tree_pass")


## Legacy's constants (TREE_CHANCE 0.20, TREE_GAP 3, trunk 2..3) with this build's widths.
func _cfg() -> Dictionary:
	return {"chance": 0.20, "gap_m": 3, "trunk_min_m": 2, "trunk_max_m": 3, "trunk_w_m": 0.5,
		"canopy_w_m": 3.0, "canopy_h_m": 2.5, "keepout_m": 12}


func _ground(datum: int = DATUM) -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 7)
	for col: int in W:
		for row: int in range(datum, H):
			grid.set_material(Vector2i(col, row), &"clay")
			grid.set_wall(Vector2i(col, row), &"clay")
	return grid


func _rng(seed: int) -> SplitRng:
	return SplitRng.new(seed).split("trees")


func _cells_of(grid: TileGrid, material: StringName) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col: int in W:
		for row: int in grid.height:
			if grid.get_material(Vector2i(col, row)) == material:
				out.append(Vector2i(col, row))
	return out


## The trunks' root columns: a wood cell on the row just above the ground with no wood to its left.
func _roots(grid: TileGrid) -> Array[int]:
	var out: Array[int] = []
	for col: int in W:
		if grid.get_material(Vector2i(col, DATUM - 1)) == &"wood" and grid.get_material(Vector2i(col - 1, DATUM - 1)) != &"wood":
			out.append(col)
	return out


func _test_the_two_materials_exist_with_legacys_look() -> void:
	_check(WorldMaterials.exists(&"wood") and WorldMaterials.exists(&"leaves"), "wood and leaves are material records")
	var wood: Dictionary = MaterialsRecords.RECORDS.get("wood", {})
	var leaves: Dictionary = MaterialsRecords.RECORDS.get("leaves", {})
	_check(wood.get("base_color", []) == [0.42, 0.28, 0.16] and leaves.get("base_color", []) == [0.18, 0.40, 0.23],
		"their colours are legacy's wood.tres and leaves.tres")
	_check(not WorldMaterials.is_ore_like(&"wood") and not WorldMaterials.is_soil(&"leaves"), "neither is ore-like, leaves are not soil")
	_check(WorldMaterials.hardness(&"leaves") < WorldMaterials.hardness(&"clay") and WorldMaterials.hardness(&"wood") > WorldMaterials.hardness(&"clay"),
		"leaves cut faster than clay and wood slower, as legacy's seconds had it (%.2f, %.2f, %.2f)"
		% [WorldMaterials.hardness(&"leaves"), WorldMaterials.hardness(&"clay"), WorldMaterials.hardness(&"wood")])


func _test_trees_root_on_the_ground_with_legacys_heights_and_a_canopy() -> void:
	var grid: TileGrid = _ground()
	var planted: int = TreePass.plant(grid, _rng(1), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM)
	var roots: Array[int] = _roots(grid)
	_check(planted > 3 and roots.size() == planted, "%d trees planted, %d trunks rooted on the ground" % [planted, roots.size()])
	var bad_height: int = 0
	var no_canopy: int = 0
	var thin: int = 0
	for col: int in roots:
		var h: int = 0
		while grid.get_material(Vector2i(col, DATUM - 1 - h)) == &"wood":
			h += 1
		if h != 2 * CPM and h != 3 * CPM:
			bad_height += 1
		if grid.get_material(Vector2i(col, DATUM - 1 - h)) != &"leaves":
			no_canopy += 1
		if grid.get_material(Vector2i(col + 1, DATUM - 1)) != &"wood":
			thin += 1
	_check(bad_height == 0, "every trunk is two or three metres tall (%d not)" % bad_height)
	_check(no_canopy == 0, "and leaves sit on every trunk's top (%d bare)" % no_canopy)
	_check(thin == 0, "and every trunk is two cells wide (%d thin)" % thin)
	var leaves: Array[Vector2i] = _cells_of(grid, &"leaves")
	var below_ground: int = 0
	for c: Vector2i in leaves:
		if c.y >= DATUM:
			below_ground += 1
	_check(leaves.size() > planted * 20 and below_ground == 0, "a canopy of %d leaf cells over %d trees, none below ground" % [leaves.size(), planted])


func _test_the_gap_and_the_keepout_hold() -> void:
	var grid: TileGrid = _ground()
	var cfg: Dictionary = _cfg()
	cfg["chance"] = 1.0                                    # every eligible column asks: the gap is what refuses
	TreePass.plant(grid, _rng(2), cfg, Relief.flat(W, DATUM), KEEPOUT, CPM)
	var roots: Array[int] = _roots(grid)
	var close: int = 0
	for i: int in range(1, roots.size()):
		if roots[i] - roots[i - 1] < 3 * CPM:
			close += 1
	_check(roots.size() >= 8 and close == 0, "no two trunks closer than 3 m (%d pairs of %d)" % [close, roots.size()])
	var on_pad: int = 0
	for c: Vector2i in _cells_of(grid, &"wood"):
		if c.x >= KEEPOUT.x and c.x <= KEEPOUT.y:
			on_pad += 1
	_check(on_pad == 0, "no wood on the pad (%d cells)" % on_pad)
	# CONTROL: right beside the keepout there is a tree, so the pad's edge is where the rule stops.
	var near: int = 0
	for col: int in roots:
		if absi(col - KEEPOUT.x) <= 3 * CPM or absi(col - KEEPOUT.y) <= 3 * CPM:
			near += 1
	_check(near > 0, "CONTROL: %d trunks within 3 m of the pad's edge" % near)


## The rate is a metre of ground, so `chance` 4.0 is every column asking; with the 3 m gap and one-cell
## trunks the roots then fall every twelfth column from zero -- 0, 12, 24, 36, 48 -- so column 48 is DUE;
## a mouth there is skipped and the tree lands on 49 instead.
func _test_no_tree_over_a_cave_mouth_and_none_without_sky() -> void:
	var grid: TileGrid = _ground()
	var cfg: Dictionary = _cfg()
	cfg["chance"] = 4.0
	cfg["trunk_w_m"] = 0.25                                # one cell, so a neighbour's trunk cannot stand in for it
	for row: int in range(DATUM, DATUM + 8):
		grid.excavate(Vector2i(48, row))                   # a mouth at column 48
	TreePass.plant(grid, _rng(3), cfg, Relief.flat(W, DATUM), KEEPOUT, CPM)
	_check(grid.get_material(Vector2i(36, DATUM - 1)) == &"wood", "CONTROL: the tree before the mouth stands at 36")
	_check(grid.get_material(Vector2i(48, DATUM - 1)) != &"wood" and grid.get_material(Vector2i(49, DATUM - 1)) == &"wood",
		"no trunk over the mouth at 48; the tree lands on 49")
	var low: TileGrid = _ground(6)                         # six rows of sky: no room for a trunk and a canopy
	var planted: int = TreePass.plant(low, _rng(3), cfg, Relief.flat(W, 6), KEEPOUT, CPM)
	_check(planted == 0 and _cells_of(low, &"wood").is_empty(), "CONTROL: without sky no tree is planted (%d)" % planted)


func _test_the_ground_and_the_wall_plane_are_untouched() -> void:
	var grid: TileGrid = _ground()
	var before: TileGrid = grid.clone()
	TreePass.plant(grid, _rng(4), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM)
	var changed_below: int = 0
	for col: int in W:
		for row: int in range(DATUM, H):
			if grid.get_material(Vector2i(col, row)) != before.get_material(Vector2i(col, row)):
				changed_below += 1
	_check(changed_below == 0, "no cell at or below the surface changed (%d)" % changed_below)
	var walled: int = 0
	for c: Vector2i in _cells_of(grid, &"wood") + _cells_of(grid, &"leaves"):
		if grid.get_wall(c) != &"":
			walled += 1
	_check(walled == 0, "a tree has no wall behind it: dug, it leaves sky (%d walled)" % walled)


func _test_the_generator_reads_the_record() -> void:
	var site: Dictionary = StrataData.SHALLOW_CLAY.duplicate(true)
	site["max_depth_m"] = 64
	site["layer_thresholds_m"] = {"topsoil_shale_end": 20, "stonereach_end": 40}
	var plain: TileGrid = ShaftGenerator.generate(site, 20260826)
	site["tree"] = _cfg()
	var with: TileGrid = ShaftGenerator.generate(site, 20260826)
	var wood: int = 0
	var above: int = 0
	for col: int in W:
		for row: int in ShaftGenerator.SKY_ROWS:
			var m: StringName = with.get_material(Vector2i(col, row))
			if m == &"wood":
				wood += 1
			if m == &"wood" or m == &"leaves":
				above += 1
	_check(wood > 0 and above > wood, "the record puts wood and leaves in the sky band (%d wood, %d in all)" % [wood, above])
	_check(_cells_of(plain, &"wood").is_empty(), "CONTROL: without it there is no wood")


func _test_the_same_seed_plants_the_same_trees() -> void:
	var a: TileGrid = _ground()
	var b: TileGrid = _ground()
	TreePass.plant(a, _rng(9), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM)
	TreePass.plant(b, _rng(9), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM)
	_check(a.state_signature() == b.state_signature(), "same seed, same trees")
	var c: TileGrid = _ground()
	TreePass.plant(c, _rng(10), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM)
	_check(c.state_signature() != a.state_signature(), "CONTROL: another seed, other trees")
