class_name Objectives
extends RefCounted

## REPRESENTATION-LAYER legibility (NOT sim): an ordered, guided RUNG-1 ladder that walks a new player
## all the way to their FIRST AUTOMATION — the self-feeding ore→ingot line. It is the direct answer to
## "what do I do?" / "how do I get to L2?": there is ALWAYS a signposted next action, and the chain only
## completes when the player has built a drill→forge stack that mines and smelts on its own (docs/PROGRESSION.md).
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
var _ingots_at_line: int = -1           ## ingots produced the moment the drill→forge line was assembled

## The Rung-1 ladder. Each step: stable id, an imperative label (what to DO), and a short goal tag (the
## win condition, shown as the chip). Order IS the tutorial path — each step is doable from the state the
## previous one leaves you in. Predicates live in `_achieved`.
var steps: Array[Dictionary] = [
	{"id": &"mine",  "label": "Dig ore — hold LMB on the orange-flecked rock by spawn", "goal": "Mine 4 ore"},
	{"id": &"smelt", "label": "Toss ore down the mineshaft into the forge (face it, press Q), then drop in to grab the ingots", "goal": "Forge 2 ingots"},
	{"id": &"craft", "label": "Press E, then the Drill key, to craft a Drill", "goal": "Craft a Drill"},
	{"id": &"build", "label": "Cap the forge with the Drill — place it (RMB) directly on top", "goal": "Build the line"},
	{"id": &"auto",  "label": "Stand back — the Drill now feeds the forge for you. First automation!", "goal": "First automation"},
]


func _init(factory: FactorySim) -> void:
	sim = factory
	_base_produced = factory.total_produced.duplicate()
	_base_consumed = factory.total_consumed.duplicate()
	_base_machines = factory.machines.size()


## Call every frame: latch any newly-achieved step. Cheap (a handful of dict reads).
func refresh(delta: float) -> void:
	for step: Dictionary in steps:
		var id: StringName = step["id"]
		if not _done.has(id) and _achieved(id):
			_done[id] = true
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
		&"mine":  return _produced(&"ore") >= 4
		&"smelt": return _produced(&"ingot") >= 2 and int(sim.inventory.get(&"ingot", 0)) >= 2  # smelted AND collected
		&"craft": return int(sim.inventory.get(&"drill", 0)) >= 1 or _has_drill_machine()        # a Drill in pack or placed
		&"build": return not _find_line().is_empty()                                             # the drill→forge stack exists
		&"auto":  return _line_has_run()                                                          # the line forged an ingot on its own
	return false


## The SELF-FEEDING LINE, detected anywhere in the world: a drill with a processor directly below it (so
## the drill's bored ore falls straight into the forge). Returns {drill, proc} cells, or {} if none. This
## is location-independent — building the stack in the mineshaft OR anywhere else counts.
func _find_line() -> Dictionary:
	for m: MachineState in sim.machines:
		if m.def.behavior == &"drill":
			var below: Vector2i = m.cell + Vector2i(0, 1)
			var p: MachineState = sim.machine_at(below)
			if p != null and p.def.id == &"processor":
				return {"drill": m.cell, "proc": p.cell}
	return {}


## True once a built line has forged an ingot ON ITS OWN. We snapshot the ingot count the moment the
## drill→forge stack first exists, then latch when production passes it — so it proves the DRILL (not the
## player's hand) fed the forge, and works whether the poured ingots pile up or get auto-collected by a
## body standing in the shaft (a ground pile is transient, production is monotonic).
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


func _produced(item: StringName) -> int:
	return int(sim.total_produced.get(item, 0)) - int(_base_produced.get(item, 0))


func _consumed(item: StringName) -> int:
	return int(sim.total_consumed.get(item, 0)) - int(_base_consumed.get(item, 0))
