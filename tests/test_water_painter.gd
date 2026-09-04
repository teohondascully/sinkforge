extends "res://tests/test_base.gd"

## `view/visuals/water_painter.gd` (A' step 6a, D0362), structural. It cannot say the water LOOKS like
## water; it guards what the painter would get wrong silently: a surface that rises the wrong way, a
## pool whose top terraces instead of tapering, an interior cell drawn short so rock shows between
## slabs, a waterline that ripples where water sits above it, a depth that never runs out, and a paint
## pass that trips on the observation.

const S: int = Fx.SCALE
const CELL: float = float(Heightfield.TERRAIN_CELL_PX)


func _initialize() -> void:
	_test_the_surface_rises_with_level()
	_test_a_level_step_tapers_and_an_interior_cell_is_full()
	_test_only_the_top_cell_ripples()
	_test_depth_runs_out()
	_test_the_wet_cells_reach_the_observation_sparsely()
	_test_the_drips_pour_only_where_there_is_room_below()
	await _test_paint_runs_against_a_real_frame_with_a_pool()
	_finish("water_painter")


class Pool:
	var grid: TileGrid
	var world: World
	var door: Interface


## A basin: floor at row 30, walls at columns 4 and 25, water poured in by level per column.
func _pool(levels: Dictionary) -> Pool:
	var p: Pool = Pool.new()
	p.grid = TileGrid.new(40, 40, 1)
	for col: int in range(40):
		for row: int in range(30, 40):
			p.grid.set_material(Vector2i(col, row), &"clay")
	for row: int in range(40):
		p.grid.set_material(Vector2i(4, row), &"clay")
		p.grid.set_material(Vector2i(25, row), &"clay")
	p.world = World.new(p.grid)
	for c: Vector2i in levels:
		p.world.water.set_level(c, int(levels[c]))
	p.door = Interface.new(p.grid, Body.new(Fx.from_int(60), Fx.from_int(60)), Mining.new(), p.world)
	return p


func _obs(p: Pool) -> Interface.Observation:
	return p.door.observe(Interface.Envelope.new(Rect2i(0, 0, 40, 40)))


func _test_the_surface_rises_with_level() -> void:
	var c := Vector2i(10, 29)
	_check(WaterPainter.surface_y(c, 0) == 30.0 * CELL, "level 0 is the cell floor")
	_check(WaterPainter.surface_y(c, WaterPainter.WATER_MAX) == 29.0 * CELL, "a full cell's surface is its top")
	_check(WaterPainter.surface_y(c, WaterPainter.WATER_MAX / 2) == 29.5 * CELL, "half full is half way up")
	_check(WaterPainter.surface_y(c, 99) == 29.0 * CELL, "an over-full level clamps to the top")


func _test_a_level_step_tapers_and_an_interior_cell_is_full() -> void:
	var half: int = WaterPainter.WATER_MAX / 2
	var p: Pool = _pool({Vector2i(10, 29): WaterPainter.WATER_MAX, Vector2i(11, 29): half, Vector2i(12, 29): half,
		Vector2i(15, 28): WaterPainter.WATER_MAX, Vector2i(15, 29): WaterPainter.WATER_MAX})
	var o: Interface.Observation = _obs(p)
	var full: Dictionary = WaterPainter.cell_shape(o, Vector2i(10, 29), 0.0)
	var step: Dictionary = WaterPainter.cell_shape(o, Vector2i(11, 29), 0.0)
	_check(not full.is_empty() and full["fill"].size() == 5, "a wet cell has a five-point fill")
	# At t=0 the ripple at x = 44, 46 and 48 px is sin(x/23 * TAU)*0.75: read the geometry through the
	# ripple-free right edge relation instead -- the step's LEFT edge averages with the full neighbour.
	var step_left: float = step["fill"][0].y - WaterPainter._ripple(11.0 * CELL, 0.0)
	var step_right: float = step["fill"][2].y - WaterPainter._ripple(12.0 * CELL, 0.0)
	_check(absf(step_left - 0.5 * (29.5 * CELL + 29.0 * CELL)) < 0.001,
		"a level step tapers: the half cell's left edge averages with the full neighbour's surface")
	_check(absf(step_right - 29.5 * CELL) < 0.001, "...and its right edge, beside an equal neighbour, stays at its own level")
	_check(WaterPainter.cell_shape(o, Vector2i(13, 29), 0.0).is_empty(), "a dry cell has no shape")
	var interior: Dictionary = WaterPainter.cell_shape(o, Vector2i(15, 29), 0.0)
	_check(not interior["open_above"] and interior["fill"][0].y == 29.0 * CELL and interior["fill"][1].y == 29.0 * CELL,
		"a cell with water above it is drawn to its top: the water above rests on it")
	var top: Dictionary = WaterPainter.cell_shape(o, Vector2i(15, 28), 0.0)
	_check(top["open_above"], "the cell above it owns the waterline")


func _test_only_the_top_cell_ripples() -> void:
	var p: Pool = _pool({Vector2i(10, 28): WaterPainter.WATER_MAX, Vector2i(10, 29): WaterPainter.WATER_MAX})
	var o: Interface.Observation = _obs(p)
	var t0: Dictionary = WaterPainter.cell_shape(o, Vector2i(10, 28), 0.0)
	var t1: Dictionary = WaterPainter.cell_shape(o, Vector2i(10, 28), 0.31)
	_check(t0["fill"][1] != t1["fill"][1], "the waterline moves with the clock")
	var moved: float = absf(t0["fill"][1].y - t1["fill"][1].y)
	_check(moved <= 2.0 * WaterPainter.WATER_RIPPLE_AMP + 0.001, "...by at most twice the ripple amplitude (%.2f px)" % moved)
	var i0: Dictionary = WaterPainter.cell_shape(o, Vector2i(10, 29), 0.0)
	var i1: Dictionary = WaterPainter.cell_shape(o, Vector2i(10, 29), 0.31)
	_check(i0["fill"] == i1["fill"], "an interior cell's geometry does not ripple")
	_check(i0["color"] != i1["color"], "...but its caustics drift")
	_check(t0["meniscus"].size() == 6 and t0["line"].size() == 6, "the meniscus and the bright line hang off the same three top points")
	_check(t0["meniscus"][0] == t0["fill"][0] and t0["line"][2] == t0["fill"][2], "...literally the same points")


