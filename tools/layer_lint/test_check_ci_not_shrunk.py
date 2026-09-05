#!/usr/bin/env python3
"""Mutation tests for check_ci_not_shrunk.py, QUALITY gate 36 (numbered 30 until D0394; D0266/D0284).

    python3 tools/layer_lint/test_check_ci_not_shrunk.py

The gate answers "did the CI check set get smaller", and the whole reason it exists is that the
smaller set reports GREEN. So every branch below is a mutation: a workflow deliberately damaged in one
specific way, run against a base that still has the undamaged version, with the verdict observed.

Two generations of the gate are covered. The NAME properties (a job or a suite disappears) are D0266's.
The ENFORCEMENT properties are D0284's, and they exist because D0266's own docstring named its hole:
**a job gutted to `run: true` keeps its name and passed**. Four mutants here are exactly that shape --
gutted step, deleted step, `continue-on-error` flipped onto a blocking step, and a job-level `if:`
added -- and each one leaves every job name and every suite name in place.

Everything runs against a scratch git repository via `--root`, never against this repository's own
`.github/workflows/`: a test that edits the live workflow and is interrupted leaves the tree broken,
which is the finding `test_check_suite_coverage.py`'s docstring already records once.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_test_support import Observations  # noqa: E402

SCRIPT = Path(__file__).resolve().parent / "check_ci_not_shrunk.py"
LOG = Observations("test_check_ci_not_shrunk")

# A miniature of the real harness.yml, carrying every shape the gate has to reason about: an enforcing
# step with a path token, a `continue-on-error` step that must contribute nothing, a step whose real
# work has NO path-shaped token at all (only the work-step count can see that one being gutted), a
# `uses:` step with `with:` keys, and the step that runs this gate itself -- QUALITY section 2 requires
# a gate's own mutation test to include the case where the gate's own subject is what trips it.
BASE = """\
name: harness
on:
  push:
    branches: [main]
jobs:
  gates:
    name: structural gates
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0
      - name: Layer dependency lint
        run: python3 tools/layer_lint/layer_lint.py
      - name: The CI check set has not SHRUNK
        run: python3 tools/layer_lint/check_ci_not_shrunk.py
      - name: Duplication (BLOCKING)
        run: python3 tools/quality_check/duplication.py
      - name: Complexity (report only)
        continue-on-error: true
        run: python3 tools/quality_check/complexity.py
      - name: Gate mutation tests (no path-shaped token anywhere in this one)
        run: |
          set -e
          while IFS= read -r f; do
            python3 "$f"
          done < <(find tools -name 'test_*.py' | sort)
  tests:
    name: godot test suites
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: all suites, in parallel
        run: |
          bash tools/run_suites.sh ./godot 4 \\
            res://tests/test_alpha.gd \\
            res://tests/test_beta.gd
  headed_boot:
    name: headed boot
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: the documented invocation opens a window
        run: xvfb-run -a bash tools/check_headed_boot.sh ./godot
