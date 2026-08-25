extends "res://tools/check_base.gd"

## CAN YOU AIM IT, AND CAN YOU KEEP GOING?
##
## Two properties, both added the same day and both load-bearing for the same reason: the rope stopped
## being an occasional tool and became the way you move.
##
##   THE GHOST TELLS THE TRUTH.  A marker showing where the hook would bite is only worth drawing if the
##                               hook then bites THERE. One disagreement and the player learns the marker
##                               lies, and from that point they are aiming blind and reading noise, which
##                               is strictly worse than having drawn nothing. Grapple.trace() and
##                               Grapple.advance() walk the same bites over the same predicate precisely so
##                               they cannot drift, and this fires shots all the way round the compass, at
##                               every range, to hold them together.
##
##   THE CHAIN KEEPS THE ARC.    Firing while anchored throws a NEW hook without letting go of the old one,
##                               so a chased arc flows into the next. Two things have to be true and
##                               neither is obvious: the constraint must stay LIVE for every frame the new
##                               hook is in the air (drop it for one and the body falls out of its swing),
##                               and a chained shot that finds nothing must leave you exactly where you
##                               were — otherwise reaching for a hold you might not get is a gamble, and a
##                               movement verb you have to gamble on is a verb you stop using.
##
## Both are measured on a carved rig, the same way check_grapple builds its course, so nothing here depends
## on what worldgen happened to produce.
##   godot --headless --path . --script res://tools/check_aim.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = FactorySim.CELL
const SETTLE: int = 30

## A hollow box with rock on every side, so a shot in ANY direction has something to find.
const RIG_LEFT: int = 12
const RIG_RIGHT: int = 58   ## wide enough that a shot down its length runs OUT of line
const RIG_TOP: int = 14
const RIG_BOTTOM: int = 26

const SHOTS: int = 48                ## shots around the compass — every 7.5 degrees
const FLIGHT_CAP: int = 90           ## frames a shot is given to resolve
const ARC_FRAMES: int = 150          ## most frames of pumping before the reach, so there is an arc to lose
const ARC_SETTLE: int = 40           ## ...and the earliest one it is allowed to throw on
const THROW_SPEED: float = 120.0     ## px/s toward the next hold that counts as "a player would go now"
const HORIZON: int = 40              ## frames after the throw at which both reaches are compared
const CHAIN_ANCHOR := Vector2i(26, 14)
const CHAIN_NEXT := Vector2i(34, 14)

func _initialize() -> void:
	print("== the hook you can aim ==")
	MainView.dev_start = false
	await _run()
	_verdict("check_aim", "the marker is honest and the chain holds the arc")


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	_carve(main.sim)
	var p: Player = main._player
	p.auto_input = false
	p.position = Vector2(float(RIG_LEFT + 10) * CELL + 16.0, float(RIG_BOTTOM - 1) * CELL)
	for _i: int in 10:
		await physics_frame

	await _ghost_is_honest(main, p)
	await _chain_keeps_the_arc(main, p)

	p.auto_input = true
	main.queue_free()
	await physics_frame


## Fire all the way round the compass and check the marker against the hook, shot for shot.
func _ghost_is_honest(main: MainView, p: Player) -> void:
	var checked: int = 0
	var wrong: int = 0
	var predicted_miss: int = 0
	var missed: int = 0
	for i: int in SHOTS:
		var ang: float = TAU * float(i) / float(SHOTS)
		var toward: Vector2 = p.hand() + Vector2(cos(ang), sin(ang)) * Grapple.MAX_RANGE * 1.4
		var ghost: Dictionary = p.grapple.trace(main.sim, p.hand(), toward)
		p.grapple.fire(p.hand(), toward)
		var f: int = 0
		while p.grapple.throwing() and f < FLIGHT_CAP:
			await physics_frame
			f += 1
		var planted: bool = p.grapple.state == Grapple.State.ANCHORED
		if bool(ghost["hit"]):
			checked += 1
			if not planted or p.grapple.anchor_cell != Vector2i(ghost["cell"]):
				wrong += 1
		else:
			predicted_miss += 1
			if planted:
				missed += 1
		p.grapple.cut()
		await physics_frame

	print("  %d shots: the marker called %d bites and %d misses" % [SHOTS, checked, predicted_miss])
	_check(checked > 0, "the rig gives the marker something to find (%d bites called)" % checked)
	_check(wrong == 0,
		"every predicted bite lands in the cell it pointed at (%d disagreed)" % wrong)
	_check(missed == 0,
		"...and a shot the marker called out-of-range never secretly plants (%d did)" % missed)


