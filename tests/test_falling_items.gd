extends "res://tests/test_base.gd"
## D0365. `view/fx/falling_items.gd`, the cosmetic half of the hybrid item model on the observation's
## CONSUMED flow channel. The claims worth a test are the ones that would fail silently: the cap (a
## pouring column in an hour-long session must not grow the array), the landing merge BY CELL (ten
## puffs on one cell is one cue, sized by the deepest fall), the consume-once contract on
## `take_landings()` (two consumers cannot both fire the same landing), and the cull box: the head of a
## drop must stay inside `bounds()` for the whole flight, or the drop flickers at the screen edge.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_falling_items.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_the_cell_centre_and_the_scale()
	_test_the_cap_actually_caps()
	_test_events_become_drops_and_drops_become_landings_by_cell()
	_test_landings_are_consumed_once()
	_test_the_arc_starts_at_from_and_ends_at_to()
	_test_the_cull_box_holds_the_head_for_the_whole_flight()
	_test_the_layer_is_deterministic_in_its_events()
	await _test_paint_runs_against_a_real_frame()
	_finish("falling_items")


func _test_the_cell_centre_and_the_scale() -> void:
	var c: Vector2 = FallingItems.cell_center(Vector2i(2, 3)) * FallingItems.SCALE
	_check(c.is_equal_approx(Vector2(40.0, 56.0)), "logic cell (2,3) centres at world px (40,56) -- got %s" % str(c))
	_check(is_equal_approx(FallingItems.SCALE, 0.5), "the fine-detail scale is 16/32 (%f)" % FallingItems.SCALE)
	var pad: float = FallingItems.DRAW_PAD
	_check(pad >= FallingItems.RING_R0 + FallingItems.RING_GROW, "the cull pad covers the fully grown landing ring (%f)" % pad)


func _test_the_cap_actually_caps() -> void:
	var f: FallingItems = FallingItems.new()
	for i: int in 300:
		f.inject(Vector2(float(i), 0.0), Vector2(float(i), 100.0), Color.WHITE)
	_check(f.size() == FallingItems.MAX_ITEMS, "300 injections hold at the cap of %d (%d)" % [FallingItems.MAX_ITEMS, f.size()])


