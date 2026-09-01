extends "res://tests/test_base.gd"

## `sim/body/gait.gd` and `sim/body/gait_state.gd` — the stride and the stagger (D0310).
##
## `docs/LEGACY_GAP.md` T1 #9 and #10, ported from `legacy/scenes/player.gd:45-71`, `:411-432` and
## `:625-643`. Every decision is a pure integer function of its arguments, so this suite needs no world,
## no grid and no tick loop, and the acceptance suite is left to say whether the BODY still behaves.
##
## THE FIVE THINGS THIS ASSERTS, and the first is the one the whole port hangs on:
##
##   NOTHING CHANGES AT STRIDE ZERO.  `RUN_SPEED` is tuned for mining. Legacy's whole design is that
##                                    everything short of a sustained run happens at EXACTLY the old
##                                    speed. A gain applied from the first tick would still pass a
##                                    top-speed-at-full-stride test and would be a different game.
##   THE DELAY IS REAL.               The stride cannot be flicked into: `STRIDE_DELAY_TICKS` of unbroken
##                                    qualifying travel bank BEFORE the ramp starts moving at all.
##   AIRBORNE HOLDS, TURNING BREAKS.  A ledge mid-sprint must not cost the sprint; steering back must.
##   THE STAGGER IS PRICED ON DISTANCE. Not on impact speed, which saturates at terminal velocity.
##   THE SIGNATURE COVERS IT.         Every field that changes motion reaches `Body.state_signature()`,
##                                    or the two-process replay is blind to a real divergence (D0261).
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_gait.gd

const RUN: int = Body.RUN_SPEED
const FAST: int = RUN  ## travelling at exactly top speed qualifies


func _initialize() -> void:
	_test_stride_zero_is_the_old_game_exactly()
	_test_the_stride_cannot_be_flicked_into()
	_test_the_ramp_reaches_full_and_stops_there()
	_test_a_ledge_mid_sprint_keeps_the_run_and_turning_back_does_not()
	_test_the_stagger_is_priced_on_distance_not_on_impact_speed()
	_test_grip_is_reduced_but_never_removed()
	_test_a_landing_costs_half_the_run()
	_test_the_signature_registers_every_field_that_moves_the_body()
	_test_the_fuzzer_cannot_reach_the_stride_and_this_says_so()
	_finish("gait")


## THE ASSERTION THE PORT EXISTS TO PROTECT. Legacy is explicit: "everything short of that happens at
## exactly the old speed, so the mining feel is untouched and measured top speed still reads 150."
func _test_stride_zero_is_the_old_game_exactly() -> void:
	_check(Gait.top_speed(RUN, 0) == RUN,
		"at stride 0 the top speed is EXACTLY RUN_SPEED (%d), not merely close to it" % RUN)
	_check(Gait.grip(Body.ACCEL_PER_TICK, 0) == Body.ACCEL_PER_TICK,
		"with no stagger the acceleration is EXACTLY the old one")
	# ...and the other end, or "always returns its input" passes both of the above.
	var full: int = Gait.top_speed(RUN, Gait.STRIDE_FULL)
	var want: float = 150.0 * (1.0 + float(Gait.STRIDE_GAIN_NUM) / float(Gait.STRIDE_GAIN_DEN))
	print("  [OBSERVED] top speed %d px/s at stride 0, %d px/s at full (legacy: 150 -> %.0f)"
		% [RUN / Fx.SCALE, full / Fx.SCALE, want])
	_check(full > RUN, "at full stride it is HIGHER (%d -> %d px/s)" % [RUN / Fx.SCALE, full / Fx.SCALE])
	_check(absi(full / Fx.SCALE - int(want)) <= 1,
		"...and it lands on legacy's own 232 px/s (%d, want %.0f) -- the 0.55 gain ported as 11/20 and "
		% [full / Fx.SCALE, want] + "the integer arithmetic did not lose it")


