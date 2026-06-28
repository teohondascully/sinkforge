extends SceneTree

## Harness layer 5 (gray-area observability) — MEASURE the body's motion vs intent, so "movement
## works but feels wrong" cannot silently happen: either the number is off (asserted here) or the
## motion looks off (the capture/motion-strip). It drives the real Player controller (auto_input
## off) on flat ground and measures run speed + jump apex against the controller's own constants.
## Run HEADED (needs the physics loop):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/measure_player.gd
## Exits 0 if both within tolerance, non-zero otherwise.

const SCENE: String = "res://scenes/main.tscn"
const RUN_TOL: float = 0.06
const JUMP_TOL: float = 0.15

var _main: MainView
var _player: Player
var _frames: int = 0
var _phase: int = 0
var _t: float = 0.0
var _x0: float = 0.0
var _floor_y: float = 0.0
var _apex: float = 0.0
var _failures: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	var packed: PackedScene = load(SCENE)
	_main = packed.instantiate()
	get_root().add_child(_main)
	print("== player motion metrics ==")
	physics_frame.connect(_phys)


func _phys() -> void:
	_frames += 1
	if _frames > 1200:
		printerr("  TIMEOUT before metrics completed"); quit(1); return
	if _frames < 5:
		return
	if _player == null:
		_player = _main._player
		_player.auto_input = false
		_player.position = _main._cell_center(Vector2i(3, 3))  # on the open surface: clear sky above, earth below
		_player.velocity = Vector2.ZERO
		return

	var dt: float = 1.0 / 60.0
	match _phase:
		0:  # settle onto the floor, then jump from the clear spawn column (before any running)
			_player.input_dir = 0.0
			if _player.on_floor:
				_floor_y = _player.position.y
				_apex = _player.position.y
				_player.request_jump()
				_phase = 1; _t = 0.0
		1:  # track apex until landing
			_t += dt
			_apex = minf(_apex, _player.position.y)
			if _player.on_floor and _t > 0.25:
				var height: float = _floor_y - _apex
				var intended: float = Player.JUMP_VELOCITY * Player.JUMP_VELOCITY / (2.0 * Player.GRAVITY)
				_report("jump apex px", height, intended, JUMP_TOL)
				_phase = 2; _t = 0.0; _x0 = _player.position.x
		2:  # run left ~0.5s (open ground, away from the chute) and measure horizontal speed
			_player.input_dir = -1.0
			_t += dt
			if _t >= 0.5:
				var speed: float = absf(_player.position.x - _x0) / _t
				_report("run speed px/s", speed, Player.RUN_SPEED, RUN_TOL)
				_player.input_dir = 0.0
				_phase = 3
		3:
			if _failures == 0:
				print("ALL WITHIN TOLERANCE"); quit(0)
			else:
				printerr("%d METRIC(S) OUT OF TOLERANCE" % _failures); quit(1)


func _report(label: String, measured: float, intended: float, tol: float) -> void:
	var ok: bool = absf(measured - intended) <= absf(intended) * tol
	var line: String = "  %s: measured %.1f, intended %.1f (±%d%%)  %s" % [
		label, measured, intended, int(tol * 100.0), "OK" if ok else "OUT"]
	if ok:
		print(line)
	else:
		_failures += 1
		printerr(line)
