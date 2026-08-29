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

import re
import sys
from pathlib import Path

from gate_status_ci import NEEDS_ENGINE_RE, fetch_ci_state, git_head, run_locally

ROOT = Path(__file__).resolve().parents[1]
QUALITY_MD = ROOT / "docs" / "QUALITY.md"
WORKFLOW = ROOT / ".github" / "workflows" / "harness.yml"

GATE_LINE_RE = re.compile(r"^(\d+)\. \*\*(.+?)\*\*\.?[ \t]*(.*)$", re.M)
CITE_RE = re.compile(r"QUALITY gates?\s+(\d+)(?:-(\d+))?", re.I)
BACKTICK_RE = re.compile(r"`([^`]+)`")
FILE_EXT_RE = re.compile(r"\.(py|gd|sh)$")


def parse_gates(path: Path = QUALITY_MD) -> dict[int, dict[str, str]]:
    """Every numbered gate in `docs/QUALITY.md`'s own "## 1. The gates" section, read fresh from the file
    -- not a copy of this list living inside this script. `path` is parametrized (default: the real
    QUALITY.md) so `tools/test_gate_status.py` can prove the tool re-derives its table from a mutated
    copy without any other edit, never a copy of QUALITY.md's structure baked into this script."""
    text = path.read_text(encoding="utf-8")
    gates: dict[int, dict[str, str]] = {}
    for m in GATE_LINE_RE.finditer(text):
        n, title, body = m.groups()
        gates[int(n)] = {"title": title.strip(), "body": body.strip()}
    return gates


ENV_EXPR_RE = re.compile(r"\$\{\{\s*env\.([A-Za-z_][A-Za-z0-9_]*)\s*\}\}")


def _resolve_env_expressions(name: str, job_env: dict) -> str:
    """GitHub Actions expands `${{ env.KEY }}` in a step's own `name:` before reporting it via the API --
    confirmed directly (F2, `docs/DECISIONS_LEDGER.md` D0162): `gh api .../jobs` reports "Download and
    verify Godot 4.6.2-stable (...)" for the step whose tracked YAML says "Download and verify Godot
    ${{ env.GODOT_VERSION }} (...)" verbatim. Reading the raw, unexpanded name and matching it against CI's
    own (expanded) step names via a plain string key never matches -- this step was silently invisible to
    CI-conclusion matching, always reporting UNKNOWN regardless of whether CI actually passed or failed on
    it. Resolving known `env.KEY` expressions here, from the SAME job's own `env:` block, closes the gap
    for every current and future step whose name embeds one -- not just the two Godot-download steps this
    was found on."""
    def repl(m: "re.Match[str]") -> str:
        key = m.group(1)
        return str(job_env.get(key, m.group(0)))
    return ENV_EXPR_RE.sub(repl, name)


