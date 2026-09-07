#!/usr/bin/env python3
"""Mutation tests for tools/gate_status.py itself -- the audit response queue's Part A (`docs/
DECISIONS_LEDGER.md` D0146). Three real defects Codex found in the status tool, each proven fixed here
against synthetic data (never the real repo, so this test can run before/after a deliberate break without
touching anything real):

    python3 tools/test_gate_status.py

A1 -- a CI "skipped" step (an earlier step in the same job already failed, so this one never actually
      ran) must never have its own local re-execution promoted into the gate's top-line PASS/FAIL.
R1 -- the sibling defect (Codex, third find on this tool, fix queue after the three-queue certification):
      a step CI reports NOTHING for at all -- absent, not skipped, a different case entirely -- must also
      never have local re-execution promoted into PASS/FAIL. The old fallback at line 270 let exactly
      that happen. Three cases proven explicitly: CI=success -> PASS, CI=skipped -> SKIPPED (A1, above),
      CI=absent -> UNKNOWN (R1, not a promoted local PASS).
A2 -- a gate whose QUALITY.md evidence is a bare DIRECTORY citation (no filename) must link only to the
      one script conventionally named after that directory, never to every other, differently-numbered
      script that happens to live alongside it.
A4  -- deleting a real step from harness.yml changes gate_status.py's own table (that gate's row flips to
      NO-CODE) with NO OTHER EDIT -- to gate_status.py, to QUALITY.md, to anything -- proving the tool
      re-derives its table from harness.yml's live structure rather than any cached or hand-copied form.

F2  -- found during the queue #2 self-audit, `docs/DECISIONS_LEDGER.md` D0162: GitHub Actions EXPANDS a
      `${{ env.KEY }}` expression in a step's own `name:` before reporting it via the API (confirmed
      directly against a real run: harness.yml's tracked YAML says "...Godot ${{ env.GODOT_VERSION }}...",
      `gh api .../jobs` reports "...Godot 4.6.2-stable..."). Reading the raw, unexpanded name and matching
      it against CI's own (expanded) name via a plain string key NEVER matched -- this step was silently
      invisible to CI-conclusion matching, always UNKNOWN regardless of whether CI actually passed or
      failed on it. Not a false PASS (UNKNOWN is not a lie), but a real population gap in the CI-matching
      mechanism this case proves is now closed.
"""
import sys
import tempfile
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gate_status as gs  # noqa: E402

RESULTS: list[tuple[str, bool]] = []


def check(name: str, ok: bool, note: str = "") -> None:
    RESULTS.append((name, ok))
    status = "OBSERVED" if ok else "NOT OBSERVED -- BRANCH UNTESTED"
    print(f"[{status}] {name}" + (f" -- {note}" if note else ""))


def branch_a1_skipped_never_promoted_to_pass() -> None:
    """A step CI reports 'skipped' but that PASSES when re-run locally right now must resolve to
    SKIPPED, never PASS -- the tool's own defect: `duplication.py` (a BLOCKING check) was skipped by CI
    because an earlier step in its job failed, then re-run locally and passing, and the old code silently
    let that local PASS become the gate's own top-line verdict."""
    step = {"job": "gates", "name": "synthetic blocking check", "run": "true", "coe": False}
    ci_steps = {"synthetic blocking check": "skipped"}
    status, details = gs.resolve_status([step], ci_steps)
    check("A1: CI=skipped + local=PASS resolves to SKIPPED, not PASS", status == "SKIPPED",
          f"got status={status}, details={details}")


def branch_a1_skipped_never_promoted_to_fail_either() -> None:
    """Symmetric case: a skipped step whose local re-run happens to FAIL must also resolve to SKIPPED,
    not FAIL -- proving the fix suppresses local promotion in BOTH directions, not just the PASS one."""
    step = {"job": "gates", "name": "synthetic blocking check 2", "run": "false", "coe": False}
    ci_steps = {"synthetic blocking check 2": "skipped"}
    status, details = gs.resolve_status([step], ci_steps)
    check("A1b: CI=skipped + local=FAIL still resolves to SKIPPED, not FAIL", status == "SKIPPED",
          f"got status={status}, details={details}")


