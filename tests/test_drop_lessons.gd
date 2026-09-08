extends "res://tests/test_base.gd"
## The DROP's outcomes on the HUD, `view/hud/drop_lessons.gd` through `Hints`: TOO FAR for a drop refused
## short of a machine in sight (D0517, D0513's `short`), the RECEIPT a fed drop puts in the slot and the
## plate letting go of every drop lesson that tick (D0517), the receipt's eater -- the rig's demand counts,
## nothing in the window reads MACHINE -- and the eater's word being the RING's word for the machine, RIG
## over CREW RIG (D0525). Split from `test_hints_moments.gd` at the size limit; the situation-read moments
## (THE WAY DOWN, STILL WORKING, BEHIND ROCK, NOT ORE, WRONG STACK) stay there.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_drop_lessons.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_short_drop_pins()
	_test_fed_receipt_pins()
	_test_fed_receipt_eater_pins()
	_test_receipt_ring_word_pins()
	_finish("drop_lessons")


## A body at the centre of logic cell (10, 10) with `pack` held and `held` selected, `machines` in the window.
func _drop_obs(pack: Array, held: StringName, machines: Array[Dictionary]) -> Interface.Observation:
	var o: Interface.Observation = _hint_obs(pack)
	o.pos_x = (10 * 16 + 8) * S
	o.pos_y = (10 * 16 + 8) * S
	o.held_item = held
	o.machines = machines
	return o


## D0517 (strangers 103-108, D0513's `short`): a drop REFUSED for a forge in sight but out of reach -- five
## metres left, coal selected, the pack unchanged -- teaches TOO FAR with the forge, the coal, the five and
## the LEFT filled in; the slot's word for it is TOO FAR, yielding to the lesson the first time and said
## again on the next short drop. The way is ABOVE/BELOW when the rise outweighs the run; a cell with no
## machine record reads MACHINE.
func _test_short_drop_pins() -> void:
	var forge: Array[Dictionary] = [{"cell": Vector2i(5, 10), "id": &"processor", "name": "Forge", "recipe": &"smelt_ingot", "input": {}, "output": {}}]
	var h: Hints = Hints.new()
	h.observe(_drop_obs([["coal", 6]], &"coal", forge), 0.016)
	var short: Interface.Observation = _drop_obs([["coal", 6]], &"coal", forge)
	short.drop_went = &"short"
	short.drop_short_cell = Vector2i(5, 10)
	h.observe(short, 0.016)
	var text: String = h.active_text()
	_check(h.active_id() == &"dropped_short" and text.begins_with("TOO FAR — the FORGE that takes coal is 5 m to your LEFT"),
		"a drop refused for a forge 5 m left, coal selected: TOO FAR names FORGE, coal, 5, LEFT (%s: %s)" % [h.active_id(), text.left(60)])
	_check(Refusals.headline(&"dropped_short") == "TOO FAR" and h.slot_text() == "", "the slot's word for it is TOO FAR, yielding while its own lesson holds the plate (\"%s\")" % h.slot_text())
	_check(not h.taught_ids().has("dropped_floor") and not h.taught_ids().has("dropped_wrong"), "...and neither floor lesson fired for it (%s)" % str(h.taught_ids()))
	for _i: int in 3:
		h.observe(_drop_obs([["coal", 6]], &"coal", forge), 4.0)
	h.observe(short, 0.016)
	_check(h.active_id() == &"" and h.slot_text() == "TOO FAR", "the next short drop, the lesson spent: TOO FAR in the slot, latched by nothing (\"%s\", active %s)" % [h.slot_text(), h.active_id()])
	var above: Interface.Observation = _drop_obs([["coal", 6]], &"coal", [{"cell": Vector2i(11, 6), "id": &"processor", "name": "Forge", "recipe": &"smelt_ingot", "input": {}, "output": {}}])
	above.drop_went = &"short"
	above.drop_short_cell = Vector2i(11, 6)
	var h2: Hints = Hints.new()
	h2.observe(_drop_obs([["coal", 6]], &"coal", forge), 0.016)
	h2.observe(above, 0.016)
	_check(h2.active_text().find("is 4 m to your ABOVE") >= 0, "four metres up and one across: the way is ABOVE (%s)" % h2.active_text().left(60))
	var bare: Interface.Observation = _drop_obs([["ore", 2]], &"ore", [])
	bare.drop_went = &"short"
	bare.drop_short_cell = Vector2i(17, 10)
	var h3: Hints = Hints.new()
	h3.observe(_drop_obs([["ore", 2]], &"ore", []), 0.016)
	h3.observe(bare, 0.016)
	_check(h3.active_text().find("the MACHINE that takes ore is 7 m to your RIGHT") >= 0, "control: no record at the cell reads MACHINE, 7 m RIGHT (%s)" % h3.active_text().left(60))


