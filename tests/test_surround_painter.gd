extends "res://tests/test_base.gd"

## `view/visuals/surround_painter.gd` -- THE EARTH PAST THE EDGE OF THE WORLD (T036, item 34).
##
## The sim has answered "rock" for every cell outside the grid since D0457; the view painted the sky's
## below-horizon colour there. **TWO GUESSES AT WHAT THAT ROCK LOOKS LIKE WERE BOTH REFUSED BY A REAL
## FRAME** (D0590, D0597): band colours came out at luma 0.381 against the terrain's 0.185, and
## `deepstone` lit by `VeilLight` under the veil came out at 0.022-0.054 -- a hole rather than a wall.
##
## So the beyond is no longer a guess at all: it is the edge column's OWN material, continued. These
## assertions pin that continuity, because it is the property that makes the seam invisible without any
## constant needing to be calibrated against another.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_surround_painter.gd

const SURF: float = float(MaterialLook.SURFACE_ROW)


func _initialize() -> void:
	_test_the_beyond_is_the_edge_column_continued()
	_test_it_recedes_to_a_floor_that_is_not_black()
	_test_it_survives_every_degenerate_input()
	await _test_paint_runs_on_a_real_canvas()
	_finish("surround_painter")


static func _luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## A window of solid `material` from `SURF` down, so the edge column has something to continue.
func _obs(material: StringName = &"clay") -> Interface.Observation:
	var w: int = 48
	var h: int = 120
	var o: Interface.Observation = Interface.Observation.new()
	o.world_cells = Vector2i(w, h)
	o.window = Rect2i(0, 0, w, h)
	o.logic_window = Rect2i(0, 0, w / 4, h / 4)
	o.legend = PackedStringArray(["", String(material)])
	o.materials = PackedByteArray()
	o.materials.resize(w * h)
	o.water = PackedByteArray()
	o.water.resize(w * h)
	# THE WALL PLANE IS POSED TOO, not switched off. `has_walls` defaults TRUE, so an observation that
	# simply omits the arrays claims a plane it does not have and `wall_at` push_errors -- which is how
	# the first version of this fixture failed. And the wall branch is real code: an open cell at the
	# edge takes the wall behind it, and a fixture that dodged that would leave it untested.
	o.has_walls = true
	o.wall_legend = PackedStringArray(["", "hardrock"])
	o.walls = PackedByteArray()
	o.walls.resize(w * h)
	for col: int in w:
		for row: int in range(int(SURF), h):
			o.materials[row * w + col] = 1
		for row: int in range(int(SURF) - 6, int(SURF)):
			o.walls[row * w + col] = 1          # six rows of exposed wall above the ground line
	var surf := PackedInt32Array()
	for _col: int in w:
		surf.append(int(SURF) * Interface.Units.CELL_PX * Fx.SCALE)
	o.surface_y = surf
	return o


## THE WHOLE DESIGN IN ONE ASSERTION. The beyond at a row IS what `MaterialLook` gives the cell just
## inside the boundary at that row, so the seam cannot be wrong by a calibration error -- there is no
## calibration. Both earlier versions failed exactly here and neither could have been caught by a test
## that only asked whether the colour was "dark enough".
func _test_the_beyond_is_the_edge_column_continued() -> void:
	var look: MaterialLook = MaterialLook.new()
	var o: Interface.Observation = _obs()
	var mismatched: int = 0
	var distinct: Dictionary = {}
	for m: int in range(0, 9):
		var row: int = int(SURF) + m * MaterialLook.CELLS_PER_METRE
		var beyond: Color = SurroundPainter.mass_color(look, o, 0, row)
		var inside: Color = look.matrix_color(&"clay", 0, row)
		if not (is_equal_approx(beyond.r, inside.r) and is_equal_approx(beyond.g, inside.g)
				and is_equal_approx(beyond.b, inside.b)):
			mismatched += 1
		distinct["%.3f,%.3f,%.3f" % [beyond.r, beyond.g, beyond.b]] = true
	_check(mismatched == 0, "the beyond IS the edge column's own colour at every row (%d mismatches of 9)" % mismatched)
	# CONTROL: it must actually VARY down the column, or the assertion above is satisfied by a constant.
	_check(distinct.size() >= 5, "and it varies down the face: %d distinct over 9 metres" % distinct.size())
	# And a different material at the edge gives a different beyond -- so it is reading the world, not a
	# constant that happens to match clay.
	var other: Color = SurroundPainter.mass_color(look, _obs(&"hardrock"), 0, int(SURF) + 20)
	var clayish: Color = SurroundPainter.mass_color(look, o, 0, int(SURF) + 20)
	_check(absf(_luma(other) - _luma(clayish)) > 0.01,
		"a hardrock edge gives a different beyond than a clay one (%.4f against %.4f)" % [
			_luma(other), _luma(clayish)])


