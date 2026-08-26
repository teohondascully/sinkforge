extends "res://tests/test_base.gd"

## Behavioral proof for the multi-level-floor limitation `docs/adr/0005-heightfield-local-window.md`
## documents (D0042/D0043): what the current local-windowed heightfield query and the new
## `Invariants` guard ACTUALLY do against `HostileChamber`'s cave-geometry section -- not that they
## "work," which they were never meant to for this case. `tests/test_hostile_chamber.gd`'s
## `_test_cave_geometry_present()` already proves the fixture itself is built as specified; this file
## is the "assert what actually happens" half the director asked for.
##
## The headline finding, confirmed here rather than assumed: `Invariants.check_floor_selection`, given
## the SAME 6-row window `body.gd::_resolve_floor()` actually passes it, does NOT fire anywhere in this
## chamber -- not standing on the shelf, not standing on the lower floor. The shelf and the lower floor
## are 16 rows apart (a 6-row slab plus the 10-row clearance a genuinely walkable pocket needs); a
## 6-row window cannot see both at once. The guard's real coverage is narrower than the 0.85%/12%
## measured figure it was built to make reproducible: it can only catch two candidate floors within
## ~6 rows of each other, a rarer sub-case of that figure, not the jump-reachable (up to 18-cell) cases
## the measurement's reachability graph mostly found. `_test_invariant_check_has_teeth_...` below proves
## the check LOGIC is correct by giving it a window wide enough to see both floors; the two
## `_real_scoped_window_` tests prove that in practice, on this geometry, `_resolve_floor`'s own window
## never reaches that far. Both things are true and neither contradicts the other -- log it, don't average it.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_top_down_scan_sees_only_the_shelf()
	_test_local_window_resolves_the_shelf_when_body_lands_there()
	_test_local_window_resolves_the_lower_floor_when_body_lands_there()
	_test_invariant_check_has_teeth_with_a_window_wide_enough_to_see_both_floors()
	_test_invariant_check_is_silent_on_a_normal_single_floor_column()
	_test_real_scoped_window_does_not_see_this_reachable_case_from_the_shelf()
	_test_real_scoped_window_does_not_see_this_reachable_case_from_the_lower_floor()
	_finish("cave_geometry")


func _col_center_x(col: int) -> int:
	return col * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2


## Drops a body from directly below the cave ceiling and lets it settle. `start_row=12` is not
## arbitrary: the ceiling occupies rows [1,5) (`CAVE_CEILING_CLEARANCE_ROWS`), and a body spawned with
## its own top still inside that -- row 6, the first naive guess -- overlaps solid rock at spawn, which
## `_resolve_horizontal`'s depenetration pushes sideways every tick regardless of input (it isn't gated
## on `vel_x != 0`), turning "drop straight down" into "drift sideways and fall past the section
## entirely." Caught by watching per-tick `pos_x` drift with a debug probe before trusting a single
## settle value -- exactly the kind of thing this file exists to catch happening for real, not assume
## away. row 12 clears the ceiling with margin.
func _settle(pos_x: int) -> Body:
	var grid: TileGrid = HostileChamber.build()
	var body: Body = Body.new(pos_x, Fx.from_int(12 * CELL))
	for i: int in range(400):
		body.tick(InputFrame.new(), grid)
	return body


func _test_top_down_scan_sees_only_the_shelf() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_OVERHANG_START + 1
	# Scanning from row 0 would hit the tunnel's own CEILING first (rows [1,5)) and report that instead
	# -- a real global ground-plane query already knows the ceiling from the grid-swept pass Heightfield
	# is explicitly not responsible for (`heightfield.gd`'s own header: "Ceilings and walls stay
	# grid-swept... this file is the ground plane only"), so it would start below it, not at the sky.
	var ceiling_clear_row: int = HostileChamber.CAVE_FLOOR_ROW - HostileChamber.CAVE_CEILING_CLEARANCE_ROWS
	var got: int = Heightfield.column_surface_y(grid, col, ceiling_clear_row, grid.height - ceiling_clear_row)
	var shelf: int = Fx.from_int(HostileChamber.CAVE_FLOOR_ROW * CELL)
	var lower: int = Fx.from_int(HostileChamber.CAVE_LOWER_FLOOR_ROW * CELL)
	_check(got == shelf,
		"a top-down scan (row 0, full column height) of an overhang column reports the shelf (row %d) -- exactly what docs/ARCHITECTURE.md §9's original global-heightfield spec would report (got Fx %d, want %d)" %
		[HostileChamber.CAVE_FLOOR_ROW, got, shelf])
	_check(got != lower,
		"and NOT the lower floor -- confirms the representational gap Codex flagged is real: a single top-down scan genuinely cannot see a floor under a reachable overhang")


func _test_local_window_resolves_the_shelf_when_body_lands_there() -> void:
	var body: Body = _settle(_col_center_x(HostileChamber.CAVE_OVERHANG_START + 1))
	_check(body.on_floor, "a body dropped over the overhang settles (does not fall forever)")
	var want_row: float = float(HostileChamber.CAVE_FLOOR_ROW)
	var got_row: float = float(body._bottom_y()) / float(Fx.SCALE) / float(CELL)
	_check(is_equal_approx(got_row, want_row),
		"and rests on the shelf, row %.0f (got %.3f) -- the local windowed query correctly picks the nearer of the two candidate floors when the body approaches from above" %
		[want_row, got_row])


