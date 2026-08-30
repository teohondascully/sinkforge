#!/usr/bin/env python3
"""Mutation tests for the four quality instruments. Same discipline as `tools/anvil/
test_check_integrity.py` and `tools/economy_check/test_check_tier_rule.py` used (both parked, `docs/
DECISIONS_LEDGER.md` D0153-D0155): write a case that SHOULD fire, observe it actually firing, before any
of this is trusted. Dashboard tools get the same scrutiny as gates -- "reaching the check is not the same
as the check firing" doesn't stop applying just because nothing here exits nonzero yet.

    python3 tools/quality_check/test_quality_check.py

Synthetic fixtures throughout, not the real tree -- `function_length.analyze`/`complexity.analyze`/
`duplication.analyze` all accept an injectable `functions` list for exactly this reason, and
`coupling.analyze` accepts an injectable `root` (a scratch directory), mirroring `tools/anvil/
check_integrity.py`'s own `check_integrity(log_dir)` parameter (Anvil is parked, D0153-D0155, kept as a
description of the convention this mirrors) -- this project's own established fix for "a checker that can
only be pointed at the real, live tree cannot be mutation-tested without risking it."
"""
import ast
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import complexity  # noqa: E402
import coupling  # noqa: E402
import dashboard  # noqa: E402
import duplication  # noqa: E402
import function_length  # noqa: E402
import scan  # noqa: E402
from scan import Func, run_cli  # noqa: E402

import check_size_limits  # noqa: E402 -- scan.py's own import already inserts tools/layer_lint/ onto sys.path

RESULTS: list[tuple[str, bool]] = []


def check(name: str, ok: bool, detail: str = "") -> None:
    RESULTS.append((name, ok))
    status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name}" + (f" -- {detail}" if detail and not ok else ""))


def gd_func(name: str, length: int, source: str = "") -> Func:
    return Func("gd", Path("sim/x/x.gd"), name, 1, length, source or ("pass\n" * length))


def py_func_from(source: str) -> Func:
    tree = ast.parse(source)
    node = tree.body[0]
    segment = ast.get_source_segment(source, node)
    return Func("py", Path("tools/x/x.py"), node.name, node.lineno, node.end_lineno, segment, node)


# --- function_length ------------------------------------------------------------------------------

def branch_function_length_outlier() -> None:
    short = [gd_func(f"short{i}", 3) for i in range(10)]
    long_one = gd_func("very_long", 200)
    result = function_length.analyze(short + [long_one])
    outlier_names = [q for q, _len in result["gd"]["outliers"]]
    check("function_length: a 200-line function among ten 3-line ones is flagged an outlier",
          any("very_long" in q for q in outlier_names), detail=str(outlier_names))

    uniform = [gd_func(f"u{i}", 5) for i in range(10)]
    result2 = function_length.analyze(uniform)
    check("function_length: a uniform distribution flags nothing", result2["gd"]["outliers"] == [],
          detail=str(result2["gd"]["outliers"]))


def _py_func_of_length(name: str, n: int) -> Func:
    body = "\n".join(f"    x = {i}" for i in range(n - 2)) if n > 2 else ""
    src = f"def {name}():\n" + (body + "\n" if body else "") + "    return x\n" if n >= 2 else f"def {name}():\n    pass\n"
    return py_func_from(src)


def branch_function_length_guardrail() -> None:
    # A frozen guardrail must fire independently of the CURRENT run's own dynamic fence, not just
    # happen to coincide with it -- proven by constructing a synthetic set where the two disagree.
    nine_tiny = [_py_func_of_length(f"tiny{i}", 2) for i in range(9)]
    one_mid = _py_func_of_length("mid", 20)
    result = function_length.analyze(nine_tiny + [one_mid])
    dynamic_flagged = any("mid" in q for q, _l in result["py"]["outliers"])
    guardrail_flagged = any("mid" in q for q, _l in result["python_guardrail"]["hits"])
    check("function_length guardrail: a 20-line function among nine 2-line ones IS a dynamic-fence "
          "outlier (proves the dynamic fence still works on this fixture)", dynamic_flagged,
          detail=str(result["py"]["outliers"]))
    check("function_length guardrail: that SAME 20-line function is NOT a guardrail hit (20 < "
          f"{function_length.PY_LENGTH_GUARDRAIL}) -- the guardrail is a different, independent number, "
          "not a relabeling of the dynamic fence", not guardrail_flagged,
          detail=str(result["python_guardrail"]["hits"]))

    eleven_at_guardrail = [_py_func_of_length(f"atg{i}", 45) for i in range(11)]
    result2 = function_length.analyze(eleven_at_guardrail)
    check("function_length guardrail: eleven UNIFORM 45-line functions are NOT dynamic-fence outliers "
          "(uniform data has no outliers relative to itself)", result2["py"]["outliers"] == [],
          detail=str(result2["py"]["outliers"]))
    check(f"function_length guardrail: those SAME functions (45 > {function_length.PY_LENGTH_GUARDRAIL}) "
          "ARE guardrail hits -- the guardrail fires even when the dynamic fence, self-normalized to "
          "this uniform set, would not",
          len(result2["python_guardrail"]["hits"]) == 11, detail=str(result2["python_guardrail"]["hits"]))


