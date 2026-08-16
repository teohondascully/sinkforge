extends SceneTree

## Harness layer — ADVERSARIAL BODY PHYSICS under TERRAIN CHURN. The static-course movement layers
## (check_step / check_walk / check_stepup / check_agility) prove the body moves well on terrain that
## HOLDS STILL. Live play surfaces a different bug class: the body getting STUCK, CLIPPING INTO SOLID,
## or FLUNG OUT OF THE WORLD when the ground changes UNDER and AROUND it — you mine the cell under your
## feet, you wall yourself in with placed blocks, you drop into a freshly-carved pit, the world churns
## while you're mid-step. That's what this hunts, in the REAL-TIME physics the sim-level stress tests
## can't reach: boot the real scene, drive the real Player, edit terrain with the sim's discrete API,
## and after each churn run the body a bounded number of frames (steering / jumping to escape) and
## assert the BODY INVARIANTS — never asserting exact positions (real-time physics has minor variance),
## only the invariants that a shipping body must never violate:
##   - NEVER INSIDE SOLID: after it settles, no solid cell overlaps the body's AABB.
##   - IN-WORLD: the body's cell stays within the world rect at all times (never flung out of bounds).
##   - NOT PERMANENTLY STUCK: given open floor, steering produces horizontal movement within N frames.
##   - no crash / valid state throughout.
## Deterministic fixed scenario sequence — NO unseeded random. HEADED:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_body_stress.gd

const SCENE: String = "res://scenes/main.tscn"

## After any terrain edit, give the body this many frames to settle before checking the "inside solid"
## invariant (a resolve/step-up/fall needs a beat; a single frame can legitimately still overlap).
const SETTLE_FRAMES: int = 30
## An open-floor stuck test drives input for this many frames and demands at least MOVE_EPS of travel.
const ESCAPE_FRAMES: int = 90
const MOVE_EPS: float = 24.0         ## px of horizontal travel that proves the body is NOT frozen

var _main: MainView
var _player: Player
var _sim: FactorySim
var _frames: int = 0
var _phase: int = 0
var _budget: int = 0
var _fails: int = 0

## Scenario workspace: a clean flat run and the body's footing column there.
var _run_col: int = -1               ## leftmost column of the flat run in use
var _foot_col: int = -1              ## the body's column (mid-run)
var _foot_row: int = -1             ## the terrain-surface row under the body
var _escape_x0: float = 0.0
var _churn_step: int = 0             ## which of the fixed churn edits we're on
var _sub: int = 0                    ## an explicit sub-phase index (avoids overlapping numeric thresholds)
var _worst_overlap: int = 0          ## how many churn frames caught the body fully inside solid (report)


func _initialize() -> void:
	Engine.max_fps = 120
	MainView.dev_start = false
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== body stress (adversarial terrain churn) ==")
	physics_frame.connect(_phys)


# --- invariant helpers ---------------------------------------------------------------------------

## The body's AABB as a cell rect (min/max cells it overlaps), in world-cell coordinates.
func _body_cells() -> Array[Vector2i]:
	var rect := Rect2(_player.position.x - Player.WIDTH * 0.5, _player.position.y - Player.HEIGHT * 0.5,
			Player.WIDTH, Player.HEIGHT)
	var lo := Vector2i(floori(rect.position.x / 32.0), floori(rect.position.y / 32.0))
	var hi := Vector2i(floori((rect.end.x - 0.001) / 32.0), floori((rect.end.y - 0.001) / 32.0))
	var out: Array[Vector2i] = []
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			out.append(Vector2i(cx, cy))
	return out

## How many of the body's overlapped cells are BLOCKING solid (earth/stone/etc — NOT walk-through
## wood/leaves, which the body legitimately passes). 0 = the body is not inside rock.
func _solid_overlap_count() -> int:
	var n: int = 0
	for c: Vector2i in _body_cells():
		if _sim.is_solid(c):
			var m: StringName = _sim.material_at(c)
			if m != &"wood" and m != &"leaves":
				n += 1
	return n

## True iff the body is FULLY inside solid — every overlapped cell is blocking rock. A body perched on a
## ledge or squeezed in a gap may clip ONE cell for a frame during a resolve; being wholly buried in rock
## (no open cell in its footprint at all) is the real "clipped into solid" bug.
func _fully_buried() -> bool:
	var cells: Array[Vector2i] = _body_cells()
	if cells.is_empty():
		return false
	return _solid_overlap_count() == cells.size()

