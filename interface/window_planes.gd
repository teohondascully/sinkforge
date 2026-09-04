class_name WindowPlanes
extends RefCounted

## THE BYTE ENCODING OF ONE WINDOW PLANE. Split out of `interface/interface.gd` (D0338) when that file
## reached 415 lines against `docs/QUALITY.md` §2's 400 cap — the same seam-not-trim move `Envelope` got
## at D0294, and taken for the reason that section records: `sim/body/body.gd` sat at exactly 400 for
## three commits running.
##
## The seam is real rather than convenient. `Interface` decides WHAT a consumer may see; this decides HOW
## a plane of it is encoded — the byte array, the interned legend and the row-major order that
## `Observation._offset_of` decodes. Those three are one contract, and keeping them in one file is what
## stops the block plane and the wall plane drifting on it.
##
## **THIS IS THE HOTTEST LOOP IN THE PER-TICK PATH** and it is worth saying so where someone will read it.
## `WorldView.draw_cost_report` measured `observe` at 10.60 ms of a 17.85 ms tick against a 120 Hz budget
## of 8.33; this function is essentially all of it. At the 40-metre framing the window is ~18,900 cells,
## and each costs a `Callable` dispatch plus a `Vector2i`-keyed `Dictionary` lookup.
##
## **THE FIX LEGACY RECORDED, DONE (D0390).** Legacy hit this shape and wrote the remedy down at
## `legacy/src/core/factory_sim.gd:795` — *"for consumers that would otherwise call `fine_is_solid()` a
## quarter of a million times... handing the array over turns that loop into a memcpy."* `TileGrid` now
## keeps flat index planes (`block_index`, `wall_index`, one byte per cell, the grid's own `legend`)
## beside its dictionaries, maintained at the mutators, and `of_plane` below cuts a window out of one as
## row slices. `of` -- the Callable-per-cell form -- stays as the reference the slice form is asserted
## equal to in `tests/test_window_planes.gd`, and for a caller with no grid.


## One plane of the window as `[PackedByteArray, PackedStringArray]`, where `read` maps a terrain cell to
## its material id.
##
## Shared by the block plane and the wall plane rather than written twice. The two loops would differ only
## in which `TileGrid` getter they call, and `tools/quality_check/duplication.py` is a BLOCKING gate that
## would reject the copy — correctly, since the byte encoding, the legend-interning and the row-major
## order are one contract that `Observation._offset_of` decodes for both.
static func of(window: Rect2i, read: Callable) -> Array:
	var index_of: Dictionary = {&"": 0}
	var legend: PackedStringArray = PackedStringArray([&""])
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(window.size.x * window.size.y)
	var i: int = 0
	for row: int in range(window.position.y, window.end.y):
		for col: int in range(window.position.x, window.end.x):
			var m: StringName = read.call(Vector2i(col, row))
			if not index_of.has(m):
				index_of[m] = legend.size()
				legend.append(m)
			bytes[i] = index_of[m]
			i += 1
	return [bytes, legend]


## One plane of the window cut from a world-sized flat plane: row slices, zero (the empty id) wherever the
## window hangs past the world. Byte-identical to `of` over the same grid, at the cost of the slices alone.
static func of_plane(window: Rect2i, plane: PackedByteArray, world: Vector2i) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	var w: int = window.size.x
	var x0: int = maxi(window.position.x, 0)
	var x1: int = mini(window.end.x, world.x)
	var y0: int = maxi(window.position.y, 0)
	var y1: int = mini(window.end.y, world.y)
	if x1 <= x0 or y1 <= y0 or w <= 0:
		out.resize(maxi(w * window.size.y, 0))
		return out
	var blank: PackedByteArray = PackedByteArray()
	blank.resize(w)
	var left: PackedByteArray = blank.slice(0, x0 - window.position.x)
	var right: PackedByteArray = blank.slice(0, window.end.x - x1)
	for row: int in range(window.position.y, window.end.y):
		if row < y0 or row >= y1:
			out.append_array(blank)
			continue
		out.append_array(left)
		out.append_array(plane.slice(row * world.x + x0, row * world.x + x1))
		out.append_array(right)
	return out