def branch_a1_real_ci_conclusion_still_authoritative() -> None:
    """Negative control: when CI actually ran and reported a real conclusion, that conclusion (not local)
    still decides the verdict -- proves the fix didn't break the ordinary, working case."""
    step = {"job": "gates", "name": "synthetic real check", "run": "false", "coe": False}
    ci_steps = {"synthetic real check": "success"}
    status, _ = gs.resolve_status([step], ci_steps)
    check("A1c negative control: CI=success stays PASS even if local=FAIL (DISAGREE, not promoted)",
          status == "PASS")


def branch_r1_absent_ci_never_promoted_to_pass() -> None:
    """The sibling defect to A1, one layer over: CI reporting NOTHING for a step name at all (absent --
    it never ran in the fetched CI run, was renamed, or is otherwise unmatched) is a DIFFERENT case from
    "skipped"/"cancelled" (those ARE a reported conclusion). The old code's fallback let `local` supply
    PASS/FAIL whenever CI had no entry for the step, so a step CI never reported on could still read as a
    promoted local PASS. Must resolve UNKNOWN, never PASS."""
    step = {"job": "gates", "name": "synthetic never-reported check", "run": "true", "coe": False}
    ci_steps = {}  # CI has NO entry for this step name at all -- absent, not skipped
    status, details = gs.resolve_status([step], ci_steps)
    check("R1: CI=absent + local=PASS resolves to UNKNOWN, not PASS", status == "UNKNOWN",
          f"got status={status}, details={details}")


def branch_r1_absent_ci_never_promoted_to_fail_either() -> None:
    """Symmetric case: a step CI never reported on, whose local re-run happens to FAIL, must also resolve
    UNKNOWN, not FAIL -- proving the fix suppresses local promotion in BOTH directions, not just PASS."""
    step = {"job": "gates", "name": "synthetic never-reported check 2", "run": "false", "coe": False}
    ci_steps = {}
    status, details = gs.resolve_status([step], ci_steps)
    check("R1b: CI=absent + local=FAIL also resolves to UNKNOWN, not FAIL", status == "UNKNOWN",
          f"got status={status}, details={details}")


def branch_r1_three_cases_explicit() -> None:
    """The three cases side by side, as the fix queue asked for explicitly: CI=success -> PASS,
    CI=skipped -> SKIPPED, CI=absent -> UNKNOWN. All three use the SAME step (`run: "true"`, which PASSES
    locally) so the only variable across the three calls is what CI itself reported -- proving the status
    tracks CI's own conclusion, not what happened to run locally."""
    step = {"job": "gates", "name": "synthetic three-case check", "run": "true", "coe": False}
    status_success, _ = gs.resolve_status([step], {"synthetic three-case check": "success"})
    status_skipped, _ = gs.resolve_status([step], {"synthetic three-case check": "skipped"})
    status_absent, _ = gs.resolve_status([step], {})
    check("R1 three-case: CI=success -> PASS", status_success == "PASS", f"got {status_success}")
    check("R1 three-case: CI=skipped -> SKIPPED", status_skipped == "SKIPPED", f"got {status_skipped}")
    check("R1 three-case: CI=absent -> UNKNOWN (not PASS, even though local=PASS)",
          status_absent == "UNKNOWN", f"got {status_absent}")


def branch_a2_bare_directory_citation_does_not_overmatch() -> None:
    """Reproduces gate 1's exact shape: a gate cited only by a bare directory ('tools/layer_lint'), a
    step that IS its directory's primary check (tools/layer_lint/layer_lint.py), and a co-located but
    unrelated, differently-numbered script (tools/layer_lint/check_loc_ratio.py) that must NOT attach."""
    gates = {
        1: {"title": "Layer lint.", "body": "Custom check in `tools/layer_lint`."},
        7: {"title": "Instrument LOC.", "body": "`tools/layer_lint/check_loc_ratio.py`"},
    }
    steps = [
        {"job": "gates", "name": "Layer dependency lint", "run": "python3 tools/layer_lint/layer_lint.py", "coe": False},
        {"job": "gates", "name": "Instrument LOC must not exceed game LOC (QUALITY gate 7)",
         "run": "python3 tools/layer_lint/check_loc_ratio.py", "coe": False},
    ]
    links, _kind = gs.link_gates(gates, steps)
    gate1_names = {s["name"] for s in links[1]}
    check("A2: gate 1 (bare directory citation) links ONLY its own primary script",
          gate1_names == {"Layer dependency lint"},
          f"gate 1 linked to: {gate1_names}")
    check("A2 negative control: gate 7's own cited step still links to gate 7",
          {s["name"] for s in links[7]} == {"Instrument LOC must not exceed game LOC (QUALITY gate 7)"})


