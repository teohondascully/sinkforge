class_name TileGrid
extends SignedPlane

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

## A CHANGE TOKEN FOR THE TERRAIN, bumped by `_xor_term` on every write (D0340). Not a count of anything
## and never compared for ordering — only for equality, by consumers asking "is what I cached still what
## the world holds". `Interface.observe` uses it to skip rebuilding a window plane that cannot have
## changed, which took the per-tick observation from 6.36 ms to near nothing.
##
## **NOT PART OF THE STATE SIGNATURE, deliberately.** `state_signature()` is computed from `_blocks` and
## `_walls` themselves; this is derived bookkeeping about how many times they were touched, and two worlds
## that hold identical cells must hash identically however they got there. Including it would make a
## replay that reached the same world by a different route look like a divergence.
## `SignedPlane.version` under the name every cache on the terrain already keys on (D0340): one counter,
## bumped in the one `_xor_term` every mutation passes through. D0390 made the plane's origin its base.
var terrain_version: int:
	get:
		return version
	set(v):
		version = v
var _dig_extent: Dictionary = {}  # col: int -> Vector2i(min_row_ever_dug, max_row_ever_dug)

## THE COARSE PLANE (A' step 6i, D0371): one CLASS byte per LOGIC cell, row-major over
## `coarse_width x coarse_height`, for the minimap -- void, dug-with-a-wall-behind, rock, or ore. Each
## logic cell is classed by its CENTRE terrain cell (offset 2,2 of its 4x4), so a write anywhere else in
## the cell costs nothing and a write at the centre is O(1): the plane is maintained at the three
## mutators, never rebuilt. `coarse_version` bumps only when a class actually changes, which is what
## the minimap keys its cached image on -- the plan's own note: a version counter, never a size
## comparison. NOT part of the state signature: derived bookkeeping, like `terrain_version`.
const COARSE_VOID: int = 0
const COARSE_WALL: int = 1
const COARSE_ROCK: int = 2
const COARSE_ORE: int = 3
const COARSE_CENTRE: int = LogicGrid.TERRAIN_PER_LOGIC / 2
var coarse: PackedByteArray = PackedByteArray()
var coarse_width: int = 0
var coarse_height: int = 0
var coarse_version: int = 0
## THE FLAT INDEX PLANES (D0390): one byte per terrain cell, row-major over `width x height`, holding the
## ordinal in `legend` of the cell's block (`block_index`) or wall (`wall_index`); 0 is air. Maintained at
## the same three mutators as `coarse`, never rebuilt, outside the signature. They exist so a window of the
## world is row SLICES (`WindowPlanes.of_plane`) instead of a Callable and a hashed lookup per cell -- the
## remedy `interface/window_planes.gd` recorded from legacy's `factory_sim.gd:795`, done as a derived
## plane beside the dictionary rather than as a change to what the signature is computed over.
## `legend` is per grid, index 0 the empty id, every other id appended when first written, never reordered.
var legend: PackedStringArray = PackedStringArray([""])
var _ordinal: Dictionary = {&"": 0}
var block_index: PackedByteArray = PackedByteArray()
var wall_index: PackedByteArray = PackedByteArray()
## THE SKY FLOOR (D0391): per column, the row of the first solid cell under the open sky, `height` when
## the column is all air. Legacy's `sim.surface_row(col)`, which its skylight measured from (light scatters
## `SKY_FADE` under the first rock and no further). Maintained at the mutators like the planes above: a
## solid write above the floor lowers it in O(1); a dig AT the floor rescans down to the next solid.
var sky_floor: PackedInt32Array = PackedInt32Array()

## D0261's two 32-bit XOR lanes (`_sig_a`, `_sig_b`) and `_xor_term` are inherited from `SignedPlane`
## since D0390 -- this file was the pattern's origin and carried a private copy until the duplication gate
## refused it. The arithmetic is unchanged: MEASURED, not assumed, at 47,603 occupied cells one string
## signature was a **1,148,776-character string taking 109.55 ms**, and `test_shaft_replay_determinism`
## builds 200 of them in each of three processes -- so the lanes exist, and XOR because the accumulator
## must be order-independent AND self-inverting (`excavate` removes a cell's contribution without a
## rebuild). Two lanes rather than one 64-bit accumulator because GDScript ints wrap silently past 63 bits.


func _init(p_width: int, p_height: int, p_seed: int) -> void:
	width = p_width
	height = p_height
	seed = p_seed
	coarse_width = ceili(float(width) / float(LogicGrid.TERRAIN_PER_LOGIC))
	coarse_height = ceili(float(height) / float(LogicGrid.TERRAIN_PER_LOGIC))
	coarse.resize(coarse_width * coarse_height)
	block_index.resize(width * height)
	wall_index.resize(width * height)
	sky_floor.resize(width)
	sky_floor.fill(height)


## The class a terrain cell would give its logic cell: what the coarse plane holds at that cell's centre.
func coarse_class_of(terrain_cell: Vector2i) -> int:
	var m: StringName = get_material(terrain_cell)
	if m != &"":
		return COARSE_ORE if WorldMaterials.is_ore_like(m) else COARSE_ROCK
	return COARSE_WALL if get_wall(terrain_cell) != &"" else COARSE_VOID


