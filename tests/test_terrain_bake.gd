extends "res://tests/test_base.gd"

## `view/visuals/terrain_bake.gd` — legacy's bake-once-draw-one-quad architecture (D0326,
## `docs/PORT_ORDER.md` V1).
##
## **THIS SUITE CANNOT SEE THE PIXELS AND SAYS SO UP FRONT.** `TerrainBake.setup()` declines under
## `--headless` on purpose — SubViewport tools HANG there rather than erroring (D0186) — so CI never
## constructs a render target and no assertion below is about a rendered image. What CI *can* run is the
## part that decides the picture: the tiling, the bounds rule, the full-rebake threshold, and the fallback.
## Those were split out of `setup` into `plan`/`would_rebake_all` specifically so they are reachable from
## here, because a bake whose arithmetic is exercised by nothing is this repository's dominant failure class
## — an instrument that cannot register its subject, arriving as a quiet green.
##
## The two things this suite deliberately does NOT claim, so a later reader does not over-read a green:
## that the baked picture matches the per-frame picture (that is a capture comparison, on a headed run), and
## that the bake is faster (that is a timing layer, which must run alone — see `add_excl`).
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_terrain_bake.gd

const CELL_PX: int = 4
## A world big enough to need several chunks on both axes: 512px chunks over 4px cells is 128 cells a side,
## so 300x300 cells is 1200x1200px and tiles 3x3. Chosen so a row-major index bug cannot pass by symmetry.
const W_CELLS: int = 300
const H_CELLS: int = 300


func _initialize() -> void:
	_test_every_cell_lands_in_exactly_one_chunk_and_every_chunk_is_used()
	_test_a_cell_outside_the_world_has_no_chunk()
	_test_a_dig_near_a_chunk_edge_dirties_the_neighbouring_chunk()
	_test_a_chunk_spans_legacys_world_AREA_not_legacys_cell_COUNT()
	_test_plan_refuses_a_world_it_cannot_tile()
	_test_the_full_rebake_threshold_decides_both_ways()
	_test_when_the_bake_declines_the_painters_still_get_mounted()
	_test_the_first_bake_chooses_the_window_and_not_the_world()
	_test_a_chunk_entering_the_window_bakes_once_and_not_again()
	_test_the_dig_path_does_not_read_the_painted_set()
	_finish("terrain_bake")


## A WORLD MUCH WIDER THAN THE VIEW, and a view the size the seat renders: 3000x1000 cells of 4px is
## 12000x4000px, tiling 24x8 = 192 chunks, against a 1280x720 seat at the shell's zoom (~214x120 world px,
## smaller than one 512px chunk). A world the window mostly covered could not tell the two bakes apart.
const WIDE_W_CELLS: int = 3000
const WIDE_H_CELLS: int = 1000
const VIEW_PX := Rect2(4000.0, 1000.0, 214.0, 120.0)


## The bake as `WorldView` builds it -- through `setup`, with the coordinator's own margin, which `setup`
## sets before it declines headless. The real wiring, not a hand-posed grid. **The caller must `free()`.**
func _wide() -> TerrainBake:
	var bake := TerrainBake.new()
	bake.setup(Vector2i(WIDE_W_CELLS, WIDE_H_CELLS), CELL_PX, Callable(), null, null, [],
		WorldView.WINDOW_MARGIN_CELLS)
	return bake


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
## selection IS the decision that cost the six seconds.
func _test_the_first_bake_chooses_the_window_and_not_the_world() -> void:
	var bake: TerrainBake = _wide()
	var w: BakeWindow = bake.window()
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
	bake.free()


## SCROLLING PAINTS THE NEW GROUND ONCE. The window lane's whole risk is bookkeeping: a chunk re-selected
## every tick would repaint the world continuously and cost more than the boot bake it replaced, and one
## never selected would be a permanent hole. The expectation is DERIVED from the two windows rather than
## written down, so a change to the chunk size or the margin moves the test with the code, not against it.
func _test_a_chunk_entering_the_window_bakes_once_and_not_again() -> void:
	var bake: TerrainBake = _wide()
	var w: BakeWindow = bake.window()
	for i: int in w.unpainted_in(VIEW_PX):
		w.note_painted(i)
	var moved: Rect2 = VIEW_PX
	moved.position.x += float(TerrainBake.CHUNK_PX)   # one whole chunk to the right
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
	bake.free()


