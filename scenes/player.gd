class_name Player
extends Node2D

## The embodied avatar — P2·S1a. PURELY a representation-layer entity: it reads the sim's world
## (is_solid / machine_at) for collision but NEVER enters the deterministic tick and never writes
## production state. Delete it and the factory numbers are identical. Movement is a small custom
## platformer controller with per-axis move-then-resolve AABB collision against the sim's solid cells,
## the machines, and the world walls/floor (safe from tunnelling at these speeds vs 32px cells; would
## need substep clamping only under severe frame drops) — plain GDScript so the feel is fully ours to
## tune (custom-now, not TileMap).
##
## FLOOR AUTHORITY (the 2026-06 movement-rebuild fix). The heightmap slope-follow (surface_row/ramp_dir)
## glides smooth 45° ramps but only knows a 1-D per-column surface — it can't see cave floors, dug pits,
## or machines, so it used to FIGHT the AABB and trap you in a 1-pit. Now it acts ONLY on a genuine
## rendered ramp (ramp_dir≠0); EVERYWHERE ELSE the AABB is the sole authority via two mirror moves in the
## resolve: auto STEP-UP a ≤1-tile rise (climb out of a pit, over a machine, up a cave ledge) and
## floor-SNAP a ≤1-tile descent (hug stairs/slopes without launching). Guarded by tools/check_step.gd.
##
## DESIGN-OPEN: every number here (speed, gravity, jump, size) is placeholder feel, measured vs
## intended by the harness (tools/measure_player.gd) and tuned by taste.

const CELL: int = 32
## Body AABB. SCALE spike (Noita-feel): shrunk 20×44 → 14×34 so the avatar reads as a small nimble figure
## in a big granular world once the camera is zoomed out (the thing we're judging by eye). Still JUST over
## one cell tall (34 > 32), so the "needs TWO tiles of clearance; a 1-tall gap is an honest squeeze" rule
## HOLDS — collision semantics + the step/agility harnesses are unchanged. WIDTH stays under a cell so it
## still fits down a 1-wide dug shaft. Proportions preserved (0.65 the old, ~0.44×1.06 tiles).
const WIDTH: float = 14.0
const HEIGHT: float = 34.0

