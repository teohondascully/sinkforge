class_name Grapple
extends RefCounted

## A piton on a winch line, and the traversal verb of a game about going down: the trip back up is where
## a game like this turns into tedium, and ropes and lifts answer that logistically without being worth
## using. tools/check_traverse measures the rope crossing a gallery half again as fast as a full stride,
## so it is the movement system rather than an accessory to one.
##
## It behaves as a ninja rope rather than as Terraria's hook, which winches the body along a straight
## line and discards its velocity at both ends. The constraint here removes only the outward component of
## velocity, so everything tangential is conserved through the arc: release at the bottom of a swing and
## the speed is kept, release at the top and the height is kept, reel in mid-arc and the arc speeds up,
## because pulling toward the centre of a rotation is how a skater spins up.
##
## The physics is one position-based distance constraint, solved once per substep, applied after the
## body's own integrate-and-collide:
##
##     d = pos - anchor;  if |d| > length:
##         pos = anchor + d.normalized() * length          # pull back onto the circle
##         v  -= n * max(0, v·n)                            # cancel only the outward radial component
##
## That is the whole simulation. It is unconditionally stable, since a projection cannot add energy on its
## own, and it produces a real pendulum because the tangential component is never touched. Reeling in adds
## energy on purpose: shortening the radius while conserving tangential speed raises angular velocity.
## See pump().
##
## The line wraps: it is a polyline (the anchor, a pivot at every corner it has caught on, then the body)
## and the constraint acts from the last of those, so it goes around rock rather than through it. Wrapping
## spends line, so the free radius shortens as the body swings into a corner and pays back out coming off
## it, and conserved tangential speed over a shorter radius is a faster rotation: tools/check_wrap
## measures 4.8 rad/s through a wrapped corner against 1.2 without one. The cost is that the anchor is no
## longer a chord readable at a glance, which the slack-drawn rope and the aiming ghost offset.

const CELL: int = FactorySim.CELL

## The probe step. The flying hook, the aiming ghost and the line-catch scan all walk a shot in fixed
## steps of this size from the origin, which is what lets them agree cell for cell. Advancing by
## `FLY_SPEED * delta` and clipping each frame's leftover makes the sample points depend on the frame rate
## and on when in the flight they are read, so a shot grazing the corner of a block resolves one way in
## the ghost and another in the hook (three times in forty-eight, measured).
## Quarter-cell: fine enough that a hook cannot slip past a block corner, coarse enough to stay cheap.
const PROBE: float = float(CELL) * 0.25

enum State {
	IDLE,       ## stowed
	FLYING,     ## the hook is in the air, no constraint yet
	ANCHORED,   ## planted in rock; the line is live
}

const FLY_SPEED: float = 1800.0      ## px/s the hook travels. At 1250, a shot at a ceiling 14 cells up
                                     ## took 22 frames to bite; 1800 lands the same shot in 15. A third of
                                     ## a second of dead air between the press and the swing is enough to
                                     ## make the tool feel like a request rather than an action.
const MAX_RANGE: float = CELL * 15.0 ## px of line on the winch; beyond this the hook falls short
## The winch speed. The body runs at 150 px/s and strides at 232, so a winch anywhere near those makes
## hauling up a line slower than walking and nobody reaches for it. 420 is thirteen cells a second, which
## is decisively faster than the legs and still slow enough that a long haul is a commitment rather than a
## teleport. For scale, Terraria's hook pulls about fifteen cells a second.
##
## The swing is unaffected by the value: reeling changes the radius, and the arc's speed comes from
## angular momentum in pump(), so a faster winch spins an arc up harder without altering the pendulum.
const REEL_SPEED: float = 420.0      ## px/s the line shortens while up is held; the ascent verb
const PAY_SPEED: float = 520.0       ## px/s it pays out under down (faster than reeling: rope falls easily)
const MIN_LENGTH: float = CELL * 0.8 ## you cannot winch yourself into the anchor itself
const SLACK_TAKEUP: float = 0.90     ## on plant, the line is set to this × the current distance, so the
                                     ## hook bites and takes up a little slack instead of hanging loose
const RELEASE_KICK: float = 1.05     ## a little extra speed on a deliberate release, which rewards timing


