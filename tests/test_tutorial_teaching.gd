extends "res://tests/test_base.gd"

## THE TUTORIAL TEACHES ACTIONABLY (D0411, the new-player review's rank 3). A lesson names the key the verb
## is bound to NOW, not the verb; the goal chip carries the count; the how-to shows the moment a rung opens
## and again when the player has stalled, and a finished rung is acknowledged before the next; the ring
## sits on the thing the rung means, found in the real tutorial world; and the ladder's latched rungs ride
## the save so a returning player is not put back on rung one.

const SEED: int = 20260826


func _initialize() -> void:
	_test_tokens_fill_with_the_bound_key_and_never_leave_a_bracket()
	_test_progress_and_the_reversed_reveal_rule()
	_test_the_ladder_rides_the_save()
	_test_the_ring_finds_the_real_targets()
	_finish("tutorial_teaching")


func _test_tokens_fill_with_the_bound_key_and_never_leave_a_bracket() -> void:
	BindingLabels.labels = {Controls.MINE: "LMB", Controls.DROP: "Q"}
	_check(BindingLabels.fill("Hold [MINE] on rock, press [DROP]") == "Hold LMB on rock, press Q", "tokens become the keys the shell wrote")
	_check(BindingLabels.fill("press [BUILD]") == "press BUILD", "an unwritten token falls back to its verb name, never an empty bracket")
	BindingLabels.labels = {}
	for step: Dictionary in Objectives.STEPS:
		var filled: String = BindingLabels.fill(String(step["label"]))
		_check(filled.find("[") < 0, "every rung's sentence fills completely: %s" % [step["id"]])
	var grapple: String = ""
	for m: Dictionary in Hints.MOMENTS:
		if m["id"] == &"deep_enough":
			grapple = String(m["text"])
	_check(grapple.find("[GRAPPLE]") >= 0 and grapple.to_lower().find("winch") < 0, "the grapple lesson names the grapple key and never the winch, which is a machine")


func _test_progress_and_the_reversed_reveal_rule() -> void:
	var obj: Objectives = Objectives.new()
	var o: Interface.Observation = Interface.Observation.new()
	obj.refresh(o, 0.1)                       # primes on an empty pack
	o.pack = [{"item": &"ore", "count": 2}]
	obj.refresh(o, 0.1)
	_check(obj.progress(&"mine") == "2/4" and obj.progress(&"build") == "", "a counted rung reports its progress; an uncounted one nothing")
	var a0: Dictionary = ObjectiveLine.alphas(3, 2.0, false)
	var a1: Dictionary = ObjectiveLine.alphas(3, 20.0, false)
	var a2: Dictionary = ObjectiveLine.alphas(3, 45.0, false)
	_check(float(a0["goal"]) == 1.0 and float(a0["hint"]) == 1.0, "a later rung shows its goal AND its how-to the moment it opens (legacy hid both for forty seconds)")
	_check(float(a1["goal"]) == 1.0 and float(a1["hint"]) == 0.0, "the how-to fades after the hold, the goal stays")
	_check(float(a2["hint"]) == 1.0, "and returns once the player has stalled")
	# The acknowledgement: rung 1 just latched, so the plate shows its tick before rung 2's goal.
	o.pack = [{"item": &"ore", "count": 6}]
	obj.refresh(o, 0.1)
	_check(obj.is_done(&"mine") and obj.current_id() == &"smelt" and obj.step_age < ObjectiveLine.ACK_HOLD, "rung 1 latched, rung 2 current, fresh")
	_check(TargetGuide.ring_alpha(obj) == 0.0, "the ring stands down while the finished rung is acknowledged")
	var font: Font = ThemeDB.fallback_font
	var l: Dictionary = ObjectiveLine.layout(obj, font, 0.0)
	_check(String(l["text"]).begins_with("✓") and String(l["text"]).find("Mine 4 ore") >= 0, "the plate acknowledges the finished rung: %s" % l["text"])
	obj.refresh(o, ObjectiveLine.ACK_HOLD + 0.1)
	l = ObjectiveLine.layout(obj, font, 0.0)
	_check(String(l["text"]).begins_with("Forge 2 ingots") and String(l["text"]).ends_with("0/2") and String(l["howto"]) != "", "then the next goal with its count and its how-to: %s" % l["text"])
	_check(String(l["howto"]).find("[") < 0, "the how-to on the plate is filled")
	# THE RING OUTLIVES THE HOW-TO (D0428, stranger 5): full while the how-to is up, the floor after it fades,
	# never zero while the rung is open.
	_check(TargetGuide.ring_alpha(obj) == 1.0, "the ring is full while the how-to is up (%.2f)" % TargetGuide.ring_alpha(obj))
	obj.refresh(o, 20.0)
	_check(float(ObjectiveLine.alphas(obj.current_index(), obj.step_age, false)["hint"]) == 0.0 and is_equal_approx(TargetGuide.ring_alpha(obj), TargetGuide.RING_FLOOR) and TargetGuide.RING_FLOOR > 0.0,
		"twenty seconds in the how-to is gone and the ring holds at its floor (%.2f): the pointer stays for the rung's life" % TargetGuide.ring_alpha(obj))


