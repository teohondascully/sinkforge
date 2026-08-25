class_name RopeView
extends RefCounted
## THE LINE, AND EVERYTHING DRAWN ALONG IT: the live grapple cord with its slack bow, the hook at its end,
## the aim ghost that shows where the hook would touch, and the placed climb-ropes hanging down their own
## shafts. Extracted from `world_renderer.gd` along a seam that was measured before it was cut.
##
## WHY THIS BLOCK. The two seams cut before this one were found by reading the file. This one was found by
## an instrument, run over every candidate the file still had, ranked by the size of the interface that
## survives the move -- outbound calls the block still needs, entry points the parent keeps, and fields it
## reaches across for:
##
##     candidate              lines   out   in   fields   BOTH   crossings   per 100 lines
##     water (cut)              220     1    3        3      0           7             3.2
##     crystal seams             96     2    1        4      1           7             7.3
##     rope + grapple           119     2    2        4      0           8             6.7
##     surface life + flora      97     2    3        4      1           9             9.3
##     conduits + power          96     3    4        4      1          11            11.5
##     machines (cut)           460     1    4       11      0          16             3.5
##     ore + lode + grain       259     4    5        8      1          17             6.6
##     aim + build previews     298     5    2       12      0          19             6.4
##     terrain bake             101     2    6       12      1          20            19.8
##     mining tells             110     5    5       11      0          21            19.1
##     veil                     269     6    1       17      2          24             8.9
##
## READ THE COUNT, NOT THE RATE. Sorted by crossings-per-line this block ranks fourth and `machines`, which
## was cut first, ranks second-best of everything -- because the rate divides by the size of the thing being
## moved and so pays a candidate for being large. What you maintain afterwards is the count. Sorted by the
## count, the ordering is the one above, and it puts the two blocks already cut at opposite ends.
##
## `veil` is the control on that reading. It is the largest candidate left, so a size-flattering metric
## should favour it, and it finishes last on both: 24 crossings, 17 fields, and two dirty-flags written on
## BOTH sides of the line. A ranking biased toward size that still rejects the biggest candidate is
## rejecting it on something the bias cannot explain.
##
## Of the candidates not yet cut, this one has the narrowest interface with no shared write. `crystal seams`
## ties it at seven crossings and loses on that axis -- it writes its own validity flag on both sides -- and
## at 96 lines it is a cache that is already private in everything but file position.
##
## WHAT MOVES. Six functions; `_draw_aim_ghost` is here because its only caller is `_draw_grapple` -- the
## ghost is the grapple's own targeting preview, and the `aim` in its name is about where the hook lands,
## not about the build cursor. Fourteen constants and one switch come with it because nothing else drew
## with them. Crossing the line afterwards: `_view_world_rect` and the static `rope_sag`, three renderer
## fields (`_anim_time`, `player`, `sim`), `WorldRenderer.CELL`, and three CanvasItem draw calls via `_wr`.
##
## TWO THINGS THE MEASUREMENT GOT WRONG, both found by the compiler rather than by the scan:
##
##   static func   the instrument collected `^func` and not `^static func`, so `rope_sag` was invisible and
##                 this block was scored at seven crossings, tying water, when it costs eight. The same
##                 instrument missed `static var` on an earlier slice. A declaration form that a scan does
##                 not enumerate does not read as a gap in the output; it reads as a better result.
##   one-file scan   the check that says a constant is safe to move reads `world_renderer.gd` and nothing
##                 else, and reported all fifteen unused elsewhere. `CORD_CORE_W` and `ROPE_CORE` are read
##                 by a check layer outside that corpus. They moved anyway, with the call sites updated to
##                 name this class, but "is this referenced anywhere" was only ever answering "in the files
##                 I read".

var _wr: WorldRenderer


func _init(renderer: WorldRenderer) -> void:
	_wr = renderer


