class_name MarkLayout
extends RefCounted

## WHAT THE MARKS SAY THIS FRAME, as data (A' step 6m, D0376). Legacy's `_draw_aim`, `_draw_dig_marks`,
## `_draw_interact_pulse`, `_cell_refusal`, the drill and rope previews, `_draw_feed_target` and
## `_draw_placement_hint`, each returning the marks it would draw instead of drawing them, so
## `tests/test_mark_painter.gd` can fail on "the wrong shape for this situation" -- the half of a cursor
## that can be wrong while the screen still shows something plausible. `MarkPainter.draw_mark` transcribes.
##
## Every rule reads the observation's affordances (`AimPlanes`), never the sim: reach, placeability, the
## feed mouth and the previews were decided by the verbs' own predicates at the door.

const NONE: Vector2i = Vector2i(-1, -1)


static func build(o: Interface.Observation, t: float, look: MaterialLook) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if o == null:
		return out
	_dig(o, t, out)
	_aim(o, t, look, out)
	_feed(o, t, out)
	_hint(o, t, out)
	return out


## The painted dig plan: every marked cell wears a whisper of amber fill, and the plan's OUTLINE breathes
## in a thin stroke. Legacy put corners on each of its metre cells; a corner on a 4 px cell is a dot, so
## the region's boundary edges carry the stroke instead -- the same "later, not now" weight, one shape.
static func _dig(o: Interface.Observation, t: float, out: Array[Dictionary]) -> void:
	if o.dig_marks.is_empty():
		return
	var cell_px: float = float(o.cell_px)
	var pulse: float = 0.65 + 0.35 * sin(t * 2.6)
	var edge := Color(MarkPainter.DIG.r, MarkPainter.DIG.g, MarkPainter.DIG.b, 0.30 + 0.25 * pulse)
	var fill := Color(MarkPainter.DIG.r, MarkPainter.DIG.g, MarkPainter.DIG.b, 0.05)
	var marked: Dictionary = {}
	for c: Vector2i in o.dig_marks:
		marked[c] = true
	for c: Vector2i in o.dig_marks:
		var r := Rect2(Vector2(c) * cell_px, Vector2(cell_px, cell_px))
		out.append({"kind": &"wash", "rect": r, "color": fill})
		for side: Array in [[Vector2i(0, -1), r.position, r.position + Vector2(r.size.x, 0.0)],
				[Vector2i(0, 1), r.position + Vector2(0.0, r.size.y), r.end],
				[Vector2i(-1, 0), r.position, r.position + Vector2(0.0, r.size.y)],
				[Vector2i(1, 0), r.position + Vector2(r.size.x, 0.0), r.end]]:
			if not marked.has(c + (side[0] as Vector2i)):
				out.append({"kind": &"line", "a": side[1], "b": side[2], "color": edge, "width": MarkPainter.THIN_W})


## The cursor, by context: rock wears the square (a vein adds corners in the ore's colour); a lode face
## pulses in its ore's colour; your machine pulses in its own colour; an open cell in reach takes the
## build ghost, barred when the press would not land.
static func _aim(o: Interface.Observation, t: float, look: MaterialLook, out: Array[Dictionary]) -> void:
	if o.aim_cell == NONE:
		return
	var rect: Rect2 = MarkPainter.mark_rect(MarkPainter.target_rect(o))
	# THE HELD BUTTON THAT DOES NOTHING SAYS SO (D0421): the refusal square and bar at full weight -- the
	# same grammar as standing in your own way. The first stranger to play held MINE on the right rock from
	# a step too far, three times, and the frame did not change: the square sat at 0.18 and read as nothing.
	# The mark says "not from here"; the WHY is the lesson dock's (`Hints` `too_far`), never text on the miner.
	if o.aim_refusal != &"":
		refusal(rect, 1.0, out)
		return
	if o.solid_at(o.aim_cell):
		var a: float = 0.85 if o.aim_in_reach else 0.18
		square(rect, Color(MarkPainter.CHROME.r, MarkPainter.CHROME.g, MarkPainter.CHROME.b, a), out)
		if o.aim_in_reach and o.deposit_at(o.aim_cell) > 0:
			pulse(rect, ore_color(o.material_at(o.aim_cell)), t, out)
		return
	if o.aim_is_lode:
		if o.aim_in_reach:
			pulse(MarkPainter.mark_rect(MarkPainter.logic_rect(MarkPainter.aim_logic(o))), ore_color(o.lode_at(o.aim_cell)), t, out)
		return
	if not o.aim_in_reach:
		return
	var m: Dictionary = o.machine_at(MarkPainter.aim_logic(o))
	if not m.is_empty():
		pulse(rect, MachineLook.color(m.get("behavior", &""), m.get("id", &""), bool(m.get("source", false))).lightened(0.25), t, out)
		return
	_ghost(o, look, rect, out)


