extends SceneTree

## Layer 6: the DRIVEN play-test (a distinct test TYPE). Instead of poking the sim, a PlayAgent literally
## PLAYS the real game to a GOAL: it walks the real body with real physics and triggers the real reach-
## gated verbs (mine / deposit / craft / build / select), looping until the goal is met or a frame
## budget runs out. A pass means "a person could actually do this from where they're standing": the
## one guarantee headless sim tests can't give (they bypass the body, reach, and terrain entirely).
##
## Each goal boots a FRESH scene, plays, asserts, tears down. Resource INJECTION (agent.give) is allowed
## to ARRANGE a situation (e.g. top up ingots before a craft goal); the verb under test stays real.
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
## more per physics frame, so goals are reached in a fraction of the frames; the play-tests run faster.
## Kept MODERATE: the agent's arrival tolerance is ~3px, so too large a per-frame step overshoots targets
## and the heuristic navigation oscillates. 2x is the MEASURED sweet spot: clean 6/6 at 29s vs 39s at 1x;
## 3x+ overshoots and gets SLOWER (32s) from oscillation, 4x misses goals. (The gain is sub-linear because
## per-goal scene boot/teardown is fixed overhead the clock can't touch.) Override with SINKFORGE_PLAY_SCALE.
const PLAY_TIME_SCALE: float = 2.0

## The harness's SKIP code. A subset run exits with it rather than 0, so that running four goals can never
## be filed alongside running all of them. See run_harness.sh: 42 buys the SKIP state only together with a
## line saying why, which `_run` prints.
const SKIP: int = 42

## Run only the goals whose name contains this, case-insensitively. For working on one rung without paying
## for the other sixteen, and for sweeping one rung across a seed corpus. DEFAULT EMPTY: unset, everything
## runs, which is the only thing CI may do. A subset run is announced in the banner and exits SKIP.
var _only: String = ""
## Goals `_only` filtered out, by name, so the skip line can list what did not run rather than count it.
var _skipped: Array[String] = []
## Goals that did run, so the skip line's denominator is a fact and not a maintained constant.
var _ran_count: int = 0


func _initialize() -> void:
	print("== Sinkforge driven play-tests ==")
	var env: String = OS.get_environment("SINKFORGE_PLAY_SCALE")
	Engine.time_scale = float(env) if env.is_valid_float() and float(env) > 0.0 else PLAY_TIME_SCALE
	_only = OS.get_environment("SF_PLAY_ONLY").strip_edges()
	# WHICH WORLD THIS RAN IN, in the header of every log. These goals walk real generated terrain, so a
	# result is a statement about a seed and not about the game until the seed is written next to it. The
	# suite has been reporting pass/fail for a long time without ever saying which world produced it.
	print("(game clock: %.0fx, world seed %d)" % [Engine.time_scale, MainView.default_seed()])
	MainView.dev_start = false      # these goals assert exact counts — boot a CLEAN pack, not the dev kit
	_run()


func _run() -> void:
	# Each goal returns whether it was MET. These run on real-time physics with heuristic navigation, so a
	# single miss can be timing variance rather than a broken game, and `_attempt` retries up to TRIES
	# times. A genuine breakage fails EVERY try; a flake passes on one of the retries. (Pure-logic
	# guarantees live in the headless suite.)
	for goal: Array in [
		["find & dig ore", _goal_find_and_dig_ore],
		["switch carried items", _goal_switch_items],
		["craft a machine", _goal_craft_a_machine],
		["build a machine", _goal_build_a_machine],
		["feed the forge & smelt", _goal_feed_and_smelt],
		["RUNG 1 — reach first automation", _goal_reach_first_automation],
		["RUNG 2 — breach the seal into L2", _goal_breach_the_seal],
		["RUNG 3 — the L2 iron chain", _goal_l2_chain],
		# The crossing RUNG 3 used to make on its way to a build site, now asked for by name. It is a
		# separate property from the chain and it is measured on ground no fixture has touched.
		["traversal: cross the open ground to the far site", _goal_cross_to_the_far_site],
		["RUNG 4 — the Borer ferret loop", _goal_borer],
		["RUNG 5 — drain the aquifer (L3 flood loop)", _goal_drain_the_aquifer],
		["RUNG 6 — breach a worldgen aquifer (real descent)", _goal_breach_worldgen_aquifer],
		["RUNG 7 — pump out a worldgen aquifer (full L3 loop)", _goal_pump_out_a_worldgen_aquifer],
		# FRICTION journeys: the BYPRODUCT experiences a real player MUST go through (the descent, and above
		# all the climb back UP), measured for effort, not just did-it-happen. These are where the game earns
		# "fun & frictionless" or fails it. A FAIL here = the player gets trapped / the loop is exhausting.
		["friction: round-trip to a buried vein", _goal_round_trip_to_vein],
		["friction: descend, build a drill, climb out", _goal_descend_build_return],
		["friction: escape a deep pit (not trapped)", _goal_escape_deep_pit],
		["friction: cross a jagged tunnel", _goal_cross_jagged_tunnel],
		["friction: haul a pack that actually fills", _goal_haul_a_capped_pack],
		["friction: what a hand leaves behind", _goal_hand_leaves_the_vein],
		["friction: trips to clear a face", _goal_trips_to_clear_a_face],
	]:
		var goal_name: String = goal[0]
		if _only != "" and not goal_name.to_lower().contains(_only.to_lower()):
			_skipped.append(goal_name)
			continue
		_ran_count += 1
		if not await _attempt(goal_name, goal[1]):
			_failures += 1
	if _failures > 0:
		printerr("%d PLAY-GOAL(S) FAILED" % _failures)
		quit(1)
		return
	# A SUBSET RUN IS NOT A SWEEP, AND IT MAY NOT EXIT LIKE ONE. `SF_PLAY_ONLY` is here so one rung can be
	# worked on, or swept across a seed corpus, without paying for the other sixteen — and the moment such a
	# thing exists, the next hazard is a green line in a log that ran four goals. So it exits on the
	# harness's SKIP contract instead of 0: exit 42 plus a line saying why, which the runner reports as SKIP
	# and strict mode refuses to count as a pass.
	if not _skipped.is_empty():
		print("play-tests: SKIP — subset run (SF_PLAY_ONLY=%s): %d of %d goals were not run"
			% [_only, _skipped.size(), _skipped.size() + _ran_count])
		printerr("play-tests: THIS WAS NOT A FULL SWEEP. Not run: %s" % ", ".join(_skipped))
		quit(SKIP)
		return
	print("ALL PLAY-GOALS MET")
	quit(0)


## Run a goal, retrying up to TRIES times if missed (real-time physics flake guard). Fresh scene each
## try. 3 tries keeps the inherently timing-sensitive goals (walk-there-and-act) reliably green while a
## GENUINE break, which fails deterministically, still fails every try.
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

## The body finds a buried ore vein and digs down to mine it: the core by-hand "go get the ore" loop.
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


## The body cycles its pack and lands the active slot on each carried item type: the hotbar select verb.
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


## The body crafts a machine item from carried ingots: the Factorio-style craft verb (keys 1/2/3).
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


## The body crafts then PLACES a machine on an open cell within reach: the embodied build verb.
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


## The body stands BESIDE the forge, FACES it, and TOSSES ore into its column (Q) so gravity feeds it in,
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


## RUNG 1: the headline integration play-test. Booting with NOTHING, the agent follows the on-screen
## objective ladder (scenes/objectives.gd) step by step, doing ONLY what each signpost says through the
## real reach-gated verbs, and must reach FIRST AUTOMATION: a self-feeding drill→forge line pouring ingots
## on its own. This is "is the game playable to its first goal?" made executable: if any signposted step
## can't be performed from where the player stands, or doing it never advances the chain, it FAILS with
## which step dead-ended. That failure is the "there's nothing to do" complaint, caught by a test.
func _goal_reach_first_automation() -> bool:
	var agent: PlayAgent = await _boot()
	var obj: Objectives = agent.main._objectives
	# This rung's goal is FIRST AUTOMATION, the tutorial ladder up to and including "auto". The steps AFTER
	# it (power/generator/descent/breach) are the gentle L1→L2 handoff, whose journey RUNG 2 plays end-to-end;
	# stop once "auto" latches so this rung stays scoped to what it asserts (and its verbs).
	for step: Dictionary in obj.steps:
		var id: StringName = step["id"]
		if obj.is_done(id):
			if id == &"auto":
				break                                                 # first automation reached — this rung's goal
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
		if id == &"auto":
			break                                                     # first automation reached — this rung's goal
	return await _finish(agent, obj.is_done(&"auto"),
		"followed the signposts all the way to FIRST AUTOMATION")


## RUNG 2. The L1→L2 GATE is playable end-to-end (docs/PROGRESSION.md §2): descend a shaft to THE SEAL,
## stand a Descent Engine ON it, climb out, FEED it by tossing ingots down the shaft (gravity is the
## feeder; the hook working as the gate's conveyor), watch the BREACH open, drop through into
## Stonereach, mine an IRON sample (the new material), and climb all the way home. Research/crafting the
## engine are proven by the headless suite + RUNG 1's bench flow; the setup hatch supplies the loadout so
## THIS goal measures the gate journey itself.
func _goal_breach_the_seal() -> bool:
	var agent: PlayAgent = await _boot()
	var sim: FactorySim = agent.sim
	var col: int = 70                                        # clear of every other fixture (they end at 64)
	var top: int = mini(sim.surface_row(col), sim.surface_row(col + 1))
	# A pre-dug 2-wide access shaft down to the seal's face (digging is the round-trip journeys' business).
	for x: int in [col, col + 1]:
		for y: int in range(top, LayeredWorldGen.SEAL_TOP):
			sim.set_solid(Vector2i(x, y), &"")
	sim.set_solid(Vector2i(col + 1, LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS), &"iron")
	sim.deposits[Vector2i(col + 1, LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS)] = 40
	agent.give(&"rope", 250)                                 # BOTH ~36-row shafts want a full hang each, plus
	                                                         # exit-cycle re-anchors; rope economy isn't what
	                                                         # this goal measures, the GATE is
	sim.place_rope(Vector2i(col, top - 1))                   # the way back up, hung at the mouth
	agent.give(&"descent_engine", 1)
	agent.give(&"stone_pickaxe", 1)                          # iron is tier-2 rock
	agent.give(&"ingot", FactorySim.DESCENT_QUOTA + 4)
	sim.research[&"automation"] = true                       # setup hatch: the bench flow is proven elsewhere
	sim.research[&"power"] = true
	sim.research[&"descent"] = true
	# 1. DESCEND: walk over the shaft mouth and let gravity take you to the seal floor.
	if not await agent.walk_to_column(col, 1800):
		return await _finish(agent, false, "never reached the seal floor down the access shaft")
	var seal_floor := Vector2i(col, LayeredWorldGen.SEAL_TOP - 1)
	if agent.main._cell_at(agent.player.position).y < seal_floor.y - 1:
		return await _finish(agent, false, "stopped short of the seal floor")
	# 2. Stand the ENGINE on the seal, in the neighbour column (your own column holds the climb rope).
	if not await agent.select_item(&"descent_engine"):
		return await _finish(agent, false, "no engine in the pack")
	if not await agent.build_at(Vector2i(col + 1, LayeredWorldGen.SEAL_TOP - 1)):
		return await _finish(agent, false, "could not stand the engine on the seal")
	# 3. Climb home, then FEED the gate from the surface: toss the ingots down its shaft. (Home = the
	# mouth row `top`, not top-1; the neighbouring ground can naturally sit a row lower than the mouth.)
	if not await agent.climb_to_surface(top):
		return await _finish(agent, false, "could not climb back out before feeding")
	if not await agent.walk_to_column(col + 2, 900):
		return await _finish(agent, false, "could not stand at the shaft mouth to feed")
	if not await agent.select_item(&"ingot"):
		return await _finish(agent, false, "no ingots to feed")
	agent.player.facing = -1                                 # face the shaft; the toss arcs the stack in
	agent.main.try_drop()
	var breach := Vector2i(col + 1, LayeredWorldGen.SEAL_TOP)
	var t: int = 0
	while sim.is_solid(breach) and t < 600:
		await agent.step(); t += 1
	if sim.is_solid(breach):
		return await _finish(agent, false, "fed the engine but the seal never breached (fed=%d)" % _engine_fed(agent))
	agent._note("  BREACH after %d frames" % t)
	# 4. Down again: reclaim the engine (RMB), step into the bored shaft, drop into STONEREACH.
	if not await agent.walk_to_column(col, 900):
		return await _finish(agent, false, "could not descend again after the breach")
	if not await agent.build_at(Vector2i(col + 1, LayeredWorldGen.SEAL_TOP - 1)):
		return await _finish(agent, false, "could not reclaim the engine off the seal")
	if not await agent.walk_to_column(col + 1, 600):
		return await _finish(agent, false, "could not drop through the breach into L2")
	# 5. The prize: mine the IRON under your feet, the first touch of L2's new material.
	var iron := Vector2i(col + 1, LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS)
	var g: int = 0
	while sim.is_solid(iron) and g < 40:
		agent.do_mine(iron)
		await agent.wait(4); g += 1
	if int(sim.inventory.get(&"iron", 0)) < 1:
		return await _finish(agent, false, "stood in L2 but could not mine the iron")
	# 6. And home: the whole loop closes on the surface.
	var home: bool = await agent.climb_to_surface(top, 6000)
	print("  gate: %s  (iron=%d home=%s)" % [agent.friction(), int(sim.inventory.get(&"iron", 0)), home])
	return await _finish(agent, home, "breached the seal, mined L2 iron, and returned to the surface")