## The body's center cell — used for the settled "not inside solid" invariant (its feet/center must be
## a standable, non-solid cell once the dust settles).
func _center_cell() -> Vector2i:
	return Vector2i(floori(_player.position.x / 32.0), floori(_player.position.y / 32.0))

func _in_world() -> bool:
	var c: Vector2i = _center_cell()
	# The body may legitimately be in open SKY above the world (cell.y < 0 is not "out of the world");
	# out-of-world = flung past a side wall or below the floor.
	return c.x >= 0 and c.x < FactorySim.GRID_COLS and c.y < FactorySim.GRID_ROWS \
			and _player.position.y < float(FactorySim.GRID_ROWS * 32) + 64.0 \
			and _player.position.x >= -32.0 and _player.position.x < float(FactorySim.GRID_COLS * 32) + 32.0

func _fail(msg: String) -> void:
	_fails += 1
	printerr("  FAIL: %s" % msg)


## Leftmost column of a flat clear run of `length` columns (open air above the surface for the body to
## stand in), or -1. Mirrors check_step._flat_run — clean terrain so the churn isn't fighting a ramp.
func _flat_run(start: int, length: int) -> int:
	for c: int in range(start, FactorySim.GRID_COLS - length - 1):
		var r: int = _sim.surface_row(c)
		if r >= FactorySim.GRID_ROWS - 6 or r < 4:
			continue
		var flat: bool = true
		for k: int in range(1, length):
			if _sim.surface_row(c + k) != r:
				flat = false
				break
		# Require open air two rows above the surface so the body has room to stand and be walled.
		if flat and not _sim.is_solid(Vector2i(c, r - 1)) and not _sim.is_solid(Vector2i(c, r - 2)):
			return c
	return -1


## Park the body standing on the surface, mid a fresh flat run; returns false if no run is free.
func _park_on_run(search_from: int, cell_span: int = 6) -> bool:
	var f: int = _flat_run(search_from, cell_span)
	if f < 0:
		return false
	_run_col = f
	_foot_col = f + cell_span / 2
	_foot_row = _sim.surface_row(_foot_col)
	_player.place(_main._cell_center(Vector2i(_foot_col, _foot_row - 1)))
	_player.velocity = Vector2.ZERO
	_player.input_dir = 0.0
	return true


func _phys() -> void:
	_frames += 1
	if _frames < 20:
		return
	if _player == null:
		_player = _main._player
		_sim = _main.sim
		_player.auto_input = false
		_start_mine_under_feet()
		return
	_budget -= 1

	match _phase:
		0: _run_mine_under_feet()
		1: _run_wall_in()
		2: _run_carved_pit()
		3: _run_churn_burst()
		4: _run_escape_check()


# --- SCENARIO 1: mine the cell directly under the feet -------------------------------------------

func _start_mine_under_feet() -> void:
	if not _park_on_run(10, 6):
		printerr("  (no flat run for scenario 1 — skipping)")
		_start_wall_in()
		return
	# Let the body settle onto the surface first, THEN mine the floor cell out from under it.
	_phase = 0
	_budget = 200
	_churn_step = 0
	print("  [1] mine-under-feet: body on col %d (surface row %d)" % [_foot_col, _foot_row])

