class_name Gait
extends RefCounted

## THE STRIDE AND THE STAGGER — the two things that make crossing a world and falling into one cost
## something. Ported from `legacy/scenes/player.gd:45-71` (the constants and their reasoning),
## `:625-643 _update_stride`, and `:411-432` (the fall accounting). `docs/LEGACY_GAP.md` T1 #9 and #10.
## `docs/DECISIONS_LEDGER.md` D0310.
##
## **THESE CONSTANTS PORT IN PIXELS, NOT IN METRES, AND KNOWING WHICH REGIME YOU ARE IN IS THE WHOLE
## TRAP.** WG-4 (D0305) converted world-generation constants by ×4 / ×16 / ×0.5 because legacy's cell was
## one metre and this build's is a quarter of one. **The body is the opposite case**: `sim/body/body.gd`
## is a pixel-for-pixel port of legacy's player, and it is exact —
##
##     legacy `player.gd`   RUN_SPEED 150.0   GRAVITY 900.0   JUMP_VELOCITY -365.0   MAX_FALL 560.0
##     this build `body.gd` RUN_SPEED 150     GRAVITY 900     JUMP_VELOCITY -365     MAX_FALL 560
##
## Four for four. So a fall of 288 px takes the same time, reaches the same speed, and stands in the same
## ratio to the same jump height in both builds. Converting these to metres would have been the *correct*
## procedure applied in the wrong regime — a change of 2× to numbers that were already right, justified by
## an arithmetic that does not apply here. The check that settles it is comparing the constants, not
## reasoning about what a cell means.
##
## STATE, HELD BY THE BODY. This class is stateless and every function is a pure integer function of the
## values handed in, so the whole gait can be asserted with no world, no grid and no tick loop.

## Fx-scaled px/s seeded when a grounded body starts falling. Legacy `FALL_START 150.0`: without it, the
## frame a resting body loses its floor it creeps down from zero and the descent reads as lag.
const FALL_START: int = 150 * Fx.SCALE

## THE COST OF A LANDING, priced on DISTANCE FALLEN rather than on impact speed, and legacy's reason is
## the load-bearing one: impact speed SATURATES. Terminal velocity (`MAX_FALL` 560 px/s under `GRAVITY`
## 900 px/s²) arrives after 174 px of fall, so past that a six-cell hop and a forty-row plunge land at
## identical speed and any threshold fires on both or on neither.
##
## The cost is GRIP, NOT DAMAGE. There is no health system here, and legacy's note is worth keeping
## whole: "a platformer that takes control away feels broken however justified the moment". Steering,
## jumping and mining all still work; the legs simply have less authority for a beat.
const STAGGER_FALL_PX: int = 32 * 9    ## legacy `CELL * 9.0`, past any ordinary platforming drop
const STAGGER_FULL_PX: int = 32 * 30   ## ...and the fall that costs the whole beat
const STAGGER_FALL: int = STAGGER_FALL_PX * Fx.SCALE
const STAGGER_FULL: int = STAGGER_FULL_PX * Fx.SCALE

## 0.26 s at 60 Hz. Rounded to 16 rather than 15.6: legacy calls this "a beat, never a lockout", and the
## rounding that errs toward the beat is the one that keeps its meaning.
const STAGGER_MAX_TICKS: int = 16

## Legacy `STAGGER_GRIP 0.34` × accel while staggered, as a plain int ratio — 34/100 reduced. Kept as a
## rational for the same reason `AIR_CONTROL_NUM/DEN` and `Mining.REACH_NUM/DEN` are: an `int*int/int` is
## exact and two Fx values multiplied are not.
const STAGGER_GRIP_NUM: int = 17
const STAGGER_GRIP_DEN: int = 50

