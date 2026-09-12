#!/usr/bin/env python3
"""Mutation tests for check_project_settings.py -- required-key checks and the gate-5 autoload scan.

    python3 tools/layer_lint/test_check_project_settings.py

The autoload half exists because the Phase 1 audit found gate 5 ("no autoloads in sim/") armed by
nothing: `no_engine_imports.py`'s docstring listed "autoloads / singletons" as a checked category, but
an autoload lives in project.godot's `[autoload]` section -- outside every .gd file that tool greps.
Proven live: `[autoload] ProbeAutoload="*res://sim/world/world.gd"` appended to the real project.godot
passed every gate in the tree. The check now lives here, and these cases pin both directions.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_project_settings import parse_settings, autoload_violations  # noqa: E402
from gate_test_support import Observations  # noqa: E402

LOG = Observations("test_check_project_settings")

BASE = """
config_version=5

[application]
run/main_scene="res://shell/main.tscn"

[debug]
gdscript/warnings/enable=true
gdscript/warnings/untyped_declaration=2
"""


def main() -> int:
    sections = parse_settings(BASE)

    LOG.observe("clean settings parse to zero autoload violations",
                autoload_violations(sections) == [])

    sections = parse_settings(BASE + '\n[autoload]\nProbeAutoload="*res://sim/world/world.gd"\n')
    v = autoload_violations(sections)
    LOG.observe("an autoload into sim/ FAILS (the audited escape)",
                len(v) == 1 and "sim/world/world.gd" in v[0], f"{len(v)} violation(s)")

    sections = parse_settings(BASE + '\n[autoload]\nProbeAutoload="*res://core/seams.gd"\n')
    LOG.observe("an autoload into core/ FAILS too (POLICED_DIRS parity)",
                len(autoload_violations(sections)) == 1)

    sections = parse_settings(BASE + '\n[autoload]\nHud="*res://view/hud/hud.gd"\n')
    LOG.observe("an autoload outside the policed dirs does not fire",
                autoload_violations(sections) == [])

    sections = parse_settings(BASE + '\n[autoload]\nNoStar="res://sim/world/world.gd"\n')
    LOG.observe("an unstarred res://sim/ autoload still FAILS (the * is only the enabled marker)",
                len(autoload_violations(sections)) == 1)

    sections = parse_settings(BASE + '\n[autoload]\nSneaky="*res://simulation/world.gd"\n')
    LOG.observe("a res://simulation/ path does NOT fire (prefix match, not substring)",
                autoload_violations(sections) == [])

    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
