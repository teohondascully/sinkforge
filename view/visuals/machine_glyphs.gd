class_name MachineGlyphs
extends RefCounted

## THE SILHOUETTE GLYPHS (A' step 6b, D0363): a machine's icon drawn on any canvas at any scale, legacy
## `scenes/visuals.gd`'s `draw_machine_glyph` and its drawers for the eleven kinds this build's registry
## names; the eight dead drawers (vent, spur, collar, h_drill, drift, crusher, descent, fork) are not
## carried. `active` and `t` (a free-running clock) drive the WORKING animation: a gear that spins, an
## ember that breathes, lift chevrons that march up; `active=false` is a still icon. Authored at scale
## 1.0 for legacy's 32 px cell against `MachineLook.GLYPH_BOX_PX`; a caller passes the scale its box wants.

## The kinds with a drawer, the population `tests/test_looks.gd` pins the registry's kinds against.
const KINDS: Array[String] = ["furnace", "gear", "lift", "drill", "generator", "conduit", "hopper", "rope",
	"torch", "press", "pump"]


static func draw(canvas: CanvasItem, center: Vector2, kind: String, s: float, active: bool, t: float) -> void:
	match kind:
		"furnace":
			_furnace(canvas, center, s, active, t)
		"gear":
			_gear(canvas, center, s, active, t)
		"lift":
			_lift(canvas, center, s, active, t)
		"drill":
			_drill(canvas, center, s, active, t)
		"generator":
			_generator(canvas, center, s, active, t)
		"conduit":
			_conduit(canvas, center, s, active, t)
		"hopper":
			_hopper(canvas, center, s, active, t)
		"rope":
			_rope(canvas, center, s)
		"torch":
			_torch(canvas, center, s, active, t)
		"press":
			_press(canvas, center, s, active, t)
		"pump":
			_pump(canvas, center, s, active, t)
		_:
			_gear(canvas, center, s, active, t)


