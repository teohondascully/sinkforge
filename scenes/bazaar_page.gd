class_name BazaarPage
extends RefCounted

## THE COUNTER'S PAGES, WHICH ARE NOT THE COUNTER.
##
## `Hud` owns the Bazaar's shell: when it is open, how tall it has eased to, which tab is selected, and
## what the focused row does. This owns what the tabs DRAW. The two change for different reasons -- a
## new tab is a shell edit, a new row on the bench is a page edit -- and the shell is the part that has
## to keep working while the pages move here one at a time.
##
## It starts with the bench because the bench is the loosest of the five clusters the Bazaar decomposes
## into: nine functions that reach outside themselves for a canvas, a font, the sim, the icon table and
## one id. Works, the rail, the pack and the detail plate follow into this file, in that order, because
## the detail plate is the hub every other cluster calls and it has to move last.
##
## Nothing here calls back into `Hud`. That is the property worth keeping while the rest arrives: the
## shell may call in, and this may not call out, so no slice has to unpick a cycle a previous one made.

## The canvas, the font, the sim and the icon table are held rather than passed. Nine functions handing
## each other five arguments on every hop is the shape this decomposition exists to avoid; `Hud` re-binds
## them on entry so nothing observed here can be stale.
var _canvas: CanvasItem = null
var _font: Font = ThemeDB.fallback_font
var _sim: FactorySim = null
var _icons: Dictionary = {}                 ## `Hud.machine_icons`, assembled by `main.gd`
var probing: bool = false
var panel_probe: Array[Rect2] = []          ## THE SAME array object Hud holds, shared by reference


## Where the name starts and how much of the chip is left for it. The lamp is the only other thing on
## that line, so the indent is the lamp's own right edge plus air. It used to be 15 on a narrow chip and
## 19 on a wide one, beside a dot drawn at 8 and 11 with a radius of 3.2, which is 3.8 and 4.8 of dead
## space in the one measurement the names were short of.
const BENCH_NARROW: float = 96.0      ## under this a chip tucks its lamp in against the edge
const BENCH_DOT_R: float = 3.2
const BENCH_NAME_AIR: float = 1.8     ## lamp → first letter
const BENCH_NAME_PAD: float = 4.0     ## last letter → the chip's right edge
const BENCH_NAME_FS: int = 11         ## the size a name is set at when the chip has the room
const BENCH_NAME_FS_MIN: int = 7

# ------------------------------------------------------------------------------------------------
# THE COUNTER'S MODEL: what is on offer, what the cursor is on, and what pressing it would do.
#
# None of this draws. It is the same split `SettingsPage` keeps -- data and pure resolvers above, the
# drawing below -- and it is the half that decides whether a row exists, whether you can afford it, and
# which of the three tabs is showing. That is the part most likely to be wrong and least visible in a
# screenshot, so it is the part worth being able to call without a running game.
#
# It moved before the works, rail and pack drawing rather than after, because those tabs read this state
# on nearly every line. Extracting a tab first would have meant threading eleven things through it.

const BAZAAR_COLS: int = 3

const PACK_CELL: float = 46.0         ## pitch of a pack well; the well itself is 6px smaller

const TAB_PACK: int = 0

const TAB_WORKS: int = 1

const TAB_BENCH: int = 2

const TAB_NAMES: Array[String] = ["PACK", "WORKS", "BENCH"]

## The ink for a short row with the cursor on it. Affordability and the cursor are orthogonal, so there
## are four combinations and not three. The name colour read `(gold if selected else UiTheme.UI_TEXT) if afford
## else grey`, with the test on `afford` outermost, so it swallowed the test on `selected` whole. A
## short row drew the same grey whether or not the cursor was on it while `if selected:` still lifted
## the plate and hung a gold spine off its left edge. That put the row being read at 3.74:1 against its
## own plate.
##
## The unselected short row moved off its own literal at the same time. `Color(0.48, 0.50, 0.56)` read
## 4.44:1 on the plain row fill, under the 4.5 this repository holds named inks to. The faint rung reads
## 5.05:1 and sits 74 steps below `UiTheme.UI_TEXT`, so the row still says "you cannot afford this" at a glance.
##
## The lift is the ramp's own step. `UiTheme.UI_TEXT_DIM` is `UiTheme.UI_TEXT_FAINT` plus exactly 0.04 on every channel,
## so one more of that unit lands the selected short row at 5.51:1 against the 5.05:1 it reads
## unselected. `UiTheme.UI_TEXT_DIM` itself measured 4.86:1: over the floor but under the unselected figure,
## which is the same inversion in miniature. It is written as the gap between the two named rungs rather
## than as `0.04`, which would be a literal equal to a difference nothing in the file relates it to.
##
## Ratios are WCAG relative luminance with channels linearised before weighing, per
## `tools/check_text_contrast.gd`. They are not the gamma-encoded Y709 quoted beside them for the plates.
const SHORT_SELECTED := Color(
	UiTheme.UI_TEXT_DIM.r + (UiTheme.UI_TEXT_DIM.r - UiTheme.UI_TEXT_FAINT.r),
	UiTheme.UI_TEXT_DIM.g + (UiTheme.UI_TEXT_DIM.g - UiTheme.UI_TEXT_FAINT.g),
	UiTheme.UI_TEXT_DIM.b + (UiTheme.UI_TEXT_DIM.b - UiTheme.UI_TEXT_FAINT.b))

