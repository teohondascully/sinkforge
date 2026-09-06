class_name WaterPlane
extends SignedPlane

## The water plane: an integer level per terrain cell, sparse, with a running state signature.
##
## Lifted in A' step 2 (D0344) from `legacy/src/core/factory_sim.gd:1100-1135` -- the `water` dictionary and its
## accessors `water_at`, `add_water`, `remove_water`, `total_water` -- which sat on `FactorySim` because
## legacy had one grid and one owner. Here the plane lives in `sim/world` beside `TileGrid` and
## `LogicGrid` under one `World` (ADR 0009, moved from `sim/fluid` in step 3b, D0347), and `WaterFlow`
## (`sim/fluid`, the algorithm, verbatim) steps it against the `TileGrid` for solidity. `docs/ARCHITECTURE.md` §9: water flows through
## the fine 4 px terrain grid, so every key here is a `terrain_cell` (D0020), the same cell `TileGrid`
## is keyed on. Legacy's cell was one metre; this one is a quarter metre, so a metre of water is sixteen
## cells of `WATER_MAX` and every legacy per-cell rate that meets this plane converts x16 (plan §3.2).
##
## Levels are integers and water only MOVES inside `WaterFlow`: no source, no drain. `add_water` and
## `remove_water` are the only ways the total changes from outside, and both return what they actually
## did, so a caller can account for every unit. `total_water()` is the conservation probe.
##
## Rock displaces water -- legacy's `set_solid` erased the cell's water so the two layers never coexist
## (`factory_sim.gd:708`). That coupling belongs to whoever owns both planes (the `sim/world` verbs, plan
## step 3); the primitive it calls is `displace()` here.
##
## THE RUNNING SIGNATURE is `SignedPlane`'s (D0261's two lanes, `core/signed_plane.gd`): one term per wet
## cell keyed by coordinate and level, so a checkpoint costs nothing and `recomputed_signature()` can
## catch a write that bypassed the lanes. Every write passes through `set_level`, the only place the
## lanes move -- a fifth mutator added later cannot avoid it without also breaking the signature.

const WATER_MAX: int = 8  ## units a full cell holds (legacy `FactorySim.WATER_MAX`, unchanged per cell)

var levels: Dictionary = {}  # terrain_cell: Vector2i -> level: int; absent means dry, never a stored 0

## THE REST MARKER, derived bookkeeping outside the signature and the save. `WaterFlow.step` is a pure
## function of the levels and the grid's solidity, so a step that changed nothing will change nothing
## again until one of those moves: these record the (plane `version`, grid `terrain_version`, grid) a
## no-change step was measured at, and `at_rest` answers whether that measurement still describes the
## plane. 23K settled aquifer cells cost 10 ms a hub tick before this (2026-09-04); at rest costs one
## comparison. The grid's instance id is part of the key because two grids built alike share a version.
var rest_version: int = -1
var rest_terrain: int = -1
var rest_grid: int = 0

## THE ACTIVE SET'S SEED (D0405), derived bookkeeping outside the signature and the save: every cell
## `set_level` actually wrote since `WaterFlow.step` last drained it. A cell nobody wrote, whose cell below
## nobody wrote, over terrain nobody dug, stopped where it is for a reason that still holds, so the step
## visits the written cells, the cells above them and the runs they sit in, and nothing else. `wake_all`
## asks for one full pass first: a new plane, a clone, a restore.
var touched: Dictionary = {}
var wake_all: bool = true

## THE ROW INDEX, derived: the wet cells of each row, so a window can be read without a scan of the world
## (`wet_terrain_cells_in`; 23K aquifer cells filtered by rectangle on every moving tick was the observation's half of
## the fresh-boot stutter, D0405). Maintained by `set_level`, rebuilt by `clone`.
var _rows: Dictionary = {}   # row: int -> {terrain_cell: true}


func water_at(terrain_cell: Vector2i) -> int:
	return int(levels.get(terrain_cell, 0))


func is_empty() -> bool:
	return levels.is_empty()


## Add up to WATER_MAX water into a cell; returns the amount ACTUALLY added, leaving the caller to
## decide what to do with the overflow. Never adds into a solid cell, since water cannot occupy rock,
## and never creates water from nothing: a 0-level cell drops out of the dict, so total_water is exact.
func add_water(grid: TileGrid, terrain_cell: Vector2i, amount: int) -> int:
	if amount <= 0 or not grid.in_bounds(terrain_cell) or grid.is_solid(terrain_cell):
		return 0
	var here: int = water_at(terrain_cell)
	var added: int = mini(amount, WATER_MAX - here)
	if added <= 0:
		return 0
	set_level(terrain_cell, here + added)
	return added


## Drain up to `amount` water from a cell; returns the amount actually removed. A cell drained to 0 is
## erased (no 0-level ghosts), so water_at/total_water read exactly.
func remove_water(terrain_cell: Vector2i, amount: int) -> int:
	if amount <= 0:
		return 0
	var here: int = water_at(terrain_cell)
	var removed: int = mini(amount, here)
	if removed <= 0:
		return 0
	set_level(terrain_cell, here - removed)
	return removed


