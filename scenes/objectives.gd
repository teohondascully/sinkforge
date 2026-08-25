class_name Objectives
extends RefCounted

## The guided step ladder: an ordered chain that walks a new player from bare hands to their first
## automation (the self-feeding ore to ingot line), through routing coal so the line runs unattended, then
## hands off toward L2 with a few nudges (research Power, burn coal in a generator, research Descent,
## breach the seal into Stonereach). It ends at the L1 to L2 gate by design, since past it the player
## self-directs through the tech tree and depth, and it deliberately does not keep nudging into L3
## (docs/PROGRESSION.md).
##
## The "hopper" step, 2026-08-25: a live playtest and a design review (docs/handoff/
## PRODUCT_RECOVERY_PASS_2026-08-24.md) found the chain jumped straight from "drop coal on the Drill by
## hand" to "research Power," with nothing about the Hopper in between -- so the player's own hand-feeding
## never stopped, "first automation" stayed half-manual, and Power read as the only answer to a problem a
## Hopper already solves. `hopper.filter`/`R` re-taste and `_first_machine_below` are not new mechanics;
## this step is the first thing in the whole chain to teach them.
##
## Representation only: it reads the sim, never mutates it and never enters the tick. Progress is measured
## as deltas against a baseline snapshotted at construction (lifetime counters minus their start value),
## so a pre-stocked pack cannot tick a step and the ore has to be mined or smelted this run. Completions
## latch, so a transient state such as ore in a buffer or a pile on the ground counts once seen and steps
## never un-complete.

var sim: FactorySim
var _base_produced: Dictionary = {}
var _base_consumed: Dictionary = {}
var _base_machines: int = 0
var _done: Dictionary = {}              ## step id -> true once achieved (latched)
var _all_done_time: float = -1.0        ## seconds the chain has been fully complete, for the HUD auto-hide
## Seconds the current step has been current, reset the moment the chain advances. The HUD shows the long
## how-to only just after a step opens, and again once you have been on one long enough to be stuck.
var step_age: float = 0.0
var _shown_index: int = -1
var _ingots_at_line: int = -1           ## ingots produced the moment the drill/forge line was assembled
var _seal_cells: Array[Vector2i] = []   ## the sealrock cells at construction; a breach opens one

## The ladder. Each step carries a stable id, an imperative label, and a short goal tag shown as a chip.
## Order is the tutorial path: each step must be doable from the state the previous one leaves you in.
## Predicates live in `_achieved`.
var steps: Array[Dictionary] = [
	{"id": &"mine",   "label": "Dig ore — hold LMB on the metal-flecked rock by spawn", "goal": "Mine 4 ore"},
	{"id": &"smelt",  "label": "Toss ore down the mineshaft into the forge (face it, press Q), then drop in to grab the ingots", "goal": "Forge 2 ingots"},
	{"id": &"wood",   "label": "Chop a tree — hold LMB on a trunk to fell it for wood", "goal": "Get wood"},
	{"id": &"bazaar", "label": "Claim the Bazaar — place wood (RMB) in the gap of the ruined frame near spawn", "goal": "Claim the Bazaar"},
	{"id": &"research", "label": "Research AUTOMATION at the Bazaar — press T by the stall, then ENTER on the lit rung (needs an ore sample + 2 ingots)", "goal": "Research Automation"},
	{"id": &"craft",  "label": "Stand by the Bazaar, press E, then the Drill key to craft a Drill", "goal": "Craft a Drill"},
	{"id": &"build",  "label": "Drop the Drill into the shaft just ABOVE the ore vein (RMB) — it bores down into it", "goal": "Build the line"},
	{"id": &"fuel",   "label": "The Drill needs COAL — mine the coal vein right of the shaft, then drop coal on the Drill (Q)", "goal": "Fuel the Drill"},
	{"id": &"auto",   "label": "Stand back — the fueled Drill bores the vein and pours ore into the forge below. First automation!", "goal": "First automation"},
	{"id": &"hopper", "label": "Coal by hand runs dry — craft a HOPPER (E), place it above the Drill (RMB), then drop coal in the top", "goal": "Automate the coal feed"},
	# --- the L1 to L2 handoff. The chain ends after this; the player self-directs from here.
	{"id": &"power",     "label": "Research POWER at the Bazaar (T, then ENTER) — the deep needs energy", "goal": "Research Power"},
	{"id": &"generator", "label": "Craft a GENERATOR, place it, and toss coal in (Q) to burn it for power", "goal": "Burn coal for power"},
	{"id": &"descent",   "label": "Research the DESCENT ENGINE at the Bazaar — the way down is sealed", "goal": "Research Descent"},
	{"id": &"breach",    "label": "Feed a Descent Engine on the seal to breach into Stonereach — then explore on your own", "goal": "Breach the seal"},
]


func _init(factory: FactorySim) -> void:
	sim = factory
	_base_produced = factory.total_produced.duplicate()
	_base_consumed = factory.total_consumed.duplicate()
	_base_machines = factory.machines.size()
	# Snapshot the intact seal, every sealrock cell. A Descent Engine bores straight down through the band,
	# so "breached" means any snapshotted cell is no longer sealrock. Read the material rather than a
	# worldgen constant, so this stays decoupled from any one generator.
	for cell: Vector2i in factory.solid.keys():
		if factory.solid[cell] == &"sealrock":
			_seal_cells.append(cell)


