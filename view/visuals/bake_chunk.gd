class_name BakeChunk
extends RefCounted

## WHAT ONE CHUNK DRAWS: the frame its painters are handed, and the partial rect it consumes (split out of
## `view/visuals/terrain_bake.gd` at that file's line cap, D0524). A seam, not a trim: `TerrainBake` decides
## WHEN the target renders and WHICH chunks show; this decides what a chunk paints once it is asked. The
## frame is built by a function of its own (`frame_for`) so its pinned fields -- the clock at zero, the
## rect shrunk to the cells the eraser clears, the look and the tone the live frame carries -- are
## reachable from a headless suite, where before they lived only past `setup`'s headless decline.
##
## **EACH CHUNK OBSERVES FOR ITSELF, and this is the one structural difference from legacy.** Legacy's
## painters read the whole world off the sim directly. Here a painter may read only `frame.obs`, which is a
## VALUE covering one window -- and `Observation.material_at` answers `&""` for any cell outside the window
## it was given, not "unknown". So handing a chunk the CAMERA's frame would paint every chunk off-screen as
## empty and bake a mostly-blank world, silently, with every gate green. A chunk therefore takes an
## `observe(rect)` callable and builds its own `Frame` -- one observation per chunk, paid once.

## The zoom a baked painter sees, PINNED. Baked content is resolution-independent -- drawn into world space
## once and sampled at whatever zoom the camera later uses -- so a zoom-gated detail tier must not vary per
## bake, or the world would change appearance because a dig happened while zoomed out.
##
## **NO PAINTER IN THIS BUILD READS `frame.zoom` TODAY** (verified across `view/visuals/` when this landed
## in `TerrainBake`, D0326), so the value is currently unobservable and 1.0 is a placeholder rather than a
## decision. Named anyway because legacy's label-visibility and detail-tier code is gated on zoom and will
## arrive with a later component -- at which point a baked painter reading this would freeze at one tier,
## and the fix is to keep that painter on the per-frame path rather than to make the bake follow the camera.
const BAKE_ZOOM: float = 1.0

## The painters baked into the target, in draw order. STATIC ONLY -- anything that changes without the
## terrain changing (the veil's lamp, a glint's animation, crumble, the seam at the worked cell) must stay
## on the per-frame path or it freezes at whatever value it held when the bake ran.
var painters: Array[Callable] = []
## `observe(rect: Rect2) -> Interface.Observation` -- see the header. The chunk's only route to world state.
var observe: Callable = Callable()
var look: MaterialLook = null
## THE BAKED FRAME MUST CARRY EVERYTHING THE LIVE FRAME CARRIES. Held for the same reason `look` is: a
## chunk builds its own `Frame`, and a field left null here is a field the baked picture silently lacks
## while the headless fallback path has it -- two renderers disagreeing, with no gate able to see it
## because CI only ever runs the fallback. D0327.
var tone: RockTone = null
var window: BakeWindow = null
## The grammar map the rock tooth samples (6p, D0379): one byte per cell, filled as each chunk paints and
## refilled on the same dig path, so it can never disagree with the colour target about which cells are
## which rock. Owned by `TerrainBake` (it uploads the texture each tick); filled here.
var gram: GramMap = null
## Chunk index -> the rect it repaints THIS bake instead of its whole rect (D0522). `paint` consumes an
## entry as it draws; no entry means the whole rect. Replaced by every bake, so none outlives its tick.
var partial: Dictionary = {}


func setup(w: BakeWindow, observe_rect: Callable, material_look: MaterialLook, rock_tone: RockTone,
		baked: Array[Callable], gram_map: GramMap) -> void:
	window = w
	observe = observe_rect
	look = material_look
	tone = rock_tone
	painters = baked
	gram = gram_map


## The rect chunk `i` paints in this bake: its partial if the plan left one, else `rect` (its whole rect).
## Consuming, so a partial can never be painted twice.
func rect_for(i: int, rect: Rect2) -> Rect2:
	var r: Rect2 = partial.get(i, rect)
	partial.erase(i)
	return r


## THE FRAME A CHUNK'S PAINTERS SEE, for the rect `r` it repaints, or null when the world declined to be
## observed. THE PAINTERS ARE UNCHANGED, which is the point -- the bake must be pixel-identical to the
## per-frame path or it is a second renderer with its own bugs. Each already culls against
## `frame.view_world_rect` (that is what `TerrainPainter.visit_rect` is for), so restricting a chunk is a
## matter of handing it a frame whose rect and whose observation are both the rect.
func frame_for(r: Rect2) -> Frame:
	if not observe.is_valid():
		return null
	var f: Frame = Frame.new()
	f.obs = observe.call(r)
	if f.obs == null:
		return null
	## PINNED, not the live clock. A baked painter that read a moving clock would freeze at whatever value
	## the last bake happened to see, and two chunks baked at different times would disagree -- a seam
	## visible exactly along a chunk boundary and only after a dig.
	f.anim_time = 0.0
	# Shrunk by the painters' overdraw so they visit EXACTLY the rect's cells (D0522): see `paint_rect`.
	f.view_world_rect = window.paint_rect(r)
	f.zoom = BAKE_ZOOM
	f.look = look
	f.tone = tone
	f.marks = PackedVector2Array()
	return f


## What a chunk draws: every baked painter, against a frame observed for the rect it repaints -- its
## whole rect, or the partial the plan left for it (D0522). Bound per chunk by `TerrainBake._build_chunks`.
func paint(ci: CanvasItem, i: int, rect: Rect2) -> void:
	var r: Rect2 = rect_for(i, rect)
	var f: Frame = frame_for(r)
	if f == null:
		return
	for p: Callable in painters:
		p.call(f, ci)
	if gram != null:
		gram.fill_rect(f.obs, window.cells_of(r), look)
