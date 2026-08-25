extends "res://tools/check_base.gd"

## DOES THE ROPE CATCH ON THINGS?
##
## Until now it did not, and the source said so in as many words: *"the line does not wrap around corners.
## Worms wraps; Bionic Commando doesn't; neither does Spider-Man. A straight line you can read at a glance
## is the better toy."* That was a defensible call when the rope was a way DOWN a shaft, which is what it
## was when the comment was written. tools/check_traverse then measured the rope crossing a gallery half
## again as fast as a full stride, which makes it the movement system rather than an accessory to one — and
## a movement system earns depth that an accessory does not.
##
## The argument the old comment actually makes is about PREDICTABILITY, and it is worth answering rather
## than ignoring. A wrapped rope is unpredictable when you cannot see why it did what it did. Two things
## have changed since: the line is drawn as rope with visible slack rather than as a chord, so a bend is
## legible, and the aiming ghost means you now choose the anchor deliberately instead of discovering it.
## What is left is the part worth having — a line that goes AROUND the rock instead of through it.
##
## Four properties, and the fourth is the one that makes wrapping a mechanic rather than a cosmetic:
##
##   IT BENDS.        Swing a body past a ledge with the hook beyond it and the line must acquire a pivot.
##                    Without this the rope hangs through solid rock, which is the bug in one sentence.
##   IT COMES OFF.    Swing back the other way and the pivot must be released. A wrap stack that only ever
##                    grows is not a rope, it is a ratchet, and it ends with a body glued to a corner.
##   THE ANCHOR HOLDS. Wrapping must never move the HOOK. The pivot is where the line is bent; the hook is
##                    where it is attached, and confusing the two is how a wrap stack quietly teleports you.
##   IT WHIPS.        A pivot spends line, so the free part shortens — and a conserved tangential speed over
##                    a shorter radius is a faster arc. Catching a corner on the way past must therefore
##                    make you QUICKER, or wrapping is a rendering fix wearing a physics coat.
##
##   godot --headless --path . --script res://tools/check_wrap.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = FactorySim.CELL
const SETTLE: int = 30

## THE HOOK AND THE LEDGE. A hook planted high, a spur of rock jutting out below and to one side of it, and
## a body swinging under the spur — so the straight run from body to hook passes through the spur, and the
## line has no choice but to catch on its corner.
## The body starts ABOVE the spur's level, so the first line to the hook runs clear OVER it — the wrap has
## to be something the SWING causes, not something the plant did. (The first version put the spur between
## body and hook at rest, and the hook simply bit the spur: nothing to catch on, because the line never got
## past it.) Falling into the arc then carries the body below the shelf while it is still out beyond the
## tip, which is the exact moment the line has to bend. The shelf also sits well ABOVE the arc's floor, so
## the body swings clean underneath it rather than landing on top of it — the second version did exactly
## that and measured a body standing on a ledge for three hundred frames.
const HOOK_COL: int = 36
const HOOK_ROW: int = 26
const SPUR_ROW: int = 31             ## the jutting shelf the line catches on
const SPUR_FROM: int = 38            ## ...running from beside the hook column
const SPUR_TO: int = 44              ## ...out to here
const BODY_COL: int = 48             ## the body starts beyond the spur's tip and ABOVE its level
const BODY_ROW: int = 29
const HALL_TOP: int = 20             ## the chamber carved around all of it
const HALL_BOTTOM: int = 46
const HALL_LEFT: int = 30
const HALL_RIGHT: int = 58

const SWING_FRAMES: int = 150        ## frames driven into the swing, each direction
const WHIP_EDGE: float = 2.0         ## how much faster a wrapped arc must turn than a free one
const KEEP_MIN: float = 0.80         ## share of speed that must survive the frame a pivot appears

