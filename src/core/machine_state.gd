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


func _init(machine_def: MachineDef, machine_cell: Vector2i) -> void:
	def = machine_def
	cell = machine_cell
