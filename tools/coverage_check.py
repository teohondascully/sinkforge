#!/usr/bin/env python3
"""Function-name coverage for `core/` and `sim/` — a ratchet against neglect, not a coverage guarantee.

Not line coverage (GDScript has no coverage instrumentation, and no pure-Python GDScript parser
exists to build one), but a real, enforceable metric: a function is "covered" if its name appears
as an identifier in at least one `tests/test_*.gd` suite's code — comments and string literals blanked
first (`gd_source.blank_comments_and_strings`), so a mention in prose doesn't count.

Three properties that must be stated wherever this gate is cited:

1. **It measures reference, not execution.** A bare identifier in a test file — never called —
   counts as covered. The gate can be taken to 100% by appending one dead line per uncovered name,
   with zero new testing. That is the tool's declared design (its name says "function-name
   coverage"), but it means this is a ratchet against neglect, not a coverage guarantee.

2. **The denominator is keyed by name, not by definition.** Two functions sharing a name in
   different files are one unit in the denominator, and one test reference covers both. The real
   declaration count is higher (156 in core/+sim/ at the time this was written); the gate's
   denominator is 144 (156 declarations → 146 distinct names → 144 after engine-called exclusion).

3. **The margin is thin.** 60% of 144 needs 87; the current level is 89. Three new untested
   functions in core/ or sim/ turns it red — which is the point of a ratchet, but it will fire on
   the next feature commit rather than eventually.

This overcounts (a name can appear for a different reason, and one match covers every same-named
function) and undercounts (private functions called by covered public functions are marked
uncovered, and engine-called functions like `_init`/`_ready` are never called by tests directly).
Both directions are stated, not glossed over. What it answers is the most important coverage
question: which functions have no test exercising them at all?

`docs/QUALITY.md` gate 14 declares "≥ 85% line coverage on `core/` and `sim/`" but has no enforcing
code (gate_status.py reports it NO-CODE). This tool does not satisfy that gate's letter — it is a
different, weaker metric — and is reported-only, not BLOCKING, for the reasons above.

    python3 tools/coverage_check.py

Exit 0 if coverage is at or above the threshold, 1 if below, 2 if the question cannot be answered
(empty population, no test suites).
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[0] / "layer_lint"))
sys.path.insert(0, str(Path(__file__).resolve().parents[0] / "quality_check"))
from gd_source import referenced_identifiers  # noqa: E402
from gd_scan import gd_files_excluding  # noqa: E402
from check_size_limits import function_spans as gd_function_spans  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]

GAME_DIRS = ("core", "sim")
TEST_DIR = "tests"

# The threshold is set at the current measured level (61.8% at the time this was written,
# D0322) as a ratchet — it can only go up, never down. A new function added to core/ or sim/
# that no test references lowers the percentage; if it drops below 61.8%, the gate reports it.
# This is reported-only (not BLOCKING) because the metric is a ratchet against neglect, not a
# coverage guarantee (see the docstring's three properties).
COVERAGE_FLOOR = 61.8

# Engine-called functions that are invoked by Godot itself, not by test code. Excluding them
# from the denominator is not gaming the metric — they ARE covered (by the engine calling them
# on every tick or every frame), just not in a way this name-reference scan can see.
ENGINE_CALLED = {
    "_init", "_ready", "_enter_tree", "_exit_tree", "_process", "_physics_process",
    "_input", "_unhandled_input", "_unhandled_key_input", "_shortcut_input",
    "_draw", "_get_configuration_warning", "_to_string", "_get", "_set",
}


def game_functions(root: Path = ROOT) -> dict[str, set[str]]:
    """Every unique function name in `core/` and `sim/`, mapped to the files that define it.
    Engine-called functions (`_init`, `_ready`, ...) are excluded from the denominator — they
    are covered by the engine, not by tests, and counting them as uncovered would understate
    the real coverage."""
    out: dict[str, set[str]] = {}
    for rel in gd_files_excluding(root, {"legacy"}):
        if str(rel).startswith(GAME_DIRS):
            text = (root / rel).read_text(encoding="utf-8", errors="replace")
            for name, _start, _length in gd_function_spans(text.splitlines()):
                if name in ENGINE_CALLED:
                    continue
                out.setdefault(name, set()).add(str(rel))
    return out


def test_identifiers(root: Path = ROOT) -> set[str]:
    """Every identifier appearing as CODE in any `tests/test_*.gd` file — comments and string
    literals blanked first, so a function name mentioned in a docstring doesn't count."""
    ids: set[str] = set()
    for rel in gd_files_excluding(root, {"legacy"}):
        if str(rel).startswith(TEST_DIR + "/") and Path(rel).name.startswith("test_"):
            text = (root / rel).read_text(encoding="utf-8")
            ids |= referenced_identifiers(text)
    return ids


def run(root: Path = ROOT) -> int:
    funcs = game_functions(root)
    if not funcs:
        print("coverage_check: VOID -- zero functions found in core/ or sim/.")
        return 2

    test_ids = test_identifiers(root)
    if not test_ids:
        print("coverage_check: VOID -- zero test suites found in tests/test_*.gd.")
        return 2

    covered = {name for name in funcs if name in test_ids}
    uncovered = set(funcs) - covered
    total = len(funcs)
    pct = 100.0 * len(covered) / total

    print(f"coverage_check: {len(covered)}/{total} function names in core/+sim/ are referenced "
          f"by tests ({pct:.1f}%)")
    print(f"coverage_check: threshold is {COVERAGE_FLOOR:.1f}%")

    if uncovered:
        print(f"coverage_check: {len(uncovered)} uncovered function name(s):")
        for name in sorted(uncovered, key=lambda n: -len(funcs[n]))[:20]:
            print(f"  {name} ({len(funcs[name])} file(s))")
        if len(uncovered) > 20:
            print(f"  ... and {len(uncovered) - 20} more")

    if pct < COVERAGE_FLOOR:
        print(f"coverage_check: FAIL -- {pct:.1f}% is below the {COVERAGE_FLOOR:.1f}% floor. "
              f"Add tests for the uncovered functions above, or lower the floor if the metric "
              f"overcounts uncovered (e.g. private functions called by covered public ones).")
        return 1

    print(f"coverage_check: PASS -- {pct:.1f}% meets the {COVERAGE_FLOOR:.1f}% floor.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--root", default=str(ROOT),
                        help="repository root (the mutation test points this at a fixture tree)")
    return run(Path(parser.parse_args(argv).root).resolve())


if __name__ == "__main__":
    sys.exit(main())
