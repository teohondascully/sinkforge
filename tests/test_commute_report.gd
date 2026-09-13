extends "res://tests/test_base.gd"

## The ~200 m commute's instrument (B3, D0647): `scenarios/commute_200.yaml` runs `CommuteBot`
## through `ScenarioDriver.run_metered` and the meter reports what the minute was spent on. The
## suite's job is the same one `test_decision_meter` does for B1: an empty report is a silent
## instrument, and a commute whose traversal bucket reads zero is a report that measured nothing.


func _initialize() -> void:
	_test_the_commute_report_is_non_empty_and_split()
	_finish("commute_report")


## Run the commute scenario metered: the route must complete (the fed forge reads `working`), the
## report must carry minutes and decisions, and the three buckets the claim names must each hold a
## share -- traversal (walk/descend/ascend_grapple), digging (the face), processing (the feeds).
func _test_the_commute_report_is_non_empty_and_split() -> void:
	var rep: Dictionary = ScenarioDriver.run_metered(ScenarioRecords.RECORDS["commute_200"])
	_check(bool(rep["ok"]), "the commute run reaches the fed-forge goal (reason=%s)" % rep["reason"])
	_check(bool(rep["legs_ok"]), "every leg of the commute route completed")
	var d: Dictionary = rep["decisions"]
	var minutes: Array = d.get("minutes", [])
	_check(not minutes.is_empty(), "the report carries at least one minute bin")
	var totals: Dictionary = d.get("totals", {})
	var decisions: int = int(totals.get("decisions", 0))
	_check(decisions > 0, "the meter counted emitted payloads (got %d) -- zero is a silent instrument"
		% decisions)
	var buckets: Dictionary = totals.get("buckets", {})
	_check(int(buckets.get(&"traversal", 0)) > 0,
		"traversal held a share -- the fall, the grapple chain, the walks (%s)" % str(buckets))
	_check(int(buckets.get(&"digging", 0)) > 0,
		"digging held a share -- the face at the foot (%s)" % str(buckets))
	_check(int(buckets.get(&"processing", 0)) > 0,
		"processing held a share -- the feeds at the top (%s)" % str(buckets))
	var kinds: Dictionary = totals.get("kinds", {})
	_check(int(kinds.get(&"climb", 0)) > 0 and int(kinds.get(&"grapple", 0)) > 0,
		"the ascent pressed climb and threw the hook (%s)" % str(kinds))
	_check(int(rep.get("ticks_used", 0)) > 0, "the run advanced the world at all")