func _engine_fed(agent: PlayAgent) -> int:
	for m: MachineState in agent.sim.machines:
		if m.def.behavior == &"descent":
			return m.fed
	return -1


## RUNG 4. The BORER is playable embodied: dig a socket at a rock face, stand the
## Borer in it facing the wall, feed it coal by toss, let it chew the face into its belly (it sits
## sealed; the on-hook rule pools the haul), then PICK IT BACK UP and walk away with the haul in the
## pack (pickup salvages buffers). The manual "send the ferret into the wall, bring it back full"
## loop, all through real verbs.
## The furthest column toward `pref` that the body can actually WALK to from `from`, and that is worth
## building a fixture on when it gets there.
##
## Two conditions, and it took both. The ground has to be FOOTED: a column can be perfectly level on top
## and open into a rift two cells down, which is level ground you cannot dig a two-deep socket into,
## because the second cut drops the body through the floor and out of its own reach. And it has to be
## REACHABLE, because the generator now cuts sinkhole mouths and a forty-row hole between here and there
## is a wall, however good the ground looks on the far side of it.
func _standing_ground(sim: FactorySim, from: int, pref: int) -> int:
	var dir: int = 1 if pref >= from else -1
	var best: int = from
	var c: int = from
	while c != pref:
		var n: int = c + dir
		if n < 2 or n >= FactorySim.GRID_COLS - 2:
			break
		if absi(sim.surface_row(n) - sim.surface_row(c)) > 1:
			break                                            # a cliff — the body cannot walk past it
		c = n
		if _footed(sim, c):
			best = c
	return best


## Solid rock for a socket's depth under this column's surface.
func _footed(sim: FactorySim, col: int) -> bool:
	var top: int = sim.surface_row(col)
	if top > Strata.SURFACE_ROW + 8:
		return false                                         # the floor of a hole, not the ground
	for k: int in range(1, 7):
		if not sim.is_solid(Vector2i(col, top + k)):
			return false
	return true


func _goal_borer() -> bool:
	var agent: PlayAgent = await _boot()
	var sim: FactorySim = agent.sim
	# Clear of every fixture, and clear of the generator's sinkholes, which are the one thing that can put
	# a forty-row hole where a hardcoded column expected a hillside. Ask for solid walkable ground near the
	# spot rather than asserting the world still has some there.
	var col: int = _standing_ground(sim, agent.main._cell_at(agent.player.position).x, 84)
	for t: StringName in ResearchRules.ORDER:                # setup hatch — the bench flow is proven elsewhere
		sim.research[t] = true
	agent.give(&"h_drill", 1)
	agent.give(&"coal", 4)
	if not await agent.walk_to_column(col, 1600):
		return await _finish(agent, false, "never reached the rock face")
	var top: int = sim.surface_row(col)
	for x: int in range(col + 1, col + 5):
		sim.set_solid(Vector2i(x, top + 1), &"earth")        # a guaranteed face at socket depth
	# Dig the 2-deep socket riding down (straight-below cuts), then jump out to its lip.
	for y: int in range(top, top + 2):
		var cell := Vector2i(col, y)
		var g: int = 0
		while sim.is_solid(cell) and g < 40:
			agent.do_mine(cell)
			await agent.wait(4); g += 1
		if sim.is_solid(cell):
			return await _finish(agent, false, "could not dig the borer socket at %s" % str(cell))
		await agent.wait(20)
	if not await agent.walk_to_column(col - 1, 900):
		return await _finish(agent, false, "could not jump out of the socket")
	# Stand the Borer at the socket bottom FACING the wall, then toss its coal in.
	if not await agent.select_item(&"h_drill"):
		return await _finish(agent, false, "no borer in the pack")
	agent.player.facing = 1                                  # it bores the way YOU face when placing
	if not await agent.build_at(Vector2i(col, top + 1)):
		return await _finish(agent, false, "could not stand the borer in the socket")
	if not await agent.select_item(&"coal"):
		return await _finish(agent, false, "no coal to feed it")
	agent.player.facing = 1
	agent.main.try_drop()
	# It chews the face into its belly (sealed below; the haul POOLS, nothing spills).
	var t2: int = 0
	var borer: MachineState = sim.machine_at(Vector2i(col, top + 1))
	if borer == null or borer.facing != 1:
		return await _finish(agent, false, "the borer did not take the builder's facing")
	while int(borer.output_buffer.get(&"earth", 0)) < 3 and t2 < 1800:
		await agent.step(); t2 += 1
	if int(borer.output_buffer.get(&"earth", 0)) < 3:
		return await _finish(agent, false, "the borer never filled its belly (bellied %d)"
			% int(borer.output_buffer.get(&"earth", 0)))
	# Bring the ferret home: pick it up; the salvage lands its belly in YOUR pack.
	if not await agent.build_at(Vector2i(col, top + 1)):
		return await _finish(agent, false, "could not reclaim the borer")
	var haul: int = int(sim.inventory.get(&"earth", 0))
	print("  borer: %s  (haul=%d frames=%d)" % [agent.friction(), haul, t2])
	return await _finish(agent, haul >= 3 and int(sim.inventory.get(&"h_drill", 0)) == 1,
		"sent the borer into the wall and brought it back full (haul=%d)" % haul)


## RUNG 5. The L3 FLOOD LOOP is playable embodied (the Aquifer answer): the pump falls
## on the LOCKED hook: water floods a dig for FREE, pumping it back OUT costs POWER. The sim tests prove
## water/pump/reward in ISOLATION; this proves a PLAYER can actually DO it from where a body stands. In a
## STAGED, SEALED, flooded surface pocket (a flat-floored watertight box with a pump sump, reachable
## without the descent-and-climb, which is RUNG 2's business), the agent: (1) WADES the flood and feels the
## impedance (_in_water); (2) builds a POWERED pump: stands a fueled generator up in the walk-space, lays a
## conduit run that carries its power over to beside the pump's cell, and drops the pump into the sump;
## (3) stands back while the powered pump DRAINS the pocket substantially; (4) walks to the now-exposed
## rich_ore in the drained floor and mines it. Any step unreachable/unbuildable through the real verbs FAILS
## with which one dead-ended; an L3 reachability gap made executable (this rung caught one: see step 2).
func _goal_drain_the_aquifer() -> bool:
	var agent: PlayAgent = await _boot()
	var sim: FactorySim = agent.sim
	var col: int = 90                                        # clear of every fixture (they end at 84)
	var r: int = MainView.SURFACE
	# --- STAGE a flooded surface PUDDLE, carved clean + placed by hand (the RUNG-fixture pattern) so the
	# geometry is deterministic run-to-run AND the whole loop sits within a standing body's reach, with NO
	# descent-and-climb (that's RUNG 2's business). The floor is CONTINUOUS at row r+1 (the body walks along
	# it standing at row r); the water sits in a shallow puddle IN the body's own standing row (row r),
	# penned by 1-tile lips, so the body wades by simply walking THROUGH it and out onto dry ground: no pit
	# to escape, no reliance on a lucky wading jump. A 1-cell SUMP under the puddle gives the pump depth. ---
	# FIRST wipe the whole fixture footprint clean (worldgen at col 90 is past the flat plateau; its
	# undulating surface + any seeded aquifer here would sit UNDER the stamp and lift the body / add stray
	# water), then SEAL the box: fill everything at/below the walk floor solid (a watertight bed) and wall
	# the box's left/right edges. This pens the puddle so a neighbouring worldgen aquifer can't leak in and
	# dilute it: the drain measured is this pump's alone. Rows above the floor stay open (walk-space).
	var box_lo_x: int = col - 10
	var box_hi_x: int = col + 7
	for x: int in range(box_lo_x, box_hi_x + 1):
		for y: int in range(r - 5, r + 6):
			var c := Vector2i(x, y)
			sim.remove_water(c, FactorySim.WATER_MAX)
			if y >= r + 1 or x == box_lo_x or x == box_hi_x:
				sim.set_solid(c, &"stone")                  # the watertight bed + the two edge walls
			else:
				sim.set_solid(c, &"")                       # open walk-space above the floor
	# The continuous walk floor is now the top of the solid bed (row r+1). Open a SUMP under the puddle centre
	# so the pump has drain depth: a 2-cell shaft (col r+1, r+2) above the solid sump floor at r+3. The floor
	# is otherwise UNBROKEN and FLAT (no surface lips); the body wades the whole span freely (wading is just
	# slower, never blocking), so there's no lip to trip on and no pit to escape while impeded.
	sim.set_solid(Vector2i(col, r + 1), &"")
	sim.set_solid(Vector2i(col, r + 2), &"")
	# THE REWARD: a rich_ore vein in the walk floor two cells left of the pump, submerged now, mineable dry
	# once the pump exposes it. On the build side of the pump so the body never has to cross the pump (a
	# machine walls the body) to reach it. rich_ore is tier-2 rock, so the loadout carries a stone pickaxe.
	var reward := Vector2i(col - 2, r + 1)
	sim.set_solid(reward, &"rich_ore")
	sim.deposits[reward] = 20
	# Flood the sealed box: pour brim-full into row r across the build span + the sump. Water levels out over
	# the connected interior (penned by the box's edge walls), settling deep enough to wade across. pocket_cells
	# = every cell that can hold this pocket's water, so the drain check reads THIS pocket alone (not the
	# world's far-off worldgen aquifers, which sit outside the sealed box).
	var pocket_cells: Array[Vector2i] = []
	for x: int in range(box_lo_x + 1, box_hi_x):
		pocket_cells.append(Vector2i(x, r))                 # the whole interior standing row
	pocket_cells.append(Vector2i(col, r + 1))               # + the sump
	pocket_cells.append(Vector2i(col, r + 2))
	var poured: int = 0
	for wet_cell: Vector2i in pocket_cells:
		poured += sim.add_water(wet_cell, FactorySim.WATER_MAX)
	if poured < FactorySim.WATER_MAX * 8:
		return await _finish(agent, false, "the pocket should start deeply flooded (poured=%d)" % poured)
	# The loadout (setup hatch; the bench/craft flow is proven in RUNG 1 + headless): a pump, a fueled
	# generator, a run of conduit to wire them, and the tier-2 pick the rich_ore needs.
	agent.give(&"pump", 1)
	agent.give(&"generator", 1)
	agent.give(&"conduit", 8)
	agent.give(&"stone_pickaxe", 1)
	# Set the body down on the flooded floor at the build end; it settles into the shallow flood.
	agent.player.position = agent.main._cell_center(Vector2i(col - 5, r))
	for _i: int in 20:
		await physics_frame                                 # settle onto the floor
	# --- STEP 1: the flood is a real hazard. Standing in the flooded pocket, the body WADES (impedance
	# registers). Confirm the wading gate trips (the body slogs, doesn't stroll). ---
	var waded: bool = false
	for _i: int in 60:
		await physics_frame
		if agent.player._in_water():
			waded = true
			break
	if not waded:
		return await _finish(agent, false, "stood in the flooded pocket but the body never registered as wading (_in_water false)")
	agent._note("  wading: body in water at %s" % agent.main._cell_at(agent.player.position))
	# --- STEP 2: build the powered pump. Standing back at the build end, the body stands the generator up in
	# the walk-space, lays a conduit run along row r-1 that ends orthogonally BESIDE the pump, and drops the
	# pump into the flooded sump. Power routes gen → the conduit below it → across the run → bleeds into the
	# pump's cell (the "generator far, conduit delivers" geometry; the conduit is load-bearing, asserted
	# below). Every placement goes through build_at on reach-valid cells; the flat flooded floor is trivially
	# navigable (wading only slows the body, never blocks) and the body stays clear of the open sump. ---
	if not await agent.walk_to_column(col - 5, 1200):
		return await _finish(agent, false, "could not reach the build end of the pocket")
	var gen_cell := Vector2i(col - 4, r - 2)                 # the generator, up in the walk-space
	if not await agent.select_item(&"generator"):
		return await _finish(agent, false, "no generator in the pack")
	if not await agent.build_at(gen_cell):
		return await _finish(agent, false, "could not stand the generator at %s" % str(gen_cell))
	# Fuel it by hand-loading its buffer (feeding coal by toss is RUNG-1's proven verb; here the POWER
	# WIRING is what's under test, so the fuel is hatched; the generator must actually burn to power the pump).
	var gen: MachineState = sim.machine_at(gen_cell)
	if gen == null:
		return await _finish(agent, false, "the generator vanished after placement")
	gen.input_buffer[&"coal"] = 60
	sim.total_produced[&"coal"] = int(sim.total_produced.get(&"coal", 0)) + 60
	# The conduit run: it starts DIRECTLY UNDER the generator (which feeds its full output down into it), runs
	# right along row r-1, then drops one cell to (col-1, r), orthogonally BESIDE the pump, so its power
	# bleeds sideways into the pump's cell. (The body builds this walking the flat flooded floor; it never has
	# to stand over the open sump.) All r-1 cells + (col-1,r) are open, so every tube is placeable.
	var conduit_cells: Array[Vector2i] = [Vector2i(col - 4, r - 1), Vector2i(col - 3, r - 1),
			Vector2i(col - 2, r - 1), Vector2i(col - 1, r - 1), Vector2i(col - 1, r)]
	if not await agent.select_item(&"conduit"):
		return await _finish(agent, false, "no conduit in the pack")
	for cc: Vector2i in conduit_cells:
		if not await agent.build_at(cc):
			return await _finish(agent, false, "could not lay a power conduit at %s" % str(cc))
		if not sim.has_conduit(cc):
			return await _finish(agent, false, "the conduit did not land at %s" % str(cc))
	# The pump goes in the puddle centre over the sump (col, r): its own cell + the sump below are water; the
	# conduit beside it (col-1, r) bleeds its power in. Reach in from col-2 on the dry-ish left so the body
	# never stands over the open sump (which it would fall into).
	var pump_cell := Vector2i(col, r)
	if not await agent.select_item(&"pump"):
		return await _finish(agent, false, "no pump in the pack")
	if not await agent.walk_to_column(col - 2, 900):
		return await _finish(agent, false, "could not stand beside the puddle to place the pump")
	if not agent.main.try_build(pump_cell):                  # reach in from col-2 (in range, off the sump)
		# If the cell is reach-valid + placeable but the build still refuses, the pump ISN'T a resolvable
		# placeable machine: the L3 REACHABILITY GAP this rung exists to catch. The pump has a .tres, a sim
		# behavior, a Visuals glyph, and a research unlock (ResearchRules "drainage"), but is MISSING from
		# MainView._craftable (scenes/main.gd ~L177), the one list that feeds both the craft menu (craft_ids)
		# AND the item→def resolver (_machine_defs_by_id) used to PLACE it. So a player who researches
		# Drainage still cannot craft OR place a pump: the whole L3 flood-defeat loop is unreachable. FIX =
		# add `load("res://src/data/machines/pump.tres")` to _craftable. (Verified: with the pump registered,
		# this rung drives the full loop green: wade → power → drain → mine.)
		var reachable: bool = agent.main._can_reach(pump_cell)
		var placeable: bool = agent.main._placeable(pump_cell)
		var resolves: bool = agent.main._machine_defs_by_id.has(&"pump")
		return await _finish(agent, false,
			"could not place the pump at %s [reach=%s placeable=%s resolves-to-def=%s] — the pump is not a placeable machine: add pump.tres to MainView._craftable (scenes/main.gd)"
				% [str(pump_cell), reachable, placeable, resolves])
	# --- STEP 3: warm the generator, confirm power reaches the pump, then let it DRAIN. ---
	for _i: int in 6:
		await agent.step()                                  # a few ticks for the generator to warm + power to flood
	if sim.power_at(pump_cell) <= 0.0:
		return await _finish(agent, false,
			"the pump is placed but no power reaches its cell (power=%.2f) — the conduit wiring didn't deliver" % sim.power_at(pump_cell))
	# Read THIS pocket's water level (the sum over its cells) so a far-off worldgen aquifer can't mask the drain.
	var pocket_water := func() -> int:
		var s: int = 0
		for pc: Vector2i in pocket_cells:
			s += sim.water_at(pc)
		return s
	var water_before: int = pocket_water.call()
	var t: int = 0
	while pocket_water.call() > water_before / 4 and t < 900:  # generous budget: the powered pump chews it down
		await agent.step(); t += 1
	var water_after: int = pocket_water.call()
	agent._note("  drain: water %d -> %d over %d frames (pump power=%.2f)" % [water_before, water_after, t, sim.power_at(pump_cell)])
	if water_after >= water_before:
		return await _finish(agent, false, "the powered pump never drained the flood (%d -> %d)" % [water_before, water_after])
	if water_after > water_before / 2:
		return await _finish(agent, false, "the pump barely touched the flood (%d -> %d) — not substantially drained" % [water_before, water_after])
	# --- STEP 4: the prize. The rich_ore in the drained floor (2 cells left of the pump) is now exposed;
	# walk onto it and mine it dry (it sits directly under the body's feet there, in reach). ---
	if not await agent.select_item(&"stone_pickaxe"):
		return await _finish(agent, false, "no pickaxe to mine the reward")
	if not await agent.walk_to_column(reward.x, 1200):     # stand over the now-drained reward cell
		return await _finish(agent, false, "could not return to the drained reward cell")
	var g: int = 0
	while sim.is_solid(reward) and g < 60:
		agent.do_mine(reward)
		await agent.wait(4); g += 1
	var got: int = int(sim.inventory.get(&"rich_ore", 0))
	print("  aquifer: %s  (water %d->%d, rich_ore=%d)" % [agent.friction(), water_before, water_after, got])
	return await _finish(agent, got >= 1,
		"waded the flood, built a powered pump, drained the pocket (%d->%d), and mined the exposed rich_ore (%d)"
			% [water_before, water_after, got])


