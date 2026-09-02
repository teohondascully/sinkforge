class_name WorldView
extends Node2D

## THE COORDINATOR. It calls `observe()`, builds one `Frame` per rendered tick, and hands that frame to
## painters. It draws nothing itself. `docs/COORDINATOR_CONTRACT.md`, `docs/DECISIONS_LEDGER.md` D0240.
##
## This replaces legacy's `world_renderer.gd`, which is 3,656 lines against this project's 400-line gate
## and which the painters reach INTO rather than merely reference. Nothing is ported from it: the
## painters are lifted underneath this object one at a time, against `Frame`, in later phases.
##
## WHY THIS FILE IS SMALL, AND WHY THAT IS THE DESIGN RATHER THAN AN ACCIDENT. `tests/body/reveal_scene.gd`
## is the closest thing this tree already has to a coordinator and it sits at **398 lines against a 400
## cap**, with `_physics_process` at **49 against a 50 cap** -- one or two lines from firing on both.
## `docs/QUALITY.md` §2 records what happens next: `sim/body/body.gd` sat at exactly 400 three commits
## running because it was trimmed rather than split. So this was NOT ported from that file and grown.
## The three concerns that make `reveal_scene` big -- command-line argument parsing, the agent-drive
## modes, and the recording flush -- are ~120 of its 398 lines and **none of them is coordinator work**.
## They stay where they belong, in the debug scene that needs them. A renderer does not parse `--seed`.
##
## WHAT IT DOES NOT OWN. No grid, no body, no mining verb, no `TileGrid` of any kind: it is constructed
## around an `Interface` its caller already owns, exactly as `interface/interface.gd` is constructed
## around the sim objects ITS caller owns. `view/` may depend on `{interface, core}` and on nothing in
## `sim/`, so there is structurally no way for a painter to reach past the envelope through this object.

## THE COSMETIC CLOCK. Q5 pinned this to a `const 0.0` and that was correct at the time: the build starts
## underground, no time system was authored, and a clock nothing could use is a field that only drifts.
## D0277 re-opens it on the director's ruling, because the animated backlog arrived —
## `docs/LEGACY_GAP.md` PRE-1 counts **28+ rows** that port, are correct, and then sit frozen: crumble
## chunks, the status pulse, working-machine glyphs, the construction overlay, the need bubble, rope sway,
## payout rise, godrays, glint flares, the lamp flicker, surface life.
##
## **A COSMETIC TICK COUNTER, NOT A WALL CLOCK, and the difference is the whole ruling.** Legacy used
## `Time.get_ticks_msec()`. That would make two captures of the same tick differ, and this project's
## entire screenshot-comparison discipline rests on the renderer being a function of state
## (`docs/QUALITY.md`). Counting rendered ticks instead means `--screenshot-tick=N` reproduces exactly the
## same frame it did yesterday, while an animation still advances for a player watching it.
##
## It is a `var` on the instance rather than a `const`, so "the clock does not advance" is no longer a
## property of the type. `PINNED_ANIM_TIME` below is what a test poses when it wants the old guarantee,
## which is most of them: an animated painter asserted at an arbitrary clock value is asserting the clock.
const PINNED_ANIM_TIME: float = 0.0

## Seconds per rendered tick. The sim runs at a fixed 60Hz (`docs/ARCHITECTURE.md` §4) and `refresh()` is
## called once per rendered tick by whoever owns the render cadence, so this is that cadence expressed as
## a duration — NOT a measured frame time. A measured `delta` would reintroduce exactly the run-to-run
## variation the tick counter exists to remove.
const SECONDS_PER_TICK: float = 1.0 / 60.0

var _anim_ticks: int = 0

