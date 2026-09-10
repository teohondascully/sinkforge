class_name Slump
extends RefCounted

## LOOSE MATERIAL FALLS (D0562). Until now the earth was scenery: `docs/GDD.md` §1 calls the terrain the
## factory and §13 puts "holes: gravity routing. free. dug, not built" at position two of the automation
## chain, above every machine -- and that step was unbuildable, because nothing in the world moved unless
## a verb moved it. An Opus playthrough on 2026-09-10 cut forty-two cells out from under a standing mass
## and the mass hung there; `docs/NORTH_STAR.md` §2.1 is the table of what the world did in reply to
## everything a player can do to it, and every row of it said "nothing".
##
## This is the smallest change that makes the world answer: a cell whose material is `loose` and whose
## support is gone moves down one cell a step, and slides diagonally when it cannot fall straight, which
## is an angle of repose rather than a column standing on a corner. Clay is the only loose material today
## (`data/materials/clay.yaml`) and it is the whole tutorial world's rock, so the change is felt
## immediately without touching hardrock, deepstone or any ore.
##
## SHAPE LIFTED FROM `TreeFall` (D0438), DELIBERATELY. Same seam (`MineHold.step` calls `settle` before
## the tick's aim and `after_break` after a blow), same transient queue, same reversal: drop the two calls
## in `MineHold.step` and the world is scenery again. It is not lifted from `WaterFlow`, whose active set
## is seeded off `TileGrid.take_solidity_changes` -- that log has one consumer and draining it twice would
## give each half the other's cells.
##
## WHAT THIS DELIBERATELY DOES NOT DO, each a real limit and not an oversight:
##
##  - **Loose material never falls into water.** A wet target is treated as occupied. `WaterPlane` has a
##    `displace` for "rock arrived", but it removes the water rather than moving it, and `sim/fluid`'s
##    module contract says every conservation violation must live in one named, gated function. Silt
##    settling on an aquifer's surface is a worse answer than a wrong one; this is a rest, not a physics
##    claim, and it keeps the water invariants exactly true.
##  - **Nothing is paid for a slumped cell.** The material moves; it does not enter the pack. A collapse
##    that paid out would be a payout for standing still.
##  - **Only a hand blow seeds the queue.** A drill boring and a machine placed do not (yet) wake the
##    cells around them. That is the same seam `TreeFall` has had since D0438 and the same one-line fix.
##  - **The queue is transient, like `TreeFall`'s.** A save taken mid-collapse leaves the rest standing
##    until something nearby is next cut. A held column is a wrong-looking frame, not a corrupt world:
##    every cell is still exactly one material in exactly one place.
##
## DETERMINISM. No RNG, no float, no tick index. The queue is FIFO and every cell entering it does so in a
## fixed order; the left/right choice is `(c.x + c.y) & 1`, which is a property of the cell and not of
## history, so it cannot drift between a run and its replay. `tests/test_slump.gd` pins the whole
## automaton against a fuzz of ten thousand steps and asserts that no step ever changes the number of
## loose cells in the world.

## Cells moved per step. `TreeFall` crumbles 2 ("a collapse the eye can follow, not a blink") and the same
## reasoning applies with more force here, because a slump is the world explaining itself: a blink teaches
## nothing. Four is a judgment call between that and a shelf that takes visible seconds to come down --
## a cell moves 4 px a step, so a lone falling cell descends at 240 px/s against the body's 150 px/s run.
const SETTLE_PER_TICK: int = 4

## A queue this long is a collapse nobody is watching any more; further cells are dropped rather than
## grown without bound. `TileGrid.SOLIDITY_LOG_CAP` is 4096 for the same reason.
const QUEUE_CAP: int = 4096

const DOWN := Vector2i(0, 1)
const UP := Vector2i(0, -1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)

var _queue: Array[Vector2i] = []
var _queued: Dictionary = {}                 ## cell -> true while queued: one blow breaks several cells
var _next: Array[Vector2i] = []              ## woken FOR THE NEXT step, never this one (see `settle`)
var moved_this_tick: Array[Vector2i] = []    ## the cells that EMPTIED this step, for the view's dust
## What moved, for the dust's colour. ONE material a step, exactly as `Mining.broke_material` is one a
## tick: clay is the only loose material, so a step cannot mix two today. If a second material is ever
## flagged loose, this becomes the LAST one moved rather than a lie -- the dust is a colour, not a claim,
## and the alternative is a per-cell allocation on the hot path for a shade nobody can name.
var moved_material: StringName = &""


## Wake the cells a blow left unsupported: the cell above each break and its two lateral-up neighbours,
## which are the three that a removed cell can stop holding up. Non-loose cells are queued too and
## filtered in `settle`, so this needs no material lookup and stays correct if `loose` moves to a new
## material tomorrow.
func after_break(grid: TileGrid, cells: Array[Vector2i]) -> void:
	for c: Vector2i in cells:
		_wake(grid, c + UP)
		_wake(grid, c + UP + LEFT)
		_wake(grid, c + UP + RIGHT)


