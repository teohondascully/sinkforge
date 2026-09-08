class_name Footing
extends RefCounted

## THE CELLS UNDER THE FEET (D0509; strangers 65, 90 and 100). The bite is a disc two cells wide about the
## aimed cell, and a body stands four cells wide: a blow on the vein one metre to the side reaches under the
## body's own boots, the floor goes, the body drops a metre into the hole it did not mean to dig, and three
## strangers never pressed SPACE again. A standing body's four support cells -- the row its bottom edge
## rests on, the columns it covers -- are spared by every blow whose AIM is not one of them. Aiming at the
## ground under you still opens it (THE WAY DOWN, D0440): the target itself is never spared, so the rule
## changes what a sideways blow takes, not what a downward one does. A body in the air has no footing and
## nothing is spared.

## The support row and columns of a body whose bottom edge is at `bottom_px` (whole px) and whose centre
## is at `centre_px`: the cell row the bottom edge rests on, every column the body's width covers.
static func cells(centre_x_px: int, bottom_y_px: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var row: int = Aim.floor_div(bottom_y_px, Mining.CELL_PX)
	var left: int = Aim.floor_div(centre_x_px - Body.WIDTH_PX / 2, Mining.CELL_PX)
	var right: int = Aim.floor_div(centre_x_px + Body.WIDTH_PX / 2 - 1, Mining.CELL_PX)
	for col: int in range(left, right + 1):
		out.append(Vector2i(col, row))
	return out


## The body's footing this tick, in `Fx` units: its support cells while it stands, nothing in the air.
static func of_body(body: Body) -> Array[Vector2i]:
	if not body.on_floor:
		return []
	return cells(body.pos_x / Fx.SCALE, body.pos_y / Fx.SCALE + Body.HEIGHT_PX / 2)
