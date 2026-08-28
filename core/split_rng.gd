class_name SplitRng
extends RefCounted

## Deterministic, seeded, splittable PRNG stream. `docs/ARCHITECTURE.md` §4: "Seeded, split RNG: one
## stream per subsystem, streams are serialized state. No global random." This is the primitive; naming
## the actual per-module streams (world, terrain_gen, body, ...) is each module's job when it's built --
## this file has no knowledge of sim/'s module list, on purpose, so core/ doesn't reach up into L1.
##
## Algorithm: SplitMix64 (Vigna, 2015). Chosen for determinism auditability over statistical strength:
## it's four operations, has no internal array/table, and its "add a constant, then scramble" structure
## makes split() and next_u64() the same primitive (see split() below). It is not cryptographically
## secure and was never meant to be; nothing here needs that.
##
## GDScript ints are signed 64-bit. Every constant and intermediate value below is a raw 64-bit BIT
## PATTERN, not a magnitude -- values with the top bit set are written as their signed two's-complement
## decimal equivalent because GDScript hex literals cannot represent values >= 2^63. `BitOps.ushr()`
## (`core/bit_ops.gd`) exists because GDScript's `>>` is an arithmetic (sign-extending) shift;
## SplitMix64's mixing steps require a logical shift. Both of these were verified empirically against the
## running engine, not assumed -- see the commit message for D0005 in docs/DECISIONS_LEDGER.md.

const _GOLDEN_GAMMA: int = -7046029254386353131  # 0x9E3779B97F4A7C15
const _MUL1: int = -4658895280553007687          # 0xBF58476D1CE4E5B9
const _MUL2: int = -7723592293110705685          # 0x94D049BB133111EB
const _FNV_OFFSET: int = -3750763034362895579    # 0xCBF29CE484222325 (FNV-1a 64-bit)
const _FNV_PRIME: int = 1099511628211            # 0x100000001B3

var _root_seed: int
var _state: int


func _init(seed: int) -> void:
	_root_seed = seed
	_state = seed


## Advances the stream and returns the next 64-bit draw as a raw bit pattern (may print negative --
## that's the sign bit of an otherwise-unsigned value, not an error).
func next_u64() -> int:
	_state += _GOLDEN_GAMMA
	var z: int = _state
	z = (z ^ BitOps.ushr(z, 30)) * _MUL1
	z = (z ^ BitOps.ushr(z, 27)) * _MUL2
	z = z ^ BitOps.ushr(z, 31)
	return z


## Uniform float in [0, 1), from the top 53 bits of one draw (the double mantissa's width) --
## standard technique, and exact: dividing an exactly-representable integer by an exactly-representable
## power of two has no rounding error, so this can never round up to 1.0.
func next_float() -> float:
	var top53: int = BitOps.ushr(next_u64(), 11)
	return float(top53) / float(1 << 53)


## Uniform integer in [lo, hi_inclusive]. Built on next_float() rather than a modulo of next_u64(), which
## trades a little uniformity (float multiply-and-truncate, not rejection sampling) for simplicity -- fine
## for world generation and nothing here is adversarial or needs cryptographic-grade uniformity.
func next_range(lo: int, hi_inclusive: int) -> int:
	var span: int = hi_inclusive - lo + 1
	return lo + int(next_float() * float(span))


static func _fnv1a64(text: String) -> int:
	var h: int = _FNV_OFFSET
	for b: int in text.to_utf8_buffer():
		h = h ^ b
		h = h * _FNV_PRIME
	return h


## Deterministically derives a NAMED child stream. Keyed off this stream's ROOT seed, not its current
## draw position, so split("world") always returns the same child regardless of how many draws the
## parent has taken or when split() is called -- order-independent by construction. The child seed is
## passed through one more SplitMix64 step (rather than used as the raw XOR) so that labels differing
## by one bit don't produce correlated children.
func split(label: String) -> SplitRng:
	var child_seed: int = _root_seed ^ _fnv1a64(label)
	var mixer: SplitRng = SplitRng.new(child_seed)
	return SplitRng.new(mixer.next_u64())


## Serialized state per `docs/ARCHITECTURE.md` §4 -- a stream is its state, not wall-clock reseeded.
func get_state() -> Dictionary:
	return {"root_seed": _root_seed, "state": _state}


func set_state(saved: Dictionary) -> void:
	_root_seed = saved["root_seed"]
	_state = saved["state"]
