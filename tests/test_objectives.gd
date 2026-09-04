extends "res://tests/test_base.gd"
## D0370. `view/hud/objectives.gd`: the ladder off the observation. The claims are legacy's mechanism
## rules on this build's content: the first frame primes so a stocked pack ticks nothing; a gain is a
## rise and a spend cannot lower it; each predicate reads what it says (a drill placed, fuelled, a
## hopper banking coal directly above it, a generator burning, a working winch head, the line's ingot
## rate after the drill); completions latch; the step clock resets on advance; the finish lingers.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_objectives.gd


func _initialize() -> void:
	_test_the_first_frame_primes_and_gains_are_rises()
	_test_the_pack_steps()
	_test_the_machine_steps()
	_test_the_line_has_run_and_completions_latch()
	_test_the_clock_and_the_finish()
	_finish("objectives")


func _obs(pack: Array = [], machines: Array = []) -> Interface.Observation:
	var o: Interface.Observation = Interface.Observation.new()
	var typed: Array[Dictionary] = []
	for p: Array in pack:
		typed.append({"item": StringName(p[0]), "count": int(p[1])})
	o.pack = typed
	for m: Dictionary in machines:
		o.machines.append(m)
	return o


func _m(behavior: StringName, cell: Vector2i, extra: Dictionary = {}) -> Dictionary:
	var r: Dictionary = {"cell": cell, "id": behavior, "behavior": behavior, "status": &"idle", "fuel": 0, "filter": &"", "input": {}, "output": {}}
	for k: Variant in extra:
		r[k] = extra[k]
	return r


func _test_the_first_frame_primes_and_gains_are_rises() -> void:
	var obj: Objectives = Objectives.new()
	obj.refresh(_obs([["ore", 10]]), 0.016)
	_check(not obj.is_done(&"mine") and obj.gained(&"ore") == 0, "a pack that already holds 10 ore ticks nothing on the first frame")
	obj.refresh(_obs([["ore", 13]]), 0.016)
	_check(obj.gained(&"ore") == 3 and not obj.is_done(&"mine"), "a rise of 3 is banked, short of 4 (%d)" % obj.gained(&"ore"))
	obj.refresh(_obs([["ore", 1]]), 0.016)
	_check(obj.gained(&"ore") == 3, "a spend does not lower the gain (%d)" % obj.gained(&"ore"))
	obj.refresh(_obs([["ore", 2]]), 0.016)
	_check(obj.gained(&"ore") == 4 and obj.is_done(&"mine"), "the fourth unit gained across spends completes the step")
	_check(obj.current_id() == &"smelt", "and the ladder advances to smelting (%s)" % obj.current_id())


func _test_the_pack_steps() -> void:
	var obj: Objectives = Objectives.new()
	obj.refresh(_obs(), 0.016)
	obj.refresh(_obs([["ore", 4], ["iron_ingot", 1], ["ingot", 1], ["wood", 1]]), 0.016)
	_check(obj.is_done(&"mine") and obj.is_done(&"smelt") and obj.is_done(&"wood"), "ore, two ingots of either kind, and wood complete the first three")
	_check(obj.current_id() == &"build", "next is the drill (%s)" % obj.current_id())


