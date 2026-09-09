extends "res://tests/test_base.gd"

## `view/visuals/bake_lane.gd`: THE WINDOW LANE'S BUDGET IS IN SOLID CELLS A TICK (D0524). A chunk's cost is
## its solid cells, counted off the tick's observation; an air chunk costs nothing and always fits; a chunk
## the un-margined VIEW touches paints this tick whatever the budget says (the view is the promise, the
## margin is the prefetch); the session's first bake is exempt (D0522); digs never spend it. The D0522
## chunk-budget pins moved here from `tests/test_bake_lanes.gd` and were re-derived in the new unit.
##
## **THIS SUITE CANNOT SEE THE PIXELS AND SAYS SO UP FRONT** (as `test_bake_lanes.gd` does): the planner is
## asserted, because `TerrainBake.setup` declines under `--headless`. The observation is posed by hand --
## a byte plane over a window, 0 for air, exactly as `Interface.observe` builds it -- so which chunks are
## solid is the fixture's choice and not the world's.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_bake_budget.gd

const CELL_PX: int = 4
## Worker G's fixture, as `test_bake_lanes.gd` poses it: 188x63 = 11,844 chunks at 64px.
const W_CELLS: int = 3000
const H_CELLS: int = 1000
const CHUNK: int = BakeWindow.CHUNK_PX
const PER_CHUNK: int = BakeWindow.CHUNK_PX / CELL_PX
const CHUNK_CELLS: int = PER_CHUNK * PER_CHUNK
const BUDGET: int = BakeLane.WINDOW_LANE_SOLID_CELLS
## The seat's view at the shell's zoom, as `test_terrain_bake.gd` poses it.
const VIEW_PX := Rect2(4000.0, 1000.0, 214.0, 120.0)
## THE RING: a 2x2 block of painted chunks at columns 61-62, rows 4-5, with a view strictly inside it (4 px
## in from the block's edges) whose 9-cell margin reaches exactly one chunk further on every side. The
## grown window is then the 4x4 block at columns 60-63, rows 3-6: 4 painted, 12 never painted, and NONE of
## the 12 touched by the view itself -- a fall's row of chunks entering the margin, twelve of them at once.
const RING_COL: int = 60
const RING_ROW: int = 3
const RING_VIEW := Rect2(float((RING_COL + 1) * CHUNK + 4), float((RING_ROW + 1) * CHUNK + 4), 120.0, 120.0)


func _initialize() -> void:
	_test_a_chunks_cost_is_its_solid_cells_as_the_observation_sees_them()
	_test_the_first_bake_of_a_session_is_not_budgeted()
	_test_twelve_solid_chunks_entering_at_once_paint_two_a_tick_and_all_within_six()
	_test_twelve_air_chunks_entering_at_once_all_paint_this_tick()
	_test_a_solid_chunk_that_does_not_fit_is_skipped_not_a_stop()
	_test_a_chunk_the_view_touches_paints_this_tick_even_when_the_budget_is_spent()
	_test_a_dig_into_an_entering_chunk_paints_it_whole_and_spends_nothing()
	_finish("bake_budget")


## An observation over `window` (cells) with every cell air except the chunks in `solid`, which are solid
## throughout. Built the way `Interface.observe` builds one: a row-major byte plane, legend index 0 air.
func _observation(w: BakeWindow, window: Rect2i, solid: Array[int]) -> Interface.Observation:
	var obs := Interface.Observation.new()
	obs.window = window
	obs.legend = PackedStringArray(["", "clay"])
	obs.materials = PackedByteArray()
	obs.materials.resize(window.size.x * window.size.y)
	for i: int in solid:
		var cells: Rect2i = w.cells_of(w.chunk_rect(i)).intersection(window)
		for y: int in range(cells.position.y, cells.end.y):
			for x: int in range(cells.position.x, cells.end.x):
				obs.materials[(y - window.position.y) * window.size.x + (x - window.position.x)] = 1
	return obs


