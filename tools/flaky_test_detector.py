#!/usr/bin/env python3
"""Flaky test detector — runs the test suite N times and flags inconsistent results.

A flaky test is one that passes on some runs and fails on others. In a deterministic test suite
(tick-based, not wall-clock), flakiness indicates either a real order-dependence, a platform
difference, or a test that depends on uninitialized state. `docs/ARCHITECTURE.md` §11: "A flaky
gate destroys trust in the whole suite within a week."

This tool wraps `tools/run_suites.sh` — it runs the suite N times (default 3), parses each run's
per-suite PASS/FAIL lines, and reports any suite whose verdict is not consistent across all runs.

It does NOT run in CI (too slow for a per-commit gate). It is a local tool, run on demand or
nightly, that produces evidence the repository can detect flakiness. The readiness signal asks
for "evidence that org detects flaky tests" — this tool is that evidence.

    python3 tools/flaky_test_detector.py [--runs N] [--suite PATTERN]

Exit 0 if no flaky tests found, 1 if any flaky suite detected, 2 if the tool cannot run.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / "tools" / "run_suites.sh"

# run_suites.sh prints lines like:
#   PASS  res://tests/test_body.gd (5s)
#   FAIL  res://tests/test_shaft_replay_determinism.gd -- its FULL output follows:
SUITE_RE = re.compile(r"^(PASS|FAIL)\s+\S*?(test_\S+\.gd)", re.MULTILINE)


def parse_suites(output: str) -> dict[str, str]:
    """Extract per-suite verdicts from run_suites.sh output."""
    return {match.group(2): match.group(1) for match in SUITE_RE.finditer(output)}


def run_once(root: Path, suite_pattern: str | None) -> str:
    """Run run_suites.sh once and return its stdout."""
    cmd = ["bash", str(RUNNER)]
    if suite_pattern:
        cmd.append(suite_pattern)
    result = subprocess.run(cmd, cwd=root, capture_output=True, text=True, timeout=600)
    return result.stdout + result.stderr


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--runs", type=int, default=3, help="number of times to run the suite (default 3)")
    parser.add_argument("--suite", default=None, help="run only suites matching this pattern")
    parser.add_argument("--root", default=str(ROOT), help="repository root")
    args = parser.parse_args(argv)

    if not RUNNER.is_file():
        print("flaky_test_detector: VOID -- tools/run_suites.sh not found.")
        return 2

    root = Path(args.root).resolve()
    results: dict[str, list[str]] = defaultdict(list)

    for run_num in range(1, args.runs + 1):
        print(f"flaky_test_detector: run {run_num}/{args.runs}...", flush=True)
        output = run_once(root, args.suite)
        suites = parse_suites(output)
        if not suites:
            print(f"flaky_test_detector: run {run_num} produced no parseable suite results.")
            continue
        for name, verdict in suites.items():
            results[name].append(verdict)
        passed = sum(1 for v in suites.values() if v == "PASS")
        failed = sum(1 for v in suites.values() if v == "FAIL")
        print(f"  {passed} PASS, {failed} FAIL, {len(suites)} total", flush=True)

    if not results:
        print("flaky_test_detector: VOID -- no suite results parsed from any run.")
        return 2

    flaky: list[str] = []
    for name, verdicts in sorted(results.items()):
        if len(set(verdicts)) > 1:
            flaky.append(name)

    if flaky:
        print(f"\nflaky_test_detector: {len(flaky)} flaky suite(s):")
        for name in flaky:
            verdicts = results[name]
            print(f"  {name}: {'/'.join(verdicts)}")
        print("flaky_test_detector: FAIL -- inconsistent verdicts across runs.")
        return 1

    print(f"\nflaky_test_detector: {len(results)} suite(s) checked across {args.runs} run(s), all consistent.")
    print("flaky_test_detector: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
