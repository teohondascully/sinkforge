#!/usr/bin/env python3
"""Instrument LOC growth may not outpace game LOC growth. docs/QUALITY.md gate 7, docs/CLAIMS.md §2.

    python3 tools/layer_lint/check_loc_ratio.py

Rewritten 2026-08-26, replacing an absolute-totals comparison that was specified wrong. Comparing
`instrument > game` on the totals sitting on disk is meaningless at project start: any nonzero
instrument code exceeds zero game code on day one, and it duly FAILed the instant Task 1 landed `core/`
without `sim/` landing alongside it in the same commit -- a true statement about that moment, but not
the failure this gate exists to catch. What actually happened in the prior codebase was a TREND:
`tools/` grew 90% in five days against `src/`'s 9%, instrumentation compounding roughly seven times
faster than the game over one short window -- not a single line being crossed once
(docs/archive/COMPAT_AUDIT..., docs/archive/PIVOT_PLAN...). This measures the trend instead: net LOC
change over a trailing window of commits, never the totals on disk right now.

    instrument = harness/ + experiment/ + tools/ + tests/
    game       = core/ + sim/ + interface/ + view/ + shell/

Window is WINDOW_COMMITS commits, not wall-clock days: commit count doesn't depend on the CI runner's
clock or timezone, and unlike a date window it can't silently shrink to zero commits in a quiet week
while still reporting a number. This needs full git history, which is why `.github/workflows/harness.yml`
's `gates` job was given `fetch-depth: 0` in the same commit that introduced this rewrite --
`actions/checkout` defaults to a depth-1 (single-commit) clone, which would make this check's own
history read empty and its comparison meaningless on every CI run. The `authorship` job already carries
the identical fetch-depth comment for the same failure shape hitting `tools/check_trailers.sh` once
before this gate existed.

FAIL when instrument growth exceeds game growth by more than RATIO_LIMIT, gated by GROWTH_FLOOR so a
handful of added lines in a quiet week can't trip it on ratio alone. ADVISORY (never blocking, exit 0
regardless of the verdict) while current game LOC is under GAME_LOC_ADVISORY_FLOOR: below that the
absolute numbers are too small for a ratio to mean anything, so the floor itself is written down here
rather than left an implicit side effect of small numbers, per the threshold-before-measurement
discipline this project applies to claims (docs/CLAIMS.md §10b).

The absolute (all-time) ratio is still computed and printed every run -- purely informational, feeds
docs/BRIEF.md's "LOC ratio" line by hand, never gates the exit code. Losing that number entirely would
have hidden exactly the state this gate's predecessor caught (instrument outpacing game in absolute
terms); it just isn't grounds for a FAIL on its own anymore.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

INSTRUMENT_DIRS = ["harness", "experiment", "tools", "tests"]
GAME_DIRS = ["core", "sim", "interface", "view", "shell"]
SCRATCH_PREFIX = "tools/scratch"
CODE_EXTENSIONS = (".gd", ".py", ".sh")

WINDOW_COMMITS = 10
RATIO_LIMIT = 2.0
GROWTH_FLOOR = 50
GAME_LOC_ADVISORY_FLOOR = 2000


def _run_git(args: list[str]) -> str:
    result = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip())
    return result.stdout


def _is_counted(rel_path: str) -> bool:
    if rel_path.startswith(SCRATCH_PREFIX + "/"):
        return False
    return rel_path.endswith(CODE_EXTENSIONS)


def loc_under_worktree(dirname: str) -> int:
    base = ROOT / dirname
    if not base.is_dir():
        return 0
    total = 0
    for ext in ("*.gd", "*.py", "*.sh"):
        for p in base.rglob(ext):
            rel = p.relative_to(ROOT).as_posix()
            if rel.startswith(SCRATCH_PREFIX + "/"):
                continue
            total += len(p.read_text(encoding="utf-8", errors="replace").splitlines())
    return total


def loc_at_commit(commit: str, dirname: str) -> int:
    """Total counted-code lines under `dirname` as of `commit`, read via git plumbing -- no checkout,
    no worktree mutation, safe to call from inside a dirty working tree."""
    try:
        listing = _run_git(["ls-tree", "-r", "--name-only", commit, "--", dirname])
    except RuntimeError:
        return 0
    total = 0
    for rel in listing.splitlines():
        if not _is_counted(rel):
            continue
        try:
            content = _run_git(["show", f"{commit}:{rel}"])
        except RuntimeError:
            continue  # in the tree listing but not readable as text -- skip rather than crash
        total += len(content.splitlines())
    return total


def resolve_window_start() -> str | None:
    """The commit WINDOW_COMMITS back from HEAD, or None if history is shorter than that (a shallow
    clone, or a young repo) -- both are real conditions this gate must say it can't measure, not
    silently treat as a zero-growth window."""
    try:
        commits = _run_git(["log", "--format=%H", f"-n{WINDOW_COMMITS + 1}"]).splitlines()
    except RuntimeError:
        return None
    if len(commits) <= WINDOW_COMMITS:
        return None
    return commits[-1]


def main() -> int:
    instrument_now = {d: loc_under_worktree(d) for d in INSTRUMENT_DIRS}
    game_now = {d: loc_under_worktree(d) for d in GAME_DIRS}
    instrument_total = sum(instrument_now.values())
    game_total = sum(game_now.values())

    print("check_loc_ratio: instrument (harness+experiment+tools+tests), current:")
    for d, n in instrument_now.items():
        print(f"    {d:12s} {n:6d}")
    print(f"    {'total':12s} {instrument_total:6d}")
    print("check_loc_ratio: game (core+sim+interface+view+shell), current:")
    for d, n in game_now.items():
        print(f"    {d:12s} {n:6d}")
    print(f"    {'total':12s} {game_total:6d}")

    if game_total == 0:
        print(f"check_loc_ratio: absolute ratio = inf ({instrument_total} instrument, 0 game) "
              "-- informational, does not gate")
    else:
        print(f"check_loc_ratio: absolute ratio = {instrument_total / game_total:.3f} "
              "(instrument / game) -- informational, does not gate")

    window_start = resolve_window_start()
    if window_start is None:
        print(f"check_loc_ratio: fewer than {WINDOW_COMMITS} commits of history available "
              "(shallow clone or a young repo) -- cannot measure a trailing-window trend. "
              "ADVISORY: not gating on velocity this run.")
        return 0

    instrument_then = sum(loc_at_commit(window_start, d) for d in INSTRUMENT_DIRS)
    game_then = sum(loc_at_commit(window_start, d) for d in GAME_DIRS)
    instrument_growth = instrument_total - instrument_then
    game_growth = game_total - game_then

    print(f"check_loc_ratio: over the last {WINDOW_COMMITS} commits ({window_start[:8]}..HEAD): "
          f"instrument {instrument_then} -> {instrument_total} ({instrument_growth:+d}), "
          f"game {game_then} -> {game_total} ({game_growth:+d})")

    violates_velocity = (
        instrument_growth > GROWTH_FLOOR
        and instrument_growth > RATIO_LIMIT * max(game_growth, 0)
    )

    if game_total < GAME_LOC_ADVISORY_FLOOR:
        verdict = "would FAIL" if violates_velocity else "would PASS"
        print(f"check_loc_ratio: ADVISORY -- game LOC ({game_total}) is under the "
              f"{GAME_LOC_ADVISORY_FLOOR}-line floor where this ratio means anything. "
              f"Velocity check {verdict} but is not gating this run.")
        return 0

    if violates_velocity:
        print(f"check_loc_ratio: FAIL -- instrument grew {instrument_growth} lines against game's "
              f"{game_growth} over the last {WINDOW_COMMITS} commits, more than {RATIO_LIMIT:.0f}x. "
              "Per docs/CLAIMS.md, the next unit of work is game, not another check.")
        return 1

    print("check_loc_ratio: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
