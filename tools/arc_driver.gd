extends RefCounted

## THE FIRST-AUTOMATION ARC, ONCE.
##
## This is the opening of the game played by a machine: dig ore → smelt → chop wood → claim the Bazaar →
## research → craft → build → fuel → automate, driven entirely through the same public, reach-gated verbs a
## human drives (try_mine / try_build / try_drop / try_research / …) and following the on-screen objective
## ladder in scenes/objectives.gd step for step. PlayAgent does all the navigation; this only decides WHAT
## the signpost is asking for and performs it.
##
## It lives on its own because more than one harness layer needs to play the same opening and they must be
## playing the SAME one: check_loop_health scores how the arc FEELS to drive, check_pacing scores the SHAPE
## of the news it produces. Two copies of an arc are two arcs, and the day they drift is the day the two
## numbers stop being about the same game.
##
## Nothing in here asserts anything. It plays, and it returns whether the play reached its goal.

const DRILL: String = "res://src/data/machines/drill.tres"


## Play the objective ladder from wherever it currently stands up to and including `until` (the first-
## automation step by default; the gentle L1→L2 handoff steps after it are a later rung's journey).
## Reasons a step could not be carried out go into the agent's own trace. Returns whether `until` ended up
## satisfied.
func play(agent: PlayAgent, obj: Objectives, until: StringName = &"auto") -> bool:
	for step: Dictionary in obj.steps:
		var id: StringName = step["id"]
		if obj.is_done(id):
			if id == until:
				break                                             # already there
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
		if id == until:
			break
	return obj.is_done(until)


## How many ladder steps `play` will actually run for a given stopping point — what a pace par is per-step
## of, so the par and the play are always describing the same number of steps.
static func step_count(obj: Objectives, until: StringName = &"auto") -> int:
	for i: int in obj.steps.size():
		if obj.steps[i]["id"] == until:
			return i + 1
	return obj.steps.size()


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
	# EVERY GIVE-UP SAYS WHY. Corpus seed 20260817 failed this step and the only thing recorded anywhere
	# was "could not perform signposted step 'smelt'", which names the step and not the reason. Of the
	# four ways out of this function only `walk_to_column` was writing a note, so a failure here was a
	# fact with no cause attached and no way to tell the three remaining branches apart.
	if not await agent.select_item(&"ore"):
		agent._note("smelt: no ore in the pack to select (carrying %d)"
			% int(agent.sim.inventory.get(&"ore", 0)))
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
		await agent.wait(20)
	var got: int = int(agent.sim.inventory.get(&"ingot", 0))
	if got < 2:
		agent._note("smelt: the forge gave up %d ingot(s) of 2 in %d tries (ore left in pack: %d)"
			% [got, guard, int(agent.sim.inventory.get(&"ore", 0))])
	return got >= 2


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
	return int(agent.sim.inventory.get(&"drill", 0)) >= 1 or has_drill(agent)


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
	while not drill_has_fuel(agent) and guard2 < 14:
		guard2 += 1
		agent.main.try_drop()
		await agent.wait(6)
	return drill_has_fuel(agent)


## Step 9 — stand back and let the fueled line run until it pours ingots on its own.
func _step_auto(agent: PlayAgent) -> bool:
	await agent.wait(200)
	return true


# --- step helpers ---------------------------------------------------------------------------------

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
			await agent.wait(30)
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
		# AND NOT THE FORGE COLUMN, for the same reason the shaft is excluded: this returns a target for
		# `dig_down_to`, which sinks a COLUMN, and the bootstrap forge sits in the middle of this one at
		# `MINESHAFT_FORGE_CELL` = (46, 20). Ore below it cannot be reached by digging down from the
		# surface, because the machine is in the way and a machine is not a block you can mine through.
		#
		# On corpus seed 512 the nearest ore during the research step was (46, 29), nine rows under the
		# forge. The agent walked to (46, 19), stood on its own forge, and dug at it until the budget ran
		# out, four times, which is the `guard < 4` in `_step_research`. That is 9632 frames, 92% of the
		# session, and it is the whole of why two of eight seeds never reach first automation.
		#
		# The search had no idea. It is a pure distance scan over `sim.solid` with one column excluded,
		# so "nearest" meant nearest in a straight line and never asked whether the digger could get
		# there. This makes the second exclusion explicit rather than teaching the scan about geometry.
		if c.x == MainView.MINESHAFT_FORGE_CELL.x:
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
static func drill_has_fuel(agent: PlayAgent) -> bool:
	for m: MachineState in agent.sim.machines:
		if m.def.behavior == &"drill" and (m.fuel > 0 or int(m.input_buffer.get(&"coal", 0)) > 0):
			return true
	return false


## Whether a Drill machine is placed anywhere.
static func has_drill(agent: PlayAgent) -> bool:
	for m: MachineState in agent.sim.machines:
		if m.def.behavior == &"drill":
			return true
	return false
