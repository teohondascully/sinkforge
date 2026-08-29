#!/usr/bin/env bash
# Runs one tests/test_*.gd (or fixture_*.gd) suite under Godot and treats an engine-level `SCRIPT ERROR:`
# in its output as an unconditional failure, on top of the process's own exit code.
#
# docs/DECISIONS_LEDGER.md D0115/D0116: `test_base.gd`'s own PASS/FAIL bookkeeping can print "ALL PASS"
# and exit 0 even after a real runtime crash mid-suite. GDScript has no try/catch -- an uncaught runtime
# error (out-of-bounds Array read, null property access, ...) does not raise anything `_check()` can see;
# it logs a `SCRIPT ERROR:` line, the crashing expression evaluates to a type-default value, and execution
# continues from the very next line in the SAME function -- so a crash inside ANY called function (which
# is every real `_test_*()` function in this project's suites; `_initialize()` itself is always just a
# flat list of calls to them) is invisible to `_check`/`_finish`'s own counters. (The one exception,
# confirmed separately and NOT this script's subject: a crash directly inside `_initialize()` itself hangs
# instead of continuing -- already mitigated by this project's own CI `timeout-minutes`, and a real, loud
# failure, not a false green.) `tests/fixture_harness_crash_probe.gd` is a permanent, reproducible case of
# the false-green mode; `tools/test_run_gd_test.sh` proves this script catches it and does NOT falsely
# flag a suite that legitimately calls `push_error()` as part of its own real, passing behavior.
#
# D0149 (queue D2): a SECOND masked-crash shape, sibling to the one above, matched `SCRIPT ERROR:` but not
# an ENGINE-level `ERROR:` -- confirmed empirically (`tests/fixture_harness_crash_probe_engine_error.gd`)
# that an unguarded native-call failure (`Array.remove_at()` with an out-of-range index) prints a bare
# `ERROR: ...` line (NOT `SCRIPT ERROR:`) followed by an `at: remove_at (core/variant/array.cpp:512)` line,
# execution continuing normally afterward exactly like the original SCRIPT ERROR: case -- so this shape
# passed straight through the detector below, which checked only for the `SCRIPT ERROR:` prefix. The one
# thing that tells this apart from a DELIBERATE `push_error()`/`push_warning()` call (which this codebase
# uses on purpose, in several suites, as real passing behavior) is that `push_error()` ALSO prints a bare
# `ERROR:` line with its own `at: push_error (core/variant/variant_utility.cpp:1024)` line -- confirmed by
# the same probing, not assumed. The two cases are the same first-line shape and differ only in the `at:`
# line's own function name.
#
# Usage: tools/run_gd_test.sh <godot-binary> <res://path/to/test_x.gd>
#
# Exits nonzero if: the process itself exits nonzero, OR "SCRIPT ERROR:" appears anywhere in its combined
# output, OR a bare "ERROR:" line's own "at:" line names a function other than push_error/push_warning
# (an engine-level crash masquerading as a deliberate log line), OR the suite never printed its own
# "ALL PASS" line (crashed before ever reaching _finish()).

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

GODOT_BIN="${1:?usage: run_gd_test.sh <godot-binary> <res://path/to/test_x.gd>}"
SCRIPT_PATH="${2:?usage: run_gd_test.sh <godot-binary> <res://path/to/test_x.gd>}"

# --- the detector has to work, checked fresh every run, not trusted from when this file was written ---
# Same reasoning as tools/check_trailers.sh's own positive/negative control: a pattern that stopped
# matching (a typo, a changed grep, a locale that broke the character class) would report a clean run
# forever, in exactly the words a clean run produces. Confirmed empirically (docs/DECISIONS_LEDGER.md
# D0116) that `push_error()`/`push_warning()` print "ERROR:"/"WARNING:", never "SCRIPT ERROR:" -- this
# codebase calls `push_error()` deliberately, as normal PASSING behavior, in several suites
# (`sim/invariants`, `test_cave_geometry.gd`, `test_fixed_point.gd`'s `Fx.div` guard,
# `docs/ARCHITECTURE.md` §9's "log in release"), so the negative control below is not decorative.
if ! printf '%s\n' "SCRIPT ERROR: Out of bounds get index" | grep -q "SCRIPT ERROR:"; then
	echo "run_gd_test: FAIL - the SCRIPT ERROR detector does not fire on a known-bad line (positive control)" >&2
	echo "run_gd_test: not reporting a verdict on $SCRIPT_PATH; the instrument itself is broken" >&2
	exit 1
