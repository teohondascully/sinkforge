extends "res://tests/test_base.gd"
## D0373. `view/visuals/light_painter.gd`: legacy's additive pass. The claims are legacy's own rules: the
## pool texture is radial and shared; the lamp bloom is scaled by how deep the miner is; a machine's pool
## follows its kind and status (a burner with no coal is OUT, not dim; an idle machine keeps IDLE_GLOW);
## same-light neighbours flood into one pool at the brightest member's pulse, and a different colour or
## an idled neighbour does not join; a shaft two metres below its rim beams and a one-metre step does
## not; a real redraw runs on an ADD-blended layer.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_light_painter.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_the_glow_texture()
	_test_the_lamp_bloom_scales_with_depth()
	_test_machine_pools_by_kind_and_status()
	_test_pools_flood_by_colour_within_reach()
	_test_the_godray()
	await _test_paint_runs_on_an_add_layer()
	_finish("light_painter")


func _rec(behavior: StringName, cell: Vector2i, status: StringName = &"working", extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = MachinesRecords.RECORDS.get(String(behavior), {})
	var r: Dictionary = {"cell": cell, "id": behavior, "behavior": behavior, "source": String(data.get("recipe", "")) == "mine_ore" or behavior == &"iron_forge",
		"status": status, "fuel": 0, "input": {}, "power_permille": 0}
	for k: Variant in extra:
		r[k] = extra[k]
	return r


func _test_the_glow_texture() -> void:
	var t: GradientTexture2D = LightPainter.glow_texture()
	_check(t.get_width() == 128 and t.get_height() == 128, "a 128x128 gradient")
	_check(LightPainter.glow_texture() == t, "shared: the same texture every call")
	var img: Image = t.get_image()
	_check(img.get_pixel(64, 64).a > 0.8 and img.get_pixel(64, 2).a < 0.05, "bright at the centre, transparent at the edge (%.2f, %.2f)" % [img.get_pixel(64, 64).a, img.get_pixel(64, 2).a])
	_check(img.get_pixel(64, 64).a > img.get_pixel(64, 40).a and img.get_pixel(64, 40).a > img.get_pixel(64, 10).a, "and falling off monotonically")
	_check(is_equal_approx(LightPainter.CULL_M, 5.6), "the cull margin is the lamp, the largest pool (%.1f m)" % LightPainter.CULL_M)


func _test_the_lamp_bloom_scales_with_depth() -> void:
	var deep: int = MaterialLook.SURFACE_ROW + 20 * MaterialLook.CELLS_PER_METRE
	var surface: int = MaterialLook.SURFACE_ROW
	var d: float = LightPainter.lamp_flick(0.0, deep)
	var s: float = LightPainter.lamp_flick(0.0, surface)
	_check(absf(d - LightPainter.LAMP_BLOOM) < 0.06, "deep: the full bloom, flicker aside (%.3f)" % d)
	_check(absf(s - LightPainter.LAMP_BLOOM * VeilPainter.LAMP_SURFACE_SCALE) < 0.02, "at the datum: the veil's own 0.30 floor (%.3f)" % s)
	var lo: float = 1.0
	var hi: float = 0.0
	for i: int in 200:
		var f: float = LightPainter.lamp_flick(float(i) * 0.05, deep)
		lo = minf(lo, f)
		hi = maxf(hi, f)
	_check(lo >= LightPainter.LAMP_BLOOM - 0.051 and hi <= LightPainter.LAMP_BLOOM + 0.051, "the flicker stays within its two sines' reach (%.3f..%.3f)" % [lo, hi])


func _test_machine_pools_by_kind_and_status() -> void:
	var furnace: Dictionary = LightPainter.machine_pool(_rec(&"iron_forge", Vector2i(3, 3)), 0.0)
	_check(not furnace.is_empty() and furnace["col"] == LightPainter.FURNACE_EMBER and bool(furnace["burning"]), "a working furnace: the ember, burning")
	var idle: Dictionary = LightPainter.machine_pool(_rec(&"iron_forge", Vector2i(3, 3), &"no_input"), 0.0)
	_check(float(idle["pulse"]) <= 0.82 * LightPainter.IDLE_GLOW + 0.001 and bool(idle["idled"]), "an idle one keeps IDLE_GLOW of its pulse (%.3f)" % float(idle["pulse"]))
	_check(LightPainter.machine_pool(_rec(&"generator", Vector2i(4, 3), &"no_fuel"), 0.0).is_empty(), "a burner with no coal is out, not dim")
	var burner: Dictionary = LightPainter.machine_pool(_rec(&"generator", Vector2i(4, 3), &"working", {"fuel": 3}), 0.0)
	_check(not burner.is_empty() and burner["col"] == LightPainter.BURNER_GLOW and bool(burner["burning"]) and not bool(burner["idled"]), "a fuelled burner glows and burns")
	var lift: Dictionary = LightPainter.machine_pool(_rec(&"lift", Vector2i(5, 3), &"working", {"power_permille": 1000}), 0.0)
	var lift_cold: Dictionary = LightPainter.machine_pool(_rec(&"lift", Vector2i(5, 3), &"idle", {"power_permille": 0}), 0.0)
	_check(lift["col"] == LightPainter.LIFT_TEAL and float(lift["pulse"]) > float(lift_cold["pulse"]), "a lift is teal and breathes with its power (%.2f > %.2f)" % [float(lift["pulse"]), float(lift_cold["pulse"])])
	var drill: Dictionary = LightPainter.machine_pool(_rec(&"drill", Vector2i(6, 3)), 0.0)
	_check(drill["col"] == MachineLook.color(&"drill", &"drill", true) and not bool(drill["burning"]), "a drill pools in its own casing colour and has no core")


func _test_pools_flood_by_colour_within_reach() -> void:
	var one: Dictionary = LightPainter.pools([_rec(&"iron_forge", Vector2i(3, 3))], 0.0)
	var two: Dictionary = LightPainter.pools([_rec(&"iron_forge", Vector2i(3, 3)), _rec(&"iron_forge", Vector2i(4, 3))], 0.0)
	_check((one["pools"] as Array).size() == 1 and (two["pools"] as Array).size() == 1 and int((two["pools"] as Array)[0]["size"]) == 2, "two adjacent furnaces are ONE pool")
	_check(float((two["pools"] as Array)[0]["radius"]) > float((one["pools"] as Array)[0]["radius"]), "wider than one furnace's, by the run's extent")
	_check((two["cores"] as Array).size() == 2, "and two cores, one per burner")
	var far: Dictionary = LightPainter.pools([_rec(&"iron_forge", Vector2i(3, 3)), _rec(&"iron_forge", Vector2i(3 + LightPainter.MACHINE_POOL_LINK + 1, 3))], 0.0)
	_check((far["pools"] as Array).size() == 2, "past the link distance they are two")
	var mixed: Dictionary = LightPainter.pools([_rec(&"iron_forge", Vector2i(3, 3)), _rec(&"drill", Vector2i(4, 3))], 0.0)
	_check((mixed["pools"] as Array).size() == 2, "a furnace and a drill side by side do not merge: different lights")
	var idled: Dictionary = LightPainter.pools([_rec(&"iron_forge", Vector2i(3, 3)), _rec(&"iron_forge", Vector2i(4, 3), &"no_input")], 0.0)
	_check((idled["pools"] as Array).size() == 2, "a working and an idled furnace do not merge: an idled pool would publish the neighbour's state")
	var out: Dictionary = LightPainter.pools([_rec(&"generator", Vector2i(3, 3), &"no_fuel")], 0.0)
	_check((out["pools"] as Array).is_empty() and (out["cores"] as Array).is_empty(), "an unfuelled burner neither pools nor cores")
	var pulse_a: float = LightPainter.machine_pool(_rec(&"iron_forge", Vector2i(3, 3)), 0.0)["pulse"]
	var pulse_b: float = LightPainter.machine_pool(_rec(&"iron_forge", Vector2i(4, 3)), 0.0)["pulse"]
	_check(is_equal_approx(float((two["pools"] as Array)[0]["pulse"]), maxf(pulse_a, pulse_b)), "the group's intensity is its brightest member, not the sum")


func _test_the_godray() -> void:
	var line: int = LightPainter.row_at_depth(VeilPainter.SURFACE_LINE_M)
	var m: int = MaterialLook.CELLS_PER_METRE
	_check(LightPainter.row_at_depth(0.0) == MaterialLook.SURFACE_ROW and LightPainter.row_at_depth(2.0) == MaterialLook.SURFACE_ROW + 2 * m, "the row inverse of the palette's depth")
	var shaft: Dictionary = LightPainter.godray(line + 6 * m, line, line)
	_check(not shaft.is_empty() and int(shaft["mouth_row"]) == line and bool(shaft["lands"]), "a six-metre shaft between two rim columns beams from the rim and lands on its floor")
	_check(float(shaft["mouth_light"]) > 0.99 and float(shaft["floor_light"]) < float(shaft["mouth_light"]), "bright at the mouth, dimmer at the floor")
	_check(LightPainter.godray(line + 1 * m, line, line).is_empty(), "a one-metre step does not beam")
	var one_side: Dictionary = LightPainter.godray(line + 6 * m, line + 6 * m, line)
	_check(not one_side.is_empty(), "one rim neighbour is enough: light pours past that edge")
	var deep_mouth: int = line + int(VeilPainter.SKY_REACH_M) * m + 2 * m
	_check(LightPainter.godray(deep_mouth + 6 * m, deep_mouth, deep_mouth).is_empty(), "a mouth below the sky's reach admits no sky")
	var long: Dictionary = LightPainter.godray(line + 40 * m, line, line)
	_check(not bool(long["lands"]) and int(long["end_row"]) < line + 40 * m, "a very deep shaft's beam dies before the floor")


func _test_paint_runs_on_an_add_layer() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	machines.place(world, MachineDef.of(&"iron_forge"), Vector2i(3, 14))
	machines.place(world, MachineDef.of(&"torch"), Vector2i(6, 14))
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var falling: FallingItems = FallingItems.new()
	falling.inject(Vector2(100.0, 100.0), Vector2(100.0, 200.0), Color.RED)
	var painter: LightPainter = LightPainter.new(falling)
	var ran: Array = [0]
	var layer: PaintLayer = view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		painter.paint_frame(f, ci)
		ran[0] = int(ran[0]) + 1)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	layer.material = mat
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint_frame() ran on an ADD layer over a forge, a torch and a mote (%d)" % int(ran[0]))
	_check((layer.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "control: the layer is additive")
	view.queue_free()
