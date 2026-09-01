extends "res://tests/test_base.gd"

## `view/visuals/wall_painter.gd` — the background wall plane, drawn (D0286, LEGACY_GAP T1 #3).
##
## The suite is about the two things legacy says this plane exists to do, both of which are measurements
## rather than pictures: the back plane must SEPARATE from the front one (or a tunnel reads as empty
## rather than as dark), and the cast shadow must be DIRECTIONAL (or a hole never reads as a room).
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_wall_painter.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
const GRID_W: int = 60
const GRID_H: int = 60
const FLOOR_ROW: int = 20   ## everything at or below this is solid in the fixture


func _initialize() -> void:
	_test_the_wall_reads_as_a_plane_behind_the_rock_not_as_the_rock()
	_test_the_cast_is_deepest_under_a_ceiling_and_lightest_over_a_floor()
	_test_the_cast_falls_off_with_distance_and_stops()
	_test_a_pocket_casts_from_every_side_without_clipping_to_black()
	_test_the_ramp_depth_is_derived_from_the_metre_it_was_ported_in()
	_test_the_observation_window_covers_the_deepest_probe_on_the_stack()
	_test_solid_cells_and_open_sky_are_both_left_alone()
	_test_an_incomplete_frame_paints_nothing()
	_test_the_wall_sits_between_the_sky_and_the_terrain()
	_finish("wall_painter")


## A world solid from `FLOOR_ROW` down, with a wall everywhere — exactly what `ShaftGenerator._fill_base`
## produces, where "wall mirrors the block's own material". Cells are then excavated to pose a shape.
func _world(dug: Array[Vector2i]) -> Array:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 7)
	for col: int in range(GRID_W):
		for row: int in range(FLOOR_ROW, GRID_H):
			var cell := Vector2i(col, row)
			grid.set_material(cell, &"clay")
			grid.set_wall(cell, &"clay")
	for c: Vector2i in dug:
		grid.excavate(c)
	var body: Body = Body.new(Fx.from_int(GRID_W * CELL / 2), Fx.from_int(5 * CELL))
	var iface: Interface = Interface.new(grid, body, Mining.new())
	var view := Rect2(0.0, 0.0, float(GRID_W * CELL), float(GRID_H * CELL))
	var obs: Interface.Observation = iface.observe(
		Interface.Envelope.covering(view, WorldView.WINDOW_MARGIN_CELLS))
	return [grid, obs]


func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## THE ASSERTION THE PLANE EXISTS FOR. Legacy's own measurement of the failure: a chamber's back wall
## printed at luma 0.142 against 0.117 for the rock around it, "so carved space and mass were
## indistinguishable". Separation has to be real and it has to be in BOTH channels legacy uses — value
## (it recedes) and hue (distance cools) — because either alone is the version that did not work.
func _test_the_wall_reads_as_a_plane_behind_the_rock_not_as_the_rock() -> void:
	var look: MaterialLook = MaterialLook.new()
	var col: int = 11
	var row: int = 30
	var front: Color = look.cell_color(&"clay", col, row)
	var back: Color = WallPainter.wall_color(look, &"clay", col, row)
	_check(_luma(back) < _luma(front),
		"the wall is darker than the rock in front of it (%.4f vs %.4f)" % [_luma(back), _luma(front)])
	# Cooler measured as "blue gained on red", against the SUBJECT-REMOVED colour as its own control: the
	# same rock darkened by the same amount and NOT drifted. `Color.darkened` scales all three channels,
	# so the control's ratio is the front's ratio exactly, and the whole rise is the drift's doing.
	#
	# The margin is here because the first version of this row was `back_ratio > control_ratio` and it
	# PASSED with the drift deleted: the two ratios agreed to three decimals and differed in the last
	# float bit, so a strict `>` read pure rounding as a result. Removing the drift is the mutant that
	# found it, and 0.20 is a floor far above that noise and far below the 0.45 the drift actually moves.
	const COOL_RISE_MIN: float = 0.20
	var control: Color = front.darkened(WallPainter.RECESS)
	var r_front: float = front.b / maxf(front.r, 0.0001)
	var r_control: float = control.b / maxf(control.r, 0.0001)
	var r_back: float = back.b / maxf(back.r, 0.0001)
	_check(is_equal_approx(r_control, r_front),
		"CONTROL: darkening alone is hue-neutral -- blue/red is unmoved at %.4f, so any rise below is "
		% r_control + "the cool drift and nothing else")
	_check(r_back > r_control * (1.0 + COOL_RISE_MIN),
		"and the wall is cooler, not merely dimmer -- blue/red rises %.3f -> %.3f, a %.0f%% lift against "
		% [r_control, r_back, (r_back / r_control - 1.0) * 100.0] + "a %.0f%% floor" % [COOL_RISE_MIN * 100.0])
	# The wall still has to be the SAME rock, or the plane reads as a painted backdrop rather than as the
	# ground seen from behind. Two different materials must still differ back there.
	var other: Color = WallPainter.wall_color(look, &"deepstone", col, row)
	_check(other != back,
		"two materials still paint two different walls (%s vs %s) -- the recess tones the rock, it does "
		% [back, other] + "not replace it")
	# And the per-cell grain survives the tone, or a wall of one material is a flat slab of one colour.
	_check(WallPainter.wall_color(look, &"clay", col + 1, row) != back
			or WallPainter.wall_color(look, &"clay", col, row + 1) != back,
		"and the wall keeps the per-cell grain the foreground has, rather than flattening to one value")


