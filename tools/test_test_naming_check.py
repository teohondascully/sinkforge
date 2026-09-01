#!/usr/bin/env python3
"""Mutation tests for tools/test_naming_check.py.

    python3 tools/test_test_naming_check.py
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[0] / "layer_lint"))
from gate_test_support import Observations, init_scratch, write_file  # noqa: E402

import test_naming_check as N  # noqa: E402

LOG = Observations("test_test_naming_check")


def branch_suite_has_tests() -> None:
    """A test_*.gd file with _test_*() functions passes."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "tests/test_foo.gd", "func _test_a():\n\tpass\nfunc _test_b():\n\tpass\n")
        exit_code = N.run(root)
        LOG.observe("suite_has_tests: test file with _test_*() functions passes",
                    exit_code == 0, detail=f"exit={exit_code}")


def branch_suite_no_tests_fails() -> None:
    """A test_*.gd file with NO _test_*() functions fails."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "tests/test_empty.gd", "func _helper():\n\tpass\n")
        exit_code = N.run(root)
        LOG.observe("suite_no_tests: test file with no _test_*() fails",
                    exit_code == 1, detail=f"exit={exit_code}")


def branch_non_suite_exempt() -> None:
    """test_base.gd and property_checks.gd are exempt — they are not suites."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "tests/test_base.gd", "func _initialize():\n\tpass\n")
        write_file(root, "tests/property_checks.gd", "func _check():\n\tpass\n")
        exit_code = N.run(root)
        LOG.observe("non_suite_exempt: test_base.gd with no _test_*() does not fail",
                    exit_code == 0, detail=f"exit={exit_code}")


def branch_test_func_outside_tests_fails() -> None:
    """A _test_*() function outside tests/ fails."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "core/mod.gd", "func _test_secret():\n\tpass\n")
        write_file(root, "tests/test_mod.gd", "func _test_real():\n\tpass\n")
        exit_code = N.run(root)
        LOG.observe("test_outside_tests: _test_*() in core/ fails",
                    exit_code == 1, detail=f"exit={exit_code}")


def branch_fixture_exempt() -> None:
    """Fixture files (fixture_*.gd) are not test_*.gd and are not checked by rule 1."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "tests/fixture_probe.gd", "func _helper():\n\tpass\n")
        write_file(root, "tests/test_real.gd", "func _test_a():\n\tpass\n")
        exit_code = N.run(root)
        LOG.observe("fixture_exempt: fixture_*.gd with no _test_*() does not fail",
                    exit_code == 0, detail=f"exit={exit_code}")


def branch_void_no_tests_dir() -> None:
    """No tests/ directory exits 2 (VOID)."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "core/mod.gd", "func foo():\n\tpass\n")
        exit_code = N.run(root)
        LOG.observe("void: no tests/ directory exits 2", exit_code == 2, detail=f"exit={exit_code}")


def main() -> int:
    for branch in (branch_suite_has_tests, branch_suite_no_tests_fails,
                   branch_non_suite_exempt, branch_test_func_outside_tests_fails,
                   branch_fixture_exempt, branch_void_no_tests_dir):
        branch()
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
