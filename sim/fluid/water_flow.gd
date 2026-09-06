class_name WaterFlow
extends RefCounted

## The deterministic per-tick fluid algorithm. Stateless, operating on a `WaterPlane` (`sim/world`) and the
## `TileGrid` it flows through. Integer levels only, snapshot-based and order-stable, so two identical sims flow
## identically (the determinism test depends on it). Water only moves: no source, no drain, sum invariant.
##
## LIFTED VERBATIM in A' step 2 from `legacy/src/core/water_flow.gd` (100 lines, zero determinism rows in
## the 2026-09-02 read). The algorithm and its constants are legacy's; what changed is the owner: legacy's
## `sim.water` dictionary is `water.levels` here and every write goes through `water.set_level` so the
## plane's running signature moves with it, `sim.solid.has(c)` is `grid.is_solid(c)`, and the cell is the
## 4 px terrain cell rather than legacy's metre (`docs/ARCHITECTURE.md` §9). Runs in the `fluid` phase.
##
## `sim/fluid/MODULE.md`'s must-not -- never tick every cell -- is met by `step`'s ACTIVE SET (D0405): the
## cells written last tick, the cells above them and the neighbourhood of every dig, and the runs those sit
## in. `step_full` is the algorithm as lifted, every wet cell every tick, kept as the oracle the active step
## is pinned equal to (`tests/test_water_rest.gd`, `tests/test_water_active.gd`).
##
## WHY THE ACTIVE SET IS EXACT. A wet cell's fall depends on its own level, the level below it and the
## solidity below it, at the moment the top-to-bottom pass reaches it. A cell nobody wrote last tick, whose
## cell below nobody wrote, over terrain nobody dug, was reached last tick with these same values and did
## not move -- so it does not move this tick either, whatever falls into it from above (the room below is
## still zero). A run's even-fill is idempotent, so a run none of whose cells moved is already level. The
## passes therefore visit only cells whose inputs changed, in the same order, and write the same values.

## The flow step, run every tick, over the active set. Two rules:
##   1. Down: water falls into the open, non-full cell below it, as much as fits.
##   2. Lateral settle: whatever cannot fall even-fills its maximal horizontal run of open cells
##      (contiguous non-solid cells in that row, bounded by walls or the world edge), with the
##      remainder biased left as a fixed tie-break. Flat by construction from the snapshot, so it
##      cannot oscillate; excess above WATER_MAX stays and falls next tick under rule 1.
static func step(water: WaterPlane, grid: TileGrid) -> void:
	var changes: Dictionary = grid.take_solidity_changes()   # drained every tick, wet or dry
	if water.is_empty():
		water.touched.clear()
		return
	if water.at_rest(grid):
		return
	var version_before: int = water.version
	var active: Dictionary = _wake(water, changes)
	# Only cells wet as the pass BEGINS fall this tick, as in `step_full`: a dry cell topped up mid-pass
	# waits for the next one.
	var wet: Dictionary = {}
	for c: Vector2i in active:
		if water.levels.has(c):
			wet[c] = true
	_gravity(water, grid, Ordering.cells_native(wet))
	# The runs the gravity pass wrote into or out of join the runs already woken. The live levels ARE the
	# post-gravity snapshot: runs are disjoint and `_settle_run` sums a run before it writes it. A woken
	# cell that is rock or off the grid (a displaced cell, the row above the world) seeds no run.
	for c: Vector2i in water.touched:
		active[c] = true
	var done: Dictionary = {}
	for c: Vector2i in Ordering.cells_native(active):
		if done.has(c) or not _open(grid, c):
			continue
		_settle_run(water, grid, water.levels, done, c)
	water.note_rest(version_before, grid)


## Run the plane to rest, or for `max_ticks`, whichever comes first; returns the ticks stepped. A fresh
## world's aquifers are seeded full against caves carved before them, so a world handed to the player
## un-settled pours for its first seconds -- generation's artifact, not play (V65, D0405). Deterministic:
## `step` is a pure function of the levels and the grid, and draws nothing.
static func settle(water: WaterPlane, grid: TileGrid, max_ticks: int) -> int:
	var ticks: int = 0
	while ticks < max_ticks:
		step(water, grid)
		ticks += 1
		if water.at_rest(grid) or water.is_empty():
			break
	return ticks


## This tick's active set from the plane's seed and the grid's solidity log, which are then cleared: the
## written cells and the cell above each (its floor changed), the dug or filled cells and their four
## neighbours (a new floor, a merged or split run). `all` -- a fresh plane, a clone, a restore, a bulk
## load, a log past its cap -- is every wet cell, which is `step_full`'s population exactly.
static func _wake(water: WaterPlane, changes: Dictionary) -> Dictionary:
	var active: Dictionary = {}
	if water.wake_all or bool(changes["all"]):
		water.wake_all = false
		for c: Vector2i in water.levels:
			active[c] = true
	else:
		for c: Vector2i in water.touched:
			active[c] = true
			active[c + Vector2i(0, -1)] = true
		for c: Vector2i in changes["cells"]:
			active[c] = true
			active[c + Vector2i(0, -1)] = true
			active[c + Vector2i(0, 1)] = true
			active[c + Vector2i(-1, 0)] = true
			active[c + Vector2i(1, 0)] = true
	water.touched.clear()
	return active


