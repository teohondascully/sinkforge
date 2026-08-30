"""Shared `.gd` file discovery for `tools/layer_lint/`'s gates -- extracted 2026-08-28
(`docs/DECISIONS_LEDGER.md` D0097) after `tools/quality_check/duplication.py`'s first run found two
near-duplicate `find_gd_files()` implementations, each defined independently in two different gates.

Two genuinely different filter styles existed, not one duplicated four times over identical data:
`check_coordinate_naming.py`/`no_engine_imports.py` each name an explicit ALLOW-list of the specific
directories they police (different lists -- `("sim/world", "sim/terrain_gen", "sim/body")` vs
`("core", "sim")`) and yield ABSOLUTE paths for direct reading; `check_size_limits.py`/`layer_lint.py`
each name a DENY-list of what NOT to scan and yield paths RELATIVE to root. Both styles are kept, as two
small named functions sharing one glob primitive each -- forcing all four into one function behind a
style flag would make every call site less self-evident about what it actually scans, trading a real
readability property for a slightly smaller line count.
"""
import subprocess
from pathlib import Path


def git_ignored(root: Path, paths) -> set:
    """The subset of `paths` (relative to `root`) that git ignores -- added 2026-08-30 (D0225, P003).

    `check_size_limits.py` linted every gitignored `.gd` under `tools/scratch/` on a developer's machine
    and none of them in CI, where a fresh checkout has no scratch directory. Same gate name, two
    populations: a local run could FAIL for a reason CI can never see, and -- the sharper half -- could
    be made to PASS by deleting an untracked file.

    `git check-ignore --stdin` exits **1 when NOTHING matched**, which is the normal case and not an
    error; only 128 is. Reading a non-zero exit as failure here would silently return "nothing is
    ignored" and restore the very behaviour this exists to remove, so the exit code is classified rather
    than truth-tested. Any other failure (no git, not a repository) returns the empty set, which keeps
    today's behaviour rather than dropping files nobody asked to drop.
    """
    rels = [str(p) for p in paths]
    if not rels:
        return set()
    try:
        proc = subprocess.run(["git", "-C", str(root), "check-ignore", "--stdin"],
                              input="\n".join(rels), capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return set()
    if proc.returncode not in (0, 1):
        return set()
    return {line.strip() for line in proc.stdout.splitlines() if line.strip()}


def files_named(root: Path, filename: str, excluded: set):
    """Every tracked file called `filename` under `root`, RELATIVE to `root` -- same deny-list and
    same gitignore filter as `gd_files_excluding`, for the non-`.gd` artifacts a gate has to size
    (`MODULE.md`, D0226). Kept here so one population rule serves every gate rather than two."""
    candidates = [p.relative_to(root) for p in root.rglob(filename)
                  if p.relative_to(root).parts[0] not in excluded
                  and not p.relative_to(root).parts[0].startswith(".")]
    ignored = git_ignored(root, candidates)
    return [rel for rel in candidates if str(rel) not in ignored]


def gd_files_in(root: Path, dirs):
    """Every `.gd` file under any of `dirs` (each a path relative to `root`), yielded as ABSOLUTE
    paths -- the allow-list style."""
    for rel in dirs:
        base = root / rel
        if base.is_dir():
            yield from base.rglob("*.gd")


def gd_files_excluding(root: Path, excluded: set):
    """Every TRACKABLE `.gd` file under `root`, yielded RELATIVE to `root`, skipping any top-level
    directory named in `excluded` or starting with `.`, and anything git ignores -- the deny-list style.

    The ignore filter (D0225) makes a local run and a CI run measure the same population; without it the
    two differ by whatever untracked scratch a developer happens to have on disk."""
    candidates = []
    for p in root.rglob("*.gd"):
        rel = p.relative_to(root)
        if rel.parts[0] in excluded or rel.parts[0].startswith("."):
            continue
        candidates.append(rel)
    ignored = git_ignored(root, candidates)
    for rel in candidates:
        if str(rel) not in ignored:
            yield rel
