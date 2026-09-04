extends "res://tests/test_base.gd"

## `sim/terrain_gen/cave_passes.gd` — the two carve passes D0017 left behind, ported under P021's ruling
## (D0291).
##
## The suite is built around the one thing a carve pass fails at silently: **carving nothing.** Every
## assertion here either counts cells opened or measures a property that is zero when nothing opened, and
## each pass reports its own count so "it ran" and "it did something" are different answers.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_cave_passes.gd

const CELLS_PER_M: int = ShaftGenerator.TERRAIN_CELLS_PER_METER
const W: int = 200
const H: int = 320
const MIN_DEPTH: int = 6


func _initialize() -> void:
	_test_both_passes_open_cells_rather_than_running_and_doing_nothing()
	_test_nothing_is_carved_into_the_protected_surface_band()
	_test_the_worms_thread_the_pockets_into_one_system()
	_test_a_chamber_keeps_a_floor_under_it()
	_test_the_count_is_denominated_in_metres_not_in_cells()
	_test_the_heading_table_is_a_circle_with_legacys_horizontal_bias()
	_test_the_same_seed_carves_the_same_world()
	_finish("cave_passes")


func _solid_world() -> TileGrid:
	var grid: TileGrid = TileGrid.new(W, H, 11)
	for col: int in W:
		for row: int in H:
			var cell := Vector2i(col, row)
			grid.set_material(cell, &"hardrock")
			grid.set_wall(cell, &"hardrock")
	return grid


func _deep_row() -> int:
	return H / 2


## One floor for every column: the passes take a per-column floor since A' step 8b (D0382); a flat one is
## the scalar these tests were written against.
func _floors(row: int) -> PackedInt32Array:
	return Relief.flat(W, row)


## Open cells over a row range. ONE function with two bindings rather than two functions: the
## duplication gate (D0099) caught the first version, where "how much of the world is open" and "did
## anything breach the protected band" were byte-identical under identifier normalization. It was right
## -- they differ only in which rows they look at.
func _open_cells(grid: TileGrid, from_row: int, to_row: int) -> int:
	var n: int = 0
	for col: int in W:
		for row: int in range(from_row, to_row):
			if not grid.is_solid(Vector2i(col, row)):
				n += 1
	return n


func _void_count(grid: TileGrid) -> int:
	return _open_cells(grid, 0, H)


## THE ASSERTION THE WHOLE FILE EXISTS FOR. A pass that ran and opened nothing is indistinguishable from
## a pass that was never called, and `docs/DECISIONS_LEDGER.md` D0285 records this project doing exactly
## that to itself once already. Both the reported count and the world's own void are checked, because
## they are different claims: the first says the function thinks it carved, the second says the grid
## agrees.
func _test_both_passes_open_cells_rather_than_running_and_doing_nothing() -> void:
	var grid: TileGrid = _solid_world()
	_check(_void_count(grid) == 0, "sanity: the fixture starts completely solid (%d void)" % _void_count(grid))
	var rng: SplitRng = SplitRng.new(2026).split("carve_passes")
	var halls: int = CavePasses.carve_big_caverns(grid, rng, _deep_row(), _floors(MIN_DEPTH), CELLS_PER_M)
	_check(halls > 0, "the cavern pass opens cells (%d)" % halls)
	_check(_void_count(grid) == halls,
		"and the grid holds exactly that many (%d vs %d) -- the count is the world, not a tally kept "
		% [_void_count(grid), halls] + "beside it")
	var after_halls: int = _void_count(grid)
	var worms: int = CavePasses.carve_tunnels(grid, rng, _floors(MIN_DEPTH), CELLS_PER_M)
	_check(worms > 0, "the tunnel pass opens cells (%d)" % worms)
	_check(_void_count(grid) > after_halls,
		"and the world has more void after it than before (%d -> %d)" % [after_halls, _void_count(grid)])


