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
