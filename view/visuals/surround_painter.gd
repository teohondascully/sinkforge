class_name SurroundPainter
extends RefCounted

## THE EARTH PAST THE EDGE OF THE WORLD (T036, item 34, D0590). The sim has said this rock is there since
## D0457 -- `WorldSurroundings.blocks` answers TRUE for every cell outside the grid, "a cell past the grid
## blocks like rock, so the body stops at the edge" -- and the view has never drawn it. The player walks
## into a wall that is not pictured.
##
## WHAT WAS ACTUALLY THERE, measured rather than assumed: not empty canvas. With `--sky` on (the shipped
## path) `SkyPainter` fills everything below the horizon across the WHOLE view with `horizon_tone`, so the
## region past the edge is painted the sky's own below-horizon blue. Ground-coloured sky where earth
## should be, which is exactly why it reads as a broken canvas rather than as a place ending.
##
## Measured across the zoom ladder on the 64 m world (`docs/WORKING.md` item 34): 2.00 shows 40.0 m and no
## void at all, 1.40 shows 57.1 m and none, 1.00 shows 80.0 m and **256 px of it**, 0.66 shows 121.2 m and
## **915 px**. So this is confined to the two widest zooms and is a question about what the world ENDS
## WITH, never a width to change.
##
## ASTRA'S D7 RULING, 2026-09-10, is what picks among T036's four candidates: "a camera clamp cannot solve
## this when the viewport is wider than the world. Render a deliberate noninteractive continuation or
## boundary backdrop outside simulation bounds. Do not enlarge the simulation solely to fill the screen."
## And on the lore: "I prefer a visibly geological boundary for now... use a manufactured bore wall only if
## you want those implications, not because it conveniently conceals an edge." So: no wider world, no bore
## wall, no cliff. Continuous geology that the player cannot enter.
##
## IT IS DRAWN AS STRATA AND NOT AS A FILL, and that is the whole of whether this works. A single flat
## rectangle past the edge is the same defect in a different colour -- the reason the sky's blue reads as
## broken is that it is FEATURELESS, not that it is the wrong hue. So the beyond is drawn a metre at a
## time in `MaterialLook`'s own band colours, which is what makes it read as the continuation of the
## ground the player is standing on rather than as a painted backdrop behind it.
##
## AND IT RECEDES. Each metre's quad carries four colours -- near and far, top and bottom -- so the mass
## darkens away from the boundary over `RECEDE_M` toward `RECEDE_FLOOR`. That is what says "you cannot go
## there" without a fence: the seam at the world's edge is continuous with the terrain, and what lies past
## it visibly loses its light. A seamless continuation would have been worse than the void, because the
## body stops dead at a boundary the picture gave no reason for.
##
## THE LIGHT IS THE SHIPPED MODEL, NOT A NEW ONE. `VeilLight.level_rgb` over `VeilLight.sky_light`, with
## the mass fully shaded -- rock with rock on every side of it -- so the beyond takes the night level
## above the surface and the deep's ambient lift below it exactly as real terrain does (D0583, D0589). It
## cannot disagree with the world about the hour or the depth, because it is asking the same functions.

## How far the mass recedes before it reaches its floor, and what is left of it there. `RECEDE_M` is
## `VeilPainter.SKY_REACH_M`, the distance this world already uses for "how far light carries": the
## beyond fading over the same span as the sky's own reach keeps one scale in the picture rather than
## introducing a second. `RECEDE_FLOOR` is not zero on purpose -- black would read as a hole cut in the
## world, and a hole is the one thing this is here to stop looking like.
const RECEDE_M: float = VeilPainter.SKY_REACH_M
const RECEDE_FLOOR: float = 0.22

const FALLBACK: Color = Color(0.42, 0.34, 0.24)   ## `matrix_color`'s own unmapped-material brown

const CELL: float = float(Interface.Units.CELL_PX)
const M: float = float(Interface.Units.LOGIC_PX)


## How much light survives `dist_m` metres past the boundary.
static func recede(dist_m: float) -> float:
	return lerpf(1.0, RECEDE_FLOOR, clampf(dist_m / RECEDE_M, 0.0, 1.0))


