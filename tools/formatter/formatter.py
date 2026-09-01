#!/usr/bin/env python3
"""tools/formatter/formatter.py -- the repository's own code formatter. `.editorconfig` made executable.

## Why this exists

`.editorconfig` at the root declares five properties for every file in this tree (`charset = utf-8`,
`end_of_line = lf`, `insert_final_newline`, `trim_trailing_whitespace`, and tabs for `.gd` against spaces
for everything else) and **nothing in this repository has ever checked one of them**. An editorconfig is a
request to whichever editor happens to be open; it is not a gate, and this project's own standard is
explicit that a declared property nobody re-derives is the shape drift hides in.

It had already drifted, measured before this tool was written rather than asserted after:

| violation | files |
|---|---|
| blank line(s) before EOF (`insert_final_newline` says one newline, not two) | 4 `.gd` |
| a run of 3+ blank lines | 5 `.gd`, 1 `.py` |
| no final newline at all | 1 `.gd` |

Ten files, no reviewer's fault -- these are exactly the differences a human eye does not register and a
diff shows as noise. That is the case for a formatter rather than another lint: the answer is mechanical,
so the tool should apply it (`--write`) instead of filing it.

## Why not gdformat

`gdformat` (gdtoolkit) is the standard GDScript formatter and was rejected, twice over. It reflows code to
its own line-length model, which over this tree's comment-dense, hand-aligned source would produce a
diff of a size nobody can review, on lines whose current shape was a decision. And it is a third-party
dependency for a project that currently has exactly one (`pyyaml`, for the schema validator). This tool
takes the opposite trade deliberately: it only canonicalizes what has one defensible answer, and it says
below exactly what it therefore does NOT touch.

## The rules, and which files each one reaches

Two rulesets. `.gd`/`.py` get all six rules and are read STRING-AWARE (see `scan`); `.sh`/`.yml`/`.yaml`
get only the four byte-level rules, because a YAML block scalar or a shell heredoc can carry indentation
this tool has no grammar for and should not be guessing about.

| rule | `.gd` | `.py` | `.sh`/`.yml`/`.yaml` | what it does |
|---|---|---|---|---|
| `charset` | yes | yes | yes | strips a UTF-8 BOM, rewrites CRLF/CR to LF |
| `trailing-whitespace` | yes | yes | yes | strips trailing spaces/tabs, never inside a string literal |
| `file-edges` | yes | yes | yes | no blank lines at BOF or EOF; exactly one final newline |
| `blank-run` | yes | yes | no | collapses 3+ consecutive blank lines to 2 |
| `indent` | yes | yes | no | `.gd` indents with tabs, `.py` with 4 spaces |
| `comment-space` | yes | yes | no | `#foo` becomes `# foo`; `##` doc comments keep their marks |

**`indent` refuses rather than guesses.** A `.gd` line indented with a whole number of 4-space groups is
converted to tabs; anything else -- tabs and spaces mixed, or a space count that is not a multiple of 4 --
is reported as an error with its line number and left exactly as it is. Reformatting an indentation the
tool cannot read unambiguously would be a formatter changing a program's structure on a guess.

**`indent` has one exemption, and it is load-bearing.** A comment-only line, indented with spaces, whose
previous line carries a TRAILING comment is a wrapped trailing comment: its leading spaces are column
alignment, not block indentation, and a tab cannot express a column. Eight such lines exist right now
(`sim/body/input_frame.gd:15`, `sim/body/vertical_resolve.gd:21-23`, and four more) and a naive
spaces-to-tabs pass corrupts every one of them -- found by looking at the actual lines before writing the
rule, which is why the rule has the exemption instead of the tree having a repair commit.

## What it deliberately does NOT do

No operator spacing, no comma spacing, no line wrapping, no argument alignment, no blank-line policy
between declarations. Those need a real GDScript grammar, and no GDScript parser exists in pure Python
(`tools/quality_check/scan.py` says the same thing about its own tokenizer, for the same reason). They
were also measured, not assumed unnecessary: this tree currently has **zero** missing-space-after-comma,
zero space-before-comma, zero space-before-close-bracket and zero `#foo` comments, so a rule for any of
them would have been an unfalsifiable claim about code that already agrees with it. `comment-space` is
kept regardless because it is free and its violation is silent; the others are not implemented at all
rather than implemented and never exercised.

## Scope

`.gd`: every trackable `.gd` file outside `legacy/`, via `tools/layer_lint/gd_scan.gd_files_excluding` --
the SAME population `check_size_limits.py` (gates 3-4) and `duplication.py` already use, imported rather
than re-derived, because a second definition of "the files we lint" is how D0102 happened.
`.py`/`.sh`: `harness/`, `experiment/`, `tools/`. `.yml`/`.yaml`: `.github/workflows/` and `data/`.
Everything git ignores is filtered out (`gd_scan.git_ignored`, D0225: a local run and a CI run must see
one population, so `tools/scratch/` is invisible here on both).

`data/<kind>/generated.gd` is IN scope on purpose. Those files are written by
`tools/data_codegen/generate.py`, they are already canonical, and leaving them in means this formatter
also fails the day the generator starts emitting something that is not.

## Exit codes

`0` clean. `1` a file needs reformatting (in `--check`) or holds an indentation this tool refuses to
guess at. `2` the question could not be answered at all -- empty population, a file that is not UTF-8, or
a formatting pass that is not idempotent -- which is VOID, never a pass, per `docs/QUALITY.md` §2.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "layer_lint"))
from gd_scan import gd_files_excluding, git_ignored  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]

GD_EXCLUDED_TOP = {"legacy"}
INSTRUMENT_DIRS = ("harness", "experiment", "tools")
YAML_DIRS = (".github/workflows", "data")

TAB_WIDTH = 4
MAX_BLANK_RUN = 2

STRING_AWARE = ("gd", "py")  # the two languages this tool reads as code rather than as bytes
REGION_RE = re.compile(r"(region|endregion)\b")


class Unstable(Exception):
    """A formatting pass that changes its own output on a second application. Fatal, and reported as
    VOID rather than as a violation: the file is not the thing at fault, this tool is."""


def discover(root: Path) -> list[tuple[Path, str]]:
    """(path relative to `root`, language) for every file this formatter owns, sorted.

    `language` is `gd`, `py` or `text`; `text` selects the byte-level ruleset only. Populations come from
    `gd_scan` where one already exists rather than from a fresh glob -- see the module docstring on why a
    second definition of the same file set is a defect in waiting, not a convenience."""
    found: list[tuple[Path, str]] = [(rel, "gd") for rel in gd_files_excluding(root, GD_EXCLUDED_TOP)]
    for dirname in INSTRUMENT_DIRS:
        base = root / dirname
        if not base.is_dir():
            continue
        found += [(p.relative_to(root), "py") for p in base.rglob("*.py")]
        found += [(p.relative_to(root), "text") for p in base.rglob("*.sh")]
    for dirname in YAML_DIRS:
        base = root / dirname
        if not base.is_dir():
            continue
        for pattern in ("*.yml", "*.yaml"):
            found += [(p.relative_to(root), "text") for p in base.rglob(pattern)]
    ignored = git_ignored(root, [rel for rel, _ in found])
    return sorted({(rel, lang) for rel, lang in found if str(rel) not in ignored})


def scan(text: str) -> tuple[list[str], list[bool]]:
    """Per-line masks plus per-line "starts inside a multi-line literal" flags.

    `masks[i][j]` classifies `lines[i][j]` as `c` (code), `s` (a string literal, quotes included) or `#`
    (a comment), and `masks[i]` is the same length as `lines[i]` so a caller can ask about one column.
    Every rule below consults this before touching a character: trailing whitespace inside a literal is
    DATA, and a `#` inside a literal is not a comment -- this tree has GDScript fixtures whose ASCII-art
    grids are full of lines like `"#....####",`, which is exactly what a raw text scan gets wrong.

    The second return value exists because the mask cannot answer one question: an EMPTY line inside a
    triple-quoted string and an empty line between two functions have identical (empty) masks. The
    blank-run and file-edges rules need to tell those apart, and `inside[i]` is what does it.

    Related to `tools/layer_lint/gd_source.blank_comments_and_strings` and deliberately not built on it:
    that function returns a same-length twin with comments AND strings both blanked to spaces, which is
    the right shape for "does this file mention that identifier" and the wrong one here -- once both are
    spaces, a trailing space inside a string is indistinguishable from a trailing space after code, and
    telling those two apart is this tool's whole job. Kept as a separate scan rather than by widening
    that one, since `gd_source`'s callers are gates whose population must not shift underneath them.

    Unterminated literals are resolved the way both languages do: a single-quote literal ends at the
    newline, a triple-quote literal runs on. Either way the tool errs toward `s`, i.e. toward leaving
    characters alone."""
    mask: list[str] = []
    inside: list[bool] = [False]
    triple: str | None = None
    i, n = 0, len(text)
    while i < n:
        char = text[i]
        if char == "\n":
            mask.append("\n")
            i += 1
            inside.append(triple is not None)
            continue
        if triple is not None:
            if text.startswith(triple, i):
                mask.append("sss")
                i += 3
                triple = None
            else:
                mask.append("s")
                i += 1
            continue
        opened = next((q for q in ('"""', "'''") if text.startswith(q, i)), None)
        if opened is not None:
            mask.append("sss")
            i += 3
            triple = opened
            continue
        if char in ("'", '"'):
            mask.append("s")
            i += 1
            while i < n and text[i] != "\n":
                if text[i] == "\\" and i + 1 < n and text[i + 1] != "\n":
                    mask.append("ss")
                    i += 2
                    continue
                closed = text[i] == char
                mask.append("s")
                i += 1
                if closed:
                    break
            continue
        if char == "#":
            while i < n and text[i] != "\n":
                mask.append("#")
                i += 1
            continue
        mask.append("c")
        i += 1
    masks = "".join(mask).split("\n")
    lines = text.split("\n")
    if len(masks) != len(lines) or any(len(m) != len(l) for m, l in zip(masks, lines)):
        raise Unstable("the mask lost alignment with the source it describes")
    return masks, inside


