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
## A larger world so a zoomed-out (3×) camera has real terrain to show and scroll through — hills,
## depth, room to explore (presentation sprint). Provisional size; real worldgen is still deferred.
const GRID_COLS: int = 72
const GRID_ROWS: int = 40
## Items/tick a LIFT carries UP its column — the throughput "cost" of fighting gravity (real power is
## deferred; slowness IS the asymmetry for now). Below this rate, a backlog piles at the lift.
const LIFT_THROUGHPUT: int = 2

## cell (Vector2i) -> MachineState. Authoritative placement + flow topology.
var grid: Dictionary = {}
## Solid terrain cells (cell -> material StringName, e.g. &"earth" / &"ore"). The ground the
## player stands on and digs through. Authoritative world state, like `grid`: placement is blocked
## in solid cells, and it is mutated ONLY by discrete calls (set_solid / mine) — never as a side
## effect of the real-time avatar moving — so the sim stays deterministic and serializable. The
## avatar lives in the representation layer and never enters the tick (docs/RISKS.md "embodied").
var solid: Dictionary = {}
## Background WALL layer (cell -> material id): what sits BEHIND a cell, independent of whether the
## cell is solid. Mining a block leaves its wall (Terraria-style). Read-only to the view (wall_at);
## written only by load_world / set_wall. Not collision (you walk through walls), not "items present".
var wall: Dictionary = {}
## What the player is carrying (item StringName -> count). Session state owned by the sim (so it is
## deterministic + serializable); the avatar only triggers discrete mine/deposit calls. Counted as
## "items present" for conservation. Rendered as the inventory hotbar (see `inventory_slots`).
var inventory: Dictionary = {}
## How many distinct stacks the carried pack shows as hotbar slots. The pack is intentionally small
## (GDD: a limited pack forces hauling trips). No hard capacity is ENFORCED yet — that's a feel/
## economy knob to turn when trip-friction is the thing being tuned (with the build economy).
const INVENTORY_SLOTS: int = 8
## Placed machines in insertion order, for deterministic iteration.
var machines: Array[MachineState] = []
## Physical product piles resting on the dug floor: cell (Vector2i) -> {item -> count}. A machine
## SPITS its output downward; gravity carries it down the column and it lands on top of the first
## solid cell (or cascades into a machine below). The player walks over a pile to scoop it into the
## pack — the embodied collect half of the loop. Authoritative sim state (mutated only in _flow and
## by collect_ground), counted as "items present" for conservation.
var ground: Dictionary = {}
## Items that fell off the bottom of the world (a column dug clear through, no floor). A void sink
## kept only so conservation accounting never silently loses an item.
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


## Is this cell solid (any material)? (Representation reads this for collision; sim mutates it only
## via set_solid / mine.)
func is_solid(cell: Vector2i) -> bool:
	return solid.has(cell)


## The material in a cell (&"earth" / &"ore"), or &"" if open. Lets the view tint veins.
func material_at(cell: Vector2i) -> StringName:
	return solid.get(cell, &"")


## Seed or clear a terrain cell — used to build the starting world. Discrete edit; in-bounds only.
## Pass &"" to clear, otherwise the material (&"earth" default).
func set_solid(cell: Vector2i, material: StringName = &"earth") -> void:
	if not in_bounds(cell):
		return
	if material == &"":
		solid.erase(cell)
	else:
		solid[cell] = material


## The background wall material in a cell (e.g. &"stone_wall"), or &"" if none. View reads this to
## draw the carved-room backing behind dug-out cells.
func wall_at(cell: Vector2i) -> StringName:
	return wall.get(cell, &"")


## Set or clear a background wall cell (in-bounds; &"" clears). Discrete edit like set_solid.
func set_wall(cell: Vector2i, material: StringName = &"") -> void:
	if not in_bounds(cell):
		return
	if material == &"":
		wall.erase(cell)
	else:
		wall[cell] = material


