class_name VerticalResolve
extends RefCounted

## Split out of `body.gd` (D0060) once the 400-line file-size gate (`docs/QUALITY.md` gate 3) could no
## longer be met by comment trimming alone without cutting load-bearing WHY reasoning -- an internal file
## of the `body` module, same as `heightfield.gd`/`input_frame.gd` already are (`tools/layer_lint/
## layer_lint.py`'s "no sibling reach-in" rule only requires outside code to go through `body.gd`; files
## inside `sim/body/` reaching each other's -- and `Body`'s own, GDScript has no real privacy --
## underscore-prefixed members is the same shape those two files already use). Pure vertical-axis
## collision resolution: ceilings (grid-swept, hard) and the ground plane (`Heightfield`, read per column
## across the box's whole footprint, plus a grid-solidity backstop that de-penetrates a box already
## inside rock). Every function takes `body: Body` explicitly rather than being instance methods on
## `Body` itself -- that's the whole point of the split.
##
## D0206: the ground plane used to be sub-pixel, interpolating `Heightfield` between column centres.
## It cannot be, for a flat-bottomed collider -- `footprint_surface_y` carries the proof and the
## measurement. `Heightfield.surface_y_at_x` still exists and is still tested; nothing in `sim/` calls
## it any more.

const V_SUBSTEP_PX: int = 2  ## Comfortably under one terrain cell (4px), so no substep can cross more
                              ## than one row boundary and skip past it -- the fixed-tick equivalent of
                              ## `legacy/scenes/player.gd`'s `MAX_SUBSTEP` clamp, needed because
                              ## `MAX_FALL_PX_S` alone covers more than one cell per 60Hz tick.


## Vertical movement, substepped so a fast fall or jump cannot tunnel through a one-cell-thick floor or
## ceiling. Ceilings are grid-swept and hard; the ground plane is `Heightfield`, read per column across
## the box's full footprint (`footprint_surface_y`).
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
	# D0206. This path snaps to the topmost solid row ANYWHERE in the box, which is right for the
	# de-penetration it exists for -- a body buried in a solid mass gets pushed up onto its surface --
	# and catastrophically wrong when that topmost solid is a CEILING the head is inside: it then places
	# the FEET on the ceiling's own top face, and for the world's ceiling row that face is y=0, putting
	# the whole body above the world. 153 of the 184 bad ticks across the director's two recorded
	# sessions are that one event: the ejection at tick 598 of the 767-tick session, and every tick after
	# it. Checking the DESTINATION is what separates the two cases; the scan itself is deliberately left
	# alone, because scanning from the box's top is exactly what the de-penetration case needs.
	var candidate: int = Fx.from_int(top_row * Body.CELL_PX) - (Body.HEIGHT_PX * Fx.SCALE) / 2
	if not _landing_is_clear(body, grid, candidate):
		return false
	body.pos_y = candidate
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


## THE SHARED CRITERION (D0206) -- the one height either grounding path in this file may put the body's
## feet at: the highest (smallest Fx `y`) solid top face across EVERY column the box occupies, or
## `NO_FLOOR` when no column has one in range.
##
## Why this is forced rather than chosen. The box's bottom edge spans `[left_x, right_x)`, and it
## overlaps no solid cell exactly when, for every column `c` beneath it, that edge sits at or above
## `c`'s topmost solid face. So the lowest legal bottom IS the minimum of those faces, and any value
## below it is inside some column's rock. `Heightfield.surface_y_at_x` interpolates BETWEEN two columns'
## faces, so wherever the footprint spans columns of different heights it returns a height below that
## minimum: sub-pixel ground following and a zero-overlap flat-bottomed box are mutually exclusive, and
## `docs/DECISIONS_LEDGER.md` D0032 already chose the flat-bottomed box. Measured, not only argued -- 13
## of the 184 bad ticks across the director's two recorded sessions are the feet sunk up to 0.75px into
## a ledge exactly this way.
##
## It erred the other way too, and that half was the expensive one. The blend anchors on column CENTRES,
## so a foot sample near the box's edge mixes in the neighbouring column OUTSIDE the footprint -- ground
## the body is not standing on. Where that neighbour is taller the body was lifted ABOVE its real floor:
## 10 more bad ticks, every one of them the head pushed up into the world's ceiling row in a shaft
## almost exactly one body-height tall, which is what then handed `grid_floor_backstop` a ceiling to
## mistake for a floor (153 more -- see its own note).
##
## Reading each column on its own also answers D0059f's original complaint head-on, which matters
## because that complaint is the whole reason `grid_floor_backstop` exists: `surface_y_at_x` returns
## `NO_FLOOR` if EITHER straddled column lacks a floor, so a body over a pit's lip could read "no
## ground" at all three samples while most of its footprint stood on real ground. A per-column minimum
## cannot do that -- a floorless column contributes `NO_FLOOR` to a `mini`, and the columns that do have
## ground decide the answer.
static func footprint_surface_y(body: Body, grid: TileGrid, scan_from: int) -> int:
	var surface: int = Heightfield.NO_FLOOR
	for col: int in range(Body._px_to_cell(body._left_x()), Body._px_to_cell(body._right_x() - 1) + 1):
		surface = mini(surface, Heightfield.column_surface_y(grid, col, scan_from, Body.FLOOR_SCAN_ROWS))
	return surface


## The post-condition D0206 makes both grounding paths establish BEFORE they commit, so that neither can
## hand `Invariants` a state to catch: the box at `candidate_pos_y` lies inside the world and overlaps
## nothing solid. Testing bounds separately is not belt-and-braces -- `is_solid` is a sparse lookup and
## every cell past the grid's edge reads OPEN, not solid (D0059c's own trap, one function up), so a snap
## that leaves the world is "unblocked" precisely BECAUSE it left.
static func _landing_is_clear(body: Body, grid: TileGrid, candidate_pos_y: int) -> bool:
	var half: int = (Body.HEIGHT_PX * Fx.SCALE) / 2
	if candidate_pos_y - half < 0 or candidate_pos_y + half > Fx.from_int(grid.height * Body.CELL_PX):
		return false
	return not body._box_blocked(grid, body._left_x(), candidate_pos_y - half,
		body._right_x(), candidate_pos_y + half)


## The ground plane: rest the box on the highest solid surface across its OWN FULL FOOTPRINT, which for
## a flat-bottomed collider is the only height that does not put part of it inside rock (see
## `footprint_surface_y` for why that is a proof and not a preference). `NO_FLOOR` under every column
## means open air: falling continues, `on_floor` stays false.
##
## D0206 replaced the three interpolated sample points that stood here -- both feet and the centre,
## `mini` of the three, ported from `legacy/scenes/player.gd`'s `_follow_slope` rule. Legacy sampled an
## AUTHORED ramp overlay whose heights were continuous by construction; a derived heightfield over a
## 4px grid is a step function, and interpolating one is what put the body inside it. The sample count
## was wrong too, independently: three points cannot cover the FOUR columns a 16px-wide box occupies.
static func resolve_floor(body: Body, grid: TileGrid) -> bool:
	var row: int = Body._px_to_cell(body._bottom_y())
	var scan_from: int = maxi(0, row - 2)
	var surface: int = footprint_surface_y(body, grid, scan_from)
	if surface == Heightfield.NO_FLOOR or body._bottom_y() < surface:
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
