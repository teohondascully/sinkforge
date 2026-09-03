class_name Landing
extends RefCounted

## Where a let-go item comes to rest: the falling half of `sim/items`. Lifted in A' step 3c (D0348) from
## `legacy/src/core/factory_sim.gd::_column_landing` (3095): scanning DOWN a column from `start_row`, the
## first machine catches it as a cascade, else it rests on top of the first rock as a ground pile, else
## a column dug clear to the bottom drops it into the void sink. The plan filed this under transport;
## it is here because `drop_item`, the spill and the pile resettle all need it and `sim/items/MODULE.md`
## names falling and settling as this module's own.
##
## TWO DEVIATIONS FROM LEGACY, both recorded in ADR 0009's deferred list: (1) legacy's `_settle_on_slope`
## (an item rolling off a 45-degree surface ramp to its base) is not applied -- it reads `surface_row`
## and `ramp_dir`, which `Heightfield` superseded pending the ramps ruling; (2) "the first solid" is the
## first metre with ANY rock in it, so a pile rests in the metre above a half-dug floor as it would above
## a whole one (ADR 0009: `cell_occupied`'s reading).
##
## A machine's input buffer is reached through `machine_buffer`, a Callable(logic_cell) -> Dictionary
## (null where there is no machine), supplied by whoever owns the machines: `sim/items` depends on
## `world`, not on `machines`.

## The row index one past the last metre row: where a column with no floor drops into the sink.
static func floor_rows(world: World) -> int:
	return world.grid.height / LogicGrid.TERRAIN_PER_LOGIC


## `{"to_cell": logic_cell, "target": Dictionary}` -- the target is a machine's input buffer, a live
## ground pile, or the sink. Add into it; then `piles.prune_empty()` if the add may have been zero.
static func column_landing(world: World, piles: GroundPiles, machine_buffer: Callable, col: int, start_row: int) -> Dictionary:
	var rows: int = floor_rows(world)
	for row: int in range(start_row, rows):
		var here := Vector2i(col, row)
		if world.logic.occupant(here) == LogicGrid.KIND_MACHINE and machine_buffer.is_valid():
			var buffer: Variant = machine_buffer.call(here)
			if buffer != null:
				return {"to_cell": here, "target": buffer}
		if not world.logic_air(here):
			var rest := Vector2i(col, row - 1)
			return {"to_cell": rest, "target": piles.pile(rest)}
	return {"to_cell": Vector2i(col, rows), "target": piles.sink}
