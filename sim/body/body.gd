class_name Body
extends RefCounted

## Player kinematics: fixed 60Hz tick, no `delta` (`docs/ARCHITECTURE.md` §4), every state-affecting
## value `Fx`. Collides against `TileGrid` two ways: the ground plane is `Heightfield` (sub-pixel,
## §9's "80% version" of a polygon contour), everything else -- walls, ceilings -- is grid-swept
## against `TileGrid.is_solid()` directly, exactly as §9 specifies ("nearly all edge-catching lives on
## the ground plane... ceilings and walls stay grid-swept").
##
## Driven by `InputFrame`, not a real `interface.apply(Command)` -- `interface` doesn't exist yet.
## `docs/ONBOARDING.md`: this is deliberately built as the raw input-frame path from the start, so it
## becomes `observe`/`apply`'s raw action level rather than being thrown away once `interface` lands.
##
## Collider shape: EXPENSIVE, unresolved on purpose. `docs/ARCHITECTURE.md` §9 says capsule or rounded
## AABB; this file uses a flat-bottomed axis-aligned box, because the heightfield ground plane needs a
## flat contact edge to sample a single surface height against -- a rounded capsule's curved bottom has
## no single well-defined foot point without extra geometry this stage doesn't build. Flagged, not
## decided: `docs/DECISIONS_LEDGER.md` D0032.

const WIDTH_PX: int = 16   ## 1 tile (docs/ARCHITECTURE.md §9)
const HEIGHT_PX: int = 40  ## 2.5 tiles
const CELL_PX: int = Heightfield.TERRAIN_CELL_PX

## Feel constants. RUN_SPEED/GRAVITY/JUMP_VELOCITY/MAX_FALL are not stated in ARCHITECTURE §9's table
## (only tick-counts and ratios are) -- ported from legacy/scenes/player.gd's tuning as the starting
## point ONBOARDING.md asks for ("keep the feel constants as a starting point and then measure"). Every
## OTHER constant below is §9's own stated value, converted from a tick-count/ratio to a per-tick Fx
## delta -- these override legacy's continuous-time constants where the two disagree, since §9 is the
## normative spec for this stage, not legacy's tuning.
const RUN_SPEED_PX_S: int = 150
const GRAVITY_PX_S2: int = 900
const JUMP_VELOCITY_PX_S: int = -365
const MAX_FALL_PX_S: int = 560
const TICK_HZ: int = 60

const RUN_SPEED: int = RUN_SPEED_PX_S * Fx.SCALE
const GRAVITY_PER_TICK: int = (GRAVITY_PX_S2 * Fx.SCALE) / TICK_HZ
const JUMP_VELOCITY: int = JUMP_VELOCITY_PX_S * Fx.SCALE
const MAX_FALL: int = MAX_FALL_PX_S * Fx.SCALE
const GROUND_ACCEL_TICKS: int = 8    ## docs/ARCHITECTURE.md §9
const GROUND_DECEL_TICKS: int = 4
const ACCEL_PER_TICK: int = RUN_SPEED / GROUND_ACCEL_TICKS
const DECEL_PER_TICK: int = RUN_SPEED / GROUND_DECEL_TICKS
const AIR_CONTROL_NUM: int = 3       ## 60% of ground accel, as a plain-int ratio (no Fx needed: an
const AIR_CONTROL_DEN: int = 5       ## int*int/int, not two Fx values multiplied)
const COYOTE_TICKS: int = 6
const JUMP_BUFFER_TICKS: int = 6
const JUMP_CUT_MULT_NUM: int = 2     ## release cuts upward velocity to 40% == 2/5
const JUMP_CUT_MULT_DEN: int = 5
const APEX_FLOAT_TICKS: int = 3      ## gravity x0.6 within this many ticks of the apex, either side
const APEX_FLOAT_MULT_NUM: int = 3
const APEX_FLOAT_MULT_DEN: int = 5
const APEX_BAND: int = APEX_FLOAT_TICKS * GRAVITY_PER_TICK  ## |vel_y| under this counts as "near apex"
## "1 tile"/"2 tiles" in docs/ARCHITECTURE.md §9's movement table means the 16px machine/logic tile (the
## same unit the table's own collider row uses: "1 tile wide, 2.5 tall" == WIDTH_PX/HEIGHT_PX above),
## NOT the 4px terrain cell `CELL_PX` names -- a step-up of 4px would be a quarter of what §9 specifies.
const LOGIC_TILE_PX: int = 16
const STEP_UP_PX: int = LOGIC_TILE_PX        ## 1 tile, docs/ARCHITECTURE.md §9
const MANTLE_PX: int = LOGIC_TILE_PX * 2     ## 2 tiles
const CORNER_NUDGE_PX: int = 6       ## docs/ARCHITECTURE.md §9

