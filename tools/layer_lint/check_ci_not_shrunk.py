#!/usr/bin/env python3
"""The CI check set may not SHRINK without saying so. `docs/QUALITY.md` gate 36 (numbered 30 until D0394), `docs/DECISIONS_LEDGER.md` D0266/D0284.

**Why this gate exists, precisely.** A line-range edit to `.github/workflows/harness.yml` deleted the
`headed_boot` and `fuzz_nightly` jobs (D0265). CI then reported **all green** and the pull request
reported `MERGEABLE / CLEAN` -- because a deleted check does not fail and does not pend, it simply stops
existing, and a rollup of three passing checks is indistinguishable from a rollup of five passing checks
unless something knows how many there should be. It was caught by a human noticing that a job name had
stopped appearing in a list. One step further and `main` would have silently stopped running a gate.

That is the most dangerous failure this project has: **green by absence**. Every other gate here answers
"is this property true"; a deleted gate answers nothing at all, in the same voice.

**Two properties, not one.** Both are compared against the same file at the merge base.

1. **NAMES.** The job set and the suite set of every workflow under `.github/workflows/`. Removing a job
   or a suite is a FAIL. Adding is fine. Renaming shows up as one removal and one addition and FAILS --
   deliberately, because a rename is indistinguishable from a deletion-plus-unrelated-addition to
   anything but a human, and the cost of the check being wrong in that direction is one line of marker.

2. **ENFORCEMENT (D0284).** The name check's own stated hole was the subtler half of the same failure:
   *a job that keeps its NAME but is gutted to `run: true` passes*. The name survives; the teeth are
   gone; the rollup still reports the job green. Same class, one level down. So each job now also
   carries a FINGERPRINT of what it actually runs, and the fingerprint may not shrink either.

**The fingerprint, and what each part is for.** Per job:

- **Work tokens** -- the set of things the job's enforcing steps *invoke*: every `res://...` or `https://...`
  URI, every word ending in `.py`/`.sh`/`.gd`/`.bash`/`.yml`/`.yaml`, every `./binary`, and every
  `uses:` action (version stripped) together with its `with:` KEY names. Losing a token FAILS.
- **Enforcing run-step count** -- how many of the job's steps still contain a line that does real work.
  A step whose `run:` holds only comments, blanks, `true`, `:`, `exit`, `set`, `echo` or `printf` is not
  one. A DROP fails; an increase does not. This exists because tokens alone cannot see every gutting:
  the `Gate mutation tests` step's real work is `find tools -name 'test_*.py'` piped into a loop, which
  contains no path-shaped token at all, and the Godot download step's work is `curl`/`unzip`/`mv`/`chmod`.
  Reduce either to `run: true` and the token sets are identical; the count is what notices.
- **Job-level gating** -- a job that GAINS a job-level `if:` it did not have has been switched off for
  the events it used to run on, with every name intact. That FAILS. (`fuzz_nightly` legitimately has
  one; it had it at the base, so it is stable.)

A step is **enforcing** only if it has no `if:` and no truthy `continue-on-error:`. That is the third
gutting vector and it is invisible to both name and text comparison: `continue-on-error: true` added to
a BLOCKING step leaves the name, the step, and the command all present and removes the enforcement
entirely. Three steps in `harness.yml` are report-only on purpose (D0096/D0098) -- they contribute no
tokens on either side, so they are stable, and flipping a blocking step to join them fires.

**What the fingerprint deliberately PASSES.** Steps reordered (it is a set, not a list). A command's
flags changed (`--check`, `-q`, `-P 8` are not tokens). A step renamed while still running the same tool
(step `name:` is not read at all). A step SPLIT into two (the count may rise). An action version bumped
(`@v5` is stripped) or a `with:` value changed (only KEY names are read). Merging two steps into one
does fail, because the count drops -- same policy as renames, and the same one-line remedy.

**The intent markers.** Both live in the COMMIT MESSAGE and neither may live in a file: a file-based
allowlist would be edited by the same careless range-replace that deletes the job, and would then agree
with the deletion. A commit message cannot be edited by a text-range bug in a YAML file.

    CI-Check-Removed: <job-or-suite-name> -- <why>      # one per removed NAME
    CI-Enforcement-Changed: <job-name> -- <why>         # one per job whose teeth changed

The second is job-granular rather than token-granular on purpose: a token-granular marker would be a
list of paths in a commit message, which is a file-based allowlist wearing a disguise, and nobody would
read it. Naming the job forces the author to say which job they meant.

**What this gate still does NOT do.** It does not verify the jobs WORK -- only that the same tools are
still named, unconditionally, in a step that does something. A step rewritten to run a DIFFERENT tool of
the same name, or a tool that has itself been gutted, is out of reach from here. `check_suite_coverage`
covers a neighbouring property (every tracked suite is named somewhere) and did not catch D0265, because
all 43 suites were still named -- one of them inside the job that had just been deleted. Separate gates
over separate properties; none is evidence for another.

Exit 0 when nothing shrank or every change is declared, 1 on a shrink, 2 when the comparison cannot be
made (no merge base, unreadable workflow, no workflows at all) -- never a silent pass, since "I could
not compare" and "nothing was removed" must not look alike.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

DEFAULT_ROOT = Path(__file__).resolve().parents[2]
WORKFLOW_DIR = ".github/workflows"
SUITE_RE = re.compile(r"res://tests/(test_[a-z0-9_]+\.gd)")
MARKER_RE = re.compile(r"^CI-Check-Removed:\s*(\S+)", re.M)
ENFORCEMENT_MARKER_RE = re.compile(r"^CI-Enforcement-Changed:\s*(\S+)", re.M)

# A URI is matched first and then blanked out, so `res://tests/test_x.gd` yields ONE token rather than
# also being re-found as a bare path -- otherwise deleting one suite would be reported as two removals.
URI_RE = re.compile(r"\b\w+://[\w./@%-]+")
PATH_RE = re.compile(r"(?<![\w./@-])[\w./@-]+\.(?:py|sh|gd|bash|yml|yaml)(?![\w./@-])")
LOCAL_EXEC_RE = re.compile(r"(?<![\w./@-])\./[\w.-]+")

# Heads of lines that cannot be the work a step exists to do. `set` and `exit` are here because a gutted
# step is usually `run: true` or `run: exit 0`; `echo`/`printf` because a step that only announces
# itself has stopped enforcing anything. A line is still read for TOKENS even if its head is on this
# list -- only the work-step COUNT ignores it.
NOOP_HEADS = {"true", ":", "exit", "set", "echo", "printf"}


@dataclass
class JobPrint:
    """One job's enforcement fingerprint. Compared base-to-now; may grow, may not shrink."""
    tokens: set[str] = field(default_factory=set)
    work_steps: int = 0
    gated: bool = False


