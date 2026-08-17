extends "res://tools/check_base.gd"

## THE RUN HAS TO BE WORTH BUILDING, AND MINING HAS TO BE UNTOUCHED BY IT.
##
## The stride raises the floor of traversal without raising the constant mining is tuned against. That is
## only true if two opposite things both hold, and they pull against each other hard enough that neither
## survives on its own:
##
##   1. Short movement is EXACTLY what it was. Every dig alignment, every hop onto a ledge, every step to
##      the left is under a second long, so if the stride reached into that window the close-quarters feel
##      would drift — the game's most frequent action made worse to buy its least frequent one.
##   2. Long movement is decisively better, arrives smoothly rather than snapping on, and can be LOST. A
##      speed you cannot lose is just a bigger constant with extra steps.
##
## Measured through the real body in the real scene, frame by frame, because the stride lives inside the
## same substep loop as friction, the coast drag and the water gate, and any of them could quietly eat it.

const SCENE: String = "res://scenes/main.tscn"
const FPS: float = 60.0
const LANE: int = 60                   ## columns of cleared, level ground the measurements run down
const HEADROOM: int = 5                ## rows cleared above the lane floor

## The first second must be untouched — the window mining, ledge-hops and dig alignment all live in.
const QUIET_WINDOW: float = 0.85
const QUIET_TOL: float = 0.01

## What a full stride has to be worth. Under about a third faster a player never notices it exists and it
## is pure complexity; the constant asks for 55%, and the guard wants nearly all of that delivered.
const GAIN_FLOOR: float = 0.50

## ...and how slowly it must arrive. A run that snaps on reads as a bug in the controller, not as a body.
const RAMP_MIN_SECONDS: float = 1.1

## How long a broken run may take to die. Much longer and stopping costs nothing.
const DECAY_MAX_SECONDS: float = 0.6

