class_name BodySwing
extends RefCounted

## The line on the body (A' step 5c, D0360): legacy `player.gd`'s swing coupling (:172-183, :271-274,
## :393-406) as a static pass over `Body`, the shape the resolvers take. Runs once per tick after both
## axes have integrated and collided: fly or chain the hook, reel, catch the line on corners, pull the
## body back onto the circle, cancel the outward half of its velocity, pump, let the winch's work land in
## the velocity, bleed a little, cap the arc.
##
## THE COLLISION HALF WAITS ON A RULING (plan §8, the resolver). Legacy moves the body onto the circle and
## then re-resolves both axes, so a swing into a wall stops at the wall and the line goes slack until the
## body swings back inside its radius. That re-resolve is the resolver's, which is parked; until it is
## ruled on the constraint YIELDS: a projected position whose box would overlap rock is refused, the body
## stays where the axis resolvers left it, and the line reads slack for the tick. The observable outcome
## is the same at a flat wall (stopped at the wall, slack); it differs at a corner, where legacy would
## slide the body along the face and this holds it. `tests/test_grapple_body.gd` pins the wall case.

## Air control is normally generous; on the rope it is deliberately weaker, because a swing that can be
## steered freely is flying and the pleasure of a pendulum is committing to an arc. Enough authority to
## pump and aim the release, no more. Legacy 0.42.
const SWING_ACCEL_NUM: int = 21
const SWING_ACCEL_DEN: int = 50
## A rope has losses; a frictionless one feels fake and a pumped swing never settles. Legacy 0.22 a
## second; per tick, v -= v * 11 / 3000.
const SWING_DRAG_NUM: int = 11
const SWING_DRAG_DEN: int = 3000
## A terminal speed for the arc: with almost no drag a driver pumping perfectly reached 6.6x RUN_SPEED,
## a slingshot rather than a swing. Legacy 2.8x.
const SWING_MAX_SPEED: int = (Body.RUN_SPEED * 14) / 5
## The throw leaves the hand, 18% of the body's height above its centre (legacy `hand()`).
const HAND_NUM: int = 18
const HAND_DEN: int = 100


static func hand_fx(body: Body) -> Vector2i:
	return Vector2i(body.pos_x, body.pos_y - (Body.HEIGHT_PX * Fx.SCALE * HAND_NUM) / HAND_DEN)


## The centre of the aimed TERRAIN cell: the recorded target of a throw (plan §3.2), never the raw pointer.
static func aim_fx(input: InputFrame) -> Vector2i:
	var c: int = Body.CELL_PX * Fx.SCALE
	return Vector2i(input.aim_col * c + c / 2, input.aim_row * c + c / 2)


static func step(body: Body, grid: TileGrid, input: InputFrame) -> void:
	var g: Grapple = body.grapple
	var hand: Vector2i = hand_fx(body)
	if input.grapple_pressed and input.has_aim:
		g.fire(hand, aim_fx(input))
	g.advance(grid, hand)
	var line_before: int = g.length      # see the refusal below: a refused pull must not ratchet (D0578)
	g.reel(input.climb_dir)
	if g.state != Grapple.State.ANCHORED:
		return
	var centre := Vector2i(body.pos_x, body.pos_y)
	g.update_line(grid, centre)
	var swung: Vector2i = g.constrain_position_fx(centre)
	if not g.taut:
		return
	swung = _step_toward(centre, swung)
	if swung != centre:
		swung = _slide(body, grid, centre, swung)
		if swung == centre:
			g.taut = false               # nothing of the move fits: the stand-in for the re-resolve
			# AND THE WINCH GIVES ITS LINE BACK (D0578). `reel` shortens on every ANCHORED tick with up
			# held, before anything can know this refusal is coming. In a shaft the refusal is every
			# tick, so the line came in at 7 px a tick while the body stood still and the correction
			# owed grew until one tick had to move the body further than its own box -- which is exactly
			# the distance where `_slide`'s endpoint checks stop being sound. See `MAX_CORRECTION`.
			g.length = line_before
			return
	# THE ACCEPTED POSITION, not the requested one (A9). This was set from the pre-slide `swung`, so a
	# tick whose move was trimmed or refused still priced the landing from a place the body never
	# reached -- and the refusal path above returns with it already written.
	body.gait.fall_from_y = swung.y      # a fall the rope caught is over; the landing is not priced from above it
	body.pos_x = swung.x
	body.pos_y = swung.y
	body.swung_this_tick = true
	var v: Vector2i = g.resolve_velocity_fx(swung, body.vel_x, body.vel_y)
	v = g.pump_fx(swung, v.x, v.y)       # resolve just made v tangential; a shorter line carries it faster
	v = _winch_drive(g, swung, v)
	v = Vector2i(v.x - (v.x * SWING_DRAG_NUM) / SWING_DRAG_DEN, v.y - (v.y * SWING_DRAG_NUM) / SWING_DRAG_DEN)
	v = Fx.limit_length(v.x, v.y, SWING_MAX_SPEED)
	body.vel_x = v.x
	body.vel_y = v.y


## Above top speed the body is coasting rather than running (a released swing; a stride ceiling that just
## dropped), and the normal controller would throw that speed away inside a sixth of a second: speed you
## cannot keep is not a reward. Braking against it always wins; with it, or hands off, it bleeds toward the
## ceiling at the coast rate -- a skid on the ground, nearly free in the air (legacy 900 and 95 px/s^2: a
## full-speed release coasts about three seconds through open air and skids to a walk in a third on landing).
const GROUND_COAST_PER_TICK: int = (900 * Fx.SCALE) / Body.TICK_HZ
const AIR_COAST_PER_TICK: int = (95 * Fx.SCALE) / Body.TICK_HZ