## --- feel constants (placeholder; harness measures these vs intent) ---
const RUN_SPEED: float = 150.0       ## px/s horizontal top speed
const ACCEL: float = 1700.0          ## px/s^2 toward top speed (~0.09s) — quick, but not instant (less stiff)
const FRICTION: float = 2200.0       ## px/s^2 rubbed off when no input (snappy stop)
const GRAVITY: float = 900.0         ## px/s^2
## Jump apex ~= v^2/(2g) ~= 74px — comfortably clears a TWO-tile (64px) wall. It was -330 (apex 60px),
## which made a 2-block ledge a 4px-short bounce-off — the reported "stalling on a 2-high jump". A ≥3-tile
## wall stays honest (jump can't beat it; that's what ropes/digging are for).
const JUMP_VELOCITY: float = -365.0
## VARIABLE JUMP: while RISING with Space released, gravity is multiplied by this —
## a tap gives a short hop (~1/2 tile), a held press the full 2-tile arc. Feel-standard platformer
## control; never touches falls (velocity.y >= 0) or rope climbs. Harness drivers that don't model
## the key default jump_held=true, so every measured/scripted jump stays the FULL arc.
const JUMP_CUT_GRAVITY: float = 2.1
const MAX_FALL: float = 560.0        ## px/s terminal
const COYOTE_TIME: float = 0.08      ## s of grace to still jump after leaving an edge
const JUMP_BUFFER: float = 0.10      ## s a jump press is remembered before landing (forgiving)
## THE STRIDE (#S9) — the body builds momentum, the same idea the dig rhythm already runs on.
##
## RUN_SPEED is tuned for MINING: close quarters, one cell at a time, stop exactly where you meant to.
## It is the wrong speed for crossing a hundred and twenty-eight columns of world, and the world grew
## sixty percent taller without the legs getting any longer, so every traverse became a commute. Raising
## the constant would fix the commute and ruin the mining, which is why it stayed wrong.
##
## So it stops being a constant and becomes a state. Hold one direction on the ground and, after
## STRIDE_DELAY of unbroken travel, the miner settles into a run that tops out STRIDE_GAIN faster. Turn,
## stop, hit a wall, wade into water or land hard and it is gone. Everything SHORT — a step to line up a
## dig, a hop onto a ledge, the whole first second of any movement — happens at exactly the speed it
## always did, so the mining feel is untouched and the measured top speed still reads 150.
##
## Deliberately not free, and deliberately not a toggle: the delay is long enough that you cannot flick
## into it, a hard landing costs half of it, and it SURVIVES leaving the ground — so running a line of
## broken terrain without breaking the run is a thing a player gets better at. The grapple stays king by
## a wide margin (a pumped arc measures 2.8x RUN_SPEED against a full stride's 1.55x); this is the floor
## of traversal rising, not the ceiling.
const STRIDE_DELAY: float = 0.9      ## s of unbroken same-way ground travel before the run starts building
const STRIDE_RAMP: float = 1.2       ## ...and s from there to full
const STRIDE_GAIN: float = 0.55      ## extra top speed at full stride (150 -> 232 px/s)
const STRIDE_DECAY: float = 3.0      ## per-second bleed once the run breaks (a third of a second to nothing)
const STRIDE_LAND_COST: float = 0.5  ## fraction of the stride a hard landing takes
const STRIDE_LEAN: float = 0.07      ## radians the body tilts forward at full stride (~4 degrees)
var stride: float = 0.0              ## 0..1 into the run — read by the lean, the camera and the dust
var _stride_hold: float = 0.0        ## s of unbroken qualifying travel so far (counts toward STRIDE_DELAY)
const LIFT_RISE_SPEED: float = 120.0 ## px/s the updraft carries the body UP (the paid inverse of gravity)
const CLIMB_SPEED: float = 110.0     ## px/s the body travels a gripped rope (hold W/S; release = hang)
## Slope follow: a single-tile rise is walked as a 45° ramp (glide, not teleport); a taller rise is a
## wall you must jump. A single-tile drop is glided down too; a bigger gap is a real fall.
const MAX_STEP: float = CELL * 1.3
const MAX_DROP: float = CELL * 1.3
## Floor-snap (hugging a descending step / catching a fast drop) applies when the body is genuinely MOVING —
## walking sideways down stairs, or falling fast onto a ledge. What it must NOT do is fire when a ~stationary
## body loses the floor from under it (you MINED it): that's not a step-down, it's the start of a FALL, so
## gravity must take over and the body drops naturally instead of teleporting onto the next surface. The bug
## case is the ONLY one stationary in BOTH axes, so we snap only if moving in one: sideways OR falling fast.
const SNAP_WALK_MIN: float = 8.0     ## px/s of horizontal motion that counts as "walking" (stair-hug)
const SNAP_FALL_MIN: float = 250.0   ## px/s of downward speed that counts as a real "drop" (fast-fall catch)
const SNAP_STABILIZE: float = 4.0    ## a snap THIS small just keeps a resting body grounded (no flicker) — always allowed
## The instant a resting body loses its floor (you MINED it out, or ran off a ledge), a fall that begins from
## velocity.y = 0 creeps down under gravity for ~0.15s before it visibly moves — a mushy, "laggy" drop. Seed
## this brisk minimum downward speed on that grounded→airborne edge so the descent reads IMMEDIATELY (Terraria-
## snappy). It never touches jump arcs: a jump sets velocity.y NEGATIVE, so this max() leaves it untouched.
const FALL_START: float = 150.0      ## px/s minimum fall speed seeded when a grounded body starts falling
## WATER IMPEDANCE (L3 slice 3b — the located hazard the Pump later relieves). When the body's AABB
## overlaps a water cell (sim.water_at > 0) it WADES: horizontal top-speed + accel are damped (you slog),
## gravity is buoyantly slowed (a floaty near-neutral sink) with a gentle terminal-rise cap so you don't
## plummet OR bob up, and the jump is weaker (harder to leap out). It's friction, NOT drowning — there's no
## health system, so every mult keeps the body clearly MOVABLE (wade, exit, still jump). Gated ONLY on
## _in_water(); dry-land movement (check_agility / check_walk) is untouched — the gate never leaks.
const WATER_SPEED_MULT: float = 0.55   ## × RUN_SPEED horizontal top speed while wading
const WATER_ACCEL_MULT: float = 0.6    ## × ACCEL/FRICTION — you build/shed speed sluggishly in water
const WATER_GRAVITY_MULT: float = 0.45 ## × GRAVITY — buoyant slow-fall (a floaty descent, not a plummet)
const WATER_JUMP_MULT: float = 0.7     ## × JUMP_VELOCITY — a weaker leap (harder to hop clear of a pool)
const WATER_MAX_SINK: float = 220.0    ## px/s terminal sink in water (a slow settle, not free-fall)
const WATER_MIN_LEVEL: int = 1         ## water_at at/above this counts the cell as "wet" (any water impedes)
## Physics integrates in chunks no larger than this, so a big frame delta — the fast-forward game clock
## (Engine.time_scale > 1) or a real frame-drop — can't let the body skip past a tile between collision
## resolves (tunnel). At time_scale 1 a normal 1/60 frame is a single substep, so play feel is unchanged;
## only large deltas split. Matches the sim's own fixed-tick discipline (a step is a step).
const MAX_SUBSTEP: float = 1.0 / 60.0

var sim: FactorySim                  ## set by MainView; read-only use (collision queries)
## When true (normal play) the controller samples the keyboard. The harness sets it false and
## drives input_dir / request_jump() directly to measure motion deterministically.
var auto_input: bool = true
var input_dir: float = 0.0           ## -1 left, +1 right
var input_climb: float = 0.0         ## +1 up, -1 down — the rope-climb axis (W/S; harness-drivable)
var velocity: Vector2 = Vector2.ZERO
var on_floor: bool = false
var climbing: bool = false           ## gripping a rope this step (read by the sprite/juice; repr-only)
var facing: int = 1

## Cosmetic feedback MainView reads to spawn juice (dust / shake) — never touches the sim.
var landed_hard: bool = false        ## one-shot: set the frame the body lands from a real fall
var last_impact: float = 0.0         ## the landing's downward speed (px/s) — juice scales with it (#43)
var jump_held: bool = true           ## is the jump key still down (auto_input polls it; drivers may set)
## Animation state (Phase C — drives sprite-frame selection only; pure representation). `digging` is a
## brief held flag MainView pokes via note_dig() each time a cell is mined, so the dig pose shows across
## the gaps between mine ticks. Both the walk clock and this clock pick frames; absent art they do nothing.
var digging: bool = false

