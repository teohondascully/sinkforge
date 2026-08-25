class_name Player
extends Node2D

## The embodied avatar, purely a representation-layer entity: it reads the sim's world (is_solid,
## machine_at) for collision but never enters the deterministic tick and never writes production
## state. Delete it and the factory numbers are identical. Movement is a small custom platformer
## controller with per-axis move-then-resolve AABB collision against the sim's solid cells, the
## machines and the world bounds. Plain GDScript rather than a TileMap, so the feel is tunable.
##
## Floor authority. The heightmap slope-follow (surface_row / ramp_dir) glides smooth 45° ramps but
## knows only a 1-D per-column surface: it cannot see cave floors, dug pits or machines, and left to
## itself it fights the AABB and traps the body in a one-cell pit. So it acts only on a genuine
## rendered ramp. Everywhere else the AABB is the sole authority, through two mirror moves in the
## resolve: auto step-up over a rise of one tile or less, and floor-snap down a descent of the same.
## Guarded by tools/check_step.gd.
##
## Every feel number here is placeholder, measured against intent by tools/measure_player.gd.

const CELL: int = FactorySim.CELL
## Body AABB, 14x34 px: 0.44 x 1.06 tiles. At the zoomed-out camera the avatar reads as a small nimble
## figure in a big granular world. Just over one cell tall, so a body still needs two tiles of
## clearance and a one-tall gap is an honest squeeze. Under a cell wide, so a one-wide shaft fits.
const WIDTH: float = 14.0
const HEIGHT: float = 34.0

const RUN_SPEED: float = 150.0       ## px/s horizontal top speed
const ACCEL: float = 1700.0          ## px/s^2 toward top speed (about 0.09s): quick, but not instant
const FRICTION: float = 2200.0       ## px/s^2 rubbed off when no input (snappy stop)
const GRAVITY: float = 900.0         ## px/s^2
## Jump apex is v^2/(2g) = about 74px, which comfortably clears a two-tile (64px) wall. At -330 it was
## 60px and bounced off a two-block ledge by four pixels. Three tiles or more stays an honest wall.
const JUMP_VELOCITY: float = -365.0
## While rising with the jump key released, gravity is multiplied by this: a tap gives a short hop of
## about half a tile and a held press the full two-tile arc. It never touches falls (velocity.y >= 0)
## or rope climbs. Drivers that do not model the key default to jump_held = true.
const JUMP_CUT_GRAVITY: float = 2.1
const MAX_FALL: float = 560.0        ## px/s terminal
const COYOTE_TIME: float = 0.08      ## s of grace to still jump after leaving an edge
const JUMP_BUFFER: float = 0.10      ## s a jump press is remembered before landing (forgiving)
## The stride. RUN_SPEED is tuned for mining: close quarters and one cell at a time, stopping exactly
## where intended. That is the wrong speed for crossing a hundred and twenty-eight columns of world.
## Raising the constant fixes the traverse and ruins the mining, so top speed is a state instead.
##
## Holding one direction on the ground for STRIDE_DELAY of unbroken travel settles the miner into a run
## that tops out STRIDE_GAIN faster. Turning, stopping, hitting a wall, wading or landing hard ends it.
## Everything short of that happens at exactly the old speed, so the mining feel is untouched and
## measured top speed still reads 150. The delay is long enough that the stride cannot be flicked into,
## and it survives leaving the ground, so broken terrain can be run without breaking the run.
const STRIDE_DELAY: float = 0.9      ## s of unbroken same-way ground travel before the run starts building
const STRIDE_RAMP: float = 1.2       ## ...and s from there to full
const STRIDE_GAIN: float = 0.55      ## extra top speed at full stride (150 -> 232 px/s)
const STRIDE_DECAY: float = 3.0      ## per-second bleed once the run breaks (a third of a second to nothing)
const STRIDE_LAND_COST: float = 0.5  ## fraction of the stride a hard landing takes
## The cost of a landing. Otherwise a fall is free: the body can ride terminal velocity into rock and
## sprint off the impact frame at full speed, which makes a forty-row hole a strictly better staircase.
##
## The cost is grip, not damage. There is no health system, and a platformer that takes control away
## feels broken however justified the moment, so a hard landing instead leaves the legs with reduced
## authority for a fraction of a second scaled by how hard the body hit. Steering, jumping and mining
## all still work.
##
## Priced on the distance fallen rather than on impact speed, because impact speed saturates: terminal
## velocity arrives after 5.4 cells, so past that a six-cell hop and a forty-row plunge land identically
## and any threshold fires on both or neither. A taut line resets the fall, since a fall the rope caught
## is over, so a descent flown properly costs nothing and one merely survived costs a beat.
const STAGGER_FALL: float = CELL * 9.0   ## px of fall that lands clean, past any ordinary platforming drop
const STAGGER_FULL: float = CELL * 30.0  ## ...and the fall that costs the full beat
const STAGGER_MAX: float = 0.26      ## s of reduced grip at the worst of it: a beat, never a lockout
const STAGGER_GRIP: float = 0.34     ## × ACCEL while staggered: steering, but not steering well
var stagger: float = 0.0             ## s of stagger left; also read by the view for the recovery pose
var _fall_from: float = 0.0          ## world y the current fall began at (ground, rope or taut line)
const STRIDE_LEAN: float = 0.07      ## radians the body tilts forward at full stride (~4 degrees)
var stride: float = 0.0              ## 0..1 into the run; read by the lean, the camera and the dust
var _stride_hold: float = 0.0        ## s of unbroken qualifying travel so far (counts toward STRIDE_DELAY)
const LIFT_RISE_SPEED: float = 120.0 ## px/s the updraft carries the body up (the paid inverse of gravity)
const CLIMB_SPEED: float = 110.0     ## px/s the body travels a gripped rope (hold W/S; release = hang)
## Slope follow: a single-tile rise is walked as a 45° ramp rather than teleported over. A taller rise
## is a wall that has to be jumped. A single-tile drop is glided down too; a bigger gap is a fall.
const MAX_STEP: float = CELL * 1.3
const MAX_DROP: float = CELL * 1.3
## Floor-snap (hugging a descending step or catching a fast drop) applies only when the body is
## genuinely moving: walking sideways down stairs, or falling fast onto a ledge. It must not fire when
## a nearly stationary body loses the floor from under it, because that is the start of a fall and
## gravity has to take over instead. That case is the only one stationary in both axes.
const SNAP_WALK_MIN: float = 8.0     ## px/s of horizontal motion that counts as "walking" (stair-hug)
const SNAP_FALL_MIN: float = 250.0   ## px/s of downward speed that counts as a real "drop" (fast-fall catch)
const SNAP_STABILIZE: float = 4.0    ## a snap this small only keeps a resting body grounded (no flicker); always allowed
## The instant a resting body loses its floor it would otherwise creep down from zero velocity for
## about 0.15s before visibly moving, which reads as lag. Seeding a minimum downward speed makes the
## descent read at once. Jump arcs are untouched: a jump sets velocity.y negative, so max() leaves it.
const FALL_START: float = 150.0      ## px/s minimum fall speed seeded when a grounded body starts falling
## Water impedance, the located hazard the Pump later relieves. With the body's AABB over a water cell
## it wades. Horizontal top speed and accel are damped, gravity is buoyantly slowed to a near-neutral
## sink under a terminal cap, and the jump is weaker. It is friction rather than drowning: there is no
## health system, so every multiplier keeps the body movable. Gated only on _in_water().
const WATER_SPEED_MULT: float = 0.55   ## × RUN_SPEED horizontal top speed while wading
const WATER_ACCEL_MULT: float = 0.6    ## × ACCEL/FRICTION: speed builds and sheds sluggishly in water
const WATER_GRAVITY_MULT: float = 0.45 ## × GRAVITY: buoyant slow-fall, a descent rather than a plummet
const WATER_JUMP_MULT: float = 0.7     ## × JUMP_VELOCITY: a weaker leap, harder to hop clear of a pool
const WATER_MAX_SINK: float = 220.0    ## px/s terminal sink in water (a slow settle, not free-fall)
const WATER_MIN_LEVEL: int = 1         ## water_at at/above this counts the cell as "wet" (any water impedes)
## Physics integrates in chunks no larger than this, so a big frame delta (fast-forward at
## Engine.time_scale > 1, or a real frame drop) cannot let the body skip past a tile between collision
## resolves. At time_scale 1 a 1/60 frame is a single substep, so play feel is unchanged.
const MAX_SUBSTEP: float = 1.0 / 60.0

