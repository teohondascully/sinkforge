class_name Aim
extends RefCounted

## Terraria-style mining reach: you do not have to land the cursor exactly on a reachable cell. Pointing
## at a block that is out of reach snaps the aim to the closest reachable block toward your cursor, so
## you see what you will hit. Precise in-reach hovering is unchanged, and while building the aim stays
## exact: placement wants the cell you point at. Lifted in A' step 3i (D0354) from `legacy/scenes/main.gd`
## `_effective_aim` 1855 and `_nearest_reachable_solid` 1866, with the float distances as `Fx` squares.
##
## Every position is an `Fx` world pixel; every cell a terrain cell. The pointer's world position is
## the caller's (a recorded world point, never the raw OS pointer: the-human-is-inside-the-measurement).

const CELL_FX: int = Mining.CELL_PX * Fx.SCALE
const LOGIC_FX: int = Mining.LOGIC_TILE_PX * Fx.SCALE
## The snap tolerance is one reach radius from the cursor, squared, scaled by REACH_DEN^2 so the compare
## stays integer: point at or near a wall and it snaps; point at open air far off and it does not.
const REACH_PX_FX_NUM: int = Mining.REACH_NUM * Mining.LOGIC_TILE_PX * Fx.SCALE
## Cells scanned either side of the body: the reach in terrain cells, rounded up, plus one.
const SPAN: int = (Mining.REACH_NUM * Mining.LOGIC_TILE_PX + Mining.REACH_DEN * Mining.CELL_PX - 1) / (Mining.REACH_DEN * Mining.CELL_PX) + 1


## THE ONE REACH RULE (`Mining.REACH_NUM/DEN` metres, Euclidean, inclusive, compared squared): is the
## `Fx` point within reach of the body? `Mining.in_reach` delegates here for a terrain cell's centre and
## `in_reach_logic` for a metre's, so the verbs that work at the metre share the primitive's circle.
## Squared, never `sqrt`. The axis reject first BOUNDS the operands: without it a body at the bottom of a
## 4096 px world squaring a full-height delta runs near int64's headroom; after it both terms are bounded.
static func in_reach_point(body_x: int, body_y: int, point_x: int, point_y: int) -> bool:
	var dx: int = point_x - body_x
	var dy: int = point_y - body_y
	var bound: int = ((Mining.REACH_NUM * Mining.LOGIC_TILE_PX) / Mining.REACH_DEN + 1) * Fx.SCALE
	if absi(dx) > bound or absi(dy) > bound:
		return false
	var radius_px_fx: int = Mining.LOGIC_TILE_PX * Fx.SCALE
	return (Mining.REACH_DEN * Mining.REACH_DEN) * (dx * dx + dy * dy) <= \
		(Mining.REACH_NUM * Mining.REACH_NUM) * (radius_px_fx * radius_px_fx)


static func in_reach_logic(body_x: int, body_y: int, logic_cell: Vector2i) -> bool:
	var half: int = LOGIC_FX / 2
	return in_reach_point(body_x, body_y, logic_cell.x * LOGIC_FX + half, logic_cell.y * LOGIC_FX + half)


## The terrain cell an `Fx` world point is in (floor division, so a point just left of zero is cell -1).
static func cell_of(point_x: int, point_y: int) -> Vector2i:
	return Vector2i(floor_div(point_x, CELL_FX), floor_div(point_y, CELL_FX))


## The metre cell an `Fx` world point is in.
static func logic_cell_of(point_x: int, point_y: int) -> Vector2i:
	return Vector2i(floor_div(point_x, LOGIC_FX), floor_div(point_y, LOGIC_FX))


static func floor_div(a: int, b: int) -> int:
	var q: int = a / b
	if a % b != 0 and ((a < 0) != (b < 0)):
		q -= 1
	return q


static func cell_center_fx(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x * CELL_FX + CELL_FX / 2, cell.y * CELL_FX + CELL_FX / 2)


## The aim for a pointer at (`point_x`, `point_y`): the exact cell while building; else an open cell in
## reach or a solid block in reach with a clear line of sight; else the nearest reachable solid toward
## the cursor; else the raw cell (nothing snaps when the cursor is far from any wall).
static func effective(grid: TileGrid, body_x: int, body_y: int, point_x: int, point_y: int, building: bool) -> Vector2i:
	var raw: Vector2i = cell_of(point_x, point_y)
	if building:
		return raw
	var body_cell: Vector2i = cell_of(body_x, body_y)
	if Mining.in_reach(body_x, body_y, raw) and (not grid.is_solid(raw) or LineOfSight.clear(grid, body_cell, raw)):
		return raw
	return nearest_reachable_solid(grid, body_x, body_y, point_x, point_y, raw)


## The reachable, visible solid cell whose centre is closest to the point, within one reach radius of it,
## else `fallback`. Scans the in-reach neighbourhood in a fixed row-major order, so ties are stable.
static func nearest_reachable_solid(grid: TileGrid, body_x: int, body_y: int, point_x: int, point_y: int, fallback: Vector2i) -> Vector2i:
	var body_cell: Vector2i = cell_of(body_x, body_y)
	var best: Vector2i = fallback
	var best_d: int = -1
	for dy: int in range(-SPAN, SPAN + 1):
		for dx: int in range(-SPAN, SPAN + 1):
			var c: Vector2i = body_cell + Vector2i(dx, dy)
			if not grid.in_bounds(c) or not grid.is_solid(c) or not Mining.in_reach(body_x, body_y, c):
				continue
			if not LineOfSight.clear(grid, body_cell, c):
				continue
			var centre: Vector2i = cell_center_fx(c)
			var d: int = Fx.length_sq(centre.x - point_x, centre.y - point_y)
			if d * Mining.REACH_DEN * Mining.REACH_DEN > REACH_PX_FX_NUM * REACH_PX_FX_NUM:
				continue                                        # farther than a reach from the cursor
			if best_d < 0 or d < best_d:
				best_d = d
				best = c
	return best