## One step of the collapse: up to `SETTLE_PER_TICK` queued cells that can still move, do. Cells that
## cannot move are dropped from the queue -- they are at rest, and something must break near them to wake
## them again.
##
## A CELL MOVES AT MOST ONE CELL PER STEP, which is the whole reason `_next` exists. The destination of a
## move is woken for the FOLLOWING step, not this one: queued into `_queue` directly it would be popped
## again a few iterations later and fall again, and a single grain would descend `SETTLE_PER_TICK` cells
## in one frame while the budget said four cells had moved. The first version of this file did exactly
## that and `tests/test_slump.gd`'s "one step moves the cell exactly one cell down" is what caught it.
func settle(grid: TileGrid, water: WaterPlane) -> void:
	moved_this_tick.clear()
	var looked: int = 0
	while moved_this_tick.size() < SETTLE_PER_TICK and not _queue.is_empty() and looked < QUEUE_CAP:
		looked += 1
		var c: Vector2i = _queue.pop_front()
		_queued.erase(c)
		var to: Vector2i = target(grid, water, c)
		if to == c:
			continue
		_move(grid, c, to)
		moved_this_tick.append(c)
	for c: Vector2i in _next:
		_wake(grid, c)
	_next.clear()


func pending() -> int:
	return _queue.size()


## Where the loose cell at `c` goes this step, or `c` itself when it is at rest.
##
## STRAIGHT DOWN FIRST, then a diagonal slide -- but ONLY WHEN THE CELL BELOW IS ITSELF LOOSE. That
## clause is the angle of repose and it is the whole rule, so it is worth stating why it is not just
## "slide whenever you can". Without it, a grain slides off any ledge it finds, so a heap dribbles off
## the edge of the world and a single cell will not sit on a one-cell shelf; WITH it, a grain resting on
## bedrock stays put and only a grain resting on other grains rolls, which is what a pile of earth
## actually does. The first version of this file omitted it, and the consequence was exactly the one
## `docs/NORTH_STAR.md` T1 is trying to buy: an eight-cell column of loose earth stood as a column,
## because every grain had a grain directly beneath it and the rule asked nothing more.
##
## A DIAGONAL SLIDE ALSO NEEDS ITS ORTHOGONAL CELL OPEN. Without that clause material pours through a
## one-cell diagonal crack between two blocks, which reads as leaking rather than as slumping, and lets a
## pile drain through a wall it should be resting against.
##
## The left/right preference is `(c.x + c.y) & 1`. A fixed preference gives every pile in the world the
## same lean; a parity is still perfectly deterministic, needs no state, and breaks the lean up spatially
## so a heap spreads instead of walking.
static func target(grid: TileGrid, water: WaterPlane, c: Vector2i) -> Vector2i:
	if not grid.in_bounds(c) or not WorldMaterials.is_loose(grid.get_material(c)):
		return c
	var below: Vector2i = c + DOWN
	if _open(grid, water, below):
		return below
	if not grid.in_bounds(below) or not WorldMaterials.is_loose(grid.get_material(below)):
		return c                     # bedrock, a machine, the world's floor or open water: this is rest
	var first: Vector2i = LEFT if ((c.x + c.y) & 1) == 0 else RIGHT
	for side: Vector2i in [first, -first]:
		if _open(grid, water, c + side) and _open(grid, water, c + side + DOWN):
			return c + side + DOWN
	return c


## Room for a loose cell to arrive: in the world, no rock, and dry. See the header on why wet is closed.
static func _open(grid: TileGrid, water: WaterPlane, c: Vector2i) -> bool:
	return grid.in_bounds(c) and not grid.is_solid(c) and water.water_at(c) == 0


## Carry the material from `from` to `to` and wake what the vacancy may release: the cell above `from` and
## its lateral-up neighbours (they were leaning on it), and `to` itself, which may keep going next step.
## `to` is queued last so a column comes down top-first, which is the order that reads as a collapse.
func _move(grid: TileGrid, from: Vector2i, to: Vector2i) -> void:
	var material: StringName = grid.get_material(from)
	moved_material = material
	grid.excavate(from)
	grid.set_material(to, material)
	_wake(grid, from + UP)
	_wake(grid, from + UP + LEFT)
	_wake(grid, from + UP + RIGHT)
	_next.append(to)   # next step, not this one: see `settle`


func _wake(grid: TileGrid, c: Vector2i) -> void:
	if _queued.has(c) or not grid.in_bounds(c) or _queue.size() >= QUEUE_CAP:
		return
	_queued[c] = true
	_queue.append(c)


## THE CONSERVATION PROBE, for the suite and the invariant: how many loose cells the window holds. A step
## moves loose cells and never makes or destroys one, so this is invariant across `settle` -- the same
## shape `WaterPlane.total_water` gives `WaterFlow`.
static func loose_cells_in(grid: TileGrid, rect: Rect2i) -> int:
	var n: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var c := Vector2i(x, y)
			if grid.in_bounds(c) and WorldMaterials.is_loose(grid.get_material(c)):
				n += 1
	return n
