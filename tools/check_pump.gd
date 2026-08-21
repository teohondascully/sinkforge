extends "res://tools/check_base.gd"

## CAN YOU WIND A SWING UP?
##
## Everybody has been on a swing, and everybody knows the answer is supposed to be yes. Here it was no.
## `constrain_position` clamped the body to a circle and `resolve_velocity` killed the outward radial part,
## and between them nothing ever noticed that the RADIUS had changed — so hauling the line in at the bottom
## of an arc, the most basic thing anyone does on a rope, did nothing whatsoever to how fast the arc went.
## Every swing was worth exactly the height you fell into it from. REEL_SPEED's own comment claimed "the
## arc's speed comes from conserved tangential momentum", which is the physics this asserts and was not the
## physics that ran.
##
## Three properties, and the third is a different kind of check on purpose:
##
##   IN PHASE WINDS UP.    Reel at the bottom, pay out at the top, over and over, and the arc must reach
##                         further than one nobody touches. This is L = m·v·r doing the work; if the number
##                         comes out flat, the constraint is eating the gain.
##   THE RHYTHM IS WHAT PAYS. Do the same thing backwards — pay out at the bottom, haul at the top — and it
##                         must get you nowhere near what the in-phase arm got. A rule that pays for ANY
##                         reeling is not a skill, it is a bonus, and holding a key would be the answer.
##                         This started out as "out of phase must KILL the arc", which was a guess and is
##                         not true: paying out at the bottom does lose tangential speed, but it also drops
##                         the body further, and the two very nearly cancel (0.64 rad against 0.59 for a
##                         swing nobody touched). The real asymmetry is in the other direction — 0.89 —
##                         and that is the one worth holding the game to.
##   THE LINE IS AUDIBLE.  Play a real swing and listen to the actual mix: the winch bed must come up while
##                         hauling and the fibre must sing under load, driven by the GAME. This is here
##                         because it was silently broken. Every generator, every stream and the whole
##                         `set_line` driver shipped and went green in tools/check_voice, which called
##                         set_line by hand — while the controller never called it once, so none of it
##                         made a sound in the game. An instrument that only ever tests itself is not one.
##
##   godot --headless --path . --script res://tools/check_pump.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = FactorySim.CELL
const SETTLE: int = 30

## THE SWING RIG. A hall wide and deep enough to take a full arc without the body ever touching anything,
## with one solid block in the roof for the hook. The line starts long: the pump's whole effect is a RATIO
## of radii, so it needs room to shorten into.
const HALL_LEFT: int = 16
const HALL_RIGHT: int = 104
const HALL_TOP: int = 18
const HALL_BOTTOM: int = 58
const HOOK_COL: int = 60
const HOOK_ROW: int = 20
const BODY_COL: int = 68            ## started off to one side so it falls into an arc rather than hanging
const BODY_ROW: int = 30

const CYCLES: int = 14              ## pump cycles driven per arm
const FRAMES: int = 900             ## ...within this budget
const BOTTOM_ARC: float = 0.55      ## radians from straight down that count as "the bottom of the arc"
const WIND_EDGE: float = 1.12       ## how much further an in-phase arc must reach than an untouched one
                                    ## (measured 1.5x, so this is a floor with room, not a fitted number)
const DIE_EDGE: float = 0.92        ## ...and the most of that an out-of-phase arm may reach (measured 0.72)

const HAUL_MIN: float = 0.25        ## winch bed level the game must reach on its own while reeling
const SING_MIN: float = 0.25        ## ...and the fibre, under load

