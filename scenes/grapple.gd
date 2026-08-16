class_name Grapple
extends RefCounted

## THE TRAVERSAL VERB. Sinkforge is a game about going DOWN, and every game about going down eventually
## discovers that the trip back up is the tedium. Ropes and lifts answer that logistically — you place
## them, you ride them, it works — but riding a rope is not a thing anyone does for fun. The grapple is
## the answer that is fun: a piton on a winch line that turns a vertical shaft from a chore into the
## best part of the run.
##
## It is a NINJA ROPE, not Terraria's hook. Terraria's hook is a teleport with an animation: it plants,
## it winches you in a straight line, and your velocity is thrown away at both ends. That is fine for a
## game whose movement is walking. Ours is a game with real gravity and real momentum, and a swing is
## where those two become a skill: the rope only ever removes the OUTWARD half of your velocity, so
## everything tangential — everything you have built up — is conserved through the arc and comes out the
## other side. Release at the bottom of a swing and you keep the speed. Release at the top and you keep
## the height. Reel in mid-arc and you go faster, because pulling yourself toward the centre of a
## rotation is how a skater spins up.
##
## PHYSICS. One position-based distance constraint, solved once per substep, applied after the body's own
## integrate-and-collide:
##
##     d = pos - anchor;  if |d| > length:
##         pos = anchor + d.normalized() * length          # pull back onto the circle
##         v  -= n * max(0, v·n)                            # cancel only the OUTWARD radial component
##
## That is the whole simulation. It is unconditionally stable (a projection can't add energy on its own),
## it costs nothing, and it produces a real pendulum because the tangential component is never touched.
## Reeling in adds energy on purpose: shortening the radius while conserving tangential speed raises
## angular velocity, which is the pump every rope-swing game is built on.
##
## IT WRAPS, and this comment used to say the opposite — that a straight line you can read at a glance is
## the better toy, that wrapping buys realism at the cost of predictability. That was the right call for the
## tool as it then was: a way DOWN a shaft, reached for occasionally. It stopped being right when
## tools/check_traverse measured this thing crossing a gallery half again as fast as a full stride, which
## makes it the movement system rather than an accessory to one, and a movement system earns depth an
## accessory does not.
##
## The predictability objection deserved an answer rather than a reversal, and it got two. The line is now
## drawn as rope with visible slack instead of as a chord, so a bend is something you can SEE; and the
## aiming ghost means the anchor is chosen deliberately rather than discovered. What is left is the part
## worth having: a line that goes AROUND the rock instead of through it.
##
## The rope is a POLYLINE — anchor, then a pivot at every corner it has caught on, then the body — and the
## constraint acts from the last of those. Wrapping SPENDS line, so the free radius shortens as you swing
## into a corner and pays back out as you come off it; conserved tangential speed over a shorter radius is
## a faster rotation, and tools/check_wrap measures the difference at 4.8 rad/s against 1.2. That is the
## skill ceiling a ninja rope is supposed to have, and it is why this is a mechanic and not a render fix.

const CELL: int = 32

## THE PROBE STEP. Both the flying hook and the aiming ghost walk a shot in fixed steps of this size FROM
## THE ORIGIN, which is what lets them agree cell-for-cell. Flying by `FLY_SPEED * delta` and clipping each
## frame's leftover meant the sample points depended on the frame rate and on when in the flight you looked
## — so a shot grazing the corner of a block resolved one way in the ghost and another in the hook, three
## times in forty-eight, and three lies in forty-eight is all it takes to stop trusting a marker.
## Quarter-cell: fine enough that a hook cannot slip past a block corner, coarse enough to stay free.
const PROBE: float = float(CELL) * 0.25

enum State {
	IDLE,       ## stowed
	FLYING,     ## the hook is in the air, no constraint yet
	ANCHORED,   ## planted in rock; the line is live
}

const FLY_SPEED: float = 1800.0      ## px/s the hook travels. Measured against the rig: at 1250 a shot at a
                                     ## ceiling 14 cells up took 22 frames to bite, and a third of a second of
                                     ## dead air between pressing and swinging is enough to make the tool feel
                                     ## like a request rather than an action. 1800 lands the same shot in 15.
