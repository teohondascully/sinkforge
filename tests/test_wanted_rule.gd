extends "res://tests/test_base.gd"

## `view/hud/wanted_rule.gd` and the hotbar mark it drives (item 41, D0592): joining "you are carrying
## coal" to "the forge is starved". Both halves were already drawn and neither knew about the other.
##
## The assertions pin the RULE, not the pixels: which statuses are answered by something in your pack,
## which are not, and that a marked slot wears the machine's own mark rather than a colour alone.
##
## Run: tools/run_gd_test.sh <godot-binary> res://tests/test_wanted_rule.gd


func _initialize() -> void:
	_test_a_starved_forge_marks_the_coal_you_carry()
	_test_a_status_no_item_can_fix_marks_nothing()
	_test_the_rig_asks_for_its_demand_and_not_a_recipe()
	_test_the_hotbar_carries_the_mark_only_on_the_matching_slot()
	_test_the_mark_is_the_machines_own_and_not_colour_alone()
	_finish("wanted_rule")


func _obs(machines: Array[Dictionary], pack: Array = []) -> Interface.Observation:
	var o: Interface.Observation = Interface.Observation.new()
	o.machines = machines
	var typed: Array[Dictionary] = []
	for i: int in pack.size():
		typed.append({"item": StringName(pack[i]), "count": 3})
	o.pack = typed
	o.pack_selected = 0
	o.pack_slots = 10
	o.pack_bulk_cap = 40
	o.pack_bulk = 0
	return o


func _machine(behavior: StringName, status: StringName, recipe: StringName = &"", extra: Dictionary = {}) -> Dictionary:
	var rec: Dictionary = {"behavior": behavior, "status": status, "recipe": recipe,
		"cell": Vector2i(4, 4), "input": {}, "output": {}, "fuel": 0}
	rec.merge(extra, true)
	return rec


## THE ITEM ITSELF. A forge out of fuel asks for coal, whatever else it is holding.
func _test_a_starved_forge_marks_the_coal_you_carry() -> void:
	var w: Dictionary = WantedRule.wanted(_obs([_machine(&"processor", &"no_fuel", &"smelt_ingot")]))
	_check(w.has(&"coal") and w[&"coal"] == &"no_fuel",
		"a forge with no fuel asks for coal (%s)" % [w])
	# CONTROL: the same machine working asks for nothing at all.
	var run: Dictionary = WantedRule.wanted(_obs([_machine(&"processor", &"working", &"smelt_ingot")]))
	_check(run.is_empty(), "and a working forge asks for nothing (%s)" % [run])


## THE GATE IS `feeds`, NOT "has a need". Walking over with coal does not fix a power cut, a jam or an
## unlinked winch, so those must not light a stack -- `BubbleRule.wants_bubble` is true for all three.
func _test_a_status_no_item_can_fix_marks_nothing() -> void:
	for status: StringName in [&"no_power", &"blocked", &"unlinked", &"spent", &"idle"]:
		var m: Dictionary = _machine(&"processor", status, &"smelt_ingot")
		var w: Dictionary = WantedRule.wanted(_obs([m]))
		var bubbles: bool = BubbleRule.wants_bubble(m)
		_check(w.is_empty(),
			"%s marks no stack (bubble says it has a need: %s) -- an item in the pack cannot fix it" % [status, bubbles])


## The rig is the exception `need_item` already carries: its `wants` is the live demand, not a recipe.
func _test_the_rig_asks_for_its_demand_and_not_a_recipe() -> void:
	var rig: Dictionary = _machine(&"rig", &"no_input", &"", {"wants": {&"ingot": 2}})
	var w: Dictionary = WantedRule.wanted(_obs([rig]))
	_check(w.has(&"ingot"), "the rig asks for the demand's item (%s)" % [w])


## THE JOIN. The marked slot is the one holding the wanted item, and only that one.
func _test_the_hotbar_carries_the_mark_only_on_the_matching_slot() -> void:
	var f: Frame = Frame.new()
	f.obs = _obs([_machine(&"processor", &"no_fuel", &"smelt_ingot")], [&"ore", &"coal", &"ingot"])
	var l: Dictionary = Hotbar.layout(f, ThemeDB.fallback_font)
	_check(not l.is_empty(), "the bar lays out")
	var marked: Array = []
	for well: Dictionary in l["wells"]:
		if well.has("wanted"):
			marked.append(String(well.get("item", &"?")))
	_check(marked == ["coal"], "exactly the coal slot is marked, of ore/coal/ingot (%s)" % [marked])
	# CONTROL, and it is the one that matters: with nothing asking, no slot is marked at all. Without
	# this the assertion above passes on a rule that marks every slot it is handed.
	var quiet: Frame = Frame.new()
	quiet.obs = _obs([_machine(&"processor", &"working", &"smelt_ingot")], [&"ore", &"coal", &"ingot"])
	var ql: Dictionary = Hotbar.layout(quiet, ThemeDB.fallback_font)
	var any: bool = false
	for well: Dictionary in ql["wells"]:
		any = any or well.has("wanted")
	_check(not any, "and with nothing asking, no slot is marked")


## `StatusLook`'s own finding, applied here: "green working against red no-fuel is the single most common
## colour confusion there is... for a deuteranope those three lamps were one lamp." So the slot's cue is
## a MARK, and it is the machine's own mark, which is what makes the two read as one statement.
func _test_the_mark_is_the_machines_own_and_not_colour_alone() -> void:
	_check(StringName(StatusLook.of(&"no_fuel")["mark"]) == &"feed"
			and StringName(StatusLook.of(&"no_input")["mark"]) == &"feed",
		"both item-needs wear the `feed` mark, which is what the slot repeats")
	_check(WantedRule.tint(&"no_fuel") == StatusLook.of(&"no_fuel")["color"],
		"and the slot's tint IS the machine's lamp colour, not a second palette")
	_check(WantedRule.tint(&"no_fuel") != WantedRule.tint(&"no_input"),
		"the two differ in colour as well, so the pair is legible by either channel")
