extends "res://tests/test_base.gd"

## Behavioral proof for the multi-level-floor limitation `docs/adr/0005-heightfield-local-window.md`
## documents (D0042-D0044): what the current local-windowed heightfield query and the `Invariants`
## guard ACTUALLY do against `HostileChamber`'s cave-geometry section -- not that they "work," which
## `_resolve_floor` was never meant to for this case in the sense of solving it. `test_hostile_chamber.gd`'s
## `_test_cave_geometry_present()` already proves the fixture itself is built as specified; this file
## is the "assert what actually happens" half the director asked for.
##
## First pass of this file found the guard's window (6 rows, matching the original `_resolve_floor`)
## could not see this fixture's own 16-row gap and reported zero by construction, not by measurement --
## a check that cannot be nonzero is not evidence. `Body.FLOOR_SCAN_ROWS` (D0044) widened the real,
## wired window to 48 rows, sized from re-measuring D0042's own reachability analysis for the actual
## row-gap distribution between genuinely-reachable stacked floors (min 11, p50 16, p99 36, max 36
## across 197 samples over the same 4,800-column run). This file now proves the corrected window
## actually detects the case it was built for, using the real `Body.FLOOR_SCAN_ROWS` constant
## throughout rather than an arbitrary test-only widening.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_top_down_scan_sees_only_the_shelf()
	_test_local_window_resolves_the_shelf_when_body_lands_there()
	_test_local_window_resolves_the_lower_floor_when_body_lands_there()
	_test_a_body_partly_over_the_shelf_catches_on_it_instead_of_clipping_through()
	_test_invariant_check_is_silent_on_a_normal_single_floor_column()
	_test_real_wired_window_detects_the_case_standing_on_the_shelf()
	_test_real_wired_window_detects_the_case_standing_on_the_lower_floor()
	_test_a_real_settle_actually_trips_the_guard()
	_test_a_real_settle_rate_limits_the_guard_to_one_report()
	_finish("cave_geometry")


func _col_center_x(col: int) -> int:
	return col * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2


## Drops a body from directly below the cave ceiling and lets it settle. The spawn row is not
## arbitrary: the ceiling occupies rows [ceiling_bottom-4, ceiling_bottom) (`CAVE_CEILING_CLEARANCE_ROWS`
## below `CAVE_FLOOR_ROW`), and a body spawned with its own top still inside that -- `ceiling_bottom+1`,
## the first naive guess -- overlaps solid rock at spawn, which `_resolve_horizontal`'s depenetration
## pushes sideways every tick regardless of input (it isn't gated on `vel_x != 0`), turning "drop
## straight down" into "drift sideways and fall past the section entirely." Caught by watching per-tick
## `pos_x` drift with a debug probe before trusting a single settle value -- exactly the kind of thing
## this file exists to catch happening for real, not assume away. `ceiling_bottom+7` clears the ceiling
## with margin -- expressed relative to `HostileChamber`'s own constants (D0055: this used to be the bare
## literal `12`, tuned against the chamber's pre-margin row values; a hardcoded absolute row silently
## stopped clearing the ceiling at all once `TOP_MARGIN_ROWS` shifted it, landing the body ON TOP of the
## ceiling material instead of below it) so it survives any future shift the same way.
func _settle(pos_x: int) -> Body:
	var grid: TileGrid = HostileChamber.build()
	var ceiling_bottom: int = HostileChamber.CAVE_FLOOR_ROW - HostileChamber.CAVE_CEILING_CLEARANCE_ROWS
	var body: Body = Body.new(pos_x, Fx.from_int((ceiling_bottom + 7) * CELL))
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
	# Unaffected by `Body.FLOOR_SCAN_ROWS`: this call passes its own generous, unrelated window (the
	# whole remaining column) to model what an unqualified GLOBAL per-column scan would report --
	# `docs/ARCHITECTURE.md` §9's original spec, not `_resolve_floor`'s actual bounded query.
	var ceiling_clear_row: int = HostileChamber.CAVE_FLOOR_ROW - HostileChamber.CAVE_CEILING_CLEARANCE_ROWS
	var got: int = Heightfield.column_surface_y(grid, col, ceiling_clear_row, grid.height - ceiling_clear_row)
	var shelf: int = Fx.from_int(HostileChamber.CAVE_FLOOR_ROW * CELL)
	var lower: int = Fx.from_int(HostileChamber.CAVE_LOWER_FLOOR_ROW * CELL)
	_check(got == shelf,
		"a top-down scan (full remaining column height) of an overhang column reports the shelf (row %d) -- exactly what docs/ARCHITECTURE.md §9's original global-heightfield spec would report (got Fx %d, want %d)" %
		[HostileChamber.CAVE_FLOOR_ROW, got, shelf])
	_check(got != lower,
		"and NOT the lower floor -- confirms the representational gap Codex flagged is real: a single unbounded top-down scan genuinely cannot see a floor under a reachable overhang, no matter how wide _resolve_floor's own LOCAL window is")


