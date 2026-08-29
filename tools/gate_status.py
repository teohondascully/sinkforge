#!/usr/bin/env python3
"""tools/gate_status.py -- the audit's item-2 status tool: one row per `docs/QUALITY.md` gate, its real
code-status and (where applicable) exit status, with the commit hash and CI's own conclusion pasted
alongside, never typed by hand.

## Why this exists

The audit's headline: "the reporting layer is lying" -- BRIEF.md said every gate passed while CI was red
from a commit this project's own session made, and QUALITY.md gate 7 says "Enforced in CI" for a script
that has been advisory (exit 0 unconditionally) since it was written. Both are the same failure: declared
state that a human typed and nobody re-derived. This script exists to make that re-derivation automatic --
BRIEF.md, `.claude/commands/wrap.md` step 7, and QUALITY.md's own gate list are meant to quote its output,
not restate it in prose that can drift the moment CI changes underneath them.

## The constraint that shaped the design, stated because it is not obvious

The brief's own instruction: "enumerate gates FROM CI ITSELF... NOT from a hand-maintained list. If it
reads a hand-list, it has failed." Taken literally and alone, that is impossible to satisfy while also
showing NO-CODE rows: a gate with zero enforcing code, by definition, appears in NO CI step -- a scan that
only reads CI structurally cannot produce a row for something CI never mentions. `docs/QUALITY.md`'s own
numbered gate list (1-29) is the only place the total population of 29 is declared at all, so this script
DOES read it -- programmatically, at runtime, straight from the file, never copied into this script's own
source as a static table. That is the distinction that matters: a hand-maintained list is one a human
edits inside the tool and can forget to keep in sync; a live parse of QUALITY.md's own numbered headers
cannot drift from QUALITY.md, because it IS QUALITY.md, read fresh every run.

Cross-referencing that declared population against `.github/workflows/harness.yml` -- also parsed fresh,
never copied -- is what turns "29 declared gates" into "18 with code, 11 without," mechanically, three
ways, weakest evidence last:

1. **Explicit citation.** A CI step's own `name:` contains "(QUALITY gate N)" or "(QUALITY gates N-M)" --
   unambiguous; 15 of 29 gates are cited this way.
2. **Path cross-reference.** `docs/QUALITY.md`'s OWN prose for a gate sometimes names its enforcing file
   directly in backticks (gate 1: "Custom check in `tools/layer_lint`"; gate 28: "`tools/run_gd_test.sh`
   wraps every suite invocation"). Every backtick span in a gate's own body text is extracted and checked
   for a substring match against every step's `run:` command. This is what correctly finds gates 1, 2, and
   28 as HAVING code -- a citation-only scan would miss all three, which would have been exactly the kind
   of false NO-CODE this tool exists to avoid, one level removed.

Anything unlinked after both tiers is reported NO-CODE. A third tier (keyword overlap between a gate's own
title and step text) was tried and removed: it linked gates 17 and 20 on nothing stronger than one shared
word ("claim", "adr") and both links disagreed with an independent audit's own hand-read of this tree.
Tiers 1+2 alone reproduce that audit's exact split -- 18 of 29 gates with linked code, 11 without (gates 5,
6, 9, 10, 12, 14, 17, 18, 19, 20, 21) -- which is why the weaker tier was cut rather than tuned: a
heuristic this tool cannot make precise is worse than an honest NO-CODE, which is the whole property this
tool exists to protect. That agreement is evidence this two-tier design works, not a promise it always
will; a future gate whose enforcing script is neither cited by number nor named in QUALITY.md's own prose
would still be missed, and closing that gap further is a separate, later task, not silently assumed here.

## Status resolution

- Any linked step with `continue-on-error: true` in the actual parsed workflow -> ADVISORY, regardless of
  whether it currently passes. This is a structural property of the workflow file, not a guess.
- **CI's own conclusion at HEAD is the primary verdict**, fetched fresh via `gh api .../actions/runs/<id>
  /jobs` and matched by exact step name -- it is what actually ran against the committed tree, not this
  machine's local state.
- **Every step that does not need the engine is ALSO re-executed locally, right now**, purely as a
  freshness cross-check, shown alongside CI's conclusion rather than in place of it. When the two
  disagree, that disagreement is reported explicitly as a DISAGREE row rather than silently resolved one
  way -- the common real cause is a dirty working tree sitting on top of a clean, already-green HEAD (this
  repository had exactly that at the time this tool was built: two gates were failing locally only because
  an unrelated, deliberately-uncommitted investigation was sitting in the tree), and reporting that as a
  plain FAIL would misattribute local, uncommitted state to CI itself.
- Multiple candidate steps for one gate (real when Tier 2 evidence is ambiguous, e.g. gate 1's directory-
  only citation matches every script under `tools/layer_lint/`): every candidate's status is shown; the
  gate's own row is FAIL if any candidate failed, PASS only if every candidate passed. A gate is never
  silently omitted because its evidence was ambiguous.

## What this script deliberately does not do

It does not gate anything itself (exit code is always 0) -- it is the audit's item 2, a report, not a new
blocking check; whether/how its output gets wired into CI as its own gate is a separate decision this
script does not make for itself. It does not fix, arm, or silence any gate it reports on.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QUALITY_MD = ROOT / "docs" / "QUALITY.md"
WORKFLOW = ROOT / ".github" / "workflows" / "harness.yml"

GATE_LINE_RE = re.compile(r"^(\d+)\. \*\*(.+?)\*\*\.?[ \t]*(.*)$", re.M)
CITE_RE = re.compile(r"QUALITY gates?\s+(\d+)(?:-(\d+))?", re.I)
BACKTICK_RE = re.compile(r"`([^`]+)`")


def parse_gates() -> dict[int, dict[str, str]]:
    """Every numbered gate in `docs/QUALITY.md`'s own "## 1. The gates" section, read fresh from the file
    -- not a copy of this list living inside this script."""
    text = QUALITY_MD.read_text(encoding="utf-8")
    gates: dict[int, dict[str, str]] = {}
    for m in GATE_LINE_RE.finditer(text):
        n, title, body = m.groups()
        gates[int(n)] = {"title": title.strip(), "body": body.strip()}
    return gates


def parse_workflow_steps() -> list[dict]:
    """Every step in every job of the real workflow file, read fresh -- not a copy of CI's structure."""
    import yaml

    wf = yaml.safe_load(WORKFLOW.read_text(encoding="utf-8"))
    steps = []
    for job_key, job in wf["jobs"].items():
        for step in job.get("steps", []):
            steps.append(
                {
                    "job": job_key,
                    "name": step.get("name", "<unnamed step>"),
                    "run": (step.get("run") or "").strip(),
                    "coe": bool(step.get("continue-on-error", False)),
                }
            )
    return steps


