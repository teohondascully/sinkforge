class_name Inspector
extends RefCounted

## THE INSPECTOR (A' step 6h, D0369): the readout top-right for whatever the aim is over and in reach.
## Legacy `scenes/hover_info.gd` (`describe`, the content) and `hud.gd`'s `_draw_hover` (the panel),
## MERGED as the plan's row says: the mechanism lifts whole, every content line is re-authored against
## the machines that exist here, because legacy's taught the Descent Engine, the splitter, the horizontal
## drill and the seal. `describe()` reads the OBSERVATION and nothing else -- legacy's three pieces of
## controller context (reach, the drill rate, the body's footing) are the observation's `aim_in_reach`,
## the economy's own rate list, and nothing (the footing refusal is a verb's answer, shell work).
##
## `layout()` decides and `paint()` transcribes (D0290); every number is legacy's authoring-canvas
## number through `UiTheme.px`/`pt`. The panel takes the width of its widest line between a floor and a
## cap, and anything past the cap is ellipsized rather than lost off the right edge -- legacy's most
## important sentence once came out cut in half.
##
## STANDS DOWN UNDER THE ARRIVAL PLATE: `HELPER_TAGS` ranks the plate critical and this panel active,
## and legacy measured the two printing over each other by 21x32 px. The predicate is VISIBILITY, not
## the plate's lifetime -- a plate held behind a live rope draws nothing while it stays live. Legacy's
## clickable knobs (the hopper's [clear filter]) are not drawn: a click is a verb and verbs are shell
## work; the filter is stated instead.

const PAD: float = 9.0
const LINE_H: float = 18.0
const MIN_W: float = 218.0
const MAX_W: float = 300.0
const NAME_SIZE: int = 13
const LINE_SIZE: int = 11
const ARROW_SIZE: int = 12
const TOP: float = 34.0 + 10.0          ## under the ambient corner register (FORGED's slot)
const NAME_INK := Color(0.95, 0.92, 0.80)
const MODE_INK := Color(0.66, 0.80, 0.90)
const RATE_INK := Color(0.85, 0.72, 0.42)
const HOLD_INK := Color(0.62, 0.66, 0.74)
const CHIP_INK := Color(0.92, 0.93, 0.96)
const ARROW_INK := Color(0.70, 0.74, 0.82)

## A stalled status in words, for the states the mode line does not already narrate. Re-authored from
## legacy's `ALERT_REASON` for the statuses `MachineStatus` produces.
const STATUS_LINE: Dictionary = {
	&"blocked": "output blocked — dig a drain",
	&"no_fuel": "out of coal — feed it",
	&"no_input": "starved — nothing feeding it",
	&"no_power": "no power — it eats a network, not a coal box",
	&"spent": "the vein is worked out — pick it up and move it",
}

var _plate: ArrivalPlate = null


func _init(plate: ArrivalPlate = null) -> void:
	_plate = plate


static func _cap(id: StringName) -> String:
	return String(id).replace("_", " ").capitalize()