## RUNG 6. BREACH A REAL WORLDGEN AQUIFER (the L3 loop on the SHIPPING WORLD): RUNG 5 proved the flood
## loop on a hand-staged surface puddle; this proves the world worldgen actually SHIPS is playable: a body
## DESCENDS into the deep, digs into a genuine sealed worldgen aquifer, and breaching it RELEASES the flood
## AND yields the rich_ore treasure lining it (the risk/reward, #126). The aquifer is DISCOVERED dynamically
## (scan sim.water for a deep, substantial, treasure-lined pocket), so the rung guards WORLDGEN too: a gen
## retune that stops shipping breachable, treasure-lined aquifers at depth fails here. The breach is ONE
## honest cut, a rim rich_ore cell at the waterline, that CLAIMS the treasure and OPENS the seal in a single
## move, after which the released flood pours laterally into the dig (the body wades). Setup hatch (RUNG-3's
## "guarantee the site"): the descent column is made solid + a foothold set at the breach level, so a worldgen
## cave in the shaft can't drop the body out of reach mid-dig; the DESCENT dig, the BREACH cut, and the flood
## are all real. The pump-drain claim is RUNG 5's business; this rung's novelty is descent + breach + release.
func _goal_breach_worldgen_aquifer() -> bool:
	var agent: PlayAgent = await _boot()
	var sim: FactorySim = agent.sim
	# The deep band AND its rich_ore both need a tier-2 pick (MiningRules); hand it (the craft is proven in
	# RUNG 1); the descent dig, the breach cut, and the claim are what's under test.
	agent.give(&"stone_pickaxe", 1)

	# --- FIND a real worldgen aquifer to breach: the shallowest pocket that is DEEP (in the aquifer band),
	# SUBSTANTIAL, and TREASURE-LINED, with a rim rich_ore cell sitting horizontally between pocket water and
	# OUTSIDE solid rock, so one sideways cut claims the ore AND opens the seal. Dynamic = a worldgen guard. ---
	var pockets: Array = _water_pockets(sim)
	pockets.sort_custom(func(a: Array, b: Array) -> bool: return _pocket_top(a) < _pocket_top(b))
	var target: Array = []
	var breach: Vector2i = Vector2i(-1, -1)     # the rim rich_ore cell to cut (claims treasure + opens the seal)
	var breach_col: int = -1                    # the OUTSIDE column the body descends + stands in to reach it
	for p: Array in pockets:
		if _pocket_top(p) < LayeredWorldGen.AQUIFER_MIN_ROW or p.size() < 12:
			continue
		var wset: Dictionary = {}
		for w: Vector2i in p:
			wset[w] = true
		# Scan for the SHALLOWEST rim rich_ore cell with the clean [water | rich_ore | outside] geometry.
		var best: Vector2i = Vector2i(-1, -1)
		var best_col: int = -1
		for w: Vector2i in p:
			for dir: int in [-1, 1]:
				var r: Vector2i = Vector2i(w.x + dir, w.y)      # the cell just outside this water cell, horizontally
				var out_cell: Vector2i = Vector2i(w.x + dir * 2, w.y)  # one more step out = the descent/stand column
				if wset.has(r) or wset.has(out_cell) or not sim.in_bounds(out_cell):
					continue
				if sim.solid.get(r, &"") != &"rich_ore":
					continue
				if best.x < 0 or r.y < best.y:
					best = r
					best_col = out_cell.x
		if best.x >= 0:
			target = p
			breach = best
			breach_col = best_col
			break
	if breach.x < 0:
		return await _finish(agent, false,
			"worldgen produced no deep, treasure-lined aquifer with a breachable rim rich_ore vein (checked %d pockets)" % pockets.size())
	agent._note("  target aquifer: %d cells, breach rim rich_ore %s, descend column %d" % [target.size(), str(breach), breach_col])

	# --- SETUP HATCH: guarantee the DESCENT (RUNG-3's guarantee-the-site). Make the descent column solid
	# deepslate from the settle row down through the breach level + a floor one below (the body ends standing
	# LEVEL with the rim vein), then open a foothold at the top. A worldgen cave in this shaft would drop the
	# body out of reach mid-dig; the DIG itself stays the tested verb. Pocket, water, and vein are untouched. ---
	const DESCENT_ROWS: int = 10
	var settle_row: int = breach.y - DESCENT_ROWS
	for y: int in range(settle_row, breach.y + 2):
		sim.set_solid(Vector2i(breach_col, y), &"deepslate")
	sim.set_solid(Vector2i(breach_col, settle_row), &"")         # the body's foothold (stand on settle_row+1)
	sim.set_solid(Vector2i(breach_col, settle_row - 1), &"")
	agent.player.position = agent.main._cell_center(Vector2i(breach_col, settle_row))
	for _i: int in 20:
		await physics_frame                                      # settle onto the foothold
	if not await agent.select_item(&"stone_pickaxe"):
		return await _finish(agent, false, "no pick to dig the deep")

	# --- STEP 1: the DESCENT. Dig straight down the deep column to the breach level (a genuine reach-gated
	# deep dig; deepslate needs the tier-2 pick selected above). ---
	if not await agent.dig_down_to(Vector2i(breach_col, breach.y)):
		return await _finish(agent, false,
			"could not descend the deep shaft to the aquifer (stuck at %s)" % str(agent.main._cell_at(agent.player.position)))

	# --- STEP 2: the BREACH + the CLAIM, one honest cut. Mine the rim rich_ore at the waterline: it CLAIMS
	# the flood-guarded treasure AND opens the sealed pocket wall. Reach in horizontally from the dry shaft
	# (re-select the pick; picking up deepslate on the way down can swap the active slot). ---
	if not agent.main._can_reach(breach):
		return await _finish(agent, false, "descended, but the rim vein at %s is out of reach from the shaft" % str(breach))
	if not await agent.select_item(&"stone_pickaxe"):
		return await _finish(agent, false, "lost the pick before the breach cut")
	var rich_before: int = int(sim.inventory.get(&"rich_ore", 0))
	var g: int = 0
	while sim.is_solid(breach) and g < 90:
		agent.do_mine(breach)
		await agent.wait(4); g += 1
	if sim.is_solid(breach):
		return await _finish(agent, false, "could not cut the rim rich_ore breach at %s" % str(breach))
	var got: int = int(sim.inventory.get(&"rich_ore", 0)) - rich_before
	if got < 1:
		return await _finish(agent, false, "cut into the aquifer wall but the rich_ore treasure didn't drop (got %d)" % got)

	# --- STEP 3: the FLOOD RELEASES. The sealed pocket, breached, pours into the dig. Let the game tick and
	# confirm water floods the shaft the body stands in (it wades): the sealed-pocket-releases fantasy, on
	# real worldgen water at real depth. ---
	var flooded: bool = false
	for _i: int in 60:
		await agent.step()
		if sim.water_at(Vector2i(breach_col, breach.y)) > 0 or agent.player._in_water():
			flooded = true
			break
	print("  breach: %s  (descended %d rows to %d, rich_ore=%d, flood released=%s)" % [
		agent.friction(), DESCENT_ROWS, breach.y, got, flooded])
	if not flooded:
		return await _finish(agent, false, "breached the aquifer + took the ore, but the sealed flood never released into the dig")
	return await _finish(agent, true,
		"descended into the deep, breached a real worldgen aquifer to claim its guarded rich_ore (%d), and released the flood" % got)


## Flood-fill sim.water into connected 4-neighbour pockets. RUNG 6 uses this to DISCOVER a real worldgen
## aquifer to breach rather than hand-staging one, so the rung guards worldgen (it must keep shipping deep,
## treasure-lined, breachable water pockets) as well as the embodied breach loop.
func _water_pockets(sim: FactorySim) -> Array:
	var seen: Dictionary = {}
	var pockets: Array = []
	for c: Vector2i in sim.water.keys():
		if seen.has(c):
			continue
		var cells: Array[Vector2i] = []
		var stack: Array[Vector2i] = [c]
		seen[c] = true
		while not stack.is_empty():
			var w: Vector2i = stack.pop_back()
			cells.append(w)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = w + d
				if sim.water.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
		pockets.append(cells)
	return pockets


func _pocket_top(cells: Array) -> int:
	var t: int = 1 << 30
	for c: Vector2i in cells:
		t = mini(t, (c as Vector2i).y)
	return t


