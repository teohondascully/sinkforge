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
const DRILL: String = "res://src/data/machines/drill.tres"

var _failures: int = 0
var _agent: PlayAgent = null      # current agent
var _last_trace: Array[String] = []  # the failing try's narration, printed only if both tries miss


## Fast-forward the whole suite with the game clock (Engine.time_scale): the body moves proportionally
## more per physics frame, so goals are reached in a fraction of the frames — the play-tests run faster.
## Kept MODERATE: the agent's arrival tolerance is ~3px, so too large a per-frame step overshoots targets
## and the heuristic navigation oscillates. 2x is the MEASURED sweet spot — clean 6/6 at 29s vs 39s at 1x;
## 3x+ overshoots and gets SLOWER (32s) from oscillation, 4x misses goals. (The gain is sub-linear because
## per-goal scene boot/teardown is fixed overhead the clock can't touch.) Override with SINKFORGE_PLAY_SCALE.
const PLAY_TIME_SCALE: float = 2.0

func _initialize() -> void:
	print("== Sinkforge scripted play-tests ==")
	var env: String = OS.get_environment("SINKFORGE_PLAY_SCALE")
	Engine.time_scale = float(env) if env.is_valid_float() and float(env) > 0.0 else PLAY_TIME_SCALE
	print("(game clock: %.0fx)" % Engine.time_scale)
	MainView.dev_start = false      # these goals assert exact counts — boot a CLEAN pack, not the dev kit
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
		["RUNG 1 — reach first automation", _goal_reach_first_automation],
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
		var st: String = _agent.stats() if _agent != null else ""      # behaviour trace, ALWAYS logged
		if met:
			print("  PASS: %s%s   [%s]" % [name, "  (try %d)" % (try_i + 1) if try_i > 0 else "", st])
			return true
		if try_i < TRIES - 1:
			print("  ... missed (try %d/%d)  [%s]; retrying (real-time physics)" % [try_i + 1, TRIES, st])
	if not _last_trace.is_empty():
		for line: String in _last_trace:
			printerr("        · %s" % line)
	printerr("  FAIL: %s (missed twice)  [%s]" % [name, _agent.stats() if _agent != null else ""])
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
	if not await _claim_and_approach_bazaar(agent):
		return await _finish(agent, false, "claimed the Bazaar and stood at it (crafting is gated there)")
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
	if not await _claim_and_approach_bazaar(agent):
		return await _finish(agent, false, "claimed the Bazaar and stood at it (crafting is gated there)")
	var proc_def: MachineDef = load(PROC)
	agent.craft(proc_def)
	await agent.select_item(&"processor")
	var target: Vector2i = _open_cell_near(agent)
	if target.x < 0:
		return await _finish(agent, false, "found an open cell beside the body to build on")
	var built: bool = await agent.build_at(target)
	return await _finish(agent, built and agent.sim.machine_at(target) != null,
		"agent placed a processor at %s and it's there" % target)


## The body stands BESIDE the forge, FACES it, and TOSSES ore into its column (Q) — gravity feeds it in —
## and the forge smelts an ingot. The embodied gravity-feed loop with the forward-toss: you don't deposit,
## you stand next to a machine and fling the stack into its column, where it falls in.
func _goal_feed_and_smelt() -> bool:
	var agent: PlayAgent = await _boot()
	agent.give(&"ore", 3)
	await agent.select_item(&"ore")
	var forge: Vector2i = agent.sim.machines[0].cell
	var forged_before: int = int(agent.sim.total_produced.get(&"ingot", 0))
	# Approach from the left, stand one column left of the forge, and face right INTO its column to toss.
	var beside: bool = await agent.walk_to_column(forge.x - 1)
	agent.player.facing = 1
	var dropped: bool = agent.main.try_drop()                                   # fling it in — gravity feeds it
	for _i: int in 120:                      # let the forge run a few production cycles
		await physics_frame
	var forged: int = int(agent.sim.total_produced.get(&"ingot", 0)) - forged_before
	return await _finish(agent, beside and dropped and forged >= 1,
		"agent stood beside the forge, tossed ore into its column; it fed and smelted (forged %d)" % forged)


