extends "res://tools/check_base.gd"

## THE HOPPER'S "blocked" STATUS (`FactorySim._status_hopper`, added 2026-08-25 for recovery priority #5,
## docs/PRIORITY.md), the visual/interaction language gap a live playtest and design review both named:
## the hopper had exactly two states, idle (empty) and working (holds anything), so a hopper banking its
## filtered good with nowhere to put it -- the consumer below backed up to HOPPER_FEED_CAP -- looked
## IDENTICAL to one genuinely feeding a drill. `_status_hopper` gives that a real third state, reusing the
## status-lamp + need-bubble machinery every other stalled machine already draws through
## (`MachineView._draw_machine_status`, `Visuals.STATUS_LOOK[&"blocked"]`) rather than adding new glyph
## code, so this check exercises the sim-side predicate the whole existing display chain already trusts.
##
## Run: godot --headless --path . --script res://tools/check_hopper_status.gd

func _initialize() -> void:
	print("== hopper status check ==")
	_negative_controls()
	_real_mechanism()
	_verdict("check_hopper_status")


## Three ways a hopper must NOT read as blocked, each isolating one term of the real gate:
## empty (nothing banked at all), storage mode (nothing below -- `_run_hopper`'s own comment calls this
## intentional, not broken), and below-but-with-room (load under HOPPER_FEED_CAP).
func _negative_controls() -> void:
	var hopper_def: MachineDef = load("res://src/data/machines/hopper.tres") as MachineDef
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres") as MachineDef
	_check(hopper_def != null and drill_def != null, "fixture: both defs load")
	if hopper_def == null or drill_def == null:
		return

	var empty := FactorySim.new()
	var h0: MachineState = empty.place_machine(hopper_def, Vector2i(10, 9))
	_check(h0 != null, "fixture: a bare hopper placed")
	if h0 != null:
		_check(empty.machine_status(h0) == &"idle", "an untouched hopper (no filter, nothing banked) -> idle")

	var storage := FactorySim.new()
	var h1: MachineState = storage.place_machine(hopper_def, Vector2i(10, 9))
	_check(h1 != null, "fixture: a hopper with nothing below it")
	if h1 != null:
		h1.input_buffer[&"coal"] = 5
		h1.filter = &"coal"
		_check(storage.machine_status(h1) != &"blocked",
			"a hopper banking coal with NOTHING below it -> not blocked (deliberate storage, not a stall)")

	var roomy := FactorySim.new()
	var d1: MachineState = roomy.place_machine(drill_def, Vector2i(10, 10))
	var h2: MachineState = roomy.place_machine(hopper_def, Vector2i(10, 9))
	_check(d1 != null and h2 != null, "fixture: drill + hopper, hopper directly above")
	if d1 != null and h2 != null:
		d1.input_buffer[&"coal"] = FactorySim.HOPPER_FEED_CAP - 1     # under the cap: there is still room
		h2.input_buffer[&"coal"] = 5
		h2.filter = &"coal"
		_check(roomy.machine_status(h2) != &"blocked",
			"a hopper over a drill with room to spare (%d < HOPPER_FEED_CAP) -> not blocked"
				% (FactorySim.HOPPER_FEED_CAP - 1))


## THE POSITIVE CONTROL: a hopper banking coal over a drill whose own coal buffer is already topped up to
## HOPPER_FEED_CAP, ticked through the real `_run_hopper` rather than asserted from a hand-set status. Two
## things must both be true, not just the derived label: the hopper's own stock must stop draining (the
## real release loop is the thing that paused, not a status word painted over an unrelated mechanism), and
## once the drill's buffer is relieved below the cap the SAME hopper must resume on its own -- proving this
## is a live back-pressure gate and not a one-way "stuck forever" flag.
func _real_mechanism() -> void:
	var hopper_def: MachineDef = load("res://src/data/machines/hopper.tres") as MachineDef
	var drill_def: MachineDef = load("res://src/data/machines/drill.tres") as MachineDef
	if hopper_def == null or drill_def == null:
		return
	var sim := FactorySim.new()
	var drill: MachineState = sim.place_machine(drill_def, Vector2i(10, 10))
	var hopper: MachineState = sim.place_machine(hopper_def, Vector2i(10, 9))
	_check(drill != null and hopper != null, "fixture: drill + hopper placed for the live mechanism")
	if drill == null or hopper == null:
		return

	drill.input_buffer[&"coal"] = FactorySim.HOPPER_FEED_CAP        # the consumer below, already topped up
	hopper.input_buffer[&"coal"] = 10
	for _i: int in 5:
		sim.tick()
	_check(hopper.filter == &"coal", "…_run_hopper latched the real filter on the real first item tasted")
	_check(sim.machine_status(hopper) == &"blocked",
		"…and with the drill backed up to the cap, the hopper now reads blocked")
	_check(int(hopper.input_buffer.get(&"coal", 0)) == 10,
		"…because the real release loop actually paused: the hopper's own bank never drained")

	# Relief, repeated rather than a single snapshot: a real consumer does not sit pinned at the cap, it
	# burns down what it holds each cycle (`_run_drill`'s own fuel burn, in play). Re-clamping the drill's
	# buffer low before every tick stands in for that consumption. A single post-relief tick is NOT enough
	# to assert `machine_status(hopper) != &"blocked"` on, because `_flow()` delivers a hopper's release the
	# same tick it fires -- one relieved tick can legitimately hand the drill straight back to the cap and
	# read blocked again one instant later, which is correct back-pressure, not a bug. What must hold across
	# the window is that release actually happened.
	var before: int = int(hopper.input_buffer.get(&"coal", 0))
	for _i2: int in 3:
		drill.input_buffer[&"coal"] = 1        # stands in for the drill having burned its fuel down
		sim.tick()
	_check(int(hopper.input_buffer.get(&"coal", 0)) < before,
		"…relieved repeatedly, the SAME hopper resumes releasing on its own, no reconfiguration needed")
