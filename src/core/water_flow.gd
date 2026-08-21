extends RefCounted

## The deterministic per-tick fluid algorithm. Stateless, operating on the sim's `water` and `solid` grids.
## Integer levels only, snapshot-based and order-stable, so two identical sims flow identically (the
## determinism test depends on it). Water only moves: no source, no drain, sum invariant.

## The flow step, run every tick. Two rules over a snapshot of the levels, so no cell is read after
## another has moved into or out of it this pass:
##   1. Down: water falls into the open, non-full cell below it, as much as fits.
##   2. Lateral settle: whatever cannot fall even-fills its maximal horizontal run of open cells
##      (contiguous non-solid cells in that row, bounded by walls or the world edge), with the
##      remainder biased left as a fixed tie-break. Flat by construction from the snapshot, so it
##      cannot oscillate; excess above WATER_MAX stays and falls next tick under rule 1.
static func step(sim: FactorySim) -> void:
	if sim.water.is_empty():
		return
	# --- 1. Gravity: a snapshot of the current levels, then every wet cell tries to fall. ---
	var snap: Dictionary = sim.water.duplicate()
	# Deterministic scan order over the wet cells (top-to-bottom, then left-to-right).
	var wet: Array[Vector2i] = []
	for cv: Variant in snap:
		wet.append(cv)
	wet.sort_custom(_cell_less)
	for c: Vector2i in wet:
		var level: int = int(sim.water.get(c, 0))                 # read live (a higher cell may have topped it up)
		if level <= 0:
			continue
		var below: Vector2i = c + Vector2i(0, 1)
		if not sim.in_bounds(below) or sim.solid.has(below):
			continue
		var room: int = FactorySim.WATER_MAX - int(sim.water.get(below, 0))
		if room <= 0:
			continue
		var moved: int = mini(level, room)
		sim.water[below] = int(sim.water.get(below, 0)) + moved
		var rem: int = level - moved
		if rem <= 0:
			sim.water.erase(c)
		else:
			sim.water[c] = rem
	# --- 2. Lateral settle: even-fill each maximal horizontal open run holding water. ---
	# A snapshot of levels after gravity, then process runs left-to-right, top-to-bottom, each once.
	snap = sim.water.duplicate()
	wet.clear()
	for cv2: Variant in snap:
		wet.append(cv2)
	wet.sort_custom(_cell_less)
	var done: Dictionary = {}                                 # cells already levelled as part of a run
	for c: Vector2i in wet:
		if done.has(c):
			continue
		# Walk out to the run's bounds along this row (open, in-bounds cells; walls/edges stop it).
		var lo: int = c.x
		while _open(sim, Vector2i(lo - 1, c.y)):
			lo -= 1
		var hi: int = c.x
		while _open(sim, Vector2i(hi + 1, c.y)):
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
				sim.water.erase(Vector2i(x2, c.y))
			continue
		# Even split across the run, with the remainder biased left. When the run holds more than it can
		# (sum > span*WATER_MAX, after a vertical dump lands), every cell fills to WATER_MAX and the
		# surplus rides the leftmost cell, falling next tick under rule 1. Nothing is dropped.
		var cap_total: int = span * FactorySim.WATER_MAX
		if sum > cap_total:
			for x3: int in range(lo, hi + 1):
				sim.water[Vector2i(x3, c.y)] = FactorySim.WATER_MAX
			sim.water[Vector2i(lo, c.y)] = FactorySim.WATER_MAX + (sum - cap_total)   # overflow rides the left cell; falls next tick
			continue
		var base: int = sum / span
		var extra: int = sum - base * span                    # 0..span-1 units to sprinkle from the left
		for i: int in span:
			var cell2 := Vector2i(lo + i, c.y)
			var lvl: int = base + (1 if i < extra else 0)
			if lvl <= 0:
				sim.water.erase(cell2)
			else:
				sim.water[cell2] = lvl


## A cell water can flow laterally into: in bounds and not solid. Machines, rope, torch and conduit do not
## block water in this slice; only rock does.
static func _open(sim: FactorySim, cell: Vector2i) -> bool:
	return sim.in_bounds(cell) and not sim.solid.has(cell)


## Deterministic cell ordering for the water passes: top-to-bottom (row), then left-to-right (col).
static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
