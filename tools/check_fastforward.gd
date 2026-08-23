extends SceneTree

## Guards the FAST-FORWARD game clock (Engine.time_scale > 1): the body's substep integration must
## resolve collision every tile even when a frame's delta is large, or a fast fall skips through thin
## geometry (tunneling). Two cases at time_scale = 8 (per-step delta ~0.133, ~8x the normal 1/60):
##   A. NO TUNNEL: drop the body onto a 1-tile-thick ledge with a VOID beneath it. Un-substepped it
##      would fall ~74px/frame and blow straight past the 32px ledge into the void; substep catches it.
##   B. FAST-FORWARD IS REAL + no sink: walking under 8x covers far more ground per real second than 1x
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
	elif _phase == 1:                     # B: fast-forward covers real ground + body stays on that floor
		_player.input_dir = 1.0
		# MEASURED AGAINST A FLOOR THIS FIXTURE BUILT AND THEREFORE KNOWS. Two rounds of wrong guard here,
		# and both were wrong ABOUT THE SAME THING: there was never a controlled floor to measure against.
		#
		# Round one asked `bottom > surface_row(col) * 32 + 20`. `surface_row` is the first solid cell from
		# the top, so over a hole the "surface" became the hole's FLOOR, descending in step with the falling
		# body: self-cancelling, quiet exactly when the body left the ground, green on a forty-row fall.
		#
		# Round two asked `is_solid(body_cell)`, the body's own collision authority (player.gd:639), immune
		# to terrain shape and to the ground moving. Immune, but watching the wrong event. A body falling
		# cleanly down an open shaft is in no rock at all, so it PASSED BY CONSTRUCTION. The old guard failed
		# open on a fall; the replacement failed open on the same fall for a fresh reason.
		#
		# The defect underneath both: `_flat_run` GUARANTEES EIGHT flat columns and the phase travels about
		# THIRTY-SEVEN. For roughly three-quarters of the run the body was over whatever the world happened
		# to contain, so neither predicate ever had a datum. Choosing a better predicate could not fix that,
		# because the missing thing was not the question; it was the ground.
		#
		# So the runway is CONSTRUCTED to cover the whole expected distance and `_floor_top` is remembered
		# from the build, not re-queried from the world. Three properties, each failing for its own reason:
		#   non-overlap : the body is not inside rock          (round two's question, kept)
		#   floor datum : the body is on the floor it started on (round one's question, finally answerable)
		#   travel      : fast-forward actually moved the body
		# The datum test is the one that catches an open hole: falling costs height against a fixed number,
		# and a fixed number cannot follow the body down.
		var body_cell: Vector2i = _player._cell_of(_player.position)
		var bottom: float = _player.position.y + Player.HEIGHT * 0.5
		_max_dev = maxf(_max_dev, absf(bottom - _floor_top))
		if _sim.is_solid(body_cell):
			printerr("  FAIL: body OVERLAPS rock under %.0fx — its own cell %s is solid (bottom=%.0f, floor=%.0f)"
				% [SCALE, body_cell, bottom, _floor_top])
			_fails += 1
			_done()
		elif absf(bottom - _floor_top) > FLOOR_TOL:
			var how: String = "SANK/FELL BELOW" if bottom > _floor_top else "ROSE ABOVE"
			printerr("  FAIL: body %s its own runway floor under %.0fx — bottom=%.0f, floor=%.0f (%.0fpx, tol %.0f) at col %d"
				% [how, SCALE, bottom, _floor_top, absf(bottom - _floor_top), FLOOR_TOL, body_cell.x])
			_dump_runway(body_cell.x)
			_fails += 1
			_done()
		elif body_cell.x >= _runway_hi - 2:
			# Ran out of built floor. The datum is only valid over the runway, so stop here and judge travel
			# rather than keep asserting against ground this fixture no longer controls.
			_finish_walk()
		elif _budget <= 0:
			_finish_walk()


## Travel, judged once, with the datum deviation reported so the tolerance is answerable from evidence.
func _finish_walk() -> void:
	var travelled: float = _player.position.x - _walk_start_x
	# 60 real frames at 8x ≈ 8s of game-time; at 150px/s that's ~1200px, vs ~150px at 1x.
	if travelled > 700.0:
		print("  PASS: covered %.0fpx in 60 real frames under %.0fx (a 1x run manages ~150px); stayed on the"
			% [travelled, SCALE]
			+ " runway floor throughout — worst deviation %.1fpx of %.0f allowed" % [_max_dev, FLOOR_TOL])
	else:
		printerr("  FAIL: only %.0fpx in 60 frames — fast-forward not advancing the body" % travelled)
		_fails += 1
	_done()