var _jump_request: bool = false
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _was_on_floor: bool = false
var _squash: float = 0.0             ## 0..1 landing squash, decays — pure visual
var _land_hold: float = 0.0          ## seconds the landing-impact frame is held (#42)
var _climb_phase: float = 0.0        ## climb-cycle clock, advanced by rope travel (#42)
var _walk_phase: float = 0.0         ## walk-cycle clock for the bob / walk anim-frame pick
var _anim_time: float = 0.0          ## free-running clock for non-walk frame cycling (the dig loop)
var _dig_hold: float = 0.0           ## seconds the dig pose stays latched after the last mined cell
## THE GRAPPLE (see scenes/grapple.gd). The body owns one because the line is a constraint on the body,
## not a thing in the world: it changes how gravity resolves, so it has to live inside the same substep.
var grapple: Grapple = Grapple.new()
## Air control is normally the same as ground control, which is generous and correct for a mining game.
## On the rope it is deliberately WEAKER: a swing you can steer freely is not a swing, it is flying, and
## the whole pleasure of a pendulum is that you commit to an arc and time your exit rather than driving
## the arc directly. Enough authority to pump and to aim the release; not enough to cancel the physics.
const SWING_ACCEL_MULT: float = 0.42
const SWING_DRAG: float = 0.22       ## per-second velocity bleed while taut — a rope has losses, and
                                     ## without one a pumped swing never settles and never feels heavy
## A terminal speed for the arc. Measured: with almost no drag, a driver pumping perfectly every frame
## reached 6.6x RUN_SPEED — about 31 cells a second — which is not a swing, it is a slingshot the player
## has no chance of reading. Capping the arc keeps the reward real (comfortably faster than running, and
## faster than you can fall) while leaving the body somewhere the camera and the collider can follow.
const SWING_MAX_SPEED: float = RUN_SPEED * 2.8
const SWING_LEAN: float = 0.40       ## radians (~23 deg) the body tilts into a full-speed arc
const SWING_LEAN_EASE: float = 7.0   ## per-second easing so the tilt settles rather than snapping
## How fast speed ABOVE the run cap bleeds off. Ground is a skid (you can feel the boots); air is nearly
## free, because nothing is touching you. At these values a full-speed release (420px/s) coasts about
## three seconds through open air and skids to a walk in a third of a second on landing — long enough
## that a good swing visibly buys you distance, short enough that it never feels like ice.
const GROUND_COAST_DRAG: float = 900.0
const AIR_COAST_DRAG: float = 95.0
var _step_grounded: bool = false     ## set per-step: may the horizontal resolve auto-step UP this frame?
var _stepped: bool = false           ## set BY the resolve when it auto-stepped up onto a ledge this frame


func _ready() -> void:
	Controls.register()    # so the body works standalone in motion harnesses, not only under MainView


func _physics_process(delta: float) -> void:
	if auto_input:
		input_dir = Input.get_axis(Controls.LEFT, Controls.RIGHT)  # remappable move axis (-1..+1)
		input_climb = Input.get_axis(Controls.DOWN, Controls.UP)   # W/S — grab + ride a rope
		# JUMP is W or Space (playtest: Space-only was confusing; W jumps like Terraria). On a rope W
		# CLIMBS instead (handled below), so holding either counts as "jump held" for the variable-height
		# arc off-rope, and is harmless on-rope (the arc-cut is gated to non-climbing).
		jump_held = Input.is_action_pressed(Controls.JUMP) or Input.is_action_pressed(Controls.UP)
	# Integrate in ≤MAX_SUBSTEP chunks so a large delta (fast-forward clock / frame-drop) resolves
	# collision every tile instead of teleporting through walls. One substep at normal 1× speed.
	landed_hard = false                       # reset ONCE per frame; a substep may only set it true
	grapple.begin_frame()                     # same contract for the line's plant/release one-shots
	var remaining: float = delta
	while remaining > 0.0:
		_step(minf(remaining, MAX_SUBSTEP))
		remaining -= MAX_SUBSTEP
	# THE LEAN (#S4). On a taut line the body tilts into its own arc. It is two lines of code and it does
	# more for how a swing reads than the whole constraint does: a sprite that stays bolt upright while it
	# travels sideways at 400px/s reads as a sticker being dragged, and the same sprite tilted 20 degrees
	# reads as a person on a rope. Node rotation only touches _draw — the AABB the collider uses is built
	# from position and the size constants, so leaning can never change where the body actually is.
	# ...and on the ground the same two lines sell the RUN: a body at full stride leans into it.
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
		request_jump()   # W jumps (Terraria) — UNLESS there's a rope here, where W climbs instead


## Is the body gripping / standing on a placed rope right now? Gates W between "jump" (no rope) and
## "climb up" (on a rope), so the same key does the Terraria-natural thing in both contexts.
func _on_rope() -> bool:
	return sim != null and sim.is_climbable(_cell_of(position))


