#!/usr/bin/env python3
"""Mutation tests for check_module_docs.py -- QUALITY.md gate 6's presence half.

Branch vocabulary, not assertions: each case is OBSERVED or reported `NOT OBSERVED -- BRANCH
UNTESTED`, so a case that stops exercising its branch is loud rather than silently absent
(gate_test_support.py's docstring says why).
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_module_docs as gate  # noqa: E402
from gate_test_support import Observations, init_scratch, write_file  # noqa: E402

OBS = Observations("check_module_docs")


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        init_scratch(root)

        # A clean mixed-convention tree: sim module doc, a layer README, a shell README.
        write_file(root, "sim/world/x.gd", "extends RefCounted\n")
        write_file(root, "sim/world/MODULE.md", "# sim/world\n")
        write_file(root, "view/v.gd", "extends RefCounted\n")
        write_file(root, "view/README.md", "# view\n")
        write_file(root, "shell/s.gd", "extends RefCounted\n")
        write_file(root, "shell/README.md", "# shell\n")

        files = [Path("sim/world/x.gd"), Path("view/v.gd"), Path("shell/s.gd")]
        missing, required = gate.dirs_missing_doc(root, files)
        OBS.observe("clean tree with both doc conventions has nothing missing", missing == [],
                    str(missing))
        OBS.observe("all three dirs counted as required", required == 3, f"required={required}")

        # Mutation: delete the sim module's doc.
        (root / "sim/world/MODULE.md").unlink()
        missing, _ = gate.dirs_missing_doc(root, files)
        OBS.observe("a module dir without a doc is reported", missing == [Path("sim/world")],
                    str(missing))
        (root / "sim/world/MODULE.md").write_text("# sim/world\n", encoding="utf-8")

        # Mutation: a NEW .gd-bearing subdir under a README'd layer still needs its own doc --
        # the layer root's README does not cover it.
        write_file(root, "view/hud/h.gd", "extends RefCounted\n")
        files.append(Path("view/hud/h.gd"))
        missing, required = gate.dirs_missing_doc(root, files)
        OBS.observe("a doc-less subdir under a documented layer is reported",
                    missing == [Path("view/hud")], str(missing))
        OBS.observe("the new dir raised the required count", required == 4, f"{required}")

        # A README.md satisfies the rule as well as MODULE.md.
        write_file(root, "view/hud/README.md", "# view/hud\n")
        missing, _ = gate.dirs_missing_doc(root, files)
        OBS.observe("README.md satisfies the rule", missing == [], str(missing))

        # Exemptions: generated data shards and unpoliced tops carry no obligation.
        files += [Path("data/bands/generated.gd"), Path("playtest/p.gd"), Path("tests/t.gd"),
                  Path("legacy/l.gd")]
        missing, required = gate.dirs_missing_doc(root, files)
        OBS.observe("data/, playtest/, tests/, legacy/ dirs carry no doc obligation",
                    missing == [], str(missing))
        OBS.observe("exempt dirs do not raise the required count", required == 4, f"{required}")

        # Tool control: an empty population is exit 2, not a vacuous PASS.
        sys.argv = ["check_module_docs.py", "--root", str(root / "empty")]
        (root / "empty").mkdir()
        init_scratch(root / "empty")
        OBS.observe("empty population exits 2", gate.main() == 2)

    return OBS.summarise()


if __name__ == "__main__":
    sys.exit(main())
