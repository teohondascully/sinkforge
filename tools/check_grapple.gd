extends "res://tools/check_base.gd"

## Harness layer: THE GRAPPLE, scored. The grapple exists to make vertical space fun instead of tedious,
## and "fun" is not a thing a harness can read. What a harness CAN read is the four properties the fun is
## made of, so each is turned into a number with a floor under it:
##
##   1. IT BITES.       A shot at rock plants within a few frames; a shot at open sky runs out of line and
##                      stows instead of hanging in the air forever.
##   2. IT SWINGS.      From a dead hang, pumping the arc gets the body moving FASTER than its legs can,
##                      because the constraint only removes the outward half of velocity, so the tangential
##                      half accumulates. If a change ever makes the rope bleed tangential speed, this is
##                      the number that drops, and a swing that is slower than walking is a swing nobody
##                      will ever use.
##   3. IT LIFTS.       Reeling in raises the body against gravity. This is the answer to the trip back up,
##                      and it is the single most load-bearing claim the tool makes.
##   4. IT CROSSES.     A chasm too wide to jump is crossed by swinging it. This is the whole verb, end to
##                      end, driven through the real body and the real constraint: the play-test, not a
##                      unit test of the maths.
##
## Every rig here is built the way check_agility builds its course: carve a pocket of open sky out of the
## real world, then place exactly the geometry the property needs, so nothing depends on worldgen.
##   godot --headless --path . --script res://tools/check_grapple.gd

const SCENE: String = "res://scenes/main.tscn"
const CELL: int = 32

## Rig geometry, in cells. A ceiling to hook, a floor to stand on, and a gap in that floor wider than any
## jump the body owns.
const RIG_LEFT: int = 10
const RIG_RIGHT: int = 40
## The ceiling sits 10 cells over the floor, not 16: the winch carries 15 cells of line, so a 16-cell
## room means every diagonal shot falls a hair short and the rig measures the range limit instead of the
## thing under test. Rooms you actually swing in are the ones you can reach the roof of.
const CEIL_ROW: int = 14
const FLOOR_ROW: int = 24
const GAP_LEFT: int = 22
const GAP_RIGHT: int = 32          ## a 10-cell chasm — the jump arc clears about three

## Floors, with headroom over the measured baseline printed by a clean run.
const PLANT_FRAMES_CAP: int = 12   ## frames from fire() to ANCHORED at 8 cells of line (baseline 9)
const SWING_SPEED_FLOOR: float = 1.15  ## × RUN_SPEED the pumped arc must beat, or the rope isn't worth using
const REEL_LIFT_FLOOR: float = 3.0     ## cells the body must gain in 90 frames of holding UP on the line
## Fraction of release speed still on the body half a second later, flying free. This is the one that
## guards the POINT of the tool: the controller's normal job is to hold you at RUN_SPEED, and for a while
## it did exactly that to a released swing: 420px/s bled back to a walk inside a sixth of a second, which
## makes every swing a very pretty way of arriving at walking pace. Speed you cannot keep is not a reward.
const MOMENTUM_KEEP_FLOOR: float = 0.72