var sim: FactorySim                  ## set by MainView; read-only use (collision queries)
## When true (normal play) the controller samples the keyboard. Set it false and drive input_dir and
## request_jump() directly to measure motion deterministically.
var auto_input: bool = true
var input_dir: float = 0.0           ## -1 left, +1 right
var input_climb: float = 0.0         ## +1 up, -1 down: the rope-climb axis (W/S, drivable directly)
var velocity: Vector2 = Vector2.ZERO
var on_floor: bool = false
var climbing: bool = false           ## gripping a rope this step (read by the sprite/juice; repr-only)
var facing: int = 1

## Cosmetic feedback MainView reads to spawn juice (dust, shake). Never touches the sim.
var landed_hard: bool = false        ## one-shot: set the frame the body lands from a real fall
var last_impact: float = 0.0         ## the landing's downward speed (px/s); juice scales with it
var jump_held: bool = true           ## is the jump key still down (auto_input polls it; drivers may set)
## Animation state, pure representation: it drives sprite-frame selection only. `digging` is a brief
## flag MainView pokes via note_dig() so the dig pose shows across the gaps between mine ticks.
var digging: bool = false

var _jump_request: bool = false
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _was_on_floor: bool = false
var _squash: float = 0.0             ## 0..1 landing squash, decays; pure visual
var _land_hold: float = 0.0          ## seconds the landing-impact frame is held
var _climb_phase: float = 0.0        ## climb-cycle clock, advanced by rope travel
var _walk_phase: float = 0.0         ## walk-cycle clock for the bob / walk anim-frame pick
var _anim_time: float = 0.0          ## free-running clock for non-walk frame cycling (the dig loop)
var _dig_hold: float = 0.0           ## seconds the dig pose stays latched after the last mined cell
## The grapple (see scenes/grapple.gd). The body owns one because the line is a constraint on the body
## rather than a thing in the world: it changes how gravity resolves, so it lives inside the same substep.
var grapple: Grapple = Grapple.new()
## Air control is normally the same as ground control, generous and correct for a mining game. On the
## rope it is deliberately weaker, because a swing that can be steered freely is flying and the
## pleasure of a pendulum is committing to an arc. Enough authority to pump and aim the release, no more.
const SWING_ACCEL_MULT: float = 0.42
const SWING_DRAG: float = 0.22       ## per-second velocity bleed while taut, or a pumped swing never settles
## A terminal speed for the arc. With almost no drag, a driver pumping perfectly every frame reached
## 6.6x RUN_SPEED, about 31 cells a second, which is a slingshot rather than a swing and unreadable at
## that speed. The cap keeps the reward real while leaving it somewhere the camera and collider follow.
const SWING_MAX_SPEED: float = RUN_SPEED * 2.8
const SWING_LEAN: float = 0.40       ## radians (~23 deg) the body tilts into a full-speed arc
const SWING_LEAN_EASE: float = 7.0   ## per-second easing so the tilt settles rather than snapping
## How fast speed above the run cap bleeds off. Ground is a skid; air is nearly free, because nothing is
## touching the body. At these values a full-speed release (420 px/s) coasts about three seconds through
## open air and skids to a walk in a third of a second on landing: a good swing visibly buys distance.
const GROUND_COAST_DRAG: float = 900.0
const AIR_COAST_DRAG: float = 95.0
var _step_grounded: bool = false     ## set per-step: whether the horizontal resolve may auto-step up here
var _stepped: bool = false           ## set by the resolve when it auto-stepped up onto a ledge this frame


func _ready() -> void:
	Controls.register()        # so the body works standalone, not only under MainView


