class_name Frame
extends RefCounted

## WHAT A PAINTER IS GIVEN, AND THE ONLY THING IT MAY READ. `docs/COORDINATOR_CONTRACT.md` §2, ruled by
## the director 2026-08-30; `docs/DECISIONS_LEDGER.md` D0240.
##
## Legacy's painters are not files that reference a coordinator -- they are extensions of one, reaching
## into ~14 private fields on `WorldRenderer` (`_anim_time`, `_view_world_rect`, `_cell_fill_color`,
## `_guide_targets`, ...). This class is what replaces that reach-in. A painter takes
## `(frame: Frame, ci: CanvasItem)`, is `static`, holds no state, and cannot see the coordinator at all.
##
## THE FOURTEEN FIELDS ARE FOUR KINDS, which is why this object is small: a cosmetic clock, a camera
## rect, the palette, and UI-marker positions. Sorting the reach-in by what SUPPLIES it rather than by
## name is what collapsed it -- the measurement is in the contract doc, and a reach-in COUNT turned out
## to be an upper bound on a contract's width rather than its width.
##
## `obs` IS HELD WHOLE, NOT FLATTENED. Copying the observation's fields up onto this object would put a
## second definition of the body's box edges in the tree, which is the drift `interface/interface.gd`'s
## own header says L2 exists to prevent.

## The sim half, verbatim. THE ONLY ROUTE TO SIM STATE a painter has: `view/` may depend on
## `{interface, core}` and never on `sim`, so there is no `TileGrid` here and no way to get one.
##
## Painters must ask `obs.in_window(c)`, NEVER `in_bounds`. `in_window` asks "was I given this cell";
## `in_bounds` asks "is this cell in the world". `material_at`/`wall_at` return `&""` outside the window
## -- not "unknown" -- so a painter that confuses them reads the viewport's edge as the world's edge and
## draws a wall where the screen stops. This is the trap named in D0238 and it lives here because here
## is where a painter author meets it.
var obs: Interface.Observation

## The cosmetic clock, in seconds. **A DETERMINISTIC TICK COUNTER, never a wall clock** (D0277, on the
## director's ruling re-opening Q5). It advances one `SECONDS_PER_TICK` per rendered tick, so an
## animation moves for a player watching it while two captures of the same tick remain byte-comparable —
## which `docs/QUALITY.md`'s whole screenshot discipline depends on.
##
## A painter may animate against this freely. What it may NOT do is treat it as a time of day: there is
## no day cycle, this build starts underground, and sky variation was ruled depth-driven rather than
## clock-driven. This is a cosmetic phase, not a calendar.
var anim_time: float = 0.0

## The camera's world-space rectangle in pixels, already margined. Painters cull against this rather
## than computing it -- legacy had two of them reaching for `_view_world_rect()` with different margins.
var view_world_rect: Rect2 = Rect2()

## The camera's zoom, for the handful of legacy decisions gated on it (label visibility, detail tiers).
var zoom: float = 1.0

## The palette: `data/` material records -> one `Color` per terrain cell.
var look: MaterialLook = null

## THE MOLDED-ROCK SHADING, or `null` before the first frame / in a fixture that did not build one.
##
## Separate from `look` rather than folded into it, and the reason is a dependency rather than taste:
## `MaterialLook` is a pure palette that needs nothing but `data/`, while `RockTone` must be seeded from
## `Observation.world_seed` and therefore cannot exist until an observation does. Folding it in would make
## every `MaterialLook.new()` in the test suite need a seed it has no opinion about.
##
## A painter must treat `null` as "draw the flat fill" rather than as an error — that is the picture this
## build drew before D0327 and it is always correct, only flatter.
var tone: RockTone = null

## World-pixel positions where a UI marker needs the background to get out of its way.
##
## THIS ONE FIELD REPLACES FIVE. `sky_painter` reached for `_guide_targets`, `_aim`, `_aim_in_reach`,
## `_ghost_def` and `_ghost_material`, and every one of them fed a single local inside `_stars`: the
## list of points where stars must fade so a marker over them stays legible. The painter does not need
## to know that a guide chevron or a build ghost exists; it needs to know where not to put stars.
##
## Collapsing them here also SEVERS `sky_painter`'S ONLY ROUTE TO THE DEAD ECONOMY -- `_ghost_def` was a
## `MachineDef`. **Empty in this build**, which legacy already handles as its designed path: "with no
## marker in the sky none of this fires and the field is exactly what it was."
var marks: PackedVector2Array = PackedVector2Array()


## A world point on the HUD canvas, through the view rect: the canvas IS the viewport, so a HUD chip that
## marks a thing in the world (the rung's target ring) maps through this and nothing else. Off-canvas
## far away when the frame has no view yet. Was `HintBubble.world_to_canvas` until D0413 moved the lessons
## off the body; the mapping outlived the bubble.
func canvas_of(world: Vector2) -> Vector2:
	var r: Rect2 = view_world_rect
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return Vector2(-1000.0, -1000.0)
	return Vector2((world.x - r.position.x) * UiTheme.CANVAS.x / r.size.x, (world.y - r.position.y) * UiTheme.CANVAS.y / r.size.y)