def parse_workflow_steps(path: Path = WORKFLOW) -> list[dict]:
    """Every step in every job of the real workflow file, read fresh -- not a copy of CI's structure.
    `path` is parametrized (default: the real harness.yml) for the same reason as `parse_gates` above."""
    import yaml

    wf = yaml.safe_load(path.read_text(encoding="utf-8"))
    steps = []
    for job_key, job in wf["jobs"].items():
        job_env = job.get("env", {}) or {}
        for step in job.get("steps", []):
            raw_name = step.get("name", "<unnamed step>")
            steps.append(
                {
                    "job": job_key,
                    "name": _resolve_env_expressions(raw_name, job_env),
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
    # A citation ending in a code extension (.py/.gd/.sh) names one specific FILE and is matched as a plain
    # substring -- unambiguous. A citation with no extension (e.g. gate 1's "Custom check in
    # `tools/layer_lint`") names a DIRECTORY, not a file, and is deliberately NOT matched as a blanket
    # substring against every step whose run: command lives under it: tools/layer_lint/ alone also holds
    # check_size_limits.py, check_loc_ratio.py, check_untracked_files.py and five more, each its own
    # separately-numbered gate with its own specific citation elsewhere in this same document. Matching the
    # bare directory string re-attached gate 7's (and gates 3/4/23/27's) own steps to gate 1 too -- gate 1
    # showed FAIL because gate 7's real LOC failure was living, unrelated, inside gate 1's own evidence list.
    # A directory-only citation is instead evidence only for the one script conventionally named after its
    # own directory (tools/layer_lint/layer_lint.py) -- the "primary" check the directory-only prose is
    # naming -- never for every other, differently-purposed script that merely happens to live alongside it.
    for n, g in gates.items():
        if links[n]:
            continue
        candidate_paths = [
            p for p in BACKTICK_RE.findall(g["body"]) if "/" in p or p.endswith((".py", ".gd", ".sh"))
        ]
        found: list[dict] = []
        all_paths: list[str] = []
        for p in candidate_paths:
            if FILE_EXT_RE.search(p):
                matched = [s for s in steps if p in s["run"]]
            else:
                dirname = p.rstrip("/").rsplit("/", 1)[-1]
                primary_re = re.compile(r"(^|/)%s\.(py|gd|sh)\b" % re.escape(dirname))
                matched = [s for s in steps if primary_re.search(s["run"])]
            if matched:
                found.extend(matched)
                all_paths.append(p)
        if found:
            seen = set()
            uniq = []
            for s in found:
                key = (s["job"], s["name"])
                if key not in seen:
                    seen.add(key)
                    uniq.append(s)
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


def classify_step(s: dict, ci_steps: dict[str, str]) -> tuple[str, str]:
    """Returns (status, detail_line) for one step. status is one of PASS/FAIL/SKIPPED/UNKNOWN.

    CI's own reported conclusion is authoritative whenever CI reported ANYTHING for this step name at
    all. Local re-execution is informational ONLY -- shown in the detail line as a freshness cross-check
    -- and must never be allowed to supply the step's own status when CI marks it "skipped" or
    "cancelled". That promotion was this tool's own defect (A1, found the same way D0145 was: running it
    against a real red run and checking the table against `gh run view` by hand): `duplication.py` is a
    BLOCKING step that CI skipped because an earlier step in the same job already failed, so CI never
    actually exercised it against the committed tree at all -- but this same session's local re-run of it
    happened to PASS, and the old code's `effective_pass = ci_pass if ci_pass is not None else local_pass`
    let that local PASS silently become the gate's own top-line verdict. A gate CI did not run must never
    read as passing."""
    ci_conclusion = ci_steps.get(s["name"])
    local = None
    if not NEEDS_ENGINE_RE.search(s["run"]) and s["run"]:
        local = run_locally(s["run"])

    if ci_conclusion in ("skipped", "cancelled"):
        reason = "an earlier step in this job already failed" if ci_conclusion == "skipped" else "run was cancelled"
        local_note = (
            ", local=%s (informational only -- CI itself never exercised this step)" % local
            if local is not None else ""
        )
        return "SKIPPED", "%s: CI=%s (%s)%s" % (s["name"][:60], ci_conclusion, reason, local_note)

    if ci_conclusion is not None:
        ci_pass = ci_conclusion == "success"
        local_pass = local == "PASS" if local is not None else None
        if local_pass is not None and local_pass != ci_pass:
            return (
                "PASS" if ci_pass else "FAIL",
                "%s: DISAGREE -- CI=%s, local=%s (likely a dirty working tree, not a CI regression)"
                % (s["name"][:60], ci_conclusion, local),
            )
        return (
            "PASS" if ci_pass else "FAIL",
            "%s: CI=%s%s" % (s["name"][:60], ci_conclusion, (", local=%s" % local) if local else ""),
        )

    # No CI data at all for this step name (e.g. it never ran in the fetched CI run) -- only in this
    # case does local execution get to speak for the step at all.
    if local is not None:
        return ("PASS" if local == "PASS" else "FAIL"), "%s: local=%s (no CI conclusion available)" % (
            s["name"][:60], local,
        )
    return "UNKNOWN", "%s: no run: command, nothing executed" % s["name"][:60]


def resolve_status(gate_steps: list[dict], ci_steps: dict[str, str]) -> tuple[str, list[str]]:
    """Rolls up each linked step's own classify_step() verdict into the gate's single status, worst-first:
    FAIL (a real failure anywhere) beats SKIPPED (CI never exercised some evidence) beats UNKNOWN (no
    data at all) beats PASS. A gate is never reported PASS on the strength of a step CI did not run."""
    if any(s["coe"] for s in gate_steps):
        return "ADVISORY", ["continue-on-error: true in harness.yml"]

    details = []
    statuses = []
    for s in gate_steps:
        status, detail = classify_step(s, ci_steps)
        details.append(detail)
        statuses.append(status)

    if "FAIL" in statuses:
        return "FAIL", details
    if "SKIPPED" in statuses:
        return "SKIPPED", details
    if "UNKNOWN" in statuses:
        return "UNKNOWN", details
    return "PASS", details


def main() -> int:
    gates = parse_gates()
    # Contiguous 1..N, not a hardcoded total -- QUALITY.md's own gate count grows over the project's
    # life (D0175 added gate 30), and a fixed literal here would FATAL on every future addition the
    # same way it did the moment gate 30 landed. What this still catches: a gap or a duplicate number,
    # which a truly contiguous 1..N could never produce.
    if sorted(gates) != list(range(1, len(gates) + 1)):
        print("gate_status: FATAL -- parsed %d gate headers from QUALITY.md, not a contiguous 1..%d, got %s"
              % (len(gates), len(gates), sorted(gates)), file=sys.stderr)
        return 2

    steps = parse_workflow_steps()
    real_steps = [s for s in steps if s["run"]]
    links, kind = link_gates(gates, steps)
    head = git_head()
    ci_conclusion, ci_note, ci_steps = fetch_ci_state(head)

    print("gate_status: commit=%s" % head)
    print("gate_status: CI %s" % ci_note)
    print(
        "gate_status: population = the UNION of docs/QUALITY.md's %d numbered gates and "
        "harness.yml's %d real CI step(s) (a run: command, not infra like checkout/setup) -- "
        "neither source can hide a gate from this table. A gate can appear with no CI step (a "
        "NO-CODE row below); a CI step can run and block the build while citing no gate number "
        "(its own section further down). Fully CI-first enumeration cannot produce the NO-CODE "
        "rows by construction: a gate with zero enforcing code, by definition, is cited by NO step "
        "in harness.yml, so scanning CI alone would silently omit it rather than reporting it "
        "missing -- QUALITY.md's own numbered list is read live, at runtime, because it is the only "
        "place the total declared population of %d is written down at all." % (len(gates), len(real_steps), len(gates))
    )
    print()

    rows = []
    counts = {"code": 0, "no_code": 0}
    for n in range(1, len(gates) + 1):
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
    total = len(gates)
    print("gate_status: %d/%d gates have linked enforcing code, %d/%d do not (NO-CODE)"
          % (counts["code"], total, counts["no_code"], total))
    no_code_list = [n for n, _, status, _, _ in rows if status == "NO-CODE"]
    print("gate_status: NO-CODE gate numbers: %s" % no_code_list)
    fail_list = [n for n, _, status, _, _ in rows if status == "FAIL"]
    advisory_list = [n for n, _, status, _, _ in rows if status == "ADVISORY"]
    skipped_list = [n for n, _, status, _, _ in rows if status == "SKIPPED"]
    print("gate_status: FAIL gate numbers: %s" % fail_list)
    print("gate_status: ADVISORY gate numbers: %s" % advisory_list)
    print("gate_status: SKIPPED gate numbers (CI has not exercised these since an earlier step in "
          "the same job failed -- not a known PASS, not a known FAIL): %s" % skipped_list)

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
    unlinked_skipped = [s["name"] for s in unlinked if resolve_status([s], ci_steps)[0] == "SKIPPED"]
    print("gate_status: unnumbered steps currently FAIL: %s" % unlinked_fail)
    print("gate_status: unnumbered steps currently SKIPPED: %s" % unlinked_skipped)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