## The near-surface band is protected in legacy at every one of the four sites that can open a cell, and
## for one reason: a hall or a worm reaching row zero opens a chimney into spawn. Checked over the WHOLE
## band rather than at a sampled row, because a single off-by-one in one of the two passes is the shape
## this would take.
func _test_nothing_is_carved_into_the_protected_surface_band() -> void:
	# A POPULATION over twenty seeds, not one, and the reason is the whole difficulty of testing this
	# guard: a worm STARTS two metres below the boundary and can only breach it by wandering upward over
	# many steps, so most seeds never come near it and a single-seed run asserts nothing. The first two
	# attempts at a control here both read zero -- once by looking below the boundary, once by removing
	# the guard on one seed -- and both were the fixture failing to pose the subject rather than the guard
	# holding.
	var breaches: int = 0
	var reached_unguarded: int = 0
	var seeds: int = 20
	for seed: int in seeds:
		breaches += _band_openings(_carved_with(seed, MIN_DEPTH))
		reached_unguarded += _band_openings(_carved_with(seed, 0))
	_check_over(seeds, breaches == 0,
		"across %d seeds, not one cell above the protected depth is opened (%d)" % [seeds, breaches])
	# CONTROL, posed by REMOVING THE SUBJECT: the identical seeds with the guard set to zero DO open cells
	# up there. Without this the row above is satisfied by passes that simply never go near the surface.
	_check(reached_unguarded > 0,
		"CONTROL: with the guard at zero the same %d seeds open %d cells in that band, so the row above "
		% [seeds, reached_unguarded] + "is the guard working and not the passes staying away")


## Open cells strictly above `MIN_DEPTH` -- the band the guard protects.
func _band_openings(grid: TileGrid) -> int:
	return _open_cells(grid, 0, MIN_DEPTH)


## Both passes at one seed and one guard depth.
func _carved_with(seed: int, min_depth: int) -> TileGrid:
	var grid: TileGrid = _solid_world()
	var rng: SplitRng = SplitRng.new(seed).split("carve_passes")
	CavePasses.carve_big_caverns(grid, rng, _deep_row(), _floors(min_depth), CELLS_PER_M)
	CavePasses.carve_tunnels(grid, rng, _floors(min_depth), CELLS_PER_M)
	return grid


## LEGACY'S OWN STATED PURPOSE FOR THE PASS: worms "thread the isolated noise pockets into one connected
## system". Measured as the size of the largest connected open region, because that is what "connected"
## means and a void-fraction number cannot see it — the same total void split into forty pockets and
## joined into one system are the same fraction and completely different worlds.
func _test_the_worms_thread_the_pockets_into_one_system() -> void:
	# POSED WITH POCKETS, because that is what the pass exists to thread. The first version of this test
	# ran the worms against the CHAMBERS alone and the largest region did not move by a single cell --
	# correctly, since four worms in a world with four halls mostly miss them. The real generator hands
	# this pass a rock full of small disconnected noise pockets, so the fixture poses that instead.
	var grid: TileGrid = _solid_world()
	for col: int in range(10, W - 10, 9):
		for row: int in range(MIN_DEPTH + 8, H - 10, 9):
			_stamp(grid, Vector2i(col, row), 2)
	var before_regions: int = _region_count(grid)
	var before_largest: int = _largest_region(grid)
	var before_void: int = _void_count(grid)
	_check(before_regions > 50,
		"sanity: the fixture really is a field of SEPARATE pockets (%d regions, largest %d of %d open)"
		% [before_regions, before_largest, before_void])
	var rng: SplitRng = SplitRng.new(4242).split("carve_passes")
	CavePasses.carve_tunnels(grid, rng, _floors(MIN_DEPTH), CELLS_PER_M)
	var after_regions: int = _region_count(grid)
	var after_largest: int = _largest_region(grid)
	_check(after_largest > before_largest,
		"the worms grow the largest connected system (%d -> %d cells)" % [before_largest, after_largest])
	_check(after_regions < before_regions,
		"and there are FEWER separate systems afterwards (%d -> %d) -- pockets joined, which is the whole "
		% [before_regions, after_regions] + "point of the pass")
	# The strong form. Total void necessarily rises when anything is carved, so the claim has to be about
	# the SHARE the largest system holds: a worm that carved a long private corridor would raise the void
	# and the largest region together while connecting nothing.
	var before_share: float = float(before_largest) / float(before_void)
	var after_share: float = float(after_largest) / float(_void_count(grid))
	_check(after_share > before_share,
		"and the largest system holds a bigger SHARE of all open space than before (%.4f -> %.4f)"
		% [before_share, after_share])


