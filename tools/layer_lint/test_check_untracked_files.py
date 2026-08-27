#!/usr/bin/env python3
"""Mutation tests for check_untracked_files.py, checked in rather than left as a manual transcript in a
brief -- an external (Codex) audit's exact finding: "I found no current executable 3/3 mutation test
accompanying the gate. The 3/3 claim exists only in the brief." `docs/DECISIONS_LEDGER.md` D0071.

    python3 tools/layer_lint/test_check_untracked_files.py

Builds a disposable scratch git repository per case (`git init` in a `tempfile.TemporaryDirectory()`) and
calls `check_untracked_files.find_violations(scratch_root)` directly -- never touches the real working
tree, matching `tools/anvil/test_check_integrity.py`'s own pattern.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_untracked_files import find_violations  # noqa: E402

RESULTS: list[tuple[str, bool]] = []


def _init_scratch_repo(root: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.email", "scratch@test"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.name", "scratch"], cwd=root, check=True)
    (root / "README.md").write_text("scratch repo\n", encoding="utf-8")
    (root / ".gitignore").write_text("*.ignored\nbuild/\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "initial"], cwd=root, check=True)


def check(name: str, root: Path, expect_violation: bool, expect_substring: str | None = None) -> None:
    violations = find_violations(root)
    fired = bool(violations)
    matched = expect_substring is None or any(expect_substring in v for v in violations)
    ok = (fired == expect_violation) and matched
    RESULTS.append((name, ok))
    status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name} -- expect_violation={expect_violation}, got {violations}")


def branch_positive_control() -> None:
    """A real untracked file outside any .gitignore pattern must FAIL."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch_repo(root)
        (root / "not_ignored.md").write_text("probe\n", encoding="utf-8")
        check("positive control: untracked, not covered by .gitignore (broken)", root,
              expect_violation=True, expect_substring="not_ignored.md")


def branch_negative_control() -> None:
    """A file legitimately covered by .gitignore must NOT be reported."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch_repo(root)
        (root / "scratch.ignored").write_text("probe\n", encoding="utf-8")
        check("negative control: covered by .gitignore (fixed)", root, expect_violation=False)


def branch_local_exclude_only_still_fails() -> None:
    """The property that actually matters: a file hidden ONLY via .git/info/exclude (never travels with
    a clone) must still FAIL. This is the specific gap ANVIL step 1 found and this gate exists to close
    -- a gate that trusted the local exclude file would reproduce the exact hole it was built to catch.
    """
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch_repo(root)
        (root / "locally_hidden.md").write_text("probe\n", encoding="utf-8")
        (root / ".git" / "info" / "exclude").write_text("locally_hidden.md\n", encoding="utf-8")
        # Sanity check within the case itself: git status must actually treat it as ignored locally,
        # otherwise this test would pass for the wrong reason (the file just isn't hidden at all).
        status = subprocess.run(["git", "status", "--porcelain"], cwd=root, capture_output=True,
                                 text=True, check=True).stdout
        locally_hidden_confirmed = "locally_hidden.md" not in status
        check("core property: hidden only via .git/info/exclude, still FAILs", root,
              expect_violation=True, expect_substring="locally_hidden.md")
        RESULTS.append(("sanity: .git/info/exclude actually hid the file from git status",
                         locally_hidden_confirmed))
        print(f"[{'OBSERVED' if locally_hidden_confirmed else 'NOT OBSERVED -- BRANCH UNTESTED'}] "
              f"sanity: git status hid the probe file: {locally_hidden_confirmed}")


def branch_clean_tree() -> None:
    """Nothing untracked at all -- no violations, the ordinary case."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch_repo(root)
        check("clean tree: nothing untracked (fixed)", root, expect_violation=False)


def main() -> int:
    for branch in (branch_positive_control, branch_negative_control,
                   branch_local_exclude_only_still_fails, branch_clean_tree):
        branch()

    failed = [name for name, ok in RESULTS if not ok]
    print()
    print(f"test_check_untracked_files: {len(RESULTS) - len(failed)}/{len(RESULTS)} cases observed correctly.")
    if failed:
        print("test_check_untracked_files: FAIL -- these branches did not fire as expected:")
        for name in failed:
            print(f"  {name}")
        return 1

    print("test_check_untracked_files: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
