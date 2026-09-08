class_name BakeLane
extends RefCounted

## THE WINDOW LANE'S BUDGET: which of the chunks entering the window are painted THIS tick (D0524). Split
## out of `view/visuals/bake_window.gd` at that file's line cap, and a seam rather than a trim: the grid,
## the painted set and the tick's plan are the window's; what the lane may admit in one tick, and in what
## unit, is this file's. Pure functions over a `BakeWindow` and the tick's observation, so every rule here
## is assertable headless (`tests/test_bake_budget.gd`) -- `TerrainBake.setup` declines under
## `--headless`, and a decision left past it is covered by nothing.

## THE BUDGET, IN SOLID CELLS A TICK (D0524; D0522 counted chunks). The painters' cost is per SOLID cell
## -- `TerrainPainter.cell_fill` -> `RockTone.shade` probes neighbours through a Callable for every solid
## cell and skips air -- so the lane spends its budget on the solid cells a chunk holds, read off the
## observation (`solid_cells_in`), and an air chunk costs it nothing. D0522's budget of 4 chunks a tick was
## in the wrong unit: on the shaft fall a row of 32-cell chunks entering the margin painted 4 chunks
## (2400-3200 solid cells) for 69-83 ms of painter time in one tick, the director's "it glitches as it
## quickly loads another part of the world". 512 solid cells is two solid 16-cell chunks: ~9 ms at the 18
## us a cell W9 measured, ~13 ms at the 26 us the fall measured on a contended host.
##
## THE FIRST BAKE OF A SESSION IS NOT BUDGETED -- nothing is painted yet, so there is no prefetch to hide
## behind, the player is looking at the whole window at once, and a seat's first frame must not show a
## hole (D0522). Digs are never budgeted and never spend it: a dug cell must never show stale for a frame.
const WINDOW_LANE_SOLID_CELLS: int = 512


## THE SOLID CELLS OF CHUNK `i` AS THE OBSERVATION SEES THEM: a byte count over the chunk's rows of
## `obs.materials`, where 0 is air by the grid's own legend (`TileGrid.legend[0]`), so no string is
## compared. A CELL THE OBSERVATION DOES NOT COVER COUNTS AS SOLID, and so does every cell when there is no
## observation: the budget may only be spent on cells it can see, and an unseen cell assumed cheap is a
## chunk painted for free that was not. The per-frame observation covers the grown window snapped outward
## to `Envelope.SNAP_CELLS` (32), so at 16-cell chunks every chunk the window selects is inside it and the
## pessimism is never exercised; were the snap or the chunk to change, the lane would paint fewer chunks a
## tick, never a hole -- the view promise in `choose` is what forbids holes.
static func solid_cells_in(w: BakeWindow, i: int, obs: Interface.Observation) -> int:
	var cells: Rect2i = w.cells_of(w.chunk_rect(i))
	if obs == null:
		return cells.get_area()
	var seen: Rect2i = cells.intersection(obs.window)
	var solid: int = cells.get_area() - seen.get_area()
	for y: int in range(seen.position.y, seen.end.y):
		var start: int = (y - obs.window.position.y) * obs.window.size.x + (seen.position.x - obs.window.position.x)
		solid += seen.size.x - obs.materials.slice(start, start + seen.size.x).count(0)
	return solid


## THE CHOICE: the never-painted chunks of the grown window, minus `exclude` (the chunks the dig lane
## already paints whole this tick), nearest the window's centre first (ties by index, so the order is
## deterministic) -- except on the session's first bake, which paints the whole window (see the constant).
## Two rules, in this order:
##
## THE VIEW IS THE PROMISE. A chunk whose rect meets the UN-MARGINED view `rect` is on screen now, and an
## unpainted chunk on screen is a hole in the world; it paints this tick whatever the budget says, and what
## it costs is spent against the budget all the same. THE MARGIN IS THE PREFETCH. Of the rest, each chunk
## whose solid cells still fit under `WINDOW_LANE_SOLID_CELLS` paints, nearest first; an air chunk holds
## no solid cells and always fits. A chunk that does not fit is skipped, not a stop: a nearer solid chunk
## must not hold up a farther air one. `p.lane_solid` receives what was spent, so a suite can assert the
## number the budget is in and not only a chunk count.
static func choose(w: BakeWindow, rect: Rect2, exclude: Dictionary, obs: Interface.Observation,
		p: BakeWindow.Plan) -> Array[int]:
	var pending: Array[int] = []
	for i: int in w.unpainted_in(rect):
		if not exclude.has(i):
			pending.append(i)
	if w.painted_count() == 0:
		for i: int in pending:   # the first bake: everything, and what it costs said in the budget's unit
			p.lane_solid += solid_cells_in(w, i, obs)
		return pending
	var centre: Vector2 = rect.get_center()
	pending.sort_custom(func(a: int, b: int) -> bool:
		var da: float = w.chunk_rect(a).get_center().distance_squared_to(centre)
		var db: float = w.chunk_rect(b).get_center().distance_squared_to(centre)
		return da < db if da != db else a < b)
	var chosen: Array[int] = []
	var prefetch: Array[int] = []
	for i: int in pending:
		if w.chunk_rect(i).intersects(rect):
			chosen.append(i)
			p.lane_solid += solid_cells_in(w, i, obs)
		else:
			prefetch.append(i)
	for i: int in prefetch:
		var solid: int = solid_cells_in(w, i, obs)
		if p.lane_solid + solid <= WINDOW_LANE_SOLID_CELLS:
			chosen.append(i)
			p.lane_solid += solid
	return chosen
