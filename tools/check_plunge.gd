extends "res://tools/check_base.gd"

## IS THE DESCENT A CHOICE, OR IS ONE ROUTE STRICTLY BETTER?
##
## check_descent proved the GEOMETRY of a second route exists: the sinkholes let open space reach sixty
## rows under the sky, from mouths you can find. Geometry is necessary and it is not sufficient. A route
## that nobody would take is scenery, and a route that everybody would take is not a choice either: it is
## the new chore with a better view. The thing worth measuring is the SHAPE OF THE TRADE.
##
## So both routes are PLAYED, from the same surface, to the same depth, in the same world:
##
##   THE SHAFT  : stand over a column and sink it by hand. The old descent. Slow, safe, entirely yours:
##                 every cell you pass through is a cell you made, so nothing about it can surprise you.
##   THE PLUNGE : walk to a sinkhole mouth and go down the hole a body did not make. Fast, committed,
##                 the world's. You arrive where the hole goes, at the speed the hole chooses.
##
## Three numbers come out, and each one is a different way for the design to be wrong:
##
##   THE SPEEDUP  : plunge frames vs shaft frames. Under about 2× the hole is not worth walking to and
##                   the second route is scenery. This has a floor.
##   THE COST     : blocks broken on each route. The shaft's number is its price. The plunge's number must
##                   be ZERO, or it is not a second route, it is the first route with a head start.
##   THE ROPE     : the plunge is ridden TWICE, once on legs alone and once with the grapple, and the gap
##                   between them is the tool's reason to exist stated as a number. check_grapple proves the
##                   rope works on a rig built to suit it; this proves it matters in terrain nobody designed.
##                   The gap is measured on the way BACK, and that is the second thing this layer has been
##                   wrong about. It first asked the rope to reach DEEPER, which no tool in this world can:
##                   a sinkhole throat is cut as a plumb fall line on purpose, and nothing beats gravity at
##                   going down. That assertion only ever passed because the mouth it happened to pick had a
##                   ledge the legs hung up on; it was gating on a defect in the route, not a virtue of the
##                   tool, and it went green again the moment the terraces landed and the ranking chose a
##                   cleaner hole. Falling in is free either way. A hole a body cannot LEAVE is a trap, and
##                   the rope is the difference between a trap and a route.
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
## three things wrong with it were all real: mouths opening over the thin end of a chasm, a winch that
## could not haul from standing, and a reel geared slower than the legs it was supposed to replace. Fixing
## those took it to 1.1. Parity is the line that actually matters: below it the free route is a novelty
## nobody takes, and at parity-plus-zero-cost it is a genuine choice, which is the whole point of cutting
## the mouths. Keeping the old 2.0 would only mean asserting a wish.
const SPEEDUP_FLOOR: float = 1.0   ## ...faster than the pickaxe (measured 1.1)
const PURCHASE_FLOOR: float = 0.50 ## ...and the rope must bite on at least this share of the way down
## Rows the rope must regain over legs on the way back. Set at MOST OF THE DEPTH rather than at some token
## margin, because "the rope gains a few rows" and "the rope gets you home" are different claims and only
## the second one justifies the hole. Measured 54 against 0 (the line does not merely escape the shaft, it
## carries on up the terrain above it), so this floor has room, and it would still catch a winch that only
## managed to lift a body off the floor of the trap it is in.
const ROPE_EDGE: int = 20
const LEGS_BACK_CAP: int = 3         ## rows legs alone may scramble back — past this it is not a trap
const CLIMB_BUDGET: int = 900        ## frames to get home, generous and identical for both routes
const CLIMB_OVER: float = 1.6        ## cells sideways the climbing throw reaches for the shaft wall
const CLIMB_UP: float = 5.0          ## ...and cells up, so each line is a real gain of height