## The winch does work. The distance constraint only clamps a position to a circle and cancels outward
## radial velocity, so shortening the line corrects the body's position and leaves its velocity
## untouched. That makes the reel a lift: it carries the body along the rope and sets it down at a
## standstill, with no momentum to release into.
##
## Taking line in at REEL_SPEED means the body approaches the anchor at REEL_SPEED, so the inward
## radial component is set to the haul rate. Never added to it, which would compound every frame, and
## never applied to the tangential component, which is the swing. So it only ever speeds the body up
## along the line, and a body already closing faster than the winch keeps its own speed.
func _winch_drive(delta: float) -> Vector2:
	if grapple.hauled <= 0.0 or delta <= 0.0:
		return velocity
	var d: Vector2 = position - grapple.anchor
	if d.length() < 0.001:
		return velocity
	var out_dir: Vector2 = d.normalized()
	var radial: float = velocity.dot(out_dir)          # negative = already closing on the anchor
	var want: float = -grapple.hauled / delta          # ...and this is how fast the line says we close
	if want >= radial:
		return velocity
	return velocity + out_dir * (want - radial)


## Put the body somewhere without it counting as having fallen there. The landing cost is priced on
## distance dropped, so anything moving the body by assignment (a savegame restoring a position, a rig
## setting up a shot) would bank the whole teleport as a fall and charge for it at the next touchdown.
## Nothing teleports during play, so this is the seam every non-gameplay mover goes through.
func place(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
	_fall_from = at.y
	stagger = 0.0


func _physics_process(delta: float) -> void:
	if auto_input:
		input_dir = Controls.axis(Controls.LEFT, Controls.RIGHT)  # remappable move axis (-1..+1)
		input_climb = Controls.axis(Controls.DOWN, Controls.UP)   # W/S: grab and ride a rope
		# Jump is W or Space, but on a rope W climbs instead. Holding either counts as jump-held for the
		# variable-height arc off-rope. On-rope it is harmless, since the arc-cut is gated to non-climbing.
		jump_held = Controls.pressed(Controls.JUMP) or Controls.pressed(Controls.UP)
	landed_hard = false                       # reset once per frame; a substep may only set it true
	grapple.begin_frame()                     # same contract for the line's plant/release one-shots
	var remaining: float = delta
	while remaining > 0.0:
		_step(minf(remaining, MAX_SUBSTEP))
		remaining -= MAX_SUBSTEP
	# On a taut line the body tilts into its own arc, because a sprite that stays upright while moving
	# sideways at 400 px/s reads as a sticker being dragged. Rotation only affects _draw: the collider's
	# AABB comes from position and the size constants. On the ground the same lines lean a full stride.
	var want_lean: float = (velocity.x / SWING_MAX_SPEED) * SWING_LEAN if grapple.taut \
		else stride * STRIDE_LEAN * float(facing)
	rotation = lerpf(rotation, clampf(want_lean, -SWING_LEAN, SWING_LEAN),
		1.0 - exp(-SWING_LEAN_EASE * delta))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not auto_input:
		return
	if event.is_action_pressed(Controls.JUMP):
		request_jump()
	elif event.is_action_pressed(Controls.UP) and not _on_rope():
		request_jump()   # W jumps, unless there is a rope here, where W climbs instead


## Is the body gripping or standing on a placed rope right now? Gates W between jump (no rope) and climb
## up (on a rope), so the same key does the natural thing in both contexts.
func _on_rope() -> bool:
	return sim != null and sim.is_climbable(_cell_of(position))


## Where the line leaves the body: the winch on the miner's belt, above centre so the rope does not
## grow out of their boots. Also the point the constraint measures from, so the swing pivots at the torso.
func hand() -> Vector2:
	return position + Vector2(0.0, -HEIGHT * 0.18)


func request_jump() -> void:
	_jump_request = true
	jump_held = true        # a requested jump implies the key is down now. Polling or a driver
	                    # wanting a tap may release it on a later frame, so never a stale false.


## MainView pokes this each time a cell is actually mined. Latches the dig pose for a beat so it reads
## across the mine-cooldown gaps, and turns a standing body to face the dug cell. Cosmetic only.
func note_dig(face: int) -> void:
	_dig_hold = 0.18
	if input_dir == 0.0 and face != 0:
		facing = face


## One physics step: horizontal (with slope follow) then vertical, each integrated and collided.
func _step(delta: float) -> void:
	# Water impedance, sampled once per step and applied by the multipliers below. On dry land every
	# multiplier is 1.0, so the resolve, step-up, snap and agility are unchanged.
	var wet: bool = _in_water()
	_update_stride(delta, wet)
	var speed_top: float = RUN_SPEED * (1.0 + STRIDE_GAIN * stride) * (WATER_SPEED_MULT if wet else 1.0)
	var accel: float = ACCEL * (WATER_ACCEL_MULT if wet else 1.0) \
			* (STAGGER_GRIP if stagger > 0.0 else 1.0)
	var friction: float = FRICTION * (WATER_ACCEL_MULT if wet else 1.0)
	var gravity: float = GRAVITY * (WATER_GRAVITY_MULT if wet else 1.0)
	var max_fall: float = WATER_MAX_SINK if wet else MAX_FALL

	# Accelerate toward the input target, or rub off speed with friction. Instant reads stiff. On a taut
	# line the body is on a pendulum: input still bites, which is how an arc is pumped and a release
	# aimed, but at reduced authority, and the clamp is lifted so a swing can outrun the legs.
	if grapple.taut:
		if input_dir != 0.0:
			velocity.x += input_dir * accel * SWING_ACCEL_MULT * delta
			facing = int(signf(input_dir))
	elif absf(velocity.x) > speed_top + 1.0:
		# Above top speed the body is coasting rather than running, and the normal controller throws that
		# away: `move_toward(velocity, input * top)` decelerates a body already travelling faster than top
		# speed, and friction does the same on release. While over the cap only two things slow the body.
		# A deliberate input against its travel always has full braking authority. A coast drag, much
		# weaker in the air than on the ground, does the rest. Below the cap nothing here applies.
		var travel: float = signf(velocity.x)
		if input_dir != 0.0:
			facing = int(signf(input_dir))
		if input_dir * travel < 0.0:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)   # braking always wins
		else:
			var coast: float = GROUND_COAST_DRAG if on_floor else AIR_COAST_DRAG
			velocity.x = move_toward(velocity.x, travel * speed_top, coast * delta)
	elif input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * speed_top, accel * delta)
		facing = int(signf(input_dir))
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	velocity.y = minf(velocity.y + gravity * delta, max_fall)
	# Variable jump height: rising with the jump key released, extra gravity clips the arc. In water the
	# arc-cut uses the same buoyant gravity, so a released hop settles gently.
	if velocity.y < 0.0 and not jump_held and not climbing:
		velocity.y = minf(velocity.y + gravity * (JUMP_CUT_GRAVITY - 1.0) * delta, max_fall)
	# Rope grip, representation only like the updraft: overlapping a placed rope, a climb press grabs it
	# and holds until the body leaves or jumps off. Gripping counts as grounded below, so Space jumps off.
	var on_rope: bool = sim.is_climbable(_cell_of(position))
	if not on_rope:
		climbing = false
	elif input_climb != 0.0:
		climbing = true
	var grounded: bool = on_floor or _coyote > 0.0 or climbing
	if _jump_request:
		_jump_buffer = JUMP_BUFFER          # remember a press so it fires the instant the body lands
	_jump_request = false
	# Jumping while the line is taut cuts it and adds the jump on top of whatever the arc built up, so a
	# release timed at the bottom stacks the leap onto the swing's speed. A slack line is left alone.
	if _jump_buffer > 0.0 and grapple.taut:
		grapple.cut()
		velocity.y = minf(velocity.y, 0.0) + JUMP_VELOCITY * (WATER_JUMP_MULT if wet else 1.0)
		velocity *= Grapple.RELEASE_KICK
		_jump_buffer = 0.0
	elif _jump_buffer > 0.0 and grounded:
		velocity.y = JUMP_VELOCITY * (WATER_JUMP_MULT if wet else 1.0)   # weaker leap out of a pool
		on_floor = false
		climbing = false                    # a jump lets go of the rope (Space off, W up: distinct verbs)
		_coyote = 0.0
		grounded = false
		_jump_buffer = 0.0
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	var impact_v: float = velocity.y         # remembered for the landing squash

	# Updraft: in a lift's open shaft the body is carried up, the rideable half of the lift. It ensures
	# at least rise speed upward, which a jump can still beat, and counts as airborne for slope-follow.
	if sim.updraft_at(_cell_of(position)):
		velocity.y = minf(velocity.y, -LIFT_RISE_SPEED)
		grounded = false

	# The climb: while gripping, gravity is replaced by direct travel. Hold W/S to ride the rope, release
	# to hang. Runs after the updraft so a gripped rope wins over a draft. The vertical resolve still
	# applies: climbing into a ceiling stops the body, climbing down onto a floor lands it.
	if climbing:
		velocity.y = -input_climb * CLIMB_SPEED
		# Top of rope: with no rope above this cell, rising further pushes the centre off the rope. That
		# un-grips and falls and re-grips, jittering at the anchor. Clamp the rise so the grip holds.
		if input_climb > 0.0 and not sim.is_climbable(_cell_of(position) + Vector2i(0, -1)):
			var top_hold: float = float(_cell_of(position).y * CELL) + 6.0
			velocity.y = clampf((top_hold - position.y) / delta, velocity.y, 0.0)

	# The line is flown, reeled and constrained inside the substep, so a fast swing collides every tile
	# the same way a fast fall does. Up and down reel while anchored, the same axis that rides a rope.
	#
	# The winch hauls from standing, because gating it to being off the floor would cost the tool its
	# whole point: the trip back up. What is refused is not height but the direction of the pull. A hook
	# planted in ground ahead of the body hauls it along, and that zip is the only rope verb available
	# under an open sky. A line pointing mostly downward while the boots are planted would wind the body
	# into the floor.
	grapple.advance(sim, hand(), delta)
	var reach: Vector2 = grapple.anchor - position
	var into_floor: bool = on_floor and reach.y > absf(reach.x)
	if grapple.state == Grapple.State.ANCHORED and not into_floor:
		grapple.reel(input_climb, delta)

	# Horizontal move. Two floor authorities, separated so they cannot fight and trap the body in a dug
	# one-cell pit. On a genuine rendered ramp the heightmap glides the feet up and down the 45°
	# hypotenuse; everywhere else the AABB is the sole authority, with auto step-up for rises of one tile
	# or less and floor-snap for descents of the same. Slopes stay smooth and the body climbs out of pits.
	position.x += velocity.x * delta
	var glided: bool = false
	if grounded and not climbing and velocity.y >= 0.0 and sim.ramp_dir(_cell_of(position).x) != 0:
		glided = _follow_slope(delta)   # never slope-yank a body hanging on a rope above a ramp
	_step_grounded = grounded          # let the horizontal resolve auto-step ≤1-tile walls when grounded
	_stepped = false
	_resolve_axis(true)

	# On a ramp the feet ride a virtual hypotenuse above the real solid square and _follow_slope grounds
	# the body itself. An auto step-up likewise just placed the feet on a ledge, perched on its edge with
	# the footprint possibly still over the lower cell, so this frame's gravity drop is skipped in both
	# cases; otherwise the same frame's fall would yank the body straight back down.
	if glided or _stepped:
		velocity.y = 0.0
		on_floor = true
	else:
		position.y += velocity.y * delta
		on_floor = false
		_resolve_axis(false)
		# Snap-hug the terrain below. A tiny snap always fires, keeping a resting body grounded without
		# flicker; a full step-down fires only when the body is genuinely moving. So a nearly stationary
		# body that loses its floor to a dig falls instead of teleporting onto the next surface.
		if grounded and not on_floor and velocity.y >= 0.0:
			var allow_step: bool = absf(velocity.x) > SNAP_WALK_MIN or velocity.y > SNAP_FALL_MIN
			_snap_to_floor(allow_step)

	# The constraint, applied after the body has integrated and collided on both axes: pull the position
	# back onto the circle, then cancel the outward half of the velocity and nothing else. Running last
	# is what stops it fighting the collider, so a swing into a wall stops at the wall and the line goes
	# slack until the body swings back inside its radius. The re-resolve catches a stray pixel of overlap.
	if grapple.state == Grapple.State.ANCHORED:
		grapple.update_line(sim, position)     # catch the line on corners / let it off them, then constrain
		var swung: Vector2 = grapple.constrain_position(position)
		if grapple.taut:
			position = swung
			velocity = grapple.resolve_velocity(position, velocity)
			# The pump, before the winch: a shorter line carries the same angular momentum at a higher
			# tangential speed. resolve_velocity just made the velocity purely tangential, so this scales it.
			velocity = grapple.pump(position, velocity)
			velocity = _winch_drive(delta)
			velocity -= velocity * SWING_DRAG * delta      # a rope has losses; a frictionless one feels fake
			velocity = velocity.limit_length(SWING_MAX_SPEED)
			_resolve_axis(true)
			_resolve_axis(false)

	# The frame a resting body loses its floor it would otherwise creep down from zero velocity, which
	# reads as lag. Seed a brisk minimum fall so the descent starts on the next frame. Gated to the
	# grounded-to-airborne edge and to genuine falls, since a jump is negative here and never altered.
	if _was_on_floor and not on_floor and velocity.y >= 0.0:
		velocity.y = maxf(velocity.y, FALL_START)

	# Landing squash + a one-shot "landed hard" signal for juice, on touching ground after a real fall.
	if on_floor and not _was_on_floor and impact_v > 240.0:
		_squash = 1.0
		landed_hard = true
		last_impact = impact_v           # the consumer scales dust, shake and thump by this
		_land_hold = 0.14                # hold the landing-impact frame a beat
		stride *= 1.0 - STRIDE_LAND_COST # a heavy landing costs the run
		var fell: float = position.y - _fall_from
		if fell > STAGGER_FALL:
			stagger = maxf(stagger, STAGGER_MAX * clampf(
				(fell - STAGGER_FALL) / (STAGGER_FULL - STAGGER_FALL), 0.0, 1.0))
			# Hold the impact pose for exactly as long as the grip is missing. A cost the player cannot see
			# reads as the controller gone vague: land hard, fold up for a beat, push off slowly.
			_land_hold = maxf(_land_hold, stagger)
	_land_hold = maxf(0.0, _land_hold - delta)
	stagger = maxf(0.0, stagger - delta)
	# Anything holding the body is where the next fall starts from: ground, rope or a taut line.
	if on_floor or climbing or grapple.taut:
		_fall_from = position.y
	if climbing:
		_climb_phase += absf(velocity.y) * delta * 0.055   # hand-over-hand cadence tracks climb speed
	_was_on_floor = on_floor
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	_walk_phase += (absf(velocity.x) * delta * 0.06) if on_floor else 0.0
	_anim_time += delta
	_dig_hold = maxf(0.0, _dig_hold - delta)
	digging = _dig_hold > 0.0

	_coyote = COYOTE_TIME if on_floor else _coyote - delta


