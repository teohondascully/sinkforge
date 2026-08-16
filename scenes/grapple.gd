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
## WHAT IT DELIBERATELY DOESN'T DO: the line does not wrap around corners. Worms wraps; Bionic Commando
## doesn't; neither does Spider-Man. Wrapping needs a per-frame corner search and a wrap stack, and it
## buys realism in exchange for a rope whose behaviour the player can no longer predict from where they
## are pointing. A straight line you can read at a glance is the better toy.

const CELL: int = 32

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
var just_planted: bool = false       ## one-shot for the impact puff / sound
var just_cut: bool = false           ## one-shot for the release whoosh

var _flown: float = 0.0              ## px the hook has travelled this shot
var _dir: Vector2 = Vector2.RIGHT


## Clear the one-shot event flags. Called ONCE PER FRAME by the body, not per substep — a plant that
## happened in substep 1 has to survive until the view reads it in _process, and at fast-forward speeds a
## frame is several substeps long. (Clearing these inside advance() ate every release, because a jump
## cuts the line earlier in the same step than the flight advances.)
func begin_frame() -> void:
	just_planted = false
	just_cut = false


## Launch toward a world point. A second fire while live is a RELEASE — one key, two verbs, which is
## what makes the rope feel like something you flick rather than something you manage.
func fire(from: Vector2, toward: Vector2) -> void:
	if state != State.IDLE:
		cut()
		return
	var d: Vector2 = toward - from
	_dir = d.normalized() if d.length() > 1.0 else Vector2.RIGHT
	tip = from
	_flown = 0.0
	state = State.FLYING
	taut = false


func cut() -> void:
	just_cut = state == State.ANCHORED
	state = State.IDLE
	taut = false


func live() -> bool:
	return state != State.IDLE


## Fly the hook / retire a shot that found nothing. `from` is the body's hand this step, so a shot fired
## while running still trails from the runner.
func advance(sim: FactorySim, from: Vector2, delta: float) -> void:
	if state != State.FLYING:
		return
	var step: float = FLY_SPEED * delta
	# Walk the flight in CELL-sized bites so a fast hook can't tunnel through a one-cell ledge.
	var travelled: float = 0.0
	while travelled < step:
		var bite: float = minf(float(CELL) * 0.5, step - travelled)
		tip += _dir * bite
		travelled += bite
		_flown += bite
		var cell := Vector2i(int(floor(tip.x / float(CELL))), int(floor(tip.y / float(CELL))))
		if sim.is_solid(cell):
			anchor_cell = cell
			# Bite at the hook's actual contact point rather than the cell centre — a hook planted in the
			# middle of a block would visibly float inside the rock.
			anchor = tip
			length = maxf(MIN_LENGTH, from.distance_to(anchor) * SLACK_TAKEUP)
			state = State.ANCHORED
			just_planted = true
			return
		if _flown >= MAX_RANGE:
			state = State.IDLE       # out of line — the shot falls short and stows
			return


## Shorten / pay out the line. `axis` is +1 for UP (reel in), -1 for DOWN (pay out) — the same axis that
## climbs a rope, because it is the same gesture.
func reel(axis: float, delta: float) -> void:
	if state != State.ANCHORED or axis == 0.0:
		return
	if axis > 0.0:
		length = maxf(MIN_LENGTH, length - REEL_SPEED * delta * axis)
	else:
		length = minf(MAX_RANGE, length - PAY_SPEED * delta * axis)


## The constraint. Returns the corrected position; mutates `vel` in place through the returned value's
## companion — GDScript has no out-params, so the caller reads `taut` and calls `resolve_velocity`.
func constrain_position(pos: Vector2) -> Vector2:
	taut = false
	if state != State.ANCHORED:
		return pos
	var d: Vector2 = pos - anchor
	var dist: float = d.length()
	if dist <= length or dist < 0.001:
		return pos
	taut = true
	return anchor + d / dist * length


## Cancel the OUTWARD radial component of velocity — and only that. Everything tangential survives, which
## is the entire reason the swing feels like a swing.
func resolve_velocity(pos: Vector2, vel: Vector2) -> Vector2:
	if not taut:
		return vel
	var d: Vector2 = pos - anchor
	if d.length() < 0.001:
		return vel
	var n: Vector2 = d.normalized()
	var radial: float = vel.dot(n)
	if radial <= 0.0:
		return vel
	return vel - n * radial


## The line's current sag, 0 (bar-taut) .. 1 (fully slack). Pure representation: the renderer bows the
## rope by this so a live-but-loose line reads as rope rather than as a laser.
func slack(from: Vector2) -> float:
	if state != State.ANCHORED or length <= 0.001:
		return 0.0
	return clampf(1.0 - from.distance_to(anchor) / length, 0.0, 1.0)
