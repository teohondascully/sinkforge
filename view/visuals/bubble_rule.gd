class_name BubbleRule
extends RefCounted

## WHICH NEED BUBBLE MAY SHOUT WHILE THE LADDER RUNS (D0498). Every machine with a need floats a gold
## ring on a stem over its roof (`MachinePainter._draw_status`, `StatusLook`), and during the opening the
## screen holds two or three of them at once: the crew's rig two metres right of the spawn asks for ingots
## from the first frame, the shaft's forge asks for ore, while the one WHITE reticle is on the ore vein or
## the surface forge. D0449 made the target ring white and gave it compass ticks for exactly this reason --
## strangers 25 and 26 pressed a forge's bubble reading "RINGED", and in batch 70-75 one fed the rig during
## the smelt rung. Ink and form separated the two shapes; they did not stop the gold ones competing for the
## eye. So while a rung is open, a bubble on a machine the rung is not pointing at stands DOWN: the stem,
## the disc and the ring at STAND_DOWN of their alpha and no item inside. The ringed machine's bubble is
## untouched, and once the ladder is finished (or there is no ladder at all) every bubble is full as before.
##
## THE MACHINE'S METRE IS ITS LOGIC CELL. The ring's target is a world position; a machine is the ringed
## one when that position lies in its metre rect, and since `TargetGuide` returns a machine's target as the
## centre of `rec["cell"]`, the containment test floors to a cell comparison.
##
## A RUNG THAT RINGS ROCK STANDS EVERY BUBBLE DOWN, which is the case the evidence is about: the mine rung
## rings a vein, no machine is the target, and the rig's bubble is the loudest thing on screen. Read this
## way rather than "leave them full when the rung's target is not a machine", because that reading leaves
## the reported defect exactly where it was found.

## The alpha a bubble wears when the rung is not pointing at it. Not zero: the machine still HAS a need and
## the player will come back to it; this is a voice dropped, not a fact withheld.
const STAND_DOWN: float = 0.30
const FULL: float = 1.0

## No machine is ringed. Far outside any world's logic cells, as `TargetGuide`'s own miss sentinel is.
const NO_METRE := Vector2i(-1000000, -1000000)

var _key: Array = []
var _metre: Vector2i = NO_METRE


## Is a rung open? A null ladder (a debug stack, a suite's bare painter) and a finished one are the same
## answer: nothing is competing, so nothing stands down.
static func running(obj: Objectives) -> bool:
	return obj != null and not obj.all_done() and obj.current_id() != &""


## The alpha for one machine's bubble this frame.
static func alpha(obj: Objectives, is_ringed: bool) -> float:
	return FULL if is_ringed or not running(obj) else STAND_DOWN


## Does this record raise a bubble at all? The same gate `_draw_status` applies: a status with no fix to
## do, and the spent vein, float nothing.
static func wants_bubble(rec: Dictionary) -> bool:
	var status: StringName = StringName(rec.get("status", &"idle"))
	return StringName(StatusLook.of(status)["fix"]) != &"none" and status != &"spent"


static func any_need(o: Interface.Observation) -> bool:
	for rec: Dictionary in o.machines:
		if wants_bubble(rec):
			return true
	return false


## The logic cell the current rung's ring stands on, or NO_METRE. A rung whose target is a terrain cell
## (`cell_predicate` answers it) is answered without searching: rock is never a machine, and the search is
## the expensive one (D0414, D0431). `TargetGuide.target` is the guide's own full, pure search -- the
## painter must ring what the guide rings, so it asks the guide rather than restating its rules.
static func ringed_metre(obj: Objectives, o: Interface.Observation) -> Vector2i:
	if not running(obj) or o == null:
		return NO_METRE
	var id: StringName = obj.current_id()
	if TargetGuide.cell_predicate(id, o).is_valid():
		return NO_METRE
	var at: Vector2 = TargetGuide.target(id, o)
	if at == TargetGuide.NONE:
		return NO_METRE
	var m: float = float(Interface.Units.LOGIC_PX)
	return Vector2i(floori(at.x / m), floori(at.y / m))


## The same answer, paid once per (rung, body cell, terrain version, pile and machine count) -- the guide's
## own cache key, and the only inputs the answer can move on -- and not paid at all on a frame where no
## machine is asking for anything. The guide already pays this search; the painter must not double it every
## frame as well.
func ringed(obj: Objectives, o: Interface.Observation) -> Vector2i:
	if not running(obj) or o == null or not any_need(o):
		return NO_METRE
	var key: Array = [obj.current_id(), o.cell, o.terrain_version, o.piles.size(), o.machines.size()]
	if key == _key:
		return _metre
	_key = key
	_metre = ringed_metre(obj, o)
	return _metre