## Where the line leaves the body — the winch on the miner's belt, a little above centre so the rope
## doesn't appear to grow out of their boots. Also the point the constraint measures from, so the swing
## pivots around the torso rather than the feet.
func hand() -> Vector2:
	return position + Vector2(0.0, -HEIGHT * 0.18)


func request_jump() -> void:
	_jump_request = true
	jump_held = true    # a requested jump implies the key is down NOW — polling (or a driver wanting a
	                    # tap) may release it on any later frame; guards drivers against a stale false


## MainView pokes this each time a cell is actually mined (Phase-C dig anim). Latches the dig pose for a
## beat (so it reads across the mine-cooldown gaps) and, when the body is standing still, turns it to face
## the dug cell — so hand-mining a vein to your side looks like you're swinging at it. Cosmetic only.
func note_dig(face: int) -> void:
	_dig_hold = 0.18
	if input_dir == 0.0 and face != 0:
		facing = face


## One physics step: horizontal (with slope follow) then vertical, each integrated and collided.
func _step(delta: float) -> void:
	# WATER IMPEDANCE (L3 3b): sampled ONCE per step. When wading, top-speed/accel/gravity/jump are damped
	# below; on dry land every mult is 1.0 so the resolve, step-up, snap, and agility are byte-for-byte
	# unchanged. The gate is the ONLY thing gating impedance — it can't leak onto dry ground.
	var wet: bool = _in_water()
	_update_stride(delta, wet)
	var speed_top: float = RUN_SPEED * (1.0 + STRIDE_GAIN * stride) * (WATER_SPEED_MULT if wet else 1.0)
	var accel: float = ACCEL * (WATER_ACCEL_MULT if wet else 1.0)
	var friction: float = FRICTION * (WATER_ACCEL_MULT if wet else 1.0)
	var gravity: float = GRAVITY * (WATER_GRAVITY_MULT if wet else 1.0)
	var max_fall: float = WATER_MAX_SINK if wet else MAX_FALL

	# Accelerate toward the input target / rub off speed with friction — not instant (which reads stiff).
	# On a taut line the body is on a pendulum: input still bites (that is how you pump an arc and how you
	# aim a release) but at reduced authority, and the top-speed clamp is lifted — a swing is allowed to
	# carry you faster than your legs ever could, which is the entire reward for using it.
	if grapple.taut:
		if input_dir != 0.0:
			velocity.x += input_dir * accel * SWING_ACCEL_MULT * delta
			facing = int(signf(input_dir))
	elif absf(velocity.x) > speed_top + 1.0:
		# MOMENTUM SURVIVES (#S4). Above your own top speed you are COASTING, not running, and the normal
		# controller would throw that away: move_toward(velocity, input * top) DECELERATES a body already
		# travelling faster than top speed, and friction does the same when you let go — so every swing,
		# every long drop, every hard release bled back to a walk inside a sixth of a second. Building
		# speed you cannot keep is worse than not building it at all; it teaches the player that the fast
		# tool does nothing. So: while over the cap, the only things that slow you down are a deliberate
		# input AGAINST your travel (full braking authority — you must always be able to stop) and a slow
		# coast drag, which is much weaker in the air than on the ground because ground is where friction
		# lives. Steering WITH your travel does nothing, which is correct: you cannot run faster than you
		# can run. Below the cap the controller is byte-for-byte what it was.
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
	# Variable jump height (#43): rising with the jump key released → extra gravity clips the arc.
	# In water the arc-cut uses the same buoyant gravity so a released hop settles gently, not sharply.
	if velocity.y < 0.0 and not jump_held and not climbing:
		velocity.y = minf(velocity.y + gravity * (JUMP_CUT_GRAVITY - 1.0) * delta, max_fall)
	# ROPE GRIP (representation-only, like the updraft): overlapping a placed rope, a climb press (W/S)
	# grabs it; the grip holds until the body leaves the rope or jumps off. Gripping counts as GROUNDED
	# below, so Space always jumps you off a rope and sideways-at-the-lip gets the auto step-up out.
	var on_rope: bool = sim.is_climbable(_cell_of(position))
	if not on_rope:
		climbing = false
	elif input_climb != 0.0:
		climbing = true
	var grounded: bool = on_floor or _coyote > 0.0 or climbing
	if _jump_request:
		_jump_buffer = JUMP_BUFFER          # remember a press so it fires the instant we land (forgiving)
	_jump_request = false
	# LEAP OFF THE SWING: jumping while the line is TAUT cuts it and adds the jump on top of whatever the
	# arc had built up. This is the payoff move — time the release at the bottom of a swing and the leap
	# stacks onto the swing's speed — and it needs no extra key, because "let go and jump" is one motion.
	# A slack line is left alone, so hooking a ceiling and then hopping around under it keeps you hooked.
	if _jump_buffer > 0.0 and grapple.taut:
		grapple.cut()
		velocity.y = minf(velocity.y, 0.0) + JUMP_VELOCITY * (WATER_JUMP_MULT if wet else 1.0)
		velocity *= Grapple.RELEASE_KICK
		_jump_buffer = 0.0
	elif _jump_buffer > 0.0 and grounded:
		velocity.y = JUMP_VELOCITY * (WATER_JUMP_MULT if wet else 1.0)   # weaker leap out of a pool
		on_floor = false
		climbing = false                    # a jump lets GO of the rope (Space = off, W = up: distinct verbs)
		_coyote = 0.0
		grounded = false
		_jump_buffer = 0.0
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	var impact_v: float = velocity.y         # remembered for the landing squash

	# Updraft: standing in a lift's open shaft, the body is carried UP (the rideable half of the lift).
	# Ensures at least rise speed upward — a jump can still beat it — and skips slope-follow (airborne).
	if sim.updraft_at(_cell_of(position)):
		velocity.y = minf(velocity.y, -LIFT_RISE_SPEED)
		grounded = false

	# THE CLIMB: while gripping, gravity is REPLACED by direct travel — hold W/S to ride up/down the
	# rope, release to HANG in place. Runs after the updraft so a gripped rope wins over a draft (your
	# hands are on it). The vertical resolve below still applies: climbing up into a ceiling stops you,
	# climbing down onto a floor lands you.
	if climbing:
		velocity.y = -input_climb * CLIMB_SPEED
		# TOP-OF-ROPE HOLD: with no rope above this cell, rising further would push the centre off the
		# rope → un-grip → fall → re-grip — a jittering stall at the anchor (the reported bug). Clamp the
		# rise so the grip HOLDS just inside the top segment; leave by jumping (Space) or side-stepping.
		if input_climb > 0.0 and not sim.is_climbable(_cell_of(position) + Vector2i(0, -1)):
			var top_hold: float = float(_cell_of(position).y * CELL) + 6.0
			velocity.y = clampf((top_hold - position.y) / delta, velocity.y, 0.0)

	# THE LINE. Flown, reeled and constrained inside the substep so a fast swing collides every tile the
	# same way a fast fall does. UP/DOWN reel while anchored — the same axis that rides a rope, because it
	# is the same gesture.
	#
	# THE WINCH HAULS FROM STANDING. This was gated to being off the floor, and the gate was defending
	# against a conflict that does not exist: jump is Space, the reel is W/S, and on the ground with a hook
	# planted overhead W did nothing at all. What it actually cost was the tool's headline claim. The whole
	# reason the grapple exists is the trip back up, and a winch that only engages once you are ALREADY
	# airborne is not a way up, it is a thing you use after a jump — tools/check_plunge caught it the
	# expensive way, watching a body stand on a shelf holding UP into a planted line for a hundred and fifty
	# frames, three separate times, going nowhere. So it hauls from standing; the only thing still refused
	# is winching toward an anchor at or below your own feet, which would wind you into the floor.
	grapple.advance(sim, hand(), delta)
	if grapple.state == Grapple.State.ANCHORED \
			and (not on_floor or grapple.anchor.y < position.y - CELL * 0.5):
		grapple.reel(input_climb, delta)

	# Horizontal move. Two floor authorities, cleanly separated so they can't fight (the old conflict
	# that trapped you in a dug 1-pit): on a GENUINE rendered ramp (ramp_dir≠0) the heightmap glides the
	# feet up/down the 45° hypotenuse for a smooth slope; EVERYWHERE ELSE (flat, pits, valleys, caves,
	# post-dig terrain, machines) the AABB is the sole authority — auto STEP-UP for ≤1-tile rises in the
	# resolve below, and floor-SNAP for ≤1-tile descents. So slopes stay smooth, and you climb out of a
	# pit / over a machine instead of wedging against it.
	position.x += velocity.x * delta
	var glided: bool = false
	if grounded and not climbing and velocity.y >= 0.0 and sim.ramp_dir(_cell_of(position).x) != 0:
		glided = _follow_slope(delta)   # never slope-yank a body hanging on a rope above a ramp
	_step_grounded = grounded          # let the horizontal resolve auto-step ≤1-tile walls when grounded
	_stepped = false
	_resolve_axis(true)

	# On a ramp the feet ride a virtual hypotenuse ABOVE the real solid square — _follow_slope grounds
	# the body itself. An auto step-up likewise just placed the feet ON a ledge (perched on its edge, its
	# footprint may still hang over the lower cell) — so SKIP this frame's gravity drop too, or the same
	# frame's fall would yank it straight back down; next frame it walks forward fully onto the ledge.
	# Otherwise integrate gravity, resolve, then snap down a descending step so the body HUGS the terrain.
	if glided or _stepped:
		velocity.y = 0.0
		on_floor = true
	else:
		position.y += velocity.y * delta
		on_floor = false
		_resolve_axis(false)
		# Snap-hug the terrain below. A tiny snap always fires (keeps a resting body grounded, no flicker); a
		# full STEP-DOWN only fires when the body is genuinely moving (walking down stairs, or falling fast).
		# So when a ~stationary body loses its floor (you MINED it), there's no near floor to stabilize on and
		# no motion to justify the step — it FALLS naturally instead of teleporting onto the next surface.
		if grounded and not on_floor and velocity.y >= 0.0:
			var allow_step: bool = absf(velocity.x) > SNAP_WALK_MIN or velocity.y > SNAP_FALL_MIN
			_snap_to_floor(allow_step)

	# THE CONSTRAINT, applied after the body has integrated and collided on both axes: pull the position
	# back onto the circle, then cancel the OUTWARD half of the velocity and nothing else. Because it runs
	# last it can never fight the collider — a swing into a wall stops at the wall, and the line simply
	# goes slack until the body swings back inside its radius. The re-resolve catches the rare case where
	# the pull-back lands the box a pixel inside geometry.
	if grapple.state == Grapple.State.ANCHORED:
		var swung: Vector2 = grapple.constrain_position(position)
		if grapple.taut:
			position = swung
			velocity = grapple.resolve_velocity(position, velocity)
			velocity -= velocity * SWING_DRAG * delta      # a rope has losses; a frictionless one feels fake
			velocity = velocity.limit_length(SWING_MAX_SPEED)
			_resolve_axis(true)
			_resolve_axis(false)

	# FALL KICK: the frame a resting body loses its floor (mined out from under it, or ran off a ledge) it
	# would otherwise creep down from zero velocity — the reported "laggy" drop. Seed a brisk minimum fall so
	# the descent starts on the very next frame. Gated to the grounded→airborne edge (was_on_floor, now not)
	# and to genuine falls (velocity.y >= 0 — a jump is negative here, so its arc is never altered).
	if _was_on_floor and not on_floor and velocity.y >= 0.0:
		velocity.y = maxf(velocity.y, FALL_START)

	# Landing squash + a one-shot "landed hard" signal for juice, on touching ground after a real fall.
	if on_floor and not _was_on_floor and impact_v > 240.0:
		_squash = 1.0
		landed_hard = true
		last_impact = impact_v           # the consumer scales dust/shake/thump by how hard (#43)
		_land_hold = 0.14                # hold the landing-impact frame a beat (#42)
		stride *= 1.0 - STRIDE_LAND_COST # a heavy landing costs the run — weight has to be felt somewhere
	_land_hold = maxf(0.0, _land_hold - delta)
	if climbing:
		_climb_phase += absf(velocity.y) * delta * 0.055   # hand-over-hand cadence tracks climb speed
	_was_on_floor = on_floor
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	_walk_phase += (absf(velocity.x) * delta * 0.06) if on_floor else 0.0
	_anim_time += delta
	_dig_hold = maxf(0.0, _dig_hold - delta)
	digging = _dig_hold > 0.0

	_coyote = COYOTE_TIME if on_floor else _coyote - delta


