#!/usr/bin/env python3
"""Mutation tests for check_coordinate_naming.py (D0020/D0027/D0359).

    python3 tools/layer_lint/test_check_coordinate_naming.py

The rule: a public function in sim/world, sim/terrain_gen or sim/body whose signature carries a
Vector2i/Array[Vector2i]/Dictionary[Vector2i,...] coordinate must name its grid (terrain_, logic_ or
fx). Tested by feeding `_check_file` synthetic source through a real file -- the function reads paths,
not text, so each case is a scratch file, which also exercises the real read path.
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_coordinate_naming import _check_file  # noqa: E402
from gate_test_support import Observations  # noqa: E402

LOG = Observations("test_check_coordinate_naming")


def violations_for(source: str) -> list:
    root = Path(tempfile.mkdtemp())
    path = root / "probe.gd"
    path.write_text(source, encoding="utf-8")
    return list(_check_file(path))


def main() -> int:
    LOG.observe("public func with unnamed Vector2i param FAILS",
                len(violations_for("func set_solid(cell: Vector2i) -> void:\n\tpass\n")) == 1)
    LOG.observe("terrain_-named param passes",
                violations_for("func set_solid(terrain_cell: Vector2i) -> void:\n\tpass\n") == [])
    LOG.observe("logic_-named param passes",
                violations_for("func set_solid(logic_cell: Vector2i) -> void:\n\tpass\n") == [])
    LOG.observe("fx-named param passes (D0358's third space)",
                violations_for("func hitch(pos_fx: Vector2i) -> void:\n\tpass\n") == [])
    LOG.observe("private _func is exempt",
                violations_for("func _set_solid(cell: Vector2i) -> void:\n\tpass\n") == [])
    LOG.observe("Vector2i RETURN with unnamed func FAILS (the occupied_cells() shape)",
                len(violations_for("func occupied() -> Array[Vector2i]:\n\treturn []\n")) == 1)
    LOG.observe("grid-named func returning Vector2i passes",
                violations_for("func occupied_terrain_cells() -> Array[Vector2i]:\n\treturn []\n") == [])
    LOG.observe("typed param inside a comment line does not fire",
                violations_for("# func set_solid(cell: Vector2i) -> void:\n\tpass\n") == [])
    # The tool's own stated blind spot, pinned so it cannot silently widen or silently heal:
    LOG.observe("KNOWN BLIND SPOT stays visible: untyped -> Array carrying cells does not fire",
                violations_for("func occupied() -> Array:\n\treturn []\n") == [])
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
