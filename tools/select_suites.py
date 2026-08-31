#!/usr/bin/env python3
"""Pick the test suites a change can possibly affect, for the INNER LOOP ONLY.

**This is an accelerator, never a gate.** The full sweep still runs before every push and CI still runs
all 43 suites; this exists so that iterating on a `view/` painter does not pay 72 seconds for
`test_shaft_replay_determinism`, which cannot observe it. Every design decision below is made in the
direction of selecting too much rather than too little, because the failure mode of a suite selector is
exactly this project's house failure class: a green that means "not run" rather than "passed".

How the graph is built. Every `.gd` file declaring `class_name X` is a node; a file referencing the bare
token `X`, or preloading `res://path.gd`, or `extends "res://path.gd"`, depends on it. The reachable set
of each `tests/test_*.gd` is the transitive closure of that. A suite is selected when any changed path
lies in its closure.

WHY REFERENCES ARE MATCHED AS BARE TOKENS and not as `X.` member accesses: a file can name a class
without calling into it (a type annotation, an `is` check, an array element type), and all three are real
dependencies. Matching `X.` would miss `var g: TileGrid = ...`, which is how most of these suites hold
the thing they test.

THE FAIL-SAFE CASES, each of which selects EVERY suite:
  - a change to `tests/test_base.gd`, `tools/run_gd_test.sh`, or this file -- shared machinery
  - a change to anything under `data/` -- the generated records drive every population
  - a change to `project.godot` or any `.uid`
  - a changed path that is not reachable from ANY suite, which means the graph does not model it and
    the honest answer is that we do not know what it affects
  - any file whose extension is not `.gd`

That last group is the important one. A selector that silently returns an empty set for an input it does
not understand reports "nothing to run" in exactly the voice it uses for "nothing is affected".
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIRS = ["core", "sim", "interface", "view", "shell", "tests", "tools"]

CLASS_DECL = re.compile(r"^class_name\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)
RES_PATH = re.compile(r'res://([A-Za-z0-9_/]+\.gd)')
TOKEN = re.compile(r"\b([A-Z][A-Za-z0-9_]*)\b")
COMMENT = re.compile(r"#.*$", re.M)
STRING = re.compile(r'"[^"\n]*"|\'[^\'\n]*\'')


def strip_prose(text: str) -> str:
    """Comments and string literals removed, so a class NAMED in prose is not read as a dependency.

    This is not a nicety -- it is the difference between a working selector and one that always returns
    the full sweep. This repository's WHY-comment density is deliberately high, and measured on the real
    tree the unstripped graph made `tests/test_base.gd` reach `sim/terrain_gen/value_noise.gd` through
    `sim/body/body.gd:70`, a line that mentions `ShaftGenerator` inside a docstring recounting a
    reachability analysis. Every suite extends `test_base`, so that one sentence made every change to
    every file select all 43 suites -- a selector that is never wrong and never useful.

    String literals go too: `&"glimmer"` and `"res://..."` are data, and the `res://` preloads that ARE
    dependencies are extracted from the raw text before this runs, so nothing real is lost.
    """
    return STRING.sub(" ", COMMENT.sub(" ", text))

ALWAYS_ALL = {
    "tests/test_base.gd",
    "tools/run_gd_test.sh",
    "tools/select_suites.py",
    "project.godot",
}


def _gd_files() -> list[Path]:
    out: list[Path] = []
    for d in SOURCE_DIRS:
        base = ROOT / d
        if base.is_dir():
            out.extend(p for p in base.rglob("*.gd"))
    return out


def build_graph() -> tuple[dict[str, str], dict[str, set[str]]]:
    """`class_name -> relpath`, and `relpath -> set of relpaths it directly depends on`."""
    files = _gd_files()
    texts = {p.relative_to(ROOT).as_posix(): p.read_text(encoding="utf-8", errors="replace")
             for p in files}
    by_class: dict[str, str] = {}
    for rel, text in texts.items():
        for m in CLASS_DECL.finditer(text):
            by_class[m.group(1)] = rel
    deps: dict[str, set[str]] = {}
    for rel, text in texts.items():
        d: set[str] = set()
        for path in RES_PATH.findall(text):
            if path in texts:
                d.add(path)
        for tok in set(TOKEN.findall(strip_prose(text))):
            target = by_class.get(tok)
            if target is not None and target != rel:
                d.add(target)
        deps[rel] = d
    return by_class, deps


def closure(start: str, deps: dict[str, set[str]]) -> set[str]:
    seen: set[str] = {start}
    stack = [start]
    while stack:
        cur = stack.pop()
        for nxt in deps.get(cur, ()):
            if nxt not in seen:
                seen.add(nxt)
                stack.append(nxt)
    return seen


def suites() -> list[str]:
    # test_base.gd matches `test_*.gd` but is the shared harness base, not a suite -- CI does not run it
    # and `check_suite_coverage` does not count it. Including it here would inflate the denominator and,
    # worse, make "all suites selected" arithmetically unreachable.
    return sorted(p.relative_to(ROOT).as_posix()
                  for p in (ROOT / "tests").glob("test_*.gd")
                  if p.name != "test_base.gd")


def select(changed: list[str]) -> tuple[list[str], str]:
    """Returns (suite relpaths, reason). An empty `changed` selects everything."""
    all_suites = suites()
    if not changed:
        return all_suites, "no changed paths given"
    for c in changed:
        if c in ALWAYS_ALL:
            return all_suites, f"{c} is shared machinery"
        if c.startswith("data/"):
            return all_suites, f"{c} is generated data, which drives every population"
        if not c.endswith(".gd"):
            return all_suites, f"{c} is not .gd -- the graph does not model it"

    _, deps = build_graph()
    closures = {s: closure(s, deps) for s in all_suites}
    picked: set[str] = set()
    for c in changed:
        reachable_from_any = False
        for s, cl in closures.items():
            if c in cl:
                picked.add(s)
                reachable_from_any = True
        if not reachable_from_any:
            return all_suites, f"{c} is not reachable from any suite -- the graph does not model it"
    return sorted(picked), "reachable-set intersection"


def main() -> int:
    changed = sys.argv[1:]
    picked, reason = select(changed)
    total = len(suites())
    print(f"select_suites: {len(picked)}/{total} suite(s) selected -- {reason}")
    if len(picked) == total:
        print("select_suites: FULL SWEEP (this is the safe answer, not a failure)")
    for s in picked:
        print(f"res://{s}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
