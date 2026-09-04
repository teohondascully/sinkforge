extends "res://tests/test_base.gd"
## D0367. `view/audio/sfx_space.gd`: the room, measured off the observation. Posed windows: open air is
## dry; a crawlway walls every ray close; a hall walls them far; a wall between a source and the listener
## occludes; the bus exists once and is released once.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_sfx_space.gd
const W: int = 200
const H: int = 200


func _initialize() -> void:
	_test_open_air_is_dry()
	_test_a_crawlway_and_a_hall()
	_test_occlusion_counts_the_rock_between()
	_test_the_reverb_map_and_the_smoothing()
	_test_the_bus_is_made_once_and_released()
	_finish("sfx_space")


func _obs() -> Interface.Observation:
	var o: Interface.Observation = Interface.Observation.new()
	o.window = Rect2i(0, 0, W, H)
	o.legend = PackedStringArray(["", "hardrock"])
	o.materials = PackedByteArray()
	o.materials.resize(W * H)
	return o


## Fill every terrain cell OUTSIDE a square of half-side `r` logic cells around `centre` (world px).
func _box(o: Interface.Observation, centre: Vector2, r: float) -> void:
	var lo: Vector2 = centre - Vector2(r, r) * SfxSpace.LOGIC_PX
	var hi: Vector2 = centre + Vector2(r, r) * SfxSpace.LOGIC_PX
	for y: int in H:
		for x: int in W:
			var p: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5)) * SfxSpace.CELL_PX
			if p.x < lo.x or p.x > hi.x or p.y < lo.y or p.y > hi.y:
				o.materials[y * W + x] = 1


func _test_open_air_is_dry() -> void:
	var p: Dictionary = SfxSpace.probe(_obs(), Vector2(400.0, 400.0))
	_check(float(p["closed"]) == 0.0 and float(p["room"]) == 0.0, "no rock in reach: closed 0, room 0 (%s)" % str(p))
	_check(SfxSpace.directions().size() == SfxSpace.RAYS, "twelve rays")


func _test_a_crawlway_and_a_hall() -> void:
	var centre := Vector2(400.0, 400.0)
	var crawl: Interface.Observation = _obs()
	_box(crawl, centre, 1.5)
	var pc: Dictionary = SfxSpace.probe(crawl, centre)
	_check(is_equal_approx(float(pc["closed"]), 1.0), "a crawlway: every ray hits (%s)" % str(pc))
	_check(float(pc["room"]) < 0.05, "and the room is tiny (%.3f)" % float(pc["room"]))
	var hall: Interface.Observation = _obs()
	_box(hall, centre, 10.5)
	var ph: Dictionary = SfxSpace.probe(hall, centre)
	_check(is_equal_approx(float(ph["closed"]), 1.0), "a hall: every ray still hits (%s)" % str(ph))
	_check(float(ph["room"]) > float(pc["room"]) + 0.4, "and the room is far larger than the crawlway's (%.3f vs %.3f)" % [float(ph["room"]), float(pc["room"])])
	var open: Interface.Observation = _obs()
	_box(open, centre, 40.0)
	var po: Dictionary = SfxSpace.probe(open, centre)
	_check(float(po["closed"]) == 0.0, "walls past the reach read as open (%s)" % str(po))


func _test_occlusion_counts_the_rock_between() -> void:
	var o: Interface.Observation = _obs()
	var listener := Vector2(100.0, 400.0)
	var source := Vector2(300.0, 400.0)
	_check(SfxSpace.occlusion(o, source, listener) == 0.0, "nothing between: no occlusion")
	for y: int in H:
		for x: int in range(48, 52):
			o.materials[y * W + x] = 1
	var thin: float = SfxSpace.occlusion(o, source, listener)
	_check(thin > 0.0 and thin < 0.3, "a one-cell wall between: a small fraction (%.3f)" % thin)
	for y: int in H:
		for x: int in range(26, 75):
			o.materials[y * W + x] = 1
	var thick: float = SfxSpace.occlusion(o, source, listener)
	_check(thick > thin, "a thick wall occludes more (%.3f > %.3f)" % [thick, thin])
	_check(SfxSpace.occlusion(o, listener, listener) == 0.0, "a source on the listener is not occluded")


func _test_the_reverb_map_and_the_smoothing() -> void:
	var dry: Dictionary = SfxSpace.reverb_for(0.0, 0.0)
	var cavern: Dictionary = SfxSpace.reverb_for(1.0, 1.0)
	_check(float(dry["wet"]) == 0.0 and float(cavern["wet"]) > float(dry["wet"]), "open sky is dry, a cavern wet")
	_check(float(cavern["room_size"]) > float(dry["room_size"]) and float(cavern["damping"]) < float(dry["damping"]), "a cavern is bigger and less damped")
	var s: SfxSpace = SfxSpace.new()
	var o: Interface.Observation = _obs()
	_box(o, Vector2(400.0, 400.0), 1.5)
	var probed: bool = s.update(o, Vector2(400.0, 400.0), 0.0)
	_check(probed and s.closed > 0.0 and s.closed < 1.0, "the first update probes and moves part of the way (%.3f)" % s.closed)
	_check(not s.update(o, Vector2(400.0, 400.0), SfxSpace.PROBE_PERIOD * 0.5), "half a period later it does not probe again")
	for _i: int in 60:
		s.update(o, Vector2(400.0, 400.0), SfxSpace.PROBE_PERIOD)
	_check(s.closed > 0.99, "sixty probes on it has closed in (%.3f)" % s.closed)


func _test_the_bus_is_made_once_and_released() -> void:
	var a: SfxSpace = SfxSpace.new()
	var b: SfxSpace = SfxSpace.new()
	a.ensure_bus()
	var count: int = AudioServer.bus_count
	b.ensure_bus()
	_check(a.has_bus() and b.has_bus(), "both instances see the reverb")
	_check(AudioServer.bus_count == count, "the second ensure made no second bus (%d)" % AudioServer.bus_count)
	b.release()
	_check(AudioServer.get_bus_index(SfxSpace.BUS) >= 0, "the instance that did not make it cannot remove it")
	a.release()
	_check(AudioServer.get_bus_index(SfxSpace.BUS) < 0, "the owner's release removes it")
