extends "res://tests/test_base.gd"

## `view/visuals/veil_map.gd` — the lightmap that replaced a `draw_rect` per visible cell (D0336).
##
## The old path issued one draw call per visible cell: **14,080 of them at the 40-metre framing, measured
## at 41.47 ms of a 54.23 ms frame** against a 120 Hz budget of 8.33 ms. The new one uploads a small
## texture and issues ONE, which is legacy's own shape (`legacy/scenes/world_renderer.gd:330`, `:2769`).
##
## **THE PROPERTY THAT ACTUALLY MATTERS HERE IS THE RESOLUTION**, not the speed. Legacy's veil is "one
## texel per cell" and legacy's cell was one METRE; this build's terrain cell is a QUARTER metre, so
## reading that sentence literally gives 16x the texels for the same picture — D0305/D0310's regime trap,
## in the direction that costs rather than the direction that breaks. So the first test asserts metres and
## carries the literal reading as its control.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_veil_map.gd

const GRID_W: int = 64
const GRID_H: int = 96
const ROCK_TOP: int = 12
const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_the_map_is_at_metre_resolution_not_cell_resolution()
	_test_every_texel_equals_the_per_cell_reference_at_its_centre()
	_test_the_stretched_rect_covers_every_cell_the_map_sampled()
	_test_a_degenerate_window_declines_rather_than_returning_black()
	_finish("veil_map")


## A world solid from `ROCK_TOP` down, with a chamber cut so the field is not uniform — a map built over
## a world with one light level everywhere would pass a resolution check by accident.
func _world() -> Interface.Observation:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 5)
	for col: int in range(GRID_W):
		for row: int in range(ROCK_TOP, GRID_H):
			grid.set_material(Vector2i(col, row), &"clay")
			grid.set_wall(Vector2i(col, row), &"clay")
	for col: int in range(20, 34):
		for row: int in range(40, 54):
			grid.excavate(Vector2i(col, row))
	var body: Body = Body.new(Fx.from_int(GRID_W * CELL / 2), Fx.from_int(4 * CELL))
	var iface: Interface = Interface.new(grid, body, Mining.new())
	var view := Rect2(0.0, 0.0, float(GRID_W * CELL), float(GRID_H * CELL))
	return iface.observe(Interface.Envelope.covering(view, WorldView.WINDOW_MARGIN_CELLS))


## ONE TEXEL PER METRE. Asserted as the ratio against the window's CELL count, so it stays true if either
## the terrain cell size or `CELLS_PER_METRE` moves, rather than pinning a literal that would quietly stop
## describing the grid it was written against.
func _test_the_map_is_at_metre_resolution_not_cell_resolution() -> void:
	var obs: Interface.Observation = _world()
	var painter: VeilPainter = VeilPainter.new()
	var field: PackedFloat32Array = painter.field_for(obs)
	var map: VeilMap = VeilMap.new()
	var win: Rect2i = obs.window
	var tex: ImageTexture = map.build(win, func(c: int, r: int) -> float:
		return VeilPainter.light_at(obs, win, field, c, r))
	_check(tex != null, "a non-degenerate window produces a texture")
	var want := Vector2i(
		int(ceil(float(win.size.x) / float(MaterialLook.CELLS_PER_METRE))),
		int(ceil(float(win.size.y) / float(MaterialLook.CELLS_PER_METRE))))
	_check(map.size() == want,
		"the map is %s texels for a %s-cell window -- one per metre, not one per cell"
		% [map.size(), win.size])
	# CONTROL: the literal reading of legacy's sentence. Without this row the assertion above would be
	# satisfied by a map that happened to match on a window whose size divided evenly, and the whole point
	# is that the cell-resolution reading is a DIFFERENT and much larger number.
	_check(map.size().x < win.size.x and map.size().y < win.size.y,
		"CONTROL: cell resolution would be %s texels, %.1fx more than the %s this builds -- so the row "
		% [win.size, float(win.size.x * win.size.y) / float(maxi(1, map.size().x * map.size().y)),
		map.size()] + "above is a real claim about the regime and not true of every map")


