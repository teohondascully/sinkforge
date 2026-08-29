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
var _had_bounds_violation: bool = false  ## same D0052 pattern: one excursion latch, no sub-cases
## Per-tick telemetry, read by the caller, not auto-cleared -- so a caller can count events without
## `body.gd` knowing anything about scenarios, metrics, or telemetry schemas.
var stepped_up_this_tick: bool = false
var mantled_this_tick: bool = false
var corner_corrected_this_tick: bool = false
var edge_caught_this_tick: bool = false
var depenetrated_this_tick: bool = false
var floor_source_this_tick: StringName = &""  ## D0132: which call set on_floor=true THIS tick --
## "resolve_floor"/"grid_floor_backstop"/"try_step", empty if none did this tick (read-only telemetry).
var bounds_violation_this_tick: bool = false; var floor_selection_violation_this_tick: bool = false  ## NOT rate-limited, unlike the push_error reports
var dig_event_this_tick: bool = false  ## true iff `input.dig_pressed` this tick actually excavated a
## cell (a press against air or out of bounds is not an event) -- the caller's ground truth for a
## dig-rate metric that must never look at cells the player hasn't dug (docs/DECISIONS_LEDGER.md D0110)
var dug_material_this_tick: StringName = &""  ## the material that WAS at the excavated cell, empty
## unless dig_event_this_tick is true this same tick -- lets a caller classify a dig as "revealed the
## test feature" without body.gd knowing anything about what a "reveal" means to any metric


func _init(start_x: int, start_y: int) -> void:
	pos_x = start_x
	pos_y = start_y


## Canonical state signature -- the physically meaningful per-tick state that determines everything
## the sim computes on FUTURE ticks (`docs/DECISIONS_LEDGER.md` D0165's real shaft-replay-determinism
## check). Excludes `_last_violation_col`/`_last_violation_row`/`_had_bounds_violation`: those gate
## `Invariants`' own stderr rate-limiting, not any future simulation output.
func state_signature() -> String:
	return "%d,%d,%d,%d,%d,%s,%d,%d,%s" % [
		pos_x, pos_y, vel_x, vel_y, facing, on_floor,
		_coyote_ticks_left, _jump_buffer_ticks_left, _was_jump_held]


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


## The column of cells horizontally adjacent to the body's leading edge, in `facing`'s direction --
## `_handle_dig` excavates the WHOLE column spanning the body's own height (D0113), this returns just its
## x plus the body's centre row for bounds-checking and reporting. Horizontal-only on purpose
## (docs/DECISIONS_LEDGER.md D0110) -- the reveal-layer test this exists for is scoped to lateral search
## (docs/GDD.md §8/§12), and a single well-defined direction avoids the aim-direction design question a
## vertical/diagonal dig would raise (which key means "down," does it compete with mantle_hold's up-key)
## without a stated answer yet.
##
## `_right_x()`/`_left_x()` are the box's edges over a HALF-OPEN [left,right) range, same as
## `_box_blocked`'s own `right - 1`/`bottom - 1` convention (docs/DECISIONS_LEDGER.md D0112) -- a body
## resting with its right edge exactly on a cell boundary has `_px_to_cell(_right_x())` already equal to
## the cell just ahead of it (not one it occupies), so `+ facing` on that value overshoots by one cell.
## The left edge doesn't need the same `- 1`: floor's rounding already gives the leftmost occupied cell
## there, correctly, with no adjustment.
func _dig_target_cell() -> Vector2i:
	var cx: int = _px_to_cell(_right_x() - 1) + 1 if facing > 0 else _px_to_cell(_left_x()) - 1
	var cy: int = _px_to_cell(pos_y)
	return Vector2i(cx, cy)