## How far past the camera rect to observe, in terrain cells. A painter deciding a cell's edges legitimately
## probes the ring just outside its own view, and `interface/interface.gd` says so: reading past the window
## is "deliberately not an error, because a renderer legitimately probes the ring just past its own window".
##
## THREE, because the deepest probe on the stack now reaches three cells: `TerrainPainter.visit_rect` draws
## one cell past the view so a straddling cell is drawn whole, and `WallPainter.ao_alpha` probes
## `AO_RAMP_CELLS` further out from every cell it draws. At a margin of 2 that probe left the window on the
## outermost ring, `solid_at` answered false for a cell it had simply never been given, and the straddling
## column at each screen edge lost its cast shadow — a defect that only appears at the very edge of the
## frame and only in one direction, which is the kind a screenshot does not settle.
## `tests/test_wall_painter.gd` derives this from those two constants rather than restating it.
##
## **NINE, since D0302.** `VeilPainter` reads further than anything else on the stack: its openness field
## is a separable box blur of radius `REACH_CELLS` (legacy's 2 m, which is 8 cells here) and the key light
## then reads that field one row either side, so a drawn cell depends on the observation `REACH + 1` cells
## out. `docs/LEGACY_GAP.md` listed T1 #2 as blocked on a "window-vs-world scope decision"; the blur has a
## bounded reach, so the question had a NUMBER, and this is it. At a margin of 3 the outermost drawn cells
## would blur against cells the observation never handed over — `solid_at` answers false for those — and
## every screen edge would grow a false halo of openness, brightest exactly where the frame is cropped.
##
## The cost is real and bounded: the window grows from (view + 6) to (view + 18) cells on each axis, which
## at the reveal camera is ~1,980 cells copied per observation against ~3,200. `tests/test_veil_painter.gd`
## derives this from the veil's own constants rather than restating it.
const WINDOW_MARGIN_CELLS: int = 9

var _iface: Interface = null
var _look: MaterialLook = null
var _camera: Camera2D = null
var _layers: Array[PaintLayer] = []
## The static painters, held until `bake_static()` decides whether they run once or every frame. See
## `add_baked_painter`.
var _baked_painters: Array[Callable] = []
var _bake: TerrainBake = null
## Painters that keep state, held so they outlive the expression that created them. See
## `add_stateful_painter` — nothing reads this array, it exists to be a reference.
var _owned: Array[RefCounted] = []
var _frame: Frame = null
var _hud: HudLayer = null
## Built lazily on the first frame, because it is seeded from `Observation.world_seed` and there is no
## observation until `refresh()` runs. Held rather than rebuilt: its eight noise fields are constructed
## once and a per-frame rebuild would be both wasteful and, worse, a different world every frame.
var _tone: RockTone = null
var _post: PostFxLayer = null
## The dilation `bake_static` handed the bake, recorded even when the bake declined.
##
## OBSERVABILITY ADDED BECAUSE A MUTANT ESCAPED (D0330). `tests/test_terrain_bake.gd` asserted the
## dilation by constructing its own `TerrainBake` and passing the margin itself, so setting THIS call site
## to 0 -- the actual defect, a permanent seam along chunk edges after mining -- left the suite green. A
## test that poses its own subject cannot register a wiring error at the call site it bypassed.
var _bake_margin: int = -1


## Constructor-by-method rather than `_init` arguments, so this node can also be instantiated from a
## scene file later without the engine needing to supply them.
func setup(iface: Interface, look: MaterialLook, camera: Camera2D) -> void:
	_iface = iface
	_look = look
	_camera = camera


## Attach a painter. `paint` is called as `paint(frame, canvas)` where `canvas` is the returned layer,
## and the layer is added as a child in call order, so a later painter draws in front of an earlier one.
##
## EACH PAINTER GETS ITS OWN `CanvasItem` rather than drawing onto this node (contract §2a, ruled).
## Legacy had both conventions and the explicit one wins on three counts: parallax needs SEVERAL
## canvases and a coordinator is only one; a painter that receives its canvas is testable with no
## coordinator at all; and it is already the convention of the two painters actually being lifted.
func add_painter(paint: Callable) -> PaintLayer:
	var layer: PaintLayer = PaintLayer.new()
	layer.bind_to(self, paint)
	_layers.append(layer)
	add_child(layer)
	return layer


## A STATIC painter — one whose picture changes only when the terrain does. Registered here and mounted by
## `bake_static()`, which decides whether it runs once into a retained target or every frame like the rest.
##
## **THIS IS THE SINGLE LARGEST PERFORMANCE DECISION IN THE RENDERER** and legacy states it at
## `world_renderer.gd:698`: *"The bottleneck was GDScript re-issuing the whole world's draw commands every
## frame; the sim itself costs almost nothing."* A static painter on the per-frame path re-issues its whole
## per-cell loop 60 times a second to produce identical pixels. Legacy measured the terrain pass at ~72% of
## all frame draw calls and issued it ONCE.
##
## WHAT QUALIFIES, and the test is not "is it slow" but "can its picture change while the terrain does not":
## the terrain fill and the wall plane qualify. The veil does NOT (its lamp follows the body), nor the glint
## (animated), the seam (follows the worked cell), the cracks, the crumble, or the sky (animated). A painter
## registered here wrongly does not fail — it FREEZES, silently, at the value it held when the bake ran.
func add_baked_painter(paint: Callable) -> void:
	_baked_painters.append(paint)


