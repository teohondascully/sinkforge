extends "res://tests/test_base.gd"
## D0367. `view/audio/voice_cues.gd`: every one-shot as an edge over two posed observations. The rules
## are the claims: a blow strikes with the struck material's voice at its hardness pitch; a break thumps
## and an ore break adds the vein; the line's plant, cut and catch edges; a hard landing thumps and a
## step-off does not; a stride is 22 px on the floor over the ground's own voice; a machine appearing
## clunks, leaving pops, the first to run ignites once, and the first frame primes; a pack gain pops; the
## dark drips only past the cave gate and never faster than three seconds apart.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_voice_cues.gd
const S: int = Fx.SCALE
const W: int = 64
const H: int = 64


func _initialize() -> void:
	_test_a_blow_strikes_with_the_materials_voice()
	_test_a_break_thumps_and_ore_adds_the_vein()
	_test_the_lines_three_edges()
	_test_landing_hard_and_stepping_off()
	_test_a_stride_over_the_ground_underfoot()
	_test_machines_clunk_pop_and_ignite_once()
	_test_a_pack_gain_pops()
	_test_the_dark_drips_past_the_gate()
	_finish("voice_cues")


func _obs() -> Interface.Observation:
	var o: Interface.Observation = Interface.Observation.new()
	o.window = Rect2i(0, 0, W, H)
	o.legend = PackedStringArray(["", "clay", "hardrock", "ore_iron", "wood"])
	o.materials = PackedByteArray()
	o.materials.resize(W * H)
	o.pos_x = 100 * S
	o.pos_y = 100 * S
	o.bottom_y = 120 * S
	o.on_floor = true
	o.hand = Vector2i(104 * S, 96 * S)
	return o


func _mat(o: Interface.Observation, c: Vector2i, mat: int) -> void:
	o.materials[c.y * W + c.x] = mat


func _voices(cues: Array[Dictionary]) -> Array:
	var out: Array = []
	for c: Dictionary in cues:
		out.append(c["voice"])
	return out


func _test_a_blow_strikes_with_the_materials_voice() -> void:
	var vc: VoiceCues = VoiceCues.new()
	var o: Interface.Observation = _obs()
	o.mining_swing = true
	o.mining_is_charging = true
	o.mining_charging_cell = Vector2i(30, 30)
	_mat(o, Vector2i(30, 30), 1)
	var cues: Array[Dictionary] = vc.cues(o, 0.016)
	_check(cues.size() == 1 and cues[0]["voice"] == &"hit_earth", "a blow into clay is the earth strike (%s)" % str(_voices(cues)))
	_check(is_equal_approx(float(cues[0]["pitch"]), VoiceCues.blow_pitch(&"clay")), "at clay's hardness pitch (%.3f)" % float(cues[0]["pitch"]))
	_check((cues[0]["at"] as Vector2).is_equal_approx(VoiceCues.terrain_centre(Vector2i(30, 30))), "at the struck cell's centre")
	_mat(o, Vector2i(30, 30), 2)
	cues = vc.cues(o, 0.016)
	_check(cues.size() == 1 and cues[0]["voice"] == &"crunch", "a blow into hardrock is the plain crunch (%s)" % str(_voices(cues)))
	_check(float(cues[0]["pitch"]) < VoiceCues.blow_pitch(&"clay"), "and harder rock strikes lower (%.3f)" % float(cues[0]["pitch"]))
	_check(VoiceCues.hardness(&"deepstone") > VoiceCues.hardness(&"hardrock"), "control: deepstone is the harder material in the data (%.1f > %.1f)" % [VoiceCues.hardness(&"deepstone"), VoiceCues.hardness(&"hardrock")])
	_check(is_equal_approx(VoiceCues.blow_pitch(&"deepstone"), 0.8), "deepstone pins to the floor of the pitch range (%.3f) -- the first draft named hardrock, whose hardness is 3.0 in the data, not the 5.0 assumed" % VoiceCues.blow_pitch(&"deepstone"))
	o.mining_swing = false
	_check(vc.cues(o, 0.016).is_empty(), "charging without the swing tick is silent")


