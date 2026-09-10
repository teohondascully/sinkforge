class_name Slump
extends RefCounted

## LOOSE MATERIAL FALLS (D0562). A cell whose material is `loose` and whose support is gone moves down
## one cell a step, and slides diagonally when it cannot fall straight, which is an angle of repose
## rather than a column standing on a corner.
##
## WHY: the earth was scenery. An Opus playthrough on 2026-09-10 cut forty-two cells out from under a
## standing mass and the mass hung there; `docs/NORTH_STAR.md` §2.1 is the table of what the world did
## in reply to everything a player can do to it, and every row of it said "nothing". This is the
## smallest change that makes the world answer a blow.
##
## **AND THE JUSTIFICATION THIS HEADER USED TO GIVE WAS FALSE (D0582).** It said `docs/GDD.md` §13's
## "holes: gravity routing. free. dug, not built" was "unbuildable, because nothing in the world moved
## unless a verb moved it". That step was ALREADY BUILT and this file has nothing to do with it:
## `sim/items/landing.gd`'s `column_landing` walks a dropped item down its column through open air and
## into a machine's buffer if it meets one, and `Items.resettle_pile_above` re-drops a pile when the
## metre under it is bored out. Items already fall through holes you dig. TERRAIN falling and ITEMS
## falling through dug space are different systems and the original header conflated them. Astra's audit
## reached the same conclusion independently ("slump is not the fuel-routing breakthrough"). What this
## file actually buys is the world answering a blow, which is worth having on its own and is the only
## claim it should make.
##
## **THE SCOPING IS AN OPEN QUESTION AND THE MEASUREMENTS ARE UNCOMFORTABLE (P043).** `clay` is the only
## loose material and it is the tutorial world's own rock, so every corridor a new player cuts is cut
## through material that flows. Measured on the real generated world: a body-height corridor at 4 m and
## at 8 m refills **100%**, leaving 0 of the 10 cells of headroom a body needs to walk; one 1 m staircase
## step moves **1,571 cells** for the 15 it dug and none of the 15 stays open. Three attempts to keep
## both behaviours all failed the same way -- a cohesion clause, and dropping the upward wake, each gave
## the corridor back and removed the collapse entirely. A tunnel roof and an undermined mass are
## LOCALLY IDENTICAL (loose cells, open below, solid to the sides), so no rule that reads only
## neighbours can distinguish them. The fix is a material, not a constant: cohesive rock holds a tunnel,
## granular material slumps, which is the line Noita itself draws. Director's call; nothing here changes
## until it is made.
##
## SHAPE LIFTED FROM `TreeFall` (D0438), DELIBERATELY. Same seam (`MineHold.step` calls `settle` before
## the tick's aim and `after_break` after a blow), same transient queue, same reversal: drop the two calls
## in `MineHold.step` and the world is scenery again. It is not lifted from `WaterFlow`, whose active set
## is seeded off `TileGrid.take_solidity_changes` -- that log has one consumer and draining it twice would
## give each half the other's cells.
##
## WHAT THIS DELIBERATELY DOES NOT DO, each a real limit and not an oversight:
##
##  - **Loose material never falls onto the body** (D0566). `occupied` is the body's cell box and is
##    treated exactly as rock is. This is the same refusal `BuildVerbs.place_block` already makes ("refuses
##    solid, OCCUPIED and out-of-bounds cells"), and it is here because the alternative was measured: with
##    a whole bank of clay coming down into a tunnel the body was standing in, the body was buried, and
##    `Body._enforce_grid_bounds` ejected it to cell (38, 35) -- the far corner of a 40-cell world.
##    `tests/test_slump_body.gd` is that measurement. Earth now packs AROUND the player instead, which is
##    also the more readable picture. Reverse by passing an empty rect.
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

## The live queue's bound. A wake past it goes to `_spill` and rejoins as the queue drains, so the real
## defer is 2 * QUEUE_CAP cells (A3). The comparison this constant used to draw to
## `TileGrid.SOLIDITY_LOG_CAP` was wrong and is withdrawn: the grid does not DROP its overflow, it falls
## back to an all-changed signal, which is a defer, and this file dropped silently.
##
## AND THE LIMIT THAT REMAINS, stated rather than implied. Past 8192 pending cells the spill is full too
## and a wake is refused -- counted in `refused_wakes`, never silent, but still lost. That is a stated
## bound and not a solved problem. It is out of reach of anything the game can do today: a blow breaks a
## handful of cells and wakes three each, and `_move` adds at most sixteen wakes a tick against a budget
## of four moves, so the queue has never been observed above a few dozen. A cave-in verb, a blast or a
## drill sweeping a face WOULD reach it, and the answer then is `TileGrid`'s own -- an overflow flag and
## a rescan of the affected region, not a third buffer. Logged for the director rather than built on
## speculation about a burst source that does not exist yet.
const QUEUE_CAP: int = 4096