## Ingest a generated world (the gen→sim handshake): replace terrain with the WorldData's two grids.
## Only cells in bounds are taken. The avatar/machines are unaffected; this is the start-of-world
## seeding step that replaces the old hand-coded _seed_world terrain loop.
func load_world(world: WorldData) -> void:
	solid.clear()
	wall.clear()
	for cell: Vector2i in world.blocks:
		if in_bounds(cell):
			solid[cell] = world.blocks[cell]
	for cell: Vector2i in world.walls:
		if in_bounds(cell):
			wall[cell] = world.walls[cell]


## Player action: dig out a solid cell. Returns the material mined (&"earth"/&"ore"), or &"" if the
## cell was already open. Mining an ORE vein yields one ore into the player's pack — and that ore is
## genuinely produced from the world, so it counts toward total_produced (conservation stays true).
## The cell's background WALL is left intact (you carve the block, the wall stays behind).
func mine(cell: Vector2i) -> StringName:
	if not solid.has(cell):
		return &""
	var material: StringName = solid[cell]
	solid.erase(cell)
	if material == &"ore":
		inventory[&"ore"] = int(inventory.get(&"ore", 0)) + 1
		total_produced[&"ore"] = int(total_produced.get(&"ore", 0)) + 1
	return material


## The carried pack as an ordered list of {item, count} for the inventory hotbar UI. Dictionaries
## preserve insertion order, so the slot layout is stable as items are picked up. Pure read over
## `inventory` — no behaviour or determinism change.
func inventory_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for item: StringName in inventory:
		slots.append({"item": item, "count": int(inventory[item])})
	return slots


## Player action: hand items from the pack into the machine at `cell` (its input buffer). Returns
## the number actually deposited (capped by what's carried). The avatar triggers this when standing
## in reach of a machine — the manual half of the manual→automated arc.
func deposit(cell: Vector2i, item: StringName, count: int) -> int:
	var machine: MachineState = grid.get(cell, null)
	if machine == null or count <= 0:
		return 0
	var have: int = int(inventory.get(item, 0))
	var moved: int = mini(have, count)
	if moved <= 0:
		return 0
	machine.input_buffer[item] = int(machine.input_buffer.get(item, 0)) + moved
	var left: int = have - moved
	if left > 0:
		inventory[item] = left
	else:
		inventory.erase(item)
	return moved


## Player action: CRAFT one machine item into the pack, spending its `craft_cost` from inventory.
## Returns true if crafted. Spent items are counted as consumed so conservation holds (crafting is
## a real ingot sink). The machine item (keyed by def.id) lives in the same pack as ore/ingots.
func craft(def: MachineDef) -> bool:
	if def.craft_cost.is_empty():
		return false
	for item: StringName in def.craft_cost:
		if int(inventory.get(item, 0)) < int(def.craft_cost[item]):
			return false
	for item: StringName in def.craft_cost:
		var n: int = int(def.craft_cost[item])
		_take_from_pack(item, n)
		total_consumed[item] = int(total_consumed.get(item, 0)) + n
	inventory[def.id] = int(inventory.get(def.id, 0)) + 1
	return true


## Player action: place a machine you CARRY — consumes one machine item (def.id) from the pack and
## places it. Returns the MachineState, or null if you don't carry one or the cell is blocked.
func build_from_pack(def: MachineDef, cell: Vector2i) -> MachineState:
	if int(inventory.get(def.id, 0)) <= 0:
		return null
	var state: MachineState = place_machine(def, cell)
	if state == null:
		return null
	_take_from_pack(def.id, 1)
	return state


## Player action: pick a placed machine back up into the pack (one machine item by its def.id).
## Returns true if a machine was there. Any items the machine was holding are SALVAGED back into the
## pack rather than discarded — so picking up a mid-work forge never silently destroys your ore
## (items just move machine→pack, both "present" → conservation holds).
func pickup_machine(cell: Vector2i) -> bool:
	var state: MachineState = grid.get(cell, null)
	if state == null:
		return false
	for buffer: Dictionary in [state.input_buffer, state.output_buffer]:
		for item: StringName in buffer:
			inventory[item] = int(inventory.get(item, 0)) + int(buffer[item])
	inventory[state.def.id] = int(inventory.get(state.def.id, 0)) + 1
	remove_machine(cell)
	return true


