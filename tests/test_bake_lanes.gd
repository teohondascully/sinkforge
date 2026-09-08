extends "res://tests/test_base.gd"

## `view/visuals/bake_window.gd`'s two lanes as D0522 reshaped them and D0524 re-grained them: a dig repaints
## its DILATED RECTANGLE clipped per chunk instead of whole chunks, a never-painted chunk that is dug paints
## whole, a dig whose influenced chunks painted whole would cost fewer cells than its rect falls back to
## them (the whole-or-rect cut, D0524), and the baked painters visit exactly the cells the eraser clears.
## THE WINDOW LANE'S BUDGET -- solid cells a tick, the first bake exempt, the view promised -- is
## `tests/test_bake_budget.gd`'s (D0524; the D0522 chunk-budget pins moved there).
##
## **THIS SUITE CANNOT SEE THE PIXELS AND SAYS SO UP FRONT** (as `test_terrain_bake.gd` does): the
## planner is asserted, because `TerrainBake.setup` declines under `--headless` and the eraser and the
## chunk painters exist only past that point. What the plan says is what `_bake_partial` shows, erases
## and paints -- that wiring is three lines, and it is the part no headless suite can reach.
##
## AT 16-CELL CHUNKS THE 9-CELL DILATION IS PAST HALF A CHUNK, so one cell's 19x19 rect crosses at least
## 2x2 chunks and, from a chunk's middle, 3x3. "Exactly one partial" is therefore true of no cell; what
## the lane promises is that the partials are EXACTLY the chunks the rect crosses, union to the rect and
## sum to its area. Every expected set below is derived by intersecting rectangles, never written.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_bake_lanes.gd

const CELL_PX: int = 4
## Worker G's fixture (3000x1000 cells): 12000x4000px tiles 188x63 = 11,844 chunks at 64px (D0524), wide
## enough that no window covers a telling share of it. The SHIPPED world is smaller -- 256x1104 cells,
## 16x69 = 1104 chunks.
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
	_test_a_dig_repaints_its_1_plus_2_margin_rect_across_exactly_the_chunks_it_crosses()
	_test_a_dig_at_a_chunk_edge_or_corner_splits_the_same_rect_without_overlap()
	_test_a_never_painted_chunk_that_is_dug_paints_whole()
	_test_a_dig_falls_back_to_whole_chunks_only_when_they_cost_fewer_cells()
	_test_the_full_rebake_threshold_still_reads_the_dug_set()
	_test_the_painters_visit_exactly_the_cells_the_eraser_clears()
	_finish("bake_lanes")


## The planner as `WorldView` wires it: the fixture's world and the observation margin.
func _lanes() -> BakeWindow:
	var w := BakeWindow.new()
	w.plan(Vector2i(W_CELLS, H_CELLS), CELL_PX)
	w.set_margin(WorldView.WINDOW_MARGIN_CELLS)
	return w


## The cell at the centre of chunk (cx, cy).
func _centre_of(cx: int, cy: int) -> Vector2i:
	return Vector2i(cx * PER_CHUNK + PER_CHUNK / 2, cy * PER_CHUNK + PER_CHUNK / 2)


## Every chunk whose own rect overlaps `rect`, by INTERSECTING RECTANGLES rather than the index arithmetic
## under test -- an off-by-one in the selection's `ceil`/`floor` cannot hide behind itself. Sorted.
func _chunks_crossing(w: BakeWindow, rect: Rect2) -> Array[int]:
	var out: Array[int] = []
	for i: int in w.chunk_count():
		if w.chunk_rect(i).intersects(rect):
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
	var expected: Array[int] = _chunks_crossing(w, VIEW_PX.grow(float(w.margin() * CELL_PX)))
	chosen.sort()
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


