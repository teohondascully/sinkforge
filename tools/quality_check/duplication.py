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
- Python `main()` entry-point dispatch functions at or under `MAIN_BOILERPLATE_MAX_LINES` lines are
  excluded from comparison -- see `_is_trivial_main_dispatch` for the exact rule and the risk this
  trades away, logged as a decision per `docs/DECISIONS_LEDGER.md` D0097.

Carries a yield counter from day one (`dashboard.py`'s YIELD section, this file's own cluster count) --
stated here, not only in the dashboard wrapper, so it is not exempted from the project's standing
retire-what-never-fires rule by feeling virtuous.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scan import all_functions, gd_tokenize, py_tokenize_source, run_cli  # noqa: E402

MIN_LINES = 4
MIN_TOKENS = 15
MAIN_BOILERPLATE_MAX_LINES = 8


def _normalize(tokens: list[tuple[str, str]]) -> tuple:
    return tuple("ID" if kind == "ID" else text for kind, text in tokens)


def _is_trivial_main_dispatch(f) -> bool:
    """True for a Python function literally named `main`, taking this repo's own zero-argument CLI
    entry-point shape, at most `MAIN_BOILERPLATE_MAX_LINES` lines long -- the one structural pattern
    this whole `tools/` tree repeats on purpose (every instrument here and in `tools/economy_check/`,
    `tools/anvil/`, `tools/layer_lint/` ends `def main() -> int: ...` / `sys.exit(main())`), not logic
    duplication in the sense this detector exists to catch (`docs/DECISIONS_LEDGER.md` D0096's "the
    previous project carried six near-identical copies of one function... because nothing was
    looking"). Named and length-bounded, not a blanket "skip anything called main": checked against
    every OTHER `main()` in this repo before picking the bound -- `check_tier_rule.py`'s --json
    dispatch, `check_integrity.py`'s bootstrap-state check, and every `layer_lint/` gate's own
    violation-printing are all real branching logic well over this threshold, and stay fully compared.

    Risk, stated per D0097 rather than left implicit: if a future `main()` is BOTH genuinely duplicated
    AND happens to fit within `MAIN_BOILERPLATE_MAX_LINES`, this exclusion hides that duplication from
    the report. Accepted because the alternative -- raising `MIN_LINES`/`MIN_TOKENS` generally to clear
    this one known shape -- would have hidden real duplication of a DIFFERENT shape elsewhere instead,
    which is the actual failure mode this instrument exists to catch. A named, narrow exclusion trades a
    small, stated risk for keeping the general detector at full sensitivity."""
    return f.lang == "py" and f.name == "main" and f.length <= MAIN_BOILERPLATE_MAX_LINES


def analyze(functions=None) -> dict:
    functions = all_functions() if functions is None else functions
    result = {}
    for lang, tokenize in (("gd", gd_tokenize), ("py", py_tokenize_source)):
        considered = 0
        groups: dict[tuple, list] = {}
        for f in functions:
            if f.lang != lang or f.length < MIN_LINES:
                continue
            if _is_trivial_main_dispatch(f):
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


def gate_exit(result: dict) -> int:
    """1 if any duplicate cluster was found in either language, else 0 -- CI's blocking check
    (`docs/DECISIONS_LEDGER.md` D0099). The only one of the four instruments that gates: 0 clusters is
    this project's current, verified-clean state, so a regression here is a fact about the tree a build
    should refuse, not merely report."""
    total = sum(len(result[lang]["clusters"]) for lang in ("gd", "py"))
    return 1 if total else 0


def main() -> int:
    return run_cli(analyze, format_report, exit_fn=gate_exit)


if __name__ == "__main__":
    sys.exit(main())
