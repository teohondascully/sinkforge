extends "res://tests/test_base.gd"

## The acceptance suite `docs/ARCHITECTURE.md` §9 requires: run the scripted traversal once against
## `HostileChamber`, then check every threshold against the SAME recorded run. `docs/DECISIONS_LEDGER.md`
## D0038 has the measured numbers and the reasoning behind each metric's operational definition -- §9
## states the thresholds, not how to compute them from a tick log, and that gap is a real judgment call.

const MAX_TICKS: int = 3000  ## ~50s -- generous; a controller that needs this long has already failed
## First-ever measured traverse_time becomes the golden baseline (docs/ARCHITECTURE.md §9: "within 5%
## of golden") -- there is no prior run to compare against yet. Recorded here, not computed, so a
## future regression is checked against THIS number, not against whatever a later run happens to produce.
## Measured from the first fully-passing run, once the chamber's own bugs (not body.gd's) stopped
## distorting it -- docs/DECISIONS_LEDGER.md D0038 has the full before/after.
const GOLDEN_TRAVERSE_TICKS: int = 225

var _t: Dictionary = {}  ## shared telemetry from the one recorded run, built once in _initialize()


func _initialize() -> void:
	_t = _run_traverse()
	_test_reached_the_end()
	_test_edge_catch_events_zero()
	_test_depenetration_events_zero()
	_test_velocity_efficiency()
	_test_step_up_success()
	_test_corner_correction_success()
	_test_input_latency()
	_test_stall_seconds_zero()
	_test_traverse_time_within_5_percent_of_golden()
	_finish("body_acceptance")


func _run_traverse() -> Dictionary:
	var grid: TileGrid = HostileChamber.build()
	var body: Body = Body.new(
		Fx.from_int(HostileChamber.SPAWN_START * Heightfield.TERRAIN_CELL_PX + Body.WIDTH_PX),
		Fx.from_int(HostileChamber.FLOOR_ROW * Heightfield.TERRAIN_CELL_PX) - Body.HEIGHT_PX / 2 * Fx.SCALE)
	var edge_catches: int = 0
	var depenetrations: int = 0
	var step_up_in_ledge_span: bool = false
	var corner_corrected_in_span: bool = false
	var jump_press_tick: int = -1
	var jump_took_effect_tick: int = -1
	var stall_ticks: int = 0
	var reached_end: bool = false
	var end_tick: int = -1
	var start_x: int = body.pos_x
	for tick_i: int in range(MAX_TICKS):
		var input: InputFrame = ScriptedTraverse.next_input(body, grid)
		var was_on_floor: bool = body.on_floor
		if input.jump_pressed and jump_press_tick < 0:
			jump_press_tick = tick_i
		body.tick(input, grid)
		if body.edge_caught_this_tick:
			edge_catches += 1
		if body.depenetrated_this_tick:
			depenetrations += 1
		var col: int = Body._px_to_cell(body.pos_x)
		# `col` tracks the body's centre; its leading edge -- and so the ledge contact -- reaches
		# LEDGE_START a half body-width (2 terrain cells) before the centre's own column number does.
		var half_width_cols: int = (Body.WIDTH_PX / Heightfield.TERRAIN_CELL_PX) / 2
		if col >= HostileChamber.LEDGE_START - half_width_cols and col < HostileChamber.PLATEAU_START and body.stepped_up_this_tick:
			step_up_in_ledge_span = true
		if col >= HostileChamber.PIT_START - ScriptedTraverse.JUMP_RUNWAY_COLS and col < HostileChamber.LEDGE_START and body.corner_corrected_this_tick:
			corner_corrected_in_span = true
		if jump_press_tick >= 0 and jump_took_effect_tick < 0 and was_on_floor and not body.on_floor:
			jump_took_effect_tick = tick_i
		if body.on_floor and input.move_dir != 0 and body.vel_x == 0 and tick_i > Body.GROUND_ACCEL_TICKS:
			stall_ticks += 1
		if col >= HostileChamber.END_START:
			reached_end = true
			end_tick = tick_i
			break
	return {
		"edge_catches": edge_catches, "depenetrations": depenetrations,
		"step_up_in_ledge_span": step_up_in_ledge_span, "corner_corrected_in_span": corner_corrected_in_span,
		"jump_press_tick": jump_press_tick, "jump_took_effect_tick": jump_took_effect_tick,
		"stall_ticks": stall_ticks, "reached_end": reached_end, "end_tick": end_tick,
		"start_x": start_x, "end_x": body.pos_x,
	}


func _test_reached_the_end() -> void:
	_check(_t["reached_end"], "the scripted traversal reaches the end of the chamber within %d ticks" % MAX_TICKS)


func _test_edge_catch_events_zero() -> void:
	_check(_t["edge_catches"] == 0, "edge_catch_events == 0 (got %d)" % _t["edge_catches"])


func _test_depenetration_events_zero() -> void:
	_check(_t["depenetrations"] == 0, "depenetration_events == 0 (got %d)" % _t["depenetrations"])


func _test_velocity_efficiency() -> void:
	var distance_px: float = float(_t["end_x"] - _t["start_x"]) / float(Fx.SCALE)
	var seconds: float = float(_t["end_tick"]) / float(Body.TICK_HZ)
	var ideal_px: float = float(Body.RUN_SPEED_PX_S) * seconds
	var efficiency: float = distance_px / ideal_px
	_check(efficiency >= 0.92, "velocity_efficiency >= 0.92 (got %.4f: %.1fpx in %.2fs against an ideal of %.1fpx)" %
		[efficiency, distance_px, seconds, ideal_px])


func _test_step_up_success() -> void:
	_check(_t["step_up_in_ledge_span"], "step_up_success_rate == 100%% (the one ledge in this chamber stepped up)")


func _test_corner_correction_success() -> void:
	_check(_t["corner_corrected_in_span"],
		"corner_correction_success_rate == 100%% (the one ceiling corner in this chamber corrected)")


func _test_input_latency() -> void:
	var pressed: int = _t["jump_press_tick"]
	var effect: int = _t["jump_took_effect_tick"]
	_check(pressed >= 0 and effect >= 0, "a jump was pressed and took effect during the run")
	if pressed >= 0 and effect >= 0:
		var latency: int = effect - pressed
		_check(latency <= 2, "input_to_state_change_latency <= 2 ticks (got %d)" % latency)


func _test_stall_seconds_zero() -> void:
	var stall_seconds: float = float(_t["stall_ticks"]) / float(Body.TICK_HZ)
	_check(stall_seconds == 0.0, "stall_seconds == 0 (got %.3fs, %d ticks)" % [stall_seconds, _t["stall_ticks"]])


func _test_traverse_time_within_5_percent_of_golden() -> void:
	var ticks: int = _t["end_tick"]
	var tolerance: int = int(ceil(float(GOLDEN_TRAVERSE_TICKS) * 0.05))
	_check(absi(ticks - GOLDEN_TRAVERSE_TICKS) <= tolerance,
		"traverse_time within 5%% of golden (%d ticks, golden %d, tolerance +/-%d, got %d)" %
		[ticks, GOLDEN_TRAVERSE_TICKS, tolerance, ticks])
