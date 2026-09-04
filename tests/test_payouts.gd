extends "res://tests/test_base.gd"
## D0365. `view/fx/payouts.gd`: the "+N" tick over the body when the pack gains. It reads gains off the
## OBSERVATION'S PACK rather than off any verb, so the claims are: a gain is a rise in an item's count
## between frames (a spend is not a payout, and the first frame primes rather than ticks), a second
## gain of the same item nearby and soon MERGES into a count instead of stacking, and the layer is
## capped and retires. Pure representation: nothing here can reach the sim.
##
## Run: tools/run_gd_test.sh <godot> res://tests/test_payouts.gd
const S: int = Fx.SCALE


func _initialize() -> void:
	_test_gains_are_rises_in_item_order()
	_test_pack_counts_sum_the_slots()
	_test_a_nearby_soon_gain_merges_into_the_count()
	_test_the_cap_and_the_retirement()
	_test_the_first_frame_primes_and_the_second_ticks()
	await _test_paint_runs_against_a_real_frame()
	_finish("payouts")


func _test_gains_are_rises_in_item_order() -> void:
	var g: Array[Dictionary] = Payouts.gains_between({}, {&"stone": 3, &"iron_ore": 1})
	_check(g.size() == 2 and g[0]["item"] == &"iron_ore" and g[1]["item"] == &"stone", "two rises from an empty pack, in lexical item order (%s)" % str(g))
	_check(int(g[1]["count"]) == 3, "the count is the rise (%d)" % int(g[1]["count"]))
	_check(Payouts.gains_between({&"stone": 3}, {&"stone": 1}).is_empty(), "a spend is not a payout")
	_check(Payouts.gains_between({&"stone": 3}, {}).is_empty(), "an item leaving the pack is not a payout")
	_check(Payouts.gains_between({&"stone": 3}, {&"stone": 3}).is_empty(), "no change is no payout")


func _test_pack_counts_sum_the_slots() -> void:
	var o: Interface.Observation = Interface.Observation.new()
	o.pack = [{"item": &"stone", "count": 2}, {"item": &"coal", "count": 5}, {"item": &"stone", "count": 4}]
	var c: Dictionary = Payouts.pack_counts(o)
	_check(int(c.get(&"stone", 0)) == 6 and int(c.get(&"coal", 0)) == 5, "two stone slots sum to 6, coal 5 (%s)" % str(c))


func _test_a_nearby_soon_gain_merges_into_the_count() -> void:
	var p: Payouts = Payouts.new()
	p.gain(Vector2(100.0, 100.0), &"stone", 1)
	p.gain(Vector2(110.0, 100.0), &"stone", 2)
	_check(p.size() == 1, "a second stone gain 10 px away merges (%d ticks)" % p.size())
	p.gain(Vector2(110.0, 100.0), &"coal", 1)
	_check(p.size() == 2, "a different item nearby is its own tick (%d)" % p.size())
	p.gain(Vector2(100.0 + Payouts.MERGE_RADIUS + 1.0, 100.0), &"stone", 1)
	_check(p.size() == 3, "a stone gain past the merge radius is its own tick (%d)" % p.size())
	var q: Payouts = Payouts.new()
	q.gain(Vector2(100.0, 100.0), &"stone", 1)
	q.advance(Payouts.MERGE_AGE + 0.01)
	q.gain(Vector2(100.0, 100.0), &"stone", 1)
	_check(q.size() == 2, "a gain after the merge age does not merge into the older tick (%d)" % q.size())
	_check(p.size() > 0, "control: the layer holds ticks before retirement")
	p.gain(Vector2(0.0, 0.0), &"stone", 0)
	_check(p.size() == 3, "a zero gain banks nothing")


func _test_the_cap_and_the_retirement() -> void:
	var p: Payouts = Payouts.new()
	for i: int in 30:
		p.gain(Vector2(float(i) * (Payouts.MERGE_RADIUS + 5.0), 0.0), &"stone", 1)
	_check(p.size() == Payouts.MAX, "30 separate gains hold at the cap of %d (%d)" % [Payouts.MAX, p.size()])
	p.advance(Payouts.LIFE * 0.5)
	_check(p.size() == Payouts.MAX, "half a life on, every tick still lives")
	p.advance(Payouts.LIFE * 0.6)
	_check(p.size() == 0, "past the life every tick retired (%d)" % p.size())


func _frame(t: float, pack: Array) -> Frame:
	var f: Frame = Frame.new()
	f.obs = Interface.Observation.new()
	var typed: Array[Dictionary] = []
	for s: Dictionary in pack:
		typed.append(s)
	f.obs.pack = typed
	f.obs.hand = Vector2i(40 * S, 60 * S)
	f.anim_time = t
	return f


func _test_the_first_frame_primes_and_the_second_ticks() -> void:
	var p: Payouts = Payouts.new()
	p.observe_frame(_frame(0.0, [{"item": &"iron_ore", "count": 2}]))
	_check(p.size() == 0, "the first frame primes: a pack that already holds 2 ore is not a payout (%d)" % p.size())
	p.observe_frame(_frame(0.016, [{"item": &"iron_ore", "count": 5}]))
	_check(p.size() == 1, "the second frame's rise from 2 to 5 is one tick (%d)" % p.size())
	p.observe_frame(_frame(0.032, [{"item": &"iron_ore", "count": 5}]))
	_check(p.size() == 1, "an unchanged pack adds nothing (%d)" % p.size())
	p.observe_frame(_frame(0.048, [{"item": &"iron_ore", "count": 3}]))
	_check(p.size() == 1, "a spend adds nothing (%d)" % p.size())
	p.observe_frame(_frame(0.064, [{"item": &"iron_ore", "count": 4}]))
	_check(p.size() == 1, "a rise soon after merges into the live tick rather than stacking (%d)" % p.size())


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
	var layer: Payouts = Payouts.new()
	var ran: Array = [0]
	view.add_painter(func(f: Frame, ci: CanvasItem) -> void:
		layer.gain(Vector2(80.0, 100.0), &"stone", 1)
		layer.paint_frame(f, ci)
		ran[0] = int(ran[0]) + 1)
	await process_frame
	view.refresh()
	for _i: int in 3:
		await process_frame
	_check(int(ran[0]) > 0, "paint_frame() ran inside a real draw pass with a live tick (%d)" % int(ran[0]))
	view.queue_free()