## Track the walkable surface as a 45° height field so the body glides along ramps instead of popping.
## Samples the surface under the body centre and its leading edge and snaps the feet onto the higher of
## the two, but only within one tile of rise or of drop: taller is a wall for the resolve to block and
## deeper is a real fall for gravity. A climb into a ceiling is rejected, since a tight gap is a wall.
func _follow_slope(delta: float) -> bool:
	var rect: Rect2 = _aabb()
	# The box rests on the highest ground under its footprint: sample both bottom corners and the centre.
	var target: float = minf(_surface_y(rect.position.x + 1.0),
			_surface_y(rect.end.x - 1.0))
	target = minf(target, _surface_y(position.x))
	var lift: float = rect.end.y - target  # feet_y - surface_y: >0 climb up, <0 step down
	if lift > MAX_STEP or lift < -MAX_DROP:
		return false  # rise too tall (a wall) or drop too deep (a real fall) → not on this surface
	var ny: float = target - HEIGHT * 0.5
	if lift > 0.5:
		var top_y: float = ny - HEIGHT * 0.5 + 1.0  # don't climb into a ceiling (a tight gap is a wall)
		if _blocked(_cell_of(Vector2(rect.position.x + 1.0, top_y))) \
				or _blocked(_cell_of(Vector2(rect.end.x - 1.0, top_y))):
			return false
		# Cap the per-frame upward glide to what horizontal travel warrants (a 45° ramp rises about as fast
		# as the body walks) plus a small crest allowance. Without it, mounting a ramp is a one-frame pop
		# where the sampled surface jumps a tile, and worse the taller the body. Guarded by check_stepup.
		var max_rise: float = absf(velocity.x) * delta + 3.0
		ny = maxf(ny, position.y - max_rise)   # limit this frame's rise (position.y is the current centre)
	position.y = ny
	return true


