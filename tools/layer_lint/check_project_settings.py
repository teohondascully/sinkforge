#!/usr/bin/env python3
"""project.godot must keep its load-bearing flags. docs/DECISIONS.md, "Enforcement tripwire #1".

    python3 tools/layer_lint/check_project_settings.py

A non-headless Godot launch this session silently rewrote project.godot, dropping
gdscript/warnings/enable=true and every doc comment in the file -- caught only by a routine
git status, not by any gate. Static typing being an already-enforced build failure is one of the
three reasons docs/ARCHITECTURE.md §12 / ONBOARDING.md give for rejecting a Rust migration; if this
flag silently goes off, that decision quietly stops being true and nothing else would notice.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROJECT_GODOT = ROOT / "project.godot"

# section -> {key: required value}
REQUIRED = {
    "debug": {
        "gdscript/warnings/enable": "true",
        "gdscript/warnings/untyped_declaration": "2",
    },
}

# QUALITY.md gate 5 ("no autoloads in sim/") -- an autoload is declared HERE, in project.godot, not in
# any .gd file, so the grep-level no_engine_imports.py cannot see one no matter what its docstring's
# category list used to claim. Measured live during the Phase 1 audit: an `[autoload]` entry pointing
# at res://sim/world/world.gd passed every gate in the tree. Policed prefix set matches
# no_engine_imports.py's POLICED_DIRS: autoloading a sim/ or core/ script makes engine-free,
# deterministic code reachable as global mutable state -- the exact thing both rules exist against.
FORBIDDEN_AUTOLOAD_PREFIXES = ("res://sim/", "res://core/")


def parse_settings(text: str) -> dict[str, dict[str, str]]:
    """Minimal .godot/.ini reader -- not configparser, which rejects the top-level config_version=5
    line this file has before its first [section]. Only key=value pairs are needed here; array/
    string-valued settings (PackedStringArray(...), quoted strings) are read as their literal RHS
    text, which is enough for the exact-match checks this gate does."""
    sections: dict[str, dict[str, str]] = {}
    current = ""
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            current = line[1:-1].strip()
            sections.setdefault(current, {})
            continue
        if "=" in line:
            key, _, value = line.partition("=")
            sections.setdefault(current, {})[key.strip()] = value.strip()
    return sections


def autoload_violations(sections: dict[str, dict[str, str]]) -> list[str]:
    """Every [autoload] entry whose target lives under a policed prefix is a failure.

    Kept as a function over parsed sections (not a read of PROJECT_GODOT) so the mutation test can
    feed it synthetic autoload tables without standing up a scratch project."""
    failures = []
    for name, target in sections.get("autoload", {}).items():
        # Value shape: `"*res://path/to/script.gd"` -- the * inside the quotes marks enabled. Strip
        # quotes FIRST, then the marker: lstrip("*") on the raw value sees `"`, not `*`, and the
        # marker survives into the prefix match (caught by this file's own mutation test).
        path = target.strip().strip('"').lstrip("*")
        if any(path.startswith(p) for p in FORBIDDEN_AUTOLOAD_PREFIXES):
            failures.append(f"[autoload] {name} targets {path} -- no autoloads in core/ or sim/ "
                            f"(QUALITY.md gate 5, CONTEXT.md 'no global mutable state')")
    return failures


def main() -> int:
    if not PROJECT_GODOT.is_file():
        print("check_project_settings: FAIL -- project.godot does not exist.")
        return 1

    sections = parse_settings(PROJECT_GODOT.read_text(encoding="utf-8"))

    failures = []
    for section, keys in REQUIRED.items():
        if section not in sections:
            failures.append(f"missing section [{section}]")
            continue
        for key, want in keys.items():
            got = sections[section].get(key)
            if got != want:
                failures.append(f"[{section}] {key} = {got!r}, want {want!r}")

    failures += autoload_violations(sections)

    checked = sum(len(keys) for keys in REQUIRED.values()) + len(sections.get("autoload", {}))
    print(f"check_project_settings: {checked} required key(s) checked in project.godot")
    if failures:
        for f in failures:
            print(f"check_project_settings: FAIL -- {f}")
        return 1

    print("check_project_settings: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
