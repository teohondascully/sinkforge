Run the end-of-session checklist, in this order:

1. **If any Agent/fork/subagent landed file changes this session, reconcile every one of them BEFORE
   anything else below — do not accept a "done" report at face value.** For each fork that reported
   completion, run `python3 tools/check_fork_completion.py --claimed=<the files it said it changed>`
   against the current working tree (or `--base=<its commit sha>` if it already committed). A FAIL means
   the fork's own report was wrong — resume it or redo the work yourself before treating anything it
   claimed as landed. This exists because a fork reported `completed` with a detailed summary while its
   diff touched neither of its two target files, caught only by hand (`docs/DECISIONS_LEDGER.md` D0105's
   sweep-blindness law, `.anvil/log/2026-08-29T074921.640759Z-ad065cf8.json`) — this step is that
   reconciliation made mechanical instead of relying on the director or the orchestrator noticing. A
   completion summary is a claim, not evidence; the tool call above is the evidence.
2. **When reporting doc edits — GDD.md, CONTEXT.md, README.md, ARCHITECTURE.md, or any other normative
   doc — show the actual diff (`git diff <file>`), never a prose summary that the edits happened.**
   Summaries are declared state, and declared state drifts; this project is event-sourced precisely to
   avoid that. A report about a change is not the change — the tree is the change, so the tree (via its
   diff) is what gets shown, not a paraphrase of it.
3. Update `docs/WORKING.md`: current stage, what landed, what's in flight, open questions. Bump its
   "Last updated" date to today.
4. Append `docs/DECISIONS_LEDGER.md` entries for every judgment call made this session that isn't
   already logged. Numbers are addresses — never edit or reuse an existing entry's number.
5. Add this session's "## What was learned" entry to `docs/BRIEF.md` before regenerating it (see the
   template in `docs/BRIEF.md` itself): what happened, what was learned, pointers to the ledger entries
   and commits that carry the detail. Findings, not a work log — if it isn't something a future session
   needs to know to avoid repeating a mistake or losing a result, it doesn't belong here.
6. Regenerate `docs/BRIEF.md` — this must be the last file write before reporting, not an arbitrary
   session boundary, since anything written after would make the brief stale on arrival.
7. Run every gate (`tools/layer_lint/*.py`, `tools/schema_validator/schema_validator.py`,
   `tools/data_codegen/generate.py --check`) and confirm the current state, not from memory.
8. Report to the director.
