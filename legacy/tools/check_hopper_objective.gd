extends "res://tools/check_base.gd"

## THE "hopper" OBJECTIVE STEP (`scenes/objectives.gd`), added 2026-08-25 to teach a mechanism that
## already worked but was never taught: routing coal through a Hopper instead of hand-feeding a Drill.
## `Objectives._coal_hopper_feeding_drill()` is the predicate the step latches on, and this is its
## positive control — it goes through `sim.tick()` and the real `_run_hopper`, not a hand-set field, so a
## refactor of the hopper's filter logic that broke the real mechanism would show up here too, not just a
## refactor of the predicate.
## Run: godot --headless --path . --script res://tools/check_hopper_objective.gd

func _initialize() -> void:
	print("== hopper objective check ==")
	_negative_controls()
	_real_mechanism()
	_verdict("check_hopper_objective")


## Three ways the predicate must say NO, each isolating one term of the "AND": no hopper at all, a hopper
## banking the wrong thing, and a hopper banking coal but not sitting over a drill.
func _negative_controls() -> void:
	var empty := FactorySim.new()
	var obj := Objectives.new(empty)
	_check(not obj._coal_hopper_feeding_drill(), "an empty world: no hopper, no drill -> false")

	var drill_def: MachineDef = load("res://src/data/machines/drill.tres") as MachineDef
	var hopper_def: MachineDef = load("res://src/data/machines/hopper.tres") as MachineDef
	_check(drill_def != null and hopper_def != null, "fixture: both defs load")
	if drill_def == null or hopper_def == null:
		return

	var wrong_filter := FactorySim.new()
	var d1: MachineState = wrong_filter.place_machine(drill_def, Vector2i(10, 10))
	var h1: MachineState = wrong_filter.place_machine(hopper_def, Vector2i(10, 9))
	_check(d1 != null and h1 != null, "fixture: drill + hopper placed, hopper directly above")
	h1.filter = &"ore"
	var obj1 := Objectives.new(wrong_filter)
	_check(not obj1._coal_hopper_feeding_drill(),
		"a hopper over a drill, filtering ORE not coal -> false (checks the filter, not just the position)")

	var not_over_drill := FactorySim.new()
	var h2: MachineState = not_over_drill.place_machine(hopper_def, Vector2i(20, 9))
	h2.filter = &"coal"
	var obj2 := Objectives.new(not_over_drill)
	_check(not obj2._coal_hopper_feeding_drill(),
		"a hopper filtering coal with nothing below it -> false (checks position, not just the filter)")


## THE POSITIVE CONTROL: a hopper fed coal through `sim.tick()`, exactly as a real drop would, sitting
## above a real drill. If this were true because the predicate is vacuous rather than because the setup
## is real, the negative controls above would already have caught it -- they exercise the same predicate
## against fixtures that share almost everything with this one and differ in exactly one term each.
func _real_mechanism() -> void:
	var sim := FactorySim.new()
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres") as MachineDef
	var hopper_def: MachineDef = load("res://src/data/machines/hopper.tres") as MachineDef
	if drill_def == null or hopper_def == null:
		return
	var drill: MachineState = sim.place_machine(drill_def, Vector2i(10, 10))
	var hopper: MachineState = sim.place_machine(hopper_def, Vector2i(10, 9))
	_check(drill != null and hopper != null, "fixture: drill + hopper placed for the live mechanism")
	if drill == null or hopper == null:
		return
	var obj := Objectives.new(sim)
	_check(not obj._coal_hopper_feeding_drill(), "before any coal falls in: not yet routing")

	hopper.input_buffer[&"coal"] = 10       # the drop a player's Q onto the hopper produces
	for _i: int in 5:
		sim.tick()
	_check(hopper.filter == &"coal", "…_run_hopper latched the real filter on the real first item tasted")
	_check(obj._coal_hopper_feeding_drill(),
		"…and the objective step now reads true, through sim.tick() and _run_hopper, not a hand-set field")
