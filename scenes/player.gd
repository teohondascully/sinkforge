class_name Player
extends Node2D

## The embodied avatar — P2·S1a. PURELY a representation-layer entity: it reads the sim's world
## (is_solid / machine_at) for collision but NEVER enters the deterministic tick and never writes
## production state. Delete it and the factory numbers are identical. Movement is a small custom
## platformer controller with per-axis move-then-resolve AABB collision against the sim's solid
## cells, the machines, and the world walls/floor (safe from tunnelling at these speeds vs 32px
## cells; would need substep clamping only under severe frame drops) — plain GDScript so the feel is
## fully ours to
## tune (custom-now, not TileMap; see docs/DECISIONS.md / prompts/prototype-2.md).
##
## DESIGN-OPEN: every number here (speed, gravity, jump, size) is placeholder feel, measured vs
## intended by the harness (tools/measure_player.gd) and tuned by taste — see docs/HARNESS.md.

const CELL: int = 32
## Body AABB (smaller than a cell so it fits through 1-wide dug tunnels later).
const WIDTH: float = 18.0
const HEIGHT: float = 26.0

## --- feel constants (placeholder; harness measures these vs intent) ---
const RUN_SPEED: float = 150.0       ## px/s horizontal
const GRAVITY: float = 900.0         ## px/s^2
const JUMP_VELOCITY: float = -330.0  ## px/s instantaneous on jump  (apex ~= 330^2/(2*900) ~= 60px)
const MAX_FALL: float = 560.0        ## px/s terminal
const COYOTE_TIME: float = 0.08      ## s of grace to still jump after leaving an edge
const LIFT_RISE_SPEED: float = 120.0 ## px/s the updraft carries the body UP (the paid inverse of gravity)
## Slope follow: a single-tile rise is walked as a 45° ramp (glide, not teleport); a taller rise is a
## wall you must jump. A single-tile drop is glided down too; a bigger gap is a real fall.
const MAX_STEP: float = CELL * 1.3
const MAX_DROP: float = CELL * 1.3

var sim: FactorySim                  ## set by MainView; read-only use (collision queries)
## When true (normal play) the controller samples the keyboard. The harness sets it false and
## drives input_dir / request_jump() directly to measure motion deterministically.
var auto_input: bool = true
var input_dir: float = 0.0           ## -1 left, +1 right
var velocity: Vector2 = Vector2.ZERO
var on_floor: bool = false
var facing: int = 1

var _jump_request: bool = false
var _coyote: float = 0.0


func _physics_process(delta: float) -> void:
	if auto_input:
		input_dir = 0.0
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			input_dir += 1.0
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
			input_dir -= 1.0
	_step(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not auto_input:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_UP, KEY_W]:
			request_jump()


func request_jump() -> void:
	_jump_request = true


## One physics step: horizontal (with slope follow) then vertical, each integrated and collided.
func _step(delta: float) -> void:
	velocity.x = input_dir * RUN_SPEED
	if input_dir != 0.0:
		facing = int(signf(input_dir))

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	var grounded: bool = on_floor or _coyote > 0.0
	if _jump_request and grounded:
		velocity.y = JUMP_VELOCITY
		on_floor = false
		_coyote = 0.0
		grounded = false
	_jump_request = false

	# Updraft: standing in a lift's open shaft, the body is carried UP (the rideable half of the lift).
	# Ensures at least rise speed upward — a jump can still beat it — and skips slope-follow (airborne).
	if sim.updraft_at(_cell_of(position)):
		velocity.y = minf(velocity.y, -LIFT_RISE_SPEED)
		grounded = false

	# Horizontal move, THEN follow the ground slope (lift/lower y in lockstep with x) BEFORE the
	# horizontal collision resolve — so a single-tile rise is glided up as a 45° ramp rather than
	# blocking x and teleporting. A taller rise isn't followed, so the resolve blocks it as a wall.
	position.x += velocity.x * delta
	var on_ramp: bool = false
	if grounded and velocity.y >= 0.0:
		on_ramp = _follow_slope()
	_resolve_axis(true)

	# On a ramp the feet ride a virtual hypotenuse ABOVE the real solid square, so the square resolve
	# can't see the floor — _follow_slope grounds the body itself. Otherwise integrate gravity normally.
	if on_ramp:
		velocity.y = 0.0
		on_floor = true
	else:
		position.y += velocity.y * delta
		on_floor = false
		_resolve_axis(false)

	_coyote = COYOTE_TIME if on_floor else _coyote - delta


## Track the walkable surface as a 45° height field so the body GLIDES along ramps instead of
## popping. Samples the surface under the body centre and its leading edge, snaps the feet onto the
## higher of the two — but only within one tile of rise (taller = a wall, left for the resolve to
## block) or drop (bigger = a real fall, left for gravity). Climbs are rejected if the new position
## would push the head into a ceiling (a tight gap is a wall, not a step).
func _follow_slope() -> bool:
	var rect: Rect2 = _aabb()
	# The box rests on the HIGHEST ground under its footprint — sample both bottom corners + centre.
	var target: float = minf(_surface_y(rect.position.x + 1.0),
			_surface_y(rect.end.x - 1.0))
	target = minf(target, _surface_y(position.x))
	var lift: float = rect.end.y - target  # feet_y - surface_y: >0 climb up, <0 step down
	if lift > MAX_STEP or lift < -MAX_DROP:
		return false  # rise too tall (a wall) or drop too deep (a real fall) → not on this surface
	var ny: float = target - HEIGHT * 0.5
	if lift > 0.5:
		var top_y: float = ny - HEIGHT * 0.5 + 1.0  # don't climb into a ceiling (a tight gap is a wall)
		if _blocked(_cell_of(Vector2(rect.position.x + 1.0, top_y))) \
				or _blocked(_cell_of(Vector2(rect.end.x - 1.0, top_y))):
			return false
	position.y = ny
	return true


