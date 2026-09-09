class_name Minimap
extends RefCounted

## THE MINIMAP (A' step 6i, D0371): a local chart in a corner box, or a tall window centred and large. Legacy
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

const MINI_W: float = 128.0   ## D0430: 150 x 116 held a sliver; a chart that fills its box is trimmed to 4:3
const MINI_H: float = 96.0
## THE CORNER FORM IS A LOCAL CHART (D0430, Astra's rank 9, V34). Legacy fitted the WHOLE world into the
## corner box; on a 64 m by 300 m shaft world that is a 24 px sliver, "a colour bar" (V34), and every
## stranger's frames show it unread. The corner now shows a window: up to CORNER_SPAN_M metres of the
## world's width at the box's full width, and as many metres of height as the box holds at that scale
## (about 50 m at 64 m wide), centred on the body and clamped to the world's edges, so it scrolls with the
## descent. The large form (the map key) is still the whole world.
const CORNER_SPAN_M: float = 64.0
const MINI_TOP: float = 34.0
const MARGIN_RIGHT: float = 12.0
## THE LARGE FORM IS A TALL WINDOW, NOT THE WHOLE WORLD (D0441; D0430 made the corner a local chart and left
## the large form a 64 x 276 m sliver 63 px wide). This game is vertical: the large map shows the world's
## width by LARGE_BOX's aspect -- 64 m by about 106 m -- centred on the body and clamped to the world, at
## six pixels a metre (the box is authored at UI_SCALE, 400 x 660 px on the 720 px canvas), so a shaft, a
## cave and the machines in them read as shapes.
const LARGE_BOX := Vector2(200.0, 330.0)
const LARGE_SPAN_M: float = 64.0
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
var _img: Image = null   ## the image behind `_tex`, kept so a step of seeing updates it in place
var _tex_cells: Vector2i = Vector2i.ZERO
## THE CLASS AND MEMORY BYTES THE IMAGE WAS PAINTED FROM, so a terrain change can repaint the cells that
## actually changed instead of all seventeen thousand. Both are `PackedByteArray` and both are
## copy-on-write, so holding them costs nothing until the world writes to one.
var _drawn_map: PackedByteArray = PackedByteArray()
var _drawn_seen: PackedByteArray = PackedByteArray()
## Cells repainted by the last patch, for a test to read the work rather than infer it from a timing.
var patched: int = 0


## The largest rect with `aspect`'s proportions that fits inside `box`.
static func fit(aspect: Vector2, box: Vector2) -> Vector2:
	if aspect.x <= 0.0 or aspect.y <= 0.0:
		return Vector2.ZERO
	return aspect * minf(box.x / aspect.x, box.y / aspect.y)


## Where the map sits, in canvas px: corner and small, or large and centred. Both forms fit the
## world's aspect inside a box rather than deriving one side from the other -- a corner element has a
## height budget as much as a width one.
static func frame_rect(map_cells: Vector2i, is_large: bool) -> Rect2:
	if is_large:
		var big: Vector2 = fit(large_window(map_cells, Vector2.ZERO).size, LARGE_BOX * UiTheme.UI_SCALE)
		return Rect2((UiTheme.CANVAS - big) * 0.5, big)
	var small: Vector2 = fit(corner_window(map_cells, Vector2.ZERO).size, Vector2(UiTheme.px(MINI_W), UiTheme.px(MINI_H)))
	return Rect2(Vector2(UiTheme.CANVAS.x - small.x - UiTheme.px(MARGIN_RIGHT), UiTheme.px(MINI_TOP)), small)


## The corner's window over the world, in logic cells: the lesser of the world's width and CORNER_SPAN_M
## wide, the box's height's worth at that scale tall (never more than the world), centred on `body`
## (logic cells) and clamped inside the world.
static func corner_window(map_cells: Vector2i, body: Vector2) -> Rect2:
	return window_of(map_cells, body, CORNER_SPAN_M, Vector2(MINI_W, MINI_H))


## The large form's window: LARGE_SPAN_M wide by LARGE_BOX's aspect, centred and clamped the same way.
static func large_window(map_cells: Vector2i, body: Vector2) -> Rect2:
	return window_of(map_cells, body, LARGE_SPAN_M, LARGE_BOX)