## The ring posed on a planner wired as `WorldView` wires it (the fixture's world, the observation margin)
## -- or on `on`, a planner a test has already painted: the inner 2x2 painted, the 12 around it never
## painted, the observation over the 4x4 block with `solid` chunks solid. Returns [planner, window, ring
## (sorted), obs].
func _ring(solid_ring: bool, air: Array[int] = [], on: BakeWindow = null) -> Array:
	var w: BakeWindow = on
	if w == null:
		w = BakeWindow.new()
		w.plan(Vector2i(W_CELLS, H_CELLS), CELL_PX)
		w.set_margin(WorldView.WINDOW_MARGIN_CELLS)
	var block: Rect2i = Rect2i(RING_COL * PER_CHUNK, RING_ROW * PER_CHUNK, 4 * PER_CHUNK, 4 * PER_CHUNK)
	var ring: Array[int] = []
	var solid: Array[int] = []
	for cy: int in range(RING_ROW, RING_ROW + 4):
		for cx: int in range(RING_COL, RING_COL + 4):
			var i: int = cy * w.grid().x + cx
			var inner: bool = cx > RING_COL and cx < RING_COL + 3 and cy > RING_ROW and cy < RING_ROW + 3
			if inner:
				w.note_painted(i)
			else:
				ring.append(i)
				if solid_ring and not air.has(i):
					solid.append(i)
	return [w, block, ring, _observation(w, block, solid)]


## Nearest first, by an independent ranking: no chosen chunk's centre is farther from the window's centre
## than any chunk left waiting (ties allowed).
func _check_nearest(w: BakeWindow, view: Rect2, pending: Array[int], chosen: Array[int]) -> void:
	var c: Vector2 = view.get_center()
	var far_chosen: float = 0.0
	var near_left: float = INF
	for i: int in pending:
		var d: float = w.chunk_rect(i).get_center().distance_to(c)
		if chosen.has(i):
			far_chosen = maxf(far_chosen, d)
		else:
			near_left = minf(near_left, d)
	_check(far_chosen <= near_left, "the chunks chosen first are the nearest: farthest chosen %.1f px from "
		% far_chosen + "the centre, nearest left waiting %.1f -- chose %s" % [near_left, str(chosen)])


## THE UNIT: a chunk's cost is its solid cells as the observation sees them. A solid chunk is all of its
## cells, an air chunk none, a half-solid chunk half -- and a chunk the observation only half covers counts
## its unseen half as SOLID (the budget may only be spent on cells it can see), as does every chunk when
## there is no observation at all.
func _test_a_chunks_cost_is_its_solid_cells_as_the_observation_sees_them() -> void:
	var ring: Array = _ring(true)
	var w: BakeWindow = ring[0]
	var window: Rect2i = ring[1]
	var obs: Interface.Observation = ring[3]
	var solid_i: int = ring[2][0]
	var inner_i: int = (RING_ROW + 1) * w.grid().x + RING_COL + 1   # painted, and air in this observation
	var counts: Array[int] = [BakeLane.solid_cells_in(w, solid_i, obs), BakeLane.solid_cells_in(w, inner_i, obs)]
	print("  solid chunk %d: %d cells; air chunk %d: %d cells; chunk cells %d" % [solid_i, counts[0], inner_i,
		counts[1], CHUNK_CELLS])
	_check(counts[0] == CHUNK_CELLS and CHUNK_CELLS == 256, "a solid chunk costs all %d of its cells (%d), "
		% [CHUNK_CELLS, counts[0]] + "and a chunk is 256 cells")
	_check(counts[1] == 0, "an air chunk costs 0 (got %d)" % counts[1])
	# Half solid: the top half of the chunk's rows.
	var half := Interface.Observation.new()
	half.window = window
	half.legend = obs.legend
	half.materials = obs.materials.duplicate()
	var cells: Rect2i = w.cells_of(w.chunk_rect(solid_i))
	for y: int in range(cells.position.y + PER_CHUNK / 2, cells.end.y):
		for x: int in range(cells.position.x, cells.end.x):
			half.materials[(y - window.position.y) * window.size.x + (x - window.position.x)] = 0
	_check(BakeLane.solid_cells_in(w, solid_i, half) == CHUNK_CELLS / 2, "a chunk solid in its top half costs "
		+ "%d (got %d)" % [CHUNK_CELLS / 2, BakeLane.solid_cells_in(w, solid_i, half)])
	# Half seen: an observation whose window stops halfway down the chunk; the unseen rows count solid,
	# so an AIR chunk half outside the window still costs half.
	var narrow: Rect2i = Rect2i(window.position, Vector2i(window.size.x, cells.position.y + PER_CHUNK / 2 - window.position.y))
	var seen := _observation(w, narrow, [])
	_check(BakeLane.solid_cells_in(w, solid_i, seen) == CHUNK_CELLS / 2, "an air chunk the observation covers "
		+ "only the top half of costs the unseen half, %d (got %d)" % [CHUNK_CELLS / 2,
			BakeLane.solid_cells_in(w, solid_i, seen)])
	_check(BakeLane.solid_cells_in(w, inner_i, null) == CHUNK_CELLS, "and with no observation at all every "
		+ "chunk costs its whole %d (got %d)" % [CHUNK_CELLS, BakeLane.solid_cells_in(w, inner_i, null)])