func _test_local_window_resolves_the_shelf_when_body_lands_there() -> void:
	var body: Body = _settle(_col_center_x(HostileChamber.CAVE_OVERHANG_START + 1))
	_check(body.on_floor, "a body dropped over the overhang settles (does not fall forever)")
	var want_row: float = float(HostileChamber.CAVE_FLOOR_ROW)
	var got_row: float = float(body._bottom_y()) / float(Fx.SCALE) / float(CELL)
	_check(is_equal_approx(got_row, want_row),
		"and rests on the shelf, row %.0f (got %.3f) -- the local windowed query correctly picks the nearer (topmost) of the two candidate floors when the body approaches from above, same as before FLOOR_SCAN_ROWS widened" %
		[want_row, got_row])


## How many solid cells the body's box overlaps -- zero at every tick is the property the resolver
## exists to maintain, and the quantity that showed this file's own expectation had been wrong (D0206).
func _overlap(grid: TileGrid, body: Body) -> int:
	var n: int = 0
	for col: int in range(Body._px_to_cell(body._left_x()), Body._px_to_cell(body._right_x() - 1) + 1):
		for row: int in range(Body._px_to_cell(body._top_y()), Body._px_to_cell(body._bottom_y() - 1) + 1):
			if grid.in_bounds(Vector2i(col, row)) and grid.is_solid(Vector2i(col, row)):
				n += 1
	return n


## D0206 corrected this test's SUBJECT, not just its number. The gap is `CAVE_GAP_COLS` = 4 columns and
## the body is exactly 4 columns wide, so it fits only when its box is aligned to the gap exactly. This
## used to drop the body on `_col_center_x(CAVE_GAP_START + 1)`, which puts its box on columns
## [GAP_START-1, GAP_START+2] -- the leftmost of them a SHELF column. It then "resolved the lower floor"
## by passing straight through the shelf's 6-row slab: measured directly against the pre-D0206 resolver,
## `worst_overlap=1` at tick 11 of the settle, on the way down. Passing that assertion required the body
## to clip through solid rock, so the assertion was pinning the defect.
##
## Aligned to the gap's own left edge instead, the body genuinely fits and genuinely falls through.
func _test_local_window_resolves_the_lower_floor_when_body_lands_there() -> void:
	var grid: TileGrid = HostileChamber.build()
	var aligned_x: int = Fx.from_int(HostileChamber.CAVE_GAP_START * CELL + Body.WIDTH_PX / 2)
	var body: Body = _settle(aligned_x)
	_check(Body._px_to_cell(body._left_x()) >= HostileChamber.CAVE_GAP_START
		and Body._px_to_cell(body._right_x() - 1) < HostileChamber.CAVE_END,
		"sanity: the body's box [%d,%d] is inside the gap's own columns [%d,%d) -- otherwise it is not the through-the-gap case at all" %
		[Body._px_to_cell(body._left_x()), Body._px_to_cell(body._right_x() - 1),
		HostileChamber.CAVE_GAP_START, HostileChamber.CAVE_END])
	_check(body.on_floor, "a body dropped through the gap (no shelf above it) settles (does not fall forever)")
	var want_row: float = float(HostileChamber.CAVE_LOWER_FLOOR_ROW)
	var got_row: float = float(body._bottom_y()) / float(Fx.SCALE) / float(CELL)
	_check(is_equal_approx(got_row, want_row),
		"and rests on the LOWER floor, row %.0f (got %.3f) -- a wider window does not make a body snap onto a distant floor prematurely (_bottom_y() < surface still gates every candidate), it only lets the query see further once the body has genuinely fallen there" %
		[want_row, got_row])
	_check(_overlap(grid, body) == 0,
		"having overlapped nothing solid on arrival (%d cells) -- `grid` is a second `HostileChamber.build()` of the same fixed-seed terrain as `_settle`'s own, so this reads the identical geometry the body fell through" %
		_overlap(grid, body))


