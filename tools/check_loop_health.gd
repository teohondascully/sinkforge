extends SceneTree

## Harness layer — LOOP HEALTH, scored (an AUTOMATED proxy for a human early-game playtest). check_agility
## turned "does MOVEMENT feel awkward?" into a number; this turns "does the FIRST-AUTOMATION LOOP feel good
## to play?" into a number. A PlayAgent boots a FRESH game and plays the real RUNG-1 arc — dig ore → smelt →
## chop wood → claim the Bazaar → research → craft → build → fuel → automate — through the same public,
## reach-gated verbs a human drives (try_mine/try_build/try_drop/try_research/…), following the on-screen
## objective ladder (scenes/objectives.gd) exactly like RUNG 1 in play_tests.gd.
##
## While it plays it SAMPLES per physics frame and scores three feel-penalties (mirrors check_agility's
## style — a printed breakdown, a ratcheting floor, component caps that a real regression trips):
##   1. COMPLETION — a GATE, not a score: the arc MUST reach first automation within a frame budget, else
##      the whole layer FAILS (the non-negotiable "the loop is playable to its first goal").
##   2. PACE — total frames to completion vs a generous per-step par. Over par → the loop drags.
##   3. FRICTION — stall frames (the body steered/acted but went nowhere) accumulated across the play. The
##      literal "this is awkward" feel, reusing the agent's own stuck_frames instrumentation.
##   4. GUIDANCE-GAP — the KEY new signal: frames where the current objective is UNMET yet the game offers
##      NO reachable world guide target for a step that is SUPPOSED to point somewhere (MainView._guide_targets
##      is empty on a spatial step). That's the "what do I do now?" / lost feeling — weighted heaviest.
##   score = max(0, 100 - pace_pen - friction_pen - guidance_gap_pen).
##
## Real-time physics + heuristic navigation make the numbers slightly noisy, so (like play_tests' friction
## ceilings) the floor keeps generous headroom under the measured baseline. RATCHET the floor UP as the loop
## improves. If the arc can't complete at all, that's a hard FAIL — the loop dead-ended, the worst outcome.
##   godot --headless --path . --script res://tools/check_loop_health.gd

const SCENE: String = "res://scenes/main.tscn"
const AGENT := preload("res://tools/play_agent.gd")
const DRILL: String = "res://src/data/machines/drill.tres"


## A tiny sampler Node parented into the live tree so it ticks EVERY physics frame (SceneTree isn't a Node,
## and the arc runs deep inside PlayAgent coroutines we can't hook per-frame). Each frame it calls back into
## the check with the live MainView, which reads the same guide-target surface the renderer draws.
class Sampler extends Node:
	var on_frame: Callable
	func _ready() -> void:
		process_priority = 1000        # sample AFTER MainView._process has pushed the frame's guide targets
	func _physics_process(_delta: float) -> void:
		if on_frame.is_valid():
			on_frame.call()

## The steps that MainView is DESIGNED to point at with a world-space guide cell (mine/smelt/wood/bazaar/build
## return a target from _guide_targets; research/craft/fuel/auto are legitimately text-only). A guidance-gap
## frame = the current step is one of THESE yet no target is offered — the game promised a "do it HERE" and
## has none. (A regression that empties the guide overlay lights every spatial frame → the score drops.)
const SPATIAL_STEPS: Array[StringName] = [&"mine", &"smelt", &"wood", &"bazaar", &"build"]

## Frame allowance per objective step at 1× time scale — generous (walking + mining + smelting take real
## time, and each step boots from wherever the last left the body). par = steps × this. The clean run lands
## well under it; the pace penalty only bites when the loop genuinely drags.
const FRAMES_PER_STEP_PAR: int = 700