## Track the walkable surface as a 45° height field so the body GLIDES along ramps instead of
## popping. Samples the surface under the body centre and its leading edge, snaps the feet onto the
## higher of the two — but only within one tile of rise (taller = a wall, left for the resolve to
## block) or drop (bigger = a real fall, left for gravity). Climbs are rejected if the new position
## would push the head into a ceiling (a tight gap is a wall, not a step).
func _follow_slope(delta: float) -> bool:
	var rect: Rect2 = _aabb()
	# The box rests on the HIGHEST ground under its footprint — sample both bottom corners + centre.
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
		# Cap the per-frame UPWARD glide to what horizontal travel warrants (a 45° ramp rises ≈ as fast as
		# you walk) plus a small crest allowance. Without this, MOUNTING a ramp (where the sampled surface
		# jumps a tile as the leading foot crosses into the higher column) is a one-frame pop — worse the
		# taller the body. Clamping keeps the climb a smooth glide at ANY body size (guarded by check_stepup).
		var max_rise: float = absf(velocity.x) * delta + 3.0
		ny = maxf(ny, position.y - max_rise)   # limit this frame's rise (position.y is the current centre)
	position.y = ny
	return true


## World-Y of the walkable surface at a horizontal position — read straight from the sim's shared
## silhouette authority (sim.surface_row / sim.ramp_dir), the SAME source the renderer draws from, so
## the hypotenuse we glide is exactly the diagonal on screen. A single-tile step is a 45° ramp across
## its own column; flat otherwise. Terrain-only by construction: machines aren't in the silhouette, so
## a placed machine is a box the square-resolve bumps/climbs — never a phantom invisible ramp.
func _surface_y(world_x: float) -> float:
	var c: int = floori(world_x / float(CELL))
	var frac: float = world_x / float(CELL) - float(c)  # 0..1 across column c
	var base: float = float(sim.surface_row(c) * CELL)
	match sim.ramp_dir(c):
		1:
			return base - frac * float(CELL)          # one tile higher to the RIGHT → ramp up rightward
		-1:
			return base - (1.0 - frac) * float(CELL)  # one tile higher to the LEFT → ramp up leftward
		_:
			return base                               # flat top (or peak/valley): no ramp


