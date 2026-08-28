#!/usr/bin/env python3
"""Mutation tests for the four quality instruments. Same discipline as `tools/anvil/
test_check_integrity.py` and `tools/economy_check/test_check_tier_rule.py`: write a case that SHOULD
fire, observe it actually firing, before any of this is trusted. Dashboard tools get the same scrutiny
as gates -- "reaching the check is not the same as the check firing" doesn't stop applying just because
nothing here exits nonzero yet.

    python3 tools/quality_check/test_quality_check.py

Synthetic fixtures throughout, not the real tree -- `function_length.analyze`/`complexity.analyze`/
`duplication.analyze` all accept an injectable `functions` list for exactly this reason, and
`coupling.analyze` accepts an injectable `root` (a scratch directory), mirroring `tools/anvil/
check_integrity.py`'s own `check_integrity(log_dir)` parameter -- this project's own established fix for
"a checker that can only be pointed at the real, live tree cannot be mutation-tested without risking it."
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
from scan import Func  # noqa: E402

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
              "for it (the anvil/economy_check schema.py collision, synthetically reproduced)",
              edges.count(("sub2", "sub1")) == 1,  # only the helper.py edge, not one from schema.py too
              detail=str(edges))
        check("coupling (tools): a name matching MULTIPLE other modules with no local match is "
              "ambiguous and is not counted, not guessed",
              not any(dst in ("sub1", "sub3") and src == "sub2" and dst != "sub1" for src, dst in edges)
              and edges.count(("sub2", "sub3")) == 0,
              detail=str(edges))


# --- dashboard smoke test ----------------------------------------------------------------------------

def branch_dashboard_runs_end_to_end() -> None:
    text, combined = dashboard.run()
    ok = ("DUPLICATION" in text and "yield" in combined
          and set(combined["yield"]) == {"duplication_clusters", "length_outliers",
                                          "complexity_outliers", "coupling_outliers"})
    check("dashboard: runs end to end against the real tree, produces all four sections + a yield "
          "summary", ok)


def main() -> int:
    for branch in (branch_function_length_outlier, branch_complexity, branch_duplication,
                   branch_coupling_sim_path_and_class_name, branch_coupling_tools_import_resolution,
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
