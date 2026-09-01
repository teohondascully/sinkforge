extends "res://tests/test_base.gd"

## `view/visuals/glint_painter.gd` — the discovery twinkle (D0300, legacy `_draw_glint_flares`).
##
## The suite is built around the two halves failing SEPARATELY, because they did: the population (which
## cells can ever glint) and the clock (when a cell that can, does). A painter with the right cells and a
## dead clock draws a static starfield; one with a live clock and the wrong cells twinkles inside solid
## rock. Neither is visible in a call that returns without crashing, which is all a `_draw` can be asked.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_glint_painter.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
const GRID_W: int = 40

## THE FIXTURE'S ROCK MUST SIT BELOW THE SURFACE DATUM, and the first version's did not. `ROCK_TOP` was a
## bare 12, which reads as seventeen metres of ALTITUDE once P017/D0292 put the surface at row 80 — so
## `depth_gate` returned 0 for every cell in the world, `alpha_at` was constantly zero, and the clock
## assertion failed against a painter that was correct. A fixture that poses its subject at the wrong
## depth measures the depth gate rather than the thing under test.
##
## Placed a clear margin past `GLINT_FULL_M` so the gate is saturated and cannot be what any assertion
## below is reading. `_test_the_fixture_poses_a_depth_that_can_glint_at_all` is the witness for that.
const ROCK_TOP: int = MaterialLook.SURFACE_ROW + 60          ## 15 m down: past the gate's full-strength depth
const GRID_H: int = ROCK_TOP + 28


func _initialize() -> void:
	_test_the_fixture_poses_a_depth_that_can_glint_at_all()
	_test_only_an_exposed_face_can_glint()
	_test_coal_never_glints_however_exposed_it_is()
	_test_the_mark_gate_is_not_in_the_predicate()
	_test_the_surface_does_not_twinkle_and_the_deep_does()
	_test_every_cell_flares_within_one_period_and_is_dark_for_most_of_it()
	_test_the_clock_is_what_moves_it()
	_test_an_incomplete_frame_paints_nothing()
	_finish("glint_painter")


## The witness for `ROCK_TOP`. Every assertion in this suite that expects a flare is silently vacuous if
## the fixture's rock sits where the depth gate is zero, and that is exactly how this suite first failed.
func _test_the_fixture_poses_a_depth_that_can_glint_at_all() -> void:
	var look: MaterialLook = MaterialLook.new()
	var m: float = MaterialLook.depth_m_exact(ROCK_TOP)
	print("  [OBSERVED] fixture rock starts at row %d = %.1f m, gate %.3f"
		% [ROCK_TOP, m, GlintPainter.depth_gate(look, ROCK_TOP)])
	_check(m >= GlintPainter.GLINT_FULL_M,
		"the fixture's rock is at %.1f m, at or past the %.1f m the gate saturates at -- otherwise every "
		% [m, GlintPainter.GLINT_FULL_M] + "flare assertion here reads the gate rather than the flare")
	_check(is_equal_approx(GlintPainter.depth_gate(look, GRID_H - 1), 1.0),
		"...and so is the bottom of the world, so no cell in this fixture is gated by depth")


## A world solid from `ROCK_TOP` down in `material`, with `dug` excavated to pose faces.
func _world(material: StringName, dug: Array[Vector2i]) -> Array:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 11)
	for col: int in range(GRID_W):
		for row: int in range(ROCK_TOP, GRID_H):
			grid.set_material(Vector2i(col, row), material)
			grid.set_wall(Vector2i(col, row), material)
	for c: Vector2i in dug:
		grid.excavate(c)
	var body: Body = Body.new(Fx.from_int(GRID_W * CELL / 2), Fx.from_int(4 * CELL))
	var iface: Interface = Interface.new(grid, body, Mining.new())
	var view := Rect2(0.0, 0.0, float(GRID_W * CELL), float(GRID_H * CELL))
	var obs: Interface.Observation = iface.observe(
		Interface.Envelope.covering(view, WorldView.WINDOW_MARGIN_CELLS))
	return [obs, MaterialLook.new()]


