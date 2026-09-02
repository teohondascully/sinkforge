class_name PaintLayer
extends Node2D

## ONE PAINTER'S CANVAS. A `WorldView` creates one of these per painter and the painter draws onto it,
## rather than onto the coordinator. `docs/COORDINATOR_CONTRACT.md` §2a, ruled; D0240.
##
## WHY A NODE PER PAINTER instead of one `_draw` on the coordinator. Legacy has both conventions --
## `sky_painter`/`terrain_painter` take a `ci: CanvasItem` argument, while `water_view`/`rope_view`/
## `machine_view` call `_wr.draw_line(...)` on the coordinator itself (49 sites between them) -- and the
## rebuild has to pick one. The explicit canvas wins on three counts, only one of which is taste:
##
##   * **Parallax needs several canvases and a coordinator is only one.** A sky that drifts against the
##     terrain is two transforms, not two draw orders. `view/fx/light_layer.gd` is already exactly this
##     shape: a separate canvas carrying its own blend mode.
##   * A painter that receives its canvas is testable with **no coordinator at all**.
##   * It is already the convention of the two painters actually being lifted.
##
## This class holds no drawing logic of its own and never will. It exists so a painter can be a pure
## static function of `(Frame, CanvasItem)` while still living inside a scene tree.

var _view: WorldView = null
var _paint: Callable = Callable()

## PER-LAYER DRAW COST, in microseconds, for the last `_draw` this layer actually ran.
##
## **A FRAME BUDGET WITH NO ATTRIBUTION IS A COMPLAINT, NOT A MEASUREMENT.** The build renders at 15.4
## fps against a 120 Hz bar and the stack is nine layers deep; "the renderer is slow" names none of them.
## Recording it here rather than in the coordinator is what makes the number a per-PAINTER cost instead of
## a per-frame total, and this is the only place that knows which painter a `_draw` belongs to.
##
## Two `Time.get_ticks_usec()` reads per layer per frame — about 40 ns against a 64 ms frame, so it is
## always on rather than behind a debug flag that would be off exactly when someone needs the number.
## It records ONLY; nothing here feeds the picture, so it cannot move a pixel or a determinism hash.
var last_draw_usec: int = 0
## Which painter this layer carries, for the cost report. Set by `WorldView.add_painter` from the
## callable itself, so a layer cannot be mislabelled by a caller passing the wrong string.
var label: StringName = &"?"


## THE BIND REFUSES A DEAD CALLABLE, LOUDLY, and D0289 is why that guard is here rather than in a
## comment. A `Callable` bound to a method on a `RefCounted` stores an object ID and **does not keep the
## object alive**, so `add_painter(CrumblePainter.new().paint)` frees its painter at the end of the
## expression — before `add_painter` is even entered. `_draw` below then found `not _paint.is_valid()`,
## returned, and drew nothing, every frame, in silence. Every suite passed, because a suite constructs
## its painter and holds it.
##
## Failing at bind time turns that into one loud line at startup instead of an invisible layer. Use
## `WorldView.add_stateful_painter` / `HudLayer.add_stateful_chip` for a painter that keeps state; they
## retain the object.
func bind_to(view: WorldView, paint: Callable) -> void:
	if not paint.is_valid():
		push_error("PaintLayer.bind_to: the callable is already dead. A Callable does not keep a "
			+ "RefCounted alive -- use add_stateful_painter/add_stateful_chip for a painter with state.")
		return
	_view = view
	_paint = paint


## Draws by asking the coordinator for the CURRENT frame rather than holding one.
##
## Godot may redraw a canvas for reasons the coordinator did not initiate -- a resize, a visibility
## change, a window regaining focus. Reading the frame at draw time means those redraws paint the same
## world as the tick that built it. A cached frame would go stale silently and only under exactly those
## conditions, which is the kind of defect that reproduces on someone else's machine and not on mine.
##
## Is this layer actually going to paint anything? For a test and for a caller asserting it wired what it
## meant to — `bind_to` refusing a dead callable is only useful if something can ask afterwards, and
## D0289's whole shape was a layer that looked mounted and drew nothing.
func painter_is_live() -> bool:
	return _view != null and _paint.is_valid()


## A null frame is a no-op, not an error: `refresh()` has simply not run yet. Painting nothing for one
## frame at startup is correct; erroring would turn an ordinary ordering into a crash.
func _draw() -> void:
	if not painter_is_live():
		return
	var frame: Frame = _view.current_frame()
	if frame == null:
		return
	# Measured around the painter ONLY, not around the early returns above: a layer that returned before
	# painting would otherwise report a real cost for having done nothing, and the whole point of the
	# number is to rank painters against each other.
	var began: int = Time.get_ticks_usec()
	_paint.call(frame, self)
	last_draw_usec = Time.get_ticks_usec() - began
