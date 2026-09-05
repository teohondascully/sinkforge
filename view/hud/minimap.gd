class_name Minimap
extends RefCounted

## THE MINIMAP (A' step 6i, D0371): the whole world in a corner box, or centred and large. Legacy
## `hud.gd`'s `minimap_frame`, `_fit`, `_draw_minimap` and `_rebuild_minimap` on the layout/paint split,
## with the plan's own correction: legacy keyed its cached terrain image on `sim.solid.size()`, a count
## without membership, and this keys it on the grid's `coarse_version`, which bumps only when a class
## changes. The image is one pixel per LOGIC cell off the observation's coarse plane: rock in its band's
## colour, ore a bright fleck, a dug cell with a wall behind it a dim backing, open sky void. Over it go
## the live overlays this build can answer: your machines, the visible window, and you.
##
## `shown` and `large` are properties the shell flips (legacy's M); the corner form is the default.
## Legacy's aquifer, power, torch, bazaar, breach and ping overlays are not here: the first three need
## whole-world planes the observation does not carry, the rest are dead.
##
## ORE IS MARKED ONLY WHERE SEEN (D0392, then D0400). With Stonereach's ore rate an ore-centred metre cell
## is common enough that legacy's gold fleck painted half the deep gold (VISUAL_QUEUE v2 V09), and a map
## that shows every ore cell for free is the survey upgrade `docs/GDD.md` §5 sells ("ore ping, strata
## map") given away at boot -- and the Reveal layer's question ("what's behind this wall", §12) answered
## before it is asked. The director's ruling (T015): ore the player has already been near shows, ore they
## have not paints as the rock it sits in. `Observation.map_seen` is that memory (`SeenPlane`).

const MINI_W: float = 150.0
const MINI_H: float = 116.0
const MINI_TOP: float = 34.0
const MARGIN_RIGHT: float = 12.0
const LARGE_BOX := Vector2(360.0, 272.0)
const VOID_COLOR := Color(0.05, 0.06, 0.09)
const ROCK_DARKEN: float = 0.35     ## the band colour is authored for lit rock; a chart of it reads darker
const WALL_DARKEN: float = 0.62
const LARGE_DIM := Color(0.02, 0.02, 0.04, 0.55)   ## the world defocused behind the large form
const ORE_COLOR := Color(0.95, 0.80, 0.40)
const SEEN_ORE_DARKEN: float = 0.30   ## a seen ore cell on the map: the ore family's colour, toned to the chart
const MAP_DESATURATE: float = 0.55    ## how far the ladder's band colours pull toward grey on the chart
const YOU_COLOR := Color(0.97, 0.86, 0.36)
const VIEW_COLOR := Color(1.0, 1.0, 1.0, 0.55)

var shown: bool = true
var large: bool = false
var rebuilds: int = 0
var _tex: ImageTexture = null
var _tex_version: int = -1
var _tex_seen_version: int = -1
var _tex_cells: Vector2i = Vector2i.ZERO


## The largest rect with `aspect`'s proportions that fits inside `box`.
static func fit(aspect: Vector2, box: Vector2) -> Vector2:
	if aspect.x <= 0.0 or aspect.y <= 0.0:
		return Vector2.ZERO
	return aspect * minf(box.x / aspect.x, box.y / aspect.y)


## Where the map sits, in canvas px: corner and small, or large and centred. Both forms fit the
## world's aspect inside a box rather than deriving one side from the other -- a corner element has a
## height budget as much as a width one.
static func frame_rect(map_cells: Vector2i, is_large: bool) -> Rect2:
	var world := Vector2(float(map_cells.x), float(map_cells.y))
	if is_large:
		var big: Vector2 = fit(world, LARGE_BOX * UiTheme.UI_SCALE)
		return Rect2((UiTheme.CANVAS - big) * 0.5, big)
	var small: Vector2 = fit(world, Vector2(UiTheme.px(MINI_W), UiTheme.px(MINI_H)))
	return Rect2(Vector2(UiTheme.CANVAS.x - small.x - UiTheme.px(MARGIN_RIGHT), UiTheme.px(MINI_TOP)), small)


