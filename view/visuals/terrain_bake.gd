class_name TerrainBake
extends Node2D

## THE STATIC TERRAIN, DRAWN ONCE INSTEAD OF EVERY FRAME. Ported from `legacy/scenes/world_renderer.gd`
## — the declarations at `:303-312`, the viewport and chunk construction at `:410-435`, `_bake_terrain_full`
## at `:703-711`, `_bake_terrain_chunks` at `:715-735`, `_paint_erase` at `:739-741`, `_chunk_index` at
## `:745-748`, and the one-quad draw at `:1370-1377`. `docs/PORT_ORDER.md` V1; `docs/DECISIONS_LEDGER.md`
## D0326.
##
## **THIS IS THE ARCHITECTURE THAT WAS NEVER PORTED, AND IT IS THE WHOLE PERFORMANCE STORY.** The painters
## came across one at a time and each is correct; what did not come across is legacy's rule about WHEN they
## run. Legacy states it at `world_renderer.gd:756`:
##
##   > "Terrain, background walls and the smoothed surface are static: drawn by the chunked terrain canvases
##   > below this at z -10 and repainted only on the dug chunk. This per-frame pass draws only the live and
##   > sparse content, with no full-world cell loop."
##
## and names the cause at `:698`: **"The bottleneck was GDScript re-issuing the whole world's draw commands
## every frame; the sim itself costs almost nothing."** Legacy measured the coarse terrain at **~72% of the
## frame's draw calls, ~11,882 of them** — issued ONCE into a bake, not per frame.
##
## This build ran every one of those per-cell loops on every rendered frame. Same pixels, ~100x the cost.
## Measured before this landed: 600 ticks at the 40-metre framing took 21.6 s of tick time, **22.5 ticks/s
## against a 120 Hz bar** — 5.3x out of budget on a world legacy ran at speed.
##
## **HOW IT WORKS, and every line of the shape is legacy's.** A world-sized `SubViewport` with a transparent
## background holds one `LightLayer` per chunk of the world. It never re-renders on its own
## (`UPDATE_DISABLED`); a dig flips it to `UPDATE_ONCE` for exactly the chunks that changed. Between
## changes the GPU replays a single textured quad.
##
## **THE ERASER IS NOT OPTIONAL.** A partial re-render can only ADD coverage — alpha blending cannot take
## rock away — so a cell dug open to the sky would keep its old pixels forever. `erase.gdshader`
## (`blend_disabled`) writes straight to the target, so drawing a transparent rect with it is a true clear.
## Ordered below the chunk painters, it blanks each dirty chunk's rect before that chunk repaints.
##
## **EACH CHUNK OBSERVES FOR ITSELF, and this is the one structural difference from legacy.** Legacy's
## painters read the whole world off the sim directly. Here a painter may read only `frame.obs`, which is a
## VALUE covering one window — and `Observation.material_at` answers `&""` for any cell outside the window
## it was given, not "unknown". So handing a chunk the CAMERA's frame would paint every chunk off-screen as
## empty and bake a mostly-blank world, silently, with every gate green. The bake therefore takes an
## `observe(rect)` callable and builds its own `Frame` per chunk. The cost is one observation per chunk at
## bake time — bounded, paid once, and on the dig path paid only for dirty chunks.

## Legacy `CHUNK` is 16 cells of 32px = 512 world px per chunk side. Held as world px and divided by this
## build's cell size, so the same PHYSICAL area is covered whatever the cell size becomes. Counting cells
## instead would make a chunk 8x smaller here and multiply the chunk count by 64.
const CHUNK_PX: int = 512

## A dig touching more than this fraction of the world's chunks rebakes everything instead. A full bake
## replays every chunk over the whole target; a partial bake replays the dirty ones PLUS an erase pass.
## Past roughly a third of the world the partial path is doing more work than the full one for no benefit.
const FULL_REBAKE_CHUNK_FRACTION: float = 0.34

