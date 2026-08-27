# ANVIL

The event-sourced development substrate. `incoming/ANVIL_ARCHITECTURE.md` is the design; the director's
own review of it (this session's transcript, and `docs/DECISIONS_LEDGER.md` D0064) has the corrections
and the build order actually being followed.

`log/` holds one JSON file per event, named `<iso8601>-<uuid8>.json`, append-only — write with
`tools/anvil/append.py`, never by hand. Empty as of this commit: steps 1-2 built the spine (schema,
append tool, referential integrity checker, mutation-tested), not the economy-authoring step that would
produce the first real events. See `docs/WORKING.md`'s overnight queue for exactly what has and hasn't
landed yet.

`tools/anvil/schema.py`, `append.py`, `check_integrity.py`, `test_check_integrity.py` are the code; this
directory is only ever data.
