extends "res://tools/check_base.gd"

## IS THE ROPE A WAY TO TRAVEL, OR ONLY A WAY TO DESCEND?
##
## Everything the rope has been asked to prove so far has been VERTICAL. check_grapple swings it on a rig
## built to suit it, check_plunge rides it down a sinkhole and climbs back out, check_impact catches a fall
## with it. All of that says the tool works. None of it says the tool is how you MOVE, and "a movement
## overhaul centred on the grappling hook" is a claim about horizontal distance per second, about whether
## a player crossing the world reaches for the line instead of the walk key.
##
## So: cross the same span, twice, in the same world.
##
##   ON LEGS:    hold the run and jump at anything in the way. The stride, coast drag and momentum-above-cap
##               rules are all already tuned for this; it is a fast, pleasant baseline and it should be.
##   ON THE ROPE: throw forward and up, reel to tighten the arc, lean into the swing, let go on the upswing
##               and throw the next one. The rhythm a player would find, driven as a player would drive it.
##
## Two numbers, and the second is the one that matters:
##
##   DISTANCE:   columns covered inside one identical budget. If the rope loses here it is not travel, it is
##               a stunt, and every hour spent on swing physics was spent on a garnish.
##   TOP SPEED:  the fastest the body ever goes on each route. This is what the swing is FOR: the controller
##               lifts the top-speed clamp while a line is taut precisely so an arc can carry you faster than
##               your legs can, and if that ceiling is never actually reached the lift is theoretical.
##
## VENUE MATTERS, and it is the finding this layer exists to keep visible. A grapple needs something
## overhead to bite. In a gallery, a corridor with a roof, which is what most of this world is, that is
## everywhere. Under open sky it is nothing at all, and no amount of swing tuning changes it. So the gallery
## is the gate, because it isolates the mechanic from the geography, and the real surface is measured
## alongside it and PRINTED rather than gated: the honest report is not "the rope is fast" or "the rope is
## slow" but "the rope is fast where there is a ceiling", which is a fact about level design.
##
##   godot --headless --path . --script res://tools/check_traverse.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = 32
const SETTLE: int = 30

## THE GALLERY: a level corridor with a solid roof, cut into real rock well below the surface.
const HALL_LEFT: int = 12
const HALL_RIGHT: int = 108
const HALL_FLOOR: int = 60
const HALL_HEIGHT: int = 7           ## cells of headroom — enough to swing in, tight enough to read as a hall
const HALL_ROOF: int = 3             ## cells of solid rock over it, so a hook always finds something

const BUDGET: int = 900              ## frames each route is given, identical for both
const START_COL: int = HALL_LEFT + 4

## The swing rhythm, in cells. Throwing FORWARD and UP is the whole motion; these say how far.
const THROW_AHEAD: float = 7.0
const THROW_UP: float = 6.0
const RETHROW_GAP: int = 4           ## frames of empty air between letting go and reaching again
const MIN_USEFUL: float = 2.0        ## cells — nearer than this a plant is a pin, not a hold
const HOLD_ABOVE: float = 1.5        ## ...and it must be this far ABOVE the hand to be worth swinging from
const FACE_BUDGET: int = 600         ## frames each attempt on the headland scarp is given
const COAST_FRAMES: int = 22         ## frames after a release before reaching again — the jump needs room
const STALL_FRAMES: int = 45         ## frames without gaining a column before a player would let go

## Columns of open surface the sky run is asked for. The gallery run crosses a carved corridor and can be
## measured end to end; the surface has mouths and scarps in it, so this asks for a span rather than a
## finish line and reports how far each route actually got inside the budget.
const SKY_SPAN: int = 40

const ROPE_EDGE: float = 1.15        ## frames-to-cross the legs take per frame the rope takes, to BE travel
const SPEED_EDGE: float = 1.10       ## ...and beat their top speed by this, or the lifted clamp is a fiction

