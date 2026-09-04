class_name ToothLayer
extends RefCounted

## THE ROCK TOOTH'S CANVAS (A' step 6p, D0379): the baked terrain quad drawn a SECOND time, above the veil,
## through `rock_tooth.gdshader` -- additive absolute value levels that survive the multiply, their hash
## cell stretched per material by the bake's grammar map (`GramMap`, `TerrainBake.gram_texture`).
##
## Nothing mounts when the bake declined (headless): the tooth is a reading of the target, and there is no
## target. Lives here rather than on `WorldView` so the coordinator stays under its size cap and knows
## nothing about which shaders read its bake.

const SHADER_PATH: String = "res://view/visuals/rock_tooth.gdshader"


## Mounts the tooth over `view`'s bake at `z`. Returns whether it mounted.
static func mount(view: WorldView, z: int) -> bool:
	if view == null:
		return false
	var bake: TerrainBake = view.terrain_bake()
	if bake == null:
		return false
	var shader: Shader = load(SHADER_PATH) as Shader
	if shader == null:
		return false
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter(&"gram_tex", bake.gram_texture())
	var tooth: PaintLayer = view.add_painter(Callable(bake, &"draw_quad"))
	tooth.z_index = z
	tooth.material = mat
	tooth.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return true
