class_name TreePass
extends RefCounted
## Surface trees: legacy `layered_world_gen.gd` `_plant_trees` (:920-955), ported in A' step 8g (D0387)
## onto the deterministic generator. A trunk of `wood` two to three metres tall on solid ground with a
## canopy of `leaves` over it; at most one tree every `gap_m`, at `chance` a metre of ground, none where
## the ground under any trunk column is broken within the cave band (`_footed`) and none on the start's
## pad. Legacy's trunk was one
## metre-cell wide and its canopy six cells in a T over it; here the trunk is `trunk_w_m` wide and the
## canopy an ellipse `canopy_w_m` by `canopy_h_m`, by the cell, so a tree reads as one at this scale.
##
## Trees are blocks with no wall behind them, as legacy's were: dug, they leave sky.

const MILLI: int = 1000


## Plant the trees; returns how many. `keepout` is the first and last column, inclusive, no tree may root
## in -- the pad the start record is stamped onto and a margin about it.
static func plant(grid: TileGrid, rng: SplitRng, cfg: Dictionary, surface: PackedInt32Array, keepout: Vector2i,
		cells_per_m: int, band: int) -> int:
	var planted: int = 0
	var last: int = -grid.width
	var gap: int = int(cfg["gap_m"]) * cells_per_m
	var chance: float = float(cfg["chance"]) / float(cells_per_m)    # legacy's rate was a metre of ground
	var g: Dictionary = geometry(cfg, cells_per_m)
	var trunk_w: int = g["trunk_w"]
	var rx: int = g["rx"]
	var ry: int = g["ry"]
	for col: int in grid.width:
		if col >= keepout.x and col <= keepout.y:
			continue
		if col - last < gap or rng.next_float() > chance:
			continue
		var ground: int = surface[col]
		if not _footed(grid, col, ground, trunk_w, band):
			continue                                   # a mouth, a rift, or ground the far trunk column misses
		var trunk: int = rng.next_range(int(cfg["trunk_min_m"]), int(cfg["trunk_max_m"])) * cells_per_m
		var top: int = ground - trunk                  # the row of the topmost trunk cell
		if top - 2 * ry < 0:
			continue                                   # not enough sky above for trunk and canopy
		if _blocked(grid, col, ground, trunk, trunk_w):
			continue                                   # a hill cell already occupies the trunk space
		plant_one(grid, col, ground, trunk, trunk_w, rx, ry)
		last = col
		planted += 1
	return planted


## The tree's cell geometry from a site's `tree` config: trunk width and the canopy's half-axes, in cells.
static func geometry(cfg: Dictionary, cells_per_m: int) -> Dictionary:
	return {
		"trunk_w": maxi(1, Relief.milli_cells(float(cfg["trunk_w_m"]), cells_per_m) / MILLI),
		"rx": maxi(1, Relief.milli_cells(float(cfg["canopy_w_m"]), cells_per_m) / (2 * MILLI)),
		"ry": maxi(1, Relief.milli_cells(float(cfg["canopy_h_m"]), cells_per_m) / (2 * MILLI)),
	}


## One tree: a trunk of `trunk` cells of wood rising from the cell above `ground` at `col`, `trunk_w` wide,
## and the canopy ellipse over it. Shared by the pass and by a start record's `tree` fixture (D0425), so
## the tutorial's guaranteed tree is the same shape as the world's.
static func plant_one(grid: TileGrid, col: int, ground: int, trunk: int, trunk_w: int, rx: int, ry: int) -> void:
	for h: int in range(1, trunk + 1):
		for dx: int in trunk_w:
			grid.set_material(Vector2i(col + dx, ground - h), &"wood")
	_canopy(grid, Vector2i(col + trunk_w / 2, ground - trunk - ry), rx, ry, col)


