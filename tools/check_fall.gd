extends SceneTree

## Guards the "mine the floor from under yourself" bug (user report): standing on a block and breaking the
## block beneath your feet must make you FALL under gravity — a gradual drop — NOT teleport instantly onto
## the next surface below. The old floor-SNAP grabbed the next floor within a tile and yanked the body down;
## the fix only lets a full-tile snap fire while MOVING, so a stationary body whose floor vanished falls.
##   HEADED:  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_fall.gd

const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _sim: FactorySim
var _player: Player
var _frames: int = 0
var _fails: int = 0
var _phase: int = 0
var _stand := Vector2i(-1, -1)
var _y_at_mine: float = 0.0
var _first_step_dy: float = -1.0
var _budget: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== fall when the floor is mined (no teleport) ==")
	physics_frame.connect(_phys)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_fails += 1
		printerr("  FAIL: %s" % label)


func _phys() -> void:
	_frames += 1
	if _frames < 20:
		return
	if _player == null:
		_player = _main._player
		_sim = _main.sim
	match _phase:
		0:
			# Build a clean stack: a block to stand on (row R), open air below it, a catch floor 3 tiles down.
			var col: int = MainView.SPAWN_COL
			var r: int = MainView.SURFACE
			for dy: int in range(-2, 6):
				_sim.set_solid(Vector2i(col, r + dy), &"")     # clear a shaft around the test
			_sim.set_solid(Vector2i(col, r), &"stone")         # the block the body stands ON
			_sim.set_solid(Vector2i(col, r + 4), &"stone")     # catch floor, 3 open tiles below the stand block
			_stand = Vector2i(col, r)
			_player.position = _main._cell_center(Vector2i(col, r - 1))
			_player.velocity = Vector2.ZERO
			_phase = 1
			_budget = 0
		1:
			# Let the body settle standing on the block.
			_budget += 1
			if _player.on_floor and absf(_player.velocity.x) < 1.0:
				_check(_player.on_floor, "body is standing on the block")
				_y_at_mine = _player.position.y
				_sim.mine(_stand)                              # break the block beneath the feet
				_phase = 2
				_budget = 0
			elif _budget > 120:
				_check(false, "body never settled on the stand block")
				_finish()
		2:
			# The VERY NEXT frame after mining: the body must NOT have jumped a full tile (that'd be a teleport).
			_first_step_dy = _player.position.y - _y_at_mine
			_check(_first_step_dy < 12.0,
				"did NOT teleport down on the mine frame (moved %.1fpx, a full tile is 32)" % _first_step_dy)
			_phase = 3
			_budget = 0
		3:
			# Over the next frames it should FALL and land on the catch floor 3 tiles down (a real gravity drop).
			_budget += 1
			if _player.on_floor and _player.position.y > _y_at_mine + 40.0:
				_check(true, "fell under gravity and landed on the floor below (dropped %.0fpx)"
					% (_player.position.y - _y_at_mine))
				_finish()
			elif _budget > 180:
				_check(false, "never fell/landed after the floor was mined (dropped %.0fpx)"
					% (_player.position.y - _y_at_mine))
				_finish()


func _finish() -> void:
	if _fails == 0:
		print("ALL FALL CHECKS PASS")
		quit(0)
	else:
		printerr("%d FALL FAILURE(S)" % _fails)
		quit(1)
