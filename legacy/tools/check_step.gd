extends SceneTree

## The MISSING traversal component: asserts the body can climb a ≤1-tile rise by
## WALKING — with jumping DISABLED, so nothing masks the jam (check_walk's stuck-jump hops obstacles and
## hides exactly these bugs). Two real-world cases the heightmap slope-follow can't cover:
##   A. climb OUT of a dug 1-wide pit you fell into (a valley → ramp_dir 0)
##   B. walk OVER one of your own 1-tile machines
##   C. walk THROUGH a tree trunk (wood is Terraria-style walk-through; guards the taller body vs. a
##      2-tall trunk that would otherwise wall it on a surface path)
## HEADED:  /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_step.gd

const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _player: Player
var _sim: FactorySim
var _frames: int = 0
var _phase: int = 0
var _budget: int = 0
var _fails: int = 0

## HOW MANY OF THE THREE TRAVERSALS WERE ACTUALLY POSED, and which were not.
##
## Every setup below needs a flat run to build its subject on, and every one of them used to answer "no
## flat run" by printing a line to stderr and moving on. None recorded a failure, and `_done()` prints
## ALL STEP-UP TRAVERSALS PASS whenever `_fails == 0` -- so a world with no 5-wide flat run at the searched
## offsets produced a green over nothing. Measured, not argued: a copy with `_flat_run` forced to return -1
## printed "skipping A", "skipping B" and then ALL STEP-UP TRAVERSALS PASS, and exited 0. It skipped
## straight from B to `_done()`, so C was never even announced.
##
## The sweep was protected by the assertion floor -- three pass lines, and a full skip prints none -- but
## the floor only judges on a full configured sweep, so a standalone run of this layer reported success.
## The refusal belongs where the layer can make it, which is here.
const TRAVERSALS: int = 3
var _posed: int = 0
var _missed: PackedStringArray = PackedStringArray()
var _pit := Vector2i(-1, -1)
var _mach_col: int = -1
var _tree_col: int = -1


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== step-up traversal (no jumping) ==")
	physics_frame.connect(_phys)


## Leftmost column of a flat run of `length` columns clear of the world edges, or -1.
func _flat_run(start: int, length: int) -> int:
	for c: int in range(start, FactorySim.GRID_COLS - length - 1):
		var r: int = _sim.surface_row(c)
		if r >= FactorySim.GRID_ROWS - 3:
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
		_setup_pit()
		return
	_player.input_dir = 1.0          # walk RIGHT, and NEVER request_jump — pure walking
	_budget -= 1

	if _phase == 0:                  # A: escape the pit
		if _player.position.x > float((_pit.x + 2) * 32):
			print("  PASS: climbed OUT of a dug 1-pit by walking (x=%.0f)" % _player.position.x)
			_setup_machine()
		elif _budget <= 0:
			printerr("  FAIL: stuck in the pit — walked to x=%.0f, never cleared col %d"
				% [_player.position.x, _pit.x + 1])
			_fails += 1
			_setup_machine()
	elif _phase == 1:                # B: walk over a machine
		if _player.position.x > float((_mach_col + 2) * 32):
			print("  PASS: walked OVER a 1-tile machine (x=%.0f)" % _player.position.x)
			_setup_tree()
		elif _budget <= 0:
			printerr("  FAIL: stuck against the machine — walked to x=%.0f, never passed col %d"
				% [_player.position.x, _mach_col])
			_fails += 1
			_setup_tree()
	elif _phase == 2:                # C: walk THROUGH a tree trunk (wood is walk-through)
		if _player.position.x > float((_tree_col + 2) * 32):
			print("  PASS: walked THROUGH a 2-tall tree trunk (x=%.0f)" % _player.position.x)
			_done()
		elif _budget <= 0:
			printerr("  FAIL: walled by the tree trunk — walked to x=%.0f, never passed col %d (wood must be walk-through)"
				% [_player.position.x, _tree_col])
			_fails += 1
			_done()


