extends SceneTree

## Harness layer 5 — motion check for the ROPE CLIMB (the placeable climb, Sprint B). Builds a deep
## 1-wide pit with a rope hung down it, drops the body to the bottom, and asserts the three feel
## contracts: (1) holding UP rides the body smoothly to the top (no jumping, no teleport frames);
## (2) releasing mid-climb HANGS (no fall); (3) at the lip, walking sideways exits the shaft onto
## the surface. Run HEADED:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_climb.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = 32
const PIT_COL: int = 6
const PIT_TOP: int = 8          ## the surface row of the fixture
const PIT_FLOOR: int = 17       ## solid floor row (pit depth = 9 tiles — far past jump height)

var _main: MainView
var _player: Player
var _frames: int = 0
var _phase: int = 0
var _t: float = 0.0
var _y_prev: float = 0.0
var _hang_y: float = 0.0
var _max_jump: float = 0.0      ## biggest single-frame rise while climbing (teleport tripwire)
var _hold_y: float = 0.0        ## position when the top-of-rope hold watch began
var _hold_frames: int = 0
var _hold_drift: float = 0.0    ## how far the body wandered while holding UP at the rope top
var _failures: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== rope climb check ==")
	physics_frame.connect(_phys)


## A flat platform around a 1-wide pit 9 tiles deep (unjumpable), with a rope anchored at the mouth
## unrolled to the floor — the exact "dug straight down" rescue the rope exists for.
func _build() -> void:
	var sim: FactorySim = _main.sim
	for x: int in range(PIT_COL - 4, PIT_COL + 5):
		for y: int in range(0, PIT_TOP):
			sim.set_solid(Vector2i(x, y), &"")             # open air above the platform
		for y: int in range(PIT_TOP, PIT_FLOOR + 2):
			sim.set_solid(Vector2i(x, y), &"earth")        # the ground slab
	for y: int in range(PIT_TOP, PIT_FLOOR):
		sim.set_solid(Vector2i(PIT_COL, y), &"")           # the 1-wide pit shaft
	sim.inventory[&"rope"] = 20
	sim.total_produced[&"rope"] = 20
	var hung: int = sim.place_rope(Vector2i(PIT_COL, PIT_TOP - 1))  # anchor one above the lip
	_check(hung == PIT_FLOOR - PIT_TOP + 1, "the rope unrolled the full shaft (%d segments)" % hung)
	_player.position = _main._cell_center(Vector2i(PIT_COL, PIT_FLOOR - 1)) - Vector2(0, 6)
	_player.velocity = Vector2.ZERO


func _phys() -> void:
	_frames += 1
	if _frames > 2000:
		printerr("  TIMEOUT (phase %d)" % _phase); quit(1); return
	if _frames < 5:
		return
	if _player == null:
		_player = _main._player
		_player.auto_input = false
		_build()
		return

	match _phase:
		0:                                                   # settle onto the pit floor
			_t += 1.0 / 60.0
			if _t >= 0.5:
				_check(_player.on_floor, "body settled at the pit bottom")
				_y_prev = _player.position.y
				_phase = 1; _t = 0.0
		1:                                                   # CLIMB: hold UP, ride to mid-shaft
			_player.input_climb = 1.0
			_t += 1.0 / 60.0
			_max_jump = maxf(_max_jump, _y_prev - _player.position.y)
			_y_prev = _player.position.y
			if _t >= 1.5:
				var mid_row: int = int(_player.position.y) / CELL
				_check(mid_row <= PIT_FLOOR - 4, "holding UP rides the rope upward (row %d)" % mid_row)
				_check(_max_jump <= 4.0, "the climb is a glide, never a teleport (max frame rise %.1fpx)" % _max_jump)
				_phase = 2; _t = 0.0
		2:                                                   # HANG: release mid-climb, must not fall
			_player.input_climb = 0.0
			if _t == 0.0:
				_hang_y = _player.position.y
			_t += 1.0 / 60.0
			if _t >= 0.8:
				_check(absf(_player.position.y - _hang_y) < 3.0,
					"releasing mid-rope HANGS in place (drift %.1fpx)" % absf(_player.position.y - _hang_y))
				_phase = 3; _t = 0.0
		3:                                                   # TOP HOLD: keep pressing UP at the rope's end —
			_player.input_climb = 1.0                         # the grip must HOLD, never un-grip/fall/jitter
			_t += 1.0 / 60.0                                  # (the live-play "stalling at the anchor" bug)
			var row: int = int(_player.position.y) / CELL
			if row <= PIT_TOP - 1:
				_hold_frames += 1
				if _hold_frames == 20:
					_hold_y = _player.position.y              # settled at the top — start the drift watch
				elif _hold_frames > 20:
					_hold_drift = maxf(_hold_drift, absf(_player.position.y - _hold_y))
				if _hold_frames >= 65:
					_check(_hold_drift < 3.0,
						"holding UP at the rope top HOLDS steady — no un-grip jitter (drift %.1fpx)" % _hold_drift)
					_phase = 4; _t = 0.0
			if _t >= 4.0:
				_check(false, "never reached the rope top (stuck at row %d)" % row)
				_phase = 5
		4:                                                   # EXIT: walk off sideways at the lip
			_t += 1.0 / 60.0
			var c: Vector2i = _main._cell_at(_player.position)
			if c.x != PIT_COL and _player.on_floor:
				_player.input_dir = 0.0                       # landed off the rope — check WHERE, then stop
				_player.input_climb = 0.0
				_check(c.y == PIT_TOP - 1,
					"walked off the rope onto the surface (at %s)" % c)
				_phase = 5
				return
			_player.input_climb = 0.0
			_player.input_dir = 1.0
			if _t >= 4.0:
				_check(false, "never exited the shaft at the lip (stuck at %s)" % c)
				_phase = 5
		5:
			if _failures == 0:
				print("CLIMB OK"); quit(0)
			else:
				printerr("%d CLIMB CHECK(S) FAILED" % _failures); quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)
