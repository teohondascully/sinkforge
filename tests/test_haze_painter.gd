extends "res://tests/test_base.gd"
## D0379. `view/visuals/haze_painter.gd` + `heat_haze.gdshader`: the heat-haze plumes. What this suite cannot
## do, first: it does not render a displacement (headless). It asserts the wiring and the rules: only a
## working furnace or generator convects; the plume roots at the casing top, is 0.72 of a cell wide, rises
## 2.1 cells and tapers; its alpha is the shader's mask, full at the base and nothing at the top; the shader
## loads with the mask uniforms and takes the deterministic clock, not TIME; the painter feeds that clock
## into its layer's material on a real view.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_haze_painter.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_only_hot_working_machines_convect()
	_test_the_plume_geometry_and_mask()
	_test_the_shader_takes_the_deterministic_clock()
	await _test_the_painter_feeds_the_clock_on_a_real_view()
	_finish("haze_painter")


func _test_only_hot_working_machines_convect() -> void:
	_check(HazePainter.is_hot(_machine_rec(&"iron_forge", Vector2i(3, 3))), "a working forge convects")
	_check(HazePainter.is_hot(_machine_rec(&"generator", Vector2i(4, 3), &"working", {"fuel": 2})), "...so does a working burner")
	_check(not HazePainter.is_hot(_machine_rec(&"iron_forge", Vector2i(3, 3), &"no_input")), "an idle forge does not")
	_check(not HazePainter.is_hot(_machine_rec(&"drill", Vector2i(5, 3))), "a working drill is not forge-style: no shimmer over every module")
	var o := Interface.Observation.new()
	o.machines = [_machine_rec(&"iron_forge", Vector2i(3, 3)), _machine_rec(&"drill", Vector2i(5, 3)), _machine_rec(&"generator", Vector2i(6, 3), &"no_fuel")]
	_check(HazePainter.plumes(o).size() == 1, "one plume for the forge alone (%d)" % HazePainter.plumes(o).size())
	_check(HazePainter.plumes(null).is_empty(), "no observation, no plumes")


func _test_the_plume_geometry_and_mask() -> void:
	var p: Dictionary = HazePainter.plume(Vector2i(3, 5))
	var pts: PackedVector2Array = p["pts"]
	var cols: PackedColorArray = p["cols"]
	_check(pts.size() == 4 and cols.size() == 4, "a quad with a colour per vertex")
	var cell: float = HazePainter.CELL
	_check(is_equal_approx(pts[1].x - pts[0].x, cell * 0.72), "0.72 of a cell wide at the base (%.2f)" % (pts[1].x - pts[0].x))
	_check(is_equal_approx(pts[0].y - pts[3].y, cell * 2.1), "rising 2.1 cells (%.2f)" % (pts[0].y - pts[3].y))
	_check(pts[2].x - pts[3].x < pts[1].x - pts[0].x, "tapering toward the top")
	_check(is_equal_approx(pts[0].y, 5.0 * cell + 2.0 * HazePainter.S), "rooted two legacy pixels below the casing top, at half")
	_check(is_equal_approx(cols[0].a, 0.85) and is_equal_approx(cols[1].a, 0.85) and cols[2].a == 0.0 and cols[3].a == 0.0, "the mask is full at the base and nothing at the top")


func _test_the_shader_takes_the_deterministic_clock() -> void:
	var shader: Shader = load("res://view/visuals/heat_haze.gdshader") as Shader
	_check(shader != null, "the shader loads")
	if shader == null:
		return
	var code: String = _uncommented(shader.code)
	_check("anim_time" in code and "TIME" not in code.replace("anim_time", ""), "it climbs on anim_time, never on TIME (the capture discipline)")
	_check("hint_screen_texture" in code and "strength_px" in code and "COLOR.a" in code, "it reads the screen, has a strength, and takes the vertex alpha as its mask")
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(&"anim_time", 3.5)
	_check(is_equal_approx(float(mat.get_shader_parameter(&"anim_time")), 3.5), "the clock uniform is settable")


func _test_the_painter_feeds_the_clock_on_a_real_view() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	machines.place(world, MachineDef.of(&"iron_forge"), Vector2i(3, 14))
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var ran: Array = [0]
	var layer: PaintLayer = view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		HazePainter.paint(f, ci)
		ran[0] = int(ran[0]) + 1)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://view/visuals/heat_haze.gdshader") as Shader
	layer.material = mat
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint() ran on a real view over a forge (%d)" % int(ran[0]))
	_check(is_equal_approx(float(mat.get_shader_parameter(&"anim_time")), view.anim_time()), "...and left the layer's clock at the view's anim_time (%.3f)" % float(mat.get_shader_parameter(&"anim_time")))
	view.queue_free()


## The shader's code with its `//` comments stripped, so a comment that NAMES the wall clock cannot be
## mistaken for a use of it.
func _uncommented(code: String) -> String:
	var out: PackedStringArray = PackedStringArray()
	for line: String in code.split("\n"):
		var cut: int = line.find("//")
		out.append(line if cut < 0 else line.substr(0, cut))
	return "\n".join(out)