## World-Y of the walkable surface at a horizontal position — read straight from the sim's shared
## silhouette authority (sim.surface_row / sim.ramp_dir), the SAME source the renderer draws from, so
## the hypotenuse we glide is exactly the diagonal on screen. A single-tile step is a 45° ramp across
## its own column; flat otherwise. Terrain-only by construction: machines aren't in the silhouette, so
## a placed machine is a box the square-resolve bumps/climbs — never a phantom invisible ramp.
func _surface_y(world_x: float) -> float:
	var c: int = floori(world_x / float(CELL))
	var frac: float = world_x / float(CELL) - float(c)  # 0..1 across column c
	var base: float = float(sim.surface_row(c) * CELL)
	match sim.ramp_dir(c):
		1:
			return base - frac * float(CELL)          # one tile higher to the RIGHT → ramp up rightward
		-1:
			return base - (1.0 - frac) * float(CELL)  # one tile higher to the LEFT → ramp up leftward
		_:
			return base                               # flat top (or peak/valley): no ramp


## Push the body out of any blocked cell it now overlaps, along the axis it just moved.
func _resolve_axis(horizontal: bool) -> void:
	var rect: Rect2 = _aabb()
	var lo: Vector2i = _cell_of(rect.position)
	var hi: Vector2i = _cell_of(rect.end - Vector2(0.001, 0.001))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			var cell := Vector2i(cx, cy)
			if not _blocked(cell):
				continue
			var cell_rect := Rect2(float(cx * CELL), float(cy * CELL), float(CELL), float(CELL))
			if not rect.intersects(cell_rect):
				continue
			if horizontal:
				if velocity.x > 0.0:
					position.x = cell_rect.position.x - WIDTH * 0.5
				elif velocity.x < 0.0:
					position.x = cell_rect.end.x + WIDTH * 0.5
				velocity.x = 0.0
			else:
				if velocity.y > 0.0:
					position.y = cell_rect.position.y - HEIGHT * 0.5
					on_floor = true
				elif velocity.y < 0.0:
					position.y = cell_rect.end.y + HEIGHT * 0.5
				velocity.y = 0.0
			rect = _aabb()


## A cell blocks the body if it's solid earth, holds a machine (you stand on machines), or is a
## world boundary (side walls + floor). Open sky above the world is not blocked.
func _blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= FactorySim.GRID_COLS:
		return true
	if cell.y >= FactorySim.GRID_ROWS:
		return true
	if cell.y < 0:
		return false
	return sim.is_solid(cell) or sim.machine_at(cell) != null


func _aabb() -> Rect2:
	return Rect2(position.x - WIDTH * 0.5, position.y - HEIGHT * 0.5, WIDTH, HEIGHT)


func _cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(CELL)), floori(world_pos.y / float(CELL)))


## A little MINER (art still an open question, but a person — not a slab): boots + legs, blue
## overalls, skin head, and a yellow hardhat with a head-lamp that points the way you face. Drawn
## small (the body is ~9px on screen at this zoom), so it's built from bold blocks that read as a
## silhouette rather than fine detail. A dark backing gives it contrast against earth and walls.
func _draw() -> void:
	var f: float = float(facing)
	var overalls := Color(0.24, 0.40, 0.62)
	var legs := Color(0.18, 0.20, 0.28)
	var skin := Color(0.84, 0.66, 0.50)
	var helmet := Color(0.95, 0.78, 0.22)

	# (No hard silhouette plate: the head-lamp pool now provides the contrast — a backing rect read as
	# a hard box fighting the soft lighting. A subtle 1px dark outline keeps edges crisp without a plate.)
	var outline := Color(0.03, 0.03, 0.05, 0.5)
	draw_rect(Rect2(-WIDTH * 0.5 - 1.0, -HEIGHT * 0.5 - 1.0, WIDTH + 2.0, HEIGHT + 2.0), outline, false, 1.0)

	# Legs + boots.
	draw_rect(Rect2(-5.0, 5.0, 4.0, 8.0), legs)
	draw_rect(Rect2(1.0, 5.0, 4.0, 8.0), legs)
	draw_rect(Rect2(-5.0, 11.0, 4.5, 2.0), Color(0.10, 0.11, 0.14))  # boot
	draw_rect(Rect2(0.5, 11.0, 4.5, 2.0), Color(0.10, 0.11, 0.14))

	# Torso (overalls) with a strap highlight.
	draw_rect(Rect2(-6.0, -5.0, 12.0, 11.0), overalls)
	draw_rect(Rect2(-1.0, -5.0, 2.0, 11.0), overalls.lightened(0.12))

	# Head.
	var head := Vector2(f * 0.5, -9.0)
	draw_circle(head, 4.2, skin)
	# Hardhat: a cap over the top of the head + a brim toward the facing side.
	draw_rect(Rect2(head.x - 4.6, head.y - 5.0, 9.2, 4.2), helmet)
	draw_rect(Rect2(head.x + (1.0 if f > 0.0 else -5.5), head.y - 1.4, 4.5, 1.6), helmet)
	# Head-lamp glow on the facing side.
	draw_circle(head + Vector2(f * 4.2, -2.2), 1.5, Color(1.0, 0.97, 0.7))
