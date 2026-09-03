class_name GroundPiles
extends RefCounted

## Product piles resting on the dug floor, and the void sink. Lifted in A' step 3c (D0348) from
## `legacy/src/core/factory_sim.gd`: `ground` (:249, logic_cell -> {item -> count}), `sink` (:252, items
## that fell off the bottom of the world, kept so conservation never silently loses one),
## `_ground_pile` 3147 and `_prune_empty_ground` 2047. A pile is a LIVE dictionary handed to whoever is
## delivering (`Landing.column_landing`'s `target`), added into in place -- legacy's shape, kept -- which
## is why this plane has no running signature: an in-place write to an inner dictionary cannot pass
## through a sandwich. `recomputed_signature()` is the only signature, from scratch, sorted; piles are few.
##
## Every key is a `logic_cell`: an item rests in the metre above the first rock (ADR 0009).

var ground: Dictionary = {}  # logic_cell -> {item: StringName -> count}
var sink: Dictionary = {}    # item -> count that fell out of the world


## The product pile resting in `logic_cell`, created on first landing. Returned LIVE so a deliverer adds
## straight into it; call `prune_empty` after a delivery that may have added nothing.
func pile(logic_cell: Vector2i) -> Dictionary:
	if not ground.has(logic_cell):
		ground[logic_cell] = {}
	return ground[logic_cell]


func has_pile(logic_cell: Vector2i) -> bool:
	return ground.has(logic_cell) and not (ground[logic_cell] as Dictionary).is_empty()


func count_at(logic_cell: Vector2i, item: StringName) -> int:
	return int((ground.get(logic_cell, {}) as Dictionary).get(item, 0))


## An empty pile is a phantom: it crashes walk-over collect and draws a ghost guide.
## Conservation-neutral at 0 items, so pruning is safe. Ground is small, so this is cheap.
func prune_empty() -> void:
	for logic_cell: Variant in ground.keys():
		if (ground[logic_cell] as Dictionary).is_empty():
			ground.erase(logic_cell)


## Units of `item` resting on the ground anywhere, plus what fell into the sink.
func present(item: StringName) -> int:
	var total: int = int(sink.get(item, 0))
	for logic_cell: Vector2i in ground:
		total += int((ground[logic_cell] as Dictionary).get(item, 0))
	return total


func pile_logic_cells() -> Array[Vector2i]:
	return Ordering.cells(ground)


func recomputed_signature() -> String:
	var a: int = 0
	var b: int = 0
	for logic_cell: Vector2i in ground:
		var p: Dictionary = ground[logic_cell]
		for item: StringName in Ordering.ids(p):
			var t: Vector2i = StateHash.term(logic_cell.x, logic_cell.y, StateHash.id_fold(item), Vector2i(int(p[item]), int(p[item])))
			a ^= t.x
			b ^= t.y
	for item: StringName in Ordering.ids(sink):
		var f: Vector2i = StateHash.id_fold(item)
		var t2: Vector2i = StateHash.term(f.x, f.y, Vector2i(int(sink[item]), int(sink[item])), Vector2i.ZERO)
		a ^= t2.x
		b ^= t2.y
	return "g%d:%d" % [a, b]


func clone() -> GroundPiles:
	var copy: GroundPiles = GroundPiles.new()
	for logic_cell: Vector2i in ground:
		copy.ground[logic_cell] = (ground[logic_cell] as Dictionary).duplicate()
	copy.sink = sink.duplicate()
	return copy