var state: State = State.IDLE
var tip: Vector2 = Vector2.ZERO      ## where the hook head is right now (world px)
var anchor: Vector2 = Vector2.ZERO   ## where it bit (world px), valid while ANCHORED
var anchor_cell: Vector2i = Vector2i.ZERO
var length: float = 0.0              ## live line length (world px)
var taut: bool = false               ## whether the constraint did work last step (drives the render)
## Px of line taken in by the last reel(), zero when paying out or idle. The body converts this into
## approach speed. The constraint on its own only clamps a position, so without this the reel drags the
## body along the line and it arrives at a standstill with nothing to release into. A winch does work on
## the thing it hauls, and that work has to land in the velocity.
var hauled: float = 0.0
var just_planted: bool = false       ## one-shot for the impact puff / sound
var just_cut: bool = false           ## one-shot for the release whoosh

var _flown: float = 0.0              ## px the hook has travelled this shot (always a multiple of PROBE)
var _carry: float = 0.0              ## sub-PROBE remainder of this frame's flight, kept for the next one
var _dir: Vector2 = Vector2.RIGHT
## A new hook is in the air while the old line is still holding; see fire(). The constraint stays live
## the whole time, so a chained shot never costs the arc already being ridden.
var _chain: bool = false


## Clear the one-shot event flags. Called once per frame by the body, never per substep: a plant that
## happened in substep 1 has to survive until the view reads it in _process, and at fast-forward speeds a
## frame is several substeps long. Clearing these inside advance() eats every release, because a jump cuts
## the line earlier in the same step than the flight advances.
func begin_frame() -> void:
	just_planted = false
	just_cut = false


## Launch toward a world point. Firing while anchored chains instead of cutting: the new hook flies while
## the old line keeps holding, and the anchor is swapped only at the instant the new one bites. Nothing is
## released into empty air, a shot that finds no rock costs only the throw, and the speed the old arc
## built carries into the new one.
##
## Binding a second fire to cutting instead costs two presses per arc (six to cross a chasm in three) and
## drops the swing that was just built, so the tool never becomes a rhythm.
##
## Deliberate release has no key of its own: jumping off a taut line cuts it and stacks a leap on the arc.
func fire(from: Vector2, toward: Vector2) -> void:
	if state == State.FLYING:
		return                       # a hook is already out; let it land or fall short before throwing again
	var d: Vector2 = toward - from
	_dir = d.normalized() if d.length() > 1.0 else Vector2.RIGHT
	tip = from
	_flown = 0.0
	_carry = 0.0
	if state == State.ANCHORED:
		_chain = true                # the line you are on holds until the new one bites
	else:
		state = State.FLYING
		taut = false


func cut() -> void:
	just_cut = state == State.ANCHORED
	state = State.IDLE
	taut = false
	_chain = false
	pivots.clear()


func live() -> bool:
	return state != State.IDLE


## Fly the hook, or retire a shot that found nothing. `from` is the body's hand this step, so a shot
## fired while running still trails from the runner. A chained shot flies under the same rules; only the
## failure case differs, because falling back onto a live line is not a failure.
func advance(sim: FactorySim, from: Vector2, delta: float) -> void:
	if state != State.FLYING and not _chain:
		return
	# Walk the flight in fixed PROBE bites, carrying the remainder, so the sample points are exactly the
	# ones trace() tests and a fast hook still cannot tunnel through a one-cell ledge.
	_carry += FLY_SPEED * delta
	while _carry >= PROBE:
		_carry -= PROBE
		tip += _dir * PROBE
		_flown += PROBE
		var cell := Vector2i(int(floor(tip.x / float(CELL))), int(floor(tip.y / float(CELL))))
		if sim.is_solid(cell):
			anchor_cell = cell
			# Bite at the hook's actual contact point rather than the cell centre. A hook planted in the
			# middle of a block visibly floats inside the rock.
			anchor = tip
			# A fresh plant takes up a little slack so the hook bites instead of hanging loose. A chained one
			# must not: yanking ten percent of the radius out at the swap cancels part of the arc's velocity
			# as outward motion, and an arc that loses speed at every new hold is not worth chaining. Take
			# the distance as it is and let the swing tighten it.
			var takeup: float = 1.0 if _chain else SLACK_TAKEUP
			length = maxf(MIN_LENGTH, from.distance_to(anchor) * takeup)
			pivots.clear()               # a fresh bite starts a fresh line, whatever the last one caught on
			state = State.ANCHORED
			just_planted = true
			_chain = false
			return
		if _flown >= MAX_RANGE:
			# Out of line. A fresh shot falls short and stows; a chained one stops flying and leaves the
			# body on the rope it was already on, so a chained shot is always worth trying.
			if not _chain:
				state = State.IDLE
			_chain = false
			return


## True while a hook is in the air, whether on its own or thrown from a line still being ridden.
func throwing() -> bool:
	return state == State.FLYING or _chain


