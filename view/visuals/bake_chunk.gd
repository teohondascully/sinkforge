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
## Per-chunk planning metadata, consumed by its actual draw callback (profiling only).
var attribution: Dictionary = {}

## THE SHADER TONE, OFF (D0528, T040's evidence). False is the shipped picture: `TerrainPainter.paint`
## fills every solid cell with `RockTone`/`SurfaceTone` on the CPU. True pulls that
## one painter out of the baked list and replaces it with `BakeData`'s texture and `rock_tone.gdshader`.
## The look is NOT the same -- eleven `FastNoiseLite` fields are re-derived in GLSL. Tufts stay on the CPU
## -- so this ships off and the ledger carries the capture diff the director rules on.
const SHADER_TONE: bool = false
const SHADER_TONE_FLAG: String = "--shader-tone"
const TONE_SHADER_PATH: String = "res://view/visuals/rock_tone.gdshader"

## `BakeData` when the flag is on, else null: the object that builds the shader's per-chunk texture. Null
## IS the off state, and every branch below tests it rather than re-reading the flag.
var data: BakeData = null
## Was the CPU terrain painter left in `painters`? Read by `tests/test_bake_data.gd`.
var cpu_tone: bool = true
## Chunk paints that ran the CPU terrain painter, and data textures built. The pin these counters serve is
## "with the flag off, nothing builds a texture": a claim about a path taken, not about a pixel.
var cpu_paints: int = 0
var data_builds: int = 0

## Chunk index -> [image, span origin, paint rect], handed from `paint` to `paint_tone` inside one frame.
var _pending: Dictionary = {}
## Chunk index -> the child `LightLayer` that draws its quad, and its own texture.
var _tone_layers: Dictionary = {}
var _tone_textures: Dictionary = {}


## Is the shader tone on for this run? The const is the default; `--shader-tone` on the command line turns
## it on for one boot. READ OFF `OS` RATHER THAN OFF `SeatFlags`, and the reason is the layer rule:
## `view` may depend on `interface`, `core` and `data` only (`tools/layer_lint/layer_lint.py`), so naming
## `shell/seat_flags.gd` from here would be a lint failure. That file documents the flag; this reads it.
##
## BOTH LISTS, and the second is the one that actually carries it: the seat's flags are passed after the
## UNIX `--`, and Godot puts those in `get_cmdline_user_args()` ALONE -- `get_cmdline_args()` came back as
## just `["--script", ...]` for a run whose own `--shader-tone` was sitting in the user args. Reading only
## the first would have been a flag that parses, documents and never fires.
static func shader_tone() -> bool:
	return (SHADER_TONE or OS.get_cmdline_user_args().has(SHADER_TONE_FLAG)
		or OS.get_cmdline_args().has(SHADER_TONE_FLAG))


func setup(w: BakeWindow, observe_rect: Callable, material_look: MaterialLook, rock_tone: RockTone,
		baked: Array[Callable], gram_map: GramMap) -> void:
	window = w
	observe = observe_rect
	look = material_look
	tone = rock_tone
	painters = baked
	gram = gram_map
	var split: Array = tone_painters(baked, shader_tone())
	painters = split[0]
	cpu_tone = bool(split[1])
	data = null
	if cpu_tone:
		return
	data = BakeData.new()
	data.setup()


## WHICH PAINTERS A CHUNK RUNS, and whether the CPU tone is still among them, as `[painters, cpu_tone]`.
##
## THE SWAP IS BY IDENTITY, NOT BY POSITION: `Callable` equality is (object, method), so this finds the one
## baked painter that IS `TerrainPainter.paint` and leaves `WallPainter.paint` exactly where it sits. A
## list that does not carry it -- a fixture's own painters -- keeps the CPU path rather than losing a pass.
##
## Pure and static so BOTH sides are assertable. `shader_tone()` reads the process's command line, which a
## headless suite cannot pose, so the ON branch is reachable only here.
static func tone_painters(baked: Array[Callable], on: bool) -> Array:
	if not on:
		return [baked, true]
	var at: int = baked.find(TerrainPainter.paint)
	if at < 0:
		return [baked, true]
	var kept: Array[Callable] = baked.duplicate()
	kept[at] = TerrainPainter.paint_tufts
	return [kept, false]


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
	var began: int = Time.get_ticks_usec()
	var source: Array = attribution.get(i, [-1, "unknown"])
	attribution.erase(i)
	BakeCost.note(BakeCost.PREP, began, _paint(ci, i, rect), source[0], source[1])