## Score floor + component caps — headroom under today's MEASURED baseline so real-time variance passes but
## a REGRESSION (the loop drags, the body thrashes, or the game stops signposting) trips the layer. RATCHET
## the floor UP as the loop improves, exactly like the friction ceilings in play_tests. (Ratcheted 2026-08-09:
## floor 70→90 — the arc measured 98.7 dead-stable across 3 runs, so a SMALLER dip now trips; 8.7 of margin
## still absorbs the per-frame stall/guidance jitter. The component *_PEN_CAP bounds stay generous CLAMP
## bounds — the SCORE_FLOOR is the meaningful ratchet; tightening the clamps risks flaking the score math.)
const SCORE_FLOOR: float = 90.0       ## baseline 98.7, floor 90.0
const PACE_PEN_CAP: float = 25.0
const FRICTION_PEN_CAP: float = 25.0
const GUIDANCE_PEN_CAP: float = 40.0

## Per-component weights.
const PACE_PEN_PER_OVER: float = 25.0        ## penalty for each 1.0× the frames run OVER par (clamped by cap)
const FRICTION_PEN_PER_STALL: float = 0.10   ## per stall-frame (mirrors check_agility's stall weighting, capped)
const GUIDANCE_PEN_PER_GAP: float = 0.20     ## per lost-frame — the heaviest per-frame weight (the lost feeling)

var _failures: int = 0
var _agent: PlayAgent = null

## Per-play sampled tallies (reset each play).
var _guidance_gap_frames: int = 0
var _sampled_frames: int = 0


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


func _initialize() -> void:
	print("== loop-health check ==")
	MainView.dev_start = false      # score a CLEAN boot (no dev kit) — the real new-player early game
	await _run()
	if _failures == 0:
		print("LOOP HEALTH OK")
		quit(0)
	else:
		printerr("%d FAILURE(S)" % _failures)
		quit(1)


func _run() -> void:
	var agent: PlayAgent = await _boot()
	var obj: Objectives = agent.main._objectives
	# The scored arc runs THROUGH "auto" (first automation); the gentle handoff steps after it are RUNG 2's.
	# Par must reflect the steps actually played, so measure the ladder up to and including "auto".
	var step_count: int = obj.steps.size()
	for i: int in obj.steps.size():
		if obj.steps[i]["id"] == &"auto":
			step_count = i + 1
			break
	var par: int = step_count * FRAMES_PER_STEP_PAR

	# Install the per-physics-frame sampler INTO the live tree (ticks after MainView pushes its guide
	# targets each frame), so the guidance-gap + sample-frame tallies cover the WHOLE play, not just the
	# outer loop's latch-waits. It reads the same surface the renderer draws (_guide_targets).
	_guidance_gap_frames = 0
	_sampled_frames = 0
	var sampler := Sampler.new()
	sampler.on_frame = func() -> void: _sample(agent)
	agent.main.add_child(sampler)

	# --- play the RUNG-1 arc; the sampler runs every frame throughout --------------------------------
	var frames0: int = Engine.get_physics_frames()
	var completed: bool = await _play_arc(agent, obj)
	var frames: int = maxi(1, int(Engine.get_physics_frames() - frames0))
	var stalls: int = agent.stuck_frames
	sampler.queue_free()

	# --- the LOOP-HEALTH SCORE -----------------------------------------------------------------------
	var pace: float = float(frames) / float(par)                          # 1.0 = exactly at par
	var pace_pen: float = clampf((pace - 1.0) * PACE_PEN_PER_OVER, 0.0, PACE_PEN_CAP)
	var friction_pen: float = clampf(float(stalls) * FRICTION_PEN_PER_STALL, 0.0, FRICTION_PEN_CAP)
	var guidance_pen: float = clampf(float(_guidance_gap_frames) * GUIDANCE_PEN_PER_GAP, 0.0, GUIDANCE_PEN_CAP)
	var score: float = maxf(0.0, 100.0 - pace_pen - friction_pen - guidance_pen)

	print("  arc: completed=%s steps=%d  |  frames=%d par=%d pace=%.2fx stalls=%d guidance_gap=%d/%d frames"
		% [completed, step_count, frames, par, pace, stalls, _guidance_gap_frames, _sampled_frames])
	print("  penalties: pace=-%.1f (cap %.0f) friction=-%.1f (cap %.0f) guidance=-%.1f (cap %.0f)  =>  LOOP-HEALTH SCORE = %.1f / 100"
		% [pace_pen, PACE_PEN_CAP, friction_pen, FRICTION_PEN_CAP, guidance_pen, GUIDANCE_PEN_CAP, score])

	# GATE first: an incomplete arc is a hard fail regardless of the number (the loop dead-ended).
	_check(completed, "the first-automation arc COMPLETES (the loop is playable to its first goal)")
	_check(pace_pen <= PACE_PEN_CAP, "pace penalty within cap (-%.1f <= %.0f)" % [pace_pen, PACE_PEN_CAP])
	_check(friction_pen <= FRICTION_PEN_CAP, "friction penalty within cap (-%.1f <= %.0f)" % [friction_pen, FRICTION_PEN_CAP])
	_check(guidance_pen <= GUIDANCE_PEN_CAP, "guidance-gap penalty within cap (-%.1f <= %.0f)" % [guidance_pen, GUIDANCE_PEN_CAP])
	_check(score >= SCORE_FLOOR, "LOOP-HEALTH SCORE %.1f >= floor %.1f" % [score, SCORE_FLOOR])

	agent.main.queue_free()
	await physics_frame