func _test_a_break_thumps_and_ore_adds_the_vein() -> void:
	var vc: VoiceCues = VoiceCues.new()
	var o: Interface.Observation = _obs()
	o.mining_broke = true
	o.mining_broke_cells = [Vector2i(30, 31)]
	o.mining_broke_material = &"clay"
	var v: Array = _voices(vc.cues(o, 0.016))
	_check(v == [&"thump"], "a clay break is one thump (%s)" % str(v))
	o.mining_broke_material = &"ore_iron"
	v = _voices(vc.cues(o, 0.016))
	_check(v == [&"thump", &"vein"], "an iron break thumps and rings the vein (%s)" % str(v))
	o.mining_broke_material = &"glimmer"
	var cues: Array[Dictionary] = vc.cues(o, 0.016)
	_check(cues.size() == 2 and is_equal_approx(float(cues[1]["pitch"]), 1.16), "glimmer's vein is pitched up (%.2f)" % float(cues[1]["pitch"]))
	o.mining_broke = false
	_check(vc.cues(o, 0.016).is_empty(), "no break, no thump")


func _test_the_lines_three_edges() -> void:
	var vc: VoiceCues = VoiceCues.new()
	var o: Interface.Observation = _obs()
	o.grapple_just_planted = true
	o.grapple_anchor = Vector2i(200 * S, 60 * S)
	_mat(o, Vector2i(50, 15), 2)
	var cues: Array[Dictionary] = vc.cues(o, 0.016)
	_check(cues.size() == 1 and cues[0]["voice"] == &"crunch" and is_equal_approx(float(cues[0]["pitch"]), 1.6), "a plant strikes the rock it bit, pitched up (%s)" % str(cues))
	o.grapple_just_planted = false
	o.grapple_pivots = [Vector2i(200 * S, 60 * S)]
	o.grapple_hitch = Vector2i(180 * S, 70 * S)
	cues = vc.cues(o, 0.016)
	_check(cues.size() == 1 and cues[0]["voice"] == &"catch" and (cues[0]["at"] as Vector2).is_equal_approx(Vector2(180.0, 70.0)), "the pivot count rising is a catch at the hitch (%s)" % str(_voices(cues)))
	_check(vc.cues(o, 0.016).is_empty(), "the same pivot count next frame is not a second catch")
	o.grapple_just_cut = true
	cues = vc.cues(o, 0.016)
	_check(cues.size() == 1 and cues[0]["voice"] == &"pop" and float(cues[0]["db"]) < -10.0, "a cut is a quiet pop (%s)" % str(_voices(cues)))


func _test_landing_hard_and_stepping_off() -> void:
	var vc: VoiceCues = VoiceCues.new()
	var air: Interface.Observation = _obs()
	air.on_floor = false
	air.vel_y = Interface.Observation.MAX_FALL_PX_S * S
	_check(vc.cues(air, 0.016).is_empty(), "falling is silent")
	var floor: Interface.Observation = _obs()
	var cues: Array[Dictionary] = vc.cues(floor, 0.016)
	_check(cues.size() == 1 and cues[0]["voice"] == &"thump" and is_equal_approx(float(cues[0]["pitch"]), 1.1), "a terminal landing thumps at the top pitch (%s)" % str(cues))
	_check((cues[0]["at"] as Vector2).is_equal_approx(Vector2(100.0, 120.0)), "at the feet")
	_check(vc.cues(floor, 0.016).is_empty(), "standing there is silent")
	var soft: Interface.Observation = _obs()
	soft.on_floor = false
	soft.vel_y = 100 * S
	vc.cues(soft, 0.016)
	_check(vc.cues(floor, 0.016).is_empty(), "a step-off at 100 px/s does not thump")


func _test_a_stride_over_the_ground_underfoot() -> void:
	var vc: VoiceCues = VoiceCues.new()
	var o: Interface.Observation = _obs()
	o.vel_x = 100 * S
	_mat(o, Vector2i(25, 30), 1)   # the cell just under the feet at (100,122): clay
	var steps: int = 0
	for _i: int in 10:
		for c: Dictionary in vc.cues(o, 0.02):
			if c["voice"] == &"step":
				steps += 1
	_check(steps == 0, "200 ms at 100 px/s is 20 px: no stride yet (%d)" % steps)
	var cues: Array[Dictionary] = vc.cues(o, 0.03)
	_check(cues.size() == 1 and cues[0]["voice"] == &"step" and float(cues[0]["db"]) < -15.0, "the 22nd px is a quiet soft step over clay (%s)" % str(_voices(cues)))
	_mat(o, Vector2i(25, 30), 2)
	for _i: int in 11:
		cues = vc.cues(o, 0.02)
	_check(cues.size() == 1 and cues[0]["voice"] == &"step_rock", "over hardrock the boot clicks (%s)" % str(_voices(cues)))
	_mat(o, Vector2i(25, 30), 4)
	for _i: int in 11:
		cues = vc.cues(o, 0.02)
	_check(cues.size() == 1 and cues[0]["voice"] == &"step_wood", "over wood the board answers (%s)" % str(_voices(cues)))
	o.on_floor = false
	for _i: int in 11:
		cues = vc.cues(o, 0.02)
	_check(cues.is_empty(), "in the air there are no steps")
	o.on_floor = true
	o.vel_x = 10 * S
	for _i: int in 30:
		cues = vc.cues(o, 0.02)
	_check(cues.is_empty(), "creeping at 10 px/s is standing, not walking")


