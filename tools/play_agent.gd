class_name PlayAgent
extends RefCounted

## PlayAgent — the embodied test-driver. It PLAYS the real game: it moves the real Player body with
## real platformer physics and triggers the real, reach-gated verbs on MainView (try_mine / try_build /
## try_deposit / try_craft / select) — the SAME surface a human drives with mouse + keys. Nothing here
## reaches past the verb layer to fake a result; if the body can't walk to a cell, it can't mine it,
## exactly like a player. That's what makes a passing play-test mean "a person could actually do this".
##
## Actions are async (await the tree's physics_frame) so a goal reads as a linear script:
##   await agent.dig_down_to(ore); await agent.deposit_into_forge(); ...
## with generous frame budgets and a give() hatch to INJECT resources for setup (e.g. top up ingots
## before testing crafting) — the user-sanctioned shortcut for "arrange the situation, then play it".
##
## Used by tools/play_tests.gd (the scripted test TYPE). See docs/HARNESS.md.

const CELL: int = 32

var tree: SceneTree
var main: MainView
var sim: FactorySim
var player: Player

## A running narration of what the agent did — printed by the harness so a failure is legible.
var trace: Array[String] = []


func _init(scene_tree: SceneTree, main_view: MainView) -> void:
	tree = scene_tree
	main = main_view
	sim = main.sim
	player = main._player
	player.auto_input = false   # the agent, not the keyboard, drives the body


func _note(msg: String) -> void:
	trace.append(msg)


# --- primitive motion -----------------------------------------------------------------------------

## Advance the live game by N physics frames (the sim ticks, the body integrates, ground auto-collects).
func wait(frames: int) -> void:
	for _i: int in frames:
		await tree.physics_frame


## Hold a jump for a couple of frames.
func jump() -> void:
	player.request_jump()
	await wait(2)


## Walk toward a cell until it's within reach, jumping when bumped against a wall. Returns whether the
## cell ended up reachable (a real failure if the terrain genuinely blocks the route — same as a player).
func approach(cell: Vector2i, budget: int = 720) -> bool:
	var target_x: float = main._cell_center(cell).x
	var last_x: float = player.position.x
	var stuck: int = 0
	var t: int = 0
	while t < budget:
		if main._can_reach(cell):
			player.input_dir = 0.0
			return true
		var dx: float = target_x - player.position.x
		player.input_dir = signf(dx) if absf(dx) > 3.0 else 0.0
		# Bumped a wall (not moving though we want to) → try to hop it.
		if player.on_floor and absf(player.position.x - last_x) < 0.4 and absf(dx) > 3.0:
			stuck += 1
			if stuck >= 5:
				player.request_jump()
				stuck = 0
		else:
			stuck = 0
		last_x = player.position.x
		await tree.physics_frame
		t += 1
	player.input_dir = 0.0
	return main._can_reach(cell)


# --- game verbs (each goes through MainView's reach-gated surface) ---------------------------------

## Walk to a solid cell and mine it (genuinely — must be reachable). Returns whether it's now clear.
func mine_cell(cell: Vector2i, budget: int = 720) -> bool:
	if not await approach(cell, budget):
		_note("could not reach %s to mine it" % cell)
		return false
	var t: int = 0
	while sim.is_solid(cell) and t < 30:
		main.try_mine(cell)
		await wait(2)
		t += 1
	return not sim.is_solid(cell)


## Walk along the surface until the body's own column is `col` (and it's standing, not mid-air). The
## prerequisite for sinking a straight shaft — you have to be standing over it first.
func walk_to_column(col: int, budget: int = 720) -> bool:
	var col_x: float = main._cell_center(Vector2i(col, 0)).x
	var last_x: float = player.position.x
	var stuck: int = 0
	var t: int = 0
	while t < budget:
		var here: int = main._cell_at(player.position).x
		if here == col and player.on_floor:
			player.input_dir = 0.0
			return true
		player.input_dir = signf(col_x - player.position.x)
		# Bumped an obstacle (a machine on the surface, a 1-tile step) → hop it, like a player would.
		if player.on_floor and absf(player.position.x - last_x) < 0.4:
			stuck += 1
			if stuck >= 4:
				player.request_jump()
				stuck = 0
		else:
			stuck = 0
		last_x = player.position.x
		await tree.physics_frame
		t += 1
	player.input_dir = 0.0
	return main._cell_at(player.position).x == col


