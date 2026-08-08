extends SceneTree

## Harness layer — the PACK / CRAFT panel always FITS the screen and the RESEARCH bench stays reachable
## (playtest #75: "the craft list outgrew the panel, so by the time you could research automation it was
## off the bottom, unreachable"). The class of bug is a growing list overflowing a screen-sized panel;
## the guard is the panel's own layout authority, Hud._pack_geometry(), which the draw code reads too —
## so seen == tested. We stress it with a craft list far longer than any real tier count and assert:
##   - the panel stays on-screen (top >= 0, bottom <= canvas)
##   - the research bench (pinned under the scroll viewport) sits inside the panel
##   - a long list actually scrolls (content > viewport), snapped to whole rows, clamped
##   - a short list does NOT scroll (viewport == content, scroll_max == 0)
## Run: godot --headless --path . --script res://tools/check_pack_layout.gd

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


func _craft_options(n: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in n:
		out.append({"name": "Machine %d" % i, "cost": {&"iron_ingot": 2}})
	return out


func _assert_fits(hud: Hud, canvas: Vector2, tag: String) -> void:
	var g: Dictionary = hud._pack_geometry()
	var origin: Vector2 = g["origin"]
	var h: float = g["h"]
	_check(origin.y >= -0.5, "%s: panel top on-screen (y=%.1f)" % [tag, origin.y])
	_check(origin.y + h <= canvas.y + 0.5, "%s: panel bottom on-screen (bot=%.1f <= %.0f)"
		% [tag, origin.y + h, canvas.y])
	# The research bench is pinned at the bottom of the scroll viewport and needs research_h beneath it.
	var bench_bottom: float = origin.y + g["head"] + g["grid_h"] + 4.0 + g["craft_head"] \
		+ g["viewport_h"] + g["research_h"]
	_check(bench_bottom <= origin.y + h + 0.5,
		"%s: research bench inside the panel (bench_bot=%.1f <= panel_bot=%.1f)"
		% [tag, bench_bottom, origin.y + h])


func _initialize() -> void:
	print("== pack-layout check ==")
	var canvas := Hud.CANVAS
	var sim: FactorySim = FactorySim.new()
	# A believable pack so the inventory grid contributes real height.
	for id: StringName in [&"earth", &"ore", &"iron_ingot", &"coal", &"wood", &"plate", &"gear", &"drill"]:
		sim.inventory[id] = 5
		sim.total_produced[id] = 5

	var hud: Hud = Hud.new()
	hud.sim = sim
	hud.can_craft = true

	# --- a craft list far longer than any real tier count: it MUST fit + scroll ---
	hud.craft_options = _craft_options(30)
	_assert_fits(hud, canvas, "long")
	var gl: Dictionary = hud._pack_geometry()
	_check(gl["content_h"] > gl["viewport_h"] + 0.5, "long: list overflows the viewport (scrolls)")
	_check(gl["viewport_h"] >= gl["row_h"] - 0.5, "long: at least one craft row is visible")
	_check(hud._craft_scroll_max > 0.5, "long: scroll_max > 0")
	_check(fmod(hud._craft_scroll_max, gl["row_h"]) < 0.01, "long: scroll_max is a whole number of rows")

	# scroll to the end: clamps, lands exactly on the max, snapped to rows
	for _i: int in 200:
		hud.scroll_craft(1)
	_check(is_equal_approx(hud._craft_scroll, hud._craft_scroll_max), "long: over-scroll clamps to max")
	_check(fmod(hud._craft_scroll, gl["row_h"]) < 0.01, "long: scroll offset stays row-aligned")
	# and back up
	for _i: int in 200:
		hud.scroll_craft(-1)
	_check(hud._craft_scroll <= 0.01, "long: scroll back clamps to 0")

	# --- a short list: no scroll, whole thing shown ---
	hud.craft_options = _craft_options(3)
	_assert_fits(hud, canvas, "short")
	var gs: Dictionary = hud._pack_geometry()
	_check(is_equal_approx(gs["viewport_h"], gs["content_h"]), "short: viewport == content (no scroll)")
	_check(hud._craft_scroll_max <= 0.01, "short: scroll_max == 0")

	# --- away from the Bazaar (can_craft = false): still fits, no research section ---
	hud.can_craft = false
	_assert_fits(hud, canvas, "no-bazaar")
	_check(hud._pack_geometry()["research_h"] <= 0.01, "no-bazaar: no research section")

	hud.free()
	if _failures == 0:
		print("PACK LAYOUT OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)
