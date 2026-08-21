extends "res://tools/check_base.gd"

## Harness layer — WATER IMPEDANCE (L3 slice 3b). The body should WADE, not glide, through water: reduced
## horizontal speed, buoyant slow-fall, a weaker jump — the felt located-hazard the Pump later relieves.
## This turns "does water slow you?" into repeatable NUMBERS, driving the REAL Player over sim-placed floor
## with the sim's discrete water API (add_water), like check_walk / check_body_stress. Tolerance-based
## (real-time physics has minor variance); asserts INVARIANTS a shipping wader must satisfy:
##   1. SLOWED: horizontal distance over N frames on a flooded floor is CLEARLY less than on dry floor.
##   2. NOT STUCK: it still moves in water (D_wet > 0) — impedance is friction, not a wall.
##   3. EXITS: driven off the flooded stretch onto dry land, it LEAVES the watered cells.
##   4. BUOYANT: falling through deep water, it descends SLOWER than the same fall in air.
## Deterministic: fixed floor, no unseeded random. HEADED:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_water_move.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = FactorySim.CELL

## A cleared, flat test arena: a thick floor plate with open air above it (like check_agility's course),
## so the natural terrain can't wall the body and the run is fully deterministic.
const ARENA_COL: int = 6             ## leftmost column of the plate
const ARENA_LEN: int = 26            ## columns wide (long enough for a clear-margin walk + a dry exit)
const FLOOR_ROW: int = 24            ## the plate's top row (the body stands on FLOOR_ROW - 1)
const WALK_FRAMES: int = 80          ## frames of a straight rightward drive when measuring D_dry / D_wet
## The wet run must be CLEARLY slower — with WATER_SPEED_MULT 0.55 the wet/dry ratio floors near ~0.55,
## so a 0.85 ceiling is a comfortable margin that still trips if the mult were ever weakened toward 1.0.
const SLOW_RATIO_MAX: float = 0.85   ## D_wet must be <= this × D_dry (a clear, measurable slowdown)
const MOVE_EPS: float = 8.0          ## px that proves the body is NOT frozen (still wades)

var _main: MainView
var _player: Player
var _sim: FactorySim

func _initialize() -> void:
	print("== water-move check (L3 impedance) ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("WATER-MOVE OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)


func _run() -> void:
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	for _i: int in 30:                                   # _ready runs on add; let the world settle
		await physics_frame
	_player = _main._player
	_sim = _main.sim
	_player.auto_input = false                           # WE drive the body, not the (absent) keyboard
	_build_arena()

	# --- (1)+(2)+(3): DRY vs WET horizontal travel, and the exit ---------------------------------------
	var d_dry: float = await _walk_run(false)
	var d_wet: float = await _walk_run(true)
	print("  horizontal: D_dry=%.1fpx  D_wet=%.1fpx  ratio=%.2f (must be <= %.2f)"
		% [d_dry, d_wet, d_wet / maxf(1.0, d_dry), SLOW_RATIO_MAX])
	_check(d_wet > MOVE_EPS, "the body still WADES in water (D_wet=%.1f > %.1f — not stuck)" % [d_wet, MOVE_EPS])
	_check(d_wet < d_dry * SLOW_RATIO_MAX,
		"water measurably SLOWS the body (D_wet %.1f < %.2f×D_dry %.1f)" % [d_wet, SLOW_RATIO_MAX, d_dry])

	var exited: bool = await _exit_run()
	_check(exited, "the body can EXIT water onto dry land (leaves the watered cells)")

	# --- (4): BUOYANCY — slower fall in deep water than in air ----------------------------------------
	var fall_air: float = await _fall_run(false)
	var fall_water: float = await _fall_run(true)
	print("  vertical: fall_air=%.1fpx  fall_water=%.1fpx (deep water must fall SLOWER)"
		% [fall_air, fall_water])
	_check(fall_water > 0.0, "the body DOES sink in water (buoyant, not neutrally floating: %.1fpx)" % fall_water)
	_check(fall_water < fall_air * 0.9,
		"deep water is BUOYANT — falls slower than air (%.1f < 0.9×%.1f)" % [fall_water, fall_air])

	_main.queue_free()
	await physics_frame


