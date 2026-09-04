class_name VeilFieldCache
extends RefCounted

## THE OPENNESS FIELD AND BASE LIGHTMAP, HELD BETWEEN FRAMES. The field is the blurred openness
## (`VeilPainter.openness`), and the base is `shade_at * skylight_ceiling` for every texel — the half
## of the veil that depends ONLY on terrain, not on the lamp or the frame. Both are pure functions of
## (window, terrain contents) and are keyed on the same version.

var _field: PackedFloat32Array = PackedFloat32Array()
var _rect: Rect2i = Rect2i()
var _version: int = -1
var _valid: bool = false
var _base: PackedFloat32Array = PackedFloat32Array()
var _base_rect: Rect2i = Rect2i()
var _base_version: int = -1


func field_for(obs: Interface.Observation, build: Callable) -> PackedFloat32Array:
	if _valid and _rect == obs.window and _version == obs.terrain_version:
		return _field
	_field = build.call(obs, obs.window)
	_rect = obs.window
	_version = obs.terrain_version
	_valid = true
	return _field


func base_for(obs: Interface.Observation, baked: Rect2i, drawn: Rect2i,
		field: PackedFloat32Array, cpt: int) -> PackedFloat32Array:
	if _base_version == obs.terrain_version and _base_rect == drawn and _base.size() > 0:
		return _base
	var half: int = cpt / 2
	var w: int = int(ceil(float(drawn.size.x) / float(cpt)))
	var h: int = int(ceil(float(drawn.size.y) / float(cpt)))
	_base.resize(w * h)
	for j: int in h:
		var row: int = drawn.position.y + j * cpt + half
		for i: int in w:
			var col: int = drawn.position.x + i * cpt + half
			var li: int = col - baked.position.x
			var lj: int = row - baked.position.y
			if li < 0 or lj < 0 or li >= baked.size.x or lj >= baked.size.y:
				_base[j * w + i] = 1.0
			else:
				_base[j * w + i] = VeilPainter.shade_at(obs, baked, field, li, lj) * VeilPainter.skylight_ceiling(row)
	_base_rect = drawn
	_base_version = obs.terrain_version
	return _base