func coarse_at(logic_cell: Vector2i) -> int:
	if logic_cell.x < 0 or logic_cell.y < 0 or logic_cell.x >= coarse_width or logic_cell.y >= coarse_height:
		return COARSE_VOID
	return coarse[logic_cell.y * coarse_width + logic_cell.x]


## After a write at `terrain_cell`: re-class its logic cell if the write was at the cell's centre.
func _coarse_refresh(terrain_cell: Vector2i) -> void:
	var n: int = LogicGrid.TERRAIN_PER_LOGIC
	if posmod(terrain_cell.x, n) != COARSE_CENTRE or posmod(terrain_cell.y, n) != COARSE_CENTRE:
		return
	var i: int = (terrain_cell.y / n) * coarse_width + terrain_cell.x / n
	if i < 0 or i >= coarse.size():
		return
	var cls: int = coarse_class_of(terrain_cell)
	if coarse[i] != cls:
		coarse[i] = cls
		coarse_version += 1


func in_bounds(terrain_cell: Vector2i) -> bool:
	return terrain_cell.x >= 0 and terrain_cell.x < width and terrain_cell.y >= 0 and terrain_cell.y < height


## Empty StringName (`&""`) means air -- no block, nothing to dig, nothing to collide with.
func get_material(terrain_cell: Vector2i) -> StringName:
	return _blocks.get(terrain_cell, &"")


func set_material(terrain_cell: Vector2i, material_id: StringName) -> void:
	_write_layer(_blocks, terrain_cell, material_id)
	_stamp(terrain_cell, material_id, true)


func get_wall(terrain_cell: Vector2i) -> StringName:
	return _walls.get(terrain_cell, &"")


## The wall only reaches the signature THROUGH an occupied cell -- `state_signature()` reads
## `get_wall()` for cells in `_blocks` and nowhere else. So setting a wall behind air legitimately
## changes nothing, and `_cell_term` returns zero there by the same test the signature itself uses. Getting
## this wrong in the other direction (always xoring) would desynchronise the running hash from the
## recomputed one, which is exactly what `_recomputed_signature()` exists to catch.
func set_wall(terrain_cell: Vector2i, material_id: StringName) -> void:
	_write_layer(_walls, terrain_cell, material_id)
	_stamp(terrain_cell, material_id, false)


## After a layer write: the flat index plane and the coarse class, the two derived planes.
func _stamp(terrain_cell: Vector2i, material_id: StringName, block: bool) -> void:
	if in_bounds(terrain_cell):
		var i: int = terrain_cell.y * width + terrain_cell.x
		if block:
			block_index[i] = ordinal_of(material_id)
			_sky_note(terrain_cell, material_id != &"")
		else:
			wall_index[i] = ordinal_of(material_id)
	_coarse_refresh(terrain_cell)


func is_solid(terrain_cell: Vector2i) -> bool:
	return get_material(terrain_cell) != &""


## Removes the block, revealing whatever wall sits behind it -- the "hole is a conveyor belt" moment's
## other half (`docs/GDD.md` §10): digging never leaves a void with nothing drawn behind it.
func excavate(terrain_cell: Vector2i) -> void:
	_xor_term(_cell_term(terrain_cell))
	_blocks.erase(terrain_cell)
	if in_bounds(terrain_cell):
		block_index[terrain_cell.y * width + terrain_cell.x] = 0
		_sky_note(terrain_cell, false)
	_coarse_refresh(terrain_cell)


## After a block write: the column's sky floor. A solid above the floor is the new floor; air at the
## floor hands it to the next solid below (or `height`).
func _sky_note(terrain_cell: Vector2i, solid: bool) -> void:
	var top: int = sky_floor[terrain_cell.x]
	if solid:
		if terrain_cell.y < top:
			sky_floor[terrain_cell.x] = terrain_cell.y
	elif terrain_cell.y == top:
		var r: int = terrain_cell.y + 1
		while r < height and not is_solid(Vector2i(terrain_cell.x, r)):
			r += 1
		sky_floor[terrain_cell.x] = r


## The byte `legend` gives a material id; a first-seen id joins the legend. A grid holds at most 255 ids,
## which is an error worth hearing about rather than a wrapped byte.
func ordinal_of(material_id: StringName) -> int:
	var known: Variant = _ordinal.get(material_id)
	if known != null:
		return int(known)
	if legend.size() >= 256:
		push_error("TileGrid.ordinal_of: more than 255 material ids on one grid (%s)" % material_id)
		return 0
	var i: int = legend.size()
	legend.append(String(material_id))
	_ordinal[material_id] = i
	return i


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
	_xor_term(_dig_term(col))
	_dig_extent[col] = merged
	_xor_term(_dig_term(col))
	return merged


