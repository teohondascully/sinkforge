#!/usr/bin/env python3
"""The suite count in CI's own step name must be the number of suites that step runs.

    python3 tools/layer_lint/check_ci_suite_count.py [workflow.yml]

## Why this gate exists

`.github/workflows/harness.yml`'s parallel step was named `all 49 suites, in parallel` while invoking
**62**. Found by a Codex audit. Nothing was broken -- every suite ran -- but the verification UI, the
one surface a reviewer actually reads to decide whether a PR is safe, stated a number thirteen short of
the truth for however many suites it took to drift that far.

A count written by hand next to the thing it counts is a drift waiting to happen, and this one had
already drifted twice: the same file carries `42 headless suites` and `42 suite results` in prose from
D0248's era. Those two are HISTORY -- they describe what was true when that finding was made -- and are
left alone, reworded to say so. This gate is about the label that makes a live claim.

## Why the number is not simply removed

The obvious fix is to delete the count and let the step name say `all suites`. GitHub Actions cannot
help here: a step `name:` is evaluated before any shell runs, so it cannot interpolate the output of
`tools/list_ci_suites.py` or of anything else. The choice is a hand-written number or no number, and no
number costs a genuinely useful thing -- at a glance, in the run list, you can see whether this commit
ran sixty-two suites or six.

So the number stays and becomes checkable. That is the same trade `check_suite_coverage.py` already
makes one gate over: hand-written lists are fine when something reconciles them.

## What it compares, and the one thing it refuses to do

DERIVED from the step's own `run:` block -- the `res://tests/*.gd` arguments actually passed to
`run_suites.sh` -- against the integer in that same step's `name:`. Not against `tools/list_ci_suites.py`,
even though that tool exists and agrees today: that tool reads the whole `tests` job, and a future step
in that job that ran one extra suite would make its total correct and this label wrong, with the gate
green. **The population must be the step the label is about.** `[[mechanism-vs-population]]`.

It also refuses to pass when the name has NO number in it. A gate whose subject can vanish is a gate
that reports success for its own absence -- `[[empty-population-guard]]` -- and deleting the count is
exactly the edit someone reaches for when this fails.
"""
import pathlib
import re
import sys

import yaml

JOB = "tests"
RUNNER = "run_suites.sh"
SUITE_RE = re.compile(r"res://[\w./-]+\.gd")
# The count as the label writes it: "all 62 suites". Deliberately narrow -- a bare integer anywhere in a
# step name would match version numbers, job counts and parallelism factors.
LABEL_RE = re.compile(r"\ball (\d+) suites\b")


def main() -> int:
    path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".github/workflows/harness.yml")
    if not path.is_file():
        print(f"check_ci_suite_count: FAIL -- no workflow at {path}", file=sys.stderr)
        return 2
    doc = yaml.safe_load(path.read_text(encoding="utf-8"))
    jobs = (doc or {}).get("jobs") or {}
    if JOB not in jobs:
        # Exit 2, not 0. An absent job is the shape where "found no mismatches" and "could not look"
        # produce the same silence, which is the failure this whole family of gates exists to avoid.
        print(f"check_ci_suite_count: FAIL -- {path} has no '{JOB}' job to read", file=sys.stderr)
        return 2

    # TWO POPULATIONS, AND THE NARROWER ONE IS THE SUBJECT. Every step invoking the runner is a
    # candidate, but `run_suites.sh` is also invoked by its OWN self-test (D0272), which drives a
    # deliberately-failing fixture and passes no `res://tests/` suite at all. Labelling that step with a
    # suite count would be meaningless, so the subject is the steps that actually pass suites.
    #
    # The empty-population guard moves up a level rather than being dropped: if NO step passes suites,
    # that is the parallel step having been deleted or emptied, and it fails here. Skipping the check
    # because the population came back empty is the exact shape this repository keeps finding.
    candidates = [s for s in (jobs[JOB].get("steps") or []) if RUNNER in (s.get("run") or "")]
    steps = [s for s in candidates if SUITE_RE.search(s["run"])]
    if not steps:
        print(f"check_ci_suite_count: FAIL -- no step in '{JOB}' passes a res://tests/*.gd suite to "
              f"{RUNNER} ({len(candidates)} step(s) invoke it at all). There is nothing for the label "
              "to be about, and a silent pass here would mean the parallel suite step had been "
              "deleted or emptied.", file=sys.stderr)
        return 2

    failures = 0
    for step in steps:
        name = step.get("name") or "(unnamed step)"
        actual = len(SUITE_RE.findall(step["run"]))
        match = LABEL_RE.search(name)
        if match is None:
            print(f"check_ci_suite_count: FAIL -- the step running {RUNNER} is named {name!r}, which "
                  f"carries no 'all N suites' count. It runs {actual}. The count is checkable and so "
                  "it is required: without it this gate has no subject and passes on anything.",
                  file=sys.stderr)
            failures += 1
            continue
        claimed = int(match.group(1))
        if claimed != actual:
            print(f"check_ci_suite_count: FAIL -- the step name claims {claimed} suites and the step "
                  f"passes {actual} to {RUNNER}.\n"
                  f"    step: {name}\n"
                  f"    fix the name to read 'all {actual} suites'.", file=sys.stderr)
            failures += 1
        else:
            print(f"check_ci_suite_count: {name!r} -> {actual} suite(s) passed to {RUNNER}, label agrees")

    if failures:
        return 1
    print(f"check_ci_suite_count: PASS -- {len(steps)} parallel suite step(s), every label matching its "
          "own argument list")
    return 0


if __name__ == "__main__":
    sys.exit(main())
