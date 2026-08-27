extends SceneTree

## D0057. The goalless input fuzzer: independent, fully-decorrelated random input every tick (uniform,
## not human-shaped -- that contrast is deliberate, see `docs/EXPERIENCE_EVALUATION.md`), asserting only
## invariants, never a goal. `ScriptedTraverse` proves one known route still works; this asks whether
## the controller can be broken by inputs no scripted route would ever produce, which is exactly how
## `JUMP_CORNER_ROW` (D0055/D0056) and the original out-of-bounds launch both went undetected -- both
## were properties of REACHING somewhere specific, not of surviving arbitrary input.
##
## Standalone subprocess: counting `push_error`s from the same script that provoked them doesn't work
## in-process (`fixture_div_by_zero_probe.gd`'s own reason), and this also needs to print its OWN
## precisely-labeled violation lines (which fuzz seed, which tick) rather than relying on parsing
## `Invariants`' own rate-limited stderr text. `tests/test_body_fuzz.gd` runs this and counts
## "FUZZ_VIOLATION" lines in its captured output.
##
## The `TileGrid` is built ONCE, outside the seed loop -- `HostileChamber.build()`'s own terrain seed
## (20260825) is fixed and unrelated to the fuzzer's input seed, so rebuilding it per run would only
## waste time, not add coverage.

const CELL: int = Heightfield.TERRAIN_CELL_PX
const NUM_SEEDS: int = 1000
const TICKS_PER_SEED: int = 1500
const DEADLOCK_TICKS: int = 300  ## consecutive identical (pos,vel,on_floor) tuples despite varying
                                  ## random input -- a real freeze, not a body legitimately resting
const POSITION_SANITY_PX: int = 1_000_000  ## far past any real chamber; catches wraparound/overflow


func _spawn_body() -> Body:
	var col: int = HostileChamber.SPAWN_START + 2
	return Body.new(
		col * CELL * Fx.SCALE + (CELL * Fx.SCALE) / 2,
		Fx.from_int(HostileChamber.FLOOR_ROW * CELL) - Body.HEIGHT_PX / 2 * Fx.SCALE)


func _random_input(rng: SplitRng) -> InputFrame:
	var input: InputFrame = InputFrame.new()
	input.move_dir = rng.next_range(-1, 1)
	input.jump_pressed = rng.next_float() < 0.5
	input.jump_held = rng.next_float() < 0.5
	input.mantle_hold = rng.next_float() < 0.5
	return input


## The largest displacement a single tick can LEGITIMATELY produce, using the body's own per-tick event
## flags as ground truth for which teleports actually fired -- not a single flat cap, which would either
## miss real bugs (too generous) or false-positive on ordinary mantles (too tight).
func _max_legit_displacement(body: Body) -> Vector2i:
	var max_x: int = Body.RUN_SPEED / Body.TICK_HZ
	if body.corner_corrected_this_tick:
		max_x += Body.CORNER_NUDGE_PX * Fx.SCALE
	var max_y: int = maxi(Body.MAX_FALL, absi(Body.JUMP_VELOCITY)) / Body.TICK_HZ + 4 * Fx.SCALE
	if body.stepped_up_this_tick:
		max_y += Body.STEP_UP_PX * Fx.SCALE
	if body.mantled_this_tick:
		max_y += Body.MANTLE_PX * Fx.SCALE
	if body.bounds_violation_this_tick:
		max_y += POSITION_SANITY_PX * Fx.SCALE  ## a correction can reposition arbitrarily; that tick's
		max_x += POSITION_SANITY_PX * Fx.SCALE  ## own violation is already flagged separately
	return Vector2i(max_x, max_y)


## Carries one seed-run's own tracking state across ticks (previous pos/vel/on_floor for the
## discontinuity and deadlock checks) -- pulled out of `_initialize` so that function stays under the
## line limit, not to hide state; there is exactly one of these alive at a time, never shared.
class _RunState:
	var prev_x: int; var prev_y: int; var prev_vx: int; var prev_vy: int; var prev_floor: bool
	var same_streak: int = 0
	var deadlock_reported: bool = false

	func _init(body: Body) -> void:
		prev_x = body.pos_x; prev_y = body.pos_y
		prev_vx = body.vel_x; prev_vy = body.vel_y; prev_floor = body.on_floor