## THE STRIDE. One flat top speed is the wrong speed for crossing a world: `RUN_SPEED` is tuned for
## mining, and legacy's answer is not to raise it but to let it BUILD, so that everything short of a
## sustained run happens at exactly the old speed and the mining feel is untouched.
##
## `stride` is an integer 0..STRIDE_FULL rather than a float 0..1, and STRIDE_FULL is chosen so that
## every rate below divides it exactly — a fixed-point sim cannot afford a ramp whose step is 49.999.
const STRIDE_FULL: int = 3600
const STRIDE_DELAY_TICKS: int = 54          ## legacy 0.9 s: long enough that the stride cannot be flicked into
const STRIDE_RAMP_PER_TICK: int = STRIDE_FULL / 72   ## legacy 1.2 s to full == 50 exactly
const STRIDE_DECAY_PER_TICK: int = STRIDE_FULL / 20  ## legacy 3.0/s == 180 exactly, a third of a second to nothing
const STRIDE_LAND_COST_NUM: int = 1         ## legacy `STRIDE_LAND_COST 0.5`: a hard landing costs half the run
const STRIDE_LAND_COST_DEN: int = 2
## Extra top speed at full stride: legacy `STRIDE_GAIN 0.55`, 150 -> 232 px/s. 55/100 reduced.
const STRIDE_GAIN_NUM: int = 11
const STRIDE_GAIN_DEN: int = 20
## The stride only builds while genuinely travelling: legacy asks `absf(velocity.x) > RUN_SPEED * 0.8`.
const STRIDE_MIN_SPEED_NUM: int = 4
const STRIDE_MIN_SPEED_DEN: int = 5

## Fx-scaled px/s of downward speed that counts as a real landing rather than a step down. Legacy
## `impact_v > 240.0`.
const HARD_LANDING_SPEED: int = 240 * Fx.SCALE


## Top speed for a given stride. At stride 0 this is exactly `RUN_SPEED`, which is the property that
## keeps the mining feel untouched — asserted rather than assumed, because a gain applied from the first
## tick would be a different game that still passes a top-speed test at full stride.
static func top_speed(run_speed: int, stride: int) -> int:
	if stride <= 0:
		return run_speed
	var s: int = mini(stride, STRIDE_FULL)
	return run_speed + (run_speed * STRIDE_GAIN_NUM * s) / (STRIDE_GAIN_DEN * STRIDE_FULL)


## Ground acceleration for a given stagger. `stagger_ticks` is how many ticks of reduced grip remain.
static func grip(accel: int, stagger_ticks: int) -> int:
	if stagger_ticks <= 0:
		return accel
	return (accel * STAGGER_GRIP_NUM) / STAGGER_GRIP_DEN


## Is the stride BUILDING this tick? Legacy's own three-way split, kept as three states rather than
## collapsed into a boolean, because "holding" and "breaking" are different and only one of them is the
## absence of building:
##
##   BUILDING  on the ground, travelling the way you are steering, at speed. Time banks toward
##             `STRIDE_DELAY_TICKS` first, and only then does the stride itself ramp.
##   HOLDING   airborne with a run already going — a ledge mid-sprint must not cost the sprint.
##   BREAKING  everything else, bled fast enough that a mistake reads as a mistake.
##
## A wall needs no special case: it zeroes `vel_x`, which fails the travelling test.
static func is_building(on_floor: bool, move_dir: int, vel_x: int, run_speed: int) -> bool:
	if not on_floor or move_dir == 0:
		return false
	if move_dir * vel_x <= 0:
		return false   ## steering against your own momentum is a turn, not a run
	return absi(vel_x) > (run_speed * STRIDE_MIN_SPEED_NUM) / STRIDE_MIN_SPEED_DEN


## One tick of the stride machine. Returns `{stride, hold}` rather than mutating, so the whole state
## transition is a value a test can hold in its hand.
static func step_stride(stride: int, hold: int, on_floor: bool, move_dir: int, vel_x: int,
		run_speed: int) -> Dictionary:
	if is_building(on_floor, move_dir, vel_x, run_speed):
		var next_hold: int = hold + 1
		var next_stride: int = stride
		if next_hold > STRIDE_DELAY_TICKS:
			next_stride = mini(STRIDE_FULL, stride + STRIDE_RAMP_PER_TICK)
		return {"stride": next_stride, "hold": next_hold}
	# Airborne mid-run: the run KEEPS, it just stops growing. `move_dir * vel_x >= 0` rather than `> 0`,
	# so a hands-off arc over a gap holds the stride and only steering BACK breaks it.
	if not on_floor and stride > 0 and move_dir * vel_x >= 0:
		return {"stride": stride, "hold": hold}
	return {"stride": maxi(0, stride - STRIDE_DECAY_PER_TICK), "hold": 0}


## The stagger a fall of `fell` (Fx px) earns, in ticks. Zero below `STAGGER_FALL`, ramping linearly to
## `STAGGER_MAX_TICKS` at `STAGGER_FULL` and clamped there.
static func stagger_for_fall(fell: int) -> int:
	if fell <= STAGGER_FALL:
		return 0
	var span: int = STAGGER_FULL - STAGGER_FALL
	var over: int = mini(fell - STAGGER_FALL, span)
	return (STAGGER_MAX_TICKS * over) / span
