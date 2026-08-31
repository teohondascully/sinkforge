extends "res://tests/test_base.gd"

## D0129/claims/C004. Proves `RevealReplayDriver` reconstructs a session bit-for-bit from its own
## recorded input log -- not that any particular measured lift is meaningful, which is a SEPARATE claim
## this file deliberately does not make (the tautology class named at D0118: a synthetic trace passing
## proves the PLUMBING, not that the reveal layer itself is proven). The trace here is agent-generated
## (scripted move+dig, same shape as `reveal_scene.gd`'s own agent mode), not real human play -- real-
## human validation of claims/C004 is still owed and is explicitly NOT what this file claims to close.

const SITE_ID: StringName = &"reveal_test_dense"
## RE-PINNED 2026-08-31 (D0256). Was 20260826, the director's own seed, which produced a qualifying
## reveal until D0254 stopped `ValueNoise` truncating the seed to 16 bits and thereby changed every
## generated world. It now digs 6 times at its target column and hits glimmer 0 times.
##
## The re-pick is measured, not guessed: 59 seeds were scanned end-to-end through this file's own
## scripted trace, and **37 of them (63%) produce at least one qualifying reveal**. Seed 8 gives four,
## with `target_glimmer_col = 9` -- deliberately not one of the many seeds whose target lands on column 6,
## because that is the `MIN_SPAWN_COL` clamp case D0192 measured as the distribution's MODE (53.2% of
## seeds spawn flush), and a fixture sitting on the degenerate spawn tests less than one that does not.
##
## READ THIS BEFORE RE-PINNING AGAIN. That 37/59 is the real finding here: this fixture is a dice roll
## that ANY change to terrain generation re-rolls, because `RevealSessionSetup.find_spawn` picks the first
## shallow glimmer COLUMN and the scripted approach digs at the body's own ROW -- nothing makes the two
## meet. The seed is the workaround; selecting a target the approach can actually reach is the fix, and it
## is parked rather than done here because `find_spawn` is shared with `reveal_scene.gd`'s live spawn.
const SEED_VALUE: int = 8
const IDLE_BEFORE: int = 350  ## padding so a reveal mid-approach sits inside a full WINDOW_TICKS(300) span
const IDLE_AFTER: int = 350
const APPROACH_CAP: int = 200  ## generous; the real approach only needs ~6 columns' worth of movement


func _initialize() -> void:
	_test_replay_matches_a_live_session_tick_for_tick()
	_test_compute_from_log_runs_end_to_end()
	_test_parse_log_rejects_a_header_missing_site_or_seed()
	_test_parse_log_rejects_a_malformed_row()
	_test_parse_log_rejects_a_different_dialect_with_matching_field_count()
	_test_a_log_replays_at_the_bite_radius_it_names_and_a_silent_log_at_the_control()
	_finish("reveal_replay_driver")


## Builds one scripted session TWICE from the same `(site, seed)` -- once driven live, once replayed from
## a log recorded from the first run -- and asserts every tick's `(dig_event, dug_material)` matches
## exactly. This is the actual plumbing claim: a replay reconstructing even a slightly different grid or
## spawn position than the session that produced the recording would diverge, likely within a few ticks.
func _test_replay_matches_a_live_session_tick_for_tick() -> void:
	var session: Dictionary = RevealSessionSetup.build(SITE_ID, SEED_VALUE)
	var grid: TileGrid = session["grid"]
	var body: Body = session["body"]
	var target_col: int = session["target_glimmer_col"]
	_check(target_col >= 0, "sanity: %s/seed=%d places a shallow glimmer pocket this scripted approach can reach" %
		[SITE_ID, SEED_VALUE])

	var recorded_rows: Array[PackedStringArray] = []
	var live_events: Array[RevealMetric.TickEvent] = []
	_run_scripted_trace(body, grid, target_col, recorded_rows, live_events)
	var log_path: String = "user://test_reveal_replay_%d.log" % Time.get_ticks_usec()
	_write_log(log_path, recorded_rows)

	var parsed: RevealReplayDriver.ParsedLog = RevealReplayDriver.parse_log(log_path)
	_check(parsed != null, "the log this test just wrote parses cleanly")
	_check(parsed.site_id == SITE_ID and parsed.seed_value == SEED_VALUE,
		"parsed header recovers the exact site/seed this test recorded (got %s/%d)" % [parsed.site_id, parsed.seed_value])
	_check(parsed.inputs.size() == live_events.size(),
		"parsed tick count matches the live session's own tick count (got %d, want %d)" %
		[parsed.inputs.size(), live_events.size()])

	var replayed_events: Array[RevealMetric.TickEvent] = RevealReplayDriver.replay(parsed)
	var mismatches: int = 0
	for i: int in mini(live_events.size(), replayed_events.size()):
		if live_events[i].dig_event != replayed_events[i].dig_event or live_events[i].dug_material != replayed_events[i].dug_material:
			mismatches += 1
	_check(mismatches == 0, "every tick's (dig_event, dug_material) matches exactly between the live run and its own replay (%d/%d mismatched)" %
		[mismatches, live_events.size()])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))