## Push the body out of any blocked cell it now overlaps. The HORIZONTAL pass resolves by MINIMUM
## penetration, pushing out by the overlap DEPTH — not snapping to the cell face. Two consequences that
## kill the ~47px backward "teleport": (1) if the overlap is shallower in Y than X, it's a ledge/step
## you're descending onto, NOT a wall — skip the sideways push and let the vertical pass land you; (2) a
## real wall is pushed out by its (small) penetration, so a fast bump nudges a few px, never a whole tile.
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
				if ov_x > ov_y:
					continue          # shallower in Y → a ledge to step/land onto, not a wall to block
				# A WALL in our path. Before blocking, try to STEP UP onto it — the unified auto-step the
				# heightmap slope-follow can't give: identical for a dug pit's edge, a cave ledge, and a
				# placed machine (none are in surface_row/ramp_dir). Only a ≤1-tile rise WITH head
				# clearance steps; anything taller stays a wall you must jump.
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
	# WOOD + LEAVES are Terraria-style walk-THROUGH: tree trunks and foliage never wall the body (you pass
	# them and chop them), and the bazaar's wood frame is a shop you ENTER — one rule covers both. Its earth
	# interior floor is NOT wood, so it still blocks (you stand inside). Everything else solid blocks; a body
	# taller than a tile would otherwise be walled by any surface trunk it can't duck under. Machines block.
	if sim.is_solid(cell):
		var m: StringName = sim.material_at(cell)
		if m != &"wood" and m != &"leaves":
			return true
	return sim.machine_at(cell) != null