## The chamber's bottom third stays solid, which is what makes a hall somewhere you stand rather than a
## lens you fall through. One chamber, carved alone, so the floor is this pass's own and not a worm's.
func _test_a_chamber_keeps_a_floor_under_it() -> void:
	var grid: TileGrid = _solid_world()
	var rng: SplitRng = SplitRng.new(99).split("carve_passes")
	CavePasses.carve_big_caverns(grid, rng, _deep_row(), _floors(MIN_DEPTH), CELLS_PER_M)
	# For every open cell, is there solid rock somewhere below it in the same column? A chamber cut clean
	# through would have open cells with nothing under them all the way down.
	var unfloored: int = 0
	var open_seen: int = 0
	for col: int in W:
		for row: int in range(MIN_DEPTH, H):
			if grid.is_solid(Vector2i(col, row)):
				continue
			open_seen += 1
			var floored := false
			for below: int in range(row + 1, H):
				if grid.is_solid(Vector2i(col, below)):
					floored = true
					break
			if not floored:
				unfloored += 1
	_check(open_seen > 0, "sanity: there are chambers to check (%d open cells)" % open_seen)
	_check_over(open_seen, unfloored == 0,
		"every open cell has solid rock below it in its own column (%d of %d unfloored) -- the bottom of "
		% [unfloored, open_seen] + "an ellipse is left solid on purpose")


## CONSTANT MUST DOMINATE CONSTANT, and this is the one that WG-4 would otherwise break silently. Legacy
## calibrated its rates against a world of ONE-METRE cells. Driving them off our cell counts would put
## sixteen halls where legacy put one, and the world would look plausible either way.
##
## Asserted as the invariance that matters: the same PHYSICAL world at two different resolutions must get
## the same number of chambers.
func _test_the_count_is_denominated_in_metres_not_in_cells() -> void:
	var coarse: int = CavePasses.count_for(50, 80, CavePasses.CAVERN_PER_M_COL, 1)
	var fine: int = CavePasses.count_for(50 * 4, 80 * 4, CavePasses.CAVERN_PER_M_COL, 4)
	_check(coarse > 0, "sanity: a legacy-sized world gets chambers at all (%d)" % coarse)
	_check(coarse == fine,
		"the same physical world gets the same count at 1 and at 4 cells per metre (%d vs %d) -- a "
		% [coarse, fine] + "cell-denominated rate would give %d here"
		% CavePasses.count_for(50 * 4, 80 * 4, CavePasses.CAVERN_PER_M_COL, 1))
	# CONTROL: it is not simply insensitive to its inputs. A world twice as big physically gets more.
	_check(CavePasses.count_for(100 * 4, 80 * 4, CavePasses.CAVERN_PER_M_COL, 4) > fine,
		"CONTROL: a physically wider world gets more chambers (%d vs %d)"
		% [CavePasses.count_for(100 * 4, 80 * 4, CavePasses.CAVERN_PER_M_COL, 4), fine])
	_check(CavePasses.count_for(50, 80, CavePasses.CAVERN_PER_M_COL, 0) == 0,
		"and a zero resolution answers zero rather than dividing by it")