## World-Y of the walkable surface at a horizontal position, read from the sim's silhouette authority
## (surface_row / ramp_dir). That is the same source the renderer draws from, so the hypotenuse the
## body glides is exactly the diagonal on screen. Terrain only by construction: a placed machine is not
## in the silhouette, so it is a box the square resolve bumps rather than a phantom invisible ramp.
func _surface_y(world_x: float) -> float:
	var c: int = floori(world_x / float(CELL))
	var frac: float = world_x / float(CELL) - float(c)  # 0..1 across column c
	var base: float = float(sim.surface_row(c) * CELL)
	match sim.ramp_dir(c):
		1:
			return base - frac * float(CELL)          # one tile higher to the right: ramp up rightward
		-1:
			return base - (1.0 - frac) * float(CELL)  # one tile higher to the left: ramp up leftward
		_:
			return base                               # flat top (or peak/valley): no ramp


## Push the body out of any blocked cell it now overlaps. The horizontal pass resolves by minimum
## penetration, pushing out by the overlap depth rather than snapping to the cell face. That removed a
## 47px backward teleport. An overlap shallower in Y than in X is a ledge rather than a wall, so the
## sideways push is skipped and the vertical pass lands the body instead.
func _resolve_axis(horizontal: bool) -> void:
	var rect: Rect2 = _aabb()
	var lo: Vector2i = _cell_of(rect.position)
	var hi: Vector2i = _cell_of(rect.end - Vector2(0.001, 0.001))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			var cell := Vector2i(cx, cy)
			if not _blocked(cell):
				continue
			var cell_rect := Rect2(float(cx * CELL), float(cy * CELL), float(CELL), float(CELL))
			if not rect.intersects(cell_rect):
				continue
			if horizontal:
				var ov_x: float = minf(rect.end.x, cell_rect.end.x) - maxf(rect.position.x, cell_rect.position.x)
				var ov_y: float = minf(rect.end.y, cell_rect.end.y) - maxf(rect.position.y, cell_rect.position.y)
				# THE LEDGE EXEMPTION ONLY APPLIES BELOW, and until it said so this test was
				# direction-blind. Its intent is "the body is clipping the top of a block UNDER it, so
				# let the vertical pass land it instead of blocking the walk". The identical condition
				# fires when the body is clipping the BOTTOM of a block above it, and nothing in the
				# branch compared the cell to the body: a two-way classifier, ledge or wall, in a world
				# that also contains ceilings.
				#
				# WHAT IT COST. HEIGHT is just over CELL, so a resting body's head pokes exactly
				# HEIGHT - CELL = 2px into the row above its own, on every walking frame (the horizontal
				# resolve runs before the vertical integration, on feet the last vertical pass snapped to
				# a row boundary). The test therefore reduced to "did this frame carry the body more than
				# 2px in", and at walking speed it does about half the time. Measured on a one-row tunnel
				# over 16 approaches differing ONLY in sub-cell start phase: 8 of 16 crossed at full
				# stride, 3 of 16 at RUN_SPEED, same map, same body, same input. The note on HEIGHT above
				# says a one-tall gap is an honest squeeze; it was a coin flip instead, and no fixture
				# could see it, because a fixture draws the same phase on every run. Comparing the cell
				# to the body makes it 16 of 16 refused in both legs. Guarded by check_stepup.
				if ov_x > ov_y and cell_rect.get_center().y > rect.get_center().y:
					continue          # shallower in Y → a ledge to step/land onto, not a wall to block
				# A wall in the path. Before blocking, try to step up onto it: the auto-step the heightmap
				# cannot give, identical for a dug pit's edge, a cave ledge and a placed machine, none of
				# which are in surface_row or ramp_dir. Only a rise of one tile or less with head clearance.
				if _step_grounded and absf(velocity.x) > 1.0:
					var lift: float = rect.end.y - cell_rect.position.y  # feet depth below the obstacle top
					if lift > 0.5 and lift <= MAX_STEP:
						var lifted := Rect2(rect.position.x, rect.position.y - lift, WIDTH, HEIGHT)
						if not _aabb_blocked(lifted):
							position.y -= lift
							on_floor = true
							_stepped = true          # tell _step to skip this frame's gravity drop
							rect = _aabb()
							continue                 # stepped up; keep the x-move, don't block it
				# Push out by the penetration depth, away from the cell centre (no snap-to-face teleport).
				position.x += ov_x if rect.get_center().x > cell_rect.get_center().x else -ov_x
				velocity.x = 0.0
			else:
				if velocity.y > 0.0:
					position.y = cell_rect.position.y - HEIGHT * 0.5
					on_floor = true
				elif velocity.y < 0.0:
					position.y = cell_rect.end.y + HEIGHT * 0.5
				velocity.y = 0.0
			rect = _aabb()


