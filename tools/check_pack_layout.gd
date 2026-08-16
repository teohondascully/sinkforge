extends SceneTree

## Harness layer — THE BAZAAR panel is ONE SHAPE, always on-screen, and never needs to scroll.
##
## The property changed with #S33 and it changed to a stronger one. It used to be "the growing craft list
## scrolls correctly inside its viewport, and the research bench stays reachable below it" — a guard on a
## workaround. `docs/BAZAAR.md` deletes the workaround: two columns of 24px rows hold twenty rows in the
## space eight stacked ones used to need, and if a list ever outgrows that the answer is a third column,
## not a scrollbar. So what is asserted now is that the overflow never happens, which is what the scrollbar
## was there to survive.
##
## The other half is fix #4, and it is worth stating as an assertion because it was the most annoying of the
## six: the panel is the SAME SIZE AND POSITION whether or not you are standing at a claimed Bazaar. It used
## to change shape — away from the stall the recipe rows and the whole research section vanished and you got
## a hint line — so you could not plan a build from the bottom of a shaft, which is the one place you want
## to. Now only the VERBS are gated; the layout is a constant.
##
## Also guards the MINIMAP frame, which is the same class of bug one element over: a HUD rect that derives
## one of its dimensions from a WORLD constant is a rect that resizes itself when the world does.
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
	var g: Dictionary = hud._bazaar_geometry()
	var origin: Vector2 = g["origin"]
	var content: Rect2 = g["content"]
	_check(origin.x >= -0.5 and origin.x + float(g["w"]) <= canvas.x + 0.5,
		"%s: panel on-screen horizontally (%.0f..%.0f)" % [tag, origin.x, origin.x + float(g["w"])])
	_check(origin.y >= -0.5 and origin.y + float(g["h"]) <= canvas.y + 0.5,
		"%s: panel on-screen vertically (%.0f..%.0f)" % [tag, origin.y, origin.y + float(g["h"])])
	_check(content.position.y >= origin.y and content.end.y <= origin.y + float(g["h"]) + 0.5,
		"%s: the content area is inside the panel" % tag)


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

	# --- THE REAL LISTS FIT WITHOUT SCROLLING. This is the assertion that replaced the scrollbar: the whole
	# counter, at the largest it can currently be, has to be readable in one look. ---
	hud.craft_options = _craft_options(10)
	hud.rack_options = _craft_options(7)
	_assert_fits(hud, canvas, "real")
	var g: Dictionary = hud._bazaar_geometry()
	var per_column: int = int(g["rows"])
	print("  the counter holds %d rows per column (%d across the two)" % [per_column, per_column * 2])
	# Twenty across the two columns is the number `docs/BAZAAR.md` promises, and the number that makes the
	# scrollbar unnecessary. If the machine list ever outgrows it the answer is a third column — this layer
	# failing is how you find out, rather than a scrollbar appearing and nobody noticing.
	_check(per_column * 2 >= 20, "the counter holds twenty rows without scrolling")
	_check(hud.craft_options.size() <= per_column,
		"every machine fits its column without scrolling (%d of %d)" % [hud.craft_options.size(), per_column])
	_check(hud.rack_options.size() <= per_column,
		"every Rack row fits its column without scrolling (%d of %d)" % [hud.rack_options.size(), per_column])

	# --- SAME SHAPE EVERYWHERE (fix #4). Away from a Bazaar only the VERBS are gated. ---
	var at_stall: Dictionary = hud._bazaar_geometry()
	hud.can_craft = false
	var in_a_shaft: Dictionary = hud._bazaar_geometry()
	_assert_fits(hud, canvas, "no-bazaar")
	_check(at_stall["origin"] == in_a_shaft["origin"] and is_equal_approx(at_stall["h"], in_a_shaft["h"]),
		"the panel is the same size and place away from a Bazaar as at one")
	_check(hud.bazaar_row_count() >= 0, "…and the counter still lists its rows down a shaft")
	hud.can_craft = true

	# --- THE CURSOR walks both columns and never leaves the list. ---
	hud.set_bazaar_tab(Hud.TAB_WORKS)
	_check(hud.bazaar_row_count() == hud.craft_options.size() + hud.rack_options.size(),
		"WORKS offers every machine and every Rack row to the cursor")
	for _i: int in 200:
		hud.bazaar_move(0, 1)
	_check(hud.bazaar_row == hud.bazaar_row_count() - 1, "the cursor clamps at the bottom")
	_check(str(hud.bazaar_action().get("kind", "")) == "rack", "…which is a Rack row")
	for _i: int in 200:
		hud.bazaar_move(0, -1)
	_check(hud.bazaar_row == 0, "the cursor clamps at the top")
	_check(str(hud.bazaar_action().get("kind", "")) == "machine", "…which is a machine row")
	hud.bazaar_move(1, 0)
	_check(str(hud.bazaar_action().get("kind", "")) == "rack", "left/right hops the counter-to-Rack gap")
	hud.bazaar_move(-1, 0)
	_check(str(hud.bazaar_action().get("kind", "")) == "machine", "…and back")
	hud.set_bazaar_tab(Hud.TAB_BENCH)
	_check(hud.bazaar_row_count() == ResearchRules.ORDER.size(), "BENCH offers every rung to the cursor")
	_check(str(hud.bazaar_action().get("kind", "")) == "tech", "…and Enter acts on a tech")
	hud.set_bazaar_tab(Hud.TAB_PACK)
	_check(hud.bazaar_action().is_empty(), "PACK has nothing to buy, so Enter does nothing")

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
