class_name RingPainter
extends RefCounted

## THE RING'S DRAW PASS, out of `TargetGuide` for the size gate (D0521): the guide decides WHAT is ringed
## (`TargetGuide.target`, its search and its cache) and this file draws it -- the ring with its compass
## ticks, the block outline within NEAR_M, the cut mark, and the word (`RingWord`).
##
## THE RING IS A STATE WHEN ITS TARGET IS A MACHINE (D0521, strangers 103-120, three batches on the same
## opening). A drop feeds the forge when the body's CENTRE is within `Reach.NUM/DEN` metres of the machine
## cell's centre -- a 22-cell band at foot level, and nothing on screen said which side of it the body was
## on. S119 stood at cell 128, the band's last, and pressed 1 then Q eleven times: TOO FAR each press, the
## once-only lesson long shown, the slot flash gone by the capture; S109 the same from 128 and 130; S111
## wrote "the game showed me I was always too far but never showed me where close enough was". The
## guide's outline within NEAR_M (2.2 m, D0443) is the POINTER's rule, written for the block a hold must
## land on, and a different number from the drop's. So for a machine target (smelt's forge, deliver's and
## winch's rig) and for BUILD's mouth (`Verbs.build` gates on the same `can_reach`) the ring reads the
## drop's own rule, through `Reach` in core with the sim's own inputs, and shows it: IN REACH, the rim is
## solid (no breath) and the disc is filled at NEAR_FILL, and the word reads "FORGE · IN REACH"; out of
## reach the ring is the pointer it was. A cell target and a pile are not this rule's and do not change.
## Readable at rest, in any frame: the strangers' walks are 30-60 ticks and did not shorten when told to
## tap (D0520), so the state cannot live in a flash.


## The ring for rung `id` on the target `at` (world px), at the guide's `alpha`; nothing off the canvas.
static func draw(frame: Frame, ci: CanvasItem, id: StringName, at: Vector2, alpha: float) -> void:
	var canvas: Vector2 = frame.canvas_of(at)
	if not Rect2(Vector2.ZERO, UiTheme.CANVAS).has_point(canvas):
		return
	var o: Interface.Observation = frame.obs
	var reached: bool = RingWord.metre_target(id, o, at) and in_reach(o, at)
	var breath: float = 1.0 if reached else 0.55 + 0.45 * sin(frame.anim_time * TAU * TargetGuide.BREATH_HZ)
	var body: Vector2 = Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)
	var dist_m: float = body.distance_to(at) / float(Interface.Units.LOGIC_PX)
	var r: float = TargetGuide.ring_m(dist_m) * TargetGuide.o_px_per_m(frame) * (0.92 + 0.08 * breath)
	var ink: float = alpha * (0.55 + 0.4 * breath)
	if reached:
		ci.draw_circle(canvas, r, Color(TargetGuide.INK, alpha * TargetGuide.NEAR_FILL))
	elif not within_reach(o, id, at):
		reach_line(frame, ci, id, at, alpha)   # NOT `not reached`: that is false for every cell target
	ci.draw_arc(canvas, r, 0.0, TAU, 40, Color(TargetGuide.RIM, alpha * 0.6), TargetGuide.RING_WIDTH + 2.0, true)
	ci.draw_arc(canvas, r, 0.0, TAU, 40, Color(TargetGuide.INK, ink), TargetGuide.RING_WIDTH, true)
	for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		ci.draw_line(canvas + d * (r + 2.0), canvas + d * (r + 2.0 + TargetGuide.TICK_LEN), Color(TargetGuide.RIM, alpha * 0.6), TargetGuide.RING_WIDTH + 2.0, true)
		ci.draw_line(canvas + d * (r + 2.0), canvas + d * (r + 2.0 + TargetGuide.TICK_LEN), Color(TargetGuide.INK, ink), TargetGuide.RING_WIDTH, true)
	if TargetGuide.near(dist_m):
		outline(frame, ci, TargetGuide.target_metre(at), alpha, ink, breath)
	var cut: Rect2 = TargetGuide.cut_metre(o, at)
	if cut.size != Vector2.ZERO:
		outline(frame, ci, cut, alpha, ink, breath)
	# THE RING SAYS WHICH THING (D0499, stranger 79 stood inside the seam's ring and strode past): one word
	# under it, in this ink, laid out by `RingWord` -- and which side of the drop's line (D0521).
	RingWord.draw_under(ci, frame, id, at, canvas, r, alpha, reached)