## The build ghost under the cursor: a translucent preview lifted toward chrome ("a thing you are still
## deciding about; white belongs to things that have already happened"), its glyph, its previews, then
## the same cursor square as over rock when the press would land and the refusal when it would not.
static func _ghost(o: Interface.Observation, look: MaterialLook, rect: Rect2, out: Array[Dictionary]) -> void:
	var wash: Rect2 = MarkPainter.mark_wash(MarkPainter.target_rect(o))
	if MachinesRecords.RECORDS.has(o.held_item):
		var rec: Dictionary = MachinesRecords.RECORDS[o.held_item]
		var behavior := StringName(String(rec.get("behavior", "")))
		var source: bool = String(rec.get("recipe", "")) == "mine_ore" or o.held_item == &"iron_forge"
		var kind: String = MachineLook.kind(behavior, o.held_item, source)
		var ghost: Color = MachineLook.color(behavior, o.held_item, source).lerp(MarkPainter.CHROME, 0.20)
		out.append({"kind": &"wash", "rect": wash, "color": Color(ghost.r, ghost.g, ghost.b, 0.55)})
		var face: Rect2 = MarkPainter.logic_rect(MarkPainter.aim_logic(o))
		out.append({"kind": &"glyph", "centre": face.get_center(), "glyph": kind, "scale": MachinePainter.glyph_scale(face)})
		if o.aim_placeable:
			_previews(o, out)
	elif MaterialsRecords.RECORDS.has(o.held_item):
		var bg: Color = look.matrix_color(o.held_item, o.aim_cell.x, o.aim_cell.y) if look != null else MarkPainter.CHROME
		out.append({"kind": &"wash", "rect": wash, "color": Color(bg.r, bg.g, bg.b, 0.55)})
	else:
		return
	if o.aim_placeable:
		square(rect, Color(MarkPainter.CHROME.r, MarkPainter.CHROME.g, MarkPainter.CHROME.b, 0.95), out)
	else:
		refusal(rect, 0.95, out)


## What the held machine would do from here: the drill's column (each ore cell tinted, a dashed box
## around the run, the out-arrow where the ore pours; red-amber when the drop is blocked), the rope's
## unroll.
static func _previews(o: Interface.Observation, out: Array[Dictionary]) -> void:
	var dp: Dictionary = o.drill_preview
	if not dp.is_empty():
		var tint: Color = MarkPainter.WARN if bool(dp.get("blocked", false)) else MarkPainter.FLOW
		var cells: Array = dp.get("cells", [])
		for c: Variant in cells:
			out.append({"kind": &"wash", "rect": MarkPainter.logic_rect(c), "color": Color(tint.r, tint.g, tint.b, 0.22)})
		if not cells.is_empty():
			var top: Vector2i = cells[0]
			var bot: Vector2i = cells[cells.size() - 1]
			var box: Rect2 = MarkPainter.logic_rect(top).merge(MarkPainter.logic_rect(bot)).grow(-1.0 * MarkPainter.S)
			out.append({"kind": &"dash", "rect": box, "color": tint})
		var drop: Vector2i = dp.get("drop", NONE)
		if drop != NONE:
			out.append({"kind": &"arrow", "cell": drop, "color": tint})
	if o.rope_preview > 0:
		var l: Vector2i = MarkPainter.aim_logic(o)
		var x: float = float(l.x) * MarkPainter.CELL + MarkPainter.CELL * 0.5
		out.append({"kind": &"rope", "x": x, "top": float(l.y) * MarkPainter.CELL + 4.0 * MarkPainter.S,
			"bot": float(l.y + o.rope_preview) * MarkPainter.CELL - 2.0 * MarkPainter.S, "hung": o.rope_preview})


