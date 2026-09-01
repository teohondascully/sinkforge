extends "res://tests/test_base.gd"

## `view/visuals/terrain_painter.gd` — terrain drawn by a painter on the coordinator (D0276,
## LEGACY_GAP T1 #4).
##
## `visit_rect()` is split out of `paint()` and asserted directly, for the reason this repo keeps
## rediscovering: Godot exposes no way to read back what a `CanvasItem` was told to draw, so a painter
## tested only by being called can assert nothing beyond "it did not crash" — which is exactly what a
## broken early return does while the screen stays black.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_terrain_painter.gd

const CELL: int = Heightfield.TERRAIN_CELL_PX
const GRID_W: int = 80
const GRID_H: int = 60


func _initialize() -> void:
	_test_the_visit_rect_covers_the_view_and_overdraws_by_one_cell()
	_test_it_never_visits_a_cell_the_observation_was_not_given()
	_test_a_view_outside_the_window_visits_nothing_rather_than_everything()
	_test_the_painter_reads_the_same_materials_the_grid_holds()
	_test_an_incomplete_frame_paints_nothing()
	_test_the_backdrop_is_the_lowest_thing_drawn()
	_finish("terrain_painter")


## A world with a floor, and an observation over a stated envelope.
func _observed(view_rect: Rect2, margin_cells: int = 2) -> Array:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 7)
	for col: int in range(GRID_W):
		for row: int in range(30, GRID_H):
			grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(GRID_W * CELL / 2), Fx.from_int(20 * CELL))
	var iface: Interface = Interface.new(grid, body, Mining.new())
	var obs: Interface.Observation = iface.observe(Interface.Envelope.covering(view_rect, margin_cells))
	return [grid, obs]


## The overdraw is what stops a seam of half-tiles along the screen edge: a cell straddling the boundary
## must be drawn whole. Asserted as "covers the view AND then some", not as a literal rect, so this
## measures the property rather than restating the arithmetic.
func _test_the_visit_rect_covers_the_view_and_overdraws_by_one_cell() -> void:
	var view := Rect2(40.0, 130.0, 200.0, 90.0)
	var parts: Array = _observed(view, 4)
	var obs: Interface.Observation = parts[1]
	var r: Rect2i = TerrainPainter.visit_rect(obs, view, CELL)
	_check(r.get_area() > 0, "sanity: the visit rect is not empty (%s)" % r)
	var first_visible_col: int = int(floor(view.position.x / float(CELL)))
	var last_visible_col: int = int(ceil(view.end.x / float(CELL)))
	_check(r.position.x <= first_visible_col,
		"it starts at or before the first visible column (%d <= %d)" % [r.position.x, first_visible_col])
	_check(r.end.x >= last_visible_col,
		"and ends at or after the last (%d >= %d)" % [r.end.x, last_visible_col])
	_check(r.position.y <= int(floor(view.position.y / float(CELL))) and r.end.y >= int(ceil(view.end.y / float(CELL))),
		"and the same on both vertical edges (%d..%d)" % [r.position.y, r.end.y])


## THE ASSERTION THE WHOLE PORT EXISTS FOR. Reading past the window returns `&""`, which a painter
## cannot tell from "no material here" — `docs/DECISIONS_LEDGER.md` D0238's trap. Visiting only cells the
## observation was actually given is what makes that distinction unnecessary, so it is checked directly:
## every cell in the visit rect must be inside the window.
func _test_it_never_visits_a_cell_the_observation_was_not_given() -> void:
	var view := Rect2(0.0, 0.0, 260.0, 200.0)
	var parts: Array = _observed(view, 2)
	var obs: Interface.Observation = parts[1]
	var r: Rect2i = TerrainPainter.visit_rect(obs, view, CELL)
	_check(r.get_area() > 0, "sanity: there are cells to visit (%s over window %s)" % [r, obs.window])
	var outside: int = 0
	for col: int in range(r.position.x, r.end.x):
		for row: int in range(r.position.y, r.end.y):
			if not obs.in_window(Vector2i(col, row)):
				outside += 1
	_check_over(r.get_area(), outside == 0,
		"every visited cell is inside the observation's window (%d of %d outside)" % [outside, r.get_area()])


## A camera pointed somewhere the observation does not cover must draw NOTHING, not everything. An
## intersection that silently produced a negative-size rect would loop zero times and look identical to
## this — so the control above (a view that DOES overlap and visits a positive area) is what makes this
## row mean something.
func _test_a_view_outside_the_window_visits_nothing_rather_than_everything() -> void:
	var view := Rect2(0.0, 0.0, 120.0, 120.0)
	var parts: Array = _observed(view, 2)
	var obs: Interface.Observation = parts[1]
	var far := Rect2(9000.0, 9000.0, 120.0, 120.0)
	var r: Rect2i = TerrainPainter.visit_rect(obs, far, CELL)
	_check(r.get_area() == 0, "a view far outside the window visits no cells (%s)" % r)
	_check(TerrainPainter.visit_rect(obs, view, CELL).get_area() > 0,
		"CONTROL: the overlapping view still visits cells -- without this a visit_rect that always "
		+ "returned an empty rect would satisfy the row above")