## Legacy's three constants exist to be told apart on screen: the key light comes from above, so a wall
## under a ceiling is deep in shadow, one beside a pillar is halfway, and one over a floor is nearly open.
## Asserted as the ORDERING of three measured alphas rather than as three literals, so this is a claim
## about the picture and not a restatement of the constants.
func _test_the_cast_is_deepest_under_a_ceiling_and_lightest_over_a_floor() -> void:
	# ONE seven-by-seven chamber, cut deep inside the solid, positioned so three of its cells each touch
	# solid on EXACTLY ONE side. Seven wide because a cell must be at least `AO_RAMP_CELLS` from the far
	# side or the far side casts on it too and the reading stops isolating one direction.
	#
	# The first version of this test dug its "side" slot at rows ABOVE the fixture's floor, where there is
	# no rock to cast at all: it read 0.0 and the ordering row failed. Worth recording, because the
	# neighbouring row -- "the ceiling cell is darkest" -- PASSED against that same 0.0, and would have
	# gone on passing against a painter whose side cast did not exist.
	var left: int = 8
	var top: int = FLOOR_ROW + 8
	var size: int = 7
	var dug: Array[Vector2i] = []
	for col: int in range(left, left + size):
		for row: int in range(top, top + size):
			dug.append(Vector2i(col, row))
	var obs: Interface.Observation = _world(dug)[1]
	var mid_col: int = left + size / 2
	var ceiling_cell := Vector2i(mid_col, top)                  ## solid only ABOVE
	var floor_cell := Vector2i(mid_col, top + size - 1)         ## solid only BELOW
	var side_cell := Vector2i(left, top + size / 2)             ## solid only to the LEFT

	var a_ceiling: float = WallPainter.ao_alpha(obs, ceiling_cell)
	var a_side: float = WallPainter.ao_alpha(obs, side_cell)
	var a_floor: float = WallPainter.ao_alpha(obs, floor_cell)
	_check(WallPainter.AO_UNDER > WallPainter.AO_SIDE and WallPainter.AO_SIDE > WallPainter.AO_ABOVE,
		"sanity: legacy's own ordering of the three constants (%.2f > %.2f > %.2f)"
		% [WallPainter.AO_UNDER, WallPainter.AO_SIDE, WallPainter.AO_ABOVE])
	_check(a_ceiling > a_side and a_side > a_floor,
		"and the picture reproduces it: under a ceiling %.4f > beside a wall %.4f > over a floor %.4f"
		% [a_ceiling, a_side, a_floor])
	_check(a_floor > 0.0,
		"the cell over a floor is cast on at all (%.4f) -- the lightest constant still has to reach the "
		% a_floor + "picture, or a floor's contact shadow is simply missing")
	# Each cell touches solid on exactly ONE side at distance 1, so each alpha must be its own constant
	# EXACTLY. This is what proves the ramp does not diminish the cell touching the occluder, and it is a
	# much sharper claim than the ordering above: an ordering survives every constant being scaled.
	_check(is_equal_approx(a_ceiling, WallPainter.AO_UNDER)
			and is_equal_approx(a_side, WallPainter.AO_SIDE)
			and is_equal_approx(a_floor, WallPainter.AO_ABOVE),
		"and each is its constant UNDIMINISHED at distance 1 (%.4f/%.2f, %.4f/%.2f, %.4f/%.2f)"
		% [a_ceiling, WallPainter.AO_UNDER, a_side, WallPainter.AO_SIDE, a_floor, WallPainter.AO_ABOVE])
	# CONTROL for the isolation itself: the chamber's own CORNER touches solid on two sides, so it must
	# NOT equal any single constant. Without this, three readings that happened to be isolated by accident
	# would look the same as three that were isolated by construction.
	_check(WallPainter.ao_alpha(obs, Vector2i(left, top)) > WallPainter.AO_UNDER,
		"CONTROL: the corner, touching solid on two sides, exceeds the deepest single constant (%.4f)"
		% WallPainter.ao_alpha(obs, Vector2i(left, top)))


