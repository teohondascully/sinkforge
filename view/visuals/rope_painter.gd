class_name RopePainter
extends RefCounted

## THE LINE, AND EVERYTHING DRAWN ALONG IT (A' step 5d, D0361): the live grapple cord with its slack bow,
## the hook at its end, the aim ghost that shows where the hook would touch, and the placed climb-ropes
## hanging down their own shafts. Legacy `scenes/rope_view.gd` lifted onto the `Frame` contract: its two
## reach-ins (`_view_world_rect`, `_anim_time`) are `frame.view_world_rect` and `frame.anim_time`, and
## everything it read off the player and the sim it reads off the observation's `grapple_*`, `hand`,
## `placed` fields. Pure representation: nothing here reaches the sim, nothing here is state.
##
## UNITS. Cord widths, the hook wedge and the aim ring keep legacy's pixels: they are read against the
## body, which ported at identical pixels. The placed rope's knots are per CELL, and the cell is 16 px
## here against legacy's 32, so their spacing halves (plan §3.2's fine-detail rule).

const LOGIC_PX: float = 16.0
const ROPE_SEGMENTS: int = 14
## The widest stroke the cord is drawn with, the dark under-stroke. NAMED because a fixture measuring the
## hang measures the cord's OUTER EDGE, which stands half of this off the centreline the sag describes.
const CORD_W: float = 4.5
## The FIBRE stroke, laid over the under-stroke: the width a fixture masking the cord by colour sees.
const CORD_CORE_W: float = 2.0
const ROPE_CORE := Color(0.78, 0.70, 0.52)
const ROPE_SHADE := Color(0.20, 0.16, 0.12)
const HEMP := Color(0.76, 0.63, 0.42)
const HEMP_SHADE := Color(0.42, 0.33, 0.20)
## The sag: a slack line bows, a taut one is bar-straight, and which one you are on is visible without
## reading a speed. `SAG_CAP` is the most of the chord the hang may ever be; `SAG_MIN` keeps a whisker of
## curve on a tight line so it reads as rope rather than as a beam.
const SAG_CAP: float = 0.42
const SAG_MIN: float = 2.0
## The aiming ghost, drawn only while the line is stowed (on the rope the attention belongs on the arc):
## a dotted stub off the hand and one ring where the throw lands. A stub rather than a tether, because a
## lead inked hand to target read as a dimension line; the endpoint is the information.
const AIM_STUB: float = 0.26
const AIM_STUB_MAX: float = 74.0
const AIM_DOTS: int = 4
const AIM_RING: float = 6.0
const AIM_LEAD := Color(0.86, 0.80, 0.62, 0.34)
const AIM_MARK := Color(0.99, 0.88, 0.56, 0.88)
const AIM_MISS := Color(0.62, 0.64, 0.70, 0.16)
const AIM_SHADE := Color(0.06, 0.05, 0.04, 0.55)
const AIM_SHADE_W: float = 3.0
const HOOK_LIT := Color(0.92, 0.86, 0.70)


static func paint(frame: Frame, ci: CanvasItem) -> void:
	if frame == null or frame.obs == null:
		return
	_draw_ropes(frame, ci)
	_draw_aim_ghost(frame, ci)
	_draw_grapple(frame, ci)


static func px(fx: Vector2i) -> Vector2:
	return Vector2(float(fx.x) / float(Fx.SCALE), float(fx.y) / float(Fx.SCALE))


## The bow of a hanging span: legacy `WorldRenderer.rope_sag`, a catenary's depth for a chord and a
## slack fraction, capped and floored.
static func rope_sag(span: float, slack: float) -> float:
	var s: float = clampf(slack, 0.0, 0.94)
	return clampf(span * sqrt(3.0 * s / (8.0 * (1.0 - s))), SAG_MIN, span * SAG_CAP)


