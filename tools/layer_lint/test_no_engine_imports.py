#!/usr/bin/env python3
"""Mutation tests for no_engine_imports.py -- the pattern list is the gate.

    python3 tools/layer_lint/test_no_engine_imports.py

A grep-level check is only as good as its pattern list (docs/QUALITY.md §2; the tool's own docstring
names "a missing pattern is a gate that reports green on the exact thing it exists to catch"). This
file's job: every pattern fires on a line written to trip it, and the comment-skip means a pattern
embedded in a `#` line is not a violation -- verified here by replicating main()'s skip, which is the
one line of logic outside PATTERNS itself.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from no_engine_imports import PATTERNS  # noqa: E402
from gate_test_support import Observations  # noqa: E402

LOG = Observations("test_no_engine_imports")

# (label substring to find in PATTERNS, a line that must trip it)
CASES = [
    ("extends a scene-tree", "extends Node2D"),
    ("instantiates a scene-tree", "var n := Sprite2D.new()"),
    ("get_tree()", "get_tree().quit()"),
    ("get_viewport()", "var vp := get_viewport()"),
    ("scene resource", 'load("res://view/hud/hud.tscn")'),
    ("FileAccess", "FileAccess.open(path)"),
    ("ResourceLoader", "ResourceLoader.load(p)"),
    ("wall clock", "OS.get_ticks_msec()"),
    ("Engine.get_", "Engine.get_process_frames()"),
    ("unseeded global RNG", "randi()"),
    ("RandomNumberGenerator", "var r := RandomNumberGenerator.new()"),
    ("FastNoiseLite", "var n := FastNoiseLite.new()"),
    ("reads input devices", "Input.is_action_pressed(x)"),
    ("rendering/audio server", "RenderingServer.canvas_item_clear(i)"),
    ("physics server", "PhysicsServer2D.body_set_state(b, s)"),
    ("threading", "var t := Thread.new()"),
    ("network IO", "var s := TCPServer.new()"),
    ("OS subprocess", 'OS.execute("ls", [])'),
    ("@onready", "@onready var x := 1"),
]


def matches(line: str) -> list[str]:
    """Replicates main()'s per-line loop: comment lines are skipped, then every pattern is tried."""
    if line.strip().startswith("#"):
        return []
    return [label for pattern, label in PATTERNS if pattern.search(line)]


def main() -> int:
    for needle, line in CASES:
        hits = matches(line)
        LOG.observe(f"pattern exists and fires: {line[:48]!r}",
                    any(needle in h for h in hits),
                    f"{len(hits)} hit(s): {hits[:1]}")

    LOG.observe("a violating line inside a # comment does not fire (the skip is real)",
                matches("# extends Node2D -- not real code") == [])
    LOG.observe("ordinary sim code stays clean (no blanket match)",
                matches("func set_solid(terrain_cell: Vector2i) -> void:") == [])
    LOG.observe("ProjectSettings is deliberately not blocked (docstring's rejected list)",
                matches("ProjectSettings.get_setting(x)") == [])
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
