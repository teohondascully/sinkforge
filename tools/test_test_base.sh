#!/usr/bin/env bash
# Mutation test for tests/test_base.gd's verdict: A GREEN THAT ASSERTED NOTHING IS NOT A GREEN.
#
#   bash tools/test_test_base.sh <godot-binary>
#
# Lifted with A' step 0 from legacy/tools/check_base.gd:145-160 (docs/DECISIONS_LEDGER.md D0343).
# `_finish()` used to print "ALL PASS" and exit 0 whenever `_failures == 0`, which is also true of a suite
# whose every `_test_*` returned before its first `_check` -- an instrument that cannot register its
# subject, reporting green. Now `_finish()` refuses that shape (prints VACUOUS, exits 1, never prints ALL
# PASS) and puts the asserted count on every verdict line, passing and failing alike.
#
# Three probes, GENERATED here rather than kept as tracked fixtures (the same choice as
# tools/test_run_suites.sh, for the same reason: a tracked zero-assertion suite would be a permanent red
# in the suite population):
#   1. zero assertions        -> exit non-zero, "VACUOUS" in the output, NO line beginning "ALL PASS"
#   2. one passing assertion  -> exit 0, "ALL PASS (...) -- 1 asserted"
#   3. one pass + one fail    -> exit non-zero, "1 FAILURE(S) of 2 asserted"
# Each runs THROUGH tools/run_gd_test.sh, the wrapper every real suite runs through, so what is proved is
# the verdict as CI reads it, not the bare process. Probe 1 is the mutation: revert the refusal in
# `_finish()` and it exits 0 with "ALL PASS (zz_verdict_probe_zero) -- 0 asserted", which this refuses.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${1:?usage: test_test_base.sh <godot-binary>}"
FAILURES=0
ASSERTED=0
TMP="$(mktemp -d)"
PROBES=(zero one fail)
cleanup() {
	rm -rf "$TMP"
	for p in "${PROBES[@]}"; do
		rm -f "$ROOT/tests/test_zz_verdict_probe_$p.gd" "$ROOT/tests/test_zz_verdict_probe_$p.gd.uid"
	done
}
trap cleanup EXIT

check() {  # check <ok:0|1> <label>
	ASSERTED=$((ASSERTED + 1))
	if [ "$1" -eq 0 ]; then
		echo "  PASS  $2"
	else
		echo "  FAIL  $2" >&2
		FAILURES=$((FAILURES + 1))
	fi
}

cat > "$ROOT/tests/test_zz_verdict_probe_zero.gd" <<'GD'
extends "res://tests/test_base.gd"
func _initialize() -> void:
	_finish("zz_verdict_probe_zero")
GD
cat > "$ROOT/tests/test_zz_verdict_probe_one.gd" <<'GD'
extends "res://tests/test_base.gd"
func _initialize() -> void:
	_check(true, "the one-assertion probe passes")
	_finish("zz_verdict_probe_one")
GD
cat > "$ROOT/tests/test_zz_verdict_probe_fail.gd" <<'GD'
extends "res://tests/test_base.gd"
func _initialize() -> void:
	_check(true, "the mixed probe's passing half")
	_check(false, "the mixed probe fails on purpose")
	_finish("zz_verdict_probe_fail")
GD

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1

echo "== tests/test_base.gd: a green that asserted nothing is refused (D0343) =="

bash "$ROOT/tools/run_gd_test.sh" "$GODOT" res://tests/test_zz_verdict_probe_zero.gd > "$TMP/zero.out" 2>&1
ZERO_RC=$?
[ "$ZERO_RC" -ne 0 ]
check $? "zero assertions: exits non-zero through the wrapper (got $ZERO_RC)"
grep -q "VACUOUS" "$TMP/zero.out"
check $? "zero assertions: the output says VACUOUS"
! grep -q "^ALL PASS" "$TMP/zero.out"
check $? "zero assertions: no line beginning ALL PASS was printed"

bash "$ROOT/tools/run_gd_test.sh" "$GODOT" res://tests/test_zz_verdict_probe_one.gd > "$TMP/one.out" 2>&1
ONE_RC=$?
[ "$ONE_RC" -eq 0 ]
check $? "one assertion: exits 0 through the wrapper (got $ONE_RC) -- the refusal does not turn a real green red"
grep -q "^ALL PASS (zz_verdict_probe_one) -- 1 asserted$" "$TMP/one.out"
check $? "one assertion: the verdict line carries the count, '-- 1 asserted'"

bash "$ROOT/tools/run_gd_test.sh" "$GODOT" res://tests/test_zz_verdict_probe_fail.gd > "$TMP/fail.out" 2>&1
FAIL_RC=$?
[ "$FAIL_RC" -ne 0 ]
check $? "one pass one fail: exits non-zero through the wrapper (got $FAIL_RC)"
grep -q "^1 FAILURE(S) of 2 asserted (zz_verdict_probe_fail)$" "$TMP/fail.out"
check $? "one pass one fail: the failing line carries the count too, '1 FAILURE(S) of 2 asserted'"

if [ "$FAILURES" -eq 0 ]; then
	echo "test_test_base: PASS ($ASSERTED asserted)"
	exit 0
fi
echo "test_test_base: $FAILURES FAILURE(S) of $ASSERTED asserted." >&2
for f in zero one fail; do echo "--- $f.out"; cat "$TMP/$f.out"; done >&2
exit 1