## THE BEYOND IS THE EDGE COLUMN, CONTINUED. Not a chosen material and not a chosen darkness: the colour
## at a row is the colour `MaterialLook` gives the cell just INSIDE the boundary at that same row, so the
## seam is continuous by construction rather than by calibration.
##
## TWO GUESSES CAME BEFORE THIS AND A REAL FRAME REFUSED BOTH (D0597).
##   1. `band_color` at full strength -- `BackdropPainter`'s header had already named that trap. Measured
##      luma 0.381 against the reference's 0.190: a garish orange-and-blue wall brighter than the terrain.
##   2. `deepstone`, fully mass-shaded, lit by `VeilLight` and then drawn UNDER the veil. Measured on a
##      real capture at luma **0.022-0.054 against the terrain's 0.185** -- three to eight times too dark,
##      reading as a hole cut in the canvas, which is the one thing this painter exists to prevent. Both
##      halves were wrong: the material was a guess (dark basement rock beside the surface's clay) and the
##      lighting was applied twice.
## The lesson is the same one twice over, so it is worth writing down: every constant here was a guess at
## what the terrain looks like, and the terrain was right there to be asked.
##
## So there is no material constant, no mass-shade term and no lighting of its own. The veil lights it as
## it lights everything under `VEIL_Z`, and `recede` is the only thing this file still decides.
##
## Separated from `paint` so it is assertable: a colour is the part that can be silently wrong, and a test
## calling `paint` could only assert that it did not crash (the lesson `BackdropPainter.fill_color` was
## split out for).
static func mass_color(look: MaterialLook, o: Interface.Observation, edge_col: int, row: int) -> Color:
	if look == null or o == null:
		return FALLBACK
	var at := Vector2i(edge_col, row)
	var material: StringName = &""
	if o.in_window(at):
		material = o.material_at(at)
		if material == &"" and o.has_walls:
			material = o.wall_at(at)      # an open cell at the edge still has the wall behind it
	if material == &"":
		return FALLBACK
	return look.matrix_color(material, edge_col, row)


static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var o: Interface.Observation = frame.obs
	var view: Rect2 = frame.view_world_rect
	if view.size.x <= 0.0 or view.size.y <= 0.0:
		return
	var right_edge: float = float(o.world_cells.x) * CELL
	if view.position.x < 0.0:
		_side(frame, ci, view, view.position.x, 0.0, 0, -1)
	if view.end.x > right_edge:
		_side(frame, ci, view, right_edge, view.end.x, o.world_cells.x - 1, 1)


## One side of the world, a metre of depth at a time. `dir` is -1 for the earth left of column 0 and +1
## for the earth right of the last column: it decides which end of each quad is the near one, so the mass
## always recedes AWAY from the world rather than toward it.
static func _side(frame: Frame, ci: CanvasItem, view: Rect2, x0: float, x1: float, edge_col: int, dir: int) -> void:
	var o: Interface.Observation = frame.obs
	var surf_row: float = _edge_surface_row(o, edge_col)
	var top: float = maxf(view.position.y, surf_row * CELL)
	if x1 <= x0 or view.end.y <= top:
		return
	var near_x: float = x0 if dir > 0 else x1
	var row: int = int(floor(top / CELL))
	var step: int = MaterialLook.CELLS_PER_METRE
	while float(row) * CELL < view.end.y:
		var y0: float = maxf(float(row) * CELL, top)
		var y1: float = minf(float(row + step) * CELL, view.end.y)
		if y1 > y0:
			# FOUR COLOURS, NOT TWO (D0597). Each quad spans a metre, and a single colour per quad drew the
			# beyond as flat horizontal BANDS with a hard seam at every metre -- visible on the first real
			# capture, and the same featurelessness this painter exists to remove, at a smaller scale. The
			# top and bottom of each quad take their own row's colour, so the strata blend down the face.
			var c_top: Color = mass_color(frame.look, o, edge_col, row)
			var c_bot: Color = mass_color(frame.look, o, edge_col, row + step)
			var near: float = recede(absf(x0 - near_x) / M)
			var far: float = recede(absf(x1 - near_x) / M)
			ci.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
				PackedColorArray([_dim(c_top, near), _dim(c_top, far), _dim(c_bot, far), _dim(c_bot, near)]))
		row += step


static func _dim(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)


## The row the ground sits at just inside the edge, held flat outward so the seam is continuous. A column
## with no walkable floor (a shaft cut to the boundary, or one outside the observation window) falls back
## to the generator's own surface datum rather than to the top of the view, which would put sky underground.
static func _edge_surface_row(o: Interface.Observation, edge_col: int) -> float:
	var y: int = o.surface_y_at_terrain_col(edge_col)
	if y == Interface.Units.NO_FLOOR:
		return float(MaterialLook.SURFACE_ROW)
	return floor(float(y) / float(Fx.SCALE) / CELL)
