extends SceneTree

## IS THERE A WAY DOWN, OR IS THERE ONLY DIGGING?
##
## The pacing timeline put the session's longest silence in one place: the moment first automation lands
## and the player turns around and heads for the deep. What they do then is pick a column and hold the
## mouse button, for as long as it takes, and that is the entire second act. It is not a route, it is a
## chore performed at a fixed rate — which is why the descent's own timeline came out a metronome even
## after the earth was given things to find in it.
##
## The world already contains the answer. The generator carves rifts — narrow chasms that fall THROUGH the
## layer stack — precisely so the underground has vertical structure, and the grapple exists precisely so a
## fall line is something a body can commit to. If those two facts met, the descent would be a DECISION:
## dig (slow, safe, yours) or find the open way and ride it (fast, committed, the world's). A choice is the
## difference between traversal and a progress bar.
##
## So this measures the geometry that decision needs, before anything is built on top of it:
##
##   THE REACH   — flood the open space from the surface downward and find the deepest row a body could get
##                 to WITHOUT breaking a single block. If that number is barely under the surface, no route
##                 exists at any skill level and the descent can only ever be digging.
##   THE MOUTHS  — how many separate places on the surface that open space can be ENTERED from. A route
##                 nobody can find the start of is not a route.
##   THE DROP    — the tallest single column of open air anywhere below the surface: the rift the grapple
##                 was built for, and the thing worth going to look for.
##
## Measured on the real generated world, headlessly, with no play in it — this is a question about the
## place, not about the player.
##
##   godot --headless --path . --script res://tools/check_descent.gd

const SCENE: String = "res://scenes/main.tscn"
const SETTLE: int = 30

## A body is HEAD_ROOM cells tall and needs that much clear air to stand in a cell; a flood that ignored it
## would report cracks a player can never enter as open route.
const HEAD_ROOM: int = 2

## What the geometry has to be worth, for the choice to exist at all. Deliberately modest: this is asking
## whether a route is POSSIBLE, not whether it is convenient.
const REACH_ROWS: int = 30           ## rows below the surface the open space must let a body reach
const MOUTHS_FLOOR: int = 3          ## ...from at least this many separate places on the surface
const DROP_ROWS: int = 12            ## ...and somewhere there must be a fall this tall to commit to

var _fails: int = 0


func _initialize() -> void:
	print("== is there a way down ==")
	MainView.dev_start = false
	await _run()
	if _fails == 0:
		print("check_descent: PASS — the world offers a way down that is not a pickaxe")
		quit(0)
	else:
		print("check_descent: FAIL (%d)" % _fails)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sim: FactorySim = main.sim

	# --- THE MOUTHS: every surface column whose air a body could actually stand in and walk down from.
	var frontier: Array[Vector2i] = []
	var seen: Dictionary = {}
	var mouths: int = 0
	for col: int in FactorySim.GRID_COLS:
		var top: int = sim.surface_row(col)
		var cell := Vector2i(col, top - 1)
		if not _standable(sim, cell):
			continue
		mouths += 1
		seen[cell] = true
		frontier.append(cell)

	# --- THE REACH: flood the standable open space and see how deep it gets — but flood it the way a BODY
	#     travels, not the way water does. A four-connected flood answers "is this air connected", and the
	#     first version of this layer asked exactly that, got sixty-three rows, and was wrong: it walked the
	#     body up a nine-cell wall one cell at a time. Air can do that. A miner with a 1.3-cell step and a
	#     2.3-cell jump cannot, and the played descent parked in a pocket the flood had called a corridor.
	#     So the moves here are the moves the controller actually has, and nothing else.
	var deepest: int = -1
	var surface_datum: int = sim.surface_row(FactorySim.GRID_COLS / 2)
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_back()
		deepest = maxi(deepest, at.y)
		for n: Vector2i in _moves(sim, at):
			if seen.has(n) or not sim.in_bounds(n):
				continue
			seen[n] = true
			frontier.append(n)
	var reach: int = deepest - surface_datum

	# --- THE DROP: the tallest unbroken column of open air below the surface anywhere in the world.
	var drop: int = 0
	var drop_at := Vector2i(-1, -1)
	for col: int in FactorySim.GRID_COLS:
		var run: int = 0
		for row: int in range(sim.surface_row(col) + 1, FactorySim.GRID_ROWS):
			if sim.is_solid(Vector2i(col, row)):
				run = 0
				continue
			run += 1
			if run > drop:
				drop = run
				drop_at = Vector2i(col, row)

	print("  %d ways in from the surface; the open space reaches %d rows down (row %d)"
		% [mouths, reach, deepest])
	print("  the longest fall in the world is %d rows, at column %d" % [drop, drop_at.x])
	print("  %d standable cells of connected open space below the sky" % seen.size())

	_check(mouths >= MOUTHS_FLOOR,
		"the way down can be FOUND (%d mouths, floor %d)" % [mouths, MOUTHS_FLOOR])
	_check(reach >= REACH_ROWS,
		"...and it goes somewhere (%d rows below the surface, floor %d)" % [reach, REACH_ROWS])
	_check(drop >= DROP_ROWS,
		"...and somewhere there is a fall worth committing to (%d rows, floor %d)" % [drop, DROP_ROWS])

	main.queue_free()
	await physics_frame


## THE BODY'S MOVES from a cell it is standing in: step aside, step or hop UP a wall it can clear, and
## fall off anything. Every edge here corresponds to something the player controller can do; going up is
## the only expensive direction, which is exactly why a descent can be a one-way trip.
const STEP_UP: int = 1               ## cells the slope-follow glides up without a jump (MAX_STEP 1.3)
const JUMP_UP: int = 2               ## ...and cells a full jump clears (apex 74px over a 32px cell)

func _moves(sim: FactorySim, at: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dx: int in [1, -1]:
		# Sideways and upward, nearest first: a step, then a jump.
		for up: int in range(0, JUMP_UP + 1):
			var side := Vector2i(at.x + dx, at.y - up)
			if not sim.in_bounds(side) or not _standable(sim, side):
				continue
			out.append(side)
			break                                    # the lowest opening on that side is the one you take
		# ...and off the edge: fall to the first floor under the neighbouring column.
		var over := Vector2i(at.x + dx, at.y)
		if sim.in_bounds(over) and _standable(sim, over):
			out.append(_ground_under(sim, over))
	out.append(_ground_under(sim, at))               # the floor may have been mined out from under you
	return out


## The cell a body dropped at `from` comes to rest in — straight down until something holds it.
func _ground_under(sim: FactorySim, from: Vector2i) -> Vector2i:
	var at: Vector2i = from
	while at.y + 1 < FactorySim.GRID_ROWS and not sim.is_solid(Vector2i(at.x, at.y + 1)):
		at.y += 1
	return at


## Whether a body could occupy this cell: it and the cells above it, to head height, are all open.
func _standable(sim: FactorySim, cell: Vector2i) -> bool:
	for dy: int in HEAD_ROOM:
		var c := Vector2i(cell.x, cell.y - dy)
		if not sim.in_bounds(c) or sim.is_solid(c):
			return false
	return true


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		_fails += 1
		printerr("  FAIL: %s" % msg)