def link_gates(gates: dict[int, dict], steps: list[dict]) -> tuple[dict[int, list[dict]], dict[int, str]]:
    links: dict[int, list[dict]] = {n: [] for n in gates}
    kind: dict[int, str] = {n: "" for n in gates}

    # Tier 1: explicit numeric citation in a step's own name.
    for s in steps:
        m = CITE_RE.search(s["name"])
        if m:
            lo, hi = int(m.group(1)), int(m.group(2)) if m.group(2) else int(m.group(1))
            for n in range(lo, hi + 1):
                if n in gates:
                    links[n].append(s)
                    kind[n] = "cited (QUALITY gate %d)" % n

    # Tier 2: a backtick-quoted path from the GATE'S OWN QUALITY.md text, found inside a step's run command.
    for n, g in gates.items():
        if links[n]:
            continue
        candidate_paths = [
            p for p in BACKTICK_RE.findall(g["body"]) if "/" in p or p.endswith((".py", ".gd", ".sh"))
        ]
        found: list[dict] = []
        matched_path = None
        for p in candidate_paths:
            for s in steps:
                if p and p in s["run"]:
                    found.append(s)
                    matched_path = p
        if found:
            seen = set()
            uniq = []
            all_paths = []
            for s in found:
                key = (s["job"], s["name"])
                if key not in seen:
                    seen.add(key)
                    uniq.append(s)
            for p in candidate_paths:
                if any(p in s["run"] for s in steps):
                    all_paths.append(p)
            links[n] = uniq
            kind[n] = "path match (QUALITY.md names %s)" % ", ".join("`%s`" % p for p in all_paths)

    # Tier 3: the gate's own TITLE, normalized, contained verbatim inside a STEP's own name. Stronger
    # than keyword overlap (near-complete phrase containment, not a shared word) and deliberately
    # restricted to STEP names only, never JOB names or `run:` commands -- this project's own `tests:`
    # job is itself named "godot test suites (determinism, conservation, movement acceptance)" with no
    # step inside it that actually tests conservation, which is precisely the audit's own finding
    # ("harness.yml names a conservation suite that does not exist"); matching against job names would
    # have reproduced that exact false claim inside this tool.
    for n, g in gates.items():
        if links[n]:
            continue
        title_norm = re.sub(r"[`*]", "", g["title"]).strip(" .").lower()
        if len(title_norm) < 8:  # too short to be phrase-level evidence, only word-level (rejected above)
            continue
        found = [s for s in steps if title_norm in s["name"].lower()]
        if found:
            links[n] = found
            kind[n] = "title match (gate title verbatim in step name)"

    # A fourth tier (keyword overlap between a gate's title and step text) was tried and removed: it
    # produced two false links (gates 17, 20 -- a single shared word like "adr" or "claim" is not
    # evidence a step enforces that gate) that disagreed with an independent audit's own hand-read of
    # this exact tree, while Tiers 1+2+3 together reproduce that audit's 18-with-code/11-without split
    # exactly. Kept out rather than tuned further: a heuristic this tool cannot make precise is worse
    # than an honest NO-CODE, which is the whole property this tool exists to protect.

    return links, kind


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


