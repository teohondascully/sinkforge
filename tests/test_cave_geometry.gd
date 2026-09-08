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
## across 197 samples over the same 4,800-column run). This file then proved the corrected window
## detects the shelf-over-a-pocket shape, using the real `Body.FLOOR_SCAN_ROWS` constant throughout.
##
## D0516 turned that half of this file around. A shelf over a pocket 16 rows down is a shape of the
## TERRAIN, not an ambiguity of the resolver's CHOICE: `resolve_floor` lands only on a surface the feet
## have reached (`_bottom_y() < surface`, the verification D0044 itself recorded), so a body on the shelf
## was never choosing between the shelf and a floor 16 rows under its feet, and the check reporting it --
## 40-190 times a session on the pockets the world seeder authors under the tutorial pad -- was an
## instrument with no subject. The check now bounds itself to the rows the feet reached; the shelf here
## is its negative case, and `tests/test_floor_ambiguity.gd` owns the positive (two surfaces a cell apart,
## both reached), the caller's rate limit (moved there with `fixture_settle_violation_probe.gd`), and the
## seeded opening walk whose count is the ledger's number.

const CELL: int = Heightfield.TERRAIN_CELL_PX


func _initialize() -> void:
	_test_top_down_scan_sees_only_the_shelf()
	_test_local_window_resolves_the_shelf_when_body_lands_there()
	_test_local_window_resolves_the_lower_floor_when_body_lands_there()
	_test_a_body_partly_over_the_shelf_catches_on_it_instead_of_clipping_through()
	_test_invariant_check_is_silent_on_a_normal_single_floor_column()
	_test_standing_on_the_shelf_over_a_pocket_is_not_ambiguous()
	_test_standing_on_the_lower_floor_under_the_shelf_is_not_ambiguous()
	_test_a_real_settle_on_the_shelf_does_not_trip_the_guard()
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
	_check(PropertyChecks.solid_overlap_count(body, grid) == 0,
		"having overlapped nothing solid on arrival (%d cells) -- `grid` is a second `HostileChamber.build()` of the same fixed-seed terrain as `_settle`'s own, so this reads the identical geometry the body fell through" %
		PropertyChecks.solid_overlap_count(body, grid))


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
	_check(PropertyChecks.solid_overlap_count(body, grid) == 0,
		"with no part of its box inside rock (overlapping %d cells)" % PropertyChecks.solid_overlap_count(body, grid))


func _test_invariant_check_is_silent_on_a_normal_single_floor_column() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_START + 2  ## plain tunnel span, one floor only
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, HostileChamber.CAVE_FLOOR_ROW - 2, Body.FLOOR_SCAN_ROWS,
		HostileChamber.CAVE_FLOOR_ROW, HostileChamber.CAVE_FLOOR_ROW)
	_check(v == null,
		"negative control: an ordinary single-floor tunnel column never trips the guard, even with the real (now-widened) window -- no false positive from widening alone")


## Until D0516 this test asserted the OPPOSITE -- that standing on the shelf fired the guard, naming the
## lower floor 16 rows down as the competing surface -- and it was wrong about what the guard is for. A
## body on the shelf has its feet at `CAVE_FLOOR_ROW`; `resolve_floor` refuses every surface the feet
## have not reached, so the lower floor was never a candidate it could have chosen. The old pin proved
## the WINDOW sees the pocket (`tests/test_floor_ambiguity.gd` keeps that as a control, with a reach no
## body can have); it did not prove a choice was ambiguous, and every stranger seat paid for the
## difference in 40-190 reports a session over the tutorial pad.
func _test_standing_on_the_shelf_over_a_pocket_is_not_ambiguous() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_OVERHANG_START + 1
	var scan_from: int = HostileChamber.CAVE_FLOOR_ROW - 2  ## the exact window _resolve_floor computes
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, scan_from, Body.FLOOR_SCAN_ROWS, HostileChamber.CAVE_FLOOR_ROW, HostileChamber.CAVE_FLOOR_ROW)
	_check(v == null,
		"standing on the shelf (feet at row %d) over the lower floor %d rows down, with body.gd's real window (Body.FLOOR_SCAN_ROWS=%d): silent -- the pocket is below the feet, so it was never a surface the resolver could have landed on" %
		[HostileChamber.CAVE_FLOOR_ROW, HostileChamber.CAVE_LOWER_FLOOR_ROW - HostileChamber.CAVE_FLOOR_ROW, Body.FLOOR_SCAN_ROWS])


func _test_standing_on_the_lower_floor_under_the_shelf_is_not_ambiguous() -> void:
	var grid: TileGrid = HostileChamber.build()
	var col: int = HostileChamber.CAVE_GAP_START + 1
	var scan_from: int = HostileChamber.CAVE_LOWER_FLOOR_ROW - 2  ## the exact window _resolve_floor computes
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, col, scan_from, Body.FLOOR_SCAN_ROWS, HostileChamber.CAVE_LOWER_FLOOR_ROW, HostileChamber.CAVE_LOWER_FLOOR_ROW)
	_check(v == null,
		"symmetric check standing on the LOWER floor: the shelf is 16 rows ABOVE, outside the window _resolve_floor scans from (two rows above the feet), so it was not a candidate either -- silence here is correct, not a coverage gap")


## The real `Body` settling through real `tick()` physics onto the shelf, the scenario that used to fire
## `push_error` in this suite's own stderr on every run: it no longer does, and the check re-derived
## from the settled body's own column and window agrees.
func _test_a_real_settle_on_the_shelf_does_not_trip_the_guard() -> void:
	var body: Body = _settle(_col_center_x(HostileChamber.CAVE_OVERHANG_START + 1))
	_check(not body.floor_selection_violation_this_tick and body.on_floor,
		"a 400-tick settle onto the shelf ends on the floor with the violation flag clear on its last tick (on_floor %s, flagged %s)" %
		[str(body.on_floor), str(body.floor_selection_violation_this_tick)])
	var grid: TileGrid = HostileChamber.build()
	var check_col: int = Body._px_to_cell(body.pos_x)
	var row: int = int(floor(float(body._bottom_y()) / float(Fx.SCALE) / float(CELL)))
	var scan_from: int = maxi(0, row - 2)
	var v: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
		grid, check_col, scan_from, Body.FLOOR_SCAN_ROWS, HostileChamber.CAVE_FLOOR_ROW, row)
	_check(v == null,
		"re-deriving the check with the settled body's own real column, window and feet row (%d, not a hand-picked one) finds nothing: the shelf is the only surface those feet reached" % row)
