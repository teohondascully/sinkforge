extends "res://tools/check_base.gd"

## CONTRACT GUARD — every material the world can contain has a MaterialDef the renderer will actually use.
##
## This is `check_craftable_registry.gd` again, applied to the OTHER hardcoded registry. That lesson was
## learned for real with the pump, written down, guarded — and then not carried across, so the identical
## bug sat in the material list for as long as rich_ore has existed.
##
## THE BUG CLASS, and why it is worse here than it was for machines. `WorldRenderer._materials` is a
## hardcoded array of `.tres` paths, and the lookup fails SOFT:
##
##     func _material(id: StringName) -> MaterialDef:
##         return _materials.get(id, _materials.get(&"earth"))
##
## A missing entry therefore produces no error, no warning, and no crash — it produces DIRT. `rich_ore`,
## the deep-layer treasure the aquifer pockets and the rift walls are lined with, was absent: every
## rich_ore cell resolved to earth.tres, whose `nugget_color` is fully transparent, so `_draw_lode` hit
## `if not def.has_nuggets(): continue` and drew the exposed vein as NOTHING, `_seam_glow_color` fell
## through to the crystal fallback and glowed it cyan, and the rock painted brown. The reward at the
## bottom of L3 was invisible and the only symptom was that it looked like ordinary ground.
##
## A machine missing from its registry is unreachable, which a play-test eventually notices. A material
## missing from this one still renders — just as the wrong thing — which nothing notices at all.
##
## Assert: every `.tres` in src/data/materials/ is registered in the LIVE WorldRenderer._materials, and
## every id the terrain can actually hold resolves to its OWN def rather than to the earth fallback.
##
## Read from the real booted scene rather than re-derived, for the reason the machine guard states and
## which applies here verbatim: a re-derivation could agree with itself while the renderer is missing the
## entry — the exact drift this guards against.
##
## Run: godot --headless --path . --script res://tools/check_material_registry.gd

const SCENE: String = "res://scenes/main.tscn"
const MATERIAL_DIR: String = "res://src/data/materials/"

var _main: MainView
var _frames: int = 0


func _initialize() -> void:
	Engine.max_fps = 60
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	print("== material registry contract ==")
	process_frame.connect(_on_frame)

func _on_frame() -> void:
	_frames += 1
	if _frames < 3:
		return
	process_frame.disconnect(_on_frame)
	_run()
	if _failures == 0:
		print("ALL MATERIAL-REGISTRY CHECKS PASS")
		quit(0)
	else:
		printerr("%d MATERIAL-REGISTRY FAILURE(S)" % _failures)
		quit(1)


func _run() -> void:
	var reg: Dictionary = _main._renderer._materials
	_check(reg.size() > 0, "the renderer's material registry is populated (%d defs)" % reg.size())
	var fallback: MaterialDef = reg.get(&"earth")
	_check(fallback != null, "…including the &\"earth\" fallback every miss silently resolves to")

	# EVERY AUTHORED MATERIAL IS REGISTERED. Walking the directory is the point: the failure being guarded
	# against is precisely "somebody added a .tres and did not add the load()", so the directory is the
	# question and the hardcoded array is the answer being marked.
	var files: PackedStringArray = DirAccess.get_files_at(MATERIAL_DIR)
	_check(files.size() > 0, "there are authored materials on disk to check (%d)" % files.size())
	var walked: int = 0
	for f: String in files:
		if not f.ends_with(".tres"):
			continue
		var def: MaterialDef = load(MATERIAL_DIR + f)
		if def == null:
			continue
		walked += 1
		_check(reg.has(def.id) and reg[def.id] == def,
			"%s is registered in WorldRenderer._materials, so it draws as itself" % f)
	_check(walked > 0, "the guard actually walked the material files (%d)" % walked)

	# …AND THE ONES THE WORLD CAN REALLY CONTAIN RESOLVE TO THEMSELVES. The check above would be satisfied
	# by a registry that holds every def under a wrong key; this one asks the renderer the question the
	# renderer actually gets asked, for the ids the generator and the lode plane actually produce. The ore
	# family is listed explicitly because it is the family where the failure is invisible: a vein that
	# resolves to earth still paints, it just paints as ground with no metal in it.
	for id: StringName in [&"ore", &"rich_ore", &"coal", &"iron", &"earth", &"stone", &"shale",
			&"deepslate", &"sealrock", &"gravel", &"wood", &"leaves"]:
		var got: MaterialDef = _main._renderer._material(id)
		_check(got != null and got.id == id,
			"_material(&\"%s\") returns its own def, not the dirt fallback" % String(id))

	# The ore family must additionally carry flecks, because `_draw_lode` skips a def that has none — which
	# is how a registered-but-wrong material would still draw an exposed vein as bare rock.
	for id2: StringName in [&"ore", &"rich_ore", &"coal", &"iron"]:
		var vein: MaterialDef = _main._renderer._material(id2)
		_check(vein != null and vein.has_nuggets(),
			"&\"%s\" has flecks, so an exposed lode of it is something you can see" % String(id2))