## D0517: a drop that FED the forge six coal puts the receipt "6 COAL → FORGE" in the slot as a RECEIPT, not
## a refusal, and any drop lesson on the plate -- up or queued -- ends that tick; the rig's demand counts as
## what it takes; a fed drop beside nothing that takes it reads MACHINE; a fed drop with no fall in the pack
## gives no receipt but still lets the plate go.
func _test_fed_receipt_pins() -> void:
	var forge: Array[Dictionary] = [{"cell": Vector2i(11, 10), "id": &"processor", "name": "Forge", "recipe": &"smelt_ingot", "input": {}, "output": {}}]
	var h: Hints = Hints.new()
	h.observe(_drop_obs([["coal", 6]], &"coal", forge), 0.016)
	var fed: Interface.Observation = _drop_obs([], &"", forge)
	fed.drop_went = &"fed"
	h.observe(fed, 0.016)
	_check(h.slot_text() == "6 COAL → FORGE" and h.slot_kind() == Refusals.RECEIPT and h.active_id() == &"",
		"six coal fed to the forge: the slot says 6 COAL → FORGE as a receipt, no lesson (\"%s\", %s, %s)" % [h.slot_text(), h.slot_kind(), h.active_id()])
	h.observe(_drop_obs([], &"", forge), Refusals.SLOT_LINGER + 0.1)
	_check(h.slot_text() == "", "...and it leaves after the slot's own linger (\"%s\")" % h.slot_text())
	var h2: Hints = Hints.new()
	h2.observe(_drop_obs([["coal", 6]], &"", []), 0.016)
	var floor: Interface.Observation = _drop_obs([["coal", 6]], &"", [])
	floor.drop_went = &"floor"
	h2.observe(floor, 0.016)
	_check(h2.active_id() == &"dropped_floor", "control: a floor drop beside nothing docks NO MACHINE HERE (%s)" % h2.active_id())
	var fed2: Interface.Observation = _drop_obs([], &"", forge)
	fed2.drop_went = &"fed"
	h2.observe(fed2, 0.016)
	_check(h2.active_id() == &"" and h2.slot_text() == "6 COAL → FORGE", "the fed drop ends NO MACHINE HERE that tick and the receipt takes the slot (active %s, \"%s\")" % [h2.active_id(), h2.slot_text()])
	var h3: Hints = Hints.new()
	h3.observe(_hint_obs(), 0.016)
	h3.observe(_hint_obs([["torch", 1], ["coal", 6]]), 0.016)
	var queued: Interface.Observation = _drop_obs([["torch", 1], ["coal", 6]], &"", [])
	queued.drop_went = &"floor"
	h3.observe(queued, 0.016)
	_check(h3.active_id() == &"torch" and h3.queued() == 1, "control: NO MACHINE HERE queues behind the torch (%s, %d)" % [h3.active_id(), h3.queued()])
	var fed3: Interface.Observation = _drop_obs([["torch", 1]], &"", forge)
	fed3.drop_went = &"fed"
	h3.observe(fed3, 0.016)
	_check(h3.active_id() == &"torch" and h3.queued() == 0 and h3.slot_text() == "6 COAL → FORGE", "the fed drop drops the queued floor lesson too and leaves the torch up (%s, %d queued)" % [h3.active_id(), h3.queued()])