## The first solid ore cell that is (or is not) an exposed face. Returns Vector2i(-1, -1) if the fixture
## posed none — the callers check, because a loop over an empty population is a green that measured
## nothing. Deliberately NOT filtered by `is_speck`: that gate belongs to how ore is coloured, not to
## whether it flares, and intersecting the two is the defect this suite's population now excludes.
func _find_ore(_look: MaterialLook, obs: Interface.Observation, exposed: bool) -> Vector2i:
	for row: int in range(ROCK_TOP, GRID_H):
		for col: int in range(GRID_W):
			var c := Vector2i(col, row)
			if obs.material_at(c) == &"":
				continue
			if GlintPainter.is_exposed_face(obs, c) == exposed:
				return c
	return Vector2i(-1, -1)


## Legacy's rule, and the whole reason the predicate is not just "is it ore": "a fleck catches the light
## at a dug face, not buried in solid rock. Ore twinkling everywhere, including cells sealed inside stone,
## reads as a floating starfield."
func _test_only_an_exposed_face_can_glint() -> void:
	# A one-cell pocket well inside the rock, so the cells around its mouth are faces and the rest are not.
	var dug: Array[Vector2i] = []
	for row: int in range(ROCK_TOP + 6, ROCK_TOP + 10):
		for col: int in range(8, 14):
			dug.append(Vector2i(col, row))
	var w: Array = _world(&"glimmer", dug)
	var obs: Interface.Observation = w[0]
	var look: MaterialLook = w[1]

	var face: Vector2i = _find_ore(look, obs, true)
	var buried: Vector2i = _find_ore(look, obs, false)
	_check(face.x >= 0, "the fixture posed an EXPOSED ore cell (got %s)" % face)
	_check(buried.x >= 0, "the fixture posed a BURIED ore cell (got %s)" % buried)
	if face.x < 0 or buried.x < 0:
		return
	_check(GlintPainter.can_glint(look, obs, face), "an ore cell at a dug face can glint (%s)" % face)
	_check(not GlintPainter.can_glint(look, obs, buried),
		"an ore cell sealed inside stone cannot, however deep (%s)" % buried)
	# The open cell itself is not solid, so it is not a face either -- the pocket does not glint, its wall does.
	_check(not GlintPainter.can_glint(look, obs, dug[0]),
		"an OPEN cell is not a face: it is the hole, not the rock around it (%s)" % dug[0])


## THE ASSERTION THAT WOULD HAVE CAUGHT THE OVER-PORT. `is_speck` decides how ore is COLOURED — ~10% of a
## vein's cells take the mineral hue (D0299) — and it has nothing to say about whether a face catches the
## light. The first version of `can_glint` intersected the two because it looked like it followed from
## D0299, and on the real `reveal_test_dense` world that took 1,183 exposed ore faces down to 81. Every
## test still passed; three of four milestone captures diffed at exactly ZERO pixels.
##
## Stated as the population it excludes rather than as a count, so it stays true when the density changes:
## an exposed ore face that is NOT marked must still be able to glint.
func _test_the_mark_gate_is_not_in_the_predicate() -> void:
	var dug: Array[Vector2i] = []
	for col: int in range(GRID_W):
		dug.append(Vector2i(col, ROCK_TOP))
	var w: Array = _world(&"glimmer", dug)
	var obs: Interface.Observation = w[0]
	var look: MaterialLook = w[1]
	var unmarked_faces: int = 0
	var unmarked_glinting: int = 0
	for col: int in range(GRID_W):
		var c := Vector2i(col, ROCK_TOP + 1)
		if look.is_speck(&"glimmer", c.x, c.y):
			continue
		unmarked_faces += 1
		if GlintPainter.can_glint(look, obs, c):
			unmarked_glinting += 1
	_check(unmarked_faces > 0,
		"the fixture posed exposed glimmer that is NOT marked (%d of %d) -- with every cell marked this "
		% [unmarked_faces, GRID_W] + "assertion could not tell the two predicates apart")
	_check(unmarked_glinting == unmarked_faces,
		"every UNMARKED exposed ore face can still glint (%d of %d) -- the colouring gate is not the "
		% [unmarked_glinting, unmarked_faces] + "flaring gate, and intersecting them cost 93%% of the population")


