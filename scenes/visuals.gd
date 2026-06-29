class_name Visuals
extends RefCounted

## Shared VISUAL VOCABULARY — the one place that maps game data to its on-screen look, so the world
## renderer and the HUD never drift apart (they used to each re-draw the same machine glyphs + item
## colours by hand). Pure presentation helpers: a machine's KIND/COLOUR, its silhouette GLYPH drawn on
## any canvas at any scale, and an item's COLOUR. No state, no sim writes — static functions only.

# --- machines ----------------------------------------------------------------

## The icon "kind" of a machine: drill / lift / fork (splitter) / furnace (no-input source) / gear.
static func machine_kind(def: MachineDef) -> String:
	if def.behavior == &"drill":
		return "drill"
	if def.behavior == &"lift":
		return "lift"
	if def.behavior == &"splitter":
		return "fork"
	if def.recipe != null and def.recipe.inputs.is_empty():
		return "furnace"
	return "gear"


## The casing colour of a machine (the riveted body the glyph sits on).
static func machine_color(def: MachineDef) -> Color:
	if def.behavior == &"drill":
		return Color(0.72, 0.56, 0.30)  # steel-amber — "ore extraction tech", distinct from the forge
	if def.behavior == &"lift":
		return Color(0.26, 0.66, 0.62)  # teal — reads as "anti-gravity tech"
	if def.behavior == &"splitter":
		return Color(0.58, 0.42, 0.78)
	var recipe: RecipeDef = def.recipe
	if recipe != null and recipe.inputs.is_empty():
		return Color(0.82, 0.45, 0.20)
	return Color(0.30, 0.55, 0.75)


## Draw a machine's silhouette glyph centred at `center`, scaled by `s` (1.0 = full 32px world icon,
## smaller for HUD chips). `active` + `t` (a free-running clock) drive the WORKING animation — a gear
## that spins, an ember that breathes, lift chevrons that march up; pass active=false for a still icon.
static func draw_machine_glyph(canvas: CanvasItem, center: Vector2, kind: String, s: float,
		active: bool, t: float) -> void:
	match kind:
		"furnace":
			_furnace(canvas, center, s, active, t)
		"gear":
			_gear(canvas, center, s, active, t)
		"lift":
			_lift(canvas, center, s, active, t)
		"fork":
			_fork(canvas, center, s)
		"drill":
			_drill(canvas, center, s, active, t)