## Furnace: a dark mouth with a glowing ember and a lintel. The ember BREATHES while burning; cold, a dead
## coal bed, so an unlit forge reads as an off machine (light = working).
static func _furnace(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	canvas.draw_rect(Rect2(c.x - 8.0 * s, c.y - 9.0 * s, 16.0 * s, 2.5 * s), Color(0.05, 0.05, 0.07))
	canvas.draw_rect(Rect2(c.x - 6.5 * s, c.y - 4.0 * s, 13.0 * s, 10.0 * s), Color(0.12, 0.08, 0.05))
	var ember := c + Vector2(0.0, 2.5 * s)
	if active:
		var p: float = 0.78 + 0.22 * sin(t * 6.5)
		canvas.draw_circle(ember, 3.4 * s * (0.85 + 0.25 * p), Color(1.0, 0.55, 0.18).lightened(0.18 * p))
		canvas.draw_circle(ember, 1.7 * s * (0.85 + 0.25 * p), Color(1.0, 0.90, 0.55))
	else:
		canvas.draw_circle(ember, 2.8 * s, Color(0.30, 0.15, 0.11))
		canvas.draw_circle(ember, 1.3 * s, Color(0.40, 0.21, 0.15))


## Gear: a cogged dark disc with a bright hub. ROTATES while running, the "machine is on" read.
static func _gear(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var gear := Color(0.10, 0.13, 0.18)
	var spin: float = t * 2.6 if active else 0.0
	canvas.draw_circle(c, 6.2 * s, gear)
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 + spin
		canvas.draw_circle(c + Vector2(cos(a), sin(a)) * 6.8 * s, 1.7 * s, gear)
	var hub := Color(0.55, 0.78, 0.98)
	canvas.draw_circle(c, 2.6 * s, hub.lightened(0.25) if active else hub)


## Lift: stacked UP-chevrons that MARCH upward while carrying, the goods-go-up read.
static func _lift(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var up := Color(0.85, 1.0, 0.95)
	var rise: float = (fmod(t * 9.0, 7.0) if active else 0.0) * s
	for k: int in 2:
		var oy: float = float(k) * 7.0 * s - 2.0 * s - rise
		var a: float = 1.0 if not active else clampf(1.0 - (float(k) * 7.0 * s - rise) / (9.0 * s), 0.35, 1.0)
		var col := Color(up.r, up.g, up.b, a)
		canvas.draw_line(c + Vector2(-6.0 * s, oy + 4.0 * s), c + Vector2(0.0, oy - 2.0 * s), col, 2.0)
		canvas.draw_line(c + Vector2(0.0, oy - 2.0 * s), c + Vector2(6.0 * s, oy + 4.0 * s), col, 2.0)


## Drill: a boxy housing over a downward bit with helical flutes. The bit BOBS and the flutes MARCH while
## boring: "it is chewing into the rock below", mirroring what the runner does.
static func _drill(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.16, 0.18, 0.22)
	var edge := Color(0.78, 0.66, 0.40)
	var bob: float = (sin(t * 14.0) * 0.9 if active else 0.0) * s
	canvas.draw_rect(Rect2(c.x - 6.5 * s, c.y - 8.0 * s, 13.0 * s, 6.0 * s), steel)
	canvas.draw_rect(Rect2(c.x - 6.5 * s, c.y - 8.0 * s, 13.0 * s, 1.5 * s), edge)
	var tip := Vector2(c.x, c.y + 9.0 * s + bob)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(c.x - 4.0 * s, c.y - 2.0 * s), Vector2(c.x + 4.0 * s, c.y - 2.0 * s), tip]), steel)
	var march: float = fmod(t * 16.0, 4.0) * s if active else 0.0
	for k: int in 3:
		var fy: float = c.y - 1.0 * s + float(k) * 3.2 * s + march + bob
		if fy < c.y + 7.5 * s:
			canvas.draw_line(Vector2(c.x - 3.0 * s, fy), Vector2(c.x + 3.0 * s, fy - 1.4 * s), edge, 1.0)


## Generator: a coal fire breathing in the firebox, a lightning bolt up top bright when active.
static func _generator(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.15, 0.16, 0.20)
	canvas.draw_rect(Rect2(c.x - 7.0 * s, c.y - 7.5 * s, 14.0 * s, 15.0 * s), steel)
	var p: float = (0.72 + 0.28 * sin(t * 7.0)) if active else 0.32
	var fire := c + Vector2(0.0, 5.0 * s)
	canvas.draw_circle(fire, 4.2 * s * (0.8 + 0.3 * p), Color(1.0, 0.5, 0.15, 0.55 + 0.4 * p))
	canvas.draw_circle(fire, 2.0 * s, Color(1.0, 0.85, 0.45, 0.6 + 0.4 * p))
	var bolt := Color(1.0, 0.92, 0.45).lightened(0.2 * p) if active else Color(0.55, 0.52, 0.34)
	var w: float = 2.2 if active else 1.6
	var pts := PackedVector2Array([
		c + Vector2(1.5 * s, -7.0 * s), c + Vector2(-2.0 * s, -1.5 * s),
		c + Vector2(0.8 * s, -1.5 * s), c + Vector2(-1.8 * s, 4.5 * s)])
	for i: int in pts.size() - 1:
		canvas.draw_line(pts[i], pts[i + 1], bolt, w)