## `_resolve_floor`'s local scan window, in terrain rows. Widened from an original 6 to cover the real
## vertical gap between two genuinely-reachable stacked floors, measured directly rather than assumed:
## re-running D0042's own reachability analysis (real `ShaftGenerator` output, `shallow_clay`, 100
## seeds) and this time recording the row-gap between a reachable column's own two floors gives min=11,
## p50=16, p90=23, p95=24, p99=36, max=36 across 197 samples. 48 covers the observed max with headroom;
## the original 6 could not see anything past row-2..row+4 and reported zero by construction, not by
## measurement (D0044). Confirmed safe for ordinary single-floor falling, not just for this new case:
## `_bottom_y() < surface` below still refuses to snap onto ANY candidate the body hasn't physically
## reached yet regardless of window width, so widening only ever lets this query see further, it never
## changes which floor a body resting on solid, unambiguous ground gets assigned -- verified by full
## acceptance-suite re-run at this width, unchanged from the narrow window (D0044).
const FLOOR_SCAN_ROWS: int = 48

var pos_x: int
var pos_y: int
var vel_x: int = 0
var vel_y: int = 0
var facing: int = 1
var on_floor: bool = false
var _coyote_ticks_left: int = 0
var _jump_buffer_ticks_left: int = 0
var _was_jump_held: bool = false

## Rate-limits `Invariants.report_floor_selection` to once per distinct (column, floor) pair rather than
## once per tick -- D0052. `sim/invariants` stays stateless by design (its own MODULE.md: "produces no
## gameplay state itself"), so this memory lives here, in the caller that already tracks the body's own
## position every tick, not in the check module. -1 is not a valid column or row, so it never collides
## with a real violation and correctly reads as "no active violation" at construction.
var _last_violation_col: int = -1
var _last_violation_row: int = -1

var _had_bounds_violation: bool = false  ## D0052 pattern again: one excursion latch, no sub-cases

## Per-tick telemetry, read once by the caller and not cleared automatically -- the caller (the
## acceptance driver) resets what it needs each tick. Exists so the acceptance suite can count events
## without `body.gd` knowing anything about scenarios, metrics, or telemetry schemas.
var stepped_up_this_tick: bool = false
var mantled_this_tick: bool = false
var corner_corrected_this_tick: bool = false
var edge_caught_this_tick: bool = false
var depenetrated_this_tick: bool = false


func _init(start_x: int, start_y: int) -> void:
	pos_x = start_x
	pos_y = start_y


func _left_x() -> int:
	return pos_x - (WIDTH_PX * Fx.SCALE) / 2


func _right_x() -> int:
	return pos_x + (WIDTH_PX * Fx.SCALE) / 2


func _top_y() -> int:
	return pos_y - (HEIGHT_PX * Fx.SCALE) / 2


func _bottom_y() -> int:
	return pos_y + (HEIGHT_PX * Fx.SCALE) / 2


static func _px_to_cell(px: int) -> int:
	return int(floor(float(px) / float(CELL_PX * Fx.SCALE)))


