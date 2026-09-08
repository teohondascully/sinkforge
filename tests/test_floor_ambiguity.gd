extends "res://tests/test_base.gd"

## WHAT "AMBIGUOUS FLOOR SELECTION" MEANS, AND WHAT IT DOES NOT (D0516). `Invariants.check_floor_selection`
## reports the resolver choosing between two standing surfaces its feet had BOTH reached -- the only case
## in which the surface it did not pick could have been the right floor, because `resolve_floor` never
## lands on a surface the feet have not reached (`_bottom_y() < surface`, D0044's own verification).
## Before D0516 it reported any second walkable pocket within the 48-row scan window, which is a census
## of the terrain and not a property of the choice: every stranger seat logged it 40-190 times a session
## standing on the tutorial pad over the pockets the world seeder authors beneath it, with no wrong floor
## in any of them. `tests/test_cave_geometry.gd` keeps the shelf-over-a-pocket case as the negative;
## this file owns the positive, the controls that separate the bound from the window, the real body
## through `tick()`, the caller's rate limit (D0052, moved here with its probe), and the seeded opening
## walk whose count is the ledger's number.

const Probe = preload("res://tests/fixture_settle_violation_probe.gd")
const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_two_surfaces_a_cell_apart_both_reached_fire()
	_test_the_same_surfaces_with_only_the_shelf_reached_are_silent()
	_test_a_thick_floors_interior_is_not_a_second_surface()
	_test_a_pocket_sixteen_rows_down_is_silenced_by_the_reach_not_the_window()
	_test_a_real_embedded_body_trips_the_guard_through_tick()
	_test_a_real_body_standing_on_the_shelf_is_silent_through_tick()
	_test_a_held_ambiguity_is_reported_once()
	_test_the_seeded_opening_walk_reports_nothing()
	_finish("floor_ambiguity")


## The scan window `resolve_floor` computes for feet in `feet_row`: two rows of lookback.
func _scan_from(feet_row: int) -> int:
	return maxi(0, feet_row - 2)


func _test_two_surfaces_a_cell_apart_both_reached_fire() -> void:
	var grid: TileGrid = Probe.build_grid()
	var col: int = Probe.WIDTH_COLS / 2
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, _scan_from(Probe.FLOOR_ROW), Body.FLOOR_SCAN_ROWS, Probe.LEDGE_ROW, Probe.FLOOR_ROW)
	_check(v != null,
		"a shelf at row %d and a floor at row %d, the feet at row %d having reached both: the check fires (the resolver took the shelf; the floor was the other candidate)" %
		[Probe.LEDGE_ROW, Probe.FLOOR_ROW, Probe.FLOOR_ROW])
	if v != null:
		_check(v.chosen_floor_row == Probe.LEDGE_ROW and v.competing_floor_row == Probe.FLOOR_ROW,
			"and names the pair: chosen %d, competing %d (got %d, %d)" %
			[Probe.LEDGE_ROW, Probe.FLOOR_ROW, v.chosen_floor_row, v.competing_floor_row])


func _test_the_same_surfaces_with_only_the_shelf_reached_are_silent() -> void:
	var grid: TileGrid = Probe.build_grid()
	var col: int = Probe.WIDTH_COLS / 2
	var standing: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, _scan_from(Probe.LEDGE_ROW), Body.FLOOR_SCAN_ROWS, Probe.LEDGE_ROW, Probe.LEDGE_ROW)
	_check(standing == null,
		"the identical two surfaces with the feet ON the shelf (reach row %d): silent -- the floor two rows down is below the feet, so it was never a candidate" % Probe.LEDGE_ROW)
	var hanging: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, _scan_from(Probe.LEDGE_ROW + 1), Body.FLOOR_SCAN_ROWS, Probe.LEDGE_ROW, Probe.LEDGE_ROW + 1)
	_check(hanging == null,
		"feet one row into the open cell (reach row %d), the floor's top face still one row below them: silent -- reached means AT OR ABOVE the feet, not within a row of them" % (Probe.LEDGE_ROW + 1))


func _test_a_thick_floors_interior_is_not_a_second_surface() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_START + 2   ## plain tunnel: one six-row slab, nothing under it in reach
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, _scan_from(HostileChamber.CAVE_FLOOR_ROW + 2), Body.FLOOR_SCAN_ROWS,
		HostileChamber.CAVE_FLOOR_ROW, HostileChamber.CAVE_FLOOR_ROW + 2)
	_check(v == null,
		"feet two rows INTO a six-row slab (reach row %d, slab top %d): silent -- rows %d and %d are the slab's interior, a surface needs an open cell above it" %
		[HostileChamber.CAVE_FLOOR_ROW + 2, HostileChamber.CAVE_FLOOR_ROW, HostileChamber.CAVE_FLOOR_ROW + 1, HostileChamber.CAVE_FLOOR_ROW + 2])


## The control that tells the bound from the window: the same call, the same 48-row window, with a reach
## no body can have. If the window could not see the lower floor the two calls would agree; they differ,
## so the silence of the first is the reach bound's doing and nothing else's.
func _test_a_pocket_sixteen_rows_down_is_silenced_by_the_reach_not_the_window() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_OVERHANG_START + 1
	var gap: int = HostileChamber.CAVE_LOWER_FLOOR_ROW - HostileChamber.CAVE_FLOOR_ROW
	var deepest_reach: int = HostileChamber.CAVE_FLOOR_ROW + 2   ## the most a landing gate can accept below the chosen row
	var real: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, _scan_from(deepest_reach), Body.FLOOR_SCAN_ROWS, HostileChamber.CAVE_FLOOR_ROW, deepest_reach)
	_check(real == null,
		"the shelf over a pocket %d rows down, with the deepest reach the resolver's own scan allows (row %d): silent" %
		[gap, deepest_reach])
	var impossible: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, _scan_from(deepest_reach), Body.FLOOR_SCAN_ROWS, HostileChamber.CAVE_FLOOR_ROW, HostileChamber.CAVE_LOWER_FLOOR_ROW)
	_check(impossible != null and impossible.competing_floor_row == HostileChamber.CAVE_LOWER_FLOOR_ROW,
		"control: the same window with a reach handed in at the lower floor itself (row %d) DOES report it -- the window sees %d rows down; it is the reach that silences the real call (got %s)" %
		[HostileChamber.CAVE_LOWER_FLOOR_ROW, gap, str(impossible.competing_floor_row) if impossible != null else "null"])