## `data/materials/coal.yaml` sets `glitters: false` and carries legacy's reason: glittering coal was
## being mistaken for a gem. Coal HAS nuggets, so a predicate keyed on `nugget_color` alone passes it —
## which is exactly what the first version of `can_glint` did.
func _test_coal_never_glints_however_exposed_it_is() -> void:
	var dug: Array[Vector2i] = []
	for col: int in range(GRID_W):
		dug.append(Vector2i(col, ROCK_TOP))   ## strip the top row: every cell below it is a face
	var w: Array = _world(&"coal", dug)
	var obs: Interface.Observation = w[0]
	var look: MaterialLook = w[1]
	var faces: int = 0
	var glinting: int = 0
	for col: int in range(GRID_W):
		var c := Vector2i(col, ROCK_TOP + 1)
		if GlintPainter.is_exposed_face(obs, c):
			faces += 1
		if GlintPainter.can_glint(look, obs, c):
			glinting += 1
	_check(faces == GRID_W,
		"the fixture posed exposed coal in every column (%d of %d) -- zero would make the next line pass "
		% [faces, GRID_W] + "by having nothing to reject")
	_check(GlintPainter.is_exposed_face(obs, Vector2i(0, ROCK_TOP + 1)),
		"...and that row IS an exposed face, so the rejection below is about `glitters` and not about depth")
	_check(glinting == 0, "coal never glints: %d of %d exposed coal faces glinted" % [glinting, faces])


## Legacy fades the flare out as skylight rises — "a lit surface vein reads as rock, not a sparkle". There
## is no veil to read, so `depth_gate` reads depth, and this is the assertion that keeps the substitution
## honest rather than leaving it as a comment.
func _test_the_surface_does_not_twinkle_and_the_deep_does() -> void:
	var look: MaterialLook = MaterialLook.new()
	var surface_row: int = MaterialLook.SURFACE_ROW
	var deep_row: int = surface_row + int(GlintPainter.GLINT_FULL_M) * MaterialLook.CELLS_PER_METRE
	_check(is_zero_approx(GlintPainter.depth_gate(look, surface_row)),
		"a vein at the surface datum does not flare (%.3f)" % GlintPainter.depth_gate(look, surface_row))
	_check(is_equal_approx(GlintPainter.depth_gate(look, deep_row), 1.0),
		"a vein at %.0f m flares at full strength (%.3f)"
		% [GlintPainter.GLINT_FULL_M, GlintPainter.depth_gate(look, deep_row)])
	# Ramped, not switched: the midpoint must be strictly between, or a hard edge draws a horizontal line
	# across the world at one row and legacy's reason for ramping is lost.
	var mid_m: float = (GlintPainter.GLINT_NONE_M + GlintPainter.GLINT_FULL_M) * 0.5
	var mid_row: int = surface_row + int(mid_m * float(MaterialLook.CELLS_PER_METRE))
	var mid: float = GlintPainter.depth_gate(look, mid_row)
	_check(mid > 0.0 and mid < 1.0, "the gate RAMPS rather than switching (%.3f at %.1f m)" % [mid, mid_m])
	_check(GlintPainter.depth_gate(null, deep_row) == 0.0, "a null palette flares nothing")