def _flat(text: str) -> tuple[list[str], list[bool]]:
    """Masks for a `text` file: every character is code, nothing is a literal. Lets the byte-level rules
    run through the same code path as the string-aware ones instead of growing a second copy."""
    lines = text.split("\n")
    return ["c" * len(line) for line in lines], [False] * len(lines)


def _read(text: str, lang: str) -> tuple[list[str], list[str], list[bool]]:
    masks, inside = scan(text) if lang in STRING_AWARE else _flat(text)
    return text.split("\n"), masks, inside


def fix_charset(text: str, lang: str, rel: str) -> tuple[str, list[str]]:
    return text.lstrip("\ufeff").replace("\r\n", "\n").replace("\r", "\n"), []


def fix_trailing_whitespace(text: str, lang: str, rel: str) -> tuple[str, list[str]]:
    lines, masks, _ = _read(text, lang)
    out = []
    for line, mask in zip(lines, masks):
        stripped = line.rstrip(" \t")
        out.append(stripped if "s" not in mask[len(stripped):] else line)
    return "\n".join(out), []


def fix_blank_run(text: str, lang: str, rel: str) -> tuple[str, list[str]]:
    if lang not in STRING_AWARE:
        return text, []
    lines, _, inside = _read(text, lang)
    out: list[str] = []
    run = 0
    for line, ins in zip(lines, inside):
        if not line.strip() and not ins:
            run += 1
            if run > MAX_BLANK_RUN:
                continue
        else:
            run = 0
        out.append(line)
    return "\n".join(out), []


