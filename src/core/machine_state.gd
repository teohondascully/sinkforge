class_name MachineState
extends RefCounted

## Runtime state of one placed machine in the simulation. PLAIN DATA — no Node, no sprite,
## no scene-tree presence. Holds a reference to its shared MachineDef (flyweight) plus its
## own mutable buffers and craft progress. The representation layer will later read this; it
## never writes to it.

## Shared definition (flyweight). The behaviour/numbers live here.
var def: MachineDef
## StringName item id -> count waiting to be consumed.
var input_buffer: Dictionary = {}
## StringName item id -> count produced, waiting to fall to the next machine.
var output_buffer: Dictionary = {}
## Seconds accumulated toward the current craft.
var progress: float = 0.0


func _init(machine_def: MachineDef) -> void:
	def = machine_def
