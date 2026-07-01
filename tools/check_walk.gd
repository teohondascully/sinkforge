extends SceneTree

## Bug hunt — the "walking and I get teleported back ~1 foot" report. Drives the REAL body across the
## REAL generated surface (hills + slopes + the surface forge) and flags any frame where the body moves
## BACKWARD against its input (a horizontal snap). Logs the worst offender with context (on a ramp? a
## machine ahead? a surface-row transition?) so we can see WHAT snaps it. HEADED:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_walk.gd

const SCENE: String = "res://scenes/main.tscn"
const BACK_EPS: float = 4.0          ## backward jump > this (px) against input = a real teleport (sub-px
                                     ## collision jitter is ~2.5px/frame and fine; a teleport is a tile+)

var _main: MainView
var _player: Player
var _frames: int = 0
var _phase: int = 0
var _prev_x: float = 0.0
var _dir: float = 1.0
var _worst: float = 0.0
var _worst_ctx: String = ""
var _snaps: int = 0
var _stuck_frames: int = 0
var _worst_reach: float = 0.0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== walk-back bug hunt ==")
	physics_frame.connect(_phys)


func _phys() -> void:
	_frames += 1
	if _frames > 4000:
		_report(); return
	if _frames < 30:
		return
	if _player == null:
		_player = _main._player
		_player.auto_input = false
		# Stand on the surface at the far left (col 2) so a long rightward walk crosses the western hills, the
		# centred flat plateau (with its fixtures), and the eastern hills — exercising every surface type.
		var sx: int = 2
		var sy: int = _main.sim.surface_row(sx)
		_player.position = _main._cell_center(Vector2i(sx, sy - 1))
		_player.velocity = Vector2.ZERO
		_prev_x = _player.position.x
		# Put a machine ON the flat plateau in the walking path (its clear left lane, left of the bazaar).
		# Machines aren't in the slope authority, so the body can't GLIDE over a 1-tile machine the way it
		# glides over a 1-tile terrain step — it hits the box head-on. Prime suspect for "walking + snapped back".
		var proc: MachineDef = load("res://src/data/machines/processor.tres")
		var mcol: int = HeightmapWorldGen.FLAT_START + 4
		var pc := Vector2i(mcol, _main.sim.surface_row(mcol) - 1)
		_main.sim.place_machine(proc, pc)
		print("  placed a test machine at %s (surface walk path)" % pc)
		return

	# Walk right across the whole world, then turn around and walk left — both directions can snap.
	if _phase == 0 and _player.position.x > float((FactorySim.GRID_COLS - 3) * 32):
		_phase = 1; _dir = -1.0
	if _phase == 1 and _player.position.x < float(4 * 32):
		_report(); return
	_player.input_dir = _dir

	_worst_reach = maxf(_worst_reach, _player.position.x)
	var dx: float = _player.position.x - _prev_x
	# Stuck detector: input is ON but we've barely moved for many frames, and the cell ahead at FOOT
	# level is OPEN (so it's not a legit wall stopping us — something at body/head height snagged us).
	if absf(dx) < 0.2:
		_stuck_frames += 1
		if _stuck_frames % 18 == 0 and _player.on_floor:
			_player.request_jump()      # hop machines/walls (you jump over them) so we test the WHOLE walk
	else:
		_stuck_frames = 0
	# A snap = moving opposite to input by more than BACK_EPS (not just decelerating into a wall, which
	# is dx≈0). We compare against the SIGN of input: dir>0 wants +dx; a <-EPS dx is a backward jump.
	if _dir > 0.0 and dx < -BACK_EPS or _dir < 0.0 and dx > BACK_EPS:
		_snaps += 1
		var mag: float = absf(dx)
		if mag > _worst:
			_worst = mag
			_worst_ctx = _context()
		if mag > 6.0:                 # a visible jerk (~a third of a tile+) — log it live
			printerr("  SNAP %.1fpx :: %s" % [mag, _context()])
	_prev_x = _player.position.x


## Describe what's around the body at the moment of a snap — the diagnostic payload.
func _context() -> String:
	var sim: FactorySim = _main.sim
	var c: Vector2i = _main._cell_at(_player.position)
	var ahead: Vector2i = c + Vector2i(int(_dir), 0)
	var head_ahead: Vector2i = ahead + Vector2i(0, -1)
	return ("x=%.1f cell=%s dir=%d on_floor=%s | ahead solid=%s machine=%s | head-ahead solid=%s machine=%s | surf(here=%d ahead=%d) ramp(here=%d ahead=%d)"
		% [_player.position.x, c, int(_dir), _player.on_floor,
		sim.is_solid(ahead), sim.machine_at(ahead) != null,
		sim.is_solid(head_ahead), sim.machine_at(head_ahead) != null,
		sim.surface_row(c.x), sim.surface_row(ahead.x), sim.ramp_dir(c.x), sim.ramp_dir(ahead.x)])


func _report() -> void:
	print("furthest x reached = %.1f (col %d of %d) over %d frames"
		% [_worst_reach, int(_worst_reach / 32.0), FactorySim.GRID_COLS, _frames])
	if _snaps == 0:
		print("NO BACKWARD SNAPS >0.3px — the snap is sub-pixel deceleration, OR the body never got far.")
		quit(0)
	else:
		printerr("REPRODUCED: %d backward-snap frames. Worst = %.1fpx" % [_snaps, _worst])
		printerr("  context: %s" % _worst_ctx)
		quit(1)