## The delay is not decoration: legacy says "the delay is long enough that the stride cannot be flicked
## into". So the stride must be EXACTLY zero for the whole banking period, not merely small.
func _test_the_stride_cannot_be_flicked_into() -> void:
	var stride: int = 0
	var hold: int = 0
	for tick: int in Gait.STRIDE_DELAY_TICKS:
		var next: Dictionary = Gait.step_stride(stride, hold, true, 1, FAST, RUN)
		stride = int(next["stride"])
		hold = int(next["hold"])
	print("  [OBSERVED] after %d ticks of unbroken running: stride %d, hold %d"
		% [Gait.STRIDE_DELAY_TICKS, stride, hold])
	_check(stride == 0,
		"the stride is still EXACTLY 0 after the whole %d-tick delay (%d) -- a ramp that started "
		% [Gait.STRIDE_DELAY_TICKS, stride] + "immediately would make every short dash faster and the "
		+ "mining feel is what that would cost")
	_check(hold == Gait.STRIDE_DELAY_TICKS,
		"...and the hold banked every one of those ticks (%d)" % hold)
	# One more tick, and it moves. Without this the assertion above passes on a stride that never starts.
	var after: Dictionary = Gait.step_stride(stride, hold, true, 1, FAST, RUN)
	_check(int(after["stride"]) > 0,
		"...and the very next tick it starts (%d) -- the delay is a gate, not a wall" % int(after["stride"]))


func _test_the_ramp_reaches_full_and_stops_there() -> void:
	var stride: int = 0
	var hold: int = 0
	var ticks_to_full: int = -1
	for tick: int in 400:
		var next: Dictionary = Gait.step_stride(stride, hold, true, 1, FAST, RUN)
		stride = int(next["stride"])
		hold = int(next["hold"])
		if stride >= Gait.STRIDE_FULL and ticks_to_full < 0:
			ticks_to_full = tick + 1
	# Legacy: 0.9 s of delay then 1.2 s of ramp == 2.1 s == 126 ticks at 60 Hz.
	print("  [OBSERVED] full stride after %d ticks (legacy 0.9s + 1.2s = 126)" % ticks_to_full)
	_check(ticks_to_full > 0, "the ramp reaches full at all (%d ticks)" % ticks_to_full)
	_check(absi(ticks_to_full - 126) <= 2,
		"...and it takes legacy's own 126 ticks (%d) -- 0.9 s banking plus 1.2 s ramping at 60 Hz"
		% ticks_to_full)
	_check(stride == Gait.STRIDE_FULL,
		"...and it STOPS at full (%d of %d) rather than running away" % [stride, Gait.STRIDE_FULL])


## Legacy's three-way split, and the two halves that are easy to collapse into one. "Holding" is not the
## absence of building -- a body sailing over a gap mid-sprint must keep the run.
func _test_a_ledge_mid_sprint_keeps_the_run_and_turning_back_does_not() -> void:
	var running: int = Gait.STRIDE_FULL
	var airborne: Dictionary = Gait.step_stride(running, 99, false, 1, FAST, RUN)
	_check(int(airborne["stride"]) == running,
		"airborne mid-run with the same heading KEEPS the whole stride (%d of %d) -- a ledge must not "
		% [int(airborne["stride"]), running] + "cost the sprint")
	var turned: Dictionary = Gait.step_stride(running, 99, false, -1, FAST, RUN)
	_check(int(turned["stride"]) < running,
		"...but steering BACK against your own momentum breaks it (%d of %d)"
		% [int(turned["stride"]), running])
	var walled: Dictionary = Gait.step_stride(running, 99, true, 1, 0, RUN)
	_check(int(walled["stride"]) < running,
		"...and so does hitting a wall (%d of %d) -- a wall needs no special case, it zeroes vel_x and "
		% [int(walled["stride"]), running] + "that fails the travelling test on its own")
	var dawdling: Dictionary = Gait.step_stride(running, 99, true, 1, RUN / 2, RUN)
	_check(int(dawdling["stride"]) < running,
		"...and so does dropping below %d%% of top speed (%d of %d)"
		% [(Gait.STRIDE_MIN_SPEED_NUM * 100) / Gait.STRIDE_MIN_SPEED_DEN,
			int(dawdling["stride"]), running])
	# The decay is fast enough to read as a mistake: legacy's 3.0/s is a third of a second to nothing.
	var bled: int = running
	var ticks: int = 0
	while bled > 0 and ticks < 200:
		bled = int(Gait.step_stride(bled, 0, true, 0, 0, RUN)["stride"])
		ticks += 1
	print("  [OBSERVED] a broken run bleeds to nothing in %d ticks (legacy 3.0/s = 20)" % ticks)
	_check(absi(ticks - 20) <= 1, "a broken run is gone in ~20 ticks (%d)" % ticks)