const MAX_RANGE: float = CELL * 15.0 ## px of line on the winch; beyond this the hook falls short
## THE WINCH SPEED, and it is the number that decides whether this is a traversal tool or a novelty.
##
## It was 165 px/s. The body RUNS at 150 and strides at 232, so hauling yourself up a line was slower than
## walking — a hand-over-hand crawl wearing a winch's name. Every game where the hook IS the movement pulls
## hard (Terraria's is about fifteen cells a second); ours pulled five, and tools/check_plunge priced the
## consequence: riding a real sinkhole down cost THREE winch hauls and forty-eight percent of the descent,
## which made the free route slower than swinging a pickaxe. A tool nobody takes is a tool that isn't there.
##
## 420 is thirteen cells a second — decisively faster than the legs, so reaching for the rope is always the
## quick answer, and still slow enough that a long haul is a commitment you feel rather than a teleport.
## The swing is untouched: reeling changes the RADIUS, and the arc's speed comes from conserved tangential
## momentum, so a faster winch spins an arc up harder without altering how the pendulum itself behaves.
const REEL_SPEED: float = 420.0      ## px/s the line shortens while you hold UP — the ascent verb
const PAY_SPEED: float = 520.0       ## px/s it pays out under DOWN (faster than reeling: rope falls easily)
const MIN_LENGTH: float = CELL * 0.8 ## you cannot winch yourself into the anchor itself
const SLACK_TAKEUP: float = 0.90     ## on plant, the line is set to this × the current distance, so the
                                     ## hook bites and takes up a little slack instead of hanging loose
const RELEASE_KICK: float = 1.05     ## a whisper of extra speed on a deliberate release — rewards timing


var state: State = State.IDLE
var tip: Vector2 = Vector2.ZERO      ## where the hook head is right now (world px)
var anchor: Vector2 = Vector2.ZERO   ## where it bit (world px) — valid while ANCHORED
var anchor_cell: Vector2i = Vector2i.ZERO
var length: float = 0.0              ## live line length (world px)
var taut: bool = false               ## was the constraint actually doing work last step? (drives the render)
## Px of line taken IN by the last reel() — zero when paying out or idle. The body converts this into
## approach speed, which is the difference between a winch and a lift: the constraint on its own only clamps
## a position, so before this existed the reel dragged you along the line and left you with no momentum at
## all. You arrived somewhere at a standstill, every time, and let go with nothing. A winch does work on the
## thing it hauls, and the work has to land in the velocity or the tool cannot build speed.
var hauled: float = 0.0
var just_planted: bool = false       ## one-shot for the impact puff / sound
var just_cut: bool = false           ## one-shot for the release whoosh

var _flown: float = 0.0              ## px the hook has travelled this shot (always a multiple of PROBE)
var _carry: float = 0.0              ## sub-PROBE remainder of this frame's flight, kept for the next one
var _dir: Vector2 = Vector2.RIGHT
## A new hook is in the air while the OLD line is still holding — see fire(). The constraint stays live
## the whole time, so a chained shot never costs you the arc you are already riding.
var _chain: bool = false


## Clear the one-shot event flags. Called ONCE PER FRAME by the body, not per substep — a plant that
## happened in substep 1 has to survive until the view reads it in _process, and at fast-forward speeds a
## frame is several substeps long. (Clearing these inside advance() ate every release, because a jump
## cuts the line earlier in the same step than the flight advances.)
func begin_frame() -> void:
	just_planted = false
	just_cut = false