## End-to-end through the convenience function, on the SAME kind of session -- proves `compute_from_log`
## (parse + replay + `RevealMetric.compute` in one call) doesn't crash and produces a well-formed result,
## including (this site/seed/approach reliably crosses a shallow glimmer pocket with 350-tick padding on
## both sides) at least one qualifying reveal, so the lift-computation branch is actually exercised, not
## just the `qualifying_reveals == 0` early return.
func _test_compute_from_log_runs_end_to_end() -> void:
	var session: Dictionary = RevealSessionSetup.build(SITE_ID, SEED_VALUE)
	var grid: TileGrid = session["grid"]
	var body: Body = session["body"]
	var target_col: int = session["target_glimmer_col"]
	var recorded_rows: Array[PackedStringArray] = []
	_run_scripted_trace(body, grid, target_col, recorded_rows, [])
	var log_path: String = "user://test_reveal_replay_e2e_%d.log" % Time.get_ticks_usec()
	_write_log(log_path, recorded_rows)

	var result: Dictionary = RevealReplayDriver.compute_from_log(log_path, &"glimmer")
	_check(not result.is_empty(), "compute_from_log returns a real result, not the empty-dict parse-failure sentinel")
	_check(result.get("total_ticks", -1) == recorded_rows.size(),
		"the computed total_ticks matches the recorded session length (got %s, want %d)" %
		[result.get("total_ticks"), recorded_rows.size()])
	_check(result.get("dig_events", -1) > 0, "the scripted approach actually fired real dig events (got %s)" % result.get("dig_events"))
	_check(result.get("qualifying_reveals", -1) > 0,
		"this site/seed/padding reliably produces at least one qualifying reveal, exercising the lift branch (got %s)" %
		result.get("qualifying_reveals"))
	_check(result.has("lift"), "a qualifying reveal means 'lift' is present, not the qualifying_reveals==0 early return")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))


func _test_parse_log_rejects_a_header_missing_site_or_seed() -> void:
	var log_path: String = "user://test_reveal_replay_bad_header_%d.log" % Time.get_ticks_usec()
	var f: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
	f.store_line("# sinkforge reveal-scene input recording -- mode=agent ticks=1")  # no site=/seed=
	f.store_line("# tick,move_dir,jump_pressed,jump_held,dig_pressed")
	f.store_line("0,0,false,false,false")
	f.close()
	var parsed: RevealReplayDriver.ParsedLog = RevealReplayDriver.parse_log(log_path)
	_check(parsed == null, "a header missing site=/seed= is rejected, not silently replayed against a wrong default grid")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))


