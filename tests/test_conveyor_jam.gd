extends "res://tests/test_base.gd"

## C005's executable core (D0645): the scenario record `scenarios/conveyor_jam.yaml` runs
## `ConveyorBot` over the `conveyor_probe` fixture -- a capped bore with a supply pile on its cap and
## a placed-instance `intake: jam` forge at its foot. The claim's two beats are read off the run's own
## channels, not narrated: the pile's ore and coal land in the forge's intake via `o.flow_events`
## after the cap is dug out from under them (the hole is the conveyor), and the clay the route tosses
## down the same column leaves the machine's status `blocked` with the clay still in the intake (the
## first self-inflicted jam). A `pass`-intake mutation of the same placed machine is the control: the
## same run does not jam, which is what makes the blocked reading mean the intake rule.


func _initialize() -> void:
	_test_the_fixture_stamps_the_jam_variant_on_the_placed_instance()
	_test_the_dug_column_carries_the_pile_into_the_forge_then_the_clay_jams_it()
	_test_the_same_run_with_a_pass_intake_does_not_jam()
	_finish("conveyor_jam")


## The fixture half of the sim support: `machine ... intake: jam` lands on the placed instance only,
## and the save carries it -- a reload keeps the variant, an older save without the field keeps the
## def's rule.
func _test_the_fixture_stamps_the_jam_variant_on_the_placed_instance() -> void:
	var booted: Dictionary = ScenarioDriver.boot(ScenarioRecords.RECORDS["conveyor_jam"])
	_check(bool(booted["ok"]), "the conveyor_probe world boots (%s)" % booted.get("reason", ""))
	if not bool(booted["ok"]):
		return
	var forge_cell := Vector2i(35, 27)
	var machines: Machines = booted["machines"]
	var forge: MachineState = null
	for m: MachineState in machines.machines:
		if m.logic_cell == forge_cell:
			forge = m
	_check(forge != null, "the fixture placed a machine at the bore's foot %s" % str(forge_cell))
	if forge == null:
		return
	_check(forge.intake == &"jam", "the placed instance carries the fixture's intake override (%s)" % forge.intake)
	_check(forge.def.intake == &"pass", "the shipped record itself still reads pass (%s)" % forge.def.intake)

	var env: Dictionary = Session.capture(booted["iface"])
	var restored: Interface = Session.from_save(bytes_to_var(var_to_bytes(env)))
	_check(restored != null, "the stamped world saves and reloads (%s)" % SaveGame.last_invalid)
	if restored == null:
		return
	var re_forge: MachineState = null
	for m: MachineState in restored.services()["machines"].machines:
		if m.logic_cell == forge_cell:
			re_forge = m
	_check(re_forge != null and re_forge.intake == &"jam",
		"the intake override survives the save/load round trip")


## The claim itself: dig the cap out from under the pile and the pile rides the column into the
## forge's intake (flow events), the forge works (status), then the tossed clay jams it (blocked).
func _test_the_dug_column_carries_the_pile_into_the_forge_then_the_clay_jams_it() -> void:
	var record: Dictionary = ScenarioRecords.RECORDS["conveyor_jam"]
	var rep: Dictionary = ScenarioDriver.run_metered(record)
	_check(bool(rep["legs_ok"]), "every leg of the conveyor route completed (reason=%s, ticks=%d)"
		% [rep["reason"], rep["ticks_used"]])
	_check(bool(rep["ok"]), "the forge read `blocked` -- the claim's goal (reason=%s)" % rep["reason"])
	_check(rep["conservation_error"] == null, "item conservation held over the whole run")

	var forge_cell := Vector2i(35, 27)
	var fed: Dictionary = {}
	var jam_fed: Dictionary = {}
	var flow_bits: PackedStringArray = []
	for ev: Dictionary in rep["flow_events"]:
		flow_bits.append("%s %s->%s" % [ev.get("item"), str(ev.get("from")), str(ev.get("to"))])
		if ev.get("to") == forge_cell:
			fed[ev["item"]] = true
			if ev["item"] == &"clay":
				jam_fed = ev
	_check(fed.has(&"ore") and fed.has(&"coal"),
		"the pile's ore and coal landed in the forge's intake through the dug column (%s)"
		% " | ".join(flow_bits))
	_check(not jam_fed.is_empty(), "the tossed clay landed in the same intake (%s)" % str(jam_fed))

	var notes: Array = rep["notes"]
	var working_note: Dictionary = _note(notes, "forge_working")
	var jam_note: Dictionary = _note(notes, "forge_jammed")
	_check(not working_note.is_empty() and not jam_note.is_empty(),
		"the route left its two evidence notes (got %d)" % notes.size())
	var wforge: Dictionary = (working_note.get("machines", {}) as Dictionary).get(forge_cell, {})
	_check(wforge.get("status") == &"working",
		"before the junk, the fed forge read working (%s)" % str(wforge.get("status")))
	var jforge: Dictionary = (jam_note.get("machines", {}) as Dictionary).get(forge_cell, {})
	_check(jforge.get("status") == &"blocked",
		"after the clay, the forge read blocked (%s)" % str(jforge.get("status")))
	_check(int((jforge.get("input", {}) as Dictionary).get(&"clay", 0)) == 1,
		"...with the clay still sitting in the intake (%s)" % str(jforge.get("input")))


## The control that makes `blocked` mean the intake rule: the SAME route and geometry with the placed
## machine's override flipped to `pass` swallows the clay and keeps working. If a future change jams
## the run for another reason (geometry, drop path), this leg -- not the claim's -- goes red with it.
func _test_the_same_run_with_a_pass_intake_does_not_jam() -> void:
	var record: Dictionary = ScenarioRecords.RECORDS["conveyor_jam"].duplicate(true)
	record["budget_ticks"] = 2400   # the control run only needs the route, not the goal watch's tail
	var booted: Dictionary = ScenarioDriver.boot(record)
	_check(bool(booted["ok"]), "the control world boots (%s)" % booted.get("reason", ""))
	if not bool(booted["ok"]):
		return
	for m: MachineState in (booted["machines"] as Machines).machines:
		m.intake = &"pass"   # the mutation: same world, same route, the record's own rule restored

	var bot: RouteBot = ScenarioDriver.bot_for(record)
	bot.attach(booted["world"], booted["items"], booted["body"], booted["iface"], booted["env"])
	bot.begin(booted["anchor"])
	var forge_cell := Vector2i(35, 27)
	var saw_blocked: bool = false
	var last_input: Dictionary = {}
	var budget: int = int(record["budget_ticks"])
	while not bot.legs_done() and bot.ticks < budget:
		bot.step()
		var o: Interface.Observation = bot.iface.observe(bot.env)
		for rec: Dictionary in o.machines:
			if rec.get("cell") == forge_cell:
				saw_blocked = saw_blocked or rec.get("status") == &"blocked"
				last_input = rec.get("input", {})
	for _i: int in 240:   # a few seconds of settling past the route, still observed
		bot.tick(0)
		var o2: Interface.Observation = bot.iface.observe(bot.env)
		for rec: Dictionary in o2.machines:
			if rec.get("cell") == forge_cell:
				saw_blocked = saw_blocked or rec.get("status") == &"blocked"
				last_input = rec.get("input", {})
	_check(not saw_blocked, "pass control: the forge never read blocked on the same run")
	_check(int(last_input.get(&"clay", 0)) == 0,
		"pass control: the clay passed through and out of the intake (%s)" % str(last_input))


static func _note(notes: Array, key: String) -> Dictionary:
	for n: Dictionary in notes:
		if n.get("key") == key:
			return n
	return {}
