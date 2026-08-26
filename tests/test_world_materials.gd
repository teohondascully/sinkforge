extends "res://tests/test_base.gd"

func _initialize() -> void:
	_test_known_materials_have_positive_hardness()
	_test_unknown_material_hardness_is_zero()
	_test_exists()
	_finish("world_materials")


func _test_known_materials_have_positive_hardness() -> void:
	for material_id: StringName in [&"clay", &"hardrock", &"deepstone", &"coal", &"ore_copper", &"ore_iron"]:
		_check(WorldMaterials.hardness(material_id) > 0.0, "%s has positive hardness" % material_id)


func _test_unknown_material_hardness_is_zero() -> void:
	_check(WorldMaterials.hardness(&"not_a_real_material") == 0.0, "an unknown material's hardness is 0.0, not an error")


func _test_exists() -> void:
	_check(WorldMaterials.exists(&"clay"), "clay is a known material")
	_check(not WorldMaterials.exists(&"not_a_real_material"), "a made-up id is not a known material")
