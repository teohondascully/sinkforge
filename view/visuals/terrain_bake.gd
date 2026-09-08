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
## This build ran every one of those per-cell loops on every rendered frame. Same pixels, ~100x the cost:
## 600 ticks at the 40-metre framing took 21.6 s of tick time, **22.5 ticks/s against a 120 Hz bar** --
## 5.3x out of budget on a world legacy ran at speed.
##
## **HOW IT WORKS, and every line of the shape is legacy's.** A world-sized `SubViewport` with a transparent
## background holds one `LightLayer` per chunk of the world. It never re-renders on its own
## (`UPDATE_DISABLED`); a dig flips it to `UPDATE_ONCE` for exactly the chunks that changed. Between
## changes the GPU replays a single textured quad. **Two departures from legacy: WHEN the first paint
## happens -- `bake_window` paints the chunks in view and leaves the rest until they arrive there (D0506),
## because painting the whole world at boot cost 6.17 s of first frame -- and HOW MUCH a dig repaints: the
## dilated rect around the dug cells, not the whole of every chunk it touches (D0522), because a whole
## chunk cost ~23 ms and froze the world on every blow. See `bake_window.gd`'s header for both.**
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
## `observe(rect)` callable and builds its own `Frame` per chunk -- one observation per chunk, paid once.

## THE CHUNK GRID, THE DIG DILATION, THE PAINTED SET AND EVERY TICK'S PLAN all live in
## `view/visuals/bake_window.gd`, split out so each decision is reachable from a headless suite -- `setup`
## below declines under `--headless`, so a decision left inside this object is covered by nothing.
var _window: BakeWindow = BakeWindow.new()

## Re-exported from `BakeWindow` so a caller still reads them off the object that uses them, and so each
## has exactly one definition.
const CHUNK_PX: int = BakeWindow.CHUNK_PX
const FULL_REBAKE_CHUNK_FRACTION: float = BakeWindow.FULL_REBAKE_CHUNK_FRACTION
const MAX_TARGET_PX: int = BakeWindow.MAX_TARGET_PX

var _viewport: SubViewport = null
var _chunks: Array[LightLayer] = []
var _eraser: LightLayer = null
var _erase_rects: Array[Rect2] = []
## The chunks the last bake left visible, so the next hides exactly those and not all 3008 (D0522).
var _shown: Array[int] = []
## Chunk index -> the rect it repaints THIS bake instead of its whole rect (D0522). `_paint_chunk` consumes
## an entry as it draws; no entry means the whole rect. Replaced by every bake, so none outlives its tick.
var _partial: Dictionary = {}

## Has the target been cleared yet? Exactly one bake per session clears it and every bake after it must
## not, or it would wipe the chunks already painted. That used to be `bake_full` at boot, unconditionally;
## since D0506 it is whichever bake runs first, which is normally the first window bake.
var _cleared: bool = false

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
## The grammar map the rock tooth samples (6p, D0379): one byte per cell, filled as each chunk paints and
## refilled on the same dig path, so it can never disagree with the colour target about which cells are
## which rock.
var _gram: GramMap = GramMap.new()

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
	_gram.setup(world_cells)
	_window.set_margin(rebake_margin)
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


## THE TILING, COMPUTED WITHOUT A RENDER TARGET, and called before `setup` can decline so `chunk_index`,
## the chunk grid, the full-rebake threshold and the window selection are reachable by a headless suite
## instead of being covered by nothing. `BakeWindow`'s header states the rule; `tests/test_terrain_bake.gd`
## drives it directly. False for a world that cannot be tiled -- see `BakeWindow.plan`.
func plan(world_cells: Vector2i, cell_px: int) -> bool:
	return _window.plan(world_cells, cell_px)


## The grid, the painted set and the selection, for a caller or a suite that wants to assert the decision
## rather than infer it from pixels there is no render target to produce.
func window() -> BakeWindow:
	return _window


## Would `bake_cells` take the full-rebake path for this many dirty chunks? Public and pure so the
## threshold is assertable without a render target — the decision is the expensive one and a test that
## could only observe it through pixels could not observe it at all.
func would_rebake_all(dirty_chunks: int, total_chunks: int) -> bool:
	return _window.would_rebake_all(dirty_chunks, total_chunks)


## Is the bake actually running? The caller draws `texture()` as one quad when true, and keeps its
## per-frame painters when false.
func available() -> bool:
	return _live


## The baked render target, for the single quad that replaces the whole per-frame static pass.
func texture() -> Texture2D:
	return _viewport.get_texture() if _live else null


