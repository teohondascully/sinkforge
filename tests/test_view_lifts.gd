extends "res://tests/test_base.gd"

## `view/visuals/art.gd` and `view/fx/light_layer.gd`, lifted from legacy (D0227). Both arrive with NO
## CONSUMER, so what a test can honestly assert about them is narrow, and saying which half is covered
## matters more than the count of green lines.
##
## `Art`: **art has now landed** (D0268 -- 16 miner PNGs under `assets/sprites/`), so BOTH paths are
## reachable here for the first time. This file's earlier note said the hit path was untestable "until
## art lands"; it has, and the assertion below moved with it rather than being relaxed.
##
## The miss path still matters just as much and is still asserted: the cache must remember a MISS, or a
## renderer calling `tex()` per frame re-probes a missing file every frame forever.
##
## `LightLayer`: the callback contract. `_draw` is invoked directly rather than through a viewport --
## the painter receives the canvas and this test's painters make no `draw_*` calls, which are the calls
## that would actually need a live draw pass.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_view_lifts.gd


func _initialize() -> void:
	_test_art_returns_null_and_caches_the_miss()
	_test_art_now_reports_real_art_and_still_misses_cleanly()
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


## RE-PINNED 2026-08-31 (D0268). This asserted `not Art.has_any()` -- correct while `assets/` did not
## exist, and it went red the moment the miner sprites landed. That is a ratchet doing its job, not a
## test to loosen: the assertion now states what is true, and the accompanying miss check keeps the
## fallback contract covered so this is a MOVE rather than a deletion.
func _test_art_now_reports_real_art_and_still_misses_cleanly() -> void:
	Art.clear_cache()
	_check(Art.has_any(),
		"has_any() is TRUE now that assets/sprites/ holds real art -- was false, and D0268 is what moved it")
	_check(Art.tex("miner_idle") != null,
		"a real key resolves to a Texture2D -- the HIT path, unreachable in this suite until art landed")
	_check(Art.tex("definitely_not_a_sprite") == null,
		"and an absent key still returns null, so a renderer without art for a key keeps its primitive")


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