func _test_the_ladder_rides_the_save() -> void:
	var obj: Objectives = Objectives.new()
	var o: Interface.Observation = Interface.Observation.new()
	obj.refresh(o, 0.1)
	o.pack = [{"item": &"ore", "count": 4}, {"item": &"ingot", "count": 2}]
	obj.refresh(o, 0.1)
	var two: Array = ["mine", "smelt"]
	_check(obj.done_ids() == two, "the latched rungs, in ladder order: %s" % [obj.done_ids()])
	var later: Objectives = Objectives.new()
	later.restore_done(obj.done_ids())
	_check(later.is_done(&"mine") and later.is_done(&"smelt") and later.current_id() == &"wood", "a fresh ladder restored from them stands on rung 3")
	var stack: ViewStack = ViewStack.new()
	stack.objectives = later
	var env: Dictionary = {}
	SeatHud.capture(stack, env)
	_check(env.get(SeatHud.KEY_OBJECTIVES) == two, "the shell writes the rungs beside the hints in the session")
	var third: Objectives = Objectives.new()
	var again: ViewStack = ViewStack.new()
	again.objectives = third
	SeatHud.restore(again, env)
	_check(third.current_id() == &"wood", "...and reads them back")
	SeatHud.restore(again, {})
	_check(third.current_id() == &"wood", "an empty session leaves the ladder as it is")


func _test_the_ring_finds_the_real_targets() -> void:
	var door: Interface = Session.new_game(StrataData.SHALLOW_CLAY, SEED, &"tutorial")
	if door == null:
		_check(false, "the tutorial starts")
		return
	var world: World = door.services()["world"]
	var body: Body = door.services()["body"]
	var o: Interface.Observation = door.observe(Interface.Envelope.oracle_over(world.grid))
	var body_px: Vector2 = Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE)
	TargetGuide.scan_visits = 0
	var vein: Vector2 = TargetGuide.target(&"mine", o)
	var visits: int = TargetGuide.scan_visits
	_check(vein != TargetGuide.NONE and vein.x < body_px.x and body_px.distance_to(vein) < 3.0 * 16.0, "MINE rings the vein two metres to the body's left (%.1f m off)" % (body_px.distance_to(vein) / 16.0))
	# D0414: the ring walk stops once no farther ring can beat the hit -- a vein two metres off costs a
	# few hundred visits, never the 6561 of the full window -- and it finds the same cell brute force does.
	var full: int = (2 * TargetGuide.SEARCH_CELLS + 1) * (2 * TargetGuide.SEARCH_CELLS + 1)
	_check(visits > 0 and visits < full / 8, "the ring search visited %d cells for a vein %.1f m off (the full window is %d)" % [visits, body_px.distance_to(vein) / 16.0, full])
	var brute: Vector2 = TargetGuide.NONE
	var brute_d: float = 1.0e18
	var centre := Vector2i(floori(body_px.x / 4.0), floori(body_px.y / 4.0))
	for dy: int in range(-TargetGuide.SEARCH_CELLS, TargetGuide.SEARCH_CELLS + 1):
		for dx: int in range(-TargetGuide.SEARCH_CELLS, TargetGuide.SEARCH_CELLS + 1):
			var c: Vector2i = centre + Vector2i(dx, dy)
			if o.window.has_point(c) and o.is_ore_like_at(c) and o.material_at(c) != &"coal":
				var at: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * 4.0
				if at.distance_squared_to(body_px) < brute_d:
					brute_d = at.distance_squared_to(body_px)
					brute = at
	_check(vein == brute, "...and it is the cell brute force finds (%s vs %s)" % [vein, brute])
	var guide: TargetGuide = TargetGuide.new(Objectives.new())
	TargetGuide.scan_visits = 0
	var first: Vector2 = guide._cached_target(&"mine", o)
	var after_first: int = TargetGuide.scan_visits
	var second: Vector2 = guide._cached_target(&"mine", o)
	_check(first == vein and second == first and TargetGuide.scan_visits == after_first and after_first > 0, "the chip searches once per (rung, cell, terrain) and reuses it: %d visits, then none" % after_first)
	var forge: Vector2 = TargetGuide.target(&"smelt", o)
	_check(forge != TargetGuide.NONE and forge.x < body_px.x and body_px.distance_to(forge) < 4.0 * 16.0, "SMELT rings the forge three metres left (%.1f m off)" % (body_px.distance_to(forge) / 16.0))
	var drill: Vector2 = TargetGuide.target(&"build", o)
	_check(drill != TargetGuide.NONE and drill.x > body_px.x and drill.y > body_px.y, "BUILD rings the crew's drill, below and to the right (%.1f m off)" % (body_px.distance_to(drill) / 16.0))
	var coal: Vector2 = TargetGuide.target(&"fuel", o)
	_check(coal != TargetGuide.NONE and coal.x > body_px.x, "FUEL rings the coal seam to the right")
	_check(TargetGuide.target(&"auto", o) == TargetGuide.NONE, "a rung with nothing to point at rings nothing")
	_budgeted_walk_pins(o, body_px)
	_band_pins(door, world, body)


