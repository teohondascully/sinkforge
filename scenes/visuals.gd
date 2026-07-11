class_name Visuals
extends RefCounted

## Shared VISUAL VOCABULARY — the one place that maps game data to its on-screen look, so the world
## renderer and the HUD never drift apart (they used to each re-draw the same machine glyphs + item
## colours by hand). Pure presentation helpers: a machine's KIND/COLOUR, its silhouette GLYPH drawn on
## any canvas at any scale, and an item's COLOUR. No state, no sim writes — static functions only.

# --- machines ----------------------------------------------------------------

## THE MACHINE STYLE REGISTRY — the representation-side twin of FactorySim._BEHAVIORS: the ONE
## table wiring a behavior tag to its LOOK (glyph kind + casing colour), replacing two parallel
## if-ladders that had to be extended in lock-step. A def with no entry falls back on its recipe:
## a no-input source reads as a furnace, anything else as a gear (the generic runner). Adding a
## machine = one entry here (+ a drawer in draw_machine_glyph if its kind is genuinely new).
const MACHINE_STYLE: Dictionary = {
	&"drill": {"kind": "drill", "color": Color(0.72, 0.56, 0.30)},        # steel-amber — ore-extraction tech
	&"lift": {"kind": "lift", "color": Color(0.26, 0.66, 0.62)},          # teal — anti-gravity tech
	&"splitter": {"kind": "fork", "color": Color(0.58, 0.42, 0.78)},
	&"generator": {"kind": "generator", "color": Color(0.80, 0.66, 0.26)},# electric gold — burns fuel → power
	&"conduit": {"kind": "conduit", "color": Color(0.66, 0.47, 0.30)},    # copper — the power-tube material
	&"hopper": {"kind": "hopper", "color": Color(0.40, 0.44, 0.52)},      # cool gunmetal — a storage bin
}


## The icon "kind" of a machine: its style entry, else furnace (no-input source) / gear (runner).
static func machine_kind(def: MachineDef) -> String:
	if MACHINE_STYLE.has(def.behavior):
		return (MACHINE_STYLE[def.behavior] as Dictionary)["kind"]
	if def.recipe != null and def.recipe.inputs.is_empty():
		return "furnace"
	return "gear"


## The casing colour of a machine (the riveted body the glyph sits on).
static func machine_color(def: MachineDef) -> Color:
	if MACHINE_STYLE.has(def.behavior):
		return (MACHINE_STYLE[def.behavior] as Dictionary)["color"]
	var recipe: RecipeDef = def.recipe
	if recipe != null and recipe.inputs.is_empty():
		return Color(0.82, 0.45, 0.20)   # ember-orange — the furnace/source family
	return Color(0.30, 0.55, 0.75)       # steel-blue — the generic processor


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
		"generator":
			_generator(canvas, center, s, active, t)
		"conduit":
			_conduit(canvas, center, s, active, t)
		"hopper":
			_hopper(canvas, center, s, active, t)


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


## Generator (coal burner → power): a steel housing with a coal-fire at its base that BREATHES while
## fueled, and a bright lightning bolt that flares when it's pouring power. The fire + bolt go dim/still
## when it runs dry — the "is it making power?" read (mirrors _run_generator's fuel state).
static func _generator(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.15, 0.16, 0.20)
	canvas.draw_rect(Rect2(c.x - 7.0 * s, c.y - 7.5 * s, 14.0 * s, 15.0 * s), steel)
	# Coal fire glowing in the firebox at the base — breathes while burning.
	var p: float = (0.72 + 0.28 * sin(t * 7.0)) if active else 0.32
	var fire := c + Vector2(0.0, 5.0 * s)
	canvas.draw_circle(fire, 4.2 * s * (0.8 + 0.3 * p), Color(1.0, 0.5, 0.15, 0.55 + 0.4 * p))
	canvas.draw_circle(fire, 2.0 * s, Color(1.0, 0.85, 0.45, 0.6 + 0.4 * p))
	# Lightning bolt up top — the power output, bright when active.
	var bolt := Color(1.0, 0.92, 0.45).lightened(0.2 * p) if active else Color(0.55, 0.52, 0.34)
	var w: float = 2.2 if active else 1.6
	var pts := PackedVector2Array([
		c + Vector2(1.5 * s, -7.0 * s), c + Vector2(-2.0 * s, -1.5 * s),
		c + Vector2(0.8 * s, -1.5 * s), c + Vector2(-1.8 * s, 4.5 * s)])
	for i: int in pts.size() - 1:
		canvas.draw_line(pts[i], pts[i + 1], bolt, w)


