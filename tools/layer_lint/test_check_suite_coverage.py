#!/usr/bin/env python3
"""Mutation tests for check_suite_coverage.py's YAML-validity branch (D0217).

    python3 tools/layer_lint/test_check_suite_coverage.py

The branch exists because a REGEX OVER A FILE THAT DOES NOT PARSE still finds every string it is
looking for. Two workflow step names written with an unquoted colon made `.github/workflows/harness.yml`
invalid YAML; GitHub ran zero jobs and reported the push as an ordinary red, while this gate read the
same bytes with `re.findall` and printed PASS. Every other gate in the file was unchecked and nothing
said so.

So the branch is exactly the shape `docs/QUALITY.md` warns about -- a check that has never been observed
failing is not a check -- and it is tested here rather than by a shell command in one session's
transcript, which is the finding `test_check_untracked_files.py`'s own docstring already records once.

Runs the real script against a scratch workflow via a temporary `--workflow` override rather than
mutating the repository's own `harness.yml`: a test that edits the live workflow and crashes leaves the
tree broken, and this file must be safe to interrupt.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "check_suite_coverage.py"
RESULTS: list[tuple[str, bool]] = []

VALID = """\
name: harness
on:
  push:
    branches: [main]
jobs:
  tests:
    runs-on: ubuntu-latest
    steps:
      - name: test_alpha (a fine step name, D0000)
        run: bash tools/run_gd_test.sh ./godot res://tests/test_alpha.gd
"""

# The exact break that happened: an unquoted ": " inside a step `name:` turns the rest of the line into
# a second mapping value, which YAML refuses at that indentation.
UNQUOTED_COLON = VALID.replace(
    "- name: test_alpha (a fine step name, D0000)",
    "- name: test_alpha (L2 is a door: observe() is pure, D0000)")

# A second, unrelated syntax error, so the branch is not fitted to one message. Bad indentation on a
# mapping key is the other way a hand-edited workflow usually dies.
BAD_INDENT = VALID.replace("    runs-on: ubuntu-latest", "      runs-on: ubuntu-latest")


def run_against(workflow_text: str, tracked_suites: list[str]) -> tuple[int, str]:
    """Runs the gate against a scratch repo whose workflow is `workflow_text`."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / ".github" / "workflows").mkdir(parents=True)
        (root / "tests").mkdir()
        (root / ".github" / "workflows" / "harness.yml").write_text(workflow_text, encoding="utf-8")
        for name in tracked_suites:
            (root / "tests" / name).write_text("extends RefCounted\n", encoding="utf-8")
        subprocess.run(["git", "init", "-q"], cwd=root, check=True)
        subprocess.run(["git", "config", "user.email", "scratch@test"], cwd=root, check=True)
        subprocess.run(["git", "config", "user.name", "scratch"], cwd=root, check=True)
        subprocess.run(["git", "add", "-A"], cwd=root, check=True)
        subprocess.run(["git", "commit", "-q", "-m", "initial"], cwd=root, check=True)
        proc = subprocess.run([sys.executable, str(SCRIPT), "--root", str(root)],
                              capture_output=True, text=True)
        return proc.returncode, proc.stdout + proc.stderr


def check(name: str, workflow_text: str, expect_fail: bool, expect_substring: str) -> None:
    code, out = run_against(workflow_text, ["test_alpha.gd"])
    failed = code != 0
    ok = (failed == expect_fail) and (expect_substring in out)
    RESULTS.append((name, ok))
    status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name} -- expect_fail={expect_fail}, exit={code}")
    if not ok:
        print("    output was:\n" + "\n".join("      " + line for line in out.splitlines()))


def main() -> int:
    # The negative control FIRST, deliberately: if a well-formed workflow does not pass, the two
    # positives below prove nothing -- they would be failing for whatever is breaking this one.
    check("a valid workflow whose one step runs its one suite passes",
          VALID, expect_fail=False, expect_substring="PASS")
    check("an unquoted ': ' in a step name is caught, not read past",
          UNQUOTED_COLON, expect_fail=True, expect_substring="not valid YAML")
    check("and so is an unrelated syntax error, so the branch is not fitted to one message",
          BAD_INDENT, expect_fail=True, expect_substring="not valid YAML")
    # The reason the branch had to be added at all: the ORIGINAL gate would have passed on both of the
    # broken files above, because a regex finds `res://tests/test_alpha.gd` in a file that cannot load.
    # Asserted directly rather than described, so the claim in the docstring is checkable.
    import re
    for label, text in (("unquoted colon", UNQUOTED_COLON), ("bad indent", BAD_INDENT)):
        found = set(re.findall(r"res://tests/(test_[a-z0-9_]+\.gd)", text))
        ok = found == {"test_alpha.gd"}
        RESULTS.append((f"the regex alone still matches through a broken workflow ({label})", ok))
        print(f"[{'OBSERVED' if ok else 'NOT OBSERVED'}] the regex alone still matches through a "
              f"broken workflow ({label}) -- found {sorted(found)}")

    failed = [n for n, ok in RESULTS if not ok]
    print(f"\ntest_check_suite_coverage: {len(RESULTS) - len(failed)}/{len(RESULTS)} branches observed")
    if failed:
        for n in failed:
            print(f"  UNTESTED: {n}")
        print("test_check_suite_coverage: FAIL.")
        return 1
    print("test_check_suite_coverage: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