func _test_events_become_drops_and_drops_become_landings_by_cell() -> void:
	var f: FallingItems = FallingItems.new()
	var events: Array[Dictionary] = [
		{"item": &"iron_ore", "from": Vector2i(2, 3), "to": Vector2i(2, 7), "count": 3},
		{"item": &"stone", "from": Vector2i(5, 3), "to": Vector2i(5, 4), "count": 1},
	]
	f.spawn_from_events(events)
	_check(f.size() == 4, "3 + 1 events become 4 drops (%d)" % f.size())
	var motes: Array[Dictionary] = f.motes()
	_check(motes.size() == 4, "one mote per drop for the light pass (%d)" % motes.size())
	_check((motes[0]["pos"] as Vector2).is_equal_approx(FallingItems.cell_center(Vector2i(2, 3)) * FallingItems.SCALE + Vector2(-4.0, 0.0) * FallingItems.SCALE),
		"a fresh mote sits at its source cell's centre, fanned by its stack index (%s)" % str(motes[0]["pos"]))
	f.advance(FallingItems.FALL_DURATION * 0.5)
	_check(f.size() == 4 and f.take_landings().is_empty(), "half-way through the fall nothing has landed")
	f.advance(FallingItems.FALL_DURATION * 0.6)
	_check(f.size() == 0, "past the fall duration every drop retired (%d live)" % f.size())
	var landed: Dictionary = f.take_landings()
	_check(landed.size() == 2, "four drops onto two cells is TWO landings, merged by cell (%d)" % landed.size())
	_check(landed.has(Vector2i(2, 7)) and landed.has(Vector2i(5, 4)), "the landings are keyed by the logic cell they fell to (%s)" % str(landed.keys()))
	var deep: Dictionary = landed.get(Vector2i(2, 7), {})
	_check(is_equal_approx(float(deep.get("drop", -1.0)), 4.0 * 16.0), "the merged landing carries the fall in world px, four cells (%f)" % float(deep.get("drop", -1.0)))
	_check((deep.get("pos", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(40.0 - 4.0 * 0.5, 120.0)) or (deep.get("pos", Vector2.ZERO) as Vector2).distance_to(Vector2(40.0, 120.0)) < 3.0,
		"the landing position is the target cell's centre in world px, within the fan (%s)" % str(deep.get("pos")))
	# the pool reuses: a second wave allocates from the retired drops and still counts correctly
	f.spawn_from_events(events)
	_check(f.size() == 4, "a second wave after retirement spawns the same four drops from the pool (%d)" % f.size())


func _test_landings_are_consumed_once() -> void:
	var f: FallingItems = FallingItems.new()
	f.inject(Vector2(80.0, 0.0), Vector2(80.0, 200.0), Color.RED)
	f.advance(FallingItems.FALL_DURATION * 1.1)
	_check(f.take_landings().size() == 1, "the first consumer sees the landing")
	_check(f.take_landings().is_empty(), "the second consumer in the same frame sees nothing: consumed once")


func _test_the_arc_starts_at_from_and_ends_at_to() -> void:
	var from := Vector2(10.0, 20.0)
	var to := Vector2(90.0, 180.0)
	_check(FallingItems.sample(from, to, 0.0).is_equal_approx(from), "t=0 is the source")
	_check(FallingItems.sample(from, to, 1.0).distance_to(to) < 1e-3, "t=1 is the target (%s)" % str(FallingItems.sample(from, to, 1.0)))
	var mid: Vector2 = FallingItems.sample(from, to, 0.5)
	_check(mid.y < lerpf(from.y, to.y, 0.5), "the bow lifts the mid-flight point above the straight line")
	_check(mid.x > lerpf(from.x, to.x, 0.5), "the horizontal eases out: ahead of linear at mid-flight")
	_check(FallingItems.bow(Vector2.ZERO, Vector2(0.0, 100.0)) < FallingItems.bow(Vector2.ZERO, Vector2(100.0, 100.0)),
		"a sideways toss bows more than a straight drop")


func _test_the_cull_box_holds_the_head_for_the_whole_flight() -> void:
	var cases: Array = [[Vector2(0.0, 0.0), Vector2(0.0, 300.0)], [Vector2(50.0, 40.0), Vector2(-200.0, 90.0)],
		[Vector2(-30.0, -30.0), Vector2(120.0, -35.0)], [Vector2(5.0, 5.0), Vector2(5.0, 5.0)]]
	var all_in: bool = true
	var worst: String = ""
	for c: Array in cases:
		var f: Dictionary = {"from": c[0], "to": c[1], "t": 0.0, "color": Color.WHITE}
		var box: Rect2 = FallingItems.bounds(f)
		for i: int in 21:
			var p: Vector2 = FallingItems.sample(c[0], c[1], float(i) / 20.0)
			if not box.grow(-FallingItems.NUGGET_R).has_point(p):
				all_in = false
				worst = "%s->%s t=%.2f p=%s box=%s" % [str(c[0]), str(c[1]), float(i) / 20.0, str(p), str(box)]
	_check(all_in, "the head plus its nugget stays inside bounds() for every t on four flights%s" % ("" if all_in else " -- " + worst))


func _test_the_layer_is_deterministic_in_its_events() -> void:
	var a: FallingItems = FallingItems.new()
	var b: FallingItems = FallingItems.new()
	var events: Array[Dictionary] = [{"item": &"coal", "from": Vector2i(1, 1), "to": Vector2i(3, 6), "count": 5}]
	a.spawn_from_events(events)
	b.spawn_from_events(events)
	a.advance(0.1)
	b.advance(0.1)
	var same: bool = true
	var ma: Array[Dictionary] = a.motes().duplicate(true)
	var mb: Array[Dictionary] = b.motes()
	for i: int in ma.size():
		if not (ma[i]["pos"] as Vector2).is_equal_approx(mb[i]["pos"]):
			same = false
	_check(same and ma.size() == 5, "two layers fed the same events agree mote for mote: no random draw in the layer")


func _test_paint_runs_against_a_real_frame() -> void:
	var items: Items = _hub_items(20, 20)
	var machines: Machines = _hub_machines(items)
	var world: World = items.world
	for col: int in range(20):
		for row: int in range(15, 20):
			world.set_solid(Vector2i(col, row), &"clay")
	var body: Body = Body.new(Fx.from_int(40), Fx.from_int(14 * 16 + 8) - Body.HEIGHT_PX / 2 * S)
	var door: Interface = Interface.new(world.grid, body, Mining.new(), world, items, machines)
	var view: WorldView = WorldView.new()
	var cam: Camera2D = Camera2D.new()
	root.add_child(view)
	view.add_child(cam)
	view.setup(door, MaterialLook.new(), cam)
	var layer: FallingItems = FallingItems.new()
	var ran: Array = [0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		if f != null and f.obs != null and int(ran[0]) == 0:
			f.obs.flow_events.append({"item": &"iron_ore", "from": Vector2i(3, 10), "to": Vector2i(3, 14), "count": 2})
		layer.paint_frame(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint_frame() ran inside a real draw pass (%d)" % int(ran[0]))
	_check(layer.size() == 2 or not layer.take_landings().is_empty(), "the two drops the frame carried are live or have landed after the pass (%d live)" % layer.size())
	view.queue_free()