## Hug descending terrain WITHOUT the heightmap: after a grounded move that left the body hanging just
## above a lower step (a 1-tile drop, a descending stair, the lip of a pit), snap the feet down onto the
## nearest solid within MAX_DROP so walking down reads smooth. A real drop (nothing within range) finds
## no floor and lets gravity take over. Mirror of the auto step-up; together they replace the heightmap
## glide on all non-ramp terrain. `allow_step`: whether a full-tile step-DOWN is permitted (only while
## moving) — a tiny stabilizing snap always is, so a stationary body that lost its floor (mined out) neither
## stabilizes nor steps → it falls naturally (the mine-under-yourself fix).
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


## True if any blocked cell overlaps `box` — the head-clearance check that gates an auto step-up (don't
## step into a space the body won't fit, so a 2-tile wall or a low ceiling stays an honest wall).
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


## Advance the stride (#S9). Three states and nothing else:
##
##   BUILDING  — grounded, dry, off the line, pushing one way and actually travelling that way at close
##               to top speed. Time banks toward STRIDE_DELAY first, then the stride itself ramps.
##   HOLDING   — airborne with a run already going. A ledge in the middle of a sprint must not cost the
##               sprint, or the player learns to avoid terrain, which is the opposite of the point.
##   BREAKING  — everything else. Bleeds fast enough that a mistake reads as a mistake.
##
## Note what needs no special case: a wall zeroes velocity.x, which fails the "actually travelling" test,
## so running into rock breaks the run without the controller ever being told what a wall is.
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


## Is the body wading — does any cell its AABB overlaps hold water (≥ WATER_MIN_LEVEL)? Reads the sim's
## water grid (never writes it); pure representation, like the collision queries. Returns false with no sim
## (standalone harness boots) or a dry world. Feet-and-body coverage: the same cell span the resolve walks,
## so stepping the feet into a pool impedes the moment you touch it, and a body half-submerged still wades.
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


## The logical sprite-frame key for the body's current motion state (Phase C). Priority: digging > airborne
## > walking > idle. Walk cycles 4 frames off the walk clock; dig alternates 2 off the free clock. The
## caller falls back to the idle "miner" frame for any state whose art hasn't been drawn yet, so dropping
## in only a subset of frames still works (and with NO frames present, every key misses → primitive path).
## Frame fallback chains: a state whose art hasn't landed borrows the nearest drawn
## pose, ending at the idle frame — so the artist can land climb_0 alone, or nothing, and every state
## still shows SOMETHING sensible.
const SPRITE_FALLBACKS: Dictionary = {
	"miner_climb_0": "miner_climb", "miner_climb_1": "miner_climb",
	"miner_hang": "miner_climb", "miner_climb": "miner", "miner_land": "miner",
}


func _sprite_key() -> String:
	if digging:
		return "miner_dig_0" if int(_anim_time * 8.0) % 2 == 0 else "miner_dig_1"
	if climbing:
		# Moving on the rope cycles the climb; a still grip HANGS (a distinct held pose).
		if absf(velocity.y) > 6.0:
			return "miner_climb_%d" % (int(_climb_phase) % 2)
		return "miner_hang"
	if not on_floor:
		return "miner_jump"
	if _land_hold > 0.0:
		return "miner_land"        # the landing-impact beat, right after touchdown
	if absf(velocity.x) > 10.0:
		return "miner_walk_%d" % (int(_walk_phase) % 4)
	return "miner"


## The best drawn texture for a state key: walk its fallback chain, ending at the idle frame (null
## only when NO miner art exists at all — then the code-drawn figure takes over).
func _resolve_tex(key: String) -> Texture2D:
	var k: String = key
	while true:
		var t: Texture2D = Art.tex(k)
		if t != null:
			return t
		if not SPRITE_FALLBACKS.has(k):
			break
		k = SPRITE_FALLBACKS[k]
	return Art.tex("miner")


