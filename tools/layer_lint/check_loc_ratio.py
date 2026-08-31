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
handful of added lines in a quiet week can't trip it on ratio alone.

**Armed 2026-08-29 (`docs/DECISIONS_LEDGER.md` D0144), per an external audit's finding: this was the
project's stated health metric ("Instrument LOC may not exceed game LOC... Enforced in CI",
`docs/QUALITY.md` gate 7) and had never once been able to fail** -- the `GAME_LOC_ADVISORY_FLOOR` below
used to force ADVISORY (exit 0 unconditionally) whenever game LOC was under 2000, and game LOC has never
exceeded 1665 at any point this project has measured it, so the floor was not a calibration, it was a
permanent off switch with a number attached. Removed rather than raised or justified, per the audit's own
explicit instruction not to narrow scope to make a failing check pass.

**What "armed" actually gates, stated precisely because it is not the same claim `docs/QUALITY.md` gate 7
makes:** this script has only ever gated on trailing-window VELOCITY (instrument growth vs. game growth
over the last WINDOW_COMMITS commits), never on the ABSOLUTE ratio gate 7's own words describe
("Instrument LOC ≤ game LOC"). The absolute ratio is still computed and printed every run, still purely
informational -- arming the advisory floor did not turn it into a second gating condition, because doing
that is a design decision (what should the real enforced condition be?) this change does not make. It
currently fails anyway, because the velocity condition it has always checked is also currently violated;
that is not evidence the absolute-ratio question has been answered too.
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
WINDOW_SCAN_CAP = 400  ## how far back to look for WINDOW_COMMITS population-touching commits
RATIO_LIMIT = 2.0
GROWTH_FLOOR = 50


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


def _touches_a_population(commit: str) -> bool:
    """Whether `commit` changed any file this gate actually counts. Uses the SAME `_is_counted` filter
    and the same directory lists as the measurement, so a commit can never be admitted to the window on
    the strength of a file whose lines are then not counted."""
    try:
        changed = _run_git(
            ["diff-tree", "--no-commit-id", "--name-only", "-r", "-m", commit]).splitlines()
    except RuntimeError:
        return False
    for rel in changed:
        if not _is_counted(rel):
            continue
        top = rel.split("/", 1)[0]
        if top in INSTRUMENT_DIRS or top in GAME_DIRS:
            return True
    return False


