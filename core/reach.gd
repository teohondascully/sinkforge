class_name Reach
extends RefCounted

## THE ONE REACH RULE, IN CORE (D0521). A drop feeds a machine, BUILD sets a machine down, and a hold cuts
## rock when the target's centre is within `NUM/DEN` metres of the body's CENTRE -- Euclidean, inclusive,
## compared squared. The arithmetic was `sim/mining/aim.gd`'s `in_reach_point`, and the sim still calls it
## there; it moved here because the VIEW has to draw the same line. Strangers 103-120 stood one cell past
## the drop's band with the forge ringed and pressed Q eleven times at TOO FAR, and nothing on screen said
## which side of the line they were on: `TargetGuide` outlined the block within its own NEAR_M, a rule
## written for the pointer and a different number from the drop's. `view` may depend on `core` and never
## on `sim`, so the rule and its rational live at the floor of the stack and both sides read them.
##
## Held as a rational so the squared compare stays in exact integers: 3.2 m == 16/5. Legacy's
## `REACH_CELLS = 3.2` at its own 32 px cell and this world's 16 px metre are both ONE METRE, so the
## portable quantity is the metres (`sim/mining/mining.gd`'s REACH note, D0354). Every position is an `Fx`
## world pixel; the metre's pixel size is the caller's, because this file may not know `Body`'s tile.

const NUM: int = 16
const DEN: int = 5


## Is the `Fx` point within reach of the body? Squared, never `sqrt`. The axis reject first BOUNDS the
## operands: without it a body at the bottom of a 4096 px world squaring a full-height delta runs near
## int64's headroom; after it both terms are bounded. `tile_px` is the metre in world px (16).
static func in_reach(body_x: int, body_y: int, point_x: int, point_y: int, tile_px: int) -> bool:
	var dx: int = point_x - body_x
	var dy: int = point_y - body_y
	var bound: int = ((NUM * tile_px) / DEN + 1) * Fx.SCALE
	if absi(dx) > bound or absi(dy) > bound:
		return false
	var radius_px_fx: int = tile_px * Fx.SCALE
	return (DEN * DEN) * (dx * dx + dy * dy) <= (NUM * NUM) * (radius_px_fx * radius_px_fx)


## Is the metre cell's CENTRE within reach of the body? The drop's and BUILD's own question
## (`Verbs.can_reach` through `Aim.in_reach_logic`), and the ring's (`RingPainter`), with the same inputs.
static func in_reach_metre(body_x: int, body_y: int, cell: Vector2i, tile_px: int) -> bool:
	var centre: Vector2i = metre_centre_fx(cell, tile_px)
	return in_reach(body_x, body_y, centre.x, centre.y, tile_px)


## The `Fx` centre of a metre cell.
static func metre_centre_fx(cell: Vector2i, tile_px: int) -> Vector2i:
	var metre_fx: int = tile_px * Fx.SCALE
	var half: int = metre_fx / 2
	return Vector2i(cell.x * metre_fx + half, cell.y * metre_fx + half)
