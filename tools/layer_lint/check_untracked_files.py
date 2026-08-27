#!/usr/bin/env python3
"""No file may be untracked unless the shipped `.gitignore` says so. `docs/QUALITY.md` gate 27.

    python3 tools/layer_lint/check_untracked_files.py

The property this checks is "does a fresh clone match my working copy" -- NOT "are there zero untracked
files." Those are different: legitimate local state (`.godot/`, `__pycache__/`, `.DS_Store`) is untracked
and covered by `.gitignore`, and a fresh clone would produce it too once the tools that generate it run.
What must never happen is a file the project depends on being untracked ONLY because of something local
-- `.git/info/exclude` or the global excludesfile -- neither of which travels with a clone. ANVIL step 1
(2026-08-27) found exactly that: fifteen real document paths hidden from every fresh checkout this way,
one of them (`docs/PRIORITY.md`) 3,447 lines.

`git ls-files --others --exclude-from=.gitignore` is deliberately NOT `git status` or
`git ls-files --others --exclude-standard` -- `--exclude-standard` also honors `.git/info/exclude` and
the global excludesfile, which would make this gate blind to the exact failure class it exists to catch.
Only the tracked, shipped `.gitignore` may excuse a file from this check.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def find_violations(root: Path) -> list[str]:
    """The pure part: untracked files not covered by the .gitignore at `root`. Split out from main() so
    `test_check_untracked_files.py` can point this at a disposable scratch git repo instead of the real
    working tree -- an external audit found this gate's mutation claim existed only as a manual
    transcript, not a checked-in, re-runnable test (`docs/DECISIONS_LEDGER.md` D0071).
    """
    result = subprocess.run(
        ["git", "ls-files", "--others", "--exclude-from=.gitignore"],
        cwd=root, capture_output=True, text=True, check=True,
    )
    return [line for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    violations = find_violations(ROOT)

    if violations:
        print(f"check_untracked_files: FAIL -- {len(violations)} file(s) are untracked and not covered "
              f"by the shipped .gitignore. A fresh clone would not have these; either track them, add a "
              f"real .gitignore pattern for them, or delete them:")
        for path in violations:
            print(f"  {path}")
        return 1

    print("check_untracked_files: PASS -- every untracked file is covered by the shipped .gitignore.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