## RUNG 1 — the headline integration play-test. Booting with NOTHING, the agent follows the on-screen
## objective ladder (scenes/objectives.gd) step by step, doing ONLY what each signpost says through the
## real reach-gated verbs, and must reach FIRST AUTOMATION: a self-feeding drill→forge line pouring ingots
## on its own. This is "is the game playable to its first goal?" made executable — if any signposted step
## can't be performed from where the player stands, or doing it never advances the chain, it FAILS with
## which step dead-ended. That failure is the "there's nothing to do" complaint, caught by a test.
func _goal_reach_first_automation() -> bool:
	var agent: PlayAgent = await _boot()
	var obj: Objectives = agent.main._objectives
	for step: Dictionary in obj.steps:
		var id: StringName = step["id"]
		if obj.is_done(id):
			continue                                                  # already satisfied — move to the next signpost
		agent._note("step '%s': %s" % [id, step["label"]])
		var acted: bool = await _do_step(agent, id)
		if not acted:
			return await _finish(agent, false, "could NOT perform signposted step '%s' from where the body stands" % id)
		var t: int = 0
		while not obj.is_done(id) and t < 240:                        # give the chain a beat to latch
			await physics_frame
			t += 1
		if not obj.is_done(id):
			return await _finish(agent, false, "did the action for '%s' but the objective never ticked — the player gets no signal they progressed" % id)
	return await _finish(agent, obj.all_done(),
		"followed the signposts all the way to FIRST AUTOMATION (%d steps)" % obj.steps.size())


## Perform the real-verb action a single objective step asks for. Each branch uses only what a player has:
## the body, reach, and the hotbar. Returns whether the action could be carried out at all.
func _do_step(agent: PlayAgent, id: StringName) -> bool:
	match id:
		&"mine":   return await _step_mine(agent)
		&"smelt":  return await _step_smelt(agent)
		&"wood":   return await _step_wood(agent)
		&"bazaar": return await _step_bazaar(agent)
		&"craft":  return await _step_craft(agent)
		&"build":  return await _step_build(agent)
		&"fuel":   return await _step_fuel(agent)
		&"auto":   return await _step_auto(agent)
	return false


## Step 1 — hand-dig the bootstrap ore (4) from the starter vein near spawn, never the mineshaft's vein.
func _step_mine(agent: PlayAgent) -> bool:
	var guard: int = 0
	while int(agent.sim.inventory.get(&"ore", 0)) < 4 and guard < 8:
		guard += 1
		var ore: Vector2i = _nearest_ore_not_shaft(agent)
		if ore.x < 0:
			return false
		await agent.dig_down_to(ore)
	agent._note("  mine: carried ore=%d, produced ore=%d" % [int(agent.sim.inventory.get(&"ore", 0)), int(agent.sim.total_produced.get(&"ore", 0))])
	return int(agent.sim.inventory.get(&"ore", 0)) >= 4


## Step 2 — toss the surface ore into the bootstrap forge pocket (col 46) from beside it (col 45), let it
## smelt, and stand by the pocket to reach-collect the 2 bootstrap ingots.
func _step_smelt(agent: PlayAgent) -> bool:
	if not await agent.select_item(&"ore"):
		return false
	var bf: Vector2i = MainView.MINESHAFT_FORGE_CELL                 # (6, SURFACE) — the bootstrap forge
	if not await agent.walk_to_column(bf.x - 1):                     # stand on the surface beside the forge (col 5)
		return false
	agent.player.facing = 1
	agent.main.try_drop()                                            # fling the ore right into the forge
	var collect: Vector2i = bf + Vector2i(0, 1)                      # (6, SURFACE+1) — where ingots land
	var guard: int = 0
	while int(agent.sim.inventory.get(&"ingot", 0)) < 2 and guard < 30:
		guard += 1
		await agent.approach(collect)                               # stand within reach → auto-collect
		for _i: int in 20:
			await physics_frame
	agent._note("  smelt: produced=%d carried=%d body@%s" % [
		int(agent.sim.total_produced.get(&"ingot", 0)), int(agent.sim.inventory.get(&"ingot", 0)),
		agent.main._cell_at(agent.player.position)])
	return int(agent.sim.inventory.get(&"ingot", 0)) >= 2


## Step 3 — chop a tree for wood (the bazaar's build material). Chop one trunk block of the nearest tree
## (block-by-block now — docs/MINING.md); one wood is enough to claim the bazaar.
func _step_wood(agent: PlayAgent) -> bool:
	var base: Vector2i = _nearest_tree_base(agent)
	if base.x < 0:
		agent._note("  wood: no tree in the world to chop")
		return false
	await agent.mine_cell(base, 1400)        # the tree may be a surface hike from the mineshaft
	agent._note("  wood: produced wood=%d carried=%d" % [
		int(agent.sim.total_produced.get(&"wood", 0)), int(agent.sim.inventory.get(&"wood", 0))])
	return int(agent.sim.inventory.get(&"wood", 0)) >= 1