static func _chips_of(counts: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: StringName in Ordering.ids(counts.keys()):
		out.append({"item": item, "count": int(counts[item])})
	return out


static func _sum(counts: Dictionary) -> int:
	var n: int = 0
	for v: Variant in counts.values():
		n += int(v)
	return n


## The content: `{}` when there is nothing to say -- out of reach, or a bare cell with no hint.
static func describe(o: Interface.Observation) -> Dictionary:
	if o == null or not o.aim_in_reach or o.aim_cell == Vector2i(-1, -1):
		return {}
	var aim: Vector2i = o.aim_cell
	var n: int = Interface.Observation.LOGIC_PX / Interface.Observation.CELL_PX
	var logic := Vector2i(floori(float(aim.x) / float(n)), floori(float(aim.y) / float(n)))
	var rec: Dictionary = o.machine_at(logic)
	if rec.is_empty():
		return _describe_terrain(o, aim, logic)
	var info: Dictionary = {"name": String(rec.get("name", _cap(rec["id"])))}
	var recipe: Dictionary = RecipesRecords.RECORDS.get(String(rec.get("recipe", &"")), {})
	info["in"] = _chips_of(recipe.get("inputs", {}))
	info["out"] = _chips_of(recipe.get("outputs", {}))
	var status: StringName = rec.get("status", &"idle")
	var input: Dictionary = rec.get("input", {})
	var coal: int = int(input.get(&"coal", 0))
	var fueled: bool = int(rec.get("fuel", 0)) > 0 or coal > 0
	match rec.get("behavior", &""):
		&"drill":
			match status:
				&"no_input": info["mode"] = "idle — no ore below it (stand it over a vein)"
				&"no_fuel": info["mode"] = "OUT OF COAL — drop coal on it to run"
				&"spent": info["mode"] = "the vein below is worked out"
				&"blocked": info["mode"] = "belly FULL — dig a drain below it, or pick it up"
				_: info["mode"] = "boring the vein below  ·  coal %d" % coal
		&"generator":
			info["mode"] = "burns coal → POWER" + ("  (running)" if fueled else "  (out of fuel)")
		&"hopper":
			var stock: int = _sum(input)
			var filter: StringName = rec.get("filter", &"")
			if filter == &"":
				info["mode"] = "stockpiles %d — keeps the FIRST thing it tastes, passes the rest" % stock
			elif status == &"blocked":
				info["mode"] = "banks %s (%d) — BACKED UP, the machine below is full" % [_cap(filter), stock]
			else:
				info["mode"] = "banks %s (%d) — passes everything else" % [_cap(filter), stock]
		&"lift":
			info["mode"] = "lifts goods + you UP" + ("  (POWERED)" if int(rec.get("power_permille", 0)) > 50 else "  (unpowered baseline)")
		&"pump":
			info["mode"] = "drains the water under it" + ("" if status == &"working" else "  (nothing to drain)")
		&"torch": info["mode"] = "light — the dark reads by it"
		&"rope": info["mode"] = "a hung line — climb it"
		&"conduit": info["mode"] = "carries power along the line"
		&"winch_head":
			match status:
				&"spent": info["mode"] = "the vein is worked out — pick it up and move it"
				&"blocked": info["mode"] = "the Station is full — collect from it"
				&"no_input": info["mode"] = "nothing to bore — stand it on a vein"
				_: info["mode"] = "bores the vein it stands on → the Station"
		&"winch_station":
			info["mode"] = "the Winch's drain — collect from it  (%d held)" % _sum(rec.get("output", {}))
		_:
			if recipe.is_empty():
				info["mode"] = ""
			elif (recipe.get("inputs", {}) as Dictionary).is_empty():
				info["mode"] = "ore source"
			else:
				var outs: Array = (recipe.get("outputs", {}) as Dictionary).keys()
				info["mode"] = "makes %s  (%.1fs a cycle)" % [_cap(StringName(outs[0])) if not outs.is_empty() else "?",
					float(recipe.get("time_ticks", 0)) / float(Interface.Observation.TICK_HZ)]
	var mode_has_it: bool = rec.get("behavior", &"") in [&"drill", &"hopper", &"winch_head"] and status != &"no_power"
	info["status"] = "" if mode_has_it else String(STATUS_LINE.get(status, ""))
	var hold: Dictionary = {}
	for buf: Dictionary in [input, rec.get("output", {})]:
		for it: Variant in buf:
			hold[StringName(it)] = int(hold.get(StringName(it), 0)) + int(buf[it])
	info["holding"] = _chips_of(hold)
	var outs2: Array = (recipe.get("outputs", {}) as Dictionary).keys()
	if not outs2.is_empty():
		var item := StringName(outs2[0])
		for r: Dictionary in o.rates:
			if r.get("item", &"") == item and int(r.get("rate_centi", 0)) > 5:
				info["rate"] = "factory makes %.1f %s/min" % [float(r["rate_centi"]) / 100.0, String(item)]
	return info


static func _describe_terrain(o: Interface.Observation, aim: Vector2i, logic: Vector2i) -> Dictionary:
	var vein: StringName = o.lode_at(aim)
	if vein != &"" and not o.solid_at(aim):
		return {"name": "%s Lode" % _cap(vein), "mode": "%d left — work the face by hand, %d%% of the next unit off it" % [o.deposit_at(aim), o.lode_permille(aim) / 10]}
	if o.solid_at(aim) and o.deposit_at(aim) > 0:
		return {"name": "Ore Vein", "mode": "%d ore — stand a Drill just above it" % o.deposit_at(aim)}
	if o.is_climbable(logic):
		return {"name": "Rope", "mode": "a hung line — climb it"}
	if o.has_torch(logic):
		return {"name": "Torch", "mode": "light — the dark reads by it"}
	if o.has_conduit(logic):
		return {"name": "Power Conduit", "mode": "carries power along the line"}
	var w: int = o.water_at(aim)
	if w > 0:
		return {"name": "Water", "mode": "%d of %d — it pours wherever the floor below is open" % [w, Interface.Observation.WATER_MAX]}
	return {}


## Ellipsize `text` to `max_w` px at `size`, legacy's `_fit_text`.
static func fit_text(font: Font, text: String, size: int, max_w: float) -> String:
	if text == "" or max_w <= 0.0 or font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
		return text
	var cut: String = text
	while cut.length() > 1:
		cut = cut.substr(0, cut.length() - 1)
		if font.get_string_size(cut + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= max_w:
			return cut.strip_edges(false, true) + "…"
	return "…"


## Everything the panel decides. `plate_shown` is the stand-down.
static func layout(frame: Frame, font: Font, plate_shown: bool = false) -> Dictionary:
	if frame == null or frame.obs == null or font == null or plate_shown:
		return {}
	var info: Dictionary = describe(frame.obs)
	if info.is_empty():
		return {}
	var ins: Array = info.get("in", [])
	var outs: Array = info.get("out", [])
	var holding: Array = info.get("holding", [])
	var lines: Array[Dictionary] = []   # {text, ink} in order below the name
	var widest: float = font.get_string_size(info["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(NAME_SIZE)).x
	for spec: Array in [["mode", MODE_INK], ["status", UiTheme.UI_WARN], ["rate", RATE_INK]]:
		var text: String = String(info.get(spec[0], ""))
		if text != "":
			widest = maxf(widest, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(LINE_SIZE)).x)
			lines.append({"key": spec[0], "text": text, "ink": spec[1]})
	var pad: float = UiTheme.px(PAD)
	var width: float = clampf(widest + pad * 2.0, UiTheme.px(MIN_W), UiTheme.px(MAX_W))
	var name: String = fit_text(font, info["name"], UiTheme.pt(NAME_SIZE), width - pad * 2.0)
	for l: Dictionary in lines:
		l["text"] = fit_text(font, l["text"], UiTheme.pt(LINE_SIZE), width - pad * 2.0)
	var has_recipe: bool = not ins.is_empty() or not outs.is_empty()
	var rows: int = 1 + int(has_recipe) + lines.size() + int(not holding.is_empty())
	var origin := Vector2(UiTheme.CANVAS.x - width - UiTheme.px(12.0), UiTheme.px(TOP))
	var rect := Rect2(origin, Vector2(width, UiTheme.px(10.0) + float(rows) * UiTheme.px(LINE_H) + UiTheme.px(4.0)))
	return {"rect": rect, "name": name, "x0": origin.x + pad, "y0": origin.y + UiTheme.px(20.0),
		"line_h": UiTheme.px(LINE_H), "in": ins, "out": outs, "has_recipe": has_recipe, "lines": lines,
		"holding": holding, "rows": rows}


func paint(frame: Frame, ci: CanvasItem) -> void:
	var font: Font = ThemeDB.fallback_font
	var l: Dictionary = layout(frame, font, _plate != null and _plate.on_screen(frame))
	if l.is_empty():
		return
	UiTheme.panel(ci, l["rect"])
	var x0: float = l["x0"]
	var y: float = l["y0"]
	ci.draw_string(font, Vector2(x0, y), l["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(NAME_SIZE), NAME_INK)
	y += l["line_h"]
	if bool(l["has_recipe"]):
		var x: float = _chips(ci, font, x0, y, l["in"])
		ci.draw_string(font, Vector2(x, y), "->", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(ARROW_SIZE), ARROW_INK)
		x += font.get_string_size("->", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(ARROW_SIZE)).x + UiTheme.px(8.0)
		_chips(ci, font, x, y, l["out"])
		y += l["line_h"]
	for line: Dictionary in l["lines"]:
		ci.draw_string(font, Vector2(x0, y), line["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(LINE_SIZE), line["ink"])
		y += l["line_h"]
	if not (l["holding"] as Array).is_empty():
		ci.draw_string(font, Vector2(x0, y), "holds", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(LINE_SIZE), HOLD_INK)
		var hx: float = x0 + font.get_string_size("holds", HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(LINE_SIZE)).x + UiTheme.px(8.0)
		_chips(ci, font, hx, y, l["holding"])


## A run of item chips (a colour swatch + count) left to right; returns the x just past them.
static func _chips(ci: CanvasItem, font: Font, x0: float, y: float, items: Array) -> float:
	var x: float = x0
	for entry: Dictionary in items:
		var sw := Rect2(x, y - UiTheme.px(11.0), UiTheme.px(12.0), UiTheme.px(12.0))
		ci.draw_rect(sw, ItemLook.color(entry["item"]))
		ci.draw_rect(sw, Color(0.0, 0.0, 0.0, 0.4), false, 1.0)
		var label: String = " %d" % int(entry["count"])
		ci.draw_string(font, Vector2(x + UiTheme.px(14.0), y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(LINE_SIZE), CHIP_INK)
		x += UiTheme.px(14.0) + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.pt(LINE_SIZE)).x + UiTheme.px(8.0)
	return x