## HOW FAR A DIG'S INFLUENCE SPREADS, in cells, and this is not a tuning knob.
##
## **A PATCHED REGION MUST BE BYTE-IDENTICAL TO A FULL BAKE, and without this it is not.** The baked
## painters all read NEIGHBOURS: `WallPainter.ao_alpha` probes `AO_RAMP_CELLS` (2) out, `TerrainPainter`
## draws one cell past its rect so a straddling cell is whole, and `RockTone`'s carved-edge terms reach
## `FORM_REACH + 1` (7). So digging one cell changes the painted colour of cells up to seven away — and if
## that cell sits near a chunk boundary, the affected cells live in a chunk this bake never marked dirty.
##
## The result is a permanent seam along chunk edges that appears only after mining, only near a boundary,
## and never in a fresh bake — so a screenshot of a newly generated world looks perfect and the defect
## accumulates as the player digs. Legacy carries the same constant for the same reason and states it
## exactly (`fine_terrain.gd:481`): *"It must cover the widest neighbour reach any paint term reads, or a
## patched region stops being byte-identical to a full bake."*
##
## SET FROM THE OBSERVATION MARGIN rather than from the painters' own constants, and deliberately. The
## bake does not know which painters it was handed — that is the caller's business — so deriving from a
## specific painter would silently under-dilate the moment a different set is baked. The observation
## margin is the widest ring any painter could POSSIBLY read, because a painter reading past it is already
## reading `&""` for cells it was never given. Over-dilating costs at most a few extra chunks per dig;
## under-dilating is a permanent visual defect.
var _rebake_margin: int = 0

## Refuse to build a render target larger than this on either axis. Godot's own limit is driver-dependent
## and a target past it fails at RENDER time, not at construction — which would surface as a blank world
## rather than as an error. Declining here instead keeps the caller on its per-frame path, which is always
## correct and only slower. 16384 is the smallest maximum-texture-size on any target this project builds for.
const MAX_TARGET_PX: int = 16384

var _viewport: SubViewport = null
var _chunks: Array[LightLayer] = []
var _chunk_cols: int = 0
var _chunk_rows: int = 0
var _eraser: LightLayer = null
var _erase_rects: Array[Rect2] = []
var _cell_px: int = 0
var _world_px: Vector2i = Vector2i.ZERO

## The painters baked into the target, in draw order. STATIC ONLY — anything that changes without the
## terrain changing (the veil's lamp, a glint's animation, crumble, the seam at the worked cell) must stay
## on the per-frame path or it freezes at whatever value it held when the bake ran.
var _painters: Array[Callable] = []

## `observe(rect: Rect2) -> Interface.Observation` — see the header. The bake's only route to world state,
## and the reason a chunk off-screen bakes correctly.
var _observe: Callable = Callable()

var _look: MaterialLook = null
## THE BAKED FRAME MUST CARRY EVERYTHING THE LIVE FRAME CARRIES. Held for the same reason `_look` is: a
## chunk builds its own `Frame`, and a field left null here is a field the baked picture silently lacks
## while the headless fallback path has it -- two renderers disagreeing, with no gate able to see it
## because CI only ever runs the fallback. D0327.
var _tone: RockTone = null

## The zoom a baked painter sees, PINNED. Baked content is resolution-independent — drawn into world space
## once and sampled at whatever zoom the camera later uses — so a zoom-gated detail tier must not vary per
## bake, or the world would change appearance because a dig happened while zoomed out.
##
## **NO PAINTER IN THIS BUILD READS `frame.zoom` TODAY** (verified across `view/visuals/` before this
## landed), so the value is currently unobservable and 1.0 is a placeholder rather than a decision. It is
## named and documented anyway because legacy's label-visibility and detail-tier code is gated on zoom and
## will arrive with a later component — at which point a baked painter reading this would freeze at one
## tier, and the fix is to keep that painter on the per-frame path rather than to make the bake follow the
## camera.
const BAKE_ZOOM: float = 1.0

## False when no usable render target could be had — see `setup`. The caller then keeps its per-frame path.
var _live: bool = false


## Builds the bake for a world of `world_cells` at `cell_px`, drawing `painters` in order, each against a
## frame built from `observe`.
##
## RETURNS FALSE RATHER THAN FAILING when a render target cannot be had. Two cases, and both must decline
## rather than half-work: a headless run (`docs/DECISIONS_LEDGER.md` D0186 and this project's own memory
## record that SubViewport tools HANG under `--headless` rather than erroring), and a world too large for a
## render target. A bake that silently produced blank pixels would be far worse than one that declines,
## because the fallback path is the code that is running today and is known correct.
func setup(world_cells: Vector2i, cell_px: int, observe: Callable, look: MaterialLook,
		tone: RockTone, painters: Array[Callable], rebake_margin: int) -> bool:
	if not plan(world_cells, cell_px):
		return false
	_rebake_margin = maxi(rebake_margin, 0)
	_painters = painters
	_observe = observe
	_look = look
	_tone = tone
	if painters.is_empty() or not observe.is_valid() or look == null:
		return false
	if DisplayServer.get_name() == "headless":
		return false
	_build_viewport()
	_build_eraser()
	_build_chunks()
	_live = true
	return true