## THE FIRST BAKE OF A SESSION IS EXEMPT (D0522's rule, kept): a window over N solid chunks, nothing painted
## yet, plans all N in one tick although their solid cells are many times the budget. The control is the
## same window one tick later with one more chunk pending: budgeted.
func _test_the_first_bake_of_a_session_is_not_budgeted() -> void:
	var w := BakeWindow.new()
	w.plan(Vector2i(W_CELLS, H_CELLS), CELL_PX)
	w.set_margin(WorldView.WINDOW_MARGIN_CELLS)
	var pending: Array[int] = w.unpainted_in(VIEW_PX)
	var window: Rect2i = w.cells_of(VIEW_PX.grow(float(w.margin() * CELL_PX)))
	var obs: Interface.Observation = _observation(w, window, pending)
	var boot: BakeWindow.Plan = w.plan_tick(VIEW_PX, [], obs)
	_check(boot.whole.size() == pending.size() and boot.lane_solid > BUDGET,
		"the FIRST bake is unbudgeted: %d solid chunks in the window, %d planned, %d solid cells against a "
			% [pending.size(), boot.whole.size(), boot.lane_solid] + "budget of %d" % BUDGET)
	w.note_plan(boot)
	# CONTROL: the ring's twelve solid chunks on the same planner, now that something is painted: budgeted.
	var ring: Array = _ring(true, [], w)
	var p: BakeWindow.Plan = w.plan_tick(RING_VIEW, [], ring[3])
	_check(p.whole.size() < ring[2].size() and p.lane_solid <= BUDGET,
		"CONTROL: once painted, %d solid chunks entering plan %d (%d solid cells of the %d budget)"
			% [ring[2].size(), p.whole.size(), p.lane_solid, BUDGET])


## Drives the ring's window until nothing is pending (or 10 ticks), noting each plan; returns the per-tick
## whole counts and prints them.
func _drain(w: BakeWindow, obs: Interface.Observation, label: String) -> Array[int]:
	var counts: Array[int] = []
	var spent: Array[int] = []
	while w.unpainted_in(RING_VIEW).size() > 0 and counts.size() < 10:
		var p: BakeWindow.Plan = w.plan_tick(RING_VIEW, [], obs)
		counts.append(p.whole.size())
		spent.append(p.lane_solid)
		w.note_plan(p)
	print("  %s: per-tick window-lane counts %s, solid cells spent %s" % [label, str(counts), str(spent)])
	return counts


