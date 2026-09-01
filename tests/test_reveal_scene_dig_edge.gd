extends "res://tests/test_base.gd"

## D0188 (Defect B). `sim/body/input_frame.gd` documents `dig_pressed` as edge-triggered -- "true only on
## the tick the button transitioned to held", explicitly "not a hold-to-clear-a-wall auto-repeat" (D0110).
## `reveal_scene.gd`'s human input path assigned the RAW held state instead, so one physical hold became
## one event per held tick.
##
## WHAT THIS FILE ASSERTS, AND WHY IT IS SHAPED THIS WAY. `_read_play_input()` polls real hardware
## (`Input.is_physical_key_pressed`) and cannot run headless, so the fix had to be reachable without it --
## hence `RevealScene._dig_edge()`, which is the whole state machine and is what this suite drives.
##
## The assertions are on EVENT COUNTS produced by a hold PATTERN, never on the expression itself. A test
## that recomputed `held and not was_held` and compared it to `_dig_edge`'s output would pass for any
## implementation of that same expression including a wrong one -- the self-referential mutation test
## D0112 records as having hidden a real off-by-one in `BodyDig.handle`'s right-facing case for exactly this
## reason. A count over a pattern cannot be satisfied by restating the code under test.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_reveal_scene_dig_edge.gd

const RevealScene := preload("res://tests/body/reveal_scene.gd")

## The real shape from the director's own recorded session, not an invented number: one unbroken 30-tick
## hold, the only dig input in 807 ticks (`tests/body/recordings/reveal_play_2026-08-30T02-04-24.log`,
## re-counted directly rather than taken from the report that first flagged it).
const RECORDED_HOLD_TICKS: int = 30


func _initialize() -> void:
	_test_one_unbroken_hold_is_one_event()
	_test_the_recorded_807_tick_session_shape_yields_exactly_one_event()
	_test_release_and_repress_is_two_events()
	_test_never_pressed_is_zero_events()
	_test_alternating_ticks_are_all_events()
	_test_the_latch_survives_across_separate_reads()
	_finish("reveal_scene_dig_edge")


## Drives `_dig_edge` over a hold pattern and returns how many edges it reported. `.new()` on the scene
## script gives a bare `Node2D` whose `_ready()` never fires (it is never added to a tree), so no grid,
## body, camera or command-line parsing happens -- only the two-line latch under test is exercised.
func _edges(pattern: Array[bool]) -> int:
	var scene: Node2D = RevealScene.new()
	var count: int = 0
	for held: bool in pattern:
		if scene._dig_edge(held):
			count += 1
	scene.free()
	return count


func _held_run(ticks: int) -> Array[bool]:
	var out: Array[bool] = []
	for _i: int in range(ticks):
		out.append(true)
	return out


## The defect itself, stated as a number: holding the key down for N ticks is ONE press, not N.
func _test_one_unbroken_hold_is_one_event() -> void:
	for ticks: int in [1, 2, 5, 100]:
		var got: int = _edges(_held_run(ticks))
		_check(got == 1, "a %d-tick unbroken hold reports exactly 1 dig event (got %d)" % [ticks, got])


## The exact recorded shape: idle, then one 30-tick hold, then idle. Under the pre-fix code this returned
## 30 -- which is what the director's session actually recorded, and the reason this file exists.
func _test_the_recorded_807_tick_session_shape_yields_exactly_one_event() -> void:
	var pattern: Array[bool] = []
	for _i: int in range(120):
		pattern.append(false)
	pattern.append_array(_held_run(RECORDED_HOLD_TICKS))
	for _i: int in range(657):
		pattern.append(false)
	var got: int = _edges(pattern)
	_check(got == 1,
		"the recorded session's shape (807 ticks, one unbroken %d-tick hold) reports 1 dig event, not %d --"
		% [RECORDED_HOLD_TICKS, RECORDED_HOLD_TICKS] +
		" got %d. Pre-fix this returned %d." % [got, RECORDED_HOLD_TICKS])


## The complement: a real second press must still be seen. A latch that only ever reported the first edge
## would pass every assertion above, so this is the one that makes those meaningful.
func _test_release_and_repress_is_two_events() -> void:
	var pattern: Array[bool] = _held_run(10)
	pattern.append(false)
	pattern.append_array(_held_run(10))
	var got: int = _edges(pattern)
	_check(got == 2, "hold, release, hold again reports exactly 2 dig events (got %d)" % got)


func _test_never_pressed_is_zero_events() -> void:
	var pattern: Array[bool] = []
	for _i: int in range(50):
		pattern.append(false)
	var got: int = _edges(pattern)
	_check(got == 0, "a run with the key never held reports 0 dig events (got %d)" % got)


## The upper bound, and the reason "one event per tick" is not automatically wrong: input that genuinely
## transitions every tick genuinely IS an edge every tick. This pins the latch to the TRANSITION rather
## than to some rate limit, which a debounce-style fix would fail.
func _test_alternating_ticks_are_all_events() -> void:
	var pattern: Array[bool] = []
	for i: int in range(20):
		pattern.append(i % 2 == 0)
	var got: int = _edges(pattern)
	_check(got == 10, "10 separate press/release cycles report 10 dig events (got %d)" % got)


## The latch is per-instance member state, not a static or a local -- a local would reset every call and
## silently restore the auto-repeat this fix removes, while passing any single-call assertion.
func _test_the_latch_survives_across_separate_reads() -> void:
	var scene: Node2D = RevealScene.new()
	var first: bool = scene._dig_edge(true)
	var second: bool = scene._dig_edge(true)
	scene.free()
	_check(first and not second,
		"the held-state latch persists between calls: first read is an edge (%s), second is not (%s)"
		% [first, second])
