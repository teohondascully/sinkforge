class_name BakeWindow
extends RefCounted

## THE CHUNK GRID, AND WHICH OF IT THE TARGET ALREADY HOLDS. Split out of `view/visuals/terrain_bake.gd`
## for exactly the reason `plan` was split out of `setup` there: none of this needs a render target, and
## `TerrainBake.setup` declines under `--headless` (D0186 -- SubViewport tools HANG there rather than
## erroring), so a decision left inside that object is a decision no CI suite can reach. That is this
## repository's dominant failure class -- an instrument that cannot register its subject, arriving as a
## quiet green.
##
## **THE BOOT WINDOW (D0506), AND THE MEASUREMENT THAT MADE IT NECESSARY.** `TerrainBake` was ported with
## legacy's `_bake_terrain_full`: at boot every chunk of the world went visible and queued its own
## redraw, so the FIRST render of the target painted every solid cell of the world at once, at
## `fine_terrain`'s per-cell grain. Measured on a playtest seat (D0503): the seat was ready 3.8 s after
## launch and then spent **6.17 s** producing its first frame with no physics tick in between, the same
## under Forward+, Mobile and gl_compatibility -- so not shader compilation, and not the GDScript
## painters, which cost 2 ms a frame. It was the one-off full-world paint, and nothing else.
##
## The window is the fix. The first bake paints only the chunks the camera can see plus the observation
## margin; a chunk that later scrolls into the window is painted then, once, in the same tick it becomes
## visible. `_painted` is the bookkeeping that makes "once" true -- a chunk already in the target is never
## re-selected, so crossing the same ground twice costs nothing after the first pass, and nothing rebakes
## a chunk that has not been dug.
##
## **ONE MARGIN SERVES BOTH JOBS, and that is not a coincidence.** The dig dilation (D0330) is set from
## the observation margin because that is the widest ring any painter could possibly read. The window
## margin wants exactly the same ring for the same reason: the cells a painter probes just outside the
## view must have been painted, or the outermost drawn column loses its neighbour terms. Holding one
## number means the two cannot drift apart.

## A CHUNK IS 32 CELLS A SIDE (128 world px at 4 px a cell, 8 m), and no longer legacy's AREA (D0522).
## Legacy's `CHUNK` was 16 cells of 32 px = 512 world px, and D0326 carried that area across so a chunk
## covered the same ground; at this build's per-cell grain that made a chunk 128 cells a side, and one
## blow near a chunk corner repainted up to four of them through every baked painter -- Worker G measured
## ~23 ms a chunk at boot, against a 16.7 ms frame. The director, playing: "the whole world freezes every
## single time I mine a block". A 32-cell chunk holds a sixteenth of the cells, and the dig lane below
## repaints only the dilated rect anyway; the chunk is now the unit the window lane paints and budgets.
## Held in world px still, and divided by the cell size, so `chunk_index` stays legacy's arithmetic.
const CHUNK_PX: int = 128

## THE WINDOW LANE'S BUDGET (D0522): at most this many never-painted chunks are painted for the window in
## one tick, nearest the window's centre first; the rest wait for the next tick. A fall can scroll a whole
## row of chunks into the window at once, and painting them all in that tick is the hitch the director
## called "it glitches as it quickly loads another part of the world". The margin ring is the prefetch
## that hides the wait: a chunk enters the grown window `_margin_cells` before the view reaches it. THE
## FIRST BAKE OF A SESSION IS NOT BUDGETED -- nothing is painted yet, so there is no prefetch to hide
## behind, the player is looking at the whole window at once, and a seat's first frame must not show a
## hole. Digs are never budgeted: a dug cell must never show stale for a frame.
const WINDOW_LANE_BUDGET: int = 4

## A dig touching more than this fraction of the world's chunks rebakes everything instead. A full bake
## replays every chunk over the whole target; a partial bake replays the dirty ones PLUS an erase pass.
## Past roughly a third of the world the partial path is doing more work than the full one for no benefit.
##
## THE WINDOW LANE IS DELIBERATELY NOT SUBJECT TO IT. This threshold answers "is a scattered dig cheaper
## replayed whole", and a full replay is bounded by the world. The window lane's cost is bounded by the
## WINDOW, which is the entire point of D0506; routing it through a full rebake on a world small enough
## for the view to cover a third of it would reintroduce the boot paint to save nothing.
const FULL_REBAKE_CHUNK_FRACTION: float = 0.34

## Refuse to build a render target larger than this on either axis. Godot's own limit is driver-dependent
## and a target past it fails at RENDER time, not at construction -- which would surface as a blank world
## rather than as an error. Declining here instead keeps the caller on its per-frame path, which is always
## correct and only slower. 16384 is the smallest maximum-texture-size on any target this project builds for.
const MAX_TARGET_PX: int = 16384

