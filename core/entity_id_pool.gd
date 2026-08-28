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


## `generation` is masked to 32 bits before the shift, matching `index` -- explicit, not a behavior
## change: verified directly (D0048) that GDScript's `<<` on a 64-bit int already drops any bits of
## `generation` at position 32 or above when shifting left by 32 (standard 2's-complement wraparound), so
## `generation << 32` and `(generation & 0xFFFFFFFF) << 32` produce IDENTICAL results for every value
## tested, including 2^32 itself -- an explicit audit finding that this file was silently missing a mask
## turned out, on measurement, not to change any actual output. The mask stays for the same reason
## `index`'s already had one: symmetry and a reader not needing to know GDScript's shift semantics by
## heart to trust this line. The real, unrelated fact underneath the audit's finding: `generation=0` and
## `generation=2^32` DO pack to the same id either way -- a 32-bit field wrapping after 2^32 increments,
## the same documented (not hit in practice) limit this file's own header already names for `index`.
static func pack(index: int, generation: int) -> int:
	return ((generation & 0xFFFFFFFF) << 32) | (index & 0xFFFFFFFF)


static func unpack_index(id: int) -> int:
	return id & 0xFFFFFFFF


static func unpack_generation(id: int) -> int:
	return BitOps.ushr(id, 32)


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
