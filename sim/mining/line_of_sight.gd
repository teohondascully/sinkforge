class_name LineOfSight
extends RefCounted

## Is the straight segment from terrain cell `a` to terrain cell `b` clear of solid cells strictly
## between them? A grid voxel walk (Amanatides-Woo DDA) from a toward b: the first solid cell entered
## before reaching b blocks the ray. The target b itself may be solid, since it is what you are mining,
## and adjacent cells are always clear because no cell lies between. Pure read of the grid.
##
## Lifted in A' step 3i (D0354) from `legacy/scenes/main.gd` `_line_of_sight_clear` 2877, RE-DERIVED IN
## INTEGERS (the plan's §3.2 row: "the DDA re-derived in integers, absent from both trees"). Legacy
## walked with float `t_max`/`t_delta`; the ray starts at a's centre and ends at b's, so with dx = b.x -
## a.x the distance to the k-th x-boundary is (2k + 1) / (2|dx|) of the ray, and "t_max_x < t_max_y" is
## exactly `(2kx + 1) * |dy| < (2ky + 1) * |dx|`. Ties step y first, as legacy's `<` did. At most
## |dx| + |dy| steps reach b, so the walk is bounded by construction.

static func clear(grid: TileGrid, a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	var dx: int = b.x - a.x
	var dy: int = b.y - a.y
	var adx: int = absi(dx)
	var ady: int = absi(dy)
	var sx: int = signi(dx)
	var sy: int = signi(dy)
	var cx: int = a.x
	var cy: int = a.y
	var kx: int = 0
	var ky: int = 0
	for _step: int in adx + ady:
		if adx > 0 and (ady == 0 or (2 * kx + 1) * ady < (2 * ky + 1) * adx):
			cx += sx
			kx += 1
		else:
			cy += sy
			ky += 1
		if cx == b.x and cy == b.y:
			return true                  # reached the target: nothing solid in the way
		if grid.is_solid(Vector2i(cx, cy)):
			return false                 # a solid cell before the target blocks the dig
	return true
