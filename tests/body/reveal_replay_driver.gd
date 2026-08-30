class_name RevealReplayDriver
extends RefCounted

## D0129/claims/C004. Turns a recorded `reveal_scene.gd` input log (agent- or play-mode) into the
## `Array[RevealMetric.TickEvent]` that `RevealMetric.compute()` needs -- the piece that lets C004 run
## against a real recorded session instead of only synthetic test data.
##
## The anti-cheat property (`RevealMetric`'s own docstring, D0109): the metric may only see what becomes
## available AT THE MOMENT OF A DIG, never feature location. This driver honors that by construction, not
## by convention -- it never reads the grid for anything except REPLAYING the recorded inputs through the
## real `Body.tick()`, and the only two fields it ever copies into a `TickEvent` are
## `body.dig_event_this_tick`/`body.dug_material_this_tick`, the exact same per-tick outcome flags a live
## player's own session produces. It never inspects `grid.get_material()` to check where glimmer actually
## is, never looks ahead, and never receives the target column agent-mode's own scripted approach used
## internally to decide WHERE to walk -- that decision logic lives in `reveal_scene.gd` and is not part
## of the recorded trace at all; the recording is only ever `(move_dir, jump_pressed, jump_held,
## dig_pressed)` per tick, the same four fields a keyboard could have produced.
##
## `(site, seed)` must be recoverable from the log to rebuild the identical grid the recording was played
## against (D0129 added them to `reveal_scene.gd`'s own header) -- older logs missing either field cannot
## be replayed and `parse_log` reports why rather than guessing a default that would silently replay
## against the WRONG grid.


## One fully-parsed recording: the header fields plus one `InputFrame` per recorded row, in tick order.
class ParsedLog:
	var site_id: StringName = &""
	var seed_value: int = 0
	var mode: String = ""
	var dialect: String = ""  ## the exact column-header line this log declared
	var inputs: Array[InputFrame] = []


## `reveal_scene.gd`'s own columns, in order -- the D0140 fix (queue #3 Part K): the OLD check here
## validated `fields.size() != 5` alone, which `play_scene.gd`'s own five-column dialect (`mantle_hold` in
## place of `dig_pressed`) ALSO satisfies -- arity is not schema. Confirmed still true before fixing, not
## assumed: `play_scene.gd` currently has no `site=`/`seed=` header, so today's cross-dialect read is
## accidentally blocked by an unrelated field's absence, not by design (`docs/DECISIONS_LEDGER.md` D0140's
## own "the day it reaches play_scene.gd" warning). These constants are the schema check that doesn't
## depend on that accident.
##
## TWO DIALECTS NOW, BOTH VALIDATED BY NAME (Slice 1, D0195). Cursor-aim made the aimed cell a
## state-affecting input, so a recording that cannot restate the aim cannot be replayed -- V2 carries it.
## V1 is kept readable rather than retired because six real recorded sessions exist in it, including the
## director's own; a V1 log replays with no aim and no mining, which is exactly what was played. The
## by-NAME check is what keeps this from becoming the arity trap again: 5 and 8 fields are different
## lengths today, but the rule is the header string, not the count.
const COLUMN_HEADER_V1: String = "# tick,move_dir,jump_pressed,jump_held,dig_pressed"
const COLUMN_HEADER_V2: String = "# tick,move_dir,jump_pressed,jump_held,dig_pressed,mine_held,aim_col,aim_row"
const KNOWN_HEADERS: Dictionary = {COLUMN_HEADER_V1: 5, COLUMN_HEADER_V2: 8}