## The other half of the correction, kept as its own case because it is the behaviour that CHANGED: a
## body whose footprint only partly overlaps the shelf catches on the shelf. It does not squeeze through
## a hole its own width while a quarter of it stands on rock.
func _test_a_body_partly_over_the_shelf_catches_on_it_instead_of_clipping_through() -> void:
	var grid: TileGrid = HostileChamber.build()
	var body: Body = _settle(_col_center_x(HostileChamber.CAVE_GAP_START + 1))
	var lo: int = Body._px_to_cell(body._left_x())
	_check(lo < HostileChamber.CAVE_GAP_START,
		"sanity: this body's leftmost column (%d) really is a shelf column, left of the gap at %d" %
		[lo, HostileChamber.CAVE_GAP_START])
	_check(body.on_floor, "it settles rather than falling forever")
	var got_row: float = float(body._bottom_y()) / float(Fx.SCALE) / float(CELL)
	_check(is_equal_approx(got_row, float(HostileChamber.CAVE_FLOOR_ROW)),
		"and rests on the SHELF, row %d (got %.3f) -- not on the lower floor, which it could only reach by passing through the shelf's own slab" %
		[HostileChamber.CAVE_FLOOR_ROW, got_row])
	_check(_overlap(grid, body) == 0,
		"with no part of its box inside rock (overlapping %d cells)" % _overlap(grid, body))


func _test_invariant_check_is_silent_on_a_normal_single_floor_column() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_START + 2  ## plain tunnel span, one floor only
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, HostileChamber.CAVE_FLOOR_ROW - 2, Body.FLOOR_SCAN_ROWS,
		HostileChamber.CAVE_FLOOR_ROW, Body.HEIGHT_PX / CELL)
	_check(v == null,
		"negative control: an ordinary single-floor tunnel column never trips the guard, even with the real (now-widened) window -- no false positive from widening alone")


## The corrected version of what this file originally found silent. `body.gd::_resolve_floor()` now
## passes `check_floor_selection` a 48-row window (`Body.FLOOR_SCAN_ROWS`, D0044), sized from a real
## measurement of the row-gap distribution between genuinely-reachable stacked floors, not an arbitrary
## widening. This fixture's own 16-row gap (median of that same distribution is 16) is well inside it.
func _test_real_wired_window_detects_the_case_standing_on_the_shelf() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_OVERHANG_START + 1
	var scan_from: int = HostileChamber.CAVE_FLOOR_ROW - 2  ## the exact window _resolve_floor computes
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, scan_from, Body.FLOOR_SCAN_ROWS, HostileChamber.CAVE_FLOOR_ROW, Body.HEIGHT_PX / CELL)
	_check(v != null,
		"standing on the shelf, with body.gd's REAL wired window (Body.FLOOR_SCAN_ROWS=%d, not a widened test-only value), the guard now DOES see the lower floor -- the case D0042/D0043 measured is now actually reproducible in real play, not just in a synthetic wide-window call" %
		Body.FLOOR_SCAN_ROWS)
	if v != null:
		_check(v.chosen_floor_row == HostileChamber.CAVE_FLOOR_ROW and v.competing_floor_row == HostileChamber.CAVE_LOWER_FLOOR_ROW,
			"and reports the correct pair: chosen row %d, competing row %d (got %d, %d)" %
			[HostileChamber.CAVE_FLOOR_ROW, HostileChamber.CAVE_LOWER_FLOOR_ROW, v.chosen_floor_row, v.competing_floor_row])


