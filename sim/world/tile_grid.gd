class_name TileGrid
extends RefCounted

## The single source of truth for "what is at this cell" -- solid rock, an excavated void, what
## material. `sim/world/MODULE.md`: foundational, nearly everything else queries or mutates this.
##
## Stores the TERRAIN/DIGGING resolution grid (4px cells, `docs/ARCHITECTURE.md` §9) -- the finest
## resolution anything mutates. The 16px machine/logic grid is a VIEW over this, not a second array
## (director directive); nothing in this file knows about it. Every coordinate here is named
## `terrain_cell` rather than a bare `cell`, on purpose -- `docs/DECISIONS_LEDGER.md` D0020.
##
## Sparse `Dictionary`-backed rather than a fixed-size chunk array: correct regardless of what chunk
## size (if any) a later performance pass picks, since that decision is explicitly not made yet
## (D0019). "Bounded shaft region per run, not one persistent grid" (`docs/ARCHITECTURE.md`/
## `ONBOARDING.md`) falls out of this for free -- a shaft's `TileGrid` only ever holds the cells its
## own generation touched.
##
## Two layers, matching `legacy/src/core/world_data.gd`'s pattern: `_blocks` (foreground, solid,
## excavatable) and `_walls` (background, revealed when a block is dug, never itself excavatable).

var width: int
var height: int
var seed: int
var _blocks: Dictionary = {}  # terrain_cell: Vector2i -> material: StringName
var _walls: Dictionary = {}   # terrain_cell: Vector2i -> material: StringName


func _init(p_width: int, p_height: int, p_seed: int) -> void:
	width = p_width
	height = p_height
	seed = p_seed


func in_bounds(terrain_cell: Vector2i) -> bool:
	return terrain_cell.x >= 0 and terrain_cell.x < width and terrain_cell.y >= 0 and terrain_cell.y < height


## Empty StringName (`&""`) means air -- no block, nothing to dig, nothing to collide with.
func get_material(terrain_cell: Vector2i) -> StringName:
	return _blocks.get(terrain_cell, &"")


func set_material(terrain_cell: Vector2i, material_id: StringName) -> void:
	_blocks[terrain_cell] = material_id


func get_wall(terrain_cell: Vector2i) -> StringName:
	return _walls.get(terrain_cell, &"")


func set_wall(terrain_cell: Vector2i, material_id: StringName) -> void:
	_walls[terrain_cell] = material_id


func is_solid(terrain_cell: Vector2i) -> bool:
	return get_material(terrain_cell) != &""


## Removes the block, revealing whatever wall sits behind it -- the "hole is a conveyor belt" moment's
## other half (`docs/GDD.md` §10): digging never leaves a void with nothing drawn behind it.
func excavate(terrain_cell: Vector2i) -> void:
	_blocks.erase(terrain_cell)


## All occupied terrain cells (blocks only, not walls), sorted for anything that needs a stable
## iteration order -- determinism tests, canonical signatures. Named (and typed) `Array[Vector2i]`
## rather than the bare `Array` this returned before D0026's audit: a return value is exactly as able
## to smuggle a wrong-scale coordinate past a caller as a parameter is, and `occupied_cells()` didn't
## carry the `terrain_cell` naming discipline every parameter here does -- an untyped `Array` from a
## function whose name doesn't say "terrain" told a reader nothing about scale at all.
func occupied_terrain_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for terrain_cell: Vector2i in _blocks:
		cells.append(terrain_cell)
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	return cells


## Canonical state signature -- sorted by (y, x) so it doesn't depend on `Dictionary` insertion order,
## same shape as `tests/test_base.gd`'s `_canon()`. Used by the shaft-determinism check.
func state_signature() -> String:
	var parts: PackedStringArray = []
	for terrain_cell: Vector2i in occupied_terrain_cells():
		var wall: StringName = get_wall(terrain_cell)
		parts.append("%d,%d:%s/%s" % [terrain_cell.x, terrain_cell.y, get_material(terrain_cell), wall])
	return "|".join(parts)
