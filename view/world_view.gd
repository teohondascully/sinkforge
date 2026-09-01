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
const WINDOW_MARGIN_CELLS: int = 3

var _iface: Interface = null
var _look: MaterialLook = null
var _camera: Camera2D = null
var _layers: Array[PaintLayer] = []
## Painters that keep state, held so they outlive the expression that created them. See
## `add_stateful_painter` — nothing reads this array, it exists to be a reference.
var _owned: Array[RefCounted] = []
var _frame: Frame = null
var _hud: HudLayer = null


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
	for layer: PaintLayer in _layers:
		layer.queue_redraw()
	if _hud != null:
		_hud.refresh()


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
