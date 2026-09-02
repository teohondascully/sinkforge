extends "res://tests/test_base.gd"

## `view/visuals/rock_grit.gdshader` and the bake quad's sampling (D0331, `docs/PORT_ORDER.md` V3).
##
## **BOTH SUBJECTS HERE WERE FOUND BY LOOKING AT A CAPTURE, NOT BY A GATE**, and neither is visible to any
## assertion over content. The bake is pixel-identical to the per-frame path in what it DRAWS, which is
## what `test_terrain_bake.gd` checks; the filter is applied when the finished target is drawn OUT, and
## the sub-cell tooth runs per screen pixel after that. A suite can only assert that the wiring is right.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_rock_grit.gd


func _initialize() -> void:
	_test_the_baked_quad_is_sampled_nearest_not_blurred()
	_test_the_tooth_runs_in_world_space_and_is_scale_converted()
	_finish("rock_grit")


## **PIXEL ART THROUGH A BLUR.** The SubViewport's `canvas_item_default_texture_filter` governs how the
## chunk painters draw INTO the target and says nothing about how the finished target is sampled when it
## is drawn OUT. On the canvas default (linear) every baked texel is bilinearly interpolated across the
## screen pixels it covers once the camera magnifies it, and the whole terrain reads as soft brown mush.
##
## Asserted on the layer that draws the quad, because that is where the property lives -- the texture is
## correct either way and no comparison of baked-versus-live content can see it.
func _test_the_baked_quad_is_sampled_nearest_not_blurred() -> void:
	var grid: TileGrid = TileGrid.new(64, 64, 7)
	for col: int in range(64):
		for row: int in range(32, 64):
			grid.set_material(Vector2i(col, row), &"clay")
			grid.set_wall(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(128), Fx.from_int(80))
	var view := WorldView.new()
	root.add_child(view)
	view.setup(Interface.new(grid, body, Mining.new()), MaterialLook.new(), null)
	view.add_baked_painter(WallPainter.paint)
	view.add_baked_painter(TerrainPainter.paint)
	view.bake_static(-60)
	# Headless takes the FALLBACK path, where each painter is its own layer drawing solid rects -- no
	# texture, so nothing to filter. The quad only exists when the bake is live, so this suite asserts the
	# property on whichever layers exist and says which case it observed rather than passing silently.
	var layers: Array[PaintLayer] = []
	for child: Node in view.get_children():
		if child is PaintLayer:
			layers.append(child as PaintLayer)
	_check_over(layers.size(), layers.size() > 0, "the coordinator mounted at least one layer")
	if view.terrain_bake() != null:
		var quad: PaintLayer = layers[layers.size() - 1]
		_check(quad.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"the baked quad samples NEAREST (%d), not the canvas default" % quad.texture_filter)
		_check(quad.material is ShaderMaterial,
			"and carries the sub-cell tooth, which must run per SCREEN pixel and so cannot live in the "
				+ "bake -- a tooth painted into the target would be one value per cell")
	else:
		_check(true, "OBSERVED the headless fallback: solid rects, no texture, so no filter to assert. "
			+ "The quad's filter is exercised only on a headed run (see this suite's header)")
	view.free()


## The tooth is a WORLD-space grain and its scale had to be converted. Legacy's world is 32 px/metre and
## this build's is 16, so a tooth sampled per OUR world pixel would be twice the physical size legacy
## authored -- coarse speckle instead of roughness. Asserted against the shader source, since a uniform's
## runtime value cannot show which coordinate a hash was fed.
func _test_the_tooth_runs_in_world_space_and_is_scale_converted() -> void:
	var f := FileAccess.open("res://view/visuals/rock_grit.gdshader", FileAccess.READ)
	_check(f != null, "the shader source is readable")
	if f == null:
		return
	var src: String = f.get_as_text()
	f.close()
	_check(src.contains("world_pos = VERTEX"),
		"the grain is keyed to WORLD position -- legacy: a grain that sits still while the rock slides "
			+ "under it reads as dirt on the lens, not as roughness")
	_check(src.contains("TOOTH_SAMPLES_PER_WORLD_PX = 2.0"),
		"and is sampled at 2x this build's world pixel, restoring legacy's 1/32-metre tooth cell")
	# CONTROL: it must NOT read SCREEN_UV. That is `post_fx.gdshader`'s job (D0328) and the two are
	# different passes for a stated reason; a tooth on screen coordinates is the lens-dirt failure above.
	_check(not src.contains("SCREEN_UV"),
		"CONTROL: no SCREEN_UV here -- the screen-space grain is post_fx's, and shipping only one of the "
			+ "two is why the rock read flat while the frame read filmic")
