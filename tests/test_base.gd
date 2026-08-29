extends SceneTree

## Shared base for the headless test suites (tests/test_*.gd). Adapted from `legacy/tests/test_base.gd`'s
## harness convention -- kept `_check`/`_finish` and the generic `_canon` signature helper, dropped
## everything tied to the pre-pivot `FactorySim`/`SaveGame` types, which don't exist in this codebase.
##
## Suites extend this BY PATH (`extends "res://tests/test_base.gd"`), run their `_test_*` methods from
## `_initialize()`, then call `_finish()`.
##
## Run a suite: tools/run_gd_test.sh <godot-binary> res://tests/test_<subject>.gd
## Exits 0 on all-pass, non-zero on any failure -- but NOT if invoked as a bare
## `godot --headless --path . --script ...`: `_finish()` can print "ALL PASS" and exit 0 over a suite
## that crashed mid-run (`docs/DECISIONS_LEDGER.md` D0115), because GDScript has no try/catch and a
## runtime error inside a called `_test_*()` function is invisible to `_check()`'s own counters.
## `tools/run_gd_test.sh` (D0116) is the real exit-0 guarantee this file's own bookkeeping cannot make
## alone -- use it, not the bare invocation, for anything whose result will be trusted.

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


## A flat `hardrock` floor at `floor_row`, `width` columns wide, with 2 columns of margin on either
## side and 5 rows of headroom above. Moved here 2026-08-28 (`docs/DECISIONS_LEDGER.md` D0102) from
## `test_body.gd`/`test_heightfield.gd`, which each defined an identical private copy independently --
## `tools/quality_check/duplication.py`'s first whole-tree run found the two byte-for-byte after
## normalization. Both suites already `extend` this file by path, so this needed no new call-site
## change -- only the two duplicate definitions came out.
func _flat_grid(floor_row: int, width: int) -> TileGrid:
	var grid: TileGrid = TileGrid.new(width, floor_row + 5, 1)
	for col: int in range(-2, width + 2):
		for row: int in range(floor_row, floor_row + 3):
			grid.set_material(Vector2i(col, row), &"hardrock")
	return grid


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
