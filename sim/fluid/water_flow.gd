class_name WaterFlow
extends RefCounted

## The deterministic per-tick fluid algorithm. Stateless, operating on a `WaterPlane` and the `TileGrid`
## it flows through. Integer levels only, snapshot-based and order-stable, so two identical sims flow
## identically (the determinism test depends on it). Water only moves: no source, no drain, sum invariant.
##
## LIFTED VERBATIM in A' step 2 from `legacy/src/core/water_flow.gd` (100 lines, zero determinism rows in
## the 2026-09-02 read). The algorithm and its constants are legacy's; what changed is the owner: legacy's
## `sim.water` dictionary is `water.levels` here and every write goes through `water.set_level` so the
## plane's running signature moves with it, `sim.solid.has(c)` is `grid.is_solid(c)`, and the cell is the
## 4 px terrain cell rather than legacy's metre (`docs/ARCHITECTURE.md` §9). Runs in the `fluid` phase.
##
## `sim/fluid/MODULE.md`'s must-not -- never tick every cell -- is met by construction: both passes iterate
## the WET cells (the plane's own dictionary), which is the active-cell set, never the world.

## The flow step, run every tick. Two rules over a snapshot of the levels, so no cell is read after
## another has moved into or out of it this pass:
##   1. Down: water falls into the open, non-full cell below it, as much as fits.
##   2. Lateral settle: whatever cannot fall even-fills its maximal horizontal run of open cells
##      (contiguous non-solid cells in that row, bounded by walls or the world edge), with the
##      remainder biased left as a fixed tie-break. Flat by construction from the snapshot, so it
##      cannot oscillate; excess above WATER_MAX stays and falls next tick under rule 1.
static func step(water: WaterPlane, grid: TileGrid) -> void:
	if water.is_empty():
		return
	# --- 1. Gravity: a snapshot of the current levels, then every wet cell tries to fall. ---
	var snap: Dictionary = water.levels.duplicate()
	# Deterministic scan order over the wet cells (top-to-bottom, then left-to-right).
	var wet: Array[Vector2i] = []
	for cv: Variant in snap:
		wet.append(cv)
	wet.sort_custom(_cell_less)
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
	snap = water.levels.duplicate()
	wet.clear()
	for cv2: Variant in snap:
		wet.append(cv2)
	wet.sort_custom(_cell_less)
	var done: Dictionary = {}                                 # cells already levelled as part of a run
	for c: Vector2i in wet:
		if done.has(c):
			continue
		_settle_run(water, grid, snap, done, c)


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
static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