## A thick floor plate under a patch of cleared open sky, drained of any world water — a deterministic
## arena the natural terrain (hills / aquifers) can't perturb.
func _build_arena() -> void:
	for col: int in range(ARENA_COL - 1, ARENA_COL + ARENA_LEN + 1):
		for row: int in range(0, FLOOR_ROW + 4):
			_sim.set_solid(Vector2i(col, row), &"")          # clear to open sky (also drains water: solid→dry)
		for row: int in range(FLOOR_ROW, FLOOR_ROW + 4):
			_sim.set_solid(Vector2i(col, row), &"stone")     # a thick solid plate, no holes
	# Belt-and-braces: erase any residual water in the arena's air column.
	for col: int in range(ARENA_COL - 1, ARENA_COL + ARENA_LEN + 1):
		for row: int in range(0, FLOOR_ROW):
			_sim.remove_water(Vector2i(col, row), FactorySim.WATER_MAX)


## Drop the body on the plate at the given column and let it come to rest, feet on FLOOR_ROW - 1.
func _settle_body(col: int) -> void:
	_player.position = _main._cell_center(Vector2i(col, FLOOR_ROW - 1))
	_player.velocity = Vector2.ZERO
	_player.input_dir = 0.0
	for _i: int in 24:
		await physics_frame


## Flood the walkable stretch (the two air rows above the plate the body occupies) to full, so every step
## of the walk is genuinely IN water. Drained again by the caller's arena rebuild between runs.
func _flood_walk_stretch() -> void:
	for col: int in range(ARENA_COL, ARENA_COL + ARENA_LEN):
		_sim.add_water(Vector2i(col, FLOOR_ROW - 1), FactorySim.WATER_MAX)
		_sim.add_water(Vector2i(col, FLOOR_ROW - 2), FactorySim.WATER_MAX)


## Drive the body straight right for WALK_FRAMES and return the horizontal distance travelled. `flooded`
## floods the walk stretch first (IDENTICAL drive otherwise) so D_dry and D_wet are directly comparable.
func _walk_run(flooded: bool) -> float:
	_build_arena()                                       # fresh dry arena each run (drains prior water)
	await _settle_body(ARENA_COL + 2)
	if flooded:
		_flood_walk_stretch()
		# Re-settle a beat so the water grid is live before the timed drive begins.
		for _i: int in 4:
			await physics_frame
	var x0: float = _player.position.x
	_player.input_dir = 1.0
	for _i: int in WALK_FRAMES:
		await physics_frame
	_player.input_dir = 0.0
	return _player.position.x - x0