## THE DIG PATH IS UNCHANGED (D0326/D0330) and must not learn about the window. `bake_cells` dilates a dug
## cell to every chunk whose shading it reaches; filtering that by what the window has painted would leave a
## neighbouring chunk stale and seam along the boundary as D0330 describes -- visible only after mining.
func _test_the_dig_path_does_not_read_the_painted_set() -> void:
	var bake: TerrainBake = _wide()
	var w: BakeWindow = bake.window()
	var per_chunk: int = TerrainBake.CHUNK_PX / CELL_PX
	var edge := Vector2i(per_chunk * 8, 300)          # the first cell of a chunk, its neighbours next door
	var unpainted: Array[int] = bake.influenced_chunks(edge)
	_check(unpainted.size() >= 2 and unpainted.has(bake.chunk_index(edge)), "a dig at a chunk's first cell "
		+ "dirties its own chunk and the one its shading reaches into (%d)" % unpainted.size())
	for i: int in w.chunk_count():
		w.note_painted(i)
	var painted: Array[int] = bake.influenced_chunks(edge)
	_check(painted == unpainted, "and the same dig dirties the same %s once every chunk is painted -- got "
		% str(unpainted) + "%s. The dig lane reads the dilation, never what the window has done" % str(painted))
	bake.free()


## A planned bake, and **the caller must `free()` it**. `TerrainBake` is a `Node2D` and a Node outside the
## scene tree is NOT reference-counted, so an orphan leaks its CanvasItem RID — which `tools/run_gd_test.sh`
## reports as an engine-level ERROR and fails the suite on, however many assertions passed.
func _planned() -> TerrainBake:
	var bake := TerrainBake.new()
	bake.plan(Vector2i(W_CELLS, H_CELLS), CELL_PX)
	return bake


## THE TILING IS A PARTITION: every cell in the world maps to a chunk, every index is in range, and every
## chunk is actually reached. The last clause is the one that matters — an off-by-one in `_chunk_cols` gives
## a mapping that is still total and still in range while silently never addressing the final column, so a
## dig there would never invalidate anything and the ghost would only appear at one edge of the world.
func _test_every_cell_lands_in_exactly_one_chunk_and_every_chunk_is_used() -> void:
	var bake: TerrainBake = _planned()
	var total: int = bake.planned_chunk_count()
	var seen: Dictionary = {}
	var checked: int = 0
	var out_of_range: int = 0
	for col: int in W_CELLS:
		for row: int in H_CELLS:
			var i: int = bake.chunk_index(Vector2i(col, row))
			checked += 1
			if i < 0 or i >= total:
				out_of_range += 1
			else:
				seen[i] = true
	_check_over(checked, out_of_range == 0,
		"every cell in a %dx%d world maps to a chunk index inside [0,%d) -- %d did not"
			% [W_CELLS, H_CELLS, total, out_of_range])
	_check(bake.chunk_grid() == Vector2i(3, 3),
		"a 1200x1200px world tiles 3x3 at %dpx chunks, got %s" % [TerrainBake.CHUNK_PX, bake.chunk_grid()])
	_check(seen.size() == total,
		"every one of the %d chunks is addressed by some cell -- %d were reachable" % [total, seen.size()])
	bake.free()


