class_name ViewWindow
extends RefCounted

## Which terrain cells a camera can actually see. Pure arithmetic, no engine types beyond `Vector2`/
## `Rect2i`, so the bound it establishes can be ASSERTED rather than eyeballed in a running scene.
##
## D0211. It exists because `play_scene._draw` used to scan `body_column +/- 200` by the FULL grid height
## every frame, which is both far more than fits on screen and -- because of the `maxi(0, ...)` clamp on
## the low end -- a window that GROWS as the body moves right: 208 columns at spawn, the full 400 once
## past column 200. The director felt that as "by 800 ticks or something it started to lag a decent
## amount," which at 150 px/s is about column 500, right where the window saturates.
##
## THE GATE THIS MAKES POSSIBLE IS A COUNT, NOT A CLOCK, and that is the point. A wall-clock threshold
## could not have caught the defect it replaces: CI runs headless, and the headless renderer is a dummy
## that does not rasterise (D0190 found it saving blank PNGs while reporting success), so render cost is
## invisible there. A duration assertion in this repo has also already inverted its own 12% margin under
## `JOBS=4` (the timing-layer rule in `docs/QUALITY.md`). Cells-visited is deterministic, needs no
## display, cannot flake, and is the quantity that actually regressed.


## The cell rect a camera at `centre_px` covers, given a viewport in pixels and a zoom, clamped to a
## `grid_w` x `grid_h` grid. One cell of margin on every side so a partially-visible cell at the edge is
## still drawn rather than popping in.
static func visible_cells(centre_px: Vector2, viewport_px: Vector2, zoom: float, cell_px: int,
		grid_w: int, grid_h: int) -> Rect2i:
	var half: Vector2 = (viewport_px / maxf(0.001, zoom)) * 0.5
	var lo_x: int = maxi(0, int(floor((centre_px.x - half.x) / float(cell_px))) - 1)
	var lo_y: int = maxi(0, int(floor((centre_px.y - half.y) / float(cell_px))) - 1)
	var hi_x: int = mini(grid_w, int(ceil((centre_px.x + half.x) / float(cell_px))) + 1)
	var hi_y: int = mini(grid_h, int(ceil((centre_px.y + half.y) / float(cell_px))) + 1)
	return Rect2i(Vector2i(lo_x, lo_y), Vector2i(maxi(0, hi_x - lo_x), maxi(0, hi_y - lo_y)))


## The most cells `visible_cells` can ever return for a given viewport/zoom/cell size, independent of
## where the camera is or how big the grid is. This is the bound a draw loop's per-frame work has to stay
## under, and the number a regression gate compares against -- stated here, next to the function it
## bounds, rather than re-derived at the call site where the two could drift apart.
static func max_cells(viewport_px: Vector2, zoom: float, cell_px: int) -> int:
	var span: Vector2 = viewport_px / maxf(0.001, zoom)
	var cols: int = int(ceil(span.x / float(cell_px))) + 3  ## +1 margin each side, +1 for a straddled cell
	var rows: int = int(ceil(span.y / float(cell_px))) + 3
	return cols * rows