## Draw the placed ropes. Each cell is a taut hemp line down the middle with rung knots every few px, a hitch
## loop on the top (anchor) cell and a loose frayed tail on the bottom one, so a roped shaft reads as
## climbable against the dark. Sways gently on the cosmetic clock, like a hung line.
func _draw_ropes() -> void:
	const HEMP := Color(0.76, 0.63, 0.42)
	const SHADE := Color(0.42, 0.33, 0.20)
	var view: Rect2 = _wr._view_world_rect(2.0)
	for cell: Variant in _wr.sim.rope:
		var c: Vector2i = cell
		if not view.has_point(Vector2(c) * float(WorldRenderer.CELL)):
			continue
		var x: float = float(c.x * WorldRenderer.CELL) + float(WorldRenderer.CELL) * 0.5
		var top := Vector2(x, float(c.y * WorldRenderer.CELL))
		var sway: float = sin(_wr._anim_time * 1.6 + float(c.y) * 0.7) * 0.8
		var is_anchor: bool = not _wr.sim.rope.has(c + Vector2i(0, -1))
		var is_tail: bool = not _wr.sim.rope.has(c + Vector2i(0, 1))
		var bot := Vector2(x + sway, float((c.y + 1) * WorldRenderer.CELL))
		_wr.draw_line(top + Vector2(1.2, 0), bot + Vector2(1.2, 0), SHADE, 2.6)         # back shade reads as depth
		_wr.draw_line(top, bot, HEMP, 1.8)
		for k: int in 3:                                                             # rung knots
			var ky: float = float(c.y * WorldRenderer.CELL) + 5.0 + float(k) * 10.5
			_wr.draw_line(Vector2(x - 3.0, ky), Vector2(x + 3.0, ky), HEMP.darkened(0.15), 2.0)
		if is_anchor:
			_wr.draw_arc(top + Vector2(0.0, 3.0), 3.2, 0.0, TAU, 10, HEMP, 2.0)          # the hitch loop
		if is_tail:
			_wr.draw_line(bot, bot + Vector2(sway * 2.0, -5.0), HEMP.darkened(0.1), 1.6)  # frayed tail curl


## The line, drawn as a chain of short segments along a quadratic bow rather than as one straight line, so
## slack reads as rope: a line the body has swung inside of sags, a line the body is hanging on snaps
## bar-straight, and which one you are on is visible without reading a speed. The hook is a small dark wedge
## at the anchor with a bright chip on its lit side, because a hook that reads as a dot makes the whole tool
## read as a laser pointer.
const ROPE_SEGMENTS: int = 14


## The widest stroke the cord is drawn with, the dark under-stroke. NAMED because a fixture measuring the
## hang measures the cord's OUTER EDGE, which stands half of this off the centreline the sag describes.
## Two files agreeing on 4.5 by both writing 4.5 is a pair no assertion can fail on.
const CORD_W: float = 4.5


## The FIBRE stroke, laid over the under-stroke. Named for the same reason and one more: a fixture masking
## the cord by colour matches `ROPE_CORE`, which is only ever drawn this wide, so this is the width that
## sets how far a found pixel can sit from the centreline. `CORD_W` is the wrong one to subtract.
const CORD_CORE_W: float = 2.0


const ROPE_CORE := Color(0.78, 0.70, 0.52)


const ROPE_SHADE := Color(0.20, 0.16, 0.12)


## The aiming ghost: where the hook would bite if thrown now, as a marker plus the faint lead it sits on the
## end of. The rope is the traversal verb, and without this it fires blind: whether the range is there, and
## whether anything is in the way, are only answered after the throw. Every other reaching tool shows its
## target: the pick has its aim box, the builder its ghost.
##
## Drawn quietly: a thin dotted lead and a small ring, nothing that competes with the ore glint or the crack
## overlay. Drawn only when the line is stowed, because once you are on the rope the attention belongs on
## the arc and a second line racing the cursor across the rock is noise.
##
## The lead is a stub rather than a line. Drawn hand to target at even spacing, `check_grapple_reads`
## measured the preview inking 0.96 of the throw, which is a dimension line: how a CAD package indicates a
## distance and how a debug build draws a raycast. What the preview is for is the endpoint, and that
## information is entirely in the ring; the lead only has to say which throw the ring belongs to, which
## takes a stub off the hand rather than a tether. The trace is unchanged, so acquisition is exactly as
## reliable as before.
const AIM_STUB: float = 0.26            ## how much of the throw the lead draws before it lets go