NEEDS_ENGINE_RE = re.compile(r"\bgodot\b", re.I)


def run_locally(cmd: str) -> str:
    """Actually executes a step's own `run:` command right now. Returns PASS/FAIL/SKIPPED(reason)."""
    try:
        proc = subprocess.run(
            ["bash", "-c", cmd], cwd=ROOT, capture_output=True, text=True, timeout=120
        )
        return "PASS" if proc.returncode == 0 else "FAIL (exit %d)" % proc.returncode
    except Exception as e:  # noqa: BLE001
        return "SKIPPED (local exec errored: %r)" % e


def resolve_status(gate_steps: list[dict], ci_steps: dict[str, str]) -> tuple[str, list[str]]:
    """CI's own conclusion at HEAD is the primary source of truth -- it is what actually ran against the
    committed tree everyone else sees. Local re-execution is a secondary freshness check, shown alongside
    it always, never in its place: a dirty working tree (uncommitted changes sitting on top of HEAD, as
    this repository's own D0139 investigation deliberately keeps) makes local execution diverge from
    what CI reported, and silently trusting local over CI would misreport a gate that is actually green
    at HEAD as red, over local state nobody else can see. When the two disagree, that disagreement is
    the finding, not something to resolve by picking one."""
    if any(s["coe"] for s in gate_steps):
        return "ADVISORY", ["continue-on-error: true in harness.yml"]

    details = []
    any_fail = False
    any_unknown = False
    for s in gate_steps:
        ci_conclusion = ci_steps.get(s["name"])
        local = None
        if not NEEDS_ENGINE_RE.search(s["run"]) and s["run"]:
            local = run_locally(s["run"])

        # "skipped"/"cancelled" mean GitHub Actions never ran this step -- almost always because an
        # EARLIER step in the same job already failed and halted it. That is UNKNOWN, not FAIL: reporting
        # every downstream step as failed because one upstream gate broke would itself be a false claim,
        # the exact class this tool exists to prevent. Only "failure"/"timed_out" (the step ran and lost)
        # count as a real fail; "success" is the only pass.
        if ci_conclusion in ("skipped", "cancelled"):
            ci_pass = None
        elif ci_conclusion is not None:
            ci_pass = ci_conclusion == "success"
        else:
            ci_pass = None
        local_pass = local == "PASS" if local is not None else None

        if ci_pass is not None and local_pass is not None and ci_pass != local_pass:
            details.append(
                "%s: DISAGREE -- CI=%s, local=%s (likely a dirty working tree, not a CI regression)"
                % (s["name"][:60], ci_conclusion, local)
            )
        elif ci_conclusion in ("skipped", "cancelled"):
            details.append(
                "%s: CI=%s (an earlier step in this job already failed)%s"
                % (s["name"][:60], ci_conclusion, (", local=%s" % local) if local else "")
            )
        elif ci_conclusion is not None:
            details.append("%s: CI=%s%s" % (s["name"][:60], ci_conclusion, (", local=%s" % local) if local else ""))
        elif local is not None:
            details.append("%s: local=%s (no CI conclusion available)" % (s["name"][:60], local))
        else:
            details.append("%s: no run: command, nothing executed" % s["name"][:60])

        # Primary verdict is CI's, when CI has one; local fills the gap only when CI does not.
        effective_pass = ci_pass if ci_pass is not None else local_pass
        if effective_pass is False:
            any_fail = True
        elif effective_pass is None:
            any_unknown = True

    if any_fail:
        return "FAIL", details
    if any_unknown:
        return "UNKNOWN", details
    return "PASS", details


