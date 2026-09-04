class_name HubCache
extends RefCounted

## THE HUB PLANES' PER-PLANE CACHE. `HubPlanes.fill` copies four world planes onto the observation,
## window-bounded; before this every hub tick sorted all 23K wet cells and 7K lode cells to filter them to a
## window that held a few hundred (4 ms a hub tick, 2026-09-04). Each plane's copy is a pure function of
## (the plane's `SignedPlane.version`, the window) -- and for the yield plane also the terrain, since it
## reads solidity -- so the copy is kept until one of those moves. `Interface` owns one; the observation
## fields it fills are read-only to every consumer, so successive observations may share them.

var water_key: Array = []
var water: PackedByteArray = PackedByteArray()
var wet_cells: Array[Vector2i] = []
var lode_key: Array = []
var lodes: Dictionary = {}
var yield_key: Array = []
var ore_yield: Dictionary = {}
var placed_key: Array = []
var placed: Dictionary = {}
var conduit_tiers: Dictionary = {}
var saplings: Dictionary = {}
## Refills, for the instrument: a hub tick that reuses every plane reports no rebuild.
var rebuilds: int = 0

## THE BUCKET INDEX of a plane's keys, rebuilt when that plane's version moves: `BUCKET`-cell squares to
## the cells in them, so a window filter visits the ~40 buckets it overlaps instead of every entry. The
## deposit planes hold ~14K entries and change only on a dig; filtering them all on every window snap was
## 2 ms of the snap frame (D0390). Water is not indexed: it moves every hub tick while it flows, and a
## 3K-entry filter costs what its index rebuild would.
const BUCKET: int = 32
var lode_index_version: int = -1
var lode_index: Dictionary = {}
var yield_index_version: int = -1
var yield_index: Dictionary = {}


static func bucket_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(float(cell.x) / float(BUCKET)), floori(float(cell.y) / float(BUCKET)))


static func index_of(keyed: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for cell: Vector2i in keyed:
		var b: Vector2i = bucket_of(cell)
		if not out.has(b):
			out[b] = ([] as Array[Vector2i])
		(out[b] as Array[Vector2i]).append(cell)
	return out


## Every key of the indexed plane inside `w`, unsorted.
static func inside_indexed(index: Dictionary, w: Rect2i) -> Array[Vector2i]:
	var hit: Array[Vector2i] = []
	var b0: Vector2i = bucket_of(w.position)
	var b1: Vector2i = bucket_of(w.end - Vector2i.ONE)
	for by: int in range(b0.y, b1.y + 1):
		for bx: int in range(b0.x, b1.x + 1):
			var cells: Variant = index.get(Vector2i(bx, by))
			if cells == null:
				continue
			for cell: Vector2i in cells:
				if w.has_point(cell):
					hit.append(cell)
	return hit
