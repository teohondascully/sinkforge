#!/usr/bin/env python3
"""HUNT-F003: FLAKY-PARSE reproduction.

tools/flaky_test_detector.py (D0324, one commit old at pin) has SUITE_RE
(line 35) expecting a dotted format like `test_x.gd ......... PASS (1.2s)`.
But run_suites.sh writes per-suite verdicts to .result files
(`PASS <secs> <suite>`), not to stdout. stdout carries only the summary line
and FAIL dumps. So parse_suites() returns an empty dict on real output,
every invocation parses zero suites, and the tool exits 2 (VOID, fail-closed
by luck).

The live fail-open half: when parse_suites() returns empty, the loop
`continue`s (lines 59-62), and suites absent from one run's parse are never
compared. A run with SOME parseable lines and a run with none reconcile
silently.

This script demonstrates the regex mismatch by testing SUITE_RE against
the actual run_suites.sh output format.
"""
import re
import sys

# The exact SUITE_RE from flaky_test_detector.py:35
SUITE_RE = re.compile(r"^(test_\S+\.gd)\s+\.+\s+(PASS|FAIL)", re.MULTILINE)

# What run_suites.sh actually prints to stdout (from the source at the pin):
# - summary: "run_suites: 62 passed, 0 failed, of 62 in 350s (jobs=4)"
# - for failures: "FAIL  res://tests/test_x.gd -- its FULL output follows:"
# Per-suite verdicts go to .result FILES, not stdout.
run_suites_stdout = """run_suites: slowest suites:
    5 res://tests/test_shaft_replay_determinism.gd
    3 res://tests/test_body.gd
    2 res://tests/test_cave_passes.gd
run_suites: 62 passed, 0 failed, of 62 in 350s (jobs=4)"""

# What SUITE_RE expects (the format from the docstring that run_suites.sh
# never emits to stdout):
expected_format = "test_body.gd ......... PASS (1.2s)"

# Test 1: SUITE_RE against actual run_suites.sh stdout
matches_real = SUITE_RE.findall(run_suites_stdout)
print(f"SUITE_RE matches against run_suites.sh stdout: {len(matches_real)}")
print(f"  (expected 0: run_suites.sh writes verdicts to .result files, not stdout)")

# Test 2: SUITE_RE against the format it expects
matches_expected = SUITE_RE.findall(expected_format)
print(f"SUITE_RE matches against expected format: {len(matches_expected)}")
print(f"  (expected 1: the regex IS correct for the format run_suites.sh never emits)")

# Test 3: the continue-on-empty-parse path
# From flaky_test_detector.py:59-62:
#   suites = parse_suites(output)
#   if not suites:
#       print(f"flaky_test_detector: run {run_num} produced no parseable suite results.")
#       continue
print()
print("Exit code path: parse_suites() returns empty -> 'continue' ->")
print("  suites absent from one run are never compared across runs.")
print("  Today: all runs parse zero -> VOID -> exit 2 (fail-closed by luck).")
print("  One format change away from quiet green: if run_suites.sh ever printed")
print("  the dotted format, partial parses would silently reconcile.")

sys.exit(0)
