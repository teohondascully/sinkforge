class_name ArrivalPlate
extends RefCounted

## THE STRATUM ARRIVAL CEREMONY. Ported from `legacy/scenes/hud.gd:252-323` (`announce`, `announcing`,
## `plate_on_screen`) and `870-940` (`ARRIVAL_*`, `SCRIM_*`, `_draw_arrival`). `docs/LEGACY_GAP.md` T1 #8,
## the other half of the depth readout D0271 landed.
##
## Legacy's own sentence for why it exists: crossing into a new stratum is **"the one moment the descent
## gets to be an event."** `DepthChip` says where you are, continuously and quietly. This says you have
## ARRIVED somewhere, once, and then gets out of the way.
##
## **NO PANEL, DELIBERATELY, and legacy's reasoning is the finding rather than the styling.** Its first
## version was a full-width plate and it read as a modal the player's first instinct was to dismiss. What
## shipped instead: half the type, letters tracked apart so small type reads as engraved, a kicker line
## above, two hairlines only as wide as the words, and a soft field of dusk with no edge to read as a
## shape. `docs/QUALITY.md`'s "menus must read 2026" is the same judgment from the other end.
##
## **THE CONTRAST IS PER GLYPH, NOT PER PLATE, AND THAT IS A MEASUREMENT.** Legacy ran the scrim at 0.80
## until it measured what the veil cost: across the plate a rope moved 26.5 dE of the 41.4 separating it
## from its backing, while the rock behind it moved 6.6 — four times more taken from the thing the player
## is hanging on than from the background it was drawn to suppress. So the words get their contrast from
## a near-black shadow a pixel behind each glyph, and the field veil dropped to 0.28 and became only what
## a compositional weight needs. Ported at 0.28 with the shadow, not at 0.80 without it.
##
## **WHAT IS NOT PORTED, AND WHY THAT IS NOT A SHORTCUT.** Legacy holds a ceremony while the large map is
## open or a grapple line is live — `_announce_held()`, with a long comment about a bug where a lesson
## gated on `announcing()` instead of `plate_on_screen()` waited behind an invisible plate forever. This
## build has no map and no rope, so both conditions are permanently false and the hold is omitted rather
## than stubbed: a branch that can never be true is a branch nobody can test, and it would read as
## supported. The two predicates would also be identical here, which is exactly the collision that caused
## legacy's bug. They come back with T1 #12.
##
## **IT KEEPS STATE**, like `view/visuals/crumble_painter.gd` and for the same reason: an arrival is one
## event and the plate is two hundred frames. Spawning is gated on the BAND CHANGING, not on the draw
## happening, so a resize or a focus change cannot re-fire a ceremony the player already watched.

## EVERY LENGTH AND TYPE SIZE BELOW IS IN LEGACY'S AUTHORING CANVAS (`UiTheme.AUTHORED`, 640x360),
## carried onto ours through `UiTheme.px`/`UiTheme.pt` at the point of use rather than baked in, so
## each value is still the value in the file it was ported from (D0290). The times are seconds and the
## fractions are fractions: neither scales.
const HOLD: float = 3.4          ## legacy ARRIVAL_HOLD: total life, fade included
const SIZE: int = 15             ## legacy ARRIVAL_SIZE, in canvas px
const KICKER_SIZE: int = 9
const TRACK: float = 3.4         ## extra px between letters -- what makes small type read as engraved
const KICKER_TRACK: float = 2.6

## Legacy's fade: fast in, slow out. `t` runs 1 -> 0 over the life, so `(1-t)*6` rises steeply at the
## start and `t*2.4` falls away at the end; the plate takes the smaller.
const FADE_IN_RATE: float = 6.0
const FADE_OUT_RATE: float = 2.4

const RISE_PX: float = 5.0       ## the plate settles upward by this much as it comes in
const CENTRE_Y_FRAC: float = 0.26
const KICKER_DY: float = -15.0
const RULE_ABOVE: float = -25.0
const RULE_BELOW: float = 7.0
const RULE_PAD: float = 12.0     ## the hairlines run this much past the widest word
const RULE_ALPHA: float = 0.40
const KICKER_ALPHA: float = 0.80

