extends "res://tests/test_base.gd"

## `sim/economy`'s live remainder (A' step 3f, D0351): the production-rate ring buffer, legacy's
## `_test_production_rate` re-expressed in integers (centi-items per minute) with the window, the
## tie-break and the "derived, not state" claim pinned. Legacy fed it from an ore vent (a ruling); here
## the ledger is fed by hand, which the rate counts the same way.


func _initialize() -> void:
	_test_rate_is_zero_until_a_second_of_history_then_exact()
	_test_window_caps_at_sixty_one_samples_and_slides()
	_test_rates_lists_live_items_fastest_first_ties_in_text_order()
	_test_derived_never_in_a_signature_and_the_hub_constant_is_the_body_divided()
	_finish("economy")


func _mine(items: Items, item: StringName, n: int) -> void:
	items.pack.add(item, n)
	items.produced(item, n)


func _test_rate_is_zero_until_a_second_of_history_then_exact() -> void:
	var items: Items = _hub_items()
	var machines: Machines = _hub_machines(items)
	var rates: ProductionRate = ProductionRate.new()
	_check(rates.rate_centi(items, &"ore") == 0 and rates.rates(items).is_empty(), "no history: rate 0, nothing listed")
	for _i: int in 19:
		_mine(items, &"ore", 1)
		HubTick.step(items.world, items, machines, rates)
	_check(rates.sample_count() == 0 and rates.rate_centi(items, &"ore") == 0, "19 ticks: no sample yet, rate 0")
	_mine(items, &"ore", 1)
	HubTick.step(items.world, items, machines, rates)
	_check(rates.sample_count() == 1 and rates.rate_centi(items, &"ore") == 0, "tick 20: the first snapshot, but a rate needs a second sample's span")
	for _i: int in 180:
		_mine(items, &"ore", 1)
		HubTick.step(items.world, items, machines, rates)
	_check(rates.sample_count() == 10 and rates.rate_centi(items, &"ore") == 120000, "one ore a tick over 200 ticks: 20/s = 1200/min = 120000 centi, exact")
	_check(rates.rate_centi(items, &"mystery") == 0, "unknown item: 0")
	var tops: Array[Dictionary] = rates.rates(items)
	_check(tops.size() == 1 and tops[0]["item"] == &"ore" and int(tops[0]["rate_centi"]) == 120000, "rates lists the one flowing item")
	_check(Invariants.check_item_conservation(items, 200) == null and items.present(&"ore") == 200, "sampling is conservation-neutral")
	for _i: int in 200:
		HubTick.step(items.world, items, machines, rates)
	_check(rates.rate_centi(items, &"ore") == 180 * ProductionRate.CENTI_PER_MINUTE / 380, "production stopped: the window still sees the 180 made after its oldest sample, over a span of 380 (60000 centi)")


func _test_window_caps_at_sixty_one_samples_and_slides() -> void:
	var items: Items = _hub_items()
	var machines: Machines = _hub_machines(items)
	var rates: ProductionRate = ProductionRate.new()
	for _i: int in 61 * 20:
		HubTick.step(items.world, items, machines, rates)
	_check(rates.sample_count() == 61, "61 samples after 1220 ticks: the window is full")
	for _i: int in 20:
		_mine(items, &"ingot", 1)
		HubTick.step(items.world, items, machines, rates)
	_check(rates.sample_count() == 61, "the 62nd sample pops the oldest: still 61")
	_check(rates.rate_centi(items, &"ingot") == 20 * ProductionRate.CENTI_PER_MINUTE / 1200, "the span is the window's 1200 ticks: 20 ingots over a minute = 2000 centi")
	for _i: int in 61 * 20:
		HubTick.step(items.world, items, machines, rates)
	_check(rates.rate_centi(items, &"ingot") == 0, "a minute of silence and the burst has left the window")


func _test_rates_lists_live_items_fastest_first_ties_in_text_order() -> void:
	var items: Items = _hub_items()
	var machines: Machines = _hub_machines(items)
	var rates: ProductionRate = ProductionRate.new()
	for _i: int in 40:
		_mine(items, &"zinc", 1)
		_mine(items, &"ore", 1)
		_mine(items, &"ingot", 3)
		HubTick.step(items.world, items, machines, rates)
	var tops: Array[Dictionary] = rates.rates(items)
	var order: Array[StringName] = []
	for row: Dictionary in tops:
		order.append(row["item"])
	var expected: Array[StringName] = [&"ingot", &"ore", &"zinc"]
	_check(order == expected, "fastest first, and the two tied at one a tick in TEXT order (ore before zinc), not insertion order")
	_check(int(tops[0]["rate_centi"]) == 3 * int(tops[1]["rate_centi"]), "ingots at three times the ore's rate")
	_mine(items, &"speck", 1)
	for _i: int in 1200:
		HubTick.step(items.world, items, machines, rates)
	var late: Array[Dictionary] = rates.rates(items)
	_check(late.size() == 1 and late[0]["item"] == &"speck" and int(late[0]["rate_centi"]) == 100, "a minute on, the one speck is the only live item: one a minute is 100 centi, the smallest rate the window can show")
	for _i: int in 20:
		HubTick.step(items.world, items, machines, rates)
	_check(rates.rates(items).is_empty() and rates.rate_centi(items, &"speck") == 0, "a second later the oldest sample already holds it: rate 0, not listed")


func _test_derived_never_in_a_signature_and_the_hub_constant_is_the_body_divided() -> void:
	var items: Items = _hub_items()
	var machines: Machines = _hub_machines(items)
	var before: String = items.state_signature() + machines.state_signature() + items.world.state_signature()
	var rates: ProductionRate = ProductionRate.new()
	for _i: int in 100:
		HubTick.step(items.world, items, machines, rates)
	_check(rates.sample_count() == 5 and items.state_signature() + machines.state_signature() + items.world.state_signature() == before, "five samples taken and no signature moved: the ring buffer is history, not state")
	_check(ProductionRate.HUB_HZ * HubTick.HUB_TICK_DIVISOR == Body.TICK_HZ, "HUB_HZ is the body's tick rate over the hub divisor (20 = 60 / 3)")
	_check(ProductionRate.CENTI_PER_MINUTE == 120000 and ProductionRate.SAMPLE_TICKS == 20 and ProductionRate.WINDOW_SAMPLES == 61, "legacy's constants: a sample a second, a minute of them")