## A cell blocks the body if it's solid earth, holds a machine (you stand on machines), or is a
## world boundary (side walls + floor). Open sky above the world is not blocked.
func _blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= FactorySim.GRID_COLS:
		return true
	if cell.y >= FactorySim.GRID_ROWS:
		return true
	if cell.y < 0:
		return false
	# Wood and leaves are walk-through: tree trunks and foliage never wall the body, and the bazaar's
	# wood frame is a shop the body enters, so one rule covers both. Its earth interior floor is not
	# wood, so it still blocks. Without this a body taller than a tile would be walled by any trunk.
	if sim.is_solid(cell):
		var m: StringName = sim.material_at(cell)
		if m != &"wood" and m != &"leaves":
			return true
	return sim.machine_at(cell) != null


## Hug descending terrain without the heightmap. After a grounded move that left the body hanging just
## above a lower step, snap the feet down onto the nearest solid within MAX_DROP so walking down reads
## smooth. A real drop finds no floor in range and lets gravity take over. This mirrors the auto
## step-up. `allow_step` permits a full-tile step down and is only true while moving; a tiny
## stabilising snap always fires.
func _snap_to_floor(allow_step: bool) -> void:
	var rect: Rect2 = _aabb()
	var feet: float = rect.end.y
	var best: float = feet + MAX_DROP + 1.0
	var col_lo: int = floori((rect.position.x + 1.0) / float(CELL))
	var col_hi: int = floori((rect.end.x - 1.0) / float(CELL))
	var row_lo: int = floori(feet / float(CELL))
	var row_hi: int = floori((feet + MAX_DROP) / float(CELL))
	for cx: int in range(col_lo, col_hi + 1):
		for ry: int in range(row_lo, row_hi + 1):
			if _blocked(Vector2i(cx, ry)):
				var top: float = float(ry * CELL)
				if top >= feet - 1.0 and top < best:
					best = top
				break                       # first solid going down in this column = its floor
	if best <= feet + MAX_DROP:
		var drop: float = best - feet
		if drop <= SNAP_STABILIZE or allow_step:   # tiny = stabilize (always); full step-down only while moving
			position.y += drop
			on_floor = true
			velocity.y = 0.0


## True if any blocked cell overlaps `box`. This is the head-clearance check gating an auto step-up, so
## the body never steps into a space it does not fit and a two-tile wall stays a wall.
func _aabb_blocked(box: Rect2) -> bool:
	var lo: Vector2i = _cell_of(box.position)
	var hi: Vector2i = _cell_of(box.end - Vector2(0.001, 0.001))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			if _blocked(Vector2i(cx, cy)) \
					and box.intersects(Rect2(float(cx * CELL), float(cy * CELL), float(CELL), float(CELL))):
				return true
	return false


