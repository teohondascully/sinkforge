class_name BazaarPack
extends BazaarSurface

## THE PACK TAB: what you are carrying, and what the belt is doing to it.
##
## A grid of wells over a summary band. The band is the part worth explaining: it is bought out of the
## grid's own height rather than added under it, so a pack that grows a row loses the room from the
## same budget and the panel never has to grow to accommodate its own summary.
##
## It calls nothing back. Everything it needs beyond the counter's shared surface -- the focused row and
## the hotbar's selection -- is handed to it, which is why this was the first tab that could be lifted
## whole once `BazaarSurface` existed.


## The focused row and the hotbar's current pick, both handed down by the page each time it draws.
var bazaar_row: int = 0
var _inv_selected: Callable

## How tall the summary under the wells is and 0.0 when it has nothing to say. `_bazaar_wanted_h` adds
## this to what PACK asks for and `_tab_pack` takes the same number back off the bottom of the grid. The
## band the summary draws into and the height the panel was sized to are therefore one piece of
## arithmetic run twice rather than two numbers that have to agree.
##
## They were two numbers and they did not agree. The summary tested `top > content.end.y - 30.0`, which
## needs `content.size.y >= rows*46 + 44`, while PACK's asking height had no term for the summary in it
## and `content` came out at exactly `rows*46`. Across 1 to 6 rows of wells the guard's two sides read
## 185/141, 208/164, 231/187, 254/210, 298/212 and 344/212. The summary has therefore only ever reached
## the screen on frames where `_bazaar_h` was still easing down from a taller tab.
##
## Four rows, because the band is bought out of the grid above it. At four the band is
## 14 + 12 + 3*17 + 7 = 84px, which a one-row and a two-row pack both fit under the 348 cap.
const LEDGER_GAP: float = 14.0        ## last row of wells to the header's baseline


const LEDGER_HEAD: float = 12.0       ## header baseline to the first row's baseline


const LEDGER_MAX: int = 4             ## goods listed; the verdict shares the header's line


const LEDGER_ROW: float = 17.0        ## row pitch


const LEDGER_TAIL: float = 7.0        ## last baseline to the bottom of the bar sitting on it


## The hovered-thing tooltip. The pack tab and the hotbar both set it and the Hud draws it, so it lives
## here with a property of each name on the Hud rather than being passed either way.
var _tooltip_item: StringName = &""
var _tooltip_count: int = 0
var _tooltip_anchor: Vector2 = Vector2.ZERO   ## top-centre of the hovered slot


## Screen rect -> flat cursor index for every well this frame actually drew, the same cache-then-hit-test
## shape `BazaarWorks._click_hits` uses. Populated in `_tab_pack`, read by `click_hit`.
var _click_hits: Array[Dictionary] = []


func click_hit(mouse: Vector2) -> int:
	for hit: Dictionary in _click_hits:
		if (hit["rect"] as Rect2).has_point(mouse):
			return int(hit["index"])
	return -1


## How many wells fit across the content and how many rows they take. `_tab_pack` calls the first of
## these rather than keeping its own copy of the division.
func _pack_cols(w: float) -> int:
	return maxi(1, int(w / PACK_CELL))


func _pack_rows(w: float) -> int:
	var n: int = _sim.inventory_slots().size()
	return maxi(1, ceili(float(n) / float(_pack_cols(w))))