## The target's size in world pixels, so the caller can draw the quad at 1:1 without re-deriving it.
func world_px() -> Vector2i:
	return _window.world_px()


## Legacy `:410-427`. Transparent background so sky above ground stays see-through and the backdrop shows;
## `UPDATE_DISABLED` so it never re-renders on its own; NEAREST so pixel art does not blur; and its own
## world so nothing outside can post-process the retained target. Legacy learned that last one the hard
## way: an inherited colour grade re-applied saturation to the SAME stored pixels on every partial bake, so
## the terrain compounded 1.18^n and the surface line read as a neon band.
func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = _window.world_px()
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
##
## BUILT HIDDEN since D0506. Every bake sets visibility across the whole grid for itself, so this decides
## only what the FIRST render replays -- and a chunk left visible here would go into the target whether or
## not the window selected it, which is the full-world paint coming back through the side door.
func _build_chunks() -> void:
	var grid: Vector2i = _window.grid()
	for cy: int in grid.y:
		for cx: int in grid.x:
			var rect := Rect2(float(cx * CHUNK_PX), float(cy * CHUNK_PX),
				float(CHUNK_PX), float(CHUNK_PX))
			var chunk := LightLayer.new()
			chunk.setup(-10, _paint_chunk.bind(_chunks.size(), rect))
			chunk.visible = false
			_viewport.add_child(chunk)
			_chunks.append(chunk)


## What a chunk draws: every baked painter, against a frame observed for the rect it repaints -- its
## whole rect, or the partial `bake_tick` left for it (D0522).
##
## THE PAINTERS ARE UNCHANGED, which is the point — the bake must be pixel-identical to the per-frame path
## or it is a second renderer with its own bugs. Each already culls against `frame.view_world_rect` (that is
## what `TerrainPainter.visit_rect` is for), so restricting a chunk is a matter of handing it a frame whose
## rect and whose observation are both the rect.
func _paint_chunk(ci: CanvasItem, i: int, rect: Rect2) -> void:
	if not _observe.is_valid():
		return
	var r: Rect2 = _partial.get(i, rect)
	_partial.erase(i)
	var f: Frame = Frame.new()
	f.obs = _observe.call(r)
	if f.obs == null:
		return
	## PINNED, not the live clock. A baked painter that read a moving clock would freeze at whatever value
	## the last bake happened to see, and two chunks baked at different times would disagree — a seam
	## visible exactly along a chunk boundary and only after a dig.
	f.anim_time = 0.0
	# Shrunk by the painters' overdraw so they visit EXACTLY the rect's cells (D0522): see `paint_rect`.
	f.view_world_rect = _window.paint_rect(r)
	f.zoom = BAKE_ZOOM
	f.look = _look
	f.tone = _tone
	f.marks = PackedVector2Array()
	for paint: Callable in _painters:
		paint.call(f, ci)
	_gram.fill_rect(f.obs, cells_of(r), _look)


## A pixel rect as the terrain cells it covers.
func cells_of(rect: Rect2) -> Rect2i:
	return _window.cells_of(rect)


## The grammar map's texture, for the tooth's `gram_tex`; updated in place across rebakes.
func gram_texture() -> ImageTexture:
	return _gram.texture()


## Legacy `:739-741`. The material's `blend_disabled` is what makes this a clear rather than a no-op.
func _paint_erase(layer: LightLayer) -> void:
	for r: Rect2 in _erase_rects:
		layer.draw_rect(r, Color(0.0, 0.0, 0.0, 0.0))


## Legacy `_bake_terrain_full` `:703-711`. Every chunk visible, target cleared once, one render.
## CLEAR_MODE_ONCE rather than ALWAYS: the target is retained from here on, and clearing it again would
## undo every partial bake that follows. NO LONGER THE BOOT LANE (D0506) -- it is now only the safety valve
## `bake_cells` reaches for when one dig dirties more of the world than a full replay costs.
func bake_full() -> void:
	if not _live:
		return
	_partial.clear()
	_shown.clear()
	for i: int in _chunks.size():
		_chunks[i].visible = true
		_chunks[i].queue_redraw()
		_shown.append(i)
	_window.note_all_painted()
	_erase_rects.clear()
	_eraser.queue_redraw()
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_cleared = true


## Legacy `_bake_terrain_chunks` `:715-735`, the per-dig lane on its own: `bake_tick` with no window.
func bake_cells(cells: Array) -> void:
	bake_tick(Rect2(), cells)


