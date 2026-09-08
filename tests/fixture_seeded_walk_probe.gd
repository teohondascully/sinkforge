extends SceneTree

## Not a suite -- no `_finish()`, doesn't extend `test_base.gd`. THE OPENING GEOMETRY UNDER A STANDING AND
## WALKING BODY (D0516): boots the real tutorial world the way `tests/test_first_rung_door.gd` does
## (`Session.new_game`, the seed every stranger seat logged), then drives the body through the door for
## 600 ticks -- standing at the spawn, walking WALK_PX right, twice that left, and back -- and prints how
## many ticks `Body.floor_selection_violation_this_tick` was set. `tests/test_floor_ambiguity.gd` spawns
## this as a subprocess and counts the `push_error` reports in its stderr as well, the same lines a seat
## log carries, because stock GDScript cannot count its own `push_error()` calls in-process (the reason
## `fixture_settle_violation_probe.gd` exists). Before D0516 the same walk reported the check dozens of
## times on the pockets the world seeder authors under the pad; the ledger carries both numbers.
##
## The walk's real extent is printed with the count so the frame is named: a count over a body that
## never moved would be a count over a different fixture.

const SEED: int = 20260826       ## the seed in every stranger seat's own report line
const TICKS: int = 600
const STAND_TICKS: int = 120
const WALK_PX: int = 10 * 16     ## 10 m at 16 px a metre (docs/ARCHITECTURE.md §9)


func _initialize() -> void:
	var door: Interface = Session.new_game(StrataData.SHALLOW_CLAY, SEED, &"tutorial")
	if door == null:
		print("SEEDED_WALK_PROBE boot=failed")
		quit(1)
		return
	var body: Body = door.services()["body"]
	var spawn_x: int = body.pos_x
	var walk: int = WALK_PX * Fx.SCALE
	var flagged: int = 0
	var min_dx: int = 0
	var max_dx: int = 0
	var leg: int = 0   ## 0 stand, 1 right to +walk, 2 left to -walk, 3 right to the spawn, 4 stand
	for t: int in TICKS:
		var f: InputFrame = InputFrame.new()
		if t >= STAND_TICKS and leg == 0:
			leg = 1
		if leg == 1:
			f.move_dir = 1
			if body.pos_x - spawn_x >= walk:
				leg = 2
		elif leg == 2:
			f.move_dir = -1
			if body.pos_x - spawn_x <= -walk:
				leg = 3
		elif leg == 3:
			f.move_dir = 1
			if body.pos_x >= spawn_x:
				leg = 4
		door.apply(Command.move(f))
		if body.floor_selection_violation_this_tick:
			flagged += 1
		min_dx = mini(min_dx, body.pos_x - spawn_x)
		max_dx = maxi(max_dx, body.pos_x - spawn_x)
	print("SEEDED_WALK_PROBE seed=%d ticks=%d flagged_ticks=%d walked_left_px=%.1f walked_right_px=%.1f final_leg=%d spawn_col=%d" % [
		SEED, TICKS, flagged, float(-min_dx) / float(Fx.SCALE), float(max_dx) / float(Fx.SCALE), leg,
		Body._px_to_cell(spawn_x)])
	quit(0)
