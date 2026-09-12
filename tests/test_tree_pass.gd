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
	_test_a_one_cell_lid_is_not_a_footing()
	_test_the_far_trunk_column_is_footed_too()
	_test_no_two_crowns_are_alike_and_none_is_the_old_ellipse()
	_test_a_planted_world_shows_more_than_one_crown()
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


## The footing depth a tree asks for, read off the SHIPPED site rather than written here: it is the same
## `cave.min_depth_cells` every carve pass in the generator refuses, which is the whole of why `_footed`
## needs no constant of its own (D0626). If the record moves, this test moves with it.
func _band() -> int:
	return int((StrataData.SHALLOW_CLAY["cave"] as Dictionary)["min_depth_cells"])


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
	_check(wood.get("base_color", []) == [0.84, 0.56, 0.32] and leaves.get("base_color", []) == [0.36, 0.8, 0.46],
		"their colours are legacy's wood.tres and leaves.tres, doubled by P036's palette step (D0630)")
	_check(not WorldMaterials.is_ore_like(&"wood") and not WorldMaterials.is_soil(&"leaves"), "neither is ore-like, leaves are not soil")
	_check(WorldMaterials.hardness(&"leaves") < WorldMaterials.hardness(&"clay") and WorldMaterials.hardness(&"wood") > WorldMaterials.hardness(&"clay"),
		"leaves cut faster than clay and wood slower, as legacy's seconds had it (%.2f, %.2f, %.2f)"
		% [WorldMaterials.hardness(&"leaves"), WorldMaterials.hardness(&"clay"), WorldMaterials.hardness(&"wood")])