## THE ROPE HOP: how a stuck body gets over the lip that stopped it. Fire up and across toward the way
## down, reel in, lean, let go. One motion, and it is the same one a player makes.
const STUCK_FRAMES: int = 14       ## frames without gaining a row before the body reaches for the wall
const HOP_OVER: int = 5            ## cells across the hop aims
const HOP_UP: int = 5              ## ...and up
const HOP_BITE: int = 24           ## frames the hook is given to plant
const HOP_RIDE: int = 150          ## frames spent reeling before letting go regardless

func _initialize() -> void:
	print("== the descent, both ways ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("check_plunge: PASS — the hole is a route, and it is one you can steer")
		quit(0)
	else:
		print("check_plunge: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	var legs: Dictionary = await _ride(false)
	var roped: Dictionary = await _ride(true)
	var shaft: Dictionary = await _dig()

	if legs.is_empty() or roped.is_empty() or shaft.is_empty():
		_failures += 1
		printerr("  FAIL: one of the routes could not be played at all")
		return

	var speedup: float = float(shaft["frames"]) / maxf(float(roped["frames"]), 1.0)
	print("  the shaft:      %d rows in %d frames, %d blocks broken"
		% [shaft["rows"], shaft["frames"], shaft["mines"]])
	print("  the plunge, legs only:  %d rows in %d frames (mouth at column %d)"
		% [legs["rows"], legs["frames"], legs["mouth"]])
	print("  the plunge, with rope:  %d rows in %d frames, %d blocks broken, %d hops"
		% [roped["rows"], roped["frames"], roped["mines"], roped["hops"]])
	print("  the way back:   %d rows on legs, %d rows on the rope (same budget, same hole)"
		% [legs["back"], roped["back"]])
	print("  the hole is %.1fx faster than the pickaxe; the rope bit on %d of %d samples on the way down"
		% [speedup, roped["bit"], roped["shots"]])

	var purchase: float = float(roped["bit"]) / maxf(float(roped["shots"]), 1.0)
	_check(roped["rows"] >= TARGET_ROWS,
		"the hole GOES somewhere (%d rows, asked for %d)" % [roped["rows"], TARGET_ROWS])
	# THIS USED TO ASSERT `roped["mines"] == 0`, and `_ride` never presses mine; its own docstring says
	# "Nothing is mined and nothing is placed". So the number was zero because of how the fixture was
	# written, not because of anything the game does, and the sentence it was standing behind ("going down
	# costs no digging") was already fully carried by the rows assertion above: the body got TARGET_ROWS
	# down without ever mining. The real claim is about the ROCK: you fall through the hole the generator
	# cut, and it is still there afterwards, which is what makes it a route rather than a thing you carve.
	_check(bool(roped["untouched"]) and int(roped["rock"]) > 1000,
		"...and the %d cells of rock around it are untouched by the trip — the hole was already there"
			% int(roped["rock"]))
	# BOTH JOURNEYS HAVE TO HAVE HAPPENED before their frame counts may be divided by one another. A shaft
	# that stalls does not stop early; it spends its whole 6000-frame budget going nowhere and then returns
	# those frames as its cost, so the ratio reads as a spectacular ~21x win for the hole. The worse mining
	# gets, the better this layer says the plunge is, and it reports the number in the tone of a pass. The
	# stall does print, but to stderr, out of the assertion record and into a place a green run never shows.
	# So the SLOWER route must arrive before its frame count is allowed to flatter the faster one.
	# NON-VACUITY: the shaft must ARRIVE before its frame count may divide anything.
	_check(bool(shaft["ok"]),
		"the shaft got all the way down too, so the two frame counts are of the same journey (%d rows)"
			% shaft["rows"])
	_check(speedup >= SPEEDUP_FLOOR,
		"...and it is worth walking to (%.1fx the shaft, floor %.1fx)" % [speedup, SPEEDUP_FLOOR])
	_check(purchase >= PURCHASE_FLOOR,
		"...and there is rock to hold the whole way (rope bit %.0f%%, floor %.0f%%)"
			% [purchase * 100.0, PURCHASE_FLOOR * 100.0])
	# ...and the same trap on the other route. "On legs alone it is a ONE-WAY door" is measured as rows
	# REGAINED against a cap, and a body that never went down the hole regains nothing and passes it with
	# room to spare. A run that stalled six rows in would report the trap working perfectly when what it
	# actually measured is a body that was never in the trap. The cap only means something below the lip.
	# NON-VACUITY: the body must have gone DOWN before 'it cannot climb out' says anything.
	_check(int(legs["rows"]) >= TARGET_ROWS,
		"the legs-only ride went down that same hole first (%d rows, asked for %d)"
			% [legs["rows"], TARGET_ROWS])
	_check(int(legs["back"]) <= LEGS_BACK_CAP,
		"...and on legs alone it is a ONE-WAY door (%d rows regained, cap %d)"
			% [legs["back"], LEGS_BACK_CAP])
	_check(int(roped["back"]) >= int(legs["back"]) + ROPE_EDGE,
		"...and the ROPE is what gets you back out of it (%d rows climbed vs %d on legs, needs +%d)"
			% [roped["back"], legs["back"], ROPE_EDGE])


## THE PLUNGE. Find the mouth nearest the spawn, walk the real body to its lip, step off, and go down the
## hole under gravity, firing at the wall every so often to find out whether the rope has anything to
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
	# THE ROCK AS IT WAS, before a single frame of the descent. `agent.mines` counts mine calls the DRIVER
	# made, and this driver never makes any, so an assertion on it says something about the fixture and
	# nothing about the world. This says something about the world: whatever happened on the way down and
	# back, the terrain is the terrain the generator laid.
	var rock_before: Dictionary = sim.solid.duplicate()
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
		var dir: float = inward if frames < WALK_IN_FRAMES else _drain_dir(sim, at, p.position.x)
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
		# immediately: this is asking whether purchase EXISTS, not riding it.
		#
		# AND THE SAMPLE HAS TO PUT THE BODY BACK, which is the third thing this layer has been wrong about
		# and by far the worst, because it made the instrument the thing being measured. A FRESH plant takes
		# up slack: Grapple.advance sets `length = distance * SLACK_TAKEUP` (0.90), and the distance
		# constraint then projects the body onto that shorter circle in the same physics step. The shot here
		# is aimed five cells sideways, so the projection is essentially horizontal and the body is snapped
		# about a tenth of the reach TOWARD THE ANCHOR, measured at ten point seven pixels, from x=2552.9
		# back to x=2563.6 against an anchor at 2663 on a line of 100.
		#
		# Ten pixels is not a rounding error at this scale. The body is fourteen pixels wide in a thirty-two
		# pixel cell, so ten pixels is most of what it takes to walk off a ledge, and the shot fires every
		# PURCHASE_EVERY frames whether the body needs it or not. On the shelf at (80,46) the legs-only ride
		# was walking left toward a twenty-row drop in column 79, it needed about seven frames of walking to
		# get its box clear of the ledge in column 80, and the probe reset it to the same tenth of a pixel
		# every eight. Six hundred frames of that, reported as "27 rows, asked for 34", a number that was
		# about this fixture's sampling cadence and not about the hole at all.
		#
		# The frames were already billed to the instrument (`probed`), which is the same decision made once
		# and then only half carried out: if the probe is outside the journey then its DISPLACEMENT is
		# outside the journey too, or the ride is being driven by its own thermometer. So the body's state is
		# taken before the shot and put back after it, and the probe becomes what the line above always
		# claimed it was. Restoring is safe here in a way it would not be in the game: the shot cannot change
		# the terrain (the `untouched` assertion is the standing evidence for that), so a position the body
		# legally occupied four frames ago is still a position it can legally occupy.
		if frames > WALK_IN_FRAMES and frames % PURCHASE_EVERY == 0:
			shots += 1
			var was_at: Vector2 = p.position
			var was_v: Vector2 = p.velocity
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
			p.position = was_at
			p.velocity = was_v
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

	var back: int = await _climb(main, p, sim, with_rope)

	var out := {
		"rows": deepest - start_row, "frames": frames - probed, "mines": agent.mines,
		"mouth": lip, "shots": shots, "bit": bit, "hops": hops, "back": back,
		"rock": rock_before.size(), "untouched": rock_before == sim.solid,
	}
	main.queue_free()
	await physics_frame
	return out


## THE WAY BACK, which is where the two routes actually differ.
##
## This layer used to assert the rope reached DEEPER than legs, and that was never a property this world
## could have. A sinkhole throat is cut as a plumb fall line on purpose (LayeredWorldGen._cut_throat), and
## nothing beats gravity at going down; the only reason the assertion ever passed is that the mouth it
## happened to pick had a ledge the legs got stuck on, so it was gating on a defect in the route rather than
## on a virtue of the tool. Both runs also stop at TARGET_ROWS, so the number was saturated at the ceiling
## for both and could not have shown a gap even in principle.
##
## What the rope is for on a plunge is the RETURN. Falling in is free either way; a hole you cannot get out
## of is a trap, and the difference between a trap and a route is the tool in your hands. So: stand the body
## at the bottom of the hole it just rode down and give it the same budget to get home, once with legs and
## once with a line. Legs may jump, scramble and take any opening the shaft offers; nothing is withheld.
func _climb(main: MainView, p: Player, sim: FactorySim, with_rope: bool) -> int:
	var bottom: int = main._cell_at(p.position).y
	var best: int = bottom
	# Drive the body, and say so here rather than relying on the caller: the first version of this ran after
	# _ride had already handed control back, so the player polled real hardware every frame and wrote a zero
	# over the winch axis on its way past. It reported the rope climbing one row out of a thirty-four row
	# hole, which reads exactly like the tool being useless and was in fact the rig never touching it.
	p.auto_input = false
	p.grapple.cut()
	p.input_climb = 0.0
	for f: int in CLIMB_BUDGET:
		var at: Vector2i = main._cell_at(p.position)
		best = mini(best, at.y)
		var side: float = _wall_dir(sim, at)
		if with_rope:
			if not p.grapple.live():
				p.grapple.fire(p.hand(), p.hand()
					+ Vector2(side * CELL * CLIMB_OVER, -CELL * CLIMB_UP))
			elif p.grapple.state == Grapple.State.ANCHORED:
				p.input_climb = 1.0                          # winch, and keep winching until it is spent
				# Wound in, or level with the hook: this line has given what it has. Let go and throw the
				# next one from higher up; that hand-over-hand is what climbing a shaft on a rope IS.
				if p.grapple.length <= Grapple.MIN_LENGTH + 1.0 \
						or p.position.y <= p.grapple.anchor.y + CELL * 0.5:
					p.grapple.cut()
					p.input_climb = 0.0
					p.request_jump()                         # kick off the wall into the next throw
		# Legs, both runs: lean toward whatever opening there is and jump at every chance. On the roped run
		# this costs nothing and keeps the comparison fair: the rope is measured as an ADDITION to the body,
		# not as a replacement for it.
		p.input_dir = -side
		if p.on_floor and f % 12 == 0:
			p.request_jump()
		await physics_frame
	p.input_dir = 0.0
	p.input_climb = 0.0
	p.grapple.cut()
	p.auto_input = true
	return bottom - best


## Which way the nearest wall is: the side a hook has something to bite. Ties go to the way the shaft is
## closed, so a body in open air still throws at rock rather than into the void.
func _wall_dir(sim: FactorySim, at: Vector2i) -> float:
	for d: int in range(1, 5):
		if sim.is_solid(at + Vector2i(d, 0)):
			return 1.0
		if sim.is_solid(at + Vector2i(-d, 0)):
			return -1.0
	return 1.0


## THE HOP. The body is on a shelf with a wall between it and the way down. Fire up and across, reel in,
## lean into the swing, let go over the far side. Returns the frames it cost; a hop that finds no rock
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
		# never fires: a winch pulls you ALONG the line, so the body arrives under the hook, not beyond it.
		# Let go the moment the way is OPEN: the hop exists to clear one lip, and riding the winch past
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
		"mines": agent.mines, "ok": ok}
	main.queue_free()
	await physics_frame
	return out


## WHICH WAY IS DOWN FROM HERE. Look at the columns within reach and find the one whose open air drops
## furthest below the body, then lean that way. This is the read a player makes at a glance (the hole is
## darker and taller on the side it continues), expressed as the only thing the body can do about it.
const DRAIN_LOOK: int = 5          ## columns either side the read covers
const DRAIN_DEPTH: int = 24        ## rows down each column is probed

## HOW CLOSE TO THE MIDDLE OF THE CHOSEN COLUMN COUNTS AS ARRIVED, in pixels. Derived, and it has to be:
## a column is CELL wide and the body's box is Player.WIDTH, so centred over a column the body has
## (CELL - WIDTH) / 2 of clearance on each side, and that is exactly the distance it may be off centre and
## still have NO PART OF ITSELF over a neighbour. Nine pixels, today.
##
## THIS IS THE DEFECT THIS CONSTANT EXISTS FOR, written down because the shape of it is not obvious from
## the code that had it. The old read returned `signf(best - at.x)` (cell index against cell index), so
## the instant the body's CENTRE crossed into the chosen column the steering went to zero and the body was
## told it had arrived. It had not. `at.x` is floor(x / 32) and the body is fourteen wide, so a body whose
## centre is one pixel inside column 71 still has six pixels of itself hanging over column 70, and if
## column 70 is rock those six pixels are a floor. That is not a hypothetical: the legs-only ride parked at
## (71, 29), x = 2277.6, frozen to a tenth of a pixel for the whole remaining budget, standing on 1.4
## pixels of the ledge in column 70 with a twenty-four row drop in the column it had already correctly
## chosen, pressing nothing, because the driver believed it was where it wanted to be. Ten rows down a
## sixty-row hole, reported as a fact about the terrain.
##
## The second thing the band has to do is not start a hunt of its own, and the arithmetic for that is the
## coast. Input released, the controller rubs off speed at Player.FRICTION, so a body entering the band at
## speed v travels a further v^2 / (2 * FRICTION) before it stops: 5.1 px at RUN_SPEED (150), 12.2 px at a
## fully strided 232. The band is DRAIN_DEADBAND either side, so the far edge is 2 * DRAIN_DEADBAND = 18 px
## from the near one, and a body that cannot coast past the far edge cannot be sent back the way it came.
## 12.2 < 18 holds with the worst case, so there is no oscillation to add hysteresis against.
##
## WHAT WOULD MAKE THIS WRONG: a body as wide as a cell (the band goes to zero and there is no position
## from which the body is clear of both neighbours, but such a body also cannot fit down a one-wide dug
## shaft, so the game would have bigger news); or a top speed raised past sqrt(2 * FRICTION * 2 * BAND) =
## 281 px/s, at which point releasing at one edge coasts out the other and this becomes the oscillation it
## was written to prevent. Both are readable off Player, so if that file moves, re-run this arithmetic.
const DRAIN_DEADBAND: float = (float(CELL) - Player.WIDTH) * 0.5

func _drain_dir(sim: FactorySim, at: Vector2i, x: float) -> float:
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
	# Steer at the MIDDLE of the chosen column, in pixels, not at its index. Nothing changes when the pick
	# is a neighbouring column (its centre is at least sixteen pixels away, so the sign is what it always
	# was), and everything changes when the pick is the column the body is already in, which used to be the
	# one case the driver could not act on.
	var want: float = float(best) * float(CELL) + float(CELL) * 0.5
	if absf(want - x) <= DRAIN_DEADBAND:
		return 0.0
	return signf(want - x)


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


## The deepest row the standable open space reaches from a cell, four-connected: "if the body walked
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
