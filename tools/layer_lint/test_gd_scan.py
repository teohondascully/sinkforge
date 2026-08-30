#!/usr/bin/env python3
"""Mutation tests for gd_scan.py's gitignore filter (D0225, NEEDS_DIRECTOR P003).

    python3 tools/layer_lint/test_gd_scan.py

`check_size_limits.py` and `layer_lint.py` enumerated with `rglob("*.gd")` and never consulted git, so
they linted every gitignored `.gd` under `tools/scratch/` on a developer's machine and none of them in
CI, where a fresh checkout has no scratch directory. The same gate name reported on two populations
depending on where it ran -- a local run could fail for a reason CI can never see, and could be made to
pass by deleting an untracked file.

Every case pairs the treatment with its own control, because "the file was not yielded" has two
explanations and only one of them is the fix: the third case is the SAME file in the SAME place with the
ignore rule removed, and it must come back. Without that pair, a filter that dropped everything named
`scratch` on a path-shape heuristic would pass just as well.

The last case pins the exit-code classification. `git check-ignore --stdin` exits **1 when nothing
matched**, which is the ordinary case; a truth-test on the exit code would read that as failure, return
"nothing is ignored", and silently restore the defect while every test above still passed.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gd_scan import gd_files_excluding, git_ignored  # noqa: E402

RESULTS: list[tuple[str, bool]] = []
BUILT: list[Path] = []  # every scratch tree, removed in main()'s finally -- this runs on every commit


def build_tree(gitignore: str | None, as_repo: bool = True) -> Path:
    """A scratch tree with one tracked file and one scratch file, optionally a git repo."""
    root = Path(tempfile.mkdtemp())
    (root / "sim" / "world").mkdir(parents=True)
    (root / "tools" / "scratch").mkdir(parents=True)
    (root / "sim" / "world" / "tile_grid.gd").write_text("class_name TileGrid\n", encoding="utf-8")
    (root / "tools" / "scratch" / "probe.gd").write_text("extends SceneTree\n", encoding="utf-8")
    if gitignore is not None:
        (root / ".gitignore").write_text(gitignore, encoding="utf-8")
    if as_repo:
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    BUILT.append(root)
    return root


def check(name: str, condition: bool, detail: str = "") -> None:
    RESULTS.append((name, condition))
    print(f"[{'OBSERVED' if condition else 'NOT OBSERVED -- BRANCH UNTESTED'}] {name}"
          + (f" -- {detail}" if detail else ""))


def run_checks() -> None:
    ignoring = build_tree("tools/scratch/*\n")
    found = {str(p) for p in gd_files_excluding(ignoring, set())}
    check("a tracked file is still yielded", "sim/world/tile_grid.gd" in found, str(sorted(found)))
    check("an ignored scratch file is NOT yielded", "tools/scratch/probe.gd" not in found,
          str(sorted(found)))

    # The control that makes the line above mean something: same tree, same paths, no ignore rule.
    plain = build_tree(None)
    found_plain = {str(p) for p in gd_files_excluding(plain, set())}
    check("CONTROL: without the ignore rule the SAME file comes back",
          "tools/scratch/probe.gd" in found_plain, str(sorted(found_plain)))

    # Fallback: outside a repository the filter must not drop anything.
    loose = build_tree("tools/scratch/*\n", as_repo=False)
    found_loose = {str(p) for p in gd_files_excluding(loose, set())}
    check("outside a git repository nothing is dropped (today's behaviour preserved)",
          "tools/scratch/probe.gd" in found_loose, str(sorted(found_loose)))

    # The exit-code classification, asserted directly rather than inferred from the cases above.
    empty = git_ignored(plain, [Path("sim/world/tile_grid.gd")])
    check("check-ignore exiting 1 (nothing matched) yields an empty set, not a crash or a fallback",
          empty == set(), f"got {empty!r}")


def main() -> int:
    try:
        run_checks()
    finally:
        for root in BUILT:
            shutil.rmtree(root, ignore_errors=True)
    failed = [name for name, ok in RESULTS if not ok]
    print(f"\ntest_gd_scan: {len(RESULTS) - len(failed)}/{len(RESULTS)} branches observed")
    for name in failed:
        print(f"  UNTESTED: {name}")
    print("test_gd_scan: " + ("FAIL." if failed else "PASS."))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
