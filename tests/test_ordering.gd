extends "res://tests/test_base.gd"

## `core/ordering.gd`: ids sort by TEXT, never by pointer (D0346). The first test is the hazard itself,
## kept live the way `tools/test_run_gd_test.sh` keeps D0115's baseline: if a future Godot makes
## `StringName <` lexical, this fails and says so, rather than leaving a helper nobody can explain.

const IDS: Array[StringName] = [&"pump", &"drill", &"conduit", &"winch_head", &"lift", &"blast_furnace", &"torch"]
const LEXICAL: Array[StringName] = [&"blast_furnace", &"conduit", &"drill", &"lift", &"pump", &"torch", &"winch_head"]


func _initialize() -> void:
	_test_the_hazard_is_real_stringname_sort_is_not_lexical()
	_test_ordering_ids_is_lexical_from_every_input_shape()
	_test_less_is_a_strict_total_order_over_text()
	_finish("ordering")


func _test_the_hazard_is_real_stringname_sort_is_not_lexical() -> void:
	var pointer_sorted: Array[StringName] = IDS.duplicate()
	pointer_sorted.sort()
	_check(pointer_sorted != LEXICAL,
		"BASELINE (D0346): Array[StringName].sort() is NOT lexical on this engine (got %s) -- if this ever fails, Godot changed StringName's operator< and this file's header needs rewriting, not deleting" % str(pointer_sorted))
	var custom_sorted: Array[StringName] = IDS.duplicate()
	custom_sorted.sort_custom(func(a: StringName, b: StringName) -> bool: return a < b)
	_check(custom_sorted == pointer_sorted, "sort_custom with the bare < operator gives the same non-lexical order (it is the same comparison)")
	_check((&"pump" < &"drill") != ("pump" < "drill") or pointer_sorted != LEXICAL,
		"at least one pair compares differently as StringName than as String")


func _test_ordering_ids_is_lexical_from_every_input_shape() -> void:
	_check(Ordering.ids(IDS) == LEXICAL, "from a typed Array[StringName]: lexical (got %s)" % str(Ordering.ids(IDS)))
	var untyped: Array = [&"pump", "drill", &"conduit", "winch_head", &"lift", &"blast_furnace", &"torch"]
	_check(Ordering.ids(untyped) == LEXICAL, "from a mixed String/StringName Array: lexical, all StringName")
	var dict: Dictionary = {}
	for id: StringName in IDS:
		dict[id] = 1
	_check(Ordering.ids(dict) == LEXICAL, "from a Dictionary's keys: lexical")
	_check(Ordering.ids(dict.keys()) == LEXICAL, "from dict.keys(): lexical")
	var empty: Array[StringName] = Ordering.ids([])
	_check(empty.is_empty(), "from nothing: an empty typed array, not a crash")
	var original: Array[StringName] = IDS.duplicate()
	Ordering.ids(original)
	_check(original == IDS, "the input is not sorted in place")


func _test_less_is_a_strict_total_order_over_text() -> void:
	_check(Ordering.less(&"a", &"b") and not Ordering.less(&"b", &"a") and not Ordering.less(&"a", &"a"),
		"less is strict: a<b, not b<a, not a<a")
	_check(Ordering.less(&"iron", &"iron_ingot") and Ordering.less(&"ingot", &"iron"),
		"prefix sorts first, and 'ingot' < 'iron' (the ids the hub actually compares)")
	var pairs: int = 0
	var consistent: int = 0
	for a: StringName in IDS:
		for b: StringName in IDS:
			pairs += 1
			if Ordering.less(a, b) == (String(a) < String(b)):
				consistent += 1
	_check_over(pairs, consistent == pairs, "less agrees with String comparison on all %d ordered pairs of the machine ids" % pairs)
