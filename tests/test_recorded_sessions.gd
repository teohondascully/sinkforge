extends "res://tests/test_base.gd"

## Every recorded play session in `tests/body/recordings/play_*.log`, replayed and checked. Promoted from
## `tools/scratch/trace_lift.gd`, which was gitignored, ran nowhere, and had already caught three real
## defects (D0209, D0212, D0213's verification) -- every claim made from it rested on someone choosing to
## run it by hand (`docs/DECISIONS_LEDGER.md` D0228, NEEDS_DIRECTOR P002).
##
## **The ruling this encodes: a recording is BINDING until the director retires it.** If this suite ever
## fails, that is the intended outcome and the question it poses is whether the recording or the game is
## wrong -- which is a director call, not a reason to delete a log.
##
## TWO RULES CARRIED OVER FROM THE SCRATCH TOOL, both learned expensively:
##
## 1. **The air-control ratio comes from the log's OWN header, never from the current default.** A log
##    records it because it is state-affecting. `Body.AIR_CONTROL_NUM` is today's value and would
##    silently re-interpret every older session at whatever the constant happens to be -- measured once
##    as 858 bad ticks on a session that replays perfectly clean at the ratio it was actually recorded
##    under. Logs in this corpus carry 3/5, 4/5 and 5/5, so this is live, not hypothetical.
##
## 2. **`chamber=` is believed ONLY in a log that also carries `air_control=`.** One commit introduced
##    both fields; before it, `chamber=` was printed as the hardcoded literal "hostile_chamber" whatever
##    world was really played. The field is not missing in an older log, it is WRONG. Measured here:
##    `play_2026-08-30T15-46-21.log` says `hostile_chamber` and replays **855 bad ticks** there and **0**
##    on the movement course it was actually played on. A replayer that trusts the field gets a
##    plausible-looking run against the wrong world and reports its own divergence as the body's.
##
## So a pre-D0209 log is replayed against BOTH worlds and attributed to one that comes back clean. That
## is a genuinely weaker check than a believed header gets, and it is weaker in a specific way worth
## knowing: for two of the three old logs BOTH worlds replay clean, so those sessions are checked for
## "some world replays this cleanly" rather than "the world it was played in does".
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_recorded_sessions.gd

const RECORDINGS_DIR: String = "res://tests/body/recordings"
## 3, the LITERAL that shipped before D0210 raised it to 4 -- deliberately not `Body.AIR_CONTROL_NUM`.
## Writing that rule in a comment and then implementing the current default is the exact mistake rule 1
## exists to prevent, and it was made once here already.
const AIR_BEFORE_D0210: int = 3
const WORLDS: Array[String] = ["hostile_chamber", "movement_course"]


func _initialize() -> void:
	var logs: Array[String] = _recording_paths()
	_check(logs.size() > 0,
		"the corpus is non-empty -- %d play recording(s) found under %s (0 would make every assertion below vacuous)"
		% [logs.size(), RECORDINGS_DIR])
	var totals: Dictionary = {"bad": 0, "airborne": 0, "invented": 0, "climbs": 0, "ticks": 0}
	var offenders: Array[String] = []
	for path: String in logs:
		_check_one(path, totals, offenders)
	_report(logs.size(), totals, offenders)
	_finish("recorded_sessions")


func _recording_paths() -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(RECORDINGS_DIR)
	if dir == null:
		return out
	for name: String in dir.get_files():
		if name.begins_with("play_") and name.ends_with(".log"):
			out.append("%s/%s" % [RECORDINGS_DIR, name])
	out.sort()
	return out


## Header fields and input rows. Returns `believed` separately from `world`, because the difference
## between "the log says X" and "X is trustworthy" is the whole of rule 2.
func _parse(path: String) -> Dictionary:
	var rows: Array[InputFrame] = []
	var air: int = AIR_BEFORE_D0210
	var world: String = ""
	var saw_air: bool = false
	var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
	while handle != null and not handle.eof_reached():
		var line: String = handle.get_line().strip_edges()
		if line.begins_with("#"):
			if line.contains("air_control="):
				air = int(line.split("air_control=")[1].split("/")[0])
				saw_air = true
			if line.contains("chamber="):
				world = line.split("chamber=")[1].split(" ")[0]
			continue
		if line == "":
			continue
		var parts: PackedStringArray = line.split(",")
		var input: InputFrame = InputFrame.new()
		input.move_dir = int(parts[1])
		input.jump_pressed = parts[2] == "true"
		input.jump_held = parts[3] == "true"
		input.mantle_hold = parts[4] == "true"
		rows.append(input)
	if handle != null:
		handle.close()
	return {"rows": rows, "air": air, "world": world, "believed": saw_air}


