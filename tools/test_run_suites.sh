#!/usr/bin/env bash
# Guard on `tools/run_suites.sh`: a FAILING suite's own diagnostic output must reach the runner's stdout.
#
# THE DEFECT THIS EXISTS FOR (D0272). The parallel runner filtered a failing suite's log to lines matching
# `^  FAIL|FAILURE(S)`, capped at three. `test_shaft_replay_determinism.gd` prints its full observed hash
# sequence on a golden mismatch as a bare `print()` -- added by D0167 specifically so a re-pin could be
# read straight from the CI log rather than costing a commit-and-push round trip. It matched neither
# pattern. CI reported the mismatch with the sequence nowhere in the log, and the information had not
# failed: it had stopped existing.
#
# The check is a POSITIVE CONTROL PAIR, not a single assertion: a fixture that passes while printing the
# marker (the marker must NOT be demanded on the pass path, or the runner would just be echoing
# everything always), and a fixture that fails while printing it (the marker MUST appear). One without
# the other proves nothing -- a runner that dumps every log unconditionally passes the second alone, and
# a runner that dumps nothing passes the first alone.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${1:?usage: test_run_suites.sh <godot-binary>}"
MARKER="RUNSUITES_DIAGNOSTIC_MARKER_47182"
FAILURES=0

TMP="$(mktemp -d)"
# The `.uid` files matter as much as the `.gd` ones: the import pass below mints a `.uid` beside every
# script, and leaving those behind would trip `check_untracked_files` with sidecars pointing at scripts
# that no longer exist -- litter that looks like a real omission.
trap 'rm -rf "$TMP"; rm -f "$ROOT"/tests/test_zz_runner_probe_pass.gd "$ROOT"/tests/test_zz_runner_probe_pass.gd.uid "$ROOT"/tests/test_zz_runner_probe_fail.gd "$ROOT"/tests/test_zz_runner_probe_fail.gd.uid' EXIT

# Both fixtures print the marker; they differ ONLY in whether they then fail. That is what isolates
# "the runner surfaced a failing suite's output" from "the suite happened to print something".
cat > "$ROOT/tests/test_zz_runner_probe_pass.gd" <<'GD'
extends "res://tests/test_base.gd"
func _initialize() -> void:
	print("RUNSUITES_DIAGNOSTIC_MARKER_47182 pass-path")
	_check(true, "the passing probe passes")
	_finish("zz_runner_probe_pass")
GD
cat > "$ROOT/tests/test_zz_runner_probe_fail.gd" <<'GD'
extends "res://tests/test_base.gd"
func _initialize() -> void:
	print("RUNSUITES_DIAGNOSTIC_MARKER_47182 fail-path")
	_check(false, "the failing probe fails on purpose")
	_finish("zz_runner_probe_fail")
GD

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1

bash "$ROOT/tools/run_suites.sh" "$GODOT" 1 res://tests/test_zz_runner_probe_pass.gd > "$TMP/pass.out" 2>&1
PASS_RC=$?
bash "$ROOT/tools/run_suites.sh" "$GODOT" 1 res://tests/test_zz_runner_probe_fail.gd > "$TMP/fail.out" 2>&1
FAIL_RC=$?

check() {  # check <description> <condition-result>
  if [ "$2" -eq 0 ]; then echo "  PASS: $1"; else echo "  FAIL: $1"; FAILURES=$((FAILURES+1)); fi
}

check "the passing probe is reported as a pass (rc=$PASS_RC)" "$PASS_RC"
[ "$FAIL_RC" -ne 0 ]; check "the failing probe is reported as a failure (rc=$FAIL_RC)" $?
grep -q "$MARKER" "$TMP/fail.out"; check "a FAILING suite's own diagnostic print reaches the runner's stdout" $?
grep -q "the failing probe fails on purpose" "$TMP/fail.out"; check "and so does its assertion text" $?
! grep -q "$MARKER" "$TMP/pass.out"; check "a PASSING suite's output is NOT echoed -- otherwise the check above is vacuous" $?

if [ "$FAILURES" -eq 0 ]; then
  echo "test_run_suites: PASS."
else
  echo "test_run_suites: $FAILURES FAILURE(S)."
fi
[ "$FAILURES" -eq 0 ]