## D0436 (strangers 11 and 12): from the drill shaft's lip the buried vein two metres under the surface is
## the nearest ore by the ruler and out of reach from anywhere the body can stand; the ring prefers the
## vein at the body's own level, however far across. Standing IN the shaft, the buried vein is the level one.
func _band_pins(door: Interface, world: World, body: Body) -> void:
	var spawn_x: int = body.pos_x
	body.pos_x = spawn_x + int(7.5 * 16.0) * Fx.SCALE                 # the shaft's right lip, on the surface
	var o: Interface.Observation = door.observe(Interface.Envelope.oracle_over(world.grid))
	var body_px: Vector2 = Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE)
	var ruler: Vector2 = TargetGuide.NONE
	var ruler_d: float = 1.0e18
	for dy: int in range(-TargetGuide.SEARCH_CELLS, TargetGuide.SEARCH_CELLS + 1):
		for dx: int in range(-TargetGuide.SEARCH_CELLS, TargetGuide.SEARCH_CELLS + 1):
			var c: Vector2i = Vector2i(floori(body_px.x / 4.0) + dx, floori(body_px.y / 4.0) + dy)
			if not (o.window.has_point(c) and o.is_ore_like_at(c) and o.material_at(c) != &"coal"):
				continue
			var at: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * 4.0
			if at.distance_squared_to(body_px) < ruler_d:
				ruler_d = at.distance_squared_to(body_px)
				ruler = at
	var ring: Vector2 = TargetGuide.target(&"mine", o)
	_check(ruler != TargetGuide.NONE and ruler.y - body_px.y > TargetGuide.BAND_PX and absf(ruler.x - body_px.x) < 16.0,
		"control: the ruler's nearest ore from the shaft's lip is the buried vein, %.1f m below the body's centre and past its reach" % ((ruler.y - body_px.y) / 16.0))
	_check(ring != TargetGuide.NONE and ring != ruler and absf(ring.y - body_px.y) <= TargetGuide.BAND_PX and ring.x < body_px.x - 6.0 * 16.0,
		"MINE rings the vein at the body's own level instead, %.1f m to the left (the ruler's was %.1f m off)" % [(body_px.x - ring.x) / 16.0, sqrt(ruler_d) / 16.0])
	# D0438 (stranger 14): the same rule for a machine. From the lip the auto forge buried in the shaft is the
	# nearer processor by the ruler; SMELT rings the surface forge ten metres west at the body's level.
	var forge: Vector2 = TargetGuide.target(&"smelt", o)
	var buried: Vector2 = TargetGuide.NONE
	var buried_d: float = 1.0e18
	for rec: Dictionary in o.machines:
		var at: Vector2 = (Vector2(rec["cell"]) + Vector2(0.5, 0.5)) * 16.0
		if rec.get("id", &"") == &"processor" and at.distance_squared_to(body_px) < buried_d:
			buried_d = at.distance_squared_to(body_px)
			buried = at
	_check(buried != TargetGuide.NONE and buried.y - body_px.y > TargetGuide.BAND_PX and absf(buried.x - body_px.x) < 16.0, "control: the ruler's nearest forge from the lip is the one buried in the shaft, %.1f m below" % ((buried.y - body_px.y) / 16.0))
	_check(forge != TargetGuide.NONE and forge != buried and absf(forge.y - body_px.y) <= TargetGuide.BAND_PX and forge.x < body_px.x - 8.0 * 16.0, "SMELT rings the surface forge at the body's level instead, %.1f m to the left" % ((body_px.x - forge.x) / 16.0))
	body.pos_x = spawn_x + 7 * 16 * Fx.SCALE + 8 * Fx.SCALE            # in the shaft's mouth, a metre down
	body.pos_y += 16 * Fx.SCALE
	o = door.observe(Interface.Envelope.oracle_over(world.grid))
	body_px = Vector2(float(body.pos_x), float(body.pos_y)) / float(Fx.SCALE)
	var below: Vector2 = TargetGuide.target(&"mine", o)
	_check(below != TargetGuide.NONE and below.y > body_px.y and absf(below.y - body_px.y) <= TargetGuide.BAND_PX and absf(below.x - body_px.x) < 8.0,
		"standing in the shaft's mouth the buried vein is at the body's level and the ring is on it (%.1f m below)" % ((below.y - body_px.y) / 16.0))
	body.pos_x = spawn_x
	body.pos_y -= 16 * Fx.SCALE