## The clock half. Legacy's period is 3.4 s with a 0.5 s flare, so a cell is dark for ~85% of its cycle —
## "a rare twinkle", not a running light. Both halves are asserted: it must fire, and it must mostly not.
func _test_every_cell_flares_within_one_period_and_is_dark_for_most_of_it() -> void:
	var samples: int = 340
	var step: float = GlintPainter.PERIOD / float(samples)
	var cells: Array[Vector2i] = [Vector2i(3, 91), Vector2i(17, 104), Vector2i(40, 220)]
	for c: Vector2i in cells:
		var lit: int = 0
		var peak: float = 0.0
		for i: int in samples:
			var f: float = GlintPainter.flare_at(c, float(i) * step)
			if f > 0.0:
				lit += 1
			peak = maxf(peak, f)
		var duty: float = float(lit) / float(samples)
		var want: float = GlintPainter.FLARE_LEN / GlintPainter.PERIOD
		print("  [OBSERVED] %s duty %.3f (want ~%.3f), peak %.3f" % [c, duty, want, peak])
		_check(peak > 0.99, "cell %s reaches full flare somewhere in one period (peak %.3f)" % [c, peak])
		_check(absf(duty - want) < 0.02,
			"cell %s is lit for %.1f%% of its period, legacy's %.1f%% (a flare that never ends is a lamp)"
			% [c, duty * 100.0, want * 100.0])
	# Different cells must be OUT OF PHASE, or the whole field blinks in unison and the hash offset is
	# doing nothing. Asserted over a sweep rather than at one instant: two cells can coincide at a given
	# t by chance, and a single-sample check would then fail on a correct painter.
	var differed: int = 0
	for i: int in samples:
		if not is_equal_approx(GlintPainter.flare_at(cells[0], float(i) * step),
				GlintPainter.flare_at(cells[1], float(i) * step)):
			differed += 1
	_check(differed > samples / 4,
		"two cells are out of phase over most of a period (%d of %d samples differed) -- in unison the "
		% [differed, samples] + "hash offset is inert and the field blinks as one")


## The clock is the SUBJECT here, so it is the thing that gets posed: same cell, same world, two times.
## A painter reading a frozen `anim_time` passes every assertion above and draws a static starfield.
func _test_the_clock_is_what_moves_it() -> void:
	var dug: Array[Vector2i] = []
	for col: int in range(GRID_W):
		dug.append(Vector2i(col, ROCK_TOP))
	var w: Array = _world(&"glimmer", dug)
	var obs: Interface.Observation = w[0]
	var look: MaterialLook = w[1]
	var c: Vector2i = _find_ore(look, obs, true)
	_check(c.x >= 0, "the fixture posed an exposed ore cell to move (got %s)" % c)
	if c.x < 0:
		return
	var seen: Dictionary = {}
	var steps: int = 68
	for i: int in steps:
		seen[snappedf(GlintPainter.alpha_at(look, obs, c, float(i) * 0.05), 0.01)] = 1
	print("  [OBSERVED] %s took %d distinct alphas over %.1f s" % [c, seen.size(), float(steps) * 0.05])
	_check(seen.size() >= 3,
		"one cell's alpha MOVES as the clock advances (%d distinct values over %d samples) -- a frozen "
		% [seen.size(), steps] + "clock gives exactly 1 and every other assertion here still passes")
	_check(seen.has(0.0), "...and it spends part of that time fully dark")


func _test_an_incomplete_frame_paints_nothing() -> void:
	var node := Node2D.new()
	GlintPainter.paint(null, node)
	var f: Frame = Frame.new()
	GlintPainter.paint(f, node)
	node.free()
	_check(not GlintPainter.can_glint(null, null, Vector2i.ZERO),
		"a null palette and observation decide nothing")
	_check(not GlintPainter.is_exposed_face(null, Vector2i.ZERO), "a null observation exposes nothing")
	_check(true, "no frame, and a frame with no observation, each paint nothing rather than erroring")