## The scrim: a soft ground with no edge. Legacy's numbers, and the shadow that replaced most of its job.
const SCRIM_ALPHA: float = 0.28
const SCRIM_PAD: float = 34.0
const SCRIM_FEATHER: float = 96.0
const SCRIM_ABOVE: float = 32.0
const SCRIM_BELOW: float = 18.0
const SCRIM_INK := Color(0.02, 0.025, 0.04)
const SCRIM_INK_OFF := Vector2(1.0, 1.0)
const SCRIM_INK_A: float = 0.90

## What the kicker says. Legacy varies it per event type; every arrival this build can produce is a
## descent into rock, so there is one string rather than a table with one row in it.
const KICKER: String = "ENTERING"

## Nothing has been announced yet. Not a band row and not -1, which is a real row above the datum.
const NO_BAND: String = ""

var _announced: String = NO_BAND   ## the band whose ceremony has already fired
var _fired_at: float = 0.0
var _text: String = ""
var _tint: Color = Color.WHITE


## Width of a tracked string: the font's own width plus the extra air between letters. Legacy's
## `_tracked_w`. The trailing letter gets no track after it, which is why this is `len - 1`.
static func tracked_width(font: Font, text: String, size: int, track: float) -> float:
	if font == null or text.is_empty():
		return 0.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(size)).x \
		+ UiTheme.px(track) * float(text.length() - 1)


## How far through its life a plate fired at `fired_at` is: 1.0 at the instant it fires, 0.0 when it is
## spent. Legacy's `_arrival_life / ARRIVAL_HOLD`, derived from the clock rather than decremented, for
## the reason D0277 made the clock a counter — a redraw must not advance an animation.
static func remaining(fired_at: float, now: float) -> float:
	return clampf(1.0 - (now - fired_at) / HOLD, 0.0, 1.0)


## The plate's opacity at life `t`. Legacy's `minf((1 - t) * 6, t * 2.4)`: fast in, slow out.
static func alpha_at(t: float) -> float:
	return clampf(minf((1.0 - t) * FADE_IN_RATE, t * FADE_OUT_RATE), 0.0, 1.0)


## Notes the band the body is in, and fires a ceremony if it has changed. Returns true when it fired, so
## a test can tell "the band did not change" from "the guard suppressed it" — the same picture and very
## different bugs, and the same reason `CrumblePainter.note_frame` reports.
##
## The FIRST band seen is recorded without a ceremony. Announcing the band the player spawned in would
## make every session open with a plate saying where they already are.
func note_frame(frame: Frame) -> bool:
	if frame == null or frame.obs == null or frame.look == null:
		return false
	var band: Dictionary = frame.look.band_at(frame.obs.cell.y)
	var name: String = String(band.get("display_name", ""))
	if name.is_empty() or name == _announced:
		return false
	var first: bool = _announced == NO_BAND
	_announced = name
	if first:
		return false
	_text = name.to_upper()
	_tint = frame.look.band_color(frame.obs.cell.y)
	_fired_at = frame.anim_time
	return true


## Everything the plate decides, as data — the rects, the strings, the two baselines and the alpha.
## Empty when there is nothing on screen, which is what makes "it drew nothing" observable rather than
## silent. Same split, and the same reason, as `view/hud/depth_chip.gd`.
func layout(frame: Frame, font: Font) -> Dictionary:
	if frame == null or font == null or _text.is_empty():
		return {}
	var t: float = remaining(_fired_at, frame.anim_time)
	var a: float = alpha_at(t)
	if a <= 0.0:
		return {}
	var y: float = UiTheme.CANVAS.y * CENTRE_Y_FRAC - (1.0 - t) * UiTheme.px(RISE_PX)
	var w: float = tracked_width(font, _text, SIZE, TRACK)
	var kw: float = tracked_width(font, KICKER, KICKER_SIZE, KICKER_TRACK)
	var mid: float = UiTheme.CANVAS.x * 0.5
	var core: float = maxf(w, kw) * 0.5 + UiTheme.px(SCRIM_PAD)
	return {
		"alpha": a,
		"text": _text,
		"text_at": Vector2(mid - w * 0.5, y),
		"kicker": KICKER,
		"kicker_at": Vector2(mid - kw * 0.5, y + UiTheme.px(KICKER_DY)),
		"tint": _tint,
		"rules": [y + UiTheme.px(RULE_ABOVE), y + UiTheme.px(RULE_BELOW)],
		"rule_half": w * 0.5 + UiTheme.px(RULE_PAD),
		"scrim": Rect2(mid - core, y - UiTheme.px(SCRIM_ABOVE), core * 2.0,
			UiTheme.px(SCRIM_ABOVE) + UiTheme.px(SCRIM_BELOW)),
	}


