#!/usr/bin/env python3
"""Mutation tests for tools/coverage_check.py.

    python3 tools/test_coverage_check.py

Synthetic fixtures in temp directories — never the real tree, matching the pattern every other gate's
mutation test file in this repository uses (`docs/QUALITY.md` §2: "a check that has never been
observed failing is not a check").
"""
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[0] / "layer_lint"))
from gate_test_support import Observations, init_scratch, write_file  # noqa: E402

import coverage_check as C  # noqa: E402

LOG = Observations("test_coverage_check")


def branch_covered_function() -> None:
    """A function whose name appears in a test suite is covered."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "core/player.gd", "class_name Player\nfunc take_damage():\n\tpass\n")
        write_file(root, "tests/test_player.gd", "func _test_damage():\n\tvar p = Player.new()\n\tp.take_damage()\n")
        funcs = C.game_functions(root)
        test_ids = C.test_identifiers(root)
        LOG.observe("covered: a function name in a test is counted as covered",
                    "take_damage" in test_ids and "take_damage" in {n for n in funcs if n in test_ids})


def branch_uncovered_function() -> None:
    """A function whose name does NOT appear in any test is uncovered."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "core/player.gd", "class_name Player\nfunc secret_method():\n\tpass\n")
        write_file(root, "tests/test_player.gd", "func _test_something():\n\tpass\n")
        funcs = C.game_functions(root)
        test_ids = C.test_identifiers(root)
        LOG.observe("uncovered: a function name NOT in any test is uncovered",
                    "secret_method" in funcs and "secret_method" not in test_ids)


def branch_threshold_fires() -> None:
    """Coverage below the floor exits 1."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        # 5 functions, only 1 covered = 20% < 60%
        write_file(root, "core/mod.gd",
               "class_name Mod\nfunc a():\n\tpass\nfunc b():\n\tpass\n"
               "func c():\n\tpass\nfunc d():\n\tpass\nfunc e():\n\tpass\n")
        write_file(root, "tests/test_mod.gd", "func _test_a():\n\ta()\n")
        exit_code = C.run(root)
        LOG.observe("threshold: 20% coverage (1/5) exits 1", exit_code == 1, detail=f"exit={exit_code}")


def branch_threshold_passes() -> None:
    """Coverage at or above the floor exits 0."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        # 2 functions, both covered = 100% > 60%
        write_file(root, "core/mod.gd", "class_name Mod\nfunc alpha():\n\tpass\nfunc beta():\n\tpass\n")
        write_file(root, "tests/test_mod.gd", "func _test_ab():\n\talpha()\n\tbeta()\n")
        exit_code = C.run(root)
        LOG.observe("threshold: 100% coverage (2/2) exits 0", exit_code == 0, detail=f"exit={exit_code}")


def branch_void_no_game_functions() -> None:
    """No game functions at all exits 2 (VOID)."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "tests/test_dummy.gd", "func _test():\n\tpass\n")
        exit_code = C.run(root)
        LOG.observe("void: no game functions exits 2", exit_code == 2, detail=f"exit={exit_code}")


def branch_void_no_tests() -> None:
    """No test suites exits 2 (VOID)."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "core/mod.gd", "func foo():\n\tpass\n")
        exit_code = C.run(root)
        LOG.observe("void: no test suites exits 2", exit_code == 2, detail=f"exit={exit_code}")


def branch_engine_called_excluded() -> None:
    """Engine-called functions (_init, _ready, _to_string) are excluded from the denominator —
    they are covered by the engine, not by tests, and counting them as uncovered would understate
    the real coverage."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "core/mod.gd",
               "class_name Mod\nfunc _init():\n\tpass\nfunc _ready():\n\tpass\nfunc real_func():\n\tpass\n")
        write_file(root, "tests/test_mod.gd", "func _test():\n\treal_func()\n")
        funcs = C.game_functions(root)
        LOG.observe("engine-called: _init and _ready excluded from denominator",
                    "_init" not in funcs and "_ready" not in funcs and "real_func" in funcs,
                    detail=str(set(funcs)))


def branch_comment_not_coverage() -> None:
    """A function name mentioned in a COMMENT in a test file does NOT count as covered —
    `gd_source.blank_comments_and_strings` blanks comments before scanning identifiers."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "core/mod.gd", "func hidden():\n\tpass\n")
        write_file(root, "tests/test_mod.gd", "# hidden is not tested yet\nfunc _test():\n\tpass\n")
        test_ids = C.test_identifiers(root)
        LOG.observe("comment-blanking: a function name in a comment does NOT count as covered",
                    "hidden" not in test_ids, detail=f"test_ids={test_ids}")


def branch_string_not_coverage() -> None:
    """A function name in a STRING LITERAL in a test does NOT count as covered."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "core/mod.gd", "func untested():\n\tpass\n")
        write_file(root, "tests/test_mod.gd", 'func _test():\n\tvar s = "untested"\n\tpass\n')
        test_ids = C.test_identifiers(root)
        LOG.observe("string-blanking: a function name in a string does NOT count as covered",
                    "untested" not in test_ids, detail=f"test_ids={test_ids}")


def branch_name_collision() -> None:
    """Two functions sharing a name in different files are ONE unit in the denominator,
    and one test reference covers both. This is the gate's key modelling choice — coverage
    is keyed by name, not by (file, name) — and it means the denominator is smaller than
    the real declaration count. The gate must disclose this wherever it is cited."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        init_scratch(root)
        write_file(root, "core/mod_a.gd", "func shared():\n\tpass\n")
        write_file(root, "sim/mod_b.gd", "func shared():\n\tpass\n")
        write_file(root, "tests/test_mod.gd", "func _test():\n\tshared()\n")
        funcs = C.game_functions(root)
        LOG.observe("name-collision: two same-named functions are ONE unit in the denominator",
                    "shared" in funcs and len(funcs["shared"]) == 2,
                    detail=f"files={funcs.get('shared', set())}")
        covered = {name for name in funcs if name in C.test_identifiers(root)}
        LOG.observe("name-collision: one test reference covers BOTH definitions",
                    "shared" in covered,
                    detail=f"covered={covered}")


def main() -> int:
    for branch in (branch_covered_function, branch_uncovered_function,
                   branch_threshold_fires, branch_threshold_passes,
                   branch_void_no_game_functions, branch_void_no_tests,
                   branch_engine_called_excluded, branch_comment_not_coverage,
                   branch_string_not_coverage, branch_name_collision):
        branch()
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
