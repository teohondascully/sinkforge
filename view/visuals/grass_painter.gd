class_name GrassPainter
extends RefCounted

## GRASS STANDING IN THE AIR ABOVE THE GROUND (item 28, D0595).
##
## `SurfaceTone` already carries moss, roots, blades and hanging tufts, and every one of them is drawn
## WITHIN the cap cell -- they are a texture on the top face, not a silhouette against the sky. So the
## ground still ended at a hard horizontal line one cell thick, which is the single most 2016 thing about
## a surface. Real height variation means drawing into the air ROW ABOVE the surface, and nothing did.
##
## THE GREEN IS THE TREES', NOT A SECOND ONE. `leaves`' own `base_color` from the records, varied per
## column by `BeddingTone.foliage_tone` -- the same function that gives two trees standing side by side
## different greens (D0584). Grass and canopy therefore drift together rather than apart, and there is one
## place to change what "plant" looks like in this world.
##
## IT IS UNDER THE VEIL, which is the whole of its lighting. Drawn at `SurfaceTone`'s own depth in the
## stack, so the veil multiplies it exactly as it multiplies the ground the blades stand in: grass at
## night is night-dark, grass in a lamp's pool is lit, and this file holds no opinion about either. A
## separate additive pass would have needed its own copy of the light model and would have drifted.
##
## ONE DRAW CALL FOR THE WHOLE FIELD. Every blade is a segment in one `PackedVector2Array` and the batch
## goes out through `draw_multiline_colors`. At the widest zoom the view holds ~1,900 soil columns; a
## blade apiece as its own `draw_line` would be 1,900 calls a frame for decoration, which is how a
## cosmetic becomes a performance item. Registered STATIC as well -- it is a pure function of the camera
## rect and the observation, so it rebuilds when the terrain or the camera moves and not on a clock.
##
## NO SWAY, DELIBERATELY, AND IT IS THE OBVIOUS NEXT THING. Sway needs the clock, which means `animated`,
## which means rebuilding the batch every tick; that is a real cost to weigh against a real charm and it
## should be weighed on a frame rather than assumed here. Item 28 asked for height variation.

## The blade's height in terrain cells, at its shortest and its tallest. A cell is 4 px and a metre is
## four cells, so this runs from a quarter of a metre to a little over half: ankle height on a 10-cell
## body, which is what keeps it reading as ground cover rather than as a crop.
const MIN_CELLS: float = 1.0
const MAX_CELLS: float = 2.4

## Blades per terrain column. Two is enough to break the line without making the surface look furred, and
## it is the count the one-draw-call budget was sized against.
const PER_COLUMN: int = 2

## How far a tip leans off vertical, in cells. Constant lean with varying height is what reads as grass
## rather than as a comb.
const LEAN_CELLS: float = 0.55

## The blade's colour against `leaves`' own, and the ground it stands in. Grass is a shade darker than
## canopy -- it sits in the ground's own shadow and a blade lit like a treetop reads as glowing.
const GRASS_DARKEN: float = 0.18
const WIDTH_PX: float = 1.0

const CELL: float = float(Interface.Observation.CELL_PX)


## The green a column's grass is, before the veil. Public because it is the part that can be silently
## wrong: a blade drawn at the wrong height is visible, a blade drawn in the wrong green is not.
static func blade_color(col: int, surf_row: int) -> Color:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(&"leaves", {})
	var base: Color = Color(0.18, 0.40, 0.23)
	if rec.has("base_color"):
		var c: Array = rec["base_color"]
		base = Color(float(c[0]), float(c[1]), float(c[2]))
	return BeddingTone.apply_tone(base.darkened(GRASS_DARKEN), BeddingTone.foliage_tone(col, surf_row))


## How tall a blade stands, in cells: deterministic in (column, blade), never a hash. Two incommensurable
## sines, so the field never visibly repeats along a hillside and neighbouring blades differ.
static func blade_height(col: int, blade: int) -> float:
	var x: float = float(col) + float(blade) * 0.37
	var n: float = sin(x * 1.31) * 0.5 + sin(x * 0.47 + 1.7) * 0.5
	return lerpf(MIN_CELLS, MAX_CELLS, clampf(n * 0.5 + 0.5, 0.0, 1.0))


## Which way and how far the tip leans, in cells.
##
## TWO INCOMMENSURABLE SINES, for the same reason `blade_height` has them, and this file shipped with one
## until its own suite refused it: a single sine at 0.83 has a period of about 7.6 columns, which is 30 px
## of surface, so the tips would have leaned in a regular repeating wave -- a comb with a wobble. 400
## columns gave 211 distinct leans against the height's 383. Two frequencies that share no common period
## put it at the same order as the height, and the suite pins the count rather than the constants.
static func blade_lean(col: int, blade: int) -> float:
	var x: float = float(col) + float(blade) * 1.7
	return (sin(x * 0.83) * 0.62 + sin(x * 0.37 + 2.2) * 0.38) * LEAN_CELLS


## Does soil at this column carry grass? The record's own `soil` flag, read from `data/` exactly as
## `MaterialLook` reads every other material property -- `sim/world/materials.gd`'s `is_soil` is the same
## rule and the view may not reach it (layer lint), so this reads the record rather than restating a list.
static func grassy(material: StringName) -> bool:
	return bool((MaterialsRecords.RECORDS.get(material, {}) as Dictionary).get("soil", false))


static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var o: Interface.Observation = frame.obs
	var view: Rect2 = frame.view_world_rect
	if view.size.x <= 0.0:
		return
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var col: int = maxi(int(floor(view.position.x / CELL)) - 1, 0)
	var last: int = mini(int(ceil(view.end.x / CELL)) + 1, o.world_cells.x - 1)
	while col <= last:
		var surf: int = _surface_row(o, col)
		if surf >= 0 and grassy(o.material_at(Vector2i(col, surf))):
			var tint: Color = blade_color(col, surf)
			var foot_y: float = float(surf) * CELL
			for blade: int in PER_COLUMN:
				var fx: float = (float(col) + (float(blade) + 0.5) / float(PER_COLUMN)) * CELL
				var h: float = blade_height(col, blade) * CELL
				points.append(Vector2(fx, foot_y))
				points.append(Vector2(fx + blade_lean(col, blade) * CELL, foot_y - h))
				colors.append(tint)
				colors.append(tint)
		col += 1
	if not points.is_empty():
		ci.draw_multiline_colors(points, colors, WIDTH_PX)


## The walkable surface row of a column, or -1 where the column has none inside the window.
static func _surface_row(o: Interface.Observation, terrain_col: int) -> int:
	var y: int = o.surface_y_at_terrain_col(terrain_col)
	if y == Interface.Observation.NO_FLOOR:
		return -1
	return int(floor(float(y) / float(Fx.SCALE) / CELL))