func _initialize() -> void:
	print("== grapple check ==")
	MainView.dev_start = false
	await _run()
	if _failures == 0:
		print("GRAPPLE OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)


func _run() -> void:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 30:
		await physics_frame
	main._player.auto_input = false
	_build_rig(main.sim)

	await _check_bite(main)
	await _check_miss(main)
	var swing: float = await _check_swing(main)
	var lift: float = await _check_reel(main)
	var crossed: bool = await _check_chasm(main)
	var kept: float = await _check_momentum(main)

	print("  swing top speed = %.2f x RUN_SPEED (floor %.2f)  |  reel lift = %.1f cells (floor %.1f)"
		% [swing, SWING_SPEED_FLOOR, lift, REEL_LIFT_FLOOR])
	_check(swing >= SWING_SPEED_FLOOR,
		"a pumped swing beats walking (%.2fx >= %.2fx)" % [swing, SWING_SPEED_FLOOR])
	_check(lift >= REEL_LIFT_FLOOR,
		"reeling in lifts the body against gravity (%.1f >= %.1f cells)" % [lift, REEL_LIFT_FLOOR])
	_check(crossed, "a 10-cell chasm no jump can clear is crossed by swinging it")
	_check(kept >= MOMENTUM_KEEP_FLOOR,
		"speed built on the line SURVIVES the release (%.2f >= %.2f of it, 30f later)"
		% [kept, MOMENTUM_KEEP_FLOOR])

	main.queue_free()
	await physics_frame


## A pocket of open sky with a ceiling above and a floor below, split by a chasm.
func _build_rig(sim: FactorySim) -> void:
	for col: int in range(RIG_LEFT - 2, RIG_RIGHT + 3):
		for row: int in range(CEIL_ROW - 3, FLOOR_ROW + 6):
			sim.set_solid(Vector2i(col, row), &"")
	for col: int in range(RIG_LEFT - 2, RIG_RIGHT + 3):
		for row: int in range(CEIL_ROW - 3, CEIL_ROW + 1):        # a thick ceiling to bite into
			sim.set_solid(Vector2i(col, row), &"stone")
		if col > GAP_LEFT and col < GAP_RIGHT:
			continue                                              # the chasm: no floor here
		for row: int in range(FLOOR_ROW, FLOOR_ROW + 5):
			sim.set_solid(Vector2i(col, row), &"stone")


## Fire and WAIT for the bite. The flight is a real projectile at a real speed, so how long it takes
## depends on how far away the rock is; a fixed frame budget silently turns "the shot is still in the
## air" into "the rig failed to anchor", which is how the first run of this file lied.
func _hook(main: MainView, target: Vector2i, budget: int = 90) -> bool:
	var p: Player = main._player
	p.grapple.fire(p.hand(), main._cell_center(target))
	for _i: int in budget:
		await physics_frame
		if p.grapple.state == Grapple.State.ANCHORED:
			return true
		if not p.grapple.live():
			return false
	return false


func _stand(main: MainView, col: int, row: int) -> void:
	main._player.grapple.cut()
	main._player.position = main._cell_center(Vector2i(col, row))
	main._player.velocity = Vector2.ZERO
	main._player.input_dir = 0.0
	main._player.input_climb = 0.0
	main._player.jump_held = false
	for _i: int in 20:
		await physics_frame


## 1. IT BITES: a shot straight up at the ceiling plants, and plants fast.
func _check_bite(main: MainView) -> void:
	await _stand(main, RIG_LEFT + 4, FLOOR_ROW - 2)
	var p: Player = main._player
	p.grapple.fire(p.hand(), main._cell_center(Vector2i(RIG_LEFT + 4, CEIL_ROW)))
	var frames: int = 0
	while p.grapple.state == Grapple.State.FLYING and frames < 60:
		frames += 1
		await physics_frame
	_check(p.grapple.state == Grapple.State.ANCHORED, "a shot at the ceiling ANCHORS")
	_check(frames <= PLANT_FRAMES_CAP,
		"it plants fast (%d <= %d frames)" % [frames, PLANT_FRAMES_CAP])
	_check(main.sim.is_solid(p.grapple.anchor_cell), "it anchored in a genuinely solid cell")
	p.grapple.cut()
	_check(not p.grapple.live(), "cutting the line stows it")


## 2. A shot at nothing runs out of line rather than flying forever.
func _check_miss(main: MainView) -> void:
	var p: Player = main._player
	await _stand(main, RIG_LEFT + 4, FLOOR_ROW - 2)
	# Fire along the open corridor between floor and ceiling: nothing to hit inside MAX_RANGE.
	p.grapple.fire(p.hand(), p.hand() + Vector2(1.0, -0.02))
	var frames: int = 0
	while p.grapple.live() and frames < 240:
		frames += 1
		await physics_frame
	_check(not p.grapple.live(), "a shot that hits nothing runs out of line and stows")


## 3. IT SWINGS: hang from the ceiling, pump the arc, and beat walking speed.
func _check_swing(main: MainView) -> float:
	# Stand on SOLID ground at the chasm's left lip and hook the ceiling out over the void, so the body
	# has a real drop to swing into. (Standing mid-chasm just falls; there is no floor there.)
	await _stand(main, GAP_LEFT - 1, FLOOR_ROW - 2)
	var p: Player = main._player
	if not await _hook(main, Vector2i(GAP_LEFT + 3, CEIL_ROW)):
		_check(false, "the swing rig anchored")
		return 0.0
	# Step off into the chasm and pump: steer with the arc, flipping at each apex, the way a player would.
	p.position += Vector2(0.0, -4.0)
	var best: float = 0.0
	var dir: float = 1.0
	var prev_x: float = p.position.x
	for i: int in 420:
		p.input_dir = dir
		await physics_frame
		var vx: float = p.velocity.x
		# Flip the pump at each apex (where horizontal travel reverses), which is how a swing is driven.
		if signf(p.position.x - prev_x) != 0.0 and signf(p.position.x - prev_x) != signf(dir):
			dir = -dir
		prev_x = p.position.x
		if i > 60:
			best = maxf(best, absf(vx))
	p.input_dir = 0.0
	p.grapple.cut()
	return best / Player.RUN_SPEED


## 4. IT LIFTS: hang on the line and hold UP; the body must climb.
func _check_reel(main: MainView) -> float:
	await _stand(main, RIG_LEFT + 6, FLOOR_ROW - 2)
	var p: Player = main._player
	if not await _hook(main, Vector2i(RIG_LEFT + 6, CEIL_ROW)):
		_check(false, "the reel rig anchored")
		return 0.0
	var y0: float = p.position.y
	p.position += Vector2(0.0, -6.0)        # break contact with the floor so the reel gate opens
	p.input_climb = 1.0
	for _i: int in 90:
		await physics_frame
	p.input_climb = 0.0
	var gained: float = (y0 - p.position.y) / float(CELL)
	p.grapple.cut()
	return gained


## 5. IT CROSSES, the whole verb, end to end, played the way a player plays it: run at the lip, hook the
## ceiling out over the void, ride the arc, and LET GO on the far side. The release is the point. A test
## that clung to the rope and reeled itself in was testing a winch, not a swing, and it never got across.
func _check_chasm(main: MainView) -> bool:
	await _stand(main, GAP_LEFT - 5, FLOOR_ROW - 2)
	var p: Player = main._player
	p.input_dir = 1.0
	for _i: int in 34:                       # run up to the lip at full speed
		await physics_frame
	p.grapple.fire(p.hand(), main._cell_center(Vector2i(GAP_LEFT + 5, CEIL_ROW)))
	var released: bool = false
	for _i: int in 300:
		await physics_frame
		# Let go when the body is OVER the far lip, which is what a player does, and which is later than
		# the low point of the arc. Releasing at the anchor's column gives you the most speed and the least
		# height, and drops you straight into the hole you were trying to clear.
		if not released and p.grapple.taut and p.position.x > float(GAP_RIGHT) * CELL:
			p.grapple.cut()
			released = true
		if released and p.on_floor:
			break
	p.input_dir = 0.0
	p.grapple.cut()
	for _i: int in 60:
		await physics_frame
	var landed: Vector2i = main._cell_at(p.position)
	print("  chasm: released=%s, body ended at cell %s (far lip is col %d), on_floor=%s"
		% [str(released), str(landed), GAP_RIGHT, str(p.on_floor)])
	return landed.x >= GAP_RIGHT and p.on_floor


## 6. IT KEEPS: the controller property the swing depends on, tested at its own level. A pendulum is at
## its fastest exactly where it is lowest, so there is no point on an arc that is both fast and high, and
## a test that demanded both never fired at all. What actually needs guarding is simpler than the rig
## makes it look: a body moving faster than it can run, with nobody touching the controls, must still be
## moving faster than it can run a moment later. Launch it in open air and watch.
##
## Without this property the whole tool is decorative: the controller's normal job is to hold you AT
## RUN_SPEED, and for a while it did exactly that to a released swing: 420px/s bled to a walk inside a
## sixth of a second. Speed you cannot keep is not a reward. (The end-to-end proof that it reaches the
## body lives in the chasm test above, which lands three cells further with this than without it.)
func _check_momentum(main: MainView) -> float:
	await _stand(main, RIG_LEFT + 2, FLOOR_ROW - 6)
	var p: Player = main._player
	var launch: float = Player.SWING_MAX_SPEED
	p.position = main._cell_center(Vector2i(RIG_LEFT + 2, FLOOR_ROW - 6))
	p.velocity = Vector2(launch, -40.0)
	p.input_dir = 0.0                        # hands off — coasting, not driving
	p.on_floor = false
	var flown: int = 0
	for _i: int in 30:
		await physics_frame
		flown += 1
		if p.on_floor:
			break
	var kept: float = p.velocity.x / launch
	print("  momentum: launched at %.0f px/s, %.0f px/s %df later (kept %.2f, on_floor=%s)"
		% [launch, p.velocity.x, flown, kept, str(p.on_floor)])
	return kept
