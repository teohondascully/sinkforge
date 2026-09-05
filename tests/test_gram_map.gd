extends "res://tests/test_base.gd"
## D0379. `view/visuals/gram_map.gd` + `rock_tooth.gdshader` + `WorldView.add_tooth`: the grammar map the
## tooth stretches its hash by. It does not render (headless). It asserts: the map is one byte per cell at
## the world's size; a fill writes each material's grammar and 0 for air; the texture is created once and
## updated in place; a refill after a dig changes the byte; the tooth shader loads with the grammar
## sampler and the per-grammar cells and is direction-aware (bedded wide, massive tall); `add_tooth`
## declines gracefully when the bake declined; the bake's cell rect conversion.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_gram_map.gd
const CELL: int = Heightfield.TERRAIN_CELL_PX
const ROCK_TOP: int = MaterialLook.SURFACE_ROW + 8
const GRID_W: int = 40
const GRID_H: int = ROCK_TOP + 40


func _initialize() -> void:
	_test_the_map_is_a_byte_per_cell()
	_test_a_fill_writes_grammars_and_a_refill_moves_them()
	_test_the_tooth_shader()
	_test_add_tooth_declines_without_a_bake()
	_finish("gram_map")


func _test_the_map_is_a_byte_per_cell() -> void:
	var g: GramMap = GramMap.new()
	_check(g.setup(Vector2i(40, 60)) and g.size() == Vector2i(40, 60), "sized to the world in cells")
	_check(not GramMap.new().setup(Vector2i(0, 5)) and not GramMap.new().setup(Vector2i(GramMap.MAX_SIDE + 1, 5)), "an empty or oversized world is refused")
	_check(g.grammar_at(Vector2i(3, 3)) == 0 and g.grammar_at(Vector2i(-1, 0)) == -1 and g.grammar_at(Vector2i(40, 0)) == -1, "unfilled cells read clastic; out of range reads -1")
	var t: ImageTexture = g.texture()
	_check(t != null and t.get_width() == 40 and t.get_height() == 60, "the texture matches the map")
	_check(g.texture() == t, "...and is the same object on the next call: updated in place, never re-created")
	_check(GramMap.new().texture() == null, "no map, no texture")


func _test_a_fill_writes_grammars_and_a_refill_moves_them() -> void:
	var grid: TileGrid = TileGrid.new(GRID_W, GRID_H, 11)
	for col: int in range(GRID_W):
		for row: int in range(ROCK_TOP, GRID_H):
			grid.set_material(Vector2i(col, row), &"clay" if col < 10 else (&"hardrock" if col < 20 else &"deepstone"))
	var body: Body = Body.new(Fx.from_int(GRID_W * CELL / 2), Fx.from_int(4 * CELL))
	var iface: Interface = Interface.new(grid, body, Mining.new())
	var view := Rect2(0.0, 0.0, float(GRID_W * CELL), float(GRID_H * CELL))
	var obs: Interface.Observation = iface.observe(Interface.Envelope.covering(view, WorldView.WINDOW_MARGIN_CELLS))
	var look: MaterialLook = MaterialLook.new()
	var g: GramMap = GramMap.new()
	g.setup(Vector2i(GRID_W, GRID_H))
	g.fill_rect(obs, Rect2i(0, 0, GRID_W, GRID_H), look)
	_check(g.grammar_at(Vector2i(5, ROCK_TOP + 2)) == look.grammar_of(&"clay"), "clay's cells carry clay's grammar (%d)" % g.grammar_at(Vector2i(5, ROCK_TOP + 2)))
	_check(g.grammar_at(Vector2i(15, ROCK_TOP + 2)) == look.grammar_of(&"hardrock") and g.grammar_at(Vector2i(25, ROCK_TOP + 2)) == look.grammar_of(&"deepstone"), "...hardrock's and deepstone's theirs")
	_check(look.grammar_of(&"clay") != look.grammar_of(&"hardrock") or look.grammar_of(&"hardrock") != look.grammar_of(&"deepstone"), "control: the fixture's three materials do not all share one grammar")
	_check(g.grammar_at(Vector2i(5, ROCK_TOP - 2)) == 0, "air is 0")
	var t: ImageTexture = g.texture()
	grid.excavate(Vector2i(15, ROCK_TOP + 2))
	var dug: Interface.Observation = iface.observe(Interface.Envelope.covering(view, WorldView.WINDOW_MARGIN_CELLS))
	g.fill_rect(dug, Rect2i(14, ROCK_TOP + 1, 3, 3), look)
	_check(g.grammar_at(Vector2i(15, ROCK_TOP + 2)) == 0 and g.grammar_at(Vector2i(16, ROCK_TOP + 2)) == look.grammar_of(&"hardrock"), "a dug cell refilled reads air; its neighbour keeps its rock")
	_check(g.texture() == t, "...through the same texture object")
	var bake: TerrainBake = TerrainBake.new()
	bake.plan(Vector2i(GRID_W, GRID_H), CELL)
	_check(bake.cells_of(Rect2(8.0, 12.0, 16.0, 8.0)) == Rect2i(2, 3, 4, 2), "the bake reads a pixel rect back to the cells it covers (%s)" % str(bake.cells_of(Rect2(8.0, 12.0, 16.0, 8.0))))
	bake.free()


