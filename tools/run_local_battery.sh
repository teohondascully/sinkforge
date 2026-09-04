#!/usr/bin/env bash
# Runs locally exactly the suites CI runs per commit -- no more, and no fewer.
#
#     bash tools/run_local_battery.sh [path-to-godot]
#
# WHY THIS IS A TRACKED TOOL AND NOT A SCRATCH SCRIPT (docs/DECISIONS_LEDGER.md D0230, NEEDS_DIRECTOR
# P007). Every session that wants "run what CI runs" writes this by hand, and the obvious way to write it
# is to grep `.github/workflows/harness.yml` for `res://tests/test_*.gd`. That is WRONG, and wrong in a
# direction nobody notices: it also matches `test_body_fuzz.gd`, which lives in the `fuzz_nightly` job
# behind `if: github.event_name == 'schedule'` and sweeps 1.5M ticks. One session ran it on every local
# battery, about four minutes a time, before noticing. Measured: the `tests` job holds 38 suites, a
# whole-file grep finds 39, and the extra one is exactly that sweep.
#
# So the job STRUCTURE carries the answer and this parses the YAML rather than pattern-matching the file
# as text. Parsing is safe to rely on now: `check_suite_coverage.py` validates the workflow parses before
# it matches anything (D0217, after two unquoted colons made the file invalid YAML while every regex over
# it still found what it wanted).
#
# The counterpart failure is why the step list is not hardcoded here: a suite added to CI and not to this
# file would be silently unrun locally, which is the same two-population defect D0225 removed from the
# size gate. One source, read twice.
set -euo pipefail

GODOT="${1:-$(command -v godot || echo ./godot)}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/harness.yml"
PARSER="$ROOT/tools/list_ci_suites.py"
GATE_PARSER="$ROOT/tools/list_ci_gates.py"

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
	echo "run_local_battery: FAIL - no godot binary at '$GODOT'" >&2
	exit 2
fi

# Read with a `while read` loop rather than `mapfile`: macOS ships bash 3.2, where `mapfile` does not
# exist. This script was first written with it, ran on this machine, printed `mapfile: command not found`,
# executed ZERO suites -- and still looked like it had worked. That is the exact failure this file's own
# header is about, reproduced inside the fix for it. The zero-suite guard below is what makes that shape
# loud instead of quiet, and it is the reason the guard is not optional politeness.
# THE GATES FIRST, and from the SAME workflow for the same reason the suites are (D0295). Every session
# that wanted "run what CI's gate job runs" wrote `for g in tools/layer_lint/*.py` by hand, which is a
# DIFFERENT and quietly smaller population: it misses the duplication gate, the base-namespace check, the
# schema validator and the codegen check. A commit passed that loop, was pushed, and CI's duplication
# gate failed on it -- a whole round trip spent discovering that two lists disagreed.
#
# NUL-separated, because one gate step is a multi-line script and splitting on newlines would run half
# of it as a command. `read -d ''` is in bash 3.2, which is what macOS ships (see the note below on
# `mapfile`, which is not).
GATES=()
while IFS= read -r -d '' gate; do
	[ -n "$gate" ] && GATES+=("$gate")
done < <(python3 "$GATE_PARSER" "$WORKFLOW"; printf '\0')

if [ "${#GATES[@]}" -eq 0 ]; then
	echo "run_local_battery: FAIL - parsed the workflow and found ZERO gate steps in the 'gates' job" >&2
	exit 2
fi

echo "run_local_battery: ${#GATES[@]} gate step(s) from harness.yml's 'gates' job"
GATE_FAILED=0
for gate in "${GATES[@]}"; do
	# The label skips shell preamble (`set -e`, blank lines) so a multi-line gate step is named by what it
	# actually runs rather than by its first housekeeping line.
	label="$(printf '%s' "$gate" | grep -vE '^[[:space:]]*(set |#|$)' | head -1)"
	[ -n "$label" ] || label="$(printf '%s' "$gate" | head -1)"
	if ( cd "$ROOT" && eval "$gate" ) >"${TMPDIR:-/tmp}/gate.log" 2>&1; then
		echo "PASS  gate: $label"
	else
		echo "FAIL  gate: $label"
		tail -20 "${TMPDIR:-/tmp}/gate.log"
		GATE_FAILED=$((GATE_FAILED + 1))
	fi
done
if [ "$GATE_FAILED" -gt 0 ]; then
	echo "run_local_battery: $GATE_FAILED gate step(s) FAILED -- CI will fail the same way" >&2
fi
if [ "${GATES_ONLY:-}" = "1" ]; then
	exit $(( GATE_FAILED > 0 ? 1 : 0 ))
fi

SUITES=()
while IFS= read -r line; do
	[ -n "$line" ] && SUITES+=("$line")
done < <(python3 "$PARSER" "$WORKFLOW")

if [ "${#SUITES[@]}" -eq 0 ]; then
	echo "run_local_battery: FAIL - parsed the workflow and found ZERO suites in the 'tests' job" >&2
	exit 2
fi

echo "run_local_battery: ${#SUITES[@]} suite(s) from harness.yml's 'tests' job (the nightly sweep is excluded by construction)"
LOG="$(mktemp)"
FAILED=()
for suite in "${SUITES[@]}"; do
	if bash "$ROOT/tools/run_gd_test.sh" "$GODOT" "$suite" >"$LOG" 2>&1; then
		echo "PASS  $suite"
		grep -E "^[[:space:]]+>" "$LOG" || true
	else
		echo "FAIL  $suite"
		tail -25 "$LOG"
		FAILED+=("$suite")
	fi
done
rm -f "$LOG"

echo
echo "run_local_battery: $(( ${#SUITES[@]} - ${#FAILED[@]} ))/${#SUITES[@]} passed"
if [ "${#FAILED[@]}" -gt 0 ]; then
	printf '  FAILED: %s\n' "${FAILED[@]}"
	exit 1
fi
if [ "$GATE_FAILED" -gt 0 ]; then
	exit 1
fi