## The painter draws whatever the OBSERVATION says, and the observation is a copy of the grid. Checked by
## comparing the two over the whole visit rect: if the door dropped or reordered the material plane, the
## picture would be wrong in a way no rect assertion could see.
func _test_the_painter_reads_the_same_materials_the_grid_holds() -> void:
	var view := Rect2(0.0, 60.0, 240.0, 160.0)
	var parts: Array = _observed(view, 2)
	var grid: TileGrid = parts[0]
	var obs: Interface.Observation = parts[1]
	var r: Rect2i = TerrainPainter.visit_rect(obs, view, CELL)
	var mismatches: int = 0
	var solid_seen: int = 0
	for col: int in range(r.position.x, r.end.x):
		for row: int in range(r.position.y, r.end.y):
			var cell := Vector2i(col, row)
			var from_obs: StringName = obs.material_at(cell)
			var from_grid: StringName = grid.get_material(cell)
			if from_obs != from_grid:
				mismatches += 1
			if from_grid != &"":
				solid_seen += 1
	_check(solid_seen > 0,
		"sanity: the visited range actually contains solid rock (%d cells) -- over empty air every "
		% solid_seen + "comparison below is `\"\" == \"\"` and the check is vacuous")
	_check_over(r.get_area(), mismatches == 0,
		"every visited cell reports the material the grid holds (%d mismatches of %d)"
		% [mismatches, r.get_area()])


## Each of these is a real state a startup frame passes through. None may crash, and none may draw.
## `visit_rect` with a zero cell size is the one that would divide by zero.
func _test_an_incomplete_frame_paints_nothing() -> void:
	var canvas := Node2D.new()
	var parts: Array = _observed(Rect2(0.0, 0.0, 200.0, 200.0), 2)
	var obs: Interface.Observation = parts[1]
	_check(TerrainPainter.visit_rect(obs, Rect2(0.0, 0.0, 200.0, 200.0), 0).get_area() == 0,
		"a zero cell size visits nothing instead of dividing by it")
	var no_obs := Frame.new()
	no_obs.look = MaterialLook.new()
	var no_look := Frame.new()
	no_look.obs = obs
	var no_scale := Frame.new()
	no_scale.obs = Interface.Observation.new()
	no_scale.look = MaterialLook.new()
	for f: Frame in [no_obs, no_look, no_scale]:
		TerrainPainter.paint(f, canvas)
	TerrainPainter.paint(null, canvas)
	_check(true, "no observation, no palette, no cell size, no frame at all -- each paints nothing")
	# CONTROL: a complete frame has real work to do, so the rows above are not passing on a painter that
	# returns unconditionally.
	var complete := Frame.new()
	complete.obs = obs
	complete.look = MaterialLook.new()
	complete.view_world_rect = Rect2(0.0, 0.0, 200.0, 200.0)
	_check(TerrainPainter.visit_rect(complete.obs, complete.view_world_rect, obs.cell_px).get_area() > 0,
		"CONTROL: a complete frame does have cells to paint")
	canvas.free()


## THE ASSERTION THAT WOULD HAVE CAUGHT D0276'S OWN BUG, written after it bit rather than before.
##
## When terrain moved onto the coordinator at `z_index = -50`, the scene's own `_draw` still filled an
## OPAQUE 12,000px backdrop at z 0 — so the terrain was drawn and then completely covered. The capture
## showed the HUD, the miner and the cracks over flat grey. **Every suite passed**, because Godot exposes
## no way to read back a `CanvasItem`'s draw commands and nothing else asserted the ordering.
##
## This is the ordering as an assertion instead of as a comment. It cannot see a NEW opaque painter added
## above terrain — only the stack's own declared depths — but it pins the exact relationship that broke,
## and it fails loudly if someone raises the backdrop or lowers the terrain.
func _test_the_backdrop_is_the_lowest_thing_drawn() -> void:
	_check(RevealViewSetup.BACKDROP_Z < RevealViewSetup.SKY_Z,
		"the backdrop sits below the sky (%d < %d)" % [RevealViewSetup.BACKDROP_Z, RevealViewSetup.SKY_Z])
	_check(RevealViewSetup.SKY_Z < RevealViewSetup.TERRAIN_Z,
		"the sky sits below the terrain (%d < %d)" % [RevealViewSetup.SKY_Z, RevealViewSetup.TERRAIN_Z])
	_check(RevealViewSetup.TERRAIN_Z < 0,
		"and the terrain sits below the scene's own draw at z 0 (%d) -- the body, the mining overlay and "
		% RevealViewSetup.TERRAIN_Z + "the particles all draw there and must be in FRONT of the ground")
	# The tint is the part of the backdrop that can be silently wrong: a band lookup off by a row reads as
	# a slightly different grey nobody would question. Asserted as a real lerp toward the band rather than
	# as a literal colour, and against a control at a different depth.
	var look := MaterialLook.new()
	var shallow: Color = BackdropPainter.fill_color(look, 0)
	var deep: Color = BackdropPainter.fill_color(look, 200 * MaterialLook.CELLS_PER_METRE)
	_check(shallow != deep, "the backdrop is tinted by DEPTH, not one flat colour (%s vs %s)" % [shallow, deep])
	_check(BackdropPainter.fill_color(null, 0) == BackdropPainter.COLOR_BG,
		"and with no palette it falls back to the untinted fill rather than crashing")
