Scoped to this run only. The queue this loop drives is fixed in `docs/WORKING.md` under
"## Overnight queue" before the loop starts, and this command may not add to it — the property that
makes this safe to run unattended is that the queue is derived from a spec the director handed down,
not authored by the session running it.

1. Read `CLAUDE.md` and `docs/WORKING.md`. Verify repo state matches what `docs/WORKING.md` claims.
   State in one line what you are doing. (Run every iteration, not once — this is what makes the loop
   survive a compaction mid-run: re-orientation happens on its own schedule, not by waiting for a human
   to invoke `/handoff`.)
2. Read the queue in `docs/WORKING.md` under "## Overnight queue".
3. Take the first unchecked item. Do it.
4. Run all gates. Red you cannot clear in one attempt -> revert, log, STOP the loop entirely.
5. Commit. Append the ledger entries for that step's decisions.
6. Check the item off in `docs/WORKING.md`.
7. If any HARD STOP condition applies, stop. Otherwise go to 1.

HARD STOPS, checked every iteration:

- Any EXPENSIVE decision (resolution split, heightfield contract, threshold move, capsule vs rounded
  AABB, or whatever the current queue's own EXPENSIVE list names).
- Any gate red not clearable in one attempt.
- Three consecutive commits with no test going red to green.
- The 5-file rule breaking.
- The commit budget stated for this run.
- Any item outside the fixed queue being checked off, or the queue itself being extended.

Run `/wrap` when the loop stops, for any reason.
