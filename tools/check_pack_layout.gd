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
## Also guards the MINIMAP frame, which is the same class of bug one element over: a HUD rect that
## derives one of its dimensions from a WORLD constant is a rect that resizes itself when the world
## does. Both map forms must fit their box, keep the world aspect, and stay off the live play area.
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

	# --- THE MINIMAP FRAME: both forms fit their box, whatever shape the world is. A corner map sized by
	# width alone was fine at 96x80 and became a 150x150 slab down half the screen the moment the world
	# went square; the class of bug is a HUD element deriving one dimension from a world constant. ---
	for large: bool in [false, true]:
		hud.minimap_large = large
		var f: Rect2 = hud.minimap_frame()
		var tag: String = "map-large" if large else "map-corner"
		_check(f.position.x >= -0.5 and f.end.x <= canvas.x + 0.5,
			"%s: on-screen horizontally (%.0f..%.0f)" % [tag, f.position.x, f.end.x])
		_check(f.position.y >= -0.5 and f.end.y <= canvas.y + 0.5,
			"%s: on-screen vertically (%.0f..%.0f of %.0f)" % [tag, f.position.y, f.end.y, canvas.y])
		var world_aspect: float = float(FactorySim.GRID_COLS) / float(FactorySim.GRID_ROWS)
		_check(absf(f.size.x / f.size.y - world_aspect) < 0.01,
			"%s: keeps the world's aspect (%.2f vs %.2f)" % [tag, f.size.x / f.size.y, world_aspect])
	hud.minimap_large = false
	var corner: Rect2 = hud.minimap_frame()
	_check(corner.size.x <= Hud.MINI_W + 0.5 and corner.size.y <= Hud.MINI_H + 0.5,
		"map-corner: inside its %.0fx%.0f box (%.0fx%.0f)"
		% [Hud.MINI_W, Hud.MINI_H, corner.size.x, corner.size.y])
	# ...and it must not reach the hotbar. The corner map is an ALWAYS-AVAILABLE overlay over live play,
	# so anything it covers is something the player cannot see while it is up.
	_check(corner.end.y <= canvas.y * 0.5,
		"map-corner: stays in the top half (bot=%.0f)" % corner.end.y)

	hud.free()
	if _failures == 0:
		print("PACK LAYOUT OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)
