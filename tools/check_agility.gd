extends SceneTree

## Harness layer — MOVEMENT AGILITY, scored (playtest: "movement/build/drop agility is awkward — I need a
## scoring FUNCTION to optimize against"). This turns "does it feel awkward?" into a repeatable NUMBER.
##
## It builds a fixed obstacle course (a floating platform that ramps up/down by a tile and throws in one
## 2-tile ledge to jump), walks the real body across it with the real reach-gated navigation, and records
## per physics-frame: horizontal progress, STALLS (on the floor, steering into geometry, going nowhere —
## the literal feel of "awkward"), JUMPS spent, and the frames-vs-par efficiency. Plus JUMP RESPONSIVENESS
## (frames from request to leaving the ground). From those it prints an AGILITY SCORE (0-100) and its
## breakdown — the thing to optimize — and fails if the score drops below a floor or the body can't finish
## (so a movement REGRESSION trips the harness, not just a bigger number). Ratchet the floor UP as movement
## improves, exactly like the friction ceilings in play_tests.
##   godot --headless --path . --script res://tools/check_agility.gd

const SCENE: String = "res://scenes/main.tscn"

## The course as per-column heights above the platform base (0 = base, 1 = a one-tile ramp, 2 = a two-tile
## ledge). Ones read as 45° ramps (glide); the 0→2 jump at index 10 is a wall the body must clear.
const HEIGHTS: Array[int] = [0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 2, 2, 2, 2, 2, 0, 0, 1, 1, 1, 0, 0, 0, 0]
const START_COL: int = 12
const BASE_ROW: int = 14
const CELL: int = 32

## Score floor + component caps — headroom over today's MEASURED baseline (deterministic: score 96,
## slowness 1.00×, 0 stalls, jump-latency 1f) so a real movement regression trips while the clean run
## passes. RATCHET the floor UP as movement improves, exactly like the friction ceilings in play_tests.
const SCORE_FLOOR: float = 80.0
const MAX_SLOWNESS: float = 2.0        ## frames may be up to this × the top-speed par (baseline 1.00×)
const STALL_CAP: int = 40              ## stuck-frames tolerated before it's "awkward" (baseline 0)
const JUMP_LATENCY_CAP: int = 3        ## frames from request_jump() to airborne (baseline 1)
## GRANULARITY-AGILITY dimensions (#104). Fine/molded terrain + the scale (#94) and fine-collision (#88)
## reworks all move the agility standard (proven when the P3 fine-collision change popped step-up). These
## turn the user's "smaller char / taller jump / MID-AIR direction change" hypothesis into NUMBERS so those
## changes are judged on data, not vibes — and so a rework can't silently kill responsiveness. Caps carry
## headroom over today's measured baseline; ratchet them as movement improves.
const TURN_LATENCY_CAP: int = 12       ## frames from a full-speed input FLIP to velocity crossing zero (ground snappiness)
const AIR_CONTROL_FLOOR: float = 0.5   ## fraction of ground top-speed steer-able MID-AIR in a 12f window (1.0 = full air control)

var _failures: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


