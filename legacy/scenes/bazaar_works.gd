class_name BazaarWorks
extends BazaarSurface

## THE WORKS TAB: the machines and the tools you can have right now, in three columns.
##
## It does not list what you cannot build. That used to be the whole catalogue, sixteen machines deep
## with thirteen greyed out, which is a wall of things you cannot have in the place you go to get things.
## The locked half has a home already, one rung at a time, on the BENCH.
##
## The stock it reads is handed to it rather than reached for: `cat` is the one catalogue the shell also
## queries, so the two cannot drift, and this tab never calls back into the page that owns it.


## The focused row, and the counter's stock.
var bazaar_row: int = 0
var cat: BazaarCatalogue = null

## Screen rect -> flat cursor index for every row this frame actually drew, so a click can be routed to
## the same index the keyboard cursor already uses. Populated in `_works_group`, read by `click_hit`, the
## same rect-cache-then-hit-test shape `Hud._alert_hits` already uses for the alert stack.
var _click_hits: Array[Dictionary] = []


## Which flat row index, if any, `mouse` (canvas coords) landed on this frame. -1 on a miss, which
## includes every frame before the tab has drawn once, so a stray click while nothing is visible yet is
## silently a no-op rather than aimed at stale geometry.
func click_hit(mouse: Vector2) -> int:
	for hit: Dictionary in _click_hits:
		if (hit["rect"] as Rect2).has_point(mouse):
			return int(hit["index"])
	return -1


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


## The fewest rows at which the two WORKS lists fit the counter's columns, asked of `works_columns`
## itself so the squeeze rule and this measure cannot disagree. Fresh, machines 4 and rack 6 fit in
## three columns at four rows. With the full tech tree, machines 19 and rack 7, it wants ten rows, which
## asks for more height than the counter has and is clamped.
func _works_rows_needed() -> int:
	var base: int = 24
	for r: int in range(1, 25):
		if int(works_demand(r)["total"]) <= BAZAAR_COLS:
			base = r
			break
	# The "N more wait behind research" line lives in this same content box, at its bottom edge, and was
	# never counted here, so the box was sized to the grid alone and the line drew on top of the grid's
	# own last row. One reserved row keeps the two from sharing space instead of moving the line elsewhere.
	if _hidden_count() > 0:
		base += 1
	return base


## The single count of what the counter is not showing: locked machines plus locked rack items. Read
## by both the height this tab asks for and the line `_tab_works` draws, so they cannot disagree about
## whether there is anything to reserve room for.
func _hidden_count() -> int:
	return (cat.craft_options.size() - cat.open_machines().size()) \
		+ (cat.rack_options.size() - cat.open_rack().size())


## What the two lists ask for at a given row count, before the squeeze. The split exists because a
## caller that needs the demand and gets the grant reads a constant. `works_columns` clamps its answer
## to `BAZAAR_COLS`, so its total is never above three whatever the catalogue does, and
## `_works_rows_needed` scanning for the first row count whose total fits got three at one row and sized
## the counter for a single row of WORKS.
func works_demand(rows: int) -> Dictionary:
	var m: int = maxi(1, ceili(float(cat.open_machines().size()) / float(maxi(rows, 1))))
	var r: int = maxi(1, ceili(float(cat.open_rack().size()) / float(maxi(rows, 1))))
	return {"machines": m, "rack": r, "total": m + r}


## WORKS: the counter, what you build from your own materials, and the Rack, what you buy with refined
## goods, as a dense card grid. No scrolling, no scrollbar, no shift-digit.
func _tab_works(g: Dictionary) -> void:
	var content: Rect2 = g["content"]
	var rows: int = int(g["rows"])
	_click_hits.clear()    # stale unless _works_group repopulates it below; a miss this frame is a miss
	# ...and one quiet line saying the rest exists and where it lives. Hiding the locked half is only
	# honest if the panel still says there is one, because otherwise the counter looks finished at four
	# machines and the tech ladder looks optional. When it is shown, the grid gets one fewer row so the
	# line has its own space at the bottom of the content box instead of drawing over the last card row.
	# `_works_rows_needed` reserved that row already, matched here by the same `_hidden_count`.
	var hidden: int = _hidden_count()
	var grid_rows: int = rows - (1 if hidden > 0 else 0)
	var lay: Dictionary = works_columns(grid_rows)
	# The columns spread to fill the counter. Once WORKS lists only what you can build, most of the game is
	# two columns rather than three, and three columns of narrow rows with an empty third is exactly the
	# dead space this layout exists to kill. It is capped, because a row wide enough to lose its price at
	# the far end is its own problem.
	var used: int = maxi(1, int(lay["total"]))
	var col_w: float = minf(268.0,
		(content.size.x - BAZAAR_GUTTER * float(used - 1)) / float(used))
	var open_m: Array[int] = cat.open_machines()
	var open_r: Array[int] = cat.open_rack()
	_works_group(content, 0, int(lay["machines"]), col_w, grid_rows, "MACHINES", cat.craft_options, open_m, 0, true)
	_works_group(content, int(lay["machines"]), int(lay["rack"]), col_w, grid_rows, "THE RACK",
		cat.rack_options, open_r, open_m.size(), false)
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
		var idx: int = base + first + i
		_works_row(rr, opts[oi], _works_id(machines, oi), idx == bazaar_row)
		_click_hits.append({"rect": rr, "index": idx})


## One row, drawn as a card and not as an outlined box: a surface tint you can see through to the panel,
## a well for the glyph and a brass edge with a warmer fill when the cursor is on it. Nothing is
## outlined, because an outline around every row makes every row shout and the selected one shout no
## louder.
func _works_row(rr: Rect2, opt: Dictionary, id: StringName, selected: bool) -> void:
	var afford: bool = BazaarCosts.can_afford(_sim.inventory, opt["cost"])
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
		return cat._craft_id(i)
	return cat.rack_ids[i] if i < cat.rack_ids.size() else &""


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
	var order: Array[StringName] = BazaarCosts.order(_sim.inventory, cost)
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