def branch_a4_deleting_a_workflow_step_changes_the_table() -> None:
    """The real docs/QUALITY.md's gates, parsed live -- but harness.yml is a MUTATED temp copy with gate
    7's own step deleted. No other edit: gate_status.py's own source is untouched, QUALITY.md is untouched
    -- only the workflow file differs. Gate 7 must flip from linked (real code) to NO-CODE."""
    gates = gs.parse_gates()  # the real, unmodified docs/QUALITY.md -- no edit made here
    steps_before = gs.parse_workflow_steps()  # the real, unmodified harness.yml
    links_before, _ = gs.link_gates(gates, steps_before)
    check("A4 sanity: gate 7 has real linked code before any mutation", bool(links_before[7]))

    real_wf_text = gs.WORKFLOW.read_text(encoding="utf-8")
    target_line = "        run: python3 tools/layer_lint/check_loc_ratio.py\n"
    assert target_line in real_wf_text, "the exact step text this test deletes must exist in harness.yml"
    # Delete gate 7's own step (its name: line plus its run: line) -- a real structural edit to the
    # workflow, done on a throwaway temp copy, never touching the tracked file.
    lines = real_wf_text.splitlines(keepends=True)
    name_idx = next(i for i, l in enumerate(lines) if "Instrument LOC must not exceed game LOC" in l)
    del lines[name_idx:name_idx + 2]  # the "- name: ..." line and its "run: ..." line
    mutated_text = "".join(lines)
    assert "Instrument LOC must not exceed game LOC" not in mutated_text, "deletion did not take"

    with tempfile.TemporaryDirectory() as d:
        mutated_path = Path(d) / "harness.yml"
        mutated_path.write_text(mutated_text, encoding="utf-8")
        steps_after = gs.parse_workflow_steps(mutated_path)
        links_after, _ = gs.link_gates(gates, steps_after)

    check("A4: deleting gate 7's own harness.yml step, no other edit, flips gate 7 to NO-CODE",
          links_after[7] == [], f"gate 7 links after deletion: {links_after[7]}")
    other_gate = 8  # an unrelated gate (determinism) must be completely unaffected by this one deletion
    check("A4 negative control: an unrelated gate's own link is unaffected by the deletion",
          bool(links_after.get(other_gate)) == bool(links_before.get(other_gate)))


def branch_f2_env_expression_in_step_name_resolves_before_matching() -> None:
    """D0162: a step name containing `${{ env.KEY }}` must resolve against the SAME job's own `env:`
    block, matching what GitHub Actions itself reports via the API -- an unresolved expression can never
    match a real CI step name, permanently reporting UNKNOWN for that step regardless of its true
    conclusion."""
    resolved = gs._resolve_env_expressions(
        "Download and verify Godot ${{ env.GODOT_VERSION }} (headless-capable Linux build)",
        {"GODOT_VERSION": "4.6.2-stable"},
    )
    check("F2: a known env.KEY expression resolves to the job's own env value",
          resolved == "Download and verify Godot 4.6.2-stable (headless-capable Linux build)",
          f"got: {resolved!r}")

    unknown = gs._resolve_env_expressions("Step using ${{ env.NOT_DECLARED }}", {"OTHER": "x"})
    check("F2 negative control: an expression for an UNDECLARED key is left untouched, not blanked",
          unknown == "Step using ${{ env.NOT_DECLARED }}", f"got: {unknown!r}")

    plain = gs._resolve_env_expressions("A perfectly ordinary step name", {"GODOT_VERSION": "4.6.2-stable"})
    check("F2 negative control: a name with no expression at all is unchanged",
          plain == "A perfectly ordinary step name")


