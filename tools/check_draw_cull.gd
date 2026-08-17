extends SceneTree

## WHAT YOU CANNOT SEE MUST NOT COST ANYTHING — AND WHAT YOU CAN SEE MUST NOT VANISH.
##
## The falling-drop layer paints about ten primitives per drop — five trail rects, a landing ring, a
## motion smear and three body rects — and MAX_ITEMS is 240. Unculled, a pour costs the frame ~2400 draw
## calls whether or not a single one of them is on screen, and the common case is the bad one: a factory
## left running upstairs while you mine somewhere else produces drops nobody is looking at.
##
## So drops are culled by their FLIGHT BOX. That is the interesting part, and it is why this layer exists
## rather than a comment saying "culled":
##
##   AN ENDPOINT TEST IS WRONG.  A drop tossed clean across the view has both ends outside it and every
##                               frame of its flight inside. Culling on `from` or `to` deletes exactly the
##                               drops that cross the screen — the most visible ones there are.
##   A STRAIGHT-LINE BOX IS WRONG. The arc BOWS upward, and the bow grows with the toss distance, so a
##                               long throw along the bottom edge of the view rises INTO it while both
##                               ends and the whole straight line stay below. `_bow()` is shared between
##                               the sampler and the box for this reason; if they ever drift, drops
##                               disappear at the top of wide machine spacings and nowhere else.
##
## Both wrong versions pass a naive "off-screen items aren't drawn" test. Both are checked below.
##
## The Spy subclass overrides the per-drop painter, so draw() runs its real control flow — the same cull,
## the same loop — while making no canvas calls at all. That is what lets this run headless with no window
## and still be about drawing.
##
##   godot --headless --path . --script res://tools/check_draw_cull.gd

## A 1000x1000 view at the origin. Every coordinate below is chosen against these bounds.
const VIEW: Rect2 = Rect2(0.0, 0.0, 1000.0, 1000.0)

var _fails: int = 0


class Spy extends FallingItems:
	var drawn: int = 0

	func _draw_item(_canvas: CanvasItem, _f: Dictionary) -> void:
		drawn += 1


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS: %s" % label)
	else:
		_fails += 1
		printerr("  FAIL: %s" % label)


## How many of the given drops draw against VIEW. Each call gets a fresh layer so counts never carry.
func _drawn(drops: Array) -> int:
	var spy := Spy.new()
	for d: Array in drops:
		spy.inject(d[0], d[1], Color.WHITE, float(d[2]))
	spy.draw(null, VIEW)
	return spy.drawn


func _initialize() -> void:
	print("== what you cannot see must not cost anything ==")

	# --- the control. Without this, every "is not drawn" below passes on a layer that draws nothing. ---
	_check(_drawn([[Vector2(500, 400), Vector2(500, 600), 0.5]]) == 1,
		"a drop in plain view is drawn (the control — without it the whole file is vacuous)")

	# --- the point of the cull ---
	_check(_drawn([[Vector2(9000, 9000), Vector2(9000, 9200), 0.5]]) == 0,
		"a drop falling far off-screen is not drawn at all")

	# --- ...and the two ways of getting the cull wrong ---
	# Both ends outside the view on opposite sides; the entire flight crosses the middle of the screen.
	_check(_drawn([[Vector2(-400, 500), Vector2(1400, 500), 0.5]]) == 1,
		"a drop tossed ACROSS the view is drawn, though neither of its endpoints is inside it")
	# Along the bottom edge, below the view: the straight line never enters, but the launch bow lifts the
	# arc up into it. bow = 10 + 600*0.28 = 178, so the arc peaks ~178px above a line at y=1100.
	_check(_drawn([[Vector2(200, 1100), Vector2(800, 1100), 0.5]]) == 1,
		"a long toss BELOW the view is drawn, because its bow carries the arc up into it")
	# The same geometry with a short toss genuinely stays out: bow = 10 + 20*0.28 = 15.6, nowhere near.
	_check(_drawn([[Vector2(200, 1400), Vector2(220, 1400), 0.5]]) == 0,
		"...while a short toss at the same depth stays out, so the bow allowance is not just a big margin")

	# --- the cull is stable across the flight, not a function of where the drop is this instant ---
	# The trail lags the head by five samples and the landing ring expands around `to`, so a drop must
	# draw for its WHOLE flight or its tail would be clipped after the head left the view.
	var crossing: Array = [[Vector2(-400, 500), Vector2(1400, 500), 0.0]]
	var same: bool = true
	for step: int in 11:
		crossing[0][2] = float(step) * 0.1
		if _drawn(crossing) != 1:
			same = false
	_check(same, "...and it draws at every point of that flight — the decision cannot flicker frame to frame")

	# --- many drops, mixed ---
	var mixed: Array = [
		[Vector2(500, 400), Vector2(500, 600), 0.5],        # in
		[Vector2(120, 200), Vector2(120, 400), 0.5],        # in
		[Vector2(9000, 9000), Vector2(9000, 9200), 0.5],    # out
		[Vector2(-9000, 500), Vector2(-9000, 700), 0.5],    # out
		[Vector2(500, -9000), Vector2(500, -8800), 0.5],    # out
	]
	_check(_drawn(mixed) == 2, "in a mixed pour only the visible drops cost anything (2 of 5)")

	# --- and the cap still holds, so the worst case is bounded ---
	var flood: Array = []
	for i: int in 400:
		flood.append([Vector2(9000, 9000), Vector2(9000, 9200), 0.5])
	_check(_drawn(flood) == 0, "400 off-screen drops cost nothing (and MAX_ITEMS caps the list at 240)")

	if _fails == 0:
		print("check_draw_cull: PASS — off-screen drops are free, and on-screen ones still arrive")
		quit(0)
	else:
		printerr("check_draw_cull: FAIL (%d)" % _fails)
		quit(1)