func _initialize() -> void:
	print("== the run ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("check_stride: PASS — the run is worth building, costs something, and leaves mining alone")
		quit(0)
	else:
		print("check_stride: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 30:
		await physics_frame
	var p: Player = _lane(main)

	# 1. THE QUIET WINDOW. Hold one way for QUIET_WINDOW and the top speed reached must still be RUN_SPEED,
	#    full stop — the stride's delay is the whole reason the mining feel survives it.
	var quiet: float = 0.0
	for _i: int in int(QUIET_WINDOW * FPS):
		p.input_dir = 1.0
		await physics_frame
		quiet = maxf(quiet, absf(p.velocity.x))
	# TWO-SIDED, because the claim in the comment above is two-sided and the assertion was not. "The top
	# speed reached must still be RUN_SPEED, full stop" says the body runs at full base speed straight away
	# AND that the stride adds nothing yet — and a cap alone only says the second half. A body that never
	# moved satisfies `quiet <= RUN_SPEED * 1.05` perfectly, which makes the most important property this
	# layer tests (base speed is INSTANT, so mining feel survives the stride) the one it could not see.
	#
	# `quiet` is a max over the window, so the floor only asks that full speed was touched once inside it.
	_check(quiet <= Player.RUN_SPEED * (1.0 + QUIET_TOL) and quiet >= Player.RUN_SPEED * (1.0 - QUIET_TOL),
		"the first %.2fs runs at RUN_SPEED and no faster (%.1f px/s vs RUN_SPEED %.1f)"
		% [QUIET_WINDOW, quiet, Player.RUN_SPEED])

	# 2. IT ARRIVES, AND IT ARRIVES SMOOTHLY. Keep holding: the stride must reach full, and the span from
	#    the first hint of it to full must be a real ramp — measured off the body, not read off a constant.
	var t: float = QUIET_WINDOW
	var first: float = -1.0
	while p.stride < 0.999 and t < 8.0:
		p.input_dir = 1.0
		await physics_frame
		t += 1.0 / FPS
		if first < 0.0 and p.stride > 0.01:
			first = t
	_check(p.stride >= 0.999, "a held run does reach full stride (%.2f at %.2fs)" % [p.stride, t])
	_check(t - first >= RAMP_MIN_SECONDS,
		"...and ramps in rather than snapping on (%.2fs from first to full)" % [t - first])

	# 3. IT IS WORTH IT.
	var top: float = 0.0
	for _i: int in 30:
		p.input_dir = 1.0
		await physics_frame
		top = maxf(top, absf(p.velocity.x))
	var gain: float = top / Player.RUN_SPEED - 1.0
	_check(gain >= GAIN_FLOOR,
		"a full run is worth having (+%.0f%%, floor +%.0f%%)" % [gain * 100.0, GAIN_FLOOR * 100.0])

	# 4. THE GRAPPLE STAYS KING. A traversal tool a plain run can match is a dead tool, and the swing cap is
	#    the number that decides it. (check_grapple measures what a real arc reaches; this guards its roof.)
	_check(Player.SWING_MAX_SPEED > top * 1.15,
		"the swing still beats the best run by a clear margin (%.0f vs %.0f px/s)"
		% [Player.SWING_MAX_SPEED, top])

	# 5. IT CAN BE LOST.
	var decay: float = 0.0
	while p.stride > 0.01 and decay < 2.0:
		p.input_dir = 0.0
		await physics_frame
		decay += 1.0 / FPS
	_check(decay <= DECAY_MAX_SECONDS,
		"letting go loses the run promptly (%.2fs, cap %.2fs)" % [decay, DECAY_MAX_SECONDS])

	# 6. A TURN COSTS IT — or "unbroken travel" is decorative and you could hold the run through a reversal.
	await _run_up(p)
	var before: float = p.stride
	for _i: int in 12:
		p.input_dir = -1.0
		await physics_frame
	_check(p.stride < before * 0.6, "turning around costs the run (%.2f -> %.2f)" % [before, p.stride])

	# 7. AND IT BUYS YOU SOMETHING YOU CANNOT OTHERWISE HAVE. This is the property that decides whether the
	#    stride is a mechanic or a number: a gap the miner CANNOT clear from a standing start is cleared by
	#    running at it. Speed you can only feel is decoration; speed that changes which terrain is passable
	#    is a verb, and it makes committing to a long unbroken run a decision rather than a habit.
	var lip: int = _gap(main, GAP_CELLS)
	var walked: bool = await _try_gap(main, p, lip, 3)          # short approach: at top speed, no stride
	var ran: bool = await _try_gap(main, p, lip, 40)            # long approach: full stride
	_check(not walked and ran,
		"a %d-cell gap is cleared running and NOT walking (walk=%s run=%s)" % [GAP_CELLS, walked, ran])


## Carve a long level shelf in the real world and stand the body on it. The generated relief is honest
## terrain with slopes and pits in it; measuring a top speed against that would be measuring the terrain.
func _lane(main: MainView) -> Player:
	var sim: FactorySim = main.sim
	var col: int = 8
	var row: int = FactorySim.GRID_ROWS / 2
	for c: int in range(col - 2, col + LANE):
		for r: int in range(row - HEADROOM, row):
			sim.set_solid(Vector2i(c, r), &"")
		sim.set_solid(Vector2i(c, row), &"stone")
	var p: Player = main._player
	p.auto_input = false                       # WE drive the body, not the (absent) keyboard
	p.input_dir = 0.0
	p.velocity = Vector2.ZERO
	p.position = Vector2((float(col) + 0.5) * float(WorldRenderer.CELL),
		float(row) * float(WorldRenderer.CELL) - Player.HEIGHT * 0.5 - 1.0)
	return p


## Open a gap in the lane's floor and return the column of its near lip. Sized so it sits between the two
## jump ranges: a jump from RUN_SPEED covers about 3.8 cells of ground, one from a full stride about 5.9.
const GAP_CELLS: int = 5

func _gap(main: MainView, cells: int) -> int:
	var lip: int = 8 + LANE - 12
	for c: int in range(lip + 1, lip + 1 + cells):
		for r: int in range(FactorySim.GRID_ROWS / 2, FactorySim.GRID_ROWS / 2 + 6):
			main.sim.set_solid(Vector2i(c, r), &"")
	return lip


## Approach the lip from `run_up` columns back, jump AT the lip, and report whether the body landed on the
## far side. Same body, same input, same jump — the only variable is how much room it had to build a run.
func _try_gap(main: MainView, p: Player, lip: int, run_up: int) -> bool:
	var row: int = FactorySim.GRID_ROWS / 2
	p.velocity = Vector2.ZERO
	p.stride = 0.0
	p.input_dir = 0.0
	p.position = Vector2((float(lip - run_up) + 0.5) * float(WorldRenderer.CELL),
		float(row) * float(WorldRenderer.CELL) - Player.HEIGHT * 0.5 - 1.0)
	for _i: int in 6:
		await physics_frame
	var jumped: bool = false
	var airborne: bool = false
	for _i: int in 900:
		p.input_dir = 1.0
		var cell: Vector2i = main._cell_at(p.position)
		if not jumped and cell.x >= lip and p.on_floor:
			p.request_jump()
			jumped = true
		if jumped and not p.on_floor:
			airborne = true
		await physics_frame
		cell = main._cell_at(p.position)
		if airborne and p.on_floor:
			p.input_dir = 0.0
			print("    run-up %2d cells -> jumped at %d, landed at %d (stride %.2f, %.0f px/s)"
				% [run_up, lip, cell.x, p.stride, absf(p.velocity.x)])
			return cell.x > lip + GAP_CELLS          # landed BEYOND the gap, not fallen into it
		if cell.y > row + 3:
			p.input_dir = 0.0
			print("    run-up %2d cells -> fell into the gap at column %d" % [run_up, cell.x])
			return false
	p.input_dir = 0.0
	print("    run-up %2d cells -> never resolved" % run_up)
	return false


func _run_up(p: Player) -> void:
	var t: float = 0.0
	while p.stride < 0.999 and t < 8.0:
		p.input_dir = 1.0
		await physics_frame
		t += 1.0 / FPS