## Furnace (ore source / forge): a dark mouth with a glowing ember + lintel. The ember BREATHES while burning.
static func _furnace(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	canvas.draw_rect(Rect2(c.x - 8.0 * s, c.y - 9.0 * s, 16.0 * s, 2.5 * s), Color(0.05, 0.05, 0.07))
	canvas.draw_rect(Rect2(c.x - 6.5 * s, c.y - 4.0 * s, 13.0 * s, 10.0 * s), Color(0.12, 0.08, 0.05))
	var p: float = (0.78 + 0.22 * sin(t * 6.5)) if active else 0.6
	var ember := c + Vector2(0.0, 2.5 * s)
	canvas.draw_circle(ember, 3.4 * s * (0.85 + 0.25 * p), Color(1.0, 0.55, 0.18).lightened(0.18 * p))
	canvas.draw_circle(ember, 1.7 * s * (0.85 + 0.25 * p), Color(1.0, 0.90, 0.55))


## Gear (processor): a cogged dark disc with a bright hub. ROTATES while running — the "machine is on" read.
static func _gear(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var gear := Color(0.10, 0.13, 0.18)
	var spin: float = t * 2.6 if active else 0.0
	canvas.draw_circle(c, 6.2 * s, gear)
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 + spin
		canvas.draw_circle(c + Vector2(cos(a), sin(a)) * 6.8 * s, 1.7 * s, gear)
	var hub := Color(0.55, 0.78, 0.98)
	canvas.draw_circle(c, 2.6 * s, hub.lightened(0.25) if active else hub)


## Lift: stacked UP-chevrons. They MARCH upward while carrying — the goods-go-up read.
static func _lift(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var up := Color(0.85, 1.0, 0.95)
	var rise: float = (fmod(t * 9.0, 7.0) if active else 0.0) * s
	for k: int in 2:
		var oy: float = float(k) * 7.0 * s - 2.0 * s - rise
		var a: float = 1.0 if not active else clampf(1.0 - (float(k) * 7.0 * s - rise) / (9.0 * s), 0.35, 1.0)
		var col := Color(up.r, up.g, up.b, a)
		canvas.draw_line(c + Vector2(-6.0 * s, oy + 4.0 * s), c + Vector2(0.0, oy - 2.0 * s), col, 2.0)
		canvas.draw_line(c + Vector2(0.0, oy - 2.0 * s), c + Vector2(6.0 * s, oy + 4.0 * s), col, 2.0)


## Drill: a boxy housing over a downward-pointing bit with helical flutes. The bit BOBS down and the
## flutes MARCH while boring — the "it's chewing into the rock below" read (mirrors what _run_drill does).
static func _drill(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.16, 0.18, 0.22)
	var edge := Color(0.78, 0.66, 0.40)
	var bob: float = (sin(t * 14.0) * 0.9 if active else 0.0) * s   # the hammer-judder of drilling
	# Housing (the motor block up top).
	canvas.draw_rect(Rect2(c.x - 6.5 * s, c.y - 8.0 * s, 13.0 * s, 6.0 * s), steel)
	canvas.draw_rect(Rect2(c.x - 6.5 * s, c.y - 8.0 * s, 13.0 * s, 1.5 * s), edge)
	# Bit: a tapering shaft to a point, with flute ticks that scroll downward while active.
	var tip := Vector2(c.x, c.y + 9.0 * s + bob)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 4.0 * s, c.y - 2.0 * s), Vector2(c.x + 4.0 * s, c.y - 2.0 * s), tip]), steel)
	var march: float = fmod(t * 16.0, 4.0) * s if active else 0.0
	for k: int in 3:
		var fy: float = c.y - 1.0 * s + float(k) * 3.2 * s + march + bob
		if fy < c.y + 7.5 * s:
			canvas.draw_line(Vector2(c.x - 3.0 * s, fy), Vector2(c.x + 3.0 * s, fy - 1.4 * s), edge, 1.0)


## Fork (splitter): a stem that splits DOWN and to the RIGHT — mirrors its 50/50 routing.
static func _fork(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var fork := Color(0.93, 0.88, 1.0)
	canvas.draw_line(c + Vector2(0.0, -6.5 * s), c, fork, 2.0)
	canvas.draw_line(c, c + Vector2(0.0, 7.0 * s), fork, 2.0)
	canvas.draw_line(c, c + Vector2(7.0 * s, 4.0 * s), fork, 2.0)


# --- items -------------------------------------------------------------------

## The colour of a carried/falling/resting item (ore amber, ingot gold).
static func item_color(item: StringName) -> Color:
	if item == &"ore":
		return Color(0.88, 0.52, 0.24)
	if item == &"ingot":
		return Color(0.97, 0.85, 0.42)
	if item == &"wood":
		return Color(0.55, 0.38, 0.22)
	return Color.WHITE


## Draw an item icon centred at `center`, `size` px square. Sprite-ready: an item_<id>.png
## (docs/ART_SPEC.md) replaces the flat colour chip the moment it exists; absent → today's look.
## One helper so ground piles, the hotbar, and anything else share the same swap.
static func draw_item(canvas: CanvasItem, center: Vector2, size: float, item: StringName) -> void:
	var rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	var tex: Texture2D = Art.tex("item_" + String(item))
	if tex != null:
		canvas.draw_texture_rect(tex, rect, false)
	else:
		canvas.draw_rect(rect, item_color(item))


## Debris/dust colour for a mined terrain material (juice particles) — roughly its rock tone.
static func terrain_dust(material: StringName) -> Color:
	if material == &"stone":
		return Color(0.34, 0.37, 0.44)
	if material == &"ore":
		return Color(0.62, 0.45, 0.26)
	if material == &"wood":
		return Color(0.45, 0.30, 0.17)        # woodchips
	if material == &"leaves":
		return Color(0.28, 0.44, 0.22)        # leaf flecks
	return Color(0.40, 0.30, 0.20)            # earth (default)