func _test_depth_runs_out() -> void:
	var levels: Dictionary = {}
	for row: int in range(0, 30):
		levels[Vector2i(20, row)] = WaterPainter.WATER_MAX   # a 30-cell column of water
	var p: Pool = _pool(levels)
	var o: Interface.Observation = _obs(p)
	_check(WaterPainter.depth(o, Vector2i(20, 0)) == 0.0, "the top cell is at depth 0")
	_check(absf(WaterPainter.depth(o, Vector2i(20, 7)) - 7.0 / float(WaterPainter.WATER_DEPTH_CELLS)) < 0.001, "seven cells down is 7/28")
	_check(WaterPainter.depth(o, Vector2i(20, 29)) == 1.0, "past the gradient's reach the depth is capped at 1")
	var shallow: Color = WaterPainter.fill_color(0.0, Vector2(80, 0), 0.0)
	var deep: Color = WaterPainter.fill_color(1.0, Vector2(80, 0), 0.0)
	_check(deep.a > shallow.a and deep.b < shallow.b + 0.001 and deep.r < shallow.r,
		"deep water is denser and darker than the surface (a %.2f vs %.2f)" % [deep.a, shallow.a])


func _test_the_wet_cells_reach_the_observation_sparsely() -> void:
	var p: Pool = _pool({Vector2i(10, 29): 3, Vector2i(11, 29): 5, Vector2i(39, 0): 2})
	var o: Interface.Observation = _obs(p)
	_check(o.wet_cells.size() == 3 and o.wet_cells == Ordering.cells({Vector2i(10, 29): 1, Vector2i(11, 29): 1, Vector2i(39, 0): 1}),
		"the observation lists the wet cells in the window, in cell order (%s)" % [o.wet_cells])
	var narrow: Interface.Observation = p.door.observe(Interface.Envelope.new(Rect2i(0, 20, 20, 20)))
	_check(narrow.wet_cells.size() == 2, "...and only those inside the window (%d)" % narrow.wet_cells.size())
	_check(o.water_at(Vector2i(11, 29)) == 5, "control: the plane itself still answers a level")


## `view/fx/water_drips.gd`: pouring is the sim's own fall rule, the phase is stable per cell, the splash
## lands on the first blocker down the column, and a frame's spawn is capped and view-culled.
func _test_the_drips_pour_only_where_there_is_room_below() -> void:
	var p: Pool = _pool({Vector2i(10, 29): WaterPainter.WATER_MAX, Vector2i(15, 20): 3, Vector2i(15, 21): WaterPainter.WATER_MAX,
		Vector2i(20, 10): 2})
	var o: Interface.Observation = _obs(p)
	_check(not WaterDrips.pouring(o, Vector2i(10, 29)), "water on the floor does not pour")
	_check(not WaterDrips.pouring(o, Vector2i(15, 20)), "water on a full cell does not pour")
	_check(WaterDrips.pouring(o, Vector2i(20, 10)), "water over open air pours")
	_check(WaterDrips.landing_cell(o, Vector2i(20, 10)) == Vector2i(20, 29), "its drop lands on the floor at row 29")
	_check(WaterDrips.landing_cell(o, Vector2i(15, 18)) == Vector2i(15, 20),
		"a drop falls through a part-full cell and lands on the full surface under it (legacy's rule)")
	_check(WaterDrips.phase(Vector2i(3, 4)) == WaterDrips.phase(Vector2i(3, 4)) and WaterDrips.phase(Vector2i(3, 4)) != WaterDrips.phase(Vector2i(4, 3)),
		"the per-cell phase is stable and differs between cells")
	var particles: Particles = Particles.new()
	var total: int = 0
	for _i: int in 200:
		total += WaterDrips.spawn(o, particles, Rect2(0, 0, 160, 160), 1.0 / 60.0)
	_check(total > 0 and total <= 200 * WaterDrips.DRIP_MAX_PER_FRAME, "over 200 frames the pouring cell shed some drips, under the cap (%d)" % total)
	_check(WaterDrips.spawn(o, particles, Rect2(1000, 1000, 10, 10), 1.0) == 0, "off-screen water sheds nothing")
	_check(WaterDrips.spawn(null, particles, Rect2(), 1.0) == 0 and WaterDrips.spawn(o, null, Rect2(), 1.0) == 0, "no observation or no layer, no drips")


func _test_paint_runs_against_a_real_frame_with_a_pool() -> void:
	var levels: Dictionary = {}
	for col: int in range(5, 25):
		levels[Vector2i(col, 29)] = WaterPainter.WATER_MAX
		levels[Vector2i(col, 28)] = WaterPainter.WATER_MAX / 2
	var p: Pool = _pool(levels)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(p.door, MaterialLook.new(), cam)
	var ran: Array = [0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		WaterPainter.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint() ran to completion inside a real draw pass over a forty-cell pool (%d)" % int(ran[0]))
	view.queue_free()
