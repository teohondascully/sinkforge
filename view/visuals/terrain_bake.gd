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
## changes the GPU replays a single textured quad. **Three departures from legacy: WHEN the first paint
## happens -- `bake_window` paints the chunks in view and leaves the rest until they arrive there (D0506),
## because painting the whole world at boot cost 6.17 s of first frame; HOW MUCH a dig repaints: the
## dilated rect around the dug cells, not the whole of every chunk it touches (D0522), because a whole
## chunk cost ~23 ms and froze the world on every blow; and HOW MUCH ground scrolling in may paint in one
## tick: a budget of solid cells (`bake_lane.gd`, D0524), because a row of chunks entering on a fall
## painted 69-83 ms in one tick. See `bake_window.gd`'s header for all three.**
##
## **THE ERASER IS NOT OPTIONAL.** A partial re-render can only ADD coverage — alpha blending cannot take
## rock away — so a cell dug open to the sky would keep its old pixels forever. `erase.gdshader`
## (`blend_disabled`) writes straight to the target, so drawing a transparent rect with it is a true clear.
## Ordered below the chunk painters, it blanks each dirty chunk's rect before that chunk repaints.
##
## **WHAT A CHUNK DRAWS is `view/visuals/bake_chunk.gd`'s** (D0524): each chunk observes for itself and
## builds its own frame with the clock pinned -- that file's header says why, and it is the one structural
## difference from legacy.

## THE CHUNK GRID, THE DIG DILATION, THE PAINTED SET AND EVERY TICK'S PLAN all live in
## `view/visuals/bake_window.gd`, split out so each decision is reachable from a headless suite -- `setup`
## below declines under `--headless`, so a decision left inside this object is covered by nothing.
var _window: BakeWindow = BakeWindow.new()
## What one chunk paints when the target asks it to (`bake_chunk.gd`).
var _chunk: BakeChunk = BakeChunk.new()

## Re-exported from `BakeWindow` so a caller still reads them off the object that uses them, and so each
## has exactly one definition.
const CHUNK_PX: int = BakeWindow.CHUNK_PX
const FULL_REBAKE_CHUNK_FRACTION: float = BakeWindow.FULL_REBAKE_CHUNK_FRACTION
const MAX_TARGET_PX: int = BakeWindow.MAX_TARGET_PX

var _viewport: SubViewport = null
var _chunks: Array[LightLayer] = []
var _eraser: LightLayer = null
var _erase_rects: Array[Rect2] = []
## The chunks the last bake left visible, so the next hides exactly those and not the whole grid (D0522).
var _shown: Array[int] = []

## Has the target been cleared yet? Exactly one bake per session clears it and every bake after it must
## not, or it would wipe the chunks already painted. That used to be `bake_full` at boot, unconditionally;
## since D0506 it is whichever bake runs first, which is normally the first window bake.
var _cleared: bool = false

## The grammar map the rock tooth samples (6p, D0379): one byte per cell, filled as each chunk paints and
## refilled on the same dig path, so it can never disagree with the colour target about which cells are
## which rock. Owned here because its texture is uploaded once a tick, below.
var _gram: GramMap = GramMap.new()

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
	_chunk.setup(_window, observe, look, tone, painters, _gram)
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


## What a chunk draws, for a suite that wants to assert the baked frame's pinned fields (D0524).
func chunk() -> BakeChunk:
	return _chunk


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


## One `LightLayer` per chunk, each bound to its own index and world rect. Legacy `:428-433`.
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
			var layer := LightLayer.new()
			layer.setup(-10, _chunk.paint.bind(_chunks.size(), rect))
			layer.visible = false
			_viewport.add_child(layer)
			# The shader-tone quad, when the flag is on (D0528): a CHILD of this layer, so hiding the chunk
			# hides its quad and the quad draws after the wall plane this layer paints. Null when off.
			_chunk.tone_layer_for(layer, _chunks.size(), rect)
			_chunks.append(layer)


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
	_chunk.partial.clear()
	_shown.clear()
	for i: int in _chunks.size():
		_chunks[i].visible = true
		_chunks[i].queue_redraw()
		_chunk.queue_tone(i)
		_shown.append(i)
	_window.note_all_painted()
	_erase_rects.clear()
	_eraser.queue_redraw()
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_cleared = true


## Legacy `_bake_terrain_chunks` `:715-735`, the per-dig lane on its own: `bake_tick` with no window, and
## so with nothing for the window lane to budget.
func bake_cells(cells: Array) -> void:
	bake_tick(Rect2(), cells, null)


## ONE BAKE PER TICK, OVER BOTH LANES AT ONCE, and that is why it is one call and not two (D0506).
##
## THE WINDOW LANE IS THE FIRST BAKE AND EVERY CHUNK THAT SCROLLS IN AFTER IT. `BakeWindow` grows
## `window_rect` by the observation margin and answers which of those chunks the target does not hold yet;
## they are painted ONCE, in the tick they enter the window -- or, since D0524, in the first tick the
## budget admits them, the view rect itself always admitted. `UPDATE_ONCE` on a SubViewport renders before
## its parent inside one frame -- the lane `bake_cells` has used for a dug chunk since D0326 -- so the quad
## samples them already painted and no frame shows a hole. Nothing rebakes a chunk that has not been dug.
##
## `dug` is the cells this tick broke. SINCE D0522 THE DIG LANE REPAINTS A RECTANGLE, NOT CHUNKS: the
## dug cells' bounding box grown by the dilation, clipped to each chunk it crosses, so a blow repaints
## (1 + 2 x margin) cells a side wherever it lands and a chunk corner costs nothing extra. Both lanes are
## planned together in `BakeWindow.plan_tick` (a second bake in one tick would hide what the first showed),
## and that planner holds the full-rebake threshold, the whole-or-rect cut and, through `BakeLane`, the
## budget, headless.
##
## `obs` IS THE TICK'S OWN OBSERVATION -- the one the coordinator built the frame from -- and the budget
## counts a chunk's solid cells off it (D0524), so admitting a chunk costs no second observation. The
## planner is given it rather than asking `observe` itself: a second observation over the window on the
## very ticks that already paint would be the cost this budget exists to bound.
func bake_tick(window_rect: Rect2, dug: Array, obs: Interface.Observation) -> void:
	if not _live:
		return
	## Last tick's chunk paints wrote the grammar map; upload it before this tick's are queued. The tooth's
	## uniform holds this same `ImageTexture`, updated in place, so nothing else has to be re-bound (D0511).
	_gram.texture()
	var p: BakeWindow.Plan = _window.plan_tick(window_rect, dug, obs)
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
	_chunk.partial = p.partial
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
	_chunk.queue_tone(i)
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
