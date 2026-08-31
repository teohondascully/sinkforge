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
var _dig_extent: Dictionary = {}  # col: int -> Vector2i(min_row_ever_dug, max_row_ever_dug)

## D0261. Two 32-bit XOR lanes carrying `state_signature()` incrementally, so a checkpoint costs nothing
## instead of re-serialising the whole grid. MEASURED, not assumed: at 47,603 occupied cells one
## signature was a **1,148,776-character string taking 109.55 ms**, and `test_shaft_replay_determinism`
## builds 200 of them in each of three processes -- 21.9 s per process, **65.7 s of the suite's 72 s**.
##
## XOR because the accumulator must be order-independent AND self-inverting: cells arrive in whatever
## order generation and digging touch them, and `excavate` has to REMOVE a cell's contribution without
## rebuilding. XOR gives both for free, and its usual weakness -- equal terms cancelling -- cannot arise
## here because every term is keyed by the coordinate it belongs to, so no two live terms are equal.
##
## Two lanes with different multipliers rather than one 64-bit accumulator: GDScript ints are signed
## 64-bit and multiplication wraps silently, so staying inside 32 bits per lane keeps every operation
## provably in range (`sim/terrain_gen/value_noise.gd` makes the same choice for the same reason). Two
## independent 32-bit lanes give the collision resistance of one 64-bit hash without the overflow.
var _sig_a: int = 0
var _sig_b: int = 0


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
	_xor_cell(terrain_cell)  # out with the old term (no-op if the cell was not occupied)
	_blocks[terrain_cell] = material_id
	_xor_cell(terrain_cell)  # in with the new


func get_wall(terrain_cell: Vector2i) -> StringName:
	return _walls.get(terrain_cell, &"")


## The wall only reaches the signature THROUGH an occupied cell -- `state_signature()` reads
## `get_wall()` for cells in `_blocks` and nowhere else. So setting a wall behind air legitimately
## changes nothing, and `_xor_cell` is a no-op there by the same test the signature itself uses. Getting
## this wrong in the other direction (always xoring) would desynchronise the running hash from the
## recomputed one, which is exactly what `_recomputed_signature()` exists to catch.
func set_wall(terrain_cell: Vector2i, material_id: StringName) -> void:
	_xor_cell(terrain_cell)
	_walls[terrain_cell] = material_id
	_xor_cell(terrain_cell)


func is_solid(terrain_cell: Vector2i) -> bool:
	return get_material(terrain_cell) != &""


## Removes the block, revealing whatever wall sits behind it -- the "hole is a conveyor belt" moment's
## other half (`docs/GDD.md` §10): digging never leaves a void with nothing drawn behind it.
func excavate(terrain_cell: Vector2i) -> void:
	_xor_cell(terrain_cell)
	_blocks.erase(terrain_cell)