## RUNG 7. PUMP OUT A REAL WORLDGEN AQUIFER (the FULL L3 loop, end to end on the shipping world): RUNG 6
## proved descent + breach + release + claim; this closes the arc with the DESIGNED tool: descend → build a
## POWERED PUMP → breach the sealed pocket (claim its guarded rich_ore) → the released flood pours in → the
## pump DRAINS it → climb back out with the flood at your back. The aquifer is DISCOVERED dynamically, so the
## rung guards the whole loop on real worldgen geometry. The play here is "prep, then breach": the pump loop is
## built DRY in a small room carved into the rim rock (the pocket stays sealed, so the build is a dry walk;
## generators/pumps aren't water-gated anyway), THEN the wall is cut so the pre-built pump immediately handles
## the flood. Setup hatch (RUNG-3's guarantee-the-site): the room + descent shaft are carved; the DESCENT dig,
## the gen/conduit/pump BUILDS, the breach CUT, the DRAIN, and the CLIMB-OUT are all real reach-gated verbs.
func _goal_pump_out_a_worldgen_aquifer() -> bool:
	var agent: PlayAgent = await _boot()
	var sim: FactorySim = agent.sim
	for t: StringName in ResearchRules.ORDER:                     # setup hatch: the bench/research flow is proven elsewhere
		sim.research[t] = true

	# --- FIND the aquifer + the breach vein: a deep, substantial pocket with a rim rich_ore R that has pocket
	# water on one side and OUTSIDE solid rock on the other, as LOW as possible (a low breach drains best; the
	# sump sits near the pocket floor so gravity feeds the whole pocket into it). dir = toward the pocket. ---
	var pockets: Array = _water_pockets(sim)
	pockets.sort_custom(func(a: Array, b: Array) -> bool: return _pocket_top(a) < _pocket_top(b))
	var pk: Array = []
	var R: Vector2i = Vector2i(-1, -1)     # the rim rich_ore to cut: claims the treasure AND opens the seal
	var dir: int = 0                       # +1 if the pocket is to the RIGHT of R (room to the left), else -1
	for p: Array in pockets:
		if _pocket_top(p) < LayeredWorldGen.AQUIFER_MIN_ROW or p.size() < 12:
			continue
		var wset: Dictionary = {}
		for w: Vector2i in p:
			wset[w] = true
		var best: Vector2i = Vector2i(-1, -1)
		var best_dir: int = 0
		for w: Vector2i in p:
			for d: int in [1, -1]:
				var rc: Vector2i = Vector2i(w.x - d, w.y)         # rim cell just OUTSIDE this water cell (pocket is dir=d away)
				var out_cell: Vector2i = Vector2i(w.x - 2 * d, w.y)  # one more step out = the room side
				if wset.has(rc) or wset.has(out_cell) or not sim.in_bounds(out_cell):
					continue
				if sim.solid.get(rc, &"") != &"rich_ore":
					continue
				if best.x < 0 or rc.y > best.y:                   # LOWEST rim vein drains best
					best = rc
					best_dir = d
		if best.x >= 0:
			pk = p
			R = best
			dir = best_dir
			break
	if R.x < 0:
		return await _finish(agent, false,
			"worldgen produced no deep aquifer with a low breachable rim rich_ore vein (checked %d pockets)" % pockets.size())

	# --- geometry: a tight room carved on the -dir (OUTSIDE) side of the breach vein R, at R's row. The body
	# works entirely from ONE solid-floored STAND column: it breaches R across the sump gap (dist 2), drops the
	# pump into the adjacent sump (dist 1), and the generator sits one cell ABOVE it: close enough to power the
	# pump by its innate AURA (radius 2, no conduit) and clear of both the walk row and the climb shaft. ---
	var r: int = R.y                                  # the room floor walk row + the breach row (level with the vein)
	var pump_col: int = R.x - dir                     # the pump + sump: one cell out from R (floods when R is cut)
	var gen_col: int = R.x - 2 * dir                  # the STAND column: solid floor; the body works entirely from here
	var ds: int = gen_col                             # descend + climb THE STAND COLUMN itself (machines live on pump_col, never on it)
	var wall_col: int = R.x - 3 * dir                 # the room's outer wall
	var lo_x: int = mini(wall_col, pump_col)
	var hi_x: int = maxi(wall_col, pump_col)

	# Carve the DRY room (pocket stays sealed; R and the pocket water are untouched). Floor bed solid at r+1,
	# outer wall solid, descent shaft solid (dug on the way down), the sump open under the pump with depth below.
	const DESCENT_ROWS: int = 10
	var settle_row: int = r - DESCENT_ROWS
	for x: int in range(lo_x, hi_x + 1):
		for y: int in range(r - 2, r + 4):
			var c := Vector2i(x, y)
			sim.remove_water(c, FactorySim.WATER_MAX)
			if y >= r + 1 or x == wall_col or x == ds:
				sim.set_solid(c, &"deepslate")        # bed + outer wall + the (solid, to-be-dug) descent shaft
			else:
				sim.set_solid(c, &"")                 # dry room walk-space
	sim.set_solid(Vector2i(pump_col, r + 1), &"")     # the sump (drain depth under the pump)
	sim.set_solid(Vector2i(pump_col, r + 2), &"")
	sim.set_solid(Vector2i(pump_col, r + 3), &"deepslate")
	for y: int in range(settle_row, r):               # the descent shaft above the room (solid, dug on the way down)
		sim.set_solid(Vector2i(ds, y), &"deepslate")
	sim.set_solid(Vector2i(ds, settle_row), &"")      # foothold at the top
	sim.set_solid(Vector2i(ds, settle_row - 1), &"")
	# A LANDING at the shaft mouth. Climbing back up only counts as "out" if there is somewhere to STAND
	# there, and once the shaft below has been dug the top cell has no floor left, so the body rides the
	# rope to the lip, finds no footed exit either side, and hangs there until the budget runs out. A
	# player descending from a chamber cuts this ledge before dropping in; the fixture cuts it too.
	for dx: int in [-1, 1]:
		if not sim.in_bounds(Vector2i(ds + dx, settle_row + 1)):
			continue
		sim.set_solid(Vector2i(ds + dx, settle_row), &"")
		sim.set_solid(Vector2i(ds + dx, settle_row - 1), &"")
		sim.set_solid(Vector2i(ds + dx, settle_row + 1), &"deepslate")

	# Loadout: a pump, a generator (its aura powers the adjacent pump: no wiring; conduit delivery is RUNG 5's
	# proof), the tier-2 pick (deepslate + rich_ore), rope for the climb out.
	agent.give(&"pump", 1)
	agent.give(&"generator", 1)
	agent.give(&"stone_pickaxe", 1)
	agent.give(&"rope", 25)
	agent.player.position = agent.main._cell_center(Vector2i(ds, settle_row))
	for _i: int in 20:
		await physics_frame
	agent._note("  aquifer %d cells, breach vein %s (dir %d), room floor row %d, descend col %d" % [pk.size(), str(R), dir, r, ds])

	# --- STEP 1: DESCEND the deep shaft into the room (a real reach-gated deepslate dig). ---
	if not await agent.select_item(&"stone_pickaxe"):
		return await _finish(agent, false, "no pick to dig the deep")
	if not await agent.dig_down_to(Vector2i(ds, r)):
		return await _finish(agent, false, "could not descend into the pump room (stuck at %s)" % str(agent.main._cell_at(agent.player.position)))

	# --- STEP 2: build the GENERATOR DRY (pocket still sealed), diagonally up from the stand column so it never
	# overlaps the body, sitting one cell ABOVE the pump's cell. Fuel it; its aura powers the pump dropped below
	# it after the breach: no wiring to lay (RUNG 5 proves conduit delivery). ---
	# `on_surface = false`: this is a walk across the floor of a pump room far underground, not an
	# approach over open ground. The room's floor sits around row 92 while that column's own surface is
	# row 13, so the surface contract is the wrong question to ask here.
	if not await agent.walk_to_column(gen_col, 900, false):
		return await _finish(agent, false, "could not reach the build spot in the room")
	var gen_cell := Vector2i(pump_col, r - 1)
	if not await agent.select_item(&"generator"):
		return await _finish(agent, false, "no generator in the pack")
	if not await agent.build_at(gen_cell):
		return await _finish(agent, false, "could not stand the generator at %s" % str(gen_cell))
	var gen: MachineState = sim.machine_at(gen_cell)
	if gen == null:
		return await _finish(agent, false, "the generator vanished after placement")
	gen.input_buffer[&"coal"] = 60                    # hatch the fuel (the toss-feed verb is RUNG-1's; the loop is under test)
	sim.total_produced[&"coal"] = int(sim.total_produced.get(&"coal", 0)) + 60

	# --- STEP 3: the BREACH + the CLAIM. Cut the rim rich_ore R. One move claims the flood-guarded treasure AND
	# opens the sealed pocket wall; the released flood pours into the room and down into the sump. Reach across the
	# sump gap from the stand column (the body never crosses into the pocket or onto the sump). ---
	if not await agent.walk_to_column(gen_col, 900, false):
		return await _finish(agent, false, "could not reach the breach wall")
	if not agent.main._can_reach(R):
		return await _finish(agent, false, "at the wall, but the rim vein %s is out of reach" % str(R))
	if not await agent.select_item(&"stone_pickaxe"):
		return await _finish(agent, false, "lost the pick before the breach")
	var rich_before: int = int(sim.inventory.get(&"rich_ore", 0))
	var bg: int = 0
	while sim.is_solid(R) and bg < 90:
		agent.do_mine(R)
		await agent.wait(4); bg += 1
	if sim.is_solid(R):
		return await _finish(agent, false, "could not cut the rim rich_ore breach at %s" % str(R))
	var got: int = int(sim.inventory.get(&"rich_ore", 0)) - rich_before
	if got < 1:
		return await _finish(agent, false, "cut the aquifer wall but the rich_ore treasure didn't drop (got %d)" % got)

	# --- STEP 4: drop the PUMP into the flooded sump (reach in from the dry side so the body never stands over
	# the sump) and confirm the pre-built power reaches it. ---
	if not await agent.walk_to_column(gen_col, 900, false):
		return await _finish(agent, false, "could not step back to place the pump")
	if not await agent.select_item(&"pump"):
		return await _finish(agent, false, "no pump in the pack")
	var pump_cell := Vector2i(pump_col, r)
	if not agent.main.try_build(pump_cell):
		return await _finish(agent, false, "could not place the pump at %s [reach=%s placeable=%s]"
			% [str(pump_cell), agent.main._can_reach(pump_cell), agent.main._placeable(pump_cell)])
	for _i: int in 6:
		await agent.step()                            # warm the generator, let power flood the network
	if sim.power_at(pump_cell) <= 0.0:
		return await _finish(agent, false, "the pump is placed but no power reaches it (power=%.2f)" % sim.power_at(pump_cell))

	# --- STEP 5: DRAIN. The pump chews the released flood down. Read the connected pocket + sump water so a
	# far-off worldgen aquifer can't mask the drain. ---
	var drain_cells: Array[Vector2i] = []
	for w: Vector2i in pk:
		drain_cells.append(w)
	drain_cells.append(Vector2i(pump_col, r))
	drain_cells.append(Vector2i(pump_col, r + 1))
	drain_cells.append(Vector2i(pump_col, r + 2))
	var pocket_water := func() -> int:
		var s: int = 0
		for c: Vector2i in drain_cells:
			s += sim.water_at(c)
		return s
	var water_before: int = pocket_water.call()
	var t: int = 0
	while pocket_water.call() > water_before / 2 and t < 1200:
		await agent.step(); t += 1
	var water_after: int = pocket_water.call()
	if water_after >= water_before or water_after > water_before / 2:
		return await _finish(agent, false, "the powered pump never substantially drained the aquifer (%d -> %d)" % [water_before, water_after])

	# --- STEP 6: CLIMB OUT. Escape the drained pocket back up the descent shaft, the flood at your back. Step
	# onto the (guaranteed, dug-clear) shaft column first, then rope up. The shaft is open the whole way (the
	# body dug out its own footing on the way down), so "escaped" = climbed clear of the flooded floor back up
	# near the top of the shaft (out of the water), not landing on a surface that no longer exists down here. ---
	# `on_surface = false`: the body is on the floor of a drained pocket far below, stepping onto the
	# shaft column before roping up. Demanding the top of the column here asks for a surface that, as the
	# note above says, no longer exists down here. This rung passed for a long time only because the old
	# one-axis test could not tell the difference: the body was at row 92 against a surface row of 13.
	if not await agent.walk_to_column(ds, 900, false):
		return await _finish(agent, false, "drained the aquifer but could not reach the shaft to climb out")
	var climbed: bool = await agent.climb_to_surface(settle_row)
	var out_row: int = agent.main._cell_at(agent.player.position).y
	var escaped: bool = climbed or out_row <= settle_row + 2
	print("  pump-out: %s  (descended %d, rich_ore=%d, water %d->%d, climbed to row %d, escaped=%s)" % [
		agent.friction(), DESCENT_ROWS, got, water_before, water_after, out_row, escaped])
	return await _finish(agent, escaped,
		"descended, built a powered pump, breached a real worldgen aquifer (claimed %d rich_ore), drained it (%d->%d), and climbed out"
			% [got, water_before, water_after])


## RUNG 3's build site, DERIVED FROM THE WORLD'S OWN CONTRACTS rather than picked by eye, because the last
## column picked by eye is what put this rung on ground the generator is allowed to open a hole in.
##
## Two properties are wanted, and the generator already promises both, so the fixture needs to touch
## nothing to get them:
##
##   PAST THE LAST SPAWN FIXTURE. WorldSeeder's rightmost stamp is the drill shaft at MINESHAFT_COL, so
##     anything beyond it is unclaimed ground and a module placed there lands on rock, not on a fixture.
##   INSIDE THE SINKHOLE KEEPOUT. `_open_sinkholes` is the only pass that breaks the surface lid, and it
##     refuses to do so within SINKHOLE_KEEPOUT columns of LayeredWorldGen.SPAWN_COL. Inside that band the
##     ground is unbroken on EVERY seed; outside it, whether a mouth lands on your approach is luck.
##
## Six columns clear of the shaft leaves room to stand, dig and jump out without the shaft mouth in reach.
const CHAIN_COL: int = MainView.MINESHAFT_COL + 6


