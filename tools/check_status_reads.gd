extends "res://tools/check_base.gd"

## EVERY STATUS THE SIM CAN REPORT MUST HAVE A LOOK, AND NO LOOK MAY EXIST FOR A STATUS IT CANNOT.
##
## This layer exists because the gap it checks was real and shipping. `FactorySim.machine_status` can return
## ten different statuses. The renderer's status lamp matched on five and swept the rest into the `_` arm,
## which is the grey that means "idle — nothing is wrong here". So a drill whose ore had no drain below it,
## a Drift Rig with a jammed pay column, a rig with a jammed spoil column, an unpowered crusher and a Spur
## wired to nothing ALL displayed the everything-is-fine lamp. Then, because they were not literally the
## string `idle`, they fell past the early return into the need bubble — which can only draw an item, so it
## drew its default — and floated an ORE icon over a machine whose actual problem was that it had no power.
##
## That is worse than an unhandled state. An unhandled state is silent; this one gave a confident wrong
## answer and sent the player to fix something that was not broken.
##
## Nothing in the suite could have caught it. Every pixel test was green, because the lamp rendered fine.
## The sim's own tests were green, because the sim was right. The defect lived precisely in the JOIN between
## a vocabulary defined in one file and a match statement written in another, which is the one place no test
## that looks at either file alone can see.
##
## HOW THE SIM'S VOCABULARY IS DISCOVERED. By reading its source. There is no runtime registry of statuses —
## they are string literals returned from `machine_status` and the nine `_status_*` helpers it dispatches to
## — and inventing one would just move the drift somewhere else, since nothing would force a new helper to
## use it. Reading the source is the only method that cannot be satisfied by a stale copy.
##
## THE CHECK IS BIDIRECTIONAL, and that is what keeps the scanner honest:
##
##   every sim status has a look     the drift that shipped. A new `_status_*` arm goes red here.
##   every look is a sim status      the reverse drift — a table entry for a status that no longer exists,
##                                   which is dead code that reads like coverage. It ALSO means a scanner
##                                   that silently found nothing fails immediately with ten dead entries,
##                                   rather than passing this layer with an empty set and proving nothing.
##
## AND THE RULE ON MARKS. Status is drawn twice, as colour and as geometry, because green-working against
## red-no-fuel is the most common colour confusion there is and amber-starved joins them. Redundancy is only
## redundancy if the second channel separates the things the first one merges, so: two statuses that call
## for DIFFERENT fixes must never share a mark. Two that call for the same fix may — `no_fuel` and
## `no_input` are both "put something in", and which something is the need bubble's job.
##
## Runs headless: it reads a file and a Dictionary.
##
##   godot --headless --path . --script res://tools/check_status_reads.gd

const SIM_SRC: String = "res://src/core/factory_sim.gd"
## Statuses come from `machine_status` itself and from the `_status_*` helpers `_BEHAVIORS` dispatches to.
## Other functions in the file return StringNames too — `mine()` and `take_lode()` return MATERIALS — so the
## scan is scoped by enclosing function rather than grepping the whole file for quoted names.
const STATUS_FN: String = "_status_"


func _initialize() -> void:
	print("== every status the sim can report has a look ==")
	_run()
	_verdict("check_status_reads", "the sim's vocabulary and the renderer's table are the same set")


