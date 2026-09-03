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


## The ids of `names`, lexically sorted, as a fresh typed array. Accepts any iterable of `StringName`
## (or `String`, converted) -- an `Array`, a typed array, or a `Dictionary` whose keys are the ids.
static func ids(names: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	for n: Variant in names:
		out.append(StringName(String(n)))
	out.sort_custom(less)
	return out
