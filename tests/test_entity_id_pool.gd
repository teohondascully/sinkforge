extends "res://tests/test_base.gd"

func _initialize() -> void:
	_test_pack_unpack_roundtrip()
	_test_allocate_gives_unique_valid_ids()
	_test_release_invalidates()
	_test_release_reuses_index_with_bumped_generation()
	_test_double_release_returns_false()
	_test_release_never_allocated_returns_false()
	_test_live_count()
	_test_stress_churn()
	_test_generation_wraps_at_2_32_same_as_index_does()
	_finish("entity_id_pool")


func _test_pack_unpack_roundtrip() -> void:
	var cases: Array = [[0, 0], [1, 0], [0, 1], [4294967295, 0], [0, 4294967295], [12345, 678]]
	for c: Array in cases:
		var id: int = EntityIdPool.pack(c[0], c[1])
		_check(EntityIdPool.unpack_index(id) == c[0], "unpack_index(pack(%d, %d)) == %d" % [c[0], c[1], c[0]])
		_check(EntityIdPool.unpack_generation(id) == c[1], "unpack_generation(pack(%d, %d)) == %d" % [c[0], c[1], c[1]])


func _test_allocate_gives_unique_valid_ids() -> void:
	var pool: EntityIdPool = EntityIdPool.new()
	var a: int = pool.allocate()
	var b: int = pool.allocate()
	var c: int = pool.allocate()
	_check(a != b and b != c and a != c, "three allocations are pairwise distinct")
	_check(pool.is_valid(a) and pool.is_valid(b) and pool.is_valid(c), "freshly allocated ids are valid")
	_check(EntityIdPool.unpack_index(a) == 0 and EntityIdPool.unpack_index(b) == 1 and
		EntityIdPool.unpack_index(c) == 2, "indices assigned in order when nothing is freed")


func _test_release_invalidates() -> void:
	var pool: EntityIdPool = EntityIdPool.new()
	var a: int = pool.allocate()
	_check(pool.release(a), "release() on a live id returns true")
	_check(not pool.is_valid(a), "id is invalid immediately after release")


func _test_release_reuses_index_with_bumped_generation() -> void:
	var pool: EntityIdPool = EntityIdPool.new()
	var a: int = pool.allocate()
	pool.release(a)
	var b: int = pool.allocate()
	_check(EntityIdPool.unpack_index(a) == EntityIdPool.unpack_index(b), "freed index is reused")
	_check(EntityIdPool.unpack_generation(b) == EntityIdPool.unpack_generation(a) + 1,
		"reused slot's generation is bumped by exactly one")
	_check(not pool.is_valid(a), "the stale (pre-release) id stays invalid after reallocation")
	_check(pool.is_valid(b), "the new id for the reused slot is valid")


func _test_double_release_returns_false() -> void:
	var pool: EntityIdPool = EntityIdPool.new()
	var a: int = pool.allocate()
	_check(pool.release(a), "first release() returns true")
	_check(not pool.release(a), "second release() of the same id returns false, not a crash")


func _test_release_never_allocated_returns_false() -> void:
	var pool: EntityIdPool = EntityIdPool.new()
	_check(not pool.release(EntityIdPool.pack(0, 0)), "release() on an out-of-range id returns false")
	_check(not pool.release(EntityIdPool.pack(-1, 0)), "release() on a negative index returns false")


func _test_live_count() -> void:
	var pool: EntityIdPool = EntityIdPool.new()
	var a: int = pool.allocate()
	var b: int = pool.allocate()
	pool.allocate()
	_check(pool.live_count() == 3, "live_count is 3 after three allocations")
	pool.release(a)
	_check(pool.live_count() == 2, "live_count drops to 2 after one release")
	pool.release(b)
	pool.allocate()
	_check(pool.live_count() == 2, "live_count reflects reuse: two releases, one reallocation, from three")


## Reproducible randomized churn: allocate/release driven by SplitRng so a failure here is replayable from
## the printed seed. Tracks the expected live set independently (a Dictionary keyed by id) and checks
## the pool agrees with it after every step, rather than asserting a specific final count.
func _test_stress_churn() -> void:
	var seed: int = 20260826
	var rng: SplitRng = SplitRng.new(seed)
	var pool: EntityIdPool = EntityIdPool.new()
	var live: Dictionary = {}
	var steps: int = 2000
	for i in steps:
		var draw: int = rng.next_u64()
		var do_allocate: bool = live.is_empty() or (draw & 1) == 0
		if do_allocate:
			var id: int = pool.allocate()
			live[id] = true
		else:
			var keys: Array = live.keys()
			var pick: int = keys[BitOps.ushr(draw, 1) % keys.size()]
			live.erase(pick)
			pool.release(pick)
	var all_live_valid: bool = true
	for id: int in live:
		if not pool.is_valid(id):
			all_live_valid = false
			break
	_check(all_live_valid, "after %d randomized ops (seed %d), every id this test believes live is valid" %
		[steps, seed])
	_check(pool.live_count() == live.size(), "pool.live_count() agrees with the independently tracked live set")


## D0048. An external audit flagged `pack()` for not masking `generation` to 32 bits before shifting.
## Measured directly before trusting that framing (CLAUDE.md: verify a numeric claim against actual tool
## output): GDScript's `<<` on a 64-bit int already drops any bits of `generation` at position 32+ when
## shifted left by 32 (2's-complement wraparound), so an explicit mask changes NO actual output --
## `pack(index, g)` and `pack(index, g & 0xFFFFFFFF)` are bit-identical for every `g` tested, including
## exactly `2^32`. What the audit's finding correctly points at, independent of the mask: `generation=0`
## and `generation=2^32` DO pack to the same id -- a 32-bit field wrapping after 2^32 increments, the
## same already-documented (never observed) limit this file's own header states for `index`. This test
## pins that real, narrower fact, not the "missing mask" framing the mask itself doesn't change.
func _test_generation_wraps_at_2_32_same_as_index_does() -> void:
	var index: int = 7
	var id_gen0: int = EntityIdPool.pack(index, 0)
	var id_gen_2_32: int = EntityIdPool.pack(index, 1 << 32)
	_check(id_gen0 == id_gen_2_32,
		"generation 0 and generation 2^32 pack to the SAME id at a given index -- a 32-bit field wrapping, not a bug the mask changes (got %d and %d)" %
		[id_gen0, id_gen_2_32])
	_check(EntityIdPool.unpack_generation(id_gen_2_32) == 0,
		"2^32 unpacks as generation 0, confirming the wrap is mod 2^32 (got %d)" %
		EntityIdPool.unpack_generation(id_gen_2_32))
	var id_gen1: int = EntityIdPool.pack(index, (1 << 32) + 1)
	_check(EntityIdPool.unpack_generation(id_gen1) == 1,
		"2^32 + 1 unpacks as generation 1, same wraparound as index already has at 2^32 (got %d)" %
		EntityIdPool.unpack_generation(id_gen1))