## Mounts everything `add_baked_painter` collected, and returns whether it went into a bake.
##
## FALLS BACK TO THE PER-FRAME PATH RATHER THAN FAILING. `TerrainBake.setup` declines under `--headless`
## (SubViewport tools HANG there rather than erroring, D0186) and on a world too large for a render target.
## In both cases every registered painter mounts as an ordinary layer at `z`, which is exactly the code that
## runs today and is known correct — only slower. A renderer that produced no picture because a render
## target was unavailable would be a far worse failure than a slow one.
##
## Must be called AFTER `setup()` and after the last `add_baked_painter`, and before the first `refresh()`.
## Needs one observation to learn the world's size, which is why it cannot happen in `setup`.
func bake_static(z: int) -> bool:
	if _iface == null or _baked_painters.is_empty():
		return false
	var probe: Interface.Observation = _iface.observe(
		Interface.Envelope.covering(Rect2(), WINDOW_MARGIN_CELLS))
	# Built here rather than waiting for `_build_frame`, because the bake paints BEFORE the first
	# `refresh()` and a bake that ran with a null tone would burn the flat fill into a retained target --
	# permanently, since nothing re-bakes a chunk that has not been dug.
	if _tone == null:
		_tone = RockTone.new(probe.world_seed)
	_bake_margin = WINDOW_MARGIN_CELLS
	_bake = TerrainBake.new()
	add_child(_bake)
	var ok: bool = _bake.setup(probe.world_cells, probe.cell_px,
		observe_rect, _look, _tone, _baked_painters, WINDOW_MARGIN_CELLS)
	if not ok:
		# `free()`, not `remove_child` alone: removing a node from the tree does NOT free it, and the
		# declined bake would sit in memory holding its CanvasItem RID for the life of the process. On the
		# fallback path this happens on every headless run, which is every CI run.
		remove_child(_bake)
		_bake.free()
		_bake = null
		for paint: Callable in _baked_painters:
			add_painter(paint).z_index = z
		return false
	add_painter(Callable(_bake, &"draw_quad")).z_index = z
	_bake.bake_full()
	return true


## One observation covering `rect`, margined exactly as the per-frame path margins its own. The bake's only
## route to world state — see `TerrainBake`'s header for why a chunk cannot reuse the camera's observation.
func observe_rect(rect: Rect2) -> Interface.Observation:
	if _iface == null:
		return null
	return _iface.observe(Interface.Envelope.covering(rect, WINDOW_MARGIN_CELLS))


## Tell the bake that these cells changed, so their chunks repaint. A no-op when the bake declined, because
## the fallback painters redraw every frame anyway and have nothing to invalidate.
##
## THE CALLER MUST DO THIS ON EVERY DIG. A retained target is retained: nothing else will notice that the
## world changed, and the mined cell would keep its rock pixels until something else forced a full bake.
func invalidate_cells(cells: Array) -> void:
	if _bake != null:
		_bake.bake_cells(cells)


## The dilation the coordinator handed the bake, or -1 before `bake_static` ran. See `_bake_margin`.
func bake_margin() -> int:
	return _bake_margin


## The bake, or `null` when it declined. For a test asserting which path was taken — the two produce the
## same picture by design, so nothing in a capture can tell them apart, which is the point and also means a
## test cannot infer it.
func terrain_bake() -> TerrainBake:
	return _bake


## A painter that KEEPS STATE, handed over as an object rather than as a bound `Callable` — and the
## difference is not a style preference, it is D0289. A `Callable` built from a method on a `RefCounted`
## stores an object ID and does not keep the object alive, so `add_painter(CrumblePainter.new().paint)`
## freed its painter at the end of that expression and the layer drew nothing for the rest of the
## session, silently, while every suite passed.
##
## Taking the object means this can hold it. `_owned` is the only reason the array exists: nothing reads
## it, and that is the point — it is a lifetime, not a registry.
func add_stateful_painter(painter: RefCounted, method: StringName) -> PaintLayer:
	_owned.append(painter)
	return add_painter(Callable(painter, method))