## THE REACH LINE (D0557): the ground the body's CENTRE has to be standing inside, drawn as a circle the
## player walks into. Only while the ringed target is a machine and the body is OUT of reach -- once it is
## in, the line has said everything it had to say and the ring's own solid rim, fill and "· IN REACH" word
## (D0521) are the state.
##
## D0521 gave the ring two states and strangers still could not read them. Three of them, in three
## batches, said the same thing in their own words: S111 "the game showed me I was always too far but
## never showed me WHERE close enough was"; S128 that a body length "gave no clear feedback about what
## distance that actually represented"; S132 "the white ring marker shows the target exists, but all
## attempts resulted in TOO FAR". Every one of those is the same complaint, and it is not about the
## refusal -- it is that a state tells you which side of a line you are on and never where the line IS.
## So the line is drawn. `Reach.NUM/DEN` metres from the metre's centre, which is the locus of
## `in_reach` above and therefore cannot disagree with the drop by construction.
##
## DASHED AND UNBREATHING, deliberately. The ring breathes because it is asking to be looked at; this is
## a fact about the floor and a second pulsing circle would read as a second target. Half the ring's ink,
## so it sits behind the thing it is about.
const REACH_DASHES: int = 28
const REACH_DUTY: float = 0.55        ## of each dash's arc drawn, the rest gap
const REACH_INK: float = 0.42         ## of the guide's alpha: a floor marking, not a target
## THE LAST LINE DRAWN, for a suite to read off the real pass rather than restate the layout (the idiom
## `RingWord.last_drawn` sets). Written by the draw, never by a caller.
static var last_reach_line: Dictionary = {}


## THE LINE'S RADIUS IN METRES, and the SAME number `in_reach` compares against -- `Reach.NUM/DEN` from
## the metre's centre. Named rather than inlined so a suite can assert the drawn circle IS the locus of
## the rule (a body a hair inside it is in reach, a hair outside is not) instead of asserting that some
## circle was drawn at some radius that happens to look right.
static func reach_radius_m() -> float:
	return float(Reach.NUM) / float(Reach.DEN)


## THE LOCUS OF THE RULE THIS TARGET IS UNDER, drawn as a dashed round-cornered outline: the places the
## body's CENTRE may stand and still work this target.
##
## TWO TARGETS, TWO LOCI, AND THE SHAPE SAYS WHICH (D0560). A machine is addressed by its METRE
## (`Reach.in_reach_metre`, one point), so its locus is a circle. Rock is addressed by the TERRAIN CELL
## the pointer lands on (`Mining.in_reach` -> `Aim.in_reach_point` over `_cell_center_fx`) and a metre
## holds 4x4 of them, so its locus is the box those cell centres span, inflated by the radius: a rounded
## rectangle, about 0.37 m wider on each axis than the circle. Drawing the circle for rock would be
## conservative rather than over-promising, and would still be a shape that is not the rule -- and the
## whole argument for drawing this line is that a line which is only about right teaches a distance the
## game then refuses. ONE PATH COVERS BOTH: for a machine `inner` is empty and the rounded rectangle
## closes into exactly the circle D0557 drew.
##
## S130 IS WHY ROCK IS HERE. It stood at the ringed coal seam, was refused, wrote "my reach is about a
## body length" -- the game's own words, from the drop lesson -- stepped closer, was refused again, and
## walked back to the forge without coal, in 41 bursts. Reach is 3.2 m, and a cell target was the thing
## it was standing at.
static func reach_line(frame: Frame, ci: CanvasItem, id: StringName, at: Vector2, alpha: float) -> void:
	var o: Interface.Observation = frame.obs
	if o == null or at == TargetGuide.NONE:
		return
	var radius: float = reach_radius_m() * TargetGuide.o_px_per_m(frame)
	var inner: Rect2 = inner_of(frame, o, id, at)
	if radius <= 0.0 or not Rect2(Vector2.ZERO, UiTheme.CANVAS).intersects(inner.grow(radius)):
		return
	var ink := Color(TargetGuide.INK, alpha * REACH_INK)
	var rim := Color(TargetGuide.RIM, alpha * REACH_INK * 0.6)
	_dash_round_rect(ci, inner, radius, ink, rim)
	last_reach_line = {"cell": RingWord.metre_of(at), "inner": inner, "radius": radius}


## The points the rule measures TO, in canvas pixels. A machine's is its metre's CENTRE -- an empty rect,
## so the outline closes into a circle. Rock's is the box its terrain-cell centres span, which is the
## metre inset by half a terrain cell on every side.
static func inner_of(frame: Frame, o: Interface.Observation, id: StringName, at: Vector2) -> Rect2:
	var m: float = float(Interface.Units.LOGIC_PX)
	var cell: Vector2i = RingWord.metre_of(at)
	if RingWord.metre_target(id, o, at):
		return Rect2(frame.canvas_of((Vector2(cell) + Vector2(0.5, 0.5)) * m), Vector2.ZERO)
	var half: float = float(Interface.Units.CELL_PX) * 0.5
	var lo: Vector2 = frame.canvas_of(Vector2(cell) * m + Vector2(half, half))
	var hi: Vector2 = frame.canvas_of(Vector2(cell + Vector2i.ONE) * m - Vector2(half, half))
	return Rect2(lo, hi - lo)