## The EXAMINED-work budget, which is not the moved-work budget (A4). `SETTLE_PER_TICK` bounds how many
## cells MOVE; nothing bounded how many were looked at, so a tick could call `target` 4096 times to find
## four movers -- and every one of those calls was a `pop_front`, which shifts the whole array. A queue
## of at-rest cells cost O(n^2) a tick to discover it had nothing to do. 64 is ~16 candidates per mover,
## and `sim/fluid/MODULE.md` makes the active set a hard constraint, so this is the constraint's shape
## here. Cells not reached this tick are still queued; they are examined next tick.
const LOOK_PER_TICK: int = 64

## Consumed prefix length that triggers a compaction. The queue is read through `_head` rather than
## `pop_front` so a step is O(looked) and not O(looked * queue); the prefix is reclaimed in one slice.
const COMPACT_AT: int = 256

const DOWN := Vector2i(0, 1)
const UP := Vector2i(0, -1)
const LEFT := Vector2i(-1, 0)
const RIGHT := Vector2i(1, 0)

var _queue: Array[Vector2i] = []
var _head: int = 0                           ## read cursor into `_queue`; see `COMPACT_AT`
var _spill: Array[Vector2i] = []             ## wakes deferred past `QUEUE_CAP`, drained as room appears
var _queued: Dictionary = {}                 ## cell -> true while queued: one blow breaks several cells
var _next: Array[Vector2i] = []              ## woken FOR THE NEXT step, never this one (see `settle`)
var _landed: Dictionary = {}                 ## cells a grain ARRIVED in this step; they rest until next
## Wake EVENTS refused because the live queue and the spill were both full -- events, not distinct
## cells, because a refused cell is re-offered by the next thing that wakes it and refused again. The
## count exists so that the one lossy path in a deterministic automaton has a witness; see `_wake`.
var refused_wakes: int = 0
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


## One step of the collapse: up to `SETTLE_PER_TICK` queued cells that can still move, do, and at most
## `LOOK_PER_TICK` are examined to find them. A cell that cannot move leaves the queue ONLY when its
## refusal is permanent -- see the transient clause below.
##
## A CELL MOVES AT MOST ONE CELL PER STEP, and `_next` alone did not buy that (A1). `_next` defers the
## destinations of moves made THIS step, which stops a grain being re-popped from cells this step put it
## in. It does nothing about a destination that was ALREADY in the queue when the step began -- and
## overlapping wake neighbourhoods put one there routinely, because `after_break` wakes three cells per
## break and `_move` wakes three more per move. Astra reproduced it: a grain at (10,25) went through
## (10,26) to (10,27) inside one `settle`, two cells for one step's budget of one. `_landed` closes it
## from the other side: a cell a grain ARRIVED in this step is deferred on sight, whatever queued it.
##
## A REFUSAL IS NOT ALWAYS A REST (A2). `target` returns the cell itself for two unlike reasons: rock or
## the world's floor beneath it, which is permanent and means the cell should leave the queue; or the
## body's cell box or a body of water, which will move on its own and wake nothing when it does. The
## second case used to hit the same bare `continue` and the grain hung forever with an empty queue --
## reproduced by blocking a destination with `occupied` and then removing the rect. The second `target`
## call asks the same rule with the transients lifted, so the two answers cannot drift apart; it runs
## only on the refusal path, which is the cold one.
func settle(grid: TileGrid, water: WaterPlane, occupied: Rect2i = Rect2i(), closed: Dictionary = {}) -> void:
	moved_this_tick.clear()
	_landed.clear()
	var looked: int = 0
	while moved_this_tick.size() < SETTLE_PER_TICK and _head < _queue.size() and looked < LOOK_PER_TICK:
		looked += 1
		var c: Vector2i = _queue[_head]
		_head += 1
		_queued.erase(c)
		if _landed.has(c):
			_next.append(c)                                  # a grain arrived here this step (A1)
			continue
		var to: Vector2i = target(grid, water, c, occupied, false, closed)
		if to == c:
			if target(grid, water, c, occupied, true, closed) != c:
				_next.append(c)                              # held by the body or by water (A2)
			continue
		_move(grid, c, to)
		_landed[to] = true
		moved_this_tick.append(c)
	_compact()
	for c: Vector2i in _next:
		_wake(grid, c)
	_next.clear()
	_drain_spill()


## Cells still owed a look, live queue and deferred spill together. A caller asking "has the world
## finished answering?" means both, and the spill is not a second, quieter queue.
func pending() -> int:
	return (_queue.size() - _head) + _spill.size()


## Reclaim the consumed prefix in one slice rather than shifting the array on every read. Deferred until
## the prefix is worth the copy, or taken for free when the queue empties.
func _compact() -> void:
	if _head == 0:
		return
	if _head >= _queue.size():
		_queue.clear()
		_head = 0
	elif _head >= COMPACT_AT:
		_queue = _queue.slice(_head)
		_head = 0


