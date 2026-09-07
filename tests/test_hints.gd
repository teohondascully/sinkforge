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
	_test_a_waiting_lesson_makes_the_active_one_yield_on_wall_time()
	_test_the_grapple_is_known_by_lesson_or_by_throw()
	_test_a_drop_that_hits_the_floor_teaches_once()
	_finish("hints")


func _test_the_acquisition_edge_fires_once_and_never_on_the_first_frame() -> void:
	var h: Hints = Hints.new()
	h.observe(_hint_obs([["rope", 3]]), 0.016)
	_check(h.active_id() == &"", "a pack that already holds rope teaches nothing on the first frame")
	h.observe(_hint_obs([["rope", 3], ["torch", 1]]), 0.016)
	_check(h.active_id() == &"torch" and h.active_text().begins_with("TORCH"), "a torch arriving teaches the torch (%s)" % h.active_id())
	h.observe(_hint_obs([]), 0.016)
	h.observe(_hint_obs([["torch", 1]]), 0.016)
	_check(h.queued() == 0, "re-acquiring the torch does not re-queue it")
	_check(Hints.DEFS.size() == 9 and Hints.MOMENTS.size() == 16, "nine pack lessons and sixteen moments (%d, %d)" % [Hints.DEFS.size(), Hints.MOMENTS.size()])


## D0436: the same slash held on open air teaches NOTHING THERE, on a longer count that a break restarts; the
## far ticks and the air ticks are separate counts, so alternating the two teaches neither.
func _air_pins(h: Hints, far: Interface.Observation, dry: Interface.Observation) -> void:
	var air: Interface.Observation = _hint_obs()
	air.aim_refusal = &"air"
	for i: int in 2 * Hints.AIR_TICKS:
		h.observe(air if i % 2 == 0 else far, 0.016)
	_check(h.active_id() == &"", "alternating air and far refusals for %d ticks teaches nothing (%s)" % [2 * Hints.AIR_TICKS, h.active_id()])
	var broke: Interface.Observation = _hint_obs()
	broke.aim_refusal = &"air"
	broke.mining_broke = true
	for _i: int in Hints.AIR_TICKS - 1:
		h.observe(air, 0.016)
	h.observe(broke, 0.016)
	for _i: int in Hints.AIR_TICKS:
		h.observe(air, 0.016)
	# D0467: a break under the pointer restarts the count AND names the hole: the air after your own bite
	# is CUT THROUGH at CUT_TICKS, and NOTHING THERE never comes for it, however long it is held.
	_check(h.active_id() == &"cut_through", "%d air ticks, a break, %d more: CUT THROUGH, not NOTHING THERE (%s)" % [Hints.AIR_TICKS - 1, Hints.AIR_TICKS, h.active_id()])
	var cold: Hints = Hints.new()
	for _i: int in Hints.AIR_TICKS - 1:
		cold.observe(air, 0.016)
	_check(cold.active_id() == &"", "air with no bite behind it teaches nothing for %d ticks (%s)" % [Hints.AIR_TICKS - 1, cold.active_id()])
	cold.observe(air, 0.016)
	_check(cold.active_id() == &"aim_air" and cold.active_text().begins_with("NOTHING THERE") and Hints.AIR_TICKS > 3 * Hints.FAR_TICKS, "the %dth tick on air fires NOTHING THERE, a count well past TOO FAR's %d (%s)" % [Hints.AIR_TICKS, Hints.FAR_TICKS, cold.active_id()])
	for _i: int in 30:
		h.observe(dry, 0.5)
	# D0445 (stranger 20): the same "air" refusal with a machine under the aimed cell is THAT IS A MACHINE, on
	# TOO FAR's count, and never NOTHING THERE however long it is held.
	var h2: Hints = Hints.new()
	var machine: Interface.Observation = _hint_obs()
	machine.aim_refusal = &"air"
	machine.aim_cell = Vector2i(46, 82)
	var typed: Array[Dictionary] = [{"cell": Vector2i(11, 20), "id": &"processor", "recipe": &"smelt_ingot", "input": {}, "output": {}}]
	machine.machines = typed
	for _i: int in 2 * Hints.AIR_TICKS:
		h2.observe(machine, 0.016)
	_check(h2.active_id() == &"aim_machine" and h2.active_text().begins_with("THAT IS A MACHINE") and not h2.taught_ids().has("aim_air"), "MINE held on the forge's cell teaches THAT IS A MACHINE and never NOTHING THERE (%s)" % h2.active_id())