const BAZAAR_GUTTER: float = 10.0

## Three columns of eight is twenty-four rows, not the 22 a two-column layout needed, so the row can
## afford the two pixels back and the type can breathe.
const BAZAAR_ROW_H: float = 24.0

## The counter's own state. `Hud` keeps a property of each name forwarding here, because `scenes/main.gd`
## and six tools have always read them there.
var bazaar_tab: int = TAB_PACK
var bazaar_row: int = 0
var craft_ids: Array[StringName] = []
var craft_options: Array[Dictionary] = []
var rack_ids: Array[StringName] = []
var rack_options: Array[Dictionary] = []
var _bazaar_rows: PackedInt32Array = PackedInt32Array()
var _bazaar_t: float = 0.0            ## 0..1 open ease, driven in _process


func open_machines() -> Array[int]:
	return _unlocked(craft_ids, craft_options.size())


func open_rack() -> Array[int]:
	return _unlocked(rack_ids, rack_options.size())


## How many columns each WORKS group takes, at this row height. Groups are laid left to right and never
## share a column, because the left list is what you build from your own materials and the right is what
## you buy with refined goods, and a player should not have to work that out from a row's position.
func works_columns(rows: int) -> Dictionary:
	var want: Dictionary = works_demand(rows)
	var m: int = int(want["machines"])
	var r: int = int(want["rack"])
	# The counter has a fixed number of columns, so two lists asking for more than it has get squeezed
	# rather than allowed to run off the panel's edge, and the group that overflows falls back to a window
	# around the cursor. This clamp is the failure mode made legible rather than the intended layout, and
	# it is the late-game normal rather than a safety valve. Measured on the real scene:
	#
	#   FRESH      machines= 4 rack= 6   ask 1+1=2 of 3   no squeeze
	#   FULL TECH  machines=19 rack= 7   ask 3+1=4 of 3   squeezed, granted 2+1
	#
	# The squeeze is kept because the alternative measured worse: a fourth column is 124.5px, and
	# `_works_row` would give the name about 48px, truncating every machine. Three columns and a cursor
	# window is the design, and `works_window_first` is what makes the window testable.
	if m + r > BAZAAR_COLS:
		r = clampi(r, 1, BAZAAR_COLS - 1)
		m = BAZAAR_COLS - r
	return {"machines": m, "rack": r, "total": m + r}


## The window's first row. A group shorter than its columns starts at 0 and this is a no-op, while a
## longer one shows `capacity` rows centred on the cursor, clamped so it never runs past either end.
##
## Three columns and a window is the right answer rather than a fourth column: 528px of content over
## four columns is 124.5px a row, and `_works_row` gives the name `width - 36 - cost glyphs`, about 48px
## at size 10, which truncates every machine name. Measured before choosing.
static func works_window_first(count: int, capacity: int, base: int, cursor: int) -> int:
	if count <= capacity:
		return 0
	return clampi(cursor - base - capacity / 2, 0, count - capacity)


## The id of the i-th craftable, supplied explicitly by MainView as `craft_ids`, parallel to
## `craft_options`, so machines and tools can interleave without relying on `_icons` insertion
## order. It falls back to the old `_icons`-keys derivation if `craft_ids` was not set.
func _craft_id(i: int) -> StringName:
	if i < craft_ids.size():
		return craft_ids[i]
	var keys: Array = _icons.keys()
	return keys[i] if i < keys.size() else &""


func _can_afford(cost: Dictionary) -> bool:
	for item: StringName in cost:
		if int(_sim.inventory.get(item, 0)) < int(cost[item]):
			return false
	return true