const AIM_STUB_MAX: float = 74.0        ## ...and never more than this many px, so a long throw stays a stub


const AIM_DOTS: int = 4


const AIM_RING: float = 6.0


const AIM_LEAD := Color(0.86, 0.80, 0.62, 0.34)


const AIM_MARK := Color(0.99, 0.88, 0.56, 0.88)


const AIM_MISS := Color(0.62, 0.64, 0.70, 0.16)   ## nothing in range: the lead fades out and there is no ring


## A dark backing ring, so the mark survives pale rock. What the halo buys is survival against a background
## as pale as the mark itself; against sky it is a cost, because a near-black stroke over a pale sky is the
## highest-contrast edge in the frame. Measured on the surface with the guidance quiet and the shot aimed
## over open sky, the preview added 207 levels of local gradient at its brightest tenth, against the miner's
## own silhouette step of 87, and nearly all of it was this ring. AIM_SHADE_W is what was pulled in; the ring
## is a distinctive shape and does not need a wide black halo to be found. Acquisition is untouched, since
## the trace, the ring's position and its radius are all unchanged.
const AIM_SHADE := Color(0.06, 0.05, 0.04, 0.55)


const AIM_SHADE_W: float = 3.0


## `SF_AIM_GHOST_OFF=1` suppresses the aim preview so it can be photographed by subtraction.
## `check_grapple_reads` isolates the preview by differencing two otherwise identical frames. Getting the
## reference frame by parking the cursor on the miner's own hand also swings the head-lamp, because the lamp
## is aimed: five and a half cells of light moved between the two captures and the difference mask ate it.
## Excluding a lamp-sized disc then blinds the check to the near field, which is the only place the
## shortened lead lives, and it measured 0.04 of the throw inked while seeing the endpoint ring alone.
##
## With this flag the reference frame has the cursor in exactly the same place and the lamp in exactly the
## same position, so the difference is the preview and nothing else.
static var AIM_GHOST_OFF: bool = OS.get_environment("SF_AIM_GHOST_OFF") == "1"


func _draw_aim_ghost() -> void:
	if _wr.player == null or _wr.player.grapple.live() or _wr.sim == null or AIM_GHOST_OFF:
		return
	var from: Vector2 = _wr.player.hand()
	var shot: Dictionary = _wr.player.grapple.trace(_wr.sim, from, Controls.pointer_world(_wr))
	var to: Vector2 = shot["at"]
	var hit: bool = shot["hit"]
	# A dotted lead rather than a solid one, because a solid line reads as a rope that is already there. It
	# runs a fraction of the way rather than all of it: the stub says which throw, the ring says where it
	# lands, and nothing in between needs drawing.
	var full: float = from.distance_to(to)
	var stub: float = minf(full * AIM_STUB, AIM_STUB_MAX) / maxf(full, 1.0)
	for i: int in AIM_DOTS:
		var t0: float = stub * float(i) / float(AIM_DOTS)
		var t1: float = t0 + stub * 0.5 / float(AIM_DOTS)
		# The stub fades out along its length in both cases, so it reads as a throw leaving the hand rather
		# than as a measurement between two points.
		var fade: float = 1.0 - 0.65 * float(i) / float(AIM_DOTS)
		if not hit:
			fade *= 0.6                                       # nothing in range: quieter still, and no ring
		_wr.draw_line(from.lerp(to, t0), from.lerp(to, t1),
			(AIM_LEAD if hit else AIM_MISS) * Color(1, 1, 1, fade), 1.0)
	if hit:
		# One ring, and nothing inside it. The dot that used to sit at the centre marked the point the ring
		# already marks, and a ring with a mark in the middle of it is a selection reticle. That is what the
		# cursor's own square is being, on the same rock a few pixels away, every time the throw lands
		# somewhere you could also swing at. Position, radius and backing stroke are all untouched, so the
		# endpoint is exactly as findable as it was; there is simply one mark on it rather than two.
		_wr.draw_arc(to, AIM_RING, 0.0, TAU, 16, AIM_SHADE, AIM_SHADE_W)
		_wr.draw_arc(to, AIM_RING, 0.0, TAU, 16, AIM_MARK, 1.5)