## `inner` inflated by `radius`, dashed: four quarter arcs at its corners and four straight sides. Each
## piece is dashed on its own at a shared pitch rather than one dash pattern wrapped around the whole
## perimeter -- wrapping would land the dashes differently on a circle than on a rectangle, and the two
## shapes have to read as one family.
static func _dash_round_rect(ci: CanvasItem, inner: Rect2, radius: float, ink: Color, rim: Color) -> void:
	var quarter: float = TAU * 0.25
	var per: int = maxi(2, REACH_DASHES / 4)
	var corners: Array[Vector2] = [inner.end, Vector2(inner.position.x, inner.end.y), inner.position,
		Vector2(inner.end.x, inner.position.y)]
	for i: int in 4:
		for d: int in per:
			var a0: float = quarter * float(i) + quarter * float(d) / float(per)
			var a1: float = a0 + quarter / float(per) * REACH_DUTY
			ci.draw_arc(corners[i], radius, a0, a1, 3, rim, TargetGuide.RING_WIDTH + 1.0, true)
			ci.draw_arc(corners[i], radius, a0, a1, 3, ink, TargetGuide.RING_WIDTH - 0.5, true)
	var out: Rect2 = inner.grow(radius)
	var pitch: float = quarter * radius / float(per)
	_dash_line(ci, Vector2(inner.position.x, out.end.y), Vector2(inner.end.x, out.end.y), pitch, ink, rim)
	_dash_line(ci, Vector2(inner.position.x, out.position.y), Vector2(inner.end.x, out.position.y), pitch, ink, rim)
	_dash_line(ci, Vector2(out.position.x, inner.position.y), Vector2(out.position.x, inner.end.y), pitch, ink, rim)
	_dash_line(ci, Vector2(out.end.x, inner.position.y), Vector2(out.end.x, inner.end.y), pitch, ink, rim)


## One dashed straight run, at the pitch the arcs use so the outline reads as one line. A zero-length
## side (the machine case, where `inner` is a point) draws nothing.
static func _dash_line(ci: CanvasItem, a: Vector2, b: Vector2, pitch: float, ink: Color, rim: Color) -> void:
	var span: float = a.distance_to(b)
	if span <= 0.0:
		return
	var n: int = maxi(1, int(round(span / maxf(pitch, 1.0))))
	for i: int in n:
		var p0: Vector2 = a.lerp(b, float(i) / float(n))
		var p1: Vector2 = a.lerp(b, (float(i) + REACH_DUTY) / float(n))
		ci.draw_line(p0, p1, rim, TargetGuide.RING_WIDTH + 1.0, true)
		ci.draw_line(p0, p1, ink, TargetGuide.RING_WIDTH - 0.5, true)


## IS THE BODY INSIDE THIS TARGET'S OWN LOCUS? The reach line's gate, and it is NOT `reached` above:
## `reached` also asks `metre_target`, so it is false for every cell target whatever the distance, and a
## line gated on it would draw on rock the body is standing on top of. A machine is measured to its
## metre's centre; rock to the nearest of its terrain-cell centres, which is the nearest point of the
## same `inner` box the line is drawn around -- so the gate and the drawing cannot disagree about which
## rule they are under. `[[guard-causes-what-it-bounds]]` in reverse: the guard reads the same geometry.
static func within_reach(o: Interface.Observation, id: StringName, at: Vector2) -> bool:
	if RingWord.metre_target(id, o, at):
		return in_reach(o, at)
	var m: int = Interface.Units.LOGIC_PX
	var half: int = Interface.Units.CELL_PX / 2
	var cell: Vector2i = RingWord.metre_of(at)
	var lo := Vector2(cell * m + Vector2i(half, half))
	var hi := Vector2((cell + Vector2i.ONE) * m - Vector2i(half, half))
	var body := Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)
	var near: Vector2 = body.clamp(lo, hi)
	return Reach.in_reach(o.pos_x, o.pos_y, int(round(near.x)) * Fx.SCALE, int(round(near.y)) * Fx.SCALE, m)


## THE DROP'S OWN RULE: the body's centre (`pos_x`/`pos_y`, the observation's `Fx` copy of `Body`'s) to the
## ringed metre's centre, through `Reach.in_reach_metre` -- the same call `Verbs.can_reach` makes on the
## sim side via `Aim.in_reach_logic`, with the same inputs, so the ring and the drop cannot disagree.
static func in_reach(o: Interface.Observation, at: Vector2) -> bool:
	return Reach.in_reach_metre(o.pos_x, o.pos_y, RingWord.metre_of(at), Interface.Units.LOGIC_PX)


## The target's metre, or the metre to cut, drawn as the one white square with its rim.
static func outline(frame: Frame, ci: CanvasItem, metre: Rect2, alpha: float, ink: float, breath: float) -> void:
	var rect := Rect2(frame.canvas_of(metre.position), frame.canvas_of(metre.end) - frame.canvas_of(metre.position))
	ci.draw_rect(rect, Color(TargetGuide.INK, alpha * TargetGuide.NEAR_FILL * breath))
	ci.draw_rect(rect.grow(1.0), Color(TargetGuide.RIM, alpha * 0.6), false, TargetGuide.RING_WIDTH + 2.0)
	ci.draw_rect(rect, Color(TargetGuide.INK, ink), false, TargetGuide.RING_WIDTH)