## THE PICTURE MUST NOT HAVE MOVED. Each texel is the reference expression evaluated at the cell the map
## says it sampled — the CENTRE of the metre, not its corner. A corner sample biases the whole map half a
## metre up-left, which is invisible in a still frame of uniform rock and obvious at the surface line.
func _test_every_texel_equals_the_per_cell_reference_at_its_centre() -> void:
	var obs: Interface.Observation = _world()
	var painter: VeilPainter = VeilPainter.new()
	var field: PackedFloat32Array = painter.field_for(obs)
	var map: VeilMap = VeilMap.new()
	var win: Rect2i = obs.window
	map.build(win, func(c: int, r: int) -> float:
		return VeilPainter.light_at(obs, win, field, c, r))
	var size: Vector2i = map.size()
	var half: int = VeilMap.CELLS_PER_TEXEL / 2
	var worst: float = 0.0
	var varied: int = 0
	for j: int in size.y:
		for i: int in size.x:
			var col: int = win.position.x + i * VeilMap.CELLS_PER_TEXEL + half
			var row: int = win.position.y + j * VeilMap.CELLS_PER_TEXEL + half
			var want: float = clampf(VeilPainter.light_at(obs, win, field, col, row), 0.0, 1.0)
			# READ BACK WHAT THE MAP WROTE. Deriving this from `want` compares a value to a quantised copy
			# of itself and is true whatever `_fill` did -- the first version of this test did exactly that
			# and a corner-sample mutant walked straight through it.
			var got: float = map.texel(i, j)
			worst = maxf(worst, absf(got - want))
			if want > 0.01 and want < 0.99:
				varied += 1
	# Half a step of 1/255 is the whole error an 8-bit quantisation can introduce; anything larger means
	# the map sampled somewhere other than where it claims.
	_check(worst <= 0.5 / 255.0 + 1e-6,
		"every texel is its reference value to within one 8-bit step (worst %.5f)" % worst)
	# The fixture must actually pose a GRADIENT. A world that came back all-dark or all-lit would satisfy
	# the equality above trivially -- the error path returning the passing value.
	_check(varied > 20,
		"the fixture poses a real gradient: %d texels are strictly between dark and lit" % varied)


## The stretched rect must cover exactly the cells the map sampled. It is derived from the texel count and
## not from the window, because the `ceil` above can make the map wider than the window — stretching that
## map to the window's own width would shear the entire gradient by up to a metre.
func _test_the_stretched_rect_covers_every_cell_the_map_sampled() -> void:
	var obs: Interface.Observation = _world()
	var painter: VeilPainter = VeilPainter.new()
	var field: PackedFloat32Array = painter.field_for(obs)
	var map: VeilMap = VeilMap.new()
	var win: Rect2i = obs.window
	map.build(win, func(c: int, r: int) -> float:
		return VeilPainter.light_at(obs, win, field, c, r))
	var rect: Rect2 = map.world_rect(CELL)
	var size: Vector2i = map.size()
	_check(rect.position == Vector2(float(win.position.x * CELL), float(win.position.y * CELL)),
		"the rect starts at the window's own first cell (%s)" % rect.position)
	_check(rect.size == Vector2(
		float(size.x * VeilMap.CELLS_PER_TEXEL * CELL), float(size.y * VeilMap.CELLS_PER_TEXEL * CELL)),
		"and spans exactly the sampled cells, not the window's (%s)" % rect.size)
	# It must never UNDER-cover: a rect short of the window leaves the far edge sampling past the texture
	# and clamping to its last texel, which reads as a bar of stale light at the screen edge.
	_check(rect.end.x >= float(win.end.x * CELL) and rect.end.y >= float(win.end.y * CELL),
		"and it reaches at least the window's far edge, so no edge samples off the map (%s vs %s)"
		% [rect.end, Vector2(float(win.end.x * CELL), float(win.end.y * CELL))])


## A degenerate window must produce NO texture rather than a black one. `build` returning a texture for an
## empty rect would have the caller stretch a 0-texel map over the world, and an unwritten map is black:
## the failure would arrive as a fully dark screen, which reads as a lighting bug rather than as an empty
## observation.
func _test_a_degenerate_window_declines_rather_than_returning_black() -> void:
	var map: VeilMap = VeilMap.new()
	var got: ImageTexture = map.build(Rect2i(0, 0, 0, 0), func(_c: int, _r: int) -> float: return 1.0)
	_check(got == null, "an empty window returns null, not a black map")