func _test_the_machine_steps() -> void:
	var obj: Objectives = Objectives.new()
	obj.refresh(_obs(), 0.016)
	obj.refresh(_obs([], [_m(&"drill", Vector2i(5, 6))]), 0.016)
	_check(obj.is_done(&"build") and not obj.is_done(&"fuel"), "a placed drill builds the line but is not fuelled")
	obj.refresh(_obs([], [_m(&"drill", Vector2i(5, 6), {"input": {&"coal": 2}})]), 0.016)
	_check(obj.is_done(&"fuel"), "coal in its buffer fuels it")
	obj.refresh(_obs([], [_m(&"drill", Vector2i(5, 6)), _m(&"hopper", Vector2i(5, 4), {"filter": &"coal"})]), 0.016)
	_check(not obj.is_done(&"hopper"), "a coal hopper two cells up is not feeding the drill")
	obj.refresh(_obs([], [_m(&"drill", Vector2i(5, 6)), _m(&"hopper", Vector2i(5, 5), {"filter": &"stone"})]), 0.016)
	_check(not obj.is_done(&"hopper"), "a hopper above it banking stone is not feeding coal")
	obj.refresh(_obs([], [_m(&"drill", Vector2i(5, 6)), _m(&"hopper", Vector2i(5, 5), {"filter": &"coal"})]), 0.016)
	_check(obj.is_done(&"hopper"), "a coal hopper directly above the drill automates the feed")
	obj.refresh(_obs([], [_m(&"generator", Vector2i(8, 6))]), 0.016)
	_check(not obj.is_done(&"power"), "a cold generator is not power")
	obj.refresh(_obs([], [_m(&"generator", Vector2i(8, 6), {"fuel": 3})]), 0.016)
	_check(obj.is_done(&"power"), "a burning one is")
	obj.refresh(_obs([], [_m(&"winch_head", Vector2i(9, 9), {"status": &"no_input"})]), 0.016)
	_check(not obj.is_done(&"winch"), "a winch head with nothing to bore is not raised")
	obj.refresh(_obs([], [_m(&"winch_head", Vector2i(9, 9), {"status": &"working"})]), 0.016)
	_check(obj.is_done(&"winch"), "a working one is")


func _test_the_line_has_run_and_completions_latch() -> void:
	var obj: Objectives = Objectives.new()
	obj.refresh(_obs(), 0.016)
	var o: Interface.Observation = _obs()
	o.rates = [{"item": &"ingot", "rate_centi": 120}]
	obj.refresh(o, 0.016)
	_check(not obj.is_done(&"auto"), "an ingot rate before any drill existed is the player's hand, not the line")
	obj.refresh(_obs([], [_m(&"drill", Vector2i(5, 6))]), 0.016)
	obj.refresh(o, 0.016)
	_check(obj.is_done(&"auto") and obj.is_done(&"build"), "the same rate after the drill was seen is first automation, and the removed drill's step stays done")
	obj.refresh(_obs(), 0.016)
	_check(obj.is_done(&"auto") and obj.is_done(&"build"), "completions latch when the state passes")


func _test_the_clock_and_the_finish() -> void:
	var obj: Objectives = Objectives.new()
	obj.refresh(_obs(), 0.0)
	for _i: int in 10:
		obj.refresh(_obs(), 0.5)
	_check(is_equal_approx(obj.step_age, 5.0), "five seconds on the first step (%.1f)" % obj.step_age)
	obj.refresh(_obs([["ore", 4]]), 0.5)
	_check(obj.step_age == 0.0 and obj.current_index() == 1, "advancing resets the step clock")
	_check(obj.done_for() < 0.0 and not obj.all_done(), "not finished: done_for is -1")
	var all: Array = []
	for m: Dictionary in [_m(&"drill", Vector2i(5, 6), {"fuel": 1}), _m(&"hopper", Vector2i(5, 5), {"filter": &"coal"}), _m(&"generator", Vector2i(8, 6), {"fuel": 1}), _m(&"winch_head", Vector2i(9, 9), {"status": &"working"})]:
		all.append(m)
	var o: Interface.Observation = _obs([["ore", 4], ["ingot", 2], ["wood", 1]], all)
	o.rates = [{"item": &"ingot", "rate_centi": 50}]
	obj.refresh(o, 0.5)
	obj.refresh(o, 0.5)
	_check(obj.all_done() and obj.current_index() == Objectives.STEPS.size() and obj.current_id() == &"", "every step done: the index is past the end")
	obj.refresh(o, 2.0)
	_check(is_equal_approx(obj.done_for(), 3.0), "done_for counts from the finish, the completing frame's own half second included, as legacy's did (%.1f)" % obj.done_for())
	_check(Objectives.STEPS.size() == 9, "nine steps in the ladder (%d)" % Objectives.STEPS.size())