## THE FOOTING, UNDER EVERY TRUNK COLUMN AND FOR THE WHOLE BAND (D0600, director-reported).
##
## This used to be `grid.is_solid(Vector2i(col, ground))`: ONE column, ONE cell. `plant_one` writes wood
## across `col .. col + trunk_w - 1` at that same row, so the far trunk column was never tested at all,
## and nothing was ever tested deeper than a single cell. Measured on the shipped seed 20260826, as solid
## cells straight down from each root before the first open one: `56/57 -> 1/0`, `69/70 -> 1/1`,
## `214/215 -> 175/0`. A lid of 0 is a trunk column standing on an open cell, and 214/215 is one tree with
## one half in 175 cells of rock and the other half over a void.
##
## **THE DEPTH IS THE CAVE BAND, DERIVED RATHER THAN PICKED.** Every carve pass in the generator refuses
## the band under a column's own surface -- `ShaftGenerator._carve_caves`, `CavePasses` through
## `Relief.offset`, `VerticalPasses._carve_row`, `StuddingPasses.open_terrain_cells` all take the same
## `site.cave.min_depth_cells` -- so the world already guarantees exactly this much unbroken ground
## everywhere it has not been deliberately broken open. The one pass that breaks it is
## `VerticalPasses.open_sinkholes`, which cuts a mouth UP from a rift's ceiling to daylight. A tree asking
## for the band is asking for the ground the world promises, and is refused in exactly the places that
## promise was cut: the rim and the lid of a sinkhole mouth. That is the director's "flat platforms over
## shafts", and it is why this is not a new constant.
##
## The far trunk column's own surface falls out of the same loop for free: where `surface[col + dx]` sits
## LOWER than `surface[col]`, the cell at `ground` in that column is sky, and sky is not solid.
## `_blocked` already refuses the mirror case, a neighbour standing higher than the trunk's own root.
static func _footed(grid: TileGrid, col: int, ground: int, trunk_w: int, band: int) -> bool:
	for dx: int in trunk_w:
		for d: int in band:
			var cell := Vector2i(col + dx, ground + d)
			if not grid.in_bounds(cell) or not grid.is_solid(cell):
				return false
	return true


static func _blocked(grid: TileGrid, col: int, ground: int, trunk: int, trunk_w: int) -> bool:
	for h: int in range(1, trunk + 1):
		for dx: int in trunk_w:
			var cell := Vector2i(col + dx, ground - h)
			if not grid.in_bounds(cell) or grid.is_solid(cell):
				return true
	return false


## HOW MANY DISTINCT CANOPIES THIS WORLD HAD, AND WHY IT WAS ONE (D0601, queue item 53).
##
## `geometry` computes `rx` and `ry` ONCE per world from the site record, and this function drew that one
## integer ellipse at every tree: from `shallow_clay.yaml`'s `canopy_w_m: 3.0` / `canopy_h_m: 2.5`, a
## 13x11 cell ellipse, the same 13x11 cell ellipse, on every trunk in the world. The only thing that
## differed between two trees was trunk height -- `trunk_min_m` to `trunk_max_m`, one of two values. A
## circle on a stick, repeated: the lollipop.
##
## A CANOPY IS BOUGHS. Three overlapping lobes instead of one ellipse, so the outline is lumpy, the lumps
## are somewhere else on the next tree, and no two crowns in sight are the same mass.
##
## **THE CROWN IS A PURE FUNCTION OF THE ROOT COLUMN, NOT AN RNG DRAW**, for two reasons that both
## mattered. `world_seeder.gd:144` plants the start record's guaranteed tree through `plant_one` with no
## stream to draw from (D0425) -- keyed off the column, the tutorial's tree gets its own crown for free
## and stays the same tree every boot. And a draw here would sit inside `plant`'s loop, where the tree
## layout already depends on the draw order: asking for a shape would change WHICH columns get trees.
## A shape change that moves the forest is a shape change nobody can review.
const LOBE_INTS: int = 3                       ## (ox, oy, r) per lobe
const LOBES_PER_CROWN: int = 3