## D0431 (stranger 6): the tree stands six metres left of spawn; from the drill shaft at +7 that is 13 m,
## past the old ten-metre search, and no ring pointed at it. WOOD rings the tutorial tree from spawn now,
## and the wider walk is paid across frames.
func _budgeted_walk_pins(o: Interface.Observation, body_px: Vector2) -> void:
	var trunk: Vector2 = TargetGuide.target(&"wood", o)
	_check(trunk != TargetGuide.NONE and trunk.x < body_px.x and absf(body_px.distance_to(trunk) / 16.0 - 6.0) < 1.5, "WOOD rings the tutorial tree about six metres left (%.1f m off)" % (body_px.distance_to(trunk) / 16.0))
	_check(TargetGuide.SEARCH_CELLS * 4 >= 25 * 16, "the search reaches the screen's half-width at play zoom (%d cells)" % TargetGuide.SEARCH_CELLS)
	# The walk is paid across frames: a small budget stops short and hands back where it was; resumed, it
	# reaches the full search's answer with the same visits in total.
	var wanted: Callable = TargetGuide.cell_predicate(&"wood", o)
	TargetGuide.scan_visits = 0
	var step: Dictionary = TargetGuide.scan(o, body_px, wanted, 0, TargetGuide.NONE, 1.0e18, 50)
	_check(not bool(step["done"]) and int(step["next_r"]) > 0 and int(step["next_r"]) < TargetGuide.SEARCH_CELLS, "a 50-visit budget stops the walk mid-way at radius %d" % int(step["next_r"]))
	var rounds: int = 1
	while not bool(step["done"]) and rounds < 1000:
		step = TargetGuide.scan(o, body_px, wanted, int(step["next_r"]), step["best"], float(step["best_d"]), 50)
		rounds += 1
	var budgeted: int = TargetGuide.scan_visits
	TargetGuide.scan_visits = 0
	var whole: Vector2 = TargetGuide.target(&"wood", o)
	_check(bool(step["done"]) and step["best"] == whole and budgeted == TargetGuide.scan_visits, "resumed over %d rounds it finds the same trunk with the same %d visits as one walk (%d)" % [rounds, TargetGuide.scan_visits, budgeted])
	var g2: TargetGuide = TargetGuide.new(Objectives.new())
	var frames: int = 0
	var seen: Vector2 = TargetGuide.NONE
	while seen == TargetGuide.NONE and frames < 60:
		seen = g2._cached_target(&"wood", o)
		frames += 1
	_check(seen == whole and frames >= 1 and frames <= 12, "the chip's frame-budgeted walk shows the ring within %d frames" % frames)
	# D0433: the ring tightens as the body arrives, so it never sits on the miner's chest.
	_check(is_equal_approx(TargetGuide.ring_m(0.5), TargetGuide.RING_NEAR_M) and is_equal_approx(TargetGuide.ring_m(6.0), TargetGuide.RING_M) and TargetGuide.ring_m(2.5) > TargetGuide.RING_NEAR_M and TargetGuide.ring_m(2.5) < TargetGuide.RING_M,
		"the ring is %.2f m beside the target, %.2f m far off, between in between" % [TargetGuide.ring_m(0.5), TargetGuide.ring_m(6.0)])
	# D0443 (strangers 13 and 17): where the ring has tightened to a speck, the target's own metre is outlined
	# -- the square the pointer must land on -- and nothing hangs in the air beside it to be pointed at.
	var beside: float = Vector2(1.5, 1.25).length()   # a cell a step to the side of the boot, from the body's centre
	_check(TargetGuide.near(beside) and TargetGuide.near(TargetGuide.NEAR_M) and not TargetGuide.near(3.0), "the block outline shows for a cell beside the boot (%.2f m from the centre), within %.1f m, and not beyond" % [beside, TargetGuide.NEAR_M])
	var metre: Rect2 = TargetGuide.target_metre(Vector2(102.0, 322.0))
	_check(metre == Rect2(96.0, 320.0, 16.0, 16.0) and metre.has_point(Vector2(102.0, 322.0)), "the outlined metre is the one the target cell lies in (%s)" % str(metre))