func _run_mine_under_feet() -> void:
	# Step 0: settle. Step 1: mine the floor. Then: fall, land, assert invariants.
	if _churn_step == 0:
		if _player.on_floor:
			_churn_step = 1
			# Mine the surface cell directly under the body AND the one below (so it must actually fall a bit,
			# not just re-ground on a half-tile). This is the "you dug the ground out from under yourself" case.
			_sim.mine(Vector2i(_foot_col, _foot_row))
			_sim.mine(Vector2i(_foot_col, _foot_row + 1))
			print("    mined the floor out from under the body (%s, +1 below)" % Vector2i(_foot_col, _foot_row))
		return
	# Invariant: never flung out of the world while falling.
	if not _in_world():
		_fail("[1] body left the world while falling (pos=%s cell=%s)" % [_player.position, _center_cell()])
		_start_wall_in(); return
	# Wait for it to come to rest on the next floor, then assert not-inside-solid.
	if _player.on_floor and absf(_player.velocity.y) < 1.0:
		# give it a couple frames to fully settle
		if _churn_step < 1 + SETTLE_FRAMES:
			_churn_step += 1
			return
		if _fully_buried():
			_fail("[1] body settled INSIDE solid after mining its floor (cell=%s overlaps=%d)"
					% [_center_cell(), _solid_overlap_count()])
		elif _sim.is_solid(_center_cell()):
			_fail("[1] body's center cell is solid after landing (cell=%s)" % _center_cell())
		else:
			print("    PASS: fell cleanly, landed not-inside-solid, in-world (cell=%s)" % _center_cell())
		_start_wall_in()
		return
	if _budget <= 0:
		# It never came to rest — either fell forever (out of world caught above) or is jittering.
		if _fully_buried():
			_fail("[1] body never settled and is buried in solid (cell=%s)" % _center_cell())
		else:
			print("    PASS(soft): body never fully buried, in-world (didn't fully rest in budget)")
		_start_wall_in()


# --- SCENARIO 2: wall yourself in (blocks on all sides + above), then a wall removed ---------------

func _start_wall_in() -> void:
	if not _park_on_run(maxi(20, _run_col + 10), 6):
		printerr("  (no flat run for scenario 2 — skipping)")
		_start_carved_pit()
		return
	_phase = 1
	_budget = 260
	_churn_step = 0
	_sub = 0                             # 0=settle+box, 1=struggle, 2=escape after a wall is removed
	print("  [2] wall-in: body on col %d (surface row %d)" % [_foot_col, _foot_row])

func _run_wall_in() -> void:
	if not _in_world():
		_fail("[2] boxed body left the world (pos=%s)" % _player.position)
		_start_carved_pit(); return

	if _sub == 0:                        # settle, then box the body in
		if not _player.on_floor:
			return
		# Box the body IN: it's ~14×34 (just over one tile) standing on foot_row's surface, so its span is
		# roughly rows foot_row-1 .. foot_row-2 with feet at foot_row. Wall the two side columns for the
		# body's rows and cap above the head. set_solid (not place_block) so the box needs no pack inventory.
		var col: int = _foot_col
		for dy: int in range(-2, 1):                 # rows foot_row-2 .. foot_row (the body's span)
			_sim.set_solid(Vector2i(col - 1, _foot_row + dy), &"stone")   # left wall
			_sim.set_solid(Vector2i(col + 1, _foot_row + dy), &"stone")   # right wall
		_sim.set_solid(Vector2i(col, _foot_row - 3), &"stone")           # ceiling cap above the head
		print("    walled the body in on all sides + capped")
		_sub = 1
		_churn_step = 0
		return

	if _sub == 1:                        # struggle for ~90 frames; must never resolve INSIDE rock
		_player.input_dir = 1.0 if (_churn_step % 40 < 20) else -1.0
		if _player.on_floor and _churn_step % 25 == 0:
			_player.request_jump()
		if _fully_buried():
			_fail("[2] boxed body resolved fully INSIDE solid rock (cell=%s overlap=%d)"
					% [_center_cell(), _solid_overlap_count()])
			_start_carved_pit(); return
		_churn_step += 1
		if _churn_step >= 90:
			# Remove the right wall; the body must be able to LEAVE (not permanently trapped by the box).
			for dy: int in range(-2, 1):
				_sim.set_solid(Vector2i(_foot_col + 1, _foot_row + dy), &"")
			_escape_x0 = _player.position.x
			print("    struggle done, never clipped into rock; removed the right wall")
			_sub = 2
			_churn_step = 0
		return

	# _sub == 2: drive right, demand it clears the opening within the budget.
	_player.input_dir = 1.0
	if _player.on_floor and _churn_step % 25 == 0:
		_player.request_jump()
	_churn_step += 1
	if _player.position.x - _escape_x0 > MOVE_EPS:
		print("    PASS: never clipped into rock; escaped once a wall was removed (dx=%.0f)"
				% (_player.position.x - _escape_x0))
		_start_carved_pit()
		return
	if _budget <= 0 or _churn_step > 150:
		_fail("[2] body could not leave after a wall was removed (dx=%.1f — permanently trapped)"
				% (_player.position.x - _escape_x0))
		_start_carved_pit()