def fix_file_edges(text: str, lang: str, rel: str) -> tuple[str, list[str]]:
    """No blank lines at either end, exactly one final newline. `inside` is what keeps this off a
    module docstring that opens with a blank line, or a multi-line literal that ends with one."""
    lines, _, inside = _read(text, lang)
    start, end = 0, len(lines)
    while start < end and not lines[start].strip() and not inside[start]:
        start += 1
    while end > start and not lines[end - 1].strip() and not inside[end - 1]:
        end -= 1
    body = "\n".join(lines[start:end])
    return (body + "\n") if body else "", []


def _is_wrapped_trailing_comment(line: str, mask: str, last_code: tuple[str, str] | None) -> bool:
    """True when `line` is a comment-only continuation of a trailing comment in the last CODE line above
    it (not necessarily the immediately previous line -- a wrapped comment chain can span several
    comment-only lines, and the code line they wrap is the one that started the chain).

    Its leading spaces align to a column in that code line, which no tab count can reproduce, so
    `fix_indent` leaves it alone. See the module docstring for the eight real lines this protects."""
    if last_code is None:
        return False
    first = len(line) - len(line.lstrip())
    if first >= len(mask) or mask[first] != "#":
        return False
    code_line, code_mask = last_code
    code_comment = code_mask.find("#")
    return code_comment > 0 and bool(code_line[:code_comment].strip())