@dataclass
class Analysis:
    job_names: set[str]
    suites: set[str]
    prints: dict[str, JobPrint]


def _git(root: Path, *args: str) -> str:
    return subprocess.run(["git", "-C", str(root), *args],
                          capture_output=True, text=True, check=True).stdout


def _code_lines(run_text: str) -> list[str]:
    """Non-blank, non-comment lines of a `run:` block. Comments are dropped before tokenising so a
    workflow COMMENT naming a tool can never satisfy this gate for a command that stopped running it --
    the same trap `check_suite_coverage` had to be mutation-tested against (D0264)."""
    out = []
    for raw in run_text.splitlines():
        line = raw.strip()
        if line and not line.startswith("#"):
            out.append(line)
    return out


def _tokens_from(lines: list[str]) -> set[str]:
    text = "\n".join(lines)
    tokens = set(URI_RE.findall(text))
    remainder = URI_RE.sub(" ", text)
    tokens.update(PATH_RE.findall(remainder))
    tokens.update(LOCAL_EXEC_RE.findall(remainder))
    return tokens


def _does_work(lines: list[str]) -> bool:
    return any(line.split(None, 1)[0] not in NOOP_HEADS for line in lines)


def _is_enforcing(step: dict) -> bool:
    """A conditional step or a `continue-on-error` step enforces nothing, whatever its name says."""
    if "if" in step:
        return False
    flag = step.get("continue-on-error", False)
    if isinstance(flag, str):
        return flag.strip().lower() in ("", "false")
    return not flag


