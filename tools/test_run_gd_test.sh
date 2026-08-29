#!/usr/bin/env bash
# Mutation test for tools/run_gd_test.sh, itself the D0116 fix for D0115's masked-crash finding.
#
#   bash tools/test_run_gd_test.sh
#
# The director's own bar for trusting this fix: "add a test that forces a mid-test crash and asserts the
# harness reports failure and exits nonzero. Until that test exists and is observed failing on the
# pre-fix harness, the fix is not trusted." This script is that test. It asserts, in order:
#
#   1. The PRE-FIX baseline still reproduces: the bare, unwrapped invocation
#      (`godot --headless --path . --script`) on `tests/fixture_harness_crash_probe.gd` exits 0 and
#      prints "ALL PASS" despite a real mid-run SCRIPT ERROR -- this is D0115 itself, kept as a live,
#      permanent assertion (not a one-time note) so a future Godot version that changes this behavior is
#      noticed rather than assumed.
#   2. The FIX: the same probe run THROUGH `tools/run_gd_test.sh` exits non-zero and its own failure
#      message names the SCRIPT ERROR class.
#   3. The negative control: a real, legitimately-passing suite that deliberately calls `push_error()` as
#      part of its own normal behavior (`tests/test_fixed_point.gd`) still exits 0 through the wrapper --
#      the fix must not turn every push_error()-using suite red.
#   4-6. D0149's own sibling defect, same bar, same shape: a masked crash that prints a bare `ERROR:` (not
#      `SCRIPT ERROR:`) from an unguarded native call (`Array.remove_at()` out of range,
#      `tests/fixture_harness_crash_probe_engine_error.gd`) -- pre-fix baseline reproduces, the fix
#      catches it and names the right class, and a second real push_error()-using suite
#      (`tests/test_cave_geometry.gd`) stays green.
#
# Needs Godot (unlike tools/check_trailers.sh) -- this is a `tests/`-adjacent gate, not a pure-repository-
# text one, so it is not wired into the fast `gates` CI job; it runs in the `tests` job instead, once,
# before any of the real per-suite steps trust the wrapper those steps are about to use.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

GODOT_BIN="${1:-godot}"
fails=0

check() {  # check <ok:0|1> <label>
	if [ "$1" -eq 0 ]; then
		echo "  PASS  $2"
	else
		echo "  FAIL  $2" >&2
		fails=$((fails + 1))
	fi
}

echo "== tools/run_gd_test.sh: mutation test against a real, reproducible crash (D0115/D0116) =="

# --- 1. the pre-fix baseline: still reproduces, on its own, unwrapped ---
raw_out="$("$GODOT_BIN" --headless --path . --script res://tests/fixture_harness_crash_probe.gd 2>&1)"
raw_exit=$?
[ "$raw_exit" -eq 0 ]
check $? "pre-fix baseline: the bare invocation exits 0 despite the crash (got $raw_exit)"
printf '%s\n' "$raw_out" | grep -q "^ALL PASS"
check $? "pre-fix baseline: the bare invocation still prints ALL PASS despite the crash"
printf '%s\n' "$raw_out" | grep -q "SCRIPT ERROR:"
check $? "pre-fix baseline: a real SCRIPT ERROR is genuinely present in that same run's output"
if [ "$raw_exit" -ne 0 ]; then
	echo "  NOTE  the pre-fix baseline no longer reproduces (exit $raw_exit) -- either this Godot version" >&2
	echo "        changed its own error-continuation behavior, or the fixture regressed. Either way," >&2
	echo "        D0115's own baseline needs re-verifying before trusting the assertions below." >&2
fi

