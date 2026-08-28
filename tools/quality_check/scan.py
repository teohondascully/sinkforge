"""Shared scanning primitives for tools/quality_check/'s four instruments -- file discovery, function-
span extraction, and tokenization for both languages this repo uses. Factored out once four consumers
needed the same thing, not built speculatively: a duplication detector whose own source duplicates this
logic across four files would be the tool disproving its own reason to exist.

GDScript function-span extraction is imported directly from `tools/layer_lint/check_size_limits.py`
(`function_spans`, `FUNC_NAME_RE`, `indent_of`) rather than reimplemented -- that scanner already
handles the "declaration forms a scan omits" class of bug (`static func` alongside `func`) and the
trailing-comment attribution edge case, both found the hard way in this exact codebase before. Python
function spans use the stdlib `ast` module, which needs none of that hand-rolled care.

Two tokenizers, two different confidence levels, stated plainly:
- Python: `tokenize` (stdlib) over `ast.get_source_segment`'s exact text for a function -- exact,
  language-correct, the real grammar.
- GDScript: a hand-rolled regex tokenizer, because no accessible GDScript parser exists in pure Python
  and invoking Godot itself for this would mean booting the engine to measure code metrics. This is an
  approximation: it recognizes identifiers/keywords/literals/operators by pattern, not real grammar,
  and `GD_KEYWORDS` is a hand-maintained list that could be incomplete. Good enough for duplication and
  complexity detection over well-formed code (which is all this repository has); not a substitute for
  a real GDScript frontend.
"""
from __future__ import annotations

import ast
import io
import keyword
import re
import sys
import tokenize as py_tokenize
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "layer_lint"))
from check_size_limits import FUNC_NAME_RE, function_spans as gd_function_spans, indent_of  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

GAME_DIRS = ("core", "sim", "interface", "view", "shell")
INSTRUMENT_DIRS = ("harness", "experiment", "tools")
SCRATCH_PREFIX = "tools/scratch"


def find_gd_files() -> list[Path]:
    """Every .gd file under the game dirs, legacy/ excluded -- same scope check_size_limits.py uses."""
    out = []
    for dirname in GAME_DIRS:
        base = ROOT / dirname
        if not base.is_dir():
            continue
        out.extend(sorted(p.relative_to(ROOT) for p in base.rglob("*.gd")))
    return out


def find_py_files() -> list[Path]:
    """Every .py file under the instrument dirs, tools/scratch/ excluded -- check_loc_ratio.py's own
    scope, minus test/tools infra this scan has no reason to special-case."""
    out = []
    for dirname in INSTRUMENT_DIRS:
        base = ROOT / dirname
        if not base.is_dir():
            continue
        for p in base.rglob("*.py"):
            rel = p.relative_to(ROOT)
            if rel.as_posix().startswith(SCRATCH_PREFIX + "/"):
                continue
            out.append(rel)
    return sorted(out)


class Func:
    """One function, either language, in one shape the four instruments share."""

    __slots__ = ("lang", "path", "name", "start_line", "end_line", "source", "node")

    def __init__(self, lang, path, name, start_line, end_line, source, node=None):
        self.lang = lang
        self.path = path
        self.name = name
        self.start_line = start_line
        self.end_line = end_line
        self.source = source
        self.node = node  # the ast.FunctionDef, python only -- None for gdscript

    @property
    def length(self) -> int:
        return self.end_line - self.start_line + 1

    @property
    def qualname(self) -> str:
        return f"{self.path}:{self.start_line}:{self.name}"


def gd_functions(rel_path: Path) -> list[Func]:
    text = (ROOT / rel_path).read_text(encoding="utf-8", errors="replace")
    lines = text.splitlines()
    out = []
    for name, start, length in gd_function_spans(lines):
        end = start + length - 1
        source = "\n".join(lines[start - 1:end])
        out.append(Func("gd", rel_path, name, start, end, source))
    return out


