extends "res://tests/test_base.gd"
## D0366. `view/audio/bed_levels.gd`: eight numbers off the observation. Every rule is posed directly on
## an `Observation` -- no sim, no scene -- so each claim is the rule and nothing else: the heartbeat
## counts WORKING machines within reach, the ambience measures against the GENERATED datum, the rush
## starts at a run, a pour is a wet cell over an open unfull cell, the haul is a length delta per tick
## against the reel rate and paying out is not a haul, and a slack line carries no load.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_bed_levels.gd
const S: int = Fx.SCALE
const O := Interface.Observation
const W: int = 256
const H: int = 64


func _initialize() -> void:
	_test_the_heartbeat_counts_working_machines_within_reach()
	_test_the_ambience_measures_against_the_generated_datum()
	_test_the_rush_starts_at_a_run()
	_test_a_pour_is_a_wet_cell_over_an_open_unfull_cell()
	_test_the_pump_bed_counts_working_pumps_only()
	_test_the_haul_is_line_taken_in_per_tick()
	_test_the_load_is_weight_below_the_hitch_plus_centripetal_pull()
	_test_levels_carries_the_eight_keys()
	_finish("bed_levels")


func _obs(body_px: Vector2 = Vector2(100.0, 100.0)) -> Interface.Observation:
	var o: Interface.Observation = O.new()
	o.window = Rect2i(0, 0, W, H)
	o.legend = PackedStringArray(["", "clay"])
	o.materials = PackedByteArray()
	o.materials.resize(W * H)
	o.water = PackedByteArray()
	o.water.resize(W * H)
	o.pos_x = int(body_px.x) * S
	o.pos_y = int(body_px.y) * S
	o.cell = Vector2i(int(body_px.x) / O.CELL_PX, int(body_px.y) / O.CELL_PX)
	return o


func _machine(cell: Vector2i, status: StringName, behavior: StringName = &"drill") -> Dictionary:
	return {"cell": cell, "id": behavior, "behavior": behavior, "status": status}


func _test_the_heartbeat_counts_working_machines_within_reach() -> void:
	var o: Interface.Observation = _obs()
	for i: int in 5:
		o.machines.append(_machine(Vector2i(6 + i, 6), &"working"))
	_check(is_equal_approx(BedLevels.hum(o), 1.0), "five working machines within reach: a full heartbeat (%.2f)" % BedLevels.hum(o))
	o.machines = []
	for i: int in 3:
		o.machines.append(_machine(Vector2i(6 + i, 6), &"working"))
	_check(is_equal_approx(BedLevels.hum(o), 0.6), "three: 0.6 (%.2f)" % BedLevels.hum(o))
	o.machines = []
	for i: int in 5:
		o.machines.append(_machine(Vector2i(6 + i, 6), &"idle"))
	_check(BedLevels.hum(o) == 0.0, "five idle machines: silence (%.2f)" % BedLevels.hum(o))
	o.machines = []
	for i: int in 5:
		o.machines.append(_machine(Vector2i(40 + i, 6), &"working"))
	_check(BedLevels.hum(o) == 0.0, "five working machines 34 cells away: silence (%.2f)" % BedLevels.hum(o))
	_check(BedLevels.near(o, BedLevels.logic_centre(Vector2i(6 + BedLevels.NEAR_CELLS - 1, 6))) and not BedLevels.near(o, BedLevels.logic_centre(Vector2i(6 + BedLevels.NEAR_CELLS, 6))),
		"control: reach ends at NEAR_CELLS from the body's column")


func _test_the_ambience_measures_against_the_generated_datum() -> void:
	var o: Interface.Observation = _obs()
	o.cell.y = O.SKY_ROWS
	var a: Dictionary = BedLevels.ambience(o)
	_check(is_equal_approx(float(a["surface"]), 1.0) and float(a["cave"]) == 0.0, "at the datum: full wind, no cave")
	o.cell.y = O.SKY_ROWS + 8
	a = BedLevels.ambience(o)
	_check(is_equal_approx(float(a["surface"]), 0.5) and is_equal_approx(float(a["cave"]), 0.2), "two metres down: wind 0.5, cave 0.2 (%s)" % str(a))
	o.cell.y = O.SKY_ROWS + 16
	a = BedLevels.ambience(o)
	_check(float(a["surface"]) == 0.0 and is_equal_approx(float(a["cave"]), 0.4), "four metres down: the wind has died (%s)" % str(a))
	o.cell.y = O.SKY_ROWS + 40
	a = BedLevels.ambience(o)
	_check(is_equal_approx(float(a["cave"]), 1.0), "ten metres down: full cave air (%s)" % str(a))
	o.cell.y = O.SKY_ROWS - 16
	a = BedLevels.ambience(o)
	_check(is_equal_approx(float(a["surface"]), 1.0) and float(a["cave"]) == 0.0, "in the sky: clamped to full wind, no cave")
	_check(is_equal_approx(BedLevels.depth_m(o), -4.0), "and depth reads minus four metres there (%.1f)" % BedLevels.depth_m(o))


func _test_the_rush_starts_at_a_run() -> void:
	var o: Interface.Observation = _obs()
	o.vel_x = O.RUN_SPEED_PX_S * S
	_check(BedLevels.rush(o) == 0.0, "a run is the zero point (%.2f)" % BedLevels.rush(o))
	o.vel_x = 0
	o.vel_y = O.MAX_FALL_PX_S * S
	_check(is_equal_approx(BedLevels.rush(o), 1.0), "terminal fall is one (%.2f)" % BedLevels.rush(o))
	o.vel_y = ((O.RUN_SPEED_PX_S + O.MAX_FALL_PX_S) / 2) * S
	_check(is_equal_approx(BedLevels.rush(o), 0.5), "midway is a half (%.2f)" % BedLevels.rush(o))
	o.vel_y = 0
	_check(BedLevels.rush(o) == 0.0, "standing still is not a negative rush")


