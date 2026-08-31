#!/usr/bin/env python3
"""The CI check set may not SHRINK without saying so. `docs/QUALITY.md` gate 30, `docs/DECISIONS_LEDGER.md` D0266.

**Why this gate exists, precisely.** A line-range edit to `.github/workflows/harness.yml` deleted the
`headed_boot` and `fuzz_nightly` jobs (D0265). CI then reported **all green** and the pull request
reported `MERGEABLE / CLEAN` -- because a deleted check does not fail and does not pend, it simply stops
existing, and a rollup of three passing checks is indistinguishable from a rollup of five passing checks
unless something knows how many there should be. It was caught by a human noticing that a job name had
stopped appearing in a list. One step further and `main` would have silently stopped running a gate.

That is the most dangerous failure this project has: **green by absence**. Every other gate here answers
"is this property true"; a deleted gate answers nothing at all, in the same voice.

**What this checks.** The job set and the suite set of every workflow under `.github/workflows/`, in the
working tree, against the same file at the merge base. Removing a job or a suite is a FAIL. Adding is
fine. Renaming shows up as one removal and one addition and FAILS -- deliberately, because a rename is
indistinguishable from a deletion-plus-unrelated-addition to anything but a human, and the cost of the
check being wrong in that direction is one line of intent marker.

**The intent marker.** A removal is legitimate sometimes. To take one, put a line in the commit message:

    CI-Check-Removed: <job-or-suite-name> -- <why>

one per removed name. The marker is deliberately in the COMMIT MESSAGE and not in a file: a file-based
allowlist would be edited by the same careless range-replace that deletes the job, and would then agree
with the deletion. A commit message cannot be edited by a text-range bug in a YAML file.

**What this gate does NOT do.** It does not verify the jobs still WORK, that their steps are non-empty,
or that a job kept in name has kept its content -- a job gutted to `run: true` passes here. It compares
NAMES. `check_suite_coverage` covers a neighbouring property (every suite is named somewhere) and did not
catch D0265, because all 43 suites were still named -- one of them inside the job that had just been
deleted. Two gates over two properties; neither is evidence for the other.

Exit 0 when nothing shrank or every removal is declared, 1 on a shrink, 2 when the comparison cannot be
made (no merge base, unreadable workflow) -- never a silent pass, since "I could not compare" and
"nothing was removed" must not look alike.
"""
from __future__ import annotations

import re
import subprocess
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW_DIR = ".github/workflows"
SUITE_RE = re.compile(r"res://tests/(test_[a-z0-9_]+\.gd)")
MARKER_RE = re.compile(r"^CI-Check-Removed:\s*(\S+)", re.M)


def _git(*args: str) -> str:
    return subprocess.run(["git", "-C", str(ROOT), *args],
                          capture_output=True, text=True, check=True).stdout


def names_from(text: str, where: str) -> tuple[set[str], set[str]]:
    """(job names, suite names). Raises on unparseable YAML -- a workflow that does not parse runs
    nothing at all, which is the same class of hole this gate exists to close."""
    doc = yaml.safe_load(text)
    if not isinstance(doc, dict):
        raise ValueError(f"{where}: not a YAML mapping")
    jobs = doc.get("jobs") or {}
    if not isinstance(jobs, dict):
        raise ValueError(f"{where}: `jobs:` is not a mapping")
    return set(jobs), set(SUITE_RE.findall(text))


def base_ref() -> str | None:
    for cand in ("origin/main", "main"):
        try:
            merge_base = _git("merge-base", "HEAD", cand).strip()
            if merge_base:
                return merge_base
        except subprocess.CalledProcessError:
            continue
    return None


def declared_removals(base: str) -> set[str]:
    """Names declared removable in any commit message between the base and HEAD."""
    try:
        log = _git("log", "--format=%B", f"{base}..HEAD")
    except subprocess.CalledProcessError:
        return set()
    return set(MARKER_RE.findall(log))


def main() -> int:
    base = base_ref()
    if base is None:
        print("check_ci_not_shrunk: CANNOT COMPARE -- no merge base against origin/main or main found. "
              "Refusing to report a pass: this gate's whole subject is a set that got smaller, and with "
              "no baseline there is no set to compare against.")
        return 2

    wf_dir = ROOT / WORKFLOW_DIR
    files = sorted(p.relative_to(ROOT).as_posix() for p in wf_dir.glob("*.yml")) if wf_dir.is_dir() else []
    if not files:
        print(f"check_ci_not_shrunk: CANNOT COMPARE -- no workflows found under {WORKFLOW_DIR}. "
              "An empty population would make every set difference empty and this gate green forever.")
        return 2

    allowed = declared_removals(base)
    failures: list[str] = []
    total_jobs = 0
    total_suites = 0

    for rel in files:
        now_text = (ROOT / rel).read_text(encoding="utf-8")
        try:
            was_text = _git("show", f"{base}:{rel}")
        except subprocess.CalledProcessError:
            print(f"  NEW      {rel} -- did not exist at the base; nothing to shrink")
            continue
        try:
            now_jobs, now_suites = names_from(now_text, rel)
            was_jobs, was_suites = names_from(was_text, f"{base}:{rel}")
        except (yaml.YAMLError, ValueError) as exc:
            print(f"check_ci_not_shrunk: CANNOT COMPARE -- {exc}")
            return 2
        total_jobs += len(now_jobs)
        total_suites += len(now_suites)
        for kind, gone in (("job", was_jobs - now_jobs), ("suite", was_suites - now_suites)):
            for name in sorted(gone):
                if name in allowed:
                    print(f"  DECLARED {rel}: {kind} {name} removed, and the commit message says so")
                else:
                    failures.append(f"{rel}: {kind} `{name}` was removed")
        print(f"  {rel}: {len(now_jobs)} job(s), {len(now_suites)} suite(s) "
              f"(was {len(was_jobs)}, {len(was_suites)})")

    if failures:
        print(f"check_ci_not_shrunk: FAIL -- the CI check set SHRANK ({len(failures)} removal(s)):")
        for f in failures:
            print(f"    {f}")
        print("  A deleted check does not go red. It stops existing, and the run reports green over a")
        print("  smaller set -- D0265, where two deleted jobs produced a CLEAN mergeable PR.")
        print("  If a removal is intended, say so in the commit message, one line per name:")
        print("      CI-Check-Removed: <name> -- <why>")
        return 1

    print(f"check_ci_not_shrunk: PASS -- {total_jobs} job(s) and {total_suites} suite(s) across "
          f"{len(files)} workflow(s); nothing removed since {base[:8]}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