## Checks all six invariants for the tick that just ran, prints one FUZZ_VIOLATION line per hit, and
## returns how many fired. Mutates `state` to the tick's own post-move values for the next call.
func _check_tick(body: Body, grid: TileGrid, grid_w: int, grid_h: int, state: _RunState, seed: int, tick: int) -> int:
	var violations: int = 0
	if body.bounds_violation_this_tick:
		# By the time tick() returns, _enforce_grid_bounds has already corrected the position -- the
		# edge is inferred from which exact clamp value it landed on, not from re-checking bounds now.
		var edge: String = ""
		if body.pos_x == (Body.WIDTH_PX * Fx.SCALE) / 2: edge += "left "
		if body.pos_x == grid_w - (Body.WIDTH_PX * Fx.SCALE) / 2: edge += "right "
		if body.pos_y == (Body.HEIGHT_PX * Fx.SCALE) / 2: edge += "top "
		if body.pos_y == grid_h - (Body.HEIGHT_PX * Fx.SCALE) / 2: edge += "bottom "
		print("FUZZ_VIOLATION type=bounds edge=%s seed=%d tick=%d pos=(%d,%d)" % [edge, seed, tick, body.pos_x, body.pos_y])
		violations += 1
	if body.floor_selection_violation_this_tick:
		print("FUZZ_VIOLATION type=floor_selection seed=%d tick=%d pos=(%d,%d)" % [seed, tick, body.pos_x, body.pos_y])
		violations += 1
	if body._box_blocked(grid, body._left_x(), body._top_y(), body._right_x(), body._bottom_y()):
		print("FUZZ_VIOLATION type=embedded seed=%d tick=%d pos=(%d,%d)" % [seed, tick, body.pos_x, body.pos_y])
		violations += 1
	if not PropertyChecks.grounded_implies_solid_beneath(body, grid):
		print("FUZZ_VIOLATION type=grounded_no_floor seed=%d tick=%d pos=(%d,%d)" % [seed, tick, body.pos_x, body.pos_y])
		violations += 1
	if absi(body.pos_x) > POSITION_SANITY_PX * Fx.SCALE or absi(body.pos_y) > POSITION_SANITY_PX * Fx.SCALE:
		print("FUZZ_VIOLATION type=overflow seed=%d tick=%d pos=(%d,%d)" % [seed, tick, body.pos_x, body.pos_y])
		violations += 1
	var dx: int = absi(body.pos_x - state.prev_x)
	var dy: int = absi(body.pos_y - state.prev_y)
	var allowed: Vector2i = _max_legit_displacement(body)
	if dx > allowed.x or dy > allowed.y:
		print("FUZZ_VIOLATION type=discontinuity seed=%d tick=%d dx=%d dy=%d max_x=%d max_y=%d" %
			[seed, tick, dx, dy, allowed.x, allowed.y])
		violations += 1
	var same_state: bool = (body.pos_x == state.prev_x and body.pos_y == state.prev_y and
		body.vel_x == state.prev_vx and body.vel_y == state.prev_vy and body.on_floor == state.prev_floor)
	state.same_streak = (state.same_streak + 1) if same_state else 0
	if not same_state:
		state.deadlock_reported = false
	if state.same_streak > DEADLOCK_TICKS and not state.deadlock_reported:
		print("FUZZ_VIOLATION type=deadlock seed=%d tick=%d streak=%d pos=(%d,%d)" %
			[seed, tick, state.same_streak, body.pos_x, body.pos_y])
		violations += 1
		state.deadlock_reported = true
	state.prev_x = body.pos_x; state.prev_y = body.pos_y
	state.prev_vx = body.vel_x; state.prev_vy = body.vel_y; state.prev_floor = body.on_floor
	return violations


func _initialize() -> void:
	var grid: TileGrid = HostileChamber.build()
	var grid_w: int = grid.width * CELL * Fx.SCALE
	var grid_h: int = grid.height * CELL * Fx.SCALE
	var violations: int = 0
	for seed: int in range(NUM_SEEDS):
		var rng: SplitRng = SplitRng.new(seed)
		var body: Body = _spawn_body()
		var state: _RunState = _RunState.new(body)
		for tick: int in range(TICKS_PER_SEED):
			body.tick(_random_input(rng), grid)
			violations += _check_tick(body, grid, grid_w, grid_h, state, seed, tick)
	print("FUZZ_SUMMARY seeds=%d ticks_per_seed=%d total_ticks=%d violations=%d" %
		[NUM_SEEDS, TICKS_PER_SEED, NUM_SEEDS * TICKS_PER_SEED, violations])
	quit(0)
