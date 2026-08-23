extends "res://tools/check_base.gd"

## Harness layer 14 — CONTROL-SCHEME context rules (playtest: "W should be jump like Terraria", but W
## must still CLIMB on a rope). Feeds synthetic action events to Player._unhandled_input and checks the
## resulting jump request, so a remap or a movement refactor can't silently break the scheme:
##   - W (Controls.UP) OFF a rope  → requests a JUMP (the Terraria-style feel this targets)
##   - W ON a rope                 → does NOT jump (it climbs)
##   - Space                       → always jumps (incl. off a rope)
##
## #S33 added the other half, from `docs/BAZAAR.md` §7: **R IS ONE VERB.** It used to be two — research, and
## configure-the-machine-you-are-aiming-at — disambiguated by whether the pack screen happened to be open.
## Two jobs on one key is a thing you have to be taught, and the teaching was the tell. Research moved onto
## ENTER at the BENCH tab, where a cursor is already sitting on the rung you would buy and its price is on
## the screen in front of you. So R is asserted from BOTH ends, because a key quietly regaining a second
## meaning is exactly the regression this layer is for: R aimed at a splitter must configure it, and R with
## a researchable rung standing by must leave that rung alone.
## Run: godot --headless --path . --script res://tools/check_controls.gd

const CELL: int = FactorySim.CELL
const SCENE: String = "res://scenes/main.tscn"

var _main: MainView
var _frames: int = 0


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

	# The R case needs the real scene, because "which verb does this key run" is a question about
	# `MainView._unhandled_input` rather than about the body.
	_main = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(_main)
	process_frame.connect(_on_frame)


func _on_frame() -> void:
	_frames += 1
	if _frames < 3:
		return
	process_frame.disconnect(_on_frame)
	_one_verb_r()
	_main.queue_free()
	_verdict("check_controls")


## R DOES ONE THING. Both halves, in the one situation where the old scheme would have run the wrong one:
## a splitter in reach AND a rung the player could afford, with the pack screen shut.
func _one_verb_r() -> void:
	var sim: FactorySim = _main.sim
	var def: MachineDef = load("res://src/data/machines/splitter.tres") as MachineDef
	_check(def != null, "fixture: the splitter def loads")
	if def == null:
		return

	# Clear a pocket beside the body and stand a splitter in it, in reach.
	var home: Vector2i = _main._cell_at(_main._player.position)
	var cell := home + Vector2i(1, 0)
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 4):
			sim.set_solid(home + Vector2i(dx, dy), &"")
	var m: MachineState = sim.place_machine(def, cell)
	_check(m != null and _main._can_reach(cell), "fixture: a splitter stands in reach of the body")
	if m == null:
		return

	# Make research genuinely POSSIBLE, so "R did not research" is a statement about the key rather than
	# about an empty pack. Stand at a Bazaar and carry more than any rung costs.
	for item: StringName in [&"ingot", &"iron_ingot", &"ore", &"coal", &"stone", &"wood", &"plate"]:
		sim.inventory[item] = 99
		sim.total_produced[item] = 99
	var unlocked_before: int = sim.research.size()

	_main._inventory_open = false
	_main._aim = cell
	var mode_before: int = m.mode
	_main._unhandled_input(_press(Controls.RESEARCH))
	_check(m.mode != mode_before,
		"R aimed at a splitter CONFIGURES it (mode %d → %d)" % [mode_before, m.mode])
	_check(sim.research.size() == unlocked_before,
		"…and R researches nothing, ever — that verb lives on ENTER at the BENCH tab now")


func _press(action: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	return e


func _center(c: Vector2i) -> Vector2:
	return Vector2(c) * float(CELL) + Vector2(CELL, CELL) * 0.5