def py_functions(rel_path: Path) -> list[Func]:
    text = (ROOT / rel_path).read_text(encoding="utf-8", errors="replace")
    try:
        tree = ast.parse(text, filename=str(rel_path))
    except SyntaxError:
        return []
    out = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
            segment = ast.get_source_segment(text, node)
            if segment is None or node.end_lineno is None:
                continue
            out.append(Func("py", rel_path, node.name, node.lineno, node.end_lineno, segment, node))
    return out


def all_functions() -> list[Func]:
    out = []
    for rel in find_gd_files():
        out.extend(gd_functions(rel))
    for rel in find_py_files():
        out.extend(py_functions(rel))
    return out


# --- GDScript tokenizer -------------------------------------------------------------------------------

GD_KEYWORDS = {
    "if", "elif", "else", "for", "while", "match", "break", "continue", "pass", "return",
    "func", "static", "class", "class_name", "extends", "is", "as", "self", "signal", "await",
    "yield", "var", "const", "enum", "and", "or", "not", "in", "true", "false", "null", "void",
    "preload", "assert", "breakpoint", "export", "onready", "tool", "setget", "master", "puppet",
    "remote", "remotesync", "mastersync", "puppetsync", "sync", "super", "PI", "TAU", "INF", "NAN",
}

_GD_OPERATORS = sorted([
    "<<=", ">>=", "**=", "//=", "==", "!=", "<=", ">=", "->", "+=", "-=", "*=", "/=", "%=", "&=", "|=",
    "^=", "&&", "||", "**", "//", "<<", ">>", "::", "(", ")", "[", "]", "{", "}", ":", ",", ".", "+", "-",
    "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?",
], key=len, reverse=True)

_GD_TOKEN_RE = re.compile(
    r'"(?:[^"\\]|\\.)*"'          # double-quoted string
    r"|'(?:[^'\\]|\\.)*'"          # single-quoted string
    r"|\d+\.\d+|\d+"               # number
    r"|[A-Za-z_]\w*"                # identifier or keyword
    r"|" + "|".join(re.escape(op) for op in _GD_OPERATORS)
)
_GD_COMMENT_RE = re.compile(r"#.*$")


def gd_tokenize(source: str) -> list[tuple[str, str]]:
    """(kind, text) pairs, kind in {"KEYWORD", "ID", "LIT", "OP"}. Comments stripped; strings/numbers
    are LIT and kept as their own text (not normalized -- see the module docstring on why duplication
    detection normalizes identifiers only, not literals)."""
    tokens = []
    for line in source.splitlines():
        line = _GD_COMMENT_RE.sub("", line)
        for m in _GD_TOKEN_RE.finditer(line):
            text = m.group(0)
            if text[0].isdigit():
                tokens.append(("LIT", text))
            elif text[0] in "\"'":
                tokens.append(("LIT", text))
            elif text[0].isalpha() or text[0] == "_":
                tokens.append(("KEYWORD" if text in GD_KEYWORDS else "ID", text))
            else:
                tokens.append(("OP", text))
    return tokens


# --- Python tokenizer -----------------------------------------------------------------------------------

def py_tokenize_source(source: str) -> list[tuple[str, str]]:
    """(kind, text) pairs, same shape as gd_tokenize's -- kind in {"KEYWORD", "ID", "LIT", "OP"}.
    Comments/whitespace/structural tokens (NEWLINE, INDENT, DEDENT, ENCODING) dropped; a function's
    leading `def name(` line is included, so two functions differing only in name/signature still share
    every other token, exactly the renamed-copy case this exists to catch."""
    tokens = []
    try:
        for tok in py_tokenize.generate_tokens(io.StringIO(source).readline):
            if tok.type in (py_tokenize.COMMENT, py_tokenize.NL, py_tokenize.NEWLINE,
                             py_tokenize.INDENT, py_tokenize.DEDENT, py_tokenize.ENCODING,
                             py_tokenize.ENDMARKER):
                continue
            text = tok.string
            if not text:
                continue
            if tok.type == py_tokenize.NAME:
                tokens.append(("KEYWORD" if keyword.iskeyword(text) else "ID", text))
            elif tok.type in (py_tokenize.NUMBER, py_tokenize.STRING):
                tokens.append(("LIT", text))
            else:
                tokens.append(("OP", text))
    except (py_tokenize.TokenizeError, IndentationError, SyntaxError):
        return []
    return tokens


