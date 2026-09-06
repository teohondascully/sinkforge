class_name WaterPainter
extends RefCounted

## HOW WATER LOOKS (A' step 6a, D0362): its surface line, its depth shading, its ripples and caustics,
## the meniscus where it meets rock. Legacy `scenes/water_view.gd`'s `_draw_water`, `_water_surface_y`
## and `_water_depth` lifted onto the `Frame` contract; the drips are `view/fx/water_drips.gd` (they
## spawn particles, which is state the painter must not own) and the fill tells are not ported, because
## `fill` has no subject in this build (3b deferred it with reasons).
##
## Each watered cell holds an integer level 1..WATER_MAX and draws a translucent blue fill whose height
## is level/WATER_MAX of the cell, anchored at the cell's bottom, so a partially-full cell reads a low
## water line and a settled pool reads a flat surface. Translucent, so the rock behind shows through --
## that rock is where a body of water gets most of its visible structure. Read each frame off the
## observation's `wet_cells`, never cached: water flows every tick and the sim is authoritative.
##
## UNITS. The cell is 4 px here against legacy's 32, and every length below is a WORLD texture -- a ripple
## wavelength, a caustic band, the depth the gradient runs out over -- so each converts at ×0.5 in pixels
## (metres conserved; `PORT_ORDER.md`'s regime), and the depth's 7 legacy cells are 28 of ours. Legacy
## sampled its waterline every 16 px against a 46 px ripple and documented the fold; sampled every 2 px
## here, 23 px means 23.

const CELL: float = float(Interface.Observation.CELL_PX)
const WATER_MAX: int = Interface.Observation.WATER_MAX
const WATER_COLOR := Color(0.16, 0.42, 0.72)          ## deep cool blue: reads as water, stays see-through
const WATER_DEEP := Color(0.03, 0.13, 0.46)           ## the colour the body tends toward with depth
const WATER_SURFACE := Color(0.42, 0.72, 0.95)        ## a brighter waterline so the top edge reads
const WATER_ALPHA: float = 0.58                       ## translucent (mid of the 0.5-0.65 window)
## Deliberately short of opaque: depth is carried by colour rather than density, because at 0.80 the body
## measured 60% featureless and the rock showing through is what fixes that, not more caustics.
const WATER_ALPHA_DEEP: float = 0.66
const WATER_DEPTH_CELLS: int = 28                     ## legacy 7 cells of 32 px: 7 m
const WATER_RIPPLE_AMP: float = 0.75                  ## legacy 1.5 px
const WATER_FILM: float = 0.125                       ## the least height a wet cell's fill keeps above its floor (D0408)
const WATER_RIPPLE_LEN: float = 23.0                  ## legacy 46 px between crests
const WATER_RIPPLE_SPEED: float = 1.7                 ## crests per second
const WATER_MENISCUS: float = 1.5                     ## legacy 3 px of soft edge under the bright line
const WATER_LINE: float = 1.0                         ## the skin line, a world pixel (was 0.75: a hairline the veil ate; D0403, V08)
const WATER_LINE_ALPHA: float = 0.95                  ## ...and nearly opaque, so the surface reads in the dark
const WATER_CAUSTIC_LEN: float = 39.0                 ## legacy 78 px between caustic bands
const WATER_CAUSTIC_SPEED: float = 0.55
const WATER_CAUSTIC: float = 0.15                     ## how much a band lifts the fill
## A second set crossing the first the other way: two bands at different scales drifting in opposite
## directions interfere, and interference is what light on moving water looks like.
const WATER_CAUSTIC_LEN2: float = 14.5                ## legacy 29 px
const WATER_CAUSTIC_SPEED2: float = -0.9
const WATER_CAUSTIC2: float = 0.09


static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null or frame.obs.wet_cells.is_empty():
		return
	var view: Rect2 = frame.view_world_rect.grow(2.0 * CELL)
	for c: Vector2i in frame.obs.wet_cells:
		if not view.has_point(Vector2(c) * CELL):
			continue
		var shape: Dictionary = cell_shape(frame.obs, c, frame.anim_time)
		if shape.is_empty():
			continue
		ci.draw_colored_polygon(shape["fill"], shape["color"])
		if shape["open_above"]:
			ci.draw_colored_polygon(shape["meniscus"], Color(WATER_SURFACE, 0.22))
			ci.draw_colored_polygon(shape["line"], Color(WATER_SURFACE, WATER_LINE_ALPHA))


## The surface y (top of the water) a cell draws for a level, anchored at the cell bottom; level 0 is
## the cell floor.
static func surface_y(cell: Vector2i, level: int) -> float:
	var frac: float = clampf(float(level) / float(WATER_MAX), 0.0, 1.0)
	return float(cell.y) * CELL + CELL * (1.0 - frac)


