extends SceneTree

## Harness layer 5 — motion check for AUTO-STEP (pulled by the sloped-terrain presentation slice).
## Drives the real Player walking into a single-tile step and asserts the body CLIMBS it and keeps
## moving (so gentle hills are smooth to walk, not a staircase you get stuck on). Also asserts a
## TWO-tile wall is NOT auto-climbed (it stays a wall you must jump). Run HEADED:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_stepup.gd

const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _player: Player
var _frames: int = 0
var _phase: int = 0
var _t: float = 0.0
var _x0: float = 0.0
var _y0: float = 0.0
var _prev_y: float = 0.0
var _max_rise: float = 0.0  ## largest single-frame UPWARD jump during the climb (teleport detector)
var _failures: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== step-up check ==")
	physics_frame.connect(_phys)


## Carve an open gallery, lay a base floor (row 12), raise the surface by ONE tile at col 7 (a step
## to climb), and put a genuine TWO-tile wall at col 15 (two tiles above that raised surface, so it
## must NOT auto-climb). One rightward walk exercises both.
func _build() -> void:
	var sim: FactorySim = _main.sim
	for x: int in range(2, 21):
		for y: int in range(2, 16):
			sim.set_solid(Vector2i(x, y), &"")
		sim.set_solid(Vector2i(x, 12), &"earth")        # base floor (cols 2..20)
	for x: int in range(7, 21):
		sim.set_solid(Vector2i(x, 11), &"earth")        # raise the surface a tile from col 7 (the step)
	sim.set_solid(Vector2i(15, 10), &"earth")           # a true 2-tile wall on the raised surface
	sim.set_solid(Vector2i(15, 9), &"earth")
	_player.position = _main._cell_center(Vector2i(3, 11))
	_player.velocity = Vector2.ZERO


func _phys() -> void:
	_frames += 1
	if _frames > 1500:
		printerr("  TIMEOUT"); quit(1); return
	if _frames < 5:
		return
	if _player == null:
		_player = _main._player
		_player.auto_input = false
		_build()
		return

	match _phase:
		0:  # settle on the floor
			_player.input_dir = 0.0
			if _player.on_floor:
				_y0 = _player.position.y
				_x0 = _player.position.x
				_prev_y = _player.position.y
				_phase = 1; _t = 0.0
		1:  # one long walk right: GLIDE up the 1-tile ramp, then get STOPPED by the 2-tile wall
			_player.input_dir = 1.0
			_max_rise = maxf(_max_rise, _prev_y - _player.position.y)  # track biggest 1-frame lift
			_prev_y = _player.position.y
			_t += 1.0 / 60.0
			if _t >= 3.0:
				var climbed: bool = _player.position.y < _y0 - 16.0
				var passed_step: bool = _player.position.x > float(8 * 32)
				var stopped_at_wall: bool = _player.position.x < float(15 * 32)
				_check(climbed and passed_step,
					"climbed the 1-tile step and walked on (dy=%.0f, x=%.0f)"
					% [_player.position.y - _y0, _player.position.x])
				# The climb must be a smooth GLIDE, not a teleport: at 150px/s on a 45° ramp the body
				# rises ~2.5px/frame; a one-frame snap would be ~32px. Guard well below a tile.
				_check(_max_rise < 8.0,
					"glided up the ramp (max single-frame rise %.1fpx — a teleport would be ~32)" % _max_rise)
				_check(stopped_at_wall,
					"the 2-tile wall stopped the body (x=%.0f, wall at %d)" % [_player.position.x, 15 * 32])
				_phase = 2; _t = 0.0
		2:  # a 2-tile wall must be JUMPABLE (walking never auto-climbs it, but a jump clears it — the
			# live-play "stalling on a 2-high jump" fix: apex ~74px > 64px). Keep walking + jump.
			_player.input_dir = 1.0
			_t += 1.0 / 60.0
			if fmod(_t, 0.6) < 1.0 / 60.0:
				_player.request_jump()
			if _player.position.x > float(16 * 32) and _player.on_floor:
				_check(true, "jumped the 2-tile wall and landed on top (x=%.0f)" % _player.position.x)
				_player.input_dir = 0.0
				_phase = 3
			elif _t >= 4.0:
				_check(false, "could not jump the 2-tile wall (x=%.0f)" % _player.position.x)
				_phase = 3
		3:
			if _failures == 0:
				print("STEP-UP OK"); quit(0)
			else:
				printerr("%d STEP-UP CHECK(S) FAILED" % _failures); quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)
