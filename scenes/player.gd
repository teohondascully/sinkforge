class_name Player
extends Node2D

## The embodied avatar — P2·S1a. PURELY a representation-layer entity: it reads the sim's world
## (is_solid / machine_at) for collision but NEVER enters the deterministic tick and never writes
## production state. Delete it and the factory numbers are identical. Movement is a small custom
## platformer controller with per-axis move-then-resolve AABB collision against the sim's solid cells,
## the machines, and the world walls/floor (safe from tunnelling at these speeds vs 32px cells; would
## need substep clamping only under severe frame drops) — plain GDScript so the feel is fully ours to
## tune (custom-now, not TileMap; see docs/DECISIONS.md / prompts/prototype-2.md).
##
## FLOOR AUTHORITY (the 2026-06 movement-rebuild fix). The heightmap slope-follow (surface_row/ramp_dir)
## glides smooth 45° ramps but only knows a 1-D per-column surface — it can't see cave floors, dug pits,
## or machines, so it used to FIGHT the AABB and trap you in a 1-pit. Now it acts ONLY on a genuine
## rendered ramp (ramp_dir≠0); EVERYWHERE ELSE the AABB is the sole authority via two mirror moves in the
## resolve: auto STEP-UP a ≤1-tile rise (climb out of a pit, over a machine, up a cave ledge) and
## floor-SNAP a ≤1-tile descent (hug stairs/slopes without launching). Guarded by tools/check_step.gd.
##
## DESIGN-OPEN: every number here (speed, gravity, jump, size) is placeholder feel, measured vs
## intended by the harness (tools/measure_player.gd) and tuned by taste — see docs/HARNESS.md.

const CELL: int = 32
## Body AABB. A real PERSON, not a sub-tile slab: ~1.4 tiles tall so it MATCHES the 32×48 miner sprite
## (feet-anchored; the hardhat crown overhangs the top a touch) and reads as embodied — and, being taller
## than a cell, it needs TWO tiles of clearance to stand, so a 1-tall gap is an honest squeeze you must dig
## out (Terraria-ish), not a crawlspace. WIDTH stays under a cell so it still fits down a 1-wide dug shaft.
const WIDTH: float = 20.0
const HEIGHT: float = 44.0

## --- feel constants (placeholder; harness measures these vs intent) ---
const RUN_SPEED: float = 150.0       ## px/s horizontal top speed
const ACCEL: float = 1700.0          ## px/s^2 toward top speed (~0.09s) — quick, but not instant (less stiff)
const FRICTION: float = 2200.0       ## px/s^2 rubbed off when no input (snappy stop)
const GRAVITY: float = 900.0         ## px/s^2
## Jump apex ~= v^2/(2g) ~= 74px — comfortably clears a TWO-tile (64px) wall. It was -330 (apex 60px),
## which made a 2-block ledge a 4px-short bounce-off — the reported "stalling on a 2-high jump". A ≥3-tile
## wall stays honest (jump can't beat it; that's what ropes/digging are for).
const JUMP_VELOCITY: float = -365.0
## VARIABLE JUMP (FABLE_50 #43): while RISING with Space released, gravity is multiplied by this —
## a tap gives a short hop (~1/2 tile), a held press the full 2-tile arc. Feel-standard platformer
## control; never touches falls (velocity.y >= 0) or rope climbs. Harness drivers that don't model
## the key default jump_held=true, so every measured/scripted jump stays the FULL arc.
const JUMP_CUT_GRAVITY: float = 2.1
const MAX_FALL: float = 560.0        ## px/s terminal
const COYOTE_TIME: float = 0.08      ## s of grace to still jump after leaving an edge
const JUMP_BUFFER: float = 0.10      ## s a jump press is remembered before landing (forgiving)
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
	var remaining: float = delta
	while remaining > 0.0:
		_step(minf(remaining, MAX_SUBSTEP))
		remaining -= MAX_SUBSTEP
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
	# Accelerate toward the input target / rub off speed with friction — not instant (which reads stiff).
	if input_dir != 0.0:
		velocity.x = move_toward(velocity.x, input_dir * RUN_SPEED, ACCEL * delta)
		facing = int(signf(input_dir))
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
	# Variable jump height (#43): rising with the jump key released → extra gravity clips the arc.
	if velocity.y < 0.0 and not jump_held and not climbing:
		velocity.y = minf(velocity.y + GRAVITY * (JUMP_CUT_GRAVITY - 1.0) * delta, MAX_FALL)
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
	if _jump_buffer > 0.0 and grounded:
		velocity.y = JUMP_VELOCITY
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


## The logical sprite-frame key for the body's current motion state (Phase C). Priority: digging > airborne
## > walking > idle. Walk cycles 4 frames off the walk clock; dig alternates 2 off the free clock. The
## caller falls back to the idle "miner" frame for any state whose art hasn't been drawn yet, so dropping
## in only a subset of frames still works (and with NO frames present, every key misses → primitive path).
## Frame fallback chains (FABLE_50 #42): a state whose art hasn't landed borrows the nearest drawn
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
		draw_texture_rect(tex, dst, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	draw_set_transform(Vector2(0.0, (HEIGHT * 0.5) * (1.0 - syq) + bob), 0.0, Vector2(sxq, syq))
	var overalls := Color(0.24, 0.40, 0.62)
	var legs := Color(0.18, 0.20, 0.28)
	var skin := Color(0.84, 0.66, 0.50)
	var helmet := Color(0.95, 0.78, 0.22)

	# (No hard silhouette plate: the head-lamp pool now provides the contrast — a backing rect read as
	# a hard box fighting the soft lighting. A subtle 1px dark outline keeps edges crisp without a plate.)
	var outline := Color(0.03, 0.03, 0.05, 0.5)
	draw_rect(Rect2(-WIDTH * 0.5 - 1.0, -HEIGHT * 0.5 - 1.0, WIDTH + 2.0, HEIGHT + 2.0), outline, false, 1.0)

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
