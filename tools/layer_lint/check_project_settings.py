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

    checked = sum(len(keys) for keys in REQUIRED.values())
    print(f"check_project_settings: {checked} required key(s) checked in project.godot")
    if failures:
        for f in failures:
            print(f"check_project_settings: FAIL -- {f}")
        return 1

    print("check_project_settings: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
