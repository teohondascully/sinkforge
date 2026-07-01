extends SceneTree

## Guards the FAST-FORWARD game clock (Engine.time_scale > 1): the body's substep integration must
## resolve collision every tile even when a frame's delta is large, or a fast fall skips through thin
## geometry (tunneling). Two cases at time_scale = 8 (per-step delta ~0.133, ~8x the normal 1/60):
##   A. NO TUNNEL — drop the body onto a 1-tile-thick ledge with a VOID beneath it. Un-substepped it
##      would fall ~74px/frame and blow straight past the 32px ledge into the void; substep catches it.
##   B. FAST-FORWARD IS REAL + no sink — walking under 8x covers far more ground per real second than 1x
##      could, and the body never sinks into the floor while doing it.
## HEADED:  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_fastforward.gd

const SCENE: String = "res://scenes/main.tscn"
const SCALE: float = 8.0

var _main: MainView
var _player: Player
var _sim: FactorySim
var _frames: int = 0
var _phase: int = -1
var _budget: int = 0
var _fails: int = 0
var _ledge_row: int = -1
var _ledge_col: int = -1
var _walk_start_x: float = 0.0


func _initialize() -> void:
	Engine.max_fps = 60
	Engine.time_scale = SCALE
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== fast-forward tunnel guard (time_scale = %.0f) ==" % SCALE)
	physics_frame.connect(_phys)


## Leftmost column of a flat run of `length` columns clear of the edges, or -1.
func _flat_run(start: int, length: int) -> int:
	for c: int in range(start, FactorySim.GRID_COLS - length - 1):
		var r: int = _sim.surface_row(c)
		if r < 4 or r >= FactorySim.GRID_ROWS - 8:
			continue
		var flat: bool = true
		for k: int in range(1, length):
			if _sim.surface_row(c + k) != r:
				flat = false
				break
		if flat:
			return c
	return -1


func _phys() -> void:
	_frames += 1
	if _frames < 20:
		return
	if _player == null:
		_player = _main._player
		_sim = _main.sim
		_player.auto_input = false
		_setup_ledge()
		return
	_budget -= 1

	if _phase == 0:                       # A: fall onto the thin ledge without tunneling through it
		var bottom: float = _player.position.y + Player.HEIGHT * 0.5
		var ledge_top: float = float(_ledge_row * 32)
		if _player.on_floor and absf(bottom - ledge_top) < 6.0:
			print("  PASS: fell onto the 1-tile ledge under %.0fx — no tunnel (bottom=%.0f, ledge=%.0f)"
				% [SCALE, bottom, ledge_top])
			_setup_walk()
		elif bottom > ledge_top + 40.0:   # sank a full tile past the ledge → fell through the void
			printerr("  FAIL: TUNNELED through the ledge under %.0fx (bottom=%.0f is past ledge %.0f)"
				% [SCALE, bottom, ledge_top])
			_fails += 1
			_setup_walk()
		elif _budget <= 0:
			printerr("  FAIL: never settled on the ledge (bottom=%.0f, ledge=%.0f)" % [bottom, ledge_top])
			_fails += 1
			_setup_walk()
	elif _phase == 1:                     # B: fast-forward covers real ground + body stays on the floor
		_player.input_dir = 1.0
		var surf_top: float = float(_sim.surface_row(_player._cell_of(_player.position).x) * 32)
		var bottom: float = _player.position.y + Player.HEIGHT * 0.5
		if bottom > surf_top + 20.0:      # sank well into the ground while running fast
			printerr("  FAIL: body sank into the floor under %.0fx (bottom=%.0f, surface=%.0f)"
				% [SCALE, bottom, surf_top])
			_fails += 1
			_done()
		elif _budget <= 0:
			var travelled: float = _player.position.x - _walk_start_x
			# 60 real frames at 8x ≈ 8s of game-time; at 150px/s that's ~1200px, vs ~150px at 1x.
			if travelled > 700.0:
				print("  PASS: covered %.0fpx in 60 real frames under %.0fx (a 1x run manages ~150px)"
					% [travelled, SCALE])
			else:
				printerr("  FAIL: only %.0fpx in 60 frames — fast-forward not advancing the body" % travelled)
				_fails += 1
			_done()


## A: a 1-tile-thick ledge (row r solid) with 4 rows of VOID beneath it, then a catch floor far below.
## Drop the body ~6 tiles above the ledge so it hits terminal speed before impact.
func _setup_ledge() -> void:
	var f: int = _flat_run(12, 4)
	if f < 0:
		printerr("  (no flat run found — skipping A)")
		_setup_walk()
		return
	var c: int = f + 1
	var r: int = _sim.surface_row(c)
	_ledge_col = c
	_ledge_row = r
	for dy: int in range(1, 6):
		_sim.set_solid(Vector2i(c, r + dy), &"")          # hollow a void directly beneath the ledge
	_player.position = Vector2(float(c * 32 + 16), float((r - 6) * 32) - Player.HEIGHT * 0.5)
	_player.velocity = Vector2(0.0, 0.0)
	_player.on_floor = false
	_phase = 0
	_budget = 200
	print("  ledge at col %d row %d, void beneath; body dropped from 6 tiles up" % [c, r])


## B: a clean flat run; the body sprints right under fast-forward for 60 real frames.
func _setup_walk() -> void:
	var g: int = _flat_run(maxi(4, _ledge_col + 5), 8)
	if g < 0:
		printerr("  (no flat run found — skipping B)")
		_done()
		return
	var r: int = _sim.surface_row(g)
	_player.position = Vector2(float(g * 32 + 16), float(r * 32) - Player.HEIGHT * 0.5)
	_player.velocity = Vector2.ZERO
	_walk_start_x = _player.position.x
	_phase = 1
	_budget = 60
	print("  flat run at col %d; sprinting right for 60 real frames" % g)


func _done() -> void:
	physics_frame.disconnect(_phys)
	Engine.time_scale = 1.0
	if _fails == 0:
		print("FAST-FORWARD GUARD PASS")
		quit(0)
	else:
		printerr("%d fast-forward guard case(s) FAILED" % _fails)
		quit(1)
