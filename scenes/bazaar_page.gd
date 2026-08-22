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

## The two primitives the bench reaches for, mirrored with the canvas this page was handed.

func _round_rect(rect: Rect2, r: float, col: Color) -> void:
	if probing:
		panel_probe.append(rect)
	Visuals.round_rect(_canvas, rect, r, col)


func _draw_thing_icon(id: StringName, box: Rect2) -> void:
	Visuals.thing_icon(_canvas, id, box, _icons)


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