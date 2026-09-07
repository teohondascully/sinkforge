extends "res://tests/test_base.gd"
## The moments of `view/hud/hints.gd` that read a situation off the observation, one pin set each: THE
## WAY DOWN (D0440), STILL WORKING (D0461), BEHIND ROCK (D0452), NOT ORE (D0450, D0458) and WRONG STACK
## (D0443). Split from `test_hints.gd` at the size limit; the queue, the edges and the clock stay there.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_hints_moments.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_way_down_pins()
	_test_wrong_stack_pins()
	_test_mined_wrong_pins()
	_test_sight_pins()
	_test_cut_through_pins()
	_test_wrong_spot_pins()
	_test_far_below_pins()
	_test_left_working_pins()
	_finish("hints_moments")


## T037 (D0440, stranger 15): a body that has broken rock once and walked the surface WAY_DOWN_RANGE_M across
## without standing WAY_DOWN_DEPTH_M down is told the ground is the way; one that went down already is not.
func _test_way_down_pins() -> void:
	var h: Hints = Hints.new()
	var m: int = Interface.Observation.LOGIC_PX * S
	var o: Interface.Observation = _hint_obs()
	o.cell.y = Interface.Observation.SKY_ROWS - 2               # standing on the surface
	o.mining_broke = true
	h.observe(o, 0.016)
	o.mining_broke = false
	for i: int in 30:
		o.pos_x = i * m                                          # 29 m of walking, one metre a frame
		h.observe(o, 0.016)
		if h.active_id() == &"way_down":
			break
	_check(h.active_id() == &"way_down" and h.active_text().begins_with("THE WAY DOWN") and float(o.pos_x) / float(m) >= Hints.WAY_DOWN_RANGE_M,
		"the surface walked %.0f m across with rock broken once and nothing dug teaches THE WAY DOWN (%s)" % [float(o.pos_x) / float(m), h.active_id()])
	var h2: Hints = Hints.new()
	var deep: Interface.Observation = _hint_obs()
	deep.cell.y = Interface.Observation.SKY_ROWS + int(Hints.WAY_DOWN_DEPTH_M + 1.0) * 4   # five metres down once
	deep.mining_broke = true
	h2.observe(deep, 0.016)
	deep.mining_broke = false
	deep.cell.y = Interface.Observation.SKY_ROWS - 2
	for i: int in 40:
		deep.pos_x = i * m
		h2.observe(deep, 0.016)
	_check(h2.active_id() == &"" and h2.queued() == 0, "control: a body that once stood five metres down is not told, however far it walks (%s)" % h2.active_id())
	var h3: Hints = Hints.new()
	var never: Interface.Observation = _hint_obs()
	never.cell.y = Interface.Observation.SKY_ROWS - 2
	for i: int in 40:
		never.pos_x = i * m
		h3.observe(never, 0.016)
	_check(h3.active_id() == &"" and h3.queued() == 0, "control: a body that has never broken rock is not told either -- the verb comes first (%s)" % h3.active_id())