func _test_trees_root_on_the_ground_with_legacys_heights_and_a_canopy() -> void:
	var grid: TileGrid = _ground()
	var planted: int = TreePass.plant(grid, _rng(1), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
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
	TreePass.plant(grid, _rng(2), cfg, Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
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
	TreePass.plant(grid, _rng(3), cfg, Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
	_check(grid.get_material(Vector2i(36, DATUM - 1)) == &"wood", "CONTROL: the tree before the mouth stands at 36")
	_check(grid.get_material(Vector2i(48, DATUM - 1)) != &"wood" and grid.get_material(Vector2i(49, DATUM - 1)) == &"wood",
		"no trunk over the mouth at 48; the tree lands on 49")
	var low: TileGrid = _ground(6)                         # six rows of sky: no room for a trunk and a canopy
	var planted: int = TreePass.plant(low, _rng(3), cfg, Relief.flat(W, 6), KEEPOUT, CPM, _band())
	_check(planted == 0 and _cells_of(low, &"wood").is_empty(), "CONTROL: without sky no tree is planted (%d)" % planted)


## THE DIRECTOR'S REPORT, POSED (D0626): *"trees randomly spawn on flat platforms over shafts"*. A
## sinkhole mouth cut up from a rift leaves a crust, and the old check -- one cell, `is_solid(col,
## ground)` -- could not tell a crust from a hillside. Measured on the shipped seed before the fix, two
## trunk columns stood on a lid of ONE cell and two more on no cell at all.
##
## The control is inside the measurement: the SAME chamber, at the same columns, dropped to the band's
## own depth, must still carry a tree. Otherwise this passes by refusing every tree in the world.
func _test_a_one_cell_lid_is_not_a_footing() -> void:
	var cfg: Dictionary = _cfg()
	cfg["chance"] = 4.0
	var lid: TileGrid = _ground()
	var deep: TileGrid = _ground()
	for col: int in range(40, 80):
		for row: int in range(DATUM + 1, DATUM + 40):
			lid.excavate(Vector2i(col, row))               # one cell of crust over forty of void
		for row: int in range(DATUM + _band(), DATUM + 40):
			deep.excavate(Vector2i(col, row))              # the same void, starting below the band
	TreePass.plant(lid, _rng(11), cfg, Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
	TreePass.plant(deep, _rng(11), cfg, Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
	var on_lid: int = 0
	var on_deep: int = 0
	for col: int in range(40, 80):
		if lid.get_material(Vector2i(col, DATUM - 1)) == &"wood":
			on_lid += 1
		if deep.get_material(Vector2i(col, DATUM - 1)) == &"wood":
			on_deep += 1
	_check(on_lid == 0, "no trunk cell stands on a one-cell lid (%d)" % on_lid)
	_check(on_deep > 0, "CONTROL: %d trunk cells over the same void when it starts below the band" % on_deep)


## `plant_one` writes wood across `col .. col + trunk_w - 1`, so the footing has to be tested across the
## same span. Before D0626 only `col` was, and the shipped seed planted a tree with one half of its trunk
## in 175 cells of rock and the other half over open air (columns 214 and 215).
func _test_the_far_trunk_column_is_footed_too() -> void:
	var cfg: Dictionary = _cfg()
	cfg["chance"] = 4.0                                    # every column asks; the 3 m gap puts a root on 48
	var far: TileGrid = _ground()
	var behind: TileGrid = _ground()
	for row: int in range(DATUM, DATUM + 40):
		far.excavate(Vector2i(49, row))                    # the trunk's SECOND column, never tested before
		behind.excavate(Vector2i(47, row))                 # one column back, outside the trunk: the control
	TreePass.plant(far, _rng(12), cfg, Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
	TreePass.plant(behind, _rng(12), cfg, Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
	_check(far.get_material(Vector2i(48, DATUM - 1)) != &"wood",
		"the far trunk column's void refuses the tree at 48")
	_check(behind.get_material(Vector2i(48, DATUM - 1)) == &"wood",
		"CONTROL: the same void one column back, outside the trunk, plants the tree at 48")


## THE SHIPPED CROWN GEOMETRY, so these assertions are about the trees the game actually grows.
const RX: int = 6
const RY: int = 5


func _crown_cells(crown: int) -> Dictionary:
	var out: Dictionary = {}
	for dy: int in range(-RY, RY + 1):
		for dx: int in range(-RX, RX + 1):
			if TreePass.in_crown(dx, dy, RX, RY, crown):
				out[Vector2i(dx, dy)] = true
	return out


## Reachable from one cell of `cells` by four-neighbour steps that stay inside it.
func _connected(cells: Dictionary) -> int:
	if cells.is_empty():
		return 0
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = [cells.keys()[0]]
	seen[queue[0]] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if cells.has(c + d) and not seen.has(c + d):
				seen[c + d] = true
				queue.append(c + d)
	return seen.size()


## ITEM 53, THE LOLLIPOP (D0627). Six crowns of three overlapping lobes replace the one ellipse every tree
## in the world used to wear. What has to be true of them, and each of these failed for the old shape:
## they differ from EACH OTHER, none of them is the ellipse that was there, each is ONE mass rather than
## three balls, each still fits the bounding box the ellipse used, and they are not all the same size.
func _test_no_two_crowns_are_alike_and_none_is_the_old_ellipse() -> void:
	var n: int = TreePass.crown_count()
	var ellipse: Dictionary = {}
	for dy: int in range(-RY, RY + 1):
		for dx: int in range(-RX, RX + 1):
			if dx * dx * RY * RY + dy * dy * RX * RX <= RX * RX * RY * RY:
				ellipse[Vector2i(dx, dy)] = true
	var sets: Array[Dictionary] = []
	for c: int in n:
		sets.append(_crown_cells(c))
	var alike: int = 0
	for i: int in n:
		for j: int in range(i + 1, n):
			if sets[i].keys() == sets[j].keys():
				alike += 1
	_check(n >= 4 and alike == 0, "%d crowns, no two the same cell set (%d pairs alike)" % [n, alike])
	var is_ellipse: int = 0
	var split: int = 0
	var areas: Array[int] = []
	for c: int in n:
		if sets[c].keys() == ellipse.keys():
			is_ellipse += 1
		if _connected(sets[c]) != sets[c].size():
			split += 1
		areas.append(sets[c].size())
	_check(is_ellipse == 0, "none of them is the ellipse this replaced (%d are)" % is_ellipse)
	_check(split == 0, "each crown is ONE mass, not three balls (%d split)" % split)
	areas.sort()
	_check(areas[0] < areas[n - 1] and areas[0] > ellipse.size() / 2,
		"and they are not all one size: %d to %d cells against the ellipse's %d" % [areas[0], areas[n - 1], ellipse.size()])
	# THE ONE PROPERTY HERE THAT IS NOT TASTE. The canopy's centre sits `ry` above the top trunk cell, so
	# the cell directly above the trunk is `(-1, ry - 1)` -- `plant_one` centres the crown at
	# `col + trunk_w / 2`. A crown that misses it leaves the canopy floating over a bare stick, which is
	# worse than the lollipop. This is the assertion the first draft of the table failed, on 7 trunks.
	var floating: int = 0
	for c: int in n:
		if not sets[c].has(Vector2i(-1, RY - 1)) or not sets[c].has(Vector2i(0, RY - 1)):
			floating += 1
	_check(floating == 0, "every crown sits on its trunk (%d float)" % floating)
	# CONTROL: the shape is `posmod(col, crown_count())` of the ROOT COLUMN and nothing else, so it repeats
	# on that period exactly -- which is what makes the tutorial's tree the same tree on every boot.
	_check(_crown_cells(3).keys() == _crown_cells(3 + n).keys() and _crown_cells(3).keys() != _crown_cells(4).keys(),
		"CONTROL: the crown is the column modulo %d -- 3 and %d agree, 3 and 4 do not" % [n, 3 + n])


## And it reaches a planted world: the trees in one posed forest do not all wear the same crown.
##
## **KEYED TO THE CROWN'S OWN TOP ROW, NOT TO THE GROUND**, and the first draft of this test was keyed to
## the ground -- which made it a trunk-height detector rather than a shape detector. Trunks come in two
## heights, so two trees wearing the SAME crown at different heights produced different signatures and
## the test read them as different shapes. Mutation M5 -- the table kept, but `posmod(col, ...)` forced to
## 0 so every tree in the world wears crown 0 -- passed the whole suite green. It is the exact defect this
## function exists to catch, and it could not see it.
func _test_a_planted_world_shows_more_than_one_crown() -> void:
	var grid: TileGrid = _ground()
	var cfg: Dictionary = _cfg()
	# THE TREES HAVE TO STAND APART OR THIS MEASURES THE SPACING. At the record's 3 m gap two crowns are
	# 12 cells apart and each is 13 wide, so a window around one root catches its NEIGHBOUR's leaves and
	# every signature differs for a reason that has nothing to do with the crowns. 7 m and every column
	# asking puts a root every 28 cells -- wider than a crown, and 28 is not a multiple of six, so the
	# roots do land on different crowns.
	cfg["chance"] = 4.0
	cfg["gap_m"] = 7
	TreePass.plant(grid, _rng(13), cfg, Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
	var roots: Array[int] = _roots(grid)
	var shapes: Dictionary = {}
	for col: int in roots:
		var cells: Array[Vector2i] = []
		for row: int in range(0, DATUM):
			for dx: int in range(-RX - 1, RX + 2):
				if grid.get_material(Vector2i(col + dx, row)) == &"leaves":
					cells.append(Vector2i(dx, row))
		if cells.is_empty():
			continue
		var top: int = cells[0].y
		var key: Array[String] = []
		for c: Vector2i in cells:
			key.append("%d,%d" % [c.x, c.y - top])
		shapes["|".join(key)] = true
	_check(roots.size() >= 4 and shapes.size() >= 3,
		"%d trees wearing %d canopy SHAPES, trunk height divided out" % [roots.size(), shapes.size()])


func _test_the_ground_and_the_wall_plane_are_untouched() -> void:
	var grid: TileGrid = _ground()
	var before: TileGrid = grid.clone()
	TreePass.plant(grid, _rng(4), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
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
	var site: Dictionary = _site_without_content(StrataData.SHALLOW_CLAY)
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
	TreePass.plant(a, _rng(9), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
	TreePass.plant(b, _rng(9), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
	_check(a.state_signature() == b.state_signature(), "same seed, same trees")
	var c: TileGrid = _ground()
	TreePass.plant(c, _rng(10), _cfg(), Relief.flat(W, DATUM), KEEPOUT, CPM, _band())
	_check(c.state_signature() != a.state_signature(), "CONTROL: another seed, other trees")