## A cell blocks movement if solid. Machine clusters (`docs/ARCHITECTURE.md` §9: "non-solid to the
## player except a 1-tile base") are not modelled yet -- no `sim/machines` exists -- so the chamber
## stands machine footprints in with solid terrain and this treats every solid cell alike.
func _blocked(grid: TileGrid, terrain_cell: Vector2i) -> bool:
	return grid.is_solid(terrain_cell)


## True if any blocked cell overlaps the box [left,right)x[top,bottom) (Fx px). Used for head-clearance
## checks before an auto step-up or mantle commits to a new position.
func _box_blocked(grid: TileGrid, left: int, top: int, right: int, bottom: int) -> bool:
	var lo: Vector2i = Vector2i(_px_to_cell(left), _px_to_cell(top))
	var hi: Vector2i = Vector2i(_px_to_cell(right - 1), _px_to_cell(bottom - 1))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			if _blocked(grid, Vector2i(cx, cy)):
				return true
	return false


## One fixed 60Hz tick. Order: horizontal integrate+move+collide, vertical integrate+move+collide.
## Matches `docs/ARCHITECTURE.md` §4's phase order at body's own scope (input already read into
## `input`; body never polls a device).
func tick(input: InputFrame, grid: TileGrid) -> void:
	stepped_up_this_tick = false
	mantled_this_tick = false
	corner_corrected_this_tick = false
	edge_caught_this_tick = false
	depenetrated_this_tick = false

	_integrate_horizontal(input)
	pos_x += vel_x / TICK_HZ
	_resolve_horizontal(grid, input)

	_integrate_vertical()
	_move_and_resolve_vertical(grid)

	# Jump is handled AFTER vertical resolve, not before: a buffered jump has to see THIS tick's own
	# landing, not the previous tick's `on_floor` -- checking it earlier meant a jump buffered right up
	# to touchdown could only ever fire one tick late, since the landing that should satisfy it hadn't
	# happened yet in the tick's own dataflow. Overriding a just-landed vel_y=0 here is a one-tick
	# touch-and-go: the position this tick is still correctly on the ground, only next tick's
	# integration reflects the jump.
	_handle_jump(input)
	_enforce_grid_bounds(grid)

	_coyote_ticks_left = COYOTE_TICKS if on_floor else maxi(0, _coyote_ticks_left - 1)
	_jump_buffer_ticks_left = maxi(0, _jump_buffer_ticks_left - 1)


func _integrate_horizontal(input: InputFrame) -> void:
	var accel: int = ACCEL_PER_TICK
	var decel: int = DECEL_PER_TICK
	if not on_floor:
		accel = (accel * AIR_CONTROL_NUM) / AIR_CONTROL_DEN
		decel = (decel * AIR_CONTROL_NUM) / AIR_CONTROL_DEN
	if input.move_dir != 0:
		facing = input.move_dir
		var target: int = input.move_dir * RUN_SPEED
		if vel_x < target:
			vel_x = mini(target, vel_x + accel)
		else:
			vel_x = maxi(target, vel_x - accel)
	elif vel_x > 0:
		vel_x = maxi(0, vel_x - decel)
	elif vel_x < 0:
		vel_x = mini(0, vel_x + decel)


func _integrate_vertical() -> void:
	var g: int = GRAVITY_PER_TICK
	if absi(vel_y) < APEX_BAND:
		g = (g * APEX_FLOAT_MULT_NUM) / APEX_FLOAT_MULT_DEN
	vel_y = mini(vel_y + g, MAX_FALL)


