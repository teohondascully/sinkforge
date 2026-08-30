"""GDScript source reading that sees past comments and string literals -- added 2026-08-30 (D0224).

`layer_lint.py` reported PASS having checked **zero** dependency edges: it matched only `res://*.gd`
path references, and this codebase couples exclusively through `class_name` globals. The gate was green
over no subject. Resolving those globals means asking "does this file mention that identifier", which is
only meaningful once comments and string literals are out of the way -- this repository's comments are
dense with capitalised prose and quoted type names, and a raw text scan reports them all.

`blank_comments_and_strings` blanks rather than deletes, so byte offsets and line numbers survive and a
caller can still report a real line for a hit. Kept separate from the lint itself so a second gate that
needs to read GDScript as code rather than as text does not re-derive it -- `duplication.py`'s D0097
finding was exactly two independently written copies of one scan.
"""
import re

IDENTIFIER_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
CLASS_NAME_RE = re.compile(r"^\s*class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)

_QUOTES = ('"""', "'''", '"', "'")


def declared_class_name(text: str) -> str | None:
    """The `class_name` this source declares, or None. Read from the RAW text on purpose: a
    `class_name` line is never inside a string, and blanking first would cost a pass over the file."""
    match = CLASS_NAME_RE.search(text)
    return match.group(1) if match else None


def _quote_at(text: str, i: int) -> str | None:
    for q in _QUOTES:
        if text.startswith(q, i):
            return q
    return None


def _skip_string(text: str, i: int, quote: str, out: list) -> int:
    """Consumes the literal opened by `quote` at `i`, appending blanks. Newlines are preserved so line
    numbers survive a multi-line literal."""
    out.append(" " * len(quote))
    i += len(quote)
    triple = len(quote) == 3
    while i < len(text):
        if text[i] == "\\" and not triple and i + 1 < len(text):
            out.append("  ")
            i += 2
            continue
        if text.startswith(quote, i):
            out.append(" " * len(quote))
            return i + len(quote)
        out.append("\n" if text[i] == "\n" else " ")
        i += 1
    return i  # unterminated literal: the rest of the file is blanked, which is the safe direction


def blank_comments_and_strings(text: str) -> str:
    """Returns `text` with every `#` comment and string literal replaced by spaces, same length.

    Blanking is deliberately the conservative direction: a missed edge is a false NEGATIVE (the lint
    under-reports), never a false accusation against a file. The zero-edge guard in `layer_lint.py` is
    what stops a systematic under-report from passing silently.
    """
    out: list[str] = []
    i = 0
    while i < len(text):
        char = text[i]
        if char == "#":
            while i < len(text) and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        quote = _quote_at(text, i)
        if quote is not None:
            i = _skip_string(text, i, quote, out)
            continue
        out.append(char)
        i += 1
    return "".join(out)


def referenced_identifiers(text: str) -> set:
    """Every identifier appearing in `text` as CODE -- comments and string literals removed first."""
    return set(IDENTIFIER_RE.findall(blank_comments_and_strings(text)))