## The colour of one coarse class at one logic row, off the palette's band ladder. ORE PAINTS ONLY WHEN
## SEEN (D0400, the director's T015 ruling): a cell the player has been near shows its ore in the ore
## family's colour, toned to the map; one they have not is the rock it sits in, so the map rewards memory
## and leaves the reason to explore where it was.
static func class_color(cls: int, logic_row: int, look: MaterialLook, seen: bool = false) -> Color:
	var n: int = Interface.Observation.LOGIC_PX / Interface.Observation.CELL_PX
	var band: Color = look.band_color(logic_row * n + n / 2) if look != null else Color(0.4, 0.4, 0.45)
	# The ladder's colours are the chip's announcement colours, saturated for type; on a chart they shout
	# (D0400: the re-placed ladder put the seal's violet on a third of the map). Pulled most of the way
	# to their own grey, so the bands still read as bands and the map reads as a map.
	var grey: float = band.get_luminance()
	band = band.lerp(Color(grey, grey, grey), MAP_DESATURATE)
	match cls:
		Interface.Observation.MAP_ORE:
			return ORE_COLOR.darkened(SEEN_ORE_DARKEN) if seen else band.darkened(ROCK_DARKEN)
		Interface.Observation.MAP_ROCK: return band.darkened(ROCK_DARKEN)
		Interface.Observation.MAP_WALL: return band.darkened(WALL_DARKEN)
	return VOID_COLOR


## The terrain image, one pixel per logic cell. Rebuilt only when the version or the size moved.
func ensure_texture(o: Interface.Observation, look: MaterialLook) -> ImageTexture:
	if o.map_cells.x <= 0 or o.map_cells.y <= 0 or o.map.size() < o.map_cells.x * o.map_cells.y:
		return null
	if _tex != null and _tex_version == o.map_version and _tex_seen_version == o.map_seen_version and _tex_cells == o.map_cells:
		return _tex
	var img := Image.create(o.map_cells.x, o.map_cells.y, false, Image.FORMAT_RGBA8)
	var has_seen: bool = o.map_seen.size() >= o.map_cells.x * o.map_cells.y
	for y: int in o.map_cells.y:
		for x: int in o.map_cells.x:
			var i: int = y * o.map_cells.x + x
			img.set_pixel(x, y, class_color(o.map[i], y, look, has_seen and o.map_seen[i] != 0))
	_tex = ImageTexture.create_from_image(img)
	_tex_version = o.map_version
	_tex_seen_version = o.map_seen_version
	_tex_cells = o.map_cells
	rebuilds += 1
	return _tex


## Everything the map decides, in canvas px; `{}` when hidden or the world has no map.
func layout(frame: Frame) -> Dictionary:
	if not shown or frame == null or frame.obs == null:
		return {}
	var o: Interface.Observation = frame.obs
	if o.map_cells.x <= 0 or o.map_cells.y <= 0:
		return {}
	var rect: Rect2 = frame_rect(o.map_cells, large)
	var scale := Vector2(rect.size.x / float(o.map_cells.x), rect.size.y / float(o.map_cells.y))
	var px_per_logic: float = float(Interface.Observation.LOGIC_PX)
	var body := Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE) / px_per_logic
	var view: Rect2 = frame.view_world_rect
	var view_rect := Rect2(rect.position + view.position / px_per_logic * scale, view.size / px_per_logic * scale)
	var dots: Array[Vector2] = []
	for cell: Vector2i in o.map_machines:
		dots.append(rect.position + Vector2(cell) * scale)
	return {"rect": rect, "scale": scale, "you": rect.position + body * scale,
		"view": view_rect.intersection(rect) if view.size.x > 0.0 else Rect2(), "dots": dots,
		"dot": Vector2(maxf(scale.x, 2.0), maxf(scale.y, 2.0)), "large": large}


func paint(frame: Frame, ci: CanvasItem) -> void:
	var l: Dictionary = layout(frame)
	if l.is_empty():
		return
	var rect: Rect2 = l["rect"]
	# The large form is a modal: above every other chip, the world dimmed behind it.
	ci.z_index = 1 if bool(l["large"]) else 0
	if bool(l["large"]):
		ci.draw_rect(Rect2(Vector2.ZERO, UiTheme.CANVAS), LARGE_DIM)
	UiTheme.panel(ci, rect.grow(UiTheme.px(3.0)))
	var tex: ImageTexture = ensure_texture(frame.obs, frame.look)
	if tex != null:
		ci.draw_texture_rect(tex, rect, false)
	for d: Vector2 in l["dots"]:
		ci.draw_rect(Rect2(d, l["dot"]), UiTheme.UI_ACCENT)
	var view: Rect2 = l["view"]
	if view.size.x > 0.0:
		ci.draw_rect(view, VIEW_COLOR, false, 1.0)
	var you: Vector2 = l["you"]
	var half: float = UiTheme.px(2.5)
	ci.draw_rect(Rect2(you - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), YOU_COLOR)
	ci.draw_rect(Rect2(you - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), Color(0.10, 0.08, 0.0), false, 1.0)