# --- Shared distribution stats, used by every instrument that flags outliers relative to the data ------

def percentile(values: list[float], p: float) -> float:
    """Linear-interpolation percentile (the common, unsurprising definition) -- values need not be
    pre-sorted. p in [0, 100]."""
    if not values:
        return 0.0
    s = sorted(values)
    if len(s) == 1:
        return s[0]
    k = (p / 100) * (len(s) - 1)
    lo, hi = int(k), min(int(k) + 1, len(s) - 1)
    frac = k - lo
    return s[lo] + (s[hi] - s[lo]) * frac


def summarize(values: list[float]) -> dict:
    """count/min/max/mean/median/p90/p95, the distribution view every instrument reports before it
    proposes an outlier fence -- director's explicit instruction: see the data before the threshold."""
    if not values:
        return {"count": 0, "min": 0, "max": 0, "mean": 0.0, "median": 0.0, "p90": 0.0, "p95": 0.0}
    return {
        "count": len(values), "min": min(values), "max": max(values),
        "mean": sum(values) / len(values), "median": percentile(values, 50),
        "p90": percentile(values, 90), "p95": percentile(values, 95),
    }


def iqr_outlier_fence(values: list[float]) -> float:
    """The standard boxplot outlier rule: Q3 + 1.5*(Q3-Q1). A self-calibrating fence -- it adapts to
    the data instead of being picked a priori, which is the whole point of a dashboard-before-gate
    approach. Not a proposal for a permanent gate threshold by itself; a starting point to argue from."""
    if len(values) < 4:
        return max(values) + 1 if values else 0.0
    q1, q3 = percentile(values, 25), percentile(values, 75)
    return q3 + 1.5 * (q3 - q1)


# --- Shared CLI dispatch, one instrument each -------------------------------------------------------

def run_cli(analyze_fn, format_report_fn, exit_fn=None) -> int:
    """The body every `tools/quality_check/` instrument's own `main()` delegates to -- extracted
    2026-08-28 (`docs/DECISIONS_LEDGER.md` D0097) after `duplication.py`'s own first real run found
    the four instruments' `main()` functions clustered as an identical duplicate: each was
    `result = analyze(); print(format_report(result)); return 0`, byte-for-byte after identifier
    normalization. This is that duplication's actual fix -- the repeated dispatch logic now exists
    once, here, not four times with different names in front of it -- not merely a detector exclusion
    (that's `duplication.MAIN_BOILERPLATE_MAX_LINES`, a separate, narrower calibration for main()-
    shaped functions this extraction cannot reach, e.g. ones with real branching of their own).
    Two-argument, not zero: each instrument's `analyze`/`format_report` pair is real, distinct domain
    logic this harness has no business hardcoding or importing by name.

    `exit_fn`, optional (`docs/DECISIONS_LEDGER.md` D0099): a `result -> int` callable that decides the
    process exit code from the analysis result. Omitted (the default, used by `function_length.py`/
    `complexity.py`/`coupling.py`) means always 0 -- dashboard, never blocking, by construction, not by
    remembering to check something at every call site. `duplication.py` is the one instrument this
    project decided should gate CI (director: "0 clusters is the current clean state; regressions fail
    the build"), so it is the one caller that passes an `exit_fn` -- the other three staying gate-less is
    guaranteed by the shared default, not by each of their own `main()` independently getting it right."""
    result = analyze_fn()
    print(format_report_fn(result))
    return exit_fn(result) if exit_fn is not None else 0
