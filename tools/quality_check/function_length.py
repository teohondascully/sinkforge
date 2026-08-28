#!/usr/bin/env python3
"""Function-length DISTRIBUTION, not a hard cap. `tools/layer_lint/check_size_limits.py` already gates
GDScript functions over 50 lines -- a fixed number, picked before this dashboard existed to show what
the real distribution looks like. This reports the distribution and flags statistical outliers
(`scan.iqr_outlier_fence`) instead, per the director's instruction: propose a threshold from the actual
numbers, don't pick one a priori. It does not replace `check_size_limits.py`'s existing gate and does
not itself gate anything -- dashboard, not enforcement (`docs/DECISIONS_LEDGER.md` D0096).

    python3 tools/quality_check/function_length.py

**Reconciled with `check_size_limits.py`'s hard 50-line cap, not left silently disagreeing with it**
(`docs/DECISIONS_LEDGER.md` D0098): that cap is a CEILING (has this function become unmaintainable), this
instrument's IQR fence is a distribution read (is this function unusual today) -- different questions, an
answer near the fence is not evidence against the cap and vice versa. Python has no hard cap at all, so
this file also carries a frozen, non-recalculating advisory guardrail for Python
(`PY_LENGTH_GUARDRAIL`, set once from this run's own fence, D0098) alongside the normal per-run
self-calibrating fence -- the guardrail answers "has the codebase's own Python size crept up since this
number was set," a question the self-calibrating fence cannot answer because it always renormalizes to
whatever the current tree looks like.

**Test code gets its own population, not its own threshold, not a pass** (`docs/DECISIONS_LEDGER.md`
D0106): test code is real code and its rot is real rot -- not exempted here. But it has a legitimately
different natural shape (assertion-heavy, many named branches) that would distort a POOLED fence for
both populations if left mixed in with production code -- the same reason `coupling.py` excludes
zero-file stub modules from its own fence (D0098). The rule: SAME self-calibrating IQR methodology,
computed against test code's OWN population, reported as its own labeled section
(`scan.is_test_func`) -- not a looser a priori number, which this project's whole dashboard-before-
threshold philosophy exists to avoid. The frozen `PY_LENGTH_GUARDRAIL` stays a single, coarse, whole-
Python-population tripwire regardless of this split -- it is an absolute drift check, not a
distributional one, and splitting it in two would be precision the guardrail's own purpose does not need.

Carries a yield counter from day one (`dashboard.py`'s YIELD section, this file's own outlier count) --
stated here, not only in the dashboard wrapper, so it is not exempted from the project's standing
retire-what-never-fires rule by feeling virtuous.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scan import all_functions, is_test_func, iqr_outlier_fence, run_cli, summarize  # noqa: E402

PY_LENGTH_GUARDRAIL = 42.5

BUCKETS = (("gd", "gd", False, "GDScript (production)"), ("gd_test", "gd", True, "GDScript (tests/)"),
           ("py", "py", False, "Python (production)"), ("py_test", "py", True, "Python (test_*.py)"))


def analyze(functions=None) -> dict:
    functions = all_functions() if functions is None else functions
    result = {}
    for bucket, lang, test, _label in BUCKETS:
        pool = [f for f in functions if f.lang == lang and is_test_func(f) == test]
        lengths = [f.length for f in pool]
        fence = iqr_outlier_fence(lengths)
        outliers = sorted((f for f in pool if f.length > fence), key=lambda f: -f.length)
        result[bucket] = {
            "stats": summarize(lengths),
            "fence": fence,
            "outliers": [(f.qualname, f.length) for f in outliers],
        }
    # The frozen guardrail is a single, coarse, whole-Python-population tripwire on purpose (see module
    # docstring) -- computed across py + py_test together, not split like the dynamic fences above.
    py_functions = [f for f in functions if f.lang == "py"]
    guardrail_hits = sorted((f for f in py_functions if f.length > PY_LENGTH_GUARDRAIL),
                             key=lambda f: -f.length)
    result["python_guardrail"] = {
        "value": PY_LENGTH_GUARDRAIL,
        "hits": [(f.qualname, f.length) for f in guardrail_hits],
    }
    return result


def format_report(result: dict) -> str:
    lines = ["function_length: distribution first, no gate -- outliers are IQR-fence relative to this "
             "run's own data, not an absolute rule. Production and test code reported as separate "
             "populations, each with its own fence (docs/DECISIONS_LEDGER.md D0106)."]
    for bucket, _lang, _test, label in BUCKETS:
        s = result[bucket]["stats"]
        fence = result[bucket]["fence"]
        outliers = result[bucket]["outliers"]
        lines.append(f"\n{label}: {s['count']} functions, min {s['min']} max {s['max']} "
                     f"mean {s['mean']:.1f} median {s['median']:.1f} p90 {s['p90']:.1f} "
                     f"p95 {s['p95']:.1f}")
        lines.append(f"  IQR outlier fence: length > {fence:.1f} ({len(outliers)} function(s) above it)")
        for qualname, length in outliers[:20]:
            lines.append(f"    {length:4d} lines  {qualname}")
        if len(outliers) > 20:
            lines.append(f"    ... and {len(outliers) - 20} more")
    guardrail = result["python_guardrail"]["value"]
    hits = result["python_guardrail"]["hits"]
    lines.append(f"\nADVISORY (frozen guardrail, whole Python population, not this run's own fence): "
                 f"length > {guardrail:.1f} ({len(hits)} function(s) above it) -- does not gate; "
                 f"see docs/DECISIONS_LEDGER.md D0098")
    return "\n".join(lines)


def main() -> int:
    return run_cli(analyze, format_report)


if __name__ == "__main__":
    sys.exit(main())
