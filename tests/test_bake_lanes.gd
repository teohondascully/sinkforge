extends "res://tests/test_base.gd"

## `view/visuals/bake_window.gd`'s two lanes as D0522 reshaped them: a dig repaints its DILATED RECTANGLE
## clipped per chunk instead of whole chunks, a never-painted chunk that is dug paints whole, a scattered
## dig falls back to whole chunks, the window lane paints at most `WINDOW_LANE_BUDGET` chunks a tick
## nearest the window's centre first (and the session's first bake is exempt), and the baked painters
## visit exactly the cells the eraser clears.
##
## **THIS SUITE CANNOT SEE THE PIXELS AND SAYS SO UP FRONT** (as `test_terrain_bake.gd` does): the
## planner is asserted, because `TerrainBake.setup` declines under `--headless` and the eraser and the
## chunk painters exist only past that point. What the plan says is what `_bake_partial` shows, erases
## and paints -- that wiring is three lines, and it is the part no headless suite can reach.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_bake_lanes.gd

const CELL_PX: int = 4
## The seat's world (3000x1000 cells) so the chunk counts are the shipped ones: 12000x4000px tiles 94x32.
const W_CELLS: int = 3000
const H_CELLS: int = 1000
const CHUNK: int = BakeWindow.CHUNK_PX
const PER_CHUNK: int = BakeWindow.CHUNK_PX / CELL_PX
## The seat's view at the shell's zoom, as `test_terrain_bake.gd` poses it.
const VIEW_PX := Rect2(4000.0, 1000.0, 214.0, 120.0)


func _initialize() -> void:
	_test_the_first_bake_chooses_the_window_and_not_the_world()
	_test_a_chunk_entering_the_window_bakes_once_and_not_again()
	_test_the_dig_path_does_not_read_the_painted_set()
	_test_a_dig_in_a_chunks_middle_repaints_one_partial_of_1_plus_2_margin_cells()
	_test_a_dig_at_a_chunk_edge_splits_the_same_rect_across_its_neighbours()
	_test_a_never_painted_chunk_that_is_dug_paints_whole()
	_test_a_scattered_dig_falls_back_to_whole_chunks()
	_test_the_full_rebake_threshold_still_reads_the_dug_set()
	_test_twelve_chunks_entering_in_one_tick_paint_four_a_tick_nearest_first()
	_test_the_painters_visit_exactly_the_cells_the_eraser_clears()
	_finish("bake_lanes")


## The planner as `WorldView` wires it: the seat's world and the observation margin.
func _lanes() -> BakeWindow:
	var w := BakeWindow.new()
	w.plan(Vector2i(W_CELLS, H_CELLS), CELL_PX)
	w.set_margin(WorldView.WINDOW_MARGIN_CELLS)
	return w


## The cell at the centre of chunk (cx, cy), the one spot where a dilation of `margin` reaches no neighbour.
func _centre_of(cx: int, cy: int) -> Vector2i:
	return Vector2i(cx * PER_CHUNK + PER_CHUNK / 2, cy * PER_CHUNK + PER_CHUNK / 2)


## Every chunk whose own rect overlaps the grown window, by INTERSECTING RECTANGLES rather than the index
## arithmetic under test -- an off-by-one in the selection's `ceil`/`floor` cannot hide behind itself.
func _window_chunks_by_intersection(w: BakeWindow, view: Rect2) -> Array[int]:
	var grown: Rect2 = view.grow(float(w.margin() * CELL_PX))
	var out: Array[int] = []
	for i: int in w.chunk_count():
		if w.chunk_rect(i).intersects(grown):
			out.append(i)
	return out