## Swing on one anchor, reach for a second, and ask what the reach COST.
##
## "Keeps 80% of the arc" was the first thing asserted here and it is not a property the physics can have:
## the constraint cancels the outward radial component, so what a swap costs depends entirely on which way
## you were travelling relative to the new hold. Throwing at a hold you are moving away from SHOULD bleed
## speed — that is the skill in it. The real claim is comparative, and it is the one the change was made
## for: chaining must beat what it replaced. So the same arc is flown twice, and the second time the line
## is cut first, exactly as the old toggle did it.
func _chain_keeps_the_arc(main: MainView, p: Player) -> void:
	var chained: Dictionary = await _reach(main, p, true)
	var toggled: Dictionary = await _reach(main, p, false)
	if chained.is_empty() or toggled.is_empty():
		_check(false, "could not fly the arc to compare the two reaches")
		return
	print("  the same arc (%.0f px/s at the throw), %d frames on from reaching for the same hold:"
		% [chained["was"], HORIZON])
	print("    chained       -> %+.0f px along, %+.0f px down" % [chained["ran"], chained["sank"]])
	print("    cut-then-fire -> %+.0f px along, %+.0f px down" % [toggled["ran"], toggled["sank"]])
	_check(int(chained["dropped"]) == 0,
		"the line holds for every frame the next hook is in the air (%d dropped)" % chained["dropped"])
	_check(bool(chained["swapped"]), "...and the anchor actually moves to the new hook")
	# The ground-and-height line above is REPORTED, not asserted, and getting there cost three wrong
	# assertions worth writing down. "Chaining keeps more speed" is false: a body that lets go is a
	# projectile and a projectile never loses speed, so free-fall always wins that number. "Chaining keeps
	# more height" and "chaining covers more ground" are both true or false depending entirely on where the
	# next hold is and when you threw — and a well-timed RELEASE beating a chain is not a bug, it is the
	# skill ceiling of a ninja rope working as intended. Gating on any of them would freeze one rig's
	# geometry into a rule about movement. What chaining actually promises is narrower and absolute: you are
	# never dropped, the swap happens, and a throw that finds nothing costs you nothing. Those are asserted.
	_check(int(toggled["dropped"]) > 0,
		"...and the old way really did drop you (%d frames off the line)" % toggled["dropped"])

	# A chained throw at NOTHING must cost only the throw.
	if not await _plant(main, p, CHAIN_ANCHOR):
		return
	var held: Vector2 = p.grapple.anchor
	# Down the long axis of the room, where there is no rock inside the winch's reach — the point is a
	# throw that finds NOTHING, and a sealed box small enough to swing in has a wall in every direction.
	p.grapple.fire(p.hand(), p.hand() + Vector2(float(CELL) * 40.0, 0.0))
	var f: int = 0
	while p.grapple.throwing() and f < FLIGHT_CAP:
		await physics_frame
		f += 1
	_check(p.grapple.state == Grapple.State.ANCHORED and p.grapple.anchor.is_equal_approx(held),
		"a chained throw that finds no rock leaves you on the line you were already on")
	p.grapple.cut()


## Fly one arc and reach for the far hold, either by chaining or by letting go first. Returns what the
## reach cost: the share of the arc's speed still there afterwards, how far the body sank doing it, and
## whether the constraint ever went away.
func _reach(main: MainView, p: Player, chain: bool) -> Dictionary:
	p.grapple.cut()
	p.velocity = Vector2.ZERO
	p.position = Vector2(float(RIG_LEFT + 10) * CELL + 16.0, float(RIG_BOTTOM - 1) * CELL)
	for _i: int in 10:
		await physics_frame
	if not await _plant(main, p, CHAIN_ANCHOR):
		return {}
	# Build a real arc, then throw at the moment a player would: travelling TOWARD the next hold, near the
	# bottom of the swing where the speed is. Sampling after a fixed frame count caught the body at the top
	# of its arc with almost no velocity, which made "the share of the speed kept" a ratio of two numbers
	# near zero — it read 4.53, which is not a share of anything.
	var f0: int = 0
	while f0 < ARC_FRAMES:
		p.input_dir = 1.0
		await physics_frame
		f0 += 1
		if f0 > ARC_SETTLE and p.velocity.x > THROW_SPEED:
			break
	p.input_dir = 0.0
	var before: Vector2 = p.velocity
	var from_at: Vector2 = p.position
	var first: Vector2 = p.grapple.anchor

	if not chain:
		p.grapple.cut()                              # the old toggle: press once to let go, again to throw
	p.grapple.fire(p.hand(), main._cell_center(CHAIN_NEXT))
	var dropped: int = 0
	for f: int in HORIZON:
		if p.grapple.throwing() and p.grapple.state != Grapple.State.ANCHORED:
			dropped += 1                             # no constraint this frame: the body is falling, not swinging
		await physics_frame
	return {
		"was": before.length(),
		"ran": p.position.x - from_at.x,             # ground covered toward the next hold
		"sank": p.position.y - from_at.y,            # ...and the altitude it cost to cover it
		"dropped": dropped,
		"swapped": p.grapple.anchor.distance_to(first) > float(CELL),
	}


func _plant(main: MainView, p: Player, cell: Vector2i) -> bool:
	p.grapple.cut()
	p.grapple.fire(p.hand(), main._cell_center(cell))
	var f: int = 0
	while p.grapple.throwing() and f < FLIGHT_CAP:
		await physics_frame
		f += 1
	return p.grapple.state == Grapple.State.ANCHORED


## A sealed room: open inside, solid shell, so every compass direction has rock at a known distance.
func _carve(sim: FactorySim) -> void:
	for x: int in range(RIG_LEFT - 2, RIG_RIGHT + 3):
		for y: int in range(RIG_TOP - 2, RIG_BOTTOM + 3):
			var cell := Vector2i(x, y)
			var inside: bool = x > RIG_LEFT and x < RIG_RIGHT and y > RIG_TOP and y < RIG_BOTTOM
			if inside:
				sim.mine(cell)
			elif not sim.is_solid(cell):
				sim.set_solid(cell, &"stone")