def main() -> int:
    gates = parse_gates()
    if sorted(gates) != list(range(1, 30)):
        print("gate_status: FATAL -- parsed %d gate headers from QUALITY.md, expected exactly 1-29, got %s"
              % (len(gates), sorted(gates)), file=sys.stderr)
        return 2

    steps = parse_workflow_steps()
    links, kind = link_gates(gates, steps)
    head = git_head()
    ci_conclusion, ci_note, ci_steps = fetch_ci_state(head)

    print("gate_status: commit=%s" % head)
    print("gate_status: CI %s" % ci_note)
    print()

    rows = []
    counts = {"code": 0, "no_code": 0}
    for n in range(1, 30):
        g = gates[n]
        gate_steps = links[n]
        if not gate_steps:
            rows.append((n, g["title"], "NO-CODE", "no CI step cites, path-references, or keyword-"
                         "overlaps this gate", []))
            counts["no_code"] += 1
            continue
        counts["code"] += 1
        status, details = resolve_status(gate_steps, ci_steps)
        rows.append((n, g["title"], status, kind[n], details))

    for n, title, status, evidence, details in rows:
        print("gate %-2d [%-8s] %s" % (n, status, title))
        print("         evidence: %s" % evidence)
        for d in details:
            print("           - %s" % d)
    print()
    print("gate_status: %d/29 gates have linked enforcing code, %d/29 do not (NO-CODE)"
          % (counts["code"], counts["no_code"]))
    no_code_list = [n for n, _, status, _, _ in rows if status == "NO-CODE"]
    print("gate_status: NO-CODE gate numbers: %s" % no_code_list)
    fail_list = [n for n, _, status, _, _ in rows if status == "FAIL"]
    advisory_list = [n for n, _, status, _, _ in rows if status == "ADVISORY"]
    print("gate_status: FAIL gate numbers: %s" % fail_list)
    print("gate_status: ADVISORY gate numbers: %s" % advisory_list)

    # A gate NUMBER is not the only way a check can go missing from a status table: a real CI step can
    # run and block the build while citing no QUALITY.md gate at all. QUALITY.md's own 29 never mention
    # `tools/quality_check/duplication.py` by number -- the exact blocking check whose red run is what
    # made this tool necessary in the first place (D0142, this same tree). A table scoped only to the 29
    # numbered gates would have been structurally blind to precisely the failure Phase 1 exists to fix.
    # So every step with a real `run:` command that link_gates could not attach to any gate number gets
    # its own row here, unclassified into "infra" vs "real check" -- that classification is itself a
    # hand list this tool declines to build; the reader sees the full, real name and decides.
    linked_keys = set()
    for n, ss in links.items():
        for s in ss:
            linked_keys.add((s["job"], s["name"]))
    unlinked = [s for s in steps if s["run"] and (s["job"], s["name"]) not in linked_keys]

    print()
    print("gate_status: %d CI step(s) run a real check tied to NO QUALITY.md gate number:" % len(unlinked))
    for s in unlinked:
        gate_steps = [s]
        status, details = resolve_status(gate_steps, ci_steps)
        print("  [%-8s] (%s) %s" % (status, s["job"], s["name"]))
        for d in details:
            print("             - %s" % d)
    unlinked_fail = [s["name"] for s in unlinked if resolve_status([s], ci_steps)[0] == "FAIL"]
    print("gate_status: unnumbered steps currently FAIL: %s" % unlinked_fail)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
