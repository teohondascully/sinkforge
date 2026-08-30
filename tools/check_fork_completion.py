#!/usr/bin/env python3
"""Refuses to accept a fork/subagent's own "done" report unless the files it claims to have changed
actually appear in the tree's own diff.

    python3 tools/check_fork_completion.py --claimed=path/a.gd,path/b.md [--base=HEAD] [--cwd=DIR]

2026-08-29: a background fork reported `status: completed` with a detailed prose summary of work done
against two target files -- `git diff` showed neither file had actually changed. Caught only because the
orchestrating session happened to check the diff by hand instead of trusting the summary (originally
logged as `.anvil/log/2026-08-29T074921.640759Z-ad065cf8.json` -- Anvil is parked, `docs/DECISIONS_
LEDGER.md` D0153-D0155, this specific log no longer exists; the finding itself is preserved in full in
`docs/DECISIONS_LEDGER.md` D0130, which this checker exists to close), extending the sweep-blindness law
(D0105) into fork/subagent coordination for the first time. The director's own
words: "A report about a change is not the change. The tree is the change." This is that reconciliation
made mechanical, per the director's explicit instruction that catching this by hand is exactly the manual
vigilance the gates exist to replace -- see `.claude/commands/wrap.md`'s own checklist for where this is
now a required step.

`--base` defaults to `HEAD` (staged + unstaged working-tree changes against the last commit) -- the shape
a fork's own uncommitted work is checked in. Pass a commit range (`--base=<sha>`) to verify a specific
landed commit's own diff against what it claimed instead.

Only checks that each claimed file APPEARS in the diff -- it cannot and does not judge whether the change
inside that file is actually the claimed work, the same limited scope `check_untracked_files.py` and
every other gate in this directory has: a file with real changes that happen to be wrong is a correctness
question for a human or a code-review pass, not something a diff-membership check can see. This closes
the specific, cheap-to-detect failure mode measured above (a fork touching NOTHING while reporting
success), not the harder one (a fork touching the wrong thing while reporting success).
"""
import argparse
import subprocess
import sys
from pathlib import Path


def changed_files(base: str, cwd: Path) -> set[str]:
    """Every path git reports as changed in the working tree relative to `base`, repo-root-relative.
    `git diff` alone is not enough -- it never lists untracked paths, by design, so a fork that CREATED
    a new file rather than modifying an existing one would be wrongly reported as having touched nothing
    (found by smoke-testing this exact script against its own two newly-created files before trusting
    it). Untracked-but-not-yet-`git add`ed new files are pulled in separately via `git ls-files --others
    --exclude-standard` and unioned in."""
    diff = subprocess.run(["git", "diff", "--name-only", base], cwd=cwd,
                           capture_output=True, text=True, check=True)
    untracked = subprocess.run(["git", "ls-files", "--others", "--exclude-standard"], cwd=cwd,
                                capture_output=True, text=True, check=True)
    return ({line for line in diff.stdout.splitlines() if line} |
            {line for line in untracked.stdout.splitlines() if line})


def find_missing(claimed: list[str], base: str, cwd: Path) -> list[str]:
    """Claimed files that do NOT appear in the diff -- empty means every claim is backed by a real
    change. Order-preserving, not a set, so a report can name exactly which claims were unbacked."""
    changed = changed_files(base, cwd)
    return [f for f in claimed if f not in changed]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--claimed", required=True,
                         help="comma-separated file paths (repo-root-relative) the fork claims to have changed")
    parser.add_argument("--base", default="HEAD",
                         help="git ref to diff against (default: HEAD, i.e. working-tree changes)")
    parser.add_argument("--cwd", default=".", help="repository root to run git in (default: .)")
    args = parser.parse_args()

    claimed = [f.strip() for f in args.claimed.split(",") if f.strip()]
    if not claimed:
        print("check_fork_completion: FAIL -- no claimed files given; a completion report naming zero "
              "files is not a verifiable claim")
        return 1

    missing = find_missing(claimed, args.base, Path(args.cwd))
    if missing:
        print(f"check_fork_completion: FAIL -- {len(missing)}/{len(claimed)} claimed file(s) do not "
              f"appear in the diff against {args.base}:")
        for f in missing:
            print(f"  MISSING  {f}")
        print("A 'done' report whose diff does not touch its own claimed files is a failed task, not a "
              "completed one -- resume the fork or redo the work before accepting it.")
        return 1

    print(f"check_fork_completion: PASS -- all {len(claimed)} claimed file(s) appear in the diff "
          f"against {args.base}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
