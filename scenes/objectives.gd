class_name Objectives
extends RefCounted

## REPRESENTATION-LAYER legibility (NOT sim): an ordered tutorial chain that walks a new player through
## the whole loop dig→feed→forge→craft→build→automate — the direct answer to "how do I actually play?"
## (the VIBE_GAP #8 indictment). It READS the sim only (never mutates, never enters the tick), so deleting
## it changes no production number.
##
## It measures SESSION DELTAS from a baseline snapshot taken at construction (lifetime counters minus
## their start value), so it still guides correctly even when the dev-start kit pre-stocks the pack — you
## must actually mine/feed/craft THIS session for a step to tick. Completions LATCH: a transient state
## (ore sitting in a buffer, a pile on the ground) still counts once seen, so steps never un-complete.

var sim: FactorySim
var _base_produced: Dictionary = {}
var _base_consumed: Dictionary = {}
var _base_machines: int = 0
var _base_bazaars: int = 0
var _done: Dictionary = {}              ## step id -> true once achieved (latched)
var _all_done_time: float = -1.0        ## seconds the chain has been fully complete (for HUD auto-hide)

## The chain. Each step: stable id, an imperative label (what to DO), and a short goal tag (the win
## condition, shown as the chip). Order IS the tutorial path. Predicates live in `_achieved`.
var steps: Array[Dictionary] = [
	{"id": &"mine",  "label": "Dig an ore vein — hold LMB on orange-flecked rock", "goal": "Mine 3 ore"},
	{"id": &"feed",  "label": "Stand over the forge and press Q to drop ore in",   "goal": "Feed the forge"},
	{"id": &"forge", "label": "Let the forge smelt your ore into an ingot",        "goal": "Forge 1 ingot"},
	{"id": &"craft", "label": "Press E for the crafting screen, then 1 for a Processor", "goal": "Craft a machine"},
	{"id": &"build", "label": "Place it with RMB on open ground below",            "goal": "Build a machine"},
	{"id": &"auto",  "label": "Watch product fall & pile up — walk over to grab it", "goal": "Automate"},
	{"id": &"bazaar", "label": "Finish the abandoned Bazaar near spawn — select wood, RMB the gap in its frame", "goal": "Raise the Bazaar"},
]


func _init(factory: FactorySim) -> void:
	sim = factory
	_base_produced = factory.total_produced.duplicate()
	_base_consumed = factory.total_consumed.duplicate()
	_base_machines = factory.machines.size()
	_base_bazaars = factory.find_bazaars().size()


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
		&"mine":  return _produced(&"ore") >= 3
		&"feed":  return _any_input() or _consumed(&"ore") >= 1   # fed OR already smelting
		&"forge": return _produced(&"ingot") >= 1
		&"craft": return _consumed(&"ingot") >= 1                 # only crafting spends ingots
		&"build": return sim.machines.size() - _base_machines >= 1
		&"auto":  return not sim.ground.is_empty()                # gravity dropped product into a pile
		&"bazaar": return sim.find_bazaars().size() > _base_bazaars  # completed a wood frame this session
	return false


func _produced(item: StringName) -> int:
	return int(sim.total_produced.get(item, 0)) - int(_base_produced.get(item, 0))


func _consumed(item: StringName) -> int:
	return int(sim.total_consumed.get(item, 0)) - int(_base_consumed.get(item, 0))


func _any_input() -> bool:
	for m: MachineState in sim.machines:
		if not m.input_buffer.is_empty():
			return true
	return false
