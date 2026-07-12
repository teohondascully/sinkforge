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
		["RUNG 2 — breach the seal into L2", _goal_breach_the_seal],
		# FRICTION journeys — the BYPRODUCT experiences a real player MUST go through (the descent, and above
		# all the climb back UP), measured for effort, not just did-it-happen. These are where the game earns
		# "fun & frictionless" or fails it. A FAIL here = the player gets trapped / the loop is exhausting.
		["friction: round-trip to a buried vein", _goal_round_trip_to_vein],
		["friction: descend, build a drill, climb out", _goal_descend_build_return],
		["friction: escape a deep pit (not trapped)", _goal_escape_deep_pit],
		["friction: cross a jagged tunnel", _goal_cross_jagged_tunnel],
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


## RUNG 2 — the L1→L2 GATE is playable end-to-end (docs/PROGRESSION.md §2): descend a shaft to THE SEAL,
## stand a Descent Engine ON it, climb out, FEED it by tossing ingots down the shaft (gravity is the
## feeder — the hook working as the gate's conveyor), watch the BREACH open, drop through into
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
	                                                         # exit-cycle re-anchors — rope economy isn't what
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
	# mouth row `top`, not top-1 — the neighbouring ground can naturally sit a row lower than the mouth.)
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
	# 5. The prize: mine the IRON under your feet — the first touch of L2's new material.
	var iron := Vector2i(col + 1, LayeredWorldGen.SEAL_TOP + LayeredWorldGen.SEAL_ROWS)
	var g: int = 0
	while sim.is_solid(iron) and g < 40:
		agent.do_mine(iron)
		await agent.wait(4); g += 1
	if int(sim.inventory.get(&"iron", 0)) < 1:
		return await _finish(agent, false, "stood in L2 but could not mine the iron")
	# 6. And home — the whole loop closes on the surface.
	var home: bool = await agent.climb_to_surface(top, 6000)
	print("  gate: %s  (iron=%d home=%s)" % [agent.friction(), int(sim.inventory.get(&"iron", 0)), home])
	return await _finish(agent, home, "breached the seal, mined L2 iron, and returned to the surface")


func _engine_fed(agent: PlayAgent) -> int:
	for m: MachineState in agent.sim.machines:
		if m.def.behavior == &"descent":
			return m.fed
	return -1


# --- FRICTION journeys ----------------------------------------------------------------------------
# These model the WHOLE realistic user experience, not just the headline verb. A player who wants to
# "drill a buried vein" doesn't teleport there — they dig DOWN to it (byproduct), do the thing, then
# claw their way back UP (the big one). We PLAY those byproduct steps and print the effort (friction())
# so we can SEE the game get less painful as mobility tools land. Blocks are topped up (setup hatch) so a
# journey measures TRAVERSAL friction, not resource starvation — the pit/shaft is what we're testing.

## Fill a clean vertical column of earth from the surface down to `depth` below it and bury an ore vein at
## the bottom — a deterministic shaft to dig, so the friction numbers are comparable run to run.
func _bury_vein(agent: PlayAgent, col: int, depth: int) -> Vector2i:
	var target := Vector2i(col, MainView.SURFACE + depth)
	for y: int in range(MainView.SURFACE, target.y):
		agent.sim.set_solid(Vector2i(col, y), &"earth")     # a clean earthen column (no caves/gaps to complicate)
	agent.sim.set_solid(target, &"ore")
	agent.sim.deposits[target] = 40
	agent.sim.set_solid(Vector2i(col, target.y + 1), &"stone")  # a floor under the vein
	return target


## Round-trip: dig DOWN to a buried vein, mine it, and climb back to the SURFACE. The most common real loop
## and the friction the user named — "mine down, then mine a staircase back up". Pass = ore in hand AND body
## back on the surface (not stranded). Friction printed so we watch it drop when the rope lands.
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
	# pillar-jumping; the rope ride measures places=3 jumps=1 frames=58 — locked in so it can't regress).
	var within: bool = _within_ceilings(agent, {"mines": 15, "places": 6, "jumps": 4, "frames": 120})
	return await _finish(agent, dug and got >= 1 and up and within,
		"dug to the buried vein, mined it, and climbed back to the surface")


## A DEEP round-trip — the same journey as the shallow one but to a vein twice as far down, so the friction
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
	# measures places=6 jumps=1 frames=111 — the deep climb no longer scales in pain, locked in).
	var within: bool = _within_ceilings(agent, {"mines": 24, "places": 10, "jumps": 4, "frames": 200})
	return await _finish(agent, dug and got >= 1 and up and within,
		"dug 14 deep to a vein, mined it, and climbed all the way back out")


## The pure "am I TRAPPED?" test: drop the body into a deep 1-wide pit (walls solid both sides) with blocks
## in the pack, and require it to get out. If it can't, the player is stranded at the bottom of their own
## shaft — the worst friction this game could ship. DELIBERATELY ROPE-LESS: this journey guards the
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
	var within: bool = _within_ceilings(agent, {"places": 12, "jumps": 12, "frames": 220})
	return await _finish(agent, up and within, "climbed out of a %d-deep pit (must not be trapped)" % depth)


## Cross a JAGGED horizontal tunnel (up-and-down 1-tile steps, like a natural cave floor) — the finicky
## cave-traversal the user flagged as feeling bad. Pass = reaches the far end; the friction (stuck_frames,
## jumps) is the read on how AGILE lateral cave movement feels.
func _goal_cross_jagged_tunnel() -> bool:
	var agent: PlayAgent = await _boot()
	var start_col: int = 57                                  # clean plateau, right of the fixtures; length stays < FLAT_END
	var length: int = 8
	var base: int = MainView.SURFACE + 4
	# Carve a corridor with a FLAT ceiling well above the highest lump and a FLOOR that jitters ±1 tile each
	# column (a lumpy cave floor). The ceiling clears rows down to the highest lump so undulating floors never
	# leave original terrain protruding into the walk path — the body only ever meets ±1 floor steps.
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
	# Just WALK it (hold toward the far column, hop only when genuinely stuck) — the way a player crosses a
	# lumpy floor. This isolates the BODY's step-up/snap-down over ±1 lumps from the pathfinder's cleverness.
	var far_col: int = start_col + length - 1
	var reached: bool = await agent.walk_to_column(far_col, 1200)
	print("  friction: %s  (reached=%s at col %d)" % [agent.friction(), reached, agent.main._cell_at(agent.player.position).x])
	var within: bool = _within_ceilings(agent, {"jumps": 8, "stuck_frames": 40})
	return await _finish(agent, reached and within, "walked a %d-cell jagged tunnel end to end" % length)


## Perform the real-verb action a single objective step asks for. Each branch uses only what a player has:
## the body, reach, and the hotbar. Returns whether the action could be carried out at all.
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
## (research) and the drill craft — both real ore→ingot labour through the real verbs.
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


## Step — RESEARCH Automation at the bench: earn the bench price (2 ingots), keep an ore SAMPLE to
## analyze, then stand at the Bazaar and research. The PULL the chain funnels through — the drill stays
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


## Step 5 — craft a Drill AT the Bazaar: earn its ingot price (research just spent the last batch), then
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


## Assert a friction journey's byproduct-effort stays under its ceiling — so a MOVEMENT REGRESSION (digging
## and climbing back gets more punishing) FAILS the harness, not just prints a bigger number. Ceilings sit
## ~1.6× above today's baseline: normal real-time variance passes, a doubling trips. RATCHET these DOWN as
## the mobility tools (rope/lift) land and these numbers should plummet — that's the whole point of them.
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
