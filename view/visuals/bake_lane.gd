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

## THE OPTIONAL MARGIN'S OWN PER-TICK CAP, IN CHUNKS (D0543), because the budget above is in the wrong
## unit for the cost it is trying to bound and the paragraph above says so in its own words: "an air chunk
## holds no solid cells and always fits". That was measured false. `BakeChunk._paint` observes the whole
## rectangle, runs EVERY retained painter over it -- the background wall included -- and fills the grammar
## map for air as well as rock; only `TerrainPainter.cell_fill` skips air. So an air-heavy margin chunk
## spends almost nothing of the solid-cell budget and still costs milliseconds. D0541 finding 4 named it
## from the source and D0542's paired receipt is the observation: **four margin callbacks, 1024 rectangle
## cells, 9.793 ms in ONE physics tick**, against a 2.78 ms frame.
##
## The cap is not a tuning knob and not a number I chose. A 16-cell chunk is 256 rectangle cells and
## preparation measures 9.6-12.3 us a cell, so ONE chunk is already 2.5-3.1 ms -- the whole frame budget.
## There is no cap that makes the margin free; the only question is how few chunks a tick it can be
## spread over WITHOUT the camera overtaking the prefetch, and that is arithmetic over the camera's own
## measured travel: see `optional_cap`. MANDATORY WORK IS NOT CAPPED AND NEVER WAITS -- a chunk on screen
## is a hole in the world and a dug cell must never show stale for a frame.
const OPTIONAL_MIN_PER_TICK: int = 1


## THE SOLID CELLS OF CHUNK `i` AS THE OBSERVATION SEES THEM: a byte count over the chunk's rows of
## `obs.materials`, where 0 is air by the grid's own legend (`TileGrid.legend[0]`), so no string is
## compared. A CELL THE OBSERVATION DOES NOT COVER COUNTS AS SOLID, and so does every cell when there is no
## observation: the budget may only be spent on cells it can see, and an unseen cell assumed cheap is a
## chunk painted for free that was not. The per-frame observation covers the grown window snapped outward
## to `Envelope.SNAP_CELLS` (32), so at 16-cell chunks every chunk the window selects is inside it and the
## pessimism is never exercised; were the snap or the chunk to change, the lane would paint fewer chunks a
## tick, never a hole -- the view promise in `choose` is what forbids holes.
static func solid_cells_in(w: BakeWindow, i: int, obs: Interface.Observation) -> int:
	return solid_in(obs, w.cells_of(w.chunk_rect(i)))


## The same count over ANY cell rect, which is what a partial repaint needs (D0546): the dig lane paints
## rects that are not a whole chunk, so a per-chunk counter cannot say what one of them held. Split out of
## the function above rather than written twice -- the pessimism about unseen cells is a rule, and a rule
## copied is a rule that drifts.
static func solid_in(obs: Interface.Observation, cells: Rect2i) -> int:
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
## it costs is spent against the budget all the same. THE MARGIN IS THE PREFETCH, and it is bounded twice:
## by `WINDOW_LANE_SOLID_CELLS` as before, and by `optional_cap` in whole chunks (D0543). A chunk that
## exceeds the solid budget is SKIPPED, not a stop -- a nearer solid chunk must not hold up a farther air
## one -- but running out of the chunk cap IS a stop, because that cap is on the tick's optional cost and
## every remaining chunk costs about the same. This is where "an air chunk always fits" used to be, and
## that sentence was the defect: air is free to the budget and is not free to paint. `p.lane_solid`
## receives what was spent, so a suite can assert the number the budget is in and not only a chunk count.
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
	# NEAREST TO WHERE THE CAMERA IS GOING, not to where it is. `travel` is the window's own movement
	# since the last plan, so it needs no constant from `sim/` and no guess about how a body is moving --
	# a grapple and a fall order the same way. A still camera has zero travel and this is the old
	# distance-to-centre order exactly.
	var focus: Vector2 = focus_of(rect, w.travel())
	pending.sort_custom(func(a: int, b: int) -> bool:
		var da: float = w.chunk_rect(a).get_center().distance_squared_to(focus)
		var db: float = w.chunk_rect(b).get_center().distance_squared_to(focus)
		return da < db if da != db else a < b)
	var chosen: Array[int] = []
	var prefetch: Array[int] = []
	for i: int in pending:
		if w.chunk_rect(i).intersects(rect):
			chosen.append(i)   # ON SCREEN: mandatory, uncapped, and still charged to the budget
			p.lane_solid += solid_cells_in(w, i, obs)
		else:
			prefetch.append(i)
	var room: int = optional_cap(w.travel(), rect)
	for i: int in prefetch:
		if room <= 0:
			break   # A STOP, not a skip: the cap is on the tick's optional COST, and the next chunk down
		var solid: int = solid_cells_in(w, i, obs)   # the list costs the same as this one.
		if p.lane_solid + solid <= WINDOW_LANE_SOLID_CELLS:
			chosen.append(i)
			p.lane_solid += solid
			room -= 1
	return chosen


## How many OPTIONAL margin chunks this tick may paint: enough that the camera cannot overtake the
## prefetch, and not one more.
##
## A row of chunks entering the margin is `ceil(width / CHUNK_PX) + 1` chunks wide, and the camera crosses
## one chunk of ground every `CHUNK_PX / speed` ticks, so staying ahead needs `chunks * speed / CHUNK_PX`
## chunks a tick. Every term is read off the window itself. A still camera exposes nothing and falls to
## `OPTIONAL_MIN_PER_TICK`, so the margin still fills, just without a burst nobody is waiting for.
##
## THIS CANNOT PROMISE A 2.78 ms FRAME and does not pretend to: one chunk is already 2.5-3.1 ms. What it
## promises is that the tick's optional work is the least the camera's own speed allows, where before it
## was however many chunks happened to fit under a budget that charges air nothing.
## THE POINT THE MARGIN IS ORDERED AROUND: one chunk ahead of the camera along its own travel, or the
## camera's centre when it is still. Pure, and separate from `choose`, so the ordering is a claim a suite
## can check rather than one a reader has to take on trust. One chunk of lead and not more: the margin is
## one chunk deep, so a focus further out would rank chunks the window does not reach.
static func focus_of(rect: Rect2, travel: Vector2) -> Vector2:
	if travel.length() <= 0.0:
		return rect.get_center()
	return rect.get_center() + travel.normalized() * float(BakeWindow.CHUNK_PX)


## Pure in its two inputs so a suite can pin the derivation directly, at any speed, without posing a
## camera that moves the window it is measuring.
static func optional_cap(travel: Vector2, rect: Rect2) -> int:
	var speed: float = travel.length()
	if speed <= 0.0:
		return OPTIONAL_MIN_PER_TICK
	var wide: int = ceili(rect.size.x / float(BakeWindow.CHUNK_PX)) + 1
	return maxi(OPTIONAL_MIN_PER_TICK, ceili(float(wide) * speed / float(BakeWindow.CHUNK_PX)))
