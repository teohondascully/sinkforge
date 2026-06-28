class_name FactorySim
extends RefCounted

## THE SOURCE OF TRUTH. A node-free, fixed-tick, deterministic factory simulation. It could
## run headless with no scene tree (and does, in tests/run_tests.gd). The representation layer
## reads FROM this; it never writes to it. All production math lives here and nowhere else.
##
## PROVISIONAL topology: machines are an ordered vertical chain (index 0 = top). A machine's
## output "falls" to the next machine's input, and the bottom machine's output lands in the
## sink. The real 2D grid / lateral routing is deferred (see docs/RISKS.md "Spatial model").

const TICKS_PER_SECOND: int = 20
const SECONDS_PER_TICK: float = 1.0 / float(TICKS_PER_SECOND)

## Placed machines, top (0) to bottom. Output falls toward higher indices.
var machines: Array[MachineState] = []
## Items that have fallen out of the bottom machine. The prototype's running output total.
var sink: Dictionary = {}
## Conservation bookkeeping: every item is created/destroyed ONLY by a recipe. Also useful
## later as throughput metrics (see docs/HARNESS.md gray-area observability).
var total_produced: Dictionary = {}
var total_consumed: Dictionary = {}

var _tick_accumulator: float = 0.0


func add_machine(state: MachineState) -> void:
	machines.append(state)


## Advance by real elapsed time, running only whole fixed ticks (deterministic, framerate-
## independent). The game loop calls this; tests call tick() directly. Fast-forwarding offline
## progress later is just calling this with a large delta.
func advance(delta: float) -> void:
	_tick_accumulator += delta
	while _tick_accumulator >= SECONDS_PER_TICK:
		_tick_accumulator -= SECONDS_PER_TICK
		tick()


## One deterministic logical step: every machine runs, then items fall one stage downward.
func tick() -> void:
	for machine: MachineState in machines:
		_run_machine(machine)
	_flow()


func _run_machine(machine: MachineState) -> void:
	var recipe: RecipeDef = machine.def.recipe
	if recipe == null:
		return
	if not _has_inputs(machine, recipe):
		return
	machine.progress += SECONDS_PER_TICK
	if machine.progress < recipe.time:
		return
	machine.progress -= recipe.time
	for item: StringName in recipe.inputs:
		var n: int = int(recipe.inputs[item])
		var remaining: int = int(machine.input_buffer.get(item, 0)) - n
		if remaining > 0:
			machine.input_buffer[item] = remaining
		else:
			machine.input_buffer.erase(item)  # keep buffers free of dead zero-count keys
		total_consumed[item] = int(total_consumed.get(item, 0)) + n
	for item: StringName in recipe.outputs:
		var n: int = int(recipe.outputs[item])
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + n
		total_produced[item] = int(total_produced.get(item, 0)) + n


func _has_inputs(machine: MachineState, recipe: RecipeDef) -> bool:
	for item: StringName in recipe.inputs:
		if int(machine.input_buffer.get(item, 0)) < int(recipe.inputs[item]):
			return false
	return true


## Gravity: each machine's output falls into the next machine's input; the bottom machine's
## output lands in the sink. Items are only moved here, never created or destroyed.
func _flow() -> void:
	var count: int = machines.size()
	for i: int in count:
		var machine: MachineState = machines[i]
		if machine.output_buffer.is_empty():
			continue
		var target: Dictionary = sink if i == count - 1 else machines[i + 1].input_buffer
		for item: StringName in machine.output_buffer:
			target[item] = int(target.get(item, 0)) + int(machine.output_buffer[item])
		machine.output_buffer.clear()