## Why `col` is not somewhere a mouth can open, or "" if it is fine. The two constants it relates live in
## two different files and nothing else compares them, so the relationship is asserted at run time rather
## than believed: move either one and this rung says which, instead of quietly going back to terrain luck.
func _site_fault(col: int) -> String:
	if col <= MainView.MINESHAFT_COL:
		return "col %d is inside the spawn fixture band (the last fixture is the drill shaft at col %d)" \
			% [col, MainView.MINESHAFT_COL]
	var reach: int = absi(col - LayeredWorldGen.SPAWN_COL)
	if reach >= LayeredWorldGen.SINKHOLE_KEEPOUT:
		return ("col %d is outside the sinkhole keepout (|%d - %d| = %d, keepout %d), so worldgen may open"
			+ " a mouth on this approach and the rung would be measuring terrain luck") \
			% [col, col, LayeredWorldGen.SPAWN_COL, reach, LayeredWorldGen.SINKHOLE_KEEPOUT]
	return ""


## RUNG 3. The L2 IRON CHAIN is playable embodied: with the iron
## tier researched and the modules in the pack (bench/craft flows proven headless + in RUNG 1), the
## agent DIGS a socket pit, stands the gravity chain in it as Iron Forge over Plate Press, pours raw
## iron into the open column above, and must end up holding a PLATE: dig, place, toss, collect, all
## through the real reach-gated verbs from where a body can actually stand.
##
## THIS RUNG IS ABOUT THE CHAIN, AND THE SITE IS CHOSEN SO THAT IT CAN BE. It used to walk to column 75,
## and when the generator opened a mouth across that approach the walk was made to succeed by levelling ten
## columns of ground into a pavement. That is the worst repair on offer: the rung went green because the
## obstacle had been deleted, and the deleted obstacle was the only one in the suite that a body was gated
## on crossing. Both halves are now addressed by not needing the pavement — the chain moves onto ground the
## generator already guarantees (CHAIN_COL), and the crossing became `_goal_cross_to_the_far_site`, which
## walks the old approach with nothing levelled.
func _goal_l2_chain() -> bool:
	var agent: PlayAgent = await _boot()
	var sim: FactorySim = agent.sim
	var col: int = CHAIN_COL
	var fault: String = _site_fault(col)
	if fault != "":
		return await _finish(agent, false, "the build site is not contract ground: %s" % fault)
	for t: StringName in ResearchRules.ORDER:                # setup hatch: the bench flow is proven elsewhere
		sim.research[t] = true
	agent.give(&"iron_forge", 1)
	agent.give(&"plate_press", 1)
	# Ten, not eight: two are spent on the control below, and a treatment left with barely enough to clear
	# its own assertion is a treatment that reports resource starvation as a broken chain.
	agent.give(&"iron", 10)
	if not await agent.walk_to_column(col, 1200):
		return await _finish(agent, false, "never reached the build site at col %d" % col)
	var top: int = sim.surface_row(col)
	# Guarantee the socket site (the RUNG-4 pattern): the column must be SOLID down through the socket
	# + its floor; a worldgen cave/tunnel under this col (pure vein-RNG luck, it shifts whenever a
	# gen pass changes) would drop the body out of reach mid-dig. The dig itself stays the tested verb.
	#
	# THE ONLY CELLS THIS RUNG WRITES, AND IT COUNTS THEM SO THE NUMBER IS IN THE LOG. An accommodation
	# nobody measures is an accommodation nobody can retire, and this one is now three cells on one column
	# rather than thirty on ten. If `filled` reads 0 across the corpus then the guarantee is dead weight and
	# can go; if it starts reading above 0, the generator has changed under the site and that is worth
	# knowing before it turns into a mystery failure.
	var filled: int = 0
	for y: int in range(top, top + 3):
		if not sim.is_solid(Vector2i(col, y)):
			sim.set_solid(Vector2i(col, y), &"earth")
			filled += 1
	# Sink the 2-deep socket exactly like a player does: the proven dig_down_to loop (stay CENTRED
	# over the column, cut under the feet, fall in, repeat). The old hand-rolled version could stall
	# with the feet straddling the socket lip: a cell-match stop leaves the body standing on the
	# neighbour floor, never falling in, and the second cut corner-blocks forever.
	if not await agent.dig_down_to(Vector2i(col, top + 1)):
		return await _finish(agent, false, "could not dig the module socket at %s" % str(Vector2i(col, top + 1)))
	await agent.wait(20)                                     # settle on the socket floor
	# Out of the socket (a 2-tile wall, exactly what the jump clears) and to its lip.
	if not await agent.walk_to_column(col + 1, 900):
		return await _finish(agent, false, "could not jump out of the socket")
	# The chain: press at the socket bottom, forge stacked on it flush with the ground; the open air
	# above the forge is the feed mouth.
	var press_cell := Vector2i(col, top + 1)
	if not await agent.select_item(&"plate_press"):
		return await _finish(agent, false, "no press in the pack")
	if not await agent.build_at(press_cell):
		return await _finish(agent, false,
			"could not stand the press in the socket at %s (chose col %d, surface row %d, body at %s)"
				% [str(press_cell), col, top, str(agent.main._cell_at(agent.player.position))])
	var refusal: String = await _press_refuses_raw_iron(agent, press_cell)
	if refusal != "":
		return await _finish(agent, false, refusal)
	if not await agent.select_item(&"iron_forge"):
		return await _finish(agent, false, "no iron forge in the pack")
	if not await agent.build_at(Vector2i(col, top)):
		return await _finish(agent, false, "could not stack the forge on the press")
	# Feed it: face the column and toss the whole iron stack in; gravity is the feeder.
	if not await agent.select_item(&"iron"):
		return await _finish(agent, false, "no iron to pour in")
	agent.player.facing = -1 if agent.main._cell_at(agent.player.position).x > col else 1
	agent.main.try_drop()
	# The chain runs hands-free; the plate pile lands at the press and reach-collection hands it over.
	var t2: int = 0
	while int(sim.inventory.get(&"plate", 0)) < 1 and t2 < 2400:
		await agent.step(); t2 += 1
	var plates: int = int(sim.inventory.get(&"plate", 0))
	print("  chain: %s  (col=%d surface row %d, socket cells filled=%d, plates=%d frames=%d)"
		% [agent.friction(), col, top, filled, plates, t2])
	return await _finish(agent, plates >= 1,
		"dug the socket, stood the iron chain, poured iron in the top, walked away holding a plate")


## THE CONTROL THAT MAKES RUNG 3 ABOUT THE CHAIN. Returns "" when the press behaves, or the reason it did
## not. Runs against the press ALONE, before the forge is stacked on it, so nothing the forge does can
## contaminate the answer.
##
## WHY IT HAS TO EXIST. `plates >= 1` cannot see the property the rung is named for. The chain is
## iron -> forge -> iron_ingot -> press -> plate, and the single thing making the forge load-bearing is
## that the press does not accept raw iron. Delete that dependency — let the press take iron directly —
## and the pour still lands in the press, a plate still comes out, and the rung is still green with the
## forge standing there as scenery. A guard that stays green when the thing it guards is removed is not a
## guard, and this file had sixteen of them and no way to tell which.
##
## THREE QUESTIONS, WEAKEST LAST. The first two are the game's own derivation (`machine_eats` is what the
## toss verb consults to pick a mouth), so they fail the instant the recipe changes, without waiting on
## physics. The third is the embodied version: the iron is put INSIDE the press and the press is run, so
## "no plate" is a statement about a press that had the iron rather than about a throw that missed. That
## distinction is the whole difference between a control and a coincidence.
func _press_refuses_raw_iron(agent: PlayAgent, cell: Vector2i) -> String:
	var sim: FactorySim = agent.sim
	var press: MachineState = sim.machine_at(cell)
	if press == null:
		return "no press registered at %s, so the control has nothing to ask" % str(cell)
	var recipe: RecipeDef = press.def.recipe
	if recipe == null:
		return "the press has no recipe at all, so there is no chain to walk"
	if sim.machine_eats(press, &"iron"):
		return ("the press eats RAW IRON, so the forge is not a step in the chain: this rung would reach"
			+ " its plate with the forge deleted")
	if not sim.machine_eats(press, &"iron_ingot"):
		return ("the press does not eat the forge's output (iron_ingot), so nothing connects the two halves"
			+ " of the chain this rung claims to walk")
	# The embodied half. `deposit` is deliberately unfiltered — the sim's own docstring says a test rig may
	# prime any buffer — which is exactly what a control needs: it puts the iron where a working press
	# would find it, past the toss and past reach, leaving no way to explain a null by a bad delivery.
	#
	# WHAT IT ASKS, AND WHY IT IS NOT "IS THE IRON STILL SITTING THERE". That was the first version of this
	# check and it failed on a healthy press, which is the useful direction for a new instrument to fail in.
	# `_run_recipe` opens with a documented PASS-THROUGH: anything a machine's recipe does not want is moved
	# straight to its output and falls on down the column, so a stack sorts a mixed stream and no buffer can
	# clog. The iron was therefore gone in 180 frames without ever being eaten, and an assertion written
	# against my assumption rather than against the design called correct behaviour a fault.
	#
	# So the question goes to the sim's own conservation ledger instead, which is the thing that actually
	# means "consumed": `total_consumed` is written in exactly one place, the branch of `_run_recipe` that
	# spends a recipe's inputs. A press that never increments it for iron has never treated iron as food,
	# whatever it did with the units afterwards.
	var offered: int = 2
	var iron_eaten: int = int(sim.total_consumed.get(&"iron", 0))
	var plates_made: int = int(sim.total_produced.get(&"plate", 0))
	if sim.deposit(cell, &"iron", offered) != offered:
		return "could not put the control iron into the press, so its silence would prove nothing"
	# Long enough for the press to have finished a cycle twice over if it were going to start one. Derived
	# from the recipe rather than typed in, so a slower press does not silently turn this into a no-op.
	var window: int = int(ceil(recipe.time * 60.0 / maxf(Engine.time_scale, 1.0))) * 2
	for _i: int in window:
		await agent.step()
	var ate: int = int(sim.total_consumed.get(&"iron", 0)) - iron_eaten
	if ate > 0:
		return ("the press CONSUMED %d raw iron in %d frames: the forge is not a step in the chain, and this"
			+ " rung would reach its plate with the forge deleted") % [ate, window]
	var made: int = int(sim.total_produced.get(&"plate", 0)) - plates_made
	if made > 0:
		return ("a press fed nothing but raw iron produced %d plate(s) in %d frames: the forge is not in the"
			+ " chain") % [made, window]
	var status: StringName = sim.machine_status(press)
	if status != &"no_input":
		return ("a press offered %d raw iron reads as '%s' rather than starved, so the game counts that iron"
			+ " as food") % [offered, str(status)]
	return ""


# --- TRAVERSAL ------------------------------------------------------------------------------------

## The column RUNG 3 used to walk to, kept as this rung's MINIMUM reach. The real destination is the far
## rim of whichever hole the world actually has (see `_first_hole_east`), but it may never be nearer than
## this: the rung exists to hold the coverage that moving RUNG 3's build site would otherwise have dropped,
## so the floor is the old walk and everything past it is a gain.
const FAR_SITE_COL: int = 75

## WHAT COUNTS AS A HOLE, so that "the body crossed the ground" cannot quietly become "there was nothing to
## cross". Six rows is past a jump and past the auto-step-up; two columns wide is past a stride. Under both
## of those the approach is a pavement, and a pavement is what this rung is here to refuse.
const CROSSING_MIN_DROP: int = 6
const CROSSING_MIN_SPAN: int = 2


## The first real hole east of `from`, as {first column, last column}, or (-1, -1) if the ground runs
## unbroken all the way. "Real" is CROSSING_MIN_DROP deep and CROSSING_MIN_SPAN wide; a narrower or
## shallower dip is skipped over and the search continues, so a one-column notch cannot be mistaken for
## the thing we came to cross.
##
## IT SEARCHES RATHER THAN ASSUMING, and the corpus is why. The first version of this rung fixed its
## destination at column 75 and asked whether there was a hole in between. On five of the eight corpus
## seeds there was; on the other three the rung reported "nothing to cross", and that reading was wrong.
## The mouths were there — seed 7 at columns 80-85, seed 512 at 81-82, seed 20260817 at 75-82 — they were
## simply outside a window somebody had typed in. Three worlds' worth of the exact subject this rung exists
## for, invisible because the instrument had a fixed frame. WHERE the generator puts a mouth is seed
## business; THAT it puts them is the contract, so the rung asks the world where its hole is.
func _first_hole_east(sim: FactorySim, from: int, to: int) -> Vector2i:
	var c: int = from
	while c <= to:
		if sim.surface_row(c) - MainView.SURFACE < CROSSING_MIN_DROP:
			c += 1
			continue
		var last: int = c
		while last + 1 <= to and sim.surface_row(last + 1) - MainView.SURFACE >= CROSSING_MIN_DROP:
			last += 1
		if last - c + 1 >= CROSSING_MIN_SPAN:
			return Vector2i(c, last)
		c = last + 1
	return Vector2i(-1, -1)


## How far below the datum a stretch of surface falls at its worst: the depth of the hole, for the log.
func _deepest_drop(sim: FactorySim, from: int, to: int) -> int:
	var drop: int = 0
	for c: int in range(from, to + 1):
		drop = maxi(drop, sim.surface_row(c) - MainView.SURFACE)
	return drop


## How far past the destination to look for real ground before giving up.
const FOOTING_SEARCH: int = 8


## Where to finish: FAR_SITE_COL if the generator left ground there, else the first column past it that it
## did. A mouth is a few columns wide and where its far rim falls is seed business, so the finish line has
## to be able to move — but it moves RIGHTWARD ONLY, away from spawn, so a wider hole can only ever make
## this rung ask for more. It can never slide the finish line back to the near side of the thing being
## crossed, which is the one way an adaptive target could quietly delete its own subject.
func _far_footing(sim: FactorySim, from: int) -> int:
	for c: int in range(from, mini(from + FOOTING_SEARCH, FactorySim.GRID_COLS - 3)):
		if sim.surface_row(c) <= HeightmapWorldGen.SURFACE_ROW_MAX:
			return c
	return -1