func _initialize() -> void:
	print("== is the rope a way to travel ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("check_traverse: PASS — under a roof, the line is the fast way across")
		quit(0)
	else:
		print("check_traverse: FAIL (%d)" % _failures)
		quit(1)


func _run() -> void:
	var legs: Dictionary = await _cross(false, true)
	var rope: Dictionary = await _cross(true, true)
	var sky_legs: Dictionary = await _cross(false, false)
	var sky_rope: Dictionary = await _cross(true, false)

	print("  IN THE GALLERY (a roof overhead, %d columns to cross)" % legs["span"])
	print("    on legs:     %3d frames, top speed %4.0f px/s" % [legs["frames"], legs["top"]])
	print("    on the rope: %3d frames, top speed %4.0f px/s (%d throws, %d bit)"
		% [rope["frames"], rope["top"], rope["throws"], rope["bit"]])
	print("  UNDER OPEN SKY (the same body, nothing to hook, %d columns)" % sky_legs["span"])
	print("    on legs:     %3d frames, %d columns covered" % [sky_legs["frames"], sky_legs["cols"]])
	print("    on the rope: %3d frames, %d columns covered (%d throws, %d bit)"
		% [sky_rope["frames"], sky_rope["cols"], sky_rope["throws"], sky_rope["bit"]])

	var reach: float = float(legs["frames"]) / maxf(float(rope["frames"]), 1.0)
	var quick: float = float(rope["top"]) / maxf(float(legs["top"]), 1.0)
	_check(reach >= ROPE_EDGE,
		"under a roof the line CROSSES FASTER than the legs (%.2fx, floor %.2fx)" % [reach, ROPE_EDGE])
	_check(quick >= SPEED_EDGE,
		"...and the lifted speed clamp is real (%.2fx top speed, floor %.2fx)" % [quick, SPEED_EDGE])
	_check(int(rope["bit"]) > 0,
		"...because there is always something over your head to bite (%d of %d throws)"
			% [rope["bit"], rope["throws"]])
	# NOT a gate, and deliberately so. A hook with nothing to hook is not a bug in the hook; it is what the
	# sky is. Printed because the number is a level-design instruction: rope traversal on the surface needs
	# overhead rock, which in this world means the scarp faces and the sinkhole mouths, not the open plain.
	var wall: Dictionary = await _climb_scarp()
	print("  AT THE HEADLAND SCARP (a %d-row face, %d frames)" % [wall["face"], wall["frames"]])
	print("    on legs: %s;  on the rope: %s"
		% ["over it" if wall["legs"] else "stopped", "over it" if wall["rope"] else "stopped"])
	_check(not bool(wall["legs"]),
		"the headland face is genuinely past the legs (%d rows)" % wall["face"])
	_check(bool(wall["rope"]),
		"...and the rope is the answer the world already put in your hand")

	var sky_edge: float = float(sky_legs["frames"]) / maxf(float(sky_rope["frames"]), 1.0)
	print("  under open sky the line still crosses %.2fx faster, on %d opportunist throws — trees, scarps"
		% [sky_edge, sky_rope["throws"]])
	print("  ...so the surface is not ropeless, it is SPARSE: every hold out there is a landmark")


## Cross the span once. `with_rope` picks the route; `roofed` picks the venue.
func _cross(with_rope: bool, roofed: bool) -> Dictionary:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sim: FactorySim = main.sim
	var p: Player = main._player
	p.auto_input = false
	p.grapple.cut()

	var start: int = START_COL
	var floor_row: int = HALL_FLOOR
	if roofed:
		_carve(sim)
	else:
		start = main._cell_at(p.position).x
		floor_row = sim.surface_row(start)
	p.place(Vector2(float(start) * CELL + 16.0, float(floor_row) * CELL - Player.HEIGHT))
	for _i: int in 6:
		await physics_frame

	var from: int = main._cell_at(p.position).x
	var goal: int = (HALL_RIGHT - 4) if roofed else (from + SKY_SPAN)
	var far: int = from
	var spent: int = BUDGET
	var top: float = 0.0
	var throws: int = 0
	var bit: int = 0
	var idle: int = 0
	var stall: int = 0
	var last: int = from

	for f: int in BUDGET:
		var at: Vector2i = main._cell_at(p.position)
		far = maxi(far, at.x)
		if at.x >= goal:
			spent = f
			break
		if at.x > last:
			last = at.x
			stall = 0
		else:
			stall += 1
		top = maxf(top, absf(p.velocity.x))
		p.input_dir = 1.0                            # lean forward always — on a line this PUMPS the arc
		if with_rope:
			if not p.grapple.live():
				idle += 1
				if idle >= RETHROW_GAP:
					var aim: Vector2 = p.hand() + Vector2(THROW_AHEAD * CELL, -THROW_UP * CELL)
					# READ THE MARKER FIRST. The game draws an aiming ghost precisely so a player can see
					# where the hook will bite before spending the throw, and a driver that ignores it is not
					# modelling a player, it is modelling someone with their eyes shut. On the surface almost
					# every forward-and-up throw plants in the ground a cell or two ahead: too close to swing
					# from, too close to zip to, and once the winch has wound in you are on a two-foot leash
					# pinned to a wall you cannot walk away from. That is what nine hundred frames of the
					# first sky run actually were.
					# ...and LOOK TWICE. A player scanning for a hold does not fire at the first thing above
					# them and give up if it is too close; they flatten the throw and reach further out. With
					# one candidate the driver spent most of a swing refusing to throw at a roof it was
					# already brushing, which understates the tool rather than measuring it.
					var picked: Vector2 = Vector2.ZERO
					for cand: Vector2 in [aim, p.hand() + Vector2(THROW_AHEAD * 1.7 * CELL, -THROW_UP * 0.4 * CELL)]:
						var shot: Dictionary = p.grapple.trace(sim, p.hand(), cand)
						# A hold you swing FROM is a hold ABOVE you. Without this the flatter candidate
						# happily hooked the far wall of the corridor dead ahead, which is not a swing and not
						# a zip; it is a leash, and it cost the gallery run the whole budget.
						if bool(shot["hit"]) \
								and p.hand().distance_to(shot["at"]) >= MIN_USEFUL * float(CELL) \
								and (shot["at"] as Vector2).y <= p.hand().y - HOLD_ABOVE * float(CELL):
							picked = cand
							break
					if picked != Vector2.ZERO:
						idle = 0
						throws += 1
						p.grapple.fire(p.hand(), picked)
			elif p.grapple.state == Grapple.State.ANCHORED:
				if p.grapple.just_planted:
					bit += 1
				# Reel while the hook is still ahead: shortening the radius on the way in is the pump, and
				# it is also what stops a long line from simply dropping you onto the floor mid-arc.
				p.input_climb = 1.0 if p.grapple.anchor.x > p.position.x else 0.0
				# LET GO ON THE UPSWING. Past the anchor and still moving forward is the moment the arc has
				# given everything it has; holding on from there is being dragged back the way you came.
				# ...and LET GO when the arc is spent: past the anchor and still going, or simply not getting
				# anywhere. A player hanging motionless on a wound-in line presses the release key; a rig that
				# does not is measuring its own stubbornness.
				if (p.position.x > p.grapple.anchor.x and p.velocity.x > 0.0) or stall > STALL_FRAMES:
					p.grapple.cut()
					p.input_climb = 0.0
					p.request_jump()
					stall = 0
		if p.on_floor and _blocked(sim, at):
			# Jump only at something actually in the way. The first version of this hopped every single frame,
			# which reads like a fair "run and hurdle" driver and is not one: the stride only builds while the
			# boots are on the ground, so a body that is never on the ground never gets past RUN_SPEED. It
			# handed the legs a 150 px/s ceiling and the rope a flattering win over a baseline that was
			# hobbled by the rig rather than by the game.
			#
			# Given to BOTH routes, for the same reason _climb gives both routes legs: a player carrying a
			# rope still has boots, and the rope is an ADDITION to the body rather than a replacement for it.
			# Withholding the jump from the roped run is how the surface run came back at seven columns in
			# nine hundred frames, not because the rope failed, but because the rig had quietly taken away
			# the one move that gets over a step.
			p.request_jump()
		await physics_frame

	p.input_dir = 0.0
	p.input_climb = 0.0
	p.grapple.cut()
	p.auto_input = true
	var out := {"cols": far - from, "span": goal - from, "frames": spent,
		"top": top, "throws": throws, "bit": bit}
	main.queue_free()
	await physics_frame
	return out


## THE FACE. check_relief asserts the world contains walls too tall to walk up; nothing yet asserted that
## they can be GOT UP. A wall with no answer is not a design, it is a boundary, and the difference between
## the two is entirely whether the tool in your hand reaches the top. So: stand at the foot of the westward
## headland scarp and try, once on legs and once with the line.
func _climb_scarp() -> Dictionary:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in SETTLE:
		await physics_frame
	var sim: FactorySim = main.sim
	var foot: int = HeightmapWorldGen.SCARP_COLS[0] + HeightmapWorldGen.SCARP_SPAN + 2
	var top: int = HeightmapWorldGen.SCARP_COLS[0] - 2
	var face: int = sim.surface_row(foot) - sim.surface_row(top)
	var legs: bool = await _try_face(main, sim, foot, top, false)
	var rope: bool = await _try_face(main, sim, foot, top, true)
	var out := {"face": face, "legs": legs, "rope": rope, "frames": FACE_BUDGET}
	main.queue_free()
	await physics_frame
	return out


## One attempt at the face, walking WEST (the direction it is met from leaving the base).
func _try_face(main: MainView, sim: FactorySim, foot: int, top: int, with_rope: bool) -> bool:
	var p: Player = main._player
	p.auto_input = false
	p.grapple.cut()
	p.place(Vector2(float(foot) * CELL + 16.0, float(sim.surface_row(foot)) * CELL - Player.HEIGHT))
	for _i: int in 6:
		await physics_frame
	var goal_row: int = sim.surface_row(top)
	var won: bool = false
	var coast: int = 0
	for f: int in FACE_BUDGET:
		var at: Vector2i = main._cell_at(p.position)
		# STANDING on the high terrace, not merely level with it. Hanging on a wound-in line beside the lip
		# is where an unaided winch leaves you and it is not the top of anything; requiring the boots to be
		# down makes this the claim it was meant to be.
		if at.x <= HeightmapWorldGen.SCARP_COLS[0] + 1 and at.y <= goal_row and p.on_floor:
			won = true
			break
		p.input_dir = -1.0
		if with_rope:
			if coast > 0:
				coast -= 1
			elif not p.grapple.live():
				# AIM AT THE LIP, which is what the aiming ghost is for. The first version threw steeply up
				# and across; the instinctive move, and a complete miss: a five-row plateau three columns
				# away is CLEARED by any throw steeper than about forty-five degrees, so the hook sailed over
				# the top and out into open sky every single time, and the face read as unclimbable when it
				# was only badly aimed at. So target the ground just past the top edge, at whatever angle
				# that happens to be: a shallow throw that lands ON the terrace rather than a tall one that
				# flies over it.
				p.grapple.fire(p.hand(), Vector2(float(top) * CELL + 16.0,
					float(goal_row) * CELL - CELL * 0.5))
			elif p.grapple.state == Grapple.State.ANCHORED:
				p.input_climb = 1.0
				if p.grapple.length <= Grapple.MIN_LENGTH + 1.0 \
						or p.position.y <= p.grapple.anchor.y + CELL * 0.5:
					p.grapple.cut()
					p.input_climb = 0.0
					p.request_jump()
					# ...and RIDE it. Firing again on the very next frame is what kept this body pinned one
					# row under the lip for six hundred frames: the winch hauls you to the top of the line,
					# the jump lifts you the last cell, and a fresh hook thrown into that instant yanks you
					# straight back down to the anchor you just left. Letting go means letting go.
					coast = COAST_FRAMES
		if p.on_floor and f % 10 == 0:
			p.request_jump()
		await physics_frame
	p.input_dir = 0.0
	p.input_climb = 0.0
	p.grapple.cut()
	p.auto_input = true
	return won


## Is there something in the way at running height? Two cells ahead, either of the two the body occupies.
func _blocked(sim: FactorySim, at: Vector2i) -> bool:
	for d: int in [1, 2]:
		for up: int in [0, -1]:
			if sim.is_solid(at + Vector2i(d, up)):
				return true
	return false


## THE GALLERY. A level floor, headroom to swing in, and a solid roof over the lot: the shape of most of
## this world once a player has been in it a while, and the venue where a hook always has something to find.
func _carve(sim: FactorySim) -> void:
	for x: int in range(HALL_LEFT, HALL_RIGHT + 1):
		for y: int in range(HALL_FLOOR - HALL_HEIGHT, HALL_FLOOR):
			sim.mine(Vector2i(x, y))
		for y: int in range(HALL_FLOOR - HALL_HEIGHT - HALL_ROOF, HALL_FLOOR - HALL_HEIGHT):
			if not sim.is_solid(Vector2i(x, y)):
				sim.set_solid(Vector2i(x, y), &"stone")
		if not sim.is_solid(Vector2i(x, HALL_FLOOR)):
			sim.set_solid(Vector2i(x, HALL_FLOOR), &"stone")