## Six crowns, each three lobes of (ox, oy, r) in THOUSANDTHS of the record's own `rx`/`ry` -- the site
## keeps control of how big a tree is and this table only says what shape it is. Every lobe satisfies
## `|o| + r <= 1000` in both axes, so a crown still fits the bounding box the single ellipse used and the
## scan below did not have to widen. The radii sum past the whole, so the lobes overlap into one mass
## with a broken edge rather than reading as three balls. The fourth is deliberately the sparsest and the
## sixth the smallest: some trees are younger than others, and that is the variation `docs/WORKING.md`
## item 27 asked for at the only scale a 4 px cell can carry it. Against the shipped record's 91-cell
## ellipse the six come out 98, 84, 84, 67, 74 and 75 cells.
##
## EVERY CROWN HAS TO SIT ON ITS TRUNK, and that is the one property of this table that is not taste: the
## canopy's centre is `ry` above the top trunk cell, so the cell just above the trunk is `(dx, dy) =
## (-1, ry - 1)` and a crown that misses it leaves the canopy floating over a bare stick, which is worse
## than the lollipop it replaced. Checked here at the record's own (6, 5) and held at (4, 3), (9, 7) and
## (12, 10) as well; far below that a crown is a handful of cells and the six stop being distinguishable,
## which is a statement about seven-cell canopies and not about this table.
const CROWN_INTS: int = LOBE_INTS * LOBES_PER_CROWN
const CROWNS: PackedInt32Array = [
	-300, 230, 740,    300, 190, 740,     0, -250, 780,   ## broad, sitting low
	-200, 240, 700,    180, -60, 780,   -30, -290, 740,   ## tall and narrow
	-340, -60, 700,    120, 220, 780,    60, -300, 700,   ## lopsided to the left
	-380,  60, 620,    340, 120, 660,     0,  180, 760,   ## wide and flat
	-250, -80, 700,    250, -100, 700,    0,  240, 740,   ## upright, forked
	-220, 240, 700,    240,  60, 640,    10, -240, 700,   ## small: a younger tree
]


## Leaves in the crown about `centre`, only where there is nothing yet: the trunk stays wood.
static func _canopy(grid: TileGrid, centre: Vector2i, rx: int, ry: int, col: int) -> void:
	var crown: int = posmod(col, crown_count())
	for dy: int in range(-ry, ry + 1):
		for dx: int in range(-rx, rx + 1):
			if not in_crown(dx, dy, rx, ry, crown):
				continue
			var leaf: Vector2i = centre + Vector2i(dx, dy)
			if grid.in_bounds(leaf) and not grid.is_solid(leaf):
				grid.set_material(leaf, &"leaves")


## Is `(dx, dy)`, relative to the crown's centre, inside ANY of its lobes? Public because the shape is the
## claim -- `tests/test_tree_pass.gd` asserts the crowns are distinct from each other and that none of them
## is the ellipse this replaced, which is a question about this function and not about a planted world.
static func in_crown(dx: int, dy: int, rx: int, ry: int, crown: int) -> bool:
	var base: int = posmod(crown, crown_count()) * CROWN_INTS
	for i: int in LOBES_PER_CROWN:
		# IN THOUSANDTHS OF A CELL, NOT IN CELLS. Converting each lobe to whole cells first threw the
		# table away at the size a tree actually is: `140 * ry / 1000` with `ry` 5 is ZERO, so every
		# offset under a fifth collapsed onto the centre and every crown came out a shrunken circle.
		# One cell is MILLI here; the largest term is about (2 * rx * MILLI)^2 * (rx * MILLI)^2, which
		# for a crown of a hundred cells is ~1e15 against int64's 9.2e18.
		var cx: int = CROWNS[base + i * LOBE_INTS] * rx
		var cy: int = CROWNS[base + i * LOBE_INTS + 1] * ry
		var lrx: int = maxi(1, CROWNS[base + i * LOBE_INTS + 2] * rx)
		var lry: int = maxi(1, CROWNS[base + i * LOBE_INTS + 2] * ry)
		var ex: int = dx * MILLI - cx
		var ey: int = dy * MILLI - cy
		if ex * ex * lry * lry + ey * ey * lrx * lrx <= lrx * lrx * lry * lry:
			return true
	return false


## How many distinct crowns the table holds. Derived from the table's own length rather than written
## beside it, so a seventh crown is one row and not two edits.
static func crown_count() -> int:
	return CROWNS.size() / CROWN_INTS
