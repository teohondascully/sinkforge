extends "res://tools/check_base.gd"

## Guards the "mine the floor from under yourself" bug (user report): standing on a block and breaking the
## block beneath your feet must make you FALL under gravity — NOT teleport instantly onto the next surface,
## and NOT creep down mushily from zero velocity (the "laggy/glitchy" fall that followed). Beyond
## the no-teleport correctness, this asserts the fall FEEL: the drop starts PROMPTLY (a couple frames, not a
## visible hang) and descends SMOOTHLY (monotone, no upward stutter, no single-frame tile jump).
##   HEADED:  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_fall.gd

const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _sim: FactorySim
var _player: Player
var _frames: int = 0
var _phase: int = 0
var _stand := Vector2i(-1, -1)
var _y_at_mine: float = 0.0
var _first_step_dy: float = -1.0
var _budget: int = 0
var _prev_y: float = 0.0
var _frames_since_mine: int = 0
var _drop_by_frame5: float = -1.0
var _max_upward_stutter: float = 0.0
var _max_frame_jump: float = 0.0
var _fall_frames: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== fall when the floor is mined (no teleport) ==")
	physics_frame.connect(_phys)

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
			_player.place(_main._cell_center(Vector2i(col, r - 1)))
			_player.velocity = Vector2.ZERO
			_phase = 1
			_budget = 0
		1:
			# Let the body settle standing on the block.
			_budget += 1
			if _player.on_floor and absf(_player.velocity.x) < 1.0:
				_check(_player.on_floor, "body is standing on the block")
				_y_at_mine = _player.position.y
				_prev_y = _player.position.y
				_frames_since_mine = 0
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
			# Over the next frames it FALLS and lands on the catch floor 3 tiles down, while we sample the FEEL:
			# prompt onset (drop by frame 5), smooth descent (no upward stutter, no single-frame tile jump).
			_budget += 1
			_frames_since_mine += 1
			var dy: float = _player.position.y - _prev_y
			if not _player.on_floor:
				_fall_frames += 1
				_max_frame_jump = maxf(_max_frame_jump, dy)          # biggest single-frame drop (teleport guard)
				_max_upward_stutter = maxf(_max_upward_stutter, -dy) # any UPWARD jerk mid-fall (glitch guard)
			if _frames_since_mine == 5:
				_drop_by_frame5 = _player.position.y - _y_at_mine
			_prev_y = _player.position.y
			if _player.on_floor and _player.position.y > _y_at_mine + 40.0:
				_check(true, "fell under gravity and landed on the floor below (dropped %.0fpx)"
					% (_player.position.y - _y_at_mine))
				# FEEL: onset is prompt — a zero-velocity creep drops only ~4px in 5 frames; the fall-kick clears 8.
				_check(_drop_by_frame5 >= 8.0,
					"fall STARTS promptly — dropped %.1fpx within 5 frames (no laggy creep)" % _drop_by_frame5)
				# FEEL: smooth — the body never jerks UPWARD mid-fall (a stutter/glitch would show a negative dy).
				_check(_max_upward_stutter < 1.0,
					"fall is smooth — no upward stutter mid-drop (worst %.2fpx)" % _max_upward_stutter)
				# FEEL: no teleport — no single airborne frame skips more than a tile.
				_check(_max_frame_jump <= float(Player.CELL),
					"no single-frame teleport during the fall (worst %.1fpx, tile=%d)" % [_max_frame_jump, Player.CELL])
				_finish()
			elif _budget > 180:
				_check(false, "never fell/landed after the floor was mined (dropped %.0fpx)"
					% (_player.position.y - _y_at_mine))
				_finish()


func _finish() -> void:
	if _failures == 0:
		print("ALL FALL CHECKS PASS")
		quit(0)
	else:
		printerr("%d FALL FAILURE(S)" % _failures)
		quit(1)
