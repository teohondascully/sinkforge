#!/usr/bin/env python3
"""Mutation tests for `check_loc_ratio.py`'s window, D0251 (closes NEEDS_DIRECTOR P018).

WHY THIS FILE EXISTS AND WHY IT IS ADVERSARIAL. The change it covers -- counting the window over the last
N commits that TOUCHED either population, rather than the last N commits -- was made by a session whose
own documentation PR the gate was blocking. A gate relaxation that unblocks its author is exactly the
change nobody should take on trust, so the load-bearing branch here is not the one that passes: it is
`instrument_only_window_still_FAILS`. If that branch ever goes green, this gate has been turned off and
this file is the thing that says so.

The property the change is supposed to deliver is branch 3: interleaving documentation commits must not
change the verdict. That was the actual defect -- a commit adding nothing to either side of the ratio
still slid the window by one, so a game-heavy commit could fall off the far end and flip the answer.
Measured on the real repository before the fix: `+742/+717 PASS`, then four documentation files later,
`+756/+348 FAIL`, with no code touched in between.

Runs the gate against synthetic git repositories: `ROOT` is `Path(__file__).parents[2]`, so a copy of the
script placed at `<tmp>/tools/layer_lint/` measures `<tmp>`.

Usage: python3 tools/layer_lint/test_check_loc_ratio.py
"""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REAL_ROOT = Path(__file__).resolve().parents[2]
GATE = REAL_ROOT / "tools" / "layer_lint" / "check_loc_ratio.py"
WINDOW = 10  # keep in step with the gate's own WINDOW_COMMITS


def git(root: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(root), *args], check=True,
                   capture_output=True, text=True)


def new_repo() -> Path:
    root = Path(tempfile.mkdtemp())
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "t@example.invalid")
    git(root, "config", "user.name", "t")
    dest = root / "tools" / "layer_lint"
    dest.mkdir(parents=True)
    shutil.copy(GATE, dest / "check_loc_ratio.py")
    # The gate's own copy lives under tools/, which IS the instrument population -- commit it first so
    # it is part of the baseline rather than counted as growth inside every window under test.
    git(root, "add", "-A")
    git(root, "commit", "-qm", "seed: the gate itself")
    return root


def commit_lines(root: Path, rel: str, lines: int, message: str) -> None:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("\n".join(f"# line {i}" for i in range(lines)) + "\n")
    git(root, "add", "-A")
    git(root, "commit", "-qm", message)