## Outside the world is -1, in all four directions, and the control is that the corners INSIDE are not.
## Without the control this passes on a `chunk_index` that returned -1 for everything, which is exactly the
## shape that would disable dig invalidation completely while every other assertion here stayed green.
func _test_a_cell_outside_the_world_has_no_chunk() -> void:
	var bake: TerrainBake = _planned()
	var outside: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(W_CELLS, 0), Vector2i(0, H_CELLS),
		Vector2i(-1, -1), Vector2i(W_CELLS, H_CELLS),
	]
	var rejected: int = 0
	for c: Vector2i in outside:
		if bake.chunk_index(c) < 0:
			rejected += 1
	_check_over(outside.size(), rejected == outside.size(),
		"a cell outside the world has no chunk -- %d of %d rejected" % [rejected, outside.size()])
	# CONTROL: the cells just inside those same edges DO have one.
	var inside: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(W_CELLS - 1, 0), Vector2i(0, H_CELLS - 1),
		Vector2i(W_CELLS - 1, H_CELLS - 1),
	]
	var accepted: int = 0
	for c: Vector2i in inside:
		if bake.chunk_index(c) >= 0:
			accepted += 1
	_check_over(inside.size(), accepted == inside.size(),
		"CONTROL: all four corners INSIDE the world do have a chunk -- %d of %d, so the row above is a "
			% [accepted, inside.size()] + "real bounds test and not a function that rejects everything")
	bake.free()


## **THE SEAM THIS BAKE SHIPPED WITH, and the reason a partial re-bake needs a dilation** (D0330).
##
## Every baked painter reads NEIGHBOURS: `WallPainter.ao_alpha` probes 2 cells, `TerrainPainter` draws one
## past its rect, and `RockTone`'s carved-edge terms reach `FORM_REACH + 1` = 7. Digging one cell therefore
## changes the painted colour of cells up to seven away — and a cell near a chunk boundary has those
## neighbours in a DIFFERENT chunk. Marking only the dug cell's own chunk leaves that neighbour stale.
##
## The failure is a permanent seam along chunk edges, visible only after mining, only near a boundary, and
## never in a fresh bake — so a capture of a newly generated world looks perfect while the defect
## accumulates as the player digs. Legacy carries the same dilation for the same stated reason
## (`fine_terrain.gd:481`): a patched region must be byte-identical to a full bake.
##
## Asserted on `influenced_chunks` rather than through a picture, because no picture of an un-dug world
## can show it.
func _test_a_dig_near_a_chunk_edge_dirties_the_neighbouring_chunk() -> void:
	var bake: TerrainBake = _planned()
	# `plan` alone does not set the margin (that is `setup`, which declines headless), so pose it the way
	# `WorldView` does -- from the observation margin, the widest ring any painter could read.
	bake.free()
	var b := TerrainBake.new()
	b.setup(Vector2i(W_CELLS, H_CELLS), CELL_PX, Callable(), null, null, [], WorldView.WINDOW_MARGIN_CELLS)
	# setup() declines headless BEFORE building chunks, but `plan` and the margin are set first by design.
	_check(b.rebake_margin() == WorldView.WINDOW_MARGIN_CELLS,
		"the dilation is the observation margin (%d), not a written literal" % b.rebake_margin())
	# A cell one inside a chunk's left edge. 512px chunks over 4px cells = 128 cells per chunk, so column
	# 128 is the first cell of chunk column 1 and its left neighbours live in chunk column 0.
	var per_chunk: int = TerrainBake.CHUNK_PX / CELL_PX
	var edge := Vector2i(per_chunk, 200)
	var touched: Array[int] = b.influenced_chunks(edge)
	_check(touched.size() >= 2,
		"a dig at the first cell of a chunk dirties %d chunks, not just its own" % touched.size())
	_check(touched.has(b.chunk_index(edge)) and touched.has(b.chunk_index(edge - Vector2i(1, 0))),
		"and the set contains BOTH its own chunk and the one holding the cells its shading reaches into")
	_check_the_coordinator_actually_passes_the_dilation()
	# CONTROL: a cell deep inside a chunk dirties exactly one. Without this the row above passes on an
	# `influenced_chunks` that returned every chunk in the world, which would silently make every dig a
	# full rebake and undo the entire per-dig fast lane while looking correct.
	var middle := Vector2i(per_chunk / 2, 200)
	var one: Array[int] = b.influenced_chunks(middle)
	_check(one.size() == 1,
		"CONTROL: a dig in a chunk's interior dirties exactly 1 chunk (got %d), so the dilation is "
			% one.size() + "targeted and has not quietly become a full rebake")
	b.free()