func _test_one_bubble_at_a_time_in_table_order() -> void:
	var h: Hints = Hints.new()
	h.observe(_hint_obs(), 0.016)
	h.observe(_hint_obs([["lift", 1], ["rope", 1], ["hopper", 1]]), 0.016)
	_check(h.active_id() == &"rope" and h.queued() == 2, "three at once: rope shows first (table order), two wait (%s, %d)" % [h.active_id(), h.queued()])
	for _i: int in 20:
		h.observe(_hint_obs([["lift", 1], ["rope", 1], ["hopper", 1]]), 0.5)
	_check(h.active_id() == &"hopper" and h.queued() == 1, "ten seconds on, the rope has expired and the hopper is up (%s)" % h.active_id())


func _test_the_moments_are_rising_edges_off_the_observation() -> void:
	var h: Hints = Hints.new()
	var dry: Interface.Observation = _hint_obs()
	h.observe(dry, 0.016)
	var wet: Interface.Observation = _hint_obs()
	wet.wet = true
	h.observe(wet, 0.016)
	_check(h.active_id() == &"in_water", "wading fires the aquifer lesson (%s)" % h.active_id())
	for _i: int in 30:
		h.observe(wet, 0.5)
	_check(h.active_id() == &"", "and it expires while still wet")
	h.observe(dry, 0.016)
	h.observe(wet, 0.016)
	_check(h.active_id() == &"", "a second wading does not re-teach")
	# D0421: MINE held on rock past the reach for a third of a second teaches TOO FAR, once; a brush past
	# the reach (fewer ticks) teaches nothing.
	var far: Interface.Observation = _hint_obs()
	far.aim_refusal = &"far"
	for _i: int in Hints.FAR_TICKS - 1:
		h.observe(far, 0.016)
	_check(h.active_id() == &"", "a brush past the reach (%d ticks) teaches nothing yet" % (Hints.FAR_TICKS - 1))
	h.observe(far, 0.016)
	_check(h.active_id() == &"too_far", "the twentieth tick fires TOO FAR (%s)" % h.active_id())
	for _i: int in 30:
		h.observe(dry, 0.5)
	_air_pins(h, far, dry)
	var deep: Interface.Observation = _hint_obs()
	deep.cell.y = Interface.Observation.SKY_ROWS + 40
	h.observe(deep, 0.016)
	_check(h.active_id() == &"deep_enough", "ten metres down fires the grapple lesson (%s)" % h.active_id())
	for _i: int in 30:
		h.observe(deep, 0.5)
	var wrapped: Interface.Observation = _hint_obs()
	wrapped.grapple_pivots = [Vector2i(100 * S, 100 * S)]
	h.observe(wrapped, 0.016)
	_check(h.active_id() == &"wrapped", "a pivot fires the catch lesson (%s)" % h.active_id())
	for _i: int in 30:
		h.observe(wrapped, 0.5)
	var fall: Interface.Observation = _hint_obs()
	fall.on_floor = false
	fall.vel_y = Interface.Observation.MAX_FALL_PX_S * S
	h.observe(fall, 0.016)
	h.observe(_hint_obs(), 0.016)
	_check(h.active_id() == &"hard_landing", "a terminal landing fires the hard-landing lesson (%s)" % h.active_id())


