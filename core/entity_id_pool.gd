class_name EntityIdPool
extends RefCounted

## Generational-index entity IDs. `docs/ARCHITECTURE.md` §4: "Generational-index entity IDs. Never
## pointers, never bare array positions." An id is a single packed 64-bit int -- (generation << 32) |
## index -- rather than a two-field object, so ids compare with plain `==`, hash as plain dictionary
## keys, and serialize as one integer. That only works because GDScript's `int` is 64-bit; each field
## gets 32 bits, which is not a limit this project will hit (2^32 live entities, or 2^32 reuses of one
## slot, in a single run).
##
## The pool owns index reuse: freeing a slot bumps its generation before the index goes back on the
## free list, so an id captured before the free is stale after -- `is_valid()` catches use-after-free
## and double-free without either crashing.

var _generations: PackedInt64Array = PackedInt64Array()
var _free_indices: Array[int] = []


## Logical (zero-fill) right shift -- see `core/split_rng.gd` for why GDScript's `>>` needs this.
static func _ushr(x: int, n: int) -> int:
	if n <= 0:
		return x
	if n >= 64:
		return 0
	return (x >> n) & ((1 << (64 - n)) - 1)


static func pack(index: int, generation: int) -> int:
	return (generation << 32) | (index & 0xFFFFFFFF)


static func unpack_index(id: int) -> int:
	return id & 0xFFFFFFFF


static func unpack_generation(id: int) -> int:
	return _ushr(id, 32)


func allocate() -> int:
	if not _free_indices.is_empty():
		var index: int = _free_indices.pop_back()
		return pack(index, _generations[index])
	var index: int = _generations.size()
	_generations.append(0)
	return pack(index, 0)


## Returns false, without side effects, for an id that is already stale or was never allocated --
## a double-release is caught here rather than corrupting the free list. Named `release`, not `free`:
## `free` collides with `Object.free()`, which every GDScript class inherits.
func release(id: int) -> bool:
	if not is_valid(id):
		return false
	var index: int = unpack_index(id)
	_generations[index] += 1
	_free_indices.append(index)
	return true


func is_valid(id: int) -> bool:
	var index: int = unpack_index(id)
	if index < 0 or index >= _generations.size():
		return false
	return _generations[index] == unpack_generation(id)


func live_count() -> int:
	return _generations.size() - _free_indices.size()
