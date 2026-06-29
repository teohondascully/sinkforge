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
## How many cells straight DOWN a Drill reaches for ore (docs/MINING.md). It bores the first ore cell
## within this range, stopping at any non-ore rock — so you place it with a clear shot at the vein.
const DRILL_REACH: int = 4
## --- POWER (the L2 twist, docs/POWER.md): power FALLS on the hook. A fueled GENERATOR burns coal and
## pours power into the cells around it (its innate aura — conduits will extend the reach down+lateral
## in a later slice); consumers draw from the field to run. The field is a DERIVED quantity recomputed
## every tick from machine placement + fuel — never stored authoritative state, exactly like updraft_at —
## so determinism is untouched and it can never desync.
const GENERATOR_POWER: float = 6.0      ## power units a fueled generator emits at its source
const GENERATOR_FUEL_TICKS: int = 100   ## ticks one coal burns (5s @20Hz) before the generator refuels
const POWER_AURA: int = 2               ## innate radius (cells) a generator powers WITHOUT any conduit

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
## Ore deposit pools (cell -> remaining yield), the finite-deposit layer over ore cells (docs/MINING.md).
## An ORE cell ABSENT here counts as amount 1, so a world that never set richness behaves as before
## (one hit = one ore = cleared). Drained by hand-`mine` and by a Drill; latent world resource, NOT
## "items present" — depleting it is conservation-neutral (the ore it yields is total_produced, as ever).
var deposits: Dictionary = {}
## What the player is carrying (item StringName -> count). Session state owned by the sim (so it is
## deterministic + serializable); the avatar only triggers discrete mine/deposit calls. Counted as
## "items present" for conservation. Rendered as the inventory hotbar (see `inventory_slots`).
var inventory: Dictionary = {}
## How many distinct stacks the carried pack shows as hotbar slots. The pack is intentionally small
## (GDD: a limited pack forces hauling trips). No hard capacity is ENFORCED yet — that's a feel/
## economy knob to turn when trip-friction is the thing being tuned (with the build economy). Sized to
## hold the current resources + craftable machine types at once (ore/ingot/wood/coal + the machines).
const INVENTORY_SLOTS: int = 10
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
## DERIVED power field (cell -> available power units), rebuilt from scratch every tick by _compute_power
## from fueled generators (+ conduits, later). NOT authoritative state — a pure function of placement +
## fuel, like updraft_at — so it can never desync. Consumers read it via power_at(); the view tints it.
var power: Dictionary = {}

var _tick_accumulator: float = 0.0


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS


func machine_at(cell: Vector2i) -> MachineState:
	return grid.get(cell, null)


## Is this cell solid (any material)? (Representation reads this for collision; sim mutates it only
## via set_solid / mine.)
func is_solid(cell: Vector2i) -> bool:
	return solid.has(cell)


## Is `cell` inside a LIFT's updraft — i.e. is there a clear (unblocked) column straight DOWN to a
## lift machine? The lift inverts gravity in the open shaft above it; the avatar reads this to ride
## UP (representation only — pure query, no sim mutation, determinism untouched).
func updraft_at(cell: Vector2i) -> bool:
	for row: int in range(cell.y + 1, GRID_ROWS):
		var here := Vector2i(cell.x, row)
		if solid.has(here):
			return false  # a floor breaks the draft
		var m: MachineState = grid.get(here, null)
		if m != null:
			return m.def.behavior == &"lift"  # first machine below is a lift → in its updraft
	return false


## The material in a cell (&"earth" / &"ore"), or &"" if open. Lets the view tint veins.
func material_at(cell: Vector2i) -> StringName:
	return solid.get(cell, &"")


## --- Surface silhouette: the ONE authority for the walkable-top shape (renderer + player share it) ---
## The diagonal "slope" of the ground is a property of TERRAIN TOPOLOGY alone — independent of material
## (earth, stone, ore all ramp the same) and EXCLUDING machines (a placed machine is a box you bump or
## jump onto, never a hill). Both the renderer (draws the diagonal) and the avatar (glides it) call
## these, so what you SEE is exactly what you WALK — no phantom invisible ramps, no un-ramped stone.

## Topmost solid terrain row in a column (the exposed surface), or GRID_ROWS if the column is all air.
## FOLIAGE (trees: wood/leaves) is SKIPPED — it's solid for collision + mineable, but it is not walkable
## ground, so it must not become the silhouette (else a tree would draw a grass cap on its canopy and the
## avatar would try to ramp up the trunk). Same exclusion machines get: present, but not the terrain top.
func surface_row(col: int) -> int:
	for row: int in range(0, GRID_ROWS):
		var cell := Vector2i(col, row)
		if solid.has(cell) and not _is_foliage(solid[cell]):
			return row
	return GRID_ROWS