# --- 2. the fix: the wrapper catches it ---
wrapped_out="$(bash tools/run_gd_test.sh "$GODOT_BIN" res://tests/fixture_harness_crash_probe.gd 2>&1)"
wrapped_exit=$?
[ "$wrapped_exit" -ne 0 ]
check $? "the fix: tools/run_gd_test.sh exits non-zero on the same crash (got $wrapped_exit)"
printf '%s\n' "$wrapped_out" | grep -q "run_gd_test: FAIL.*SCRIPT ERROR"
check $? "the fix: the wrapper's own failure message names the SCRIPT ERROR class, not a generic failure"

# --- 3. negative control: a real push_error()-using PASS must stay a PASS ---
control_out="$(bash tools/run_gd_test.sh "$GODOT_BIN" res://tests/test_fixed_point.gd 2>&1)"
control_exit=$?
[ "$control_exit" -eq 0 ]
check $? "negative control: test_fixed_point.gd (deliberately calls push_error as PASSING behavior) still exits 0 through the wrapper (got $control_exit)"
printf '%s\n' "$control_out" | grep -q "run_gd_test: PASS"
check $? "negative control: the wrapper's own PASS line is printed for it"

# --- 4-6. D0149's own sibling: an ENGINE-level bare ERROR: (Array.remove_at() out-of-range), same shape
# as steps 1-3 above but for tests/fixture_harness_crash_probe_engine_error.gd ---
engine_raw_out="$("$GODOT_BIN" --headless --path . --script res://tests/fixture_harness_crash_probe_engine_error.gd 2>&1)"
engine_raw_exit=$?
[ "$engine_raw_exit" -eq 0 ]
check $? "D0149 pre-fix baseline: the bare invocation exits 0 despite the engine-level ERROR: (got $engine_raw_exit)"
printf '%s\n' "$engine_raw_out" | grep -q "^ALL PASS"
check $? "D0149 pre-fix baseline: the bare invocation still prints ALL PASS despite the crash"
printf '%s\n' "$engine_raw_out" | grep -q "^ERROR: The calculated index"
check $? "D0149 pre-fix baseline: a real engine-level ERROR: is genuinely present in that same run's output"
if [ "$engine_raw_exit" -ne 0 ]; then
	echo "  NOTE  the D0149 pre-fix baseline no longer reproduces (exit $engine_raw_exit) -- either this" >&2
	echo "        Godot version changed Array.remove_at()'s own error-continuation behavior, or the" >&2
	echo "        fixture regressed. Either way, the assertions below need re-verifying." >&2
fi

engine_wrapped_out="$(bash tools/run_gd_test.sh "$GODOT_BIN" res://tests/fixture_harness_crash_probe_engine_error.gd 2>&1)"
engine_wrapped_exit=$?
[ "$engine_wrapped_exit" -ne 0 ]
check $? "D0149 fix: tools/run_gd_test.sh exits non-zero on the engine-level ERROR: (got $engine_wrapped_exit)"
printf '%s\n' "$engine_wrapped_out" | grep -q "run_gd_test: FAIL.*engine-level ERROR"
check $? "D0149 fix: the wrapper's own failure message names the engine-level-ERROR class, not a generic failure"

engine_control_out="$(bash tools/run_gd_test.sh "$GODOT_BIN" res://tests/test_cave_geometry.gd 2>&1)"
engine_control_exit=$?
[ "$engine_control_exit" -eq 0 ]
check $? "D0149 negative control: test_cave_geometry.gd (deliberately calls push_error as PASSING behavior) still exits 0 through the wrapper (got $engine_control_exit)"
printf '%s\n' "$engine_control_out" | grep -q "run_gd_test: PASS"
check $? "D0149 negative control: the wrapper's own PASS line is printed for it"

echo
if [ "$fails" -eq 0 ]; then
	echo "test_run_gd_test: PASS - the pre-fix bug reproduces, the wrapper catches it, and the wrapper does not false-positive on a legitimate push_error()-using suite"
	exit 0
fi
echo "test_run_gd_test: FAIL ($fails) - do not trust tools/run_gd_test.sh until every assertion above passes" >&2
exit 1
