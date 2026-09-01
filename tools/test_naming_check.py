#!/usr/bin/env python3
"""Test naming convention check for `tests/`.

Two rules, both static (no Godot needed):

1. Every `tests/test_*.gd` file must define at least one `func _test_*()` — a test file with no
   tests is dead weight that CI runs and reports green over.
2. Every `func _test_*()` in the repository must be inside `tests/` — a test function outside the
   test tree is a structural violation that `check_suite_coverage` (gate 31) would not catch,
   because it counts suites by filename, not by function.

Fixture files (`tests/fixture_*.gd`) and diagnostic files (`tests/diag_*.gd`) are exempt from rule 1
— they are not test suites. `test_base.gd` and `property_checks.gd` are also exempt (base class and
property-test helpers, not suites themselves).

    python3 tools/test_naming_check.py

Exit 0 if all conventions hold, 1 if any violation is found.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST_DIR = ROOT / "tests"

# Files in tests/ that are not test suites and are exempt from rule 1.
NON_SUITE_FILES = {
    "test_base.gd",           # base class, not a suite
    "property_checks.gd",     # property-test helper, not a suite
    "test_recorded_sessions.gd",  # replays recordings in _initialize(), no discrete _test_*() cases (D0282)
}

FUNC_RE = re.compile(r"^\s*(?:static\s+)?func\s+(\w+)", re.MULTILINE)


def gd_files(root: Path) -> list[Path]:
    """Every .gd file under root, relative to root."""
    return sorted(p for p in root.rglob("*.gd") if "legacy" not in p.parts and ".godot" not in p.parts)


def test_functions(text: str) -> list[str]:
    """Every function name matching _test_*() in the source text."""
    return [name for name in FUNC_RE.findall(text) if name.startswith("_test_")]


def run(root: Path = ROOT) -> int:
    test_root = root / "tests"
    if not test_root.is_dir():
        print("test_naming: VOID -- no tests/ directory found.")
        return 2

    violations: list[str] = []

    # Rule 1: every tests/test_*.gd file has at least one _test_*() function.
    for path in sorted(test_root.glob("test_*.gd")):
        if path.name in NON_SUITE_FILES:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        funcs = test_functions(text)
        if not funcs:
            rel = path.relative_to(root)
            violations.append(f"{rel}: no _test_*() functions found (test file with no tests)")

    # Rule 2: every _test_*() function in the repo is inside tests/.
    for path in gd_files(root):
        if "tests" in path.parts:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        funcs = test_functions(text)
        if funcs:
            rel = path.relative_to(root)
            for name in funcs:
                violations.append(f"{rel}: _test function {name}() outside tests/")

    if violations:
        print(f"test_naming: {len(violations)} violation(s):")
        for v in violations:
            print(f"  {v}")
        print("test_naming: FAIL")
        return 1

    suite_count = len(list(test_root.glob("test_*.gd")))
    suite_count -= len(NON_SUITE_FILES & {p.name for p in test_root.glob("test_*.gd")})
    print(f"test_naming: {suite_count} test suite(s) checked, all conventions hold.")
    print("test_naming: PASS")
    return 0


def main(argv: list[str] | None = None) -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", default=str(ROOT))
    return run(Path(parser.parse_args(argv).root).resolve())


if __name__ == "__main__":
    sys.exit(main())