func _test_a_real_embedded_body_trips_the_guard_through_tick() -> void:
	var grid: TileGrid = Probe.build_grid()
	var body: Body = Body.new(0, 0)
	Probe.pose(body, Probe.FLOOR_ROW)
	body.tick(InputFrame.new(), grid)
	_check(body.floor_selection_violation_this_tick,
		"a body posed with its feet on the floor and the shelf through its shins flags the violation on the tick that resolves it")
	var got_row: float = float(body._bottom_y()) / float(Fx.SCALE) / float(CELL)
	_check(body.floor_source_this_tick == &"resolve_floor" and is_equal_approx(got_row, float(Probe.LEDGE_ROW)),
		"and it was resolve_floor that chose, lifting the feet onto the shelf at row %d (got row %.3f via %s) -- the choice the check reports on" %
		[Probe.LEDGE_ROW, got_row, body.floor_source_this_tick])


func _test_a_real_body_standing_on_the_shelf_is_silent_through_tick() -> void:
	var grid: TileGrid = Probe.build_grid()
	var body: Body = Body.new(0, 0)
	Probe.pose(body, Probe.LEDGE_ROW)
	for i: int in 30:
		body.tick(InputFrame.new(), grid)
		if body.floor_selection_violation_this_tick:
			break
	var got_row: float = float(body._bottom_y()) / float(Fx.SCALE) / float(CELL)
	_check(not body.floor_selection_violation_this_tick and body.on_floor and is_equal_approx(got_row, float(Probe.LEDGE_ROW)),
		"the same body resting ON the shelf over the same crack for 30 ticks: never flagged, still on row %d (got %.3f, on_floor %s)" %
		[Probe.LEDGE_ROW, got_row, str(body.on_floor)])


## D0052's rate limit, measured where it can be: a subprocess holding the ambiguous pose for HOLD_TICKS
## landings on one (column, floor) pair. With the caller's gate, one report; with the gate reverted to
## unconditional reporting, HOLD_TICKS (mutation-tested at D0516: 30).
func _test_a_held_ambiguity_is_reported_once() -> void:
	var combined: String = _run_probe("res://tests/fixture_settle_violation_probe.gd")
	var frame: String = _probe_line(combined, "SETTLE_VIOLATION_PROBE")
	_check(_field(frame, "flagged_ticks") == str(Probe.HOLD_TICKS),
		"the frame: the condition held on every one of the %d ticks (probe line: %s)" % [Probe.HOLD_TICKS, frame])
	var occurrences: int = combined.count("ambiguous floor selection")
	_check(occurrences == 1,
		"and the caller reported it exactly ONCE, not once per landing -- got %d occurrences in the probe's own stderr" % occurrences)


## THE LEDGER'S NUMBER. The real tutorial world at the stranger seats' seed, 600 ticks standing at the
## spawn and walking ten metres each way through the door. Before D0516 the same probe on the same tree
## reported 19 distinct (column, floor) pairs across 39 flagged ticks, every one of them the pad at row
## 80 over a pocket 12-20 rows down; the seat logs' own row 80 / row 96 at column 144 is the first of
## them. A count of zero here is only evidence because the walk is asserted to have happened.
func _test_the_seeded_opening_walk_reports_nothing() -> void:
	var combined: String = _run_probe("res://tests/fixture_seeded_walk_probe.gd")
	var frame: String = _probe_line(combined, "SEEDED_WALK_PROBE")
	var left: float = float(_field(frame, "walked_left_px"))
	var right: float = float(_field(frame, "walked_right_px"))
	_check(left >= 160.0 and right >= 160.0 and _field(frame, "final_leg") == "4",
		"the frame: the body walked at least 10 m (160 px) each way and came back to stand (probe line: %s)" % frame)
	_check(_field(frame, "flagged_ticks") == "0" and combined.count("ambiguous floor selection") == 0,
		"and the check fired on none of the 600 ticks and reported nothing -- got flagged_ticks=%s, %d report(s)" %
		[_field(frame, "flagged_ticks"), combined.count("ambiguous floor selection")])


## Spawns a probe as its own process and returns its combined output, after the two checks every probe
## run needs (D0115/D0117): it exited cleanly and printed no SCRIPT ERROR, since a mid-run crash could
## abort the loop early and land a count on the expected value by coincidence.
func _run_probe(script: String) -> String:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", script], output, true)
	_check(exit_code == 0, "%s exits cleanly (got %d)" % [script, exit_code])
	var combined: String = "\n".join(output)
	_check(not combined.contains("SCRIPT ERROR:"), "%s printed no SCRIPT ERROR (docs/DECISIONS_LEDGER.md D0117)" % script)
	return combined


func _probe_line(combined: String, tag: String) -> String:
	for line: String in combined.split("\n"):
		if line.begins_with(tag):
			return line.strip_edges()
	return ""


func _field(line: String, key: String) -> String:
	for token: String in line.split(" "):
		if token.begins_with(key + "="):
			return token.substr(key.length() + 1)
	return ""