## The surface silhouette of a stretch, column by column. Printed rather than summarised: when this rung
## fails, the shape of the ground is the finding, and a single "could not get there" is not.
func _surface_profile(sim: FactorySim, from: int, to: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c: int in range(from, to + 1):
		parts.append(str(sim.surface_row(c)))
	return "cols %d-%d rows [%s]" % [from, to, " ".join(parts)]


## CROSS THE OPEN GROUND, on ground nothing has levelled.
##
## THE COVERAGE THIS RUNG IS CARRYING, and why it is worth a rung of its own. RUNG 3 walked from spawn to
## column 75 to reach a build site. That walk leaves the sinkhole keepout at column 68, and past the
## keepout is the first place in the world where `_open_sinkholes` may break the surface lid — so, entirely
## by accident, that walk was the only gated thing in the suite that put a body across a real surface
## mouth. Nothing else covers it. `check_walk` PLACES the body at each sample column and walks a 90-frame
## burst, which is a snap hunt and never crosses anything. `check_traverse` carves its own gallery, gates
## the rope against the legs inside it, and deliberately PRINTS the open-sky run rather than gating it.
## `check_plunge` rides a mouth DOWNWARD. The horizontal crossing belonged to nobody, so it belongs here.
##
## THE FIXTURE MAY NOT TOUCH THE GROUND, and the rung enforces that on itself rather than promising it. It
## finds the hole in the approach BEFORE walking, and fails if there is not one. That is the guard against
## the repair that started all of this: levelling the approach makes the walk succeed, and it also makes
## this assertion fail, so the pavement can no longer be mistaken for a pass. Demonstrated rather than
## assumed — dropping the old ledge loop back in front of this check flattens columns 66-75 to row 21, the
## 58-row hole disappears from the profile, and the rung goes red instead of green. It doubles as a worldgen
## alarm: if a future pass stops breaking the surface lid, this says so rather than going quietly green.
##
## The blocks are the file's usual journey hatch (a journey measures traversal, not whether you remembered
## to bring planks). Everything after that is a player verb: walk, jump, and lay a plank of your own dirt
## over the hole. `approach` is what does the laying, and it does it through `try_build`.
func _goal_cross_to_the_far_site() -> bool:
	var agent: PlayAgent = await _boot()
	var sim: FactorySim = agent.sim
	var from_col: int = agent.main._cell_at(agent.player.position).x
	var east_edge: int = FactorySim.GRID_COLS - 6
	var hole: Vector2i = _first_hole_east(sim, from_col, east_edge)
	if hole.x < 0:
		return await _finish(agent, false,
			("there is nothing to cross anywhere east of col %d — no run of %d columns is %d rows below the"
			+ " datum between there and col %d. Either the ground was levelled before the walk, in which"
			+ " case this rung is measuring a pavement, or worldgen has stopped breaking the surface lid, in"
			+ " which case the crossing is no longer a property of this world. Profile: %s")
				% [from_col, CROSSING_MIN_SPAN, CROSSING_MIN_DROP, east_edge,
				_surface_profile(sim, from_col, east_edge)])
	var drop: int = _deepest_drop(sim, hole.x, hole.y)
	# Finish on the far rim, but never nearer than the column RUNG 3 used to walk to, so this rung can only
	# ever ask for MORE ground than the coverage it inherited, never less.
	var stand: int = _far_footing(sim, maxi(hole.y + 1, FAR_SITE_COL))
	if stand < 0:
		# The parentheses are load-bearing. `%` binds tighter than `+`, so an unbracketed
		# `"a" + "b" % [x, y]` formats the SECOND fragment alone — a string with no specifiers against two
		# arguments — and the failure lands on the error path, where nobody is looking.
		return await _finish(agent, false,
			("the hole at cols %d-%d has no generated ground within %d columns of its far rim, so there is"
			+ " nowhere on the other side to stand") % [hole.x, hole.y, FOOTING_SEARCH])
	print("  crossing: hole at cols %d-%d, %d rows deep; finishing on col %d. %s"
		% [hole.x, hole.y, drop, stand, _surface_profile(sim, from_col, stand)])
	agent.give(&"earth", 40)
	await agent.approach(Vector2i(stand, sim.surface_row(stand)), 3000)
	# The gate is the two-axis arrival: on that column AND on top of it.
	var arrived: bool = await agent.walk_to_column(stand, 1200)
	var at: Vector2i = agent.main._cell_at(agent.player.position)
	# AND THE ROW IS CHECKED AGAINST THE GENERATOR, NOT AGAINST THE LIVE COLUMN, because the live column is
	# the one thing that cannot answer this. `surface_row` scans for the first solid cell and keeps no memory
	# of the original ground, so a column with a hole in it reports the floor of the hole as its surface —
	# and `walk_to_column`'s own depth test, being written against exactly that number, is satisfied at the
	# bottom of a mouth. That is fine for its callers, who are asking "am I on this column's ground"; it is
	# not enough here, where the whole question is whether the body is on the world's surface or inside it.
	# SURFACE_ROW_MAX is the deepest valley floor the heightmap can produce, so one row under it is the
	# honest boundary between standing on the ground and standing in a hole.
	var on_the_world: bool = at.y <= HeightmapWorldGen.SURFACE_ROW_MAX + 1
	print("  crossing: %s  (hole cols %d-%d %d rows deep, ended at %s, surface band ends row %d)"
		% [agent.friction(), hole.x, hole.y, drop, str(at), HeightmapWorldGen.SURFACE_ROW_MAX])
	return await _finish(agent, arrived and on_the_world,
		"crossed %d columns of unlevelled ground, over a hole %d rows deep at cols %d-%d, and stood on the"
		% [stand - from_col, drop, hole.x, hole.y] + " surface at col %d" % stand)


# --- FRICTION journeys ----------------------------------------------------------------------------
# These model the WHOLE realistic user experience, not just the headline verb. A player who wants to
# "drill a buried vein" doesn't teleport there; they dig DOWN to it (byproduct), do the thing, then
# claw their way back UP (the big one). Those byproduct steps are PLAYED and the effort printed (friction())
# so the game can be SEEN getting less painful as mobility tools land. Blocks are topped up (setup hatch) so a
# journey measures TRAVERSAL friction, not resource starvation; the pit/shaft is what is under test.

## Fill a clean vertical column of earth from the surface down to `depth` below it and bury an ore vein at
## the bottom: a deterministic shaft to dig, so the friction numbers are comparable run to run.
## `ore_rows` AND `per_cell` DEFAULT TO THE OLD BEHAVIOUR, so the four call sites that predate them are
## byte-equivalent: with `ore_rows` at 0 the ore branch below is unreachable, because `ore_top` equals
## `target.y` and the loop stops one short of it. They exist for the capped-trip rung, which needs a shaft
## whose spoil is ore rather than earth, since no arrangement of earth in Layer 1 can fill the pack.
## `per_cell` is pinned low on purpose: `mini(_ore_burst, latent)` then takes exactly `per_cell`, the cell
## is erased whole, and no lode residue is left behind, which matters because the pilot has no wrapper for
## the lode verb and would walk past what it could not pick up.
func _bury_vein(agent: PlayAgent, col: int, depth: int, ore_rows: int = 0, per_cell: int = 3) -> Vector2i:
	var target := Vector2i(col, MainView.SURFACE + depth)
	var ore_top: int = target.y - ore_rows
	for y: int in range(MainView.SURFACE, target.y):
		if y >= ore_top:
			agent.sim.set_solid(Vector2i(col, y), &"ore")
			agent.sim.deposits[Vector2i(col, y)] = per_cell
		else:
			agent.sim.set_solid(Vector2i(col, y), &"earth")  # a clean earthen column (no caves/gaps to complicate)
	agent.sim.set_solid(target, &"ore")
	agent.sim.deposits[target] = 40
	agent.sim.set_solid(Vector2i(col, target.y + 1), &"stone")  # a floor under the vein
	return target


## Round-trip: dig DOWN to a buried vein, mine it, and climb back to the SURFACE. The most common real loop
## and the friction it targets: "mine down, then mine a staircase back up". Pass = ore in hand AND body
## back on the surface (not stranded). Friction printed so the drop is visible when the rope lands.
func _goal_round_trip_to_vein() -> bool:
	var agent: PlayAgent = await _boot()
	var col: int = 34                                        # a clean plateau column, clear of the fixtures (40-56)
	var vein: Vector2i = _bury_vein(agent, col, 8)
	agent.give(&"earth", 12)                                 # buffer so "out of blocks" can't mask traversal friction
	agent.give(&"rope", 25)                                  # the era's loadout: rope makes the climb cheap
	var before: int = int(agent.sim.inventory.get(&"ore", 0))
	var dug: bool = await agent.dig_down_to(vein)
	var got: int = int(agent.sim.inventory.get(&"ore", 0)) - before
	var up: bool = await agent.climb_to_surface(MainView.SURFACE - 1)
	print("  friction: %s  (down=%s ore=%d up=%s)" % [agent.friction(), dug, got, up])
	# Rope-era ceilings (RATCHETED 2026-07-11: pre-rope this cost places=15/jumps=18/frames=320 of
	# pillar-jumping; the rope ride measures places=3 jumps=1 frames=58, locked in so it can't regress).
	# RATCHETED 2026-08-09 (measured dead-stable across 3 runs: mines=9 places=3 jumps=2 frames=82):
	# mines 15→12 · places 6→5 · frames 120→100 (jumps kept at 4, the loosest integer metric).
	var within: bool = _within_ceilings(agent, {"mines": 12, "places": 5, "jumps": 4, "frames": 100})
	return await _finish(agent, dug and got >= 1 and up and within,
		"dug to the buried vein, mined it, and climbed back to the surface")


## A DEEP round-trip: the same journey as the shallow one but to a vein twice as far down, so the friction
## SCALES visibly with depth (deeper = a longer, more punishing climb back). This is the number that must not
## explode as the game asks you to go deeper: it's the argument for the lift over the rope. Pass = ore in
## hand AND back on the surface; the friction() print is the depth-scaling read.
func _goal_descend_build_return() -> bool:
	var agent: PlayAgent = await _boot()
	var col: int = 62                                        # a clean plateau column, clear of the fixtures (40-56)
	var vein: Vector2i = _bury_vein(agent, col, 14)          # DEEP — twice the shallow round-trip
	agent.give(&"earth", 20)                                 # buffer so traversal friction, not resource, is measured
	agent.give(&"rope", 25)                                  # the era's loadout: rope makes the climb cheap
	var before: int = int(agent.sim.inventory.get(&"ore", 0))
	var dug: bool = await agent.dig_down_to(vein)
	var got: int = int(agent.sim.inventory.get(&"ore", 0)) - before
	var up: bool = await agent.climb_to_surface(MainView.SURFACE - 1)
	print("  friction: %s  (depth=14 down=%s ore=%d up=%s)" % [agent.friction(), dug, got, up])
	# Rope-era ceilings (RATCHETED 2026-07-11: pre-rope places=24/jumps=26/frames=520; the rope ride
	# measures places=6 jumps=1 frames=111; the deep climb no longer scales in pain, locked in).
	# RATCHETED 2026-08-09 (measured dead-stable across 3 runs: mines=15 places=6 jumps=2 frames=134):
	# mines 24→20 · places 10→8 · frames 200→165 (jumps kept at 4, the loosest integer metric).
	var within: bool = _within_ceilings(agent, {"mines": 20, "places": 8, "jumps": 4, "frames": 165})
	return await _finish(agent, dug and got >= 1 and up and within,
		"dug 14 deep to a vein, mined it, and climbed all the way back out")


## The pure "is the body TRAPPED?" test: drop the body into a deep 1-wide pit (walls solid both sides) with blocks
## in the pack, and require it to get out. If it can't, the player is stranded at the bottom of their own
## shaft: the worst friction this game could ship. DELIBERATELY ROPE-LESS: this journey guards the
## pillar-jump fallback (the worst-case loadout), while the round-trip journeys measure the rope era.
func _goal_escape_deep_pit() -> bool:
	var agent: PlayAgent = await _boot()
	var col: int = 37                                        # a clean plateau column, clear of the fixtures (40-56)
	var depth: int = 6
	# Solid ground both sides + below; a 1-wide open pit the body stands at the bottom of.
	for y: int in range(MainView.SURFACE, MainView.SURFACE + depth + 2):
		agent.sim.set_solid(Vector2i(col - 1, y), &"stone")
		agent.sim.set_solid(Vector2i(col + 1, y), &"stone")
	for y: int in range(MainView.SURFACE, MainView.SURFACE + depth):
		agent.sim.set_solid(Vector2i(col, y), &"")          # carve the pit
	agent.sim.set_solid(Vector2i(col, MainView.SURFACE + depth), &"stone")  # pit floor
	agent.player.position = agent.main._cell_center(Vector2i(col, MainView.SURFACE + depth - 1))
	agent.give(&"stone", 12)
	for _i: int in 20:                                      # let it settle at the bottom
		await physics_frame
	var up: bool = await agent.climb_to_surface(MainView.SURFACE - 1)
	print("  friction: %s  (escaped=%s)" % [agent.friction(), up])
	# RATCHETED 2026-08-09 (measured dead-stable across 3 runs: places=6 jumps=6 frames=132):
	# places 12→9 · jumps 12→9 · frames 220→175; the pillar-jump escape now can't quietly get worse.
	var within: bool = _within_ceilings(agent, {"places": 9, "jumps": 9, "frames": 175})
	return await _finish(agent, up and within, "climbed out of a %d-deep pit (must not be trapped)" % depth)


## Cross a JAGGED horizontal tunnel (up-and-down 1-tile steps, like a natural cave floor): the finicky
## cave-traversal that reads as feeling bad. Pass = reaches the far end; the friction (stuck_frames,
## jumps) is the read on how AGILE lateral cave movement feels.
func _goal_cross_jagged_tunnel() -> bool:
	var agent: PlayAgent = await _boot()
	var start_col: int = 57                                  # clean plateau, right of the fixtures; length stays < FLAT_END
	var length: int = 8
	var base: int = MainView.SURFACE + 4
	# Carve a corridor with a FLAT ceiling well above the highest lump and a FLOOR that jitters ±1 tile each
	# column (a lumpy cave floor). The ceiling clears rows down to the highest lump so undulating floors never
	# leave original terrain protruding into the walk path; the body only ever meets ±1 floor steps.
	var ceiling: int = base - 4                              # above the highest possible lump (base-1)
	for i: int in range(length):
		var c: int = start_col + i
		var floor_row: int = base + (1 if i % 3 == 1 else 0) - (1 if i % 4 == 3 else 0)
		for y: int in range(ceiling, floor_row):
			agent.sim.set_solid(Vector2i(c, y), &"")        # open headroom (flat ceiling → lumpy floor)
		for y: int in range(floor_row, base + 3):
			agent.sim.set_solid(Vector2i(c, y), &"stone")   # the lumpy floor + fill below
	agent.player.position = agent.main._cell_center(Vector2i(start_col, base - 1))
	agent.give(&"stone", 8)
	for _i: int in 20:
		await physics_frame
	# Just WALK it (hold toward the far column, hop only when genuinely stuck), the way a player crosses a
	# lumpy floor. This isolates the BODY's step-up/snap-down over ±1 lumps from the pathfinder's cleverness.
	var far_col: int = start_col + length - 1
	var reached: bool = await agent.walk_to_column(far_col, 1200)
	print("  friction: %s  (reached=%s at col %d)" % [agent.friction(), reached, agent.main._cell_at(agent.player.position).x])
	# RATCHETED 2026-08-09 (measured dead-stable across 3 runs: jumps=2 stuck_frames=1):
	# jumps 8→5 · stuck_frames 40→20; lumpy-floor lateral movement now guarded far tighter.
	var within: bool = _within_ceilings(agent, {"jumps": 5, "stuck_frames": 20})
	return await _finish(agent, reached and within, "walked a %d-cell jagged tunnel end to end" % length)


## Perform the real-verb action a single objective step asks for. Each branch uses only what a player has:
## the body, reach, and the hotbar. Returns whether the action could be carried out at all.

## THE RUNG THAT FILLS THE PACK. It exists because nothing else in this suite can: the four rungs above
## reach 25, 38, 12 and 8 bulk against a `PACK_BULK_CAP` of 90, and that is structural rather than a seed
## accident, because their veins hold 40 units and their grants hand out 12 and 20 earth. The deepest of
## them has an arithmetic ceiling near 74. **The cap cannot bind in any of them even in principle**, so the
## question the cap was added to answer, whether a capped trip is still a trip or has become a job, has had
## no instrument rather than no answer.
##
## An ore-bottomed shaft is what closes that. Thirty rows of ore at three units each is ninety bulk of
## spoil on the way down, on top of a granted twenty, so the pack fills partway and the cap binds during
## the descent rather than at the face.
##
## WHAT IT ASSERTS IS THAT IT POSED ITS SUBJECT AND SURVIVED IT: the pack reached ninety, and the body
## carried ninety back to the surface. No friction ceiling on top of that: `frames` would be a ceiling on
## a depth nobody has argued for, and three readings with no negative population cannot locate a bound.
## Ratchet later, from a member list across seeds and a control that breaches it.
##
## AND `frames` IS NOT THE TRIP COST, which is the trap this rung is most likely to be misread through.
## Only `step()` counts a frame and every one of its call sites is inside `climb_to_surface`, so the number
## measures the climb and not the journey. The jagged-tunnel rung prints `frames=0` for exactly that
## reason, having never climbed. Read `mines` and `peak carried` for what the descent cost.
func _goal_haul_a_capped_pack() -> bool:
	var agent: PlayAgent = await _boot()
	var col: int = 32                                        # clear of the fixtures and of the other rungs
	var vein: Vector2i = _bury_vein(agent, col, 40, 30, 3)
	agent.give(&"earth", 20)
	# FIFTY rope for a forty-deep shaft, and the margin is the point. `place_rope` spends one carried unit
	# PER SEGMENT, so a rope budget under the depth strands the body at the top of its own hang with
	# `rope_stall` and nothing to re-anchor from. This rung was written with twenty-five and read `up=false`
	# at `stuck=128`, which looked exactly like a capped pack refusing to be hauled out. It was not: a
	# control at four ore rows instead of thirty, nineteen bulk short of the cap, printed the SAME
	# `mines=41 places=11 jumps=2 frames=394 stuck=128`. Every driver number was identical while the load
	# differed, so the failure could not have been about the load. Provision the climb past the question,
	# then `rope_left` shows the descent was never what bound it.
	agent.give(&"rope", 50)
	var dug: bool = await agent.dig_down_to(vein)
	var up: bool = await agent.climb_to_surface(MainView.SURFACE - 1)
	print("  friction: %s  (down=%s up=%s cap=%d peak=%d room_at_end=%d rope_left=%d)"
		% [agent.friction(), dug, up, FactorySim.PACK_BULK_CAP, agent.peak_bulk, agent.sim.pack_room(),
			int(agent.sim.inventory.get(&"rope", 0))])
	# TWO CLAIMS, AND THE SECOND ONLY MEANS ANYTHING BECAUSE OF THE FIRST. That the journey reached the cap,
	# because a rung that fills to eighty-nine measures an uncapped trip and the suite already had four of
	# those. And that the body still got OUT carrying it, which is the question the cap was added to raise:
	# a limit that strands a player at the bottom of their own shaft is a different feature from one that
	# costs them a second trip. It costs a second trip. Ninety bulk climbs forty rows and surfaces.
	var filled: bool = agent.peak_bulk >= FactorySim.PACK_BULK_CAP
	if not filled:
		print("  the pack never filled: peak %d against a cap of %d" % [agent.peak_bulk, FactorySim.PACK_BULK_CAP])
	if not up:
		# Read `rope_left` before reading this as the cap stranding anybody. At zero the loadout ran out and
		# the rung is measuring its own provisioning; the trace carries the `climb:` note that says which.
		print("  the full pack never surfaced: %d rope left, %d bulk aboard"
			% [int(agent.sim.inventory.get(&"rope", 0)), agent.sim.carried_bulk()])
	return await _finish(agent, dug and filled and up,
		"hauled a pack that reached PACK_BULK_CAP back to the surface")

## The topmost SOLID ore cell in a column, or -1. The face a hand can still strike.
func _top_ore(agent: PlayAgent, col: int, y0: int, y1: int) -> int:
	for y: int in range(y0, y1 + 1):
		if agent.sim.material_at(Vector2i(col, y)) == &"ore":
			return y
	return -1


## How many SOLID ore cells are left. This is the face, and it is the loop's termination condition.
func _face_cells(agent: PlayAgent, col: int, y0: int, y1: int) -> int:
	var n: int = 0
	for y: int in range(y0, y1 + 1):
		if agent.sim.material_at(Vector2i(col, y)) == &"ore":
			n += 1
	return n


## UNITS still in the ground in a column, whether the cell is still solid or has been opened into a lode.
##
## THIS IS THE FUNCTION THE FIRST VERSION OF THIS RUNG DID NOT HAVE, and its absence produced a confident
## wrong answer. Hand-mining clears the block and pockets a 3-6 burst; the rest of the cell's yield stays
## put as a LODE for a drill (`factory_sim.gd:788`). `material_at` goes blank the instant a cell is
## struck, so a counter built on it reports a vein as GONE while most of its units are still in the
## ground. The rung read that as 173 units spilling onto the floor and asserted a conservation failure
## against a population that had never been in play.
func _vein_units(agent: PlayAgent, col: int, y0: int, y1: int) -> int:
	var n: int = 0
	for y: int in range(y0, y1 + 1):
		n += int(agent.sim.deposits.get(Vector2i(col, y), 0))
	return n


## WHAT A HAND LEAVES BEHIND. The T1.0 measurement that a single descent can actually take.
##
## THIS ROW WAS QUEUED AS A TRIPS RUNG AND THAT RUNG IS BLOCKED, on `climb_to_surface` and not on the
## game: a pilot that has roped a shaft, climbed out and re-descended cannot climb out a SECOND time. It
## rope-stalls two columns off the shaft axis, identically at depth 24 and depth 40, with 284 of 300 rope
## unspent. Not a budget, not a depth. The evidence and the next experiment are in the state file; the
## trips half of T1.0 stays open and is not silently converted into this.
##
## WHAT THE FIRST ATTEMPT GOT WRONG IS THE REASON THIS ROW EXISTS AT ALL. It counted the face as the
## `deposits` sitting under solid ore cells, watched 173 units vanish, and reported a spill. There was no
## spill. Hand-mining an ore block clears the cell and pockets a 3-6 burst; the rest of that cell's yield
## stays in the ground as a LODE for a drill (`factory_sim.gd:788`), and `material_at` goes blank the
## instant the cell is struck. **A counter built on `material_at` reports a vein as gone while most of it
## is still there.** The population was wrong, so the conservation law was written against units that had
## never been in play.
##
## Corrected, that mistake is the finding: a hand miner does not clear a vein, and cannot, at any number
## of trips. This rung measures the share.
##
## THE ASSERTIONS, AND EACH HAS A NEGATIVE THAT WAS RUN, NOT IMAGINED.
##
##   1. `produced > 0`. The hand won something; without it the other two are about an untouched vein.
##   2. `left > produced`. MOST OF THE VEIN IS STILL THERE when the hand is done. This is the claim.
##      Negative: pose the same face at 3 units a cell instead of 10 and the burst takes each cell whole,
##      leaving nothing for a drill, and the assertion fails. Run below.
##   3. `in_pack == produced`. Nothing spilled, so `produced` is a measurement of the pack and not of the
##      floor. Negative: drop the room guard and a full pack spills the burst.
func _goal_hand_leaves_the_vein() -> bool:
	var agent: PlayAgent = await _boot()
	var col: int = 36                                        # clear of the capped rung at 32
	var per: int = int(OS.get_environment("SF_VEIN_PER")) if OS.has_environment("SF_VEIN_PER") else 10
	var vein: Vector2i = _bury_vein(agent, col, 24, 24, per)
	var y0: int = MainView.SURFACE
	var cells0: int = _face_cells(agent, col, y0, vein.y)
	var units0: int = _vein_units(agent, col, y0, vein.y)
	agent.give(&"earth", 20)
	agent.give(&"rope", 60)
	const MAX_BURST: int = 6                                 # `_ore_burst` is 3 + (hash % 4)
	var face: int = _top_ore(agent, col, y0, vein.y)
	var down: bool = await agent.descend_to(Vector2i(col, face - 1))
	# Strike DOWN one cell at a time while a whole burst can fit, so the pack never has to spill and
	# `produced` stays a measurement of what the hand carried rather than of what hit the floor.
	while agent.sim.pack_room() >= MAX_BURST:
		var f: int = _top_ore(agent, col, y0, vein.y)
		if f < 0:
			break
		if not await agent.mine_cell(Vector2i(col, f)):
			break
	var produced: int = int(agent.sim.total_produced.get(&"ore", 0))
	var in_pack: int = int(agent.sim.inventory.get(&"ore", 0))
	var left: int = _vein_units(agent, col, y0, vein.y)
	var struck: int = cells0 - _face_cells(agent, col, y0, vein.y)
	print(("  friction: %s  (down=%s cells=%d struck=%d units=%d produced=%d in_pack=%d "
		+ "left_for_drill=%d)")
		% [agent.friction(), down, cells0, struck, units0, produced, in_pack, left])
	print("    HAND SHARE: %d of %d unit(s) in the ground came out by hand, %.1f%%. The rest needs a drill."
		% [produced, units0, 100.0 * float(produced) / maxf(1.0, float(units0))])
	if left <= produced:
		print("    the hand took most of this vein (%d left against %d won), so it does not pose the "
			% [left, produced] + "question a drill exists to answer")
	if in_pack != produced:
		print("    %d produced unit(s) are not in the pack: they SPILLED, and `produced` is then a "
			% (produced - in_pack) + "measurement of the floor")
	return await _finish(agent, produced > 0 and left > produced and in_pack == produced,
		"a hand miner wins the burst and leaves most of the vein for a drill")


## TRIPS PER FACE. The other half of T1.0's priority-1 row, which asked for frames AND TRIPS.
##
## The trip-count evidence this row had was `factory_sim.gd`'s arithmetic on a 263-unit lode: a floor,
## computed, never walked. This walks it. `_goal_hand_leaves_the_vein` measures ONE descent and what the
## hand wins from it; this one runs the loop until the face is out and counts the journeys.
##
## IT WAS BLOCKED FOR TWO ITERATIONS AND THE BLOCKER WAS IN THE PILOT, at `_rope_anchor_above`. A second
## descent leaves a one-cell bare gap where the first trip's hang meets the second's, and the anchor
## selector reported the stretch already roped because it only ever tested the top of it. The body rode
## the lower run to its top, could not grip past the gap, and burned its budget stalling and leaping into
## a cave. Fixed there, not worked around here.
##
## THE ASSERTIONS.
##
##   1. `trips >= 2`. A face holding more than one pack cannot be cleared in one journey.
##   2. `why == "the face ran out"`. The loop ended on the ORE and not on `TRIP_LIMIT`, and not on a
##      pilot failure. Without this, `trips` can be a measurement of the limit and assertion 1 passes by
##      construction, which is exactly how the first draft of this rung passed while reporting `trips=2`
##      against a derived floor of `4`.
##   3. `accounted >= produced`. Everything the hand won reached a machine or is still in the pack.
##      Nothing on the floor, so the trip count is over a loop that actually delivers.
func _goal_trips_to_clear_a_face() -> bool:
	var agent: PlayAgent = await _boot()
	if agent.sim.machines.is_empty():
		print("  VOID: no machine exists at boot, so there is nowhere to deliver and a trip count would "
			+ "be counting journeys that end with the pack still full")
		return await _finish(agent, false, "trips to clear a face")
	var col: int = 40                                        # clear of 32 and 36, the other two rungs
	var vein: Vector2i = _bury_vein(agent, col, 24, 24, 10)
	var y0: int = MainView.SURFACE
	var cells0: int = _face_cells(agent, col, y0, vein.y)
	var units0: int = _vein_units(agent, col, y0, vein.y)
	agent.give(&"earth", 20)
	agent.give(&"rope", 300)
	var trips: int = 0
	var delivered: int = 0
	var why: String = "the face ran out"
	const TRIP_LIMIT: int = 9
	const MAX_BURST: int = 6                                 # `_ore_burst` is 3 + (hash % 4)
	# TRIP_FRAMES, PER TRIP: `frames` (declared on `PlayAgent`) counts only `step()`, and every `step()`
	# call site is inside `climb_to_surface` -- it is a climb cost, not a trip cost, and this loop's descent
	# and mining phases wait on `_tick()`, which the docstring at `play_agent.gd:146-149` says deliberately
	# does not touch it. A round trip's actual cost -- descend, mine, climb -- has no counter that spans it.
	# `Engine.get_physics_frames()` is the zero-instrumentation-cost reading: a monotonic engine counter, so
	# a delta of two reads cannot be vacuous the way a hand-rolled counter could be, and it needs no change
	# to `play_agent.gd`. Split at the climb boundary so a trip dominated by re-descent reads differently
	# from one dominated by the carry, which is a live fork in `T1_0_SINK_DESIGN.md`'s decision table.
	var trip_frames: Array = []
	var descend_frames: Array = []
	var climb_frames: Array = []
	while _face_cells(agent, col, y0, vein.y) > 0:
		if trips >= TRIP_LIMIT:
			why = "TRIP_LIMIT reached, so this number is the limit and not the face"
			break
		trips += 1
		var trip_t0: int = Engine.get_physics_frames()
		var face: int = _top_ore(agent, col, y0, vein.y)
		# The cell ABOVE the face, never the face itself: `descend_to` is `dig_down_to`, so aiming it at
		# the ore makes the descent strike the column on the way down, outside the metered loop below.
		if not await agent.descend_to(Vector2i(col, face - 1)):
			why = "trip %d could not reach the cell above the face at row %d" % [trips, face]
			break
		while agent.sim.pack_room() >= MAX_BURST:
			var f: int = _top_ore(agent, col, y0, vein.y)
			if f < 0:
				break
			if not await agent.mine_cell(Vector2i(col, f)):
				break
		var trip_t1: int = Engine.get_physics_frames()
		if not await agent.climb_to_surface(MainView.SURFACE - 1):
			why = "trip %d filled but could not climb out" % trips
			break
		var trip_t2: int = Engine.get_physics_frames()
		descend_frames.append(trip_t1 - trip_t0)
		climb_frames.append(trip_t2 - trip_t1)
		trip_frames.append(trip_t2 - trip_t0)
		agent.select_item(&"ore")
		var before: int = int(agent.sim.inventory.get(&"ore", 0))
		var got: bool = await agent.deposit_selected()
		var moved: int = before - int(agent.sim.inventory.get(&"ore", 0))
		delivered += moved
		print("    trip %d: delivered %d (deposit=%s), %d face cell(s) left, rope %d left, trip_frames=%d (descend=%d climb=%d)"
			% [trips, moved, got, _face_cells(agent, col, y0, vein.y),
				int(agent.sim.inventory.get(&"rope", 0)), trip_frames[-1], descend_frames[-1], climb_frames[-1]])
		if moved <= 0:
			why = "trip %d delivered nothing, so the pack cannot empty and no later trip can differ" % trips
			break
	var in_pack: int = int(agent.sim.inventory.get(&"ore", 0))
	var produced: int = int(agent.sim.total_produced.get(&"ore", 0))
	var accounted: int = delivered + in_pack
	var climb_frames_sum: int = 0
	for c: int in climb_frames:
		climb_frames_sum += c
	var trip_frames_sum: int = 0
	for t: int in trip_frames:
		trip_frames_sum += t
	print("  CROSS-CHECK: sum(climb_frames)=%d against agent.frames=%d (both count physics frames spent "
		% [climb_frames_sum, agent.frames]
		+ "inside climb_to_surface, by different mechanisms -- a mismatch means the new counter is wrong)")
	print(("  friction: %s  (trips=%d cells=%d units=%d produced=%d delivered=%d in_pack=%d "
		+ "left_for_drill=%d | trip_frames=%s sum=%d | why: %s)")
		% [agent.friction(), trips, cells0, units0, produced, delivered, in_pack,
			_vein_units(agent, col, y0, vein.y), trip_frames, trip_frames_sum, why])
	if trips < 2:
		print("  the face was cleared in %d trip(s), so it never posed the question" % trips)
	if accounted < produced:
		print("  %d produced unit(s) reached neither a machine nor the pack: they SPILLED"
			% (produced - accounted))
	if why != "the face ran out":
		print("  the loop did not end on the ore: %s" % why)
	return await _finish(agent, trips >= 2 and accounted >= produced and why == "the face ran out",
		"a face bigger than the pack takes more than one trip, and every unit the hand wins arrives")


func _do_step(agent: PlayAgent, id: StringName) -> bool:
	match id:
		&"mine":   return await _step_mine(agent)
		&"smelt":  return await _step_smelt(agent)
		&"wood":   return await _step_wood(agent)
		&"bazaar": return await _step_bazaar(agent)
		&"craft":  return await _step_craft(agent)
		&"research": return await _step_research(agent)
		&"build":  return await _step_build(agent)
		&"fuel":   return await _step_fuel(agent)
		&"auto":   return await _step_auto(agent)
	return false


## Earn ingots the tutorial way: mine the starter veins for ore, toss it into the bootstrap forge, and
## reach-collect until `want` ingots are carried. The shared acquisition loop for the bench price
## (research) and the drill craft; both real ore→ingot labour through the real verbs.
func _ensure_ingots(agent: PlayAgent, want: int) -> bool:
	var guard: int = 0
	while int(agent.sim.inventory.get(&"ingot", 0)) < want and guard < 12:
		guard += 1
		if int(agent.sim.inventory.get(&"ore", 0)) < 2:
			var ore: Vector2i = _nearest_ore_not_shaft(agent)
			if ore.x < 0:
				return false
			await agent.dig_down_to(ore)
			await agent.climb_to_surface(MainView.SURFACE - 1)   # back OUT of the dig (pillar/rope), like a player
			continue
		if not await agent.select_item(&"ore"):
			return false
		if not await agent.walk_to_column(MainView.MINESHAFT_FORGE_CELL.x - 1):
			return false
		agent.player.facing = 1
		agent.main.try_drop()                                        # fling the carried ore into the forge
		var collect: Vector2i = MainView.MINESHAFT_FORGE_CELL + Vector2i(0, 1)
		var last: int = -1
		var settled: int = 0
		while settled < 3 and int(agent.sim.inventory.get(&"ingot", 0)) < want:
			await agent.approach(collect)                            # stand within reach → auto-collect
			for _i: int in 30:
				await physics_frame
			var now: int = int(agent.sim.inventory.get(&"ingot", 0))
			settled = settled + 1 if now == last else 0
			last = now
	return int(agent.sim.inventory.get(&"ingot", 0)) >= want


## Step: RESEARCH Automation at the bench. Earn the bench price (2 ingots), keep an ore SAMPLE to
## analyze, then stand at the Bazaar and research. The PULL the chain funnels through; the drill stays
## locked until the bench opens it, so this proves a player can actually pay the first unlock.
func _step_research(agent: PlayAgent) -> bool:
	if agent.sim.is_researched(&"automation"):
		return true
	var price: int = int(ResearchRules.tech(&"automation")["cost"].get(&"ingot", 0))
	if not await _ensure_ingots(agent, price):
		agent._note("  research: couldn't earn the %d-ingot bench price" % price)
		return false
	var guard: int = 0
	while int(agent.sim.inventory.get(&"ore", 0)) < 1 and guard < 4:
		guard += 1                                                   # top the SAMPLE back up (smelting ate it)
		var ore: Vector2i = _nearest_ore_not_shaft(agent)
		if ore.x < 0:
			return false
		await agent.dig_down_to(ore)
		await agent.climb_to_surface(MainView.SURFACE - 1)           # back OUT of the sample dig
	if not await _walk_to_bazaar(agent):
		agent._note("  research: could not reach the Bazaar bench")
		return false
	var ok: bool = agent.main.try_research(&"automation")
	agent._note("  research: automation=%s (ore=%d ingots=%d near=%s)" % [ok,
		int(agent.sim.inventory.get(&"ore", 0)), int(agent.sim.inventory.get(&"ingot", 0)),
		agent.main._near_bazaar()])
	return ok


## Step 1. Hand-dig the bootstrap ore (4) from the starter vein near spawn, never the mineshaft's vein.
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


## Step 2. Toss the surface ore into the bootstrap forge pocket (col 46) from beside it (col 45), let it
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


## Step 3. Chop a tree for wood (the bazaar's build material). Chop one trunk block of the nearest tree
## (block-by-block now); one wood is enough to claim the bazaar.
func _step_wood(agent: PlayAgent) -> bool:
	var base: Vector2i = _nearest_tree_base(agent)
	if base.x < 0:
		agent._note("  wood: no tree in the world to chop")
		return false
	await agent.mine_cell(base, 1400)        # the tree may be a surface hike from the mineshaft
	agent._note("  wood: produced wood=%d carried=%d" % [
		int(agent.sim.total_produced.get(&"wood", 0)), int(agent.sim.inventory.get(&"wood", 0))])
	return int(agent.sim.inventory.get(&"wood", 0)) >= 1


## Step 4. Claim the Bazaar: place one wood block in the gap of the ruined frame near spawn, completing it.
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


## Step 5. Craft a Drill AT the Bazaar: earn its ingot price (research just spent the last batch), then
## walk to the stall (crafting is gated on proximity) and craft.
func _step_craft(agent: PlayAgent) -> bool:
	var price: int = int((load(DRILL) as MachineDef).craft_cost.get(&"ingot", 0))
	if not await _ensure_ingots(agent, price):
		agent._note("  craft: couldn't earn the %d-ingot drill price" % price)
		return false
	if not await _walk_to_bazaar(agent):
		agent._note("  craft: could not reach the Bazaar to craft at it")
		return false
	if not agent.craft(load(DRILL)):
		agent._note("  craft: craft refused (near_bazaar=%s ingots=%d)" % [
			agent.main._near_bazaar(), int(agent.sim.inventory.get(&"ingot", 0))])
		return false
	return int(agent.sim.inventory.get(&"drill", 0)) >= 1 or _has_drill(agent)


## Step 4. Drop the Drill above the vein (boring model): the mineshaft has a VISIBLE solid ore vein with an
## OPEN cell above it; place the Drill in that open cell and it bores DOWN into the ore, whose pull falls into
## the forge below. The reach-in comes from the shaft EDGE (col-1) so the body never drops into the cell being placed.
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


## Step 5. Fuel the Drill: mine the coal vein (right of the shaft), then drop coal down the open shaft so
## it lands in the drill (the demand-web; the drill won't pull ore without coal).
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


## Step 6. Stand back and let the fueled line run until it pours ingots on its own (no further input).
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
## directly above (which only a real tree-top has; a bazaar frame post has wood or sky above it, never
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
	# Stand just outside the frame on the RIGHT (spawn/shaft) side; the whole hand-work + shaft lie to its
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


## The nearest solid ORE cell to the body that is NOT in the mineshaft column, so hand-mining the
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


## Assert a friction journey's byproduct-effort stays under its ceiling, so a MOVEMENT REGRESSION (digging
## and climbing back gets more punishing) FAILS the harness, not just prints a bigger number. Ceilings sit
## ~1.6× above today's baseline: normal real-time variance passes, a doubling trips. RATCHET these DOWN as
## the mobility tools (rope/lift) land and these numbers should plummet; that's the whole point of them.
func _within_ceilings(agent: PlayAgent, ceilings: Dictionary) -> bool:
	var ok: bool = true
	for metric: String in ceilings:
		var val: int = int(agent.get(metric))
		var cap: int = int(ceilings[metric])
		if val > cap:
			printerr("    friction CEILING breached: %s=%d > %d (movement got more punishing)" % [metric, val, cap])
			ok = false
	return ok


## Record this try's verdict, tear the scene down, and return whether the goal was met. On a miss it
## stashes the agent's trace + the label so _attempt can print them if BOTH tries fail.
func _finish(agent: PlayAgent, ok: bool, label: String) -> bool:
	if not ok:
		_last_trace = agent.trace.duplicate()
		_last_trace.append(label)
	await _teardown(agent)
	return ok
