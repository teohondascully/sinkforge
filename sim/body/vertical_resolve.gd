class_name VerticalResolve
extends RefCounted

## Split out of `body.gd` (D0060) once the 400-line file-size gate (`docs/QUALITY.md` gate 3) could no
## longer be met by comment trimming alone without cutting load-bearing WHY reasoning -- an internal file
## of the `body` module, same as `heightfield.gd`/`input_frame.gd` already are (`tools/layer_lint/
## layer_lint.py`'s "no sibling reach-in" rule only requires outside code to go through `body.gd`; files
## inside `sim/body/` reaching each other's -- and `Body`'s own, GDScript has no real privacy --
## underscore-prefixed members is the same shape those two files already use). Pure vertical-axis
## collision resolution: ceilings (grid-swept, hard) and the ground plane (`Heightfield`, sub-pixel, plus
## a grid-solidity backstop for what the sub-pixel model's own contract can't answer). Every function
## takes `body: Body` explicitly rather than being instance methods on `Body` itself -- that's the whole
## point of the split.

const V_SUBSTEP_PX: int = 2  ## Comfortably under one terrain cell (4px), so no substep can cross more
                              ## than one row boundary and skip past it -- the fixed-tick equivalent of
                              ## `legacy/scenes/player.gd`'s `MAX_SUBSTEP` clamp, needed because
                              ## `MAX_FALL_PX_S` alone covers more than one cell per 60Hz tick.


## Vertical movement, substepped so a fast fall or jump cannot tunnel through a one-cell-thick floor or
## ceiling. Ceilings are grid-swept and hard; the ground plane is `Heightfield`, sub-pixel.
##
## KNOWN COMPLEXITY OUTLIER, accepted (`docs/DECISIONS_LEDGER.md` D0101/D0103), not chased further: 9,
## against a 6.0 fence, after `_resolve_substep_collision` was already extracted from it. The remainder
## is the substep `while` loop's own control flow (early-exit `break` on a stopped substep, the backout
## branch, the trailing catch-all) -- not safely reducible by pure mechanical extraction without
## converting `break`-based loop control into a return-value contract across a function boundary, which
## is a design decision, not an Extract Method. ACCEPTANCE CONDITION: if this function is touched again
## for any other reason, bringing its complexity down is part of that change, not deferred again.
static func move_and_resolve(body: Body, grid: TileGrid) -> void:
	var total: int = body.vel_y / Body.TICK_HZ
	var dir: int = signi(total)
	if dir != 0:
		body.on_floor = false
	var remaining: int = absi(total)
	var substep: int = V_SUBSTEP_PX * Fx.SCALE
	var resolved_this_tick: bool = false
	while remaining > 0 and dir != 0:
		var move: int = mini(remaining, substep)
		body.pos_y += dir * move
		remaining -= move
		var stopped: bool = _resolve_substep_collision(body, grid, dir)
		if stopped:
			# D0059b: a failed ceiling nudge only halts further movement -- it never undoes the substep
			# that moved the box into the ceiling, unlike `resolve_floor` (always recomputes pos_y from
			# the heightfield, so it can't leave the box embedded). Back out this substep's own move.
			if dir < 0:
				body.pos_y -= dir * move
			resolved_this_tick = true
			break
	# `resolved_this_tick` guards a landing `grid_floor_backstop` just confirmed: otherwise redundant
	# with the substep loop's own last call, EXCEPT when the backstop landed on ground the heightfield
	# still can't see -- `resolve_floor` alone would unconditionally re-set `on_floor = false` there.
	if dir >= 0 and not resolved_this_tick:
		resolve_floor(body, grid) or grid_floor_backstop(body, grid)  ## also catches a body at rest


## Resolves ONE substep's collision: ceiling if moving up (`dir < 0`), else the ground plane
## (heightfield, falling back to the grid-solidity backstop). Extracted 2026-08-28
## (`docs/DECISIONS_LEDGER.md` D0100) from `move_and_resolve`'s own ternary, a pure Extract Method --
## returns true iff the substep was stopped, exactly the original ternary's own value.
static func _resolve_substep_collision(body: Body, grid: TileGrid, dir: int) -> bool:
	if dir < 0:
		return resolve_ceiling(body, grid)
	return resolve_floor(body, grid) or grid_floor_backstop(body, grid)