def _fingerprint(job: object) -> JobPrint:
    if not isinstance(job, dict):
        return JobPrint()
    print_ = JobPrint(gated="if" in job)
    for step in job.get("steps") or []:
        if not isinstance(step, dict) or not _is_enforcing(step):
            continue
        uses = step.get("uses")
        if isinstance(uses, str):
            action = uses.split("@")[0].strip()
            print_.tokens.add(f"uses:{action}")
            with_block = step.get("with")
            if isinstance(with_block, dict):
                print_.tokens.update(f"uses:{action}:{key}" for key in with_block)
        run = step.get("run")
        if isinstance(run, str):
            lines = _code_lines(run)
            print_.tokens |= _tokens_from(lines)
            if _does_work(lines):
                print_.work_steps += 1
    return print_


def analyse(text: str, where: str) -> Analysis:
    """Raises on unparseable YAML -- a workflow that does not parse runs nothing at all, which is the
    same class of hole this gate exists to close."""
    doc = yaml.safe_load(text)
    if not isinstance(doc, dict):
        raise ValueError(f"{where}: not a YAML mapping")
    jobs = doc.get("jobs") or {}
    if not isinstance(jobs, dict):
        raise ValueError(f"{where}: `jobs:` is not a mapping")
    return Analysis(set(jobs), set(SUITE_RE.findall(text)),
                    {name: _fingerprint(job) for name, job in jobs.items()})


def base_ref(root: Path) -> str | None:
    for cand in ("origin/main", "main"):
        try:
            merge_base = _git(root, "merge-base", "HEAD", cand).strip()
            if merge_base:
                return merge_base
        except subprocess.CalledProcessError:
            continue
    return None


def declared(root: Path, base: str) -> tuple[set[str], set[str]]:
    """(names declared removable, jobs declared re-enforced) from commit messages base..HEAD."""
    try:
        log = _git(root, "log", "--format=%B", f"{base}..HEAD")
    except subprocess.CalledProcessError:
        return set(), set()
    return set(MARKER_RE.findall(log)), set(ENFORCEMENT_MARKER_RE.findall(log))


def compare_names(rel: str, now: Analysis, was: Analysis, allowed: set[str]) -> list[str]:
    failures = []
    for kind, gone in (("job", was.job_names - now.job_names), ("suite", was.suites - now.suites)):
        for name in sorted(gone):
            if name in allowed:
                print(f"  DECLARED {rel}: {kind} {name} removed, and the commit message says so")
            else:
                failures.append(f"{rel}: {kind} `{name}` was removed")
    return failures


def compare_enforcement(rel: str, now: Analysis, was: Analysis, allowed: set[str]) -> list[str]:
    """Only jobs present on BOTH sides -- a job that is gone entirely is `compare_names`' finding, and
    reporting it twice would bury the second property under the first."""
    failures = []
    for job in sorted(was.job_names & now.job_names):
        before, after = was.prints[job], now.prints[job]
        if job in allowed:
            print(f"  DECLARED {rel}: job {job}'s enforcement changed, and the commit message says so")
            continue
        for token in sorted(before.tokens - after.tokens):
            failures.append(f"{rel}: job `{job}` no longer runs `{token}` in an enforcing step")
        if after.work_steps < before.work_steps:
            failures.append(f"{rel}: job `{job}` has {after.work_steps} enforcing run-step(s) that do "
                            f"work, was {before.work_steps}")
        if after.gated and not before.gated:
            failures.append(f"{rel}: job `{job}` gained a job-level `if:` -- it no longer runs on the "
                            f"events it used to, with every name intact")
    return failures