## The cast is a shadow, so it has to fade with distance and then STOP. A ramp that never ended would
## darken the middle of a cavern as much as its walls, which is the flat-fill failure again with extra
## steps; a ramp that ended at one cell would read as a drawn border rather than as a shadow.
func _test_the_cast_falls_off_with_distance_and_stops() -> void:
	# One tall open shaft, so distance from the floor below is the only thing that varies.
	var dug: Array[Vector2i] = []
	var shaft_col: int = 25
	for row: int in range(FLOOR_ROW, FLOOR_ROW + 30):
		for col: int in range(shaft_col - 6, shaft_col + 7):
			dug.append(Vector2i(col, row))
	var obs: Interface.Observation = _world(dug)[1]
	var bottom_row: int = FLOOR_ROW + 29
	var readings: Array[float] = []
	for k: int in range(1, WallPainter.AO_RAMP_CELLS + 2):
		readings.append(WallPainter.ao_alpha(obs, Vector2i(shaft_col, bottom_row - k + 1)))
	_check(readings[0] > 0.0, "the cell touching the floor is cast on (%.4f)" % readings[0])
	var monotone := true
	for i: int in range(1, readings.size()):
		if readings[i] >= readings[i - 1]:
			monotone = false
	_check(monotone, "and each cell further from it is lighter than the last (%s)" % [readings])
	_check(is_zero_approx(readings[readings.size() - 1]),
		"and past the ramp there is no cast at all (%.4f at %d cells) -- the shadow ENDS"
		% [readings[readings.size() - 1], WallPainter.AO_RAMP_CELLS + 1])
	# CONTROL for the row above: an alpha of 0 out there must mean "no occluder in reach", not "this
	# function returns 0". The same cell one row down, inside the ramp, is non-zero.
	_check(WallPainter.ao_alpha(obs, Vector2i(shaft_col, bottom_row)) > 0.0,
		"CONTROL: inside the ramp the same shaft still casts")


## The composite, checked where it can go wrong: a one-cell pocket is occluded on all four sides at
## distance 1, which SUMS to 1.46 and would clip to a black square. Compositing gets a very dark but
## still-coloured cell, which is what four overlapping translucent draws actually produce.
func _test_a_pocket_casts_from_every_side_without_clipping_to_black() -> void:
	var obs: Interface.Observation = _world([Vector2i(40, FLOOR_ROW + 8)] as Array[Vector2i])[1]
	var a: float = WallPainter.ao_alpha(obs, Vector2i(40, FLOOR_ROW + 8))
	var summed: float = WallPainter.AO_UNDER + WallPainter.AO_ABOVE + WallPainter.AO_SIDE * 2.0
	_check(summed > 1.0,
		"sanity: the four constants SUM past opaque (%.3f), which is the thing being guarded against"
		% summed)
	_check(a < 1.0, "a fully enclosed cell is not opaque black (%.4f)" % a)
	_check(a > WallPainter.AO_UNDER,
		"but it is darker than the deepest single constant (%.4f > %.2f) -- four sides really do compound"
		% [a, WallPainter.AO_UNDER])


## CONSTANT MUST DOMINATE CONSTANT. `AO_RAMP_CELLS` is a whole number of cells standing in for a distance
## in metres, and the two are only related by the current cell size. Derived here rather than restated,
## so that re-denominating the grid (LEGACY_GAP WG-4) fails this row instead of silently halving the
## shadow.
func _test_the_ramp_depth_is_derived_from_the_metre_it_was_ported_in() -> void:
	var want: int = int(ceil(WallPainter.AO_DEPTH_M * float(MaterialLook.CELLS_PER_METRE)))
	_check(WallPainter.AO_RAMP_CELLS == want,
		"the ramp is %d cells, which is %0.3f m at %d cells/m rounded up (%d)"
		% [WallPainter.AO_RAMP_CELLS, WallPainter.AO_DEPTH_M, MaterialLook.CELLS_PER_METRE, want])
	_check(WallPainter.AO_RAMP_CELLS >= 1,
		"and it is at least one cell -- a zero ramp is a painter with no cast at all, which every other "
		+ "row here would still pass")