## The fewest rows at which the two WORKS lists fit the counter's columns, asked of `works_columns`
## itself so the squeeze rule and this measure cannot disagree. Fresh, machines 4 and rack 6 fit in
## three columns at four rows. With the full tech tree, machines 19 and rack 7, it wants ten rows, which
## asks for more height than the counter has and is clamped.
func _works_rows_needed() -> int:
	for r: int in range(1, 25):
		if int(works_demand(r)["total"]) <= BAZAAR_COLS:
			return r
	return 24


## What the two lists ask for at a given row count, before the squeeze. The split exists because a
## caller that needs the demand and gets the grant reads a constant. `works_columns` clamps its answer
## to `BAZAAR_COLS`, so its total is never above three whatever the catalogue does, and
## `_works_rows_needed` scanning for the first row count whose total fits got three at one row and sized
## the counter for a single row of WORKS.
func works_demand(rows: int) -> Dictionary:
	var m: int = maxi(1, ceili(float(open_machines().size()) / float(maxi(rows, 1))))
	var r: int = maxi(1, ceili(float(open_rack().size()) / float(maxi(rows, 1))))
	return {"machines": m, "rack": r, "total": m + r}


## How many rows the active tab offers the cursor. WORKS is the two lists end to end; BENCH is the ladder.
func bazaar_row_count() -> int:
	match bazaar_tab:
		TAB_WORKS:
			return open_machines().size() + open_rack().size()
		TAB_BENCH:
			return ResearchRules.ORDER.size()
		_:
			return _sim.inventory_slots().size()


## What Enter would do, as {kind, id}, where kind is "machine", "rack", "tech" or "". The panel owns the
## cursor because the panel draws it, and MainView owns the verbs, so the highlighted row and the thing
## that happens cannot drift apart.
func bazaar_action() -> Dictionary:
	var i: int = bazaar_row
	match bazaar_tab:
		TAB_WORKS:
			if i < 0 or i >= bazaar_row_count():
				return {}
			# The cursor walks the open rows, while `row` indexes the full catalogue, because that is what
			# MainView's verbs are keyed on. Filtering the view must never renumber the world.
			var open_m: Array[int] = open_machines()
			if i < open_m.size():
				return {"kind": "machine", "id": _craft_id(open_m[i]), "row": open_m[i]}
			var r: int = open_rack()[i - open_m.size()]
			return {"kind": "rack", "id": rack_ids[r] if r < rack_ids.size() else &"", "row": r}
		TAB_BENCH:
			if i < 0 or i >= ResearchRules.ORDER.size():
				return {}
			return {"kind": "tech", "id": ResearchRules.ORDER[i], "row": i}
		_:
			# PACK's verb is HOLD. It was the one tab with a cursor and nothing to do with it, and holding a
			# thing from the pack screen is what the stateless bit-equipping in `BitRules` wants: what is in your
			# hand is what you dig with.
			var slots: Array[Dictionary] = _sim.inventory_slots()
			if i < 0 or i >= slots.size():
				return {}
			return {"kind": "hold", "id": slots[i]["item"], "row": i}


## Change tab, keeping each tab's place in its own list. Re-picking the tab you are already on means
## "back to the top", which is the only way left to send the cursor home now that leaving and returning
## no longer does it.
func set_bazaar_tab(tab: int) -> void:
	var want: int = clampi(tab, TAB_PACK, TAB_BENCH)
	# Sized from the tab list itself on first use, so a fourth tab needs no change here and cannot index
	# past the end of the store. `resize` fills the new slots with zero, which is row one.
	if _bazaar_rows.size() < TAB_NAMES.size():
		_bazaar_rows.resize(TAB_NAMES.size())
	if want == bazaar_tab:
		bazaar_row = 0
		_bazaar_rows[want] = 0
		return
	_bazaar_rows[bazaar_tab] = bazaar_row
	bazaar_tab = want
	# A list can shrink under a stored index while you are away from it: spend the last of a material and
	# its well leaves the pack, or build a machine and the rack row goes. So the stored row is re-clamped
	# against the count the tab has now. `bazaar_row_count()` reads the _sim on two of the three tabs, so a
	# HUD without one keeps the old behaviour of landing at the top rather than reaching through a null.
	var n: int = bazaar_row_count() if _sim != null else 0
	bazaar_row = clampi(_bazaar_rows[want], 0, maxi(n - 1, 0))
	_bazaar_rows[want] = bazaar_row


## Ease-out cubic. The counter's rise reads as arriving because it slows down at the end.
func _bazaar_ease() -> float:
	var u: float = 1.0 - _bazaar_t
	return 1.0 - u * u * u


