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

## Rock with rock on every side: what `VeilPainter.MASS_SHADE` costs a fully-buried cell.
##
## RAMPED IN, NOT APPLIED FLAT, for the same reason the real veil ramps it: a cell at an opening is not
## mass-shaded, and the beyond's top row IS at an opening -- the sky is directly above it. Applied flat,
## the surface row measured 0.041 against the 0.155 of the ground standing beside it, a four-fold step
## that would have drawn a black bar along the top of the boundary. `VeilLight.under_rock` is the ramp
## the veil already uses over its own scatter band, so the two agree by construction.
const BEYOND_SHADE: float = 1.0 - VeilPainter.MASS_SHADE


## How much of the light survives the mass at a row: none of it lost at the surface, `BEYOND_SHADE` deep.
static func mass_shade(row: int, surf_row: float) -> float:
	return lerpf(1.0, BEYOND_SHADE, VeilLight.under_rock(float(row), surf_row))

## How far the mass recedes before it reaches its floor, and what is left of it there. `RECEDE_M` is
## `VeilPainter.SKY_REACH_M`, the distance this world already uses for "how far light carries": the
## beyond fading over the same span as the sky's own reach keeps one scale in the picture rather than
## introducing a second. `RECEDE_FLOOR` is not zero on purpose -- black would read as a hole cut in the
## world, and a hole is the one thing this is here to stop looking like.
const RECEDE_M: float = VeilPainter.SKY_REACH_M
const RECEDE_FLOOR: float = 0.22

## The country rock past the edge. `hardrock` rather than the band's own material: see `mass_color`.
const BEDROCK: StringName = &"deepstone"
const FALLBACK: Color = Color(0.42, 0.34, 0.24)   ## `matrix_color`'s own unmapped-material brown

const CELL: float = float(Interface.Observation.CELL_PX)
const M: float = float(Interface.Observation.LOGIC_PX)


## How much light survives `dist_m` metres past the boundary.
static func recede(dist_m: float) -> float:
	return lerpf(1.0, RECEDE_FLOOR, clampf(dist_m / RECEDE_M, 0.0, 1.0))


## THE MATERIAL IS BEDROCK AND IT IS NOT THE BAND'S COLOUR, which is the trap this function fell into
## once and `BackdropPainter`'s own header had already named: legacy's band colours "were authored as
## ANNOUNCEMENT colours -- type on a dark plate, every one between 0.44 and 0.96 in its brightest channel
## -- and are far too bright to use as fills at full strength", which is why that painter only ever takes
## 10% of one. Measured on the first draft of this file, which used `band_color` at full strength: the
## beyond came out at luma 0.3658 where the reference's unlit deep rock is 0.190, a garish orange-and-blue
## striped wall brighter than the terrain in front of it -- and `the_seal`'s band colour is PURPLE
## (`data/bands/the_seal.yaml`, [0.72, 0.44, 0.86]).
##
## So it takes `matrix_color`, the path the terrain itself takes, which carries the material's own
## `depth_darken` and `BeddingTone`'s bedding -- and it takes ONE material rather than the band's, because
## undifferentiated bedrock is the more truthful picture: past the edge is not more of the player's world,
## it is the rock their world is cut into. The bedding still lands, because `BeddingTone` is keyed on
## (col, row) and the columns here are the world's own continued outward, so a bed running off the edge
## keeps running.
##
## Separated from `paint` so it is assertable: a colour is the part that can be silently wrong, and a test
## calling `paint` could only assert that it did not crash (the lesson `BackdropPainter.fill_color` was
## split out for).
static func mass_color(look: MaterialLook, col: int, row: int, surf_row: float) -> Color:
	var sky: float = VeilLight.sky_light(float(row), surf_row)
	var deep_t: float = clampf((1.0 - sky) / VeilPainter.AMBIENT_DARK, 0.0, 1.0)
	var lit: Color = VeilLight.level_rgb(mass_shade(row, surf_row) * sky, deep_t)
	var base: Color = FALLBACK if look == null else look.matrix_color(BEDROCK, col, row)
	return Color(base.r * lit.r, base.g * lit.g, base.b * lit.b)


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
			var c: Color = mass_color(frame.look, int(floor(near_x / CELL)) + dir * (row & 7), row, surf_row)
			var a: Color = _dim(c, recede(absf(x0 - near_x) / M))
			var b: Color = _dim(c, recede(absf(x1 - near_x) / M))
			ci.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
				PackedColorArray([a, b, b, a]))
		row += step


static func _dim(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k)


## The row the ground sits at just inside the edge, held flat outward so the seam is continuous. A column
## with no walkable floor (a shaft cut to the boundary, or one outside the observation window) falls back
## to the generator's own surface datum rather than to the top of the view, which would put sky underground.
static func _edge_surface_row(o: Interface.Observation, edge_col: int) -> float:
	var y: int = o.surface_y_at_terrain_col(edge_col)
	if y == Interface.Observation.NO_FLOOR:
		return float(MaterialLook.SURFACE_ROW)
	return floor(float(y) / float(Fx.SCALE) / CELL)
