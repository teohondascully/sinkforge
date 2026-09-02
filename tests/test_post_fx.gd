extends "res://tests/test_base.gd"

## `view/visuals/post_fx.gdshader` + `view/visuals/post_fx_layer.gd` — legacy's lens and palette grade
## (D0328, `docs/PORT_ORDER.md` V3).
##
## **WHAT THIS SUITE CANNOT DO, stated first so its green is not over-read.** It does not render. A
## fragment shader's output is only observable by drawing it, and CI runs `--headless`. Nothing here
## asserts that the vignette darkens a corner or that the grade warms a highlight; those are capture
## comparisons on a headed run.
##
## What it CAN assert is everything that decides whether the pass is correctly WIRED, and that is where
## the real failure modes live: a lens over the HUD, an opaque rectangle where a shader failed to load, a
## Control eating the aim verb's mouse events, and a grain on a wall clock quietly voiding every
## capture-based verdict this repository takes.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_post_fx.gd


func _initialize() -> void:
	_test_the_lens_sits_above_the_world_and_below_the_hud()
	_test_the_pass_mounts_full_screen_and_does_not_eat_input()
	_test_the_grain_is_driven_by_the_deterministic_clock_not_a_wall_clock()
	_test_a_second_call_returns_the_same_layer_rather_than_stacking_a_second_grade()
	_finish("post_fx")


## The ordering that makes the whole design work, asserted between the two files that hold the numbers.
## A lens ABOVE the HUD grades and grains the readouts, which presents as "the UI looks a bit soft"
## rather than as a bug, and no capture-free test other than this one can see it.
func _test_the_lens_sits_above_the_world_and_below_the_hud() -> void:
	_check(PostFxLayer.POST_FX_CANVAS_LAYER < HudLayer.HUD_CANVAS_LAYER,
		"the lens (layer %d) draws under the HUD (layer %d), so the world is graded and the readouts "
			% [PostFxLayer.POST_FX_CANVAS_LAYER, HudLayer.HUD_CANVAS_LAYER] + "stay crisp")
	# ...and above the world, which is every `PaintLayer` on the coordinator's own Node2D -- canvas layer 0.
	_check(PostFxLayer.POST_FX_CANVAS_LAYER > 0,
		"and over the world painters, which draw on the default canvas layer 0")


## A ColorRect that does not cover the screen makes `SCREEN_UV` mean something other than the screen, and
## one that accepts mouse events swallows the aim verb -- which would present as "mining stopped working"
## with nothing pointing at a renderer.
func _test_the_pass_mounts_full_screen_and_does_not_eat_input() -> void:
	var fx := PostFxLayer.new()
	root.add_child(fx)
	var ok: bool = fx.setup()
	_check(ok, "the shader loads and the pass mounts")
	var rects: Array[ColorRect] = []
	for child: Node in fx.get_children():
		if child is ColorRect:
			rects.append(child as ColorRect)
	_check_over(1, rects.size() == 1, "exactly one full-screen rect, not a stack -- found %d" % rects.size())
	if rects.size() == 1:
		var r: ColorRect = rects[0]
		_check(r.material is ShaderMaterial and (r.material as ShaderMaterial).shader != null,
			"it carries the shader -- a rect with no material is an OPAQUE BOX over the whole world")
		_check(r.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"and ignores the mouse, so the aim verb's events reach the game")
		_check(r.anchor_right == 1.0 and r.anchor_bottom == 1.0,
			"anchored full-rect (%.1f, %.1f), so SCREEN_UV spans the screen" % [r.anchor_right, r.anchor_bottom])
	fx.free()


## **THE ADAPTATION THIS PORT EXISTS TO GET RIGHT.** Legacy seeds the grain from `TIME`, a wall clock;
## this project's screenshot discipline requires the renderer be a function of state, so two captures of
## one tick are byte-comparable. A wall-clock grain would void every capture-based verdict silently — the
## captures would simply differ, and the difference would be read as whatever change was being measured.
##
## Asserted against the SHADER SOURCE, because that is where the defect would live and no runtime read of
## a uniform can see a `TIME` reference in a fragment body.
func _test_the_grain_is_driven_by_the_deterministic_clock_not_a_wall_clock() -> void:
	var f := FileAccess.open("res://view/visuals/post_fx.gdshader", FileAccess.READ)
	_check(f != null, "the shader source is readable")
	if f == null:
		return
	var src: String = f.get_as_text()
	f.close()
	_check(src.contains("uniform float anim_time"),
		"the shader takes an `anim_time` uniform")
	# The grain line must use it. Checked as the actual expression rather than as "contains anim_time",
	# so declaring the uniform and then ignoring it does not pass.
	_check(src.contains("fract(anim_time * time_scale"),
		"and the grain seed is fed that uniform")
	# CONTROL, and the one that matters: no `TIME` anywhere in the shader body. Without this row the two
	# above pass on a shader that declares and uses `anim_time` AND still mixes `TIME` into the hash.
	var body: String = src
	var lines: PackedStringArray = body.split("\n")
	var time_refs: int = 0
	for line: String in lines:
		var code: String = line.split("//")[0]     # strip comments: the header discusses `TIME` by name
		if code.contains("TIME"):
			time_refs += 1
	_check(time_refs == 0,
		"CONTROL: no wall-clock `TIME` reference survives in shader CODE (%d found, comments excluded) -- "
			% time_refs + "so the rows above describe the only clock this pass reads")
	# And the layer actually pushes the clock through.
	var fx := PostFxLayer.new()
	root.add_child(fx)
	fx.setup()
	fx.set_anim_time(1.25)
	var rects: Array[ColorRect] = []
	for child: Node in fx.get_children():
		if child is ColorRect:
			rects.append(child as ColorRect)
	if rects.size() == 1:
		var mat: ShaderMaterial = rects[0].material as ShaderMaterial
		_check(absf(float(mat.get_shader_parameter(&"anim_time")) - 1.25) < 0.001,
			"and `set_anim_time` reaches the uniform (%s)" % mat.get_shader_parameter(&"anim_time"))
	fx.free()


## A second `add_post_fx()` must return the SAME layer. Two stacked passes apply the vignette and the
## grade twice, which reads as "the corners are too dark" rather than as a doubled layer -- the same trap
## `WorldView.add_hud` already guards, where a second call would have doubled every chip.
func _test_a_second_call_returns_the_same_layer_rather_than_stacking_a_second_grade() -> void:
	var grid: TileGrid = TileGrid.new(48, 48, 7)
	for col: int in range(48):
		for row: int in range(24, 48):
			grid.set_material(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(96), Fx.from_int(80))
	var view := WorldView.new()
	root.add_child(view)
	view.setup(Interface.new(grid, body, Mining.new()), MaterialLook.new(), null)
	var a: PostFxLayer = view.add_post_fx()
	var b: PostFxLayer = view.add_post_fx()
	_check(a != null, "the coordinator mounts a lens")
	_check(a == b, "and a second call returns the same one rather than stacking a second grade")
	var count: int = 0
	for child: Node in view.get_children():
		if child is PostFxLayer:
			count += 1
	_check_over(1, count == 1, "exactly one lens on the coordinator -- found %d" % count)
	view.free()
