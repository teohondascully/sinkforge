#!/usr/bin/env python3
"""tools/gate_status.py's own CI/git interaction, extracted (D0161, queue E6) -- `git_head`/`fetch_ci_state`
(talk to `git`/`gh`) and `run_locally` (execute a step's own `run:` command) share nothing with
`gate_status.py`'s parsing/linking logic except being called from the same `main()`; this is a real Extract
Module, not a line-count dodge -- gate_status.py had grown to 431 lines (over `docs/QUALITY.md` gate 3's own
400-line limit, a limit `tools/layer_lint/check_size_limits.py` does not currently enforce for `.py` files at
all, GDScript-only -- a separate finding, `docs/DECISIONS_LEDGER.md` D0161).
"""
from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NEEDS_ENGINE_RE = re.compile(r"\bgodot\b", re.I)


def git_head() -> str:
    return subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True, check=True
    ).stdout.strip()


def fetch_ci_state(head_sha: str) -> tuple[str | None, str, dict[str, str]]:
    """Returns (overall_conclusion_or_None, human_note, {step_name: conclusion}) for the latest completed
    CI run at `head_sha`, via `gh` -- never a hand-typed record of what CI last did."""
    try:
        listing = subprocess.run(
            [
                "gh", "run", "list", "--branch", "main", "--limit", "20", "--json",
                "databaseId,headSha,conclusion,status,workflowName,createdAt",
            ],
            cwd=ROOT, capture_output=True, text=True, timeout=30,
        )
        if listing.returncode != 0:
            return None, "gh run list failed: %s" % listing.stderr.strip()[:200], {}
        runs = json.loads(listing.stdout)
    except Exception as e:  # noqa: BLE001 -- report, never crash the whole table over one network call
        return None, "gh run list errored: %r" % e, {}

    matches = [r for r in runs if r["headSha"] == head_sha and r["status"] == "completed"]
    if not matches:
        return None, "no completed CI run found for HEAD %s" % head_sha[:12], {}
    matches.sort(key=lambda r: r["createdAt"], reverse=True)
    run = matches[0]

    step_conclusions: dict[str, str] = {}
    try:
        jobs_raw = subprocess.run(
            ["gh", "api", "repos/{owner}/{repo}/actions/runs/%d/jobs" % run["databaseId"]],
            cwd=ROOT, capture_output=True, text=True, timeout=30,
        )
        if jobs_raw.returncode == 0:
            for job in json.loads(jobs_raw.stdout).get("jobs", []):
                for step in job.get("steps", []):
                    step_conclusions[step["name"]] = step.get("conclusion") or step.get("status") or "unknown"
    except Exception as e:  # noqa: BLE001
        return run["conclusion"], "run found but per-step fetch errored: %r" % e, {}

    note = "run %d, conclusion=%s, sha=%s" % (run["databaseId"], run["conclusion"], head_sha[:12])
    return run["conclusion"], note, step_conclusions


def run_locally(cmd: str) -> str:
    """Actually executes a step's own `run:` command right now. Returns PASS/FAIL/SKIPPED(reason)."""
    try:
        proc = subprocess.run(
            ["bash", "-c", cmd], cwd=ROOT, capture_output=True, text=True, timeout=120
        )
        return "PASS" if proc.returncode == 0 else "FAIL (exit %d)" % proc.returncode
    except Exception as e:  # noqa: BLE001
        return "SKIPPED (local exec errored: %r)" % e
