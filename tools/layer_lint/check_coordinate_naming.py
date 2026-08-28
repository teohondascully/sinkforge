#!/usr/bin/env python3
"""Every coordinate crossing sim/world's or sim/terrain_gen's public API must name its grid.

    python3 tools/layer_lint/check_coordinate_naming.py

docs/DECISIONS_LEDGER.md D0020: the 4px terrain grid and the (not yet built) 16px logic grid share one
GDScript type, Vector2i -- nothing at the type level stops a caller from passing one where the other is
expected. The accepted mitigation is naming discipline: every terrain-grid coordinate is named
`terrain_cell`, reserving `logic_cell` for whichever module needs the 16px grid. D0027 found that
discipline had already lapsed once (`occupied_cells() -> Array`, no "terrain" anywhere in its
signature) purely by a human sampling three functions at random.

Per the director, 2026-08-26: naming-and-typing discipline is an accepted trade against the allocation
cost real wrapper types would add to sim/world's hottest paths (docs/DECISIONS_LEDGER.md D0019, D0020),
but discipline degrades across sessions and context compactions in a way a lint does not. This makes the
naming rule a checked property instead of something a reviewer has to remember to sample for.

Rule: in sim/world/*.gd and sim/terrain_gen/*.gd, every PUBLIC function (name doesn't start with `_` --
this codebase's existing private-by-convention marker, e.g. ShaftGenerator._grow_vein) whose signature
carries a coordinate must name which grid it is:
  - a Vector2i-typed PARAMETER's own name must contain "terrain_" or "logic_"
  - a function RETURNING Vector2i, Array[Vector2i], or Dictionary[Vector2i, ...] must have "terrain_" or
    "logic_" in its own name (there's no parameter to name in this direction, so the function name is
    the only identifier available -- exactly how `occupied_terrain_cells()` reads once fixed)

Grep-level, not a parser, matching every other gate in this directory -- see their docstrings for why
that tradeoff is accepted. Known blind spot, stated rather than silently missed: an UNTYPED `-> Array`
or `-> Dictionary` return cannot be checked at all, since nothing declares it holds Vector2i in the
first place. That's a real gap this check does not close -- it was `occupied_cells()`'s exact original
shape, and a future function could dodge this rule the same way by simply not typing its return. Out of
scope here on purpose: the director asked for a coordinate-naming check, not a general "type your
collections" check, and folding the two together would make this a different, broader tool than the one
that was actually requested.

Scoped to Vector2i only, not Vector2: the ambiguity this exists to catch is specifically about which
GRID an integer cell index belongs to, not about continuous positions (sim/body's eventual pixel-space
Vector2 values are a different axis entirely, unaffected by D0020).
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gd_scan import gd_files_in  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
POLICED_DIRS = ("sim/world", "sim/terrain_gen", "sim/body")

_FUNC_RE = re.compile(
    r'^\s*(?:static\s+)?func\s+(?P<name>\w+)\s*\((?P<params>.*)\)\s*'
    r'(?:->\s*(?P<ret>[\w\[\],\s]+?))?\s*:'
)
_GRID_TAGS = ("terrain_", "logic_")


def _split_top_level(params: str) -> list[str]:
    """Split a parameter list on commas, ignoring commas nested inside [...] (e.g. Array[Vector2i])."""
    parts = []
    depth = 0
    current = ""
    for ch in params:
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += ch
    if current.strip():
        parts.append(current)
    return parts


def _is_coordinate_type(type_str: str) -> bool:
    t = type_str.strip()
    if t == "Vector2i":
        return True
    if t.replace(" ", "") == "Array[Vector2i]":
        return True
    if t.replace(" ", "").startswith("Dictionary[Vector2i,"):
        return True
    return False


def _names_its_grid(identifier: str) -> bool:
    return any(tag in identifier for tag in _GRID_TAGS)


def _check_file(path: Path):
    """Yield (lineno, message) for every violation in one file."""
    for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue
        m = _FUNC_RE.match(line)
        if not m:
            continue
        func_name = m.group("name")
        if func_name.startswith("_"):
            continue  # private by this codebase's convention -- not part of the public API

        for raw_param in _split_top_level(m.group("params")):
            raw_param = raw_param.strip()
            if not raw_param or ":" not in raw_param:
                continue
            param_name, _, rest = raw_param.partition(":")
            param_name = param_name.strip()
            param_type = rest.split("=")[0].strip()
            if _is_coordinate_type(param_type) and not _names_its_grid(param_name):
                yield lineno, (f"{func_name}()'s parameter `{param_name}: {param_type}` doesn't name "
                                f"its grid (needs 'terrain_' or 'logic_' in the parameter name)")

        ret = (m.group("ret") or "").strip()
        if ret and _is_coordinate_type(ret) and not _names_its_grid(func_name):
            yield lineno, (f"{func_name}() -> {ret} doesn't name its grid "
                            f"(needs 'terrain_' or 'logic_' in the function name)")


def find_gd_files():
    return gd_files_in(ROOT, POLICED_DIRS)


def main() -> int:
    files = sorted(find_gd_files())
    if not files:
        print("check_coordinate_naming: sim/world and sim/terrain_gen have no .gd files yet — nothing to check.")
        print("check_coordinate_naming: PASS (vacuously)")
        return 0

    violations = []
    for path in files:
        rel = path.relative_to(ROOT)
        for lineno, message in _check_file(path):
            violations.append(f"{rel}:{lineno}: {message}")

    print(f"check_coordinate_naming: {len(files)} files scanned under {', '.join(POLICED_DIRS)}/")
    if violations:
        print(f"check_coordinate_naming: FAIL — {len(violations)} violation(s)")
        for v in violations:
            print(f"  FAIL  {v}")
        return 1

    print("check_coordinate_naming: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