## Play the FIRST-AUTOMATION arc, doing ONLY what each signpost says (like RUNG 1), and SAMPLING per frame
## throughout: guidance-gap frames (a spatial step with no offered target) and the agent's own stall count.
## Stops at the "auto" step — the gentle L1→L2 handoff steps after it (power/generator/descent/breach) are
## RUNG 2's journey; this metric scores the loop's playability to its FIRST goal. Returns whether it reached
## first automation.
func _play_arc(agent: PlayAgent, obj: Objectives) -> bool:
	for step: Dictionary in obj.steps:
		var id: StringName = step["id"]
		if obj.is_done(id):
			if id == &"auto":
				break                                             # first automation already reached
			continue
		var acted: bool = await _do_step(agent, id)
		if not acted:
			agent._note("could not perform signposted step '%s'" % id)
			return false
		var t: int = 0
		while not obj.is_done(id) and t < 240:                    # give the chain a beat to latch
			await agent.step()
			t += 1
		if not obj.is_done(id):
			agent._note("did '%s' but the objective never ticked" % id)
			return false
		if id == &"auto":
			break                                                 # first automation reached — the arc's goal
	return obj.is_done(&"auto")


## Sample the CURRENT-frame feel signal: if the active objective is a spatial step (one MainView is designed
## to point at) but offers no reachable guide cell, that's a "what do I do now?" frame. Read through the same
## public surface the renderer does (_guide_targets), so this measures exactly what the player would see.
func _sample(agent: PlayAgent) -> void:
	_sampled_frames += 1
	var obj: Objectives = agent.main._objectives
	if obj == null or obj.all_done():
		return
	var id: StringName = obj.current_id()
	if id in SPATIAL_STEPS and agent.main._guide_targets().is_empty():
		_guidance_gap_frames += 1


# --- the RUNG-1 step driver (faithful to play_tests.gd; PlayAgent does all the real navigation) --------

## Perform the real-verb action a single objective step asks for — one branch per signpost, using only the
## body, reach, and the hotbar. Returns whether the action could be carried out at all.
func _do_step(agent: PlayAgent, id: StringName) -> bool:
	match id:
		&"mine":     return await _step_mine(agent)
		&"smelt":    return await _step_smelt(agent)
		&"wood":     return await _step_wood(agent)
		&"bazaar":   return await _step_bazaar(agent)
		&"research": return await _step_research(agent)
		&"craft":    return await _step_craft(agent)
		&"build":    return await _step_build(agent)
		&"fuel":     return await _step_fuel(agent)
		&"auto":     return await _step_auto(agent)
	return false


## Step 1 — hand-dig the bootstrap ore (4) from the starter vein near spawn (never the mineshaft's vein, so
## the automated line's vein stays intact).
func _step_mine(agent: PlayAgent) -> bool:
	var guard: int = 0
	while int(agent.sim.inventory.get(&"ore", 0)) < 4 and guard < 8:
		guard += 1
		var ore: Vector2i = _nearest_ore_not_shaft(agent)
		if ore.x < 0:
			return false
		await agent.dig_down_to(ore)
	return int(agent.sim.inventory.get(&"ore", 0)) >= 4


