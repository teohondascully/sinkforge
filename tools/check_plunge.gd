extends SceneTree

## IS THE DESCENT A CHOICE, OR IS ONE ROUTE STRICTLY BETTER?
##
## check_descent proved the GEOMETRY of a second route exists: the sinkholes let open space reach sixty
## rows under the sky, from mouths you can find. Geometry is necessary and it is not sufficient. A route
## that nobody would take is scenery, and a route that everybody would take is not a choice either — it is
## the new chore with a better view. The thing worth measuring is the SHAPE OF THE TRADE.
##
## So both routes are PLAYED, from the same surface, to the same depth, in the same world:
##
##   THE SHAFT   — stand over a column and sink it by hand. The old descent. Slow, safe, entirely yours:
##                 every cell you pass through is a cell you made, so nothing about it can surprise you.
##   THE PLUNGE  — walk to a sinkhole mouth and go down the hole a body did not make. Fast, committed,
##                 the world's. You arrive where the hole goes, at the speed the hole chooses.
##
## Three numbers come out, and each one is a different way for the design to be wrong:
##
##   THE SPEEDUP   — plunge frames vs shaft frames. Under about 2× the hole is not worth walking to and
##                   the second route is scenery. This has a floor.
##   THE COST      — blocks broken on each route. The shaft's number is its price. The plunge's number must
##                   be ZERO, or it is not a second route, it is the first route with a head start.
##   THE ROPE      — the plunge is ridden TWICE, once on legs alone and once with the grapple, and the gap
##                   between them is the tool's reason to exist stated as a number. check_grapple proves the
##                   rope works on a rig built to suit it; this proves it matters in terrain nobody designed.
##                   A hole a body walks out of does not need a rope. A hole a body CANNOT walk out of is a
##                   trap unless it has one — and the first played descent parked in exactly such a pocket,
##                   twelve rows down, for the whole budget, in a shaft whose walls the hook bit on every
##                   single sample. The rock to hold was always there; the body just never reached for it.
##
## What this does NOT measure is risk, because there is not yet any. That absence is the finding this layer
## exists to keep visible: with no stakes on a fall, a faster free route is not a choice at all.
##
##   godot --headless --path . --script res://tools/check_plunge.gd

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const CELL: int = 32
const SETTLE: int = 30

## How far down both routes are asked to get. Deep enough that the shaft is real work and the hole has
## somewhere to take you; shallow enough to sit inside a harness layer's budget.
const TARGET_ROWS: int = 34

const MOUTH_PLUNGE: int = 6        ## rows of surface drop that make a step a MOUTH rather than a hill
const WALK_IN_FRAMES: int = 26     ## frames of held input to step off the lip
const FALL_BUDGET: int = 1500      ## frames the plunge is given to arrive
const PURCHASE_EVERY: int = 8      ## frames between rope-purchase samples during the fall
const PURCHASE_REACH: int = 5      ## cells sideways the sample shot is aimed

## The hole must not be SLOWER than the pickaxe. This was written as 2.0 before the route had ever been
## played, on the assumption that falling obviously beats digging; the first honest run said 0.3, and the
## three things wrong with it were all real — mouths opening over the thin end of a chasm, a winch that
## could not haul from standing, and a reel geared slower than the legs it was supposed to replace. Fixing
## those took it to 1.1. Parity is the line that actually matters: below it the free route is a novelty
## nobody takes, and at parity-plus-zero-cost it is a genuine choice, which is the whole point of cutting
## the mouths. Keeping the old 2.0 would only mean asserting a wish.
const SPEEDUP_FLOOR: float = 1.0   ## ...faster than the pickaxe (measured 1.1)
const PURCHASE_FLOOR: float = 0.50 ## ...and the rope must bite on at least this share of the way down
const ROPE_EDGE: int = 12          ## ...and the roped ride must beat the legs-only ride by this many rows

