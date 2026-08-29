#!/usr/bin/env python3
"""Mutation tests for check_fork_completion.py, same discipline as
tools/layer_lint/test_check_untracked_files.py -- a check that has never been observed failing is not a
check (docs/QUALITY.md §2).

    python3 tools/test_check_fork_completion.py

Builds a disposable scratch git repository per case and calls `check_fork_completion.find_missing()`
directly, never the real working tree.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_fork_completion import find_missing  # noqa: E402

RESULTS: list[tuple[str, bool]] = []


def _init_scratch_repo(root: Path) -> None:
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.email", "scratch@test"], cwd=root, check=True)
    subprocess.run(["git", "config", "user.name", "scratch"], cwd=root, check=True)
    (root / "a.txt").write_text("original a\n", encoding="utf-8")
    (root / "b.txt").write_text("original b\n", encoding="utf-8")
    (root / "c.txt").write_text("original c\n", encoding="utf-8")
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)
    subprocess.run(["git", "commit", "-q", "-m", "initial"], cwd=root, check=True)


def check(name: str, missing: list[str], expect_missing: list[str]) -> None:
    ok = missing == expect_missing
    RESULTS.append((name, ok))
    status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name} -- got missing={missing}, want {expect_missing}")


def branch_no_op_fork_claims_done_but_touched_nothing() -> None:
    """The exact incident this tool exists for: a fork claims two files, changes neither. Must report
    BOTH as missing, not silently pass."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch_repo(root)
        missing = find_missing(["a.txt", "b.txt"], "HEAD", root)
        check("positive control: fork claims 2 files, touches 0 (broken)", missing, ["a.txt", "b.txt"])


def branch_fork_did_the_real_work() -> None:
    """The honest case: claimed files actually changed. Must report nothing missing."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch_repo(root)
        (root / "a.txt").write_text("changed a\n", encoding="utf-8")
        (root / "b.txt").write_text("changed b\n", encoding="utf-8")
        missing = find_missing(["a.txt", "b.txt"], "HEAD", root)
        check("negative control: fork claims 2 files, touches both (fixed)", missing, [])


def branch_partial_completion() -> None:
    """A fork that did SOME of its claimed work but not all -- must name exactly the untouched file,
    not report a bare pass/fail with no detail, and must not report the touched file as missing too."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch_repo(root)
        (root / "a.txt").write_text("changed a\n", encoding="utf-8")
        missing = find_missing(["a.txt", "b.txt", "c.txt"], "HEAD", root)
        check("partial completion: only a.txt actually changed", missing, ["b.txt", "c.txt"])


def branch_new_untracked_file_counts_as_touched() -> None:
    """The real bug found while smoke-testing this tool before trusting it: `git diff` alone never lists
    untracked paths, so a fork that CREATED a brand-new file (not yet `git add`ed) would be wrongly
    reported as having touched nothing. A new, never-committed file must count as claimed-and-touched."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch_repo(root)
        (root / "new_file.txt").write_text("brand new, never added\n", encoding="utf-8")
        missing = find_missing(["new_file.txt"], "HEAD", root)
        check("a newly-created untracked file counts as touched, not missing", missing, [])


def branch_extra_real_changes_do_not_mask_a_missing_claim() -> None:
    """A fork that changed a file it did NOT claim must not let that unrelated change hide a missing
    claimed file -- diff-membership is checked per claimed file, not just 'was anything changed'."""
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        _init_scratch_repo(root)
        (root / "c.txt").write_text("changed c, never claimed\n", encoding="utf-8")
        missing = find_missing(["a.txt"], "HEAD", root)
        check("unclaimed change elsewhere does not mask a missing claimed file", missing, ["a.txt"])


def main() -> int:
    for branch in (branch_no_op_fork_claims_done_but_touched_nothing,
                   branch_fork_did_the_real_work,
                   branch_partial_completion,
                   branch_new_untracked_file_counts_as_touched,
                   branch_extra_real_changes_do_not_mask_a_missing_claim):
        branch()

    failed = [name for name, ok in RESULTS if not ok]
    print()
    print(f"test_check_fork_completion: {len(RESULTS) - len(failed)}/{len(RESULTS)} cases observed correctly.")
    if failed:
        print("test_check_fork_completion: FAIL -- these branches did not fire as expected:")
        for name in failed:
            print(f"  {name}")
        return 1

    print("test_check_fork_completion: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
