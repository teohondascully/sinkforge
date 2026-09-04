class_name AimPlanes
extends RefCounted

## THE AIM'S AFFORDANCES, answered at the door (A' step 6m, D0376). Legacy's controller pushed
## `set_aim(cell, in_reach, placeable, ghost_def, ghost_material, bites)`, `set_feed_target` and
## `set_placement_hint` into the renderer and let the previews read the sim directly; here the observation
## carries the same answers, derived from the verbs' OWN predicates (`Verbs.placeable`, `reachable_eater`,
## `body_occupies`, the rope's and the drill's runners), so the mark can never disagree with the press.
##
## What a mark may say is decided in `view/visuals/mark_layout.gd`; this only says what is TRUE.

const NONE: Vector2i = Vector2i(-1, -1)
const HINT_RING: int = 2   ## how far the nearest-open-cell search reaches, in logic cells


static func fill(o: RefCounted, verbs: Verbs, world: World, machines: Machines) -> void:
	o.held_item = verbs.selected_item()
	o.aim_placeable = false
	o.feed_target = NONE
	o.place_hint = NONE
	o.rope_preview = 0
	o.drill_preview = {}
	if o.held_item != &"":
		var eater: MachineState = verbs.reachable_eater(o.held_item)
		o.feed_target = eater.logic_cell if eater != null else NONE
	if o.aim_cell == NONE:
		return
	var l: Vector2i = logic_of(o.aim_cell)
	var def: MachineDef = verbs.selected_machine_def()
	var material: StringName = verbs.selected_build_material()
	if def == null and material == &"":
		return
	o.aim_placeable = placeable(verbs, world, l, def, material)
	# The nearest open cell, only while standing in your own way is the refusal: legacy's placement hint.
	if not o.aim_placeable and verbs.can_reach(l) and verbs.body_occupies(l):
		o.place_hint = nearest_open(verbs, world, l, def, material)
	if def != null and o.aim_placeable:
		if def.behavior == &"rope":
			o.rope_preview = rope_hang(world, l, verbs.items.pack.count(o.held_item))
		elif def.behavior == &"drill":
			o.drill_preview = drill_preview(world, machines, l)


## The logic cell a terrain cell sits in.
static func logic_of(terrain_cell: Vector2i) -> Vector2i:
	var n: int = LogicGrid.TERRAIN_PER_LOGIC
	return Vector2i(Aim.floor_div(terrain_cell.x, n), Aim.floor_div(terrain_cell.y, n))


## Would the build press land here? The verbs' own gates: reach, then the machine's or the block's rule;
## a placed kind (torch, conduit, rope) asks only for an unoccupied cell in bounds, as its verb does.
static func placeable(verbs: Verbs, world: World, l: Vector2i, def: MachineDef, material: StringName) -> bool:
	if not verbs.can_reach(l):
		return false
	if def != null:
		if def.behavior == &"torch" or def.behavior == &"conduit" or def.behavior == &"rope":
			return world.logic_in_bounds(l) and not world.cell_occupied(l)
		return verbs.placeable(l)
	return material != &"" and verbs.placeable(l) and world.block_supported(l)


## The nearest cell within HINT_RING where the same press would land, or NONE.
static func nearest_open(verbs: Verbs, world: World, l: Vector2i, def: MachineDef, material: StringName) -> Vector2i:
	var best: Vector2i = NONE
	var best_d: int = -1
	for dy: int in range(-HINT_RING, HINT_RING + 1):
		for dx: int in range(-HINT_RING, HINT_RING + 1):
			var c: Vector2i = l + Vector2i(dx, dy)
			if c == l or not placeable(verbs, world, c, def, material):
				continue
			var d: int = dx * dx + dy * dy
			if best_d < 0 or d < best_d:
				best_d = d
				best = c
	return best


## How many segments a rope would hang from `anchor`: `PlacedVerbs.place_rope`'s own walk, read-only.
static func rope_hang(world: World, anchor: Vector2i, carried: int) -> int:
	var hung: int = 0
	var c: Vector2i = anchor
	while world.logic_in_bounds(c) and not world.cell_occupied(c) and hung < carried:
		hung += 1
		c += Vector2i(0, 1)
	return hung


## What a drill placed at `l` would bore: the ore-body cells of the column down to the runner's target,
## the cell the ore would pour into, whether that drop is blocked, and whether a lode in the wall would be
## worked in place instead. {} when there is nothing below to bore.
static func drill_preview(world: World, machines: Machines, l: Vector2i) -> Dictionary:
	var target: Vector2i = Runners.drill_target(world, machines, l)
	var lode: bool = Runners.drill_lode_target(world, l) != Runners.NONE
	if target == Runners.NONE and not lode:
		return {}
	var cells: Array[Vector2i] = []
	if target != Runners.NONE:
		for dy: int in range(1, target.y - l.y + 1):
			var c: Vector2i = l + Vector2i(0, dy)
			if world.logic_ore_body(c):
				cells.append(c)
	return {"target": target, "cells": cells, "blocked": Runners.drill_blocked(world, machines, target),
		"drop": target + Vector2i(0, 1) if target != Runners.NONE else NONE, "lode": lode}
