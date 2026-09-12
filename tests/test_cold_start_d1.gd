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
	_test_the_resulting_state_is_a_checkpoint_that_reloads_identically()
	_test_a_mid_run_checkpoint_resumes_the_same_route_to_the_goal()
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


## The claim's last clause: "the resulting state is a valid checkpoint (re-loadable, re-derivable
## byte-identically)". The door the run ended on is captured through `Session` (the shell's save
## surface), round-tripped through the binary serializer, and rebuilt with `Session.from_save`; the
## restored session must sign identically and STAY identical under further ticks -- the same proof
## shape `test_boot_snapshot.gd` runs on a fresh game, here on a lived one.
func _test_the_resulting_state_is_a_checkpoint_that_reloads_identically() -> void:
	var rep: Dictionary = ScenarioDriver.run(ScenarioRecords.RECORDS["cold_start_to_d1"])
	_check(bool(rep["ok"]), "control: a fresh run reaches d1 before the checkpoint leg (reason=%s)" % rep["reason"])
	if not bool(rep["ok"]):
		return
	var door: Interface = rep["session"]
	var env: Dictionary = Session.capture(door)
	var restored: Interface = Session.from_save(bytes_to_var(var_to_bytes(env)))
	_check(restored != null, "the resulting state re-loads through the serializer (%s)" % SaveGame.last_invalid)
	if restored == null:
		return
	var a: PackedStringArray = door.state_signature().split("||")
	var b: PackedStringArray = restored.state_signature().split("||")
	_check(a.size() == 8 and b.size() == 8, "eight signed parts on both sides (body, world, items, machines, mining, plan, lode, verbs)")
	_check(a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] and a[5] == b[5] and a[6] == b[6],
		"every saved part signs as the run's end state")
	_check(a[7] != b[7], "the bot's hotbar selection is verbs state, never saved (D0355) -- the pin is that it differs")
	# The run ends quiescent -- nothing in flight, so empty ticks would not move the signature and the
	# equality below would be a no-op. Held input must move the body: a bare `jump_held` proved too
	# weak (no press edge, and a hop can land back on its own footprint -- it did, once the route's
	# end position shifted a few ticks), so this walks east off the pad with a real press edge.
	var hop: InputFrame = InputFrame.new()
	hop.move_dir = 1
	hop.jump_pressed = true
	hop.jump_held = true
	var walk: InputFrame = InputFrame.new()
	walk.move_dir = 1
	for i: int in 30:
		var f: InputFrame = hop if i == 0 else (walk if i < 10 else InputFrame.new())
		door.apply(Command.move(f))
		restored.apply(Command.move(f))
	var s1: PackedStringArray = door.state_signature().split("||")
	var s2: PackedStringArray = restored.state_signature().split("||")
	_check(s1[0] != a[0], "30 ticks of held input moved the body (the equality below is not a no-op)")
	_check(s1[0] == s2[0] and s1[1] == s2[1] and s1[2] == s2[2] and s1[3] == s2[3] and s1[4] == s2[4] and s1[5] == s2[5] and s1[6] == s2[6],
		"...and the restored session's saved parts moved to the same place")


## The stronger half of "valid checkpoint": not just that the END state reloads, but that a save taken
## MID-RUN resumes to the same goal. The route's seam is the leg index (a delivered stack reads as
## un-mined, so the bot cannot re-derive leg progress from the pack -- `execute(anchor, from, to)` takes
## the range explicitly). Checkpoint after leg 3: ore and coal delivered, the forge holding work in
## flight -- a machine's buffers, progress and the body's position all mid-motion in the envelope.
func _test_a_mid_run_checkpoint_resumes_the_same_route_to_the_goal() -> void:
	var record: Dictionary = ScenarioRecords.RECORDS["cold_start_to_d1"]
	var booted: Dictionary = ScenarioDriver.boot(record)
	_check(bool(booted["ok"]), "the world boots for the checkpoint leg (%s)" % booted.get("reason", ""))
	if not bool(booted["ok"]):
		return
	var bot: ColdStartBot = ScenarioDriver.bot_for(record)
	bot.attach(booted["world"], booted["items"], booted["body"], booted["iface"], booted["env"])
	var first: Dictionary = bot.execute(booted["anchor"], 0, 3)
	_check(bool(first["legs_ok"]), "the first three legs ran before the checkpoint (%d ticks)" % first["ticks"])

	var env: Dictionary = Session.capture(booted["iface"])
	var restored: Interface = Session.from_save(bytes_to_var(var_to_bytes(env)))
	_check(restored != null, "the mid-run state re-loads (%s)" % SaveGame.last_invalid)
	if restored == null:
		return
	var rs: Dictionary = restored.services()
	var resumed: ColdStartBot = ScenarioDriver.bot_for(record)
	resumed.attach(rs["world"], rs["items"], rs["body"], restored, Interface.Envelope.oracle_over(rs["world"].grid))
	var second: Dictionary = resumed.execute(booted["anchor"], 3, -1)
	_check(bool(second["legs_ok"]), "the resumed route finished its legs on the restored session (%d ticks)" % second["ticks"])
	var rep: Dictionary = ScenarioDriver.await_goal(record,
		{"ok": false, "reason": "", "ticks_used": 0, "goal_event": {}, "legs_ok": true,
			"conservation_error": null, "envelope": &"oracle"}, resumed)
	_check(bool(rep["ok"]), "demand_satisfied d1 arrived on the session that lived through a save and a load (reason=%s, ticks=%d+%d)" % [rep["reason"], first["ticks"], rep["ticks_used"]])
	_check(rep["conservation_error"] == null, "conservation held across the checkpoint")