## The cord's polyline, bowed by `sag`: a parabola is close enough to a catenary at this size.
static func cord_points(from: Vector2, to: Vector2, sag: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in ROPE_SEGMENTS + 1:
		var t: float = float(i) / float(ROPE_SEGMENTS)
		var p: Vector2 = from.lerp(to, t)
		p.y += sin(t * PI) * sag
		pts.append(p)
	return pts


## The hook: a wedge biting into the rock, oriented along the line's last segment so it always looks
## planted. Returns the wedge's four corners, head first.
static func hook_polygon(pts: PackedVector2Array) -> PackedVector2Array:
	var n: int = pts.size()
	var dir: Vector2 = (pts[n - 1] - pts[n - 2]).normalized()
	var side := Vector2(-dir.y, dir.x)
	var head: Vector2 = pts[n - 1] + dir * 3.0
	return PackedVector2Array([head, head - dir * 9.0 + side * 5.0, head - dir * 6.0, head - dir * 9.0 - side * 5.0])


## How much of a throw the ghost's lead draws: a fraction of it, never more than AIM_STUB_MAX px.
static func stub_fraction(full: float) -> float:
	return minf(full * AIM_STUB, AIM_STUB_MAX) / maxf(full, 1.0)


## The placed ropes: a taut hemp line down each cell with rung knots, a hitch loop on the anchor cell, a
## frayed tail on the bottom one, swaying gently on the cosmetic clock like a hung line.
static func _draw_ropes(frame: Frame, ci: CanvasItem) -> void:
	var o: Interface.Observation = frame.obs
	var view: Rect2 = frame.view_world_rect.grow(2.0 * LOGIC_PX)
	for cell: Vector2i in o.placed:
		if not o.is_climbable(cell) or not view.has_point(Vector2(cell) * LOGIC_PX):
			continue
		var x: float = float(cell.x) * LOGIC_PX + LOGIC_PX * 0.5
		var top := Vector2(x, float(cell.y) * LOGIC_PX)
		var sway: float = sin(frame.anim_time * 1.6 + float(cell.y) * 0.7) * 0.8
		var bot := Vector2(x + sway, float(cell.y + 1) * LOGIC_PX)
		ci.draw_line(top + Vector2(1.2, 0), bot + Vector2(1.2, 0), HEMP_SHADE, 2.6)   # back shade reads as depth
		ci.draw_line(top, bot, HEMP, 1.8)
		for k: int in 3:                                                             # rung knots
			var ky: float = top.y + 2.5 + float(k) * 5.25
			ci.draw_line(Vector2(x - 3.0, ky), Vector2(x + 3.0, ky), HEMP.darkened(0.15), 2.0)
		if not o.is_climbable(cell + Vector2i(0, -1)):
			ci.draw_arc(top + Vector2(0.0, 3.0), 3.2, 0.0, TAU, 10, HEMP, 2.0)          # the hitch loop
		if not o.is_climbable(cell + Vector2i(0, 1)):
			ci.draw_line(bot, bot + Vector2(sway * 2.0, -5.0), HEMP.darkened(0.1), 1.6)  # frayed tail curl


static func _draw_aim_ghost(frame: Frame, ci: CanvasItem) -> void:
	var o: Interface.Observation = frame.obs
	if o.grapple_live or o.grapple_ghost.is_empty():
		return
	var from: Vector2 = px(o.hand)
	var to: Vector2 = px(o.grapple_ghost["at"])
	var hit: bool = bool(o.grapple_ghost["hit"])
	var stub: float = stub_fraction(from.distance_to(to))
	for i: int in AIM_DOTS:
		var t0: float = stub * float(i) / float(AIM_DOTS)
		var t1: float = t0 + stub * 0.5 / float(AIM_DOTS)
		var fade: float = 1.0 - 0.65 * float(i) / float(AIM_DOTS)   # the stub fades along its length
		if not hit:
			fade *= 0.6                                          # nothing in range: quieter, and no ring
		ci.draw_line(from.lerp(to, t0), from.lerp(to, t1), (AIM_LEAD if hit else AIM_MISS) * Color(1, 1, 1, fade), 1.0)
	if hit:
		ci.draw_arc(to, AIM_RING, 0.0, TAU, 16, AIM_SHADE, AIM_SHADE_W)   # a dark backing ring survives pale rock
		ci.draw_arc(to, AIM_RING, 0.0, TAU, 16, AIM_MARK, 1.5)


## A wrapped line is drawn as what it is: bar-taut around every corner it has caught on, hanging only on
## the last segment; the piton belongs at the hook, pointed back down the first span. A chained throw
## draws both the line still carrying the body and the hook already on its way.
static func _draw_grapple(frame: Frame, ci: CanvasItem) -> void:
	var o: Interface.Observation = frame.obs
	if not o.grapple_live:
		return
	var from: Vector2 = px(o.hand)
	if o.grapple_anchored:
		var at: Vector2 = px(o.grapple_anchor)
		for pivot: Vector2i in o.grapple_pivots:
			_draw_cord(ci, at, px(pivot), 0.0)
			at = px(pivot)
		_draw_cord(ci, from, at, rope_sag(from.distance_to(at), float(o.grapple_slack) / 1000.0))
		var first: Vector2 = px(o.grapple_pivots[0]) if not o.grapple_pivots.is_empty() else from
		_draw_hook(ci, cord_points(first, px(o.grapple_anchor), 0.0))
	if o.grapple_throwing:
		var flight: PackedVector2Array = cord_points(from, px(o.grapple_tip), 0.0)
		_draw_cord(ci, from, px(o.grapple_tip), 0.0)
		_draw_hook(ci, flight)


## Two passes, a dark under-stroke that gives the rope an edge against light rock and then the fibre, and
## a twist highlight every other segment: at this scale, rope or laser is whether it has any structure.
static func _draw_cord(ci: CanvasItem, from: Vector2, to: Vector2, sag: float) -> void:
	var pts: PackedVector2Array = cord_points(from, to, sag)
	for i: int in ROPE_SEGMENTS:
		ci.draw_line(pts[i], pts[i + 1], ROPE_SHADE, CORD_W)
	for i: int in ROPE_SEGMENTS:
		ci.draw_line(pts[i], pts[i + 1], ROPE_CORE, CORD_CORE_W)
	for i: int in ROPE_SEGMENTS:
		if i % 2 == 0:
			ci.draw_line(pts[i], pts[i].lerp(pts[i + 1], 0.55), ROPE_CORE.lightened(0.35), 1.0)


static func _draw_hook(ci: CanvasItem, pts: PackedVector2Array) -> void:
	var n: int = pts.size()
	if n < 2 or pts[n - 1] == pts[n - 2]:
		return
	var wedge: PackedVector2Array = hook_polygon(pts)
	ci.draw_colored_polygon(wedge, ROPE_SHADE.lightened(0.22))
	var dir: Vector2 = (pts[n - 1] - pts[n - 2]).normalized()
	var side := Vector2(-dir.y, dir.x)
	ci.draw_line(wedge[0] - dir * 8.0 + side * 3.0, wedge[0] - dir * 2.0, HOOK_LIT, 1.0)
