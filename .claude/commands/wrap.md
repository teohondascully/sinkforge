Run the end-of-session checklist, in this order:

1. Update `docs/WORKING.md`: current stage, what landed, what's in flight, open questions. Bump its
   "Last updated" date to today.
2. Append `docs/DECISIONS_LEDGER.md` entries for every judgment call made this session that isn't
   already logged. Numbers are addresses — never edit or reuse an existing entry's number.
3. Add this session's "## What was learned" entry to `docs/BRIEF.md` before regenerating it (see the
   template in `docs/BRIEF.md` itself): what happened, what was learned, pointers to the ledger entries
   and commits that carry the detail. Findings, not a work log — if it isn't something a future session
   needs to know to avoid repeating a mistake or losing a result, it doesn't belong here.
4. Regenerate `docs/BRIEF.md` — this must be the last file write before reporting, not an arbitrary
   session boundary, since anything written after would make the brief stale on arrival.
5. Run every gate (`tools/layer_lint/*.py`, `tools/schema_validator/schema_validator.py`,
   `tools/data_codegen/generate.py --check`) and confirm the current state, not from memory.
6. Report to the director.