## Parses a `reveal_scene.gd` recording. Returns `null` (with a `push_error`) if the header is missing
## `site=`/`seed=` -- both required to reconstruct the grid, per the docstring above -- if the column-
## header comment line doesn't name EXACTLY `EXPECTED_COLUMN_HEADER`'s five columns in this order (D0140's
## own fix, queue #3), or if any data row doesn't have exactly 5 fields. Tolerant of the mode field
## (`play` or `agent`); both share one format.
static func parse_log(path: String) -> ParsedLog:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("RevealReplayDriver: could not open %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return null
	var result: ParsedLog = ParsedLog.new()
	var found_site: bool = false
	var found_seed: bool = false
	var want_fields: int = 0  # 0 until the column header names a dialect; a row before it is a malformed log
	while not f.eof_reached():
		var line: String = f.get_line()
		if line.is_empty():
			continue
		if line.begins_with("#"):
			if " site=" in line and " seed=" in line:
				result.site_id = StringName(line.split(" site=")[1].split(" ")[0])
				result.seed_value = int(line.split(" seed=")[1].split(" ")[0])
				result.mode = line.split("mode=")[1].split(" ")[0]
				found_site = true
				found_seed = true
			elif line.begins_with("# tick,"):
				if not KNOWN_HEADERS.has(line):
					push_error("RevealReplayDriver: %s declares columns %s, which is not one of this format's own dialects (%s) -- refusing to replay a different dialect's log even though its rows may have the same field COUNT" %
						[path, line, str(KNOWN_HEADERS.keys())])
					return null
				result.dialect = line
				want_fields = int(KNOWN_HEADERS[line])
			continue
		var fields: PackedStringArray = line.split(",")
		if fields.size() != want_fields:
			push_error("RevealReplayDriver: malformed row (want %d fields for dialect %s, got %d): %s" %
				[want_fields, result.dialect, fields.size(), line])
			return null
		result.inputs.append(_row_to_input(fields, want_fields))
	f.close()
	if not (found_site and found_seed):
		push_error("RevealReplayDriver: %s has no site=/seed= header -- cannot rebuild the grid it was played against" % path)
		return null
	if want_fields == 0:
		push_error("RevealReplayDriver: %s has no recognised column-header comment line (want one of %s) -- cannot confirm this is this format's own dialect, not just a same-length one" %
			[path, str(KNOWN_HEADERS.keys())])
		return null
	return result


## One validated data row to one `InputFrame`. `want_fields` picks the dialect: the V1 five-column shape
## carries no aim and no mining hold, so a V1 log replays with `mine_held` false throughout, which is
## exactly what was played when it was recorded. Split out of `parse_log` when the two together crossed
## QUALITY gate 4's 50-line limit.
static func _row_to_input(fields: PackedStringArray, want_fields: int) -> InputFrame:
	var input: InputFrame = InputFrame.new()
	input.move_dir = int(fields[1])
	input.jump_pressed = fields[2] == "true"
	input.jump_held = fields[3] == "true"
	input.dig_pressed = fields[4] == "true"
	if want_fields == int(KNOWN_HEADERS[COLUMN_HEADER_V2]):
		input.mine_held = fields[5] == "true"
		input.aim_col = int(fields[6])
		input.aim_row = int(fields[7])
		# `has_aim` is recovered from the sentinel row rather than a ninth column: a tick with no aim
		# writes the same out-of-world value into both axes, which no real cell can occupy.
		input.has_aim = input.aim_row != DebugSceneCommon.NO_AIM_ROW
	return input


## Replays a parsed log through a freshly-built session (`RevealSessionSetup.build`, the SAME
## reconstruction `reveal_scene.gd` itself uses) and returns one `RevealMetric.TickEvent` per tick, in
## order -- exactly what a live session's own tick loop would have produced.
##
## Runs the mining verb in the same order the live scene does (body first, then mine, so the reach test
## sees this tick's own position) and reports a cursor-mine break as a dig event exactly like the
## horizontal column dig. A V1 log carries no aim, so `mine_held` is false throughout and this costs it
## nothing -- the added call cannot change what an existing recording replays to.
static func replay(parsed: ParsedLog) -> Array[RevealMetric.TickEvent]:
	var session: Dictionary = RevealSessionSetup.build(parsed.site_id, parsed.seed_value)
	var grid: TileGrid = session["grid"]
	var body: Body = session["body"]
	var mining: Mining = Mining.new()
	var events: Array[RevealMetric.TickEvent] = []
	for input: InputFrame in parsed.inputs:
		body.tick(input, grid)
		var target: Vector2i = Vector2i(input.aim_col, input.aim_row)
		mining.mine(grid, body.pos_x, body.pos_y, target, input.mine_held and input.has_aim)
		var event: RevealMetric.TickEvent = RevealMetric.TickEvent.new()
		event.dig_event = body.dig_event_this_tick or mining.broke_this_tick
		event.dug_material = body.dug_material_this_tick if body.dig_event_this_tick else mining.broke_material
		events.append(event)
	return events


## Convenience: parse + replay + compute in one call. Returns `null` if `parse_log` failed.
static func compute_from_log(path: String, reveal_material: StringName) -> Dictionary:
	var parsed: ParsedLog = parse_log(path)
	if parsed == null:
		return {}
	var events: Array[RevealMetric.TickEvent] = replay(parsed)
	return RevealMetric.compute(events, reveal_material)