## It must fade AWAY from the world and must not reach black: black past the edge reads as a hole, which
## is the one thing this painter exists to stop looking like.
func _test_it_recedes_to_a_floor_that_is_not_black() -> void:
	_check(absf(SurroundPainter.recede(0.0) - 1.0) < 0.0001,
		"at the boundary the mass is at full strength: the seam is continuous with the terrain")
	_check(absf(SurroundPainter.recede(SurroundPainter.RECEDE_M) - SurroundPainter.RECEDE_FLOOR) < 0.0001,
		"and reaches its floor at RECEDE_M (%.1f m -> %.4f)" % [SurroundPainter.RECEDE_M, SurroundPainter.RECEDE_FLOOR])
	_check(SurroundPainter.RECEDE_FLOOR > 0.05, "the floor is not black (%.4f)" % SurroundPainter.RECEDE_FLOOR)
	var fell: int = 0
	var last: float = 2.0
	for i: int in 21:
		var v: float = SurroundPainter.recede(float(i))
		if v <= last:
			fell += 1
		last = v
	_check(fell == 21, "and never brightens with distance across 21 steps (%d)" % fell)
	_check(absf(SurroundPainter.recede(999.0) - SurroundPainter.RECEDE_FLOOR) < 0.0001,
		"and clamps rather than running negative far out")


## Every early return, including the ones a real frame reaches at a world corner.
func _test_it_survives_every_degenerate_input() -> void:
	var o: Interface.Observation = _obs()
	_check(SurroundPainter.mass_color(null, o, 0, 100) == SurroundPainter.FALLBACK,
		"a null look falls back rather than throwing")
	_check(SurroundPainter.mass_color(MaterialLook.new(), null, 0, 100) == SurroundPainter.FALLBACK,
		"and a null observation does too")
	# AN OPEN CELL AT THE EDGE TAKES THE WALL BEHIND IT, which is the branch a cut-to-the-boundary shaft
	# reaches. The fixture puts six rows of `hardrock` wall just above the ground line.
	var look: MaterialLook = MaterialLook.new()
	var walled: Color = SurroundPainter.mass_color(look, o, 0, int(SURF) - 3)
	_check(walled == look.matrix_color(&"hardrock", 0, int(SURF) - 3),
		"an open cell at the edge is painted with the WALL behind it, not with air")
	# Higher still there is neither, and it falls back rather than painting the beyond with nothing.
	_check(SurroundPainter.mass_color(look, o, 0, 4) == SurroundPainter.FALLBACK,
		"and where there is neither material nor wall it falls back")
	SurroundPainter.paint(null, null)
	var f: Frame = Frame.new()
	SurroundPainter.paint(f, null)
	_check(true, "and `paint` refuses a null frame and one with no observation")


## THE DRAW, and it exists because of D0596: a suite of pure-function assertions can be complete, green,
## and about nothing that reaches the screen. `run_gd_test.sh`'s D0149 guard fails this file if the
## polygon batch is ever malformed the way `GrassPainter`'s multiline batch was.
func _test_paint_runs_on_a_real_canvas() -> void:
	var items: Items = _hub_items(20, 30)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20 * 4):
		for row: int in range(80, 120):
			world.set_solid(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(76 * 4) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var ran: Array = [0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		SurroundPainter.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint() ran inside a real draw pass (%d)" % int(ran[0]))
	_check(true, "and the engine raised no draw error -- the D0149 guard is the witness")
	view.queue_free()