func _initialize() -> void:
	print("== agility check ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("AGILITY OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 30:                                   # _ready runs on add; let the world settle
		await physics_frame
	main._player.auto_input = false                      # WE drive the body, not the (absent) keyboard
	_build_course(main.sim)
	var goal_col: int = START_COL + HEIGHTS.size() - 1
	# Stand the body on the start of the platform and let it land.
	main._player.position = main._cell_center(Vector2i(START_COL, BASE_ROW - 2))
	main._player.velocity = Vector2.ZERO
	main._player.input_dir = 0.0
	for _i: int in 24:
		await physics_frame
	print("  start: body cell=%s on_floor=%s vel=%s (goal col %d)"
		% [str(main._cell_at(main._player.position)), str(main._player.on_floor),
		str(main._player.velocity.round()), goal_col])

	var jump_latency: int = await _jump_latency(main)
	var turn_latency: int = await _turn_latency(main)
	var air_control: float = await _air_control(main)
	# Re-stand the body at the start so the traverse below runs from a deterministic pose.
	main._player.position = main._cell_center(Vector2i(START_COL, BASE_ROW - 2))
	main._player.velocity = Vector2.ZERO
	main._player.input_dir = 0.0
	for _i: int in 16:
		await physics_frame
	var m: Dictionary = await _traverse(main, goal_col)

	# --- the AGILITY SCORE ---------------------------------------------------------------------------
	var fps: float = float(Engine.physics_ticks_per_second)
	var dist: float = absf(main._cell_center(Vector2i(goal_col, 0)).x
		- main._cell_center(Vector2i(START_COL, 0)).x)
	var par: float = dist / (Player.RUN_SPEED / fps)     # frames at top speed, straight line
	var frames: int = int(m["frames"])
	var stalls: int = int(m["stalls"])
	var jumps: int = int(m["jumps"])
	var reached: bool = bool(m["reached"])
	var slowness: float = float(frames) / maxf(1.0, par)
	# expected jumps = the course features that warrant a hop (2-tile walls + 2-tile drops)
	var expected_jumps: int = _jump_feature_count()

	var slow_pen: float = clampf(slowness - 1.0, 0.0, 3.0) * 20.0        # over par → slower = worse
	var stall_pen: float = minf(float(stalls), 60.0) * 0.7               # getting stuck = the awkwardness
	var jump_pen: float = float(maxi(0, jumps - expected_jumps)) * 4.0   # wasted hops = thrash
	var score: float = maxf(0.0, 100.0 - slow_pen - stall_pen - jump_pen)

	print("  course: dist=%.0fpx par=%.0ff  |  frames=%d slowness=%.2fx stalls=%d jumps=%d (exp %d) jump_latency=%df"
		% [dist, par, frames, slowness, stalls, jumps, expected_jumps, jump_latency])
	print("  granularity-agility: turn_latency=%df (cap %d)  air_control=%.2f (floor %.2f, 1.0=full)"
		% [turn_latency, TURN_LATENCY_CAP, air_control, AIR_CONTROL_FLOOR])
	print("  penalties: slow=-%.1f stall=-%.1f jump=-%.1f  =>  AGILITY SCORE = %.1f / 100"
		% [slow_pen, stall_pen, jump_pen, score])

	_check(reached, "the body traverses the whole obstacle course")
	_check(slowness <= MAX_SLOWNESS, "finishes within %.1f× the top-speed par (%.2fx)" % [MAX_SLOWNESS, slowness])
	_check(stalls <= STALL_CAP, "stalls stay under the cap (%d <= %d)" % [stalls, STALL_CAP])
	_check(jump_latency <= JUMP_LATENCY_CAP, "jump is responsive (%d <= %df from request to airborne)"
		% [jump_latency, JUMP_LATENCY_CAP])
	_check(turn_latency <= TURN_LATENCY_CAP, "ground turn is snappy (%d <= %df to reverse at speed)"
		% [turn_latency, TURN_LATENCY_CAP])
	_check(air_control >= AIR_CONTROL_FLOOR, "mid-air direction change works (%.2f >= floor %.2f)"
		% [air_control, AIR_CONTROL_FLOOR])
	_check(score >= SCORE_FLOOR, "AGILITY SCORE %.1f >= floor %.1f" % [score, SCORE_FLOOR])

	main.queue_free()
	await physics_frame


## Lay the course as a thick floating platform so the body can never fall off the world during the run.
## Clears the whole region first (a patch of open sky), so the natural terrain can't wall the body.
func _build_course(sim: FactorySim) -> void:
	for col: int in range(START_COL - 2, START_COL + HEIGHTS.size() + 2):
		for row: int in range(0, BASE_ROW + 6):
			sim.set_solid(Vector2i(col, row), &"")       # clear to open sky
	for i: int in HEIGHTS.size():
		var col: int = START_COL + i
		var top: int = BASE_ROW - HEIGHTS[i]
		for row: int in range(top, BASE_ROW + 4):        # solid from the surface down (thick, no holes)
			sim.set_solid(Vector2i(col, row), &"earth")


## Course features that legitimately warrant a hop: a 2-tile rise (a wall to clear) OR a 2-tile drop
## (the walker hops off a ledge). Jumps BEYOND this count are thrash — the movement-quality signal.
func _jump_feature_count() -> int:
	var n: int = 0
	for i: int in range(1, HEIGHTS.size()):
		if absi(HEIGHTS[i] - HEIGHTS[i - 1]) >= 2:
			n += 1
	return n


## Frames from request_jump() to the body actually leaving the ground — input→motion responsiveness.
func _jump_latency(main: MainView) -> int:
	var p: Player = main._player
	p.input_dir = 0.0
	for _i: int in 10:                                   # make sure it's settled on the floor first
		await physics_frame
	if not p.on_floor:
		return 99
	p.request_jump()
	var f: int = 0
	while f < 20:
		await physics_frame
		f += 1
		if not p.on_floor and p.velocity.y < 0.0:
			return f
	return 99


## GROUND TURN LATENCY (#104): frames from an input FLIP at full speed to the velocity crossing zero (i.e.
## actually reversing). The feel of "I pressed the other way, when does the body respond?" — the ground
## snappiness that char-size / friction / scale changes all perturb. Baseline is ~RUN_SPEED/ACCEL frames.
func _turn_latency(main: MainView) -> int:
	var p: Player = main._player
	# Re-stand on the flat start stretch so the run has room and no wall to hit.
	p.position = main._cell_center(Vector2i(START_COL, BASE_ROW - 2))
	p.velocity = Vector2.ZERO
	p.input_dir = 0.0
	for _i: int in 12:
		await physics_frame
	# Accelerate to (near) top speed one way.
	p.input_dir = 1.0
	var acc: int = 0
	while acc < 60 and p.velocity.x < Player.RUN_SPEED * 0.85:
		await physics_frame
		acc += 1
	# Flip — count frames until the horizontal velocity crosses zero (now moving the other way).
	p.input_dir = -1.0
	var t: int = 0
	while t < 40:
		await physics_frame
		t += 1
		if p.velocity.x <= 0.0:
			return t
	return 99


## AIR CONTROL (#104): the fraction of ground top-speed you can build up HORIZONTALLY while airborne, over a
## short window from a standing jump — the user's "movement can happen mid-air so you can change direction"
## made a number. 1.0 = full air control (steer as freely as on the ground); 0.0 = a committed leap you
## can't redirect. Instrumentation: it tells us whether air-steer is the lever to pull for agility (today it
## already reads ~full, so it is NOT the missing piece) and guards a rework from silently removing it.
func _air_control(main: MainView) -> float:
	var p: Player = main._player
	p.position = main._cell_center(Vector2i(START_COL, BASE_ROW - 2))
	p.velocity = Vector2.ZERO
	p.input_dir = 0.0
	for _i: int in 12:
		await physics_frame
	if not p.on_floor:
		return 0.0
	p.request_jump()
	var lift: int = 0
	while lift < 20 and p.on_floor:                      # wait until genuinely airborne
		await physics_frame
		lift += 1
	var vx0: float = p.velocity.x                         # ~0 from a standing jump
	p.input_dir = 1.0                                    # now try to steer in the air
	for _i: int in 12:
		if p.on_floor:
			break
		await physics_frame
	var gained: float = absf(p.velocity.x - vx0)
	return clampf(gained / Player.RUN_SPEED, 0.0, 1.5)


## Instrumented traversal to goal_col — the same reach-gated navigation a play-goal uses (steer toward the
## target; hop a gap or a wall you're stuck against), while sampling stalls + jumps every frame.
func _traverse(main: MainView, goal_col: int) -> Dictionary:
	var p: Player = main._player
	var sim: FactorySim = main.sim
	var goal_x: float = main._cell_center(Vector2i(goal_col, 0)).x
	var frames: int = 0
	var stalls: int = 0
	var jumps: int = 0
	var jump_cool: int = 0
	var last_x: float = p.position.x
	var budget: int = 1400
	while frames < budget:
		var here: Vector2i = main._cell_at(p.position)
		if here.x == goal_col and p.on_floor:
			break
		var dir: int = signi(int(goal_x - p.position.x))
		p.input_dir = float(dir)
		jump_cool = maxi(0, jump_cool - 1)
		var progressing: bool = absf(p.position.x - last_x) > 0.4
		if p.on_floor and dir != 0:
			var ahead: Vector2i = here + Vector2i(dir, 0)
			var ahead_floor: Vector2i = here + Vector2i(dir, 1)
			if not sim.is_solid(ahead) and not sim.is_solid(ahead_floor) and jump_cool == 0:
				p.request_jump(); jumps += 1; jump_cool = 14
			elif not progressing and sim.is_solid(ahead) and jump_cool == 0:
				p.request_jump(); jumps += 1; jump_cool = 14
			if not progressing:
				stalls += 1
		last_x = p.position.x
		await physics_frame
		frames += 1
	p.input_dir = 0.0
	return {"frames": frames, "stalls": stalls, "jumps": jumps,
		"reached": main._cell_at(p.position).x == goal_col}