## Call every frame to latch any newly-achieved step. A handful of dict reads.
func refresh(delta: float) -> void:
	for step: Dictionary in steps:
		var id: StringName = step["id"]
		if not _done.has(id) and _achieved(id):
			_done[id] = true
	var i: int = current_index()
	if i != _shown_index:
		_shown_index = i
		step_age = 0.0
	else:
		step_age += delta
	if all_done():
		_all_done_time = (_all_done_time if _all_done_time >= 0.0 else 0.0) + delta


## Index of the current (first incomplete) step, or steps.size() if the whole chain is done.
func current_index() -> int:
	for i: int in steps.size():
		if not _done.has(steps[i]["id"]):
			return i
	return steps.size()


## The id of the current (first incomplete) step, or &"" when the whole chain is done. The controller
## maps the id to cells so the view can highlight where the step happens.
func current_id() -> StringName:
	var i: int = current_index()
	return steps[i]["id"] if i < steps.size() else &""


func is_done(id: StringName) -> bool:
	return _done.has(id)


func all_done() -> bool:
	return _done.size() >= steps.size()


## Seconds since the chain finished, so the HUD can fade the panel out. -1 until complete.
func done_for() -> float:
	return _all_done_time


# --- predicates, all run deltas over the sim's lifetime counters ---------------------------------

func _achieved(id: StringName) -> bool:
	match id:
		&"mine":   return _produced(&"ore") >= 4
		&"smelt":  return _produced(&"ingot") >= 2 and int(sim.inventory.get(&"ingot", 0)) >= 2  # smelted and collected
		&"wood":   return _produced(&"wood") >= 1                                                 # felled a tree this run
		&"bazaar": return not sim.find_bazaars().is_empty()                                       # a frame is complete
		&"research": return sim.is_researched(&"automation")                                      # the drill is unlocked
		&"craft":  return int(sim.inventory.get(&"drill", 0)) >= 1 or _has_drill_machine()        # in pack or placed
		&"build": return not _find_line().is_empty()                                             # the drill/forge stack exists
		&"fuel":  return _drill_fueled()                                                          # the drill has coal to burn
		&"auto":  return _line_has_run()                                                          # it forged an ingot on its own
		&"hopper":    return _coal_hopper_feeding_drill()                                         # coal routed, not hand-dropped
		&"power":     return sim.is_researched(&"power")                                          # the generator is unlocked
		&"generator": return _generator_burning()                                                # a placed generator is burning
		&"descent":   return sim.is_researched(&"descent")                                        # the engine is unlocked
		&"breach":    return _seal_breached()                                                     # the seal has been bored open
	return false


## The self-feeding line, detected anywhere in the world: a drill placed above a solid ore vein, boring
## down the column into ore that falls toward a forge below. Returns {drill: cell}, or {} if none. It is
## location-independent, so any drill sitting over ore it can still bore counts.
func _find_line() -> Dictionary:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"drill" and sim.drill_column_remaining(m.cell) > 0:
			return {"drill": m.cell}
	return {}


## True once a built line has forged an ingot on its own. The ingot count is snapshotted the moment a drill
## first caps an ore body and latches when production passes it, which is what proves the drill drove the
## smelt rather than the player's hand. It reads production rather than the ground pile, which is transient.
func _line_has_run() -> bool:
	if _find_line().is_empty():
		return false
	if _ingots_at_line < 0:
		_ingots_at_line = _produced(&"ingot")   # the line just appeared: mark the baseline, not done yet
		return false
	return _produced(&"ingot") > _ingots_at_line


func _has_drill_machine() -> bool:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"drill":
			return true
	return false


## A placed drill fueled with coal, either burning now or with coal waiting in its buffer. The drill will
## not pull ore until it is fed, so this is the step that teaches the demand web.
func _drill_fueled() -> bool:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"drill" and (m.fuel > 0 or int(m.input_buffer.get(&"coal", 0)) > 0):
			return true
	return false


## A Hopper banking coal and sitting directly above a Drill, the real (and only) mechanism the game has
## for routing fuel automatically: `_run_hopper` metes its filtered good straight down to whatever
## `_first_machine_below` finds. Reads the filter rather than the buffer, since a hopper can hold zero
## coal for a beat between deliveries and still be the thing doing the routing -- the buffer is transient,
## the filter latches the moment coal is first banked and only clears on a deliberate R.
func _coal_hopper_feeding_drill() -> bool:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"hopper" and m.filter == &"coal":
			var below: MachineState = sim._first_machine_below(m.cell)
			if below != null and below.def.behavior == &"drill":
				return true
	return false


## A placed generator that is actually burning. The step teaches "burn coal for power", so it must read
## fed rather than merely placed, mirroring _drill_fueled.
func _generator_burning() -> bool:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"generator" and (m.fuel > 0 or int(m.input_buffer.get(&"coal", 0)) > 0):
			return true
	return false


## Has the seal been breached? A Descent Engine at quota bores the sealrock band open straight below it,
## so any cell that was sealrock at world load and is no longer counts, anywhere in the band.
func _seal_breached() -> bool:
	for cell: Vector2i in _seal_cells:
		if sim.solid.get(cell, &"") != &"sealrock":
			return true
	return false


func _produced(item: StringName) -> int:
	return int(sim.total_produced.get(item, 0)) - int(_base_produced.get(item, 0))


func _consumed(item: StringName) -> int:
	return int(sim.total_consumed.get(item, 0)) - int(_base_consumed.get(item, 0))