## D0125: `_dig_extent`'s own high/low-water-mark update, per column, and its authority ("what should
## THIS dig actually excavate"). Extends column `col`'s historical dig extent to include
## `[touch_top, touch_bottom]` (this dig's own current row-range) and returns the MERGED range the caller
## should excavate -- always the full span from the lowest row ever dug in this column to the highest,
## never just this one touch. This is what makes a gap-within-a-column structurally impossible (the
## D0122/D0123 staircase): any dig touching a column re-opens the ENTIRE historical span, so the column
## is always one contiguous open run from its own dig floor to its own dig ceiling. Column-scoped, not
## grid-wide -- two ADJACENT columns disagreeing with each other is legal, generated-terrain-compatible
## geometry `_resolve_horizontal` already handles correctly; only a gap strictly WITHIN one column was
## the illegal shape a hand-authored or procedurally-generated chamber never produces on its own.
##
## Tracks only DUG extent, not "everything currently open" -- a column can also have a natural,
## generation-time opening (a cave) far from anywhere the player has dug; this deliberately leaves that
## alone rather than merging the two, since the player's own dig history is the only thing this fix is
## about. State lives here, in `TileGrid`, not on `Body` or anywhere else outside it, because a shaft's
## grid is exactly the thing determinism already replays -- a side table anywhere else would be new,
## unreplayed state (`docs/DECISIONS_LEDGER.md` D0125).
func extend_terrain_dig_extent(col: int, touch_top: int, touch_bottom: int) -> Vector2i:
	var merged: Vector2i = Vector2i(touch_top, touch_bottom)
	if _dig_extent.has(col):
		var existing: Vector2i = _dig_extent[col]
		merged = Vector2i(mini(existing.x, touch_top), maxi(existing.y, touch_bottom))
	_xor_dig(col)
	_dig_extent[col] = merged
	_xor_dig(col)
	return merged


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
##
## Includes `_dig_extent` (D0125), sorted by column -- not derivable from `_blocks`/`_walls` alone (a
## column can have a natural, generation-time opening far from anywhere dug, so "what's currently open"
## doesn't say "what's been dug"), and it is real state that affects future gameplay (the next dig
## touching a column). A signature that omitted it could match on `_blocks` while silently diverging on
## dig history -- exactly the "instrument cannot register its subject" class this project keeps finding.
## Deterministic string fold. NOT `String.hash()`: that is engine-provided, and the determinism contract
## may not rest on a value Godot is free to change between versions.
##
## Masked to **31** bits, not 32, and that one bit is load-bearing. The lanes travel in `Vector2i`, whose
## components are `int32_t`; a 32-bit mask produces values above 2^31-1, and narrowing those to a signed
## int32 is an implementation-defined conversion in C++. It happens to be two's-complement wrap on every
## platform Godot ships, and it showed up here as a perfectly stable `-1422115007` -- deterministic on
## this machine, and precisely the kind of thing that is deterministic on this machine right up until CI
## runs a different architecture. A determinism contract may not contain an implementation-defined
## narrowing. 31 bits per lane always fits positively, costs one bit of a 64-bit budget, and removes the
## question entirely.
static func _fold(text: String, h0: int) -> int:
	var h: int = h0
	for i: int in text.length():
		h = ((h * 31) + text.unicode_at(i)) & 0x7FFFFFFF
	return h


## One occupied cell's contribution, or ZERO if the cell holds no block. The zero case is what makes
## `_xor_cell` safe to call unconditionally on both sides of a mutation: xoring zero is a no-op, so a
## cell that was air before and after contributes nothing either time, and a cell that changed occupancy
## contributes on exactly the side where it was occupied.
func _cell_term(terrain_cell: Vector2i) -> Vector2i:
	if not _blocks.has(terrain_cell):
		return Vector2i.ZERO
	var body: String = "%d,%d:%s/%s" % [terrain_cell.x, terrain_cell.y,
		_blocks[terrain_cell], get_wall(terrain_cell)]
	return Vector2i(_fold(body, 2166136261), _fold(body, 486187739))


func _dig_term(col: int) -> Vector2i:
	if not _dig_extent.has(col):
		return Vector2i.ZERO
	var extent: Vector2i = _dig_extent[col]
	var body: String = "dig%d:%d,%d" % [col, extent.x, extent.y]
	return Vector2i(_fold(body, 2166136261), _fold(body, 486187739))


func _xor_cell(terrain_cell: Vector2i) -> void:
	var t: Vector2i = _cell_term(terrain_cell)
	_sig_a ^= t.x
	_sig_b ^= t.y


func _xor_dig(col: int) -> void:
	var t: Vector2i = _dig_term(col)
	_sig_a ^= t.x
	_sig_b ^= t.y


## O(1). The whole grid's signature, carried incrementally by the four mutation methods.
func state_signature() -> String:
	return "%d:%d" % [_sig_a, _sig_b]


## THE GUARD, and the reason this optimisation is safe to make at all (D0261).
##
## An incrementally-maintained hash is the determinism CONTRACT, and its failure mode is silent: a
## mutation path that forgets to update leaves the running value stale, and a stale value AGREES with
## itself across two runs. The suite goes green while the two worlds differ -- the house failure class,
## arriving as a quiet green exactly as it always does.
##
## So the running value is checkable against a from-scratch rebuild over the same state, and
## `tests/test_tile_grid.gd` asserts they agree after every kind of mutation and after randomised
## sequences of them. That assertion fails the moment any path stops updating, which is a stronger and
## more durable guard than remembering to add a mutation test per method. O(n) and called only by tests.
func recomputed_signature() -> String:
	var a: int = 0
	var b: int = 0
	for terrain_cell: Vector2i in occupied_terrain_cells():
		var t: Vector2i = _cell_term(terrain_cell)
		a ^= t.x
		b ^= t.y
	var dig_cols: Array = _dig_extent.keys()
	dig_cols.sort()
	for col: int in dig_cols:
		var t2: Vector2i = _dig_term(col)
		a ^= t2.x
		b ^= t2.y
	return "%d:%d" % [a, b]
