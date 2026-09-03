class_name StateHash
extends RefCounted

## The two-lane running-signature mixer every sim plane hashes with. Extracted in A' step 2 (D0344) from
## `sim/world/tile_grid.gd`, where it lived as three private statics while `TileGrid` was the only plane;
## `WaterPlane` needed the same mixer and the metre-cell planes (plan step 4) will too, and a copy per
## plane is two conventions where one is enough -- `tools/quality_check/duplication.py` would refuse the
## copy anyway. The arithmetic is unchanged from D0261's `TileGrid`, so no golden moved:
## `tests/test_state_hash.gd` pins the literal outputs and `tests/test_shaft_replay_determinism.gd` is
## the end-to-end proof.
##
## WHY TWO 32-BIT LANES AND NOT ONE 64-BIT HASH (D0261): GDScript ints are signed 64-bit and multiplication
## wraps silently, so every step here stays inside 31 bits (`& 0x7FFFFFFF`) and is provably in range. Two
## independent lanes seeded differently give the collision resistance of one 64-bit hash without the
## overflow. A plane XORs one `term` per live record into its two lanes: XOR is order-independent and
## self-inverting, so a record can be removed without a rebuild, and equal terms cannot cancel because
## every term carries the coordinate it belongs to.
##
## THIS IS A SIGNATURE, NOT A CRYPTOGRAPHIC HASH. `h * 31 + v` is a polynomial fold; it is here to detect
## a replay that diverged, not to resist an adversary, and `recomputed_signature()` on each plane is the
## check that its running lanes never drifted from the records.

const LANE_A: int = 2166136261  ## FNV offset basis, as the first lane's seed
const LANE_B: int = 486187739   ## a second, unrelated odd seed for the second lane

static var _id_folds: Dictionary = {}  # StringName -> Vector2i(fold_a, fold_b), memoised per process


## Polynomial fold of a string into 31 bits from seed `h0`. Pure; `fold("", h0) == h0`.
static func fold(text: String, h0: int) -> int:
	var h: int = h0
	for i: int in text.length():
		h = ((h * 31) + text.unicode_at(i)) & 0x7FFFFFFF
	return h


## One lane of a coordinate-keyed record: the coordinate, then two integer payloads (a material fold and
## a wall fold for terrain; a level for water), folded from seed `h0`.
static func mix(x: int, y: int, m: int, w: int, h0: int) -> int:
	var h: int = h0
	h = ((h * 31) + x) & 0x7FFFFFFF
	h = ((h * 31) + y) & 0x7FFFFFFF
	h = ((h * 31) + m) & 0x7FFFFFFF
	h = ((h * 31) + w) & 0x7FFFFFFF
	return h


## Both lanes of a coordinate-keyed record. `m` and `w` are per-lane payload PAIRS (`.x` feeds lane A,
## `.y` lane B), which is how an `id_fold` pair plugs straight in; a scalar payload passes the same value
## in both components.
static func term(x: int, y: int, m: Vector2i, w: Vector2i) -> Vector2i:
	return Vector2i(mix(x, y, m.x, w.x, LANE_A), mix(x, y, m.y, w.y, LANE_B))


## Both lanes of a free-text record (e.g. `TileGrid`'s per-column dig extent, "dig%d:%d,%d").
static func text_term(text: String) -> Vector2i:
	return Vector2i(fold(text, LANE_A), fold(text, LANE_B))


## A material id folded into both lanes, memoised: ids are few and hashed millions of times, and
## `StringName` -> `String` conversion is the expensive part.
static func id_fold(id: StringName) -> Vector2i:
	var hit: Variant = _id_folds.get(id)
	if hit != null:
		return hit
	var pair: Vector2i = text_term(String(id))
	_id_folds[id] = pair
	return pair
