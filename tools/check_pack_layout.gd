extends "res://tools/check_base.gd"

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
	var cols: int = int(g["cols"])
	print("  the counter holds %d rows per column, %d columns (%d in all)"
		% [per_column, cols, per_column * cols])
	# Twenty is the number `docs/BAZAAR.md` promises, and the number that makes the scrollbar unnecessary.
	# #S34 moved it from two columns of ten to three of seven when the detail plate took the bottom of the
	# panel — the promise is the ROW COUNT, not the column count, and this is the assertion that says so.
	_check(per_column * cols >= 20, "the counter holds twenty rows without scrolling")
	# ...and each GROUP gets whole columns of its own, because the left list is what you build and the right
	# is what you buy. A group that spilled into its neighbour's column would make a row's meaning depend on
	# its position, which is the one thing a two-list screen must never do.
	var lay: Dictionary = hud.works_columns(per_column)
	print("  MACHINES takes %d column(s), THE RACK %d — of %d" % [int(lay["machines"]), int(lay["rack"]), cols])
	_check(int(lay["total"]) <= cols,
		"both lists fit the counter in whole columns (%d of %d)" % [int(lay["total"]), cols])
	_check(hud.craft_options.size() <= per_column * int(lay["machines"]),
		"every machine is reachable without a window (%d of %d)"
		% [hud.craft_options.size(), per_column * int(lay["machines"])])
	_check(hud.rack_options.size() <= per_column * int(lay["rack"]),
		"every Rack row is reachable without a window (%d of %d)"
		% [hud.rack_options.size(), per_column * int(lay["rack"])])
	# THE DETAIL PLATE is part of the shape, so it is part of the test: it has to be inside the panel and it
	# has to be big enough to hold the thing it exists to show (a 44px glyph plus two lines and a button).
	var detail: Rect2 = g["detail"]
	_check(detail.end.y <= float(g["origin"].y) + float(g["h"]) + 0.5 and detail.size.y >= 70.0,
		"the detail plate is inside the panel and tall enough to matter (%.0fpx)" % detail.size.y)

	# --- SAME SHAPE EVERYWHERE (fix #4). Away from a Bazaar only the VERBS are gated. ---
	var at_stall: Dictionary = hud._bazaar_geometry()
	var rows_at_stall: int = hud.bazaar_row_count()
	hud.can_craft = false
	var in_a_shaft: Dictionary = hud._bazaar_geometry()
	_assert_fits(hud, canvas, "no-bazaar")
	_check(at_stall["origin"] == in_a_shaft["origin"] and is_equal_approx(at_stall["h"], in_a_shaft["h"]),
		"the panel is the same size and place away from a Bazaar as at one")
	# THIS ASSERTION USED TO READ `bazaar_row_count() >= 0`. A row count is an integer count; it is never
	# negative; the check could not fail, and it was the only thing standing behind the claim its own
	# label made. The property that sentence is actually about is that the list does not SHRINK when the
	# verbs gate — away from a Bazaar you still READ everything it would sell you, you just cannot buy it
	# here, which is what makes the screen the same screen in both places.
	_check(rows_at_stall > 0 and hud.bazaar_row_count() == rows_at_stall,
		"…and the counter lists the SAME %d rows down a shaft — only the verbs gate" % rows_at_stall)
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
	# LEFT/RIGHT jumps a whole COLUMN — the motion your eye makes. Two of them clears the machine list's two
	# columns and lands in the Rack, which is the counter-to-Rack hop stated in the honest units.
	hud.bazaar_move(1, 0)
	_check(str(hud.bazaar_action().get("kind", "")) == "machine", "right jumps a column, still in MACHINES")
	hud.bazaar_move(1, 0)
	_check(str(hud.bazaar_action().get("kind", "")) == "rack", "…and the next one lands in the Rack")
	hud.bazaar_move(-1, 0)
	hud.bazaar_move(-1, 0)
	_check(str(hud.bazaar_action().get("kind", "")) == "machine", "…and back")
	hud.set_bazaar_tab(Hud.TAB_BENCH)
	_check(hud.bazaar_row_count() == ResearchRules.ORDER.size(), "BENCH offers every rung to the cursor")
	_check(str(hud.bazaar_action().get("kind", "")) == "tech", "…and Enter acts on a tech")
	hud.set_bazaar_tab(Hud.TAB_PACK)
	# PACK's verb is HOLD (#S34): the one tab that had a cursor and nothing to do with it. Equipping is
	# stateless, so "hold this" is the same act as pressing the slot's hotbar digit — reachable from the
	# screen you are looking at rather than only from a row of numbers hidden behind the panel.
	_check(hud.bazaar_row_count() == sim.inventory_slots().size(), "PACK offers every carried slot to the cursor")
	_check(str(hud.bazaar_action().get("kind", "")) == "hold", "…and Enter holds the one under the cursor")
	hud.bazaar_move(0, 1)
	_check(int(hud.bazaar_action().get("row", -1)) == 1, "…and the row it reports is the slot it drew")

	# --- WORKS LISTS WHAT YOU CAN BUILD, NOT THE CATALOGUE (#S34). Thirteen greyed rows in the place you go
	# to get things is decision paralysis dressed as content; the locked half lives on the BENCH, under the
	# rung that unlocks it, which is the one screen whose job is "what comes next". ---
	var locked_tech: StringName = ResearchRules.ORDER[ResearchRules.ORDER.size() - 1]
	var gated: Array = (ResearchRules.tech(locked_tech).get("unlocks", []) as Array)
	if gated.is_empty():
		_check(false, "fixture: the last rung unlocks something to gate on")
	else:
		var gated_id: StringName = gated[0]
		hud.craft_options = [{"name": "Free", "cost": {}}, {"name": "Gated", "cost": {}}]
		hud.craft_ids = [&"", gated_id] as Array[StringName]
		hud.rack_options = []
		hud.rack_ids = [] as Array[StringName]
		hud.set_bazaar_tab(Hud.TAB_WORKS)
		_check(hud.open_machines().size() == 1,
			"a machine behind unresearched tech is NOT on the counter (%d of 2 listed)" % hud.open_machines().size())
		_check(hud.bazaar_row_count() == 1, "…so the cursor cannot even land on it")
		sim.research[locked_tech] = true
		_check(hud.open_machines().size() == 2, "…and researching its tech puts it on the counter")
		# The row index the panel reports is the index into the FULL catalogue, because that is what the
		# verbs are keyed on: filtering the view must never renumber the world.
		hud.bazaar_move(0, 1)
		_check(int(hud.bazaar_action().get("row", -1)) == 1,
			"the reported row indexes the catalogue, not the filtered view")
		sim.research.erase(locked_tech)

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