def fix_indent(text: str, lang: str, rel: str) -> tuple[str, list[str]]:
    """`.gd` indents with tabs, `.py` with spaces -- `.editorconfig`'s own rule, applied where it is
    unambiguous and REFUSED where it is not. An unreadable indentation is reported, never rewritten."""
    if lang not in STRING_AWARE:
        return text, []
    lines, masks, inside = _read(text, lang)
    out: list[str] = []
    errors: list[str] = []
    last_code: tuple[str, str] | None = None
    for number, (line, mask, ins) in enumerate(zip(lines, masks, inside), start=1):
        if ins:
            out.append(line)
            continue
        if not line.strip():
            last_code = None
            out.append(line)
            continue
        lead = line[:len(line) - len(line.lstrip(" \t"))]
        body = line[len(lead):]
        wrong, right = (" ", "\t") if lang == "gd" else ("\t", " ")
        if wrong not in lead:
            out.append(line)
        elif lang == "gd" and _is_wrapped_trailing_comment(line, mask, last_code):
            out.append(line)
        elif set(lead) == {wrong} and (lang == "py" or len(lead) % TAB_WIDTH == 0):
            depth = len(lead) // TAB_WIDTH if lang == "gd" else len(lead) * TAB_WIDTH
            out.append(right * depth + body)
        else:
            errors.append(f"{rel}:{number}: indentation is {len(lead)} character(s) of mixed tabs and "
                          f"spaces (or a space count that is not a multiple of {TAB_WIDTH}); "
                          f"{'.gd indents with tabs' if lang == 'gd' else '.py indents with spaces'} "
                          f"and this tool will not guess which nesting depth was meant")
            out.append(line)
        comment_col = mask.find("#")
        if comment_col < 0 or line[:comment_col].strip():
            last_code = (line, mask)
    return "\n".join(out), errors


def fix_comment_space(text: str, lang: str, rel: str) -> tuple[str, list[str]]:
    """One space after the `#` marks. `##` (this project's doc-comment convention) keeps both marks, a
    line of nothing but `#` is a separator and is left alone, and `#!` at column 0 is a shebang."""
    if lang not in STRING_AWARE:
        return text, []
    lines, masks, _ = _read(text, lang)
    out = []
    for line, mask in zip(lines, masks):
        column = mask.find("#")
        if column < 0:
            out.append(line)
            continue
        comment = line[column:]
        body = comment.lstrip("#")
        marks = len(comment) - len(body)
        if not body or body[0] in " \t" or (body[0] == "!" and column == 0) or REGION_RE.match(body):
            out.append(line)
        else:
            out.append(line[:column] + "#" * marks + " " + body)
    return "\n".join(out), []


RULES = (
    ("charset", fix_charset),
    ("trailing-whitespace", fix_trailing_whitespace),
    ("blank-run", fix_blank_run),
    ("file-edges", fix_file_edges),
    ("indent", fix_indent),
    ("comment-space", fix_comment_space),
)


