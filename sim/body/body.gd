class_name Body
extends RefCounted

## Player kinematics: fixed 60Hz tick, no `delta` (`docs/ARCHITECTURE.md` §4), every state-affecting
## value `Fx`. Collides against `TileGrid` two ways: the ground plane is `Heightfield` (sub-pixel, §9's
## "80% version" of a polygon contour), walls and ceilings are grid-swept through `surroundings.blocks`.
## Driven by `InputFrame`: the raw action level under `Interface.apply` (`docs/ONBOARDING.md`).
## Collider shape: a flat-bottomed axis-aligned box, because the heightfield ground plane needs a flat
## contact edge to sample one surface height against; §9's capsule stays flagged, not decided (D0032).
## The line (`grapple.gd`, `body_swing.gd`) and the medium (`body_medium.gd`: water, ropes, drafts through
## `surroundings`) joined in A' step 5c (D0360); the swing's collision half waits on the resolver ruling.

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
## D0210, the director's ruling: raised 3 -> 4 (60% -> 80% of ground accel). The one FEEL DECISION in this
## block -- every other constant here is a port of legacy's tuning or a value `docs/ARCHITECTURE.md` §9
## states, and §9 names no air-control ratio at all. At 3/5 a mid-air reversal overshot 15.4px, just under
## one BODY WIDTH; at 4/5 it is 11.2px, inside it. NOT 5/5, deliberately: there air and ground accel are
## identical, so a jump stops being a commitment, and full air control is worth more granted on the
## progression web's Tools axis than spent as the default. D0210 has the measured sweep across all four.
const AIR_CONTROL_NUM: int = 4       ## 80% of ground accel, as a plain-int ratio (no Fx needed: an
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

## `_resolve_floor`'s scan window in terrain rows: D0044 measured the row-gap between a reachable column's
## two floors at max 36 over 197 samples (the original 6 reported zero by construction); 48 covers it, and
## `_bottom_y() < surface` still refuses any floor the body has not physically reached.
const FLOOR_SCAN_ROWS: int = 48

var pos_x: int
var pos_y: int
var vel_x: int = 0
var vel_y: int = 0
var facing: int = 1
## D0210. Sweepable via `play_scene`'s `--air=N`, the same shape `Mining.bite_radius` (D0200) gave the
## bite: this project answers a feel question by making the axis playable. State-affecting, so it travels
## in `state_signature` AND in the recording header -- a log replayed at a different ratio is a different
## run, and one without the field reconstructs at the ratio it was recorded under, never today's default.
var air_control_num: int = AIR_CONTROL_NUM
var on_floor: bool = false
## THE GAIT (D0310): the stride that builds while you run and the stagger a long fall costs.
## `sim/body/gait.gd` is the pure decision layer; `sim/body/gait_state.gd` is the state and the order.
var gait: GaitState = GaitState.new()
var _coyote_ticks_left: int = 0
var _jump_buffer_ticks_left: int = 0
var _was_jump_held: bool = false
## THE LINE AND THE MEDIUM (A' step 5c, D0360). `surroundings` is bare terrain until the door hands in
## the world's (`sim/run/world_surroundings.gd`), so a body built alone runs exactly as it always has.
var grapple: Grapple = Grapple.new()
var surroundings: Surroundings = Surroundings.new()
var climbing: bool = false     ## gripping a placed rope: gravity replaced by direct travel
var wet: bool = false          ## this tick's footing, read by the observation
var _was_taut: bool = false    ## last tick's tautness: a jump right after a reel finds the line slack for a tick

