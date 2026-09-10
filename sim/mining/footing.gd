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


## How far either side of the body's own columns still counts as digging out from under yourself. ONE
## cell, and the number is not free: `tests/test_interface_verbs.gd` fires D0509's side blow two cells
## clear of the boots and requires it to be spared, so the margin cannot reach 2 without turning that
## suite red. A player aiming down is inside their own four columns; a player working a vein beside them
## is not.
const OUT_MARGIN: int = 1


## THE WAY DOWN (D0440), made true at the controls (D0568). What `spare` should be for a blow aimed at
## `aim`: the footing, unless the blow is the player deliberately cutting the floor out from under
## themselves, in which case nothing is spared and they drop.
##
## D0509 is right and this does not weaken it. Read its own words for the case it exists for: "a blow on
## the vein one metre TO THE SIDE reaches under the body's own boots, the floor goes, the body drops a
## metre into the hole it did not mean to dig". The rule is about a SIDEWAYS blow, and it was written as
## "spare unless the aim is exactly one of the four" -- which also silently swallows a blow aimed
## straight down, because the disc is two cells wide and the four boot cells are 4 px each. The measured
## consequence: an Opus playthrough cut eleven cells straight down beneath itself across eight bursts and
## descended ZERO, and needed 31 bursts to fall its first metre and a half only after reading this file
## and computing the support row by hand. The `cut_through` lesson tells the player "a hole has to be a
## little wider than you before you drop in", which is a description of this bug rather than a rule of
## the world.
static func spared_for(body: Body, aim: Vector2i) -> Array[Vector2i]:
	var feet: Array[Vector2i] = of_body(body)
	if feet.is_empty():
		return feet
	if aim.y >= feet[0].y and aim.x >= feet[0].x - OUT_MARGIN and aim.x <= feet[feet.size() - 1].x + OUT_MARGIN:
		return []                    # aimed at or below the boots, within reach of their own columns
	return feet
