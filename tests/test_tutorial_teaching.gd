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
	var font: Font = ThemeDB.fallback_font
	var l: Dictionary = ObjectiveLine.layout(obj, font, 0.0)
	_check(String(l["text"]).begins_with("✓") and String(l["text"]).find("Mine 4 ore") >= 0, "the plate acknowledges the finished rung: %s" % l["text"])
	obj.refresh(o, ObjectiveLine.ACK_HOLD + 0.1)
	l = ObjectiveLine.layout(obj, font, 0.0)
	_check(String(l["text"]).begins_with("Forge 2 ingots") and String(l["text"]).ends_with("0/2") and String(l["howto"]) != "", "then the next goal with its count and its how-to: %s" % l["text"])
	_check(String(l["howto"]).find("[") < 0, "the how-to on the plate is filled")


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
	var vein: Vector2 = TargetGuide.target(&"mine", o)
	_check(vein != TargetGuide.NONE and vein.x < body_px.x and body_px.distance_to(vein) < 3.0 * 16.0, "MINE rings the vein two metres to the body's left (%.1f m off)" % (body_px.distance_to(vein) / 16.0))
	var forge: Vector2 = TargetGuide.target(&"smelt", o)
	_check(forge != TargetGuide.NONE and forge.x < body_px.x and body_px.distance_to(forge) < 4.0 * 16.0, "SMELT rings the forge three metres left (%.1f m off)" % (body_px.distance_to(forge) / 16.0))
	var drill: Vector2 = TargetGuide.target(&"build", o)
	_check(drill != TargetGuide.NONE and drill.x > body_px.x and drill.y > body_px.y, "BUILD rings the crew's drill, below and to the right (%.1f m off)" % (body_px.distance_to(drill) / 16.0))
	var coal: Vector2 = TargetGuide.target(&"fuel", o)
	_check(coal != TargetGuide.NONE and coal.x > body_px.x, "FUEL rings the coal seam to the right")
	_check(TargetGuide.target(&"auto", o) == TargetGuide.NONE, "a rung with nothing to point at rings nothing")