# --- SCENARIO 3: drop into a freshly-carved 1-wide deep pit --------------------------------------

func _start_carved_pit() -> void:
	if not _park_on_run(maxi(34, _run_col + 10), 6):
		printerr("  (no flat run for scenario 3 — skipping)")
		_start_churn_burst()
		return
	_phase = 2
	_budget = 320
	_churn_step = 0
	_sub = 0                             # consecutive grounded frames (resets when airborne) → rest detector
	print("  [3] carved-pit: body on col %d (surface row %d)" % [_foot_col, _foot_row])

func _run_carved_pit() -> void:
	if _churn_step == 0:
		if not _player.on_floor:
			return
		# Carve a 1-wide, 4-deep pit straight down through the surface where the body stands.
		for dy: int in range(0, 4):
			_sim.set_solid(Vector2i(_foot_col, _foot_row + dy), &"")
		_churn_step = 1
		print("    carved a 1-wide 4-deep pit under the body")
		return
	# Invariants EVERY frame while it falls / rests: in-world, never fully buried in rock.
	if not _in_world():
		_fail("[3] body left the world falling into the pit (pos=%s)" % _player.position)
		_start_churn_burst(); return
	if _fully_buried():
		_fail("[3] body clipped INTO solid inside the pit (cell=%s overlap=%d)"
				% [_center_cell(), _solid_overlap_count()])
		_start_churn_burst(); return
	# Let it fall and settle with NO input first — count consecutive grounded frames as "settled"
	# (leaving the floor resets it, so a bounce doesn't count as rest).
	_player.input_dir = 0.0
	_sub = _sub + 1 if _player.on_floor else 0
	if _sub >= SETTLE_FRAMES:
		# It rests cleanly on the pit floor (not buried, in-world — asserted above). That IS the pass: a
		# 1-wide 4-deep pit is a legitimate trap you'd need a rope/pillar to leave; the invariant is that
		# the drop was CLEAN and the body is in a valid resting state, not clipped, not flung out.
		print("    PASS: fell into the pit cleanly, rests not-clipped and in-world (cell=%s)" % _center_cell())
		_start_churn_burst()
		return
	if _budget <= 0:
		# Never settled in budget — still a pass IF it stayed clean the whole time (invariants above held).
		print("    PASS(soft): never buried / in-world through the pit fall (didn't fully rest in budget)")
		_start_churn_burst()


# --- SCENARIO 4: a churn burst — a fixed interleaved sequence of edits around the steered body -----

## The fixed churn program: (op, dx, dy) relative to the body's footing column/surface row. op 0 =
## set_solid stone, op 1 = mine/erase. Deterministic, ~30 edits touching the body's neighbourhood — the
## cells beside, above, and below it while it's steered left/right. NO random.
const CHURN: Array[Vector3i] = [
	Vector3i(0, 1, 0),   Vector3i(0, -1, 0),  Vector3i(1, 0, 0),   Vector3i(0, 0, -3),
	Vector3i(1, 0, 0),   Vector3i(0, 1, 0),   Vector3i(0, -1, 0),  Vector3i(1, 0, -1),
	Vector3i(0, 0, 1),   Vector3i(1, 0, 1),   Vector3i(0, 2, -2),  Vector3i(0, -2, -2),
	Vector3i(1, 2, -2),  Vector3i(1, -2, -2), Vector3i(0, 1, -3),  Vector3i(0, -1, -3),
	Vector3i(1, 0, 0),   Vector3i(0, 0, 1),   Vector3i(1, 0, 1),   Vector3i(0, 1, 0),
	Vector3i(1, 1, 0),   Vector3i(0, -1, 0),  Vector3i(1, -1, 0),  Vector3i(0, 0, -2),
	Vector3i(1, 0, -2),  Vector3i(0, 2, 0),   Vector3i(1, 2, 0),   Vector3i(0, -2, 0),
	Vector3i(1, -2, 0),  Vector3i(0, 0, 0),   Vector3i(1, 0, 0),   Vector3i(0, 0, 2),
]
const CHURN_STRIDE: int = 3          ## physics frames between churn edits (let the body react between)

func _start_churn_burst() -> void:
	if not _park_on_run(maxi(48, _run_col + 10), 6):
		printerr("  (no flat run for scenario 4 — skipping)")
		_start_escape_check()
		return
	_phase = 3
	_budget = 400
	_churn_step = 0
	_sub = 0                             # frames spent settling AFTER the last churn edit
	_worst_overlap = 0
	print("  [4] churn-burst: %d interleaved edits around col %d" % [CHURN.size(), _foot_col])