func _aabb() -> Rect2:
	return Rect2(position.x - WIDTH * 0.5, position.y - HEIGHT * 0.5, WIDTH, HEIGHT)


func _cell_of(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(CELL)), floori(world_pos.y / float(CELL)))


## Advance the stride. Three states and nothing else:
##
##   Building: grounded, dry, off the line, pushing one way and actually travelling that way at close
##             to top speed. Time banks toward STRIDE_DELAY first, then the stride itself ramps.
##   Holding:  airborne with a run already going, because a ledge mid-sprint must not cost the sprint.
##   Breaking: everything else. Bleeds fast enough that a mistake reads as a mistake.
##
## A wall needs no special case: it zeroes velocity.x, which fails the travelling test.
func _update_stride(delta: float, wet: bool) -> void:
	var building: bool = on_floor and not wet and not climbing and not grapple.taut \
		and input_dir != 0.0 and input_dir * velocity.x > 0.0 \
		and absf(velocity.x) > RUN_SPEED * 0.8
	if building:
		_stride_hold += delta
		if _stride_hold > STRIDE_DELAY:
			stride = minf(1.0, stride + delta / STRIDE_RAMP)
		return
	if not on_floor and stride > 0.0 and input_dir * velocity.x >= 0.0:
		return                                  # airborne mid-run: the run keeps, it just stops growing
	_stride_hold = 0.0
	stride = maxf(0.0, stride - STRIDE_DECAY * delta)


## Is the body wading: does any cell its AABB overlaps hold water at or above WATER_MIN_LEVEL? Reads
## the sim's water grid and never writes it, like the collision queries. Returns false with no sim or a
## dry world. Covers the same span the resolve walks, so feet entering a pool impede on contact.
func _in_water() -> bool:
	if sim == null:
		return false
	var rect: Rect2 = _aabb()
	var lo: Vector2i = _cell_of(rect.position)
	var hi: Vector2i = _cell_of(rect.end - Vector2(0.001, 0.001))
	for cy: int in range(lo.y, hi.y + 1):
		for cx: int in range(lo.x, hi.x + 1):
			if sim.water_at(Vector2i(cx, cy)) >= WATER_MIN_LEVEL:
				return true
	return false


## Frame fallback chains: a state whose art has not landed borrows the nearest drawn pose rather than
## snapping to a neutral stand, and every chain drains toward the idle frame. So climb_0 can land alone,
## or nothing at all, and every state still shows something that belongs to the motion. Acyclic by hand.
const SPRITE_FALLBACKS: Dictionary = {
	"miner_swing": "miner_fall", "miner_fall": "miner_jump", "miner_jump": "miner_idle",
	"miner_haul": "miner_climb_0",
	"miner_climb_0": "miner_climb", "miner_climb_1": "miner_climb",
	"miner_hang": "miner_climb", "miner_climb": "miner_idle",
	"miner_land": "miner_idle",
	"miner_walk_0": "miner_idle", "miner_walk_1": "miner_idle",
	"miner_walk_2": "miner_idle", "miner_walk_3": "miner_idle",
	"miner_dig_0": "miner_idle", "miner_dig_1": "miner_idle",
	"miner_idle": "miner",
}


## The logical sprite-frame key for the body's current motion state, in priority order: digging, the
## line, the rope, airborne, walking, idle. Walk cycles 4 frames off the walk clock; dig alternates 2.
func _sprite_key() -> String:
	if digging:
		return "miner_dig_0" if int(_anim_time * 8.0) % 2 == 0 else "miner_dig_1"
	# A live line outranks the floor and the rope: once the constraint is doing work the body is hanging
	# off it, and that is the only pose explaining what it is about to do. Reeling gets its own frame.
	if grapple.taut:
		return "miner_swing"
	if grapple.state == Grapple.State.ANCHORED and input_climb > 0.0:
		return "miner_haul"
	if climbing:
		# Moving on the rope cycles the climb; a still grip hangs, a distinct held pose.
		if absf(velocity.y) > 6.0:
			return "miner_climb_%d" % (int(_climb_phase) % 2)
		return "miner_hang"
	if not on_floor:
		# Up and down are different beats: the rise is a tuck, the drop streams the legs out behind.
		return "miner_fall" if velocity.y > 0.0 else "miner_jump"
	if _land_hold > 0.0:
		return "miner_land"        # the landing-impact beat, right after touchdown
	if absf(velocity.x) > 10.0:
		return "miner_walk_%d" % (int(_walk_phase) % 4)
	return "miner_idle"


## The best drawn texture for a state key: walk its fallback chain, then the baked idle and finally the
## hand-made original. Returning null is load-bearing: it hands the body back to the code-drawn figure.
func _resolve_tex(key: String) -> Texture2D:
	var k: String = key
	while true:
		var t: Texture2D = Art.tex(k)
		if t != null:
			return t
		if not SPRITE_FALLBACKS.has(k):
			break
		k = SPRITE_FALLBACKS[k]
	var idle: Texture2D = Art.tex("miner_idle")
	return idle if idle != null else Art.tex("miner")


## How full the pack reads, 0..1. There is no carry cap in the sim (T3.8: mass is counts and slots, not a
## weight system), so this saturates on total item count rather than a fraction of some capacity: a single
## ore ticks the pack visibly, a loaded-up return trip reads as full, and nothing has to invent a max.
const CARRY_VISUAL_SATURATION: float = 10.0

func _carry_load() -> float:
	if sim == null or sim.inventory.is_empty():
		return 0.0
	var total: int = 0
	for count: Variant in sim.inventory.values():
		total += int(count)
	return 1.0 - exp(-float(total) / CARRY_VISUAL_SATURATION)