## D0140's own scenario, reproduced directly: `play_scene.gd`'s five-column dialect (`mantle_hold` in
## the fifth column, not `dig_pressed`) IF it ever also gained a `site=`/`seed=` header -- same field
## COUNT as this format's own, which is exactly why an arity-only check couldn't see the difference
## (queue #3 Part K's own fix). Confirmed BEFORE this fix landed that the old check silently accepted
## this file and replayed `mantle_hold=true` as `dig_pressed=true` -- this test is the permanent guard
## against that regression recurring.
func _test_parse_log_rejects_a_different_dialect_with_matching_field_count() -> void:
	var log_path: String = "user://test_reveal_replay_dialect_%d.log" % Time.get_ticks_usec()
	var f: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
	f.store_line("# sinkforge input recording -- mode=play site=%s seed=%d ticks=1" % [SITE_ID, SEED_VALUE])
	f.store_line("# tick,move_dir,jump_pressed,jump_held,mantle_hold")  # play_scene.gd's own dialect
	f.store_line("0,1,false,false,true")
	f.close()
	var parsed: RevealReplayDriver.ParsedLog = RevealReplayDriver.parse_log(log_path)
	_check(parsed == null,
		"a differently-named fifth column (mantle_hold, not dig_pressed) is rejected even with a matching " +
		"field count and a valid site=/seed= header -- arity alone must never be schema")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))