## Coyote time, jump buffer, variable jump height (release cuts upward velocity, not a continuous
## gravity multiplier -- docs/ARCHITECTURE.md §9 states the cut as a ratio of current velocity, applied
## once on release, which is what this does).
func _handle_jump(input: InputFrame) -> void:
	if input.jump_pressed:
		_jump_buffer_ticks_left = JUMP_BUFFER_TICKS
	if _jump_buffer_ticks_left > 0 and (on_floor or _coyote_ticks_left > 0):
		vel_y = JUMP_VELOCITY
		on_floor = false
		_coyote_ticks_left = 0
		_jump_buffer_ticks_left = 0
	elif vel_y < 0 and _was_jump_held and not input.jump_held:
		vel_y = (vel_y * JUMP_CUT_MULT_NUM) / JUMP_CUT_MULT_DEN
	_was_jump_held = input.jump_held


## Auto step-up (1 tile) and mantle (2 tiles): raise the body by `lift` if the space it would occupy at
## that height is clear. Both call this identically -- the only difference is which caller allows a
## larger `lift` and under what input condition, per docs/ARCHITECTURE.md §9.
##
## D0055: refuses a lift crossing row 0, BEFORE moving -- correcting after the fact alone left the body
## oscillating forever against the same wall (measured: 258 ticks); this falls through to the normal
## depenetration/stop path instead, as if solid rock were there.
func _try_step(grid: TileGrid, lift: int) -> bool:
	if _top_y() - lift < 0:
		return false
	if _box_blocked(grid, _left_x(), _top_y() - lift, _right_x(), _bottom_y() - lift):
		return false
	pos_y -= lift
	on_floor = true
	return true


## Ledge-vs-ceiling classifier: shallower in Y than in X, AND the blocking cell's centre is BELOW the
## body's centre, means the body is clipping the TOP of a block under it -- a ledge to land on, not a
## wall. The identical overlap shape with the cell ABOVE the body's centre is a ceiling clip, which is
## NOT exempted -- `legacy/scenes/player.gd`'s own fixed bug (docs/ARCHITECTURE.md §9's design lineage)
## was this classifier missing the second half of that comparison.
func _resolve_horizontal(grid: TileGrid, input: InputFrame) -> void:
	var moving_right: bool = vel_x > 0
	var lo: Vector2i = Vector2i(_px_to_cell(_left_x()), _px_to_cell(_top_y()))
	var hi: Vector2i = Vector2i(_px_to_cell(_right_x() - 1), _px_to_cell(_bottom_y() - 1))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			var cell := Vector2i(cx, cy)
			if not _blocked(grid, cell):
				continue
			var cell_left: int = cx * CELL_PX * Fx.SCALE
			var cell_top: int = cy * CELL_PX * Fx.SCALE
			var cell_right: int = cell_left + CELL_PX * Fx.SCALE
			var cell_bottom: int = cell_top + CELL_PX * Fx.SCALE
			var left: int = _left_x(); var right: int = _right_x()
			var top: int = _top_y(); var bottom: int = _bottom_y()
			if left >= cell_right or right <= cell_left or top >= cell_bottom or bottom <= cell_top:
				continue
			var ov_x: int = mini(right, cell_right) - maxi(left, cell_left)
			var ov_y: int = mini(bottom, cell_bottom) - maxi(top, cell_top)
			if ov_x > ov_y and (cell_top + cell_bottom) / 2 > pos_y:
				continue  # a ledge beneath the body -- the vertical resolve lands it, not a wall
			var lift: int = bottom - cell_top
			if vel_x != 0 and lift <= STEP_UP_PX * Fx.SCALE and _try_step(grid, lift):
				stepped_up_this_tick = true
				continue
			if vel_x != 0 and lift <= MANTLE_PX * Fx.SCALE and input.mantle_hold and _try_step(grid, lift):
				mantled_this_tick = true
				continue
			if vel_x != 0 and lift <= STEP_UP_PX * Fx.SCALE:
				edge_caught_this_tick = true  # should have been walkable; head clearance refused it
			pos_x += (cell_left - right) if moving_right else (cell_right - left)
			depenetrated_this_tick = true
			vel_x = 0


