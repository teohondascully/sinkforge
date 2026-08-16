class_name Objectives
extends RefCounted

## REPRESENTATION-LAYER legibility (NOT sim): an ordered, guided ladder that walks a new player from bare
## hands to their FIRST AUTOMATION — the self-feeding ore→ingot line — then hands off toward L2 with a FEW
## gentle nudges (research Power → burn coal in a generator → research Descent → breach the seal into
## Stonereach). It is the direct answer to "what do I do?" / "how do I get to L2?": there is a signposted
## next action right up to the L1→L2 gate, after which the chain ENDS and the player self-directs via the
## tech tree + depth (we deliberately do NOT keep nudging into L3 — docs/PROGRESSION.md).
## It READS the sim only (never mutates, never enters the tick), so deleting it changes no production number.
##
## It measures SESSION DELTAS from a baseline snapshot taken at construction (lifetime counters minus their
## start value), so it still guides correctly even when the dev-start kit pre-stocks the pack — you must
## actually mine/smelt THIS session for a step to tick. Completions LATCH: a transient state (ore in a
## buffer, a pile on the ground) still counts once seen, so steps never un-complete.
##
## The chain IS the spec the Rung-1 agent-play-test drives (tools/play_tests.gd): the test follows these
## same steps through the real verbs and fails if any step can't be reached — "nothing to do" made executable.

var sim: FactorySim
var _base_produced: Dictionary = {}
var _base_consumed: Dictionary = {}
var _base_machines: int = 0
var _done: Dictionary = {}              ## step id -> true once achieved (latched)
var _all_done_time: float = -1.0        ## seconds the chain has been fully complete (for HUD auto-hide)
## Seconds the CURRENT step has been the current one, reset the moment the chain advances. The HUD reads
## it to show the long how-to only while it's wanted: right after a step opens, and again once you've
## been on one long enough to be stuck (#B4).
var step_age: float = 0.0
var _shown_index: int = -1
var _ingots_at_line: int = -1           ## ingots produced the moment the drill→forge line was assembled
var _seal_cells: Array[Vector2i] = []   ## the sealrock cells at construction — a breach opens one (below)

## The Rung-1 ladder. Each step: stable id, an imperative label (what to DO), and a short goal tag (the
## win condition, shown as the chip). Order IS the tutorial path — each step is doable from the state the
## previous one leaves you in. Predicates live in `_achieved`.
var steps: Array[Dictionary] = [
	{"id": &"mine",   "label": "Dig ore — hold LMB on the metal-flecked rock by spawn", "goal": "Mine 4 ore"},
	{"id": &"smelt",  "label": "Toss ore down the mineshaft into the forge (face it, press Q), then drop in to grab the ingots", "goal": "Forge 2 ingots"},
	{"id": &"wood",   "label": "Chop a tree — hold LMB on a trunk to fell it for wood", "goal": "Get wood"},
	{"id": &"bazaar", "label": "Claim the Bazaar — place wood (RMB) in the gap of the ruined frame near spawn", "goal": "Claim the Bazaar"},
	{"id": &"research", "label": "Research AUTOMATION at the Bazaar — press E by the stall, then R (needs an ore sample + 2 ingots)", "goal": "Research Automation"},
	{"id": &"craft",  "label": "Stand by the Bazaar, press E, then the Drill key to craft a Drill", "goal": "Craft a Drill"},
	{"id": &"build",  "label": "Drop the Drill into the shaft just ABOVE the ore vein (RMB) — it bores down into it", "goal": "Build the line"},
	{"id": &"fuel",   "label": "The Drill needs COAL — mine the coal vein right of the shaft, then drop coal on the Drill (Q)", "goal": "Fuel the Drill"},
	{"id": &"auto",   "label": "Stand back — the fueled Drill bores the vein and pours ore into the forge below. First automation!", "goal": "First automation"},
	# --- the gentle L1→L2 handoff: research power → burn coal → research descent → breach the seal. After
	# this the chain ENDS; the player self-directs (tech tree [T], go deeper). Deliberately NOT into L3.
	{"id": &"power",     "label": "Research POWER at the Bazaar (press R) — the deep needs energy", "goal": "Research Power"},
	{"id": &"generator", "label": "Craft a GENERATOR, place it, and toss coal in (Q) to burn it for power", "goal": "Burn coal for power"},
	{"id": &"descent",   "label": "Research the DESCENT ENGINE at the Bazaar — the way down is sealed", "goal": "Research Descent"},
	{"id": &"breach",    "label": "Feed a Descent Engine on the seal to breach into Stonereach — then explore on your own", "goal": "Breach the seal"},
]