## How far inside the body this cell sits: 0 at the surface, growing downward, capped where the gradient
## has run out anyway, so a deep aquifer costs no more to draw than a puddle.
static func depth(o: Interface.Observation, c: Vector2i) -> float:
	var d: int = 0
	while d < WATER_DEPTH_CELLS:
		if o.water_at(c - Vector2i(0, d + 1)) <= 0:
			break
		d += 1
	return float(d) / float(WATER_DEPTH_CELLS)


## One cell's geometry and colour, the layout decision a test can fail on: the fill anchored at the
## floor with a three-point top edge (each side averaged with its water neighbour so a level step tapers
## into a ramp; the midpoint this cell's own height, so 23 px means 23), an interior cell drawn to its
## top because the water above rests on it, and only a cell with nothing above it owning a waterline
## that ripples. Empty for a dry cell.
static func cell_shape(o: Interface.Observation, c: Vector2i, t: float) -> Dictionary:
	var level: int = o.water_at(c)
	if level <= 0:
		return {}
	var base := Vector2(c) * CELL
	var floor_y: float = base.y + CELL
	var mid_y: float = surface_y(c, level)
	var left_lvl: int = o.water_at(c + Vector2i(-1, 0))
	var right_lvl: int = o.water_at(c + Vector2i(1, 0))
	var left_y: float = 0.5 * (mid_y + surface_y(c + Vector2i(-1, 0), left_lvl)) if left_lvl > 0 else mid_y
	var right_y: float = 0.5 * (mid_y + surface_y(c + Vector2i(1, 0), right_lvl)) if right_lvl > 0 else mid_y
	var open_above: bool = o.water_at(c - Vector2i(0, 1)) <= 0
	var mid_top: float = mid_y
	if not open_above:
		left_y = base.y
		right_y = base.y
		mid_top = base.y
	else:
		# A ripple no taller than half the water under it (D0408): a level is half a pixel and the ripple's
		# amplitude three quarters, so a rippled film's top edge crossed its own floor and the fill was a
		# bow-tie -- `draw_colored_polygon` refused it, 249 times in three seconds at a 206 m pool.
		var amp: float = clampf((floor_y - mid_y) / (2.0 * WATER_RIPPLE_AMP), 0.0, 1.0)
		left_y = minf(left_y + _ripple(base.x, t) * amp, floor_y - WATER_FILM)
		mid_top = minf(mid_top + _ripple(base.x + CELL * 0.5, t) * amp, floor_y - WATER_FILM)
		right_y = minf(right_y + _ripple(base.x + CELL, t) * amp, floor_y - WATER_FILM)
	var tl := Vector2(base.x, left_y)
	var tm := Vector2(base.x + CELL * 0.5, mid_top)
	var tr := Vector2(base.x + CELL, right_y)
	return {
		"open_above": open_above,
		"color": fill_color(depth(o, c), base, t),
		"fill": PackedVector2Array([tl, tm, tr, Vector2(tr.x, floor_y), Vector2(tl.x, floor_y)]),
		# Both bands hang off the SAME three points as the fill: a band that resampled the surface on its
		# own would drift off the fill it is supposed to cap.
		"meniscus": PackedVector2Array([tl, tm, tr, Vector2(tr.x, right_y + WATER_MENISCUS),
			Vector2(tm.x, mid_top + WATER_MENISCUS), Vector2(tl.x, left_y + WATER_MENISCUS)]),
		"line": PackedVector2Array([tl, tm, tr, Vector2(tr.x, right_y + WATER_LINE),
			Vector2(tm.x, mid_top + WATER_LINE), Vector2(tl.x, left_y + WATER_LINE)]),
	}


static func _ripple(x: float, t: float) -> float:
	return sin(x / WATER_RIPPLE_LEN * TAU + t * WATER_RIPPLE_SPEED * TAU) * WATER_RIPPLE_AMP


## Depth tint toward WATER_DEEP and denser as the body closes over you, and two slow caustic bands so the
## interior is never one dead value.
static func fill_color(depth_frac: float, base: Vector2, t: float) -> Color:
	var body: Color = WATER_COLOR.lerp(WATER_DEEP, depth_frac)
	var alpha: float = lerpf(WATER_ALPHA, WATER_ALPHA_DEEP, depth_frac)
	var caustic: float = 0.5 + 0.5 * sin((base.x + base.y * 0.6) / WATER_CAUSTIC_LEN * TAU - t * WATER_CAUSTIC_SPEED * TAU)
	var caustic2: float = 0.5 + 0.5 * sin((base.x * 0.7 - base.y) / WATER_CAUSTIC_LEN2 * TAU - t * WATER_CAUSTIC_SPEED2 * TAU)
	body = body.lightened((caustic * WATER_CAUSTIC + caustic2 * WATER_CAUSTIC2) * (1.0 - depth_frac * 0.4))
	return Color(body.r, body.g, body.b, alpha)