## D0517, the receipt's eater: the rig's demand counts as what it takes; nothing in the window that takes
## the item reads MACHINE; a fed drop with no fall in the pack gives no receipt, and neither the plate nor
## the slot keeps a drop refusal past it.
func _test_fed_receipt_eater_pins() -> void:
	var forge: Array[Dictionary] = [{"cell": Vector2i(11, 10), "id": &"processor", "name": "Forge", "recipe": &"smelt_ingot", "input": {}, "output": {}}]
	var rig: Array[Dictionary] = [{"cell": Vector2i(11, 10), "id": &"rig", "name": "Crew Rig", "behavior": &"rig", "wants": {&"ingot": 2}, "input": {}, "output": {}}]
	var h4: Hints = Hints.new()
	h4.observe(_drop_obs([["ingot", 2]], &"ingot", rig), 0.016)
	var paid: Interface.Observation = _drop_obs([], &"", rig)
	paid.drop_went = &"fed"
	h4.observe(paid, 0.016)
	_check(h4.slot_text() == "2 INGOT → RIG", "two ingots fed to the rig, which wants them: 2 INGOT → RIG, the ring's word, not the record's CREW RIG (D0525) (\"%s\")" % h4.slot_text())
	var h5: Hints = Hints.new()
	h5.observe(_drop_obs([["clay", 3]], &"clay", forge), 0.016)
	var odd: Interface.Observation = _drop_obs([], &"", forge)
	odd.drop_went = &"fed"
	h5.observe(odd, 0.016)
	_check(h5.slot_text() == "3 CLAY → MACHINE", "control: fed with nothing in the window that takes clay reads MACHINE (\"%s\")" % h5.slot_text())
	var h6: Hints = Hints.new()
	h6.observe(_drop_obs([["coal", 6]], &"", []), 0.016)
	var floor: Interface.Observation = _drop_obs([["coal", 6]], &"", [])
	floor.drop_went = &"floor"
	h6.observe(floor, 0.016)
	_check(h6.active_id() == &"dropped_floor" and h6.slot_text() == "", "control: the floor drop's lesson is up, the slot yielding to it (%s)" % h6.active_id())
	var still: Interface.Observation = _drop_obs([["coal", 6]], &"", forge)
	still.drop_went = &"fed"
	h6.observe(still, 0.016)
	_check(h6.active_id() == &"" and h6.slot_text() == "", "control: fed with no fall in the pack gives no receipt, and the plate still lets go (active %s, \"%s\")" % [h6.active_id(), h6.slot_text()])


## D0525 (W3's flag in D0517): the receipt's word for a machine is the RING's word for it -- the ring under
## the rig says RIG, and "2 INGOT → CREW RIG" over it was two words for one machine. `DropLessons.RING_WORDS`
## is `RingWord.word` read by machine id, so each entry is pinned against the ring's own word for the rung
## whose ring stands on that machine (a pile of the item, for the two the ring finds lying on the ground); a
## machine with no ring word keeps its record's name; the short lesson's eater takes the same word.
func _test_receipt_ring_word_pins() -> void:
	var at: Vector2 = DropLessons.cell_px(Vector2i(11, 10))
	var rungs: Dictionary = {&"processor": &"smelt", &"rig": &"deliver", &"hopper": &"hopper", &"generator": &"power"}
	var piles: Dictionary = {&"drill": &"build", &"winch_head": &"winch"}
	var agree: int = 0
	var words: PackedStringArray = PackedStringArray()
	for id: StringName in DropLessons.RING_WORDS:
		var o: Interface.Observation = _drop_obs([], &"", [{"cell": Vector2i(11, 10), "id": id, "name": "Record Name", "input": {}, "output": {}}])
		var ring: String = ""
		if rungs.has(id):
			ring = RingWord.word(rungs[id], o, at)
		else:
			o.piles[Vector2i(11, 10)] = {id: 1}
			ring = RingWord.word(piles[id], o, at)
		words.append("%s: ring %s, table %s" % [id, ring, DropLessons.RING_WORDS[id]])
		agree += 1 if ring == String(DropLessons.RING_WORDS[id]) and ring != "" else 0
	_check(agree == DropLessons.RING_WORDS.size() and agree == 6, "every ring word in the table is what RingWord.word says for the ring on that machine: %d of %d agree (%s)" % [agree, DropLessons.RING_WORDS.size(), "; ".join(words)])
	var iron: Array[Dictionary] = [{"cell": Vector2i(11, 10), "id": &"iron_forge", "name": "Iron Forge", "recipe": &"smelt_ingot", "input": {}, "output": {}}]
	var h7: Hints = Hints.new()
	h7.observe(_drop_obs([["coal", 6]], &"coal", iron), 0.016)
	var fed: Interface.Observation = _drop_obs([], &"", iron)
	fed.drop_went = &"fed"
	h7.observe(fed, 0.016)
	_check(h7.slot_text() == "6 COAL → IRON FORGE", "control: a machine the ring has no word for keeps its record's name (\"%s\")" % h7.slot_text())
	var rig: Array[Dictionary] = [{"cell": Vector2i(15, 10), "id": &"rig", "name": "Crew Rig", "behavior": &"rig", "wants": {&"ingot": 2}, "input": {}, "output": {}}]
	var short: Interface.Observation = _drop_obs([["ingot", 2]], &"ingot", rig)
	short.drop_went = &"short"
	short.drop_short_cell = Vector2i(15, 10)
	var subs: Dictionary = {}
	DropLessons.new().read(short, {&"ingot": 2}, subs)
	_check(String((subs.get(&"dropped_short", {}) as Dictionary).get("{eater}", "")) == "RIG", "the short lesson's eater is the ring's word too (%s)" % str(subs.get(&"dropped_short", {})))