## The MINER. Draws the motion-appropriate `assets/sprites/miner*.png` frame if present (feet-anchored,
## flipped by facing, landing squash applied), falling back to the idle frame and then the code-drawn
## figure. Squash (flatten + widen on landing, + a tiny walk bob) is the first scrap of game-feel juice
## and applies to either path.
func _draw() -> void:
	var f: float = float(facing)
	# Contact shadow — a soft dark ellipse at the feet so the body sits ON the ground, not floating.
	# Shrinks while airborne (a small far shadow) so a jump reads as leaving the floor.
	var grounded_amt: float = 1.0 if on_floor else 0.45
	draw_set_transform(Vector2(0.0, HEIGHT * 0.5 - 1.0), 0.0, Vector2(1.0, 0.30))
	draw_circle(Vector2.ZERO, WIDTH * 0.72 * grounded_amt, Color(0.0, 0.0, 0.0, 0.34 * grounded_amt))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sxq: float = 1.0 + 0.18 * _squash             # landing squash widens X
	var syq: float = 1.0 - 0.22 * _squash             # ...and flattens Y
	var bob: float = -absf(sin(_walk_phase)) * 1.2 if (on_floor and absf(velocity.x) > 10.0) else 0.0
	var tex: Texture2D = _resolve_tex(_sprite_key())
	if tex != null:
		var w: float = float(tex.get_width()) * sxq
		var h: float = float(tex.get_height()) * syq
		var dst := Rect2(-w * 0.5, (HEIGHT * 0.5) - h + bob, w, h)  # feet on the AABB bottom, centred
		# The drop-in miner art is authored facing LEFT, so flip it when the body faces RIGHT (f > 0).
		if f > 0.0:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
			dst.position.x = -w * 0.5
		# STICKER OUTLINE — readable on ANY background (blind testers kept finding the body only via the
		# guide arrow, not the sprite itself: tiny + low-contrast over the gear/hills/trees, and a single
		# DARK outline vanished against the dark terrain/machines/underground he actually stands in). TWO
		# rings: a warm LIGHT halo on the outside separates him from the dark/mid world; a near-black inner
		# edge separates him from the bright sky. Light drawn first (wider), dark over it (tighter), so the
		# light survives only as a thin outer fringe — a crisp rim, not a heavy glow.
		# The rim is COOL + bright on purpose: the miner's own art is warm (leather/amber) — the SAME warm
		# family as the dirt, the FORGE boxes and the amber UI, so a warm outline just deepened the collision
		# (blind testers read the body as "one of three machine-ish objects"). A cool bright edge is the one
		# thing in the warm-brown world nothing else wears, so the body reads instantly as THE player.
		var rim := Color(0.80, 0.93, 1.0, 0.85)                 # cool bright halo — the reserved "that's me" edge
		var ol := Color(0.03, 0.03, 0.05, 0.72)                 # near-black inner edge — pops on the bright sky
		const RW: float = 2.6
		const OW: float = 1.4
		for d: Vector2 in [Vector2(-RW, 0.0), Vector2(RW, 0.0), Vector2(0.0, -RW), Vector2(0.0, RW),
				Vector2(-RW, -RW), Vector2(RW, -RW), Vector2(-RW, RW), Vector2(RW, RW)]:
			draw_texture_rect(tex, Rect2(dst.position + d, dst.size), false, rim)
		for d: Vector2 in [Vector2(-OW, 0.0), Vector2(OW, 0.0), Vector2(0.0, -OW), Vector2(0.0, OW),
				Vector2(-OW, -OW), Vector2(OW, -OW), Vector2(-OW, OW), Vector2(OW, OW)]:
			draw_texture_rect(tex, Rect2(dst.position + d, dst.size), false, ol)
		draw_texture_rect(tex, dst, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# A subtle 1px dark edge tracing the TRUE AABB (drawn un-scaled so it hugs the collision box) — keeps the
	# body crisp without a hard silhouette plate fighting the soft lighting.
	var outline := Color(0.03, 0.03, 0.05, 0.5)
	draw_rect(Rect2(-WIDTH * 0.5 - 1.0, -HEIGHT * 0.5 - 1.0, WIDTH + 2.0, HEIGHT + 2.0), outline, false, 1.0)

	# The code-drawn miner (art-less fallback) was authored for the old 20×44 body; SCALE it by the current
	# body's ratio so it shrinks WITH the AABB and its proportions are preserved at any size (feet on the
	# AABB bottom via the y-offset below).
	var body_scale: float = HEIGHT / 44.0
	draw_set_transform(Vector2(0.0, (HEIGHT * 0.5) * (1.0 - syq * body_scale) + bob), 0.0,
		Vector2(sxq * body_scale, syq * body_scale))
	var overalls := Color(0.24, 0.40, 0.62)
	var legs := Color(0.18, 0.20, 0.28)
	var skin := Color(0.84, 0.66, 0.50)
	var helmet := Color(0.95, 0.78, 0.22)

	# Legs + boots.
	draw_rect(Rect2(-5.0, 5.0, 4.0, 8.0), legs)
	draw_rect(Rect2(1.0, 5.0, 4.0, 8.0), legs)
	draw_rect(Rect2(-5.0, 11.0, 4.5, 2.0), Color(0.10, 0.11, 0.14))  # boot
	draw_rect(Rect2(0.5, 11.0, 4.5, 2.0), Color(0.10, 0.11, 0.14))

	# Torso (overalls) with a strap highlight.
	draw_rect(Rect2(-6.0, -5.0, 12.0, 11.0), overalls)
	draw_rect(Rect2(-1.0, -5.0, 2.0, 11.0), overalls.lightened(0.12))

	# Head.
	var head := Vector2(f * 0.5, -9.0)
	draw_circle(head, 4.2, skin)
	# Hardhat: a cap over the top of the head + a brim toward the facing side.
	draw_rect(Rect2(head.x - 4.6, head.y - 5.0, 9.2, 4.2), helmet)
	draw_rect(Rect2(head.x + (1.0 if f > 0.0 else -5.5), head.y - 1.4, 4.5, 1.6), helmet)
	# Head-lamp glow on the facing side.
	draw_circle(head + Vector2(f * 4.2, -2.2), 1.5, Color(1.0, 0.97, 0.7))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # clear the squash transform
