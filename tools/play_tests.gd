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
var _agent: PlayAgent = null      # current agent
var _last_trace: Array[String] = []  # the failing try's narration, printed only if both tries miss


func _initialize() -> void:
	print("== Sinkforge scripted play-tests ==")
	_run()


func _run() -> void:
	# Each goal returns whether it was MET. These run on real-time physics with heuristic navigation, so
	# a single miss can be timing variance, not a broken game — _attempt retries once. A genuine breakage
	# fails BOTH tries; a flake passes on the retry. (Pure-logic guarantees live in the headless suite.)
	for goal: Array in [
		["find & dig ore", _goal_find_and_dig_ore],
		["switch carried items", _goal_switch_items],
		["craft a machine", _goal_craft_a_machine],
		["build a machine", _goal_build_a_machine],
		["feed the forge & smelt", _goal_feed_and_smelt],
	]:
		if not await _attempt(goal[0], goal[1]):
			_failures += 1
	if _failures == 0:
		print("ALL PLAY-GOALS MET")
		quit(0)
	else:
		printerr("%d PLAY-GOAL(S) FAILED" % _failures)
		quit(1)


## Run a goal, retrying up to TRIES times if missed (real-time physics flake guard). Fresh scene each
## try. 3 tries keeps the inherently timing-sensitive goals (walk-there-and-act) reliably green while a
## GENUINE break — which fails deterministically — still fails every try.
const TRIES: int = 3

func _attempt(name: String, fn: Callable) -> bool:
	print("- goal: %s" % name)
	for try_i: int in TRIES:
		var met: bool = await fn.call()
		if met:
			print("  PASS: %s%s" % [name, "  (try %d)" % (try_i + 1) if try_i > 0 else ""])
			return true
		if try_i < TRIES - 1:
			print("  ... missed (try %d/%d); retrying (real-time physics)" % [try_i + 1, TRIES])
	if not _last_trace.is_empty():
		for line: String in _last_trace:
			printerr("        · %s" % line)
	printerr("  FAIL: %s (missed twice)" % name)
	return false


# --- goals ----------------------------------------------------------------------------------------

## The body finds a buried ore vein and digs down to mine it — the core by-hand "go get the ore" loop.
func _goal_find_and_dig_ore() -> bool:
	var agent: PlayAgent = await _boot()
	var ore: Vector2i = agent.nearest_material(&"ore")
	if ore.x < 0:
		return await _finish(agent, false, "the world contains an ore vein to find")
	var before: int = int(agent.sim.inventory.get(&"ore", 0))
	var dug: bool = await agent.dig_down_to(ore)
	var got: int = int(agent.sim.inventory.get(&"ore", 0)) - before
	return await _finish(agent, dug and got >= 1,
		"agent dug down to %s and mined ore (got %d)" % [ore, got])


## The body cycles its pack and lands the active slot on each carried item type — the hotbar select verb.
func _goal_switch_items() -> bool:
	var agent: PlayAgent = await _boot()
	agent.give(&"ore", 2)
	agent.give(&"ingot", 2)
	var picked_ore: bool = await agent.select_item(&"ore")
	var ore_slot: int = agent.main._inv_selected
	var picked_ingot: bool = await agent.select_item(&"ingot")
	var ingot_slot: int = agent.main._inv_selected
	var slots: Array[Dictionary] = agent.sim.inventory_slots()
	return await _finish(agent, picked_ore and picked_ingot and slots[ore_slot]["item"] == &"ore"
		and slots[ingot_slot]["item"] == &"ingot",
		"agent switched the active slot between ore and ingot")


## The body crafts a machine item from carried ingots — the Factorio-style craft verb (keys 1/2/3).
func _goal_craft_a_machine() -> bool:
	var agent: PlayAgent = await _boot()
	agent.give(&"ingot", 3)
	agent.sim.total_produced[&"ingot"] = int(agent.sim.total_produced.get(&"ingot", 0)) + 3
	var proc_def: MachineDef = load(PROC)
	var ok: bool = agent.craft(proc_def)
	return await _finish(agent, ok and int(agent.sim.inventory.get(&"processor", 0)) == 1
		and int(agent.sim.inventory.get(&"ingot", 0)) == 0,
		"agent crafted a processor (spent 3 ingots, gained the item)")


## The body crafts then PLACES a machine on an open cell within reach — the embodied build verb.
func _goal_build_a_machine() -> bool:
	var agent: PlayAgent = await _boot()
	agent.give(&"ingot", 3)
	agent.sim.total_produced[&"ingot"] = int(agent.sim.total_produced.get(&"ingot", 0)) + 3
	var proc_def: MachineDef = load(PROC)
	agent.craft(proc_def)
	await agent.select_item(&"processor")
	var target: Vector2i = _open_cell_near(agent)
	if target.x < 0:
		return await _finish(agent, false, "found an open cell beside the body to build on")
	var built: bool = await agent.build_at(target)
	return await _finish(agent, built and agent.sim.machine_at(target) != null,
		"agent placed a processor at %s and it's there" % target)


## The body walks to the forge, hand-feeds it ore, and the forge smelts an ingot — the manual feed loop.
func _goal_feed_and_smelt() -> bool:
	var agent: PlayAgent = await _boot()
	agent.give(&"ore", 3)
	await agent.select_item(&"ore")
	var forged_before: int = int(agent.sim.total_produced.get(&"ingot", 0))
	var deposited: bool = await agent.deposit_selected()
	for _i: int in 120:                      # let the forge run a few production cycles
		await physics_frame
	var forged: int = int(agent.sim.total_produced.get(&"ingot", 0)) - forged_before
	return await _finish(agent, deposited and forged >= 1,
		"agent fed the forge ore and it smelted an ingot (forged %d)" % forged)


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


## Record this try's verdict, tear the scene down, and return whether the goal was met. On a miss it
## stashes the agent's trace + the label so _attempt can print them if BOTH tries fail.
func _finish(agent: PlayAgent, ok: bool, label: String) -> bool:
	if not ok:
		_last_trace = agent.trace.duplicate()
		_last_trace.append(label)
	await _teardown(agent)
	return ok