## THE LOAD-BEARING REASON THE PRICE IS DISTANCE. Terminal velocity is `MAX_FALL` 560 px/s under
## `GRAVITY` 900 px/s², so it arrives after 560²/(2×900) = 174 px. Past that, impact speed is a CONSTANT
## and cannot distinguish a 200 px drop from a 2,000 px one. Asserted by measuring both.
func _test_the_stagger_is_priced_on_distance_not_on_impact_speed() -> void:
	var terminal_px: int = (Body.MAX_FALL_PX_S * Body.MAX_FALL_PX_S) / (2 * Body.GRAVITY_PX_S2)
	print("  [OBSERVED] terminal velocity is reached after %d px of fall; STAGGER_FALL is %d px"
		% [terminal_px, Gait.STAGGER_FALL_PX])
	_check(terminal_px < Gait.STAGGER_FALL_PX,
		"the fall that starts costing (%d px) is PAST the point where impact speed saturates (%d px) -- "
		% [Gait.STAGGER_FALL_PX, terminal_px] + "which is exactly why the price cannot be read off "
		+ "impact speed: every fall this rule is about lands at the same speed")
	_check(Gait.stagger_for_fall(Gait.STAGGER_FALL) == 0,
		"a fall of exactly STAGGER_FALL costs nothing -- the boundary is where the constant says")
	_check(Gait.stagger_for_fall(Gait.STAGGER_FALL - Fx.SCALE) == 0, "...and one just under it costs nothing")
	var mid: int = Gait.stagger_for_fall((Gait.STAGGER_FALL + Gait.STAGGER_FULL) / 2)
	_check(mid > 0 and mid < Gait.STAGGER_MAX_TICKS,
		"a fall halfway between the two costs a PART of the beat (%d of %d ticks)"
		% [mid, Gait.STAGGER_MAX_TICKS])
	_check(Gait.stagger_for_fall(Gait.STAGGER_FULL) == Gait.STAGGER_MAX_TICKS,
		"a fall of STAGGER_FULL costs the whole beat (%d ticks)" % Gait.STAGGER_MAX_TICKS)
	_check(Gait.stagger_for_fall(Gait.STAGGER_FULL * 10) == Gait.STAGGER_MAX_TICKS,
		"...and a fall TEN TIMES that costs exactly the same (%d) -- it is a beat, never a lockout, and "
		% Gait.stagger_for_fall(Gait.STAGGER_FULL * 10) + "a plunge that scaled without limit would be one")


## "The cost is grip, not damage... a platformer that takes control away feels broken however justified
## the moment." So the stagger must REDUCE authority and never remove it.
func _test_grip_is_reduced_but_never_removed() -> void:
	var normal: int = Body.ACCEL_PER_TICK
	var staggered: int = Gait.grip(normal, Gait.STAGGER_MAX_TICKS)
	print("  [OBSERVED] ground accel %d -> %d while staggered (legacy 0.34x)" % [normal, staggered])
	_check(staggered < normal, "a staggered body accelerates more slowly (%d < %d)" % [staggered, normal])
	_check(staggered > 0,
		"...but it still accelerates (%d > 0). Steering, jumping and mining all still work; this is a "
		% staggered + "beat of reduced authority, not a lockout, and a zero here would be the lockout")


func _test_a_landing_costs_half_the_run() -> void:
	var g: GaitState = GaitState.new()
	g.stride = Gait.STRIDE_FULL
	g.was_on_floor = false
	g.fall_from_y = 0
	# Landing after a fall long enough to matter, arriving at terminal velocity.
	g.step(true, Gait.STAGGER_FULL, Body.MAX_FALL, 0, 0, RUN)
	print("  [OBSERVED] after a full-height landing: stride %d of %d, stagger %d ticks, landed_hard %s"
		% [g.stride, Gait.STRIDE_FULL, g.stagger_ticks, g.landed_hard])
	_check(g.landed_hard, "a full-height landing reports itself as hard")
	_check(g.stagger_ticks > 0, "...and costs grip (%d ticks)" % g.stagger_ticks)
	_check(g.stride <= Gait.STRIDE_FULL / 2,
		"...and costs half the run (%d of %d)" % [g.stride, Gait.STRIDE_FULL])
	# The control: a short drop costs nothing. Without it, "a landing always costs half" passes above.
	var soft: GaitState = GaitState.new()
	soft.stride = Gait.STRIDE_FULL
	soft.was_on_floor = false
	soft.fall_from_y = 0
	soft.step(true, Gait.STAGGER_FALL / 2, Fx.SCALE, 0, 0, RUN)
	_check(soft.stagger_ticks == 0 and soft.stride > Gait.STRIDE_FULL / 2,
		"...while an ordinary hop costs neither grip (%d ticks) nor the run (%d of %d)"
		% [soft.stagger_ticks, soft.stride, Gait.STRIDE_FULL])


