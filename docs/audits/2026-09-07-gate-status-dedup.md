# Gate-status local execution deduplication

Status: implemented and focused-tested, 2026-09-07. Base: f50f78a3.
Scope: tools/gate_status.py and tools/test_gate_status.py. No CI policy or gameplay changes.

Each report owns a local-result cache keyed by job, step name, and command. Multiple gate references
and unlinked-step summary lists reuse the result. A subsequent report runs fresh checks. CI verdicts
are classified independently, preserving UNKNOWN, SKIPPED, failure and disagreement reporting.
Standalone classifier calls without a cache retain their previous fresh-execution behavior.

Verification:
- New synthetic regression failed before the fix: three eligible steps executed eight commands.
- After the fix, all 26 cases passed, including distinct jobs, changed commands, cached errors,
  cancelled CI, repeated report invocations and unchanged informational exit status.
- Against the actual workflow, with all local runners and CI access mocked, executions fell from
  56 to 28 and stdout matched the pre-change report byte for byte.
- Focused formatter and diff-whitespace checks passed.

No real gate sweep or gameplay session was run. The count reduction is not a measured wall-time
speedup. The engineering agent's staged hint and playtest changes were left outside this change.
Remaining Batch 3 work is in docs/CLEANUP_PLAN.md; directory moves remain deferred during active playtesting.