## Hard grid-swept ceiling block, with corner correction: a horizontal nudge up to 6px toward the
## direction the body is already moving, tried before blocking outright, since a ceiling contact right
## at a corner is exactly the case docs/ARCHITECTURE.md §9 names this mechanic for.
static func resolve_ceiling(body: Body, grid: TileGrid) -> bool:
	if not body._box_blocked(grid, body._left_x(), body._top_y(), body._right_x(), body._bottom_y()):
		return false
	var nudge_dir: int = signi(body.vel_x) if body.vel_x != 0 else body.facing
	var nudge: int = nudge_dir * Body.CORNER_NUDGE_PX * Fx.SCALE
	# D0059c: `is_solid` is a sparse lookup -- a cell past the grid's own width/height reads as open,
	# not solid, so nothing stopped the nudge from carrying the body past the world edge (`_try_step`
	# already refuses a move crossing row 0 the same way, D0055).
	var in_bounds: bool = (body._left_x() + nudge >= 0 and
		body._right_x() + nudge <= grid.width * Body.CELL_PX * Fx.SCALE)
	if in_bounds and not body._box_blocked(
			grid, body._left_x() + nudge, body._top_y(), body._right_x() + nudge, body._bottom_y()):
		body.pos_x += nudge
		body.corner_corrected_this_tick = true
		return false
	body.vel_y = 0
	return true


