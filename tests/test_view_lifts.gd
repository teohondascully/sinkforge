extends "res://tests/test_base.gd"

## `view/visuals/art.gd` and `view/fx/light_layer.gd`, lifted from legacy (D0227). Both arrive with NO
## CONSUMER, so what a test can honestly assert about them is narrow, and saying which half is covered
## matters more than the count of green lines.
##
## `Art`: `res://assets/` does not exist in this tree, so **only the miss path is reachable here.** The
## hit path -- a real PNG resolving to a Texture2D -- is untestable until art lands, and a suite that
## pretended otherwise would be asserting the fallback while claiming to check the loader. What IS
## testable is the part that would break silently: the cache must remember a MISS, or a renderer calling
## `tex()` per frame re-probes a missing file every frame forever.
##
## `LightLayer`: the callback contract. `_draw` is invoked directly rather than through a viewport --
## the painter receives the canvas and this test's painters make no `draw_*` calls, which are the calls
## that would actually need a live draw pass.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_view_lifts.gd


func _initialize() -> void:
	_test_art_returns_null_and_caches_the_miss()
	_test_art_reports_no_art_at_all_so_callers_keep_their_primitives()
	_test_light_layer_hands_its_own_canvas_to_the_painter()
	_test_light_layer_only_builds_a_material_when_the_blend_is_not_the_default()
	_test_light_layer_survives_an_invalid_painter()
	_finish("view_lifts")


func _test_art_returns_null_and_caches_the_miss() -> void:
	Art.clear_cache()
	var first: Texture2D = Art.tex("definitely_not_a_sprite")
	_check(first == null, "a key with no PNG under %s returns null, not an error" % Art.DIR)
	# The discriminating assertion: `has()` distinguishes a cached null from an absent entry, which a
	# second `tex()` call returning null cannot -- both a working cache and no cache at all return null.
	_check(Art._cache.has("definitely_not_a_sprite"),
		"the MISS is cached, so a per-frame caller probes the filesystem once rather than every frame (a null return alone would not distinguish a cache from no cache)")
	Art.clear_cache()
	_check(not Art._cache.has("definitely_not_a_sprite"),
		"CONTROL: clear_cache actually empties it, so the assertion above is reading a real entry")


func _test_art_reports_no_art_at_all_so_callers_keep_their_primitives() -> void:
	Art.clear_cache()
	_check(not Art.has_any(),
		"has_any() is false in a tree with no assets/ directory -- the state this build is in, and the signal that keeps every renderer on its code-drawn path")


func _test_light_layer_hands_its_own_canvas_to_the_painter() -> void:
	var layer := LightLayer.new()
	var seen: Array = []
	layer.setup(7, func(canvas: CanvasItem) -> void: seen.append(canvas))
	_check(layer.z_index == 7, "setup applies the z-index it was given (got %d)" % layer.z_index)
	layer._draw()
	_check(seen.size() == 1, "the painter ran exactly once per _draw (ran %d time(s))" % seen.size())
	_check(seen.size() == 1 and seen[0] == layer,
		"the painter receives THIS canvas, not some other node -- draw_* is only valid on the item inside its own _draw pass")
	layer.free()


func _test_light_layer_only_builds_a_material_when_the_blend_is_not_the_default() -> void:
	var plain := LightLayer.new()
	plain.setup(0, func(_c: CanvasItem) -> void: pass)
	_check(plain.material == null,
		"a MIX layer gets no material -- the default costs nothing and a material per pass would be the point of the file inverted")
	plain.free()

	var multiplied := LightLayer.new()
	multiplied.setup(1, func(_c: CanvasItem) -> void: pass, CanvasItemMaterial.BLEND_MODE_MUL)
	var mat := multiplied.material as CanvasItemMaterial
	_check(mat != null and mat.blend_mode == CanvasItemMaterial.BLEND_MODE_MUL,
		"a MUL layer carries a CanvasItemMaterial set to MUL -- the whole reason each pass is its own node")
	multiplied.free()


func _test_light_layer_survives_an_invalid_painter() -> void:
	var layer := LightLayer.new()
	layer._draw()  # painter never assigned: an unset Callable is not valid, and _draw must not throw
	_check(not layer.painter.is_valid(),
		"an unconfigured layer has no valid painter and its _draw is a no-op rather than an error")
	layer.free()
