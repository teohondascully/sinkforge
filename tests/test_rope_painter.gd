extends "res://tests/test_base.gd"

## `view/visuals/rope_painter.gd` (A' step 5d, D0361), structural. WHAT THIS CANNOT DO, said first: it
## cannot judge whether the rope LOOKS like rope; that is the director's eye at the play scene. What it
## guards is the failure the painter would fail silently -- a sag that bows the wrong way or not at all, a
## hook wedge pointing away from the rock, a ghost lead that inks the whole throw, a paint pass that
## trips on a member the observation no longer has -- (the carry look that stood here left with D0407: nothing consumed it).

const S: int = Fx.SCALE


func _initialize() -> void:
	_test_the_sag_bows_down_bounded_and_monotone()
	_test_the_cord_and_the_hook()
	_test_the_ghost_is_a_stub()
	await _test_paint_runs_against_a_real_frame_with_a_live_line()
	_finish("rope_painter")


func _test_the_sag_bows_down_bounded_and_monotone() -> void:
	_check(RopePainter.rope_sag(100.0, 0.0) == RopePainter.SAG_MIN, "bar-taut keeps a whisker of curve (SAG_MIN)")
	var prev: float = 0.0
	var monotone: bool = true
	for i: int in 20:
		var s: float = RopePainter.rope_sag(100.0, float(i) / 20.0)
		if s < prev:
			monotone = false
		prev = s
	_check(monotone, "more slack, more sag, never less")
	_check(RopePainter.rope_sag(100.0, 1.0) <= 100.0 * RopePainter.SAG_CAP + 0.001, "a fully slack line bows at most SAG_CAP of its chord")
	_check(RopePainter.rope_sag(300.0, 0.5) > RopePainter.rope_sag(100.0, 0.5), "a longer chord hangs deeper at the same slack")


func _test_the_cord_and_the_hook() -> void:
	var from := Vector2(0.0, 0.0)
	var to := Vector2(100.0, 0.0)
	var pts: PackedVector2Array = RopePainter.cord_points(from, to, 10.0)
	_check(pts.size() == RopePainter.ROPE_SEGMENTS + 1 and pts[0].is_equal_approx(from) and pts[pts.size() - 1].is_equal_approx(to),
		"the cord runs end to end in ROPE_SEGMENTS pieces")
	_check(absf(pts[RopePainter.ROPE_SEGMENTS / 2].y - 10.0) < 0.01, "...and its middle hangs DOWN by the sag (+y)")
	_check(RopePainter.cord_points(from, to, 0.0)[7].y == 0.0, "a taut cord is straight")
	var wedge: PackedVector2Array = RopePainter.hook_polygon(RopePainter.cord_points(from, to, 0.0))
	_check(wedge.size() == 4 and wedge[0].x > to.x, "the hook's head bites PAST the anchor, along the line")
	_check(wedge[1].x < wedge[0].x and wedge[3].x < wedge[0].x and wedge[1].y != wedge[3].y,
		"...and its barbs trail back toward the body on both sides")
	var up: PackedVector2Array = RopePainter.hook_polygon(RopePainter.cord_points(Vector2(0, 100), Vector2(0, 0), 0.0))
	_check(up[0].y < 0.0, "thrown upward, the head points up")


func _test_the_ghost_is_a_stub() -> void:
	_check(absf(RopePainter.stub_fraction(100.0) - RopePainter.AIM_STUB) < 0.001, "a short throw's lead is AIM_STUB of it")
	_check(RopePainter.stub_fraction(1000.0) * 1000.0 <= RopePainter.AIM_STUB_MAX + 0.001, "a long throw's lead never exceeds AIM_STUB_MAX px")
	_check(RopePainter.stub_fraction(0.0) == 0.0, "no throw, no lead")


## IT MUST GO THROUGH A REAL REDRAW (`tests/test_sky_painter.gd` has the reason): a direct `_draw()` is
## refused by the engine as an ERROR that does not stop execution. The line is thrown and anchored
## through the door first, so the anchored branch, the hook and the placed-rope branch all execute.
func _test_paint_runs_against_a_real_frame_with_a_live_line() -> void:
	var grid: TileGrid = TileGrid.new(80, 80, 1)
	for col: int in range(80):
		for row: int in range(80):
			if row < 10 or row >= 60:
				grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(160), Fx.from_int(60 * 4 - 20))
	var door: Interface = Interface.new(grid, body, Mining.new())
	PlacedVerbs.place_rope(door.services()["world"], Vector2i(5, 6), 6)
	for _i: int in 10:
		door.apply(Command.move(_input()))
	var t: InputFrame = _input()
	t.grapple_pressed = true
	t.has_aim = true
	t.aim_col = 40
	t.aim_row = 9
	door.apply(Command.move(t))
	for _i: int in 20:
		door.apply(Command.move(_input()))
	var o: Interface.Observation = door.observe(Interface.Envelope.new(Rect2i(0, 0, 80, 80)))
	_check(o.grapple_live and o.grapple_anchored and not o.grapple_throwing, "the line is anchored before the paint (state %d)" % o.grapple_state)
	_check(o.pack_total() == 0, "control: an empty pack totals zero")
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var ran: Array = [0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		RopePainter.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint() ran to completion inside a real draw pass with a live line and placed ropes (%d)" % int(ran[0]))
	view.queue_free()