var _cols: int = 0
var _rows: int = 0
var _cell_px: int = 0
var _world_px: Vector2i = Vector2i.ZERO
var _world_cells: Vector2i = Vector2i.ZERO


## ONE TICK'S PLAN, both lanes in one answer (D0522). `whole` paints whole chunks (the window lane, a
## scattered dig, or a dug chunk the target does not hold yet); `partial` maps a chunk index to the rect
## in world px it repaints -- the tick's dilated dig rect clipped to that chunk. `full` means the dig
## dirtied so much of the world that replaying the whole target is cheaper. Pure data, so the decision is
## assertable headless.
class Plan extends RefCounted:
	var full: bool = false
	var whole: Array[int] = []
	var partial: Dictionary = {}

## HOW FAR A DIG'S INFLUENCE SPREADS, and how far past the camera the first bake reaches, in cells. Not a
## tuning knob: a PATCHED REGION MUST BE BYTE-IDENTICAL TO A FULL BAKE, and without this it is not. The
## baked painters all read NEIGHBOURS -- `WallPainter.ao_alpha` probes `AO_RAMP_CELLS` (2) out,
## `TerrainPainter` draws one cell past its rect so a straddling cell is whole, and `RockTone`'s
## carved-edge terms reach `FORM_REACH + 1` (7). So digging one cell changes the painted colour of cells
## up to seven away, and if that cell sits near a chunk boundary the affected cells live in a chunk the
## bake never marked dirty. The result is a permanent seam along chunk edges that appears only after
## mining, only near a boundary, and never in a fresh bake. Legacy carries the same constant for the same
## reason (`fine_terrain.gd:481`).
##
## SET FROM THE OBSERVATION MARGIN by the caller rather than from the painters' own constants, and
## deliberately: the bake does not know which painters it was handed, so deriving from a specific painter
## would silently under-dilate the moment a different set is baked.
var _margin_cells: int = 0

## Chunk indices the target already holds pixels for. A set rather than a count: "have we painted THIS
## chunk" is the question, and a count cannot answer it -- see the memory record on counts without
## membership.
var _painted: Dictionary = {}


## The tiling, computed without a render target. Returns false for a world that cannot be tiled:
## non-positive dimensions, or a target past the smallest maximum texture size this project builds for.
func plan(world_cells: Vector2i, cell_px: int) -> bool:
	_cell_px = cell_px
	_world_cells = world_cells
	_world_px = Vector2i(world_cells.x * cell_px, world_cells.y * cell_px)
	_cols = 0
	_rows = 0
	_painted.clear()
	if world_cells.x <= 0 or world_cells.y <= 0 or cell_px <= 0:
		return false
	if _world_px.x > MAX_TARGET_PX or _world_px.y > MAX_TARGET_PX:
		return false
	_cols = ceili(float(_world_px.x) / float(CHUNK_PX))
	_rows = ceili(float(_world_px.y) / float(CHUNK_PX))
	return true


func set_margin(cells: int) -> void:
	_margin_cells = maxi(cells, 0)


func margin() -> int:
	return _margin_cells


func grid() -> Vector2i:
	return Vector2i(_cols, _rows)


func chunk_count() -> int:
	return _cols * _rows


func world_px() -> Vector2i:
	return _world_px


func cell_px() -> int:
	return _cell_px


## Legacy `world_renderer.gd:745-748`. The row-major index of the chunk owning `cell`, or -1 outside the
## world.
func chunk_index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0:
		return -1
	var px: Vector2i = cell * _cell_px
	if px.x >= _world_px.x or px.y >= _world_px.y:
		return -1
	return (px.y / CHUNK_PX) * _cols + (px.x / CHUNK_PX)


## One chunk's rect in world pixels, for the eraser that blanks it before it repaints.
func chunk_rect(i: int) -> Rect2:
	if _cols <= 0:
		return Rect2()
	return Rect2(float((i % _cols) * CHUNK_PX), float((i / _cols) * CHUNK_PX),
		float(CHUNK_PX), float(CHUNK_PX))


## A pixel rect as the terrain cells it covers.
func cells_of(rect: Rect2) -> Rect2i:
	var px: int = maxi(_cell_px, 1)
	var lo := Vector2i(int(floor(rect.position.x / float(px))), int(floor(rect.position.y / float(px))))
	var hi := Vector2i(int(ceil(rect.end.x / float(px))), int(ceil(rect.end.y / float(px))))
	return Rect2i(lo, hi - lo)


