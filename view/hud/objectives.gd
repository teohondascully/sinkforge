class_name Objectives
extends RefCounted

## THE GUIDED STEP LADDER (A' step 6h (ii), D0370): an ordered chain that walks a new player from bare
## hands to their first automation, then to the winch. Legacy `scenes/objectives.gd`'s MECHANISM lifts
## whole -- an ordered chain with a stable id, an imperative label and a goal chip per step; completions
## LATCH so a transient state counts once seen and a step never un-completes; progress is measured as
## deltas against a baseline so a pre-stocked pack cannot tick a step. Every content row is re-authored:
## legacy's taught the Bazaar, research, crafting and the Descent Engine, none of which exists here.
##
## Representation only, off the OBSERVATION. Legacy read the sim's lifetime counters; here "gained"
## is the pack's rises between observations (the payout's rule, D0365), latched into a counter that a
## later spend cannot lower, and "the line has run" is the economy's own rate list (D0351) rather than
## a ground pile, which is transient. The verbs named in the labels are the ones this build has
## (`view/controls.gd`); a key that is not bound is named as a verb, not invented.

## Seconds a finished ladder lingers before the HUD clears the screen for veterans.
const LINGER_DONE: float = 5.0

## The ladder. Order is the tutorial path: each step must be doable from where the previous leaves you.
const STEPS: Array[Dictionary] = [
	{"id": &"mine", "label": "Dig ore — hold MINE on the metal-flecked rock by spawn", "goal": "Mine 4 ore"},
	{"id": &"smelt", "label": "Drop ore into the forge below spawn, then collect the ingots it makes", "goal": "Forge 2 ingots"},
	{"id": &"wood", "label": "Fell a tree — hold MINE on a trunk for wood", "goal": "Get wood"},
	{"id": &"build", "label": "Set the Drill down in the shaft just ABOVE the ore vein — it bores down into it", "goal": "Build the line"},
	{"id": &"fuel", "label": "The Drill burns COAL — dig the coal seam by the shaft, then drop coal on the Drill", "goal": "Fuel the Drill"},
	{"id": &"auto", "label": "Stand back — the fuelled Drill bores the vein and pours ore into the forge. First automation!", "goal": "First automation"},
	{"id": &"hopper", "label": "Coal by hand runs dry — set a HOPPER above the Drill and drop coal in its top", "goal": "Automate the coal feed"},
	{"id": &"power", "label": "Set a GENERATOR down and drop coal on it — the deep needs power", "goal": "Burn coal for power"},
	{"id": &"winch", "label": "Stand a WINCH HEAD on a lode and link it to a Station — the vein climbs on its own", "goal": "Raise the winch"},
]

const INGOTS: Array[StringName] = [&"ingot", &"iron_ingot"]

var _done: Dictionary = {}              ## step id -> true once achieved (latched)
var _gained: Dictionary = {}            ## item -> units the pack has RISEN by this run (never lowered)
var _prev_pack: Dictionary = {}
var _primed: bool = false
var _drill_seen: bool = false           ## the line existed at some point, so a rate after it counts
var _all_done_time: float = -1.0
var _shown_index: int = -1
var step_age: float = 0.0               ## seconds the current step has been current


## Call every frame: bank the pack's rises, latch any newly achieved step, run the clocks.
func refresh(o: Interface.Observation, delta: float) -> void:
	if o == null:
		return
	var now: Dictionary = Payouts.pack_counts(o)
	if _primed:
		for g: Dictionary in Payouts.gains_between(_prev_pack, now):
			_gained[g["item"]] = int(_gained.get(g["item"], 0)) + int(g["count"])
	_prev_pack = now
	_primed = true
	if _has_machine(o, &"drill"):
		_drill_seen = true
	for step: Dictionary in STEPS:
		var id: StringName = step["id"]
		if not _done.has(id) and _achieved(id, o):
			_done[id] = true
	var i: int = current_index()
	if i != _shown_index:
		_shown_index = i
		step_age = 0.0
	else:
		step_age += delta
	if all_done():
		_all_done_time = (_all_done_time if _all_done_time >= 0.0 else 0.0) + delta


func current_index() -> int:
	for i: int in STEPS.size():
		if not _done.has(STEPS[i]["id"]):
			return i
	return STEPS.size()


func current_id() -> StringName:
	var i: int = current_index()
	return STEPS[i]["id"] if i < STEPS.size() else &""


func is_done(id: StringName) -> bool:
	return _done.has(id)


func all_done() -> bool:
	return _done.size() >= STEPS.size()


## Seconds since the chain finished; -1 until complete.
func done_for() -> float:
	return _all_done_time


func gained(item: StringName) -> int:
	return int(_gained.get(item, 0))


func _gained_any(items: Array[StringName]) -> int:
	var n: int = 0
	for it: StringName in items:
		n += gained(it)
	return n


# --- predicates, every one a read of the observation ----------------------------------------------

func _achieved(id: StringName, o: Interface.Observation) -> bool:
	match id:
		&"mine": return gained(&"ore") >= 4
		&"smelt": return _gained_any(INGOTS) >= 2
		&"wood": return gained(&"wood") >= 1
		&"build": return _has_machine(o, &"drill")
		&"fuel": return _fuelled(o, &"drill")
		&"auto": return _drill_seen and _rate_of_any(o, INGOTS) > 0
		&"hopper": return _coal_hopper_above_drill(o)
		&"power": return _fuelled(o, &"generator")
		&"winch": return _working(o, &"winch_head")
	return false


static func _has_machine(o: Interface.Observation, behavior: StringName) -> bool:
	for rec: Dictionary in o.machines:
		if rec.get("behavior", &"") == behavior:
			return true
	return false


## A placed machine of `behavior` with coal to burn: burning now or with coal waiting in its buffer.
static func _fuelled(o: Interface.Observation, behavior: StringName) -> bool:
	for rec: Dictionary in o.machines:
		if rec.get("behavior", &"") == behavior and (int(rec.get("fuel", 0)) > 0 or int((rec.get("input", {}) as Dictionary).get(&"coal", 0)) > 0):
			return true
	return false


static func _working(o: Interface.Observation, behavior: StringName) -> bool:
	for rec: Dictionary in o.machines:
		if rec.get("behavior", &"") == behavior and rec.get("status", &"") == &"working":
			return true
	return false


## A Hopper banking coal directly above a Drill: the one mechanism the game has for routing fuel. Reads
## the FILTER rather than the buffer, since a hopper can hold zero coal for a beat between deliveries and
## still be the thing doing the routing.
static func _coal_hopper_above_drill(o: Interface.Observation) -> bool:
	for rec: Dictionary in o.machines:
		if rec.get("behavior", &"") == &"hopper" and rec.get("filter", &"") == &"coal":
			var below: Dictionary = o.machine_at(Vector2i(rec["cell"]) + Vector2i(0, 1))
			if below.get("behavior", &"") == &"drill":
				return true
	return false


static func _rate_of_any(o: Interface.Observation, items: Array[StringName]) -> int:
	var n: int = 0
	for r: Dictionary in o.rates:
		if items.has(r.get("item", &"")):
			n += int(r.get("rate_centi", 0))
	return n