## Tree materials — solid + mineable, but excluded from the walkable surface silhouette (see surface_row).
func _is_foliage(material: StringName) -> bool:
	return material == &"wood" or material == &"leaves"


## Slope of the exposed surface at a column: +1 rising to the right, -1 rising to the left, 0 flat.
## A neighbour exactly ONE tile higher reads as a 45° ramp; a bigger step is a wall (0 here → the
## avatar's square-collision blocks it, the renderer draws no diagonal). Terrain only — machines and
## material never enter, which is precisely what kills the two bugs the split authority caused.
func ramp_dir(col: int) -> int:
	var here: int = surface_row(col)
	var left: int = surface_row(col - 1)
	var right: int = surface_row(col + 1)
	if right == here - 1 and left >= here:
		return 1
	if left == here - 1 and right >= here:
		return -1
	return 0


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
	deposits.clear()
	for cell: Vector2i in world.blocks:
		if in_bounds(cell):
			solid[cell] = world.blocks[cell]
	for cell: Vector2i in world.walls:
		if in_bounds(cell):
			wall[cell] = world.walls[cell]
	for cell: Vector2i in world.amounts:
		if in_bounds(cell):
			deposits[cell] = int(world.amounts[cell])


## Player action: dig out a solid cell. Returns the material mined (&"earth"/&"ore"), or &"" if the
## cell was already open. Mining an ORE vein yields one ore into the player's pack — and that ore is
## genuinely produced from the world, so it counts toward total_produced (conservation stays true).
## The cell's background WALL is left intact (you carve the block, the wall stays behind).
func mine(cell: Vector2i) -> StringName:
	if not solid.has(cell):
		return &""
	var material: StringName = solid[cell]
	if material == &"ore":
		# A finite deposit: each hit yields 1 ore and drains the pool; the block only clears (wall kept)
		# once the pool is empty. A cell with no pool entry holds 1 → one hit, exactly as before.
		inventory[&"ore"] = int(inventory.get(&"ore", 0)) + 1
		total_produced[&"ore"] = int(total_produced.get(&"ore", 0)) + 1
		if _drain_deposit(cell):
			solid.erase(cell)
		return material
	if _is_foliage(material):
		# Chop a tree: one hit FELLS the whole tree (no floating canopy), yielding 1 wood per trunk cell.
		var got: int = _fell_tree(cell)
		if got > 0:
			inventory[&"wood"] = int(inventory.get(&"wood", 0)) + got
			total_produced[&"wood"] = int(total_produced.get(&"wood", 0)) + got
		return material
	solid.erase(cell)
	return material


## Fell the tree containing `cell`: flood-fill the connected foliage (trunk + the 3-wide canopy), clear
## it all, and return how many WOOD cells it held (leaves yield nothing). The fill stops at the ground
## (earth isn't foliage) so it never eats terrain, and is capped so a pathological foliage mass can't run
## away. Cleared cells become open air again (a tree has no wall behind it).
const _FELL_CAP: int = 64
func _fell_tree(cell: Vector2i) -> int:
	var wood: int = 0
	var seen: Dictionary = {}
	var stack: Array[Vector2i] = [cell]
	while not stack.is_empty() and seen.size() < _FELL_CAP:
		var c: Vector2i = stack.pop_back()
		if seen.has(c) or not _is_foliage(solid.get(c, &"")):
			continue
		seen[c] = true
		if solid[c] == &"wood":
			wood += 1
		solid.erase(c)
		stack.append(c + Vector2i(1, 0))
		stack.append(c + Vector2i(-1, 0))
		stack.append(c + Vector2i(0, 1))
		stack.append(c + Vector2i(0, -1))
	return wood


## Player action: PLACE a building-material block from the pack into an open cell (the Terraria build
## primitive — the inverse of mine). Consumes one `material` from the pack; the cell becomes solid. Like
## crafting, the spent item is counted as CONSUMED, and mining it back counts as produced, so conservation
## holds across build/dig (terrain isn't "items present"). Refuses solid/occupied/out-of-bounds cells.
func place_block(cell: Vector2i, material: StringName) -> bool:
	if not in_bounds(cell) or solid.has(cell) or grid.has(cell):
		return false
	if int(inventory.get(material, 0)) <= 0:
		return false
	_take_from_pack(material, 1)
	total_consumed[material] = int(total_consumed.get(material, 0)) + 1
	solid[cell] = material
	return true


## --- The BAZAAR (crafting hub, docs/CRAFTING.md) — detected as a structure in the world, not a machine.
## A bazaar is a distinctive WOOD FRAME with an open interior, sitting on solid ground:
##     W W W W      top beam (all wood)
##     W . . W      posts + open interior
##     W . . W      posts + open interior
##     . G G .      interior floor must be solid ground
## "Active" is DERIVED from the world (a valid frame == active) — no persistent state, so it stays
## deterministic + node-free, and a bazaar you rebuild elsewhere just works. The open interior + exact
## shape is what stops a plain wall/house from matching. (A second `log` material for extra robustness +
## the cozy look, and the NPC walk-in, are deferred — see docs/CRAFTING.md.)
const BAZAAR_W: int = 4
const BAZAAR_H: int = 3