## Rate-limits `Invariants.report_floor_selection` to once per distinct (column, floor) pair (D0052);
## `sim/invariants` stays stateless, so the memory lives here. -1 is no valid column or row.
var _last_violation_col: int = -1
var _last_violation_row: int = -1
var _had_bounds_violation: bool = false  ## same D0052 pattern: one excursion latch, no sub-cases
## Per-tick telemetry, read by the caller, not auto-cleared -- so a caller can count events without
## `body.gd` knowing anything about scenarios, metrics, or telemetry schemas.
var stepped_up_this_tick: bool = false
var mantled_this_tick: bool = false
var stepped_down_this_tick: bool = false  ## the floor snap hugged a descending step (5c)
var swung_this_tick: bool = false         ## the line moved the body onto its circle (5c): a consenting mover
var corner_corrected_this_tick: bool = false
var edge_caught_this_tick: bool = false
var depenetrated_this_tick: bool = false
var floor_source_this_tick: StringName = &""  ## D0132: which call set on_floor=true THIS tick --
## "resolve_floor"/"grid_floor_backstop"/"try_step", empty if none did this tick (read-only telemetry).
var bounds_violation_this_tick: bool = false; var floor_selection_violation_this_tick: bool = false  ## NOT rate-limited, unlike the push_error reports
## D0205. True on a tick `_handle_jump` actually launched. Exists because it is the ONE legitimate way a
## tick can end with `floor_source_this_tick` set and `on_floor` false -- the "one-tick touch-and-go" the
## tick order's own comment describes -- and the grounding-consistency invariant below has to exempt it or
## it would fire on correct behaviour.
var jumped_this_tick: bool = false
var grounding_consistency_violation_this_tick: bool = false
var translation_consent_violation_this_tick: bool = false  ## D0213: x moved on a tick that had no
## horizontal input, no incoming velocity, and no recovery to account for it (`Invariants` carries the why)
var dig_event_this_tick: bool = false  ## true iff `input.dig_pressed` this tick actually excavated a
## cell (a press against air or out of bounds is not an event) -- the caller's ground truth for a
## dig-rate metric that must never look at cells the player hasn't dug (docs/DECISIONS_LEDGER.md D0110)
var dug_material_this_tick: StringName = &""  ## the material that WAS at the excavated cell, empty
## unless dig_event_this_tick is true this same tick -- lets a caller classify a dig as "revealed the
## test feature" without body.gd knowing anything about what a "reveal" means to any metric


func _init(start_x: int, start_y: int) -> void:
	pos_x = start_x
	pos_y = start_y


## Canonical state signature -- every per-tick value that determines FUTURE ticks (D0165, D0261): the
## gait, the grip and the line included, because a replay blind to any of them diverges silently.
## Excludes the `Invariants` rate-limiting latches, which gate stderr and no simulation output.
func state_signature() -> String:
	return "%d,%d,%d,%d,%d,%s,%d,%d,%s,%d,%s,%s,%s" % [
		pos_x, pos_y, vel_x, vel_y, facing, on_floor,
		_coyote_ticks_left, _jump_buffer_ticks_left, _was_jump_held, air_control_num,
		gait.signature(), climbing, grapple.state_signature()]


## The save's copy of the body (A' step 4b, D0357): every field `state_signature` covers, as ints.
func capture() -> Dictionary:
	return {"pos_x": pos_x, "pos_y": pos_y, "vel_x": vel_x, "vel_y": vel_y, "facing": facing,
		"on_floor": on_floor, "coyote": _coyote_ticks_left, "jump_buffer": _jump_buffer_ticks_left,
		"jump_held": _was_jump_held, "air_control_num": air_control_num, "gait": gait.capture(),
		"climbing": climbing, "grapple": grapple.capture()}


func restore(d: Dictionary) -> void:
	pos_x = int(d["pos_x"])
	pos_y = int(d["pos_y"])
	vel_x = int(d.get("vel_x", 0))
	vel_y = int(d.get("vel_y", 0))
	facing = int(d.get("facing", 1))
	on_floor = bool(d.get("on_floor", false))
	_coyote_ticks_left = int(d.get("coyote", 0))
	_jump_buffer_ticks_left = int(d.get("jump_buffer", 0))
	_was_jump_held = bool(d.get("jump_held", false))
	air_control_num = int(d.get("air_control_num", AIR_CONTROL_NUM))
	gait.restore(d.get("gait", {}))
	climbing = bool(d.get("climbing", false))
	grapple.restore(d.get("grapple", {}))   # a save from before the line restores a stowed one


## Put the body somewhere without it counting as having fallen there (legacy `place`): the landing cost
## is priced on distance dropped, so a save restoring a position or a rig setting up a shot must not bank
## the teleport as a fall. Cuts the line, because a teleport cannot keep one. The seam every
## non-gameplay mover goes through.
func place(x: int, y: int) -> void:
	pos_x = x
	pos_y = y
	vel_x = 0
	vel_y = 0
	gait.fall_from_y = y
	gait.stagger_ticks = 0
	grapple.cut()
	climbing = false


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


