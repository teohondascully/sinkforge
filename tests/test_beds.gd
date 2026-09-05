extends "res://tests/test_base.gd"
## D0366. `view/audio/beds.gd`, the bed driver. The mix maps are static and return numbers, so the
## claims are exact: silent at zero, the stated ceiling at one, monotone between, the hum's middle and
## top layers gated by their thresholds. The node half is checked through the one property a player DOES
## read back, `volume_db`, so the injected ambience slider is seen to reach the mixer.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_beds.gd


func _initialize() -> void:
	_test_the_maps_are_silent_at_zero_and_at_their_ceilings_at_one()
	_test_the_maps_are_monotone()
	_test_the_hum_gains_colour_by_threshold()
	_test_the_winch_snaps_and_the_rope_drags()
	_test_the_node_builds_ten_beds_and_smooths_toward_a_level()
	await _test_the_synthesis_is_the_same_off_thread()
	_finish("beds")


## D0397: the seat synthesizes on a worker thread and attaches later. The content may not depend on the
## path: the bytes of every bed from `synthesize` equal the synchronous `setup`'s, and the rig settles.
func _test_the_synthesis_is_the_same_off_thread() -> void:
	var sync: Dictionary = Beds.synthesize(7)
	var again: Dictionary = Beds.synthesize(7)
	var same: bool = sync.size() == 10
	for name: StringName in sync:
		same = same and (sync[name] as AudioStreamWAV).data == (again[name] as AudioStreamWAV).data
	_check(same, "ten beds, byte-identical across two syntheses of one seed")
	_check((sync[&"hum"] as AudioStreamWAV).data != (Beds.synthesize(8)[&"hum"] as AudioStreamWAV).data, "control: another seed is another hum")
	var rig: SceneAudio = SceneAudio.new()
	root.add_child(rig)
	rig.setup_async(7)
	_check(not rig.beds.ready() and not rig.sfx.ready(), "before the thread finishes, no player exists and every voice is refused")
	var frames: int = 0
	while not rig.settle() and frames < 600:
		await process_frame
		frames += 1
	_check(rig.settle() and rig.beds.ready() and rig.sfx.ready() and rig.beds.get_child_count() == 10, "the rig settles with its ten beds and its voices (%d frames)" % frames)
	rig.queue_free()


func _test_the_maps_are_silent_at_zero_and_at_their_ceilings_at_one() -> void:
	var h0: Dictionary = Beds.hum_mix(0.0)
	var h1: Dictionary = Beds.hum_mix(1.0)
	_check(is_equal_approx(float(h0["sub_db"]), Beds.SILENT_DB) and is_equal_approx(float(h0["mid_db"]), Beds.SILENT_DB) and is_equal_approx(float(h0["top_db"]), Beds.SILENT_DB), "hum: all three layers silent at 0")
	_check(is_equal_approx(float(h1["sub_db"]), Beds.HUM_SUB_DB) and is_equal_approx(float(h1["mid_db"]), Beds.HUM_MID_DB) and is_equal_approx(float(h1["top_db"]), Beds.HUM_TOP_DB), "hum: the three ceilings at 1")
	_check(float(h1["top_db"]) < float(h1["mid_db"]) and float(h1["mid_db"]) < float(h1["sub_db"]), "the top is the quietest layer, the sub the loudest")
	var r: Dictionary = Beds.rush_mix(1.0)
	_check(is_equal_approx(float(r["db"]), Beds.RUSH_DB) and is_equal_approx(float(r["pitch"]), Beds.RUSH_PITCH_HI), "rush: ceiling and top pitch at 1")
	_check(is_equal_approx(float(Beds.rush_mix(0.0)["pitch"]), Beds.RUSH_PITCH_LO), "rush: bottom pitch at 0")
	var a: Dictionary = Beds.ambience_mix(1.0, 0.0)
	_check(is_equal_approx(float(a["wind_db"]), Beds.WIND_DB) and is_equal_approx(float(a["cave_db"]), Beds.SILENT_DB), "ambience: wind up, cave silent at the surface")
	var w: Dictionary = Beds.water_mix(1.0, 1.0)
	_check(is_equal_approx(float(w["pour_db"]), Beds.POUR_DB) and is_equal_approx(float(w["pump_db"]), Beds.PUMP_DB), "water: both ceilings at 1")
	var l: Dictionary = Beds.line_mix(0.0, 1.0)
	_check(is_equal_approx(float(l["winch_db"]), Beds.SILENT_DB) and is_equal_approx(float(l["creak_db"]), Beds.CREAK_DB) and is_equal_approx(float(l["creak_pitch"]), Beds.CREAK_PITCH_HI), "line: a loaded rope with the winch idle sings at its top pitch and the drum is silent")
	_check(Beds.WIND_DB < Beds.CAVE_DB and Beds.POUR_DB < Beds.CAVE_DB and Beds.PUMP_DB < Beds.CAVE_DB, "the water beds and the wind top out under the cave bed")


