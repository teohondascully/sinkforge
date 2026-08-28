#!/usr/bin/env python3
"""Cyclomatic complexity per function, distribution + outliers -- `check_size_limits.py`'s own docstring
names this as a real gap ("Cyclomatic complexity is NOT checked here... if that gate is wanted later it
needs a real branch-counting pass, not a line-based approximation pretending to be one"). This is that
real pass, for both languages.

    python3 tools/quality_check/complexity.py

**Two different confidence levels, stated plainly:**
- Python: exact, via `ast` -- counts `if`/`for`/`while`/`except` clauses, each `and`/`or` operand beyond
  the first, ternary expressions, comprehension `if`-filters (plus the comprehension's own implicit
  loop), and `match` case arms if the running interpreter supports `ast.Match` (3.10+). Descends into a
  function's own body only -- a nested `def`/`lambda`/`class` does NOT contribute to its enclosing
  function's count; it gets its own count when it's measured as its own function.
- GDScript: approximate, via `scan.gd_tokenize`'s token stream -- counts occurrences of
  `if`/`elif`/`for`/`while`/`and`/`or`/`match` keyword tokens. `match` counts once regardless of how
  many `when`/case arms it has (this tokenizer has no notion of a match arm) -- a real undercounting for
  large match blocks, named here rather than silently accepted as precise.

McCabe's base complexity is 1 (a function with no branches has complexity 1, not 0).

Python also carries a frozen, non-recalculating advisory guardrail (`PY_COMPLEXITY_GUARDRAIL`, set once
from this run's own fence, `docs/DECISIONS_LEDGER.md` D0098) alongside the normal per-run self-
calibrating fence -- same reasoning as `function_length.py`'s: the self-calibrating fence always
renormalizes to whatever the current tree looks like, so it cannot by itself show the codebase's own
complexity creeping up over time the way a fixed reference point can.

Carries a yield counter from day one (`dashboard.py`'s YIELD section, this file's own outlier count) --
stated here, not only in the dashboard wrapper, so it is not exempted from the project's standing
retire-what-never-fires rule by feeling virtuous.
"""
import sys
from pathlib import Path

import ast

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scan import all_functions, gd_tokenize, iqr_outlier_fence, run_cli, summarize  # noqa: E402

PY_COMPLEXITY_GUARDRAIL = 13.5

GD_DECISION_KEYWORDS = {"if", "elif", "for", "while", "and", "or", "match"}
_STOP_TYPES = (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda, ast.ClassDef)
_SIMPLE_BRANCH_TYPES = (ast.If, ast.For, ast.AsyncFor, ast.While, ast.ExceptHandler, ast.IfExp)


def _walk_own_body(node):
    for child in ast.iter_child_nodes(node):
        yield child
        if not isinstance(child, _STOP_TYPES):
            yield from _walk_own_body(child)


def gd_complexity(source: str) -> int:
    toks = gd_tokenize(source)
    return 1 + sum(1 for kind, text in toks if kind == "KEYWORD" and text in GD_DECISION_KEYWORDS)


def py_complexity(node: ast.AST) -> int:
    complexity = 1
    for child in _walk_own_body(node):
        if isinstance(child, _SIMPLE_BRANCH_TYPES):
            complexity += 1
        elif isinstance(child, ast.BoolOp):
            complexity += max(len(child.values) - 1, 0)
        elif isinstance(child, ast.comprehension):
            complexity += 1 + len(child.ifs)
        elif hasattr(ast, "Match") and isinstance(child, ast.Match):
            complexity += len(child.cases)
    return complexity


def analyze(functions=None) -> dict:
    functions = all_functions() if functions is None else functions
    result = {}
    py_scored = []
    for lang in ("gd", "py"):
        scored = []
        for f in functions:
            if f.lang != lang:
                continue
            c = gd_complexity(f.source) if lang == "gd" else py_complexity(f.node)
            scored.append((f, c))
        if lang == "py":
            py_scored = scored
        values = [c for _f, c in scored]
        fence = iqr_outlier_fence(values)
        outliers = sorted((item for item in scored if item[1] > fence), key=lambda item: -item[1])
        result[lang] = {
            "stats": summarize(values),
            "fence": fence,
            "outliers": [(f.qualname, c) for f, c in outliers],
        }
    guardrail_hits = sorted(
        (item for item in py_scored if item[1] > PY_COMPLEXITY_GUARDRAIL),
        key=lambda item: -item[1],
    )
    result["py"]["guardrail"] = PY_COMPLEXITY_GUARDRAIL
    result["py"]["guardrail_hits"] = [(f.qualname, c) for f, c in guardrail_hits]
    return result


def format_report(result: dict) -> str:
    lines = ["complexity: McCabe cyclomatic complexity per function, distribution first, no gate."]
    for lang, label in (("gd", "GDScript"), ("py", "Python")):
        s = result[lang]["stats"]
        fence = result[lang]["fence"]
        outliers = result[lang]["outliers"]
        lines.append(f"\n{label}: {s['count']} functions, min {s['min']} max {s['max']} "
                     f"mean {s['mean']:.1f} median {s['median']:.1f} p90 {s['p90']:.1f} "
                     f"p95 {s['p95']:.1f}")
        lines.append(f"  IQR outlier fence: complexity > {fence:.1f} ({len(outliers)} function(s) "
                     f"above it)")
        for qualname, c in outliers[:20]:
            lines.append(f"    complexity {c:3d}  {qualname}")
        if len(outliers) > 20:
            lines.append(f"    ... and {len(outliers) - 20} more")
        if lang == "py":
            guardrail = result["py"]["guardrail"]
            hits = result["py"]["guardrail_hits"]
            lines.append(f"  ADVISORY (frozen guardrail, not this run's own fence): complexity > "
                         f"{guardrail:.1f} ({len(hits)} function(s) above it) -- does not gate; "
                         f"see docs/DECISIONS_LEDGER.md D0098")
    return "\n".join(lines)


def main() -> int:
    return run_cli(analyze, format_report)


if __name__ == "__main__":
    sys.exit(main())