## D0443 (stranger 16): clay dropped on the floor beside a forge that takes ore, with ore in the pack, teaches
## WRONG STACK with both names filled in; ore dropped short of the same forge is the BESIDE lesson's case.
## D0450 (stranger 26): a break whose yield is not ore, with no ore in the pack, teaches NOT ORE once and names
## what fell; an ore break, a pack already holding ore, or a session past THE WAY DOWN, teaches nothing.
## D0461 (strangers 37, 38): out of reach of a forge that still holds your ore, with no ingot gained, is
## STILL WORKING with the count still to come; the same walk after the forge emptied into the pack is not.
func _test_left_working_pins() -> void:
	var forge: Dictionary = {"cell": Vector2i(11, 10), "id": &"processor", "recipe": &"smelt_ingot", "input": {&"ore": 2, &"coal": 1}, "output": {}}   # D0483: a craft is 2 ore + 1 coal
	var h: Hints = Hints.new()
	var near: Interface.Observation = _hint_obs([["ingot", 1]])
	near.pos_x = 10 * 16 * S
	near.pos_y = 10 * 16 * S
	var typed: Array[Dictionary] = [forge]
	near.machines = typed
	h.observe(near, 0.016)
	var away: Interface.Observation = _hint_obs([["ingot", 1]])
	away.pos_x = 30 * 16 * S
	away.pos_y = 10 * 16 * S
	away.machines = typed
	h.observe(away, 0.016)
	_check(h.active_id() == &"left_working" and h.active_text().find("1 more coming") >= 0, "a step out of reach of a forge holding two ore, no ingot gained: STILL WORKING, 1 more coming (%s: %s)" % [h.active_id(), h.active_text().right(24)])
	var h2: Hints = Hints.new()
	h2.observe(near, 0.016)
	var done: Interface.Observation = _hint_obs([["ingot", 2]])
	done.pos_x = 30 * 16 * S
	done.pos_y = 10 * 16 * S
	var empty: Array[Dictionary] = [{"cell": Vector2i(11, 10), "id": &"processor", "recipe": &"smelt_ingot", "input": {}, "output": {}}]
	done.machines = empty
	h2.observe(done, 0.016)
	_check(h2.active_id() == &"" and h2.queued() == 0, "control: the forge emptied into the pack and the walk away teaches nothing (%s)" % h2.active_id())


## D0452: the "sight" refusal held FAR_TICKS teaches BEHIND ROCK once; a brush teaches nothing.
func _test_sight_pins() -> void:
	var h: Hints = Hints.new()
	var behind: Interface.Observation = _hint_obs()
	behind.aim_refusal = &"sight"
	for _i: int in Hints.FAR_TICKS - 1:
		h.observe(behind, 0.016)
	_check(h.active_id() == &"", "a brush past a buried cell (%d ticks) teaches nothing yet" % (Hints.FAR_TICKS - 1))
	h.observe(behind, 0.016)
	_check(h.active_id() == &"aim_sight" and h.active_text().begins_with("BEHIND ROCK"), "the %dth tick on a cell behind rock fires BEHIND ROCK (%s)" % [Hints.FAR_TICKS, h.active_id()])


## D0467 (strangers 46 and 48): a hold whose own bite opened the pointer's cell runs on air; half a second
## of that is CUT THROUGH, and NOTHING THERE stays quiet for it. Air with no bite behind it keeps the old
## lesson at its own time.
func _test_cut_through_pins() -> void:
	var h: Hints = Hints.new()
	var bite: Interface.Observation = _hint_obs()
	bite.mining_broke = true
	bite.mining_broke_material = &"ore_iron"                       # ore, so NOT ORE stays out of the way
	var air: Interface.Observation = _hint_obs()
	air.aim_refusal = &"air"
	h.observe(bite, 0.016)
	for _i: int in Hints.CUT_TICKS - 1:
		h.observe(air, 0.016)
	_check(h.active_id() == &"", "air for %d ticks after the bite teaches nothing yet" % (Hints.CUT_TICKS - 1))
	h.observe(air, 0.016)
	_check(h.active_id() == &"cut_through" and h.active_text().begins_with("CUT THROUGH"), "the %dth tick on air after your own bite is CUT THROUGH (%s)" % [Hints.CUT_TICKS, h.active_id()])
	for _i: int in Hints.AIR_TICKS:
		h.observe(air, 0.016)
	_check(h.active_id() != &"aim_air", "...and NOTHING THERE stays quiet for a hole you cut yourself (%s)" % h.active_id())
	var cold: Hints = Hints.new()
	for _i: int in Hints.AIR_TICKS - 1:
		cold.observe(air, 0.016)
	_check(cold.active_id() == &"", "control: air with no bite behind it says nothing for %d ticks" % (Hints.AIR_TICKS - 1))
	cold.observe(air, 0.016)
	_check(cold.active_id() == &"aim_air", "...and NOTHING THERE at the %dth (%s)" % [Hints.AIR_TICKS, cold.active_id()])


