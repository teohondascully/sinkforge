class_name HudLayer
extends CanvasLayer

## THE HUD HOST — `docs/LEGACY_GAP.md` H-01, the prerequisite every one of Lane H's sixty-five rows was
## blocked on. Before this, the build drew **zero text**, had no `CanvasLayer` and no font handle.
##
## IT IS A `CanvasLayer` AND ITS CHILDREN ARE ORDINARY `PaintLayer`s, which is the whole design and took
## one line rather than a parallel painter contract. A `CanvasLayer`'s children are not moved by the
## camera transform, so a painter parented here draws in SCREEN pixels while using exactly the same
## `(frame: Frame, ci: CanvasItem)` signature as `view/visuals/sky_painter.gd`. The alternative — a
## second contract for screen-space painters, with its own frame type carrying viewport size — would
## have doubled the surface a painter author has to learn in order to buy nothing: a HUD painter that
## needs the viewport can ask its own canvas for it.
##
## Legacy's `hud.gd` is 2,189 lines against this project's 400-line gate, and it is one `_draw` with
## thirty-odd `_draw_*` methods reaching into fields on the page. **Nothing is ported from its
## structure** — the chips are lifted underneath this object one at a time, each a static function, in
## the same shape the world painters already use. `legacy/scenes/hud.gd`'s own measurement says this is
## affordable: only 15 of its call sites read the sim at all, across five surfaces, so most of the HUD
## needs no new sim accessor.
##
## WHAT IT DOES NOT OWN. No `Interface`, no sim object, no state of its own beyond the layers it built.
## It is handed a `WorldView` and asks that for the current frame, exactly as `PaintLayer` does — so the
## HUD and the world are painted from ONE frame per tick and cannot disagree about which tick they are
## showing. That disagreement is not hypothetical: it is what a HUD caching its own copy of the
## observation would produce, silently, on any redraw the coordinator did not initiate.

## Above the world, below nothing yet. Godot draws `CanvasLayer`s in ascending `layer` order and the
## default (0) is where `Node2D` world content lives, so an explicit value is what keeps the HUD from
## depending on child order in a scene file.
const HUD_CANVAS_LAYER: int = 10

var _view: WorldView = null
var _layers: Array[PaintLayer] = []
## Chips that keep state, held so they outlive the expression that created them (D0289). Nothing reads
## this array; it exists to be a reference.
var _owned: Array[RefCounted] = []


## Constructor-by-method, matching `WorldView.setup` — so this node can also come from a scene file
## later without the engine having to supply arguments.
func setup(view: WorldView) -> void:
	_view = view
	layer = HUD_CANVAS_LAYER


## Adds one chip. `paint` must be a `(Frame, CanvasItem) -> void` static function.
##
## Returns the layer so a caller can order or hide an individual chip without this object having to
## grow a name->layer map for a lookup nobody has needed yet.
func add_chip(paint: Callable) -> PaintLayer:
	var canvas := PaintLayer.new()
	canvas.bind_to(_view, paint)
	canvas.label = DrawCost.label_for(paint)   # named in the cost report like a world painter (D0414: a 3 ms chip read as "?")
	add_child(canvas)
	_layers.append(canvas)
	return canvas


## A chip that KEEPS STATE — an arrival ceremony outlives the tick that fired it — handed over as an
## object rather than as a bound `Callable`. See `WorldView.add_stateful_painter`: a `Callable` does not
## keep a `RefCounted` alive, so the bound form frees the chip before this method is even entered
## (D0289).
func add_stateful_chip(chip: RefCounted, method: StringName) -> PaintLayer:
	_owned.append(chip)
	return add_chip(Callable(chip, method))


## Marks every chip dirty. Called once per rendered tick by whoever owns the coordinator, AFTER
## `WorldView.refresh()` — each `PaintLayer._draw` then pulls `current_frame()` itself, so a chip that
## Godot redraws for its own reasons (a resize, a focus change) still paints the same tick the world
## does rather than a stale copy.
func refresh() -> void:
	for canvas: PaintLayer in _layers:
		canvas.queue_redraw()


## For tests and for a caller that wants to assert it built what it meant to. Returns the count rather
## than the array so nothing outside can mutate the list this object maintains.
func chip_count() -> int:
	return _layers.size()


## The chips themselves, for `DrawCost.report` -- a HUD chip is a `PaintLayer` and stamps its own cost,
## and a frame budget that leaves the HUD out is measuring part of the frame.
func layers() -> Array[PaintLayer]:
	return _layers
