extends SceneTree

## Shared base for the headless test suites (tests/test_*.gd). Adapted from `legacy/tests/test_base.gd`'s
## harness convention -- kept `_check`/`_finish` and the generic `_canon` signature helper, dropped
## everything tied to the pre-pivot `FactorySim`/`SaveGame` types, which don't exist in this codebase.
##
## Suites extend this BY PATH (`extends "res://tests/test_base.gd"`), run their `_test_*` methods from
## `_initialize()`, then call `_finish()`.
##
## Run a suite: godot --headless --path . --script res://tests/test_<subject>.gd
## Exits 0 on all-pass, non-zero on any failure.

var _failures: int = 0


func _finish(suite: String) -> void:
	if _failures == 0:
		print("ALL PASS (%s)" % suite)
		quit(0)
	else:
		printerr("%d FAILURE(S) (%s)" % [_failures, suite])
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


## Canonical string signature of any Variant -- dictionary keys sorted so the signature is content-based
## and insertion-order-proof. Used to compare two captured states for exact equality without caring how
## either dictionary was built up.
func _canon(v: Variant) -> String:
	match typeof(v):
		TYPE_DICTIONARY:
			var d: Dictionary = v
			var keys: Array = d.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var parts: PackedStringArray = []
			for k: Variant in keys:
				parts.append("%s=%s" % [str(k), _canon(d[k])])
			return "{%s}" % ",".join(parts)
		TYPE_ARRAY:
			var parts: PackedStringArray = []
			for e: Variant in (v as Array):
				parts.append(_canon(e))
			return "[%s]" % ",".join(parts)
		_:
			return str(v)