## An EXTRA field, not a missing one: a row with fewer than 5 fields makes `parse_log`'s own
## `fields[4]` read go out of bounds, which aborts the function with a script error and returns `null`
## anyway -- coincidentally "correct" even if the explicit field-count check were deleted entirely, which
## would make this test pass for the wrong reason (found by mutation-testing the check and seeing this
## still incidentally pass). A 6-field row hits no such crash -- `fields[0..4]` all exist -- so only the
## explicit size check stands between it and being silently accepted.
func _test_parse_log_rejects_a_malformed_row() -> void:
	var log_path: String = "user://test_reveal_replay_bad_row_%d.log" % Time.get_ticks_usec()
	var f: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
	f.store_line("# sinkforge reveal-scene input recording -- mode=agent ticks=1 site=%s seed=%d" % [SITE_ID, SEED_VALUE])
	f.store_line("# tick,move_dir,jump_pressed,jump_held,dig_pressed")
	f.store_line("0,0,false,false,false,extra")  # one field too many
	f.close()
	var parsed: RevealReplayDriver.ParsedLog = RevealReplayDriver.parse_log(log_path)
	_check(parsed == null, "a data row with the wrong field count is rejected, not silently accepted with the extra field ignored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))


## Ticks the body once, records the row, and appends the live TickEvent to `events` -- pass `[]` when the
## caller (like the end-to-end test below) doesn't need the live comparison array, since nothing reads it.
func _step(body: Body, grid: TileGrid, input: InputFrame, tick: int, rows: Array[PackedStringArray], events: Array) -> void:
	rows.append(DebugSceneCommon.record_row(tick, input.move_dir, input.jump_pressed, input.jump_held, input.dig_pressed))
	body.tick(input, grid)
	var event: RevealMetric.TickEvent = RevealMetric.TickEvent.new()
	event.dig_event = body.dig_event_this_tick
	event.dug_material = body.dug_material_this_tick
	events.append(event)


## Shared by both real-session tests: `IDLE_BEFORE` idle ticks, then move-right-and-dig until reaching
## `target_col` (or `APPROACH_CAP`, asserted below), then `IDLE_AFTER` idle ticks -- the same shape
## `reveal_scene.gd`'s own agent mode uses, scripted rather than reactive since the exact tick count needs
## to be known up front to pad a full `RevealMetric.WINDOW_TICKS` span on both sides of the reveal.
func _run_scripted_trace(body: Body, grid: TileGrid, target_col: int, rows: Array[PackedStringArray], events: Array) -> void:
	var tick: int = 0
	for _i: int in IDLE_BEFORE:
		_step(body, grid, InputFrame.new(), tick, rows, events)
		tick += 1
	var approach_ticks: int = 0
	while Body._px_to_cell(body.pos_x) < target_col and approach_ticks < APPROACH_CAP:
		var dig_input: InputFrame = InputFrame.new()
		dig_input.move_dir = 1
		dig_input.dig_pressed = true
		_step(body, grid, dig_input, tick, rows, events)
		tick += 1
		approach_ticks += 1
	_check(approach_ticks < APPROACH_CAP, "sanity: the scripted approach reaches the target column within the cap (used %d/%d)" %
		[approach_ticks, APPROACH_CAP])
	for _i: int in IDLE_AFTER:
		_step(body, grid, InputFrame.new(), tick, rows, events)
		tick += 1


## The standard `reveal_scene.gd` recording format, `site=`/`seed=` header included (D0129) -- shared so a
## future format change only needs updating here, not at every call site.
func _write_log(path: String, rows: Array[PackedStringArray]) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_line("# sinkforge reveal-scene input recording -- mode=agent ticks=%d site=%s seed=%d" %
		[rows.size(), SITE_ID, SEED_VALUE])
	f.store_line("# tick,move_dir,jump_pressed,jump_held,dig_pressed")
	for row: PackedStringArray in rows:
		f.store_line(",".join(row))
	f.close()


## D0200. The bite radius is as load-bearing as `site=`/`seed=`: the same inputs at a different radius
## diverge on the first break. Two claims, and the SECOND is the one that protects existing evidence --
## a log with no `bite=` field was recorded before the probe, so it must reconstruct at
## `CONTROL_BITE_RADIUS`, not at whatever `Mining` currently defaults to. Six committed recordings and
## every C004 number ever computed from them depend on that default being the OLD behaviour rather than
## the NEW one; defaulting the other way would silently restate history in the present tense.
func _test_a_log_replays_at_the_bite_radius_it_names_and_a_silent_log_at_the_control() -> void:
	var cases: Array = [
		{"suffix": "", "want": Mining.CONTROL_BITE_RADIUS, "label": "a log with NO bite= field (pre-probe)"},
		{"suffix": " bite=0", "want": 0, "label": "a log naming bite=0"},
		{"suffix": " bite=2", "want": 2, "label": "a log naming bite=2"},
		{"suffix": " bite=3", "want": 3, "label": "a log naming bite=3"},
	]
	for case: Dictionary in cases:
		var log_path: String = "user://test_reveal_replay_bite_%d.log" % Time.get_ticks_usec()
		var f: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
		f.store_line("# sinkforge reveal-scene input recording -- mode=agent ticks=1 site=%s seed=%d%s"
			% [SITE_ID, SEED_VALUE, case["suffix"]])
		f.store_line(RevealReplayDriver.COLUMN_HEADER_V1)
		f.store_line("0,0,false,false,false")
		f.close()
		var parsed: RevealReplayDriver.ParsedLog = RevealReplayDriver.parse_log(log_path)
		_check(parsed != null and parsed.bite_radius == int(case["want"]),
			"%s reconstructs at radius %d (got %s)"
			% [case["label"], case["want"], "null" if parsed == null else str(parsed.bite_radius)])
		DirAccess.remove_absolute(ProjectSettings.globalize_path(log_path))
	# `seed=` sits immediately before `bite=` in the real header, so the seed parse has to stop at the
	# space rather than swallowing the rest of the line -- an off-by-one there would replay a seed of
	# `20260826 bite=2`, which `int()` would quietly truncate back to the right number and hide itself.
	var probe: String = "# sinkforge reveal-scene input recording -- mode=play ticks=9 site=%s seed=%d bite=2" % [SITE_ID, SEED_VALUE]
	var log2: String = "user://test_reveal_replay_bite_order_%d.log" % Time.get_ticks_usec()
	var g: FileAccess = FileAccess.open(log2, FileAccess.WRITE)
	g.store_line(probe)
	g.store_line(RevealReplayDriver.COLUMN_HEADER_V1)
	g.store_line("0,0,false,false,false")
	g.close()
	var p2: RevealReplayDriver.ParsedLog = RevealReplayDriver.parse_log(log2)
	_check(p2 != null and p2.seed_value == SEED_VALUE and p2.mode == "play" and p2.bite_radius == 2,
		"a full real-shaped header parses seed, mode and bite independently of their order (%s)"
		% ("null" if p2 == null else "seed=%d mode=%s bite=%d" % [p2.seed_value, p2.mode, p2.bite_radius]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(log2))