## True if a valid bazaar frame has its top-left corner at `o`. Pure read of `solid`.
func is_bazaar_at(o: Vector2i) -> bool:
	if not in_bounds(o) or not in_bounds(o + Vector2i(BAZAAR_W - 1, BAZAAR_H)):
		return false
	for dx: int in BAZAAR_W:                                   # top beam: all wood
		if solid.get(o + Vector2i(dx, 0), &"") != &"wood":
			return false
	for dy: int in range(1, BAZAAR_H):                         # posts wood, interior open
		if solid.get(o + Vector2i(0, dy), &"") != &"wood":
			return false
		if solid.get(o + Vector2i(BAZAAR_W - 1, dy), &"") != &"wood":
			return false
		for ix: int in range(1, BAZAAR_W - 1):
			if solid.has(o + Vector2i(ix, dy)):
				return false
	for ix: int in range(1, BAZAAR_W - 1):                     # interior floor: real solid ground
		var floor_cell: Vector2i = o + Vector2i(ix, BAZAAR_H)
		if not solid.has(floor_cell) or _is_foliage(solid[floor_cell]):
			return false
	return true


## All valid bazaar frames in the world (their top-left origins). A whole-world scan — cheap enough to
## call on demand (e.g. when the player opens the craft screen), not per-frame. Deterministic ordering.
func find_bazaars() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(0, GRID_ROWS - BAZAAR_H):
		for x: int in range(0, GRID_COLS - BAZAAR_W + 1):
			if is_bazaar_at(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out


## The interior-centre cell of a bazaar at origin `o` (where the NPC stands / the "here" marker sits).
func bazaar_center(o: Vector2i) -> Vector2i:
	return o + Vector2i(BAZAAR_W / 2, BAZAAR_H - 1)


## True if any active bazaar's interior is within `radius` cells of `cell` — the gate for crafting
## (you craft AT the bazaar). Scans the detected frames; cheap on demand.
func near_bazaar(cell: Vector2i, radius: int) -> bool:
	for o: Vector2i in find_bazaars():
		var c: Vector2i = bazaar_center(o)
		if absi(c.x - cell.x) <= radius and absi(c.y - cell.y) <= radius:
			return true
	return false


## Take one unit from `cell`'s deposit pool (default 1 if untracked). Returns true when the pool is now
## EMPTY (the caller clears the ore block). Shared by hand-mining and the Drill so both drain identically.
func _drain_deposit(cell: Vector2i) -> bool:
	var left: int = int(deposits.get(cell, 1)) - 1
	if left > 0:
		deposits[cell] = left
		return false
	deposits.erase(cell)
	return true


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


## Player action: DROP items from the pack into a column — gravity is the conveyor, so you don't
## "insert" into a machine, you let go and it FALLS. Reuses _column_landing: the dropped items cascade
## straight down `cell`'s column from the player's row and land in the first machine below (feeding its
## input), else on the first floor as a ground pile (re-collectable), else the void sink. Returns how
## many dropped. Conservation holds: items only MOVE pack→(machine|ground|sink), none made or destroyed.
## `from_cell` is the VISUAL launch origin for the cosmetic toss (the body's cell when you toss ore into
## the next column over) — it only colours the flow_event's `from`, which the sim never reads back, so
## the production landing is unaffected. Default sentinel (-1,-1) means "launch from `cell`" (straight drop).
func drop_item(cell: Vector2i, item: StringName, count: int, from_cell: Vector2i = Vector2i(-1, -1)) -> int:
	var have: int = int(inventory.get(item, 0))
	var n: int = mini(have, count)
	if n <= 0:
		return 0
	_take_from_pack(item, n)
	var origin: Vector2i = cell if from_cell == Vector2i(-1, -1) else from_cell
	var dest: Dictionary = _column_landing(cell.x, cell.y)
	dest["target"][item] = int(dest["target"].get(item, 0)) + n
	flow_events.append({"item": item, "from": origin, "to": dest["to_cell"], "count": n})
	return n


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


## One deterministic logical step: derive the power field, every machine runs (consumers read the field),
## then items fall one stage downward.
func tick() -> void:
	_compute_power()
	for machine: MachineState in machines:
		_run_machine(machine)
	_flow()


## Rebuild the power field from scratch (docs/POWER.md): every FUELED generator stamps its innate aura.
## Pure derived state — cleared and recomputed each tick so it never desyncs from placement/fuel. Conduits
## extend this field in a later slice; for now a generator powers only the diamond of cells around it.
func _compute_power() -> void:
	power.clear()
	for machine: MachineState in machines:
		if machine.def.behavior == &"generator" and machine.fuel > 0:
			_emit_aura(machine.cell, GENERATOR_POWER)


## Stamp a generator's innate aura: an attenuating diamond (manhattan radius POWER_AURA) of power around
## `origin`. Overlapping auras take the MAX (a supply reading, not a sum — two generators don't conjure
## double power at a shared cell). The strength fades to 0 at the rim so the lit zone reads as a falloff.
func _emit_aura(origin: Vector2i, amount: float) -> void:
	for dy: int in range(-POWER_AURA, POWER_AURA + 1):
		for dx: int in range(-POWER_AURA, POWER_AURA + 1):
			var dist: int = absi(dx) + absi(dy)
			if dist > POWER_AURA:
				continue
			var cell: Vector2i = origin + Vector2i(dx, dy)
			if not in_bounds(cell):
				continue
			var v: float = amount * (1.0 - float(dist) / float(POWER_AURA + 1))
			power[cell] = maxf(float(power.get(cell, 0.0)), v)


## Available power at a cell (the derived field; 0.0 where none reaches). Consumers read this to throttle;
## the view tints it. Pure read — no mutation, determinism untouched (mirrors updraft_at / material_at).
func power_at(cell: Vector2i) -> float:
	return float(power.get(cell, 0.0))


func _run_machine(machine: MachineState) -> void:
	if machine.def.behavior == &"lift":
		_run_lift(machine)
		return
	if machine.def.behavior == &"splitter":
		_run_splitter(machine)
		return
	if machine.def.behavior == &"drill":
		_run_drill(machine)
		return
	if machine.def.behavior == &"generator":
		_run_generator(machine)
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


## A DRILL automates the by-hand ore mine (docs/MINING.md): it draws from the WORLD, not an input buffer.
## Each cycle (recipe.time) it bores the first ore cell straight below it, drains one unit from that
## deposit (clearing the block when empty — wall kept), and emits recipe.outputs (1 ore) into its output
## buffer, which _flow then drops down the column like any machine. No reachable ore → it idles (progress
## doesn't advance, so it resumes cleanly when a new vein comes into reach as the shaft bores deeper). The
## ore is genuinely produced from the world → total_produced (the same accounting as hand-mining).
func _run_drill(machine: MachineState) -> void:
	var recipe: RecipeDef = machine.def.recipe
	if recipe == null:
		return
	var target: Vector2i = _drill_target(machine.cell)
	if target.x < 0:
		return                          # nothing to bore in reach — idle, hold progress
	machine.progress += SECONDS_PER_TICK
	if machine.progress < recipe.time:
		return
	machine.progress -= recipe.time
	if _drain_deposit(target):
		solid.erase(target)             # deposit exhausted — clear the block (wall kept), bore deeper next
	for item: StringName in recipe.outputs:
		var n: int = int(recipe.outputs[item])
		machine.output_buffer[item] = int(machine.output_buffer.get(item, 0)) + n
		total_produced[item] = int(total_produced.get(item, 0)) + n


## A GENERATOR burns coal to pour power (docs/POWER.md). Each tick it spends one tick of its current fuel;
## when that runs out it consumes one coal from its input buffer to reburn for GENERATOR_FUEL_TICKS. No
## fuel left and no coal → it goes dark (fuel stays 0, so _compute_power emits nothing for it). Coal is
## genuinely consumed (total_consumed) so conservation holds. The power it makes is NOT an item — it's the
## derived field, which _compute_power reads from this machine's fuel>0 state at the top of the next tick.
func _run_generator(machine: MachineState) -> void:
	if machine.fuel > 0:
		machine.fuel -= 1
	if machine.fuel <= 0 and int(machine.input_buffer.get(&"coal", 0)) > 0:
		var left: int = int(machine.input_buffer[&"coal"]) - 1
		if left > 0:
			machine.input_buffer[&"coal"] = left
		else:
			machine.input_buffer.erase(&"coal")
		total_consumed[&"coal"] = int(total_consumed.get(&"coal", 0)) + 1
		machine.fuel = GENERATOR_FUEL_TICKS


## The cell a drill bores: scanning straight DOWN from the drill within DRILL_REACH, the first SOLID cell
## — returned only if it's ore (else the drill is blocked by plain rock and idles). Open air above the
## vein is skipped (the drill string reaches through it). Returns (-1,-1) when no ore is in reach.
func _drill_target(origin: Vector2i) -> Vector2i:
	for row: int in range(origin.y + 1, mini(origin.y + 1 + DRILL_REACH, GRID_ROWS)):
		var cell := Vector2i(origin.x, row)
		if solid.has(cell):
			return cell if solid[cell] == &"ore" else Vector2i(-1, -1)
	return Vector2i(-1, -1)


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