func _take_from_pack(item: StringName, n: int) -> void:
	var left: int = int(inventory.get(item, 0)) - n
	if left > 0:
		inventory[item] = left
	else:
		inventory.erase(item)


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
	if machine.def.behavior == &"lift":
		_run_lift(machine)
		return
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


## A LIFT runs no recipe: it carries items UP its column — the paid inverse of gravity. Each tick it
## moves up to LIFT_THROUGHPUT items from its input into its output (delivered upward by _flow next);
## the rest stays as a backlog (the throughput "cost"). No items created or destroyed → conservation
## holds. Whatever falls onto a lift (gravity brings product down to it) is hauled back up.
func _run_lift(machine: MachineState) -> void:
	var moved: int = 0
	for item: StringName in machine.input_buffer.keys():
		if moved >= LIFT_THROUGHPUT:
			break
		var take: int = mini(int(machine.input_buffer[item]), LIFT_THROUGHPUT - moved)
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + take
		var left: int = int(machine.input_buffer[item]) - take
		if left > 0:
			machine.input_buffer[item] = left
		else:
			machine.input_buffer.erase(item)
		moved += take


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
	if machine.def.behavior == &"lift":
		return [_column_rise(x, y - 1)]  # the inverse of gravity: this machine's output goes UP
	var down: Dictionary = _column_landing(x, y + 1)
	if machine.def.behavior != &"splitter":
		return [down]
	var right_col: int = x + 1
	if right_col >= GRID_COLS:
		return [down]
	# Diverted items move sideways into the right column at the splitter's row, then fall.
	return [down, _column_landing(right_col, y)]


## Where a spat product lands, scanning down `col` from `start_row`: the first machine below catches
## it (cascade), else it rests on top of the first solid floor as a physical ground pile. A column
## dug clear to the bottom drops it into the void sink (conservation-only).
func _column_landing(col: int, start_row: int) -> Dictionary:
	for row: int in range(start_row, GRID_ROWS):
		var m: MachineState = grid.get(Vector2i(col, row), null)
		if m != null:
			return {"to_cell": m.cell, "target": m.input_buffer}
		if solid.has(Vector2i(col, row)):
			var rest := Vector2i(col, row - 1)  # the open cell on top of the floor
			return {"to_cell": rest, "target": _ground_pile(rest)}
	return {"to_cell": Vector2i(col, GRID_ROWS), "target": sink}


## Where a LIFTED item goes, scanning UP `col` from `start_row` (the mirror of _column_landing): the
## first machine above catches it (feed a higher machine), else it rests against the first ceiling
## (a pile just below the solid cell), else — an open shaft to the top — it rests at the top row.
func _column_rise(col: int, start_row: int) -> Dictionary:
	for row: int in range(start_row, -1, -1):
		var m: MachineState = grid.get(Vector2i(col, row), null)
		if m != null:
			return {"to_cell": m.cell, "target": m.input_buffer}
		if solid.has(Vector2i(col, row)):
			var rest := Vector2i(col, row + 1)  # the open cell just below the ceiling
			return {"to_cell": rest, "target": _ground_pile(rest)}
	return {"to_cell": Vector2i(col, 0), "target": _ground_pile(Vector2i(col, 0))}


## The product pile resting in `cell`, created on first landing. Returned as a live Dictionary so
## _deliver adds straight into it.
func _ground_pile(cell: Vector2i) -> Dictionary:
	if not ground.has(cell):
		ground[cell] = {}
	return ground[cell]


## Player action: walk over a resting pile and scoop it all into the pack. Returns how many items
## were collected. The embodied collect half of spit-out → fall → collect (no abstract counter).
func collect_ground(cell: Vector2i) -> int:
	var pile: Dictionary = ground.get(cell, {})
	if pile.is_empty():
		return 0
	var collected: int = 0
	for item: StringName in pile:
		inventory[item] = int(inventory.get(item, 0)) + int(pile[item])
		collected += int(pile[item])
	ground.erase(cell)
	return collected
