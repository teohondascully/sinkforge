#!/usr/bin/env python3
"""Test isolation check — verifies every `godot` invocation of a test suite in CI goes through
`run_gd_test.sh` or `run_suites.sh`, not a bare `godot --script`.

Each suite running in its own Godot process (via `tools/run_gd_test.sh`) is what gives this
repository process-level test isolation: no shared state, no order-dependence, no one suite's
crash taking down another. D0115/D0116 documented why this matters: a runtime error inside a
called function logs `SCRIPT ERROR:` and lets execution continue — `run_gd_test.sh` catches
this, a bare `godot --script` would not.

`run_suites.sh` calls `run_gd_test.sh` internally for each suite, so `res://tests/` paths passed
as arguments to `run_suites.sh` are fine. The violation is a `godot` command that references
`res://tests/` without going through either wrapper.

    python3 tools/test_isolation_check.py

Exit 0 if all suites are isolated, 1 if any bypasses the wrappers.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# A godot command that directly references a test suite path.
# Matches lines containing 'godot' and 'res://tests/' but NOT 'run_gd_test' or 'run_suites'.
GODOT_SUITE_RE = re.compile(r"godot")
SUITE_RE = re.compile(r"res://tests/\S+\.gd")
WRAPPER_RE = re.compile(r"run_gd_test\.sh|run_suites\.sh")


def run(root: Path = ROOT) -> int:
    workflow = root / ".github" / "workflows" / "harness.yml"
    if not workflow.is_file():
        print("test_isolation: VOID -- no harness.yml found.")
        return 2

    lines = workflow.read_text(encoding="utf-8").splitlines()
    violations: list[str] = []

    for i, line in enumerate(lines, 1):
        # Only check lines that invoke godot directly AND reference a test suite.
        if not GODOT_SUITE_RE.search(line):
            continue
        if not SUITE_RE.search(line):
            continue
        if WRAPPER_RE.search(line):
            continue
        violations.append(f"line {i}: {line.strip()}")

    if violations:
        print(f"test_isolation: {len(violations)} violation(s):")
        for v in violations:
            print(f"  {v}")
        print("test_isolation: FAIL -- a godot invocation bypassing run_gd_test.sh/run_suites.sh "
              "loses the SCRIPT ERROR guard (D0115/D0116).")
        return 1

    print("test_isolation: no bare godot invocations of test suites found — all go through "
          "run_gd_test.sh or run_suites.sh.")
    print("test_isolation: PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", default=str(ROOT))
    return run(Path(parser.parse_args(argv).root).resolve())


if __name__ == "__main__":
    sys.exit(main())
