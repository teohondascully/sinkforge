#!/bin/bash
# HUNT-F009: test_isolation_check.py raw-text scan reproduction.
#
# tools/test_isolation_check.py at the pin reads the workflow as raw text
# (no YAML parse). It uses regex on each line to find godot invocations
# that reference test suites without going through run_gd_test.sh or
# run_suites.sh. An unparseable harness.yml would still scan "clean" because
# the regex would still match lines. Mitigated by check_suite_coverage.py's
# YAML parse in the same CI job (D0217).
#
# This script verifies the raw-text approach by showing the code path and
# demonstrating that the tool does not use a YAML parser.
#
# Usage: bash repro/hunt-f009-isolation.sh [output-file]

set -eu

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$PACK_ROOT/raw/hunt-f009-isolation.txt}"
REPO="/Users/thondascully/Projects/sinkforge"

cd "$REPO"

echo "=== test_isolation_check.py: raw-text approach (no YAML parse) ===" > "$OUT"
echo "" >> "$OUT"

echo "--- Source: how the workflow is read ---" >> "$OUT"
git show 70f8a785:tools/test_isolation_check.py | grep -n 'read_text\|splitlines\|yaml\|YAML' >> "$OUT" 2>&1 || echo "(no YAML import found)" >> "$OUT"
echo "" >> "$OUT"

echo "--- Source: the regex approach ---" >> "$OUT"
git show 70f8a785:tools/test_isolation_check.py | grep -n 'GODOT_SUITE_RE\|SUITE_RE\|WRAPPER_RE\|re.compile' >> "$OUT" 2>&1 || true
echo "" >> "$OUT"

echo "=== Running test_isolation_check.py at the pin ===" >> "$OUT"
git show 70f8a785:tools/test_isolation_check.py | python3 - >> "$OUT" 2>&1 || true
echo "" >> "$OUT"

echo "=== Mitigation: check_suite_coverage.py uses YAML parse ===" >> "$OUT"
git show 70f8a785:tools/layer_lint/check_suite_coverage.py | grep -n 'yaml\|YAML\|import yaml' >> "$OUT" 2>&1 || true

echo "" >> "$OUT"
echo "=== Assessment ===" >> "$OUT"
echo "test_isolation_check.py reads harness.yml as raw text (read_text +" >> "$OUT"
echo "splitlines, no YAML parser). An unparseable harness.yml would still" >> "$OUT"
echo "scan clean because the regex would still match lines. Mitigated by" >> "$OUT"
echo "check_suite_coverage.py's YAML parse in the same CI job (D0217):" >> "$OUT"
echo "if harness.yml is invalid YAML, check_suite_coverage.py fails first." >> "$OUT"
echo "Not the seventh; a disclosed and mitigated weakness." >> "$OUT"

echo "Reproduction complete. Output saved to $OUT" >&2