func _draw_grapple() -> void:
	_draw_aim_ghost()
	if _wr.player == null or not _wr.player.grapple.live():
		return
	var g: Grapple = _wr.player.grapple
	var from: Vector2 = _wr.player.hand()
	# A chained throw draws both: the line still carrying the body, and the hook already on its way to the
	# next one. Seeing them overlap for those few frames is what says chaining never lets go of anything.
	if g.state == Grapple.State.ANCHORED:
		# A wrapped line is drawn as what it is: bar-taut around every corner it has caught on, and hanging
		# only on the last segment. Drawing the whole thing as one chord to the hook would put rope straight
		# through the rock it is wrapped around, which is the lie the wrap exists to end.
		var at: Vector2 = g.anchor
		for pivot: Vector2 in g.pivots:
			_draw_cord(at, pivot, 0.0)
			at = pivot
		_draw_cord(from, at, WorldRenderer.rope_sag(from.distance_to(at), g.slack(from)))
		# The piton belongs at the hook and nowhere else, pointed back down the first span of line.
		_draw_hook(g.pivots[0] if not g.pivots.is_empty() else from, g.anchor, 0.0)
	if g.throwing():
		_draw_rope(from, g.tip, 0.0)


## One line, bowed by `sag`, with its hook on the end.
func _draw_rope(from: Vector2, to: Vector2, sag: float) -> void:
	_draw_cord(from, to, sag)
	_draw_hook(from, to, sag)


## Just the cord, with no hook. Split out because a wrapped line is several spans and only one of them ends
## at the hook; drawing the whole polyline with _draw_rope sprouts a piton at every corner it caught on.
func _draw_cord(from: Vector2, to: Vector2, sag: float) -> void:
	var pts := PackedVector2Array()
	for i: int in ROPE_SEGMENTS + 1:
		var t: float = float(i) / float(ROPE_SEGMENTS)
		var p: Vector2 = from.lerp(to, t)
		p.y += sin(t * PI) * sag                     # a parabola is close enough to a catenary at this size
		pts.append(p)
	# Two passes: a dark under-stroke that gives the rope an edge against light rock, then the fibre.
	for i: int in ROPE_SEGMENTS:
		_wr.draw_line(pts[i], pts[i + 1], ROPE_SHADE, CORD_W)
	for i: int in ROPE_SEGMENTS:
		_wr.draw_line(pts[i], pts[i + 1], ROPE_CORE, CORD_CORE_W)
	# A twist highlight every other segment: at this scale, whether the line reads as rope or as a laser is
	# entirely whether it has any internal structure at all.
	for i: int in ROPE_SEGMENTS:
		if i % 2 == 0:
			_wr.draw_line(pts[i], pts[i].lerp(pts[i + 1], 0.55), ROPE_CORE.lightened(0.35), 1.0)


## The hook: a wedge biting into the rock, oriented along the line's last segment so it always looks planted.
func _draw_hook(from: Vector2, to: Vector2, sag: float) -> void:
	var pts := PackedVector2Array()
	for i: int in ROPE_SEGMENTS + 1:
		var t: float = float(i) / float(ROPE_SEGMENTS)
		var p: Vector2 = from.lerp(to, t)
		p.y += sin(t * PI) * sag
		pts.append(p)
	var dir: Vector2 = (pts[ROPE_SEGMENTS] - pts[ROPE_SEGMENTS - 1]).normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var head: Vector2 = to + dir * 3.0
	_wr.draw_colored_polygon(PackedVector2Array([
		head, head - dir * 9.0 + side * 5.0, head - dir * 6.0, head - dir * 9.0 - side * 5.0]),
		ROPE_SHADE.lightened(0.22))
	_wr.draw_line(head - dir * 8.0 + side * 3.0, head - dir * 2.0, Color(0.92, 0.86, 0.70), 1.0)