## Where a shot would land right now, without firing one. The aiming ghost's single source of truth: it
## walks the same PROBE bites `advance` flies in, tests the same predicate and stops at the same range,
## because an indicator that disagrees with the hook is worse than no indicator at all. tools/check_aim
## holds the two in step.
func trace(sim: FactorySim, from: Vector2, toward: Vector2) -> Dictionary:
	var d: Vector2 = toward - from
	var dir: Vector2 = d.normalized() if d.length() > 1.0 else Vector2.RIGHT
	var at: Vector2 = from
	var flown: float = 0.0
	while flown < MAX_RANGE:
		at += dir * PROBE
		flown += PROBE
		var cell := Vector2i(int(floor(at.x / float(CELL))), int(floor(at.y / float(CELL))))
		if sim.is_solid(cell):
			return {"hit": true, "at": at, "cell": cell}
	return {"hit": false, "at": at, "cell": Vector2i.ZERO}


## Shorten or pay out the line. `axis` is +1 for up (reel in), -1 for down (pay out), the same axis that
## climbs a rope.
func reel(axis: float, delta: float) -> void:
	hauled = 0.0
	if state != State.ANCHORED or axis == 0.0:
		return
	var before: float = length
	if axis > 0.0:
		length = maxf(MIN_LENGTH, length - REEL_SPEED * delta * axis)
	else:
		length = minf(MAX_RANGE, length - PAY_SPEED * delta * axis)
	hauled = before - length


## The rope bends. A line drawn straight from the hook to the body passes through whatever rock lies
## between them, so swinging past the corner of a ledge gives the arc of an anchor that is no longer
## visible. The line is a polyline instead: the anchor, a pivot at every corner it has caught on, then the
## body, with the constraint acting from the last of those rather than from the hook. Two rules keep it
## honest:
##
##   Wrap:   if rock blocks the straight run from the current hitch to the body, the line has caught on
##           something, and the corner it caught on becomes the new hitch.
##   Unwrap: if the run from the previous hitch to the body is clear again, the line has come off that
##           corner and the pivot is dropped.
##
## Unwrap is what makes it reversible. A wrapped pivot also spends line, so the free part of the rope
## shortens as the body swings into a corner and pays back out as it swings off, and conserved tangential
## speed over a shrinking radius whips the body around the ledge.
const MAX_PIVOTS: int = 6            ## a safety cap; runaway pivots would be a bug rather than a manoeuvre
const PIVOT_NUDGE: float = 2.0       ## px a pivot sits off its corner, so the line does not re-catch itself
var pivots: Array[Vector2] = []      ## corners the line is currently caught on, anchor-first


## The point the body actually pivots around: the last corner the line has caught on, or the hook itself.
func hitch() -> Vector2:
	return pivots[pivots.size() - 1] if not pivots.is_empty() else anchor


## Line consumed by the fixed segments, anchor through every pivot, and so unavailable to the swing.
func spent() -> float:
	var total: float = 0.0
	var at: Vector2 = anchor
	for p: Vector2 in pivots:
		total += at.distance_to(p)
		at = p
	return total


## The part of the line the body is actually swinging on.
func free_length() -> float:
	return maxf(MIN_LENGTH * 0.25, length - spent())


## Catch the line on corners and let it off them again. Called once per physics step while ANCHORED,
## before the constraint, with the point the constraint measures from.
func update_line(sim: FactorySim, pos: Vector2) -> void:
	if state != State.ANCHORED:
		return
	# Unwrap first, so a line that came off a corner this step does not immediately re-catch on it.
	while not pivots.is_empty():
		var prev: Vector2 = pivots[pivots.size() - 2] if pivots.size() >= 2 else anchor
		if _blocked(sim, prev, pos):
			break
		pivots.remove_at(pivots.size() - 1)
	while pivots.size() < MAX_PIVOTS:
		var corner: Vector2 = _catch(sim, hitch(), pos)
		if corner == Vector2.INF:
			break
		pivots.append(corner)