## D0059f: `surface_y_at_x` reports `NO_FLOOR` when a foot sample straddles a real gap (a ramp can't
## blend into a hole) -- correct for its own contract, but a wide body's three sample points can ALL
## straddle a pit's own lip while most of the footprint sits over real ground there. Grid-solidity
## backstop, the authority `resolve_ceiling`/`_try_step` already trust, for the case the sub-pixel
## ground plane's own contract can't answer -- snaps to the TOPMOST solid row in the box's footprint.
static func grid_floor_backstop(body: Body, grid: TileGrid) -> bool:
	if not body._box_blocked(grid, body._left_x(), body._top_y(), body._right_x(), body._bottom_y()):
		return false
	var lo_col: int = Body._px_to_cell(body._left_x())
	var hi_col: int = Body._px_to_cell(body._right_x() - 1)
	var hi_row: int = Body._px_to_cell(body._bottom_y() - 1)
	var top_row: int = _topmost_solid_row(grid, Body._px_to_cell(body._top_y()), hi_row, lo_col, hi_col)
	if _has_deferred_floor_below(body, grid, lo_col, hi_col, top_row):
		return false
	body.pos_y = Fx.from_int(top_row * Body.CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2
	body.vel_y = 0
	body.on_floor = true
	body.floor_source_this_tick = &"grid_floor_backstop"
	return true


## The topmost solid row across [lo_col, hi_col], scanning rows [row_start, hi_row]; `hi_row + 1`
## ("none found") if the whole scanned range is open. Extracted 2026-08-28 (`docs/DECISIONS_LEDGER.md`
## D0100) from `grid_floor_backstop`'s own first loop, a pure Extract Method -- no logic changed.
static func _topmost_solid_row(grid: TileGrid, row_start: int, hi_row: int, lo_col: int, hi_col: int) -> int:
	var top_row: int = hi_row + 1
	for row: int in range(row_start, hi_row + 1):
		for col: int in range(lo_col, hi_col + 1):
			if grid.is_solid(Vector2i(col, row)):
				top_row = row
				break
		if top_row <= hi_row:
			break
	return top_row


## True iff some OPEN column at `top_row` has a real, unreached floor further down -- an ordinary gap
## with a lower floor (docs/adr/0005's overhang), not a pit lip, so the caller should defer so the fall
## reaches that floor rather than snapping to `top_row`. Extracted 2026-08-28 (D0100) from
## `grid_floor_backstop`'s own second loop, a pure Extract Method -- no logic changed.
static func _has_deferred_floor_below(body: Body, grid: TileGrid, lo_col: int, hi_col: int, top_row: int) -> bool:
	for col: int in range(lo_col, hi_col + 1):
		if grid.is_solid(Vector2i(col, top_row)):
			continue
		var deeper: int = Heightfield.column_surface_y(grid, col, top_row, Body.FLOOR_SCAN_ROWS)
		if deeper != Heightfield.NO_FLOOR and body._bottom_y() < deeper:
			return true
	return false


## Mirrors `tests/property_checks.gd::grounded_implies_solid_beneath`'s own full-footprint check --
## DUPLICATED, not called: `sim/` cannot depend on `tests/` (that predicate is deliberately TEST-ONLY,
## a signal for the harness to catch a violation after the fact, never a shipped correction path --
## this is the opposite direction, the RESOLVER establishing the same condition before it ever creates
## a violating state). `landing_row` is the row `surface` would place the body's own `_bottom_y()` at,
## checked BEFORE `resolve_floor` commits to the move. If this drifts out of sync with
## `grounded_implies_solid_beneath`'s own logic, keep both in mind together -- they must describe the
## same property (D0139).
static func _full_footprint_solid(body: Body, grid: TileGrid, surface: int) -> bool:
	var landing_row: int = Body._px_to_cell(surface)
	var left_col: int = Body._px_to_cell(body._left_x())
	var right_col: int = Body._px_to_cell(body._right_x() - 1)
	for col: int in range(left_col, right_col + 1):
		if not grid.is_solid(Vector2i(col, landing_row)):
			return false
	return true


## The ground plane: sample the heightfield under both feet and the centre, rest on whichever is
## highest (smallest Fx `y`) -- matches `legacy/scenes/player.gd`'s `_follow_slope` sampling rule,
## adapted to a continuous heightfield instead of an authored ramp overlay. `NO_FLOOR` at all three
## means open air: falling continues, `on_floor` stays false.
static func resolve_floor(body: Body, grid: TileGrid) -> bool:
	var row: int = Body._px_to_cell(body._bottom_y())
	var scan_from: int = maxi(0, row - 2)
	var s_left: int = Heightfield.surface_y_at_x(
		grid, body._left_x() + Fx.SCALE, scan_from, Body.FLOOR_SCAN_ROWS)
	var s_right: int = Heightfield.surface_y_at_x(
		grid, body._right_x() - Fx.SCALE, scan_from, Body.FLOOR_SCAN_ROWS)
	var s_center: int = Heightfield.surface_y_at_x(grid, body.pos_x, scan_from, Body.FLOOR_SCAN_ROWS)
	var surface: int = mini(mini(s_left, s_right), s_center)
	if surface == Heightfield.NO_FLOOR or body._bottom_y() < surface:
		body.on_floor = false
		return false
	# D0139: the three-sample `surface` above is a PROXY for "is the whole footprint supported" --
	# D0137/D0138 found it can be wrong (any one real sample lets the whole box land, even when the
	# other samples correctly saw open air). `_full_footprint_solid` checks the ACTUAL property
	# `tests/property_checks.gd::grounded_implies_solid_beneath` verifies, at the row `surface` is
	# about to place the body on -- resolving_floor now ESTABLISHES that invariant instead of
	# approximating it, so a partial-footprint landing defers to `grid_floor_backstop` instead of
	# ever existing as a violating state.
	if not _full_footprint_solid(body, grid, surface):
		body.on_floor = false
		return false
	# Diagnostic only -- does not change which floor gets picked. docs/adr/0005 measured this
	# ambiguity in real terrain and accepted it as a documented limitation rather than building
	# stateful floor tracking; this is what turns a silent wrong-floor bug report into a reproducible,
	# position-and-seed-logged one. Checks the column nearest `pos_x` only, not every column the three
	# foot samples straddle -- a scoped first pass, not full coverage (docs/DECISIONS_LEDGER.md D0043).
	# Shares FLOOR_SCAN_ROWS with the resolve calls above on purpose (D0044) -- this check exists to
	# answer "did the query that just picked a floor also see another one," which is only a true answer
	# if it's given the SAME window that query used.
	var check_col: int = Body._px_to_cell(body.pos_x)
	var chosen_row: int = Heightfield._column_top_row(grid, check_col, scan_from, Body.FLOOR_SCAN_ROWS)
	if chosen_row >= 0:
		var violation: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
			grid, check_col, scan_from, Body.FLOOR_SCAN_ROWS, chosen_row, Body.HEIGHT_PX / Body.CELL_PX)
		# Rate-limited HERE, at the caller, not inside Invariants (D0052) -- sim/invariants stays
		# stateless by design, and body.gd already tracks its own position every tick, so the memory
		# for "have I already reported THIS (column, floor) pair" belongs where the context already is.
		# Without this, a body resting on one ambiguous floor logs the identical violation on nearly
		# every call to this block -- measured directly by mutation-testing this exact gate (temporarily
		# reverting it to unconditional reporting): 778 push_errors from one ~400-tick settle in
		# tests/test_cave_geometry.gd, not merely once per tick -- `move_and_resolve` calls
		# `resolve_floor` twice on most resting ticks (once inside the substep loop, once via its own
		# trailing catch-all), and this gate suppresses both, not just inter-tick repeats. A real
		# occurrence would bury itself in its own repetition, and the log volume would make a genuine
		# incidence count impossible to derive from real play. Clearing to -1 when the violation clears
		# (not just remembering the LAST reported pair) means a resolve-then-recur at the exact same
		# (column, floor) is a fresh occurrence, correctly: it did stop and start again, not continue.
		body.floor_selection_violation_this_tick = violation != null
		if violation == null:
			body._last_violation_col = -1; body._last_violation_row = -1
		elif violation.column != body._last_violation_col or violation.chosen_floor_row != body._last_violation_row:
			Invariants.report_floor_selection(grid, check_col, scan_from, Body.FLOOR_SCAN_ROWS,
				chosen_row, Body.HEIGHT_PX / Body.CELL_PX, grid.seed, body.pos_x, body.pos_y)
			body._last_violation_col = check_col
			body._last_violation_row = chosen_row
	body.pos_y = surface - (Body.HEIGHT_PX * Fx.SCALE) / 2
	body.vel_y = 0
	body.on_floor = true; body.floor_source_this_tick = &"resolve_floor"
	return true
