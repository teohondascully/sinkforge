class_name DropLessons
extends RefCounted

## THE DROP'S OUTCOMES ON THE HUD (out of `Hints` in D0517, for the size gate; `Hints` owns the plate and
## the queue and applies what this decides). `o.drop_went` is `fed`, `floor` or `short` (D0513): `short` is
## a drop REFUSED for a machine in sight that takes the stack but is out of reach, the pack unchanged,
## `drop_short_cell` that machine's cell; `floor` means NO machine in sight takes it; `fed` as before.
##
## THE WRONG STACK (D0443, stranger 16). Q drops the SELECTED stack; the sixteenth stranger, holding clay
## from the pit they had dug, pressed Q beside the forge a dozen times, read DROPPED each time ("stand
## BESIDE it"), stepped closer and dropped clay again. When a floor drop's item is one no machine within
## the drop's own far range takes, and the pack holds one such a machine does, the lesson names both.
##
## THE SHORT LESSON AND THE RECEIPT (D0517, strangers 103-108). S104 fed the forge six coal while NO
## MACHINE HERE still held the plate from a floor drop eighteen seconds before; S107 and S108 first
## hesitated over "whether anything happened"; S106 dropped six times beside the rig, the forge nineteen
## cells off, and read NO MACHINE HERE each time. So the short drop has a lesson that points (the eater's
## word, the metres, the way), a fed drop puts a RECEIPT on the slot ("6 COAL → FORGE", in the plate's own
## ink), and the plate lets go of any drop lesson the tick a drop feeds: a receipt and a refusal never show
## together.

const WANTED_RANGE_M: float = float(Reach.NAMED_M)   ## the one range, in core (D0559), not a copy of it
const LESSONS: Array[StringName] = [&"dropped_floor", &"dropped_wrong", &"dropped_short"]

var _prev_counts: Dictionary = {}
## THE MACHINE THE STANDING "TOO FAR" LESSON NAMED, kept so its metres can be recomputed while the lesson
## is up (D0558). `o.drop_short_cell` is one observe wide and then a window of ticks (D0434), and the
## lesson outlives both.
var _short_cell: Vector2i = Vector2i(-1, -1)


## One observe: the pack's fall, then which drop lesson is TRUE, what the slot says, and the receipt.
## Returns `{"wrong": bool, "short": bool, "slot": StringName, "receipt": String}` -- `slot` is the drop
## lesson whose headline the slot repeats (`&""` for no drop), `receipt` the fed drop's words ("" for
## none). Fills `subs` (lesson id -> {placeholder: text}) for the lessons that fire.
func read(o: Interface.Observation, counts: Dictionary, subs: Dictionary) -> Dictionary:
	var fell: Dictionary = _pack_fell(counts)
	var wrong: bool = _wrong_stack(o, counts, fell, subs)
	var short: bool = _short_drop(o, subs)
	var slot: StringName = &""
	if short:
		slot = &"dropped_short"
	elif o.drop_went == &"floor":
		slot = &"dropped_wrong" if wrong else &"dropped_floor"
	return {"wrong": wrong, "short": short, "slot": slot, "receipt": _receipt(o, fell)}


## The pack's fall this observe: `{item, n}` for the item whose count fell (the last such, in pack order),
## `{}` for none. The `_prev_counts` edge every drop detector reads.
func _pack_fell(counts: Dictionary) -> Dictionary:
	var fell: Dictionary = {}
	for item: StringName in _prev_counts:
		var n: int = int(_prev_counts[item]) - int(counts.get(item, 0))
		if n > 0:
			fell = {"item": item, "n": n}
	_prev_counts = counts
	return fell


## A floor drop of an item no machine in range takes, while the pack holds one a machine does: the dropped
## item is the one whose count fell this frame; the wanted one is the first recipe input a machine within
## WANTED_RANGE_M asks for that the pack still holds. Fills the lesson's placeholders.
func _wrong_stack(o: Interface.Observation, counts: Dictionary, fell: Dictionary, subs: Dictionary) -> bool:
	if o.drop_went != &"floor" or fell.is_empty():
		return false
	var dropped: StringName = fell["item"]
	var body: Vector2 = body_px(o)
	var wanted: StringName = &""
	for rec: Dictionary in o.machines:
		if cell_px(rec["cell"]).distance_to(body) > WANTED_RANGE_M * float(Interface.Observation.LOGIC_PX):
			continue
		var inputs: Dictionary = RecipesRecords.RECORDS.get(String(rec.get("recipe", &"")), {}).get("inputs", {})
		for need: Variant in inputs:
			var item := StringName(String(need))
			if item == dropped:
				return false                         # the machine takes what fell: that is the BESIDE lesson's case
			if wanted == &"" and int(counts.get(item, 0)) > 0:
				wanted = item
	if wanted == &"":
		return false
	subs[&"dropped_wrong"] = {"{dropped}": Hotbar.item_label(dropped).to_lower(), "{wanted}": Hotbar.item_label(wanted).to_lower()}
	return true


## A drop REFUSED for a machine in sight but out of reach (D0517): TOO FAR's placeholders are the eater's
## word at `drop_short_cell`, the selected stack's item, the whole metres from the body to that cell, and
## the way to it -- LEFT/RIGHT, or ABOVE/BELOW when the rise outweighs the run.
func _short_drop(o: Interface.Observation, subs: Dictionary) -> bool:
	if o.drop_went != &"short":
		return false
	_short_cell = o.drop_short_cell
	subs[&"dropped_short"] = _short_subs(o, o.drop_short_cell, Hotbar.item_label(o.held_item).to_lower())
	return true


