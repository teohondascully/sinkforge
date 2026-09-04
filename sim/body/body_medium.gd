class_name BodyMedium
extends RefCounted

## The medium the body moves through (A' step 5c, D0360): legacy `player.gd`'s water wading (:259 and
## its five multipliers), rope grip and climb (:302-306, :337-343) and lift updraft (:330), as a static
## pass over `Body` reading `body.surroundings`. Every answer here changes a velocity or a flag the tick
## then integrates as usual; nothing here is representation.

## Water impedance, the located hazard the Pump later relieves. With the body's box over a water cell it
## wades: top speed and accel are damped, gravity is buoyantly slowed to a near-neutral sink under a
## terminal cap, the jump is weaker. Friction rather than drowning: every multiplier keeps the body
## movable. Legacy 0.55, 0.6, 0.45, 0.7 and 220 px/s.
const WATER_SPEED_NUM: int = 11
const WATER_SPEED_DEN: int = 20
const WATER_ACCEL_NUM: int = 3
const WATER_ACCEL_DEN: int = 5
const WATER_GRAVITY_NUM: int = 9
const WATER_GRAVITY_DEN: int = 20
const WATER_JUMP_NUM: int = 7
const WATER_JUMP_DEN: int = 10
const WATER_MAX_SINK: int = 220 * Fx.SCALE
const WATER_MIN_LEVEL: int = 1                ## any water impedes
const LIFT_RISE_SPEED: int = 120 * Fx.SCALE   ## the updraft carries the body up at least this fast
const CLIMB_SPEED: int = 110 * Fx.SCALE       ## the body travels a gripped rope at this; release = hang
## Top of rope: with no rope above, rising further pushes the centre off the rope, which un-grips, falls
## and re-grips, jittering at the anchor. The rise is clamped so the centre holds this far below the top
## cell's upper edge.
const ROPE_TOP_HOLD_PX: int = 6


## Is any terrain cell under the body's box wet?
static func wet(body: Body) -> bool:
	var lo := Vector2i(Body._px_to_cell(body._left_x()), Body._px_to_cell(body._top_y()))
	var hi := Vector2i(Body._px_to_cell(body._right_x() - 1), Body._px_to_cell(body._bottom_y() - 1))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			if body.surroundings.water_at(Vector2i(cx, cy)) >= WATER_MIN_LEVEL:
				return true
	return false


## The logic cell the body's centre is in.
static func logic_cell(body: Body) -> Vector2i:
	var c: int = Body.LOGIC_TILE_PX * Fx.SCALE
	return Vector2i(_floor_div(body.pos_x, c), _floor_div(body.pos_y, c))


static func _floor_div(a: int, b: int) -> int:
	return (a - (b - 1 if a < 0 else 0)) / b


## Rope grip: overlapping a placed rope, a climb press grabs it and holds until the body leaves or jumps
## off. Before the vertical pass, so the pass sees the grip; gripping counts as grounded for the jump.
static func grip(body: Body, input: InputFrame) -> void:
	if not body.surroundings.is_climbable(logic_cell(body)):
		body.climbing = false
	elif input.climb_dir != 0:
		body.climbing = true


## After gravity: the updraft ensures at least the rise speed upward (a jump can still beat it); the climb
## replaces gravity with direct travel and runs after the updraft so a gripped rope wins over a draft. The
## vertical resolve still applies: climbing into a ceiling stops the body, climbing onto a floor lands it.
static func vertical(body: Body, input: InputFrame) -> void:
	var cell: Vector2i = logic_cell(body)
	if body.surroundings.updraft_at(cell):
		body.vel_y = mini(body.vel_y, -LIFT_RISE_SPEED)
	if not body.climbing:
		return
	body.vel_y = -input.climb_dir * CLIMB_SPEED
	if input.climb_dir > 0 and not body.surroundings.is_climbable(cell + Vector2i(0, -1)):
		var top_hold: int = cell.y * Body.LOGIC_TILE_PX * Fx.SCALE + ROPE_TOP_HOLD_PX * Fx.SCALE
		body.vel_y = clampi((top_hold - body.pos_y) * Body.TICK_HZ, body.vel_y, 0)
