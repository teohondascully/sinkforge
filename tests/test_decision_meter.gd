extends "res://tests/test_base.gd"

## The decision meter's contract (D0643): `harness/aggregate/decision_meter.gd` bins what
## `RouteBot.decide()` emits into per-minute buckets, and `ScenarioDriver.run_metered` reports it.
## The suites below pin the three ways the count could lie: a payload classified by something other
## than its own buttons, a bin keyed on something other than sim-minutes, and a run whose report came
## back empty -- the last is the instrument's whole reason to exist.


func _initialize() -> void:
	_test_classify_reads_the_payload_not_the_intent()
	_test_bins_are_sim_minutes_not_calls()
	_test_the_metered_run_produces_a_non_empty_report()
	_test_to_budget_leaves_a_decision_free_tail()
	_finish("decision_meter")


## A decision is the payload's own content: an empty frame with no commands is `idle` (the policy
## deciding to stand still), every pressed verb is its own tag, and each Command rides the same tick.
func _test_classify_reads_the_payload_not_the_intent() -> void:
	var f: InputFrame = InputFrame.new()
	_check(DecisionMeter.classify({"frame": f, "commands": []}) == [&"idle"],
		"an empty frame with no commands is exactly one tag: idle")

	f.move_dir = 1
	_check(DecisionMeter.classify({"frame": f, "commands": []}) == [&"walk"],
		"a move direction is walk")

	f.mine_held = true
	_check(DecisionMeter.classify({"frame": f, "commands": []}) == [&"walk", &"mine"],
		"a walk that holds the pick is both tags -- the meter does not pick a winner")

	f = InputFrame.new()
	f.jump_held = true
	f.climb_dir = -1
	var got: Array[StringName] = DecisionMeter.classify({"frame": f,
		"commands": [Command.select(2), Command.drop()]})
	_check(got == [&"hop", &"climb", &"cmd_select", &"cmd_drop"],
		"hop, climb and two commands all register in KIND_ORDER (%s)" % str(got))

	f = InputFrame.new()
	f.dig_pressed = true
	f.grapple_pressed = true
	got = DecisionMeter.classify({"frame": f, "commands": []})
	_check(got == [&"dig", &"grapple"], "the dig verb and the grapple press read off the frame (%s)" % str(got))


## A minute is 3600 sim ticks. Rows fabricated at the boundaries must land in three bins, and the
## zero-decision gap between the route's end and the clock's end must still show as a bin.
func _test_bins_are_sim_minutes_not_calls() -> void:
	var meter := DecisionMeter.new()
	var f: InputFrame = InputFrame.new()
	f.move_dir = -1
	meter.record(1, {"frame": f, "commands": [], "leg_kind": &"walk_to", "finished": -1})
	meter.record(3600, {"frame": InputFrame.new(), "commands": [], "leg_kind": &"", "finished": -1})
	meter.record(7261, {"frame": f, "commands": [], "leg_kind": &"descend", "finished": 2})
	meter.elapsed_ticks = 7262
	var rep: Dictionary = meter.report()
	var minutes: Array = rep["minutes"]
	_check(minutes.size() == 3, "7262 ticks is three minute bins (got %d)" % minutes.size())
	_check(int(minutes[0]["decisions"]) == 1 and int(minutes[1]["decisions"]) == 1
		and int(minutes[2]["decisions"]) == 1, "one emission landed in each bin")
	_check(int(minutes[1]["idle"]) == 1, "the minute-1 emission was the idle one")
	_check(minutes[2]["legs_finished"] == [2], "the leg that finished on that tick is attributed")
	var totals: Dictionary = rep["totals"]
	_check(int(totals["decisions"]) == 3 and int(totals["active"]) == 2 and int(totals["idle"]) == 1,
		"totals split active from idle (%s)" % str(totals))
	_check(totals["buckets"].get(&"traversal", 0) == 2,
		"walk_to and descend both bucket as traversal (%s)" % str(totals["buckets"]))


## The instrument's reason to exist: run `cold_start_to_d1` metered and the report must be non-empty
## -- minute bins, counted payloads, leg attribution -- or the whole tool reports on nothing.
func _test_the_metered_run_produces_a_non_empty_report() -> void:
	var rep: Dictionary = ScenarioDriver.run_metered(ScenarioRecords.RECORDS["cold_start_to_d1"])
	_check(bool(rep["ok"]), "the metered run still reaches the claim's goal (reason=%s)" % rep["reason"])
	_check(bool(rep["legs_ok"]), "the route's legs all completed under the meter")
	var d: Dictionary = rep["decisions"]
	var minutes: Array = d.get("minutes", [])
	_check(not minutes.is_empty(), "the report carries at least one minute bin")
	var totals: Dictionary = d.get("totals", {})
	var decisions: int = int(totals.get("decisions", 0))
	_check(decisions > 0, "the meter counted emitted payloads (got %d)" % decisions)
	_check(decisions <= int(rep["ticks_used"]),
		"decisions (%d) cannot exceed world ticks (%d) -- the world owes one tick per emission"
		% [decisions, rep["ticks_used"]])
	var legs: Dictionary = totals.get("legs", {})
	_check(int(legs.get(&"mine", 0)) > 0 and int(legs.get(&"deliver", 0)) > 0
		and int(legs.get(&"await", 0)) > 0,
		"the route's legs attributed ticks to mine/deliver/await (%s)" % str(legs))
	var kinds: Dictionary = totals.get("kinds", {})
	_check(int(kinds.get(&"mine", 0)) > 0 and int(kinds.get(&"walk", 0)) > 0
		and int(kinds.get(&"cmd_drop", 0)) > 0,
		"the payload histogram carries pick, feet and the drop command (%s)" % str(kinds))


## `--to-budget`'s contract: the clock runs to the record's budget after the route ends, the meter
## stops counting, and the difference is printed instead of silently averaged away.
func _test_to_budget_leaves_a_decision_free_tail() -> void:
	var record: Dictionary = ScenarioRecords.RECORDS["cold_start_to_d1"].duplicate()
	record["budget_ticks"] = 3900   ## just past a minute boundary, so the tail has its own bin
	var rep: Dictionary = ScenarioDriver.run_metered(record, true)
	_check(int(rep["ticks_used"]) == 3900, "the clock ran to the budget (%d)" % rep["ticks_used"])
	var d: Dictionary = rep["decisions"]
	var minutes: Array = d.get("minutes", [])
	_check(minutes.size() == 2, "3900 ticks spans two minute bins (got %d)" % minutes.size())
	if minutes.size() == 2:
		_check(int(minutes[1]["decisions"]) == 0,
			"minute 1 holds zero decisions -- the route ended inside minute 0 and the clock kept running")
	var totals: Dictionary = d.get("totals", {})
	_check(int(totals.get("decisions", 0)) > 0, "the decisions that did happen still counted")
	_check(float(totals.get("decisions_per_minute", 9999.0)) < float(totals.get("decisions", 1)),
		"the per-minute rate dropped below 60 Hz once the tail dilutes it -- the honest answer to pacing")
