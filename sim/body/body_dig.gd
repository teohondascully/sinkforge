class_name BodyDig
extends RefCounted

## THE DIG HALF OF `sim/body/body.gd`, split out at the 400-line file cap (D0310). `tests/test_body_dig.gd`
## already made this seam once, at D0269, and called it "the dig half: which cell, which rows, what it
## reports" -- the file follows the suite rather than the other way round.
##
## Static and stateless: the body owns every field these read, so this is the same code in a different
## address and not a new object with a lifetime. `docs/QUALITY.md` §2 on why the cap is met by splitting.

## The column of cells horizontally adjacent to the body's leading edge, in `b.facing`'s direction --
## `handle` excavates the WHOLE column spanning the body's own height (D0113), this returns just its
## x plus the body's centre row for bounds-checking and reporting. Horizontal-only on purpose
## (docs/DECISIONS_LEDGER.md D0110) -- the reveal-layer test this exists for is scoped to lateral search
## (docs/GDD.md §8/§12), and a single well-defined direction avoids the aim-direction design question a
## vertical/diagonal dig would raise (which key means "down," does it compete with mantle_hold's up-key)
## without a stated answer yet.
##
## `b._right_x()`/`b._left_x()` are the box's edges over a HALF-OPEN [left,right) range, same as
## `_box_blocked`'s own `right - 1`/`bottom - 1` convention (docs/DECISIONS_LEDGER.md D0112) -- a body
## resting with its right edge exactly on a cell boundary has `b._px_to_cell(b._right_x())` already equal to
## the cell just ahead of it (not one it occupies), so `+ b.facing` on that value overshoots by one cell.
## The left edge doesn't need the same `- 1`: floor's rounding already gives the leftmost occupied cell
## there, correctly, with no adjustment.
static func terrain_target_cell(b: Body) -> Vector2i:
	var cx: int = b._px_to_cell(b._right_x() - 1) + 1 if b.facing > 0 else b._px_to_cell(b._left_x()) - 1
	var cy: int = b._px_to_cell(b.pos_y)
	return Vector2i(cx, cy)


## Excavates the dig target COLUMN across its own FULL HISTORICAL dig extent, not just the body's
## current height -- a single-row notch cannot be walked through by a body several cells tall
## (docs/DECISIONS_LEDGER.md D0113), and a column dug at two different body-heights without ever being
## dug in between leaves a gap the body's own later, differently-positioned footprint can straddle
## (D0122/D0123's staircase). `TileGrid.extend_terrain_dig_extent` (D0125) is the fix: it folds this touch into
## the column's own historical [min,max] and returns the merged range, so a column is always one
## contiguous open span from the lowest row ever dug there to the highest -- never re-computed from the
## body's own current height alone. A press against a column that's already fully open is not an event;
## a partially-open column still counts once any new cell clears. `b.dug_material_this_tick` reports
## `glimmer` if the excavated range held it anywhere, else the first real material found.
static func handle(b: Body, grid: TileGrid) -> void:
	var target: Vector2i = terrain_target_cell(b)
	if not grid.in_bounds(target):
		return
	var touch_top: int = maxi(0, b._px_to_cell(b._top_y()) - Heightfield.DIG_HEADROOM_CELLS)
	var touch_bottom: int = b._px_to_cell(b._bottom_y() - 1)
	var extent: Vector2i = grid.extend_terrain_dig_extent(target.x, touch_top, touch_bottom)
	var reported_material: StringName = &""
	for row: int in range(extent.x, extent.y + 1):
		var cell: Vector2i = Vector2i(target.x, row)
		if not grid.in_bounds(cell):
			continue
		var material: StringName = grid.get_material(cell)
		if material == &"":
			continue
		grid.excavate(cell)
		if reported_material == &"" or material == &"glimmer":
			reported_material = material
	b.dig_event_this_tick = reported_material != &""
	b.dug_material_this_tick = reported_material