## Step 2 — toss surface ore into the bootstrap forge, let it smelt, stand by the pocket to reach-collect 2
## ingots.
func _step_smelt(agent: PlayAgent) -> bool:
	if not await agent.select_item(&"ore"):
		return false
	var bf: Vector2i = MainView.MINESHAFT_FORGE_CELL
	if not await agent.walk_to_column(bf.x - 1):
		return false
	agent.player.facing = 1
	agent.main.try_drop()
	var collect: Vector2i = bf + Vector2i(0, 1)
	var guard: int = 0
	while int(agent.sim.inventory.get(&"ingot", 0)) < 2 and guard < 30:
		guard += 1
		await agent.approach(collect)
		for _i: int in 20:
			await physics_frame
	return int(agent.sim.inventory.get(&"ingot", 0)) >= 2


## Step 3 — chop one trunk block of the nearest tree for wood (enough to claim the bazaar).
func _step_wood(agent: PlayAgent) -> bool:
	var base: Vector2i = _nearest_tree_base(agent)
	if base.x < 0:
		return false
	await agent.mine_cell(base, 1400)
	return int(agent.sim.inventory.get(&"wood", 0)) >= 1


## Step 4 — claim the Bazaar: place one wood block in the gap of the ruined frame near spawn.
func _step_bazaar(agent: PlayAgent) -> bool:
	var gap: Vector2i = agent.sim.bazaar_completion_cell()
	if gap.x < 0:
		return false
	if not await agent.select_item(&"wood"):
		return false
	if not await agent.build_at(gap):
		return false
	return not agent.sim.find_bazaars().is_empty()


## Step 5 — research Automation at the bench: earn the ingot price, keep an ore SAMPLE, then research at the
## Bazaar (the drill stays locked until this opens it).
func _step_research(agent: PlayAgent) -> bool:
	if agent.sim.is_researched(&"automation"):
		return true
	var price: int = int(ResearchRules.tech(&"automation")["cost"].get(&"ingot", 0))
	if not await _ensure_ingots(agent, price):
		return false
	var guard: int = 0
	while int(agent.sim.inventory.get(&"ore", 0)) < 1 and guard < 4:
		guard += 1
		var ore: Vector2i = _nearest_ore_not_shaft(agent)
		if ore.x < 0:
			return false
		await agent.dig_down_to(ore)
		await agent.climb_to_surface(MainView.SURFACE - 1)
	if not await _walk_to_bazaar(agent):
		return false
	return agent.main.try_research(&"automation")


## Step 6 — craft a Drill AT the Bazaar: earn its price, then walk to the stall and craft (gated on proximity).
func _step_craft(agent: PlayAgent) -> bool:
	var price: int = int((load(DRILL) as MachineDef).craft_cost.get(&"ingot", 0))
	if not await _ensure_ingots(agent, price):
		return false
	if not await _walk_to_bazaar(agent):
		return false
	if not agent.craft(load(DRILL)):
		return false
	return int(agent.sim.inventory.get(&"drill", 0)) >= 1 or _has_drill(agent)


## Step 7 — drop the Drill above the mineshaft vein (boring model): reach in from the shaft edge.
func _step_build(agent: PlayAgent) -> bool:
	if not await agent.walk_to_column(MainView.MINESHAFT_COL - 1):
		return false
	var d: Vector2i = MainView.MINESHAFT_DRILL_CELL
	if agent.sim.drill_column_remaining(d) <= 0:
		return false
	if not await agent.select_item(&"drill"):
		return false
	if not await agent.build_at(d):
		return false
	return agent.sim.machine_at(d) != null


