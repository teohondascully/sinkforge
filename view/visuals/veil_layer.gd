class_name VeilLayer
extends RefCounted

## THE VEIL'S GPU PAINTER (D0390). Feeds `view/visuals/veil.gdshader` and draws one rect over the visible
## world; the shader evaluates `VeilPainter`'s light expression per pixel. `VeilPainter` stays as the
## specification and the CPU reference (`tests/test_veil_painter.gd` pins its terms); this file owns only
## what the GPU needs handed to it, and hands it as little as possible:
##
## - `cells_tex`: the observation's material plane, uploaded BYTE FOR BYTE (`Observation.materials` is
##   already one ordinal per cell, 0 = air) -- no loop, re-uploaded only when the window or the terrain
##   version moves.
## - `field_tex`: the blurred openness at one texel per metre (`openness_metres`), off the coarse map --
##   rebuilt only when the window or the map's own version moves; ~6K samples, not the ~100K the
##   cell-resolution field cost on every camera move (60-76 ms, the whole of the movement lag, 2026-09-04).
## - the lamp's three cuts and every other source (`VeilSources.cuts_for`) as uniform arrays, per frame.
##
## Mounted with `render_mode blend_mul` in the shader, so the layer needs no material of its own.

const SHADER_PATH: String = "res://view/visuals/veil.gdshader"
const MAX_CUTS: int = 64
const PER_M: int = MaterialLook.CELLS_PER_METRE

var material: ShaderMaterial = null
var _cells_img: Image = null
var _cells_tex: ImageTexture = null
var _cells_key: Array = []
var _walls_img: Image = null
var _walls_tex: ImageTexture = null
var _sky_img: Image = null
var _sky_tex: ImageTexture = null
var _field_img: Image = null
var _field_tex: ImageTexture = null
var _field_key: Array = []
var _ore: OrePainter = null
var _falling: FallingItems = null
## Uploads, for the instrument and the suite: a frame that moved nothing uploads nothing.
var cell_uploads: int = 0
var field_uploads: int = 0


func _init(ore: OrePainter = null, falling: FallingItems = null) -> void:
	_ore = ore
	_falling = falling
	var shader: Shader = load(SHADER_PATH) as Shader
	if shader != null:
		material = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter(&"cell_px", float(Interface.Observation.CELL_PX))
		material.set_shader_parameter(&"cells_per_metre", float(PER_M))
		material.set_shader_parameter(&"surface_row", float(MaterialLook.SURFACE_ROW))
		material.set_shader_parameter(&"mass_shade", VeilPainter.MASS_SHADE)
		material.set_shader_parameter(&"key_strength", VeilPainter.KEY_STRENGTH)
		material.set_shader_parameter(&"key_gain", VeilPainter.KEY_GAIN)
		material.set_shader_parameter(&"openness_saturate", VeilPainter.OPENNESS_SATURATE)
		material.set_shader_parameter(&"ambient_dark", VeilPainter.AMBIENT_DARK)
		material.set_shader_parameter(&"sky_reach_m", VeilPainter.SKY_REACH_M)
		material.set_shader_parameter(&"surface_line_m", VeilPainter.SURFACE_LINE_M)
		material.set_shader_parameter(&"lamp_grain", VeilPainter.LAMP_GRAIN)
		material.set_shader_parameter(&"lamp_window_gain", VeilPainter.LAMP_WINDOW_GAIN)
		material.set_shader_parameter(&"sky_fade_m", VeilLight.SKY_FADE_M)
		material.set_shader_parameter(&"ambient_light", Vector3(VeilLight.AMBIENT_LIGHT.r, VeilLight.AMBIENT_LIGHT.g, VeilLight.AMBIENT_LIGHT.b))
		material.set_shader_parameter(&"void_floor", VeilLight.VOID_FLOOR)
		var tint: Color = VeilLight.lamp_tint()
		material.set_shader_parameter(&"lamp_tint", Vector3(tint.r, tint.g, tint.b))


