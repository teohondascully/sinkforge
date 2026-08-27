# ANVIL

The event-sourced development substrate. `incoming/ANVIL_ARCHITECTURE.md` is the design; the director's
own review of it (this session's transcript, and `docs/DECISIONS_LEDGER.md` D0064) has the corrections
and the build order actually being followed.

`log/` holds one JSON file per event, named `<iso8601>-<uuid8>.json`, append-only — write with
`tools/anvil/append.py`, never by hand. **Two real events now, both `FINDING`s from an external (Codex)
audit of ANVIL itself, `source_class: external-audit`** — one records that this document's original
"contradictions unrepresentable" claim was false (`docs/DECISIONS_LEDGER.md` D0070); one records the
audit's judgment that the seven event types may be missing a home for evaluation runs, work items, and
adjudications, logged as evidence rather than resolved (D0073). See `docs/WORKING.md`'s overnight queue
for exactly what has and hasn't landed.

`tools/anvil/schema.py`, `append.py`, `check_integrity.py`, `test_check_integrity.py` are the code; this
directory is only ever data.

## Two things that happened in the first round, worth keeping here rather than only in the ledger

**Unread does not mean unimportant, and it cost hours to prove, not months.** Step 1 of ANVIL's own build
order confirmed a bucket of files to track, including `legacy/tools/director_bus.sh` and
`test_director_bus.sh`. A separate, unrelated instruction — read `CONVERGENCE_LEDGER.md` and a few other
specific files before archiving `docs/handoff/`, because they were flagged as plausibly containing
reasoning worth keeping — surfaced a dated, reasoned 2026-08-23 decision to keep those exact two files
untracked, for a real reason (public-portfolio hygiene) the already-confirmed bucket knew nothing about.
The bucket was reversed before it was executed. This is the argument for archiving unread content
instead of deleting it by classification, made concrete rather than asserted: had the file been deleted
unread, the mistake it prevented would have shipped, and the evidence that it was a mistake would be
gone along with it. `docs/DECISIONS_LEDGER.md` D0065.

**A gate caught its own system's directory in the round it landed.** The instant `.anvil/` was created,
it fell under `.gitignore`'s then-existing "ignore every dotted directory by shape" rule —
`check_untracked_files.py` (the gate this same round built to close a related hole) flagged
`.anvil/README.md` as untracked before the commit that introduced it. That rule has since been removed
in favor of gate 27 itself doing the work loudly, rather than a blanket exclusion doing it silently
(`docs/DECISIONS_LEDGER.md` D0066) — the near-miss is the reason the rule was worth removing, not just an
anecdote next to the decision.

**A third, candidate for this document's eventual opening line, once it is composed in full rather than
grown incrementally:** typed references (`docs/DECISIONS_LEDGER.md` D0069) broke two of this session's
own "fixed" test fixtures — a self-referencing event, structurally valid, semantically nonsensical, that
passed every check that existed until the type rule arrived. Written by an author paying attention, in
code whose whole purpose was testing correctness. That is the second such finding in three days, after
D0004's duplicate ledger header. Both are a rule with no mechanism, violated by someone careful, not
someone careless — which is the actual argument for Anvil, made twice now as a measured pattern rather
than asserted once as a thesis (D0075).