func _test_real_wired_window_detects_the_case_standing_on_the_lower_floor() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_GAP_START + 1
	var scan_from: int = HostileChamber.CAVE_LOWER_FLOOR_ROW - 2  ## the exact window _resolve_floor computes
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, scan_from, Body.FLOOR_SCAN_ROWS, HostileChamber.CAVE_LOWER_FLOOR_ROW, Body.HEIGHT_PX / CELL)
	_check(v == null,
		"symmetric check standing on the LOWER floor: the shelf is 16 rows ABOVE, outside check_floor_selection's own downward-only scan (it only looks from chosen_floor_row+1 down, matching what _resolve_floor could ever mis-pick -- a floor already below the one just chosen), so silence here is correct, not a coverage gap")


## The most direct proof available: not a synthetic direct call with hand-picked parameters, but a real
## `Body` actually settling through real `tick()` physics, with `push_error` genuinely firing during the
## run (visible in this suite's own stderr) -- the same code path a real playthrough would exercise.
func _test_a_real_settle_actually_trips_the_guard() -> void:
	var body: Body = _settle(_col_center_x(HostileChamber.CAVE_OVERHANG_START + 1))
	var grid: TileGrid = HostileChamber.build()
	var check_col: int = Body._px_to_cell(body.pos_x)
	var row: int = int(floor(float(body._bottom_y()) / float(Fx.SCALE) / float(CELL)))
	var scan_from: int = maxi(0, row - 2)
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, check_col, scan_from, Body.FLOOR_SCAN_ROWS, HostileChamber.CAVE_FLOOR_ROW, Body.HEIGHT_PX / CELL)
	_check(v != null,
		"re-deriving the same check with the settled body's own real column/window (not a hand-picked one) still finds the violation -- confirms _test_local_window_resolves_the_shelf_when_body_lands_there's settle above is the exact scenario that fires the guard live, matching the push_error the test run's own stderr shows")


## D0052. Before rate-limiting, this exact ~400-tick settle produced 778 near-identical push_error
## lines (measured directly while building the fix, by temporarily reverting body.gd's rate-limit
## gate to unconditional reporting and re-running this same probe) -- not merely once per tick, since
## `body.gd::_move_and_resolve_vertical` calls `_resolve_floor` twice on most resting ticks (once
## inside its substep loop, once via its own trailing catch-all). `body.gd::_resolve_floor()` now
## suppresses a repeat report while the resolved (column, floor) pair is unchanged, however many times
## it runs in a tick; this proves that in the real tick() path, not just against a direct
## check_floor_selection() call, which cannot observe rate-limiting at all since it holds no state
## across calls. Stock GDScript has no in-process way to count `push_error()` calls from the same
## script that made them (the same reason `fixture_div_by_zero_probe.gd` exists), so this spawns
## `tests/fixture_settle_violation_probe.gd` as a real subprocess and counts occurrences of the
## violation's own message text in its actual stderr.
func _test_a_real_settle_rate_limits_the_guard_to_one_report() -> void:
	var project_root: String = ProjectSettings.globalize_path("res://")
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(),
		["--headless", "--path", project_root, "--script", "res://tests/fixture_settle_violation_probe.gd"],
		output, true)
	_check(exit_code == 0, "the probe subprocess itself exits cleanly (got %d)" % exit_code)
	var combined: String = "\n".join(output)
	# D0115/D0117: exit_code==0 is not enough on its own -- a mid-run SCRIPT ERROR could abort the
	# 400-tick settle early, before or after the one report this test expects, and still land the
	# count on exactly 1 by coincidence rather than by the rate-limit actually holding.
	_check(not combined.contains("SCRIPT ERROR:"),
		"the probe's own output contains no SCRIPT ERROR (docs/DECISIONS_LEDGER.md D0117)")
	var occurrences: int = combined.count("ambiguous floor selection")
	_check(occurrences == 1,
		"a 400-tick settle on the ambiguous shelf logs the violation exactly ONCE, not once per tick -- got %d occurrences in the probe's own stderr (captured output: %s)" %
		[occurrences, combined])