## Dig a straight vertical shaft down to `cell`, the by-hand "go get the buried vein" loop: stand over
## the column, mine the cell under the feet, FALL into it, repeat — exactly how a player sinks a shaft.
## Digging is GATED on staying centred over the column (so it sinks plumb, never carving off sideways),
## and the vein itself is mined the moment it's in reach. Returns whether the target got mined.
func dig_down_to(cell: Vector2i, budget: int = 2400) -> bool:
	var col: int = cell.x
	var col_x: float = main._cell_center(Vector2i(col, 0)).x
	if not await walk_to_column(col):
		_note("could not walk over column %d" % col)
		return false
	var t: int = 0
	while t < budget:
		if not sim.is_solid(cell):
			player.input_dir = 0.0
			return true                              # the vein is mined → in the pack
		var dx: float = col_x - player.position.x
		var centred: bool = absf(dx) < 6.0
		player.input_dir = 0.0 if centred else signf(dx)
		# Only sink while plumb over the column — mine the block under the feet, and the vein once reachable.
		if centred:
			var feet: Vector2i = main._cell_at(player.position + Vector2(0.0, Player.HEIGHT * 0.5 + 2.0))
			if feet.x == col and sim.is_solid(feet) and main._can_reach(feet):
				main.try_mine(feet)
			if main._can_reach(cell):
				main.try_mine(cell)
		await tree.physics_frame
		t += 1
	player.input_dir = 0.0
	_note("ran out of budget digging to %s (stuck near %s)" % [cell, main._cell_at(player.position)])
	return not sim.is_solid(cell)


## Select the carried slot holding `item_id`. Returns whether it's now the active slot.
func select_item(item_id: StringName) -> bool:
	var slots: Array[Dictionary] = sim.inventory_slots()
	for i: int in slots.size():
		if slots[i]["item"] == item_id:
			main._inv_selected = i
			return true
	return false


## Walk within reach of a machine and deposit the selected carried item into it.
func deposit_selected(budget: int = 720) -> bool:
	if sim.machines.is_empty():
		return false
	var machine: MachineState = sim.machines[0]
	if not await approach(machine.cell, budget):
		return false
	return main.try_deposit()


## Stand under a column and wait for product to fall + auto-collect into the pack (the spit→collect loop).
func collect_below(col: int, want_item: StringName, want: int, budget: int = 600) -> bool:
	var floor_row: int = sim.surface_row(col)
	await approach(Vector2i(col, maxi(floor_row - 1, 0)), budget)
	var t: int = 0
	while int(sim.inventory.get(want_item, 0)) < want and t < budget:
		await tree.physics_frame
		t += 1
	return int(sim.inventory.get(want_item, 0)) >= want


## Craft a machine item (spends carried ingots). Returns whether the craft happened.
func craft(def: MachineDef) -> bool:
	return main.try_craft(def)


## Walk within reach of `cell` and place the selected machine there. Returns whether it got built.
func build_at(cell: Vector2i, budget: int = 720) -> bool:
	if not await approach(cell, budget):
		return false
	return main.try_build(cell)


# --- setup hatch (user-sanctioned) ----------------------------------------------------------------

## Inject resources straight into the pack to ARRANGE a situation before playing it (e.g. top up ingots
## so a craft test isn't gated on first smelting 3 ore). Setup only — the verb under test stays real.
func give(item: StringName, n: int) -> void:
	sim.inventory[item] = int(sim.inventory.get(item, 0)) + n


## The nearest solid cell of a given material to the body (e.g. find an ore vein to go dig).
func nearest_material(material: StringName) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d: float = INF
	for cell: Variant in sim.solid:
		var c: Vector2i = cell
		if sim.solid[c] != material:
			continue
		var d: float = main._cell_center(c).distance_to(player.position)
		if d < best_d:
			best_d = d
			best = c
	return best