## Is a ceremony visible right now? Legacy's `plate_on_screen()`, and legacy's own bug is the reason it
## reads the same condition `layout` returns on rather than restating it: `main.gd` gated lessons on
## `announcing()` — "is an announcement still owed" — under a comment saying to read the HUD rather than
## mirror it, and then read the predicate that is not the one that draws.
func on_screen(frame: Frame) -> bool:
	return not layout(frame, ThemeDB.fallback_font).is_empty()


## The transcription. Holds no decision of its own beyond the empty-layout guard.
func paint(frame: Frame, ci: CanvasItem) -> void:
	note_frame(frame)
	var font: Font = ThemeDB.fallback_font
	var l: Dictionary = layout(frame, font)
	if l.is_empty():
		return
	var a: float = l["alpha"]
	_draw_scrim(ci, l["scrim"], a)
	var tint: Color = l["tint"]
	_tracked(ci, font, l["kicker"], l["kicker_at"] + SCRIM_INK_OFF * UiTheme.UI_SCALE, KICKER_SIZE, KICKER_TRACK,
		Color(SCRIM_INK.r, SCRIM_INK.g, SCRIM_INK.b, SCRIM_INK_A * a))
	_tracked(ci, font, l["kicker"], l["kicker_at"], KICKER_SIZE, KICKER_TRACK,
		Color(tint.r, tint.g, tint.b, KICKER_ALPHA * a))
	_tracked(ci, font, l["text"], (l["text_at"] as Vector2) + SCRIM_INK_OFF * UiTheme.UI_SCALE, SIZE, TRACK,
		Color(SCRIM_INK.r, SCRIM_INK.g, SCRIM_INK.b, SCRIM_INK_A * a))
	_tracked(ci, font, l["text"], l["text_at"], SIZE, TRACK, Color(tint.r, tint.g, tint.b, a))
	var mid: float = UiTheme.CANVAS.x * 0.5
	var half: float = l["rule_half"]
	for ry: float in (l["rules"] as Array):
		ci.draw_line(Vector2(mid - half, ry), Vector2(mid + half, ry),
			Color(tint.r, tint.g, tint.b, RULE_ALPHA * a), 1.0)


## One string, letter by letter, with `track` px of extra air between them. Godot's `draw_string` has no
## letter-spacing, so tracking is per-glyph placement or it is nothing.
static func _tracked(ci: CanvasItem, font: Font, text: String, at: Vector2, size: int, track: float,
		col: Color) -> void:
	var x: float = at.x
	for i: int in text.length():
		var ch: String = text[i]
		ci.draw_string(font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(size), col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(size)).x + UiTheme.px(track)


## The soft ground: a solid core that fades to nothing left and right, so it has no edge to read as a
## shape. Drawn as three horizontal gradient rects rather than legacy's interpolated grid — its grid
## exists because its scrim spans a bright sky where a vertical falloff is visible too, and every
## arrival this build can produce fires underground against rock.
static func _draw_scrim(ci: CanvasItem, core: Rect2, a: float) -> void:
	var ink := Color(SCRIM_INK.r, SCRIM_INK.g, SCRIM_INK.b, SCRIM_ALPHA * a)
	var clear := Color(SCRIM_INK.r, SCRIM_INK.g, SCRIM_INK.b, 0.0)
	ci.draw_rect(core, ink, true)
	# Constant-alpha strips with an overlap would composite at every seam and rasterize as banding; a
	# gradient has no seams, which is legacy's own reason for not stacking bands.
	var feather: float = UiTheme.px(SCRIM_FEATHER)
	_fade(ci, Rect2(core.position - Vector2(feather, 0.0), Vector2(feather, core.size.y)), clear, ink)
	_fade(ci, Rect2(Vector2(core.end.x, core.position.y), Vector2(feather, core.size.y)), ink, clear)


## A horizontal gradient across `rect`, as a two-triangle quad with interpolated vertex colours.
static func _fade(ci: CanvasItem, rect: Rect2, left: Color, right: Color) -> void:
	var pts := PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)])
	ci.draw_polygon(pts, PackedColorArray([left, right, right, left]))
