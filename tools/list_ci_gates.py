#!/usr/bin/env python3
"""Print the shell command of every step in the workflow's structural-gate job, NUL-separated.

    python3 tools/list_ci_gates.py .github/workflows/harness.yml

WHY THIS EXISTS (`docs/DECISIONS_LEDGER.md` D0295). `tools/run_local_battery.sh` runs exactly the SUITES
CI runs, parsed from the workflow so the two populations cannot drift. It did not run the GATES, and
every session that wanted them wrote `for g in tools/layer_lint/*.py` by hand — which is a different
population from the gate job's step list, and quietly a smaller one: it misses
`tools/quality_check/duplication.py`, `tools/check_base_namespace.sh`, the schema validator and the data
codegen check. A commit passed that loop, was pushed, and CI's duplication gate failed on it. That is a
full round trip spent finding out that two lists disagreed.

Same principle as `list_ci_suites.py`, which this is modelled on: **one source, read twice.** The job
structure carries the answer, so this parses the YAML rather than pattern-matching the file as text.

NUL-separated rather than newline-separated because a `run:` block may itself be a multi-line script,
and splitting those on newlines would hand the caller half a shell script as a whole command. One of the
gate steps is exactly that today.

It prints commands, not tool paths, because a gate step is a command line: some take arguments
(`--check`), some are `sh` not `python3`, and reconstructing that from a filename is how the two lists
came apart in the first place. Steps with no `run:` (checkout, setup-python, pip install) are skipped —
they are the runner's own setup, not gates, and `pip install pyyaml` in particular must not run here.
"""

import sys

import yaml

JOB = "gates"

# Steps whose command is environment setup for the runner rather than a gate. Matched on the whole
# command, not on a substring: a gate that happened to contain one of these words must still run.
SETUP_COMMANDS = {"pip install pyyaml"}


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <workflow.yml>", file=sys.stderr)
        return 2
    with open(sys.argv[1], encoding="utf-8") as handle:
        doc = yaml.safe_load(handle)

    if not isinstance(doc, dict) or "jobs" not in doc:
        print(f"list_ci_gates: {sys.argv[1]} is not a workflow mapping with a 'jobs' key",
              file=sys.stderr)
        return 2
    job = doc["jobs"].get(JOB)
    if job is None:
        print(f"list_ci_gates: no '{JOB}' job in {sys.argv[1]} -- if the job was renamed, "
              f"this file's JOB constant is what has to follow it", file=sys.stderr)
        return 2

    commands = []
    for step in job.get("steps") or []:
        run = (step or {}).get("run")
        if not run:
            continue
        command = run.strip()
        if command in SETUP_COMMANDS:
            continue
        commands.append(command)

    if not commands:
        # A gate job that parses to zero steps is indistinguishable from a green run, which is the whole
        # "green by absence" shape `check_ci_not_shrunk.py` exists for. Say so loudly instead.
        print(f"list_ci_gates: the '{JOB}' job parsed to ZERO runnable steps", file=sys.stderr)
        return 2
    sys.stdout.write("\0".join(commands))
    return 0


if __name__ == "__main__":
    sys.exit(main())
