extends "res://tests/test_base.gd"
## D0375. `view/visuals/veil_sources.gd` + `VeilPainter.light_rgb_at` + the tinted `VeilMap` texel: every
## light but the lamp cuts the veil. The claims are legacy's own: a source's tint is its colour at 0.28
## toward white; a burner cuts 0.9 fuelled and nothing dry, a furnace 0.85, a lift 0.35 + 0.55 x power,
## any other machine 0.6; a torch cuts twice, wide and soft then a hot core; a conduit cuts only over
## 0.04 of its capacity; a seam's cut breathes with its glow; motes cut in cells; a source past the cull
## is dropped; a cut only ever ADDS light to a channel and never overshoots the tint; the map carries the
## tint; the veil redraws over a lit base.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_veil_sources.gd
const CELL: int = Heightfield.TERRAIN_CELL_PX
const GRID_W: int = 40
const ROCK_TOP: int = MaterialLook.SURFACE_ROW + 60
const GRID_H: int = ROCK_TOP + 28
const S: int = Fx.SCALE
const WIDE: Rect2 = Rect2(-1000.0, -1000.0, 4000.0, 4000.0)


func _initialize() -> void:
	_test_the_tint()
	_test_the_machine_table()
	_test_the_status_beacon()
	_test_the_placed_sources_and_the_cull()
	_test_the_seams_and_the_motes()
	_test_the_composition_only_adds_light()
	_test_the_map_carries_the_tint()
	await _test_the_veil_redraws_over_a_lit_base()
	_finish("veil_sources")


func _rec(behavior: StringName, cell: Vector2i, status: StringName = &"working", extra: Dictionary = {}) -> Dictionary:
	return _machine_rec(behavior, cell, status, extra)


func _obs_with(machines: Array[Dictionary], placed: Dictionary, power: Dictionary) -> Interface.Observation:
	var o := Interface.Observation.new()
	o.machines = machines
	o.placed = placed
	o.power = power
	return o


func _test_the_tint() -> void:
	var t: Color = VeilSources.light_tint(VeilSources.TORCH_LIGHT)
	_check(is_equal_approx(t.r, 1.0) and is_equal_approx(t.g, 1.0 - 0.28 * (1.0 - 0.72)) and is_equal_approx(t.b, 1.0 - 0.28 * (1.0 - 0.34)), "the torch's tint is its colour 0.28 of the way from white (%.3f %.3f %.3f)" % [t.r, t.g, t.b])
	_check(t.r > t.g and t.g > t.b, "...warm: R > G > B")
	_check(VeilSources.light_tint(Color.WHITE) == Color.WHITE, "a white source tints nothing")
	_check(is_equal_approx(VeilSources.CULL_M, 7.6), "the cull margin is the torch's wide glow, the widest pool (%.1f m)" % VeilSources.CULL_M)


func _test_the_machine_table() -> void:
	_check(is_equal_approx(VeilSources.machine_strength(_rec(&"iron_forge", Vector2i(3, 3))), 0.85), "a furnace cuts 0.85")
	_check(is_equal_approx(VeilSources.machine_strength(_rec(&"iron_forge", Vector2i(3, 3), &"no_input")), 0.85), "...working or not: legacy's veil table has no status gate")
	_check(VeilSources.machine_strength(_rec(&"generator", Vector2i(4, 3), &"no_fuel")) == 0.0, "a burner with no coal cuts nothing: dark when it runs dry")
	_check(is_equal_approx(VeilSources.machine_strength(_rec(&"generator", Vector2i(4, 3), &"working", {"fuel": 2})), 0.9), "...fuelled it cuts 0.9")
	_check(is_equal_approx(VeilSources.machine_strength(_rec(&"generator", Vector2i(4, 3), &"working", {"input": {&"coal": 1}})), 0.9), "...and coal in its input counts as fuel")
	_check(is_equal_approx(VeilSources.machine_strength(_rec(&"lift", Vector2i(5, 3), &"working", {"power_permille": 1000})), 0.9), "a powered lift cuts 0.35 + 0.55")
	_check(is_equal_approx(VeilSources.machine_strength(_rec(&"lift", Vector2i(5, 3), &"working", {"power_permille": 0})), 0.35), "...an unpowered one its 0.35 base")
	_check(is_equal_approx(VeilSources.machine_strength(_rec(&"drill", Vector2i(6, 3))), 0.6), "any other machine the cool 0.6")