def branch_report_executes_each_local_step_once_per_invocation() -> None:
    """Shared gate evidence and unlinked summaries must not rerun commands; a new report must."""
    gates = {n: {"title": f"Gate {n}", "body": ""} for n in (1, 2)}
    shared = {"job": "checks", "name": "shared", "run": "check shared", "coe": False}
    unlinked = {"job": "checks", "name": "unlinked", "run": "check extra", "coe": False}
    other_job = dict(unlinked, job="other")
    engine = {"job": "checks", "name": "engine", "run": "godot --headless", "coe": False}
    advisory = dict(unlinked, name="advisory", coe=True)
    steps = [shared, unlinked, other_job, engine, advisory]
    links = {1: [shared], 2: [shared]}
    ci = {"shared": "success", "unlinked": "skipped", "engine": "failure"}
    output = StringIO()
    with patch.object(gs, "parse_gates", return_value=gates), \
            patch.object(gs, "parse_workflow_steps", return_value=steps), \
            patch.object(gs, "link_gates", return_value=(links, {1: "test", 2: "test"})), \
            patch.object(gs, "git_head", return_value="test-head"), \
            patch.object(gs, "fetch_ci_state", return_value=(None, "synthetic", ci)), \
            patch.object(gs, "run_locally", return_value="FAIL (exit 1)") as run, \
            redirect_stdout(output), redirect_stderr(StringIO()):
        rc = gs.main()
        first_calls = [c.args[0] for c in run.call_args_list]
        run.reset_mock()
        run.return_value = "PASS"
        ci.clear()
        output.seek(0)
        first_output = output.getvalue()
        output.truncate(0)
        second_rc = gs.main()
        second_calls = [c.args[0] for c in run.call_args_list]
    expected = ["check shared", "check extra", "check extra"]
    check("report executes shared and unlinked steps once; distinct jobs stay distinct",
          first_calls == expected, repr(first_calls))
    check("a second report executes afresh with no persistent cache", second_calls == expected)
    check("cached local failure preserves CI success and DISAGREE", "DISAGREE -- CI=success, local=FAIL" in first_output)
    check("unlinked failure and skipped summaries retain their members",
          "unnumbered steps currently FAIL: ['engine']" in first_output
          and "unnumbered steps currently SKIPPED: ['unlinked', 'unlinked']" in first_output)
    check("a later report uses fresh CI and local results", "local=PASS" in output.getvalue()
          and "DISAGREE" not in output.getvalue() and "[UNKNOWN " in output.getvalue())
    check("report exit remains informational", rc == second_rc == 0)


def branch_local_cache_preserves_errors_and_command_identity() -> None:
    step = {"job": "checks", "name": "same", "run": "check original", "coe": False}
    cache = {}
    with patch.object(gs, "run_locally", return_value="FAIL (timeout)") as run:
        first = gs.classify_step(step, {"same": "failure"}, cache)
        repeated = gs.classify_step(dict(step), {"same": "failure"}, cache)
        cancelled = gs.classify_step(step, {"same": "cancelled"}, cache)
        check("cached errors retain failure details", first == repeated and "timeout" in repeated[1])
        check("CI is reclassified independently of cached local errors", cancelled[0] == "SKIPPED")
        check("an error is executed once, not retried by report formatting", run.call_count == 1)
        gs.classify_step(dict(step, run="check changed"), {}, cache)
        check("a changed command is not hidden by the cache", run.call_count == 2)


def main() -> int:
    for branch in (
        branch_a1_skipped_never_promoted_to_pass,
        branch_a1_skipped_never_promoted_to_fail_either,
        branch_a1_real_ci_conclusion_still_authoritative,
        branch_r1_absent_ci_never_promoted_to_pass,
        branch_r1_absent_ci_never_promoted_to_fail_either,
        branch_r1_three_cases_explicit,
        branch_a2_bare_directory_citation_does_not_overmatch,
        branch_a4_deleting_a_workflow_step_changes_the_table,
        branch_f2_env_expression_in_step_name_resolves_before_matching,
        branch_report_executes_each_local_step_once_per_invocation,
        branch_local_cache_preserves_errors_and_command_identity,
    ):
        branch()

    failed = [name for name, ok in RESULTS if not ok]
    print()
    print(f"test_gate_status: {len(RESULTS) - len(failed)}/{len(RESULTS)} cases observed correctly.")
    if failed:
        print("test_gate_status: FAIL -- these branches did not fire as expected:")
        for name in failed:
            print(f"  {name}")
        return 1

    print("test_gate_status: PASS.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