# --- complexity -------------------------------------------------------------------------------------

def branch_complexity() -> None:
    gd_simple = "func f():\n\tpass\n"
    gd_branchy = "func f():\n\tif a:\n\t\tpass\n\telif b:\n\t\tpass\n\tfor i in x:\n\t\tpass\n"
    c_simple = complexity.gd_complexity(gd_simple)
    c_branchy = complexity.gd_complexity(gd_branchy)
    check("complexity (gd): a branchless function has complexity 1", c_simple == 1, detail=str(c_simple))
    check("complexity (gd): if+elif+for adds three decision points over base 1",
          c_branchy == 4, detail=f"got {c_branchy}, expected 4")

    py_simple = py_func_from("def f():\n    pass\n")
    py_branchy = py_func_from(
        "def f():\n    if a:\n        pass\n    elif b:\n        pass\n    for i in x:\n        pass\n"
        "    while True:\n        break\n"
    )
    pc_simple = complexity.py_complexity(py_simple.node)
    pc_branchy = complexity.py_complexity(py_branchy.node)
    check("complexity (py): a branchless function has complexity 1", pc_simple == 1,
          detail=str(pc_simple))
    check("complexity (py): if/elif/for/while all counted, nested def does not leak in",
          pc_branchy == 5, detail=f"got {pc_branchy}, expected 5")

    py_with_nested = py_func_from(
        "def outer():\n"
        "    def inner():\n"
        "        if x:\n"
        "            pass\n"
        "        if y:\n"
        "            pass\n"
        "    return inner\n"
    )
    outer_c = complexity.py_complexity(py_with_nested.node)
    check("complexity (py): a nested def's own branches do not inflate the OUTER function's count",
          outer_c == 1, detail=f"got {outer_c}, expected 1 (outer has no branches of its own)")


def _py_func_with_ifs(name: str, k: int) -> Func:
    ifs = "".join(f"    if a{i}:\n        pass\n" for i in range(k))
    return py_func_from(f"def {name}():\n{ifs}    return 0\n")


def branch_complexity_guardrail() -> None:
    # Same decoupling proof as function_length's guardrail, for complexity: the frozen guardrail must
    # fire independently of this run's own dynamic fence, not just happen to coincide with it today.
    nine_trivial = [_py_func_with_ifs(f"triv{i}", 0) for i in range(9)]
    one_branchy = _py_func_with_ifs("branchy", 4)  # complexity 1 + 4 = 5
    result = complexity.analyze(nine_trivial + [one_branchy])
    dynamic_flagged = any("branchy" in q for q, _c in result["py"]["outliers"])
    guardrail_flagged = any("branchy" in q for q, _c in result["python_guardrail"]["hits"])
    check("complexity guardrail: a complexity-5 function among nine complexity-1 ones IS a "
          "dynamic-fence outlier (proves the dynamic fence still works on this fixture)", dynamic_flagged,
          detail=str(result["py"]["outliers"]))
    check("complexity guardrail: that SAME complexity-5 function is NOT a guardrail hit (5 < "
          f"{complexity.PY_COMPLEXITY_GUARDRAIL}) -- the guardrail is a different, independent number, "
          "not a relabeling of the dynamic fence", not guardrail_flagged,
          detail=str(result["python_guardrail"]["hits"]))

    fourteen_at_guardrail = [_py_func_with_ifs(f"atg{i}", 14) for i in range(5)]  # complexity 1+14=15
    result2 = complexity.analyze(fourteen_at_guardrail)
    check("complexity guardrail: five UNIFORM complexity-15 functions are NOT dynamic-fence outliers "
          "(uniform data has no outliers relative to itself)", result2["py"]["outliers"] == [],
          detail=str(result2["py"]["outliers"]))
    check(f"complexity guardrail: those SAME functions (15 > {complexity.PY_COMPLEXITY_GUARDRAIL}) ARE "
          "guardrail hits -- the guardrail fires even when the dynamic fence, self-normalized to this "
          "uniform set, would not",
          len(result2["python_guardrail"]["hits"]) == 5, detail=str(result2["python_guardrail"]["hits"]))