## D0469 (stranger 51): a drill set off the line while BUILD is open is WRONG SPOT; on the line it is the
## rung's own tick; with no ladder attached a bare Hints says nothing about it.
func _test_wrong_spot_pins() -> void:
	var h: Hints = Hints.new()
	h.objectives = Objectives.new()
	h.objectives.refresh(_hint_obs(), 0.016)
	for id: StringName in [&"mine", &"smelt", &"deliver"]:
		h.objectives._done[id] = true
	_check(h.objectives.current_id() == &"build", "control: the ladder is at BUILD (%s)" % h.objectives.current_id())
	var off: Interface.Observation = _hint_obs()
	off.machines.append({"cell": Vector2i(9, 4), "id": &"drill", "behavior": &"drill", "status": &"idle"})
	h.observe(off, 0.016)
	_check(h.active_id() == &"wrong_spot" and h.active_text().begins_with("WRONG SPOT"), "a drill standing with nothing under it while BUILD is open: WRONG SPOT (%s)" % h.active_id())
	var on: Interface.Observation = _hint_obs()
	on.machines.append({"cell": Vector2i(9, 4), "id": &"drill", "behavior": &"drill", "status": &"idle"})
	on.machines.append({"cell": Vector2i(9, 6), "id": &"processor", "status": &"idle"})
	var fresh: Hints = Hints.new()
	fresh.objectives = h.objectives
	fresh.observe(on, 0.016)
	_check(fresh.active_id() != &"wrong_spot", "a drill over the forge is the line, not a lesson (%s)" % fresh.active_id())
	var bare: Hints = Hints.new()
	bare.observe(off, 0.016)
	_check(bare.active_id() == &"", "control: with no ladder attached the lesson never fires (%s)" % bare.active_id())
	for pair: Array in [[&"build_far", "TOO FAR"], [&"build_here", "STEP ASIDE"]]:
		var pressed: Interface.Observation = _hint_obs()
		pressed.aim_refusal = pair[0]
		var once: Hints = Hints.new()
		once.observe(pressed, 0.016)
		_check(once.active_id() == pair[0] and once.active_text().begins_with(pair[1]), "a BUILD refused %s teaches on the press itself, one observe wide (D0470) (%s)" % [pair[0], once.active_id()])


## D0473 (strangers 52 and 54): "far" with the pointer on the buried ring, three metres under the feet, is
## TOO FAR DOWN (dig at the square first), never TOO FAR's "step closer"; a far cell at the body's level
## keeps TOO FAR.
func _test_far_below_pins() -> void:
	var h: Hints = Hints.new()
	var buried: Interface.Observation = _hint_obs()
	buried.aim_refusal = &"far"
	buried.cell = Vector2i(100, 75)
	buried.aim_cell = Vector2i(100, 75 + Hints.BELOW_CELLS)
	for _i: int in Hints.FAR_TICKS:
		h.observe(buried, 0.016)
	_check(h.active_id() == &"far_below" and h.active_text().begins_with("TOO FAR DOWN"), "far, two metres under the body: TOO FAR DOWN (%s)" % h.active_id())
	var level: Hints = Hints.new()
	var across: Interface.Observation = _hint_obs()
	across.aim_refusal = &"far"
	across.cell = Vector2i(100, 75)
	across.aim_cell = Vector2i(120, 75 + Hints.BELOW_CELLS - 1)
	for _i: int in Hints.FAR_TICKS:
		level.observe(across, 0.016)
	_check(level.active_id() == &"too_far", "control: far across, or under the feet by less than two metres, keeps TOO FAR (%s)" % level.active_id())