## Launch toward a world point — and launch again, and again, without ever letting go.
##
## A second fire used to CUT the line: one key, two verbs. That is the right binding for a tool you reach
## for occasionally and the wrong one for a movement system. Crossing a chasm in three arcs meant six
## presses, and every second press dropped you out of the swing you had just built — so the tool could
## never become a RHYTHM, which is the only thing that makes rope movement feel like anything.
##
## So firing while anchored CHAINS: the new hook flies while the old line keeps holding, and the anchor is
## swapped only at the instant the new one bites. Nothing is ever released into empty air, a shot that
## finds no rock costs you nothing but the throw, and everything the old arc built up carries straight
## into the new one — which is the whole physics of this style of movement in one sentence.
##
## The deliberate release did not need a key of its own. Jumping off a taut line already cuts it AND
## stacks a leap on top of the arc, which is the better verb and the one a player reaches for anyway.
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


## Fly the hook / retire a shot that found nothing. `from` is the body's hand this step, so a shot fired
## while running still trails from the runner. A CHAINED shot flies under exactly the same rules; the only
## difference is what happens when it fails, because failing back onto a live line is not a failure.
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
			# Bite at the hook's actual contact point rather than the cell centre — a hook planted in the
			# middle of a block would visibly float inside the rock.
			anchor = tip
			# A FRESH plant takes up a little slack so the hook bites instead of hanging loose. A CHAINED
			# one must not: yanking ten percent of the radius out at the swap cancels a chunk of the arc's
			# velocity as "outward" motion, and an arc that loses speed every time you reach for the next
			# hold is a chain nobody chains. Take the distance as it is and let the swing tighten it.
			var takeup: float = 1.0 if _chain else SLACK_TAKEUP
			length = maxf(MIN_LENGTH, from.distance_to(anchor) * takeup)
			pivots.clear()               # a fresh bite starts a fresh line, whatever the last one caught on
			state = State.ANCHORED
			just_planted = true
			_chain = false
			return
		if _flown >= MAX_RANGE:
			# Out of line. A fresh shot falls short and stows; a chained one just stops flying and leaves
			# you on the rope you were already on, which is why chaining is always worth trying.
			if not _chain:
				state = State.IDLE
			_chain = false
			return


## Is a hook in the air right now — on its own, or thrown from a line you are still riding?
func throwing() -> bool:
	return state == State.FLYING or _chain


## WHERE A SHOT WOULD LAND, right now, without firing one. The aiming ghost's single source of truth.
##
## It walks the same cell-sized bites `advance` flies in, tests the same predicate, and stops at the same
## range — because an aim indicator that disagrees with the hook is worse than no indicator at all. You
## learn within a minute that it lies, and from then on you are aiming blind AND reading noise. The two
## staying in step is the property tools/check_aim exists to hold.
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


## Shorten / pay out the line. `axis` is +1 for UP (reel in), -1 for DOWN (pay out) — the same axis that
## climbs a rope, because it is the same gesture.
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


## THE ROPE BENDS. A line from a hook to a body, drawn straight through whatever happens to be between
## them, is a laser with a rope's texture: swing past the corner of a ledge and it passes through the rock
## as though the rock were not there, and the arc you get is the arc of an anchor you can no longer see.
##
## So the line is a POLYLINE — the anchor, then a pivot at every corner it has caught on, then the body —
## and the constraint acts from the last of those rather than from the hook. Two rules keep it honest:
##
##   WRAP    — if the rock blocks the straight run from the current hitch to the body, the line has caught
##             on something; the corner it caught on becomes the new hitch.
##   UNWRAP  — if the run from the PREVIOUS hitch to the body is clear again, the line has come off that
##             corner and the pivot is dropped.
##
## The second rule is what makes it reversible, and it is why this is worth having beyond looking right: a
## wrapped pivot spends line, so the free part of the rope SHORTENS as you swing into a corner and pays back
## out as you swing off it. Conserved tangential speed over a shrinking radius is a faster arc, so catching
## a ledge on the way past genuinely whips you around it — the whole reason a ninja rope has a skill ceiling.
const MAX_PIVOTS: int = 6            ## a cap, not a design: runaway pivots would be a bug, not a manoeuvre
const PIVOT_NUDGE: float = 2.0       ## px a pivot sits off its corner, so the line does not re-catch itself
var pivots: Array[Vector2] = []      ## corners the line is currently caught on, anchor-first