## Deferred wakes rejoin the live queue as room appears (A3). A burst wider than `QUEUE_CAP` is a
## collapse arriving faster than the budget answers it, which is a reason to be late and not a reason to
## lose cells.
func _drain_spill() -> void:
	var room: int = QUEUE_CAP - (_queue.size() - _head)
	if room <= 0 or _spill.is_empty():
		return
	var n: int = mini(room, _spill.size())
	for i: int in range(n):
		_queue.append(_spill[i])
	_spill = _spill.slice(n)


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
##
## `lift_transients` asks the same question with the body and the water taken out of the world, which is
## how `settle` tells a rest from a wait (A2). It is not a second rule: every other clause is shared, so
## the two answers cannot drift.
static func target(grid: TileGrid, water: WaterPlane, c: Vector2i, occupied: Rect2i = Rect2i(),
		lift_transients: bool = false, closed: Dictionary = {}) -> Vector2i:
	if not grid.in_bounds(c) or not WorldMaterials.is_loose(grid.get_material(c)):
		return c
	var below: Vector2i = c + DOWN
	if _open(grid, water, below, occupied, lift_transients, closed):
		return below
	if not grid.in_bounds(below) or not WorldMaterials.is_loose(grid.get_material(below)):
		return c                     # bedrock, a machine, the world's floor or open water: this is rest
	var first: Vector2i = LEFT if ((c.x + c.y) & 1) == 0 else RIGHT
	for side: Vector2i in [first, -first]:
		if _open(grid, water, c + side, occupied, lift_transients, closed) \
				and _open(grid, water, c + side + DOWN, occupied, lift_transients, closed):
			return c + side + DOWN
	return c


## `closed` is a set of cells earth may not enter that the grid does not know about -- MACHINES (A5).
## They live in `sim/machines`' own registry keyed by logic cell and never make the terrain solid, so
## `is_solid` cannot see one and falling earth used to write rock into a working machine's cell. It
## arrives as plain cell data rather than as a `Machines` object because this module takes none: the
## same reason `occupied` is a `Rect2i` and not a `Body`. Earth packs AROUND machinery exactly as D0566
## made it pack around the player -- consistent, non-destructive, and the readable picture.
##
## Room for a loose cell to arrive: in the world, no rock, dry, not closed, and not where the body is
## standing. See
## the header on why wet and occupied are both closed. An empty `occupied` rect contains no point, so the
## default argument means "nothing is standing anywhere" without a branch.
static func _open(grid: TileGrid, water: WaterPlane, c: Vector2i, occupied: Rect2i = Rect2i(),
		lift_transients: bool = false, closed: Dictionary = {}) -> bool:
	if not grid.in_bounds(c) or grid.is_solid(c) or closed.has(c):
		return false
	if lift_transients:
		return true                  # the body and the water are asked to step aside, the rock is not
	return water.water_at(c) == 0 and not occupied.has_point(c)


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
	if _queued.has(c) or not grid.in_bounds(c):
		return
	_queued[c] = true
	if _queue.size() - _head < QUEUE_CAP:
		_queue.append(c)
		return
	if _spill.size() < QUEUE_CAP:
		_spill.append(c)             # late, not lost (A3)
		return
	_queued.erase(c)
	refused_wakes += 1               # both bounds full: counted, so a replay divergence has a name


## THE PENDING COLLAPSE, CARRIED ACROSS A SAVE (A7, D0579). The queue used to be transient, so a save
## taken mid-collapse came back with the earth standing and nothing to wake it -- and that is not merely
## a wrong-looking frame: two otherwise identical factories evolve differently depending on whether their
## player reloaded.
##
## ORDER IS PART OF THE STATE, not a detail. The queue is FIFO and the order decides which cell moves
## next, so the spill follows the live queue and `_next` follows both -- exactly where each would have
## been read from had the save never happened.
##
## THE ALTERNATIVE WAS TO DERIVE IT ON LOAD by scanning for unsupported cells, and it was tried first
## and measured wrong. The generated tutorial world holds **1061 unsupported loose cells** out of 28,572
## loose cells: deriving the queue would collapse a tenth of the world's loose earth the moment anyone
## loaded a save, cascading (3,876 still pending after 2,000 settle steps) while a freshly generated
## session sat still. `tests/test_boot_snapshot.gd` caught it -- the two sessions signed identically at
## rest and diverged after ticking. Whether the world SHOULD arrive settled is a real question and it is
## the director's, in `docs/NEEDS_DIRECTOR.md`; it is not a thing to decide inside a save-format fix.
func capture() -> Array[Vector2i]:
	var out: Array[Vector2i] = _queue.slice(_head)
	out.append_array(_spill)
	out.append_array(_next)
	return out


## A save from before this key carries no collapse, which is exactly what those saves meant.
func restore(cells: Array) -> void:
	_queue.clear()
	_spill.clear()
	_next.clear()
	_queued.clear()
	_landed.clear()
	_head = 0
	refused_wakes = 0
	for c: Vector2i in cells:
		if _queued.has(c):
			continue
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