func _test_mined_wrong_pins() -> void:
	var h: Hints = Hints.new()
	var clay: Interface.Observation = _hint_obs()
	clay.mining_broke = true
	clay.mining_broke_material = &"clay"
	h.observe(_hint_obs(), 0.016)
	h.observe(clay, 0.016)
	_check(h.active_id() == &"mined_wrong" and h.active_text().begins_with("NOT ORE — that was clay,"), "clay broken with no ore held teaches NOT ORE naming clay (%s: %s)" % [h.active_id(), h.active_text().left(30)])
	var h2: Hints = Hints.new()
	var vein: Interface.Observation = _hint_obs()
	vein.mining_broke = true
	vein.mining_broke_material = &"ore_iron"
	h2.observe(vein, 0.016)
	var held: Interface.Observation = _hint_obs([["ore", 1]])
	held.mining_broke = true
	held.mining_broke_material = &"clay"
	h2.observe(held, 0.016)
	_check(h2.active_id() == &"" and h2.queued() == 0 and String(MaterialsRecords.RECORDS["ore_iron"]["yields"]) == "ore", "control: an ore_iron break (yield ore), then clay with ore in the pack, teach nothing (%s)" % h2.active_id())
	var h3: Hints = Hints.new()
	h3.restore_taught([&"way_down"])
	h3.observe(clay, 0.016)
	_check(h3.active_id() == &"" and h3.queued() == 0, "control: after THE WAY DOWN a clay break is the asked-for cut, not a miss (%s)" % h3.active_id())
	# D0458: with the ladder attached the rung decides, not the pack -- wood felled on a later rung with
	# the ore long spent in the forge teaches nothing; the same break on the mine rung does. (The ladder's
	# third rung is the delivery since D0485; the pin's point is the rung, not the material.)
	var h4: Hints = Hints.new()
	h4.objectives = Objectives.new()
	h4.objectives.restore_done([&"mine", &"smelt"])
	var wood: Interface.Observation = _hint_obs()
	wood.mining_broke = true
	wood.mining_broke_material = &"wood"
	h4.observe(wood, 0.016)
	_check(h4.objectives.current_id() == &"deliver" and h4.active_id() == &"" and h4.queued() == 0, "on the deliver rung, an empty pack and a wood break teach nothing (%s)" % h4.active_id())
	var h5: Hints = Hints.new()
	h5.objectives = Objectives.new()
	h5.observe(wood, 0.016)
	_check(h5.objectives.current_id() == &"mine" and h5.active_id() == &"mined_wrong", "on the mine rung the same break is NOT ORE (%s)" % h5.active_id())


func _test_wrong_stack_pins() -> void:
	var forge: Dictionary = {"cell": Vector2i(11, 10), "id": &"processor", "recipe": &"smelt_ingot", "input": {}, "output": {}}
	var h: Hints = Hints.new()
	var o: Interface.Observation = _hint_obs([["clay", 3], ["ore", 4]])
	o.pos_x = 10 * 16 * S
	o.pos_y = 10 * 16 * S
	var typed: Array[Dictionary] = [forge]
	o.machines = typed
	h.observe(o, 0.016)
	var after: Interface.Observation = _hint_obs([["ore", 4]])
	after.pos_x = o.pos_x
	after.pos_y = o.pos_y
	after.machines = typed
	after.drop_went = &"floor"
	h.observe(after, 0.016)
	_check(h.active_id() == &"dropped_wrong" and h.active_text().find("you dropped clay") >= 0 and h.active_text().find("takes ore") >= 0,
		"clay on the floor beside a forge, ore in the pack: WRONG STACK names both (%s)" % h.active_text().left(72))
	var h2: Hints = Hints.new()
	h2.observe(o, 0.016)
	var short: Interface.Observation = _hint_obs([["clay", 3]])
	short.pos_x = o.pos_x
	short.pos_y = o.pos_y
	short.machines = typed
	short.drop_went = &"floor"
	h2.observe(short, 0.016)
	_check(h2.active_id() == &"dropped_floor", "control: ore on the floor beside the same forge is the BESIDE lesson, not WRONG STACK (%s)" % h2.active_id())
	var h3: Hints = Hints.new()
	var alone: Interface.Observation = _hint_obs([["clay", 3], ["ore", 4]])
	h3.observe(alone, 0.016)
	var alone_after: Interface.Observation = _hint_obs([["ore", 4]])
	alone_after.drop_went = &"floor"
	h3.observe(alone_after, 0.016)
	_check(h3.active_id() == &"dropped_floor", "control: clay on the floor with no machine in range is the BESIDE lesson too (%s)" % h3.active_id())