## The blurred openness at ONE SAMPLE PER METRE off the observation's coarse map (`Observation.map`, the
## grid's class byte per logic cell), over `rect_m` in metres: rock and ore are mass, void and wall are
## open. Legacy's own resolution -- its cell was a metre -- with `VeilPainter.MASS_REACH_M` as the reach.
static func openness_metres(obs: Interface.Observation, rect_m: Rect2i) -> PackedByteArray:
	var w: int = rect_m.size.x
	var h: int = rect_m.size.y
	var raw := PackedFloat32Array()
	raw.resize(w * h)
	var mw: int = obs.map_cells.x
	var last := Vector2i(maxi(obs.map_cells.x - 1, 0), maxi(obs.map_cells.y - 1, 0))
	var have_map: bool = obs.map.size() >= obs.map_cells.x * obs.map_cells.y and mw > 0
	for row: int in h:
		var my: int = clampi(rect_m.position.y + row, 0, last.y)
		for col: int in w:
			var mx: int = clampi(rect_m.position.x + col, 0, last.x)
			var cls: int = obs.map[my * mw + mx] if have_map else Interface.Observation.MAP_VOID
			raw[row * w + col] = 0.0 if (cls == Interface.Observation.MAP_ROCK or cls == Interface.Observation.MAP_ORE) else 1.0
	var reach: int = int(VeilPainter.MASS_REACH_M)
	var blur: PackedFloat32Array = VeilPainter._blur_axis(VeilPainter._blur_axis(raw, w, h, true, reach), w, h, false, reach)
	var out := PackedByteArray()
	out.resize(w * h)
	for i: int in w * h:
		out[i] = int(round(clampf(blur[i], 0.0, 1.0) * 255.0))
	return out


## The metre rect that covers a cell window, floor and ceil so every cell has a texel.
static func metre_rect_of(window: Rect2i) -> Rect2i:
	var lo := Vector2i(floori(float(window.position.x) / float(PER_M)), floori(float(window.position.y) / float(PER_M)))
	var hi := Vector2i(ceili(float(window.end.x) / float(PER_M)), ceili(float(window.end.y) / float(PER_M)))
	return Rect2i(lo, hi - lo)


## The lamp's three cuts as the shader takes them: xy centre and z radius in cells, w strength scaled
## by depth -- `VeilPainter.lamp_lift`'s own table, in its own order.
static func lamp_cuts(obs: Interface.Observation) -> PackedVector4Array:
	var m: float = float(PER_M)
	var scale: float = VeilPainter.lamp_scale(obs.cell.y)
	var head: Vector2 = VeilPainter.lamp_head(obs)
	var body: Vector2 = Vector2(obs.cell) + Vector2(0.5, 0.5)
	var throat: Vector2 = body.lerp(head, 0.45)
	return PackedVector4Array([
		Vector4(head.x, head.y, VeilPainter.LAMP_BEAM_M * m, VeilPainter.LAMP_BEAM_STRENGTH * scale),
		Vector4(throat.x, throat.y, VeilPainter.LAMP_THROAT_M * m, VeilPainter.LAMP_THROAT_STRENGTH * scale),
		Vector4(body.x, body.y, VeilPainter.LAMP_BODY_M * m, VeilPainter.LAMP_BODY_STRENGTH * scale)])


## Every other source packed for the shader, capped at `MAX_CUTS` in the order `VeilSources` lists them.
static func pack_cuts(cuts: Array[Dictionary]) -> Array:
	var geo: PackedVector4Array = PackedVector4Array()
	var tints: PackedVector4Array = PackedVector4Array()
	geo.resize(MAX_CUTS)
	tints.resize(MAX_CUTS)
	var n: int = mini(cuts.size(), MAX_CUTS)
	for i: int in n:
		var c: Dictionary = cuts[i]
		var at: Vector2 = c["centre"]
		var tint: Color = c["tint"]
		geo[i] = Vector4(at.x, at.y, float(c["radius"]), float(c["strength"]))
		tints[i] = Vector4(tint.r, tint.g, tint.b, 1.0)
	return [geo, tints, n]


func paint_frame(frame: Frame, ci: CanvasItem) -> void:
	if material == null or frame == null or frame.obs == null or frame.obs.cell_px <= 0:
		return
	var obs: Interface.Observation = frame.obs
	var w: Rect2i = obs.window
	if w.size.x <= 0 or w.size.y <= 0 or obs.materials.size() < w.size.x * w.size.y:
		return
	_upload_cells(obs, w)
	_upload_field(obs, w)
	material.set_shader_parameter(&"lamp_cuts", lamp_cuts(obs))
	var drawn: Rect2i = TerrainPainter.visit_rect(obs, frame.view_world_rect, obs.cell_px).intersection(w)
	var packed: Array = pack_cuts(VeilSources.cuts_for(frame, drawn, _ore, _falling))
	material.set_shader_parameter(&"cuts", packed[0])
	material.set_shader_parameter(&"cut_tints", packed[1])
	material.set_shader_parameter(&"cut_count", packed[2])
	if ci.material != material:
		ci.material = material
	ci.draw_rect(frame.view_world_rect, Color.WHITE)


