extends "res://tests/test_base.gd"

## Mutation tests for tests/body/reveal_metric.gd's RevealMetric.compute -- claims/C004's own instrument.
## All synthetic: builds TickEvent arrays by hand, never touches Body/TileGrid/ShaftGenerator, so these
## stay fast and independent of terrain generation.

const REVEAL: StringName = &"glimmer"
const OTHER: StringName = &"hardrock"


func _initialize() -> void:
	_test_empty_session()
	_test_dig_events_counted_including_non_reveal_digs()
	_test_no_reveal_events_means_no_qualifying_reveals()
	_test_reveal_too_close_to_start_is_excluded()
	_test_reveal_too_close_to_end_is_excluded()
	_test_a_real_lift_is_computed_correctly()
	_test_multiple_reveals_are_averaged()
	_finish("reveal_metric")


func _flat_events(count: int) -> Array[RevealMetric.TickEvent]:
	var events: Array[RevealMetric.TickEvent] = []
	for _i: int in count:
		events.append(RevealMetric.TickEvent.new())
	return events


func _test_empty_session() -> void:
	var result: Dictionary = RevealMetric.compute([], REVEAL)
	_check(result["total_ticks"] == 0, "empty session: total_ticks == 0")
	_check(result["dig_events"] == 0, "empty session: dig_events == 0")
	_check(result["qualifying_reveals"] == 0, "empty session: qualifying_reveals == 0")
	_check(not result.has("lift"), "empty session: no lift key when there's nothing to average")


func _test_dig_events_counted_including_non_reveal_digs() -> void:
	var events: Array[RevealMetric.TickEvent] = _flat_events(10)
	events[2].dig_event = true
	events[2].dug_material = OTHER
	events[5].dig_event = true
	events[5].dug_material = REVEAL
	events[8].dig_event = true
	events[8].dug_material = OTHER
	var result: Dictionary = RevealMetric.compute(events, REVEAL)
	_check(result["dig_events"] == 3,
		"dig_events counts every dig regardless of material (got %d, want 3)" % result["dig_events"])


func _test_no_reveal_events_means_no_qualifying_reveals() -> void:
	var events: Array[RevealMetric.TickEvent] = _flat_events(1000)
	for i: int in [100, 400, 700]:
		events[i].dig_event = true
		events[i].dug_material = OTHER  # real digs, never glimmer
	var result: Dictionary = RevealMetric.compute(events, REVEAL)
	_check(result["qualifying_reveals"] == 0,
		"non-reveal digs never count as a qualifying reveal (got %d)" % result["qualifying_reveals"])
	_check(not result.has("lift"), "no lift when nothing revealed")


func _test_reveal_too_close_to_start_is_excluded() -> void:
	var events: Array[RevealMetric.TickEvent] = _flat_events(1000)
	events[RevealMetric.WINDOW_TICKS - 1].dig_event = true  # one tick short of a full BEFORE window
	events[RevealMetric.WINDOW_TICKS - 1].dug_material = REVEAL
	var result: Dictionary = RevealMetric.compute(events, REVEAL)
	_check(result["qualifying_reveals"] == 0,
		"a reveal with less than WINDOW_TICKS ticks of history is excluded, not padded (got %d)" %
		result["qualifying_reveals"])


func _test_reveal_too_close_to_end_is_excluded() -> void:
	var total: int = 1000
	var events: Array[RevealMetric.TickEvent] = _flat_events(total)
	events[total - RevealMetric.WINDOW_TICKS].dig_event = true  # one tick short of a full AFTER window
	events[total - RevealMetric.WINDOW_TICKS].dug_material = REVEAL
	var result: Dictionary = RevealMetric.compute(events, REVEAL)
	_check(result["qualifying_reveals"] == 0,
		"a reveal with less than WINDOW_TICKS ticks of runway left is excluded, not padded (got %d)" %
		result["qualifying_reveals"])


## The core claim, exercised directly: sparse digging before a reveal, dense digging after -- a real,
## hand-computable lift, not just "some nonzero number."
func _test_a_real_lift_is_computed_correctly() -> void:
	var w: int = RevealMetric.WINDOW_TICKS
	var total: int = w * 2 + 1
	var reveal_tick: int = w
	var events: Array[RevealMetric.TickEvent] = _flat_events(total)
	events[reveal_tick].dig_event = true
	events[reveal_tick].dug_material = REVEAL
	# Before window [0, w): a dig every 10 ticks -> w/10 events. After window (w, 2w]: a dig every tick.
	for i: int in range(0, w, 10):
		events[i].dig_event = true
		events[i].dug_material = OTHER
	for i: int in range(reveal_tick + 1, total):
		events[i].dig_event = true
		events[i].dug_material = OTHER
	var result: Dictionary = RevealMetric.compute(events, REVEAL)
	_check(result["qualifying_reveals"] == 1, "exactly one qualifying reveal (got %d)" % result["qualifying_reveals"])
	var expected_before_rate: float = float(w / 10) / float(w)  # integer division matches the range() step count
	var expected_after_rate: float = 1.0  # every tick in the after window dug
	_check(absf(result["mean_before_rate"] - expected_before_rate) < 0.001,
		"before-rate matches the hand-computed sparse rate (got %.4f, want %.4f)" %
		[result["mean_before_rate"], expected_before_rate])
	_check(absf(result["mean_after_rate"] - expected_after_rate) < 0.001,
		"after-rate matches the hand-computed dense rate (got %.4f, want %.4f)" %
		[result["mean_after_rate"], expected_after_rate])
	_check(result["lift"] > 0.85, "a sparse-before/dense-after session shows a real positive lift (got %.4f)" %
		result["lift"])


func _test_multiple_reveals_are_averaged() -> void:
	var w: int = RevealMetric.WINDOW_TICKS
	var total: int = w * 4 + 1  # reveal_b sits at 3w and needs a FULL w-tick after-window past it, i.e.
	# a valid index up to 4w -- w*4 alone leaves zero margin (3w + w == total is the excluded boundary,
	# not a full window), a real off-by-one caught only by actually running this test, not by inspection
	var events: Array[RevealMetric.TickEvent] = _flat_events(total)
	var reveal_a: int = w
	var reveal_b: int = w * 3
	events[reveal_a].dig_event = true
	events[reveal_a].dug_material = REVEAL
	events[reveal_b].dig_event = true
	events[reveal_b].dug_material = REVEAL
	# Identical, deliberately-uniform dig pattern around both reveals so the two individual lifts are
	# equal -- proves averaging doesn't distort a case where distortion would be invisible otherwise.
	for i: int in range(0, total, 5):
		if i != reveal_a and i != reveal_b:
			events[i].dig_event = true
			events[i].dug_material = OTHER
	var result: Dictionary = RevealMetric.compute(events, REVEAL)
	_check(result["qualifying_reveals"] == 2, "both reveals qualify (got %d)" % result["qualifying_reveals"])
	# Same uniform pattern before and after every reveal -> lift should be ~0, not a spurious nonzero
	# value averaging could introduce if the two per-reveal lifts were computed or combined incorrectly.
	_check(absf(result["lift"]) < 0.01,
		"a uniform dig pattern around every reveal averages to ~zero lift (got %.4f)" % result["lift"])