"""


def sub(old: str, new: str) -> str:
    """One textual mutation of BASE, with the anchor-found witness the harness cannot do without.

    A replacement that matches nothing yields a file identical to the base, and an identical file
    PASSES -- so a silently-missed anchor reports "the mutant was not caught" for a reason that has
    nothing to do with the gate. Raising here makes that impossible to mistake for a result."""
    if old not in BASE:
        raise AssertionError(f"mutation anchor not present in BASE: {old!r}")
    return BASE.replace(old, new, 1)


def run_against(now: str, message: str = "", workflow: bool = True, on_main: bool = True) -> tuple[int, str]:
    """Commits BASE, then puts `now` in the working tree (or in a commit carrying `message`)."""
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        wf = root / ".github" / "workflows"
        wf.mkdir(parents=True)
        (wf / "harness.yml").write_text(BASE, encoding="utf-8")
        git = lambda *a: subprocess.run(["git", "-C", str(root), *a], check=True,  # noqa: E731
                                        capture_output=True, text=True)
        git("init", "-q")
        git("config", "user.email", "scratch@test")
        git("config", "user.name", "scratch")
        git("symbolic-ref", "HEAD", f"refs/heads/{'main' if on_main else 'sidebranch'}")
        git("add", "-A")
        git("commit", "-q", "-m", "base")
        if not workflow:
            (wf / "harness.yml").unlink()
        else:
            (wf / "harness.yml").write_text(now, encoding="utf-8")
        if message:
            git("checkout", "-q", "-b", "feature")
            git("add", "-A")
            git("commit", "-q", "-m", message)
        proc = subprocess.run([sys.executable, str(SCRIPT), "--root", str(root)],
                              capture_output=True, text=True)
        return proc.returncode, proc.stdout + proc.stderr


def observe(name: str, now: str, expect_code: int, expect_text: str, message: str = "",
            workflow: bool = True, on_main: bool = True) -> None:
    code, out = run_against(now, message, workflow, on_main)
    ok = code == expect_code and expect_text in out
    LOG.observe(name, ok, f"exit={code} (wanted {expect_code})")
    if not ok:
        print("\n".join("      " + line for line in out.splitlines()))


def gutting_mutants() -> None:
    """D0284's shapes. Every job name and every suite name survives all of them, which is why the
    name-set gate that shipped before D0284 passed on every one."""
    observe("a step gutted to `run: true` with its name kept",
            sub("        run: python3 tools/layer_lint/layer_lint.py",
                "        run: true"),
            1, "no longer runs `tools/layer_lint/layer_lint.py`")
    observe("a step's real work deleted outright",
            sub("      - name: Duplication (BLOCKING)\n"
                "        run: python3 tools/quality_check/duplication.py\n", ""),
            1, "no longer runs `tools/quality_check/duplication.py`")
    observe("a BLOCKING step flipped to `continue-on-error: true`, command untouched",
            sub("      - name: Duplication (BLOCKING)\n",
                "      - name: Duplication (BLOCKING)\n        continue-on-error: true\n"),
            1, "no longer runs `tools/quality_check/duplication.py`")
    observe("a job-level `if:` added, switching the job off with every name intact",
            sub("  gates:\n", "  gates:\n    if: false\n"),
            1, "gained a job-level `if:`")

    # The gate's own step is its own subject (QUALITY section 2: a gate is not exempt from the property
    # it measures). Deleting the step that runs THIS script must fire this script.
    observe("the step running this gate itself is deleted, and this gate catches it",
            sub("      - name: The CI check set has not SHRUNK\n"
                "        run: python3 tools/layer_lint/check_ci_not_shrunk.py\n", ""),
            1, "no longer runs `tools/layer_lint/check_ci_not_shrunk.py`")

    # The work-step COUNT, isolated: this step's real work carries no path-shaped token, so the token
    # set is unchanged by gutting it and only the count can tell. Asserting on the count message rather
    # than on the exit code is what makes that isolation checkable rather than asserted.
    observe("a step whose work has no path token is gutted, and only the count sees it",
            sub("        run: |\n          set -e\n          while IFS= read -r f; do\n"
                "            python3 \"$f\"\n          done < <(find tools -name 'test_*.py' | sort)\n",
                "        run: true\n"),
            1, "enforcing run-step(s) that do work, was")


def name_mutants() -> None:
    """D0266's original properties, still live."""
    observe("a job deleted outright still fires the name check",
            sub("  headed_boot:\n    name: headed boot\n    runs-on: ubuntu-latest\n    steps:\n"
                "      - uses: actions/checkout@v5\n"
                "      - name: the documented invocation opens a window\n"
                "        run: xvfb-run -a bash tools/check_headed_boot.sh ./godot\n", ""),
            1, "job `headed_boot` was removed")
    observe("a suite dropped from the runner's argument list fires",
            sub("            res://tests/test_beta.gd\n", ""),
            1, "suite `test_beta.gd` was removed")