def run_gate(root: Path) -> tuple[int, str]:
    r = subprocess.run([sys.executable, str(root / "tools" / "layer_lint" / "check_loc_ratio.py")],
                       cwd=root, capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


def window_line(out: str) -> str:
    for line in out.splitlines():
        if "over the last" in line and "..HEAD" in line:
            return line.strip()
    return ""


failures: list[str] = []
observed = 0


def check(ok: bool, label: str) -> None:
    global observed
    observed += 1
    print(f"  {'PASS' if ok else 'FAIL'}  {label}")
    if not ok:
        failures.append(label)


# --- 1. THE BRANCH THAT MATTERS ------------------------------------------------------------------
# An instrument-only window must still be refused. This is the mutant that a careless "just widen the
# window until it passes" would let through, and it is the reason the change is a fix and not a bypass.
def branch_instrument_only_window_still_fails() -> None:
    root = new_repo()
    try:
        for i in range(WINDOW + 1):
            commit_lines(root, f"tools/thing_{i}.py", 200, f"instrument {i}")
        rc, out = run_gate(root)
        check(rc == 1, "an instrument-only window still FAILS (exit %d) -- the gate is not turned off" % rc)
        check("FAIL" in out and "next unit of work is game" in out,
              "and it still says why, in CLAIMS.md's own words")
        check("did not move AT ALL" in out,
              "and it blocks on the RIGHT condition -- zero game growth, not a ratio (D0259)")
    finally:
        shutil.rmtree(root, ignore_errors=True)


# --- 2. the negative control: balanced growth must pass, or the gate is simply always-red ----------
def branch_balanced_window_passes() -> None:
    root = new_repo()
    try:
        for i in range(WINDOW + 1):
            commit_lines(root, f"tools/thing_{i}.py", 100, f"instrument {i}")
            commit_lines(root, f"core/thing_{i}.gd", 100, f"game {i}")
        rc, _ = run_gate(root)
        check(rc == 0, "a balanced window PASSES (exit %d) -- the gate is not simply always-red" % rc)
    finally:
        shutil.rmtree(root, ignore_errors=True)


# --- 3. THE PROPERTY THE CHANGE EXISTS FOR --------------------------------------------------------
# Two repositories with IDENTICAL population history, one with documentation commits interleaved. The
# verdict and the resolved window must be the same. Under the old rule the docs commits slid the window
# and could change the answer; that is the defect, stated as a differential test rather than as prose.
def branch_documentation_commits_do_not_move_the_window() -> None:
    def build(with_docs: bool) -> tuple[int, str]:
        root = new_repo()
        try:
            for i in range(WINDOW + 2):
                commit_lines(root, f"core/thing_{i}.gd", 120, f"game {i}")
                commit_lines(root, f"tools/thing_{i}.py", 100, f"instrument {i}")
                if with_docs:
                    commit_lines(root, f"docs/note_{i}.md", 400, f"docs {i}")
            rc, out = run_gate(root)
            return rc, window_line(out)
        finally:
            shutil.rmtree(root, ignore_errors=True)

    rc_plain, line_plain = build(with_docs=False)
    rc_docs, line_docs = build(with_docs=True)
    check(rc_plain == rc_docs,
          "interleaving documentation commits does not change the VERDICT (%d vs %d)" % (rc_plain, rc_docs))
    # Compare the measured numbers, not the abbreviated sha -- the two repositories are built
    # independently so their hashes differ by construction while the population history is identical.
    nums_plain = line_plain.split("):", 1)[-1]
    nums_docs = line_docs.split("):", 1)[-1]
    check(nums_plain == nums_docs and nums_plain != "",
          "and it does not change the measured window either:\n           without docs:%s\n           with docs:   %s"
          % (nums_plain, nums_docs))


# --- 4. a commit under a population dir that changes no COUNTED file must not admit itself ---------
# `_touches_a_population` shares `_is_counted` with the measurement on purpose: a commit editing
# `tools/README.md` contributes zero lines to the ratio, so letting it into the window would reintroduce
# exactly the class this change removes, one level down.
def branch_uncounted_file_under_a_population_dir_does_not_admit_a_commit() -> None:
    def build(with_readmes: bool) -> str:
        root = new_repo()
        try:
            for i in range(WINDOW + 2):
                commit_lines(root, f"core/thing_{i}.gd", 120, f"game {i}")
                commit_lines(root, f"tools/thing_{i}.py", 100, f"instrument {i}")
                if with_readmes:
                    commit_lines(root, f"tools/README_{i}.md", 400, f"tools prose {i}")
            return window_line(run_gate(root)[1]).split("):", 1)[-1]
        finally:
            shutil.rmtree(root, ignore_errors=True)

    check(build(with_readmes=False) == build(with_readmes=True),
          "a commit touching only an uncounted file UNDER tools/ does not enter the window either")


# --- 5. too few population-touching commits: unmeasurable, and it must SAY so ----------------------
# The error path has to be checked explicitly because it returns 0. A gate whose "cannot measure" branch
# is indistinguishable from its "measured and fine" branch is the house failure class.
def branch_too_few_population_commits_is_unmeasurable_not_a_pass() -> None:
    root = new_repo()
    try:
        commit_lines(root, "core/only.gd", 50, "one game commit")
        for i in range(30):
            commit_lines(root, f"docs/note_{i}.md", 10, f"docs {i}")
        rc, out = run_gate(root)
        check(rc == 0 and "cannot measure" in out,
              "a history without %d population-touching commits reports CANNOT MEASURE, "
              "not a silent pass claiming a measurement" % WINDOW)
        check("ADVISORY" in out, "and marks itself advisory so a reader cannot mistake it for a verdict")
    finally:
        shutil.rmtree(root, ignore_errors=True)



# --- 6. D0259: instrument-heavy but game IS growing -- WARNS without BLOCKING ----------------------
# The case that stalled a real run. PR #10 grew instrument +1148 against game +542 -- more than the 2x
# velocity limit, so the old rule blocked it -- while every one of those instrument lines was building
# the measurement that found four generator defects, and game LOC was growing in the same branch. A gate
# whose remedy line says "the next unit of work is game" must not block a branch that is doing game work.
#
# The distinction this asserts is the whole of the change: instrument outpacing game is a PACE signal
# (warn), game not moving at all is a DIRECTION signal (block). Both are checked here against the same
# repository shape so the pair cannot drift apart -- 300 instrument lines per commit against 100 game
# lines is 3x, comfortably over RATIO_LIMIT, with game growth strictly positive.
def branch_instrument_heavy_with_game_growth_warns_but_passes() -> None:
    root = new_repo()
    try:
        for i in range(WINDOW + 1):
            commit_lines(root, f"tools/thing_{i}.py", 300, f"instrument {i}")
            commit_lines(root, f"core/thing_{i}.gd", 100, f"game {i}")
        rc, out = run_gate(root)
        check(rc == 0,
              "instrument growing 3x game PASSES when game is growing (exit %d) -- the pace signal "
              "does not block the direction" % rc)
        check("WARNING (not blocking)" in out,
              "but it WARNS -- the polish-the-machine signal stays visible, it just stops being a wall")
        check("FAIL" not in out, "and says nothing that reads as a failure")
    finally:
        shutil.rmtree(root, ignore_errors=True)


# --- 7. D0259: the warning is not free -- silence here would mean the signal was over-loosened -------
# The honesty test the ruling names: a PR that is pure instrument bloat with no game and no docs must
# STILL be caught. Branch 1 proves it blocks; this proves the WARNING text itself is reachable and is not
# printed unconditionally, by checking a balanced window stays silent.
def branch_balanced_window_emits_no_warning() -> None:
    root = new_repo()
    try:
        for i in range(WINDOW + 1):
            commit_lines(root, f"tools/thing_{i}.py", 100, f"instrument {i}")
            commit_lines(root, f"core/thing_{i}.gd", 100, f"game {i}")
        rc, out = run_gate(root)
        check(rc == 0 and "WARNING" not in out,
              "a balanced window emits NO warning (exit %d) -- the warning is conditional, not decoration" % rc)
    finally:
        shutil.rmtree(root, ignore_errors=True)

def main() -> int:
    print("test_check_loc_ratio: the window counts population-touching commits (D0251)")
    branch_instrument_only_window_still_fails()
    branch_balanced_window_passes()
    branch_documentation_commits_do_not_move_the_window()
    branch_uncounted_file_under_a_population_dir_does_not_admit_a_commit()
    branch_too_few_population_commits_is_unmeasurable_not_a_pass()
    branch_instrument_heavy_with_game_growth_warns_but_passes()
    branch_balanced_window_emits_no_warning()
    print()
    if failures:
        print(f"test_check_loc_ratio: FAIL -- {len(failures)} of {observed} branches")
        return 1
    print(f"test_check_loc_ratio: {observed}/{observed} branches observed")
    print("test_check_loc_ratio: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