## THE DIG LANE IS A RECTANGLE, NOT CHUNKS. One cell in the middle of a painted chunk plans partials in
## exactly the chunks its (1 + 2 x margin)-cell rect crosses -- 19 cells at the 9-cell margin, a 3x3 block
## of 16-cell chunks -- and no whole chunk: 361 cells, where whole chunks would be 9 x 256. Before D0522
## the same blow repainted the whole 128-cell chunk (16,384 cells, ~23 ms).
func _test_a_dig_repaints_its_1_plus_2_margin_rect_across_exactly_the_chunks_it_crosses() -> void:
	var w: BakeWindow = _lanes()
	w.note_all_painted()
	var cell: Vector2i = _centre_of(30, 10)
	var p: BakeWindow.Plan = w.plan_tick(Rect2(), [cell])
	var side: int = 1 + 2 * w.margin()
	var rect: Rect2 = w.dig_rect([cell])
	var cells: Rect2i = w.cells_of(rect)
	print("  dig rect for %s: %s = cells %s" % [str(cell), str(rect), str(cells)])
	_check(cells.size == Vector2i(side, side) and cells.position == cell - Vector2i(w.margin(), w.margin()),
		"the rect is %dx%d cells (1 + 2 x %d) starting at cell - margin: got %s at %s"
			% [side, side, w.margin(), str(cells.size), str(cells.position)])
	var keys: Array[int] = []
	keys.assign(p.partial.keys())
	keys.sort()
	var crossed: Array[int] = _chunks_crossing(w, rect)
	_check(keys == crossed and crossed.has(w.chunk_index(cell)), "one cell dug at %s plans partials in "
		% str(cell) + "exactly the %d chunks its rect crosses, its own among them: %s against %s"
			% [crossed.size(), str(keys), str(crossed)])
	var ua: Array = _union_and_area(p.partial)
	_check(ua[0] == rect and is_equal_approx(ua[1], rect.get_area()), "whose union is the rect (%s) and "
		% str(ua[0]) + "whose areas sum to its %.0f px^2 (%.0f): no overlap, no gap" % [rect.get_area(), ua[1]])
	_check(p.whole.is_empty() and not p.full, "no whole chunk and no full rebake for one cell (whole=%s): "
		% str(p.whole) + "%d cells of rect against %d of whole chunks" % [cells.get_area(),
			crossed.size() * PER_CHUNK * PER_CHUNK])


## A DIG AT A CHUNK'S FIRST CELL splits the same dilated rect across the chunks it reaches -- fewer of them
## than from a chunk's middle, since the rect straddles one boundary per axis instead of two. The partials
## union to `dig_rect` with no overlap, so together they erase and repaint exactly the rect and not a pixel
## twice. Expected counts by intersection, not written.
func _test_a_dig_at_a_chunk_edge_or_corner_splits_the_same_rect_without_overlap() -> void:
	var w: BakeWindow = _lanes()
	w.note_all_painted()
	var edge := Vector2i(20 * PER_CHUNK, _centre_of(0, 12).y)   # first column of chunk column 20
	var corner := Vector2i(20 * PER_CHUNK, 12 * PER_CHUNK)       # first cell of chunk (20, 12)
	var middle: int = _chunks_crossing(w, w.dig_rect([_centre_of(20, 12)])).size()
	for probe: Array in [[edge, "edge"], [corner, "corner"]]:
		var cell: Vector2i = probe[0]
		var p: BakeWindow.Plan = w.plan_tick(Rect2(), [cell])
		var want: Rect2 = w.dig_rect([cell])
		var crossed: Array[int] = _chunks_crossing(w, want)
		var keys: Array[int] = []
		keys.assign(p.partial.keys())
		keys.sort()
		var ua: Array = _union_and_area(p.partial)
		for i: int in keys:
			print("  %s dig at %s: chunk %d repaints %s" % [probe[1], str(cell), i, str(p.partial[i])])
		_check(keys == crossed and crossed.size() < middle, "a dig at a chunk's %s cell %s plans partials "
			% [probe[1], str(cell)] + "in exactly the %d chunks its rect crosses (fewer than a middle's %d): %s"
				% [crossed.size(), middle, str(keys)])
		_check(ua[0] == want, "whose union is the dilated rect %s (got %s)" % [str(want), str(ua[0])])
		_check(is_equal_approx(ua[1], want.get_area()), "with no overlap: %.0f px^2 summed against the "
			% ua[1] + "rect's %.0f" % want.get_area())