## Conduit: a copper pipe with end couplings, an inner channel that GLOWS and a spark that travels DOWN it
## while power flows. The hotbar icon; the in-world tube knows its orientation and the live power level.
static func _conduit(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var copper := Color(0.46, 0.32, 0.20)
	canvas.draw_rect(Rect2(c.x - 3.5 * s, c.y - 8.0 * s, 7.0 * s, 16.0 * s), copper)
	canvas.draw_rect(Rect2(c.x - 5.0 * s, c.y - 8.0 * s, 10.0 * s, 2.2 * s), copper)
	canvas.draw_rect(Rect2(c.x - 5.0 * s, c.y + 5.8 * s, 10.0 * s, 2.2 * s), copper)
	var glow := Color(1.0, 0.85, 0.40, 0.85) if active else Color(0.30, 0.26, 0.20, 0.7)
	canvas.draw_rect(Rect2(c.x - 1.4 * s, c.y - 7.0 * s, 2.8 * s, 14.0 * s), glow)
	if active:
		var sy: float = c.y - 6.0 * s + fmod(t * 26.0, 12.0) * s
		canvas.draw_circle(Vector2(c.x, sy), 1.7 * s, Color(1.0, 0.96, 0.7))


## Hopper: an inverted funnel mouth over a bin holding a MOUND of goods, a chute metering a bit DOWN while
## feeding: "it banks what pours in and trickles it out", the chest of the gravity factory.
static func _hopper(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.30, 0.34, 0.42)
	var lip := Color(0.52, 0.57, 0.66)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-8.0 * s, -8.0 * s), c + Vector2(8.0 * s, -8.0 * s),
		c + Vector2(4.5 * s, -2.0 * s), c + Vector2(-4.5 * s, -2.0 * s)]), steel)
	canvas.draw_line(c + Vector2(-8.0 * s, -8.0 * s), c + Vector2(8.0 * s, -8.0 * s), lip, 1.6)
	canvas.draw_rect(Rect2(c.x - 4.5 * s, c.y - 2.0 * s, 9.0 * s, 8.0 * s), steel.darkened(0.15))
	var gold := Color(0.86, 0.66, 0.30)
	canvas.draw_colored_polygon(PackedVector2Array([
		c + Vector2(-4.0 * s, 5.0 * s), c + Vector2(-1.0 * s, 0.5 * s),
		c + Vector2(1.5 * s, 2.0 * s), c + Vector2(4.0 * s, 5.0 * s)]), gold)
	canvas.draw_rect(Rect2(c.x - 1.6 * s, c.y + 5.5 * s, 3.2 * s, 2.5 * s), steel)
	if active:
		var fy: float = c.y + 8.0 * s + fmod(t * 18.0, 5.0) * s
		canvas.draw_circle(Vector2(c.x, fy), 1.5 * s, gold.lightened(0.2))


