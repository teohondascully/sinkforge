extends "res://tools/check_base.gd"

## Does every shader in the game still compile?
##
## Nothing else in the suite can answer this. `parse_check.sh` reads GDScript and never opens a
## `.gdshader`. The pixel layers boot the game, but a canvas_item shader that fails to compile does not
## crash anything: Godot logs the failure, drops the material, and the scene renders without that pass.
## A capture taken afterwards is a real frame of a game missing its colour grade, and every layer judging
## it will happily report on what it sees.
##
## THE PREDICATE IS NOT `load() == null`, AND THAT IS THE WHOLE POINT OF THIS FILE. `load()` returns a
## live Shader for source that did not compile. Written the obvious way, this layer printed `ok` for a
## shader whose log said `SHADER ERROR: Unknown identifier` on the line above, and exited 0. A check that
## cannot register its own subject is worse than no check, because it is reported as coverage.
##
## What a failed compile does change is the uniform list: the parser populates it only if it got through
## the source. So the source's own `uniform` declarations are the prediction and `get_shader_uniform_list`
## is the measurement, and the layer prints both rather than a verdict derived from one of them.
##
## Uniforms the engine feeds itself are excluded from the prediction. `hint_screen_texture` is supplied by
## the renderer and never appears in the material's list, so counting every `uniform` line over-predicts
## by exactly the number of them. Verified rather than assumed: two shaders each declare one and each
## parsed count was short by exactly one.
##
## `erase.gdshader` declares no uniforms at all and must still pass, so the assertion is equality with the
## prediction and not "more than zero".
##
##   godot --headless --path . --script res://tools/check_shaders.gd

## Every shader the game ships. Discovered rather than listed, so a new one is covered the day it lands:
## a hand-written list is a coverage claim that ages silently, and this layer exists because of a check
## that was quietly not checking.
const SHADER_DIR: String = "res://scenes"


func _initialize() -> void:
	var paths: Array[String] = _shader_paths()
	if paths.is_empty():
		_skip_layer("check_shaders", "no .gdshader files found under %s" % SHADER_DIR)
		return

	for p: String in paths:
		var sh: Shader = load(p) as Shader
		if sh == null:
			_check(false, "%s loads at all" % p.get_file())
			continue
		var declared: int = _declared_uniforms(sh.code)
		var parsed: int = sh.get_shader_uniform_list().size()
		_check(parsed == declared,
			"%s compiles (%d uniforms declared, %d survived the parser)"
				% [p.get_file(), declared, parsed])

	_verdict("check_shaders", "%d shader(s) compiled" % paths.size())


func _shader_paths() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(SHADER_DIR)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gdshader"):
			out.append("%s/%s" % [SHADER_DIR, f])
	out.sort()
	return out


func _declared_uniforms(code: String) -> int:
	var n: int = 0
	for line: String in code.split("\n"):
		var t: String = line.strip_edges()
		if t.begins_with("uniform ") and not t.contains("hint_screen_texture"):
			n += 1
	return n