def legitimate_refactors() -> None:
    """Each keeps the enforcement and must PASS. A gate that fires on these is a gate people route
    around, and a gate people route around is worth less than no gate at all."""
    observe("steps reordered",
            sub("      - name: Layer dependency lint\n"
                "        run: python3 tools/layer_lint/layer_lint.py\n"
                "      - name: The CI check set has not SHRUNK\n"
                "        run: python3 tools/layer_lint/check_ci_not_shrunk.py\n",
                "      - name: The CI check set has not SHRUNK\n"
                "        run: python3 tools/layer_lint/check_ci_not_shrunk.py\n"
                "      - name: Layer dependency lint\n"
                "        run: python3 tools/layer_lint/layer_lint.py\n"),
            0, "PASS --")
    observe("a command's flags changed",
            sub("        run: python3 tools/layer_lint/layer_lint.py",
                "        run: python3 tools/layer_lint/layer_lint.py --strict -v"),
            0, "PASS --")
    observe("a positional argument changed (the parallel job count)",
            sub("bash tools/run_suites.sh ./godot 4", "bash tools/run_suites.sh ./godot 8"),
            0, "PASS --")
    observe("a step renamed while still running the same tool",
            sub("      - name: Layer dependency lint\n", "      - name: Something else entirely\n"),
            0, "PASS --")
    observe("an action version bumped and a `with:` value changed",
            sub("      - uses: actions/checkout@v5\n        with:\n          fetch-depth: 0\n",
                "      - uses: actions/checkout@v6\n        with:\n          fetch-depth: 1\n"),
            0, "PASS --")
    observe("one step split into two, each keeping its own work",
            sub("      - name: Layer dependency lint\n"
                "        run: python3 tools/layer_lint/layer_lint.py\n",
                "      - name: Layer dependency lint\n"
                "        run: python3 tools/layer_lint/layer_lint.py\n"
                "      - name: An added step\n"
                "        run: python3 tools/layer_lint/gd_scan.py\n"),
            0, "PASS --")


def marker_branches() -> None:
    """The two commit-message markers. Neither may be satisfiable from a file, so both are posed by
    committing a real message on a real branch off the base."""
    observe("a removed job declared by CI-Check-Removed in the commit message is allowed",
            sub("  headed_boot:\n    name: headed boot\n    runs-on: ubuntu-latest\n    steps:\n"
                "      - uses: actions/checkout@v5\n"
                "      - name: the documented invocation opens a window\n"
                "        run: xvfb-run -a bash tools/check_headed_boot.sh ./godot\n", ""),
            0, "DECLARED",
            message="drop the headed job\n\nCI-Check-Removed: headed_boot -- xvfb moved to a nightly")
    observe("a gutted job declared by CI-Enforcement-Changed in the commit message is allowed",
            sub("        run: python3 tools/layer_lint/layer_lint.py", "        run: true"),
            0, "DECLARED",
            message="park the layer lint\n\nCI-Enforcement-Changed: gates -- lint moved to a pre-commit hook")
    observe("the WRONG job named in CI-Enforcement-Changed does not cover the gutted one",
            sub("        run: python3 tools/layer_lint/layer_lint.py", "        run: true"),
            1, "no longer runs `tools/layer_lint/layer_lint.py`",
            message="park the layer lint\n\nCI-Enforcement-Changed: tests -- wrong job on purpose")


def cannot_compare_branches() -> None:
    """CANNOT COMPARE is exit 2, never a pass: "I could not compare" and "nothing was removed" must not
    look alike, which is the whole reason this gate does not have a two-value contract. Each case
    asserts its OWN message rather than the shared "CANNOT COMPARE" -- three cases passing on one
    substring would be one case counted three times."""
    observe("a workflow that does not parse is exit 2, not a pass",
            sub("    name: structural gates\n", "      name: structural gates\n"),
            2, "does not parse as a workflow")
    observe("no workflows at all is exit 2, not a green over an empty population",
            BASE, 2, "no workflows found under", workflow=False)
    observe("no merge base against main or origin/main is exit 2",
            BASE, 2, "no merge base against origin/main or main", on_main=False)


def main() -> int:
    # THE NEGATIVE CONTROL FIRST, deliberately. If an unmutated workflow does not pass, every mutant
    # below is failing for whatever is breaking this one, and none of them is evidence of anything.
    observe("an unchanged workflow passes", BASE, 0, "PASS --")
    gutting_mutants()
    name_mutants()
    legitimate_refactors()
    marker_branches()
    cannot_compare_branches()
    return LOG.summarise()


if __name__ == "__main__":
    sys.exit(main())
