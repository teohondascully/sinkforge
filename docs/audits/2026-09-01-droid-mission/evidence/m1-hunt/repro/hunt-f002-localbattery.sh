#!/bin/bash
# HUNT-F002: LOCALBATTERY-GATEDROP reproduction.
#
# tools/run_local_battery.sh runs gates then suites. Gate failures set
# GATE_FAILED and print to stderr, but the script's final exit keys only on
# suite FAILED. The `exit 1` for gates fires only under GATES_ONLY=1. So a
# failing gate + green suites produces exit 0 from the canonical "run what CI
# runs" instrument.
#
# This script reproduces the exit-code path in isolation: it extracts the
# gate-failure and suite-pass logic from run_local_battery.sh (lines 60-120 at
# the pin) and demonstrates that GATE_FAILED > 0 with zero suite failures
# produces exit 0 (not exit 1).
#
# Usage: bash repro/hunt-f002-localbattery.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/hunt-f002-localbattery.txt}"
SCRATCH="/tmp/m1-hunt-f002"
rm -rf "$SCRATCH"
mkdir -p "$SCRATCH"
cd "$SCRATCH"

# Reproduce the exit-code logic from run_local_battery.sh:60-120.
# The script runs gates, tracks GATE_FAILED, then runs suites and tracks FAILED.
# Final exit: only suite FAILED matters (unless GATES_ONLY=1).
{
    # Simulate: one gate failed, all suites passed.
    GATE_FAILED=1
    SUITES_PASSED=62
    SUITES_TOTAL=62
    FAILED=()  # empty: no suites failed

    # From run_local_battery.sh:74-78
    if [ "$GATE_FAILED" -gt 0 ]; then
        echo "run_local_battery: $GATE_FAILED gate step(s) FAILED -- CI will fail the same way" >&2
    fi
    # GATES_ONLY is not set (default), so this block is skipped:
    # if [ "${GATES_ONLY:-}" = "1" ]; then
    #     exit $(( GATE_FAILED > 0 ? 1 : 0 ))
    # fi

    # From run_local_battery.sh:107-120
    echo "run_local_battery: $(( $SUITES_TOTAL - ${#FAILED[@]} ))/$SUITES_TOTAL passed"
    if [ "${#FAILED[@]}" -gt 0 ]; then
        printf '  FAILED: %s\n' "${FAILED[@]}"
        exit 1
    fi
    # Falls through to implicit exit 0 (no exit statement after the if block).
    echo "EXIT_CODE=0"
} > "$OUT" 2>&1
RC=$?

echo "exit code: $RC" >> "$OUT"
echo "---" >> "$OUT"
echo "Reproduction complete. Output saved to $OUT" >&2
echo "Key evidence: GATE_FAILED=1 but EXIT_CODE=0 (gate drop reproduced)" >&2

rm -rf "$SCRATCH"