func _test_busy_freezes_and_hides_and_the_ceremony_holds() -> void:
	var h: Hints = Hints.new()
	h.observe(_hint_obs(), 0.016)
	h.observe(_hint_obs([["torch", 1]]), 0.016)
	var calm: Interface.Observation = _hint_obs([["torch", 1]])
	h.observe(calm, 1.0)
	_check(h.active_alpha() > 0.99, "a second in, the bubble is fully up (%.2f)" % h.active_alpha())
	var fast: Interface.Observation = _hint_obs([["torch", 1]])
	fast.vel_x = int(float(Interface.Observation.RUN_SPEED_PX_S) * 1.5) * S
	h.observe(fast, 5.0)
	_check(h.busy() and h.active_alpha() == 0.0 and h.active_id() == &"torch", "at 1.5x a run the bubble hides and its clock freezes: five seconds cost nothing")
	var cruising: Interface.Observation = _hint_obs([["torch", 1]])
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
	h.observe(_hint_obs(), 0.016)
	h.observe(_hint_obs([["torch", 1]]), 0.0)
	_check(h.active_alpha() == 0.0, "the first instant is dark: the fade-in starts at 0")
	h.observe(_hint_obs([["torch", 1]]), Hints.FADE_IN * 0.5)
	_check(absf(h.active_alpha() - 0.5) < 0.05, "half a fade-in later it is half up (%.2f)" % h.active_alpha())
	var fast: Interface.Observation = _hint_obs([["torch", 1]])
	fast.vel_x = Interface.Observation.MAX_FALL_PX_S * S
	for _i: int in 60:
		h.observe(fast, 0.5)
	_check(h.active_id() == &"", "thirty busy seconds hit the linger cap and the bubble is gone (cap %.0f s)" % Hints.MAX_LINGER)


func _test_taught_ids_and_resync() -> void:
	var h: Hints = Hints.new()
	h.observe(_hint_obs(), 0.016)
	h.observe(_hint_obs([["torch", 1], ["rope", 1]]), 0.016)
	_check(h.taught_ids() == ["rope", "torch"], "taught ids are sorted (%s)" % str(h.taught_ids()))
	var g: Hints = Hints.new()
	g.restore_taught(["torch", "no_such_lesson", "wrapped"])
	_check(g.taught_ids() == ["torch", "wrapped"], "restore keeps known ids and drops unknown ones (%s)" % str(g.taught_ids()))
	g.observe(_hint_obs(), 0.016)
	g.observe(_hint_obs([["torch", 1]]), 0.016)
	_check(g.active_id() == &"", "a restored torch lesson is not taught again")
	var r: Hints = Hints.new()
	r.observe(_hint_obs(), 0.016)
	r.observe(_hint_obs([["lift", 1], ["rope", 1]]), 0.016)
	r.resync()
	_check(r.active_id() == &"" and r.queued() == 0, "resync clears the bubble and the queue")
	r.observe(_hint_obs([["lift", 1], ["rope", 1], ["hopper", 1]]), 0.016)
	_check(r.active_id() == &"", "and the first frame after re-arms: the hopper already held is old news")


