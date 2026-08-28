"""Shared `.gd` file discovery for `tools/layer_lint/`'s gates -- extracted 2026-08-28
(`docs/DECISIONS_LEDGER.md` D0097) after `tools/quality_check/duplication.py`'s first run found two
near-duplicate `find_gd_files()` implementations, each defined independently in two different gates.

Two genuinely different filter styles existed, not one duplicated four times over identical data:
`check_coordinate_naming.py`/`no_engine_imports.py` each name an explicit ALLOW-list of the specific
directories they police (different lists -- `("sim/world", "sim/terrain_gen", "sim/body")` vs
`("core", "sim")`) and yield ABSOLUTE paths for direct reading; `check_size_limits.py`/`layer_lint.py`
each name a DENY-list of what NOT to scan and yield paths RELATIVE to root. Both styles are kept, as two
small named functions sharing one glob primitive each -- forcing all four into one function behind a
style flag would make every call site less self-evident about what it actually scans, trading a real
readability property for a slightly smaller line count.
"""
from pathlib import Path


def gd_files_in(root: Path, dirs):
    """Every `.gd` file under any of `dirs` (each a path relative to `root`), yielded as ABSOLUTE
    paths -- the allow-list style."""
    for rel in dirs:
        base = root / rel
        if base.is_dir():
            yield from base.rglob("*.gd")


def gd_files_excluding(root: Path, excluded: set):
    """Every `.gd` file under `root`, yielded RELATIVE to `root`, skipping any top-level directory
    named in `excluded` or starting with `.` -- the deny-list style."""
    for p in root.rglob("*.gd"):
        rel = p.relative_to(root)
        if rel.parts[0] in excluded or rel.parts[0].startswith("."):
            continue
        yield rel