## Step 8 — fuel the Drill: mine the coal vein, then toss coal down the open shaft onto the drill.
func _step_fuel(agent: PlayAgent) -> bool:
	var guard: int = 0
	while int(agent.sim.inventory.get(&"coal", 0)) < 3 and guard < 6:
		guard += 1
		var coal: Vector2i = _nearest_coal(agent)
		if coal.x < 0:
			break
		await agent.dig_down_to(coal)
	if int(agent.sim.inventory.get(&"coal", 0)) < 1:
		return false
	if not await agent.select_item(&"coal"):
		return false
	if not await agent.walk_to_column(MainView.MINESHAFT_COL - 1):
		return false
	agent.player.facing = 1
	var guard2: int = 0
	while not _drill_has_fuel(agent) and guard2 < 14:
		guard2 += 1
		agent.main.try_drop()
		for _i: int in 6:
			await physics_frame
	return _drill_has_fuel(agent)


## Step 9 — stand back and let the fueled line run until it pours ingots on its own.
func _step_auto(agent: PlayAgent) -> bool:
	for _i: int in 200:
		await physics_frame
	return true


# --- step helpers (faithful to play_tests.gd) -----------------------------------------------------

## Earn `want` ingots the tutorial way: mine starter veins, toss ore into the bootstrap forge, reach-collect.
func _ensure_ingots(agent: PlayAgent, want: int) -> bool:
	var guard: int = 0
	while int(agent.sim.inventory.get(&"ingot", 0)) < want and guard < 12:
		guard += 1
		if int(agent.sim.inventory.get(&"ore", 0)) < 2:
			var ore: Vector2i = _nearest_ore_not_shaft(agent)
			if ore.x < 0:
				return false
			await agent.dig_down_to(ore)
			await agent.climb_to_surface(MainView.SURFACE - 1)
			continue
		if not await agent.select_item(&"ore"):
			return false
		if not await agent.walk_to_column(MainView.MINESHAFT_FORGE_CELL.x - 1):
			return false
		agent.player.facing = 1
		agent.main.try_drop()
		var collect: Vector2i = MainView.MINESHAFT_FORGE_CELL + Vector2i(0, 1)
		var last: int = -1
		var settled: int = 0
		while settled < 3 and int(agent.sim.inventory.get(&"ingot", 0)) < want:
			await agent.approach(collect)
			for _i: int in 30:
				await physics_frame
			var now: int = int(agent.sim.inventory.get(&"ingot", 0))
			settled = settled + 1 if now == last else 0
			last = now
	return int(agent.sim.inventory.get(&"ingot", 0)) >= want


## Walk to within crafting range of a claimed Bazaar (stand just outside the frame on the work side).
func _walk_to_bazaar(agent: PlayAgent) -> bool:
	var bzs: Array[Vector2i] = agent.sim.find_bazaars()
	if bzs.is_empty():
		return false
	await agent.walk_to_column(bzs[0].x + FactorySim.BAZAAR_W)
	return agent.main._near_bazaar()


## The nearest solid ORE cell that is NOT the mineshaft column (so hand-mining never eats the drill's vein).
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


## The base (lowest) trunk cell of the nearest TREE — a wood cell crowned by leaves (a real trunk top, not a
## bazaar-frame post), then descend that column to its base.
func _nearest_tree_base(agent: PlayAgent) -> Vector2i:
	var top := Vector2i(-1, -1)
	var best_d: float = INF
	for cell: Variant in agent.sim.solid:
		var c: Vector2i = cell
		if agent.sim.solid[c] != &"wood":
			continue
		if agent.sim.solid.get(c + Vector2i(0, -1), &"") != &"leaves":
			continue
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


## Whether a Drill machine is placed anywhere.
func _has_drill(agent: PlayAgent) -> bool:
	for m: MachineState in agent.sim.machines:
		if m.def.behavior == &"drill":
			return true
	return false


# --- scaffolding ----------------------------------------------------------------------------------

## Boot a fresh game scene and let the body settle, then hand back a PlayAgent driving it.
func _boot() -> PlayAgent:
	var main: MainView = (load(SCENE) as PackedScene).instantiate()
	get_root().add_child(main)
	for _i: int in 30:                       # _ready runs on add; let the body fall + land
		await physics_frame
	_agent = AGENT.new(self, main)
	return _agent