fi
if printf '%s\n' "ERROR: a deliberate push_error call" | grep -q "SCRIPT ERROR:"; then
	echo "run_gd_test: FAIL - the SCRIPT ERROR detector fires on a plain push_error()/push_warning() line (negative control)" >&2
	echo "run_gd_test: not reporting a verdict on $SCRIPT_PATH; the instrument itself is broken" >&2
	exit 1
fi

# --- D0149's own detector has to work too, checked fresh every run for the same reason as above ---
ENGINE_CRASH_SAMPLE=$'ERROR: The calculated index 99 is out of bounds (the array has 3 elements). Leaving the array untouched.\n   at: remove_at (core/variant/array.cpp:512)'
PUSH_ERROR_SAMPLE=$'ERROR: a deliberate push_error call\n   at: push_error (core/variant/variant_utility.cpp:1024)'
if ! printf '%s\n' "$ENGINE_CRASH_SAMPLE" | grep -A1 "^ERROR: " | grep -E "^[[:space:]]*at: " | grep -qv "^[[:space:]]*at: push_error "; then
	echo "run_gd_test: FAIL - the engine-ERROR detector does not fire on a known-bad line (positive control)" >&2
	echo "run_gd_test: not reporting a verdict on $SCRIPT_PATH; the instrument itself is broken" >&2
	exit 1
fi
if printf '%s\n' "$PUSH_ERROR_SAMPLE" | grep -A1 "^ERROR: " | grep -E "^[[:space:]]*at: " | grep -qv "^[[:space:]]*at: push_error "; then
	echo "run_gd_test: FAIL - the engine-ERROR detector fires on a real push_error() call (negative control)" >&2
	echo "run_gd_test: not reporting a verdict on $SCRIPT_PATH; the instrument itself is broken" >&2
	exit 1
fi

OUT="$("$GODOT_BIN" --headless --path . --script "$SCRIPT_PATH" 2>&1)"
GODOT_EXIT=$?

printf '%s\n' "$OUT"

fail=0
if [ "$GODOT_EXIT" -ne 0 ]; then
	echo "run_gd_test: FAIL - $SCRIPT_PATH exited $GODOT_EXIT" >&2
	fail=1
fi
if printf '%s\n' "$OUT" | grep -q "SCRIPT ERROR:"; then
	echo "run_gd_test: FAIL - $SCRIPT_PATH printed a SCRIPT ERROR mid-run (process exit was $GODOT_EXIT -- this is the masked-crash class D0115 found, not an ordinary assertion failure)" >&2
	fail=1
fi
if printf '%s\n' "$OUT" | grep -A1 "^ERROR: " | grep -E "^[[:space:]]*at: " | grep -qv "^[[:space:]]*at: push_error "; then
	echo "run_gd_test: FAIL - $SCRIPT_PATH printed an engine-level ERROR: not from push_error() (process exit was $GODOT_EXIT -- the D0149 masked-crash sibling: a native call failed and execution kept going, same class as SCRIPT ERROR: but never prefixed that way)" >&2
	fail=1
fi
if ! printf '%s\n' "$OUT" | grep -q "^ALL PASS"; then
	echo "run_gd_test: FAIL - $SCRIPT_PATH never printed its own ALL PASS line" >&2
	fail=1
fi

if [ "$fail" -eq 0 ]; then
	echo "run_gd_test: PASS - $SCRIPT_PATH"
fi
exit $fail