## Step 4 — claim the Bazaar: place one wood block in the gap of the ruined frame near spawn, completing it.
func _step_bazaar(agent: PlayAgent) -> bool:
	var gap: Vector2i = agent.sim.bazaar_completion_cell()
	if gap.x < 0:
		agent._note("  bazaar: no near-complete ruin to finish")
		return false
	if not await agent.select_item(&"wood"):
		return false
	if not await agent.build_at(gap):
		agent._note("  bazaar: could not place wood at the gap %s" % gap)
		return false
	return not agent.sim.find_bazaars().is_empty()


## Step 5 — craft a Drill AT the Bazaar: walk to the stall (crafting is gated on proximity) and craft.
func _step_craft(agent: PlayAgent) -> bool:
	if not await _walk_to_bazaar(agent):
		agent._note("  craft: could not reach the Bazaar to craft at it")
		return false
	if not agent.craft(load(DRILL)):
		agent._note("  craft: craft refused (near_bazaar=%s ingots=%d)" % [
			agent.main._near_bazaar(), int(agent.sim.inventory.get(&"ingot", 0))])
		return false
	return int(agent.sim.inventory.get(&"drill", 0)) >= 1 or _has_drill(agent)


## Step 4 — drop the Drill above the vein (boring model): the mineshaft has a VISIBLE solid ore vein with an
## OPEN cell above it; place the Drill in that open cell and it bores DOWN into the ore, whose pull falls into
## the forge below. We reach in from the shaft EDGE (col-1) so we never drop into the very cell we're placing.
func _step_build(agent: PlayAgent) -> bool:
	if not await agent.walk_to_column(MainView.MINESHAFT_COL - 1):  # stand on the surface beside the shaft, in reach
		return false
	var d: Vector2i = MainView.MINESHAFT_DRILL_CELL
	if agent.sim.drill_column_remaining(d) <= 0:
		agent._note("  build: no ore vein below the drill cell %s (remaining=%d)" % [
			d, agent.sim.drill_column_remaining(d)])
		return false
	if not await agent.select_item(&"drill"):
		agent._note("  build: no drill in pack (have %d)" % int(agent.sim.inventory.get(&"drill", 0)))
		return false
	if not await agent.build_at(d):                                 # drop the drill above the vein
		agent._note("  build: failed to place drill at %s (reach=%s placeable=%s)" % [
			d, agent.main._can_reach(d), agent.main._placeable(d)])
		return false
	return agent.sim.machine_at(d) != null


## Step 5 — fuel the Drill: mine the coal vein (right of the shaft), then drop coal down the open shaft so
## it lands in the drill (the demand-web — the drill won't pull ore without coal, docs/MINING.md).
func _step_fuel(agent: PlayAgent) -> bool:
	agent._note("  fuel: START body@%s (coal target=%s)" % [
		agent.main._cell_at(agent.player.position), _nearest_coal(agent)])
	var guard: int = 0
	while int(agent.sim.inventory.get(&"coal", 0)) < 3 and guard < 6:
		guard += 1
		var coal: Vector2i = _nearest_coal(agent)
		if coal.x < 0:
			break
		await agent.dig_down_to(coal)
	if int(agent.sim.inventory.get(&"coal", 0)) < 1:
		agent._note("  fuel: no coal mined")
		return false
	if not await agent.select_item(&"coal"):
		return false
	if not await agent.walk_to_column(MainView.MINESHAFT_COL - 1):   # col 7, beside the open shaft
		return false
	agent.player.facing = 1
	var guard2: int = 0
	while not _drill_has_fuel(agent) and guard2 < 14:                # toss coal down the shaft onto the drill
		guard2 += 1
		agent.main.try_drop()
		for _i: int in 6:
			await physics_frame
	agent._note("  fuel: drill_fueled=%s coal_carried=%d" % [
		_drill_has_fuel(agent), int(agent.sim.inventory.get(&"coal", 0))])
	return _drill_has_fuel(agent)


## The nearest COAL vein cell to the body (the drill's fuel source).
func _nearest_coal(agent: PlayAgent) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd: float = INF
	for cell: Variant in agent.sim.solid:
		var c: Vector2i = cell
		if agent.sim.solid[c] != &"coal":
			continue
		var d: float = agent.main._cell_center(c).distance_to(agent.player.position)
		if d < bd:
			bd = d
			best = c
	return best


## Whether a placed Drill has coal to burn (fuel mid-burn, or coal waiting in its buffer).
func _drill_has_fuel(agent: PlayAgent) -> bool:
	for m: MachineState in agent.sim.machines:
		if m.def.behavior == &"drill" and (m.fuel > 0 or int(m.input_buffer.get(&"coal", 0)) > 0):
			return true
	return false