## A cell blocks movement if the surroundings say so: solid terrain on the bare base; with the world's
## surroundings also a machine's base tile, and not wood or leaves (`sim/run/world_surroundings.gd`).
func _blocked(grid: TileGrid, terrain_cell: Vector2i) -> bool:
	return surroundings.blocks(grid, terrain_cell)


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
## Every per-tick telemetry flag, cleared together, so a new flag has one obvious home.
func _reset_tick_flags() -> void:
	stepped_up_this_tick = false
	mantled_this_tick = false
	stepped_down_this_tick = false
	swung_this_tick = false
	corner_corrected_this_tick = false
	edge_caught_this_tick = false
	depenetrated_this_tick = false
	floor_source_this_tick = &""
	bounds_violation_this_tick = false
	floor_selection_violation_this_tick = false
	jumped_this_tick = false
	grounding_consistency_violation_this_tick = false
	translation_consent_violation_this_tick = false
	dig_event_this_tick = false
	dug_material_this_tick = &""


func tick(input: InputFrame, grid: TileGrid) -> void:
	_reset_tick_flags()
	var entry_pos_x: int = pos_x   ## D0213's two witnesses, read before anything can change them
	var entry_vel_x: int = vel_x
	var entry_on_floor: bool = on_floor
	_was_taut = grapple.taut
	grapple.begin_tick()
	wet = BodyMedium.wet(self)
	BodyMedium.grip(self, input)

	_integrate_horizontal(input)
	pos_x += vel_x / TICK_HZ
	HorizontalResolve.resolve(self, grid, input)

	# D0205. A climb that just succeeded OWNS this tick's vertical state and the vertical pass is skipped
	# rather than allowed to undo it: `_try_step` placed the feet on the ledge, zeroed `vel_y` and set
	# `on_floor`, and `move_and_resolve`'s first act would discard that grounding before `resolve_floor`
	# could re-establish it -- on a ledge narrower than the footprint it cannot. Legacy's own rule
	# (`_stepped`); the cost is one tick of deferred fall if the ledge does not hold.
	if not (stepped_up_this_tick or mantled_this_tick):
		if entry_on_floor and not climbing:
			VerticalResolve.step_down(self, grid)   # hug a descending step (5c)
		_integrate_vertical()
		BodyMedium.vertical(self, input)          # the draft and the climb, after gravity
		VerticalResolve.move_and_resolve(self, grid)
	BodySwing.step(self, grid, input)             # the line, after both axes have collided

	# Jump AFTER the vertical resolve: a buffered jump has to see THIS tick's own landing, or one buffered
	# right up to touchdown fires a tick late. Overriding a just-landed vel_y=0 is a one-tick touch-and-go.
	_handle_jump(input)
	_enforce_grid_bounds(grid)
	_enforce_grounding_consistency()
	if input.dig_pressed:
		BodyDig.handle(self, grid)
	# LAST, and after `_enforce_grid_bounds` in particular: the clamp is one of the two recovery paths
	# entitled to move `pos_x` without consent, and the flag that exempts it is only set once it fires.
	translation_consent_violation_this_tick = Invariants.report_translation_consent(
		input.move_dir, entry_vel_x, entry_pos_x, pos_x,
		depenetrated_this_tick or bounds_violation_this_tick or swung_this_tick, grid.seed, pos_y) != null

	# LAST, so the gait reads the SETTLED `on_floor` and `pos_y` rather than the mid-resolve ones.
	vel_y = gait.step(on_floor, pos_y, vel_y, input.move_dir, vel_x, RUN_SPEED)

	_coyote_ticks_left = COYOTE_TICKS if on_floor else maxi(0, _coyote_ticks_left - 1)
	_jump_buffer_ticks_left = maxi(0, _jump_buffer_ticks_left - 1)