func _machine(cell: Vector2i, status: StringName) -> Dictionary:
	return {"cell": cell, "id": &"drill", "behavior": &"drill", "status": status}


func _test_machines_clunk_pop_and_ignite_once() -> void:
	var vc: VoiceCues = VoiceCues.new()
	var o: Interface.Observation = _obs()
	o.machines = [_machine(Vector2i(5, 5), &"idle"), _machine(Vector2i(6, 5), &"idle")]
	_check(vc.cues(o, 0.016).is_empty(), "the first frame primes: two machines already there do not clunk")
	o.machines.append(_machine(Vector2i(7, 5), &"idle"))
	var cues: Array[Dictionary] = vc.cues(o, 0.016)
	_check(cues.size() == 1 and cues[0]["voice"] == &"clunk" and (cues[0]["at"] as Vector2).is_equal_approx(VoiceCues.logic_centre(Vector2i(7, 5))), "a third appearing clunks at its cell (%s)" % str(cues))
	o.machines.remove_at(0)
	cues = vc.cues(o, 0.016)
	_check(cues.size() == 1 and cues[0]["voice"] == &"pop", "one leaving pops (%s)" % str(_voices(cues)))
	o.machines[0]["status"] = &"working"
	var v: Array = _voices(vc.cues(o, 0.016))
	_check(v == [&"ignite", &"ignite"], "the first machine ever to run ignites, positional and ui (%s)" % str(v))
	o.machines[1]["status"] = &"working"
	_check(vc.cues(o, 0.016).is_empty(), "a second running machine does not ignite again")
	var loaded: VoiceCues = VoiceCues.new()
	var base: Interface.Observation = _obs()
	base.machines = [_machine(Vector2i(5, 5), &"working")]
	loaded.cues(base, 0.016)
	base.machines.append(_machine(Vector2i(6, 5), &"working"))
	v = _voices(loaded.cues(base, 0.016))
	_check(v == [&"clunk"], "a loaded base already running never ignites: only the new machine clunks (%s)" % str(v))


func _test_a_pack_gain_pops() -> void:
	var vc: VoiceCues = VoiceCues.new()
	var o: Interface.Observation = _obs()
	o.pack = [{"item": &"stone", "count": 3}]
	_check(vc.cues(o, 0.016).is_empty(), "the first frame primes the pack")
	o.pack = [{"item": &"stone", "count": 5}]
	var cues: Array[Dictionary] = vc.cues(o, 0.016)
	_check(cues.size() == 1 and cues[0]["voice"] == &"pop" and (cues[0]["at"] as Vector2).is_equal_approx(Vector2(104.0, 96.0)), "a gain pops at the hand (%s)" % str(cues))
	o.pack = [{"item": &"stone", "count": 2}]
	_check(vc.cues(o, 0.016).is_empty(), "a spend does not pop")


func _test_the_dark_drips_past_the_gate() -> void:
	var quiet: VoiceCues = VoiceCues.new(3)
	var o: Interface.Observation = _obs()
	var drips: int = 0
	for _i: int in 300:
		for c: Dictionary in quiet.cues(o, 0.1):
			if c["voice"] == &"drip":
				drips += 1
	_check(drips == 0, "thirty seconds at the surface: no drips (%d)" % drips)
	var dark: VoiceCues = VoiceCues.new(3)
	var times: Array[float] = []
	var t: float = 0.0
	for _i: int in 300:
		for c: Dictionary in dark.cues(o, 0.1, 1.0):
			if c["voice"] == &"drip":
				times.append(t)
		t += 0.1
	_check(times.size() >= 3 and times.size() <= 10, "thirty seconds in the dark: between 3 and 10 drips (%d)" % times.size())
	var min_gap: float = 99.0
	for i: int in range(1, times.size()):
		min_gap = minf(min_gap, times[i] - times[i - 1])
	_check(times.size() < 2 or min_gap >= VoiceCues.DRIP_GAP_MIN - 0.11, "never faster than three seconds apart (min gap %.1f)" % min_gap)
