#!/usr/bin/env python3
"""Duplication detection, token-level after identifier normalization -- the specific legacy failure
(`docs/DECISIONS_LEDGER.md` D0096: "the previous project carried six near-identical copies of one
function across fifty layers and nothing flagged it, because nothing was looking"). Catches RENAMED
copies, not just literal text matches: two functions with the exact same token sequence once every
identifier (variable/function/parameter name) is replaced with a placeholder are flagged together,
regardless of what either copy's identifiers are actually called.

    python3 tools/quality_check/duplication.py

**Scope, stated precisely because "catches duplication" oversells it if left vague:**
- Literals (numbers, strings) are NOT normalized -- kept as their exact text. Two functions that differ
  only in a literal value do not match. This is deliberate: normalizing literals too would flag
  structurally-similar-but-substantively-different code (e.g. two test fixtures with the same shape but
  different domain data) as "duplicates," which is noise, not the failure this exists to catch. The
  director's own framing named the target precisely: "renamed copies must be caught" -- renaming, not
  reconstanting.
- Comparison is per language (GDScript functions are never compared against Python ones) and per whole
  FUNCTION (no partial-block or cross-function-boundary matching -- a hard problem this doesn't attempt,
  and the legacy failure was function-shaped, not block-shaped).
- Functions under MIN_LINES lines or MIN_TOKENS normalized tokens are excluded -- otherwise every
  trivial one-line getter across the codebase collides with every other one-line getter, which is noise,
  not signal. Both constants are tunable and stated here, not buried.
- Exact match only after normalization (no fuzzy/edit-distance matching). A near-miss that also
  reorders statements or adds/removes one line is NOT caught. Stated as a real boundary, not silently
  assumed solved.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scan import all_functions, gd_tokenize, py_tokenize_source  # noqa: E402

MIN_LINES = 4
MIN_TOKENS = 15


def _normalize(tokens: list[tuple[str, str]]) -> tuple:
    return tuple("ID" if kind == "ID" else text for kind, text in tokens)


def analyze(functions=None) -> dict:
    functions = all_functions() if functions is None else functions
    result = {}
    for lang, tokenize in (("gd", gd_tokenize), ("py", py_tokenize_source)):
        considered = 0
        groups: dict[tuple, list] = {}
        for f in functions:
            if f.lang != lang or f.length < MIN_LINES:
                continue
            toks = tokenize(f.source)
            if len(toks) < MIN_TOKENS:
                continue
            considered += 1
            groups.setdefault(_normalize(toks), []).append(f)
        clusters = [members for members in groups.values() if len(members) > 1]
        clusters.sort(key=lambda members: -len(members))
        result[lang] = {
            "functions_considered": considered,
            "clusters": [[m.qualname for m in members] for members in clusters],
        }
    return result


def format_report(result: dict) -> str:
    lines = [f"duplication: identifier-normalized, exact-match, per-function (MIN_LINES={MIN_LINES}, "
             f"MIN_TOKENS={MIN_TOKENS}) -- see module docstring for what this does not catch."]
    total_clusters = sum(len(result[lang]["clusters"]) for lang in ("gd", "py"))
    for lang, label in (("gd", "GDScript"), ("py", "Python")):
        r = result[lang]
        lines.append(f"\n{label}: {r['functions_considered']} function(s) considered, "
                     f"{len(r['clusters'])} duplicate cluster(s)")
        for cluster in r["clusters"]:
            lines.append(f"  cluster of {len(cluster)}:")
            for qualname in cluster:
                lines.append(f"    {qualname}")
    if total_clusters == 0:
        lines.append("\nNo duplicate clusters found above the size floor, in either language.")
    return "\n".join(lines)


def main() -> int:
    result = analyze()
    print(format_report(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