## D0401 (T014): a machine that wants something cuts the veil a second time in its status colour, and it
## breathes; a working one cuts once. Asserted on the cuts a starved and a working drill produce.
func _test_the_status_beacon() -> void:
	var starved: Interface.Observation = _obs_with([_rec(&"drill", Vector2i(2, 2), &"no_input")], {}, {})
	var working: Interface.Observation = _obs_with([_rec(&"drill", Vector2i(2, 2), &"working")], {}, {})
	var s_cuts: Array[Dictionary] = VeilSources.cuts(starved, [], [], 0.0, WIDE)
	var w_cuts: Array[Dictionary] = VeilSources.cuts(working, [], [], 0.0, WIDE)
	_check(w_cuts.size() == 1 and s_cuts.size() == 2, "a working drill cuts once, a starved one twice (%d, %d)" % [w_cuts.size(), s_cuts.size()])
	var amber: Color = VeilSources.light_tint(StatusLook.of(&"no_input")["color"])
	var beacon: Dictionary = {}
	for c: Dictionary in s_cuts:
		if c["tint"] == amber:
			beacon = c
	_check(not beacon.is_empty() and is_equal_approx(float(beacon["radius"]), VeilSources.BEACON_R_M * VeilSources.PER_M), "the second cut wears no_input's amber at the beacon radius")
	var rec: Dictionary = _rec(&"drill", Vector2i(2, 2), &"no_input")
	var lo: float = 2.0
	var hi: float = -1.0
	for i: int in 40:
		var b: Dictionary = VeilSources.beacon_cut(rec, Vector2.ZERO, float(i) / 40.0 / VeilSources.BEACON_HZ)
		lo = minf(lo, float(b["strength"]))
		hi = maxf(hi, float(b["strength"]))
	_check(is_equal_approx(lo, VeilSources.BEACON_S_LOW) and is_equal_approx(hi, VeilSources.BEACON_S_HIGH), "it breathes over one period between its two strengths (%.2f..%.2f)" % [lo, hi])
	_check(VeilSources.beacon_cut(_rec(&"drill", Vector2i(2, 2), &"idle"), Vector2.ZERO, 0.3).is_empty() and VeilSources.beacon_cut(_rec(&"drill", Vector2i(2, 2), &"spent"), Vector2.ZERO, 0.3).is_empty() == false, "idle wants nothing and has no beacon; spent wants a relocate and has one")
	var red: Color = VeilSources.light_tint(StatusLook.of(&"no_fuel")["color"])
	_check(VeilSources.beacon_cut(_rec(&"generator", Vector2i(4, 3), &"no_fuel"), Vector2.ZERO, 0.0)["tint"] == red and red != amber, "a burner out of coal pulses red, not amber: the colour is the status's")


func _test_the_placed_sources_and_the_cull() -> void:
	var o: Interface.Observation = _obs_with([_rec(&"drill", Vector2i(2, 2))], {Vector2i(5, 2): &"torch", Vector2i(8, 2): &"conduit", Vector2i(9, 2): &"conduit"}, {Vector2i(8, 2): 1000, Vector2i(9, 2): 10})
	var cuts: Array[Dictionary] = VeilSources.cuts(o, [], [], 0.0, WIDE)
	var cap: int = int(MachinesRecords.RECORDS["conduit"]["capacity_milli"])
	var torches: int = 0
	var conduits: int = 0
	var machines: int = 0
	for c: Dictionary in cuts:
		if c["tint"] == VeilSources.light_tint(VeilSources.TORCH_LIGHT):
			torches += 1
		elif c["tint"] == Color.WHITE:
			conduits += 1
		else:
			machines += 1
	_check(machines == 1 and torches == 2 and conduits == (1 if 1000.0 / float(cap) > VeilSources.CONDUIT_GATE else 0), "a drill, a torch (two cuts) and one conduit over the gate cut; the trickle at 10 milli does not (%d, %d, %d; cap %d)" % [machines, torches, conduits, cap])
	var wide: Dictionary = {}
	var core: Dictionary = {}
	for c: Dictionary in cuts:
		if c["tint"] == VeilSources.light_tint(VeilSources.TORCH_LIGHT):
			if float(c["radius"]) > float(wide.get("radius", 0.0)):
				core = wide
				wide = c
			else:
				core = c
	_check(is_equal_approx(float(wide["radius"]), 7.6 * 4.0) and is_equal_approx(float(wide["strength"]), 0.52) and is_equal_approx(float(core["radius"]), 4.4 * 4.0) and is_equal_approx(float(core["strength"]), 0.94), "the torch: 7.6 m at 0.52 and a 4.4 m core at 0.94, in cells")
	_check((wide["centre"] as Vector2).is_equal_approx(Vector2(22.0, 10.0)), "centred on the logic cell's centre in terrain cells (%s)" % str(wide["centre"]))
	var drill: Dictionary = cuts[0]
	_check(is_equal_approx(float(drill["radius"]), 2.8 * 4.0) and drill["tint"] == VeilSources.light_tint(MachineLook.color(&"drill", &"drill", true)), "the machine cut at 2.8 m in its casing colour's tint")
	var far: Array[Dictionary] = VeilSources.cuts(o, [], [], 0.0, Rect2(500.0, 500.0, 10.0, 10.0))
	_check(far.is_empty(), "every source past the cull rect is dropped (%d)" % far.size())
	_check(VeilSources.cuts(null, [], [], 0.0, WIDE).is_empty(), "no observation, no cuts")