func _initialize() -> void:
	print("== does the rope catch on things ==")
	MainView.dev_start = false
	await _run()
	_verdict("check_wrap", "the line goes around the rock, and comes back off it")


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sim: FactorySim = main.sim
	var p: Player = main._player
	_carve(sim)
	p.auto_input = false
	p.grapple.cut()
	p.place(Vector2(float(BODY_COL) * CELL + 16.0, float(BODY_ROW) * CELL))
	for _i: int in 4:
		await physics_frame

	# Plant the hook up and to the LEFT, past the spur, so swinging left drives the line onto its corner.
	p.grapple.fire(p.hand(), Vector2(float(HOOK_COL) * CELL + 16.0, float(HOOK_ROW) * CELL + 16.0))
	for _i: int in 40:
		await physics_frame
		if p.grapple.state == Grapple.State.ANCHORED:
			break
	if p.grapple.state != Grapple.State.ANCHORED:
		_check(false, "the hook never planted — nothing to test")
		main.queue_free()
		return
	var hook: Vector2 = p.grapple.anchor
	print("  hook planted at %s; the spur runs cols %d..%d on row %d"
		% [main._cell_at(hook), SPUR_FROM, SPUR_TO, SPUR_ROW])

	# SWING IN, under the spur, toward the hook side.
	var wrapped: int = 0
	var cleared: bool = false
	# THE WHIP, stated as the physics rather than as a wish. The first version asked whether a caught arc
	# came ROUND UNDER THE HOOK sooner, and the answer is no and always will be: a wrapped line orbits the
	# CORNER, not the hook, so "reach the hook's x" is a goal the manoeuvre does not even aim at. What
	# actually happens — and what makes a wrap a manoeuvre rather than a rendering fix — is that spending
	# line on a pivot shortens the free radius, and a conserved tangential speed over a shorter radius is a
	# faster ROTATION. So: peak angular rate, wrapped against free, measured in one run.
	var spin: float = 0.0
	var free_spin: float = 0.0
	# ...and the correctness property a naive wrap gets wrong: the frame a pivot appears, the constraint
	# snaps to a new centre, and a careless implementation cancels most of the velocity as "outward" against
	# the new radius. An arc that dies at every corner is worse than one that clips through the rock.
	var before: float = 0.0
	var after: float = 0.0
	var kept: float = 1.0
	var was: int = 0
	var events: int = 0
	var last_speed: float = 0.0
	for _i: int in SWING_FRAMES:
		p.input_dir = -1.0
		await physics_frame
		wrapped = maxi(wrapped, p.grapple.pivots.size())
		if wrapped > 0 and p.grapple.pivots.is_empty():
			cleared = true
		var now: int = p.grapple.pivots.size()
		var rate: float = p.velocity.length() / maxf(p.grapple.free_length(), 1.0)
		if p.grapple.taut:
			if now > 0:
				spin = maxf(spin, rate)
			else:
				free_spin = maxf(free_spin, rate)
		if now > was and last_speed > Player.RUN_SPEED:
			var through: float = p.velocity.length() / last_speed
			if events == 0 or through < kept:
				kept = through
				before = last_speed
				after = p.velocity.length()
			events += 1
		was = now
		last_speed = p.velocity.length()
		if _i % 25 == 0:
			print("    in  f%3d at %s pivots=%d spent=%.0f free=%.0f len=%.0f v=%.0f"
				% [_i, main._cell_at(p.position), p.grapple.pivots.size(), p.grapple.spent(),
				   p.grapple.free_length(), p.grapple.length, p.velocity.length()])
	print("  swinging in under the spur: the line took %d pivot(s)" % wrapped)
	_check(wrapped > 0, "the line BENDS around the rock instead of hanging through it (%d)" % wrapped)
	_check(p.grapple.anchor.is_equal_approx(hook),
		"...and wrapping never moves the HOOK (%s)" % main._cell_at(p.grapple.anchor))

	# ...and back OUT, which must let the line off the corner again.
	for _i: int in SWING_FRAMES:
		p.input_dir = 1.0
		await physics_frame
		wrapped = maxi(wrapped, p.grapple.pivots.size())
		if wrapped > 0 and p.grapple.pivots.is_empty():
			cleared = true
		var now: int = p.grapple.pivots.size()
		var rate: float = p.velocity.length() / maxf(p.grapple.free_length(), 1.0)
		if p.grapple.taut:
			if now > 0:
				spin = maxf(spin, rate)
			else:
				free_spin = maxf(free_spin, rate)
		if now > was and last_speed > Player.RUN_SPEED:
			var through: float = p.velocity.length() / last_speed
			if events == 0 or through < kept:
				kept = through
				before = last_speed
				after = p.velocity.length()
			events += 1
		was = now
		last_speed = p.velocity.length()
	# Measured as "the stack EVER emptied", not as "it is empty now". A rope in a chamber with a shelf in it
	# wraps, unwraps and wraps again as the arc crosses the shelf's line of sight — the second version of
	# this compared the final count against the peak and failed a run whose log plainly showed the pivot
	# being released, because the swing back out had caught a fresh one by the time it looked. What must be
	# true is that a wrap is REVERSIBLE; a stack that only ever grows is a ratchet, and that is what this
	# now says.
	print("  the line came off the corner during the arc: %s" % cleared)
	_check(cleared, "...and it COMES OFF again (peak %d pivots, stack emptied)" % wrapped)

	print("  the arc turned at up to %.1f rad/s while free and %.1f rad/s while wrapped" % [free_spin, spin])
	# THE BASELINE HAS TO EXIST. `free_spin` starts at 0.0 and is only ever raised by a maxf, so a run in
	# which the line never went taut without a pivot leaves it at zero and the whip assertion below decays
	# into `spin > 0.0` — "the arc turned at all", which is not the claim and is nearly impossible to fail.
	# It is the same trap the `events > 0` guard further down was written for, sitting one assertion above it
	# unguarded. Measured on this rig: 1.2 rad/s free against 4.8 wrapped, so there is plenty to compare
	# with; this is here for the day the fixture stops producing a free arc and the whip check silently
	# weakens instead of going red.
	# NON-VACUITY — without a free arc the whip test decays to `spin > 0.0`.
	_check(free_spin > 0.0, "there was a FREE arc to measure the whip against (%.1f rad/s)" % free_spin)
	_check(spin > free_spin * WHIP_EDGE,
		"...and catching a corner WHIPS you round it (%.1f rad/s vs %.1f, needs %.1fx)"
			% [spin, free_spin, WHIP_EDGE])
	print("  %d wrap event(s) at speed; through the sharpest the body kept %.0f%% (%.0f -> %.0f px/s)"
		% [events, kept * 100.0, before, after])
	# Gated on having WATCHED one, because the version below it passed on an empty sample: `kept` starts at
	# 1.0 and is only ever lowered, so a run in which no pivot appeared while moving reported "100% kept,
	# 0 -> 0 px/s" and went green. A check that cannot fail for want of data is not a check.
	_check(events > 0, "...and there was a wrap AT SPEED to judge (%d)" % events)
	_check(kept >= KEEP_MIN,
		"...without the pivot EATING the arc (%.0f%% kept, floor %.0f%%)" % [kept * 100.0, KEEP_MIN * 100.0])


## The chamber, the hook's roof, and the spur that juts into the line's path.
func _carve(sim: FactorySim) -> void:
	for x: int in range(HALL_LEFT, HALL_RIGHT + 1):
		for y: int in range(HALL_TOP, HALL_BOTTOM + 1):
			sim.mine(Vector2i(x, y))
	for x: int in range(HALL_LEFT, HALL_RIGHT + 1):
		for y: int in [HALL_TOP - 1, HALL_BOTTOM + 1]:
			if not sim.is_solid(Vector2i(x, y)):
				sim.set_solid(Vector2i(x, y), &"stone")
	# The roof block the hook bites, and the spur it will later catch on.
	for y: int in range(HOOK_ROW - 2, HOOK_ROW + 1):
		for x: int in range(HOOK_COL - 2, HOOK_COL + 1):
			sim.set_solid(Vector2i(x, y), &"stone")
	for x: int in range(SPUR_FROM, SPUR_TO + 1):
		sim.set_solid(Vector2i(x, SPUR_ROW), &"stone")
