class_name TerrainPainter
extends RefCounted

## THE TERRAIN, DRAWN BY A PAINTER ON THE COORDINATOR. `docs/LEGACY_GAP.md` T1 #4 — "the structural
## unlock for every painter below it", and the reason it is ranked so high despite drawing nothing new:
## until terrain arrives through `Frame`, the wall plane (T1 #3), the veil (T1 #2) and every later pass
## have nowhere to sit. `WorldView` carried exactly one painter (sky) and only under `--sky`.
##
## WHAT MOVED, AND WHAT DID NOT. `tests/body/reveal_terrain_draw.gd` drew the same cells straight onto the
## debug scene's canvas from a live `TileGrid`. This reads `frame.obs` instead, which is the whole point:
## a painter that holds a `TileGrid` can read any cell it likes and the envelope is decorative. The
## picture is the same today. The DIFFERENCE is that every pass added after this one inherits the
## boundary rather than having to be talked into it.
##
## **THE CULL IS NOW THE WINDOW, NOT TWO HARDCODED CAPS, and that is a correctness change rather than a
## tidy-up.** The old loop scanned `body_col ± 60` columns and capped rows at 120 — or at a
## `wide_view_row_cap` passed in specially, because `--wide-view` needs the whole topsoil band and the
## 120 cap would have sliced it. Both numbers existed because the loop had no idea what was on screen.
## An observation does: `obs.window` IS the camera rect plus `WorldView.WINDOW_MARGIN_CELLS`, so the
## wide view and the follow view need no special case between them, and a zoom the caps never anticipated
## draws correctly instead of clipping to a rectangle nobody chose.
##
## Legacy's `terrain_painter.gd` is 438 lines and its later passes — the autotile silhouette chamfers,
## the concave fillets, the carved-edge ambient occlusion, the surface cap and ramp — are what make rock
## read as carved rather than as a grid of squares. **None of them is here.** They are `LEGACY_GAP` T1 #2
## and T1 #3, they are the reason this file will grow, and they land on top of this structure rather than
## alongside it. Claiming them now by porting half of one would make the gap doc lie about what is done.

## How far outside the visible rect to keep drawing, in cells. One cell, because a cell straddling the
## edge must be drawn whole or the screen border shows a seam of half-tiles; the observation itself
## carries a wider margin (`WorldView.WINDOW_MARGIN_CELLS`) for passes that probe neighbours.
const OVERDRAW_CELLS: int = 1


## The cell range to visit for a given view rect, clipped to what the observation actually holds.
##
## Returned as a `Rect2i` and separately testable because it is the half of this painter that can be
## WRONG in a way a screenshot hides: a range one cell short leaves a seam only at the screen edge, and
## a range that silently collapses to nothing draws a black frame that looks like a load failure. The
## test asserts it against the window rather than against the numbers.
static func visit_rect(obs: Interface.Observation, view_world_rect: Rect2, cell_px: int) -> Rect2i:
	if cell_px <= 0:
		return Rect2i()
	var lo := Vector2i(
		int(floor(view_world_rect.position.x / float(cell_px))) - OVERDRAW_CELLS,
		int(floor(view_world_rect.position.y / float(cell_px))) - OVERDRAW_CELLS)
	var hi := Vector2i(
		int(ceil(view_world_rect.end.x / float(cell_px))) + OVERDRAW_CELLS,
		int(ceil(view_world_rect.end.y / float(cell_px))) + OVERDRAW_CELLS)
	# Clipped to the window, not merely intersected with it: reading past the window returns `&""`, which
	# a painter cannot tell from "no material here". Visiting only cells the observation was actually
	# given means the loop never has to make that distinction.
	var clipped: Rect2i = Rect2i(lo, hi - lo).intersection(obs.window)
	return clipped


## Every solid cell in view, filled. `frame.look` supplies the colour, which is deterministic in
## `(material, col, row)` — two runs of one seed paint identically, which is what
## `docs/QUALITY.md`'s screenshot comparison rests on.
##
## An incomplete frame paints nothing rather than erroring: `WorldView` builds one every rendered tick
## and a painter must not be the thing that turns a startup frame into a crash. Same rule as
## `view/paint_layer.gd`'s null-frame guard.
static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.look == null or frame.obs.cell_px <= 0:
		return
	var cell_px: int = frame.obs.cell_px
	var r: Rect2i = visit_rect(frame.obs, frame.view_world_rect, cell_px)
	for col: int in range(r.position.x, r.end.x):
		for row: int in range(r.position.y, r.end.y):
			var material: StringName = frame.obs.material_at(Vector2i(col, row))
			if material == &"":
				continue
			ci.draw_rect(Rect2(col * cell_px, row * cell_px, cell_px, cell_px),
				frame.look.cell_color(material, col, row), true)