## The table replaces `cos`/`sin`, which this generator may not call — the goldens are captured on CI
## Linux and evaluated on macOS, and libm is not required to agree in the last bit. So the table has to
## BE a circle, checked as one, and it has to carry legacy's `* 0.55` vertical squash.
func _test_the_heading_table_is_a_circle_with_legacys_horizontal_bias() -> void:
	var dirs: Array[Vector2i] = CavePasses.DIRS
	_check(dirs.size() == 16, "sixteen headings, 22.5 degrees apart (%d)" % dirs.size())
	var worst: int = 0
	var max_dx: int = 0
	var max_dy: int = 0
	for i: int in dirs.size():
		# Opposite entries must negate exactly, or a worm's wander is biased in one direction.
		var opposite: Vector2i = dirs[(i + dirs.size() / 2) % dirs.size()]
		if dirs[i] != -opposite:
			worst += 1
		max_dx = maxi(max_dx, absi(dirs[i].x))
		max_dy = maxi(max_dy, absi(dirs[i].y))
	_check_over(dirs.size(), worst == 0, "every heading has an exact opposite (%d do not)" % worst)
	_check(max_dx == CavePasses.DIR_SCALE,
		"the horizontal reach is a full unit step (%d of %d)" % [max_dx, CavePasses.DIR_SCALE])
	_check(max_dy < max_dx,
		"and the vertical reach is squashed below it (%d vs %d) -- legacy's 0.55 bias, which is what "
		% [max_dy, max_dx] + "makes a worm a tunnel rather than a well")
	# The bias is the ratio, so it is checked as one rather than as "smaller".
	_check(absi(max_dy * 100 / max_dx - 55) <= 1,
		"and the ratio is legacy's 0.55 (%.3f)" % (float(max_dy) / float(max_dx)))


## The generator's whole contract. Checked by carving twice and comparing every cell, with a different
## seed as the control -- two identical runs prove nothing if the passes are insensitive to the seed.
func _test_the_same_seed_carves_the_same_world() -> void:
	var a: TileGrid = _carved(1234)
	var b: TileGrid = _carved(1234)
	var c: TileGrid = _carved(1235)
	var same: int = 0
	var differ: int = 0
	for col: int in W:
		for row: int in H:
			var cell := Vector2i(col, row)
			if a.is_solid(cell) != b.is_solid(cell):
				same += 1
			if a.is_solid(cell) != c.is_solid(cell):
				differ += 1
	_check_over(W * H, same == 0, "the same seed carves an identical world (%d cells differ)" % same)
	_check(differ > 0,
		"CONTROL: a different seed carves a different one (%d cells differ) -- without this the row "
		% differ + "above passes on a pass that ignores its seed entirely")


func _carved(seed: int) -> TileGrid:
	var grid: TileGrid = _solid_world()
	var rng: SplitRng = SplitRng.new(seed).split("carve_passes")
	CavePasses.carve_big_caverns(grid, rng, _deep_row(), _floors(MIN_DEPTH), CELLS_PER_M)
	CavePasses.carve_tunnels(grid, rng, _floors(MIN_DEPTH), CELLS_PER_M)
	return grid


## Cells in the largest 4-connected open region. Iterative rather than recursive: a region here runs to
## tens of thousands of cells and GDScript has no tail call.
func _largest_region(grid: TileGrid) -> int:
	var seen: Dictionary = {}
	var best: int = 0
	for col: int in W:
		for row: int in H:
			var start := Vector2i(col, row)
			if grid.is_solid(start) or seen.has(start):
				continue
			var size: int = 0
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				size += 1
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if n.x < 0 or n.x >= W or n.y < 0 or n.y >= H or seen.has(n) or grid.is_solid(n):
						continue
					seen[n] = true
					stack.append(n)
			best = maxi(best, size)
	return best


## A disc of open air, for posing a fixture. Deliberately not `CavePasses._carve_disc`: a test that used
## the subject to build its own fixture could not tell a broken disc from a broken pass.
func _stamp(grid: TileGrid, centre: Vector2i, radius: int) -> void:
	for dy: int in range(-radius, radius + 1):
		for dx: int in range(-radius, radius + 1):
			if dx * dx + dy * dy > radius * radius:
				continue
			var c: Vector2i = centre + Vector2i(dx, dy)
			if c.x >= 0 and c.x < W and c.y >= 0 and c.y < H and grid.is_solid(c):
				grid.excavate(c)


## How many separate 4-connected open regions the world holds.
func _region_count(grid: TileGrid) -> int:
	var seen: Dictionary = {}
	var regions: int = 0
	for col: int in W:
		for row: int in H:
			var start := Vector2i(col, row)
			if grid.is_solid(start) or seen.has(start):
				continue
			regions += 1
			var stack: Array[Vector2i] = [start]
			seen[start] = true
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if n.x < 0 or n.x >= W or n.y < 0 or n.y >= H or seen.has(n) or grid.is_solid(n):
						continue
					seen[n] = true
					stack.append(n)
	return regions