## THE CALL SITE, not just the unit. The test above poses its own `TerrainBake` and hands it the margin,
## so it cannot see a `WorldView` that passes 0 -- which is the actual defect and which left the suite
## green as a mutant. Asserted against the painters' own reaches so it is a real bound and not a
## restatement of one constant by another.
func _check_the_coordinator_actually_passes_the_dilation() -> void:
	var grid: TileGrid = TileGrid.new(64, 64, 7)
	for col: int in range(64):
		for row: int in range(32, 64):
			grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(128), Fx.from_int(80))
	var view := WorldView.new()
	root.add_child(view)
	view.setup(Interface.new(grid, body, Mining.new()), MaterialLook.new(), null)
	view.add_baked_painter(WallPainter.paint)
	view.add_baked_painter(TerrainPainter.paint)
	view.bake_static(-60)
	# The deepest neighbour reach among the painters actually baked. Derived from their own constants, so
	# a painter that grows its reach moves this bound instead of silently outrunning it.
	var deepest: int = maxi(WallPainter.AO_RAMP_CELLS, RockTone.FORM_REACH + 1)
	_check(view.bake_margin() >= deepest,
		"the coordinator hands the bake a dilation of %d, covering the deepest painter reach of %d"
			% [view.bake_margin(), deepest])
	_check(view.bake_margin() > 0,
		"and it is not zero -- zero is the seam-along-chunk-edges defect this whole test exists for")
	view.free()


## THE ONE CONSTANT IN THIS FILE THAT IS NOT LEGACY'S NUMBER, and the WG-4 regime question (D0305) in
## miniature. Legacy's `CHUNK` is 16 cells of 32px. Copying the CELL COUNT would give 16 cells of 4px here —
## a chunk 8x smaller on each side, 64x as many of them, and 64x the per-dig bookkeeping for the same world.
## What must be conserved is the AREA a chunk covers, so the constant is held in world pixels.
func _test_a_chunk_spans_legacys_world_AREA_not_legacys_cell_COUNT() -> void:
	const LEGACY_CHUNK_CELLS: int = 16
	const LEGACY_CELL_PX: int = 32
	_check(TerrainBake.CHUNK_PX == LEGACY_CHUNK_CELLS * LEGACY_CELL_PX,
		"a chunk spans legacy's own %dpx (%d cells x %dpx), not its cell count"
			% [TerrainBake.CHUNK_PX, LEGACY_CHUNK_CELLS, LEGACY_CELL_PX])
	# CONTROL: the cell-count reading gives a different, much smaller answer. Stated as a number so the
	# claim above is a comparison rather than a restatement of the constant it reads.
	var naive: int = LEGACY_CHUNK_CELLS * CELL_PX
	_check(naive != TerrainBake.CHUNK_PX,
		"CONTROL: porting the CELL COUNT instead would give %dpx chunks, %dx smaller on a side"
			% [naive, TerrainBake.CHUNK_PX / naive])


## `plan` returns false rather than tiling a world it cannot represent, and the control is that an ordinary
## world passes. A `plan` that always returned false would disable the bake everywhere and be invisible.
func _test_plan_refuses_a_world_it_cannot_tile() -> void:
	var bad: Array = [
		[Vector2i(0, 100), CELL_PX, "zero width"],
		[Vector2i(100, 0), CELL_PX, "zero height"],
		[Vector2i(-4, 100), CELL_PX, "negative width"],
		[Vector2i(100, 100), 0, "zero cell size"],
		[Vector2i(TerrainBake.MAX_TARGET_PX, 100), CELL_PX, "target past the max texture size"],
	]
	var refused: int = 0
	for row: Array in bad:
		var b := TerrainBake.new()
		if not b.plan(row[0] as Vector2i, row[1] as int):
			refused += 1
		else:
			_check(false, "plan should have refused: %s" % row[2])
		b.free()
	_check_over(bad.size(), refused == bad.size(),
		"plan refuses a world it cannot tile -- %d of %d refused" % [refused, bad.size()])
	# CONTROL: an ordinary world is accepted and produces a real grid.
	var ok := TerrainBake.new()
	_check(ok.plan(Vector2i(W_CELLS, H_CELLS), CELL_PX) and ok.planned_chunk_count() > 0,
		"CONTROL: an ordinary %dx%d world plans into %d chunks, so the refusals above are selective"
			% [W_CELLS, H_CELLS, ok.planned_chunk_count()])
	ok.free()