## **THE FIRST BAKE PAINTS THE VIEW, NOT THE WORLD** (D0506). Ported with legacy's `_bake_terrain_full`,
## boot made every chunk visible and queued its redraw, so the first render painted every solid cell of the
## world at once: measured on a playtest seat, **6.17 s** between the seat writing its receipt and its first
## frame, no physics tick between, the same under Forward+, Mobile and gl_compatibility -- so neither shader
## compilation nor the painters, which cost 2 ms a frame. Asserted as a SELECTION rather than through
## pixels: `setup` declines under `--headless` (D0186), so no suite CI runs has a target to inspect, and the
## selection IS the decision that cost the six seconds. A world much wider than the view (the seat's) --
## a world the window mostly covered could not tell the two bakes apart.
func _test_the_first_bake_chooses_the_window_and_not_the_world() -> void:
	var w: BakeWindow = _lanes()
	var chosen: Array[int] = w.unpainted_in(VIEW_PX)
	var expected: Array[int] = _window_chunks_by_intersection(w, VIEW_PX)
	chosen.sort()
	expected.sort()
	_check(chosen == expected, "the first bake selects the chunks the window+%d-cell margin covers: chose "
		% w.margin() + "%s, the rects that overlap say %s" % [str(chosen), str(expected)])
	_check(chosen.size() * 8 < w.chunk_count(), "and that is %d chunks of the world's %d -- the full-world "
		% [chosen.size(), w.chunk_count()] + "first bake this replaces chose every one")
	# CONTROL: a window over the whole world selects every chunk. Without it the row above passes on a
	# selection returning a handful of chunks for ANY rect -- which would leave the player looking at
	# unpainted target the moment the camera moved, and would read here as a very good number.
	var all_of_it: Array[int] = w.unpainted_in(Rect2(Vector2.ZERO, Vector2(w.world_px())))
	_check(all_of_it.size() == w.chunk_count(), "CONTROL: a window over the whole world selects all %d of "
		% w.chunk_count() + "its chunks (got %d), so %d above is the window and not a cap"
			% [all_of_it.size(), chosen.size()])


## SCROLLING PAINTS THE NEW GROUND ONCE. The window lane's whole risk is bookkeeping: a chunk re-selected
## every tick would repaint the world continuously and cost more than the boot bake it replaced, and one
## never selected would be a permanent hole. The expectation is DERIVED from the two windows rather than
## written down, so a change to the chunk size or the margin moves the test with the code, not against it.
func _test_a_chunk_entering_the_window_bakes_once_and_not_again() -> void:
	var w: BakeWindow = _lanes()
	for i: int in w.unpainted_in(VIEW_PX):
		w.note_painted(i)
	var moved: Rect2 = VIEW_PX
	moved.position.x += float(CHUNK)   # one whole chunk to the right
	var before: Dictionary = {}
	for i: int in w.chunks_in(VIEW_PX):
		before[i] = true
	var entered: Array[int] = []
	for i: int in w.chunks_in(moved):
		if not before.has(i):
			entered.append(i)
	var fresh: Array[int] = w.unpainted_in(moved)
	fresh.sort()
	entered.sort()
	_check(fresh == entered and not entered.is_empty(), "one chunk of camera motion bakes exactly the %d "
		% entered.size() + "chunk(s) that entered the window, %s -- it chose %s" % [str(entered), str(fresh)])
	for i: int in fresh:
		w.note_painted(i)
	_check(w.unpainted_in(moved).is_empty(), "and the NEXT refresh at that window bakes nothing (%d chosen)"
		% w.unpainted_in(moved).size() + ", so a stationary camera does not repaint the ground under it")
	_check(w.unpainted_in(VIEW_PX).is_empty(), "and scrolling BACK bakes nothing either (%d chosen) -- the "
		% w.unpainted_in(VIEW_PX).size() + "target keeps the pixels of a chunk that has scrolled off")


## THE DIG PATH'S DILATION IS UNCHANGED (D0326/D0330) and must not learn about the window. A dug cell
## dilates to every chunk whose shading it reaches; filtering that by what the window has painted would
## leave a neighbouring chunk stale and seam along the boundary as D0330 describes -- visible only after
## mining. (What a PAINTED chunk repaints is the partial rect, below; which chunks are reached is this.)
func _test_the_dig_path_does_not_read_the_painted_set() -> void:
	var w: BakeWindow = _lanes()
	var edge := Vector2i(PER_CHUNK * 8, _centre_of(0, 9).y)   # the first cell of a chunk, its neighbours next door
	var unpainted: Array[int] = w.influenced_chunks(edge)
	_check(unpainted.size() >= 2 and unpainted.has(w.chunk_index(edge)), "a dig at a chunk's first cell "
		+ "dirties its own chunk and the one its shading reaches into (%d)" % unpainted.size())
	w.note_all_painted()
	var painted: Array[int] = w.influenced_chunks(edge)
	_check(painted == unpainted, "and the same dig dirties the same %s once every chunk is painted -- got "
		% str(unpainted) + "%s. The dig lane reads the dilation, never what the window has done" % str(painted))


## The smallest rect containing every value of `parts`, and their summed area -- so a union that matches
## the dig rect can be told from overlapping partials that merely reach as far.
func _union_and_area(parts: Dictionary) -> Array:
	var u := Rect2()
	var area: float = 0.0
	for i: int in parts:
		var r: Rect2 = parts[i]
		u = r if not u.has_area() else u.merge(r)
		area += r.get_area()
	return [u, area]