## A: a 1-tile-thick ledge (row r solid) with 4 rows of VOID beneath it, then a catch floor far below.
## Drop the body ~6 tiles above the ledge so it hits terminal speed before impact.
## HOW MANY OF THE TWO CASES WERE ACTUALLY POSED, and which were not.
##
## Both setups need terrain to build on, and both used to answer "no site" by printing a line to stderr and
## moving on without recording anything. `_done()` prints FAST-FORWARD GUARD PASS whenever `_fails == 0`,
## and a run that posed nothing has `_fails == 0` -- so a world that offered neither site produced a green
## over no cases at all. `check_step` had the identical defect and was found in the same audit.
##
## `SF_FF_NOSITE=1` forces both finders to fail, in the same spirit as `SF_FF_MUTANT` below: the claim that
## this refusal fires should be re-runnable by anyone who doubts it, without editing the file.
const CASES: int = 2
var _posed: int = 0
var _missed: PackedStringArray = PackedStringArray()


func _no_site() -> bool:
	return OS.get_environment("SF_FF_NOSITE") == "1"


func _setup_ledge() -> void:
	var f: int = -1 if _no_site() else _flat_run(12, 4)
	if f < 0:
		printerr("  (no flat run found — skipping A)")
		_missed.append("A (the ledge)")
		_setup_walk()
		return
	_posed += 1
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


## B: a runway this fixture BUILDS, wide enough for the whole sprint, and then sprints along it.
##
## `_flat_run(…, 8)` was the bug behind two guards: it FINDS eight flat columns and the phase covers about
## thirty-seven, so most of the run happened over uncontrolled world. A found floor also cannot be a datum:
## you can only remember a number you chose. So the floor is written here, at one row, across the full
## distance plus margin, and `_floor_top` is kept from the write.
##
## RUNWAY_COLS is sized off the thing being measured rather than guessed: the PASS bar is 700px of travel
## and the phase typically manages ~1200px, so 56 columns (1792px) covers the expected distance with room
## for the body to be stopped by the runway-end check instead of by terrain.
const RUNWAY_COLS: int = 56
const RUNWAY_FILL: int = 3    ## rows of floor written under the walk line — thicker than any one step
const RUNWAY_CLEAR: int = 6   ## rows of headroom carved above it, so a hillside cannot block the sprint
## How far the body's feet may stray from the floor it was placed on. One cell is 32px; a body that has
## sunk or fallen is off by at least that. 8px is loose enough for step/settle jitter and still a quarter
## of the smallest real defect. Every run prints its worst deviation, so this is answerable from evidence
## rather than defended: if it ever tightens or loosens it will be because a number said so.
const FLOOR_TOL: float = 8.0
var _floor_top: float = 0.0
var _runway_hi: int = 0
var _max_dev: float = 0.0


## THE RUNWAY HAS TO BE CLEAR OF MACHINES, WHICH `set_solid` CANNOT DO ANYTHING ABOUT.
##
## Found by the datum test on its first honest run, and it is the reason a controlled floor was worth
## building rather than found. The runway was written perfectly flat (every column reporting
## `surface_row = 21`, rows 17..20 empty, 21..22 stone), and the body still rose exactly one cell at column
## 46, because a MACHINE stood at (46, 20). `set_solid` writes terrain; machines live in `sim.grid` and are
## untouched by it. The body does not rest on solid cells either: `_step_up` rests it on `_surface_y`, and
## `_blocked` counts a machine, so it climbed onto the box.
##
## They are NOT bulldozed here. Deleting the starting base to make a fixture convenient would be the same
## move as retuning DELVE_ROWS to suit a new question: the fixture would stop describing the world the
## game actually boots. So the site is CHOSEN to be free of them, which also keeps the run deterministic
## for a given seed instead of depending on where the base happened to be laid.
##
## Terrain flatness is deliberately NOT a criterion. The runway is written, so the ground underneath it
## does not need to start flat; only the things this fixture cannot rewrite have to be absent.
func _runway_site(from: int) -> int:
	for lo: int in range(from, FactorySim.GRID_COLS - RUNWAY_COLS - 1):
		var r: int = _sim.surface_row(lo)
		if r < RUNWAY_CLEAR + 1 or r >= FactorySim.GRID_ROWS - RUNWAY_FILL - 1:
			continue
		# ON THE ACTUAL SURFACE, not merely on the first solid cell. `surface_row` answers "topmost rock in
		# this column", which inside a rift or a chasm is a floor seventeen rows underground, and the first
		# site this search accepted was exactly that (col 23, row 54). The runway still worked as a datum
		# there, and both new assertions behaved correctly, so this is not a correctness fix for them. It is
		# a fix for what the layer MEANS: a guard whose subject is "walking under fast-forward" should be
		# walking on the surface the player walks on, not along the bottom of a hole that happened to be
		# leftmost. Bounding the row to the generator's own surface band is the cheapest way to say so.
		if r < HeightmapWorldGen.SURFACE_ROW_MIN or r > HeightmapWorldGen.SURFACE_ROW_MAX:
			continue
		var clear: bool = true
		for col: int in range(lo, lo + RUNWAY_COLS):
			for row: int in range(r - RUNWAY_CLEAR, r + RUNWAY_FILL):
				if _sim.machine_at(Vector2i(col, row)) != null:
					clear = false
					break
			if not clear:
				break
		if clear:
			return lo
	return -1