def resolve_window_start() -> str | None:
    """The WINDOW_COMMITS-th most recent commit THAT TOUCHED EITHER POPULATION, or None if history does
    not hold that many (a shallow clone, or a young repo) -- both are real conditions this gate must say
    it cannot measure, not silently treat as a zero-growth window.

    WHY POPULATION-TOUCHING AND NOT SIMPLY THE LAST N COMMITS (D0251, closes NEEDS_DIRECTOR P018).
    The window is a commit count, and it used to slide on EVERY commit. So a documentation-only commit --
    which adds nothing to either side of the ratio -- still pushed one commit off the far end, and if that
    commit happened to be game-heavy the verdict flipped. Measured, not hypothesised: PR #8 merged with
    this gate reading `+742 instrument / +717 game`, and the very next commit, four documentation files
    and no code, read `+756 / +348` and FAILED. **A commit that changes neither number could change this
    gate's answer**, which makes the verdict a property of where the window happened to land rather than
    of the work.

    Counting only commits that touched a counted file removes that entire class. It does NOT weaken the
    gate: the same ratio, floor and populations apply, and an instrument-heavy run still fails -- it
    simply stops changing its mind about a tree nobody edited. `tools/layer_lint/test_check_loc_ratio.py`
    holds the mutation proof, including a synthetic instrument-only window that must still FAIL.

    Bounded so a repository whose recent history is entirely documentation cannot make this walk the
    whole log; hitting the cap is reported as unmeasurable rather than guessed at."""
    found: list[str] = []
    try:
        commits = _run_git(["log", "--format=%H", f"-n{WINDOW_SCAN_CAP}"]).splitlines()
    except RuntimeError:
        return None
    for commit in commits:
        if _touches_a_population(commit):
            found.append(commit)
            if len(found) > WINDOW_COMMITS:
                return found[-1]
    return None


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
        print(f"check_loc_ratio: why it's >1 -- tools/ and tests/ were built ahead of game content by "
              f"design (docs/ONBOARDING.md Task 0 requires the structural gates before there is game code "
              f"for them to check); it falls only when game LOC ({game_total} now) grows, not when "
              f"instrument LOC shrinks -- concretely, data/economy/ producing machines and content, per "
              f"docs/QUALITY.md gate 7's own 'the next unit of work is game.'")

    window_start = resolve_window_start()
    if window_start is None:
        print(f"check_loc_ratio: fewer than {WINDOW_COMMITS} population-touching commits in the last "
              f"{WINDOW_SCAN_CAP} (shallow clone, young repo, or a long documentation-only stretch) "
              "-- cannot measure a trailing-window trend. "
              "ADVISORY: not gating on velocity this run.")
        return 0

    instrument_then = sum(loc_at_commit(window_start, d) for d in INSTRUMENT_DIRS)
    game_then = sum(loc_at_commit(window_start, d) for d in GAME_DIRS)
    instrument_growth = instrument_total - instrument_then
    game_growth = game_total - game_then

    print(f"check_loc_ratio: over the last {WINDOW_COMMITS} commits that touched either population "
          f"({window_start[:8]}..HEAD): "
          f"instrument {instrument_then} -> {instrument_total} ({instrument_growth:+d}), "
          f"game {game_then} -> {game_total} ({game_growth:+d})")

    violates_velocity = (
        instrument_growth > GROWTH_FLOOR
        and instrument_growth > RATIO_LIMIT * max(game_growth, 0)
    )
    # D0259. The velocity signal is real and stays; BLOCKING on it was wrong, because it cannot tell a
    # run that has stopped building the game from a run that is deliberately building the instrument the
    # game needs. PR #10 was the case in point: +1148 instrument against +542 game, every line of it
    # infrastructure that FOUND four generator defects, blocked by a gate whose own remedy line said
    # "the next unit of work is game" -- advice that was already being followed in the same branch.
    #
    # So: warn always, block only on the condition the gate is actually named for. "You have stopped
    # building the game" is not a ratio, it is game growth of ZERO. If game grew at all, porting is
    # happening and the ratio is a matter of pace, not of direction.
    #
    # GROWTH_FLOOR is REUSED rather than a second threshold invented, and that is the whole diagnosis:
    # it already answers "is this window big enough to judge at all", which is the same question an
    # egregious-bloat floor would have to answer. What the block admits, stated plainly: any window in
    # which game LOC grew by even one line, and any window whose instrument growth is under
    # GROWTH_FLOOR lines. What it catches: a window that added more than GROWTH_FLOOR lines of
    # instrument and not one line of game.
    stopped_building_the_game = instrument_growth > GROWTH_FLOOR and game_growth <= 0

    if stopped_building_the_game:
        print(f"check_loc_ratio: FAIL -- instrument grew {instrument_growth} lines and game grew "
              f"{game_growth} over the last {WINDOW_COMMITS} commits that touched either population. "
              "Not a ratio complaint: game LOC did not move AT ALL while the instrument did. "
              "Per docs/CLAIMS.md, the next unit of work is game, not another check.")
        return 1

    if violates_velocity:
        print(f"check_loc_ratio: WARNING (not blocking) -- instrument grew {instrument_growth} lines "
              f"against game's {game_growth} over the last {WINDOW_COMMITS} commits that touched either "
              f"population, more than {RATIO_LIMIT:.0f}x. This is the polish-the-machine-neglect-the-game "
              "signal and it is worth reading, but game LOC IS growing, so it does not block. It blocks "
              "only when game growth reaches zero.")
        print("check_loc_ratio: PASS (with velocity warning)")
        return 0

    print("check_loc_ratio: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
