class_name Envelope
extends RefCounted

## WHAT A CONSUMER IS ALLOWED TO SEE. Today: a rectangle of cells, in cell coordinates.
##
## `window` is REQUIRED and has no default, on purpose. An envelope that means "everything" is the one
## an agent measuring discoverability must never be handed by accident, and a defaulted whole-world
## window is exactly how that happens. `oracle_over()` exists to make the unfiltered case say its own
## name at the call site.
##
## SPLIT OUT OF `interface/interface.gd` (D0294) when that file hit its 400-line cap, and taken as a seam
## rather than a trim — `docs/QUALITY.md` §2 records what happens when a cap is met by shaving
## WHY-comments instead. It is still reached as `Interface.Envelope`, through a `const` in that file, so
## no call site moved. Deliberately no `class_name`: `Interface.Envelope` is the one name this should be
## It carries a `class_name` so its own static factories can name their return type — a script with no
## global name cannot refer to itself in a signature, and `-> RefCounted` would have thrown away the
## type checking that makes those factories worth having. `Interface.Envelope` remains the name to use.

var window: Rect2i

func _init(cell_window: Rect2i) -> void:
	window = cell_window

## Perfect spatial information over a whole grid -- §5's Oracle envelope, as far as this build has a
## mechanism for it. Named rather than written as a literal `Rect2i(0, 0, w, h)` at each call site so
## a reader can see which runs are unfiltered.
static func oracle_over(grid: TileGrid) -> Envelope:
	return Envelope.new(Rect2i(0, 0, grid.width, grid.height))

## The window covering a world-PIXEL rectangle, grown by `margin_cells` on every side.
##
## THIS LIVES HERE BECAUSE THE CONVERSION NEEDS A `sim/` CONSTANT and its caller is `view/`, which may
## depend on `{interface, core}` and not on `sim`. The alternative -- re-declaring the terrain cell
## size in `view/` -- would put a second definition of a world-scale number in the tree, and the near
## miss is worth recording: `view/visuals/material_look.gd` already carries `CELLS_PER_METRE = 4`,
## which is a DIFFERENT quantity (cells per metre, not pixels per cell) that happens to share the
## value at 16px/m. Reaching for it would have been right by coincidence and wrong by construction.
##
## `floor` on the near edge and `ceil` on the far one, never `int()`: truncation toward zero drops
## the partially-visible row at the top and left of the screen, a one-cell strip of undrawn world
## that appears only at some camera positions and reads as flicker rather than as a missing feature.
static func covering(world_rect: Rect2, margin_cells: int) -> Envelope:
	var cell: float = float(Heightfield.TERRAIN_CELL_PX)
	var margin := Vector2i(margin_cells, margin_cells)
	var lo := Vector2i(int(floor(world_rect.position.x / cell)),
		int(floor(world_rect.position.y / cell))) - margin
	var hi := Vector2i(int(ceil(world_rect.end.x / cell)),
		int(ceil(world_rect.end.y / cell))) + margin
	return Envelope.new(Rect2i(lo, hi - lo))


