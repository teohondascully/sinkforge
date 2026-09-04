class_name Heightfield
extends RefCounted

## The "80% version" of Noita's polygon-contour ground plane, `docs/ARCHITECTURE.md` §9: derive a
## per-column surface height from the fine (4px) terrain grid and treat walkable ground as a
## heightfield, sub-pixel, linearly interpolated between columns. Ceilings and walls stay grid-swept
## (`TileGrid.is_solid()` directly) -- this file is the ground plane only.
##
## Every height this file returns is an `Fx` value (world-y in pixels), not a `TileGrid` cell index --
## named `_y` rather than `_cell`/`_row` throughout so a caller can't mistake one for the other.

const TERRAIN_CELL_PX: int = 4  ## docs/ARCHITECTURE.md §9: the terrain/digging grid's pixel size.

## D0269 (`docs/NEEDS_DIRECTOR.md` P022, the director's ruling). How many TERRAIN cells of clearance a
## dug tunnel leaves above the body's head, instead of stopping flush against it.
##
## **Lives here rather than on `Body` because it is a property of the TERRAIN GRID**, denominated in the
## cells this file owns, and because a body is not the only thing that will ever want to fit through a
## tunnel. (`sim/body/body.gd` was also at 396 of its 400-line cap, but that is why it is not THERE, not
## why it is HERE.)
##
## DERIVED, not picked. A tunnel carved to exactly the body's height leaves **zero** headroom -- measured
## directly, `headroom above the body = 0.0 px` -- so anything drawn taller than the collision box is
## permanently inside rock. That is what P022 was: the ported miner sprite is 48px against a 40px body,
## so its top 8px, helmet and pickaxe, sat in the ceiling on every frame. 8px / `TERRAIN_CELL_PX` = **2**.
##
## Stated as a WORLD property and not as a rendering fix, deliberately. `sim/` may not know what `view/`
## draws, and a constant justified by "the current sprite is 48 tall" would need changing every time art
## does. The durable claim is the one legacy shipped: a tunnel a person dug has clearance above their
## head. Legacy got it for free -- its `CELL` was 32px, so every dug tunnel had a full cell of slack.
## Ours is 4px and carved flush. This restores legacy's property by the mechanism this build needs.
##
## NOT applied to width. The body digs the column it faces, and widening that changes what a dig COSTS,
## which is an economy question and not this one.
const DIG_HEADROOM_CELLS: int = 2

## Definitionally "no floor found within the scanned range" -- i32 max, never a value a real surface
## height could produce (`docs/ARCHITECTURE.md` §9's depth budget is 4096px). Distinct from a real fall:
## a caller seeing this must treat it as "the ground plane doesn't answer here," not as a valid height
## to lerp toward, which is why `surface_y_at_x` refuses to blend a real height against this sentinel.
const NO_FLOOR: int = 2147483647


## Row (`TileGrid` terrain-cell index, not px) of the topmost solid cell in `terrain_col`, scanning
## downward from `scan_from_row` for at most `max_rows`, or -1 if nothing solid is found in range.
## Bounded rather than scanning the whole grid: a caller (the body controller) always knows roughly
## where it is and passes a small window around its own position. `blocker` (A' step 5c, D0360) is the
## body's `Surroundings`, so a machine's tile is ground and a trunk is not -- the same answer the wall
## sweep gives; null reads bare terrain, as the view's surface query does.
static func _column_top_row(grid: TileGrid, terrain_col: int, scan_from_row: int, max_rows: int,
		blocker: Surroundings = null) -> int:
	for row: int in range(scan_from_row, scan_from_row + max_rows):
		var c := Vector2i(terrain_col, row)
		if (grid.is_solid(c) if blocker == null else blocker.blocks(grid, c)):
			return row
	return -1


## The world-y (`Fx`) of column `terrain_col`'s surface -- the top face of its topmost solid cell in
## range -- or `NO_FLOOR`.
static func column_surface_y(grid: TileGrid, terrain_col: int, scan_from_row: int, max_rows: int,
		blocker: Surroundings = null) -> int:
	var row: int = _column_top_row(grid, terrain_col, scan_from_row, max_rows, blocker)
	if row < 0:
		return NO_FLOOR
	return Fx.from_int(row * TERRAIN_CELL_PX)


## Sub-pixel walkable-surface height at a continuous world-x (`Fx`), linearly interpolated between the
## two terrain columns straddling it. Interpolation anchors are COLUMN CENTRES, so standing exactly on
## a column's centre reads that column's own height with no blend -- a flat floor reads flat, not
## rippled. Returns `NO_FLOOR` if either straddling column has no floor in range: a real gap has to
## read as a gap, never as an average with whatever is on the far side of it.
static func surface_y_at_x(grid: TileGrid, x_fx: int, scan_from_row: int, max_rows: int) -> int:
	var cell_px: int = TERRAIN_CELL_PX * Fx.SCALE
	var col: int = int(floor(float(x_fx) / float(cell_px)))
	var col_center: int = col * cell_px + cell_px / 2
	var left_col: int
	var t: int  ## Fx, 0..SCALE: how far from the left column's centre toward the right column's.
	if x_fx < col_center:
		left_col = col - 1
		t = Fx.div(x_fx - (left_col * cell_px + cell_px / 2), cell_px)
	else:
		left_col = col
		t = Fx.div(x_fx - col_center, cell_px)
	var right_col: int = left_col + 1
	var left_y: int = column_surface_y(grid, left_col, scan_from_row, max_rows)
	var right_y: int = column_surface_y(grid, right_col, scan_from_row, max_rows)
	if left_y == NO_FLOOR or right_y == NO_FLOOR:
		return NO_FLOOR
	return Fx.lerp(left_y, right_y, t)