func _spawn(world: String) -> Body:
	if world == "movement_course":
		return Body.new(MovementCourse.spawn_x(), MovementCourse.spawn_y())
	return Body.new(
		Fx.from_int(HostileChamber.SPAWN_START * Heightfield.TERRAIN_CELL_PX + Body.WIDTH_PX),
		Fx.from_int(HostileChamber.FLOOR_ROW * Heightfield.TERRAIN_CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2)


## One replay. `climbs` is the positive control: a harness that silently replayed nothing would report
## zero of every BAD counter and pass, so the count of step-ups and mantles is what proves the run
## happened at all.
func _replay(world: String, rows: Array[InputFrame], air: int) -> Dictionary:
	var grid: TileGrid = MovementCourse.build() if world == "movement_course" else HostileChamber.build()
	var body: Body = _spawn(world)
	body.air_control_num = air
	var counts: Dictionary = {"bad": 0, "airborne": 0, "invented": 0, "climbs": 0}
	for input: InputFrame in rows:
		var was_airborne: bool = not body.on_floor
		var before_vx: int = body.vel_x
		body.tick(input, grid)
		if body.corner_corrected_this_tick and before_vx == 0:
			counts["invented"] += 1
		if body.bounds_violation_this_tick or PropertyChecks.solid_overlap_count(body, grid) > 0:
			counts["bad"] += 1
		if body.stepped_up_this_tick or body.mantled_this_tick:
			counts["climbs"] += 1
			if was_airborne:
				counts["airborne"] += 1
	return counts


## Replays one recording and folds its numbers into `totals`. A believed header is checked against the
## world it names; an unbelievable one is attributed to whichever candidate world comes back clean.
func _check_one(path: String, totals: Dictionary, offenders: Array[String]) -> void:
	var parsed: Dictionary = _parse(path)
	var rows: Array[InputFrame] = parsed["rows"]
	var believed: bool = bool(parsed["believed"])
	var candidates: Array = [parsed["world"]] if believed else _unbelieved_order(String(parsed["world"]))
	var best: Dictionary = {}
	var best_world: String = ""
	for world: String in candidates:
		var counts: Dictionary = _replay(world, rows, int(parsed["air"]))
		# First clean candidate wins; otherwise keep the first, so an all-dirty log still reports numbers
		# rather than an empty dictionary the assertions could not read.
		if best.is_empty() or (int(best["bad"]) > 0 and int(counts["bad"]) == 0):
			best = counts
			best_world = world
		if int(best["bad"]) == 0:
			break  # a clean attribution is an answer; replaying the rest only produces noise
	var name: String = path.get_file()
	print("  [OBSERVED] %-34s %5d ticks air=%d/%d world=%-16s bad=%d airborne=%d unconsented=%d climbs=%d"
		% [name, rows.size(), parsed["air"], Body.AIR_CONTROL_DEN, best_world + ("" if believed else "*"),
		best["bad"], best["airborne"], best["invented"], best["climbs"]])
	if int(best["bad"]) > 0 or int(best["airborne"]) > 0 or int(best["invented"]) > 0:
		offenders.append("%s (%s): bad=%d airborne=%d unconsented=%d"
			% [name, best_world, best["bad"], best["airborne"], best["invented"]])
	for key: String in ["bad", "airborne", "invented", "climbs"]:
		totals[key] = int(totals[key]) + int(best[key])
	totals["ticks"] = int(totals["ticks"]) + rows.size()


## Candidate order for a log whose `chamber=` cannot be believed: **the named world goes LAST.** Not an
## optimisation dressed as a principle -- in a pre-D0209 log that field is the hardcoded literal
## "hostile_chamber", so it is the one candidate actively known to carry no information, while any other
## world is merely unconfirmed. Trying it last means a session like `play_2026-08-30T15-46-21.log`
## (855 bad ticks in the world it names, 0 in the one it was played on) finds its clean attribution
## first and never replays the wrong world at all -- which matters because replaying it emits hundreds of
## `push_error` lines into CI output, and a suite that floods a log with ERROR lines on every green run
## teaches everyone reading it to skip them.
func _unbelieved_order(named: String) -> Array[String]:
	var out: Array[String] = []
	for world: String in WORLDS:
		if world != named:
			out.append(world)
	for world: String in WORLDS:
		if world == named:
			out.append(world)
	return out


func _report(session_count: int, totals: Dictionary, offenders: Array[String]) -> void:
	print("  [OBSERVED] %d session(s), %d ticks replayed, %d climb(s) exercised"
		% [session_count, totals["ticks"], totals["climbs"]])
	# The positive control FIRST. Every assertion below is a zero-count, and a replay that did nothing at
	# all satisfies all of them -- this is the line that fails if the harness stops driving the body.
	_check(int(totals["climbs"]) > 0,
		"the corpus actually exercised the climb path -- %d step-up/mantle event(s) across %d ticks; 0 would mean every zero below was measured on a body that never moved"
		% [totals["climbs"], totals["ticks"]])
	_check(int(totals["bad"]) == 0,
		"no recorded session produces a bounds violation or a solid overlap (%d bad tick(s)%s)"
		% [totals["bad"], "" if offenders.is_empty() else "; first " + offenders[0]])
	_check(int(totals["airborne"]) == 0,
		"no recorded session climbs while airborne -- D0212's rule, held across every session the director has recorded (%d airborne climb(s))"
		% totals["airborne"])
	_check(int(totals["invented"]) == 0,
		"no recorded session produces an unconsented corner nudge -- D0213's rule, a corner correction never fires at vel_x == 0 (%d unconsented)"
		% totals["invented"])