## THE ROPE HOP — how a stuck body gets over the lip that stopped it. Fire up and across toward the way
## down, reel in, lean, let go. One motion, and it is the same one a player makes.
const STUCK_FRAMES: int = 14       ## frames without gaining a row before the body reaches for the wall
const HOP_OVER: int = 5            ## cells across the hop aims
const HOP_UP: int = 5              ## ...and up
const HOP_BITE: int = 24           ## frames the hook is given to plant
const HOP_RIDE: int = 150          ## frames spent reeling before letting go regardless

var _fails: int = 0


func _initialize() -> void:
	print("== the descent, both ways ==")
	MainView.dev_start = false
	await _run()
	if _fails == 0:
		print("check_plunge: PASS — the hole is a route, and it is one you can steer")
		quit(0)
	else:
		print("check_plunge: FAIL (%d)" % _fails)
		quit(1)


func _run() -> void:
	var legs: Dictionary = await _ride(false)
	var roped: Dictionary = await _ride(true)
	var shaft: Dictionary = await _dig()

	if legs.is_empty() or roped.is_empty() or shaft.is_empty():
		_fails += 1
		printerr("  FAIL: one of the routes could not be played at all")
		return

	var speedup: float = float(shaft["frames"]) / maxf(float(roped["frames"]), 1.0)
	print("  the shaft:      %d rows in %d frames, %d blocks broken"
		% [shaft["rows"], shaft["frames"], shaft["mines"]])
	print("  the plunge, legs only:  %d rows in %d frames (mouth at column %d)"
		% [legs["rows"], legs["frames"], legs["mouth"]])
	print("  the plunge, with rope:  %d rows in %d frames, %d blocks broken, %d hops"
		% [roped["rows"], roped["frames"], roped["mines"], roped["hops"]])
	print("  the hole is %.1fx faster than the pickaxe; the rope bit on %d of %d samples on the way down"
		% [speedup, roped["bit"], roped["shots"]])

	var purchase: float = float(roped["bit"]) / maxf(float(roped["shots"]), 1.0)
	_check(roped["rows"] >= TARGET_ROWS,
		"the hole GOES somewhere (%d rows, asked for %d)" % [roped["rows"], TARGET_ROWS])
	_check(roped["mines"] == 0,
		"...and going down it costs no digging (%d blocks broken)" % roped["mines"])
	_check(speedup >= SPEEDUP_FLOOR,
		"...and it is worth walking to (%.1fx the shaft, floor %.1fx)" % [speedup, SPEEDUP_FLOOR])
	_check(purchase >= PURCHASE_FLOOR,
		"...and there is rock to hold the whole way (rope bit %.0f%%, floor %.0f%%)"
			% [purchase * 100.0, PURCHASE_FLOOR * 100.0])
	_check(roped["rows"] >= legs["rows"] + ROPE_EDGE,
		"...and the ROPE is what gets you down it (%d rows roped vs %d on legs, needs +%d)"
			% [roped["rows"], legs["rows"], ROPE_EDGE])


