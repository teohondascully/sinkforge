extends SceneTree

## Harness layer 14 — CONTROL-SCHEME context rules (playtest: "W should be jump like Terraria", but W
## must still CLIMB on a rope). Feeds synthetic action events to Player._unhandled_input and checks the
## resulting jump request, so a remap or a movement refactor can't silently break the scheme:
##   - W (Controls.UP) OFF a rope  → requests a JUMP (the Terraria feel the user asked for)
##   - W ON a rope                 → does NOT jump (it climbs)
##   - Space                       → always jumps (incl. off a rope)
## Run: godot --headless --path . --script res://tools/check_controls.gd

const CELL: int = 32

var _failures: int = 0


func _initialize() -> void:
	print("== controls check ==")
	Controls.register()
	var sim: FactorySim = FactorySim.new()
	for x: int in range(0, 10):
		sim.set_solid(Vector2i(x, 10), &"earth")       # a floor
	sim.inventory[&"rope"] = 10
	sim.total_produced[&"rope"] = 10
	sim.place_rope(Vector2i(3, 5))                     # a rope down column 3
	_check(sim.is_climbable(Vector2i(3, 6)), "fixture: column 3 is roped")
	_check(not sim.is_climbable(Vector2i(7, 6)), "fixture: column 7 is not roped")

	var player: Player = Player.new()
	player.sim = sim
	player.auto_input = true

	# W off a rope → jump.
	player.place(_center(Vector2i(7, 9)))
	player._jump_request = false
	player._unhandled_input(_press(Controls.UP))
	_check(player._jump_request, "W off a rope requests a JUMP (Terraria)")

	# W on a rope → NO jump (climbs instead).
	player.place(_center(Vector2i(3, 6)))
	player._jump_request = false
	player._unhandled_input(_press(Controls.UP))
	_check(not player._jump_request, "W on a rope does NOT jump (it climbs)")

	# Space always jumps.
	player.place(_center(Vector2i(7, 9)))
	player._jump_request = false
	player._unhandled_input(_press(Controls.JUMP))
	_check(player._jump_request, "Space jumps")

	# Space jumps OFF a rope too.
	player.place(_center(Vector2i(3, 6)))
	player._jump_request = false
	player._unhandled_input(_press(Controls.JUMP))
	_check(player._jump_request, "Space jumps off a rope")

	player.free()
	if _failures == 0:
		print("CONTROLS OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)


func _press(action: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _center(c: Vector2i) -> Vector2:
	return Vector2(c) * float(CELL) + Vector2(CELL, CELL) * 0.5


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)
