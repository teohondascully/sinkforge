class_name GaitState
extends RefCounted

## THE GAIT'S STATE AND ITS ORDER, split from `sim/body/body.gd` at the 400-line file cap (D0310).
## `sim/body/gait.gd` holds the decisions and the constants and is pure; this holds the five values that
## persist between ticks and the sequence they are updated in. `docs/QUALITY.md` §2 records what happens
## when a cap is met by trimming instead of splitting: `body.gd` sat at exactly 400 for three commits.
##
## The seam is the right one and not merely the convenient one: everything in `gait.gd` is a function of
## its arguments and can be asserted with no world at all, while everything here is about WHEN — which
## has to run after the resolve, what a landing means, which edge seeds the fall. That is body work.
##
## **EVERY FIELD HERE IS IN `Body.state_signature()`.** The signature IS the determinism contract
## (D0261): a mutation path it does not cover is a divergence the two-process replay cannot see. `stride`
## and `stagger_ticks` change acceleration and top speed, so a replay that ignored them would diverge
## silently — and `_stride_hold`, `_fall_from_y` and `_was_on_floor` are what produce them.

var stride: int = 0            ## 0..`Gait.STRIDE_FULL`; read by the view for the lean
var stagger_ticks: int = 0     ## ticks of reduced grip left; read by the view for the recovery pose
var hold: int = 0              ## ticks of unbroken qualifying travel, banking toward STRIDE_DELAY_TICKS
var fall_from_y: int = 0       ## Fx world y this fall began at -- the stagger is priced on DISTANCE
var was_on_floor: bool = false
var landed_hard: bool = false  ## one tick, for the view: dust, shake, thump


## The save's copy of this state and its inverse (A' step 4b, D0357): exactly the fields `signature`
## covers plus `landed_hard`, so a loaded body walks on as the saved one would have.
func capture() -> Dictionary:
	return {"stride": stride, "stagger_ticks": stagger_ticks, "hold": hold, "fall_from_y": fall_from_y,
		"was_on_floor": was_on_floor, "landed_hard": landed_hard}


func restore(d: Dictionary) -> void:
	stride = int(d.get("stride", 0))
	stagger_ticks = int(d.get("stagger_ticks", 0))
	hold = int(d.get("hold", 0))
	fall_from_y = int(d.get("fall_from_y", 0))
	was_on_floor = bool(d.get("was_on_floor", false))
	landed_hard = bool(d.get("landed_hard", false))


func signature() -> String:
	return "%d,%d,%d,%d,%s" % [stride, stagger_ticks, hold, fall_from_y, was_on_floor]


## One tick, run LAST in `Body.tick` so it reads the SETTLED `on_floor` and `pos_y` rather than the
## mid-resolve ones. Returns the body's possibly-seeded `vel_y`; the caller assigns it back.
##
## The `FALL_START` seed reproduces `legacy/scenes/player.gd:411-412` and is gated the same way: to the
## grounded-to-airborne EDGE and to `vel_y >= 0`, because a jump is negative here and must never be
## altered by it. Without the seed, the frame a resting body loses its floor it creeps down from zero and
## the descent reads as lag.
func step(on_floor: bool, pos_y: int, vel_y: int, move_dir: int, vel_x: int, run_speed: int) -> int:
	landed_hard = false
	var out_vel_y: int = vel_y
	if was_on_floor and not on_floor and vel_y >= 0:
		out_vel_y = maxi(vel_y, Gait.FALL_START)
	if on_floor and not was_on_floor:
		_land(pos_y, vel_y)
	if on_floor:
		# A fall begins where the ground was left, so this tracks continuously while grounded and is
		# frozen the moment it is not. Walking off a ledge and jumping off it therefore price the same.
		fall_from_y = pos_y
	stagger_ticks = maxi(0, stagger_ticks - 1)
	var next: Dictionary = Gait.step_stride(stride, hold, on_floor, move_dir, vel_x, run_speed)
	stride = int(next["stride"])
	hold = int(next["hold"])
	was_on_floor = on_floor
	return out_vel_y


## THE LANDING. The stagger is priced on the DISTANCE fallen, not on the impact speed, and legacy's
## reason is the load-bearing one: impact speed saturates at terminal velocity, so past ~174 px a short
## drop and a long plunge land identically and any speed threshold fires on both or on neither.
func _land(pos_y: int, vel_y: int) -> void:
	var earned: int = Gait.stagger_for_fall(pos_y - fall_from_y)
	if earned > 0:
		stagger_ticks = maxi(stagger_ticks, earned)
	# Two ways to be a hard landing, and they are not the same event: a fall long enough to STAGGER, or a
	# fast arrival that does not (a jump landed at speed). Both cost the stride; only the first costs grip.
	if earned > 0 or vel_y > Gait.HARD_LANDING_SPEED:
		landed_hard = true
		stride = (stride * Gait.STRIDE_LAND_COST_NUM) / Gait.STRIDE_LAND_COST_DEN
