extends "res://tools/check_base.gd"

## Harness layer 5 — motion check for the LIFT RIDE (the rideable half of the updraft shaft). Builds a
## walled shaft with a lift at the bottom, drops the body into it, and asserts the updraft carries it
## UP and it stops at the ceiling (it doesn't ride through solid). Run HEADED:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_lift.gd

const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _player: Player
var _frames: int = 0
var _phase: int = 0
var _t: float = 0.0
var _y_start: float = 0.0
var _checked_mid: bool = false


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== lift ride check ==")
	physics_frame.connect(_phys)


## A vertical shaft (cols 4..6 open) walled left/right, a floor at the bottom, a ceiling cap at the
## top, and a LIFT just above the floor. The body starts mid-shaft and should ride up to the ceiling.
func _build() -> void:
	var sim: FactorySim = _main.sim
	var lift_def: MachineDef = load("res://src/data/machines/lift.tres")
	for x: int in range(3, 8):
		for y: int in range(1, 20):
			sim.set_solid(Vector2i(x, y), &"")
	for y: int in range(1, 20):
		sim.set_solid(Vector2i(3, y), &"earth")     # left wall
		sim.set_solid(Vector2i(7, y), &"earth")     # right wall
	for x: int in range(3, 8):
		sim.set_solid(Vector2i(x, 18), &"earth")    # floor
	sim.set_solid(Vector2i(5, 1), &"earth")         # ceiling cap (rise must stop here)
	sim.place_machine(lift_def, Vector2i(5, 17))    # lift just above the floor
	_player.position = _main._cell_center(Vector2i(5, 15))
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
		0:
			_player.input_dir = 0.0
			_y_start = _player.position.y
			_phase = 1; _t = 0.0
		1:
			_t += 1.0 / 60.0
			if not _checked_mid and _t >= 1.5:
				_checked_mid = true
				_check(_player.position.y < _y_start - 64.0,
					"the updraft carried the body UP mid-ride (dy=%.0f)" % (_player.position.y - _y_start))
			if _t >= 4.5:  # enough time to rise the full shaft (120px/s over ~13 tiles)
				_check(_player.position.y < float(4 * 32),
					"rode to the top of the shaft, stopped by the ceiling (y=%.0f)" % _player.position.y)
				_phase = 2
		2:
			_verdict("check_lift")