## Step 6 — stand back and let the fueled line run until it pours ingots on its own (no further input).
func _step_auto(agent: PlayAgent) -> bool:
	for _i: int in 200:
		await physics_frame
	return true


## Whether a Drill machine is placed anywhere (the craft step is satisfied by a Drill in pack OR built).
func _has_drill(agent: PlayAgent) -> bool:
	for m: MachineState in agent.sim.machines:
		if m.def.behavior == &"drill":
			return true
	return false


## The base (lowest) trunk cell of the nearest TREE. Identifies a trunk as a WOOD cell crowned by LEAVES
## directly above (which only a real tree-top has — a bazaar frame post has wood or sky above it, never
## leaves), then descends that column to the base. Robust even when a canopy overlaps the frame's columns.
func _nearest_tree_base(agent: PlayAgent) -> Vector2i:
	var top := Vector2i(-1, -1)
	var best_d: float = INF
	for cell: Variant in agent.sim.solid:
		var c: Vector2i = cell
		if agent.sim.solid[c] != &"wood":
			continue
		if agent.sim.solid.get(c + Vector2i(0, -1), &"") != &"leaves":
			continue                                            # not a trunk top — skip frame posts
		var d: float = agent.main._cell_center(c).distance_to(agent.player.position)
		if d < best_d:
			best_d = d
			top = c
	if top.x < 0:
		return Vector2i(-1, -1)
	var base := top
	for cell2: Variant in agent.sim.solid:
		var c2: Vector2i = cell2
		if c2.x == top.x and agent.sim.solid[c2] == &"wood" and c2.y > base.y:
			base = c2
	return base


## Walk the body to within crafting range of a claimed Bazaar (stand on its centre column). Returns whether
## the body ends up near enough to craft. Used by the craft step + the isolated craft/build goals.
func _walk_to_bazaar(agent: PlayAgent) -> bool:
	var bzs: Array[Vector2i] = agent.sim.find_bazaars()
	if bzs.is_empty():
		return false
	# Stand just outside the frame on the RIGHT (spawn/shaft) side — the whole hand-work + shaft lie to its
	# right, so crafting from that side keeps the agent on the working side. (The frame is walk-through now,
	# so this is about staying near the work, not avoiding a wall.) The craft radius reaches the interior.
	await agent.walk_to_column(bzs[0].x + FactorySim.BAZAAR_W)
	return agent.main._near_bazaar()


## Setup hatch for the isolated craft/build goals: claim the seeded ruin with an injected wood block, then
## stand at the stall so crafting is unlocked. (The RUNG-1 goal does this for real via the wood+bazaar steps.)
func _claim_and_approach_bazaar(agent: PlayAgent) -> bool:
	agent.give(&"earth", 8)   # setup: a handful of dirt so the agent can bridge/climb the shaft en route
	var gap: Vector2i = agent.sim.bazaar_completion_cell()
	agent._note("  claim: body@%s gap=%s" % [agent.main._cell_at(agent.player.position), gap])
	if gap.x >= 0:
		agent.give(&"wood", 1)
		agent.sim.total_produced[&"wood"] = int(agent.sim.total_produced.get(&"wood", 0)) + 1  # account the injected block
		if not await agent.select_item(&"wood"):
			return false
		var built: bool = await agent.build_at(gap)
		agent._note("  claim: build_at(gap) -> %s, body now@%s reach=%s placeable=%s" % [
			built, agent.main._cell_at(agent.player.position), agent.main._can_reach(gap), agent.main._placeable(gap)])
		if not built:
			return false
	if agent.sim.find_bazaars().is_empty():
		agent._note("  claim: no bazaar detected after build")
		return false
	var near: bool = await _walk_to_bazaar(agent)
	agent._note("  claim: walk_to_bazaar -> near=%s body@%s" % [near, agent.main._cell_at(agent.player.position)])
	return near


## The nearest solid ORE cell to the body that is NOT in the mineshaft column — so hand-mining the
## bootstrap never eats the vein the automated line will drill.
func _nearest_ore_not_shaft(agent: PlayAgent) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: float = INF
	for cell: Variant in agent.sim.solid:
		var c: Vector2i = cell
		if agent.sim.solid[c] != &"ore" or c.x == MainView.MINESHAFT_COL:
			continue
		var d: float = agent.main._cell_center(c).distance_to(agent.player.position)
		if d < best_d:
			best_d = d
			best = c
	return best


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
