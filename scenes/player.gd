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


## One physics step: horizontal then vertical, each integrated and then collided against the grid.
func _step(delta: float) -> void:
	velocity.x = input_dir * RUN_SPEED
	if input_dir != 0.0:
		facing = int(signf(input_dir))

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	if _jump_request and (on_floor or _coyote > 0.0):
		velocity.y = JUMP_VELOCITY
		on_floor = false
		_coyote = 0.0
	_jump_request = false

	var grounded: bool = on_floor or _coyote > 0.0
	position.x += velocity.x * delta
	_resolve_axis(true)
	if grounded and input_dir != 0.0 and is_equal_approx(velocity.x, 0.0):
		_try_step_up()  # walking into a 1-tile rise (a hill/slope) → climb it smoothly, don't stop

	position.y += velocity.y * delta
	on_floor = false
	_resolve_axis(false)

	_coyote = COYOTE_TIME if on_floor else _coyote - delta


## Auto-climb a SINGLE-tile step in the walk direction (so gentle hills/slopes are smooth to walk,
## not a staircase you must jump). Only fires when grounded and blocked by a rise that is exactly one
## tile tall with clear headroom above — a taller rise stays a wall you must jump.
func _try_step_up() -> void:
	var dir: float = signf(input_dir)
	var rect: Rect2 = _aabb()
	var foot_y: float = rect.end.y - 2.0
	var ahead_x: float = (rect.end.x + 2.0) if dir > 0.0 else (rect.position.x - 2.0)
	var step_cell: Vector2i = _cell_of(Vector2(ahead_x, foot_y))
	if not sim.is_solid(step_cell):
		return
	var stand_cell: Vector2i = step_cell + Vector2i(0, -1)  # the body rises into this cell
	if _blocked(stand_cell):
		return  # rise is taller than one tile → a real wall, don't auto-climb
	position.y = float(step_cell.y * CELL) - HEIGHT * 0.5 - 1.0  # feet just ABOVE the step top
	position.x += dir * 4.0                                      # nudge forward over the edge
	velocity.y = 0.0
	_resolve_axis(true)                                         # re-resolve x at the new height


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

	# Dark silhouette backing (1px halo) so the body pops against terrain/back-wall.
	draw_rect(Rect2(-WIDTH * 0.5 - 1.0, -HEIGHT * 0.5 - 1.0, WIDTH + 2.0, HEIGHT + 2.0),
		Color(0.04, 0.04, 0.06))

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