## How many wells fit across the content and how many rows they take. `_tab_pack` calls the first of
## these rather than keeping its own copy of the division.
func _pack_cols(w: float) -> int:
	return maxi(1, int(w / PACK_CELL))


func _pack_rows(w: float) -> int:
	var n: int = _sim.inventory_slots().size()
	return maxi(1, ceili(float(n) / float(_pack_cols(w))))


## What the counter will sell you today: the indices of the rows whose tech is already yours.
##
## WORKS used to list the whole catalogue, sixteen machines deep with thirteen greyed out behind techs
## you had not reached, which is a wall of things you cannot have in the place you go to get things. The
## future has a home already: the BENCH, where every locked machine sits under the rung that unlocks it.
func _unlocked(ids: Array[StringName], n: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in n:
		var id: StringName = ids[i] if i < ids.size() else &""
		var lock: StringName = ResearchRules.locking_tech(id)
		if lock == &"" or _sim.is_researched(lock):
			out.append(i)
	return out


# ------------------------------------------------------------------------------------------------
# THE PAGES AS THEY ARE DRAWN.

## The two primitives the bench reaches for, mirrored with the canvas this page was handed.

func _round_rect(rect: Rect2, r: float, col: Color) -> void:
	if probing:
		panel_probe.append(rect)
	Visuals.round_rect(_canvas, rect, r, col)


func _draw_thing_icon(id: StringName, box: Rect2) -> void:
	Visuals.thing_icon(_canvas, id, box, _icons)


func _item_label(item: StringName) -> String:
	return Visuals.thing_label(item, _icons)


func _tracked(text: String, at: Vector2, size: int, track: float, col: Color) -> void:
	Visuals.tracked(_canvas, _font, text, at, size, track, col)


func _keycap(at: Vector2, key: String, fs: int = 8) -> float:
	return Visuals.keycap(_canvas, _font, at, key, fs, panel_probe if probing else [])


## BENCH: the research ladder as a graph and the verb that acts on it, on one screen.
##
## The tree used to be a separate full-screen overlay on `T` that showed the ladder you could not act
## on, because the research verb lived back inside the pack screen. Now the ladder is a tab of the same
## counter, a cursor walks it, and the selected rung is the one the plate prices and the one Enter takes.
##
## Tiers derive from each tech's `requires` chain, so a branching tree simply stacks its chips in a
## column and no layout changes. The chips are scaled to the panel rather than the panel to the chips.
func _tab_bench(g: Dictionary, picked: StringName) -> void:
	var content: Rect2 = g["content"]
	var tiers: Array = _bench_tiers()
	if tiers.is_empty():
		return
	var tallest: int = _bench_tallest()
	var gap := Vector2(10.0, 6.0)
	var chip := Vector2(
		minf(108.0, (content.size.x - float(tiers.size() - 1) * gap.x) / float(tiers.size())),
		minf(64.0, (content.size.y - float(tallest - 1) * gap.y) / float(tallest)))
	var span := Vector2(float(tiers.size()) * chip.x + float(tiers.size() - 1) * gap.x,
		float(tallest) * chip.y + float(tallest - 1) * gap.y)
	var at := Vector2(content.position.x + (content.size.x - span.x) * 0.5,
		content.position.y + (content.size.y - span.y) * 0.5)
	# One type size for the whole ladder, chosen once here rather than per chip. See `_bench_name_fs`.
	var fs: int = _bench_name_fs(chip.x)
	var rects: Dictionary = {}
	for ti: int in tiers.size():
		var tier: Array = tiers[ti]
		var col_h: float = float(tier.size()) * chip.y + float(tier.size() - 1) * gap.y
		for ni: int in tier.size():
			rects[tier[ni]] = Rect2(at + Vector2(float(ti) * (chip.x + gap.x),
				(span.y - col_h) * 0.5 + float(ni) * (chip.y + gap.y)), chip)
	# Arrows first, under the chips, from the prereq's right edge to the dependent's left edge. A path you
	# have already walked glows, so the tree reads as a route rather than as a table.
	for tid: StringName in ResearchRules.ORDER:
		var req: StringName = ResearchRules.tech(tid).get("requires", &"")
		if req == &"" or not rects.has(req):
			continue
		var a: Rect2 = rects[req]
		var b: Rect2 = rects[tid]
		var p0 := Vector2(a.end.x, a.position.y + a.size.y * 0.5)
		var p1 := Vector2(b.position.x, b.position.y + b.size.y * 0.5)
		var lc: Color = Color(0.48, 0.72, 0.52, 0.85) if _sim.is_researched(req) \
			else Color(0.26, 0.29, 0.36, 0.85)
		_canvas.draw_line(p0, p1, lc, 1.5)
		_canvas.draw_colored_polygon(PackedVector2Array([p1, p1 + Vector2(-5.0, -3.5), p1 + Vector2(-5.0, 3.5)]), lc)
	var next: StringName = ResearchRules.next_tech(_sim.research)
	for tid: StringName in ResearchRules.ORDER:
		_draw_tech_chip(tid, rects[tid], tid == next, tid == picked, fs)


## The research tree, grouped by how many prerequisites deep each tech is. It is lifted out of
## `_tab_bench` so the drawing and the sizing read the same tiers.
func _bench_tiers() -> Array:
	var tiers: Array = []
	for tid: StringName in ResearchRules.ORDER:
		var d: int = 0
		var cur: StringName = ResearchRules.tech(tid).get("requires", &"")
		while cur != &"":
			d += 1
			cur = ResearchRules.tech(cur).get("requires", &"")
		while tiers.size() <= d:
			tiers.append([])
		(tiers[d] as Array).append(tid)
	return tiers


func _bench_tallest() -> int:
	var tallest: int = 1
	for tier: Array in _bench_tiers():
		tallest = maxi(tallest, tier.size())
	return tallest


func _bench_dot_x(w: float) -> float:
	return 8.0 if w < BENCH_NARROW else 11.0


func _bench_indent(w: float) -> float:
	return _bench_dot_x(w) + BENCH_DOT_R + BENCH_NAME_AIR


## The ladder's one type size: the largest at which the longest name on it fits a chip. Every name on
## the board is then set at the size the worst of them can take.
##
## Each chip used to shrink its own name until it fit, and a chip only knows its own string. On the
## finished tree that printed Descent, Ironworks and Machining at 9, Prospecting and Enrichment at 8,
## and Automation and Crosscutting at 7: three sizes on one board, tracking the length of the word.
##
## Measured on the finished ladder, whose seven tiers leave a chip 66.9 wide, the longest name is
## Crosscutting at 49.0 across at size 8 against 49.9 of room. So the whole board sets at 8. Size 9 is
## not available at seven tiers, where Crosscutting asks for 55.0, and the consequence of setting from
## the longest name is that the board drops a size together the day the ladder grows a longer one.
## Uniformly small is the smaller cost: a name smaller than its neighbours reads as worth less.
func _bench_name_fs(w: float) -> int:
	var room: float = w - _bench_indent(w) - BENCH_NAME_PAD
	var fs: int = BENCH_NAME_FS
	while fs > BENCH_NAME_FS_MIN and _bench_name_w(fs) > room:
		fs -= 1
	return fs


func _bench_name_w(fs: int) -> float:
	var w: float = 0.0
	for tid: StringName in ResearchRules.ORDER:
		w = maxf(w, _font.get_string_size(str(ResearchRules.tech(tid)["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	return w


## One tech chip: a lamp, a name, and the machines it unlocks. Its price moved to the detail plate,
## because a chip carrying the price had to shrink the name to fit it, and a truncated name such as
## "Prospecti" costs the player more than a second glance downward does.
func _draw_tech_chip(tid: StringName, rr: Rect2, is_next: bool, picked: bool, fs: int) -> void:
	var t: Dictionary = ResearchRules.tech(tid)
	var done: bool = _sim.is_researched(tid)
	if picked:
		_round_rect(rr, 5.0, Color(0.176, 0.153, 0.098))
		_canvas.draw_rect(Rect2(rr.position + Vector2(0.0, 3.0), Vector2(2.0, rr.size.y - 6.0)), UiTheme.UI_ACCENT)
	elif done:
		_round_rect(rr, 5.0, Color(0.078, 0.113, 0.086))
	else:
		_round_rect(rr, 5.0, Color(1.0, 1.0, 1.0, 0.040 if is_next else 0.022))
	var name_col: Color = UiTheme.STATE_INK if done \
		else ((UiTheme.GOLD_PALE if picked else UiTheme.UI_TEXT) if is_next else UiTheme.UI_TEXT_FAINT)
	var indent: float = _bench_indent(rr.size.x)
	var room: float = rr.size.x - indent - BENCH_NAME_PAD
	_canvas.draw_circle(rr.position + Vector2(_bench_dot_x(rr.size.x), 13.0), BENCH_DOT_R,
		Color(0.38, 0.78, 0.44) if done else (UiTheme.UI_ACCENT if is_next else Color(0.22, 0.24, 0.30)))
	_canvas.draw_string(_font, rr.position + Vector2(indent, 16.0), str(t["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, room, fs, name_col)
	# What it buys: the unlocked machines' faces, dimmed until the tech is live.
	var ux: float = rr.position.x + 7.0
	for uid: StringName in (t.get("unlocks", []) as Array):
		var box := Rect2(ux, rr.position.y + 26.0, 17.0, 17.0)
		if box.end.x > rr.end.x - 3.0 or box.end.y > rr.end.y - 3.0:
			break                                          # a narrow chip shows what it can, never overflows
		_draw_thing_icon(uid, box)
		if not done:
			_canvas.draw_rect(box, Color(0.0, 0.0, 0.0, 0.22 if is_next else 0.45))
		ux += 20.0


## A tech has no glyph of its own, being knowledge, so its plate shows what it buys: the machines it
## unlocks, laid out big. That is also the honest answer to "why would I research this".
func _draw_tech_art(tid: StringName, art: Rect2) -> void:
	var unlocks: Array = ResearchRules.tech(tid).get("unlocks", [])
	if unlocks.is_empty():
		Visuals.draw_item(_canvas, art.get_center(), 40.0, &"ingot")
		return
	var n: int = mini(4, unlocks.size())
	if n == 1:
		_draw_thing_icon(unlocks[0], Rect2(art.get_center() - Vector2(21.0, 21.0), Vector2(42.0, 42.0)))
		return
	var cell: float = 25.0
	var cols: int = 2
	var span := Vector2(float(cols) * cell, float((n + cols - 1) / cols) * cell)
	var at: Vector2 = art.get_center() - span * 0.5
	for i: int in n:
		_draw_thing_icon(unlocks[i], Rect2(at + Vector2(float(i % cols) * cell + 2.0,
			float(i / cols) * cell + 2.0), Vector2(cell - 4.0, cell - 4.0)))


## WORKS: the counter, what you build from your own materials, and the Rack, what you buy with refined
## goods, as a dense card grid. No scrolling, no scrollbar, no shift-digit.
func _tab_works(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
	var rows: int = int(g["rows"])
	var lay: Dictionary = works_columns(rows)
	# The columns spread to fill the counter. Once WORKS lists only what you can build, most of the game is
	# two columns rather than three, and three columns of narrow rows with an empty third is exactly the
	# dead space this layout exists to kill. It is capped, because a row wide enough to lose its price at
	# the far end is its own problem.
	var used: int = maxi(1, int(lay["total"]))
	var col_w: float = minf(268.0,
		(content.size.x - BAZAAR_GUTTER * float(used - 1)) / float(used))
	var open_m: Array[int] = open_machines()
	var open_r: Array[int] = open_rack()
	_works_group(content, 0, int(lay["machines"]), col_w, rows, "MACHINES", craft_options, open_m, 0, true)
	_works_group(content, int(lay["machines"]), int(lay["rack"]), col_w, rows, "THE RACK",
		rack_options, open_r, open_m.size(), false)
	# ...and one quiet line saying the rest exists and where it lives. Hiding the locked half is only
	# honest if the panel still says there is one, because otherwise the counter looks finished at four
	# machines and the tech ladder looks optional.
	var hidden: int = (craft_options.size() - open_m.size()) + (rack_options.size() - open_r.size())
	if hidden > 0:
		# The key is a cap and not a word in a sentence. "press 3 for the BENCH" asks the reader to parse an
		# instruction to find the one glyph that matters, while the cap grammar the rail and footer already
		# use puts it where the eye lands.
		#
		# The line is a pointer rather than an offer: the thing your input reaches is the cap, and the cap
		# draws itself. Off the gold with the headings, for the reason written at `GOLD_DIM`.
		var dim: Color = UiTheme.UI_TEXT_DIM
		var y: float = content.end.y - 2.0
		var head: String = "%d more wait behind research" % hidden
		_canvas.draw_string(_font, Vector2(content.position.x + 1.0, y), head,
			HORIZONTAL_ALIGNMENT_LEFT, content.size.x, 9, dim)
		var x: float = content.position.x + 1.0 \
			+ _font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 10.0
		x += _keycap(Vector2(x, y - 10.0), "3", 8) + 5.0
		_canvas.draw_string(_font, Vector2(x, y), "BENCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, dim)


## One group: a list poured down as many columns as it needs, left to right. `base` is where the group
## starts in the panel's flat cursor index, so the highlight and `bazaar_action()` cannot disagree.
func _works_group(content: Rect2, col0: int, cols: int, col_w: float, rows: int, title: String,
		opts: Array[Dictionary], open_rows: Array[int], base: int, machines: bool) -> void:
	var x0: float = content.position.x + float(col0) * (col_w + BAZAAR_GUTTER)
	# MACHINES / THE RACK are labels, in the grey ramp for the reason written at `GOLD_DIM`. This is the
	# site where the gold rung was doing the most damage: a dimmed cut of the affordance colour, standing
	# directly over rows where dim genuinely means you cannot afford the thing.
	_tracked(title, Vector2(x0 + 1.0, content.position.y - 6.0), 8, 2.0, UiTheme.UI_TEXT_DIM)
	if open_rows.is_empty():
		_canvas.draw_string(_font, Vector2(x0 + 1.0, content.position.y + 16.0), "(nothing unlocked yet)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UiTheme.UI_TEXT_DIM)
		return
	# A group longer than its columns shows a window around the cursor rather than truncating. It is lifted
	# out of this loop so `check_pack_layout` can assert a property of what the drawing computes, that the
	# cursor is always inside the window, instead of re-deriving the arithmetic and agreeing with itself.
	# It also runs headless, which `_works_group` cannot, since that only executes inside `_draw`.
	var capacity: int = rows * cols
	var first: int = works_window_first(open_rows.size(), capacity, base, bazaar_row)
	for i: int in mini(capacity, open_rows.size()):
		var oi: int = open_rows[first + i]
		var rr := Rect2(x0 + float(i / rows) * (col_w + BAZAAR_GUTTER),
			content.position.y + float(i % rows) * BAZAAR_ROW_H, col_w, BAZAAR_ROW_H - 3.0)
		_works_row(rr, opts[oi], _works_id(machines, oi), base + first + i == bazaar_row)


## One row, drawn as a card and not as an outlined box: a surface tint you can see through to the panel,
## a well for the glyph and a brass edge with a warmer fill when the cursor is on it. Nothing is
## outlined, because an outline around every row makes every row shout and the selected one shout no
## louder.
func _works_row(rr: Rect2, opt: Dictionary, id: StringName, selected: bool) -> void:
	var afford: bool = _can_afford(opt["cost"])
	if selected:
		_round_rect(rr, 4.0, Color(0.176, 0.153, 0.098))
		_canvas.draw_rect(Rect2(rr.position + Vector2(0.0, 2.0), Vector2(2.0, rr.size.y - 4.0)), UiTheme.UI_ACCENT)
	else:
		_round_rect(rr, 4.0, Color(1.0, 1.0, 1.0, 0.030))
	_draw_thing_icon(id, Rect2(rr.position + Vector2(6.0, 2.5), Vector2(16.0, 16.0)))
	var name_col: Color = (UiTheme.GOLD_PALE if selected else UiTheme.UI_TEXT) if afford \
		else (SHORT_SELECTED if selected else UiTheme.UI_TEXT_FAINT)
	var cw: float = _cost_glyphs(rr, opt["cost"])
	_canvas.draw_string(_font, rr.position + Vector2(26.0, 14.0), str(opt["name"]),
		HORIZONTAL_ALIGNMENT_LEFT, rr.size.x - 36.0 - cw, 10, name_col)


func _works_id(machines: bool, i: int) -> StringName:
	if machines:
		return _craft_id(i)
	return rack_ids[i] if i < rack_ids.size() else &""


## The price as glyphs rather than prose. "6 Iron Ingot 3 Wood" is a hundred pixels of a hundred-and-
## seventy pixel row and it clipped the name off the thing being bought: "Iron Pickax", "Blast Furnac".
## The same fact as two icons and two numbers is forty, and it reads faster besides.
##
## An ingredient you are short of prints what you are short by (`-2`) where this printed `2` in red and
## left the subtraction to the reader. It is the same number `_shortfall_note` prints in words under the
## detail button, so the row is the compressed form of that sentence. An ingredient the pack covers
## still prints its price, which is what an expert scans a row end for.
##
## The sign exists so the hue is not the only copy of it. Green covered against red short is a hue
## difference. That is nothing to a greyscale reader and nothing on a one-ingredient recipe with no
## second numeral to compare against. Both come off the same string below, so the two readers cannot be
## told different things.
##
## It costs 3px per short ingredient and nothing per covered one. A deficit cannot carry more digits
## than the price it was subtracted from, so the only growth is the sign itself: 3.0px at size 9 in the
## Open Sans SemiBold `ThemeDB.fallback_font` resolves to here. Measured at the tightest row this panel
## can draw, three ingredients in a 169.3px column with every one short, the name's budget goes 58.3 to
## 49.3. The longest name a three-ingredient row can carry is Drift Rig at 40.0px, which clears it by
## 9.3. Nothing clips.
##
## What it does not fix is the red. Against the selected row's plate that literal measures 4.20:1, under
## the 4.5 `tools/check_text_contrast.gd` holds body text to and under the 4.99 the same red reads on an
## unselected row. Every lift of it closes the value gap between green and red, which used to be the
## only thing carrying affordability without colour. The sign now carries that job.
func _cost_glyphs(rr: Rect2, cost: Dictionary) -> float:
	# One walk order for both passes. The sum is the same whichever way the dictionary is read, so the
	# width pass does not need this. It takes it anyway, because the day the two passes walk the price by
	# two different rules is the day one of them stops describing the other.
	var order: Array[StringName] = _cost_order(cost)
	var w: float = 0.0
	for item: StringName in order:
		w += 12.0 + _font.get_string_size(_cost_numeral(item, int(cost[item])),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
	var x: float = rr.end.x - 5.0 - w
	for item: StringName in order:
		var label: String = _cost_numeral(item, int(cost[item]))
		Visuals.draw_item(_canvas, Vector2(x + 6.0, rr.position.y + 10.5), 12.0, item)
		# The ink reads the sign rather than asking the pack a second time. `have < need` written out twice,
		# three lines apart, is how the mark and the colour start disagreeing about one ingredient, and
		# disagreeing is worse than either cue missing, because each reader sees only one of them.
		_canvas.draw_string(_font, Vector2(x + 13.0, rr.position.y + 14.5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9,
			UiTheme.UI_WARN if label.begins_with("-") else Color(0.482, 0.796, 0.518))
		x += 12.0 + _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x + 7.0
	return w


## What one ingredient's numeral says: the deficit when you are short of it, the price when you are not.
##
## It is a function and not an expression because the width pass and the draw pass above are two walks
## of the same dictionary, and they used to each format the numeral for themselves. The width is not
## cosmetic here: `_works_row` subtracts this function's total from the name's budget, so a numeral that
## measures narrower than it draws puts the price on top of the word it was widened to protect.
func _cost_numeral(item: StringName, need: int) -> String:
	var gap: int = _cost_gap(item, need)
	return ("-%d" % gap) if gap > 0 else str(need)


## The bill-of-materials order: the lines you still owe first, the lines the pack already settles after.
##
## The numerals were the half of this that shipped first, a deficit printing as a signed `-N` instead of
## leaving the subtraction to the reader, and fixing a numeral does not make a row of chips a bill. A
## bill is a list whose outstanding lines are grouped, because the only question anybody brings to a
## price is which lines are still open. Interleaved, that question is a scan of every ingredient and a
## comparison per chip. Grouped, it is a glance at the front of the price, and the count of open lines is
## the length of the first run.
##
## Stable inside each run, so a recipe keeps the order its `.tres` or its rung wrote it in and the only
## thing that ever moves a chip is that ingredient crossing the line. The crossing is the point rather
## than the price of it: the frame where you pick up the last ingot is the frame the owed run gets
## shorter, which is the most direct feedback on the panel and the one thing a static row could never say.
##
## It sorts the works rows and the detail plate alike, so a machine's price does not rearrange itself
## between the row you picked it from and the plate that prices it.
func _cost_order(cost: Dictionary) -> Array[StringName]:
	var owed: Array[StringName] = []
	var settled: Array[StringName] = []
	for item: StringName in cost:
		if _cost_gap(item, int(cost[item])) > 0:
			owed.append(item)
		else:
			settled.append(item)
	owed.append_array(settled)
	return owed


## The one subtraction, and the one predicate. What this ingredient is short by: positive while the pack
## cannot cover the line, zero or below once it can.
##
## Everything that tells an outstanding ingredient from a settled one reads this and nothing else: the
## order the price is walked in, the card under a detail chip, the sign on both surfaces' numerals and
## the ink they are drawn in. `have < need` was written out at four addresses before, which is
## survivable only while the four cannot disagree. They can, and a mark that disagrees with the colour
## beside it about one ingredient is worse than either cue missing, because each reader only ever sees
## one of them.
func _cost_gap(item: StringName, need: int) -> int:
	return need - int(_sim.inventory.get(item, 0))