func _test_a_pour_is_a_wet_cell_over_an_open_unfull_cell() -> void:
	var o: Interface.Observation = _obs()
	var wet := Vector2i(25, 30)
	o.wet_cells = [wet]
	o.water[30 * W + 25] = 3
	_check(is_equal_approx(BedLevels.pour(o), 0.25), "one wet cell over open air within reach: a quarter pour (%.2f)" % BedLevels.pour(o))
	o.materials[31 * W + 25] = 1
	_check(BedLevels.pour(o) == 0.0, "the same cell over rock: nothing pours (%.2f)" % BedLevels.pour(o))
	o.materials[31 * W + 25] = 0
	o.water[31 * W + 25] = O.WATER_MAX
	_check(BedLevels.pour(o) == 0.0, "over a FULL cell: nothing pours (%.2f)" % BedLevels.pour(o))
	o.water[31 * W + 25] = 0
	o.wet_cells = [Vector2i(200, 30)]
	_check(BedLevels.pour(o) == 0.0, "a pouring cell 700 px away is out of earshot (%.2f)" % BedLevels.pour(o))
	o.wet_cells = [Vector2i(25, 30), Vector2i(26, 30), Vector2i(27, 30), Vector2i(28, 30), Vector2i(29, 30)]
	_check(is_equal_approx(BedLevels.pour(o), 1.0), "five pouring cells clamp to a full pour (%.2f)" % BedLevels.pour(o))


func _test_the_pump_bed_counts_working_pumps_only() -> void:
	var o: Interface.Observation = _obs()
	o.machines = [_machine(Vector2i(7, 6), &"working", &"pump")]
	_check(is_equal_approx(BedLevels.pump(o), 0.5), "one working pump: half (%.2f)" % BedLevels.pump(o))
	o.machines.append(_machine(Vector2i(8, 6), &"working", &"pump"))
	_check(is_equal_approx(BedLevels.pump(o), 1.0), "two: full (%.2f)" % BedLevels.pump(o))
	o.machines = [_machine(Vector2i(7, 6), &"no_power", &"pump")]
	_check(BedLevels.pump(o) == 0.0, "an unpowered pump is silent")
	o.machines = [_machine(Vector2i(7, 6), &"working", &"drill")]
	_check(BedLevels.pump(o) == 0.0 and BedLevels.hum(o) > 0.0, "a working drill is heartbeat, not drain")


func _test_the_haul_is_line_taken_in_per_tick() -> void:
	var lv: BedLevels = BedLevels.new()
	var per_tick: int = (O.REEL_PX_S * S) / O.TICK_HZ
	var o: Interface.Observation = _obs()
	o.grapple_anchored = true
	o.tick = 100
	o.grapple_length = 300 * S
	_check(lv.haul(o) == 0.0, "the first anchored observation has no delta yet")
	o.tick = 101
	o.grapple_length -= per_tick
	_check(is_equal_approx(lv.haul(o), 1.0), "one reel step in one tick is a full haul (%.2f)" % lv.haul(o))
	o.tick = 102
	_check(lv.haul(o) == 0.0, "a held length is no haul")
	o.tick = 103
	o.grapple_length += per_tick * 2
	_check(lv.haul(o) == 0.0, "paying out is not a haul")
	o.tick = 105
	o.grapple_length -= per_tick
	_check(is_equal_approx(lv.haul(o), 0.5), "one step over two ticks is half (%.2f)" % lv.haul(o))
	o.grapple_anchored = false
	o.tick = 106
	_check(lv.haul(o) == 0.0, "stowed: nothing")
	o.grapple_anchored = true
	o.tick = 107
	o.grapple_length = 100 * S
	_check(lv.haul(o) == 0.0, "re-anchored: the old length was forgotten, no phantom haul")


func _test_the_load_is_weight_below_the_hitch_plus_centripetal_pull() -> void:
	var o: Interface.Observation = _obs(Vector2(100.0, 200.0))
	o.grapple_hitch = Vector2i(100 * S, 100 * S)
	_check(BedLevels.line_load(o) == 0.0, "a slack line carries no load")
	o.grapple_taut = true
	var hanging: float = BedLevels.line_load(o)
	_check(is_equal_approx(hanging, 1.0 / 2.6), "hanging still below the hitch: the body's weight over the full tension (%.3f)" % hanging)
	o.vel_x = 100 * S
	var swinging: float = BedLevels.line_load(o)
	_check(swinging > hanging, "swinging through the bottom adds centripetal pull (%.3f > %.3f)" % [swinging, hanging])
	o.vel_x = 0
	o.grapple_hitch = Vector2i(0, 200 * S)
	_check(BedLevels.line_load(o) == 0.0, "a hitch level with the body at rest: no weight hangs below it")
	o.grapple_hitch = o.grapple_hitch * 0 + Vector2i(100 * S, 200 * S)
	_check(BedLevels.line_load(o) == 0.0, "a zero-length line is no load, not a division")


func _test_levels_carries_the_eight_keys() -> void:
	var lv: BedLevels = BedLevels.new()
	var d: Dictionary = lv.levels(_obs())
	_check(d.size() == 8 and d.has("hum") and d.has("surface") and d.has("cave") and d.has("rush") and d.has("pour") and d.has("pump") and d.has("haul") and d.has("load"),
		"the eight levels in the driver's vocabulary (%s)" % str(d.keys()))