const V_SUBSTEP_PX: int = 2  ## Comfortably under one terrain cell (4px), so no substep can cross more
                              ## than one row boundary and skip past it -- the fixed-tick equivalent of
                              ## `legacy/scenes/player.gd`'s `MAX_SUBSTEP` clamp, needed because
                              ## `MAX_FALL_PX_S` alone covers more than one cell per 60Hz tick.


## Vertical movement, substepped so a fast fall or jump cannot tunnel through a one-cell-thick floor or
## ceiling. Ceilings are grid-swept and hard; the ground plane is `Heightfield`, sub-pixel.
func _move_and_resolve_vertical(grid: TileGrid) -> void:
	var total: int = vel_y / TICK_HZ
	var dir: int = signi(total)
	if dir != 0:
		on_floor = false
	var remaining: int = absi(total)
	var substep: int = V_SUBSTEP_PX * Fx.SCALE
	while remaining > 0 and dir != 0:
		var move: int = mini(remaining, substep)
		pos_y += dir * move
		remaining -= move
		var stopped: bool = _resolve_ceiling(grid) if dir < 0 else _resolve_floor(grid)
		if stopped:
			break
	if dir >= 0:
		_resolve_floor(grid)  ## also catches a body at rest (dir == 0) every tick, per-column


## Hard grid-swept ceiling block, with corner correction: a horizontal nudge up to 6px toward the
## direction the body is already moving, tried before blocking outright, since a ceiling contact right
## at a corner is exactly the case docs/ARCHITECTURE.md §9 names this mechanic for.
func _resolve_ceiling(grid: TileGrid) -> bool:
	if not _box_blocked(grid, _left_x(), _top_y(), _right_x(), _bottom_y()):
		return false
	var nudge_dir: int = signi(vel_x) if vel_x != 0 else facing
	var nudge: int = nudge_dir * CORNER_NUDGE_PX * Fx.SCALE
	if not _box_blocked(grid, _left_x() + nudge, _top_y(), _right_x() + nudge, _bottom_y()):
		pos_x += nudge
		corner_corrected_this_tick = true
		return false
	vel_y = 0
	return true


