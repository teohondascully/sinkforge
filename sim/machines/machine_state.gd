class_name MachineState
extends RefCounted

## Runtime state of one placed machine. Plain data: no Node, no sprite, no scene tree. Holds its
## shared MachineDef (flyweight), its grid cell, and its own buffers. The view reads, never writes.
##
## Lifted in A' step 3 (D0346) from `legacy/src/core/machine_state.gd`, 45 lines, with the two
## determinism rows fixed on the way (plan §5.1 row 010): `progress: float` seconds is
## `progress_ticks: int`, `power_factor: float` 0..1 is `power_permille: int` 0..1000. `spoil_buffer`
## (Drift Rig only, GDD §9 dead) does not come over. The cell is named `logic_cell` -- the 16 px metre
## cell D0020 reserved that name for -- rather than legacy's bare `cell`.

## Shared definition (flyweight). The behaviour/numbers live here.
var def: MachineDef
## Logic (16 px, one-metre) cell this machine occupies (x = column, y = row; row increases downward).
var logic_cell: Vector2i
## StringName item id -> count waiting to be consumed.
var input_buffer: Dictionary = {}
## StringName item id -> count produced, waiting to fall to the machine below.
var output_buffer: Dictionary = {}
## Hub ticks accumulated toward the current craft (legacy: seconds, as a float).
var progress_ticks: int = 0
## Splitter only: counter that alternates output between destinations item by item, so an odd count
## splits evenly over time (the remainder carries across ticks). Stays, whichever way the splitter is
## ruled (plan §8): it is one int and the save carries it.
var route_toggle: int = 0
## Generator only: ticks of burn left from the current fuel. >0 means it pours power this tick; it
## refuels by consuming one coal when this hits 0 (see _run_generator).
var fuel: int = 0
## Consumers only: 0..1000 power boost this tick, per mille. 0 = unpowered baseline, 1000 = fully
## powered. Set by the consumer's runner from the power field; the view draws brownout from it.
## Default 1000 = not gated. (Legacy: `power_factor: float = 1.0`.)
var power_permille: int = 1000
## Units consumed. Legacy had two writers meaning different things; the surviving one is `_run_drill`,
## which counts ore pulled so `_status_drill` can tell a spent drill from a starved one. (The other,
## `_run_descent`, is dead with the Descent Engine.)
var fed: int = 0
## Directional machines only: which way it works, plus or minus 1. Set once at placement from the
## builder's facing (a discrete call, so determinism holds). 1 when unused.
var facing: int = 1
## Configurable machines only: mode index cycled by the configure verb. 0 = default behaviour.
var mode: int = 0
## Hopper only: the one item id banked here. Auto-latches on the first item banked; everything else
## passes through. &"" = not yet latched.
var filter: StringName = &""


func _init(machine_def: MachineDef, machine_logic_cell: Vector2i) -> void:
	def = machine_def
	logic_cell = machine_logic_cell