def report_failures(failures: list[str]) -> int:
    print(f"check_ci_not_shrunk: FAIL -- the CI check set SHRANK ({len(failures)} removal(s)):")
    for line in failures:
        print(f"    {line}")
    print("  A deleted check does not go red. It stops existing, and the run reports green over a")
    print("  smaller set -- D0265, where two deleted jobs produced a CLEAN mergeable PR. A job GUTTED")
    print("  while keeping its name is the same failure one level down -- D0284.")
    print("  If the change is intended, say so in the commit message, one line per name:")
    print("      CI-Check-Removed: <job-or-suite-name> -- <why>")
    print("      CI-Enforcement-Changed: <job-name> -- <why>")
    return 1


def _totals(analysis: Analysis) -> tuple[int, int, int, int]:
    return (len(analysis.job_names), len(analysis.suites),
            sum(p.work_steps for p in analysis.prints.values()),
            sum(len(p.tokens) for p in analysis.prints.values()))


def compare_one(root: Path, base: str, rel: str, allowed_names: set[str],
                allowed_jobs: set[str]) -> tuple[list[str] | None, tuple[int, int, int, int]]:
    """(failures, this file's now-side totals). `None` failures means CANNOT COMPARE; the empty list
    means compared and clean, and the two must not be conflated by the caller."""
    now_text = (root / rel).read_text(encoding="utf-8")
    try:
        was_text = _git(root, "show", f"{base}:{rel}")
    except subprocess.CalledProcessError:
        print(f"  NEW      {rel} -- did not exist at the base; nothing to shrink")
        return [], (0, 0, 0, 0)
    try:
        now, was = analyse(now_text, rel), analyse(was_text, f"{base}:{rel}")
    except (yaml.YAMLError, ValueError) as exc:
        print(f"check_ci_not_shrunk: CANNOT COMPARE -- {rel} does not parse as a workflow, so "
              f"neither side of the comparison can be read: {exc}")
        return None, (0, 0, 0, 0)
    failures = compare_names(rel, now, was, allowed_names)
    failures += compare_enforcement(rel, now, was, allowed_jobs)
    jobs, suites, steps, tokens = _totals(now)
    print(f"  {rel}: {jobs} job(s), {suites} suite(s), {steps} enforcing run-step(s), "
          f"{tokens} work token(s) (was " + ", ".join(str(n) for n in _totals(was)) + ")")
    return failures, (jobs, suites, steps, tokens)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(DEFAULT_ROOT),
                        help="repository root to check (the self-test points this at a scratch repo)")
    root = Path(parser.parse_args(argv).root).resolve()

    base = base_ref(root)
    if base is None:
        print("check_ci_not_shrunk: CANNOT COMPARE -- no merge base against origin/main or main found. "
              "Refusing to report a pass: this gate's whole subject is a set that got smaller, and with "
              "no baseline there is no set to compare against.")
        return 2

    wf_dir = root / WORKFLOW_DIR
    files = sorted(p.relative_to(root).as_posix() for p in wf_dir.glob("*.yml")) if wf_dir.is_dir() else []
    if not files:
        print(f"check_ci_not_shrunk: CANNOT COMPARE -- no workflows found under {WORKFLOW_DIR}. "
              "An empty population would make every set difference empty and this gate green forever.")
        return 2

    allowed_names, allowed_jobs = declared(root, base)
    failures: list[str] = []
    jobs = suites = steps = 0
    for rel in files:
        found, totals = compare_one(root, base, rel, allowed_names, allowed_jobs)
        if found is None:
            return 2
        failures += found
        jobs, suites, steps = jobs + totals[0], suites + totals[1], steps + totals[2]

    if failures:
        return report_failures(failures)
    print(f"check_ci_not_shrunk: PASS -- {jobs} job(s), {suites} suite(s) and {steps} "
          f"enforcing run-step(s) across {len(files)} workflow(s); nothing removed since {base[:8]}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