static func coast(body: Body, input: InputFrame, top: int, decel: int) -> void:
	var travel: int = signi(body.vel_x)
	if input.move_dir * travel < 0:
		body.vel_x = travel * maxi(0, absi(body.vel_x) - decel)
		return
	var rate: int = GROUND_COAST_PER_TICK if body.on_floor else AIR_COAST_PER_TICK
	body.vel_x = travel * maxi(top, absi(body.vel_x) - rate)


## AS MUCH OF THE CONSTRAINED MOVE AS FITS (D0567). The full move first; failing that the VERTICAL
## component alone, then the horizontal. Each candidate is collision-checked against the same box
## predicate the axis resolvers use, so nothing here can put the body inside rock -- every candidate is a
## subset of a move the constraint already wanted.
##
## THIS IS THE TRAP'S FIX AND IT IS NOT THE PARKED RESOLVER RULING. The header above describes the yield
## this replaces: "a projected position whose box would overlap rock is refused... it differs at a corner,
## where legacy would slide the body along the face and this holds it." Held is what a player in a
## vertical shaft gets, on every tick, forever: the constrained position is always diagonally into the
## wall, so the reel was refused every tick and a driver with the source open rose zero metres in 515
## commands. Sliding along the face is legacy's own behaviour and strictly less refusal than before; the
## full two-axis re-resolve legacy does after the move is still parked and still the resolver's.
##
## VERTICAL IS TRIED FIRST, deliberately. Both orders fix the shaft, because the horizontal candidate is
## blocked there and falls through -- but the line exists to buy vertical space (`docs/GDD.md` §1), and
## when both axes are clear the one that gets you out of the hole is the one to spend the tick on.
## THE CORRECTION IS BOUNDED BY THE BODY'S OWN BOX, and that bound is the reason the endpoint checks in
## `_slide` are a correctness argument instead of an assumption (A9).
##
## `_slide` tests DESTINATIONS, never the swept path between them, and D0567's header claimed safety
## from "every candidate is a subset of a move the constraint already wanted". That is true of the
## candidate SET and says nothing about what the body passes through on the way. A helper probe accepts
## a move straight across an intervening floor when the far side is clear.
##
## Whether that is reachable is a question about DISTANCE, and it has an exact answer. The body's box is
## `WIDTH_PX` wide. Move it by `d` horizontally and the origin box spans `[x-8, x+8]`, the destination
## `[x+d-8, x+d+8]`: a solid can sit between them, touched by neither, only when `d > WIDTH_PX`. Under
## that, the two boxes overlap or touch and nothing can hide in the gap because there is no gap. So the
## bound is not a chosen number -- it is the body's own width, and `tests/test_grapple_body.gd` asserts
## the relation rather than the literal.
##
## A normal tick never reaches it: the overshoot is the body's speed (`SWING_MAX_SPEED`, 7 px a tick)
## plus the reel (7 px), about 14 against a bound of 16. What DID reach it was the ratchet -- see
## `Grapple.give_back`. Both halves are fixed, and this one is the backstop that holds even if some
## future path finds another way to owe a large correction: the body converges to the circle over
## several ticks instead of snapping to it in one.
const MAX_CORRECTION: int = Body.WIDTH_PX * Fx.SCALE


static func _step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var d: Vector2i = to - from
	var far: int = Fx.isqrt_ceil(Fx.length_sq(d.x, d.y))
	if far <= MAX_CORRECTION or far == 0:
		return to
	return from + Vector2i((d.x * MAX_CORRECTION) / far, (d.y * MAX_CORRECTION) / far)


static func _slide(body: Body, grid: TileGrid, from: Vector2i, to: Vector2i) -> Vector2i:
	if not _blocked_at(body, grid, to):
		return to
	if to.y != from.y and not _blocked_at(body, grid, Vector2i(from.x, to.y)):
		return Vector2i(from.x, to.y)
	if to.x != from.x and not _blocked_at(body, grid, Vector2i(to.x, from.y)):
		return Vector2i(to.x, from.y)
	return from


static func _blocked_at(body: Body, grid: TileGrid, at: Vector2i) -> bool:
	var hw: int = (Body.WIDTH_PX * Fx.SCALE) / 2
	var hh: int = (Body.HEIGHT_PX * Fx.SCALE) / 2
	return body._box_blocked(grid, at.x - hw, at.y - hh, at.x + hw, at.y + hh)


## Taking line in at the reel rate means the body approaches the hitch at that rate, so the inward radial
## component is SET to the haul rate: never added (that compounds every tick) and never applied to the
## tangential part (the swing). A body already closing faster than the winch keeps its own speed. Legacy
## measured from the anchor; a wrapped line pulls from its hitch, so this measures from there.
static func _winch_drive(g: Grapple, pos: Vector2i, v: Vector2i) -> Vector2i:
	if g.hauled <= 0:
		return v
	var d: Vector2i = pos - g.hitch_fx()
	var dist: int = Fx.isqrt_ceil(Fx.length_sq(d.x, d.y))
	if dist == 0:
		return v
	var radial: int = (v.x * d.x + v.y * d.y) / dist   # negative = already closing on the hitch
	var want: int = -g.hauled * Body.TICK_HZ           # ...and this is how fast the line says we close
	if want >= radial:
		return v
	var delta: int = want - radial
	return Vector2i(v.x + (d.x * delta) / dist, v.y + (d.y * delta) / dist)
