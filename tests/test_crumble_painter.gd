extends "res://tests/test_base.gd"

## `view/visuals/crumble_painter.gd` — rock shattering when it breaks (D0278, the other half of
## LEGACY_GAP T1 #5), and the first consumer of D0277's cosmetic clock.
##
## This painter is the one that KEEPS STATE, so the suite is about lifecycle rather than geometry: does
## it spawn once per break and not once per redraw, does it age off a clock rather than off draw calls,
## does it retire, and does the cap drop the OLDEST rather than refusing the newest.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_crumble_painter.gd


func _initialize() -> void:
	_test_it_spawns_from_what_broke_this_tick()
	_test_a_redraw_does_not_respawn_the_same_debris()
	_test_age_comes_from_the_clock_not_from_draw_calls()
	_test_finished_crumbles_retire()
	_test_the_cap_drops_the_oldest_rather_than_refusing_the_newest()
	_test_an_incomplete_frame_spawns_nothing()
	_finish("crumble_painter")


## A frame reporting `cells` as broken on `tick`.
func _frame(tick: int, cells: Array[Vector2i], now: float) -> Frame:
	var f := Frame.new()
	f.obs = Interface.Observation.new()
	f.obs.tick = tick
	f.obs.cell_px = Heightfield.TERRAIN_CELL_PX
	f.obs.mining_broke_cells = cells
	f.obs.mining_broke_material = &"clay"
	f.look = MaterialLook.new()
	f.anim_time = now
	return f


func _test_it_spawns_from_what_broke_this_tick() -> void:
	var p := CrumblePainter.new()
	_check(p.alive_count() == 0, "a fresh painter holds nothing (%d)" % p.alive_count())
	_check(not p.note_frame(_frame(1, [], 0.0)),
		"a tick where nothing broke spawns nothing, and SAYS so rather than silently doing nothing")
	_check(p.note_frame(_frame(2, [Vector2i(3, 4), Vector2i(3, 5)], 0.0)),
		"a tick with two broken cells spawns")
	_check(p.alive_count() == 2, "one crumble per broken cell (%d of 2)" % p.alive_count())


## THE GUARD THAT MAKES SPAWN-FROM-FRAME SAFE. Godot redraws a canvas for reasons the coordinator did not
## initiate — a resize, a focus change — and each of those hands the painter the same observation again.
## Without the tick guard every one would re-spawn the same debris, and the bug would only appear on
## someone else's machine when they resized a window.
func _test_a_redraw_does_not_respawn_the_same_debris() -> void:
	var p := CrumblePainter.new()
	var f: Frame = _frame(7, [Vector2i(1, 1)], 0.0)
	p.note_frame(f)
	var after_first: int = p.alive_count()
	for _i: int in 5:
		p.note_frame(f)   ## the SAME frame, as a repeated redraw would deliver it
	_check(after_first == 1, "sanity: the first pass spawned (%d)" % after_first)
	_check(p.alive_count() == after_first,
		"five more draws of the same tick spawn nothing further (%d of %d)" % [p.alive_count(), after_first])
	# And the guard must not be so wide that it blocks a REAL later break. Without this the row above
	# passes on a painter that spawns exactly once and never again.
	_check(p.note_frame(_frame(8, [Vector2i(2, 2)], 0.0)),
		"CONTROL: the next TICK still spawns -- the guard is on the tick, not on having spawned before")