def _apply(text: str, lang: str, rel: str) -> tuple[str, list[str], list[str]]:
    fired: list[str] = []
    errors: list[str] = []
    for name, rule in RULES:
        new_text, rule_errors = rule(text, lang, rel)
        if new_text != text:
            fired.append(name)
        text = new_text
        errors += rule_errors
    return text, fired, errors


def format_text(text: str, lang: str, rel: str = "<text>") -> tuple[str, list[str], list[str]]:
    """The formatted form of `text`, which rules changed it, and the violations left unfixed.

    Applies the pipeline TWICE and refuses to return an unstable result. A formatter whose output is not
    its own fixed point turns `--check` into a coin flip -- CI would fail a tree that `--write` had just
    produced -- so the property is asserted on every file on every run rather than trusted from a test."""
    once, fired, errors = _apply(text, lang, rel)
    twice, again, _ = _apply(once, lang, rel)
    if twice != once:
        raise Unstable(f"{rel}: formatting is not idempotent -- a second pass fired {again or ['?']}")
    return once, fired, errors


def _population_summary(population: list[tuple[Path, str]]) -> str:
    counts: dict[str, int] = {}
    for rel, _ in population:
        counts[rel.suffix] = counts.get(rel.suffix, 0) + 1
    return ", ".join(f"{n} {ext}" for ext, n in sorted(counts.items(), key=lambda kv: -kv[1]))


def run(root: Path, write: bool, only: list[str]) -> int:
    population = discover(root)
    if only:
        wanted = {Path(p).as_posix() for p in only}
        population = [(rel, lang) for rel, lang in population if rel.as_posix() in wanted]
    if not population:
        print("formatter: VOID -- zero files in scope. Every set difference over an empty population is "
              "empty, which would make this check green forever; that is not a pass.")
        return 2

    unformatted: list[tuple[Path, list[str]]] = []
    errors: list[str] = []
    for rel, lang in population:
        raw = (root / rel).read_bytes()
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError as exc:
            print(f"formatter: VOID -- {rel} is not valid UTF-8 ({exc}); `.editorconfig` declares "
                  f"charset = utf-8 and a file that will not decode is not a file with nothing wrong.")
            return 2
        formatted, fired, file_errors = format_text(text, lang, rel.as_posix())
        errors += file_errors
        if formatted != text:
            unformatted.append((rel, fired))
            if write:
                (root / rel).write_text(formatted, encoding="utf-8", newline="")

    print(f"formatter: {len(population)} file(s) in scope ({_population_summary(population)})")
    for rel, fired in unformatted:
        verb = "REFORMATTED" if write else "WOULD REFORMAT"
        print(f"  {verb} {rel} ({', '.join(fired)})")
    for error in errors:
        print(f"  REFUSED  {error}")

    if errors:
        print(f"formatter: FAIL -- {len(errors)} indentation(s) this tool will not rewrite on a guess. "
              f"Fix them by hand; every other difference is mechanical and `--write` applies it.")
        return 1
    if unformatted and not write:
        print(f"formatter: FAIL -- {len(unformatted)} file(s) are not canonically formatted. "
              f"Run: python3 tools/formatter/formatter.py --write")
        return 1
    if unformatted:
        print(f"formatter: REWROTE {len(unformatted)} file(s); the tree is now canonical.")
        return 0
    print("formatter: PASS -- every file in scope already matches .editorconfig's declared rules.")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--write", action="store_true",
                        help="rewrite files in place. Default is --check: report and change nothing.")
    parser.add_argument("--root", default=str(ROOT),
                        help="repository root to format (the mutation tests point this at a fixture tree)")
    parser.add_argument("paths", nargs="*",
                        help="limit to these paths, relative to root; default is the whole population")
    args = parser.parse_args(argv)
    try:
        return run(Path(args.root).resolve(), args.write, args.paths)
    except Unstable as exc:
        print(f"formatter: VOID -- {exc}. This is a defect in the formatter, not in the file: refusing "
              f"to report a verdict rather than reporting one that a second run would contradict.")
        return 2


if __name__ == "__main__":
    sys.exit(main())
