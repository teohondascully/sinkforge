class_name PlacedVerbs
extends RefCounted

## The placed-layer verbs -- conduit, rope, torch, sapling -- as static functions over a `World`. Lifted
## in A' step 3b (D0347) from `legacy/src/core/factory_sim.gd` (`place_conduit`/`remove_conduit` 956-991,
## `place_rope`/`retract_rope`/`remove_rope` 1002-1060, `place_torch`/`remove_torch` 1062-1099,
## `can_plant_sapling`/`plant_sapling`/`remove_sapling` 1198-1240), minus the pack: legacy spent the
## inventory and wrote `total_consumed` inside each verb, and here each returns what it did so the items
## sub-step can ledger it (ADR 0009 §5). The geometry, the refusals and their order are legacy's.
## Kept out of `world.gd` for the 400-line file cap, not for any difference in kind.

## Place a conduit into an open cell. Refuses solid, occupied, already-piped and out-of-bounds cells.
## Returns whether it went down.
static func place_conduit(world: World, logic_cell: Vector2i) -> bool:
	if not world.logic_open(logic_cell):
		return false
	return world.logic.occupy(logic_cell, LogicGrid.KIND_CONDUIT, 1)   # tier 1 (the only tier for now)


## Pick a placed conduit back up. Returns whether one was there.
static func remove_conduit(world: World, logic_cell: Vector2i) -> bool:
	return _remove_kind(world, logic_cell, LogicGrid.KIND_CONDUIT)


## The mirror of every single-cell placement: vacate the cell if THIS kind is there. One helper for the
## conduit and the torch rather than two identical bodies (`tools/quality_check/duplication.py`).
static func _remove_kind(world: World, logic_cell: Vector2i, kind: StringName) -> bool:
	if world.logic.occupant(logic_cell) != kind:
		return false
	world.logic.vacate(logic_cell)
	return true


## Hang a rope at `anchor` and let it unroll DOWN the open column, one segment per cell, until it hits
## rock, a machine, an existing rope or the world floor, or `max_segments` (the pack) runs out. One
## placement ropes a whole shaft. Returns the number of segments hung; 0 means refused.
static func place_rope(world: World, logic_anchor: Vector2i, max_segments: int) -> int:
	var hung: int = 0
	var c: Vector2i = logic_anchor
	while world.logic_in_bounds(c) and not world.cell_occupied(c) and hung < max_segments:
		world.logic.occupy(c, LogicGrid.KIND_ROPE)
		hung += 1
		c += Vector2i(0, 1)
	return hung


## Retract the whole rope through `logic_cell`, walking up to its anchor and taking every segment back.
## Returns segments recovered.
static func retract_rope(world: World, logic_cell: Vector2i) -> int:
	if not world.logic.is_climbable(logic_cell):
		return 0
	return remove_rope(world, world.logic.logic_rope_anchor(logic_cell))


## Cut the rope at `logic_cell`: that segment and every connected segment BELOW it come back, since the
## tail cannot float. Returns how many segments came back.
static func remove_rope(world: World, logic_cell: Vector2i) -> int:
	var cut: int = 0
	var c: Vector2i = logic_cell
	while world.logic.is_climbable(c):
		world.logic.vacate(c)
		cut += 1
		c += Vector2i(0, 1)
	return cut


## Mount a torch on an open cell. Needs a backing to hang from: a wall behind the cell or a full solid
## face, so no torch floats in open sky. Returns whether it mounted.
static func place_torch(world: World, logic_cell: Vector2i) -> bool:
	if not world.logic_open(logic_cell) or not world.backed(logic_cell):
		return false
	return world.logic.occupy(logic_cell, LogicGrid.KIND_TORCH)


static func remove_torch(world: World, logic_cell: Vector2i) -> bool:
	return _remove_kind(world, logic_cell, LogicGrid.KIND_TORCH)


## Would a sapling go in here? Open (no rock, nothing placed, no sapling already) and sitting ON soil.
## Legacy's own list (`factory_sim.gd:1211`) omitted conduits from the sapling gate; `logic_open` closes
## that here, and ADR 0009 records the change. The carried-sapling check is the items sub-step's.
static func can_plant_sapling(world: World, logic_cell: Vector2i) -> bool:
	if not world.logic_open(logic_cell) or world.logic.has_sapling(logic_cell):
		return false
	return world.soil_below(logic_cell)


static func plant_sapling(world: World, logic_cell: Vector2i) -> bool:
	if not can_plant_sapling(world, logic_cell):
		return false
	world.logic.plant(logic_cell)
	return true


## Take a planted sapling back. Growth so far is forfeit. Returns whether one was there.
static func remove_sapling(world: World, logic_cell: Vector2i) -> bool:
	return world.logic.unplant(logic_cell)