## NEVER A PARTIAL OVER UNPAINTED PIXELS. A dug chunk the target does not hold yet paints WHOLE: a partial
## would leave the rest of it a transparent hole beside the fresh paint. The same chunks dug again once
## painted go partial -- the control that says the first row was the painted set and not the dig.
func _test_a_never_painted_chunk_that_is_dug_paints_whole() -> void:
	var w: BakeWindow = _lanes()
	w.note_plan(w.plan_tick(VIEW_PX, []))            # the first bake: the window only
	var far: Vector2i = _centre_of(80, 20)
	var crossed: Array[int] = _chunks_crossing(w, w.dig_rect([far]))
	var painted_already: int = 0
	for i: int in crossed:
		if w.is_painted(i):
			painted_already += 1
	_check(painted_already == 0, "the %d chunks the probe dig reaches are all outside the painted window"
		% crossed.size())
	var p: BakeWindow.Plan = w.plan_tick(VIEW_PX, [far])
	_check(p.whole == crossed and p.partial.is_empty(),
		"a dig in never-painted chunks paints every chunk its rect crosses WHOLE: whole=%s partial=%s"
			% [str(p.whole), str(p.partial)])
	w.note_plan(p)
	var again: BakeWindow.Plan = w.plan_tick(VIEW_PX, [far])
	var keys: Array[int] = []
	keys.assign(again.partial.keys())
	keys.sort()
	_check(keys == crossed and again.whole.is_empty(),
		"CONTROL: the same dig once those chunks are painted plans partials in them (whole=%s)" % str(again.whole))
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


## WHOLE CHUNKS ONLY WHEN THEY COST FEWER CELLS THAN THE RECT (D0524). D0522 called a dig "scattered" when
## its rect out-areaed one chunk, which at 16-cell chunks is every dig. The cut is now the two plans' own
## cell counts: two cells twenty chunks apart make a rect of the world's width order, more cells than their
## influenced chunks painted whole, so those paint whole; two cells three chunks apart make a rect that is
## still fewer cells than their 18 whole chunks, so the rect wins. Both counts printed.
func _test_a_dig_falls_back_to_whole_chunks_only_when_they_cost_fewer_cells() -> void:
	var w: BakeWindow = _lanes()
	w.note_all_painted()
	var a: Vector2i = _centre_of(10, 10)
	var far: Vector2i = _centre_of(30, 10)   # twenty chunks east
	var near: Vector2i = _centre_of(13, 10)  # three chunks east
	for probe: Array in [[far, true, "twenty"], [near, false, "three"]]:
		var b: Vector2i = probe[0]
		var influenced: Dictionary = {}
		for c: Vector2i in [a, b]:
			for i: int in w.influenced_chunks(c):
				influenced[i] = true
		var rect_cells: int = w.cells_of(w.dig_rect([a, b])).get_area()
		var whole_cells: int = influenced.size() * PER_CHUNK * PER_CHUNK
		print("  two cells %s chunks apart: rect %d cells, %d whole chunks %d cells" % [probe[2], rect_cells,
			influenced.size(), whole_cells])
		var p: BakeWindow.Plan = w.plan_tick(Rect2(), [a, b])
		var expect_whole: bool = probe[1]
		_check((whole_cells <= rect_cells) == expect_whole, "the cut says whole=%s for %s chunks apart "
			% [str(expect_whole), probe[2]] + "(%d whole against %d rect cells)" % [whole_cells, rect_cells])
		if expect_whole:
			var keys: Array[int] = []
			keys.assign(influenced.keys())
			keys.sort()
			_check(p.partial.is_empty() and p.whole == keys, "and the plan is those %d chunks WHOLE, no partial: "
				% keys.size() + "whole=%s partial=%s" % [str(p.whole), str(p.partial.keys())])
		else:
			_check(p.whole.is_empty() and p.partial.size() == influenced.size(), "CONTROL: and the plan is the "
				+ "rect in %d partials and no whole chunk (got %d, %d)" % [influenced.size(), p.partial.size(),
					p.whole.size()])