## Conduit (power tube): a copper pipe with end couplings + an inner channel that GLOWS and a spark that
## travels DOWN it while power flows (active) — the "power pours down this tube" read. Used for the hotbar
## icon; the in-world tube is drawn by WorldRenderer (it knows orientation + the live power level).
static func _conduit(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var copper := Color(0.46, 0.32, 0.20)
	canvas.draw_rect(Rect2(c.x - 3.5 * s, c.y - 8.0 * s, 7.0 * s, 16.0 * s), copper)
	canvas.draw_rect(Rect2(c.x - 5.0 * s, c.y - 8.0 * s, 10.0 * s, 2.2 * s), copper)   # top coupling
	canvas.draw_rect(Rect2(c.x - 5.0 * s, c.y + 5.8 * s, 10.0 * s, 2.2 * s), copper)   # bottom coupling
	var glow := Color(1.0, 0.85, 0.40, 0.85) if active else Color(0.30, 0.26, 0.20, 0.7)
	canvas.draw_rect(Rect2(c.x - 1.4 * s, c.y - 7.0 * s, 2.8 * s, 14.0 * s), glow)     # inner channel
	if active:                                                                          # a spark falling down it
		var sy: float = c.y - 6.0 * s + fmod(t * 26.0, 12.0) * s
		canvas.draw_circle(Vector2(c.x, sy), 1.7 * s, Color(1.0, 0.96, 0.7))


## Hopper (storage bin): an inverted funnel mouth over a bin that holds a MOUND of stockpiled goods, with a
## chute at the base metering a bit DOWN while feeding (active). The mound + the falling nub read "it banks
## what pours in and trickles it out" — the chest of the gravity factory.
static func _hopper(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.30, 0.34, 0.42)
	var lip := Color(0.52, 0.57, 0.66)
	# Funnel mouth (wide top tapering in) — the catch.
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-8.0 * s, -8.0 * s), c + Vector2(8.0 * s, -8.0 * s),
		c + Vector2(4.5 * s, -2.0 * s), c + Vector2(-4.5 * s, -2.0 * s)]), steel)
	canvas.draw_line(c + Vector2(-8.0 * s, -8.0 * s), c + Vector2(8.0 * s, -8.0 * s), lip, 1.6)
	# Bin body holding a heaped mound of goods.
	canvas.draw_rect(Rect2(c.x - 4.5 * s, c.y - 2.0 * s, 9.0 * s, 8.0 * s), steel.darkened(0.15))
	var gold := Color(0.86, 0.66, 0.30)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-4.0 * s, 5.0 * s), c + Vector2(-1.0 * s, 0.5 * s),
		c + Vector2(1.5 * s, 2.0 * s), c + Vector2(4.0 * s, 5.0 * s)]), gold)  # the stockpile mound
	# Chute at the base + a nub of goods trickling out while feeding.
	canvas.draw_rect(Rect2(c.x - 1.6 * s, c.y + 5.5 * s, 3.2 * s, 2.5 * s), steel)
	if active:
		var fy: float = c.y + 8.0 * s + fmod(t * 18.0, 5.0) * s
		canvas.draw_circle(Vector2(c.x, fy), 1.5 * s, gold.lightened(0.2))


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
	if item == &"coal":
		return Color(0.24, 0.25, 0.29)        # dark slate-black — the generator's fuel
	if item == &"wood_pickaxe":
		return Color(0.62, 0.46, 0.30)        # starter tools — a wood-handle brown
	if item == &"wood_axe":
		return Color(0.70, 0.52, 0.32)
	if item == &"stone_pickaxe":
		return Color(0.56, 0.60, 0.66)        # the tier-2 upgrade — cold stone-grey (unlocks deepslate)
	return Color.WHITE


## Draw an item icon centred at `center`, `size` px square. Sprite-ready: an item_<id>.png
## (docs/ART_SPEC.md) replaces the procedural glyph the moment it exists; absent → a drawn glyph that
## actually READS as the thing (a pickaxe looks like a pickaxe, an ingot like a bar). One helper so ground
## piles, the hotbar, the craft screen, and anything else share the same look + the same sprite swap.
static func draw_item(canvas: CanvasItem, center: Vector2, size: float, item: StringName) -> void:
	var tex: Texture2D = Art.tex("item_" + String(item))
	if tex != null:
		canvas.draw_texture_rect(tex, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false)
		return
	match item:
		&"ore":
			_item_ore(canvas, center, size)
		&"ingot":
			_item_ingot(canvas, center, size)
		&"coal":
			_item_coal(canvas, center, size)
		&"wood":
			_item_wood(canvas, center, size)
		&"wood_pickaxe":
			_item_pickaxe(canvas, center, size, Color(0.55, 0.40, 0.24), Color(0.74, 0.63, 0.47))
		&"stone_pickaxe":
			_item_pickaxe(canvas, center, size, Color(0.50, 0.37, 0.23), Color(0.60, 0.64, 0.71))
		&"wood_axe":
			_item_axe(canvas, center, size, Color(0.55, 0.40, 0.24), Color(0.64, 0.67, 0.73))
		_:
			canvas.draw_rect(Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), item_color(item))


## Polygon helper: points given as size-fractions from the centre (y+ down), filled `fill` with a crisp
## darker outline so a glyph reads at small hotbar scale. Keeps the item drawers terse + consistent.
static func _poly(canvas: CanvasItem, c: Vector2, size: float, frac: Array, fill: Color) -> void:
	var pts := PackedVector2Array()
	for f: Vector2 in frac:
		pts.append(c + f * size)
	canvas.draw_colored_polygon(pts, fill)
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), fill.darkened(0.45), maxf(1.0, size * 0.03), true)