func _upload_cells(obs: Interface.Observation, w: Rect2i) -> void:
	var key: Array = [w, obs.terrain_version]
	if _cells_key == key:
		return
	_cells_key = key
	cell_uploads += 1
	if _cells_img == null or _cells_img.get_width() != w.size.x or _cells_img.get_height() != w.size.y:
		_cells_img = Image.create_from_data(w.size.x, w.size.y, false, Image.FORMAT_R8, obs.materials)
		_cells_tex = ImageTexture.create_from_image(_cells_img)
	else:
		_cells_img.set_data(w.size.x, w.size.y, false, Image.FORMAT_R8, obs.materials)
		_cells_tex.update(_cells_img)
	var px: float = float(obs.cell_px)
	material.set_shader_parameter(&"cells_tex", _cells_tex)
	material.set_shader_parameter(&"cells_origin_px", Vector2(w.position) * px)
	material.set_shader_parameter(&"cells_size_px", Vector2(w.size) * px)
	# The wall plane, when the envelope asked for it, and the sky floor per column (both share the key).
	var walls_ok: bool = obs.has_walls and obs.walls.size() >= w.size.x * w.size.y
	material.set_shader_parameter(&"has_walls", walls_ok)
	if walls_ok:
		if _walls_img == null or _walls_img.get_width() != w.size.x or _walls_img.get_height() != w.size.y:
			_walls_img = Image.create_from_data(w.size.x, w.size.y, false, Image.FORMAT_R8, obs.walls)
			_walls_tex = ImageTexture.create_from_image(_walls_img)
		else:
			_walls_img.set_data(w.size.x, w.size.y, false, Image.FORMAT_R8, obs.walls)
			_walls_tex.update(_walls_img)
		material.set_shader_parameter(&"walls_tex", _walls_tex)
	var floors: PackedFloat32Array = PackedFloat32Array()
	floors.resize(w.size.x)
	for i: int in w.size.x:
		floors[i] = float(obs.sky_floor[i]) if i < obs.sky_floor.size() else 1.0e9
	var sky_bytes: PackedByteArray = floors.to_byte_array()
	if _sky_img == null or _sky_img.get_width() != w.size.x:
		_sky_img = Image.create_from_data(w.size.x, 1, false, Image.FORMAT_RF, sky_bytes)
		_sky_tex = ImageTexture.create_from_image(_sky_img)
	else:
		_sky_img.set_data(w.size.x, 1, false, Image.FORMAT_RF, sky_bytes)
		_sky_tex.update(_sky_img)
	material.set_shader_parameter(&"sky_tex", _sky_tex)


func _upload_field(obs: Interface.Observation, w: Rect2i) -> void:
	var rect_m: Rect2i = metre_rect_of(w)
	var key: Array = [rect_m, obs.map_version]
	if _field_key == key:
		return
	_field_key = key
	field_uploads += 1
	var bytes: PackedByteArray = openness_metres(obs, rect_m)
	if _field_img == null or _field_img.get_width() != rect_m.size.x or _field_img.get_height() != rect_m.size.y:
		_field_img = Image.create_from_data(rect_m.size.x, rect_m.size.y, false, Image.FORMAT_R8, bytes)
		_field_tex = ImageTexture.create_from_image(_field_img)
	else:
		_field_img.set_data(rect_m.size.x, rect_m.size.y, false, Image.FORMAT_R8, bytes)
		_field_tex.update(_field_img)
	var metre_px: float = float(obs.cell_px * PER_M)
	material.set_shader_parameter(&"field_tex", _field_tex)
	material.set_shader_parameter(&"field_origin_px", Vector2(rect_m.position) * metre_px)
	material.set_shader_parameter(&"field_size_px", Vector2(rect_m.size) * metre_px)
	material.set_shader_parameter(&"field_texels", Vector2(rect_m.size))