## The point the body actually pivots around: the last corner the line has caught on, or the hook itself.
func hitch() -> Vector2:
	return pivots[pivots.size() - 1] if not pivots.is_empty() else anchor


## Line consumed by the fixed segments (anchor through every pivot) — unavailable to the swinging part.
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


## Catch the line on corners / let it off them again. Called once per physics step while ANCHORED, before
## the constraint, with the point the constraint measures from.
func update_line(sim: FactorySim, pos: Vector2) -> void:
	if state != State.ANCHORED:
		return
	# UNWRAP first, so a line that came off a corner this step does not immediately re-catch on it.
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


## Where the run from `from` to `to` first meets rock, expressed as the corner of the blocking cell nearest
## the last clear point — or INF if the run is clear. Walked in the same fixed PROBE steps the hook and the
## aiming ghost use, so all three agree about what counts as blocked.
func _catch(sim: FactorySim, from: Vector2, to: Vector2) -> Vector2:
	var d: Vector2 = to - from
	var span: float = d.length()
	if span < PROBE:
		return Vector2.INF
	var dir: Vector2 = d / span
	var at: Vector2 = from
	var last: Vector2 = from
	var flown: float = 0.0
	# The line legitimately BEGINS inside rock: the hook bites at the probe sample where solidity was first
	# found, so the anchor sits up to a quarter-cell inside its own block, and a pivot is by construction a
	# corner. A scan that took the first solid sample would therefore catch the line on the very thing it is
	# tied to — measured as a pivot fourteen pixels from the hook, pinning the body to the roof it had just
	# thrown at. So a catch only counts once the run has been in OPEN AIR: rock re-entered, not rock left.
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
		# The corner of the blocking cell nearest the last clear point, nudged out along the way we came so
		# the very next step does not read the pivot itself as inside rock.
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


## The constraint. Returns the corrected position; mutates `vel` in place through the returned value's
## companion — GDScript has no out-params, so the caller reads `taut` and calls `resolve_velocity`.
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


## Cancel the OUTWARD radial component of velocity — and only that. Everything tangential survives, which
## is the entire reason the swing feels like a swing.
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


## THE PUMP, and it is the line of physics this whole tool was missing.
##
## REEL_SPEED's own comment claims "the arc's speed comes from conserved tangential momentum". It did not.
## constrain_position clamped the body to a circle and resolve_velocity killed the outward radial part, and
## between them nothing ever noticed that the RADIUS had changed — so hauling the line in at the bottom of
## an arc, the single most basic thing anyone does on a rope, did nothing at all to how fast the arc went.
## Every swing was worth exactly the height you fell into it from, and the winch was a lift.
##
## Angular momentum says otherwise: L = m·v·r is conserved, so halving the radius doubles the tangential
## speed. That one identity is the entire skill of a grapple game. Reel at the BOTTOM, where the velocity
## is nearly all tangential and the gain is nearly all of it; pay out at the TOP, where it is nearly all
## radial and costs almost nothing. In phase, an arc winds itself up out of nothing. Out of phase, it dies.
## Nobody has to be told the rule — it is a swing, and everyone has been on a swing.
##
## Symmetric on purpose: paying out scales tangential speed DOWN by the same law, which makes S a real
## brake and swinging wide a real decision rather than a free way to cover ground.
##
## Driven off `hauled` (px the reel took in this frame) rather than off the radius itself, so a pivot
## appearing or releasing — which changes the free length by a whole cell in one frame — cannot be mistaken
## for a haul and fire a spike. Clamped per frame for the same reason: near the anchor the ratio runs away.
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
## rope by this so a live-but-loose line reads as rope rather than as a laser.
func slack(from: Vector2) -> float:
	if state != State.ANCHORED or length <= 0.001:
		return 0.0
	# Measured on the FREE part against the HITCH, not on the whole line against the hook: a wrapped rope is
	# bar-taut around its corners by definition, and only the last segment can hang.
	var free: float = free_length()
	if free <= 0.001:
		return 0.0
	return clampf(1.0 - from.distance_to(hitch()) / free, 0.0, 1.0)
