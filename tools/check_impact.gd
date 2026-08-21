extends "res://tools/check_base.gd"

## WHAT DOES A FALL COST?
##
## Nothing, until now — and that was fine while the only way down was a shaft you dug one cell at a time,
## because you never went faster than you chose to. Then the sinkholes opened and the winch got geared up,
## and a forty-row hole became a strictly better staircase: free, instant, and with no more consequence
## than stepping off a kerb. A route with no downside is not a choice, and the whole point of cutting the
## mouths was to make the descent one.
##
## The price is GRIP, not damage. There is no health system here and inventing one to charge for a fall
## would be a much bigger decision than this needs; more to the point, a platformer that takes control away
## feels broken however well-earned the moment. So a hard landing leaves the legs briefly without purchase,
## and the rope is the way out — arresting on the line bleeds the fall before it arrives.
##
## Four properties, and each is a way the idea could go wrong:
##
##   IT ONLY BITES WHEN IT SHOULD.  Ordinary platforming — a hop, a two-cell step down, running off a ledge
##                                  — must cost NOTHING. A stagger that fires on the moves you make every
##                                  five seconds is not weight, it is a controller that feels sticky.
##   A REAL DROP COSTS.             Terminal velocity into rock has to leave a mark, or nothing changed.
##   IT IS A BEAT, NOT A LOCKOUT.   The body must recover fast, and must never actually lose control: it
##                                  still steers, still jumps, the whole time.
##   THE ROPE IS THE ANSWER.        The same drop, caught on the line, must land clean. If the tool that
##                                  makes the descent fast does not also make it safe, the fast route is
##                                  just the expensive one. Note that BOTH land at terminal speed — the rope
##                                  does not soften the last few cells, it ends the fall being charged for
##                                  and starts a new one, which is precisely why the price is distance and
##                                  not impact. Let go too high and the new fall is long enough to cost too.
##
## Driven on a carved tower with a floor at the bottom, so the fall height is exact and nothing depends on
## what worldgen produced.
##   godot --headless --path . --script res://tools/check_impact.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = FactorySim.CELL
const SETTLE: int = 30

## The shaft: a clear column with solid rock either side (so the hook has something to bite) and a floor.
const COL: int = 30
const TOP: int = 8
const FLOOR_ROW: int = 44
const BORE: int = 1                  ## cells either side of COL that are cleared — a shaft you fall down

const SHORT_DROP: int = 2            ## cells: ordinary platforming
const LONG_DROP: int = 30            ## cells: a real plunge, well past terminal
const LAND_WAIT: int = 90            ## frames to watch after touching down
const RECOVER_CAP: float = 0.35      ## s the body may be short of grip — a beat, not a punishment
const CATCH_ROWS: int = 7            ## cells above the floor the line is thrown — late and low
const CATCH_HOLD: int = 26           ## frames on the winch before letting go to land it on foot

