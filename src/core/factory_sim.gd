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
## Wider than the 640px viewport so the world fills the screen horizontally, and taller than one
## screen so descending scrolls (embodied pivot, P2·S1a). The world is no longer a single fixed
## screen of grid.
const GRID_COLS: int = 20
const GRID_ROWS: int = 20

## cell (Vector2i) -> MachineState. Authoritative placement + flow topology.
var grid: Dictionary = {}
## Solid terrain cells (cell -> true). The earth the player stands on and (later) digs through.
## Authoritative world state, like `grid`: placement is blocked in solid cells, and it is mutated
## ONLY by discrete calls (set_solid / mine) — never as a side effect of the real-time avatar
## moving — so the sim stays deterministic and serializable. The avatar lives in the
## representation layer and never enters the tick (see docs/RISKS.md "embodied pivot").
var solid: Dictionary = {}
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


## Is this cell solid earth? (Representation layer reads this for collision; sim mutates it only
## via set_solid / mine.)
func is_solid(cell: Vector2i) -> bool:
	return solid.get(cell, false)


## Seed or clear a terrain cell — used to build the starting world. Discrete edit; in-bounds only.
func set_solid(cell: Vector2i, value: bool) -> void:
	if not in_bounds(cell):
		return
	if value:
		solid[cell] = true
	else:
		solid.erase(cell)


## Player action: dig out a solid earth cell. Returns true if a cell was actually cleared. (P2·S1b
## will hook the ore yield onto this; S1a only needs terrain to exist + be queryable.)
func mine(cell: Vector2i) -> bool:
	if not solid.get(cell, false):
		return false
	solid.erase(cell)
	return true


## Place a machine in a cell. Returns the new MachineState, or null if out of bounds / occupied /
## inside solid earth.
func place_machine(def: MachineDef, cell: Vector2i) -> MachineState:
	if not in_bounds(cell) or grid.has(cell) or solid.get(cell, false):
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
	if machine.def.behavior == &"splitter":
		_run_splitter(machine)
		return
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


## A splitter runs no recipe: it just moves whatever has fallen into it from its input into its
## output (no items created or destroyed), to be divided across two columns by _flow next. This
## gives one tick of pass-through latency, which keeps it deterministic and order-independent.
func _run_splitter(machine: MachineState) -> void:
	for item: StringName in machine.input_buffer:
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + int(machine.input_buffer[item])
	machine.input_buffer.clear()


## Gravity + routing: each machine's output is handed to its destination(s). An ordinary machine
## has ONE destination — straight down its column. A splitter has TWO — straight down, and down
## the column to its right — and divides its output evenly between them (alternating item-by-item
## so odd counts split fairly over time). Items are only moved here, never created or destroyed.
func _flow() -> void:
	for machine: MachineState in machines:
		if machine.output_buffer.is_empty():
			continue
		var dests: Array[Dictionary] = _destinations(machine)
		if dests.size() == 1:
			_deliver(machine, dests[0], machine.output_buffer)
		else:
			# Split: deal each item unit to the next destination round-robin via route_toggle.
			var n: int = dests.size()
			var portions: Array[Dictionary] = []
			for _i: int in n:
				portions.append({})
			for item: StringName in machine.output_buffer:
				for _c: int in int(machine.output_buffer[item]):
					var idx: int = machine.route_toggle % n
					machine.route_toggle += 1
					portions[idx][item] = int(portions[idx].get(item, 0)) + 1
			for i: int in n:
				if not portions[i].is_empty():
					_deliver(machine, dests[i], portions[i])
		machine.output_buffer.clear()


## Move a bundle of items from `machine` into one destination, logging the cosmetic flow event.
func _deliver(machine: MachineState, dest: Dictionary, bundle: Dictionary) -> void:
	var target: Dictionary = dest["target"]
	var to_cell: Vector2i = dest["to_cell"]
	for item: StringName in bundle:
		var count: int = int(bundle[item])
		target[item] = int(target.get(item, 0)) + count
		flow_events.append({"item": item, "from": machine.cell, "to": to_cell, "count": count})


## Where a machine's output goes. Each destination is {to_cell: Vector2i, target: Dictionary}.
## Default: one destination straight down. Splitter: down + the column to the right. A splitter
## hard against the right wall has no second column, so it degrades to a plain pass-through (down
## only) — provisional edge behaviour, see docs/RISKS.md.
func _destinations(machine: MachineState) -> Array[Dictionary]:
	var x: int = machine.cell.x
	var y: int = machine.cell.y
	var down: Dictionary = _column_landing(x, y + 1)
	if machine.def.behavior != &"splitter":
		return [down]
	var right_col: int = x + 1
	if right_col >= GRID_COLS:
		return [down]
	# Diverted items move sideways into the right column at the splitter's row, then fall.
	return [down, _column_landing(right_col, y)]


## The first machine at or below `start_row` in `col`, as a delivery destination; if the column
## is clear to the bottom, the destination is that column's sink.
func _column_landing(col: int, start_row: int) -> Dictionary:
	for row: int in range(start_row, GRID_ROWS):
		var m: MachineState = grid.get(Vector2i(col, row), null)
		if m != null:
			return {"to_cell": m.cell, "target": m.input_buffer}
	return {"to_cell": Vector2i(col, GRID_ROWS), "target": sink}
