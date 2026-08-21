extends "res://tools/check_base.gd"

## Harness layer: THE BAZAAR panel is ONE SHAPE, always on-screen, and never needs to scroll.
##
## The property changed with #S33 and it changed to a stronger one. It used to be "the growing craft list
## scrolls correctly inside its viewport, and the research bench stays reachable below it", a guard on a
## workaround. `docs/BAZAAR.md` deletes the workaround: two columns of 24px rows hold twenty rows in the
## space eight stacked ones used to need, and if a list ever outgrows that the answer is a third column,
## not a scrollbar. So what is asserted now is that the overflow never happens, which is what the scrollbar
## was there to survive.
##
## The other half is fix #4, and it is worth stating as an assertion because it was the most annoying of the
## six: the panel is the SAME SIZE AND POSITION whether or not you are standing at a claimed Bazaar. It used
## to change shape (away from the stall the recipe rows and the whole research section vanished and you got
## a hint line), so you could not plan a build from the bottom of a shaft, which is the one place you want
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


## The first field of the panel's shape that moved, named: "" if nothing did, and NOTHING_MEASURED if there
## was nothing to compare. Every entry `_bazaar_geometry` returns is compared, so a field ADDED to that
## dictionary later is covered the day it lands rather than the day somebody remembers to come back here.
##
## THE TWO EMPTY ANSWERS ARE DIFFERENT STRINGS, and that is the whole design of this function. A version
## that returned "" for both would say "nothing moved" about a shape it never looked at: the un-measurable
## case handed back as the passing verdict, which is the `dead_space.gd` defect exactly. That one was
## survivable only because callers guarded it, and it went wrong the moment a second caller appeared and
## did not: three callers, two remembered, one did not, and nobody ever decided that. A caller-side guard
## has a per-call-site failure rate. So the ambiguity is sealed off here where it cannot be forgotten, and
## the fixture assertion beside the call site is free to be about the fixture instead of propping this up.
const NOTHING_MEASURED: String = "NOTHING TO COMPARE — the shape dictionary was empty"
func _shape_diff(a: Dictionary, b: Dictionary) -> String:
	if a.is_empty() or b.is_empty():
		return NOTHING_MEASURED
	for k: Variant in a.keys():
		if typeof(a[k]) == TYPE_FLOAT and typeof(b.get(k)) == TYPE_FLOAT:
			if not is_equal_approx(a[k], b[k]):
				return "%s: %s -> %s" % [k, a[k], b[k]]
		elif a[k] != b.get(k):
			return "%s: %s -> %s" % [k, a[k], b.get(k)]
	return ""


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

	# --- THE COUNTER FITS AT A CONTROLLED SIZE. This used to say "THE REAL LISTS ... at the largest it can
	# currently be", and 10 and 7 are neither. Measured on the shipping scene: 19 craftable machines, all 19
	# open once the tech tree is finished, plus 7 on the Rack, so this stand-in is HALF the machine list, and every
	# assertion below about columns and windows was being made against a population smaller than the one it
	# named. That is the measurement-boundary error, not a rounding one: the numbers are right about what
	# they measured and the sentence was about something else.
	#
	# The synthetic case is KEPT, because a fixed size is what makes the geometry assertions readable, and
	# 10+7 sits exactly on the 3-column boundary where a regression would show first. What it is NOT is a
	# statement about the shipping catalogue; `_real_catalogue()` at the bottom of this file is. ---
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
	# panel; the promise is the ROW COUNT, not the column count, and this is the assertion that says so.
	_check(per_column * cols >= 20, "the counter holds twenty rows without scrolling")
	# ...and each GROUP gets whole columns of its own, because the left list is what you build and the right
	# is what you buy. A group that spilled into its neighbour's column would make a row's meaning depend on
	# its position, which is the one thing a two-list screen must never do.
	var lay: Dictionary = hud.works_columns(per_column)
	print("  MACHINES takes %d column(s), THE RACK %d — of %d" % [int(lay["machines"]), int(lay["rack"]), cols])
	# ASKED OF THE DEMAND, NOT OF THE ANSWER. This read `lay["total"] <= cols`, and `works_columns` ends with
	# `if m + r > BAZAAR_COLS: … m = BAZAAR_COLS - r`; it CLAMPS its own total on purpose, so the number
	# being tested had just been forced into range by the function under test. It could not fail however far
	# the two lists overflowed. `hud.gd`'s comment beside that clamp says "check_pack_layout asserts the
	# squeeze is not happening today", and that was exactly the sentence this file was not saying: the clamp
	# is the FAILURE MODE, made legible rather than invisible, and reading it back as if it were the result
	# is how a fallback becomes the silent normal. So compute what the lists ASK for, before the clamp sees
	# it, and require that the squeeze never fires.
	# The `maxi(1, …)` floors mean two EMPTY lists still ask for 1+1, so this alone would pass on a counter
	# with nothing on it. It is not left resting on that: the per-tab census below asserts TAB_WORKS has rows
	# at the stall, and TAB_WORKS is these two lists end to end, so emptiness fails there, loudly, and this
	# assertion is free to be about the squeeze. Stated because the coupling is real but not local.
	var want_machines: int = maxi(1, ceili(float(hud.open_machines().size()) / float(per_column)))
	var want_rack: int = maxi(1, ceili(float(hud.open_rack().size()) / float(per_column)))
	_check(want_machines + want_rack <= cols,
		"both lists fit the counter in whole columns UNSQUEEZED (%d asked of %d)"
		% [want_machines + want_rack, cols])
	_check(int(lay["machines"]) == want_machines and int(lay["rack"]) == want_rack,
		"…and the counter gave each list the columns it asked for (%d+%d, wanted %d+%d)"
		% [int(lay["machines"]), int(lay["rack"]), want_machines, want_rack])
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
	# Two fields of the shape were compared (`origin` and `h`), which is the panel's OUTLINE. The content
	# rect, the detail plate and the row geometry could all move underneath an outline that stayed put, and
	# the content rect is exactly where the vanishing recipe rows lived. And the row count was asked on the
	# ONE tab that happened to be selected, while the old panel lost a different part of itself on each. So:
	# every field compared, and every tab counted.
	var tabs: Array[int] = [Hud.TAB_PACK, Hud.TAB_WORKS, Hud.TAB_BENCH]
	var stall_rows: Dictionary = {}
	for tab: int in tabs:
		hud.set_bazaar_tab(tab)
		stall_rows[tab] = hud.bazaar_row_count()
		# The guard that makes the comparison below mean anything: a tab that is EMPTY at the stall would
		# keep its nothing down a shaft and report a pass for having lost none of it.
		# NON-VACUITY: a tab with no rows at the stall would lose none down a shaft.
		_check(int(stall_rows[tab]) > 0,
			"at the stall, tab %d has rows it could lose (%d)" % [tab, int(stall_rows[tab])])
	# BOTH GEOMETRIES ARE READ ON THE SAME TAB, pinned here rather than inherited. `_bazaar_geometry` does
	# not consult `bazaar_tab` today, so the census loop above cannot disturb it, but the whole point of
	# `_shape_diff` is that it covers fields nobody has added yet, and the day one of them varies by tab this
	# comparison would read two different tabs and report the difference as `can_craft`'s doing. One line to
	# make the only variable between the two readings the one under test.
	hud.set_bazaar_tab(Hud.TAB_WORKS)
	var at_stall: Dictionary = hud._bazaar_geometry()
	var stall_cols: Dictionary = hud.works_columns(per_column)
	hud.can_craft = false
	hud.set_bazaar_tab(Hud.TAB_WORKS)
	var in_a_shaft: Dictionary = hud._bazaar_geometry()
	_assert_fits(hud, canvas, "no-bazaar")
	# NON-VACUITY: a statement about the FIXTURE, not the feature. It no longer props up `_shape_diff`
	# (that ambiguity is sealed inside the helper now); it asserts the panel reports a shape worth comparing.
	_check(at_stall.size() >= 6, "the geometry has fields to compare at all (%d)" % at_stall.size())
	var moved: String = _shape_diff(at_stall, in_a_shaft)
	_check(moved == "", "the panel is the same shape FIELD FOR FIELD away from a Bazaar as at one (%s)"
		% ("nothing moved" if moved == "" else moved))
	# THIS ASSERTION USED TO READ `bazaar_row_count() >= 0`. A row count is an integer count; it is never
	# negative; the check could not fail, and it was the only thing standing behind the claim its own
	# label made. The property that sentence is actually about is that the list does not SHRINK when the
	# verbs gate: away from a Bazaar you still READ everything it would sell you, you just cannot buy it
	# here, which is what makes the screen the same screen in both places.
	for tab: int in tabs:
		hud.set_bazaar_tab(tab)
		_check(hud.bazaar_row_count() == int(stall_rows[tab]),
			"…and tab %d still lists all %d of its rows down a shaft (%d) — only the verbs gate"
			% [tab, int(stall_rows[tab]), hud.bazaar_row_count()])
	var split_moved: String = _shape_diff(stall_cols, hud.works_columns(per_column))
	_check(split_moved == "", "…and WORKS still splits its columns the same way (%s)"
		% ("unchanged %s" % stall_cols if split_moved == "" else split_moved))
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
	# LEFT/RIGHT jumps a whole COLUMN: the motion your eye makes. Two of them clears the machine list's two
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
	# stateless, so "hold this" is the same act as pressing the slot's hotbar digit; reachable from the
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
	await _real_catalogue()
	if _failures == 0:
		print("PACK LAYOUT OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)


## THE SHIPPING CATALOGUE, IN THE TWO RESEARCH STATES THAT ARE DIFFERENT SHAPES.
##
## Everything above runs on a stand-in of 10 machines and 7 Rack rows. The real one is bigger, and the
## interesting thing about it only appears at the far end of the tech tree, which no fixture in this suite
## has ever stood in. `check_pack_layout` researched exactly one locked tech and erased it four lines later.
##
##   FRESH      machines= 4 rack= 6   ask 1+1 = 2 of 3   no squeeze
##   FULL TECH  machines=19 rack= 7   ask 3+1 = 4 of 3   SQUEEZED, granted 2+1
##
## So `hud.gd`'s "this branch never fires" was a universal produced by a fixture that visits one state, and
## it fires for every player who finishes the tree. BOTH properties are held here, keyed on research
## completeness, rather than the unsqueezed one being weakened to accommodate the squeezed one: "it never
## squeezes" and "it squeezes when the tree is done" are different claims and the layer should say which
## one it is standing on.
##
## The window is asserted through `Hud.works_window_first`, the function the DRAWING code calls, so this is
## a property of the subject's own output and not a second implementation of the arithmetic agreeing with
## the first.
func _real_catalogue() -> void:
	MainView.dev_start = false
	MainView.boot_skip_title = true
	var main: MainView = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 8:
		await physics_frame
	var hud: Hud = main._hud
	if hud == null:
		_check(false, "the real scene has a HUD whose catalogue can be read")
		return
	var per_col: int = int(hud._bazaar_geometry()["rows"])
	var cols: int = Hud.BAZAAR_COLS

	# POSITIVE CONTROL. Every assertion below is about list sizes, and all of them pass on empty lists.
	_check(hud.craft_options.size() > 0 and hud.rack_options.size() > 0,
		"the shipping catalogue is %d machines and %d Rack rows, so there are lists to judge"
			% [hud.craft_options.size(), hud.rack_options.size()])

	# FRESH: the state the ticket's "never fires" claim is actually true in.
	var fm: int = hud.open_machines().size()
	var fr: int = hud.open_rack().size()
	_check(_want(fm, per_col) + _want(fr, per_col) <= cols,
		"fresh: both lists fit UNSQUEEZED (%d machines + %d rack ask %d of %d columns)"
			% [fm, fr, _want(fm, per_col) + _want(fr, per_col), cols])

	# FULL TECH: the state nothing has ever visited.
	for tid: StringName in ResearchRules.ORDER:
		main.sim.research[tid] = true
	var tm: int = hud.open_machines().size()
	var tr: int = hud.open_rack().size()
	_check(tm > fm, "researching the whole ladder opened more machines (%d -> %d)" % [fm, tm])
	var want: int = _want(tm, per_col) + _want(tr, per_col)
	_check(want > cols,
		"full tech: the counter IS squeezed (%d machines + %d rack ask %d of %d) — the state hud.gd said never happens"
			% [tm, tr, want, cols])

	# ...AND THE WINDOW STILL CONTAINS THE CURSOR, which is what makes the squeeze survivable and what
	# nothing has ever checked. Walked over every row of both groups, not sampled.
	var lay: Dictionary = hud.works_columns(per_col)
	var lost: Array[String] = []
	_walk_window(tm, per_col * int(lay["machines"]), 0, lost, "MACHINES")
	_walk_window(tr, per_col * int(lay["rack"]), tm, lost, "THE RACK")
	_check(lost.is_empty(),
		"full tech: every row of both groups is inside the drawn window when the cursor is on it%s"
			% ["" if lost.is_empty() else " — LOST: " + ", ".join(lost.slice(0, 6))])
	_adaptive_panel(main, hud)
	main.queue_free()


## What one list ASKS for, before `works_columns` clamps it.
func _want(count: int, per_col: int) -> int:
	return maxi(1, ceili(float(count) / float(maxi(per_col, 1))))


## Put the cursor on every row of a group and record any that the drawing code would not have drawn.
func _walk_window(count: int, capacity: int, base: int, lost: Array[String], tag: String) -> void:
	var drawn: int = mini(capacity, count)
	for i: int in count:
		var cursor: int = base + i
		var first: int = Hud.works_window_first(count, capacity, base, cursor)
		if i < first or i >= first + drawn:
			lost.append("%s row %d (window %d..%d)" % [tag, i, first, first + drawn - 1])


## THE COUNTER TAKES THE HEIGHT ITS OPEN TAB ASKS FOR, and a fresh pack asks for less than a stocked one.
##
## The panel used to draw `BAZAAR_SIZE` whatever the tab held, so a fresh game's one-item PACK covered the
## same 91.8% of the canvas as a finished game's nineteen-machine WORKS list. `_bazaar_wanted_h` ended that
## and nothing anywhere held it (the only reader outside the class was a scratch probe), so a counter put
## back on a fixed height would have passed every layer in this suite, this one included.
##
## ORDERED, NOT PINNED TO A NUMBER. `wanted == 206` would pin today's arithmetic, and it would go red the
## first time somebody legitimately adds four pixels of padding, which teaches the next reader to edit the
## number instead of reading it. What is asserted is the ORDER, plus the two clamp ends, which are the
## places an adaptive panel stops being adaptive.
##
## AND THOSE ENDS ARE ASSERTED AS EQUALITIES ON PURPOSE. `_bazaar_wanted_h` finishes in a `clampf` between
## `BAZAAR_MIN_H` and `BAZAAR_SIZE.y`, so `wanted >= BAZAAR_MIN_H` and `wanted <= BAZAAR_SIZE.y` are
## properties of that clamp and hold whatever the tabs contain; the same shape as the column total this
## file used to read back out of `works_columns` after `works_columns` had clamped it, and no more able to
## fail. The equalities can fail. A fresh pack is one row of wells and `BAZAAR_MIN_H` is written as that row
## plus the fixed furniture, so the floor is where PACK's sum LANDS and not where it is caught; BENCH's
## deepest tier at full chip height asks for more than the panel may ever be, so a tree that had become
## short enough to fit inside the ceiling would say so here rather than quietly stop being clamped.
##
## MEASURED ON `_bazaar_wanted_h`, NOT ON THE PANEL'S DRAWN HEIGHT. `_bazaar_geometry` reports `_bazaar_h`,
## which `_process` eases toward the want and which starts at `BAZAAR_SIZE.y`; in a scene where nobody has
## opened the counter that field is still sitting on its default, so all three readings would come back as
## the full panel and the comparison would be between two copies of one constant.
##
## THE PACK IS FILLED THROUGH THE SIM, by resting a pile of real catalogue items on the ground and having
## the sim scoop it, which is the collect half of the pack's own spit-out/fall/collect. The height derives
## from `inventory_slots()`, which derives from `inventory`, so a fixture that wrote a row count would have
## posed a number the counter never consults.
func _adaptive_panel(main: MainView, hud: Hud) -> void:
	# Nothing above this line puts anything in the pack, so this is still the pack a new game hands you.
	# The research loop did run, and it does not reach these two: BENCH's height is the SHAPE of the tree,
	# not how much of it is yours, and PACK's is what you carry.
	var fresh_slots: int = main.sim.inventory_slots().size()
	var fresh_h: float = _asks_for(hud, Hud.TAB_PACK)
	var bench_h: float = _asks_for(hud, Hud.TAB_BENCH)
	# The machines the counter sells, which are the items a pack fills up with. Taken from the catalogue
	# rather than written out here, so this stays a stocked pack on the day a machine is added.
	var pile: Dictionary = {}
	for id: StringName in hud.craft_ids:
		if id != &"":
			pile[id] = 4
	main.sim.ground[Vector2i.ZERO] = pile
	var scooped: int = main.sim.collect_ground(Vector2i.ZERO)
	var stocked_slots: int = main.sim.inventory_slots().size()
	var stocked_h: float = _asks_for(hud, Hud.TAB_PACK)
	print("  the counter asks for %.0f fresh (%d slots), %.0f stocked (%d), %.0f on BENCH — of %.0f..%.0f"
		% [fresh_h, fresh_slots, stocked_h, stocked_slots, bench_h, Hud.BAZAAR_MIN_H, Hud.BAZAAR_SIZE.y])
	# NON-VACUITY: a statement about the FIXTURE. If the scoop moved nothing the two PACK readings would be
	# one reading taken twice, and the strict inequality below would be reporting that the pack never
	# changed as if it were reporting that the panel never grew. It also fixes the attribution of a red:
	# a pile too small to reach a second row of wells fails HERE, by name, and not as the ordering.
	_check(scooped > 0 and stocked_slots > fresh_slots,
		"fixture: the sim scooped %d items into the pack (%d slots -> %d)"
			% [scooped, fresh_slots, stocked_slots])
	_check(is_equal_approx(fresh_h, Hud.BAZAAR_MIN_H),
		"a fresh pack asks for the counter's floor, exactly (%.0f of %.0f)" % [fresh_h, Hud.BAZAAR_MIN_H])
	_check(stocked_h > fresh_h + 0.5,
		"…and a stocked pack asks for MORE than a fresh one (%.0f -> %.0f)" % [fresh_h, stocked_h])
	_check(is_equal_approx(bench_h, Hud.BAZAAR_SIZE.y),
		"…and the deepest BENCH tier is still held at the ceiling, unchanged (%.0f of %.0f)"
			% [bench_h, Hud.BAZAAR_SIZE.y])


## What the counter asks for with `tab` open, reached through the setter the keys go through. The tab is
## what selects the term inside `_bazaar_wanted_h`, and `set_bazaar_tab` is also where a tab change
## re-clamps the row it remembers, so writing `bazaar_tab` here would measure a tab nobody switched to.
func _asks_for(hud: Hud, tab: int) -> float:
	hud.set_bazaar_tab(tab)
	return hud._bazaar_wanted_h()