func _test_the_seams_and_the_motes() -> void:
	var o: Interface.Observation = _obs_with([], {}, {})
	var seam: Dictionary = {"pos": Vector2(30.0, 100.0), "radius": 12.0, "cells": []}
	var mote: Dictionary = {"pos": Vector2(40.0, 80.0), "color": Color.RED}
	var cuts: Array[Dictionary] = VeilSources.cuts(o, [seam], [mote], 0.0, WIDE)
	_check(cuts.size() == 2, "one seam and one mote: two cuts (%d)" % cuts.size())
	var sc: Dictionary = cuts[0]
	_check(sc["centre"] == seam["pos"] and is_equal_approx(float(sc["radius"]), 12.0) and sc["tint"] == VeilSources.light_tint(OrePainter.SEAM_LIGHT), "the seam cuts at its own centre and radius in cold cyan's tint")
	var lo: float = 2.0
	var hi: float = 0.0
	for i: int in 200:
		var st: float = VeilSources.seam_strength(float(i) * 0.05, 30.0)
		lo = minf(lo, st)
		hi = maxf(hi, st)
	_check(lo >= 0.62 - 0.001 and hi <= 0.88 + 0.001 and hi - lo > 0.2, "the seam's strength breathes inside 0.62..0.88 (%.3f..%.3f)" % [lo, hi])
	_check(is_equal_approx(VeilSources.seam_strength(1.0, 30.0), 0.62 + 0.26 * OrePainter.breath(1.0, 30.0)), "...with the glow's own breath, so reveal and pool agree")
	var mc: Dictionary = cuts[1]
	_check((mc["centre"] as Vector2).is_equal_approx(Vector2(10.0, 20.0)) and is_equal_approx(float(mc["radius"]), 1.4 * 4.0) and is_equal_approx(float(mc["strength"]), 0.5) and mc["tint"] == Color.WHITE, "a mote at px (40, 80) cuts at cell (10, 20), 1.4 m, 0.5, white")


func _test_the_composition_only_adds_light() -> void:
	var w: Array = _world(&"clay", [Vector2i(20, ROCK_TOP + 4)])
	var obs: Interface.Observation = w[0]
	var field: PackedFloat32Array = VeilPainter.openness(obs, obs.window)
	var cell := Vector2i(20, ROCK_TOP + 3)
	var s: float = VeilPainter.light_at(obs, obs.window, field, cell.x, cell.y)
	var none: Color = VeilPainter.light_rgb_at(obs, obs.window, field, cell.x, cell.y, [])
	_check(is_equal_approx(none.r, clampf(s, 0.0, 1.0)) and none.r == none.g and none.g == none.b, "no cuts: the grey light level in every channel (%.3f)" % s)
	var torch: Array[Dictionary] = [{"centre": Vector2(cell) + Vector2(0.5, 0.5), "radius": 4.4 * 4.0, "strength": 0.94, "tint": VeilSources.light_tint(VeilSources.TORCH_LIGHT)}]
	var lit: Color = VeilPainter.light_rgb_at(obs, obs.window, field, cell.x, cell.y, torch)
	_check(lit.r > none.r + 0.3 and lit.g >= none.g and lit.b >= none.b, "a torch at the cell lifts every channel (R %.3f -> %.3f)" % [none.r, lit.r])
	_check(lit.r > lit.g and lit.g > lit.b, "...warm: the rock comes out amber, not grey")
	_check(lit.r <= 1.0 and lit.g <= torch[0]["tint"].g + 0.001 and lit.b <= torch[0]["tint"].b + 0.001, "...and never past the tint")
	var far: Array[Dictionary] = [{"centre": Vector2(cell) + Vector2(200.0, 0.0), "radius": 4.0, "strength": 0.94, "tint": Color.WHITE}]
	_check(VeilPainter.light_rgb_at(obs, obs.window, field, cell.x, cell.y, far) == none, "a cut out of reach changes nothing")
	var dim: Array[Dictionary] = [{"centre": Vector2(cell) + Vector2(0.5, 0.5), "radius": 8.0, "strength": 0.9, "tint": Color(0.0, 0.0, 0.0)}]
	_check(VeilPainter.light_rgb_at(obs, obs.window, field, cell.x, cell.y, dim) == none, "a black tint cannot take light away: a cut only ever adds")
	var twice: Array[Dictionary] = [torch[0], torch[0]]
	var stacked: Color = VeilPainter.light_rgb_at(obs, obs.window, field, cell.x, cell.y, twice)
	_check(stacked.r >= lit.r and stacked.r <= 1.0, "two stacked cuts brighten further and stay bounded (%.3f -> %.3f)" % [lit.r, stacked.r])
	_check(VeilSources.compose(0.4, [], Vector2i.ZERO) == Color(0.4, 0.4, 0.4, 1.0), "compose with no cuts is the level, opaque")