## `would_rebake_all` KEEPS READING THE DUG SET, as it did before D0522: enough cells to dirty more than the
## fraction of the world's chunks plan a full rebake; one cell fewer does not. Cells sit on a lattice three
## chunks apart so each dirties its own disjoint block (a 3x3 at this margin, measured on one probe cell
## rather than written), and the counts are derived from the fraction and that block.
func _test_the_full_rebake_threshold_still_reads_the_dug_set() -> void:
	var w: BakeWindow = _lanes()
	w.note_all_painted()
	var per_cell: int = w.influenced_chunks(_centre_of(1, 1)).size()
	var limit: int = int(BakeWindow.FULL_REBAKE_CHUNK_FRACTION * w.chunk_count())
	var n_under: int = limit / per_cell
	var lattice_cols: int = w.grid().x / 3
	var cells: Array[Vector2i] = []
	for i: int in n_under + 1:
		cells.append(_centre_of(3 * (i % lattice_cols) + 1, 3 * (i / lattice_cols) + 1))
	print("  %d chunks dirtied a cell, %d chunks the %.2f fraction of %d" % [per_cell, limit,
		BakeWindow.FULL_REBAKE_CHUNK_FRACTION, w.chunk_count()])
	_check(w.plan_tick(Rect2(), cells).full, "%d cells dirtying %d chunks (past the %d of the fraction) plan a "
		% [n_under + 1, (n_under + 1) * per_cell, limit] + "FULL rebake")
	cells.resize(n_under)
	var p: BakeWindow.Plan = w.plan_tick(Rect2(), cells)
	_check(not p.full and p.whole.size() + p.partial.size() > 0,
		"CONTROL: %d cells dirtying %d chunks stay under it (full=%s; %d whole, %d partial)"
			% [n_under, n_under * per_cell, str(p.full), p.whole.size(), p.partial.size()])


## THE PAINTERS VISIT EXACTLY THE CELLS THE ERASER CLEARS. `TerrainPainter.visit_rect` overdraws one cell
## past the rect it is handed; the bake hands it `paint_rect` so the visit is the rect's own cells -- 16
## for a chunk, not 18. A second stamping of a wall cell at `WALL_ALPHA` rounds to 1.0 by the blend
## equation and the tooth reads rock; that was a two-cell line along every chunk edge and would have been
## a ring around every dig. Either way, erase and paint must cover the same pixels.
func _test_the_painters_visit_exactly_the_cells_the_eraser_clears() -> void:
	var w: BakeWindow = _lanes()
	var obs := Interface.Observation.new()
	obs.window = Rect2i(0, 0, W_CELLS, H_CELLS)
	var chunk: Rect2 = w.chunk_rect(w.chunk_index(_centre_of(5, 5)))
	# A dig three cells into chunk (5, 5): its own chunk's partial is the rect's inner corner, 13x13 cells.
	var off: Vector2i = Vector2i(5 * PER_CHUNK + 3, 5 * PER_CHUNK + 3)
	var part: Rect2 = w.partials_of(w.dig_rect([off]))[w.chunk_index(off)]
	for probe: Array in [[chunk, "a whole chunk"], [part, "a dig partial"]]:
		var rect: Rect2 = probe[0]
		var visited: Rect2i = TerrainPainter.visit_rect(obs, w.paint_rect(rect), CELL_PX)
		_check(visited == w.cells_of(rect) and rect.has_area(), "%s %s: the painters visit %s, the eraser clears %s"
			% [probe[1], str(rect), str(visited), str(w.cells_of(rect))])
	_check(w.cells_of(part).size != w.cells_of(chunk).size, "and the partial (%s cells) is not the chunk (%s), "
		% [str(w.cells_of(part).size), str(w.cells_of(chunk).size)] + "so the two rows above are two shapes")
	# CONTROL: handed the rect itself, the painters overdraw one cell each way -- 18 cells a side of a
	# 16-cell chunk. That is what the bake did before D0522.
	var raw: Rect2i = TerrainPainter.visit_rect(obs, chunk, CELL_PX)
	_check(raw.size == w.cells_of(chunk).size + 2 * Vector2i.ONE * TerrainPainter.OVERDRAW_CELLS,
		"CONTROL: the unshrunk chunk rect visits %s cells against the chunk's %s -- the double-painted edge"
			% [str(raw.size), str(w.cells_of(chunk).size)])