## THE DETERMINISM CONTRACT. `state_signature()` IS the contract (D0261): a field that changes motion and
## does not reach it is a divergence the two-process replay cannot see. Both new fields change motion --
## `stride` sets top speed, `stagger_ticks` sets acceleration -- so both must move the signature.
func _test_the_signature_registers_every_field_that_moves_the_body() -> void:
	var a: Body = Body.new(Fx.from_int(64), Fx.from_int(64))
	var base: String = a.state_signature()
	a.gait.stride = Gait.STRIDE_FULL
	var with_stride: String = a.state_signature()
	_check(with_stride != base, "changing `stride` changes the signature")
	a.gait.stride = 0
	a.gait.stagger_ticks = Gait.STAGGER_MAX_TICKS
	_check(a.state_signature() != base, "changing `stagger_ticks` changes the signature")
	a.gait.stagger_ticks = 0
	a.gait.hold = 7
	_check(a.state_signature() != base,
		"...and so does `hold`, which is not read by the physics directly but DECIDES when the stride "
		+ "starts, so two bodies differing only in it diverge a tick later")
	a.gait.hold = 0
	a.gait.fall_from_y = Fx.from_int(999)
	_check(a.state_signature() != base,
		"...and `fall_from_y`, which decides what the next landing costs")
	a.gait.fall_from_y = 0
	a.gait.was_on_floor = not a.gait.was_on_floor
	_check(a.state_signature() != base, "...and `was_on_floor`, which is the edge the fall seed reads")
	# And back to the start: the signature is a function of the state, not a counter that only grows.
	a.gait.was_on_floor = not a.gait.was_on_floor
	_check(a.state_signature() == base,
		"restoring every field restores the signature -- it reports STATE, not history")


## WHAT THE PER-COMMIT FUZZER CANNOT SEE, stated here so nobody reads its green as coverage of this.
##
## Adding the stride and the stagger moved `test_body_acceptance`'s traverse by 31 ticks and moved
## `test_body_fuzz_fast`'s violation count by **exactly zero** — `bounds=922` before and after. That is
## not luck and it is not evidence of safety. `FuzzDriverCommon.random_input` draws `move_dir` uniformly
## from {-1, 0, 1} **independently every tick**, so the chance of the `STRIDE_DELAY_TICKS` consecutive
## same-direction ticks the stride needs is `2 x (1/3)^54` — about 1 in 10^25, against 50,000 ticks.
##
## **The fuzzer cannot build a stride, so it cannot fuzz one.** This is `docs/NEEDS_DIRECTOR.md` P004's
## finding again in a third place: that entry records the same fuzzer posing the corner nudge zero times
## and excavating once in 50,000 ticks. A sustained run is a THIRD mechanic its input distribution
## excludes by construction.
##
## Asserted rather than written down, and measured over the real generator rather than derived, so that
## if the distribution ever changes this line says so instead of quietly becoming false.
func _test_the_fuzzer_cannot_reach_the_stride_and_this_says_so() -> void:
	var rng: SplitRng = SplitRng.new(20260901)
	var longest: int = 0
	var current: int = 0
	var last: int = 0
	for i: int in 50000:
		var dir: int = FuzzDriverCommon.random_input(rng, false).move_dir
		if dir != 0 and dir == last:
			current += 1
		else:
			current = 1 if dir != 0 else 0
		last = dir
		longest = maxi(longest, current)
	print("  [OBSERVED] longest same-direction run in 50,000 fuzz ticks: %d (stride needs %d)"
		% [longest, Gait.STRIDE_DELAY_TICKS + 1])
	_check(longest <= Gait.STRIDE_DELAY_TICKS,
		"the per-commit fuzzer's longest unbroken heading is %d ticks, under the %d the stride needs -- "
		% [longest, Gait.STRIDE_DELAY_TICKS + 1] + "so `test_body_fuzz_fast` staying at bounds=922 across "
		+ "this change is EXPLAINED, not reassuring. If this assertion ever fails the distribution has "
		+ "changed and the fuzzer has started covering the stride, which is good news and worth knowing.")