## THE DIG LANE IS A RECTANGLE, NOT A CHUNK. One cell in the middle of a painted chunk plans exactly one
## partial, for that chunk, of (1 + 2 x margin) cells a side -- 19 at the 9-cell margin -- and no whole
## chunk. Before D0522 the same blow repainted the whole 128-cell chunk (16,384 cells, ~23 ms).
func _test_a_dig_in_a_chunks_middle_repaints_one_partial_of_1_plus_2_margin_cells() -> void:
	var w: BakeWindow = _lanes()
	w.note_all_painted()
	var cell: Vector2i = _centre_of(30, 10)
	var p: BakeWindow.Plan = w.plan_tick(Rect2(), [cell])
	var side: int = 1 + 2 * w.margin()
	_check(p.partial.size() == 1 and p.partial.has(w.chunk_index(cell)),
		"one cell dug at %s plans partials in exactly 1 chunk, its own (%d): %s"
			% [str(cell), w.chunk_index(cell), str(p.partial.keys())])
	var r: Rect2 = p.partial.get(w.chunk_index(cell), Rect2())
	var cells: Rect2i = w.cells_of(r)
	print("  partial for %s: %s = cells %s" % [str(cell), str(r), str(cells)])
	_check(cells.size == Vector2i(side, side), "and that partial is %dx%d cells (1 + 2 x %d), got %s -- a "
		% [side, side, w.margin(), str(cells.size)] + "whole chunk would be %dx%d" % [PER_CHUNK, PER_CHUNK])
	_check(cells.has_point(cell) and cells.position == cell - Vector2i(w.margin(), w.margin()),
		"centred on the dug cell: starts at %s for a dig at %s" % [str(cells.position), str(cell)])
	_check(p.whole.is_empty() and not p.full, "no whole chunk and no full rebake for one cell (whole=%s)"
		% str(p.whole))


## A DIG AT A CHUNK'S FIRST CELL splits the same dilated rect across the chunks it reaches: two at an edge,
## four at a corner. The partials union to `dig_rect` with no overlap, so together they erase and repaint
## exactly the rect and not a pixel twice.
func _test_a_dig_at_a_chunk_edge_splits_the_same_rect_across_its_neighbours() -> void:
	var w: BakeWindow = _lanes()
	w.note_all_painted()
	var edge := Vector2i(20 * PER_CHUNK, _centre_of(0, 12).y)   # first column of chunk column 20
	var corner := Vector2i(20 * PER_CHUNK, 12 * PER_CHUNK)       # first cell of chunk (20, 12)
	for probe: Array in [[edge, 2, "edge"], [corner, 4, "corner"]]:
		var cell: Vector2i = probe[0]
		var p: BakeWindow.Plan = w.plan_tick(Rect2(), [cell])
		var want: Rect2 = w.dig_rect([cell])
		var ua: Array = _union_and_area(p.partial)
		for i: int in p.partial:
			print("  %s dig at %s: chunk %d repaints %s" % [probe[2], str(cell), i, str(p.partial[i])])
		_check(p.partial.size() == probe[1], "a dig at a chunk's %s cell %s plans partials in %d chunks, got %d"
			% [probe[2], str(cell), probe[1], p.partial.size()])
		_check(ua[0] == want, "whose union is the dilated rect %s (got %s)" % [str(want), str(ua[0])])
		_check(is_equal_approx(ua[1], want.get_area()), "with no overlap: %.0f px^2 summed against the "
			% ua[1] + "rect's %.0f" % want.get_area())


## NEVER A PARTIAL OVER UNPAINTED PIXELS. A dug chunk the target does not hold yet paints WHOLE: a partial
## would leave the rest of it a transparent hole beside the fresh paint. The same chunk dug again once
## painted goes partial -- the control that says the first row was the painted set and not the dig.
func _test_a_never_painted_chunk_that_is_dug_paints_whole() -> void:
	var w: BakeWindow = _lanes()
	w.note_plan(w.plan_tick(VIEW_PX, []))            # the first bake: the window only
	var far: Vector2i = _centre_of(80, 20)
	_check(not w.is_painted(w.chunk_index(far)), "the probe chunk %d is outside the painted window"
		% w.chunk_index(far))
	var p: BakeWindow.Plan = w.plan_tick(VIEW_PX, [far])
	_check(p.whole == [w.chunk_index(far)] and p.partial.is_empty(),
		"a dig in a never-painted chunk paints it WHOLE: whole=%s partial=%s" % [str(p.whole), str(p.partial)])
	w.note_plan(p)
	var again: BakeWindow.Plan = w.plan_tick(VIEW_PX, [far])
	_check(again.partial.has(w.chunk_index(far)) and again.whole.is_empty(),
		"CONTROL: the same dig once the chunk is painted plans a partial (whole=%s)" % str(again.whole))
	# And a chunk entering the window in the tick it is dug: whole, once, not whole AND partial.
	var moved: Rect2 = VIEW_PX
	moved.position.x += float(CHUNK)
	var entering: Array[int] = w.unpainted_in(moved)
	_check(not entering.is_empty(), "one chunk of camera motion has %d chunk(s) entering" % entering.size())
	var in_new := Vector2i(w.chunk_rect(entering[0]).get_center() / float(CELL_PX))
	var both: BakeWindow.Plan = w.plan_tick(moved, [in_new])
	_check(both.whole.has(entering[0]) and not both.partial.has(entering[0]),
		"a chunk entering the window AND dug in the same tick paints whole and never partial (whole=%s, "
			% str(both.whole) + "partial keys=%s)" % str(both.partial.keys()))