## The miner. Draws the motion-appropriate `assets/sprites/miner*.png` frame if present, feet-anchored
## and flipped by facing. Falls back to the idle frame and then to the code-drawn figure.
func _draw() -> void:
	var f: float = float(facing)
	# Contact shadow: a soft dark ellipse at the feet so the body sits on the ground rather than floating.
	# It shrinks while airborne, so a jump reads as leaving the floor.
	var grounded_amt: float = 1.0 if on_floor else 0.45
	draw_set_transform(Vector2(0.0, HEIGHT * 0.5 - 1.0), 0.0, Vector2(1.0, 0.30))
	draw_circle(Vector2.ZERO, WIDTH * 0.72 * grounded_amt, Color(0.0, 0.0, 0.0, 0.34 * grounded_amt))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sxq: float = 1.0 + 0.18 * _squash             # landing squash widens X
	var syq: float = 1.0 - 0.22 * _squash             # ...and flattens Y
	var bob: float = -absf(sin(_walk_phase)) * 1.2 if (on_floor and absf(velocity.x) > 10.0) else 0.0
	# The pack: a load-scaled sack drawn behind the body, on the back (opposite facing) at shoulder height,
	# so the body sprite occludes the near half and only the carried bulk peeks out, T3.8's "haul has no
	# body." Drawn before the tex so it sits underneath; the sack itself never reads a sprite frame.
	var load: float = _carry_load()
	if load > 0.0:
		var pack_center := Vector2(-f * WIDTH * 0.46, -HEIGHT * 0.10 + bob)
		var pack_r: float = WIDTH * (0.30 + 0.30 * load)
		# A canvas tan, not a leather brown: the overalls and the sprite's own outline already own the dark
		# warm register, so a bulge in that family would sit unread against them at small sizes. The same
		# cool rim used on the body silhouette (line ~772) separates the sack the same way it separates the
		# body, drawn as one oversized circle underneath rather than the 8-direction loop: cheap, and the
		# pack has no limbs to halo around.
		draw_set_transform(pack_center, 0.0, Vector2(0.85, 1.0))
		draw_circle(Vector2.ZERO, pack_r + 1.2, Color(0.80, 0.93, 1.0, 0.85))
		draw_circle(Vector2.ZERO, pack_r, Color(0.74, 0.60, 0.38, 0.96))
		draw_circle(Vector2.ZERO, pack_r * 0.55, Color(0.52, 0.40, 0.24, 0.9))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tex: Texture2D = _resolve_tex(_sprite_key())
	if tex != null:
		var w: float = float(tex.get_width()) * sxq
		var h: float = float(tex.get_height()) * syq
		var dst := Rect2(-w * 0.5, (HEIGHT * 0.5) - h + bob, w, h)  # feet on the AABB bottom, centred
		# The miner art is authored facing left, so flip it when the body faces right (f > 0).
		if f > 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
			dst.position.x = -w * 0.5
		# The rim is what makes the body findable on any background. The sprite is small and low contrast
		# over the gear, hills and trees, and a single dark outline vanishes against the dark terrain and
		# machines it stands in.
		#
		# Cool and bright on purpose. The miner's art is warm leather and amber, the same family as the
		# dirt, the forge boxes and the amber UI, so a warm outline would deepen that collision. A cool
		# bright edge is the one thing in this warm-brown world nothing else wears.
		#
		# One ring, not two. The authored pixel art already carries its own one-pixel near-black outline,
		# so a second inner ring at 1.4px in eight directions printed up to two solid pixels of black
		# around every limb: the legs came out as black boxes with boots inside them.
		var rim := Color(0.80, 0.93, 1.0, 0.85)                 # cool bright halo, reserved for the player
		const RW: float = 1.5                                   # about 1.5 art pixels: read, but not seen
		for d: Vector2 in [Vector2(-RW, 0.0), Vector2(RW, 0.0), Vector2(0.0, -RW), Vector2(0.0, RW),
				Vector2(-RW, -RW), Vector2(RW, -RW), Vector2(-RW, RW), Vector2(RW, RW)]:
			draw_texture_rect(tex, Rect2(dst.position + d, dst.size), false, rim)
		draw_texture_rect(tex, dst, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# A 1px dark edge tracing the true AABB, drawn unscaled so it hugs the collision box.
	var outline := Color(0.03, 0.03, 0.05, 0.5)
	draw_rect(Rect2(-WIDTH * 0.5 - 1.0, -HEIGHT * 0.5 - 1.0, WIDTH + 2.0, HEIGHT + 2.0), outline, false, 1.0)

	# The code-drawn fallback was authored for a 20x44 body and is scaled by the current body's ratio, so
	# it shrinks with the AABB and keeps its proportions at any size.
	var body_scale: float = HEIGHT / 44.0
	draw_set_transform(Vector2(0.0, (HEIGHT * 0.5) * (1.0 - syq * body_scale) + bob), 0.0,
		Vector2(sxq * body_scale, syq * body_scale))
	var overalls := Color(0.24, 0.40, 0.62)
	var legs := Color(0.18, 0.20, 0.28)
	var skin := Color(0.84, 0.66, 0.50)
	var helmet := Color(0.95, 0.78, 0.22)

	draw_rect(Rect2(-5.0, 5.0, 4.0, 8.0), legs)
	draw_rect(Rect2(1.0, 5.0, 4.0, 8.0), legs)
	draw_rect(Rect2(-5.0, 11.0, 4.5, 2.0), Color(0.10, 0.11, 0.14))  # boot
	draw_rect(Rect2(0.5, 11.0, 4.5, 2.0), Color(0.10, 0.11, 0.14))

	draw_rect(Rect2(-6.0, -5.0, 12.0, 11.0), overalls)
	draw_rect(Rect2(-1.0, -5.0, 2.0, 11.0), overalls.lightened(0.12))

	var head := Vector2(f * 0.5, -9.0)
	draw_circle(head, 4.2, skin)
	draw_rect(Rect2(head.x - 4.6, head.y - 5.0, 9.2, 4.2), helmet)
	draw_rect(Rect2(head.x + (1.0 if f > 0.0 else -5.5), head.y - 1.4, 4.5, 1.6), helmet)
	draw_circle(head + Vector2(f * 4.2, -2.2), 1.5, Color(1.0, 0.97, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # clear the squash transform