func _test_the_map_carries_the_tint() -> void:
	var map: VeilMap = VeilMap.new()
	var tex: ImageTexture = map.build(Rect2i(0, 0, 8, 8), func(_c: int, _r: int) -> Color:
		return Color(0.9, 0.5, 0.2))
	_check(tex != null, "the map built")
	var px: Color = map.texel_rgb(0, 0)
	_check(absf(px.r - 0.9) < 0.01 and absf(px.g - 0.5) < 0.01 and absf(px.b - 0.2) < 0.01 and is_equal_approx(px.a, 1.0), "a Color shade writes a tinted, opaque texel (%.3f %.3f %.3f %.2f)" % [px.r, px.g, px.b, px.a])
	var grey_map: VeilMap = VeilMap.new()
	grey_map.build(Rect2i(0, 0, 8, 8), func(_c: int, _r: int) -> float:
		return 0.6)
	var gp: Color = grey_map.texel_rgb(1, 1)
	_check(absf(gp.r - 0.6) < 0.01 and gp.r == gp.g and gp.g == gp.b, "a float shade still writes grey (%.3f)" % gp.r)
	var over_map: VeilMap = VeilMap.new()
	over_map.build(Rect2i(0, 0, 8, 8), func(_c: int, _r: int) -> Color:
		return Color(1.4, -0.2, 0.5))
	var op: Color = over_map.texel_rgb(0, 0)
	_check(is_equal_approx(op.r, 1.0) and is_equal_approx(op.g, 0.0), "channels are clamped into the byte (%.2f %.2f)" % [op.r, op.g])


func _test_the_veil_redraws_over_a_lit_base() -> void:
	var items: Items = _hub_items(20, 40)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(25, 40):
			world.set_solid(Vector2i(col, row), &"ore_iron")
	for x: int in range(30, 38):
		for y: int in range(104, 110):
			world.grid.excavate(Vector2i(x, y))
	machines.place(world, MachineDef.of(&"iron_forge"), Vector2i(3, 24))
	machines.place(world, MachineDef.of(&"torch"), Vector2i(6, 24))
	var body: Body = Body.new(Fx.from_int(34 * 4), Fx.from_int(24 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var falling: FallingItems = FallingItems.new()
	falling.inject(Vector2(130.0, 400.0), Vector2(130.0, 420.0), Color.RED)
	var veil: VeilPainter = VeilPainter.new(OrePainter.new(), falling)
	var ran: Array = [0]
	var cut_count: Array = [0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		veil.paint_frame(f, ci)
		cut_count[0] = VeilSources.cuts_for(f, f.obs.window, OrePainter.new(), falling).size()
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "the veil redrew with its sources on a real view (%d)" % int(ran[0]))
	_check(int(cut_count[0]) >= 3, "...and the frame carried a forge, a torch's two cuts and a mote at least (%d cuts)" % int(cut_count[0]))
	view.queue_free()


func _world(material: StringName, dug: Array[Vector2i]) -> Array:
	return _rock_world(material, dug, ROCK_TOP, GRID_W, GRID_H)