# --- duplication ------------------------------------------------------------------------------------

def branch_duplication() -> None:
    src_a = "func compute_thing(value):\n\tvar total = 0\n\tfor i in range(value):\n\t\ttotal += i\n\treturn total\n"
    src_b = "func compute_other(amount):\n\tvar sum = 0\n\tfor j in range(amount):\n\t\tsum += j\n\treturn sum\n"
    src_c = "func compute_unrelated(amount):\n\tvar sum = 0\n\tfor j in range(amount):\n\t\tsum += j\n\t\tsum += 1\n\treturn sum\n"

    a = gd_func("compute_thing", 5, src_a)
    b = gd_func("compute_other", 5, src_b)
    c = gd_func("compute_unrelated", 6, src_c)
    result = duplication.analyze([a, b, c])
    clusters = result["gd"]["clusters"]
    a_and_b_together = any(a.qualname in cluster and b.qualname in cluster for cluster in clusters)
    c_alone = not any(c.qualname in cluster for cluster in clusters)
    check("duplication (gd): a renamed copy (same shape, different identifiers) is caught",
          a_and_b_together, detail=str(clusters))
    check("duplication (gd): a function with a genuinely different body is NOT clustered in",
          c_alone, detail=str(clusters))

    py_a = py_func_from("def compute_thing(value):\n    total = 0\n    for i in range(value):\n"
                          "        total += i\n    return total\n")
    py_b = py_func_from("def compute_other(amount):\n    total = 0\n    for j in range(amount):\n"
                          "        total += j\n    return total\n")
    py_result = duplication.analyze([py_a, py_b])
    py_clusters = py_result["py"]["clusters"]
    check("duplication (py): the same renamed-copy case is caught in Python too",
          any(py_a.qualname in cl and py_b.qualname in cl for cl in py_clusters), detail=str(py_clusters))

    tiny_a = gd_func("get_x", 2, "func get_x():\n\treturn x\n")
    tiny_b = gd_func("get_y", 2, "func get_y():\n\treturn y\n")
    tiny_result = duplication.analyze([tiny_a, tiny_b])
    check("duplication (gd): trivial functions under the size floor are excluded, not flagged as noise",
          tiny_result["gd"]["clusters"] == [], detail=str(tiny_result["gd"]["clusters"]))


def branch_duplication_main_exclusion() -> None:
    main_a = py_func_from("def main():\n    result = analyze()\n    print(format_report(result))\n"
                            "    return 0\n")
    main_b = py_func_from("def main():\n    result = analyze()\n    print(format_report(result))\n"
                            "    return 0\n")
    result = duplication.analyze([main_a, main_b])
    check("duplication (py): two trivial main()-shaped dispatch functions are NOT clustered",
          result["py"]["clusters"] == [], detail=str(result["py"]["clusters"]))

    # A same-length, same-token-shape function under a DIFFERENT name is not exempt -- the exclusion is
    # keyed on the name "main", not on being short.
    not_main_a = py_func_from("def dispatch():\n    result = analyze()\n    print(format_report(result))\n"
                                "    return 0\n")
    not_main_b = py_func_from("def run():\n    result = analyze()\n    print(format_report(result))\n"
                                "    return 0\n")
    result2 = duplication.analyze([not_main_a, not_main_b])
    check("duplication (py): the SAME shape under names other than main() is still caught -- the "
          "exclusion is not a generic short-function exemption",
          any(not_main_a.qualname in cl and not_main_b.qualname in cl for cl in result2["py"]["clusters"]),
          detail=str(result2["py"]["clusters"]))

    # A main() with real branching logic, over MAIN_BOILERPLATE_MAX_LINES, is not exempt either -- the
    # exclusion is length-bounded, not name-only.
    big_main_src = (
        "def main():\n"
        "    if len(sys.argv) < 2:\n"
        "        print('usage')\n"
        "        return 2\n"
        "    result = analyze(sys.argv[1])\n"
        "    if result.ok:\n"
        "        print('pass')\n"
        "        return 0\n"
        "    print('fail')\n"
        "    return 1\n"
    )
    big_main_a = py_func_from(big_main_src)
    big_main_b = py_func_from(big_main_src)
    check("duplication (py): main()'s own length still gates the exclusion -- this fixture is "
          f"{big_main_a.length} lines, over MAIN_BOILERPLATE_MAX_LINES={duplication.MAIN_BOILERPLATE_MAX_LINES}",
          big_main_a.length > duplication.MAIN_BOILERPLATE_MAX_LINES, detail=str(big_main_a.length))
    result3 = duplication.analyze([big_main_a, big_main_b])
    check("duplication (py): a real, over-threshold main() duplicated verbatim is still caught -- the "
          "exclusion does not silently swallow genuine main()-body duplication",
          any(big_main_a.qualname in cl and big_main_b.qualname in cl for cl in result3["py"]["clusters"]),
          detail=str(result3["py"]["clusters"]))