func _test_local_window_resolves_the_lower_floor_when_body_lands_there() -> void:
	var body: Body = _settle(_col_center_x(HostileChamber.CAVE_GAP_START + 1))
	_check(body.on_floor, "a body dropped through the gap (no shelf above it) settles (does not fall forever)")
	var want_row: float = float(HostileChamber.CAVE_LOWER_FLOOR_ROW)
	var got_row: float = float(body._bottom_y()) / float(Fx.SCALE) / float(CELL)
	_check(is_equal_approx(got_row, want_row),
		"and rests on the LOWER floor, row %.0f (got %.3f) -- proving the local window is not simply blind to the lower pocket, it correctly resolves it once the body is actually near it, which is the whole case for accepting this as a bounded query rather than a broken one" %
		[want_row, got_row])


## `check_floor_selection`'s own correctness, independent of what window `body.gd` happens to pass in
## practice -- the mutation-test proof this guard has teeth at all. A window wide enough to span both
## the shelf (row `CAVE_FLOOR_ROW`) and the lower floor (row `CAVE_LOWER_FLOOR_ROW`, 16 rows below) must
## detect the second one. `+4` past the exact gap width is deliberate margin, not tuning to pass --
## `while row < window_end` is a half-open range, so a window sized to the gap EXACTLY (window_end ==
## CAVE_LOWER_FLOOR_ROW) misses the lower floor's own row by one and reports no violation, which is
## the first thing this test hit and corrected before trusting the result.
func _test_invariant_check_has_teeth_with_a_window_wide_enough_to_see_both_floors() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_OVERHANG_START + 1
	var scan_from: int = HostileChamber.CAVE_FLOOR_ROW - 2
	var wide_max_rows: int = (HostileChamber.CAVE_LOWER_FLOOR_ROW - scan_from) + 4
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, scan_from, wide_max_rows, HostileChamber.CAVE_FLOOR_ROW, Body.HEIGHT_PX / CELL)
	_check(v != null,
		"given a window wide enough to actually span both candidate floors (%d rows), check_floor_selection detects the ambiguity -- the check logic itself is not the reason it stays silent in practice" %
		wide_max_rows)
	if v != null:
		_check(v.chosen_floor_row == HostileChamber.CAVE_FLOOR_ROW,
			"reports the chosen floor it was given (row %d, got %d)" % [HostileChamber.CAVE_FLOOR_ROW, v.chosen_floor_row])
		_check(v.competing_floor_row == HostileChamber.CAVE_LOWER_FLOOR_ROW,
			"and correctly identifies the lower floor (row %d) as the competing surface, not some other row (got %d)" %
			[HostileChamber.CAVE_LOWER_FLOOR_ROW, v.competing_floor_row])


func _test_invariant_check_is_silent_on_a_normal_single_floor_column() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_START + 2  ## plain tunnel span, one floor only
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, HostileChamber.CAVE_FLOOR_ROW - 2, 6, HostileChamber.CAVE_FLOOR_ROW, Body.HEIGHT_PX / CELL)
	_check(v == null,
		"negative control: an ordinary single-floor tunnel column never trips the guard, even with the real 6-row window (no false positive)")


## The finding this file exists to surface. `body.gd::_resolve_floor()` passes `check_floor_selection`
## the SAME narrow window it uses to pick a floor: 6 rows, `scan_from = row - 2`. This chamber's cave
## section was deliberately built with the shelf and lower floor 16 rows apart -- a 6-row slab plus the
## full 10-row body-height clearance a genuinely walkable pocket needs (`CAVE_LOWER_FLOOR_ROW` itself).
## That is not a special case chosen to embarrass the guard: it is what "genuinely reachable" means in
## this codebase's own terms, the same terms the 0.85%/12% measurement used. A 6-row window cannot see
## 16 rows. So the guard, as actually wired into `body.gd`, does not fire anywhere in this fixture --
## confirmed here rather than assumed, matching the "assert what actually happens" instruction this
## whole file follows.
func _test_real_scoped_window_does_not_see_this_reachable_case_from_the_shelf() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_OVERHANG_START + 1
	var scan_from: int = HostileChamber.CAVE_FLOOR_ROW - 2  ## the exact window _resolve_floor computes
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, scan_from, 6, HostileChamber.CAVE_FLOOR_ROW, Body.HEIGHT_PX / CELL)
	_check(v == null,
		"standing on the shelf, with body.gd's REAL 6-row window (not a widened test window), the guard does not see the lower floor 16 rows below -- the guard's practical coverage is narrower than the 0.85%%/12%% figure it was built to make reproducible, and that gap is itself worth knowing, not just the guard's existence")


func _test_real_scoped_window_does_not_see_this_reachable_case_from_the_lower_floor() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_GAP_START + 1
	var scan_from: int = HostileChamber.CAVE_LOWER_FLOOR_ROW - 2  ## the exact window _resolve_floor computes
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, scan_from, 6, HostileChamber.CAVE_LOWER_FLOOR_ROW, Body.HEIGHT_PX / CELL)
	_check(v == null,
		"symmetric check standing on the lower floor: the shelf is 16 rows above, also outside the real 6-row window, so the guard is silent here too -- neither resting position in this fixture is one the wired guard can see")