## D0424 (stranger 3): a busy body froze TOO FAR's calm clock while the GRAPPLE lesson waited behind it
## for the full 27 s linger, twenty metres down a shaft. With a ready lesson waiting, the active one yields
## after QUEUE_LINGER seconds HIDDEN; with nothing waiting, the old cap stands (the control); and calm
## reading is untouched (the table-order test above keeps its nine seconds a lesson).
func _test_a_waiting_lesson_makes_the_active_one_yield_on_wall_time() -> void:
	var h: Hints = Hints.new()
	h.observe(_hint_obs(), 0.016)
	h.observe(_hint_obs([["torch", 1]]), 0.016)
	_check(h.active_id() == &"torch", "the torch is up")
	var fast_wet: Interface.Observation = _hint_obs([["torch", 1]])
	fast_wet.vel_x = Interface.Observation.MAX_FALL_PX_S * S
	fast_wet.wet = true
	h.observe(fast_wet, 0.016)
	_check(h.queued() == 1 and h.active_id() == &"torch", "wading fast: AQUIFER queues behind the torch (%d, %s)" % [h.queued(), h.active_id()])
	var elapsed: float = 0.016
	while elapsed < Hints.QUEUE_LINGER - 0.5:
		h.observe(fast_wet, 0.5)
		elapsed += 0.5
	_check(h.active_id() == &"torch", "under QUEUE_LINGER the torch still holds the plate (%.1f s)" % elapsed)
	h.observe(fast_wet, 1.0)
	_check(h.active_id() == &"in_water" and h.queued() == 0, "past QUEUE_LINGER of wall time the torch yields and AQUIFER is up (%s)" % h.active_id())
	# Control: no waiting lesson, the same busy body, the same wall time -- the old cap stands.
	var c: Hints = Hints.new()
	c.observe(_hint_obs(), 0.016)
	c.observe(_hint_obs([["torch", 1]]), 0.016)
	var fast: Interface.Observation = _hint_obs([["torch", 1]])
	fast.vel_x = Interface.Observation.MAX_FALL_PX_S * S
	for _i: int in 14:
		c.observe(fast, 0.5)
	_check(c.active_id() == &"torch" and c.queued() == 0, "control: seven busy seconds with nothing waiting and the torch still holds (%s)" % c.active_id())


## D0424: the rope painter's landing ring waits on this. Fresh: unknown. The deep lesson firing: known
## (the latch is at queue time, and the lesson shows within QUEUE_LINGER). A line thrown before any lesson:
## known too, and it stays known once the line is stowed.
func _test_the_grapple_is_known_by_lesson_or_by_throw() -> void:
	var h: Hints = Hints.new()
	h.observe(_hint_obs(), 0.016)
	_check(not h.grapple_known(), "a fresh player has not met the grapple")
	var deep: Interface.Observation = _hint_obs()
	deep.cell = Vector2i(10, MaterialLook.SURFACE_ROW + (int(Hints.DEPTH_HINT_M) + 1) * MaterialLook.CELLS_PER_METRE)
	h.observe(deep, 0.016)
	_check(h.grapple_known(), "the deep lesson firing makes the grapple known (active %s, queued %d)" % [h.active_id(), h.queued()])
	var t: Hints = Hints.new()
	t.observe(_hint_obs(), 0.016)
	var live: Interface.Observation = _hint_obs()
	live.grapple_live = true
	t.observe(live, 0.016)
	_check(t.grapple_known(), "a line thrown on the surface makes it known")
	t.observe(_hint_obs(), 0.016)
	_check(t.grapple_known(), "and it stays known once the line is stowed")
	var r: Hints = Hints.new()
	r.observe(_hint_obs(), 0.016)
	r.restore_taught(["deep_enough"])
	_check(r.grapple_known(), "a save that taught the deep lesson restores the knowledge")


## D0428 (stranger 5): twenty-five DROPs five metres from the forge, the stack at the feet and back, and
## nothing but the ticks to say so. The first drop that lands on the floor docks the lesson; a drop that
## fed a machine does not; it latches like every moment.
func _test_a_drop_that_hits_the_floor_teaches_once() -> void:
	var h: Hints = Hints.new()
	h.observe(_hint_obs(), 0.016)
	var fed: Interface.Observation = _hint_obs()
	fed.drop_went = &"fed"
	h.observe(fed, 0.016)
	_check(h.active_id() == &"", "a drop that fed a machine teaches nothing")
	var floor: Interface.Observation = _hint_obs()
	floor.drop_went = &"floor"
	h.observe(floor, 0.016)
	_check(h.active_id() == &"dropped_floor" and h.active_text().begins_with("DROPPED"), "the first drop to the floor docks DROPPED (%s)" % h.active_id())
	for _i: int in 30:
		h.observe(_hint_obs(), 0.5)
	h.observe(floor, 0.016)
	_check(h.active_id() == &"" and h.queued() == 0, "a second floor drop is not taught again")