## Pump: a steel housing with a rising water column inside, a curved spout, a piston knob bobbing on the
## clock, a droplet climbing the spout while draining; still and dim when there is nothing to pump.
static func _pump(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var steel := Color(0.16, 0.20, 0.26)
	var water := Color(0.34, 0.62, 0.86)
	canvas.draw_rect(Rect2(c.x - 6.0 * s, c.y - 6.0 * s, 12.0 * s, 13.0 * s), steel)
	var rise: float = (0.55 + 0.35 * (0.5 + 0.5 * sin(t * 6.0))) if active else 0.4
	var col_h: float = 9.0 * s * rise
	canvas.draw_rect(Rect2(c.x - 3.0 * s, c.y + 6.0 * s - col_h, 6.0 * s, col_h),
		Color(water.r, water.g, water.b, 0.55 + 0.35 * (1.0 if active else 0.0)))
	canvas.draw_line(c + Vector2(0.0, -3.0 * s), c + Vector2(7.5 * s, -3.0 * s), steel.lightened(0.2), 2.6 * s)
	canvas.draw_line(c + Vector2(7.5 * s, -3.0 * s), c + Vector2(7.5 * s, 1.0 * s), steel.lightened(0.2), 2.6 * s)
	var bob: float = (sin(t * 8.0) * 1.2 if active else 0.0) * s
	canvas.draw_rect(Rect2(c.x - 1.4 * s, c.y - 9.0 * s + bob, 2.8 * s, 3.5 * s), steel.lightened(0.25))
	if active:
		var dy: float = -3.0 * s - 3.0 * s * (0.5 + 0.5 * sin(t * 5.0))
		canvas.draw_circle(c + Vector2(7.5 * s, dy), 1.6 * s, water.lightened(0.25))
		var spill: float = c.y + 2.0 * s + fmod(t * 20.0, 5.0) * s
		canvas.draw_circle(c + Vector2(7.5 * s, spill), 1.3 * s, water)


## Rope: a hanging line with rung KNOTS and a coiled spare at the top: "this unrolls down a shaft".
static func _rope(canvas: CanvasItem, c: Vector2, s: float) -> void:
	var hemp := Color(0.78, 0.66, 0.44)
	canvas.draw_arc(c + Vector2(0.0, -5.5 * s), 3.4 * s, 0.0, TAU, 14, hemp, 2.0)
	canvas.draw_line(c + Vector2(0.0, -2.2 * s), c + Vector2(0.0, 8.5 * s), hemp, 1.8)
	for k: int in 3:
		var ky: float = 0.5 * s + float(k) * 3.2 * s
		canvas.draw_line(c + Vector2(-1.8 * s, ky), c + Vector2(1.8 * s, ky), hemp.darkened(0.18), 1.6)


## Press: a heavy frame over a piston RAM stroking down onto a glowing slab while working.
static func _press(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var frame := Color(0.13, 0.15, 0.20)
	canvas.draw_rect(Rect2(c.x - 7.5 * s, c.y - 9.0 * s, 15.0 * s, 3.0 * s), frame)
	canvas.draw_rect(Rect2(c.x - 7.5 * s, c.y - 9.0 * s, 2.5 * s, 16.0 * s), frame)
	canvas.draw_rect(Rect2(c.x + 5.0 * s, c.y - 9.0 * s, 2.5 * s, 16.0 * s), frame)
	var stroke: float = (0.5 + 0.5 * sin(t * 5.0)) if active else 0.15
	var ram_y: float = c.y - 6.0 * s + stroke * 6.5 * s
	canvas.draw_rect(Rect2(c.x - 1.6 * s, c.y - 7.0 * s, 3.2 * s, ram_y - (c.y - 7.0 * s)), Color(0.42, 0.46, 0.55))
	canvas.draw_rect(Rect2(c.x - 4.5 * s, ram_y, 9.0 * s, 2.4 * s), Color(0.60, 0.65, 0.75))
	var slab := Color(0.85, 0.62, 0.35).lightened(0.2 * stroke) if active else Color(0.45, 0.48, 0.56)
	canvas.draw_rect(Rect2(c.x - 5.5 * s, c.y + 5.2 * s, 11.0 * s, 1.8 * s), slab)


## Torch: a leaning stick with a live FLAME that gutters on the clock; still icons burn steady and small.
static func _torch(canvas: CanvasItem, c: Vector2, s: float, active: bool, t: float) -> void:
	var stick := Color(0.46, 0.32, 0.18)
	var tip := c + Vector2(1.2 * s, -3.5 * s)
	canvas.draw_line(c + Vector2(-1.8 * s, 7.5 * s), tip, stick, 2.4 * maxf(s, 0.6))
	canvas.draw_line(c + Vector2(-1.8 * s, 7.5 * s), tip, stick.lightened(0.18), 1.0 * maxf(s, 0.6))
	var gutter: float = (0.82 + 0.18 * sin(t * 9.0 + c.x * 0.13) + 0.06 * sin(t * 23.0)) if active else 0.9
	var flame := tip + Vector2(0.0, -1.6 * s)
	canvas.draw_circle(flame, 3.0 * s * gutter, Color(1.0, 0.55, 0.16, 0.85))
	canvas.draw_circle(flame + Vector2(0.0, -0.8 * s), 1.6 * s * gutter, Color(1.0, 0.86, 0.42))
	canvas.draw_circle(tip, 1.3 * s, Color(0.16, 0.10, 0.06))
