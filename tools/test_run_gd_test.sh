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

echo
if [ "$fails" -eq 0 ]; then
	echo "test_run_gd_test: PASS - the pre-fix bug reproduces, the wrapper catches it, and the wrapper does not false-positive on a legitimate push_error()-using suite"
	exit 0
fi
echo "test_run_gd_test: FAIL ($fails) - do not trust tools/run_gd_test.sh until every assertion above passes" >&2
exit 1