## A: dig a 1-wide pit on a flat run and drop the body INTO it, then walk toward the far wall.
func _setup_pit() -> void:
	# Search for a clean flat run (the centred plateau) so the pit is dug in clear terrain — a pit
	# under a machine is (correctly) unclimbable, which would be a bogus failure.
	var f: int = _flat_run(12, 5)
	if f < 0:
		printerr("  (no flat run found to test the pit — skipping A)")
		_missed.append("A (the 1-pit)")
		_setup_machine()
		return
	var r: int = _sim.surface_row(f)
	_pit = Vector2i(f + 2, r)
	_sim.set_solid(_pit, &"")                                   # carve the 1-wide, 1-deep hole
	_player.position = Vector2(float(_pit.x * 32 + 16), float((r + 1) * 32) - Player.HEIGHT * 0.5)
	_player.velocity = Vector2.ZERO
	_phase = 0
	_budget = 150
	print("  dug a 1-pit at %s; body dropped in" % _pit)
	_posed += 1


## B: place a machine on a fresh flat run; the body walks into it from the left.
func _setup_machine() -> void:
	var g: int = _flat_run(maxi(4, _pit.x + 4), 5)
	if g < 0:
		printerr("  (no flat run found to test the machine — skipping B)")
		_missed.append("B (the machine)")
		_done()
		return
	var r: int = _sim.surface_row(g)
	_mach_col = g + 2
	_sim.place_machine(load("res://src/data/machines/processor.tres"), Vector2i(_mach_col, r - 1))
	_player.position = Vector2(float(g * 32 + 16), float(r * 32) - Player.HEIGHT * 0.5)
	_player.velocity = Vector2.ZERO
	_phase = 1
	_budget = 220
	print("  placed a machine at col %d; body left of it" % _mach_col)
	_posed += 1


## C: plant a 2-tall WOOD trunk (rows r-1, r-2) on a fresh flat run — a wall taller than the body — and
## walk into it from the left. A blocking trunk would trap the taller body; walk-through wood lets it pass.
func _setup_tree() -> void:
	var g: int = _flat_run(maxi(4, _mach_col + 4), 5)
	if g < 0:
		printerr("  (no flat run found to test the tree — skipping C)")
		_missed.append("C (the wood trunk)")
		_done()
		return
	var r: int = _sim.surface_row(g)
	_tree_col = g + 2
	_sim.set_solid(Vector2i(_tree_col, r - 1), &"wood")         # trunk base (at head height for the body)
	_sim.set_solid(Vector2i(_tree_col, r - 2), &"wood")         # trunk top → a 2-tall wall if wood blocked
	_player.position = Vector2(float(g * 32 + 16), float(r * 32) - Player.HEIGHT * 0.5)
	_player.velocity = Vector2.ZERO
	_phase = 2
	_budget = 220
	print("  planted a 2-tall wood trunk at col %d; body left of it" % _tree_col)
	_posed += 1


func _done() -> void:
	physics_frame.disconnect(_phys)
	# A TRAVERSAL THAT WAS NEVER POSED IS NOT ONE THAT PASSED. This is checked before `_fails`, because
	# `_fails == 0` is what a run that tested nothing reports.
	if _posed < TRAVERSALS:
		# THE COUNT AND THE LIST DO NOT HAVE TO AGREE, and saying so is cheaper than a reader deciding one
		# of them is wrong. A skip jumps straight to this verdict, so the traversals after it never run and
		# never announce a reason: the first draft printed "3 of 3 were never posed: A, B" and read like an
		# off-by-one.
		var tail: String = "" if _missed.size() == TRAVERSALS - _posed \
			else " — the rest were never reached, because a skip jumps straight here"
		printerr("  %d of %d traversals were never posed, so this run judged nothing about them: %s%s"
			% [TRAVERSALS - _posed, TRAVERSALS,
				", ".join(_missed) if not _missed.is_empty() else "none announced a reason", tail])
		printerr("%d step-up traversal(s) FAILED, and %d were not attempted" % [_fails, TRAVERSALS - _posed])
		quit(1)
		return
	if _fails == 0:
		print("ALL STEP-UP TRAVERSALS PASS (%d traversals posed)" % _posed)
		quit(0)
	else:
		printerr("%d step-up traversal(s) FAILED" % _fails)
		quit(1)