## Which mouth the drop will feed, shown before the key is pressed: the cell's own top LIP lit in the held
## item's colour ("gravity feeds the toss, so the opening it falls into is exactly the right thing to
## light"), never an arrow -- the shapes near a machine are spoken for.
static func _feed(o: Interface.Observation, t: float, out: Array[Dictionary]) -> void:
	if o.feed_target == NONE:
		return
	var col: Color = ItemLook.color(o.held_item)
	var pulse: float = 0.72 + 0.28 * sin(t * 3.0)
	var cell: Rect2 = MarkPainter.logic_rect(o.feed_target)
	out.append({"kind": &"wash", "rect": cell, "color": Color(col.r, col.g, col.b, 0.10 * pulse)})
	var lip_w: float = MarkPainter.CELL * 0.78
	var lip := Rect2(cell.position + Vector2((MarkPainter.CELL - lip_w) * 0.5, -1.5 * MarkPainter.S), Vector2(lip_w, 3.0 * MarkPainter.S))
	out.append({"kind": &"wash", "rect": lip.grow(1.5 * MarkPainter.S), "color": Color(col.r, col.g, col.b, 0.22 * pulse)})
	out.append({"kind": &"wash", "rect": lip, "color": Color(col.r, col.g, col.b, 0.55 + 0.35 * pulse), "lip": true})


## The nearest open cell, only while standing in your own way is the refusal: a plain outline breathing
## in alpha alone, in a colour neither the ghost nor a refusal uses.
static func _hint(o: Interface.Observation, t: float, out: Array[Dictionary]) -> void:
	if o.place_hint == NONE:
		return
	var pulse: float = 0.35 + 0.25 * sin(t * 2.5)
	out.append({"kind": &"square", "rect": MarkPainter.mark_rect(MarkPainter.logic_rect(o.place_hint)),
		"color": Color(MarkPainter.HINT.r, MarkPainter.HINT.g, MarkPainter.HINT.b, pulse), "width": MarkPainter.MARK_W, "hint": true})


static func square(rect: Rect2, col: Color, out: Array[Dictionary]) -> void:
	out.append({"kind": &"square", "rect": rect, "color": col, "width": MarkPainter.MARK_W})


## The breathing coloured outline plus solid corners in the thing's own colour: the next press lands here.
static func pulse(rect: Rect2, col: Color, t: float, out: Array[Dictionary]) -> void:
	var p: float = 0.5 + 0.5 * sin(t * 4.0)
	var r: Rect2 = rect.grow(MarkPainter.PULSE_GROW + p * MarkPainter.PULSE_BREATH)
	out.append({"kind": &"square", "rect": r, "color": Color(col.r, col.g, col.b, 0.28 + 0.42 * p), "width": MarkPainter.MARK_W, "pulse": true})
	out.append({"kind": &"corners", "rect": r, "color": Color(col.r, col.g, col.b, 0.95), "width": MarkPainter.MARK_W})


## The cursor square in the refusal red with a bar struck across it, from half a corner arm in.
static func refusal(rect: Rect2, alpha: float, out: Array[Dictionary]) -> void:
	var no := Color(MarkPainter.REFUSE.r, MarkPainter.REFUSE.g, MarkPainter.REFUSE.b, alpha)
	square(rect, no, out)
	var pull: Vector2 = Vector2.ONE * (minf(rect.size.x, rect.size.y) * MarkPainter.MARK_ARM * 0.5)
	out.append({"kind": &"bar", "a": rect.position + pull, "b": rect.end - pull, "color": no, "width": MarkPainter.MARK_BAR_W})


## The colour a vein pulses in: its nugget colour, chrome for a material without one.
static func ore_color(material: StringName) -> Color:
	var rec: Dictionary = MaterialsRecords.RECORDS.get(material, {})
	if not rec.has("nugget_color"):
		return MarkPainter.CHROME
	return OrePainter.record_color(rec["nugget_color"])