## THE LESSON'S METRES, RECOMPUTED FROM WHERE THE BODY IS NOW (D0558). S131 walked while "TOO FAR -- the
## FORGE that takes ore is 8 m to your LEFT" stood on the dock and reported that "the message did not
## update as it walked". It did not: `{dist}` was substituted once, at the drop. `Hints.active_text`
## re-substitutes on every call, so the number only had to be kept fresh -- and a distance that is wrong
## the instant you obey it is worse than no distance, because the player obeys it and then distrusts the
## next one. Returns false once the body is INSIDE the drop's own reach, which is the moment the lesson
## has nothing left to say: `Hints` lets go of it there, and that letting-go is the "close enough" signal
## three strangers said was missing (D0557 draws the same line on the ground).
func refresh_short(o: Interface.Observation, subs: Dictionary) -> bool:
	if _short_cell == Vector2i(-1, -1):
		return false
	if Reach.in_reach_metre(o.pos_x, o.pos_y, _short_cell, Interface.Observation.LOGIC_PX):
		_short_cell = Vector2i(-1, -1)
		return false
	var held: Dictionary = subs.get(&"dropped_short", {})
	subs[&"dropped_short"] = _short_subs(o, _short_cell, String(held.get("{item}", "that stack")))
	return true


## The placeholders for one reading of the lesson, from the body's CURRENT position. `{item}` is carried
## in by the caller rather than read off `o.held_item`: the hand may have moved to another stack since
## the drop, and the lesson is about the stack that was refused.
func _short_subs(o: Interface.Observation, cell: Vector2i, item: String) -> Dictionary:
	var d: Vector2 = cell_px(cell) - body_px(o)
	# THE DIRECTION CARRIES ITS OWN PREPOSITION (D0558). The sentence used to read "is 4 m to your
	# ABOVE", which is not English, and this lesson is the one a stranger reads while standing still
	# and refused. `EDGE_TEXT` keeps its own "to your {dir}" and is always given LEFT or RIGHT.
	var way: String = ("BELOW you" if d.y > 0.0 else "ABOVE you") if absf(d.y) > absf(d.x) else ("to your RIGHT" if d.x > 0.0 else "to your LEFT")
	return {"{eater}": eater_label(o.machine_at(cell)), "{item}": item,
		"{dist}": str(roundi(d.length() / float(Interface.Observation.LOGIC_PX))), "{dir}": way}


## The receipt for a drop that FED a machine (D0517): "6 COAL → FORGE" -- the pack's fall in that item and
## the nearest machine in the window that takes it, "MACHINE" if none resolves. "" for any other drop, and
## for a fed drop with no fall in the pack (a pickup of the same item in the same tick).
func _receipt(o: Interface.Observation, fell: Dictionary) -> String:
	if o.drop_went != &"fed" or fell.is_empty():
		return ""
	var item: StringName = fell["item"]
	var body: Vector2 = body_px(o)
	var eater: Dictionary = {}
	var best: float = INF
	for rec: Dictionary in o.machines:
		var gap: float = cell_px(rec["cell"]).distance_to(body)
		if gap < best and takes(rec).has(item):
			best = gap
			eater = rec
	return "%d %s → %s" % [int(fell["n"]), Hotbar.item_label(item).to_upper(), eater_label(eater)]


## What a machine takes: its recipe's inputs, and the rig's current demand (`wants`, on the record so the
## view reads no ladder).
static func takes(rec: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var inputs: Dictionary = (RecipesRecords.RECORDS.get(String(rec.get("recipe", &"")), {}) as Dictionary).get("inputs", {})
	for need: Variant in inputs.keys() + (rec.get("wants", {}) as Dictionary).keys():
		out.append(StringName(String(need)))
	return out


## THE RECEIPT USES THE RING'S WORD (D0525, W3's flag in D0517): the ring under the rig says RIG and the
## receipt over it said CREW RIG, two words for one machine in one glance. `RingWord.word` is keyed by the
## rung and what the ring stands on, so this is that table read the other way, by the machine's record id,
## for the machines a ring stands on; `tests/test_hints_moments.gd` pins each word against `RingWord.word`
## so the two cannot drift. A machine with no ring word keeps its record's name.
const RING_WORDS: Dictionary = {&"processor": "FORGE", &"rig": "RIG", &"drill": "DRILL", &"hopper": "HOPPER",
	&"generator": "GENERATOR", &"winch_head": "WINCH HEAD"}


## A machine's word on the plate: the ring's word for it when the ring has one (RIG, FORGE...), else its
## record's name in caps, the inspector's own path; "MACHINE" for a record that resolves nothing.
static func eater_label(rec: Dictionary) -> String:
	if rec.is_empty():
		return "MACHINE"
	var id := StringName(String(rec.get("id", "")))
	if RING_WORDS.has(id):
		return RING_WORDS[id]
	return String(rec.get("name", String(rec.get("id", "machine")).replace("_", " "))).to_upper()


## The body's centre and a logic cell's centre, in world px.
static func body_px(o: Interface.Observation) -> Vector2:
	return Vector2(float(o.pos_x), float(o.pos_y)) / float(Fx.SCALE)


static func cell_px(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(Interface.Observation.LOGIC_PX)
