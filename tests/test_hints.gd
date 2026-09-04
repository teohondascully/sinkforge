extends "res://tests/test_base.gd"
## D0370. `view/hud/hints.gd`: legacy's teaching mechanism on this build's content. The claims: the
## acquisition edge fires once per world and never on the first frame; one bubble at a time with a queue
## in table order; the moments are rising edges read off the observation; busy freezes the clock and
## hides; a ceremony holds a lesson intact; the linger cap; taught ids survive a save and unknown ids
## are dropped; resync re-arms.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_hints.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_the_acquisition_edge_fires_once_and_never_on_the_first_frame()
	_test_one_bubble_at_a_time_in_table_order()
	_test_the_moments_are_rising_edges_off_the_observation()
	_test_busy_freezes_and_hides_and_the_ceremony_holds()
	_test_the_linger_cap_and_the_fade()
	_test_taught_ids_and_resync()
	_finish("hints")


func _obs(pack: Array = []) -> Interface.Observation:
	var o: Interface.Observation = Interface.Observation.new()
	var typed: Array[Dictionary] = []
	for p: Array in pack:
		typed.append({"item": StringName(p[0]), "count": int(p[1])})
	o.pack = typed
	o.on_floor = true
	o.cell = Vector2i(10, Interface.Observation.SKY_ROWS)
	return o


func _test_the_acquisition_edge_fires_once_and_never_on_the_first_frame() -> void:
	var h: Hints = Hints.new()
	h.observe(_obs([["rope", 3]]), 0.016)
	_check(h.active_id() == &"", "a pack that already holds rope teaches nothing on the first frame")
	h.observe(_obs([["rope", 3], ["torch", 1]]), 0.016)
	_check(h.active_id() == &"torch" and h.active_text().begins_with("TORCH"), "a torch arriving teaches the torch (%s)" % h.active_id())
	h.observe(_obs([]), 0.016)
	h.observe(_obs([["torch", 1]]), 0.016)
	_check(h.queued() == 0, "re-acquiring the torch does not re-queue it")
	_check(Hints.DEFS.size() == 9 and Hints.MOMENTS.size() == 6, "nine pack lessons and six moments (%d, %d)" % [Hints.DEFS.size(), Hints.MOMENTS.size()])


func _test_one_bubble_at_a_time_in_table_order() -> void:
	var h: Hints = Hints.new()
	h.observe(_obs(), 0.016)
	h.observe(_obs([["lift", 1], ["rope", 1], ["hopper", 1]]), 0.016)
	_check(h.active_id() == &"rope" and h.queued() == 2, "three at once: rope shows first (table order), two wait (%s, %d)" % [h.active_id(), h.queued()])
	for _i: int in 20:
		h.observe(_obs([["lift", 1], ["rope", 1], ["hopper", 1]]), 0.5)
	_check(h.active_id() == &"hopper" and h.queued() == 1, "ten seconds on, the rope has expired and the hopper is up (%s)" % h.active_id())


func _test_the_moments_are_rising_edges_off_the_observation() -> void:
	var h: Hints = Hints.new()
	var dry: Interface.Observation = _obs()
	h.observe(dry, 0.016)
	var wet: Interface.Observation = _obs()
	wet.wet = true
	h.observe(wet, 0.016)
	_check(h.active_id() == &"in_water", "wading fires the aquifer lesson (%s)" % h.active_id())
	for _i: int in 30:
		h.observe(wet, 0.5)
	_check(h.active_id() == &"", "and it expires while still wet")
	h.observe(dry, 0.016)
	h.observe(wet, 0.016)
	_check(h.active_id() == &"", "a second wading does not re-teach")
	var deep: Interface.Observation = _obs()
	deep.cell.y = Interface.Observation.SKY_ROWS + 40
	h.observe(deep, 0.016)
	_check(h.active_id() == &"deep_enough", "ten metres down fires the grapple lesson (%s)" % h.active_id())
	for _i: int in 30:
		h.observe(deep, 0.5)
	var wrapped: Interface.Observation = _obs()
	wrapped.grapple_pivots = [Vector2i(100 * S, 100 * S)]
	h.observe(wrapped, 0.016)
	_check(h.active_id() == &"wrapped", "a pivot fires the catch lesson (%s)" % h.active_id())
	for _i: int in 30:
		h.observe(wrapped, 0.5)
	var fall: Interface.Observation = _obs()
	fall.on_floor = false
	fall.vel_y = Interface.Observation.MAX_FALL_PX_S * S
	h.observe(fall, 0.016)
	h.observe(_obs(), 0.016)
	_check(h.active_id() == &"hard_landing", "a terminal landing fires the hard-landing lesson (%s)" % h.active_id())