## Build a WALLED BASIN pool (a trench sunk into the plate, bounded by solid on both sides so the sim's
## per-tick lateral _flow_water CANNOT spread it out of the pit), fill it to submerge a standing body, and
## start the body in it. Then drive right: it must climb the pit's 1-tile lip onto the dry plate and end
## with its whole footprint OUT of the water. Proves a flooded pocket is passable friction, not a trap.
func _exit_run() -> bool:
	_build_arena()
	# Carve a basin TWO rows deeper than the plate surface (dig FLOOR_ROW + FLOOR_ROW+1 across the pit
	# columns), bounded by solid on both sides so the sim's per-tick lateral _flow_water CANNOT carry it out
	# of the pit (walls bound a water run). Fill ONLY up to the lip (FLOOR_ROW-1, the surrounding surface
	# level) so the pool never overtops the rim and spills onto the dry plate — the pit self-contains it.
	var basin_lo: int = ARENA_COL + 2
	var basin_hi: int = ARENA_COL + 6
	for col: int in range(basin_lo, basin_hi + 1):
		_sim.set_solid(Vector2i(col, FLOOR_ROW), &"")            # dig the pit
		_sim.set_solid(Vector2i(col, FLOOR_ROW + 1), &"")
	# Fill the two dug rows + the lip row (a submerging pool whose surface sits AT the rim, not above it).
	for col: int in range(basin_lo, basin_hi + 1):
		for row: int in range(FLOOR_ROW - 1, FLOOR_ROW + 2):
			_sim.add_water(Vector2i(col, row), FactorySim.WATER_MAX)
	# Stand the body in the basin, feet on the sunk floor (rests on FLOOR_ROW+2, submerged past its head).
	_player.position = _main._cell_center(Vector2i(basin_lo + 1, FLOOR_ROW + 1))
	_player.velocity = Vector2.ZERO
	_player.input_dir = 0.0
	for _i: int in 24:
		await physics_frame
	# Confirm we START wet (else the test proves nothing).
	if not _body_in_water():
		printerr("  (exit-run setup: body did not start in water — arena/flood off)")
		return false
	# Drive right, hopping the 1-tile lip out of the pit onto the dry plate beyond basin_hi.
	_player.input_dir = 1.0
	var f: int = 0
	while f < 400:
		await physics_frame
		f += 1
		if _player.on_floor and f % 20 == 0:
			_player.request_jump()                              # hop the lip if a plain step-up won't clear it
		if _player.position.x > float((basin_hi + 4) * CELL):
			break
	_player.input_dir = 0.0
	for _i: int in 8:                                    # let it settle on the dry plate
		await physics_frame
	print("    exit: drove from a flooded basin to cell %s (dry=%s) in %d frames"
		% [str(_main._cell_at(_player.position)), str(not _body_in_water()), f])
	return not _body_in_water()


## Let the body FALL through a tall open shaft for a fixed frame count, measuring how far it descends.
## `flooded` fills the shaft with deep water so the buoyancy mult is in effect; identical geometry otherwise.
func _fall_run(flooded: bool) -> float:
	_build_arena()
	# A deep open shaft above the plate at the arena's centre — clear a tall column, no side walls needed.
	var col: int = ARENA_COL + ARENA_LEN / 2
	var top: int = 4
	for row: int in range(top, FLOOR_ROW):
		_sim.set_solid(Vector2i(col, row), &"")
		_sim.set_solid(Vector2i(col - 1, row), &"")
		_sim.set_solid(Vector2i(col + 1, row), &"")
		_sim.remove_water(Vector2i(col, row), FactorySim.WATER_MAX)   # drain the shaft (residual from a prior run)
	if flooded:
		for row: int in range(top, FLOOR_ROW):
			_sim.add_water(Vector2i(col, row), FactorySim.WATER_MAX)
	# Start the body high in the shaft with zero velocity, then let gravity act for a fixed window. Measured
	# over the same frame count from the same rest, so a slower descent = a smaller number = buoyancy.
	_player.position = _main._cell_center(Vector2i(col, top + 2))
	_player.velocity = Vector2.ZERO
	_player.input_dir = 0.0
	var y0: float = _player.position.y
	for _i: int in 30:
		if flooded:
			# The sim's per-tick gravity settles the pool toward the shaft bottom; re-top the column the body
			# is passing through so it stays genuinely SUBMERGED for the whole measured fall.
			for row: int in range(top, FLOOR_ROW):
				_sim.add_water(Vector2i(col, row), FactorySim.WATER_MAX)
		await physics_frame
	return _player.position.y - y0


## True if any cell the body's AABB overlaps holds water — mirrors Player._in_water for the test's own read.
func _body_in_water() -> bool:
	var rect := Rect2(_player.position.x - Player.WIDTH * 0.5, _player.position.y - Player.HEIGHT * 0.5,
			Player.WIDTH, Player.HEIGHT)
	var lo := Vector2i(floori(rect.position.x / float(CELL)), floori(rect.position.y / float(CELL)))
	var hi := Vector2i(floori((rect.end.x - 0.001) / float(CELL)), floori((rect.end.y - 0.001) / float(CELL)))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			if _sim.water_at(Vector2i(cx, cy)) > 0:
				return true
	return false