## The partial-vs-full decision, asserted in BOTH directions across the threshold. A one-sided assertion
## here passes on a function that always chose one path, and choosing "full" always would silently undo the
## entire per-dig fast lane — the thing this port exists to add — while the picture stayed correct.
func _test_the_full_rebake_threshold_decides_both_ways() -> void:
	var bake := TerrainBake.new()
	var total: int = 100
	var frac: float = TerrainBake.FULL_REBAKE_CHUNK_FRACTION
	_check(not bake.would_rebake_all(1, total),
		"one dirty chunk in %d takes the PARTIAL path" % total)
	_check(not bake.would_rebake_all(int(frac * total), total),
		"exactly at the %.2f threshold stays PARTIAL (the test is >, not >=)" % frac)
	_check(bake.would_rebake_all(int(frac * total) + 1, total),
		"one chunk past the threshold takes the FULL path")
	_check(bake.would_rebake_all(total, total),
		"every chunk dirty takes the FULL path")
	# A zero total must not divide by zero and must not silently choose partial.
	_check(bake.would_rebake_all(1, 0), "a dirty chunk against a zero-chunk world rebakes rather than "
		+ "dividing by zero")
	bake.free()


## THE FALLBACK IS THE PATH CI ACTUALLY RUNS, so it is the one that must be asserted hardest.
##
## Under `--headless` the bake declines and `WorldView.bake_static` mounts every registered painter as an
## ordinary per-frame layer instead. If that fallback were broken, CI would render nothing and — because
## every current suite asserts painter OUTPUT rather than painter PRESENCE — a great many of them would go
## green over an empty picture. D0289 is the precedent: a painter that was freed at bind time drew nothing
## for four commits while every suite passed.
func _test_when_the_bake_declines_the_painters_still_get_mounted() -> void:
	var grid: TileGrid = TileGrid.new(64, 64, 7)
	for col: int in range(64):
		for row: int in range(32, 64):
			grid.set_material(Vector2i(col, row), &"clay")
			grid.set_wall(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(32 * CELL_PX), Fx.from_int(20 * CELL_PX))
	var iface: Interface = Interface.new(grid, body, Mining.new())
	var view := WorldView.new()
	root.add_child(view)
	view.setup(iface, MaterialLook.new(), null)
	view.add_baked_painter(WallPainter.paint)
	view.add_baked_painter(TerrainPainter.paint)
	var baked: bool = view.bake_static(-60)

	_check(not baked, "headless declines the render target rather than hanging on it (D0186)")
	_check(view.terrain_bake() == null, "and holds no bake object, so nothing tries to invalidate one")
	var live: int = 0
	for child: Node in view.get_children():
		if child is PaintLayer and (child as PaintLayer).painter_is_live():
			live += 1
	_check_over(2, live == 2,
		"both static painters mounted as live per-frame layers instead -- found %d" % live)
	# CONTROL: a WorldView that registered NOTHING mounts nothing, so the count above is reporting the
	# painters and not simply counting children that any WorldView would have.
	var empty := WorldView.new()
	root.add_child(empty)
	empty.setup(iface, MaterialLook.new(), null)
	var empty_live: int = 0
	for child: Node in empty.get_children():
		if child is PaintLayer:
			empty_live += 1
	_check(empty_live == 0,
		"CONTROL: a WorldView with no registered painters mounts %d layers, so 2 above is the subject"
			% empty_live)
	# `free()`, NOT `queue_free()`. A queued free runs on the next process frame and `_finish()` quits
	# before one arrives, so the nodes and their CanvasItem RIDs leak — which `tools/run_gd_test.sh`
	# correctly reports as an engine-level ERROR and fails the suite on, even though every assertion passed.
	view.free()
	empty.free()
