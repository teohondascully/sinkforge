class_name BuildVerbs
extends RefCounted

## The builder's verbs: spend a carried thing to place it, take a placed thing back into the pack. The
## ledger half of what legacy did inline inside each world verb (`factory_sim.gd` 935-1240): the world
## verb is geometry (`World`, `PlacedVerbs`, ADR 0009 §5) and this is the pack and the accounting around
## it. The spent item counts as CONSUMED and removal counts as PRODUCED, the same symmetric accounting as
## place_block/mine, so a placed layer never silently leaks the conservation invariant. Lifted in A' step
## 3c (D0348).

## Place a building-material block from the pack into an open metre, the inverse of mine. Consumes one
## `material`; the cell becomes solid. Refuses solid, occupied and out-of-bounds cells, and an empty
## pack. The support gate is the command layer's (machines are exempt), as in legacy.
static func place_block(items: Items, logic_cell: Vector2i, material: StringName) -> bool:
	if items.pack.count(material) <= 0 or not items.world.place_block(logic_cell, material):
		return false
	_spend(items, material, 1)
	return true


static func place_conduit(items: Items, logic_cell: Vector2i) -> bool:
	if items.pack.count(&"conduit") <= 0 or not PlacedVerbs.place_conduit(items.world, logic_cell):
		return false
	_spend(items, &"conduit", 1)
	return true


static func remove_conduit(items: Items, logic_cell: Vector2i) -> bool:
	if not PlacedVerbs.remove_conduit(items.world, logic_cell):
		return false
	_recover(items, &"conduit", 1)
	return true


## Hang a rope from `anchor`, one carried rope per segment, until the column ends or the pack runs out.
## Returns the number of segments hung.
static func place_rope(items: Items, logic_anchor: Vector2i) -> int:
	var hung: int = PlacedVerbs.place_rope(items.world, logic_anchor, items.pack.count(&"rope"))
	_spend(items, &"rope", hung)
	return hung


static func retract_rope(items: Items, logic_cell: Vector2i) -> int:
	return _rope_home(items, PlacedVerbs.retract_rope(items.world, logic_cell))


static func remove_rope(items: Items, logic_cell: Vector2i) -> int:
	return _rope_home(items, PlacedVerbs.remove_rope(items.world, logic_cell))


## Segments that came back go into the pack as produced; returns the count for the verb's own return.
static func _rope_home(items: Items, segments: int) -> int:
	_recover(items, &"rope", segments)
	return segments


static func place_torch(items: Items, logic_cell: Vector2i) -> bool:
	if items.pack.count(&"torch") <= 0 or not PlacedVerbs.place_torch(items.world, logic_cell):
		return false
	_spend(items, &"torch", 1)
	return true


static func remove_torch(items: Items, logic_cell: Vector2i) -> bool:
	if not PlacedVerbs.remove_torch(items.world, logic_cell):
		return false
	_recover(items, &"torch", 1)
	return true


static func plant_sapling(items: Items, logic_cell: Vector2i) -> bool:
	if items.pack.count(&"sapling") <= 0 or not PlacedVerbs.plant_sapling(items.world, logic_cell):
		return false
	_spend(items, &"sapling", 1)
	return true


## A FULL PACK LEAVES IT PLANTED (legacy): refusing here destroys nothing, the sapling keeps growing.
static func remove_sapling(items: Items, logic_cell: Vector2i) -> bool:
	if not items.pack.can_carry(&"sapling", 1) or not PlacedVerbs.remove_sapling(items.world, logic_cell):
		return false
	_recover(items, &"sapling", 1)
	return true


static func _spend(items: Items, item: StringName, n: int) -> void:
	_ledger(items, item, n, true)


static func _recover(items: Items, item: StringName, n: int) -> void:
	_ledger(items, item, n, false)


## Spending takes from the pack and counts consumed; recovering adds to the pack and counts produced.
## One body for both directions, so the symmetry that keeps conservation exact is one function.
static func _ledger(items: Items, item: StringName, n: int, spending: bool) -> void:
	if n <= 0:
		return
	if spending:
		items.pack.remove(item, n)
		items.consumed(item, n)
	else:
		items.pack.add(item, n)
		items.produced(item, n)