## Rule 1 over `cells`, in scan order, reading live: a higher cell may have topped a lower one up.
static func _gravity(water: WaterPlane, grid: TileGrid, cells: Array[Vector2i]) -> void:
	for c: Vector2i in cells:
		var level: int = water.water_at(c)
		if level <= 0:
			continue
		var below: Vector2i = c + Vector2i(0, 1)
		if not grid.in_bounds(below) or grid.is_solid(below):
			continue
		var room: int = WaterPlane.WATER_MAX - water.water_at(below)
		if room <= 0:
			continue
		var moved: int = mini(level, room)
		water.set_level(below, water.water_at(below) + moved)
		water.set_level(c, level - moved)                         # a remainder of 0 erases the cell


## THE ALGORITHM AS LIFTED, every wet cell every tick, over a snapshot: the oracle `step` is pinned equal
## to, and nothing else calls it. Two rules over a snapshot of the levels, so no cell is read after
## another has moved into or out of it this pass.
static func step_full(water: WaterPlane, grid: TileGrid) -> void:
	if water.is_empty():
		return
	# A plane at rest over unchanged terrain would settle to itself again: skip it (`WaterPlane.at_rest`).
	if water.at_rest(grid):
		return
	var version_before: int = water.version
	# --- 1. Gravity: every wet cell tries to fall, processed top-to-bottom. ---
	var wet: Array[Vector2i] = Ordering.cells_native(water.levels)
	for c: Vector2i in wet:
		var level: int = water.water_at(c)                        # read live (a higher cell may have topped it up)
		if level <= 0:
			continue
		var below: Vector2i = c + Vector2i(0, 1)
		if not grid.in_bounds(below) or grid.is_solid(below):
			continue
		var room: int = WaterPlane.WATER_MAX - water.water_at(below)
		if room <= 0:
			continue
		var moved: int = mini(level, room)
		water.set_level(below, water.water_at(below) + moved)
		water.set_level(c, level - moved)                         # a remainder of 0 erases the cell
	# --- 2. Lateral settle: even-fill each maximal horizontal open run holding water. ---
	# A snapshot of levels after gravity, then process runs left-to-right, top-to-bottom, each once.
	var snap: Dictionary = water.levels.duplicate()
	wet = Ordering.cells_native(snap)
	var done: Dictionary = {}                                 # cells already levelled as part of a run
	for c: Vector2i in wet:
		if done.has(c):
			continue
		_settle_run(water, grid, snap, done, c)
	water.note_rest(version_before, grid)


## One maximal horizontal open run, levelled. Split out of `step` only for the 50-line function cap
## (`docs/QUALITY.md` gate 4); the body is legacy's, line for line.
static func _settle_run(water: WaterPlane, grid: TileGrid, snap: Dictionary, done: Dictionary, c: Vector2i) -> void:
	# Walk out to the run's bounds along this row (open, in-bounds cells; walls/edges stop it).
	var lo: int = c.x
	while _open(grid, Vector2i(lo - 1, c.y)):
		lo -= 1
	var hi: int = c.x
	while _open(grid, Vector2i(hi + 1, c.y)):
		hi += 1
	var span: int = hi - lo + 1
	# Sum the run's water from the post-gravity snapshot (order-independent), and mark the run done.
	var sum: int = 0
	for x: int in range(lo, hi + 1):
		var cell := Vector2i(x, c.y)
		sum += int(snap.get(cell, 0))
		done[cell] = true
	if sum <= 0:
		for x2: int in range(lo, hi + 1):
			water.set_level(Vector2i(x2, c.y), 0)
		return
	# Even split across the run, with the remainder biased left. When the run holds more than it can
	# (sum > span*WATER_MAX, after a vertical dump lands), every cell fills to WATER_MAX and the
	# surplus rides the leftmost cell, falling next tick under rule 1. Nothing is dropped.
	var cap_total: int = span * WaterPlane.WATER_MAX
	if sum > cap_total:
		for x3: int in range(lo, hi + 1):
			water.set_level(Vector2i(x3, c.y), WaterPlane.WATER_MAX)
		water.set_level(Vector2i(lo, c.y), WaterPlane.WATER_MAX + (sum - cap_total))   # overflow rides the left cell; falls next tick
		return
	var base: int = sum / span
	var extra: int = sum - base * span                    # 0..span-1 units to sprinkle from the left
	for i: int in span:
		var cell2 := Vector2i(lo + i, c.y)
		water.set_level(cell2, base + (1 if i < extra else 0))   # 0 erases


## A cell water can flow laterally into: in bounds and not solid. Machines, rope, torch and conduit do not
## block water in this slice; only rock does.
static func _open(grid: TileGrid, terrain_cell: Vector2i) -> bool:
	return grid.in_bounds(terrain_cell) and not grid.is_solid(terrain_cell)


## Deterministic cell ordering for the water passes: top-to-bottom (row), then left-to-right (col).
## Legacy's body, now `Ordering.cell_less` so every plane shares one scan order (the one deliberate
## deviation from verbatim in this file, D0347).
static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	return Ordering.cell_less(a, b)
