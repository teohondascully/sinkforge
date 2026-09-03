class_name DigPlan
extends RefCounted

## THE DIG PLAN: sweep-paint marks on every solid cell the cursor crosses while the mine button is held,
## sampled sub-cell so a fast drag skips no block, allowed beyond reach (the plan is where you intend to
## dig; reach gates the work, not the sketch). When the cursor itself offers no workable block, the
## nearest marked cell the body can work becomes the work target: the precise hover always wins, the
## plan drains when the hand is free. Lifted in A' step 3i (D0354) from `legacy/scenes/main.gd`
## `_paint_dig_marks` 1806 and `_nearest_marked_workable` 1824.
##
## STATE, signed: a mark decides which cell the hand digs next, so two runs with different plans break
## different cells. Legacy did not save it; the save gains it with the mining state (D0354). Legacy's
## tool-tier gate on a mark is the dead economy and is not here. The cap is legacy's 200 metre-marks
## as 4 px cells along a drag: a line crosses four times as many.

const MAX_MARKS: int = 800
const HALF_CELL_FX: int = Aim.CELL_FX / 2

var marks: Dictionary = {}   # terrain_cell -> true


## Mark every solid cell the segment from the last pointer position to this one crosses, sampled every
## half cell along it. Both ends are `Fx` world points.
func paint(grid: TileGrid, from_x: int, from_y: int, to_x: int, to_y: int) -> void:
	var span: int = Fx.length(to_x - from_x, to_y - from_y)
	var steps: int = maxi(1, (span + HALF_CELL_FX - 1) / HALF_CELL_FX)
	for i: int in steps + 1:
		var cell: Vector2i = Aim.cell_of(from_x + ((to_x - from_x) * i) / steps, from_y + ((to_y - from_y) * i) / steps)
		if marks.has(cell) or marks.size() >= MAX_MARKS:
			continue
		if grid.in_bounds(cell) and grid.is_solid(cell):
			marks[cell] = true


## The marked cell nearest the body that can be worked right now (solid, in reach, in sight), or
## `Mining.NO_CELL`. Prunes spent marks (cells already dug) as it scans, so the plan never points at air.
## Cells are visited in scan order and a nearer cell must be strictly nearer, so ties are stable.
func nearest_workable(grid: TileGrid, body_x: int, body_y: int) -> Vector2i:
	var best: Vector2i = Mining.NO_CELL
	var best_d: int = -1
	var body_cell: Vector2i = Aim.cell_of(body_x, body_y)
	for cell: Vector2i in Ordering.cells(marks):
		if not grid.is_solid(cell):
			marks.erase(cell)            # dug, by hand or by the plan itself: the mark is spent
			continue
		if not Mining.in_reach(body_x, body_y, cell) or not LineOfSight.clear(grid, body_cell, cell):
			continue                     # out of reach or out of sight: stays in the plan
		var centre: Vector2i = Aim.cell_center_fx(cell)
		var d: int = Fx.length_sq(centre.x - body_x, centre.y - body_y)
		if best_d < 0 or d < best_d:
			best_d = d
			best = cell
	return best


func clear() -> void:
	marks.clear()


func capture() -> Array[Vector2i]:
	return Ordering.cells(marks)


func restore(cells: Array) -> void:
	marks.clear()
	for cell: Vector2i in cells:
		marks[cell] = true


func state_signature() -> String:
	var parts: PackedStringArray = []
	for cell: Vector2i in Ordering.cells(marks):
		parts.append("%d,%d" % [cell.x, cell.y])
	return "p" + ";".join(parts)
