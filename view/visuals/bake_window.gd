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

## Legacy `CHUNK` is 16 cells of 32px = 512 world px per chunk side. Held as world px and divided by this
## build's cell size, so the same PHYSICAL area is covered whatever the cell size becomes. Counting cells
## instead would make a chunk 8x smaller here and multiply the chunk count by 64.
const CHUNK_PX: int = 512

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
	var g: Rect2 = rect.grow(float(_margin_cells * _cell_px))
	var x0: int = maxi(floori(g.position.x / float(CHUNK_PX)), 0)
	var y0: int = maxi(floori(g.position.y / float(CHUNK_PX)), 0)
	var x1: int = mini(ceili(g.end.x / float(CHUNK_PX)) - 1, _cols - 1)
	var y1: int = mini(ceili(g.end.y / float(CHUNK_PX)) - 1, _rows - 1)
	for cy: int in range(y0, y1 + 1):
		for cx: int in range(x0, x1 + 1):
			out.append(cy * _cols + cx)
	return out


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