## ORE — a rough rock nugget with bright amber ore flecks embedded (reads as "metal IN rock").
static func _item_ore(canvas: CanvasItem, c: Vector2, size: float) -> void:
	_poly(canvas, c, size, [Vector2(-0.34, -0.06), Vector2(-0.10, -0.34), Vector2(0.28, -0.24),
		Vector2(0.36, 0.14), Vector2(0.06, 0.34), Vector2(-0.30, 0.22)], Color(0.44, 0.46, 0.52))
	for f: Vector2 in [Vector2(-0.10, 0.02), Vector2(0.14, -0.10), Vector2(-0.02, 0.18)]:
		canvas.draw_circle(c + f * size, size * 0.06, Color(0.90, 0.56, 0.24))
		canvas.draw_circle(c + f * size - Vector2(size * 0.02, size * 0.02), size * 0.025, Color(1.0, 0.82, 0.5))


## INGOT — a trapezoidal cast metal bar with a bright top face (the classic ingot silhouette).
static func _item_ingot(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var gold := Color(0.93, 0.78, 0.36)
	_poly(canvas, c, size, [Vector2(-0.26, -0.16), Vector2(0.26, -0.16), Vector2(0.40, 0.18),
		Vector2(-0.40, 0.18)], gold)
	_poly(canvas, c, size, [Vector2(-0.26, -0.16), Vector2(0.26, -0.16), Vector2(0.20, -0.06),
		Vector2(-0.20, -0.06)], gold.lightened(0.28))   # lit top face


## COAL — a dark faceted lump with a cool sheen highlight (distinct from the rounded ore nugget).
static func _item_coal(canvas: CanvasItem, c: Vector2, size: float) -> void:
	_poly(canvas, c, size, [Vector2(-0.30, -0.10), Vector2(-0.06, -0.32), Vector2(0.30, -0.18),
		Vector2(0.34, 0.16), Vector2(0.02, 0.34), Vector2(-0.32, 0.16)], Color(0.20, 0.21, 0.25))
	_poly(canvas, c, size, [Vector2(-0.06, -0.32), Vector2(0.14, -0.06), Vector2(-0.10, 0.00)],
		Color(0.34, 0.36, 0.42))   # a lit facet


## WOOD — a short LOG: a brown bar capped by round ends, with concentric end-grain rings on the left face.
static func _item_wood(canvas: CanvasItem, c: Vector2, size: float) -> void:
	var bark := Color(0.52, 0.36, 0.20)
	canvas.draw_rect(Rect2(c - Vector2(size * 0.30, size * 0.16), Vector2(size * 0.60, size * 0.32)), bark)
	canvas.draw_circle(c + Vector2(size * 0.30, 0.0), size * 0.16, bark)
	canvas.draw_circle(c - Vector2(size * 0.30, 0.0), size * 0.16, bark.lightened(0.10))   # left end face
	canvas.draw_arc(c - Vector2(size * 0.30, 0.0), size * 0.10, 0.0, TAU, 12, bark.darkened(0.25), maxf(1.0, size * 0.03))
	canvas.draw_circle(c - Vector2(size * 0.30, 0.0), size * 0.035, bark.darkened(0.30))


## PICKAXE — a wood handle with a curved double-pointed head at the top (points sweeping down-and-out).
## `handle`/`head` colours let one drawer serve the wood pick and the grey stone pick.
static func _item_pickaxe(canvas: CanvasItem, c: Vector2, size: float, handle: Color, head: Color) -> void:
	canvas.draw_line(c + Vector2(size * 0.10, size * 0.42), c + Vector2(-0.02 * size, -0.16 * size),
		handle, maxf(1.5, size * 0.12))                              # the shaft
	_poly(canvas, c, size, [Vector2(-0.44, -0.04), Vector2(-0.16, -0.30), Vector2(0.16, -0.30),
		Vector2(0.44, -0.04), Vector2(0.12, -0.16), Vector2(-0.12, -0.16)], head)   # the curved head


## AXE — a wood handle with a fanned blade on the upper right + a bright cutting edge.
static func _item_axe(canvas: CanvasItem, c: Vector2, size: float, handle: Color, blade: Color) -> void:
	canvas.draw_line(c + Vector2(size * 0.06, size * 0.42), c + Vector2(-0.10 * size, -0.34 * size),
		handle, maxf(1.5, size * 0.12))                              # the shaft
	_poly(canvas, c, size, [Vector2(-0.14, -0.34), Vector2(0.30, -0.36), Vector2(0.40, -0.02),
		Vector2(-0.06, -0.02)], blade)                              # the blade fanning right
	canvas.draw_line(c + Vector2(0.30 * size, -0.36 * size), c + Vector2(0.40 * size, -0.02 * size),
		blade.lightened(0.4), maxf(1.0, size * 0.04))              # honed cutting edge


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
