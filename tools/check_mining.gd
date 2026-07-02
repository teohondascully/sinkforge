extends SceneTree

## Mining LINE-OF-SIGHT (the "carve the exposed face" rule): you can't dig THROUGH solid rock to a block
## behind it — a block is mineable only if a clear line reaches it from the body. Asserts the exact bug the
## user reported (mining 3,0 while 1,0 and 2,0 are still wall) is now impossible, and that carving one layer
## at a time exposes the next. HEADED:
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/check_mining.gd

const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _sim: FactorySim
var _frames: int = 0
var _fails: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== mining line-of-sight ==")
	process_frame.connect(_on_frame)


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_fails += 1
		printerr("  FAIL: %s" % label)


func _on_frame() -> void:
	_frames += 1
	if _frames < 3:
		return
	process_frame.disconnect(_on_frame)
	_sim = _main.sim
	_run()
	if _fails == 0:
		print("ALL MINING-LOS CHECKS PASS")
		quit(0)
	else:
		printerr("%d MINING-LOS FAILURE(S)" % _fails)
		quit(1)


func _run() -> void:
	var surf: int = MainView.SURFACE
	var row: int = surf + 2
	# Carve an open chamber, then a SOLID horizontal wall the body digs into from the left.
	for x: int in range(20, 40):
		for y: int in range(row - 2, row + 3):
			_sim.set_solid(Vector2i(x, y), &"")
	for x: int in range(30, 40):                                   # a solid stone wall from col 30 rightward
		_sim.set_solid(Vector2i(x, row), &"stone")
	# Stand the body just LEFT of the wall face, at the wall's row (in the open pocket at col 29).
	_main._player.position = _main._cell_center(Vector2i(29, row))

	var face := Vector2i(30, row)                                  # the exposed wall face (touches the pocket)
	var behind1 := Vector2i(31, row)                              # one block behind the face — hidden by (30,row)
	var behind2 := Vector2i(32, row)
	_check(_main._mineable(face), "the exposed wall FACE is mineable")
	_check(not _main._mineable(behind1), "a block BEHIND the face is NOT mineable (can't dig through rock)")
	_check(not _main._mineable(behind2), "a block two-deep behind the wall is NOT mineable")
	# The reported bug, explicitly: (behind) is within reach radius but blocked by line-of-sight.
	_check(_main._can_reach(behind1) and not _main._mineable(behind1),
		"the hidden block is IN REACH yet blocked by line-of-sight (the exact reported bug)")

	# Carve the face → the pocket grows → the NEXT layer becomes exposed.
	_check(_main.try_mine(face), "mining the face succeeds")
	_check(_main._mineable(behind1), "after carving the face, the next layer IS now exposed + mineable")
	_check(not _main._mineable(behind2), "the layer after that is still hidden (carve one at a time)")

	# Straight DOWN a shaft: body on a floor digs the cell below, then the next — never skipping a solid.
	var col: int = 24
	for y: int in range(row + 1, row + 6):                         # solid ground below the body's feet
		_sim.set_solid(Vector2i(col, y), &"stone")
	_main._player.position = _main._cell_center(Vector2i(col, row))
	var d1 := Vector2i(col, row + 1)
	var d2 := Vector2i(col, row + 2)
	_check(_main._mineable(d1), "the cell directly below the body is mineable")
	_check(not _main._mineable(d2), "the cell two-below (through solid) is NOT mineable")
	_check(_main.try_mine(d1), "mining straight down one cell succeeds")
	_check(_main._mineable(d2), "after digging one down, the next-down IS exposed (shaft deepens one at a time)")

	# REGRESSION — the "cracks loop forever without breaking" bug: the mine ANIMATION gate (_update_mining's
	# `holding`) is now the SAME _mineable predicate try_mine enforces. So the effective aim can never be a
	# cell that would spider a full charge yet refuse to break. Point the cursor PAST a fresh wall and assert
	# the hold-gate never reads a LOS-blocked block as mineable (the old gate checked reach only → the loop).
	var wcol: int = 44
	for y: int in range(row - 2, row + 3):
		_sim.set_solid(Vector2i(wcol - 1, y), &"")            # a pocket to stand in
	for x: int in range(wcol, wcol + 4):
		_sim.set_solid(Vector2i(x, row), &"stone")            # a fresh solid wall
	_main._player.position = _main._cell_center(Vector2i(wcol - 1, row))
	var buried := Vector2i(wcol + 2, row)                     # two behind the wall face
	var eff: Vector2i = _main._effective_aim(_main._cell_center(buried))
	if _sim.is_solid(eff) and not _main._line_of_sight_clear(_main._body_cell(), eff):
		_check(not _main._mineable(eff),
			"a LOS-blocked block is never 'mineable' → the hold-gate won't charge it (no phantom crack loop)")
	else:
		_check(_main._mineable(eff),
			"the aim snapped to an exposed face → you dig the PATH toward the buried block (no phantom)")