## TWELVE SOLID CHUNKS ENTERING IN ONE TICK paint two a tick -- 512 solid cells, two chunks of 256 --
## nearest first, none dropped, all twelve painted within six ticks. Under D0522's budget of 4 chunks the
## same fall painted 4 x 1024-cell chunks in one tick, 69-83 ms measured; the number this pin turns on is
## the solid cells a tick, 512, printed beside the counts.
func _test_twelve_solid_chunks_entering_at_once_paint_two_a_tick_and_all_within_six() -> void:
	var ring: Array = _ring(true)
	var w: BakeWindow = ring[0]
	var twelve: Array[int] = ring[2]
	var obs: Interface.Observation = ring[3]
	_check(w.unpainted_in(RING_VIEW).size() == 12 and twelve.size() == 12, "the ring has 12 never-painted "
		+ "chunks entering at once, got %d" % w.unpainted_in(RING_VIEW).size())
	var touching: int = 0
	for i: int in twelve:
		if w.chunk_rect(i).intersects(RING_VIEW):
			touching += 1
	_check(touching == 0, "and none of the 12 touches the view itself (%d do): they are the margin's" % touching)
	var before: int = w.painted_count()
	var first: BakeWindow.Plan = w.plan_tick(RING_VIEW, [], obs)
	_check_nearest(w, RING_VIEW, twelve, first.whole)
	_check(first.whole.size() == 2 and first.lane_solid == BUDGET, "this tick paints 2 of the 12 (got %d), "
		% first.whole.size() + "spending exactly the %d-cell budget (%d)" % [BUDGET, first.lane_solid])
	_check(first.reasons.values().all(func(reason: String) -> bool: return reason == "margin"),
		"offscreen selections retain margin provenance")
	w.note_plan(first)
	var counts: Array[int] = [first.whole.size()]
	counts.append_array(_drain(w, obs, "12 solid"))
	_check(counts == [2, 2, 2, 2, 2, 2], "12 solid chunks paint 2 a tick over 6 ticks, got %s" % str(counts))
	_check(w.painted_count() == before + 12, "painted_count reaches +12 in %d ticks (%d -> %d), none dropped"
		% [counts.size(), before, w.painted_count()])


## TWELVE AIR CHUNKS ENTERING IN ONE TICK all paint this tick: air costs the budget nothing. Under a budget
## in chunks the same twelve took three ticks (4, 4, 4).
func _test_twelve_air_chunks_entering_at_once_all_paint_this_tick() -> void:
	var ring: Array = _ring(false)
	var counts: Array[int] = _drain(ring[0], ring[3], "12 air")
	_check(counts == [12], "12 air chunks paint in one tick, got %s" % str(counts))


## A SOLID CHUNK THAT DOES NOT FIT IS SKIPPED, NOT A STOP: with the ring's four corners air and its eight
## edges solid, the first tick paints the two nearest solid chunks AND all four air corners, which are the
## farthest -- six -- and the remaining six solid chunks two a tick.
func _test_a_solid_chunk_that_does_not_fit_is_skipped_not_a_stop() -> void:
	var corners: Array[int] = []
	var cols: int = (W_CELLS * CELL_PX + CHUNK - 1) / CHUNK
	for cy: int in [RING_ROW, RING_ROW + 3]:
		for cx: int in [RING_COL, RING_COL + 3]:
			corners.append(cy * cols + cx)
	var ring: Array = _ring(true, corners)
	var w: BakeWindow = ring[0]
	_check(w.grid().x == cols, "the corner indices were derived on the planner's own %d columns (%d)" % [w.grid().x, cols])
	var first: BakeWindow.Plan = w.plan_tick(RING_VIEW, [], ring[3])
	var air_in: int = 0
	for i: int in corners:
		if first.whole.has(i):
			air_in += 1
	_check(air_in == 4 and first.whole.size() == 6 and first.lane_solid == BUDGET, "the first tick paints all "
		+ "4 air corners (%d) beside the 2 solid chunks that fit: %d chunks, %d solid cells" % [air_in,
			first.whole.size(), first.lane_solid])
	w.note_plan(first)
	var counts: Array[int] = [first.whole.size()]
	counts.append_array(_drain(w, ring[3], "8 solid + 4 air"))
	_check(counts == [6, 2, 2, 2], "6 this tick then 2 a tick, got %s" % str(counts))


