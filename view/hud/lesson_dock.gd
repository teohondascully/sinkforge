class_name LessonDock
extends RefCounted

## THE LESSON DOCK (D0413, the new-player review's rank 6 and V70): the active hint as a plate at ONE
## place on the screen, the lower left above the hotbar band, never on the body. Legacy's bubble (D0370,
## `hud.gd`'s `hint_box`/`hint_tail`/`hint_rect`) hung over the miner's head with a tail, lifting only
## for the rope's pivots -- and the first lesson a stranger meets, GRAPPLE, told them to throw a line at
## the rock above while covering that rock. The zone round the miner is where every verb lands: the aim
## ring, the mining reach, the grapple's throw, the rung's target ring. Text has no business there.
##
## So the text docks. The dock's rect depends on the lesson and the font and nothing else -- not the body,
## not the zoom, not the camera -- and `tests/test_lesson_dock.gd` pins that it stays clear of the action
## area round a centred miner at the closest zoom under the largest lead the camera can hold while a
## lesson is visible (the busy rule hides lessons above 1.25x a run). What remains near the body is the
## SHORT pointer: the rung's ring (`TargetGuide`) and the aim marks, which point and do not read.
##
## The dock owns the `Hints` and steps them from the frame; the ceremony is the arrival plate's
## `on_screen`, consulted the way the inspector does. Elevation, not an outline: a drop shadow and a left
## rule in `UI_EDGE_HI`; the plate rises a few px as it fades in so the eye catches the arrival.

const FS: int = 8
const WRAP: float = 150.0               ## authored px; the pin in the suite bounds it against the action area
const MARGIN_X: float = 10.0            ## the legend's and the depth chip's left margin
const BAND_GAP: float = 8.0             ## above the hotbar band
const RISE: float = 4.0                 ## authored px the plate rises over its fade-in
const INK := Color(0.92, 0.88, 0.74)
## THE REFUSAL SLOT (D0488, D0496): a one-line plate in the dock's place that says the live refusal's
## headline -- TOO FAR, NOTHING THERE, THAT IS A MACHINE for an aim, NO MACHINE HERE and WRONG STACK for a drop --
## on every refused press, for the short linger `Refusals` keeps, above the lesson plate when one is up.
## Its rule is the refusal's red, the slashed square's own, so the word and the mark read as one answer.
const SLOT_GAP: float = 4.0             ## authored px between the slot and the lesson plate under it

var hints: Hints = Hints.new()
var _plate: ArrivalPlate = null
var _last_time: float = 0.0


## `p_hints` lets the stack share the lessons with a world painter that waits on one (the rope painter's
## landing ring waits on the grapple being known, D0424); a bare dock owns its own.
func _init(plate: ArrivalPlate = null, p_hints: Hints = null) -> void:
	_plate = plate
	if p_hints != null:
		hints = p_hints


static func box(font: Font, text: String) -> Vector2:
	var ts: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, UiTheme.px(WRAP), UiTheme.pt(FS))
	return Vector2(minf(ts.x, UiTheme.px(WRAP)) + UiTheme.px(16.0), ts.y + UiTheme.px(11.0))


## The rect the dock fills for this text: left margin, bottom edge a gap above the hotbar band.
static func dock_rect(font: Font, text: String) -> Rect2:
	var b: Vector2 = box(font, text)
	return Rect2(Vector2(UiTheme.px(MARGIN_X), UiTheme.px(Hotbar.HOTBAR_BAND_TOP - BAND_GAP) - b.y), b)


## Everything the dock decides: `{}` for no lesson and no refusal; the lesson's `rect`/`text`/`alpha`/
## `text_at` when one is up; a `slot` dictionary of the same keys when a refusal is live (D0488).
static func layout(h: Hints, frame: Frame, font: Font) -> Dictionary:
	if h == null or frame == null or frame.obs == null or font == null:
		return {}
	var out: Dictionary = {}
	var text: String = BindingLabels.fill(h.active_text())   # the verb's CURRENT key, never its name (D0411)
	var a: float = h.active_alpha()
	var foot: float = UiTheme.px(Hotbar.HOTBAR_BAND_TOP - BAND_GAP)   # where the slot's foot goes: the dock's, or over the lesson
	if text != "" and a > 0.01:
		var rect: Rect2 = dock_rect(font, text)
		rect.position.y += UiTheme.px(RISE) * (1.0 - a)
		out = {"rect": rect, "text": text, "alpha": a, "text_at": rect.position + Vector2(UiTheme.px(8.0), UiTheme.px(13.0))}
		foot = dock_rect(font, text).position.y - UiTheme.px(SLOT_GAP)
	var word: String = h.slot_text()
	var sa: float = h.slot_alpha()
	if word != "" and sa > 0.01:
		var srect: Rect2 = slot_rect(font, word, foot)
		out["slot"] = {"rect": srect, "text": word, "alpha": sa, "text_at": srect.position + Vector2(UiTheme.px(8.0), UiTheme.px(13.0))}
	return out


## The slot's rect for `word`, its foot at `foot` (the dock's foot, or a gap above the lesson plate).
static func slot_rect(font: Font, word: String, foot: float) -> Rect2:
	var b: Vector2 = box(font, word)
	return Rect2(Vector2(UiTheme.px(MARGIN_X), foot - b.y), b)


func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	var dt: float = clampf(frame.anim_time - _last_time, 0.0, 0.1)
	_last_time = frame.anim_time
	hints.observe(frame.obs, dt, _plate != null and _plate.on_screen(frame))
	var font: Font = ThemeDB.fallback_font
	var l: Dictionary = layout(hints, frame, font)
	if l.has("rect"):
		_plate_draw(ci, font, l, UiTheme.UI_EDGE_HI)
	if l.has("slot"):
		_plate_draw(ci, font, l["slot"], MarkPainter.REFUSE)


## One plate: shadow, ground, the left rule in `rule`, the text.
static func _plate_draw(ci: CanvasItem, font: Font, l: Dictionary, rule: Color) -> void:
	var rect: Rect2 = l["rect"]
	var a: float = l["alpha"]
	PageDraw.round_rect(ci, Rect2(rect.position + Vector2(0.0, UiTheme.px(1.5)), rect.size), UiTheme.px(4.0), Color(0.0, 0.0, 0.0, 0.38 * a))
	PageDraw.round_rect(ci, rect, UiTheme.px(4.0), Color(UiTheme.UI_BG.r, UiTheme.UI_BG.g, UiTheme.UI_BG.b, UiTheme.UI_BG.a * a))
	ci.draw_rect(Rect2(rect.position + Vector2(0.0, UiTheme.px(3.0)), Vector2(UiTheme.px(1.5), rect.size.y - UiTheme.px(6.0))), Color(rule.r, rule.g, rule.b, a))
	ci.draw_multiline_string(font, l["text_at"], l["text"], HORIZONTAL_ALIGNMENT_LEFT, UiTheme.px(WRAP), UiTheme.pt(FS), -1, Color(INK, a))