func _initialize() -> void:
	print("== can you wind a swing up ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("check_pump: PASS — the arc answers the rhythm, and you can hear it")
		quit(0)
	else:
		print("check_pump: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	_carve(main.sim)

	var idle: Dictionary = await _arm(main, 0)
	var pumped: Dictionary = await _arm(main, 1)
	var fought: Dictionary = await _arm(main, -1)
	print("  widest arc  — untouched %.2f, pumped %.2f, fought %.2f rad"
		% [idle["widest"], pumped["widest"], fought["widest"]])
	print("  peak spin   — untouched %.2f, pumped %.2f, fought %.2f rad/s"
		% [idle["rate"], pumped["rate"], fought["rate"]])
	_check(float(idle["widest"]) > 0.1,
		"the rig actually swings when left alone (%.2f rad)" % idle["widest"])
	_check(float(pumped["widest"]) >= float(idle["widest"]) * WIND_EDGE,
		"reeling IN PHASE winds the arc up (%.2f vs %.2f rad, needs %.2fx)"
			% [pumped["widest"], idle["widest"], WIND_EDGE])
	_check(float(fought["widest"]) <= float(pumped["widest"]) * DIE_EDGE,
		"...and it is the RHYTHM that pays, not the reeling (%.2f vs %.2f rad, cap %.2fx)"
			% [fought["widest"], pumped["widest"], DIE_EDGE])

	await _judge_voice(main)
	main.queue_free()
	await physics_frame


## Drive one arm and return the widest angle from straight-down the arc ever reached.
## phase 0 = hands off, 1 = reel at the bottom / pay at the top, -1 = the exact opposite.
func _arm(main: MainView, phase: int) -> Dictionary:
	var p: Player = main._player
	p.auto_input = false
	p.input_dir = 0.0
	p.input_climb = 0.0
	p.grapple.cut()
	p.place(Vector2(float(BODY_COL) * CELL + 16.0, float(BODY_ROW) * CELL))
	for _i: int in 4:
		await physics_frame
	p.grapple.fire(p.hand(), Vector2(float(HOOK_COL) * CELL + 16.0, float(HOOK_ROW) * CELL + 16.0))
	for _i: int in 40:
		await physics_frame
		if p.grapple.state == Grapple.State.ANCHORED:
			break
	if p.grapple.state != Grapple.State.ANCHORED:
		_failures += 1
		printerr("  FAIL: the hook never planted — no arc to judge")
		return {"widest": 0.0, "rate": 0.0}
	var start_len: float = p.grapple.length
	var widest: float = 0.0
	var rate: float = 0.0
	var swings: int = 0
	var was_side: int = 0
	for _i: int in FRAMES:
		var a: float = _angle(p)
		widest = maxf(widest, absf(a))
		if p.grapple.taut:
			rate = maxf(rate, p.velocity.length() / maxf(p.grapple.free_length(), 1.0))
		var side: int = signi(int(signf(a)))
		if side != 0 and side != was_side:
			swings += 1
			was_side = side
		# The pump itself: at the bottom of the arc the velocity is nearly all tangential, so shortening
		# the line converts almost all of it into speed. At the extremes it is nearly all radial and costs
		# nearly nothing to give back. Holding one direction the whole way is NOT this manoeuvre.
		var at_bottom: bool = absf(a) < BOTTOM_ARC
		if phase == 0:
			p.input_climb = 0.0
		elif at_bottom:
			p.input_climb = float(phase)
		else:
			p.input_climb = float(-phase)
		await physics_frame
		if swings >= CYCLES * 2:
			break
	p.input_climb = 0.0
	print("    phase %+d: %d half-swings, line %.0f -> %.0f px, widest %.2f rad, peak %.2f rad/s"
		% [phase, swings, start_len, p.grapple.length, widest, rate])
	# A pump that simply winched itself to the stop is not a pump, it is a lift, and the amplitude it
	# reports would be an artefact of a two-cell radius rather than of any energy it gained.
	if phase != 0:
		_check(p.grapple.length > Grapple.MIN_LENGTH * 2.0,
			"    ...phase %+d kept a real line to swing on (%.0f px)" % [phase, p.grapple.length])
	return {"widest": widest, "rate": rate}


## Angle of the body from straight below the hitch, in radians. 0 is the bottom of the arc.
func _angle(p: Player) -> float:
	var d: Vector2 = p.position - p.grapple.hitch()
	if d.length() < 0.001:
		return 0.0
	return atan2(d.x, maxf(d.y, 0.001))


## --- and can you HEAR it -------------------------------------------------------------------------

## Everything above judges the physics. This judges the WIRING, by playing the game and listening to the
## mix — no test may call set_line here, because a test calling set_line is exactly what hid the bug.
func _judge_voice(main: MainView) -> void:
	var p: Player = main._player
	var sfx: Node = main._sfx
	p.grapple.cut()
	p.place(Vector2(float(BODY_COL) * CELL + 16.0, float(BODY_ROW) * CELL))
	for _i: int in 4:
		await physics_frame
	p.grapple.fire(p.hand(), Vector2(float(HOOK_COL) * CELL + 16.0, float(HOOK_ROW) * CELL + 16.0))
	for _i: int in 40:
		await physics_frame
		if p.grapple.state == Grapple.State.ANCHORED:
			break
	var loudest_haul: float = 0.0
	var loudest_sing: float = 0.0
	for _i: int in 240:
		p.input_climb = 1.0 if absf(_angle(p)) < BOTTOM_ARC else -1.0
		await physics_frame
		loudest_haul = maxf(loudest_haul, sfx._winch_level)
		loudest_sing = maxf(loudest_sing, sfx._creak_level)
	p.input_climb = 0.0
	print("  playing a real swing drove the winch to %.2f and the line to %.2f"
		% [loudest_haul, loudest_sing])
	_check(loudest_haul >= HAUL_MIN,
		"the game itself runs the WINCH while it hauls (%.2f, floor %.2f)" % [loudest_haul, HAUL_MIN])
	_check(loudest_sing >= SING_MIN,
		"...and the LINE sings under the load it is carrying (%.2f, floor %.2f)"
			% [loudest_sing, SING_MIN])
	# ...and lets go of both when the rope does. A bed nobody turns off is worse than one nobody turns on.
	p.grapple.cut()
	for _i: int in 120:
		await physics_frame
	print("  after cutting the line the winch sits at %.2f and the fibre at %.2f"
		% [sfx._winch_level, sfx._creak_level])
	_check(sfx._winch_level < 0.05 and sfx._creak_level < 0.05,
		"...and both go quiet when the line is cut (%.2f / %.2f)"
			% [sfx._winch_level, sfx._creak_level])


## A hall big enough for a full arc, and one block in the roof to bite.
func _carve(sim: FactorySim) -> void:
	for x: int in range(HALL_LEFT, HALL_RIGHT + 1):
		for y: int in range(HALL_TOP, HALL_BOTTOM + 1):
			sim.mine(Vector2i(x, y))
	for x: int in range(HALL_LEFT, HALL_RIGHT + 1):
		sim.set_solid(Vector2i(x, HALL_BOTTOM + 1), &"stone")
	for y: int in range(HOOK_ROW - 2, HOOK_ROW + 1):
		for x: int in range(HOOK_COL - 1, HOOK_COL + 2):
			sim.set_solid(Vector2i(x, y), &"stone")