## THE PLUNGE. Find the mouth nearest the spawn, walk the real body to its lip, step off, and go down the
## hole under gravity — firing at the wall every so often to find out whether the rope has anything to
## hold. Nothing is mined and nothing is placed; if the body ends up somewhere it cannot leave, that is a
## true report about the route.
func _ride(with_rope: bool) -> Dictionary:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sim: FactorySim = main.sim
	var agent: PlayAgent = AGENT.new(self, main)
	var p: Player = agent.player

	var here: int = main._cell_at(p.position).x
	var lip: int = _nearest_mouth(sim, here)
	if lip < 0:
		printerr("  no sinkhole mouth in this world")
		main.queue_free()
		await physics_frame
		return {}

	var inward: float = 1.0 if lip > here else -1.0
	if not await agent.walk_to_column(lip - int(inward) * 2, 1600):
		printerr("  the body could not walk to the mouth at column %d" % lip)
		main.queue_free()
		await physics_frame
		return {}

	var start_row: int = main._cell_at(p.position).y
	var frames: int = 0
	var deepest: int = start_row
	var shots: int = 0
	var bit: int = 0
	var hops: int = 0
	var probed: int = 0                      ## frames spent PROBING, billed to the instrument not the route
	var stuck: int = 0

	# Step off the lip, then STEER. A body going down a hole is not a dropped stone: it reads which way the
	# hole continues and leans that way, in the air and on every shelf it lands on. Riding passively would
	# measure the shape of the shaft; riding steered measures the shape of the ROUTE, which is the thing a
	# player is actually offered.
	p.auto_input = false
	while frames < FALL_BUDGET:
		var at: Vector2i = main._cell_at(p.position)
		var dir: float = inward if frames < WALK_IN_FRAMES else _drain_dir(sim, at)
		p.input_dir = dir
		await physics_frame
		frames += 1
		at = main._cell_at(p.position)
		if at.y > deepest or frames <= WALK_IN_FRAMES:
			deepest = maxi(deepest, at.y)
			stuck = 0                        # walking in is not being stuck; the fall has not started yet
		else:
			stuck += 1
		if deepest - start_row >= TARGET_ROWS:
			break
		# Can the rope find rock from here? Sample from where the body actually is, mid-descent, then let go
		# immediately — this is asking whether purchase EXISTS, not riding it.
		if frames > WALK_IN_FRAMES and frames % PURCHASE_EVERY == 0:
			shots += 1
			p.grapple.fire(p.hand(), p.hand() + Vector2(inward * CELL * PURCHASE_REACH, 0.0))
			var f: int = 0
			while p.grapple.state == Grapple.State.FLYING and f < 20:
				await physics_frame
				frames += 1
				probed += 1
				f += 1
			if p.grapple.state == Grapple.State.ANCHORED:
				bit += 1
			p.grapple.cut()
		# ...and reach for it when the hole stops giving. On legs alone this branch never runs, which is the
		# whole comparison: the same body, in the same hole, with and without the one tool for it.
		if with_rope and stuck > STUCK_FRAMES and p.on_floor:
			hops += 1
			var cost: int = await _rope_hop(main, p, sim, dir if dir != 0.0 else inward)
			print("    ...reached for the wall at %s and got over it in %d frames" % [at, cost])
			frames += cost
			stuck = 0
	p.input_dir = 0.0
	p.input_climb = 0.0
	p.auto_input = true

	var out := {
		"rows": deepest - start_row, "frames": frames - probed, "mines": agent.mines,
		"mouth": lip, "shots": shots, "bit": bit, "hops": hops,
	}
	main.queue_free()
	await physics_frame
	return out


## THE HOP. The body is on a shelf with a wall between it and the way down. Fire up and across, reel in,
## lean into the swing, let go over the far side. Returns the frames it cost — a hop that finds no rock
## costs only the flight, which is the honest price of reaching for a wall that is not there.
func _rope_hop(main: MainView, p: Player, sim: FactorySim, dir: float) -> int:
	var spent: int = 0
	var aim: Vector2 = p.hand() + Vector2(dir * CELL * HOP_OVER, -CELL * HOP_UP)
	p.grapple.fire(p.hand(), aim)
	while p.grapple.state == Grapple.State.FLYING and spent < HOP_BITE:
		await physics_frame
		spent += 1
	if p.grapple.state != Grapple.State.ANCHORED:
		p.grapple.cut()
		return spent
	var over: bool = false
	for _i: int in HOP_RIDE:
		p.input_climb = 1.0                                   # winch up the line
		p.input_dir = dir                                     # ...and lean the arc the way you want to go
		await physics_frame
		spent += 1
		# Let go once level with the anchor: the body is over the lip it was stuck behind, and everything the
		# winch and the lean built up carries it across. Waiting to pass the anchor in X sounds tidier and
		# never fires — a winch pulls you ALONG the line, so the body arrives under the hook, not beyond it.
		# Let go the moment the way is OPEN — the hop exists to clear one lip, and riding the winch past
		# that point is pure cost. Falling back on "wound all the way in" only when the terrain read never
		# comes good, so a hop can still end.
		var cell: Vector2i = main._cell_at(p.position)
		var ahead := Vector2i(cell.x + int(dir), cell.y)
		var clear: bool = sim.in_bounds(ahead) and not sim.is_solid(ahead) \
				and not sim.is_solid(ahead + Vector2i(0, -1))
		if clear and not p.on_floor \
				or p.position.y <= p.grapple.anchor.y + CELL * 0.5 \
				or p.grapple.length <= Grapple.MIN_LENGTH + 1.0:
			over = true
			break
	p.grapple.cut()
	p.input_climb = 0.0
	if not over:
		# A ride that never cleared the anchor still leaves the body higher than it found it, which is the
		# point of a winch; it just did not become a swing.
		pass
	return spent


