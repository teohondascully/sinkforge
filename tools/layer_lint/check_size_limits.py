#!/usr/bin/env python3
"""File and function size limits. See docs/QUALITY.md gates 3-4.

    python3 tools/layer_lint/check_size_limits.py

- No .gd file over 400 lines (warn at 300). legacy/ is excluded — it is
  frozen pre-pivot code and these limits were never its contract.
- No function over 50 lines. Cyclomatic complexity is NOT checked here
  (this script only counts lines); if that gate is wanted later it needs a
  real branch-counting pass, not a line-based approximation pretending to
  be one.

Function boundaries are found by indentation: a `func` line at indent N ends
at the next line at indent <= N that is not blank/comment, or EOF. This is
GDScript's actual block-scoping rule, so it is exact, not a heuristic.
"""
import re
import sys
from pathlib import Path

FUNC_NAME_RE = re.compile(r'^\s*(?:static\s+)?func\s+([A-Za-z_]\w*)')

ROOT = Path(__file__).resolve().parents[2]
EXCLUDED_TOP = {"legacy"}
FILE_WARN = 300
FILE_LIMIT = 400
FUNC_LIMIT = 50


def find_gd_files():
    for p in ROOT.rglob("*.gd"):
        rel = p.relative_to(ROOT)
        if rel.parts[0] in EXCLUDED_TOP or rel.parts[0].startswith("."):
            continue
        yield rel


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" \t"))


def function_spans(lines: list[str]):
    """Yields (name, start_line_1idx, length) for each top-level or nested func."""
    for i, line in enumerate(lines):
        stripped = line.strip()
        m = FUNC_NAME_RE.match(line)
        if not m:
            continue
        name = m.group(1)
        base_indent = indent_of(line)
        length = 1
        for j in range(i + 1, len(lines)):
            nxt = lines[j]
            if nxt.strip() == "" or nxt.strip().startswith("#"):
                length += 1
                continue
            if indent_of(nxt) <= base_indent:
                break
            length += 1
        yield name, i + 1, length


def main() -> int:
    files = list(find_gd_files())
    if not files:
        print("check_size_limits: no .gd files outside legacy/ yet — nothing to check.")
        print("check_size_limits: PASS (vacuously)")
        return 0

    fails = []
    warns = []
    for rel in files:
        lines = (ROOT / rel).read_text(encoding="utf-8", errors="replace").splitlines()
        n = len(lines)
        if n > FILE_LIMIT:
            fails.append(f"{rel}: {n} lines (limit {FILE_LIMIT})")
        elif n > FILE_WARN:
            warns.append(f"{rel}: {n} lines (warn at {FILE_WARN})")
        for name, start, length in function_spans(lines):
            if length > FUNC_LIMIT:
                fails.append(f"{rel}:{start}: func {name}() is {length} lines (limit {FUNC_LIMIT})")

    print(f"check_size_limits: {len(files)} files scanned")
    for w in warns:
        print(f"  WARN  {w}")
    if fails:
        print(f"check_size_limits: FAIL — {len(fails)} violation(s)")
        for f in fails:
            print(f"  FAIL  {f}")
        return 1

    print("check_size_limits: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
