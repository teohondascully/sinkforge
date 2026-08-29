extends "res://tests/test_base.gd"

## Stage 2 (`ONBOARDING.md`): replay_determinism_test must exist and pass before there is a sim worth
## testing, because retrofitting determinism is much harder than maintaining it. `TrivialStub` below is
## NOT `sim/` and never will be -- it exists only to prove the replay-and-hash mechanism itself (run a
## recorded input log twice from one seed, hash state every 100 ticks, assert identical) before there is
## a real sim to run it against. `docs/ARCHITECTURE.md` §4's actual requirement is that a real
## `replay_determinism_test` exists once `sim/` and `harness/` do -- this file's stub is throwaway
## scaffolding for that day, not a foundation to build on.
##
## **That day arrived (D0165, queue #2 Part G): `docs/QUALITY.md` gate 8's own subject is now
## `tests/test_shaft_replay_determinism.gd`** -- a real `ShaftGenerator`+`TileGrid`+`Body` sim run,
## replayed across two separate OS processes. This file stays as a standing MECHANISM check for the
## hash-and-replay plumbing itself (does re-running the SAME recorded input from the SAME seed twice
## produce identical hashes at all), not as gate 8's own evidence -- confirmed by direct test, not
## assumed: moving `sim/` out of the project tree entirely leaves this file GREEN (it never touches
## `sim/`) while the real test goes RED, exactly the contrast this queue asked for.
##
## The stub exercises all three `core/` primitives together (a handful of particles with `Fx`
## position/velocity, spawned and despawned through an `EntityIdPool`, perturbed each tick by a
## `SplitRng` stream) so the replay check has real, varied, non-trivial state to hash -- not because the
## particles mean anything.

const TICKS: int = 20000
const HASH_INTERVAL: int = 100
const SEED: int = 20260826


class TrivialStub:
	extends RefCounted

	var rng: SplitRng
	var pool: EntityIdPool
	var positions: Dictionary = {}   # id: int -> [x, y] Array[int] of Fx values
	var velocities: Dictionary = {}  # id: int -> [vx, vy] Array[int] of Fx values

	func _init(seed: int) -> void:
		rng = SplitRng.new(seed)
		pool = EntityIdPool.new()

	func _sorted_ids() -> Array:
		var ids: Array = positions.keys()
		ids.sort()
		return ids

	func _spawn() -> void:
		var id: int = pool.allocate()
		var zero: Array = [Fx.from_int(0), Fx.from_int(0)]
		positions[id] = zero.duplicate()
		velocities[id] = zero.duplicate()

	func _despawn_oldest() -> void:
		var ids: Array = _sorted_ids()
		if ids.is_empty():
			return
		var id: int = ids[0]
		positions.erase(id)
		velocities.erase(id)
		pool.release(id)

	## Small deterministic perturbation in [-100, 100] raw Fx units, non-negative-masked before `%` so
	## the result doesn't depend on GDScript's negative-modulo behavior.
	func _perturbation() -> int:
		var raw: int = rng.next_u64() & 0x7FFFFFFFFFFFFFFF
		return (raw % 201) - 100

	func tick(input_event: int) -> void:
		if input_event == 0:
			_spawn()
		elif input_event == 1:
			_despawn_oldest()
		for id: int in _sorted_ids():
			var vel: Array = velocities[id]
			vel[0] = Fx.add(vel[0], _perturbation())
			vel[1] = Fx.add(vel[1], _perturbation())
			var pos: Array = positions[id]
			pos[0] = Fx.add(pos[0], vel[0])
			pos[1] = Fx.add(pos[1], vel[1])

	## Canonical, insertion-order-proof state signature -- sorted by id, same shape as
	## `tests/test_base.gd`'s `_canon()` but built directly since this state is already flat.
	func state_signature() -> String:
		var parts: PackedStringArray = []
		for id: int in _sorted_ids():
			var pos: Array = positions[id]
			var vel: Array = velocities[id]
			parts.append("%d:%d,%d,%d,%d" % [id, pos[0], pos[1], vel[0], vel[1]])
		return "|".join(parts)


func _build_input_log() -> Array:
	# Fixed, deterministic pattern -- not derived from the stub's own RNG stream, so "recorded input"
	# and "sim-internal randomness" stay two separate concepts even in a stub this small.
	var log: Array = []
	for i: int in TICKS:
		if i % 37 == 0:
			log.append(0)  # spawn
		elif i % 53 == 0:
			log.append(1)  # despawn
		else:
			log.append(2)  # no-op
	return log


func _run(input_log: Array) -> Array:
	var stub: TrivialStub = TrivialStub.new(SEED)
	var hashes: Array = []
	for i: int in TICKS:
		stub.tick(input_log[i])
		if (i + 1) % HASH_INTERVAL == 0:
			hashes.append(stub.state_signature().hash())
	return hashes


func _initialize() -> void:
	_test_replay_is_bit_identical()
	_test_stub_state_actually_varies()
	_finish("replay_determinism")


func _test_replay_is_bit_identical() -> void:
	var input_log: Array = _build_input_log()
	var hashes_a: Array = _run(input_log)
	var hashes_b: Array = _run(input_log)

	_check(hashes_a.size() == int(TICKS / HASH_INTERVAL),
		"produced %d checkpoint hashes (expected %d)" % [hashes_a.size(), TICKS / HASH_INTERVAL])
	_check(hashes_a.size() == hashes_b.size(), "both runs produced the same number of checkpoints")

	var mismatch_at: int = -1
	for i: int in hashes_a.size():
		if hashes_a[i] != hashes_b[i]:
			mismatch_at = i
			break
	_check(mismatch_at == -1,
		"all %d checkpoint hashes identical across two runs from the same seed (first mismatch at checkpoint %d)" %
		[hashes_a.size(), mismatch_at])


## A replay check that never actually varies state would pass trivially. Confirms the stub produces at
## least a few distinct checkpoint hashes, so "all identical" above is evidence of determinism, not of
## a frozen no-op stub -- the same principle `docs/QUALITY.md` §2 applies to every other check here.
func _test_stub_state_actually_varies() -> void:
	var hashes: Array = _run(_build_input_log())
	var distinct: Dictionary = {}
	for h: int in hashes:
		distinct[h] = true
	_check(distinct.size() > 1, "checkpoint hashes are not all identical to each other (%d distinct of %d)" %
		[distinct.size(), hashes.size()])