static func window_of(map_cells: Vector2i, body: Vector2, span_m: float, box: Vector2) -> Rect2:
	var world := Vector2(float(map_cells.x), float(map_cells.y))
	var w: float = minf(world.x, span_m)
	var h: float = minf(world.y, w * box.y / box.x)
	var origin := Vector2(clampf(body.x - w * 0.5, 0.0, world.x - w), clampf(body.y - h * 0.5, 0.0, world.y - h))
	return Rect2(origin, Vector2(w, h))


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
	var has_seen: bool = o.map_seen.size() >= o.map_cells.x * o.map_cells.y
	# ONE STEP OF SEEING IS AN UPDATE IN PLACE (D0403): the terrain unchanged and the memory one version on
	# from the image's, so only the cells that version turned are repainted -- a few dozen, not 17K. Any
	# other change (the terrain, a skipped version, a restore) rebuilds.
	if _tex != null and _img != null and _tex_version == o.map_version and _tex_cells == o.map_cells and _tex_seen_version == o.map_seen_version - 1 and not o.map_seen_recent.is_empty():
		for i: int in o.map_seen_recent:
			if o.map[i] == Interface.Observation.MAP_ORE:
				_img.set_pixel(i % o.map_cells.x, i / o.map_cells.x, class_color(o.map[i], i / o.map_cells.x, look, true))
		_tex.update(_img)
		_stamp(o)
		return _tex
	# THE TERRAIN MOVED. Repaint the cells that differ, not the world: a full rebuild walks every logic
	# cell calling `class_color` and `set_pixel`, and measured 36.5-38.1 ms in a 1280x720 seat -- thirteen
	# times the whole 2.78 ms frame budget, in one HUD chip, on nineteen of the twenty slow frames of a
	# 1500-tick mining run (2026-09-08). It fired every twenty to sixty ticks while digging, because a
	# dig is exactly what moves `map_version`, so the chip was at its most expensive precisely while the
	# player was doing the thing the director said felt like a freeze. The bytes the image was painted
	# from are kept above, so the diff is a byte compare over the map, and a dig changes a handful of
	# cells. Same pixels by construction: the changed cells go through the same `class_color`.
	if _can_patch(o):
		return _patch(o, look, has_seen)
	_img = Image.create(o.map_cells.x, o.map_cells.y, false, Image.FORMAT_RGBA8)
	for y: int in o.map_cells.y:
		for x: int in o.map_cells.x:
			var i: int = y * o.map_cells.x + x
			_img.set_pixel(x, y, class_color(o.map[i], y, look, has_seen and o.map_seen[i] != 0))
	_tex = ImageTexture.create_from_image(_img)
	_stamp(o)
	rebuilds += 1
	return _tex


## Is there an image on screen that the same world painted, at the same size? Then the difference between
## it and this observation is a set of cells, and that set is what has to be repainted.
func _can_patch(o: Interface.Observation) -> bool:
	return (_tex != null and _img != null and _tex_cells == o.map_cells
		and _drawn_map.size() == o.map.size() and _drawn_seen.size() == o.map_seen.size()
		# A world with no memory plane carries an EMPTY `map_seen`, not a zeroed one, and indexing it per
		# cell is a crash rather than a wrong colour. The full rebuild reads it through `has_seen` for
		# exactly this reason; the patch has to honour the same guard.
		and (o.map_seen.is_empty() or o.map_seen.size() == o.map.size()))


## Repaint exactly the cells whose class byte or memory byte differs from what the image holds.
func _patch(o: Interface.Observation, look: MaterialLook, has_seen: bool) -> ImageTexture:
	patched = 0
	var w: int = o.map_cells.x
	for i: int in o.map.size():
		var now_seen: int = o.map_seen[i] if has_seen else 0
		if o.map[i] == _drawn_map[i] and now_seen == (_drawn_seen[i] if has_seen else 0):
			continue
		_img.set_pixel(i % w, i / w, class_color(o.map[i], i / w, look, now_seen != 0))
		patched += 1
	if patched > 0:
		_tex.update(_img)
	_stamp(o)
	return _tex


## What the image now holds, recorded so the next call can diff against it.
func _stamp(o: Interface.Observation) -> void:
	_tex_version = o.map_version
	_tex_seen_version = o.map_seen_version
	_tex_cells = o.map_cells
	# DUPLICATED, NOT ALIASED. `o.map` is the world's own coarse plane handed straight out, so holding the
	# reference holds a window onto whatever the world does next: the diff then compares the array with
	# itself and finds nothing changed, for ever. The suite caught it -- one changed byte repainted zero
	# cells -- and it would have shipped as a minimap that stops updating the moment you mine.
	_drawn_map = o.map.duplicate()
	_drawn_seen = o.map_seen.duplicate()


## Everything the map decides, in canvas px; `{}` when hidden or the world has no map.
func layout(frame: Frame) -> Dictionary:
	if not shown or frame == null or frame.obs == null:
		return {}
	var o: Interface.Observation = frame.obs
	if o.map_cells.x <= 0 or o.map_cells.y <= 0:
		return {}
	var rect: Rect2 = frame_rect(o.map_cells, large)
	var px_per_logic: float = float(Interface.Observation.LOGIC_PX)
	var body := Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE) / px_per_logic
	var window: Rect2 = large_window(o.map_cells, body) if large else corner_window(o.map_cells, body)
	var scale := Vector2(rect.size.x / window.size.x, rect.size.y / window.size.y)
	var view: Rect2 = frame.view_world_rect
	var view_rect := Rect2(rect.position + (view.position / px_per_logic - window.position) * scale, view.size / px_per_logic * scale)
	var dots: Array[Vector2] = []
	for cell: Vector2i in o.map_machines:
		if window.has_point(Vector2(cell) + Vector2(0.5, 0.5)):
			dots.append(rect.position + (Vector2(cell) - window.position) * scale)
	return {"rect": rect, "scale": scale, "window": window, "you": rect.position + (body - window.position) * scale,
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
		ci.draw_texture_rect_region(tex, rect, l["window"])   # one texel per logic cell: the window IS the region
	for d: Vector2 in l["dots"]:
		ci.draw_rect(Rect2(d, l["dot"]), UiTheme.UI_ACCENT)
	var view: Rect2 = l["view"]
	if view.size.x > 0.0:
		ci.draw_rect(view, VIEW_COLOR, false, 1.0)
	var you: Vector2 = l["you"]
	var half: float = UiTheme.px(2.5)
	ci.draw_rect(Rect2(you - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), YOU_COLOR)
	ci.draw_rect(Rect2(you - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), Color(0.10, 0.08, 0.0), false, 1.0)