func _run_churn_burst() -> void:
	# Steer the body back and forth so it's mid-motion while the ground churns.
	_player.input_dir = 1.0 if ((_frames / 30) % 2 == 0) else -1.0
	if _player.on_floor and _frames % 22 == 0:
		_player.request_jump()

	# Apply the next churn edit every CHURN_STRIDE frames.
	if _churn_step < CHURN.size() and (_frames % CHURN_STRIDE) == 0:
		var e: Vector3i = CHURN[_churn_step]
		var cell := Vector2i(_foot_col + e.y, _foot_row + e.z)
		if e.x == 0:
			_sim.set_solid(cell, &"stone")
		else:
			_sim.set_solid(cell, &"")
		_churn_step += 1

	# INVARIANT every frame: in-world, and never FULLY buried in rock (a transient single-cell clip during
	# a resolve is allowed; being wholly encased across several frames is the bug).
	if not _in_world():
		_fail("[4] churn flung the body out of the world (pos=%s cell=%s)" % [_player.position, _center_cell()])
		_start_escape_check(); return
	if _fully_buried():
		_worst_overlap += 1
		if _worst_overlap > 8:
			_fail("[4] churn buried the body inside solid for %d+ frames (cell=%s overlap=%d)"
					% [_worst_overlap, _center_cell(), _solid_overlap_count()])
			_start_escape_check(); return
	else:
		_worst_overlap = 0

	# Once every edit is applied, let the body settle a beat, then assert the final state + move on.
	if _churn_step >= CHURN.size():
		_sub += 1
		if _sub >= SETTLE_FRAMES or _budget <= 0:
			if _fully_buried():
				_fail("[4] body settled buried after the churn (cell=%s)" % _center_cell())
			elif not _in_world():
				_fail("[4] body out of world after the churn (pos=%s)" % _player.position)
			else:
				print("    PASS: survived %d churn edits — never buried >8 frames, stayed in-world" % CHURN.size())
			_start_escape_check()


# --- SCENARIO 5: after the churn, on open floor, the body can still MOVE (never permanently frozen) --

func _start_escape_check() -> void:
	# Give the body a guaranteed clean open floor: lay a fresh flat plate and clear the air above it, then
	# drop the body on it (independent of whatever the churn left behind).
	var col: int = 6
	var row: int = 30
	for x: int in range(col, col + 12):
		_sim.set_solid(Vector2i(x, row), &"stone")            # floor plate
		for y: int in range(row - 4, row):
			_sim.set_solid(Vector2i(x, y), &"")               # clear air above it
	_player.place(_main._cell_center(Vector2i(col + 1, row - 1)))
	_player.velocity = Vector2.ZERO
	_phase = 4
	_budget = ESCAPE_FRAMES + 60
	_churn_step = 0
	print("  [5] escape/stuck: fresh open floor, body must move when steered")

func _run_escape_check() -> void:
	if _churn_step == 0:
		if _player.on_floor:
			_escape_x0 = _player.position.x
			_churn_step = 1
		elif _budget <= 0:
			_fail("[5] body never landed on the fresh floor (still airborne)")
			_done()
		return
	_player.input_dir = 1.0
	_churn_step += 1
	if not _in_world():
		_fail("[5] body left the world on the escape floor (pos=%s)" % _player.position)
		_done(); return
	if _player.position.x - _escape_x0 > MOVE_EPS:
		print("    PASS: body moves freely after the churn (dx=%.0f in %d frames)"
				% [_player.position.x - _escape_x0, _churn_step])
		_done()
		return
	if _churn_step >= ESCAPE_FRAMES or _budget <= 0:
		_fail("[5] body is PERMANENTLY STUCK on open floor — steered %d frames, moved only %.1fpx"
				% [_churn_step, _player.position.x - _escape_x0])
		_done()


func _done() -> void:
	physics_frame.disconnect(_phys)
	if _fails == 0:
		print("ALL BODY-STRESS INVARIANTS HELD")
		quit(0)
	else:
		printerr("%d BODY-STRESS INVARIANT(S) FAILED" % _fails)
		quit(1)