def branch_duplication_gate_exit() -> None:
    clean = {"gd": {"functions_considered": 5, "clusters": []},
             "py": {"functions_considered": 5, "clusters": []}}
    dirty_gd = {"gd": {"functions_considered": 5, "clusters": [["a", "b"]]},
                "py": {"functions_considered": 5, "clusters": []}}
    dirty_py = {"gd": {"functions_considered": 5, "clusters": []},
                "py": {"functions_considered": 5, "clusters": [["c", "d"]]}}
    check("duplication.gate_exit: 0 clusters in either language exits 0",
          duplication.gate_exit(clean) == 0, detail=str(duplication.gate_exit(clean)))
    check("duplication.gate_exit: a GDScript cluster exits 1",
          duplication.gate_exit(dirty_gd) == 1, detail=str(duplication.gate_exit(dirty_gd)))
    check("duplication.gate_exit: a Python cluster exits 1",
          duplication.gate_exit(dirty_py) == 1, detail=str(duplication.gate_exit(dirty_py)))

    # The plumbing itself, not just the pure function: run_cli must actually CALL exit_fn and return
    # its value, and must default to 0 when no exit_fn is given (the other three instruments' path).
    exit_code_no_fn = run_cli(lambda: clean, lambda r: "report text")
    exit_code_clean = run_cli(lambda: clean, lambda r: "report text", exit_fn=duplication.gate_exit)
    exit_code_dirty = run_cli(lambda: dirty_gd, lambda r: "report text", exit_fn=duplication.gate_exit)
    check("run_cli: no exit_fn given defaults to 0 (function_length/complexity/coupling's own path)",
          exit_code_no_fn == 0, detail=str(exit_code_no_fn))
    check("run_cli: exit_fn given and the result is clean returns 0",
          exit_code_clean == 0, detail=str(exit_code_clean))
    check("run_cli: exit_fn given and the result is dirty returns exit_fn's own verdict (1), proving "
          "run_cli actually calls exit_fn rather than ignoring it", exit_code_dirty == 1,
          detail=str(exit_code_dirty))


# --- coupling ---------------------------------------------------------------------------------------

def _write(root: Path, rel: str, content: str) -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def branch_coupling_sim_path_and_class_name() -> None:
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _write(root, "sim/mod_a/mod_a.gd", "class_name TypeA\nfunc foo():\n\tpass\n")
        _write(root, "sim/mod_b/mod_b.gd", "func bar():\n\tvar x = TypeA.new()\n")
        _write(root, "sim/mod_c/mod_c.gd", 'func baz():\n\tpreload("res://sim/mod_a/mod_a.gd")\n')
        result = coupling.analyze(root)
        fan_in_a = result["sim"]["fan_in"]["mod_a"]
        check("coupling (sim): class_name-only usage (no preload) is still a real edge",
              "mod_b" in {s for s, dst in coupling._sim_class_name_edges(root) if dst == "mod_a"},
              detail=str(coupling._sim_class_name_edges(root)))
        check("coupling (sim): mod_a's fan-in counts both the class_name edge and the preload edge",
              fan_in_a == 2, detail=f"got {fan_in_a}, expected 2 (mod_b via class_name, mod_c via preload)")


def branch_coupling_stub_exclusion() -> None:
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _write(root, "sim/mod_a/mod_a.gd", "class_name TypeA\nfunc foo():\n\tpass\n")
        _write(root, "sim/mod_b/mod_b.gd", "func bar():\n\tvar x = TypeA.new()\n")
        (root / "sim" / "empty_stub_one").mkdir(parents=True)
        (root / "sim" / "empty_stub_two").mkdir(parents=True)
        result = coupling.analyze(root)
        check("coupling: a module directory with zero .gd files is named in 'stubs', not silently "
              "dropped", set(result["sim"]["stubs"]) == {"empty_stub_one", "empty_stub_two"},
              detail=str(result["sim"]["stubs"]))
        check("coupling: that same stub module does NOT appear in 'modules' (the corpus used for "
              "fan-in/fan-out and the outlier fence)",
              "empty_stub_one" not in result["sim"]["modules"]
              and "empty_stub_two" not in result["sim"]["modules"],
              detail=str(result["sim"]["modules"]))
        check("coupling: a real module (mod_a, mod_b) still appears in 'modules', unaffected by the "
              "stub exclusion", {"mod_a", "mod_b"} <= set(result["sim"]["modules"]),
              detail=str(result["sim"]["modules"]))


