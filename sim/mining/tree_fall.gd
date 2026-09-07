class_name TreeFall
extends RefCounted

## THE CROWN FALLS WITH THE TRUNK (T034 taken provisionally, D0438). Stranger 10 cut the tutorial tree's
## sixteen trunk cells for a wood block and walked away from a canopy of leaves floating over nothing
## (frame 33 of run 10): the tree pass plants leaves as terrain cells, and a terrain cell has no notion of
## what holds it up. This is that notion, for leaves only. After a wood cell breaks, every leaf near the
## cut that no longer connects to any wood -- through other leaves, four-neighbour -- is queued, nearest
## the cut first, and crumbles at `CRUMBLE_PER_TICK` cells a tick: a collapse the eye can follow, not a
## blink. Leaves that still touch a standing trunk, this tree's or a neighbour's, stay.
##
## Nothing is paid for a crumbled leaf: the cut trunk paid its wood, a leaf cut by hand pays as it
## always did, and a crown's forty cells raining leaves into the pack would be a payout for walking away.
## The queue is transient like `MineHold` that owns it: a save mid-crumble (a fraction of a second) leaves
## the rest standing, which is the pre-D0438 world and not a corruption.
##
## Reverse: drop the two calls in `MineHold.step`.

const BOX: int = 32                 ## cells either side of the cut the search covers: 8 m, two crowns' span
const CRUMBLE_PER_TICK: int = 2
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var _queue: Array[Vector2i] = []
var _queued: Dictionary = {}        ## cell -> true while in the queue: a blow's disc breaks several wood cells
var crumbled_this_tick: Array[Vector2i] = []


## Queue the leaves each broken wood cell left unsupported, each once.
func after_break(grid: TileGrid, cells: Array[Vector2i], materials: Array[StringName]) -> void:
	for i: int in cells.size():
		if materials[i] != &"wood":
			continue
		for c: Vector2i in unsupported_leaves(grid, cells[i]):
			if not _queued.has(c):
				_queued[c] = true
				_queue.append(c)


## One tick of the collapse: up to CRUMBLE_PER_TICK queued cells that are still leaves are excavated.
func crumble(grid: TileGrid) -> void:
	crumbled_this_tick.clear()
	while crumbled_this_tick.size() < CRUMBLE_PER_TICK and not _queue.is_empty():
		var c: Vector2i = _queue.pop_front()
		_queued.erase(c)
		if grid.in_bounds(c) and grid.get_material(c) == &"leaves":
			grid.excavate(c)
			crumbled_this_tick.append(c)


func pending() -> int:
	return _queue.size()


## The leaves within BOX of `cut` that no chain of leaves connects to a grounded wood cell, nearest the cut
## first (Manhattan, then row, then column: a total order, so two runs crumble in the same sequence).
static func unsupported_leaves(grid: TileGrid, cut: Vector2i) -> Array[Vector2i]:
	var leaves: Dictionary = {}
	var wood: Dictionary = {}
	for dy: int in range(-BOX, BOX + 1):
		for dx: int in range(-BOX, BOX + 1):
			var c: Vector2i = cut + Vector2i(dx, dy)
			if not grid.in_bounds(c):
				continue
			var m: StringName = grid.get_material(c)
			if m == &"leaves":
				leaves[c] = true
			elif m == &"wood":
				wood[c] = true
	var supported: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for w: Vector2i in grounded_wood(grid, wood):
		_reach(w, leaves, supported, frontier)
	while not frontier.is_empty():
		_reach(frontier.pop_back(), leaves, supported, frontier)
	var out: Array[Vector2i] = []
	for c: Vector2i in leaves:
		if not supported.has(c):
			out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = absi(a.x - cut.x) + absi(a.y - cut.y)
		var db: int = absi(b.x - cut.x) + absi(b.y - cut.y)
		return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
	return out


## The wood cells of `wood` (cell -> true) that reach, through wood, a solid cell that is neither wood
## nor leaves: a trunk on the ground, not a stub in the air.
static func grounded_wood(grid: TileGrid, wood: Dictionary) -> Array[Vector2i]:
	var grounded: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for w: Vector2i in wood:
		for d: Vector2i in DIRS:
			var m: StringName = grid.get_material(w + d)
			if m != &"" and m != &"wood" and m != &"leaves":
				grounded[w] = true
				frontier.append(w)
				break
	while not frontier.is_empty():
		_reach(frontier.pop_back(), wood, grounded, frontier)
	var out: Array[Vector2i] = []
	for w: Vector2i in grounded:
		out.append(w)
	return out


static func _reach(from: Vector2i, leaves: Dictionary, supported: Dictionary, frontier: Array[Vector2i]) -> void:
	for d: Vector2i in DIRS:
		var n: Vector2i = from + d
		if leaves.has(n) and not supported.has(n):
			supported[n] = true
			frontier.append(n)
