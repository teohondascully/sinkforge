class_name MachineState
extends RefCounted

## Runtime state of one placed machine. Plain data: no Node, no sprite, no scene tree. Holds its
## shared MachineDef (flyweight), its grid cell, and its own buffers. The view reads, never writes.

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
## Splitter only: counter that alternates output between destinations item by item, so an odd count
## splits evenly over time (the remainder carries across ticks).
var route_toggle: int = 0
## Generator only: ticks of burn left from the current fuel. >0 means it pours power this tick; it
## refuels by consuming one coal when this hits 0 (see _run_generator).
var fuel: int = 0
## Consumers only: 0..1 power boost this tick. 0 = unpowered baseline, 1 = fully powered. Set by the
## consumer's runner from the power field; the view draws brownout from it. Default 1.0 = not gated.
var power_factor: float = 1.0
## Units consumed, written by two runners and meaning something different in each. `_run_descent` counts
## refined goods eaten toward the breach quota (DESCENT_QUOTA). `_run_drill` counts ore pulled, which
## `_status_drill` reads to tell a spent Borer from a starved one. Check both before splitting it.
var fed: int = 0
## Directional machines only: which way it works, plus or minus 1. Set once at placement from the
## builder's facing (a discrete call, so determinism holds). 1 when unused.
var facing: int = 1
## Configurable machines only: mode index cycled by the R-configure verb. 0 = default behaviour.
var mode: int = 0
## Drift Rig only: the spoil half of its haul, falling down the column behind the rig while
## `output_buffer` holds the pay half for the column under it. Each jams independently (DRIFT.md §3).
var spoil_buffer: Dictionary = {}
## Hopper only: the one item id banked here. Auto-latches on the first item banked; everything else
## passes through. &"" = not yet latched.
var filter: StringName = &""


func _init(machine_def: MachineDef, machine_cell: Vector2i) -> void:
	def = machine_def
	cell = machine_cell