## THE TILING, COMPUTED WITHOUT A RENDER TARGET, and split out of `setup` so it can be tested at all.
##
## `setup` declines under `--headless` — it must, since SubViewport tools hang there rather than erroring
## (D0186) — which would leave `chunk_index`, the chunk grid and the full-rebake threshold reachable by no
## headless suite and therefore covered by nothing. That is this repository's own dominant failure class:
## an instrument that cannot register its subject, arriving as a quiet green. Everything here is integer
## arithmetic over the world's dimensions and none of it needs pixels, so it is computed first and
## separately, and `tests/test_terrain_bake.gd` drives it directly.
##
## Returns false for a world that cannot be tiled: non-positive dimensions, or a target past the smallest
## maximum texture size this project builds for. A too-large target fails at RENDER time rather than at
## construction, which would surface as a blank world instead of an error.
func plan(world_cells: Vector2i, cell_px: int) -> bool:
	_cell_px = cell_px
	_world_px = Vector2i(world_cells.x * cell_px, world_cells.y * cell_px)
	_chunk_cols = 0
	_chunk_rows = 0
	if world_cells.x <= 0 or world_cells.y <= 0 or cell_px <= 0:
		return false
	if _world_px.x > MAX_TARGET_PX or _world_px.y > MAX_TARGET_PX:
		return false
	_chunk_cols = ceili(float(_world_px.x) / float(CHUNK_PX))
	_chunk_rows = ceili(float(_world_px.y) / float(CHUNK_PX))
	return true


## Would `bake_cells` take the full-rebake path for this many dirty chunks? Public and pure so the
## threshold is assertable without a render target — the decision is the expensive one and a test that
## could only observe it through pixels could not observe it at all.
func would_rebake_all(dirty_chunks: int, total_chunks: int) -> bool:
	return float(dirty_chunks) / float(maxi(total_chunks, 1)) > FULL_REBAKE_CHUNK_FRACTION


## Is the bake actually running? The caller draws `texture()` as one quad when true, and keeps its
## per-frame painters when false.
func available() -> bool:
	return _live


## The baked render target, for the single quad that replaces the whole per-frame static pass.
func texture() -> Texture2D:
	return _viewport.get_texture() if _live else null


## The target's size in world pixels, so the caller can draw the quad at 1:1 without re-deriving it.
func world_px() -> Vector2i:
	return _world_px


## Legacy `:410-427`. Transparent background so sky above ground stays see-through and the backdrop shows;
## `UPDATE_DISABLED` so it never re-renders on its own; NEAREST so pixel art does not blur; and its own
## world so nothing outside can post-process the retained target. Legacy learned that last one the hard
## way: an inherited colour grade re-applied saturation to the SAME stored pixels on every partial bake, so
## the terrain compounded 1.18^n and the surface line read as a neon band.
func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = _world_px
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.disable_3d = true
	_viewport.own_world_3d = true
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_viewport)


## Legacy `:433-440`. Sits BELOW the chunk painters inside the same viewport so a partial re-render blanks
## each dirty rect before that chunk repaints into it.
func _build_eraser() -> void:
	_eraser = LightLayer.new()
	_eraser.setup(-11, _paint_erase)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://view/visuals/erase.gdshader")
	_eraser.material = mat
	_viewport.add_child(_eraser)


## One `LightLayer` per chunk, each bound to its own world rect. Legacy `:428-433`.
func _build_chunks() -> void:
	for cy: int in _chunk_rows:
		for cx: int in _chunk_cols:
			var rect := Rect2(float(cx * CHUNK_PX), float(cy * CHUNK_PX),
				float(CHUNK_PX), float(CHUNK_PX))
			var chunk := LightLayer.new()
			chunk.setup(-10, _paint_chunk.bind(rect))
			_viewport.add_child(chunk)
			_chunks.append(chunk)


## What a chunk draws: every baked painter, against a frame observed for THIS chunk.
##
## THE PAINTERS ARE UNCHANGED, which is the point — the bake must be pixel-identical to the per-frame path
## or it is a second renderer with its own bugs. Each already culls against `frame.view_world_rect` (that is
## what `TerrainPainter.visit_rect` is for), so restricting a chunk is a matter of handing it a frame whose
## rect and whose observation are both the chunk.
func _paint_chunk(ci: CanvasItem, rect: Rect2) -> void:
	if not _observe.is_valid():
		return
	var f: Frame = Frame.new()
	f.obs = _observe.call(rect)
	if f.obs == null:
		return
	## PINNED, not the live clock. A baked painter that read a moving clock would freeze at whatever value
	## the last bake happened to see, and two chunks baked at different times would disagree — a seam
	## visible exactly along a chunk boundary and only after a dig.
	f.anim_time = 0.0
	f.view_world_rect = rect
	f.zoom = BAKE_ZOOM
	f.look = _look
	f.tone = _tone
	f.marks = PackedVector2Array()
	for paint: Callable in _painters:
		paint.call(f, ci)