func _setup_walk() -> void:
	var lo: int = -1 if _no_site() else _runway_site(maxi(4, _ledge_col + 5))
	if lo < 0:
		printerr("  (no machine-free %d-column site with room to build — skipping B)" % RUNWAY_COLS)
		_missed.append("B (the runway walk)")
		_done()
		return
	_posed += 1
	var r: int = _sim.surface_row(lo)
	_runway_hi = lo + RUNWAY_COLS
	for col: int in range(lo, _runway_hi):
		for dy: int in range(0, RUNWAY_FILL):
			_sim.set_solid(Vector2i(col, r + dy), &"stone")
		for dy: int in range(1, RUNWAY_CLEAR + 1):
			_sim.set_solid(Vector2i(col, r - dy), &"")
	_floor_top = float(r * 32)
	_max_dev = 0.0
	# THE FIXTURE'S OWN MUTANT, kept in the file rather than applied by hand, because "prove the guard goes
	# red" is a claim that should be re-runnable by anyone who doubts it. It punches a clean OPEN HOLE in the
	# runway (no rock anywhere near the body), which is precisely the event both previous guards passed.
	if OS.get_environment("SF_FF_MUTANT") == "1":
		var hole: int = lo + RUNWAY_COLS / 2
		for col: int in range(hole, hole + 3):
			for dy: int in range(0, RUNWAY_FILL + 10):
				_sim.set_solid(Vector2i(col, r + dy), &"")
		print("  MUTANT: open hole punched at cols %d..%d — a correct guard MUST fail this run"
			% [hole, hole + 2])
	_player.position = Vector2(float(lo * 32 + 16), _floor_top - Player.HEIGHT * 0.5)
	_player.velocity = Vector2.ZERO
	_walk_start_x = _player.position.x
	_phase = 1
	_budget = 60
	print("  runway built: cols %d..%d on row %d (floor_top=%.0f); sprinting right for 60 real frames"
		% [lo, _runway_hi - 1, r, _floor_top])


## WHAT IS ACTUALLY UNDER THE BODY, printed when the datum test fails, because "the body is not where the
## fixture built the floor" has several possible causes and the run should not force a guess between them.
## `surface_row` is included beside raw solidity on purpose: the body does not rest on solid cells, it rests
## on `_surface_y`, which reads the sim's silhouette, and that skips foliage. When the two disagree, the
## disagreement IS the answer.
func _dump_runway(at_col: int) -> void:
	printerr("       runway datum row %d; columns around the failure:" % int(_floor_top / 32.0))
	for col: int in range(maxi(0, at_col - 3), mini(FactorySim.GRID_COLS, at_col + 4)):
		var rows: PackedStringArray = PackedStringArray()
		for row: int in range(int(_floor_top / 32.0) - 4, int(_floor_top / 32.0) + 2):
			var c := Vector2i(col, row)
			var tag: String = "."
			if _sim.is_solid(c):
				tag = String(_sim.material_at(c)).substr(0, 2)
			if _sim.machine_at(c) != null:
				tag = "M"
			rows.append("%d:%s" % [row, tag])
		printerr("         col %d  surface_row=%d  %s" % [col, _sim.surface_row(col), " ".join(rows)])


func _done() -> void:
	physics_frame.disconnect(_phys)
	Engine.time_scale = 1.0
	# A CASE THAT WAS NEVER POSED IS NOT ONE THAT PASSED, and this is checked before `_fails`, because
	# `_fails == 0` is what a run that posed nothing reports.
	if _posed < CASES:
		printerr("  %d of %d guard cases were never posed, so this run judged nothing about them: %s"
			% [CASES - _posed, CASES, ", ".join(_missed)])
		printerr("%d fast-forward guard case(s) FAILED, and %d were not attempted"
			% [_fails, CASES - _posed])
		quit(1)
		return
	if _fails == 0:
		print("FAST-FORWARD GUARD PASS (%d cases posed)" % _posed)
		quit(0)
	else:
		printerr("%d fast-forward guard case(s) FAILED" % _fails)
		quit(1)