## Excavates the dig target COLUMN across its own FULL HISTORICAL dig extent, not just the body's
## current height -- a single-row notch cannot be walked through by a body several cells tall
## (docs/DECISIONS_LEDGER.md D0113), and a column dug at two different body-heights without ever being
## dug in between leaves a gap the body's own later, differently-positioned footprint can straddle
## (D0122/D0123's staircase). `TileGrid.extend_terrain_dig_extent` (D0125) is the fix: it folds this touch into
## the column's own historical [min,max] and returns the merged range, so a column is always one
## contiguous open span from the lowest row ever dug there to the highest -- never re-computed from the
## body's own current height alone. A press against a column that's already fully open is not an event;
## a partially-open column still counts once any new cell clears. `dug_material_this_tick` reports
## `glimmer` if the excavated range held it anywhere, else the first real material found.
func _handle_dig(grid: TileGrid) -> void:
	var target: Vector2i = _dig_target_cell()
	if not grid.in_bounds(target):
		return
	var touch_top: int = _px_to_cell(_top_y())
	var touch_bottom: int = _px_to_cell(_bottom_y() - 1)
	var extent: Vector2i = grid.extend_terrain_dig_extent(target.x, touch_top, touch_bottom)
	var reported_material: StringName = &""
	for row: int in range(extent.x, extent.y + 1):
		var cell: Vector2i = Vector2i(target.x, row)
		if not grid.in_bounds(cell):
			continue
		var material: StringName = grid.get_material(cell)
		if material == &"":
			continue
		grid.excavate(cell)
		if reported_material == &"" or material == &"glimmer":
			reported_material = material
	dig_event_this_tick = reported_material != &""
	dug_material_this_tick = reported_material


## One fixed 60Hz tick. Order: horizontal integrate+move+collide, vertical integrate+move+collide.
## Matches `docs/ARCHITECTURE.md` §4's phase order at body's own scope (input already read into
## `input`; body never polls a device).
func tick(input: InputFrame, grid: TileGrid) -> void:
	stepped_up_this_tick = false
	mantled_this_tick = false
	corner_corrected_this_tick = false
	edge_caught_this_tick = false
	depenetrated_this_tick = false
	floor_source_this_tick = &""
	bounds_violation_this_tick = false
	floor_selection_violation_this_tick = false
	dig_event_this_tick = false
	dug_material_this_tick = &""

	_integrate_horizontal(input)
	pos_x += vel_x / TICK_HZ
	HorizontalResolve.resolve(self, grid, input)

	_integrate_vertical()
	VerticalResolve.move_and_resolve(self, grid)

	# Jump is handled AFTER vertical resolve, not before: a buffered jump has to see THIS tick's own
	# landing, not the previous tick's `on_floor` -- checking it earlier meant a jump buffered right up
	# to touchdown could only ever fire one tick late, since the landing that should satisfy it hadn't
	# happened yet in the tick's own dataflow. Overriding a just-landed vel_y=0 here is a one-tick
	# touch-and-go: the position this tick is still correctly on the ground, only next tick's
	# integration reflects the jump.
	_handle_jump(input)
	_enforce_grid_bounds(grid)
	if input.dig_pressed:
		_handle_dig(grid)

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


## World boundary, not terrain (D0055) -- called last in `tick()`, reports (D0052) BEFORE correcting.
func _enforce_grid_bounds(grid: TileGrid) -> void:
	var grid_max_x: int = grid.width * CELL_PX * Fx.SCALE
	var grid_max_y: int = grid.height * CELL_PX * Fx.SCALE
	var violation: Invariants.BoundsViolation = Invariants.check_bounds(
		0, 0, grid_max_x, grid_max_y, _left_x(), _top_y(), _right_x(), _bottom_y())
	bounds_violation_this_tick = violation != null
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
		# D0058: used to also set on_floor=true, asymmetric with the top clamp (velocity-only, above) --
		# false whenever this fires from falling PAST a missing floor, not landing. Caught by the
		# fuzzer's grounded_implies_solid_beneath property (~3,978 violations, all this exact clamp).
		pos_y = grid_max_y - (HEIGHT_PX * Fx.SCALE) / 2
		vel_y = 0