func _integrate_horizontal(input: InputFrame) -> void:
	var accel: int = ACCEL_PER_TICK
	var decel: int = DECEL_PER_TICK
	if not on_floor:
		accel = (accel * air_control_num) / AIR_CONTROL_DEN
		decel = (decel * air_control_num) / AIR_CONTROL_DEN
	# The stagger takes GRIP, not control: steering, jumping and mining all still work, the legs just
	# have less authority for a beat. The stride raises the ceiling it is steering toward; water lowers it.
	accel = Gait.grip(accel, gait.stagger_ticks)
	decel = Gait.grip(decel, gait.stagger_ticks)
	var top: int = Gait.top_speed(RUN_SPEED, gait.stride)
	if wet:
		accel = (accel * BodyMedium.WATER_ACCEL_NUM) / BodyMedium.WATER_ACCEL_DEN
		decel = (decel * BodyMedium.WATER_ACCEL_NUM) / BodyMedium.WATER_ACCEL_DEN
		top = (top * BodyMedium.WATER_SPEED_NUM) / BodyMedium.WATER_SPEED_DEN
	if input.move_dir != 0:
		facing = input.move_dir
	if grapple.taut:
		# On a taut line the body is a pendulum: input still bites, which is how an arc is pumped and a
		# release aimed, at reduced authority; and the clamp is lifted so a swing can outrun the legs.
		vel_x += (input.move_dir * accel * BodySwing.SWING_ACCEL_NUM) / BodySwing.SWING_ACCEL_DEN
		return
	if absi(vel_x) > top:
		BodySwing.coast(self, input, top, decel)
		return
	if input.move_dir != 0:
		var target: int = input.move_dir * top
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
	var max_fall: int = MAX_FALL
	if wet:
		g = (g * BodyMedium.WATER_GRAVITY_NUM) / BodyMedium.WATER_GRAVITY_DEN
		max_fall = BodyMedium.WATER_MAX_SINK
	vel_y = mini(vel_y + g, max_fall)


## Coyote time, jump buffer, variable jump height (release cuts upward velocity once, as a ratio: §9).
## A gripped rope counts as grounded and a jump lets go of it (Space off, W up: distinct verbs). Jumping
## off a TAUT line cuts it and stacks the leap on whatever the arc built, with a little extra for the
## timing (legacy `RELEASE_KICK`, the pump's own 21/20); a slack line is left alone.
func _handle_jump(input: InputFrame) -> void:
	if input.jump_pressed:
		_jump_buffer_ticks_left = JUMP_BUFFER_TICKS
	var leap: int = JUMP_VELOCITY
	if wet:
		leap = (leap * BodyMedium.WATER_JUMP_NUM) / BodyMedium.WATER_JUMP_DEN
	if _jump_buffer_ticks_left > 0 and (grapple.taut or _was_taut):
		grapple.cut()
		vel_y = mini(vel_y, 0) + leap
		vel_x = (vel_x * Grapple.PUMP_CLAMP_NUM) / Grapple.PUMP_CLAMP_DEN
		vel_y = (vel_y * Grapple.PUMP_CLAMP_NUM) / Grapple.PUMP_CLAMP_DEN
		jumped_this_tick = true
		_jump_buffer_ticks_left = 0
	elif _jump_buffer_ticks_left > 0 and (on_floor or _coyote_ticks_left > 0 or climbing):
		vel_y = leap
		on_floor = false
		climbing = false
		jumped_this_tick = true
		_coyote_ticks_left = 0
		_jump_buffer_ticks_left = 0
	elif vel_y < 0 and _was_jump_held and not input.jump_held and not climbing:
		vel_y = (vel_y * JUMP_CUT_MULT_NUM) / JUMP_CUT_MULT_DEN
	_was_jump_held = input.jump_held


## D0205. Every assignment to `floor_source_this_tick` sits beside its own `on_floor = true`, so a tick
## that ends naming a grounding source while reporting the body airborne is reporting two things that
## cannot both be true -- the exact pair that sat on screen unwatched through the D0202 investigation.
## Diagnostic, never a correction; a jump is the one legitimate producer and is exempt by flag.
func _enforce_grounding_consistency() -> void:
	if floor_source_this_tick == &"" or on_floor or jumped_this_tick:
		return
	grounding_consistency_violation_this_tick = true
	push_error(("Invariants: tick ended with floor_source=%s but on_floor=false and no jump -- a grounding " +
		"was established and then discarded inside the same tick. pos=(%d,%d) vel=(%d,%d)")
		% [floor_source_this_tick, pos_x, pos_y, vel_x, vel_y])


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
		# D0058: never sets on_floor -- this fires from falling PAST a missing floor, not from landing.
		pos_y = grid_max_y - (HEIGHT_PX * Fx.SCALE) / 2
		vel_y = 0
