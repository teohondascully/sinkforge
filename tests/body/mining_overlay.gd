class_name MiningOverlay
extends RefCounted

## The cursor-aim mining HUD: the reach circle, the aim reticle, and per-cell crack progress. Slice 1,
## `docs/DECISIONS_LEDGER.md` D0195.
##
## WHY THIS IS NOT IN `view/`, WHICH IS WHERE IT BELONGS. It needs a `TileGrid` and a `Mining` to draw
## anything, and `tools/layer_lint`'s own table says `view` may reference `interface` and `core` -- not
## `sim`. `interface/` does not exist until Slice 2, so there is no legal way to hand a renderer the sim
## state it needs to draw. It sits beside the scene that uses it until that door exists. **This file is the
## seam made visible**: the day `interface.observe()` lands, this moves to `view/` and takes an observation
## instead of a grid, and nothing else about it changes.
##
## Deliberately flat colours and primitives, matching the reveal scene's own stated discipline: no shaders,
## no sprites, so an unfinished look cannot be mistaken for a verdict on feel. The legacy look is Slice 3.

const CELL: int = Heightfield.TERRAIN_CELL_PX

const COLOR_REACH: Color = Color(1.0, 1.0, 1.0, 0.10)
const COLOR_AIM_OK: Color = Color(0.95, 0.85, 0.35, 0.85)      ## a cell that can be mined from here
const COLOR_AIM_BLOCKED: Color = Color(0.85, 0.30, 0.25, 0.60) ## out of reach, or not solid
const COLOR_CRACK: Color = Color(0.05, 0.04, 0.03, 0.80)
const COLOR_TELL: Color = Color(0.55, 0.85, 1.0, 0.9)          ## the hollow reading, drawn as a bar

const REACH_SEGMENTS: int = 48
const CRACK_BARS: int = 3  ## how many "fracture lines" a fully-charged cell shows


## Everything the overlay draws, in one call. `canvas` is the Node2D doing the drawing; every coordinate
## here is world space, the same space the terrain rects are drawn in.
static func draw(canvas: CanvasItem, grid: TileGrid, mining: Mining, body_x: int, body_y: int,
		has_aim: bool, aim: Vector2i) -> void:
	var centre: Vector2 = Vector2(float(body_x) / float(Fx.SCALE), float(body_y) / float(Fx.SCALE))
	var radius: float = float(Mining.REACH_NUM * Mining.LOGIC_TILE_PX) / float(Mining.REACH_DEN)
	canvas.draw_arc(centre, radius, 0.0, TAU, REACH_SEGMENTS, COLOR_REACH, 1.0, true)
	_draw_cracks(canvas, mining, grid)
	if has_aim:
		_draw_reticle(canvas, grid, mining, body_x, body_y, aim)


## Every cell with banked charge, darkened in proportion to how close it is to breaking. This is the whole
## reason the crack bank is worth having as a mechanic: a player has to be able to SEE that a cell they
## walked away from kept its progress, or the bank may as well not exist.
static func _draw_cracks(canvas: CanvasItem, mining: Mining, grid: TileGrid) -> void:
	for cell: Vector2i in mining.cracked_cells():
		var cost: int = Mining.break_cost(grid.get_material(cell))
		if cost <= 0:
			continue
		var frac: float = clampf(float(mining.banked(cell)) / float(cost), 0.0, 1.0)
		var origin: Vector2 = Vector2(cell.x * CELL, cell.y * CELL)
		for i: int in CRACK_BARS:
			# Fracture lines appear one at a time as the charge fills, rather than one bar fading in: a
			# count reads as progress at 4px where an alpha ramp reads as noise.
			if frac < float(i + 1) / float(CRACK_BARS + 1):
				break
			var y: float = origin.y + float(CELL) * (float(i) + 0.5) / float(CRACK_BARS)
			canvas.draw_line(Vector2(origin.x, y), Vector2(origin.x + CELL, y), COLOR_CRACK, 1.0)


## The aimed cell, plus the hollow reading as a short bar leaning the way the blow faces. The bar is the
## only place the tell is legible without sound, and Slice 1 has no audio.
static func _draw_reticle(canvas: CanvasItem, grid: TileGrid, mining: Mining,
		body_x: int, body_y: int, aim: Vector2i) -> void:
	var workable: bool = grid.in_bounds(aim) and grid.is_solid(aim) and Mining.in_reach(body_x, body_y, aim)
	var rect: Rect2 = Rect2(aim.x * CELL, aim.y * CELL, CELL, CELL)
	canvas.draw_rect(rect, COLOR_AIM_OK if workable else COLOR_AIM_BLOCKED, false, 1.0)
	if not workable:
		return
	var dir: Vector2i = Mining.swing_dir(body_x, body_y, aim)
	var tell: float = float(Mining.hollow_at(grid, aim, dir)) / float(HollowTell.FULL)
	if tell <= 0.0:
		return
	var from: Vector2 = rect.get_center()
	var to: Vector2 = from + Vector2(dir) * (float(CELL) * (1.0 + 3.0 * tell))
	canvas.draw_line(from, to, Color(COLOR_TELL, 0.25 + 0.75 * tell), 1.0)