func _init(factory: FactorySim) -> void:
	sim = factory
	_base_produced = factory.total_produced.duplicate()
	_base_consumed = factory.total_consumed.duplicate()
	_base_machines = factory.machines.size()
	# Snapshot the intact SEAL (every sealrock cell). A Descent Engine's breach bores a hole straight down
	# through this band (set_solid → open), so "the seal is breached" = any snapshotted cell is no longer
	# sealrock. Reading the material (not a worldgen constant) keeps this decoupled from any one generator.
	for cell: Vector2i in factory.solid.keys():
		if factory.solid[cell] == &"sealrock":
			_seal_cells.append(cell)


## Call every frame: latch any newly-achieved step. Cheap (a handful of dict reads).
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


## The id of the current (first incomplete) step, or &"" when the whole chain is done. Lets the view
## point a world-space highlight at WHERE the current step happens (the controller maps id→cells).
func current_id() -> StringName:
	var i: int = current_index()
	return steps[i]["id"] if i < steps.size() else &""


func is_done(id: StringName) -> bool:
	return _done.has(id)


func all_done() -> bool:
	return _done.size() >= steps.size()


## Seconds since the chain finished (HUD fades the panel out after a beat). -1 until complete.
func done_for() -> float:
	return _all_done_time


# --- predicates (session deltas over the sim's lifetime counters) ---------------------------------

func _achieved(id: StringName) -> bool:
	match id:
		&"mine":   return _produced(&"ore") >= 4
		&"smelt":  return _produced(&"ingot") >= 2 and int(sim.inventory.get(&"ingot", 0)) >= 2  # smelted AND collected
		&"wood":   return _produced(&"wood") >= 1                                                 # felled a tree this session
		&"bazaar": return not sim.find_bazaars().is_empty()                                       # a frame is complete + claimed
		&"research": return sim.is_researched(&"automation")                                      # the bench unlocked the drill
		&"craft":  return int(sim.inventory.get(&"drill", 0)) >= 1 or _has_drill_machine()        # a Drill in pack or placed
		&"build": return not _find_line().is_empty()                                             # the drill→forge stack exists
		&"fuel":  return _drill_fueled()                                                          # the drill has coal to burn
		&"auto":  return _line_has_run()                                                          # the line forged an ingot on its own
		&"power":     return sim.is_researched(&"power")                                          # the power tech unlocked the generator
		&"generator": return _generator_burning()                                                # a placed generator is burning coal → power
		&"descent":   return sim.is_researched(&"descent")                                        # the descent engine is unlocked
		&"breach":    return _seal_breached()                                                     # the seal band has been bored open
	return false


## The SELF-FEEDING LINE, detected anywhere in the world: a DRILL placed above a SOLID ore vein (it bores
## down the column into the ore, which falls toward a forge below). Returns {drill} cell, or {} if none.
## Location-independent — any drill sitting over ore it can still bore counts.
func _find_line() -> Dictionary:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"drill" and sim.drill_column_remaining(m.cell) > 0:
			return {"drill": m.cell}
	return {}


## True once a built line has forged an ingot ON ITS OWN. We snapshot the ingot count the moment a drill is
## first capping an ore body, then latch when production passes it — so it proves the DRILL (not the
## player's hand) drove the smelt, and works whether the poured ingots pile up or get auto-collected (a
## ground pile is transient, production is monotonic).
func _line_has_run() -> bool:
	if _find_line().is_empty():
		return false
	if _ingots_at_line < 0:
		_ingots_at_line = _produced(&"ingot")   # the line just appeared — mark the baseline, not done yet
		return false
	return _produced(&"ingot") > _ingots_at_line


func _has_drill_machine() -> bool:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"drill":
			return true
	return false


## Has a placed Drill been fueled with coal (burning now, or coal waiting in its buffer)? The demand-web
## beat: the drill won't pull ore until you've mined coal and fed it.
func _drill_fueled() -> bool:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"drill" and (m.fuel > 0 or int(m.input_buffer.get(&"coal", 0)) > 0):
			return true
	return false


## Is a placed GENERATOR actually BURNING (fuel loaded → pouring power)? The nudge teaches "burn coal for
## power", so we want it FED, not merely placed — mirrors _drill_fueled's "coal in it" read. The generator
## carries the `power_source` behavior flag (_BEHAVIORS); its behavior tag is &"generator".
func _generator_burning() -> bool:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"generator" and (m.fuel > 0 or int(m.input_buffer.get(&"coal", 0)) > 0):
			return true
	return false


## Has the SEAL been breached? A Descent Engine at quota bores the sealrock band open straight below it
## (set_solid → &""), so any cell that WAS sealrock at world-load but is no longer counts — the same
## "the seal cell went open" read RUNG-2 uses at its breach column, generalized over the whole band.
func _seal_breached() -> bool:
	for cell: Vector2i in _seal_cells:
		if sim.solid.get(cell, &"") != &"sealrock":
			return true
	return false


func _produced(item: StringName) -> int:
	return int(sim.total_produced.get(item, 0)) - int(_base_produced.get(item, 0))


func _consumed(item: StringName) -> int:
	return int(sim.total_consumed.get(item, 0)) - int(_base_consumed.get(item, 0))
