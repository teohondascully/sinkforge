extends "res://tests/test_base.gd"

## THE DECISIONS-PER-MINUTE INSTRUMENT (D0643): runs a scripted scenario through
## `ScenarioDriver.run_metered` and prints the per-minute series -- the pacing instrument the vision
## brief's minute-25 question needs ("does the density of decisions stay roughly constant as the shaft
## deepens, or does it thin out?"). A decision is one emitted `decide()` payload; `active` is the ones
## that carried a verb, `idle` the ones that decided to stand still. Leg kinds attribute each tick to
## a phase and the buckets roll that up to traversal / digging / processing / observe / idle.
##
## Run: godot --headless --path . --script res://tools/measure_decisions.gd -- <scenario> [--to-budget] [--json]
##   <scenario>     a key of `ScenarioRecords.RECORDS` (the same name `scenario_check` would take)
##   --to-budget    keep the world clock running to the record's budget after the route ends: the
##                  honest tail -- decisions stop when the policy has nothing left, ticks do not
##   --json         dump the full `decisions` report as one JSON line after the table

const TICK_HZ: int = 60


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var positional: Array[String] = []
	for a: String in args:
		if not a.begins_with("--"):
			positional.append(a)
	if positional.is_empty():
		printerr("usage: ... -- <scenario> [--to-budget] [--json]")
		quit(1)
		return
	var name: String = positional[0]
	var record: Dictionary = ScenarioRecords.RECORDS.get(name, {})
	if record.is_empty():
		printerr("unknown scenario '%s' -- ScenarioRecords.RECORDS has %s"
			% [name, str(ScenarioRecords.RECORDS.keys())])
		quit(1)
		return
	var rep: Dictionary = ScenarioDriver.run_metered(record, "--to-budget" in args)
	_report(name, record, rep)
	if "--json" in args:
		print("DECISIONS_JSON %s" % JSON.stringify(rep["decisions"]))
	var minutes: Array = rep["decisions"].get("minutes", [])
	_check(not minutes.is_empty(), "the report carries at least one minute bin")
	var totals: Dictionary = rep["decisions"].get("totals", {})
	_check(int(totals.get("decisions", 0)) > 0,
		"the meter counted at least one emitted payload -- a report of zero is a silent instrument")
	_check(int(rep.get("ticks_used", 0)) > 0, "the run advanced the world at all")
	_finish("measure_decisions")


func _report(name: String, record: Dictionary, rep: Dictionary) -> void:
	var ticks: int = int(rep["ticks_used"])
	print("=== %s (agent=%s envelope=%s of %s asked) -- %d ticks = %.1f s -- %s ==="
		% [name, record.get("agent", "?"), rep["envelope"], record.get("envelope", "oracle"), ticks,
		float(ticks) / float(TICK_HZ), rep["reason"]])
	print("  legs_ok=%s goal=%s" % [str(rep["legs_ok"]), str(rep["goal_event"])])
	var d: Dictionary = rep["decisions"]
	print("  %-6s | %-8s | %-9s | %-6s | %-4s | legs (bucket mix)" % ["minute", "ticks", "decisions",
		"active", "idle"])
	for bin: Dictionary in d.get("minutes", []):
		var leg_bits: PackedStringArray = []
		var legs: Dictionary = bin.get("legs", {})
		var leg_ticks: int = 0
		for k: StringName in legs:
			leg_ticks += int(legs[k])
			var b: StringName = DecisionMeter.bucket(k)
			leg_bits.append("%s:%d[%s]" % [k, legs[k], b])
		var unattr: int = int(bin["decisions"]) - leg_ticks
		print("  %-6d | %-8d | %-9d | %-6d | %-4d | %s%s"
			% [bin["minute"], int(bin["tick_to"]) - int(bin["tick_from"]), bin["decisions"],
			bin["active"], bin["idle"], " ".join(leg_bits),
			" (+%d unattributed)" % unattr if unattr > 0 else ""])
	var t: Dictionary = d.get("totals", {})
	print("  TOTALS decisions=%d active=%d idle=%d | decisions/min=%s active/min=%s"
		% [t.get("decisions", 0), t.get("active", 0), t.get("idle", 0),
		str(t.get("decisions_per_minute", 0.0)), str(t.get("active_per_minute", 0.0))])
	var kind_bits: PackedStringArray = []
	for k: StringName in t.get("kinds", {}):
		kind_bits.append("%s:%d" % [k, t["kinds"][k]])
	print("  kinds: %s" % " ".join(kind_bits))
	var bucket_bits: PackedStringArray = []
	for k: StringName in t.get("buckets", {}):
		bucket_bits.append("%s:%d" % [k, t["buckets"][k]])
	print("  buckets: %s" % " ".join(bucket_bits))