func _test_the_tooth_shader() -> void:
	var shader: Shader = load("res://view/visuals/rock_tooth.gdshader") as Shader
	_check(shader != null, "the tooth shader loads")
	if shader == null:
		return
	var code: String = shader.code
	_check("blend_add" in code, "it adds: the one rock pass over the veil")
	_check("gram_tex" in code and "hint_default_black" in code, "it samples the grammar map and reads clastic when unbound")
	_check("TIME" not in code, "no wall clock anywhere in it")
	# A material answers null for a uniform never set, and headless the server holds no compiled default
	# either, so the defaults are read off the source: `uniform vec2 NAME = vec2(x, y);`.
	var bedded: Vector2 = _default_vec2(code, "cell_bedded")
	var massive: Vector2 = _default_vec2(code, "cell_massive")
	var clastic: Vector2 = _default_vec2(code, "cell_clastic")
	_check(bedded.x > bedded.y and massive.y > massive.x and is_equal_approx(clastic.x, clastic.y), "direction-aware: bedded runs flat, massive steep, soil square (%s %s %s)" % [str(bedded), str(massive), str(clastic)])
	# D0398: legacy's 1/32 m cell was one screen pixel at the player's zoom and read as static; the tooth
	# samples every 2 world px now (an eighth of a metre), at half the weight. Pinned as the cell in metres.
	_check("TOOTH_SAMPLES_PER_WORLD_PX = 0.5" in code, "the tooth cell is an eighth of a metre: two world px a sample (D0398)")
	_check("tooth_add : hint_range(0.0, 0.12) = 0.030" in code, "...at half legacy's weight, so it grits the bake rather than covering it")


func _test_add_tooth_declines_without_a_bake() -> void:
	var grid: TileGrid = _flat_grid(ROCK_TOP, GRID_W)
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(4 * CELL))
	var view: WorldView = WorldView.new()
	root.add_child(view)
	view.setup(Interface.new(grid, body, Mining.new()), MaterialLook.new(), null)
	view.add_baked_painter(TerrainPainter.paint)
	var baked: bool = view.bake_static(-60)
	_check(not baked, "control: headless declines the bake")
	_check(not ToothLayer.mount(view, -44), "...so there is no target to read and the tooth declines with it, mounting nothing")
	_check(not ToothLayer.mount(null, -44), "no view, no tooth")
	view.queue_free()


func _default_vec2(code: String, name: String) -> Vector2:
	var rx := RegEx.new()
	rx.compile("uniform\\s+vec2\\s+" + name + "\\s*=\\s*vec2\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)\\s*\\)")
	var m: RegExMatch = rx.search(code)
	if m == null:
		return Vector2(-1.0, -1.0)
	return Vector2(float(m.get_string(1)), float(m.get_string(2)))
