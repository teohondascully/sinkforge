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
	var dist_m: float = body.distance_to(at) / float(Interface.Observation.LOGIC_PX)
	var r: float = TargetGuide.ring_m(dist_m) * TargetGuide.o_px_per_m(frame) * (0.92 + 0.08 * breath)
	var ink: float = alpha * (0.55 + 0.4 * breath)
	if reached:
		ci.draw_circle(canvas, r, Color(TargetGuide.INK, alpha * TargetGuide.NEAR_FILL))
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


## THE DROP'S OWN RULE: the body's centre (`pos_x`/`pos_y`, the observation's `Fx` copy of `Body`'s) to the
## ringed metre's centre, through `Reach.in_reach_metre` -- the same call `Verbs.can_reach` makes on the
## sim side via `Aim.in_reach_logic`, with the same inputs, so the ring and the drop cannot disagree.
static func in_reach(o: Interface.Observation, at: Vector2) -> bool:
	return Reach.in_reach_metre(o.pos_x, o.pos_y, RingWord.metre_of(at), Interface.Observation.LOGIC_PX)


## The target's metre, or the metre to cut, drawn as the one white square with its rim.
static func outline(frame: Frame, ci: CanvasItem, metre: Rect2, alpha: float, ink: float, breath: float) -> void:
	var rect := Rect2(frame.canvas_of(metre.position), frame.canvas_of(metre.end) - frame.canvas_of(metre.position))
	ci.draw_rect(rect, Color(TargetGuide.INK, alpha * TargetGuide.NEAR_FILL * breath))
	ci.draw_rect(rect.grow(1.0), Color(TargetGuide.RIM, alpha * 0.6), false, TargetGuide.RING_WIDTH + 2.0)
	ci.draw_rect(rect, Color(TargetGuide.INK, ink), false, TargetGuide.RING_WIDTH)
