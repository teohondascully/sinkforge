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

## The pinned cosmetic clock (Q5, ruled). One value, forever, because this build starts underground and
## no time system was authored -- see `Frame.anim_time`. It is a `const` rather than a `var` so that
## "the clock does not advance" is a property of the type instead of a promise in a comment.
const ANIM_TIME: float = 0.0

## How far past the camera rect to observe, in terrain cells. A painter deciding a cell's edges legitimately
## probes the ring just outside its own view, and `interface/interface.gd` says so: reading past the window
## is "deliberately not an error, because a renderer legitimately probes the ring just past its own window".
const WINDOW_MARGIN_CELLS: int = 2

var _iface: Interface = null
var _look: MaterialLook = null
var _camera: Camera2D = null
var _layers: Array[PaintLayer] = []
var _frame: Frame = null


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


## The frame built for the current tick, or `null` before the first `refresh()`. `PaintLayer` reads this
## during its own `_draw`; it is not rebuilt per layer, so every painter in one tick sees one world.
func current_frame() -> Frame:
	return _frame


## Rebuild the frame and mark every layer dirty. Called by whoever owns the render cadence rather than
## from `_process`, so a headless test can step it deterministically without a running SceneTree clock.
func refresh() -> void:
	if _iface == null:
		return
	_frame = _build_frame()
	for layer: PaintLayer in _layers:
		layer.queue_redraw()


func _build_frame() -> Frame:
	var f: Frame = Frame.new()
	var rect: Rect2 = view_world_rect()
	f.obs = _iface.observe(Interface.Envelope.covering(rect, WINDOW_MARGIN_CELLS))
	f.anim_time = ANIM_TIME
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