## Rock arrived in this cell: clear whatever water it held and return how much that was, so the caller
## (the world verb that placed the rock) can account for the loss. Legacy did this inline in `set_solid`.
func displace(terrain_cell: Vector2i) -> int:
	return remove_water(terrain_cell, water_at(terrain_cell))


## Total water in the world: the conservation probe. `WaterFlow.step` is invariant in this sum.
func total_water() -> int:
	var sum: int = 0
	for v: Variant in levels.values():
		sum += int(v)
	return sum


## Every wet cell in `WaterFlow`'s own scan order: top-to-bottom, then left-to-right. Sorted, so anything
## that iterates the plane in state-affecting code has a total order to stand on (ARCHITECTURE §4).
func wet_terrain_cells() -> Array[Vector2i]:
	return Ordering.cells(levels)


## THE ONE WRITE. A level <= 0 erases the cell. Levels above WATER_MAX are legal here on purpose:
## `WaterFlow`'s lateral settle parks a run's surplus on its leftmost cell to fall next tick, and clamping
## it would delete water (legacy `water_flow.gd`, the `cap_total` branch). A write that stores what is
## already there returns before the sandwich: xor-out then xor-in of one term is the identity, so the
## signature is untouched either way, and the settle pass rewrites every cell of every level run.
##
## The sandwich is written out here rather than through `_write_int` (SignedPlane's other sanctioned form,
## `LogicGrid`'s): the old and new levels are already in hand, so the two terms cost no lookups of their
## own. A pour is two of these per moving cell per tick; D0405 measured the write at 1.8 us before this.
func set_level(terrain_cell: Vector2i, level: int) -> void:
	var here: int = int(levels.get(terrain_cell, 0))
	var next: int = maxi(level, 0)
	if next == here:
		return
	_xor_term(_level_term(terrain_cell, here))
	if next == 0:
		levels.erase(terrain_cell)
		_row_forget(terrain_cell)
	else:
		levels[terrain_cell] = next
		if here == 0:
			_row_note(terrain_cell)
	_xor_term(_level_term(terrain_cell, next))
	touched[terrain_cell] = true


func _row_note(terrain_cell: Vector2i) -> void:
	if not _rows.has(terrain_cell.y):
		_rows[terrain_cell.y] = {}
	_rows[terrain_cell.y][terrain_cell] = true


func _row_forget(terrain_cell: Vector2i) -> void:
	var row: Dictionary = _rows.get(terrain_cell.y, {})
	row.erase(terrain_cell)
	if row.is_empty():
		_rows.erase(terrain_cell.y)


## The wet cells inside `rect`, in scan order, read row by row off the index rather than by filtering the
## world. Equal to filtering `levels` by `rect.has_point` (pinned in `tests/test_water_active.gd`).
func wet_terrain_cells_in(rect: Rect2i) -> Array[Vector2i]:
	var hit: Dictionary = {}
	var x0: int = rect.position.x
	var x1: int = rect.end.x
	for y: int in range(rect.position.y, rect.end.y):
		if not _rows.has(y):
			continue
		for terrain_cell: Vector2i in _rows[y]:
			if terrain_cell.x >= x0 and terrain_cell.x < x1:
				hit[terrain_cell] = true
	return Ordering.cells_native(hit)


## True when a `WaterFlow.step` measured at this exact (version, terrain_version, grid) changed nothing,
## and nothing has written the plane or the terrain since.
func at_rest(grid: TileGrid) -> bool:
	return version == rest_version and grid.terrain_version == rest_terrain and grid.get_instance_id() == rest_grid


## Called by `WaterFlow.step` after its passes with the `version` it saw on entry: a step that wrote
## nothing marks the plane at rest against the terrain it was measured on.
func note_rest(version_before: int, grid: TileGrid) -> void:
	if version == version_before:
		rest_version = version
		rest_terrain = grid.terrain_version
		rest_grid = grid.get_instance_id()


func state_signature() -> String:
	return _lanes("w")


## The signature rebuilt from the cells themselves, for the self-check `tests/test_water_flow.gd` runs
## after randomised mutation. Agreeing with `state_signature()` is what proves no write skipped the lanes.
func recomputed_signature() -> String:
	return _rebuilt("w", wet_terrain_cells())


func clone() -> WaterPlane:
	var copy: WaterPlane = WaterPlane.new()
	_clone_into(copy, [&"levels"])
	for terrain_cell: Vector2i in copy.levels:
		copy._row_note(terrain_cell)
	return copy


func _term_of(key: Variant) -> Vector2i:
	var terrain_cell: Vector2i = key
	return _level_term(terrain_cell, water_at(terrain_cell))


## The term of `terrain_cell` holding `level`: ZERO when dry, so an erased cell contributes nothing.
func _level_term(terrain_cell: Vector2i, level: int) -> Vector2i:
	if level <= 0:
		return Vector2i.ZERO
	return StateHash.term(terrain_cell.x, terrain_cell.y, Vector2i(level, level), Vector2i.ONE)