## THE RECT A BAKED PAINTER IS HANDED SO THAT IT PAINTS EXACTLY THE CELLS OF `rect` AND NOT ONE MORE
## (D0522). `TerrainPainter.visit_rect` draws `OVERDRAW_CELLS` past the rect it is given, so a screen-edge
## cell the view straddles is drawn whole; a bake rect is cell-aligned and its neighbour paints its own
## cells, so in the bake that overdraw painted every boundary cell TWICE -- and a wall cell is stamped at
## `WallPainter.WALL_ALPHA` (254/255) precisely so the tooth can tell it from rock. By the blend equation
## a second stamping lands at 254.996/255, which round-to-nearest stores as 1.0 and the tooth reads as rock
## (arithmetic, D0522; not observed on the GPU): a two-cell line along every chunk edge, and a partial
## rect would have drawn the same line around every dig. Shrunk by the overdraw, the visit is the rect's
## own cells, and the erase and the paint cover the same pixels whatever the GPU rounds. Pure, so the
## equality is pinned against `visit_rect` itself in `tests/test_bake_lanes.gd`.
func paint_rect(rect: Rect2) -> Rect2:
	return rect.grow(-float(TerrainPainter.OVERDRAW_CELLS * _cell_px))


## Every chunk a change at `cell` can alter: its own, plus any chunk the dilation reaches. Returned as a
## list rather than folded into the caller so it is assertable directly -- the failure it guards is a seam
## that appears only after digging near a boundary, which no fresh-world capture can show.
func influenced_chunks(cell: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var seen: Dictionary = {}
	for dx: int in [-_margin_cells, 0, _margin_cells]:
		for dy: int in [-_margin_cells, 0, _margin_cells]:
			var i: int = chunk_index(Vector2i(cell.x + dx, cell.y + dy))
			if i >= 0 and not seen.has(i):
				seen[i] = true
				out.append(i)
	return out


## Would a partial bake of this many dirty chunks cost more than replaying the whole target? Pure, so the
## threshold is assertable without a render target.
func would_rebake_all(dirty_chunks: int, total_chunks: int) -> bool:
	return float(dirty_chunks) / float(maxi(total_chunks, 1)) > FULL_REBAKE_CHUNK_FRACTION


## THE SELECTION (D0506): every chunk the camera's window touches, grown by the observation margin, in
## row-major order. `rect` is the view in world pixels -- `WorldView.view_world_rect()`, the same rect the
## per-frame observation is built from, so the bake and the observation cannot disagree about what is on
## screen.
##
## A rect with no area selects nothing, rather than the margin ring around a point. A caller with no
## window yet has not asked for chunks; growing an empty rect would quietly bake the world's top-left
## corner and call it the view.
func chunks_in(rect: Rect2) -> Array[int]:
	var out: Array[int] = []
	if _cols <= 0 or _rows <= 0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return out
	var span: Rect2i = _chunk_span(rect.grow(float(_margin_cells * _cell_px)))
	for cy: int in range(span.position.y, span.end.y):
		for cx: int in range(span.position.x, span.end.x):
			out.append(cy * _cols + cx)
	return out


## The chunk columns and rows a world-px rect touches, clamped to the grid: `position` is the first
## column and row, `end` one past the last. Shared by the window selection and the dig partials.
func _chunk_span(g: Rect2) -> Rect2i:
	var x0: int = maxi(floori(g.position.x / float(CHUNK_PX)), 0)
	var y0: int = maxi(floori(g.position.y / float(CHUNK_PX)), 0)
	var x1: int = mini(ceili(g.end.x / float(CHUNK_PX)), _cols)
	var y1: int = mini(ceili(g.end.y / float(CHUNK_PX)), _rows)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


## The chunks of `chunks_in(rect)` the target does not hold yet -- what a bake actually has to paint. Empty
## on the overwhelming majority of ticks, which is what makes the per-tick check free.
func unpainted_in(rect: Rect2) -> Array[int]:
	var out: Array[int] = []
	for i: int in chunks_in(rect):
		if not _painted.has(i):
			out.append(i)
	return out


func note_painted(i: int) -> void:
	_painted[i] = true


func note_all_painted() -> void:
	for i: int in chunk_count():
		_painted[i] = true


func is_painted(i: int) -> bool:
	return _painted.has(i)


func painted_count() -> int:
	return _painted.size()


## THE DIG LANE'S RECTANGLE (D0522): the tick's dug cells as ONE rect in world px -- their bounding box
## grown by the margin, clamped to the world. Before this a dig repainted WHOLE chunks: the erase rect was
## the chunk rect and every baked painter ran over every cell of it, so one blow near a corner repainted
## four chunks at per-cell grain. Nothing outside this rect can change colour, by the margin's own
## construction (`_margin_cells` above), so nothing outside it is repainted. Empty when nothing was dug.
func dig_rect(dug: Array) -> Rect2:
	if dug.is_empty() or _cols <= 0:
		return Rect2()
	var lo: Vector2i = dug[0]
	var hi: Vector2i = dug[0]
	for c: Vector2i in dug:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var m := Vector2i(_margin_cells, _margin_cells)
	var cells: Rect2i = Rect2i(lo - m, hi - lo + Vector2i.ONE + 2 * m).intersection(
		Rect2i(Vector2i.ZERO, _world_cells))
	if cells.size.x <= 0 or cells.size.y <= 0:
		return Rect2()
	return Rect2(Vector2(cells.position * _cell_px), Vector2(cells.size * _cell_px))


## A SCATTERED DIG falls back to whole chunks: when the dug cells' bounding rect covers more than one
## chunk's area, the rect is mostly ground nothing touched (two cells at opposite ends of the world would
## make it the world), and `influenced_chunks` per cell is the tighter answer. Pure, so the cut is
## assertable.
func is_scattered(rect: Rect2) -> bool:
	return rect.get_area() > float(CHUNK_PX * CHUNK_PX)


## The rect clipped to each chunk it crosses: chunk index -> `rect` ∩ that chunk's rect, in world px. The
## values union to `rect`, so erasing and repainting them is erasing and repainting the rect, chunk by
## chunk, through each chunk's own retained draw list.
func partials_of(rect: Rect2) -> Dictionary:
	var out: Dictionary = {}
	if _cols <= 0 or _rows <= 0 or not rect.has_area():
		return out
	var span: Rect2i = _chunk_span(rect)
	for cy: int in range(span.position.y, span.end.y):
		for cx: int in range(span.position.x, span.end.x):
			var i: int = cy * _cols + cx
			var part: Rect2 = chunk_rect(i).intersection(rect)
			if part.has_area():
				out[i] = part
	return out


## THE WINDOW LANE, BUDGETED: the never-painted chunks of the grown window, minus `exclude` (the chunks
## the dig lane already paints whole this tick, which do not spend the budget), nearest the window's
## centre first, at most `WINDOW_LANE_BUDGET` of them -- except on the session's first bake, which paints
## the whole window (see the constant). Ties in distance break by index so the order is deterministic.
func window_lane(rect: Rect2, exclude: Dictionary) -> Array[int]:
	var pending: Array[int] = []
	for i: int in unpainted_in(rect):
		if not exclude.has(i):
			pending.append(i)
	if _painted.is_empty() or pending.size() <= WINDOW_LANE_BUDGET:
		return pending
	var centre: Vector2 = rect.get_center()
	pending.sort_custom(func(a: int, b: int) -> bool:
		var da: float = chunk_rect(a).get_center().distance_squared_to(centre)
		var db: float = chunk_rect(b).get_center().distance_squared_to(centre)
		return da < db if da != db else a < b)
	return pending.slice(0, WINDOW_LANE_BUDGET)


## ONE TICK'S PLAN OVER BOTH LANES (D0506, D0522). The full-rebake threshold reads the dug set as it
## always has -- the chunks the dilation reaches -- and never the window. Otherwise the dig lane is the
## dilated rect, clipped per chunk, for every chunk the target already holds; a dug chunk the target does
## NOT hold yet paints whole (a partial over unpainted pixels would leave the rest of it a hole), and so
## does every chunk of a scattered dig. The window lane comes last and is budgeted. The two maps are
## disjoint by construction: partials go only to painted chunks, the window lane only to unpainted ones.
func plan_tick(window_rect: Rect2, dug: Array) -> Plan:
	var p := Plan.new()
	var influenced: Dictionary = {}
	for cell: Vector2i in dug:
		for i: int in influenced_chunks(cell):
			influenced[i] = true
	if not influenced.is_empty() and would_rebake_all(influenced.size(), chunk_count()):
		p.full = true
		return p
	var whole: Dictionary = {}
	var rect: Rect2 = dig_rect(dug)
	if rect.has_area() and not is_scattered(rect):
		var parts: Dictionary = partials_of(rect)
		for i: int in parts:
			if _painted.has(i):
				p.partial[i] = parts[i]
			else:
				whole[i] = true
	else:
		for i: int in influenced:
			whole[i] = true
	for i: int in window_lane(window_rect, whole):
		whole[i] = true
	p.whole.assign(whole.keys())
	p.whole.sort()
	return p


## Records the plan's whole-chunk paints in the painted set. A partial changes nothing here: the chunk was
## painted already, and stays so.
func note_plan(p: Plan) -> void:
	for i: int in p.whole:
		_painted[i] = true
