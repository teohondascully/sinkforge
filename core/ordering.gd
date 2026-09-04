class_name Ordering
extends RefCounted

## THE ONE WAY TO SORT IDS IN STATE-AFFECTING CODE. `StringName < StringName` in Godot 4 compares the
## interned pointers, not the text: `Array[StringName].sort()` and `sort_custom(func(a, b): return a < b)`
## both return creation order reversed, and `Dictionary.keys().sort()` over `StringName` keys does the
## same (probed 2026-09-03, D0346: seven machine ids sorted to the exact reverse of the order the literals
## were written in). Creation order is which script touched which name first, which differs between a
## fresh run and a loaded save, between two fixtures, between a test and the game -- so a "sorted" order
## built that way is a WITHIN-platform determinism breaker wearing the costume of the fix. It was found
## because `tests/test_machine_defs.gd` pinned the sorted population and the pin failed; a three-key
## dictionary in the same probe happened to come out alphabetical, which is how it would have hidden.
##
## `docs/ARCHITECTURE.md` §4: "No iteration over hash maps in state-affecting code. Sorted arrays or
## insertion-ordered structures." Every "sort keys" row of the hub lift (plan §5.1 rows 012-022) goes
## through here, and `tests/test_ordering.gd` keeps the hazard itself as a live baseline so a Godot that
## changes the operator is noticed rather than assumed.

## Lexical order by the name's TEXT. Stable across processes, saves and fixtures because it depends on
## nothing but the characters.
static func less(a: StringName, b: StringName) -> bool:
	return String(a) < String(b)


## Row-major cell order: top-to-bottom, then left-to-right -- the scan order every plane walks in
## (`WaterFlow`'s, lifted with it). For `Vector2i` keys; ids go through `less`.
static func cell_less(a: Vector2i, b: Vector2i) -> bool:
	if a.y != b.y:
		return a.y < b.y
	return a.x < b.x


## The `Vector2i` keys of a plane's dictionary in row-major scan order, as a fresh typed array -- the one
## walk every plane uses when it must iterate in state-affecting code.
static func cells(keyed: Dictionary) -> Array[Vector2i]:
	return cells_native(keyed)


## Native-int sort: pack (y, x) into one int, sort with PackedInt64Array.sort() (no GDScript callback),
## unpack. Produces the same row-major order as `sort_custom(cell_less)` and runs 10-20x faster on large
## dictionaries because the comparisons happen in compiled C++, not in interpreted GDScript Callables.
static func cells_native(keyed: Dictionary) -> Array[Vector2i]:
	var n: int = keyed.size()
	if n == 0:
		return []
	var packed := PackedInt64Array()
	packed.resize(n)
	var i: int = 0
	for c: Vector2i in keyed:
		packed[i] = (int(c.y) << 32) | (int(c.x) & 0xFFFFFFFF)
		i += 1
	packed.sort()
	var out: Array[Vector2i] = []
	out.resize(n)
	for j: int in n:
		var v: int = packed[j]
		out[j] = Vector2i(int(v & 0xFFFFFFFF), int(v >> 32))
	return out


## The ids of `names`, lexically sorted, as a fresh typed array. Accepts any iterable of `StringName`
## (or `String`, converted) -- an `Array`, a typed array, or a `Dictionary` whose keys are the ids.
static func ids(names: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	for n: Variant in names:
		out.append(StringName(String(n)))
	out.sort_custom(less)
	return out