## Where the run from `from` to `to` first meets rock, expressed as the corner of the blocking cell
## nearest the last clear point, or INF if the run is clear. Walked in the same fixed PROBE steps the hook
## and the aiming ghost use, so all three agree about what counts as blocked.
func _catch(sim: FactorySim, from: Vector2, to: Vector2) -> Vector2:
	var d: Vector2 = to - from
	var span: float = d.length()
	if span < PROBE:
		return Vector2.INF
	var dir: Vector2 = d / span
	var at: Vector2 = from
	var last: Vector2 = from
	var flown: float = 0.0
	# The line legitimately begins inside rock: the hook bites at the probe sample where solidity was first
	# found, so the anchor sits up to a quarter-cell inside its own block, and a pivot is by construction a
	# corner. A scan that took the first solid sample would catch the line on the very thing it is tied to,
	# measured as a pivot fourteen pixels from the hook pinning the body to the roof it had just thrown at.
	# A catch counts only once the run has been in open air: rock re-entered, not rock left.
	var airborne: bool = false
	while flown < span:
		at += dir * PROBE
		flown += PROBE
		var cell := Vector2i(int(floor(at.x / float(CELL))), int(floor(at.y / float(CELL))))
		if not sim.is_solid(cell):
			last = at
			airborne = true
			continue
		if not airborne:
			continue
		# The corner of the blocking cell nearest the last clear point, nudged back along the incoming
		# direction so the next step does not read the pivot itself as inside rock.
		var best: Vector2 = Vector2.INF
		var near: float = INF
		for cx: int in [0, 1]:
			for cy: int in [0, 1]:
				var c := Vector2(float(cell.x + cx), float(cell.y + cy)) * float(CELL)
				var far: float = c.distance_to(last)
				if far < near:
					near = far
					best = c
		return best + (last - best).normalized() * PIVOT_NUDGE
	return Vector2.INF


func _blocked(sim: FactorySim, from: Vector2, to: Vector2) -> bool:
	return _catch(sim, from, to) != Vector2.INF


## The constraint. Returns the corrected position. GDScript has no out-params, so velocity is handled
## separately: the caller reads `taut` and then calls `resolve_velocity`.
func constrain_position(pos: Vector2) -> Vector2:
	taut = false
	if state != State.ANCHORED:
		return pos
	var pin: Vector2 = hitch()
	var free: float = free_length()
	var d: Vector2 = pos - pin
	var dist: float = d.length()
	if dist <= free or dist < 0.001:
		return pos
	taut = true
	return pin + d / dist * free


## Cancel the outward radial component of velocity and nothing else. Everything tangential survives,
## which is what makes the swing behave as a swing.
func resolve_velocity(pos: Vector2, vel: Vector2) -> Vector2:
	if not taut:
		return vel
	var d: Vector2 = pos - hitch()
	if d.length() < 0.001:
		return vel
	var n: Vector2 = d.normalized()
	var radial: float = vel.dot(n)
	if radial <= 0.0:
		return vel
	return vel - n * radial


## The pump. Angular momentum, L = m·v·r, is conserved, so halving the radius doubles tangential speed.
## Without this step constrain_position clamps the body to a circle and resolve_velocity kills the outward
## radial part, and neither observes that the radius changed: hauling the line in at the bottom of an arc
## does nothing to how fast the arc goes, every swing is worth exactly the height it was entered from, and
## the winch is a lift. With it, reeling at the bottom, where velocity is nearly all tangential, gains
## nearly all of it, and paying out at the top, where it is nearly all radial, costs almost nothing.
##
## Symmetric on purpose: paying out scales tangential speed down by the same law, which makes swinging
## wide a brake and a decision rather than a free way to cover ground.
##
## Driven off `hauled`, the px the reel took in this frame, rather than off the radius itself, so a pivot
## appearing or releasing, which changes the free length by a whole cell in one frame, cannot be mistaken
## for a haul and fire a spike. Clamped per frame for the same reason: near the anchor the ratio runs
## away.
const PUMP_CLAMP: float = 1.05       ## most one frame may multiply tangential speed by, either direction


func pump(pos: Vector2, vel: Vector2) -> Vector2:
	if not taut or hauled == 0.0:
		return vel
	var d: Vector2 = pos - hitch()
	var r: float = d.length()
	var before: float = r + hauled    # hauled is negative while paying out, so this works both ways
	if r < 0.001 or before < 0.001:
		return vel
	var n: Vector2 = d.normalized()
	var radial: Vector2 = n * vel.dot(n)
	var tangent: Vector2 = vel - radial
	return radial + tangent * clampf(before / r, 1.0 / PUMP_CLAMP, PUMP_CLAMP)


## The line's current sag, 0 (bar-taut) .. 1 (fully slack). Pure representation: the renderer bows the
## rope by this so a live but loose line reads as rope rather than as a straight beam.
func slack(from: Vector2) -> float:
	if state != State.ANCHORED or length <= 0.001:
		return 0.0
	# Measured on the free part against the hitch, not on the whole line against the hook: a wrapped rope is
	# bar-taut around its corners by definition, and only the last segment can hang.
	var free: float = free_length()
	if free <= 0.001:
		return 0.0
	return clampf(1.0 - from.distance_to(hitch()) / free, 0.0, 1.0)