## The ground plane: sample the heightfield under both feet and the centre, rest on whichever is
## highest (smallest Fx `y`) -- matches `legacy/scenes/player.gd`'s `_follow_slope` sampling rule,
## adapted to a continuous heightfield instead of an authored ramp overlay. `NO_FLOOR` at all three
## means open air: falling continues, `on_floor` stays false.
func _resolve_floor(grid: TileGrid) -> bool:
	var row: int = _px_to_cell(_bottom_y())
	var scan_from: int = maxi(0, row - 2)
	var s_left: int = Heightfield.surface_y_at_x(grid, _left_x() + Fx.SCALE, scan_from, FLOOR_SCAN_ROWS)
	var s_right: int = Heightfield.surface_y_at_x(grid, _right_x() - Fx.SCALE, scan_from, FLOOR_SCAN_ROWS)
	var s_center: int = Heightfield.surface_y_at_x(grid, pos_x, scan_from, FLOOR_SCAN_ROWS)
	var surface: int = mini(mini(s_left, s_right), s_center)
	if surface == Heightfield.NO_FLOOR or _bottom_y() < surface:
		on_floor = false
		return false
	# Diagnostic only -- does not change which floor gets picked. docs/adr/0005 measured this
	# ambiguity in real terrain and accepted it as a documented limitation rather than building
	# stateful floor tracking; this is what turns a silent wrong-floor bug report into a reproducible,
	# position-and-seed-logged one. Checks the column nearest `pos_x` only, not every column the three
	# foot samples straddle -- a scoped first pass, not full coverage (docs/DECISIONS_LEDGER.md D0043).
	# Shares FLOOR_SCAN_ROWS with the resolve calls above on purpose (D0044) -- this check exists to
	# answer "did the query that just picked a floor also see another one," which is only a true answer
	# if it's given the SAME window that query used.
	var check_col: int = _px_to_cell(pos_x)
	var chosen_row: int = Heightfield._column_top_row(grid, check_col, scan_from, FLOOR_SCAN_ROWS)
	if chosen_row >= 0:
		var violation: Invariants.FloorSelectionViolation = Invariants.check_floor_selection(
			grid, check_col, scan_from, FLOOR_SCAN_ROWS, chosen_row, HEIGHT_PX / CELL_PX)
		# Rate-limited HERE, at the caller, not inside Invariants (D0052) -- sim/invariants stays
		# stateless by design, and body.gd already tracks its own position every tick, so the memory
		# for "have I already reported THIS (column, floor) pair" belongs where the context already is.
		# Without this, a body resting on one ambiguous floor logs the identical violation on nearly
		# every call to this block -- measured directly by mutation-testing this exact gate (temporarily
		# reverting it to unconditional reporting): 778 push_errors from one ~400-tick settle in
		# tests/test_cave_geometry.gd, not merely once per tick -- `_move_and_resolve_vertical` calls
		# `_resolve_floor` twice on most resting ticks (once inside the substep loop, once via its own
		# trailing catch-all), and this gate suppresses both, not just inter-tick repeats. A real
		# occurrence would bury itself in its own repetition, and the log volume would make a genuine
		# incidence count impossible to derive from real play. Clearing to -1 when the violation clears
		# (rather than only ever remembering the LAST reported pair) means a condition that resolves and later
		# recurs -- even at the exact same (column, floor) -- is treated as a fresh occurrence, which
		# is the right call: it did stop and start again, that's a second episode, not a continuation.
		if violation == null:
			_last_violation_col = -1
			_last_violation_row = -1
		elif violation.column != _last_violation_col or violation.chosen_floor_row != _last_violation_row:
			Invariants.report_floor_selection(
				grid, check_col, scan_from, FLOOR_SCAN_ROWS, chosen_row, HEIGHT_PX / CELL_PX, grid.seed, pos_x, pos_y)
			_last_violation_col = check_col
			_last_violation_row = chosen_row
	pos_y = surface - (HEIGHT_PX * Fx.SCALE) / 2
	vel_y = 0
	on_floor = true
	return true


## World boundary, not terrain -- D0055 has the root cause. Called last in `tick()`. Reports via
## `Invariants` (rate-limited, D0052's pattern) BEFORE correcting -- silent clamping would hide this.
func _enforce_grid_bounds(grid: TileGrid) -> void:
	var grid_max_x: int = grid.width * CELL_PX * Fx.SCALE
	var grid_max_y: int = grid.height * CELL_PX * Fx.SCALE
	var violation: Invariants.BoundsViolation = Invariants.check_bounds(
		0, 0, grid_max_x, grid_max_y, _left_x(), _top_y(), _right_x(), _bottom_y())
	if violation == null:
		_had_bounds_violation = false
	elif not _had_bounds_violation:
		Invariants.report_bounds(0, 0, grid_max_x, grid_max_y,
			_left_x(), _top_y(), _right_x(), _bottom_y(), grid.seed, pos_x, pos_y)
		_had_bounds_violation = true
	if _left_x() < 0:  # correction itself is never rate-limited
		pos_x = (WIDTH_PX * Fx.SCALE) / 2
		vel_x = maxi(vel_x, 0)
	elif _right_x() > grid_max_x:
		pos_x = grid_max_x - (WIDTH_PX * Fx.SCALE) / 2
		vel_x = mini(vel_x, 0)
	if _top_y() < 0:
		pos_y = (HEIGHT_PX * Fx.SCALE) / 2
		vel_y = maxi(vel_y, 0)
	elif _bottom_y() > grid_max_y:
		pos_y = grid_max_y - (HEIGHT_PX * Fx.SCALE) / 2
		vel_y = 0
		on_floor = true