def branch_coupling_tools_import_resolution() -> None:
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _write(root, "tools/sub1/helper.py", "X = 1\n")
        _write(root, "tools/sub2/consumer.py", "from helper import X\n")
        _write(root, "tools/sub1/schema.py", "Y = 1\n")
        _write(root, "tools/sub2/schema.py", "Y = 2\n")
        _write(root, "tools/sub2/user.py", "from schema import Y\n")
        _write(root, "tools/sub1/ambig.py", "Z = 1\n")
        _write(root, "tools/sub3/ambig.py", "Z = 2\n")
        _write(root, "tools/sub2/user2.py", "import ambig\n")

        edges = coupling._tools_edges(root)
        check("coupling (tools): an import resolving to exactly one OTHER module is a real edge",
              ("sub2", "sub1") in edges and edges.count(("sub2", "sub1")) == 1, detail=str(edges))
        check("coupling (tools): a name that ALSO exists locally resolves locally, no cross-module edge "
              "for it (the anvil/economy_check schema.py collision -- both parked, D0153-D0155 -- "
              "synthetically reproduced since the real files are gone)",
              edges.count(("sub2", "sub1")) == 1,  # only the helper.py edge, not one from schema.py too
              detail=str(edges))
        check("coupling (tools): a name matching MULTIPLE other modules with no local match is "
              "ambiguous and is not counted, not guessed",
              not any(dst in ("sub1", "sub3") and src == "sub2" and dst != "sub1" for src, dst in edges)
              and edges.count(("sub2", "sub3")) == 0,
              detail=str(edges))


# --- scan scope ---------------------------------------------------------------------------------------

def branch_find_gd_files_reaches_whole_tree() -> None:
    files = set(str(p) for p in scan.find_gd_files())
    check("find_gd_files: reaches tests/ (D0102 -- was GAME_DIRS-only, missing it entirely)",
          any(f.startswith("tests/") for f in files), detail=str([f for f in files if "test" in f][:3]))
    check("find_gd_files: still excludes legacy/ (the one exclusion check_size_limits.py itself uses)",
          not any(f.startswith("legacy/") for f in files))

    # Real parity, not a hardcoded count that would go stale the moment any .gd file is added or
    # removed anywhere in the tree: compute check_size_limits.py's OWN file list directly and assert
    # the two scanners agree exactly, not just that scan.py's is a superset.
    check_size_limits_files = set(str(p) for p in check_size_limits.find_gd_files())
    check("find_gd_files: matches check_size_limits.py's own file list EXACTLY (same scope, not just "
          "a superset that happens to include tests/)", files == check_size_limits_files,
          detail=f"only in scan: {files - check_size_limits_files}, only in check_size_limits: "
                 f"{check_size_limits_files - files}")


# --- dashboard smoke test ----------------------------------------------------------------------------

def branch_dashboard_runs_end_to_end() -> None:
    text, combined = dashboard.run()
    ok = ("DUPLICATION" in text and "yield" in combined
          and set(combined["yield"]) == {"duplication_clusters", "length_outliers",
                                          "complexity_outliers", "coupling_outliers"})
    check("dashboard: runs end to end against the real tree, produces all four sections + a yield "
          "summary", ok)


def main() -> int:
    for branch in (branch_function_length_outlier, branch_function_length_guardrail,
                   branch_complexity, branch_complexity_guardrail, branch_duplication,
                   branch_duplication_main_exclusion, branch_duplication_gate_exit,
                   branch_coupling_sim_path_and_class_name, branch_coupling_tools_import_resolution,
                   branch_coupling_stub_exclusion,
                   branch_find_gd_files_reaches_whole_tree,
                   branch_dashboard_runs_end_to_end):
        branch()

    failed = [name for name, ok in RESULTS if not ok]
    print()
    print(f"test_quality_check: {len(RESULTS) - len(failed)}/{len(RESULTS)} cases observed correctly.")
    if failed:
        print("test_quality_check: FAIL -- these branches did not fire as expected:")
        for name in failed:
            print(f"  {name}")
        return 1

    print("test_quality_check: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