## A SCATTERED DIG -- cells whose bounding rect covers more than one chunk's area -- falls back to whole
## chunks by `influenced_chunks`, since the rect would be mostly ground nothing touched.
func _test_a_scattered_dig_falls_back_to_whole_chunks() -> void:
	var w: BakeWindow = _lanes()
	w.note_all_painted()
	var a: Vector2i = _centre_of(10, 10)
	var b: Vector2i = _centre_of(13, 10)   # three chunks east: the rect spans 4 chunks of empty ground
	var rect: Rect2 = w.dig_rect([a, b])
	_check(w.is_scattered(rect), "two cells three chunks apart make a %s rect of %.0f px^2, past one chunk's %d"
		% [str(w.cells_of(rect).size), rect.get_area(), CHUNK * CHUNK])
	var p: BakeWindow.Plan = w.plan_tick(Rect2(), [a, b])
	_check(p.partial.is_empty() and p.whole == [w.chunk_index(a), w.chunk_index(b)],
		"and the plan is those two chunks WHOLE, not the four the rect crosses: whole=%s partial=%s"
			% [str(p.whole), str(p.partial.keys())])
	# CONTROL: two cells a few apart share one rect and stay partial.
	var near: BakeWindow.Plan = w.plan_tick(Rect2(), [a, a + Vector2i(3, 2)])
	_check(not w.is_scattered(w.dig_rect([a, a + Vector2i(3, 2)])) and near.whole.is_empty()
		and near.partial.size() == 1, "CONTROL: two cells 3 apart plan 1 partial and no whole chunk (got %d, %d)"
			% [near.partial.size(), near.whole.size()])


## `would_rebake_all` KEEPS READING THE DUG SET, as it did before D0522: one cell in each of enough chunks
## to pass the fraction plans a full rebake; one fewer chunk than that plans them whole (scattered).
func _test_the_full_rebake_threshold_still_reads_the_dug_set() -> void:
	var w: BakeWindow = _lanes()
	w.note_all_painted()
	var limit: int = int(BakeWindow.FULL_REBAKE_CHUNK_FRACTION * w.chunk_count())
	var cells: Array[Vector2i] = []
	for i: int in limit + 1:
		cells.append(_centre_of(i % w.grid().x, i / w.grid().x))
	_check(w.plan_tick(Rect2(), cells).full, "a dig in %d of %d chunks (past the %.2f fraction) plans a FULL "
		% [limit + 1, w.chunk_count(), BakeWindow.FULL_REBAKE_CHUNK_FRACTION] + "rebake")
	cells.resize(limit)
	var p: BakeWindow.Plan = w.plan_tick(Rect2(), cells)
	_check(not p.full and p.whole.size() == limit and p.partial.is_empty(),
		"CONTROL: %d chunks stay under it and plan %d whole chunks (scattered), full=%s"
			% [limit, p.whole.size(), str(p.full)])