## ONE BAKE PER TICK, OVER BOTH LANES AT ONCE, and that is why it is one call and not two (D0506).
##
## THE WINDOW LANE IS THE FIRST BAKE AND EVERY CHUNK THAT SCROLLS IN AFTER IT. `BakeWindow` grows
## `window_rect` by the observation margin and answers which of those chunks the target does not hold yet;
## they are painted ONCE, in the tick they enter the window. `UPDATE_ONCE` on a SubViewport renders before
## its parent inside one frame -- the lane `bake_cells` has used for a dug chunk since D0326 -- so the quad
## samples them already painted and no frame shows a hole. Nothing rebakes a chunk that has not been dug.
##
## `dug` is the cells this tick broke. SINCE D0522 THE DIG LANE REPAINTS A RECTANGLE, NOT CHUNKS: the
## dug cells' bounding box grown by the dilation, clipped to each chunk it crosses, so a blow repaints
## (1 + 2 x margin) cells a side wherever it lands and a chunk corner costs nothing extra. Both lanes are
## planned together in `BakeWindow.plan_tick` (a second bake in one tick would hide what the first showed),
## and that planner holds the full-rebake threshold, the scattered-dig fallback and the budget, headless.
func bake_tick(window_rect: Rect2, dug: Array) -> void:
	if not _live:
		return
	## Last tick's chunk paints wrote the grammar map; upload it before this tick's are queued. The tooth's
	## uniform holds this same `ImageTexture`, updated in place, so nothing else has to be re-bound (D0511).
	_gram.texture()
	var p: BakeWindow.Plan = _window.plan_tick(window_rect, dug)
	if p.full:
		bake_full()
		return
	if p.whole.is_empty() and p.partial.is_empty():
		return
	_bake_partial(p)


## Shows exactly the plan's chunks, erases what each will repaint, and asks the target for one render.
##
## EVERY RECT SHOWN IS ERASED FIRST, and that is what makes showing a superset safe: `erase.gdshader` is
## `blend_disabled`, so erase-then-repaint is byte-identical to a fresh paint. The dig lane and the window
## lane can therefore be unioned in one tick without either compounding the other's pixels. A chunk the
## target has never held is transparent already, so erasing it costs one degenerate rect and no accuracy.
## A partial chunk erases and repaints ONLY its partial rect (D0522); the rest of its pixels stay.
func _bake_partial(p: BakeWindow.Plan) -> void:
	_erase_rects.clear()
	for i: int in _shown:
		_chunks[i].visible = false
	_shown.clear()
	_partial = p.partial
	for i: int in p.whole:
		_show(i, _window.chunk_rect(i))
	for i: int in p.partial:
		_show(i, p.partial[i])
	_window.note_plan(p)
	_eraser.queue_redraw()
	# The first bake of a session clears the target once; every one after it must not, or it would wipe
	# the chunks already painted. Before D0506 that first bake was always `bake_full` at boot.
	_viewport.render_target_clear_mode = (SubViewport.CLEAR_MODE_NEVER if _cleared
		else SubViewport.CLEAR_MODE_ONCE)
	_cleared = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## One chunk into this bake: visible, queued, and `rect` (its whole rect or its partial) erased first.
func _show(i: int, rect: Rect2) -> void:
	_chunks[i].visible = true
	_chunks[i].queue_redraw()
	_shown.append(i)
	_erase_rects.append(rect)


## Every chunk a change at `cell` can alter, which is its own chunk plus any chunk the dilation reaches.
##
## Returned as a list rather than folded into `bake_cells` so it is assertable directly: the failure this
## guards is a seam that appears only after digging near a boundary, which no fresh-world capture can
## show and no test that only inspects a picture would catch. Reads nothing about which chunks are already
## painted -- the dig path is the same path it was before D0506.
func influenced_chunks(cell: Vector2i) -> Array[int]:
	return _window.influenced_chunks(cell)


## The dilation actually in force, for a test that wants to assert it rather than infer it.
func rebake_margin() -> int:
	return _window.margin()


## Legacy `:745-748`. The row-major index of the chunk owning `cell`, or -1 outside the world.
func chunk_index(cell: Vector2i) -> int:
	return _window.chunk_index(cell)


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
	ci.draw_texture_rect(tex, Rect2(Vector2.ZERO, Vector2(_window.world_px())), false)


## Chunks the tiling CALLS FOR, from `plan` alone (the CONSTRUCTED count, `_chunks.size()`, is zero when
## the bake declined). Non-zero even headless, so a test can check the grid against the world's own
## dimensions on the one path CI can actually run.
func planned_chunk_count() -> int:
	return _window.chunk_count()


func chunk_grid() -> Vector2i:
	return _window.grid()
