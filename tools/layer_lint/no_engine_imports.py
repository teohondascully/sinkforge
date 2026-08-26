#!/usr/bin/env python3
"""No engine coupling in core/ or sim/. See docs/ARCHITECTURE.md §3, §4.

    python3 tools/layer_lint/no_engine_imports.py

Grep-level, not a parser, and deliberately conservative: every pattern below
is something docs/ARCHITECTURE.md states outright as forbidden in these two
layers. A file tripping this check is not "maybe fine" — read the offending
line before assuming the pattern is a false positive, because loosening a
pattern here is exactly how the sim quietly regains engine coupling.

Categories checked, each mapped to the architecture rule it enforces:
  - scene-tree coupling      ("no engine imports")
  - scene/resource references("no engine imports" — a .tscn/.tres path is a
                               reference to something Godot, not the sim)
  - file IO                  ("no file IO")
  - wall clock / engine time ("no wall clock")
  - unseeded randomness      (determinism: "seeded, split RNG... no global
                               random", docs/ARCHITECTURE.md §4)
  - autoloads / singletons   ("no global mutable state", CONTEXT.md)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
POLICED_DIRS = ("core", "sim")

PATTERNS = [
    (re.compile(r'\bextends\s+(Node\w*|CanvasItem|Control|Sprite2D|RefCounted\b.*Node)'),
     "extends a scene-tree class"),
    (re.compile(r'\bget_tree\s*\('), "get_tree() — scene-tree access"),
    (re.compile(r'\bget_viewport\s*\('), "get_viewport() — engine viewport access"),
    (re.compile(r'res://[\w./-]+\.(tscn|tres)\b'), "references a .tscn/.tres scene resource"),
    (re.compile(r'\bFileAccess\.'), "FileAccess — file IO"),
    (re.compile(r'\bDirAccess\.'), "DirAccess — file IO"),
    (re.compile(r'\bOS\.get_ticks_(msec|usec)\s*\('), "OS.get_ticks_* — wall clock"),
    (re.compile(r'\bTime\.get_(ticks|unix_time|datetime)'), "Time.get_* — wall clock"),
    (re.compile(r'\bEngine\.get_process_frames\s*\('), "Engine.get_process_frames() — wall/frame clock"),
    (re.compile(r'\b(randi|randf|randomize)\s*\('), "unseeded global RNG (use core's seeded RNG)"),
    (re.compile(r'\bRandomNumberGenerator\b'),
     "RandomNumberGenerator — engine RNG class (use core/SplitRng: one stream per subsystem, serializable)"),
    (re.compile(r'\bFastNoiseLite\b'),
     "FastNoiseLite — engine noise resource (sim/ is engine-free; write a deterministic noise function)"),
    (re.compile(r'^\s*@onready\b'), "@onready — implies scene-tree membership"),
]


def find_gd_files():
    for top in POLICED_DIRS:
        base = ROOT / top
        if base.is_dir():
            yield from base.rglob("*.gd")


def main() -> int:
    files = list(find_gd_files())
    if not files:
        print("no_engine_imports: core/ and sim/ have no .gd files yet — nothing to check.")
        print("no_engine_imports: PASS (vacuously)")
        return 0

    violations = []
    for path in files:
        rel = path.relative_to(ROOT)
        for lineno, line in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            for pattern, label in PATTERNS:
                if pattern.search(line):
                    violations.append(f"{rel}:{lineno}: {label} — {stripped[:80]}")

    print(f"no_engine_imports: {len(files)} files scanned under core/, sim/")
    if violations:
        print(f"no_engine_imports: FAIL — {len(violations)} violation(s)")
        for v in violations:
            print(f"  FAIL  {v}")
        return 1

    print("no_engine_imports: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
