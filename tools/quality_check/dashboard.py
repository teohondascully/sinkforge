#!/usr/bin/env python3
"""Runs all four instruments and prints one combined report. Dashboard, not a gate -- every instrument
here reports a distribution and flags outliers relative to that distribution; none of them exits nonzero
on a finding, and none of them is wired into CI yet (`docs/DECISIONS_LEDGER.md` D0096). Thresholds get
proposed from what this prints, not decided in advance of it.

    python3 tools/quality_check/dashboard.py

**Duplication is reported first and is the headline finding**, not because it is the only thing that
matters but because it is the one that actually happened: the legacy failure this whole suite exists to
catch was the same function copied until nobody could tell which version was authoritative. A
duplication finding here is worth more than a complexity or length finding, and the report order says so
rather than leaving that judgment implicit in four equally-weighted sections.

**Yield, from day one.** Each instrument's finding count below is this run's yield -- the first recorded
data point for each, not a historical rate (no persistence layer exists yet; that's future work if/when
these become real gates). A quality instrument that never yields a finding after the defect that
motivated it is a retirement candidate under this project's own standing rule for every instrument, gate
included -- stated here so that rule has something to be checked against later, not only asserted now.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import complexity  # noqa: E402
import coupling  # noqa: E402
import duplication  # noqa: E402
import function_length  # noqa: E402
from scan import all_functions  # noqa: E402


def run() -> tuple[str, dict]:
    functions = all_functions()

    dup_result = duplication.analyze(functions)
    len_result = function_length.analyze(functions)
    cx_result = complexity.analyze(functions)
    coupling_result = coupling.analyze()

    dup_clusters = sum(len(dup_result[lang]["clusters"]) for lang in ("gd", "py"))
    len_outliers = sum(len(len_result[bucket]["outliers"]) for bucket, *_ in function_length.BUCKETS)
    cx_outliers = sum(len(cx_result[bucket]["outliers"]) for bucket, *_ in complexity.BUCKETS)
    coupling_outliers = sum(len(coupling_result[scope]["outliers"]) for scope in ("sim", "tools"))

    lines = [
        "=" * 88,
        "QUALITY DASHBOARD -- distribution report, not a gate. No exit code reacts to any finding here.",
        "=" * 88,
        "",
        "YIELD, this run (the first recorded data point for each instrument):",
        f"  duplication clusters:     {dup_clusters}",
        f"  function-length outliers: {len_outliers}",
        f"  complexity outliers:      {cx_outliers}",
        f"  coupling outliers:        {coupling_outliers}",
        "",
        "-" * 88,
        "1. DUPLICATION -- reported first: this is the failure that actually happened last time.",
        "-" * 88,
        duplication.format_report(dup_result),
        "",
        "-" * 88,
        "2. FUNCTION LENGTH",
        "-" * 88,
        function_length.format_report(len_result),
        "",
        "-" * 88,
        "3. CYCLOMATIC COMPLEXITY",
        "-" * 88,
        complexity.format_report(cx_result),
        "",
        "-" * 88,
        "4. MODULE COUPLING",
        "-" * 88,
        coupling.format_report(coupling_result),
    ]
    combined = {
        "duplication": dup_result, "function_length": len_result, "complexity": cx_result,
        "coupling": coupling_result,
        "yield": {"duplication_clusters": dup_clusters, "length_outliers": len_outliers,
                  "complexity_outliers": cx_outliers, "coupling_outliers": coupling_outliers},
    }
    return "\n".join(lines), combined


def main() -> int:
    text, _combined = run()
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
