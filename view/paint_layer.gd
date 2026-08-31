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


func bind_to(view: WorldView, paint: Callable) -> void:
	_view = view
	_paint = paint


## Draws by asking the coordinator for the CURRENT frame rather than holding one.
##
## Godot may redraw a canvas for reasons the coordinator did not initiate -- a resize, a visibility
## change, a window regaining focus. Reading the frame at draw time means those redraws paint the same
## world as the tick that built it. A cached frame would go stale silently and only under exactly those
## conditions, which is the kind of defect that reproduces on someone else's machine and not on mine.
##
## A null frame is a no-op, not an error: `refresh()` has simply not run yet. Painting nothing for one
## frame at startup is correct; erroring would turn an ordinary ordering into a crash.
func _draw() -> void:
	if _view == null or not _paint.is_valid():
		return
	var frame: Frame = _view.current_frame()
	if frame == null:
		return
	_paint.call(frame, self)
