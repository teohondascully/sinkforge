class_name PageDraw
extends RefCounted

## WHAT EVERY DRAWN PAGE NEEDS AND NOTHING ELSE (A' step 6j, D0372): the primitives a modal page is
## built from, lifted from legacy `scenes/visuals.gd:1660-1875` and `page_surface.gd`, verbatim in their
## arithmetic. Static, taking the canvas and the font as arguments, in the shape every painter here
## already uses; nothing draws anything of its own beyond the mark it names. Every length is in CANVAS
## px -- the caller scales its authored numbers through `UiTheme.px` before it gets here.
##
## Elevation instead of a border: a modern panel does not outline itself, it casts (`soft_shadow`), and
## one hairline of light along the top edge says which way the lamp is (`panel_sheen`). The focus ring
## carries three channels -- shape, weight, inset -- so any one alone still says focus, and a keyline
## inside it so the pale gold cannot merge into a light fill.

const FOCUS_W: float = 2.0            ## the ring, at double the weight of every 1px edge near it
const FOCUS_GROW: float = 2.5         ## how far outside the control it sits, where nothing else paints
const FOCUS_KEYLINE := Color(0.0, 0.0, 0.0, 0.55)
const FOCUS_SPINE_W: float = 2.0
const FOCUS_SPINE_DX: float = 4.0     ## far enough left of the plate that the two marks stay two marks
const FOCUS_SPINE_INSET: float = 2.0
const KEYCAP_PAD_X: float = 8.0
const KEYCAP_MIN_W: float = 14.0
const KEYCAP_PAD_Y: float = 7.0
const KEYCAP_BASE: float = 5.0
const KEYCAP_DROP: float = 1.0


## A filled box with rounded corners; 8 segments is already past where the curve reads as faceted.
static func round_rect(canvas: CanvasItem, rect: Rect2, r: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(r))
	sb.corner_detail = 8
	sb.draw(canvas.get_canvas_item(), rect)


## Rounded on the left two corners only, for a rail sitting flush against the panel's edge.
static func round_rect_left(canvas: CanvasItem, rect: Rect2, r: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(0)
	sb.corner_radius_top_left = int(r)
	sb.corner_radius_bottom_left = int(r)
	sb.corner_detail = 8
	sb.draw(canvas.get_canvas_item(), rect)


## Concentric translucent rings: the cheap honest version of a cast shadow.
static func soft_shadow(canvas: CanvasItem, rect: Rect2, spread: int, peak: float) -> void:
	for i: int in range(spread, 0, -1):
		var t: float = float(i) / float(spread)
		canvas.draw_rect(rect.grow(float(i)), Color(0.0, 0.0, 0.0, peak * (1.0 - t) * 0.32))


## One hairline of light along the top edge and a slow warm gradient down the plate. `scale` carries
## legacy's 46 px gradient reach onto the canvas.
static func panel_sheen(canvas: CanvasItem, rect: Rect2, scale: float = 1.0) -> void:
	for i: int in 10:
		var t: float = float(i) / 9.0
		canvas.draw_rect(Rect2(rect.position.x + 2.0, rect.position.y + 2.0 + t * 46.0 * scale, rect.size.x - 4.0, 5.0 * scale), Color(1.0, 0.94, 0.82, 0.020 * (1.0 - t)))
	canvas.draw_rect(Rect2(rect.position.x + 8.0, rect.position.y, rect.size.x - 16.0, 1.0), Color(1.0, 1.0, 1.0, 0.075))


## Letter-spaced type, drawn a character at a time: small caps with air between them is most of what
## separates a title from a label.
static func tracked(canvas: CanvasItem, font: Font, text: String, at: Vector2, size: int, track: float, col: Color) -> void:
	var x: float = at.x
	for i: int in text.length():
		var ch: String = text[i]
		canvas.draw_string(font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track


## What `tracked` occupies: the plain width plus one gap per letter. Measuring tracked type with a bare
## `get_string_size` is how a caption ends up printed through its own title.
static func tracked_width(font: Font, text: String, size: int, track: float) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + track * float(maxi(text.length() - 1, 0))


## The focus ring: where the next keypress will land. The two colours are the caller's palette.
static func focus_ring(canvas: CanvasItem, box: Rect2, ring: Color, spine_col: Color, grow: float = FOCUS_GROW, spine: bool = false) -> void:
	canvas.draw_rect(box.grow(grow - 1.0), FOCUS_KEYLINE, false, 1.0)
	canvas.draw_rect(box.grow(grow), ring, false, FOCUS_W)
	if spine:
		canvas.draw_rect(Rect2(box.position.x - FOCUS_SPINE_DX, box.position.y + FOCUS_SPINE_INSET, FOCUS_SPINE_W, box.size.y - FOCUS_SPINE_INSET * 2.0), spine_col)


static func keycap_width(font: Font, key: String, fs: int) -> float:
	return maxf(font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + KEYCAP_PAD_X, KEYCAP_MIN_W)


static func keycap_height(fs: int) -> float:
	return float(fs) + KEYCAP_PAD_Y


## Draws one cap and returns the width it consumed, so a row of them lays out once. A bare digit reads
## as a step number; the same digit inside a raised cap reads as something to press.
static func keycap(canvas: CanvasItem, font: Font, at: Vector2, key: String, fs: int) -> float:
	var tw: float = font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w: float = keycap_width(font, key, fs)
	var h: float = keycap_height(fs)
	var box := Rect2(at, Vector2(w, h))
	round_rect(canvas, Rect2(box.position + Vector2(0.0, KEYCAP_DROP), box.size), 3.0, Color(0.0, 0.0, 0.0, 0.35))
	round_rect(canvas, box, 3.0, Color(0.13, 0.145, 0.18))
	canvas.draw_string(font, at + Vector2((w - tw) * 0.5, h - KEYCAP_BASE), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.74, 0.78, 0.86))
	return w


## Darkens the frame's edges so the eye is pushed to whatever plate is open. The canvas size is a
## parameter: this file draws for whoever asks.
static func edge_vignette(canvas: CanvasItem, canvas_size: Vector2, peak: float) -> void:
	if peak <= 0.001:
		return
	var reach: float = 130.0 * canvas_size.x / 640.0
	for i: int in 18:
		var t: float = float(i) / 18.0
		var inset: float = t * reach
		canvas.draw_rect(Rect2(0.0, 0.0, canvas_size.x, 1.0 + inset * 0.5), Color(0.0, 0.0, 0.0, peak * 0.030))
		canvas.draw_rect(Rect2(0.0, canvas_size.y - 1.0 - inset * 0.5, canvas_size.x, 1.0 + inset * 0.5), Color(0.0, 0.0, 0.0, peak * 0.030))
		canvas.draw_rect(Rect2(0.0, 0.0, 1.0 + inset, canvas_size.y), Color(0.0, 0.0, 0.0, peak * 0.024))
		canvas.draw_rect(Rect2(canvas_size.x - 1.0 - inset, 0.0, 1.0 + inset, canvas_size.y), Color(0.0, 0.0, 0.0, peak * 0.024))