func _test_busy_freezes_and_hides_and_the_ceremony_holds() -> void:
	var h: Hints = Hints.new()
	h.observe(_obs(), 0.016)
	h.observe(_obs([["torch", 1]]), 0.016)
	var calm: Interface.Observation = _obs([["torch", 1]])
	h.observe(calm, 1.0)
	_check(h.active_alpha() > 0.99, "a second in, the bubble is fully up (%.2f)" % h.active_alpha())
	var fast: Interface.Observation = _obs([["torch", 1]])
	fast.vel_x = int(float(Interface.Observation.RUN_SPEED_PX_S) * 1.5) * S
	h.observe(fast, 5.0)
	_check(h.busy() and h.active_alpha() == 0.0 and h.active_id() == &"torch", "at 1.5x a run the bubble hides and its clock freezes: five seconds cost nothing")
	var cruising: Interface.Observation = _obs([["torch", 1]])
	cruising.vel_x = int(float(Interface.Observation.RUN_SPEED_PX_S) * 1.0) * S
	h.observe(cruising, 0.016)
	_check(h.busy(), "hysteresis: at 1.0x a run, still busy once armed")
	h.observe(calm, 0.016)
	_check(not h.busy() and h.active_alpha() > 0.99, "calm again: the lesson returns with its life")
	h.observe(calm, 3.0, true)
	_check(h.active_alpha() == 0.0 and h.active_id() == &"torch", "a ceremony hides it and holds it")
	h.observe(calm, 0.016, false)
	_check(h.active_alpha() > 0.99, "and it comes back after the ceremony")


func _test_the_linger_cap_and_the_fade() -> void:
	var h: Hints = Hints.new()
	h.observe(_obs(), 0.016)
	h.observe(_obs([["torch", 1]]), 0.0)
	_check(h.active_alpha() == 0.0, "the first instant is dark: the fade-in starts at 0")
	h.observe(_obs([["torch", 1]]), Hints.FADE_IN * 0.5)
	_check(absf(h.active_alpha() - 0.5) < 0.05, "half a fade-in later it is half up (%.2f)" % h.active_alpha())
	var fast: Interface.Observation = _obs([["torch", 1]])
	fast.vel_x = Interface.Observation.MAX_FALL_PX_S * S
	for _i: int in 60:
		h.observe(fast, 0.5)
	_check(h.active_id() == &"", "thirty busy seconds hit the linger cap and the bubble is gone (cap %.0f s)" % Hints.MAX_LINGER)


func _test_taught_ids_and_resync() -> void:
	var h: Hints = Hints.new()
	h.observe(_obs(), 0.016)
	h.observe(_obs([["torch", 1], ["rope", 1]]), 0.016)
	_check(h.taught_ids() == ["rope", "torch"], "taught ids are sorted (%s)" % str(h.taught_ids()))
	var g: Hints = Hints.new()
	g.restore_taught(["torch", "no_such_lesson", "wrapped"])
	_check(g.taught_ids() == ["torch", "wrapped"], "restore keeps known ids and drops unknown ones (%s)" % str(g.taught_ids()))
	g.observe(_obs(), 0.016)
	g.observe(_obs([["torch", 1]]), 0.016)
	_check(g.active_id() == &"", "a restored torch lesson is not taught again")
	var r: Hints = Hints.new()
	r.observe(_obs(), 0.016)
	r.observe(_obs([["lift", 1], ["rope", 1]]), 0.016)
	r.resync()
	_check(r.active_id() == &"" and r.queued() == 0, "resync clears the bubble and the queue")
	r.observe(_obs([["lift", 1], ["rope", 1], ["hopper", 1]]), 0.016)
	_check(r.active_id() == &"", "and the first frame after re-arms: the hopper already held is old news")
