#!/usr/bin/env python3
"""Mutation tests for layer_lint.py's dependency resolution (D0224).

    python3 tools/layer_lint/test_layer_lint.py

This file exists because `layer_lint.py` ran as a REQUIRED CI check for weeks while resolving **zero**
dependency edges -- it matched only `res://*.gd` paths against a codebase that couples entirely through
`class_name` globals. It printed PASS every time. Nothing was wrong with the tree; the instrument could
not register its subject, and a green from it meant nothing at all.

So the fix cannot be trusted on its own say-so either. Every branch below plants a violation and asserts
it is CAUGHT, or plants a legal edge and asserts it is NOT -- including the two directions that make the
resolver honest rather than merely loud: a reference inside a COMMENT and one inside a STRING must not be
edges, because this repository's comments are full of capitalised type names and a lint that flagged
prose would be turned off within a day.

The last case is the important one. `a tree whose globals are never referenced` reproduces the ORIGINAL
defect -- edges exist to be found and the resolver finds none -- and asserts the gate now exits 2 rather
than printing PASS. That is the branch that would have caught this in the first place.

Runs the real script against scratch trees via `--root`, never against the repository: a test that edits
the live tree and crashes leaves the tree broken, and this file must be safe to interrupt.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_test_support import Observations  # noqa: E402

SCRIPT = Path(__file__).resolve().parent / "layer_lint.py"
LOG = Observations("test_layer_lint")

# A minimal but REAL-shaped tree: core publishes a global, sim uses it (legal), view uses interface
# (legal). Every case below is this tree plus one edit, so a failure names the edit, not the fixture.
CLEAN = {
    "core/fixed_point.gd": "class_name Fx\nextends RefCounted\n\nconst SCALE: int = 65536\n",
    "sim/world/tile_grid.gd": "class_name TileGrid\nextends RefCounted\n\nvar width: int = 0\n",
    "sim/body/body.gd": (
        "class_name Body\nextends RefCounted\n\n"
        "func at(grid: TileGrid) -> int:\n\treturn grid.width * Fx.SCALE\n"),
    "interface/interface.gd": (
        "class_name Interface\nextends RefCounted\n\n"
        "func observe(body: Body) -> int:\n\treturn 1 if body else 0\n"),
    "data/materials/generated.gd": (
        "class_name MaterialsRecords\nextends RefCounted\n\nconst RECORDS: Dictionary = {}\n"),
    "view/hud.gd": (
        "class_name Hud\nextends RefCounted\n\n"
        "func draw_from(door: Interface) -> void:\n"
        "\tprint(door, MaterialsRecords.RECORDS)\n"),
}


def run_lint(files: dict) -> tuple[int, str]:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        for rel, text in files.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        proc = subprocess.run([sys.executable, str(SCRIPT), "--root", str(root)],
                              capture_output=True, text=True)
        return proc.returncode, proc.stdout + proc.stderr


def with_edit(rel: str, text: str) -> dict:
    files = dict(CLEAN)
    files[rel] = text
    return files


def check(name: str, files: dict, expect_code: int, expect_substring: str) -> None:
    code, out = run_lint(files)
    ok = code == expect_code and expect_substring in out
    LOG.observe(name, ok, f"want exit {expect_code}, got {code}")
    if not ok:
        print("    output was:\n" + "\n".join("      " + line for line in out.splitlines()))


def main() -> int:
    # The negative control FIRST: if the clean tree does not pass, every positive below is failing for
    # whatever breaks this one, and none of them prove anything.
    check("the clean tree passes and reports the edges it actually resolved",
          CLEAN, 0, "class_name reference(s) checked")

    # THE PLANT the brief asks for: view/ may depend on interface and core, never on sim.
    check("PLANT: a view file using a sim class_name is CAUGHT",
          with_edit("view/hud.gd",
                    "class_name Hud\nextends RefCounted\n\n"
                    "func draw(grid: TileGrid) -> int:\n\treturn grid.width\n"),
          1, "layer 'view' may not depend on layer 'sim'")

    # The other direction of the same rule, so the catch is not fitted to one layer pair.
    check("PLANT: a core file using a sim class_name is CAUGHT (core depends on nothing)",
          with_edit("core/fixed_point.gd",
                    "class_name Fx\nextends RefCounted\n\nconst SCALE: int = 65536\n"
                    "static func rows(grid: TileGrid) -> int:\n\treturn grid.width\n"),
          1, "layer 'core' may not depend on layer 'sim'")

    # The pre-existing path-based check must still work -- the class_name work is an addition, and a
    # regression here would trade one blind spot for another.
    check("the res:// path rule still catches its own violation",
          with_edit("view/hud.gd",
                    'class_name Hud\nextends RefCounted\n\n'
                    'const G := preload("res://sim/world/tile_grid.gd")\n'),
          1, "may not depend on layer 'sim'")

    # Both directions of "reads code, not prose". A lint that flagged either of these is unusable here.
    check("a sim class_name inside a COMMENT is not an edge",
          with_edit("view/hud.gd",
                    "class_name Hud\nextends RefCounted\n\n"
                    "## Draws the world. Never touches TileGrid -- that is sim's business.\n"
                    "func draw(door: Interface) -> void:\n\tprint(door)\n"),
          0, "PASS")
    check("a sim class_name inside a STRING is not an edge",
          with_edit("view/hud.gd",
                    'class_name Hud\nextends RefCounted\n\n'
                    'func draw() -> void:\n\tprint("TileGrid is not imported here")\n'),
          0, "PASS")

    # A legal edge must stay legal, or the gate is just loud rather than correct.
    check("a legal sim -> core edge still passes",
          with_edit("sim/world/tile_grid.gd",
                    "class_name TileGrid\nextends RefCounted\n\n"
                    "var width: int = Fx.SCALE\n"),
          0, "PASS")

    # ---- P013 (D0243): `data` is a MODELLED layer now. It used to sit in UNPOLICED, where the lint
    # could neither permit nor refuse an edge to it -- the vacuous state a ruling cannot be enforced in.

    check("a legal view -> data appearance edge passes (the palette a renderer must be able to read)",
          with_edit("view/hud.gd",
                    "class_name Hud\nextends RefCounted\n\n"
                    "func draw() -> Dictionary:\n\treturn MaterialsRecords.RECORDS\n"),
          0, "PASS")

    # THE LAUNDERING GUARD, and it is the reason `view -> data` is safe to grant at all. `data` is
    # declared a leaf (`ALLOWED["data"] = set()`), so it cannot become a route from view to sim. Without
    # this branch, "view cannot reach sim through data" would be a claim rather than a checked property.
    check("PLANT: a data file referencing a sim class_name is CAUGHT (data is a leaf, so it cannot launder)",
          with_edit("data/materials/generated.gd",
                    "class_name MaterialsRecords\nextends RefCounted\n\n"
                    "const RECORDS: Dictionary = {}\n"
                    "static func rows(grid: TileGrid) -> int:\n\treturn grid.width\n"),
          1, "layer 'data' may not depend on layer 'sim'")

    # And the grant is PER-LAYER, not a blanket "data is readable by anyone". `interface` was not
    # granted it, so it must still fail -- otherwise modelling the layer would have quietly opened it
    # to every layer at once, which is a wider change than the one that was ruled.
    check("PLANT: an interface file using a data class_name is CAUGHT (the grant is per-layer)",
          with_edit("interface/interface.gd",
                    "class_name Interface\nextends RefCounted\n\n"
                    "func observe(body: Body) -> Dictionary:\n"
                    "\treturn MaterialsRecords.RECORDS if body else {}\n"),
          1, "layer 'interface' may not depend on layer 'data'")

    # THE ORIGINAL DEFECT, reproduced: globals exist, nothing references any of them, and the old gate
    # called that PASS. It must now be a control failure.
    check("a tree whose globals are never referenced FAILS as a broken resolver, not as a pass",
          {"core/fixed_point.gd": "class_name Fx\nextends RefCounted\n\nconst SCALE: int = 65536\n",
           "sim/world/tile_grid.gd": "class_name TileGrid\nextends RefCounted\n\nvar width: int = 0\n"},
          2, "CONTROL FAILED")

    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
