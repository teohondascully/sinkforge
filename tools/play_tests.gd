extends SceneTree

## Layer 6 — the SCRIPTED play-test (a new test TYPE). Instead of poking the sim, a PlayAgent literally
## PLAYS the real game to a GOAL: it walks the real body with real physics and triggers the real reach-
## gated verbs (mine / deposit / craft / build / select), looping until the goal is met or a frame
## budget runs out. A pass means "a person could actually do this from where they're standing" — the
## one guarantee headless sim tests can't give (they bypass the body, reach, and terrain entirely).
##
## Each goal boots a FRESH scene, plays, asserts, tears down. Resource INJECTION (agent.give) is allowed
## to ARRANGE a situation (e.g. top up ingots before a craft goal) — the verb under test stays real.
##
## Run HEADED (the body needs real physics frames):
##   /Applications/Godot.app/Contents/MacOS/Godot --path . --script res://tools/play_tests.gd

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const PROC: String = "res://src/data/machines/processor.tres"

var _failures: int = 0
var _agent: PlayAgent = null  # current agent (for trace on failure)


func _initialize() -> void:
	print("== Sinkforge scripted play-tests ==")
	_run()


func _run() -> void:
	await _goal_find_and_dig_ore()
	await _goal_switch_items()
	await _goal_craft_a_machine()
	await _goal_build_a_machine()
	await _goal_feed_and_smelt()
	if _failures == 0:
		print("ALL PLAY-GOALS MET")
		quit(0)
	else:
		printerr("%d PLAY-GOAL(S) FAILED" % _failures)
		quit(1)


# --- goals ----------------------------------------------------------------------------------------

## The body finds a buried ore vein and digs down to mine it — the core by-hand "go get the ore" loop.
func _goal_find_and_dig_ore() -> void:
	print("- goal: find & dig ore")
	var agent: PlayAgent = await _boot()
	var ore: Vector2i = agent.nearest_material(&"ore")
	if ore.x < 0:
		_check(false, "the world contains an ore vein to find")
		await _teardown(agent)
		return
	var before: int = int(agent.sim.inventory.get(&"ore", 0))
	var dug: bool = await agent.dig_down_to(ore)
	var got: int = int(agent.sim.inventory.get(&"ore", 0)) - before
	_check(dug and got >= 1, "agent dug down to %s and mined ore (got %d)" % [ore, got])
	_teardown(agent)


## The body cycles its pack and lands the active slot on each carried item type — the hotbar select verb.
func _goal_switch_items() -> void:
	print("- goal: switch carried items")
	var agent: PlayAgent = await _boot()
	agent.give(&"ore", 2)
	agent.give(&"ingot", 2)
	var picked_ore: bool = await agent.select_item(&"ore")
	var ore_slot: int = agent.main._inv_selected
	var picked_ingot: bool = await agent.select_item(&"ingot")
	var ingot_slot: int = agent.main._inv_selected
	var slots: Array[Dictionary] = agent.sim.inventory_slots()
	_check(picked_ore and picked_ingot and slots[ore_slot]["item"] == &"ore"
		and slots[ingot_slot]["item"] == &"ingot",
		"agent switched the active slot between ore and ingot")
	_teardown(agent)


## The body crafts a machine item from carried ingots — the Factorio-style craft verb (keys 1/2/3).
func _goal_craft_a_machine() -> void:
	print("- goal: craft a machine")
	var agent: PlayAgent = await _boot()
	agent.give(&"ingot", 3)
	agent.sim.total_produced[&"ingot"] = int(agent.sim.total_produced.get(&"ingot", 0)) + 3
	var proc_def: MachineDef = load(PROC)
	var ok: bool = agent.craft(proc_def)
	_check(ok and int(agent.sim.inventory.get(&"processor", 0)) == 1
		and int(agent.sim.inventory.get(&"ingot", 0)) == 0,
		"agent crafted a processor (spent 3 ingots, gained the item)")
	_teardown(agent)


## The body crafts then PLACES a machine on an open cell within reach — the embodied build verb.
func _goal_build_a_machine() -> void:
	print("- goal: build a machine")
	var agent: PlayAgent = await _boot()
	agent.give(&"ingot", 3)
	agent.sim.total_produced[&"ingot"] = int(agent.sim.total_produced.get(&"ingot", 0)) + 3
	var proc_def: MachineDef = load(PROC)
	agent.craft(proc_def)
	await agent.select_item(&"processor")
	var target: Vector2i = _open_cell_near(agent)
	if target.x < 0:
		_check(false, "found an open cell beside the body to build on")
		await _teardown(agent)
		return
	var built: bool = await agent.build_at(target)
	_check(built and agent.sim.machine_at(target) != null,
		"agent placed a processor at %s and it's there" % target)
	_teardown(agent)


## The body walks to the forge, hand-feeds it ore, and the forge smelts an ingot — the manual feed loop.
func _goal_feed_and_smelt() -> void:
	print("- goal: feed the forge & smelt")
	var agent: PlayAgent = await _boot()
	agent.give(&"ore", 3)
	await agent.select_item(&"ore")
	var forged_before: int = int(agent.sim.total_produced.get(&"ingot", 0))
	var deposited: bool = await agent.deposit_selected()
	for _i: int in 120:                      # let the forge run a few production cycles
		await physics_frame
	var forged: int = int(agent.sim.total_produced.get(&"ingot", 0)) - forged_before
	_check(deposited and forged >= 1,
		"agent fed the forge ore and it smelted an ingot (forged %d)" % forged)
	_teardown(agent)


# --- scaffolding ----------------------------------------------------------------------------------

## Boot a fresh game scene and let the body settle on the ground, then hand back a PlayAgent driving it.
func _boot() -> PlayAgent:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 30:                       # _ready runs on add; let the body fall + land
		await physics_frame
	_agent = AGENT.new(self, main)
	return _agent


func _teardown(agent: PlayAgent) -> void:
	if agent != null and agent.main != null:
		agent.main.queue_free()
	await physics_frame


## An open, placeable cell beside the body (a spot the build verb will accept and reach). Scans the 8
## neighbours of the body's cell for one that's in-bounds, open, unoccupied, and not the body's own cell.
func _open_cell_near(agent: PlayAgent) -> Vector2i:
	var bc: Vector2i = agent.main._cell_at(agent.player.position)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(-1, -1),
			Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0)]:
		var c: Vector2i = bc + d
		if agent.main._placeable(c) and agent.main._can_reach(c):
			return c
	return Vector2i(-1, -1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)
		if _agent != null and not _agent.trace.is_empty():
			for line: String in _agent.trace:
				printerr("        · %s" % line)