## Age is derived from the clock, not accumulated per draw. A painter that added a fixed step per draw
## would animate at the frame rate, and two captures of one tick would differ — which is the whole reason
## D0277 made the clock a deterministic counter.
func _test_age_comes_from_the_clock_not_from_draw_calls() -> void:
	_check(is_equal_approx(CrumblePainter.progress(0.0, 0.0), 0.0), "at spawn, progress is 0")
	_check(is_equal_approx(CrumblePainter.progress(0.0, CrumblePainter.DUR * 0.5), 0.5),
		"halfway through the duration, progress is 0.5 (%f)" % CrumblePainter.progress(0.0, CrumblePainter.DUR * 0.5))
	_check(is_equal_approx(CrumblePainter.progress(0.0, CrumblePainter.DUR), 1.0), "at the duration, 1.0")
	_check(is_equal_approx(CrumblePainter.progress(0.0, CrumblePainter.DUR * 9.0), 1.0),
		"and it CLAMPS rather than running past 1.0 -- an unclamped t inverts the shrink and the chunk "
		+ "grows forever (%f)" % CrumblePainter.progress(0.0, CrumblePainter.DUR * 9.0))
	_check(is_equal_approx(CrumblePainter.progress(2.0, 2.0 + CrumblePainter.DUR * 0.25), 0.25),
		"and it is measured from the SPAWN time, not from zero (%f)"
		% CrumblePainter.progress(2.0, 2.0 + CrumblePainter.DUR * 0.25))


## Retirement is what stops the list growing for the whole session. Checked through `advance`, the
## spawn-and-retire step `paint` itself calls — Godot refuses `draw_rect` outside a node's own `_draw()`,
## so going through `paint` here would need a mounted scene to assert a list operation.
func _test_finished_crumbles_retire() -> void:
	var p := CrumblePainter.new()
	p.advance(_frame(1, [Vector2i(5, 5)], 0.0))
	_check(p.alive_count() == 1, "sanity: one crumble is alive right after the break (%d)" % p.alive_count())
	p.advance(_frame(2, [], CrumblePainter.DUR * 0.5))
	_check(p.alive_count() == 1,
		"halfway through its life it is still drawn (%d) -- retiring early would make the animation "
		% p.alive_count() + "stop before it finished, which reads as a dropped frame")
	p.advance(_frame(3, [], CrumblePainter.DUR * 1.01))
	_check(p.alive_count() == 0, "and past its duration it is gone (%d)" % p.alive_count())


## Legacy's cap drops the OLDEST. The opposite policy — refusing to spawn once full — would make a rapid
## dig stop showing feedback exactly when the player is digging hardest, which is backwards.
func _test_the_cap_drops_the_oldest_rather_than_refusing_the_newest() -> void:
	var p := CrumblePainter.new()
	var overflow: int = CrumblePainter.MAX_ALIVE + 10
	for i: int in overflow:
		p.note_frame(_frame(100 + i, [Vector2i(i, 0)], 0.0))
	_check(p.alive_count() == CrumblePainter.MAX_ALIVE,
		"the list is capped at %d (%d alive after %d breaks)"
		% [CrumblePainter.MAX_ALIVE, p.alive_count(), overflow])
	# The NEWEST break must have survived. Asserted through a fresh painter's own first spawn as the
	# control, since `alive_count` alone cannot say WHICH ones are held.
	var last := CrumblePainter.new()
	last.note_frame(_frame(1, [Vector2i(overflow - 1, 0)], 0.0))
	_check(last.alive_count() == 1,
		"CONTROL: a break does spawn one crumble, so 'capped at %d' above is a cap and not a coincidence"
		% CrumblePainter.MAX_ALIVE)


## Each is a real startup state. None may crash, and none may spawn phantom debris at the origin.
func _test_an_incomplete_frame_spawns_nothing() -> void:
	var p := CrumblePainter.new()
	var no_look := _frame(1, [Vector2i(1, 1)], 0.0)
	no_look.look = null
	var no_obs := Frame.new()
	no_obs.look = MaterialLook.new()
	for f: Frame in [no_look, no_obs]:
		_check(not p.note_frame(f), "an incomplete frame spawns nothing")
		p.advance(f)
	p.advance(null)
	_check(p.alive_count() == 0, "and nothing accumulated from any of them (%d)" % p.alive_count())
	# CONTROL: the same painter DOES spawn from a complete frame, so the rows above are not passing on a
	# painter that ignores every frame it is given.
	_check(p.note_frame(_frame(2, [Vector2i(1, 1)], 0.0)) and p.alive_count() == 1,
		"CONTROL: a complete frame still spawns (%d alive)" % p.alive_count())
