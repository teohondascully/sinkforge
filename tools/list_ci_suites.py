#!/usr/bin/env python3
"""Prints the `res://...gd` suites CI's `tests` job runs, one per line, in the job's own order.

    python3 tools/list_ci_suites.py .github/workflows/harness.yml

Split out of `run_local_battery.sh` (D0230) rather than embedded as a heredoc: a Python heredoc nested
inside a shell heredoc is a real hazard here, since both conventionally end on the same `PY` marker and
the outer one swallows the inner. That is not a hypothetical -- it happened writing this pair.

The job name is not a parameter on purpose. `tests` is the per-commit job; `fuzz_nightly` is
schedule-only and sweeps 1.5M ticks, and making the caller name a job is exactly how someone eventually
passes the wrong one. Exits 2 with a message if that job is missing, rather than printing nothing, since
an empty list is what this whole tool exists to make impossible to mistake for success.
"""
import re
import sys

import yaml

SUITE_RE = re.compile(r"res://[\w./-]+\.gd")
JOB = "tests"


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <workflow.yml>", file=sys.stderr)
        return 2
    with open(sys.argv[1], encoding="utf-8") as handle:
        workflow = yaml.safe_load(handle)
    # `safe_load` returns None for an empty file, and `None.get` is a traceback rather than a verdict.
    # An unreadable workflow has to say so, because the caller's next move on an empty list is to abort.
    if not isinstance(workflow, dict):
        print(f"list_ci_suites: {sys.argv[1]} is not a workflow mapping "
              f"(parsed as {type(workflow).__name__})", file=sys.stderr)
        return 2
    jobs = workflow.get("jobs", {})
    if JOB not in jobs:
        print(f"list_ci_suites: no '{JOB}' job in {sys.argv[1]} "
              f"(found: {sorted(jobs)})", file=sys.stderr)
        return 2
    for step in jobs[JOB].get("steps", []):
        for found in SUITE_RE.findall(step.get("run", "") or ""):
            print(found)
    return 0


if __name__ == "__main__":
    sys.exit(main())