## The paint itself, returning the terrain cells it prepared so the clock above can charge per cell
## rather than per chunk -- a partial chunk (D0522) is a fraction of a whole one and a per-chunk average
## over a mixed window names neither. Split out only so `paint` can be the timed wrapper: a `began` read
## at the top of a body with four early returns would need the stamp repeated at each of them, and the
## one that got missed would be the cheap path, which is the shape that reads as a speedup.
func _paint(ci: CanvasItem, i: int, rect: Rect2) -> int:
	var r: Rect2 = rect_for(i, rect)
	var f: Frame = frame_for(r)
	if f == null:
		return 0
	var cells: Rect2i = window.cells_of(r)
	var prepared: int = cells.size.x * cells.size.y
	for p: Callable in painters:
		p.call(f, ci)
	if cpu_tone:
		cpu_paints += 1
	if gram != null:
		gram.fill_rect(f.obs, cells, look)
	if data == null:
		return prepared
	# BUILT HERE, WHERE THE OBSERVATION IS ALREADY IN HAND, so the shader path pays for exactly one
	# observation a chunk, as the CPU path does. The child layer's own `_draw` only uploads and draws.
	var img: Image = data.build(f.obs, cells, look)
	if img == null:
		return prepared
	_pending[i] = [img, data.span.position, r, f.obs.world_seed, f.obs.cell_px]
	data_builds += 1
	return prepared


## THE CHILD LAYER THAT DRAWS ONE CHUNK'S QUAD, added under the chunk's own layer so the parent's
## visibility governs both and the quad draws AFTER the wall plane the parent paints (same effective z,
## children after parents). Null when the flag is off. Called once a chunk by `TerrainBake._build_chunks`.
func tone_layer_for(parent: Node2D, i: int, rect: Rect2) -> LightLayer:
	if data == null:
		return null
	var layer := LightLayer.new()
	layer.setup(0, paint_tone.bind(i, rect))
	var mat := ShaderMaterial.new()
	mat.shader = load(TONE_SHADER_PATH)
	mat.set_shader_parameter("palette", data.palette())
	mat.set_shader_parameter("unknown_index", data.unknown_index())
	layer.material = mat
	parent.add_child(layer)
	_tone_layers[i] = layer
	return layer


## A chunk's quad follows its own layer into a bake: `queue_redraw` on the parent does not reach a child.
func queue_tone(i: int) -> void:
	var layer: LightLayer = _tone_layers.get(i)
	if layer != null:
		layer.queue_redraw()


## ONE QUAD OVER THE PAINT RECT, sampling the texture `paint` built for this chunk this frame. Consuming:
## a stale entry would draw last bake's rock over a rect the eraser has since cleared.
func paint_tone(ci: CanvasItem, i: int, _rect: Rect2) -> void:
	var e: Array = _pending.get(i, [])
	_pending.erase(i)
	if e.is_empty() or ci.material == null:
		return
	var img: Image = e[0]
	var began: int = Time.get_ticks_usec()
	var tex: ImageTexture = _tone_textures.get(i)
	if tex == null or tex.get_size() != Vector2(img.get_size()):
		tex = ImageTexture.create_from_image(img)
		_tone_textures[i] = tex
	else:
		tex.update(img)
	BakeCost.note(BakeCost.UPLOAD, began, img.get_width() * img.get_height())
	var mat: ShaderMaterial = ci.material
	mat.set_shader_parameter("data_tex", tex)
	mat.set_shader_parameter("span_origin", e[1])
	mat.set_shader_parameter("world_seed", BakeData.seed32(e[3]))
	mat.set_shader_parameter("cell_px", e[4])
	# UNTEXTURED: the plane is `data_tex`, a uniform, because the shader compiler will not let a built-in
	# sampler cross a function boundary. The fill colour is overwritten wholesale by `fragment`.
	ci.draw_rect(e[2], Color.WHITE, true)