func _test_the_maps_are_monotone() -> void:
	var ok: bool = true
	for i: int in 10:
		var lo: float = float(i) / 10.0
		var hi: float = float(i + 1) / 10.0
		ok = ok and float(Beds.hum_mix(lo)["sub_db"]) <= float(Beds.hum_mix(hi)["sub_db"])
		ok = ok and float(Beds.rush_mix(lo)["db"]) <= float(Beds.rush_mix(hi)["db"])
		ok = ok and float(Beds.rush_mix(lo)["pitch"]) <= float(Beds.rush_mix(hi)["pitch"])
		ok = ok and float(Beds.water_mix(lo, 0.0)["pour_pitch"]) <= float(Beds.water_mix(hi, 0.0)["pour_pitch"])
		ok = ok and float(Beds.line_mix(lo, 0.0)["winch_pitch"]) <= float(Beds.line_mix(hi, 0.0)["winch_pitch"])
	_check(ok, "every level and pitch map rises with its level over ten steps")


func _test_the_hum_gains_colour_by_threshold() -> void:
	var below_mid: Dictionary = Beds.hum_mix(Beds.HUM_MID_FROM - 0.01)
	var above_mid: Dictionary = Beds.hum_mix(Beds.HUM_MID_FROM + 0.05)
	_check(is_equal_approx(float(below_mid["mid_db"]), Beds.SILENT_DB) and float(above_mid["mid_db"]) > Beds.SILENT_DB, "one machine is a sub only; the belts arrive past the mid threshold")
	var below_top: Dictionary = Beds.hum_mix(Beds.HUM_TOP_FROM - 0.01)
	var above_top: Dictionary = Beds.hum_mix(Beds.HUM_TOP_FROM + 0.05)
	_check(is_equal_approx(float(below_top["top_db"]), Beds.SILENT_DB) and float(above_top["top_db"]) > Beds.SILENT_DB, "the clatter arrives past the top threshold")
	_check(float(below_top["mid_db"]) > Beds.SILENT_DB, "control: at the top threshold the belts are already in the room")
	_check(Beds.HUM_MID_FROM < Beds.HUM_TOP_FROM, "the thresholds are ordered: belts before clatter")


func _test_the_winch_snaps_and_the_rope_drags() -> void:
	_check(Beds.WINCH_RATE > Beds.CREAK_RATE * 2.0, "the winch follows the key at least twice as fast as the rope follows the load (%.1f vs %.1f)" % [Beds.WINCH_RATE, Beds.CREAK_RATE])
	_check(Beds.RUSH_RATE > Beds.HUM_RATE and Beds.HUM_RATE > Beds.AMBIENCE_RATE, "speed answers faster than the factory, the factory faster than the weather")


func _test_the_node_builds_ten_beds_and_smooths_toward_a_level() -> void:
	var beds: Beds = Beds.new()
	root.add_child(beds)
	beds.setup(7)
	_check(beds.get_child_count() == 10, "ten players built (%d)" % beds.get_child_count())
	beds.ambience_db = -3.0
	beds.drive({"hum": 1.0}, 0.5)
	_check(is_equal_approx(beds.level(&"hum"), Beds.HUM_RATE * 0.5), "half a second at rate %.1f moves the hum to %.2f (%.3f)" % [Beds.HUM_RATE, Beds.HUM_RATE * 0.5, beds.level(&"hum")])
	for _i: int in 20:
		beds.drive({"hum": 1.0, "haul": 1.0}, 0.5)
	_check(is_equal_approx(beds.level(&"hum"), 1.0) and is_equal_approx(beds.level(&"winch"), 1.0), "ten seconds on, the hum and the winch sit at 1")
	var sub: AudioStreamPlayer = null
	var winch: AudioStreamPlayer = null
	var cave: AudioStreamPlayer = null
	for c: Node in beds.get_children():
		if c.stream != null and c.stream.loop_end == int(float(BedBank.RATE) * 1.0):
			sub = c
	_check(sub != null, "control: the one-second bed is the sub")
	if sub != null:
		_check(is_equal_approx(sub.volume_db, Beds.HUM_SUB_DB + -3.0), "the sub's player carries the ceiling PLUS the injected slider (%.1f)" % sub.volume_db)
	for _i: int in 40:
		beds.drive({}, 0.5)
	_check(beds.level(&"hum") == 0.0 and beds.level(&"winch") == 0.0, "twenty seconds of nothing and every bed is back at 0")
	_check(cave == null and winch == null, "control: the untouched handles stayed null")
	beds.queue_free()