## THE WINDOW LANE IS BUDGETED. A window over 12 never-painted chunks (a fall) paints 4 a tick, nearest
## the window's centre first, none dropped: 4, 4, 4. The dig lane is not budgeted and does not spend it.
## The session's FIRST bake is the control the other way: the whole window at once.
func _test_twelve_chunks_entering_in_one_tick_paint_four_a_tick_nearest_first() -> void:
	var w: BakeWindow = _lanes()
	var first: int = w.unpainted_in(VIEW_PX).size()
	var boot: BakeWindow.Plan = w.plan_tick(VIEW_PX, [])
	_check(boot.whole.size() == first and first > BakeWindow.WINDOW_LANE_BUDGET,
		"the FIRST bake is unbudgeted: %d chunks in the window, %d planned (budget %d)"
			% [first, boot.whole.size(), BakeWindow.WINDOW_LANE_BUDGET])
	w.note_plan(boot)
	# A window whose grown rect covers exactly 4x3 chunks, derived from the chunk size and the margin.
	var m: float = float(w.margin() * CELL_PX)
	var view := Rect2(CHUNK * 60 + 1 + m, CHUNK * 3 + 1 + m, CHUNK * 4 - 2 - 2 * m, CHUNK * 3 - 2 - 2 * m)
	var twelve: Array[int] = w.unpainted_in(view)
	_check(twelve.size() == 12, "the window has 12 never-painted chunks entering at once, got %d" % twelve.size())
	var counts: Array[int] = []
	var before: int = w.painted_count()
	var ticks: int = 0
	while w.unpainted_in(view).size() > 0 and ticks < 10:
		var p: BakeWindow.Plan = w.plan_tick(view, [])
		if ticks == 0:
			_check_nearest(w, view, twelve, p.whole)
		counts.append(p.whole.size())
		w.note_plan(p)
		ticks += 1
	print("  per-tick window-lane counts: %s" % str(counts))
	_check(counts == [4, 4, 4], "12 chunks paint 4 a tick over 3 ticks, got %s" % str(counts))
	_check(w.painted_count() == before + 12, "painted_count reaches +12 in %d ticks (%d -> %d), none dropped"
		% [ticks, before, w.painted_count()])
	# DIGS ARE NEVER BUDGETED, and do not spend the budget: a dig into one of 12 fresh chunks paints it
	# whole beside the 4 the window lane chose.
	var w2: BakeWindow = _lanes()
	w2.note_plan(w2.plan_tick(VIEW_PX, []))
	var dug: Vector2i = _centre_of(63, 5)
	var mixed: BakeWindow.Plan = w2.plan_tick(view, [dug])
	_check(mixed.whole.size() == BakeWindow.WINDOW_LANE_BUDGET + 1 and mixed.whole.has(w2.chunk_index(dug)),
		"a dig into an entering chunk paints it whole on top of the %d budgeted: %d whole, dug chunk %d in %s"
			% [BakeWindow.WINDOW_LANE_BUDGET, mixed.whole.size(), w2.chunk_index(dug), str(mixed.whole)])


## Nearest first, by an independent ranking: no chosen chunk's centre is farther from the window's centre
## than any chunk left waiting.
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
	_check(far_chosen <= near_left, "the 4 chosen first are the nearest: farthest chosen %.1f px from the "
		% far_chosen + "centre, nearest left waiting %.1f -- chose %s" % [near_left, str(chosen)])


## THE PAINTERS VISIT EXACTLY THE CELLS THE ERASER CLEARS. `TerrainPainter.visit_rect` overdraws one cell
## past the rect it is handed; the bake hands it `paint_rect` so the visit is the rect's own cells -- 32
## for a chunk, not 34. A second stamping of a wall cell at `WALL_ALPHA` rounds to 1.0 by the blend
## equation and the tooth reads rock; that was a two-cell line along every chunk edge and would have been
## a ring around every dig. Either way, erase and paint must cover the same pixels.
func _test_the_painters_visit_exactly_the_cells_the_eraser_clears() -> void:
	var w: BakeWindow = _lanes()
	var obs := Interface.Observation.new()
	obs.window = Rect2i(0, 0, W_CELLS, H_CELLS)
	var chunk: Rect2 = w.chunk_rect(w.chunk_index(_centre_of(5, 5)))
	var part: Rect2 = w.partials_of(w.dig_rect([_centre_of(5, 5)]))[w.chunk_index(_centre_of(5, 5))]
	for probe: Array in [[chunk, "a whole chunk"], [part, "a dig partial"]]:
		var rect: Rect2 = probe[0]
		var visited: Rect2i = TerrainPainter.visit_rect(obs, w.paint_rect(rect), CELL_PX)
		_check(visited == w.cells_of(rect), "%s %s: the painters visit %s, the eraser clears %s"
			% [probe[1], str(rect), str(visited), str(w.cells_of(rect))])
	# CONTROL: handed the rect itself, the painters overdraw one cell each way -- 34 cells a side of a
	# 32-cell chunk. That is what the bake did before D0522.
	var raw: Rect2i = TerrainPainter.visit_rect(obs, chunk, CELL_PX)
	_check(raw.size == w.cells_of(chunk).size + 2 * Vector2i.ONE * TerrainPainter.OVERDRAW_CELLS,
		"CONTROL: the unshrunk chunk rect visits %s cells against the chunk's %s -- the double-painted edge"
			% [str(raw.size), str(w.cells_of(chunk).size)])