## Legacy `:739-741`. The material's `blend_disabled` is what makes this a clear rather than a no-op.
func _paint_erase(layer: LightLayer) -> void:
	for r: Rect2 in _erase_rects:
		layer.draw_rect(r, Color(0.0, 0.0, 0.0, 0.0))


## Legacy `_bake_terrain_full` `:703-711`. Every chunk visible, target cleared once, one render.
##
## CLEAR_MODE_ONCE rather than ALWAYS: the target is retained from here on, and clearing it again would
## undo every partial bake that follows.
func bake_full() -> void:
	if not _live:
		return
	for chunk: LightLayer in _chunks:
		chunk.visible = true
		chunk.queue_redraw()
	_erase_rects.clear()
	_eraser.queue_redraw()
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Legacy `_bake_terrain_chunks` `:715-735` — the per-dig fast lane, and the fix for the mining hitch.
##
## Only the dirty chunks are made visible, so only their retained draw buffers are replayed; every other
## chunk keeps the pixels already in the target. Chunks stay hidden afterwards, which is safe because the
## viewport re-renders only when a bake asks it to and every bake sets visibility for itself first.
func bake_cells(cells: Array) -> void:
	if not _live or cells.is_empty():
		return
	var dirty: Dictionary = {}
	for cell: Vector2i in cells:
		for i: int in influenced_chunks(cell):
			dirty[i] = true
	if dirty.is_empty():
		return
	if would_rebake_all(dirty.size(), _chunks.size()):
		bake_full()
		return
	_erase_rects.clear()
	for i: int in _chunks.size():
		var on: bool = dirty.has(i)
		_chunks[i].visible = on
		if on:
			_chunks[i].queue_redraw()
			_erase_rects.append(Rect2(float((i % _chunk_cols) * CHUNK_PX),
				float((i / _chunk_cols) * CHUNK_PX), float(CHUNK_PX), float(CHUNK_PX)))
	_eraser.queue_redraw()
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Every chunk a change at `cell` can alter, which is its own chunk plus any chunk the dilation reaches.
##
## Returned as a list rather than folded into `bake_cells` so it is assertable directly: the failure this
## guards is a seam that appears only after digging near a boundary, which no fresh-world capture can
## show and no test that only inspects a picture would catch.
func influenced_chunks(cell: Vector2i) -> Array[int]:
	var out: Array[int] = []
	var seen: Dictionary = {}
	for dx: int in [-_rebake_margin, 0, _rebake_margin]:
		for dy: int in [-_rebake_margin, 0, _rebake_margin]:
			var i: int = chunk_index(Vector2i(cell.x + dx, cell.y + dy))
			if i >= 0 and not seen.has(i):
				seen[i] = true
				out.append(i)
	return out


## The dilation actually in force, for a test that wants to assert it rather than infer it.
func rebake_margin() -> int:
	return _rebake_margin


## Legacy `:745-748`. The row-major index of the chunk owning `cell`, or -1 outside the world.
func chunk_index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0:
		return -1
	var px: Vector2i = cell * _cell_px
	if px.x >= _world_px.x or px.y >= _world_px.y:
		return -1
	return (px.y / CHUNK_PX) * _chunk_cols + (px.x / CHUNK_PX)


## THE ONE QUAD THAT REPLACES THE WHOLE STATIC PASS. Legacy `:1370-1377`. A `(frame, ci)` painter like any
## other, so it mounts on the coordinator through the ordinary `add_painter` path and needs no special case
## in `WorldView._draw` — the frame is ignored because a retained target does not depend on the tick.
##
## Drawn at 1:1 in world space at the origin, because that is the space the chunks painted in. `false` is
## `tile`: the target is exactly world-sized, and tiling would wrap a world edge back over itself.
func draw_quad(_frame: Frame, ci: CanvasItem) -> void:
	if not _live:
		return
	var tex: Texture2D = texture()
	if tex == null:
		return
	ci.draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(_world_px)), false)


## Chunks actually CONSTRUCTED. Zero when the bake declined, which is why it is not the number a tiling
## test should assert — see `planned_chunk_count`.
func chunk_count() -> int:
	return _chunks.size()


## Chunks the tiling CALLS FOR, from `plan` alone. Non-zero even headless, so a test can check the grid
## against the world's own dimensions on the one path CI can actually run.
func planned_chunk_count() -> int:
	return _chunk_cols * _chunk_rows


func chunk_grid() -> Vector2i:
	return Vector2i(_chunk_cols, _chunk_rows)
