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

Carries a yield counter from day one (`dashboard.py`'s YIELD section, this file's own outlier count) --
stated here, not only in the dashboard wrapper, so it is not exempted from the project's standing
retire-what-never-fires rule by feeling virtuous.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scan import all_functions, iqr_outlier_fence, run_cli, summarize  # noqa: E402

PY_LENGTH_GUARDRAIL = 42.5


def analyze(functions=None) -> dict:
    functions = all_functions() if functions is None else functions
    result = {}
    for lang in ("gd", "py"):
        lengths = [f.length for f in functions if f.lang == lang]
        fence = iqr_outlier_fence(lengths)
        outliers = sorted(
            (f for f in functions if f.lang == lang and f.length > fence),
            key=lambda f: -f.length,
        )
        result[lang] = {
            "stats": summarize(lengths),
            "fence": fence,
            "outliers": [(f.qualname, f.length) for f in outliers],
        }
    guardrail_hits = sorted(
        (f for f in functions if f.lang == "py" and f.length > PY_LENGTH_GUARDRAIL),
        key=lambda f: -f.length,
    )
    result["py"]["guardrail"] = PY_LENGTH_GUARDRAIL
    result["py"]["guardrail_hits"] = [(f.qualname, f.length) for f in guardrail_hits]
    return result


def format_report(result: dict) -> str:
    lines = ["function_length: distribution first, no gate -- outliers are IQR-fence relative to this "
             "run's own data, not an absolute rule."]
    for lang, label in (("gd", "GDScript"), ("py", "Python")):
        s = result[lang]["stats"]
        fence = result[lang]["fence"]
        outliers = result[lang]["outliers"]
        lines.append(f"\n{label}: {s['count']} functions, min {s['min']} max {s['max']} "
                     f"mean {s['mean']:.1f} median {s['median']:.1f} p90 {s['p90']:.1f} "
                     f"p95 {s['p95']:.1f}")
        lines.append(f"  IQR outlier fence: length > {fence:.1f} ({len(outliers)} function(s) above it)")
        for qualname, length in outliers[:20]:
            lines.append(f"    {length:4d} lines  {qualname}")
        if len(outliers) > 20:
            lines.append(f"    ... and {len(outliers) - 20} more")
        if lang == "py":
            guardrail = result["py"]["guardrail"]
            hits = result["py"]["guardrail_hits"]
            lines.append(f"  ADVISORY (frozen guardrail, not this run's own fence): length > "
                         f"{guardrail:.1f} ({len(hits)} function(s) above it) -- does not gate; "
                         f"see docs/DECISIONS_LEDGER.md D0098")
    return "\n".join(lines)


def main() -> int:
    return run_cli(analyze, format_report)


if __name__ == "__main__":
    sys.exit(main())