## THE SHAFT. The same depth, sunk by hand with the real dig-down loop, from a column clear of the hole.
func _dig() -> Dictionary:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var agent: PlayAgent = AGENT.new(self, main)
	agent.give(&"stone_pickaxe", 1)
	var col: int = main._cell_at(agent.player.position).x
	var top: int = main.sim.surface_row(col)
	var before: int = int(Engine.get_physics_frames())
	var ok: bool = await agent.dig_down_to(Vector2i(col, top + TARGET_ROWS), 6000)
	var reached: int = main._cell_at(agent.player.position).y - top
	if not ok:
		printerr("  the shaft stalled %d rows down" % reached)
	var out := {"rows": reached, "frames": int(Engine.get_physics_frames()) - before,
		"mines": agent.mines}
	main.queue_free()
	await physics_frame
	return out


## WHICH WAY IS DOWN FROM HERE. Look at the columns within reach and find the one whose open air drops
## furthest below the body, then lean that way. This is the read a player makes at a glance — the hole is
## darker and taller on the side it continues — expressed as the only thing the body can do about it.
const DRAIN_LOOK: int = 5          ## columns either side the read covers
const DRAIN_DEPTH: int = 24        ## rows down each column is probed

func _drain_dir(sim: FactorySim, at: Vector2i) -> float:
	var best: int = at.x
	var best_run: int = _open_run(sim, at.x, at.y)
	for dx: int in range(-DRAIN_LOOK, DRAIN_LOOK + 1):
		var c: int = at.x + dx
		if dx == 0 or c < 1 or c >= FactorySim.GRID_COLS - 1:
			continue
		var run: int = _open_run(sim, c, at.y)
		# Ties go to the nearer column, so a body over a wide shaft goes straight down instead of sliding.
		if run > best_run or (run == best_run and absi(c - at.x) < absi(best - at.x)):
			best_run = run
			best = c
	return signf(float(best - at.x))


## How many unbroken open rows a column offers below a starting row.
func _open_run(sim: FactorySim, col: int, from_row: int) -> int:
	var run: int = 0
	for r: int in range(from_row, FactorySim.GRID_ROWS):
		if sim.is_solid(Vector2i(col, r)):
			break
		run += 1
		if run >= DRAIN_DEPTH:
			break
	return run


## The deepest row the standable open space reaches from a cell, four-connected — "if the body walked
## every corridor it can get to from here without digging, how far down does that get it?"
func _reach_from(sim: FactorySim, start: Vector2i) -> int:
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	var deepest: int = start.y
	while not frontier.is_empty():
		var at: Vector2i = frontier.pop_back()
		deepest = maxi(deepest, at.y)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = at + d
			if seen.has(n) or not sim.in_bounds(n) or sim.is_solid(n) or sim.is_solid(n + Vector2i(0, -1)):
				continue
			seen[n] = true
			frontier.append(n)
	return deepest


## The lip of the surface break nearest `from`: the standable side of the biggest step in the ground.
func _nearest_mouth(sim: FactorySim, from: int) -> int:
	var lip: int = -1
	for c: int in range(2, FactorySim.GRID_COLS - 2):
		var step: int = sim.surface_row(c) - sim.surface_row(c - 1)
		if absi(step) < MOUTH_PLUNGE:
			continue
		var edge: int = (c - 1) if step > 0 else c
		if lip < 0 or absi(edge - from) < absi(lip - from):
			lip = edge
	return lip


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		_fails += 1
		printerr("  FAIL: %s" % msg)
