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
var _passes: int = 0


## THE COUNT IS PART OF THE VERDICT, ALWAYS (lifted from `legacy/tools/check_base.gd:145-160` in A' step 0,
## D0343). A green that does not say how many properties it stood on is a claim with its evidence withheld,
## and a green that asserted NOTHING is refused outright: nothing downstream can tell it from a real one --
## both are exit 0 over a log with no FAIL line -- so it has to be loud here. A suite whose every `_test_*`
## returned before its first `_check` has reached its verdict without testing anything, which is the house
## defect (an instrument that cannot register its subject) arriving inside the instrument.
## `tools/test_test_base.sh` is the mutation test: a suite with zero `_check` calls must print VACUOUS and
## exit non-zero and must never print ALL PASS.
##
## `quit()` DOES NOT RETURN. It asks the main loop to stop at the end of the current iteration and execution
## carries straight on through this function, so the `return` after the refusal is load-bearing: without
## it the refusal would fall through to the ALL PASS line and exit 0 anyway. Legacy's own probe of this
## guard hit exactly that -- the guard against a green that asserted nothing was itself exiting green.
func _finish(suite: String) -> void:
	if _failures == 0 and _passes == 0:
		printerr("VACUOUS -- %s made NO ASSERTIONS and reached its verdict anyway; exit 0 would claim a"
			% suite + " property nobody tested. Every _test_* returned before its first _check, or the"
			+ " suite has none.")
		quit(1)
		return
	if _failures == 0:
		print("ALL PASS (%s) -- %d asserted" % [suite, _passes])
		quit(0)
	else:
		printerr("%d FAILURE(S) of %d asserted (%s)" % [_failures, _failures + _passes, suite])
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passes += 1
		print("  PASS: %s" % label)
	else:
		_failures += 1
		printerr("  FAIL: %s" % label)


## THE VACUOUS-ASSERTION GUARD (D0245). Assert `condition` over a population of `count` items, and FAIL
## when that population is EMPTY -- even if `condition` is true.
##
## This exists because the same defect has now landed four separate times in this repository, each time
## in a test written by someone being careful:
##
##   * `test_world_view` asserted an observation window was "non-empty" and PASSED over a window that was
##     entirely margin, because a Godot node is not in the tree until a process frame has passed.
##   * `test_sky_painter`'s starfield would have passed every property check with all 42 stars culled
##     below the horizon by a wrong rescale.
##   * `test_reveal_spawn_bounds` needed a `checked > 0` guard bolted on after the fact (D0229).
##   * `test_interface`'s first fixture used a legacy material id, so the charge path it was written to
##     exercise broke on tick one and the suite reported success.
##
## They share one shape: **`for x in EMPTY: assert(p(x))` is true by construction**, and so is every
## aggregate over an empty collection -- `all()`, `max() == expected`, `count == 0`. The assertion is not
## wrong; it simply has no subject, which is this project's dominant failure class arriving inside the
## instrument meant to catch it.
##
## THE DIRECTION RULE, and the reason this is not simply sprinkled everywhere a loop appears. Only
## assertions that PASS on an empty population need it. `all_above == count`, `violations == 0`,
## `unmoved.is_empty()`, `max <= limit` -- all true over nothing. Their mirrors are already safe:
## `stars.size() > 20`, `gaps.size() > 3`, `found >= 1` FAIL on an empty population by construction, and
## wrapping one of those adds a guard that can never fire, which is how an idiom becomes decoration.
## Sort the assertion by direction first; if emptiness would make it RED, leave it as `_check`.
##
## Pass a COUNTED population, not a computed one. `SEEDS * SITES.size()` is a product of two constants and
## cannot register a loop body that never executed -- increment a counter inside the loop instead.
##
## Use it wherever an assertion ranges over something that could be empty. It cannot help with a scalar.
func _check_over(count: int, condition: bool, label: String) -> void:
	var verdict: Array = over(count, condition, label)
	_check(bool(verdict[0]), String(verdict[1]))


## `_check_over`'s decision, as a PURE function returning `[ok, label]`.
##
## Static and separate so the guard can be mutation-tested in-process rather than trusted: a guard that
## has never been observed refusing an empty population is exactly the kind of check `docs/QUALITY.md` §2
## says is not a check. `tests/test_empty_population_guard.gd` poses all three branches, and the one that
## matters is `over(0, true, ...)` -- a condition that WOULD have passed, refused because it had nothing
## to range over.
static func over(count: int, condition: bool, label: String) -> Array:
	if count <= 0:
		return [false, "VACUOUS -- \"%s\" was asserted over %d item(s), which is true by construction "
			% [label, count] + "whatever the code does. The population is the bug, not the assertion."]
	return [condition, "%s (over %d item(s))" % [label, count]]


## How many ticks a `fixture_body_fuzz_probe.gd` run actually simulated, read off its own FUZZ_SUMMARY
## line. Returns 0 when the line is absent, malformed, or reports nothing -- all three of which mean the
## same thing to a caller: there is no population, so no verdict about the sweep is available.
##
## This exists because the fuzz suites' real assertions are `counts[kind] == 0` over the probe's whole
## output, and **a probe that simulated nothing satisfies every one of them**. The guard those suites had
## was `summary_line != ""`, which is a PRESENCE check: a summary line reading `total_ticks=0` is present,
## and passes it. Shared here rather than copied into each suite because
## `tools/quality_check/duplication.py` would find two identical copies byte-for-byte after normalization,
## which is exactly why `_flat_grid` below lives here too (D0102).
static func fuzz_total_ticks(combined: String) -> int:
	for line: String in combined.split("\n"):
		if not line.begins_with("FUZZ_SUMMARY"):
			continue
		for field: String in line.split(" "):
			if field.begins_with("total_ticks="):
				return int(field.trim_prefix("total_ticks="))
	return 0


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


## A uniform grid of one material, `size` cells square. Lives here rather than in a suite for the same
## reason `_flat_grid` above does (D0102): `test_mining.gd` and `test_mining_bite.gd` both need the
## identical fixture, and two private copies is exactly the duplication that check found byte-for-byte.
func _solid_grid(material: StringName, size: int = 64) -> TileGrid:
	var grid: TileGrid = TileGrid.new(size, size, 1)
	for col: int in size:
		for row: int in size:
			grid.set_material(Vector2i(col, row), material)
	return grid


## Body centre placed exactly on a terrain cell's centre, so every distance in a mining test is a clean
## multiple of the cell size rather than an offset that has to be reasoned about at each assertion.
func _at_cell_centre(cell: Vector2i) -> Vector2i:
	var cell_px: int = Heightfield.TERRAIN_CELL_PX * Fx.SCALE
	return Vector2i(cell.x * cell_px + cell_px / 2, cell.y * cell_px + cell_px / 2)


## Holds MINE on one cell until it breaks, and returns how many ticks that took (-1 if it never did).
func _ticks_to_break(mining: Mining, grid: TileGrid, body: Vector2i, cell: Vector2i, cap: int) -> int:
	for t: int in range(1, cap + 1):
		if mining.mine(grid, body.x, body.y, cell, true) != Mining.NO_CELL:
			return t
	return -1


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
