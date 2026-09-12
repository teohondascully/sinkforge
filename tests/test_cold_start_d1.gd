extends "res://tests/test_base.gd"

## C003's executable core (D0609, D0620): the scenario record `scenarios/cold_start_to_d1.yaml` --
## schema-validated, code-generated into `ScenarioRecords` -- is run by `harness/driver`'s
## ScenarioDriver, which boots the world the record names and hands it to the bot `agent` names
## (`harness/bots/cold_start.gd`). Every action is a `Command` through `Interface.apply`, every read
## an `observe()`; the claim's metric, `demand_satisfied.id == "d1"`, is read off `o.events` (D0605).
##
## On the envelope: the record asks for `constrained`; no fog-filtered envelope exists yet, so the
## driver runs the oracle window and SAYS SO in its report -- this suite asserts that honesty rather
## than letting the claim silently read oracle as constrained.


func _initialize() -> void:
	_test_the_scenario_record_runs_to_d1_through_the_driver()
	_finish("cold_start_d1")


func _test_the_scenario_record_runs_to_d1_through_the_driver() -> void:
	_check(ScenarioRecords.RECORDS.has("cold_start_to_d1"), "the scenario record exists in the generated table")
	var record: Dictionary = ScenarioRecords.RECORDS["cold_start_to_d1"]
	_check(record.get("claim") == "C003" and record.get("agent") == "cold_start",
		"the record names its claim and its bot (%s, %s)" % [record.get("claim"), record.get("agent")])

	var rep: Dictionary = ScenarioDriver.run(record)
	_check(rep["envelope"] == &"oracle", "the driver reports the envelope it actually used, not the one requested (%s)" % rep["envelope"])
	_check(bool(rep["legs_ok"]), "every leg of the cold start completed (reason=%s, ticks=%d)" % [rep["reason"], rep["ticks_used"]])
	_check(bool(rep["ok"]), "the rig emitted demand_satisfied d1 through o.events inside the record's budget (reason=%s, ticks=%d)" % [rep["reason"], rep["ticks_used"]])
	_check(rep["ticks_used"] <= int(record["budget_ticks"]), "the run fit the record's own budget (%d <= %d)" % [rep["ticks_used"], record["budget_ticks"]])
	_check(rep["conservation_error"] == null,
		"the claim's own rider: zero invariant violations over the whole run")