func _run() -> void:
	var reported: Array[StringName] = _scan_sim_statuses()
	var table: Array = Visuals.STATUS_LOOK.keys()

	# --- the drift that shipped ---
	var missing: Array[String] = []
	for s: StringName in reported:
		if not Visuals.STATUS_LOOK.has(s):
			missing.append(String(s))
	_check(missing.is_empty(),
		"all %d statuses the sim can report have a look%s"
			% [reported.size(), "" if missing.is_empty() else " — UNHANDLED: " + ", ".join(missing)])

	# --- the reverse drift, which is also what proves the scanner ran ---
	var dead: Array[String] = []
	for s: Variant in table:
		if not reported.has(StringName(s)):
			dead.append(String(s))
	_check(dead.is_empty(),
		"no look describes a status the sim cannot return%s"
			% ["" if dead.is_empty() else " — DEAD: " + ", ".join(dead)])

	# --- the redundancy rule: a different job must never wear the same mark ---
	var clashes: Array[String] = []
	for a: Variant in table:
		for b: Variant in table:
			if String(a) >= String(b):
				continue
			var la: Dictionary = Visuals.STATUS_LOOK[a]
			var lb: Dictionary = Visuals.STATUS_LOOK[b]
			if la["mark"] == lb["mark"] and la["fix"] != lb["fix"]:
				clashes.append("%s/%s both draw %s but want %s vs %s"
					% [a, b, la["mark"], la["fix"], lb["fix"]])
	_check(clashes.is_empty(),
		"no two different jobs share a mark%s"
			% ["" if clashes.is_empty() else " — " + "; ".join(clashes)])

	# --- the bubble may only speak when it has something true to say ---
	# It can draw an ITEM and nothing else. A status whose fix is power, a jam or wiring has no item to hold
	# up, and the code that used to reach the bubble in those states invented one.
	var liars: Array[String] = []
	for s: Variant in table:
		var look: Dictionary = Visuals.STATUS_LOOK[s]
		if bool(look["feeds"]) and StringName(look["fix"]) != &"feed":
			liars.append("%s feeds a bubble but its fix is %s" % [s, look["fix"]])
	_check(liars.is_empty(),
		"the need bubble only appears where an item is the answer%s"
			% ["" if liars.is_empty() else " — " + "; ".join(liars)])

	# --- every entry is complete, since a half-filled row would crash the renderer mid-draw ---
	var ragged: Array[String] = []
	for s: Variant in table:
		var look: Dictionary = Visuals.STATUS_LOOK[s]
		for key: String in ["color", "mark", "fix", "feeds"]:
			if not look.has(key):
				ragged.append("%s has no %s" % [s, key])
	_check(ragged.is_empty(),
		"every look carries colour, mark, fix and feeds%s"
			% ["" if ragged.is_empty() else " — " + "; ".join(ragged)])

	# NON-VACUITY. Every assertion above is satisfied perfectly by a scan that found nothing and a table
	# that is empty — which is exactly what a broken regex produces. It is also satisfied by ten statuses
	# that all wear the identical mark. So: the vocabulary must be large, and it must be VARIED.
	_check(reported.size() >= 8, "the scan read %d statuses out of the sim" % reported.size())
	var marks: Dictionary = {}
	var fixes: Dictionary = {}
	for s: Variant in table:
		marks[(Visuals.STATUS_LOOK[s] as Dictionary)["mark"]] = true
		fixes[(Visuals.STATUS_LOOK[s] as Dictionary)["fix"]] = true
	_check(marks.size() >= 5,
		"the statuses wear %d different marks, so the geometry channel carries real information"
			% marks.size())
	print("  %d statuses, %d marks, %d distinct jobs" % [reported.size(), marks.size(), fixes.size()])


## Every status literal returned from `machine_status` or a `_status_*` helper, by reading the sim's source.
func _scan_sim_statuses() -> Array[StringName]:
	var f: FileAccess = FileAccess.open(SIM_SRC, FileAccess.READ)
	if f == null:
		_check(false, "the sim source is readable at %s" % SIM_SRC)
		return ([] as Array[StringName])
	var out: Array[StringName] = []
	var in_status: bool = false
	var lit := RegEx.new()
	lit.compile("&\"([a-z_]+)\"")
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.begins_with("func "):
			var name: String = line.substr(5).split("(")[0]
			in_status = name == "machine_status" or name.begins_with(STATUS_FN)
		if not in_status or line.find("return ") < 0:
			continue
		for m: RegExMatch in lit.search_all(line):
			var s := StringName(m.get_string(1))
			if not out.has(s):
				out.append(s)
	f.close()
	return out
