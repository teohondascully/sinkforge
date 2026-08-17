class_name MachineState
extends RefCounted

## Runtime state of one placed machine in the simulation. PLAIN DATA — no Node, no sprite,
## no scene-tree presence. Holds a reference to its shared MachineDef (flyweight), its grid
## cell, and its own mutable buffers/progress. The representation layer reads this; never writes.

## Shared definition (flyweight). The behaviour/numbers live here.
var def: MachineDef
## Grid cell this machine occupies (x = column, y = row; row increases downward).
var cell: Vector2i
## StringName item id -> count waiting to be consumed.
var input_buffer: Dictionary = {}
## StringName item id -> count produced, waiting to fall to the machine below.
var output_buffer: Dictionary = {}
## Seconds accumulated toward the current craft.
var progress: float = 0.0
## Splitter-only: a running counter used to alternate output between destinations item-by-item,
## so an odd item count splits evenly over time (carries the remainder across ticks). Unused by
## recipe-runners. Kept here (not a subclass) to honour composition-over-inheritance for now.
var route_toggle: int = 0
## Generator-only: ticks of burn remaining from the current piece of fuel. >0 means the generator is
## pouring power this tick; it refuels by consuming one coal when this hits 0 (see _run_generator).
## Unused by other machines (same composition-over-inheritance stance as route_toggle).
var fuel: int = 0
## Consumer-only (the lift, for now): 0..1 how much POWER boost it's getting this tick — 0 = running on
## its unpowered baseline, 1 = fully powered. Set by the consumer's runner from the power field; the view
## reads it to show the machine labouring vs surging (brownout). 1.0 default = "not power-gated / nominal".
var power_factor: float = 1.0
## Descent-Engine-only: refined goods it has EATEN toward its breach quota (DESCENT_QUOTA). The gate's
## throughput-wall progress. Same composition-over-inheritance stance as route_toggle/fuel.
var fed: int = 0
## Directional machines only (the horizontal drill): which way it works, ±1. Set once at placement
## (the builder's facing — a discrete call, so determinism holds). 1 for machines that don't care.
var facing: int = 1
## Configurable machines only (the splitter's ratio, for now): a small mode index cycled by the
## player's R-configure verb (a discrete call). 0 = the machine's default behaviour.
var mode: int = 0
## Drift-Rig-only: the SPOIL half of its haul, waiting to fall down the column BEHIND the rig while
## `output_buffer` holds the pay half for the column under it. Two bellies rather than one because the rig's
## whole point is that it sorts at the face — one buffer would mean sorting downstream, which is the problem
## it exists to solve. Each jams on its own (docs/DRIFT.md §3). Same composition-over-inheritance stance as
## route_toggle/fuel/fed: a plain field, unused by every other machine.
var spoil_buffer: Dictionary = {}
## Hopper-only: the ONE item id this hopper banks. Auto-latches on the first item it
## banks ("keeps the first thing it tastes"); everything else passes through. &"" = not yet latched.
var filter: StringName = &""


func _init(machine_def: MachineDef, machine_cell: Vector2i) -> void:
	def = machine_def
	cell = machine_cell