## PACK: the whole carried inventory as a grid of wells, given the whole width. It is the same pack it
## always was, and it simply stopped sharing a 360px column with two other screens.
func _tab_pack(g: Dictionary) -> void:
	_click_hits.clear()    # stale unless the loop below repopulates it; a miss this frame is a miss
	var content: Rect2 = g["content"]
	var slots: Array[Dictionary] = _sim.inventory_slots()
	var cell: float = PACK_CELL
	var cols: int = _pack_cols(content.size.x)
	# The wells are served first and the summary gets what is left. `_bazaar_wanted_h` asks for both, so
	# below the panel's height cap this subtraction takes nothing the grid needed, and above the cap the
	# band gives way, because the grid is the tab's subject and the summary is a footnote on it.
	#
	# It uses `maxi(1, ...)` rather than the slot count, so an empty pack reserves the one row `_pack_rows`
	# charged the panel for and the band lands where the height was bought. An empty pack with a running
	# factory is a real state: it is what standing at the counter having just fed everything in looks like,
	# and it is the state `_detail_pack` exists for.
	var rows: int = maxi(1, (slots.size() + cols - 1) / cols)
	var band: float = clampf(content.size.y - float(rows) * cell, 0.0, _ledger_h())
	var wells := Rect2(content.position, Vector2(content.size.x, content.size.y - band))
	if slots.is_empty():
		_canvas.draw_string(_font, content.position + Vector2(2.0, 20.0), "(empty — go dig)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.UI_TEXT_DIM)
		_pack_ledger(Rect2(wells.position.x, wells.end.y, content.size.x, band))
		return
	var held: int = _inv_selected.call() if _inv_selected.is_valid() else -1
	for i: int in slots.size():
		var box := Rect2(content.position.x + float(i % cols) * cell, content.position.y + float(i / cols) * cell,
			cell - 6.0, cell - 6.0)
		if box.end.y > wells.end.y:
			break
		_click_hits.append({"rect": box, "index": i})
		var item: StringName = slots[i]["item"]
		var hot: bool = box.has_point(Controls.pointer_viewport(_canvas))
		var picked: bool = i == bazaar_row
		if picked:
			_round_rect(box, 5.0, Color(0.176, 0.153, 0.098))
			_canvas.draw_rect(Rect2(box.position + Vector2(0.0, 3.0), Vector2(2.0, box.size.y - 6.0)), UiTheme.UI_ACCENT)
		else:
			_round_rect(box, 5.0, Color(1.0, 1.0, 1.0, 0.062 if hot else 0.030))
		if hot:
			_tooltip_item = item
			_tooltip_count = int(slots[i]["count"])
			_tooltip_anchor = Vector2(box.get_center().x, box.position.y)
		_draw_thing_icon(item, Rect2(box.position + Vector2(8.0, 5.0),
			Vector2(box.size.x - 16.0, box.size.y - 17.0)))
		_canvas.draw_string(_font, box.position + Vector2(box.size.x - 13.0, box.size.y - 4.0),
			str(int(slots[i]["count"])), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiTheme.UI_TEXT)
		# The thing actually in your hand wears a mark, because "what am I holding" is the question the pack
		# screen is opened to answer, and the hotbar is behind the panel while it is open.
		#
		# It is a state rather than the cursor, which is why it is no longer in the cursor's colour. The
		# held well is usually not the picked well, so the grid was carrying two golds a row apart saying
		# two different things, the doubling the gold rule exists to stop. `_state_plate` has always drawn
		# this exact word in `UiTheme.STATE_INK` a couple of hundred pixels to the right, and green is already
		# this file's colour for a fact that is true of you rather than an offer: the researched tech's
		# name, the finished lamp. One word, one colour, on one screen. The well's wash goes from 12.22:1
		# to 7.20:1 and the picked row's brass from 10.29:1 to 6.06:1, both clear of the 4.5 floor.
		if i == held:
			_canvas.draw_string(_font, box.position + Vector2(5.0, 12.0), "HELD",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 7, UiTheme.STATE_INK)
	_pack_ledger(Rect2(wells.position.x, wells.end.y, content.size.x, band))


## Under the grid: what the factory is making for you, and what the rest of the line does with it.
##
## The bar is not a magnitude. Drawn as a share of the fastest number on the panel, a trickle of a
## refined good and a flood of a common raw look like the same kind of fact at two lengths, and the
## length moves when an unrelated row moves. It is the share of that item's own income the line is
## taking back, a 0..1 quantity meaning the same thing on every row. The /min number beside it keeps the
## magnitude. Rows split into two kinds out of the data rather than out of a rule: an item the line
## consumes gets a bar and a clause naming what eats it, and anything unattributable gets neither.
##
## The verdict on the header's line is the decision the rows only imply. It is chosen over the items the
## line actually consumes, so it is always about a live flow rather than the earth and stone a
## hand-mining player's rate list is full of. A deficit outranks a surplus. A step drawing more than its
## feed earns will stall, and a pile that is growing can wait.
func _pack_ledger(band: Rect2) -> void:
	var rates: Array[Dictionary] = _sim.production_rates()
	if rates.is_empty() or band.size.y <= 0.0:
		return
	var off: Dictionary = _line_offtake()
	var taken: Dictionary = off["draw"]
	var eater: Dictionary = off["eater"]
	var mute: Dictionary = off["mute"]
	var hb: float = band.position.y + LEDGER_GAP
	var head: String = "YOUR LINE IS MAKING"
	# A heading is a label, and gold does not label. See `GOLD_DIM`, where the type-weight argument that
	# put this in gold is taken apart. `UiTheme.UI_TEXT_DIM` is the grey ramp's subordinate rung and reads brighter
	# here than the gold rung did (6.15:1 against 5.40), while staying a step under the `UiTheme.UI_TEXT` verdict
	# printed beside it, which is the order the two lines are supposed to be read in.
	_tracked(head, Vector2(band.position.x + 1.0, hb), 8, 2.0, UiTheme.UI_TEXT_DIM)
	var vx: float = band.position.x + 1.0 + _tracked_w(head, 8, 2.0) + 12.0
	var verdict: String = _ledger_verdict(rates, off)
	if verdict != "" and band.end.x > vx:
		_canvas.draw_string(_font, Vector2(vx, hb), verdict, HORIZONTAL_ALIGNMENT_RIGHT, band.end.x - vx, 9,
			UiTheme.UI_TEXT)
	# The columns are the glyph, the name, the rate right-aligned against the bar's left edge, the bar and
	# the clause. The bar is 120 rather than the old `min(240, width/2)`, because a share does not need
	# half the panel to be read and the clause beside it does need the room: 246px of the 528.
	var bar_x: float = band.position.x + 154.0
	var bar_w: float = 120.0
	for i: int in mini(LEDGER_MAX, rates.size()):
		var y: float = hb + LEDGER_HEAD + float(i) * LEDGER_ROW
		if y + LEDGER_TAIL > band.end.y:
			return
		var item: StringName = rates[i]["item"]
		var rate: float = float(rates[i]["rate"])
		Visuals.draw_item(_canvas, Vector2(band.position.x + 8.0, y + 3.0), 13.0, item)
		_canvas.draw_string(_font, Vector2(band.position.x + 18.0, y + 7.0), _item_label(item),
			HORIZONTAL_ALIGNMENT_LEFT, 80.0, 9, UiTheme.UI_TEXT)
		_canvas.draw_string(_font, Vector2(band.position.x + 100.0, y + 7.0), "%.1f/min" % rate,
			HORIZONTAL_ALIGNMENT_RIGHT, 46.0, 9, UiTheme.UI_TEXT)
		var took: float = float(taken.get(item, 0.0))
		if mute.has(item) or took <= 0.0 or rate <= 0.0:
			continue
		_round_rect(Rect2(bar_x, y - 3.0, bar_w, 10.0), 3.0, Color(1.0, 1.0, 1.0, 0.035))
		# The item's own colour rather than the panel's gold. The dashboard's throughput bars already read
		# this way, and gold on this screen means selected, affordable and the live verb, which is not what a
		# share of an income is.
		_round_rect(Rect2(bar_x, y - 3.0, maxf(3.0, bar_w * clampf(took / rate, 0.0, 1.0)), 10.0), 3.0,
			Color(Visuals.item_color(item), 0.62))
		var who: String = str(eater.get(item, ""))
		var clause: String = "%.1f/min back into the line" % took
		if who != "":
			clause = "%.1f/min to the %s" % [took, who]
		_canvas.draw_string(_font, Vector2(bar_x + bar_w + 8.0, y + 7.0), clause,
			HORIZONTAL_ALIGNMENT_LEFT, band.end.x - bar_x - bar_w - 8.0, 9, UiTheme.UI_TEXT_DIM)


func _ledger_h() -> float:
	if _sim == null:
		return 0.0
	var n: int = mini(LEDGER_MAX, _sim.production_rates().size())
	if n <= 0:
		return 0.0
	return LEDGER_GAP + LEDGER_HEAD + float(n - 1) * LEDGER_ROW + LEDGER_TAIL


## The one line of the summary that asks for a decision instead of reporting a number. It is empty when
## the offtake has nothing it can speak about, which is the same silence the rows keep in that state.
func _ledger_verdict(rates: Array[Dictionary], off: Dictionary) -> String:
	var taken: Dictionary = off["draw"]
	var mute: Dictionary = off["mute"]
	# Empty because nothing refines anything, and empty because everything that does is unattributable, are
	# two different states, and only the first is a fact about the factory. Measured: place a Forge and a
	# Blast Furnace together and the offtake goes to {} with ore and rich_ore muted, which reads as
	# "nothing on the line refines any of it yet" while two machines are refining it.
	if taken.is_empty():
		return "" if not mute.is_empty() else "nothing on the line refines any of it yet"
	var by_item: Dictionary = {}
	for r: Dictionary in rates:
		by_item[r["item"]] = float(r["rate"])
	var pick: StringName = &""
	var spare: float = 0.0
	for item: StringName in taken:
		if mute.has(item):
			continue
		var s: float = float(by_item.get(item, 0.0)) - float(taken[item])
		# A deficit wins outright, and between two of the same sign the larger one wins.
		var better: bool = (s < 0.0 and spare >= 0.0) \
			or (spare < 0.0 and s < spare) \
			or (spare >= 0.0 and s > spare)
		if pick == &"" or better:
			pick = item
			spare = s
	if pick == &"":
		return ""
	var label: String = _item_label(pick).to_lower()
	var who: String = str((off["eater"] as Dictionary).get(pick, ""))
	if who == "":
		who = "line"
	if spare < 0.0:
		return "the %s outruns your %s by %.1f/min" % [who, label, -spare]
	return "%.1f %s/min spare past the %s" % [spare, label, who]


## What the line takes back. Per input item, how many of it a minute the placed recipe machines are
## consuming, derived from the measured output rates and nothing else. A forge measured at 2.2 ingot/min
## has, by smelt_ingot's 2 ore for 1 ingot, consumed exactly 4.4 ore/min. The ratio is the recipe's and
## the rate is the _sim's, so there is no capacity model here and nothing to calibrate.
##
## It returns {"draw": item -> per minute, "eater": item -> the machine's display name, or "" when more
## than one type is eating it, "mute": item -> true for the ones this cannot speak about}.
##
## The mute set is the point. Two placed machine types can output the same good. A measured ingot rate
## cannot be split between a Forge turning 2 ore into 1 and a Blast Furnace turning 1 rich_ore into 2.
## Attributing the whole rate to either invents the other's throughput, so every input of every
## candidate recipe goes mute instead. That is a different state from an item nothing consumes, which
## reports a real zero.
##
## Machines running their own tick carry no recipe inputs to add up here. A drill's mine_ore has none,
## and the descent engine eats ingots through DESCENT_EATS with no recipe at all. So the clause says "to
## the Forge" rather than "consumed", which is true whatever else is also eating.
func _line_offtake() -> Dictionary:
	var makers: Dictionary = {}                       # output item -> [{recipe, name}, ...]
	for row: Dictionary in _sim.machine_census():
		var rec: RecipeDef = (row["def"] as MachineDef).recipe
		if rec == null or rec.inputs.is_empty():
			continue
		for out: StringName in rec.outputs:
			if not makers.has(out):
				makers[out] = []
			(makers[out] as Array).append({"recipe": rec, "name": str(row["name"])})
	var taken: Dictionary = {}
	var eater: Dictionary = {}
	var mute: Dictionary = {}
	for r: Dictionary in _sim.production_rates():
		var out: StringName = r["item"]
		var mk: Array = makers.get(out, [])
		if mk.is_empty():
			continue
		if mk.size() > 1:
			for m: Dictionary in mk:
				for item: StringName in (m["recipe"] as RecipeDef).inputs:
					mute[item] = true
			continue
		var rec: RecipeDef = mk[0]["recipe"]
		var per: float = float(int(rec.outputs[out]))
		if per <= 0.0:
			continue
		var who: String = str(mk[0]["name"])
		for item: StringName in rec.inputs:
			taken[item] = float(taken.get(item, 0.0)) \
				+ float(r["rate"]) * float(int(rec.inputs[item])) / per
			# Two machine types can share one ingredient, since the Gear Mill and the Plate Press both eat iron
			# ingots, and the total stays right while the name stops being. Naming neither beats naming whichever
			# the census happened to yield last.
			eater[item] = who if not eater.has(item) or str(eater[item]) == who else ""
	return {"draw": taken, "eater": eater, "mute": mute}