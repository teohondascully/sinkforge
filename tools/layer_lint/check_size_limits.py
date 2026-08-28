#!/usr/bin/env python3
"""File and function size limits. See docs/QUALITY.md gates 3-4.

    python3 tools/layer_lint/check_size_limits.py

- No .gd file over 400 lines (warn at 300). legacy/ is excluded — it is
  frozen pre-pivot code and these limits were never its contract.
- No function over 50 lines. Cyclomatic complexity is NOT checked here
  (this script only counts lines); if that gate is wanted later it needs a
  real branch-counting pass, not a line-based approximation pretending to
  be one.

`FUNC_LIMIT=50` is a CEILING, not a norm — reconciled explicitly, not left to silently disagree with
`tools/quality_check/function_length.py`'s own IQR-fence read of the real distribution
(`docs/DECISIONS_LEDGER.md` D0098). This run's real numbers: 85 GDScript functions, median 4 lines, p90
18.6, IQR outlier fence 19.5 — the typical function in this codebase is nowhere near 50; 50 is a hard
backstop for the pathological case, verified empirically to still hold at least one real function
(`sim/body/vertical_resolve.gd:resolve_floor`, currently exactly 50) rather than picked with no headroom
at all. Kept unchanged rather than lowered toward 19.5, on purpose: this gate is a blocking FAIL, and
retroactively lowering it would force an immediate split of every function currently between 20 and 50
lines — several of them (`_resolve_horizontal`, `_carve_caves`, `tick`, `_enforce_grid_bounds`,
`move_and_resolve`, `grid_floor_backstop`, `generate`) working and tested, with no defect driving the
change. The two numbers answer different questions — this one asks "has this function become
unmaintainable," `function_length.py`'s fence asks "is this function unusual relative to the rest of
this codebase's own distribution today" — and a function between the fence and the cap is not a
violation of either question read correctly, only of conflating them.

Function boundaries are found by indentation: a `func` line at indent N ends
at its LAST line at indent > N, or EOF. A run of blank/comment lines is only
attributed to the function if a deeper-indented real line follows it (proving
it was interior or trailing) -- otherwise it's the next function's own
leading doc-comment, not this one's tail.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gd_scan import gd_files_excluding  # noqa: E402

FUNC_NAME_RE = re.compile(r'^\s*(?:static\s+)?func\s+([A-Za-z_]\w*)')

ROOT = Path(__file__).resolve().parents[2]
EXCLUDED_TOP = {"legacy"}
FILE_WARN = 300
FILE_LIMIT = 400
FUNC_LIMIT = 50


def find_gd_files():
    return gd_files_excluding(ROOT, EXCLUDED_TOP)


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" \t"))


def function_spans(lines: list[str]):
    """Yields (name, start_line_1idx, length) for each top-level or nested func.

    A blank/comment line only extends the span if a LATER line at deeper indent proves it was
    genuinely interior (or trailing) to this function's own body -- otherwise it's the next
    function's own leading doc-comment and must not be attributed here. Found live: a multi-line
    doc-comment for `_enforce_grid_bounds` was landing entirely on `_resolve_floor`'s own count, since
    the original version counted every blank/comment line unconditionally before checking what came
    after it. `docs/QUALITY.md` §2's "a gate is only as good as its pattern list" applies to
    line-attribution as much as to a name list.
    """
    for i, line in enumerate(lines):
        m = FUNC_NAME_RE.match(line)
        if not m:
            continue
        name = m.group(1)
        base_indent = indent_of(line)
        last_real_offset = 0
        j = i + 1
        while j < len(lines):
            nxt = lines[j]
            if nxt.strip() == "" or nxt.strip().startswith("#"):
                j += 1
                continue
            if indent_of(nxt) <= base_indent:
                break
            last_real_offset = j - i
            j += 1
        yield name, i + 1, last_real_offset + 1


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