func _initialize() -> void:
	print("== what a fall costs ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("check_impact: PASS — a drop has weight, and the rope is the way out of it")
		quit(0)
	else:
		print("check_impact: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	_carve(main.sim)

	var short_fall: Dictionary = await _drop(main, SHORT_DROP, false)
	var long_fall: Dictionary = await _drop(main, LONG_DROP, false)
	var caught: Dictionary = await _drop(main, LONG_DROP, true)

	print("  a %d-cell step down lands at %.0f px/s and costs %.2fs of grip"
		% [SHORT_DROP, short_fall["impact"], short_fall["stagger"]])
	print("  a %d-cell drop lands at %.0f px/s and costs %.2fs"
		% [LONG_DROP, long_fall["impact"], long_fall["stagger"]])
	print("  the same drop, caught on the line, lands at %.0f px/s and costs %.2fs"
		% [caught["impact"], caught["stagger"]])

	_check(float(short_fall["stagger"]) <= 0.0,
		"ordinary platforming costs nothing (%.2fs)" % short_fall["stagger"])
	_check(float(long_fall["stagger"]) > 0.0,
		"...and a real drop is felt (%.2fs)" % long_fall["stagger"])
	_check(float(long_fall["stagger"]) <= RECOVER_CAP,
		"...and it is a beat, not a punishment (%.2fs, cap %.2fs)"
			% [long_fall["stagger"], RECOVER_CAP])
	_check(bool(long_fall["steered"]),
		"...and the body still answers the stick the whole time it lasts")
	# Note both caught and uncaught land at terminal speed, and that is not the rope failing — it is why the
	# cost is priced on DISTANCE. The line does not slow the last few cells, it ENDS the fall and starts a
	# new one, so what the rope buys is a shorter drop on the books, not a softer touchdown.
	_check(float(caught["stagger"]) < float(long_fall["stagger"]),
		"the rope ends the fall that was being charged for (%.2fs vs %.2fs)"
			% [caught["stagger"], long_fall["stagger"]])
	_check(float(caught["stagger"]) <= 0.0,
		"...so a descent you actually flew costs nothing (%.2fs)" % caught["stagger"])

	main.queue_free()
	await physics_frame


## Drop the body `cells` onto the floor and report what the landing cost. With `catch`, the line is thrown
## at the shaft wall on the way down and reeled — the descent a player who owns a grapple actually makes.
func _drop(main: MainView, cells: int, catch: bool) -> Dictionary:
	var p: Player = main._player
	p.auto_input = false
	p.grapple.cut()
	p.place(Vector2(float(COL) * CELL + 16.0, float(FLOOR_ROW - cells) * CELL - Player.HEIGHT * 0.5))
	for _i: int in 4:
		await physics_frame

	var impact: float = 0.0
	var held: int = 0
	var worst: float = 0.0
	var steered: bool = true
	var f: int = 0
	while f < 600:
		await physics_frame
		f += 1
		# Throw late and low, the way you actually would: you ride the drop for the speed and catch
		# yourself near the bottom. Then let go and land the last few cells on your feet — a fall ARRESTED
		# is the claim, not a fall avoided by hanging on the rope until the test times out, which is what
		# the first version of this measured and reported as a landing at zero.
		if catch and not p.grapple.live() and held == 0 \
				and main._cell_at(p.position).y >= FLOOR_ROW - CATCH_ROWS:
			p.grapple.fire(p.hand(), p.hand() + Vector2(float(CELL) * 3.0, -float(CELL) * 2.0))
		if p.grapple.state == Grapple.State.ANCHORED:
			p.input_climb = 1.0                      # winch: what you do to arrest a fall you committed to
			held += 1
			if held > CATCH_HOLD:
				p.grapple.cut()
				p.input_climb = 0.0
		if p.on_floor:
			impact = p.last_impact
			break
	p.grapple.cut()
	p.input_climb = 0.0

	# Watch the recovery: how long the grip is short, and whether the body answers input throughout.
	for _i: int in LAND_WAIT:
		p.input_dir = 1.0
		worst = maxf(worst, p.stagger)
		if p.stagger > 0.0 and absf(p.velocity.x) < 1.0 and _i > 8:
			steered = false                          # staggered AND not moving: that is a lockout
		await physics_frame
	p.input_dir = 0.0
	p.auto_input = true
	return {"impact": impact, "stagger": worst, "steered": steered}


## A bored shaft with rock walls and a floor: an exact fall height, and something for a hook to hold.
func _carve(sim: FactorySim) -> void:
	for y: int in range(TOP, FLOOR_ROW):
		for x: int in range(COL - BORE, COL + BORE + 1):
			sim.mine(Vector2i(x, y))
		for x: int in [COL - BORE - 1, COL + BORE + 1]:
			if not sim.is_solid(Vector2i(x, y)):
				sim.set_solid(Vector2i(x, y), &"stone")
	for x: int in range(COL - BORE - 1, COL + BORE + 2):
		if not sim.is_solid(Vector2i(x, FLOOR_ROW)):
			sim.set_solid(Vector2i(x, FLOOR_ROW), &"stone")
