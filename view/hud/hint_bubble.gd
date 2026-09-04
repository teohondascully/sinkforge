class_name HintBubble
extends RefCounted

## THE LESSON BUBBLE (A' step 6h (ii), D0370): the active hint as a plate near the body with a tail
## reaching toward it. Legacy `hud.gd`'s `hint_box`, `hint_tail`, `hint_rect` and `_draw_hint_bubble`,
## with the placement rule legacy wrote down: the bubble sits above its anchor unless that would put it
## under the objective line, then it flips below; and it LIFTS until the plate clears what the lesson
## is about (the rope's pivots), only upward, clamped. The chip owns the `Hints` and steps them from the
## frame; the ceremony is the arrival plate's `on_screen`, consulted the way the inspector does.
##
## Elevation, not an outline: a soft drop shadow puts the plate above the world, the rule shrinks to a
## left edge in `UI_EDGE_HI` (a hint is a thing to read, not a thing to press). The anchor is just over
## the body's head in world px, mapped through the frame's view rect onto the canvas.

const FS: int = 8
const WRAP: float = 176.0
const TAIL_REACH: float = 10.0
const HEAD_CLEAR: float = 6.0            ## world px above the body's top the tail points at
const TOP_FLIP: float = 38.0             ## above this the bubble flips below its anchor (the banner's band)
const INK := Color(0.92, 0.88, 0.74)

var hints: Hints = Hints.new()
var _plate: ArrivalPlate = null
var _last_time: float = 0.0


func _init(plate: ArrivalPlate = null) -> void:
	_plate = plate


## A world point on the HUD canvas, through the frame's view rect: the canvas is the viewport.
static func world_to_canvas(frame: Frame, world: Vector2) -> Vector2:
	var r: Rect2 = frame.view_world_rect
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return Vector2(-1000.0, -1000.0)
	return Vector2((world.x - r.position.x) * UiTheme.CANVAS.x / r.size.x, (world.y - r.position.y) * UiTheme.CANVAS.y / r.size.y)


static func hint_box(font: Font, text: String) -> Vector2:
	var ts: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, UiTheme.px(WRAP), UiTheme.pt(FS))
	return Vector2(minf(ts.x, UiTheme.px(WRAP)) + UiTheme.px(16.0), ts.y + UiTheme.px(11.0))


## The canvas point the tail reaches toward: the anchor clamped into the band a bubble may point at.
static func hint_tail(anchor: Vector2) -> Vector2:
	return Vector2(clampf(anchor.x, UiTheme.px(8.0), UiTheme.CANVAS.x - UiTheme.px(8.0)),
		clampf(anchor.y, UiTheme.px(60.0), UiTheme.px(Hotbar.HOTBAR_BAND_TOP - 6.0)))


## The rect the bubble fills. `avoid` has no default on purpose: two call sites, and both move together.
static func hint_rect(font: Font, text: String, anchor: Vector2, avoid: Array[Vector2]) -> Rect2:
	var box: Vector2 = hint_box(font, text)
	var tail: Vector2 = hint_tail(anchor)
	var origin := Vector2(clampf(tail.x - box.x * 0.5, UiTheme.px(6.0), UiTheme.CANVAS.x - box.x - UiTheme.px(6.0)), tail.y - UiTheme.px(7.0) - box.y)
	if origin.y < UiTheme.px(TOP_FLIP):
		origin.y = tail.y + UiTheme.px(7.0)
		return Rect2(origin, box)
	var lift: float = 0.0
	for pt: Vector2 in avoid:
		if pt.x < origin.x or pt.x > origin.x + box.x or pt.y < origin.y or pt.y > origin.y + box.y:
			continue
		lift = maxf(lift, origin.y + box.y - pt.y + 1.0)
	if lift > 0.0:
		origin.y = maxf(UiTheme.px(TOP_FLIP), origin.y - lift)
	return Rect2(origin, box)


## Everything the bubble decides: `{}` for no bubble.
static func layout(h: Hints, frame: Frame, font: Font) -> Dictionary:
	if h == null or frame == null or frame.obs == null or font == null:
		return {}
	var text: String = h.active_text()
	var a: float = h.active_alpha()
	if text == "" or a <= 0.01:
		return {}
	var o: Interface.Observation = frame.obs
	var head := Vector2(float(o.pos_x), float(o.top_y)) / float(Fx.SCALE) + Vector2(0.0, -HEAD_CLEAR)
	var anchor: Vector2 = world_to_canvas(frame, head)
	var avoid: Array[Vector2] = []
	for pv: Vector2i in o.grapple_pivots:
		avoid.append(world_to_canvas(frame, VoiceCues.px(pv)))
	var rect: Rect2 = hint_rect(font, text, anchor, avoid)
	var tail: Vector2 = hint_tail(anchor)
	var above: bool = rect.position.y < tail.y
	var tip_y: float = minf(tail.y, rect.end.y + UiTheme.px(TAIL_REACH)) if above else rect.position.y - 1.0
	var base_y: float = rect.end.y if above else rect.position.y
	var tx: float = clampf(tail.x, rect.position.x + UiTheme.px(10.0), rect.end.x - UiTheme.px(10.0))
	return {"rect": rect, "text": text, "alpha": a, "anchor": anchor, "above": above,
		"tail": PackedVector2Array([Vector2(tx - UiTheme.px(3.5), base_y), Vector2(tx + UiTheme.px(3.5), base_y), Vector2(tx, tip_y)]),
		"text_at": rect.position + Vector2(UiTheme.px(8.0), UiTheme.px(13.0))}


static func _round_rect(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.draw(ci.get_canvas_item(), rect)


func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var dt: float = clampf(frame.anim_time - _last_time, 0.0, 0.1)
	_last_time = frame.anim_time
	hints.observe(frame.obs, dt, _plate != null and _plate.on_screen(frame))
	var font: Font = ThemeDB.fallback_font
	var l: Dictionary = layout(hints, frame, font)
	if l.is_empty():
		return
	var rect: Rect2 = l["rect"]
	var a: float = l["alpha"]
	_round_rect(ci, Rect2(rect.position + Vector2(0.0, UiTheme.px(1.5)), rect.size), UiTheme.px(4.0), Color(0.0, 0.0, 0.0, 0.38 * a))
	_round_rect(ci, rect, UiTheme.px(4.0), Color(UiTheme.UI_BG.r, UiTheme.UI_BG.g, UiTheme.UI_BG.b, UiTheme.UI_BG.a * a))
	ci.draw_rect(Rect2(rect.position + Vector2(0.0, UiTheme.px(3.0)), Vector2(UiTheme.px(1.5), rect.size.y - UiTheme.px(6.0))), Color(UiTheme.UI_EDGE_HI.r, UiTheme.UI_EDGE_HI.g, UiTheme.UI_EDGE_HI.b, a))
	ci.draw_colored_polygon(l["tail"], Color(UiTheme.UI_BG.r, UiTheme.UI_BG.g, UiTheme.UI_BG.b, UiTheme.UI_BG.a * a))
	ci.draw_multiline_string(font, l["text_at"], l["text"], HORIZONTAL_ALIGNMENT_LEFT, UiTheme.px(WRAP), UiTheme.pt(FS), -1, Color(INK, a))
