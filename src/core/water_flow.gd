extends RefCounted

## THE WATER FLOW STEP — the deterministic per-tick fluid algorithm, extracted from FactorySim so the
## sim's tick reads as a list of named subsystems rather than inlining ~80 lines of flow logic. Pure
## domain logic, no state of its own: it operates on the sim's `water` + `solid` grids (FactorySim still
## owns the water STATE and its public API — water_at / add_water / remove_water / total_water). Integer
## levels only, snapshot-based, order-stable: two identical sims flow identically (the determinism test
## depends on it), and the sum is invariant (water only MOVES — no source or drain here).

## THE FLOW STEP — run every tick (see FactorySim.tick). Deterministic + integer + snapshot-based, so it is
## order-stable and two identical sims flow identically. Two rules, computed over a SNAPSHOT of the
## levels (so no cell is read after another already moved into/out of it this pass):
##   1. DOWN (gravity — the hook): water falls into the open, non-full cell below it, as much as fits.
##   2. LATERAL settle: whatever can't fall EVEN-FILLS its maximal horizontal run of open cells (a run =
##      the contiguous non-solid cells sharing that row, bounded by walls / world edge). The run's total
##      is redistributed evenly across the run — remainder biased LEFT, a fixed deterministic tie-break —
##      so the pool reads a FLAT top (all wet cells within 1 unit). Computed directly from a snapshot, so
##      it's flat by construction and cannot oscillate; excess above WATER_MAX simply stays and falls next
##      tick via rule 1. Water never enters a solid cell; total is invariant (moves only, no source/drain).
static func step(sim: FactorySim) -> void:
	if sim.water.is_empty():
		return
	# --- 1. GRAVITY: a snapshot of the current levels, then every wet cell tries to fall. ---
	var snap: Dictionary = sim.water.duplicate()
	# Deterministic scan order over the wet cells (top-to-bottom, then left-to-right).
	var wet: Array[Vector2i] = []
	for cv: Variant in snap:
		wet.append(cv)
	wet.sort_custom(_cell_less)
	for c: Vector2i in wet:
		var level: int = int(sim.water.get(c, 0))                 # read LIVE (a higher cell may have topped it up)
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
	# --- 2. LATERAL settle: even-fill each maximal horizontal open run holding water. ---
	# A snapshot of levels AFTER gravity, then process runs left-to-right, top-to-bottom, each once.
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
		# Sum the run's water (from the post-gravity snapshot — order-independent), mark the whole run done.
		var sum: int = 0
		for x: int in range(lo, hi + 1):
			var cell := Vector2i(x, c.y)
			sum += int(snap.get(cell, 0))
			done[cell] = true
		if sum <= 0:
			for x2: int in range(lo, hi + 1):
				sim.water.erase(Vector2i(x2, c.y))
			continue
		# Even split across the run, remainder biased LEFT (deterministic). If the run holds MORE than it
		# can (sum > span*WATER_MAX — a big vertical dump just landed), every cell fills to WATER_MAX and
		# the TRUE surplus is parked in the leftmost cell, which falls next tick via rule 1 — nothing is
		# ever dropped, so the run's total is preserved exactly (conservation holds).
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


## A cell water can flow laterally INTO: in bounds and not solid. (Machines/rope/torch/conduit don't block
## water in this first slice — only rock does; interaction with those layers is a later slice.)
static func _open(sim: FactorySim, cell: Vector2i) -> bool:
	return sim.in_bounds(cell) and not sim.solid.has(cell)


## Deterministic cell ordering for the water sweeps: top-to-bottom (row), then left-to-right (col).
static func _cell_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x
