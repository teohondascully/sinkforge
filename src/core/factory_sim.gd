class_name FactorySim
extends RefCounted

## THE SOURCE OF TRUTH. A node-free, fixed-tick, deterministic factory simulation. It could
## run headless with no scene tree (and does, in tests/run_tests.gd). The representation layer
## reads FROM this; it never writes to it. All production math lives here and nowhere else.
##
## TOPOLOGY: machines occupy cells on a grid (x = column, y = row, row increasing DOWNWARD).
## Gravity = a machine's output falls straight down its column to the next machine below; if
## none, it lands in the sink. The grid size and the "straight-down only" rule are PROVISIONAL
## (chutes / splitters / lateral routing are later slices — see docs/RISKS.md "Spatial model").

const TICKS_PER_SECOND: int = 20
const SECONDS_PER_TICK: float = 1.0 / float(TICKS_PER_SECOND)
const GRID_COLS: int = 14
const GRID_ROWS: int = 9

## cell (Vector2i) -> MachineState. Authoritative placement + flow topology.
var grid: Dictionary = {}
## Placed machines in insertion order, for deterministic iteration.
var machines: Array[MachineState] = []
## Items that have fallen out the bottom of a column. The prototype's running output total.
var sink: Dictionary = {}
## Conservation bookkeeping: every item is created/destroyed ONLY by a recipe (holds while no
## machine is removed mid-run; removing a machine intentionally discards its buffered items).
var total_produced: Dictionary = {}
var total_consumed: Dictionary = {}
## Cosmetic output channel: item movements logged during _flow, for the view to animate as
## falling sprites. The sim NEVER reads this back — clearing it changes no production. The
## representation layer drains it each frame. Each entry: {item, from: Vector2i, to: Vector2i, count}.
var flow_events: Array[Dictionary] = []

var _tick_accumulator: float = 0.0


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS


func machine_at(cell: Vector2i) -> MachineState:
	return grid.get(cell, null)


## Place a machine in a cell. Returns the new MachineState, or null if out of bounds / occupied.
func place_machine(def: MachineDef, cell: Vector2i) -> MachineState:
	if not in_bounds(cell) or grid.has(cell):
		return null
	var state: MachineState = MachineState.new(def, cell)
	grid[cell] = state
	machines.append(state)
	return state


## Remove the machine at a cell (if any). Its buffered items are discarded.
func remove_machine(cell: Vector2i) -> void:
	var state: MachineState = grid.get(cell, null)
	if state == null:
		return
	grid.erase(cell)
	machines.erase(state)


## Advance by real elapsed time, running only whole fixed ticks (deterministic, framerate-
## independent). The game loop calls this; tests call tick() directly.
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


## Gravity: each machine's output falls straight down its column to the next machine below;
## if none, it lands in the sink. Items are only moved here, never created or destroyed.
func _flow() -> void:
	for machine: MachineState in machines:
		if machine.output_buffer.is_empty():
			continue
		var below: MachineState = _machine_below(machine)
		var to_cell: Vector2i
		var target: Dictionary
		if below != null:
			to_cell = below.cell
			target = below.input_buffer
		else:
			to_cell = Vector2i(machine.cell.x, GRID_ROWS)  # falls past the bottom into the sink
			target = sink
		for item: StringName in machine.output_buffer:
			var count: int = int(machine.output_buffer[item])
			target[item] = int(target.get(item, 0)) + count
			flow_events.append({"item": item, "from": machine.cell, "to": to_cell, "count": count})
		machine.output_buffer.clear()


## The next machine straight down this one's column, or null if the column is clear to the bottom.
func _machine_below(machine: MachineState) -> MachineState:
	var col: int = machine.cell.x
	for row: int in range(machine.cell.y + 1, GRID_ROWS):
		var below: MachineState = grid.get(Vector2i(col, row), null)
		if below != null:
			return below
	return null