## All occupied terrain cells (blocks only, not walls), sorted for anything that needs a stable
## iteration order -- determinism tests, canonical signatures. Named (and typed) `Array[Vector2i]`
## rather than the bare `Array` this returned before D0026's audit: a return value is exactly as able
## to smuggle a wrong-scale coordinate past a caller as a parameter is, and `occupied_cells()` didn't
## carry the `terrain_cell` naming discipline every parameter here does -- an untyped `Array` from a
## function whose name doesn't say "terrain" told a reader nothing about scale at all.
## A copy of the dug-extent table (col -> Vector2i(min_row, max_row)) for the save; `extend_terrain_dig_extent`
## is its inverse. Read-only: the copy is the caller's.
func dig_extents() -> Dictionary:
	return _dig_extent.duplicate()


func occupied_terrain_cells() -> Array[Vector2i]:
	return Ordering.cells(_blocks)


## Every cell with a wall, behind rock or behind air, in scan order. The signature sees a wall only
## through an occupied cell (see `set_wall`); the save must carry the ones behind air too, since the
## renderer draws them (ADR 0010).
func wall_terrain_cells() -> Array[Vector2i]:
	return Ordering.cells(_walls)


## THE MIXER LIVES IN `core/state_hash.gd` (D0344). It was three private statics here (`_fold`, `_mix`,
## `_id_fold`) while this was the only plane; `WaterPlane` and the metre-cell planes to come hash with the
## same `StateHash.term`, arithmetic unchanged from D0261 -- 31 bits per lane so no implementation-defined
## int32 narrowing can differ between architectures, a polynomial fold over integers rather than an engine
## `String.hash()` whose cross-process stability is not guaranteed, two seeds for two lanes (that file's
## header carries the reasons). The memoised id fold that D0334 measured as a third of world generation is
## `StateHash.id_fold`. What is this grid's own is the two terms below.
##
## One occupied cell's contribution, or ZERO if the cell holds no block. The zero case is what makes
## `_write_layer` safe to xor unconditionally on both sides of a mutation: xoring zero is a no-op, so a
## cell that was air before and after contributes nothing either time, and a cell that changed occupancy
## contributes on exactly the side where it was occupied.
func _cell_term(terrain_cell: Vector2i) -> Vector2i:
	if not _blocks.has(terrain_cell):
		return Vector2i.ZERO
	return StateHash.term(terrain_cell.x, terrain_cell.y,
		StateHash.id_fold(_blocks[terrain_cell]), StateHash.id_fold(get_wall(terrain_cell)))


func _dig_term(col: int) -> Vector2i:
	if not _dig_extent.has(col):
		return Vector2i.ZERO
	var extent: Vector2i = _dig_extent[col]
	return StateHash.text_term("dig%d:%d,%d" % [col, extent.x, extent.y])


## Both layers maintain the running signature the same way, and saying that ONCE is the point: the
## sandwich below (xor out, write, xor in) is the invariant every cell-layer write must honour, and two
## copies of it are two places for a future layer to be added wrong. `_blocks` and `_walls` differ only in
## which dictionary they land in -- `_cell_term` already reads both, so the maintenance is identical by
## construction rather than by coincidence. A duplication gate caught this the moment it appeared.
func _write_layer(layer: Dictionary, terrain_cell: Vector2i, material_id: StringName) -> void:
	_xor_term(_cell_term(terrain_cell))  # out with the old (zero, and a no-op, if the cell held no block)
	layer[terrain_cell] = material_id
	_xor_term(_cell_term(terrain_cell))  # in with the new


## A deep copy: same cells, same walls, same dig extents, same signature, sharing no state with the
## original. Exists for tests that need N independent copies of one expensive world (D0267) --
## `ShaftGenerator.generate` is ~858 ms for a 48x1024 shaft, of which ~414 ms is five-octave noise, so a
## suite regenerating the same (site, seed) once per assertion pass pays that repeatedly for worlds it has
## already built.
##
## `Dictionary.duplicate()` is used WITHOUT `true` (no recursive deep copy) and that is correct rather
## than a shortcut: the values are `StringName` and `Vector2i`, both immutable value types in GDScript, so
## a shallow copy of the mapping already gives the clone its own independent state. A recursive duplicate
## would copy nothing further and cost more.
##
## The signature lanes are copied rather than recomputed, and `tests/test_tile_grid.gd` asserts a clone's
## `state_signature()` equals the original's AND equals its own `recomputed_signature()` -- so a clone
## that silently dropped a layer would be caught by the same guard that catches a forgotten mutation
## update, rather than by a separate promise.
func clone() -> TileGrid:
	var copy: TileGrid = TileGrid.new(width, height, seed)
	copy._blocks = _blocks.duplicate()
	copy._walls = _walls.duplicate()
	copy._dig_extent = _dig_extent.duplicate()
	copy._sig_a = _sig_a
	copy._sig_b = _sig_b
	copy.coarse = coarse.duplicate()
	copy.coarse_version = coarse_version
	copy.legend = legend.duplicate()
	copy._ordinal = _ordinal.duplicate()
	copy.block_index = block_index.duplicate()
	copy.wall_index = wall_index.duplicate()
	copy.sky_floor = sky_floor.duplicate()
	return copy


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