## The screen-space half. A `HudLayer` is a `CanvasLayer`, so its children are not moved by the camera
## transform, and its chips use the SAME `(frame, ci)` painter signature as the world painters above.
##
## It hangs off the coordinator rather than off the scene so that the HUD and the world are painted from
## ONE frame per tick and cannot disagree about which tick they are showing -- the same reason
## `PaintLayer` asks for `current_frame()` at draw time instead of caching one. A HUD that held its own
## copy of the observation would go stale silently, and only on redraws the coordinator did not
## initiate: a resize, a focus change. `docs/LEGACY_GAP.md` H-01.
##
## One host, created on demand: a second call returns the same layer rather than a second `CanvasLayer`
## stacked on the first, which would double every chip.
func add_hud() -> HudLayer:
	if _hud == null:
		_hud = HudLayer.new()
		_hud.setup(self)
		add_child(_hud)
	return _hud


## THE LENS, mounted between the world and the HUD. Created on demand, and a second call returns the same
## layer rather than stacking a second graded pass on the first — which would apply the vignette and the
## grade twice and read as "the corners are too dark" rather than as a doubled layer.
##
## Returns `null` when the shader could not be loaded, and the caller carries on without a lens: a missing
## grade is a look regression, while a mounted ColorRect with no material is an opaque rectangle over the
## whole world.
func add_post_fx() -> PostFxLayer:
	if _post == null:
		var fx := PostFxLayer.new()
		if not fx.setup():
			fx.free()
			return null
		_post = fx
		add_child(_post)
	return _post


## The frame built for the current tick, or `null` before the first `refresh()`. `PaintLayer` reads this
## during its own `_draw`; it is not rebuilt per layer, so every painter in one tick sees one world.
func current_frame() -> Frame:
	return _frame


## Rebuild the frame and mark every layer dirty. Called by whoever owns the render cadence rather than
## from `_process`, so a headless test can step it deterministically without a running SceneTree clock.
func refresh() -> void:
	if _iface == null:
		return
	_anim_ticks += 1
	_frame = _build_frame()
	# THE BAKE IS TOLD WHAT CHANGED HERE, not at the dig site, and deliberately: a retained target is
	# retained, so a mined cell keeps its rock pixels until something invalidates its chunk. Doing it from
	# the frame the coordinator already built means no caller can forget it, and there is exactly one place
	# to look when a dig leaves a ghost. `mining_broke_cells` is empty on the overwhelming majority of ticks,
	# so this costs an `is_empty()` per tick on the common path.
	if _bake != null and not _frame.obs.mining_broke_cells.is_empty():
		_bake.bake_cells(_frame.obs.mining_broke_cells)
	for layer: PaintLayer in _layers:
		layer.queue_redraw()
	if _hud != null:
		_hud.refresh()
	# The lens rides the same deterministic clock as every animated painter (D0277). Fed here rather than
	# from a `_process` for the same reason `refresh()` itself is: a headless capture must be able to step
	# the renderer without a running SceneTree clock, and a grain on a wall clock would make two captures
	# of one tick differ.
	if _post != null:
		_post.set_anim_time(_frame.anim_time)


## The cosmetic clock's current value, in seconds. Monotonic, deterministic in the number of rendered
## ticks, and never read from a wall clock.
##
## Public so a test can assert the clock ADVANCES without reaching into `_anim_ticks` — an animation bug
## and a frozen clock look identical in a still frame, so the two have to be separable.
func anim_time() -> float:
	return float(_anim_ticks) * SECONDS_PER_TICK


## Puts the clock back to zero. For a capture that must reproduce a previous one exactly, and for a test
## that wants Q5's original guarantee: a painter asserted at an arbitrary clock value is asserting the
## clock rather than the painter.
func reset_anim_clock() -> void:
	_anim_ticks = 0


func _build_frame() -> Frame:
	var f: Frame = Frame.new()
	var rect: Rect2 = view_world_rect()
	f.obs = _iface.observe(Interface.Envelope.covering(rect, WINDOW_MARGIN_CELLS))
	f.anim_time = anim_time()
	f.view_world_rect = rect
	f.zoom = _camera.zoom.x if _camera != null else 1.0
	f.look = _look
	if _tone == null:
		_tone = RockTone.new(f.obs.world_seed)
	f.tone = _tone
	f.marks = PackedVector2Array()  ## empty in this build -- see Frame.marks
	return f


## The camera's world-space rectangle in pixels. Falls back to the viewport's own rect when there is no
## camera, rather than returning an empty one: an empty rect would make every painter cull everything
## and the screen would go black with nothing reporting an error.
func view_world_rect() -> Rect2:
	var vp: Viewport = get_viewport()
	if vp == null:
		return Rect2()
	var visible: Rect2 = vp.get_visible_rect()
	return get_canvas_transform().affine_inverse() * visible