## THE VIEW IS THE PROMISE. The same ring, the view nudged 8 px right and 8 px down so it pokes into the
## ring's east column and south row: five never-painted solid chunks are ON SCREEN, 1280 solid cells, and
## all five paint this tick although the budget is 512 -- the margin is the prefetch, the view is the
## promise. The CONTROL is the un-nudged view of the pin above: two.
func _test_a_chunk_the_view_touches_paints_this_tick_even_when_the_budget_is_spent() -> void:
	var ring: Array = _ring(true)
	var w: BakeWindow = ring[0]
	var nudged: Rect2 = RING_VIEW
	nudged.position += Vector2(8.0, 8.0)
	var on_screen: Array[int] = []
	for i: int in ring[2]:
		if w.chunk_rect(i).intersects(nudged):
			on_screen.append(i)
	_check(on_screen.size() == 5 and on_screen.size() * CHUNK_CELLS > BUDGET, "the nudged view touches %d "
		% on_screen.size() + "never-painted solid chunks, %d solid cells, past the %d budget" % [on_screen.size()
			* CHUNK_CELLS, BUDGET])
	var p: BakeWindow.Plan = w.plan_tick(nudged, [], ring[3])
	var promised: int = 0
	for i: int in on_screen:
		if p.whole.has(i):
			promised += 1
	print("  view promise: on screen %s, planned %s, %d solid cells" % [str(on_screen), str(p.whole), p.lane_solid])
	_check(promised == on_screen.size() and p.lane_solid == on_screen.size() * CHUNK_CELLS,
		"every chunk the view touches paints this tick (%d of %d), spending %d solid cells against a budget "
			% [promised, on_screen.size(), p.lane_solid] + "of %d" % BUDGET)
	_check(p.whole.size() == on_screen.size(), "and with the budget over-spent no margin chunk joins them "
		+ "(%d planned)" % p.whole.size())
	_check(p.reasons.values().all(func(reason: String) -> bool: return reason == "visible"),
		"mandatory visible work is distinguished from optional margin work")


## DIGS ARE NEVER BUDGETED, AND DO NOT SPEND THE BUDGET: a dig into one of the ring's solid chunks paints it
## whole beside the two the lane chose, and the lane still spent exactly its 512.
func _test_a_dig_into_an_entering_chunk_paints_it_whole_and_spends_nothing() -> void:
	var ring: Array = _ring(true)
	var w: BakeWindow = ring[0]
	var dug_chunk: int = ring[2][ring[2].size() - 1]   # the ring's far corner, last to be chosen by distance
	var dug := Vector2i(w.chunk_rect(dug_chunk).get_center() / float(CELL_PX))
	var crossed: Array[int] = []   # the unpainted chunks the dig's rect crosses: whole by the dig lane
	for i: int in w.chunk_count():
		if w.chunk_rect(i).intersects(w.dig_rect([dug])) and not w.is_painted(i):
			crossed.append(i)
	var p: BakeWindow.Plan = w.plan_tick(RING_VIEW, [dug], ring[3])
	var dug_whole: int = 0
	for i: int in crossed:
		if p.whole.has(i):
			dug_whole += 1
	_check(dug_whole == crossed.size() and p.whole.has(dug_chunk), "the dig's %d unpainted chunks all paint "
		% crossed.size() + "whole (%d), the dug chunk %d among them" % [dug_whole, dug_chunk])
	_check(p.reasons[dug_chunk] == "dig", "dig provenance wins over a simultaneous window request")
	_check(p.lane_solid == BUDGET and p.whole.size() == crossed.size() + 2, "and the lane still spent its "
		+ "%d on 2 more (%d spent, %d whole in all)" % [BUDGET, p.lane_solid, p.whole.size()])