## The probe reaches further than the draw does, so the OBSERVATION has to reach further still. At a
## margin of 2 the outermost drawn column probed a cell it had never been given, `solid_at` answered
## false for it, and the straddling column at each screen edge silently lost its cast — visible only at
## the frame's edge, and only on one side. Derived from the two constants that set it.
func _test_the_observation_window_covers_the_deepest_probe_on_the_stack() -> void:
	var need: int = TerrainPainter.OVERDRAW_CELLS + WallPainter.AO_RAMP_CELLS
	_check(WorldView.WINDOW_MARGIN_CELLS >= need,
		"the window margin (%d) covers the overdraw plus the AO ramp (%d + %d = %d)"
		% [WorldView.WINDOW_MARGIN_CELLS, TerrainPainter.OVERDRAW_CELLS, WallPainter.AO_RAMP_CELLS, need])


## The two opposite reasons a cell is skipped, and they must not be confused: solid rock is skipped
## because something else draws it, and open sky is skipped because NOTHING should. Getting the second
## wrong is what would paint a wall over the sky once P017 generates air above the surface.
func _test_solid_cells_and_open_sky_are_both_left_alone() -> void:
	var parts: Array = _world([Vector2i(15, FLOOR_ROW + 2)] as Array[Vector2i])
	var grid: TileGrid = parts[0]
	var obs: Interface.Observation = parts[1]
	_check(WallPainter.backs(obs, Vector2i(15, FLOOR_ROW + 2)) == &"clay",
		"a dug cell shows the wall the grid kept behind it (%s)"
		% WallPainter.backs(obs, Vector2i(15, FLOOR_ROW + 2)))
	_check(WallPainter.backs(obs, Vector2i(16, FLOOR_ROW + 2)) == &"",
		"the solid cell beside it is left to the terrain painter")
	_check(grid.get_material(Vector2i(16, FLOOR_ROW + 2)) != &"",
		"CONTROL: that neighbour really is solid, so the row above is about SOLIDITY and not about the "
		+ "cell being missing")
	_check(WallPainter.backs(obs, Vector2i(15, FLOOR_ROW - 5)) == &"",
		"and open air above the surface, with no wall entry, is left transparent for the backdrop")
	_check(WallPainter.backs(null, Vector2i(0, 0)) == &"", "a null observation decides nothing")


## Each is a real startup state. None may crash, and none may draw.
func _test_an_incomplete_frame_paints_nothing() -> void:
	var canvas := Node2D.new()
	var obs: Interface.Observation = _world([Vector2i(15, FLOOR_ROW + 2)] as Array[Vector2i])[1]
	var no_obs := Frame.new()
	no_obs.look = MaterialLook.new()
	var no_look := Frame.new()
	no_look.obs = obs
	var no_scale := Frame.new()
	no_scale.obs = Interface.Observation.new()
	no_scale.look = MaterialLook.new()
	for f: Frame in [no_obs, no_look, no_scale]:
		WallPainter.paint(f, canvas)
	WallPainter.paint(null, canvas)
	_check(true, "no observation, no palette, no cell size, no frame at all -- each paints nothing")
	# CONTROL: a complete frame has real work to do, so the rows above are not passing on a painter that
	# returns unconditionally.
	_check(WallPainter.backs(obs, Vector2i(15, FLOOR_ROW + 2)) != &"",
		"CONTROL: a complete frame does have a wall cell to paint")
	_check(WallPainter.wall_color(null, &"clay", 0, 0) == WallPainter.COOL,
		"and with no palette the colour falls back rather than crashing")
	canvas.free()


## D0276's lesson as an assertion, extended by one plane: the wall is BEHIND the terrain and IN FRONT of
## the sky. Getting it the other way round draws the whole world flat and passes every other row here,
## which is exactly how the empty-world bug got through 48 green suites.
func _test_the_wall_sits_between_the_sky_and_the_terrain() -> void:
	_check(RevealViewSetup.SKY_Z < RevealViewSetup.WALL_Z,
		"the wall is in front of the sky (%d > %d)" % [RevealViewSetup.WALL_Z, RevealViewSetup.SKY_Z])
	_check(RevealViewSetup.WALL_Z < RevealViewSetup.TERRAIN_Z,
		"and behind the terrain (%d < %d) -- a wall drawn over the rock is a hole in the world"
		% [RevealViewSetup.WALL_Z, RevealViewSetup.TERRAIN_Z])
	_check(RevealViewSetup.BACKDROP_Z < RevealViewSetup.WALL_Z,
		"and the backdrop is still below both (%d)" % RevealViewSetup.BACKDROP_Z)
