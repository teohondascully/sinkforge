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
	_test_a_loss_is_a_named_signed_tick_that_never_merges_with_a_gain()
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
	return _frame_with(t, pack, Interface.Observation.new())


func _frame_with(t: float, pack: Array, obs: Interface.Observation) -> Frame:
	var f: Frame = Frame.new()
	f.obs = obs
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
	_check(p.size() == 2, "a spend is a loss tick of its own (D0424 reversed D0365's silence: a drop read as a forge at work) (%d)" % p.size())
	p.observe_frame(_frame(0.064, [{"item": &"iron_ore", "count": 4}]))
	_check(p.size() == 2, "a rise soon after merges into the live GAIN tick rather than stacking or touching the loss (%d)" % p.size())


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


## D0424 (stranger 3; T029): the tick names its item, and a stack leaving the pack is a tick too, signed
## the other way and kept apart from a gain of the same item at the same spot -- a drop re-collected after
## its grace shows both, in order.
func _test_a_loss_is_a_named_signed_tick_that_never_merges_with_a_gain() -> void:
	var l: Array[Dictionary] = Payouts.losses_between({&"ore": 7, &"stone": 2}, {&"stone": 2})
	_check(l.size() == 1 and l[0]["item"] == &"ore" and int(l[0]["count"]) == 7, "ore leaving the pack entirely is a loss of 7 (%s)" % str(l))
	_check(Payouts.losses_between({&"stone": 3}, {&"stone": 1}).size() == 1 and int(Payouts.losses_between({&"stone": 3}, {&"stone": 1})[0]["count"]) == 2, "a spend of 2 is a loss of 2")
	_check(Payouts.losses_between({}, {&"stone": 3}).is_empty() and Payouts.losses_between({&"stone": 3}, {&"stone": 3}).is_empty(), "a rise and no change are not losses")
	_check(Payouts.label_of(&"ore", 7, false) == "+7 ore" and Payouts.label_of(&"ore", 7, true) == "-7 ore", "the label is signed and named (%s / %s)" % [Payouts.label_of(&"ore", 7, false), Payouts.label_of(&"ore", 7, true)])
	_check(Payouts.label_of(&"drill", 1, true) == "-1 drill", "a machine item takes its record's display name, lowered (%s)" % Payouts.label_of(&"drill", 1, true))
	_coming_pins()
	var p: Payouts = Payouts.new()
	p.gain(Vector2(0, 0), &"ore", 7)
	p.lose(Vector2(0, 0), &"ore", 7)
	_check(p.size() == 2, "a loss at the spot of a young gain of the same item is its own tick (%d)" % p.size())
	p.lose(Vector2(2, 0), &"ore", 1)
	_check(p.size() == 2, "a second loss nearby merges into the loss, not the gain (%d)" % p.size())
	var q: Payouts = Payouts.new()
	q.observe_frame(_frame(0.0, [{"item": &"ore", "count": 7}]))
	q.observe_frame(_frame(0.1, []))
	_check(q.size() == 1, "the pack emptied between frames: one loss tick (%d)" % q.size())
	for i: int in 10:                                 # dt clamps at 0.1 a frame: ten frames age the loss past its life
		q.observe_frame(_frame(0.2 + 0.1 * float(i), []))
	q.observe_frame(_frame(1.3, [{"item": &"ore", "count": 7}]))
	_check(q.size() == 1, "re-collected after the grace: the loss has retired and the gain is its own tick (%d)" % q.size())


## T033 (D0442, stranger 8): the arrival tick says how many more the forge beside you still owes -- its
## output buffer plus what its held ore will smelt by the recipe -- and nothing when the machine is out of
## the collect reach, holds too little for a batch, or the tick is a loss.
func _coming_pins() -> void:
	var f: Frame = _frame(0.0, [])
	var o: Interface.Observation = f.obs
	o.pos_x = 10 * 16 * S
	o.pos_y = 10 * 16 * S
	var forge: Dictionary = {"cell": Vector2i(11, 10), "id": &"processor", "recipe": &"smelt_ingot", "input": {&"ore": 5, &"coal": 3}, "output": {&"ingot": 1}}   # D0483: a craft is 2 ore + 1 coal
	var far: Dictionary = {"cell": Vector2i(30, 10), "id": &"processor", "recipe": &"smelt_ingot", "input": {&"ore": 8, &"coal": 4}, "output": {}}
	var typed: Array[Dictionary] = [forge, far]
	o.machines = typed
	_check(Payouts.coming(o, &"ingot") == 3, "five ore held and one ingot waiting in the forge a metre off: 2 + 1 = %d more coming; the forge twenty metres off counts nothing" % Payouts.coming(o, &"ingot"))
	_check(Payouts.coming(o, &"ore") == 0, "ore is the forge's input, not its output: nothing coming")
	forge["input"] = {&"ore": 1, &"coal": 1}
	forge["output"] = {}
	_check(Payouts.coming(o, &"ingot") == 0, "one ore is short of a two-ore batch: nothing coming")
	_check(Payouts.label_of(&"ingot", 1, false, 2) == "+1 ingot · 2 more" and Payouts.label_of(&"ingot", 1, false, 0) == "+1 ingot" and Payouts.label_of(&"ore", 7, true, 2) == "-7 ore",
		"the label carries the remainder on a gain only (%s)" % Payouts.label_of(&"ingot", 1, false, 2))
	var p: Payouts = Payouts.new()
	forge["input"] = {&"ore": 4, &"coal": 2}
	p.observe_frame(f)
	p.observe_frame(_frame_with(0.016, [{"item": &"ingot", "count": 1}], o))
	_check(p.size() == 1 and int((p._t[0] as Dictionary)["more"]) == 2, "an ingot arriving beside a forge holding four ore ticks with 2 more (%s)" % [p._t])
